# Regras do projeto

- **Sempre comente os fontes** (em português): o dono do projeto pediu isso para
  conseguir lembrar depois como tudo funciona. Cada módulo com um cabeçalho dizendo
  para que serve, cada função/classe com docstring, e comentários nos trechos que não
  são óbvios (principalmente regras de negócio como ICMS-ST e hash).
- Python do projeto `tray_sync` deve continuar compatível com 3.7+ (só `requests` como dependência).
- Nunca versionar segredos (`config.ini`, tokens, senhas) nem DBFs reais.
