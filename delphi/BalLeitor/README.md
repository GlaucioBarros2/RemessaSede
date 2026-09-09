# BalLeitor — Leitor de arquivos de balança (Delphi XE5)

Aplicativo console em Delphi XE5 que lê os arquivos `bal_*.txt` gerados
pela balança e, para cada um, gera um arquivo de saída `bal_*.XXX` com os
dados de produto já tratados.

## Formato de entrada (`bal_*.txt`)

```
sede.daniel;2026/09/09 11:15;2026/09/09 11:20
022763;0.000;A
020624;0.000;A
007956;4.000;V
005465;628.000;V
005057;620.000;A
020620;0.000;V
```

- **Linha 1**: cabeçalho (sede; data/hora início; data/hora fim) — sempre
  ignorado pelo programa.
- **Linha 2 em diante**: `código;quantidade;apresentação` — a
  apresentação é opcional.

## Regras aplicadas

- Somente as linhas a partir da 2ª são lidas.
- Em **quantidade**, apenas a parte inteira é gravada no arquivo de
  saída — o que vier depois do separador decimal é descartado (sem
  arredondamento): `628.000` → `628`, `4.000` → `4`, `0.000` → `0`.
- O arquivo de saída mantém o mesmo nome base do arquivo de entrada,
  apenas trocando a extensão para `.XXX` (constante `EXTENSAO_SAIDA` no
  início do `.dpr` — ajuste ali caso a extensão real precise ser outra).

Com o exemplo em `exemplo/bal_20260909.txt`, o programa gera
`exemplo/bal_20260909.XXX` com o conteúdo:

```
022763;0;A
020624;0;A
007956;4;V
005465;628;V
005057;620;A
020620;0;V
```

## Uso

```
BalLeitor.exe [pasta]
```

- Sem parâmetro: processa os arquivos `bal_*.txt` na mesma pasta do
  executável.
- Com parâmetro: processa os arquivos `bal_*.txt` na pasta informada,
  por exemplo `BalLeitor.exe C:\Balanca\Retorno`.

O programa varre todos os arquivos que casam com `bal_*.txt` na pasta,
gera o `.XXX` correspondente para cada um e exibe um resumo no console
(arquivos processados, linhas gravadas e eventuais avisos/erros por
arquivo — um arquivo com problema não interrompe o processamento dos
demais).

## Compilando

Abra `BalLeitor.dpr` no Delphi XE5 e compile (`Project > Build`), ou via
linha de comando com o `dcc32` do XE5:

```
dcc32 BalLeitor.dpr
```

## Observações / pontos de ajuste

- O separador decimal aceito na leitura é `.` ou `,` — o texto é
  cortado no primeiro separador encontrado, então isso não depende da
  configuração regional do Windows.
- Linhas em branco são ignoradas; linhas com menos de 2 campos
  (`código;quantidade`) geram um aviso no console e são puladas, sem
  interromper o processamento do arquivo.
- Se a extensão de saída não for literalmente `.XXX`, basta alterar a
  constante `EXTENSAO_SAIDA` no topo do `BalLeitor.dpr`.
