"""Leitura e escrita minima de arquivos DBF (dBase III/Clipper/Apollo).

Le registros direto do arquivo e grava campos numericos *no lugar*, mexendo
somente nos bytes do campo (cabecalho e demais campos ficam intactos), para
nao atrapalhar o sistema legado que mantem o arquivo aberto.
"""
import struct
from collections import OrderedDict, namedtuple
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

Field = namedtuple('Field', 'name type length decimals offset')

DELETED = 0x2A


class DbfTable(object):
    def __init__(self, path, encoding='cp850'):
        self.path = path
        self.encoding = encoding
        self._read_header()

    def _read_header(self):
        with open(self.path, 'rb') as f:
            head = f.read(32)
            if len(head) < 32:
                raise ValueError('DBF invalido (cabecalho curto): %s' % self.path)
            self.header_len, self.record_len = struct.unpack('<HH', head[8:12])
            self.fields = OrderedDict()
            offset = 1  # byte 0 de cada registro e o flag de deletado
            f.seek(32)
            while True:
                desc = f.read(32)
                if len(desc) < 32 or desc[0:1] == b'\r':
                    break
                name = desc[:11].split(b'\x00')[0].decode('ascii', 'replace').upper()
                length, decimals = desc[16], desc[17]
                self.fields[name] = Field(name, chr(desc[11]), length, decimals, offset)
                offset += length

    def require(self, names):
        faltando = [n for n in names if n.upper() not in self.fields]
        if faltando:
            raise KeyError('campos ausentes em %s: %s' % (self.path, ', '.join(faltando)))

    def _record_count(self, f):
        f.seek(0, 2)
        return max(0, (f.tell() - self.header_len) // self.record_len)

    def _parse(self, field, raw):
        if field.type in ('N', 'F'):
            txt = raw.decode('ascii', 'replace').strip()
            if not txt or '*' in txt:
                return None
            try:
                return Decimal(txt)
            except InvalidOperation:
                return None
        if field.type == 'L':
            return raw.strip().upper() in (b'T', b'Y', b'S')
        return raw.decode(self.encoding, 'replace').strip()

    def records(self, names):
        """Gera (recno, {CAMPO: valor}) dos registros nao deletados, recno a partir de 0."""
        cols = [self.fields[n.upper()] for n in names]
        chunk = 1000
        with open(self.path, 'rb') as f:
            total = self._record_count(f)
            f.seek(self.header_len)
            recno = 0
            while recno < total:
                n = min(chunk, total - recno)
                data = f.read(n * self.record_len)
                for i in range(len(data) // self.record_len):
                    rec = data[i * self.record_len:(i + 1) * self.record_len]
                    if rec[0] != DELETED:
                        yield recno + i, dict(
                            (c.name, self._parse(c, rec[c.offset:c.offset + c.length]))
                            for c in cols)
                recno += n

    def quantize(self, name, value):
        """Arredonda value para as casas decimais do campo numerico."""
        fld = self.fields[name.upper()]
        return Decimal(value).quantize(Decimal(1).scaleb(-fld.decimals), ROUND_HALF_UP)

    def write_numbers(self, recno, values):
        """Grava campos numericos do registro recno (a partir de 0), so os bytes do campo."""
        with open(self.path, 'r+b') as f:
            for name, value in values.items():
                fld = self.fields[name.upper()]
                txt = format(self.quantize(name, value), 'f').rjust(fld.length)
                if len(txt) > fld.length:
                    raise ValueError('valor %s nao cabe no campo %s' % (value, fld.name))
                f.seek(self.header_len + recno * self.record_len + fld.offset)
                f.write(txt.encode('ascii'))
