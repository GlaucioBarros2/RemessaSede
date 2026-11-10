unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.IniFiles, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Menus,
  uDM, uRetorno;

const
  ARQ_INI = 'DataRet.ini';
  ARQ_LOG = 'DataRet.log';

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
    FProc: TProcessadorRetorno;
    FProcessando: Boolean;
    FErros: TStringList;      // "arquivo|mensagem" ja registrados (evita repetir no log)
    procedure Log(const AMsg: string);
    procedure LerConfig(out ACfg: TConfigRetorno; out ASegundos: Integer;
      out AHost: string; out APorta: Integer);
    procedure Varrer;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.Log(const AMsg: string);
begin
  try
    TFile.AppendAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), ARQ_LOG),
      FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + '  ' + AMsg + sLineBreak);
  except
    // log nunca pode derrubar o processamento
  end;
end;

{-------------------------------------------------------------------------
  Le o DataRet.ini (ao lado do .exe). Se nao existir, cria com os valores
  padrao, que reproduzem os caminhos do DATARET2 original.
-------------------------------------------------------------------------}
procedure TfrmMain.LerConfig(out ACfg: TConfigRetorno; out ASegundos: Integer;
  out AHost: string; out APorta: Integer);
var
  ini: TIniFile;
  cArq: string;
begin
  cArq := TPath.Combine(ExtractFilePath(ParamStr(0)), ARQ_INI);
  ini := TIniFile.Create(cArq);
  try
    if not FileExists(cArq) then
    begin
      ini.WriteString('Config', 'PastaRetorno', 'C:\datanet\fontes\');
      ini.WriteString('Config', 'PastaDados', 'C:\datanet\fontes\');
      ini.WriteString('Config', 'PastaPDF', 'C:\datanet\fontes\RETORNO\');
      ini.WriteInteger('Config', 'IntervaloSegundos', 60);
      ini.WriteString('Config', 'ApolloHost', '127.0.0.1');
      ini.WriteInteger('Config', 'ApolloPorta', 5002);
    end;
    ACfg.PastaRetorno := ini.ReadString('Config', 'PastaRetorno', 'C:\datanet\fontes\');
    ACfg.PastaDados   := ini.ReadString('Config', 'PastaDados', 'C:\datanet\fontes\');
    ACfg.PastaPDF     := ini.ReadString('Config', 'PastaPDF', 'C:\datanet\fontes\RETORNO\');
    ASegundos         := ini.ReadInteger('Config', 'IntervaloSegundos', 60);
    AHost             := ini.ReadString('Config', 'ApolloHost', '127.0.0.1');
    APorta            := ini.ReadInteger('Config', 'ApolloPorta', 5002);
  finally
    ini.Free;
  end;
  if ASegundos < 5 then
    ASegundos := 5;
  // parametro de linha de comando: pasta de retorno (para testes)
  if ParamCount >= 1 then
    ACfg.PastaRetorno := ParamStr(1);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  cfg: TConfigRetorno;
  nSeg, nPorta: Integer;
  cHost, cArqIcone: string;
begin
  Visible := False;
  FErros := TStringList.Create;
  FProcessando := False;

  cArqIcone := TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'res'), 'caixa.ico');
  if TFile.Exists(cArqIcone) then
    TrayIcon1.Icon.LoadFromFile(cArqIcone)
  else
    TrayIcon1.Icon := Application.Icon;
  TrayIcon1.Visible := True;

  LerConfig(cfg, nSeg, cHost, nPorta);

  dmDados := TdmDados.Create(Self);
  FProc := TProcessadorRetorno.Create(dmDados, cfg);

  TrayIcon1.Hint := 'DataRet - Retorno de Cobranca' + sLineBreak +
    'Pasta: ' + cfg.PastaRetorno + sLineBreak +
    'Verificando a cada ' + IntToStr(nSeg) + ' s';

  Log(Format('Programa iniciado. Retornos: %s | Dados: %s | PDF: %s | Intervalo: %d s',
    [cfg.PastaRetorno, cfg.PastaDados, cfg.PastaPDF, nSeg]));

  try
    dmDados.Conectar(cHost, nPorta);
  except
    on E: Exception do
      Log('[ERRO] Conexao Apollo: ' + E.Message + ' (nova tentativa a cada ciclo)');
  end;

  Timer1.Interval := nSeg * 1000;
  Timer1.Enabled := True;
  Varrer;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := False;
  FProc.Free;
  FErros.Free;
  Log('Programa encerrado.');
  TrayIcon1.Visible := False;
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  Varrer;
end;

procedure TfrmMain.TrayIcon1DblClick(Sender: TObject);
begin
  Varrer;
end;

procedure TfrmMain.mnuProcessarAgoraClick(Sender: TObject);
begin
  Varrer;
end;

procedure TfrmMain.mnuEncerrarClick(Sender: TObject);
begin
  Application.Terminate;
end;

{-------------------------------------------------------------------------
  Varre a pasta e processa, em ordem de data/hora, todos os retornos
  encontrados. Protegida contra execucao simultanea (timer + menu).
-------------------------------------------------------------------------}
procedure TfrmMain.Varrer;
var
  aArq: TArray<string>;
  cArq, cChave, cRes: string;
  nOk: Integer;
begin
  if FProcessando then
    Exit;
  FProcessando := True;
  Timer1.Enabled := False;
  try
    try
      aArq := FProc.ListarArquivos;
    except
      on E: Exception do
      begin
        Log('[ERRO] Listando arquivos: ' + E.Message);
        Exit;
      end;
    end;

    nOk := 0;
    for cArq in aArq do
    begin
      if not FProc.ArquivoEstavel(cArq) then
        Continue;          // ainda sendo gravado: fica para o proximo ciclo
      try
        dmDados.Conectar('', 0);
        cRes := FProc.Processar(cArq);
        Log('OK: ' + cRes);
        Inc(nOk);
      except
        on E: Exception do
        begin
          cChave := cArq + '|' + E.Message;
          if FErros.IndexOf(cChave) < 0 then     // registra cada erro uma vez so
          begin
            FErros.Add(cChave);
            Log('[ERRO] ' + ExtractFileName(cArq) + ': ' + E.Message);
          end;
          try
            dmDados.FecharTabelas;
          except
          end;
        end;
      end;
      Application.ProcessMessages;
    end;

    if nOk > 0 then
    begin
      TrayIcon1.BalloonTitle := 'DataRet';
      TrayIcon1.BalloonHint := Format('%d arquivo(s) de retorno processado(s).', [nOk]);
      TrayIcon1.BalloonFlags := bfInfo;
      TrayIcon1.ShowBalloonHint;
    end;
  finally
    FProcessando := False;
    Timer1.Enabled := True;
  end;
end;

end.
