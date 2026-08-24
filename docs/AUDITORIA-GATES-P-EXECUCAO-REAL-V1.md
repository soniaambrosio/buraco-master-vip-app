# OS 47 — AUDITORIA FAIL-CLOSED DOS GATES DECLARADOS E NÃO EXECUTADOS V1

Auditoria **somente leitura**, executada em 2026-08-24. Nenhum arquivo produtivo
foi alterado; nenhuma composição foi feita; nenhum saneamento foi aplicado.
Toda medição rodou em bancadas fora do repositório (`C:\os47bench`,
`C:\os47camp`, `C:\os47triv`, `C:\os47res`) e num worktree destacado descartável.

---

## 0. VEREDITO

**A arquitetura de gates da linhagem P está íntegra e é fail-closed. Ela não roda.**

As duas metades desta frase foram medidas separadamente, e as duas são fortes:

* **O mecanismo passa.** Os 65 gates declarados na fonte única têm produtor no
  workflow (bijeção exata, sem órfão dos dois lados), e os 65 participam do
  veredito: **325 sabotagens mínimas executadas — cinco por gate — e 325
  detectadas, zero escapes.** "NÃO EXECUTADO tratado como verde" não existe
  nesta ponta: é impossível por construção, e foi provado gate a gate.
* **Nada disso executa.** O único workflow que produz os marcadores
  (`ci-os-integracao.yml`) **não dispara nesta ponta e não é dispachável**. A
  última execução real do agregador foi em **2026-08-18**, sobre `e0cf917`, com
  **36 gates** — **373 commits e 634 arquivos atrás** da ponta auditada. Dos 65
  gates de hoje, **30 nunca foram executados em run nenhum**.

E há um custo já materializado: **dois gates obrigatórios estão VERMELHOS nesta
ponta**, os dois medidos aqui — `rankingfn` (461/462) e `contratosui` (caso
T27). O portão desta ponta, se rodasse hoje, sairia VERMELHO — e ninguém sabe
disso porque ele não roda.

**Classificação global: `FAIL — declaração não produz execução real`**, aplicada
aos 65 gates pelo mesmo motivo único (item 6 do §1 da OS: gate chamado apenas em
workflow que não dispara). As distinções finas por gate estão no §5.

---

## 1. GATE ZERO — A PONTA P CONGELADA

### 1.1 A raiz e as folhas

A raiz da linhagem P é `5aa8263469d5abbf19f40e4fd0b35e20560c3944`
(`integracao/os32-fonte-unica-gates-p-v1`, 2026-08-20) — a linhagem que aboliu o
mecanismo M (`app/test/suites_obrigatorias.txt` +
`verificar_suites_obrigatorias.sh`) e pôs tudo em
`scripts/ci/gates_os_integracao.txt`.

Refs que contêm a raiz P: 11 commits distintos. Calculadas as relações de
ancestralidade entre todos, sobram **cinco folhas maximais**:

| folha | data | branch |
|---|---|---|
| `b99f41a` | 2026-08-22 12:35 | `correcao/saneamento-falsa-recompensa-treino-v1` |
| `0b6b577` | 2026-08-22 18:13 | `integracao/tema-real-vip-assets-aprovados-v1` |
| `5819baf` | 2026-08-22 20:53 | `integracao/fundacao-p-torneios-v1` |
| `5371a87` | 2026-08-23 16:17 | `correcao/os40-c1-guarda-externa-exports-v1` (só local) |
| **`828d5a0`** | **2026-08-24 11:18** | **`correcao/os42-c2-torneiobase-fail-closed-v1`** |

**A ponta P mais recente disponível é `828d5a0`**, e é ela que a OS manda
resolver. Linhagem: `5aa8263` → `21ddf47` → `5306e3f` → `f328420` → `2cc62d2` →
`828d5a0`.

### 1.2 O congelamento

```
branch    correcao/os42-c2-torneiobase-fail-closed-v1
SHA       828d5a0e5a7e57a575ecd7b906629a746b6a4cc2
data      2026-08-24 11:18:09 -0300
árvore    947 arquivos
```

| peça | caminho | blob |
|---|---|---|
| fonte única de gates | `scripts/ci/gates_os_integracao.txt` | `d1fdae9f3d1fdabef8b2206b1178894111f722e6` |
| agregador | `scripts/ci/portao_os_integracao.sh` | `7d6752bc69e9f6f2208e2c5f435bebacf15d3c02` |
| verificador de contrato | `scripts/ci/verificar_contrato_suites.sh` | `44ddb6f121632a1ff4bf6297acf150ea0e298c89` |
| matriz do agregador | `scripts/ci/teste_portao_os_integracao.sh` | `87a0f1a5b26164481ee73b122909ee50fca77ba9` |
| matriz do verificador | `scripts/ci/teste_contrato_suites.sh` | `3fe747e83f81a5b298a4c8d9c22440f64e0b3ebd` |
| workflow consumidor | `.github/workflows/ci-os-integracao.yml` | `3b70fb97ee228a87dc57769afb96cb5f53ba530d` |
| workflow paralelo (APK) | `.github/workflows/build.yml` | `c3137c7e7c371f5042d63af11357d1e1e6809dc7` |

**Fonte única canônica: uma só.** Varredura da árvore inteira: `app/test/suites_obrigatorias.txt`,
`scripts/ci/verificar_suites_obrigatorias.sh` e `app/test/ci/` **não existem**
nesta ponta. O mecanismo M não está aqui, e portanto a condição de STOP "mais de
uma fonte de gates tratada como canônica" **não se aplica a esta árvore**.

---

## 2. A ARQUITETURA, E ONDE ELA PARA

### 2.1 As quatro peças

1. **`gates_os_integracao.txt`** — a relação. Nome na margem = gate existe.
   Linha indentada = atributo do **contrato de conteúdo** do gate acima
   (`suite`, `executor`, `sha256`, `provas`, `conta`, `casos`, `contador`,
   `exige`).
2. **`portao_os_integracao.sh`** — o agregador. Lê a fonte, percorre
   `exit_<gate>` / `nao_<gate>`, e só o inteiro `0` fica verde. Modo `--listar`
   é o **leitor único** da relação; os outros consumidores o invocam em vez de
   reimplementar a leitura.
3. **`verificar_contrato_suites.sh`** — responde a terceira pergunta ("a suíte
   ainda PROVA?"). Fase A estática (antes de Flutter/Node/emulador, com falha
   própria); fase B sobre o log e o carimbo do run.
4. **`ci-os-integracao.yml`** — o único produtor de marcadores.

### 2.2 O ponto de parada, medido

```
on:
  push:
    branches:
      - integracao/os-final-backend-flutter
      - correcao/ci-composicao-perfil-mesa-ranking-v2-v1
  workflow_dispatch:
```

* A branch auditada é `correcao/os42-c2-torneiobase-fail-closed-v1`. **Não casa
  com nenhuma das duas.** O gatilho `push` nunca dispara aqui.
* `workflow_dispatch` **não está disponível**: o GitHub lê esse gatilho da
  versão do arquivo na branch **default**, e `origin/main` (`fb9edb5`) contém
  **um único workflow, `build.yml`** — conferido por `git ls-tree`.
  `ci-os-integracao.yml` nunca chegou a `main`.

**Consequência:** os 65 gates são, nesta ponta, o item 6 do §1 da OS — *gate
chamado apenas em workflow que não dispara*. Não é um problema de um gate; é o
teto de todos eles.

### 2.3 O único workflow alcançável não é um portão de gates

`build.yml` existe na branch default e portanto **é** dispachável sobre qualquer
ref. Ele carrega **13 passos chamados "PORTÃO"** — e nenhum deles participa da
fonte única: não escreve `exit_<gate>`, não tem nome de gate, não tem contrato,
não é percorrido pelo agregador. Medido: `grep -oE 'exit_[A-Za-z0-9_]+' build.yml`
devolve **zero ocorrências**.

O que esses 13 passos exercitam, por coincidência de caminho:

* **18 suítes que também são gate** — `motor`, `resil`, `torneios`, `colarte`,
  `colfire`, `colkit`, `analyze` e as **onze** de `app/test/casca` (que o passo
  roda por diretório: `casca`, `cascaaud`, `cascavisao`, `cascamesaaud`,
  `cascav2`, `cascaligacao`, `cascamesa`, `cascaporta`, `cascaloja`,
  `avatarcanon`, `avatarhml`);
* **6 suítes que não são gate nenhum** — `test/online_auth_test.dart`,
  `test/conexao_producao_test.dart` e as quatro de `test/sessao/`
  (`auditoria_identidade`, `identidade_sessao`, `telas_consomem_identidade`,
  `uniao_sessao_transporte`). Elas são obrigatórias **só** neste workflow e
  **não constam da fonte única**.

**E ele não pode ser usado como bancada de gate.** O passo final é
`gh release delete latest --cleanup-tag` seguido de `gh release create latest`:
dispará-lo **substitui o APK público "latest"** por um build desta branch. Rodar
`build.yml` para "ver os gates passarem" é publicar.


### 2.3b Os outros três workflows, e por que nenhum salva

| workflow | gatilho | está em `main`? | dispara nesta ponta? | "PORTÕES" próprios |
|---|---|---|---|---|
| `ci-os-integracao.yml` | push em 2 branches + dispatch | **não** | **não** | é o dono dos 65 gates |
| `build.yml` | push `main`/`master`/`codex/inicio-ui` + dispatch | **sim** | só por dispatch — **e publica release** | 13 |
| `release-aab.yml` | só `workflow_dispatch` | **não** | **não** | 9 (inclui `flutter test test/billing/`, sem gate na fonte) |
| `tamanho-aab.yml` | push `claude/**`, `feat/**` + dispatch | **não** | **não** (branch é `correcao/**`) | 3 |
| `web.yml` | só `workflow_dispatch` | **não** | **não** | 0 |

São **25 passos "PORTÃO" espalhados por três workflows**, todos fora da fonte
única, sem marcador, sem contrato e sem agregador. Somados aos 65 gates da
fonte, o repositório tem hoje **duas noções de "portão" que não se conhecem** —
e a única alcançável nesta ponta é a que **não** é a fonte única.

### 2.4 A última execução real

Branch `origin/ci-evidencias`, arquivo `run-17.md`:

```
branch: correcao/ci-composicao-perfil-mesa-ranking-v2-v1
commit: e0cf91791913e1345c9181e1fb2f0a0871d30fe2
data:   2026-08-18T00:17:00Z
obrigatórios: 36 | verdes: 36 | fora da fonte: 0
resultado: VERDE
```

`e0cf917` **é ancestral** de `828d5a0`. Entre os dois: **373 commits, 634
arquivos alterados**. Comparando a relação de 36 gates do run-17 com a de 65 de
hoje:

* **35 gates em comum** — executados de verdade uma vez, em 18/08, seis dias e
  373 commits atrás;
* **30 gates novos, nunca executados em run real nenhum**: `a11yamigos`,
  `admvip`, `audsocial`, `avatarcanon`, `avatarhml`, `cascaloja`, `chatdom`,
  `chatemu`, `colecoesemu`, `compavrank`, `compnavpub`, `composloja`,
  `composneg`, `comunicacao`, `contaemu`, `contafn`, `contratosui`,
  `economiafn`, `mesasfn`, `moderacaoemu`, `moderacaofn`, `passeint`,
  `perfilvis`, `proveni`, `rknavpub`, `rkpagina`, `socialestado`,
  `socialleitor`, `socialtela`, `torneiobase`;
* **1 gate do run-17 que sumiu da fonte**: `regras` — e sumiu **corretamente**.
  Foi renomeado para `colecoesemu` na OS do fail-closed, e a fonte carrega a
  lápide explicando. É o único `SUPERSEDED` do censo, e ele **já foi removido**:
  não sobrou nome sem produtor nem produtor sem nome.

---

## 3. O CENSO

65 gates declarados na margem da fonte única. Para cada um: o passo do
`ci-os-integracao.yml` que o produz, o alvo material (conferido no disco), se
tem contrato de conteúdo, e se ele existia na última execução real.

Colunas `digest`/`provas`/`casos`/`blocos` só existem para gate com contrato.
"blocos" = quantidade de linhas `exige` (blocos normativos).

| gate | passo produtor (ci-os-integracao.yml) | alvo material | contrato | digest | provas | casos | blocos | rodou no run-17 |
|---|---|---|---|---|---|---|---|---|
| `a11yamigos` | 1+2 | `app/test/amigos/a11y_alvos_amigos_test.dart` | sim | `4b614ae0ae0b` | 30 | 75 | 3 | NAO |
| `admvip` | 1+2 | `app/test/torneios/admissao_vip_torneios_test.dart` | sim | `4b78d50d2b0c` | 48 | 48 | 14 | NAO |
| `analyze` | 1+2 | `app_build :: flutter analyze --no-fatal-infos --no-fatal-warnings` | nao | — | — | — | — | sim |
| `auditident` | 3f3 | `functions-social :: node --test test/auditoria.identidade.emulador.test.js (emulador)` | nao | — | — | — | — | sim |
| `audsocial` | 1+2 | `app/test/amigos/auditoria_descoberta_social_test.dart` | sim | `28b9cf5e87d2` | 23 | 23 | 4 | NAO |
| `avatarcanon` | 1+2 | `app/test/casca/avatar_publico_canonico_test.dart` | sim | `cea6eb4e8b0d` | 38 | 38 | 4 | NAO |
| `avatarhml` | 1+2 | `app/test/casca/homologacao_avatar_publico_test.dart` | sim | `54ed51b7bcbd` | 42 | 42 | 4 | NAO |
| `billing` | 3a | `functions-billing :: npm ci + npm test` | nao | — | — | — | — | sim |
| `casca` | 1+2 | `app/test/casca/casca_producao_test.dart` | nao | — | — | — | — | sim |
| `cascaaud` | 1+2 | `app/test/casca/auditoria_casca_test.dart` | nao | — | — | — | — | sim |
| `cascaligacao` | 1+2 | `app/test/casca/ligacao_mesa_caracterizacao_test.dart` | nao | — | — | — | — | sim |
| `cascaloja` | 1+2 | `app/test/casca/loja_de_producao_test.dart` | nao | — | — | — | — | NAO |
| `cascamesa` | 1+2 | `app/test/casca/mesa_online_test.dart` | nao | — | — | — | — | sim |
| `cascamesaaud` | 1+2 | `app/test/casca/auditoria_mesa_online_test.dart` | nao | — | — | — | — | sim |
| `cascaporta` | 1+2 | `app/test/casca/porta_de_comandos_online_test.dart` | nao | — | — | — | — | sim |
| `cascav2` | 1+2 | `app/test/casca/homologacao_casca_v2_test.dart` | nao | — | — | — | — | sim |
| `cascavisao` | 1+2 | `app/test/casca/adaptador_visao_online_test.dart` | nao | — | — | — | — | sim |
| `chatdom` | 1+2 | `app/test/chat/chat_test.dart` | sim | `d0aac4775d20` | 60 | — | 6 | NAO |
| `chatemu` | 3i | `functions-moderacao :: node --test test/integracao.chat.emulador.test.js (emulador)` | nao | — | — | — | — | NAO |
| `colarte` | 1+2 | `app/test/colecoes/colecao_arte_test.dart` | nao | — | — | — | — | sim |
| `colecoesemu` | 3g | `firebase/testes :: npm run test:integrado (emulador)` | nao | — | — | — | — | NAO |
| `colfire` | 1+2 | `app/test/colecoes/colecao_firebase_test.dart` | nao | — | — | — | — | sim |
| `colkit` | 1+2 | `app/test/colecoes/kit_pioneiros_test.dart` | nao | — | — | — | — | sim |
| `compavrank` | 1+2 | `app/test/composicao/composicao_avatar_ranking_test.dart` | sim | `3f081613dfa6` | 21 | 21 | 3 | NAO |
| `compnavpub` | 1+2 | `app/test/composicao/composicao_navegacao_publica_test.dart` | sim | `c6b31bebd7b8` | 22 | 22 | 3 | NAO |
| `composicao` | 1+2 | `app/test/composicao/composicao_perfil_ranking_test.dart` | nao | — | — | — | — | sim |
| `composloja` | 4c | `node --test ferramentas/composicao/loja_functions.test.js` | nao | — | — | — | — | NAO |
| `composneg` | 4b | `node --test ferramentas/composicao/negativas.test.js` | nao | — | — | — | — | NAO |
| `comunicacao` | 1+2 | `app/test/comunicacao/comunicacao_test.dart` | sim | `94af3e9b5bbe` | 71 | 81 | 10 | NAO |
| `contaemu` | 3j2 | `functions-conta :: npm run test:emulador (emulador)` | nao | — | — | — | — | NAO |
| `contafn` | 3j | `functions-conta :: npm test` | nao | — | — | — | — | NAO |
| `contratosui` | 0b | `scripts/ci/teste_contrato_suites.sh` | sim | `ce872aaddc7e` | 65 | 74 | 11 | NAO |
| `economiafn` | 3l | `functions-economia :: npm test` | nao | — | — | — | — | NAO |
| `encerr` | 1+2 | `app/test/teste_encerramento.dart` | nao | — | — | — | — | sim |
| `identint` | 3f2 | `functions-social :: node --test test/integracao.identidade.emulador.test.js (emulador)` | nao | — | — | — | — | sim |
| `integr` | 1+2 | `app/test/integracao/teste_integracao_motores.dart` | nao | — | — | — | — | sim |
| `mesasfn` | 3k | `functions-mesas :: npm test` | nao | — | — | — | — | NAO |
| `moderacaoemu` | 3h | `firebase/testes :: npm run emulador:moderacao (emulador)` | nao | — | — | — | — | NAO |
| `moderacaofn` | 3h | `functions-moderacao :: npm run build:domain + npm test` | nao | — | — | — | — | NAO |
| `motor` | 1+2 | `app/test/teste_motor.dart` | nao | — | — | — | — | sim |
| `mtorneios` | 1+2 | `app/test/torneios/motor_torneios_test.dart` | nao | — | — | — | — | sim |
| `passeint` | 3f3 | `functions-ranking :: node --test test/integracao.passe.emulador.test.js (emulador)` | nao | — | — | — | — | NAO |
| `perfilvis` | 1+2 | `app/test/perfil/identidade_visitada_test.dart` | sim | `1a2a810782eb` | 25 | 25 | 4 | NAO |
| `portaoci` | 0 | `scripts/ci/teste_portao_os_integracao.sh` | sim | `0ae02bb66558` | 49 | 38 | 6 | sim |
| `proveni` | 4a | `node --test ferramentas/proveniencia/proveniencia.test.js` | nao | — | — | — | — | NAO |
| `rankingfn` | 3e | `functions-ranking :: npm ci + npm test (tsc && node --test)` | nao | — | — | — | — | sim |
| `rankingint` | 3f | `functions-ranking :: node --test test/integracao.emulador.test.js (emulador)` | nao | — | — | — | — | sim |
| `resil` | 1+2 | `app/test/teste_motor_resiliencia.dart` | nao | — | — | — | — | sim |
| `rkbarreira` | 1+2 | `app/test/ranking/barreira_temporal_ranking_test.dart` | nao | — | — | — | — | sim |
| `rkestado` | 1+2 | `app/test/ranking/estado_canonico_ranking_test.dart` | nao | — | — | — | — | sim |
| `rkleitor` | 1+2 | `app/test/ranking/leitor_ranking_real_test.dart` | nao | — | — | — | — | sim |
| `rknavpub` | 1+2 | `app/test/ranking/navegacao_perfil_publico_test.dart` | sim | `ef7ce42dfd13` | 38 | 38 | 4 | NAO |
| `rkpagina` | 1+2 | `app/test/ranking_page_test.dart` | nao | — | — | — | — | NAO |
| `rkperfil` | 1+2 | `app/test/ranking/homologacao_perfil_publicavel_test.dart` | nao | — | — | — | — | sim |
| `rkregressao` | 1+2 | `app/test/ranking/regressao_leitor_ranking_test.dart` | nao | — | — | — | — | sim |
| `social` | 1+2 | `app/test/social/teste_social.dart` | nao | — | — | — | — | sim |
| `socialdom` | 3c | `functions-social :: npm run build:domain` | nao | — | — | — | — | sim |
| `socialemu` | 3d | `firebase/testes :: npm run test:social:functions (emulador)` | nao | — | — | — | — | sim |
| `socialestado` | 1+2 | `app/test/amigos/estado_social_test.dart` | sim | `b1ad02a84508` | 28 | 28 | 3 | NAO |
| `socialfn` | 3c | `functions-social :: npm test` | nao | — | — | — | — | sim |
| `socialleitor` | 1+2 | `app/test/amigos/leitor_social_test.dart` | sim | `e877b6b576b1` | 29 | 29 | 3 | NAO |
| `socialtela` | 1+2 | `app/test/amigos/descoberta_social_tela_test.dart` | sim | `0730b190d89a` | 18 | 18 | 2 | NAO |
| `torneiobase` | 1+2 | `app/test/torneios/fundacao_base_p_test.dart` | sim | `6351d5270f6e` | 56 | 56 | 14 | NAO |
| `torneios` | 1+2 | `app/test/torneios/reward_grants_test.dart` | nao | — | — | — | — | sim |
| `torneiosfn` | 3b | `functions :: npx tsc --noEmit` | nao | — | — | — | — | sim |

**Bijeção, medida:** `comm` entre os 65 nomes na margem e os 65 produtores
extraídos do YAML (`roda <gate>`, `exit_<gate>`, `nao_<gate>`) devolve **conjunto
vazio nos dois sentidos**. Nenhum gate declarado sem produtor; nenhum produtor
sem gate declarado.

**Materialidade, medida:** os **41** alvos `roda` existem em `app/test/` (41 de 41, conferidos um a um no disco). Existem também todos os alvos dos gates de codebase e ferramenta: os oito `package.json` de Functions, `firebase/testes/package.json`, `firebase.json`, os três `.test.js` de `ferramentas/` e os dois `.sh` de `scripts/ci/`. **Zero alvos ausentes** — nenhum gate desta ponta seria `nao_<gate>` por ausência de artefato.

**Marcador:** `exit_<gate>` para todos; `nao_<gate>` declarado explicitamente em
19 passos (os de codebase, que checam o caminho antes) e implícito no auxiliar
`roda` para os 41 de Flutter. `analyze`, `composloja`, `composneg`, `proveni` e
`socialdom` não escrevem `nao_`: se o passo não roda, não há `exit_`, e o
agregador reprova por ausência — que é a mesma porta fechada.

**Sabotagem mínima (idêntica para os 65, executada para os 65):** remover `exit_<gate>` do diretório de resultados, com os outros 64 verdes. O agregador tem de sair VERMELHO. Rodada junto com outras quatro variantes no §4.1.

**Condição de disparo (idêntica para os 65):** `push` em
`integracao/os-final-backend-flutter` ou
`correcao/ci-composicao-perfil-mesa-ranking-v2-v1`, ou `workflow_dispatch`
(indisponível). **Nenhuma das três ocorre nesta ponta.**

---

## 4. AS PROVAS EXECUTADAS

Busca textual não basta, e a OS diz isso. Tudo abaixo foi **rodado**, em cópia
da árvore de `828d5a0` extraída com `git archive` (fonte única conferida byte a
byte: `sha256 = 0f6099db311ba04c565306e8cf20dcd873392d86ff39690a88d7a8628a0edbfa`,
idêntica ao blob).

### 4.1 Participação real no veredito — 325 sabotagens, uma matriz por gate

Para **cada um dos 65 gates**, cinco sabotagens mínimas contra o agregador, com
os outros 64 verdes:

| # | sabotagem | esperado |
|---|---|---|
| S1 | `exit_<gate>` = `1` | VERMELHO |
| S2 | `exit_<gate>` removido | VERMELHO (ausência de resultado) |
| S3 | `nao_<gate>` no lugar do exit | VERMELHO (NÃO EXECUTADO) |
| S4 | `nao_<gate>` **ao lado** de `exit_<gate>`=0 | VERMELHO (marcador vence) |
| S5 | `exit_<gate>` vazio | VERMELHO (ilegível) |

```
BASELINE 65 verdes -> exit 0
gates com as 5 sabotagens DETECTADAS: 65 | com escape: 0 | total 65
CONTROLE final -> exit 0
```

**Zero escapes em 325 execuções.** O item 5 do §1 da OS — "`NÃO EXECUTADO`
tratado como verde" — **não tem um único gate** nesta ponta.

### 4.2 As duas matrizes do próprio CI

* **`portaoci`** (`teste_portao_os_integracao.sh`) — executado inteiro:
  **38/38 casos ok, `TESTE DO PORTÃO: VERDE`, exit 0.** Bate com o contrato
  (`provas 49`, `casos 38`).
* **`contratosui`** (`teste_contrato_suites.sh`) — executado inteiro:
  **73/74 casos ok, 1 falha, `TESTE DO CONTRATO: VERMELHO`, exit 1.** A única
  falha é **T27**, o controle da FASE B; os dois outros controles da matriz
  (`T01` árvore íntegra e `T34` árvore restaurada) passam, o que isola a falha
  no conteúdo da fixture e não no arnês. Detalhe no §4.6b.

### 4.3 Contrato de conteúdo — controle e sabotagem

**Controle**, árvore íntegra:

```
contrato de suites: 17 conferido(s), tudo no lugar     (exit 0)
```

Os 17 contratos conferem **arquivo, executor, marcador, piso, assinatura,
provas e blocos** — inclusive os pisos externos de `torneiobase` (`exige 14 >= 14`)
e de `admvip`, e a própria invocação do verificador dentro do YAML.

**Sabotagem de trivialização** (`expect(1, 1)` no lugar do corpo da suíte):

| gate | tem contrato? | verificador |
|---|---|---|
| `motor` (`app/test/teste_motor.dart`) | **não** | **exit 0 — "17 conferido(s), tudo no lugar"** |
| `chatdom` (`app/test/chat/chat_test.dart`) | sim | exit 1 — digest divergente, `0 declaracoes e o piso e 60`, 6 blocos sumidos |

É a diferença exata entre os 17 gates com contrato e os **48 sem**: esvaziar a
suíte de qualquer um dos 48 atravessa o CI inteiro em silêncio.

### 4.4 A régua externa cobre 6 dos 17 contratos

Segunda sabotagem: apagar **o bloco de contrato inteiro** do gate na fonte única
(o gate continua declarado, a suíte continua no disco, o produtor continua no
YAML — só o contrato some).

| gate com contrato | na régua externa? | verificador ao perder o contrato |
|---|---|---|
| `chatdom` | sim | exit 1 — REPROVADO |
| `comunicacao` | sim | exit 1 — REPROVADO |
| `portaoci` | sim | exit 1 — REPROVADO |
| `contratosui` | sim | exit 1 — REPROVADO |
| `admvip` | sim | exit 1 — REPROVADO |
| `torneiobase` | sim | exit 1 — REPROVADO |
| `avatarcanon` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `avatarhml` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `perfilvis` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `rknavpub` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `compavrank` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `compnavpub` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `socialestado` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `socialleitor` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `socialtela` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `audsocial` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `a11yamigos` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |

`CONTRATOS_MINIMOS`, `PISOS_PROVAS`, `PISOS_CASOS` e `PISOS_EXIGE` vivem **dentro
do `verificar_contrato_suites.sh`** e nomeiam exatamente seis gates:
`comunicacao chatdom portaoci contratosui admvip torneiobase`. Para esses seis,
o contrato não pode encolher. Para os **outros onze**, apagar o contrato é
**silencioso**: o verificador conta 16 em vez de 17 e diz "tudo no lugar".

### 4.4b Um gate inteiro pode sumir calado — 59 dos 65

Terceira sabotagem, a mais dura: apagar **a entrada inteira** da fonte única
(nome + contrato), **o produtor** do workflow (`roda <gate>`) e **a suíte do
disco**, tudo junto. É o escape que a OS 42-C1 mediu e deixou de reserva e que a
OS 42-C2 fechou — mas fechou **só para os seis nomes da régua externa**: os
quatro que já estavam lá e os dois (`torneiobase`, `admvip`) que ela
acrescentou.

| gate | na régua externa? | fonte + workflow + suíte apagados juntos |
|---|---|---|
| `torneiobase` | sim | exit 1 — REPROVADO |
| `avatarcanon` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |
| `a11yamigos` | **não** | **exit 0 — "16 conferido(s), tudo no lugar"** |

E o agregador, medido separadamente, confirma o outro lado:

```
fonte com a entrada de avatarcanon removida, sem o resultado dela
obrigatórios: 64 | verdes: 64 | fora da fonte: 0
resultado: VERDE          (exit 0)
```

`composneg` (PN-10/PN-12) e `composloja` cobram a **bijeção**, e a bijeção
continua fechando: sumiram os dois lados ao mesmo tempo. Não há, em lugar
nenhum da árvore, **piso de quantidade de gates** — nem no verificador (que só
reprova quando os contratos somem TODOS), nem nas provas negativas.

**Portanto: 59 dos 65 gates podem ser removidos do repositório em silêncio, com
o portão saindo VERDE.** Os seis que não podem são exatamente os nomeados em
`CONTRATOS_MINIMOS`.

*Base do número:* a sabotagem foi executada em três gates — um da régua
(`torneiobase`, reprova) e dois de fora (`avatarcanon` e `a11yamigos`, passam) —
e o `59` sai daí mais o código: a única cobrança de existência é o laço
`for k in $CONTRATOS_MINIMOS` do verificador, que percorre seis nomes e mais
nenhum. Não há segundo laço, e não há piso de quantidade.

### 4.5 Resultado atual, onde a bancada alcança

| gate | execução | resultado |
|---|---|---|
| `portaoci` | `bash teste_portao_os_integracao.sh` | **VERDE** — 38/38 |
| `proveni` | `node --test ferramentas/proveniencia/proveniencia.test.js` | **VERDE** — 13/13 |
| `composneg` | `node --test ferramentas/composicao/negativas.test.js` | **VERDE** — 21/21 |
| `composloja` | `node --test ferramentas/composicao/loja_functions.test.js` | **VERDE** — 35/35 |
| `rankingfn` | `npm ci && npm test` em `functions-ranking` | **VERMELHO** — 461/462 |
| `contratosui` | `bash teste_contrato_suites.sh` | **VERMELHO** — 73/74, falha em T27 |

`composloja` só mede em árvore com git: na cópia sem `.git` ele reprova por
`ANCORA PERDIDA`, e reprova **de propósito** (histórico raso não prova
ancestralidade). Rodado num worktree destacado de `828d5a0`, com histórico
completo: **35/35**.

### 4.6 `rankingfn` está vermelho, e o vermelho não é de ranking

```
✖ PF-01: NENHUMA Cloud Function produtiva nova é exportada
  functions-moderacao/src/index.ts mudou de superfície de deploy
  actual: 11, expected: 9
  ℹ tests 462 | pass 461 | fail 1
```

O contrato PF-01 (em `functions-ranking/test/passe.test.js:687`) congela a
superfície de deploy de **quatro** codebases. A contagem de
`functions-moderacao` está fixada em **9**, e a árvore tem **11**: entraram
`emitirEventoDeSistema` e `consultarCatalogoDeComunicacao`, que são a superfície
da **Comunicação Controlada V1** (OS 24-C2, `d1eb537`).

Ou seja: **uma entrega legítima subiu e deixou um gate obrigatório vermelho**, e
seis dias depois o vermelho continua lá — porque o portão não roda. É o custo
concreto da §2.2, e não uma hipótese.

O conserto existe e **está fora desta linhagem**: `fda24a2`
(`correcao/rankingfn-pf01-contrato-exports-v1`) e `5371a87`
(`correcao/os40-c1-guarda-externa-exports-v1`) **não são ancestrais de
`828d5a0`**.

### 4.6b `contratosui` também está vermelho, e a OS 42-C2 piorou o caso

O gate que guarda o verificador de conteúdo reprova na própria ponta — **73/74,
exit 1** — e a única falha é **T27, o CONTROLE da FASE B**, o único caso daquela
fase que espera `exit 0`:

```
FALHA T27 CONTROLE — evidencia completa e datada => VERDE — esperado exit 0, obtido 1
  CONTRATO DE SUITE: 'contratosui' executou 34 caso(s) e o piso e 74 — a suite encolheu
  CONTRATO DE SUITE: o gate 'avatarcanon' nao deixou log — marcador sem execucao
  ... e mais doze: avatarhml, perfilvis, rknavpub, compavrank, compnavpub,
      socialestado, socialleitor, socialtela, audsocial, a11yamigos,
      torneiobase, admvip
```

**A causa é uma fixture escrita à mão.** A FASE B exige um `t_<gate>.log` para
**todo** gate contratado. A evidência sintética da bancada — a função
`resultados()` dentro de `teste_contrato_suites.sh` — escreve exatamente
**quatro** logs: `comunicacao`, `chatdom`, `portaoci` e `contratosui`. Todo
contrato acrescentado à fonte única desde então é mais um log faltando.

**E a OS 42-C2 acrescentou um segundo motivo de falha ao mesmo caso.** Ela subiu
o piso de casos de `contratosui` de 34 para **74** — corretamente, porque a
campanha cresceu —, mas o log sintético que a fixture escreve **para si mesma**
continua anunciando 34. Agora T27 falha por **duas** razões independentes: treze
logs ausentes *e* o piso de casos do próprio `contratosui`.

Não é regressão desta ponta: o defeito já valia em `21ddf47`, então com onze
logs faltando. O que esta auditoria acrescenta é que ele **cresce sozinho** a
cada contrato novo, e que agora atingiu a linha que mede o próprio gate.


### 4.7 Uma guarda fail-open, achada de passagem

`app/test/casca/auditoria_casca_test.dart` (gate `cascaaud`) é o único ponto
Dart que cobra a fonte única — e cobra **só `perfilvis`**. Ele abre com:

```dart
if (!workflow.existsSync()) return;      // ...
if (!fonte.existsSync()) return;
```

Apagar o workflow, ou apagar a fonte única, faz o caso **passar por vazio**.
A guarda não sobrevive à própria remoção do que ela guarda — o padrão que a
árvore já conhece. O agregador ainda reprovaria (ele sai com exit 2 sem fonte),
então o dano é limitado; mas a guarda Dart, sozinha, é decorativa.

*Este é o único achado do laudo que vem de **leitura de código, não de
execução**:* `cascaaud` é uma suíte Flutter e está entre os gates em `N/M`. Os
dois `return` estão nas linhas 539 e 548 do arquivo.

---

## 5. CLASSIFICAÇÃO

### 5.1 Pelos oito recortes do §1 da OS

| # | recorte | quantos | quais |
|---|---|---|---|
| 1 | gate declarado **e executado** | **0 nesta ponta** (35 já executaram em `e0cf917`, 18/08) | ver §2.4 |
| 2 | gate declarado, **mas não alcançado** | **65** | todos — o workflow não dispara nesta branch e não é dispachável |
| 3 | gate executado **sem contrato** | **48** | os 65 menos os 17 com bloco de contrato |
| 4 | passo existente, **fora do agregador** | **1 + 25 + 6** | `colevid` (por decisão registrada no cabeçalho do próprio teste); os **25** passos "PORTÃO" espalhados por `build.yml` (13), `release-aab.yml` (9) e `tamanho-aab.yml` (3); e as 6 suítes que só existem no `build.yml` |
| 5 | `NÃO EXECUTADO` tratado como verde | **0** | impossível — provado gate a gate em 325 sabotagens |
| 6 | gate chamado só em workflow que não dispara | **65** | todos |
| 7 | contrato cuja suíte pode ser trivializada | **48 sem contrato · 11 com contrato removível · 59 removíveis por inteiro** | 48 gates sem contrato nenhum (a suíte vira `expect(1, 1)`); 11 dos 17 contratos podem ser apagados da fonte em silêncio; e 59 gates podem ser apagados por inteiro — fonte, produtor e suíte — com o portão VERDE |
| 8 | gate órfão ou superseded | **0 órfãos, 1 superseded já removido** | `regras` → `colecoesemu`, com lápide na fonte |

### 5.2 Pelos cinco vereditos do §4 da OS

**`FAIL — declaração não produz execução real`: os 65 gates.** Motivo único e
comum, não específico de gate nenhum: o produtor de todos eles é o
`ci-os-integracao.yml`, que não dispara nesta ponta e não é dispachável.
Nenhum gate desta ponta pode receber `PASS — declarado, executado e agregado`,
porque a segunda palavra não é verdadeira para nenhum.

Dentro do FAIL, a gravidade **não** é uniforme. Três subclasses:

* **FAIL-A — só falta o gatilho** (`35` gates): mecanismo completo, alvo no
  disco, participação no agregador provada, e já executaram de verdade uma vez.
  Estes voltam a valer no minuto em que o workflow rodar.
* **FAIL-B — nunca executaram** (`30` gates): tudo o que se sabe deles é
  estático. Quatro puderam ser rodados por fora nesta auditoria — `proveni`,
  `composneg` e `composloja` **verdes**, e `contratosui` **vermelho**. Para os
  outros 26, o verde é presunção.
* **FAIL-C — vermelho conhecido e invisível** (`2` gates, e são recorte dos dois
  de cima, não uma quarta caixa): `rankingfn` (461/462), que é FAIL-A — já
  rodou verde em 18/08 e ficou vermelho depois; e `contratosui` (caso T27), que é FAIL-B — nasceu vermelho e nunca rodou em CI nenhum.

**`BLOCKED — infraestrutura externa ausente`: 0 gates**, no sentido da OS. O que
é bloqueado é a *medição do resultado atual* de parte deles na bancada, não a
declaração nem a agregação — e isso está em `N/M`, abaixo.

**`SUPERSEDED`: 1 nome**, `regras`, e ele **já saiu**. Não há OS de remoção a
abrir: a fonte carrega a lápide, `colecoesemu` tem produtor e contrato de
marcador, e a bijeção fecha nos dois sentidos.

**`N/M — não mensurável na bancada`: 59 gates**, para a coluna *resultado atual*
(a declaração e a agregação foram medidas para os 65). Motivos objetivos:

| grupo | quantos | motivo |
|---|---|---|
| suítes Flutter + `analyze` | 42 | exigem `flutter create` + overlay + `pub get`; nesta máquina **um `flutter test` por vez** e a suíte lê `../scripts/...`, o que obriga espelhar a raiz. Custo de horas, sem relação com o objeto desta OS |
| gates de emulador | 9 | `socialemu`, `moderacaoemu`, `colecoesemu`, `chatemu`, `contaemu`, `rankingint`, `identint`, `auditident`, `passeint` — exigem Java 21 + `firebase-tools` + Emulator Suite em portas fixas, **sequenciais entre si** |
| codebases Node | 8 | `billing`, `torneiosfn`, `socialdom`, `socialfn`, `moderacaofn`, `contafn`, `mesasfn`, `economiafn` — exigem `npm ci` com rede, e três deles exigem `dart compile js` antes do `tsc`, o que reencosta no Flutter |

Medidos, portanto: **6 de 65** — `portaoci`, `contratosui`, `proveni`, `composneg`, `composloja` e `rankingfn`.

---

## 6. OS NÚMEROS QUE A OS PEDE

| pergunta | resposta | como foi medido |
|---|---|---|
| **quantidade declarada** | **65** | nomes na margem de `gates_os_integracao.txt`, lidos por `portao_os_integracao.sh --listar` (o leitor único) |
| **quantidade realmente executada** | **0 nesta ponta** | nenhum gatilho do `ci-os-integracao.yml` casa com esta branch, e `workflow_dispatch` está indisponível |
| — já executada alguma vez | **35** | `run-17.md` de `origin/ci-evidencias`, `e0cf917`, 2026-08-18 |
| — nunca executada | **30** | diferença entre a relação de hoje e a do run-17 |
| **quantidade agregada** | **65** | 325 sabotagens mínimas, 5 por gate, 0 escapes |
| **quantidade órfã** | **0** | bijeção gate ↔ produtor fecha nos dois sentidos |
| — passo fora do agregador | **1 + 25 + 6** | `colevid` por decisão; 25 "PORTÃO" em três workflows; 6 suítes só do `build.yml` |
| **gates falsamente verdes** | **0 por omissão · 2 vermelhos invisíveis · 48 trivializáveis · 59 removíveis em silêncio** | ver abaixo |
| **superseded** | **1, já removido** | `regras` |

### O que "falsamente verde" quer dizer aqui, em três leituras

1. **Verde por omissão no agregador: zero.** Ausência de resultado, marcador,
   exit vazio, exit não numérico e marcador ao lado de exit 0 reprovam nos 65.
   Medido.
2. **Verde presumido que é vermelho: dois.** `rankingfn` (461/462, §4.6) e
   `contratosui` (T27, §4.6b). Ninguém vê porque nada roda.
3. **Verde que pode ser esvaziado — ou sumir — em silêncio.** Três degraus,
   todos medidos: **48** gates cuja suíte pode virar `expect(1, 1)` sem que
   nada reclame; **11** dos 17 contratos, que podem ser apagados da fonte sem
   que o verificador conte falta; e **59** gates que podem ser removidos por
   inteiro — entrada, produtor e suíte — com o agregador saindo VERDE. Os seis
   que resistem aos três são os nomeados na régua externa.

---

## 7. MAPA DE DEPENDÊNCIAS

```
                       origin/main (fb9edb5)
                              │  contém SÓ build.yml
                              ▼
        workflow_dispatch de ci-os-integracao.yml  ──►  INDISPONÍVEL (422)
                              │
   push em 2 branches que não são esta  ──────────►  NÃO DISPARA
                              │
                              ▼
                 ci-os-integracao.yml  (único produtor de exit_/nao_)
                              │
   ┌──────────────────────────┼───────────────────────────────┐
   │                          │                               │
 passo 0                   passo 0b                        passo 0c
 portaoci                  contratosui              verificar_contrato (FASE A)
   │                          │                     falha aborta o JOB (bash -e)
   └──────────┬───────────────┘                               │
              ▼                                               ▼
      carimbo_execucao ─────────────────────────────► FASE B (log + casos)
              │
              ▼
   passos 1+2 (41 suítes Flutter + analyze)
   passos 3a..3l (codebases Node e emulador)   ── dependências internas:
        3c socialdom/socialfn ─► 3d socialemu, 3f2 identint
        3e rankingfn ─────────► 3f rankingint, 3f3 passeint, 3f3 auditident
        3h moderacaofn ───────► 3i chatemu, 3h moderacaoemu
        3j contafn ───────────► 3j2 contaemu
   passos 4a/4b/4c (proveni, composneg, composloja)
        composloja exige checkout com fetch-depth: 0
              │
              ▼
   passo "Publicar evidência"  ──►  branch ci-evidencias  (último: run-17)
              │
              ▼
   passo "Portão verde/vermelho"  (if: always())
        verificar_contrato_suites.sh . <yml> .      ◄── FASE A+B
        portao_os_integracao.sh <fonte> .          ◄── veredito dos 65
```

**Leitores da fonte única** (todos passam pelo mesmo `--listar`, e é isso que
impede o CI-02 de voltar): o agregador, o verificador de contrato, o passo de
evidência, `ferramentas/composicao/arvore.js` (usado por `composneg` PN-10 /
PN-12 / PN-16 e por `composloja`) e — parcialmente e fail-open — o
`auditoria_casca_test.dart` do gate `cascaaud`.

**Consequência para quem for consertar:** tirar um gate da fonte não silencia só
o agregador; derruba também `composneg` e `composloja`, que cobram a bijeção nos
dois sentidos. Tirar o gate **e** o produtor **e** a suíte de uma vez é o que
passa calado — e só não passa para os seis gates da régua externa.

---

## 8. STOP — O QUE ESTA AUDITORIA NÃO FEZ

O §5 da OS manda parar sem escolher arquitetura em cinco situações. Duas se
aplicam, e as duas foram respeitadas:

| condição | aplica? | como foi tratada |
|---|---|---|
| mais de uma fonte de gates tratada como canônica | **não** nesta árvore | o mecanismo M não existe em `828d5a0`; a fonte é uma só. **Mas veja o §9.1**: a linhagem P tem folhas concorrentes que reescrevem a fonte, e essa arbitragem continua aberta |
| Gate Zero não resolve a ponta P | **não** | resolvida: `828d5a0`, a mais recente das cinco folhas maximais |
| **o workflow aplicável não está disponível** | **SIM** | é o achado central. A auditoria **relatou** e **não tentou** acrescentar branch ao `on: push`, nem levar o workflow a `main`, nem dispachar `build.yml` |
| execução depende de secrets/infra externa inacessível | **SIM, em parte** | 59 dos 65 gates ficaram em `N/M` com motivo objetivo, em vez de receberem verde presumido |
| o relatório tentar corrigir o problema durante a auditoria | — | **nada foi corrigido**. Nenhum arquivo produtivo tocado; toda sabotagem rodou em cópia e foi revertida com conferência de digest |

**Esta auditoria não autoriza implementar o saneamento encontrado.**

---

## 9. OS MÍNIMAS RECOMENDADAS, POR AUTORIDADE

Em ordem de dependência. Nenhuma delas é autorizada por esta OS.

### 9.1 — Arbitragem das folhas maximais de P *(pré-requisito de todas)*

Cinco folhas maximais, nenhuma contendo outra, e pelo menos duas delas
reescrevem `gates_os_integracao.txt` e o digest de `contratosui`. Enquanto isso
não for arbitrado, **qualquer OS que escreva na fonte única escolhe uma
vencedora por via oblíqua**. Autoridade: quem decide linhagem.

### 9.2 — Alcançabilidade do portão *(o achado central)*

O objetivo é uma coisa só: que `828d5a0` (ou a ponta que a 9.1 eleger) produza
um `run-N.md` novo em `ci-evidencias`. Duas saídas conhecidas, e a OS precisa
escolher **uma**:

* acrescentar a branch da ponta ao `on: push` do `ci-os-integracao.yml` — é
  como a OS de blindagem obteve execução real, e não exige merge; ou
* levar `ci-os-integracao.yml` à branch default, que é o que destrava
  `workflow_dispatch` de uma vez por todas.

Observação de custo: são **373 commits e 634 arquivos** desde o último verde
conhecido, e 30 gates que nunca rodaram. A primeira execução real **vai**
encontrar vermelho — no mínimo os dois já medidos aqui, `rankingfn` e
`contratosui`. Isso é o resultado esperado, não um defeito da OS: um portão que
volta a rodar depois de seis dias parados serve exatamente para isso.

### 9.3 — `rankingfn` / PF-01 *(pode ser paralela à 9.2)*

Fechar o vermelho medido: a contagem de `functions-moderacao` em PF-01 diz 9 e a
árvore tem 11, porque a Comunicação Controlada V1 exportou
`emitirEventoDeSistema` e `consultarCatalogoDeComunicacao`. Existem **duas
correções já escritas fora desta linhagem** (`fda24a2`, `5371a87`); a OS precisa
decidir se **traz uma delas** ou refaz — e a decisão depende da 9.1.

### 9.3b — `contratosui` / T27: a fixture da bancada *(independe da 9.1)*

A evidência sintética de `teste_contrato_suites.sh` (`resultados()`) escreve
quatro logs à mão, e a fonte única tem dezessete contratos. Cada contrato novo
piora o caso T27. O conserto certo é `resultados()` **derivar** os logs da
própria fonte — como o mesmo arquivo já faz para descobrir as suítes — em vez de
manter uma lista paralela; e acertar o número de casos que o log sintético do
`contratosui` anuncia sobre si mesmo.

**Armadilha de custo, e é a razão de a OS 42 não ter feito isso:** o conserto
mora dentro do arquivo cujo digest está fixado pelo contrato do próprio
`contratosui`. Recarimbá-lo produz mais um digest no ponto exato em que as
folhas da linhagem P colidem — encarece a arbitragem da 9.1, e por isso as duas
precisam ser pensadas juntas mesmo sendo tecnicamente independentes.

### 9.4 — Estender a régua externa aos 11 contratos desprotegidos

`CONTRATOS_MINIMOS`, `PISOS_PROVAS`, `PISOS_CASOS` e `PISOS_EXIGE` nomeiam seis
gates. Os outros onze (`avatarcanon`, `avatarhml`, `perfilvis`, `rknavpub`,
`compavrank`, `compnavpub`, `socialestado`, `socialleitor`, `socialtela`,
`audsocial`, `a11yamigos`) perdem o contrato em silêncio — medido. A correção é
mecânica e mora **fora** do arquivo que ela protege, como a OS 42-C2 fez.
Acrescentar também o `casos` que falta em `chatdom`.

### 9.5 — Contrato de conteúdo para os 48 gates que não têm

É a lacuna mais larga do censo, e a mais cara: 48 suítes podem virar
`expect(1, 1)` sem que nada reclame. Não cabe numa OS só. Recorte sugerido por
ordem de risco: (a) as 11 de `app/test/casca` e as 5 de Ranking, que são a casca
publicável; (b) os 9 codebases Node, onde o "contrato" teria de ser sobre o
alvo do `npm test` e não sobre um `.dart`; (c) o resto.

### 9.6 — `cascaaud`: fechar a guarda fail-open

Os dois `return` sobre `existsSync` fazem o único caso Dart que cobra a fonte
única passar por vazio quando o que ele guarda some. Correção pequena, e a
mesma disciplina de sempre: ausência do alvo tem de **reprovar**, não retornar.

### 9.7 — Decidir o que fazer com os 25 "PORTÃO" fora da fonte única

Os 13 do `build.yml` são hoje o **único** conjunto alcançável nesta ponta (os 9 do `release-aab.yml` e os 3 do `tamanho-aab.yml` também não disparam) — e
estão fora da fonte única, sem marcador, sem contrato e sem agregador. Além
disso, 6 suítes (`test/sessao/*`, `online_auth`, `conexao_producao`) só existem
ali. Ou entram na fonte única, ou a fonte única deixa de ser "a" relação de
gates do repositório. Autoridade: a mesma da 9.1.

---

## 10. LIMITES DECLARADOS DESTA MEDIÇÃO

* **`workflow_dispatch` foi lido do repositório, não da API do GitHub.** A
  conclusão vem de `origin/main` conter só `build.yml` — regra documentada e já
  medida por 422 em auditoria anterior. Não houve chamada à API nesta sessão.
* **Nenhum gate foi executado dentro de um runner.** Tudo o que roda neste
  laudo rodou em bancada local; o comportamento do `bash -e` dos passos foi lido
  do YAML, não exercitado no Actions.
* **59 dos 65 gates não tiveram o resultado atual medido**, com os motivos do
  §5.2. O laudo não afirma que eles estão verdes — afirma que ninguém sabe.
* **A bancada roda Node v24; o CI pina Node 20.** `functions-ranking` avisa
  `EBADENGINE`. O vermelho de PF-01 é uma contagem de `export const` num arquivo
  fonte e não depende da versão do runtime, mas a divergência fica registrada.
* **A cópia de bancada foi extraída com `core.autocrlf=false`**, e a fonte única
  confere byte a byte com o blob. Sem isso o Windows entrega CRLF e os `.sh` não
  executam.
* **`git worktree` destacado** foi usado uma vez, só para dar histórico ao
  `composloja`, e removido ao fim. Nenhum commit foi feito na árvore auditada.
