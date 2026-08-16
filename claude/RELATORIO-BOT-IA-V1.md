# RELATÓRIO — INTELIGÊNCIA ESTRATÉGICA DO BOT V1

## 1. Base e branch

| item | valor |
|---|---|
| Base exigida pela OS | `88d12acae2ec34502eaaf3052e4a9faf1c9079a1` — *C10 (rev.3): relatório do fechamento + genealogia* |
| Branch de entrega | `claude/bot-ia-estrategica-v1` |
| Merge em `main` | **não houve** |
| Deploy / Railway / Play | **não houve** |

**Observação sobre a base, que precisa ficar registrada.** A OS manda partir de
`auditoria/regras-bmv` **no SHA `88d12ac`**. Esses dois não coincidem neste
repositório: `auditoria/regras-bmv` aponta para `4e35594` no local e para
`14b8d03` no remoto, e o `88d12ac` vive na linhagem `c10-parte2-rev3`. Como a OS
proíbe explicitamente iniciar sobre `14b8d03`, o **SHA prevaleceu** sobre o nome
da branch. A árvore de trabalho foi resetada para `88d12ac` antes de qualquer
alteração.

## 2. Princípio arquitetural — o que a camada estratégica pode e não pode

O bot **não decide legalidade**. A camada nova observa, gera alternativas,
pontua, escolhe UMA intenção e devolve as ações para a autoridade canônica
validar e aplicar — pelas mesmas entradas que o humano usa.

Três provas disso, e não apenas a afirmação:

- **Por construção.** Todo plano devolvido pelo gerador já passou por
  `aplicarLegal`. O gerador enumera e poda; ele nunca conclui que algo é legal.
- **Por teste.** `BOTIA-14(a)` roda a decisão em oito mesas e submete cada ação
  à mesma autoridade, exigindo `legal == true`.
- **Por contraprova.** `BOTIA-14(b)` forja uma intenção ilegal e a submete pela
  mesma porta do bot: é recusada, `falhasTecnicas` fica em zero (recusa de
  REGRA, não falha técnica) e o snapshot do `Jogo` fica idêntico.

O robô legado continua intacto sob `MotorConfig.legadoRollback()`. Isso é
deliberado: o rollback existe para preservar o comportamento antigo, e dar a ele
uma camada nova esvaziaria o rollback.

## 3. Mapa dos módulos

### Criados — `app/lib/bot/`

| arquivo | papel na OS | responsabilidade |
|---|---|---|
| `visao_informacao.dart` | InformationView (§7) | máscara estrutural do `EstadoJogo`; mãos alheias, monte, mortos e lixo enterrado **não têm campo** |
| `analise_mao.dart` | HandAnalyzer | ligações por carta (dano de descarte) e potencial de canastra por corrida |
| `leitura_meld.dart` | apoio | perguntas sobre jogos públicos; "estende?" delega ao validador canônico |
| `modelo_parceiro.dart` | PartnerModel (§1) | o que os jogos da dupla pedem, carga do parceiro, prudência de batida |
| `risco_descarte.dart` | OpponentModel / DiscardRisk (§2) | risco do descarte por sinal público |
| `pesos.dart` | §8 | pesos e restrições centralizados e versionados |
| `razoes.dart` | §8 | vocabulário fechado de reasonCodes |
| `avaliador_heuristico.dart` | HeuristicEvaluator (§8) | score + decomposição em features |
| `gerador_candidatos.dart` | CandidateGenerator (§5) | planos completos de turno, já validados |
| `executor_bot.dart` | BotExecutor | escolhe a intenção e devolve para a autoridade |

### Alterados

| arquivo | mudança |
|---|---|
| `app/lib/mesa.dart` | `botJoga` divide-se em `_botJogaEstrategico` (canônico) e `_botJogaLegado` (rollback); removidos `_botCompra`, `_botAbrir` e `_botEscolheCompraLixo`; novos campos observáveis `configuracaoBot`, `ultimaDecisaoBot`, `impassesEstrategicos` |
| `app/test/teste_motor.dart` | +29 testes (2 grupos novos) e os fixtures determinísticos |

Nada em `rules/` foi tocado. RuleSpec, pontuação, morto, batida, vulnerabilidade
e compra atômica do lixo permanecem exatamente como o C10 os deixou.

## 4. Heurísticas, features e pesos iniciais

Versão dos pesos: **`bmv-bot-heuristico-v1`**. Todos em `app/lib/bot/pesos.dart`.

### 4.1 Objetivos de rodada

| feature | peso | sinal |
|---|---|---|
| `abertura` | 30 | + |
| `aberturaVulneravel` | 140 | + |
| `morto` | 220 | + |
| `batida` | 160 | + |
| `batidaPrematura` | 300 | − |

`batidaPrematura` é **maior** que `batida` de propósito: se fosse menor, a
prudência do §6 seria decorativa e nunca mudaria uma decisão.

### 4.2 Mesa e mão — a mesma moeda (pontos)

| feature | peso | sinal |
|---|---|---|
| `valorMesa` | 0,40 | + |
| `potencialMao` | 0,28 | + |
| `ligacoesMao` | 0,35 | + |
| `deadwood` | 0,35 | − |
| `maoResidual` | 0,10 | − |
| `excedenteMao` | 4,0 × excesso² acima de 15 cartas (limiar +4 na compra) | − |
| `exposicaoSemGanho` | 0,4 por carta de jogo novo | − |
| `turnoSemSaida` | 80 | − |

`valorMesa` é **nível**, não delta: cartas + bônus de canastra (pela pontuação
canônica) + potencial ainda não realizado. `potencialMao` usa o **mesmo**
potencial, descontado. É esse desconto que faz baixar a corrida inteira ser bom
negócio e desmontá-la ser péssimo.

O potencial por comprimento de corrida — 3→10, 4→30, 5→70, 6→130, **7+→0** —
mede potencial *não realizado*. Ele zera em 7 porque ali virou bônus de verdade.

### 4.3 Curinga (§3)

| feature | peso | sinal |
|---|---|---|
| `custoCuringa` | 60 por curinga comprometido | − |
| `custoCuringaGratuito` | 110 por curinga que a combinação dispensaria | − |

O custo **não** é perdoado por "ganho decisivo". Perdoá-lo fazia o bot queimar o
Joker em qualquer abertura que cumprisse o mínimo, mesmo existindo caminho
natural com os mesmos pontos. O ganho decisivo já vale 140/160/220 no score; se
compensa, compensa pagando o curinga.

### 4.4 Descarte (§2)

| feature | peso | sinal |
|---|---|---|
| `danoDescarte` | 2,2 por ponto de dano estrutural | − |
| `riscoDescarte` | 6,0 por ponto de risco | − |
| `descarteUtilAoParceiro` | 34 | − |
| `descarteAdjacenteAoParceiro` | 12 | − |

### 4.5 Compra

| feature | peso |
|---|---|
| `compraMonteBase` | 6 |
| `compraLixoVolume` | 3,0 por carta enterrada |
| `compraLixoLastro` | 0,15 × 8 pts esperados por carta enterrada |
| `topoUtilAoJogo` | 8 |

### 4.6 Restrições DURAS (filtros, não pesos)

`proibeDescartarCuringa`, `protegeCanastraLimpa`, `preservaCuringa`,
`avaliaDanoEstrutural`, `preservaCartaDoParceiro`, `evitaAlimentarAdversario`,
`planoIncluiDescarte`, `prudenciaBatida` — todas ligadas por padrão. Desligar
qualquer uma **não** libera jogada ilegal: apenas devolve ao bot uma alternativa
que a autoridade já aceitava e que a política desta OS proíbe.

### 4.7 Limites de busca — nunca silenciosos

`orcamentoBusca` 6000 nós · `maxBaixadasAvaliadas` 64 · `maxDescartesPorBaixada`
10. Se qualquer um morder, a decisão carrega `BUSCA_TRUNCADA` no rastro.

## 5. ReasonCodes

`COMPRA_LIXO_ESTRUTURA` · `COMPRA_LIXO_VOLUME` · `COMPRA_MONTE` ·
`COMPRA_MONTE_SEM_USO_DO_TOPO` · `BAIXA_ABERTURA_MINIMA` · `BAIXA_ABERTURA` ·
`BAIXA_GANHO_LIQUIDO` · `BAIXA_CANASTRA` · `BAIXA_MORTO` · `BAIXA_BATIDA` ·
`PRESERVA_ESTRUTURA` · `ADIA_POR_PARCEIRO` · `REAVALIA_APOS_MORTO` ·
`DESCARTE_MENOR_DANO` · `DESCARTE_SEGURO` · `DESCARTE_PRESERVA_PARCEIRO` ·
`IMPASSE_DESCARTE_SO_CURINGA` · `BUSCA_TRUNCADA` · `SEM_PLANO_LEGAL`.

## 6. Testes

Suíte executada no overlay do CI (Flutter 3.41.4 / Dart 3.11.1), com o mesmo
comando do portão: `flutter test test/teste_motor.dart`.

```
00:08 +412: All tests passed!
```

| grupo | testes |
|---|---|
| regressão integral do C10 | 383 |
| `OS BOT-IA V1 — inteligência estratégica` | 20 |
| `OS BOT-IA V1 — não-vacuidade` | 9 |
| **total** | **412** |

### 6.1 Cobertura dos 17 cenários obrigatórios

| # da OS | teste | como é provado |
|---|---|---|
| 1 não descarta 2 | BOTIA-01 | decisão e turno completo; o 2 fica na mão |
| 2 não descarta Joker | BOTIA-02 | idem |
| 3 menor dano estrutural | BOTIA-03 | descarta a peça solta, `danoDescarte == 0` |
| 4 preserva carta do parceiro | BOTIA-04 | quatro cartas equivalentes; só a adjacência decide |
| 5 evita alimentar adversário | BOTIA-05 | + `DESCARTE_SEGURO` no rastro |
| 6 não suja canastra limpa | BOTIA-06 | a alternativa nem chega a ser gerada |
| 7 não gasta curinga à toa | BOTIA-07 | dois caminhos de abertura; vence o natural |
| 8 usa curinga quando decisivo | BOTIA-08 | curinga zera a mão e pega o morto |
| 9 não baixa todo meld legal | BOTIA-09 | a baixada existe e é legal; o bot recusa |
| 10 estrutura x descarte ruim | BOTIA-10 | plano completo com o descarte simulado |
| 11 reavalia após o morto | BOTIA-11 | segunda decisão no mesmo turno |
| 12 não bate prematuramente | BOTIA-12 | bater é legal e mesmo assim não bate |
| 13 abertura vulnerável | BOTIA-13 | escolhe a opção que não toca a corrida de seis |
| 14 nada passa fora do motor | BOTIA-14 | sweep + intenção forjada recusada |
| 15 informação oculta | BOTIA-15 | estrutural + comportamental |
| 16 determinismo | BOTIA-16 | mesma assinatura, mesmo JSON, mesmo score |
| 17 regressão do C10 | os 383 | verdes |

Extras que os cenários pediram: **BOTIA-17** (rastro auditável), **BOTIA-18**
(impasse registrado), **BOTIA-19** (fail-closed do C10 preservado no caminho
estratégico), **BOTIA-20** (60 turnos canônicos com invariante de progresso).

### 6.2 Relatório de não-vacuidade

Cada regra crítica desligada uma por vez; o cenário correspondente muda.

| teste | regra desligada | o que passa a acontecer |
|---|---|---|
| NV-01/02 | `proibeDescartarCuringa` | planos que mandam 2/Joker ao lixo voltam a existir |
| NV-03 | `avaliaDanoEstrutural` | a feature `danoDescarte` some da decisão |
| NV-04 | `preservaCartaDoParceiro` | alguma semente larga a carta do parceiro |
| NV-05 | `evitaAlimentarAdversario` | alguma semente entrega a extensão |
| NV-06 | `protegeCanastraLimpa` | sujar a limpa volta ao conjunto de alternativas |
| NV-07 | `preservaCuringa` | o bot queima o Joker para abrir |
| NV-08 | `potencialMao` + `ligacoesMao` = 0 | volta a baixar tudo que é legal |
| NV-09 | `planoIncluiDescarte` | baixa e entrega o descarte perigoso |
| NV-10 | `prudenciaBatida` | bate e deixa o parceiro com 11 cartas |

Onde a regra é **filtro** (NV-01/02, NV-06), a prova é sobre o conjunto de
alternativas geradas — é lá que o filtro age. Onde duas cartas empatam por
construção (NV-04, NV-05), a prova varre 21 sementes: com a regra, **nenhuma**
escolhe a carta errada; sem ela, alguma escolhe.

## 7. Analyzer

`flutter analyze` no overlay, comparado com o commit base ignorando números de
linha: **115 issues na base, 115 na entrega, diff vazio**. Nenhum aviso novo. Os
10 arquivos de `app/lib/bot/` analisam limpos (`No issues found`).

## 8. Comparação objetiva com o bot atual

### 8.1 Cenários determinísticos, mesma mesa, baralho completo

| # | cenário | bot ATUAL (legado) | bot ESTRATÉGICO |
|---|---|---|---|
| C1 | curinga órfão na mão | **descarta o JOKER** | descarta 6/espadas; baixa 7 cartas |
| C2 | 5h,6h,8h,K/paus | descarta 5/copas (quebra o par) | descarta K/paus |
| C3 | dupla abriu 4-5-6 copas | **descarta o 8/copas** (a extensão natural) | descarta K/espadas |
| C4 | eles têm 10-J-Q copas | evita o Kh | evita o Kh |
| C5 | canastra limpa na mesa | não suja | não suja |
| C6 | corrida promissora de 5 | **baixa as 5** | preserva |
| C7 | vulnerável 75 | **não abre** | abre com 3 jogos, 10 cartas, e pega o morto |
| C8 | batida com parceiro de 11 cartas | **bate** | descarta e espera |
| C9 | curinga decisivo para o morto | pega o morto com 6 cartas | pega com 4 |

Os quatro casos em **negrito** são o núcleo do que a OS chamou de sabotagem: o
robô atual descarta curinga (C1), entrega a carta que o parceiro precisa (C3),
desmonta a corrida promissora (C6) e bate deixando o parceiro com a mão cheia
(C8). Em C7 ele simplesmente não abre sob vulnerabilidade — o `_botAbrir` antigo
tentava do conjunto maior para o menor e parava no primeiro aceito, e neste
arranjo nenhum conjunto isolado passava.

Em C4 e C5 os dois empatam: o robô legado já tinha `ehPerigosa` e a "regra de
ouro" da canastra limpa de 7+. A camada nova generaliza — a proteção passa a
valer para qualquer jogo limpo, não só o de 7 cartas, e o risco passa a
considerar adjacência e ameaça visível.

### 8.2 Partidas completas — 10 rodadas por modalidade, sementes 1..10

| modalidade | bot | pontos (10 rodadas) | canastras | curinga ao lixo | impasses |
|---|---|---|---|---|---|
| ABERTO | ATUAL | 13 950 | 64 | 2 | — |
| ABERTO | ESTRATÉGICO | 8 155 | 27 | **0** | 0 |
| FECHADO | ATUAL | 13 770 | 59 | 1 | — |
| FECHADO | ESTRATÉGICO | 5 670 | 12 | 1 | 1 |

**Leitura honesta destes números.** O bot estratégico marca menos pontos que o
robô atual. Ele também nunca manda curinga ao lixo por escolha (o único caso em
Fechado é o impasse documentado do §7 abaixo), não desmonta corridas e não bate
por cima do parceiro. A OS diz que a aprovação não se dá por "ganhar mais" — mas
também não se dá por perder, e este é o ponto aberto que levo adiante na §9.

### 8.3 Custo por turno

Medido em 3 partidas × 60 turnos, mão de até 22 cartas:

```
n=179  média=57ms  p50=12ms  p90=199ms  máx=591ms
```

O laço de robôs da mesa espera 650 ms entre turnos, então o custo cabe. As
primeiras calibrações chegaram a **3,6 s** de pico; o que resolveu foi memoizar
os modelos por carta, limitar a largura do descarte e — principalmente — impedir
que a mão inchasse a 28 cartas.

## 9. Pontos que precisam de decisão da Sônia

### 9.1 Força de jogo: o bot é conservador demais para os pesos atuais

Medido: 8 155 pontos contra 13 950 em ABERTO, 27 canastras contra 64. O robô
atual pontua mais porque despeja a mão inteira na mesa; o estratégico segura
mais e fecha menos canastras.

Isto **não** é um defeito de arquitetura — é calibração, e está inteiramente em
`pesos.dart`, versionado. Três calibrações foram medidas ao longo da entrega:

| calibração | ABERTO (pontos / canastras) |
|---|---|
| prêmio de corrida em degrau, estrutura só na mão | −200 / 7 |
| prêmio por carta, estrutura na mão e na mesa | 1 235 / 5 |
| **moeda única, potencial por corrida (entregue)** | **8 155 / 27** |

A direção que ainda rende é a mesma: reduzir o valor de segurar (`ligacoesMao`
já caiu de 0,60 para 0,35 com ganho medido de 3 955 → 8 155; a 0,20 piorou para
6 290, então o ótimo está entre 0,35 e 0,50). **Recomendo tratar isso como v1.1
de calibração**, com o comparativo da §8.2 como métrica de aceite, em vez de
mexer nos pesos sem medição.

### 9.2 Impasse: mão só de curinga

Quando **toda** carta legalmente descartável é um 2 ou um Joker, a política do
§2 e a necessidade de encerrar o turno se contradizem. A OS proíbe exceção
silenciosa, então o tratamento é: a decisão sai marcada com
`IMPASSE_DESCARTE_SO_CURINGA`, o diagnóstico completo fica em
`Jogo.impassesEstrategicos`, e a carta escolhida é a de menor perda (um "2"
antes de um Joker) — aplicada pela autoridade como qualquer outra.

Frequência medida: **0 em 10 rodadas no ABERTO, 1 em 10 no FECHADO**. Coberto
por `BOTIA-18`. **Decisão pendente:** manter esta saída, ou preferir que o robô
pare o turno e a mesa pause.

### 9.3 Beco sem saída do motor (não é do bot)

Existe estado em que a autoridade **aceita** uma baixada que deixa exatamente 1
carta na mão sem morto a pegar e sem canastra para bater — e depois **nenhum**
descarte é legal. O turno termina sem passar a vez, e o guarda de progresso do
`_rodarBots` pausa a partida.

Isso já era assim no C10: o fixture `C10-BOT-03` exercita exatamente esse estado
e o robô antigo o produzia. O bot novo trata o caso como plano marcado
(`turnoIncompleto`) e cobra 80 pontos por ele, de modo que só vence quando é a
única forma de a dupla abrir sob o mínimo — que é justamente o caso do
`C10-BOT-03`.

**A correção de verdade é no motor** (recusar a baixada que torna o descarte
seguinte impossível) e está **fora do escopo** desta OS, que proíbe tocar em
morto/batida e na autoridade canônica. Fica registrado para decisão.

### 9.4 Descartes públicos do parceiro

A §1 pede que o bot considere "descartes públicos feitos pelo parceiro". A
projeção canônica **não carrega autoria de descarte** — o `EstadoJogo` tem a
pilha do lixo, não quem pôs cada carta lá. Deduzir autoria pela ordem da pilha
seria fabricar informação, o que a §7 proíbe.

O sinal foi implementado como entrada opcional
(`VisaoInformacao.descartesPublicos`) e o `ModeloParceiro` já o consome quando
existe; hoje ele chega vazio. Ligá-lo exige um log de autoria no envelope de
runtime — mudança que toca a projeção e o round-trip do C10, e portanto não
cabia nesta OS.

## 10. Fora do escopo — confirmação

Não foram tocados: RuleSpec, regras oficiais, valores de pontuação, morto,
batida, vulnerabilidade, compra atômica do lixo, autoridade canônica, política
competitiva, servidor/Railway, Play Billing, UI, distribuição de cartas. Nenhum
RNG foi usado para favorecer ou prejudicar o bot — a semente de
`ConfiguracaoBot` entra **apenas** no desempate determinístico entre
alternativas de score idêntico.

Também ficaram de fora, como a OS determina: LLM em runtime, acesso a informação
oculta, ISMCTS, reinforcement learning, CFR e treino online.

## 11. Estado da entrega

- Árvore limpa.
- Sem merge, sem deploy.
- Commits separados por responsabilidade (6).
