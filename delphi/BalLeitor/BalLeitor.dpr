{-------------------------------------------------------------------------
  BalLeitor.dpr

  Aplicativo console em Delphi XE5 para leitura dos arquivos de balanca
  no padrao "bal_*.txt" e geracao, para cada um, de um arquivo de saida
  "bal_*.XXX" com os dados de produto ja tratados.

  Formato de entrada (arquivo bal_*.txt):

    Linha 1 (cabecalho, ignorada): sede;data/hora inicio;data/hora fim
      Ex.: sede.daniel;2026/09/09 11:15;2026/09/09 11:20

    Linha 2 em diante (dados a processar): codigo;quantidade;apresentacao
      apresentacao e opcional.
      Ex.: 022763;0.000;A
           005465;628.000;V

  Regras aplicadas:
    - A linha 1 (cabecalho) e sempre ignorada.
    - Em "quantidade", apenas a parte inteira e considerada na gravacao
      (628.000 -> 628, 4.000 -> 4), sem arredondamento: tudo o que vier
      depois do separador decimal e simplesmente descartado.
    - O arquivo de saida mantem o mesmo nome base do arquivo de entrada,
      trocando apenas a extensao para ".XXX" (constante EXTENSAO_SAIDA,
      caso seja necessario ajustar para outra extensao).

  Uso:
    BalLeitor.exe [pasta]

    Se "pasta" nao for informada, o programa processa os arquivos
    bal_*.txt localizados na mesma pasta do executavel.
-------------------------------------------------------------------------}

program BalLeitor;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types;

const
  MASCARA_ENTRADA = 'bal_*.txt';
  EXTENSAO_SAIDA  = '.XXX';

{-------------------------------------------------------------------------
  Retorna a pasta a ser processada: o primeiro parametro de linha de
  comando, se informado, ou a pasta do proprio executavel.
-------------------------------------------------------------------------}
function PastaProcessamento: string;
begin
  if ParamCount >= 1 then
    Result := IncludeTrailingPathDelimiter(ParamStr(1))
  else
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

{-------------------------------------------------------------------------
  Retorna apenas a parte inteira do texto de quantidade, descartando
  tudo a partir do separador decimal (ponto ou virgula), sem arredondar.
  Ex.: '628.000' -> 628 | '4.000' -> 4 | '0.000' -> 0
-------------------------------------------------------------------------}
function ParteInteira(const cValor: string): Integer;
var
  cLimpo: string;
  nPos: Integer;
begin
  cLimpo := Trim(cValor);

  nPos := Pos('.', cLimpo);
  if nPos = 0 then
    nPos := Pos(',', cLimpo);

  if nPos > 0 then
    cLimpo := Copy(cLimpo, 1, nPos - 1);

  Result := StrToIntDef(Trim(cLimpo), 0);
end;

{-------------------------------------------------------------------------
  Le um arquivo bal_*.txt, monta as linhas ja tratadas (a partir da
  linha 2) e grava o arquivo de saida correspondente (bal_*.XXX).
-------------------------------------------------------------------------}
procedure ProcessarArquivo(const cArqEntrada: string);
var
  slEntrada, slSaida: TStringList;
  i: Integer;
  cLinha, cArqSaida: string;
  aCampos: TArray<string>;
  cCodigo, cApresentacao: string;
  nQuantidade: Integer;
  nLinhasLidas, nLinhasGravadas: Integer;
begin
  slEntrada := TStringList.Create;
  slSaida   := TStringList.Create;
  try
    slEntrada.LoadFromFile(cArqEntrada);

    if slEntrada.Count < 2 then
    begin
      Writeln('  Arquivo sem registros de produto (so ha cabecalho): ' +
        ExtractFileName(cArqEntrada));
      Exit;
    end;

    nLinhasLidas    := 0;
    nLinhasGravadas := 0;

    // Processa a partir da linha 2 (indice 1), ignorando o cabecalho (linha 1)
    for i := 1 to slEntrada.Count - 1 do
    begin
      cLinha := Trim(slEntrada[i]);
      if cLinha = '' then
        Continue;

      Inc(nLinhasLidas);
      aCampos := cLinha.Split([';']);

      if Length(aCampos) < 2 then
      begin
        Writeln(Format('  [AVISO] Linha %d ignorada (formato invalido): %s',
          [i + 1, cLinha]));
        Continue;
      end;

      cCodigo     := Trim(aCampos[0]);
      nQuantidade := ParteInteira(aCampos[1]);

      cApresentacao := '';
      if Length(aCampos) >= 3 then
        cApresentacao := Trim(aCampos[2]);

      if cApresentacao <> '' then
        slSaida.Add(Format('%s;%d;%s', [cCodigo, nQuantidade, cApresentacao]))
      else
        slSaida.Add(Format('%s;%d', [cCodigo, nQuantidade]));

      Inc(nLinhasGravadas);
    end;

    cArqSaida := ChangeFileExt(cArqEntrada, EXTENSAO_SAIDA);
    slSaida.SaveToFile(cArqSaida);

    Writeln(Format('  OK: %s -> %s  (%d de %d linhas gravadas)',
      [ExtractFileName(cArqEntrada), ExtractFileName(cArqSaida),
       nLinhasGravadas, nLinhasLidas]));
  finally
    slEntrada.Free;
    slSaida.Free;
  end;
end;

var
  cPasta: string;
  aArquivos: TStringDynArray;
  cArquivo: string;
  nTotal: Integer;
begin
  try
    cPasta := PastaProcessamento;

    Writeln('==================================================================');
    Writeln(' LEITOR DE ARQUIVOS DE BALANCA (' + MASCARA_ENTRADA + ')');
    Writeln(' Pasta: ' + cPasta);
    Writeln('==================================================================');
    Writeln;

    if not TDirectory.Exists(cPasta) then
    begin
      Writeln('Pasta nao encontrada: ' + cPasta);
      Exit;
    end;

    aArquivos := TDirectory.GetFiles(cPasta, MASCARA_ENTRADA);
    nTotal := 0;

    if Length(aArquivos) = 0 then
      Writeln('Nenhum arquivo ' + MASCARA_ENTRADA + ' encontrado.')
    else
      for cArquivo in aArquivos do
      begin
        try
          ProcessarArquivo(cArquivo);
          Inc(nTotal);
        except
          on E: Exception do
            Writeln('  [ERRO] ' + ExtractFileName(cArquivo) + ': ' + E.Message);
        end;
      end;

    Writeln;
    Writeln('------------------------------------------------------------------');
    Writeln(Format('Arquivos processados: %d', [nTotal]));
    Writeln('------------------------------------------------------------------');
  except
    on E: Exception do
      Writeln('ERRO FATAL: ' + E.ClassName + ': ' + E.Message);
  end;

  {$IFDEF DEBUG}
  Writeln;
  Writeln('Pressione ENTER para sair...');
  Readln;
  {$ENDIF}
end.
