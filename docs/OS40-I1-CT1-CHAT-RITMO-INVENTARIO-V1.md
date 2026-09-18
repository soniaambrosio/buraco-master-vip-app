# OS 40-I1-CT1 — `chatRitmo` na exclusão da própria conta

**Versão:** V1
**Base:** `d047857fb2e2f984b8d5deff155146958bac28d9`
**Estado:** candidata local, não publicada e não integrável isoladamente.

A CT1 isolada **não fecha a OS 40-I1**: enquanto a B1 não for corrigida, o
portão global continua legitimamente vermelho.

## 1. O que estava errado

`chatRitmo/{uid}` é declarada em `firebase/firestore.rules` e escrita pelo
backend a cada fala (`functions-moderacao/src/comunicacao.ts`). Ela **não
aparecia** na matriz de `functions-conta/src/inventario.ts`.

O guard de cobertura — `test/inventario.test.js`, que cruza a matriz com as
Rules — acusou, e é assim que ele foi desenhado para funcionar: coleção nova sem
destino escrito quebra a suíte. O vermelho de referência era exatamente um:

```
✖ toda colecao declarada em firestore.rules esta na matriz
  actual: [ 'chatRitmo' ]   expected: []
```

Acrescentar exceção ao teste seria o conserto errado. O certo é decidir o
destino do dado.

## 2. A decisão

| Campo | Valor |
|---|---|
| identificador | `moderacao.ritmoDeChat` |
| caminho | `chatRitmo/{uid}` |
| domínio | `moderacao` |
| classe | `APAGAR` |
| alcance | `{ modo: "docPorUid", colecao: "chatRitmo" }` |

**Por que APAGAR, e não reter.** O documento guarda estado operacional de ritmo
do próprio jogador: o histórico recente de envios (instante e id de cada fala),
as recusas seguidas e o bloqueio temporário que o freio anti-spam aplica.

Ele **não é sanção nem histórico disciplinar**, e a separação é deliberada no
projeto: a regra do Firestore manteve `chatRitmo` numa coleção própria
justamente para que contagem de rajada não virasse disciplina — quem guarda o
fundamento de uma punição é `playerModeration`, que continua `RETER`. O mesmo
vocabulário está escrito em `app/lib/comunicacao/limites.dart`: *"ISTO NÃO É
SANÇÃO... é um freio automático de minutos, sem julgamento e sem registro
disciplinar"*.

Não preserva direito, pontuação, prova nem vínculo de terceiro: é chaveado pelo
UID e descreve o ritmo daquele jogador, de mais ninguém. Encerrada a conta, não
existe agente legítimo que volte a falar por ela — não há rajada futura a frear,
e reter o documento seria guardar estado pessoal sem finalidade.

## 3. Os três arquivos, e por que são três

A §5 da ordem autorizava apenas `inventario.ts`. A execução demonstrou à Central
que o escopo não fechava, e o despacho **CT1-D1** levantou o STOP. A razão é
material, e vale registrar porque contraria a leitura natural do código:

**`executor.ts` não é genérico.** A matriz não dirige a execução. `EXECUCOES` é
uma tabela escrita à mão, uma função por etapa, e `itensDaEtapa` só aparece
dentro de `descreverEtapa`, cujo próprio docstring diz *"Não executa nada"* —
ela alimenta a **prévia** de `resumirExclusaoDeConta`. O campo `alcance` não é
lido por nenhum caminho de escrita.

Daí os três:

1. **`src/inventario.ts`** — a decisão. Sem ela, o guard de cobertura reprova.
2. **`src/plano.ts`** — o item entra na etapa `moderacaoDoJogador`. Sem isso,
   `itensAcionaveisForaDoPlano()` reprova: todo item acionável tem que estar em
   alguma etapa.
3. **`src/executor.ts`** — o efeito. Sem isso, a matriz mandaria apagar, a
   prévia **prometeria ao jogador** que o documento sai, e o documento
   continuaria no banco — com a suíte unitária inteira verde.

A linha do executor é uma só, e na forma que os vizinhos já usam:

```ts
await db().collection("chatRitmo").doc(ctx.uid).delete();
```

A chave é o uid, então não há consulta, e um `delete` de documento que pode não
existir é idempotente por construção no Firestore — a mesma forma de
`tentativasDeCodigo` na etapa `mesas`.

## 4. Provas

| Gate | Antes | Depois |
|---|---|---|
| `npm test` (unitário) | 81 testes, 80 passam, **1 falha**, exit 1 | **86 testes, 86 passam, 0 falhas**, exit 0 |
| `npm run test:emulador` | 37 casos | **42 casos, 42 passam, 0 falhas**, exit 0 |

O emulador roda sem credencial, contra o projeto de demonstração `demo-bmv`.

### 4.1 O que o emulador prova, nominalmente

- `chatRitmo/{uidExcluido}` **existe antes** e **não existe depois**;
- a exclusão **chega** à etapa `moderacaoDoJogador`, e isso é afirmado;
- `chatRitmo/{outroUid}` permanece inalterado, campo por campo;
- o retry continua idempotente;
- falha parcial e retomada não ressuscitam o documento;
- nenhuma sanção ou denúncia é apagada por consequência.

### 4.2 O caminho sai da matriz, de propósito

A suíte de emulador **semeia no caminho literal** e **confere pelo caminho
declarado na matriz** (`colecaoDoRitmo()`). As duas pontas são diferentes de
propósito: se ambas saíssem da matriz, uma matriz mentirosa combinaria consigo
mesma e a suíte passaria. É esse descasamento que amarra a declaração ao efeito
num executor que não lê `alcance`.

## 5. Controles adversariais

Executados em cópia externa, nunca na candidata.

| # | Mutação | Detectado por | Resultado |
|---|---|---|---|
| 1 | remover a entrada da matriz | `toda colecao declarada em firestore.rules esta na matriz` (nomeia `chatRitmo`) | 7 falhas |
| 2 | `APAGAR` → `RETER` | `a decisao e APAGAR`, `o estado disciplinar continua RETIDO ao lado dele`, `RETER e NAO_APLICAVEL nao tem alcance de execucao` | 4 falhas |
| 3 | `docPorUid` → `semAcao` | emulador: `a matriz deixou de dizer COMO alcancar o ritmo de fala` | 3 falhas no unitário, **5 no emulador** |
| 4 | adulterar o UID alvo no executor | `o contador do terceiro nao pode sumir por consequencia` | 5 falhas no emulador |

Nenhuma das quatro sobrevive.

## 6. O que esta ordem não fez

- Não tocou `firestore.rules`, índices, `functions-moderacao`, `functions-billing`,
  workflows, `scripts/ci` nem qualquer arquivo da OS 40-C10.
- Não mudou classe, alcance, campos ou justificativa de nenhum item preexistente
  da matriz. O diff é aditivo.
- Não criou tratamento especial de `chatRitmo` em lugar nenhum: a decisão está na
  matriz, a ordem no plano, e o efeito é uma linha na etapa que já existia.
- Zero dependência nova, zero acesso a projeto Firebase real, zero segredo.
