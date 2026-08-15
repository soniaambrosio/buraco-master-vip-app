# Release Android de Produção V1 — AAB, assinatura e identidade final

**OS:** Release Android de Produção V1 — Buraco Master VIP
**Base:** `claude/vip-production-readiness-4194df` @ `7a91e1f9088549d891a749c6624b6d54071bfbb0`
**Branch desta OS:** `claude/android-aab-production-build-ea6bbc`
**Data:** 2026-08-15
**Escopo:** produzir e provar tecnicamente o AAB de produção. **Sem** upload,
merge ou deploy.

> Este documento **complementa** [PUBLICACAO-GOOGLE-PLAY-V1.md](PUBLICACAO-GOOGLE-PLAY-V1.md),
> que segue íntegro. Onde os dois divergem, é porque a auditoria original foi
> feita sobre uma base mais antiga — a §1 explica exatamente qual e por quê.

---

## 0. O que muda o enquadramento desta OS

A auditoria anterior listou quatro bloqueadores duros (APK em vez de AAB,
`applicationId` de PoC, keystore de teste, ícone padrão do Flutter). **Dois
deles já estavam resolvidos** numa branch que a auditoria não enxergou, e os
outros dois foram resolvidos aqui. Em compensação, apareceram dois defeitos que
ninguém tinha visto — e a razão de não terem sido vistos é a mesma para os dois.

| # | Achado | Evidência |
|---|---|---|
| 0.1 | O pipeline de AAB **já existia** (`.github/workflows/release-aab.yml`), com `applicationId` oficial e assinatura 100% por Secrets. A auditoria não o viu porque auditou `consolidacao/apk-geral-bmv` @ `0cea0d6`, e o workflow entrou depois, em `4c85258`, na linhagem de Billing. | §1 |
| 0.2 | Esse workflow **nunca rodou**. Este repositório só dispara workflow por `workflow_dispatch`, em branch já publicada — então a única forma de testar um passo era gastar um build inteiro de CI, numa branch que ainda não existia. | §2 |
| 0.3 | **Defeito latente 1:** o passo `minSdk = 23` colocava o projeto **abaixo do piso do próprio engine do Flutter** (24). | §6 |
| 0.4 | **Defeito latente 2:** a verificação "Billing Library dentro do AAB" procurava o caminho `com/android/billingclient` na **listagem do zip**. Num AAB as classes vivem dentro de `base/dex/classes*.dex`, nunca como arquivos. A busca retornava zero **sempre**, e o passo tinha `exit 1` no zero — o portão teria reprovado **todo** build, inclusive um correto. | §8 |
| 0.5 | **Defeito novo, no app:** `loja_categoria_screen.dart` cita **46 caminhos** de `assets/loja/` que nunca existiram no repositório nem no `pubspec`. A tela é alcançável em dois toques a partir do Início. | §9 |
| 0.6 | **Defeito novo, no app:** `PerfilService.statsDemo = true` montava número inventado (nível, vitórias, canastras, conquistas desbloqueadas) **ao lado do nome e da foto reais** do jogador. | §11 |

0.3 e 0.4 foram encontrados rodando o pipeline **na máquina**, antes de gastar
CI. É por isso que a montagem migrou de Python-dentro-do-YAML para Dart
versionado: não é preferência de linguagem, é a diferença entre um passo que só
pode ser testado no CI e um que pode ser testado antes.

---

## 1. Base usada

| Item | Valor |
|---|---|
| Branch escolhida | `claude/vip-production-readiness-4194df` |
| Hash completo | `7a91e1f9088549d891a749c6624b6d54071bfbb0` |
| Branch desta OS | `claude/android-aab-production-build-ea6bbc` |

**Por que esta base representa o estado real mais atual.** Ancestralidade
conferida com `git merge-base --is-ancestor`:

| Base candidata | É ancestral de `7a91e1f`? |
|---|---|
| `origin/consolidacao/apk-geral-bmv` (`0cea0d6`) | **sim** |
| `homologacao/play-billing-comercial` (`0ea96c2`) | **sim** |
| `integracao/play-billing-flutter` (`319bb8f`) | **sim** |
| `integracao/rtdn-vip-producao` (`a2622d5`) | **sim** |
| `correcao/p0-elegibilidade-vip-lifecycle` (`bcb55c7`) | **sim** |

Ou seja: `7a91e1f` contém a consolidação visual **e** toda a linhagem comercial
(cliente Billing, RTDN, ciclo de vida do VIP, fichas de assinatura). Nenhum
merge foi necessário — a base já continha tudo.

**A base da auditoria anterior não serve.** `604f362` (a auditoria) está
diretamente sobre `0cea0d6`, e `homologacao/play-billing-comercial` **não** é
ancestral dele. Por isso a auditoria descreve um app sem `in_app_purchase` e sem
pipeline de AAB: naquela base, realmente não havia.

O único conteúdo de `604f362` é o próprio documento de auditoria (409 linhas, um
arquivo). Ele foi trazido por `git cherry-pick` para que a referência cruzada
deste documento resolva, sem merge de código.

---

## 2. Arquitetura do pipeline final

Existe **um** pipeline de publicação Android:

```
.github/workflows/release-aab.yml   →  AAB oficial. É este.
```

Os demais workflows Android **não publicam** e agora dizem isso no próprio
cabeçalho:

| Workflow | Produz | Serve para |
|---|---|---|
| `release-aab.yml` | `app-release.aab` | **publicação** (upload manual na faixa de Teste interno) |
| `build.yml` | APK `.poc` | instalar em aparelho durante o desenvolvimento |
| `ci-os-integracao.yml` | nada | `analyze` + suítes Flutter + três codebases Firebase |
| `web.yml` | build web | GitHub Pages |

O `build.yml` **da raiz do repositório** foi removido — ver §10.

### 2.1 Onde mora a lógica

A montagem do projeto Android saiu do YAML e virou dois programas Dart
versionados:

| Programa | Faz |
|---|---|
| `tools/android/bin/preparar_release.dart` | transforma o scaffold do `flutter create` no projeto de produção |
| `tools/android/bin/verificar_aab.dart` | lê o `.aab` pronto e confere tudo que a OS exige |
| `tools/android/bin/verificar_assets.dart` | portão de consistência de assets (§9) |
| `tools/icone/bin/gerar.dart` | gera o launcher icon a partir da arte oficial (§8) |

Dart, e não Python, por um motivo único: o SDK já vem com o Flutter, que é
obrigatório no CI **e** na máquina. O mesmo código roda nos dois lugares. A
alternativa — reescrever os passos em bash para conseguir rodar local — criaria
duas implementações do mesmo patch, que divergem na primeira manutenção.

Cada patch confere o próprio resultado e aborta com mensagem nomeada. **Sem
fallback:** um patch que erra o alvo e segue em frente produz um AAB que
compila, parece pronto, e está assinado com a chave errada.

### 2.2 Sequência do workflow

```
portões de entrada   versionCode > 2 · secrets de assinatura · google-services · in_app_purchase no pubspec
scaffold             flutter create (--org do PoC: define só o nome do pacote Dart)
dependências         cp pubspec.yaml + pubspec.lock do repositório  →  flutter pub get
portões de conteúdo  assets citados × existentes × declarados · ícone reproduzível da arte-fonte
overlay              app/lib + app/assets reais
Firebase             troca o appId para o app Android OFICIAL (só na cópia, não no fonte)
portões de qualidade motor de partidas · cliente Billing (15 casos) · backend Billing (node --test)
Android              google-services.json (Secret) · keystore de upload (Secret) · key.properties
preparação           preparar_release.dart  (identidade, SDKs, assinatura, ícone, manifesto)
build                flutter build appbundle --release
verificação          bundletool validate · bundletool dump manifest · verificar_aab.dart · fingerprint
artefato             upload-artifact (sem publicação)
```

---

## 3. Identidade Android

| Campo | Valor | Onde é fixado |
|---|---|---|
| `applicationId` | `io.github.soniaambrosio.buracomastervip` | `release-aab.yml` (env) → `preparar_release.dart` |
| `namespace` | `io.github.soniaambrosio.buracomastervip` | idem |
| `MainActivity` | `io.github.soniaambrosio.buracomastervip.MainActivity` | movida de pacote junto com o namespace |
| Firebase App ID | `1:203886484007:android:b1cd95baa0b9e6e629cc02` | app Android oficial |
| `android:label` | `Buraco Master VIP` | `preparar_release.dart` |

**O namespace passou a acompanhar o applicationId.** O Android aceita os dois
diferentes, e a versão anterior do workflow deixava o namespace no pacote do
scaffold de propósito. O problema prático é que o namespace é a base a partir da
qual o manifesto resolve nomes relativos: com `android:name=".MainActivity"`, o
nome de classe da Activity no manifesto final do artefato seria
`com.buracomastervip.poc.buraco_master_vip.MainActivity`. O pacote de PoC
sobreviveria dentro do pacote de produção como identidade de uma classe.

Trocar o namespace **sem mover a classe** compila e estoura
`ClassNotFoundException` ao abrir. Por isso as duas coisas acontecem no mesmo
passo, com conferência no fim — e o resultado foi verificado dentro do AAB
(§13).

### 3.1 Busca final por `com.buracomastervip`

Todas as ocorrências que restam, e a justificativa de cada uma:

| Local | Ocorrência | Justificativa |
|---|---|---|
| `release-aab.yml:185`, `ci-os-integracao.yml:58`, `web.yml:35`, `build.yml:65` | `flutter create --org com.buracomastervip.poc --project-name buraco_master_vip` | Define o nome do **pacote Dart** (`buraco_master_vip`), que as suítes importam como `package:buraco_master_vip/...`. O `--org` só afeta o scaffold; no `release-aab.yml` tanto o `applicationId` quanto o `namespace` são sobrescritos logo depois, e o resultado é conferido dentro do artefato. |
| `build.yml:34,39` | `BMV_APPLICATION_ID: com.buracomastervip.poc.buraco_master_vip` | É o APK de **teste**, que não publica. O pacote `.poc` é o que mantém o SHA-1 do login Google dos aparelhos de teste. |
| `tools/android/bin/preparar_release.dart:186,204` | `'com.buracomastervip.poc': false` e um comentário | É a **asserção** que reprova o build se o pacote de PoC sobrar no `build.gradle.kts`. |
| `tools/android/bin/verificar_aab.dart:117-125` | `contains('com.buracomastervip')` | É a **asserção** que reprova se o pacote de PoC aparecer no manifesto final. |

**Nenhuma ocorrência é identidade efetiva da build de produção.** Prova em §13:
o manifesto real dentro do AAB não contém a string `com.buracomastervip`.

---

## 4. Assinatura

| Item | Valor |
|---|---|
| Origem da chave | **exclusivamente GitHub Secrets** |
| Secrets exigidos | `BMV_UPLOAD_KEYSTORE_B64`, `BMV_UPLOAD_KEY_ALIAS`, `BMV_UPLOAD_STORE_PASSWORD`, `BMV_UPLOAD_KEY_PASSWORD` |
| Portão | falha antes de qualquer build, nomeando o secret que falta |
| `signingConfig` | `create("upload")`, lido de `key.properties` |
| `key.properties` | escrito em tempo de execução, fora do repositório, impresso só com `Password=***` |
| `buildTypes.release` | `signingConfig = upload`, `isDebuggable = false` |
| Fingerprint da chave de upload registrada na Play Console | SHA-1 `32:6B:CA:26:34:29:45:41:D5:DA:21:17:DB:87:80:91:32:D2:D9:9C` |

### 4.1 O que saiu do repositório

| Removido | Era |
|---|---|
| `keystore/buraco-master-vip-test.jks.b64` | chave de teste **versionada** |
| `keystore/debug.keystore.b64` | chave versionada, **sem nenhum consumidor** no repositório |
| `BMV_STORE_PASSWORD: bmvtest2026` e `BMV_KEY_PASSWORD: bmvtest2026` em `build.yml` | senha de assinatura **em texto claro**, em arquivo versionado |

O `build.yml` (APK de teste) passou a ler a chave e as senhas de
`BMV_TEST_KEYSTORE_B64`, `BMV_TEST_STORE_PASSWORD` e `BMV_TEST_KEY_PASSWORD`,
com o mesmo padrão de portão fail-closed do pipeline oficial.

> ⚠️ **Consequência operacional.** O `build.yml` só voltará a rodar depois que
> esses três secrets forem cadastrados. Como o `.jks` de teste saiu do
> repositório, ele precisa ser recuperado do histórico do git (`git show
> 7a91e1f:keystore/buraco-master-vip-test.jks.b64`) e cadastrado como secret. Se
> for gerado um `.jks` novo em vez disso, o SHA-1 muda e o **login Google do APK
> de teste para de funcionar** até o novo SHA-1 ser registrado no Firebase
> Console.
>
> Registrar também que a senha `bmvtest2026` permanece **no histórico do git**
> para sempre. Removê-la do `HEAD` impede que ela continue sendo usada; não a
> apaga do passado. Como ela protege uma chave que também estava versionada, o
> tratamento correto é considerar essa chave de teste comprometida por
> construção — o que ela sempre foi.

### 4.2 O certificado do AAB gerado nesta OS

O AAB desta OS foi construído **na máquina**, e a chave de upload de produção
existe apenas em Secrets do GitHub — ela não é acessível aqui, e criar ou
manipular material de chave de produção não é trabalho desta OS. A build local
foi assinada com uma chave de **verificação descartável**, gerada fora do
repositório, válida por 30 dias, com o próprio nome dizendo o que é:

```
Proprietário: CN=Verificacao Local OS AAB NAO E CHAVE DE UPLOAD, O=Buraco Master VIP, C=BR
SHA-1:   3C:80:EA:15:F0:96:7D:BE:4C:C8:6D:1D:15:E4:7C:C7:3B:7F:B7:6E
SHA-256: 08:F1:0E:23:4A:02:D0:19:0A:3D:BE:9F:96:94:67:E3:6C:96:33:AC:BD:66:DF:62:90:D5:87:8F:8C:32:B8:77
```

O que isso prova e o que não prova:

- **prova** que o `signingConfig` de release funciona, que o AAB sai assinado,
  que nenhum material de assinatura vai dentro do bundle, e que o passo de
  impressão digital funciona;
- **não prova** que a chave de upload registrada na Play Console assina este
  commit. Isso só pode ser provado por uma execução do `release-aab.yml` com os
  Secrets presentes, e o próprio workflow imprime as duas impressões digitais
  lado a lado para a conferência.

Nenhum segredo foi exposto: impressão digital de certificado é informação
pública, e é exatamente o que a Play Console mostra.

---

## 5. Versionamento

| Campo | Valor | Origem da decisão |
|---|---|---|
| `versionCode` | `3` | O último AAB aceito pela Play Console foi o `2`. Decisão já registrada em [PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md:179,191](PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md). |
| `versionName` | `1.0.1` | Idem. O anterior aparece como `1.0.0.1` na Play Console. |

Os dois são **entradas do `workflow_dispatch`**, com esses valores como padrão,
e não são herdados do `pubspec.yaml`. Um portão de entrada rejeita
`versionCode ≤ 2` antes de gastar build.

Nada foi incrementado arbitrariamente nesta OS: os valores são os que já
estavam decididos.

---

## 6. targetSdk / compatibilidade

| Campo | Valor | Como é fixado |
|---|---|---|
| `compileSdk` | **36** | literal no `preparar_release.dart` |
| `targetSdk` | **36** | literal |
| `minSdk` | **24** | literal |
| Java / Kotlin JVM target | 17 | do scaffold |
| Flutter (CI) | 3.44.8, pinado | `release-aab.yml` |
| Android Gradle Plugin / Gradle | do scaffold do Flutter pinado | — |

**Por que literal e não `flutter.targetSdkVersion`.** Herdar parece conveniente
e é justamente o problema: o alvo do artefato mudaria sozinho a cada bump do
canal stable, sem ninguém decidir. Como a Play sobe o alvo mínimo exigido todo
ano e recusa upload abaixo dele, esse número precisa ser uma decisão registrada.
`targetSdk 36` atende a exigência prevista para agosto de 2026 sem impedimento
técnico — o build passou e a suíte inteira está verde.

**`minSdk` era 23 e estava errado.** O passo antigo fazia
`sed 's/minSdk = flutter.minSdkVersion/minSdk = 23/'`, herdado da época em que o
Firebase pedia 23. O piso do próprio engine do Flutter hoje é **24**
(`FlutterExtension.minSdkVersion`). Fixar 23 colocava o projeto abaixo do piso
do engine. Corrigido para 24, e conferido dentro do artefato.

---

## 7. Assets

O portão `verificar_assets.dart` cruza três listas que precisam concordar:

1. os caminhos `assets/...` citados no Dart;
2. os arquivos que existem em `app/assets/`;
3. as pastas declaradas no bloco `flutter: assets:` do `app/pubspec.yaml`.

Nenhuma divergência entre elas produz erro de compilação — é por isso que o
defeito abaixo sobreviveu.

### 7.1 Resultado do portão

| Achado | Situação |
|---|---|
| `assets/loja/{avatares,dorsos,efeitos,emojis,mascotes,molduras}/` — **46 arquivos** citados por `loja_categoria_screen.dart` | **NÃO EXISTEM.** A pasta `app/assets/loja/` nunca foi criada. Ver §9. |
| `assets/splash.jpg` — citado por `main.dart:185` | **NÃO EXISTE**, mas é **código morto**: quem o usa é `SplashScreen`, que tem **zero referências**. O `home:` do app é `SplashOficialScreen`. |
| Arquivos que existem e não seriam empacotados | **nenhum** |
| Pastas declaradas e inexistentes | **nenhuma** |

**A correção sugerida pela auditoria anterior não podia ser aplicada como
escrita.** Declarar `assets/loja/` no `pubspec` sem que a pasta exista faz
`flutter build` **falhar** — o problema não era a declaração faltando, era a
arte faltando. O `pubspec.yaml` não foi alterado: ele já declara corretamente
todas as 14 pastas que existem, e as 166 entraram no artefato (§13).

---

## 8. Ícone oficial

O launcher icon deixou de ser o padrão do Flutter.

| Item | Valor |
|---|---|
| Arte-fonte | `app/assets/splash/logo_splash_oficial.webp` — 1024×1024, RGBA, 100% opaca |
| Gerador | `tools/icone/bin/gerar.dart` (Dart puro, sem Pillow/ImageMagick) |
| Saída versionada | `android/launcher-icon/res/` |
| Densidades legado | mdpi 48 · hdpi 72 · xhdpi 96 · xxhdpi 144 · xxxhdpi 192 |
| Adaptive icon | `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_foreground.png` nas 5 densidades (108dp → 432px) |
| Cor de fundo | `#040201`, **amostrada dos quatro cantos da própria arte** |
| Ícone da ficha da Play | `android/launcher-icon/play-store-icon-512.png` — 512×512, PNG 32 bits, sem transparência |

**Como o adaptive icon foi montado, e por quê.** Um adaptive icon tem 108
unidades de lado, das quais o sistema exibe apenas as 72 centrais. Jogar a arte
inteira em bleed total faria a máscara comer o anel dourado externo do emblema.
A camada de frente recebe a arte reduzida a exatamente **72/108** do quadro,
centralizada, com o resto transparente — o emblema passa a coincidir com a área
visível, e nenhuma máscara (círculo, squircle, gota) o corta. A camada de fundo
é cor chapada amostrada da arte, para que a borda quadrada da camada de frente
não apareça contra o fundo.

Nada foi redesenhado. É reamostragem cúbica da arte aprovada.

**Dois portões protegem isso:**

1. no CI, o gerador é reexecutado e `git diff --exit-code -- android/launcher-icon`
   exige que o resultado seja idêntico ao versionado — impede que alguém edite um
   PNG de ícone à mão;
2. na conferência do artefato, os PNG de mipmap são extraídos de dentro do
   `.aab`, decodificados e comparados **pixel a pixel** com a arte versionada.
   Comparar bytes não serviria: o `aapt2` recomprime todo PNG de recurso. A
   recompressão é sem perda, então os pixels batem exatamente — e é essa
   igualdade que prova que o ícone do artefato é o oficial.

---

## 9. `assets/loja/` — o defeito que o portão encontrou

`app/lib/screens/loja_categoria_screen.dart` cita **46 caminhos** sob
`assets/loja/`. Nenhum existe.

**A tela é alcançável em produção.** Cadeia verificada:

```
Início (menu_loja_vip)  →  _abrirLoja()            main.dart:316,669
                        →  LojaScreen              main.dart:932
                        →  onAbrirCategoria        main.dart:962
                        →  _LojaCategoriaPreviewHost
                        →  LojaCategoriaScreen(vm: LojaCategoriaVM.mock(categoria))
                                                   main.dart:1017-1018
```

O que o jogador vê hoje, em dois toques a partir do Início: uma grade de
cosméticos com catálogo inventado, preços, raridade e estado de posse, em que
**todas as imagens falham**. Dois dos três pontos de renderização têm
`errorBuilder` e mostram um ícone de "imagem indisponível"
(`loja_categoria_screen.dart:622,888`); o terceiro, `loja_categoria_screen.dart:1049`,
**não tem** `errorBuilder` — ali o `Image.asset` de um asset inexistente lança.

**Não foi corrigido nesta OS, e por quê.** As duas saídas possíveis estão fora
do que esta OS pode decidir sozinha: ou a arte dos 46 cosméticos chega (é
material de design, e a OS proíbe inventar), ou a grade de cosméticos sai do
caminho do release (é decisão de produto, e a OS proíbe redesenho de telas).

**O que foi feito:** o portão é *fail-closed*. O pipeline oficial **para aqui** e
não produz AAB enquanto a divergência existir. Há uma válvula
(`--tolerar-ausentes=assets/loja/`), deliberadamente chata: ela deixa a dívida
escrita no comando, visível em toda execução, em vez de escondida num
`|| true` — que foi exatamente como o passo antigo do `build.yml` copiava essa
pasta (`cp -r app/assets/loja/. ... 2>/dev/null || true`, falhando em silêncio
sobre uma pasta que nem existia).

---

## 10. `build.yml` obsoleto

**Removido.** Ausência de consumidor provada por três vias:

1. **O GitHub Actions não o executa.** Só arquivos em `.github/workflows/` são
   workflows. Um `build.yml` na raiz é um arquivo YAML comum.
2. **Ninguém o referencia.** Busca no repositório por `build.yml`: todas as
   ocorrências apontam para `.github/workflows/build.yml` (em `release-aab.yml`,
   `docs/MOTOR-PARTIDAS-ARQUITETURA.md`, `firebase/README.md`).
3. **Estava morto há muito.** Histórico completo: dois commits, ambos
   "Add files via upload" (`5dcf0ba`, `1b973b1`). Nunca foi mantido junto do
   workflow real — o `diff` contra `.github/workflows/build.yml` tinha 324
   linhas.

Ele já tinha custado tempo: a auditoria anterior citou "build.yml:20-24" e
"build.yml:493" misturando os dois arquivos, e registrou o problema na própria
§6.3.

O objetivo de "uma única fonte oficial e reconhecível" foi fechado pelos dois
lados: o arquivo confuso saiu, e os dois workflows Android que restam declaram
no cabeçalho qual publica e qual não publica.

---

## 11. Mocks e dados demonstrativos

### 11.1 `statsDemo` — corrigido

`PerfilService.statsDemo` era `true`. Consequência: o Perfil montava nível,
vitórias, canastras e conquistas desbloqueadas **inventados**, e os exibia ao
lado do `displayName` e da `photoURL` **reais**, vindos do Firebase Auth. O app
afirmava ao jogador um histórico que ele não tem.

**Passou a `false`.** Não é redesenho: a própria classe foi escrita para os dois
casos (`_catalogoTravado` e `_catalogoDemo`), e o comentário do arquivo já dizia
"vire para false quando quiser o estado honesto de jogador novo". Nenhuma suíte
depende da constante (`grep` por `statsDemo|PerfilService` em `app/test/` →
nenhum resultado).

### 11.2 Classificação das chamadas `.mock()`

31 ocorrências em `app/lib`. Classificação:

| Classe | Quantidade | Detalhe |
|---|---|---|
| **Definições** (fábricas `VM.mock(...)` nas telas) | 13 | São construtores de VM de exemplo em `app/lib/screens/*.dart`. Inofensivas por si — o que importa é quem as chama. |
| **Alcançáveis em release** | 14 | Todas em `main.dart`, listadas abaixo. |
| **Código morto removido** | 2 | `app/lib/app/lib/` — pasta duplicada, zero referências (§12). |
| Fixtures de teste | — | Nenhuma foi tocada. |

As 14 alcançáveis:

| Linha | Tela | O que é fabricado |
|---|---|---|
| `main.dart:372` | Início | contadores do menu |
| `main.dart:403,417` | Saguão | salas e jogadores online |
| `main.dart:487,595` | Amigos | lista de amigos e convites |
| `main.dart:927` | Loja (hub) | catálogo |
| `main.dart:1018` | Loja › categoria | catálogo de cosméticos + **46 artes inexistentes** (§9) |
| `main.dart:1094` | Hall dos Imortais | painel de glória |
| `main.dart:1135` | Onde Jogar | modos |
| `main.dart:1466` | Recompensas | recompensas |
| `main.dart:1493,1526` | Configurar Mesa | opções |
| `main.dart:1635` | Preparando Partida | oponentes |
| `main.dart:2114` | Ranking | pódio e classificação |

**Nenhuma foi removida, e isso é deliberado.** Esses `.mock()` não são um
descuido pontual: são a arquitetura atual do `main.dart`, que é um *preview
host* ligando VMs de exemplo em cada tela. Substituí-los exige as fontes reais
(Firestore, ranking com fórmula, grafo social, economia) — cada uma é uma OS
própria, várias já entregues em branches não mescladas. Trocar isso aqui seria
reconstruir o app, o que a §15 da OS proíbe explicitamente.

**Consequência para o veredito:** o critério "mocks não são apresentados como
dados reais em release" **não pode ser respondido SIM**. O caso mais grave
(`statsDemo`, que colava número falso na identidade real do jogador) foi
resolvido; o restante permanece e está registrado como bloqueio.

---

## 12. Limpeza

| Removido | Por quê |
|---|---|
| `build.yml` (raiz) | §10 |
| `keystore/buraco-master-vip-test.jks.b64` | §4.1 |
| `keystore/debug.keystore.b64` | §4.1 — e **sem nenhum consumidor**: busca por `debug.keystore` no repositório não retorna nada |
| `app/lib/app/lib/screens/amigos_screen.dart` | cópia duplicada; a viva é `app/lib/screens/amigos_screen.dart` |
| `app/lib/app/lib/widgets/convite_vip.dart` | idem; a viva é `app/lib/widgets/convite_vip.dart` |

A pasta `app/lib/app/` era copiada para dentro do build por `cp -R app/lib/.`.
Nenhum `import` aponta para ela, verificado.

---

## 13. Permissões reais e validação do AAB

### 13.1 Permissões efetivas, extraídas do artefato

O manifesto de origem do app declara **uma** permissão
(`com.android.vending.BILLING`, explícita). Todas as demais chegam pelo merge
dos manifestos das dependências, e só existem depois do build. Extraídas de
`bundletool dump manifest` sobre o `.aab`, **7 no total**:

| Permissão | Origem | Data Safety |
|---|---|---|
| `android.permission.INTERNET` | Firebase Auth/Firestore/Functions e o WebSocket de partidas | necessária; sem ela o app não conecta |
| `android.permission.ACCESS_NETWORK_STATE` | Play Services / Firebase | consulta de conectividade; não coleta dado |
| `android.permission.WAKE_LOCK` | Play Services (Firebase) | mantém a CPU ativa durante troca de token; não coleta dado |
| `com.android.vending.BILLING` | declarada no manifesto de origem **e** trazida pelo `in_app_purchase_android` | compras no app — declarar "sim" para compras digitais |
| `com.google.android.c2dm.permission.RECEIVE` | Play Services (`firebase-common`), transitiva | não há Firebase Messaging no app; não coleta dado |
| `com.google.android.providers.gsf.permission.READ_GSERVICES` | Play Services, transitiva | leitura de configuração do Google Services Framework; não coleta dado |
| `io.github.soniaambrosio.buracomastervip.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | gerada pelo `androidx.core` para o próprio app | nível `signature`, só o próprio app a detém; não aparece para o usuário e **não entra** no Data Safety |

**Ausências relevantes, confirmadas:** nenhuma permissão de localização,
contatos, câmera, microfone, armazenamento, notificações ou identificador de
anúncio. Isso confirma, agora com evidência de artefato, o que a auditoria
anterior tinha marcado como **A CONFIRMAR** na sua §3.

O conjunto é conferido por **igualdade exata**: sobrar reprova, e faltar também.
Como nenhuma dessas permissões está no fonte, o conjunto muda sozinho quando uma
dependência sobe de versão — o portão obriga alguém a decidir.

### 13.2 Conferência do artefato

Tudo abaixo sai de **dentro** do `.aab`:

| Item | Resultado |
|---|---|
| `bundletool validate` | exit 0 |
| `package` no manifesto final | `io.github.soniaambrosio.buracomastervip` |
| `versionCode` / `versionName` | `3` / `1.0.1` |
| `minSdkVersion` / `targetSdkVersion` | `24` / `36` |
| string `com.buracomastervip` no manifesto final | **nenhuma ocorrência** |
| Activity de entrada | `io.github.soniaambrosio.buracomastervip.MainActivity` |
| `android:debuggable` | ausente (release) |
| `android:icon` | `@mipmap/ic_launcher` |
| Permissões | 7, conjunto exato (§13.1) |
| Entradas no bundle | 946 |
| Assets do app | 166 (`assets/flutter_assets/assets/`), incluindo 56 do baralho |
| Launcher icon | 5 densidades, **0 pixel de diferença** contra a arte oficial, + adaptive icon |
| Google Play Billing no dex | `Lcom/android/billingclient/api/BillingClient;` e `...Purchase;` em `classes.dex` e `classes3.dex` |
| Ponte do plugin | `Lio/flutter/plugins/inapppurchase/InAppPurchasePlugin;` em `classes3.dex` |
| Firebase Auth no dex | `Lcom/google/firebase/auth/FirebaseAuth;` em `classes.dex`, `classes2.dex`, `classes3.dex` |
| Material de assinatura empacotado | **nenhum** (`key.properties`, `*.jks`, `*.keystore`) |
| Bloco de assinatura | `META-INF/*.RSA` presente |

**Sobre a verificação de Billing.** O passo antigo procurava
`com/android/billingclient` na listagem do zip. Num AAB (como num APK) as
classes não existem como arquivos — vivem em `base/dex/classes*.dex`. A busca
dava zero **sempre**, e o passo tinha `exit 1` no zero. A conferência atual
procura o descritor `Lcom/android/billingclient/api/BillingClient;` nos bytes do
dex, onde a tabela de strings guarda o nome. Confirmado também por `dexdump`:
3.076 referências em `classes.dex` e 96 em `classes3.dex`.

### 13.3 O artefato

| Campo | Valor |
|---|---|
| Caminho (CI e local) | `app_build/build/app/outputs/bundle/release/app-release.aab` |
| Tamanho | 136.860.469 bytes (130,52 MB) |
| SHA-256 | `f0cad75f71100026b7b5d514b62be99a5ec0cae8d8ced12ccc7203c5f4be84dd` |
| Assinado por | chave de **verificação local** (§4.2), não a de upload |

> ⚠️ **Tamanho.** 130 MB está sob o limite de 150 MB da Play, mas com pouca
> folga. **46 MB são símbolos de depuração nativos**
> (`BUNDLE-METADATA/com.android.tools.build.debugsymbols/*.sym`, para as três
> ABIs) — eles não são entregues ao aparelho, servem para a Play simbolicar
> crash nativo. Se a folga apertar, `ndk.debugSymbolLevel` é a alavanca, ao
> custo de perder simbolicação. Não é bloqueador hoje; é risco a acompanhar.

---

## 14. Comandos

### 14.1 Geração (processo oficial)

O pipeline oficial é o `workflow_dispatch` de **Release AAB (Teste interno)**,
com `version_code` e `version_name` como entradas.

### 14.2 Reprodução local (foi assim que este AAB foi gerado)

```bash
flutter create --org com.buracomastervip.poc --project-name buraco_master_vip app_build
cp app/pubspec.yaml app/pubspec.lock app_build/
(cd app_build && flutter pub get)
cp -R app/lib/. app_build/lib/
(cd app && find assets -type f ! -name '*.dart' -exec sh -c 'mkdir -p "../app_build/$(dirname "$1")" && cp "$1" "../app_build/$1"' _ {} \;)

dart pub get --directory tools/android
dart run tools/android/bin/verificar_assets.dart --app=app

dart run tools/android/bin/preparar_release.dart \
  --scaffold=app_build \
  --application-id=io.github.soniaambrosio.buracomastervip \
  --version-code=3 --version-name=1.0.1 \
  --icone=android/launcher-icon/res

# key.properties com a chave de VERIFICACAO local (nunca a de upload)
(cd app_build && flutter build appbundle --release)
```

Diferenças conhecidas da execução local, todas registradas:

| Passo | Local | Por quê |
|---|---|---|
| `google-services.json` e o plugin `com.google.gms.google-services` | **pulado** | o arquivo vive em Secret. Não altera permissões nem identidade: o plugin gera recursos de string, e o `FirebaseOptions` do app vem do Dart. |
| Plataformas não-Android do scaffold | removidas | `flutter pub get` falha ao criar symlink de plugin Windows entre unidades diferentes (projeto em `F:`, SDK em `C:`). Não afeta o build Android. |
| Assinatura | chave descartável | §4.2 |
| Portão de assets | contornado deliberadamente | §9 — no CI ele para o build |

### 14.3 Validação

```bash
java -jar bundletool.jar validate --bundle=<aab>
java -jar bundletool.jar dump manifest --bundle=<aab> > manifesto-final.xml
dart run tools/android/bin/verificar_aab.dart \
  --aab=<aab> --manifesto=manifesto-final.xml \
  --application-id=io.github.soniaambrosio.buracomastervip \
  --version-code=3 --version-name=1.0.1 --icone=android/launcher-icon/res
```

### 14.4 Regerar o ícone

```bash
dart pub get --directory tools/icone
dart run tools/icone/bin/gerar.dart
```

---

## 15. Resultado dos testes

| Gate | Resultado | Quantidade | Observação |
|---|---|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **exit 0** | 106 issues | **0 erros.** 93 info + 13 warning, todos pré-existentes (`deprecated_member_use`, `unnecessary_underscores`, campo não usado). Esta OS não tocou em código de tela. |
| `flutter test` (glob padrão, 17 arquivos) | **passou** | 602 | — |
| `flutter test test/teste_motor.dart` | **passou** | 132 | fora do glob padrão |
| `flutter test test/teste_motor_resiliencia.dart` | **passou** | 196 | fora do glob padrão |
| `flutter test test/teste_encerramento.dart` | **passou** | 10 | fora do glob padrão |
| `flutter test test/integracao/teste_integracao_motores.dart` | **passou** | 64 | fora do glob padrão |
| `flutter test test/moderacao/teste_moderacao.dart` | **passou** | 42 | fora do glob padrão |
| `flutter test test/motor/teste_visao_espectador.dart` | **passou** | 15 | fora do glob padrão |
| `node --test` em `functions-billing` | **passou** | 123 | entitlement, fichas, RTDN, diagnóstico do legado |
| `dart run verificar_assets.dart` | **REPROVOU** | 7 divergências | §7.1 e §9 — 46 assets de `assets/loja/` + 1 de código morto |
| `flutter build appbundle --release` | **passou** | 1 AAB | 130,52 MB |
| `bundletool validate` | **passou** | exit 0 | — |
| `dart run verificar_aab.dart` | **passou** | 7 permissões, 946 entradas | §13.2 |

**Total: 1.061 testes Flutter + 123 Node, todos verdes.**

> **Nota sobre a contagem.** Seis arquivos de suíte usam o prefixo `teste_` em
> vez do sufixo `_test`, e por isso ficam **fora** do glob padrão do
> `flutter test`. Pior: `flutter test test/motor/` — um diretório que só contém
> `teste_visao_espectador.dart` — **não** reporta "nenhum teste"; ele cai de
> volta na suíte inteira e reporta 602 passando. Uma leitura desatenta conclui
> que o diretório está coberto. Os seis foram rodados por caminho explícito
> acima. O `ci-os-integracao.yml` já os roda dessa forma.

**Separação de dívida:** nenhuma falha nova. Os 106 issues do `analyze` são
anteriores a esta OS — as únicas mudanças em `app/lib` foram uma constante
(`statsDemo`) e a remoção de uma pasta duplicada, e remover código só pode
reduzir a contagem.

---

## 16. Riscos remanescentes

| Risco | Gravidade | Nota |
|---|---|---|
| A chave de upload nunca assinou este commit | alta | Só uma execução do `release-aab.yml` prova. O workflow imprime as duas impressões digitais lado a lado. |
| `build.yml` (APK de teste) não roda até três secrets novos serem cadastrados | média | §4.1. O `.jks` precisa ser recuperado do histórico, não regerado, ou o login Google do APK de teste quebra. |
| `bmvtest2026` permanece no histórico do git | média | Removê-la do `HEAD` não a apaga do passado. A chave que ela protege também estava versionada. |
| AAB com 130 MB (limite 150 MB) | média | 46 MB são símbolos de depuração nativos. §13.3. |
| Dependências sem *pin* exato | baixa | `pubspec.lock` é versionado e copiado para o scaffold, então os builds são reprodutíveis hoje. |
| Ícone: fim de linha CRLF no Windows | baixa | O portão `git diff --exit-code -- android/launcher-icon` roda no CI (Linux, LF). Reexecutar o gerador no Windows pode acusar diferença de fim de linha, não de conteúdo. |

---

## 17. O que ainda impede o primeiro upload

### 17.1 Bloqueia o primeiro upload (homologação)

| # | Bloqueio | Dono |
|---|---|---|
| 1 | **`assets/loja/` — 46 artes inexistentes** numa tela alcançável em dois toques. Ou a arte chega, ou a grade de cosméticos sai do caminho do release. O pipeline oficial **para** aqui. | Sônia (arte) ou produto |
| 2 | **Secrets de assinatura** (`BMV_UPLOAD_*`) precisam existir no GitHub para o `release-aab.yml` rodar. | Sônia |
| 3 | **`BMV_GOOGLE_SERVICES_JSON_B64`** precisa existir, do app Android oficial no Firebase Console. | Sônia |
| 4 | **Execução do pipeline oficial** para produzir o AAB assinado pela chave de upload. | depende de 1–3 |

### 17.2 Bloqueia a publicação em produção (além dos acima)

| Bloqueio | Referência |
|---|---|
| **Mocks em 13 telas** apresentados como dados do jogador (Ranking, Saguão, Amigos, Hall, Recompensas, Loja, Início, Configurar Mesa, Preparando Partida) | §11.2 |
| Ficha da Loja: política de privacidade, URL de exclusão de conta, e-mail de suporte, descrições, categoria, screenshots, feature graphic | [PUBLICACAO-GOOGLE-PLAY-V1.md §8](PUBLICACAO-GOOGLE-PLAY-V1.md) |
| Classificação indicativa (IARC) | idem §5 |
| Produtos e preços na Play Console (mensal R$ 19,90 · trimestral R$ 49,90 · anual R$ 149,90) | [PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md](PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md) |
| Tópico RTDN, IAM e deploy do backend de Billing | [RTDN-VIP-PRODUCAO.md](RTDN-VIP-PRODUCAO.md) |

### 17.3 Pode ficar para depois do lançamento

| Item |
|---|
| `assets/splash.jpg` e a classe `SplashScreen` — código morto, remover |
| `mesa_vip_preview_screen.dart` e `reward_grants.dart` — código morto |
| Arquivos `.dart` soltos dentro de `.github/workflows/` e de `app/assets/` |
| Padronizar o prefixo das seis suítes `teste_*.dart` para `*_test.dart` |
| Reduzir o AAB via `ndk.debugSymbolLevel`, se a folga de 20 MB apertar |
| Ícone redondo (`ic_launcher_round`) — o adaptive icon já cobre API 26+ |

---

## 18. Veredito

**REPROVADO** para o primeiro upload de homologação.

A engenharia desta OS está completa e provada: identidade final, AAB gerado e
validado, assinatura por Secrets, `targetSdk 36`, ícone oficial dentro do
artefato, permissões extraídas do artefato, Billing compilada no dex, pipeline
único e — pela primeira vez — executável fora do CI. Dois defeitos latentes que
teriam reprovado todo build foram encontrados e corrigidos.

O veredito não é sobre isso. A §17 da OS exige **SIM, com evidência, para
todos** os critérios, e dois não podem ser respondidos SIM:

- **"assets necessários estão no artefato"** — 46 artes de `assets/loja/` não
  existem, numa tela alcançável em produção (§9);
- **"mocks não são apresentados como dados reais em release"** — 13 telas ainda
  montam VM de exemplo (§11.2). O caso mais grave, `statsDemo`, foi corrigido;
  o restante é a arquitetura atual do `main.dart` e exige as fontes reais de
  dados, que são outras OS.

O AAB compilou, validou e passou em todas as conferências de artefato. Isso não
é o mesmo que estar pronto para publicação — e é exatamente a distinção que o
princípio desta OS pede que se respeite.

---

*Nenhum merge, deploy ou upload foi realizado. O AAB desta OS foi gerado*
*localmente, assinado com chave de verificação descartável, e não é publicável.*
