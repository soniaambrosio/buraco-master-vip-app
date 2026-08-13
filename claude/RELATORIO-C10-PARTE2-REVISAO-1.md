# Relatório — C10 Parte 2, revisão 1 (correções cirúrgicas)

**Base:** `1dfa572241ff6d9310f53363dc95cbf9304552a8` (entrega reprovada).
**Escopo:** só os seis itens da revisão. RuleSpec, servidor/Railway, online e
arquitetura canônica não foram tocados. Sem merge, deploy ou publicação.
**C10 NÃO está encerrada.**

Local: **371 `test()` verdes**; `flutter analyze` com **0 erros** e diff de
avisos **idêntico** ao de `14b8d03`.

---

## Item 1 — penalidade do morto convertido

**Era:** a conversão §8.1 (morto vira monte) suprimia o -100 da dupla que não
pegou morto — no canônico (`!e.mortoConvertido`) e no legado
(`_mortosConvertidos == 0`).

**Ficou:** `penalidadeMorto = !mortoPego && algumPegouMorto`. Sem cláusula de
conversão em lugar nenhum. `EntradaRodada.mortoConvertido` foi **removido** —
manter um campo ignorado seria um convite a religá-lo. A conversão continua
registrada (`_mortosConvertidos`, envelope, `C10-CONVERSAO-01` intactos).

**Regressão nova:** `C10-SCORE-03` pelo caminho REAL de produção — conversão
registrada + dupla sem morto ⇒ `penalidadeMorto = -100`, com a contraparte em 0.

**Três asserções existentes afirmavam a regra errada** e foram viradas (mesmos
cenários, expectativa corrigida; nenhuma afrouxada): `PONT-09` e `FLUX-21`
(legado) e as duas unitárias canônicas em C3 e C9-C2a-fix. `PONT-09` passou a
provar também que a conversão continua **registrada**, só não perdoa.

> **Decisão que precisa do seu aval.** A OS listou "rollback legado" entre o que
> não se altera, e o item 1 mandou remover "qualquer equivalente". Os dois se
> cruzam em `_pontuarDupla`. Resolvi pelo lado da **regra** — sob rollback a
> partida aplicaria uma regra que a direção acabou de rejeitar, e as duas
> contagens divergiriam justo no ponto corrigido. Para você poder discordar sem
> desfazer o resto, isso está num **commit isolado** (`72345e6`), revertível
> sozinho.

## Item 2 — fail-closed do bot

**Era:** o robô seguia jogando depois de falha técnica — falhava no lixo e
comprava o monte, falhava ao baixar e tentava o próximo grupo, falhava ao
descartar e varria a mão inteira. Cada tentativa era nova transação sobre um
motor recém-quebrado.

**Ficou:** `Jogo.falhasTecnicas` (contador monotônico) + `_botFalhouTecnicamente`
consultado depois de **cada** tentativa canônica: compra, abertura, baixada,
extensão, fechamento e descarte. Na primeira falha o turno encerra sem segunda
transação; `ultimaFalhaTecnica` e o estado ficam preservados.

`ultimaFalhaTecnica` sozinha não servia: não distingue "falhou agora" de "falhou
há três jogadas". O contador é o que torna a verificação exata.

Recusa de **regra** segue contornável pelo agente — é decisão estratégica, não
falha de motor. A distinção está explícita no código.

**Testes:** `BOT-FC-01` (compra não vira compra do monte), `BOT-FC-02` (não tenta
outro grupo), `BOT-FC-03` (não tenta outra extensão), `BOT-FC-04` (não varre os
outros descartes). Cada um prova ausência de segunda transação com estado
idêntico ao de antes.

**Não-vacuidade verificada:** removendo a guarda de `_botCompra`, `BOT-FC-01`
falha. A guarda externa do `botJoga` não bastaria — `comprarMonte` já teria
rodado antes do retorno.

## Item 3 — consumidor REAL de abertura múltipla

**Era:** `baixarAtomico` existia e ninguém consumia. A abertura múltipla era
provada só por chamada direta ao motor.

**Ficou:** o gesto aprovado **não mudou** — seleciona as cartas, toca no feltro.
Mudou a interpretação: `derivarParticoesAbertura` enumera todas as maneiras
legais de repartir **exatamente** a seleção em jogos, e `_baixar` aplica o mesmo
contrato do lixo — **0 recusa / 1 executa / 2+ seletor mínimo**, sem autoescolha.
Seleção de um meld só continua dando uma partição, então o gesto de sempre se
comporta igual.

A travessia usa a mesma poda estrutural do derivador do lixo, ancorada na carta
livre de menor índice — isso elimina permutações da mesma partição **por
construção**, em vez de deduplicar depois. `avaliarBaixar` continua sendo o
verificador final (mínimo de vulnerabilidade, trava de esvaziar, tudo).

**Bot:** `_botAbrir` faz abertura composta quando a dupla está vulnerável e ainda
não abriu. Antes, com o mínimo dependendo da soma, cada baixada isolada era
recusada e o robô simplesmente **nunca abria**. A heurística propõe os grupos; a
transação é uma só e o mínimo continua sendo decidido pelo canônico.

**Testes:** `ABERTURA-02` (um meld ⇒ uma partição — o gesto de sempre não mudou),
`ABERTURA-03` (humano abre com três jogos numa seleção; toda carta usada, nenhuma
a mais), `ABERTURA-04` (0 partições ⇒ recusa intacta), `ABERTURA-05` (seis em
sequência ⇒ um jogo de 6 **ou** dois de 3; determinístico, sem duplicatas),
`BOT-03` (robô abre com o mínimo atingido na soma).

## Item 4 — responsividade da derivação

**A alegação anterior estava errada e foi removida.** `Future(() => ...)` só adia
a execução para outra volta do event loop, no **mesmo isolate**: quando a
travessia roda, roda inteira, e o frame trava igual.

**Ficou:** `motor/derivacao_fora_do_frame.dart` — as duas derivações passam por
`compute`, em outro isolate. `compute` e não `Isolate.run` porque `dart:isolate`
não existe na web e o projeto tem alvo web; na web `compute` executa no mesmo
isolate, e essa degradação está registrada no cabeçalho como o que é.

**Nenhum teto** de cartas, candidatos, melds ou tempo foi introduzido. As
travessias são idênticas; mudou onde a CPU é gasta.

**Segunda derivação eliminada:** com 0 candidatos, o consumidor montava a recusa
chamando `comprarLixo`, que derivava tudo de novo só para redescobrir a lista
vazia. Agora usa `Jogo.erroLixoSemUsoDoTopo`. (No caminho de baixar, a recusa
passa por `baixar`, que faz **uma** transação canônica direta e não regenera
partições.)

**`C10-ISOLATE-01`** prova o que a alegação exige: os payloads atravessam a
fronteira de isolate e voltam com resultado **idêntico** ao da chamada síncrona,
inclusive no caso ambíguo. Sem essa prova, um `EstadoJogo` não-transferível
quebraria a primeira compra Fechado em runtime — era risco real, não formalidade.

## Item 5 — cobertura

Além dos testes citados acima:

- `C10-NO-FALLBACK-03` — falha técnica em `comprarMonte` (nada convertido, nada
  comprado, turno não avança);
- `C10-NO-FALLBACK-04` — falha técnica na compra **atômica** do lixo (lixo não
  recolhido, nada baixado);
- `C10-ABERTURA-01` deixou de ser a única prova de abertura múltipla: continua
  como prova do motor, e `ABERTURA-02/03/04/05` provam o consumidor humano,
  `BOT-03` o consumidor robô.

## Item 6 — documentação

`meld_validator.dart` e `pontuacao_canonica.dart` afirmavam "SEM comportamento de
produção / só a suíte usa isto". Corrigido.

A revisão nomeou esses dois, mas **a mesma afirmação falsa estava em todo o
`rules/`**. Corrigi os onze arquivos que de fato entraram em runtime — deixar dez
arquivos afirmando o oposto da realidade seria o mesmo defeito, só nos que não
foram citados. Os dois que **não** entraram ficaram explícitos em vez de vagos:
`rules_engine.dart` (interface, `motor/` não importa) e `sombra.dart`
(diagnóstico; `producao()` nasce com sombra OFF).

Comentários sobre a conversão revisados em `mesa.dart` e `envelope_runtime.dart`
— diziam que a conversão isentava o -100. A referência a "§8.3" saiu desses
pontos, já que o efeito que ela nomeava deixou de existir.

---

## Commits (revertíveis isoladamente)

| SHA | O quê |
|---|---|
| `4ace3fb` | -100 da conversão: correção no canônico |
| `72345e6` | -100 da conversão: mesma correção no legado (**isolado de propósito**) |
| `ce48f43` | fail-closed do robô + abertura composta do robô |
| `4b10333` | consumidor humano da abertura múltipla |
| `37838b1` | derivação fora do isolate de UI |
| `df37c44` | cabeçalhos de runtime + comentários da conversão |

## Não incorporado, como instruído

A OS ampla de Inteligência Estratégica do Bot **não** entrou. `_botAbrir` e
`_botEscolheCompraLixo` são o mínimo para o robô conseguir abrir e comprar sob a
autoridade — não são política de jogo.

## O que continua pendente da sua decisão

O ponto do relatório anterior sobre a abertura múltipla **foi resolvido**: o
consumidor humano existe, pelo gesto aprovado, sem redesign.

Segue em aberto apenas o **teste de widget da mesa**, inviável no portão atual
porque o CI declara os assets no pubspec **depois** do gate de qualidade —
mudança de workflow, não de código, e não fiz por conta própria.
