# tray_sync — DBF → Tray (sem ODBC, sem PostgreSQL, sem Delphi)

Substitui os dois programas antigos (Delphi XE5 + scripts Python 3.7) por **um só
processo Python** que lê o `sacadpro.dbf` direto e atualiza preço/saldo na API da Tray.

## Regra

Para cada produto do `sacadpro.dbf`:

- `SALDESTOQ <> SAL_HASH` **ou** `PREVENDA <> PRE_HASH` → envia à Tray (`PUT /products/{id}`
  com `price`, `stock`, `available`) e, só se a Tray aceitou, grava `SAL_HASH`/`PRE_HASH`
  no DBF com os valores enviados. Se der erro, o hash fica diferente e ele tenta de novo
  (com espera de `retry_minutos`, para não gastar a cota).
- Preço enviado = `(PREVENDA + ICMS-ST) + acréscimo%`, 2 casas (igual ao Delphi + script antigo).
- `available` = 1 se saldo > 0. Saldo negativo é enviado como 0.

## Como o que existia foi trocado

| Antes | Agora |
|---|---|
| Delphi + Apollo + ODBC copiando DBF → PostgreSQL | leitura direta do DBF (`dbfio.py`) |
| tabela `produtos_produto` (mapa código → id Tray) | SQLite local (`state.py`), recarregado da Tray sozinho |
| `produtos_parametro` (tokens, acréscimo, flag "Delphi processando") | tokens no SQLite; acréscimo no `config.ini`; flag não é mais necessária |
| 4 scripts (tokens, códigos, preços) | `tray.py` renova token sozinho (refresh_token → senão `code`) |

A escrita no DBF mexe **somente nos bytes dos campos `SAL_HASH`/`PRE_HASH`** do registro
(não regrava cabeçalho nem outros campos), para conviver com o sistema legado aberto.

## Uso

```
pip install -r tray_sync/requirements.txt         # só o requests; Python 3.7+
copy tray_sync\config.example.ini config.ini      # preencha
python -m tray_sync --dry-run                     # mostra o que enviaria, sem tocar em nada
python -m tray_sync                                # loop (a cada intervalo_segundos)
python -m tray_sync --once                         # um ciclo e sai (Agendador de Tarefas)
python -m tray_sync --remap                        # recarrega o mapa código → id da Tray
```

Para parar o loop: crie o arquivo `parar_sync.txt` (como no script antigo). Testes: `python -m pytest tray_sync`.

## Pontos para você decidir / conferir

1. **Produto que não existe na Tray não é criado.** O fluxo antigo também não criava (só
   atualizava quem já tinha `codigo_tray`); ele fica pendente e aparece no log (`reference` = código
   com 6 dígitos). Se quiser *incluir* na Tray automaticamente, preciso saber os campos
   obrigatórios do seu cadastro (categoria, marca, etc.).
2. **ICMS-ST (`AchaSubst`)**: conferido com o seu `SACADPRO.DBF`/`SACADAGR.DBF`: o `PE` fica sempre no
   slot 01 (`UFICMRT01`), que é o único que o Delphi realmente avaliava (nos slots 02..27 ele comparava
   `ICMSRET0n` com `'PE'`, nunca verdadeiro). Por isso `st_todos_slots = false` (padrão) dá o resultado
   correto. Configure `agregados = ...\SACADAGR.DBF`. O arquivo tem ~487 mil linhas; só as da UF da loja
   são carregadas (≈2 s) e ficam em cache até o arquivo mudar.
3. **Hash com menos casas que o campo origem**: a comparação é feita na precisão do campo `*_HASH`
   (o Delphi gravava o saldo truncado em inteiro; sem isso o produto seria reenviado para sempre).
4. **Cota da Tray**: 180 req/min e 10 mil/dia. Há intervalo entre requisições e contador diário
   (`limite_diario`).
5. Rode **uma instância só**.
