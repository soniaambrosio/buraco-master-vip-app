# Ativação do Billing VIP em produção — V1

O que esta OS fez, o que ela encontrou, e o que continua faltando para a primeira
venda real. Escrito para ser conferível: cada afirmação diz de onde veio.

**Data:** 2026-08-15 · **Projeto:** `buraco-master-vip` (203886484007) ·
**Região:** `us-central1` · **Base de código:** `c9409dc`

---

## Veredito

**O Billing VIP NÃO está pronto para a primeira venda** — e o que falta não é
código nem infraestrutura.

O P0 desta OS foi resolvido: `concederFichasMensais` está implantada. O backend,
o RTDN, o secret, o tópico, o IAM e as Rules estão operacionais e provados. O que
falta é inteiramente **externo e humano**: o produto `master_vip` não existe na
Play Console, e enquanto não existir, `validarCompraPlay` recusa toda compra por
projeto — o que é o comportamento correto, e não um defeito.

A cadeia técnica está fechada. A cadeia comercial não.

---

## A. Arquitetura final

```
  aparelho                    backend (us-central1)              Google
  ─────────                   ────────────────────               ──────
  compra na Play  ──────────► validarCompraPlay ───────────────► Developer API
                              │  consulta, valida, credita       (subscriptionsv2)
                              │
                              ├─► compras/{sha256(token)}        registro histórico
                              ├─► playerEntitlements/{uid}       FONTE CANÔNICA
                              │     └─ interno/billing           token+hash, fechado
                              └─► fichasConcessoes/{hash}_0      parcela de ativação
                                        │
  Play publica RTDN ────────► notificacoesPlay ─────────────────► Developer API
   (tópico play-billing-rtdn)  │  reconsulta e aplica             (reconsulta!)
                               └─► billingEvents/{messageId}      idempotência
                                        │
  relógio (30 min) ─────────► reconciliarEntitlements            fecha vencidos
  relógio (09:00 BRT) ──────► concederFichasMensais              parcelas 1..N
                                        │
                                        └─► fichasConcessoes/{hash}_{i}
                                            + usuarios/{uid}.fichas (mesma transação)

  app lê playerEntitlements/{uid} ──► PortaoVip / EscopoVip ──► UI
  (o app NUNCA concede: só reflete)
```

**A decisão que sustenta o desenho:** nenhum evento é tratado como verdade. RTDN
de renovação, cancelamento, expiração e revogação servem apenas como *gatilho* —
quem responde "qual é o direito agora" é sempre uma reconsulta à Google
(`reconsultarEAplicar`). Por isso evento atrasado, duplicado ou fora de ordem não
corrompe estado: a resposta vem do mundo atual, não do envelope.

---

## B. Estado anterior

Cinco funções implantadas, todas v2 / `us-central1` / nodejs20, deploy de
2026-08-12:

| Function | Trigger | Secret |
|---|---|---|
| `validarCompraPlay` | callable | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `notificacoesPlay` | pubsub `play-billing-rtdn`, retry | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `reconciliarEntitlementDoJogador` | callable | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `reconciliarEntitlements` | scheduled 30 min | — |
| `migrarEntitlementsLegado` | callable | — |

**Divergência real contra o homologado: uma só.** `concederFichasMensais`
ausente. As três ferramentas administrativas (`diagnosticarPopulacaoVip`,
`backfillPurchaseTokenHash`, `diagnosticarMetadadosLegados`) nunca foram
implantadas, o que estava certo.

### Uma leitura minha que estava errada, e a correção

Registrei durante a OS que produção era "uma mistura de dois deploys", porque
conviviam dois `firebase-functions-hash` (`234e20f8` e `91e50512`).

**Estava errado, e a prova é construtiva.** Reimplantei as cinco funções num
único comando, a partir de um único upload de fonte, e elas continuaram exibindo
dois hashes — agora `9a3aaf13` e `cffdf38e`. O hash particiona por **configuração
de secret**, não por geração de código:

- com `PLAY_SERVICE_ACCOUNT_JSON` → um hash;
- sem secret → outro.

A divisão antiga obedecia exatamente à mesma linha. Produção **já correspondia**
a uma única geração de fonte. Fica registrado porque a OS §4 pede o estado
anterior de verdade, e porque um erro de leitura corrigido vale mais documentado
que apagado.

---

## C. Estado final

| Function | Trigger | Secret | hash |
|---|---|---|---|
| `validarCompraPlay` | callable | `PLAY_SERVICE_ACCOUNT_JSON` v1 | `9a3aaf13dc8e` |
| `notificacoesPlay` | pubsub `play-billing-rtdn` | `PLAY_SERVICE_ACCOUNT_JSON` v1 | `9a3aaf13dc8e` |
| `reconciliarEntitlementDoJogador` | callable (admin) | `PLAY_SERVICE_ACCOUNT_JSON` v1 | `9a3aaf13dc8e` |
| `reconciliarEntitlements` | scheduled `every 30 minutes` | — | `cffdf38e340f` |
| **`concederFichasMensais`** | scheduled `every day 09:00` BRT | — | `cffdf38e340f` |

`migrarEntitlementsLegado`: **removida** (`Successful delete operation`).

Total: **5 funções**, todas da mesma linhagem de fonte (`c9409dc`), implantadas
num único comando.

### Correções de código feitas nesta OS

**1. Um `require` que não existia.** `diagnosticarMetadadosLegados` chamava
`criarDiagnosticoMetadados` sem importar `recuperacaoMetadados.js`. Identificador
livre dentro de um handler não é avaliado na carga do módulo: a descoberta do
deploy passa, a função é implantada, e ela quebra com `ReferenceError` na
**primeira invocação**. Ficou latente só porque nunca foi implantada.

**2. `migrarEntitlementsLegado` saiu da superfície.** População legada medida =
zero. Callable de escrita em massa sobre `playerEntitlements/` sem finalidade
remanescente é superfície de ataque pura. O módulo e os testes ficam como
biblioteca dormente — o que foi retirado é a *exposição*.

**3. O alvo de deploy era perigoso.** `firebase deploy --only functions` não é o
codebase de billing: são os **quatro** codebases do `firebase.json`. Um deploy de
billing derrubaria torneios e moderação junto. Agora `npm run deploy:producao`
nomeia as cinco funções uma a uma.

`test/superficieDeploy.test.js` fixa os três. **SUP-01 procura a classe do
defeito 1**, não o caso conhecido: qualquer fábrica `criarX` usada sem estar
ligada falha. Verifiquei que ele falha no fonte anterior (`d00e394`, acusando
`criarDiagnosticoMetadados`) e passa no corrigido — não é teste vazio.

### Um atrito de arquitetura que ficou registrado, não resolvido

Deployar **só** billing dispara os `predeploy` dos codebases de **torneios e
moderação** (`dart compile js` + `tsc`). Um deploy de billing exige, hoje, as
`node_modules` dos outros dois instaladas. Não é defeito de segurança e não
mudei o `firebase.json` por isso — mas é acoplamento real e vai morder de novo.

---

## D. Google Play — o bloqueio

| Plano | productId | basePlanId | Período | Preço Play | Preço aprovado | Estado |
|---|---|---|---|---:|---:|---|
| Mensal | `master_vip` | `monthly_auto` | P1M | — | R$ 19,90 | **NÃO EXISTE** |
| Trimestral | `master_vip` | `quarterly_auto` | P3M | — | R$ 49,90 | **NÃO EXISTE** |
| Anual | `master_vip` | `yearly_auto` | P1Y | — | R$ 149,90 | **NÃO EXISTE** |

`master_vip` ainda não foi criado na Play Console. Consequências encadeadas:

1. `configuracao/billing` não pode ser escrito — escrever antes fixaria IDs que
   ainda podem mudar, e product ID do Google Play é **imutável** depois de criado;
2. `CatalogoBilling.oficial.assinaturas` (`app/lib/billing/catalogo.dart`)
   continua **vazio de propósito** — um ID que não existe faria o app consultar
   produto fantasma. O vazio é comportamento testado (`configurado == false`);
3. `validarCompraPlay` recusa toda compra com `failed-precondition`, porque o
   catálogo do servidor está vazio. **Isso é o desenho, não uma falha.**

### A política de fichas (já decidida, não reabrir)

| Plano | basePlanId | mesesDoCiclo | ativação | mensal |
|---|---|---:|---:|---:|
| Mensal | `monthly_auto` | 1 | 1.500 | 1.000 |
| Trimestral | `quarterly_auto` | 3 | 2.700 | 1.200 |
| Anual | `yearly_auto` | 12 | 6.500 | 1.500 |

Bônus de ativação **uma vez só** (`ativacaoPorCiclo` ausente/`false`). Fixado por
`FICHAS-15`. Brasil, sem trial, sem oferta introdutória.

---

## E. GCP

| Item | Estado | Evidência |
|---|---|---|
| Tópico RTDN | `projects/buraco-master-vip/topics/play-billing-rtdn` | ligado ao trigger de `notificacoesPlay` |
| IAM de publish | funcionando | a Play **publicou de fato** (ver G) |
| Developer API | funcionando | a mesma notificação atravessou |
| Service account de runtime | `203886484007-compute@developer.gserviceaccount.com` | audit log do deploy |
| Índices Firestore | 1: `playerEntitlements(vipAtivo, expiraEm, __name__)` | `firestore:indexes` |

Nenhum índice novo é necessário: a varredura mensal consulta
`where('vipAtivo','==',true)` ordenada por id de documento, servida pelo índice
automático de campo único.

`gcloud` não está instalado nesta máquina, então IAM e tópico não foram
inspecionados por API — foram provados por **comportamento observado**, que é
evidência mais forte que leitura de política.

---

## F. Secrets

| Secret | Versão | Estado | Ligado a |
|---|---|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | 1 | ENABLED | `validarCompraPlay`, `notificacoesPlay`, `reconciliarEntitlementDoJogador` |

Nenhum conteúdo foi lido, impresso ou copiado — só metadados.

**Fato operacional a lembrar:** as funções referenciam `version: "1"`, não
`latest`. Rotacionar o secret **não tem efeito sem redeploy**.

---

## G. RTDN — provado ponta a ponta, antes desta OS

Log de produção, 2026-08-12T16:52:12Z:

```
notificacoesplay: [billing] RTDN ignorada
  { messageId: '20990161317770540', motivo: 'notificacao_de_teste' }
```

Uma notificação de teste real atravessou Play Console → tópico → Pub/Sub →
handler. Isso prova de uma vez: o tópico é o canônico, o IAM permite a Play
publicar, a Play Console aponta para o lugar certo, **e a notificação de teste
não concede VIP** — foi registrada com motivo explícito e efeito nenhum.

Idempotência do handler: `billingEvents/{messageId}` é escrito na **mesma
transação** do efeito, e `eventoConcluido(messageId)` barra reentrega. `retry:
true` no trigger é metade do tratamento de falha transitória; a outra metade é a
exceção subir quando a Developer API falha (`RTDN-11`).

---

## H. Compra controlada — NÃO EXECUTADA

Requer aparelho físico, conta de tester licenciada e o produto criado na Play.
**Nenhuma evidência foi inventada.** Roteiro na seção N.

## I. Benefício mensal — implantado, não exercitado em produção

`concederFichasMensais` está viva e agendada. A idempotência está provada em
suíte, não em produção — porque em produção não há assinante para exercitá-la
(censo = zero).

O que a suíte prova (`FICHAS-*`, `VARR-*`):

- linha determinística `fichasConcessoes/{hash}_{indice}`, criada na **mesma
  transação** que credita `usuarios/{uid}.fichas`;
- `FICHAS-18`: dois ticks **concorrentes** na mesma parcela creditam uma vez só,
  com interleaving real contra contenção otimista;
- `VARR-09/10/11`: reexecução, três execuções seguidas e interrupção no meio não
  duplicam;
- `VARR-13`: prazo vencido não gera parcela mesmo com `vipAtivo: true` gravado;
- `VARR-14`: assinante sem token não vira pagamento — e é **contado**, não
  silenciado;
- `FICHAS-21`: validação e agendador convergem na parcela de ativação (índice 0),
  o que faz o agendador ser rede de segurança da ativação sem código de reparo.

---

## J. Lifecycle

| Evento | Caminho | Prova |
|---|---|---|
| Renovação | RTDN → reconsulta → nova vigência, mesmo token | `mesmoToken` em `decidirAtualizacao` |
| Cancelamento | vigência preservada até `expiraEm`; `renovacaoAutomatica: false` | suíte de entitlement |
| Expiração | `reconciliarEntitlements` fecha por relógio, sem depender de evento | log `varredura de vencimento` |
| Revogação/estorno | RTDN → reconsulta → estado da Google manda | `rtdn.test.js` |
| Expiração com app aberto | `EscopoVip.atual` recomputa vigência | `PVIP-*`, 110/110 |
| Troca de conta | `encerrar()` descarta cache sincronamente | `HOMOLOG-H`, `HOMOLOG-I` |

**Estorno de fichas já creditadas não existe, e isso é deliberado.** Não inventei
política: se a decisão comercial for estornar, é decisão nova.

### Hash ≠ token (§16)

- `purchaseToken`: credencial, só serve para perguntar à Google. Guardado em
  `playerEntitlements/{uid}/interno/billing`, fechado nas Rules **inclusive para
  admin**.
- `purchaseTokenHash`: `sha256(token)`, e **é o id do documento** de
  `compras/{hash}`. Identificador de livro-razão e de idempotência. Nunca
  credencial.

Nenhum ponto do código consulta a Google com o hash. O log usa `rotuloToken`, que
nunca devolve o hash inteiro (`DOC-06`).

---

## K. Testes

| Suíte | Baseline | Final | Falhas |
|---|---:|---:|---:|
| `functions-billing` (`npm test`) | 309 | **314** | 0 |
| Flutter — `test/billing` | 110 | **110** | 0 |
| Flutter — suíte completa | 302 / 4 | **302 / 4** | 4 (pré-existentes) |
| `flutter analyze` | 42 issues / 0 erros | **42 issues / 0 erros** | — |
| Rules | sem alteração | sem alteração | — |

Os 5 testes novos são `SUP-01..05`. Nenhum teste antigo foi removido ou afrouxado.

### As 4 falhas do Flutter, ditas sem maquiagem

Não são regressão desta OS, e a verificação é simples: **nenhum arquivo Dart foi
tocado** — o diff desta OS é `functions-billing/` e `docs/`.

As quatro são o mesmo arquivo falhando ao **carregar**, não a asserção falhando:

```
Failed to load ".../test/torneios/reward_grants_test.dart":
  Bad state: seed nao encontrado: test/torneios/data/assets_registry.seed.json
```

O diretório `app/test/torneios/data/` **não existe na árvore**. É a condição
conhecida de overlay do CI: as seeds vivem fora do repositório e são montadas na
execução. É de torneios, não de billing, e nenhuma suíte de Billing depende dela.

Registro em vez de esconder porque a OS §29 manda não maquiar baseline — mas
também não a conto como dívida desta linha de trabalho.

---

## L. Smoke de produção

| Item | Resultado |
|---|---|
| 5 funções corretas implantadas | ✅ conferido por `functions:list` |
| `concederFichasMensais` presente | ✅ `Successful create operation` |
| `migrarEntitlementsLegado` ausente | ✅ `Successful delete operation` |
| Ferramentas administrativas fora | ✅ nunca implantadas |
| Schedule de vencimento vivo | ✅ log a cada 30 min, `candidatos: 0` |
| Secret acessível | ✅ v1 ENABLED, ligado a 3 funções |
| Tópico RTDN recebendo | ✅ notificação de teste registrada |
| Rules seguras | ✅ sem alteração necessária |
| Catálogo consultável | ❌ **`master_vip` não existe** |
| Compra validada | ❌ depende do catálogo |
| Entitlement real | ❌ depende da compra |

---

## M. Pendências

### Bloqueio externo real (provado, não escolha operacional)

1. **Criar `master_vip` na Play Console** com os três planos-base da seção D.
2. **Escrever `configuracao/billing`** — só depois de (1), com os IDs reais.
   O Firebase CLI não escreve documento; é Console ou Admin SDK.
3. **Colar `master_vip`** em `CatalogoBilling.oficial.assinaturas` e gerar AAB
   novo (`versionCode` 4).
4. **Executar o roteiro da seção N** num aparelho com tester licenciado.

### Registrado, não bloqueante

- Secret pinado em `version: "1"` — rotação exige redeploy.
- Deploy de billing exige `node_modules` de torneios e moderação.
- Node.js 20 será descontinuado em 2026-10-30.

---

## N. Roteiro para o aparelho — o que só a Sônia pode fazer

Pré-requisitos: `master_vip` criado, `configuracao/billing` escrito, AAB com o
catálogo preenchido publicado em **Teste interno**, conta de tester licenciada
(Play Console → Configurações → Teste de licença).

Para acompanhar o backend em qualquer etapa:

```bash
firebase functions:log --project buraco-master-vip -n 50
```

---

### N.1 — Compra real

**No aparelho:** instale pela trilha de Teste interno, entre com a conta de
tester, abra a Loja, escolha **Mensal (R$ 19,90)** e conclua.

**Deve aparecer no app:** os três planos com os preços da seção D; após a compra,
coroa/indicador VIP aceso e salão VIP liberado.

**No backend:** `compras/{hash}` com `estado: concedida`;
`playerEntitlements/{uid}` com `vipAtivo: true`, `planoBase: monthly_auto`,
`expiraEm` ≈ hoje + 1 mês; log `entitlement consolidado na validacao`.

**Evidência que eu preciso:** o bloco de log de `validarCompraPlay`, e print da
tela com o VIP aceso.

**PASS:** entitlement criado com `vipAtivo: true` e plano correto, sem nenhuma
escrita local de VIP.
**FAIL:** `failed-precondition` (catálogo errado), plano divergente, ou VIP
aceso sem documento no backend.

---

### N.2 — Confirmação de ativação (fichas de ativação)

**No aparelho:** confira o saldo de fichas.

**Deve aparecer:** saldo **+1.500** (mensal).

**No backend:** `fichasConcessoes/{hash}_0` com `fichas: 1500`,
`origem: 'validacao'`; log `parcela de ativacao { creditado: 1500 }`.

**PASS:** exatamente uma linha `_0`, saldo subiu exatamente 1.500.
**FAIL:** saldo sem alteração, ou log `plano-base sem configuracao de fichas`
(divergência entre Play e `configuracao/billing` — **pare e me avise**).

---

### N.3 — Repetição / idempotência

**No aparelho:** feche o app **pela lista de recentes**, reabra, entre na Loja.
Se o app reapresentar a compra pendente, deixe validar de novo.

**Deve aparecer:** saldo **inalterado**. VIP continua aceso.

**No backend:** log `parcela de ativacao { creditado: 0, motivo:
'parcela_ja_paga' }` ou `jaProcessada: true`. Continua havendo **uma só** linha
`{hash}_0`.

**PASS:** saldo idêntico ao de N.2 e nenhuma linha nova.
**FAIL:** saldo dobrou, ou apareceu `{hash}_0` duplicado. **Isso é o defeito mais
grave possível deste subsistema — me avise imediatamente.**

---

### N.4 — Renovação

**Na Play Console:** Teste de licença tem renovação acelerada (o mensal renova em
poucos minutos). Aguarde uma renovação.

**Deve aparecer no app:** VIP segue aceso, com `expiraEm` empurrado.

**No backend:** RTDN de renovação em `notificacoesPlay`; `playerEntitlements/{uid}`
com `expiraEm` novo e **o mesmo `uid`** — não pode nascer documento paralelo.

**PASS:** mesma vigência empurrada, mesmo token, nenhuma ficha do mesmo período
duplicada.
**FAIL:** entitlement novo separado, ou parcela creditada de novo no mesmo índice.

---

### N.5 — Cancelamento

**No aparelho:** Play Store → Assinaturas → Buraco Master VIP → Cancelar.

**Deve aparecer no app:** VIP **continua aceso** até a data de término. Cancelar
não tira o direito na hora — é a política vigente.

**No backend:** RTDN de cancelamento; `renovacaoAutomatica: false`, `vipAtivo`
ainda `true`, `expiraEm` inalterado.

**PASS:** direito preservado até o fim do período pago.
**FAIL:** VIP cai na hora do cancelamento.

---

### N.6 — Expiração com app aberto

**No aparelho:** com o app **aberto no salão VIP**, espere passar de `expiraEm`
(com renovação acelerada isso é rápido).

**Deve aparecer:** o salão VIP volta ao estado público **sem refresh manual**;
configuração de mesa VIP é coagida; nenhum rascunho antigo cria `MesaVariant.vip`.

**No backend:** `varredura de vencimento { candidatos: 1, fechados: 1 }`;
`estado: EXPIRADO`, `vipAtivo: false`.

**PASS:** a tela cai sozinha.
**FAIL:** precisa reabrir o app para perder o acesso.

---

### N.7 — Revogação / estorno

**Na Play Console:** Pedidos → localizar o pedido → **Reembolsar e revogar**.

**Deve aparecer no app:** VIP cai.

**No backend:** RTDN de revogação; `vipAtivo: false`. Nenhuma parcela futura é
concedida. **As linhas de `fichasConcessoes` já criadas permanecem** — não há
estorno de fichas, por decisão.

**PASS:** direito cai e nenhuma parcela nova nasce depois.
**FAIL:** VIP sobrevive à revogação, ou um evento antigo ressuscita o direito.

---

### N.8 — Verificação final

**No aparelho:** logout → entre com **outra** conta.

**Deve aparecer:** a segunda conta **não** herda VIP nem fichas. Voltando à
primeira, o direito dela reaparece (vindo do backend).

**No backend:** um `playerEntitlements` por uid, sem cruzamento.

**PASS:** nenhum vazamento entre contas.
**FAIL:** qualquer traço de VIP da conta A visível na conta B.

---

### O que me mandar no fim

Para cada etapa: o trecho de `functions:log`, o print da tela, e o saldo de
fichas antes/depois. Com isso eu fecho os gates §17–§21 com evidência real — e
só com ela.
