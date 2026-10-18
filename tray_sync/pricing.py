"""Calculo da substituicao tributaria (ICMS-ST) - port de TFrmAtualizaSubst.AchaSubst."""
from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal('0.01')
ZERO = Decimal(0)
CODIGOS_ST = ('2', '4', '5')


def aplica_st(row, uf, todos_slots=False):
    """True se o produto tem retencao de ICMS (codigo 2, 4 ou 5) para a UF.

    O Delphi original so conseguia casar o slot 01: nos slots 02..27 comparava
    ICMSRETnn (e nao UFICMRTnn) com 'PE', o que nunca e verdadeiro. Por padrao
    mantemos esse comportamento; todos_slots=True aplica a regra aparentemente
    pretendida (UFICMRT01..27).
    """
    slots = range(1, 28) if todos_slots else (1,)
    for n in slots:
        if ((row.get('UFICMRT%02d' % n) or '') == uf
                and (row.get('ICMSRET%02d' % n) or '') in CODIGOS_ST):
            return True
    return False


def valor_st(row, agregados, uf='PE', todos_slots=False):
    """Valor do ICMS-ST a somar ao preco; 0 quando nao se aplica."""
    if not aplica_st(row, uf, todos_slots):
        return ZERO
    magre = agregados.get(((row.get('CODPRO') or ''), uf), ZERO)
    if magre <= 0:
        return ZERO
    preco = row.get('PREVENDA') or ZERO
    icms_normal = row.get('ICMNORMAL') or ZERO
    icms1 = preco / 100 * icms_normal
    icms2 = (preco + preco / 100 * magre) / 100 * icms_normal
    return icms2 - icms1


def preco_final(prevenda, st, acrescimo_pct):
    """(prevenda + ST) com o acrescimo percentual da loja, em 2 casas."""
    base = (prevenda or ZERO) + st
    return (base + base / 100 * acrescimo_pct).quantize(CENT, ROUND_HALF_UP)
