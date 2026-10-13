unit Unitboleto;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Mask, Buttons, RpRender, RpRenderPDF, RpDefine,
  WinSpool,
  RpBase, RpSystem, Grids, DBGrids, ExtCtrls, RpRave, ShellApi;

type
  TFormBoleto = class(TForm)
    ComboBox1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    MaskEdit1: TMaskEdit;
    BitBtn1: TBitBtn;
    Label3: TLabel;
    Label4: TLabel;
    RvSystemBoleto: TRvSystem;
    RvRenderPDF1: TRvRenderPDF;
    DBGrid1: TDBGrid;
    Image1: TImage;
    Label5: TLabel;
    procedure BitBtn1Click(Sender: TObject);
    procedure MaskEdit1Exit(Sender: TObject);
    procedure RvSystemBoletoPrint(Sender: TObject);
    procedure MaskEdit1Enter(Sender: TObject);
  private
    cFiltro:String;
    function formatacnpj(Cnpj:String):string;
    function formatainsc(insc,uf:String):string;
    function GeraCodBarra2de5(cCodBanco:String):String;
    function LInhaDigitavel(cCodigoBarras:string):string;
    function CalcDigVerificador(CodigoBarras:string): char;
    function Modulo10(Valor: string): string;
    function FatorVencto(dDataVenc:TDate; cCodBanco:string):string;
    function PadL(Oque: string; Tamanho: integer; ComOque: char): string;
    function DIGNOSSONUM(cNossoNum:String;cPeso:string):String;
    function TemFilaImpressao(const NomeImpressora: string): Boolean;
    { Private declarations }
  public
   nParcela : integer;
   { Public declarations }
  end;

var
  FormBoleto: TFormBoleto;

implementation

uses UnitDM, DB;

{$R *.dfm}

// ===========================================================================
// SUPORTE AO BANCO SAFRA (422) - mesmos valores/formulas de UnitImBoletoMes.pas
// (ja validados em producao pela Safra para esta empresa).
const
  cAgSafra         = '1440';           // agencia (4 digitos) usada no calculo do codigo de barras
  cContaSafra      = '00587488';       // conta corrente (8 digitos, sem DV)
  cContaDVSafra    = '9';              // digito verificador da conta corrente
  cContaBarraSafra = '0005874889';     // conta+DV concatenados (campo CONTA do codigo de barras)
  cPrefixoNNSafra  = '422';            // prefixo do nosso numero livre do Safra
  cAgSafraLabel    = '14400';          // agencia exibida no campo "Agencia/Codigo Beneficiario"
  cCNPJEmpresa     = '40868234000170'; // CNPJ da SEDE DAS MIUDEZAS ATACADO LTDA
// ===========================================================================

procedure TFormBoleto.BitBtn1Click(Sender: TObject);
var cNumNot,cFiltro:string;
begin
  cFiltro := '(CODPOR <> "999") AND'+
             '(FLAGAPO = " ") AND (FLAGSIT = "4" OR FLAGSIT = "5") AND'+
             '(MODATEND <> "9.999") AND '+
             '( IF( NATOPE=0.000,(IMPERIAL = "H"),TRUE ) ) AND'+
             '( IF( NATOPE<>0.000,(NUMPROTOC <> "                    "),TRUE ) ) AND'+
             '(NATOPE <> 1.111) AND '+
             '(CODTAB <> "AA") AND CODTAB <> "AB")';

  DM.ATCadPd1.SetFiltered(False);
  DM.ATCadPd1.Filter := cFiltro;
  DM.ATCadPd1.SetFiltered(True);
  DM.ATCadPd1.GoTop;

  if DM.ATCadPd1.Eof Then
    ShowMessage('Nenhum boleto para ser impresso')
  else
    begin
      DM.ATCadPd1.SetOrder(2);    // notafisc
      DM.ATCadPd1.GoTop;
      while not DM.ATCadPd1.Eof do
        begin

          //if TemFilaImpressao('Nome da sua impressora') then     capturar nome da impressora padrao
          //  ShowMessage('Tem coisa na fila de impressão')
          //else
          //  ShowMessage('Fila vazia');
          ShowMessage('gerar pdf');

          cNumNot := Copy(DM.ATCadPd1NOTAFISC.AsString,4,6);
          IF (DM.ATCadPd1CODPOR.Text = '001') and (not Fileexists('f:\DATANET\BOL\BB'+cNumNot+'.PDF')) then
            begin
              // gera o boleto em pdf para depois imprimir...
              RvSystemBoleto.DoNativeOutput           := False;
              RvSystemBoleto.DefaultDest              := rdFile;
              RvSystemBoleto.SystemOptions            := RvSystemBoleto.SystemOptions - [soShowStatus];
              RvSystemBoleto.SystemFiler.StatusFormat := 'Gerando PDF pag. %p';
              RvSystemBoleto.RenderObject             := RvRenderPDF1;
              RvSystemBoleto.SystemSetups             := RvSystemBoleto.SystemSetups - [ssAllowSetup];
              RvSystemBoleto.OutputFileName           := 'f:\DATANET\BOL\BB'+cNumNot+'.PDF';
              RvSystemBoleto.Execute;

              // imprime o pdf direto para impressora
              ShellExecute(Application.handle, 'print',PChar('f:\DATANET\BOL\BB'+cNumNot+'.PDF'), nil,nil,SW_HIDE);
              //ShellExecute(Application.handle, 'open',PChar('F:\DATANET\BOL\BB'+cNumNot+'.PDF'), nil,nil,SW_SHOWMAXIMIZED);
            end
          else IF (DM.ATCadPd1CODPOR.Text = '341') and (not Fileexists('c:\DATANET\BOL\IT'+cNumNot+'.PDF')) then
            begin
              // gera o boleto em pdf para depois imprimir...
              ShowMessage('gerar pdf');

              RvSystemBoleto.DoNativeOutput           := False;
              RvSystemBoleto.DefaultDest              := rdFile;       // rdFile = gera pdf
              RvSystemBoleto.SystemOptions            := RvSystemBoleto.SystemOptions - [soShowStatus];
              RvSystemBoleto.SystemFiler.StatusFormat := 'Gerando PDF pag. %p';
              RvSystemBoleto.RenderObject             := RvRenderPDF1;
              RvSystemBoleto.SystemSetups             := RvSystemBoleto.SystemSetups - [ssAllowSetup];
              RvSystemBoleto.OutputFileName           := 'c:\DATANET\BOL\IT'+cNumNot+'.PDF';
              RvSystemBoleto.Execute;

              // imprime o pdf direto para impressora
              ShellExecute(Application.handle, 'print',PChar('c:\DATANET\BOL\IT'+cNumNot+'.PDF'), nil,nil,SW_HIDE);   // SW_HIDE
              //ShellExecute(Application.handle, 'open',PChar('c:\DATANET\BOL\IT'+cNumNot+'.PDF'), nil,nil,SW_SHOWMAXIMIZED);
            end
          else IF (DM.ATCadPd1CODPOR.Text = '422') and (not Fileexists('c:\DATANET\BOL\SF'+cNumNot+'.PDF')) then
            begin
              // gera o boleto em pdf para depois imprimir...
              RvSystemBoleto.DoNativeOutput           := False;
              RvSystemBoleto.DefaultDest              := rdFile;       // rdFile = gera pdf
              RvSystemBoleto.SystemOptions            := RvSystemBoleto.SystemOptions - [soShowStatus];
              RvSystemBoleto.SystemFiler.StatusFormat := 'Gerando PDF pag. %p';
              RvSystemBoleto.RenderObject             := RvRenderPDF1;
              RvSystemBoleto.SystemSetups             := RvSystemBoleto.SystemSetups - [ssAllowSetup];
              RvSystemBoleto.OutputFileName           := 'c:\DATANET\BOL\SF'+cNumNot+'.PDF';
              RvSystemBoleto.Execute;

              // imprime o pdf direto para impressora
              ShellExecute(Application.handle, 'print',PChar('c:\DATANET\BOL\SF'+cNumNot+'.PDF'), nil,nil,SW_HIDE);
            end;


          DM.ATCadPd1.Edit;
          DM.ATCadPd1FLAGAPO.AsString := '*';
          DM.ATCadPd1.Post;

          DM.ATCadAud.Append;
          DM.ATCadAudDATA_SIS.AsString   := DateToStr(Date);
          DM.ATCadAudDATA_DOS.AsString   := DateToStr(Date);
          DM.ATCadAudHORA_DOS.AsString   := TimeToStr(Time);
          DM.ATCadAudCODUSU.AsString     := '???';
          DM.ATCadAudNOMEUSU.AsString    := '???????';
          DM.ATCadAudDOCUMENTO.AsString  := DM.ATCadPd1NOTAFISC.AsString;
          DM.ATCadAudMOVIMENTO.AsString  := 'Emissao do boleto do dia';
          DM.ATCadAud.Post;

          DM.ATCadPd1.Next;
        end;
    end;
 close;
end;

procedure TFormBoleto.MaskEdit1Exit(Sender: TObject);
var
  nNumDig:integer;
begin

  if MaskEdit1.Text <> '' then
    begin
      nNumDig := Length(MaskEdit1.Text);
      MaskEdit1.Text := Copy('000'+MaskEdit1.Text,nNumDig+1,3);

      DM.ATCadPor.SetOrder(1);
      DM.ATCadPor.Seek(MaskEdit1.Text);

      if (MaskEdit1.Text <> DM.ATCadPorCODPOR.AsString) Then
        begin
          cFiltro := 'CODPOR = "???"';
          Label4.Caption := '';
          ShowMessage('Código do Potador inválido');
        end
      else
        Label4.Caption := DM.ATCadPorNOMPOR.AsString;
        cFiltro := '(CODPOR <> "999") AND'+
                   '(FLAGAPO = " ") AND (FLAGSIT = "4" OR FLAGSIT = "5") AND'+
                   '(MODATEND <> "9.999") AND '+
                   '( IF( NATOPE=0.000,(IMPERIAL = "H"),TRUE ) ) AND'+
                   '( IF( NATOPE<>0.000,(NUMPROTOC <> "                    "),TRUE ) ) AND'+
                   '(NATOPE <> 1.111)';
    end
  else
    begin
      cFiltro := 'CODPOR = "???"';
      Label4.Caption := '';
      ShowMessage('Código do Potador inválido');
    end;

  {
  cFiltro := '(CODPOR <> "999") AND'+
             '(FLAGAPO = " ") AND (FLAGSIT = "4" OR FLAGSIT = "5") AND'+
             '(MODATEND <> "9.999") AND '+
             '( IF( NATOPE=0.000,(IMPERIAL = "H"),TRUE ) ) AND'+
             '( IF( NATOPE<>0.000,(NUMPROTOC <> "                    "),TRUE ) ) AND'+
             '(NATOPE <> 1.111)';
  }
  DM.ATCadPd1.Filter := cFiltro;
  DM.ATCadPd1.SetFiltered(True);
  DM.ATCadPd1.GoTop;

end;

procedure TFormBoleto.RvSystemBoletoPrint(Sender: TObject);
var
  Bitmap:TBitmap;
  nJuros,nDescontos:real;
  Linha,cNossoNum:Real;
  cCNPJ,cInsc,cLinhaDig,cNossoNumAux:string;
  y:integer;
  cMoeda,cDv,cFator,cValTit,cCampoLivre:String;
  lDataSaida: Boolean;
begin
  with Sender as TBaseReport do
    begin

      cMoeda      := '9'; // Real
      cDv         := '';  // dígito verificador do código de barras
      cFator      := '';  // Fator de vencimento
      cValTit     := '';  // Valor do título
      cCampoLivre := '';  // Campo Livre de acordo com cada banco

      DM.ATCadSet.SetOrder(1);
      DM.ATCadSet.Seek(DM.ATCadPd1CODSET.AsString);

      DM.ATCadCli.SetOrder(1);
      DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        lDataSaida := True;
      Except
        lDataSaida := False;
      end;

      if DM.ATCadPd1PRAZOLIM1.Value > 0 then
        begin
          nParcela := 1;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    begin
                      DM.ATCadPd1.SetOrder(19);                             // nossonum
                      if not DM.ATCadPd1.seek(cNossoNumAux) then
                        begin
                          DM.ATCadPd1.SetOrder(20);                           // nossonum2
                          if not DM.ATCadPd1.seek(cNossoNumAux) then
                            begin
                              DM.ATCadPd1.SetOrder(21);                         // nossonum3
                              if not DM.ATCadPd1.seek(cNossoNumAux) then
                                begin
                                  DM.ATCadPd1.SetOrder(22);                       // nossonum4
                                  if not DM.ATCadPd1.seek(cNossoNumAux) then
                                    begin
                                      DM.ATCadPd1.SetOrder(23);                     // nossonum5
                                      if not DM.ATCadPd1.seek(cNossoNumAux) then
                                        begin
                                         DM.ATCadPd1.SetOrder(24);                   // nossonum6
                                         if not DM.ATCadPd1.seek(cNossoNumAux) then
                                           Break  // sai do loop
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  {
                  if cNossoNum >= 191000 then
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := '00191999';
                      DM.ATCadEm2.Post;
                      cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;    // inicia em 192000. fiz isso devido ter usado a faixa de numeração de 191000 até 191999 anteriormente
                    end;
                  }
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa

                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM1.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      if lDataSaida then
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant))
                      else
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant));
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-1/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ1.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4; // boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM1.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM1.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM1.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;

              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM1.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  if lDataSaida then
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant))
                  else
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant));
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-1/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ1.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ1.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+Format('%7.2f',[nJuros])+' AO DIA.');
                  //Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;

              Linha := Linha + 0.3;
              PrintXY(1.7,Linha,'CHAVE PARA PAGAMENTO POR PIX: 40868234000170');

              if DM.ATCadPd1DESCANTE1.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  if DM.ATCadCliTODALINHA.AsString = 'S' then  // KARNE KEIJO, desconto no total da nota
                    nDescontos := (DM.ATCadPd1DESCANTE1.AsFloat * (DM.ATCadPd1VALFATPZ1.AsFloat)) / 100
                  else
                    nDescontos := (DM.ATCadPd1DESCANTE1.AsFloat * (DM.ATCadPd1VALFATPZ1.AsFloat-DM.ATCadPd1VALICMRET.AsFloat)) / 100;

                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT1.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT1.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;

              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3 ,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6 ,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9 ,'Não receber após 60 dias do vencimento');

              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}



              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;  // boleto 1

      if DM.ATCadPd1PRAZOLIM2.Value > 0 then
        begin
          NewPage;
          nParcela := 2;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa

                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM2.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      if lDataSaida then
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant))
                      else
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant));
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-2/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ2.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4;// boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM2.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM2.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM2.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;


              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM2.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  try
                    StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant))
                  Except
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant))
                  end;
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-2/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ2.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ2.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                Format('%7.2f',[nJuros])+' AO DIA.');
                  Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;
              if DM.ATCadPd1DESCANTE2.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  nDescontos := (DM.ATCadPd1DESCANTE2.AsFloat * (DM.ATCadPd1VALFATPZ2.AsFloat))/100;
                  //nDescontos := (DM.ATCadPd1DESCANTE2.AsFloat * (DM.ATCadPd1VALFATPZ2.AsFloat-DM.ATCadPd1VALICMRET.AsFloat))/100;
                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT2.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT2.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;
              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9,'Não receber após 60 dias do vencimento');

              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}
              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;   // boleto 2

      if DM.ATCadPd1PRAZOLIM3.Value > 0 then
        begin
          NewPage;
          nParcela := 3;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM3.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      try
                        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant))
                      Except
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant))
                      end;
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-3/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ3.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4;// boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM3.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM3.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM3.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;


              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM3.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  try
                    StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant))
                  Except
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant))
                  end;
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-3/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ3.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ3.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                Format('%7.2f',[nJuros])+' AO DIA.');
                  Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;
              if DM.ATCadPd1DESCANTE3.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  nDescontos := (DM.ATCadPd1DESCANTE3.AsFloat * (DM.ATCadPd1VALFATPZ3.AsFloat))/100;
                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT3.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT3.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;
              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9 ,'Não receber após 60 dias do vencimento');


              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}
              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;  // boleto 3'

      if DM.ATCadPd1PRAZOLIM4.Value > 0 then
        begin
          NewPage;
          nParcela := 4;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM4.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      try
                        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant))
                      Except
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant))
                      end;
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-4/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ4.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4;// boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM4.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM4.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM4.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;


              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM4.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  try
                    StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant))
                  Except
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant))
                  end;
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-4/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ4.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ4.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                Format('%7.2f',[nJuros])+' AO DIA.');
                  Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;
              if DM.ATCadPd1DESCANTE4.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  nDescontos := (DM.ATCadPd1DESCANTE4.AsFloat * (DM.ATCadPd1VALFATPZ4.AsFloat))/100;
                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT4.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT4.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;
              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9 ,'Não receber após 60 dias do vencimento');

              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}
              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;  // boleto 4

      if DM.ATCadPd1PRAZOLIM5.Value > 0 then
        begin
          NewPage;
          nParcela := 5;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM5.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      try
                        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant))
                      Except
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant))
                      end;
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-5/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ5.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4;// boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM5.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM5.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM5.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;


              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM5.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  try
                    StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant))
                  Except
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant))
                  end;
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-5/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ5.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ5.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                Format('%7.2f',[nJuros])+' AO DIA.');
                  Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;
              if DM.ATCadPd1DESCANTE5.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  nDescontos := (DM.ATCadPd1DESCANTE5.AsFloat * (DM.ATCadPd1VALFATPZ5.AsFloat))/100;
                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT5.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT5.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;
              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9 ,'Não receber após 60 dias do vencimento');

              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}
              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;  // boleto 5

      if DM.ATCadPd1PRAZOLIM6.Value > 0 then
        begin
          NewPage;
          nParcela := 6;
          Bitmap := TBitmap.Create;
          try
            if DM.ATCadPd1CODPOR.AsString = '001' then
              Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
            else if DM.ATCadPd1CODPOR.AsString = '422' then
              Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
            else
              Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');
            PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
          finally
            FreeAndNil(Bitmap);
          end;

          // pega um novo nosso numero que ainda nao exista no sacadtit
          while True do
            begin
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                  cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                  cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0');
                      DM.ATCadEm2.Post;
                    end;
                end
              else         // itau
                begin
                  cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
                  cNossoNumAux := '109'+Padl(IntToStr(Trunc(cNossoNum)), 8, '0');

                  DM.ATCadTit.SetOrder(13);    // nossonum
                  if not DM.ATCadTit.seek(cNossoNumAux) then
                    Break  // sai do loop
                  else
                    begin
                      DM.ATCadEm2.Edit;
                      DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
                      DM.ATCadEm2.Post;
                    end;
                end;
            end;

          DM.ATCadEm2.Edit;
          if DM.ATCadPd1CODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')  // 10 + os 7 digitos do convenio abaixo
          else if DM.ATCadPd1CODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')  // 3+6 = 9 digitos (prefixo 422 + sequencial)
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');  // 10 + os 7 digitos do convenio abaixo
          DM.ATCadEm2.Post;

          for y := 1 to 2 do  // dois boletos
            begin
              SetFont('Times New Roman',8);
              Bold := True;
              Bold := False;
              if y = 1 then
                begin
                  // canhoto da empresa
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  Linha := 4.3; // boleto do sacado
                  if DM.ATCadPd1PRAZOLIM6.AsVariant = 0 then
                    PrintXY(16.6,Linha+0.1,'A VISTA')
                  else
                    begin
                      try
                        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant))
                      Except
                        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant))
                      end;
                    end;

                  PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
                  else
                    PrintXY(16.6,Linha+0.75,'8322/11901-0');

                  PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-6/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.4,'DM');
                  PrintXY(11.4,Linha+1.4,'N');
                  PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
                  if DM.ATCadPd1CODPOR.AsString = '001' then
                    begin
                      PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                      PrintXY(5.5,Linha+2,'17-027');
                    end
                  else if DM.ATCadPd1CODPOR.AsString = '422' then
                    begin
                      PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                      PrintXY(5.5,Linha+2,'01');
                    end
                  else
                    begin
                      PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                      PrintXY(5.5,Linha+2,'109');
                    end;

                  PrintXY(8.3,Linha+2,'R$');
                  PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadPd1VALFATPZ6.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

//                  DM.ATCadCli.SetOrder(1);
//                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
//                  PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);

                  Linha := Linha+2.6;
                  DM.ATCadCli.SetOrder(1);
                  DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
                  else
                    cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

                  if DM.ATCadCliPESFISJUR.AsString = 'J' then
                    cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

                  PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
                  PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
                  PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
                  PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                        DM.ATCadCliCIDCLI.AsString+' - '+
                                        DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                        dm.ATCadCliCEPCLI.AsString);

                  PrintXY(1.7,Linha+0.9,'SETOR: '+DM.ATCadPd1CODSET.AsString+' - '+
                                                  DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+
                                                  DM.ATCadPd1CODCLI.AsString+'      CONTROLE: '+
                                                  DM.ATCadPd1CONTROLE.AsString+'      CAMINHAO: '+
                                                  DM.ATCadPd1CAMINHAO.AsString+'     FONE: '+
                                                  DM.ATCadCliTELCLI.AsString);
                  // fim da impressao do canhoto.

                  Linha := 10.4;// boleto do sacado
                end
              else
                if DM.ATCadPd1CODPOR.AsString = '001' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM6.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString;
                    DM.ATCadPd1.Post;
                  end
                else if DM.ATCadPd1CODPOR.AsString = '422' then
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('422');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM6.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;
                    DM.ATCadPd1.Post;
                  end
                else
                  begin
                    Linha := 20.2;  // boleto do banco
                    cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco
                    PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                    SetFont('Times New Roman',10);
                    PrintXY(7.5,3.5,cLinhaDig);
                    PrintXY(7.5,9.6 ,cLinhaDig);
                    SetFont('Times New Roman',12);
                    Bold := True;
                    PrintXY(8.4,19.5,cLinhaDig);
                    SetFont('Times New Roman',8);

                    DM.ATCadPd1.Edit;
                    DM.ATCadPd1NOSSONUM6.AsString := DM.ATCadEm2NOSSONUM2.AsString;
                    DM.ATCadPd1.Post;
                  end;


              // inicio da impressão do boleto (boleto do sacado e do banco)

              if DM.ATCadPd1PRAZOLIM6.AsVariant = 0 then
                PrintXY(16.6,Linha+0.1,'A VISTA')
              else
                begin
                  try
                    StrToDate(DM.ATCadPd1DTSAIDA.AsString);
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant))
                  Except
                    PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant))
                  end;
                end;

              PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA - '+formatacnpj(cCNPJEmpresa));

              if DM.ATCadPd1CODPOR.AsString = '001' then
                PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                PrintXY(16.6,Linha+0.75,cAgSafraLabel+' / '+cContaSafra+cContaDVSafra)
              else
                PrintXY(16.6,Linha+0.75,'8322/11901-0');

              PrintXY(1.9, Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              PrintXY(4.8, Linha+1.4,DM.ATCadPd1NOTAFISC.AsString+'-6/'+DM.ATCadPd1NUMDUPLIC.AsString);
              PrintXY(8.3, Linha+1.4,'DM');
              PrintXY(11.4,Linha+1.4,'N');
              PrintXY(13.6,Linha+1.4,DM.ATCadPd1DTEMIS.AsString);
              if DM.ATCadPd1CODPOR.AsString = '001' then
                begin
                  PrintXY(16.1,Linha+1.4,'1406478'+DM.ATCadEm2nossonum.AsString);
                  PrintXY(5.5,Linha+2,'17-027');
                end
              else if DM.ATCadPd1CODPOR.AsString = '422' then
                begin
                  PrintXY(16.1,Linha+1.4,cPrefixoNNSafra+DM.ATCadEm2nossonum3.AsString);
                  PrintXY(5.5,Linha+2,'01');
                end
              else
                begin
                  PrintXY(16.1,Linha+1.4,'109/'+DM.ATCadEm2nossonum2.AsString+'-'+Modulo10('832211901109'+DM.ATCadEm2nossonum2.AsString));
                  PrintXY(5.5,Linha+2,'109');
                end;
              PrintXY(8.3,Linha+2,'R$');
              PrintXY(17.38,Linha+2.05,Format('%10.2m',[DM.ATCadPd1VALFATPZ6.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

              nJuros :=  DM.ATCadPd1VALFATPZ6.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

              if y = 1 then
                Linha := 12.9     // boleto do sacado
              else
                Linha := 22.6; // boleto do banco

              if nJuros > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                Format('%7.2f',[nJuros])+' AO DIA.');
                  Linha := Linha + 0.3;
                  //PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                end;
              if DM.ATCadPd1DESCANTE6.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  nDescontos := (DM.ATCadPd1DESCANTE6.AsFloat * (DM.ATCadPd1VALFATPZ6.AsFloat))/100;
                  if lDataSaida then
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOANT6.AsVariant))
                  else
                    PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                      Format('%7.2f',[nDescontos])+
                                      ' PARA PAGAMENTO ATÉ: '+
                                      FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT6.AsVariant));
                end
              else
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'NÃO CONCEDER DESCONTOS');
                end;
              if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                begin
                  Linha := Linha + 0.3;
                  PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                    Format('%7.2f',[DM.ATCadCliVALTARBAN.AsFloat]));
                end;

              //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
              PrintXY(1.7,Linha+0.3,'PROTESTAR APÓS QUINTO DIA DO VENCIMENTO');
              PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadPd1CODSET.AsString+'   CLIENTE: '+DM.ATCadPd1CODCLI.AsString);
              PrintXY(1.7,Linha+0.9 ,'Não receber após 60 dias do vencimento');

              if y = 1 then
                Linha := 15
              else
                Linha := 24.8;
{
               if DM.ATCadPd1CODPOR.AsString = '001' then
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS:');
                   PrintXY(1.7,Linha+0.3,'http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
                 end
               else
                 begin
                   PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
                 end;
}
              // Sacado
              if y = 1 then
                Linha := 16.1  // boleto do sacado
              else
                Linha := 25.9; // boleto do banco

              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cCNPJ := 'CNPJ: '+formatacnpj(DM.ATCadCliCGCCLI.AsString)
              else
                cCNPJ := 'CPF: '+DM.ATCadCliCPFCLI.AsString;

              if DM.ATCadCliPESFISJUR.AsString = 'J' then
                cInsc := 'ISNC.EST: '+formataInsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString);

              PrintXY(1.7,Linha,DM.ATCadCliRAZSOCCLI.AsString);
              PrintXY(10,Linha,cCNPJ+'  --  '+cInsc);
              PrintXY(1.7,Linha+0.3,DM.ATCadCliENDCLI.AsString);
              PrintXY(1.7,Linha+0.6,DM.ATCadCliBAIRCLI.AsString+' - '+
                                    DM.ATCadCliCIDCLI.AsString+' - '+
                                    DM.ATCadCliESTCLI.AsString+' - CEP: '+
                                    dm.ATCadCliCEPCLI.AsString);
            end;

        end;  // boleto 6

    end;



  exit;
end;

procedure TFormBoleto.MaskEdit1Enter(Sender: TObject);
begin
  MaskEdit1.Text := '001';
end;

function TFormBoleto.formatacnpj(Cnpj: String): string;
begin
  Result := Copy(Cnpj,1,2)+'.'+Copy(Cnpj,3,3)+'.'+Copy(Cnpj,6,3)+'/'+
            Copy(Cnpj,9,4)+'-'+Copy(Cnpj,13,2);
end;

function TFormBoleto.formatainsc(insc, uf: String): string;
begin
 IF Pos(uf,'SP') > 0 then
  Result := Copy(insc,3,3)+'.'+Copy(insc,6,3)+'.'+Copy(insc,9,3)+'.'+
  Copy(insc,12,3)
  //999.999.999.999
 ELSE IF Pos(uf,'RJ,BA') > 0 then
  Result := Copy(insc,7,2)+'.'+Copy(insc,9,3)+'.'+Copy(insc,12,3)
  //99.999.999
 ELSE IF Pos(uf,'PE') > 0 then
  Result := Copy(insc,6,7)+'-'+Copy(insc,13,2)
  //9999999-99
 ELSE IF Pos(uf,'RS') > 0 then
  Result := Copy(insc,4,3)+'/'+Copy(insc,8,7)
  //999/9999999
 ELSE IF Pos(uf,'PB,SE,RN,MA,AL,CE,PA,PI') > 0 then
  Result := Copy(insc,5,2)+'.'+Copy(insc,8,3)+'.'+Copy(insc,11,3)+'-'+Copy(insc,14,1)
  //99.999.999-9
 ELSE IF Pos(uf,'SC') > 0 then
  Result := Copy(insc,1,3)+'.'+Copy(insc,4,3)+'.'+Copy(insc,7,3)
  //999.999.999
 ELSE
  Result := Copy(insc,1,14);
  //99999999999999
end;

function TFormBoleto.GeraCodBarra2de5(cCodBanco: String): String;
const
  CorBarra = clBlack;       // clBlack
  CorEspaco = clWhite;      // clWhite
  LarguraBarraFina = 1;     // 1
  LarguraBarraGrossa = 3;   // 3
  AlturaBarra = 50;         // 50
{Traduz dígitos do código de barras para valores de 0 e 1, formando um código do tipo Intercalado 2 de 5}
var
  CodigoAuxiliar: string;
  Start: string;
  Stop: string;
  T2de5: array[0..9] of string;
  Codifi: string;
  I: integer;
  aux:real;

  X: integer;
  DAC1,DAC2:string;
  Col: integer;
  Lar: integer;
  ImgBarras: TImage;
  cCodigo,cMoeda,cFator,cValTit,cCampoLivre,cDv,cNossoNumAux,cCarteira:string;
begin
  Result := 'Erro';
  Start := '0000';
  Stop := '100';
  T2de5[0] := '00110';
  T2de5[1] := '10001';
  T2de5[2] := '01001';
  T2de5[3] := '11000';
  T2de5[4] := '00101';
  T2de5[5] := '10100';
  T2de5[6] := '01100';
  T2de5[7] := '00011';
  T2de5[8] := '10010';
  T2de5[9] := '01010';

  { Digitos }

  cMoeda      := '9'; // Real
  if nParcela = 1 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ1.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 2 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ2.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 3 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ3.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 4 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ4.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 5 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ5.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 6 then
    begin
      try
        StrToDate(DM.ATCadPd1DTSAIDA.AsString);
        cFator      := FatorVencto(DM.ATCadPd1DTSAIDA.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant, cCodBanco);   // Fator de vencimento
      Except
        cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant, cCodBanco);   // Fator de vencimento
      end;
      aux         := (DM.ATCadPd1VALFATPZ6.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;

  // obs. o campo nosso numero, nao contem o codigo do convenio(1406478), para facilitar...
  if cCodBanco = '001' then
    begin
      cCarteira    := '17';
      cNossoNumAux := DM.ATCadEm2NOSSONUM.AsString;
      cDv          := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+'000000'+'1406478'+cNossoNumAux+cCarteira);   // dígito verificador do código de barras
      cCodigo      := cCodBanco+cMoeda+cDv+cFator+cValTit+'000000'+'1406478'+cNossoNumAux+cCarteira;
    end
  else if cCodBanco = '422' then
    begin
      // SAFRA: layout do campo livre (posicoes 20-44) conforme manual
      // "Cobranca Safra - Layout Padrao Safra CNAB 240": F(1)+Agencia(4)+
      // Conta(10)+NossoNumero(9)+F(1). DAC1 = Modulo10(agencia) - posicao
      // 20, "Primeiro Fixo". DAC2 = '2' fixo - posicao 44, "Segundo Fixo"
      // (confirmado pelo relatorio real de validacao da Safra; ver
      // UnitImBoletoMes.pas para o historico completo da investigacao).
      cNossoNumAux := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString;   // 9 digitos (422 + 6 sequenciais)
      DAC1    := Modulo10(cAgSafra);
      DAC2    := '2';
      cDv     := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+DAC1+cAgSafra+cContaBarraSafra+cNossoNumAux+DAC2);
      cCodigo := cCodBanco+cMoeda+cDv+cFator+cValTit+DAC1+cAgSafra+cContaBarraSafra+cNossoNumAux+DAC2;
    end
  else
    begin
      cCarteira    := '109';
      cNossoNumAux := DM.ATCadEm2NOSSONUM2.AsString;     // 8 DIGITOS LIVRES

      // DAC1 [Agência /Conta/Carteira/Nosso Número] (Anexo 4)
      DAC1 := Modulo10('832211901'+cCarteira+cNossoNumAux);

      // DAC2 [Agência/Conta Corrente] (Anexo 3)
      DAC2 := Modulo10('8322'+'11901');

      cDv     := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+cCarteira+cNossoNumAux+DAC1+'8322'+'11901'+DAC2+'000');
      cCodigo := cCodBanco+cMoeda+cDv+cFator+cValTit+cCarteira+cNossoNumAux+DAC1+'8322'+'11901'+DAC2+'000';
    end;

  for I := 1 to length(cCodigo) do
  begin
    if pos(cCodigo[I], '0123456789') <> 0 then
      // concatenando os digitos binários do código informado...
      Codifi := Codifi + T2de5[StrToInt(cCodigo[I])]
    else
      Exit;
  end;

  {Se houver um número ÍMPAR de dígitos no Código, acrescentar um ZERO no início}
  if odd(length(cCodigo)) then
    Codifi := T2de5[0] + Codifi;

  {Intercalar números - O primeiro com o segundo, o terceiro com o quarto, etc...}
  I := 1;
  CodigoAuxiliar := '';
  while I <= (length(Codifi) - 9) do
    begin
      CodigoAuxiliar := CodigoAuxiliar + Codifi[I]     + Codifi[I + 5] +
                                         Codifi[I + 1] + Codifi[I + 6] +
                                         Codifi[I + 2] + Codifi[I + 7] +
                                         Codifi[I + 3] + Codifi[I + 8] +
                                         Codifi[I + 4] + Codifi[I + 9];
      I := I + 10;
    end;

  //-------------------------------------------------

  CodigoAuxiliar := Start + CodigoAuxiliar + Stop;
  ImgBarras := TImage.Create(nil);

  // Image1.Canvas.Rectangle(5, 5, 210, 60);
  try
    ImgBarras.Height := AlturaBarra;
    ImgBarras.Width := 0;
    for X := 1 to Length(CodigoAuxiliar) do
      case CodigoAuxiliar[X] of
        '0': ImgBarras.Width := ImgBarras.Width + LarguraBarraFina;
        '1': ImgBarras.Width := ImgBarras.Width + LarguraBarraGrossa;
      end;

    Col := 0;

    if CodigoAuxiliar <> 'Erro' then
      begin
        for X := 1 to length(CodigoAuxiliar) do
        begin
          {Desenha barra}
          with Image1.Canvas do
          begin
            if Odd(X) then
              Pen.Color := CorBarra
            else
              Pen.Color := CorEspaco;

            if CodigoAuxiliar[X] = '0' then
            begin
              for Lar := 1 to LarguraBarraFina do
              begin
                MoveTo(Col, 0);
                LineTo(Col, AlturaBarra);
                Col := Col + 1;
              end;
            end
            else
            begin
              for Lar := 1 to LarguraBarraGrossa do
              begin
                MoveTo(Col, 0);
                LineTo(Col, AlturaBarra);
                Col := Col + 1;
              end;
            end;
          end;
        end;
      end
    else
      Image1.Canvas.TextOut(0, 0, 'Erro');

  finally
    //Image1.Free;
  end;
  result := LinhaDigitavel(cCodigo);
end;

function TFormBoleto.DIGNOSSONUM(cNossoNum:String;cPeso:string): String;
var
  nSoma,y,Resto:integer;
begin
  nSoma := 0;
  for y := Length(cNossoNum) downto 1 do
    begin
      Inc(nSoma,StrToInt(cNossoNum[y]) * StrToInt(cPeso[y]));
    end;

  Resto := nSoma mod 11;

  if Resto = 0 then
    Result := '0'
  else if Resto < 10 then
    Result := IntToStr(Resto)
  else if Resto = 10 then
    Result := 'X';
end;

function TFormBoleto.CalcDigVerificador(CodigoBarras: string): char;
var
  Somatoria, P, Peso, i, Resto: integer;
begin
  Peso := 2;
  Somatoria := 0;
  for i := Length(CodigoBarras) downto 1 do
    if i <> 5 then // Pula a quinta casa, pois eh a propria casa do digito verificador
    begin
      P := StrToInt(CodigoBarras[i]) * Peso;
      Inc(Somatoria, P);
      if Peso < 9 then
        Inc(Peso, 1)
      else
        Peso := 2;
    end;

  Resto := 11 - (Somatoria mod 11);

  if (Resto = 0) or (Resto = 1) or (Resto > 9) then
    Result := '1'
  else
    Result := chr(48 + Resto); // CHR(48) = '0', CHR(49) = '1', etc...
end;

function TFormBoleto.FatorVencto(dDataVenc: TDate; cCodBanco: string): string;
var
  FatVencto: LongInt;
begin
  if dDataVenc < EncodeDate(1997, 10, 7) then
    ShowMessage('O vencimento do boleto deve ser superior à 7-Outubro-1997');
  // Regra FEBRABAN vigente desde 22/02/2025: o fator de vencimento antigo
  // (dias corridos desde 07/10/1997) estourava 9999 nessa data; a partir
  // dai o fator reinicia em 1000 e conta os dias desde entao (mesmo fix
  // aplicado em UnitImBoletoMes.pas). Aplicada SO para o Safra (422): BB/
  // Itau continuam na formula antiga a pedido do usuario, que ja usa
  // esses bancos em producao sem rejeicao.
  if (cCodBanco = '422') and (dDataVenc >= EncodeDate(2025, 2, 22)) then
    FatVencto := 1000 + (Trunc(dDataVenc) - Trunc(EncodeDate(2025, 2, 22)))
  else
    FatVencto := Abs(Trunc(dDataVenc) - Trunc(EncodeDate(1997, 10, 7)));
  Result := PadL(IntToStr(FatVencto), 4, '0');
end;

function TFormBoleto.PadL(Oque: string; Tamanho: integer;
  ComOque: char): string;
var
  FillStr: string;
begin
  Oque := trim(Oque);
  SetLength(FillStr, Tamanho);
  FillChar(FillStr[1], Tamanho, ComOque);
  if Length(Oque) > Tamanho then
    Result := Copy(Oque, 1, Tamanho)
  else
    Result := Copy(FillStr, 1, Tamanho - Length(oque)) + Oque;
end;


function TFormBoleto.LinhaDigitavel(cCodigoBarras: string): string;
var
  c1, c2, c3, c4, c5: string;
begin
  if DM.ATCadPd1CODPOR.Text = '001' then
    begin
      // cCodBanco+cMoeda+'0'+cFator+cValTit+'000000'+'1406478'+cNossoNumAux+cCarteira

      c1 := Copy(cCodigoBarras,1,4) + Copy(cCodigoBarras, 20, 5);
      c1 := c1 + Modulo10(c1);
      Insert('.', c1, 6);

      c2 := Copy(cCodigoBarras, 25, 10);
      c2 := c2 + Modulo10(c2);
      Insert('.', c2, 6);

      c3 := Copy(cCodigoBarras, 35, 10);
      c3 := c3 + Modulo10(c3);
      Insert('.', c3, 6);

      c4 := Copy(cCodigoBarras, 5, 1);
      c5 := Copy(cCodigoBarras, 6, 14);
    end;

  if DM.ATCadPd1CODPOR.Text = '341' then
    begin
      // codigo de barras do itau na cobranca simples

      // 01 - cCodBanco    = 341
      // 04 - cMoeda       = 9
      // 05 - cDV          = '?'
      // 06 - cFator       = 1234
      // 10 - cValTit      = 0123456789
      // 20 - cCarteira    = 109
      // 23 - cNossoNumAux = 01234567
      // 31 - DAC1         = '?'
      // 32 - '8322'       = Agencia
      // 36 - '11901'      = Conta
      // 41 - DAC2         = '?' 
      // 42 - '000'        = Zeros
      //
      // cCodBanco+cMoeda+'0'+cFator+cValTit+cCarteira+cNossoNumAux+DAC1+'8322'+'11901'+DAC2+'000'

      c1 := Copy(cCodigoBarras,1,4) + Copy(cCodigoBarras, 20, 5);   // cCodBanco+cMoeda + cCarteira + Dois primeiros dígitos do nosso número
      c1 := c1 + Modulo10(c1);
      Insert('.', c1, 6);

      c2 := Copy(cCodigoBarras, 25, 10);                            //  Right(cNossoNumAux,6) + DAC1 + Trez primeiros dígitos da agencia
      c2 := c2 + Modulo10(c2);
      Insert('.', c2, 6);

      c3 := Copy(cCodigoBarras, 35, 10);                            //  Último dígito da agencia + Número Ct Corrente + DAC2 + Tres zeros
      c3 := c3 + Modulo10(c3);
      Insert('.', c3, 6);

      c4 := Copy(cCodigoBarras, 5, 1);                              // Dígito verificador do código de barras
      c5 := Copy(cCodigoBarras, 6, 14);                             // cFator + cValTit
    end;

  if DM.ATCadPd1CODPOR.Text = '422' then
    begin
      // codigo de barras do safra - formula de fatiamento puramente
      // posicional, identica a' do Itau acima (mesmo layout de 44 digitos).
      c1 := Copy(cCodigoBarras,1,4) + Copy(cCodigoBarras, 20, 5);
      c1 := c1 + Modulo10(c1);
      Insert('.', c1, 6);

      c2 := Copy(cCodigoBarras, 25, 10);
      c2 := c2 + Modulo10(c2);
      Insert('.', c2, 6);

      c3 := Copy(cCodigoBarras, 35, 10);
      c3 := c3 + Modulo10(c3);
      Insert('.', c3, 6);

      c4 := Copy(cCodigoBarras, 5, 1);
      c5 := Copy(cCodigoBarras, 6, 14);
    end;

  result := c1 + ' ' + c2 + ' ' + c3 + ' ' + c4 + ' ' + c5;
end;

function TFormBoleto.Modulo10(Valor: string): string;
var
  Somatoria, P, Resto, Peso, i: integer;
begin
  Peso := 2;  Somatoria := 0;
  for i := Length(Valor) downto 1 do
  begin
    P := StrToInt(Valor[i]) * Peso;
    if P > 9 then
      Inc(Somatoria, P - 9)
    else
      Inc(Somatoria, P);

    if Peso = 2 then
      Peso := 1
    else
      Peso := 2;
  end;

  Resto := Somatoria mod 10;

  if Resto = 0 then
    Result := '0'
  else
    Result := IntToStr(10 - Resto);
end;

function TFormBoleto.TemFilaImpressao(
  const NomeImpressora: string): Boolean;
var
  hPrinter: THandle;
  BytesNeeded, JobsReturned: DWORD;
  pJobInfo: Pointer;
begin
  Result := False;

  if not OpenPrinter(PChar(NomeImpressora), hPrinter, nil) then
    Exit;

  try
    // Primeiro pega o tamanho necessário
    EnumJobs(hPrinter, 0, 255, 1, nil, 0, BytesNeeded, JobsReturned);

    if BytesNeeded = 0 then
      Exit;

    GetMem(pJobInfo, BytesNeeded);
    try
      if EnumJobs(hPrinter, 0, 255, 1, pJobInfo, BytesNeeded, BytesNeeded, JobsReturned) then
      begin
        Result := JobsReturned > 0;
      end;
    finally
      FreeMem(pJobInfo);
    end;

  finally
    ClosePrinter(hPrinter);
  end;
end;
end.
