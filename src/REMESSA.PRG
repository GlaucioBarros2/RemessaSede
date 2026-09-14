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
@ 04,10 PROM " BANCO DO BRASIL                                "
@ 05,10 PROM " BANCO SAFRA SA                                 "
MENU TO opcaoB
if opcaoB== 0
   CLS ; RETURN
ENDIF

cls
cBanco1 := if(opcaob=1,"341",if(opcaob=2,"001","422"))
cBanco2 := if(opcaob=1,"BANCO ITAU SA                 ",;
           if(opcaob=2,"BANCO DO BRASIL               ","BANCO SAFRA SA                "))

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
	   
      GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
      GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
        GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
          GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
          GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
          GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
	   
      GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
	  
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
cab[3] := "Data;Emiss�o"
cab[4] := "Data;Vencto."
cab[5] := "Gerados (O-Opcoes)"
cab[6] := "St"
cab[7] := "No  Titulo"
cab[8] := "Tp"
cab[9] := "Data;Baixa"
cab[10] := "Vendedor"
cab[11] := "Cliente"
cab[12]:= "Valor"
cab[13]:= "N� Bloq no Bco"
cab[14]:= "N� Ped"
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
SCROLL(03,00,21,79,0) ; DISPBOX(03,00,21,79,"��������")
CENTRA("[T]-Mar_Todos [D]-Des_Todos [M]-Marca/Desm [F3]-Gerar [O]-Opcoes [P]-Pesq.")
//
CLI->( DBSETORDER(1) )
//
SELECT AUX
GO TOP
//
DBEDIT(04,01,19,78,cam,"DBCONFCLI",mas,cab,"��","�","��")
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
  IF CONFIRMA("Confirma Desmarca��o de Todos (S/N) ?"," ")
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
  IF CONFIRMA("Confirma Marca��o de Todos (S/N) ?"," ")
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
  KEYBOARD CHR(24)           // Pr�ximo Item
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
    MENSAGEM("N�o h� titulos selecionados"+enter,,.T.)
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

// este for abaixo � devido existir 2 convenios, ou seja, dois nosso numero.
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
  // TODO SAFRA: preencher com os dados reais do convenio Safra (cedente),
  // agencia e conta corrente fornecidos pelo banco antes de usar em producao.
  cConv := space(7)     // codigo do cedente/convenio Safra
  cAgen := "00000 "     // agencia Safra (4 digitos + branco, ajustar conforme manual)
  cCont := "000000000000 "  // conta corrente + DV Safra
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
else  // SAFRA (422) - layout padrao FEBRABAN CNAB240, TODO: confirmar versao
      // de layout e campos reservados com o manual tecnico do Safra
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
else  // SAFRA (422) - TODO: substituir "0000"/"00000" pela agencia/conta
      // reais fornecidas pelo Safra (mesma posicao usada pelo Itau acima)
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
			 "0000"+;
             " "+;
             "0000000"+;
			 "00000"+;
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
     (cBanco1 == "422" .and. left(TIT->nossonum,3) # "422")  // TODO SAFRA: confirmar o
                                                              // prefixo usado no nosso numero
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
      IF DOW(mdat) == 7        // S�BADO
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
  cNossoN := alltrim(TIT->NOSSONUM)+digito("8322"+"11901"+"109"+subst(TIT->NOSSONUM,4,8))  // cria um d�gito verificador usando o modulo 10.

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
  else  // SAFRA (422)
  // TODO SAFRA: DIGITOMOD11() abaixo usa o Modulo 11 padrao FEBRABAN como
  // "melhor palpite" na ausencia do manual tecnico do Safra. Confirmar o
  // algoritmo real do DV do nosso numero (pode ser Modulo 10 ou Modulo 11
  // com regras proprias) antes de usar este arquivo em producao. Da mesma
  // forma, "0000"/"00000" (agencia/conta) e a carteira "01" sao placeholders
  // a substituir pelos dados reais do convenio Safra.
  cNossoN := alltrim(TIT->NOSSONUM)+DIGITOMOD11("0000"+"00000"+"422"+subst(TIT->NOSSONUM,4,8))

mregrem := cBanco1+;   					// 1-3
             "0001"+;					// 4-7
             "3"+;						// 8
             strzero(++Csequenc,5)+;	// 9-13
             "P"+;						// 14-14
             " "+;						// 15-15
             cCodMov+;					// 16-17
             "0"+;						// 18-18
			 "0000"+;					// 19-22  TODO SAFRA: agencia
             " "+;						// 23
             "0000000"+;				// 24-30
			 "00000"+;					// TODO SAFRA: conta corrente
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
			 "01"+;   // TODO SAFRA: codigo da carteira
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
else
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
  cExt := cBanco1
  while .t.
    if ! file("BB\REMESSA.&cExt.")
      // COPY TO BB\REMESSA.&cExt. SDF
	  copy to bb\remessa.txt sdf
      
	  tira26()   // tira o caracter do fim do arquivo
  
      RENAME bb\remess2.txt TO BB\REMESSA.&cExt.
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
MENSAGEM("Arquivo (REMESSA."+cExt+") Gerado com sucesso."+enter,,.F.)
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

FUNC DIGITOMOD11(NossoNum)
**************************
// TODO SAFRA: implementa o calculo de DV pelo Modulo 11 padrao FEBRABAN,
// usado aqui como "melhor palpite" para o nosso numero do Banco Safra na
// AUSENCIA do manual tecnico do banco. O Safra pode usar Modulo 10 (igual
// a funcao DIGITO() acima) ou regras proprias de Modulo 11 (ex.: DV "P"
// quando o resto da 10, ou DV "0" quando o resto da 0 ou 1). CONFIRMAR
// com o manual de instrucoes CNAB240 do Safra antes de usar em producao.
Peso := 2
Somatoria := 0
for i := Len(NossoNum) to 1 STEP -1
  Somatoria += val(Subst(NossoNum,i,1)) * Peso

  if Peso = 7
    Peso := 2
  else
    Peso++
  endif
next

Resto := MOD(Somatoria,11)

if Resto = 0 .or. Resto = 1
  RETURN('0')
elseif Resto = 10
  RETURN('0')     // TODO SAFRA: alguns bancos usam "P" para resto 10 - confirmar
else
  RETURN(str(11 - Resto,1))
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
@ lin1,col2 Say "�"
@ lin2,col2 Say "�"
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

FUNCTION GRAVAAUX()   // pega o t�tulo e cadastra no auxiliar para mostragem
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
//mas se for necess�rio pode diminuir este tamanho para a metade.
return(.t.)

function trocacarac(texto)
********************

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