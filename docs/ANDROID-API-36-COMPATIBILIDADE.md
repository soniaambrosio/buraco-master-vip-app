# Compatibilidade com Android API 36 (Android 16)

Auditoria e ajuste minimo do alvo Android. Nenhuma dependencia foi atualizada,
nenhum comportamento de Billing foi tocado, nenhuma tela mudou.

## O ponto de partida: o `android/` nao existe no repositorio

Este projeto nao versiona o projeto host do Android. Os tres workflows montam o
projeto na hora com `flutter create` e aplicam remendos sobre o scaffold:

| workflow | artefato |
|---|---|
| `build.yml` | APK de teste (`applicationId` `.poc`, keystore de teste) |
| `release-aab.yml` | AAB oficial da faixa de Teste interno da Play |
| `ci-os-integracao.yml` | so analyze + suites, nao gera artefato |

Consequencia direta: **a versao pinada do Flutter e quem define o alvo Android.**
Nao ha `build.gradle` no repositorio onde ler `targetSdk`.

## Toolchain efetivo (Flutter 3.44.8, pinado nos tres workflows)

Valores lidos em `packages/flutter_tools/lib/src/android/gradle_utils.dart` e
`gradle/src/main/kotlin/FlutterExtension.kt` na tag `3.44.8`:

| item | valor |
|---|---|
| Gradle | 9.1.0 |
| Android Gradle Plugin | 9.0.1 |
| Kotlin (KGP) | 2.3.20 |
| Java / JDK | 17 (temurin, definido nos workflows) |
| `compileSdk` | 36 |
| `targetSdk` | 36 |
| `minSdk` (padrao do Flutter) | 24 |
| NDK | 28.2.13676358 |

Pisos do `DependencyVersionChecker` em 3.44.8: Gradle >= 8.7 (aviso < 8.14),
AGP >= 8.6 (aviso < 8.11.1), KGP >= 2.0 (aviso < 2.2.20), Java >= 17,
`minSdk` erro < 23 / aviso < 24. O ambiente atual esta acima de todos os pisos.

## O que ja estava certo

- **`targetSdk` ja resolvia para 36**, herdado de `flutter.targetSdkVersion`.
- **Nenhum codigo nativo Android no repositorio** — zero `.kt`, `.java`,
  `AndroidManifest.xml` ou `.gradle` versionado.
- **Nenhum `PendingIntent`, `BroadcastReceiver`, service ou notificacao** no
  codigo do app. Toda a superficie de componentes vem do merge de manifestos dos
  plugins (Firebase, Play Services, Billing, AndroidX).
- **Edge-to-edge obrigatorio (API 36 removeu o opt-out):** o app nao usa
  `SystemChrome` em lugar nenhum e nao existe `windowOptOutEdgeToEdgeEnforcement`
  no projeto — nao ha nada para desfazer. As telas ja usam `SafeArea`.
- **Restricao de orientacao ignorada em tela grande (API 36):** o app nao chama
  `setPreferredOrientations`, entao nao depende de trava de orientacao.
- **`android:exported` explicito (exigido desde a API 31):** garantido por
  construcao — o AGP reprova o build quando falta, e o build passa.

## O que mudou

`targetSdk` deixou de ser herdado e passou a ser **fixo em 36** no remendo do
Gradle dos dois workflows que geram artefato.

O motivo esta na propria documentacao do campo em `FlutterExtension.kt`:

> targetSdkVersion should always be the latest available stable version.

Ou seja, o valor **anda sozinho** a cada bump do canal stable. `targetSdk` decide
comportamento de runtime e e o numero que a Play cobra: subir a versao pinada do
Flutter mudaria o alvo do artefato enviado a loja sem nenhuma revisao. Fixar
transforma isso numa decisao explicita.

`compileSdk` continua herdado **de proposito** — ele precisa acompanhar o SDK e
os plugins, e `compileSdk >= targetSdk` e a configuracao correta.

Alem do remendo, `release-aab.yml` ganhou um portao que le o `targetSdkVersion`
do manifesto **real dentro do AAB** (via `bundletool dump manifest`), depois do
merge com os manifestos de todos os plugins. O `build.gradle.kts` declara a
intencao; so o manifesto do bundle prova o resultado.

## Plugins que podem impedir a API 36 (registro, sem alteracao)

Nenhum destes bloqueia hoje. Todos sao risco **futuro**, e o que os mantem vivos
sob o AGP 9 e o `android.newDsl=false` que o scaffold do Flutter escreve em
`gradle.properties`. No dia em que esse flag virar `true` (ou sumir), estes
quebram:

| plugin | versao | risco |
|---|---|---|
| `audioplayers_android` | 5.2.1 | Maior risco. Usa `kotlinOptions { }` (DSL legada), `apply plugin: 'kotlin-android'`, `compileSdk 35` **fixo no codigo** (nao segue `flutter.compileSdkVersion`) e o plugin Gradle `de.mannodermaus.android-junit5:1.7.1.1`, muito antigo para o Gradle 9. |
| `google_sign_in_android` | 6.2.1 | Usa `lintOptions { }`, removido no AGP 9 em favor de `lint { }`. Depende de `play-services-auth:21.0.0`, a API legada de login. A versao esta **travada exata** (`google_sign_in: 6.2.1`) no pubspec. |
| `jni` | 1.0.0 | Entra por `dependency_overrides`. `compileSdk 35` fixo e `build.gradle` Groovy legado. O override existe porque o `jni` 1.0.1 quebra com "Could not find method kotlin()" — ou seja, ja se esta preso entre duas versoes ruins. |

`in_app_purchase_android` 0.5.0 esta em dia (DSL moderna, `plugins { }`,
`kotlin { compilerOptions }`, `compileSdk = flutter.compileSdkVersion`, Java 17)
e nao oferece risco.

## `minSdk`: o passo do workflow e letra morta

Os dois workflows tem um passo chamado "Bump minSdk to 23 (Firebase)":

```sh
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$f"
```

Ele **nao tem efeito**. O `MinSdkVersionMigration` do proprio Flutter roda no
inicio de `flutter build` e reverte qualquer `minSdk` entre 16 e 23 de volta para
`flutter.minSdkVersion`. Verificado nos dois lados:

- codigo: `tooOldMinSdkVersionEqualsMatch` -> `kotlinReplacementMinSdkText` em
  `lib/src/android/migrations/min_sdk_version_migration.dart` na tag 3.44.8;
- artefato: o APK de release construido nesta OS saiu com `minSdkVersion:'24'`.

O piso real do app e **24 (Android 7.0)**, nao 23. O passo foi mantido como esta:
remove-lo nao muda artefato nenhum, e mexer no `minSdk` e decisao de cobertura de
aparelho, fora do escopo desta OS.

## Verificacao

O build de release local roda desde que o caminho seja curto — num diretorio
profundo o `impellerc` falha por limite de caminho do Windows (`MAX_PATH`), o que
se disfarca de erro de toolchain.

Evidencia do APK de release construido com o `targetSdk` fixado:

```
package: name='com.buracomastervip.poc.buraco_master_vip'
         platformBuildVersionName='16' platformBuildVersionCode='36'
         compileSdkVersion='36' compileSdkVersionCodename='16'
minSdkVersion:'24'
targetSdkVersion:'36'
```

Ressalva honesta: essa verificacao usou o Flutter **3.41.4** da maquina
(AGP 8.11.1), nao o 3.44.8 pinado no CI (AGP 9.0.1). Ela prova que
`targetSdk 36` + `compileSdk 36` compila com este conjunto de plugins e produz o
manifesto correto. Ela **nao** exercita o AGP 9 — e e exatamente ali que moram os
riscos de plugin da tabela acima. A prova sob AGP 9 so sai no CI.
