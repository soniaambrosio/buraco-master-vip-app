# Status — Motor canônico (RulesEngine), migração progressiva

**Branch (app):** `auditoria/regras-bmv`. **Branch (servidor):** `correcao/conformidade-canonica` → **mesclada na `main` (PR #1) e DEPLOYADA**. Motor antigo (`mesa.dart`) = padrão até C10.
**Docs:** `PLANO-RULESENGINE-CANONICO.md`, `PLANO-C8-DART-NODE.md`, `RELATORIO-DART-NODE-C8.md`, `RELATORIO-C8B-FLUXO-NODE.md`, `PLANO-SERVIDOR-CONFORMIDADE.md`, `RELATORIO-C8-FECHAMENTO.md`, `PLANO-C9-MOTOR-FLAG.md` (v2.1), `RELATORIO-C9C-SOMBRA.md`.
**Entrega:** commit local → `git bundle` → upload web → Codespace `git fetch ./bundle` → push → Actions.

## Progresso por commit (app)
- **C1..C7 — CI VERDE — APROVADOS.** Motor canônico completo (`app/lib/rules/`). HEAD C7 `7d727ae` (+251).
- **C8 — ENCERRADO OFICIALMENTE; promoção online DESBLOQUEADA.** Servidor canônico deployado (`main`, `sha256=81ec3255…`, 0 CRIT); portão `C8-CONFORMIDADE` exige conjunto crítico vazio.
- **C9-A — `07b9ff0` — CI #136 VERDE — APROVADO.** Flags + porta tipada + fábrica/seletor.
- **C9-B + C9-B-fix — `9332aaa` — CI #138 VERDE — APROVADO.** Projeção/envelope + adaptadores + costura runtime OFF; preserva as 3 fases (`mortoPendente` via transporte) + clone profundo `pontosRodada`.
- **C9-C — `c822926`** (sobre `9332aaa`): modo sombra + comparador. **Bundle entregue:** `BMV-APP-C9-C-c822926.bundle` (requer `9332aaa`, fast-forward). Suíte **263 → 272 `test()`**. **ENTREGUE — pendente push + CI + revisão da Sônia.**

## C9 — motor canônico atrás de flag (plano v2.1 aprovado)
- **C9-A (`07b9ff0`, APROVADO):** flags (2 independentes OFF), contrato tipado da porta, seletor/fábrica.
- **C9-B+fix (`9332aaa`, APROVADO):** projeção pela matriz (CANÔNICO exato; DERIVADO+TRANSPORTE preserva `compra/jogo/mortoPendente`; ENVELOPE completo; SIDECAR; `pontosRodada` clone profundo); adaptadores concretos; composição (OFF⇒legado, não reroteia); costura mínima em `mesa.dart`. Testes C9-MAP-01..09, C9-ADAP-*, C9-COMPOSICAO-01.
- **C9-C (`c822926`, entregue):** `modo_sombra.dart` — comparador puro, autoridade OFF, sombra separada, execução dupla sobre clones com EnvelopeRuntime COMPLETO. Pipeline: execução dupla → normalização (`assinatura()`) → comparação → classificação `CONVERGE/EXC-01..04/INESPERADA/canonicoRecusou` → diff (`CampoDiff`) → `Replay` por snapshot. Transações semânticas + estabilização (mortoPendente indireto). EXC só por id **declarado e conhecido**; não declarado/inexistente = **INESPERADA** (nada escondido).
  - `replay.dart`: `seed` opcional (Ajuste 3) + invariante `reproduzivel` (seed OU snapshot).
  - `projecao_estado.dart`: **descoberta da sombra** — topo do monte divergia (legado `removeAt(0)` × canônico `removeLast`); reconciliado revertendo o monte na projeção (round-trip exato preservado). Correção de mapeamento, não de regra.
  - Testes C9-SOMBRA-01..09; **meta 0 inesperadas** nos cenários convergentes (01/02). Relatório: `RELATORIO-C9C-SOMBRA.md`.
  - **Findings declarados p/ reconciliar antes do C9-D:** monte vazio → morto (legado converte × canônico recusa); e expandir a sombra p/ `baixar`/`bater` + cenários de EXC-01..04.
  - **Revisão estática independente:** sem erros de compilação; 1 defeito lógico pego e corrigido (fase pós-legado estagnada → limpar transporte antes de projetar).
- **C9-D (próximo, só após aprovação do C9-C):** ativação atrás da flag (autoridade ON, fronteira atômica mapear→aplicar→validar→commit único; fallback só técnico com telemetria/Replay). Padrão continua OFF.

## Servidor — patch de conformidade — DEPLOYADO e validado
- **`main`, `sha256(server.js)=81ec3255…`** (== `09835bd`); `/health`=`ok`; smoke OK. CRIT-01/02/03 corrigidos; bundle real 8/8 → 0 CRIT.

## Exceções do modo sombra (declaradas; remoção no C10)
- **EXC-01** trinca com curinga. **EXC-02** abertura múltipla. **EXC-03** lixo fechado desacoplado. **EXC-04** grupo de ases = trinca canônica.

## Regras congeladas (RuleSpec `bmv-regras-2026.08`)
Vulnerabilidade +75/+90 (limiar meta/2 = 750, uniforme bot=humano); trinca só natural no Fechado; Joker e "2" fora da trinca; abertura múltipla atômica; topo do lixo com uso em ≥1 jogo; jogador e bot mesma legalidade; **fase do turno é regra**; **esvaziar a mão é regra**; UI não decide regra.
Pontuação: A=15, JOKER=50, 2=10, 8..K=10, 3..7=5; canastra as_a_as=1000/de_500=500/limpa=200/suja=100; batida +100; mão desconta; morto não pego −100.

## Próximo
1. **Sônia:** aplicar `BMV-APP-C9-C-c822926.bundle` (fast-forward na `auditoria/regras-bmv`, sobre `9332aaa`) → rodar o **CI "Build APK"**.
2. **Se CI verde + revisão OK:** aprovar C9-C → decidir sobre os findings (reconciliar antes do C9-D) → iniciar **C9-D**.
3. **Se CI falhar:** parar; diagnosticar antes do C9-D. **Não iniciar C9-D sem aprovação.**