# Relatório de fechamento C8 — patch de conformidade do servidor (CRIT-01/02/03)

**Servidor:** `soniaambrosio/buraco-servidor`, branch **`correcao/conformidade-canonica`**.
- `69698f9` (base `be72bb6`) — patch inicial CRIT-01/02/03.
- **`09835bd`** — ajustes da revisão da Sônia (mesmo escopo). **SHA final = `09835bd`.**
**Sem deploy.** `server.js` anterior preservado no Git (main/`be72bb6`).
**Exceção documentada** (opção c): fonte `cliente/` ausente → patch cirúrgico direto no bundle `server.js`, só nas 3 CRIT, marcado com `// [PATCH CRIT-0x]`. Retroportar para `cliente/` se a fonte reaparecer.

## Ajustes da revisão (incremental `69698f9` → `09835bd`)
1. **CRIT-02 — `decidirBater` (estratégia do bot):** passou a reconhecer `as_a_as` como canastra apta a bater (antes só `limpa||de_500`). Motor autoritativo e estratégia do bot agora alinhados. `// [PATCH CRIT-02]`.
2. **CRIT-02 — detalhe da pontuação:** `as_a_as` deixou de incrementar `detalhe.de500`; agora usa contador próprio **`detalhe.asas`** (campo novo, aditivo, compatível com o contrato). O **total** não muda (+1000).
3. **CRIT-03 — JSDoc de `checarAberturaVulneravel`:** corrigido o texto "Vale SÓ pro HUMANO" (falso após o CRIT-03) → agora afirma aplicação uniforme humano **e** bot.

Aprovados na revisão sem alteração: CRIT-01 (de_500), CRIT-03 funcional (isenção de bot removida), bloco de EXCEÇÃO, escopo (só `server.js`).

## Trechos alterados no bundle (acumulado)
| CRIT | Funções/linhas (pós-`09835bd`) |
|------|--------------------------------|
| **CRIT-01** de_500=500 | `validarSequencia` (detecção A..K 13) + `finalizar`. |
| **CRIT-02** as_a_as=1000 | `validarSequencia` (A–K–A 14) + `finalizar` + `pontuarDuplaJogo` (+1000, `detalhe.asas`) + `duplaTemCanastraLimpa` + `duplaPodeBater` + `baixadaTravaria` + **`decidirBater`** (estratégia do bot). |
| **CRIT-03** vulnerabilidade uniforme | `checarAberturaVulneravel` (removida a isenção de bot) + JSDoc. |

## Verificação — PROVA CONTRA O BUNDLE REAL
`auditoria/conformidade/verificacao_bundle_real.js` carrega os **módulos reais** do `server.js` corrigido (`canastra`/`jogo`/`bot`) **sem subir o servidor** (neutraliza só o boot do WS; nenhuma porta) e roda os vetores nas funções reais:

```
OK REAL CRIT-01 de_500 (valido, tipo)                 -> [true,"de_500"]
OK REAL CRIT-02 as_a_as (valido, tipo)                -> [true,"as_a_as"]
OK REAL CRIT-01 pontuação de_500 (total)              -> 610
OK REAL CRIT-02 detalhe de_500 (de500=1, asas=0)      -> [1,0]
OK REAL CRIT-02 pontuação as_a_as (total)             -> 1125
OK REAL CRIT-02 detalhe as_a_as (asas=1, de500=0)     -> [1,0]
OK REAL CRIT-02 decidirBater reconhece as_a_as        -> true
OK REAL CRIT-03 BOT <minimo é ANULADO (descarte recusado + mesa vazia) -> [false,0]
BUNDLE REAL: 8/8 conformes; CRIT remanescentes=0 → ZERO CRIT ✔
```

Reproduzir: `BMV_SERVER_JS=/caminho/buraco-servidor/server.js node auditoria/conformidade/verificacao_bundle_real.js` (com a branch `correcao/conformidade-canonica` clonada). Espelho (`servidor_regras_corrigido.js` + `verificacao_pos_patch.js`) permanece como verificação secundária: **5/5, 0 CRIT**.

## Antes × depois
- **Deployed (`be72bb6`):** C8-A/C8-B = **3 CRIT** (CRIT-01, CRIT-02, CRIT-03).
- **Corrigido (`09835bd`), bundle real:** **0 CRIT** (8/8).

## Portões
- **Servidor:** patch pronto na branch, **0 CRIT provado no bundle real**. Falta sua aprovação final + **deploy** (fora do escopo sem autorização).
- **App (Dart) `C8-CONFORMIDADE`:** segue exigindo o **deployado** (`{CRIT-01,CRIT-02}`) de propósito, até o deploy do corrigido. Quando deployar: regenerar o fixture do deployado (0 CRIT) → virar o portão para exigir zero → promoção online desbloqueia. App segue **+253**.

## Entregáveis desta rodada
- **SHA final:** `09835bd`.
- **Bundle incremental (servidor):** `BMV-SERVIDOR-CRIT02-ajustes-09835bd.bundle` (requer `69698f9`, fast-forward na branch).
- **Diff incremental:** `SERVIDOR-CRIT02-incremental.diff` (só os 3 ajustes).
- **Verificação bundle real:** 8/8 → 0 CRIT (acima).
- **C8-A/C8-B pós-ajuste:** mirror 5/5; deployado mantém registro do estado anterior.
- **Confirmação:** **ZERO CRIT** no servidor corrigido.
