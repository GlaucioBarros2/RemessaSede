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
remessa CNAB240 a partir das tabelas
`SACADTIT`/`SACADCLI`/`SACADSET`/`SACADEMP`. O nome do arquivo gerado
depende do banco escolhido: `REMESSA.<código do banco>` para Itaú e BB
(ex.: `REMESSA.341`, `REMESSA.001`), e **`REMSAFRA.<código do banco>`**
para o Safra (ex.: `REMSAFRA.422`), para ficar visualmente claro de
qual banco é o arquivo mesmo sem abrir o conteúdo.

## Bancos suportados

Menu de seleção (`opcaoB`), nesta ordem:

1. **341 — Banco Itaú SA**
2. **422 — Banco Safra SA** *(adicionado seguindo o mesmo padrão dos
  bancos acima)*
3. **001 — Banco do Brasil**

A escolha do banco define `cBanco1` (código do banco), `cBanco2` (nome
do banco) e `cNomeArq` (nome-base do arquivo gerado), usados em
seguida para selecionar o layout correto de cada registro (header de
arquivo, header de lote, segmentos P/Q, trailers).

## Sem acentuação no código-fonte

O programa não usa mais nenhum caractere acentuado (á, é, ã, ç, etc.)
em suas mensagens de tela nem em comentários — foram substituídos
pelo equivalente sem acento (ex.: "Emissão" → "Emissao"). Isso evita
problemas de exibição na tela do MS-DOS quando o arquivo é editado em
ferramentas que usam páginas de código diferentes da usada originalmente.
Os caracteres de desenho de caixa/moldura (`DISPBOX()`, `DBEDIT()`,
`F_BOX()`) continuam usando os bytes da página de código OEM/DOS
original — esses **não** são caracteres acentuados, são símbolos de
desenho (linhas/cantos de caixa) que não têm equivalente sem acento.

## Sobre o suporte ao Banco Safra

O bloco do Safra foi implementado com base no manual oficial **"Cobrança
Safra — Guia para implantação de transmissão e troca de arquivos —
Layout padrão Safra CNAB 240"**, posição a posição, seguindo o mesmo
padrão estrutural já usado para Itaú/BB (`if cBanco1 = "001" / elseif
"341" / else` em cada registro: header de arquivo, header de lote,
segmento P; o segmento Q já era genérico e vale para os três bancos).

### Confirmado pelo manual (já implementado com os valores corretos)

- Header de Arquivo (registro 0) e Header de Lote (registro 1): CNPJ,
  nome da empresa, "BANCO SAFRA S/A", código remessa, datas, número
  sequencial, versão do layout do lote (`060`), hora de geração fixa em
  `000000` (o manual pede explicitamente, ao contrário de BB/Itaú que
  usam a hora real) e data do crédito fixa em `00000000`.
- Segmento P: carteira `1` (Cobrança Simples), forma de cadastro `1`
  (Cobrança Registrada), tipo de documento `2` (Escritural), espécie do
  título mapeada a partir de `TIT->TIPODOC` (a Safra recusa `99`
  "Outros", diferente do Itaú — ver seção de correções abaixo), moeda
  `09` (Real), IOF e abatimento zerados (Safra não aceita abatimento na
  entrada do título), código de juros/desconto conforme haja ou não
  `cJurDia`/`cDesFin` calculados.
- **Nosso Número**: o manual confirma que no Safra ele é **livre** — 9
  dígitos escolhidos pela empresa (posições 38 a 46 do segmento P), sem
  nenhum dígito verificador calculado pelo banco (isso só existe na
  "Cobrança Convencional", onde o próprio Safra emite o boleto e
  preenche zeros nessas posições). Por isso **não há função de DV**
  para o Safra (a tentativa anterior com Módulo 11 foi removida por não
  ser necessária). O programa usa como nosso número os 9 caracteres do
  campo `TIT->NOSSONUM`, na mesma convenção interna já usada para os
  outros bancos: prefixo `"422"` + 6 dígitos sequenciais.
- Trailer de Lote (registro 5): a contagem em 018-023 **soma "+2"** ao
  total de registros de detalhe (contando também o header e o trailer
  do lote), igual ao Itaú/BB — apesar do texto do manual sugerir que
  seria só a contagem de detalhe, o relatório de validação real da
  Safra confirmou que o "+2" é necessário (ver seção de correções
  abaixo).

### Corrigido a partir do relatório de validação real da Safra

O primeiro arquivo de teste (`REMSAFRA.422`) gerado com os dados acima
foi validado pela mesa de implantação do Safra e retornou 9 erros
graves (categoria X, recusam o arquivo) e 2 informativos (categoria
Y). Todos foram corrigidos:

- **Agência** (posições 053-057 do header de arquivo, 054-058 do
  header de lote, 018-022 e 101-105 do segmento P): o valor correto é
  `14400`, não `00144` — o número de agência informado (`0144`) sozinho
  não é o valor completo que a Safra espera nesse campo.
- **Espécie do Título** (posição 107-108 do segmento P): a Safra
  **recusa** `"99" (Outros)`, apesar do manual genérico listar essa
  opção — exige um código específico (`02`=DM Duplicata Mercantil,
  `04`=DS Duplicata de Serviço, `12`=NP, `16`=NS, `17`=RC). O código
  agora mapeia `TIT->TIPODOC`: `"DP"→"02"`, `"DC"→"04"`, e usa `"17"`
  como padrão para `"OR"` — **a confirmar** qual código a empresa
  realmente usa para títulos com tipodoc `"OR"`.
- **Segmento Q — Sacador/Avalista** (posições 154, 155-169, 170-209):
  o bloco do Safra preenchia esses campos com o CNPJ/nome da própria
  empresa (mesma convenção herdada do bloco do Itaú/BB) — a Safra
  recusa isso. Como a empresa não opera com Factoring (sem
  sacador/avalista), o Safra exige Tipo de Inscrição `"0"` (não
  informado), Número de Inscrição zerado e Nome do Beneficiário Final
  em branco. **Isso só foi corrigido para o Safra** — o bloco do Itaú
  continua preenchendo esses campos com os dados da empresa, exatamente
  como antes (o segmento Q deixou de ser compartilhado entre os dois
  bancos).
- **Trailer de Lote, Quantidade de Registros** (posição 018-023): a
  Safra recusou `"000006"` e pediu `"000008"` — a fórmula mudou de
  `Csequenc` para `Csequenc+2`, igual ao Itaú/BB (ver observação acima).
- **Trailer de Lote, Valor Total dos Títulos em Carteiras** (posição
  099-115): a Safra pediu zeros (`"00000000000000000"`), não espaços em
  branco.

Também identifiquei (mas **não** é um problema de código, é só um
detalhe de uso): a Safra recusa título com vencimento anterior à data
de validação/envio do arquivo — ao gerar uma remessa de teste, use
datas de vencimento atuais ou futuras.

### Já preenchido com dados reais

- **Agência, conta corrente e dígito verificador da conta**
  (`cAgenSaf`, `cContSaf`, `cContDVSaf`, definidos em `GER_ARQUIVO()`) —
  agência `14400`, conta `00587488-9`.

### Ainda como placeholder — TODO antes de produção

- **Versão do layout do arquivo** (posições 164-166 do header de
  arquivo): o manual lista 3 opções válidas (`084`, `087` ou `103`) sem
  indicar qual usar — o código está com `"084"`, a confirmar com a Mesa
  de Implantação do Safra.
- **Modalidade de cobrança** (Convencional × Direta): o código assume
  **Cobrança Direta** (a empresa emite e distribui o próprio boleto,
  como já é feito hoje para Itaú/BB), preenchendo "Identificação da
  Emissão do Bloqueto" (pos. 61) e "Identificação da Distribuição" (pos.
  62) com `"2"` (cliente). Se a empresa for operar em Cobrança
  Convencional (Safra emite o boleto), essas posições mudam para `"1"`
  e o nosso número (posições 38-46) deve ser preenchido com zeros.
- **Código para Baixa/Devolução** (posição 224): está em `"2"` (não
  baixar e não devolver) como opção conservadora — ajustar para `"1"`
  (baixar e devolver) e preencher a quantidade de dias (posições
  225-227, hoje `"000"`) se a empresa quiser que o Safra baixe
  automaticamente títulos não pagos.
- **Uso livre banco/empresa** (posição 240): está em `"1"` (não
  autoriza pagamento parcial) — ajustar para `"2"` se a empresa quiser
  autorizar pagamento parcial dos títulos.

Esses pontos estão marcados com comentários `// TODO SAFRA` no código
(em `src/REMESSA.PRG`).

O trailer de arquivo (registro 9) não precisou de bloco específico para
o Safra: a fórmula já genérica (baseada em `Csequenc`) bate com o que o
manual do Safra pede.

# UnitImBoletoMes — Impressão do Boleto (Delphi 7)

`delphi/ImBoletoMes/UnitImBoletoMes.pas` é a tela Delphi 7 que gera o PDF
do boleto (via RaveReports) para o título informado, incluindo código de
barras e linha digitável, hoje para Itaú e BB.

## Suporte ao Banco Safra

Foi adicionado suporte ao Safra (código `422`) **sem alterar nenhuma
linha existente** do arquivo — toda a lógica de BB/Itaú permanece
idêntica; apenas novos blocos `else if CODPOR = '422' then ...` foram
inseridos ao lado dos já existentes. O layout visual (imagem do boleto,
posições `PrintXY`, funções `Modulo10`/`CalcDigVerificador`/`PadL`) segue
o mesmo padrão já usado para o Itaú, por pedido explícito; a única parte
onde o Safra usa uma composição própria é a montagem do "campo livre" do
código de barras (`GeraCodBarra2de5`), pois o layout real do Safra
(`F + Agência(4) + Conta(10) + Nosso Número(9) + F`, conforme o manual
"Cobrança Safra — Layout Padrão Safra CNAB 240", pág. 22) é diferente da
composição usada pelo Itaú (`carteira + nosso número + DAC1 + agência +
conta + DAC2 + "000"`) — usar a mesma fórmula do Itaú geraria um código
de barras com 2 dígitos a menos que os 44 exigidos. A fatiamento da linha
digitável (`LinhaDigitavel`), por ser puramente posicional (não depende
do significado de cada sub-campo), foi reaproveitado exatamente igual ao
do Itaú.

**Corrigido a partir do relatório de validação real da Safra** (o mesmo
relatório usado para corrigir o `REMESSA.PRG` — ver seção
correspondente acima — trazia uma comparação "Informado x Correto" do
código de barras gerado por este arquivo):

- **Agência**: `cAgSafra` era `'0144'`, correto é `'1440'`.
- **Conta no código de barras**: `cContaSafra` (10 dígitos) era
  `'0000587488'` (conta zero-padded, sem o DV) — o correto é conta+DV
  concatenados: `'0005874889'` (renomeada para `cContaBarraSafra`,
  usada só na montagem do código de barras). Para o rótulo impresso
  (agência/conta legível), `cContaSafra` agora guarda só a conta pura
  (`'00587488'`, 8 dígitos), e o DV continua em `cContaDVSafra` (`'9'`).
- **Dígitos "F" (posições 20 e 44 do código de barras)**: não eram de
  uso livre como o manual sugeria — comparando o "Informado x Correto"
  do relatório, a posição 20 é o dígito verificador Módulo 10 da
  Agência sozinha, e a posição 44 é o Módulo 10 de (posição20 +
  Agência + Conta + Nosso Número). `GeraCodBarra2de5()` agora calcula
  os dois dinamicamente em vez de usar as antigas constantes fixas
  `cFLivreSafra1`/`cFLivreSafra2` (`'0'`), que foram removidas.
- **Nosso Número impresso no boleto com sufixo indevido**: a validação
  real do Safra acusou "Nosso número deve conter somente 9 dígitos". O
  campo impresso (`PrintXY` logo abaixo da imagem do boleto, 4
  ocorrências no código — 1ª e 2ª via) estava reaproveitando a
  convenção do Itaú de exibir `NossoNumero + "-" + DV` (dígito
  verificador Módulo 10 calculado sobre Agência+Conta+NossoNúmero),
  convenção que o Safra não usa. Corrigido para imprimir só o número
  puro de 9 dígitos (`DM.ATCadTitNOSSONUM.AsString`), igual ao que já
  era feito para o BB. Não afeta o código de barras nem a linha
  digitável, que já usavam DAC1/DAC2 próprios do Safra (ver item acima).

**Pendências antes de usar em produção** (comentários `// TODO SAFRA` no
código):

- **Novo campo no banco de dados**: o contador sequencial do nosso
  número do Safra usa `DM.ATCadEm2NOSSONUM3` (mesmo papel de
  `NOSSONUM`/`NOSSONUM2` para BB/Itaú) — esse campo precisa ser criado na
  tabela `SACADEM2`/`UnitDM.pas` (não incluído aqui, pois não fazia parte
  do arquivo enviado). **Sem esse campo o projeto não compila.**
- O nosso número do Safra usa 9 dígitos (prefixo `"422"` + 6 dígitos
  sequenciais), a mesma convenção usada em `REMESSA.PRG` — o boleto
  impresso precisa espelhar exatamente o que vai na remessa, por isso a
  largura aqui é 6 (e não 8 como no Itaú).

## Template visual do boleto (`boleto 2v SAFRA.bmp`)

`delphi/ImBoletoMes/boleto 2v SAFRA.bmp` é a imagem de fundo impressa por
`Bitmap.LoadFromFile('C:\boleto 2v SAFRA.bmp')` (já ligada ao código em
`UnitImBoletoMes.pas` para `CODPOR = '422'`). Foi **gerada do zero**
programaticamente (não é uma edição pixel a pixel do `boleto 2v ITAU.bmp`
original, que não chegou a ser enviado como arquivo), reproduzindo a
mesma estrutura de tabela/campos do template do Itaú, com:

- Logomarca do Safra (brasão + "Safra") reconstruída a partir da imagem
  de logo enviada — é uma **aproximação vetorial**, não um recorte
  exato da arte oficial do banco.
- "Banco Safra S/A" no lugar de "Banco Itaú S/A".
- Código "**422-7**" no lugar de "341-7" (código do banco na
  compensação + dígito verificador, conferido pelo algoritmo padrão
  FEBRABAN).
- "ATE O VENCIMENTO PAGUE PREFERENCIALMENTE NO SAFRA" no lugar de
  "...NO ITAU".
- Todos os demais campos (Local de Pagamento, Beneficiário, Agência/
  Código Cedente, Nosso Número, Carteira, Instruções, Pagador, etc.)
  seguem o padrão FEBRABAN, idênticos ao template do Itaú.

**Antes de usar em produção**: copiar o arquivo para `C:\boleto 2v
SAFRA.bmp` na máquina onde o `UnitImBoletoMes` roda (mesmo diretório
onde hoje ficam `boleto 2v BB.bmp` e `boleto 2v ITAU.bmp`), e revisar
visualmente o resultado impresso — como foi reconstruído do zero, vale
comparar lado a lado com um boleto real do Safra e, se a área do banco
tiver a arte oficial da logo em alta resolução, trocar a logo
reconstruída pela original.
