{-------------------------------------------------------------------------
  uPdfRel.pas

  Gerador minimo de PDF para relatorios em modo texto (fonte Courier,
  monoespacada). Substitui a saida em impressora/arquivo .PRN do antigo
  DATARET2 (Clipper): o relatorio e montado por LINHA/COLUNA, igual ao
  "@ L,C SAY" do Clipper, e gravado em paginas A4 paisagem.

  Nao depende de nenhum componente de terceiros.
-------------------------------------------------------------------------}
unit uPdfRel;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TPdfRelatorio = class
  private
    FPaginas: TObjectList<TStringBuilder>;
    FAtual: TStringBuilder;
    FFS: TFormatSettings;
    function Escapa(const S: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure NovaPagina;
    // Escreve S na linha/coluna (base 0), como o "@ lin,col SAY" do Clipper
    procedure Say(ALinha, ACol: Integer; const S: string; ANegrito: Boolean = False);
    function TotalPaginas: Integer;
    procedure SalvarEm(const AArquivo: string);
  end;

implementation

const
  PG_LARGURA = 842;      // A4 paisagem, em pontos
  PG_ALTURA  = 595;
  FONTE_TAM  = 8.0;
  CHAR_LARG  = 4.8;      // Courier: 0,6 x tamanho da fonte
  ENTRELINHA = 9.0;
  MARG_ESQ   = 30.0;
  TOPO_Y     = 572.0;

{ TPdfRelatorio }

constructor TPdfRelatorio.Create;
begin
  inherited Create;
  FFS := TFormatSettings.Create('en-US');
  FPaginas := TObjectList<TStringBuilder>.Create(True);
  NovaPagina;
end;

destructor TPdfRelatorio.Destroy;
begin
  FPaginas.Free;
  inherited;
end;

procedure TPdfRelatorio.NovaPagina;
begin
  FAtual := TStringBuilder.Create;
  FPaginas.Add(FAtual);
end;

function TPdfRelatorio.TotalPaginas: Integer;
begin
  Result := FPaginas.Count;
end;

function TPdfRelatorio.Escapa(const S: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    case c of
      '\', '(', ')': Result := Result + '\' + c;
    else
      if (Ord(c) < 32) then
        Result := Result + ' '
      else if Ord(c) > 255 then
        Result := Result + '?'
      else if Ord(c) > 126 then
        Result := Result + '\' + Chr(48 + (Ord(c) shr 6)) +
                  Chr(48 + ((Ord(c) shr 3) and 7)) + Chr(48 + (Ord(c) and 7))
      else
        Result := Result + c;
    end;
  end;
end;

procedure TPdfRelatorio.Say(ALinha, ACol: Integer; const S: string; ANegrito: Boolean);
var
  x, y: Double;
  cFonte: string;
begin
  if S = '' then
    Exit;
  x := MARG_ESQ + ACol * CHAR_LARG;
  y := TOPO_Y - ALinha * ENTRELINHA;
  if ANegrito then cFonte := 'F2' else cFonte := 'F1';
  FAtual.Append(Format('BT /%s %.1f Tf %.2f %.2f Td (%s) Tj ET'#10,
    [cFonte, FONTE_TAM, x, y, Escapa(S)], FFS));
end;

procedure TPdfRelatorio.SalvarEm(const AArquivo: string);
var
  ms: TMemoryStream;
  offs: array of Integer;
  nObj, i, nXref: Integer;
  cConteudo: string;

  procedure W(const S: string);
  var
    b: TBytes;
  begin
    if S = '' then Exit;
    b := TEncoding.ASCII.GetBytes(S);
    ms.WriteBuffer(b[0], Length(b));
  end;

  procedure Obj(N: Integer);
  begin
    offs[N] := ms.Position;
    W(IntToStr(N) + ' 0 obj'#10);
  end;

var
  cKids: string;
begin
  // objetos: 1 catalogo | 2 paginas | 3 Courier | 4 Courier-Bold |
  //          5.. pagina i = 5+2i, conteudo i = 6+2i
  nObj := 4 + 2 * FPaginas.Count;
  SetLength(offs, nObj + 1);
  ms := TMemoryStream.Create;
  try
    W('%PDF-1.4'#10);

    Obj(1);
    W('<< /Type /Catalog /Pages 2 0 R >>'#10'endobj'#10);

    cKids := '';
    for i := 0 to FPaginas.Count - 1 do
      cKids := cKids + IntToStr(5 + 2 * i) + ' 0 R ';
    Obj(2);
    W(Format('<< /Type /Pages /Kids [ %s] /Count %d >>'#10'endobj'#10,
      [cKids, FPaginas.Count]));

    Obj(3);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>'#10'endobj'#10);
    Obj(4);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold /Encoding /WinAnsiEncoding >>'#10'endobj'#10);

    for i := 0 to FPaginas.Count - 1 do
    begin
      Obj(5 + 2 * i);
      W(Format('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] ' +
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents %d 0 R >>'#10'endobj'#10,
        [PG_LARGURA, PG_ALTURA, 6 + 2 * i]));

      cConteudo := FPaginas[i].ToString;
      Obj(6 + 2 * i);
      W(Format('<< /Length %d >>'#10'stream'#10, [Length(cConteudo)]));
      W(cConteudo);
      W('endstream'#10'endobj'#10);
    end;

    nXref := ms.Position;
    W(Format('xref'#10'0 %d'#10, [nObj + 1]));
    W('0000000000 65535 f '#10);
    for i := 1 to nObj do
      W(Format('%.10d 00000 n '#10, [offs[i]]));
    W(Format('trailer'#10'<< /Size %d /Root 1 0 R >>'#10'startxref'#10'%d'#10'%%%%EOF'#10,
      [nObj + 1, nXref]));

    ms.SaveToFile(AArquivo);
  finally
    ms.Free;
  end;
end;

end.
