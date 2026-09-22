unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Types, System.IOUtils, Data.DB,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Menus,
  UnitDM;   // TDM / DM.ATCadPro - saldo de estoque anterior ao ajuste (campo SALDESTOQ)

const
  PASTA_PADRAO      = 'F:\DataNet\Balanco\';
  MASCARA_ENTRADA   = 'bal_*.txt';
  EXTENSAO_SAIDA    = '.XXX';
  PASTA_PROCESSADOS = 'Processados';
  ARQ_LOG           = 'BalLeitor.log';

type
  TfrmMain = class(TForm)
    TrayIcon1: TTrayIcon;
    Timer1: TTimer;
    PopupMenu1: TPopupMenu;
    mnuProcessarAgora: TMenuItem;
    mnuSeparador1: TMenuItem;
    mnuEncerrar: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure mnuProcessarAgoraClick(Sender: TObject);
    procedure mnuEncerrarClick(Sender: TObject);
  private
    FPasta: string;
    FProcessando: Boolean;
    procedure Log(const cMsg: string);
    function PastaProcessados: string;
    function ParteInteira(const cValor: string): Integer;
    function NomeSemColisao(const cPastaDestino, cNomeArquivo: string): string;
    function SaldoAnteriorProduto(const cCodigo: string): Integer;
    procedure ProcessarArquivo(const cArqEntrada: string);
    procedure VarrerPasta;
  public
    procedure IniciarMonitoramento(nMinutos: Integer);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  cArqIcone: string;
begin
  // Programa roda apenas pela bandeja do sistema, sem janela visivel
  Visible := False;

  // Icone da bandeja: usa a imagem da caixinha (res\caixa.ico), se
  // estiver junto do executavel; senao cai no icone padrao do app.
  cArqIcone := TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'res'), 'caixa.ico');
  if TFile.Exists(cArqIcone) then
    TrayIcon1.Icon.LoadFromFile(cArqIcone)
  else
    TrayIcon1.Icon := Application.Icon;

  TrayIcon1.Visible := True;
  FProcessando := False;

  // Conexao com o mesmo banco do ERP (UnitDM/TDM), usada so para consultar
  // o saldo de estoque anterior (ATCadPro.SALDESTOQ) antes do ajuste.
  // Se a conexao falhar, o programa continua rodando: o saldo anterior
  // fica registrado como 0 e um aviso vai para o log (ver
  // SaldoAnteriorProduto), em vez de travar a bandeja inteira.
  try
    DM := TDM.Create(Application);
  except
    on E: Exception do
    begin
      DM := nil;
      Log('[ERRO] Falha ao conectar no banco (DM/ATCadPro): ' + E.Message);
    end;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Log('Programa encerrado.');
  TrayIcon1.Visible := False;
end;

{-------------------------------------------------------------------------
  Configura a pasta monitorada e o intervalo de verificacao, liga o
  timer e dispara a primeira varredura imediatamente.
-------------------------------------------------------------------------}
procedure TfrmMain.IniciarMonitoramento(nMinutos: Integer);
begin
  // Pasta monitorada: fixa em F:\DataNet\Balanco (ver PASTA_PADRAO), a
  // menos que outra pasta seja informada por parametro de linha de
  // comando (util para testes fora do servidor de producao).
  if ParamCount >= 1 then
    FPasta := IncludeTrailingPathDelimiter(ParamStr(1))
  else
    FPasta := PASTA_PADRAO;

  TrayIcon1.Hint := 'BalLeitor - Balanco de Estoque' + sLineBreak +
    'Pasta: ' + FPasta + sLineBreak +
    'Verificando a cada ' + IntToStr(nMinutos) + ' minuto(s)';

  Timer1.Interval := nMinutos * 60 * 1000;
  Timer1.Enabled := True;

  Log(Format('Programa iniciado. Pasta monitorada: %s | Intervalo: %d minuto(s).',
    [FPasta, nMinutos]));

  TrayIcon1.BalloonTitle := 'BalLeitor';
  TrayIcon1.BalloonHint := Format('Monitorando "%s" a cada %d minuto(s).' + sLineBreak +
    'Clique com o botao direito no icone para processar agora ou encerrar.',
    [FPasta, nMinutos]);
  TrayIcon1.BalloonFlags := bfInfo;
  TrayIcon1.ShowBalloonHint;

  VarrerPasta;
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  VarrerPasta;
end;

procedure TfrmMain.TrayIcon1DblClick(Sender: TObject);
begin
  VarrerPasta;
end;

procedure TfrmMain.mnuProcessarAgoraClick(Sender: TObject);
begin
  VarrerPasta;
end;

procedure TfrmMain.mnuEncerrarClick(Sender: TObject);
begin
  Application.Terminate;
end;

{-------------------------------------------------------------------------
  Grava uma linha com data/hora no arquivo de log, na pasta do executavel.
  Como o programa nao tem console/janela, o log e o unico registro do
  que foi processado.
-------------------------------------------------------------------------}
procedure TfrmMain.Log(const cMsg: string);
var
  slLog: TStringList;
  cArqLog: string;
begin
  cArqLog := TPath.Combine(ExtractFilePath(ParamStr(0)), ARQ_LOG);
  slLog := TStringList.Create;
  try
    if FileExists(cArqLog) then
      slLog.LoadFromFile(cArqLog);
    slLog.Add(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + '  ' + cMsg);
    slLog.SaveToFile(cArqLog);
  finally
    slLog.Free;
  end;
end;

{-------------------------------------------------------------------------
  Garante (criando se preciso) a subpasta "Processados" dentro da pasta
  monitorada e retorna o caminho completo, com separador final.
-------------------------------------------------------------------------}
function TfrmMain.PastaProcessados: string;
begin
  Result := IncludeTrailingPathDelimiter(FPasta + PASTA_PROCESSADOS);
  ForceDirectories(Result);
end;

{-------------------------------------------------------------------------
  Retorna apenas a parte inteira do texto de quantidade, descartando
  tudo a partir do separador decimal (ponto ou virgula), sem arredondar.
  Ex.: '628.000' -> 628 | '4.000' -> 4 | '0.000' -> 0
-------------------------------------------------------------------------}
function TfrmMain.ParteInteira(const cValor: string): Integer;
var
  cLimpo: string;
  nPos: Integer;
begin
  cLimpo := Trim(cValor);

  nPos := Pos('.', cLimpo);
  if nPos = 0 then
    nPos := Pos(',', cLimpo);

  if nPos > 0 then
    cLimpo := Copy(cLimpo, 1, nPos - 1);

  Result := StrToIntDef(Trim(cLimpo), 0);
end;

{-------------------------------------------------------------------------
  Busca em DM.ATCadPro (tabela de cadastro de produtos do ERP) o saldo
  de estoque que o produto tinha ANTES do ajuste feito pelo balanco,
  no campo SALDESTOQ. Retorna 0 (e grava aviso/erro no log) se a
  conexao nao estiver disponivel ou o produto nao for encontrado -
  isso nao interrompe o processamento do arquivo.
-------------------------------------------------------------------------}
function TfrmMain.SaldoAnteriorProduto(const cCodigo: string): Integer;
begin
  Result := 0;
  try
    if (DM = nil) or not DM.ATCadPro.Active then
    begin
      Log('[AVISO] Tabela ATCadPro indisponivel - saldo anterior do produto ' +
        cCodigo + ' gravado como 0.');
      Exit;
    end;

    if DM.ATCadPro.Locate('CODPRO', cCodigo, [loCaseInsensitive]) then
      Result := DM.ATCadPro.FieldByName('SALDESTOQ').AsInteger
    else
      Log('[AVISO] Produto ' + cCodigo +
        ' nao encontrado em ATCadPro - saldo anterior gravado como 0.');
  except
    on E: Exception do
      Log(Format('[ERRO] Falha ao consultar saldo anterior do produto %s: %s',
        [cCodigo, E.Message]));
  end;
end;

{-------------------------------------------------------------------------
  Evita sobrescrever um arquivo ja existente em "Processados": se
  cNomeArquivo ja existir la, acrescenta _1, _2, ... antes da extensao.
-------------------------------------------------------------------------}
function TfrmMain.NomeSemColisao(const cPastaDestino, cNomeArquivo: string): string;
var
  cNome, cExt, cCandidato: string;
  nSeq: Integer;
begin
  cNome := TPath.GetFileNameWithoutExtension(cNomeArquivo);
  cExt  := TPath.GetExtension(cNomeArquivo);
  cCandidato := cNomeArquivo;
  nSeq := 0;

  while TFile.Exists(TPath.Combine(cPastaDestino, cCandidato)) do
  begin
    Inc(nSeq);
    cCandidato := Format('%s_%d%s', [cNome, nSeq, cExt]);
  end;

  Result := cCandidato;
end;

{-------------------------------------------------------------------------
  Le um arquivo bal_*.txt (a partir da linha 2, ignorando o cabecalho),
  grava o .XXX correspondente em Processados e grava tambem, em
  Processados, uma copia do .txt original com uma coluna a mais em
  cada linha de produto: o saldo de estoque que o produto tinha antes
  do ajuste (consultado em DM.ATCadPro.SALDESTOQ). O .txt original na
  pasta monitorada e apagado em seguida (seu conteudo, ja com a coluna
  extra, passa a existir em Processados) - assim ele tambem nao e
  reprocessado no proximo ciclo.
-------------------------------------------------------------------------}
procedure TfrmMain.ProcessarArquivo(const cArqEntrada: string);
var
  slEntrada, slSaida, slTxtProcessado: TStringList;
  i: Integer;
  cLinha: string;
  cPastaDestino, cNomeSaida, cArqSaida: string;
  cNomeTxtDestino, cArqTxtDestino: string;
  aCampos: TArray<string>;
  cCodigo, cApresentacao: string;
  nQuantidade, nSaldoAnterior: Integer;
  nLinhasLidas, nLinhasGravadas: Integer;
begin
  slEntrada       := TStringList.Create;
  slSaida         := TStringList.Create;
  slTxtProcessado := TStringList.Create;
  try
    slEntrada.LoadFromFile(cArqEntrada);

    if slEntrada.Count < 2 then
    begin
      Log('Arquivo sem registros de produto (so ha cabecalho): ' +
        ExtractFileName(cArqEntrada));
      Exit;
    end;

    // Cabecalho (linha 1) e copiado sem alteracao para o .txt em Processados
    slTxtProcessado.Add(slEntrada[0]);

    nLinhasLidas    := 0;
    nLinhasGravadas := 0;

    // Processa a partir da linha 2 (indice 1), ignorando o cabecalho (linha 1)
    for i := 1 to slEntrada.Count - 1 do
    begin
      cLinha := Trim(slEntrada[i]);
      if cLinha = '' then
        Continue;

      Inc(nLinhasLidas);
      aCampos := cLinha.Split([';']);

      if Length(aCampos) < 2 then
      begin
        Log(Format('[AVISO] %s - linha %d ignorada (formato invalido): %s',
          [ExtractFileName(cArqEntrada), i + 1, cLinha]));
        // Linha invalida: copiada para Processados do jeito que veio,
        // sem coluna de saldo anterior (nao ha codigo confiavel pra buscar)
        slTxtProcessado.Add(cLinha);
        Continue;
      end;

      cCodigo     := Trim(aCampos[0]);
      nQuantidade := ParteInteira(aCampos[1]);

      cApresentacao := '';
      if Length(aCampos) >= 3 then
        cApresentacao := Trim(aCampos[2]);

      if cApresentacao <> '' then
        slSaida.Add(Format('%s;%d;%s', [cCodigo, nQuantidade, cApresentacao]))
      else
        slSaida.Add(Format('%s;%d', [cCodigo, nQuantidade]));

      // Saldo que o produto tinha antes do ajuste (DM.ATCadPro.SALDESTOQ),
      // gravado como ultima coluna na copia arquivada em Processados
      nSaldoAnterior := SaldoAnteriorProduto(cCodigo);
      slTxtProcessado.Add(Format('%s;%d', [cLinha, nSaldoAnterior]));

      Inc(nLinhasGravadas);
    end;

    cPastaDestino := PastaProcessados;

    // Grava o .XXX em Processados
    cNomeSaida := ChangeFileExt(ExtractFileName(cArqEntrada), EXTENSAO_SAIDA);
    cNomeSaida := NomeSemColisao(cPastaDestino, cNomeSaida);
    cArqSaida  := TPath.Combine(cPastaDestino, cNomeSaida);
    slSaida.SaveToFile(cArqSaida);

    // Grava em Processados a copia do .txt original com a coluna do saldo
    // anterior, e apaga o original da pasta monitorada (evita reprocessar)
    cNomeTxtDestino := NomeSemColisao(cPastaDestino, ExtractFileName(cArqEntrada));
    cArqTxtDestino  := TPath.Combine(cPastaDestino, cNomeTxtDestino);
    slTxtProcessado.SaveToFile(cArqTxtDestino);
    TFile.Delete(cArqEntrada);

    Log(Format('OK: %s -> Processados\%s (%d de %d linhas) | original -> Processados\%s (com saldo anterior)',
      [ExtractFileName(cArqEntrada), cNomeSaida, nLinhasGravadas, nLinhasLidas,
       cNomeTxtDestino]));
  finally
    slEntrada.Free;
    slSaida.Free;
    slTxtProcessado.Free;
  end;
end;

{-------------------------------------------------------------------------
  Varre a pasta monitorada procurando bal_*.txt e processa cada um.
  Protegida contra execucao simultanea (timer + duplo clique/menu).
-------------------------------------------------------------------------}
procedure TfrmMain.VarrerPasta;
var
  aArquivos: TStringDynArray;
  cArquivo: string;
  nTotal: Integer;
begin
  if FProcessando then
    Exit;

  FProcessando := True;
  try
    if not TDirectory.Exists(FPasta) then
    begin
      Log('Pasta monitorada nao encontrada: ' + FPasta);
      Exit;
    end;

    aArquivos := TDirectory.GetFiles(FPasta, MASCARA_ENTRADA);
    nTotal := 0;

    for cArquivo in aArquivos do
    begin
      try
        ProcessarArquivo(cArquivo);
        Inc(nTotal);
      except
        on E: Exception do
          Log(Format('[ERRO] %s: %s', [ExtractFileName(cArquivo), E.Message]));
      end;
    end;

    if nTotal > 0 then
    begin
      TrayIcon1.BalloonTitle := 'BalLeitor';
      TrayIcon1.BalloonHint := Format('%d arquivo(s) processado(s).', [nTotal]);
      TrayIcon1.BalloonFlags := bfInfo;
      TrayIcon1.ShowBalloonHint;
    end;
  finally
    FProcessando := False;
  end;
end;

end.
