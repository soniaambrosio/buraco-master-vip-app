# RELATÓRIO — ORÇAMENTO DETERMINÍSTICO DE BUSCA E FALLBACK LEGAL DO BOT STBL V1

**VEREDITO: (ver §12)**

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
