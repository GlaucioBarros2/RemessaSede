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
  título `99` (Outros — mesma convenção já usada no bloco do Itaú),
  moeda `09` (Real), IOF e abatimento zerados (Safra não aceita
  abatimento na entrada do título), código de juros/desconto conforme
  haja ou não `cJurDia`/`cDesFin` calculados.
- **Nosso Número**: o manual confirma que no Safra ele é **livre** — 9
  dígitos escolhidos pela empresa (posições 38 a 46 do segmento P), sem
  nenhum dígito verificador calculado pelo banco (isso só existe na
  "Cobrança Convencional", onde o próprio Safra emite o boleto e
  preenche zeros nessas posições). Por isso **não há função de DV**
  para o Safra (a tentativa anterior com Módulo 11 foi removida por não
  ser necessária). O programa usa como nosso número os 9 caracteres do
  campo `TIT->NOSSONUM`, na mesma convenção interna já usada para os
  outros bancos: prefixo `"422"` + 6 dígitos sequenciais.
- Trailer de Lote (registro 5): ao contrário do bloco do Itaú/BB
  (que soma "+2" ao total de registros do lote), o manual do Safra diz
  que a contagem em 018-023 é **só** dos registros de detalhe (segmentos
  P/Q/R) — por isso o Safra tem sua própria fórmula sem o "+2".

### Já preenchido com dados reais

- **Agência, conta corrente e dígito verificador da conta**
  (`cAgenSaf`, `cContSaf`, `cContDVSaf`, definidos em `GER_ARQUIVO()`) —
  agência `0144`, conta `00587488-9`.

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

**Já preenchido com dados reais**: `cAgSafra` (`'0144'`), `cContaSafra`
(`'0000587488'`) e `cContaDVSafra` (`'9'`) — agência `0144`, conta
`00587488-9`.

**Pendências antes de usar em produção** (comentários `// TODO SAFRA` no
código):

- Falta confirmar se o campo livre do código de barras (10 dígitos)
  espera só a conta (zero-padded à esquerda, como está hoje) ou a
  conta+DV concatenados — ver comentário ao lado de `cContaSafra` no
  código.
- **`cFLivreSafra1` / `cFLivreSafra2`**: os 2 dígitos de "uso livre" nas
  posições 20 e 44 do código de barras não são documentados no manual;
  estão fixos em `'0'` até confirmação com a mesa de implantação do
  Safra.
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
