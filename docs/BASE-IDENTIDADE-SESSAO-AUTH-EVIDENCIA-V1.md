# Base canônica de identidade, sessão e autenticação — Evidência V1

Comandos, exit codes, contagens e ambiente. O que foi executado está aqui com o
número; o que **não** foi executado está marcado como não executado, e não como
verde.

---

## 1. Ambiente

```
Flutter   3.41.4 · channel stable · revision ff37bef603
Dart      3.11.1 (stable) · windows_x64
Git       2.55.0.windows.2
SO        Windows 11 Home Single Language 10.0.26200
```

`app/` é um pacote Dart de verdade a partir da Folha A (que trouxe
`pubspec.yaml` e `pubspec.lock`), então as suítes rodam direto na árvore, sem o
scaffold `app_build` do CI.

---

## 2. Gate zero — entradas congeladas

### 2.1 Fetch com refspec completo

```
$ git config --get-all remote.origin.fetch
+refs/heads/*:refs/remotes/origin/*

$ git fetch --all --prune
exit 0
```

Refspec verificado explicitamente antes do fetch. Um refspec truncado faria
`fetch --all` responder "up to date" sobre refs congeladas, e a medição de
ancestralidade sairia mentirosa.

Refs remotas após o fetch: **102** heads (`git ls-remote --heads origin`).

### 2.2 Duas consultas, com intervalo

```
$ git ls-remote origin refs/heads/{consolidacao/apk-geral-bmv,claude/identidade-sessao-canonica-flutter,claude/ws-auth-identidade-1fc213,main}
```

| Ref | 1ª consulta | 2ª consulta (04:24:41Z) | Estável |
|---|---|---|---|
| `consolidacao/apk-geral-bmv` | `0cea0d6d…` | `0cea0d6d…` | ✔ |
| `claude/identidade-sessao-canonica-flutter` | `3c6eb8da…` | `3c6eb8da…` | ✔ |
| `claude/ws-auth-identidade-1fc213` | `13582ddf…` | `13582ddf…` | ✔ |
| `main` | `fb9edb5c…` | `fb9edb5c…` | ✔ |

Os três SHAs batem com a §2 da OS, caractere por caractere.

### 2.3 Branch de saída inexistente

```
$ git ls-remote origin refs/heads/integracao/identidade-sessao-ws-auth-v1
(vazio)

$ git show-ref --verify --quiet refs/heads/integracao/identidade-sessao-ws-auth-v1
NAO EXISTE
```

Nome livre nos dois lados. Não foi preciso sufixo.

### 2.4 Árvore limpa

O worktree tinha resíduo não versionado herdado de uma sessão anterior. Ele foi
**enumerado**, e não presumido inofensivo:

```
app/.dart_tool/**            artefato de `flutter pub get`
app/build/**                 artefato de `flutter test`
app/.flutter-plugins-dependencies
firestore-debug.log · firebase/firestore-debug.log
functions/lib/*.js · functions-moderacao/lib/*.js   saída de build das Functions
**/node_modules/**
```

Fora de `.dart_tool`, `build` e `node_modules`, o total é de **11 arquivos**,
todos saída de build ou log. **Nenhuma fonte.** Todos são cobertos pelo
`.gitignore` que a Folha A traz, e por isso a árvore ficou `git status`
**vazio** já a partir do primeiro merge — o que é a prova, e não a promessa, de
que não havia trabalho não versionado.

### 2.5 Topologia

```
$ git merge-base 0cea0d6d 3c6eb8da   ->  0cea0d6d
$ git merge-base 0cea0d6d 13582ddf   ->  0cea0d6d
$ git merge-base 3c6eb8da 13582ddf   ->  0cea0d6d
$ git merge-base --all 3c6eb8da 13582ddf -> 0cea0d6d   (base única)

$ git merge-base --is-ancestor 0cea0d6d 3c6eb8da  -> 0   (SIM)
$ git merge-base --is-ancestor 0cea0d6d 13582ddf  -> 0   (SIM)
$ git merge-base --is-ancestor 3c6eb8da 13582ddf  -> 1   (NÃO)
$ git merge-base --is-ancestor 13582ddf 3c6eb8da  -> 1   (NÃO)
```

Commits exclusivos: Folha A **49**, Folha B **2**.
Arquivos tocados: Folha A **213**, Folha B **5**.
Sobreposição: **2** arquivos (`build.yml`, `main.dart`).

### 2.6 Suítes focadas de cada folha, no SHA congelado

Executadas em exportações limpas (`git archive <sha> app | tar -x`) no
scratchpad, sem contaminação da árvore de trabalho.

| Folha | SHA | Comando | Testes | Exit |
|---|---|---|---|---|
| A | `3c6eb8da` | `flutter test test/sessao` | **51** | **0** |
| B | `13582ddf` | `flutter test test/online_auth_test.dart` | **31** | **0** |

Nota sobre a Folha B: no SHA dela `app/` ainda **não** era um pacote (o
`pubspec.yaml` chega com a Folha A). Foi preciso reproduzir o overlay que o
`build.yml` da própria folha monta em CI — `flutter create` + `pub add` das
mesmas dependências, incluindo `dev:stream_channel` e `dev:fake_async`. O
pubspec de overlay ficou no scratchpad e **não** foi versionado.

**Gate zero: PASS.**

---

## 3. Composição

| Passo | Comando | Resultado |
|---|---|---|
| 1 | `git checkout -b integracao/identidade-sessao-ws-auth-v1 0cea0d6d` | HEAD inicial `0cea0d6d` |
| 2 | `git merge --no-ff 3c6eb8da` | `Automatic merge went well` · **0 conflitos** · `d6cd313` |
| 3 | `tree(d6cd313) == tree(3c6eb8da)` | **SIM** — nada da folha se perdeu |
| 4 | `flutter test test/sessao` | **51** · exit **0** |
| 5 | `git merge --no-ff 13582ddf` | `Auto-merging build.yml` + `main.dart` · **0 conflitos** · `9d6d7af` |
| 6 | `flutter test test/online_auth_test.dart` | **31** · exit **0** |

Os dois arquivos auto-mesclados foram conferidos **semanticamente**, não
presumidos corretos — ver
[CONFLITOS](BASE-IDENTIDADE-SESSAO-AUTH-CONFLITOS-V1.md) §2 e §3.

---

## 4. Reconciliação e suítes finais

### 4.1 `flutter analyze`

| Árvore | Issues | Errors | Exit |
|---|---|---|---|
| `9d6d7af` (merge, antes da reconciliação) | **42** | **0** | 1 |
| HEAD final (depois da reconciliação) | **42** | **0** | 1 |

**Delta zero.** Os 42 são `info`/`warning` pré-existentes (`withOpacity`
depreciado, campos não usados em telas), nenhum deles nos arquivos tocados por
esta composição — verificado por filtro sobre `online_service`,
`ponte_sessao_online`, `sessao/`, `main.dart` e `credencial_de_sessao`:
**nenhuma ocorrência**.

O exit 1 é o comportamento do `flutter analyze` diante de qualquer issue,
inclusive `info`. Ele é o mesmo antes e depois, e por isso não é regressão.

### 4.2 Suítes obrigatórias

| # (OS §8) | Suíte | Testes | Exit |
|---|---|---|---|
| 1–13 | `test/sessao/uniao_sessao_transporte_test.dart` — **nova** | **32** | **0** |
| 14 | `test/sessao/` — originais da Folha A, íntegros | **51** | **0** |
| 15 | `test/online_auth_test.dart` — original da Folha B, íntegro | **31** | **0** |
| 16 | `flutter analyze` | 42 issues / 0 errors | 1 (= baseline) |
| 16 | `flutter test` (glob `*_test.dart`) | **621** | **0** |
| 16 | as 7 suítes com prefixo `teste_` | **549** | **0** |

**Total da árvore integrada: 1170 testes, todos verdes.**

Nenhum teste foi desabilitado, marcado como `skip` ou removido. As contagens de
14 e 15 são **idênticas** às medidas nos SHAs congelados (51 e 31) — as folhas
não perderam cobertura na composição.

### 4.3 Por que 621 e não 1170 no comando padrão

`flutter test` sem argumentos coleta apenas `*_test.dart`. Sete arquivos usam o
prefixo `teste_` e ficam **fora do glob**:

```
test/teste_encerramento.dart          test/moderacao/teste_moderacao.dart
test/teste_motor.dart                 test/motor/teste_visao_espectador.dart
test/teste_motor_resiliencia.dart     test/social/teste_social.dart
test/integracao/teste_integracao_motores.dart
```

Foram executados explicitamente, e é a soma dos dois comandos que dá o número
real da árvore. Um relatório que dissesse "621, tudo verde" estaria escondendo
metade da suíte.

### 4.4 As 4 suítes que exigem o overlay de seeds

`test/torneios/{reward_grants,motor_torneios}_test.dart` e
`test/colecoes/{evidencias_visuais,kit_pioneiros}_test.dart` procuram seeds em
`test/<dir>/data/`, mas os seeds moram em `app/data/`. Sem o overlay, as quatro
falham **ao carregar**:

```
Failed to load … : Cannot open file, path = 'test/torneios/data/assets_registry.seed.json'
Failed to load … : Bad state: seed nao encontrado: …
```

É condição **pré-existente do ambiente local**, não regressão desta composição —
o `build.yml` faz essa cópia em CI (linhas 238–241). O overlay foi reproduzido
à mão (`cp app/data/*/*.json test/*/data/`), a suíte rodou verde, e **as cópias
foram removidas antes do commit**. `git status` confirma que nada disso entrou
na branch.

Duas PNGs de evidência (`test/colecoes/evidencias/`) são reescritas pela própria
suíte ao rodar. Foram restauradas com `git checkout --` e **não** foram
commitadas: são efeito colateral de execução, não trabalho desta OS.

---

## 5. O que NÃO foi executado

Registrado como não executado, e não como verde:

* **`.github/workflows/build.yml`.** O CI deste repositório só dispara por
  `workflow_dispatch`, e a partir da branch padrão. Esta branch não foi mesclada
  em lugar nenhum, então o pipeline **não rodou**. Os quatro portões foram
  conferidos por leitura (ordem, pré-condições, passo de dependências antes
  deles) — o que prova coerência do arquivo, e não execução.
* **Nenhum deploy, AAB, APK ou operação no Google Play Console.** Fora do escopo
  da OS e não tentados.
* **Nenhum emulador do Firebase.** Esta composição não toca Functions, Rules nem
  servidor.

---

## 6. Reprodução

```bash
git fetch --all --prune
git checkout -b <nome> 0cea0d6d68f2c93613b985f4aa85800d77cf42d7
git merge --no-ff 3c6eb8da7da59fd2f6823d770b9eeb67ddf94d69
git merge --no-ff 13582ddfa0f9b8cccc81b20e51705bf666ca8754
# aplicar a reconciliação (commit fix(uniao)) e a suíte (commit test(uniao))

cd app
flutter pub get
flutter analyze                                    # 42 issues, 0 errors
flutter test test/sessao                           # 51
flutter test test/online_auth_test.dart            # 31
flutter test test/sessao/uniao_sessao_transporte_test.dart   # 32

# overlay de seeds — necessário só localmente, NÃO commitar
mkdir -p test/torneios/data test/colecoes/data
cp data/torneios/*.json test/torneios/data/
cp data/colecoes/*.json test/colecoes/data/
flutter test                                       # 621
flutter test test/teste_encerramento.dart test/teste_motor.dart \
             test/teste_motor_resiliencia.dart \
             test/integracao/teste_integracao_motores.dart \
             test/moderacao/teste_moderacao.dart \
             test/motor/teste_visao_espectador.dart \
             test/social/teste_social.dart          # 549
rm -rf test/torneios/data test/colecoes/data
git checkout -- test/colecoes/evidencias/
```

---

## 7. Recibo final

### Commits criados por esta OS

```
d6cd313  merge: Folha A — identidade e sessao canonica do jogador
9d6d7af  merge: Folha B — cliente WebSocket autenticado (protocolo 2)
72c8a9b  fix(uniao): a sessao vira a dona unica da credencial do transporte
81b48d6  test(uniao): os treze casos do contrato conjunto (OS §8.1..§8.13)
<tip>    docs(uniao): manifesto, contrato, conflitos e evidencia   ← este documento
```

### O SHA-base para a OS da Casca

> **A OS `CASCA REAL DE PRODUÇÃO, AUTENTICAÇÃO E ROTEAMENTO V1` deve ser
> reiniciada em BRANCH NOVA a partir do tip de
> `integracao/identidade-sessao-ws-auth-v1`.**

O SHA literal do tip está no relatório final desta entrega, junto da prova
`local == remoto` por `git ls-remote`. Ele também é obtível a qualquer momento:

```bash
git ls-remote origin refs/heads/integracao/identidade-sessao-ws-auth-v1
```

**A branch bloqueada da Casca não deve ser continuada.** Ela nasceu de
`0cea0d6d`, que não tem sessão — foi exatamente por isso que ela parou no Gate
zero, e continuar nela reintroduziria o pré-requisito ausente.
