# BalLeitor — Leitor de arquivos de balança para Balanço de Estoque (Delphi XE5)

Programa em Delphi XE5 que fica **residente na bandeja do sistema**
(o ícone ao lado do relógio, no rodapé da tela do Windows), monitorando
uma pasta em busca de arquivos `bal_*.txt` — a contagem de saldo feita
na prateleira do depósito — e gerando, para cada um, um arquivo
`bal_*.XXX` já tratado.

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
  ignorado.
- **Linha 2 em diante**: `código;quantidade;apresentação` — a
  apresentação é opcional.

## Regras aplicadas

- Somente as linhas a partir da 2ª são lidas.
- Em **quantidade**, apenas a parte inteira é gravada — o que vier
  depois do separador decimal é descartado (sem arredondamento):
  `628.000` → `628`, `4.000` → `4`, `0.000` → `0`.
- O arquivo de saída mantém o mesmo nome base, trocando a extensão
  para `.XXX` (constante `EXTENSAO_SAIDA` em `uMain.pas` — ajuste se a
  extensão real precisar ser outra).
- O `.XXX` ganha uma **quarta coluna**, depois da apresentação (`A`/`V`):
  o saldo de estoque que o produto tinha **antes** do ajuste, consultado
  em `DM.ATCadPro.FieldByName('saldestoq')` pelo código do produto
  (campo `CODPRO`). Exemplo, para a entrada do topo deste README:

  ```
  022763;0;A;150
  020624;0;A;30
  007956;4;V;4
  005465;628;V;700
  005057;620;A;80
  020620;0;V;12
  ```

  (os números de saldo acima são só exemplo — vêm da consulta ao banco
  no momento do processamento.)

## Pasta "Processados"

- O `.XXX` gerado (já com a coluna do saldo anterior — ver acima) é
  salvo dentro da subpasta **`Processados`**, criada automaticamente
  se ainda não existir.
- O `.txt` original (a contagem, sem alteração nenhuma) é **movido
  junto** para `Processados` depois de gerado o `.XXX` — assim os dois
  ficam juntos para conferência/auditoria, e o mesmo arquivo não é
  processado de novo no próximo ciclo.
- Se já existir um arquivo com o mesmo nome em `Processados` (`.txt`
  ou `.XXX`), o programa não sobrescreve: acrescenta `_1`, `_2` etc.
  antes da extensão.

## Dependência: `UnitDM.pas` (conexão com o banco do ERP)

Para consultar o saldo anterior, o `BalLeitor` agora depende do
`UnitDM.pas` **e do `UnitDM.dfm`** do seu sistema (ERP) — os mesmos
que já usam os componentes Apollo (`ApolloEnv1`, `ApolloConnection1`,
`ATCadPro`) configurados e testados lá.

- Copie os dois arquivos para dentro de `delphi/BalLeitor/` (junto de
  `uMain.pas`) antes de compilar.
- O `UnitDM.pas` que vimos foi compilado em **Delphi 7**, usando
  pacotes de terceiros (Apollo: `ApoDSet`, `ApWin`, `ApConn`, `ApoEnv`;
  Rave Reports: `RpDefine`, `RpCon`, `RpRave` etc.). Para o `BalLeitor`
  (Delphi XE5) compilar com essa unit no `uses`, **esses mesmos
  pacotes precisam estar instalados no Delphi XE5** também — se não
  estiverem, a compilação falha por falta desses componentes, e aí
  precisamos de uma conexão mais enxuta, só para o `BalLeitor`.
- Se a conexão falhar ao abrir o programa (banco fora do ar, etc.), o
  `BalLeitor` **não trava**: grava um erro no log, continua rodando, e
  o saldo anterior sai como `0` até a conexão voltar a funcionar.
- Se o código do produto não for encontrado em `ATCadPro`, o saldo
  anterior também sai como `0`, com um aviso no log.
- O campo de busca é `CODPRO`; se no seu `ATCadPro` for outro nome,
  ajuste em `SaldoAnteriorProduto`, no `uMain.pas`.

## Como o programa roda

1. Ao abrir, uma caixinha pergunta **de quantos em quantos minutos**
   verificar a pasta em busca de novos `bal_*.txt`.
2. Depois disso, **não abre nenhuma janela** — fica só o ícone na
   bandeja do sistema (pode estar escondido atrás da setinha "mostrar
   ícones ocultos", no canto inferior direito da tela).
3. Ele processa imediatamente ao iniciar, e depois repete no intervalo
   configurado.
4. **Clique com o botão direito** no ícone para abrir o menu:
   - **Processar agora** — força uma varredura imediata, sem esperar o
     intervalo.
   - **Encerrar** — para o programa a qualquer momento.
   - **Duplo clique** no ícone também força uma varredura imediata.
5. Cada execução gera uma linha em `BalLeitor.log` (na mesma pasta do
   `.exe`), com data/hora, arquivos processados e eventuais avisos ou
   erros — como não há janela nem console, esse log é o registro do
   que aconteceu.

## Pasta monitorada

Por padrão, o programa monitora **`F:\DataNet\Balanco`** (constante
`PASTA_PADRAO` em `uMain.pas`) — é lá que os `bal_*.txt` devem ser
colocados. O `.XXX` gerado e o `.txt` original movido vão para
**`F:\DataNet\Balanco\Processados`**.

Para testar em outra pasta (numa máquina onde `F:\DataNet\Balanco` não
existe, por exemplo), informe o caminho como parâmetro ao rodar o
`.exe`:

```
BalLeitor.exe C:\Balanca\Arquivos
```

Nesse caso o programa usa a pasta informada em vez da padrão, e
`Processados` é criada dentro dela.

## Compilando

Abra `BalLeitor.dpr` no Delphi XE5 (`File → Open Project...`) e
compile (`Ctrl+F9`), ou via linha de comando com o `dcc32` do XE5:

```
dcc32 BalLeitor.dpr
```

Arquivos do projeto:
- `BalLeitor.dpr` — arquivo principal, pergunta o intervalo e inicia o
  formulário.
- `uMain.pas` / `uMain.dfm` — formulário (sem janela visível), ícone
  de bandeja, timer e toda a lógica de leitura/gravação/movimentação
  dos arquivos.
- `UnitDM.pas` / `UnitDM.dfm` — **não incluídos neste repositório**;
  copie os do seu ERP para cá antes de compilar (ver seção
  "Dependência: UnitDM.pas" acima — é de onde vem `DM.ATCadPro`).
- `res/caixa.ico` — imagem de uma caixinha usada no ícone da bandeja.
- `exemplo/bal_20260909.txt` — arquivo de exemplo para teste.

## Ícone da bandeja

O programa procura `res\caixa.ico` **na pasta do executável** e usa
essa imagem no ícone da bandeja; se não encontrar o arquivo, usa o
ícone padrão do Delphi como reserva (o programa nunca deixa de abrir
por causa disso).

Então, ao copiar o `.exe` para rodar em outro lugar (ex.: produção),
leve a pasta `res` junto, do lado do `.exe`:

```
BalLeitor.exe
res\caixa.ico
```

No Delphi, isso significa copiar a pasta `res` (com o `caixa.ico`) para
dentro de `Win32\Debug` (ou `Win32\Release`) ao testar, do mesmo jeito
que se faz com o arquivo de exemplo abaixo.

Quer trocar a imagem? Basta substituir `res/caixa.ico` por outro `.ico`
com o mesmo nome — não precisa mexer no código nem recompilar nada
além do próprio programa.

## Testando

1. Compile o projeto.
2. Copie a pasta `res` (com `caixa.ico`) para a pasta do `.exe`
   compilado (ex.: `Win32\Debug`) — é daí que o ícone da bandeja é
   carregado, independente da pasta monitorada.
3. Para os arquivos de retorno, você tem duas opções:
   - **Testar na pasta padrão**: crie `F:\DataNet\Balanco` na sua
     máquina e copie `exemplo/bal_20260909.txt` para lá; ou
   - **Testar em outra pasta**: copie `exemplo/bal_20260909.txt` para
     qualquer pasta e rode `BalLeitor.exe <pasta>` informando o
     caminho como parâmetro.
4. Rode o `.exe`, informe o intervalo (ex.: `1`) e confirme.
5. Verifique se surgiu a pasta `Processados` (dentro da pasta
   monitorada) com dois arquivos: `bal_20260909.txt` (movido, sem
   alteração) e `bal_20260909.XXX` (gerado, com a coluna do saldo
   anterior em cada linha), além do `BalLeitor.log` (na pasta do
   `.exe`) registrando o processamento.
6. Verifique se o ícone da caixinha apareceu na bandeja do sistema
   (pode estar atrás da setinha "mostrar ícones ocultos").
7. Clique com o botão direito no ícone da bandeja e escolha
   **Encerrar** para parar o programa.

## Observações / pontos de ajuste

- O separador decimal aceito é `.` ou `,` — não depende da
  configuração regional do Windows.
- Linhas em branco são ignoradas; linhas com menos de 2 campos geram
  um aviso no log e são puladas, sem interromper o processamento do
  arquivo.
- Se a extensão de saída não for literalmente `.XXX`, ou se quiser
  apagar o `.txt` original em vez de movê-lo, ajuste a constante
  `EXTENSAO_SAIDA` e o trecho de `TFile.Move` em `uMain.pas`.
