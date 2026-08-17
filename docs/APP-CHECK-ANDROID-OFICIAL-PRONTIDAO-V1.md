# CANONIZAÇÃO DO APP FIREBASE ANDROID OFICIAL E PREPARAÇÃO DO APP CHECK — V1

**Natureza:** código e portões. **Nada foi ativado fora do repositório.** Nenhum
provider foi registrado, nenhum enforcement foi ligado, nenhuma SHA foi
cadastrada, nenhum token de depuração foi criado ou publicado, nenhum deploy e
nenhum upload foram feitos.

**Repositório:** `soniaambrosio/buraco-master-vip-app`
**Base funcional:** `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`
**SHA da base:** `6e428e8575e2df4a504148a948305838cf3ff2d4`
**Branch entregue:** `claude/app-check-android-oficial-prontidao-v1-33249b`
**Referência documental:** `auditoria/app-check-prontidao-v1 @ 4c118c9`
**Data:** 17/08/2026

---

## 1. Gate Zero

| # | Exigência | Resultado |
| --- | --- | --- |
| 1 | Confirmar todas as refs por `ls-remote` | **OK** — as quatro batem com a OS, ao caractere (§1.1) |
| 2 | Divergências entre a base e as entregas Android | **OK** — nenhuma das duas descende da base; medidas em §1.2 |
| 3 | Consultar em leitura os registros Android do Firebase | **OK** — três consultas, todas GET (§1.3) |
| 4 | Registro oficial corresponde a `io.github.soniaambrosio.buracomastervip` | **OK** — e é **único** |
| 5 | `appId` oficial terminado em `b1cd95ba` | **OK** — `1:203886484007:android:b1cd95baa0b9e6e629cc02` |
| 6 | Estado do App Check e das SHA-256 | **SHA-256: NÃO CONFIGURADA. App Check: NÃO VERIFICÁVEL** (§1.4) |

Não houve mais de um registro oficial plausível, então a OS prosseguiu.

### 1.1 As refs, conferidas

```
6e428e8575e2df4a504148a948305838cf3ff2d4  refs/heads/integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1
4c118c931495201f4425d02a9f5d22b3549583a6  refs/heads/auditoria/app-check-prontidao-v1
005940469aad011adc461b0653cf359fa87acbd7  refs/heads/claude/android-aab-production-build-ea6bbc
7e77cfe45f83bd547740c3fabd92aab965dbb02f  refs/heads/claude/android-api-36-compat-a62a58
```

O worktree nasceu no `main` placeholder (`fb9edb5`) e foi reposicionado em
`6e428e8` **antes** de qualquer edição.

### 1.2 As duas referências Android — conferidas, não incorporadas

Nenhuma das duas contém a base. `merge-base` das duas com `6e428e8` é
`f9814f95`, e `git merge-base --is-ancestor 6e428e8 <ref>` responde **não** para
ambas. Elas removem `functions-social/` e `functions-ranking/` **inteiros**
(−52.931 e −54.309 linhas): mesclá-las apagaria as duas codebases que publicam
as callables que este aplicativo consome. **Não foram incorporadas.**

O que foi **aproveitado delas como conhecimento**, e confere com o console:

| Achado | Onde | Uso nesta OS |
| --- | --- | --- |
| `BMV_APPLICATION_ID: io.github.soniaambrosio.buracomastervip` | `release-aab.yml:70` de `0059404` | confirma o alvo de §2 |
| `BMV_FIREBASE_APP_ID: 1:203886484007:android:b1cd95baa0b9e6e629cc02` | `release-aab.yml:73` | confirma o `appId` oficial |
| `namespace` pode divergir de `applicationId` | `preparar_release.dart:205` | é o que permite **não** mover a `MainActivity` (§2.2) |

Note-se que **o `main.dart` daquela branch também aponta para `…734aaa61…`**
(`0059404:app/lib/main.dart:64`): a identidade do cliente nunca foi corrigida em
lugar nenhum. Esta OS é a primeira a corrigi-la.

### 1.3 O registro oficial, medido

`firebase apps:list ANDROID --project buraco-master-vip` devolve quatro
registros; `apps:sdkconfig ANDROID 1:203886484007:android:b1cd95baa0b9e6e629cc02`
devolve, para o oficial:

```
project_id    buraco-master-vip
package_name  io.github.soniaambrosio.buracomastervip
api_key       AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ
```

Projeto, pacote e `appId` conferidos **antes** de a configuração ser versionada,
como a OS §3 exige. A `api_key` é a mesma que o arquivo já usava — o que mudou é
só o `appId`.

### 1.4 SHA e App Check

`firebase apps:android:sha:list 1:203886484007:android:b1cd95baa0b9e6e629cc02`:

| SHA Id | Hash | Tipo |
| --- | --- | --- |
| `7a2b3a64c44871ad` | `83738c7a9ac9f500ab27491a04ea8bea74abcf6a` | **SHA_1** |

**Uma só, e é SHA-1. SHA-256: NÃO CONFIGURADA.** O provider Play Integrity a
exige. É a pendência de console mais objetiva desta OS (§6).

**App Check: NÃO VERIFICÁVEL.** A CLI do Firebase não expõe comandos de App
Check, e a arbitragem `4c118c9 §6.4` registra que a extração de token de acesso
para chamar `firebaseappcheck.googleapis.com` foi bloqueada pelo classificador
de permissões. **Esta OS não tentou contornar esse bloqueio.** Permanecem `NÃO
VERIFICADO`, item a item, os dez pontos de `4c118c9 §6.4`.

---

## 2. O que mudou

### 2.1 A identidade do cliente — [app/lib/main.dart](app/lib/main.dart)

`appId` `…734aaa61…` (**BMV Teste**, pacote `com.buracomastervip.poc.…`) →
`…b1cd95ba…` (**Buraco Master VIP Oficial**, pacote
`io.github.soniaambrosio.buracomastervip`).

Auth e Functions não conferem o pacote do binário, e é por isso que nada
quebrava. **Play Integrity confere:** a atestação é emitida para um par
(pacote, certificado) e validada contra o registro que o `appId` nomeia.

### 2.2 O App Check

Ativado em `main()`, **entre `Firebase.initializeApp` e `runApp`** — a única
janela que precede toda callable, porque toda callable nasce no `initState` da
raiz, que só roda depois do `runApp`.

O provedor é uma **constante de compilação**:

```dart
const AndroidAppCheckProvider kProvedorDeAtestacao = kReleaseMode
    ? AndroidPlayIntegrityProvider()
    : AndroidDebugProvider();
```

`kReleaseMode` é `const`, então o `?:` é dobrado em tempo de compilação. Esta
forma copia `services/endpoint_servidor.dart:91`, e §4.3 mostra que ela **de
fato** elimina o ramo de depuração do artefato de release.

O `try/catch` é **próprio**, e não o herdado do `initializeApp`: dentro daquele
bloco a falha seria engolida em silêncio; fora de qualquer bloco, um ambiente
sem configuração Android derrubaria o `main()`.

### 2.3 O P0 da Identidade

`MotivoFalhaIdentidade.naoAutenticado` → **`credencialOuAtestacao`**, espelhando
`MotivoFalhaRanking.credencialOuAtestacao`. O transporte deixa de concluir o que
o código recebido não autoriza: sob App Check, `unauthenticated` cobre credencial
inválida, atestação inválida **e** atestação ausente — nas duas últimas a sessão
está viva e repetir resolve.

Quem desfaz a ambiguidade é `EstadoIdentidadeSessao.podeTentarDeNovo`, e a prova
sai do próprio objeto: o estado carrega o `uid`, então `autenticado` **é** o "há
sessão local viva" que `permiteNovaTentativa(haSessaoLocal:)` exige. É o desenho
de `EstadoRanking.daFalha`, sem precisar do parâmetro — aqui a prova já estava
dentro.

**Correção de um ponto da arbitragem.** `4c118c9 §3.5` diz que a falha de App
Check na identidade "vira um beco sem saída, **sem botão**". Medido nesta OS:
[home_de_producao.dart:64-85](app/lib/casca/home_de_producao.dart:64) e
[perfil_page.dart:237](app/lib/pages/perfil_page.dart:237) mapeiam **qualquer**
`FaseIdentidade.falha` para o estado de erro com `onRecarregar` ligado, sem
consultar `podeTentarDeNovo`. **O botão já aparecia.** O que estava errado era o
predicado canônico — o contrato que qualquer consumidor novo leria, e que
`identidade_publica_sessao.dart:95-115` documentava como "não adianta repetir".
O defeito era de contrato, não de tela; corrigi-lo é o que impede a próxima tela
de nascer com o beco sem saída.

### 2.4 O `.poc` saiu do CI

| Arquivo | Antes | Depois |
| --- | --- | --- |
| `.github/workflows/build.yml` | `--org com.buracomastervip.poc` | `--org io.github.soniaambrosio` + `applicationId` oficial |
| `.github/workflows/ci-os-integracao.yml` | idem | `--org io.github.soniaambrosio` |
| `.github/workflows/web.yml` | idem | `--org io.github.soniaambrosio` |
| `build.yml` **na raiz do repositório** | 362 linhas com `.poc` | **removido** (§5.2) |

`--project-name` continua `buraco_master_vip`: é o nome do **pacote Dart**, e
todo `package:buraco_master_vip/...` do repositório depende dele. O `--org`
sozinho não produz `io.github.soniaambrosio.buracomastervip` (daria
`…buraco_master_vip`), então o `applicationId` é ajustado num passo próprio, que
**confere o próprio resultado** e aborta se o alvo não bateu.

O `namespace` **não** é tocado: o Android aceita `namespace != applicationId`, e
alterá-lo obrigaria a mover a `MainActivity.kt` de pacote — passo que falha em
silêncio e produz `ClassNotFoundException` só ao abrir o app. O namespace do
scaffold já está livre de `.poc`, que é o que a OS pede.

Também corrigido de passagem, porque sem isso o `build.yml` **não fecha**:
`cloud_functions` e `cloud_firestore` faltavam no `flutter pub add` embora
`lib/` os importe desde a OS de identidade — o `flutter analyze` daquele
workflow reprovaria por `uri_does_not_exist`. `firebase_app_check` entrou junto.

---

## 3. A matriz

`E` = provado por evidência de artefato ou execução · `S` = estrutural
(varredura de código, comentário-consciente)

| # | Caso | Como | Resultado |
| --- | --- | --- | --- |
| 1 | `Firebase.initializeApp` precede App Check | S | **PASS** |
| 2 | App Check precede `runApp` | S | **PASS** |
| 3 | Nenhuma das três callables sai antes | S | **PASS** — `main()` não menciona `httpsCallable`, `FirebaseFunctions` nem nome de callable; os emissores **alcançáveis** são exatamente 2 |
| 4 | Release escolhe Play Integrity | S + **E** | **PASS** — §4.3 |
| 5 | Debug escolhe só o provedor de depuração | S + E | **PASS** — neste processo (JIT) `kProvedorDeAtestacao` **é** `AndroidDebugProvider` |
| 6 | Release não contém caminho executável de depuração | S + **E** | **PASS no nosso código**, com ressalva registrada em §4.3 |
| 7 | Pacote oficial é único | S + **E** | **PASS** — 1 declarante em `lib/`; manifesto do AAB confirma |
| 8 | `appId` de teste é proibido | S + **E** | **PASS** — 0 ocorrências em `lib/` e 0 no `libapp.so` |
| 9 | CI não produz pacote `.poc` | S + **E** | **PASS** — manifesto do AAB oficial em §4.2 |
| 10 | `unauthenticated` com sessão viva permite retry | E | **PASS** |
| 11 | Retry bem-sucedido recupera a Identidade | E | **PASS** — recusa → `recarregar()` → `publicId` do **mesmo** `uid` |
| 12 | Sessão realmente ausente mantém tratamento próprio | E | **PASS** — `haSessaoLocal: false` nega o retry; e a ausência real é outra **fase** (`naoAutenticado`), não uma falha com botão |
| 13 | Nenhuma falha provoca logout indevido | S + E | **PASS** — `signOut` existe em 1 arquivo, no comando explícito |
| 14 | Nenhum token, chave ou segredo entra no Git | S | **PASS** — §5.1 |

Suíte: [app/test/casca/app_check_identidade_android_test.dart](app/test/casca/app_check_identidade_android_test.dart),
**19 casos, todos verdes**. Mora em `test/casca/` de propósito: é o diretório que
`build.yml` copia inteiro, então a matriz roda nos **dois** portões de CI. Nasceu
como `*_test.dart`, e não `teste_*`, porque o prefixo `teste_` fica fora do glob
padrão do `flutter test`.

### 3.1 Mutações

Cada mutação foi aplicada ao código real, a suíte foi executada, e o `numstat`
foi conferido para provar que a edição pegou — um mutante que não se aplica
mente sobre cobertura.

| Mutação | `numstat` | Suíte | Quem pegou |
| --- | --- | --- | --- |
| **Ordem de bootstrap** — `runApp` movido para antes da ativação | 62+/2− | **18 +, 1 −** | caso 2 |
| **Provider de release** — ramos de `kReleaseMode` trocados | 61+/2− | **17 +, 2 −** | casos 4 e 5 |
| **Pacote** — `kPacoteAndroidOficial` vira o de PoC | 61+/2− | **17 +, 2 −** | casos 7 e 8/9 |
| **`appId`** — oficial trocado pelo BMV Teste | 60+/1− | **17 +, 2 −** | casos 7 e 8/9 |
| **Classificação de erro** — `unauthenticated` volta a ser terminal | 9+/1− | **18 +, 1 −** | tradução do adaptador |
| *(revertido)* | — | **19 +, 0 −** | — |

A mutação de `appId` foi rodada **também** contra o portão de shell do CI, que a
pegou em `app/lib/main.dart:52`.

A quinta mutação revelou uma lacuna real e a fechou: a tradução
`'unauthenticated' => credencialOuAtestacao` não tinha teste nenhum, e o mutante
passaria despercebido. `_traduzir` é privado e o caminho público exige uma
`FirebaseFunctions` de verdade, então a asserção é estrutural sobre a linha da
tradução — o que basta para o mutante morrer.

---

## 4. Portões executados

| Portão | Resultado |
| --- | --- |
| `flutter analyze --no-fatal-infos --no-fatal-warnings lib test` | **0 erros**, 38 issues — a baseline exata da árvore, sem regressão |
| `flutter test` (glob padrão) | **1011 casos, todos verdes** |
| 7 suítes com prefixo `teste_` (fora do glob) | **549 casos, todos verdes** |
| Sessão, Identidade, Ranking, bootstrap, composição | **430 casos** — subconjunto rodado isolado, verde |
| C16 (hash de `main.dart`) | **atualizado e verde** — `8d38beb5…` |
| Build do AAB oficial, **sem upload** | **125,0 MB, verde** — §4.2 |
| Inspeção do manifesto e do `applicationId` | **OK** — §4.2 |
| Busca por pacote/appId antigos | **limpa** — §5.1 |
| Varredura de segredos | **limpa** — §5.1 |
| Portão de identidade do CI (partes locais) | **verde**, e pega a mutação |

**Ressalva sobre as suítes:** quatro delas (`colecoes/evidencias_visuais`,
`colecoes/kit_pioneiros`, `torneios/motor_torneios`, `torneios/reward_grants`)
falham no **carregamento** numa árvore limpa, com `seed nao encontrado:
test/torneios/data/…`. É lacuna de ambiente conhecida — o CI copia os seeds de
`app/data/` para dentro de `test/`. Reproduzida a cópia, as quatro passam; as
cópias **não** foram commitadas.

### 4.1 Uma correção sobre o ambiente

O primeiro build do AAB falhou com `Failed to canonicalize path … OS error 122`
dentro do scratchpad. **Não era o Modo de Desenvolvedor**: era o limite de
comprimento de caminho do Windows. Refeito o mesmo overlay em `C:\Users\sonii\
bmvaab`, o AAB **compilou**. O aviso `Building with plugins requires symlink
support` aparece no `pub get` e **não** impediu o build.

### 4.2 O AAB oficial

Overlay reproduzindo o CI: `flutter create --org io.github.soniaambrosio`, patch
do `applicationId`, `pubspec.yaml`/`.lock` do repositório, `lib/` e 166 assets.

```
√ Built build\app\outputs\bundle\release\app-release.aab (125.0MB)
```

Manifesto extraído de `base/manifest/AndroidManifest.xml`:

| Item | Valor |
| --- | --- |
| package / `applicationId` | **`io.github.soniaambrosio.buracomastervip`** |
| Activity | `io.github.soniaambrosio.buraco_master_vip.MainActivity` (namespace, resolvido por nome completo) |
| Providers | `…buracomastervip.androidx-startup`, `…buracomastervip.firebaseinitprovider` |
| `com.buracomastervip.poc` | **ausente** |

**Nenhum upload foi feito.** O AAB ficou fora do repositório e está assinado com
a chave de **debug** do scaffold — ele serve para provar identidade e manifesto,
e **não** serve para homologar Play Integrity (§6).

### 4.3 O ramo de depuração, medido no artefato

Buscas no `base/lib/arm64-v8a/libapp.so` (o snapshot AOT do nosso código Dart):

| Símbolo | Ocorrências |
| --- | --- |
| `AndroidPlayIntegrityProvider` | **1** |
| `AndroidDebugProvider` | **0** |
| `b1cd95baa0b9e6e629cc02` | **1** |
| `734aaa61ca5ca68b29cc02` | **0** |
| `com.buracomastervip.poc` | **0** |

**A dobra da constante funcionou.** O item 6 da matriz deixa de ser uma promessa
estrutural e passa a ser evidência de artefato: o provedor de depuração **não
existe** no binário de release do nosso código.

**Ressalva, e ela é honesta.** O `classes.dex` **contém** as classes nativas
`com.google.firebase.appcheck.debug` (e `.recaptcha`), porque o plugin
`firebase_app_check` declara esses artefatos do SDK Android como dependência
**incondicional** — não é escolha nossa e não muda com `kReleaseMode`. Elas são
**inalcançáveis a partir do nosso código**: o plugin seleciona o provedor pela
string que o Dart manda, e a única que este binário consegue emitir é
`playIntegrity` (as duas ocorrências no dex). Retirá-las exigiria uma exclusão de
Gradle sobre o plugin — decisão fora do escopo desta OS, e que precisa ser
tomada sabendo que o mesmo plugin as usa no build de depuração.

---

## 5. Varreduras e uma remoção

### 5.1 Limpo

| Busca | Resultado |
| --- | --- |
| `-----BEGIN … PRIVATE KEY` / `"type": "service_account"` em arquivos versionados | **nenhum** |
| `appCheckDebugToken` / `FIREBASE_APP_CHECK_DEBUG_TOKEN` | **nenhum** (só o padrão do próprio portão) |
| Diff desta branch, por assinatura de segredo | **nenhuma linha nova suspeita** |
| `com.buracomastervip.poc` fora de documentação e de portões | **nenhum** |
| `734aaa61` fora de documentação e de portões | **nenhum** |

### 5.2 O `build.yml` da raiz — removido

A varredura achou um **`build.yml` de 362 linhas na raiz do repositório**,
rastreado, subido pela interface web (`Add files via upload`), sem nenhuma
referência, e 463 linhas atrás do `.github/workflows/build.yml` de verdade. Ele
carregava `--org com.buracomastervip.poc` e o `applicationId` de teste.

O GitHub **nunca o executou** — workflows só rodam dentro de
`.github/workflows/`. E é exatamente por isso que ele era perigoso: uma cópia
morta que ninguém roda é uma cópia que ninguém corrige, e era o caminho mais
curto para o `.poc` voltar por copiar-e-colar.

**Foi removido**, e o portão de identidade passou a reprovar qualquer YAML fora
de `.github/workflows/` que carregue os identificadores proibidos. Registro a
remoção em destaque porque ela **não estava na letra da OS**: se a intenção era
preservá-lo como histórico, basta reverter este arquivo.

### 5.3 O portão de identidade

Novo passo em `build.yml`, fail-closed, seis verificações: código Dart do
cliente, `appId` oficial no `main.dart`, `--org` dos workflows, projeto Android
montado, cópias soltas de workflow, token de depuração.

Ele **descarta linhas de comentário** antes de acusar. Sem isso, acusava a
própria documentação: o `main.dart` explica, em prosa, qual era o pacote errado —
e o jeito de "consertar" seria apagar a explicação, que é como o defeito volta.

---

## 6. O que ainda precisa ser feito no Console — **nada disto foi tocado**

Todos exigem ser **Owner** do projeto e são de responsabilidade da Sônia.

| # | Pendência | Onde | Estado medido |
| --- | --- | --- | --- |
| 1 | **SHA-256 da assinatura da Play** no app oficial | Firebase → Configurações → Apps | **AUSENTE.** Só há uma SHA-1 (`83738c7a9ac9…`). O provider Play Integrity **exige** a SHA-256 |
| 2 | **Certificado de homologação** — a SHA do keystore de teste | Firebase → Configurações → Apps | **AUSENTE no app oficial.** Ver §7, é consequência desta OS |
| 3 | **Registro do provider Play Integrity** para `…b1cd95ba…` | Firebase → App Check → Apps | **NÃO VERIFICÁVEL** pela CLI |
| 4 | **Vínculo Firebase ↔ Google Play Console** e Play Integrity API habilitada | Play Console → Vínculos de API; Cloud Console | **NÃO VERIFICÁVEL** |
| 5 | **Validação do AAB** — build assinado com a chave de upload e aceito pela Play | Play Console | **NÃO FEITO.** O AAB de §4.2 tem assinatura de debug |
| 6 | **Smoke test** — instalar por trilha e exercer as três callables com token válido | Aparelho + Firebase → App Check → Métricas | **NÃO FEITO** |
| 7 | **Token de depuração** cadastrado, para o build local | Firebase → App Check → Gerenciar tokens de depuração | **NÃO FEITO.** O token nasce no log do aparelho e **não** vem para o Git |
| 8 | **Decisão de distribuição** — só Play, ou também fora dela | decisão | **PENDENTE.** Determina `PLAY_RECOGNIZED` / `LICENSED` |
| 9 | **Decisão explícita de ativação** do enforcement, um serviço por vez | Firebase → App Check → APIs | **PENDENTE.** Ordem recomendada em `4c118c9 §7`: Cloud Functions primeiro |
| 10 | `ENFORCE_APP_CHECK=true` no codebase `colecoes` | deploy | **PENDENTE**, e **só depois** de a versão com App Check estar publicada |

A assimetria que governa a ordem: **o console reverte em segundos; a Play reverte
em dias.** Ligar o enforcement antes de a versão compatível estar nas mãos das
pessoas recusa quem está numa versão anterior.

---

## 7. Consequência que esta OS introduz, e que precisa de decisão

O `build.yml` produz o APK de teste com o **`applicationId` oficial**, como a
matriz item 9 exige, mas continua assinando com o **keystore de teste**
(`bmv-test`), cujo SHA-1 está registrado no app "BMV Teste" e **não** no oficial.

Enquanto essa impressão digital não for cadastrada no app oficial — ou a trilha
não passar a ser assinada pela chave da Play —, valem duas coisas **neste
artefato de teste**:

1. **O login Google não encontra cliente OAuth correspondente.** O cliente OAuth
   Android do app oficial é o par
   (`io.github.soniaambrosio.buracomastervip`, `83738c7a9ac9…`); o APK do CI
   apresentará esse pacote com outro certificado.
2. **A atestação do Play Integrity não pode ser homologada por ele.** É o mesmo
   ponto que `4c118c9 §6.2` já registrava, e continua verdadeiro.

As duas se resolvem com o item 2 de §6 — uma linha no console. Registro aqui,
em destaque, porque é uma regressão real e imediata na trilha de teste, e a
decisão de aceitá-la ou de cadastrar a SHA antes do próximo build é da Sônia.

**A alternativa que foi descartada, e por quê:** manter o `.poc` no `build.yml`
e criar um pipeline oficial separado (a forma de `claude/android-aab-production-
build-ea6bbc`). Foi descartada porque, com o `main.dart` já apontando para o
registro oficial, um artefato `.poc` volta a ser um binário cuja identidade não
casa com o registro que ele declara — o mesmo defeito de origem, espelhado. A
matriz item 9 da OS é explícita, e ela está certa.

---

## 8. Limites declarados

1. **Nada foi ativado fora do repositório.** As únicas chamadas remotas foram
   três GET da CLI do Firebase (`apps:list`, `apps:sdkconfig`,
   `apps:android:sha:list`).
2. **O estado do App Check no console segue `NÃO VERIFICÁVEL`.** A CLI não o
   expõe, e o bloqueio do classificador registrado em `4c118c9 §6.4` **não foi
   contornado**.
3. **O AAB de §4.2 não é publicável.** Assinatura de debug, sem `minSdk`/
   `targetSdk` decididos e sem ícone de produção — ele prova identidade e
   manifesto, e mais nada. O ferramental que faz um AAB publicável existe em
   `claude/android-aab-production-build-ea6bbc` (`tools/android/`) e **não** foi
   incorporado aqui: incorporá-lo traz signing config, SDKs e ícone, que são
   escopo de uma OS de publicação.
4. **A eliminação do ramo de depuração vale para o nosso código Dart**, provada
   no `libapp.so`. As classes nativas do SDK Android continuam no artefato
   (§4.3).
5. **Nenhum enforcement foi ligado**, então nenhuma das três callables foi
   exercida sob recusa real. Os casos 10 a 13 da matriz são encenados por um
   fake — que é o único jeito: o emulador de Functions **dispensa** App Check por
   construção e não consegue produzir a recusa.
6. **A medição vale para esta branch.** Outras têm topologia diferente:
   `claimPioneerKit`, Firestore direto e Billing podem estar alcançáveis nelas, e
   aí a superfície muda.
