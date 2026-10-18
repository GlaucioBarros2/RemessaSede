"""Cliente da API Tray (web_api): tokens, limite de requisicoes, listagem e PUT de produtos."""
import re
import time
from datetime import datetime, timedelta

import requests

DATA_FMT = '%Y-%m-%d %H:%M:%S'
MARGEM_TOKEN = timedelta(minutes=5)
POR_PAGINA = 50  # maximo da Tray


class TrayError(Exception):
    pass


class TrayAuthError(TrayError):
    pass


class TrayHTTPError(TrayError):
    def __init__(self, status, corpo):
        TrayError.__init__(self, 'HTTP %s: %s' % (status, corpo))
        self.status = status


class DailyLimitReached(TrayError):
    pass


def _scrub(txt):
    """Tira tokens de mensagens (o requests inclui a URL, e o access_token vai na query)."""
    return re.sub(r'(access_token|refresh_token)=[^&\s\'"]+', r'\1=***', str(txt))


class TrayClient(object):
    def __init__(self, api_base, consumer_key, consumer_secret, code, state,
                 session=None, intervalo=0.4, limite_diario=9500,
                 agora=datetime.now, sleep=time.sleep):
        self.api = api_base.rstrip('/')
        self.consumer_key = consumer_key
        self.consumer_secret = consumer_secret
        self.code = code
        self.state = state
        self.session = session or requests.Session()
        self.intervalo = intervalo
        self.limite_diario = limite_diario
        self.agora = agora
        self.sleep = sleep
        self._ultimo = 0.0

    # ---- tokens ----------------------------------------------------------
    def _salva_tokens(self, d):
        if not d.get('access_token'):
            raise TrayAuthError('resposta de autenticacao sem access_token: %s' % _scrub(d.get('message', d)))
        for k in ('access_token', 'refresh_token', 'date_expiration_access_token',
                  'date_expiration_refresh_token'):
            if d.get(k):
                self.state.set(k, d[k])

    def _expirado(self, chave):
        val = self.state.get(chave)
        if not val:
            return True
        try:
            return datetime.strptime(val, DATA_FMT) - self.agora() < MARGEM_TOKEN
        except ValueError:
            return True

    def _auth_call(self, method, **kw):
        try:
            r = self.session.request(method, self.api + '/auth', timeout=30, **kw)
            dados = r.json()
        except (requests.RequestException, ValueError) as e:
            raise TrayAuthError(_scrub(e))
        self._salva_tokens(dados)

    def renovar(self):
        """Renova pelo refresh_token; se nao der, autentica de novo com o code."""
        refresh = self.state.get('refresh_token')
        if refresh and not self._expirado('date_expiration_refresh_token'):
            try:
                self._auth_call('GET', params={'refresh_token': refresh})
                return
            except TrayAuthError:
                pass
        if not self.code:
            raise TrayAuthError('refresh_token invalido/expirado e nao ha "code" configurado')
        self._auth_call('POST', json={'consumer_key': self.consumer_key,
                                      'consumer_secret': self.consumer_secret,
                                      'code': self.code})

    def _garante_token(self):
        if not self.state.get('access_token') or self._expirado('date_expiration_access_token'):
            self.renovar()

    # ---- requisicoes -----------------------------------------------------
    def _request(self, method, path, params=None, json=None):
        self._garante_token()
        reautenticou = False
        for _ in range(5):
            dia = self.agora().date().isoformat()
            if self.state.requests_today(dia) >= self.limite_diario:
                raise DailyLimitReached('limite diario de %d requisicoes atingido' % self.limite_diario)
            espera = self.intervalo - (time.monotonic() - self._ultimo)
            if espera > 0:
                self.sleep(espera)
            self._ultimo = time.monotonic()
            self.state.count_request(dia)
            p = dict(params or {})
            p['access_token'] = self.state.get('access_token')
            try:
                r = self.session.request(method, self.api + path, params=p, json=json, timeout=30)
            except requests.RequestException as e:
                raise TrayError(_scrub(e))
            if r.status_code == 401 and not reautenticou:
                reautenticou = True
                self.renovar()
                continue
            if r.status_code == 429:
                self.sleep(60)
                continue
            if r.status_code >= 400:
                raise TrayHTTPError(r.status_code, _scrub(r.text[:300]))
            return r
        raise TrayError('muitas tentativas em %s %s' % (method, path))

    # ---- produtos --------------------------------------------------------
    def lista_produtos(self):
        """Gera (reference, id, name) de todos os produtos da loja."""
        pagina = 1
        while True:
            dados = self._request('GET', '/products', params={'page': pagina, 'limit': POR_PAGINA}).json()
            itens = dados.get('Products') or []
            for it in itens:
                p = it['Product']
                yield (p.get('reference') or '', str(p['id']), p.get('name') or '')
            if len(itens) < POR_PAGINA:
                return
            pagina += 1

    def atualiza(self, tray_id, preco, estoque, disponivel):
        body = {'Product': {'price': preco, 'stock': estoque, 'available': '1' if disponivel else '0'}}
        self._request('PUT', '/products/%s' % tray_id, json=body)
