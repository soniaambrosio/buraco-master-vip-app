# OS 40-I1-B1 — Determinismo temporal do gate `billing`

**Base:** `d047857fb2e2f984b8d5deff155146958bac28d9` (C10, integrada por fast-forward na I1)
**Autoridade:** bloqueador externo encontrado na integração da OS 40-I1 (run nº 21, `35115498021`)
**Natureza:** correção de **prova**. Nenhum arquivo produtivo muda.

## 1. O defeito

O run nº 21 terminou em `failure` com 62 de 64 gates verdes. O gate `billing`
ficou em 410 testes, 401 aprovados e 9 falhas.

A causa não é a lógica de billing. A fixture do harness adversarial declara

```js
const FUTURO = '2026-09-16T10:00:00.000Z';
```

e a suíte rodou em 16/09/2026 às 15:36Z — quando aquele instante **já era
passado**. O harness tem dois caminhos, e só um deles tinha relógio:

- `cenarioDeModulo()` liga store, reconciliador e RTDN com um **relógio
  injetado** (`RelogioFalso`). Decide contra um instante ditado, e por isso
  permaneceu verde;
- `cenarioDeIndex()` carrega `index.js` inteiro com as portas trocadas. Mas
  `index.js` é o adaptador: ele chama `new Date()` direto, sem porta injetável
  (`consultadoEm` e as três montagens de `agora`). Esse caminho decidia contra o
  **calendário de quem rodava a suíte**.

Enquanto a data civil do executor ficou antes de `FUTURO`, um prazo escrito
`FUTURO` era futuro. No dia em que passou, `consolidarAssinatura` passou a
classificar como expirado — `dentroDoPrazo = Boolean(expiraEm) && anteriorA(agora,
expiraEm)` — e nove casos viraram vermelhos **sem que uma linha de código
mudasse**.

Os nove: `A`, `R`, `R6`, `R6b`, `Y7`, `F2`, `T`, `V4`, `W3`.

## 2. O que NÃO foi feito

Trocar `FUTURO` por uma data civil mais distante só adia a mesma falha: a suíte
voltaria a ficar vermelha sozinha, mais tarde, pelo mesmo motivo. Nenhuma
expectativa, contagem ou asserção foi relaxada, e a classificação de assinatura
expirada, cancelada, revogada ou em carência não foi tocada.

## 3. O que foi feito

O último vazamento de ambiente do harness foi fechado: **o caminho de `index.js`
passou a ter relógio**, ditado por fora.

### 3.1 `test/apoio/carga_index.js` — o relógio é uma porta

`instalarRelogioGlobal(instante)` troca `globalThis.Date` por uma subclasse cuja
construção **sem argumento** devolve o instante dado, e cujo `now()` devolve o
mesmo em milissegundos. `restaurarRelogioGlobal()` desfaz.

Três decisões carregam a garantia:

1. **Só a forma sem argumento é ditada.** `new Date(x)` continua interpretando
   `x` exatamente como antes. Disso dependem `RelogioFalso`, a comparação de
   instantes de `entitlement.js` e toda leitura de prazo já gravado — os
   cenários de relógio injetado preservam ordem e semântica.
2. **`DateReal` é capturada na carga do módulo**, e não no momento da troca. Um
   cenário aninhado (`Z1` monta dois) instalaria relógio por cima de relógio; uma
   restauração que voltasse "para o que estava antes" devolveria o falso no lugar
   do verdadeiro. Com referência única, toda restauração chega à original em um
   passo.
3. **A restauração é idempotente**, porque é chamada depois de todo caso,
   inclusive dos que nunca instalaram nada.

### 3.2 `test/apoio/cenario.js` — o instante controlado do caso

`cenarioDeIndex({ agora = AGORA_DE_INDEX })` instala o relógio antes de carregar
`index.js`. `AGORA_DE_INDEX` **é `T0`**, o mesmo instante em que o relógio do
cenário de módulo começa: os dois caminhos passaram a decidir contra o mesmo
instante, e `FUTURO` significa a mesma coisa nos dois.

Duas peças tornam a relação estrutural, e não uma coincidência de literais:

- **a banda temporal é conferida na carga.** `PASSADO < AGORA_DE_INDEX < FUTURO <
  FUTURO_LONGE` é afirmado, e quebrá-lo para o harness com uma mensagem nominal
  em vez de produzir falhas sem explicação;
- **`futuroDe(instante)` e `passadoDe(instante)`** produzem prazos ±30 dias
  **em relação ao instante dado**. O cenário expõe `agora`, `futuro` e `passado`,
  de modo que "futuro" deixa de ser uma data e passa a ser uma relação.

Os literais `T0`–`T4`, `PASSADO`, `FUTURO` e `FUTURO_LONGE` permanecem
byte a byte como estavam.

### 3.3 `test/adversarial.test.js` — a restauração não pode depender do caso

```js
test.afterEach(() => {
  restaurarRelogioGlobal();
});
```

A restauração **não** mora no fim de cada cenário, de propósito. Um caso que
falhasse no meio nunca chegaria àquela linha e deixaria `Date` trocada para todos
os seguintes: o próximo cenário decidiria contra o instante do caso que quebrou, e
a suíte passaria a relatar falhas herdadas em vez das próprias. `afterEach` roda
de todo jeito.

Quatro casos novos, na seção `TM`, colocada **antes** de `X1`/`X4` para que a
armadilha de rede e a fronteira de domínio continuem cobrindo tudo:

| Caso | O que prova |
|---|---|
| `TM1` | o relógio do caso anterior (`W3`, um cenário de index) não sobreviveu — é o teste que cai primeiro se o `afterEach` sumir |
| `TM2` | **prova pareada**: um prazo declarado futuro fica ativo tanto no controle anterior ao corte antigo quanto no posterior a `2026-09-16T10:00:00.000Z` |
| `TM3` | no **mesmo** relógio posterior, um prazo declarado passado expira — a contraparte obrigatória, sem a qual `TM2` ficaria verde por ter empurrado tudo para o futuro |
| `TM4` | a restauração alcança a `Date` **original** com cenários aninhados e depois de falha no meio, e é idempotente |

`TM2` afirma a própria premissa antes de usá-la: que um controle está antes e o
outro depois do corte antigo.

## 4. Resultado

| Gate | Base `d047857` | Rodada inicial, sem `X3` | Estado final, com `X3` |
|---|---|---|---|
| `npm test` | 410 testes, 401 ✓, **9 ✗** | 414 testes, 414 ✓ | **415 testes, 415 ✓, 0 ✗** |
| `npm run test:adversarial` | 86 testes, 9 ✗ | 90 testes, 0 ✗ | **91 testes, 91 ✓, 0 ✗** |
| `prova:propriedade-nao-vacua` | verde | verde — 0 sobreviventes | **verde — 0 sobreviventes** |
| `prova:nao-vacuidade` | **vermelha**: 3 vácuas | **vermelha**: 2 vácuas (`N6`, `N7`) | **exit 0 — zero vácuas** |

O estado final foi medido em **Node `v20.20.2`**, a versão declarada em `engines`.
A cronologia da última linha está na §5.

A mudança é **aditiva**: 5 nomes de teste novos (`TM1`–`TM4` e `X3`), nenhum
removido e nenhum renomeado. Nenhuma dependência entrou. Os **18 blobs
produtivos** de `functions-billing` — incluindo `package.json` e
`package-lock.json` — são byte a byte idênticos aos da base. O diff da candidata
toca quatro caminhos: a suíte e dois arquivos de apoio em `functions-billing/test/`,
e este documento. A alteração é **exclusivamente de testes, apoio de testes e
documentação**.

### 4.1 Prova pareada por mutação

Cada mutação foi aplicada numa **cópia externa** da candidata, nunca na bancada:

| Mutação | O que desliga | Vermelhos |
|---|---|---|
| `M1` | o relógio controlado não é instalado — volta o regime antigo | os **nove** do run 21, mais `TM2`, `TM3`, `TM4` |
| `M2` | a âncora anda para depois do corte antigo, com `FUTURO` literal | a guarda de banda derruba a **carga** do harness, com mensagem nominal |
| `M3` | `futuroDe` devolve instante no passado do controle | só `TM2` |
| `M4` | `passadoDe` devolve instante no futuro do controle | só `TM3` |
| `M5` | o `afterEach` é removido | `TM1` e `TM4` |

`M1` é a restauração da fixture antiga exigida pela ordem: reproduz o vermelho de
referência **caso a caso**, com os mesmos nove nomes.

## 5. `prova:nao-vacuidade`: cronologia

### 5.1 Rodada inicial, antes de `X3`

Base e candidata inicial foram medidas em cópias externas limpas, lado a lado. A
base tinha **três** vacuidades e a candidata inicial, **duas**:

| Caso | Base | Candidata inicial |
|---|---|---|
| `C5` — `fichasStore.js`, padrão `^FI4 ` | **VÁCUO** | **NÃO VÁCUO** |
| `N6` — `entitlement.js`, padrão `^X3 ` | **VÁCUO** | **VÁCUO** |
| `N7` — `entitlement.js`, padrão `^X3 ` | **VÁCUO** | **VÁCUO** |

`C5` foi curada pelo relógio controlado. `N6` e `N7` eram **herdadas**: mediam o
padrão `^X3 `, e o teste `X3` tinha sido removido de `adversarial.test.js` em
`7e74bcf`. Com padrão que não casa com nada, `node --test` ainda resume
`tests 1 / pass 1 / fail 0` — os mesmos contadores de um teste real que passou —,
de modo que a guarda "o padrão não selecionou nenhum teste" da própria prova não
dispara e o caso é contado como vácuo.

### 5.2 A inclusão de `X3`

Por despacho próprio, `X3` foi acrescentado a `adversarial.test.js`. É um teste,
nove combinações: `packageName` **ausente**, **vazio** ou **de terceiro**, cada um
em notificação de **assinatura**, **anulação** e **revogação**. Cada combinação é
medida em dois níveis:

- **a leitura**: `interpretarNotificacao` devolve `acao: 'ignorar'` com
  `motivo: 'pacote_divergente'`;
- **o efeito**, atravessando o processador de RTDN: decisão `pacote_divergente`,
  **zero consulta à Play** e zero fechamento junto à Google, **zero escrita** no
  entitlement público e no interno — direito e prazo preservados — e **zero
  vazamento** de token ou hash no evento gravado e nos logs.

Cobre também o pacote oficial ausente, vazio ou não-string, que falha fechado com
`detalhe: 'pacote_oficial_ausente'`, e fecha afirmando que as nove combinações
rodaram, para que a matriz não encolha em silêncio.

Os dois mutantes derrubam `X3` **separadamente**, com `entitlement.js` mutado em
cópia e restaurado:

| Mutante | O que desliga | `X3` |
|---|---|---|
| `N6` | `corpo.packageName && corpo.packageName !== pacote` — pacote ausente volta a passar | **vermelho** |
| `N7` | `acao: 'ignorar'` vira `'reconciliar'` — pacote alheio entra no caminho econômico | **vermelho** |

As duas vacuidades foram eliminadas **sem editar `test/apoio/nao_vacuidade.js`**:
o padrão `^X3 ` que a prova já declarava passou a encontrar o teste que ela
esperava.

### 5.3 Estado final da candidata

Em Node `v20.20.2`:

- `npm run test:adversarial`: **91/91**;
- `npm test`: **415/415**;
- `prova:propriedade-nao-vacua`: **zero sobreviventes**;
- `prova:nao-vacuidade`: **exit 0, zero vacuidades**, árvore limpa no fim;
- `N6` e `N7`: **NÃO VÁCUO**.

**Nenhum bloqueio residual permanece na B1.**

Uma nota de leitura: na tabela da prova, a coluna "rodados" de `N6`/`N7` mostra
`91` em Node 20 e `1` em Node 24. Com `--test-name-pattern`, o Node 20 conta o
arquivo inteiro e o Node 24 só o selecionado. Nas duas versões, o que prova a
morte do mutante é a coluna de vermelhos, e não a de rodados.

## 6. O que continua em aberto

Esta correção é **isolada** e não fecha a OS 40-I1. O portão global continuará
legitimamente vermelho enquanto a CT1 não for corrigida. A publicação depende de
despacho próprio.
