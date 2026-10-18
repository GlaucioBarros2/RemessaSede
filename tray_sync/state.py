"""Estado local em SQLite (um arquivo simples, sem servidor).

Substitui as tabelas do PostgreSQL do sistema antigo:
  kv       -> tokens da Tray e data do ultimo recarregamento do mapa
  tray_map -> de/para: codigo do produto (6 digitos) -> id do produto na Tray
  falha    -> produtos que deram erro e quando podem ser tentados de novo
  cota     -> quantas requisicoes ja fizemos hoje (limite diario da Tray)
"""
import os
import sqlite3


class State(object):
    def __init__(self, path):
        existed = os.path.exists(path)
        self.db = sqlite3.connect(path)
        # cria as tabelas na primeira vez (se ja existirem, nao faz nada)
        self.db.executescript(
            'create table if not exists kv (k text primary key, v text);'
            'create table if not exists tray_map (codpro text primary key, tray_id text not null);'
            'create table if not exists falha (codpro text primary key, retry_em real, msg text);'
            'create table if not exists cota (dia text primary key, n integer);')
        if not existed:
            try:
                os.chmod(path, 0o600)  # arquivo guarda tokens: so o dono le
            except OSError:
                pass

    # ---- chave/valor (tokens etc.) ----
    def get(self, k, default=None):
        row = self.db.execute('select v from kv where k=?', (k,)).fetchone()
        return row[0] if row else default

    def set(self, k, v):
        self.db.execute('insert or replace into kv values (?,?)', (k, v))
        self.db.commit()

    # ---- mapa codigo -> id da Tray ----
    def replace_map(self, pares):
        """Troca o mapa inteiro de uma vez (pares = [(codpro, tray_id), ...])."""
        with self.db:
            self.db.execute('delete from tray_map')
            self.db.executemany('insert or replace into tray_map values (?,?)', pares)

    def tray_id(self, codpro):
        row = self.db.execute('select tray_id from tray_map where codpro=?', (codpro,)).fetchone()
        return row[0] if row else None

    def forget(self, codpro):
        """Esquece um produto (ex.: a Tray respondeu 404, foi apagado la)."""
        with self.db:
            self.db.execute('delete from tray_map where codpro=?', (codpro,))

    def map_size(self):
        return self.db.execute('select count(*) from tray_map').fetchone()[0]

    # ---- falhas: evita ficar martelando a API com um produto que da erro ----
    def fail(self, codpro, retry_em, msg):
        with self.db:
            self.db.execute('insert or replace into falha values (?,?,?)', (codpro, retry_em, msg))

    def clear_fail(self, codpro):
        with self.db:
            self.db.execute('delete from falha where codpro=?', (codpro,))

    def retry_em(self, codpro):
        """Instante (epoch) a partir do qual pode tentar de novo; 0 = sem restricao."""
        row = self.db.execute('select retry_em from falha where codpro=?', (codpro,)).fetchone()
        return row[0] if row else 0

    # ---- cota diaria de requisicoes ----
    def requests_today(self, dia):
        row = self.db.execute('select n from cota where dia=?', (dia,)).fetchone()
        return row[0] if row else 0

    def count_request(self, dia):
        with self.db:
            self.db.execute('insert or ignore into cota values (?,0)', (dia,))
            self.db.execute('update cota set n=n+1 where dia=?', (dia,))
