# Relatório de conformidade C8 — Dart (canônico) × Node (servidor deployado)

**Spec:** `bmv-regras-2026.08` (autoridade). **Motor canônico:** `app/lib/rules/` (base `7d727ae`).
**Servidor:** `soniaambrosio/buraco-servidor` `server.js@be72bb6` (sha256 `c43c3e98…`), clone **só leitura**. **Sem deploy, sem push, sem alteração no servidor.** Extrato de regras: `auditoria/conformidade/servidor_regras_extraidas.js` (sha256 `6ade2909…`), sem segredos.

**Método:** os mesmos vetores sintéticos rodam nos dois motores. MELD compara **legalidade** e **bônus de canastra** (efeito, não rótulo). PONTUAÇÃO compara o **total** da rodada. Portão no CI: `C8-HASH` + `C8-CONFORMIDADE` (`app/test/teste_motor.dart`).

## Veredito
**PROMOÇÃO ONLINE: BLOQUEADA.** Duas divergências críticas conhecidas (CRIT-01, CRIT-02). Nenhuma divergência crítica inesperada. As demais famílias convergem em efeito.

## Divergências críticas (bloqueiam promoção online)
| ID | Regra | Canônico (Dart) | Servidor (Node) | Impacto | Vetores |
|----|-------|-----------------|-----------------|---------|---------|
| **CRIT-01** | Canastra de 500 (A–K limpa, 13 cartas) | `de_500` = **500** pts | classifica como `limpa` = **200** pts (o tipo `de_500` existe no código mas é **morto** — `finalizar` nunca o gera) | Pontuação: −300 por de_500 | `M07-de500` (bônus 500×200), `S05-de500-pontos` (total 610×310) |
| **CRIT-02** | Canastra as_a_as (A–K–A, 14 cartas) | **válido** = **1000** pts | **inválido** (rejeita Ás repetido na sequência) | Legalidade + pontuação | `M08-as_a_as` (válido×inválido) |

## Convergências (sem efeito de jogo)
| Família | Resultado |
|---------|-----------|
| Valor das cartas | idêntico (A=15, JOKER=50, 2/8–K=10, 3–7=5) |
| Sequência limpa/suja (7+) | idêntico (bônus 200/100) |
| Trinca natural | válida nos dois; sem bônus; **rótulo** difere (canônico `trinca` × servidor `aberta`/`limpa`) sem efeito |
| Trinca com curinga | **inválida** nos dois (o canônico casa com o servidor — a antiga EXC-01 era motor antigo × canônico) |
| Grupo só de ases | **EXC-04**: canônico `trinca` × servidor `de_as` — diferença só de **rótulo**; nenhum dos dois dá bônus nem libera batida; inválido no Aberto nos dois |
| Batida (+100), morto não pego (−100), desconto da mão | idênticos |
| Liberação de batida | idêntica (trinca nunca; grupo de ases nunca; limpa/de_500 sim) |

## Diferenças de rótulo NÃO críticas (registradas, não bloqueiam)
- Sequência 3–6 cartas: canônico rotula `limpa/suja`; servidor `aberta`. Sem efeito (não é canastra, sem bônus).
- Grupo de ases (EXC-04) e trinca 7+: rótulos diferentes, efeito nulo (batida usa `validarSequencia`, que recusa grupos de valor igual nos dois).

## Ação futura obrigatória (registrada por decisão da Sônia)
Atualizar o servidor Node (`buraco-servidor`) para **reproduzir exatamente a regra canônica**: (1) `finalizar` deve gerar `de_500` (A–K limpa 13 → 500) em vez de `limpa`; (2) aceitar `as_a_as` (A–K–A 14 → 1000). Depois, **reexecutar os vetores cross-engine** (`node auditoria/conformidade/node_harness.js` + CI) e reclassificar CRIT-01/CRIT-02. Enquanto isso não ocorrer, a promoção online permanece **BLOQUEADA**. **A spec canônica `bmv-regras-2026.08` continua a autoridade — não reconciliar o canônico ao servidor.**

## Escopo desta etapa (declarado, não omitido)
Comparadas as regras que o Node expõe como **função pura**: meld (legalidade/classificação/bônus) e pontuação da rodada (cartas, canastra, batida, morto, mão). Fase/turno e a orquestração de compra/lixo/abertura no servidor são lógica de sessão (WS), não função pura isolada — ficam para uma etapa de comparação de fluxo posterior (não entram neste portão).
