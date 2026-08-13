# Economia inicial e recompensa por resultado de partida — v1

Base: `0ea96c292f5c9f21ae0a884507c79a4bed3b3d20` (`homologacao/play-billing-comercial`).

## A economia aprovada — texto normativo

> ### Bônus de boas-vindas: **100 fichas**
>
> Todo jogador elegível recebe **exatamente 100 (cem) fichas** na **primeira e
> única** concessão de boas-vindas.
>
> - concessão **única e idempotente**, uma vez por conta, **para sempre**;
> - **contas antigas são elegíveis sem migração** — a primeira chamada credita as
>   100 delas, e o saldo que já tinham é **somado**, não substituído;
> - **autoridade exclusivamente server-side**: o cliente não informa valor, saldo
>   nem "ainda não recebi";
> - creditadas na **mesma carteira canônica** `usuarios/{uid}.fichas`.
>
> O número vive em `POLITICA.boasVindas` (`functions-economia/economia.js`) e está
> amarrado pelo teste `ECO-01`.

| Movimento | Valor | Quando |
|---|---|---|
| `boas_vindas` | **+100 fichas** | uma vez por conta, para sempre |
| `vitoria_partida` | **+15 fichas** | por competidor humano do lado vencedor, em partida elegível |
| `derrota_partida` | **−10 fichas** | por competidor humano do lado perdedor, em partida elegível, com piso zero |

**Elegibilidade da partida** (decisão comercial fechada — ver §5):

| Modalidade | Movimenta |
|---|---|
| `publica_casual` · `publica_ranqueada` · `torneio` | **+15 / −10** |
| `treinamento` · `contra_robos` · `privada` | **0** |
| anulada · cancelada · inconsistente · não concluída · sem resultado oficial | **0** |

O saldo **nunca** fica negativo: piso absoluto em `0`.

Nenhum destes valores depende de assinatura VIP, pacote Fundador/Pioneiro ou
promoção.

---

## 1. A auditoria, antes de qualquer linha de código

### 1.1 A carteira canônica

**`usuarios/{uid}.fichas`.** Escrita hoje por `functions-billing/fichasStore.js`
(as parcelas da assinatura), declarada como campo exclusivo de servidor em
`firebase/firestore.rules` desde o bloco 2/3:

```
function camposDeServidor() {
  return ['vip', 'vipExpiraEm', 'vipProdutoId', 'vipAtualizadoEm',
          'fichas', 'fichasAtualizadoEm'];
}
```

Esta OS usa essa carteira. **Não foi criada carteira paralela.**

### 1.2 "moedas" e "fichas" — a trava da seção 2 foi verificada e liberada

A OS fala em *moedas*; o código persistido fala em `fichas`. **Não são moedas
economicamente diferentes.** A verificação:

- `moedas` não aparece em **nenhum** arquivo `.js` ou `.ts` do projeto — nem
  como campo do Firestore, nem em regra, nem em Function;
- as ocorrências de `moedas` estão todas em telas Flutter, com valor fixo no
  próprio arquivo (`moedas: 1000` em `inicio_screen.dart`,
  `loja_categoria_screen.dart`, `recompensas_screen.dart`). São rótulos de
  maquete, sem leitura ou escrita associada;
- o único saldo que existe de verdade é `usuarios/{uid}.fichas` — é o que
  billing credita e o que o torneio debita como entrada.

Logo: mesma carteira, dois nomes. Usou-se a existente.

> `MoedaTipo.gemas`, na vitrine, é uma terceira unidade — também só de tela, sem
> nada persistido. Esta OS não a toca.

### 1.3 Onde o usuário é criado de forma autoritativa

**Em lugar nenhum.** Nesta base não existe Function de criação de usuário: nem
gatilho de Auth, nem `beforeUserCreated`, nem callable de provisionamento. O
documento `usuarios/{uid}` é criado pelo próprio cliente (as Rules permitem, e
barram os campos de servidor).

Consequência de desenho: o bônus não pôde ser pendurado num ponto de criação que
não existe. Virou uma **callable idempotente** que o aplicativo chama a cada
entrada de sessão — o que, como efeito colateral, resolve as contas antigas de
graça (ver §4).

### 1.4 Onde a partida é declarada definitivamente encerrada

**`registrarEncerramentoPartida`**, em
[`functions/src/rastreabilidade.ts:125`](../functions/src/rastreabilidade.ts).
Exige o claim `motorDePartidas` (ou `admin`), grava `matches/{matchId}` dentro de
uma transação, e é a **única porta**: `firestore.rules` nega toda escrita de
cliente em `matches`.

O documento gravado é o `RegistroDePartida.toJson()` do domínio Dart
(`app/lib/rastreabilidade/registro_partida.dart`), e é dele que esta OS deriva
tudo:

- `estado` — `finalizada` / `abandonada` / `cancelada` (terminais);
  `EstadoDaPartida.valeu` inclui as duas primeiras, e **não** `cancelada`;
- `ladoVencedor` — `nos` / `eles`. `null` só em partida viva ou anulada;
- `participantes[]` — `classe` (`humano` / `robo` / `convidado` / `espectador`),
  `userId`, `assento`, `lado`.

### 1.5 O débito de −10 já existia?

**Não.** Nenhuma ocorrência de débito por derrota em backend nem em cliente. Não
havia economia de resultado de partida em lugar nenhum — nem no servidor, nem no
Flutter. Não houve o que mover de camada e não há risco de processamento duplo
com um caminho antigo.

### 1.6 Identificadores únicos

- jogador: `uid` do Firebase Auth (o mesmo que `users/`, `usuarios/`,
  `playerEntitlements/` e `rankingLedger` já usam);
- partida: `matchId`, cunhado por quem tem autoridade e validado em
  `IdentidadePartida` — o cliente nunca o escolhe.

### 1.7 Livro-razão e idempotência reutilizáveis

Três precedentes, todos com a mesma disciplina (o recibo e o efeito na MESMA
transação), e nenhum deles servia direto:

| Existente | Chave | Por que não serviu |
|---|---|---|
| `fichasConcessoes` | `{purchaseTokenHash}_{indice}` | indexado por compra da Play; não há token numa partida |
| `rankingLedger` | `matchId\|userId\|motivo` | é pontuação competitiva; `ledger_competitivo.dart` declara que fichas e economia **não** passam por ele |
| `compras/{hash}` | hash do `purchaseToken` | validação de compra |

O que se reutilizou foi o **padrão**, não a coleção: chave determinística, recibo
e saldo na mesma transação, repetição como rotina e não como erro.

---

## 2. O que foi construído

Um codebase de Functions próprio, `functions-economia`, pelo mesmo critério que
`firebase.json` já aplica aos outros quatro: **são unidades de implantação
independentes**. Um deploy da economia básica não pode derrubar a validação de
compra na Play, e uma correção de RTDN não pode mexer no que o jogador ganha por
vencer.

```
functions-economia/
  economia.js        política, elegibilidade, piso e chaves — puro, sem Firestore
  economiaStore.js   a transação: recibo + saldo são a mesma escrita
  index.js           os gatilhos
  test/              63 testes, `node --test`, sem emulador e sem node_modules
```

### Autoridade

```
registrarEncerramentoPartida ──escreve──> matches/{matchId}
                                                │
                                    (gatilho onDocumentWritten)
                                                ▼
                                       aoRegistrarPartida
                                                │
                          movimentosDoResultado(registro server-owned)
                                                ▼
                       economiaLedger/{chave}  +  usuarios/{uid}.fichas
                              (uma única transação por movimento)
```

O resultado da partida é um **gatilho de Firestore**, e não uma callable, porque
é a forma mais forte de autoridade que existe: o cliente não consegue invocá-lo,
não consegue deixar de invocá-lo, e não tem por onde passar parâmetro. A entrada
de `movimentosDoResultado` é o registro server-owned e mais nada — não há
assinatura por onde declarar vitória, valor ou saldo.

### Idempotência

| Movimento | Documento em `economiaLedger` |
|---|---|
| boas-vindas | `boas_vindas\|{uid}` |
| vitória | `partida\|{matchId}\|{uid}\|vitoria_partida` |
| derrota | `partida\|{matchId}\|{uid}\|derrota_partida` |

O id do documento **é** a chave. Criar o recibo e alterar o saldo é a mesma
escrita, dentro de `runTransaction`: não existe instante em que o saldo mudou e o
recibo não está anotado. Quem chegar depois lê o recibo e devolve `ja_lancado`,
sem tocar no saldo e sem erro.

Isso cobre, com uma barreira só: retry, reconexão, callback repetido,
reprocessamento administrativo, entrega duplicada do gatilho (o Firestore é
at-least-once) e duas Functions concorrentes.

### O piso, e por que não é `FieldValue.increment`

`increment(-10)` não sabe parar no zero — um jogador com 6 fichas terminaria com
−4. O saldo é **lido dentro da transação** e gravado como valor absoluto. É
seguro sob concorrência porque o documento lido entra no conjunto de versões
conferidas no commit: um crédito de billing no meio do caminho invalida a
transação, que roda de novo contra o saldo novo (provado em `CAR-28`).

O recibo grava os dois números:

```
saldo 6, derrota  ->  deltaNominal: -10   delta: -6   saldoAntes: 6   saldoDepois: 0
```

`delta` é o efetivo, para `antes + delta == depois` valer em toda linha — a mesma
invariante de `LancamentoCompetitivo`. `deltaNominal` fica ao lado para a
auditoria distinguir "a política cobrou 10" de "a carteira só tinha 6".

---

## 3. Empate — o baseline, preservado

**Empate não existe no domínio, e esta OS não criou regra para ele.**

- `MotivoEncerramento.metaAtingida`: "alguém cruzou a meta de pontos **sem empate
  exato**";
- `capturarDesfecho` (`app/lib/motor/desfecho_partida.dart:562`) **estoura** se um
  placar empatado for marcado como encerrado;
- `DesfechoCanonicoPartida` **exige** `ladoVencedor` em todo motivo que não seja
  `anulada`.

Ou seja: não há hoje caminho que grave `finalizada` sem vencedor. O que esta OS
faz é não pagar nada quando o vencedor não for afirmável (`partida_sem_vencedor`)
— que é o mesmo zero que já valeria. Coberto em `ECO-25`.

---

## 4. Contas preexistentes

**Resolvidas sem migração, sem varredura e sem alterar dado histórico.**

A chave `boas_vindas|{uid}` é a única coisa que decide. Uma conta criada antes
desta OS simplesmente ainda não tem recibo: a primeira chamada credita os 100
dela, a segunda não credita. Não existe janela em que duas execuções creditem
duas vezes, e o saldo que a conta já tinha é **somado**, não substituído
(`CAR-06`: 1500 → 1600, e a segunda chamada mantém 1600).

A alternativa perigosa — varrer contas e creditar em lote — **não foi executada**,
conforme a OS manda: ela exigiria tocar dado histórico e criaria risco de crédito
duplicado que a via idempotente não tem.

---

## 5. Elegibilidade por modalidade — DECISÃO FECHADA

A ambiguidade levantada na entrega anterior foi resolvida na revisão da OS. A
política aprovada, implementada em `tipoMoveCarteira()`:

| Modalidade | Vitória | Derrota | Por quê |
|---|---|---|---|
| `publica_casual` | **+15** | **−10** | disputa humana real |
| `publica_ranqueada` | **+15** | **−10** | disputa humana real |
| `torneio` | **+15** | **−10** | disputa humana real |
| `treinamento` | **0** | **0** | treino não gera economia |
| `contra_robos` | **0** | **0** | seria o farm mais barato do produto: o bot não reclama de perder e a mesa reinicia sozinha |
| `privada` | **0** | **0** | o dono da sala escolhe os adversários — dois jogadores combinariam quem perde e quem ganha e fabricariam saldo em par |

### Lista de permissão, e não de exclusão

`TIPOS_QUE_PAGAM` enumera as três modalidades que pagam. A diferença só aparece
no dia em que alguém acrescentar uma modalidade: com lista de exclusão, ela
passaria a pagar sozinha, sem ninguém decidir. Aqui ela **não paga** até ser
escrita na constante — e "não paga" é o erro barato dos dois.

Pelo mesmo critério, `tipo` **ausente, nulo ou desconhecido não paga** (`ECO-27e`).

### Por que não é `TipoDePartida.alteraRanking`

Apesar de o resultado quase coincidir, aquele predicado vale só para
`publica_ranqueada` e `torneio`, e deixaria a **`publica_casual` de fora** — que é
disputa humana de verdade. "Vale ranking" e "movimenta fichas" são duas decisões
independentes, e `ledger_competitivo.dart` já declara em texto que economia e
fichas **não** passam pelo critério de ranking. Amarrar as duas faria uma mudança
de política de ranking mexer em dinheiro sem querer.

### Proteção contra regressão

| Teste | O que trava |
|---|---|
| `ECO-27` | `contra_robos` → 0 |
| `ECO-27b` | `treinamento` → 0 |
| `ECO-27c` | `privada` → 0 |
| `ECO-27d` | a tabela inteira, tipo a tipo, e cai se `TIPOS_QUE_PAGAM` ganhar ou perder membro |
| `ECO-27e` | tipo ausente/desconhecido → 0 |
| `CAR-23b` | ponta a ponta: nenhuma escrita chega ao banco, `db.commits == 0` |
| `CAR-23c` | 100 mesas contra robôs vencidas seguidas rendem **exatamente 0** |

### Observação residual, para uma decisão futura — não implementada

A regra é por **modalidade**, então uma mesa `publica_casual` ou
`publica_ranqueada` **com robô sentado** paga normalmente. O domínio permite isso
(`TipoDePartida.roboEsperado` é falso para elas, mas nada no registro proíbe um
robô no assento), e o registro já carrega `temRobo` — o dado para fechar essa
porta existe.

Não foi implementado porque a decisão aprovada é explicitamente por modalidade, e
estender por conta própria seria inventar regra. Fica registrado aqui como
observação, junto do item de §8.

---

## 6. O que NÃO foi tocado

Nenhuma linha de: `functions-billing/` (VIP, RTDN, Scheduler, catálogo,
`master_vip`, planos-base), `firebase/functions/` (Kit Fundador/Pioneiro),
`functions/` (torneios, prêmios, rastreabilidade), `functions-moderacao/`, e o
bloco 2/3 de `firestore.rules` onde `usuarios/{uid}` é declarado.

Regressão provada, não presumida: 103 testes de billing e 13 de moderação
verdes, e `ECON-10`/`ECON-11` no emulador provam que a carteira continua fechada
ao cliente.

## 7. Correção que a suíte de regras pegou

A primeira versão da regra de `economiaLedger` copiou o formato de
`rankingLedger` (`allow read: ... || ehAdmin()`). O teste `ECON-03` reprovou: num
`list`, o predicado é avaliado documento a documento, e `ehAdmin()` — que não
depende de documento nenhum — autorizava a varredura da **coleção inteira**. Um
`getDocs('economiaLedger')` traria a economia do jogo toda: quem joga, quanto
ganha, com que frequência e contra quem.

A regra final separa os verbos:

```
match /economiaLedger/{chaveIdempotencia} {
  allow get:  if autenticado()
              && (resource.data.uid == request.auth.uid || ehAdmin());
  allow list: if false;
  allow write: if false;
}
```

Escrita negada a todo mundo, inclusive ao admin pelo cliente, e o motivo é
direto: o id do documento **é** a chave de idempotência, então quem conseguisse
criar um documento ali a mão **cancelaria o próprio débito de derrota** — bastaria
plantar `partida|{matchId}|{uid}|derrota_partida` vazio e o gatilho encontraria o
recibo e não debitaria. Fraude sem precisar mentir sobre o resultado. `ECON-06`
prova que está fechado.

## 8. Pendências REGISTRADAS — fora do escopo desta OS

Nenhuma das duas foi corrigida aqui, por decisão expressa da revisão: evitar
expansão de escopo.

### 8.1 `rankingLedger` provavelmente é varrível pelo admin

O mesmo defeito que §7 descreve e que corrigi em `economiaLedger` existe, pelo
formato, na coleção vizinha:

```
match /rankingLedger/{chaveIdempotencia} {
  allow read: if autenticado()
              && (resource.data.userId == request.auth.uid || ehAdmin());
  allow write: if false;
}
```

`allow read` cobre `get` **e** `list`. Num `list`, o predicado é avaliado
documento a documento, e `ehAdmin()` — que não depende de documento nenhum —
autoriza um `getDocs('rankingLedger')` sobre a coleção inteira. A escrita
continua fechada; o que vaza é leitura em massa do histórico competitivo.

**Correção provável:** separar os verbos, como em `economiaLedger`
(`allow get: …` + `allow list: if false`), e servir o extrato paginado por
`consultarExtratoCompetitivo`, que já existe e já faz exatamente isso.

**Encaminhamento:** OS específica de segurança/regras. Vale conferir, no mesmo
passe, todas as coleções que usam `allow read` com `|| ehAdmin()`.

### 8.2 Robô em mesa pública

Ver §5, "Observação residual". A modalidade paga; o participante robô não recebe
nada (não tem conta), mas o humano da mesa recebe. Fechar essa porta exigiria
decisão comercial nova.

## 9. Como rodar

```bash
cd functions-economia && npm test
```

```bash
cd firebase/testes && npm run emulador-economia
```

Numa máquina sem Java no PATH mas com Android Studio instalado, o JBR serve:

```bash
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" PATH="$JAVA_HOME/bin:$PATH" npm run emulador:integrado
```
