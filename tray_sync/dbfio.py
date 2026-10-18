"""Leitura e escrita minima de arquivos DBF (dBase III / Clipper / Apollo).

Por que existe: no sistema antigo o Delphi usava ODBC para ler o DBF. Aqui lemos
o arquivo direto, byte a byte, sem driver nenhum.

Estrutura de um DBF (resumo para lembrar):
  - Cabecalho de 32 bytes: no byte 8 fica o tamanho do cabecalho (2 bytes) e no
    byte 10 o tamanho de cada registro (2 bytes).
  - Depois vem 1 descritor de 32 bytes por campo (nome, tipo, tamanho, decimais),
    terminado por um byte 0x0D.
  - Depois vem os registros, um atras do outro. O 1o byte de cada registro e o
    "flag de deletado" (espaco = ativo, '*' = deletado); os campos vem em seguida,
    todos em texto, ocupando exatamente o tamanho definido.

Na escrita mexemos *somente* nos bytes do campo desejado (nao regravamos o
cabecalho nem outros campos), para conviver com o sistema legado que mantem o
arquivo aberto ao mesmo tempo.
"""
import struct
from collections import OrderedDict, namedtuple
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

# Descricao de um campo: offset = posicao do campo dentro do registro
Field = namedtuple('Field', 'name type length decimals offset')

# Primeiro byte do registro quando ele esta deletado
DELETED = 0x2A  # '*'


class DbfTable(object):
    def __init__(self, path, encoding='cp850'):
        self.path = path
        self.encoding = encoding  # codificacao dos campos texto (Clipper costuma ser cp850)
        self._read_header()

    def _read_header(self):
        """Le o cabecalho e monta a lista de campos (self.fields)."""
        with open(self.path, 'rb') as f:
            head = f.read(32)
            if len(head) < 32:
                raise ValueError('DBF invalido (cabecalho curto): %s' % self.path)
            # bytes 8-9: tamanho do cabecalho; bytes 10-11: tamanho do registro
            self.header_len, self.record_len = struct.unpack('<HH', head[8:12])
            self.fields = OrderedDict()
            offset = 1  # o byte 0 de cada registro e o flag de deletado
            f.seek(32)
            while True:
                desc = f.read(32)
                # 0x0D marca o fim da lista de campos
                if len(desc) < 32 or desc[0:1] == b'\r':
                    break
                # nome: 11 bytes terminados em NUL; sempre guardamos em MAIUSCULAS
                name = desc[:11].split(b'\x00')[0].decode('ascii', 'replace').upper()
                length, decimals = desc[16], desc[17]
                self.fields[name] = Field(name, chr(desc[11]), length, decimals, offset)
                offset += length

    def require(self, names):
        """Garante que os campos existem; senao avisa claramente quais faltam."""
        faltando = [n for n in names if n.upper() not in self.fields]
        if faltando:
            raise KeyError('campos ausentes em %s: %s' % (self.path, ', '.join(faltando)))

    def _record_count(self, f):
        """Quantidade de registros calculada pelo tamanho do arquivo.

        Nao confiamos no contador do cabecalho porque o sistema legado pode estar
        gravando registros novos e so atualizar o cabecalho depois. O byte final
        0x1A (marca de fim de arquivo) some na divisao inteira.
        """
        f.seek(0, 2)
        return max(0, (f.tell() - self.header_len) // self.record_len)

    def _parse(self, field, raw):
        """Converte os bytes de um campo para o tipo Python adequado."""
        if field.type in ('N', 'F'):  # numerico -> Decimal (nao perde centavos)
            txt = raw.decode('ascii', 'replace').strip()
            if not txt or '*' in txt:  # vazio ou estouro ('****') -> sem valor
                return None
            try:
                return Decimal(txt)
            except InvalidOperation:
                return None
        if field.type == 'L':  # logico
            return raw.strip().upper() in (b'T', b'Y', b'S')
        # texto (e datas, que aqui nao usamos): decodifica e tira espacos das pontas
        return raw.decode(self.encoding, 'replace').strip()

    def records(self, names):
        """Gera (recno, {CAMPO: valor}) dos registros nao deletados.

        recno comeca em 0 (e a posicao fisica no arquivo, usada depois para gravar).
        Le o arquivo em blocos de 1000 registros para ser rapido em arquivos grandes.
        """
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
                    if rec[0] != DELETED:  # ignora registros deletados
                        yield recno + i, dict(
                            (c.name, self._parse(c, rec[c.offset:c.offset + c.length]))
                            for c in cols)
                recno += n

    def quantize(self, name, value):
        """Arredonda value para as casas decimais do campo (ex.: 10.005 -> 10.01)."""
        fld = self.fields[name.upper()]
        return Decimal(value).quantize(Decimal(1).scaleb(-fld.decimals), ROUND_HALF_UP)

    def write_numbers(self, recno, values):
        """Grava campos numericos do registro recno (a partir de 0).

        values = {'SAL_HASH': Decimal, ...}. Escreve so os bytes de cada campo,
        alinhados a direita e completados com espacos, como o Clipper faz.
        """
        with open(self.path, 'r+b') as f:
            for name, value in values.items():
                fld = self.fields[name.upper()]
                txt = format(self.quantize(name, value), 'f').rjust(fld.length)
                if len(txt) > fld.length:
                    raise ValueError('valor %s nao cabe no campo %s' % (value, fld.name))
                # posicao = cabecalho + registros anteriores + deslocamento do campo
                f.seek(self.header_len + recno * self.record_len + fld.offset)
                f.write(txt.encode('ascii'))
