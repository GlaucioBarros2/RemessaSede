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

## Pasta "Processados"

- O `.XXX` gerado é salvo dentro da subpasta **`Processados`**, criada
  automaticamente se ainda não existir.
- O `.txt` original (a contagem) é **movido junto** para `Processados`
  depois de gerado o `.XXX` — assim os dois ficam juntos para
  conferência/auditoria, e o mesmo arquivo não é processado de novo no
  próximo ciclo.
- Se já existir um arquivo com o mesmo nome em `Processados` (`.txt`
  ou `.XXX`), o programa não sobrescreve: acrescenta `_1`, `_2` etc.
  antes da extensão.

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

Por padrão, o programa monitora a **pasta onde o `.exe` está**. Se
quiser apontar para outra pasta, crie um atalho para o `.exe` e
informe o caminho como parâmetro, por exemplo:

```
BalLeitor.exe C:\Balanca\Arquivos
```

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
2. Copie `exemplo/bal_20260909.txt` e a pasta `res` (com `caixa.ico`)
   para a pasta do `.exe` compilado (ex.: `Win32\Debug`).
3. Rode o `.exe`, informe o intervalo (ex.: `1`) e confirme.
4. Verifique se surgiu a pasta `Processados` com dois arquivos dentro:
   `bal_20260909.txt` (movido) e `bal_20260909.XXX` (gerado), além do
   `BalLeitor.log` registrando o processamento.
5. Verifique se o ícone da caixinha apareceu na bandeja do sistema
   (pode estar atrás da setinha "mostrar ícones ocultos").
6. Clique com o botão direito no ícone da bandeja e escolha
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
