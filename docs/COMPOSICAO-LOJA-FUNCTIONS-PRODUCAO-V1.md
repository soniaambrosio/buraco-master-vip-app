# Composição canônica — Loja/Casca V2 ↔ Functions de produção V1

**Veredito: PASS.** Portão real VERDE em **50/50** gates obrigatórios, rodado
pelo agregador do repositório (`scripts/ci/portao_os_integracao.sh`) sobre a
fonte única e sobre resultados reais desta árvore.

Esta folha **não** é declarada raiz integrada final do aplicativo. Sem deploy,
sem PR, sem merge em `main`.

---

## 1. As duas entradas, e a topologia

| lado | branch | SHA completo |
|---|---|---|
| A — Loja/Casca V2 | `integracao/loja-casca-v2-v1` | `44883788c5808b3ea7a48966ac181f4e426e9995` |
| B — Functions canônicas | `integracao/functions-producao-canonica-v1` | `8e89ea795c829d98a3ceda66fa5b9c743adac5f0` |

`merge-base(A, B) = 6340573c1a9c9b10881c3555673ebb5279364ecf`
(«fix(regras): PRF-01 media negacao universal, e a colecao ganhou autoridade»).

Nenhuma das duas é ancestral da outra. A topologia é um **Y curto**: as duas
folhas nasceram do mesmo ponto, a Loja levou **um** commit e as Functions
levaram **cinco**.

```
6340573 (merge-base)
├── 4488378  a Loja publicavel nasce da Casca V2               [folha A]
└── d440e30 → 3784d45 → 7e74bcf → b6676bf → 8e89ea7            [folha B]
                                                  ↘        ↙
                                            cb4d2d8 (merge, 2 pais)
                                                     ↓
                                            817fdaa → 393f82e (HEAD)
```

**Branch efetiva:** `integracao/loja-functions-producao-canonica-v1`
**HEAD final:** `393f82e1ac9c642e624e78af943775854a26ab51`

### Prova de ancestralidade

```
$ git rev-list --parents -n1 cb4d2d8
cb4d2d8… 44883788c5808b3ea7a48966ac181f4e426e9995 8e89ea795c829d98a3ceda66fa5b9c743adac5f0

$ git merge-base --is-ancestor 4488378 HEAD  →  0
$ git merge-base --is-ancestor 8e89ea7 HEAD  →  0
```

Os dois SHAs são **pais diretos** do commit de merge, e não ancestrais remotos:
a composição aconteceu no grafo, e não por cópia de texto.

---

## 2. O que a união é, medida byte a byte

A sobreposição textual entre as duas folhas é de **exatamente dois arquivos**, e
os dois são a fonte única do portão:

* `scripts/ci/gates_os_integracao.txt`
* `.github/workflows/ci-os-integracao.yml`

Os dois lados os editaram em **hunks disjuntos** — a Loja no bloco 3b, as
Functions nos blocos 7, 10 e 11 —, e o merge foi limpo. **Merge limpo não é
aprovação**, então a igualdade foi medida:

```
diff(A → merge) ≡ diff(merge-base → B)     linha por linha, IDÊNTICO
diff(B → merge) ≡ diff(merge-base → A)     linha por linha, IDÊNTICO
```

Ou seja: o merge é a **união exata**. Nenhuma linha foi acrescentada, perdida ou
alterada por ele. Consequência verificada: no commit de merge, **só aqueles dois
arquivos** diferem de *ambas* as folhas; todo o resto da árvore é byte a byte
igual a uma das duas.

Nenhum dos dois lados toca `build.yml`, e os commits desta OS também não —
**a OS 1.1 (Pipeline/Branding) não foi disputada**.

### Diffstat

| comparação | arquivos | + | − |
|---|---|---|---|
| Loja (A) → HEAD | 19 | 3.417 | 184 |
| Functions (B) → HEAD | 16 | 2.377 | 122 |
| merge → HEAD (o que esta OS acrescentou) | 5 | 939 | 0 |

---

## 3. Autoridades preservadas

Nenhuma responsabilidade ganhou um segundo dono. O que a composição podia
quebrar, e não quebrou:

| responsabilidade | autoridade única, na árvore composta |
|---|---|
| sessão / autenticação | `app/lib/sessao/sessao_firebase.dart` — **o único** assinante de `authStateChanges`/`idTokenChanges` em todo o `app/lib` (CL-09) |
| Perfil público | `functions-social` (`verPerfilPublico`, `obterMinhaIdentidade`) |
| Ranking | `functions-ranking` + `EstadoRanking` no cliente; sem fallback embutido |
| inventário / cosméticos | `functions-conta` (`src/inventario.ts`) e a codebase `colecoes` |
| entitlement / VIP | `functions-billing` — **só ele** escreve `playerEntitlements` (PN-06) |
| Billing | `functions-billing`, 9 exports, superfície declarada uma vez em `test/apoio/superficie.js` |
| mesas | `functions-mesas` |
| moderação / chat | `functions-moderacao` |
| estatísticas | `functions-ranking` (`estatisticas.test.js`) |
| credencial do motor | `functions/src/autoridade.ts`, com `checkRevoked` (PN-01) |
| exclusão de conta | `functions-conta` (`excluirMinhaConta`), matriz de retenção em `src/inventario.ts` |

A Loja, ao virar alcançável, **não** trouxe leitura de identidade própria:
`app/lib/casca/loja_de_producao.dart` não menciona `FirebaseAuth.instance`.

---

## 4. Codebases e exports

As **nove** codebases da folha canônica atravessaram inteiras — manifesto e
disco conferem, e cada uma tem passo próprio no workflow (PN-07, PN-13, CL-03):

`colecoes` · `billing` · `torneios` · `economia` · `moderacao` · `ranking` ·
`social` · `conta` · `mesas`

Superfície implantada congelada em **63 exports** (CL-04, conjunto fechado por
codebase — ausência e sobra reprovam igualmente):

| codebase | exports |
|---|---|
| `firebase/functions` | 3 |
| `functions-billing` | 9 |
| `functions` | 7 |
| `functions-economia` | 3 |
| `functions-moderacao` | 9 |
| `functions-ranking` | 11 |
| `functions-social` | 15 |
| `functions-conta` | 2 |
| `functions-mesas` | 4 |

---

## 5. O gate da composição

`ferramentas/composicao/loja_functions.test.js` — gate **`composloja`**, 34
casos. É a costura de um nível acima de `composneg`: aquele guarda a união das
nove codebases; este guarda a árvore em que a Loja publicável e as Functions
canônicas passam a coexistir.

| caso | o que reprova |
|---|---|
| CL-01 | a árvore que só *parece* composta — exige os dois SHAs como ancestrais, e reprova em histórico raso |
| CL-02 | um lado entrando só como documento |
| CL-03 | uma codebase perdida na união |
| CL-04 | um export sumindo na união |
| CL-05 | um lado perdendo os gates na união da fonte única (quebra **nos dois sentidos**) |
| CL-06 | gate da Loja declarado e sem suíte por trás |
| CL-07 | **RANKING-01** — fábrica de ranking fictício de volta |
| CL-08 | a prova de `const RankingPage()` sem fonte fora do portão |
| CL-09 | um segundo dono de sessão entrando com a Loja |
| CL-10 | `playerCourtesyPass` sobrevivendo à exclusão de conta |
| CL-11 | dado de maquete no caminho publicável da Loja |

**O critério central: ele fica vermelho se qualquer um dos dois lados sumir.**
Provado, e não afirmado — ver §7.

### Dois defeitos que só a união produziu

**1. CI-01 outra vez, e no pior lugar.** O único caso que monta
`const RankingPage()` **sem fonte** — que é a construção REAL de
`hall_page.dart` e de `perfil_page.dart` — morava em
`app/test/ranking_page_test.dart`, e **passo nenhum do workflow o rodava**. A
suíte que guarda a invariante RANKING-01 podia ficar vermelha sem ninguém
saber. Agora é o gate **`rkpagina`** (16 casos, verdes).

**2. O checkout era raso.** `actions/checkout@v4` sem `fetch-depth` não deixa
provar ancestralidade: num clone raso o `merge-base` responde «não é ancestral»
para qualquer commit. O passo passou a `fetch-depth: 0`, e CL-01 **reprova** em
histórico raso em vez de ficar verde onde não pode medir.

Ambos entraram também no teste do próprio portão, como I8a/I8b/I8c: o agregador
reprova se um dos dois lados sumir da fonte única, ou se o produtor da
composição sair do YAML.

---

## 6. RANKING-01 — a invariante, e a prova comportamental

`RankingVM.mock()` **não existe** em nenhuma das duas folhas nem na composição.
As duas únicas ocorrências do nome estão em **comentário**, documentando a
remoção — e por isso toda leitura de CL-07 passa por `arvore.js`, que remove
comentários antes de medir. Buscar sobre o texto cru acharia a lápide e
reprovaria código correto.

Provas, nesta ordem:

1. **Estrutural (CL-07).** Varredura de todo o `app/lib`, sem comentário, por
   `<Tipo com "Ranking">.mock(` e por `factory <…Ranking…>.mock` — conjunto
   vazio, com âncora positiva de que `class RankingVM` continua lá para ser
   medida. Se a classe sumir, o caso reprova em vez de passar por ausência.
2. **A fonte do estado vazio existe.** `class RankingSemFonte` em
   `app/lib/services/ranking_service.dart` — é ela que responde quando não há
   ranking publicado. Sem ela, o «estado vazio» não teria produtor.
3. **Comportamental (`rkpagina`).** O caso
   *«sem fonte oficial (caminho de produção) — a tela diz que não há ranking
   publicado, sem inventar nome»* monta `const RankingPage()` e exige
   `RankingEstado.erro`, a frase «O ranking oficial ainda não está sendo
   publicado.», `findsNothing` para o selo `VOCÊ` e `findsNothing` para o nome
   de maquete. **16/16 verdes.**
4. **Erro de leitura não cai em ficção.** `rkleitor` (41), `rkbarreira` (23),
   `rkestado` (43), `rkregressao` (22) e `rkperfil` (16), todas verdes.

Nenhum nome, liga, posição ou pontuação falsa pode aparecer, e a ausência de
fonte é estado indisponível — não maquete.

---

## 7. Provas negativas

### 7.1 Campanha de mutação — `ferramentas/composicao/mutacoes_loja.js`

Cada mutação **introduz na árvore real** a remoção que a OS manda provar
removível, e exige que o caso nominal reprove. Restaura sempre.

```
BASE: 34/34 passam, 0 falham

ML-01  DETECTADA  espera CL-03 | uma codebase some do manifesto
ML-02  DETECTADA  espera CL-04 | um export some da superficie implantada
ML-03  DETECTADA  espera CL-05 | o gate de proveniencia sai da fonte unica
ML-04  DETECTADA  espera CL-05 | o gate da Loja sai da fonte unica
ML-05  DETECTADA  espera CL-02 | o gerador de proveniencia vira casca sem superficie
ML-06  DETECTADA  espera CL-09 | a Loja assina o estado de autenticacao por conta propria
ML-07  DETECTADA  espera CL-07 | a fabrica de ranking de maquete volta ao app
ML-08  DETECTADA  espera CL-07 | o estado vazio do Ranking perde a fonte que o produz
ML-09  DETECTADA  espera CL-10 | o passe de cortesia deixa de ser apagado
ML-10  DETECTADA  espera CL-08 | a suite de `const RankingPage()` perde o produtor
ML-11  DETECTADA  espera CL-11 | dado de maquete entra no caminho publicavel

RESTAURADO: 34/34 passam, 0 falham
sobreviventes: 0 | fora do alvo: 0 | instrumentos quebrados: 0
```

**A primeira rodada teve um sobrevivente, e ele vale mais que os dez
detectados.** CL-10 media `playerCourtesyPass` por **prefixo**: renomear a
coleção para `playerCourtesyPassDESLIGADO` deixava a prova verde sobre uma
entrada que já apontava para outro lugar. Agora a matriz é lida por caminho
**entre aspas fechadas** (`"playerCourtesyPass/{uid}"` e
`"playerCourtesyPass/{uid}/cycles/{cicloId}"`), nas duas entradas, e o `alcance`
do executor é conferido pelo nome exato da coleção — porque entrada com caminho
certo e alcance errado não apaga nada.

### 7.2 A nona remoção: a ancestralidade

Não é edição de arquivo. Prova-se rodando **a mesma suíte** a partir de uma
árvore que descende de UMA folha só:

```
$ git worktree add --detach /c/anc-so-loja 4488378
$ node --test ferramentas/composicao/loja_functions.test.js
  ✖ CL-01  ✖ CL-02  ✖ CL-05  ✖ CL-08          →  26 pass, 8 fail

$ git worktree add --detach /c/anc-so-functions 8e89ea7
$ node --test ferramentas/composicao/loja_functions.test.js
  ✖ CL-01  ✖ CL-02  ✖ CL-05  ✖ CL-06  ✖ CL-08  ✖ CL-09  ✖ CL-11
                                                  →  24 pass, 10 fail
```

CL-01 cai nos dois. **O gate reprova quando metade da composição some.** Os dois
worktrees temporários foram removidos; a árvore final está limpa.

---

## 8. `playerCourtesyPass = APAGAR`

Duas entradas na matriz de retenção de `functions-conta/src/inventario.ts`, as
duas `CLASSE.APAGAR`:

* `ranking.passeCortesiaCiclos` → `playerCourtesyPass/{uid}/cycles/{cicloId}`
  (subcoleção do dono, esvaziada primeiro)
* `ranking.passeCortesia` → `playerCourtesyPass/{uid}` (documento de controle,
  apagado depois — apagar a raiz antes deixaria `cycles` viva e órfã)

**Prova comportamental**, no gate `contaemu`, contra Firestore e Auth reais:
*«jogador com passe de cortesia — o controle e o histórico de ciclos somem, e o
do terceiro fica»*. É o único lugar onde a etapa executa de verdade, e ele passa
junto com os outros 36 casos da exclusão.

---

## 9. Portão real — 50/50

`bash scripts/ci/portao_os_integracao.sh scripts/ci/gates_os_integracao.txt <resultados>`

```
obrigatórios: 50 | verdes: 50 | fora da fonte: 0
resultado: VERDE
```

### Flutter (27 suítes, `flutter analyze` exit 0, 0 erros)

| gate | casos | | gate | casos |
|---|---|---|---|---|
| `motor` | 458 | | `cascaligacao` | 6 |
| `resil` | 196 | | `cascamesa` | 33 |
| `encerr` | 10 | | `cascaporta` | 24 |
| `torneios` | 80 | | **`cascaloja`** | **16** |
| `mtorneios` | 179 | | `rkbarreira` | 23 |
| `integr` | 64 | | `rkestado` | 43 |
| `colarte` | 14 | | `rkperfil` | 16 |
| `colfire` | 18 | | `rkleitor` | 41 |
| `colkit` | 81 | | `rkregressao` | 22 |
| `social` | 90 | | **`rkpagina`** | **16** |
| `casca` | 30 | | `composicao` | 19 |
| `cascaaud` | 17 | | `chatdom` | 60 |
| `cascavisao` | 35 | | | |
| `cascamesaaud` | 8 | | | |
| `cascav2` | 12 | | | |

### Functions — puras e typecheck

| gate | resultado |
|---|---|
| `billing` | 410/410 |
| `torneiosfn` | `tsc --noEmit` exit 0 |
| `rankingfn` | 458/458 |
| `contafn` | 81/81 |
| `mesasfn` | 142/142 |
| `economiafn` | 63/63 |
| `moderacaofn` | 51/51 |
| `socialfn` | 55/55 |
| `socialdom` | bundle Dart→JS, exit 0 |

### Functions — contra o Emulator Suite

| gate | resultado |
|---|---|
| `colecoesemu` (Rules + coleções) | 244/244 |
| `socialemu` | 113/113 |
| `moderacaoemu` | 45/45, `class=OK cleanup=ok ports=released` |
| `chatemu` | 42/42 |
| `rankingint` | 27/27 |
| `passeint` | 18/18 |
| `identint` | 14/14 |
| `contaemu` | 37/37 |
| `auditident` | dry-run read-only, exit 0 |

### Composição e portão

| gate | resultado |
|---|---|
| `portaoci` | 34/34 (31 anteriores + I8a/I8b/I8c) |
| `proveni` | 13/13 — 9 codebases carimbadas, `predeploy` intransponível |
| `composneg` | 20/20 (PN-01…PN-15) |
| **`composloja`** | **34/34** |

---

## 10. Bancada

O drive `F:` é exFAT: `npm install` é proibitivo e não há junction. As Functions
rodaram num worktree espelho em `C:` (NTFS) no **mesmo SHA**, com `node_modules`
apontado por junction; o Flutter rodou num overlay montado exatamente como o
workflow monta (`flutter create` + `pubspec` do repo + `lib`/`assets`/`test`).

Duas armadilhas pagas, e vale registrá-las:

* **Colisão de overlay.** A primeira rodada de `flutter test` sobreviveu ao
  timeout da ferramenta e passou a rodar **junto** com a segunda no mesmo
  overlay. Os resultados foram descartados inteiros, os processos `dart`/
  `flutter_tester` órfãos foram mortos, e a matriz foi refeita numa **passada
  sequencial única** — que é a que este relatório reporta.
* **`chatemu` ≠ `moderacaoemu`.** São suítes diferentes com comandos
  diferentes (`integracao.chat.emulador.test.js` contra
  `npm run emulador:moderacao`). Rodar uma e etiquetar como a outra teria
  deixado um obrigatório sem execução, com o portão verde.

Versão local do Flutter: 3.41.4 (o CI pina 3.44.8). Java 21 pelo JBR do Android
Studio.

---

## 11. O que esta folha NÃO é

* **não** é a raiz integrada final do aplicativo;
* **não** houve deploy de Functions, escrita em produção nem acesso à Play
  Console;
* **não** há PR aberto nem merge em `main`;
* `build.yml` não foi tocado — a OS 1.1 segue com o assunto inteiro.
