# Relatório de fechamento C8 — patch de conformidade do servidor (CRIT-01/02/03)

**Servidor:** `soniaambrosio/buraco-servidor`, branch **`correcao/conformidade-canonica`** (base `be72bb6`), commit **`69698f9`**. **Sem deploy.** `server.js` anterior preservado no Git (main/`be72bb6`).
**Exceção documentada:** a fonte `cliente/` (`motor/*.js` + `build_server_bundle.js`) não está versionada/localizada; por decisão da Sônia (opção c), o **bundle** `server.js` foi corrigido **direto**, só para as 3 CRIT. Todos os trechos marcados com `// [PATCH CRIT-0x]`. Retroportar para `cliente/` se a fonte reaparecer, e regerar o bundle.

## Trechos alterados (bundle `server.js`)
| CRIT | Regra | Funções/linhas alteradas (pós-patch) |
|------|-------|--------------------------------------|
| **CRIT-01** | `de_500` = 500 | `validarSequencia` (detecção A..K limpa 13, ~l.172) + `finalizar` (`de_500`, ~l.331). O ramo `de_500 → 500` do `pontuarDuplaJogo` (já existente) passa a ativar. |
| **CRIT-02** | `as_a_as` = 1000 | `validarSequencia` (detecção A–K–A 14, ~l.184) + `finalizar` (`as_a_as`, ~l.333) + `pontuarDuplaJogo` (`as_a_as → 1000`, ~l.2218) + `duplaTemCanastraLimpa` (~l.2109) + `duplaPodeBater` (~l.2127) + `baixadaTravaria` (~l.2142). |
| **CRIT-03** | vulnerabilidade uniforme bot=humano | `checarAberturaVulneravel` (~l.2021): removida a isenção `if (tipo !== "humano") {…}`. O gate +75/+90 passa a valer para todos os assentos. |

Nenhuma outra área tocada (geração/embaralho, WS/salas, contas, ranking, cérebro e força dos bots intactos). Nenhuma EXC criada.

## Verificação — antes × depois (0 CRIT)
- **Deployed (`be72bb6`)** — C8-A/C8-B: **3 CRIT** (CRIT-01, CRIT-02, CRIT-03).
- **Corrigido (`69698f9`)** — reexecução dos vetores contra as regras corrigidas (`auditoria/conformidade/servidor_regras_corrigido.js` espelha o patch), via `verificacao_pos_patch.js`:

```
OK CRIT-01 M07 de_500 (valido, tipo, bonus) -> [true,"de_500",500]
OK CRIT-02 M08 as_a_as (valido, tipo, bonus) -> [true,"as_a_as",1000]
OK CRIT-01 S05 pontuação de_500 (total)      -> 610
OK CRIT-03 BOT abre <minimo agora é ANULADO (=humano) -> true
OK CRIT-03 HUMANO idem (simetria)            -> true
PÓS-PATCH: 5/5 conformes; CRIT remanescentes=0 → ZERO CRIT ✔
```

`node_harness.js`/`fluxo_harness.js` (deployed) permanecem como registro do estado **anterior**; `servidor_regras_corrigido.js` + `verificacao_pos_patch.js` provam o estado **corrigido**.

## Estado dos portões
- **Servidor:** patch pronto na branch, **0 CRIT** provado. **Falta:** sua revisão do diff (`SERVIDOR-CRIT010203.diff`) e, quando você quiser, o **deploy** (fora do meu escopo sem sua autorização).
- **App (Dart) `C8-CONFORMIDADE`:** continua exigindo `{CRIT-01,CRIT-02}` contra o **fixture do servidor DEPLOYADO** — e isso é proposital: o portão reflete a realidade em produção. Quando o servidor corrigido for **deployado**, regeneramos o fixture (0 CRIT) e viramos o portão para exigir **zero** — aí o app também trava conformidade em verde. Enquanto não há deploy, o app segue **+253** e a promoção online continua **BLOQUEADA**.

## Próximo
1. Você revisa o `SERVIDOR-CRIT010203.diff` e aprova a branch `correcao/conformidade-canonica`.
2. Deploy do servidor corrigido (quando você autorizar) → regeneramos o fixture do deployado → viramos `C8-CONFORMIDADE` para exigir 0 CRIT → promoção online deixa de estar bloqueada.
3. Retomamos o **C9** no app (motor canônico atrás de flag). *(Se preferir, podemos iniciar o planejamento do C9 em paralelo, já que a correção está provada; mas a promoção online só abre após deploy + portão em zero.)*
