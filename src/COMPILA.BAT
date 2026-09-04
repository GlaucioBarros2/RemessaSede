@ECHO OFF
REM ---------------------------------------------------------------------
REM Compila e linka o LECNABT.PRG usando CA-Cl*pper 5.2e + RTLink
REM Execute a partir do prompt do DOS, dentro da pasta SRC.
REM ---------------------------------------------------------------------

CLIPPER LECNABT /N /W /M
IF ERRORLEVEL 1 GOTO FIM

RTLINK FI LECNABT LIB CLIPPER

:FIM
