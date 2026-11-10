# DataRet — Retorno de cobrança CNAB240 (Delphi XE5)

Substitui o `src/DATARET2.PRG` (Clipper). Fica **residente na bandeja** do
Windows, sem janela e **sem nenhuma pergunta**: a cada ciclo lê a pasta de
retornos e processa sozinho todo arquivo

- `*.RET`
- `RETORNO_*.TXT` (nomes longos, ex.: `RETORNO_500EDES12345678001.TXT`)

em ordem de data/hora de gravação (o mais antigo primeiro). Arquivos que
ainda estão sendo copiados (gravados nos últimos 5 s ou travados por outro
programa) ficam para o ciclo seguinte.

## O que é feito com cada arquivo

Mesmas regras e mesmas posições do CNAB240 do DATARET2:

1. Para cada título (segmento **T** + segmento **U**), localiza-o em
   `SACADTIT` pelo índice 13 (nosso número; 17 dígitos, ou 11 na carteira
   antiga) e grava a ocorrência em `SACADTIT->RETBANCO` (não sobrescreve
   com "03 - entrada rejeitada" se já houver texto).
2. Gera o relatório **`LOTB_nnn.pdf`** (antigo `LOTB_nnn.PRN`) em
   `PastaPDF`: mesmas colunas, subtotais por grupo, total geral, quebra de
   página em 56 linhas, A4 paisagem. Só lista liquidações (códigos 06 e 17).
   Em **negrito** ficam os títulos com nosso número repetido no arquivo ou
   com situação `BB, BC, PC, PB, CA`.
3. Gera **`LOTBAIXA.nnn`** (DBF) em `PastaDados` com os títulos
   liquidados cuja situação é `AB`, `PC` ou `PB`, mais o registro de capa
   (1º registro, deletado) — mesma estrutura do Clipper.
4. Soma 1 em `SACADEMP->NUMLOTBAI` (volta a 000 ao chegar em 999).
5. Renomeia o retorno para `.XXX` (se já existir um `.XXX` igual, usa
   `_1`, `_2`… em vez de apagar).

Se algo falhar (banco fora do ar, `LOTBAIXA.nnn` já existente, arquivo que
não é CNAB240…), o arquivo **não** é renomeado, o erro vai para
`DataRet.log` (uma única vez por arquivo/mensagem) e ele é tentado de novo
no próximo ciclo.

## Configuração — `DataRet.ini`

Criado automaticamente ao lado do `.exe` na primeira execução:

```ini
[Config]
PastaRetorno=C:\datanet\fontes\
PastaDados=C:\datanet\fontes\
PastaPDF=C:\datanet\fontes\RETORNO\
IntervaloSegundos=60
ApolloHost=127.0.0.1
ApolloPorta=5002
```

Um parâmetro de linha de comando substitui `PastaRetorno` (para testes):
`DataRet.exe C:\teste\retornos`.

Menu do ícone (botão direito): **Processar agora** / **Encerrar**. Só é
permitida uma cópia do programa por vez (mutex).

## Banco de dados (Apollo)

`uDM.pas/.dfm` é um DataModule com a mesma conexão do BalLeitor (servidor
`datanet`, porta 5002, banco `DATANET`) e as tabelas `SACADTIT.DBF`
(índice `saindtit.nsx`) e `SACADEMP.DBF`.

## Compilando

Abra `DataRet.dpr` no Delphi XE5 e compile (`Ctrl+F9`), ou `dcc32 DataRet.dpr`.
Copie `res\caixa.ico` para a pasta do `.exe` (ícone da bandeja).

## Pontos para conferir no primeiro teste

> Este código foi escrito sem acesso ao Delphi/Apollo; **ainda não foi
> compilado nem executado**. Compare a saída com a do DATARET2 usando o
> mesmo arquivo de retorno antes de colocar em produção.

- **`LOTINDEX.nnn`**: o Clipper também criava esse índice
  (`NUMMOV+TIPODOC+CODCLI`). O DataRet **não** o cria. Se o programa que
  consome o `LOTBAIXA.nnn` precisar dele, ele terá que gerá-lo ou isso
  precisa ser acrescentado.
- **`SetOrder(13)`** em `SACADTIT`: se o Apollo reclamar, atualize os
  `IndexDefs` de `ATTit` no designer (clique direito → atualizar índices).
- Datas, valores e posições seguem o DATARET2; os `.TXT` precisam ter o
  mesmo layout dos `.RET` (confirmado).
- Diferenças propositais em relação ao Clipper:
  - o negrito de nosso número repetido compara o **nosso número da
    própria linha** (no Clipper comparava o da última linha lida — bug);
  - não apaga um `.XXX` existente; usa `_1`, `_2`…;
  - recusa arquivo sem header CNAB240 (posição 8 do 1º registro = `0`);
  - lê qualquer fim de linha (CRLF, LF ou CR).
