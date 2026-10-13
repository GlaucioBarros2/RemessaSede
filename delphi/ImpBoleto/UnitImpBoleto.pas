unit UnitImpBoleto;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Mask, Buttons, RpRender, RpRenderPDF, RpDefine,
  RpBase, RpSystem, Grids, DBGrids, ExtCtrls, RpRave;

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

    function FatorVencto(dDataVenc:TDate):string;
    function PadL(Oque: string; Tamanho: integer; ComOque: char): string;
    function DIGNOSSONUM(cNossoNum:String;cPeso:string):String;
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

procedure TFormBoleto.BitBtn1Click(Sender: TObject);
begin
  if DM.ATCadPd1.Eof Then
    ShowMessage('Nenhum boleto para ser impresso')
  else
    begin
      RvSystemBoleto.Execute;
      DM.ATCadPd1.GoTop;
      close;
    end;
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
        cFiltro := '(CODPOR = "'+MaskEdit1.Text+'") AND'+
                   '(FLAGAPO = " ") AND (FLAGSIT = "4" OR FLAGSIT = "5") AND'+
                   '(MODATEND <> "9.999") AND'+
                   '(NATOPE <> 0.000) AND'+
                   '(NATOPE <> 1.111)';
    end
  else
    begin
      cFiltro := 'CODPOR = "???"';
      Label4.Caption := '';
      ShowMessage('Código do Potador inválido');
    end;

  DM.ATCadPd1.Filter := cFiltro;
  DM.ATCadPd1.SetFiltered(True);
  DM.ATCadPd1.GoTop;

end;

procedure TFormBoleto.RvSystemBoletoPrint(Sender: TObject);
var
  Bitmap:TBitmap;
  nJuros,nDescontos:real;
  Linha,cNossoNum:Real;
  cCNPJ,cInsc,cLinhaDig:string;
  y:integer;
  cMoeda,cDv,cFator,cValTit,cCampoLivre:String;
begin
  with Sender as TBaseReport do
    begin
      DM.ATCadPd1.SetOrder(2);    // notafisc
      //DM.ATCadPd1.DisableControls;
      DM.ATCadPd1.GoTop;
      while not DM.ATCadPd1.Eof do
        begin
          cMoeda      := '9'; // Real
          cDv         := '';  // dígito verificador do código de barras
          cFator      := '';  // Fator de vencimento
          cValTit     := '';  // Valor do título
          cCampoLivre := '';  // Campo Livre de acordo com cada banco

          DM.ATCadCli.SetOrder(1);
          DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);

          if DM.ATCadPd1PRAZOLIM1.Value > 0 then
            begin
              nParcela := 1;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do  // dois boletos
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,13,26.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM1.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-1/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,  Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ1.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ1.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8     // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ1.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE1.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE1.AsFloat * (DM.ATCadPd1VALFATPZ1.AsFloat-DM.ATCadPd1VALICMRET.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT1.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          if DM.ATCadPd1PRAZOLIM2.Value > 0 then
            begin
              NewPage;
              nParcela := 2;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,11,26.5,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM2.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-2/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,  Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ2.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ2.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8   // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ2.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE2.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE2.AsFloat * (DM.ATCadPd1VALFATPZ2.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT2.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          if DM.ATCadPd1PRAZOLIM3.Value > 0 then
            begin
              NewPage;
              nParcela := 3;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,11,26.5,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM3.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-3/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,  Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ3.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ3.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8   // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ3.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE3.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE3.AsFloat * (DM.ATCadPd1VALFATPZ3.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT3.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          if DM.ATCadPd1PRAZOLIM4.Value > 0 then
            begin
              NewPage;
              nParcela := 4;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,11,26.5,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM4.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-4/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,  Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ4.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ4.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8   // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ4.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE4.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE4.AsFloat * (DM.ATCadPd1VALFATPZ4.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT4.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          if DM.ATCadPd1PRAZOLIM5.Value > 0 then
            begin
              NewPage;
              nParcela := 5;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,11,26.5,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM5.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-5/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ5.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ5.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8   // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ5.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE5.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE5.AsFloat * (DM.ATCadPd1VALFATPZ5.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT5.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          if DM.ATCadPd1PRAZOLIM6.Value > 0 then
            begin
              NewPage;
              nParcela := 6;
              Bitmap := TBitmap.Create;
              try
                Bitmap.LoadFromFile('C:\boleto 2v.bmp');
                PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
              finally
                FreeAndNil(Bitmap);
              end;

              cNossoNum :=     StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
              DM.ATCadEm2.Edit;
              DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
              DM.ATCadEm2.Post;
              for y := 1 to 2 do
                begin
                  SetFont('Times New Roman',8);
                  Bold := True;
                  Bold := False;
                  if y = 1 then
                    Linha := 4.9 // boleto do sacado
                  else
                    begin
                      Linha := 17;  // boleto do banco
                      cLinhaDig := GeraCodBarra2de5('001');  // passa o codigo do banco
                      PrintBitmapRect(2,25,11,26.5,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
                      SetFont('Times New Roman',10);
                      PrintXY(7.5,4.1 ,cLinhaDig);
                      SetFont('Times New Roman',12);
                      Bold := True;
                      PrintXY(8.4,16.3,cLinhaDig);
                      Bold := False;
                      SetFont('Times New Roman',8);

                      DM.ATCadPd1.Edit;
                      DM.ATCadPd1NOSSONUM6.AsString := '1703928'+DM.ATCadEm2NOSSONUM.AsString;
                      DM.ATCadPd1.Post;
                    end;

                  PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant));
                  PrintXY(1.7, Linha+1,'REMED RECIFE MEDICAMENTOS LTDA');
                  PrintXY(16.6,Linha+1,'3433-9/  25551-3');
                  PrintXY(1.9, Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(4.8, Linha+1.9,DM.ATCadPd1NOTAFISC.AsString+'-6/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(8.3, Linha+1.9,'DM');
                  PrintXY(11.4,Linha+1.9,'N');
                  PrintXY(13.6,Linha+1.9,DM.ATCadPd1DTEMIS.AsString);
                  PrintXY(16.1,Linha+1.9,'1703928'+DM.ATCadEm2nossonum.AsString);
                       //+'-'+
                       //DIGNOSSONUM(DM.ATCadEm2nossonum.AsString,'78923456789'));

                  PrintXY(5,   Linha+2.8,'17-019');
                  PrintXY(8.3, Linha+2.8,'R$');
                  PrintXY(17.3,  Linha+2.8,Format('%10.2m',[DM.ATCadPd1VALFATPZ6.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
                  nJuros :=  DM.ATCadPd1VALFATPZ6.AsFloat * ((DM.ATCadEmpTAXAJUROS.AsFloat/30)/100);

                  if y = 1 then
                    Linha := 8   // boleto do sacado
                  else
                    Linha := 20.2; // boleto do banco

                  if nJuros > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                                    Format('%7.2m',[nJuros])+' AO DIA.');
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
                    end;
                  if DM.ATCadEmpTAXADESC.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := DM.ATCadPd1VALFATPZ6.AsFloat * ((DM.ATCadEmpTAXADESC.AsFloat/30)/100);
                      PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                        Format('%7.2m',[nDescontos])+' AO DIA.');
                    end;
                  if DM.ATCadPd1DESCANTE6.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      nDescontos := (DM.ATCadPd1DESCANTE6.AsFloat * (DM.ATCadPd1VALFATPZ6.AsFloat))/100;
                      PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                        Format('%7.2m',[nDescontos])+
                                        ' PARA PAGAMENTO ATÉ: '+
                                        FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOANT6.AsVariant));
                    end;
                  if DM.ATCadCliVALTARBAN.AsFloat > 0 then
                    begin
                      Linha := Linha + 0.3;
                      PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                        Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
                    end;

                  PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
                  PrintXY(1.7,Linha+0.6,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
                  PrintXY(1.7,Linha+0.9,'NOTA FISCAL: '+DM.ATCadPd1NOTAFISC.AsString+'    SETOR/CLIENTE: '+
                                        DM.ATCadPd1CODSET.AsString+' / '+DM.ATCadPd1CODCLI.AsString);
                  // Sacado
                  if y = 1 then
                    Linha := 11.7  // boleto do sacado
                  else
                    Linha := 23.9; // boleto do banco

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

            end;

          DM.ATCadPd1.Edit;
          DM.ATCadPd1FLAGAPO.AsString := '*';
          DM.ATCadPd1.Post;

          DM.ATCadPd1.Skip(1);
          if not DM.ATCadPd1.Eof then
            NewPage;
        end;
    end;
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
  Result := Copy(insc,5,7)+'-'+Copy(insc,13,2)
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
  Col: integer;
  Lar: integer;
  ImgBarras: TImage;
  cCodigo,cMoeda,cFator,cValTit,cConvenio,cCampoLivre,cDv:string;
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
  cConvenio   := '01703928';
  if nParcela = 1 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ1.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 2 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ2.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 3 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ3.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 4 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ4.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 5 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ5.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;
  if nParcela = 6 then
    begin
      cFator      := FatorVencto(DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant);   // Fator de vencimento
      aux         := (DM.ATCadPd1VALFATPZ6.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;
      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;

  // obs. o campo nosso numero, nao contem o codigo do convenio(1703928), para facilitar...
  cDv         := CalcDigVerificador('001'+cMoeda+'0'+cFator+cValTit+'000000'+'1703928'+DM.ATCadEm2NOSSONUM.AsString+'17');   // dígito verificador do código de barras

  cCodigo := '001'+cMoeda+cDv+cFator+cValTit+'000000'+'1703928'+DM.ATCadEm2NOSSONUM.AsString+'17';
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

function TFormBoleto.FatorVencto(dDataVenc: TDate): string;
var
  FatVencto: LongInt;
begin
  if dDataVenc < EncodeDate(1997, 10, 7) then
    ShowMessage('O vencimento do boleto deve ser superior à 7-Outubro-1997');
  // Regra FEBRABAN vigente desde 22/02/2025: o fator de vencimento antigo
  // (dias corridos desde 07/10/1997) estourava 9999 nessa data; a partir
  // dai o fator reinicia em 1000 e conta os dias desde entao (mesmo fix
  // aplicado em UnitImBoletoMes.pas).
  if dDataVenc >= EncodeDate(2025, 2, 22) then
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

end.
