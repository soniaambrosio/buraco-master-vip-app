# Consolidação Firebase — espinha única, três codebases

OS "Integração Final Backend ↔ Flutter". Executado em 10/08/2026 sobre
`integracao/os-final-backend-flutter`. Complementa o mapa em
[`OS-INTEGRACAO-MAPA-FIREBASE.md`](OS-INTEGRACAO-MAPA-FIREBASE.md).

Nenhum merge integral. As três branches foram tratadas como fontes seletivas e
seguem intactas.

---

## 1. Árvore final

```
firebase.json                    <- manifesto ÚNICO, três codebases
.firebaserc                      <- projeto "buraco-master-vip" (origem: billing)

firebase/
  firestore.rules                <- UNIÃO dos três conjuntos
  firestore.indexes.json         <- UNIÃO (3 do kit + 14 de torneios = 17)
  README.md
  functions/                     [codebase colecoes]  index.js, package.json
  scripts/seed_pioneiros_2026.js
  testes/                        harness de segurança (rules-unit-testing)

functions-billing/               [codebase billing]   index.js, idempotencia.js, test/
functions/                       [codebase torneios]  src/*.ts, tsconfig.json

app/pubspec.yaml                 <- fonte da verdade das dependências
app/pubspec.lock
app/lib/colecoes/                8 arquivos
app/data/colecoes/               4 seeds
app/test/colecoes/               4 suítes + evidências
app/assets/colecoes/pioneiros_2026/   10 artes
```

## 2. `firebase.json`

Um só, na raiz. Regras e índices em `firebase/`; **três codebases, três sources,
nenhum `default`**:

| codebase | source | runtime | particularidade |
|---|---|---|---|
| `colecoes` | `firebase/functions` | nodejs20 | — |
| `billing` | `functions-billing` | nodejs20 | diretório movido (ver §5) |
| `torneios` | `functions` | nodejs20 | `predeploy`: `build:domain` (Dart→JS) e depois `build` (tsc) |

Verificado por script: sources únicos, codebases únicos, nenhum `default`
remanescente. O `predeploy` de Torneios foi preservado na ordem original — o
`domain.ts` não carrega sem o bundle.

## 3. Origem de cada bloco de Rules

O arquivo final é **união**, não escolha. Os blocos são disjuntos em caminho.

| Coleção | Leitura | Escrita | Autoridade | Origem |
|---|---|---|---|---|
| `config/{doc}` | autenticado | negada | Cloud Function (Admin SDK) | kit-pioneiros |
| `campaigns/{id}` | autenticado | admin | claim `admin` | kit-pioneiros |
| `campaigns/{id}/eligible/{uid}` | `get` dono ou admin; `list` só admin | negada | Cloud Function | kit-pioneiros |
| `collections/{id}` e `/items/{id}` | autenticado | negada | Cloud Function | kit-pioneiros |
| `users/{uid}/inventory/{id}` | dono ou admin | `create`/`delete` negados; `update` só do campo `equipped`, booleano | Cloud Function | kit-pioneiros |
| `users/{uid}/campaign_claims/{id}` | dono ou admin | negada | Cloud Function | kit-pioneiros |
| `audit/{id}` | admin | negada | Cloud Function | kit-pioneiros |
| `usuarios/{uid}` | dono | dono, **menos** `vip`,`vipExpiraEm`,`vipProdutoId`,`vipAtualizadoEm`,`fichas`,`fichasAtualizadoEm` | Cloud Function de compra | billing |
| `compras/{chave}` | dono do registro | negada | Cloud Function de compra | billing |
| `configuracao/{doc}` | autenticado | negada | console/admin | billing |
| `tournaments/{id}` | autenticado | admin | claim `admin` | torneios |
| `.../editions/.../registrations/{userId}` | dono ou admin | `create`/`update` do próprio, sob forma estreita; `delete` negado | motor + Functions | torneios |
| `.../phases`, `tables`, `results`, `standings`, `conclusion` | autenticado | negada | Cloud Functions | torneios |
| `tournamentHistory/{id}` | autenticado | negada | Cloud Functions | torneios |
| `rewardGrants`, `annualQualifications`, `closingInvites` | conforme bloco de origem | negada | Cloud Functions | torneios |
| `tournamentTasks`, `tournamentAudit` | admin | negada | Cloud Functions | torneios |
| `/{documento=**}` | negada | negada | — (fecho explícito) | torneios |

**Auxiliares unificados.** As origens traziam os mesmos três predicados com nomes
diferentes e **ambas declaravam `autenticado()`** — declarar duas vezes não
compila. Os pares foram mantidos como sinônimos de corpo único
(`ehDono`≡`souEu`, `ehAdmin`≡`admin`), para que cada bloco continue literalmente
igual ao da origem e a união seja conferível linha a linha.

**`config/` × `configuracao/`: NÃO normalizados.** Os dois têm consumidor real e
guardam coisas diferentes — `config/featureFlags` (lido por
`colecao_firebase.dart` e por `claimPioneerKit`) e `configuracao/billing` (mapa
de produtos, lido pela função de compra). Nomes parecidos, conceitos distintos.

**Identidade, como decidido:**

- `users/{uid}` = **identidade canônica do aplicativo**;
- `usuarios/{uid}` = **namespace legado temporário, exclusivo do Billing**.

Não há dual-write, não há espelhamento, nada replica um no outro, e a função de
Billing não foi alterada para trocar de coleção. A eliminação de `usuarios/` é
migração separada, com OS própria. Está escrito no cabeçalho do
`firestore.rules` para quem chegar depois.

## 4. Functions por codebase

| codebase | função | tipo |
|---|---|---|
| colecoes | `claimPioneerKit` | `onCall` |
| colecoes | `grantPioneerEligibility` | `onCall` |
| colecoes | `revokePioneerKit` | `onCall` |
| billing | `validarCompraPlay` | `onCall` |
| torneios | `inscreverEmTorneio` | `onCall` |
| torneios | `cancelarInscricaoTorneio` | `onCall` |
| torneios | `receberResultadoPartida` | `onCall` |
| torneios | `consolidarConvitesDaTemporada` | `onCall` |
| torneios | `responderConviteEncerramento` | `onCall` |
| torneios | `tickTorneios` | `onSchedule` |
| torneios | `aoConcluirEdicao` | `onDocumentCreated` |

Nenhuma HTTP aberta. O UID vem sempre de `request.auth.uid`.

## 5. Billing permaneceu funcionalmente idêntico

A única mudança foi de **empacotamento**, obrigatória porque o codebase de
Torneios já ocupa `functions/`: o diretório passou a ser `functions-billing/`.

Comprovação por hash de conteúdo (`git hash-object`) contra a origem
`feat/play-billing-aab-interno:functions/`:

| arquivo | resultado |
|---|---|
| `index.js` | **byte a byte idêntico** |
| `idempotencia.js` | **byte a byte idêntico** |
| `test/idempotencia.test.js` | **byte a byte idêntico** |

`package.json` recebeu **uma única linha**: o script `"test"`, que não existia e
por isso os testes não estavam ligados a nada. Nenhuma dependência, runtime ou
regra mudou. Preço, entitlement, economia, regra de compra e idempotência não
foram tocados — nenhum dos arquivos que os contêm mudou um byte.

Testes de Billing: **13 verdes** (`node --test`, exit 0), sem emulador.

## 6. Dependências Flutter

`app/pubspec.yaml` e `app/pubspec.lock` passaram a ser versionados, vindos de
`claude/kit-pioneiros-2026-1b56ed`. O projeto declara o que importa; o CI não
resolve mais versões na hora. Saíram do workflow o `flutter pub add` e o remendo
Python que travava o `jni` — o `dependency_overrides` do pubspec faz isso.

Dependências declaradas: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`cloud_functions`, `firebase_app_check` (integrado e **desligado**),
`google_sign_in`, `audioplayers`, `web_socket_channel`, `shared_preferences`,
`cupertino_icons`; em dev, `flutter_lints`, `crypto`, `fake_cloud_firestore`.

**Preservação medida, não presumida:** a lista de assets de origem **não** tinha
`assets/mesa_vip/`, que `mesa_vip_preview_screen.dart` carrega em duas telas. A
linha foi acrescentada — sem ela as duas artes sumiriam do bundle sem nenhum erro
de compilação avisar.

**O lock não foi regenerado.** `flutter pub get` resolveu o lock do kit **sem
alterar um byte** nesta toolchain (Flutter 3.41.4 / Dart 3.11.1), conferido por
`diff`. Nenhuma incompatibilidade a reportar.

## 7. Resultado dos testes

### 7.0 `flutter analyze` — árvore real e scaffold

Depois da limpeza da §10, o analyze passou a ser rodado **sobre a árvore real do
pacote** (`cd app && flutter pub get && flutter analyze`), sem overlay e sem
excluir arquivo nenhum.

| | Árvore real `app/` (antes da limpeza) | **Árvore real `app/` (agora)** | Scaffold `app_build` |
|---|---|---|---|
| **errors** | 16 | **0** | 0 |
| warnings | 13 | 13 | 13 |
| infos | 45 | 29 | 92 |
| total | 74 | **42** | 105 |
| exit | 1 | **0** | 0 |

**Gate do bloco atendido: 0 errors.** Os 13 warnings e 29 infos são
pré-existentes, todos em `main.dart`, `mesa.dart` e `lib/screens/` — nenhum em
`lib/motor`, `lib/integracao`, `lib/torneios` ou `lib/colecoes`, e nenhum
introduzido por esta OS.

A diferença de infos entre árvore real (29) e scaffold (92) **não é código**: é
conjunto de lints. O scaffold herda o `analysis_options.yaml` do
`flutter create`; `app/` não tem esse arquivo, embora declare `flutter_lints`
como dev dependency.

> **Dívida técnica registrada, não resolvida nesta OS:** falta
> `app/analysis_options.yaml` para ativar o `flutter_lints` que o pubspec já
> declara. Introduzi-lo agora só mudaria a contagem de infos sem melhorar nada
> do que este bloco entrega, então fica anotado como item próprio.

| Suíte | Testes | Resultado |
|---|---|---|
| `teste_motor` | 132 | verde |
| `teste_motor_resiliencia` | 196 | verde |
| `teste_encerramento` | 10 | verde |
| `torneios/reward_grants` | 80 | verde |
| `torneios/motor_torneios` | 179 | verde |
| `integracao/teste_integracao_motores` | 64 | verde |
| `colecoes/colecao_arte` | 14 | verde |
| `colecoes/colecao_firebase` | 18 | verde |
| `colecoes/kit_pioneiros` | 81 | verde |
| `colecoes/evidencias_visuais` | 4 | verde (fora do portão) |
| **Total** | **778** | **778 verdes, 0 falhas, 0 pulados** |

Node: Billing 13 verdes; Torneios `tsc --noEmit` exit 0.

### 7.1 Defeito corrigido: `evidencias_visuais_test` não terminava

A suíte ficava presa em "did not complete" até o timeout de 10 minutos, sem
gravar PNG. Causa: `boundary.toImage()` e `toByteData()` são operações reais do
engine e estavam **fora** do `tester.runAsync` — no relógio falso do teste elas
nunca completam. O `precacheImage` logo acima já estava dentro de `runAsync`; a
captura ficou de fora. Corrigido, roda em ~1 s.

Provavelmente nunca havia sido executada: como push não dispara CI neste
repositório, a suíte da branch de origem nunca teve execução real.

## 8. Emulator Suite — EXECUTADO

A primeira medição registrou "não há Java nesta máquina". Estava incompleta: o
**JBR que acompanha o Android Studio** serve, e foi usado apenas como ferramenta
de execução (`JAVA_HOME`/`PATH` na sessão), sem instalar nada nem alterar o
repositório.

| Item | Versão |
|---|---|
| Java | OpenJDK **21.0.9** (JBR do Android Studio) — o emulador exige 11+ |
| Firebase CLI | **15.26.0** |
| Emulador Firestore | cloud-firestore-emulator **v1.22.0** |
| Node | v24.14.0 |

Comando exato:

```bash
firebase emulators:exec --only firestore,auth,functions --project demo-bmv \
  "set FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 && cd firebase\testes && npm test"
```

### 8.1 Compilação das Rules: **PASSOU**

O emulador carregou, compilou e **avaliou** `firebase/firestore.rules`. A prova
não é indireta: as negações no log citam `@ L426`, e a linha 426 do arquivo
unido é exatamente o fecho `allow read, write: if false`. As regras foram
exercitadas contra ~19 asserções reais de permissão, não apenas parseadas.

### 8.2 Functions: **11 carregadas, as três codebases**

```
colecoes  claimPioneerKit, grantPioneerEligibility, revokePioneerKit
billing   validarCompraPlay
torneios  inscreverEmTorneio, cancelarInscricaoTorneio, receberResultadoPartida,
          tickTorneios, aoConcluirEdicao, consolidarConvitesDaTemporada,
          responderConviteEncerramento
```

O `predeploy` de Torneios foi executado de verdade: `dart compile js` produziu o
bundle (162.838 caracteres) e o `tsc` compilou (`--noEmit` exit 0). A cadeia
declarada no `firebase.json` está validada ponta a ponta.

### 8.3 Testes de segurança: 19 no total, **15 verdes, 4 vermelhos**

| Bloco | Testes | Resultado |
|---|---|---|
| inventário: o cliente não concede itens | 5 | verdes |
| inventário: isolamento entre jogadores | 4 | verdes |
| elegibilidade | 3 | verdes |
| catálogo e campanha | 2 | verdes |
| `claimPioneerKit` | 5 | 1 verde, **4 vermelhos** |

Nenhum pulado.

### 8.4 Três defeitos encontrados ao rodar isto pela primeira vez

O harness nunca havia sido executado — push não dispara CI neste repositório, e
a branch de origem não tinha outra forma de rodá-lo. Três problemas apareceram em
sequência, cada um escondendo o seguinte:

1. **`PROJETO` fixo** (`buraco-master-vip-testes`) não batia com o `--project` do
   emulador. As chamadas de Cloud Function iam para um projeto não servido: 404,
   entregue pelo SDK como `not-found`, reprovando o bloco inteiro sem tocar em
   regra nenhuma. **Corrigido**: sai de `GCLOUD_PROJECT`, que `emulators:exec`
   exporta.
2. **`admin.firestore.FieldValue` indefinido sob o emulador.** As duas formas são
   equivalentes em produção, mas o runtime do emulador substitui
   `admin.firestore` por um wrapper sem os estáticos do namespace. **Corrigido**
   com a importação modular, em commit isolado e autorizado.
3. **Fixture da campanha incompleto** — este **não** foi corrigido, por decisão
   de escopo. Ver §8.5.

### 8.5 Os 4 vermelhos restantes: fixture, não produção

```
Value for argument "data" is not a valid Firestore document.
Cannot use "undefined" as a Firestore value (found in field "collectionId").
  em gravarItens — firebase/functions/index.js:286
```

`gravarItens` grava `collectionId: campanha.collectionId`. O seed de produção
(`app/data/colecoes/campanha_pioneiros_2026.seed.json`) **tem**
`"collectionId": "pioneiros_2026"`. O fixture do harness monta o documento da
campanha com `campaignId`, `version`, `status`, `eligibilityMode`, `featureFlag`
e `rewardIds` — **sem `collectionId`**.

É a mesma classe do defeito do `eligibilityMode`: o fixture é uma réplica
incompleta do documento real, e a função está correta. Nada aqui indica falha em
produção. A correção é uma linha no fixture, e **foi deixada para autorização**.

Progresso medido: o erro de `serverTimestamp` desapareceu por completo do log
(0 ocorrências) e a execução avançou até este ponto.

## 9. Correção obrigatória do CI

O workflow reportava "artefatos presentes, porém sem harness" porque procurava
apenas `<dir>/emulator-tests` ou um script `test` em `<dir>/functions/package.json`
— e o harness real vive em `firebase/testes/`. Isso era **erro de descoberta
disfarçado de NÃO EXECUTADO**, exatamente o que não pode acontecer.

O workflow novo:

- descobre cada codebase por **caminho fixo declarado**, sem sondagem;
- roda os três separadamente: `billing` (`npm test`, sem emulador), `torneios`
  (`tsc --noEmit`), `colecoes` (regras + Functions no Emulator Suite);
- publica uma tabela por gate com **EXECUTADO / FALHOU / NÃO EXECUTADO**, e o
  NÃO EXECUTADO sempre acompanhado do motivo real;
- usa o `pubspec.yaml`/`lock` versionados em vez de `pub add`;
- copia `app/assets` **excluindo `*.dart`** (ver §10).

## 10. Limpeza dos sete `.dart` órfãos — registro antes da remoção

Sete arquivos `.dart` estavam versionados fora de `app/lib` e `app/test`. Todos
entraram por commits **"Add files via upload"** — upload pela interface do
GitHub, sem estrutura de pastas — entre 27 e 30/07/2026, antes de todo o
trabalho de motor. **Nenhum é referenciado**: não há `import`, e nenhum `.yml`
de workflow menciona os `.dart` vizinhos. Os sufixos `_1` são a assinatura de
reenvio duplicado.

Este é o registro exigido antes da remoção (§21). O histórico do Git preserva
integralmente todas as versões, inclusive as que divergiam do canônico, então
não foi criada cópia separada de nenhuma.

| # | Caminho | Commit de origem | SHA do blob | Equivalente canônico | Comparação | Referenciado | Motivo da remoção |
|---|---|---|---|---|---|---|---|
| 1 | `app/assets/loja_categoria_screen.dart` | `fec5700` (30/07) | `a7c052a3` | `app/lib/screens/loja_categoria_screen.dart` (`a7c052a3`) | **idêntico** | não | cópia órfã byte a byte; causava 8 dos 16 errors do analyze |
| 2 | `app/assets/loja_categoria_screen_1.dart` | `9add150` (30/07) | `a7c052a3` | idem (`a7c052a3`) | **idêntico** (e ao #1) | não | reenvio duplicado do #1; outros 8 errors |
| 3 | `main.dart` (raiz) | `eaef82c` (27/07) | `4c1c13c3` | `app/lib/main.dart` (`4c8aea6e`) | **diverge** (41 vs 2020 linhas) | não | fragmento antigo fora da árvore do pacote; versão preservada no Git |
| 4 | `.github/workflows/main.dart` | `ea1bd0c` (29/07) | `4f2d132a` | `app/lib/main.dart` (`4c8aea6e`) | **diverge** (4198 vs 2020 linhas) | não | `.dart` dentro de `workflows/` não tem função; versão preservada no Git |
| 5 | `.github/workflows/screens/como_jogar_screen.dart` | `ea1bd0c` (29/07) | `9c6ba8f5` | `app/lib/screens/como_jogar_screen.dart` (`9c6ba8f5`) | **idêntico** | não | cópia órfã em diretório de workflows |
| 6 | `.github/workflows/screens/configuracoes_screen.dart` | `ea1bd0c` (29/07) | `dae0b4ba` | `app/lib/screens/configuracoes_screen.dart` (`66d69fa8`) | **diverge** (955 vs 930 linhas) | não | versão antiga em diretório de workflows; preservada no Git |
| 7 | `.github/workflows/screens/loja_screen.dart` | `ea1bd0c` (29/07) | `816b2859` | `app/lib/screens/loja_screen.dart` (`816b2859`) | **idêntico** | não | cópia órfã em diretório de workflows |

**Nenhum equivalente canônico de `app/lib/` foi tocado.** Os hashes acima
provam quais sobreviveram: `a7c052a3`, `4c8aea6e`, `9c6ba8f5`, `66d69fa8`,
`816b2859`.

Efeito medido no `flutter analyze` sobre a árvore real (`app/`), antes e depois:
**16 errors / exit 1 → 0 errors / exit 0**. Os 16 vinham exclusivamente de #1 e
#2; os outros cinco estão fora do pacote Flutter e nunca eram analisados.

Com a remoção feita, a exclusão de `*.dart` na cópia de assets do workflow deixa
de ser necessária como solução e permanece apenas como salvaguarda barata contra
reincidência do mesmo tipo de upload.

## 11. Onde isto para

Conforme instruído, **nada de migração `usuarios/` → `users/`**. A duplicação
está documentada, delimitada e sem espelhamento. Preços, Billing funcional,
entitlement VIP, economia, regras de compra, Motor de Partidas, Motor de
Torneios, Fluxo de Mesas e UI não foram alterados.
