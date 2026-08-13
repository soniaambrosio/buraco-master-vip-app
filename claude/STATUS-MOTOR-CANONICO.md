# Status — Motor canônico (RulesEngine), migração progressiva

**Branch (app):** `auditoria/regras-bmv`. **Branch (servidor):** `correcao/conformidade-canonica` → **mesclada na `main` (PR #1) e DEPLOYADA**. Motor antigo (`mesa.dart`) = padrão até C10.
**Docs:** `PLANO-RULESENGINE-CANONICO.md`, `PLANO-C8-DART-NODE.md`, `RELATORIO-DART-NODE-C8.md`, `RELATORIO-C8B-FLUXO-NODE.md`, `PLANO-SERVIDOR-CONFORMIDADE.md`, `RELATORIO-C8-FECHAMENTO.md`, `PLANO-C9-MOTOR-FLAG.md` (v2.1), `RELATORIO-C9C-SOMBRA.md`.
**Entrega:** commit local → `git bundle` → upload web → Codespace `git fetch ./bundle` → push → Actions.

## Progresso por commit (app)
- **C1..C7 — CI VERDE — APROVADOS.** Motor canônico completo (`app/lib/rules/`).
- **C8 — ENCERRADO; promoção online DESBLOQUEADA.** Servidor deployado (`main`, `sha256=81ec3255…`, 0 CRIT).
- **C9-A — `07b9ff0` — CI #136 — APROVADO.** Flags + porta tipada + fábrica/seletor.
- **C9-B + fix — `9332aaa` — CI #138 — APROVADO.** Projeção/envelope + adaptadores + costura OFF.
- **C9-C + C9-C-fix — `4e35594` — CI #140 — APROVADO.** Modo sombra + comparador; Replay completo.
- **C9-C2a + fix — `0d03526` — CI #141 — APROVADO.** Reconcilia `monte vazio + morto` (§8.1) + paridade de envelope.
- **C9-C2b + C9-C2b-fix — `2bc7768` — CI #142 — APROVADO.** Objetivo 2: `baixar`/`bater` como transações semânticas + estabilização; quadrantes de legalidade EXPLÍCITOS.
- **C9-C2c + fix + fix2 — `d0664c2` — CI #144 — APROVADO.** **Objetivos 3 e 4** — cenários REAIS EXC-01..04 + **classificador VERIFICADOR** (tag + condição concreta) + **verificador econômico da EXC-02** (fix) + reconciliação da **exaustão** (monte+mortos vazios) + **fix2** (`C9-SOMBRA-05` atualizado ao contrato). Suíte **291 `test()`** — todos verdes. *(Histórico: C9-C2c=`de9ad89`, fix=`fb4d066`; #143 falhou só em `C9-SOMBRA-05`, corrigido no fix2 → #144 verde.)*

## C9-C2c — verdade de campo das quatro EXC (investigada no código real)
- **EXC-01 (trinca c/ curinga): RECONCILIADA** — o legado atual já recusa Joker em trinca; canônico também → ambos recusam / CONVERGE. Não dirigível por transação.
- **EXC-02 (abertura múltipla atômica): DIVERGÊNCIA VIVA** — única dirigível por sombra. Legado baixa 1 jogo/chamada (1º < mínimo → RECUSA); canônico soma numa abertura atômica (≥ mínimo → ACEITA). Verificada por `_ehEXC02` pela **ECONOMIA REAL** (C9-C2c-fix): via `avaliarBaixar` (autoridade canônica), exige 1º jogo isolado ABAIXO do mínimo **e** conjunto atômico ATINGINDO o mínimo — não só o formato. Detector negativo `C9-EXC02-FORMATO-SEM-ECONOMIA` garante que formato sem economia → INESPERADA.
- **EXC-03 (lixo fechado desacoplado): NÍVEL-FUNÇÃO** — o `Acao ComprarLixo` não carrega `jogosNovos`, então não é dirigível por transação de sombra; coberta chamando `avaliarComprarLixo` direto.
- **EXC-04 (grupo de ases): RECONCILIADA em nível de ESTADO** — Fechado ambos aceitam (mesmo meld), Aberto ambos recusam. Restava só diferença de classificação/pontuação (de_as × trinca), fora da assinatura de estado. **FECHADA no C10 Parte 2** — a pontuação passou a ter um classificador só.
- **Classificador:** `excConhecida` → `excVerificada` (verificada por condição concreta) nas duas saídas; EXC declarada sem condição real → INESPERADA; condição real sem id correto → INESPERADA. Quatro quadrantes de legalidade mantidos.
- **Exaustão:** canônico `ComprarMonte` com monte+mortos vazios agora ENCERRA a rodada (`rodadaEncerrada=true`) — mesmo efeito do legado; assinaturas coincidem → CONVERGE.
- **Meta final:** ZERO inesperadas em todos os cenários convergentes (as INESPERADAS restantes são injeções propositais e negativos do verificador, todas com Replay).

## C9 — motor canônico atrás de flag (plano v2.1 aprovado)
- **C9-A / C9-B+fix / C9-C+fix / C9-C2a+fix / C9-C2b+fix / C9-C2c+fix+fix2 — TODOS APROVADOS.** Comparador de sombra: execução dupla → normalização → quadrantes de legalidade explícitos → comparação (estado + envelope relevante) → diff → Replay completo. Estabiliza morto direto/indireto e batida; classificador verificador de EXC (econômico na EXC-02).
- **C9-C2 (fechamento de paridade pré-C9-D): CONCLUÍDO e APROVADO** — 2a (monte→morto + envelope), 2b+fix (baixar/bater + quadrantes), 2c+fix+fix2 (EXC reais + classificador verificador econômico + exaustão + meta 0 inesperadas — **CI #144, SHA `d0664c2`**). Autoridade OFF; RuleSpec inalterada; `mesa.dart` padrão.
- **C9-D (só após autorização da direção):** ativação atrás da flag (autoridade ON, fronteira atômica; fallback só técnico com telemetria/Replay). Padrão continua OFF. **BLOQUEADO — não iniciado.** Base do C9-D = novo hash da branch oficial (após versionamento desta documentação), a ser informado pela direção.

## Servidor — patch de conformidade — DEPLOYADO e validado
- **`main`, `sha256(server.js)=81ec3255…`** (== `09835bd`); `/health`=`ok`; smoke OK. CRIT-01/02/03 corrigidos; bundle real 8/8 → 0 CRIT.

## Exceções do modo sombra (declaradas; remoção no C10)
- **EXC-01** trinca com curinga — RECONCILIADA (ambos recusam). **EXC-02** abertura múltipla — VIVA (verificada pela economia). **EXC-03** lixo fechado desacoplado — nível-função. **EXC-04** grupo de ases — RECONCILIADA em estado (resta classificação/pontuação).

## Regras congeladas (RuleSpec `bmv-regras-2026.08`)
Vulnerabilidade +75/+90 (limiar meta/2 = 750, uniforme bot=humano); trinca só natural no Fechado; Joker e "2" fora da trinca; abertura múltipla atômica; topo do lixo com uso em ≥1 jogo; jogador e bot mesma legalidade; **fase do turno é regra**; **esvaziar a mão é regra**; UI não decide regra. Conversão §8.1: monte vazio → morto de menor índice vira monte (agora no canônico também). Exaustão: monte+mortos vazios encerra a rodada (canônico == legado).
Pontuação: A=15, JOKER=50, 2=10, 8..K=10, 3..7=5; canastra as_a_as=1000/de_500=500/limpa=200/suja=100; batida +100; mão desconta; morto não pego −100 (isento se convertido).

## C10 — corte canônico (promoção à autoridade padrão da partida LOCAL)
- **Parte 1 — `14b8d03` (= `fa1902f` + `ff89f79` + `ab7f46d` + `14b8d03`) — APROVADA pela Sônia.** Contrato ATÔMICO da compra do lixo Fechado/STBL (EXC-03): `ComprarLixo(topoDeclarado, jogosNovos, extensoes)`, `derivarCandidatosCompraLixoFechado` (lazy/streaming, sem caps e sem materializar 2^n), `MotorConfig.producao()`/`legadoRollback()`. `mesa.dart` intocado, flag OFF. Suíte 325 `test()`.
- **Parte 2 — PROMOÇÃO DO CONSUMIDOR REAL — entregue para revisão + CI.** Ver `RELATORIO-C10-PARTE2-PROMOCAO.md`. Base `14b8d03`.
  - **ROOT flipado:** a partida local nasce em `MotorConfig.producao()`; rollback só por `MesaScreen(motorConfig: MotorConfig.legadoRollback())`, pré-transação e imutável depois.
  - **Autoridade ÚNICA:** acabou o fallback técnico. Falha técnica é **fail-closed** (recusa + estado intacto + evidência em `ultimaFalhaTecnica`). `_falharFechado` substituiu `_registrarFallbackTecnico`.
  - **`estender` roteado:** era o último furo; virou `Baixar(extensoes:)` via o novo `Jogo.baixarAtomico` — que é também como a **abertura múltipla (EXC-02)** existe no modelo.
  - **EXC-04 FECHADA:** `contarPontos()` e `pontosMesaAoVivo` contam por `pontuacao_canonica` + `meld_validator`. A diferença que sobrava era de classificação na hora de pontuar (`de_as` × `trinca`); com um só classificador no caminho, não há duas respostas. Costura nova: `motor/pontuacao_costura.dart`.
  - **Lixo no consumidor real:** 0 → recusa, 1 → executa, 2+ → seletor mínimo (a autoridade enumera, o jogador escolhe). Derivação **agendada fora do frame**, sem nenhum cap semântico.
  - **Robô auditado:** heurística escolhe a intenção e qual candidato; a legalidade é sempre canônica. As redes que chamavam `_passarVez()` direto viraram parada com evidência; `_rodarBots` ganhou guarda de progresso.
  - **`lixoTopoObrigatorio` morreu sob o canônico:** com a compra atômica a obrigação diferida não nasce. É a prova de que o §5 foi respeitado.
  - **Verificação local (overlay do CI reproduzido):** 358 `test()` verdes; `flutter analyze` com 0 erros e diff de avisos **idêntico** ao de `14b8d03`. Não substitui o portão §16.
  - **Sombra:** exclusivamente diagnóstica — `producao()` nasce com sombra OFF e `mesa.dart` nunca consulta `sombraAtiva`.

## Próximo
1. **Sônia:** aplicar o bundle/diff da Parte 2 na `auditoria/regras-bmv` e rodar o **Build APK**. Nada é concluído sem CI verde + revisão (§16).
2. **Decisão de produto pendente (§18, reportada e não contornada):** abertura múltipla no **gesto** da mesa. O motor faz, a compra do lixo usa, mas o toque no feltro baixa um jogo por vez. Três opções no relatório da Parte 2 — nenhuma implementada.
3. **Opcional de CI:** mover "Declare assets in pubspec" para antes do portão de qualidade, para viabilizar teste de widget da mesa.
4. **Online/Railway:** fora do C10 (§15). Sem merge, deploy ou publicação sem autorização explícita.
