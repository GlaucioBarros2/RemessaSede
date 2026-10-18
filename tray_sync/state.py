"""Estado local em SQLite: tokens da Tray, mapa codigo->id, falhas e cota diaria."""
import os
import sqlite3


class State(object):
    def __init__(self, path):
        existed = os.path.exists(path)
        self.db = sqlite3.connect(path)
        self.db.executescript(
            'create table if not exists kv (k text primary key, v text);'
            'create table if not exists tray_map (codpro text primary key, tray_id text not null);'
            'create table if not exists falha (codpro text primary key, retry_em real, msg text);'
            'create table if not exists cota (dia text primary key, n integer);')
        if not existed:
            try:
                os.chmod(path, 0o600)  # guarda tokens
            except OSError:
                pass

    def get(self, k, default=None):
        row = self.db.execute('select v from kv where k=?', (k,)).fetchone()
        return row[0] if row else default

    def set(self, k, v):
        self.db.execute('insert or replace into kv values (?,?)', (k, v))
        self.db.commit()

    def replace_map(self, pares):
        with self.db:
            self.db.execute('delete from tray_map')
            self.db.executemany('insert or replace into tray_map values (?,?)', pares)

    def tray_id(self, codpro):
        row = self.db.execute('select tray_id from tray_map where codpro=?', (codpro,)).fetchone()
        return row[0] if row else None

    def forget(self, codpro):
        with self.db:
            self.db.execute('delete from tray_map where codpro=?', (codpro,))

    def map_size(self):
        return self.db.execute('select count(*) from tray_map').fetchone()[0]

    def fail(self, codpro, retry_em, msg):
        with self.db:
            self.db.execute('insert or replace into falha values (?,?,?)', (codpro, retry_em, msg))

    def clear_fail(self, codpro):
        with self.db:
            self.db.execute('delete from falha where codpro=?', (codpro,))

    def retry_em(self, codpro):
        row = self.db.execute('select retry_em from falha where codpro=?', (codpro,)).fetchone()
        return row[0] if row else 0

    def requests_today(self, dia):
        row = self.db.execute('select n from cota where dia=?', (dia,)).fetchone()
        return row[0] if row else 0

    def count_request(self, dia):
        with self.db:
            self.db.execute('insert or ignore into cota values (?,0)', (dia,))
            self.db.execute('update cota set n=n+1 where dia=?', (dia,))
