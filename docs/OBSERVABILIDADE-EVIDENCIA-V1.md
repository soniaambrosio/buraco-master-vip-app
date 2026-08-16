# Evidência — observabilidade, identidade de build e recuperação (V1)

Comandos executados, saídas e exit codes. Tudo reproduzível na máquina de
quem quiser conferir.

- **Base:** `origin/consolidacao/apk-geral-bmv` @ `0cea0d6d68f2c93613b985f4aa85800d77cf42d7`
- **Branch:** `claude/observabilidade-build-recuperacao-v1-f47093`
- **Toolchain local:** Flutter 3.41.4 · Dart 3.11.1 (Windows)
- **Toolchain do CI:** Flutter 3.44.8 (pinado em `.github/workflows/build.yml`)

---

## 1. O que existia antes (gate zero)

Levantado sobre o commit da base, antes de qualquer edição.

| Item | Situação encontrada | Onde |
|---|---|---|
| Inicialização Firebase | `Firebase.initializeApp` com `FirebaseOptions` no código, dentro de `try { } catch (_) { }` **mudo** | `app/lib/main.dart:49-68` |
| `FlutterError.onError` | **não existe** | — |
| Zona protegida | **não existe** | — |
| `PlatformDispatcher.onError` | **não existe** | — |
| Logs | **zero** ocorrências de `print` / `debugPrint` / `developer.log` em `app/lib/` | — |
| PII em log | nenhuma — porque não havia log nenhum | — |
| `versionName` | nunca definido no repositório; vem do `flutter create` do CI (`1.0.0+1`) | `.github/workflows/build.yml:50` |
| `versionCode` | `${{ github.run_number }}` | `.github/workflows/build.yml:232,290` |
| SHA no artefato | **nenhum** — `GITHUB_SHA` só era ecoado no log do CI | `build.yml:180,188,207` |
| Crash reporting | **nenhum** pacote | — |
| Lockfile | **não existe** — o repositório não versiona projeto Flutter | — |

### Prova de que o `versionCode` era ambíguo

`github.run_number` é um contador **por arquivo de workflow**, não por commit:

1. Recompilar o **mesmo commit** (novo `workflow_dispatch`, ou re-run) produz um
   `versionCode` **diferente** — dois artefatos com numeração distinta e código
   idêntico.
2. Renomear ou recriar o arquivo de workflow **zera** o contador — regressão de
   `versionCode`, que a Play recusa.
3. Se o `sed` do patch de Gradle não casasse, o valor cairia no default do
   `flutter create` (`1`), silenciosamente.

Nenhuma das três é detectável depois da publicação, e nenhuma tem volta.

### Compatibilidade do pacote de crash reporting

Resolução real executada (`flutter pub add firebase_core firebase_crashlytics`):

```
+ firebase_crashlytics 5.2.7
+ firebase_crashlytics_platform_interface 3.8.27
+ firebase_core 4.13.0
+ _flutterfire_internals 1.3.76
```

Restrições declaradas por todos os quatro:

```
environment:
  sdk: '^3.6.0'
  flutter: '>=3.27.0'
```

`^3.6.0` significa `>=3.6.0 <4.0.0`. O Flutter 3.44.8 do CI traz Dart 3.x e é
`>=3.27.0` — **satisfeito nos dois eixos**. A resolução concreta acima foi feita
sob o Flutter 3.41.4 local; a análise de restrição é o que cobre o pin do CI,
já que 3.44.8 é *mais novo* que o local e as restrições são pisos, não tetos.

> **Divergência assumida e declarada:** a máquina local tem 3.41.4 e o CI pina
> 3.44.8. Não foi possível *executar* a resolução sob a versão pinada.

### Trava de versão — o que foi possível, e o que não

O repositório **não versiona `pubspec.yaml` nem `pubspec.lock`**: o projeto
Flutter é criado do zero a cada run (`flutter create app_build`) e as
dependências entram por `flutter pub add`. Não existe lockfile para travar.

A trava aplicada é **restrição de versão exata**, sem `^`:

```yaml
flutter pub add firebase_core "firebase_crashlytics:5.2.7" ...
```

Uma restrição exata fixa a versão daquele pacote de forma tão rígida quanto uma
linha de lockfile. O que ela **não** fixa são as transitivas — e commitar um
`pubspec.lock` gerado sob 3.41.4 para ser aplicado sob 3.44.8 traria risco de
quebrar o APK da OS 1 por incompatibilidade de pacotes de SDK. Ficou de fora
por essa razão, não por esquecimento.

---

## 2. Análise estática

```bash
flutter analyze lib            # overlay do CI, com app/lib/ inteiro
```

| Cenário | Issues | Erros | Avisos novos |
|---|---|---|---|
| Base `0cea0d6`, sem a camada | **105** | 0 | — |
| Branch, com a camada e o `main.dart` novo | **105** | 0 | **0** |

```bash
flutter analyze lib/observability
# No issues found! (ran in 3.1s)
```

Os 105 são infos e avisos pré-existentes do código da base (imports não usados,
APIs depreciadas). **A camada nova não acrescenta nenhum.**

---

## 3. Suíte de testes

Overlay equivalente ao do CI: `flutter create` + `app/lib/` + `app/test/` + as
seeds de `app/data/torneios/`.

```bash
flutter test
```

```
+151 ~1: All other tests passed!     exit 0
```

O único `~1` é o teste de ponta a ponta da identidade, que se pula quando a
suíte roda **sem** `--dart-define` — é exatamente o que ele existe para
detectar. Com os defines que o gate imprime:

```bash
DEFINES=$(dart run app/tool/gate_identidade_build.dart --ambiente=producao --defines)
flutter test $DEFINES
```

```
+152: All tests passed!              exit 0
```

Ou seja: **a identidade carimbada por `--dart-define` chega dentro do binário e
é reconhecida como provável em tempo de execução.**

### Cobertura contra o contrato da OS (§7)

| # | Exigência | Onde |
|---|---|---|
| 1 | erro síncrono Flutter | `captura_test.dart` › *porta 1* (2 testes) |
| 2 | erro assíncrono não tratado | `captura_test.dart` › *porta 3* |
| 3 | erro de plataforma | `captura_test.dart` › *porta 2* |
| 4 | fatal vs. não fatal | *porta 1* (`silent`) e *porta 4* (2 testes) |
| 5 | deduplicação | `captura_test.dart` › *deduplicação* (4 testes) |
| 6 | coletor indisponível sem bloquear startup | *coletor indisponível* (4 testes) |
| 7 | redação adversarial | `redacao_test.dart` (20 testes) |
| 8 | coleta desligada em teste/debug | *coleta desligada em debug/teste* (2 testes) |
| 9 | manifesto reprodutível | `identidade_manifesto_test.dart` › *manifesto reprodutível* (5) |
| 10 | gate reprova suja / SHA ausente / vc repetido / regressivo | *gate de release* (13 testes) |
| 11 | analyze + suíte completa | §2 e §3 acima |

O item 7 é adversarial de propósito: cada caso tenta **vazar** — JWT, chave de
API do Google, e-mail, UID solto, `purchaseToken`, `Authorization`, número de
cartão, mão de cartas, client id OAuth — em mensagem, em chave de contexto, em
valor de contexto e três níveis abaixo numa cadeia de exceções aninhadas. Há
também os testes do que **não** pode ser destruído: SHA de commit e frames de
stack trace sobrevivem, senão a redação teria custado a resposta de "onde
quebrou?".

---

## 4. Gate de identidade de build

Todas as execuções abaixo são reais. `0` = PASS, `1` = FAIL, `2` = erro de uso.

### 4.1 Árvore suja reprova

```bash
dart run app/tool/gate_identidade_build.dart --ambiente=producao --sem-artefatos
```

```
árvore:       SUJA (3)
              ?? docs/RUNBOOK-CRASH-RECUPERACAO-V1.md
              ...
FAIL — 1 reprovação(ões):
  · árvore suja: há mudança não commitada; o SHA não descreveria o que foi compilado
```
**exit 1**

### 4.2 Árvore limpa aprova

Mesmo comando, num clone limpo da branch:

```
build:        1.0.0 (136) · 6b64d40 · producao
sha:          6b64d4090589b8f7d54034d60e2953dc66804242
árvore:       limpa
PASS — identidade de build provada
```
**exit 0**

### 4.3 Build de validação, não publicável

`flutter build apk` exige Modo de Desenvolvedor nesta máquina (symlinks), então
a validação usou o alvo **web**, que compila o mesmo `lib/` em release com os
mesmos defines e produz um mapa de símbolos real:

```bash
DEF=$(dart run app/tool/gate_identidade_build.dart --ambiente=producao --defines)
flutter build web --release --source-maps $DEF
```
```
√ Built build\web                    exit 0
```

Isso prova, com o compilador e não com argumentação, que o app inteiro — camada
de observabilidade e adaptador do Crashlytics incluídos — **compila em release
com a identidade carimbada**. Nenhum AAB foi gerado; nada foi publicado.

### 4.4 Gate pós-build com artefato e símbolos reais

```bash
dart run app/tool/gate_identidade_build.dart --ambiente=producao \
  --artefato=app_build/main.dart.js \
  --simbolos=app_build/simbolos \
  --manifesto=app_build/MANIFESTO-BUILD.json --registrar
```

```
build:        1.0.0 (137) · ffc6251 · producao
árvore:       limpa
artefatos:    1
símbolos:     1
manifesto:    029e0dbd09a358a0ff467a9fe20d61571abad24e9714221569806461b35579b3
PASS — identidade de build provada
manifesto gravado em app_build/MANIFESTO-BUILD.json
versionCode 137 registrado no livro-razão
```
**exit 0**

Manifesto produzido:

```json
{
  "artefatos": {
    "app_build/main.dart.js": "25ff53444e3ae22e8be4a09776b92cf9ed36dd5323a1688ddfdc5b18724c7a38"
  },
  "esquema": 1,
  "identidade": {
    "ambiente": "producao",
    "branch": "claude/observabilidade-build-recuperacao-v1-f47093",
    "dart": "3.11.1",
    "flutter": "3.41.4",
    "sha": "ffc6251b0251bfbe945300d0b240c0aad2951aa0",
    "versionCode": 137,
    "versionName": "1.0.0"
  },
  "simbolos": {
    "simbolos/main.dart.js.map": "6c636fb44f6fff4530651841607e7d37b4f416cd27bcb1b0a021e5d53043af25"
  }
}
```

### 4.5 Reprodutibilidade

Segunda execução, mesmo commit, mesmos artefatos:

```
manifesto:    029e0dbd09a358a0ff467a9fe20d61571abad24e9714221569806461b35579b3
PASS
```
**exit 0** — impressão digital **idêntica**. Sem timestamp e com chaves
ordenadas, o manifesto é comparável byte a byte.

### 4.6 `versionCode` repetido reprova

Livro-razão adulterado para atribuir 137 a outro commit:

```
FAIL — 1 reprovação(ões):
  · versionCode repetido: 137 já foi emitido para aaaaaaaa... e agora viria de ffc6251b...
```
**exit 1**

### 4.7 `versionCode` regressivo reprova

Livro-razão com 999 já emitido:

```
FAIL — 1 reprovação(ões):
  · versionCode regressivo: 137 é menor que o maior já emitido (999)
```
**exit 1**

### 4.8 Artefato não provado reprova

```
FAIL — 1 reprovação(ões):
  · identidade do artefato não provada: o manifesto não declara nenhum artefato
```
**exit 1**

### 4.9 `--defines` imprime o carimbo

```
--dart-define=BMV_VERSION_NAME=1.0.0
--dart-define=BMV_VERSION_CODE=137
--dart-define=BMV_GIT_SHA=ffc6251b0251bfbe945300d0b240c0aad2951aa0
--dart-define=BMV_GIT_BRANCH=claude/observabilidade-build-recuperacao-v1-f47093
--dart-define=BMV_AMBIENTE=producao
--dart-define=BMV_FLUTTER_VERSION=3.41.4
--dart-define=BMV_DART_VERSION=3.11.1
```
**exit 0**

---

## 5. Decisões que valem registrar

**Sem correlação de jogador.** A camada não emite identificador de jogador
nenhum, nem pseudônimo, nem rotativo. A OS permite omitir quando não for
estritamente necessário, e não é: agrupar por `versionCode`, tipo de exceção e
trilha resolve. Identificador que existe acaba sendo usado. Se um dia for
preciso, o requisito está escrito no runbook, §8.

**Livro-razão nasce vazio.** `app/data/observabilidade/versioncode_ledger.json`
foi versionado sem registros. Registrar é ato deliberado, feito no momento de
uma release de verdade e revisado em commit — registrar um commit de branch de
trabalho faria o livro afirmar uma publicação que não houve. Os testes e a
demonstração §4.6/§4.7 cobrem o comportamento com o livro cheio.

**Símbolos são produzidos e associados, não enviados.** O CI passa a rodar
`--split-debug-info=build/simbolos` e o gate hasheia cada arquivo dentro do
manifesto, amarrando símbolo e artefato à mesma identidade. O **upload** para o
painel do fornecedor exigiria o plugin Gradle do Crashlytics e um
`google-services.json`, o que passa pelo Firebase Console — explicitamente fora
desta OS. Enquanto isso, a deofuscação se faz localmente com o artefato
`bmv-identidade-build` do run correspondente.

**Sujeira inclui arquivo não rastreado.** `git status --porcelain` respeita o
`.gitignore`, e `/app_build/` já era ignorado; foram acrescentados `.dart_tool/`,
`/app/build/` e `*-debug.log`, que são saídas de ferramenta. Um `.dart` novo e
não commitado muda o que é compilado tanto quanto uma linha editada, e por isso
reprova.

---

## 6. Limitações honestas

1. **Nenhuma evidência de CI.** O workflow deste repositório só dispara por
   `workflow_dispatch`, e esta branch não foi mesclada. As mudanças em
   `.github/workflows/build.yml` — `fetch-depth: 0`, o pin do
   `firebase_crashlytics`, os dois passos de gate e os `--dart-define` no
   build — **não foram executadas pelo GitHub Actions**. Foram validadas
   localmente comando a comando, com o mesmo overlay que o CI monta.

2. **`flutter build apk` não roda nesta máquina** (exige Modo de Desenvolvedor
   para symlinks). A validação de build usou o alvo web, que compila o mesmo
   `lib/`. A produção de símbolos `--split-debug-info` é específica de alvo AOT
   nativo e, portanto, **só será exercida no CI**.

3. **Flutter local (3.41.4) ≠ Flutter do CI (3.44.8).** A compatibilidade do
   `firebase_crashlytics 5.2.7` com o pin foi estabelecida por análise de
   restrição, não por execução sob 3.44.8.

4. **O caminho nativo do Crashlytics não foi exercido.** Nenhum crash real foi
   provocado em dispositivo, e nenhum evento chegou a painel de fornecedor —
   ambos proibidos pela OS. O que está provado é que o adaptador só recebe
   evento já redigido, que sua falha não derruba o app, e que ele nem sequer é
   ligado sem identidade provável.

---

## 7. Como reproduzir tudo

```bash
# 1. Overlay equivalente ao CI
flutter create --org com.buracomastervip.poc --project-name buraco_master_vip ov
cp -R app/lib/. ov/lib/
mkdir -p ov/test/observabilidade ov/test/torneios/data
cp app/test/observabilidade/*.dart ov/test/observabilidade/
cp app/test/teste_motor.dart ov/test/
cp app/test/torneios/reward_grants_test.dart ov/test/torneios/
cp app/data/torneios/*.seed.json ov/test/torneios/data/
rm ov/test/widget_test.dart          # scaffold do flutter create, quebrado na base
cd ov && flutter pub add firebase_core "firebase_crashlytics:5.2.7" firebase_auth \
  "google_sign_in:^6.2.1" audioplayers web_socket_channel shared_preferences

# 2. Análise e testes
flutter analyze lib
flutter test

# 3. Gate (do repositório, não do overlay)
dart run app/tool/gate_identidade_build.dart --help
dart run app/tool/gate_identidade_build.dart --ambiente=producao --sem-artefatos
```
