# RELATÓRIO — ORÇAMENTO DETERMINÍSTICO DE BUSCA E FALLBACK LEGAL DO BOT STBL V1

**VEREDITO: PASS — BUSCA DO BOT STBL LIMITADA DE FORMA DETERMINÍSTICA COM FALLBACK LEGAL E SEM REGRESSÃO**

---

## 1. Git

| item | valor |
| ---- | ----- |
| branch | `claude/bot-orcamento-busca-stbl-v1` |
| base | `6b028be8ad19fbbcdf3d5511d0df0fafabb07a6b` (`claude/bot-calibracao-descartes-publicos-v1`) |
| HEAD inicial | `6b028be…` (a base; worktree resetado antes de qualquer edição) |
| merges | **0** |
| PR | **nenhum** |
| deploy | **nenhum** |

Ancestralidade conferida sobre o SHA completo de 40 caracteres:

```
89fca38  Inteligência do Bot V1              -> ancestral: SIM
f41eea0  Encerramento de turno V1            -> ancestral: SIM
07eb4ff  Proveniência de descartes V1        -> ancestral: SIM
6b028be8ad19fbbcdf3d5511d0df0fafabb07a6b   BASE (local == remoto)
```

A branch alvo não existia (nem local, nem remota), então o nome preferencial da
OS foi usado sem sufixo. Árvore limpa antes da primeira edição.

---

## 2. Gate Zero

| # | verificação | resultado |
| - | ----------- | --------- |
| 1 | baseline de testes | **462** verdes |
| 2 | baseline do analyzer | **118** diagnósticos, nenhum novo |
| 3 | peso da memória pública | `memoriaDescarteParceiro: 4` em `pesos.dart:414` |
| 4 | consumidor único dos descartes públicos | `grep` por `parceiroDescartou`/`descartesPublicos` fora de `modelo_parceiro`/`visao_informacao`: **uma** ocorrência, em `avaliador_heuristico.dart:199` |
| 5 | semente patológica reproduzível | STBL/29, sim |
| 6 | controle V1 × V1 também explode | sim — registrado na OS 3: o controle da mesma semente passou de 2h25 sem terminar |
| 7 | jogadas ilegais na base | **0** |
| 8 | fase que explode | **derivação de compra do lixo** (ver §3) |
| 9 | trabalho medido em nós/combinações | sim (ver §3 e §4) |
| 10 | árvore limpa | sim |

---

## 3. O ponto exato da explosão

A suspeita natural era o gerador de planos do bot. **Não era ele.** A medição
decompôs o turno mais caro da semente patológica (STBL/29, mão de 19 cartas):

```
derivarCandidatosCompraLixo  = 16.933 ms   101.404 transações validadas
decidirCompra                =  2.936 ms   (pontuando os 101.404 candidatos)
planosDeJogo                 =    227 ms   6.000 nós, 110 planos, truncado
decidirJogo (total)          =    227 ms
```

O gerador de planos **já tinha** teto (`orcamentoBusca = 6000`) e o respeitava.
Quem não tinha teto nenhum era `derivarCandidatosCompraLixoFechado`, na
autoridade — e no Fechado/STBL ela roda **a cada turno**, porque a modalidade
exige justificar o uso do topo. Cada "transação" ali roda `avaliarComprarLixo`
mais `acaoEhLegal`, isto é, **dois clones profundos do estado inteiro**.

O contador que existia (`_nos`, campo privado do `GeradorPlanos`) era, na
prática, um **contador paralelo**: media uma fase e ignorava a que dominava o
custo.

### Distribuição de trabalho no corpus normal

610 decisões (5 sementes × 3 modalidades, 45 turnos), transações por decisão:

| modalidade | p50 | p90 | p95 | p99 | máximo |
| ---------- | --- | --- | --- | --- | ------ |
| ABERTO | 0 | 0 | 0 | 0 | 0 |
| FECHADO | 0 | 8 | 22 | 196 | 738 |
| STBL | 0 | 31 | **784** | **3.464** | **28.110** |

E a decisão patológica: **101.404**. O ABERTO é zero porque lá a compra do lixo
é livre e não exige derivar uso do topo.

---

## 4. Orçamento escolhido, e por quê

```dart
tetoTransacoesCompraLixo = 2000
tetoPlanosAvaliados      = 4000
orcamentoBusca (nós)     = 6000   // já existia, inalterado
fusivelBuscaMs           = 5000   // secundário
```

**`2000` transações** preserva integralmente o p95 medido do STBL (784) e corta
a explosão. O p99 (3.464) passa a ser cortado — foi a troca escolhida, e ela é
consciente: o teto de **2 s por decisão** da §10 não cabia junto com preservar o
p99. Medido no turno mais caro da semente patológica:

| teto | pior turno |
| ---- | ---------- |
| 1000 | 1.639 ms |
| **2000** | **1.816 ms** |
| 4000 | 2.327 ms |
| 6000 | 1.750–2.236 ms (ruidoso) |

**`4000` planos avaliados** nunca é o limite que aperta: a largura já limita a
64 baixadas × 10 descartes = 640 planos na fase de jogo. É o backstop exigido
pela §5, não o corte operante.

**Fusível de 5.000 ms**: uma ordem de grandeza acima do pior caso medido, para
que ele nunca governe decisão normal — e o teste `ORC-12` exige que, em estado
normal, o motivo do encerramento seja `buscaCompleta`, nunca `fusivelTemporal`.

**O peso 4 da memória pública não foi tocado** (`ORC-14` verifica).

---

## 5. Autoridade única do contador

`OrcamentoBuscaBot` (`app/lib/bot/orcamento_busca.dart`) controla:

* nós expandidos, transações de compra do lixo, planos completos avaliados;
* motivo do encerramento (`buscaCompleta`, `orcamentoDeterministico`,
  `fusivelTemporal`) e a **fase** em que o limite bateu;
* consumido e restante; e se houve fallback.

Garantias por construção: nasce por decisão (quem cria é `ExecutorBot` ou o
driver em `mesa.dart`), é passado explicitamente pelas camadas recursivas,
**não tem `reset`**, e o esgotamento é absorvente dentro de cada dimensão.

O `GeradorPlanos` **deixou de ter contador próprio**: o número que ele reporta é
o do orçamento (`ORC-03` verifica a igualdade).

### Como o motor recebe um teto sem conhecer o bot

`DiagnosticoLixo` — que já existia na autoridade como instrumentação — ganhou um
`tetoTransacoes` **opcional**. `null` mantém o comportamento histórico byte a
byte. O bot passa um teto; o **jogador não passa nenhum**, e por isso
`comprarLixo` continua recebendo TODAS as formas legais de usar o topo, que é o
que a escolha manual exige (`ORC-09` compara as duas listas item a item).

O teto **não é regra**: não torna legal o que era ilegal nem o contrário. Cada
candidato devolvido continua tendo passado por `avaliarComprarLixo` **e** por
`acaoEhLegal`, um a um (`ORC-08`).

---

## 6. Ordenação determinística

Nada foi trocado: a ordem que já existia é estável e não depende de identidade
de objeto, hash de objeto nem relógio.

* planos: ordenados por `PlanoTurno.assinatura` (string semântica);
* baixadas: pré-score explícito (esvaziar a mão → pontos naturais → cartas →
  assinatura);
* candidatos de compra do lixo: ordenados por `_sigCompra` no fim da derivação;
  quando o teto corta, o prefixo é o da **ordem de enumeração**, que é fixa
  (laços sobre listas construídas deterministicamente);
* desempate entre planos: `_hash(assinatura, semente)` — sem relógio.

O fallback ordena por **classe de ação** e depois pela assinatura JSON da ação
(`_sigAcao`). A mutação 11 troca isso por `hashCode` e é detectada.

Uma correção de custo, sem efeito na ordem: `pontosDe` reconstruía o mapa da mão
**a cada comparação** do sort de baixadas. O mapa passou a ser construído uma
vez — mesmo resultado, sem o fator |mão| em cima do `n log n`.

---

## 7. Fallback legal

Acionado **só** quando a busca terminou sem nenhum plano completo avaliado.
Não reimplementa regra: pergunta `gerarAcoesLegais` à autoridade — a mesma que
valida a jogada do humano — e escolhe por uma chave estável.

Ordem de preferência: descarte (conclui o turno) → morto → batida → compra do
lixo → compra do monte; e, dentro de cada classe, a assinatura da ação. O
curinga continua protegido também aqui (`ORC-07`), porque o fallback seria a
porta dos fundos por onde o Joker iria ao lixo.

Emite `Razao.fallbackOrcamento`, um código de primeira classe: quem lê o rastro
precisa saber que a decisão foi **aceita**, não **preferida**.

---

## 8. Fusível temporal

Existe, ligado por padrão em 5.000 ms, e é explicitamente secundário:

* não desempata e não reordena;
* só é consultado a cada 256 unidades de trabalho, entre unidades completas —
  nunca no meio de uma mutação;
* produz o mesmo fallback determinístico;
* a telemetria distingue os três motivos (`orcamentoDeterministico`,
  `fusivelTemporal`, `buscaCompleta`), como a §9 exige.

---

## 9. Desempenho

### Por DECISÃO — que é o que a §10 exige

A exigência é sobre a decisão, e o tempo de um **turno** não responde isso: um
turno pode conter várias decisões (o laço de jogo reavalia do zero quando a mão
troca pelo morto). O benchmark mede `decidirCompra`/`decidirJogo` sobre **o
mesmo estado**, com a base e com a candidata.

603 decisões (5 sementes × 3 modalidades, 45 turnos):

| | p50 | p95 | p99 | **máximo** |
| - | --- | --- | --- | ---------- |
| base (`6b028be`) | 127 µs | 4.597 µs | 232.329 µs | **7.466.991 µs (7,47 s)** |
| **com orçamento** | **110 µs** | **4.182 µs** | **217.690 µs** | **546.731 µs (0,55 s)** |

* pior decisão: **7,47 s → 0,55 s**, dentro do teto de 2 s;
* mediana **não regrediu** (110 vs 127 µs — a correção do `pontosDe` paga a
  instrumentação);
* nenhuma decisão do corpus passa de 2 s.

### Preservação da escolha (§11)

Das 603 decisões, **602 escolheram exatamente a mesma coisa** que a base. A
única diferença é uma decisão em que o orçamento cortou — e o rastro dela diz
isso (`esgotado: true`, `motivo: orcamentoDeterministico`,
`fase: derivacaoCompraLixo`). Cortadas: 5. Fallbacks: 0.

### A semente patológica

| | antes | depois |
| - | ----- | ------ |
| partida STBL/29 | ~2 h (par espelhado: 3,6 h) | **40 s** |
| tempo por turno | ~75.000 ms | p50 13 ms, p95 1.626 ms, **máx 2.236 ms** |
| terminou | sim, em horas | **sim, em 40 s** |
| fallbacks | — | **0** |

---

## 10. Dois defeitos meus, achados por medição

Os dois foram encontrados porque a medição contradisse a expectativa, e os dois
estão corrigidos e comentados no código.

**Esgotamento global absorvente.** A primeira versão usava um único `_esgotado`.
Numa mão grande a enumeração gasta todos os nós primeiro, o interruptor fechava,
e a expansão e a avaliação **nem começavam**: o gerador devolvia **zero planos**
onde a base devolvia 110. Cortar a enumeração não pode apagar o direito de
transformar em plano completo o que já foi enumerado. O esgotamento passou a ser
por dimensão.

**Orçamento por turno.** A segunda versão criava um orçamento para o turno
inteiro. A compra do STBL esgotava a cota de planos e a fase de jogo chegava sem
poder pontuar nenhum: **19 fallbacks em 185 turnos**, por falta de orçamento e
não por falta de jogada. Passou a ser **por decisão**, como a §5 pede — e os
fallbacks foram a **zero**.

---

## 11. Matriz de 384 partidas completas

```
64 sementes x 3 modalidades x 2 lados espelhados = 384 partidas
bot limitado desta OS  x  bot calibrado da base (6b028be)
```

A matriz **não foi reduzida** e a semente lenta **não foi excluída**. Duração:
~2h18 no shard mais lento, com quatro processos em paralelo.

| modalidade | partidas | vitórias novo–base | pontos novo × base | participação | terminaram |
| ---------- | -------- | ------------------ | ------------------ | ------------ | ---------- |
| ABERTO | 128 | 64–64 | 156.950 × 156.950 | **50,0%** | 128/128 |
| FECHADO | 128 | 64–64 | 173.250 × 173.595 | **50,0%** | 128/128 |
| STBL | 128 | 56–72 | 176.545 × 189.425 | **48,2%** | 128/128 |
| **AGREGADO** | **384** | **184–200** | **506.745 × 519.970** | **49,36%** | **384/384** |

| exigência da §12 | resultado |
| ---------------- | --------- |
| jogadas ilegais | **0** |
| exceções / falhas técnicas | **0** |
| partidas não terminadas | **0** |
| sementes STBL concluídas | **128/128 (100%)** |
| participação agregada entre 48% e 52% | **49,36%** ✔ |
| nenhuma modalidade abaixo de 45% | menor é **48,2%** ✔ |
| lados e sementes espelhados | sim |

O ABERTO fica em 50,0% com pontuação **idêntica** dos dois lados, e isso é
esclarecedor: lá a compra do lixo é livre e a derivação nem é chamada, então o
orçamento não corta nada e o bot novo joga exatamente como a base. O corte
aparece onde deve aparecer — no STBL, que é a modalidade que explodia.

Nenhum peso foi mexido para compensar resultado, como a §12 proíbe.

### O teto de 10 minutos por partida

Seis partidas da matriz passaram de 10 minutos — todas STBL (sementes 3, 29, 37,
55, 61 e 64), a pior com 1h49. **Isso não é o bot entregue.** Na matriz, metade
dos assentos roda de propósito a `ConfiguracaoBot.base`, isto é, a versão **sem
orçamento** — a explosão que esta OS corrige. O número que responde à §10 é o da
configuração entregue nas quatro cadeiras:

| semente (STBL) | partida | p50 do turno | p95 | pior turno | cortes | fallbacks |
| -------------- | ------- | ------------ | --- | ---------- | ------ | --------- |
| 3 | **5,3 s** | 4 ms | 201 ms | 497 ms | 6 | 0 |
| 29 (a patológica) | **9,2 s** | 4 ms | 312 ms | **444 ms** | 23 | 0 |
| 37 | **2,5 s** | 4 ms | 44 ms | 548 ms | 2 | 0 |
| 55 | **10,0 s** | 5 ms | 228 ms | 519 ms | 15 | 0 |
| 61 | **3,0 s** | 4 ms | 42 ms | 394 ms | 2 | 0 |
| 64 | **3,6 s** | 3 ms | 52 ms | 568 ms | 3 | 0 |

As seis partidas mais lentas do corpus terminam em **menos de 10 segundos**
contra um limite de 10 minutos, e nenhum turno passa de 568 ms contra um limite
de 2 s. Zero fallbacks.

---

## 12. Testes, mutações e portões

### Testes

```
base  (6b028be): 462 verdes
final:           479 verdes   (+17 ORC-*)
regressões:        0
```

O portão passou de ~12 s para ~17 s. O grupo novo custa ~25 s quando roda
sozinho; `ORC-11` é o mais caro porque **procura** o regime pesado em vez de
presumi-lo.

Fora do portão: `bench_orcamento_bot.dart` (custo por decisão e por partida) e
`harness_partidas_bot.dart` (a matriz).

### Analyzer

```
base:  118 diagnósticos
final: 118 diagnósticos
novos: 0     perdidos: 0
```

Cinco `unnecessary_string_interpolations` chegaram a aparecer nos testes novos e
foram corrigidos antes da entrega, não tolerados.

### Provas negativas — 12 de 12 detectadas

| # | defeito injetado | testes que caem |
| - | ---------------- | --------------- |
| 1 | verificação do orçamento removida da enumeração | `ORC-16` |
| 2 | contador reiniciado a cada ramo | `ORC-03` |
| 3 | tempo usado como desempate | `ORC-11`, `CAL-02`, `CAL-05`, `CAL-12`, `BOTIA-16`, `NV-05` |
| 4 | primeiro plano em vez do melhor avaliado | 18 testes (`BOTIA-*`, `CAL-*`, `NV-*`, `ORC-11`) |
| 5 | fallback acionado mesmo havendo plano completo | 28 testes, incluindo `ORC-05`, `ORC-06`, `ORC-07` |
| 6 | fallback devolve jogada ilegal | `ORC-17` |
| 7 | peso 4 da memória pública alterado | `ORC-14` |
| 8 | sinal público de descartes removido | 13 testes (`PROV-*`, `CAL-*`, `ORC-14`) |
| 9 | orçamento compartilhado entre turnos | `ORC-11`, `NV-10` |
| 10 | expansão recursiva fora da contagem | `ORC-16` |
| 11 | ordem instável no fallback | `ORC-06` |
| 12 | informação privada na telemetria | `ORC-13` |

Todas revertidas; árvore limpa conferida ao fim. As mutações de desempenho
foram verificadas quanto à aplicação real do defeito antes de creditar a morte
(o script aborta se a âncora não casar, e a saída registra a aplicação).

### Três lacunas que as mutações acharam — nos testes, não no código

**1 e 10 — "conta mas não para".** Trocar `if (semOrcamento(...)) return;` por um
`gastarNo(...)` solto não derrubava nada. O motivo é sutil e vale registrar: o
**contador não denuncia esse defeito**, porque `gastarNo` recusa *antes* de
incrementar — o total fica preso no teto mesmo com a varredura correndo solta.
O contador estava medindo a si mesmo. Entrou `tentativasAposEsgotar`, que conta
nós **tentados depois** do fechamento: zero num código que obedece, milhares num
que só conta. E `ORC-16` passou a varrer uma faixa de tetos, exigindo que o
limite caia ora na enumeração de unidades, ora na combinação de baixadas — só a
faixa baixa deixava o laço de combinação sem prova nenhuma.

**6 — fallback ilegal.** Trocar `gerarAcoesLegais` por "qualquer descarte da mão"
não derrubava nada porque, no estado testado, todo descarte era mesmo legal.
`ORC-17` põe o fallback na fase de **compra**, onde descartar é ilegal: é ali que
um fallback que inventa ação se denuncia.

---

## 13. Escopo e limites

Arquivos alterados:

```
app/lib/bot/orcamento_busca.dart      novo         contador único
app/lib/bot/gerador_candidatos.dart   modificado   usa o orçamento injetado
app/lib/bot/executor_bot.dart         modificado   corte, fallback, telemetria
app/lib/bot/pesos.dart                modificado   limites e ConfiguracaoBot.base
app/lib/bot/razoes.dart               modificado   razão do fallback
app/lib/motor/autoridade_canonica.dart modificado  teto OPCIONAL na derivação
app/lib/mesa.dart                     modificado   orçamento por decisão
app/test/teste_motor.dart             modificado   17 provas ORC-*
app/test/bench_orcamento_bot.dart     novo         benchmarks
app/test/harness_partidas_bot.dart    modificado   lado de referência configurável
```

**Zero regra do Buraco alterada.** O peso 4 não foi tocado, nenhum outro peso foi
recalibrado, a matriz não foi reduzida, a semente lenta não foi excluída, não há
aleatoriedade nova, não há isolate, e servidor, Functions, Rules e UI seguem
intocados. Zero deploy, zero PR, zero merge, `main` intocada.

---

## 14. Riscos residuais

1. **O p99 do STBL passa a ser cortado.** O teto de 2.000 preserva o p95 medido
   (784 transações) e corta o p99 (3.464). Foi troca consciente: o teto de 2 s
   por decisão não cabia junto com preservar o p99. Aparece na matriz como os
   48,2% do STBL — dentro da faixa, mas é o preço.
2. **O corpus de calibração tem 5 sementes.** A distribuição que escolheu o
   número veio de 610 decisões. Uma amostra maior poderia deslocar o p95 e, com
   ele, o teto.
3. **A derivação continua sem teto para o JOGADOR humano** — de propósito,
   porque cortá-la mudaria o que a pessoa pode escolher. Se uma mão humana
   chegar ao regime de 100 mil transações, a interface vai esperar. Não foi
   observado, e resolver exigiria decidir o que mostrar a quem escolhe à mão.
4. **O fusível temporal nunca disparou** em nenhuma medição. É proteção contra
   defeito não previsto — e proteção que nunca disparou também nunca foi
   exercitada de verdade.
5. **O grupo novo custa ~25 s no portão** quando roda sozinho, com `ORC-11` como
   principal responsável.

---

## 15. Veredito

**`PASS — BUSCA DO BOT STBL LIMITADA DE FORMA DETERMINÍSTICA COM FALLBACK LEGAL
E SEM REGRESSÃO`**

| condição do §18 | resultado |
| --------------- | --------- |
| término da semente patológica | **9,2 s** (era ~2 h) |
| nenhuma decisão acima de 2 s | pior decisão do corpus: **0,55 s** |
| 384 partidas concluídas | **384/384** |
| zero ilegalidades | **0** |
| qualidade dentro dos limites | 49,36% agregado; menor modalidade 48,2% |
| decisões normais preservadas | **602/603** escolhas idênticas |
| memória pública de descartes intacta | peso 4, ponto único de consumo, sinal não vazio |
