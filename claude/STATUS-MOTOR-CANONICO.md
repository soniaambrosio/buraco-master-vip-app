# Status — Motor canônico (RulesEngine), migração progressiva

**Branch (app):** `auditoria/regras-bmv`. **Branch (servidor):** `correcao/conformidade-canonica` → **mesclada na `main` (PR #1) e DEPLOYADA**. Motor antigo (`mesa.dart`) = padrão até C10.
**Docs:** `PLANO-RULESENGINE-CANONICO.md`, `PLANO-C8-DART-NODE.md`, `RELATORIO-DART-NODE-C8.md`, `RELATORIO-C8B-FLUXO-NODE.md`, `PLANO-SERVIDOR-CONFORMIDADE.md`, `RELATORIO-C8-FECHAMENTO.md`, `PLANO-C9-MOTOR-FLAG.md` (v2.1), `RELATORIO-C9C-SOMBRA.md`.
**Entrega:** commit local → `git bundle` → upload web → Codespace `git fetch ./bundle` → push → Actions.

## Progresso por commit (app)
- **C1..C7 — CI VERDE — APROVADOS.** Motor canônico completo (`app/lib/rules/`). HEAD C7 `7d727ae` (+251).
- **C8 — ENCERRADO OFICIALMENTE; promoção online DESBLOQUEADA.** Servidor canônico deployado (`main`, `sha256=81ec3255…`, 0 CRIT); portão `C8-CONFORMIDADE` exige conjunto crítico vazio.
- **C9-A — `07b9ff0` — CI #136 VERDE — APROVADO.** Flags + porta tipada + fábrica/seletor.
- **C9-B + C9-B-fix — `9332aaa` — CI #138 VERDE — APROVADO.** Projeção/envelope + adaptadores + costura runtime OFF; preserva as 3 fases + clone profundo `pontosRodada`.
- **C9-C — `c822926`/`3381a21` — CI #139 VERDE.** Modo sombra + comparador. (Revisão pediu 1 fix de Replay — abaixo.)
- **C9-C-fix — `0379145`** (sobre `3381a21`): Replay de sombra persiste EstadoJogo **+ EnvelopeRuntime completo**; `reproduzivel` exige snapshot completo validável. **Entregue:** `BMV-APP-C9-C-fix-0379145.bundle` + `C9-C-fix-0379145.diff` (aplica por conteúdo sobre `3381a21`). Suíte **272 → 273 `test()`**. **ENTREGUE — pendente push + CI + revisão da Sônia.**

## C9 — motor canônico atrás de flag (plano v2.1 aprovado)
- **C9-A (`07b9ff0`, APROVADO):** flags (2 independentes OFF), contrato tipado da porta, seletor/fábrica.
- **C9-B+fix (`9332aaa`, APROVADO):** projeção pela matriz; adaptadores concretos; composição (OFF⇒legado); costura mínima em `mesa.dart`.
- **C9-C + C9-C-fix (`0379145`, entregue):** `modo_sombra.dart` — comparador puro, autoridade OFF, sombra separada, execução dupla sobre clones com EnvelopeRuntime COMPLETO. Pipeline de 6 etapas; classificação `CONVERGE/EXC-01..04/INESPERADA/canonicoRecusou`; EXC só por id declarado e conhecido (não declarado/inexistente = INESPERADA).
  - **Replay (C9-C-fix):** snapshot COMPLETO `{canonico, envelope}` (15 campos runtime+sidecar); `reproduzivel` = seed **OU** snapshot completo validável (contém `canonico` E `envelope`; mapa arbitrário não conta). `rules/replay.dart` valida só o contrato de topo — segue **desacoplado** de `mesa.dart`; snapshot trafega como mapa genérico.
  - `projecao_estado.dart`: descoberta da sombra — topo do monte reconciliado (reversão na projeção; round-trip exato).
  - Testes C9-SOMBRA-01..10; **meta 0 inesperadas** nos convergentes (01/02). **C9-SOMBRA-10** prova reprodução de divergência DEPENDENTE do envelope (`lixoTopoObrigatorio`). Relatório: `RELATORIO-C9C-SOMBRA.md`.
  - **Findings declarados p/ reconciliar antes do C9-D:** monte vazio → morto (legado converte × canônico recusa); expandir a sombra p/ `baixar`/`bater` + EXC-01..04 reais.
 - **C9-C-fix — original `0379145`; aplicado por cherry-pick como `d9cd88f`.**
  Replay agora persiste EstadoJogo + EnvelopeRuntime completo; `reproduzivel` exige seed ou snapshot completo validável; C9-SOMBRA-10 cobre divergência dependente do envelope. **Pendente: push + CI + revisão final.**

## Servidor — patch de conformidade — DEPLOYADO e validado
- **`main`, `sha256(server.js)=81ec3255…`** (== `09835bd`); `/health`=`ok`; smoke OK. CRIT-01/02/03 corrigidos; bundle real 8/8 → 0 CRIT.

## Exceções do modo sombra (declaradas; remoção no C10)
- **EXC-01** trinca com curinga. **EXC-02** abertura múltipla. **EXC-03** lixo fechado desacoplado. **EXC-04** grupo de ases = trinca canônica.

## Regras congeladas (RuleSpec `bmv-regras-2026.08`)
Vulnerabilidade +75/+90 (limiar meta/2 = 750, uniforme bot=humano); trinca só natural no Fechado; Joker e "2" fora da trinca; abertura múltipla atômica; topo do lixo com uso em ≥1 jogo; jogador e bot mesma legalidade; **fase do turno é regra**; **esvaziar a mão é regra**; UI não decide regra.
Pontuação: A=15, JOKER=50, 2=10, 8..K=10, 3..7=5; canastra as_a_as=1000/de_500=500/limpa=200/suja=100; batida +100; mão desconta; morto não pego −100.

## Próximo
1. **Sônia:** versionar a atualização documental → push da branch → rodar o **CI "Build APK"**.
2. **Se CI verde + revisão OK:** aprovar **C9-C-fix**.
3. **C9-D continua BLOQUEADO** até reconciliar **monte vazio + morto disponível** e ampliar a sombra para **baixar/bater + cenários reais EXC-01..04**.