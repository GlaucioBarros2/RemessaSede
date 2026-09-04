# LECNABT — Leitor de Retorno CNAB240 (Itaú) em Clipper 5.2e

Programa em CA-Clipper 5.2e que varre a pasta `F:\DATANET` procurando os
arquivos de retorno CNAB240 do Banco Itaú (`IED*.RET`), processa-os em
ordem crescente de **data/hora de criação** e exibe na tela o conteúdo de
cada linha em que a **posição 14** do registro seja igual a **"T"**
(registro Segmento T), aguardando **2 segundos** entre cada linha exibida.

## Arquivos

- `src/LECNABT.PRG` — programa principal (usa apenas funções padrão do
  RTL do Clipper: `DIRECTORY()`, `ASORT()`, `FOPEN()`, `FREAD()`,
  `FCLOSE()`, `SECONDS()`, etc.).
- `src/COMPILA.BAT` — script de compilação/link (`CLIPPER` + `RTLINK`).

## Como funciona

1. `DIRECTORY("F:\DATANET\IED*.RET")` lista os arquivos que casam com a
   máscara, retornando nome, tamanho, data e hora de cada um.
2. O array resultante é ordenado com `ASORT()` usando um bloco de código
   que compara primeiro a data e, em caso de empate, a hora — colocando
   os arquivos mais antigos (criados primeiro) no início.
3. Cada arquivo é aberto em modo binário/leitura (`FOPEN`) e lido em
   blocos de 4000 bytes (`FREAD`), remontando as linhas conforme os
   caracteres de quebra (`CHR(13)+CHR(10)`) são encontrados. Essa leitura
   por blocos evita o limite de 64 KB de uma única string do Clipper,
   permitindo processar arquivos de retorno de qualquer tamanho.
4. Para cada linha lida, verifica-se `SUBSTR(cLinha, 14, 1)`. Quando o
   caractere é `"T"`, a linha completa é exibida na tela e o programa
   aguarda 2 segundos (função `Delay()`, baseada em `SECONDS()`) antes de
   continuar a leitura.
5. Ao final, é exibido um resumo com o total de arquivos processados e o
   total de registros Segmento T encontrados.

## Compilando

No prompt do DOS (ou emulador), dentro da pasta `src`:

```
COMPILA.BAT
```

Isso gera `LECNABT.EXE`, que pode ser executado diretamente (o caminho
`F:\DATANET` e a máscara `IED*.RET` estão definidos no início do
programa, em `#define`, caso seja necessário ajustá-los).

## Observações

- O DOS/Clipper não distingue "data de criação" de "data de modificação"
  do arquivo — `DIRECTORY()` retorna a data/hora do sistema de arquivos,
  que é usada aqui como critério de ordenação.
- A verificação da posição 14 é feita em qualquer linha do arquivo (não
  apenas nos registros de detalhe), conforme solicitado — ou seja, o
  critério de seleção é exclusivamente `SUBSTR(linha, 14, 1) == "T"`.
