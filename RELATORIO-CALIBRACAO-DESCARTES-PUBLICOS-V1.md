# RELATÓRIO — CALIBRAÇÃO ESTRATÉGICA DO BOT COM MEMÓRIA PÚBLICA DE DESCARTES V1

**VEREDITO: (ver §13 — Gate Final)**

---

## 1. Git

| item | valor |
| ---- | ----- |
| branch | `claude/bot-calibracao-descartes-publicos-v1` |
| base | `07eb4ff3113b310545eb0bebacbbcdc4215212ae` (`claude/proveniencia-descartes-v1-818916`) |
| HEAD inicial | `07eb4ff` (a base; o worktree foi resetado antes de qualquer edição) |
| merges | **0** (`git log --merges 07eb4ff..HEAD` = vazio) |
| deploy | **nenhum** |
| force push / rebase | **nenhum** |

### Ancestralidade (Gate Zero, itens 1–4)

```
89fca38   Inteligência do Bot V1        -> ancestral de 07eb4ff: SIM
f41eea0   Encerramento de turno V1      -> ancestral de 07eb4ff: SIM
07eb4ff   Proveniência de descartes V1  -> BASE desta OS
```

Base conferida **duas vezes** por `git ls-remote origin
refs/heads/claude/proveniencia-descartes-v1-818916`: as duas consultas
responderam `07eb4ff3113b310545eb0bebacbbcdc4215212ae`, idêntico ao HEAD local.
Árvore limpa antes da primeira edição. A branch alvo não existia — nem local,
nem remota —, então o nome preferencial da OS foi usado sem sufixo.

---

## 2. Gate Zero — o que foi verificado antes de editar

| # | verificação | resultado |
| - | ----------- | --------- |
| 5 | `DescarteRegistrado` existe | `rules/estado.dart:56` |
| 6 | `EstadoJogo.descartes` existe | `rules/estado.dart:147` |
| 7 | proveniência sobrevive a snapshot/reconexão | `PROV-06`, `PROV-07` verdes na base |
| 8 | `VisaoInformacao.descartesPublicos` existe | `bot/visao_informacao.dart:124` |
| 9 | `ModeloParceiro.parceiroDescartou` existe | `bot/modelo_parceiro.dart:112` |
| 10 | **o sinal não tinha consumidor estratégico** | `grep` por `parceiroDescartou`/`descartesPublicos` em `avaliador_heuristico`, `gerador_candidatos`, `executor_bot`, `risco_descarte`, `analise_mao` e `mesa.dart`: **zero ocorrências** |
| 11 | decisões de descarte | `AvaliadorHeuristico.avaliarPlano`, bloco `if (r.planoIncluiDescarte && plano.cartaDescartada != null)` |
| 12 | pesos centralizados | `bot/pesos.dart` (`PesosHeuristicos`) — nenhum número de estratégia fora dali |
| 13 | códigos de razão | `bot/razoes.dart` (`Razao`) |
| 14 | configuração padrão do bot | `mesa.dart` → `configuracaoBot`, lido a cada `botJoga` |
| 15 | baseline de testes | **445** verdes |
| 16 | baseline do analyzer | **118** issues (3 errors ambientais pré-existentes de `google_sign_in`) |
| 17 | baseline de desempenho | ver §10 |
| 18 | baseline de partidas completas | ver §9 |

Nada divergiu; nenhuma injeção de autoria era possível (a OS 2 removeu o
parâmetro que permitia passar autoria de fora); o bot não alcança mãos alheias
(a `VisaoInformacao` não tem campo para elas). Gate Zero **verde**.

---

## 3. Ponto único de consumo

O fato continua sendo do `ModeloParceiro`. O efeito estratégico entra em **um**
lugar: [`avaliador_heuristico.dart`](app/lib/bot/avaliador_heuristico.dart), no
bloco do descarte de `avaliarPlano`.

```dart
if (r.usaMemoriaDescarteParceiro &&
    p.memoriaDescarteParceiro != 0 &&
    !ehCuringaEstrategico(carta) &&
    parceiro.parceiroDescartou(carta)) {
  f[featureMemoriaDescarteParceiro] = p.memoriaDescarteParceiro;
}
```

`EstadoJogo.descartes` **não** é lido por `gerador_candidatos.dart`,
`executor_bot.dart`, `risco_descarte.dart`, pelo motor nem pela UI. O gerador
continua produzindo alternativas legais; o avaliador decide preferência.

As três guardas, e por que cada uma existe:

1. **flag da configuração** — desligada, a V2 é a V1 bit a bit;
2. **peso zero não emite feature** — sem isso, zerar o peso deixaria uma chave
   `0.0` a mais no rastro, e "reproduz a V1 bit a bit" seria falso no traço
   ainda que verdadeiro na decisão;
3. **curinga nunca recebe o prêmio** — a política que impede descartar curinga é
   um ponto de desligamento declarado; a guarda é estrutural e não confia nela.

---

## 4. Peso aprovado e precedência

**`memoriaDescarteParceiro = 4`**, em `ConfiguracaoBot.v2`.

### Teto por precedência (§6), antes de qualquer medição

O prêmio precisa perder para todo termo acima dele. O menor passo **não-nulo**
de um termo concorrente é `riscoDescarte × 1 = 6` — uma nota de risco mínima,
que qualquer carta de 10 pontos já tem. Um prêmio ≥ 6 poderia virar uma decisão
em que a alternativa é *estritamente* mais segura. Daí o teto: **abaixo de 6**.

| termo concorrente | magnitude | relação |
| ----------------- | --------- | ------- |
| `descarteUtilAoParceiro` | 34 | carta que estende jogo público da dupla |
| `descarteAdjacenteAoParceiro` | 12 | carta que encosta em jogo público |
| `riscoDescarte × nota` | 6, 12, 18… | menor passo de risco |
| `danoDescarte × força` | 2,2 por ponto de estrutura | 8♥ no meio de corrida ≈ 15,4 |
| **`memoriaDescarteParceiro`** | **4** | desempate entre alternativas próximas |
| `custoCuringa` / dano de curinga | 60 / 2200 | inalcançável por construção |

### Calibração por medição

Três valores dentro do teto foram medidos em partidas completas espelhadas
(4 sementes × 3 modalidades × 2 lados = 24 partidas por valor):

| peso | participação da V2 nos pontos | vitórias V2–V1 | sinal aplicado | sinal decisivo |
| ---- | ----------------------------- | -------------- | -------------- | -------------- |
| 3 | 44,78% | 8–16 | 10,5% das decisões | 2,6% |
| **4** | **48,46%** | **10–14** | **11,4%** | **3,5%** |
| 5 | 45,42% | 9–15 | 12,0% | 4,0% |

O 4 foi escolhido por ser o melhor dos três nessa amostra, não por conveniência
de teste. A amostra de calibração é pequena (24 partidas por valor) e serve para
ordenar candidatos, não para afirmar não-regressão — quem responde isso é a
matriz de 384 partidas da §9.

### Precedência provada, não declarada

| exigência da §6 | prova |
| --------------- | ----- |
| perde para curinga protegido | `CAL-10` (avalia o plano do JOKER diretamente) |
| perde para carta que estende jogo público da dupla | `CAL-08` |
| perde para dano estrutural relevante | `CAL-09` |
| perde para risco de alimentar o adversário | `CAL-11` |
| a situação ATUAL prevalece sobre o histórico | `CAL-08` (o parceiro dispensou justamente a carta que hoje serve à mesa; ela é preservada) |
| não vira filtro/obrigação | mutação 5 (§8) derruba 6 testes |

---

## 5. Configuração V1 preservada, V2 criada

`ConfiguracaoBot.v1` **não foi tocada**. Os campos novos nascem neutros — flag
desligada e peso zero —, então `v1` produz exatamente a decisão de antes. Isso é
verificado, não afirmado: `CAL-02` compara V1 contra V2-com-flag-desligada e
contra V2-com-peso-zero, exigindo igualdade de carta descartada, score,
features, razões, candidatos avaliados e truncamento.

```dart
static const v2 = ConfiguracaoBot(
  pesos: PesosHeuristicos(
    versao: 'bmv-bot-heuristico-v2-descartes-publicos',
    memoriaDescarteParceiro: 4,
  ),
  regras: RegrasEstrategicas(usaMemoriaDescarteParceiro: true),
);
```

A V2 difere da V1 em **duas** coisas: a flag e o peso. Pesos, orçamento de
busca, largura, semente e política de desempate são literalmente os mesmos — a
comparação mede o sinal, não uma segunda mudança embutida.

`PesosHeuristicos.copyWith` foi criado (não existia) para a comparação e para as
provas de reprodução. `ConfiguracaoBot.comPesos` idem.

**Padrão de produção:** `mesa.dart` passou a nascer com `ConfiguracaoBot.v2`. A
V1 continua acessível para regressão, comparação e rollback — trocar o campo
devolve o robô da OS de Inteligência do Bot V1, sem recompilar nada.

---

## 6. Rastro: feature e razão

**Feature:** `memoriaDescarteParceiro`, constante pública
`featureMemoriaDescarteParceiro`. Entra na soma como qualquer outro termo, e
`CAL-13` exige que a soma das features feche no score (tolerância 1e-9).

**Razão:** `Razao.descarteMemoriaParceiro` = `DESCARTE_MEMORIA_PARCEIRO`.

A razão só é emitida quando o sinal foi **decisivo**. A condição é verificada,
não presumida: o executor refaz o argmax descontando a contribuição da feature,
usando o **mesmo** desempate (assinatura do plano + semente), e compara os
vencedores. Sai cedo quando nenhuma alternativa recebeu contribuição, que é o
caso comum.

O rastro permite provar, para qualquer decisão: que o sinal existia
(`features`), qual alternativa o recebeu (`plano.cartaDescartada`), qual peso foi
aplicado (o valor da feature), se a evidência mudou a escolha (presença da razão)
e qual configuração decidiu (`assinaturaDecisao` carrega `pesos=<versão>`).

---

## 7. Matriz direcionada (§11)

17 testes `CAL-*` no portão (`app/test/teste_motor.dart`), cobrindo os 30 itens:

| itens | teste |
| ----- | ----- |
| 1, 13 · alternativas equivalentes, carta dispensada é escolhida | `CAL-01-ABERTO/FECHADO/SBTL` |
| 24, 25, 26 · as três modalidades | `CAL-01-*` |
| 11, 12 · flag desligada e peso zero reproduzem a V1 | `CAL-02` |
| 2, 3, 4, 5, 10 · quem conta (valor+naipe; parceiro sim; adversário não; o próprio bot não; cópias equivalentes) | `CAL-03` |
| 18 · ausência de registro não produz bônus | `CAL-04` |
| 6 · snapshot legado sem registros | `CAL-05` |
| 7, 8 · compra do lixo preserva, nova mão elimina | `CAL-06` |
| 9 · reconexão preserva a decisão | `CAL-07` |
| 14 · dispensada, mas útil à mesa da dupla, é preservada | `CAL-08` |
| 15 · dispensada, mas estrutural na mão, é preservada | `CAL-09` |
| 16 · não supera a proteção de curinga | `CAL-10` |
| 17 · não leva a alimentar o adversário | `CAL-11` |
| 19, 20 · razão aparece quando decisiva, some quando inócua | `CAL-12` |
| 21 · feature participa da soma | `CAL-13` |
| 23 · permutar mãos ocultas não muda a decisão | `CAL-14` |
| 22, 27, 28, 29, 30 · determinismo, autoridade, turno concluído, sem impasse, orçamento | `CAL-15` |

### Não-vacuidade dentro da matriz

`CAL-01` não se contenta em ver a V2 escolher a carta dispensada. O **mesmo**
estado canônico é rodado com dois livros de proveniência diferentes; a V1, que
não enxerga proveniência, tem de escolher o **mesmo** rei nos dois; e exatamente
**uma** das duas decisões da V2 tem de virar. Assim a diferença não pode vir da
distribuição nem do desempate.

---

## 8. Provas por defeito injetado (§12)

Cada mutação foi aplicada sobre a **cópia** da lib no overlay — a árvore do
repositório nunca ficou suja — e a suíte inteira rodou em cima.

| # | defeito injetado | testes que caem |
| - | ---------------- | --------------- |
| 1 | autoria deduzida pelo topo do lixo | `PROV-01`, `PROV-12` |
| 2 | autoria deduzida pela vez anterior (`ordem % 4`) | `CAL-01`, `CAL-03`, `CAL-06`, `CAL-12`, `CAL-13`, `CAL-14` |
| 3 | descarte de adversário tratado como do parceiro | `CAL-03`, `PROV-12` |
| 4 | ausência de registro tratada como evidência positiva | `CAL-03`, `CAL-04`, `CAL-06`, `PROV-01`, `PROV-05`, `PROV-12` |
| 5 | sinal virou proibição dura (alternativa não dispensada é vetada) | `CAL-04`, `CAL-08`, `CAL-09`, `CAL-10`, `CAL-11`, `CAL-12` |
| 6 | peso 100 (maior que a proteção de estrutura) | `CAL-09`, `CAL-11` |
| 7 | guarda do curinga removida | `CAL-10` |
| 8 | razão emitida sem ter alterado a decisão | `CAL-12` |
| 9 | leitura direta de mão oculta | `PROV-00`, `PROV-01`, `PROV-03`, `PROV-08`, `PROV-09`, `PROV-11` |
| 10 | V1 modificada em vez de versionada | `CAL-01`, `CAL-02` |
| 11 | história apagada na compra do lixo | `CAL-06`, `PROV-13` |
| 12 | história sobrevivendo à nova mão | `CAL-06`, `PROV-05` |

**12 de 12 detectadas.** Todas revertidas; árvore limpa conferida por
`git status` ao fim.

### O que a primeira rodada encontrou — nos testes, não no código

A primeira passada detectou só 8 das 12, e as falhas foram informativas:

* **`CAL-09` passava por motivo errado.** A mão tinha uma corrida de TRÊS
  cartas; o robô baixava o jogo e o 8♥ saía da mão antes do descarte, então
  nenhuma alternativa era comparada. Com corrida de DUAS cartas não há baixada
  possível. O teste ganhou `expect(plano.baixada, isNull)` para não degenerar de
  novo em silêncio. Só depois disso a mutação 6 passou a ser detectada.
* **`CAL-10` olhava as features do VENCEDOR.** O curinga custa −2200 de dano
  estrutural e nunca vence — a guarda do curinga podia ser removida sem nenhum
  teste cair. Agora a alternativa que descarta o JOKER é avaliada diretamente.
* **`CAL-06` rodava no motor legado** (`novo()` não liga o canônico), então a
  compra do lixo que importa — a de `avaliarComprarLixo` — não era exercitada.
  Passou a usar `MotorConfig.producao()`.
* **A mutação 10 era inerte.** Virar só a flag não faz nada, porque o peso padrão
  é zero. A mutação honesta é a que faz a V1 virar V2 em silêncio: flag ligada
  **e** peso não-nulo nos padrões.

Nenhuma dessas correções afrouxou asserção: todas as quatro tornaram os testes
mais estritos.

---

## 9. Partidas completas (§13)

Harness determinístico em `app/test/harness_partidas_bot.dart`, **fora do
portão** (o CI roda `teste_motor.dart`; esta comparação custa horas).

### Controle e espelhamento

Mesma distribuição, modalidade, meta (1500), semente, orçamento, limites de
busca e política de desempate. A configuração é atribuída **por dupla**,
trocando `Jogo.configuracaoBot` antes de cada jogada — nenhuma linha de
`mesa.dart` precisou mudar, e a troca não existe em produção.

Cada semente é jogada **duas vezes**, com os lados trocados (candidata em 'nos'
e depois em 'eles'), e o par entra agregado.

### Amostra executada — a matriz mínima da OS, inteira

```
64 sementes × 3 modalidades × 2 lados espelhados = 384 partidas completas
```

Duração: **~4h20** de relógio no shard mais lento, com quatro processos em
paralelo. O tempo somado de decisão nas 384 partidas foi de **24.838 s**.
A matriz **não** foi reduzida.

### Resultado

| modalidade | partidas | vitórias V2–V1 | pontos V2 × V1 | participação V2 | canastras V2×V1 | compras do lixo | mortos |
| ---------- | -------- | -------------- | -------------- | --------------- | --------------- | --------------- | ------ |
| ABERTO | 128 | 66–62 | 161.840 × 159.825 | **50,3%** | 229×195 | 2.039 | 579 |
| FECHADO | 128 | 64–64 | 167.300 × 167.290 | **50,0%** | 81×86 | 2.130 | 798 |
| STBL | 128 | 66–62 | 189.250 × 178.815 | **51,4%** | 215×205 | 953 | 638 |
| **AGREGADO** | **384** | **196–188** | **518.390 × 505.930** | **50,61%** | — | 5.122 | 2.015 |

| item exigido pela §14 | resultado |
| --------------------- | --------- |
| jogadas ilegais | **0** — toda jogada passa por `aplicarLegal`; nenhuma foi aplicada contra recusa |
| exceções / falhas técnicas | **0** em 384 partidas |
| partidas não terminadas | **0** |
| loops | **0** (nenhuma partida bateu o teto de segurança) |
| impasses estratégicos | 236 (todos do impasse de curinga já documentado na OS de Bot IA V1) |
| buscas truncadas | 26.419 de 69.723 turnos — mesma taxa da base (ver §10) |

**Participação agregada 50,61% ≥ 50%.** Nenhuma modalidade abaixo de 47% (a
menor é 50,0%). Os critérios de não-regressão da §14 estão cumpridos.

### O que a amostra pequena dizia, e por que ela não valia

A calibração (24 partidas por peso) media 44,8% / 48,5% / 45,4% — todas abaixo
do limite. Com 384 partidas o mesmo peso 4 mede 50,61%. A diferença é ruído: 24
partidas completas de Buraco não distinguem 45% de 50%. Isso está registrado
porque é a armadilha óbvia desta OS — parar na amostra de calibração teria
produzido um FAIL falso, e escolher o peso pela amostra pequena teria sido
escolher por ruído.

### Não-vacuidade em partida real (§15)

| medida | valor |
| ------ | ----- |
| decisões observadas | 69.723 |
| decisões com a feature ≠ 0 | **8.171** (11,7%) |
| decisões em que o sinal foi **decisivo** | **2.281** (3,3%) |

O sinal nem é decorativo nem dominante: aparece em cerca de um turno em nove e
muda o vencedor em um turno em trinta. Por modalidade, o sinal é decisivo em
4,3% (ABERTO), 2,5% (FECHADO) e 2,7% (STBL) das decisões.

Exemplos reproduzíveis, com semente e rastro, estão nos testes direcionados:
`CAL-01-ABERTO/FECHADO/SBTL` viram a decisão ao ligar a flag e voltam ao
comportamento V1 ao desligá-la (`CAL-02`), sobre o mesmo estado canônico.

---

## 10. Desempenho (§10)

### Custo POR DECISÃO — a medida que isola o sinal

As partidas não respondem isso: a V2 joga trajetórias diferentes, com mãos e
mesas diferentes, e o custo de decidir depende do tamanho da mão. Comparar
tempo médio por turno entre duas trajetórias mede as trajetórias.

O bench (`harness_partidas_bot.dart`, teste "custo da decisão") põe as duas
configurações para decidir sobre o **mesmo** estado, com as **mesmas**
alternativas, alternando chamada a chamada e comparando **medianas**:

| modalidade | planos avaliados | mediana V1 | mediana V2 | delta | p95 V1 | p95 V2 |
| ---------- | ---------------- | ---------- | ---------- | ----- | ------ | ------ |
| ABERTO | 124 | 237.907 µs | 240.001 µs | **+0,9%** | 329.711 µs | 316.934 µs |
| FECHADO | 3 | 1.157 µs | 1.137 µs | **−1,7%** | 2.190 µs | 2.848 µs |
| STBL | 69 | 70.733 µs | 72.611 µs | **+2,7%** | 90.252 µs | 91.234 µs |

O trabalho que a V2 acrescenta é montar o índice uma vez por decisão, consultar
um conjunto por plano e uma passada linear do argmax contrafactual — desprezível
diante da busca de planos. **Nenhum aumento material de tempo médio ou p95.**

Duas versões deste bench foram descartadas por medirem a coisa errada, e as
duas estão registradas no código:

* medir em **blocos** (60 chamadas da V1, depois 60 da V2) acusou a V2 **22,9%
  mais rápida** no STBL — impossível. Era deriva da máquina no intervalo;
* medir sobre um estado na fase de **compra** dava `planos=0`: `decidirJogo` não
  gera plano nenhum ali e o avaliador nem é alcançado. O bench concluiria "sem
  custo" sem ter exercitado uma linha da V2.

### Orçamento e nós

`CAL-15` prova, sobre o mesmo estado, que a V2 avalia **exatamente** o mesmo
número de alternativas que a V1 e carrega o mesmo `truncado`. O sinal entra
depois da geração: não amplia nem reduz a busca.

### Duração das partidas

Comparação nas **mesmas** sementes (1–4, 24 partidas de cada lado), V1×V1 contra
V1×V2:

| | turnos/partida | rodadas/partida | truncadas/turno | impasses | não terminadas | falhas técnicas |
| - | -------------- | --------------- | --------------- | -------- | -------------- | --------------- |
| V1 × V1 | 166,0 | 3,42 | 0,388 | 14 | 0 | 0 |
| V1 × V2 | 189,0 | 3,75 | 0,409 | 18 | 0 | 0 |

As partidas com a V2 ficaram ~14% mais longas nessa amostra de 24. É efeito de
**trajetória** (jogo diferente chega à meta em outro ritmo), não custo por
decisão — que o bench mede em ~+1%. Com 24 partidas isso está dentro do ruído,
e fica registrado como risco residual a acompanhar, não como número provado.

### O penhasco do STBL, e de quem ele é

Uma partida (STBL, semente 29) consumiu **2 horas**, a ~75 s por turno — sozinha
respondeu por boa parte das 4h20 do shard mais lento. É explosão combinatória da
busca de planos numa mão grande.

Evidência de que é **pré-existente**, e não da V2:

* **controle direto da mesma semente**: STBL/29 rodado com a **V1 nas duas
  duplas** passou de **2h25 sem terminar** — mesma ordem de grandeza das 3,6 h
  que o par espelhado V1×V2 consumiu. O penhasco está no baralho, não na
  configuração. (A execução foi encerrada nesse ponto: o número exato não muda
  a conclusão, e a marca já é maior que a de qualquer outra partida das 384.)
* o controle **V1 × V1** das sementes 1–4 já media p95 de 4,7 s por turno no
  STBL, contra 74 ms no FECHADO — o penhasco existe sem nenhuma linha desta OS;
* `CAL-15` prova que a V2 avalia o mesmo conjunto de alternativas;
* o bench por decisão mede +1%.

**Achado ambiental, não defeito:** ao rodar essa mesma semente isolada com
**cinco** VMs Dart simultâneas, o processo abortou com
`zone.cc: 96: error: Out of memory`. A mesma semente terminou normalmente
(6/6 partidas, integridade OK, 0 falhas técnicas) dentro da execução das 384,
com quatro processos. É pressão de memória da máquina, não defeito do código.

---

## 11. Gates gerais (§16)

### Testes

```
base  (07eb4ff): 445 verdes
final:           462 verdes   (+17 CAL-*)
regressões:        0
```

Cobertos na mesma execução: suíte do bot (`BOTIA-*`, `NV-*`), do motor
(`C7`/`C10`), encerramento de turno (`ENC-*`), proveniência (`PROV-*`),
serialização/reconexão, partidas completas do portão (`PARTIDA-*`, `AUD-01-*`) e
a bateria nova. Nenhum teste antigo foi apagado, renomeado ou afrouxado.

### Analyzer

```
base  (07eb4ff): 118 issues
final:           118 issues
diagnósticos novos: 0     diagnósticos perdidos: 0
```

Comparação linha a linha (`comm` sobre a saída ordenada, sem número de linha e
coluna), medida no **mesmo** overlay para base e candidata. Zero erro novo, zero
warning novo, nenhum diagnóstico novo nos arquivos tocados.

### Determinismo

`CAL-15` exige, para a mesma entrada, configuração, orçamento e semente: mesma
decisão, mesmo score, mesmas features, mesmas razões e mesma
`assinaturaDecisao`. `CAL-07` estende a exigência ao estado reconstruído de um
snapshot.

---

## 12. Escopo

Arquivos alterados, todos dentro do §17:

```
app/lib/bot/pesos.dart                +138 -6    V2, flag, peso, copyWith
app/lib/bot/avaliador_heuristico.dart  +40       PONTO ÚNICO de consumo
app/lib/bot/executor_bot.dart          +40       razão só quando decisiva
app/lib/bot/modelo_parceiro.dart       +34 -14   índice da memória
app/lib/bot/razoes.dart                 +9       razão nova
app/lib/mesa.dart                       +8 -2    padrão passa a ser a V2
app/test/teste_motor.dart              +544      17 provas CAL-*
app/test/harness_partidas_bot.dart     +376      harness e bench
```

**Zero regra do Buraco alterada.** `gerador.dart` continua a autoridade e não
foi tocado; legalidade, proveniência canônica e formato do snapshot idem.
Servidor Node, UI, ranking, Perfil, economia, autenticação, Firebase, Rules,
modalidade, distribuição e aleatoriedade: **intocados**. **Zero deploy.**

---

## 13. Riscos residuais

1. **A janela do sinal depende do corte de largura.** O gerador expande no
   máximo `maxDescartesPorBaixada` (10) descartes por baixada, ordenados por
   dano → risco → pontos. Numa mão muito grande, a carta dispensada pelo
   parceiro pode cair fora antes de ser avaliada. Não é perda de correção — é
   perda de alcance, e aparece como truncamento no rastro.
2. **Partidas ~14% mais longas** na amostra de 24 sementes espelhadas. Pode ser
   ruído; só uma amostra maior de V1×V1 responderia, e ela custa outras horas.
3. **Penhasco de desempenho do STBL** (75 s/turno numa semente em 64). É
   anterior a esta OS e continua aberto — vale uma OS de custo de busca.
4. **O sinal ainda é só do descarte.** Nada foi ligado à compra, à baixada nem à
   prudência de batida. Era o escopo.
5. **Nenhuma superioridade estatística foi provada.** 50,61% em 384 partidas
   prova não-regressão, não vantagem.

---

## 14. Veredito

**`PASS — MEMÓRIA PÚBLICA DE DESCARTES CALIBRADA E CONSUMIDA PELO BOT SEM
REGRESSÃO`**

* o sinal **muda decisão**: 3,3% das decisões em partida real, e casos
  direcionados que viram ao ligar a flag e voltam ao desligá-la — não é
  `FAIL — SINAL ESTRATÉGICO CONECTADO, MAS VAZIO`;
* os casos direcionados melhoraram **e** as partidas completas não regrediram
  (50,61% agregado, nenhuma modalidade abaixo de 47%) — não é
  `FAIL — MELHORIA LOCAL COM REGRESSÃO GLOBAL`;
* o bot lê **apenas** o que a autoridade publicou, e permutar as mãos ocultas
  não muda a decisão (`CAL-14`) — não é
  `FAIL — FRONTEIRA DE INFORMAÇÃO DO BOT VIOLADA`.

Não se declara "bot mais forte". A evidência sustenta **não-regressão**, não
superioridade.

---
