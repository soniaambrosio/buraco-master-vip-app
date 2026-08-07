# Relatório C8-B — auditoria só-leitura do FLUXO do servidor Node

**Spec:** `bmv-regras-2026.08` (autoridade). **Canônico:** `app/lib/rules/` (base `8a2d7c1`).
**Servidor:** `soniaambrosio/buraco-servidor` `server.js@be72bb6` (sha256 `c43c3e98…`), **clone só leitura**. **Nada foi alterado, nenhum deploy.**
**Evidência:** as funções de fluxo do servidor foram copiadas VERBATIM e **executadas** sobre estados sintéticos em `auditoria/conformidade/fluxo_harness.js` (18/18 cenários com o comportamento esperado). Complementado pela leitura direta do código (linhas citadas).

**Classificação:** CONVERGE · DIFERENÇA NÃO CRÍTICA · EXC já declarada · CRIT (bloqueia online).

## Resultado por item
| # | Regra | Servidor (evidência) | Classificação |
|---|-------|----------------------|---------------|
| 1 | Abertura múltipla soma o mínimo | `checarAberturaVulneravel` soma TODAS as melds da dupla vs mín. (l.1971) | **CONVERGE** (ver DIF-FLOW-02 p/ o mecanismo) |
| 2 | Vulnerabilidade +75/+90 | `min = niv===1?75:90` (l.1970); vulnerável ≥ meta/2, escala até 2 (l.2207) | **CONVERGE** |
| 3 | Lixo Fechado/STBL: topo com uso, outros completam o mínimo | `comprarLixo`→`topoTemUsoLegal` (uso do topo, l.1939) desacoplado do mínimo (foul separado) | **CONVERGE** (EXC-03 era motor antigo) |
| 4 | Enterradas NÃO justificam a compra | `topoTemUsoLegal` vê só mão+topo; lixo entra na mão DEPOIS (l.1948) — T04 rejeita | **CONVERGE** |
| 5 | Aberto pega lixo sem baixar | `if (modalidade!=="aberto")` pula uso/`deveUsarTopo` (l.1938) — T05 ok | **CONVERGE** |
| 6 | Fase compra→jogo→descarte | `validarVez` via `jaComprou` (`precisaComprar`/`precisaTerComprado`, l.1770-1771) | **CONVERGE** (ver DIF-FLOW-03 p/ morto pendente) |
| 7 | Impedir compra dupla | `precisaComprar && jaComprou → "já comprou"` (l.1770) — T07 | **CONVERGE** |
| 8 | Impedir descarte antes da compra | `precisaTerComprado && !jaComprou` (l.1771) — T08 | **CONVERGE** |
| 9 | Morto direto e indireto | direto=`aoZerarMaoBaixando` mantém a vez (l.1847); indireto=`descartar` pega e `passarVez` (l.2036-2038) — T09/T10 | **CONVERGE** |
| 10 | Descarte da última → morto ou batida | zera+morto→indireto; zera+cumprido+canastra→batida; senão ILEGAL (l.2018-2043) — T10 | **CONVERGE** |
| 11 | Baixar a última sem morto/canastra → rejeita | `baixadaTravaria` (l.2087) — T11 rejeita | **CONVERGE** (ver DIF-FLOW-04) |
| 12 | Ações fora da vez | `validarVez`: `vez!==assento → "não é a sua vez"` (l.1769) — T12 | **CONVERGE** |
| 13 | Rodada encerrada → nenhuma ação | `validarVez`: `rodadaEncerrada`/`encerrada` (l.1767-1768) — T13 | **CONVERGE** |
| 14 | Conservação de IDs/cartas | fluxo MOVE cartas (shift/push/splice/filter/concat), não cria — T14 conserva o multiconjunto | **CONVERGE** |

## Veredito
**Nenhuma divergência crítica NOVA no fluxo.** As únicas CRIT continuam sendo as do C8-A (meld/pontuação): **CRIT-01 (de_500)** e **CRIT-02 (as_a_as)** — promoção online segue **BLOQUEADA** por elas. O fluxo (turno, compra, lixo, abertura, morto, batida, encerramento, conservação) **converge** com o motor canônico. A liberação de batida também converge (Fechado aceita suja; Aberto/STBL só limpa; trinca nunca; grupo de ases nunca).

## Diferenças NÃO críticas (registradas, não bloqueiam)
- **DIF-FLOW-02 — mecanismo da abertura vulnerável:** o servidor PERMITE baixar fraco e ANULA no descarte (devolve cartas à mão e o lixo ao monte de descarte; escala p/ 90+ — l.1976-1990); o canônico REJEITA a abertura fraca já no `avaliarBaixar`. Resultado final igual (abertura abaixo do mínimo não fica em pé). Diferença de timing/UX.
- **DIF-FLOW-03 — modelagem do morto indireto:** o servidor resolve o morto indireto INLINE no descarte (pega o morto e `passarVez` no mesmo passo); o canônico modela um estado explícito `mortoPendente` e uma ação `PegarMorto(viaDescarte)`. Mesmo efeito observável (pega o morto, passa a vez).
- **DIF-FLOW-04 — trava de esvaziamento:** o servidor barra a baixada já quando sobraria **≤ 1** carta impossível de descartar (protege o "clássico erro", l.2088) e, na trava do baixar, só considera **limpa/de_500** (não suja); o canônico barra quando a mão ficaria **em 0** e trata o caso de 1 carta no descarte. O servidor é mais conservador (barra mais cedo); nenhum dos dois deixa o jogador num estado impossível.

## Divergência sinalizada para SUA decisão (candidata a CRIT ou aceite)
- **DIF-FLOW-01 — legalidade uniforme jogador × bot na abertura vulnerável:** o motor do servidor **isenta os BOTS** do foul de abertura vulnerável (`if (assentos[assento].tipo !== "humano") { abriuValido=true; return null }`, l.1974) — confia que o cérebro do bot (`minimoAbertura`) não abre fraco. O canônico aplica o mínimo **uniformemente** (o `avaliarBaixar` não conhece "humano/bot"). Na prática os bots se auto-regulam, então não observei estado de jogo errado — por isso classifiquei como **DIFERENÇA NÃO CRÍTICA**. Mas como "jogador e bot mesma legalidade" é regra congelada, deixo explícito para você decidir se vira **CRIT** (bloqueia online até o motor do servidor aplicar o mínimo também aos bots) ou fica aceite.

## Ação futura (registrada; nenhuma correção feita nesta fase)
Ao atualizar o servidor Node (fase separada, com sua autorização): (1) implementar CRIT-01/CRIT-02 (de_500=500; as_a_as válido/1000); (2) se você classificar DIF-FLOW-01 como CRIT, aplicar o mínimo de abertura também aos bots no motor; (3) reexecutar `fluxo_harness.js` + os vetores do C8-A. A spec `bmv-regras-2026.08` permanece a autoridade; **não reconciliar o canônico ao servidor**.

## Escopo/limites desta fase
Comparação por (a) leitura direta do código do servidor (linhas citadas) e (b) execução das funções de fluxo reais sobre estados sintéticos. Não é um portão de CI cross-engine de fluxo (o fluxo do servidor é stateful/WS); se você quiser, um C8-C pode transformar estes cenários num portão automatizado. Cartas 100% sintéticas; nada de `dados/`, contas, tokens ou produção foi lido.
