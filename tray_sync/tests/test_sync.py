"""Testes do fluxo completo, com uma Tray de mentira (FakeTray) e um DBF temporario."""
import configparser
from datetime import datetime, timedelta
from decimal import Decimal as D

import pytest

from tray_sync.dbfio import DbfTable
from tray_sync.state import State
from tray_sync.sync import Sincronizador
from tray_sync.tray import TrayClient
from .helpers import CAMPOS_PRO, escreve_dbf


# Resposta HTTP de mentira
class Resp(object):
    def __init__(self, status=200, dados=None):
        self.status_code, self._d, self.text = status, dados or {}, str(dados)

    def json(self):
        return self._d


class FakeTray(object):
    """Imita a web_api da Tray."""
    def __init__(self, produtos):
        self.produtos = produtos  # id -> reference
        self.puts = []
        self.token_valido = 'tok1'
        self.chamadas = []

    def request(self, method, url, params=None, json=None, timeout=None):
        self.chamadas.append((method, url))
        if url.endswith('/auth'):
            self.token_valido = 'tok2'
            return Resp(200, {'access_token': 'tok2', 'refresh_token': 'r2',
                              'date_expiration_access_token': '2099-01-01 00:00:00',
                              'date_expiration_refresh_token': '2099-01-01 00:00:00'})
        if params.get('access_token') != self.token_valido:
            return Resp(401, {'message': 'Unauthorized'})
        if method == 'GET' and url.rsplit('/', 1)[1] != 'products':   # produto unico
            pid = url.rsplit('/', 1)[1]
            return Resp(200, {'Product': {'id': pid, 'reference': self.produtos.get(int(pid), ''), 'name': 'x'}})
        if method == 'GET':
            itens = [{'Product': {'id': i, 'reference': ref, 'name': 'n'}} for i, ref in self.produtos.items()]
            pg, lim = params['page'], params['limit']
            return Resp(200, {'Products': itens[(pg - 1) * lim: pg * lim]})
        pid = url.rsplit('/', 1)[1]
        if pid not in [str(i) for i in self.produtos]:
            return Resp(404, {'message': 'not found'})
        self.puts.append((pid, json['Product']))
        return Resp(200, {})


# Cria Sincronizador + Tray falsa + DBF temporario. produtos = {id_tray: reference}
def monta(tmp_path, registros, produtos, token='tok1', extra=None):
    dbf = str(tmp_path / 'sacadpro.dbf')
    escreve_dbf(dbf, CAMPOS_PRO, registros)
    cfg = configparser.ConfigParser()
    cfg.read_dict({'dbf': {'produtos': dbf},
                   'tray': {'acrescimo_percent': '10'},
                   'sync': {}})
    state = State(str(tmp_path / 's.db'))
    state.set('access_token', token)
    state.set('refresh_token', 'r1')
    state.set('date_expiration_access_token', '2099-01-01 00:00:00')
    state.set('date_expiration_refresh_token', '2099-01-01 00:00:00')
    fake = FakeTray(produtos)
    tray = TrayClient('https://x/web_api', 'k', 's', 'c', state, session=fake,
                      intervalo=0, sleep=lambda s: None)
    return Sincronizador(cfg, state, tray), fake, dbf


# Casos: 1 igual / 2 saldo mudou / 3 preco mudou / 4 nao existe na Tray
REG = [
    {'CODPRO': '000001', 'SALDESTOQ': 5, 'SAL_HASH': 5, 'PREVENDA': '10', 'PRE_HASH': '10'},   # igual
    {'CODPRO': '000002', 'SALDESTOQ': 3, 'SAL_HASH': 9, 'PREVENDA': '20', 'PRE_HASH': '20'},   # saldo
    {'CODPRO': '000003', 'SALDESTOQ': 0, 'SAL_HASH': 0, 'PREVENDA': '30', 'PRE_HASH': '25'},   # preco
    {'CODPRO': '000004', 'SALDESTOQ': 1, 'SAL_HASH': 0, 'PREVENDA': '5', 'PRE_HASH': '5'},     # nao esta na Tray
]


# So o que mudou e enviado; hash gravado no DBF; 2o ciclo nao reenvia
def test_envia_so_o_que_mudou_e_grava_hash(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG, {10: '2', 11: '000003'})
    st = sinc.roda_uma_vez()
    assert (st.alterados, st.enviados, st.sem_tray) == (3, 2, 1)
    assert sorted(fake.puts) == [
        ('10', {'price': '22.00', 'stock': '3', 'available': '1'}),
        ('11', {'price': '33.00', 'stock': '0', 'available': '0'}),
    ]
    rows = dict(DbfTable(dbf).records(['SAL_HASH', 'PRE_HASH']))
    assert rows[1] == {'SAL_HASH': 3, 'PRE_HASH': D(20)}
    assert rows[2] == {'SAL_HASH': 0, 'PRE_HASH': D(30)}
    assert rows[3]['SAL_HASH'] == 0            # sem_tray: continua pendente
    # 2o ciclo: so sobra o que nao existe na Tray, sem novo PUT
    n = len(fake.puts)
    st = sinc.roda_uma_vez()
    assert (st.alterados, st.enviados, st.sem_tray) == (1, 0, 1)
    assert len(fake.puts) == n


# Token invalido (401): renova sozinho e repete o envio
def test_token_expirado_renova_e_repete(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '000002'}, token='velho')
    st = sinc.roda_uma_vez()
    assert st.enviados == 1
    assert sinc.state.get('access_token') == 'tok2'


# Erro da Tray: nao grava hash e entra em espera antes de tentar de novo
def test_falha_nao_grava_hash_e_aguarda_retry(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '000002'})
    sinc.tray.atualiza = lambda *a: (_ for _ in ()).throw(
        __import__('tray_sync.tray', fromlist=['x']).TrayHTTPError(400, 'x'))
    st = sinc.roda_uma_vez()
    assert (st.enviados, st.falhas) == (0, 1)
    assert dict(DbfTable(dbf).records(['SAL_HASH']))[0]['SAL_HASH'] == 9
    assert sinc.roda_uma_vez().falhas == 0   # em espera, nao martela a API


# Atingiu a cota diaria: nao envia nada
def test_limite_diario(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG[1:3], {10: '000002', 11: '000003'})
    sinc.tray.limite_diario = 0
    st = sinc.roda_uma_vez()
    assert st.enviados == 0 and fake.puts == []


# --dry-run: nao chama a Tray e nao altera o DBF
def test_dry_run_nao_toca_em_nada(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG, {10: '000002'})
    antes = open(dbf, 'rb').read()
    sinc.roda_uma_vez(dry_run=True)
    assert fake.chamadas == [] and open(dbf, 'rb').read() == antes


# --limite: envia so N produtos; os demais continuam pendentes para o proximo ciclo
def test_limite_envia_so_n(tmp_path):
    sinc, fake, dbf = monta(tmp_path, REG[1:3], {10: '000002', 11: '000003'})
    st = sinc.roda_uma_vez(limite=1)
    assert st.enviados == 1 and len(fake.puts) == 1
    assert sinc.roda_uma_vez().enviados == 1   # o outro vai no ciclo seguinte


# --procura: mostra o que a Tray tem para o codigo (ex.: reference sem zeros a esquerda)
def test_procura_mostra_produto(tmp_path, capsys):
    from tray_sync.sync import procura
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '19189', 11: 'ABC', 12: '', 13: '019189'})
    csv_path = str(tmp_path / 'lista.csv')
    procura(sinc, '019189', arq_csv=csv_path)
    saida = capsys.readouterr().out
    assert "reference='19189'" in saida and 'id=10' in saida
    assert 'com reference vazia ...........: 1' in saida
    assert 'references repetidas (ids diferentes com a mesma reference): 1' in saida   # 19189 e 019189
    assert open(csv_path, encoding='utf-8-sig').read().count('\n') == 5            # cabecalho + 4


# --produto: mostra os campos que a API devolve para um produto
def test_mostra_produto(tmp_path, capsys):
    from tray_sync.sync import mostra_produto
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '19189'})
    mostra_produto(sinc, '10')
    saida = capsys.readouterr().out
    assert "reference" in saida and "'19189'" in saida and '019189' in saida


# --info: mostra a loja autorizada (store_id/api_host) e o total de produtos, sem expor tokens
def test_mostra_info(tmp_path, capsys):
    from tray_sync.sync import mostra_info
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '19189'})
    mostra_info(sinc)
    saida = capsys.readouterr().out
    assert 'store_id' in saida and 'total de produtos' in saida
    assert 'tok2' not in saida and 'r2' not in saida


# --reautenticar: apaga tokens/mapa da loja antiga e autentica de novo com o code
def test_reautenticar_limpa_e_autentica(tmp_path, capsys):
    sinc, fake, dbf = monta(tmp_path, REG[1:2], {10: '19189'})
    sinc.state.replace_map([('019189', '10')])
    sinc.state.reset_autorizacao()
    assert sinc.state.map_size() == 0 and sinc.state.get('access_token') is None
    from tray_sync.sync import mostra_info
    mostra_info(sinc)                       # sem refresh_token -> autentica com o code (POST /auth)
    assert sinc.state.get('access_token') == 'tok2'
    assert ('POST', 'https://x/web_api/auth') in fake.chamadas
