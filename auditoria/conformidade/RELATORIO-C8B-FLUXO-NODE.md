# Relatório C8-B — auditoria só-leitura do FLUXO do servidor Node

**Spec:** `bmv-regras-2026.08` (autoridade). **Canônico:** `app/lib/rules/` (base `8a2d7c1`).
**Servidor:** `soniaambrosio/buraco-servidor` `server.js@be72bb6` (sha256 `c43c3e98…`), **clone só leitura**. **Nada foi alterado, nenhum deploy.**
**Evidência:** as funções de fluxo do servidor foram copiadas VERBATIM e **executadas** sobre estados sintéticos em `auditoria/conformidade/fluxo_harness.js` (**20/20** cenários com o comportamento esperado). Complementado pela leitura direta do código (linhas citadas).

**Classificação:** CONVERGE · DIFERENÇA NÃO CRÍTICA · EXC já declarada · CRIT (bloqueia online).

## Resultado por item
| # | Regra | Servidor (evidência) | Classificação |
|---|-------|----------------------|---------------|
| 1 | Abertura múltipla soma o mínimo | `checarAberturaVulneravel` soma TODAS as melds da dupla vs mín. (l.1971) | **CONVERGE** (regra); ver **CRIT-03** (isenção de bot) e DIF-FLOW-02 (mecanismo) |
| 2 | Vulnerabilidade +75/+90 | `min = niv===1?75:90` (l.1970); vulnerável ≥ meta/2, escala até 2 (l.2207) | **CONVERGE** no valor; **CRIT-03** na aplicação (bot isento) |
| 3 | Lixo Fechado/STBL: topo com uso, outros completam o mínimo | `comprarLixo`→`topoTemUsoLegal` (l.1939) desacoplado do mínimo | **CONVERGE** (EXC-03 era motor antigo) |
| 4 | Enterradas NÃO justificam a compra | `topoTemUsoLegal` vê só mão+topo; lixo entra na mão DEPOIS (l.1948) — T04 rejeita | **CONVERGE** |
| 5 | Aberto pega lixo sem baixar | `if (modalidade!=="aberto")` pula uso/`deveUsarTopo` (l.1938) — T05 ok | **CONVERGE** |
| 6 | Fase compra→jogo→descarte | `validarVez` via `jaComprou` (l.1770-1771) | **CONVERGE** (DIF-FLOW-03 p/ morto pendente) |
| 7 | Impedir compra dupla | `precisaComprar && jaComprou` (l.1770) — T07 | **CONVERGE** |
| 8 | Impedir descarte antes da compra | `precisaTerComprado && !jaComprou` (l.1771) — T08 | **CONVERGE** |
| 9 | Morto direto e indireto | direto=`aoZerarMaoBaixando` mantém a vez (l.1847); indireto=`descartar`+`passarVez` (l.2036) — T09/T10 | **CONVERGE** |
| 10 | Descarte da última → morto ou batida | zera+morto→indireto; zera+cumprido+canastra→batida; senão ILEGAL (l.2018-2043) — T10 | **CONVERGE** |
| 11 | Baixar a última sem morto/canastra → rejeita | `baixadaTravaria` (l.2087) — T11 rejeita | **CONVERGE** (DIF-FLOW-04) |
| 12 | Ações fora da vez | `validarVez`: `vez!==assento` (l.1769) — T12 | **CONVERGE** |
| 13 | Rodada encerrada → nenhuma ação | `validarVez`: `rodadaEncerrada`/`encerrada` (l.1767-1768) — T13 | **CONVERGE** |
| 14 | Conservação de IDs/cartas | fluxo MOVE cartas (shift/push/splice/filter/concat), não cria — T14 conserva o multiconjunto | **CONVERGE** |

## Veredito
**PROMOÇÃO ONLINE: BLOQUEADA** por TRÊS divergências críticas: **CRIT-01** e **CRIT-02** (meld/pontuação, do C8-A) e **CRIT-03** (fluxo, abaixo). Fora dessas, o fluxo **converge** com o motor canônico nos 14 itens. A liberação de batida também converge (Fechado aceita suja; Aberto/STBL só limpa; trinca nunca; grupo de ases nunca).

## Divergências críticas do fluxo (bloqueiam promoção online)
- **CRIT-03 — validação de vulnerabilidade NÃO uniforme (bot × humano)** *(decisão Sônia)*: o MOTOR do servidor **isenta os bots** do foul de abertura vulnerável (`if (jogo.assentos[assento].tipo !== "humano") { abriuValido=true; return null }`, l.1974) — ele confia que o cérebro do bot (`minimoAbertura`) não abre fraco. O motor canônico aplica o mínimo **+75/+90 uniformemente** (o `avaliarBaixar` não conhece humano/bot). **Evidência (fluxo_harness.js):** dupla vulnerável nível 1 (mín 75) abrindo 15 pts — assento BOT: o servidor DEIXA a abertura em pé; assento HUMANO idêntico: o servidor ANULA. O canônico rejeitaria os DOIS no `avaliarBaixar`. **NÃO é EXC.** Princípio congelado: *estratégia do bot decide o que tentar; o RulesEngine decide o que é legal* — o motor deve continuar validando e recusando a ação ilegal, mesmo de bot.

*(Referência C8-A:* **CRIT-01** de_500 canônico 500 × servidor 200; **CRIT-02** as_a_as canônico válido/1000 × servidor inválido.)*

## Diferenças NÃO críticas (registradas, não bloqueiam)
- **DIF-FLOW-02 — mecanismo da abertura vulnerável:** servidor PERMITE baixar fraco e ANULA no descarte (devolve cartas/lixo; escala p/ 90+, l.1976-1990); canônico REJEITA no `avaliarBaixar`. Resultado final igual (abertura fraca não fica em pé — para o HUMANO). Diferença de timing/UX. *(A isenção do BOT nesse mesmo mecanismo é o CRIT-03 acima.)*
- **DIF-FLOW-03 — modelagem do morto indireto:** servidor resolve inline no descarte (pega o morto e `passarVez`); canônico usa estado `mortoPendente` + ação `PegarMorto(viaDescarte)`. Mesmo efeito observável.
- **DIF-FLOW-04 — trava de esvaziamento:** servidor barra já quando sobraria **≤ 1** carta impossível (l.2088) e considera só limpa/de_500; canônico barra quando a mão ficaria **em 0**. Servidor mais conservador; nenhum deixa estado impossível.

## Ação futura obrigatória (nenhuma correção feita nesta fase)
Ao atualizar o servidor Node (fase separada, com sua autorização): (1) **CRIT-01/CRIT-02** — implementar de_500=500 e as_a_as válido/1000; (2) **CRIT-03** — o motor do servidor deve validar o mínimo de abertura vulnerável por **um único caminho para bot e humano** (remover a isenção `tipo !== "humano"`); a inteligência do bot pode escolher NÃO tentar abrir fraco (estratégia), mas o motor recusa a ação ilegal; (3) **reexecutar** os vetores cross-engine específicos (`fluxo_harness.js` CRIT-03 + vetores C8-A). Spec `bmv-regras-2026.08` permanece a autoridade; **não reconciliar o canônico ao servidor**. Promoção online **BLOQUEADA** até CRIT-01/02/03 fecharem.

## Escopo/limites desta fase
Comparação por (a) leitura direta do código (linhas citadas) e (b) execução das funções de fluxo reais sobre estados sintéticos. Não é um portão de CI cross-engine de fluxo (o fluxo do servidor é stateful/WS); um C8-C pode transformar estes cenários num portão automatizado, se você quiser. Cartas 100% sintéticas; nada de `dados/`, contas, tokens ou produção foi lido.
