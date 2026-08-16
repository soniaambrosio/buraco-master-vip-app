# Mapa de arquitetura e origem — Firebase / Auth / Catálogo / Kit Pioneiros

OS "Integração Final Backend ↔ Flutter", bloco de consolidação Firebase.
Levantado em 10/08/2026 sobre `integracao/os-final-backend-flutter`.

**Este documento é só mapa.** Nenhuma linha de código de produção foi escrita, e
nenhuma branch foi mesclada. A regra de parada foi acionada: há conflito entre as
topologias e risco de duplicar a espinha de identidade. A recomendação está na §10
e depende de decisão.

---

## 1. Correção do mapa de branches herdado

O hand-off da OS trazia uma linha errada, e ela precisa ser corrigida antes de
qualquer coisa:

> | Regras de Segurança (§16) | `auditoria/regras-bmv` (conformidade C8/C9) |

`auditoria/regras-bmv` **não trata de regras de segurança do Firestore.** É
auditoria de conformidade do **motor de regras do jogo** entre Dart e o servidor
Node: `auditoria/conformidade/servidor_regras_extraidas.js`,
`servidor_regras_corrigido.js`, `verificacao_bundle_real.js`, modo sombra,
replay, `RELATORIO-C9C-SOMBRA.md`. Não contém `firestore.rules`, `firebase.json`
nem `functions/`. É a linhagem do backend Node/Railway, não do Firebase.

É também a branch **mais recente do repositório** (`4e35594`, 10/08/2026) e ela
**remove** `app/test/torneios/reward_grants_test.dart` e reescreve
`teste_motor.dart` (+3208 linhas) em relação a `consolidacao/apk-geral-bmv` — ou
seja, é uma linhagem divergente que **não** deve ser tocada neste bloco.

As regras de segurança do Firestore e seus testes vivem, de fato, em
`claude/kit-pioneiros-2026-1b56ed` (`firebase/firestore.rules` +
`firebase/testes/seguranca.test.js`).

---

## 2. Não são duas topologias. São três.

| # | Topologia | Branch | `firebase.json` | Rules | Functions | Linguagem |
|---|---|---|---|---|---|---|
| A | `firebase/` inteira | `claude/kit-pioneiros-2026-1b56ed` | `firebase/firebase.json` | `firebase/firestore.rules` | `firebase/functions/` | JS (CommonJS) |
| B | raiz inteira | `feat/play-billing-aab-interno` | `firebase.json` (raiz) | `firestore.rules` (raiz) | `functions/` | JS (CommonJS) |
| C | **híbrida** | `integracao/motores-torneios-partidas-v1` | `firebase.json` (raiz) | `firebase/firestore.rules` | `functions/` | **TypeScript** + bundle Dart→JS |

A topologia C é a que o hand-off não previu: `firebase.json` na raiz apontando
para regras em `firebase/` e functions na raiz. Ela não é "uma das duas": é uma
terceira convenção.

`.firebaserc` existe **só** em B, com `"default": "buraco-master-vip"`. A e C não
declaram projeto.

---

## 3. Colisões diretas de caminho e de codebase

Três colisões, e nenhuma é cosmética:

1. **`codebase` repetido.** A e B declaram ambas `"codebase": "default"`. Duas
   implantações no mesmo codebase do mesmo projeto Firebase se substituem: quem
   fizer `firebase deploy --only functions` por último apaga as funções da outra.
   C usa `"codebase": "torneios"`, então C convive; A e B, não.
2. **`functions/` na raiz disputado.** B e C reivindicam o **mesmo caminho** com
   conteúdos e linguagens diferentes (JS vs TS). Não é merge de arquivo: é o
   mesmo diretório sendo duas coisas.
3. **Regras em dois lugares.** A resolve `firestore.rules` relativo a
   `firebase/`; B resolve na raiz; C aponta explicitamente para
   `firebase/firestore.rules` a partir da raiz. Três arquivos distintos, nenhum
   superconjunto de outro (§5).

---

## 4. Cloud Functions — inventário completo

Nenhuma colisão de **nome** entre os três conjuntos. Essa é a boa notícia do
bloco: o conteúdo é somável, o que briga é o empacotamento.

| Função | Tipo | Topologia | Observação |
|---|---|---|---|
| `claimPioneerKit` | `onCall` v2 | A | resgate do Kit; transação; idempotente por comprovante |
| `grantPioneerEligibility` | `onCall` v2 | A | administrativa |
| `revokePioneerKit` | `onCall` v2 | A | administrativa |
| `validarCompraPlay` | `onCall` v2 | B | valida compra no Google Play (`googleapis`); usa `defineSecret`; idempotência em `functions/idempotencia.js` |
| `inscreverEmTorneio` | `onCall` v2 | C | |
| `cancelarInscricaoTorneio` | `onCall` v2 | C | |
| `receberResultadoPartida` | `onCall` v2 | C | porta de entrada do resultado de partida |
| `tickTorneios` | `onSchedule` | C | agendada |
| `aoConcluirEdicao` | `onDocumentCreated` | C | trigger Firestore |
| `consolidarConvitesDaTemporada` | `onCall` v2 | C | |
| `responderConviteEncerramento` | `onCall` v2 | C | |

**Nenhuma função HTTP aberta (`onRequest`) em nenhuma das três.** Tudo é
`onCall`, `onSchedule` ou trigger. Isso é uma decisão de segurança já tomada e
consistente, e vale preservar.

**C tem um passo de build que as outras não têm:** `predeploy` roda
`build:domain` (`dart compile js -O2 -o functions/lib/domain_bundle.js
app/lib/torneios/js_bridge.dart`) antes do `tsc`. O domínio Dart de torneios é
compilado para JS e consumido pelas Functions. Consolidar C exige levar esse
pipeline junto — ele não é opcional, o `domain.ts` não carrega sem o bundle.

> Nota de campo: existe um `functions/` **não versionado** nesta worktree, com
> `lib/domain_bundle.js` (163 KB) e `node_modules` (1,5 GB). O `.deps` mostra que
> foi compilado **desta própria worktree** em 07/08/2026, quando ela estava na
> branch v1. É resíduo de build, não fonte da verdade, e não deve ser commitado.

---

## 5. Regras do Firestore e coleções

| Topologia | Arquivo | Linhas | Coleções raiz |
|---|---|---|---|
| A | `firebase/firestore.rules` | 121 | `config/`, `campaigns/{id}/eligible/{uid}`, `collections/{id}/items/{id}`, `users/{uid}/inventory/{id}`, `users/{uid}/campaign_claims/{id}`, `audit/{id}` |
| B | `firestore.rules` | 57 | `usuarios/{uid}`, `compras/{chave}`, `configuracao/{doc}` |
| C | `firebase/firestore.rules` | 250 | `tournaments/{id}/editions/{id}/{registrations,phases,tables,results,standings,conclusion}`, `tournamentHistory/{id}` |

C e A são disjuntas (torneios × coleções/inventário). **A e B não são.**

### 5.1 A duplicação da espinha de identidade — o conflito principal

| Conceito | Topologia A | Topologia B |
|---|---|---|
| jogador | `users/{uid}` | `usuarios/{uid}` |
| configuração | `config/{documento}` | `configuracao/{doc}` |

São **duas coleções raiz para o mesmo sujeito**, em idiomas diferentes. Não é
divergência de conteúdo que se resolve com merge de arquivo: é decidir qual nome
é o do produto, e migrar o outro.

Estado de uso, medido:

- `users/{uid}/inventory` e `users/{uid}/campaign_claims` estão **em uso real**:
  `app/lib/colecoes/colecao_firebase.dart` lê e escreve (`_db.collection('users/$uid/inventory')`,
  `_db.doc('users/$uid/inventory/$itemId')`), e `claimPioneerKit` grava.
- `usuarios/{uid}` **ainda não é lido pelo app.** `perfil_service.dart` é
  **idêntico** em `HEAD` e na branch de billing, e nos dois o cabeçalho diz:
  *"FASE 2: trocar a origem por Firestore (`usuarios/{uid}`)"*. Hoje quem escreve
  ali é só a Cloud Function de compra.

Isso é o que torna a decisão possível sem quebrar nada agora — mas é decisão de
produto, não de código, e por isso este bloco para aqui.

---

## 6. Auth e origem do UID

Consistente e sem conflito nas três:

- **Cliente:** `firebase_auth` — `FirebaseAuth.instance.currentUser`,
  `authStateChanges()`, `signInWithCredential` (Google Sign-In). Está em
  `app/lib/main.dart` e `app/lib/services/perfil_service.dart`, já presentes em
  `HEAD`.
- **Servidor:** o UID **nunca** vem do corpo da chamada. Toda função lê
  `request.auth.uid` e recusa com `unauthenticated` se ausente — inclusive
  `claimPioneerKit`. O comentário de `billing_validacao_firebase.dart` diz o
  porquê com todas as letras: *"sem que o app precise mandar um uid — que seria
  falsificável"*.
- **App Check:** integrado em A (`firebase_app_check: ^0.4.6`), **desligado por
  padrão**, com ativação prevista para antes da abertura pública.

Não há segunda origem de identidade. **Nada a consolidar aqui** — só a preservar.

---

## 7. `app/lib/colecoes/` — Catálogo e Inventário

Existe **só** em `claude/kit-pioneiros-2026-1b56ed`. Não há implementação
concorrente em nenhuma outra branch, portanto **não há duplicação de catálogo ou
inventário** — há ausência nas demais.

8 arquivos: `colecao_arte`, `colecao_campanha`, `colecao_catalogo`,
`colecao_firebase`, `colecao_inventario`, `colecao_repositorio`,
`colecao_resgate`, `colecao_ui_contract`.
Dados: `app/data/colecoes/` — `catalogo.seed.json`,
`campanha_pioneiros_2026.seed.json`, `pioneiros_2026.manifest.json`,
`otimizacao_pngs.json`.
Testes: `app/test/colecoes/` — `colecao_arte_test`, `colecao_firebase_test`,
`kit_pioneiros_test`, `evidencias_visuais_test` (+ 4 PNGs de evidência).

`colecao_repositorio.dart` é a porta abstrata e `colecao_firebase.dart` a
implementação Firestore — ou seja, o módulo já nasce com a inversão de dependência
que uma consolidação exigiria.

---

## 8. Kit Pioneiros e `claimPioneerKit`

Fluxo, como está hoje em A:

1. cliente chama `_functions.httpsCallable('claimPioneerKit')`;
2. a função exige `request.auth.uid`;
3. transação lê `campaigns/{CAMPAIGN_ID}`, `users/{uid}/campaign_claims/{id}`,
   flags e os itens de `users/{uid}/inventory/{rewardId}`;
4. comprovante existente com `campaignVersion` diferente **não é arbitrado** —
   devolve `failed-precondition` e manda para decisão administrativa;
5. reconciliação de itens faltantes acontece **antes** da checagem de
   elegibilidade, para quem já tem direito não ficar com kit pela metade.

É idempotente por comprovante e por item, e escreve só via Admin SDK — as regras
de A negam escrita do cliente em inventário (`allow create, delete: if false`;
`update` só do campo `equipped`, e só booleano).

---

## 9. Testes de segurança e dependências

**Testes de regras:** existem só em A — `firebase/testes/seguranca.test.js`
(`node --test`, `@firebase/rules-unit-testing ^4.0.1`), com script
`emulador: firebase emulators:exec --only firestore,functions,auth`. Cobrem
inventário (cliente não concede item, só alterna `equipped`), isolamento entre
jogadores, elegibilidade, catálogo/campanha e auditoria. O bloco `claimPioneerKit`
é `skip` sem `FUNCTIONS_EMULATOR_HOST`.
B tem `functions/test/idempotencia.test.js`, mas **sem script `test`** no
`package.json` — não está ligado a nada.
C não tem testes de regras nem de functions.

> Consequência para o nosso CI: o job de Emulator Suite procura
> `<DIR>/emulator-tests` ou um script `test` em `<DIR>/functions/package.json`.
> O harness de A está em `firebase/testes/`, que **nenhum dos dois padrões
> encontra**. Se A for adotada, o workflow precisa aprender esse caminho — hoje
> ele reportaria "artefatos presentes, porém sem harness", que seria falso.

**Dependências Flutter:**

| Branch | `app/pubspec.yaml` | Firebase declarado |
|---|---|---|
| `integracao/os-final-backend-flutter` (destino) | **não existe** | — |
| `claude/kit-pioneiros-2026-1b56ed` | existe, versionado | `firebase_core ^4.13.0`, `firebase_auth ^6.5.7`, `cloud_firestore ^6.8.0`, `cloud_functions ^6.3.6`, `firebase_app_check ^0.4.6`, `google_sign_in 6.2.1` |
| `feat/play-billing-aab-interno` | não existe | — |
| `integracao/motores-torneios-partidas-v1` | não existe | — |

**Isto é estrutural e precisa de decisão explícita.** A branch de destino não tem
`pubspec.yaml`: as dependências são injetadas pelo harness/CI
(`flutter create` + `flutter pub add firebase_core firebase_auth google_sign_in
audioplayers web_socket_channel shared_preferences`), **sem `cloud_firestore` e
sem `cloud_functions`**. Trazer `app/lib/colecoes/` para cá não compila enquanto
isso não mudar — ou o `pubspec.yaml` de A passa a ser versionado aqui, ou o
harness ganha os dois pacotes. Não há terceira opção, e nenhuma das duas é
neutra: a primeira muda como esta branch é construída; a segunda mantém a
dependência invisível no repositório.

Não há `pubspec.lock` versionado em nenhuma das branches.

---

## 10. Para cada duplicação: origem, recência, completude, consumidor, risco, recomendação

### 10.1 `firebase.json` (A × B × C)

- **Origem:** A `claude/kit-pioneiros-2026-1b56ed`; B `feat/play-billing-aab-interno`; C `integracao/motores-torneios-partidas-v1`.
- **Mais recente:** C (07/08/2026). A e B em 06/08/2026.
- **Mais completo:** C — é o único com `predeploy`, `runtime` explícito, `codebase` próprio e emuladores; A também declara emuladores, B não.
- **Consumidores:** nenhum consumidor de código; é configuração de deploy.
- **Risco:** adotar A ou B mantém `codebase: "default"` duplicado entre elas e um `firebase deploy` derruba o outro conjunto de funções. Adotar C sem levar o `predeploy` quebra o build do TypeScript.
- **Recomendação:** **um único `firebase.json` na raiz**, no formato de C (raiz aponta para `firebase/` nas regras), declarando **três codebases distintos** — `colecoes`, `billing`, `torneios` — cada um com seu `source`. Assim nada se sobrescreve e cada frente continua implantável isoladamente.

### 10.2 `firestore.rules` (A × B × C)

- **Origem/recência:** C é a mais nova (07/08) e a maior (250 linhas); A (121) e B (57) são de 06/08.
- **Mais completo:** nenhum é superconjunto — os domínios são **disjuntos**, exceto pela colisão `config`/`configuracao` (§5.1).
- **Consumidores:** A é exercitada por `firebase/testes/seguranca.test.js`; B e C não têm teste de regras.
- **Risco:** escolher "a mais completa" e descartar as outras **remove regra de produção** — sem as de A, o inventário fica sem proteção; sem as de B, `compras/` fica exposta.
- **Recomendação:** **união, não escolha.** Um `firebase/firestore.rules` só, concatenando os três blocos de `match`, que são disjuntos. A única decisão real é `config` × `configuracao` (§10.4).

### 10.3 `functions/` (B × C no mesmo caminho) e `firebase/functions/` (A)

- **Origem:** A JS em `firebase/functions`; B JS em `functions`; C TS em `functions` + bundle Dart.
- **Mais recente:** C (07/08).
- **Mais completo:** C — 7 funções, TypeScript, `onSchedule` e trigger, pipeline de build.
- **Consumidores:** A ← `colecao_firebase.dart` (`claimPioneerKit`); B ← `billing_validacao_firebase.dart` (`validarCompraPlay`); C ← `adaptador_partida_torneio` (já nesta branch) via `receberResultadoPartida`.
- **Risco:** unificar tudo num diretório só obriga a converter A e B para TypeScript **ou** a rebaixar C para JS, perdendo tipagem e o `predeploy`. Qualquer das duas é reescrita de código de produção que hoje está em uso — fora do escopo deste bloco e proibido pelas travas (Billing).
- **Recomendação:** **não unificar diretório.** Três `source` distintos, três codebases: `firebase/functions` (colecoes), `functions-billing/` (billing, movido de `functions/`) e `functions/` (torneios, TS). O único movimento de arquivo é tirar B de `functions/`, e ele é mecânico. Confirma-se depois com um `firebase deploy --dry-run`.

### 10.4 `users/` × `usuarios/` e `config/` × `configuracao/`

- **Origem:** `users`/`config` de A; `usuarios`/`configuracao` de B.
- **Mais recente:** empate (ambas 06/08/2026).
- **Mais completo:** A — tem subcoleções em uso (`inventory`, `campaign_claims`) e teste de regras; B tem só o documento raiz.
- **Consumidores:** `users/` é lido e escrito **hoje** pelo app (`colecao_firebase.dart`) e por `claimPioneerKit`. `usuarios/` **não é lido pelo app**: `perfil_service.dart` ainda é local nas duas branches, com Firestore marcado como "FASE 2". Só a função de compra escreve lá.
- **Risco de escolher uma:** manter as duas é o pior caminho — dois documentos de jogador, duas fontes de verdade de perfil, e a Fase 2 do perfil escolhendo por acidente. Padronizar em `usuarios/` obriga a migrar inventário, comprovantes, regras e testes já validados de A. Padronizar em `users/` mexe no que a Cloud Function de compra escreve — e **Billing/entitlement está explicitamente travado neste bloco**.
- **Recomendação:** **`users/{uid}` como espinha**, por ser a que tem consumidor real, subcoleções e teste. `usuarios/{uid}` vira alias a extinguir. Mas — e por isso o bloco para — **executar isso toca a função de Billing**, que está proibida. O caminho que respeita a trava é: adotar `users/` para tudo que é catálogo/inventário/perfil **agora**, e deixar `usuarios/` intocada até haver autorização para mexer em Billing. Isso é consolidação parcial e precisa da sua aprovação explícita, porque deixa a duplicação viva por um período.
- `config` × `configuracao`: mesmo raciocínio, risco menor — nenhuma das duas tem consumidor no app hoje. Recomendo `config/`.

### 10.5 `app/lib/colecoes/`, seeds e testes

- **Origem:** exclusivamente A. **Não há duplicação.**
- **Risco:** trazer sem resolver a §9 (pubspec sem `cloud_firestore`/`cloud_functions`) não compila.
- **Recomendação:** trazer inteiro, com `app/data/colecoes/` e `app/test/colecoes/`, **depois** de decidida a questão do `pubspec.yaml`.

---

## 11. Onde isto para

Acionada a regra de parada, por três motivos independentes:

1. **Conflito entre topologias** — `codebase: "default"` duplicado e `functions/`
   disputado por dois conteúdos em linguagens diferentes (§3).
2. **Risco de duplicar a autenticação/identidade** — `users/` × `usuarios/`
   (§5.1, §10.4), cuja resolução completa esbarra na trava de Billing.
3. **Decisão estrutural pendente** — a branch de destino não tem `pubspec.yaml`,
   e trazer o módulo de coleções exige escolher entre versionar o pubspec de A ou
   estender o harness (§9).

Nada foi consolidado. As branches seguem intactas e tratadas apenas como fontes
seletivas.
