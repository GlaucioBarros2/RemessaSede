{-------------------------------------------------------------------------
  BalLeitor.dpr

  Programa em Delphi XE5 usado no balanco de estoque: fica residente na
  bandeja do sistema (system tray) monitorando uma pasta em busca de
  arquivos "bal_*.txt" (a contagem de saldo feita na prateleira do
  deposito) e gerando, para cada um, um arquivo "bal_*.XXX" dentro da
  subpasta "Processados".

  Ao iniciar, pergunta de quantos em quantos minutos a pasta deve ser
  verificada. O programa roda em segundo plano (sem janela visivel) ate
  ser encerrado manualmente pelo menu do icone na bandeja.

  Veja uMain.pas para o funcionamento completo (leitura, geracao do
  .XXX, movimentacao do .txt original, log, etc.).
-------------------------------------------------------------------------}

program BalLeitor;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  System.SysUtils,
  uMain in 'uMain.pas' {frmMain};

{$R *.res}

var
  cResp: string;
  nMinutos: Integer;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;

  // Pergunta o intervalo de verificacao ANTES de criar qualquer janela,
  // para que um cancelamento aqui encerre o programa de forma limpa.
  cResp := '1';
  if not InputQuery('BalLeitor - Balanco de Estoque',
       'De quantos em quantos minutos verificar a pasta por novos arquivos bal_*.txt?',
       cResp) then
    Exit;

  if not TryStrToInt(Trim(cResp), nMinutos) or (nMinutos <= 0) then
    nMinutos := 1;

  Application.CreateForm(TfrmMain, frmMain);
  Application.ShowMainForm := False;   // roda so pela bandeja, sem janela

  frmMain.IniciarMonitoramento(nMinutos);

  Application.Run;
end.
