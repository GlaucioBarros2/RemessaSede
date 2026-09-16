#include "SIXNSX.CH"
#include "MACHSIX.CH"

SET CONF ON
SET WRAP ON
SET EPOCH TO 1960
SET DATE FRENC
SET DELE ON
CLS
enter   := ". Tecle [ENTER]"

centra("Selecione o Banco Desejado ")
@ 02,08 TO 06,58
@ 03,10 PROM " BANCO ITAU SA                                  "
@ 04,10 PROM " BANCO SAFRA SA                                 "
@ 05,10 PROM " BANCO DO BRASIL                                "
MENU TO opcaoB
if opcaoB== 0
   CLS ; RETURN
ENDIF

cls
cBanco1 := if(opcaob=1,"341",if(opcaob=2,"422","001"))
cBanco2 := if(opcaob=1,"BANCO ITAU SA                 ",;
           if(opcaob=2,"BANCO SAFRA SA                ","BANCO DO BRASIL               "))

@ 00,25 say cbanco2

SET MESSAGE TO 01 center

centra("Informe o codigo de movimento para a remessa")
@ 02,08 TO 14,58
@ 03,10 PROM "01 - Entrada de titulos                         " message "01 - Entrada de titulos"
@ 04,10 PROM "02 - Pedido de Baixa                            " message "02 - Pedido de Baixa"
@ 05,10 PROM "04 - Concessao de abatimento                    " message "04 - Concessao de abatimento"
@ 06,10 PROM "05 - Cancelamento de abatimento                 " message "05 - Cancelamento de abatimento"
@ 07,10 PROM "06 - Alteracao de vencimento                    " message "06 - Alteracao de vencimento"
@ 08,10 PROM "07 - Concessao de desconto                      " message "07 - Concessao de desconto"
@ 09,10 PROM "08 - Cancelamento de desconto                   " message "08 - Cancelamento de desconto"
@ 10,10 PROM "09 - Protestar                                  " message "09 - Protestar"
@ 11,10 PROM "10 - Cancelar/Sustacao da instrucao de protesto " message "10 - Cancelar/Sustacao da instrucao de protesto"
@ 12,10 PROM "30 - Recusa da alegacao do sacado               " message "30 - Recusa da alegacao do sacado"
@ 13,10 PROM "31 - Alteracao de outros dados                  " message "31 - Alteracao de outros dados"
MENU TO opcao
if opcao == 0
   CLS ; RETURN
ENDIF
cCodMov := if(opcao==1,"01",;
           if(opcao==2,"02",;
           if(opcao==3,"04",;
           if(opcao==4,"05",;
           if(opcao==5,"06",;
           if(opcao==6,"07",;
           if(opcao==7,"08",;
           if(opcao==8,"09",;
           if(opcao==9,"10",;
           if(opcao==10,"30","31"))))))))))

ccodmovaux := ccodmov

USE SACADEMP.DBF ALIAS EMP NEW SHARED
centra("Informe o periodo para remessa")

IF ! FILE("datas.DBF")
  astru := { ;
         {"ENTINI    ","D",8,0},;
         {"ENTFIN    ","D",8,0},;
         {"PROTFIN   ","D",8,0},;
         {"PROTFIN   ","D",8,0},;
         {"BAIXAINI  ","D",8,0},;
         {"BAIXAFIN  ","D",8,0} }
  DBCREATE("datas.DBF",astru)
ENDIF
USE datas.DBF ALIAS dat NEW

datini   := EMP->DTULTENV+1
datfin   := EMP->DTDIAFAT-1

if datini > datfin
  datini   := EMP->DTDIAFAT
  datfin   := EMP->DTDIAFAT
end

ddataatu := DATE()

cBaixa := .f.
if opcao = 2  //pedido de baixa
  datini := dat->baixafin
  datfin := date()
  nQtdeDias := 0
  
  IF CONFIRMA("Pedido de baixa dos vencidos a N dias (S/N) ?"," ")
    @ 15,10 say "Qtde Dias: " GET nQtdeDias pict "999" valid nQtdeDias > 0
	read
	datini := ctod("01/01/2017")
	datfin := date() - nQtdeDias
  else 
    IF CONFIRMA("Pedido de baixa pela data da baixa (S/N) ?"," ")
      cBaixa := .t.
      @ 15,10 say "Data Base .....:" GET ddataatu
      @ 17,10 say "Baixa Inicial:" GET datini VALID ! EMPTY(DATINI)
      @ 17,40 say "Baixa Final..:" get datfin VALID datfin >= datini
    else
      @ 15,10 say "Data Base .....:" GET ddataatu
      @ 17,10 say "Emissao Inicial:" GET datini VALID ! EMPTY(DATINI)
      @ 17,40 say "Emissao Final..:" get datfin VALID datfin >= datini
    endif
    read
  endif
else
  @ 15,10 say "Data Base .....:" GET ddataatu
  @ 17,10 say "Emissao Inicial:" GET datini VALID ! EMPTY(DATINI)
  @ 17,40 say "Emissao Final..:" get datfin VALID datfin >= datini

  if cCodMov $ "01"  // Entrada de Titulos
    datVini := date()
    datVfin := ctod("  /  /  ")
    @ 19,10 say "Vencto Inicial:" GET datVini VALID ! EMPTY(datVini)
    @ 19,40 say "Vencto Final..:" get datVfin 
  endif
  read

endif

IF empty(datVfin)
  datVfin := ctod("31/12/2099")
endif

IF LASTKEY() == 27
  cls ; RETURN
ELSEIF EMPTY(datini) .OR. EMPTY(datfin)
  MENSAGEM("Data invalida.."+enter)
  RETURN
ELSEIF (EMPTY(DATVINI) .OR. EMPTY(DATVFIN) .or. datVfin < datVini)
  MENSAGEM("Data invalida.."+enter)
  RETURN
ENDIF

EMP->(rlock())
EMP->DTULTENV := datFIN
EMP->(dbunlock())

centra("Aguarde...")
USE SACADDAT ALIAS DAT2               NEW SHARE
USE SACADSET ALIAS SET INDEX SAINDSET NEW SHARE
USE SACADCLI ALIAS CLI INDEX SAINDCLI NEW SHARE
USE SACADTIT ALIAS TIT INDEX SAINDTIT NEW SHARE

SET RELATION TO CODCLI INTO CLI, TO CODSET INTO SET
dbsetorder(1)

copy stru to remestit.aux
use remestit.aux alias aux new
//index on aux->nummov to indaux
index on dtos(aux->dtvenclim) to indaux

if cCodMov $ "01"  // Entrada de Titulos
  tit->(dbsetorder(10),dbseek(datini,.t.))   // DTEMISS
  while tit->dtemiss <= datfin .and. tit->(! eof())
    if (TIT->DTEMISS >= datini .and. TIT->DTEMISS <= datfin) .AND.;
       (tit->DTVENCLIM >= datVini .and. tit->DTVENCLIM <= datVfin) .and.;
       (tit->sittit $ "AB") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
       (cli->remess $ "S ") .and. (tit->tipodoc$"DP,DC,OR") .and. (TIT->CODPOR = cBanco1) .and.;
       (("Entr Rejeit"$tit->retbanco) .or. empty(tit->retbanco))
	   
      GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
    ENDIF
    TIT->(DBSKIP())
  enddo
elseif cCodMov $ "09"  // protestar
  cTipoRem := "Entr Confirm ,"+;
              "Conf Abatim. ,"+;
              "Conf Can Abat,"+;
              "Conf Vencto  ,"+;
              "canc. Prot.  ,"+;
              "Retir.cart   ,"+;
              "Prot baixado ,"+;
              "Instr rejeit ,"+;
              "Alt dos dados,"+;
              "Deb tarifas  ,"+;
              "Ocorr sacado ,"+;
              "Alt. dados   "
  tit->(dbsetorder(10),dbseek(datini,.t.))   // DTEMISS
  while tit->dtemiss <= datfin .and. tit->(! eof())
    IF (TIT->DTEMISS >= datini .and. TIT->DTEMISS <= datfin) .AND.;
      (tit->sittit $ "AB") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
      (cli->remess $ "S ") .and. (TIT->CODPOR = cBanco1) .and. ;
      ((ddataatu-TIT->DTVENCLIM)>=cli->diasprot) .and.;
      (tit->tipodoc$"DP,DC,OR") .and.;
      (left(tit->retbanco,13) $ cTipoRem)
	   
      GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
    ENDIF
    TIT->(DBSKIP())
  enddo
elseif cCodMov $ "02"  // pedido de baixa
  cTipoRem := "Baixa        ,"+;
              "Liquidacao   "
			  
  if nQtdeDias > 0
    cTipoRem := "Entr Rejeit  "
    tit->(dbsetorder(2),dbseek(dtos(datini),.t.))   // vencimento
    while tit->DTVENCLIM <= datfin .and. tit->(! eof())
      IF (TIT->DTVENCLIM >= datini .and. TIT->DTVENCLIM <= datfin) .AND.;
        (tit->sittit $ "AB") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
        (TIT->CODPOR = cBanco1) .and. ;
        (tit->tipodoc$"DP,DC,OR") .and.(!empty(tit->retbanco)).and.;
                                    (!left(tit->retbanco,13)$cTipoRem)
	   
        GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
      ENDIF
      TIT->(DBSKIP())
    enddo
  else
    if cBaixa
      tit->(dbsetorder(15),dbseek(dtos(datini),.t.))   // DTbaixa
      while tit->dtbaixa <= datfin .and. tit->(! eof())
        IF (TIT->DTbaixa >= datini .and. TIT->DTbaixa <= datfin) .AND.;
          (!tit->sittit $ "BB") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
          (TIT->CODPOR = cBanco1) .and. ;
          (tit->tipodoc$"DP,DC,OR") .and.(!empty(tit->retbanco)).and.;
          (!left(tit->retbanco,13)$cTipoRem)
	   
          GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
        ENDIF
        TIT->(DBSKIP())
      enddo
  	
      // ENVIAR TAMBEM OS CANCELADOS
  	tit->(dbsetorder(3),dbseek(dtos(datini),.t.))   // DTpagto
      while tit->DTpagto <= datfin .and. tit->(! eof())
        IF (TIT->DTpagto >= datini .and. TIT->DTpagto <= datfin) .AND.;
           (tit->sittit $ "CA") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
           (cli->remess $ "S ") .and. (TIT->CODPOR = cBanco1) .and. ;
          (tit->tipodoc$"DP,DC,OR") .and.(!empty(tit->retbanco)).and.;
          (!left(tit->retbanco,13)$cTipoRem)
	   
          GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
        ENDIF
        TIT->(DBSKIP())
      enddo
  	
      dat->baixaini := datini
      dat->baixafin := datfin
    else
      tit->(dbsetorder(10),dbseek(datini,.t.))   // DTEMISS
      while tit->dtemiss <= datfin .and. tit->(! eof())
        IF (TIT->DTemiss >= datini .and. TIT->DTemiss <= datfin) .AND.;
          (!tit->sittit $ "BB,BC") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
          (cli->remess $ "S ") .and. (TIT->CODPOR = cBanco1) .and. ;
          (tit->tipodoc $ "DP,DC") .and.(!empty(tit->retbanco)).and.;
          (!left(tit->retbanco,13)$cTipoRem)
	   
          GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
        ENDIF
        TIT->(DBSKIP())
      enddo
    endif
  endif
else  // outros
  cTipoRem := "Entr Confirm "
  tit->(dbsetorder(10),dbseek(datini,.t.))   // DTEMISS
  while tit->dtemiss <= datfin .and. tit->(! eof())
    IF (TIT->DTEMISS >= datini .and. TIT->DTEMISS <= datfin) .AND.;
      (!tit->sittit $ "PC,BB,PB,BC,CA") .AND. (!EMPTY(TIT->NOSSONUM)).and.;
      (cli->remess $ "S ") .and. (TIT->CODPOR = cBanco1) .and. ;
      (tit->tipodoc$"DP,DC,OR") .and.;
      (! "Entr Rejeit" $ tit->retbanco) .and.;
      (!empty(tit->retbanco))
	   
      GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
	  
    ENDIF
    TIT->(DBSKIP())
  enddo
endif

SELECT AUX
DBGOTOP()
IF EOF()
  mensagem("Nao ha titulos a transmitir."+enter)
  CLS
  RETURN
ENDIF

AUX->( DBCOMMIT() )
AUX->( DBGOTOP() )

TONE(900,1)
@ 22,02 CLEAR TO 22,74
CENTRA("Desmarcando os rejeitados. [Aguarde]")
//
AUX->( DBGOTOP() )
WHILE AUX->( !EOF() )
  IF ("Entr Rejeit"$aux->retbanco) .and. AUX->( RLOCK() )
    AUX->marca := " "
    AUX->( DBUNLOCK() )
  ENDIF
  AUX->( DBSKIP() )
END
//
AUX->( DBCOMMIT() )
AUX->( DBGOTOP() )
//
SET RELATION TO CODCLI INTO CLI, TO CODSET INTO SET
set->(dbsetorder(1))

DECLARE cab[14],cam[14],mas[14]

cab[1] := "M"
cab[2] := "Retorno do banco"
cab[3] := "Data;Emissao"
cab[4] := "Data;Vencto."
cab[5] := "Gerados (O-Opcoes)"
cab[6] := "St"
cab[7] := "No  Titulo"
cab[8] := "Tp"
cab[9] := "Data;Baixa"
cab[10] := "Vendedor"
cab[11] := "Cliente"
cab[12]:= "Valor"
cab[13]:= "No Bloq no Bco"
cab[14]:= "No Ped"
cam[1] := "AUX->MARCA"
cam[2] := "AUX->RETBANCO"
cam[3] := "AUX->DTEMISS"
cam[4] := "AUX->DTVENCLIM"
cam[5] := "AUX->FLAG01+'-'+AUX->FLAG02+'-'+AUX->FLAG04+'-'+AUX->FLAG05+'-'+AUX->FLAG06+'-'+AUX->FLAG07+'-'+AUX->FLAG08+'-'+AUX->FLAG09+'-'+AUX->FLAG10+'-'+AUX->FLAG30+'-'+AUX->FLAG31"
cam[6] := "AUX->SITTIT"
cam[7] := "AUX->NUMMOV"
cam[8] := "AUX->TIPODOC"
cam[9] := "AUX->DTBAIXA"
cam[10] := "AUX->CODSET+'-'+LEFT(SET->NOMSET,10)"
cam[11] := "AUX->CODCLI+'-'+LEFT(CLI->RAZSOCCLI,17)"
cam[12]:= "AUX->VALBRUTO"
cam[13]:= "AUX->NOSSONUM"
cam[14]:= "AUX->NUMPED"
AFILL(mas,"")
mas[7] := "@R 999999-9/9"   
mas[12]:= "@E 999,999.99"   

cNumMov := space(8)
//
TONE(900,1)  ;  TONE(900,1)
SCROLL(03,00,21,79,0) ; DISPBOX(03,00,21,79,"ÜÄÜÞßÄßÝ")
CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
//
CLI->( DBSETORDER(1) )
//
SELECT AUX
GO TOP
//
DBEDIT(04,01,19,78,cam,"DBCONFCLI",mas,cab,"ÂÄ","³","ÏÍ")
//
SET FILTER TO
SET RELATION TO
//
CLS
RETURN
*
**
FUNCTION DBCONFCLI(modo,pont)
*****************************

SELECT AUX
SETCURSOR(0)

IF modo = 1 .OR. modo = 2   ;   TONE(700,1)  ;   ENDIF
//
*IF LASTKEY() == 19           // seta esq
*  KEYBOARD CHR(26)           // seta ctrl <-   devido barra iluminada
*ELSEIF LASTKEY() == 4        // seta dir
*  KEYBOARD CHR(2)            // seta ctrl ->
//
IF CHR(LASTKEY()) $ "Dd"    // Desmarcar Todos
  IF CONFIRMA("Confirma Desmarcacao de Todos (S/N) ?"," ")
    TONE(900,1)
    @ 22,02 CLEAR TO 22,74
    CENTRA("Desmarcando todos os titulos. [Aguarde]")
    //
    AUX->( DBGOTOP() )
    WHILE AUX->( !EOF() )
      IF AUX->( RLOCK() )
        AUX->marca := " "
        AUX->( DBUNLOCK() )

        TIT->(DBSETORDER(1),DBSEEK(AUX->nummov+aux->tipodoc+aux->codcli))
        TIT->(rlock())
        TIT->MARCA := AUX->MARCA
        TIT->(dbunlock())

      ENDIF
      AUX->( DBSKIP() )
    END
    //
    AUX->( DBCOMMIT() )
    AUX->( DBGOTOP() )
    //
    KEYBOARD CHR(26)
    TONE(900,1)
    CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
    RETURN(2)
  ENDIF
  CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
  KEYBOARD CHR(26)
//
ELSEIF CHR(LASTKEY()) $ "Tt"    // Marcar Todos
  IF CONFIRMA("Confirma Marcacao de Todos (S/N) ?"," ")
    TONE(900,1)
    @ 22,02 CLEAR TO 22,74
    CENTRA("Marcando todos os titulos. [Aguarde]")
    //
    AUX->( DBGOTOP() )
    WHILE AUX->( !EOF() )
	  IF EMPTY(AUX->RETBANCO)
        CLI->(DBSETORDER(1),DBSEEK(AUX->CODCLI))
        AUX->( RLOCK() )
        AUX->marca := "*"
        AUX->( DBUNLOCK() )
      ENDIF
	  AUX->( DBSKIP() )

      TIT->(DBSETORDER(1),DBSEEK(AUX->nummov+aux->tipodoc+aux->codcli))
      TIT->(rlock())
      TIT->MARCA := AUX->MARCA
      TIT->(dbunlock())

    END
    //
    AUX->( DBCOMMIT() )
    AUX->( DBGOTOP() )
    //
    KEYBOARD CHR(26)
    TONE(900,1)
    CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
    RETURN(2)
  ENDIF
  CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
  KEYBOARD CHR(26)
//
ELSEIF CHR(LASTKEY()) $ "Mm"    // Marcar/Descmarca
  IF AUX->( RLOCK() )
    IF !empty(AUX->MARCA)
      AUX->MARCA := " "
    ELSE
      AUX->MARCA := "*"
    ENDIF
    AUX->( DBUNLOCK() )
    AUX->( DBCOMMIT() )

    TIT->(DBSETORDER(1),DBSEEK(AUX->nummov+aux->tipodoc+aux->codcli))
    TIT->(rlock())
    TIT->MARCA := AUX->MARCA
    TIT->(dbunlock())

  ENDIF
  //
  TONE(900,1)
  KEYBOARD CHR(24)           // Proximo Item
  RETURN(2)
ELSEIF chr(LASTKEY()) $ "pP"
   telaaux := SAVESCREEN(16,00,23,79)
   SETCURSOR(1)
   @ 20,68 to 22,79
   @ 20,70 say "Titulo"
   @ 21,69 get cNumMov pict "@r 999999-9/9"
   read
   SETCURSOR(0)
   @ 20,68 clear to 22,79
   if ! empty(cNumMov)
     nRecno := aux->(recno())
     cNota2 := strzero(val(cNumMov),8)
     if ! aux->(dbseek(cNota2))
       @ 24,00
       @ 24,00 say "Titulo &cNota2. inexistente. tecle enter" color "W*/N" ; inkey(0)
       go nrecno
       RESTSCREEN(16,00,23,79,telaaux)
       return(1)
     endif
     RESTSCREEN(16,00,23,79,telaaux)
     return(2)
   endif
   RESTSCREEN(16,00,23,79,telaaux)
ELSEIF LASTKEY() == -2       // F3 GERAR ARQUIVO
  CENTRA("[Aguarde] Selecionando titulos para geracao")
  COUNT TO nMARCAs FOR !empty(AUX->marca)
  AUX->( DBGOTOP() )
  IF nMARCAs < 1
    MENSAGEM("Nao ha titulos selecionados"+enter,,.T.)
    KEYBOARD CHR(26)
    AUX->( DBGOTOp() )
    CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
    RETURN(1)
  ENDIF
  //
  select AUX
  GO TOP

  GER_ARQUIVO()   // GERA ARQUIVO DE REMESSA

  KEYBOARD CHR(26)
  RETURN(2)
//
ELSEIF CHR(LASTKEY()) $ "Oo"    // Opcoes

  @ 04,08 CLEAR TO 16,58
  @ 04,08 TO 16,58
  @ 05,10 SAY "01 - Entrada de titulos"
  @ 06,10 SAY "02 - Pedido de Baixa"
  @ 07,10 SAY "04 - Concessao de abatimento"
  @ 08,10 SAY "05 - Cancelamento de abatimento"
  @ 09,10 SAY "06 - Alteracao de vencimento"
  @ 10,10 SAY "07 - Concessao de desconto"
  @ 11,10 SAY "08 - Cancelamento de desconto"
  @ 12,10 SAY "09 - Protestar"
  @ 13,10 SAY "10 - Cancelar/Sustacao da instrucao de protesto"
  @ 14,10 SAY "30 - Recusa da alegacao do sacado"
  @ 15,10 SAY "31 - Alteracao de outros dados"
  INKEY(0)
  KEYBOARD CHR(26)
  TONE(900,1)
  CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
  RETURN(2)
//
ELSEIF LASTKEY() == 27                          // RETORNA
  RETURN(0)
ENDIF
RETURN(1)
*
**
FUNCTION GER_ARQUIVO()
*********************
CENTRA("[Aguarde] Gerando arquivo REMESSA.")
TONE(600,1) ; TONE(800,1)

astru := { ;
         {"REGREMES ","C",240,0} }
DBCREATE("ARQ_REM.DBF",astru)
USE ARQ_REM.DBF ALIAS ARQ NEW

// este for abaixo e devido existir 2 convenios, ou seja, dois nosso numero.
// entao deve ser enviado dois arquivos separados...
for xx := 1 to 1

select arq
zap

if cBanco1 == "001"
  cConv := "1406478"    // bb
  cAgen := "028118"
  cCont := "0000001145460"
elseif cBanco1 == "341"
  cConv := space(7)  // "0127845"    // itau
  cAgen := "08322 "
  cCont := "000000011901 "
else
  // Dados reais do convenio Safra (agencia 0144, conta 00587488-9).
  // Larguras conforme manual "Cobranca Safra - Layout Padrao Safra CNAB
  // 240": agencia 5 digitos, conta 12 digitos, DV 1 digito.
  cAgenSaf   := "00144"          // agencia (5 digitos)
  cContSaf   := "000000587488"   // conta corrente (12 digitos)
  cContDVSaf := "9"              // digito verificador da conta corrente
endif

// header de arquivo - registro 0
if cBanco1 = "001"
  mregrem := cBanco1+;
             "0000"+;
             "0"+;
             space(9)+;
             "2"+;
             "40868234000170"+;
             "00"+cConv+"001417027  "+;
             cAgen+;
             cCont+;
             " "+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             cBanco2+;
             space(10)+;
             "1"+;
             SUBST(DTOC(ddataatu),1,2)+;
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             SUBST(TIME(),1,2)+;
             SUBST(TIME(),4,2)+;
             SUBST(TIME(),7,2)+;
             "000001"+;
             "030"+;
             "00000"+;
             SPACE(20)+;
             SPACE(20)+;
             SPACE(11)+;
             if(cBanco1="001","CSP",space(3))+;
             "000"+;
             SPACE(2)+;
             SPACE(10)
elseif cBanco1 = "341"
  mregrem := cBanco1+;
             "0000"+;
             "0"+;
             space(9)+;
             "2"+;
             "40868234000170"+;
             space(20)+;
             cAgen+;
             cCont+;
             "0"+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             cBanco2+;
             space(10)+;
             "1"+;
             SUBST(DTOC(ddataatu),1,2)+;
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             SUBST(TIME(),1,2)+;
             SUBST(TIME(),4,2)+;
             SUBST(TIME(),7,2)+;
             "000001"+;
             "040"+;
             "00000"+;
             SPACE(54)+;
             "000"+;
             SPACE(12)
else  // SAFRA (422) - layout conforme manual "Cobranca Safra - Layout Padrao
      // Safra CNAB 240" (Header de Arquivo, pag. 5-6)
  mregrem := cBanco1+;                          // 001-003 Banco = 422
             "0000"+;                           // 004-007 Lote de servico
             "0"+;                              // 008     Tipo de registro = 0
             space(9)+;                         // 009-017 Uso exclusivo - brancos
             "2"+;                              // 018     Tipo insc. empresa = 2 (CNPJ)
             "40868234000170"+;                 // 019-032 CNPJ da empresa
             space(20)+;                        // 033-052 Convenio - Safra nao trata
             cAgenSaf+;                         // 053-057 Agencia mantenedora da conta
             " "+;                              // 058     DV agencia - em branco
             cContSaf+;                         // 059-070 Numero da conta corrente
             cContDVSaf+;                       // 071     DV da conta
             " "+;                              // 072     DV ag/conta - em branco
             "SEDE DAS MIUDEZAS ATACADO LTDA"+; // 073-102 Nome da empresa
             "BANCO SAFRA S/A               "+; // 103-132 Nome do banco (30)
             space(10)+;                        // 133-142 Uso exclusivo - brancos
             "1"+;                              // 143     Codigo remessa = 1
             SUBST(DTOC(ddataatu),1,2)+;        // 144-151 Data de geracao (DDMMAAAA)
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             "000000"+;                         // 152-157 Hora de geracao - manual pede "000000"
             "000001"+;                         // 158-163 Numero sequencial do arquivo
             "084"+;                            // 164-166 TODO SAFRA: versao do layout - opcoes
                                                 // validas 084/087/103, confirmar com o banco
             "00000"+;                          // 167-171 Densidade de gravacao (opcional)
             SPACE(20)+;                        // 172-191 Uso reservado do banco
             SPACE(20)+;                        // 192-211 Uso reservado da empresa
             SPACE(29)                          // 212-240 Uso exclusivo - brancos
endif

ARQ->( DBAPPEND() )
arq->REGREMES := mregrem

// header de LOTE - registro 1

if cBanco1 = "001"
  mregrem := cBanco1+;
             "0001"+;
             "1"+;
             "R"+;
             "01"+;
             "00"+;
             "020"+;
             " "+;
             "2"+;
             "040868234000170"+;
             "00"+cConv+"001417027  "+;
             cAgen+;
             cCont+;
             " "+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             space(40)+;
             space(40)+;
             "00000001"+;
             SUBST(DTOC(ddataatu),1,2)+;
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             "00000000"+;
             SPACE(33)
elseif cBanco1 = "341"
  mregrem := cBanco1+;
             "0001"+;
             "1"+;
             "R"+;
             "01"+;
             "00"+;
             "030"+;
             " "+;
             "2"+;
             "040868234000170"+;
             space(20)+;
             "0"+;
			 "8322"+;
             " "+;
             "0000000"+;
			 "11901"+;
             " "+;
             "0"+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             space(80)+;
             "00000001"+;
             SUBST(DTOC(ddataatu),1,2)+;
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             SUBST(DTOC(ddataatu),1,2)+;  // data do credito
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             SPACE(33)
else  // SAFRA (422) - layout conforme manual "Cobranca Safra - Layout Padrao
      // Safra CNAB 240" (Header de Lote, pag. 7-8)
  mregrem := cBanco1+;                          // 001-003 Banco = 422
             "0001"+;                           // 004-007 Lote do servico
             "1"+;                              // 008     Tipo de registro = 1
             "R"+;                              // 009     Tipo de operacao = R (remessa)
             "01"+;                             // 010-011 Tipo de servico = 01 (cobranca)
             space(2)+;                         // 012-013 Uso exclusivo - brancos
             "060"+;                            // 014-016 Versao do layout do lote
             " "+;                              // 017     Uso exclusivo - branco
             "2"+;                              // 018     Tipo insc. empresa = 2 (CNPJ)
             "0"+"40868234000170"+;             // 019-033 CNPJ da empresa
             space(20)+;                        // 034-053 Convenio - Safra nao trata
             cAgenSaf+;                         // 054-058 Agencia mantenedora da conta
             " "+;                              // 059     DV agencia - em branco
             cContSaf+;                         // 060-071 Numero da conta corrente
             cContDVSaf+;                       // 072     DV da conta
             " "+;                              // 073     DV ag/conta - em branco
             "SEDE DAS MIUDEZAS ATACADO LTDA"+; // 074-103 Nome da empresa
             space(40)+;                        // 104-143 Mensagem 1 - Safra nao trata
             space(40)+;                        // 144-183 Mensagem 2 - Safra nao trata
             "00000001"+;                       // 184-191 Numero remessa (seq. do lote)
             SUBST(DTOC(ddataatu),1,2)+;        // 192-199 Data de gravacao da remessa
             SUBST(DTOC(ddataatu),4,2)+;
             SUBST(DTOS(ddataatu),1,4)+;
             "00000000"+;                       // 200-207 Data do credito - manual pede zeros
             SPACE(33)                          // 208-240 Uso exclusivo - brancos
endif

ARQ->( DBAPPEND() )
arq->REGREMES := mregrem

SELECT AUX
Csequenc   := 0       // CONTADOR DOS TIPOS 1,2,3,4,5
nTotCobSim := 0.00    // total de cobranca simples
nQtdCobSim := 0

WHILE AUX->( !EOF() )

  TIT->(DBSETORDER(1),DBSEEK(AUX->nummov+aux->tipodoc+aux->codcli))
  
  if AUX->marca # "*" .or. ;
     (cBanco1 == "001" .and. left(TIT->nossonum,3) # "140").or.;
     (cBanco1 == "341" .and. left(TIT->nossonum,3) # "109").or.;
     (cBanco1 == "422" .and. left(TIT->nossonum,3) # "422")  // convencao interna: nosso
                                                              // numero Safra = prefixo "422"
                                                              // + 6 digitos sequenciais (9
                                                              // digitos livres, ver manual)
    AUX->( dbskip() )
    loop
  endif

  // se carteira 17 e vencido a mais de 5 dias, deve ir com protestar.
  // isso se no cadastro estiver como CLI->PROTESTAR = "S", e o campo
  // TIT->MARCAR foi marcado logo acima.

  CLI->(DBSETORDER(1),DBSEEK(AUX->CODCLI))

  ccodmov := ccodmovaux

  SELE AUX
  cJurDia := tit->valbruto*((tit->TAXAJUROS / 30)/100)

  cDesFin  := 0.00
  dVencAnt := "00000000"
  if ! empty(tit->dtvencant)
    if cli->todalinha = "S"  // 
      cDesFin  := (tit->descantec * (TIT->VALBRUTO)) / 100
	else
      cDesFin  := (tit->descantec * (TIT->VALBRUTO-tit->valicmret)) / 100
	endif
	
	// permite desconto no primeiro dia util
    mdat := tit->dtvencant
    WHILE .T.
      IF DOW(mdat) == 7        // SABADO
        mdat += 2
		LOOP
      ELSEIF DOW(mdat) == 1    // DOMINGO
        mdat += 1
		LOOP
      ELSEIF SUBST(DTOC(mdat),1,5) $ "01/01,30/03,21/04,01/05,31/05,07/09,12/10,02/11,15/11,25/12"     // FERIADOS NACIONAIS
        mdat += 1
		LOOP
      ENDIF
	  
	  SELECT DAT2
	  LOCATE FOR DAT2->FERIADO == mdat     
      IF DAT2->FERIADO == mdat .OR. STR(DOW(mdat),1) $ "17"    // E' UM FERIADO OU FIM DE SEMANA
        mdat += 1
      ELSE
        EXIT
      ENDIF
    ENDDO
	
    dVencAnt := SUBST(DTOC(mdat),1,2)+;
                SUBST(DTOC(mdat),4,2)+;
                SUBST(DTOS(mdat),1,4)
  endif

  SELE AUX

  cNossoN := left(alltrim(TIT->NOSSONUM)+space(8),20)

  // remessa detalhe - registro 3 - segmento P

  if cBanco1 = "001"
  mregrem := cBanco1+;
             "0001"+;
             "3"+;
             strzero(++Csequenc,5)+;
             "P"+;
             " "+;
             cCodMov+;
             cAgen+;
             cCont+;
             "0"+;
             cNossoN+;
             if(cBanco1="001","1"," ")+;
             "1"+;
             "1"+;
             "2"+;
             "2"+;
             TIT->NUMMOV+SPACE(7)+;
             SUBST(DTOC(TIT->DTVENCLIM),1,2)+;
             SUBST(DTOC(TIT->DTVENCLIM),4,2)+;
             SUBST(DTOS(TIT->DTVENCLIM),1,4)+;
             STUFF(STRZERO(TIT->VALBRUTO,16,2),14,1,"")+;
             "00000"+;
             "0"+;
             "02"+;
             "N"+;
             SUBST(DTOC(TIT->DTEMISS),1,2)+;
             SUBST(DTOC(TIT->DTEMISS),4,2)+;
             SUBST(DTOS(TIT->DTEMISS),1,4)+;
             "1"+;
             "00000000"+;
             STUFF(STRZERO(cJurDia,16,2),14,1,"")+;
             IF(cDesFin > 0,"1","0")+;
             IF(cDesFin > 0,dVencAnt,"00000000")+;
             IF(cDesFin > 0,STUFF(STRZERO(cDesFin,16,2),14,1,""),"000000000000000")+;
             "000000000000000"+;
             "000000000000000"+;
             TIT->NUMMOV+SPACE(17)+;
             IF(ccodmov="09","1","0")+;
             IF(ccodmov="09",strzero(cli->diasprot,2),"00")+;
             "2"+;
             "000"+;
             "09"+;
             "0000000000"+;
             SPACE(1)
  elseif cBanco1 = "341"
  cNossoN := alltrim(TIT->NOSSONUM)+digito("8322"+"11901"+"109"+subst(TIT->NOSSONUM,4,8))  // cria um digito verificador usando o modulo 10.

mregrem := cBanco1+;   					// 1-3
             "0001"+;					// 4-7
             "3"+;						// 8
             strzero(++Csequenc,5)+;	// 9-13
             "P"+;						// 14-14
             " "+;						// 15-15
             cCodMov+;					// 16-17
             "0"+;						// 18-18
			 "8322"+;					// 19-22
             " "+;						// 23
             "0000000"+;				// 24-30
			 "11901"+;					//
			 " "+;
			 "0"+;
             cNossoN+;
			 space(8)+;
			 "00000"+;
             TIT->NUMMOV+SPACE(2)+;
			 space(5)+;
             SUBST(DTOC(TIT->DTVENCLIM),1,2)+;
             SUBST(DTOC(TIT->DTVENCLIM),4,2)+;
             SUBST(DTOS(TIT->DTVENCLIM),1,4)+;
             STUFF(STRZERO(TIT->VALBRUTO,16,2),14,1,"")+;
			 "00000"+;
             "0"+;
			 "99"+;   // DIVERSOS
			 "N"+;
             SUBST(DTOC(TIT->DTEMISS),1,2)+;
             SUBST(DTOC(TIT->DTEMISS),4,2)+;
             SUBST(DTOS(TIT->DTEMISS),1,4)+;
			 "0"+;
             SUBST(DTOC(TIT->DTVENCLIM),1,2)+;
             SUBST(DTOC(TIT->DTVENCLIM),4,2)+;
             SUBST(DTOS(TIT->DTVENCLIM),1,4)+;
             STUFF(STRZERO(cJurDia,16,2),14,1,"")+;
             IF(cDesFin > 0,"1","0")+;
             IF(cDesFin > 0,dVencAnt,"00000000")+;
             IF(cDesFin > 0,STUFF(STRZERO(cDesFin,16,2),14,1,""),"000000000000000")+;
             "000000000000000"+;
             "000000000000000"+;
             TIT->NUMMOV+SPACE(17)+;
             IF(ccodmov="09","1","0")+;
             IF(ccodmov="09",strzero(cli->diasprot,2),"00")+;
			 "0"+;
			 "01"+;
             "0000000000000"+;
             SPACE(1)

	nTotCobSim += TIT->VALBRUTO
    nQtdCobSim++
  else  // SAFRA (422) - layout conforme manual "Cobranca Safra - Layout Padrao
        // Safra CNAB 240" (Segmento P, pag. 9-12). Cobranca DIRETA (a
        // empresa emite o proprio boleto), pois o "nosso numero" abaixo e'
        // um valor real gerado pelo sistema (na Cobranca Convencional o
        // manual pede 000000000 nas posicoes 38-46, devolvido pelo banco
        // no retorno). O manual confirma que o "nosso numero" Safra e'
        // LIVRE (9 digitos escolhidos pela empresa, sem digito verificador
        // calculado pelo banco) - por isso nao ha calculo de DV aqui.
  cNossoN := LEFT(alltrim(TIT->NOSSONUM)+SPACE(9),9)  // 9 digitos livres (ex.: prefixo 422 + sequencial)

mregrem := cBanco1+;   					// 001-003 Banco = 422
             "0001"+;					// 004-007 Lote do servico
             "3"+;						// 008     Tipo de registro = 3
             strzero(++Csequenc,5)+;	// 009-013 Numero sequencial de registro no lote
             "P"+;						// 014     Segmento = P
             " "+;						// 015     Uso exclusivo - branco
             cCodMov+;					// 016-017 Codigo de movimento remessa
             cAgenSaf+;					// 018-022 Agencia mantenedora da conta
             " "+;						// 023     DV agencia - em branco
             cContSaf+;					// 024-035 Numero da conta corrente
             cContDVSaf+;				// 036     DV da conta
             " "+;						// 037     DV ag/conta - em branco
             cNossoN+;					// 038-046 Identificacao do titulo no banco (livre, 9 digitos)
			 space(11)+;				// 047-057 Uso exclusivo Safra - em branco
             "1"+;						// 058     Carteira = 1 (Cobranca Simples)
             "1"+;						// 059     Forma de cadastro = 1 (Cobranca Registrada)
             "2"+;						// 060     Tipo de documento = 2 (Escritural)
             "2"+;						// 061     TODO SAFRA: emissao do bloqueto - 2 = cliente emite (confirmar)
             "2"+;						// 062     TODO SAFRA: distribuicao do bloqueto - 2 = cliente distribui (confirmar)
             TIT->NUMMOV+SPACE(2)+;
			 space(5)+;					// 063-077 Numero do documento de cobranca (10 uteis + 5 brancos)
             SUBST(DTOC(TIT->DTVENCLIM),1,2)+;
             SUBST(DTOC(TIT->DTVENCLIM),4,2)+;
             SUBST(DTOS(TIT->DTVENCLIM),1,4)+;	// 078-085 Data de vencimento do titulo
             STUFF(STRZERO(TIT->VALBRUTO,16,2),14,1,"")+;	// 086-100 Valor nominal do titulo
			 cAgenSaf+;					// 101-105 Agencia encarregada da cobranca (mesma da 018-022)
             " "+;						// 106     DV agencia - em branco
			 "99"+;						// 107-108 Especie do titulo = 99 (Outros)
			 "N"+;						// 109     Titulo nao aceito
             SUBST(DTOC(TIT->DTEMISS),1,2)+;
             SUBST(DTOC(TIT->DTEMISS),4,2)+;
             SUBST(DTOS(TIT->DTEMISS),1,4)+;	// 110-117 Data de emissao do titulo
			 IF(cJurDia > 0,"1","3")+;	// 118     Codigo do juros de mora (1=valor/dia, 3=isento)
             IF(cJurDia > 0,;
                SUBST(DTOC(TIT->DTVENCLIM+1),1,2)+SUBST(DTOC(TIT->DTVENCLIM+1),4,2)+SUBST(DTOS(TIT->DTVENCLIM+1),1,4),;
                "00000000")+;			// 119-126 Data do juros de mora (TODO SAFRA: confirmar se e' vencto+1)
             STUFF(STRZERO(cJurDia,16,2),14,1,"")+;	// 127-141 Valor do juros de mora por dia
             IF(cDesFin > 0,"1","0")+;	// 142     Codigo do desconto
             IF(cDesFin > 0,dVencAnt,"00000000")+;		// 143-150 Data do desconto
             IF(cDesFin > 0,STUFF(STRZERO(cDesFin,16,2),14,1,""),"000000000000000")+;	// 151-165 Valor do desconto
             "000000000000000"+;		// 166-180 Valor do IOF (zeros - nao seguradora)
             "000000000000000"+;		// 181-195 Valor do abatimento (Safra nao aceita na entrada)
             TIT->NUMMOV+SPACE(17)+;	// 196-220 Identificacao do titulo na empresa (uso livre)
             IF(ccodmov="09","1","3")+;	// 221     Codigo p/ protesto (1=dias corridos, 3=nao protestar)
             IF(ccodmov="09",strzero(cli->diasprot,2),"00")+;	// 222-223 Numero de dias para protesto
			 "2"+;						// 224     TODO SAFRA: codigo baixa/devolucao - 2 = nao baixar (confirmar)
			 "000"+;					// 225-227 Numero de dias para baixa/devolucao
             "09"+;						// 228-229 Codigo da moeda = 09 (Real)
             "0000000000"+;				// 230-239 Numero do contrato de operacao de credito
             "1"						// 240     TODO SAFRA: uso livre - 1 = nao autoriza pagto parcial (confirmar)

	nTotCobSim += TIT->VALBRUTO
    nQtdCobSim++
  endif
  
  ARQ->( DBAPPEND() , arq->REGREMES := mregrem)

  // remessa detalhe - registro 3 - segmento Q

  if cBanco1 = "001"
  mregrem := cBanco1+;
             "0001"+;
             "3"+;
             strzero(++Csequenc,5)+;
             "Q"+;
             " "+;
             cCodMov+;
             IF(CLI->PESFISJUR=="F","1","2")+;
             IF(CLI->PESFISJUR=="F","0000"+CLI->CPFCLI,"0"+CLI->CGCCLI)+;
             trocacarac(CLI->RAZSOCCLI)+SPACE(8)+;
             trocacarac(CLI->ENDCLI)+SPACE(8)+;
             trocacarac(CLI->BAIRCLI)+;
             trocacarac(CLI->CEPCLI)+;
             LEFT(trocacarac(CLI->CIDCLI),15)+;
             CLI->ESTCLI+;
             IF(CLI->PESFISJUR=="F","1","2")+;
             "040868234000170"+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             SPACE(10)+;
             "000"+;
             SPACE(28)

			 // "040868234000170"+;
             // "SEDE DAS MIUDEZAS ATACADO LTDA"+;
  else  // ITAU (341) e SAFRA (422) - layout de segmento Q identico entre os dois
  mregrem := cBanco1+;
             "0001"+;
             "3"+;
             strzero(++Csequenc,5)+;
             "Q"+;
             " "+;
             cCodMov+;
             IF(CLI->PESFISJUR=="F","1","2")+;
             IF(CLI->PESFISJUR=="F","0000"+CLI->CPFCLI,"0"+CLI->CGCCLI)+;
             left(trocacarac(CLI->RAZSOCCLI),30)+;
			 SPACE(10)+;
             trocacarac(CLI->ENDCLI)+SPACE(8)+;
             trocacarac(CLI->BAIRCLI)+;
             trocacarac(CLI->CEPCLI)+;
			 LEFT(trocacarac(CLI->CIDCLI),15)+;
			 CLI->ESTCLI+;
             IF(CLI->PESFISJUR=="F","1","2")+;
             "040868234000170"+;
             "SEDE DAS MIUDEZAS ATACADO LTDA"+;
             SPACE(10)+;
             "000"+;
             SPACE(28)

			 // "040868234000170"+;
             // "SEDE DAS MIUDEZAS ATACADO LTDA"+;
  endif
  
  ARQ->( DBAPPEND() , arq->REGREMES := mregrem )

  tit->(rlock())
  tit->flag&cCodMov. := cCodMov
  tit->(dbunlock())

  SELE AUX
  AUX->flag&cCodMov. := cCodMov
  SKIP

ENDDO

// TRAILER DE LOTE - REGISTRO 5

if cBanco1 = "001"
  mregrem := cBanco1+;
             "0001"+;
             "5"+;
             SPACE(9)+;
             STRZERO(Csequenc+2,6)+;
             REPL("0",92)+;
             SPACE(125)
elseif cBanco1 = "341"
  mregrem := cBanco1+;
             "0001"+;
             "5"+;
             SPACE(9)+;
             STRZERO(Csequenc+2,6)+;    // +2 devido registro tipo 1 e 5 nao ter contado.  Obs. deve contar o registro tipo 5
             STRZERO(nQtdCobSim,6)+;    // somente os registros 3-P e 3-Q
             STUFF(STRZERO(nTotCobSim,18,2),16,1,"")+;
             STRZERO(0,6)+;             // somente os registros 3-P e 3-Q
             STUFF(STRZERO(0.00,18,2),16,1,"")+;
             REPL("0",46)+;
			 "00000000"+;
             SPACE(117)
	nTotCobSim += TIT->VALBRUTO
    nQtdCobSim++
else  // SAFRA (422) - layout conforme manual "Cobranca Safra - Layout Padrao
      // Safra CNAB 240" (Trailer de Lote, pag. 16-18). Diferente de BB/Itau,
      // o campo 018-023 conta APENAS os registros de detalhe (P/Q/R), sem
      // somar os registros de header/trailer de lote - por isso nao soma "+2"
      // aqui.
  mregrem := cBanco1+;                          // 001-003 Banco = 422
             "0001"+;                           // 004-007 Lote do servico
             "5"+;                              // 008     Tipo de registro = 5
             SPACE(9)+;                         // 009-017 Uso exclusivo - brancos
             STRZERO(Csequenc,6)+;              // 018-023 Qtde de registros detalhe (P+Q) do lote
             STRZERO(nQtdCobSim,6)+;            // 024-029 Qtde de titulos em cobranca simples
             STUFF(STRZERO(nTotCobSim,18,2),16,1,"")+;	// 030-046 Valor total (simples)
             STRZERO(0,6)+;                     // 047-052 Qtde de titulos em cobranca vinculada
             STUFF(STRZERO(0.00,18,2),16,1,"")+;	// 053-069 Valor total (vinculada)
             "000000"+;                         // 070-075 Qtde titulos caucionada - Safra nao trata
             STUFF(STRZERO(0.00,18,2),16,1,"")+;	// 076-092 Valor total (caucionada) - Safra nao trata
             "000000"+;                         // 093-098 Qtde titulos descontada - Safra nao trata
             SPACE(17)+;                        // 099-115 Valor total titulos - deixar em branco
             SPACE(8)+;                         // 116-123 Numero de aviso do lancamento - em branco
             SPACE(117)                         // 124-240 Uso exclusivo - brancos
	nTotCobSim += TIT->VALBRUTO
    nQtdCobSim++
endif

ARQ->( DBAPPEND() , arq->REGREMES := mregrem )

// TRAILER DO ARQUIVO - REGISTRO 9

if cBanco1 = "001"
  mregrem := cBanco1+;
             "9999"+;
             "9"+;
             SPACE(9)+;
             STRZERO(1,6)+;
             STRZERO(Csequenc+4,6)+;
             "000000"+;
             SPACE(205)
else
  mregrem := cBanco1+;
             "9999"+;
             "9"+;
             SPACE(9)+;
             STRZERO(1,6)+;
             STRZERO(Csequenc+4,6)+;
             "000000"+;
             SPACE(205)
endif

ARQ->( DBAPPEND() , arq->REGREMES := mregrem )

SELE ARQ
GO TOP
//dbedit()
IF LASTREC() > 4

  SELE ARQ
  GO TOP
  cNomeArq := if(cBanco1 == "422", "REMSAFRA", "REMESSA")   // nome do arquivo conforme o banco escolhido
  cExt := cBanco1
  while .t.
    if ! file("BB\&cNomeArq..&cExt.")
      // COPY TO BB\<cNomeArq>.&cExt. SDF
	  copy to bb\remessa.txt sdf
      
	  tira26()   // tira o caracter do fim do arquivo
  
      RENAME bb\remess2.txt TO BB\&cNomeArq..&cExt.
	  erase bb\remessa.txt
      exit
    endif
	
    cExt := strzero(val(cExt)+1,3)
  enddo

endif
select AUX
go top

next

TONE(1000,5) ; TONE(2000,5) ; TONE(3000,5)
MENSAGEM("Arquivo ("+cNomeArq+"."+cExt+") Gerado com sucesso."+enter,,.F.)
CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")

IF SELECT("ARQ") # 0
  CLOSE ARQ
ENDIF
ERASE &arq1.:ARQ_REM.DBF
RETURN

FUNC DIGITO(NossoNum)
*********************
Peso := 2
Somatoria := 0
for i := Len(NossoNum) to 1 STEP -1
  P := val(Subst(NossoNum,i,1)) * Peso
  if P > 9 
    Somatoria += (P - 9)
  else
    Somatoria += P
  endif

  if Peso = 2 
    Peso := 1
  else
    Peso := 2
  endif
next

Resto := MOD(Somatoria,10)

if Resto = 0
  RETURN('0')
else
  RETURN(str(10 - Resto,1))
endif

FUNCTION MENSAGEM(mensagem)
***************************
 LOCAL telamens, cursorant := SETCURSOR()
 telamens := SAVESCREEN(24,00,24,80)
 SETCURSOR(0)
 CENTRA(mensagem)
 FOR x := 1 TO 2
   TONE(300,1)  ;  TONE(500,1)
 NEXT
 WHILE ! STR(INKEY(0),2) $ "13,27"
 ENDDO
 RESTSCREEN(24,00,24,80,telamens)
 SETCURSOR(cursorant)
RETURN(.T.)
*
**
FUNCTION CENTRA(mtexto)
***********************
 LOCAL cor_ant := SETCOLOR()
 SetColor("W+/N")
 DISPBEGIN()
 @ 23,00 SAY SPACE(80)
 INVERSO(mtexto)
 DISPEND()
 SETCOLOR(cor_ant)
RETURN(.T.)
*
**
FUNCTION INVERSO(mtexto)
************************
 LOCAL mabre,mfech,mtecla1,mtecla2,mtecla3
 LOCAL mcoluna := ((80-LEN(mtexto))/2)
 @ 23,mcoluna SAY mtexto
 WHILE "[" $ mtexto
   mabre   := AT("[",mtexto)
   mfech   := AT("]",mtexto)
   mtecla1 := SUBST(mtexto,mabre,mfech-mabre+1)
   mtecla2 := " "+SUBST(mtecla1,2,LEN(mtecla1)-2)+" "
   mtecla3 := SUBST(mtecla1,2,LEN(mtecla1)-2)
   mtexto  := STRTRAN(mtexto,mtecla1,mtecla2)
   @ 23,mcoluna+mabre-1 SAY " "     COLOR "N/W"
   @ 23,mcoluna+mabre+0 SAY mtecla3 COLOR "N*/W"
   @ 23,mcoluna+mfech-1 SAY " "     COLOR "N/W"
 ENDDO
RETURN(.T.)
*
**
Function F_BOX(lin1,col1,lin2,col2)
***********************************
Local Cor := SetColor()
SetColor("W/W")   ; Scroll(lin1,col1,lin2,col2,0) ; SOMBRA(lin1,col1,lin2,col2)
SetColor("W+/W+") ; @ lin1,col1 to lin2,col2
SetColor("N+/W+")
@ lin2,col1+1 to lin2,col2
@ lin1,col2   to lin2,col2
@ lin1,col2 Say "¿"
@ lin2,col2 Say "Ù"
SetColor( Cor )
Return(.T.)
*
**
FUNCTION SOMBRA(ls1,cs1,ls2,cs2)
********************************
 LOCAL x
 // sombra horizontal
 RESTSCREEN(ls2+1, cs1-1,ls2+1,cs2-2,;
 TRANSFORM(SAVESCREEN(ls2+1,cs1-1,ls2+1,cs2-2),REPL("X"+CHR(8),cs2-cs1)))
 // sombra vertical
 FOR x := 1 TO 2
   RESTSCREEN(ls1+1,cs1-x,ls2+1,cs1-x,;
   TRANSFORM(SAVESCREEN(ls1+1,cs1-x,ls2+1,cs1-x),REPL("X"+CHR(8),(ls2+1)-ls1)))
 NEXT
RETURN(.T.)
*
**
FUNCTION CONFIRMA(mtexto,mresp1)
********************************
 LOCAL GETLIST := {}, mresp2,  cursorant := SETCURSOR()
 LOCAL mcoluna := (80-LEN(mtexto))/2, lcCor := SetColor()
 SetColor("W+/N")
 @ 23,00 SAY SPACE(80) ; @ 23,mcoluna SAY mtexto
 TONE(500,0.5)         ; SETCURSOR(1)
 mresp2  := mresp1
 @ 23,((mcoluna+LEN(mtexto))+1) GET mresp2 PICT "@! A" VALID mresp2 $ "SN"
 SET ESCAPE OFF
 READ
 SET ESCAPE ON
 CLEAR GETS
 TONE(200,1)
 SETCURSOR(cursorant); SetColor(lcCor)
RETURN(IIF(mresp2 = "S",.T.,.F.))

FUNCTION GRAVAAUX()   // pega o titulo e cadastra no auxiliar para mostragem
*******************
AUX->(DBAPPEND())
AUX->MARCA     := TIT->MARCA
AUX->RETBANCO  := TIT->RETBANCO
AUX->NUMMOV    := TIT->NUMMOV
AUX->TIPODOC   := TIT->TIPODOC
AUX->DTEMISS   := TIT->DTEMISS
AUX->CODSET    := TIT->CODSET
AUX->CODCLI    := TIT->CODCLI
AUX->SITTIT    := TIT->SITTIT
AUX->DTVENCLIM := TIT->DTVENCLIM
AUX->VALBRUTO  := TIT->VALBRUTO
AUX->NOSSONUM  := TIT->NOSSONUM
AUX->NUMPED    := TIT->NUMPED
AUX->FLAG01    := TIT->FLAG01
AUX->FLAG02    := TIT->FLAG02
AUX->FLAG04    := TIT->FLAG04
AUX->FLAG05    := TIT->FLAG05
AUX->FLAG06    := TIT->FLAG06
AUX->FLAG07    := TIT->FLAG07
AUX->FLAG08    := TIT->FLAG08
AUX->FLAG09    := TIT->FLAG09
AUX->FLAG10    := TIT->FLAG10
AUX->FLAG30    := TIT->FLAG30
AUX->FLAG31    := TIT->FLAG31

if cCodMov $ "02"
  if cBaixa .and. AUX->sittit $ "BC,CA,PC" .and. empty(aux->flag&cCodMov.)  // pedido de baixa
    AUX->marca := "*"
  elseif nQtdeDias > 0
    AUX->marca := "*"
  else 
    AUX->marca := ""
  ENDIF
elseif cCodMov $ "01"
  if empty(aux->flag01) .or. EMPTY(tit->retbanco)
    AUX->marca := "*"
  else
    AUX->marca := ""
  endif
elseif cCodMov $ "09"
  if empty(aux->flag09)
    AUX->marca := "*"
  else
    AUX->marca := ""
  endif
elseif ! cCodMov $ "02,01,09"
  AUX->marca := "*"
endif


* TIT->(DBSETORDER(1),DBSEEK(AUX->nummov+aux->tipodoc+aux->codcli))
TIT->(rlock())
TIT->MARCA := AUX->MARCA
TIT->(dbunlock())

RETURN(.T.)

function tira26()
*****************
//O CLIPPER grava um caracter chr(26) no final to TXT gerado.
//Nao sei como nao gravar este caracter, mas escrevi um programa pequeno que
//le o TXT criado e grava um outro sem este caracter.
//pequeno e rapido. Vale a pena!

//Veja:

arq_tmp=fopen("bb\remessa.txt")  // 
tam_tmp=fseek(arq_tmp,0,2)-1
fseek(arq_tmp,0,0)
arq_txt=fcreate("bb\remess2.txt")   // xml provisorio, sem o caractere do final do arquivo, e que sera renomeado, ficando o arquivo definitivo.
tam_txt=0

do while tam_txt<tam_tmp
  restante=tam_tmp-tam_txt
  buffer=space(if(restante<=30000,restante,30000))
  fread(arq_tmp,@buffer,len(buffer))
  fwrite(arq_txt,buffer)    // quando grava elimina o caracter chr(26)
  tam_txt+=len(buffer)
enddo

fclose(arq_tmp)
fclose(arq_txt)
*ferase("arquivo.tmp")

//Utilizeu um BUFFER de 30.000 bytes,
//mas se for necessario pode diminuir este tamanho para a metade.
return(.t.)

function trocacarac(texto)
********************

 // Remove acentuacao (o Safra, como a maioria dos bancos, exige texto
 // sem acentos nos campos do CNAB240) - usa CHR(n) com os codigos da
 // pagina de codigo OEM/DOS (CP850, padrao em sistemas Clipper no
 // Brasil) em vez de gravar o caracter acentuado direto no fonte, pra
 // nao depender de qual code page este arquivo .PRG e' editado/salvo.
 texto := STRTRAN(texto,CHR(160),"A")  // a com agudo
 texto := STRTRAN(texto,CHR(181),"A")  // A com agudo
 texto := STRTRAN(texto,CHR(131),"A")  // a com circunflexo
 texto := STRTRAN(texto,CHR(182),"A")  // A com circunflexo
 texto := STRTRAN(texto,CHR(198),"A")  // a com til
 texto := STRTRAN(texto,CHR(199),"A")  // A com til
 texto := STRTRAN(texto,CHR(133),"A")  // a com crase
 texto := STRTRAN(texto,CHR(183),"A")  // A com crase
 texto := STRTRAN(texto,CHR(130),"E")  // e com agudo
 texto := STRTRAN(texto,CHR(144),"E")  // E com agudo
 texto := STRTRAN(texto,CHR(136),"E")  // e com circunflexo
 texto := STRTRAN(texto,CHR(210),"E")  // E com circunflexo
 texto := STRTRAN(texto,CHR(161),"I")  // i com agudo
 texto := STRTRAN(texto,CHR(214),"I")  // I com agudo
 texto := STRTRAN(texto,CHR(140),"I")  // i com circunflexo
 texto := STRTRAN(texto,CHR(215),"I")  // I com circunflexo
 texto := STRTRAN(texto,CHR(162),"O")  // o com agudo
 texto := STRTRAN(texto,CHR(224),"O")  // O com agudo
 texto := STRTRAN(texto,CHR(147),"O")  // o com circunflexo
 texto := STRTRAN(texto,CHR(226),"O")  // O com circunflexo
 texto := STRTRAN(texto,CHR(228),"O")  // o com til
 texto := STRTRAN(texto,CHR(229),"O")  // O com til
 texto := STRTRAN(texto,CHR(163),"U")  // u com agudo
 texto := STRTRAN(texto,CHR(233),"U")  // U com agudo
 texto := STRTRAN(texto,CHR(150),"U")  // u com circunflexo
 texto := STRTRAN(texto,CHR(234),"U")  // U com circunflexo
 texto := STRTRAN(texto,CHR(129),"U")  // u com trema
 texto := STRTRAN(texto,CHR(154),"U")  // U com trema
 texto := STRTRAN(texto,CHR(135),"C")  // c cedilha
 texto := STRTRAN(texto,CHR(128),"C")  // C cedilha

 WHILE "/" $ texto 
   posic := AT("/",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "," $ texto 
   posic := AT(",",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "(" $ texto 
   posic := AT("(",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "+" $ texto 
   posic := AT("+",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "." $ texto 
   posic := AT(".",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "-" $ texto 
   posic := AT("-",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
 
 WHILE "|" $ texto 
   posic := AT("|",texto)
   
   texto := STUFF(texto,posic,1," ")
   
 ENDDO
RETURN(texto)