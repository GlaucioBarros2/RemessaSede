{-------------------------------------------------------------------------
  uDM.pas

  DataModule com a conexao Apollo e as duas tabelas do ERP usadas pelo
  DataRet: SACADTIT.DBF (titulos) e SACADEMP.DBF (empresa - contador de
  lote de baixa). Mesmos parametros do BalLeitor (servidor 'datanet',
  porta 5002, banco 'DATANET'); host/porta podem ser trocados no
  DataRet.ini.
-------------------------------------------------------------------------}
unit uDM;

interface

uses
  System.SysUtils, System.Classes, Data.DB, ApoDSet, apoEnv, apWin, ApConn;

type
  TdmDados = class(TDataModule)
    ApolloConnection1: TApolloConnection;
    ApolloEnv1: TApolloEnv;
    ATTit: TApolloTable;
    ATEmp: TApolloTable;
  public
    procedure Conectar(const AHost: string; APorta: Integer);
    procedure AbrirTabelas;
    procedure FecharTabelas;
  end;

var
  dmDados: TdmDados;

implementation

{$R *.dfm}

procedure TdmDados.Conectar(const AHost: string; APorta: Integer);
begin
  if ApolloConnection1.Active then
    Exit;
  if AHost <> '' then
    ApolloConnection1.Host := AHost;
  if APorta > 0 then
    ApolloConnection1.Port := APorta;
  ApolloConnection1.Active := True;
end;

procedure TdmDados.AbrirTabelas;
begin
  if not ApolloConnection1.Active then
    ApolloConnection1.Active := True;
  ATEmp.Open;
  ATTit.Open;
end;

procedure TdmDados.FecharTabelas;
begin
  if ATTit.Active then ATTit.Close;
  if ATEmp.Active then ATEmp.Close;
end;

end.
