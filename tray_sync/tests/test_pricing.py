"""Testes do calculo de ICMS-ST e do preco final."""
from decimal import Decimal as D

from tray_sync import pricing


# Monta um registro de produto de teste (preco 100, ICMS normal 18%)
def row(**kw):
    base = {'CODPRO': '000001', 'PREVENDA': D(100), 'ICMNORMAL': D(18)}
    base.update(kw)
    return base


# Conta conferida a mao: 100 + 40% = 140; 140*18% = 25,20; menos 18,00 = 7,20
def test_st_slot1():
    r = row(UFICMRT01='PE', ICMSRET01='4')
    assert pricing.valor_st(r, {('000001', 'PE'): D(40)}) == D('7.2')


# Nao soma ST quando: codigo de retencao nao e 2/4/5, UF diferente ou sem agregado
def test_sem_agregado_ou_codigo_nao_aplica():
    ag = {('000001', 'PE'): D(40)}
    assert pricing.valor_st(row(UFICMRT01='PE', ICMSRET01='1'), ag) == 0
    assert pricing.valor_st(row(UFICMRT01='SP', ICMSRET01='4'), ag) == 0
    assert pricing.valor_st(row(UFICMRT01='PE', ICMSRET01='4'), {}) == 0


# PE no slot 03 so conta se ligarmos st_todos_slots
def test_slots_extras_so_com_flag():
    r = row(UFICMRT01='SP', ICMSRET01='1', UFICMRT03='PE', ICMSRET03='5')
    ag = {('000001', 'PE'): D(40)}
    assert pricing.valor_st(r, ag) == 0
    assert pricing.valor_st(r, ag, todos_slots=True) == D('7.2')


# Acrescimo de 10% e arredondamento em 2 casas
def test_preco_final_arredonda():
    assert pricing.preco_final(D(100), D('7.2'), D(10)) == D('117.92')
    assert pricing.preco_final(D('10.005'), D(0), D(0)) == D('10.01')
