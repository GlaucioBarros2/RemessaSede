"""Cliente da API da Tray (web_api).

Cuida de:
  - tokens: guarda, confere validade e renova sozinho (substitui os scripts
    teste_atualiza_token.py e teste_get_refresh_token.py);
  - limites da Tray: 180 requisicoes/minuto e 10 mil/dia;
  - listar produtos (para saber o id da Tray de cada codigo) e atualizar preco/estoque.
"""
import logging
import re
import time
from datetime import datetime, timedelta

import requests

DATA_FMT = '%Y-%m-%d %H:%M:%S'          # formato das datas de validade que a Tray devolve
MARGEM_TOKEN = timedelta(minutes=5)      # renova o token um pouco antes de vencer (ao enviar)
MARGEM_RENOVACAO = timedelta(minutes=30)  # renovacao proativa: access_token vale 3h, renova com 30 min de folga
AVISO_REFRESH = timedelta(days=5)         # avisa no log se o refresh_token (30 dias) vence em menos de 5 dias
POR_PAGINA = 50                          # maximo de produtos por pagina na Tray

log = logging.getLogger('tray_sync')


class TrayError(Exception):
    """Erro generico de comunicacao com a Tray."""


class TrayAuthError(TrayError):
    """Nao conseguiu autenticar / renovar o token."""


class TrayHTTPError(TrayError):
    """A Tray respondeu com erro HTTP (400, 404, 500...). Guarda o status."""
    def __init__(self, status, corpo):
        TrayError.__init__(self, 'HTTP %s: %s' % (status, corpo))
        self.status = status


class DailyLimitReached(TrayError):
    """Chegamos no limite diario de requisicoes; para e retoma amanha."""


def _scrub(txt):
    """Esconde tokens em mensagens de erro.

    O access_token vai na URL (?access_token=...) e o requests coloca a URL inteira
    nas mensagens de erro; sem isso o token iria parar no arquivo de log.
    """
    return re.sub(r'(access_token|refresh_token)=[^&\s\'"]+', r'\1=***', str(txt))


class TrayClient(object):
    def __init__(self, api_base, consumer_key, consumer_secret, code, state,
                 session=None, intervalo=0.4, limite_diario=9500,
                 agora=datetime.now, sleep=time.sleep):
        self.api = api_base.rstrip('/')          # ex.: https://loja.com.br/web_api
        self.consumer_key = consumer_key
        self.consumer_secret = consumer_secret
        self.code = code                         # codigo de autorizacao (so usado se nao houver refresh_token)
        self.state = state                       # onde os tokens ficam guardados
        self.session = session or requests.Session()
        self.intervalo = intervalo               # espera minima entre requisicoes (segundos)
        self.limite_diario = limite_diario       # margem abaixo dos 10 mil da Tray
        self.agora = agora                       # (injetaveis para facilitar os testes)
        self.sleep = sleep
        self._ultimo = 0.0                       # instante da ultima requisicao

    # ---- tokens ----------------------------------------------------------
    def _salva_tokens(self, d):
        """Guarda os tokens recebidos da Tray no SQLite."""
        if not d.get('access_token'):
            raise TrayAuthError('resposta de autenticacao sem access_token: %s' % _scrub(d.get('message', d)))
        # store_id e api_host dizem QUAL loja esta autorizada (so para diagnostico)
        for k in ('access_token', 'refresh_token', 'date_expiration_access_token',
                  'date_expiration_refresh_token', 'store_id', 'api_host'):
            if d.get(k):
                self.state.set(k, str(d[k]))

    def _expirado(self, chave, margem=MARGEM_TOKEN):
        """True se a data de validade guardada em 'chave' ja venceu (ou vence em menos de 'margem')."""
        val = self.state.get(chave)
        if not val:
            return True
        try:
            return datetime.strptime(val, DATA_FMT) - self.agora() < margem
        except ValueError:
            return True

    def _auth_call(self, method, **kw):
        """Chama /auth (GET para renovar, POST para autenticar) e guarda o resultado."""
        try:
            r = self.session.request(method, self.api + '/auth', timeout=30, **kw)
            dados = r.json()
        except (requests.RequestException, ValueError) as e:
            raise TrayAuthError(_scrub(e))
        self._salva_tokens(dados)

    def renovar(self):
        """Obtem um access_token novo.

        1o tenta pelo refresh_token (se ainda valido); se nao der, autentica de novo
        com consumer_key/consumer_secret/code.
        """
        refresh = self.state.get('refresh_token')
        if refresh and not self._expirado('date_expiration_refresh_token'):
            try:
                self._auth_call('GET', params={'refresh_token': refresh})
                return
            except TrayAuthError:
                pass  # cai para a autenticacao com o code
        if not self.code:
            raise TrayAuthError('refresh_token invalido/expirado e nao ha "code" configurado')
        self._auth_call('POST', json={'consumer_key': self.consumer_key,
                                      'consumer_secret': self.consumer_secret,
                                      'code': self.code})

    def manter_token(self):
        """Mantem os tokens em dia mesmo sem enviar nada (chamado a cada ciclo).

        A Tray recomenda automatizar isso: o access_token vale 3 horas e, a cada renovacao,
        vem tambem um refresh_token novo (valido por 30 dias). Se o programa ficasse dias sem
        renovar (nenhum produto mudou), o refresh_token venceria sem ninguem perceber.
        """
        if (not self.state.get('access_token')
                or self._expirado('date_expiration_access_token', MARGEM_RENOVACAO)):
            self.renovar()
        # se mesmo apos renovar o refresh_token vence logo, o usuario precisa gerar um code novo
        if self._expirado('date_expiration_refresh_token', AVISO_REFRESH):
            log.warning('o refresh_token da Tray vence em %s; se a renovacao automatica falhar, '
                        'gere um code novo e rode: python -m tray_sync --reautenticar',
                        self.state.get('date_expiration_refresh_token'))

    def _garante_token(self):
        """Antes de cada requisicao: se nao ha token ou ele vai vencer, renova."""
        if not self.state.get('access_token') or self._expirado('date_expiration_access_token'):
            self.renovar()

    # ---- requisicoes -----------------------------------------------------
    def _request(self, method, path, params=None, json=None):
        """Faz uma requisicao a Tray respeitando limites e tratando erros comuns.

        - 401 (token invalido): renova o token e repete UMA vez;
        - 429 (muitas requisicoes): espera 1 minuto e repete;
        - outros erros 4xx/5xx: levanta TrayHTTPError.
        """
        self._garante_token()
        reautenticou = False
        for _ in range(5):
            dia = self.agora().date().isoformat()
            # trava de seguranca do limite diario
            if self.state.requests_today(dia) >= self.limite_diario:
                raise DailyLimitReached('limite diario de %d requisicoes atingido' % self.limite_diario)
            # espaca as requisicoes (a Tray aceita 180/min; usamos bem menos)
            espera = self.intervalo - (time.monotonic() - self._ultimo)
            if espera > 0:
                self.sleep(espera)
            self._ultimo = time.monotonic()
            self.state.count_request(dia)
            p = dict(params or {})
            p['access_token'] = self.state.get('access_token')  # a Tray recebe o token na query
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
        """Gera (reference, id, nome) de todos os produtos da loja, pagina a pagina.

        'reference' na Tray e o nosso codigo do produto (CODPRO).
        """
        pagina = 1
        while True:
            dados = self._request('GET', '/products', params={'page': pagina, 'limit': POR_PAGINA}).json()
            itens = dados.get('Products') or []
            for it in itens:
                p = it['Product']
                yield (p.get('reference') or '', str(p['id']), p.get('name') or '')
            if len(itens) < POR_PAGINA:  # pagina incompleta = ultima
                return
            pagina += 1

    def resumo_loja(self):
        """(total de produtos, nome do 1o produto) segundo a API; 1 requisicao (diagnostico)."""
        dados = self._request('GET', '/products', params={'page': 1, 'limit': 1}).json()
        itens = dados.get('Products') or []
        nome = itens[0]['Product'].get('name') if itens else None
        return (dados.get('paging') or {}).get('total'), nome

    def produto(self, tray_id):
        """Devolve o JSON completo de UM produto (GET /products/{id}); usado no diagnostico."""
        return self._request('GET', '/products/%s' % tray_id).json()

    def atualiza(self, tray_id, preco, estoque, disponivel):
        """PUT no produto: atualiza preco, estoque e disponibilidade (1 = disponivel)."""
        body = {'Product': {'price': preco, 'stock': estoque, 'available': '1' if disponivel else '0'}}
        self._request('PUT', '/products/%s' % tray_id, json=body)
