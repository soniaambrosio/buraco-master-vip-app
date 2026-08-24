# OS 46 — saneamento canônico de `contratosui/T27` na arquitetura P V1

Correção independente da infraestrutura P. Não pertence a Torneios, à OS 40, à
OS 30 nem à Comunicação Controlada, e não toca em nenhuma delas.

## A base

Ponta P executiva mais recente que ainda reproduzia T27:

    correcao/os42-c2-torneiobase-fail-closed-v1
    828d5a0e5a7e57a575ecd7b906629a746b6a4cc2

Ela descende das duas referências obrigatórias de comparação —
`integracao/perfil-social-funcional-raiz-p-v1` (`21ddf47b`) e
`integracao/base-p-torneios-vip-fundacao-v1` (`5306e3f7`) — pela cadeia
`21ddf47b → 5306e3f7 → f328420 → 2cc62d2 → 828d5a0`.

Nenhuma das quatro folhas P que tocam estes arquivos carregava correção
concorrente: todas tinham a mesma fixture de quatro logs.

## O defeito

A FASE B de `verificar_contrato_suites.sh` exige um `t_<gate>.log` para **todo**
gate que carrega contrato na fonte única. A fixture `resultados()` de
`teste_contrato_suites.sh` montava a evidência sintética com **quatro** logs
escritos à mão — `comunicacao`, `chatdom`, `portaoci`, `contratosui`.

Quando a composição de Perfil/Social acrescentou **onze** contratos de uma vez, a
fixture não acompanhou. T27 é o único caso de FASE B que espera exit 0; passou a
receber 1. O déficit cresce a cada contrato novo e é o mesmo em toda a linhagem:

| árvore | contratos na fonte | logs da fixture | faltando |
|---|---|---|---|
| `21ddf47b` (referência) | 15 | 4 | 11 |
| `5306e3f7` (referência) | 16 | 4 | 12 |
| `828d5a0e` (base) | 17 | 4 | 13 |

Além dos treze logs ausentes, o `t_contratosui.log` da própria fixture declarava
`casos ok: 34` contra o piso de 74 — a fixture também mentia sobre o tamanho da
matriz que ela mesma representa.

**Das quatro hipóteses da OS, a que se confirma é a primeira.** A fixture estava
incompleta. O contrato esperado não estava desatualizado (o piso e os literais
descreviam a matriz real); o leitor da fonte interpretou corretamente cada
atributo — margem é entrada, linha indentada é atributo; e a topologia cobrada
pela FASE B não foi superada: continua sendo exatamente a que o CI produz, um
log por gate contratado. Por isso o conserto é a fixture derivar da fonte, e
**não** T27 passar a esperar vermelho.

## A correção

`resultados()` deixou de ser lista escrita à mão. A relação de gates vem da
própria fonte única, pelo auxiliar novo `gates_com_contrato` — a mesma pergunta
que `conferir_entrada` faz do outro lado. A linha de log carrega os dois
contadores de uma vez (`+N` do Flutter e `casos ok: N` dos portões em bash),
porque `contador` é por gate e a fixture não tem como conhecer o vocabulário de
cada um.

Com isso, `resultados_completos()` — a cópia já derivada que a OS 42-C2 criou
justamente para não mexer em `resultados()` — deixou de ter razão de existir. As
quatro chamadas da campanha C2 passaram a usar a fixture única. Duas fixtures
para o mesmo cenário garantem que uma delas envelheça sozinha.

Nenhuma Function produtiva, nenhum arquivo de Torneios, Loja, Comunicação ou
Ajustes, nenhum export e nenhum segundo manifesto foram tocados. `fundacao_v1.dart`
não foi tocado. Nenhum gatilho ou permissão do CI foi ampliado.

## A campanha negativa

Seis casos novos na matriz do gate `contratosui`:

| caso | o que reprova |
|---|---|
| OS46-01 | a fixture deixa log de **todo** gate com contrato |
| OS46-02 | nenhuma linha indentada virou gate na evidência |
| OS46-03 | contrato **novo** na fonte e a FASE B segue verde |
| OS46-04 | o log do contrato novo removido => vermelho |
| OS46-05 | a fixture-isca de quatro logs => vermelho |
| OS46-06 | `contratosui` marcado NÃO EXECUTADO => agregador vermelho |

O que impede T27 de ser **pulado** ou de ter a expectativa **trivializada** não
mora na matriz — mora fora dela, no contrato de `contratosui` na fonte única.
Oito `exige` novos nomeiam, como bloco normativo, tanto a linha
`esperar 0 "T27 CONTROLE` quanto a derivação `for k in $(gates_com_contrato ...)`
e o `esperar`/`nok` de cada caso da OS 46 — de modo que apagar um caso para
"consertar" uma sabotagem também reprova, e rebaixar um `esperar 0` para
`esperar 1` idem. `PISOS_EXIGE` ganhou `contratosui:19` pelo mesmo motivo que
`torneiobase:14` existe: um contrato que perde `exige` um a um continua
formalmente completo.

Pisos realinhados na régua externa: `provas` 65 → 72, `casos` 74 → 80.

## Até onde isto alcança

`PISOS_PROVAS`, `PISOS_CASOS`, `PISOS_EXIGE` e `CONTRATOS_MINIMOS` moram dentro
de `verificar_contrato_suites.sh`, e quem os verifica é a matriz que eles
guardam. Baixar um piso ali continua sendo uma edição que só a revisão humana
pega — é o mesmo limite que a OS 42-C2 registrou, e a OS 46 não o fecha.
