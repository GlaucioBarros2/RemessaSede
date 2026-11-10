{-------------------------------------------------------------------------
  uRetorno.pas

  Porte para Delphi do DATARET2.PRG (Clipper). Processa, sem intervencao
  manual, um arquivo de retorno CNAB240 (*.RET ou RETORNO_*.TXT):

    1. Le o arquivo e, para cada titulo (segmento T + segmento U):
       - localiza o titulo em SACADTIT (indice 13 = nosso numero);
       - atualiza SACADTIT->RETBANCO com a ultima ocorrencia do banco
         (antiga IMPR_ARQ);
       - monta as linhas do relatorio (antigo LOTB_nnn.PRN, agora PDF);
       - para liquidacoes (codigo 06 e 17) de titulos em aberto
         (SITTIT AB, PC ou PB) monta o item do lote de baixa
         (antiga F_CAPTURATIT).
    2. Grava o relatorio  <PastaPDF>\LOTB_nnn.pdf
    3. Grava o lote       <PastaDados>\LOTBAIXA.nnn  (DBF)
    4. Soma 1 em SACADEMP->NUMLOTBAI
    5. Renomeia o arquivo de retorno para .XXX

  As posicoes dos campos do CNAB240 e as regras sao as mesmas do programa
  Clipper.
-------------------------------------------------------------------------}
unit uRetorno;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Math,
  System.Generics.Collections, System.Generics.Defaults, System.Types,
  System.DateUtils,
  Data.DB, uDM, uPdfRel;

type
  TConfigRetorno = record
    PastaRetorno: string;   // onde chegam os *.RET / RETORNO_*.TXT
    PastaDados: string;     // onde sera gravado o LOTBAIXA.nnn
    PastaPDF: string;       // onde sera gravado o LOTB_nnn.pdf
  end;

  TProcessadorRetorno = class
  private
    type
      // linha do relatorio (antigo AUX_RET.DBF)
      TItemAux = record
        Seq: Integer;
        Ordem, NumMov, SitTit, NossoNum, CodMov, Identif: string;
        DtVenc, DtCred: TDateTime;
        ValBruto, ValPago, ValCred, Juros, Desc, ValTarif, Iof: Double;
      end;
      // item do lote de baixa (antigo LOTBAIXA.nnn)
      TItemLote = record
        NumMov, TipoDoc, CodCli, CodPor, SitTit, SitTit2, Cobrador, ModoBaixa: string;
        NossoNum, Identif, CodMov: string;
        DtPagto, DtVencto, DtOcorr, DtCred: TDateTime;
        ValPago, ValDesJur, SalDevTit, ValCred, ValBruto, ValTarif: Double;
        Juros, Desc, Abat, Iof: Double;
      end;
  private
    FDM: TdmDados;
    FCfg: TConfigRetorno;
    FAux: TList<TItemAux>;
    FLote: TList<TItemLote>;
    FFSus: TFormatSettings;
    FFSbr: TFormatSettings;
    function LerLinhas(const AArq: string): TStringList;
    function ValClip(const AInt, ADec: string): Double;
    function DataCnab(const ADia, AMes, AAno2: string): TDateTime;
    function AcharTitulo(const ANossoNum: string): Boolean;
    function TextoRetBanco(const ACodMov: string): string;
    function TextoRel(const ACodMov: string): string;
    function OrdemImpr(const ACodMov: string): string;
    function Nota47(const ACodMov: string): string;
    procedure AtualizaRetBanco(const ACodMov, AIdentif: string);
    procedure GravaLote(const AArq, ANumLote: string; ADtPagto: TDateTime;
      AValPago: Double; ANumTit: Integer; ACapaPreenchida: Boolean);
    procedure GravaPDF(const AArqRetorno, ANumLote: string);
    function Pic(AValor: Double; ALarg: Integer): string;
    function DtRel(ADt: TDateTime): string;
    function Fmt(const S: string; ALarg: Integer): string;
    function NomeLivre(const AArq: string): string;
  public
    constructor Create(ADM: TdmDados; const ACfg: TConfigRetorno);
    destructor Destroy; override;
    // Lista os arquivos de retorno da pasta, do mais antigo para o mais novo
    function ListarArquivos: TArray<string>;
    // True se o arquivo nao esta mais sendo gravado por outro programa
    function ArquivoEstavel(const AArq: string): Boolean;
    // Processa um arquivo; devolve resumo. Levanta Exception em caso de erro.
    function Processar(const AArq: string): string;
  end;

implementation

const
  COD_LIQUIDACAO = '06,17';

function CodEm(const ACod, ALista: string): Boolean;
begin
  Result := Pos(',' + ACod + ',', ',' + ALista + ',') > 0;
end;

function StrZero(N, Tam: Integer): string;
begin
  Result := IntToStr(N);
  while Length(Result) < Tam do
    Result := '0' + Result;
end;

// arredonda a 2 casas "para cima" como o STR() do Clipper
function Arr2(V: Double): Int64;
begin
  if V >= 0 then
    Result := Floor(V * 100 + 0.5)
  else
    Result := -Floor(-V * 100 + 0.5);
end;

{ TProcessadorRetorno }

constructor TProcessadorRetorno.Create(ADM: TdmDados; const ACfg: TConfigRetorno);
begin
  inherited Create;
  FDM := ADM;
  FCfg := ACfg;
  FCfg.PastaRetorno := IncludeTrailingPathDelimiter(FCfg.PastaRetorno);
  FCfg.PastaDados   := IncludeTrailingPathDelimiter(FCfg.PastaDados);
  FCfg.PastaPDF     := IncludeTrailingPathDelimiter(FCfg.PastaPDF);
  FAux  := TList<TItemAux>.Create;
  FLote := TList<TItemLote>.Create;
  FFSus := TFormatSettings.Create('en-US');
  FFSbr := TFormatSettings.Create('en-US');
  FFSbr.DecimalSeparator := ',';
  FFSbr.ThousandSeparator := '.';
end;

destructor TProcessadorRetorno.Destroy;
begin
  FAux.Free;
  FLote.Free;
  inherited;
end;

{------------------------------------------------------------------------
  Arquivos candidatos: *.RET  e  RETORNO_*.TXT (nomes longos, ex.:
  RETORNO_500EDES12345678001.TXT). O filtro extra pela extensao evita o
  casamento indevido com nomes curtos 8.3 (ex.: "*.RET" casando .RETX).
------------------------------------------------------------------------}
function TProcessadorRetorno.ListarArquivos: TArray<string>;
type
  TArqData = record
    Nome: string;
    Data: TDateTime;
  end;
var
  lista: TList<TArqData>;
  cArq: string;
  aTmp: TStringDynArray;
  ad: TArqData;
  aOrd: TArray<TArqData>;
  i: Integer;

  function Ja(const ANome: string): Boolean;
  var
    k: Integer;
  begin
    Result := False;
    for k := 0 to lista.Count - 1 do
      if SameText(lista[k].Nome, ANome) then
        Exit(True);
  end;

begin
  SetLength(Result, 0);
  if not TDirectory.Exists(FCfg.PastaRetorno) then
    Exit;

  lista := TList<TArqData>.Create;
  try
    aTmp := TDirectory.GetFiles(FCfg.PastaRetorno, '*.RET');
    for cArq in aTmp do
      if SameText(ExtractFileExt(cArq), '.RET') and not Ja(cArq) then
      begin
        ad.Nome := cArq;
        ad.Data := TFile.GetLastWriteTime(cArq);
        lista.Add(ad);
      end;

    aTmp := TDirectory.GetFiles(FCfg.PastaRetorno, 'RETORNO_*.TXT');
    for cArq in aTmp do
      if SameText(ExtractFileExt(cArq), '.TXT') and not Ja(cArq) then
      begin
        ad.Nome := cArq;
        ad.Data := TFile.GetLastWriteTime(cArq);
        lista.Add(ad);
      end;

    // mais antigo primeiro (data/hora de gravacao), desempate pelo nome
    aOrd := lista.ToArray;
    TArray.Sort<TArqData>(aOrd, TComparer<TArqData>.Construct(
      function(const A, B: TArqData): Integer
      begin
        Result := CompareDateTime(A.Data, B.Data);
        if Result = 0 then
          Result := CompareText(A.Nome, B.Nome);
      end));

    SetLength(Result, Length(aOrd));
    for i := 0 to High(aOrd) do
      Result[i] := aOrd[i].Nome;
  finally
    lista.Free;
  end;
end;

function TProcessadorRetorno.ArquivoEstavel(const AArq: string): Boolean;
var
  fs: TFileStream;
begin
  Result := False;
  // ainda sendo copiado/gravado? espera 5 s sem alteracao
  if (Now - TFile.GetLastWriteTime(AArq)) < (5 / 86400) then
    Exit;
  try
    fs := TFileStream.Create(AArq, fmOpenRead or fmShareExclusive);
    fs.Free;
    Result := True;
  except
    Result := False;
  end;
end;

{------------------------------------------------------------------------
  Le o arquivo em memoria, aceitando fim de linha CRLF, LF ou CR.
  Linhas vazias sao descartadas.
------------------------------------------------------------------------}
function TProcessadorRetorno.LerLinhas(const AArq: string): TStringList;
var
  b: TBytes;
  s, cLin: string;
  i: Integer;
begin
  Result := TStringList.Create;
  try
    b := TFile.ReadAllBytes(AArq);
    if Length(b) = 0 then
      Exit;
    s := TEncoding.Default.GetString(b);
    cLin := '';
    for i := 1 to Length(s) do
    begin
      case s[i] of
        #13, #10:
          begin
            if cLin <> '' then
              Result.Add(cLin);
            cLin := '';
          end;
        #26: ; // Ctrl-Z de fim de arquivo
      else
        cLin := cLin + s[i];
      end;
    end;
    if cLin <> '' then
      Result.Add(cLin);
  except
    Result.Free;
    raise;
  end;
end;

// equivale a  val(SubStr(r,p,13)+"."+SubStr(r,q,02))
function TProcessadorRetorno.ValClip(const AInt, ADec: string): Double;
begin
  Result := StrToFloatDef(Trim(AInt) + '.' + Trim(ADec), 0, FFSus);
end;

// equivale a CtoD(dd/mm/aa) com SET EPOCH TO 1960
function TProcessadorRetorno.DataCnab(const ADia, AMes, AAno2: string): TDateTime;
var
  d, m, a: Integer;
begin
  Result := 0;
  d := StrToIntDef(ADia, 0);
  m := StrToIntDef(AMes, 0);
  a := StrToIntDef(AAno2, -1);
  if a < 0 then
    Exit;
  if a >= 60 then a := 1900 + a else a := 2000 + a;
  if not TryEncodeDate(a, m, d, Result) then
    Result := 0;
end;

function TProcessadorRetorno.AcharTitulo(const ANossoNum: string): Boolean;
var
  k, v: string;
begin
  Result := False;
  k := Trim(ANossoNum);
  if k = '' then
    Exit;
  FDM.ATTit.SetOrder(13);
  FDM.ATTit.Seek(k);
  if FDM.ATTit.Eof then
    Exit;
  v := Trim(FDM.ATTit.FieldByName('NOSSONUM').AsString);
  Result := Pos(k, v) = 1;       // seek "nao exato" do Clipper
end;

{------------------------------------------------------------------------
  Tabelas de codigos de movimento (tabela 40 do CNAB240)
------------------------------------------------------------------------}
function TProcessadorRetorno.TextoRetBanco(const ACodMov: string): string;
const
  T: array[0..21] of array[0..1] of string = (
    ('02','Entr Confirm '), ('03','Entr Rejeit  '), ('04','Tranf.Cart/en'),
    ('05','Tranf.Cart/ba'), ('06','Liquidacao   '), ('09','Baixa        '),
    ('11','Tit carteira '), ('12','Conf Abatim. '), ('13','Conf Can Abat'),
    ('14','Conf Vencto  '), ('15','Franco Pag   '), ('17','Liquidacao   '),
    ('19','Conf protesto'), ('20','canc. Prot.  '), ('23','Remessa cart '),
    ('24','Retir.cart   '), ('25','Prot baixado '), ('26','Instr rejeit '),
    ('27','Alt dos dados'), ('28','Deb tarifas  '), ('29','Ocorr sacado '),
    ('30','Alt. dados   '));
var
  i: Integer;
begin
  Result := '';
  for i := Low(T) to High(T) do
    if T[i][0] = ACodMov then
      Exit(T[i][1]);
end;

function TProcessadorRetorno.TextoRel(const ACodMov: string): string;
const
  T: array[0..21] of array[0..1] of string = (
    ('02','Entr Confirm '), ('03','Entr Rejeit'), ('04','Tranf.Cart/en'),
    ('05','Tranf.Cart/ba'), ('06','Liquidacao'), ('09','Baixa'),
    ('11','Tit carteira'), ('12','Conf Abatim.'), ('13','Conf C. Abat'),
    ('14','Conf Vencto'), ('15','Franco Pag'), ('17','Liquidacao'),
    ('19','Conf protesto'), ('20','canc. Prot.'), ('23','Remessa cart'),
    ('24','Retir.cart'), ('25','Prot baixado'), ('26','Instr regeit'),
    ('27','Alt dos dados'), ('28','Deb tarifas'), ('29','Ocorr sacado'),
    ('30','Alt. dados '));
var
  i: Integer;
begin
  Result := '';
  for i := Low(T) to High(T) do
    if T[i][0] = ACodMov then
      Exit(T[i][1]);
end;

function TProcessadorRetorno.OrdemImpr(const ACodMov: string): string;
const
  T: array[0..20] of array[0..1] of string = (
    ('02','05'), ('03','06'), ('04','07'), ('05','08'), ('06','00'),
    ('09','03'), ('11','11'), ('12','12'), ('13','13'), ('14','14'),
    ('15','15'), ('17','00'), ('19','19'), ('20','20'), ('23','23'),
    ('24','24'), ('25','25'), ('26','26'), ('27','01'), ('28','02'),
    ('29','29'));
var
  i: Integer;
begin
  if ACodMov = '30' then
    Exit('01');
  Result := '';
  for i := Low(T) to High(T) do
    if T[i][0] = ACodMov then
      Exit(T[i][1]);
end;

// legenda dos codigos de erro (47a/47b/47c) impressa na ultima coluna
function TProcessadorRetorno.Nota47(const ACodMov: string): string;
begin
  if CodEm(ACodMov, '03,26,30') then Result := '47a'
  else if CodEm(ACodMov, '28') then Result := '47b'
  else if CodEm(ACodMov, '06,09,17') then Result := '47c'
  else Result := '';
end;

{------------------------------------------------------------------------
  Grava em SACADTIT->RETBANCO a ultima ocorrencia retornada pelo banco
  (titulo ja posicionado). Nao sobrescreve o que ja existe quando a nova
  ocorrencia for "03 - entrada rejeitada".
------------------------------------------------------------------------}
procedure TProcessadorRetorno.AtualizaRetBanco(const ACodMov, AIdentif: string);
var
  cTxt: string;
begin
  if (Trim(FDM.ATTit.FieldByName('RETBANCO').AsString) = '') or (ACodMov <> '03') then
  begin
    cTxt := Copy(TextoRetBanco(ACodMov), 1, 13) + ' - ' + AIdentif + ' ' + Nota47(ACodMov);
    FDM.ATTit.Edit;
    FDM.ATTit.FieldByName('RETBANCO').AsString := cTxt;
    FDM.ATTit.Post;
  end;
end;

function TProcessadorRetorno.NomeLivre(const AArq: string): string;
var
  cBase, cExt: string;
  n: Integer;
begin
  Result := AArq;
  cBase := ChangeFileExt(AArq, '');
  cExt := ExtractFileExt(AArq);
  n := 0;
  while TFile.Exists(Result) do
  begin
    Inc(n);
    Result := Format('%s_%d%s', [cBase, n, cExt]);
  end;
end;

{------------------------------------------------------------------------
  Formatacao do relatorio (equivale ao PICTURE "@E" do Clipper)
------------------------------------------------------------------------}
function TProcessadorRetorno.Pic(AValor: Double; ALarg: Integer): string;
var
  s: string;
begin
  s := FormatFloat('#,##0.00', Abs(AValor), FFSbr);
  if AValor < 0 then
    s := '-' + s;
  if Length(s) > ALarg then
    Result := StringOfChar('*', ALarg)
  else
    Result := StringOfChar(' ', ALarg - Length(s)) + s;
end;

function TProcessadorRetorno.DtRel(ADt: TDateTime): string;
begin
  if ADt = 0 then
    Result := '        '
  else
    Result := FormatDateTime('dd/mm/yy', ADt);
end;

function TProcessadorRetorno.Fmt(const S: string; ALarg: Integer): string;
begin
  Result := Copy(S + StringOfChar(' ', ALarg), 1, ALarg);
end;

{------------------------------------------------------------------------
  Relatorio de titulos retornados (antigo LOTB_nnn.PRN) em PDF.
  Mesmas colunas, mesmos subtotais, mesma quebra de pagina (56 linhas).
------------------------------------------------------------------------}
procedure TProcessadorRetorno.GravaPDF(const AArqRetorno, ANumLote: string);
const
  CAB_COL = 'Movimento Tp  Nosso Numero       Vencto Vl_Titulo   Vl_Pago Vl_Credit ' +
            'Dt_Cred.  Acresc. Desconto Tarifa VL_IOF Codigo_Movimento Cd Tb.';
var
  pdf: TPdfRelatorio;
  aOrd: TArray<TItemAux>;
  nPag, L, i, n: Integer;
  cOrdem, cNossos, cArqNome, cMovTxt, cNumMov: string;
  it: TItemAux;
  negrito: Boolean;
  // acumuladores: x = total geral | y = subtotal do grupo
  xBr, xPg, xCr, xJu, xDe, xTa, xIo: Double;
  yBr, yPg, yCr, yJu, yDe, yTa, yIo: Double;

  procedure Cabecalho;
  begin
    Inc(nPag);
    pdf.Say(0, 0, 'Relatorio de titulos retornados.  Arquivo: ' + cArqNome +
      ' - Data: ' + FormatDateTime('dd/mm/yyyy', Date) +
      ' - Pagina: ' + IntToStr(nPag) + ' - Lote de baixa: ' + ANumLote, True);
    pdf.Say(2, 1, CAB_COL);
    pdf.Say(3, 0, StringOfChar('-', 135));
    L := 4;
  end;

  procedure ZeraY;
  begin
    yBr := 0; yPg := 0; yCr := 0; yJu := 0; yDe := 0; yTa := 0; yIo := 0;
  end;

  procedure Totais(ABr, APg, ACr, AJu, ADe, ATa, AIo: Double);
  begin
    pdf.Say(L, 41, '---------');
    pdf.Say(L, 51, '---------');
    pdf.Say(L, 61, '---------');
    pdf.Say(L, 80, '--------');
    pdf.Say(L, 89, '--------');
    pdf.Say(L, 98, '------');
    pdf.Say(L, 105, '------');
    Inc(L);
    pdf.Say(L, 36, Pic(ABr, 14));
    pdf.Say(L, 51, Pic(APg, 9));
    pdf.Say(L, 61, Pic(ACr, 9));
    pdf.Say(L, 80, Pic(AJu, 8));
    pdf.Say(L, 89, Pic(ADe, 8));
    pdf.Say(L, 98, Pic(ATa, 6));
    pdf.Say(L, 105, Pic(AIo, 6));
  end;

begin
  cArqNome := ExtractFileName(AArqRetorno);
  pdf := TPdfRelatorio.Create;
  try
    // ordena por ORDEM_IMPR + NOSSONUM (estavel: empate pela ordem de leitura)
    aOrd := FAux.ToArray;
    TArray.Sort<TItemAux>(aOrd, TComparer<TItemAux>.Construct(
      function(const A, B: TItemAux): Integer
      begin
        Result := CompareStr(A.Ordem + Fmt(A.NossoNum, 17), B.Ordem + Fmt(B.NossoNum, 17));
        if Result = 0 then
          Result := A.Seq - B.Seq;
      end));

    nPag := 0;
    cNossos := '';
    ZeraY;
    xBr := 0; xPg := 0; xCr := 0; xJu := 0; xDe := 0; xTa := 0; xIo := 0;
    Cabecalho;

    n := Length(aOrd);
    i := 0;
    if n > 0 then
      cOrdem := aOrd[0].Ordem
    else
      cOrdem := '';

    while i < n do
    begin
      it := aOrd[i];

      // o relatorio lista apenas as liquidacoes (codigos 06 e 17;
      // o 17 ja foi gravado como 06 em CodMov)
      if CodEm(it.CodMov, COD_LIQUIDACAO) then
      begin
        // negrito = nosso numero repetido no arquivo ou titulo ja baixado
        negrito := (Pos(it.NossoNum + ',', cNossos) > 0) or
                   CodEm(it.SitTit, 'BB,BC,PC,PB,CA');
        if not negrito then
          cNossos := cNossos + it.NossoNum + ',';

        if Length(Trim(it.NumMov)) = 8 then
          cNumMov := Copy(it.NumMov, 1, 6) + '-' + Copy(it.NumMov, 7, 1) + '/' + Copy(it.NumMov, 8, 1)
        else
          cNumMov := '      - / ';
        cMovTxt := it.CodMov + '-' + TextoRel(it.CodMov);

        pdf.Say(L, 0, cNumMov, negrito);
        pdf.Say(L, 11, it.SitTit, negrito);
        pdf.Say(L, 14, it.NossoNum, negrito);
        pdf.Say(L, 32, DtRel(it.DtVenc), negrito);
        pdf.Say(L, 41, Pic(it.ValBruto, 9), negrito);
        pdf.Say(L, 51, Pic(it.ValPago, 9), negrito);
        pdf.Say(L, 61, Pic(it.ValCred, 9), negrito);
        pdf.Say(L, 71, DtRel(it.DtCred), negrito);
        pdf.Say(L, 80, Pic(it.Juros, 8), negrito);
        pdf.Say(L, 89, Pic(it.Desc, 8), negrito);
        pdf.Say(L, 98, Pic(it.ValTarif, 6), negrito);
        pdf.Say(L, 105, Pic(it.Iof, 6), negrito);
        pdf.Say(L, 112, cMovTxt, negrito);
        pdf.Say(L, 129, it.Identif);       // resultado do processamento
        pdf.Say(L, 132, Nota47(it.CodMov));
        Inc(L);

        xBr := xBr + it.ValBruto; xPg := xPg + it.ValPago; xCr := xCr + it.ValCred;
        xJu := xJu + it.Juros;    xDe := xDe + it.Desc;    xTa := xTa + it.ValTarif;
        xIo := xIo + it.Iof;
        yBr := yBr + it.ValBruto; yPg := yPg + it.ValPago; yCr := yCr + it.ValCred;
        yJu := yJu + it.Juros;    yDe := yDe + it.Desc;    yTa := yTa + it.ValTarif;
        yIo := yIo + it.Iof;

        if L > 56 then
        begin
          pdf.NovaPagina;
          Cabecalho;
        end;

        Inc(i);
        if (i >= n) or (cOrdem <> aOrd[i].Ordem) then
        begin
          if i < n then cOrdem := aOrd[i].Ordem else cOrdem := '';
          Totais(yBr, yPg, yCr, yJu, yDe, yTa, yIo);
          Inc(L, 2);
          ZeraY;
        end;
      end
      else
        Inc(i);
    end;

    // total geral (so quando ha movimento)
    if Arr2(yBr) <> Arr2(xBr) then
      Totais(xBr, xPg, xCr, xJu, xDe, xTa, xIo);

    Inc(L, 3);
    pdf.Say(L, 0, '**** Os NUMEROS DE MOVIMENTO encontrados, sera'' gerado LOTE DE BAIXA', True);

    ForceDirectories(FCfg.PastaPDF);
    pdf.SalvarEm(FCfg.PastaPDF + 'LOTB_' + ANumLote + '.pdf');
  finally
    pdf.Free;
  end;
end;

{------------------------------------------------------------------------
  Grava o LOTBAIXA.nnn como DBF (dBase III), com a mesma estrutura que o
  Clipper criava, incluindo o registro de capa (1o registro, deletado).
------------------------------------------------------------------------}
procedure TProcessadorRetorno.GravaLote(const AArq, ANumLote: string;
  ADtPagto: TDateTime; AValPago: Double; ANumTit: Integer; ACapaPreenchida: Boolean);
type
  TCampo = record
    Nome: string;
    Tipo: Char;
    Tam, Dec: Integer;
  end;
const
  CAMPOS: array[0..30] of TCampo = (
    (Nome:'NUMMOV';    Tipo:'C'; Tam: 8; Dec:0), (Nome:'TIPODOC';   Tipo:'C'; Tam: 2; Dec:0),
    (Nome:'CODCLI';    Tipo:'C'; Tam: 6; Dec:0), (Nome:'CODPOR';    Tipo:'C'; Tam: 3; Dec:0),
    (Nome:'SITTIT';    Tipo:'C'; Tam: 2; Dec:0), (Nome:'SITTIT2';   Tipo:'C'; Tam: 2; Dec:0),
    (Nome:'COBRADOR';  Tipo:'C'; Tam: 4; Dec:0), (Nome:'MODOBAIXA'; Tipo:'C'; Tam: 1; Dec:0),
    (Nome:'TIPPROTIT'; Tipo:'C'; Tam: 1; Dec:0), (Nome:'DTPAGTO';   Tipo:'D'; Tam: 8; Dec:0),
    (Nome:'DTCHEPRE';  Tipo:'D'; Tam: 8; Dec:0), (Nome:'VALPAGO';   Tipo:'N'; Tam:18; Dec:6),
    (Nome:'VALDESJUR'; Tipo:'N'; Tam:16; Dec:6), (Nome:'SALDEVTIT'; Tipo:'N'; Tam:16; Dec:6),
    (Nome:'NUMNOTCRE'; Tipo:'C'; Tam: 8; Dec:0), (Nome:'NOSSONUM';  Tipo:'C'; Tam:20; Dec:0),
    (Nome:'DTVENCTO';  Tipo:'D'; Tam: 8; Dec:0), (Nome:'DTOCORR';   Tipo:'D'; Tam: 8; Dec:0),
    (Nome:'DTCRED';    Tipo:'D'; Tam: 8; Dec:0), (Nome:'VALCRED';   Tipo:'N'; Tam:12; Dec:2),
    (Nome:'VALBRUTO';  Tipo:'N'; Tam:12; Dec:2), (Nome:'VALTARIF';  Tipo:'N'; Tam:12; Dec:2),
    (Nome:'IDENTIF';   Tipo:'C'; Tam: 2; Dec:0), (Nome:'CODMOV';    Tipo:'C'; Tam: 2; Dec:0),
    (Nome:'JUROS';     Tipo:'N'; Tam:12; Dec:2), (Nome:'DESC';      Tipo:'N'; Tam:12; Dec:2),
    (Nome:'ABAT';      Tipo:'N'; Tam:12; Dec:2), (Nome:'COMPROV';   Tipo:'C'; Tam:20; Dec:0),
    (Nome:'DATACOMPR'; Tipo:'D'; Tam: 8; Dec:0), (Nome:'VALORCOMP'; Tipo:'N'; Tam:12; Dec:2),
    (Nome:'IOF';       Tipo:'N'; Tam:12; Dec:2));
var
  ms: TMemoryStream;
  i, nRec, nLenReg, nLenCab: Integer;
  y, m, d: Word;
  b: TBytes;
  it: TItemLote;

  procedure WB(const ABytes: TBytes);
  begin
    if Length(ABytes) > 0 then
      ms.WriteBuffer(ABytes[0], Length(ABytes));
  end;

  procedure W32(V: Cardinal);
  begin
    ms.WriteBuffer(V, 4);
  end;

  procedure W16(V: Word);
  begin
    ms.WriteBuffer(V, 2);
  end;

  procedure W8(V: Byte);
  begin
    ms.WriteBuffer(V, 1);
  end;

  function C(const S: string; ALen: Integer): string;
  begin
    Result := Copy(S + StringOfChar(' ', ALen), 1, ALen);
  end;

  function N(V: Double; ALen, ADec: Integer): string;
  begin
    Result := Format('%*.*f', [ALen, ADec, V], FFSus);
    if Length(Result) > ALen then
      Result := StringOfChar('*', ALen);
  end;

  function D8(V: TDateTime): string;
  begin
    if V = 0 then Result := StringOfChar(' ', 8)
    else Result := FormatDateTime('yyyymmdd', V);
  end;

  procedure Reg(ADeletado: Boolean; const ANumMov, ATipoDoc, ACodCli, ACodPor,
    ASitTit, ASitTit2, ACobrador, AModo: string; ADtPagto, ADtVencto, ADtOcorr,
    ADtCred: TDateTime; AValPago, AValDesJur, ASalDev: Double; const ANumNotCre,
    ANossoNum: string; AValCred, AValBruto, AValTarif: Double; const AIdentif,
    ACodMov: string; AJuros, ADesc, AAbat, AIof: Double);
  var
    s: string;
  begin
    if ADeletado then s := '*' else s := ' ';
    s := s + C(ANumMov, 8) + C(ATipoDoc, 2) + C(ACodCli, 6) + C(ACodPor, 3) +
         C(ASitTit, 2) + C(ASitTit2, 2) + C(ACobrador, 4) + C(AModo, 1) + C('', 1) +
         D8(ADtPagto) + D8(0) + N(AValPago, 18, 6) + N(AValDesJur, 16, 6) +
         N(ASalDev, 16, 6) + C(ANumNotCre, 8) + C(ANossoNum, 20) + D8(ADtVencto) +
         D8(ADtOcorr) + D8(ADtCred) + N(AValCred, 12, 2) + N(AValBruto, 12, 2) +
         N(AValTarif, 12, 2) + C(AIdentif, 2) + C(ACodMov, 2) + N(AJuros, 12, 2) +
         N(ADesc, 12, 2) + N(AAbat, 12, 2) + C('', 20) + D8(0) + N(0, 12, 2) +
         N(AIof, 12, 2);
    WB(TEncoding.Default.GetBytes(s));
  end;

begin
  nLenReg := 1;
  for i := Low(CAMPOS) to High(CAMPOS) do
    Inc(nLenReg, CAMPOS[i].Tam);
  nLenCab := 32 + 32 * Length(CAMPOS) + 1;
  nRec := FLote.Count + 1;     // + registro de capa

  ms := TMemoryStream.Create;
  try
    DecodeDate(Date, y, m, d);
    W8($03);
    W8(y mod 100); W8(m); W8(d);
    W32(nRec);
    W16(nLenCab);
    W16(nLenReg);
    SetLength(b, 20);
    FillChar(b[0], 20, 0);
    WB(b);
    for i := Low(CAMPOS) to High(CAMPOS) do
    begin
      SetLength(b, 11);
      FillChar(b[0], 11, 0);
      Move(TEncoding.ASCII.GetBytes(CAMPOS[i].Nome)[0], b[0], Length(CAMPOS[i].Nome));
      WB(b);
      W8(Ord(CAMPOS[i].Tipo));
      W32(0);
      W8(CAMPOS[i].Tam);
      W8(CAMPOS[i].Dec);
      SetLength(b, 14);
      FillChar(b[0], 14, 0);
      WB(b);
    end;
    W8($0D);

    // registro de capa: deletado quando o arquivo teve trailer (como no Clipper)
    if ACapaPreenchida then
      Reg(True, '', '', ANumLote, '', '', '', '', '', ADtPagto, 0, 0, 0, AValPago, 0, 0,
        IntToStr(ANumTit), '', 0, 0, 0, '', '', 0, 0, 0, 0)
    else
      Reg(False, '', '', '', '', '', '', '', '', 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, '', '', 0, 0, 0, 0);

    for i := 0 to FLote.Count - 1 do
    begin
      it := FLote[i];
      Reg(False, it.NumMov, it.TipoDoc, it.CodCli, it.CodPor, it.SitTit, it.SitTit2,
        it.Cobrador, it.ModoBaixa, it.DtPagto, it.DtVencto, it.DtOcorr, it.DtCred,
        it.ValPago, it.ValDesJur, it.SalDevTit, '', it.NossoNum, it.ValCred,
        it.ValBruto, it.ValTarif, it.Identif, it.CodMov, it.Juros, it.Desc,
        it.Abat, it.Iof);
    end;
    W8($1A);

    ForceDirectories(FCfg.PastaDados);
    ms.SaveToFile(AArq);
  finally
    ms.Free;
  end;
end;

{------------------------------------------------------------------------
  Processamento completo de um arquivo de retorno
------------------------------------------------------------------------}
function TProcessadorRetorno.Processar(const AArq: string): string;
var
  Linhas: TStringList;
  R, cNumLote, cArqLote, cArqXXX, cNossoNum, cNumMov, cIdentif, cCodMov: string;
  cNum: string;
  i, nSeq, nTitulos, nBaixas: Integer;
  lFlagBai, lAchou, lTrailer: Boolean;
  xDtPagto, mDtVencto, mDtOcorr, mDtPagto, mDtCred: TDateTime;
  mValBruto, mValTxBan, mJuros, mDesc, mIof, mValPago, mValCred: Double;
  xValPago: Double;
  aux: TItemAux;
  lot: TItemLote;
  cSit: string;
begin
  Linhas := LerLinhas(AArq);
  try
    if Linhas.Count < 2 then
      raise Exception.Create('arquivo vazio ou sem registros');
    if Copy(Linhas[0], 8, 1) <> '0' then
      raise Exception.Create('nao parece um arquivo CNAB240 (header de arquivo nao encontrado)');

    FAux.Clear;
    FLote.Clear;

    FDM.AbrirTabelas;
    try
      //----- numero do lote de baixa
      FDM.ATEmp.First;
      cNum := Trim(FDM.ATEmp.FieldByName('NUMLOTBAI').AsString);
      if (cNum = '') or (cNum = '999') then
      begin
        FDM.ATEmp.Edit;
        FDM.ATEmp.FieldByName('NUMLOTBAI').AsString := '000';
        FDM.ATEmp.Post;
        cNum := '000';
      end;
      cNumLote := StrZero(StrToIntDef(cNum, 0) + 1, 3);

      cArqLote := FCfg.PastaDados + 'LOTBAIXA.' + cNumLote;
      if TFile.Exists(cArqLote) then
        raise Exception.Create('o arquivo ' + cArqLote + ' ja existe (lote ' + cNumLote +
          ' ainda nao baixado?)');

      //----- varredura dos registros (a 1a linha e o header do arquivo)
      xDtPagto := 0; xValPago := 0; nTitulos := 0; nBaixas := 0; nSeq := 0;
      lFlagBai := False; lTrailer := False;
      cCodMov := ''; cNossoNum := ''; cNumMov := ''; cIdentif := '';
      mDtVencto := 0; mValBruto := 0; mValTxBan := 0;

      for i := 1 to Linhas.Count - 1 do
      begin
        R := Copy(Linhas[i] + StringOfChar(' ', 240), 1, 240);

        if R[9] = 'T' then
        begin
          xDtPagto := DataCnab(Copy(R, 192, 2), Copy(R, 194, 2), Copy(R, 198, 2));
        end
        else if R[14] = 'T' then
        begin
          // SEGMENTO T
          cCodMov   := Copy(R, 16, 2);
          cNossoNum := Copy(R, 38, 17);
          // carteira antiga: nosso numero com 11 digitos
          if Length(Trim(cNossoNum)) < 17 then
            cNossoNum := Copy(R, 38, 11);
          cNumMov   := Copy(R, 59, 8);
          mDtVencto := DataCnab(Copy(R, 74, 2), Copy(R, 76, 2), Copy(R, 80, 2));
          mValBruto := ValClip(Copy(R, 82, 13), Copy(R, 95, 2));
          mValTxBan := ValClip(Copy(R, 199, 13), Copy(R, 212, 2));
          cIdentif  := Copy(R, 214, 2);
          lFlagBai  := CodEm(cCodMov, COD_LIQUIDACAO);
        end
        else if R[14] = 'U' then
        begin
          // SEGMENTO U
          mJuros   := ValClip(Copy(R, 18, 13), Copy(R, 31, 2));
          mDesc    := ValClip(Copy(R, 33, 13), Copy(R, 46, 2));
          mIof     := ValClip(Copy(R, 63, 13), Copy(R, 76, 2));
          mValPago := ValClip(Copy(R, 78, 13), Copy(R, 91, 2));
          mValCred := ValClip(Copy(R, 93, 13), Copy(R, 106, 2));
          mDtOcorr := DataCnab(Copy(R, 138, 2), Copy(R, 140, 2), Copy(R, 144, 2));
          mDtPagto := mDtOcorr;
          mDtCred  := DataCnab(Copy(R, 146, 2), Copy(R, 148, 2), Copy(R, 152, 2));

          lAchou := AcharTitulo(cNossoNum);
          Inc(nSeq);
          Inc(nTitulos);

          //--- linha do relatorio + RETBANCO (qualquer ocorrencia)
          Finalize(aux); FillChar(aux, SizeOf(aux), 0);
          aux.Seq      := nSeq;
          aux.NossoNum := cNossoNum;
          aux.ValBruto := mValBruto;
          aux.ValPago  := mValPago;
          aux.ValCred  := mValCred;
          aux.DtCred   := mDtCred;
          aux.Juros    := mJuros;
          aux.Desc     := mDesc;
          aux.ValTarif := mValPago - mValCred;
          aux.Iof      := mIof;
          if cCodMov = '17' then aux.CodMov := '06' else aux.CodMov := cCodMov;
          aux.Identif  := cIdentif;
          aux.Ordem    := OrdemImpr(cCodMov);
          if lAchou then
          begin
            aux.NumMov  := FDM.ATTit.FieldByName('NUMMOV').AsString;
            aux.SitTit  := FDM.ATTit.FieldByName('SITTIT').AsString;
            aux.DtVenc  := FDM.ATTit.FieldByName('DTVENCLIM').AsDateTime;
            AtualizaRetBanco(cCodMov, cIdentif);
          end;
          FAux.Add(aux);

          //--- item do lote de baixa (liquidacao de titulo em aberto)
          if lFlagBai then
          begin
            if lAchou then
            begin
              cSit := FDM.ATTit.FieldByName('SITTIT').AsString;
              if CodEm(cSit, 'AB,PC,PB') then
              begin
                mValPago := mValPago + mValTxBan;       // tarifa do banco soma ao valor pago
                xValPago := xValPago + mValPago;
                Inc(nBaixas);

                Finalize(lot); FillChar(lot, SizeOf(lot), 0);
                lot.NumMov    := FDM.ATTit.FieldByName('NUMMOV').AsString;
                lot.TipoDoc   := FDM.ATTit.FieldByName('TIPODOC').AsString;
                lot.CodCli    := FDM.ATTit.FieldByName('CODCLI').AsString;
                if (Arr2(mValPago) < Arr2(FDM.ATTit.FieldByName('VALBRUTO').AsFloat)) and
                   (FDM.ATTit.FieldByName('DESCANTEC').AsFloat = 0) then
                  lot.SitTit := 'PB'
                else
                  lot.SitTit := 'BB';
                lot.SitTit2   := cSit;
                lot.ModoBaixa := '1';
                lot.DtPagto   := mDtPagto;
                lot.ValPago   := mValPago;
                lot.CodPor    := FDM.ATTit.FieldByName('CODPOR').AsString;
                lot.Cobrador  := FDM.ATTit.FieldByName('COBRADOR').AsString;
                lot.ValDesJur := mValPago - (FDM.ATTit.FieldByName('VALBRUTO').AsFloat -
                                             FDM.ATTit.FieldByName('VALPARCPAG').AsFloat);
                lot.SalDevTit := FDM.ATTit.FieldByName('VALBRUTO').AsFloat -
                                 FDM.ATTit.FieldByName('VALPARCPAG').AsFloat;
                lot.NossoNum  := cNossoNum;
                lot.DtVencto  := FDM.ATTit.FieldByName('DTVENCLIM').AsDateTime;
                lot.DtOcorr   := mDtOcorr;
                lot.DtCred    := mDtCred;
                lot.ValCred   := mValCred;
                lot.ValBruto  := mValBruto;
                lot.ValTarif  := 0;
                lot.Identif   := cIdentif;
                lot.CodMov    := cCodMov;
                lot.Juros     := mJuros;
                lot.Desc      := mDesc;
                lot.Abat      := 0;
                lot.Iof       := mIof;
                FLote.Add(lot);
              end;
            end;
            lFlagBai := False;
          end;
        end
        else if R[8] = '9' then
          lTrailer := True;       // trailer do arquivo
      end;

      //----- relatorio em PDF e lote de baixa
      GravaPDF(AArq, cNumLote);
      GravaLote(cArqLote, cNumLote, xDtPagto, xValPago, nBaixas, lTrailer);

      //----- confirma o numero do lote
      FDM.ATEmp.First;
      FDM.ATEmp.Edit;
      FDM.ATEmp.FieldByName('NUMLOTBAI').AsString := cNumLote;
      FDM.ATEmp.Post;
    finally
      FDM.FecharTabelas;
    end;

    //----- marca o arquivo como processado (.XXX)
    cArqXXX := NomeLivre(ChangeFileExt(AArq, '.XXX'));
    TFile.Move(AArq, cArqXXX);

    Result := Format('%s: %d registro(s), %d titulo(s) em lote de baixa. Lote %s | PDF LOTB_%s.pdf | arquivo -> %s',
      [ExtractFileName(AArq), nTitulos, nBaixas, cNumLote, cNumLote, ExtractFileName(cArqXXX)]);
  finally
    Linhas.Free;
  end;
end;

end.
