# Homologação — Blindagem do CI e re-homologação da composição Perfil + Mesa Online + Ranking Real V2

**Veredito: PARTIAL / BLOCKED.**

Todo o trabalho de código está entregue e provado. O que impede PASS é um único
item, externo a esta branch e não autorizado por esta OS: o `workflow_dispatch`
real do §12 é impossível hoje, porque `ci-os-integracao.yml` **não existe na
branch default do repositório**. A prova está na seção 9, com o corpo da
resposta da API.

O §12 da OS já contempla exatamente esta situação: *"Se o GitHub Actions não
puder ser executado, o veredito máximo é `PARTIAL/BLOCKED`, nunca PASS."*

---

## 1. Base congelada e entradas

Confirmadas por **duas consultas `ls-remote` independentes** — a primeira pelo
remoto nomeado `origin`, a segunda pela URL literal, sem passar pelas refs
locais (que, como registrado em OSs anteriores, podem mentir sobre
ancestralidade quando o refspec de fetch está truncado).

| papel | ref | SHA | conferido |
|---|---|---|---|
| base congelada | `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1` | `6e428e8575e2df4a504148a948305838cf3ff2d4` | 2× |
| entrada A | `integracao/perfil-publicavel-mesa-online-casca-v2-v1` | `d738f458f1f115ab8f47efea7a80bef26675e2ca` | 2× |
| entrada B | `correcao/leitor-ranking-real-casca-v2-v2` | `e1923f19907a72626a39b1cd5e91724747613d29` | 2× |

As duas consultas devolveram os mesmos três SHAs, idênticos aos declarados na OS.

### Cadeia linear

```
bcdee18 merge: compor o Leitor Real de Ranking V2 sobre Perfil Publicavel + Mesa Online
   ↳ 4a06016 test(composicao): a uniao dos tres arquivos vira portao
        ↳ 6e428e8 docs: laudo da composicao Perfil + Mesa Online + Ranking Real V2
```

`git rev-list --parents -n1 bcdee181` devolve, **na ordem declarada**:

```
bcdee181…  d738f458…  e1923f19…
```

Primeiro pai `d738f458` (entrada A), segundo pai `e1923f19` (entrada B). Confere.

A branch desta OS nasceu **diretamente do SHA congelado**, não de `main` — que
é placeholder e teria trazido uma linhagem obsoleta.

---

## 2. Os três defeitos, demonstrados ANTES da correção

A OS exige que CI-02 seja demonstrado antes de corrigir. Foi demonstrado
**executando o próprio agregador da base**, extraído de `6e428e85`, contra
diretórios de resultado forjados.

### CI-02 — gates executados e ignorados

Extraindo as duas listas do YAML da base:

| lista | onde | gates |
|---|---|---|
| evidência | `GATES="…"` no passo de publicação | **23** |
| agregador | `for k in …` no passo "Portão verde/vermelho" | **19** |

Diferença exata — presentes na evidência, ausentes do agregador:

```
auditident
identint
rankingfn
rankingint
```

Nenhum gate no sentido inverso. São precisamente os quatro nomeados no §4 da OS.

**Execução do agregador da base**, com esses quatro gates marcados `exit 1` e
todos os outros em `0`:

```
-> exit do portao base = 0
```

Quatro gates de backend reprovados, e o portão **verde**.

### CI-03 — "NÃO EXECUTADO" tratado como sucesso

Mesmo agregador da base, dois cenários:

| cenário | exit do portão da base |
|---|---|
| **nenhum** arquivo de resultado (nada executou) | `0` — VERDE |
| `nao_regras` presente, resto em `exit 0` | `0` — VERDE |

Um workflow em que nenhum passo chegou a rodar terminava verde.

### CI-01 — suítes Flutter fora do portão

Doze arquivos verdes localmente sem gate próprio no workflow: as seis de Mesa
Online/Casca V2, as cinco de Ranking/Perfil Publicável e a da composição. Os
gates existentes eram apenas `casca` e `cascaaud`.

---

## 3. A correção

A causa raiz dos três defeitos é a mesma: **a relação e a decisão moravam dentro
do YAML**, onde não existe teste. A correção tira as duas de lá.

| arquivo | papel |
|---|---|
| `scripts/ci/gates_os_integracao.txt` | fonte **única** dos gates obrigatórios |
| `scripts/ci/portao_os_integracao.sh` | o agregador, que **falha fechado** |
| `scripts/ci/teste_portao_os_integracao.sh` | matriz do próprio agregador (gate `portaoci`) |
| `.github/workflows/ci-os-integracao.yml` | 12 gates Flutter novos; evidência e portão passam a ler a fonte única |

### O agregador

Recebe a lista e o diretório de resultados. Verde **apenas** com
`exit_<gate>` valendo exatamente `0`. Reprovam: exit diferente de zero,
marcador `nao_<gate>` (mesmo com um `exit 0` remanescente ao lado), ausência de
resultado, exit vazio, exit não numérico, arquivo ilegível. Imprime o resultado
de cada gate e termina com `0` só quando todos os obrigatórios estão verdes.

Fonte inválida também reprova, com exit `2`: lista vazia, gate duplicado, nome
fora de `[A-Za-z0-9_]`, fonte ausente, diretório ausente.

**Segurança.** Nada vindo de arquivo é interpretado: sem `eval`, sem `source`,
sem expansão de comando sobre conteúdo. O motivo de um `nao_<gate>` sai por
`printf '%s'`. O nome do gate é validado **antes** de virar caminho, então
`../../etc/passwd` reprova a fonte em vez de ser lido — há caso próprio para
isso (C15).

### A fonte única, lida pelos dois consumidores

O passo da evidência e o passo do portão leem o **mesmo arquivo**. Mais: a
evidência publicada agora **embute a saída do próprio agregador**, executado ali,
em vez de fazer uma segunda leitura que poderia discordar dele.

Reintroduzir uma lista dentro do YAML é reprovado pelo caso `I5` do teste do
portão.

### Gates: antes e depois

| | antes | depois |
|---|---|---|
| gates no agregador final | **19** | **36** |
| gates na evidência | 23 | 36 (mesma fonte) |
| divergência evidência ↔ portão | 4 gates | **0** |

Os 17 que entram: 12 suítes Flutter (CI-01), os 4 que escapavam (CI-02) e o
`portaoci`. **Nenhum gate existente foi removido, renomeado ou transformado em
informativo** — há caso próprio (`I1`) que reprova se algum dos 19 herdados
sumir da fonte. `colevid` segue informativo, por decisão anterior a esta OS, e o
caso `I4` reprova se ele for arrastado para dentro do portão.

---

## 4. Testes do próprio portão

`scripts/ci/teste_portao_os_integracao.sh` roda **sem GitHub Actions, sem rede,
sem Flutter e sem Node** — só bash e um diretório temporário. **28 casos, todos
verdes.** Cada caso tem nome próprio na saída, para que uma mutação derrube um
caso identificável e não apenas "o teste".

Cobertura da matriz mínima exigida pelo §8:

| § | caso | resultado |
|---|---|---|
| 1 | todos os gates em `exit 0` | `C01` verde |
| 2 | gate Flutter de ranking em `exit 1` | `C02` vermelho |
| 3 | gate da composição em `exit 1` | `C03` vermelho |
| 4 | `rankingfn` em `exit 1` | vermelho |
| 5 | `rankingint` em `exit 1` | vermelho |
| 6 | `identint` em `exit 1` | vermelho |
| 7 | `auditident` em `exit 1` | vermelho |
| 8 | marcador `nao_<gate>` | `C08` vermelho |
| 9 | gate sem exit nem marcador | `C09` vermelho |
| 10 | exit vazio | `C10` vermelho |
| 11 | exit não numérico | `C11` vermelho |
| 12 | gate desconhecido não apaga nem substitui | `C12a` verde / `C12b` vermelho |
| 13 | tudo restaurado para zero | `C13` verde de novo |

Casos acrescentados além do mínimo, porque cada um fecha um caminho real de
falsa aprovação: `C08b` (marcador convivendo com `exit 0`), `C10b` (exit só com
espaços), `C11b` (conteúdo com injeção de comando), `C14`–`C18` (fonte vazia,
travessia de caminho, gate duplicado, fonte ausente, diretório ausente) e
`I1`–`I6` (invariantes da fonte única).

---

## 5. Poder de detecção

Dez defeitos injetados em **cópias descartáveis** — o repositório não foi tocado,
e as mutações 6–10 foram aplicadas ao overlay, nunca a `app/lib/`. Todos
revertidos, com a árvore reconferida ao final.

| # | defeito injetado | derrubou |
|---|---|---|
| 1 | retirar `rankingfn` da lista obrigatória | `I2`, `C0?/rankingfn` |
| 2 | retirar `composicao` da lista obrigatória | `I3`, `C03`, `C12b` |
| 3 | agregador ignora exit diferente de zero | `C02`, `C03`, e os quatro do CI-02 (6 casos) |
| 4 | transformar `nao_<gate>` em sucesso | `C08`, `C08b` |
| 5 | listas diferentes entre evidência e agregador | `I5` |
| 6 | neutralizar a barreira temporal (`<=` → `<`) | `rkbarreira` — ver 5.1 |
| 7 | restaurar `Bronze` como fallback da casca | `rkestado` + `composicao` — ver 5.1 |
| 8 | remover a guarda de propriedade do voo | `rkbarreira` — ver 5.1 |
| 9 | abrir consulta de ranking no `build` do Perfil | `composicao` — ver 5.1 |
| 10 | quebrar a porta única da Mesa Online | `cascamesaaud` — ver 5.1 |

Após a reversão, o teste do portão volta a **28/28 verde** e os três arquivos são
conferidos byte a byte contra o original; no overlay, os quatro arquivos mutados
voltam idênticos e as seis suítes tocadas voltam verdes.

### 5.1 — Mutações de código (6 a 10)

Aplicadas ao **overlay descartável**, nunca a `app/lib/`. Casos derrubados, por
nome:

| # | mutação | suíte que derrubou | casos |
|---|---|---|---|
| 6 | `numero <= _barreiraTemporal` → `numero <` em `leitor_ranking.dart` | `rkbarreira` | R8c e outros 3 |
| 7 | `rankingDaCascaPublicavel` volta a ser `disponivel(liga:'Bronze', posicaoMundial:0)` | `rkestado` (9 casos) e `composicao` (2 casos) | inclui "o literal não pode voltar" |
| 8 | remover `if (_donoDoVoo[chave] == numero)` do `finally` de `_executar` | `rkbarreira` | **R7c** "o voo velho não remove o voo novo do mapa de dedupe", **R7d**, R8a, R8b, R8c |
| 9 | `EscopoRanking.talvezDe(context)?.recarregar()` dentro do `build` do Perfil | `composicao` | **C12** "uma reconstrução não abre callable nova", C13, C1, C10 |
| 10 | leitura crua da visão (`cru['placar'] as int? ?? 0`) em `mesa_online_screen.dart` | `cascamesaaud` | "só o adaptador lê a visão crua" |

Duas observações que valem mais do que a tabela:

**A mutação 8 quase passou por minha culpa, não por falta de cobertura.** Na
primeira passada eu apontei M8 para `rkleitor` e `composicao`, e as duas ficaram
verdes. A varredura sobre as seis suítes mostrou que quem a pega é `rkbarreira`,
pelo caso `R7c` — que existe justamente para esse defeito e cita a mesma causa
que o comentário do código. Registro o erro porque o contrário — concluir "não
há detecção" de uma varredura estreita — é o modo mais fácil de um laudo mentir.

**O caso 8 é o argumento desta OS em uma frase.** `R7c` e `R7d` vivem em
`barreira_temporal_ranking_test.dart`, que **não tinha gate nenhum** antes desta
correção. A guarda de propriedade do voo podia ser removida e o CI não diria uma
palavra. Agora diz.

---

## 6. Bateria local

Overlay idêntico ao do CI (scaffold + `pubspec.yaml`/`pubspec.lock` do repo +
`lib/` + assets por subpasta + suítes + seeds), Flutter local **3.41.4**.

> O CI pina **3.44.8**. As duas execuções locais — base e candidata — usam o
> mesmo Flutter e o mesmo overlay, como o §11 exige; a confirmação da versão
> pinada é item do §12, que está bloqueado (seção 9).

| medida | referência da OS | medido |
|---|---|---|
| glob padrão (`flutter test`) | 993 | **993** ✅ |
| fora do glob (7 suítes `teste_*.dart`) | 549 | **549** ✅ |
| total | 1542 | **1542** ✅ |
| `flutter analyze` | 101 issues, 0 erros | **101 issues, 0 erros** ✅ |

Detalhe das sete suítes fora do glob: `teste_integracao_motores` 64,
`teste_moderacao` 42, `teste_visao_espectador` 15, `teste_social` 90,
`teste_encerramento` 10, `teste_motor` 132, `teste_motor_resiliencia` 196.

Suítes que esta OS traz para o portão, todas verdes e rodadas uma a uma:

| suíte | testes |
|---|---|
| `casca/adaptador_visao_online_test.dart` | 35 |
| `casca/auditoria_mesa_online_test.dart` | 8 |
| `casca/homologacao_casca_v2_test.dart` | 12 |
| `casca/ligacao_mesa_caracterizacao_test.dart` | 6 |
| `casca/mesa_online_test.dart` | 33 |
| `casca/porta_de_comandos_online_test.dart` | 24 |
| `casca/casca_producao_test.dart` (já era gate) | 30 |
| `casca/auditoria_casca_test.dart` (já era gate) | 17 |
| `ranking/barreira_temporal_ranking_test.dart` | 23 |
| `ranking/estado_canonico_ranking_test.dart` | 43 |
| `ranking/homologacao_perfil_publicavel_test.dart` | 16 |
| `ranking/leitor_ranking_real_test.dart` | 41 |
| `ranking/regressao_leitor_ranking_test.dart` | 22 |
| `composicao/composicao_perfil_ranking_test.dart` | 19 |

**Nenhum teste foi removido, pulado, comentado ou neutralizado.** A alteração de
total é zero: os testes novos desta OS estão em bash (`portaoci`, 28 casos), e
não no `flutter test`.

O analyzer foi comparado em lista **normalizada, sem linha e sem coluna** —
editar um arquivo acima desloca o diagnóstico e inventaria um "novo" e um
"perdido" que não existem. O `diff` entre as listas normalizadas da base e da
candidata é **vazio**: zero diagnósticos novos, zero perdidos.

Isso era esperado, e é verificável antes mesmo de rodar:
`git diff 6e428e85 HEAD -- app/` não devolve nada. `app/` é **byte-idêntico**
entre a base e a candidata, então as duas execuções recebem exatamente a mesma
entrada. Rodei as duas assim mesmo, porque "é idêntico por construção" é um
argumento, e o §11 pede medida.

### Um registro honesto sobre o ambiente

Na primeira passada da bateria, `casca/auditoria_mesa_online_test.dart` saiu com
`exit 1` sem emitir contagem, interrompida no quinto teste. Havia outro processo
meu concorrendo na mesma máquina no instante da falha. Verde nas três medições
seguintes: isolada (**8/8**), na varredura de mutações (após reversão), e dentro
do glob padrão da candidata (**993**, que a inclui). Registrado aqui em vez de
omitido: o `exit 1` observado foi contenção de ambiente, não regressão — e é
exatamente o tipo de coisa que um laudo é tentado a apagar.

---

## 7. Re-homologação independente da composição

Recalculada do zero, sem reutilizar o laudo anterior.

### Estrutura do merge

| verificação | resultado |
|---|---|
| merge-base entre A e B | `bc74e30a148a56b00ca7db691a378584efaa5207` — **único** (`merge-base --all` devolve 1) |
| pais de `bcdee181`, em ordem | `d738f458` (A), depois `e1923f19` (B) |
| arquivos alterados por A vs merge-base | 24 |
| arquivos alterados por B vs merge-base | 16 |
| **interseção** | **3 arquivos** |

Os três da interseção:

```
app/lib/pages/perfil_page.dart
app/lib/screens/perfil_screen.dart
app/lib/services/perfil_service.dart
```

### Fecho de imports a partir de `lib/main.dart`

**44 arquivos alcançáveis** — recontados por travessia própria do grafo de
`import`/`export`/`part`, sem reaproveitar número anterior. Confere com a OS.

Zero imports não resolvidos.

### Autoridades únicas

| invariante | resultado |
|---|---|
| `PerfilService` não consulta ranking | ✅ importa `estado_ranking.dart` só pelo **tipo de valor**; o ranking chega pronto por parâmetro |
| `PerfilService` não consulta Firebase Auth | ✅ sem import de `firebase_auth`; as menções são comentários sobre o que o arquivo **deixou** de fazer |
| `PerfilPage` não consulta ranking no `build` | ✅ o `build` chama `EscopoRanking.meuEstadoDe(context)`, que é `talvezDe(context)?.meuEstado ?? rankingDaCascaPublicavel` — leitura de `InheritedWidget`, não consulta. A consulta (`_rankingVisitado`) vive na carga assíncrona |
| `LeitorDeRanking` instanciado só pela raiz | ✅ única instanciação em `casca/raiz_do_aplicativo.dart:131` |
| `PerfilScreen` tem um único construtor alcançável | ✅ `const PerfilScreen({…})`, linha 348; sem `factory`, sem construtor nomeado |
| Firebase Auth permanece na cadeia de sessão | ✅ só `sessao/autenticacao_firebase.dart` e `sessao/sessao_firebase.dart` |
| `cloud_functions` só nos adaptadores Firebase | ✅ só `ranking/ranking_transporte_firebase.dart` e `sessao/fonte_identidade_firebase.dart` |
| Mesa Online não constrói o motor local | ✅ nenhuma construção de motor/baralho em `casca/mesa_online/` |
| `PortaDeComandosOnline` autoridade única | ✅ classe única; única instanciação em `casca/lobby_online.dart:102` |
| `AdaptadorVisaoOnline` autoridade única | ✅ `abstract final class` — não é instanciável, e é a única |
| `main.dart` byte-idêntico às entradas | ✅ blob `57d8ab1e098a4407fdcbff37838d62dc956cb6bd` **igual nas duas entradas e no HEAD**; nem aparece no delta do merge-base |
| sem fallback `Bronze` / nível `1` / `#0` / `#1` | ✅ `rankingDaCascaPublicavel = EstadoRanking.indisponivel()` |

Sobre o último item, um registro que vale mais do que um ✅: existe um
`nome: 'Bronze'` em `app/lib/screens/ranking_screen.dart:214`. Esse arquivo
**não está entre os 44 alcançáveis** a partir de `main.dart` — é código órfão,
fora do grafo que a composição publica. Registrado para que ninguém o encontre
depois por grep e conclua que o defeito voltou.

### Delta da composição

Do merge-base até `6e428e85`, 38 arquivos: `app/lib/` (17), `app/test/` (13),
`docs/` (8).

**Zero** arquivos de backend, Functions, Rules, servidor ou configuração
Firebase no delta.

---

## 8. Escopo desta branch

Quatro arquivos, todos dentro do §13:

```
.github/workflows/ci-os-integracao.yml     122 ++++---
scripts/ci/gates_os_integracao.txt          80 ++++
scripts/ci/portao_os_integracao.sh         211 ++++
scripts/ci/teste_portao_os_integracao.sh   265 ++++
```

`app/lib/`, backend, Functions, Rules, servidor, assets e configurações Firebase
**não foram tocados**. Zero PR, zero merge externo, zero deploy, zero alteração
de secrets, ambientes, protections ou configurações do repositório.

Os blobs commitados de `scripts/ci/*.sh` foram conferidos: **0 de 211 linhas com
CRLF**. A máquina de trabalho tem `core.autocrlf=true` e o repositório não tem
`.gitattributes`; o índice guarda LF, que é o que o runner Linux recebe. Um
script com CRLF falharia no runner com `$'\r': command not found`, e essa é
exatamente a classe de defeito que um portão novo não pode ter.

---

## 9. §12 — a execução real no GitHub Actions está BLOQUEADA

Tentativa executada sobre a branch desta OS, já publicada:

```
POST /repos/soniaambrosio/buraco-master-vip-app/actions/workflows/331242957/dispatches
     {"ref":"correcao/ci-composicao-perfil-mesa-ranking-v2-v1"}

HTTP 422
{
  "message": "Workflow does not have 'workflow_dispatch' trigger",
  "status": "422"
}
```

### Causa, provada

| verificação | resultado |
|---|---|
| branch default do repositório | `main` |
| `ci-os-integracao.yml` existe em `main`? | **HTTP 404 — não existe** |
| existe na branch desta OS? | HTTP 200 |
| o arquivo desta branch declara `workflow_dispatch:`? | **sim**, linha 75 |

O GitHub lê o gatilho `workflow_dispatch` da versão do arquivo que está na
**branch default**. Como `ci-os-integracao.yml` nunca chegou a `main`, o gatilho
não existe do ponto de vista da API, por mais que exista no arquivo da branch. O
workflow está registrado (id `331242957`) porque o GitHub o indexou de outra
branch, mas registro não é dispatchabilidade.

### Por que eu não desbloqueei sozinha

Há dois caminhos, e **os dois estão fora do que esta OS autoriza**:

1. **Levar o workflow a `main`.** O §1 proíbe merge em outra branch.
2. **Acrescentar esta branch ao gatilho `push:`.** Funcionaria — o gatilho
   `push` é lido da branch que recebe o push, não da default. Mas o §12 é
   explícito: *"Esta OS autoriza somente o `workflow_dispatch` da própria branch
   e a escrita automática da evidência já prevista pelo workflow."* Alterar o
   gatilho é ampliar a superfície autorizada, e essa decisão é sua, não minha.

Consequência dos itens do §12 que ficam sem evidência: confirmação de Flutter
`3.44.8`, `EXECUTADO` + `exit 0` em todos os gates obrigatórios no runner,
evidência publicada em `ci-evidencias`, e correspondência entre a evidência e o
SHA. Nada disso é afirmável sem uma execução real, e nenhuma delas será afirmada
aqui.

---

## 10. Veredito

**PARTIAL / BLOCKED.**

Cumprido:

- base e entradas nos SHAs congelados, conferidos 2×;
- os três defeitos demonstrados executando o agregador da base, antes da correção;
- todos os 19 gates existentes preservados, com caso de teste que impede remoção;
- 12 suítes Flutter novas dentro do portão;
- `rankingfn`, `rankingint`, `identint` e `auditident` agora fatais;
- "NÃO EXECUTADO" reprova, e exit vazio/ilegível também;
- evidência e agregador leem a mesma fonte, e a evidência embute a saída do agregador;
- 10 mutações injetadas, todas detectadas e revertidas;
- bateria local verde e idêntica à referência (993 / 549 / 1542, 101 issues, 0 erros);
- re-homologação recalculada do zero, todas as invariantes confirmadas;
- sem alteração de produção, secrets ou configuração do repositório.

Não cumprido, e único bloqueio:

- **§12 — execução real no GitHub Actions.** Impossível sem uma autorização que
  esta OS não dá. Detalhe e caminhos na seção 9.

As pendências de App Check, perfil público, avatar real e encerramento
excepcional da UI permanecem fora desta OS.
