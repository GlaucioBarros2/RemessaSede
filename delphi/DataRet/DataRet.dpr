{-------------------------------------------------------------------------
  DataRet.dpr

  Substitui o DATARET2.PRG (Clipper). Fica residente na bandeja do
  sistema, sem janela e sem perguntas: de tempos em tempos le a pasta de
  retornos e processa sozinho todo arquivo *.RET ou RETORNO_*.TXT
  (CNAB240) - atualiza SACADTIT->RETBANCO, gera o relatorio em PDF
  (LOTB_nnn.pdf) e o lote de baixa (LOTBAIXA.nnn).
-------------------------------------------------------------------------}

program DataRet;

uses
  Winapi.Windows,
  Vcl.Forms,
  System.SysUtils,
  uMain in 'uMain.pas' {frmMain},
  uDM in 'uDM.pas' {dmDados: TDataModule},
  uRetorno in 'uRetorno.pas',
  uPdfRel in 'uPdfRel.pas';

{$R *.res}

var
  hMutex: THandle;

begin
  // uma unica copia por vez: duas instancias processariam o mesmo
  // arquivo e gerariam lotes duplicados
  hMutex := CreateMutex(nil, True, 'DataRet_Instancia_Unica');
  if GetLastError = ERROR_ALREADY_EXISTS then
    Exit;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.ShowMainForm := False;
  Application.Run;

  if hMutex <> 0 then
    CloseHandle(hMutex);
end.
