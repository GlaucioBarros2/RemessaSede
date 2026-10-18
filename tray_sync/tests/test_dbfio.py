"""Testes da leitura/escrita de DBF."""
from decimal import Decimal

from tray_sync.dbfio import DbfTable
from .helpers import CAMPOS_PRO, escreve_dbf


# Le valores corretamente, ignora registro deletado e preserva acentos
def test_le_pula_deletados_e_acentos(tmp_path):
    p = str(tmp_path / 'sacadpro.dbf')
    escreve_dbf(p, CAMPOS_PRO, [
        {'CODPRO': '000001', 'DESCPRO': 'CAMISETA AÇÃO', 'SALDESTOQ': 5, 'PREVENDA': '10.50'},
        {'CODPRO': '000002', 'SALDESTOQ': 1},
        {'CODPRO': '000003', 'SALDESTOQ': 2, 'PREVENDA': '3'},
    ], deletados=(1,))
    t = DbfTable(p)
    rows = list(t.records(['CODPRO', 'DESCPRO', 'SALDESTOQ', 'PREVENDA', 'PRE_HASH']))
    assert [r[0] for r in rows] == [0, 2]
    assert rows[0][1]['DESCPRO'] == 'CAMISETA AÇÃO'
    assert rows[0][1]['PREVENDA'] == Decimal('10.50')
    assert rows[0][1]['PRE_HASH'] is None


# Gravar o hash so pode alterar os bytes de SAL_HASH/PRE_HASH do registro certo
def test_escrita_no_lugar_nao_mexe_no_resto(tmp_path):
    p = str(tmp_path / 'a.dbf')
    escreve_dbf(p, CAMPOS_PRO, [{'CODPRO': '000001', 'SALDESTOQ': 5, 'PREVENDA': '10.5'},
                                {'CODPRO': '000002', 'SALDESTOQ': 7, 'PREVENDA': '2'}])
    antes = open(p, 'rb').read()
    t = DbfTable(p)
    t.write_numbers(1, {'SAL_HASH': Decimal(7), 'PRE_HASH': Decimal('2')})
    depois = open(p, 'rb').read()
    assert len(antes) == len(depois)
    diff = [i for i in range(len(antes)) if antes[i] != depois[i]]
    f1, f2 = t.fields['SAL_HASH'], t.fields['PRE_HASH']
    base = t.header_len + t.record_len
    assert all(base + f1.offset <= i < base + f2.offset + f2.length for i in diff)
    r = dict(t.records(['SAL_HASH', 'PRE_HASH']))
    assert r[1] == {'SAL_HASH': Decimal(7), 'PRE_HASH': Decimal('2.00')}
    assert r[0] == {'SAL_HASH': None, 'PRE_HASH': None}
