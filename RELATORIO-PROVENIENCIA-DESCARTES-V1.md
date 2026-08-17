# RELATÓRIO — PROVENIÊNCIA PÚBLICA CANÔNICA DE DESCARTES V1

**VEREDITO: PASS**

O bot passa a afirmar "meu parceiro descartou esta carta" porque a autoridade
registrou que ele descartou — não porque o bot tentou adivinhar.

---

## 1. Base herdada da OS 1 (§2)

| item | valor |
| ---- | ----- |
| branch da OS 1 | `claude/garantia-encerramento-turno-v1` |
| SHA remoto | `f41eea0e1143f4b2e572a8a7105cbea8aea755f3` |
| SHA local | `f41eea0e1143f4b2e572a8a7105cbea8aea755f3` |
| local == remoto | **SIM** — `git ls-remote origin refs/heads/claude/garantia-encerramento-turno-v1` responde `f41eea0`, consulta ao servidor |
| veredito da OS 1 | **PASS** (`RELATORIO-ENCERRAMENTO-TURNO-V1.md`, §13 com os 19 critérios marcados) |
| `git merge-base HEAD f41eea0` | `f41eea0` — a base é ancestral direto, sem divergência |

### Genealogia

```
origin/auditoria/regras-bmv (88d12ac)          C10 rev.3, publicado
  └─ 7 commits da OS de Inteligência do Bot V1
      └─ 89fca38                               referência FUNCIONAL desta OS
          └─ 5 commits da OS 1 (motor) + 2 de relatório
              └─ f41eea0                       ← BASE ADOTADA (HEAD PASS da OS 1)
                  └─ 5 commits desta OS
                      └─ a91dada               ← HEAD final
```

Verificado que `89fca38` é ancestral de `f41eea0` (`git merge-base --is-ancestor`
= verdadeiro): a base da OS 1 **contém** a entrega do bot, então esta OS herda as
duas coisas de que precisa sem compor branch nenhuma. `89fca38` **não** foi usada
como base — ela é referência funcional, como a própria OS determina.

O HEAD da OS 1 avançou de `c8b1ff9` (registrado no relatório dela) para
`f41eea0`; os dois commits a mais são **só documentação** (`1724e0d`, `f41eea0`
corroboram §12 do relatório com medições). Nenhuma linha de código entre um e
outro. A base adotada é a ponta remota, `f41eea0`.

Não se iniciou sobre `main` (`fb9edb5`, repositório placeholder) — o HEAD inicial
do worktree foi descartado com `git reset --hard f41eea0`.

---

## 2. Fonte de verdade (§5)

Cadeia auditada, do comando ao consumidor:

```
Descartar(id)
  → mesa.dart `descartar()`         roteia para a autoridade (canônicoAtivo)
  → autoridade_canonica.dart        projeta o Jogo, aplica em snapshot, comita
  → gerador.dart `_aplicar`         VALIDA e MUTA  ← A AUTORIA NASCE AQUI
  → EstadoJogo.descartes            estado canônico, append-only
  → projecao_estado.dart            round-trip exato Jogo ↔ EstadoJogo
  → modo_sombra.dart                serializa / desserializa / compara paridade
  → VisaoInformacao.doEstado        projeção pública, igual para todo assento
  → ModeloParceiro.parceiroDescartou   consumidor
```

**O ponto exato:** [`gerador.dart`](app/lib/rules/gerador/gerador.dart) — ramo
`Descartar`, imediatamente depois de `prox.lixo.add(carta)`. É o único lugar do
código em que a autoria é inequívoca: a ação é `Descartar`, o autor é o `assento`
que a autoridade acabou de validar, a carta é aquela. Um passo adiante a
informação já não existe — a pilha do lixo não diz quem pôs cada carta nela.

O registro é **atômico com a mutação**: acontece no clone (`cloneProfundo`), e
qualquer recusa posterior (esvaziamento ilegal, batida inválida, invariante da
OS 1) descarta o clone inteiro. Estado recusado não deixa registro órfão.

Nada é reconstruído depois. Não existe no código nenhuma derivação de autoria a
partir de índice da pilha, ordem de turnos ou contagem de mãos.

---

## 3. Modelo (§6)

```dart
class DescarteRegistrado {
  final CartaSnapshot carta;   // a carta que foi ao lixo (cópia imutável)
  final int assento;           // AUTOR — identidade canônica da mesa (0..3)
  final int ordem;             // carimbo temporal dentro da MÃO (0,1,2,...)
}

class EstadoJogo {
  ...
  final List<DescarteRegistrado> descartes;   // livro append-only da mão
}
```

**Autor = `assento`.** É a identidade que a projeção, o `Jogo` e o bot já usam.
UID, conta, perfil e apelido não entram: são identidade privada, e o contrato
público desta camada trabalha por assento (§6 e §20).

**`ordem` é monotônica a partir do último registro**, não derivada de `length` —
um consumidor pode recortar a lista sem que a sequência real se perca (§15).

**Onde o livro vive, e por quê.** Dentro do `EstadoJogo`, não no
`EnvelopeRuntime`. Campo que não está no estado canônico não atravessa
`aplicarLegal` e some no primeiro round-trip da autoridade — o envelope carrega o
que o canônico *não* modela, e proveniência pública é exatamente o oposto disso.

**Autoridade única da forma do registro:** `registrarDescarte(livro, carta,
assento)`. O caminho canônico e o caminho legado chamam a **mesma** função, então
não têm como divergir na autoria nem na ordem — e o modo sombra compara o
resultado (`_campos` ganhou a chave `descartes`).

Nenhum subsistema novo foi criado. Não há event stream canônico neste
repositório (o `Replay` grava ações, não eventos de estado), então o livro é o
**menor** modelo que responde à pergunta estratégica, e vive junto das outras
zonas do estado.

---

## 4. Política de histórico e compra do lixo (§7, §8)

**Semântica adotada: A — histórico acumulado da mão.**

Comprar o lixo esvazia a pilha e **não** apaga o livro. A carta deixou de estar no
lixo; não deixou de ter sido descartada à vista de todos. Nenhuma linha de código
foi necessária para isso — a decisão foi *não* limpar, e ela está testada
(`PROV-04`: depois da compra o lixo tem 0 cartas e o livro mantém o registro; o
descarte seguinte continua a numeração em `ordem: 1`).

### Por que A, e por que isso não é memória perfeita ilimitada

A OS manda avaliar contra a semântica já adotada pelo jogo antes de dar memória
ao consumidor. O que foi verificado:

* O lixo **nasce vazio** (`_distribuir()` faz `lixo = []`) e recebe carta por um
  **único** caminho: o descarte. Não há carta virada na distribuição. Logo, toda
  carta da pilha passou pelo topo, à vista de todos, no instante em que foi
  descartada — **em qualquer modalidade**. O que o Fechado/SBTL proíbe é
  *folhear* a pilha agora, não ter visto o que passou por ela.
* O servidor de produção já publica a pilha **inteira** para todos os assentos e
  para quem assiste no ABERTO (`server.js`, campo `lixoAberto`, com o comentário
  "todo mundo leu o que passou por ela"). A informação não é nova nem secreta.
* O limite é a **MÃO** (§9). Não existe memória entre mãos, e não existe memória
  de zona oculta: monte, mortos e mãos alheias continuam sem campo na visão.

**Consequência estratégica, registrada de propósito:** depois de alguém comprar a
pilha, o livro continua dizendo quais cartas passaram por ela — ou seja, um
consumidor pode deduzir parte da mão de quem comprou. É a mesma dedução que um
humano com boa memória faz na mesa real, sobre eventos que ele presenciou. Não é
informação privada vazando: é informação pública sendo lembrada.

Isto **muda de propósito** uma fronteira que a OS de Bot IA V1 tinha declarado
(`VisaoInformacao` mascarava o lixo enterrado). A mudança está escrita no
cabeçalho de [`visao_informacao.dart`](app/lib/bot/visao_informacao.dart), com a
justificativa e os três limites que continuam valendo. O critério de PASS da OS
("humano e bot recebem a mesma verdade pública") não admitiria o contrário: dar
ao humano um fato e ao bot outro seria criar duas verdades públicas.

---

## 5. Política de nova mão (§9)

O livro morre com o lixo, em `_distribuir()`:

```dart
lixo = [];
descartes = [];
```

* histórico da mão anterior **desaparece**;
* não há histórico de partida — só de mão;
* o bot raciocina **por mão**, que é o escopo em que o sinal tem sentido (as
  cartas voltaram ao baralho; lembrar o que passou pelo lixo na mão passada não
  informa nada sobre a mão atual).

Provado em `PROV-05`: depois de `novaRodada()`, o livro está vazio e
`parceiroDescartou` volta a responder `false` para a carta da mão anterior. O
mínimo obrigatório do §9 — não atribuir descarte de mão anterior à mão corrente —
é cumprido por construção, não por filtro.

---

## 6. Reconexão (§12)

O caminho que um jogador reconectando percorre neste repositório é a projeção
reconstruída: `serializarProjecao` → texto → `desserializarProjecao` →
`aplicarEmJogo`. O livro atravessa os dois sentidos.

`PROV-06` prova que o estado reconstruído tem **a mesma** autoria (registro a
registro, e assinatura de estado idêntica), e que a `assinaturaPublica` da visão
dos **quatro** assentos é idêntica antes e depois da queda. Não existe o cenário
proibido "quem estava desde o início conhece a autoria, quem reconectou não".

`PROV-12` (Caso 4) repete a prova no nível do consumidor: o `ModeloParceiro`
construído a partir do snapshot responde exatamente o mesmo que o de antes.

---

## 7. Visões e privacidade (§13, §14, §20)

| visão | o que recebe |
| ----- | ------------ |
| próprio jogador | livro completo da mão: carta, assento autor, ordem |
| parceiro | **o mesmo** livro, byte a byte |
| adversário | **o mesmo** livro, byte a byte |
| recorte sem mão (`maoOculta`) | **o mesmo** livro; a mão própria é que some |
| conexão não autenticada / fora da sala | **nada** — esta OS não criou canal, não abriu permissão e não tocou em transporte |

`PROV-08` compara as quatro projeções de assento e o recorte sem mão contra a
mesma lista esperada. A visão **não** pré-calcula `foiDescartadoPeloParceiro`
(§10): ela entrega "quem descartou o quê", e o consumidor decide a relação —
`PROV-09` faz a conta pelos dois lados (parceiro e adversários) a partir do mesmo
fato canônico, sem API nova.

### O que a estrutura NÃO transporta

`PROV-10` inspeciona o registro serializado e exige que suas chaves sejam
exatamente `{carta, assento, ordem}`, que a forma da carta seja **idêntica** à que
o lixo já usa, e que o texto não contenha `uid`, `mao`, `monte`, `morto`,
`timestamp`, `razao` nem `plano`. Sem mão do autor, sem alternativas que ele
poderia ter descartado, sem carta comprada que não virou pública, sem estrutura
da decisão, sem raciocínio do bot, sem informação futura.

`PROV-11` prova o outro lado: dois estados que diferem **só** no oculto (mãos
alheias) continuam com a mesma assinatura pública, e dois estados com autorias
**diferentes** produzem assinaturas públicas diferentes — o campo participa de
verdade, não é decoração.

---

## 8. Integração com a Inteligência do Bot V1 (§17, §22)

`VisaoInformacao.descartesPublicos` deixou de ser entrada opcional vazia:
`doEstado` copia o livro da autoridade. O parâmetro que permitia **injetar**
autoria de fora foi **removido** — o único caminho passou a ser o registro
canônico, então não existe porta por onde uma autoria inventada entre (§18).

Os quatro casos exigidos, em `PROV-12` (e nos testes dedicados):

| caso | resultado |
| ---- | --------- |
| 1 — parceiro descartou uma carta pública | `parceiroDescartou` = **true** (`PROV-00b`) |
| 2 — adversário descartou a carta | **false**; e o registro do adversário guarda o assento dele (`PROV-03`) |
| 3 — carta no lixo sem autoria provável | **false**, por ausência de prova (`PROV-01`, e o estado forjado de `PROV-12`) |
| 4 — reconexão | resposta idêntica à de antes da queda (`PROV-06`, `PROV-12`) |

**Nada de estratégia foi tocado.** `pesos.dart` não aparece no diff. Nenhum
avaliador, nenhuma heurística e nenhum peso mudaram; o único consumidor do sinal
continua sendo `ModeloParceiro.parceiroDescartou`, que a camada de avaliação
ainda **não** chama — ligá-lo a uma decisão seria alteração de força de jogo, que
o §26 põe fora do escopo. O que mudou é que o método passou a responder a verdade.

### Prova empírica de que o robô joga igual

Sonda determinística fora do repositório: 3 modalidades × 2 sementes × 40 turnos
de robô canônico, comparando a assinatura do estado final (sem a linha nova de
proveniência) entre `f41eea0` e a entrega.

```
diff probe_base.txt probe_novo.txt  →  vazio
```

Estado final idêntico em todas as 6 partidas. Confirma o que a leitura do código
já dizia: a `assinaturaPublica` alimenta só `DecisaoBot.assinaturaDecisao`
(telemetria); o desempate determinístico usa `PlanoTurno.assinatura`, que não foi
tocada.

---

## 9. Compatibilidade (§16)

Evolução **aditiva**, sem virada de versão:

* `serializarEstado` ganhou a chave `descartes`;
* `desserializarEstado` lê `m['descartes'] as List? ?? const []` — snapshot
  gravado **antes** desta OS desserializa como livro **vazio**, isto é, autor
  desconhecido, jamais autoria reconstruída (`PROV-07`);
* nenhuma chave existente mudou de forma ou de significado;
* `Replay` continua reproduzível e com `snapshotCompleto` verdadeiro; a versão da
  spec (`bmv-regras-2026.08`) **não** mudou, porque legalidade nenhuma mudou.

Cliente antigo lendo snapshot novo ignora a chave que não conhece. Cliente novo
lendo snapshot antigo vê ausência de prova. Nenhum dos dois vê autoria errada.

**Nenhuma versão de protocolo foi alterada, silenciosamente ou não.**

---

## 10. Testes

Suíte oficial do portão, `app/test/teste_motor.dart`, executada como o CI a
executa (`flutter test test/teste_motor.dart`) num overlay limpo
(`flutter create` + `app/lib` + `app/test`), Flutter 3.41.4 / Dart 3.11.1.

```
base  (f41eea0):  430 testes  — All tests passed!
final (a91dada):  445 testes  — All tests passed!
novos:             15
regressões:         0
```

Nenhum teste antigo foi apagado, renomeado ou afrouxado.

### Cobertura do §19

| § | prova |
| - | ----- |
| 1 descarte simples com autoria | `PROV-00` |
| 2 quatro jogadores em ordem | `PROV-02` |
| 3 dois descartes iguais, autores diferentes | `PROV-03` |
| 4 compra do lixo | `PROV-04` |
| 5 novo descarte após a compra | `PROV-04` |
| 6 nova mão | `PROV-05` |
| 7 reconexão | `PROV-06`, `PROV-12` |
| 8 projeção do jogador | `PROV-08` |
| 9 projeção do adversário | `PROV-08`, `PROV-09` |
| 10 projeção de espectador | `PROV-08` (recorte sem mão — ver pendência 1) |
| 11 serialização | `PROV-06`, `PROV-10` |
| 12 desserialização | `PROV-06`, `PROV-07` |
| 13 versão/revisão da visão | `PROV-06` (snapshot do `Replay` versionado pela spec — ver pendência 2) |
| 14 integração do bot | `PROV-00b`, `PROV-12`, `PROV-13` |
| 15 ausência de vazamento privado | `PROV-10`, `PROV-11` |

`PROV-13` roda partidas completas do robô canônico em ABERTO e FECHADO e verifica
a cada turno que todo registro aponta para assento real, que `ordem` é
estritamente crescente e que o lixo **nunca** tem mais cartas do que o livro tem
registros. Com **não-vacuidade explícita** (≥10 descartes e ≥2 autores por
partida), para o invariante não passar por vazio.

### Não regressão da OS 1 (§21) e do bot (§22)

Os 430 testes da base continuam verdes, incluindo os 18 `ENC-*` da OS 1 (turno
morto, avanço da vez, mutação parcial, recusa consistente, varredura `ENC-12` e
`ENC-15`) e os 20 `BOTIA-*` + 10 `NV-*` da OS do bot. A proveniência não
reintroduziu nenhum dos quatro defeitos que a OS 1 fechou — o registro entra no
clone e morre junto com ele quando a ação é recusada.

---

## 11. Analyzer

```
base  (f41eea0): 118 issues, 3 errors
final (a91dada): 118 issues, 3 errors
delta introduzido pela OS: 0
```

Comparação linha a linha (`comm` sobre a saída ordenada, sem números de linha):
conjunto **idêntico**. Os 3 errors são ambientais e pré-existentes — API do
`google_sign_in` em `lib/main.dart`, resolvida pelo `pub add` do overlay em versão
diferente da que o CI fixa; não têm relação com esta OS e já estavam na base.

Uma issue nova chegou a aparecer (`avoid_renaming_method_parameters` no
`operator ==` do registro) e foi corrigida antes da entrega, e não tolerada.

---

## 12. Segurança (§20)

A estrutura nova transporta **três** coisas: a carta pública, o assento autor e a
ordem. Não transporta mão do autor, identificador privado, credencial, UID,
timestamp, raciocínio do bot, ação pretendida nem qualquer informação não
pública. Verificado por asserção sobre o payload serializado (`PROV-10`), não por
inspeção visual.

Nenhuma permissão foi ampliada, nenhum canal foi criado e nenhum endpoint foi
tocado. A informação acrescentada acompanha um fato que já era público na mesma
visão em que já era público.

---

## 13. Git

| item | valor |
| ---- | ----- |
| branch | `claude/proveniencia-descartes-v1-818916` |
| base | `f41eea0` (HEAD PASS remoto da OS 1) |
| HEAD final | `a91dada989d6f15d2a83cf44601fbaf38ace500a` |
| local == remoto | **SIM** (ver §14) |
| árvore | limpa |
| merges | **0** (`git log --merges f41eea0..HEAD` = vazio) |
| deploy | **nenhum** |
| force push / rebase | **nenhum** |
| `main` no remoto | `fb9edb5` — intocada |

A OS sugere o nome `claude/proveniencia-descartes-canonica-v1`. A branch entregue
é a do worktree, `claude/proveniencia-descartes-v1-818916` — mesmo trabalho,
nome diferente. Registrado para não confundir quem procurar pelo nome sugerido.

### Commits

| SHA | commit |
| --- | ------ |
| `3df48ed` | test: fixa o contrato ATUAL — descarte sem autoria registrada |
| `ced11af` | **feat: autoridade registra quem descartou cada carta** |
| `c2a3767` | feat: proveniência atravessa transporte, serialização e sombra |
| `a2cdfe2` | feat: o modelo do parceiro passa a receber a autoria real |
| `a91dada` | test: bateria da OS §19 — 15 provas e as regressões |

### Arquivos

```
app/lib/rules/estado.dart          +105 -4    modelo + livro + registro
app/lib/rules/gerador/gerador.dart   +9       onde a autoria nasce
app/lib/mesa.dart                  +21 -2     livro no runtime, nova mão, legado
app/lib/motor/projecao_estado.dart  +12       round-trip
app/lib/motor/modo_sombra.dart      +22       serialização + paridade
app/lib/bot/visao_informacao.dart   +71 -13   projeção pública
app/lib/bot/modelo_parceiro.dart    +24 -5    consumidor (só documentação e doc)
app/test/teste_motor.dart          +515       15 provas
```

`pesos.dart` não foi tocado. Nenhum avaliador foi tocado.

---

## 14. Critérios de PASS (§25)

- [x] Base é o HEAD aprovado da OS 1 (`f41eea0`, PASS, local == remoto)
- [x] Autoria nasce na autoridade (`gerador.dart`, ramo `Descartar`)
- [x] Nenhuma autoria é inferida heuristicamente (não há dedução no código; sem registro, o autor é desconhecido)
- [x] Carta e autor permanecem associados (compra do lixo, nova vez, reconexão, serialização)
- [x] Compra do lixo possui semântica definida (A — acumulado por mão, testado)
- [x] Nova mão não herda autoria indevida (`PROV-05`)
- [x] Reconexão mantém visão coerente (`PROV-06`)
- [x] Não há vazamento de informação privada (`PROV-10`, `PROV-11`)
- [x] Humano e bot recebem a mesma verdade pública (mesmo livro, mesma projeção)
- [x] Modelo do bot passa a receber a informação real (`PROV-00b`)
- [x] Pesos estratégicos não foram recalibrados (diff + sonda determinística)
- [x] Testes da OS 1 continuam verdes (430/430)
- [x] Testes relevantes do bot continuam verdes (`BOTIA-*`, `NV-*`)
- [x] Analyzer sem regressão nova (delta 0)
- [x] Local == remoto
- [x] Árvore limpa
- [x] Sem merge
- [x] Sem deploy
- [x] Relatório entregue

---

## 15. Pendências e achados registrados

1. **Servidor Node não tem proveniência — e é outro repositório.** A partida
   online é servida por `buraco-servidor` (`server.js`, HEAD `7e7572b`), que tem
   motor JS próprio. Auditado: `descartar()` empilha em `jogo.lixo` na linha
   2319 e **não** registra autor; `visaoDoAssento` e `visaoDoEspectador` mandam
   `lixoTopo` e, no ABERTO, `lixoAberto` — nunca autoria. O ponto de correção lá
   é do mesmo formato que o daqui: uma linha, no único lugar em que a carta vai
   ao lixo. **Não foi feito nesta OS por decisão de base:** o §2 fixa a base no
   HEAD PASS da OS 1, que é um SHA deste repositório; entregar no servidor exige
   uma base e uma branch que a OS não autorizou. Enquanto isso não for feito, a
   proveniência existe na partida local (que é onde o bot joga) e não na online.
2. **Visão versionada não existe nesta linhagem.** O contador de versão da visão
   (`versaoEstadoFinal`) vive em `claude/consumo-visao-versionada-flutter-v1` e no
   servidor, não em `f41eea0`. Aqui o versionamento disponível é o do `Replay`
   (`RuleSpec.versaoCanonica` + snapshot completo), e é sobre ele que `PROV-06`
   prova a participação da proveniência. Quando as duas linhagens forem
   compostas, conferir que o livro entra na visão versionada.
3. **Projeção de espectador não existe nesta base.** `visao_espectador.dart` é
   citado pelo servidor como contrato de referência do app, mas mora em
   `claude/spectator-view-server-enforcement-c154ee`. O que dá para provar aqui é
   que a proveniência não amplia permissão nenhuma: o recorte sem mão recebe
   exatamente o mesmo livro (`PROV-08`), e o livro só contém fato público
   (`PROV-10`).
4. **O sinal está ligado mas nenhuma decisão o consome.**
   `ModeloParceiro.parceiroDescartou` responde a verdade e não é chamado por
   nenhum avaliador. É deliberado — §17 manda não modificar estratégia além do
   necessário, e §26 põe calibração fora do escopo. Usar o sinal para decidir é
   trabalho de uma OS de força de jogo, com a comparação de partidas completas
   que a OS de Bot IA V1 deixou documentada.
5. **Fronteira de informação do bot mudou.** Registrado em §4 deste relatório e
   no cabeçalho de `visao_informacao.dart`: a visão passou a lembrar os descartes
   públicos da mão, inclusive os que já saíram da pilha. É decisão de projeto
   desta OS, não efeito colateral, e não muda nada hoje porque nenhum avaliador
   lê o campo (pendência 4).
</content>
