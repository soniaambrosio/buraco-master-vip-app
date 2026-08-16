# Rehomologação P0 final integrada — elegibilidade, Billing, moderação, torneios e segurança

Rehomologação do portão P0 integrado depois da correção conjunta de **P0-1**
(não existia fonte real para o estado de elegibilidade) e **P0-3** (Billing sem
ciclo de vida de entitlement).

Veredito no §J. As três respostas que a OS exige estão separadas lá, e não se
misturam: *o código está correto* não é *a produção está liberada*.

---

## A. Base

| | |
|---|---|
| branch exigida | `correcao/p0-elegibilidade-vip-lifecycle` |
| HEAD exigido | `bcb55c7` |
| HEAD remoto encontrado | `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` — **confere** |
| HEAD local encontrado | `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` — **local == remoto** |
| branch de rehomologação criada | `homologacao/p0-final-integrada` @ `bcb55c7` |
| branch recebida do harness | `claude/homologacao-p0-final-integrada-080848` @ `fb9edb5` — o placeholder de `origin/main` de sempre; **abandonada sem ser tocada** |
| árvore inicial | **limpa** (`git status --porcelain` vazio) |

### Cadeia conferida

```
bcb55c7  docs(p0): contrato, ciclo de vida, evidencias e pendencias da correcao
   ^
f2b06c1  fix(p0): elegibilidade composta das fontes reais e ciclo de vida do VIP
   ^
f9814f9  docs(homologacao): matriz P0, defeitos e evidencias do portao integrado
   ^
77eff2d  fix(moderacao): intencao reaproveitada nao pode responder sucesso silencioso   <- P0-2
```

Ancestralidade verificada por `git merge-base --is-ancestor`:

| commit | ancestral do HEAD desta OS |
|---|---|
| `f9814f9` (base da correção) | **sim** |
| `f2b06c1` (código da correção) | **sim** |
| `77eff2d` (correção P0-2 da moderação) | **sim** |

Nenhuma divergência de base. Nada foi retomado silenciosamente.

### Notas de ambiente

- o `git` desta máquina recusa o worktree por *dubious ownership* (F: não
  registra ownership). Foi preciso acrescentar a exceção ao `.gitconfig` global,
  como já existia para outros 13 worktrees deste repositório;
- o emulador do Firestore rodou com o JBR do Android Studio
  (`C:\Program Files\Android\Android Studio\jbr`, OpenJDK 21.0.9) — não há
  `java` no PATH desta máquina.

---

## B. Contrato efetivamente encontrado

Conferido na árvore, e não no documento da correção.

```
  playerModeration/{uid}              playerEntitlements/{uid}
  produtor: functions-moderacao       produtor: functions-billing
  (consolidarSancoes, COL_ESTADO)     (aplicarProposta -> refsEntitlement)
            \                                   /
             \                                 /
              v                               v
                 comporPerfil()   app/lib/elegibilidade/composicao.dart
                        |
                        v
                 PerfilElegibilidade
                        |
                        v
       inscrever() / avaliarElegibilidade()   (domínio Dart, um só)
```

| item | o que a árvore mostra | evidência |
|---|---|---|
| **moderação** | canônica em `playerModeration/{uid}`; produtor real é `consolidarSancoes` | `functions-moderacao/src/index.ts:74` (`COL_ESTADO`), escritas em `:460` e `:524` |
| **entitlement** | canônico em `playerEntitlements/{uid}`; toda escrita passa por `aplicarProposta` | `functions-billing/index.js:207` (`refsEntitlement`), `:229` (`aplicarProposta`) |
| **elegibilidade** | **composição na leitura**, sem documento agregado | `app/lib/elegibilidade/composicao.dart:80` (`comporPerfil`) |
| **consumidor** | `montarPerfil` lê as duas fontes e delega à ponte | `functions/src/index.ts:103-140` |
| **vigência VIP** | uma definição só, temporal | `app/lib/elegibilidade/entitlement.dart:183` (`vigenteEm`) |
| **`players/{uid}`** | **não voltou.** Varredura na árvore inteira: aparece só em comentário, em documentação e no teste que prova a negação | `firebase/testes/entitlement.test.js:260` (ENT-21) |
| **`usuarios/{uid}`** | **não é mais fonte de VIP.** O Billing só escreve ali `fichas` (produto avulso); os campos `vip*` são apenas **lidos** pela migração única | `functions-billing/index.js:582` (única escrita, ramo de consumível), `:933`/`:950`/`:963` (leituras da migração) |
| duas verdades sobre assinatura ativa | **não existem.** `EntitlementVip.vigenteEm` é o único predicado; a varredura do Billing é uma *consulta* (`vipAtivo == true && expiraEm <= agora`), não uma segunda regra | `functions-billing/index.js:801-806` |

Nada foi encontrado fora do que a correção declarou.

### Onde mora a pergunta "tem VIP agora?"

```
vigente = vipAtivo  &&  estado concede acesso  &&  agora < expiraEm
```

As três condições juntas. Um documento incoerente (`revogado` com
`vipAtivo: true`) **não concede** — a divergência recusa. Provado no §C
(casos E2/F2) e no fail-closed FC-01.

---

## C. Casos A–G

Provados por **duas travessias independentes**, e o motivo de serem duas está
declarado no §G.

- **Dart** — `app/test/elegibilidade/costura_p0_test.dart` (29 casos). O lado da
  **moderação** parte do produtor de verdade (`avaliarSancao` + `consolidar()`,
  o mesmo código que a Cloud Function executa). O lado do **Billing** entra como
  literal espelhado.
- **Entre runtimes** — `functions/test/costura_p0_runtime.js` (19 casos,
  **acrescentado nesta OS**). O lado do **Billing** parte do produtor de verdade
  (`consolidarAssinatura` / `consolidarTerminal` + `documentosDeEntitlement`, em
  JavaScript) e alimenta o **domínio Dart compilado** (`domain_bundle.js`), com
  o template VIP vindo do **seed aprovado** (`sexta_master_vip`; o seed tem
  quatro torneios VIP). Nenhuma flag construída à mão: `assinaturaAtiva` e
  `suspenso` nascem dos documentos.

Juntas, as duas fecham o vão que a correção declarou: cada lado da fronteira é
exercitado pelo seu produtor real em pelo menos uma das travessias.

| caso | fonte real | caminho exercitado | esperado | observado | status |
|---|---|---|---|---|---|
| **A — suspenso** | `playerModeration/{uid}`, `suspensaoTemporaria` vigente | `avaliarSancao` → `consolidar` → documento → `comporPerfil` → `inscrever` | recusa | `recusa: perfil_suspenso`, **com VIP em dia** | **PASSA** (Dart A-01 · runtime A) |
| A′ — banido | `suspensaoPermanente` | idem | recusa | `recusa: perfil_suspenso`, sem depender de prazo | **PASSA** (A-02 · A2) |
| A″ — suspensão vencida | `suspensoAte` no passado | idem | entra | `ACEITA` — prazo reavaliado na leitura, sem job | **PASSA** (A-03 · A3) |
| A‴ — sanção revogada | `status: revogada` | idem | entra | `ACEITA` | **PASSA** (A-04) |
| A⁗ — só silêncio de chat | `chatSilenciadoAte` vigente | idem | entra | `ACEITA` — punição de chat não vira punição de competição | **PASSA** (A-05 · A5) |
| **B — VIP válido** | `SUBSCRIPTION_STATE_ACTIVE`, prazo futuro | resposta Play → `consolidarAssinatura` → documento → `comporPerfil` → `inscrever` | entra | `estado: ativo`, `assinaturaAtiva: true`, `ACEITA` | **PASSA** (B · B) |
| **C — sem VIP** | nenhum entitlement | documento ausente → composição → inscrição | recusa | `recusa: requisito_vip_nao_atendido` (`semAssinatura`) | **PASSA** (C · C) |
| **D — VIP expirado** | prazo vencido, **`vipAtivo: true` ainda gravado** | idem | recusa | `vipAtivo: true` no documento, `assinaturaAtiva: false`, recusa | **PASSA** (D · D) |
| D′ — após a varredura | `estado: expirado`, `vipAtivo: false` | idem | recusa | recusa | **PASSA** (D-2 · D2) |
| **E — VIP revogado** | `consolidarTerminal(revogado)` | notificação → terminal → documento → composição | recusa | `estado: revogado`, recusa | **PASSA** (E · E) |
| E′ — revogado com prazo futuro | documento incoerente | idem | recusa | recusa — o estado terminal sozinho basta | **PASSA** (E-2 · E2) |
| **F — VIP reembolsado** | `consolidarTerminal(reembolsado)` | idem | recusa | recusa | **PASSA** (F · F) |
| F′ — reembolsado com prazo futuro | documento incoerente | idem | recusa | recusa | **PASSA** (F-2 · F2) |
| **G — cancelado, ainda vigente** | `SUBSCRIPTION_STATE_CANCELED`, prazo futuro | idem | **entra até `expiraEm`** | `estado: cancelado_vigente`, `renovacaoAutomatica: false`, `ACEITA` | **PASSA** (G · G) |
| G′ — o mesmo, após o prazo | prazo vencido | idem | recusa | o produtor já grava `expirado`; recusa | **PASSA** (G-2 · G2) |
| H — carência × conta em espera | `IN_GRACE_PERIOD` / `ON_HOLD` | idem | uma concede, a outra não | carência `ACEITA`; em espera recusa | **PASSA** (H · H1/H2) |
| H′ — pausado / pendente | `PAUSED` / `PENDING` | idem | recusa | recusa nos dois | **PASSA** (runtime H3/H4) |
| I — torneio público | sem entitlement | idem, template público do seed | entra | `ACEITA` | **PASSA** (I · I) |

Fail-closed, sete casos adicionais (FC-01..FC-07): documento incoerente, estado
desconhecido, direito sem prazo, documento vazio, documento ausente, uid do
corpo divergente do caminho, e o instante exato do vencimento (`agora == expiraEm`
já **não** concede). Todos recusam.

Saída literal do harness entre runtimes, reproduzível com
`npm run build:domain && npm run test:costura` em `functions/`:

```
torneio VIP do seed: sexta_master_vip   (VIPs no seed aprovado: 4)

caso                                    | estado gravado    | vipAtivo | suspenso | assinaturaAtiva | inscricao
----------------------------------------|-------------------|----------|----------|-----------------|-----------
A  suspenso, com VIP em dia             | ativo             | true     | true     | true            | recusa:perfil_suspenso
A2 banido (permanente)                  | ativo             | true     | true     | true            | recusa:perfil_suspenso
A3 suspensao ja vencida                 | ativo             | true     | false    | true            | ACEITA
A5 so silencio de chat                  | ativo             | true     | false    | true            | ACEITA
B  VIP valido                           | ativo             | true     | false    | true            | ACEITA
C  sem entitlement                      | (ausente)         | false    | false    | false           | recusa:requisito_vip_nao_atendido
D  VIP expirado, vipAtivo ainda gravado | ativo             | true     | false    | false           | recusa:requisito_vip_nao_atendido
D2 expirado apos a varredura            | expirado          | false    | false    | false           | recusa:requisito_vip_nao_atendido
E  VIP revogado                         | revogado          | false    | false    | false           | recusa:requisito_vip_nao_atendido
E2 revogado com prazo futuro            | revogado          | true     | false    | false           | recusa:requisito_vip_nao_atendido
F  VIP reembolsado                      | reembolsado       | false    | false    | false           | recusa:requisito_vip_nao_atendido
F2 reembolsado com prazo futuro         | reembolsado       | true     | false    | false           | recusa:requisito_vip_nao_atendido
G  cancelado, periodo ainda pago        | cancelado_vigente | true     | false    | true            | ACEITA
G2 cancelado, periodo vencido           | expirado          | false    | false    | false           | recusa:requisito_vip_nao_atendido
H1 carencia                             | em_carencia       | true     | false    | true            | ACEITA
H2 conta em espera                      | em_espera         | false    | false    | false           | recusa:requisito_vip_nao_atendido
H3 pausado                              | pausado           | false    | false    | false           | recusa:requisito_vip_nao_atendido
H4 pendente, nao pago                   | pendente          | false    | false    | false           | recusa:requisito_vip_nao_atendido
I  torneio publico sem VIP              | (ausente)         | false    | false    | false           | ACEITA

19 casos, 0 divergencias — a costura P0 confere ponta a ponta.
```

A linha que separa esta correção de um `vip: true` renomeado é a **D**: o
documento ainda diz `vipAtivo: true`, e o consumidor recusa mesmo assim, porque
a vigência é avaliada contra o relógio da operação. Se a varredura de vencimento
atrasar cinco minutos ou falhar por uma semana, ninguém entra de graça.

---

## D. Ciclo de vida

Conferido em `functions-billing/entitlement.js` e coberto por teste.

| evento | estado resultante | `vipAtivo` | `expiraEm` | entra? | teste |
|---|---|---|---|---|---|
| compra validada (`ACTIVE`) | `ativo` | `true` | fim do período | sim | CV-01 |
| renovação (RTDN 2 → reconsulta) | `ativo` | `true` | **estendido** | sim | CV-10, RT-01 |
| carência (`IN_GRACE_PERIOD`) | `em_carencia` | `true` | mantido | sim | CV-02 |
| conta em espera (`ON_HOLD`) | `em_espera` | `false` | mantido | não | CV-06 |
| pausa (`PAUSED`) | `pausado` | `false` | mantido | não | CV-06 |
| compra pendente (`PENDING`) | `pendente` | `false` | — | não | CV-06 |
| cancelamento (`CANCELED`) | `cancelado_vigente` | `true` | **mantido** | **sim, até expirar** | CV-03 |
| cancelado vencido | `expirado` | `false` | mantido | não | CV-04 |
| expiração / relógio | `expirado` | `false` | mantido (é o fato) | não | CV-05, CV-06 |
| revogação (RTDN 12) | `revogado` | `false` | **agora** | não | RT-02, CV-11 |
| reembolso (`voidedPurchase`) | `reembolsado` | `false` | **agora** | não | RT-03, CV-11 |
| compra nova após terminal | `ativo` | `true` | novo período | sim | DA-10 |
| estado que a Google inventar | `desconhecido` | `false` | — | não | CV-07 |

Três verificações de coerência que valem registro:

- `consolidarAssinatura` **rebaixa para `expirado`** um estado que concede acesso
  mas cujo prazo já venceu — o documento não fica contando uma história que o
  relógio desmente (CV-05);
- assinatura com **dois `lineItems`** (troca de plano no meio do período) vence
  pelo prazo mais distante — encerrar no primeiro tiraria acesso já pago (CV-09);
- resposta **sem `lineItems`** não concede: sem prazo, sem direito (CV-08).

---

## E. Ordem / concorrência

Toda a decisão mora em `decidirAtualizacao`, avaliada com o documento **relido
dentro da transação** de `aplicarProposta`. O carimbo comparado **não é o do
evento** — é o da *consulta* que produziu a proposta (`verificadoEm`), capturado
**antes** da chamada de rede (`functions-billing/index.js:302`, `:461`).

| situação | comportamento | teste |
|---|---|---|
| RTDN/evento repetido | `billingEvents/{messageId}` escrito **na mesma transação** do efeito → `evento_repetido` | código: `index.js:243`; **sem teste automatizado** (ver §G) |
| reprocessar a mesma verificação | `verificacao_antiga`, sem efeito novo | DA-04 |
| evento antigo chegando depois | `verificacao_antiga` — não regride | DA-03 |
| leitura externa antiga | consulta nova nunca regride; a antiga é descartada | DA-03, DA-14 |
| token antigo/superado | `token_superado` — a expiração da assinatura anterior não derruba a nova | DA-05 |
| renovação concorrente | vence quem **consultou** por último, não quem gravou por último | DA-14 |
| validação manual concorrendo com ciclo de vida | idem, nas duas ordens de commit | DA-14 |
| retry após falha externa | `retry: true` no consumidor; o registro de "já processei" só nasce junto com o efeito, então a reentrega encontra trabalho a fazer | código: `index.js:662`; **sem teste automatizado** |
| reprocessamento idempotente | terminal repetido converge (`terminal_repetido`); mesma verificação converge | DA-09, DA-04 |
| leitura atrasada após estorno | `terminal_preservado` — **não ressuscita** | DA-08 |
| terminal com verificação mais antiga | entra assim mesmo: estorno é fato, não leitura de estado | DA-07 |
| carimbo `ultimoEventoEm` | só anda para a frente | DOC-03 |

As duas garantias que a OS pede estão provadas no nível onde a decisão é tomada:

```
evento velho não regride estado     -> DA-03, DA-05, DA-08, DA-14
evento duplicado não duplica efeito -> DA-04, DA-09
```

---

## F. Reembolso, revogação e reconciliação

### Onde a autoridade é a Google, e onde ela não é

| desfecho | autoridade | por quê |
|---|---|---|
| ativo, carência, cancelado, em espera, pausado, pendente, expirado | **Google consultada** (`purchases.subscriptionsv2.get`) | a notificação é *sinal*: ela manda perguntar, e nada é derivado do payload |
| **revogação** (`notificationType: 12`) | **o próprio evento** | a Google não devolve um `subscriptionState` que diga "revogado" |
| **anulação / estorno** (`voidedPurchaseNotification`) | **o próprio evento** | idem para reembolso |

Esperar a consulta nesses dois casos deixaria uma janela em que o reembolsado
continua VIP. É a única exceção, e ela está isolada em `consolidarTerminal`.

### O fato que precisa ser preservado localmente

`revogado` e `reembolsado` são **terminais para aquele `purchaseToken`**. Uma
consulta em voo que volte dizendo `ACTIVE` depois do estorno vira
`terminal_preservado` — divergência registrada, não concessão (DA-08). O único
caminho de volta é uma **compra nova**, com outro token, que entra pelo ramo de
titularidade (DA-10). O terminal prende o token, não a pessoa.

### Três caminhos de reconciliação

| caminho | gatilho | consulta a Google? | para quê |
|---|---|---|---|
| `notificacoesPlay` | RTDN (Pub/Sub) | sim | o normal |
| `reconciliarEntitlements` | agendado, 30 min | **não** | rede de segurança: fecha vencidos pelo relógio mesmo sem RTDN, sem API e sem tópico configurado |
| `reconciliarEntitlementDoJogador` | admin | sim | divergência relatada, notificação perdida |

O segundo é o que sustenta a operação enquanto o tópico RTDN não existe: sozinho
ele **não** traz revogação nem estorno, mas garante que ninguém fique VIP depois
do prazo.

---

## G. Testes

Todas as suítes rodaram nesta máquina, nesta árvore, com o código em `bcb55c7`.

### Por suíte

| suíte | comando | executados | ✓ | ✗ | skip | não executados | observações |
|---|---|---|---|---|---|---|---|
| Dart — `flutter test` (glob padrão) | `flutter test` em `app/` | **536** | 536 | 0 | 0 | — | exige staging de seeds (§ abaixo) |
| Dart — `test/elegibilidade` | `flutter test test/elegibilidade` | 29 | 29 | 0 | 0 | — | a costura P0 |
| Dart — `test/torneios` | idem | 259 | 259 | 0 | 0 | — | motor + recompensas |
| Dart — `test/colecoes` | idem | 117 | 117 | 0 | 0 | — | inclui gerador de evidência visual |
| Dart — `test/rastreabilidade` | idem | 131 | 131 | 0 | 0 | — | §19 da OS |
| Dart — moderação | `flutter test test/moderacao/teste_moderacao.dart` | **42** | 42 | 0 | 0 | — | **fora do glob padrão** |
| Dart — visão de espectador | `flutter test test/motor/teste_visao_espectador.dart` | **15** | 15 | 0 | 0 | — | **fora do glob padrão**; §19 da OS |
| Dart — integração de motores | `flutter test test/integracao/teste_integracao_motores.dart` | **64** | 64 | 0 | 0 | — | **fora do glob padrão** |
| Dart — motor de partidas | `flutter test test/teste_motor.dart` | **132** | 132 | 0 | 0 | — | **fora do glob padrão** |
| Dart — resiliência do motor | `flutter test test/teste_motor_resiliencia.dart` | **196** | 196 | 0 | 0 | — | **fora do glob padrão** |
| Dart — encerramento | `flutter test test/teste_encerramento.dart` | **10** | 10 | 0 | 0 | — | **fora do glob padrão** |
| Regras Firestore — integrado | `firebase emulators:exec --only firestore --project demo-bmv "cd firebase/testes && npm run test:integrado"` | **93** | 93 | 0 | 3 marcados SKIP | — | um só `firestore.rules` |
| ↳ `seguranca.test.js` | idem, por arquivo | 14 | 14 | 0 | 1 SKIP | — | `claimPioneerKit` exige emulador de Functions |
| ↳ `moderacao.test.js` | idem | 29 | 29 | 0 | 2 SKIP | — | `registrarDenuncia`, `bloqueio pela Function` |
| ↳ `rastreabilidade.test.js` | idem | 28 | 28 | 0 | 0 | — | |
| ↳ `entitlement.test.js` | idem | **22** | 22 | 0 | 0 | — | ENT-01..ENT-22, todos verdes |
| Billing (Functions) | `npm test` em `functions-billing/` | **55** | 55 | 0 | 0 | — | 13 idempotência + 42 entitlement |
| Moderação (Functions) | `npm test` em `functions-moderacao/` | **13** | 13 | 0 | 0 | — | P0-2 incluído |
| Torneios (Functions) — typecheck | `npx tsc --noEmit` em `functions/` | typecheck | exit 0 | — | — | — | |
| Bundle Dart→JS | `npm run build:domain` em `functions/` | compilação | exit 0 | — | — | — | 166.959 caracteres de JS |
| **Costura entre runtimes** | `npm run test:costura` em `functions/` | **19** | 19 | 0 | 0 | — | **acrescentado nesta OS** |
| `flutter analyze` | `--no-fatal-infos --no-fatal-warnings` em `app/` | 42 issues | **0 erros** | — | — | — | ver §baseline |
| CI (`ci-os-integracao.yml`) | — | — | — | — | — | **NÃO EXECUTADO** | dispara só por `workflow_dispatch` / push em `integracao/os-final-backend-flutter` |
| RTDN ponta a ponta | — | — | — | — | — | **NÃO EXECUTADO** | exige tópico Pub/Sub e credencial de conta de serviço |

**Soma do que rodou: 1.161 testes automatizados, 1.161 aprovados, 0 falhos**
(995 Dart em alvos explícitos + 93 regras + 55 Billing + 13 moderação + 19 do
harness de costura, sem contar os 536 do `flutter test` padrão, que são
subconjunto dos 995).

Nada foi dado como aprovado por não ter rodado.

### Cobertura do Billing, por caso (§15 da OS)

| caso | cobertura | natureza |
|---|---|---|
| compra inicial | CV-01, CT-01 | unitário, resposta da Play como literal |
| compra inválida / estado não concedente | CV-05..CV-08 | unitário |
| titularidade | 12 casos em `idempotencia.test.js` | unitário |
| renovação | CV-10, RT-01 | unitário |
| expiração | CV-04, CV-05, DOC-04 | unitário |
| cancelamento | CV-03, CT-02 | unitário |
| revogação | RT-02, CV-11, DA-09 | unitário |
| reembolso | RT-03, DA-07, DA-08 | unitário |
| retry | — | **só no código** (`retry: true`), sem teste |
| reconciliação | DA-14 (decisão); os três caminhos em si | **decisão testada, orquestração não** |
| duplicidade | DA-04, DA-09 | unitário |
| ordem | DA-03, DA-05, DA-14 | unitário |
| token superado | DA-05, DOC-05 | unitário |
| concorrência | DA-14 | unitário, nas duas ordens de commit |
| falha externa (Play API fora do ar) | — | **só no código**, sem teste |

### Fronteira dos testes, declarada sem maquiagem

- **teste unitário** — `functions-billing/test/entitlement.test.js`. As respostas
  da Play Developer API entram como **literais**, copiados do formato documentado
  de `purchases.subscriptionsv2`. Não há rede, não há mock de cliente HTTP, e
  **não se afirma nada** sobre a API real responder assim hoje. Não é integração
  com o Google Play;
- **teste de costura entre módulos, mesmo runtime** — `costura_p0_test.dart`. O
  estado de moderação nasce de `avaliarSancao` + `consolidar()`;
- **teste de costura entre runtimes** — `functions/test/costura_p0_runtime.js`,
  acrescentado nesta OS. O produtor JS real alimenta o consumidor Dart compilado
  real. **É a prova única** que o contrato espelhado (`CT-01..CT-05` + os
  literais do teste Dart) descrevia em dois lugares;
- **teste de regras** — `firebase/testes/entitlement.test.js`, emulador de
  Firestore, regras de verdade;
- **o que não tem teste nenhum** — a **casca de I/O** do Billing:
  `aplicarProposta` (a transação), `notificacoesPlay`, `reconciliarEntitlements`,
  `reconciliarEntitlementDoJogador` e `migrarEntitlementsLegado`. Só a camada
  pura de decisão é exercitada. Testá-las exigiria o emulador de Functions com
  Pub/Sub, que este harness não tem. **Consequência avaliada:** nenhuma delas
  concede acesso por conta própria — todas passam por `decidirAtualizacao`, que é
  a parte testada, e a barreira de convergência (DA-04, DA-09) torna
  reprocessamento inofensivo mesmo que o atalho de dedupe falhe. Por isso é P1 de
  cobertura, e não P0 de correção;
- **teste que exigiria ambiente externo real** — RTDN de verdade chegando por
  Pub/Sub, com tópico configurado na Play Console, e a conferência de que a
  resposta real da Google tem os campos que este código lê. **Não existe e não
  foi simulado.**

### SKIP e não executado

| item | situação | por quê |
|---|---|---|
| `registrarDenuncia`, `bloqueio pela Function` (`moderacao.test.js`) | **SKIP** | exigem o emulador de Functions; rodei `--only firestore` |
| `claimPioneerKit` (`seguranca.test.js`) | **SKIP** | idem |
| CI (`ci-os-integracao.yml`) | **NÃO EXECUTADO** | o workflow não dispara desta branch; sem merge na branch padrão, nenhum run acontece |
| RTDN ponta a ponta | **NÃO EXECUTADO** | ambiente externo |
| Migração legada em dados reais | **NÃO EXECUTADA** | proibida por esta OS (§16) |

### Baseline de `flutter analyze`

| | base (`f2b06c1`, declarada) | agora (`bcb55c7`) | diferença |
|---|---|---|---|
| erros | 0 | **0** | — |
| warnings | — | 13 | — |
| infos | — | 29 | — |
| **total** | 42 issues | **42 issues** | **idêntico** |

Nenhum issue vem de arquivo desta correção ou desta rehomologação: a varredura
por `elegibilidade` no relatório do analisador devolve **zero** ocorrências. Os
42 são pré-existentes (`withOpacity` depreciado, `activeColor`, `groupValue`,
campos privados não usados em telas antigas). A OS não pede limpeza deles.

### Seeds / CWD

A dependência de CWD **continua existindo**. Sem o staging, quatro suítes Dart
falham no *load*. Procedimento executado:

```
app/data/torneios/*.json  ->  app/test/torneios/data/
app/data/colecoes/*.json  ->  app/test/colecoes/data/
```

1. registrado;
2. staging feito;
3. testes executados;
4. staging **desfeito** (`Remove-Item -Recurse` nos dois diretórios);
5. efeito colateral registrado: a suíte completa **regenera** dois PNGs em
   `app/test/colecoes/evidencias/` — restaurados com `git checkout`;
6. árvore conferida: `git status --porcelain` **vazio** antes de qualquer commit
   desta OS.

Corrigir a localização dos seeds não era necessário para a cobertura, e a §22
manda não transformar isso em correção ampla. **Não foi feito.**

---

## H. Segurança

### Identidade e titularidade

| item | o que a árvore mostra | evidência |
|---|---|---|
| uid nunca vem do cliente | `validarCompraPlay` tira o uid de `request.auth`; o app não manda uid | `functions-billing/index.js:364` |
| elo uid ↔ token | `compras/{sha256(token)}`, escrito só com identidade autenticada | `index.js:395`, `:404` |
| titularidade antes do estado | `decidirSobreRegistroExistente` → `conferirTitularidade` **antes** de olhar o estado | `idempotencia.js`; 12 testes |
| titularidade de novo dentro da transação | defesa em profundidade na concessão | `index.js:549-552` |
| token de outro usuário | `CONFLITO` → `permission-denied` | testes de titularidade (4 casos) |
| RTDN sem titular comprovável | evento **descartado**, não atribuído por palpite | `index.js:704-716` |
| entitlement alheio | escrita fechada para todos pelo cliente | ENT-12 |
| payload manipulado para ativar VIP | o entitlement é escrito a partir da **resposta da Google**, nunca do corpo da chamada; `fichas` vem do catálogo do servidor | `index.js:497`, `:580` |
| operações administrativas | `reconciliarEntitlementDoJogador` e `migrarEntitlementsLegado` exigem custom claim `admin`, nunca documento | `index.js:852`, `:922` |

### Firestore Rules

Suíte integrada completa executada contra **um só** `firestore.rules`: 93/93.

O que ficou provado no emulador para entitlement (ENT-01..ENT-19):

| tentativa do cliente | resultado |
|---|---|
| criar o próprio entitlement | **negado** (ENT-05) |
| conceder-se VIP | **negado** (ENT-06) |
| estender `expiraEm` | **negado** (ENT-07) |
| trocar `estado` / desfazer revogação | **negado** (ENT-08) |
| trocar `produtoId` | **negado** (ENT-09) |
| apagar o entitlement | **negado** (ENT-10) |
| escrever como **admin** pelo cliente | **negado** (ENT-11) |
| escrever no entitlement de terceiro | **negado** (ENT-12) |
| ler entitlement alheio | **negado** (ENT-02) — também impede enumerar quem paga |
| ler sem autenticação | **negado** (ENT-03) |
| ler o próprio | **permitido** (ENT-01) — só o necessário; ver "dados sensíveis" |
| ler a subcoleção `interno` (dono) | **negado** (ENT-13) |
| ler a subcoleção `interno` (admin) | **negado** (ENT-14) |
| escrever no `interno` | **negado** (ENT-15) |
| ler o pai abre a subcoleção? | **não** (ENT-16) |
| ler `billingEvents` | **negado** ao jogador (ENT-17), permitido ao admin (ENT-18) |
| criar `billingEvents` | **negado** (ENT-19) — plantar um documento ali faria o sistema descartar como "repetida" a notificação de estorno |

### Regressão de regras — nenhuma permissão antiga foi afrouxada

Conferido **por teste**, e não por leitura:

| regra antiga | continua valendo | teste |
|---|---|---|
| `usuarios/{uid}` barra campos de servidor (`vip`, `vipExpiraEm`, `fichas`…) | sim | ENT-20 |
| `players/{uid}` negada pelo fecho padrão | sim | ENT-21 |
| `playerModeration/{uid}` fechada para escrita, inclusive para o dono | sim | ENT-22 |
| fecho padrão nega caminho não declarado | sim | suíte de não-regressão pré-existente |
| segundo bloco `users/{uid}` não afrouxou o inventário | sim | suíte de não-regressão pré-existente |
| `compras/{chave}` legível só pelo dono, escrita fechada | sim | `firestore.rules:250-253` + suíte de segurança |

### `purchaseToken` — a decisão declarada, homologada

O token cru é gravado em `playerEntitlements/{uid}/interno/billing`. Verificado
item a item:

| exigência da OS §10 | resultado |
|---|---|
| Rules negam acesso do cliente | **sim** — `allow read, write: if false` na subcoleção, para dono **e** admin (ENT-13/14/15/16) |
| nenhuma resposta pública devolve o token | **sim** — `validarCompraPlay` devolve `{aprovada, jaProcessada, detalhes, entitlement:{estado, vipAtivo}}`; `reconciliarEntitlementDoJogador` devolve `{estado, vipAtivo, aplicado, motivo}` |
| logs não exibem token | **sim** — varredura em todos os `console.*` de `functions-billing/`: **todo** log de token usa `rotuloToken(hash)`, que corta o **hash** sha256 em 8 caracteres. O token cru não aparece em nenhum |
| mensagens de erro não exibem token | **sim** — as três `HttpsError` do caminho de compra são textos fixos |
| documentos de observabilidade não vazam token | **sim** — `billingEvents/{messageId}` grava `token: rotuloToken(hash)` (`index.js:269`), e é ilegível pelo cliente (ENT-17) |
| hashes continuam usados quando o segredo em claro não é necessário | **sim** — `compras/{hash}`, `purchaseTokenHash` e os rótulos de log |
| o documento que o jogador lê não carrega campo sensível | **sim** — DOC-01 lista as chaves permitidas e quebra se alguém acrescentar uma |

**Nenhum caminho cliente lê o purchase token.** A decisão de guardá-lo em claro
está justificada (é credencial de consulta, e hash não consulta nada) e as
mitigações são todas verificáveis por teste. **Homologada.**

Observação sem gravidade, registrada por honestidade: em falha da Play Developer
API, `index.js:471` persiste `e.message` em `compras/{hash}.ultimoErro`. A
mensagem do `googleapis` não carrega a URL (o token viaja em `error.config.url`,
não em `.message`), e mesmo se carregasse, `compras/{hash}` só é legível pelo
**dono daquele token**, que já o possui. Não há vazamento cruzado. Não classifico
como defeito.

---

## I. Migração legada

**Não executada** (proibido pela §16). Homologada por leitura e por teste da
camada de decisão.

| exigência | resultado |
|---|---|
| a rotina existe | **sim** — `migrarEntitlementsLegado`, `functions-billing/index.js:919` |
| só admin | **sim** — custom claim `admin`, `:922` |
| idempotente | **sim** — `decidirAtualizacao` recusa `fonte: 'migracao'` sobre qualquer entitlement existente (`legado_nao_sobrescreve`), provado em **DA-11**; onde não há nada, entra (**DA-12**) |
| tem cursor | **sim** — `orderBy(documentId()).startAfter(cursor)`, lote ≤ 400 |
| comportamento quando só existe `vipExpiraEm` | cria o direito **até aquele prazo e nem um minuto a mais**, com `origem: 'legado_usuarios'` |
| `vip: true` **sem** `vipExpiraEm` | **pulado e contado** (`semPrazo`) — sem prazo não dá para afirmar que o direito vale |
| impossibilidade de reconsulta histórica | **confirmada** — `compras/{hash}` guarda o hash, nunca o token; para compras anteriores à correção o valor com que se pergunta à Play **não existe em lugar nenhum da árvore** |
| não sobrescrever entitlement melhor com estado legado pior | **sim** — é o mesmo DA-11 |
| a rotina em si tem teste? | **não.** Só a decisão que ela usa (DA-11/DA-12). O corpo (cursor, contagem, `semPrazo`) não é exercitado |

### Resposta à pergunta da §16

> A migração pode ser executada antes da abertura dos torneios VIP sem corromper
> entitlements novos?

**Sim, quanto a corromper.** `legado_nao_sobrescreve` é incondicional: qualquer
entitlement já existente — de qualquer origem — vence a migração. Rodá-la duas
vezes, ou depois de o jogador já ter renovado, não estraga nada. E um entitlement
migrado **não trava** o jogador: como ele nasce com `purchaseTokenHash: null`, a
primeira notificação ou validação real passa por cima dele sem cair em
`token_superado` (verificado em `decidirAtualizacao`: o bloqueio por token exige
`atual.purchaseTokenHash` preenchido).

**Com duas limitações declaradas, que não são corrupção e sim perda de precisão:**

1. se a assinatura renovou depois do último `vipExpiraEm` gravado, o jogador
   fica com prazo curto até a próxima validação/RTDN repor;
2. se foi estornada no meio do período, o sistema só descobre no vencimento —
   janela de erro de, no máximo, um período de cobrança.

A alternativa seria tirar o VIP de todo assinante pagante no dia da virada.

---

## J. Regressões

### P0-2 da moderação — continua corrigido

`functions-moderacao/test/idempotencia.test.js`: **13/13, verde**, com os dois
casos que nomeiam o defeito:

```
✔ DEFEITO P0: mesma intencao apontada para outra pessoa e CONFLITO
✔ decidirSobreReserva — intencao reaproveitada e CONFLITO
✔ outra tarefa reusando a chave e CONFLITO
✔ outro ator reusando a chave e CONFLITO
✔ a mesma denuncia reenviada (toque duplo, retry) converge
```

`77eff2d` é ancestral do HEAD desta OS. Nenhum arquivo da moderação foi tocado
por esta rehomologação. A barreira **não** foi removida nem simplificada.

### As demais provas de não regressão

| item | como foi conferido | resultado |
|---|---|---|
| autoridade do servidor | `firestore.rules` + as 93 provas de regra; nenhuma decisão de competição em TypeScript (`functions/src/index.ts` só lê e obedece) | íntegro |
| idempotência do motor de torneios | `test/torneios` 259/259; `test/teste_motor.dart` 132/132 | íntegro |
| proteção da identidade | `test/rastreabilidade/identidade_test.dart` (dentro dos 131) + ENT-02/03 | íntegro |
| moderação | Dart 42/42; Functions 13/13; regras 29/29 | íntegro |
| rastreabilidade | Dart 131/131; regras 28/28 | íntegro |
| recorte de espectador | `test/motor/teste_visao_espectador.dart` **15/15** | íntegro |
| crédito único sob concorrência | 3 casos em `idempotencia.test.js` | íntegro |
| regras integradas | 93/93 num só `firestore.rules` | íntegro |
| suíte anterior | Dart 536 → **536**; regras 93 → **93**; Billing 55 → **55**; moderação 13 → **13**; `tsc` exit 0 → **exit 0**; analyze 42/0 erros → **42/0 erros** | **idêntico, sem nenhuma regressão** |

Nenhum teste existente foi editado, renomeado ou removido nesta OS.

---

## K. Ressalvas

### P0 — bloqueiam a aprovação técnica

**Nenhum.** Nenhum defeito de classe P0 foi encontrado nesta rehomologação.

Verificado item a item contra a lista da §24:

| defeito P0 possível | encontrado? |
|---|---|
| VIP expirado entra | **não** (caso D, nas duas travessias) |
| suspenso entra | **não** (caso A, com o produtor real de sanção) |
| cliente consegue conceder VIP | **não** (ENT-05..ENT-12) |
| revogado ressuscita | **não** (DA-08, `terminal_preservado`) |
| token sensível exposto | **não** (ENT-13..ENT-16, DOC-01, DOC-06, varredura de logs) |
| estado antigo vence estado novo | **não** (DA-03, DA-05, DA-14) |
| titularidade pode ser quebrada | **não** (12 casos + reconferência dentro da transação) |

### P1 — não bloqueiam o contrato central

1. **CI manual e incompleto — o portão automático não cobre o que esta OS
   provou.** `ci-os-integracao.yml` dispara só por `workflow_dispatch` ou por
   push em `integracao/os-final-backend-flutter`, e roda as suítes Dart por
   **caminho explícito**. Ficam de fora do portão:
   `test/elegibilidade/costura_p0_test.dart` (a costura P0 nova),
   `test/moderacao/teste_moderacao.dart`, `test/motor/teste_visao_espectador.dart`,
   `test/rastreabilidade/*_test.dart`, `functions-moderacao` inteiro, e
   `rastreabilidade.test.js` das regras (o alvo `test` de `firebase/testes` não a
   inclui; só `test:integrado` inclui, e o CI chama `test`). O harness de costura
   entre runtimes também não está lá.
   **Não corrigido de propósito** (§18): uma edição no workflow não é verificável
   nesta sessão — sem merge na branch padrão nenhum run acontece —, e mexer nele
   sem poder provar seria exatamente o "verde que não significa nada".
2. **Casca de I/O do Billing sem teste.** `aplicarProposta`, `notificacoesPlay`,
   `reconciliarEntitlements`, `reconciliarEntitlementDoJogador` e
   `migrarEntitlementsLegado` não têm teste automatizado — só a camada pura de
   decisão tem. Avaliado no §G: não é P0 porque nenhuma delas concede por conta
   própria e o reprocessamento converge.
3. **Suítes Dart invisíveis ao `flutter test` padrão.** Seis arquivos usam o
   prefixo `teste_` em vez do sufixo `_test.dart` e por isso não entram no glob
   padrão: 459 testes que só rodam se alguém souber o caminho. Todos verdes
   quando chamados explicitamente. É risco de descoberta, não de correção.
4. **Estorno de compra avulsa não devolve as fichas** (herdado da correção).
   Economia, fora de escopo, exige decisão de produto.
5. **Duas carteiras coexistem** — `usuarios/{uid}.fichas` (Billing) e
   `wallets/{uid}.fichas` (torneios). Pré-existente e ortogonal; reaparece quando
   um torneio com `custoEntrada` abrir.
6. **Os quatro da homologação anterior continuam abertos**, nenhum tocado: freios
   de abuso contornáveis por concorrência; CI sem moderação/rastreabilidade/
   espectador; `NÃO EXECUTADO` não reprovando o portão; `VisaoEspectador` sem
   consumidor de produção.
7. **Dependência de CWD nos seeds** — quatro suítes Dart falham no *load* sem o
   staging manual. §22 manda não corrigir sem necessidade.

### P2 — melhorias não bloqueantes

1. `nivel`, `posicaoRanking` e `conquistas` seguem **sem autoridade** nesta
   árvore; os critérios correspondentes recusam por `dado_indisponivel`. Nenhum
   torneio do seed aprovado os usa hoje.
2. Os 42 issues do `flutter analyze` (0 erros) seguem pré-existentes.

### Produção — o que falta, e é infraestrutura, não código

1. **O tópico RTDN não existe.** `play-billing-rtdn` está declarado em
   `functions-billing/index.js:94` e **não foi criado nem apontado na Play
   Console**. O código de parsing, idempotência, ordenação, reconciliação e
   segurança está homologado acima; a ligação não. **Sem o tópico configurado,
   revogação e reembolso não chegam ao sistema** — sobram apenas validação
   (compra e renovação, quando o app chama) e varredura por relógio (expiração).
2. **A migração legada não foi executada.** Sem ela, todo assinante anterior à
   correção entra como "sem VIP" no primeiro torneio VIP que abrir. Ela é admin,
   idempotente e com cursor, e o §I responde que pode rodar sem corromper
   entitlements novos — mas **rodar ainda é um ato, e ele não aconteceu**.

Esses dois são a diferença entre "o código está correto" e "funciona em
produção". Não reprovam o P0 técnico, e **bloqueiam a produção VIP**.

---

## L. Veredito

### 1. P0 técnico

```
P0 TÉCNICO: APROVADO
```

Todos os critérios da §25 foram atendidos, com evidência:

- casos **A–G** passam pela costura real, em **duas travessias independentes**,
  com produtor de verdade em cada lado da fronteira;
- moderação real **impede** a inscrição — e a prova parte de `avaliarSancao` +
  `consolidar()`, não de flag construída à mão;
- VIP válido **permite** a inscrição, no torneio VIP do seed aprovado;
- expirado, revogado e reembolsado são **recusados**;
- cancelado ainda vigente **permanece válido até `expiraEm`**;
- identidade e titularidade seguras; o cliente **não escreve** entitlement;
- regras intactas, nenhuma permissão antiga afrouxada;
- concorrência e idempotência corretas na camada que decide;
- **nenhuma regressão P0**;
- **P0-2 continua verde** (13/13).

### 2. Prontidão de produção VIP

```
PRODUÇÃO VIP: BLOQUEADA
```

Faltam os dois itens de implantação do §26, e nenhum deles é código:

```
RTDN configurado e apontado na Play Console   -> NÃO FEITO
migração legada executada e conferida         -> NÃO EXECUTADA
```

### 3. CI

```
CI: P1 PENDENTE — a homologação atual é MANUAL
```

O workflow não dispara desta branch, e seu portão não cobre a costura P0 nova,
a moderação, o espectador, a rastreabilidade das regras nem o harness entre
runtimes. Os números do §G são desta máquina.

---

## M. Git

| | |
|---|---|
| branch da rehomologação | `homologacao/p0-final-integrada` |
| hash da base | `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` |
| hash final local | o commit desta OS, imediatamente acima de `bcb55c7` |
| hash remoto | **não se aplica** — branch não publicada |
| upstream | **não configurado** |
| árvore de trabalho | **limpa** (staging de seeds desfeito, PNGs restaurados) |
| merge em `main` | **NÃO FEITO** |
| merge em `consolidacao/apk-geral-bmv` | **NÃO FEITO** |
| merge em qualquer branch compartilhada | **NÃO FEITO** |
| deploy / publicação | **NÃO FEITO** |
| force push / rebase destrutivo | **NÃO FEITO** |
| branches de origem alteradas | **NENHUMA** — `correcao/p0-elegibilidade-vip-lifecycle` continua em `bcb55c7`, local e remoto |

### O que esta OS mudou na árvore

Não é só documentação, e por isso está declarado:

```
novo:
  docs/REHOMOLOGACAO-P0-FINAL-INTEGRADA.md   este relatório
  functions/test/costura_p0_runtime.js       19 casos de costura entre runtimes

alterado:
  functions/package.json                     + script `test:costura`
```

`functions/test/costura_p0_runtime.js` é **infraestrutura de teste, sem mudança
funcional** — a categoria que a §3 desta OS autoriza. Ele existe porque a
correção declarou o lado do Billing como contrato *espelhado* (literais nos dois
lados, com estopim em cada um) em vez de prova única, e a §14 pede prova da
costura real. Nenhum código de produção foi tocado por esta rehomologação.

O push não foi feito: publicar é ação externa e a OS não a exige.
`git push -u origin homologacao/p0-final-integrada` publica sem tocar em nenhuma
outra branch, se a Sônia quiser.
