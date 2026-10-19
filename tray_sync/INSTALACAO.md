# Instalação do tray_sync em uma máquina nova (Windows)

Tempo estimado: 20 minutos. A máquina precisa enxergar a pasta onde estão os DBFs
(ex.: `F:\DataNet`) e ter internet.

## 1. Instalar o Python
1. Baixe em https://www.python.org/downloads/ (versão 3.7 ou mais nova).
   *Windows 7 só roda até o Python 3.8; Windows 10/11 pode usar o mais novo.*
2. No instalador, **marque "Add Python to PATH"** e clique em *Install Now*.
3. Confira: abra o *Prompt de Comando* (tecla Windows, digite `cmd`) e rode:
   ```
   python --version
   ```

## 2. Copiar o programa
Opção A (com Git): `git clone https://github.com/glauciobarros2/remessasede.git C:\RemessaSede`
e depois `cd C:\RemessaSede` e `git checkout claude/gallant-rubin-rkaxaw`.

Opção B (sem Git): no GitHub, abra o branch `claude/gallant-rubin-rkaxaw`,
botão verde **Code → Download ZIP**, e extraia em `C:\RemessaSede`.

Daqui em diante, **todos os comandos são rodados dentro de `C:\RemessaSede`**
(a pasta que *contém* a pasta `tray_sync`):
```
cd C:\RemessaSede
```

## 3. Instalar a única dependência
```
python -m pip install -r tray_sync\requirements.txt
```

Se aparecer o erro `urllib3 v2.0 only supports OpenSSL 1.1.1+` ao rodar o programa
(acontece no Python 3.7), corrija com:
```
python -m pip install "urllib3<2" "requests<2.32"
```

## 4. Criar o config.ini
```
copy tray_sync\config.example.ini config.ini
notepad config.ini
```
Preencha:

| Campo | O que colocar |
|---|---|
| `[dbf] produtos` | caminho do `sacadpro.dbf` (ex.: `F:\DataNet\sacadpro.dbf`) |
| `[dbf] agregados` | caminho do `sacadagr.dbf` (vazio = não soma ICMS-ST) |
| `[tray] api_base` | `https://www.sededasmiudezas.com.br/web_api` |
| `[tray] consumer_key` / `consumer_secret` | **novos** (os antigos estavam expostos nos scripts; gere outros no painel da Tray) |
| `[tray] code` | código de autorização do aplicativo na Tray (usado só na 1ª autenticação) |
| `[tray] acrescimo_percent` | acréscimo % sobre o preço (era o `acrescimo` do PostgreSQL) |

Se você já tem `access_token` e `refresh_token` válidos, pode colocá-los na seção `[tray]`
(com `date_expiration_access_token` e `date_expiration_refresh_token`); senão, o programa
autentica sozinho com o `code`. **Não envie o config.ini a ninguém nem suba no GitHub.**

## 5. Testar sem risco (nada é enviado nem gravado)
```
python -m tray_sync --dry-run
```
Deve listar os produtos alterados com o preço e o estoque que seriam enviados.
Confira alguns valores com o sistema (principalmente produtos com ICMS-ST).

## 6. Baixar o mapa de produtos da Tray
```
python -m tray_sync --remap
```
Cria o `tray_sync.db` (de/para código → id da Tray). Aparece no log:
`mapa Tray atualizado: N produtos`. Se N for 0 ou der erro de token, revise o passo 4.

## 7. Primeiro envio de verdade (teste com poucos produtos)
Se possível, antes de liberar geral, faça o teste com um produto só (ex.: altere o preço de
um produto no sistema) e rode:
```
python -m tray_sync --once --limite 3
```
(`--limite 3` envia no máximo 3 produtos; os demais ficam para depois.)
Confira os produtos na loja Tray e veja se `SAL_HASH`/`PRE_HASH` foram gravados no DBF.
**Atenção:** na 1ª execução real, todos os produtos com hash em branco serão enviados
(pode passar de 10 mil requisições — o programa para no limite diário e continua no dia seguinte).
Considere avisar antes ou começar à tarde.

## 8. Deixar rodando
- **Janela aberta** (simples): `python -m tray_sync` — a cada 60 s verifica e envia.
  Para parar: crie um arquivo vazio chamado `parar_sync.txt` na pasta (ou Ctrl+C).
- **Automático ao ligar o PC** (recomendado): *Agendador de Tarefas* →
  *Criar Tarefa Básica* → disparador "Ao iniciar o computador" → ação *Iniciar programa*:
  - Programa: `python`
  - Argumentos: `-m tray_sync`
  - Iniciar em: `C:\RemessaSede`

## Onde olhar se algo der errado
- `tray_sync.log` (na pasta onde você rodou): histórico de tudo que foi enviado e dos erros.
- Produto "não existe na Tray" mas você vê ele no painel: rode `python -m tray_sync --procura 019189`
  (troque pelo código). Ele varre a Tray e mostra como a `reference` aparece de verdade.
- Produto "não existe na Tray": cadastre-o na Tray com `reference` = código de 6 dígitos.
- Erro de token: confira `consumer_key`, `consumer_secret` e `code` no `config.ini`.
- Rode **uma instância só** do programa e **desligue o Delphi e os scripts antigos**.
