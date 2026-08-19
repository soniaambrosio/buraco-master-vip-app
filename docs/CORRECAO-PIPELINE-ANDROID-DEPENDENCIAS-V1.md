# Correção cirúrgica do pipeline Android — dependências da base canônica V1

Base: `claude/integracao-splash-rive-constelacao-v1` @ `2ffe4ff`.
Escopo: `.github/workflows/build.yml`. Nada de Play Console, deploy, PR ou `main`.

## O defeito

`build.yml` não conseguia construir a árvore real. Reproduzido antes de mexer em
nada, rodando os passos do próprio workflow sobre a base:

```
flutter create ... app_build
cp -R app/lib/. app_build/lib/
cd app_build && flutter pub add firebase_core firebase_auth "google_sign_in:^6.2.1" \
    audioplayers web_socket_channel shared_preferences "rive:^0.14.11" "flutter_svg:^2.3.0"
flutter analyze --no-fatal-infos --no-fatal-warnings lib
```

→ **26 erros**, todos da mesma família:

```
error - Target of URI doesn't exist: 'package:cloud_firestore/cloud_firestore.dart'
        - lib\colecoes\colecao_firebase.dart:16:8 - uri_does_not_exist
error - Target of URI doesn't exist: 'package:cloud_functions/cloud_functions.dart'
        - lib\sessao\fonte_identidade_firebase.dart:13:8 - uri_does_not_exist
error - Undefined class 'FirebaseFunctions' - lib\sessao\fonte_identidade_firebase.dart:31:30
...
```

A causa não é esquecimento, é **estrutura**: o workflow montava as dependências
a partir de uma lista **digitada** dentro dele. `app/pubspec.yaml` declara
`cloud_firestore`, `cloud_functions` e `firebase_app_check`; a lista do
`build.yml` não. Um pacote novo no repositório só chegava ao APK se alguém
lembrasse de editar também o workflow.

### O segundo defeito, da mesma família

Consertar só as dependências ainda não faria o APK sair. O passo
`Declare assets in pubspec (robusto)` mantinha uma **segunda** lista digitada — a
das pastas de asset — e ela também divergiu: o bloco injetado não continha
`assets/rive/`, mas a trava no fim do mesmo script exigia:

```python
for a in ('assets/splash/', 'assets/rive/', ...):
    assert a in s, f'FALTOU declarar {a} no pubspec!'
```

Ou seja, o passo abortaria em `AssertionError: FALTOU declarar assets/rive/`.
Duas listas digitadas, duas divergências, o mesmo mecanismo errado.

## A correção

`ci-os-integracao.yml` nunca sofreu disso porque não digita lista nenhuma: ele
copia `app/pubspec.yaml` + `app/pubspec.lock` para dentro do scaffold. O
`build.yml` passou a fazer o mesmo.

**Saiu** (203 linhas):

- `Add Firebase + Google Sign-In + Audio deps` — o `flutter pub add` digitado;
- `Deps de TESTE (só dev — não entram no APK)` — o segundo `pub add` digitado;
- `Trava jni em 1.0.0` — remendo Python; o `dependency_overrides` já vive no
  `app/pubspec.yaml`;
- `Declare assets in pubspec (robusto)` — 126 linhas de Python que reinjetavam,
  a cada build, a seção `flutter:` que o `app/pubspec.yaml` já traz pronta.

**Entrou** (138 linhas):

- `Dependências versionadas (pubspec.yaml + pubspec.lock do repositório)` —
  `cp app/pubspec.yaml app/pubspec.lock app_build/ && flutter pub get`.
  O `.lock` entra junto: sem ele dois builds do MESMO commit podem resolver
  versões diferentes.
- `PORTÃO DE DEPENDÊNCIAS` — cada pacote declarado em `app/pubspec.yaml` tem de
  aparecer resolvido no `package_config.json` do scaffold. A lista é **lida do
  repositório**, não digitada; é o que impede o defeito de voltar.
- `PORTÃO DE ASSETS` — cada pasta declarada no `flutter:` do pubspec tem de
  existir e ter conteúdo no scaffold. Mesma ideia, outro lado: asset que falta
  não é erro de compilação, é tela quebrada no celular de quem instalou.
- `Copy VIP table preview assets` e `Copy Pioneiros 2026 collection assets` —
  as duas pastas que o pubspec declarava e nenhum passo copiava.

**Mudou de lugar, sem mudar de conteúdo:** `Copy official animated splash assets`
e `Copy Rive opening art` subiram para junto das outras cópias. Como o pubspec do
repositório declara os assets desde a cópia, tudo tem de existir antes do
primeiro `flutter test`. (`flutter test` tolera pasta declarada e ausente — sai
com 0 e só imprime `unable to find directory entry` —, mas `flutter build apk`
não.)

Versão de pacote nenhuma foi alterada: as versões saem do `app/pubspec.yaml` e do
`app/pubspec.lock` que já estavam no repositório.

## A prova

A bancada foi **gerada a partir do próprio `build.yml` corrigido** (cada passo
`run:` extraído do YAML e executado na ordem), para não haver paráfrase entre o
que se testou e o que a esteira roda. 35 passos executados.

- `flutter pub get` com o `pubspec.lock` do repositório: **lock byte a byte
  idêntico** ao versionado — a resolução é reprodutível.
- `PORTÃO DE DEPENDÊNCIAS`: verde. 13 de produção + 6 de teste + 1 override,
  incluindo `cloud_firestore`, `cloud_functions` e `firebase_app_check`.
- `PORTÃO DE ASSETS`: verde, 15 pastas.
- Os oito portões que já existiam: **todos verdes**, inclusive o
  `PORTÃO DE QUALIDADE — análise estática`, que era onde os 26 erros apareciam.
- `PORTÃO DA ABERTURA`: verde — o `.riv` continua sendo lido pelo bundle com o
  SHA-256 aprovado, mesmo com as cópias adiantadas.
- **APK:** `flutter build apk --release --split-per-abi` saiu verde. Três APKs
  (arm64 110 MB, armeabi-v7a 107 MB, x86_64 112 MB).
- Dentro do APK arm64: 56 cartas, 8 sons, 23 do perfil, 25 do ranking, 10 selos,
  11 da tela início, 8 de configurar mesa, 2 da mesa VIP, 10 da coleção
  Pioneiros; `.riv` e `.svg` com os SHA-256 aprovados; `librive_native.so`
  empacotada. As três dependências que faltavam aparecem como classes no dex
  (`io/flutter/plugins/firebase/{firestore,functions,appcheck}`).
- **AAB:** o `build.yml` **não tem passo de AAB** — gerar bundle é outra frente
  (ver `claude/android-aab-production-build-*`). Como a OS pedia a prova "se o
  pipeline suportar", ela foi feita fora do workflow, sobre a MESMA árvore:
  `flutter build appbundle --release` → `app-release.aab`, **145,5 MB**.
  A primeira tentativa morreu com `Gradle build daemon disappeared unexpectedly`
  (daemon com `-Xmx8G` nesta máquina, logo depois do build do APK); repetindo com
  `org.gradle.jvmargs=-Xmx4G` no scaffold saiu verde em 372 s. É pressão de
  memória da máquina, não da árvore — o `gradle.properties` alterado é o do
  `app_build` gerado, e nada disso encostou no repositório.

### O que a bancada local não cobre

- Flutter local é **3.41.4**; o CI pina **3.44.8**. A bancada prova o mecanismo e
  a árvore, não a resolução byte a byte do CI.
- Três passos do workflow usam `python3`, que não existe nesta máquina. Os de
  assinatura (`keystore`, `key.properties`, patch do `build.gradle.kts`) foram
  **pulados** — esta OS não os tocou, e o APK local saiu com a assinatura padrão
  do Flutter. Os de `Impeller` e `launch screen` foram rodados por um porte fiel
  em Node (`porte_py.js` da bancada), incluindo a trava que compara a cor nativa
  com `contrato_da_abertura.dart`.
- `flutter pub get` sai com código 1 **nesta máquina** por causa do aviso
  `Building with plugins requires symlink support` do Windows; a resolução
  completa normalmente (`Got dependencies!`) e o portão seguinte confirma. Em
  `ubuntu-latest` o aviso não existe.

## Achado que fica em aberto

O APK ficou em ~110 MB por ABI. Os assets declarados pesam **82,3 MB**
descomprimidos, concentrados em quatro pastas:

| pasta | peso | arquivos |
|---|---|---|
| `colecoes/pioneiros_2026` | 26,0 MB | 10 |
| `torneios/premiacao/selos` | 19,1 MB | 8 |
| `torneios/premiacao/coroas` | 18,6 MB | 7 |
| `torneios/capas` | 12,0 MB | 5 |

São PNG sem redução. Três dessas quatro pastas já eram copiadas e declaradas
antes desta correção; a coleção Pioneiros (26 MB) entrou agora, porque o
`app/pubspec.yaml` a declara. **Nada aqui foi decidido por esta OS** — o peso é o
que o repositório declara. Reduzir arte é outra frente, e é o único caminho para
o APK caber no limite de 100 MB da Play. O AAB medido, **145,5 MB**, também não
tem folga: encosta no teto de 150 MB que a Play aceita para o bundle.
