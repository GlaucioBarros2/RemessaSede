"""Calculo da substituicao tributaria (ICMS-ST) e do preco final.

E a traducao para Python da rotina AchaSubst do Delphi (UntEnviaContingencia.pas).
"""
from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal('0.01')  # 2 casas decimais
ZERO = Decimal(0)
# Codigos de ICMSRETnn que indicam retencao de ICMS (os mesmos '2,4,5' do Delphi)
CODIGOS_ST = ('2', '4', '5')


def aplica_st(row, uf, todos_slots=False):
    """Diz se o produto tem retencao de ICMS (codigo 2, 4 ou 5) para a UF.

    No cadastro do produto existem 27 "slots" (01..27), cada um com a UF
    (UFICMRTnn) e o codigo de retencao daquela UF (ICMSRETnn).

    ATENCAO - comportamento herdado do Delphi: ele so conseguia casar o slot 01.
    Nos slots 02..27 o codigo comparava ICMSRETnn (e nao UFICMRTnn) com 'PE', o que
    nunca e verdadeiro. Nos seus DBFs o 'PE' fica sempre no slot 01, entao o
    resultado e o mesmo. Por padrao mantemos so o slot 01; com todos_slots=True
    olhariamos os 27 (provavelmente a intencao original, mas muda precos).
    """
    slots = range(1, 28) if todos_slots else (1,)
    for n in slots:
        if ((row.get('UFICMRT%02d' % n) or '') == uf
                and (row.get('ICMSRET%02d' % n) or '') in CODIGOS_ST):
            return True
    return False


def valor_st(row, agregados, uf='PE', todos_slots=False):
    """Valor em reais do ICMS-ST a somar ao preco; 0 quando nao se aplica.

    agregados = {(CODPRO, UF): percentual} vindo do SACADAGR.DBF (campo AGRESUBST).
    Formula (a mesma do Delphi):
        icms1 = preco * aliquota / 100                       (ICMS normal)
        icms2 = (preco + preco*agregado/100) * aliquota/100  (ICMS sobre preco+agregado)
        ST    = icms2 - icms1                                (diferenca)
    """
    if not aplica_st(row, uf, todos_slots):
        return ZERO
    # percentual de agregado deste produto nesta UF (0 se nao houver cadastro)
    magre = agregados.get(((row.get('CODPRO') or ''), uf), ZERO)
    if magre <= 0:
        return ZERO
    preco = row.get('PREVENDA') or ZERO
    icms_normal = row.get('ICMNORMAL') or ZERO  # aliquota de ICMS normal (ex.: 20.50)
    icms1 = preco / 100 * icms_normal
    icms2 = (preco + preco / 100 * magre) / 100 * icms_normal
    return icms2 - icms1


def preco_final(prevenda, st, acrescimo_pct):
    """Preco enviado a Tray: (PREVENDA + ST) + acrescimo %, arredondado em 2 casas.

    O acrescimo era o campo 'acrescimo' da tabela produtos_parametro; agora vem do
    config.ini (acrescimo_percent).
    """
    base = (prevenda or ZERO) + st
    return (base + base / 100 * acrescimo_pct).quantize(CENT, ROUND_HALF_UP)
