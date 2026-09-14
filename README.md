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

# REMESSA — Gerador de Remessa CNAB240 (Itaú, Banco do Brasil e Safra)

Programa em CA-Clipper/xHarbour (`src/REMESSA.PRG`) que monta e exibe os
títulos a enviar (entrada, baixa, protesto, etc.) e gera o arquivo de
remessa CNAB240 (`REMESSA.<código do banco>`) a partir das tabelas
`SACADTIT`/`SACADCLI`/`SACADSET`/`SACADEMP`.

## Bancos suportados

- **341 — Banco Itaú SA**
- **001 — Banco do Brasil**
- **422 — Banco Safra SA** *(adicionado seguindo o mesmo padrão dos
  bancos acima)*

A escolha do banco é feita no menu inicial (`opcaoB`), que define
`cBanco1` (código do banco) e `cBanco2` (nome do banco), usados em
seguida para selecionar o layout correto de cada registro (header de
arquivo, header de lote, segmentos P/Q, trailers).

## Sobre o suporte ao Banco Safra

O bloco do Safra foi implementado espelhando a estrutura já existente
para Itaú/BB (mesmo padrão de `if cBanco1 = "001" / elseif "341" / else`
em cada registro do CNAB240: header de arquivo, header de lote, segmento
P e cálculo do dígito verificador do nosso número). Como não havia à
disposição o manual de instruções técnico do Safra nem os dados reais do
convênio, os seguintes pontos ficam com **valores placeholder** e
comentários `// TODO SAFRA` no código, para revisão antes de uso em
produção:

- **Convênio/agência/conta** (`cConv`, `cAgen`, `cCont` no bloco do
  Safra dentro de `GER_ARQUIVO()`, e os campos correspondentes no header
  de lote e no segmento P) — hoje preenchidos com zeros/brancos.
- **Código da carteira** usado no segmento P (`"01"` fixo) — deve ser
  confirmado com o banco.
- **Prefixo do nosso número** (`"422"`), usado apenas internamente pelo
  programa para filtrar quais títulos pertencem à carteira Safra dentro
  da tabela `SACADTIT` (mesma lógica hoje usada com `"140"` para BB e
  `"109"` para Itaú) — pode ser ajustado para outro valor se a empresa
  preferir outra convenção.
- **Dígito verificador do nosso número**: foi criada a função
  `DIGITOMOD11()`, que aplica o Módulo 11 padrão FEBRABAN (pesos 2 a 7,
  cíclicos) como "melhor palpite" na ausência do manual do Safra. O
  Safra pode usar Módulo 10 (a mesma função `DIGITO()` já usada para o
  Itaú) ou regras próprias de Módulo 11 (por exemplo, DV `"P"` quando o
  resto da divisão é 10). **Confirme o algoritmo correto com o manual
  técnico CNAB240 do Safra antes de gerar remessas reais.**

Os registros que já eram genéricos/independentes de banco (segmento Q,
trailer de lote — registro 5 — e trailer de arquivo — registro 9) não
precisaram de bloco específico para o Safra: eles usam as mesmas
variáveis (`cBanco1`, totais calculados dinamicamente) e já funcionam
para qualquer banco selecionado.
