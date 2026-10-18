import struct
from decimal import Decimal


def escreve_dbf(path, campos, registros, deletados=()):
    """campos: [(nome, tipo, tamanho, decimais)]; registros: lista de dicts."""
    rec_len = 1 + sum(c[2] for c in campos)
    head_len = 32 + 32 * len(campos) + 1
    out = bytearray(struct.pack('<BBBBIHH', 3, 126, 1, 1, len(registros), head_len, rec_len) + b'\0' * 20)
    for nome, tipo, tam, dec in campos:
        out += nome.encode().ljust(11, b'\0') + tipo.encode() + b'\0' * 4 + bytes([tam, dec]) + b'\0' * 14
    out += b'\r'
    for i, r in enumerate(registros):
        out += b'*' if i in deletados else b' '
        for nome, tipo, tam, dec in campos:
            v = r.get(nome, '')
            if tipo == 'N':
                txt = '' if v == '' else format(Decimal(str(v)), '.%df' % dec)
                out += txt.rjust(tam).encode()
            else:
                out += str(v).ljust(tam).encode('cp850')
    out += b'\x1a'
    with open(path, 'wb') as f:
        f.write(out)


CAMPOS_PRO = [('CODPRO', 'C', 6, 0), ('DESCPRO', 'C', 20, 0), ('SALDESTOQ', 'N', 8, 0),
              ('SAL_HASH', 'N', 8, 0), ('PREVENDA', 'N', 10, 2), ('PRE_HASH', 'N', 10, 2)]
