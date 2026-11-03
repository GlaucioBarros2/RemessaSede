unit UnitEnviaImprime;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, DBGrids, ExtCtrls, StdCtrls, Buttons, NFe_Util_2G_TLB,
  ComCtrls, RpRender, RpRenderPDF, RpDefine, RpBase, RpSystem, rpbars,
  RpCon, RpConDS, RpRave,
  shellapi, RPDevice, Mask, DBCtrls, Menus;

type
  TFormEnviaImprime = class(TForm)
    DBGrid1: TDBGrid;
    ckbEnviar: TCheckBox;
    ckbEmProc: TCheckBox;
    ckbRejeitados: TCheckBox;
    ckbAutorizados: TCheckBox;
    btCertificado: TBitBtn;
    EdNome: TEdit;
    Label2: TLabel;
    Timer1: TTimer;
    ckbImprimindo: TCheckBox;
    ckbImpresso: TCheckBox;
    ckbNFECanceladas: TCheckBox;
    Label1: TLabel;
    Label3: TLabel;
    ckbProcessamento: TCheckBox;
    BitBtn1: TBitBtn;
    DBEdit1: TDBEdit;
    RvRenderPDF1: TRvRenderPDF;
    PopupMenu1: TPopupMenu;
    ReemiteNFe1: TMenuItem;
    Label4: TLabel;
    RvSystemDANFE: TRvSystem;
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure btCertificadoClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure ckbEnviarClick(Sender: TObject);
    procedure ckbEmProcClick(Sender: TObject);
    procedure ckbRejeitadosClick(Sender: TObject);
    procedure ckbAutorizadosClick(Sender: TObject);
    procedure ckbImprimindoClick(Sender: TObject);
    procedure ckbImpressoClick(Sender: TObject);
    procedure edLicencaExit(Sender: TObject);
    procedure DBGrid1Enter(Sender: TObject);
    procedure DBGrid1ColExit(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
    procedure RvSystemDanfeBeforePrint(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure ckbProcessamentoClick(Sender: TObject);
    procedure RvSystemDANFEPrint(Sender: TObject);
    procedure ReemiteNFe1Click(Sender: TObject);
  private
    { Private declarations }
    function natureza(nNatope:Real):string;
    procedure PrintBarcode128(RVSystem:TRVSystem; Row, Column:Double; Value:String);
    function somaitens():integer;
    function formatacnpj(Cnpj:String):string;
    function formatainsc(insc,uf:String):string;
    function recebetotaisnota(mens:string):string;
    function recebemenspro(mens:string):string;

  public
    { Public declarations }
    matriz:array[1..10] of string;
    lSegundaVez:Boolean;
  end;

var
  FormEnviaImprime: TFormEnviaImprime;
  siglaWS, NFe, nomeCertificado,Versao, msgDados, msgRetWS,msgResultado,nroRecibo,dhRecbto,tMed, proxy, usuario, senha, licenca: Widestring;
  retWS,cabMsg,NFeAssinada,ProcNfe,nroProtocolo,dhProtocolo,cMsg,xMsg,siglaUF:Widestring;
  tipoAmbiente,cStat:integer;
  resultado:integer;
  cFiltro:String;
  lProcessando:Boolean;
  micmretido,moperfisc:string;
implementation

Uses UnitDM, DB;

{$R *.dfm}

procedure TFormEnviaImprime.DBGrid1DrawColumnCell(Sender: TObject;
  const Rect: TRect; DataCol: Integer; Column: TColumn;
  State: TGridDrawState);
begin
  if not ckbProcessamento.Checked then Exit;
  // alternating color

  if (ckbEnviar.Checked) and ( ((DM.ATCadPd1numrecibo.AsString = '')or(DM.ATCadPd1NUMPROTOC.AsString = '') ) and
      (DM.ATCadPd1flagnfe.AsString <> '') and
      ((DM.ATCadPd1contingenc.AsString = '1') or (DM.ATCadPd1contingenc.AsString = '7'))) then
    begin
      // Enviando
      DBGrid1.canvas.Brush.Color := clLime;   // verde
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if ( (ckbEmProc.Checked) and (Pos('103 ',DM.ATCadPd1RTSEFAZ.AsString)>0) or
       (Pos('104 ',DM.ATCadPd1RTSEFAZ.AsString)>0) or
       (Pos('105 ',DM.ATCadPd1RTSEFAZ.AsString)>0)) then
    begin
      // Em Processamento
      DBGrid1.canvas.Brush.Color := clYellow;   // amarelo
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if ((ckbImprimindo.Checked) and (DM.ATCadPd1NUMPROTOC.AsString <> '') and
      (DM.ATCadPd1IMPDANFE.AsString  = '') and
      (Pos('101 ',DM.ATCadPd1RTSEFAZ.AsString)=0) )  then
    begin
      // Imprimindo
      DBGrid1.canvas.Brush.Color := $000080FF;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if ((ckbImpresso.Checked) and (DM.ATCadPd1NUMPROTOC.AsString <> '') and
      (DM.ATCadPd1IMPDANFE.AsString  = 'S')) then
    begin
      // Impresso
      DBGrid1.canvas.Brush.Color := $00DFDF9F;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if ((ckbAutorizados.Checked) and (DM.ATCadPd1NUMPROTOC.AsString <> '') and
      (Pos('100 ',DM.ATCadPd1RTSEFAZ.AsString)>0) )  then
    begin
      // autorizado uso
      DBGrid1.canvas.Brush.Color := clSilver;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if (ckbRejeitados.Checked) and (Pos('Rejeição',DM.ATCadPd1RTSEFAZ.AsString)>0)  then
    begin
      // Rejeitados
      DBGrid1.canvas.Brush.Color := clRed;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if (ckbRejeitados.Checked) and (Pos('Erro',DM.ATCadPd1RTSEFAZ.AsString)>0)  then
    begin
      // Rejeitados
      DBGrid1.canvas.Brush.Color := clRed;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

  if (ckbNFECanceladas.Checked) and (Pos('101 ',DM.ATCadPd1RTSEFAZ.AsString)>0) then
    begin
      // Canceladas
      DBGrid1.canvas.Brush.Color := clWhite;
      DBGrid1.Canvas.FillRect(Rect);
      DBGrid1.DefaultDrawDataCell(rect,Column.Field,State);
    end;

end;

procedure TFormEnviaImprime.btCertificadoClick(Sender: TObject);
var

    ///  2. PegaNomeCertificado: Seleciona ou confirma a exitência de um certificado para o nome informado.
    ///
    ///     Entrada: Nome do titular
    ///                se não informado busca certificado do repositório;
    ///                se informado confirma a existência.
    ///
    ///    Retornos:
    ///
    ///        PegaNomeCertificado: código do resultado
    ///
    ///                             0-Selecinado um Certificado
    ///                             1-Existe um Certificado com o nome informado
    ///                             2-Nenhum Certificado Selecionado
    ///                             3-Nenhum certificado válido foi encontrado com o nome informado
    ///                             4-Erro Inesperado: "+ex.Message
    ///
    ///        Nome               : Nome do titular do Certificado
    ///
    ///        msgResultado       : Literal da mensagem do resultado
    ///

Util:NFe_Util_2g_Interface;
i:integer;

begin
  Timer1.Enabled     := False;

  Util := CoUtil.Create;
  nomeCertificado := edNome.Text;

  i:= Util.PegaNomeCertificado(nomeCertificado, msgResultado);
  if i > 5402 then
      MessageDlg( 'Ocorreu uma falha no acesso ao repositório de certificados digitais...'+#13+#13+msgResultado, mtInformation, [mbOk], 0)
  else
    begin
      edNome.Text := nomeCertificado;
      Timer1.Enabled := True;
      DBGrid1.SetFocus;
    end;

  Util:= nil;

  Timer1.Enabled     := True;
end;

procedure TFormEnviaImprime.Timer1Timer(Sender: TObject);
var
  Util:NFe_Util_2G_Interface;
  Fentrada:File;
  NumRead,i,ii,nposi,TPAMB:integer;
  buf: char;
  S,cChave,cTpAmb,cArquivo,cProtoc: string;

  xmldoc, ref, nome, xmlassinado, mensagem: Widestring;

  Status,Motivo,NomeArq:string;
  texto1,texto2,xverAplic,xchNFe,xdhRecbto,xnProt,xdigVal,xcStat,xxMotivo,ProtAutorizacao:string;
  PosInic,PosFin,Aux,Aux2,Aux3:integer;
  Fsaida: TextFile;
  cStatEnv: integer;
  msgOrig: string;
begin
  if not ckbProcessamento.Checked then exit;

  Timer1.Enabled := False;
  
  if (DM.ATCadPd1.Eof) then
    begin
      DM.ATCadPd1.GoTop;
      DBGrid1.Refresh;

      Timer1.Enabled := True;
      exit;
    end;

  if (Pos('Rejeição'      ,DM.ATCadPd1RTSEFAZ.AsString)>0)or
     (Pos('Erro'          ,DM.ATCadPd1RTSEFAZ.AsString)>0)or
     (Pos('denegada'      ,DM.ATCadPd1RTSEFAZ.AsString)>0)or
     (Pos('S'             ,DM.ATCadPd1IMPDANFE.AsString)>0)or
     (Pos('Não Habilitado',DM.ATCadPd1RTSEFAZ.AsString)>0) then
    begin
      DM.ATCadPd1.Next;
      if DM.ATCadPd1.Eof then
        begin
          DM.ATCadPd1.GoTop;
          DBGrid1.Refresh;
        end;

      Timer1.Enabled := True;
      exit;
    end;

  cArquivo := '';
  if DirectoryExists('c:\NFCe em Dephi xe5\') then
    cArquivo := 'c:\DATANET\NF'+Copy(DM.ATCadPd1NOTAFISC.AsString,4,6)+'.xml';
    //cArquivo := 'c:\DATANET\fontes\NF'+Copy(DM.ATCadPd1NOTAFISC.AsString,4,6)+'.xml';

  if DirectoryExists('f:\datanet') then
    cArquivo := 'f:\DATANET\NF'+Copy(DM.ATCadPd1NOTAFISC.AsString,4,6)+'.xml';

  if DirectoryExists('g:\datanet') then
    cArquivo := 'g:\DATANET\NF'+Copy(DM.ATCadPd1NOTAFISC.AsString,4,6)+'.xml';

  Timer1.Enabled := False;

    Versao  := '4.00';
    licenca := '';

    Ctpamb  := DM.ATCadPd1TIPOAMBXML.AsString;
    if (cTpAmb = '1') then    // producao
      begin
        if Pos('CM COMERCIO',DM.ATCadEmpNOMEMP.AsString) <> 0 then
          licenca :='c897eb4c554d7a27517256e8a910aac1c4181f5d2e565d0cc697b76226288c0271b8e27d1ad8716e1e35346dff88e8bdab5ba36ac865116f2d20e37f75627bb5'
        else if Pos('SOSUCESSO',DM.ATCadEmpNOMEMP.AsString) <> 0 then
          licenca :='f4767fbd58cee0ff2f875b03c3d01ff668704d1afa11e287856f163ed5389a2185a81c82c240a4ff1cab384993c1a32ab155f19f98eb895f192815629e612f3d';
      end;

    DM.ATCadCli.SetOrder(1);  // codcli
    DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.Text);

    if ( (DM.ATCadPd1NUMRECIBO.AsString = '') and
          (DM.ATCadPd1FLAGNFE.AsString <> '') and
          ((DM.ATCadPd1CONTINGENC.AsString = '1') or (DM.ATCadPd1CONTINGENC.AsString = '7')) ) then
      begin
        // Enviando o XML para SEFAZ...

        if FileExists(cArquivo) then
          begin
            AssignFile(Fentrada,cArquivo);
            Reset(Fentrada,1);
            S:='';
            for i:= 1 to FileSize(Fentrada) do
              begin
                Blockread(Fentrada,buf,1,NumRead);
                S:=S+buf;
              end;

            CloseFile(Fentrada);
            NFe := S;

            // Emviando XML para SEFAZ...
            Util := CoUtil.Create;
            nomeCertificado := trim(edNome.Text);

            siglaWS := 'PE';
            if DM.ATCadPd1FLAGSCAN.AsString = 'S' then
              begin
                siglaWS := 'SVRS';    // ANTES ERA SCAN
              end;

            retWS         := '';
            cabMsg        := '';
            msgResultado  := '';
            tpamb := StrToInt(cTpAmb);

            Screen.Cursor := CrHourGlass;

          //NfeAssinada :=      Util.EnviaNfe2g(siglaWS,NFe,nomeCertificado,Versao,msgDados,msgRetWS,cStat,msgResultado,nroRecibo,dhRecbto,tMed, proxy, usuario, senha, licenca);
            cStat     := 0;
            nroRecibo := '';
            NfeAssinada := Util.EnviaNFSincrono(siglaWS,NFe,nomeCertificado,Versao,msgDados,msgRetWS,cStat,msgResultado,nroRecibo,dhRecbto,tMed, proxy, usuario, senha, licenca);

            // CORRECAO DUPLICIDADE: se o envio nao retornou 100 (204 duplicidade, timeout,
            // resposta perdida, etc.), a SEFAZ pode ja ter autorizado a nota.
            // Consulta pela chave antes de considerar como rejeitada / reenviar.
            if cStat <> 100 then
              begin
                cStatEnv := cStat;
                msgOrig  := msgResultado;
                cStat := Util.consultaNF2G(siglaWS, tpamb, nomeCertificado, Versao, msgDados, msgRetWS, msgResultado, DM.ATCadPd1CHAVEDANFE.AsString, proxy, usuario, senha);
                if cStat <> 100 then
                  begin
                    // nao esta autorizada: mantem o resultado original do envio
                    cStat        := cStatEnv;
                    msgResultado := msgOrig;
                  end;
              end;
            Screen.Cursor := CrDefault;

            // if cStat = 103 then     // lote recebido com sucesso
            if cStat = 100 then     // Autorizado
              begin
                // grava numero recibo no pd1
                // (no envio sincrono o recibo pode vir vazio: grava marcador para
                //  a nota nao cair novamente no ramo de envio)
                if Trim(nroRecibo) = '' then
                  nroRecibo := 'SINCRONO';
                DM.ATCadPd1.Edit;
                DM.ATCadPd1NUMRECIBO.AsString := nroRecibo;
                DM.ATCadPd1RTSEFAZ.AsString   := msgResultado;
                DM.ATCadPd1.Post;
              end
            else
              begin
                DM.ATCadPd1.Edit;
                DM.ATCadPd1RTSEFAZ.AsString   := msgResultado;
                DM.ATCadPd1.Post;
              end;
            Util := nil;
          end;
      end
    else
      if ((DM.ATCadPd1FLAGNFE.AsString <> '') and (DM.ATCadPd1NUMPROTOC.AsString = '') and
         ((DM.ATCadPd1CONTINGENC.AsString = '1') or (DM.ATCadPd1CONTINGENC.AsString = '7')) and
         FileExists(cArquivo) ) then
          // Pedindo autorizacao de uso...
        begin
          AssignFile(Fentrada,cArquivo);
          Reset(Fentrada,1);
          S:='';
          for ii:= 1 to FileSize(Fentrada) do
            begin
              Blockread(Fentrada,buf,1,NumRead);
              S:=S+buf;
            end;

          CloseFile(Fentrada);
          //RExml.Text := S;
          NFe := S;

          Util := CoUtil.Create;
          nomeCertificado := trim(edNome.Text);
          siglaUF := 'PE';    //cbUF.Text;
          if DM.ATCadPd1FLAGSCAN.AsString = 'S' then
            siglaWS := 'SVRS';    // ANTES ERA SCAN
          retWS :='';
          cabMsg :='';
          msgResultado :='';
          tpamb := DM.ATCadPd1TIPOAMBXML.AsInteger;
          nroRecibo := DM.ATCadPd1NUMRECIBO.AsString;
          xmlAssinado := '';
          mensagem := '';


          Util := CoUtil.Create;
          cStat := 0;
          xmlAssinado := Util.Assinar(NFe, 'infNFe', nomeCertificado, resultado, msgResultado);
          NFeAssinada := xmlAssinado;   // evita usar XML residual de outra nota

         if resultado = 5300 then   // 5300 Assinatura realizada com sucesso.
            begin
              // faz a consulta se já autorizou o uso da nfe
              // Util.buscanfe2g(siglaWS, tpamb, xmlAssinado ,nroRecibo, nomeCertificado, Versao, msgDados,msgretWS,cStat, msgResultado,nroProtocolo,dhProtocolo,cMsg,xMsg,proxy, usuario, senha,licenca);
              // recibo vazio ou 'SINCRONO' (envio sincrono): nao ha lote para buscar,
              // vai direto para a consulta pela chave
              if (Trim(nroRecibo) <> '') and (nroRecibo <> 'SINCRONO') then
                Util.buscanfe2g(siglaWS, tpamb, xmlAssinado ,nroRecibo, nomeCertificado, Versao, msgDados,msgretWS,cStat, msgResultado,nroProtocolo,dhProtocolo,cMsg,xMsg,proxy, usuario, senha,licenca)
              else
                cStat := 204;
            end;

          if cStat = 204 then  // Rejeição: Duplicidade de NF-e.
            begin
              // se DUPLICIDADE, pega o protocolo de autorizacao
              cStat := Util.consultaNF2G(siglaWS, tpamb, nomeCertificado, Versao, msgDados, msgretWS, msgResultado,DM.ATCadPd1CHAVEDANFE.AsString , proxy, usuario, senha);
            end;
          

          if cStat = 100 then  // Autorizado uso nfe
            begin

    ///          nroRecibo: retorna o número do recibo do lote atribuído ao lote pela SEFAZ, este será utilizado para consultar o resultado do processamento do lote.
    ///           msgDados: XML com o lote de NF-e para transmissão ao WS
    ///            Versao: informar o versão da mensagem do WS - 1.10 (manual de integração versão 2.04 ou 3.00) ou 2.00 (manual de integração versão 4.0x) >>parâmetro novo!<<
    ///           msgRetWS: XML de resposta do WS
    ///        NFeAssinada: XML da NF-e assinada
    ///       msgResultado: literal do resultado da chamada do WS

              { acrescenta a tag <nfeProc> no INICIO do xml}
              texto1 := '"UTF-8"?>';
              texto2 := '"UTF-8"?><nfeProc xmlns="http://www.portalfiscal.inf.br/nfe" versao="2.00">';
              NFeAssinada := StringReplace(NFeAssinada, texto1, texto2,[rfReplaceAll]);

              { acrescenta as tags de autorizacao de uso no FINAL do xml}
              PosInic := Pos('<verAplic>',msgRetWS);
              PosFin  := Pos('</verAplic>',msgRetWS);
              xverAplic := Copy(msgRetWS,PosInic+10,(PosFin-(PosInic+10)));

              PosInic := Pos('<chNFe>',msgRetWS);
              PosFin  := Pos('</chNFe>',msgRetWS);
              xchNFe  := Copy(msgRetWS,PosInic+7,(PosFin-(PosInic+7)));

              PosInic := Pos('<dhRecbto>',msgRetWS);
              PosFin  := Pos('</dhRecbto>',msgRetWS);
              xdhRecbto  := Copy(msgRetWS,PosInic+10,(PosFin-(PosInic+10)));

              PosInic := Pos('<nProt>',msgRetWS);
              PosFin  := Pos('</nProt>',msgRetWS);
              xnProt  := Copy(msgRetWS,PosInic+7,(PosFin-(PosInic+7)));

              PosInic := Pos('<digVal>',msgRetWS);
              PosFin  := Pos('</digVal>',msgRetWS);
              xdigVal := Copy(msgRetWS,PosInic+8,(PosFin-(PosInic+8)));

              PosInic := Pos('<cStat>',msgRetWS);
              PosFin  := Pos('</cStat>',msgRetWS);
              xcStat := Copy(msgRetWS,PosInic+7,(PosFin-(PosInic+7)));

              PosInic := Pos('<xMotivo>',msgRetWS);
              PosFin  := Pos('</xMotivo>',msgRetWS);
              xxMotivo := Copy(msgRetWS,PosInic+9,(PosFin-(PosInic+9)));

              ProtAutorizacao := '<protNFe versao="2.00" xmlns="http://www.portalfiscal.inf.br/nfe">'+
                                    '<infProt>'+
                                       '<tpAmb>'+cTpAmb+'</tpAmb>'+
                                       '<verAplic>'+xverAplic+'</verAplic>'+
                                       '<chNFe>'+xchNFe+'</chNFe>'+
                                       '<dhRecbto>'+xdhRecbto+'</dhRecbto>'+
                                       '<nProt>'+xnProt+'</nProt>'+
                                       '<digVal>'+xdigVal+'</digVal>'+
                                       '<cStat>'+IntToStr(cStat)+'</cStat>'+
                                       '<xMotivo>'+msgResultado+'</xMotivo>'+
                                   '</infProt>'+
                                 '</protNFe>'+
                                 '</nfeProc>';
              NFeAssinada := NFeAssinada+ProtAutorizacao;


              nPosi := Pos('nProt',msgRetWS);
              cProtoc := copy(msgRetWS,nPosi+6,15);

              nPosi := Pos('dhRecbto',msgRetWS);
              cProtoc := cProtoc + ' - '+copy(msgRetWS,nPosi+17,02)+'/'     // data  2011-03-21T21:58:48
                                        +copy(msgRetWS,nPosi+14,02)+'/'     // data
                                        +copy(msgRetWS,nPosi+09,04);        // data

              cProtoc := cProtoc + ' - '+copy(msgRetWS,nPosi+20,08);        // hora 11-03-21T21:58:48

              DM.ATCadPd1.Edit;
              DM.ATCadPd1NUMPROTOC.AsString := cProtoc;
              //DM.ATCadPd1RTSEFAZ.AsString   := msgResultado;
              DM.ATCadPd1CONTAPAG.AsVariant := 0;
              DM.ATCadPd1.Post;

              AssignFile(Fsaida,cArquivo);
              Rewrite(Fsaida);
              Write(Fsaida, NFeAssinada);
              CloseFile(Fsaida);

              // MOVE O XML PARA PASTA XML
              nomearq := 'NF'+COPY(DM.ATCadPd1NOTAFISC.AsString,4,6)+'.XML';

              if DirectoryExists('c:\NFCe em Dephi xe5\') then
                moveFile(pchar('c:\DATANET\'+nomearq),pchar('c:\DATANET\XML\'+nomearq));

              if DirectoryExists('f:\datanet') then
                moveFile(pchar('f:\DATANET\'+nomearq),pchar('f:\DATANET\XML\'+nomearq));

              if DirectoryExists('g:\datanet') then
                moveFile(pchar('g:\DATANET\'+nomearq),pchar('g:\DATANET\XML\'+nomearq));
            end
          else
            begin
              DM.ATCadPd1.Edit;
              DM.ATCadPd1RTSEFAZ.AsString  := msgResultado;
              DM.ATCadPd1.Post;
            end;
          Util := nil;
        end
      else
        begin
{
As propriedades SystemOptions controlar a configuração do TRvSystem componente:
   soUseFiler - sempre enviará o relatório para um arquivo de relatório. Isso pode
                ser muito útil se o método macro foi usada no relatório
   soWaitForOK - determina se o usuário pressionar o botão OK
                uma vez que o relatório foi gerado para a saída
   soShowStatus - determina se ou não a tela de status é
                exibida quando o relatório está sendo gerado
   soAllowPrintFromPreview - determina se o usuário pode imprimir a partir de
                a tela de visualização
   soAllowSaveFromPreview - determina se o usuário pode gravar a partir de
                a tela de visualização
   soPreviewModal - determina se a tela de visualização será restrita
   soNoGenerate - fará com que o componente RvSystem para pular o
                fase de geração do relatório e siga em frente para a tela ou a
                impressora. Esta opção só deve ser usado com um StreamMode de smFile
                onde o arquivo de relatório foi gerado anteriormente e só precisa ser
                visualizado ou impresso
}

          // Imprimindo DANFE...
          if ((DM.ATCadPd1NUMRECIBO.AsString <> '') and
              (DM.ATCadPd1NUMPROTOC.AsString <> '') and
              (DM.ATCadPd1CONTINGENC.AsString <> '2') and
              (DM.ATCadPd1IMPDANFE.AsString  =  '')) then
            begin
              if True then    // chkPDF.Checked then
                begin
                  lSegundaVez := False;     // gera os boletos em pdf
                  RvSystemDANFE.DefaultDest    := rdFile;
                  RvSystemDANFE.SystemFiler.StatusFormat := 'Gerando PDF pag. %p';
                  RvSystemDANFE.DoNativeOutput := False;
                  RvSystemDANFE.RenderObject   := RvRenderPDF1;
                  RvSystemDANFE.SystemSetups   := RvSystemDANFE.SystemSetups - [ssAllowSetup];

                  RvSystemDANFE.Execute;
                end;
              lSegundaVez  := True;      // imprime os danfes
              RvSystemDANFE.DefaultDest    := rdPrinter;
              RvSystemDANFE.SystemOptions  := RvSystemDANFE.SystemOptions + [soShowStatus];
              RvSystemDANFE.DoNativeOutput := True;
              RvSystemDANFE.SystemSetups   := RvSystemDANFE.SystemSetups - [ssAllowSetup];
              RvSystemDANFE.SystemFiler.StatusFormat := 'Imprimindo pag. %p';
              RvSystemDANFE.Execute;

              DM.ATCadPd1.Edit;
              Dm.ATCadPd1IMPDANFE.AsString := 'S';  // para nao imprimir danfe novamente
              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
              if (DM.ATCadCliEMAIL.AsString <> '') and (DM.ATCadPd1EMAIL.AsString = '') then
                DM.ATCadPd1EMAIL.AsString     := '1';
              DM.ATCadPd1.Post;

              Util := nil;
              DM.ATCadPd1.Next;
            end;
        end;

  if DM.ATCadPd1.Eof then
    DM.ATCadPd1.GoTop;

  Timer1.Enabled := True;
end;

procedure TFormEnviaImprime.ckbEnviarClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbEmProcClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbRejeitadosClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbAutorizadosClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbImprimindoClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbImpressoClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.edLicencaExit(Sender: TObject);
begin
  lProcessando := False;
end;

procedure TFormEnviaImprime.DBGrid1Enter(Sender: TObject);
var
  cFiltroEnviar,cFiltroEmProc,cFiltroRejeitados,cFiltroAutorizados,
  cFiltroCanceladas,cFiltroImprimindo,cFiltroImpressos:string;
begin
  if not ckbProcessamento.Checked then Exit;

  Timer1.Enabled     := True;
  
  cFiltroEnviar      := 'False';
  cFiltroEmProc      := 'False';
  cFiltroCanceladas  := 'False';
  cFiltroRejeitados  := 'False';
  cFiltroAutorizados := 'False';
  cFiltroImpressos   := 'False';
  cFiltroImprimindo  := 'False';

  if ckbEnviar.Checked then
    cFiltroEnviar := '( ((numrecibo = "               ")or(numprotoc = "               ")) and '+
                      '(flagnfe <> " ") and (cart17 <> "C") and (flagsit <> "9") and '+
                      '((contingenc = "1") or (contingenc = "7")) )';

  if ckbEmProc.Checked then
    cFiltroEmProc  := '(((Pos("103",RTSEFAZ)>0)or'+
                        '(Pos("104",RTSEFAZ)>0)or'+
                        '(Pos("105",RTSEFAZ)>0)) and (cart17 <> "C"))';

  if ckbRejeitados.Checked then
    cFiltroRejeitados := '((Pos("Rejeição",RTSEFAZ)>0) and (cart17 <> "C"))';

  if ckbNFECanceladas.Checked then
    cFiltroCanceladas := '((Pos("101",RTSEFAZ)>0) and (cart17 <> "C"))';

  if ckbImprimindo.Checked then
    cFiltroImprimindo := '((numprotoc <> "               ") and (impdanfe = " ") and (cart17 <> "C") and (Pos("101",RTSEFAZ)=0))';

  if ckbImpresso.Checked then
    cFiltroImpressos := '((numprotoc <> "               ") and (cart17 <> "C") and (impdanfe = "S"))';

  if ckbAutorizados.Checked then
    cFiltroAutorizados := '((numprotoc <> "               ") and (cart17 <> "C")) ';

  DM.ATCadPd1.SetOrder(2);
  DM.ATCadPd1.Filter := '('+cFiltroEnviar+'or'+
                        cFiltroEmProc+'or'+
                        cFiltroRejeitados+'or'+
                        cFiltroAutorizados+'or'+
                        cFiltroImprimindo+'or'+
                        cFiltroImpressos+'or'+
                        cFiltroCanceladas+')';

  DM.ATCadPd1.GoTop;
  DBGrid1.Refresh;
end;

procedure TFormEnviaImprime.DBGrid1ColExit(Sender: TObject);
begin
  Timer1.Enabled := False;
end;

procedure TFormEnviaImprime.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Timer1.Enabled := False;
end;

procedure TFormEnviaImprime.FormActivate(Sender: TObject);
begin
  Timer1.Enabled := True;
  Label3.Caption := DM.ATCadEmpSIGLAEMP.AsString;

  if Pos('SUCESSO',dm.ATCadEmpNOMEMP.AsString) > 0 then
    EdNome.Text := 'CN=SOSUCESSO DE MEDICAMENTOS LTDA, OU=(EM BRANCO), OU=(EM BRANCO), OU=(EM BRANCO), OU=(EM BRANCO), OU=(EM BRANCO), OU=000001008664151, OU=(EM BRANCO), O=ICP-Brasil, C=BR';

  if Pos('CM COMERC',dm.ATCadEmpNOMEMP.AsString) > 0 then
    EdNome.Text := 'CN=CM COMERCIO DE MEDICAMENTOS E PERFUMARIAS LTDA:19454639000175, OU=videoconferencia, OU=06123758000101, OU=RFB e-CNPJ A1, OU=Secretaria da Receita Federal do Brasil - RFB, L=RECIFE, S=PE, O=ICP-Brasil, C=BR';

  DBGrid1.SetFocus;

end;                

procedure TFormEnviaImprime.RvSystemDanfeBeforePrint(Sender: TObject);
begin
with Sender as TBaseReport do
  begin
    SelectPaper('A4');
    SetPaperSize(0,29.7,21);
  end;
end;

procedure TFormEnviaImprime.BitBtn1Click(Sender: TObject);
begin
  if DM.ATCadPd1NUMPROTOC.AsString <> '' then
    begin
      ShowMessage('Limpesa Negada. Nota com Protocolo.');
      Exit;
    end;
  DM.ATCadPd1.Edit;
  DM.ATCadPd1NUMRECIBO.AsString := '';
  DM.ATCadPd1RTSEFAZ.AsString   := '';
  DM.ATCadPd1.Post;
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.ckbProcessamentoClick(Sender: TObject);
begin
  DBGrid1.SetFocus;
end;

procedure TFormEnviaImprime.RvSystemDANFEPrint(Sender: TObject);
var
  cTipo,cNatu,cCNPJ,cInsc,cDspCliente,cCep:string;
  cLot1,aux,micmretido,moperfisc,cCampoAux:string;
  nTotItens,nTotPagNot,TotItemPag,nPagAtuNot:Real;
  nTotIteNot,nFator,nLinha:real;
  nResultado:Real;
  y,nTotBas,LtQtdeFat:integer;
  Bitmap:TBitmap;
  cNotaIni,cNotaFin,menspro,letras,cChave,cLinhaBas:string;
  nfCorrecao:Boolean;
begin
  with Sender as TBaseReport do
    begin
      DM.ATCadPd1.SetOrder(2);    // notafisc
      DM.ATCadPd1.DisableControls;
      DM.ATCadPd1.GoTop;
      cNotaIni := copy(DM.ATCadPd1NOTAFISC.AsString,4,6);
      while not DM.ATCadPd1.Eof do
        begin
          TotItemPag := 10;   // deixar sempre 2 linhas para mensagens. Obs: mudar tb no if...
          Bitmap := TBitmap.Create;
          try
            Bitmap.LoadFromFile('C:\DANFE.bmp');
            PrintBitmapRect(0,0,29.7,21,Bitmap);  // imprime imagem bmp do DANFE

            //Bitmap.LoadFromFile('C:\LOGO.bmp');
            //PrintBitmapRect(3.2,0.8,6,3.5,Bitmap);  // imprime imagem bmp do LOGO REMED
          finally
            FreeAndNil(Bitmap);
          end;

          SetFont('Arial',8);
          Bold := True;

          Bold := False;
          nPagAtuNot := 1;

          cNatu := natureza(DM.ATCadPd1NATOPE.AsVariant); // pega descricao do CFOP
          nfCorrecao := False;
          if (DM.ATCadPd1VALLIQFAT.Value = 0) then
            nfCorrecao := True;   // nf de correcao

          if DM.ATCadPd1NATOPE.Value < 4 then
            cTipo := '1'   // nota de entrada
          else
            cTipo := '2';  // nota de saida

          SetFont('Arial',10);
          Bold := True;
          PrintXY(3.5,1.1,'CM COMÉRCIO DE MEDICAMENTOS E PERFUMARIAS LTDA'); 
          SetFont('Arial',6);
          Bold := False;
          //PrintXY(3.5,1.5,'Clara Maria A.A.DE L.Com de Med. e Perf-EIREL');
          PrintXY(3.5,1.5,'MERCANTIL DE MEDICAMENTOS E PERFUMARIAS');
          //PrintXY(6.5,1.5,'C.N.A.E: 4644-3/01');
          SetFont('Arial',8);
          PrintXY(3.5,1.9,'RUA CORAÇÃO DE MARIA, 141');
          PrintXY(3.5,2.3,'SÃO JOSÉ - RECIFE - PE - CEP:50.020-400');
          Bold := True;
          PrintXY(3.5,2.7,'FONES:(81)3224-6653/7665/3369');
          PrintXY(3.5,3.1,'Email: mercantil.medicamentos@outlook.com');
          Bold := False;
          //PrintXY(11,3.5,'AUT./MS: 1.04.724-6');

          PrintXY(16.6,2.6,cTipo);
          PrintBarCode128(RvSystemDANFE,1.2,20.2,DM.ATCadPd1CHAVEDANFE.AsString);
          PrintXY(15,3.1,DM.ATCadPd1NOTAFISC.AsString);

          // filtra tens somente da prenota atual devido somaitens()
          DM.ATCadPd2.DisableControls;
          DM.ATCadPd2.Scoped := False;
          if DM.ATCadEmpSEPARAPED.AsString = 'S' then
            begin
              DM.ATCadPd2.SetOrder(5);  // numped+descpro
              DM.ATCadPd2.ScopeBegin := DM.ATCadPd1NUMPED.AsString;
              DM.ATCadPd2.ScopeEnd   := DM.ATCadPd1NUMPED.AsString;
            end
          else
            begin
              DM.ATCadPd2.SetOrder(3);  // numprenot+descpro
              DM.ATCadPd2.ScopeBegin := DM.ATCadPd1NUMPRENOT.AsString;
              DM.ATCadPd2.ScopeEnd   := DM.ATCadPd1NUMPRENOT.AsString;
            end;

          DM.ATCadPd2.Scoped := True;

          nLinha := 3.1;
          nTotPagNot := somaitens();   // retorna o total de paginas...
          PrintXY(17.5,nLinha,'Pag: 1/ '+FloatToStr(nTotPagNot));

          if DM.ATCadPd1FLAGSCAN.AsString = 'S' then
            PrintXY(15.5,3.66,'0')
          else
            PrintXY(15.5,3.66,'0');  // serie da nota

          FontRotation := 90;
          PrintXY(2,3.5,DM.ATCadPd1NOTAFISC.AsString);
          FontRotation := 0;

          SetFont('Arial',5);
          FontRotation := 90;
          PrintXY(0.8,19.7,'RECEBEMOS DA MERCANTIL DE MEDICAMENTOS E PERFUMARIAS, O(S) PRODUTO(S) CONSTANTE(S) DESTA NOTA FISCAL INDICADA AO LADO');
          FontRotation := 0;
          SetFont('Arial',8);

          cNatu := natureza(DM.ATCadPd1NATOPE.AsVariant); // pega descricao do CFOP
          nLinha := 4.5;
          PrintXY(3.5,nLinha,cNatu);                   // cfop + descricao do cfop
          if False then
             PrintXY(18.7,nLinha,'DANFE em contingência, impresso em decorrência de problemas técnicos')
          else
             PrintXY(18.7,nLinha,DM.ATCadPd1NUMPROTOC.AsString);  // numero do protocolo

          nLinha := 5.15;
          PrintXY(4,nLinha,'0559394-81');
          PrintXY(14.5,nLinha,'19.454.639/0001-75');
          PrintXY(8,nLinha,DM.ATCadPd1INSCSUBST.AsString);                     //

          cChave := copy(DM.ATCadPd1CHAVEDANFE.AsString,01,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,05,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,09,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,13,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,17,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,21,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,25,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,29,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,33,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,37,4)+' '+
                    copy(DM.ATCadPd1CHAVEDANFE.AsString,41,4);
          PrintXY(18.7,nLinha,cChave);

          if lSegundaVez then
            begin
              DM.ATCadPd1.Edit;
              Dm.ATCadPd1IMPDANFE.AsString := 'S';  // para nao imprimir danfe novamente
              DM.ATCadCli.SetOrder(1);
              DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsString);
              if (DM.ATCadCliEMAIL.AsString <> '') and (DM.ATCadPd1EMAIL.AsString = '') then
                DM.ATCadPd1EMAIL.AsString     := '1';
              DM.ATCadPd1.Post;
            end;

          DM.ATCadCli.SetOrder(1);
          DM.ATCadCli.Seek(DM.ATCadPd1CODCLI.AsVariant);

          nLinha := 6.1;
          if DM.ATCadCliCODCLI.AsString = DM.ATCadEmpCODCLIBAL.AsString then
            PrintXY(3.5,nLinha,DM.ATCadPd1NOMCLIPED.AsVariant+' - '+DM.ATCadCliCODCLI.AsString)
          else
            PrintXY(3.5,nLinha,DM.ATCadCliRAZSOCCLI.AsVariant+' - '+DM.ATCadCliCODCLI.AsString);

          if DM.ATCadCliPESFISJUR.AsString = 'J' then
            cCNPJ := formatacnpj(DM.ATCadCliCGCCLI.AsString)
          else
            cCNPJ := DM.ATCadCliCPFCLI.AsString;

          PrintXY(19.5,nLinha,cCNPJ);
          PrintXY(26,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant));                     //

          nLinha := 6.75;
          PrintXY(3.5,nLinha,DM.ATCadCliENDCLI.AsString);
          PrintXY(16.5,nLinha,DM.ATCadCliBAIRCLI.AsString);

          ccep := copy(DM.ATCadCliCEPCLI.AsString,1,5)+'-'+copy(DM.ATCadCliCEPCLI.AsString,6,3);
          PrintXY(22,nLinha,ccep);

          if DM.ATCadPd1DTSAIDA.Value = 0 then
            PrintXY(26,nLinha,'')
          else
            PrintXY(26,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTSAIDA.AsVariant));

          nLinha := 7.4;
          PrintXY(3.5,nLinha,DM.ATCadCliCIDCLI.AsString);
          cCampoAux := Copy(DM.ATCadCliTELCLI.AsString,1,8)+'-'+Copy(DM.ATCadCliTELCLI.AsString,9,8);
          PrintXY(12,nLinha,cCampoAux);
          PrintXY(18.5,nLinha,DM.ATCadCliESTCLI.AsString);

          if DM.ATCadCliINSCESCLI.AsString <> '' then
            cInsc := formatainsc(DM.ATCadCliINSCESCLI.AsString,DM.ATCadCliESTCLI.AsString)
          else
            cInsc := 'ISENTO';

          PrintXY(19.5,nLinha,cInsc);
          PrintXY(26,nLinha,'');

          cnatu := FloatToStr(DM.ATCadPd1NATOPE.AsVariant);
          cnatu := copy(cnatu,1,1)+'.'+copy(cnatu,3,3);

          if Pos(cnatu,'1.102,1.202,5.908,5.910,'+
                       '5.152,6.152,1.441,2.441,'+
                       '5.911,5.912,5.913,5.914,'+
                       '5.556,6.556,'+
                       '5.917,5.918,5.927,5.949,'+
                       '2.102,2.202,6.908,6.910,'+
                       '6.911,6.912,6.913,6.914,'+
                       '6.917,6.918,6.927,6.949,') = 0 then
            begin
              nLinha := 8.1;
              if DM.ATCadPd1PRAZOLIM1.Value > 0 then
                begin
                  PrintXY(3.5,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-1/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(6,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM1.AsVariant));
                  PrintXY(8,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ1.AsFloat]));
                end;

              if DM.ATCadPd1PRAZOLIM2.Value > 0 then
                begin
                  PrintXY(12,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-2/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(14.5,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM2.AsVariant));
                  PrintXY(17,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ2.AsFloat]));
                end;

              if DM.ATCadPd1PRAZOLIM3.Value > 0 then
                begin
                  PrintXY(20.5,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-3/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(23.5,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM3.AsVariant));
                  PrintXY(27,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ3.AsFloat]));
                end;

              nLinha := 8.4;
              if DM.ATCadPd1PRAZOLIM4.Value > 0 then
                begin
                  PrintXY(3.5,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-4/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(6,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM4.AsVariant));
                  PrintXY(8,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ4.AsFloat]));
                end;

              if DM.ATCadPd1PRAZOLIM5.Value > 0 then
                begin
                  PrintXY(12,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-5/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(14.5,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM5.AsVariant));
                  PrintXY(17,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ5.AsFloat]));
                end;

              if DM.ATCadPd1PRAZOLIM6.Value > 0 then
                begin
                  PrintXY(20.5,nLinha,DM.ATCadPd1NOTAFISC.AsString+'-6/'+DM.ATCadPd1NUMDUPLIC.AsString);
                  PrintXY(23.5,nLinha,FormatDateTime('dd/mm/yyyy',DM.ATCadPd1DTEMIS.AsVariant+DM.ATCadPd1PRAZOLIM6.AsVariant));
                  PrintXY(27,nLinha,Format('%10.2f',[DM.ATCadPd1VALFATPZ6.AsFloat]));
                end;
            end;

          nLinha := 9.3;
          PrintXY(6.5,nLinha,Format('%10.2f',[DM.ATCadPd1VALBASICM.AsFloat]));
          PrintXY(11.5,nLinha,Format('%10.2f',[DM.ATCadPd1VALICMNOT.AsFloat]));
          PrintXY(16.5,nLinha,Format('%10.2f',[DM.ATCadPd1VALBASRET.AsFloat]));
          PrintXY(21.5,nLinha,Format('%10.2f',[DM.ATCadPd1VALICMRET.AsFloat]));
          if nfCorrecao then     // nf de correcao
            PrintXY(27,nLinha,Format('%10.2f',[0.00]))
          else
            PrintXY(27,nLinha,Format('%10.2f',[DM.ATCadPd1TOTFATBRU.AsFloat]));
            //PrintXY(27,nLinha,Format('%10.2f',[DM.ATCadPd1TOTBRUDANF.AsFloat]));

          nLinha := 9.9;
          PrintXY(6.5,nLinha,Format('%10.2f',[DM.ATCadPd1VALFRETE.AsFloat]));
          PrintXY(11.5,nLinha,Format('%10.2f',[0.00]));
          PrintXY(16.5,nLinha,Format('%10.2f',[0.00]));
          PrintXY(21.5,nLinha,Format('%10.2f',[0.00]));
          PrintXY(27,nLinha,Format('%10.2f',[DM.ATCadPd1VALLIQFAT.AsFloat+
                                             DM.ATCadPd1VALICMRET.AsFloat+
                                             DM.ATCadPd1VALRETICM.AsFloat+
                                             DM.ATCadPd1VALFRETE.AsFloat+
                                             DM.ATCadPd1VALREPASS.AsFloat]));

          SetFont('Arial',5);
          Bold := True;
          PrintXY(13.5,12.77,'NCM/SH');
          PrintXY(17.15,12.77,'%Desc');
          PrintXY(19.5,12.77,'Subst');
          SetFont('Arial',8);

          if DM.ATCadPd1CODTRA.AsString <> '' then
            begin
              DM.ATCadTra.SetOrder(1);
              DM.ATCadTra.Seek(DM.ATCadPd1CODTRA.AsVariant);
              nLinha := 10.9;
              PrintXY(3.5,nLinha,DM.ATCadTraNOMTRA.AsVariant);
              PrintXY(18,nLinha,'1');
              PrintXY(19.5,nLinha,DM.ATCadTraPLACAVEI.AsVariant);
              PrintXY(22,nLinha,DM.ATCadTraESTTRA.AsVariant);
              cCNPJ := formatacnpj(DM.ATCadTraCGCTRA.AsString);
              PrintXY(24,nLinha,cCNPJ);
              nLinha := 11.5;
              PrintXY(3.5,nLinha,DM.ATCadTraENDTRA.AsString+' - '+DM.ATCadTraBAIRTRA.AsString);
              PrintXY(15.5,nLinha,DM.ATCadTraCIDTRA.AsVariant);
              PrintXY(22,nLinha,DM.ATCadTraESTTRA.AsVariant);
              PrintXY(24,nLinha,DM.ATCadTraINSCTRA.AsVariant);
              nLinha := 12.1;
              PrintXY(4.5,nLinha,DM.ATCadPd1VOLUMES.AsVariant);
              PrintXY(6,nLinha,'CAIXA(S)');
              PrintXY(23.5,nLinha,DM.ATCadPd1PESOBRU.AsVariant);
              PrintXY(27.5,nLinha,DM.ATCadPd1PESO.AsVariant);
            end;

          SetFont('Courier new',7);
          Bold := True;

          if DM.ATCadPd1EMPENHO.AsString <> '' then
            begin
              PrintXY(3.5,16.5,DM.ATCadPd1MENSNOT1.AsString+' '+
                               DM.ATCadPd1MENSNOT2.AsString+' '+
                               DM.ATCadPd1MENSNOT3.AsString+' '+
                               '- SETOR: '+DM.ATCadPd1CODSET.AsString+
                               ' - ROTA: '+DM.ATCadPd1CODROT.AsString+
                               '  -- Num. Empenho: '+DM.ATCadPd1EMPENHO.AsString);
            end
          else
            if not nfCorrecao then
              begin
                PrintXY(3.5,16.5,DM.ATCadPd1MENSNOT1.AsString+' '+
                                 DM.ATCadPd1MENSNOT2.AsString+' '+
                                 DM.ATCadPd1MENSNOT3.AsString+' '+
                                 '- SETOR: '+DM.ATCadPd1CODSET.AsString+
                                 ' - ROTA: '+DM.ATCadPd1CODROT.AsString);
              end
            else
              begin
                // aqui os dados referentes a nf de correcao.
                PrintXY(3.5,16.5,DM.ATCadPd1MENSNOT1.AsString);
                recebetotaisnota(DM.ATCadPd1MENSNOT2.AsString);
                recebetotaisnota(DM.ATCadPd1MENSNOT3.AsString);
                recebetotaisnota(DM.ATCadPd1MENSNOT4.AsString);
                recebetotaisnota(DM.ATCadPd1MENSNOT5.AsString);
              end;

          //cDspCliente := '';
          //if (DM.ATCadCliALVARA.AsString <> '') then
          //  cDspCliente := '  ////  DSP CLIENTE=> '+DM.ATCadCliALVARA.AsString;
          //recebetotaisnota('DSP REMED => 3.4.57.4.0960.002'+cDspCliente );

          if (DM.ATCadPd1TOTBRUREP.AsFloat > 0) then
            begin
              //recebetotaisnota('* TOT. PROD. S/ REPASSE: '+DM.ATCadPd1TOTBRUREP.AsFloat);
              recebetotaisnota('REPASSE ICMS: '+DM.ATCadPd1VALREPASS.AsString);
            end;

          if (DM.ATCadPd1VALTOTCRED.AsFloat > 0) then
            recebetotaisnota('CRED.ICMS NAO LANCADO PELA ENTRADA: '+DM.ATCadPd1VALTOTCRED.AsString);

          //if (DM.ATCadCliCODCLI.AsString = '000177') then
          //  recebetotaisnota('////  DESPACHO ICMS-MD No. 015/2002');

          nTotBas   := 0;
          cLinhaBas := '';
          if (DM.ATCadPd1VALBASICM1.AsFloat > 0) then
            begin
              nTotBas := nTotBas + 1;
              cLinhaBas := cLinhaBas +'BC 7% ==> '+DM.ATCadPd1VALBASICM1.AsString+
                                      '  ICMS ==> '+DM.ATCadPd1VALICMNOT1.AsString
            end;
          if (DM.ATCadPd1VALBASICM2.AsFloat > 0) then
            begin
              nTotBas := nTotBas + 1;
              cLinhaBas := cLinhaBas +'BC 12% ==> '+DM.ATCadPd1VALBASICM2.AsString+
                                      '  ICMS ==> '+DM.ATCadPd1VALICMNOT2.AsString
            end;
          if (DM.ATCadPd1VALBASICM3.AsFloat > 0) then
            begin
              nTotBas := nTotBas + 1;
              cLinhaBas := cLinhaBas +'BC 18% ==> '+DM.ATCadPd1VALBASICM3.AsString+
                                      '  ICMS ==> '+DM.ATCadPd1VALICMNOT3.AsString
            end;
          if (DM.ATCadPd1VALBASICM4.AsFloat > 0) then
            begin
              nTotBas := nTotBas + 1;
              cLinhaBas := cLinhaBas +'BC 25% ==> '+DM.ATCadPd1VALBASICM4.AsString+
                                      '  ICMS ==> '+DM.ATCadPd1VALICMNOT4.AsString
            end;
          if nTotBas > 1 then
            recebetotaisnota(cLinhaBas);

          if (DM.ATCadPd1VALRETICM.AsFloat > 0) then
            recebetotaisnota('RETORNO DO ICMS: '+DM.ATCadPd1VALRETICM.AsString);

          if (DM.ATCadPd1VALDESVAR.AsFloat > 0) and (DM.ATCadPd1DSCRODAPE.AsString = 'S') then
            recebetotaisnota('DESCONTO VAREJO: '+DM.ATCadPd1VALDESVAR.AsString);

          if (DM.ATCadPd1TOTDESPRO.AsFloat > 0) and (DM.ATCadPd1DSCRODAPE.AsString = 'S') then
            recebetotaisnota('DESC. PRODUTOS: '+DM.ATCadPd1TOTDESPRO.AsString);

          if (DM.ATCadPd1VALDESCOM.AsFloat > 0) and (DM.ATCadPd1DSCRODAPE.AsString = 'S') then
            begin
              if (DM.ATCadPd1DESCESP.AsFloat > 0) then
                recebetotaisnota('DESCONTO ESPECIAL: '+DM.ATCadPd1VALDESCOM.AsString)
              else
                recebetotaisnota('DESCONTO COMERCIAL: '+DM.ATCadPd1VALDESCOM.AsString);
            end;

          if (DM.ATCadPd1VALCONFIS.AsFloat > 0)  then
            recebetotaisnota('Isent.Pis/Cofins: '+DM.ATCadPd1VALCONFIS.AsString);

          if (DM.ATCadPd1DECR24891.AsFloat > 0)  then
            recebetotaisnota('DESCONTO DECRETO 28044: '+DM.ATCadPd1DECR24891.AsString);

          if (DM.ATCadPd1DECR27541.AsFloat > 0)  then
            recebetotaisnota('DESCONTO DECRETO 27541: '+DM.ATCadPd1DECR27541.AsString);

          nTotItens := 0;
          nFator    := 0.3;     // usado para pular linha a cada 0.3 milimetros

          letras  := '';
          menspro := '';
          DM.ATCadPd2.GoTop;
          while not DM.ATCadPd2.Eof do
            begin
              if (DM.ATCadPd2QUANTFAT.Value > 0) then
                begin
                  DM.ATCadPro.SetOrder(1);
                  DM.ATCadPro.Seek(DM.ATCadPd2CODPRO.AsString);

                  // o uso de fontes mono-espaçadas nos relatórios (aquelas em que qualquer
                  // caracter possui o mesmo tamanho), por exemplo a Courier new.
                  // Essa não é uma boa técnica, porém não é regra.
                  // Eu, particularmente, prefiro as fontes TrueType Verdana ou Tahoma.
                  SetFont('Courier new',7);
                  Bold := True;

                  if nPagAtuNot = 1 then
                    nLinha := nfator+12.8  // 12.8 corresponde a linha na primeira pagina
                  else
                    nLinha := nfator+6.1;  // 6 corresponde a linha nas paginas maiores que 1

                  if (DM.ATCadProCLASFISC.AsString = 'S') and (Pos(DM.ATCadProOPCAO.AsString,'P,N')>0) then
                    PrintXY(3.3,nLinha,DM.ATCadPd2CODPRO.AsVariant+DM.ATCadProOPCAO.AsVariant+'.')
                  else
                    PrintXY(3.3,nLinha,DM.ATCadPd2CODPRO.AsVariant+DM.ATCadProOPCAO.AsVariant);

                  if (DM.ATCadProREPASSE.AsString = '*') and (DM.ATCadPd1VALREPASS.AsFloat > 0) then
                    PrintXY(4.5,nLinha,'*');

                  menspro := '';
                  if DM.ATCadProMENSPRO.AsString <> '' then
                    menspro := '('+DM.ATCadProMENSPRO.AsString+')';

                  IF (DM.ATCadCliDEC24891.AsString = 'S') AND (DM.ATCadProDEC24891.AsString = 'S') AND
                     (DM.ATCadPd2DEC24891.AsString = 'S') AND (Pos('H',letras) = 0) then
                    begin
                      letras := letras + 'H';
                      menspro := '(H)';
                      recebemenspro('H');  // QUARDA NA MATRIZ PARA MOSTRAR NOS DADOS ADCIONAIS
                    end
                  ELSE IF (DM.ATCadCliDEC27541.AsString = 'S') and (DM.ATCadProDEC27541.AsString = 'S') AND
                      (DM.ATCadPd2DEC27541.AsString = 'S') AND (Pos('I',letras) = 0) then
                    begin
                      letras   := letras + 'I';
                      menspro := '(I)';
                      recebemenspro('I');  // QUARDA NA MATRIZ PARA MOSTRAR NOS DADOS ADCIONAIS
                    end
                  ELSE IF (moperfisc = '1') AND (DM.ATCadProMENSPRO.AsString = 'A') then
                      letras   := letras + ''
                  ELSE IF (DM.ATCadCliICMRETIDO.AsString = 'S') AND (Pos(micmretido,'245') <> 0) then
                      letras   := letras + ''
                  ELSE IF (DM.ATCadProMENSPRO.AsString <> '') AND (Pos(DM.ATCadProMENSPRO.AsString,letras) = 0) then
                    begin
                      letras   := letras + DM.ATCadProMENSPRO.AsString;
                      menspro := '('+DM.ATCadProMENSPRO.AsString+')';
                      recebemenspro(DM.ATCadProMENSPRO.AsString); // QUARDA NA MATRIZ PARA MOSTRAR NOS DADOS ADCIONAIS
                    end;

                  PrintXY(4.7,nLinha,DM.ATCadPd2DESCPRO.AsString);
                  PrintXY(11,nLinha,menspro);

                  DM.ATCadPri.SetOrder(1);
                  DM.ATCadPri.Seek(DM.ATCadProCODPRI.AsString);
                  if (DM.ATCadPriCODPRI.AsString = DM.ATCadProCODPRI.AsString) then
                    PrintXY(11.5,nLinha,DM.ATCadPriLISTAPRI.AsString);

                  PrintXY(13.2,nLinha,DM.ATCadProCLASSFISC.AsString);

                  cLot1 := '';

                  DM.ATCadLtp.SetOrder(2);
                  DM.ATCadLtp.Seek(DM.ATCadPd1NUMPED.AsString+DM.ATCadPd2CODPRO.AsString);
                  IF DM.ATCadLtp.Found then
                    begin
                      cLot1 := DM.ATCadLtpNUMLOTE.AsString;
                      PrintXY(15,nLinha,DM.ATCadLtpNUMLOTE.AsString);

                      LtQtdeFat := DM.ATCadLtpQTDEFAT.AsVariant;
                      aux := DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString ;
                      // DEVIDO TER LOTES IGUAIS, DE NOTAS DE ENTRADA DIFERENTES.
                      // AS ETIQUETAS SAEM COM "CODSETETQ" DIFERENTES.

                      DM.ATCadLtp.Next;
                      while (DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString = aux) and
                            (not DM.ATCadLtp.Eof) do
                        begin
                          LtQtdeFat := LtQtdeFat + DM.ATCadLtpQTDEFAT.AsVariant;
                          DM.ATCadLtp.Next;
                        end;
                    end;

                  PrintXY(16.4,nLinha,Format('%10.2f',[DM.ATCadPd2DESCBONIF.AsFloat]));

                  IF (DM.ATCadProPREVENDA2.AsFloat > 0) and (DM.ATCadCliINSCESCLI.AsString <> '') then
                    PrintXY(17.6,nLinha,Format('%10.2f',[DM.ATCadProPREVENDA2.AsFloat]));

                  PrintXY(18.7,nLinha,Format('%10.2f',[DM.ATCadPd2VALICMRET.AsFloat]));
                  PrintXY(20.4,nLinha,DM.ATCadPd2CFOP.AsString);
                  PrintXY(21.4,nLinha,DM.ATCadPd2SITTRIB.AsString);

                  IF DM.ATCadPd2CODAPR.AsString = '999'  then
                    PrintXY(22.1,nLinha,DM.ATCadProUNIDPRO.AsString)
                  ELSE
                    begin
                      DM.ATCadApr.SetOrder(1);
                      DM.ATCadapr.Seek(DM.ATCadPd2CODAPR.AsString);
                      PrintXY(22.1,nLinha,DM.ATCadAprUNID.AsString);
                    end;

                  if cLot1 = '' then
                    PrintXY(23.7,nLinha,DM.ATCadPd2QUANTFAT.AsVariant)
                  else
                    PrintXY(23.7,nLinha,IntToStr(LtQtdeFat));

                  PrintXY(24.3,nLinha,Format('%10.2f',[DM.ATCadPd2PREVENDANF.AsFloat]));
                  PrintXY(26.3,nLinha,Format('%10.2f',[DM.ATCadPd2PREVENDANF.AsFloat*
                                                    (DM.ATCadPd2QUANTFAT.AsFloat*(1-(DM.ATCadPd2DESCBONIF.AsFloat/100)))]));
                  PrintXY(28.2,nLinha,DM.ATCadPd2ALIQUOTA.AsString);
                  nFator := nFator + 0.3;

                  DM.ATCadLtp.SetOrder(2);
                  DM.ATCadLtp.Seek(DM.ATCadPd1NUMPED.AsString+DM.ATCadPd2CODPRO.AsString);
                  IF DM.ATCadLtp.Found then
                    begin
                      // soma total de itens do mesmo lote
                      while (DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString =
                             DM.ATCadPd1NUMPED.AsString+DM.ATCadPd2CODPRO.AsString) and
                             (not DM.ATCadLtp.Eof) do
                        begin
                          if cLot1 <> DM.ATCadLtpNUMLOTE.AsString then
                            begin
                              if DM.ATCadEmpSEPARAPED.AsString = 'S' then
                                begin
                                  if (nTotItens >= TotItemPag) OR
                                     (DM.ATCadPd2NUMPED.AsString <> DM.ATCadPd1NUMPED.AsString) then
                                    begin
                                      nTotItens := 0;
                                      nPagAtuNot := nPagAtuNot + 1;
                                    end;
                                end
                              else
                                begin
                                  if (nTotItens >= TotItemPag) OR
                                     (DM.ATCadPd2NUMPRENOT.AsString <> DM.ATCadPd1NUMPRENOT.AsString) then
                                    begin
                                      nTotItens := 0;
                                      nPagAtuNot := nPagAtuNot + 1;
                                    end;
                                end;

                              if nPagAtuNot = 1 then
                                nLinha := nfator+12.8  // 12.8 corresponde a linha na primeira pagina
                              else
                                nLinha := nfator+6.1;  // 6 corresponde a linha nas paginas maiores que 1
                              PrintXY(15,nLinha,DM.ATCadLtpNUMLOTE.AsString);

                              LtQtdeFat := DM.ATCadLtpQTDEFAT.AsVariant;
                              aux := DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString ;

                              // DEVIDO TER LOTES IGUAIS, DE NOTAS DE ENTRADA DIFERENTES.
                              // AS ETIQUETAS SAEM COM "CODSETETQ" DIFERENTES.

                              DM.ATCadLtp.Next;
                              while (DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString = aux) and
                                    (not DM.ATCadLtp.Eof) do
                                begin
                                  LtQtdeFat := LtQtdeFat + DM.ATCadLtpQTDEFAT.AsVariant;
                                  DM.ATCadLtp.Next;
                                end;

                              nTotItens := nTotItens + 1;
                              PrintXY(23.7,nLinha,IntToStr(LtQtdeFat));
                              nFator := nFator + 0.3;
                            end
                          else
                            DM.ATCadLtp.Next;
                        end;
                    end;

                  nTotItens := nTotItens + 1;
                  DM.ATCadPd2.Next;

                  while (DM.ATCadPd2QUANTFAT.AsVariant = 0) and
                        (not DM.ATCadPd2.Eof) do
                    begin
                      DM.ATCadPd2.Next;
                    end;

                  SetFont('Arial',8);
                  if (nTotItens >= TotItemPag) and (not DM.ATCadPd2.Eof) then
                    Begin
                      SetFont('Courier new',7);
                      Bold := True;
                      PrintXY(3.2,17.50,matriz[1]);
                      PrintXY(3.2,17.80,matriz[2]);
                      PrintXY(3.2,18.10,matriz[3]);
                      PrintXY(3.2,18.40,matriz[4]);
                      PrintXY(3.2,18.70,matriz[5]);
                      PrintXY(3.2,19.00,matriz[6]);
                      PrintXY(3.2,19.30,matriz[7]);
                      PrintXY(3.2,19.60,matriz[8]);
                      PrintXY(3.2,19.90,matriz[9]);
                      PrintXY(3.2,20.20,matriz[10]);
                      for y := 1 to 10 do
                        begin
                          matriz[y] := '';
                        end;
                      letras  := '';
                      menspro := '';
                      nTotItens := 0;
                      TotItemPag := 33;     // a partir da segunda pagina...
                      nFator    := 0.3;     // usado para pular linha a cada 0.3 milimetros
                      nPagAtuNot := nPagAtuNot + 1;

                      NewPage;
                      Bitmap := TBitmap.Create;
                      try
                      Bitmap.LoadFromFile('C:\DANFE2.bmp');
                      PrintBitmapRect(0,0,29.7,21,Bitmap);  // imprime imagem bmp do DANFE

                      //Bitmap.LoadFromFile('C:\LOGO.bmp');
                      //PrintBitmapRect(3.2,0.8,6,3.5,Bitmap);  // imprime imagem bmp do LOGO REMED
                      finally
                        FreeAndNil(Bitmap);
                      end;

                      SetFont('Arial',10);
                      Bold := True;
                      PrintXY(3.5,1.1,'CM COMÉRCIO DE MEDICAMENTOS E PERFUMARIAS LTDA'); 
                      SetFont('Arial',6);
                      Bold := False;
                      //PrintXY(3.5,1.5,'Clara Maria A.A.DE L.Com de Med. e Perf-EIREL');
                      PrintXY(3.5,1.5,'MERCANTIL DE MEDICAMENTOS E PERFUMARIAS');
                      //PrintXY(6.5,1.5,'C.N.A.E: 4644-3/01');
                      SetFont('Arial',8);
                      PrintXY(3.5,1.9,'RUA CORAÇÃO DE MARIA, 141');
                      PrintXY(3.5,2.3,'SÃO JOSÉ - RECIFE - PE - CEP:50.020-400');
                      Bold := True;
                      PrintXY(3.5,2.7,'FONES:(81)3224-6653/7665 - FAX:(81)3224-3369');
                      PrintXY(3.5,3.1,'Email: mercantil.medicamentos@outlook.com');
                      //Bold := False;
                      //PrintXY(6.5,3.1,'LIC.VIG.SANITARIA: 3.4.57.0960.002');
                      //Bold := True;
                      //PrintXY(6.5,3.5,'E-Mail: remed@remed.com.br');
                      //Bold := False;

                      SetFont('Arial',8);
                      Bold := False;
                      PrintXY(16.6,2.6,cTipo);
                      PrintBarCode128(RvSystemDANFE,1.2,20.2,DM.ATCadPd1CHAVEDANFE.AsString);
                      PrintXY(15,3.1,DM.ATCadPd1NOTAFISC.AsString);

                      nLinha := 3.1;
                      PrintXY(17.5,nLinha,'Pag: '+FloatToStr(nPagAtuNot)+'/'+FloatToStr(nTotPagNot));
                      PrintXY(15.5,3.66,'0');  // serie da nota

                      FontRotation := 90;
                      PrintXY(2,3.5,DM.ATCadPd1NOTAFISC.AsString);
                      FontRotation := 0;

                      nLinha := 4.5;
                      cNatu := natureza(DM.ATCadPd1NATOPE.AsVariant); // pega descricao do CFOP
                      PrintXY(3.5,nLinha,cNatu);                   // cfop + descricao do cfop
                      if False then
                         PrintXY(18.7,nLinha,'DANFE em contingência, impresso em decorrência de problemas técnicos')
                      else
                         PrintXY(18.7,nLinha,DM.ATCadPd1NUMPROTOC.AsString);  // numero do protocolo

                      nLinha := 5.15;
                      PrintXY(4,nLinha,'0559394-81');
                      PrintXY(14.5,nLinha,'19.454.639/0001-75');

                      SetFont('Arial',5);
                      Bold := True;
                      PrintXY(13.5,6,'NCM/SH');
                      PrintXY(17.15,6,'%Desc');
                      PrintXY(19.5,6,'Subst');
                      SetFont('Arial',8);

                      SetFont('Arial',5);
                      FontRotation := 90;
                      PrintXY(0.8,19.7,'RECEBEMOS DA MERCANTIL DE MEDICAMENTOS E PERFUMARIAS, O(S) PRODUTO(S) CONSTANTE(S) DESTA NOTA FISCAL INDICADA AO LADO');
                      FontRotation := 0;
                      SetFont('Arial',8);

                      PrintXY(8,nLinha,DM.ATCadPd1INSCSUBST.AsString);                     //
                      PrintXY(18.7,nLinha,cChave);

                      nTotItens := 0;
                      nFator    := 0.3;     // usado para pular linha a cada 0.3 milimetros

                      letras  := '';
                      menspro := '';
                    end
                  else if DM.ATCadPd2.Eof then
                    begin
                      SetFont('Courier new',7);
                      Bold := True;
                      PrintXY(3.2,17.50,matriz[1]);
                      PrintXY(3.2,17.80,matriz[2]);
                      PrintXY(3.2,18.10,matriz[3]);
                      PrintXY(3.2,18.40,matriz[4]);
                      PrintXY(3.2,18.70,matriz[5]);
                      PrintXY(3.2,19.00,matriz[6]);
                      PrintXY(3.2,19.30,matriz[7]);
                      PrintXY(3.2,19.60,matriz[8]);
                      PrintXY(3.2,19.90,matriz[9]);
                      PrintXY(3.2,20.20,matriz[10]);
                      for y := 1 to 10 do
                        begin
                          matriz[y] := '';
                        end;
                    end;
                end
              else
                DM.ATCadPd2.Next;
            end;

            if nfCorrecao then  // nf de correcao
              begin
                SetFont('Courier new',7);
                Bold := True;
                PrintXY(3.2,17.50,matriz[1]);  // mensagem2
                PrintXY(3.2,17.80,matriz[2]);  // mensagem3
                PrintXY(3.2,18.10,matriz[3]);  // mensagem4
                PrintXY(3.2,18.40,matriz[4]);  // mensagem5
                for y := 1 to 10 do
                  begin
                    matriz[y] := '';
                  end;
              end;

            cNotaFin := copy(DM.ATCadPd1NOTAFISC.AsString,4,6);
            DM.ATCadPd1.Next;
            if (not DM.ATCadPd1.Eof) then
              NewPage;
        end;
    end;

    if cNotaIni = cNotaFin then
      begin

        if DirectoryExists('c:\NFCe em Dephi xe5\') then
          RvSystemDANFE.OutputFileName := 'c:\DATANET\PDF\'+cNotaIni+'.PDF';

        if DirectoryExists('f:\datanet') then
          RvSystemDANFE.OutputFileName := 'f:\DATANET\PDF\'+cNotaIni+'.PDF';

        if DirectoryExists('g:\datanet') then
          RvSystemDANFE.OutputFileName := 'g:\DATANET\PDF\'+cNotaIni+'.PDF';
      end
    else
      begin
        if DirectoryExists('c:\NFCe em Dephi xe5\') then
          RvSystemDANFE.OutputFileName := 'c:\DATANET\PDF\'+cNotaIni+' A '+cNotaFin+'.PDF';

        if DirectoryExists('f:\datanet') then
          RvSystemDANFE.OutputFileName := 'f:\DATANET\PDF\'+cNotaIni+' A '+cNotaFin+'.PDF';

        if DirectoryExists('g:\datanet') then
          RvSystemDANFE.OutputFileName := 'g:\DATANET\PDF\'+cNotaIni+' A '+cNotaFin+'.PDF';
      end;
    
    DM.ATCadPd1.DisableControls;
    DM.ATCadPd2.DisableControls;

end;

function TFormEnviaImprime.natureza(nNatope: Real): string;
var
  natu,natu2:string;
begin
natu := FloatToStr(nNatope);
natu := copy(natu,1,1)+'.'+copy(natu,3,3);
if Pos(natu,'5.102,6.102,6.108,5.114,6.114,5.115,6.115') > 0 then
  natu2 := natu+' - VENDA DE MERCADORIA'
else if Pos(natu,'5.152,6.152') > 0 then
  natu2 := natu+' - TRANSFERENCIA'
else if Pos(natu,'5.929,6.929') > 0 then
  natu2 := natu+' - LNC.DEC.CUP.FIS'
else if Pos(natu,'1.202,2.202,5.202,6.202,1.411,2.411,5,411.6,411') > 0 then
  natu2 := natu+' - DEVOLUCAO'
else if Pos(natu,'1.102,2.102') > 0 then
  natu2 := natu+' - COMP.P/COMERCIALIZACAO'
else if Pos(natu,'1.551,2.551') > 0 then
  natu2 := natu+' - COMPR. ATIVO'
else if Pos(natu,'1.553,2.553') > 0 then
  natu2 := natu+' - DEVOL. ATIVO'
else if Pos(natu,'5.551,6.551') > 0 then
  natu2 := natu+' - VENDA ATIVO'
else if Pos(natu,'1.551,2.551') > 0 then
  natu2 := natu+' - COMP.ATIVO'
else if Pos(natu,'5.551,6.551') > 0 then
  natu2 := natu+' - VENDA ATIVO'
else if Pos(natu,'1.113,2.113') > 0 then
  natu2 := natu+' - COMP.P/COMERC.RECEBIDA EM CONSIGNACAO'
else if Pos(natu,'1.910,2.910') > 0 then
  natu2 := natu+' - ENTRADA BONIFICACAO, DOACAO OU BRINDE'
else if Pos(natu,'1.911,2.911') > 0 then
  natu2 := natu+' - ENTRADA AMOSTRA GRATIS'
else if Pos(natu,'1.912,2.912') > 0 then
  natu2 := natu+' - ENT.MER.REM.P/DEMOS'
else if Pos(natu,'1.913,2.913') > 0 then
  natu2 := natu+' - RET.MER.REM.P/DEMOS'
else if Pos(natu,'1.914,2.914') > 0 then
  natu2 := natu+' - RET.MER.REM.P/EXPOS'
else if Pos(natu,'1.915,2.915') > 0 then
  natu2 := natu+' - RET.MER.REM.P/CONSE'
else if Pos(natu,'1.917,2.917') > 0 then
  natu2 := natu+' - ENT.MER.REC.EM CONSIG'
else if Pos(natu,'1.918,2.918') > 0 then
  natu2 := natu+' - DEV.MER.REM.EM CONSIG'
else if Pos(natu,'1.926,2.926') > 0 then
  natu2 := natu+' - RECL.DE MERC/KIT/DES.'
else if Pos(natu,'1.949,2.949') > 0 then
  natu2 := natu+' - OUTRAS ENTRADAS'
else if Pos(natu,'5.102,6.102,6.108') > 0 then
  natu2 := natu+' - VENDA MERCADORIA'
else if Pos(natu,'5.114,6.114') > 0 then
  natu2 := natu+' - VDA.MERC.REM.ANT.EM CONS.'
else if Pos(natu,'5.115,6.115') > 0 then
  natu2 := natu+' - VDA.MERC.REC.ANT.EM CONS.'
else if Pos(natu,'5.152,6.152') > 0 then
  natu2 := natu+' - TRANSFERENCIA DE MERCADORIA'
else if Pos(natu,'5.415,6.415') > 0 then
  natu2 := natu+' - REM.MER.VEND.FORA ESTA'
else if Pos(natu,'5.403,6.403') > 0 then
  natu2 := natu+' - VDA.MERC.SUB.TRIB.'
else if Pos(natu,'5.556,6.556') > 0 then
  natu2 := natu+' - DEV.COM.P/COMER'
else if Pos(natu,'5.910,6.910') > 0 then
  natu2 := natu+' - REM.BON.DOAC/BRINDE'
else if Pos(natu,'5.911,6.911') > 0 then
  natu2 := natu+' - REM.AMOSTRA GRATIS'
else if Pos(natu,'5.912,6.912') > 0 then
  natu2 := natu+' - REM.P/DEMOSTR.'
else if Pos(natu,'5.914,6.914') > 0 then
  natu2 := natu+' - REM.P/EXPOS OU FEIRA'
else if Pos(natu,'5.915,6.915') > 0 then
  natu2 := natu+' - REM.P/CONSERTO'
else if Pos(natu,'5.917,6.917') > 0 then
  natu2 := natu+' - REM.EM CONSIG.MERC.'
else if Pos(natu,'5.918,6.918') > 0 then
  natu2 := natu+' - DEV.MER.REC.EM CONSIG.'
else if Pos(natu,'5.926,6.926') > 0 then
  natu2 := natu+' - RECL.DE MERC/KIT/DES.'
else if Pos(natu,'5.927,6.927') > 0 then
  natu2 := natu+' - PERDA/ROUBO OU DETER.'
else if Pos(natu,'5.554,6.554') > 0 then
  natu2 := natu+' - REM.BEM.AT.IMOB.F.E'
else if Pos(natu,'5.551,6.551') > 0 then
  natu2 := natu+' - VENDA ATIVO IMOBILIZ.'
else if Pos(natu,'5.949,6.949') > 0 then
  natu2 := natu+' - OUTRAS SAIDAS';

  natureza := natu2
end;

procedure TFormEnviaImprime.PrintBarcode128(RVSystem: TRVSystem; Row,
  Column: Double; Value: String);
begin
   With TRPBarsCode128.Create(RVSystem.BaseReport) do Begin
     BarHeight  := 2;
     BarWidth   := 0.03; //0.030;
     Text := Value;
     PrintReadable := False;
     PrintXY(Column,Row);
     Free;
   end;
end;

function TFormEnviaImprime.somaitens: integer;
var nTotPag,itens,TotItemPag:integer;
    aux:string;
begin
  itens := 0;
  TotItemPag := 10;     // a primeira pagina
  nTotPag := 1;
  DM.ATCadPd2.GoTop;
  while not DM.ATCadPd2.Eof do
    begin
      if (DM.ATCadPd2QUANTFAT.Value > 0) then
        begin
          itens := itens + 1;

          DM.ATCadLtp.SetOrder(2);
          DM.ATCadLtp.Seek(DM.ATCadPd1NUMPED.AsString+DM.ATCadPd2CODPRO.AsString);
          if DM.ATCadLtp.Found then
            begin
              while (DM.ATCadPd1NUMPED.AsString+DM.ATCadPd2CODPRO.AsString =
                     DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString) and
                     (not DM.ATCadLtp.Eof) do
                begin
                  itens := itens + 1;

                  aux := DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString;

                  // DEVIDO TER LOTES IGUAIS, DE NOTAS DE ENTRADA DIFERENTES.
                  // AS ETIQUETAS SAEM COM "CODSETETQ" DIFERENTES, MAIS COM O MESMO LT.
                  // SOMA TOTAL DE ITENS SOMENTE UMA VEZ

                  DM.ATCadLtp.Next;
                  WHILE (DM.ATCadLtpNUMPED.AsString+DM.ATCadLtpCODPRO.AsString+DM.ATCadLtpNUMLOTE.AsString = aux) and
                        (not DM.ATCadLtp.Eof) do
                    begin
                      DM.ATCadLtp.Next;
                    end;
                end;
                // subtrai devido o prim. lote sair na mesma linha
                itens := itens - 1;
            end;
        end;

      DM.ATCadPd2.Next;
      while (DM.ATCadPd2QUANTFAT.AsVariant = 0) and
            (not DM.ATCadPd2.Eof) do
        begin
          DM.ATCadPd2.Next;
        end;
      if (Itens >= TotItemPag) and (not DM.ATCadPd2.Eof) then
        begin
          Itens := 0;
          TotItemPag := 33;     // a partir da segunda pagina...
          nTotPag := nTotPag + 1;
        end;
    end;
    result := nTotPag;
end;

function TFormEnviaImprime.formatacnpj(Cnpj: String): string;
begin
  Result := Copy(Cnpj,1,2)+'.'+Copy(Cnpj,3,3)+'.'+Copy(Cnpj,6,3)+'/'+
  Copy(Cnpj,9,4)+'-'+Copy(Cnpj,13,2);
end;

function TFormEnviaImprime.formatainsc(insc, uf: String): string;
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
  Result := Copy(insc,6,2)+'.'+Copy(insc,8,3)+'.'+Copy(insc,11,3)+'-'+Copy(insc,14,1)
  //99.999.999-9
 ELSE IF Pos(uf,'SC') > 0 then
  Result := Copy(insc,1,3)+'.'+Copy(insc,4,3)+'.'+Copy(insc,7,3)
  //999.999.999
 ELSE
  Result := Copy(insc,1,14);
  //99999999999999
end;

function TFormEnviaImprime.recebetotaisnota(mens: string): string;
var y:integer;
begin
 for y := 1 to 10 do
   begin
     if matriz[y] = '' then
       begin
         matriz[y] := mens;
         exit;
       end;
   end;
end;

function TFormEnviaImprime.recebemenspro(mens: string): string;
var y:integer;
begin
 for y := 1 to 10 do
   begin
     if matriz[y] = '' then
       begin
         IF mens = 'A' Then
           begin
             matriz[y] := '(A)-'+DM.ATCadEm2MENSPRO_A.AsString;
             exit;
           end;

         IF mens = 'B' Then
           begin
             matriz[y] := '(B)-'+DM.ATCadEm2MENSPRO_B.AsString;
             exit;
           end;

         IF mens = 'C' Then
           begin
             matriz[y] := '(C)-'+DM.ATCadEm2MENSPRO_C.AsString;
             exit;
           end;

         IF mens = 'D' Then
           begin
             matriz[y] := '(D)-'+DM.ATCadEm2MENSPRO_D.AsString;
             exit;
           end;

         IF mens = 'E' Then
           begin
             matriz[y] := '(E)-'+DM.ATCadEm2MENSPRO_E.AsString;
             exit;
           end;

         IF mens = 'F' Then
           begin
             matriz[y] := '(F)-'+DM.ATCadEm2MENSPRO_F.AsString;
             exit;
           end;

         IF mens = 'G' Then
           begin
             matriz[y] := '(G)-'+DM.ATCadEm2MENSPRO_G.AsString;
             exit;
           end;

         IF mens = 'H' Then
           begin
             matriz[y] := '(H)-'+DM.ATCadEm2MENSPRO_H.AsString;
             exit;
           end;

         IF mens = 'I' Then
           begin
             matriz[y] := '(I)-'+DM.ATCadEm2MENSPRO_I.AsString;
             exit;
           end;
       end
     else
        if mens = matriz[y] then
          exit;
   end;
end;

procedure TFormEnviaImprime.ReemiteNFe1Click(Sender: TObject);
begin
  if dm.ATCadPd1NUMPROTOC.AsString <> '' then
    begin
      dm.ATCadPd1.Edit;
      dm.ATCadPd1IMPDANFE.AsString := '';
      dm.ATCadPd1.Post;

      ckbAutorizados.Checked := False;
      ckbImpresso.Checked    := False;

      ckbProcessamento.Checked := true;
      DBGrid1Enter(Sender);  // filtra somentes a reemissoes
      DBGrid1.SetFocus;
    end;
end;

end.
