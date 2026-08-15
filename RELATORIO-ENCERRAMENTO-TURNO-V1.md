# RELATÓRIO — GARANTIA DE ENCERRAMENTO LEGAL DE TURNO V1

**VEREDITO: PASS**

---

## 1. Git

| item | valor |
| ---- | ----- |
| branch | `claude/garantia-encerramento-turno-v1` |
| base efetiva | `89fca3899aa680c303a0b227c051cb3b0a2d6b2a` |
| HEAD inicial (worktree) | `fb9edb5` — descartado, era o `main` placeholder |
| HEAD final | `c8b1ff9b6a4a98058def53f1012c1123d28a4147` |
| remoto | `origin/claude/garantia-encerramento-turno-v1` = `c8b1ff9` |
| local == remoto | **SIM** (`git ls-remote`, consulta ao servidor) |
| árvore | limpa (nenhum arquivo versionado modificado) |
| merges | **0** (`git log --merges 89fca38..HEAD` = vazio) |
| deploy | **nenhum** |
| `main` no remoto | `fb9edb5` — **intocada** |

### Escolha da base (genealogia, não nome de branch)

A OS cita a branch `claude/bot-ia-estrategica-v1` com HEAD `89fca38`. Verificado:

* `claude/bot-ia-estrategica-v1` (local) aponta **exatamente** para `89fca38`;
* `89fca38` **não existe em remoto nenhum** — a branch do bot nunca foi publicada;
* `89fca38` descende de `88d12ac` (C10 rev.3) por 7 commits do bot;
* `88d12ac` **é** o `origin/auditoria/regras-bmv` publicado.

**Divergência encontrada e resolvida.** O ref local `auditoria/regras-bmv` está em
`4e35594`, que **não contém** `88d12ac` — o ref local está *atrasado* em relação ao
remoto (`4e35594` é ancestral de `88d12ac`). Isto confirma a nota de que o par
branch+SHA das OSs diverge: **vale o SHA**. A cadeia adotada é, do publicado ao HEAD:

```
origin/auditoria/regras-bmv (88d12ac)
  └─ 7 commits da OS de Bot IA V1
      └─ 89fca38  ← BASE ADOTADA (HEAD citado pela OS)
          └─ 4 commits desta OS
              └─ c8b1ff9  ← HEAD final
```

Não se iniciou sobre `main` placeholder (`fb9edb5`).

### Commits

| SHA | commit |
| --- | ------ |
| `6b83355` | test: reproduz o beco sem saída do turno (C10-BOT-03) |
| `df581d9` | **fix: turno aceito tem de ter conclusão legal** |
| `5b1b7a0` | test: corrige fixtures que codificavam o beco + antes/depois do BOT-03 |
| `07387c9` | test: varredura de baralhos reais no regime em que o beco nasce |
| `c8b1ff9` | test: fronteira entre reasonCode e mensagem ao jogador |

Arquivos tocados: `app/lib/rules/gerador/gerador.dart`,
`app/lib/motor/autoridade_canonica.dart`, `app/test/teste_motor.dart`.
**`mesa.dart` não foi tocada.**

---

## 2. Reprodução (antes da correção)

### Estado inicial

Assento 0, fase de **jogo** (`jaComprou = true`), modalidade ABERTO.

| dimensão | valor |
| -------- | ----- |
| mão do assento 0 | `7c`(7♥) `8c`(8♥) `9c`(9♥) `orfa`(K♠) |
| jogos da dupla NOS | um meld de 3: `3♦ 4♦ 5♦` — **não é canastra** |
| jogos da dupla ELES | nenhum |
| morto disponível | **não** (`mortos = []`, `mortoPego = {nos:true, eles:true}`) |
| vulnerabilidade | não vulnerável; dupla **já abriu** (mínimo = 0) |
| parceiro / adversários | assento 2 / assentos 1 e 3 |
| monte | 1 carta | 
| lixo | 1 carta (`3♠`) |
| jogador da vez | 0 |

### Ação

`j.baixar(0, ['7c','8c','9c'])` — sequência 7-8-9 de copas, estruturalmente legal.

### Estado defeituoso observado na base (`89fca38`)

Saída literal da sonda executada sobre a base, antes de qualquer alteração:

```
--- BAIXAR -> {ok: true, tipo: aberta, tipos: [aberta]}
mao0=[orfa]
vez=0 rodadaEncerrada=false
jogosNos=[3, 3]
--- DESCARTAR orfa -> erro=descartar a última carta sem morto a pegar nem canastra para bater
mao0=[orfa] vez=0
--- ACOES LEGAIS = []
podeEsvaziarMao=false
fase=FaseTurno.jogo
```

Os seis pontos exigidos pela OS, confirmados:

1. a ação é **aceita** (`ok: true`);
2. sobra **1 carta** (`mao0=[orfa]`);
3. **não existe descarte legal** (recusa por regra);
4. **não ocorre batida válida** (sem canastra);
5. **não ocorre encerramento válido** (`rodadaEncerrada=false`);
6. **a vez não é transferida** (`vez=0`).

A definição de "morto" não é opinião do teste: é o **próprio gerador canônico**
devolvendo `ACOES LEGAIS = []` com a rodada aberta e a vez parada no assento.

### Teste vermelho antes da correção

O commit `6b83355` (só testes, sobre a base intacta) rodou:

```
+4 -11: Some tests failed.
```

**11 vermelhos e 4 verdes.** Os 4 que já passavam são exatamente os que provam
que a garantia **não pode** bloquear jogada legítima (ENC-02/03/04/05) — isto é,
o teste não foi escrito adaptado à solução. O varredor ENC-12 nomeou a ação
culpada:

```
beco: {tipo: baixar, jogosNovos: [[7c, 8c, 9c]], extensoes: []} deixou estado MORTO
```

---

## 3. Causa raiz

**Resposta à §6: alternativa (A), por uma causa estrutural (E) que a explica.**

O gerador único (`app/lib/rules/gerador/gerador.dart`) validava:

* a legalidade **imediata** da mutação (`avaliarBaixar`, fase, vez, mínimo); e
* **um único caso especial de continuação** — a regra "esvaziar a mão é regra",
  que só cobre `mão == 0`.

Nunca validava se o estado resultante **ainda podia concluir o turno**.

O beco real acontece em **`mão == 1`**. A baixada é legal, mas a carta que sobra
não tem descarte legal: descartá-la esvaziaria a mão, e esvaziar é ilegal sem
morto a pegar e sem canastra para bater. Restam zero ações — e a rodada segue
aberta com a vez parada.

`mão == 0` e `mão == 1` são **o mesmo defeito**: aceitar uma mutação sem
verificar se o turno ainda termina. O motor tinha a regra certa para o caso
particular e nenhuma para o caso geral.

Por que **não** era (B), (C) ou (D):

* **(B)** — não existe outro desfecho canônico disponível: sem canastra a batida
  é ilegal, e o morto já fora consumido. Não há para onde estabilizar.
* **(C)** — a regra de descarte está **correta**: no Buraco não se sai sem
  canastra. Relaxá-la quebraria a batida.
* **(D)** — morto e batida estão completos; ambos recusam corretamente. O
  problema é a mutação anterior que criou a situação.

### Achado adicional: o defeito estava nos fixtures, não só no C10-BOT-03

Oito testes do C7/C10 usavam o idioma **"carta guarda"**, com o comentário
`// sobra: a baixada NÃO zera a mão`, acreditando que sobrar 1 carta era seguro.
Sem morto e sem canastra, sobrar 1 carta **é** o beco. O comentário deixa ver o
modelo mental que causou o defeito: *"só `mão == 0` é perigoso"*. Os fixtures
codificavam o bug e o mantinham verde.

---

## 4. Correção

Implementada **na autoridade do jogo** — `aplicarLegal`, o gerador único que
jogador e robô consultam. Nenhuma linha de bot foi tocada; `pesos.dart` intacto.

### Invariante formal

```
Se uma ação autoritativa é aceita durante o turno,
o estado resultante deve permitir ao menos uma transição legal até:
  - descarte válido; ou
  - batida válida; ou
  - tomada do morto, quando aplicável; ou
  - encerramento da mão/partida; ou
  - próximo jogador conforme fluxo canônico.
```

`existeConclusaoLegalDoTurno(estado, assento, spec)` decide isso. Guarda as
**duas** mutações que reduzem a mão mantendo o turno com o mesmo assento:

* `Baixar` (jogos novos **e** extensões);
* `ComprarLixo` (a compra atômica do Fechado/STBL entra no mesmo beco pelo uso
  do topo — **estado morto adicional encontrado pela §12**).

### Terminação e completude (por que um nível basta)

A verificação avalia as continuações com o **próprio invariante desligado**,
portanto há exatamente **um nível** — não há recursão. Um nível é suficiente e
completo:

* `mão ≥ 2` → algum descarte é sempre legal; a questão nem se coloca;
* `mão == 1` → toda continuação possível **esvazia a mão**, e esvaziar já é
  decidido por `podeEsvaziarMao`/`avaliarBatida`, sem depender deste invariante;
* `mão == 0` → morto direto ou batida, idem.

**Jogada legítima preservada explicitamente:** a extensão em que a *última* carta
completa uma canastra torna a batida legal — o invariante reconhece esse caminho
e não o bloqueia.

### Efeito colateral corrigido: oferecido == aceito

Os derivadores de candidatos (`derivarCandidatosCompraLixoFechado` e
`derivarParticoesAbertura`) usavam `avaliarComprarLixo`/`avaliarBaixar` como
verificador final, que **não conhecem** o invariante. Sem correção, a mesa
ofereceria uma jogada que o motor recusaria em seguida — e, com candidato único,
o fluxo a executaria direto, entregando ao jogador uma recusa por uma jogada que
a própria mesa sugeriu. Ambos passaram a filtrar por `acaoEhLegal`.

---

## 5. Casos

| cenário | antes | depois | resultado |
| ------- | ----- | ------ | --------- |
| 1 — C10-BOT-03 (beco) | baixada **aceita**, 0 ações legais, vez parada | baixada **recusada**, estado intacto, descarte segue disponível | PASS |
| 2 — 1 carta, descarte legal (morto) | aceita | **aceita** (sem bloqueio falso) | PASS |
| 3 — 1 carta, batida válida | aceita | **aceita**; descarte final bate e encerra a rodada | PASS |
| 4 — 1 carta, morto aplicável | aceita | **aceita**; morto indireto ponta a ponta, vez passa | PASS |
| 5 — 2+ cartas restantes | aceita | **aceita** | PASS |
| 6 — curinga (`JOKER` e `2`) | aceita (beco) | **recusada**, estado intacto | PASS |
| 7 — vulnerável e não vulnerável | aceita (beco) | **recusada** em ambos; mínimo 80≥75 atingido não salva | PASS |
| 8 — ABERTO / FECHADO / STBL | aceita (beco) | **recusada** nas três; descarte normal segue nas três | PASS |
| 9 — rollback transacional | — | mão, mesa, lixo, monte, mortos, `mortoPego`, `primeiraBaixadaFeita`, vez e projeção **idênticos**; `falhasTecnicas` não incrementa | PASS |
| 10 — avanço de turno | — | descarte→assento seguinte; morto indireto→assento seguinte; batida→rodada encerrada; recusa→vez **não** se move | PASS |
| 11 — compra do lixo (§12) | aceita (beco) | **recusada**; candidatos oferecidos == aceitos | PASS |
| 12 — invariante varrido (fixtures) | 1 estado morto | **0** | PASS |
| 13 — paridade humano × robô | — | mesma autoridade; robô sem falha técnica e sem beco | PASS |
| 14 — gerador não oferece beco | oferecia | **não oferece** | PASS |
| 15 — varredura de baralhos reais | 6 achados | **0** | PASS |
| 16 — reasonCode × mensagem | — | canais separados, sem vazamento | PASS |

Modalidades: o motor é **o mesmo** nas três; nenhuma divergência foi introduzida.
A única diferença canônica pré-existente e não relacionada: trincas
(mesmo valor, naipes diferentes) só são meld válido no **FECHADO** — no
ABERTO/STBL o validador exige mesmo naipe. Registrado, não alterado.

---

## 6. Testes

Suíte oficial do portão: `app/test/teste_motor.dart`, executada como o CI a
executa (`flutter test test/teste_motor.dart`) num overlay limpo
(`flutter create` + `app/lib` + `app/test`), Flutter 3.41.4 / Dart 3.11.1.

```
base:  412 testes  (89fca38, todos verdes)
novos:  18 testes
final: 430 testes  — All tests passed!
```

**Nenhum teste antigo foi apagado ou afrouxado.** Os 412 originais continuam
presentes e verdes.

### As 8 regressões e o que foi feito

As 8 quedas foram todas fixtures que **codificavam o beco** (idioma "carta
guarda"). Corrigidos os **fixtures**, não as asserções: dar morto à dupla
devolve a saída legal que o cenário real teria, sem mexer em mão, mesa ou na
combinatória de candidatos/partições que cada teste mede.

| teste | fixture | correção |
| ----- | ------- | -------- |
| `TURNO-10` | `estadoTurno` inline | morto disponível |
| `FASE-04` | `estF` inline | morto disponível |
| `C10-LIXO-15` | `_jgLixoMonoAC10` / `B` | morto disponível |
| `C10-ISOLATE-01`, `C10-ABERTURA-05` | `_jgSelecaoAmbiguaC10` | morto disponível |
| `C10-ABERTURA-01`, `C10-ABERTURA-03` | `_jgAberturaMultiplaC10` | morto disponível |
| `C10-BOT-03` | `_jgBotAberturaCompostaC10` | morto disponível |

`C10-BOT-03` **manteve fixture, nome e asserção originais** e ganhou o par
`C10-BOT-03-BECO`, que preserva **literalmente** a forma histórica (sem morto,
sem canastra) para provar o antes/depois do caso nomeado na OS.

### Inteligência do Bot V1 (§14)

Os testes da OS de Bot IA rodam na mesma suíte e estão **todos verdes**,
incluindo os 20 `BOTIA-*` e as 10 provas de não-vacuidade `NV-*`. Verificado:

* `ExecutorBot` lida com a nova recusa sem falha técnica (`ENC-13`,
  `C10-BOT-03-BECO`: `falhasTecnicas` não incrementa, partida não pausa);
* `GeradorPlanos` não entra em loop — `BOTIA-20` (60 turnos) segue verde com a
  guarda de progresso intacta;
* plano tornado ilegal **desaparece** do conjunto oferecido (`ENC-14`);
* reasonCodes do bot permanecem coerentes (`NV-01..NV-10` verdes);
* fallback legado continua operacional (rollback não foi tocado).

**Pesos não foram recalibrados.** `pesos.dart` não aparece no diff.

---

## 7. Analyzer / lint

```
base  (89fca38): 115 issues, 0 errors
final (c8b1ff9): 115 issues, 0 errors
delta introduzido pela OS: 0
```

(Medido no mesmo overlay, descartando o `widget_test.dart` que o
`flutter create` gera e que não pertence ao repositório.)

---

## 8. Busca por estados mortos adicionais (§12)

### Caminhos examinados

Todas as operações do motor foram auditadas quanto a "aceita, muta, e deixa sem
saída": `baixar`, `estender` (é `Baixar` com `extensoes`), `comprarLixo`,
`comprarMonte`, `pegarMorto` (direto e indireto), `bater`, `descartar`.

* **`Baixar` / `estender`** — beco confirmado. Corrigido.
* **`ComprarLixo`** — **beco adicional encontrado**: a compra atômica consome a
  mão no uso do topo e pode deixar 1 carta órfã. Corrigido pela mesma regra.
* **`ComprarMonte`** — só aumenta a mão; não pode criar beco.
* **`PegarMorto`** — entrega 11 cartas; não pode criar beco.
* **`Bater`** / **`Descartar`** — encerram o turno por construção; já guardados
  pela regra de esvaziamento.

### Varredura property-like sobre baralhos REAIS

Partindo de baralhos reais, caminhando por ações legais sorteadas e enumerando
**exaustivamente** em cada estado todo subconjunto da mão como jogo novo, toda
extensão de até 3 cartas em cada jogo exposto das duas duplas, e todas as ações
de base.

O **regime** foi decisivo. Registrado porque quase custou a conclusão errada:

| regime | ações avaliadas | achados (guarda ligada) |
| ------ | --------------- | ----------------------- |
| baralho recém-distribuído | 9.665.031 | 0 — **e 0 também com a guarda desligada** |
| dois mortos já consumidos | — | ver abaixo |

Com morto ainda por pegar, esvaziar é sempre legal e o beco **não nasce**: uma
varredura "do início" passa longe da região de interesse e não prova nada. A
varredura útil é a que começa com os dois mortos consumidos.

**Não-vacuidade medida** (3 modalidades × 25 sementes × 60 passos, ambos os
regimes):

| guarda | estados | ações avaliadas | aceitas | achados |
| ------ | ------- | --------------- | ------- | ------- |
| **desligada** | 8.958 | 19.220.644 | 72.479 | **6** |
| **ligada** | 9.000 | 19.303.702 | 72.850 | **0** |

Os 6 achados com a guarda desligada incluem um passeio que chegou a um estado
**sem nenhuma ação legal** (`ABERTO/24/17`) e um beco alcançado por **extensão**,
não por jogo novo — confirmando que a guarda precisava cobrir os dois.

A versão no portão (`ENC-15`) é a mesma varredura em escala reduzida
(3 modalidades × 3 sementes × 18 passos), com piso de não-vacuidade nas ações
aceitas. Custo do portão: **~8s → ~19s**.

### Corroboração: partidas reais dirigidas pelo robô estratégico

Varredura longa, rodada fora do portão (87 min), com o motor já corrigido:
3 modalidades × 40 sementes × até 120 turnos, dirigida pelo **robô estratégico
real** (`botJoga`) e com enumeração **exaustiva** de candidatos em cada estado
visitado.

```
turnos jogados   = 6374
estados varridos = 6374
achados          = 0
```

Zero estados mortos, zero turnos que não progrediram, zero falhas técnicas.

Duas ressalvas, para a evidência não valer mais do que vale:

* é o regime **"início"** (baralho recém-distribuído), justamente aquele em que
  o beco quase não nasce porque o morto ainda está disponível. Serve como prova
  de **progresso e integridade sob jogo realista**, não como caça ao beco — essa
  continua sendo a tabela acima, no regime "dois mortos consumidos";
* o overlay foi alterado durante a execução para o experimento de não-vacuidade;
  o `flutter test` compila no início, então o binário exercitado é o do
  lançamento (motor corrigido), mas a medição não foi repetida para confirmar.

**Nenhum estado morto adicional permanece conhecido.**

---

## 9. Cliente (§17)

**Nenhuma UI nova foi criada.** `_baixarSelecao` já trata
`resultado['ok'] != true` exibindo `resultado['erro']` e tocando o som de erro;
a mensagem foi escrita para caber nesse canal existente:

> Essa jogada deixaria você sem uma forma válida de concluir o turno.

`ENC-16` prova que a mensagem não vaza o reasonCode, nem termos internos do
motor, nem qualquer carta da mão.

---

## 10. Observabilidade (§16)

reasonCode estável, sem informação privada (é constante — sem carta, sem mão,
sem assento):

```
acao_deixaria_turno_sem_conclusao_legal
```

Trafega em `ResultadoJogada.codigo` → `ResultadoAutoridade.codigo`, separado da
mensagem ao jogador. Distingue os três casos que a OS pede: ação genericamente
inválida (sem código), regra de jogo violada (sem código, motivo próprio) e
estado que resultaria sem conclusão legal (**com** código). A recusa é de
**REGRA**: não incrementa `falhasTecnicas`, não gera evidência de Replay e não
pausa a partida.

---

## 11. Segurança e autoridade (§18)

* cliente **não** decide legalidade — `MesaScreen` chama `_j.baixar(...)` e só
  exibe o resultado;
* robô **não** decide legalidade — propõe candidatos; `acaoEhLegal` filtra;
* heurística **não** decide legalidade — `pesos.dart` ordena preferência, nunca
  legalidade;
* autoridade única: `aplicarLegal`, no gerador canônico;
* nenhuma regra crítica foi duplicada em Flutter como fonte autoritativa — a
  correção mora inteira na camada de regras.

`ENC-13` prova a paridade pelos dois caminhos (humano e robô) na mesma mesa.

---

## 12. Pendências reais e achados fora da premissa

1. **Motor legado não foi corrigido.** Sob rollback explícito
   (`MotorConfig` com `canonicoAtivo = false`), o caminho legado de `mesa.dart`
   mantém o comportamento antigo e ainda admite o beco. Em produção o C10
   promoveu o canônico a padrão sem fallback, então o caminho não é alcançável
   normalmente. **Deixado fora por §19** (alterar só o necessário) e registrado
   aqui em vez de silenciado.

2. **O defeito estava nos fixtures do C7/C10, não só no C10-BOT-03.** Oito
   testes o codificavam via o idioma "carta guarda". Vale uma varredura por
   esse idioma em suítes fora do portão, se existirem.

3. **`_lixoUnicoCompradoId` não é modelado canonicamente.** A regra §5.2 do
   ABERTO ("comprou o lixo de uma carta só, não pode devolvê-la no mesmo turno")
   vive no envelope de runtime, fora do `EstadoJogo`. Em tese, uma mão de 1 carta
   que seja justamente essa carta é outro caminho de beco — **não** alcançável
   pelo canônico hoje, porque o canônico não aplica essa trava. Divergência
   legado × canônico pré-existente, **fora do escopo desta OS**, registrada.

4. **Custo do portão subiu de ~8s para ~19s** por causa da varredura `ENC-15`.
   Se incomodar, é o primeiro parâmetro a reduzir (sementes/passos), com perda
   proporcional de cobertura.

5. **Ref local `auditoria/regras-bmv` está atrasado** (`4e35594`) em relação ao
   remoto (`88d12ac`). Não afeta esta OS — a base foi escolhida por SHA — mas
   confunde quem escolher base por nome de branch.

---

## 13. Critérios de PASS

- [x] C10-BOT-03 reproduzido antes da correção
- [x] Causa raiz identificada
- [x] Correção no motor autoritativo
- [x] Nenhum workaround exclusivo de bot
- [x] Estado pós-ação sempre possui conclusão legal
- [x] Ação rejeitada não deixa mutação parcial
- [x] Jogador humano e bot obedecem à mesma autoridade
- [x] Caso com descarte legal continua permitido
- [x] Batida válida continua funcionando
- [x] Fluxo de morto continua funcionando
- [x] Avanço de turno explicitamente testado
- [x] Suítes C10 permanecem verdes
- [x] Testes do bot relevantes permanecem verdes
- [x] Nenhuma regressão nova no analyzer (delta 0)
- [x] Árvore Git limpa
- [x] HEAD local == remoto
- [x] Nenhum merge
- [x] Nenhum deploy
- [x] Relatório final entregue
