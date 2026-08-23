# RELATÓRIO — GATE DETERMINÍSTICO DA CAPACIDADE DE BATIDA NATURAL DO BOT DART V1

**VEREDITO: PASS — CAPACIDADE DE BATIDA DO BOT DART PROTEGIDA E REPRODUZÍVEL**

---

## 1. Git

| item | valor |
| ---- | ----- |
| branch | `claude/dart-bot-batida-gate-f52f69` |
| base | `d3effdc119bd68ccf27fdcb628834a43baf5c6d8` (`claude/bot-orcamento-busca-stbl-v1`) |
| HEAD inicial do worktree | `fb9edb5` — o `main` placeholder, **descartado** antes de qualquer edição |
| HEAD final | `7c7d58e` (código) · o relatório entra no commit seguinte |
| merges | **0** |
| PR | **nenhum** |
| deploy | **nenhum** |
| `main` | **intocada** |

O worktree nasceu apontando para `fb9edb5`, que é o `main` placeholder e **não
contém** a linhagem do bot. Foi resetado para o SHA da OS antes da primeira
edição; nenhuma linha foi escrita sobre a base errada.

---

## 2. O buraco que este portão fecha

A suíte obrigatória da base tem **479 testes verdes** e nenhum deles ficaria
vermelho se o bot perdesse a capacidade de bater. Isso não é opinião — é o que
o código diz, e vale registrar exatamente onde.

**As 12 partidas completas e a auditoria AUD-01 rodam o robô LEGADO, não o de
produção.** As duas usam o helper `novo()` de `teste_motor.dart:78`:

```dart
Jogo novo([String modalidade = 'ABERTO', int? seed]) {
  final j = Jogo(const ['você', 'B1', 'B2', 'B3'], ..., seed: seed);
```

Sem `motorConfig`, o `Jogo` nasce com `const MotorConfig()`, cujo
`canonicoAtivo` é **`false`** (`motor_config.dart`). E `Jogo.botJoga` decide o
caminho por essa flag:

```dart
if (motorConfig.canonicoAtivo) { _botJogaEstrategico(assento, marca); return; }
_botJogaLegado(assento, marca);
```

Ou seja: as únicas partidas completas dentro do portão exercitam
`_botJogaLegado` — o robô guloso que existe para o rollback —, e **nenhuma**
exercita a camada estratégica (`lib/bot/`) que o app real usa. As `PARTIDA-*`
sequer passam semente: o baralho delas é aleatório.

**E nenhuma delas conta batidas.** `AUD-01` reprova meld ilegal e ciclo;
`PARTIDA-*` exige 108 cartas, integridade e um vencedor no placar. Uma rodada
que termina por **esgotamento do baralho** satisfaz as duas coisas: o placar é
contado, há vencedor, o baralho está íntegro — e ninguém bateu. Um bot que
nunca mais fechasse a mão passaria por esses testes sem um arranhão.

O harness que joga partidas com o bot de produção existe
(`app/test/harness_partidas_bot.dart`), e o cabeçalho dele é explícito: *"FORA
DO PORTÃO"*. Ele mede qualidade relativa entre duas configurações e nunca foi
um piso.

É esse o buraco: **a capacidade de bater não tinha piso, não tinha corpus e não
tinha portão.**

---

## 3. O que a suíte mede, e como

`app/test/gate_batida_bot.dart` joga **26 partidas completas** de 108 cartas e
conta batidas legais. Cada partida nasce assim, e não de fixture:

```dart
final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], ..., seed: semente,
    motorConfig: MotorConfig.producao());
j.configuracaoBot = cfg;
```

`MotorConfig.producao()` liga a **autoridade canônica**: toda jogada dos quatro
assentos é derivada pela camada estratégica e aplicada pelo mesmo motor que
valida a jogada do humano. Nenhuma mão é montada, nenhuma canastra é posta na
mesa, nenhum morto é entregue de graça.

### O que conta como batida

Uma, e só uma coisa: **a rodada encerrou com `duplaQueBateu != null`**. O
número vem do motor, não desta suíte. Esgotamento do baralho também encerra a
rodada — e cai no ramo `else`, num contador separado. Os dois ramos são
exclusivos, e `GBB-09` confere que a soma deles é igual ao número de rodadas
efetivamente encerradas, contado num terceiro contador independente.

### O que cada batida precisa provar

| exigência da OS | como é medida |
| --------------- | ------------- |
| zero divergência plano × ação | pelos DOIS lados: a rodada acabou em batida ⇒ a razão da decisão está no **vocabulário fechado** de razões que produzem batida (`BAIXA_BATIDA` no plano de turno; `COMPRA_LIXO_ESTRUTURA`/`COMPRA_LIXO_VOLUME` na compra — ver §7.4) e o assento que jogou é da dupla que bateu; e o turno acabou dizendo `BAIXA_BATIDA` ⇒ a rodada encerrou em batida |
| zero batida sem morto/canastra exigida | no pós-estado projetado, `mortoPego[dupla] \|\| mortos.isEmpty` **e** `duplaPodeBater(estado, dupla, spec)` — a função canônica de `rules/morto/morto.dart`, não uma cópia |
| feature `batida = 160` | o conjunto de valores DISTINTOS que a feature assumiu em todas as batidas de PLANO tem de ser exatamente `[160.0]` — se uma única batida trouxesse outro peso, a lista teria dois elementos |
| pelo menos uma `BAIXA_BATIDA` por modalidade | contagem por modalidade das decisões com essa razão primária |
| esgotamento nunca contado como batida | partição conferida contra `rodadasEncerradas` + exigência de que o corpus CONTENHA esgotamentos (senão a distinção nunca foi exercitada) |
| zero decisão vazia | contagem de decisões com `acoes` vazio **e** de turnos que terminaram com a rodada aberta e a vez parada no mesmo assento — que é a forma observável da decisão vazia dentro de uma partida |
| zero falha de integridade | `integridadeErro == null` e `falhasTecnicas == 0` em todas as partidas |

### O único desvio da produção

O **fusível temporal** é desligado na medição (`fusivelMs: 0`), e só ele. É a
única parte da busca que lê o relógio: com ele ligado, uma máquina mais lenta
cortaria decisões que uma mais rápida completaria, e o portão passaria a medir
o runner em vez de medir o bot. Os **tetos determinísticos** — 6000 nós, 2000
transações de compra do lixo, 4000 planos avaliados — são lidos de
`ConfiguracaoBot.v2` e não escritos de novo aqui:

```dart
ConfiguracaoBot configuracaoDeMedicao() => producaoDoBot.comLimites(LimitesBusca(
      nos: producaoDoBot.orcamentoBusca,
      transacoesCompraLixo: producaoDoBot.tetoTransacoesCompraLixo,
      planosAvaliados: producaoDoBot.tetoPlanosAvaliados,
      fusivelMs: 0,
    ));
```

A produção não muda: `ConfiguracaoBot.v2.fusivelBuscaMs` continua **5000**, e
`GBB-03` + `TRAVA-10` reprovam se isso deixar de ser verdade. `TRAVA-10`
confere ainda que uma `Jogo` recém-construída carrega a configuração de
produção, e que a de medição difere dela **somente** no fusível.

A **prudência de batida** fica ligada (`prudenciaBatida: true`), como manda a
OS: medir com ela desligada mediria outro bot.

---

## 4. O corpus

Blocos **contíguos** de sementes, começando em 1 nas três modalidades — nada de
semente escolhida a dedo por render batida. Os tamanhos diferem porque as taxas
medidas diferem (§8).

| modalidade | sementes | partidas | rodadas | batidas | esgotamentos |
| ---------- | -------- | -------- | ------- | ------- | ------------ |
| ABERTO | 1–10 | 10 | 38 | **17** | 21 |
| FECHADO | 1–8 | 8 | 32 | **27** | 5 |
| STBL | 1–8 | 8 | 30 | **21** | 9 |
| **total** | | **26** | **100** | **65** | **35** |

`65 + 35 = 100` — batida e esgotamento **particionam** as rodadas encerradas,
sem sobreposição e sem buraco. A conferência é do `GBB-09`, contra um terceiro
contador (`rodadasEncerradas`) que não sabe qual dos dois desfechos ocorreu.

O corpus inteiro são **5.072 turnos** de partida real, jogados duas vezes.

### Por que os esgotamentos importam

Vinte e uma das 38 rodadas do Aberto terminaram com o baralho acabando, sem
ninguém bater. Se o portão somasse os dois desfechos, o Aberto "bateria" 38
vezes e o piso de 12 seria cumprido por uma capacidade que não existe. É por
isso que `GBB-09` exige que o corpus CONTENHA esgotamentos: sem eles, a
distinção nunca teria sido exercitada.

### As duas origens de batida

| origem | razão no rastro | ABERTO | FECHADO | STBL | total |
| ------ | --------------- | ------ | ------- | ---- | ----- |
| plano de turno | `BAIXA_BATIDA` | 17 | 27 | 20 | **64** |
| compra atômica do lixo | `COMPRA_LIXO_ESTRUTURA` | 0 | 0 | 1 | **1** |

A segunda linha foi uma descoberta da primeira medição, e está contada aqui
porque é capacidade real do bot — não um acidente. Ver §7.4.

---

## 5. Os pisos, o medido e a margem

| exigência da OS | piso | medido | margem |
| --------------- | ---- | ------ | ------ |
| ABERTO | ≥ 12 | **17** | +5 |
| FECHADO | ≥ 25 | **27** | +2 |
| STBL | ≥ 16 | **21** | +5 |
| **TOTAL** | ≥ 60 | **65** | +5 |

E as demais exigências, todas medidas sobre o mesmo corpus:

| exigência | resultado |
| --------- | --------- |
| ao menos uma `BAIXA_BATIDA` por modalidade | 17 · 27 · 20 |
| feature `batida = 160` | valores distintos observados: **`[160.0]`** |
| zero divergência plano × ação | **0** |
| zero batida sem morto/canastra exigida | **0** |
| esgotamento nunca contado como batida | 35 esgotamentos, contados à parte; partição fecha em 100 |
| zero decisão vazia | **0** (e **0** turnos sem conclusão) |
| zero falha de integridade | **0** (e 0 falhas técnicas, 0 partidas truncadas) |
| duas execuções idênticas | digest `4a248a31…` nas duas |

A margem é pequena no Fechado (+2), e isso **não** é fragilidade de medição: o
corpus é determinístico, então 27 é 27 em toda execução. O que a margem
pequena significa é que uma recalibração futura dos pesos que reduzisse a
batida no Fechado acenderia o portão — que é exatamente o serviço que ele
presta.

### A reprodução

As duas execuções do corpus, no mesmo processo, produziram o mesmo digest. E
**dois processos independentes** também: a execução de diagnóstico e a de
verificação final produziram `digestExecucao1` idêntico. Isso importa porque
a semente de hash de `String` do Dart é sorteada por isolate — duas execuções
no mesmo processo não distinguiriam uma ordenação que dependesse de `hashCode`;
dois processos distinguem.

---

## 6. Proteção do portão

### A fonte única

`app/test/gates/gates_bot.txt` declara o portão com as seis chaves que a OS
exige. O formato tem dois níveis e **a margem é o que os distingue**:

```
GATE-BATIDA-NATURAL-BOT-V1
  suite: app/test/gate_batida_bot.dart
  executor: flutter test test/gate_batida_bot.dart --reporter expanded
  sha256: 5fd39ab4c4691e02b0419a140809292dce5acd66624bac6964f6d12baf98291c
  provas: 13
  casos: GBB-01, …, GBB-13
  exige: ABERTO>=12, FECHADO>=25, STBL>=16, TOTAL>=60, MODALIDADES>=3, PARTIDAS>=26, PROVAS>=13
```

O leitor (`app/test/gates/leitor_fonte_unica.dart`) trata como **erro** tanto o
atributo na margem quanto a entrada indentada. Não é preciosismo de formato:
um leitor que confunde os dois transforma `suite:` e `sha256:` em portões
fantasmas e passa a reprovar um repositório íntegro. `TRAVA-02` exercita as
duas violações e mais oito — chave repetida, chave desconhecida, chave
obrigatória ausente, `provas` discordando de `casos`, sha malformado,
exigência malformada, arquivo vazio e arquivo só com comentário — e exercita
também o **caminho feliz**, porque uma trava que reprova tudo não distingue
estado nenhum.

O `sha256` é o digest dos bytes com o CR das sequências CRLF removido. O
repositório é editado no Windows (`core.autocrlf = true`) e o CI roda em Linux:
sem essa normalização o mesmo conteúdo daria dois digests e o portão reprovaria
por causa do sistema operacional. CR solto continua entrando no hash. A
implementação é Dart puro (`app/test/gates/sha256_puro.dart`) — `package:crypto`
só existe no scaffold como dependência **transitiva**, e importá-lo acenderia
`depend_on_referenced_packages` e amarraria o portão a uma árvore que ninguém
fixou. Ela foi conferida contra `sha256sum` nos vetores `""`, `"abc"` e um
milhão de `a`.

### As três coisas conferidas, e por que são três

| camada | onde vive | o que garante |
| ------ | --------- | ------------- |
| DECLARAÇÃO | `gates_bot.txt` | o que o repositório promete rodar |
| ARQUIVO | sha256 conferido pela TRAVA e pelo passo do CI | que o que está no disco é o que foi declarado |
| EVIDÊNCIA | `build/evidencia_gate_batida.json`, escrito pela própria suíte | que o passo **executou nesta build**, com o corpus inteiro e resultado reprodutível |

Declaração sem execução é promessa; execução sem declaração é acaso.

### Onde a guarda mora — e por que não mora dentro do alvo

A TRAVA está em `app/test/teste_motor.dart`, que é o portão **obrigatório** do
CI. Ela importa a suíte do portão **com prefixo e de verdade**:

```dart
import 'gate_batida_bot.dart' as gate;
```

e lê as constantes compiladas (`gate.kSementesGate`, `gate.kPisosGate`, …). Um
`File(...).existsSync()` no lugar disso seria mais frouxo — daria para
satisfazê-lo com um arquivo vazio. Assim, **apagar a suíte quebra a compilação
do portão obrigatório**, e ele fica vermelho antes de rodar um único caso.

O sentido inverso é fechado por `GBB-13`: a suíte do portão exige que a TRAVA
continue em `teste_motor.dart`, com o import, o grupo, os dez casos e a
referência a `File(gate.kArquivoEvidencia)`. Nenhuma das duas metades some
sozinha em silêncio.

### O passo do CI

`.github/workflows/build.yml` ganhou um passo **antes** do portão do motor. Ele
não tem comando próprio: lê o `executor` da fonte única e roda o que estiver
declarado — depois de conferir que a suíte existe, que o executor é um
`flutter test` que aponta para a suíte declarada, que o sha256 bate, que os
sete valores de `exige` não foram afrouxados, que `provas` bate com a lista de
`casos`, que cada caso declarado existe de fato no arquivo e que o número de
`test(` do arquivo é igual a `provas`. Só então executa, e no fim exige que a
evidência tenha sido escrita.

### Cenário a cenário

| a OS exige reprovar se… | quem reprova |
| ----------------------- | ------------ |
| a suíte desaparecer | compilação de `teste_motor.dart` (import direto) + `-f` no passo do CI |
| o passo não executar | `TRAVA-07/08/09` — sem evidência, o portão obrigatório fica vermelho |
| o corpus for reduzido | `TRAVA-04` (constante compilada) + `TRAVA-09` (o que a evidência realmente jogou) + `PARTIDAS>=26` no passo do CI |
| uma modalidade for retirada | `TRAVA-04` + `TRAVA-09` + `MODALIDADES>=3` no passo do CI |
| os pisos forem diminuídos | `TRAVA-04` (na suíte) + `TRAVA-05` (na fonte única) + a lista de mínimos do passo do CI — **três arquivos, três reprovações independentes** |
| o corpo for trivializado | sha256 em `TRAVA-03` e no passo do CI + `TRAVA-06` (casos e contagem de `test(`) |
| o resultado não for determinístico | `GBB-11` (a suíte reprova na hora) + `TRAVA-08` (a evidência carrega `determinismo`) |

Os pisos aparecem em três arquivos de propósito. Uma "fonte única" de piso que
também fosse o único lugar a conferi-lo não protegeria piso nenhum: bastaria
editá-la. Aqui, baixar um piso exige três edições coordenadas, e cada uma delas
reprova sozinha — como as sabotagens S03, S05 e S08 da §7 mostram.

---

## 7. Provas negativas

Três campanhas, porque há três coisas diferentes a provar: que o **passo do CI**
reprova, que a **TRAVA** reprova, e que o portão fica vermelho quando o **bot**
perde a capacidade. Toda campanha tem CONTROLE — sem ele, uma trava que reprova
tudo passaria por "detectou".

### 7.1 O passo do CI — 11 de 11

O corpo do passo é **extraído do `build.yml`** e executado de verdade; só a
chamada do `flutter` é simulada. Não é uma paráfrase do passo: é o passo.

| # | cenário | veredito | mensagem do passo |
| - | ------- | -------- | ----------------- |
| W00 | **CONTROLE** (árvore íntegra) | **PASSOU** | — |
| W01 | a suíte declarada é apagada | REPROVOU | `a suíte declarada na fonte única não existe` |
| W02 | a fonte única é apagada | REPROVOU | `fonte única dos portões do bot não encontrada` |
| W03 | o corpo muda e o sha256 não é atualizado | REPROVOU | `o sha256 da suíte não confere com a fonte única` |
| W04 | piso afrouxado (`TOTAL>=60` → `>=10`) | REPROVOU | `exigência 'TOTAL' AFROUXADA na fonte única: 10 < 60` |
| W05 | exigência removida (`STBL>=16` some) | REPROVOU | `a fonte única deixou de exigir 'STBL'` |
| W06 | `executor` apontando para outra suíte | REPROVOU | `o executor declarado não roda a suíte declarada` |
| W07 | atributo `suite:` movido para a MARGEM | REPROVOU | `não declara o atributo obrigatório 'suite'` |
| W08 | um caso declarado some da suíte | REPROVOU | `o caso GBB-13 é declarado na fonte única e não existe na suíte` |
| W09 | corpo trivializado (stub de 1 teste), **com o sha256 atualizado** | REPROVOU | `o caso GBB-02 é declarado na fonte única e não existe na suíte` |
| W10 | `provas` discordando de `casos` | REPROVOU | `a entrada declara provas=4 e lista 13 casos` |

### 7.2 A TRAVA — 16 de 16

Cada cenário é aplicado sobre uma cópia limpa da árvore e medido rodando só o
grupo `TRAVA` de `teste_motor.dart`. **Nos cenários 03, 04 e 05 o sabotador é
CUIDADOSO: ele edita a suíte e ATUALIZA o sha256 da fonte única.** É o teste
que importa — com o sha em dia, o vermelho tem de vir das asserções de
conteúdo, não do digest.

| # | cenário | veredito | o que reprovou |
| - | ------- | -------- | -------------- |
| S00 | **CONTROLE** | **VERDE** (10/10) | — |
| S01 | a suíte é apagada | VERMELHO | **não compila**: `Error when reading 'test/gate_batida_bot.dart'` + `Undefined name 'kEntradaFonteUnica'` |
| S02 | o passo não executou (evidência ausente) | VERMELHO | TRAVA-07/08/09 · `EVIDÊNCIA ausente: o passo do portão de batida NÃO EXECUTOU` |
| S03 | corpus do ABERTO 10 → 4 sementes, **sha atualizado** | VERMELHO | TRAVA-04 · `Expected: >= <10> Actual: <4>` (+TRAVA-09) |
| S04 | modalidade STBL retirada, **sha atualizado** | VERMELHO | TRAVA-04 · `Expected: ['ABERTO','FECHADO','STBL'] Actual: ['ABERTO','FECHADO']` |
| S05 | piso do FECHADO 25 → 3 na suíte, **sha atualizado** | VERMELHO | TRAVA-04/05 · `Expected: >= <25> Actual: <3>` |
| S06a | uma linha a mais no corpo, sha NÃO atualizado | VERMELHO | TRAVA-03 · digest divergente |
| S06b | corpo trivializado (stub de 1 teste) | VERMELHO | **não compila** (as constantes somem) |
| S07 | evidência com `determinismo: false` | VERMELHO | TRAVA-08 · `Expected: true Actual: <false>` |
| S08 | `TOTAL>=60` → `>=10` na fonte única | VERMELHO | TRAVA-05 · `Expected: >= <60> Actual: <10>` |
| S09 | evidência produzida por outra suíte | VERMELHO | TRAVA-07 · `sha256Suite` divergente |
| S10 | evidência com FECHADO = 3 batidas | VERMELHO | TRAVA-08 · `Expected: >= <25> Actual: <3>` |
| S11 | atributo `suite:` na MARGEM da fonte única | VERMELHO | 5 casos (o leitor recusa a fonte única inteira) |
| S12 | partição batida/esgotamento quebrada | VERMELHO | TRAVA-08 · `Expected: <999999> Actual: <100>` |
| S13 | `executor` apontando para outra suíte | VERMELHO | TRAVA-01 · `Expected: contains 'test/gate_batida_bot.dart'` |
| S14 | a TRAVA é removida de `teste_motor.dart` | VERMELHO | **GBB-13** (a outra metade da proteção) |
| S15 | **CONTROLE do GBB-13** (árvore íntegra) | **VERDE** | — |

Os dois cenários que fecham o par são o **S01** e o **S14**: apagar a suíte
reprova pelo portão obrigatório, apagar a guarda reprova pela suíte.

### 7.3 A capacidade de batida — o alvo é o BOT, não a trava

Aqui o defeito é injetado no `lib/`, e o que se mede é a queda das batidas
legais. A amostra é **reduzida de propósito** (Fechado e STBL sementes 1–3,
Aberto sementes 3–5 — 24 batidas no controle contra 65 no corpus inteiro),
porque o corpus completo custa dezenas de minutos por cenário. O que a amostra
prova é a QUEDA; a §7.5 mostra o corpus inteiro reprovando de verdade num dos
cenários.

Cada mutação é aplicada por `sed` e **abortada se a âncora não casar** — uma
mutação que não pega transforma "sobreviveu" em falso negativo de cobertura.

| # | defeito injetado | ABERTO | FECHADO | STBL | total |
| - | ---------------- | ------ | ------- | ---- | ----- |
| C00 | **CONTROLE** | 7 | 10 | 7 | **24** |
| C01 | `pesos.batida` 160 → 0 (o bot deixa de valorizar fechar) | 4 | 5 | 4 | **13** |
| C02 | `canastraLiberaBatida` sempre `false` (a regra de batida quebra) | **0** | **0** | **0** | **0** |
| C03 | `batidaPrematura()` sempre `true` (a prudência passa a adiar sempre) | **0** | 1 | 3 | **4** |

C02 e C03 colapsam a capacidade e reprovariam qualquer piso. C01 corta 46% das
batidas — e é o cenário mais realista dos três, porque é o que uma
recalibração distraída produziria. Ver §7.5.

### 7.4 O que a primeira medição pegou — e que não era defeito

A primeira execução do portão sobre o corpus completo acusou **2 divergências
plano × ação**, e as duas eram o mesmo evento: `STBL / semente 4 / rodada 0 /
assento 3`. A investigação (diagnóstico dirigido sobre as oito sementes do
STBL) devolveu isto:

```
[DIV-ACAO] STBL/4 rod=0 assento=3 dupla=eles razao=COMPRA_LIXO_ESTRUTURA
           orc={motivo: buscaCompleta, transacoesLixo: 32, planosAvaliados: 18}
```

O robô comprou o lixo com **uso atômico do topo**, e a baixada exigida por essa
compra consumiu a mão inteira. A autoridade estabilizou o turno em **batida**,
ainda na fase de COMPRA. A decisão dizia `COMPRA_LIXO_ESTRUTURA` porque a
decisão foi comprar — e comprar foi exatamente o que se aplicou.

**Não havia divergência nenhuma.** Havia uma origem de batida que a medição não
conhecia, e uma medição que confundia "a razão não diz batida" com "aconteceu
outra coisa". As duas contagens vinham do mesmo evento: uma pela razão fora do
esperado, outra pela ausência da feature `batida` (que só existe em plano de
turno).

A correção não foi afrouxar a asserção. O vocabulário de razões que podem
produzir batida passou a ser **explícito e fechado** —
`BAIXA_BATIDA` para o plano de turno, `COMPRA_LIXO_ESTRUTURA` e
`COMPRA_LIXO_VOLUME` para a compra —, a suíte passou a contar as duas origens
separadamente e a exigir que a soma feche com o total, e qualquer razão fora do
vocabulário continua sendo divergência. A `TRAVA-08` confere o mesmo pela
evidência, inclusive que o vocabulário da compra não cresceu.

Vale registrar que essa batida **passou por toda a checagem de habilitação**:
morto cumprido e canastra que libera, conferidos pela função canônica. Ela é
capacidade real do bot, e está contada no piso.

### 7.5 O corpus INTEIRO reprovando

Amostra reduzida prova tendência; o portão precisa provar que **ele** reprova.
O cenário C01 (`pesos.batida` de 160 para 0 — uma recalibração distraída) foi
rodado contra o **corpus completo**, com a suíte de verdade:

```
GBB-04 [E]  Expected: >= <12>   Actual: <11>   ABERTO: 11 batidas legais, piso 12
GBB-05 [E]  Expected: >= <25>   Actual: <10>   FECHADO: 10 batidas legais, piso 25
GBB-06 [E]  Expected: >= <16>   Actual: <12>   STBL: 12 batidas legais, piso 16
GBB-07 [E]  Expected: >= <60>   Actual: <33>   total: 33 batidas legais, piso 60
GBB-08 [E]  Expected: [160.0]   Actual: [0.0]
GBB-12 [E]  Expected: <160.0>   Actual: <0.0>
```

| modalidade | íntegro | com `batida = 0` | piso |
| ---------- | ------- | ---------------- | ---- |
| ABERTO | 17 | **11** | 12 |
| FECHADO | 27 | **10** | 25 |
| STBL | 21 | **12** | 16 |
| **TOTAL** | **65** | **33** | 60 |

Seis dos treze casos reprovam, e os quatro pisos caem juntos. É a prova de que
o portão faz o que a OS pede: **fica vermelho se o bot perder a capacidade real
de bater legalmente.**

Repare que o Aberto cai de 17 para 11 — a margem de +5 não era gordura.

---

## 8. Custo — e a troca que ele impõe

Este é o ponto que eu levantaria com a Sônia antes de qualquer outro.

Medido nesta máquina, com a suíte rodando **sozinha** (ver §10.8 sobre as
medições contaminadas que não valem):

| passo | tempo |
| ----- | ----- |
| `PORTÃO DE BATIDA` — 26 partidas × 2 execuções, 5.072 turnos cada | **9 min 55 s** |
| `PORTÃO DE QUALIDADE` — a suíte do motor, 489 casos | 1 min 07 s |
| **acréscimo ao build** | **≈ 10 minutos** |

Dez minutos em toda build de APK. Não é catastrófico — o build Android já
custa mais que isso —, mas é **dez vezes** o portão que existia, e é bom que
isso esteja escrito antes de alguém descobrir por acidente.

### Por que custa isso, e por que não dá para cortar muito

O corpus é **quase mínimo para os pisos da OS**. As medições que o
dimensionaram:

| modalidade | batidas acumuladas por bloco de sementes | piso |
| ---------- | ---------------------------------------- | ---- |
| ABERTO | 1..6 = 11 · 1..8 = 13 · 1..9 = 15 · **1..10 = 17** | 12 |
| FECHADO | **1..8 = 27** | 25 |
| STBL | **1..8 = 21** | 16 |

O Aberto é o gargalo, e por uma razão de REGRA, não de implementação: lá (como
no STBL) só canastra **LIMPA** libera a batida, e as duplas do bot chegam a ela
com muito menos frequência do que chegam à canastra suja que o Fechado aceita.
O resultado é que o Aberto precisa de mais partidas para render menos batidas —
e as partidas dele são as mais longas, porque a rodada que ninguém fecha
consome o baralho inteiro.

Cortar o bloco do Aberto para 8 sementes economizaria pouco tempo e deixaria a
margem em **1** batida. Não vale.

### O que dobra o custo

A exigência de **duas execuções idênticas**. O corpus é medido inteiro, duas
vezes, no mesmo processo. É o que a OS pede, e é o que prova que a contagem não
depende de ordem de iteração nem de relógio — mas metade do custo do portão
está aí.

### Recomendação

O portão está ligado no `build.yml` como a OS manda. Se o tempo de build virar
problema, a conversa a ter é sobre **onde** ele roda, não sobre encolher o
corpus: mover o passo para um workflow próprio, disparado por agenda ou por PR,
preserva o piso e tira o custo do caminho do APK. Encolher o corpus, baixar
piso ou rodar uma execução só devolve o portão ao estado que ele existe para
corrigir — e as travas da §6 reprovam as três coisas.

---

## 9. Escopo e limites

Arquivos tocados:

```
app/test/gate_batida_bot.dart          novo         a suíte do portão
app/test/gates/gates_bot.txt           novo         a fonte única
app/test/gates/leitor_fonte_unica.dart novo         o leitor (margem x indentação)
app/test/gates/sha256_puro.dart        novo         SHA-256 sem dependência
app/test/teste_motor.dart              modificado   +TRAVA-01..10 (só inserções)
.github/workflows/build.yml            modificado   +1 passo (só inserções)
RELATORIO-GATE-BATIDA-NATURAL-BOT-V1.md novo        este relatório
```

**Nenhum arquivo de `app/lib/` foi tocado.** Confirmado por
`git show --stat 7c7d58e`: 1.649 inserções, **0 remoções**, e as duas
modificações (`teste_motor.dart` +343, `build.yml` +133) são puramente
aditivas.

O que a OS proibiu alterar, e não foi alterado:

| limite da OS | prova |
| ------------ | ----- |
| pesos do avaliador | `app/lib/bot/pesos.dart` intocado; `TRAVA-10` fixa `batida = 160` e `batidaPrematura = 300` |
| regra de batida | `app/lib/rules/morto/morto.dart` intocado; o portão **consulta** `duplaPodeBater`, não reimplementa |
| motor | `app/lib/mesa.dart` e `app/lib/motor/` intocados |
| prudência | `prudenciaBatida` continua `true` por padrão, e a medição a usa ligada |
| bot do servidor | esta linhagem não contém servidor; nada em `auditoria/conformidade/` foi tocado |
| contrato de encerramento | `rules/` intocado |
| comportamento padrão de produção | `ConfiguracaoBot.v2` intocada; o fusível de produção segue em 5000 ms, e `TRAVA-10` reprova se mudar |

A configuração de medição é construída **em tempo de teste**, por
`comLimites(...)` sobre `ConfiguracaoBot.v2`. Ela não existe em produção e não
é alcançável pelo app.

---

## 10. Riscos residuais

1. **O custo é o risco principal.** Ver §8. É a única coisa desta entrega que
   eu recomendaria a Sônia rever antes de ligar o portão em toda build.

2. **O determinismo é provado DENTRO de um processo.** As duas execuções da
   `GBB-11` rodam no mesmo isolate, então elas compartilham a semente de hash
   de `String` do Dart — que é aleatória **por isolate**. Uma dependência de
   `hashCode` na ordenação passaria despercebida por elas. Mitiga isto o fato
   de a ordenação do bot ser por assinatura semântica (auditado na OS 4,
   `ORC-06`), e a conferência manual registrada na §5 de que
   dois PROCESSOS independentes produziram o mesmo digest. Fechar isso de vez
   exigiria rodar o executor duas vezes no CI e comparar as evidências — o que
   dobraria de novo o custo.

3. **O portão é um PISO, não um teto.** Ele reprova o bot que perde a
   capacidade de bater; não reprova o bot que passa a bater cedo demais. A
   prudência (`batidaPrematura`) continua sendo protegida só pelos testes
   unitários da OS de inteligência.

4. **O corpus é de 26 partidas e 3 modalidades.** Uma regressão que só
   aparecesse fora dessas sementes não seria vista. Aumentar o corpus melhora a
   cobertura e piora o custo, na mesma proporção.

5. **A evidência é confiável DENTRO do job.** Ela prova que o passo executou
   nesta build; ela não se defende de um workflow que a escrevesse à mão. Isso
   está fora do modelo de ameaça que a OS enumera (que é a erosão do portão,
   não a fraude deliberada de quem edita o CI).

6. **As duas metades da proteção podem ser removidas JUNTAS.** Apagar a suíte
   sozinha reprova (compilação), apagar a TRAVA sozinha reprova (`GBB-13`),
   apagar o passo sozinho reprova (evidência ausente). Apagar os três ao mesmo
   tempo não é detectável por dentro — nenhum portão auto-hospedado é.

7. **Este portão nunca rodou no GitHub Actions.** O `build.yml` desta linhagem
   dispara em `push` para `main`/`master`/`codex/inicio-ui` e em
   `workflow_dispatch`; a branch desta OS não é nenhuma delas e não houve PR,
   merge nem dispatch. O passo foi exercitado **localmente**, com o corpo
   extraído do próprio arquivo (§7.1), mas a primeira execução real dele será a
   primeira build que o alcançar.

8. **A máquina de medição desta sessão estava sob pressão.** Três execuções do
   portão morreram sem mensagem (o isolate do `flutter_test` sendo derrubado,
   com ~2,4 GB livres e outras sessões ativas na mesma máquina). Isso não é
   defeito da suíte — a execução que completou é íntegra e reprodutível —, mas
   é um aviso: num runner apertado, o portão pode falhar por ambiente, e a
   mensagem não vai dizer isso.

---

## 11. Veredito

### Suítes e analyzer

```
portão de batida (novo):   13/13 verdes   ·  9 min 55 s
portão do motor:          489/489 verdes  ·  1 min 07 s   (479 da base + 10 da TRAVA)
analyzer:                 115 diagnósticos — o MESMO da base, 0 novos, 0 perdidos
regressões:               0
```

A base foi medida no mesmo overlay, a partir de `d3effdc` puro: **479** casos e
**115** diagnósticos.

### Condição a condição

| exigência da OS | resultado |
| --------------- | --------- |
| partidas reais de 108 cartas | 26 partidas, 100 rodadas, 5.072 turnos, integridade conferida pelo motor a cada jogada |
| sementes fixas | blocos contíguos 1–10 / 1–8 / 1–8, constantes de compilação |
| Aberto, Fechado e STBL | as três, e `TRAVA-04` reprova a retirada de qualquer uma |
| regras canônicas de produção | `MotorConfig.producao()`, autoridade canônica em todas as jogadas |
| prudência de batida ligada | `prudenciaBatida: true` (`GBB-02`) |
| nenhum estado fabricado | zero fixtures: todo estado vem de partida jogada |
| fusível desligado só na medição | `GBB-03`: medição 0 ms, produção 5000 ms |
| teto determinístico preservado | 6000 / 2000 / 4000, lidos de `ConfiguracaoBot.v2` |
| duas execuções idênticas | mesmo digest — e também entre PROCESSOS distintos |
| ABERTO ≥ 12 | **17** |
| FECHADO ≥ 25 | **27** |
| STBL ≥ 16 | **21** |
| TOTAL ≥ 60 | **65** |
| ≥ 1 `BAIXA_BATIDA` por modalidade | 17 · 27 · 20 |
| feature `batida = 160` | valores distintos: `[160.0]` |
| zero divergência plano × ação | **0** |
| zero batida sem morto/canastra | **0** |
| esgotamento nunca contado como batida | 35 à parte; partição fecha em 100 |
| zero decisão vazia | **0** |
| zero falha de integridade | **0** |
| fonte única com suite/executor/sha256/provas/casos/exige | as seis chaves, e o leitor reprova fechado |
| reprovar se a suíte sumir | S01 · W01 |
| reprovar se o passo não executar | S02 |
| reprovar se o corpus for reduzido | S03 · W-`PARTIDAS` |
| reprovar se uma modalidade for retirada | S04 · W05 |
| reprovar se os pisos forem diminuídos | S05 · S08 · S10 · W04 |
| reprovar se o corpo for trivializado | S06a · S06b · W03 · W09 |
| reprovar se o resultado não for determinístico | S07 |

### E os limites

Nenhum peso do avaliador, nenhuma regra de batida, nenhuma linha do motor,
nenhuma linha do bot e nenhum comportamento padrão de produção foram alterados.
O commit `7c7d58e` é de **1.649 inserções e 0 remoções**, em seis arquivos —
quatro novos e dois modificados só por acréscimo (`build.yml` +133,
`teste_motor.dart` +343). Nenhum deles em `app/lib/`.

E o digest confere do lado do CI: o BLOB do git (que é o que o runner Linux
recebe no checkout) tem sha256
`5fd39ab4c4691e02b0419a140809292dce5acd66624bac6964f6d12baf98291c`, idêntico ao
declarado na fonte única.

---

**`PASS — CAPACIDADE DE BATIDA DO BOT DART PROTEGIDA E REPRODUZÍVEL`**

Com duas coisas ditas em voz alta, porque um PASS que esconde o preço não
serve: o portão custa **≈ 10 minutos** em toda build (§8), e ele **ainda não
rodou no GitHub Actions** — o `build.yml` desta linhagem só dispara em
`main`/`master`/`codex/inicio-ui` ou por dispatch, e esta OS não fez merge, PR
nem deploy (§10.7). O passo foi exercitado localmente com o corpo extraído do
próprio arquivo, e reprovou em 11 de 11 sabotagens.
