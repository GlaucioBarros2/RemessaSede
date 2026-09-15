unit UnitImBoletoMes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Mask, Buttons, RpRender, RpRenderPDF, RpDefine,
  RpBase, RpSystem, Grids, DBGrids, ExtCtrls, RpRave, ShellApi;

type
  TFormBoletoMes = class(TForm)
    ComboBox1: TComboBox;
    Label1: TLabel;
    MaskEdit1: TMaskEdit;
    BitBtn1: TBitBtn;
    Label4: TLabel;
    RvSystemBoletoMes: TRvSystem;
    RvRenderPDF1: TRvRenderPDF;
    DBGrid1: TDBGrid;
    Image1: TImage;
    Label5: TLabel;
    Label2: TLabel;
    CB_TipoDoc: TComboBox;
    procedure BitBtn1Click(Sender: TObject);
    procedure RvSystemBoletoMesPrint(Sender: TObject);
    procedure MaskEdit1Enter(Sender: TObject);
    procedure DBGrid1Exit(Sender: TObject);
    procedure MaskEdit1Exit(Sender: TObject);
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
  FormBoletoMes: TFormBoletoMes;

implementation

uses UnitDM, DB;

{$R *.dfm}

// ===========================================================================
// SUPORTE AO BANCO SAFRA (422) - adicionado sem alterar a logica existente
// de BB (001) / Itau (341). O layout do boleto (imagem, posicoes PrintXY,
// funcoes Modulo10/CalcDigVerificador/PadL) segue o MESMO padrao ja usado
// para o Itau; apenas a composicao do "campo livre" do codigo de barras usa
// os valores reais do manual "Cobranca Safra - Layout Padrao Safra CNAB 240"
// (Formatacao do Codigo de Barras, pag. 22), pois o Itau usa uma composicao
// (carteira+nosso numero+DAC1+agencia+conta+DAC2+"000") diferente da do
// Safra (F+agencia+conta+nosso numero+F) e as duas nao sao equivalentes.
//
// TODO SAFRA - pendente antes de usar em producao:
//   1) cAgSafra / cContaSafra abaixo sao PLACEHOLDERS - substituir pelos
//      dados reais da agencia/conta do convenio Safra.
//   2) Os digitos "de uso livre" nas posicoes 20 e 44 do codigo de barras
//      (cFLivreSafra1/cFLivreSafra2) nao sao documentados no manual -
//      usando "0" como valor neutro ate confirmar com a mesa de implantacao
//      do Safra.
//   3) O campo DM.ATCadEm2NOSSONUM3 (contador sequencial do nosso numero
//      Safra, mesmo papel de NOSSONUM/NOSSONUM2 para BB/Itau) precisa ser
//      criado em UnitDM/tabela SACADEM2 - esta unit nao cria/edita o data
//      module. Sem esse campo o projeto nao compila.
//   4) O nosso numero do Safra e' LIVRE e tem exatamente 9 digitos no
//      arquivo de remessa (prefixo "422" + 6 digitos sequenciais, mesma
//      convencao usada em REMESSA.PRG) - o boleto deve espelhar exatamente
//      o que vai na remessa, por isso a largura aqui e' 6 (e nao 8 como
//      no Itau).
//   5) A imagem 'boleto 2v SAFRA.bmp' (mesmo layout do 'boleto 2v ITAU.bmp',
//      com logo/nome/codigo 422-7 do Safra) precisa ser copiada para
//      C:\ na maquina onde este programa roda, igual ja e' feito hoje
//      com 'boleto 2v BB.bmp' e 'boleto 2v ITAU.bmp'.
const
  cAgSafra      = '0000';        // TODO SAFRA: agencia real (4 digitos)
  cContaSafra   = '0000000000';  // TODO SAFRA: conta corrente real (10 digitos)
  cFLivreSafra1 = '0';           // TODO SAFRA: digito de uso livre (posicao 20 do cod. barras)
  cFLivreSafra2 = '0';           // TODO SAFRA: digito de uso livre (posicao 44 do cod. barras)
  cPrefixoNNSafra = '422';       // prefixo do nosso numero livre do Safra
// ===========================================================================

procedure TFormBoletoMes.BitBtn1Click(Sender: TObject);
var cNumNot:string;
begin
  DM.ATCadTit.SetOrder(1); // NUMMOV + TIPODOC
  DM.ATCadTit.Seek(MaskEdit1.Text+dm.ATCadTitTIPODOC.AsString);

  if DM.ATCadTit.Eof Then
    ShowMessage('Boleto não encontrado!')
  else if DM.ATCadTitCODPOR.AsString = '999' Then
    begin
      ShowMessage('Boleto não é banco!')
    end
  else
    begin
      cNumNot := DM.ATCadTitNUMMOV.AsString;
      IF Fileexists('F:\DATANET\BOL\BOL'+cNumNot+'.PDF') then
         DeleteFile('F:\DATANET\BOL\BOL'+cNumNot+'.PDF');

      RvSystemBoletoMes.DoNativeOutput           := False;
      RvSystemBoletoMes.DefaultDest              := rdFile;
      RvSystemBoletoMes.SystemOptions            := RvSystemBoletoMes.SystemOptions - [soShowStatus];
      RvSystemBoletoMes.SystemFiler.StatusFormat := 'Gerando PDF pag. %p';
      RvSystemBoletoMes.RenderObject             := RvRenderPDF1;
      RvSystemBoletoMes.SystemSetups             := RvSystemBoletoMes.SystemSetups - [ssAllowSetup];
      RvSystemBoletoMes.OutputFileName           := 'F:\DATANET\BOL\BOL'+cNumNot+'.PDF';
      RvSystemBoletoMes.Execute;

      // imprime o pdf direto para impressora
      //ShellExecute(Application.handle, 'print',PChar('F:\DATANET\BOL\BOL'+cNumNot+'.PDF'), nil,nil,SW_HIDE);
      ShellExecute(Application.handle, 'open',PChar('F:\DATANET\BOL\BOL'+cNumNot+'.PDF'), nil,nil,SW_SHOWMAXIMIZED);

     close;
    end
end;

procedure TFormBoletoMes.RvSystemBoletoMesPrint(Sender: TObject);
var
  Bitmap:TBitmap;
  nJuros,nDescontos:real;
  Linha,cNossoNum:Real;
  cCNPJ,cInsc,cLinhaDig:string;
  y:integer;
  cMoeda,cDv,cFator,cValTit,cCampoLivre,cNossoNumAux:String;
begin
  with Sender as TBaseReport do
    begin
      if DM.ATCadTitNOSSONUM.AsString <> '' then
        begin
          if (DM.ATCadTitCODPOR.AsString = '001') and (Copy(DM.ATCadTitNOSSONUM.AsString,1,3) <> '140')  then
            begin
              ShowMessage('Boleto com nosso número inválido');
              Exit;
            end;

          if (DM.ATCadTitCODPOR.AsString = '341') and (Copy(DM.ATCadTitNOSSONUM.AsString,1,3) <> '109')  then
            begin
              ShowMessage('Boleto com nosso número inválido');
              Exit;
            end;

          if (DM.ATCadTitCODPOR.AsString = '422') and (Copy(DM.ATCadTitNOSSONUM.AsString,1,3) <> cPrefixoNNSafra)  then
            begin
              ShowMessage('Boleto com nosso número inválido');
              Exit;
            end;
        end;


      cMoeda      := '9'; // Real
      cDv         := '';  // dígito verificador do código de barras
      cFator      := '';  // Fator de vencimento
      cValTit     := '';  // Valor do título
      cCampoLivre := '';  // Campo Livre de acordo com cada banco

      DM.ATCadSet.SetOrder(1);
      DM.ATCadSet.Seek(DM.ATCadTitCODSET.AsString);

      DM.ATCadCli.SetOrder(1);
      DM.ATCadCli.Seek(DM.ATCadTitCODCLI.AsString);

      nParcela := 1;
      Bitmap := TBitmap.Create;
      try
        if DM.ATCadTitCODPOR.AsString = '001' then
          Bitmap.LoadFromFile('C:\boleto 2v BB.bmp')
        else if DM.ATCadTitCODPOR.AsString = '422' then
          Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')
        else
          Bitmap.LoadFromFile('C:\boleto 2v ITAU.bmp');

        PrintBitmapRect(1,3,20,28.7,Bitmap);     // imprime imagem bmp do boleto bb
      finally
        FreeAndNil(Bitmap);
      end;

//////////////////////////////////////////////////////////////////

      SetFont('Times New Roman',8);
      Bold := True;
      Bold := False;
      Linha := 4.3; // boleto do sacado
      if DM.ATCadTitDTPRORROG.AsString <> '' then
        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadTitDTPRORROG.AsVariant))
      else
        PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadTitDTVENCLIM.AsVariant));
      PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA');

      if DM.ATCadTitCODPOR.AsString = '001' then
        PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
      else if DM.ATCadTitCODPOR.AsString = '422' then
        PrintXY(16.6,Linha+0.75,cAgSafra+'/'+cContaSafra+'-0')  // TODO SAFRA: ajustar formatacao/DV se necessario
      else
        PrintXY(16.6,Linha+0.75,'8322/11901-0');

      PrintXY(1.9, Linha+1.4,DM.ATCadTitDTEMISS.AsString);
      PrintXY(4.8, Linha+1.4,copy(DM.ATCadTitNUMMOV.AsString,1,6)+'-'+copy(DM.ATCadTitNUMMOV.AsString,7,1)+'/'+copy(DM.ATCadTitNUMMOV.AsString,8,1));
      PrintXY(8.3, Linha+1.4,'DM');
      PrintXY(11.4,Linha+1.4,'N');
      PrintXY(13.6,Linha+1.4,DM.ATCadTitDTEMISS.AsString);
      
      if DM.ATCadTitNOSSONUM.AsString <> '' then
        if DM.ATCadTitCODPOR.AsString = '001' then
          PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString)
        else if DM.ATCadTitCODPOR.AsString = '422' then
          PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10(cAgSafra+cContaSafra+DM.ATCadTitNOSSONUM.AsString))
        else
          PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10('832211901'+DM.ATCadTitNOSSONUM.AsString))
      else
        begin
          // pega um novo nosso numero que ainda nao exista
          while True do
            if DM.ATCadTitCODPOR.AsString = '001' then
              begin
                cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                DM.ATCadTit.SetOrder(13);    // nossonum
                if not DM.ATCadTit.seek(cNossoNumAux) then
                  Break      // sai do loop
                else
                  begin
                    //
                    DM.ATCadEm2.Edit;
                    DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
                    DM.ATCadEm2.Post;
                  end;
              end
            else if DM.ATCadTitCODPOR.AsString = '422' then
              begin
                // TODO SAFRA: requer o campo DM.ATCadEm2NOSSONUM3 (ver comentario
                // no topo desta unit) - contador sequencial exclusivo do Safra.
                cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos (limite do manual Safra)

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
            ELSE
              begin
                cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
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

          DM.ATCadTit.SetOrder(1);
          DM.ATCadTit.Seek(MaskEdit1.Text);

          DM.ATCadEm2.Edit;
          if DM.ATCadTitCODPOR.AsString = '001' then
            DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')
          else if DM.ATCadTitCODPOR.AsString = '422' then
            DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')
          else
            DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');
          DM.ATCadEm2.Post;

          DM.ATCadTit.Edit;

          if DM.ATCadTitCODPOR.AsString = '001' then
            DM.ATCadTitNOSSONUM.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString
          else if DM.ATCadTitCODPOR.AsString = '422' then
            DM.ATCadTitNOSSONUM.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString
          else
            DM.ATCadTitNOSSONUM.AsString := '109'+DM.ATCadEm2NOSSONUM2.AsString;

          DM.ATCadTit.Post;
          if DM.ATCadTitCODPOR.AsString = '001' then
            PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString)
          else if DM.ATCadTitCODPOR.AsString = '422' then
            PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10(cAgSafra+cContaSafra+DM.ATCadTitNOSSONUM.AsString))
          else
            PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10('832211901'+DM.ATCadTitNOSSONUM.AsString));
        end;

      if DM.ATCadTitCODPOR.AsString = '001' then
        PrintXY(5.5,  Linha+2,'17-027')
      else if DM.ATCadTitCODPOR.AsString = '422' then
        PrintXY(5.5,  Linha+2,cPrefixoNNSafra)
      else
        PrintXY(5.5,  Linha+2,'109');

      PrintXY(8.3,  Linha+2,'R$');
      if DM.ATCadTitVALPRORRO.AsFloat > 0 then
        PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadTitVALPRORRO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]))
      else
        PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadTitVALBRUTO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));

      PrintXY(1.7,Linha+2.6,DM.ATCadCliRAZSOCCLI.AsString);
      PrintXY(1.7,Linha+3.2,'SETOR: '+DM.ATCadTitCODSET.AsString+' - '+DM.ATCadSetNOMSET.AsString+'       CLIENTE: '+DM.ATCadTitCODCLI.AsString);
      PrintXY(1.7,Linha+3.8,'Não receber após 60 dias do vencimento');

      Linha := 15;
{
      if DM.ATCadTitCODPOR.AsString = '001' then
       begin
          PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos');
          PrintXY(6.5,Linha+0.3,'/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
       end
      else
       begin
         PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: https://www.itau.com.br/servicos/boletos/atualizar/');
       end;
}

//////////////////////////////////////////////////////////////////////////////////////

      for y := 1 to 2 do  // dois boletos
        begin
          SetFont('Times New Roman',8);
          Bold := True;
          Bold := False;
          if y = 1 then
            Linha := 10.4 // boleto do sacado
          else
            begin
              Linha := 20.2;  // boleto do banco
              if DM.ATCadTitCODPOR.Text = '001' then
                cLinhaDig := GeraCodBarra2de5('001')  // passa o codigo do banco
              else if DM.ATCadTitCODPOR.Text = '422' then
                cLinhaDig := GeraCodBarra2de5('422')  // passa o codigo do banco
              else
                cLinhaDig := GeraCodBarra2de5('341');  // passa o codigo do banco

              PrintBitmapRect(2,27,13,28.4,Image1.Picture.Bitmap);     // imprime imagem bmp do código de barras
              SetFont('Times New Roman',10);
              PrintXY(7.5,3.5,cLinhaDig);
              PrintXY(7.5,9.6,cLinhaDig);
              SetFont('Times New Roman',12);
              Bold := True;
              PrintXY(8.4,19.5,cLinhaDig);
              Bold := False;
              SetFont('Times New Roman',8);
            end;

          if DM.ATCadTitDTPRORROG.AsString <> '' then
            PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadTitDTPRORROG.AsVariant))
          else
            PrintXY(16.6,Linha+0.1,FormatDateTime('dd/mm/yyyy',DM.ATCadTitDTVENCLIM.AsVariant));
          PrintXY(2.6, Linha+0.7,'SEDE DAS MIUDEZAS ATACADO LTDA');

          if DM.ATCadTitCODPOR.AsString = '001' then
            PrintXY(16.6,Linha+0.75,'2811-8/ 114546-0')
          else if DM.ATCadTitCODPOR.AsString = '422' then
            PrintXY(16.6,Linha+0.75,cAgSafra+'/'+cContaSafra+'-0')  // TODO SAFRA: ajustar formatacao/DV se necessario
          else
            PrintXY(16.6,Linha+0.75,'8322/11901-0');

          PrintXY(1.9, Linha+1.4,DM.ATCadTitDTEMISS.AsString);
          PrintXY(4.8, Linha+1.4,DM.ATCadTitNUMMOV.AsString);
          PrintXY(8.3, Linha+1.4,'DM');
          PrintXY(11.4,Linha+1.4,'N');
          PrintXY(13.6,Linha+1.4,DM.ATCadTitDTEMISS.AsString);

          if DM.ATCadTitNOSSONUM.AsString <> '' then
            if DM.ATCadTitCODPOR.AsString = '001' then
              PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString)
            else if DM.ATCadTitCODPOR.AsString = '422' then
              PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10(cAgSafra+cContaSafra+DM.ATCadTitNOSSONUM.AsString))
            else
              PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10('832211901'+DM.ATCadTitNOSSONUM.AsString))
          else
            begin
              // pega um novo nosso numero que ainda nao exista
              while True do
                if DM.ATCadTitCODPOR.AsString = '001' then
                  begin
                    cNossoNum := StrToFloat(DM.ATCadEm2NOSSONUM.AsString) + 1;
                    cNossoNumAux := '1406478'+Padl(IntToStr(Trunc(cNossoNum)), 10, '0');

                    DM.ATCadTit.SetOrder(13);    // nossonum
                    if not DM.ATCadTit.seek(cNossoNumAux) then
                      Break      // sai do loop
                    else
                      begin
                        //
                        DM.ATCadEm2.Edit;
                        DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0');
                        DM.ATCadEm2.Post;
                      end;
                  end
                else if DM.ATCadTitCODPOR.AsString = '422' then
                  begin
                    // TODO SAFRA: requer o campo DM.ATCadEm2NOSSONUM3 (ver comentario
                    // no topo desta unit) - contador sequencial exclusivo do Safra.
                    cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM3.AsString) + 1;
                    cNossoNumAux := cPrefixoNNSafra+Padl(IntToStr(Trunc(cNossoNum)), 6, '0');  // 3+6 = 9 digitos (limite do manual Safra)

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
                ELSE
                  begin
                    cNossoNum    := StrToFloat(DM.ATCadEm2NOSSONUM2.AsString) + 1;
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

              DM.ATCadTit.SetOrder(1);
              DM.ATCadTit.Seek(MaskEdit1.Text);

              DM.ATCadEm2.Edit;
              if DM.ATCadTitCODPOR.AsString = '001' then
                DM.ATCadEm2nossonum.AsString := Padl(IntToStr(Trunc(cNossoNum)), 10, '0')
              else if DM.ATCadTitCODPOR.AsString = '422' then
                DM.ATCadEm2nossonum3.AsString := Padl(IntToStr(Trunc(cNossoNum)), 6, '0')
              else
                DM.ATCadEm2nossonum2.AsString := Padl(IntToStr(Trunc(cNossoNum)), 8, '0');
              DM.ATCadEm2.Post;

              DM.ATCadTit.Edit;

              if DM.ATCadTitCODPOR.AsString = '001' then
                DM.ATCadTitNOSSONUM.AsString := '1406478'+DM.ATCadEm2NOSSONUM.AsString
              else if DM.ATCadTitCODPOR.AsString = '422' then
                DM.ATCadTitNOSSONUM.AsString := cPrefixoNNSafra+DM.ATCadEm2NOSSONUM3.AsString
              else
                DM.ATCadTitNOSSONUM.AsString := '109'+DM.ATCadEm2NOSSONUM2.AsString;

              DM.ATCadTit.Post;

              if DM.ATCadTitCODPOR.AsString = '001' then
                PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString)
              else if DM.ATCadTitCODPOR.AsString = '422' then
                PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10(cAgSafra+cContaSafra+DM.ATCadTitNOSSONUM.AsString))
              else
                PrintXY(16.1,Linha+1.4,DM.ATCadTitNOSSONUM.AsString+'-'+Modulo10('832211901'+DM.ATCadTitNOSSONUM.AsString))
            end;


          if DM.ATCadTitCODPOR.AsString = '001' then
            PrintXY(5.5,  Linha+2,'17-027')
          else if DM.ATCadTitCODPOR.AsString = '422' then
            PrintXY(5.5,  Linha+2,cPrefixoNNSafra)
          else
            PrintXY(5.5,  Linha+2,'109');

          PrintXY(8.3, Linha+2,'R$');
          if DM.ATCadTitVALPRORRO.AsFloat > 0 then
            begin
              PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadTitVALPRORRO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
              nJuros :=  DM.ATCadTitVALPRORRO.AsFloat * ((DM.ATCadTitTAXAJUROS.AsFloat/30)/100);
            end
          else
            begin
              PrintXY(17.38,Linha+2.03,Format('%10.2m',[DM.ATCadTitVALBRUTO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat]));
              nJuros :=  DM.ATCadTitVALBRUTO.AsFloat * ((DM.ATCadTitTAXAJUROS.AsFloat/30)/100);
            end;

          if y = 1 then
            Linha := 13     // boleto do sacado
          else
            Linha := 22.8; // boleto do banco

          if nJuros > 0 then
            begin
              Linha := Linha + 0.3;
              PrintXY(1.7,Linha,'APÓS VENCIMENTO COBRAR R$ '+
                            Format('%7.2m',[nJuros])+' AO DIA.');
              Linha := Linha + 0.3;
              PrintXY(1.7,Linha,'APÓS O VENCIMENTO SÓ RECEBER COM JUROS')
            end;

          Linha := Linha + 0.3;
          PrintXY(1.7,Linha,'CHAVE PARA PAGAMENTO POR PIX: 40868234000170');

          if DM.ATCadTitTAXADESC.AsFloat > 0 then
            begin
              Linha := Linha + 0.3;
              nDescontos := DM.ATCadTitVALBRUTO.AsFloat * ((DM.ATCadTitTAXADESC.AsFloat/30)/100);
              PrintXY(1.7,Linha,'DESCONTO POR ANTECIPAÇÃO DE R$ '+
                                Format('%7.2m',[nDescontos])+' AO DIA.');
            end;
          if DM.ATCadTitDESCANTEC.AsFloat > 0 then
            begin
              Linha := Linha + 0.3;
              if dm.ATCadCliTODALINHA.AsString = 'S' then
                nDescontos := (DM.ATCadTitDESCANTEC.AsFloat * (DM.ATCadTitVALBRUTO.AsFloat))/100
              else
                nDescontos := (DM.ATCadTitDESCANTEC.AsFloat * (DM.ATCadTitVALBRUTO.AsFloat-DM.ATCadTitVALICMRET.AsFloat))/100;
                
              PrintXY(1.7,Linha,'DESCONTO FINANCEIRO DE R$ '+
                                Format('%7.2m',[nDescontos])+
                                ' PARA PAGAMENTO ATÉ: '+
                                FormatDateTime('dd/mm/yyyy',DM.ATCadTitDTVENCANT.AsVariant));
            end;
          if DM.ATCadCliVALTARBAN.AsFloat > 0 then
            begin
              Linha := Linha + 0.3;
              PrintXY(1.7,Linha,'TARIFA BANCÁRIA R$ '+
                                Format('%7.2m',[DM.ATCadCliVALTARBAN.AsFloat]));
            end;

          //PrintXY(1.7,Linha+0.3,'PROIBIDO PAGAMENTO A VENDEDOR');
          PrintXY(1.7,Linha+0.3,'TÍTULO SUJEITO A PROTESTO APÓS O VENCIMENTO');
          PrintXY(1.7,Linha+0.6,'SETOR: '+DM.ATCadTitCODSET.AsString+'   CLIENTE: '+DM.ATCadTitCODCLI.AsString);
          PrintXY(1.7,Linha+0.9,'Não receber após 60 dias do vencimento');

          if y = 1 then
            Linha := 15
          else
            Linha := 24.8;
{
          if DM.ATCadTitCODPOR.AsString = '001' then
           begin
              PrintXY(1.7,Linha,'ATUALIZAR TÍTULOS VENCIDOS: http://www.bb.com.br/pbb/pagina-inicial/voce/produtos-e-servicos');
              PrintXY(6.5,Linha+0.3,'/contas/todos-os-servicos/2a-via-de-boleto-de-cobranca#/');
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
          DM.ATCadCli.Seek(DM.ATCadTitCODCLI.AsString);

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
end;

procedure TFormBoletoMes.MaskEdit1Enter(Sender: TObject);
begin
  MaskEdit1.Text := DM.ATCadTitNUMMOV.AsString;
end;

function TFormBoletoMes.formatacnpj(Cnpj: String): string;
begin
  Result := Copy(Cnpj,1,2)+'.'+Copy(Cnpj,3,3)+'.'+Copy(Cnpj,6,3)+'/'+
            Copy(Cnpj,9,4)+'-'+Copy(Cnpj,13,2);
end;

function TFormBoletoMes.formatainsc(insc, uf: String): string;
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

function TFormBoletoMes.GeraCodBarra2de5(cCodBanco: String): String;
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
  cCarteira,cNossoNumAux,DAC1,DAC2:string;

  X: integer;
  Col: integer;
  Lar: integer;
  ImgBarras: TImage;
  cCodigo,cMoeda,cFator,cValTit,cCampoLivre,cDv:string;
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
      if DM.ATCadTitDTPRORROG.AsString <> '' then
        cFator := FatorVencto(DM.ATCadTitDTPRORROG.AsVariant)
      else
        cFator := FatorVencto(DM.ATCadTitDTVENCLIM.AsVariant);

      if DM.ATCadTitVALPRORRO.AsFloat > 0 then
        aux := (DM.ATCadTitVALPRORRO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100
      else
        aux := (DM.ATCadTitVALBRUTO.AsFloat+DM.ATCadCliVALTARBAN.AsFloat)*100;

      cValTit     := Padl(floatToStr(aux), 10, '0');  // Valor do titulo (10 posicoes)
    end;

  if cCodBanco = '001' then
    begin
      cCarteira    := '17';
      cNossoNumAux := DM.ATCadTitNOSSONUM.AsString;
      cDv          := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+'000000'+cNossoNumAux+cCarteira);   // dígito verificador do código de barras
      cCodigo      := cCodBanco+cMoeda+cDv+cFator+cValTit+'000000'+cNossoNumAux+cCarteira;
    end
  else if cCodBanco = '422' then
    begin
      // SAFRA: layout do campo livre (posições 20-44 do código de barras)
      // conforme o manual "Cobrança Safra - Layout Padrão Safra CNAB 240"
      // (Formatação do Código de Barras, pág. 22): F(1) + Agência(4) +
      // Conta(10) + Nosso Número(9) + F(1) = 25 dígitos. Diferente da
      // composição usada pelo Itaú (carteira+nosso número+DAC1+agência+
      // conta+DAC2+"000"), por isso não reaproveita cCarteira/DAC1/DAC2.
      cNossoNumAux := DM.ATCadTitNOSSONUM.AsString;     // 9 dígitos livres (prefixo 422 + 6 sequenciais)
      cDv     := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+cFLivreSafra1+cAgSafra+cContaSafra+cNossoNumAux+cFLivreSafra2);
      cCodigo := cCodBanco+cMoeda+cDv+cFator+cValTit+cFLivreSafra1+cAgSafra+cContaSafra+cNossoNumAux+cFLivreSafra2;
    end
  else
    begin
      cCarteira    := '109';
      cNossoNumAux := DM.ATCadTitNOSSONUM.AsString;     // 8 DIGITOS LIVRES

      // DAC1 [Agência /Conta/Carteira/Nosso Número] (Anexo 4)
      DAC1 := Modulo10('832211901'+cNossoNumAux);

      // DAC2 [Agência/Conta Corrente] (Anexo 3)
      DAC2 := Modulo10('8322'+'11901');

      cDv     := CalcDigVerificador(cCodBanco+cMoeda+'0'+cFator+cValTit+cNossoNumAux+DAC1+'8322'+'11901'+DAC2+'000');
      cCodigo := cCodBanco+cMoeda+cDv+cFator+cValTit+cNossoNumAux+DAC1+'8322'+'11901'+DAC2+'000';
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

function TFormBoletoMes.DIGNOSSONUM(cNossoNum:String;cPeso:string): String;
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

function TFormBoletoMes.CalcDigVerificador(CodigoBarras: string): char;
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

function TFormBoletoMes.FatorVencto(dDataVenc: TDate): string;
var
  FatVencto: LongInt;
begin
  if dDataVenc < EncodeDate(1997, 10, 7) then
    ShowMessage('O vencimento do boleto deve ser superior à 7-Outubro-1997');
  FatVencto := Abs(Trunc(dDataVenc) - Trunc(EncodeDate(1997, 10, 7)));
  Result := PadL(IntToStr(FatVencto), 4, '0');
end;

function TFormBoletoMes.PadL(Oque: string; Tamanho: integer;
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


function TFormBoletoMes.LinhaDigitavel(cCodigoBarras: string): string;
var
  c1, c2, c3, c4, c5: string;
begin
  if DM.ATCadTitCODPOR.Text = '001' then
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

  if DM.ATCadTitCODPOR.Text = '341' then
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

  if DM.ATCadTitCODPOR.Text = '422' then
    begin
      // codigo de barras do safra - a formula de fatiamento da linha
      // digitavel e' puramente posicional (mesmas posicoes 1-44 usadas
      // pelo Itau acima), pois so depende do tamanho fixo do codigo de
      // barras (44 digitos) e nao do significado de cada sub-campo do
      // "campo livre" (posicoes 20-44) - por isso reaproveita exatamente
      // o mesmo calculo do bloco do Itau (mesmo layout).
      //
      // 01 - cCodBanco    = 422
      // 04 - cMoeda       = 9
      // 05 - cDV          = '?'
      // 06 - cFator       = 1234
      // 10 - cValTit      = 0123456789
      // 20 - F (uso livre)
      // 21 - Agencia (4)
      // 25 - Conta (10)
      // 35 - Nosso Numero (9)
      // 44 - F (uso livre)

      c1 := Copy(cCodigoBarras,1,4) + Copy(cCodigoBarras, 20, 5);
      c1 := c1 + Modulo10(c1);
      Insert('.', c1, 6);

      c2 := Copy(cCodigoBarras, 25, 10);
      c2 := c2 + Modulo10(c2);
      Insert('.', c2, 6);

      c3 := Copy(cCodigoBarras, 35, 10);
      c3 := c3 + Modulo10(c3);
      Insert('.', c3, 6);

      c4 := Copy(cCodigoBarras, 5, 1);                              // Dígito verificador do código de barras
      c5 := Copy(cCodigoBarras, 6, 14);                             // cFator + cValTit
    end;

  result := c1 + ' ' + c2 + ' ' + c3 + ' ' + c4 + ' ' + c5;
end;

function TFormBoletoMes.Modulo10(Valor: string): string;
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

procedure TFormBoletoMes.DBGrid1Exit(Sender: TObject);
begin
  MaskEdit1.Text := DM.ATCadTitNUMMOV.AsString;

end;

procedure TFormBoletoMes.MaskEdit1Exit(Sender: TObject);
begin
  dm.ATCadTit.Filtered := False;
  dm.ATCadTit.Filter   := 'tipodoc = '+QuotedStr(CB_TipoDoc.Text)+' and '+
                          'CODPOR <> "999"';
  dm.ATCadTit.Filtered := True;

  DM.ATCadTit.SetOrder(1); // NUMMOV + TIPODOC
  DM.ATCadTit.Seek(MaskEdit1.Text+CB_TipoDoc.Text);

  if (DM.ATCadTitNUMMOV.AsString <> MaskEdit1.Text) or (DM.ATCadTitTIPODOC.AsString <> CB_TipoDoc.Text) then
    begin
      ShowMessage('Não encontrado !');
    end
  else
    begin
      if (DM.ATCadTitSITTIT.AsString <> 'AB') and (DM.ATCadTitSITTIT.AsString <> 'PB') and (DM.ATCadTitSITTIT.AsString <> 'PC') then
         begin
           ShowMessage('Títutlo baixado.');
         end;
    end;
end;

end.
