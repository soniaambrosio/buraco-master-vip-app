# Evidência — Crashlytics Android operacional (V1)

- **Base:** `claude/observabilidade-build-recuperacao-v1-f47093` @ `14cf1edb6bd78fccefe3a8ae584ee76bad830e46`
- **Branch:** `claude/crashlytics-android-operacional-v1`
- **Toolchain local:** Flutter 3.41.4 · Dart 3.11.1 (Windows) · Android SDK build-tools 36.1.0
- **Toolchain do CI:** Flutter 3.44.8 (pinado)
- **Aparelho:** emulador `Medium_Phone_API_36.1`, imagem `google_apis_playstore`, x86_64

---

## 1. Aplicativo Firebase canônico

O projeto `buraco-master-vip` (número `203886484007`) tem **quatro** aplicativos
Android registrados. Levantados pela Firebase Management API:

| App ID (parcial) | Display name | Package |
|---|---|---|
| `…android:1a8d6087…` | Buraco Master VIP (Android) | `com.buracomastervip.app` |
| `…android:734aaa61…` | BMV Teste | `com.buracomastervip.poc.buraco_master_vip` |
| `…android:7d871ec4…` | buraco-master-vip Android | `com.mycompany.buracomastervip` |
| **`…android:b1cd95ba…`** | **Buraco Master VIP Oficial** | **`io.github.soniaambrosio.buracomastervip`** |

**Canônico: `1:203886484007:android:b1cd95baa0b9e6e629cc02`.** A autoridade é
demonstrável por três vias independentes: é o único com o package name exigido,
é o único cujo display name diz "Oficial", e é o mesmo App ID que a release
Android já aprovada usa.

> **Armadilha de ferramenta, registrada para não custar a próxima investigação:**
> `firebase apps:sdkconfig ANDROID <appId>` **ignora o `<appId>`** e devolve
> sempre a mesma configuração. Chegamos a concluir, errado, que os quatro apps
> tinham o mesmo package. O caminho confiável é
> `firebase apps:list ANDROID --debug`, que traz o corpo bruto da API com
> `packageName` por app. Um `google-services.json` de projeto traz **todos** os
> apps num arquivo só — é o formato normal, e o plugin Gradle escolhe pelo
> `applicationId`.

---

## 2. GitHub Actions — execução real

O workflow `crashlytics-homologacao.yml` dispara por `push` na própria branch.

> **Correção de uma crença registrada no projeto:** havia a nota de que "o CI só
> dispara por `workflow_dispatch` e workflow novo só roda depois de chegar na
> branch padrão". **É falso para `push`.** Um workflow novo, numa branch de
> trabalho, com `on: push` para essa branch, roda na hora. Confirmado pelos runs
> abaixo, e pelo histórico do repositório (há runs `event: push` em
> `integracao/orientacao-mesa-atualizada`).

| Run | Commit | Resultado | O que provou |
|---|---|---|---|
| [31949119691](https://github.com/soniaambrosio/buraco-master-vip-app/actions/runs/31949119691) | `d244721` | failure | O Secret **existe** (portão passou); a configuração é que estava errada |
| [31949486346](https://github.com/soniaambrosio/buraco-master-vip-app/actions/runs/31949486346) | `7e323c1` | failure | Anotação nomeou a causa exata (abaixo) |

Anotação do run 31949486346, palavra por palavra:

```
o arquivo não declara o pacote `io.github.soniaambrosio.buracomastervip`;
declara 3: com.buracomastervip.app, com.buracomastervip.poc.buraco_master_vip,
com.mycompany.buracomastervip
```

**Diagnóstico:** o Secret `BMV_GOOGLE_SERVICES_JSON_B64` existe e é válido, mas
guarda um `google-services.json` **anterior à criação do app oficial**. Trocar
Secret exige acesso administrativo ao repositório, que esta execução não tem.

O conteúdo de substituição foi preparado localmente, fora do repositório, em
`C:\Users\sonii\bmv-secret\` (o `.json` e a linha base64 de 8192 caracteres).
Nada disso foi versionado nem impresso.

---

## 3. Host Android: plugins aplicados

`app/tool/patch_host_android.dart`, sobre o scaffold do `flutter create`:

```
===== HOST ANDROID =====
applicationId:  io.github.soniaambrosio.buracomastervip
namespace:      io.github.soniaambrosio.buracomastervip
SDKs:           compile 36 · target 36 · min 24
versão:         1.0.0 (143)
plugins:        google-services 4.4.4 · crashlytics 3.0.7
------------------------
MainActivity movida para io.github.soniaambrosio.buracomastervip
PASS — host Android remendado e conferido
```

As versões dos plugins foram conferidas contra o Google Maven antes de fixar
(`google-services` existe até 4.5.0; `firebase-crashlytics-gradle` até 3.0.7).

---

## 4. Inspeção do APK de release

```
package: name='io.github.soniaambrosio.buracomastervip' versionCode='143'
         versionName='1.0.0' compileSdkVersion='36'
minSdkVersion:'24'
```

| Verificação | Resultado |
|---|---|
| SHA do commit dentro de `lib/arm64-v8a/libapp.so` | **presente** (`grep -a -c` = 1) |
| Classes do Crashlytics em `classes.dex` | **presentes** |
| Recurso `string/google_app_id` compilado | **`1:203886484007:android:b1cd95baa0b9e6e629cc02`** |
| Recurso `string/google_crash_reporting_api_key` | presente |
| Marcador do gatilho (build armada) | presente |

O `google_app_id` é a prova que fecha a cadeia: é o valor que o SDK nativo lê em
tempo de execução, então ele responde "para qual painel este APK reporta" sem
depender de nenhuma afirmação nossa.

> **Armadilha, a mesma que já custou um portão quebrado neste repositório:**
> procurar `crashlytics` na **listagem** do zip dá zero sempre — classe Java não
> é arquivo dentro do APK, vive dentro de `classes*.dex`. Um portão escrito
> assim reprova todo build, inclusive o correto. O passo de verificação
> descompacta o dex e procura lá dentro.

---

## 5. Crash controlado, no aparelho, no serviço real

Inicialização (logcat, package oficial):

```
I FirebaseCrashlytics: Initializing Firebase Crashlytics 20.1.0 for io.github.soniaambrosio.buracomastervip
D FirebaseSessions: Fetched settings: {... "app":{"status":"activated" ...},
   "fabric":{"org_id":"6a81c7c5a4407d90ae08acdf",
             "bundle_id":"io.github.soniaambrosio.buracomastervip"} ...}
```

O `Fetched settings` vem do backend do Crashlytics: o SDK está falando com o
serviço real, e o `bundle_id` que ele devolve é o do app oficial.

Disparo do gatilho, 8 s após o arranque:

```
I flutter : CrashDeHomologacao: BMV-HOMOLOG-CRASH
I flutter : #0  GatilhoHomologacao.armarSePedido.<anonymous closure>
            (package:buraco_master_vip/observability/gatilho_homologacao.dart:81)
I flutter : #11 _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:193)
I flutter : (elided 10 frames from class _Timer, dart:async, and dart:async-patch)
```

Envio do relatório, na reabertura do app:

```
I TRuntime.CctTransportBackend: Making request to:
   https://crashlyticsreports-pa.googleapis.com/v1/firelog/legacy/batchlog
I TRuntime.CctTransportBackend: Status Code: 200
```

**HTTP 200 no endpoint de relatórios do Crashlytics.** Duas ocorrências foram
enviadas assim (uma por build, ver §6).

O que procurar no painel (Firebase Console > Crashlytics > **Buraco Master VIP
Oficial**):

- tipo **`CrashDeHomologacao`**
- mensagem contendo **`BMV-HOMOLOG-CRASH`**
- chaves personalizadas `build.sha`, `build.versionCode` (143), `build.branch`,
  `build.ambiente` = `homologacao`
- app version `1.0.0 (143)`

> Aplicativo recém-criado no Crashlytics leva alguns minutos até aparecer na
> lista pela primeira vez; até o primeiro relatório ser processado, o painel
> mostra a tela de onboarding. O `"firebase_crashlytics_enabled":false` nas
> settings é exatamente isso, e não um erro de configuração.

---

## 6. `--split-debug-info` apaga o stack trace — medido

Este é o achado mais consequente desta OS, e ele contraria a premissa com que
começamos.

Duas builds do **mesmo commit**, mudando só essa flag, mesmo aparelho, mesmo
gatilho:

| Build | Stack que chega ao coletor |
|---|---|
| `flutter build apk --release --split-debug-info=build/simbolos` | **vazio** — nenhuma linha |
| `flutter build apk --release` | `#0 GatilhoHomologacao.armarSePedido.<anonymous closure> (package:buraco_master_vip/observability/gatilho_homologacao.dart:81)` |

Com a flag, a ocorrência chega ao painel **sem uma linha de pilha**, o que
equivale a não chegar: responde "quebrou" e não responde "onde".

Consequências, e o que foi decidido:

1. **A build de homologação/produção com Crashlytics não usa
   `--split-debug-info`.** Os nomes ficam no binário, o painel os mostra
   direto, e não há arquivo de símbolo para casar com a build — some uma classe
   inteira de erro operacional (símbolo da build errada produz nomes plausíveis
   e falsos, que é pior que não ter símbolo).

2. **`firebase crashlytics:symbols:upload` não serve para símbolos Dart.** A
   tentativa real falhou assim:

   ```
   i Generating symbols for build/simbolos
   ! An unknown error occurred
   Error: java command failed with args: ... crashlytics-buildtools-3.0.3.jar,
     -symbolGenerator,breakpad, ... -generateNativeSymbols,
     -unstrippedLibrary,build/simbolos ...
   ```

   O comando roda **breakpad** sobre **bibliotecas nativas não-stripadas** —
   é a ferramenta de símbolos de NDK (C/C++). Os arquivos `.symbols` que o
   `--split-debug-info` gera são consumidos por `flutter symbolize`, offline, e
   o Crashlytics não os ingere. Este app não tem código NDK próprio, então não
   há símbolo nativo a enviar.

   Ou seja: a exigência de "upload de símbolos" não se aplica a este app da
   forma como foi escrita. O que substitui é melhor — stack legível de origem.

3. A capacidade de gerar e associar símbolos continua no repositório (o gate da
   OS 3 hasheia o diretório de símbolos no manifesto) e serve a builds que
   priorizem tamanho. Ela apenas deixa de ser o padrão de quem quer painel
   legível.

---

## 7. Defeito encontrado no aparelho — e só nele

O primeiro build instalado subiu, o Crashlytics nativo inicializou, e **o app
não desenhava nada**. No logcat:

```
E flutter : Unhandled Exception: [core/no-app] No Firebase App '[DEFAULT]' has
            been created - call Firebase.initializeApp()
```

Causa: `ColetorCrashlytics()` resolvia `FirebaseCrashlytics.instance` no
construtor, e o coletor é passado como **argumento** de `runBuracoMasterVip` —
argumento é avaliado **antes** da chamada. A exceção acontecia fora da zona
protegida, antes de existir handler nenhum, e derrubava o `main()` inteiro: sem
UI, sem observabilidade, e nada no painel para contar o motivo.

Nenhum teste em Dart pegava, porque em teste o coletor sempre vem injetado e
pronto. Foi preciso um aparelho.

Duas correções, ambas com teste de regressão:

1. A instância do Crashlytics passa a ser resolvida sob demanda, nunca no
   construtor — construir o coletor volta a ser inerte.
2. As portas de captura sobem imediatamente, como antes, mas o coletor real só
   inicia **depois** do `Firebase.initializeApp`. No intervalo os eventos ficam
   num buffer pequeno e limitado e são despejados quando há para onde mandar —
   e é justamente nesse intervalo que mora a falha que ninguém consegue ver, a
   do próprio Firebase não subir.

Correção relacionada: `main.dart` fixava `appId: …734aaa61…` (o app de PoC) no
`FirebaseOptions`, enquanto o `google-services.json` passa a trazer o oficial.
O Crashlytics é nativo e usa a configuração nativa, então os dois discordariam
em silêncio e o painel do app **errado** encheria. No Android o Firebase agora
sobe **sem** `options`, deixando o `google-services.json` ser a única verdade.

---

## 8. `versionCode` determinístico — revalidação

`versionCode = git rev-list --count HEAD`.

| Cenário | Comportamento | Certo? |
|---|---|---|
| Rebuild do mesmo commit | mesmo número | sim |
| Novo commit na mesma linhagem | +1 | sim |
| Histórico com merge | conta todos os ancestrais; nunca diminui ao avançar | sim |
| Branch divergente | **duas branches podem produzir o mesmo número** | não, e é por isso que existe o livro-razão |
| Repetição de número já emitido, com outro SHA | gate **reprova** | sim |
| Regressão | gate **reprova** | sim |

A contagem sozinha **não** é suficiente entre branches divergentes — é uma
propriedade da linhagem, não do repositório. O livro-razão versionado
(`app/data/observabilidade/versioncode_ledger.json`) é o que fecha esse furo, e
ele fecha no code review, não na Play, que é onde não teria volta. Composição
futura de RC herda a mesma proteção: se a RC nascer de outra linhagem e cair num
número já emitido, o gate reprova antes do upload.

---

## 9. Testes

```
flutter analyze lib/observability      → No issues found
flutter test test/observabilidade      → 110 passaram, 1 pulado, exit 0
```

O pulado é o teste de ponta a ponta da identidade, que só roda com
`--dart-define` (ver `docs/OBSERVABILIDADE-EVIDENCIA-V1.md`).

Cobertura acrescentada por esta OS:

- remendo do host Android: plugins na ordem certa, identidade oficial, SDKs
  literais, idempotência, plugin duplicado, e `PatchNaoCasou` quando o scaffold
  muda (13 testes);
- `google-services.json`: ausente, inválido, pacote divergente, App ID
  divergente, projeto errado, sem `api_key`, e a garantia de que nenhuma
  mensagem carrega chave (13 testes);
- gatilho de homologação: desarmado por padrão, sem efeito quando desarmado,
  marcador que sobrevive à redação (6 testes);
- coletor adiado: buffer, teto do buffer, falha ao ligar, idempotência (7).

---

## 10. O que ficou por fora, e por quê

1. **Workflow verde não foi alcançado.** O Secret
   `BMV_GOOGLE_SERVICES_JSON_B64` guarda um `google-services.json` anterior ao
   app oficial, e trocá-lo exige acesso administrativo ao repositório. O
   conteúdo correto está preparado; a troca é uma ação de quem administra.

2. **A confirmação visual no painel do Crashlytics** depende de sessão logada no
   Firebase Console. O envio está provado do lado do aparelho (HTTP 200 no
   endpoint de relatórios); a leitura da ocorrência na tela não foi feita por
   esta execução.

3. **Upload de símbolos não se aplica** — ver §6.2. Não é bloqueio, é premissa
   corrigida.

4. **Flutter local (3.41.4) ≠ CI (3.44.8).** Os APKs desta evidência foram
   compilados com 3.41.4.
