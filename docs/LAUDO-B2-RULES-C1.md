# LAUDO B2-RULES-C1 — Correção dirigida das Firestore Rules

**OS:** PRÉ-HOM-BMV-RC1-B2-RULES-C1
**Projeto:** Buraco Master VIP · **Família:** Pré-Homologação BMV
**Natureza:** correção de Rules — **sem deploy**
**Base autorizada:** `rc/bmv-rc1-prehom` @ `603f0e1fce21787ac003a1b5c5cfd957e3984d77`
**Desfecho:** **PASS PARA AUDITORIA** — implementação concluída, pronta para auditoria independente.

> O executor desta OS **não homologa o próprio material**. Este laudo é matéria
> para a auditoria da §23, não um veredito sobre si mesmo.

---

## 1. Gate Zero — identidade

| Item | Valor |
|---|---|
| Repositório | `F:/Projetos/buraco-master-vip-app/buraco-master-vip-app/os40-r8-rehomologacao-3128d5` (worktree) |
| Remoto | `https://github.com/soniaambrosio/buraco-master-vip-app.git` |
| Base exigida | `603f0e1fce21787ac003a1b5c5cfd957e3984d77` |
| Base encontrada | `603f0e1fce21787ac003a1b5c5cfd957e3984d77` — **confere** |
| `rc/bmv-rc1-prehom` | `603f0e1…` (local) = `origin/rc/bmv-rc1-prehom` |
| Tree da base | `3c2bb86d93dfdb72abe5d709a5fc491148291d53` |
| Branch de trabalho | `correcao/bmv-rc1-b2-rules-c1-v1`, criada **de** `603f0e1` |
| Estado Git na entrada | árvore limpa, staging vazio, nenhuma operação pendente |

**Nota de procedimento.** O HEAD nativo deste worktree era `fb9edb5`, e **não** a
base. A branch de trabalho foi criada explicitamente a partir do SHA exigido; a
base `rc/bmv-rc1-prehom` estava (e continua) ocupada por outro worktree
(`F:/rc1`), que não foi tocado.

### 1.1 Hashes de entrada (SHA-256)

| Arquivo | Antes |
|---|---|
| `firebase/firestore.rules` | `178750a6ca01f9e3601d7c1e490499955b08fcc27d6138d22b5dc2181b920e99` |
| `firebase/testes/seguranca.test.js` | `3e4913aa5f572960e2b3f31e744b4885a44d78ac3329249c407c12922b352573` |
| `firebase/testes/chat.test.js` | `4f6462111d3b89b0f664cd6b3916d2601ca8808334891d49c2679807617910de` |
| `firebase/firestore.indexes.json` | *(não tocado)* |

### 1.2 Hashes de saída (SHA-256)

| Arquivo | Depois |
|---|---|
| `firebase/firestore.rules` | `7f078f2d10f8f181a86e8634499fd6a140cdd1011e827a3533a751496a3313a2` |
| `firebase/testes/seguranca.test.js` | `22801fa62f534e8da0b2efcdf8aa3dc28c5693fc9f4876defedfa35e5decb823` |
| `firebase/testes/chat.test.js` | `b3b0657abe478998699ac5d4243b6d7ca638f10c8ba6161bf5bcd303379730c8` |

### 1.3 ARMADILHA DE CONFERÊNCIA — os hashes acima são da CÓPIA DE TRABALHO

Este repositório tem `core.autocrlf=true` e **nenhum `.gitattributes`**. Os
arquivos vivem em **UTF-8 com CRLF** no disco e são armazenados com **LF** no
banco de objetos. Um auditor que rodar `git show HEAD:<arquivo> | sha256sum` vai
obter um número **diferente** dos das §1.1/§1.2 — e isso **não é divergência**.

| Arquivo | SHA-256 do conteúdo do blob (LF) |
|---|---|
| `firebase/firestore.rules` (base) | `7de170f27884f5275d5fdd6e2ae918798b21da8b1b17e7639e99822b63e19152` |
| `firebase/firestore.rules` (corrigido) | `98b78976f2e237ea4861bb00100e046670c17231333adc65d31e2951295ad892` |
| `firebase/testes/seguranca.test.js` (corrigido) | `1f75aab8742aeffd0f454d666da767962896528d94d7017ee0868c4b9172eebe` |
| `firebase/testes/chat.test.js` (corrigido) | `d30163c45076bbcb6cfcdb70f62c58e7ed8ad1e7d506910b14e5c7c0140634e1` |

**Blobs Git** (`git ls-tree -r HEAD`):

| Arquivo | blob |
|---|---|
| `firebase/firestore.rules` | `d06f47a42c404d804f688c50c4cf9b38acb731b3` |
| `firebase/testes/seguranca.test.js` | `0b50e1d7d2c51d249453b3dcdb35006f5f747b40` |
| `firebase/testes/chat.test.js` | `5b29b723a1e725c99cfa58915f2ce76701b48c12` |
| `docs/LAUDO-B2-RULES-C1.md` | `782fdb8925e0a53200a284be4b819096ee40f944` |

**A base se comporta identicamente** — blob LF, disco CRLF —, o que confirma que
o comportamento é pré-existente do repositório e não foi introduzido aqui. O
round-trip foi **verificado nos três arquivos**: `blob(LF) → CRLF` reproduz o
arquivo do disco byte a byte. Nenhum CR solto, nenhum LF solto (o aplicador de
patch recusava as duas condições).

---

## 2. O resultado em uma linha

**A mudança semântica INTEIRA das Rules é uma única linha:**

```diff
+      allow read, write: if false;
```

Todo o resto do diff de `firestore.rules` (158 linhas) é **comentário**: as
decisões dos três bloqueadores escritas onde o próximo leitor vai procurá-las.
A verificação é reproduzível:

```bash
git diff -U0 firebase/firestore.rules | grep -E "^[+-]" \
  | grep -vE "^(\+\+\+|---)" | grep -vE "^[+-]\s*//" | grep -vE "^[+-]\s*$"
```

O que carrega peso de execução são os **38 casos novos de emulador**, não os
comentários.

---

## 3. Bloqueador R1 — `users/{uid}`

### 3.1 O que foi medido (e não assumido)

A §4 da OS proíbe assumir como correta a solução sugerida no laudo anterior. As
seis perguntas da §6 foram respondidas por varredura, não por leitura do laudo:

| Pergunta da §6 | Medida | Resultado |
|---|---|---|
| O app atual ainda lê `users/{uid}`? | Enumeração de **toda** a superfície Firestore de `app/lib/` | **NÃO.** São quatro caminhos: `users/{uid}/inventory`, `config/featureFlags`, `campaigns/{id}`(+`/eligible/{uid}`), `playerEntitlements/{uid}`. Só quatro arquivos Dart importam `cloud_firestore`. |
| Alguma Function lê ou grava `users/{uid}`? | Varredura de `functions*/src/**.ts` por `users` | **NÃO grava.** Todo uso é `users/{uid}/<subcoleção>`; o documento raiz só aparece como **pai de caminho**. A única operação sobre ele é `db().collection("users").doc(ctx.uid).delete()` em `functions-conta/src/executor.ts:632`, pelo Admin SDK, que ignora estas regras. |
| Dados legados ainda existem nesse caminho? | Censo de produção já publicado na árvore | **SIM, um documento:** `users/teste_user`, com `displayName` e nada mais (`docs/DIAGNOSTICO-POPULACAO-LEGADA-VIP.md` §14.B.1). |
| `usuarios/{uid}` substituiu o documento legado? | Cabeçalho de `firestore.rules` + matriz de retenção | **NÃO — e não deve.** São namespaces **diferentes e simultâneos**: `usuarios/` é exclusivo do Billing, e `functions-conta/src/inventario.ts:685` registra que varrer só `users/` deixaria `usuarios/{uid}` inteiro para trás. Não há dual-write nem espelhamento. |
| Preservar leitura do dono é necessário? | Consequência das duas primeiras linhas | **NÃO.** Não há leitor. |
| Preservar escrita seria perigoso? | Análise de campo | **SIM.** Ver 3.2. |

**A prova que decide o caso já estava escrita na árvore**, e é de outro autor:
`functions-conta/src/inventario.ts:764–770`, item `conta.usersRaiz` —
*"O documento raiz. Nenhuma Function deste repositório o escreve hoje — ele
existe como PAI das oito subcoleções."*

### 3.2 A decisão

**`users/{uid}` é NEGADO A TODOS, e a negação passa a ser EXPLÍCITA.**

A regra antiga de produção (`allow read, write: if owner`) **não é restaurada**.
A §6 da OS proíbe copiá-la, e a proibição se sustenta por medida:

* **Devolver `write` seria abrir campo livre.** Sem produtor, não existe lista de
  campos legítimos a que prender um `hasOnly`. O dono gravaria **qualquer** chave
  num documento que oito subcoleções usam como pai e que `functions-moderacao` e
  `functions-social` percorrem. É o oposto do que `usuarios/{uid}` faz ao lado,
  onde cada campo de servidor está nomeado e fechado.
* **Devolver só `read` também não se sustenta.** Leitura sem leitor não serve a
  ninguém, e documento legível convida a virar depósito.

### 3.3 O que a linha muda, e o que ela não muda

Ela **não muda o efeito**: antes, a negação vinha por omissão — os **três**
blocos `match /users/{uid}` do arquivo declaram apenas subcoleções, e um `allow`
dentro de `match /users/{uid}` não alcança descendentes; o documento raiz caía no
fecho `match /{documento=**}`.

Ela muda a **legibilidade**. A ausência de qualquer linha sobre o documento raiz
já produziu uma leitura errada num laudo de pré-homologação. A OS §21 exige
"decisão explícita"; um comportamento correto que ninguém consegue ler no ponto
onde vai procurá-lo não é decisão explícita.

**Esta honestidade tem consequência medida, e está na campanha negativa: a
mutação M1 (remover a linha) SOBREVIVE.** É *mutante equivalente*, não escape —
ver §7.2.

### 3.4 A contraprova que a decisão exigia

Um `if false` no pai **não pode** remover concessão das subcoleções (regras se
avaliam por documento e se somam por OR). "Não pode" por leitura do modelo virou
**medida**: os casos `RAIZ-U-10` a `RAIZ-U-13` provam que o dono continua lendo o
inventário, ligando `equipped`, e **escrevendo** em `users/{uid}/mutes` — a única
subcoleção em que o cliente escreve, e onde o vazamento apareceria primeiro.

Que essa contraprova **tem dente** também foi medido: a mutação M9, que fecha a
escrita de `mutes`, mata `RAIZ-U-12`.

---

## 4. Bloqueador R2 — as cinco coleções legadas

### 4.1 Tabela de decisão

**Classificação: `LEGADO-ENCERRAR` para as cinco.** A §7 proíbe inferir pelo
nome; cada linha abaixo tem a substituição da RC1 nomeada e a varredura por trás.

| Caminho | Classificação | O que é | Quem ocupa o lugar na RC1 | Consumidor na RC1 |
|---|---|---|---|---|
| `global_chat` | **LEGADO-ENCERRAR** | chat global de sala única, era FlutterFlow | `chatChannels` + `chatMessages` — texto livre é de **mesa privada**, com ritmo, bloqueio e sanção | **nenhum** |
| `tables` | **LEGADO-ENCERRAR** | mesa de jogo, era FlutterFlow | a mesa em tempo real **não vive no Firestore** (servidor WebSocket); o Firestore guarda `admissoesDeMesa`, `assentosAdmitidos`, `salasPrivadas` | **nenhum** |
| `seasons` | **LEGADO-ENCERRAR** | temporada (`2026_S1`), era FlutterFlow | `rankingSeasons` | **nenhum** |
| `leaderboards` | **LEGADO-ENCERRAR** | classificação (`2026_S1`), era FlutterFlow | `rankingLadders` + `rankingStandings` + `hallEntries`; a leitura da lista **nem passa por regra** — passa por `abrirRanking`/`paginarRanking`, que projetam `publicPlayerId` no lugar do uid | **nenhum** |
| `store_products` | **LEGADO-ENCERRAR** | catálogo (`pack_starter`), era FlutterFlow | `configuracao/billing` (catálogo comercial) + `collections/{id}/items` (acervo cosmético) | **nenhum** |

**A varredura.** Nenhum dos cinco nomes aparece em `app/lib/`, `functions*/src/`,
`web/` ou no servidor. As **únicas** ocorrências no repositório são os dois
relatórios de auditoria que os inventariaram.

> **Armadilha nomeada de propósito.** Existe um `tables` **dentro** de
> `firestore.rules`, e ele é outro caminho: `tournaments/{t}/editions/{e}/tables`,
> com outro produtor e legível pelo autenticado. A decisão acima **não o alcança**.
> O caso `LEGADO-tables nao confunde a subcolecao de torneio` existe para quebrar
> se alguém "cumprir" o encerramento mexendo no bloco de torneios.

### 4.2 Risco de dado: nenhum

Os cinco somam **cinco documentos** em produção — um por coleção, com ids de
semente (`pack_starter`, `2026_S1`). É base de demonstração, não base com
histórico. **Negar a regra não apaga nada:** os documentos continuam lá,
alcançáveis pelo Admin SDK, e uma migração futura não perde matéria-prima.

### 4.3 Por que o fechamento é o fecho final, e não cinco blocos `if false`

Esta foi a única alternativa considerada, e **foi descartada por impedimento
estrutural, não por estética** — a auditoria precisa julgar este ponto:

`functions-conta/test/inventario.test.js` **lê `firebase/firestore.rules`** e
exige que **toda coleção de primeiro nível declarada ali** tenha destino escrito
na matriz de retenção da exclusão de conta. O extrator é
`/^ {4}match \/([A-Za-z_][A-Za-z0-9_]*)\//gm`.

Declarar os cinco — **mesmo com `if false`** — os tornaria coleções declaradas
sem destino na matriz, e reprovaria aquele guard. Corrigi-lo exigiria alterar
`functions-conta/src/inventario.ts`, e **a §3 desta OS proíbe alterar Functions**.
Um bloco `if false` também **não acrescentaria efeito nenhum**: o fecho já nega.

**Consequência verificada:** o conjunto de coleções que o guard enxerga é
**idêntico** antes e depois desta correção — 54 nomes, zero novas, zero perdidas.
E `functions-conta` fecha **86/86** sobre a árvore corrigida (§6.3).

**Onde a decisão passa a morar, então:** no quadro escrito em `firestore.rules` e,
com dente, em `firebase/testes/seguranca.test.js`, que exerce os cinco caminhos em
leitura, varredura, escrita e exclusão, para **anônimo, dono, terceiro e admin**,
e falha se qualquer um voltar a conceder. **É o teste, e não o comentário, que
impede a reabertura** — e a mutação M6 prova isso.

### 4.4 Existe uma candidata CONCORRENTE para esta mesma OS — e ela foi medida

Descoberto ao fim desta execução: outra sessão produziu, **no mesmo dia e sobre a
mesma base `603f0e1`**, a correção **RULES-B** — commit
`19e082b88e9b24da1179a3485f52c3af452ad9ce`, branch
`correcao/rules-caminhos-legados-encerramento-v1`. Ela cobre **os mesmos seis
caminhos** (os cinco legados mais `users/{uid}`).

As duas divergem exatamente no ponto da §4.3: **RULES-B declara os cinco legados
como blocos `match` de primeiro nível** (59 coleções de primeiro nível, contra 54
na base e 54 nesta candidata). Com isso ela ganha a metade que falta aqui — uma
prova de **declaração**, que faz doer a remoção do bloco e mata o equivalente da
§7.2.

**O custo disso foi medido nesta sessão, não suposto.** Aplicando as Rules de
`19e082b` e rodando o codebase vizinho:

```
functions-conta$ npm test
✖ toda colecao declarada em firestore.rules esta na matriz
  actual: [ 'global_chat', 'leaderboards', 'seasons', 'store_products', 'tables' ]
  expected: []
ℹ tests 86 · pass 85 · fail 1
```

Contra esta candidata (`006800e`), o mesmo comando dá **86/86**.

É o impedimento da §4.3, realizado. RULES-B resolve a fraqueza da §7.2 e, ao
fazê-lo, **quebra o guard de cobertura da exclusão de conta** — provavelmente sem
ter notado, já que a suíte reportada por ela é a de `firebase/testes` (295/295), e
o guard mora em `functions-conta`.

**Isto não é veredito sobre a candidata alheia**, e esta OS não tem autoridade
para emiti-lo. É o dado que faltava para a arbitragem da §23, e as três saídas
possíveis são:

1. **Esta candidata** — íntegra entre codebases, com a §7.2 aberta;
2. **RULES-B** — com prova de declaração, e `functions-conta` vermelho até que uma
   OS conjunta acrescente os cinco itens à matriz de retenção;
3. **Uma composição** — os cinco `match` de RULES-B **mais** as cinco entradas em
   `functions-conta/src/inventario.ts`, o que exige uma OS que autorize as duas
   frentes. É a única saída que fica verde nas duas pontas.

---

## 5. Bloqueador R3 — `chatRitmo`

### 5.1 A divergência era documental, e a leitura era invertida

O laudo anterior registrou que `chatRitmo` "continua presente nas Rules apesar de
existir decisão anterior de apagá-la". **A decisão anterior não pede isso.**

A decisão é a **OS 40-I1-CT1** (`docs/OS40-I1-CT1-CHAT-RITMO-INVENTARIO-V1.md`,
commit `28477df`, já incorporada a esta base). O que ela classificou como
`APAGAR` é um item da **matriz de retenção da exclusão de conta** —
`moderacao.ritmoDeChat`, em `functions-conta/src/inventario.ts:927`. Ali,
`APAGAR` significa *"quando o **jogador** pede para sair, o documento **dele** é
apagado"*, e o efeito é uma linha em `functions-conta/src/executor.ts:363`.

Não significa, e nunca significou, apagar a **coleção** nem a regra dela. A §6
daquela ordem declara em letra: *"Não tocou `firestore.rules`"*.

### 5.2 Verificação das seis perguntas da §8

| Pergunta | Resultado |
|---|---|
| Origem da decisão de remoção | **Não existe.** A decisão de `APAGAR` é de retenção, não de Rules (5.1). |
| `chatRitmo` ainda é usado no cliente? | Não diretamente — o que o jogador precisa saber volta em `liberaEmMs`, na resposta da chamada. O vocabulário está em `app/lib/comunicacao/limites.dart`. |
| É usado por Functions? | **SIM, com produtor vivo:** `functions-moderacao/src/comunicacao.ts` (`C_RITMO`) escreve **a cada fala**, pelo freio anti-spam. |
| Há testes que dependem dele? | **SIM:** 4 casos em `firebase/testes/chat.test.js` (agora 6), mais 5 em `functions-conta/test/integracao.emulador.test.js` e 6 em `functions-conta/test/inventario.test.js`. |
| Há dados existentes? | Em produção, não (a coleção não existe lá ainda). No emulador, sim, a cada fala. |
| Remover a regra é suficiente, ou há dependência funcional? | **Há dependência.** Ver 5.3. |

### 5.3 A decisão: o bloco PERMANECE, sem alteração de condição

Remover o bloco **não fecharia porta nenhuma** — o Admin SDK ignora estas regras
— e teria três custos reais:

1. tiraria a **leitura do admin**, que é a única concessão ali (e `CHAT-RIT-04`
   quebra: medido em M8);
2. derrubaria os casos de `chat.test.js` que provam quem lê e quem não lê;
3. retiraria `chatRitmo` da **fonte externa** que `functions-conta/test/inventario.test.js`
   cruza com a matriz — afrouxando justamente o guard que detectou a lacuna
   original.

**Não há migração necessária e não há HOLD a abrir.** A reconciliação foi escrita
no próprio bloco de regras, para que a mesma leitura errada não se repita, e a
campanha da §12 foi completada com dois casos novos (`CHAT-RIT-05` sem sessão,
`CHAT-RIT-06` ausência de caminho permissivo por baixo do documento).

---

## 6. Testes executados

### 6.1 A bancada, e por que ela não é o repositório

`F:` é **exFAT**. A árvore `firebase`/`@firebase` **não se instala** ali: `npm ci`
sai com exit 0 e deixa pacotes sem `package.json`, e a suíte morre em
`Cannot find module` **antes de avaliar regra nenhuma** — parecendo suíte
quebrada. Toda medição desta OS rodou em **NTFS**:

| Item | Valor |
|---|---|
| Bancada | `C:/rulesc1` — `git worktree add --detach`, mesmo SHA `603f0e1` |
| `npm ci` em `firebase/testes` | exit 0, **45** pacotes `@firebase` |
| JDK | JBR do Android Studio (`C:/Program Files/Android/Android Studio/jbr`) |
| `firebase-tools` | 15.26.0 |
| Emulador | `emulators:exec --only firestore --project demo-bmv` |
| Alvo | `npm run test:integrado` — união das **dez** suítes contra o **mesmo** `firestore.rules` |

> Portas: os harnesses de `passe`, `ranking` e `rastreabilidade` **fixam 8080**;
> `--config` com portas alternativas não serve para este alvo. As execuções foram
> serializadas com dreno verificado de 8080/4400/4500.

### 6.2 Resultados

| Execução | tests | suites | pass | fail | cancelled | skipped |
|---|---:|---:|---:|---:|---:|---:|
| **Linha de base** (árvore intacta em `603f0e1`) | **252** | 55 | **252** | 0 | 0 | 0 |
| **Árvore corrigida** | **290** | 58 | **290** | 0 | 0 | 0 |
| **Confirmação** (após a campanha, bancada restaurada) | **290** | 58 | **290** | 0 | 0 | 0 |

A linha de base foi **medida**, não herdada do laudo anterior, e bate com a
referência da §11 (252/252/0). **Os 252 casos legítimos estão preservados**: o
delta é +38, e os 38 são nominalmente identificáveis.

> `skipped 0` importa: uma suíte que não carrega **não falha — ela some**, e um
> `describe` pulado inteiro não aparece no rodapé. O total é a única frente que
> enxerga esse buraco, e por isso ele é reportado junto.

### 6.3 Guard cruzado entre codebases

`functions-conta` lê `firebase/firestore.rules`. Rodado sobre a árvore corrigida:

```
functions-conta$ npm test   →  tests 86 · pass 86 · fail 0 · skipped 0
```

Inclui `toda colecao declarada em firestore.rules esta na matriz`. **Nenhuma
Function foi alterada** para isso — o conjunto de coleções de primeiro nível
visto pelo extrator é idêntico ao da base (54 → 54, zero novas, zero perdidas).

---

## 7. Campanha negativa

Nove mutações, **todas em cópia externa** (`C:/rulesc1`), nunca na candidata; a
candidata em `F:` é a fonte, e foi recopiada antes de cada rodada.

| # | Mutação | pass/fail | Desfecho | Morta por |
|---|---|---:|---|---|
| M1 | remove `allow read, write: if false` do raiz | 290/0 | **SOBREVIVE — equivalente** | — (§7.2) |
| M2 | restaura a regra de produção: `read, write: if ehDono(uid)` | 285/5 | morta | `RAIZ-U-01`, `-06`, `-07`, `-08`, `-09` |
| M3 | restaura só a leitura: `read: if ehDono(uid)` | 289/1 | morta | `RAIZ-U-01` |
| M4 | abre para o admin: `read: if ehAdmin()` | 288/2 | morta | `RAIZ-U-04`, `-05` |
| M5 | `update` com allowlist `['displayName']` (parece prudente) | 288/2 | morta | `RAIZ-U-06`, `-07` |
| M6 | reabre `global_chat` com `read: if autenticado()` | 288/2 | morta | `LEGADO-global_chat-le`, `-varre` |
| M7 | afrouxa o **fecho final** para `read: if autenticado()` | 201/89 | morta | 15 casos novos + 74 outros |
| M8 | **remove o bloco `chatRitmo`** (a leitura errada do laudo, executada) | 289/1 | morta | `CHAT-RIT-04` |
| M9 | fecha a escrita de `mutes` | 286/4 | morta | `RAIZ-U-12` (+3 preexistentes) |

**8 de 9 mortas. A nona é equivalente, não escape.**

### 7.1 Duas rodadas foram descartadas por infraestrutura, não por resultado

M6 e M8 saíram na primeira volta como `pass 0 / fail 4` e "sem mortos". **Nenhum
dos dois era medição:** o hub subiu em 4401 porque a 4400 ainda estava presa da
rodada anterior, e o Firestore saiu com código 1 — `emulators:exec` devolve o
terminal **antes** de as portas drenarem. Os dois foram refeitos com dreno
verificado das três portas, e os números da tabela são os da segunda volta.

Registrado porque o sintoma é indistinguível de suíte quebrada, e porque um
"sobreviveu" lido daquela primeira volta seria falso.

### 7.2 M1 é mutante equivalente — e isso é declarado, não escondido

Remover `allow read, write: if false` de `match /users/{uid}` devolve o documento
raiz à negação por omissão do fecho final. O comportamento é **idêntico**, e a
medida confirma: 290/290, **byte a byte o mesmo rodapé** da árvore limpa.

Nenhum teste de comportamento pode distinguir os dois estados, porque **não há
diferença de comportamento** — só um teste que lesse o texto do arquivo
distinguiria, e um teste desses guardaria a prosa, não o programa.

**Isto concorda com o que a própria linha declara**: ela não muda o efeito, ela
torna a decisão legível. O que protege o comportamento são `RAIZ-U-01` a
`RAIZ-U-09`, e eles matam **M2, M3, M4 e M5** — inclusive a restauração literal
da regra de produção, que é a mutação perigosa de verdade.

**A auditoria tem aqui uma decisão a tomar**, e ela é nomeada em vez de
escondida: se a §21 exigir que a linha explícita seja *executavelmente* guardada,
o único instrumento possível é um teste estrutural sobre o texto de
`firestore.rules` — e esta OS **não o escreveu**, por considerá-lo guarda de
prosa. É ponto legítimo de discordância.

---

## 8. Campanha mínima da §12 — cobertura ponto a ponto

### 8.1 `users/{uid}`

| Exigência da §12 | Caso | Desfecho |
|---|---|---|
| dono | `RAIZ-U-01` | deny |
| outro usuário | `RAIZ-U-02` | deny |
| não autenticado | `RAIZ-U-03` | deny |
| *(acréscimo)* admin | `RAIZ-U-04` | deny |
| *(acréscimo)* varredura da coleção | `RAIZ-U-05` | deny p/ os quatro |
| escrita em campo permitido | `RAIZ-U-06` (`displayName`) | deny |
| tentativa de tocar campo sensível | `RAIZ-U-07` (`vip`) | deny |
| *(acréscimo)* create | `RAIZ-U-08` | deny |
| delete | `RAIZ-U-09` | deny p/ os quatro |
| subcoleções | `RAIZ-U-10`…`-13` | **allow** onde deve, **deny** no isolamento |
| *(controle)* a bancada carregou as regras | `RAIZ-U-00` | **allow** |

### 8.2 Os cinco legados

Para cada um dos cinco caminhos, quatro casos — `-le`, `-varre`, `-escreve`,
`-apaga` — e cada caso percorre **dono, terceiro, admin e anônimo**. `-escreve`
cobre `update` e `setDoc` sobre o documento que existe **e** criação de um
documento novo (`{colecao}/forjado`), que é como coleção morta volta a ganhar
conteúdo sem ninguém decidir. **20 casos, todos deny.** Mais `LEGADO-00`
(controle positivo) e o caso da subcoleção de torneio.

> **Os cinco documentos estão semeados** com os ids que existem em produção.
> Negar leitura de documento **inexistente** não prova regra nenhuma — o
> Firestore nega de qualquer jeito, e o caso passaria com a regra aberta. Semeado,
> o `assertFails` só pode vir da regra.

### 8.3 `chatRitmo`

| Exigência da §12 | Caso | Desfecho |
|---|---|---|
| caminho existe conforme decisão | `CHAT-RIT-04` (admin lê) | **allow** |
| leitura coerente | `CHAT-RIT-01`, `-03`, `-05` | deny p/ dono, estranho, anônimo |
| escrita coerente | `CHAT-RIT-02`, `-05` | deny p/ dono, estranho, motor, admin, anônimo |
| ausência de fallback permissivo | `CHAT-RIT-06` | deny em subcaminho inventado |

### 8.4 Controles positivos — por que eles abrem os blocos

Um emulador que subisse **sem carregar as regras** faria **todo** `assertFails`
"passar", e a suíte inteira daria verde provando nada. `RAIZ-U-00` e `LEGADO-00`
afirmam um caminho que a RC1 **declara** como legível. Se eles falham, o que está
quebrado é a bancada, não a regra. São repetidos nos dois blocos de propósito:
cada bloco tem de poder ser executado sozinho sem herdar a garantia do vizinho.

---

## 9. Fail-closed (§13)

O fecho `match /{documento=**} { allow read, write: if false; }` está **intacto,
byte a byte**. Nada foi removido nem enfraquecido para restaurar comportamento
legado — a correção move na direção contrária: **acrescenta** um `if false`.

A mutação **M7**, que afrouxa esse fecho para `read: if autenticado()`, derruba
**89 casos**. O fecho é a viga, e a campanha mede que ele é a viga.

Uma nota **envelhecida** no fecho foi corrigida: ela dizia que o fecho era seguro
porque *"nenhuma tela usa Firestore ainda — o app só consome `firebase_auth`"*.
Isso deixou de ser verdade (são quatro caminhos hoje). A frase foi substituída
para que ninguém conclua dela que o fecho é inofensivo por falta de consumidor. É
mudança de comentário, e está no diff.

---

## 10. Compatibilidade com versões anteriores (§9)

**Veredito: COMPATIBILIDADE ENCERRADA POR DECISÃO, com custo real zero.**

| Caminho | Compatibilidade | Fundamento |
|---|---|---|
| `users/{uid}` | **encerrada por decisão** | nenhum leitor no cliente atual; produção tem 1 documento de semente |
| `global_chat` | **encerrada por decisão** | nenhum consumidor; 1 documento de semente |
| `tables` | **encerrada por decisão** | idem |
| `seasons` | **encerrada por decisão** | idem |
| `leaderboards` | **encerrada por decisão** | idem |
| `store_products` | **encerrada por decisão** | idem |

**Nenhuma necessidade de transição**, e o motivo é factual e verificável: **não
existe cliente publicado**. O aplicativo nunca foi publicado na Play, e o único
documento de `billingEvents` em produção é a notificação de **teste** do console.
Não há versão antiga em circulação para quebrar.

**Isto não é "quebrar em silêncio":** é o que esta seção existe para registrar, e
os seis caminhos estão nomeados um a um, com a classificação de cada um.

> **Reversibilidade.** Nada foi apagado. Os seis documentos continuam em
> produção, e o ruleset anterior (`e5b63447-2ddf-46ea-954a-03d13eca6fba`)
> continua existindo e é republicável pelo id, em segundos.

---

## 11. `usuarios/{uid}` (§10) — não foi enfraquecido

O bloco de `usuarios/{uid}` **não foi tocado**. `camposDeServidor()` segue com
`vip`, `vipExpiraEm`, `vipProdutoId`, `vipAtualizadoEm`, `fichas`,
`fichasAtualizadoEm`; `create` segue exigindo `!hasAny(camposDeServidor())`,
`update` segue exigindo que o `diff` não toque nenhum deles, e `delete` segue
`false`. Nada foi afrouxado ali para "compensar" o fechamento de `users/{uid}` —
o diff prova: a única linha semântica do arquivo está em `users/{uid}`.

A suíte `entitlement.test.js` entra em `test:integrado` e permaneceu verde.

---

## 12. Fora de escopo — o que esta OS NÃO fez

| Item | Estado |
|---|---|
| **Deploy de Rules** | **NÃO EXECUTADO.** §14 e §24. Nenhum `firebase deploy`, nenhum `firebaserules.projects.test`, nenhuma chamada a projeto Firebase real. |
| **Deploy de índices** | **NÃO EXECUTADO.** |
| **Índices** (§15) | `firebase/firestore.indexes.json` **não tocado** — `git diff` vazio. Seguem em HOLD: 1 em produção, 40 na RC1, 39 novos, 0 a excluir, 2 field overrides. |
| **Functions** (§3) | **nenhum arquivo alterado** em `functions*/` — `git diff` vazio. |
| **`functions-conta`** (§16) | **não alterado.** O conflito documental no `package.json` continua para OS separada. |
| Dados de usuários / migração | nada tocado, nada migrado. |
| Endpoint, versão, Billing, economia, ranking | nada tocado. |
| Merge em `main` | **não executado.** |
| Publicação Play | **não executada.** |

### 12.1 Pendências externas registradas, não resolvidas

* **PITR e proteção contra exclusão** (§17): **DESABILITADOS** em produção.
  Fora do alcance desta estação — registrado como pendência externa.
* **Runtime `nodejs20`** (§18): não atualizado. Pendência separada.

---

## 13. O commit

| Item | Valor |
|---|---|
| Branch | `correcao/bmv-rc1-b2-rules-c1-v1` |
| Pai | `603f0e1fce21787ac003a1b5c5cfd957e3984d77` |
| Natureza | **aditivo**; nenhuma condição preexistente alterada ou removida |

**Arquivos alterados — quatro, e nenhum fora do que a §19 autoriza:**

| Arquivo | Papel |
|---|---|
| `firebase/firestore.rules` | a correção (1 linha semântica + as decisões escritas) |
| `firebase/testes/seguranca.test.js` | campanha de `users/{uid}` e dos cinco legados |
| `firebase/testes/chat.test.js` | dois casos que completam a campanha de `chatRitmo` |
| `docs/LAUDO-B2-RULES-C1.md` | este laudo |

> **Por que o SHA do commit não está nesta tabela.** Ele não pode estar: este
> arquivo é conteúdo do próprio commit, e escrevê-lo aqui mudaria o SHA que ele
> afirma. O SHA e o tree são reportados no despacho de entrega, e são verificáveis
> com `git log -1 --format='%H %T %P'` sobre a branch. O que **está** aqui e é
> auto-verificável são os hashes SHA-256 de cada arquivo (§1.2).

---

## 14. Critério de PASS de implementação (§21) — conferência

| Exigência | Estado | Onde |
|---|---|---|
| `users/{uid}` com decisão explícita e segura | **atendido** | §3 |
| cinco caminhos legados com destino explícito | **atendido** | §4.1 |
| `chatRitmo` reconciliado | **atendido** | §5 |
| deny final permanece | **atendido** | §9 |
| campos sensíveis continuam protegidos | **atendido** | §11 |
| testes verdes | **atendido** — 290/290, 0 fail, 0 skipped | §6.2 |
| campanha negativa eficaz | **atendido com ressalva declarada** — 8/9 mortas, 1 equivalente | §7, §7.2 |
| nenhuma Function alterada | **atendido** | §12 |
| nenhum índice alterado | **atendido** | §12 |
| nenhum deploy executado | **atendido** | §12 |
| árvore final limpa | **atendido** | commit isolado, sem resíduo |
| commit isolado produzido | **atendido** | §13 |

---

## 15. O que a auditoria independente deve atacar primeiro

Três pontos, nomeados pelo executor porque são onde ele pode ter errado:

0. **A existência de uma candidata concorrente** (§4.4) — `19e082b`, mesma base, mesmo escopo, decisão oposta no ponto central, e `functions-conta` vermelho. A arbitragem entre as duas precede qualquer julgamento desta.
1. **A decisão de não declarar os cinco legados como blocos `if false`** (§4.3).
   O impedimento é real e está medido, mas a conclusão — "então a decisão mora no
   teste" — é escolha, não necessidade. A alternativa seria uma OS conjunta que
   tocasse `functions-conta`.
2. **M1 sobrevive** (§7.2). A linha acrescentada é documental por construção. Se
   a §21 exigir guarda executável para ela, esta entrega não a tem.
3. **A afirmação "não existe cliente publicado"** (§10) é o que sustenta *todo* o
   encerramento de compatibilidade. Ela vem de dois relatórios de auditoria já na
   árvore, e **não foi reverificada contra a Play Console nesta sessão** — não há
   ferramenta para isso nesta estação. Se ela for falsa, §10 cai inteira.

---

## 16. Desfecho

**B2-RULES-C1 — IMPLEMENTAÇÃO CONCLUÍDA / PRONTA PARA AUDITORIA INDEPENDENTE**

Sem deploy. Sem Functions. Sem índices. Sem merge.
