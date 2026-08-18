# Integração do splash Rive "Constelação Master VIP" — V1

**Veredito: `PASS — ABERTURA EM RIVE INTEGRADA À CASCA CANÔNICA, COM PORTÃO DUPLO`**

| | |
| --- | --- |
| Branch | `claude/integracao-splash-rive-constelacao-v1` |
| Base | `integracao/avatar-ranking-estatisticas-navegacao-publica-v1` @ `089cb5e` |
| Publicada | sem merge, sem PR, sem deploy, sem tag |

---

## 1. Gate Zero

### 1.1 Base canônica

`origin/integracao/avatar-ranking-estatisticas-navegacao-publica-v1` está
publicada. O SHA remoto foi provado **duas vezes** por `git ls-remote`, e as duas
leituras deram `089cb5ee8e050f8903aabd8336509973834c9a7a`.

Ancestralidade dos três marcadores arbitrados, por
`git merge-base --is-ancestor`:

| Marcador | SHA completo | Resultado |
| --- | --- | --- |
| `41a767a` | `41a767a49353575b9a251119c0753782659ec3e6` | ANCESTRAL |
| `79063e07` | `79063e07c38e1b2601058504b0083d4a41a33223` | ANCESTRAL |
| `53105ab` | `53105ab861e32cbcaa6ea19bb81e29549276bf98` | ANCESTRAL |

### 1.2 Não existe base posterior com autoridade

`git branch -r --contains 089cb5e` devolve **três** refs, e nenhuma delas é uma
integração homologada posterior:

| Ref | O que é |
| --- | --- |
| `integracao/avatar-ranking-estatisticas-navegacao-publica-v1` | a própria base |
| `claude/configuracao-mesa-apostas-canonicas-v1` | laudo BLOCKED, só documento (154 linhas de `.md`, zero código) |
| `claude/meta-canonica-lobby-v1` | folha de funcionalidade, publicada sem merge; o laudo dela **nomeia `089cb5e` como sua base** |

Nenhuma é `integracao/` ou `homologacao/`. A base preferencial da OS está
publicada e provada, e o §3.2.1 fecha aí. Não houve escolha por data, nome
parecido ou conveniência.

### 1.3 A candidata local que NÃO entrou

Existe na máquina uma implementação anterior de splash em Rive:
`claude/splash-rive-alternativa-producao-753f32` @ `129ee1d`. Ela **não foi
usada como base e não foi mesclada**, por três razões que o Gate Zero mediu:

- não está publicada (`git ls-remote origin 'refs/heads/*splash*'` devolve vazio);
- descende de `426ea2a` e **não contém `089cb5e`**;
- resolve outro problema — uma variante A/B selecionável por
  `--dart-define=BMV_SPLASH=rive`, com o `.riv` ausente do repositório.

Ela foi lida como referência (a versão do pacote `rive` que resolve nesta
toolchain veio dessa leitura) e nada mais.

### 1.4 Inspeção arquitetural

| Pergunta da OS | Resposta na base |
| --- | --- |
| Ponto único de criação do app raiz | `app/lib/main.dart` → `RaizDoAplicativo` |
| Bootstrap | `main.dart` (binding + Firebase); `raiz_do_aplicativo.dart` (sessão, autenticação, transporte, ranking) |
| Autoridade que decide Login/Home | `casca_de_producao.dart`, lendo `SessaoDoJogador` |
| Roteador | declarativo: `MaterialApp.home` com chave por geração de sessão |
| Splash existente | `screens/splash_oficial_screen.dart`, já com o contrato `onConcluida` |
| Splash nativo Android | **não versionado**: `app/android/` não existe; quem o configura é `build.yml`, no scaffold gerado por `flutter create` |
| Dependência Rive | ausente |
| `main.dart` é bancada de prévias? | **não** — a Casca de Produção já havia encerrado isso |

**A base já tinha o portão duplo.** `casca_de_producao.dart` espera
`sessao.resolvida` **e** `aberturaTerminou` antes de desenhar Login ou Home. Esta
OS não criou arquitetura de inicialização nenhuma: trocou o que a abertura
DESENHA e manteve intacto quem decide o destino.

### 1.5 Linha de base ANTES de editar

| Medida | Base `089cb5e` |
| --- | --- |
| `flutter analyze` | 103 diagnósticos — 93 `info`, 10 `warning`, **0 `error`** |
| `flutter test` (glob) | **1153 casos, todos verdes** |
| `test/casca` · `test/sessao` · `test/ranking` | 244 · 83 · 183, verdes |

Nenhum teste canônico estava vermelho antes da mudança.

---

## 2. O binário autoritativo

| Conferência | Esperado pela OS | Medido |
| --- | --- | --- |
| Tamanho | 2.298.957 bytes | **2.298.957** |
| SHA-256 | `a5a7ca19…d4d67d` | **`a5a7ca1912de6f301b8a5c022151c7f14d6ae07228fa9c9dd49076fb2ea4d67d`** |
| Cabeçalho | `RIVE` | **`RIVE`** |

Caminho efetivo: `app/assets/rive/splash_constelacao_master_vip_v2.riv`.

O arquivo **não foi recriado, reexportado, recomprimido nem editado** — foi
copiado do anexo e conferido antes e depois da cópia, antes e depois do commit,
e de novo de dentro do APK.

`.gitattributes` novo, com `*.riv binary`. Não é zelo: este repositório está com
`core.autocrlf=true`, e sem a linha a preservação byte a byte dependeria da
heurística de detecção de binário do git.

---

## 3. O que foi construído

```
app/lib/casca/splash/
  contrato_da_abertura.dart      os nomes, as durações, a cor, e a porta
  splash_constelacao_screen.dart a primeira tela Flutter
  abertura_rive.dart             a ÚNICA porta para package:rive
```

### 3.1 O portão duplo

O fluxo é o da OS, e ele não é novo — é o que a Casca já fazia:

```
tela nativa do Android (#050B1E)
        ↓ primeiro quadro Flutter
SplashConstelacaoScreen → artboard SplashConstelacao / timeline entrada_splash
        ↘ o bootstrap canônico segue em paralelo
        ↓ a timeline termina (ou o relógio de segurança marca)
a casca continua desenhando a abertura enquanto a sessão não responde
        ↓ sessao.resolvida == true  E  aberturaTerminou == true
CascaDeProducao decide: LoginDeProducao ou HomeDeProducao
```

A saída da tela é `onConcluida`, chamada **no máximo uma vez**, por um único
caminho (`_encerrarAnimacao`) guardado por `_concluiu` e por `mounted`. A tela
não conhece `Navigator`, não lê a sessão e não sabe o que é Home — a suíte
afirma isso arquivo por arquivo.

### 3.2 O relógio de segurança, e o que ele NÃO faz

Armado **antes** do carregamento, em `duração × 7/6` — 3 s × 7/6 = **3,5 s**,
exatamente o que a OS pede. Ele marca **apenas** "animação encerrada".

Ele **não afirma bootstrap pronto**. Uma sessão que não respondeu continua não
tendo respondido, e quem se pronuncia é o teto de 8 s que a Casca já tinha, com
estado explícito e botão. Isso tem caso próprio: `R03`.

A proporção existe por um motivo prático: os testes de widget encurtam a
abertura, e uma margem fixa de meio segundo faria cada caso da suíte esperar
meio segundo de relógio falso por nada.

### 3.3 Movimento reduzido

Quando a plataforma pede animações reduzidas, a arte **não é sequer carregada**:
o fundo estável fica no ar por `duração × 1/5` e a abertura se encerra. Sem
laço, sem bloqueio, e o bootstrap continua mandando. Caso `W09`.

### 3.4 A porta estreita, e por que ela existe

`rive_native` é uma **biblioteca dinâmica baixada no build da plataforma alvo**.
Dentro de `flutter test` ela não existe — e o pacote não apenas lança, ele
REPORTA o erro ao framework, o que `flutter_test` trata como reprovação.

Sem uma porta, duas coisas seriam verdade ao mesmo tempo: nenhum caso de corrida
seria testável, e **todo** teste de widget que montasse o aplicativo cairia por
causa do ambiente. Por isso `FonteDaAbertura` existe, e por isso as três
bancadas de teste da Casca passaram a injetar um dublê.

A porta não pode ser contornada, e três casos afirmam isso: `package:rive` é
importado num arquivo só (`A08`), a fonte real é construída num lugar só
(`A09`), e o padrão de produção continua sendo a fonte real.

### 3.5 O som foi preservado

`assets/splash/splash_intro.mp3`, com o mesmo volume, a mesma proteção contra
ambiente sem plugin de áudio e o mesmo `habilitarSom`. Não estava no escopo
mexer nisso, e tirá-lo em silêncio seria regressão.

---

## 4. Onde a abertura foi ligada

Ponto exato: `app/lib/casca/casca_de_producao.dart`, método `_splash()`.

```diff
-  Widget _splash() => SplashOficialScreen(
+  Widget _splash() => SplashConstelacaoScreen(
```

Nada mais mudou na decisão de tela. `screens/splash_oficial_screen.dart`
continua no repositório como catálogo visual; o que acabou foi o **caminho** até
ela a partir de `main()`, e o fecho alcançável mede exatamente isso.

Quinta costura de teste em `RaizDoAplicativo`: `fonteDaAbertura`, nula em
produção, pelo mesmo motivo das outras quatro.

---

## 5. Runtime Rive

| | |
| --- | --- |
| Versão | `rive: ^0.14.11` → resolvido em **0.14.11**, com `rive_native 0.1.11` |
| Por quê | é a versão que resolve **offline** no cache desta máquina e satisfaz `sdk: ^3.11.1` (o pacote exige `>=3.6.0 <4.0.0` e Flutter `>=3.28.0`) |
| Upgrade amplo | **não houve**: `pubspec.lock` ganhou 3 pacotes (`rive`, `rive_native`, `graphs`) e **nenhuma versão existente mudou** |

### 5.1 O custo que precisa ficar registrado

`rive_native` **não traz `.so` prontos**. O gradle do plugin dispara
`dart run rive_native:setup -p android`, que **baixa** as bibliotecas de
`rive-flutter-artifacts.rive.app`.

- **O build precisa de rede.** Se aquele host cair, o APK não sai.
- **A execução não precisa.** O `.riv` e as `.so` viajam dentro do APK — provado
  na §7.
- Isso acrescenta 3 bibliotecas nativas ao artefato (7,7 MB arm64-v8a, 6,7 MB
  armeabi-v7a, 8,1 MB x86_64, **sem compressão**). O impacto no tamanho do
  release não foi medido nesta OS.

---

## 6. Matriz de testes

Suíte nova: `app/test/splash/splash_constelacao_test.dart` — **34 casos**.

| Grupo | Casos | O que provam |
| --- | --- | --- |
| `ASSET` | A01–A11 | arquivo presente, declarado, entregue pelo bundle, cabeçalho `RIVE`, tamanho e SHA-256 do binário aprovado, os nomes do contrato existindo DENTRO do `.riv`, nenhuma string divergente em `lib/`, `package:rive` contido, fonte real num lugar só, `contain`+centralizado, escolha por nome e não por posição, `State Machine` não usada |
| `ABERTURA` | W01–W11 | uma saída só; timeline avisando duas vezes; corrida com o relógio; timeline que nunca termina; **as quatro** falhas de carregamento; arte que entra; tela desmontada sem saída tardia nem exceção; arte que chega depois da desmontagem é devolvida; movimento reduzido; MediaQuery mudando no meio; segundo plano e volta |
| `LAYOUT` | L01–L04 | o **primeiro** quadro já é `#050B1E`; nenhum AppBar/texto/controle/indicador; a arte ocupa a janela inteira em 4 superfícies (telefone estreito, 9:16, alta e recortada, larga); escala de texto 2× não mexe na arte |
| `ROTEAMENTO` | R01–R06 | bootstrap pronto antes → a abertura toca até o fim; animação pronta antes → espera o bootstrap; **arte quebrada não mascara sessão que não responde**; a abertura não conhece rota/sessão/destino; a casca é o único ponto que a monta; a casca continua exigindo as duas condições |

### 6.1 Comandos e resultados

Overlay local espelhando `ci-os-integracao.yml` (scaffold do `flutter create` +
`pubspec.yaml`/`.lock` do repositório + `lib/` + assets + suítes).

| Comando | Resultado |
| --- | --- |
| `flutter pub get` | OK, offline |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **103 diagnósticos — a lista é BYTE A BYTE idêntica à da base** |
| `flutter test test/splash/splash_constelacao_test.dart` | **+34 verde** |
| `flutter test test/casca` | **+244 verde** |
| `flutter test test/sessao` | **+83 verde** |
| `flutter test test/ranking` | **+183 verde** |
| `flutter test test/online_auth_test.dart` | **+31 verde** |
| `flutter test test/conexao_producao_test.dart` | **+43 verde** |
| os 12 alvos nomeados do `ci-os-integracao` | **todos verdes** |
| `flutter test` (glob) | **+1187 verde** (base: 1153 → **+34, exatamente a suíte nova**) |
| `flutter build apk --debug` | **APK gerado** |

Nenhum teste foi removido, afrouxado ou renomeado.

### 6.2 Os testes existentes que foram TOCADOS, e por quê

| Arquivo | O que mudou | Por quê |
| --- | --- | --- |
| `casca_producao_test.dart` | 4 asserções `find.byType(SplashOficialScreen)` → `SplashConstelacaoScreen`; 1 import; injeção do dublê | a casca trocou de abertura; a **afirmação** ("a splash cobre a espera inteira") é a mesma |
| `homologacao_casca_v2_test.dart` | injeção do dublê | o runtime nativo não sobe em `flutter test` |
| `bancada_online.dart` | injeção do dublê | idem |
| `avatar_publico_canonico_test.dart` | o fecho alcançável: 48 → **50** | +3 arquivos da abertura, **−1** (`splash_oficial_screen.dart` saiu do caminho que nasce em `main()`) |

O caso do fecho segue a disciplina que o próprio arquivo impõe: o total **não**
foi trocado sozinho. Os três que entraram estão nomeados, o que saiu está
nomeado, e há uma asserção nova exigindo que a abertura anterior **continue
fora** — duas aberturas alcançáveis seriam duas inicializações concorrentes.

### 6.3 Campanha de mutação

Cada mutante foi aplicado no overlay com conferência de que a âncora casou
(comparação de hash do arquivo antes/depois), e revertido em seguida.

| Mutante | Resultado |
| --- | --- |
| tirar a idempotência de `_encerrarAnimacao` | **morto** |
| `Fit.contain` → `Fit.fill` | **morto** |
| trocar o nome do artboard | **morto** |
| não devolver a arte no `dispose` | **morto** |
| não devolver a arte que chega tarde | **morto** |
| relógio de segurança para 1 dia | **morto** (5 casos) |
| timeline por posição em vez de por nome | **morto** |
| fundo branco em vez de `#050B1E` | **morto** |
| movimento reduzido passar a carregar a arte | **morto** |
| tirar **só** a guarda `mounted` de `_encerrarAnimacao` | **sobreviveu** |
| tirar **só** a guarda `mounted` do retorno da timeline | **sobreviveu** |
| tirar **as duas** guardas juntas | **morto** (`W07`) |

Os dois sobreviventes são redundância deliberada: as guardas se cobrem, então
remover uma sozinha não muda comportamento observável. A combinação é pega.
Está registrado aqui em vez de "9 de 9" porque a diferença importa.

---

## 7. Evidências de execução real

### 7.1 O runtime Rive, de verdade

Com a biblioteca nativa de desktop instalada
(`dart run rive_native:setup -p windows`), o binário do repositório foi aberto
pelo runtime REAL:

```
artboard=SplashConstelacao  bounds=1080x1920
timeline=entrada_splash     duracao=3.0s
parou em t=3.0s  time=3.000  duration=3.0
```

- a proporção de autoria bate: **1080 × 1920**, retrato;
- a duração bate: **exatamente 3,0 s**;
- **reprodução única**: a timeline para em 3,0 s e não reinicia;
- `artboard('SplashConstelacaoX')` e `animationNamed('entrada_splash_x')`
  devolvem `null` — a escolha é mesmo **por nome**.

### 7.2 A abertura completa, quadro a quadro

Montando `SplashConstelacaoScreen` com a fonte REAL e a arte REAL, e gravando o
`RepaintBoundary`:

| Quadro | O que mostra |
| --- | --- |
| `01_inicio.png` | `#050B1E` **liso** — a prova de que não há lampejo branco no primeiro quadro |
| `02_um_terco.png` | ainda o fundo, arte carregando |
| `03_dois_tercos.png` | coroa, brasão e espadilha no ar; o texto ainda não entrou |
| `04_final.png` | a arte inteira, com "BURACO MASTER VIP" na Cinzel embutida |

E, ao fim da reprodução real, `onConcluida` foi chamada **exatamente uma vez**.

### 7.3 O APK

`flutter build apk --debug` no overlay, e depois **extraindo do APK**:

```
assets/flutter_assets/assets/rive/splash_constelacao_master_vip_v2.riv
  2298957 bytes
  sha256 a5a7ca1912de6f301b8a5c022151c7f14d6ae07228fa9c9dd49076fb2ea4d67d
lib/arm64-v8a/librive_native.so      7.675.336
lib/armeabi-v7a/librive_native.so    6.739.096
lib/x86_64/librive_native.so         8.088.648
```

O binário dentro do APK é **byte a byte** o aprovado, e as bibliotecas nativas
estão empacotadas. **É isto que prova que a abertura roda offline**: não há uma
requisição a fazer no cold start.

### 7.4 O que NÃO foi provado

- **Cold start em aparelho ou emulador.** Não há dispositivo nem emulador
  Android disponível neste ambiente. A prova de que a arte desenha é a §7.2,
  feita no runtime real mas fora do Android; a prova de que ela chega ao
  aparelho é a §7.3. O comportamento visual do cold start **no aparelho** segue
  não medido, e a OS manda declarar isso em vez de simular PASS.
- **O `ci-os-integracao.yml` não roda nesta branch**: ele dispara só em push
  para `integracao/os-final-backend-flutter`, e `workflow_dispatch` não alcança
  arquivo que não está em `main`. O gate `splash` foi adicionado e o YAML foi
  validado por parser, mas ele não executou no GitHub.
- **Tamanho do APK de release** com as bibliotecas nativas: não medido.

---

## 8. Splash nativo do Android

`app/android/` **não existe no repositório** — o scaffold é gerado pelo CI. Por
isso a adaptação autorizada pelo §2.7 foi feita onde o mecanismo de fato mora:
o passo `Configure dark native launch screen` do `build.yml`.

Mudou **só a cor**: `#050201` → `#050B1E`. O mecanismo continua idêntico —
`splash_background` em `values/` e `values-night/`, `launch_background.xml` em
`drawable/` e `drawable-v21/`, cobrindo Android 12+ e anteriores. Nada foi
removido.

E há uma trava contra as duas cores divergirem em silêncio: o passo lê
`contrato_da_abertura.dart` e **falha o build** se `kFundoDaAbertura` não for a
mesma cor. Sem ela, alguém mudaria o fundo da arte um dia e o lampejo voltaria
sem nenhum teste acusar.

---

## 9. Workflows

`on:`, `branches:`, `permissions:` e `env:` dos dois arquivos são **byte a byte
idênticos** aos da base. Nenhum evento, branch, secret ou permissão foi
ampliado. Os dois foram validados por parser YAML.

### `build.yml`

1. `rive:^0.14.11` no `flutter pub add`, e `dev:crypto` nas deps de teste (é o
   `crypto` que confere o SHA-256; ele é **dev**, então não entra no APK);
2. passo novo de cópia do `.riv`, com conferência de tamanho, SHA-256 e
   cabeçalho;
3. `assets/rive/` declarado no script do `pubspec` e na trava de asserções;
4. a cor da tela nativa, com a trava contra divergência;
5. portão novo `PORTÃO DA ABERTURA`;
6. conferência do `.riv` **extraído** do APK e da presença das `.so`.

**Por que o portão da abertura está lá embaixo, e não junto dos outros:** neste
workflow os portões rodam **antes** de os assets serem copiados e declarados no
`pubspec`, e metade da suíte lê o `.riv` pelo **bundle**. Rodá-la antes provaria
o arquivo no disco, que é outra coisa. É também por isso que a suíte mora em
`app/test/splash/` e não em `app/test/casca/`.

### `ci-os-integracao.yml`

Um gate novo, `splash`, e nada mais. Este workflow copia `app/assets` inteiro e
o `pubspec.yaml` do repositório logo no começo, então a ordem já estava certa.

---

## 10. Limites e pendências reais

1. **Cold start em aparelho não foi provado.** Sem dispositivo/emulador aqui.
2. **O build passou a depender de rede** para baixar as bibliotecas nativas da
   Rive. A execução, não.
3. **Não há observabilidade alcançável pela raiz nesta base.** A OS manda
   registrar falha pela observabilidade existente "sem criar coletor
   concorrente" — não existindo nenhuma, o motivo da falha é guardado como
   estado (`FalhaDaAbertura`) e afirmado por teste, e nada é escrito em log.
   Quando a camada de observabilidade entrar na linhagem, este é o ponto a ligar.
4. **`ci-os-integracao.yml` não executou** — não é dispatchável fora de `main`.
5. **Tamanho do APK de release não foi medido** com as bibliotecas nativas.
6. **`State Machine 1` continua vazia e sem uso.** É o contrato desta V1: a
   autoridade é a timeline nomeada. Se um dia a arte ganhar estados, isso é
   outra OS.
7. **A `screens/splash_oficial_screen.dart` continua no repositório**, fora do
   caminho de produção. Removê-la não foi autorizado e não é necessário.

---

## 11. Nada foi publicado além da branch

Sem merge em `main`, sem PR, sem tag, sem release, sem deploy, sem publicação na
Play. Sem ampliação de permissões de workflow.
