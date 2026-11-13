#include "SIXNSX.CH"
#include "MACHSIX.CH"

SetCursor(0)

Set Scoreboard OFF  ;  Set Date British   ;  Set Confirm ON
Set Intensity  OFF  ;  Set Delimiters ON  ;  Set Delimiters To "[]"
Set Deleted    ON   ;  Set Exclusive  ON  ;  Set Epoch to 1960

cCorAtu := SetColor()

SetColor(If(IsColor(),"W+/B+","W+/GR"))

Tone(1250,0.1) ;  Tone(600,0.5)

DISPBEGIN()

Cls
For y := 1 To 160
  ?? " TECSOFT " + Space(4)
Next

DISPEND()

F_BOX(01,06,03,73)

@ 02,09 Say "DATARET2 - CAPTURA ARQUIVO-RETORNO C/TITULOS DO BANCO" Color("N/W")

xBox := SAVESCREEN(06,24,24,52)

setas := "["+CHR(24)+CHR(25)+"]"

AbreDBF := .T.

BEGIN SEQUENCE

While .T.

  F_BOX(06,26,21,51)
  
  cCanco := ""

  If ! File("c:\datanet\fontes\*.RET")
    Break
  EndIf

  Declare aRetorno[ADir("c:\datanet\fontes\*.RET")]

  ADir("c:\datanet\fontes\*.RET",aRetorno)

  ASort(aRetorno)

  While .T.

    AbreDBF := .T.
    close all

    SetColor("N/W,W/N")

	KEYB CHR(13)

    opRetorno := ACHOICE(07,28,21,49,aRetorno,.T.,"RETORNO")

    If opRetorno = 0  ;  Break  ;  EndIf

    lAbertos := "S"

    lGeraLot := .T.
	
	cCodMov := "06,17"+space(50)     // '06' = Liquidação,   '17' = Liquidação Após Baixa ou Liquidação Título Não Registrado
	setcursor(1)
	
    IF ! IMPR_ARQ()   // Imprime informações do *.ret 
      LOOP
    ENDIF

    AbreDBF := .T.

    RestScreen(06,24,24,52,xBox)

    xBox2 := SaveScreen(13,00,21,74)

    If ! F_CAPTURATIT()                 // CAPTURA TITULOS DO ARQUIVO DE RETORNO
      RestScreen(13,00,21,74,xBox2)
      Break
    EndIf

    RestScreen(13,00,21,74,xBox2)

    If Len(aRetorno) = 1
      Break
    EndIf

    Exit

  Enddo

Enddo

END SEQUENCE

If ! AbreDBF  ;  CENTRA("Fechando arquivos. Aguarde...")  ;  EndIf

dbCloseAll()  ;  SetColor(cCorAtu)  ;  Cls  ;  Return
*
**
Static Function F_CAPTURATIT()
******************************
Local xArquivo := aRetorno[opRetorno], xPonto, xArqXXX,;
      xDia, xMes, xAno

MultiUsu := .T.

If AbreDBF
  If ! NET_USE("c:\datanet\fontes\SACADEMP.DBF","EMP",MultiUsu,.F.) ; Return(.F.) ; EndIf
EndIf

EMP->( dbGotop() )
If Empty(EMP->NUMLOTBAI) .or. EMP->NUMLOTBAI == "999"
  If EMP->( R_LOCK() )
    EMP->NUMLOTBAI := "000"
    EMP->( UN_LOCK() )
  EndIf
EndIf

mNumLote := StrZero(Val(EMP->NUMLOTBAI)+1,3)

Tone(220,1) ; Tone(320,1) ; Tone(420,1)

@ 16,37 Say "LOTBAIXA."+mNumLote

If AbreDBF
  If ! NET_USE("c:\datanet\fontes\SACADTIT.DBF","TIT",MultiUsu,.T.) ; Return(.F.) ; EndIf
EndIf

If ! File("c:\datanet\fontes\LOTBAIXA.&mNumLote.")
  aStru := { {"NUMMOV    ","C", 8,0},;
             {"TIPODOC   ","C", 2,0},;
             {"CODCLI    ","C", 6,0},;
             {"CODPOR    ","C", 3,0},;
             {"SITTIT    ","C", 2,0},;
             {"SITTIT2   ","C", 2,0},;
             {"COBRADOR  ","C", 4,0},;
             {"MODOBAIXA ","C", 1,0},;
             {"TIPPROTIT ","C", 1,0},;
             {"DTPAGTO   ","D", 8,0},;
             {"DTCHEPRE  ","D", 8,0},;
             {"VALPAGO   ","N",18,6},;
             {"VALDESJUR ","N",16,6},;
             {"SALDEVTIT ","N",16,6},;
             {"NUMNOTCRE ","C", 8,0},;
             {"NOSSONUM  ","C",20,0},;
             {"DTVENCTO  ","D", 8,0},;
             {"DTOCORR   ","D", 8,0},;
             {"DTCRED    ","D", 8,0},;
             {"VALCRED   ","N",12,2},;
             {"VALBRUTO  ","N",12,2},;
             {"VALTARIF  ","N",12,2},;
             {"IDENTIF   ","C",02,0},;
             {"CODMOV    ","C",02,0},;
             {"JUROS     ","N",12,2},;
             {"DESC      ","N",12,2},;
             {"ABAT      ","N",12,2},;
             {"COMPROV   ","C",20,0},;
             {"DATACOMPR ","D", 8,0},;
             {"VALORCOMP ","N",12,2},;
             {"IOF       ","N",12,2} }
  dbCreate( "c:\datanet\fontes\LOTBAIXA.&mNumLote.", aStru )
  AbreDBF := .T.
Else
  Return(.F.)
EndIf

If AbreDBF
  If ! NET_USE("c:\datanet\fontes\LOTBAIXA.&mNumLote.","LOT",.F.,.F.) ; Return(.F.) ; EndIf
  INDEX ON NUMMOV+TIPODOC+CODCLI TO c:\datanet\fontes\LOTINDEX.&mNumLote.
  LOT->( dbAppend() )     // para capa do lote
EndIf

If ! File("c:\datanet\fontes\SACADRET.DBF")
  aStru := { {"REGISTRO  ","C", 240,0} }
  dbCreate( "c:\datanet\fontes\SACADRET.DBF", aStru )
  AbreDBF := .T.
EndIf

If ! File("c:\datanet\fontes\AUX_RET.DBF")                   // Guarda as informacoes do relatorio
  aStru := { {"Nummov    ","C",08,0},;
             {"ORDEM_IMPR","C",02,0},;   // 
             {"SITTIT    ","C",02,0},;
             {"SITTIT2   ","C",02,0},;
             {"mNossoNum ","C",17,0},;
             {"DTVENCLIM ","D",08,0},;
             {"mValBruto ","N",12,2},;
             {"mValPago  ","N",12,2},;
             {"mValCred  ","N",12,2},;
             {"mDtCred   ","D",12,0},;
             {"mJuros    ","N",07,2},;
             {"mDesc     ","N",07,2},;
             {"mValTarif ","N",12,2},;
             {"mIOF      ","N",12,2},;
             {"mCodMov   ","C",02,0},;
             {"mIdentif  ","C",02,0} }
  dbCreate( "c:\datanet\fontes\AUX_RET.DBF", aStru )
  AbreDBF := .T.
EndIf

If AbreDBF
  If ! NET_USE("c:\datanet\fontes\SACADRET.DBF","RET",.F.,.F.) ; Return(.F.) ; EndIf
  If ! NET_USE("c:\datanet\fontes\AUX_RET.DBF","AUX",.F.,.F.) ; Return(.F.) ; EndIf
EndIf

AbreDBF := .F.

Select AUX
ZAP

Select RET
ZAP

APPEND FROM (xArquivo) DELIMITED

RET->( dbGoTo(2) )

mNumMov    := Space(08)          // Numero do t?tulo
xDtPagto   := CtoD(Space(08))    // Data do lote
mDtPagto   := CtoD("")           // Data de pagamento
mValPago   := 0.00               // Valor pago do titulo
xValPago   := 0.00               // Valor pago dos titulos "appendados"
mNumNotCre := 0.00               // Numero de titulos
xNumNotCre := 0.00               // Numero de titulos "appendados"

mNossoNum  := Space(17)          // nosso numero
mDtVencto  := CtoD("")           // Data de vencimento
mDtOcorr   := CtoD("")           // Data da ocorrencia
mDtCred    := CtoD("")           // Data da efetivacao do credito
mValCred   := 0.00               // Valor a ser creditado
mValBruto  := 0.00               // Valor do titulo
mValTxBan  := 0.00               // Valor da Taxa cobrada pelo Banco
mValTarif  := 0.00               // Valor da tarifa
mIdentif   := Space(02)          // Identificacao       (tabela 42)
mCodMov    := Space(02)          // Codigo de movimento (tabela 40)
mJuros     := 0.00               // Acrescimo
mDesc      := 0.00               // Descontos
mAbat      := 0.00               // Abatimento
mIof       := 0.00               // IOF recolhido
mCodOcorr  := space(4)           // Codigo da ocorrencia do sacado
mDtOcorr   := CtoD("")           // Data   da ocorrencia do sacado
mValOcorr  := 0.00               // Valor ocorrencia do sacado
mComplem   := space(30)          // compl.ocorrencia do sacado

lFlagBai  := .F.
While RET->( ! EOF() )
  *
  If ( SubStr(RET->REGISTRO,09,1) == "T" )   // 'T' equivale arquivo de retorno (pag 175)
    // HEADER DE LOTE SEGMENTO T

    xDia := SubStr(RET->REGISTRO,192,02)
    xMes := SubStr(RET->REGISTRO,194,02)
    xAno := SubStr(RET->REGISTRO,198,02)
    xDtPagto  := CtoD(xDia+"/"+xMes+"/"+xAno)
  *
  ELSEIf ( SubStr(RET->REGISTRO,14,1) == "T" .AND.;
           SubStr(RET->REGISTRO,16,2) $ "06,17" )  // c:\datanet\fontes\sedemiud\cobranca_cnab240
    // SEGMENTO T - // 06=LIQUIDAÇÃO NORMAL
	                // 17=ALTERAÇÃO DE DADOS REJEITADA (NOTA 25 - TABELA 2) 
					// 09=BAIXA SIMPLES 

    lFlagBai  := .T.
    mCodMov   := SubStr(RET->REGISTRO,16,2)
    mNossoNum := SubStr(RET->REGISTRO,38,17)

    //devido a carteira de sede ter mudado de 11 digitos para 17

    if len(alltrim(mnossonum)) < 17
      mNossoNum := SubStr(RET->REGISTRO,38,11)
    endif

    mNumMov   := SubStr(RET->REGISTRO,59,08)

    xDia := SubStr(RET->REGISTRO,74,02)
    xMes := SubStr(RET->REGISTRO,76,02)
    xAno := SubStr(RET->REGISTRO,80,02)
    mDtVencto := CtoD(xDia+"/"+xMes+"/"+xAno)

    mValBruto := val(SubStr(RET->REGISTRO,82,13)+"."+SubStr(RET->REGISTRO,95,02))
	mValTxBan := val(SubStr(RET->REGISTRO,199,13)+"."+SubStr(RET->REGISTRO,212,02))
    mIdentif  := SubStr(RET->REGISTRO,214,02)
  *
  ElseIf SubStr(RET->REGISTRO,14,1) == "U" .AND. lFlagBai
  // SEGMENTO U

    mJuros    := val(SubStr(RET->REGISTRO,18,13)+"."+SubStr(RET->REGISTRO,31,02))
    mDesc     := val(SubStr(RET->REGISTRO,33,13)+"."+SubStr(RET->REGISTRO,46,02))
    mIof      := val(SubStr(RET->REGISTRO,63,13)+"."+SubStr(RET->REGISTRO,76,02))
    mValPago  := val(SubStr(RET->REGISTRO,78,13)+"."+SubStr(RET->REGISTRO,91,02)) + mValTxBan
    mValCred  := val(SubStr(RET->REGISTRO,93,13)+"."+SubStr(RET->REGISTRO,106,02))

    xDia := SubStr(RET->REGISTRO,138,02)
    xMes := SubStr(RET->REGISTRO,140,02)
    xAno := SubStr(RET->REGISTRO,144,02)
    mDtOcorr := CtoD(xDia+"/"+xMes+"/"+xAno)
    mDtPagto := CtoD(xDia+"/"+xMes+"/"+xAno)

    xDia := SubStr(RET->REGISTRO,146,02)
    xMes := SubStr(RET->REGISTRO,148,02)
    xAno := SubStr(RET->REGISTRO,152,02)
    mDtCred  := CtoD(xDia+"/"+xMes+"/"+xAno)

    mCodOcorr := SubStr(RET->REGISTRO,154,4)     // tabela 44

    If mCodMov $ "06,17" .AND.;     // Liquidacao
       TIT->( dbSetOrder(13), dbSeek(mNossoNum) ) .and.;
       (TIT->SITTIT $ "AB-PC-PB")

      ++ xNumNotCre
      xValPago += mValPago

      Tone(220,1) ; Tone(320,1) ; Tone(420,1)

      mNumMov   := TIT->NUMMOV
      mDtVencto := TIT->DTVENCLIM
      @ 17,37 Say mNummov Pict "@R 999999-9/9"

      LOT->( dbAppend() )
      LOT->NUMMOV    := mNumMov
      LOT->TIPODOC   := TIT->TIPODOC
      LOT->CODCLI    := TIT->CODCLI
      if val(str(mValPago,12,2)) < val(str(TIT->VALBRUTO,12,2)) .and. tit->DESCANTEC = 0.00
        LOT->SITTIT    := "PB"
      else
        LOT->SITTIT    := "BB"
      endif
      LOT->SITTIT2   := tit->sittit
      LOT->MODOBAIXA := "1"
      LOT->DTPAGTO   := mDtPagto
      LOT->VALPAGO   := mValPago

      LOT->CODPOR    := TIT->CODPOR
      LOT->COBRADOR  := TIT->COBRADOR
      LOT->VALDESJUR := (mvalpago - (TIT->VALBRUTO - TIT->VALPARCPAG))
      LOT->SALDEVTIT := (TIT->VALBRUTO - TIT->VALPARCPAG)
      LOT->NOSSONUM  := mNossoNum
      LOT->DTVENCTO  := mDtVencto
      LOT->DTOCORR   := mDtOcorr
      LOT->DTCRED    := mDtCred
      LOT->VALCRED   := mValCred
      LOT->VALBRUTO  := mValBruto
      LOT->VALTARIF  := mValTarif
      LOT->IDENTIF   := mIdentif
      LOT->CODMOV    := mCodMov
      LOT->JUROS     := mJuros
      LOT->DESC      := mDesc
      LOT->ABAT      := mAbat
      LOT->IOF       := mIof
    EndIf
    lFlagBai  := .F.
  *
  ElseIf ( SubStr(RET->REGISTRO,8,1) == "9" )
  // (TRAILER)
  
    LOT->( dbGoTop() )
    LOT->CODCLI    := mNumLote
    LOT->DTPAGTO   := xDtPagto
    LOT->VALPAGO   := xValPago                   // valor total dos titulos
    LOT->NUMNOTCRE := AllTrim(Str(xNumNotCre,8)) // total de titulos "appendados"
    LOT->( dbDelete() )
  *
  EndIf

  RET->( dbSkip() )

Enddo

xPonto := AT( ".", aRetorno[opRetorno] )

xArqXXX := Left(aRetorno[opRetorno],xPonto-1)+".XXX"

ERASE  (xArqXXX)
RENAME (xArquivo) TO (xArqXXX)

If EMP->( R_LOCK() )
  EMP->NUMLOTBAI := mNumLote
  EMP->( UN_LOCK() )
EndIf

Return(.T.)
*
**
FUNCTION RETORNO(modo,elemento,pos_elem)
****************************************
fret := 2
IF modo >= 0 .AND. modo <= 2      // inativo/tent. ultrap. inicio/fim da lista
ELSEIF modo == 3                  // uma tecla de excessao foi pressionada
  IF LASTKEY() == 27
    fret := 0                    // pressionado ESC, aborta
  ELSEIF LASTKEY() == 13
    fret := 1                    // Executa selecao
  ELSEIF LASTKEY() == 01
    KEYBOARD CHR(31)             // press. HOME vai para o inicio da lista
  ELSEIF LASTKEY() == 06
    KEYBOARD CHR(30)             // press. END vai para o final da lista
  ENDIF
ENDIF
RETURN(fret)
*
**
FUNCTION NET_USE(marq,malias,muso,mind,grafico)
***********************************************
/*
ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¸
³ Tenta abrir um arquivo para uso exclusivo ou compartilhado.               ³
³ Passado os seguintes parametros:                                          ³
³   1. Caracter - Nome do arquivo (DBF) para abrir com sua extensao         ³
³   2  Caracter - Nome do ALIAS do arquivo. Se em branco, sem alias         ³
³   3. L¢gico   - Modo de abertura (Exclusivo = .F. / Nao exclusivo = .T.)  ³
³   4. L¢gico   - indica se existe ¡ndices                                  ³
³   5. Num‚rico - Numero de tentativas de abertura                          ³
³                                                                           ³
³ Obs.: Ao omitir o parametro do numero de tentativas, a funcao define = 10 ³
³                                                                           ³
³ Exemplo:                                                                  ³
³                                                                           ³
³   IF ! NET_USE("SGCADPRO.DBF","PRO",.T.,.T.,.T.)                          ³
³     RETURN                                                                ³
³   ENDIF                                                                   ³
ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¾
*/
 mtempoant := mtempo := 10
 grafico   := IIF(grafico == NIL,.F.,grafico)
 WHILE mtempo > 0

   IF ! FILE(marq)
     NET_ERRO("Arquivo "+marq+" n„o encontrado. Tecle [ENTER]",,.T.)
     EXIT
   ENDIF
   DBUSEAREA(.T.,,(marq),(malias),muso)

   *IF grafico ; GRAFICO() ; ENDIF

   IF ! NETERR()
     IF mind .AND. ! ABREINDEX( "c:\datanet\fontes\SAIND"+malias )
       EXIT
     ENDIF
     RETURN(.T.)
   ELSEIF ! multiusu
     MENSAGEM("Sistema n„o desenvolvido para ambiente de rede. Tecle [ENTER]",,.T.)
     EXIT
   ENDIF

   mtempo --
   IF mtempo == 0
     mtempo := NET_ERRO("Erro na abertura do arquivo "+marq+". Tentar de novo (S/N) ?")
   ENDIF
 ENDDO
RETURN(.F.)        // ----> Abertura sem sucesso
*
**
FUNCTION R_LOCK(mtempo)
***********************
/*
ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¸
³ Tenta travar o registro corrente                                          ³
³ Passagem do seguinte parametro                                            ³
³   1. Numerico - Numero de tentativas                                      ³
³                                                                           ³
³ Obs.: Ao omitir o parametro do numero de tentativas, a funcao define = 10 ³
³                                                                           ³
³ Exemplo:                                                                  ³
³                                                                           ³
³   IF R_LOCK(5)                                                            ³
³      REPCLACE Price WITH newprice                                         ³
³   ENDIF                                                                   ³
ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¾
*/
 IF multiusu
   mtempoant := mtempo := IIF(mtempo == NIL,10,mtempo)
   WHILE mtempo > 0
     IF RLOCK()
       RETURN(.T.)    // ----> Travado
     ENDIF
     mtempo --
     IF mtempo == 0
       mtempo := NET_ERRO("Erro no bloqueio do registro. Tentar de novo (S/N) ?")
     ENDIF
   ENDDO
 ELSE
   RETURN(.T.)
 ENDIF
RETURN(.F.)           // ----> Nao travado
*
**
FUNCTION UN_LOCK()
******************
/*
ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¸
³  Destravar registro e atualizar os buffers do servidor e da estacao        ³
³  Exemplo:                                                                  ³
³  IF R_LOCK(5)                                                              ³
³     REPCLACE Price WITH newprice                                           ³
³     UN_LOCK()                                                              ³
³  ENDIF                                                                     ³
ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¾
*/
DBCOMMIT()
DBGOTO(RECNO())
DBUNLOCK()
RETURN(.T.)
*
**
FUNCTION NET_ERRO(mmsg)
***********************
/*
ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¸
³ Exibe na tela o erro no processo de manuseio de arquivos em rede         ³
³ Passagem do seguinte parametro                                           ³
³   1. Mensagem - Mensagem de erro                                         ³
³ Obs. Exibe mensagem se o sistema foi compilado para mono usuario         ³
³      com tentativa de uso em rede                                        ³
ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¾
*/
 LOCAL tela := SAVESCREEN(00,00,24,79), mtempo := 0 , tecla := 0
 TONE(900) ; TONE(950) ; TONE(999)
 CENTRA(mmsg)
 WHILE ! CHR(tecla) $ "SsNn"+CHR(13)
   tecla := INKEY()
 ENDDO
 mtempo := IIF( CHR(tecla) $ "Ss", mtempoant, mtempo)
 RESTSCREEN(00,00,24,79,tela)
RETURN(mtempo)
*
**
FUNCTION ABREINDEX(mascind)
***************************
 CLOSE INDEX
 mascind := IIF("." $ mascind,mascind,mascind+".NSX")
 IF ! FILE(mascind)
   MENSAGEM("Ausˆncia de arquivos de ¡ndice do sistema. Tecle [ENTER]")
   RETURN(.F.)
 ENDIF
 DBSETINDEX(mascind)
 SET ORDER TO 1
RETURN(.T.)
*
**
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
 @ 24,00 SAY SPACE(80)
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
 @ 24,mcoluna SAY mtexto
 WHILE "[" $ mtexto
   mabre   := AT("[",mtexto)
   mfech   := AT("]",mtexto)
   mtecla1 := SUBST(mtexto,mabre,mfech-mabre+1)
   mtecla2 := " "+SUBST(mtecla1,2,LEN(mtecla1)-2)+" "
   mtecla3 := SUBST(mtecla1,2,LEN(mtecla1)-2)
   mtexto  := STRTRAN(mtexto,mtecla1,mtecla2)
   @ 24,mcoluna+mabre-1 SAY " "     COLOR "N/W"
   @ 24,mcoluna+mabre+0 SAY mtecla3 COLOR "N*/W"
   @ 24,mcoluna+mfech-1 SAY " "     COLOR "N/W"
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
 @ 24,00 SAY SPACE(80) ; @ 24,mcoluna SAY mtexto
 TONE(500,0.5)         ; SETCURSOR(1)
 mresp2  := mresp1
 @ 24,((mcoluna+LEN(mtexto))+1) GET mresp2 PICT "@! A" VALID mresp2 $ "SN"
 SET ESCAPE OFF
 READ
 SET ESCAPE ON
 CLEAR GETS
 TONE(200,1)
 SETCURSOR(cursorant); SetColor(lcCor)
RETURN(IIF(mresp2 = "S",.T.,.F.))
*
FUNCTION E_DDA(cReg)
********************
// .T. se algum dos 5 motivos de ocorrencia (pos. 214 a 223 do segmento T)
// for 'A4' = Pagador DDA (manual Safra CNAB 240 - Cobranca, Produto 500).
LOCAL i
FOR i := 0 TO 8 STEP 2
  IF SubStr(cReg,214+i,2) == "A4"
    RETURN(.T.)
  ENDIF
NEXT
RETURN(.F.)
*
**
FUNCTION IMPR_ARQ()
*******************
xArquivo := aRetorno[opRetorno]

MultiUsu := .T.

If ! NET_USE("c:\datanet\fontes\SACADTIT.DBF","TIT",MultiUsu,.T.) ; Return(.F.) ; EndIf

If ! File("c:\datanet\fontes\SACADRET.DBF")
  aStru := { {"REGISTRO  ","C", 240,0} }
  dbCreate( "SACADRET.DBF", aStru )
  AbreDBF := .T.
EndIf

// If ! File("AUX_RET.DBF")                   
ERASE c:\datanet\fontes\AUX_RET.DBF               // Importa dados do *.ret
  aStru := { {"Nummov    ","C",08,0},;
             {"ORDEM_IMPR","C",02,0},;   
             {"SITTIT    ","C",02,0},;
             {"SITTIT2   ","C",02,0},;
             {"mNossoNum ","C",17,0},;
             {"DTVENCLIM ","D",08,0},;
             {"mValBruto ","N",14,2},;
             {"mValPago  ","N",14,2},;
             {"mValCred  ","N",14,2},;
             {"mDtCred   ","D",14,0},;
             {"mJuros    ","N",07,2},;
             {"mDesc     ","N",07,2},;
             {"mValTarif ","N",14,2},;
             {"mIOF      ","N",14,2},;
             {"mCodMov   ","C",02,0},;
             {"mIdentif  ","C",02,0} }
  dbCreate( "c:\datanet\fontes\AUX_RET.DBF", aStru )
  AbreDBF := .T.
// EndIf

If AbreDBF
  If ! NET_USE("c:\datanet\fontes\SACADRET.DBF","RET",.F.,.F.) ; Return(.F.) ; EndIf
  If ! NET_USE("c:\datanet\fontes\AUX_RET.DBF","AUX",.F.,.F.) ; Return(.F.) ; EndIf
EndIf

AbreDBF := .F.

Select AUX
ZAP

Select RET
ZAP

APPEND FROM (xArquivo) DELIMITED    // importa os dados do arquivo *.ret

RET->( dbGoTo(2) )    // 

AbreDBF := .F.

mNumMov    := Space(08)          // Numero do t¡tulo
xDtPagto   := CtoD("")           // Data do lote
mDtPagto   := CtoD("")           // Data de pagamento
mValPago   := 0.00               // Valor pago do titulo
xValPago   := 0.00               // Valor pago dos titulos "appendados"
mNumNotCre := 0.00               // Numero de titulos
xNumNotCre := 0.00               // Numero de titulos "appendados"

mNossoNum  := Space(17)          // nosso numero
mDtVencto  := CtoD("")           // Data de vencimento
mDtOcorr   := CtoD("")           // Data da ocorrencia
mDtCred    := CtoD("")           // Data da efetivacao do credito
mValCred   := 0.00               // Valor a ser creditado
mValBruto  := 0.00               // Valor do titulo
mValTarif  := 0.00               // Valor da tarifa
mIdentif   := Space(02)          // Identificacao       (tabela 42)
mCodMov    := Space(02)          // Codigo de movimento (tabela 40)
mJuros     := 0.00               // Acrescimo
mDesc      := 0.00               // Descontos
mAbat      := 0.00               // Abatimento
mIof       := 0.00               // IOF recolhido
mCodOcorr  := space(4)           // Codigo da ocorrencia do sacado
mDtOcorr   := CtoD("")           // Data   da ocorrencia do sacado
mValOcorr  := 0.00               // Valor ocorrencia do sacado
mComplem   := space(30)          // compl.ocorrencia do sacado

cNossosNum := ""                 // concatena os nossos numeros. Usado para verificar pagamentos duplicados

CENTRA("Aguarde a Impressao. . .")
lFlagBai  := .F.
While RET->( ! EOF() )
  *
  If ( SubStr(RET->REGISTRO,09,1) == "T" )
    // HEADER DE LOTE SEGMENTO T

    xDia := SubStr(RET->REGISTRO,192,02)
    xMes := SubStr(RET->REGISTRO,194,02)
    xAno := SubStr(RET->REGISTRO,198,02)
    xDtPagto  := CtoD(xDia+"/"+xMes+"/"+xAno)
  *
  ELSEIf SubStr(RET->REGISTRO,14,1) == "T"
    // SEGMENTO T

    mCodMov   := SubStr(RET->REGISTRO,16,2)
    mNossoNum := SubStr(RET->REGISTRO,38,17)

    if len(alltrim(mnossonum)) < 17
      mNossoNum := SubStr(RET->REGISTRO,38,11)
    endif
	
    mNumMov   := SubStr(RET->REGISTRO,59,08)

    xDia := SubStr(RET->REGISTRO,74,02)
    xMes := SubStr(RET->REGISTRO,76,02)
    xAno := SubStr(RET->REGISTRO,80,02)
    mDtVencto := CtoD(xDia+"/"+xMes+"/"+xAno)

    mValBruto := val(SubStr(RET->REGISTRO,82,13)+"."+SubStr(RET->REGISTRO,95,02))
    mIdentif  := SubStr(RET->REGISTRO,214,02)    // Erros
    // 'A4' = Pagador DDA (informativo, nao e' erro). Pode vir em qualquer dos
    // 5 motivos (pos. 214-223); nos movimentos de erro (03,26,30) mantem o 1o codigo
    IF ! (mCodMov $ "03,26,30") .AND. E_DDA(RET->REGISTRO)
      mIdentif := "A4"
    ENDIF
  *
  ElseIf SubStr(RET->REGISTRO,14,1) == "U"
  // SEGMENTO U

    mJuros    := val(SubStr(RET->REGISTRO,18,13)+"."+SubStr(RET->REGISTRO,31,02))
    mDesc     := val(SubStr(RET->REGISTRO,33,13)+"."+SubStr(RET->REGISTRO,46,02))
    mIof      := val(SubStr(RET->REGISTRO,63,13)+"."+SubStr(RET->REGISTRO,76,02))
    mValPago  := val(SubStr(RET->REGISTRO,78,13)+"."+SubStr(RET->REGISTRO,91,02))
    mValCred  := val(SubStr(RET->REGISTRO,93,13)+"."+SubStr(RET->REGISTRO,106,02))

    xDia := SubStr(RET->REGISTRO,138,02)
    xMes := SubStr(RET->REGISTRO,140,02)
    xAno := SubStr(RET->REGISTRO,144,02)
    mDtOcorr := CtoD(xDia+"/"+xMes+"/"+xAno)
    mDtPagto := CtoD(xDia+"/"+xMes+"/"+xAno)

    xDia := SubStr(RET->REGISTRO,146,02)
    xMes := SubStr(RET->REGISTRO,148,02)
    xAno := SubStr(RET->REGISTRO,152,02)
    mDtCred  := CtoD(xDia+"/"+xMes+"/"+xAno)

    mCodOcorr := SubStr(RET->REGISTRO,154,4)     // tabela 44

    TIT->( dbSetOrder(13), dbSeek(mNossoNum) )

    ++ xNumNotCre

    mNumMov   := TIT->NUMMOV
    mDtVencto := TIT->DTVENCLIM
/*
 Movimento Tp  Nosso Numero       Vencto Vl_Titulo   Vl_Pago Vl_Credit Dt_Cred.  Acresc. Desconto Tarifa VL_IOF Codigo_Movimento Cd Tb.
111111/1-1 DP 12345678901       11/11/11 99.999,99 99.999,99 99.999,99 99/99/99 9.999,99 9.999,99 999,99 999,99 00               99 99a
0          11 14          26       35        45        55        65       74       83       92     99     106                    129132
*/
    AUX->(DBAPPEND())
	AUX->Nummov    := mNummov        
	AUX->SITTIT    := tit->SITTIT
	AUX->SITTIT2   := tit->SITTIT
	AUX->mNossoNum := mNossoNum
	AUX->DTVENCLIM := TIT->DTVENCLIM
	AUX->mValBruto := mValBruto      
	AUX->mValPago  := mValPago       
	AUX->mValCred  := mValCred       
	AUX->mDtCred   := mDtCred        
	AUX->mJuros    := mJuros         
	AUX->mDesc     := mDesc            
	AUX->mValTarif := mValPago-mValCred        
	AUX->mIOF      := mIOF             
    AUX->mCodMov   := if(mCodMov="17","06",mCodMov)
    AUX->mIdentif  := mIdentif
    AUX->ORDEM_IMPR:= IF(mCodMov=="02","05",;
                      IF(mCodMov=="03","06",;
                      IF(mCodMov=="04","07",;
                      IF(mCodMov=="05","08",;
                      IF(mCodMov=="06","00",;   
                      IF(mCodMov=="09","03",;  
                      IF(mCodMov=="11","11",;
                      IF(mCodMov=="12","12",;
                      IF(mCodMov=="13","13",;
                      IF(mCodMov=="14","14",;
                      IF(mCodMov=="15","15",;
                      IF(mCodMov=="17","00",;  
                      IF(mCodMov=="19","19",;
                      IF(mCodMov=="20","20",;
                      IF(mCodMov=="23","23",;
                      IF(mCodMov=="24","24",;
                      IF(mCodMov=="25","25",;
                      IF(mCodMov=="26","26",;
                      IF(mCodMov=="27","01",;
                      IF(mCodMov=="28","02",;
                      IF(mCodMov=="29","29",;
                      IF(mCodMov=="30","01",""))))))))))))))))))))))
	
    //IF empty(tit->retbanco) .or. (("Entr Confirm" $ tit->retbanco) .AND. (mCodMov <> "03"))  // Entr Rejeit
    IF empty(tit->retbanco) .or. (mCodMov <> "03")              // Entr Rejeit
    	tit->(rlock())
    
        tit->retbanco :=  IF(mCodMov=="02","Entr Confirm ",;
      				  IF(mCodMov=="03","Entr Rejeit  ",;
      				  IF(mCodMov=="04","Tranf.Cart/en",;
      				  IF(mCodMov=="05","Tranf.Cart/ba",;
      				  IF(mCodMov=="06","Liquidacao   ",;
      				  IF(mCodMov=="09","Baixa        ",;
      				  IF(mCodMov=="11","Tit carteira ",;
      				  IF(mCodMov=="12","Conf Abatim. ",;
      				  IF(mCodMov=="13","Conf Can Abat",;
      				  IF(mCodMov=="14","Conf Vencto  ",;
      				  IF(mCodMov=="15","Franco Pag   ",;
      				  IF(mCodMov=="17","Liquidacao   ",;
      				  IF(mCodMov=="19","Conf protesto",;
      				  IF(mCodMov=="20","canc. Prot.  ",;
      				  IF(mCodMov=="23","Remessa cart ",;
      				  IF(mCodMov=="24","Retir.cart   ",;
      				  IF(mCodMov=="25","Prot baixado ",;
      				  IF(mCodMov=="26","Instr rejeit ",;
      				  IF(mCodMov=="27","Alt dos dados",;
      				  IF(mCodMov=="28","Deb tarifas  ",;
      				  IF(mCodMov=="29","Ocorr sacado ",;
      				  IF(mCodMov=="30","Alt. dados   ",""))))))))))))))))))))))
        
		// os codigo de erro (mIdentif), estão no final desta página
		tit->retbanco :=  left(tit->retbanco,13)+" - "+mIdentif+" "+;
                  IF(mCodMov $ "03,26,30","47a",;
                  IF(mIdentif=="A4","DDA",;
                  IF(mCodMov $ "28","47b",;
                  IF(mCodMov $ "06,09,17","47c",""))))
    
        tit->(dbunlock())
    ENDIF
	
  ElseIf ( SubStr(RET->REGISTRO,8,1) == "9" )
  // (TRAILER)
  *
  EndIf

  RET->( dbSkip() )

Enddo

// AQUI, SÓ IMPRIME EM ARQUIVO (LOTB_&mLoteBAI.PRN), E SOMENTE DEPOIS É GERADO O LOTBAIXA.???
// OU SEJA, O CAMPO EMP->NUMLOTBAI, SÓ SERÁ SOMADO +1, NO MOMENTO QUE FOR GERADO O LOTBAIXA.???
// FICANDO ASSIM, O NOME DO LOTBAIXA.???, E O LOTB_???.PRN, USANDO O MESMO NÚMERO DE LOTE (EMP->NUMLOTBAI)+1.

USE SACADEMP.DBF ALIAS EMP NEW SHARED
mLoteBAI := StrZero(Val(EMP->NUMLOTBAI)+1,3)
CLOSE EMP

SELECT AUX
INDEX ON AUX->ORDEM_IMPR+AUX->mNossoNum TO c:\datanet\fontes\INDAUX.NSX
GO TOP

SET DEVICE TO PRINT
SET PRINTER TO c:\datanet\fontes\RETORNO\LOTB_&mLoteBAI.PRN
SET PRINT ON
SET CONSOLE OFF
?? CHR(15)
SETPRC(0,0)
mpag := 0
L := 0
xValbruto := xvalpago := xvalcred := xjuros := xdesc := xvaltarif := xiof := 0.00
yValbruto := yvalpago := yvalcred := yjuros := ydesc := yvaltarif := yiof := 0.00

@ 0,00 SAY "Relatorio de titulos retornados.  Arquivo: "+xArquivo+" - Data: "+dtoc(date())+" - Pagina: "+ALLTRIM(STR(++MPAG))
@ 0,00 SAY "Relatorio de titulos retornados.  Arquivo: "+xArquivo+" - Data: "+dtoc(date())+" - Pagina: "+ALLTRIM(STR(MPAG))
@ 2,01 SAY "Movimento Tp  Nosso Numero       Vencto Vl_Titulo   Vl_Pago Vl_Credit Dt_Cred.  Acresc. Desconto Tarifa VL_IOF Codigo_Movimento Cd Tb."
@ 3,00 SAY replicate("-",135)
L := 4

cOrdemImpr := AUX->ORDEM_IMPR
WHILE AUX->(! EOF())
/*
 Movimento Tp  Nosso Numero       Vencto Vl_Titulo   Vl_Pago Vl_Credit Dt_Cred.  Acresc. Desconto Tarifa VL_IOF Codigo_Movimento Cd Tb.
111111/1-1 DP 12345678901       11/11/11 99.999,99 99.999,99 99.999,99 99/99/99 9.999,99 9.999,99 999,99 999,99 00               99 99a
0          11 14          26       35        45        55        65       74       83       92     99     106                    129132
*/

  if (Empty(cCodMov) .or. (AUX->mCodMov $ cCodMov)) .and. (if(AUX->SITTIT="AB".and.lAbertos="N", .f. , .t. ))

    @ L,000 Say AUX->Nummov           Pict "@R 999999-9/9"
    @ L,011 Say AUX->SITTIT
    @ L,014 Say AUX->mNossoNum
    @ L,032 Say AUX->DTVENCLIM
    @ L,041 Say AUX->mValBruto         PICT "@E 99,999.99"
    @ L,051 Say AUX->mValPago          PICT "@E 99,999.99"
    @ L,061 Say AUX->mValCred          PICT "@E 99,999.99"
    @ L,071 Say AUX->mDtCred           
    @ L,080 Say AUX->mJuros            PICT "@E 9,999.99"
    @ L,089 Say AUX->mDesc             PICT "@E 9,999.99"
    @ L,098 Say AUX->mValTarif         PICT "@E 999.99"
    @ L,105 Say AUX->mIOF              PICT "@E 999.99"
    @ L,112 Say AUX->mCodMov+"-"+IF(AUX->mCodMov=="02","Entr Confirm ",;
                                 IF(AUX->mCodMov=="03","Entr Rejeit",;
                                 IF(AUX->mCodMov=="04","Tranf.Cart/en",;
                                 IF(AUX->mCodMov=="05","Tranf.Cart/ba",;
                                 IF(AUX->mCodMov=="06","Liquidacao",;
                                 IF(AUX->mCodMov=="09","Baixa",;
                                 IF(AUX->mCodMov=="11","Tit carteira",;
                                 IF(AUX->mCodMov=="12","Conf Abatim.",;
                                 IF(AUX->mCodMov=="13","Conf C. Abat",;
                                 IF(AUX->mCodMov=="14","Conf Vencto",;
                                 IF(AUX->mCodMov=="15","Franco Pag",;
                                 IF(AUX->mCodMov=="17","Liquidacao",;
                                 IF(AUX->mCodMov=="19","Conf protesto",;
                                 IF(AUX->mCodMov=="20","canc. Prot.",;
                                 IF(AUX->mCodMov=="23","Remessa cart",;
                                 IF(AUX->mCodMov=="24","Retir.cart",;
                                 IF(AUX->mCodMov=="25","Prot baixado",;
                                 IF(AUX->mCodMov=="26","Instr regeit",;
                                 IF(AUX->mCodMov=="27","Alt dos dados",;
                                 IF(AUX->mCodMov=="28","Deb tarifas",;
                                 IF(AUX->mCodMov=="29","Ocorr sacado",;
                                 IF(AUX->mCodMov=="30","Alt. dados ",""))))))))))))))))))))))

    @ L,129 Say AUX->mIdentif  // diz o resultado do processamento

	if mNossoNum $ cNossosNum .or. AUX->SITTIT $ "BB,BC,PC,PB,CA"              // Negrito
      @ L,000 Say AUX->Nummov           Pict "@R 999999-9/9"
      @ L,011 Say AUX->SITTIT
      @ L,014 Say AUX->mNossoNum
      @ L,032 Say AUX->DTVENCLIM
      @ L,041 Say AUX->mValBruto         PICT "@E 99,999.99"
      @ L,051 Say AUX->mValPago          PICT "@E 99,999.99"
      @ L,061 Say AUX->mValCred          PICT "@E 99,999.99"
      @ L,071 Say AUX->mDtCred           
      @ L,080 Say AUX->mJuros            PICT "@E 9,999.99"
      @ L,089 Say AUX->mDesc             PICT "@E 9,999.99"
      @ L,098 Say AUX->mValTarif         PICT "@E 999.99"
      @ L,105 Say AUX->mIOF              PICT "@E 999.99"
      @ L,112 Say AUX->mCodMov+"-"+IF(AUX->mCodMov=="02","Entr Confirm ",;
                                   IF(AUX->mCodMov=="03","Entr Rejeit",;
                                   IF(AUX->mCodMov=="04","Tranf.Cart/en",;
                                   IF(AUX->mCodMov=="05","Tranf.Cart/ba",;
                                   IF(AUX->mCodMov=="06","Liquidacao",;
                                   IF(AUX->mCodMov=="09","Baixa",;
                                   IF(AUX->mCodMov=="11","Tit carteira",;
                                   IF(AUX->mCodMov=="12","Conf Abatim.",;
                                   IF(AUX->mCodMov=="13","Conf C. Abat",;
                                   IF(AUX->mCodMov=="14","Conf Vencto",;
                                   IF(AUX->mCodMov=="15","Franco Pag",;
                                   IF(AUX->mCodMov=="17","Liquidacao",;
                                   IF(AUX->mCodMov=="19","Conf protesto",;
                                   IF(AUX->mCodMov=="20","canc. Prot.",;
                                   IF(AUX->mCodMov=="23","Remessa cart",;
                                   IF(AUX->mCodMov=="24","Retir.cart",;
                                   IF(AUX->mCodMov=="25","Prot baixado",;
                                   IF(AUX->mCodMov=="26","Instr regeit",;
                                   IF(AUX->mCodMov=="27","Alt dos dados",;
                                   IF(AUX->mCodMov=="28","Deb tarifas",;
                                   IF(AUX->mCodMov=="29","Ocorr sacado",;
                                   IF(AUX->mCodMov=="30","Alt. dados ",""))))))))))))))))))))))
	else
      cNossosNum += mNossoNum+","
	endif

    @ L++,132 Say IF(AUX->mCodMov $ "03,26,30","47a",;
                  IF(AUX->mIdentif=="A4","DDA",;
                  IF(AUX->mCodMov $ "28","47b",;
                  IF(AUX->mCodMov $ "06,09,17","47c",""))))

    xValbruto += AUX->mValbruto
    xvalpago  += AUX->mvalpago
    xvalcred  += AUX->mvalcred
    xjuros    += AUX->mjuros
    xdesc     += AUX->mdesc
    xvaltarif += AUX->mvaltarif
    xiof      += AUX->miof

    yValbruto += AUX->mValbruto
    yvalpago  += AUX->mvalpago
    yvalcred  += AUX->mvalcred
    yjuros    += AUX->mjuros
    ydesc     += AUX->mdesc
    yvaltarif += AUX->mvaltarif
    yiof      += AUX->miof

//    mValbruto := mvalpago := mvalcred := mjuros := mdesc := mvaltarif := miof := 0.00

    IF L > 56
      eject
      SETPRC(0,0)
      @ 0,00 SAY "Relatorio de titulos retornados.  Arquivo: "+xArquivo+" - Data: "+dtoc(date())+" - Pagina: "+ALLTRIM(STR(++MPAG))
      @ 0,00 SAY "Relatorio de titulos retornados.  Arquivo: "+xArquivo+" - Data: "+dtoc(date())+" - Pagina: "+ALLTRIM(STR(MPAG))
      @ 2,01 SAY "Movimento Tp  Nosso Numero       Vencto Vl_Titulo   Vl_Pago Vl_Credit Dt_Cred.  Acresc. Desconto Tarifa VL_IOF Codigo_Movimento Cd Tb."
      @ 3,00 SAY replicate("-",135)
      L := 4
    ENDIF
	
    AUX->( dbSkip() )	
	if cOrdemImpr <> AUX->ORDEM_IMPR .OR. AUX->(EOF()) 	
      cOrdemImpr := AUX->ORDEM_IMPR
      @ L,041 Say "---------"
      @ L,051 Say "---------"
      @ L,061 Say "---------"
      @ L,080 Say "--------"
      @ L,089 Say "--------"
      @ L,098 Say "------"
      @ L,105 Say "------"
      L++
      @ L,036 Say yValBruto  PICT "@E 99999999999.99"
      @ L,051 Say yValPago   PICT "@E 999999.99"
      @ L,061 Say yValCred   PICT "@E 999999.99"
      @ L,080 Say yJuros     PICT "@E 9,999.99"
      @ L,089 Say yDesc      PICT "@E 9,999.99"
      @ L,098 Say yValTarif  PICT "@E 999.99"
      @ L,105 Say yIOF       PICT "@E 999.99"
      L+=2
      yValbruto := yvalpago := yvalcred := yjuros := ydesc := yvaltarif := yiof := 0.00
    endif
  else
    AUX->( dbSkip() ) 
  endif
  
ENDDO

IF yValBruto <> xValBruto
  @ L,041 Say "---------"
  @ L,051 Say "---------"
  @ L,061 Say "---------"
  @ L,080 Say "--------"
  @ L,089 Say "--------"
  @ L,098 Say "------"
  @ L,105 Say "------"
  L++                             
  @ L,036 Say xValBruto  PICT "@E 99999999999.99"
  @ L,051 Say xValPago   PICT "@E 999999.99"
  @ L,061 Say xValCred   PICT "@E 999999.99"
  @ L,080 Say xJuros     PICT "@E 9,999.99"
  @ L,089 Say xDesc      PICT "@E 9,999.99"
  @ L,098 Say xValTarif  PICT "@E 999.99"
  @ L,105 Say xIOF       PICT "@E 999.99"
ENDIF

IF lGeralot
  L += 3
  @ L,00 SAY "**** Os NUMEROS DE MOVIMENTO encontrados, sera' gerado LOTE DE BAIXA"
  @ L,00 SAY "**** Os NUMEROS DE MOVIMENTO encontrados, sera' gerado LOTE DE BAIXA"
ENDIF

eject
?? CHR(18)
SETPRC(0,0)
SET DEVICE TO SCREEN
SET PRINTER TO
SET PRINT OFF
SET CONSOLE ON
close all
return(.t.)

/*
Tabela dos principais códigos de erro (ver mIdentif na atribuição da linha 886)

Para a ocorrência 03 — Entrada rejeitada, o manual apresenta, entre outros:

Código	Campo	Significado

03	Agência cobradora	Não foi possível atribuir agência pelo CEP ou CEP inválido
04	Estado	            Sigla do estado inválida
05	Data vencimento	    Prazo da operação menor que mínimo ou maior que máximo
08	Nome do pagador	    Não informado ou deslocado
09	Agência/Conta	    Agência encerrada
10	Logradouro			Não informado ou deslocado
11	CEP					CEP não numérico
13	Estado/CEP			CEP incompatível com UF
14	Nosso Número	    Já registrado no banco ou fora da faixa
15	Nosso Número	    Em duplicidade no mesmo movimento
18	Data de entrada		Inválida para a carteira
19	Ocorrência			Ocorrência inválida
21	Agência cobradora	Agência inválida/não cadastrada ou incompatibilidade
22	Carteira			Carteira não permitida
27	CNPJ inapto			CNPJ do beneficiário inapto
29	Código empresa		Categoria da conta inválida
31	Agência/Conta		Conta sem permissão para protestar
35	Valor IOF			IOF maior que 5%
36	Quantidade moeda	Incompatível com valor do título
37	CPF/CNPJ pagador	Não numérico ou igual a zeros
42	Nosso Número		Nosso Número fora de faixa
60	Abatimento			Valor inválido
61	Juros de mora		Maior que o permitido
62	Desconto			Maior que o valor do título
64	Emissão				Data de emissão inválida
66	Vencimento			Inválido/fora do prazo de operação
67	Valor/quantidade	Valor do título/quantidade de moeda inválido
68	Carteira			Inválida ou não cadastrada


Motivo 'A4' = Pagador DDA (informativo; vem com a ocorrencia 02 - Entrada Confirmada).
No relatorio aparece 'A4' na coluna Cd e 'DDA' na coluna Tb. Outros movimentos DDA do manual:
51=reconhecido pelo Pagador, 52=nao reconhecido, 53=recusado pela CIP.
*/