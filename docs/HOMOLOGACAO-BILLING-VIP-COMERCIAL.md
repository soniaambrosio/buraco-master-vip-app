# Homologação comercial Google Play Billing ↔ VIP ↔ RTDN

Relatório da OS **HOMOLOGAÇÃO COMERCIAL REAL GOOGLE PLAY BILLING ↔ VIP ↔ RTDN V1**.

## Veredito

> **APROVADA TECNICAMENTE, COM GATE EXTERNO PENDENTE**

O que isso significa, sem maquiagem: **a Billing NÃO está comercialmente
homologada.** Nenhuma compra real foi feita, porque **não existe produto para
comprar** — nem no código, nem no catálogo do servidor, nem (até onde este
relatório pôde verificar) na Play Console. Os quinze itens do gate comercial
(§43 da OS) que dependem de uma transação real continuam **não demonstrados**.

O que foi provado é a outra metade: o código, as regras e a lógica econômica
passam integralmente nos portões determinísticos, **um defeito real de vazamento
de VIP entre contas foi encontrado, reproduzido e corrigido**, e nenhum segredo
está versionado.

Os gates que faltam estão nomeados um a um em §3, com o responsável de cada um.

---

## 1. Base e branch

| item | valor |
|---|---|
| base da OS | `962846ea8fae257d5823e15de1315b4ce1c0f771` |
| branch da base | `integracao/play-billing-flutter` |
| ancestralidade `a2622d5` → `962846e` | **confirmada** (`git merge-base --is-ancestor`) |
| `a2622d5` completo | `a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9` |
| branch desta OS | `homologacao/billing-vip-comercial` |
| criada a partir de | `962846e`, sem merge de nenhuma outra branch |

Conferido antes de começar: `app/lib/billing/` presente com os 8 arquivos
esperados; `functions-billing/` presente com `rtdn.js`, `reconciliacao.js` e
`entitlementStore.js` (a implementação RTDN de `4ef296e`); árvore limpa; hash
remoto de `integracao/play-billing-flutter` idêntico ao local por `git ls-remote`.

A branch de trabalho da sessão nasceu de `main` (`fb9edb5`, o placeholder) e foi
**reapontada** para `962846e` antes de qualquer alteração, como manda §3.

---

## 2. Divergência entre a OS e o estado da árvore — registrada, não resolvida

A OS declara, em §2, que a infraestrutura RTDN **já foi ativada**: tópico
`play-billing-rtdn` criado, Functions v2 implantadas, Eventarc ligado, índice
Firestore READY, notificação de teste da Play atravessando o pipeline e criando
registro em `billingEvents`.

Os documentos da própria base dizem o contrário. `docs/RTDN-VIP-PRODUCAO.md` §13
lista os oito passos de ativação como **pendentes**, e §15 afirma "nenhum evento
real ocorreu" e "deploy: nenhum".

As duas coisas podem ser verdadeiras em momentos diferentes — a ativação teria
acontecido depois de `a2622d5` ser escrito, fora do repositório. **Esta sessão
não tem acesso ao Google Cloud Console, à Play Console nem ao projeto implantado,
e portanto não pode confirmar nem desmentir a ativação.** Nada neste relatório
afirma que a infraestrutura existe; nada afirma que não existe. Fica registrado
como um item que só Sonia consegue fechar, com evidência do console.

O que o código espera, para conferência: tópico `play-billing-rtdn`
(`functions-billing/index.js`, `TOPICO_RTDN`), região `us-central1`,
`applicationId` `io.github.soniaambrosio.buracomastervip`, secret
`PLAY_SERVICE_ACCOUNT_JSON` no Secret Manager, projeto `buraco-master-vip`.

---

## 3. Os quatro bloqueios que impedem a compra real

Estes são os motivos concretos pelos quais o gate comercial não pôde ser fechado.
Nenhum deles é resolvido escrevendo código nesta OS.

### B1 — Não existe produto. Nem ID canônico, nem catálogo. *(decisão comercial)*

§5 da OS pede para identificar qual ID canônico está implementado e eliminar a
divergência entre `vip_master` e `master_vip`. **A resposta é que não há
divergência porque não há ID nenhum.**

Varredura em `app/lib/billing/` e `functions-billing/`: as strings `vip_master` e
`master_vip` aparecem **uma única vez em toda a árvore**, dentro de um comentário
de `catalogo.dart` que as usa como contraexemplo do que não fazer. Nenhum ID de
produto existe em código.

- `CatalogoBilling.oficial` = `const CatalogoBilling()` — conjuntos vazios.
  Com `configurado == false`, o serviço **nem consulta a Play Store**
  (`servico_billing.dart`, `recarregarCatalogo`) e a vitrine mostra `semProdutos`.
- `configuracao/billing` não é criado por esta OS. §6 autoriza criar "somente a
  configuração mínima prevista pelo código existente" — e o código existente lê
  `{ produtos: { "<id>": { assinatura: bool, fichas: int } } }`. **Criar esse
  documento exige os IDs reais**, que só existem depois de os produtos serem
  cadastrados na Play Console. Um documento com IDs inventados faria a validação
  aceitar compras de produtos fantasma, e IDs de produto do Google Play são
  imutáveis. Portanto: não criado, deliberadamente.

Enquanto isso, toda compra é recusada com `failed-precondition` no passo 3 de
`validarCompraPlay` — comportamento correto e testado, e o cliente trata esse
código como **transitório**, de modo que a compra fica pendente e não é queimada.

Para destravar é preciso a decisão comercial que a OS anterior já havia nomeado e
que continua sem dono: quantos planos-base, preço em BRL de cada um, países,
oferta introdutória/trial, benefícios por plano, e se haverá consumíveis de fichas
nesta primeira leva.

### B2 — O módulo Billing não está ligado a nenhuma tela *(consequência de B1)*

Achado desta homologação, e o mais decisivo para o gate §43:

```
grep -rn "ServicoBilling\|EntitlementRepositorio" app/lib --include=*.dart \
  | grep -v "^app/lib/billing/"
→ (nenhum resultado)
```

`app/lib/billing/` tem **zero consumidores** no aplicativo. `app/lib/screens/loja_screen.dart`
continua sendo uma maquete alimentada por `LojaVM.mock()`, com `ehVip` próprio,
sem nenhuma relação com `PainelBilling.mostrarComoVip`.

Consequência direta: **mesmo que os produtos existissem na Play Console e o AAB
estivesse na faixa de teste, não haveria caminho de interface para iniciar uma
compra.** Os casos A, B, C, E, G, H, I e V da OS são inalcançáveis em aparelho por
essa razão, e não por falta de acesso ao Google.

Isto não é um defeito: foi decisão explícita e documentada da OS anterior
(`docs/PLAY-BILLING-CLIENTE-FLUTTER.md` §6), pelo motivo correto — não há preço
nem plano aprovado para montar uma vitrine, e a OS anterior proibia inferir preço
da maquete. Mas é um bloqueio **interno**, e precisa constar como tal: a ligação
da vitrine é trabalho que ainda não foi feito e que só pode ser especificado
depois de B1.

### B3 — O workflow do AAB não pode ser disparado hoje *(infraestrutura do repo)*

§8 exige gerar o AAB de homologação. `.github/workflows/release-aab.yml` existe em
`962846e` e é um workflow completo e auto-verificável (confere `applicationId`,
`versionCode`, `versionName`, a permissão `com.android.vending.BILLING` e a
presença de `com/android/billingclient` dentro do `.aab`, e imprime o SHA-256).

Mas ele é `workflow_dispatch`, e o GitHub só oferece o botão "Run workflow" para
workflows **presentes na branch padrão**. A branch padrão deste repositório é
`main` @ `fb9edb5`, e ela contém **apenas `build.yml`**:

```
git ls-tree --name-only FETCH_HEAD .github/workflows/   # FETCH_HEAD = origin/main
→ .github/workflows/build.yml
```

Logo, **não há como disparar `Release AAB (Teste interno)` hoje**, e portanto não
há AAB, não há SHA-256 de artefato e não há instalação vinda do Google Play.
Isto é consistente com o já registrado em memória do projeto: neste repositório o
CI só dispara por `workflow_dispatch`, e workflow novo só roda depois de chegar à
branch padrão.

Destrava-se levando `release-aab.yml` até a branch padrão — o que esta OS **não
faz**, porque §42 proíbe merge em `main`.

Também é impossível gerar o AAB localmente nesta máquina: `flutter build` falha
por symlink sem o Modo de Desenvolvedor do Windows ativado.

### B4 — Sem produtos e sem AAB distribuído, não há evento RTDN de assinatura real

§15 e §16 pedem RTDN real de ciclo de vida sobre uma assinatura de homologação.
Sem assinatura, não há ciclo de vida. A notificação de teste que a OS declara ter
atravessado o pipeline prova **transporte**, e a própria OS já reconhece isso.

---

## 4. Defeito encontrado, reproduzido e corrigido

**Único achado de código desta OS.** §28 da OS proíbe, em termos explícitos, que
B herde o estado VIP de A pelo cache Flutter. O cliente entregue violava isso.

### Reprodução

`ServicoBilling` guarda o último `EntitlementVip` recebido dentro de
`PainelBilling`, e a interface lê VIP dali (`mostrarComoVip`). `encerrar()` —
o método que um logout dispara — cancelava a escuta, limpava `_iniciando` e
`_emValidacao`, e **deixava o `entitlement` intacto**. Três consequências, todas
observadas em teste antes da correção:

| cenário | comportamento antes | teste |
|---|---|---|
| A é VIP, faz logout (`encerrar()`) | `mostrarComoVip` continua `true` | HOMOLOG-H |
| A faz logout, B faz login (`encerrar()` + `iniciar()`) | **B aparece como VIP** | HOMOLOG-I |
| uma tela já montada escuta `painel` | `encerrar()` não publica nada; o selo de A fica na tela | HOMOLOG-H |

A janela não é teórica. `EntitlementRepositorio.observar(uid)` é um `snapshots()`,
e o primeiro evento de uma escuta nova não é síncrono: entre o login de B e a
chegada do documento dele, a única fonte da interface era o valor que ficou de A.

Agravante de projeto: `PainelBilling.copiarCom` resolve `entitlement ?? this.entitlement`,
então **passar `null` não apaga** — não havia como zerar o direito a não ser
publicando um painel novo, e nada fazia isso.

### Correção

`app/lib/billing/servico_billing.dart`, em `encerrar()`: além do que já fazia,
zera `_entregasNaRestauracao` e `_produtos` e publica `const PainelBilling()`.
Cinco linhas de comportamento. Nenhuma regra econômica tocada, nenhum outro
arquivo de produção alterado.

Publicar (em vez de só mudar o campo) é parte da correção: sem evento, uma tela já
montada continuaria exibindo o selo do jogador anterior mesmo com o estado interno
correto.

Custo aceito e documentado no código: quem religa sendo o **mesmo** jogador (app
voltando do segundo plano) vê um piscar de "não-VIP" até o documento ser relido.
É a direção segura — errar para menos não entrega acesso pago a quem não pagou.

### Regressão

`app/test/billing/troca_de_conta_test.dart`, 6 testes novos (HOMOLOG-H, 3;
HOMOLOG-I, 3). Todos vermelhos antes da correção nos pontos acima, todos verdes
depois. Cobrem também o caminho que **já** funcionava e que a camada de ligação
deve usar: `atualizarEntitlement(EntitlementVip.ausente(novoUid))` sobrescreve um
direito vigente.

---

## 5. Gates automáticos — números reais

| Gate | Comando | Resultado |
|---|---|---:|
| Billing backend — idempotência | `node --test test/idempotencia.test.js` | **13/13** |
| Billing backend — ciclo de vida VIP | `node --test test/entitlement.test.js` | **42/42** |
| Billing backend — RTDN | `node --test test/rtdn.test.js` | **24/24** |
| **Billing backend — total** | `npm test` em `functions-billing` | **79/79** |
| Flutter — suíte descoberta | `flutter test` em `app` | **588/588** |
| Flutter — Billing (`test/billing/`) | `flutter test test/billing/` | **52/52** |
| Flutter — motor de partidas | `flutter test test/teste_motor.dart` | **132/132** |
| Flutter — resiliência do motor | `flutter test test/teste_motor_resiliencia.dart` | **196/196** |
| Flutter — encerramento | `flutter test test/teste_encerramento.dart` | **10/10** |
| Flutter — análise estática | `flutter analyze --no-fatal-infos --no-fatal-warnings` | **42 issues, 0 erros** |
| Functions/TS — torneios | `npx tsc --noEmit` em `functions` | **0 erros** |
| Functions/TS — moderação | `npx tsc --noEmit` em `functions-moderacao` | **0 erros** |
| Regras Firestore (emulador) | `emulators:exec --only firestore` → `npm run test:integrado` | **93/93** |

**Comparação com a baseline de `962846e`:** `flutter test` era 582 e passou a
**588** (+6, os testes novos de troca de conta). `flutter analyze` continua em
**42 issues, 0 erros — idêntico**. `functions-billing` continua **79/79**.
Nenhuma regressão, nenhum teste removido, skipado ou suavizado.

Reconciliação e observabilidade não têm suíte própria e não ganharam uma:
são provadas dentro das suítes acima. Reconciliação em RTDN-11 (falha da Play API
sobe para o Pub/Sub reentregar), RTDN-21 (carimbo capturado antes da rede),
RTDN-09/10 (convergência sob contenção real) e na família DA (14 testes de ordem
e regressão de estado). Observabilidade em RTDN-14 (token ausente nos 4 caminhos
que logam), RTDN-12/12b (o `SyntaxError` que citava o payload), DOC-06 (o rótulo
nunca devolve o hash inteiro) e BILLING-FLUTTER-14 (4 caminhos no cliente).

### Notas de execução

- A porta 8080 estava presa por um emulador Firestore remanescente de outra
  sessão (`java.exe` do JBR do Android Studio, PID 19144). **Ele não foi tocado.**
  A suíte de regras rodou contra um emulador próprio na 8085, via um
  `firebase.homolog-8085.json` temporário que foi removido antes do commit.
- O emulador usou o JDK 21 do JBR do Android Studio.
- Quatro suítes Flutter exigem o overlay de seeds que o CI copia de `app/data/`
  para `test/**/data/`. A cópia foi reproduzida localmente e **removida antes do
  commit** — não está versionada.
- Um teste aparece como `SKIP` na suíte de regras (`claimPioneerKit`): ele exige o
  emulador de Functions, e a execução foi `--only firestore`. É anterior a esta OS
  e não pertence ao domínio Billing.

---

## 6. Cadeia de autoridade — auditada e confirmada

O princípio de §4 da OS está implementado e coberto por teste. O cliente **não
concede VIP** em nenhum caminho.

- `servico_billing.dart` não escreve `playerEntitlements` nem `compras/{hash}`,
  não credita fichas e não consome assinatura. Ele valida, e só finaliza a compra
  na Play Store **depois** de um veredito (`deveFinalizarCompra`).
- `PainelBilling.mostrarComoVip(agora)` **não olha o estado da compra**: pergunta
  ao `EntitlementVip` lido de `playerEntitlements/{uid}`, com o relógio aplicado.
  BILLING-FLUTTER-15 prova os dois lados — validada sem VIP, e VIP sem compra
  nesta sessão.
- `EntitlementRepositorio` só lê. A regra é `allow write: if false` mesmo para o
  dono e para o admin.
- O reconhecimento junto à Google (`acknowledge`/`consume`) é do **servidor**,
  depois de creditar (`fecharComAGoogle`, passo 8 de `validarCompraPlay`).

### Regras do Firestore auditadas

| coleção | leitura | escrita |
|---|---|---|
| `playerEntitlements/{uid}` | dono ou admin | `if false` |
| `playerEntitlements/{uid}/interno/*` | **ninguém** (nem dono, nem admin) | `if false` |
| `compras/{chave}` | só o dono do registro (`resource.data.uid`) | `if false` |
| `billingEvents/{messageId}` | só admin | `if false` |
| `configuracao/{doc}` | autenticado | `if false` |

O `purchaseToken` vive só no documento interno, que nenhum cliente lê — a
separação em dois documentos existe porque regra do Firestore libera o documento
inteiro.

---

## 7. Os casos obrigatórios (§49), um a um

Legenda: **real** = ocorreu no Google Play; **automático** = provado por teste
determinístico; **não observável** = não ocorreu, com a razão nomeada.

| # | caso | situação | evidência / razão |
|---|---|---|---|
| A | catálogo real carregado | **não observável** | B1 + B2 + B3: não há produto, não há vitrine, não há AAB. Caminho coberto por BILLING-FLUTTER-03 (catálogo injetado) e BILLING-FLUTTER-02 (o catálogo **oficial** está vazio) |
| B | compra cancelada pelo usuário | **automático** | BILLING-FLUTTER-04 — finaliza, não concede |
| C | compra legítima | **não observável** | B1/B2/B3 |
| D | validação server-side | **automático** | `validarCompraPlay` passos 3–8; idempotência 13/13; entitlement 42/42. Sem token real, o contrato com a resposta da Google segue provado só contra literais no formato documentado de `purchases.subscriptionsv2` |
| E | concessão VIP | **automático** | CV-01..CV-11, DA-01..DA-14 |
| F | replay / idempotência | **automático** | "duas entregas do mesmo token creditam UMA vez", "reentregas repetidas não acumulam saldo", RTDN-07/07b, BILLING-FLUTTER-10 |
| G | restore | **automático** | BILLING-FLUTTER-11 — o restore passa pela validação e não concede sozinho |
| H | logout | **automático — defeito corrigido** | HOMOLOG-H (novo). Vazava antes desta OS |
| I | troca A → B | **automático — defeito corrigido** | HOMOLOG-I (novo). Vazava antes desta OS |
| J | token inválido | **automático** | passo 5 de `validarCompraPlay`: exceção da Play API vira `unavailable`, **não** marca recusada, nada é concedido. RTDN-12/12b provam que o payload ilegível não vaza conteúdo |
| K | produto divergente | **automático** | passo 3 (`failed-precondition` para produto fora do catálogo) e passo 3.1 (`invalid-argument` para tipo divergente); "titularidade: token registrado para outro produto é recusado" |
| L | replay entre usuários | **automático** | "titularidade: token de outro jogador é recusado" e "titularidade é conferida ANTES do estado" — reconferida **dentro** da transação de concessão |
| M | compra pendente | **automático** | BILLING-FLUTTER-05 — não valida e **não finaliza**; backend recusa `purchaseState != 0` |
| N | RTDN real | **não observável** | B4. Transporte declarado pela OS §2, não verificável desta sessão (§2 deste relatório) |
| O | redelivery RTDN | **automático** | RTDN-07 (atalho) e RTDN-07b (barreira transacional, com o atalho neutralizado) |
| P | reconciliação | **automático** | RTDN-11, RTDN-21, RTDN-09/10; `reconciliarEntitlements` (relógio, sem consultar a Google) e `reconciliarEntitlementDoJogador` |
| Q | cancelada dentro do período pago | **automático** | CV-03, RTDN-03 — **continua VIP** até `expiraEm`. `cancelada ≠ expirada` |
| R | expiração | **automático** | CV-04, CV-05, RTDN-04 |
| S | grace / hold | **automático** | CV-02 (carência **mantém** VIP), CV-06 (`ON_HOLD`/`PAUSED` não concedem) |
| T | revogação / reembolso | **automático** | CV-11, RTDN-05, RTDN-06 — terminal tirado do payload, `expiraEm = agora`; DA-08 impede leitura atrasada ressuscitar direito estornado |
| U | recuperação | **automático** | DA-10 (compra nova depois de estorno volta a valer), RTDN-18. Assinatura **não** vira `recusada` no registro do token, justamente para a recuperação não ficar barrada |
| V | reinstalação | **não observável** | B2/B3. Caminho coberto por BILLING-FLUTTER-11 e pela escuta ligada **antes** de qualquer compra, que é o que recebe as reentregas de sessões anteriores |
| W | nenhum segredo versionado | **verificado** | §8 deste relatório |

Nenhum evento real é declarado neste relatório. Onde não ocorreu, está escrito que
não ocorreu.

---

## 8. Segredos

Varredura em toda a árvore versionada por chave privada, `service_account`,
`private_key`, tokens `ya29.`, `GOCSPX-` e arquivos `.env`/`.jks`/`.p12`/`.pem`:
**nenhuma ocorrência**.

Os dois identificadores públicos do Firebase que aparecem em
`app/lib/main.dart` — a `apiKey` do cliente (`AIzaSy…`) e o `serverClientId` OAuth
Web — **não são segredo por projeto**: são identificadores de cliente, protegidos
por regra do Firestore e pela impressão digital do app, e o próprio Google os
distribui dentro do binário. Nenhum deles concede acesso administrativo.

O material que **é** segredo continua fora do repositório e é exigido por portão
no workflow: keystore de upload, `google-services.json` oficial (GitHub Secrets) e
a conta de serviço da Play (`defineSecret('PLAY_SERVICE_ACCOUNT_JSON')`,
Secret Manager). Nenhum `purchaseToken` aparece neste documento.

---

## 9. Firestore — documentos alterados

**Nenhum.** Nenhuma compra real foi processada, nenhuma escrita manual foi feita
em produção, nenhum `configuracao/billing` foi criado, nenhum registro legado foi
tocado e nenhuma migração foi disparada.

---

## 10. Deploy e merge

- **Deploy:** nenhum. Nenhuma Function implantada, nenhuma infraestrutura alterada.
- **Merge:** nenhum. Não houve merge em `main`, em branch de consolidação nem em
  branch de outra sessão.
- **Force push:** nenhum. **Tag:** nenhuma.
- **Play Console:** não tocada. **Produção:** não tocada.
- Nenhuma branch alheia foi alterada e nenhum arquivo de outra sessão foi apagado.

---

## 11. O que fazer a seguir, na ordem que destrava

1. **Decidir e registrar o contrato comercial** (Sonia): planos-base, preço em BRL,
   países, trial/oferta introdutória, benefícios por plano, consumíveis sim/não.
   Nada abaixo é possível antes disto. — *destrava B1*
2. **Levar `release-aab.yml` à branch padrão** para que o `workflow_dispatch`
   apareça. — *destrava B3*
3. Disparar o workflow com `version_code ≥ 3`, baixar o artefato, enviar à faixa
   de **Teste interno** e registrar o SHA-256 impresso pelo próprio build.
4. Confirmar que a Play Console liberou a área de produtos; **se continuar
   bloqueando, registrar a mensagem literal** antes de qualquer improviso.
5. Criar os produtos e base plans, colher os IDs reais.
6. Colar os IDs em `CatalogoBilling.oficial` e publicar `configuracao/billing` no
   formato `{ produtos: { "<id>": { assinatura: bool, fichas: int } } }`.
   Os dois **precisam** listar exatamente os mesmos IDs.
7. **Ligar a vitrine**: substituir `LojaVM.mock()` por `ServicoBilling.painel`,
   `assinaturas` e `PainelBilling.mostrarComoVip`, e chamar `encerrar()` no logout
   (o contrato agora está fixado por HOMOLOG-H/I). — *destrava B2*
8. Confirmar a ativação da infraestrutura RTDN com evidência de console (§2).
9. Só então: compra real de homologação, e reabertura desta OS para os casos
   A, C, N, V e para a linha do tempo de §45, que hoje não tem uma única linha
   preenchível.

---

## 12. Git — fechamento

| item | valor |
|---|---|
| branch | `homologacao/billing-vip-comercial` |
| hash da base | `962846ea8fae257d5823e15de1315b4ce1c0f771` |
| merges na faixa da OS | nenhum |
| arquivos criados | `app/test/billing/troca_de_conta_test.dart`, `docs/HOMOLOGACAO-BILLING-VIP-COMERCIAL.md` |
| arquivos alterados | `app/lib/billing/servico_billing.dart` |
| arquivos removidos | nenhum |

Hash final, hash remoto e a confirmação `local == remoto` estão em §13, escritos
depois do push.
