*=========================================================================
* LECNABT.PRG
*
* Leitor de arquivos de RETORNO CNAB240 do Banco Ita�, gerados na pasta
* F:\DATANET com o padr�o de nome IED*.RET.
*
* Para cada arquivo (processados em ordem crescente de data/hora de
* cria��o), o programa l� o conte�do linha a linha e, sempre que o
* caractere localizado na POSI��O 14 do registro for igual a "T"
* (registro do tipo "Segmento T"), exibe a linha na tela, aguardando
* 2 segundos entre uma linha exibida e outra.
*
* Compat�vel com CA-Cl*pper 5.2e (apenas fun��es padr�o do RTL).
*=========================================================================

#define CTAB_PASTA     "F:\DATANET\"
#define CTAB_MASCARA   "IED*.RET"
#define CTAB_BUFSIZE   4000
#define CTAB_POSSEG    14
#define CTAB_SEGMENTO  "T"
#define CTAB_ATRASO    2

*-------------------------------------------------------------------------
FUNCTION Main()

   LOCAL aArquivos
   LOCAL nArq
   LOCAL cArquivo
   LOCAL nHandle
   LOCAL cBuffer
   LOCAL cChunk
   LOCAL nLidos
   LOCAL nPosNL
   LOCAL cLinha
   LOCAL nNumLinha
   LOCAL nTotalArq   := 0
   LOCAL nTotalSegT  := 0

   CLS
   SET SCOREBOARD OFF

   ? "======================================================================="
   ? " LEITOR DE RETORNO CNAB240 - BANCO ITAU - REGISTROS SEGMENTO T"
   ? " Pasta..: " + CTAB_PASTA
   ? " Mascara: " + CTAB_MASCARA
   ? "======================================================================="
   ?

   * Localiza os arquivos de retorno na pasta informada
   aArquivos := DIRECTORY(CTAB_PASTA + CTAB_MASCARA)

   IF EMPTY(aArquivos)
      ? "Nenhum arquivo " + CTAB_MASCARA + " localizado em " + CTAB_PASTA
      ?
      ? "Pressione qualquer tecla para sair..."
      INKEY(0)
      RETURN NIL
   ENDIF

   * Classifica o array de arquivos em ordem crescente de data/hora de
   * cria��o (campos [3]=data e [4]=hora retornados pela DIRECTORY())
   ASORT(aArquivos, , , { |x, y| IIF(x[3] == y[3], x[4] < y[4], x[3] < y[3]) })

   * Percorre os arquivos j� classificados por data de cria��o
   FOR nArq := 1 TO LEN(aArquivos)

      cArquivo := CTAB_PASTA + ALLTRIM(aArquivos[nArq, 1])
      nHandle  := FOPEN(cArquivo, 0)          && 0 = abre somente leitura

      IF nHandle == -1
         ? "Erro ao abrir o arquivo " + cArquivo + " (FERROR = " + LTRIM(STR(FERROR())) + ")"
         LOOP
      ENDIF

      nTotalArq++
      nNumLinha := 0
      cBuffer   := ""

      ?
      ? "Arquivo: " + aArquivos[nArq, 1] + ;
        "   Data/Cria��o: " + DTOC(aArquivos[nArq, 3]) + " " + aArquivos[nArq, 4]
      ? REPLICATE("-", 73)

      * L� o arquivo em blocos, montando o buffer e extraindo as linhas
      * completas (terminadas em CHR(10)) conforme v�o ficando dispon�veis.
      * Essa abordagem evita o limite de 64K de uma �nica string do
      * Cl*pper mesmo em arquivos de retorno grandes.
      DO WHILE .T.

         cChunk := SPACE(CTAB_BUFSIZE)
         nLidos := FREAD(nHandle, @cChunk, CTAB_BUFSIZE)

         IF nLidos > 0
            cBuffer += SUBSTR(cChunk, 1, nLidos)
         ENDIF

         DO WHILE (nPosNL := AT(CHR(10), cBuffer)) > 0

            cLinha  := SUBSTR(cBuffer, 1, nPosNL - 1)
            cBuffer := SUBSTR(cBuffer, nPosNL + 1)

            IF RIGHT(cLinha, 1) == CHR(13)
               cLinha := SUBSTR(cLinha, 1, LEN(cLinha) - 1)
            ENDIF

            nNumLinha++

            IF LEN(cLinha) >= CTAB_POSSEG .AND. ;
               UPPER(SUBSTR(cLinha, CTAB_POSSEG, 1)) == CTAB_SEGMENTO

               nTotalSegT++
               ? "Linha " + PADL(LTRIM(STR(nNumLinha)), 5, "0") + ;
                 " [Segmento " + CTAB_SEGMENTO + "] -> " + cLinha
               Delay(CTAB_ATRASO)
            ENDIF

         ENDDO

         IF nLidos < CTAB_BUFSIZE
            EXIT                              && fim do arquivo
         ENDIF

      ENDDO

      * Trata a �ltima linha, caso o arquivo n�o termine com quebra de linha
      IF !EMPTY(cBuffer)
         cLinha := cBuffer
         nNumLinha++
         IF LEN(cLinha) >= CTAB_POSSEG .AND. ;
            UPPER(SUBSTR(cLinha, CTAB_POSSEG, 1)) == CTAB_SEGMENTO

            nTotalSegT++
            ? "Linha " + PADL(LTRIM(STR(nNumLinha)), 5, "0") + ;
              " [Segmento " + CTAB_SEGMENTO + "] -> " + cLinha
            Delay(CTAB_ATRASO)
         ENDIF
      ENDIF

      FCLOSE(nHandle)

   NEXT nArq

   ?
   ? REPLICATE("=", 73)
   ? "Arquivos processados....: " + LTRIM(STR(nTotalArq))
   ? "Registros Segmento T....: " + LTRIM(STR(nTotalSegT))
   ? REPLICATE("=", 73)
   ?
   ? "Pressione qualquer tecla para sair..."
   INKEY(0)

RETURN NIL

*-------------------------------------------------------------------------
* Delay(nSegundos) - aguarda o n�mero de segundos informado, sem travar
* o sistema, com base no rel�gio do DOS (fun��o padr�o SECONDS()).
*-------------------------------------------------------------------------
FUNCTION Delay(nSegundos)

   LOCAL nInicio := SECONDS()

   DO WHILE SECONDS() - nInicio < nSegundos
      * aguardando o intervalo solicitado
   ENDDO

RETURN NIL
