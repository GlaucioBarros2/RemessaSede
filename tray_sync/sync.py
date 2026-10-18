"""Le o sacadpro.dbf e envia a Tray os produtos cujo preco/saldo difere do hash."""
import argparse
import configparser
import logging
import logging.handlers
import os
import sys
import time
from collections import namedtuple
from datetime import datetime
from decimal import Decimal

from . import pricing
from .dbfio import DbfTable
from .state import State
from .tray import DailyLimitReached, TrayClient, TrayError, TrayHTTPError

log = logging.getLogger('tray_sync')

Change = namedtuple('Change', 'recno codpro stock preco_base row')
Stats = namedtuple('Stats', 'alterados enviados sem_tray falhas')

CAMPOS_BASE = ['CODPRO', 'SALDESTOQ', 'SAL_HASH', 'PREVENDA', 'PRE_HASH']
CAMPOS_ST = ['ICMNORMAL'] + ['UFICMRT%02d' % n for n in range(1, 28)] + ['ICMSRET%02d' % n for n in range(1, 28)]


def carrega_config(path):
    cp = configparser.ConfigParser()
    if not cp.read(path, encoding='utf-8'):
        raise SystemExit('config nao encontrado: %s' % path)
    return cp


def referencia(codigo):
    """Equivale ao right(,6) do Clipper usado para casar reference da Tray com o codpro."""
    return codigo.strip().zfill(6)[-6:]


class Sincronizador(object):
    def __init__(self, cfg, state, tray, stop_check=lambda: False, agora=time.time):
        d, s, t = cfg['dbf'], cfg['sync'], cfg['tray']
        self.dbf_path = d['produtos']
        self.dbf_agr = d.get('agregados', '').strip()
        self.encoding = d.get('encoding', 'cp850')
        self.uf = t.get('uf_st', 'PE')
        self.acrescimo = Decimal(t.get('acrescimo_percent', '0').replace(',', '.'))
        self.todos_slots = s.getboolean('st_todos_slots', fallback=False)
        self.retry_s = s.getint('retry_minutos', fallback=30) * 60
        self.remap_s = s.getint('remap_minutos', fallback=60) * 60
        self.state, self.tray, self.stop_check, self.agora = state, tray, stop_check, agora
        self._avisados = set()
        self._agr_cache = None

    # ---- DBF -------------------------------------------------------------
    def _tabela(self):
        tbl = DbfTable(self.dbf_path, self.encoding)
        tbl.require(CAMPOS_BASE)
        return tbl

    def acha_alteracoes(self):
        tbl = self._tabela()
        usa_st = bool(self.dbf_agr)
        campos = CAMPOS_BASE + (CAMPOS_ST if usa_st else [])
        if usa_st:
            tbl.require(CAMPOS_ST)
        mudou = []
        for recno, row in tbl.records(campos):
            zero = Decimal(0)
            # compara na precisao dos campos *_HASH, senao 10.005 vs 10.01 reenviaria sempre
            saldo = tbl.quantize('SAL_HASH', row['SALDESTOQ'] or zero)
            preco = tbl.quantize('PRE_HASH', row['PREVENDA'] or zero)
            if saldo != (row['SAL_HASH'] or zero) or preco != (row['PRE_HASH'] or zero):
                mudou.append(Change(recno, row['CODPRO'], saldo, preco, row))
        return tbl, mudou

    def carrega_agregados(self):
        """{(CODPRO, UF): AGRESUBST} so da UF da loja; relido apenas se o arquivo mudou."""
        if not self.dbf_agr:
            return {}
        st = os.stat(self.dbf_agr)
        chave = (st.st_mtime, st.st_size)
        if self._agr_cache and self._agr_cache[0] == chave:
            return self._agr_cache[1]
        tbl = DbfTable(self.dbf_agr, self.encoding)
        tbl.require(['CODPRO', 'UF', 'AGRESUBST'])
        agr = {}
        for _, r in tbl.records(['CODPRO', 'UF', 'AGRESUBST']):
            if r['UF'] == self.uf:
                agr.setdefault((r['CODPRO'], r['UF']), r['AGRESUBST'] or Decimal(0))
        self._agr_cache = (chave, agr)
        return agr

    # ---- mapa codigo -> id Tray -----------------------------------------
    def atualiza_mapa(self):
        pares = []
        for ref, tray_id, _nome in self.tray.lista_produtos():
            if ref.strip():
                pares.append((referencia(ref), tray_id))
        self.state.replace_map(pares)
        self.state.set('remap_ts', str(self.agora()))
        log.info('mapa Tray atualizado: %d produtos', len(pares))

    def _precisa_remapear(self):
        ult = self.state.get('remap_ts')
        return ult is None or self.agora() - float(ult) >= self.remap_s

    # ---- ciclo -----------------------------------------------------------
    def roda_uma_vez(self, dry_run=False):
        tbl, mudou = self.acha_alteracoes()
        if not mudou:
            return Stats(0, 0, 0, 0)
        log.info('%d produto(s) com preco/saldo alterado', len(mudou))
        agr = self.carrega_agregados()
        enviados = sem_tray = falhas = 0
        try:
            if not dry_run and any(self.state.tray_id(referencia(c.codpro)) is None for c in mudou) \
                    and self._precisa_remapear():
                self.atualiza_mapa()
            for c in mudou:
                if self.stop_check():
                    break
                chave = referencia(c.codpro)
                st = pricing.valor_st(c.row, agr, self.uf, self.todos_slots)
                preco = pricing.preco_final(c.row['PREVENDA'], st, self.acrescimo)
                estoque = max(c.stock, Decimal(0))
                if dry_run:
                    log.info('[dry-run] %s preco=%s estoque=%s', chave, preco, estoque)
                    continue
                if self.retry_em(chave) > self.agora():
                    continue
                tray_id = self.state.tray_id(chave)
                if tray_id is None:
                    sem_tray += 1
                    if chave not in self._avisados:
                        self._avisados.add(chave)
                        log.warning('produto %s nao existe na Tray (reference); cadastre la', chave)
                    continue
                try:
                    self.tray.atualiza(tray_id, '%.2f' % preco, format(estoque.normalize(), 'f'), estoque > 0)
                except TrayHTTPError as e:
                    falhas += 1
                    if e.status == 404:
                        self.state.forget(chave)
                    self.state.fail(chave, self.agora() + self.retry_s, str(e))
                    log.error('produto %s: %s', chave, e)
                    continue
                except DailyLimitReached:
                    raise
                except TrayError as e:
                    falhas += 1
                    self.state.fail(chave, self.agora() + self.retry_s, str(e))
                    log.error('produto %s: %s', chave, e)
                    continue
                self.state.clear_fail(chave)
                enviados += 1
                try:
                    tbl.write_numbers(c.recno, {'SAL_HASH': c.stock, 'PRE_HASH': c.preco_base})
                except (IOError, OSError, ValueError) as e:
                    # Tray ja foi atualizada; no proximo ciclo reenvia (idempotente)
                    log.error('produto %s: enviado, mas nao gravou hash no DBF: %s', chave, e)
        except DailyLimitReached as e:
            log.error('%s - retomando amanha', e)
        return Stats(len(mudou), enviados, sem_tray, falhas)

    def retry_em(self, chave):
        return self.state.retry_em(chave)


def monta(cfg, stop_check):
    s, t = cfg['sync'], cfg['tray']
    state = State(s.get('state_db', 'tray_sync.db'))
    tray = TrayClient(t['api_base'], t.get('consumer_key', ''), t.get('consumer_secret', ''),
                      t.get('code', ''), state,
                      intervalo=s.getfloat('intervalo_requisicao', fallback=0.4),
                      limite_diario=s.getint('limite_diario', fallback=9500))
    # primeira execucao: aproveita tokens ja existentes (se informados no ini)
    for k in ('access_token', 'refresh_token', 'date_expiration_access_token',
              'date_expiration_refresh_token'):
        if t.get(k) and not state.get(k):
            state.set(k, t[k])
    return Sincronizador(cfg, state, tray, stop_check)


def configura_log(arq):
    fmt = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    log.setLevel(logging.INFO)
    h = logging.StreamHandler()
    h.setFormatter(fmt)
    log.addHandler(h)
    if arq:
        fh = logging.handlers.RotatingFileHandler(arq, maxBytes=2000000, backupCount=5, encoding='utf-8')
        fh.setFormatter(fmt)
        log.addHandler(fh)


def main(argv=None):
    ap = argparse.ArgumentParser(prog='tray_sync')
    ap.add_argument('--config', default='config.ini')
    ap.add_argument('--once', action='store_true', help='roda um ciclo e sai')
    ap.add_argument('--dry-run', action='store_true', help='so mostra o que enviaria (nao chama a Tray nem grava o DBF)')
    ap.add_argument('--remap', action='store_true', help='baixa de novo o mapa codigo->id da Tray e sai')
    a = ap.parse_args(argv)

    cfg = carrega_config(a.config)
    s = cfg['sync']
    configura_log(s.get('log_file', 'tray_sync.log'))
    stop_file = s.get('stop_file', 'parar_sync.txt')

    def parar():
        if os.path.exists(stop_file):
            os.remove(stop_file)
            return True
        return False

    sinc = monta(cfg, parar)
    if a.remap:
        sinc.atualiza_mapa()
        return 0
    intervalo = s.getint('intervalo_segundos', fallback=60)
    log.info('tray_sync iniciado')
    while True:
        try:
            st = sinc.roda_uma_vez(dry_run=a.dry_run)
            if st.alterados:
                log.info('alterados=%d enviados=%d sem_tray=%d falhas=%d', *st)
        except Exception:
            log.exception('erro no ciclo')
        if a.once or a.dry_run:
            return 0
        for _ in range(intervalo):  # dorme em passos curtos para reagir ao arquivo de parada
            if sinc.stop_check():
                log.info('parada solicitada')
                return 0
            time.sleep(1)


if __name__ == '__main__':
    sys.exit(main())
