# Homologação P0 integrada — portão de pré-lançamento

Auditoria de **fronteiras** entre os subsistemas do Buraco Master VIP. Não repete
teste unitário: procura o lugar onde a garantia de um módulo é quebrada por
outro.

A pergunta de encerramento da OS é *"as garantias críticas continuam válidas
quando os módulos interagem entre si?"*. A resposta desta homologação é
**NÃO — o portão não pode ser declarado aprovado**, por dois bloqueadores
descritos em P0-1 e P0-3. Um terceiro defeito (P0-2) foi corrigido aqui.

---

## A. Base real

O ponto de partida **não era utilizável** e essa foi a primeira descoberta.

| | |
|---|---|
| branch da sessão (recebida) | `claude/buraco-vip-integrated-testing-a90557` @ `fb9edb5` |
| o que era `fb9edb5` | `origin/main` — placeholder com `main.dart` solto e um commit "noop". Sem `app/lib/moderacao`, sem `functions*`, sem `firebase/` |
| branch desta OS | `homologacao/p0-integrada-a90557` |
| base escolhida | `c2e34ad` (`claude/buraco-vip-game-traceability-3eb66c`) |
| base integrada | `d10170b` — merge de `f25026e` (moderação) sobre `c2e34ad` |

### Por que foi preciso montar a base

Os módulos que a OS manda cruzar **nunca coexistiram em árvore nenhuma**. O
mapeamento de ancestralidade mostrou uma cadeia com duas pontas irmãs:

```
consolidacao/apk-geral-bmv        0cea0d6   (130 commits)
└── motor-partidas-resiliencia    6917331
    └── os-integracao-final...    1dc26dd   consolidação Firebase (rules unificadas)
        ├── moderation-reports... f25026e   +1 commit   ─┐ irmãs, nunca reunidas
        └── game-traceability     c2e34ad   +2 commits  ─┘
```

`1dc26dd` já havia unificado as três topologias Firebase (`firebase.json` como
manifesto único, `functions-billing/` absorvendo `feat/play-billing-aab-interno`
byte a byte). Sobre ele, moderação e rastreabilidade seguiram em paralelo e cada
uma acrescentou o seu bloco **no mesmo ponto dos mesmos três arquivos**.

O conflito foi de **anexo**, não de conteúdo — colunas disjuntas:

| arquivo | resolução | verificação |
|---|---|---|
| `firebase/firestore.rules` | união literal dos dois blocos; nenhuma condição `allow` tocada | 71/71 no emulador |
| `firebase/firestore.indexes.json` | 17 comuns + 8 rastreabilidade + 4 moderação = **29**; coleções disjuntas | JSON válido, contagem conferida |
| `firebase/testes/package.json` | união dos alvos + `test:integrado` (as três suítes contra **um** `firestore.rules`) | JSON válido |

Nenhuma regra foi afrouxada para acomodar a união.

### Fora da base, e por quê

| módulo | situação |
|---|---|
| **espectador** (`spectator-view-server-enforcement`) | contribui só `docs/ESPECTADOR-SERVIDOR.md` + `servidor/SERVIDOR-ESPECTADOR.patch`. O patch **não está aplicado** e não existe `servidor/` nesta árvore — o servidor autoritativo é outro repositório. O recorte de espectador em Dart (`app/lib/motor/visao_espectador.dart`) **veio pela moderação** e está na base. |
| **fluxo de mesas** / **ranking-ligas-hall** (`7a75bab`) | camada visual Flutter — fora de escopo por §6. |
| **kit-pioneiros** (`bce06fe`) | já absorvido por `1dc26dd` (`firebase/functions`, codebase `colecoes`). |

---

## B. Matriz P0

Legenda: **OK** aprovado · **CORRIGIDO** defeito consertado aqui ·
**BLOQUEADOR** P0 real, reportado e não corrigido · **PENDÊNCIA** lacuna sem
defeito demonstrável nesta árvore.

### Partida · reconexão · idempotência · concorrência

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| queda durante ação, reconexão após troca de turno/rodada | cliente reaplica ação vencida | `sessao_reconexao.dart`, `snapshot_partida.dart`, `versaoEstado` | `teste_motor_resiliencia.dart` (no portão do APK) | **OK** |
| comando antigo reaparece / evento duplicado reenviado | dupla aplicação | `comando_partida.dart`; id do evento **é** o id do documento em `matches/{id}/events` | `teste_motor_resiliencia.dart`, `rastreabilidade/reconexao_e_abandono_test.dart` | **OK** |
| cliente com estado atrasado | divergência silenciosa | `formatoSnapshot` + `versaoEstado` no payload | `teste_motor.dart` | **OK** |
| cliente forja desfecho / troca `matchId` / se marca vencedor | resultado falso | validação de envelope no domínio; `allow write: if false` em `matches` | `rastreabilidade/seguranca_test.dart` (TAM-01..06, VAL-01..05) | **OK** |
| ledger aplicado duas vezes | ranking inflado | id do doc = `matchId\|userId\|motivo` | `rastreabilidade/resultado_test.dart` | **OK** |

### Partida · espectador

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| espectador recebe dado reservado | mão/monte/morto no aparelho de quem assiste | `VisaoEspectador` é **lista de permissão** escrita à mão + `vazamentos()` varre a estrutura contra `segredos()` em qualquer profundidade | `motor/teste_visao_espectador.dart` | **OK** (domínio) |
| espectador executa ação de jogador / acessa payload de terceiro | escalada de privilégio | autorização vive no servidor autoritativo | seção ESPECTADOR de `firebase/testes/moderacao.test.js` | **OK** (regras) |
| o recorte é realmente usado | proteção teórica | — | — | **PENDÊNCIA** — ver P1-3 |
| jogador moderado como espectador | sanção sem efeito | `playerModeration` consolidado | — | **BLOQUEADOR** — ver P0-1 |

### Chat · proteção social

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| bloqueio entre jogadores (mútuo) | contato indevido | `consultarContato` lê **as duas direções** (`blocks` ida e volta) | `moderacao.test.js` | **OK** |
| mute | escrita direta do cliente | `users/{uid}/mutes`: cliente escreve, mas `alvoUid != uid`, `apenasCampos([...])` e id do doc = alvo | `moderacao.test.js` | **OK** |
| denunciado descobre quem o denunciou | vazamento de identidade | `reports` só admin; comprovante é **outro documento** (`reportReceipts`) sem `denunciadoUid`/evidência/status interno | `moderacao.test.js` | **OK** |
| consultar evidência ou dado interno de denúncia | leitura administrativa | `reports`/`sanctions`/`moderationAudit` só admin | `moderacao.test.js` | **OK** |
| enumeração de suspensos | mapa de contas punidas | `playerModeration/{uid}` legível só pelo dono | `moderacao.test.js` | **OK** |
| evidência de mensagem | conteúdo atestado pelo cliente | não há chat servidor-lado; registro grava `origem: "cliente_atestada"` | — | **PENDÊNCIA** (limitação já declarada no código) |

### Billing · entitlement

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| compra válida | crédito forjado no aparelho | Play Developer API + conta de serviço no Secret Manager; `fichas` vêm do catálogo do servidor, nunca do payload | `functions-billing/test/idempotencia.test.js` | **OK** |
| evento duplicado / reentrega concorrente | crédito duplo | concessão e `estado: concedida` na **mesma** transação, documento relido dentro dela | 13/13 billing | **OK** |
| token de terceiro | concessão alheia devolvida | `conferirTitularidade` **antes** do estado | 13/13 billing | **OK** |
| cliente concede entitlement direto | escalada | `usuarios/{uid}`: `camposDeServidor()` barra `vip`/`fichas` no create e no update | `seguranca.test.js` | **OK** |
| renovação · cancelamento · account hold · recuperação · expiração · reembolso · revogação · fora de ordem · reconciliação | entitlement eterno; reembolsado continua VIP | **nenhuma** | — | **BLOQUEADOR** — P0-3 |

### Economia · auditoria

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| operação econômica repetida / retry / falha parcial | saldo duplicado | `FieldValue.increment` dentro da transação de concessão, guardada por `podeConceder` | 13/13 billing | **OK** |
| recompensa de torneio concedida duas vezes | prêmio duplicado | id do doc = chave de idempotência em `rewardGrants` | `torneios/reward_grants_test.dart` (no portão do APK) | **OK** |
| correlação evento↔jogador↔operação sem vazar dado sensível | trilha expõe conteúdo | `moderationAudit` grava só quem/o quê/sobre quem/quando — nunca o comentário nem a evidência | `moderacao.test.js` | **OK** |
| freio de abuso sob concorrência | teto contornável | contagem por consulta **fora** da transação | — | **P1-1** |

### Moderação × demais módulos

| cenário | risco | proteção existente | teste | status |
|---|---|---|---|---|
| sanção produz efeito no chat/social | punição decorativa | `consultarContato` consulta `playerModeration` do chamador | `moderacao.test.js` | **OK** |
| sanção produz efeito na inscrição em torneio | suspenso continua competindo | domínio honra `perfil.suspenso`… mas ninguém o preenche | `motor_torneios_test.dart:706` passa (constrói a flag à mão) | **BLOQUEADOR** — P0-1 |
| moderação com poder além do definido | admin apaga a própria trilha | `moderationAudit`/`sanctions` com `allow write: if false` inclusive para admin; revogação **não apaga**, marca `revogada` | `moderacao.test.js` | **OK** |
| intenção de sanção reaproveitada | sanção some com sucesso na mão do chamador | não havia | `functions-moderacao/test/idempotencia.test.js` | **CORRIGIDO** — P0-2 |

### Regras Firestore × Functions

| cenário | risco | resultado |
|---|---|---|
| bloco de regras novo afrouxando o vizinho | união permissiva | **OK** — regras concedem se *qualquer* bloco conceder, então os dois `match /users/{uid}` foram conferidos: o bloco 1 declara **cada** subcoleção explicitamente (`inventory`, `campaign_claims`, `matchHistory`), sem curinga e sem regra no documento pai. Não há caminho pelo qual ele abra `blocks`, `mutes` ou `reportReceipts`. |
| predicados duplicados divergindo | `admin()` mais frouxo que `ehAdmin()` | **OK** — corpos idênticos (`request.auth.token.admin == true`), sinônimos declarados de propósito para manter os blocos conferíveis contra as branches de origem. |
| gravação direta que devia passar por Function | escrita de cliente em coleção sensível | **OK** — fecho `match /{documento=**}` nega o não declarado; a única escrita de cliente concedida em toda a superfície de moderação é `mutes`, com forma fixa. |
| papel administrativo por documento | jogador se promove | **OK** — admin vem de *custom claim*, nunca de documento. |

---

## C. Defeitos encontrados

### P0-1 · BLOQUEADOR · `players/{uid}` não é escrito por ninguém: entitlement e sanção nunca chegam ao portão de torneios

**Reprodução (estática, determinística).** `players` aparece **uma única vez** em
todo o repositório, e é uma *leitura*:

```
functions/src/index.ts:80    db().collection("players").doc(userId).get()
```

Não há `match /players` em `firebase/firestore.rules` (portanto o cliente não
escreve — o fecho nega), e nenhuma Function, seed ou script grava a coleção. O
documento **nunca existe**.

**Causa raiz.** `montarPerfil` (`functions/src/index.ts:78-117`) é o adaptador
entre o mundo persistido e o domínio de elegibilidade. Ele projeta:

```ts
assinaturaAtiva: dados.assinaturaAtiva === true,   // dados = {} sempre
suspenso:        dados.suspenso === true,          // dados = {} sempre
```

Mas os produtores gravam em **outros documentos, com outros nomes**:

| quem produz | onde grava | o que grava |
|---|---|---|
| Billing (`functions-billing/index.js:276`) | `usuarios/{uid}` | `vip`, `vipExpiraEm`, `vipProdutoId` |
| Moderação (`functions-moderacao/src/index.ts:445`) | `playerModeration/{uid}` | `suspensoAte`, `suspensaoPermanente`, `chatSilenciadoAte`, `socialRestritoAte` |
| Consumidor de torneios | lê `players/{uid}` | `assinaturaAtiva`, `suspenso` |

Três módulos mantêm três noções de estado do jogador em três documentos, e o
consumidor lê um quarto que ninguém alimenta.

**Impacto.** Dois lados, ambos P0:

1. **Sanção sem efeito.** `eligibility.dart:162` documenta a intenção — *"O
   perfil esta suspenso por moderacao. Bloqueia inscricao independentemente dos
   criterios do torneio."* Como `suspenso` é sempre `false`, **um jogador
   suspenso ou banido permanentemente continua se inscrevendo em torneios.** É
   exatamente a verificação que §2 ("Moderação + demais módulos") exige, e ela
   falha.
2. **Entitlement pago sem efeito.** `assinaturaAtiva` é sempre `false`, logo
   `RecusaElegibilidade.semAssinatura` recusa **todo** assinante VIP nos torneios
   de acesso VIP (`AcessoTorneio.vip`, ex. Sexta Master VIP).

**Por que os testes de módulo não pegam.** `motor_torneios_test.dart:706`
(`'perfil suspenso e recusado'`) constrói `_perfil('ana', suspenso: true)` e
injeta direto no domínio, **sem passar por `montarPerfil`**. O domínio está
correto e o teste passa; a costura onde o nome do campo divergiu não é
exercitada por nenhum teste. É o caso-tese desta OS.

**Correção: NÃO aplicada, por §5.** Ligar o adaptador exige decidir contrato, e
não é escolha de implementação:

- qual documento é canônico para entitlement? O cabeçalho de `firestore.rules`
  declara `usuarios/` como **namespace legado exclusivo do Billing**, cuja
  eliminação é *"uma MIGRACAO SEPARADA E TESTADA, com OS propria"*. Fazer um
  consumidor novo depender dele contraria a decisão já registrada;
- `vip` sozinho não basta: sem avaliar `vipExpiraEm` o entitlement é eterno — e
  não há ciclo de vida que o mantenha (P0-3);
- `suspenso` precisa vir de `consolidarSancoes`, o que introduz dependência de
  relógio no caminho de inscrição.

**Recomendação.** Um único ponto de verdade por jogador, escrito só por Function,
lido pelos consumidores — e `montarPerfil` passando a lê-lo. A decisão de qual
documento é esse pertence à Sônia.

---

### P0-2 · CORRIGIDO · intenção de moderação reaproveitada respondia sucesso silencioso

Commit `77eff2d`.

**Reprodução.** Chamar `aplicarSancao` com um `sancaoIntentId` já usado, mudando
o `userId` (ou o `tipo`). A chave reservada é encontrada e a resposta é
`{aplicada: true, jaAplicada: true}` — **sem que sanção alguma seja aplicada**.
O mesmo vale para `registrarDenuncia` com o mesmo `reportIntentId` apontado a
outra pessoa.

**Causa raiz.** `functions-moderacao/src/idempotency.ts` declara no cabeçalho
*"Mesmo desenho de `functions/src/idempotency.ts`"*. Em torneios esse desenho é
seguro porque a chave **carrega o payload** (`tournamentId|editionId|alvo`), o
que faz da existência do documento prova de que o pedido é o mesmo. As chaves da
moderação não carregam:

```
aplicarSancao      ${responsavel}|${sancaoIntentId}      sem userId, sem tipo
registrarDenuncia  ${denuncianteUid}|${reportIntentId}   sem denunciadoUid
```

A moderação herdou o mecanismo sem herdar a precondição que o tornava seguro. A
conferência que faltava **já existia no vizinho**: `conferirTitularidade` em
`functions-billing/idempotencia.js`, escrita justamente porque lá a chave (hash
do `purchaseToken`) também não carrega o payload.

**Impacto.** Uma sanção pedida desaparece e o operador recebe confirmação de que
ela foi aplicada. Numa ferramenta administrativa que reaproveite identificador de
intenção, sanções somem em silêncio.

**Correção (mínima).** `conferirConformidade` + `decidirSobreReserva`, puras, e a
reserva passa a distinguir **três** desfechos — `EXECUTAR`, `REPETICAO`,
`CONFLITO`. `CONFLITO` vira `failed-precondition/intencaoReutilizada` em vez de
sucesso. Os dois call sites passam `impressao`, carregando o que a chave não
carrega. Registro legado sem `impressao` continua convergindo, para não
transformar retry antigo em conflito.

**Regressão.** `functions-moderacao/test/idempotencia.test.js` — 13 casos,
`node --test`, sem Firestore, emulador, relógio real, rede ou CWD. Vermelho antes
(guarda inexistente), verde depois. **Este codebase não tinha script de teste
nenhum**; agora tem `npm test`.

---

### P0-3 · BLOQUEADOR · o Billing não tem ciclo de vida: só validação de compra

**Reprodução.** `functions-billing/` exporta exatamente uma função,
`validarCompraPlay`. Não há consumidor de RTDN (*Real-time Developer
Notifications*) via Pub/Sub, não há job de expiração, não há leitura de
`purchases.voidedpurchases`.

**Causa raiz.** A OS pede onze estados; a implementação cobre dois. `compra
válida` e `evento duplicado` estão sólidos. Os demais não existem:

| estado exigido | situação |
|---|---|
| renovação | o `purchaseToken` da assinatura é o mesmo; o registro está `concedida`, então `decidirSobreRegistroExistente` devolve `JA_CONCEDIDA` e **`vipExpiraEm` nunca é atualizado** |
| cancelamento · account hold · recuperação · expiração | nenhum caminho reavalia o estado depois da compra |
| reembolso · revogação | nada revoga entitlement já concedido |
| fora de ordem · reconciliação posterior | não há eventos, logo não há ordenação nem reconciliação |

`ASSINATURA_VALIDA` (que aceita `ACTIVE` e `IN_GRACE_PERIOD`) só é consultada no
instante da validação e nunca depois.

**Impacto.** Entitlement é *write-only e monotônico*: uma vez `vip: true` em
`usuarios/{uid}`, nada no sistema o remove. Reembolso, cancelamento e expiração
não têm efeito. Para um produto pago é perda de receita direta e um problema de
conformidade com a Play.

Hoje o dano está **contido por acidente**: nada lê o entitlement (P0-1, e
`PerfilService` ainda serve números de demonstração com `statsDemo = true`).
Assim que o consumidor for ligado, o defeito passa a valer em produção — e ligar
o consumidor é justamente a correção de P0-1. **Os dois precisam ser resolvidos
juntos.**

**Correção: NÃO aplicada.** Construir consumidor de RTDN, reconciliação e
expiração é implementação de subsistema, não a "menor correção segura" de §5.

---

### P1-1 · freios de abuso são contornáveis por concorrência

`registrarDenuncia` conta as denúncias da última hora e `bloquearJogador` conta
os bloqueios **antes e fora** da transação:

```ts
const recentes = await db().collection("reports")...count().get();   // fora
const quantos  = await lista.count().get();                          // fora
```

Duas chamadas simultâneas leem a mesma contagem, ambas passam pelo teto e ambas
gravam. `kLimiteDenunciasPorJanela` e `kLimiteBloqueios` podem ser excedidos por
paralelismo. A idempotência **não** cobre isto: são pedidos distintos, com
chaves distintas.

Não corrigido de propósito: a correção exige contador denormalizado lido dentro
da transação, e o comentário do código registra a escolha oposta como
deliberada — mexer nisso é decisão de projeto, não conserto.

### P1-2 · o portão de CI não executa os subsistemas P0 mais recentes

`ci-os-integracao.yml` tem 13 gates: `analyze motor resil encerr torneios
mtorneios integr colarte colfire colkit billing torneiosfn regras`. **Não
executa**:

- `app/test/moderacao/teste_moderacao.dart`
- `app/test/motor/teste_visao_espectador.dart`
- `app/test/rastreabilidade/` (7 arquivos)
- o codebase `functions-moderacao` (a palavra "moderacao" não aparece uma vez no
  workflow — `grep -c` devolve 0)

> **Parcialmente fechado pela OS *Gate de Moderação no CI*.** O último item saiu:
> o workflow ganhou o passo `3e — codebase MODERACAO`, gate `moderacaoemu`,
> bloqueante, que roda `npm run emulador:moderacao` — regras **e** chamadas reais
> às Cloud Functions de moderação, com piso de 45 casos. Com ele, o CI protege as
> três suítes Firebase: **Social** (`socialemu`), **Moderação** (`moderacaoemu`) e
> **Coleções** (`regras`).
>
> Continuam abertos os três primeiros itens (suítes Flutter de moderação,
> espectador e rastreabilidade), o agravante do `NÃO EXECUTADO` que não reprova, e
> o disparo apenas por `workflow_dispatch`.

Agravante de integridade: `NÃO EXECUTADO` **não reprova** o portão (*"só falha em
gate que REALMENTE rodou e falhou"*). Um teste renomeado ou removido deixa o
portão verde. O cabeçalho do próprio arquivo promete o contrário — *"REGRA DURA
DE HONESTIDADE: nada aqui pode sair como NÃO EXECUTADO por erro de descoberta"* —
mas a promessa não tem enforcement.

Somado ao fato de o workflow só disparar por `workflow_dispatch` (o `push` aponta
para `integracao/os-final-backend-flutter`, branch que não existe), o portão de
pré-lançamento é **manual e parcial**.

Não alterei o workflow: uma edição aqui não é verificável nesta sessão (sem merge
na branch padrão, nenhum run acontece).

### P1-3 · o recorte de espectador não tem consumidor de produção nesta árvore

`VisaoEspectador` é referenciado **apenas** por
`app/test/motor/teste_visao_espectador.dart`. `VisaoAssento`, o irmão, é usado
por `motor_partida.dart`. O despacho real vive no servidor Node, que é outro
repositório — e `servidor/SERVIDOR-ESPECTADOR.patch` (na branch de espectador)
não está aplicado aqui.

O risco não é o recorte, que está correto e testado: é o aviso do próprio arquivo
— *"uma segunda cópia dessa lista no backend divergiria na primeira mudança de
regra"*. `segredos()` existe em Dart para o servidor consultar; enquanto o
servidor não consumir o bundle, existe uma segunda definição de "o que é segredo"
fora deste repositório, sem teste que as compare.

### Pré-existente · 4 suítes dependem de staging de seeds

`colecoes/evidencias_visuais_test.dart`, `colecoes/kit_pioneiros_test.dart`,
`torneios/motor_torneios_test.dart` e `torneios/reward_grants_test.dart` leem
`test/<área>/data/*.seed.json`, caminho que só existe depois do staging que o CI
faz em `app_build/`. Localmente falham no *load*. Não é regressão do merge — é
dependência de CWD, a mesma que §4 proíbe em teste novo.

---

## D. Testes

Todos os comandos abaixo rodaram nesta máquina, em `homologacao/p0-integrada-a90557`.

| suíte | comando | testes | ✓ | ✗ | skip |
|---|---|---|---|---|---|
| Dart (completa) | `flutter test` em `app/` | **507** | 507 | 0 | 0 |
| regras Firestore (as três, um só `firestore.rules`) | `firebase emulators:exec --only firestore --project demo-bmv "cd firebase/testes && npm run test:integrado"` | **71** | 71 | 0 | 1 suíte |
| Billing (Functions) | `npm test` em `functions-billing/` | **13** | 13 | 0 | 0 |
| Moderação (Functions) — **novo** | `npm test` em `functions-moderacao/` | **13** | 13 | 0 | 0 |
| Torneios (Functions) | `npx tsc --noEmit` em `functions/` | typecheck | exit 0 | — | — |

**Total: 604 testes, 604 aprovados, 0 falhos.**

Observações honestas:

- Os 507 do Dart exigiram staging **temporário** dos seeds (`app/data/*/*.json` →
  `app/test/*/data/`), que o CI faz em `app_build/`. Sem o staging são
  `503 ✓ / 4 ✗ no load` — as 4 falhas pré-existentes descritas acima. O staging
  foi desfeito e a árvore ficou limpa; nada dele foi commitado.
- A suíte `claimPioneerKit` de `seguranca.test.js` fica **SKIP**: exige o
  emulador de Functions, e eu rodei `--only firestore` (provar regras não requer
  compilar o bundle Dart→JS). Está declarado, não escondido.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: **42 issues, 0 erros**,
  todos **pré-existentes** e todos na camada visual (`main.dart`, `mesa.dart`,
  `screens/*`) — imports não usados, campos não referenciados e `withOpacity`
  deprecado. Nenhum arquivo que eu toquei produz issue. **Nenhum erro novo.**
- Ambiente do emulador nesta máquina: `java` não está no PATH; usei o JBR do
  Android Studio (`JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`),
  workaround que o cabeçalho de `moderacao.test.js` já documenta.
  `firebase-tools` 15.26.0.

### Teste novo criado

Um só arquivo, para um risco concreto — §4 pede para não inflar contagem.

`functions-moderacao/test/idempotencia.test.js` (13 casos). Garantia protegida:
**uma chave de intenção descreve uma operação; pedido divergente é CONFLITO,
nunca sucesso silencioso.** Puro: recebe o documento como dado, sem Firestore,
emulador, relógio, rede ou CWD. Vermelho antes da correção, verde depois.

---

## E. Git

| | |
|---|---|
| branch final | `homologacao/p0-integrada-a90557` |
| commit final | o commit **deste documento**, terceiro da lista abaixo |
| upstream configurado | **não** (`no upstream configured`) |
| branch remota | **não existe** |
| hash remoto | não se aplica |
| merge para `main`/`consolidacao`/qualquer branch compartilhada | **NÃO FEITO** |
| deploy / publicação | **NÃO FEITO** |
| branches de outras sessões | **intocadas** — nenhum `reset`, `rebase` ou limpeza fora deste worktree |

Commits desta OS:

```
d10170b  merge: base integrada da homologacao P0 (rastreabilidade + moderacao)
77eff2d  fix(moderacao): intencao reaproveitada nao pode responder sucesso silencioso
   HEAD  docs(homologacao): matriz P0, defeitos e evidencias do portao integrado
```

Base: `c2e34ad`. Ancestral comum das duas frentes reunidas: `1dc26dd`.

Nota de ambiente: o `git` desta máquina recusa o worktree por *dubious
ownership* (F: não registra ownership). Trabalhei com `-c safe.directory=*` por
comando, **sem** alterar o `.gitconfig` global da usuária.

---

## Critério de encerramento

> *"As garantias críticas continuam válidas quando os módulos Buraco Master VIP
> interagem entre si?"*

**Não — e o portão P0 não está aprovado.**

O que se sustenta é substancial: autoridade do servidor, idempotência do motor,
recorte de espectador, proteção de identidade do denunciante, crédito único sob
concorrência e a união das regras (71/71) resistiram ao cruzamento. Onde os
módulos se tocam por **contrato de dados**, não.

Os dois bloqueadores são a mesma fratura vista de dois lados: **não existe um
ponto de verdade sobre o estado do jogador.** Billing escreve `usuarios/{uid}`,
moderação escreve `playerModeration/{uid}`, e o consumidor de torneios lê
`players/{uid}` — coleção que ninguém preenche. Disso decorre que uma sanção não
impede inscrição (P0-1) e que um entitlement, quando alguém finalmente o ler,
nunca expira (P0-3).

Nenhum dos dois é conserto de linha: os dois exigem decisão de contrato, e por
§5 foram reportados em vez de executados em silêncio. **P0-1 e P0-3 devem ser
resolvidos juntos** — ligar o consumidor sem o ciclo de vida troca "VIP que não
funciona" por "VIP que não expira".
