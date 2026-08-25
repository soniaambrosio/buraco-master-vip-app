# OS 42‑A2 — Arbitragem final da fixture `contratosui`/T27 na arquitetura P V1

Laudo durável. Arbitragem independente, comparativa e **somente leitura** sobre as
candidatas. Nenhuma das duas árvores candidatas foi editada, comitada, publicada,
mesclada ou composta. As mutações desta campanha foram aplicadas exclusivamente em
worktrees de auditoria descartáveis e restauradas com `git checkout --`, com
conferência de árvore limpa antes e depois de cada uma.

---

## 0. Veredito

> **A autoridade canônica da fixture `contratosui`/T27 na arquitetura P é
> `5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf`, e a candidata
> `7db53fd69ef35a412a86684e2e4d6716f7d6d542` não deve ser composta.**

**PASS — OS 46 É A AUTORIDADE.**

Motivo em uma frase: a OS 42‑C3 mantém uma relação escrita à mão
(`readonly FABRICADOS`) que **nenhuma guarda protege** — encolhê‑la de quatro nomes
para um, com o digest recarimbado, deixa a régua VERDE, o T27 VERDE e o T30 VERDE —,
e deixa as **duas âncoras que ela mesma acrescentou** removíveis da fonte única sem
qualquer detector, porque não subiu `PISOS_EXIGE`. A OS 46 fecha os dois eixos.

---

## 1. Gate Zero

### 1.1 Identidade das pontas (duas leituras remotas independentes de cada ref)

| leitura | ref | SHA |
|---|---|---|
| 1ª (`git ls-remote`) | `refs/heads/correcao/contratosui-t27-fixture-p-v1` | `5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf` |
| 2ª (`git ls-remote`) | `refs/heads/correcao/contratosui-t27-fixture-p-v1` | `5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf` |
| 1ª (`git ls-remote`) | `refs/heads/correcao/os42-c3-fixture-contratosui-piso-v1` | `7db53fd69ef35a412a86684e2e4d6716f7d6d542` |
| 2ª (`git ls-remote`) | `refs/heads/correcao/os42-c3-fixture-contratosui-piso-v1` | `7db53fd69ef35a412a86684e2e4d6716f7d6d542` |
| remoto | `refs/heads/correcao/os42-c2-torneiobase-fail-closed-v1` (base) | `828d5a0e5a7e57a575ecd7b906629a746b6a4cc2` |

`remote.origin.fetch` = `+refs/heads/*:refs/remotes/origin/*` (refspec **íntegro** —
sem truncamento que pudesse mentir sobre ancestralidade). Local, remote‑tracking e
remoto coincidem nas três referências.

### 1.2 Ancestralidade

```
pai(5c19f19) = 828d5a0        pai(7db53fd) = 828d5a0
merge-base(5c19f19, 7db53fd) = 828d5a0
5c19f19 ancestral de 7db53fd? NÃO      7db53fd ancestral de 5c19f19? NÃO
merge commits em 828d5a0..5c19f19 = 0  em 828d5a0..7db53fd = 0
commits sobre a base: exatamente 1 em cada
```

- `5c19f19` — `fix(ci): a evidencia da FASE B deriva da fonte — T27 volta a ser CONTROLE verde` (2026‑08‑24 17:56:57 ‑0300)
- `7db53fd` — `fix(ci): a fixture do 'contratosui' le o piso em vez de carregar um numero` (2026‑08‑24 18:29:57 ‑0300)
- `828d5a0` — `fix(ci): 'torneiobase' fail-closed — o gate da fundacao P nao pode sumir calado` (2026‑08‑24 11:18:09 ‑0300)

São **irmãs**. Nenhuma pode ser tratada como continuação da outra.

### 1.3 Publicação, PR, merge, tag e deploy

| eixo | situação |
|---|---|
| publicação | ambas existem em `origin`; nenhuma em `origin/main` |
| PR | nenhum. Os PRs do repositório são #1 (fechado, `soniaambrosio-patch-1`), #2, #3, #4 — nenhum referencia as candidatas |
| merge | nenhuma é ancestral de `origin/main`; contidas apenas na própria ref |
| tag | única tag do repositório é `latest` → `fb9edb5c…` (nenhuma candidata) |
| deploy | somente `github-pages` a partir de `codex/inicio-ui`; nenhum toca as candidatas |
| execução em CI | **0 runs** do GitHub Actions em `correcao/contratosui-t27-fixture-p-v1`, em `correcao/os42-c3-fixture-contratosui-piso-v1` e na base. `ci-os-integracao.yml` só dispara em `push` para `integracao/os-final-backend-flutter` e `correcao/ci-composicao-perfil-mesa-ranking-v2-v1`, mais `workflow_dispatch` |

### 1.4 Folha concorrente posterior

Descendentes de `828d5a0` que tocam `scripts/ci/{teste_contrato_suites.sh, gates_os_integracao.txt, verificar_contrato_suites.sh}`:

| ref | SHA | arquivos |
|---|---|---|
| `origin/claude/os50-1-app-check-android-ativacao-v1` | `3bb3766` | `gates_os_integracao.txt`, `verificar_contrato_suites.sh` (**não toca a bancada**) |
| `origin/correcao/contratosui-t27-fixture-p-v1` | `5c19f19` | os três |
| `origin/correcao/os42-c3-fixture-contratosui-piso-v1` | `7db53fd` | os dois primeiros |

**Nenhuma folha nova resolveu o mesmo defeito depois delas.** App Check não mexe em
`teste_contrato_suites.sh` e portanto não é uma terceira solução do T27.

### 1.5 Inventário das bancadas

Todas as bancadas em uso são desta arbitragem, criadas como worktrees destacadas.
Nenhuma bancada anterior de terceiros foi limpa, sobrescrita ou reutilizada.

| bancada | HEAD | papel | estado final |
|---|---|---|---|
| `C:/a2Z` | `828d5a0` | base, execução íntegra | limpa |
| `C:/a2A` | `5c19f19` | candidata A, execução íntegra | limpa |
| `C:/a2B` | `7db53fd` | candidata B, execução íntegra | limpa |
| `C:/a2A18` | `5c19f19` | A com 18º contrato | mutação declarada, restaurável |
| `C:/a2B18` | `7db53fd` | B com 18º contrato | mutação declarada, restaurável |
| `C:/a2Am` | `5c19f19` | campanha de mutação de A | limpa |
| `C:/a2Bm` | `7db53fd` | campanha de mutação de B | limpa |
| `F:/a2base`, `F:/a2candA`, `F:/a2candB` | base / A / B | cópias de referência intocadas | limpas |

**Contaminação detectada e tratada.** Um lote de sondas desta própria arbitragem
(`refaz.sh`) rodou concorrente às campanhas em `C:/a2Am` e `C:/a2Bm`. O sintoma foi
inequívoco — motivos de uma mutação aparecendo no laudo de outra e divergências de
digest cruzadas. **Todos os resultados daquele lote foram descartados**, o processo
foi encerrado por PID, as árvores foram restauradas e a campanha inteira foi
**reexecutada em série**, com uma guarda que aborta a mutação se a árvore não estiver
limpa e outra que declara `INDETERMINADA` a mutação cuja âncora não casou. Só os
resultados da execução serial constam deste laudo.

Outras sessões desta máquina (`C:/os29c5`, `C:/os30-r3`) rodaram campanhas próprias em
worktrees disjuntas durante a medição. Elas disputam CPU — o que altera o tempo de
parede, não o veredito — e não tocam nenhuma bancada desta OS.

---

## 2. Matriz de arquivos e responsabilidades

| arquivo | base | OS 46 (`5c19f19`) | OS 42‑C3 (`7db53fd`) |
|---|---|---|---|
| `docs/OS46-CONTRATOSUI-T27-FIXTURE-P.md` | — | **+98 linhas** (laudo próprio) | — |
| `scripts/ci/gates_os_integracao.txt` | — | +24/−? (contrato de `contratosui`) | +22/−? (contrato de `contratosui`) |
| `scripts/ci/teste_contrato_suites.sh` | — | +187/−36 | +102/−22 |
| `scripts/ci/verificar_contrato_suites.sh` | — | **+11/−? (régua)** | **não toca** |
| total | — | 4 arquivos, 284 inserções | 2 arquivos, 102 inserções |

**Nenhuma das duas toca produto, Rules, workflow, Functions ou `app/`.** Conferido por
`git diff --name-only`: só `docs/` e `scripts/ci/`.

Identidade dos demais contratos (bloco por bloco, comentários removidos):

| gate | `828d5a0` | `5c19f19` | `7db53fd` |
|---|---|---|---|
| `torneiobase` | `52d066d9…` | **igual** | **igual** |
| `admvip` | `fdea9a1f…` | **igual** | **igual** |
| `portaoci` | `3238de34…` | **igual** | **igual** |
| `comunicacao` | `ecb63c31…` | **igual** | **igual** |
| `contratosui` | `49437552…` | `9ea90395…` | `68ea47f6…` |

Só o bloco de `contratosui` muda. Os 17 contratos existem nas três árvores.

---

## 3. Diff semântico entre as candidatas

### 3.1 O defeito, reproduzido

A FASE B de `verificar_contrato_suites.sh` cobra um `t_<gate>.log` para **todo** gate
com contrato. A fixture `resultados()` da base escrevia **quatro** logs à mão
(`comunicacao`, `chatdom`, `portaoci`, `contratosui`) e a fonte já tinha **dezessete**
contratos. T27 — o único CONTROLE verde da FASE B — passou a receber exit 1.

**Base `828d5a0`, matriz integral: `casos ok: 73 | casos com falha: 1`,
`TESTE DO CONTRATO: VERMELHO`.** A única falha é
`T27 CONTROLE — evidencia completa e datada => VERDE — esperado exit 0, obtido 1`.

E a prova de que o defeito era da **fixture**, e não do verificador: montando na
própria base uma evidência completa (um log por gate contratado, datado depois do
carimbo), a FASE B da base fica **VERDE** — `contrato de suites: 17 conferido(s),
tudo no lugar`, exit 0.

### 3.2 As duas leituras

**OS 46 (`5c19f19`) — topologia completa.** `resultados()` deixa de ser lista e passa a
derivar da fonte, pelo auxiliar novo `gates_com_contrato`. A linha de log carrega os
dois vocabulários de contador (`+N` do Flutter e `casos ok: N` dos portões em bash) com
valores folgados. `resultados_completos()` — a segunda fixture, já derivada, criada
pela OS 42‑C2 — é **removida**, e as quatro chamadas da campanha C2 passam a usar a
fixture única. T27 volta a ser CONTROLE verde. Seis casos novos (OS46‑01…06), oito
`exige` novos e `PISOS_EXIGE contratosui:19`; pisos 65→72 e 74→80.

**OS 42‑C3 (`7db53fd`) — ausência exata como oráculo.** `resultados()` continua
fabricando log só para quatro gates, agora nomeados uma vez em
`readonly FABRICADOS='comunicacao chatdom portaoci contratosui'`, e o número de cada
log passa a ser lido do contrato (`casos_declarados`). T27 **deixa de ser controle
verde**: passa a exigir exit 1 com o conjunto **exato** dos treze gates sem log,
comparado por `comm -23` e por igualdade real. Duas `exige` novas ancoram a comparação.
Pisos e régua **inalterados**.

### 3.3 A contradição interna da OS 42‑C3

O cabeçalho de `resultados()` continua dizendo, literalmente, *"monta a evidencia de um
run bem-sucedido"*, enquanto o cabeçalho de `resultados_completos()`, trinta linhas
abaixo, diz que `resultados()` *"fabrica evidencia INCOMPLETA de proposito"*. As duas
frases convivem no mesmo arquivo, sobre a mesma função.

### 3.4 O que a ausência deliberada custa: T28 e T32 ficam vazios

Medição direta, na árvore `7db53fd`, com a fixture **intacta e sem nenhuma sabotagem**:

```
exit = 1
13 × "CONTRATO DE SUITE: o gate '<x>' nao deixou log ... — marcador sem execucao"
4 × "ok   log"      3 × "ok   casos" (81>=81, 38>=38, 74>=74)
```

Ou seja: o estado de partida de T28…T32 já é vermelho **com a agulha que T28 e T32
procuram**. T28 (`esperar 1 … 'marcador sem execucao'`) e T32 (mesma agulha) passariam
com a sabotagem revertida. São dois casos que continuam contando para `provas` e para
`casos` e não provam mais nada — exatamente a "prova vazia" contra a qual o cabeçalho
da própria bancada adverte. Na OS 46 os dois voltam a discriminar, porque o estado de
partida é verde.

### 3.5 Contagem e digest, conferidos independentemente

| | base | OS 46 | OS 42‑C3 |
|---|---|---|---|
| linhas contadas por `^[[:blank:]]*(ok\|nok\|esperar)[[:blank:]]` | 65 | **72** | **66** |
| `provas` declarado na fonte | 65 | **72** | **65** |
| casos realmente executados (`casos ok:` no fim da matriz) | 73+1 | **80** | **74** |
| `casos` declarado na fonte | 74 | **80** | **74** |
| `exige` no contrato de `contratosui` | 11 | **19** | **13** |
| sha256 recomputado (`tr -d '\r' \| sha256sum`) | `ce872aad…` | `f76eb744…` | `8bc0afcc…` |
| sha256 declarado na fonte | idem | idem | idem |

Os digests das duas candidatas conferem. **Mas a OS 42‑C3 declara `provas 65` para uma
suíte que tem 66 declarações**: como `provas` é piso (`>=`), o contrato passa, e sobra
**uma linha de folga silenciosa** — uma `ok`/`nok`/`esperar` pode ser apagada sem que
nada reclame. Na OS 46 a folga é zero (72 declaradas, 72 reais; 80 executados, 80
declarados).

---

## 4. Resultados integrais das três árvores

Cada evidência abaixo foi produzida na árvore indicada, sem reaproveitamento entre elas.

| prova | `828d5a0` (base) | `5c19f19` (OS 46) | `7db53fd` (OS 42‑C3) |
|---|---|---|---|
| `contratosui` — matriz integral | **VERMELHO** — `casos ok: 73 \| falhas: 1` (T27) | **VERDE** — `casos ok: 80 \| falhas: 0` | **VERDE** — `casos ok: 74 \| falhas: 0` |
| verificador FASE A | exit 0 — `17 conferido(s), tudo no lugar` | exit 0 — 17 conferidos | exit 0 — 17 conferidos |
| verificador FASE B, evidência completa e válida | exit 0 — 17 conferidos | exit 0 — 17 conferidos | exit 0 — 17 conferidos |
| `teste_portao_os_integracao.sh` | exit 0 — `casos ok: 38 \| falhas: 0`, VERDE | exit 0 — **38/38** VERDE | exit 0 — **38/38** VERDE |
| agregador, todos `exit_<gate>` = 0 | exit 0 — `resultado: VERDE` | exit 0 — VERDE | exit 0 — VERDE |
| agregador, `nao_contratosui` presente | exit 1 — `contratosui NAO EXECUTADO`, VERMELHO | exit 1 — VERMELHO | exit 1 — VERMELHO |
| `torneiobase` (`flutter test test/torneios/fundacao_base_p_test.dart`) | exit 0 — **+56 All tests passed!** | exit 0 — **+56** | exit 0 — **+56** |
| `admvip` (`flutter test test/torneios/admissao_vip_torneios_test.dart`) | exit 0 — **+48 All tests passed!** | exit 0 — **+48** | exit 0 — **+48** |
| análise estática (`bash -n` nos três scripts) | OK | OK | OK |
| `shellcheck` | **não disponível nesta máquina** — não executado | idem | idem |

Nenhuma execução excedeu limite; não há prova classificada como `INCONCLUSIVA` por
timeout.

Correções à tabela preliminar da OS 47‑A1: todos os sete eixos foram **reproduzidos e
confirmados** (4 vs 2 arquivos; A toca a régua e B não; 72/80 vs 65/74; derivação vs
leitura do piso; 1 conflito com App Check vs 0; `portaoci` 38/38 nas duas; FASE A com 17
contratos nas duas). Nenhum número precisou de correção.

---

## 5. Campanha comparativa, mutação por mutação

Legenda: **PEGA** = algum detector reprovou nominalmente. **SOBREVIVE** = nenhum
detector reagiu. **n/a** = a propriedade não existe naquela candidata (registrado, não
computado como sobrevivência). Detectores: **régua** = `verificar_contrato_suites.sh`;
**matriz** = `teste_contrato_suites.sh` integral; **T27‑fiel** = instrumento que extrai
e executa a **própria** `resultados()` da candidata e depois aplica a assertiva do T27
dela (validado contra as matrizes integrais: reproduz A verde com 17 logs e B vermelho
com 13 faltando); **agregador** = `portao_os_integracao.sh`.

| # | mutação | âncora | OS 46 — detector e motivo | OS 42‑C3 — detector e motivo |
|---|---|---|---|---|
| 1 | reintroduzir `casos ok: 34` na fixture (digest realinhado) | `printf` da fixture / `n=casos_declarados(...)` | **PEGA** — T27‑fiel: `'contratosui' executou 34 caso(s) e o piso e 80 — a suite encolheu` (+ `comunicacao`, `portaoci`) | **PEGA** — T27‑fiel: 16 motivos ≠ 13 esperados; extras `executou 34 … piso 74/81/38` |
| 2 | rebaixar a evidência por outro caminho (fixture perde `casos ok:`) | linha de log da fixture | **PEGA** — T27‑fiel: `'portaoci' executou 0 caso(s) e o piso e 38` | **PEGA** — T27‑fiel: 15 motivos ≠ 13 |
| 3 | rebaixar o piso contratual (`casos` → 10) | linha `casos` de `contratosui` | **PEGA** — régua: `o piso de casos de 'contratosui' foi baixado de 80 para 10 na fonte` | **PEGA** — régua: `… de 74 para 10 …` |
| 4 | subir `casos` para 200 sem crescer a matriz | linha `casos` | **SOBREVIVE** (régua e T27) — piso é `>=`; em CI real o log traria 80 < 200 | **SOBREVIVE** (régua e T27) — idem |
| 5 | remover T27 com digest realinhado | bloco do T27 | **PEGA** — régua: `71 declaracoes e o piso e 72` + `o bloco esperar 0 "T27 CONTROLE sumiu` | **PEGA** — régua: `64 declaracoes e o piso e 65` + os dois blocos `comm -23` e `[ "$t27_obtidos" = … ]` |
| 6 | trivializar T27 com digest realinhado | bloco do T27 | **PEGA** — régua: `o bloco esperar 0 "T27 CONTROLE sumiu` | **PEGA** — régua: os dois blocos sumiram |
| 7 | remover um motivo esperado (log contratado omitido) | diretório de evidência | **PEGA** — régua: `o gate 'torneiobase' nao deixou log … marcador sem execucao` | **PEGA** — idem |
| 8 | acrescentar motivo estranho (suíte de `a11yamigos` some do disco) | arquivo da suíte | **PEGA** — régua: `suite removida ou renomeada`; T27‑fiel também reprova | **PEGA** — régua idem; T27‑fiel: 14 motivos ≠ 13 |
| 9 | remover os casos novos da campanha | = #5/#6 | **PEGA** (ver #5) | **PEGA** (ver #5) |
| 10 | esvaziar a campanha mantendo nomes/comentários | bloco do T27 comentado, digest realinhado | **PEGA** — régua: `71 declaracoes e o piso e 72` + bloco sumiu (o leitor ignora linha de comentário) | **PEGA** — régua: `64 e o piso e 65` + dois blocos sumiram |
| 11 | alterar digest sem alterar a suíte | linha `sha256` | **PEGA** — régua: `o conteudo … mudou e a assinatura nao` | **PEGA** — idem |
| 12 | alterar a suíte sem recarimbar | fim da suíte | **PEGA** — régua: mesma família | **PEGA** — idem |
| 13 | acrescentar contrato novo sem log | evidência + fonte | **PEGA** — régua: `nao deixou log` para o gate novo; e a matriz integral com 18º contrato fica **VERDE 80/80** | **PEGA** — idem; matriz com 18º contrato **VERDE 74/74** |
| 14 | linha indentada nova que "deveria virar gate" | 1ª linha do bloco `contratosui` | **PEGA** — régua: `atributo desconhecido 'gatefalso'` | **PEGA** — idem |
| 15 | fazer a fixture ignorar gate contratado | derivação / `FABRICADOS` | **PEGA** — régua: `o bloco for k in $(gates_com_contrato "$W/$FONTE_W") sumiu` | **SOBREVIVE — BLOQUEANTE** — régua VERDE, T27 ok, T30 ok e **matriz integral VERDE `casos ok: 74 \| falhas: 0`** (ver §6.1) |
| 16 | aceitar `NÃO EXECUTADO` indevidamente | marcadores do agregador | **PEGA** — agregador exit 1, `contratosui NAO EXECUTADO`, VERMELHO | **PEGA** — idem |
| 17 | remover a derivação `gates_com_contrato` | corpo de `resultados()` | **PEGA** — régua, pelo `exige` da derivação | **n/a na fixture** — B não usa a derivação em `resultados()`; usa em `resultados_completos()` e na assertiva do T27, e ambas ficam cobertas pelo `exige` do `comm -23` |
| 18 | substituir a derivação por lista paralela de quatro | corpo de `resultados()` | **PEGA** — régua: bloco `for k in $(gates_com_contrato …)` sumiu; T27‑fiel também reprova (13 gates sem log) | **n/a** — a lista paralela **é** o desenho de B |
| 19 | remover `resultados_completos()` | função | **n/a** — a OS 46 já a removeu por decisão | **SOBREVIVE na régua** (não há `exige` que a nomeie). A matriz quebraria nas quatro chamadas C2‑19…C2‑22 — **não medido**; classificado como não bloqueante |
| 20 | reintroduzir uma segunda fixture equivalente | fim da suíte, digest realinhado | **SOBREVIVE** — nada proíbe. Não bloqueante (regressão de higiene) | **n/a** — B já mantém duas |
| 21 | rebaixar `PISOS_EXIGE` dentro da régua | `readonly PISOS_EXIGE` | **SOBREVIVE** — limite conhecido, registrado pela própria OS 46 | **SOBREVIVE** — e em B a propriedade **nem existe** para `contratosui` |
| 22 | sabotagem semântica + pisos e digest realinhados juntos | T27 + `provas`/`casos`/`sha256` | **PEGA** — régua: `o piso de casos … baixado de 80 para 1` + bloco do T27 sumiu | **PEGA** — régua: `… de 74 para 1` + os dois blocos sumiram |
| 23 | alterar o conjunto contratado sem atualizar a prova recíproca | contrato removido / renomeado | **PEGA/coerente** — T27‑fiel: contrato removido → 16 logs, VERDE; renomeado → 17 logs, VERDE | **coerente** — T27‑fiel: removido → 12 esperados, ok; renomeado → 13 esperados, ok |
| 24 | fazer o controle olhar só a cor, não o conjunto | `[ "$t27_obtidos" = "$t27_esperados" ]` | **n/a** — o T27 de A é controle verde; a comparação de conjunto vive em OS46‑01/02 | **PEGA** — régua: `o bloco [ "$t27_obtidos" = "$t27_esperados" ] sumiu` |
| 25 | remover a própria guarda externa / a âncora que a exige | `exige` novos na fonte | **PEGA** — régua: `o contrato de 'contratosui' declara 18 'exige' e o piso e 19 — o contrato encolheu` (e 17/19 com dois) | **SOBREVIVE — BLOQUEANTE** — retirar uma **ou as duas** `exige` novas deixa a régua VERDE (não há `PISOS_EXIGE` para `contratosui`) |
| — | apagar a comparação de conjuntos (`comm -23`) | linha do `comm` | **n/a** | **PEGA** — régua: bloco `comm -23 …` sumiu |
| — | log de gate **não contratado** acrescentado | evidência | **SOBREVIVE** — pré‑existente, comum às duas | **SOBREVIVE** — idem |
| — | contador **exatamente** no piso sem executar nada | evidência | **SOBREVIVE** — pré‑existente, comum às duas | **SOBREVIVE** — idem |
| — | CONTROLE íntegro | — | exit 0, 17 conferidos | exit 0, 17 conferidos |

Toda mutação partiu de árvore limpa (guarda automática), teve a âncora conferida antes
da alteração, foi restaurada com `git checkout --` e teve a restauração verificada.
Nenhuma mutação ficou `INDETERMINADA` por âncora que não casou.

---

## 6. Sobreviventes e causalidade

### 6.1 Bloqueante — OS 42‑C3: `FABRICADOS` é lista paralela sem dono

`readonly FABRICADOS` é a relação dos quatro gates que a fixture de B fabrica. **Nenhum
`exige`, nenhum piso e nenhum caso da matriz guarda o conteúdo dessa linha.**

Medido, com o digest recarimbado em cada passo:

| `FABRICADOS` | régua | T27 de B | T30 de B | matriz integral |
|---|---|---|---|---|
| `'comunicacao chatdom portaoci contratosui'` (4) | VERDE | ok — 13 gates sem log | ok | **VERDE — `casos ok: 74 \| falhas: 0`** |
| `'comunicacao portaoci contratosui'` (3) | **VERDE** | **ok — 14 gates sem log** | **ok** (agulha `carimbo de execucao ausente` presente 3×) | **VERDE — `casos ok: 74 \| falhas: 0`** |
| `'comunicacao'` (1) | **VERDE** | **ok — 16 gates sem log** | **ok** (agulha presente 1×) | não medida |
| `''` (0) | VERDE | ok — 17 gates sem log | **FALHA** — a agulha some (sem log, o verificador nunca chega a datar) | não medida (T30 já reprova) |

A linha do meio é a prova definitiva, e foi medida com o **instrumento mais forte que
existe aqui**: a matriz integral de `contratosui`, rodada de ponta a ponta na árvore
`7db53fd` com `FABRICADOS` reduzido a três nomes e o digest recarimbado. Resultado:
`casos ok: 74 | casos com falha: 0`, `TESTE DO CONTRATO: VERDE` — **placar idêntico ao
da árvore íntegra**. Nenhum dos 74 casos reage.

A causalidade é direta: a assertiva do T27 de B deriva `esperados = contratados −
FABRICADOS`, e a fixture escreve `FABRICADOS`. **Os dois lados leem a mesma relação, e
por isso encolhê‑la é auto‑consistente.** A evidência real de FASE B — a única parte de
`resultados()` que ainda prova alguma coisa — pode ser reduzida de quatro gates para
**um**, e o gate `contratosui` continua verde. Só o caso degenerado (zero) reage, e
reage por T30, não por T27.

Isto viola frontalmente os critérios 1 ("derivar de autoridade única, sem lista paralela
silenciosa"), 3 ("reprovar quando a fixture ficar atrás da fonte") e 11 ("não depender
de revisão humana para um defeito que pode ser guardado automaticamente").

### 6.2 Bloqueante — OS 42‑C3: as duas âncoras novas são removíveis sem detector

A OS 42‑C3 acrescentou `exige comm -23 …` e `exige [ "$t27_obtidos" = "$t27_esperados" ]`
— e **não** acrescentou `contratosui` a `PISOS_EXIGE`. Medido: retirar **uma** das duas
da fonte única deixa a régua VERDE; retirar **as duas** também. O contrato desce de 13
para 11 `exige` sem uma palavra.

O escape é de dois passos e cada passo é individualmente verde:
1. apagar as duas `exige` da fonte → VERDE;
2. trivializar o T27 e recarimbar o digest → VERDE (as mutações #5, #6, #10, #22 só eram
   pegas por essas duas âncoras).

Na OS 46 o passo 1 é vermelho: `PISOS_EXIGE contratosui:19` reprova em 18.

### 6.3 Bloqueante — OS 42‑C3: dois casos da FASE B ficaram vazios

T28 e T32 (§3.4). Ambos são `exige` nominais do contrato desde a base — o contrato
continua satisfeito enquanto os casos não provam mais nada.

### 6.4 Não bloqueantes, comuns às duas

| sobrevivente | natureza |
|---|---|
| `casos` declarado acima da matriz real (#4) | piso é `>=`; o CI real reprova pelo log verdadeiro |
| log de gate não contratado ignorado | pré‑existente na FASE B |
| contador exatamente no piso sem execução | pré‑existente; inerente a evidência sintética |
| `PISOS_*` rebaixados **dentro** da régua (#21, #25b) | limite auto‑referencial, registrado pela própria OS 46 no seu laudo |

### 6.5 Não bloqueante, específico da OS 46

Uma segunda fixture equivalente pode ser reintroduzida (#20) sem detector. É regressão
de higiene, não de proteção — e é justamente o estado em que a OS 42‑C3 permanece por
desenho.

---

## 7. Comportamento sob 18º contrato

Ambas as candidatas receberam um contrato novo **completo** (`gatenovo18`, com `suite`,
`executor`, `sha256`, `provas`, `exige`, produtor no workflow) e rodaram a matriz
integral:

| árvore | resultado |
|---|---|
| `5c19f19` + 18º contrato | **VERDE — `casos ok: 80 \| falhas: 0`** |
| `7db53fd` + 18º contrato | **VERDE — `casos ok: 74 \| falhas: 0`** |

**A hipótese B da OS não se confirma neste ponto**, e o laudo registra a correção: a
OS 42‑C3 **não** exige manutenção manual para o 18º contrato. O conjunto esperado do
T27 dela é derivado (`contratados − FABRICADOS`), então o contrato novo entra sozinho no
lado esperado. Também sobrevive à remoção e à renomeação de contrato (medido pelo
instrumento fiel: 12 e 13 esperados, respectivamente).

**Este eixo não decide a arbitragem.** O que decide é o §6.1 e o §6.2: o que a OS 42‑C3
não deriva é a relação `FABRICADOS`, e é ela que pode encolher calada.

---

## 8. Decisão sobre cada prova exclusiva da perdedora

| prova exclusiva da OS 42‑C3 | decisão | fundamento |
|---|---|---|
| a fixture lê a autoridade contratual em vez de carregar um número literal (`casos_declarados`) | **redundante — não portar** | A deriva conta o mesmo problema por outro caminho (valor acima de todo piso + pisos subidos na régua), e a mutação #1 é pega nas duas. Além disso a leitura do piso faz a fixture **espelhar** um piso rebaixado, o que é a direção errada para uma testemunha |
| T27 exige o conjunto exato dos contratos **sem** evidência | **perigosa — não portar** | é o que fabrica o defeito permanente, esvazia T28/T32 e congela uma topologia artificial. Incompatível com a topologia vencedora, onde não há ausência deliberada |
| comparação por `comm -23` | **já coberta pela vencedora** | OS46‑01 (`faltando46`) e OS46‑02 (`sobrando46`) fazem a comparação de conjunto nas **duas** direções entre os gates contratados e os logs da fixture, e ambas são `exige` nominais do contrato |
| igualdade real entre obtidos e esperados | **já coberta pela vencedora** | mesma razão: OS46‑01/02 exigem conjuntos **vazios**, não "contém" |
| campanha que demonstrou que cor verde/vermelha não bastava | **absorver semanticamente depois** | a lição é legítima e só está **parcialmente** na vencedora: OS46‑01/02 comparam conjuntos, mas OS46‑03/04/05 ainda afirmam `exit` + uma agulha. Cabe uma OS própria, futura, que estenda os casos negativos da FASE B da OS 46 para afirmarem o **conjunto de motivos**. **Não é tarefa da OS 47‑C1** |
| proteção contra trivialização do T27 com digest realinhado (as duas `exige`) | **superada — não portar** | a vencedora tem oito âncoras e `PISOS_EXIGE contratosui:19`; a campanha mostra que a OS 46 pega #5, #6, #10, #22, #25 e a OS 42‑C3 **falha** em #25. O conteúdo literal das duas âncoras de B aponta para código que não existe na OS 46 |

**Nada será portado nesta OS.** A conclusão é que a candidata vencedora é utilizável
**pura**; a única propriedade que valeria absorver depois (conjunto de motivos nos casos
negativos da FASE B) é um acréscimo, não um resgate.

---

## 9. Autoridade escolhida

**`5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf`** — branch
`correcao/contratosui-t27-fixture-p-v1`, OS 46.

Aderência aos doze critérios:

| # | critério | OS 46 |
|---|---|---|
| 1 | expectativa derivada de autoridade única, sem lista paralela | **sim** — `gates_com_contrato` lê a fonte; a derivação é `exige` nominal |
| 2 | reprova quando contrato novo não produz evidência | **sim** — OS46‑04 |
| 3 | reprova quando a fixture fica atrás da fonte | **sim** — OS46‑01, OS46‑05 (fixture‑isca) |
| 4 | reprova quando pisos/digests/guardas são rebaixados | **sim** — #3, #5, #6, #10, #11, #12, #22, #25 |
| 5 | exige conjunto e motivo corretos, não só exit code | **sim** nas duas direções (OS46‑01/02); parcial nos negativos (§8) |
| 6 | resiste à trivialização com digest realinhado | **sim** — #6 e #22 |
| 7 | não duplica fixture do mesmo cenário | **sim** — `resultados_completos()` removida |
| 8 | `portaoci`, FASE A e FASE B fail‑closed | **sim** — 38/38, 17 contratos, agregador VERMELHO em `NÃO EXECUTADO` |
| 9 | preserva `torneiobase`, `admvip` e os demais contratos | **sim** — blocos byte a byte idênticos; 56/56 e 48/48 verdes |
| 10 | autoridade sustentável para App Check, OS 40, família B, Treino | **sim** — conflito único de 4 linhas, resolúvel por união dos maiores (§11) |
| 11 | não depende de revisão humana para defeito automatizável | **sim**, exceto o limite auto‑referencial da régua, que ela mesma registra |
| 12 | zero sobrevivente bloqueante | **sim** — os sobreviventes são pré‑existentes/compartilhados e um de higiene |

**Declaração expressa:** a candidata `7db53fd69ef35a412a86684e2e4d6716f7d6d542`
**não deve ser composta** — nem inteira, nem em parte, nem como camada sobre a
vencedora. Ela carrega três sobreviventes bloqueantes (§6.1, §6.2, §6.3) e nenhuma
propriedade exclusiva que a vencedora não cubra ou supere.

O conflito textual com App Check **não** derrotou a OS 46, e a composição limpa **não**
elegeu a OS 42‑C3: a limpeza da OS 42‑C3 na composição é consequência direta de ela não
ter subido piso nenhum.

---

## 10. Instruções parametrizadas para a OS 47‑C1

1. Compor **`5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf`** sobre a raiz P. Não compor
   `7db53fd`.
2. O único conflito previsto com `origin/claude/os50-1-app-check-android-ativacao-v1`
   (`3bb3766`) é em `scripts/ci/verificar_contrato_suites.sh`.
   `scripts/ci/gates_os_integracao.txt` **auto‑merge** (medido com
   `git merge-tree --write-tree`). Resolver por **união dos maiores valores**:

   ```
   readonly CONTRATOS_MINIMOS="comunicacao chatdom portaoci contratosui admvip torneiobase appcheckandroid"
   readonly PISOS_PROVAS="comunicacao:71 chatdom:60 portaoci:49 contratosui:72 admvip:48 torneiobase:56 appcheckandroid:26"
   readonly PISOS_CASOS="comunicacao:81 portaoci:38 contratosui:80 admvip:48 torneiobase:56 appcheckandroid:26"
   readonly PISOS_EXIGE="torneiobase:14 contratosui:19 appcheckandroid:10"
   ```

3. Provas de aceitação após a composição, **sem rebaixar nada**:
   - `bash scripts/ci/teste_contrato_suites.sh` → `casos ok: 80 | casos com falha: 0`, VERDE;
   - FASE A → 17 contratos (18 com App Check composto), exit 0;
   - FASE B com evidência completa → exit 0;
   - `bash scripts/ci/teste_portao_os_integracao.sh` → 38/38 VERDE;
   - `flutter test test/torneios/fundacao_base_p_test.dart` → +56;
   - `flutter test test/torneios/admissao_vip_torneios_test.dart` → +48;
   - agregador com `nao_contratosui` → VERMELHO.
4. Não iniciar composição de nenhuma outra folha nesta mesma OS.

---

## 11. Pisos e digests que devem sobreviver

| chave | valor que a composição deve preservar |
|---|---|
| `contratosui` `sha256` | `f76eb744a957fb28cd5db35f734c0edab32b50483ea18b7a474a7a1ebe471254` |
| `contratosui` `provas` | `72` |
| `contratosui` `casos` | `80` |
| `contratosui` `exige` | **19** blocos |
| `contratosui` `conta` | `^[[:blank:]]*(ok\|nok\|esperar)[[:blank:]]` |
| `contratosui` `contador` | `casos ok: [0-9]+` |
| `PISOS_PROVAS` | `contratosui:72` (e os demais inalterados) |
| `PISOS_CASOS` | `contratosui:80` |
| `PISOS_EXIGE` | `torneiobase:14 contratosui:19` |
| `torneiobase` | `sha256 6351d527…`, `provas 56`, `casos 56`, 14 `exige` |
| `admvip` | `sha256 4b78d50d…`, `provas 48`, `casos 48` |
| `comunicacao` | `sha256 94af3e9b…`, `provas 71`, `casos 81` |

Qualquer composição que faça `contratosui` voltar a `65`/`74`, ou que deixe
`PISOS_EXIGE` sem `contratosui`, está reintroduzindo os escapes §6.2.

---

## 12. Residuais não bloqueantes (registrados, não resolvidos)

1. Os pisos da régua (`PISOS_PROVAS`, `PISOS_CASOS`, `PISOS_EXIGE`, `CONTRATOS_MINIMOS`)
   moram dentro de `verificar_contrato_suites.sh` e quem os verifica é a matriz que eles
   guardam. Rebaixá‑los ali continua sendo edição que só a revisão humana pega
   (mutações #21 e #25b sobrevivem nas duas candidatas). O padrão de solução já existe
   no repositório: a guarda externa que a OS 40‑C1 deu a `rankingfn`.
2. A FASE B ignora `t_<gate>.log` de gate não contratado.
3. A FASE B aceita contador **exatamente** no piso sem que nada tenha executado.
4. `PISOS_EXIGE` dos demais contratos continua residual (só `torneiobase` e, com a
   vencedora, `contratosui`).
5. Uma segunda fixture equivalente pode ser reintroduzida na vencedora sem detector.
6. Os casos negativos da FASE B da vencedora (OS46‑03/04/05) afirmam `exit` + uma agulha,
   não o conjunto de motivos — é aqui que a lição da OS 42‑C3 caberia, em OS própria.
7. `contratosui` **nunca rodou em CI**: `ci-os-integracao.yml` não dispara nas folhas de
   correção. A prova é local por construção.
8. A futura OS 51‑C1 disputa arquivos de CI; a ponta OS 40‑C1 permanece concorrente da
   linhagem OS 42/46; a OS 42.1 permanece pausada; `5819baf` continua proibida — e não
   está na ancestralidade de nenhuma das duas candidatas (conferido).
9. Nenhuma decisão deste laudo autoriza composição geral da Fundação P.

---

## 13. Confirmação de higiene

- Nenhum arquivo das candidatas foi editado, comitado ou publicado.
- Nenhuma branch de correção foi criada; nenhum merge, cherry‑pick ou rebase; nenhum
  push, PR, deploy ou tag; `main` intocada.
- Todas as mutações rodaram em worktrees de auditoria e foram restauradas com
  `git checkout --`, com verificação de árvore limpa registrada mutação a mutação
  ("restauracao: INTEGRA" em 100% dos casos das campanhas seriais).
- `C:/a2Am` e `C:/a2Bm` terminaram com **0 arquivos rastreados sujos**.
- `C:/a2Z`, `C:/a2A`, `C:/a2B` terminaram com **0 arquivos rastreados sujos**
  (`flutter pub get` só cria material não rastreado).
- `C:/a2A18` e `C:/a2B18` mantêm, declaradamente, a mutação do 18º contrato — dois
  arquivos, restauráveis com `git checkout --`.
- Um lote de sondas concorrente foi detectado, encerrado, e **todos os seus resultados
  foram descartados**; a campanha foi reexecutada em série.

---

## 14. Frase de encerramento

> **A autoridade canônica da fixture `contratosui`/T27 na arquitetura P é
> `5c19f19af64e5043c4a7a0a51f2ca12b2c3914bf`, e a candidata
> `7db53fd69ef35a412a86684e2e4d6716f7d6d542` não deve ser composta.**
