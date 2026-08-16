# Recuperação dos metadados legados VIP — `planoBase`, `inicioEm` e a aptidão real

**Veredito: `planoBase` é recuperável. `inicioEm` NÃO é. Nenhum direito migrado
fica apto à ficha mensal por recuperação de dado — e a população real, medida, é
zero.**

Esta OS auditou, provou e implementou o **diagnóstico**. Não implementou rotina
de escrita, e a ausência é uma decisão registrada (§9). Nenhuma escrita foi
executada, nenhum deploy foi feito, nenhuma ficha foi concedida.

---

## 1. Git

| | |
|---|---|
| Branch | `claude/recuperacao-metadados-legados-vip` |
| Base | `92a9fa0` (`claude/backfill-purchasetokenhash-4f3365`) |
| Ancestralidade verificada | `e9c2aa1` ✓, `921f3fd` ✓, `0ea96c2` ✓, `fe4cdb5` ✓ — todos ancestrais |
| Merge indevido | nenhum; o trabalho é linear sobre `92a9fa0` |
| Módulo novo | `functions-billing/recuperacaoMetadados.js` |
| Callable | `diagnosticarMetadadosLegados` (só admin, **somente leitura**) |
| Testes novos | `test/recuperacaoMetadados.test.js` (44), `test/recuperacaoEfeitos.test.js` (16) |
| `main` | não tocada |

## 2. Fontes históricas

`validarCompraPlay` teve **cinco gerações**. Em todas elas o bloco de concessão
de assinatura grava exatamente os mesmos três campos em `compras/{hash}`:

| Geração | Commit | Data | `concessao` gravado |
|---|---|---|---|
| 1 | `767b74a` | 06/08/2026 | `vip`, `vipExpiraEm`, `planoBase` |
| 2 | `32b6709` | 06/08/2026 | idem |
| 3 | `fe4cdb5` | 10/08/2026 | idem |
| 4 | `f2b06c1` / `4ef296e` | — | idem |
| 5 | `83a522b` | — | idem |

Em todas, `planoBase = lineItems[0].offerDetails.basePlanId`. **Nenhuma jamais
persistiu `startTime`.** `startTime` só passou a ser *lido* em `f2b06c1`, já
dentro de `consolidarAssinatura`, e dali vai para `playerEntitlements` — nunca
para `compras/`.

### A tabela que a OS pede

| Campo | Fonte | Evidência histórica | Confiabilidade |
|---|---|---|---|
| `purchaseTokenHash` | id do documento `compras/{hash}` | `chaveDaCompra = sha256(token)`, e o resultado é a chave. Desde `767b74a` | **Alta** — é o mesmo valor que `chaveDaCompra` produziria |
| `planoBase` | `compras/{hash}.concessao.planoBase` | `lineItems[0].offerDetails.basePlanId`, gravado idêntico nas 5 gerações | **Alta** — e não é leitura nova: o caminho de produção de hoje já lê esse campo para creditar a parcela 0 |
| `inicioEm` | **não existe** | nenhuma geração persistiu `startTime` | **Nula** |

### As datas que existem e não servem

`compras/{hash}` tem três datas. Nenhuma é `inicioEm`, e o diagnóstico as **nomeia
e recusa** em vez de ignorá-las (`REC-31`):

| Data | O que é | Por que não serve |
|---|---|---|
| `criadoEm` | `serverTimestamp()` da criação do registro | é quando **este sistema validou**, não quando a assinatura começou na Google. Divergem em toda reentrega da Play (troca de aparelho, reinstalação) — justamente o caso comum de quem tem compra antiga |
| `concedidoEm` | `serverTimestamp()` da concessão | idem, alguns segundos depois |
| `concessao.vipExpiraEm` | fim do período cobrado | menos o ciclo daria o início do **último** período, não da assinatura. E como o índice 0 é a **ativação**, isso pagaria o bônus de ativação de novo a cada renovação |

`orderId` também está persistido, mas é um identificador da Google, não uma data.

**`REC-30` fixa o esquema histórico completo de `compras/{hash}` em código** —
todos os campos que já existiram nas cinco gerações — e prova que, com tudo
preenchido, `inicioEm` continua `SEM_FONTE`. Se alguém decidir um dia que
`criadoEm` "dá para usar", esse teste quebra antes da revisão humana.

## 3. Critérios AUTO

### `planoBase`

AUTO quando, entre as compras **atribuíveis** ao uid:

1. pelo menos uma está `concedida` e registrou `concessao.planoBase`;
2. todos os planos registrados são **o mesmo valor**;
3. o entitlement **não** tem `planoBase` gravado.

"Atribuível" é o mesmo critério de `titularDoToken` e de `classificarBackfill`:
`dados.uid === uid` **e** `dados.assinatura === true`. A repetição é deliberada —
se a fonte do plano fosse mais frouxa que a do hash, uma compra incapaz de dar
identidade ao direito poderia dar **plano** a ele (`EFE-22`).

Duas compras concedidas com planos **diferentes** → `AMBIGUO`. Não há desempate
por data, por ordem, nem por "a mais recente" (`REC-06`, `REC-08`). Duas compras
com o **mesmo** plano → `AUTO`, porque não há escolha a fazer: qualquer compra
daria o mesmo valor (`REC-07`).

### `inicioEm`

**Não há critério AUTO.** A função `avaliarInicioEm` não tem ramo de recuperação,
e a ausência é o resultado da investigação, não um esquecimento. Ela recebe as
compras assim mesmo — sem usá-las para produzir valor — porque é isso que torna a
auditoria verificável.

### Preservação

Valor existente **nunca** é sobrescrito. Se o valor atual contradiz a fonte
histórica, a classe é `INCONSISTENTE` e nada é corrigido automaticamente
(`REC-10`, `EFE-16`).

## 4. População: as classes

| Classe | Significado |
|---|---|
| `JA_CONSISTENTE` | os três campos já existem |
| `AUTO_RECUPERAVEL` | tudo que falta é recuperável **e** o entitlement fica apto |
| `AUTO_PARCIAL` | parte é recuperável, mas sobra ausência que impede a aptidão |
| `AMBIGUO` | algum campo tem duas ou mais fontes plausíveis |
| `IRRECUPERAVEL` | nada do que falta tem fonte |
| `INCONSISTENTE` | algum valor atual contradiz a fonte histórica |
| `FORA_DO_ESCOPO` | não há entitlement, ou não há documento interno |
| `NAO_INVESTIGADO` | a correlação com `compras/` não rodou |

As classes são exclusivas e a soma fecha com `examinados` (`REC-25`). A ordem de
decisão é de recusa: **contradição vence ambiguidade, que vence ausência**
(`REC-19`).

## 5. Aptidão às fichas: antes → depois

Aptidão é a **conjunção**: os três campos presentes **e** direito vigente. Não
existe aptidão parcial — faltando um, `concederFichasMensais` não paga nada.

| Classe | Antes | Depois da recuperação | Prova |
|---|---|---|---|
| `JA_CONSISTENTE` | recebe | recebe, sem mudança | `EFE-10` |
| só o hash faltando | 0 parcelas (`semPlano`) | **recebe** | `EFE-11` |
| só o plano faltando | 0 parcelas (`semPlano`) | **recebe** | `EFE-12` |
| **direito migrado típico** | 0 parcelas | **0 parcelas** | `EFE-13` |
| `AMBIGUO` | 0 | 0 | `EFE-14` |
| `IRRECUPERAVEL` | 0 | 0 | `EFE-15` |
| `INCONSISTENTE` | inalterado | inalterado | `EFE-16` |

**`EFE-13` é o resultado desta OS.** No direito migrado, hash e plano são
recuperados — e nenhuma ficha se move, porque `inicioEm` não tem fonte e
`mesesDecorridos(null, …)` devolve `-1`. Dois campos preenchidos, zero efeito. E
a ausência é **silenciosa**: depois da recuperação nem `semPlano` acusa mais; o
jogador é visitado pela varredura e sai sem nada.

## 6. Monotonicidade — a recuperação não amplia direito

`EFE-20` varre combinatoriamente titular × tipo × estado (3 × 2 × 3) e afirma que
`AUTO` aparece em **exatamente uma** célula: `u1 / assinatura=true /
estado=concedida`. Nas outras dezessete, nada é recuperado.

- o plano de outra assinatura nunca vaza para este entitlement (`EFE-21`);
- a fonte do plano e a do hash usam o mesmo critério de titularidade (`EFE-22`);
- recuperar metadado nunca torna apto quem não tem direito vigente — testado com
  expirado, vencido, reembolsado e sem prazo (`EFE-23`).

## 7. Auditoria do ciclo de fichas

| Pergunta | Resposta | Prova |
|---|---|---|
| mês civil ou intervalo? | **mês civil** — início 31/01 completa o mês 1 em 28/02 | `EFE-30` |
| qual é o mês zero? | índice 0 = **ativação**, vence no dia da compra | `EFE-30` |
| qual parcela vence primeiro? | a 0 | `EFE-30` |
| há limite de parcelas? | `TETO_PARCELAS_POR_TICK = 24`, **por jogador por tick** — não é limite da política | `EFE-33` |
| há deduplicação? | sim, `fichasConcessoes/{hash}_{indice}` | `EFE-31` |
| data antiga gera concessão retroativa? | **sim, e grande** | `EFE-32` |

### O lote retroativo (gate de produção)

Com `inicioEm` três anos no passado, a **primeira** varredura liquida o teto
inteiro de uma vez: **24 parcelas = 1.500 + 23 × 1.000 = 24.500 fichas** para um
único jogador, num único tick (`EFE-32`). É por isso que "arredondar" a data não
é detalhe: `inicioEm` é o marco zero do índice, e errar a data erra **quantas
parcelas** o jogador recebe.

### Defeito pré-existente encontrado pelo teste

`fichas.js` afirma, no cabeçalho de `TETO_PARCELAS_POR_TICK`, que *"o que passar
disso é entregue no tick seguinte — nunca perdido"*. **Isso não é o que
acontece.** `indicesDevidos` fatia sempre a partir do índice 0:

```js
const limite = Math.min(total, teto);
for (let i = 0; i < limite; i += 1) indices.push(i);
```

Ela não pula o que já foi pago. O tick seguinte recomputa os mesmos `0..23`,
encontra todos liquidados e devolve zero. **As parcelas 24..N nunca chegam** — e
a varredura segue anunciando `truncados: 1` para sempre (`EFE-34`).

O defeito é **anterior a esta OS** e hoje é inalcançável: o plano mais longo tem
12 parcelas e ninguém acumula 24. Ele passa a ser alcançável exatamente se
`inicioEm` for preenchido com data antiga — a operação que esta OS avaliava. Fica
registrado como bloqueador de qualquer OS futura que resolva a fonte de
`inicioEm`; **não foi corrigido aqui**, porque corrigi-lo mexe em quanto o
jogador recebe e isso é decisão comercial, não de auditoria.

## 8. Casos não recuperáveis, e o motivo exato

| Situação | Classe | Motivo |
|---|---|---|
| entitlement migrado do legado | `AUTO_PARCIAL` | `inicioEm` nunca foi persistido por nenhuma geração |
| sem nenhuma compra atribuível | `IRRECUPERAVEL` | não há fonte para campo nenhum |
| compra de outro titular | `INCONSISTENTE` | `uid` do registro diverge |
| compra que não é assinatura | `SEM_FONTE` | não é atribuível — mesmo critério de `titularDoToken` |
| compra em `em_validacao` ou `recusada` | `SEM_FONTE` | não provou ter concedido direito |
| duas compras com planos distintos | `AMBIGUO` | upgrade/downgrade/resubscribe sem regra histórica que diga qual originou o direito |
| plano gravado ≠ plano da fonte | `INCONSISTENTE` | contradição; exige olho humano |
| direito vencido ou estornado | qualquer | não receberia ficha nem completo |

## 9. Por que não há rotina de escrita

A OS condiciona a implementação a *"somente se tecnicamente seguro"* (§2) e trata
o modo de escrita como hipótese (*"Se for implementado…"*, §12). A decisão foi
**não implementar**, e o motivo é o resultado da própria auditoria:

`planoBase` é recuperável, mas preenchê-lo sozinho **não entrega uma ficha
sequer** ao direito migrado, porque `inicioEm` continua ausente (`EFE-13`). Uma
rotina de escrita para esses campos seria código que altera documento de pagante
em troca de zero efeito — e criaria exatamente o mal-entendido que este relatório
existe para evitar: *"os campos foram preenchidos, logo o jogador voltou a
receber"*.

Quando e se `inicioEm` ganhar uma fonte, a escrita se faz com o padrão já pronto
de `backfillHashStore.js` (transação, precondição relida, marca de procedência).

## 10. Garantias estruturais

- **Somente leitura por construção**: o módulo não recebe `db`, só leitores, e não
  importa nenhum store. `REC-40` lê o próprio fonte e falha se `.set(`, `.update(`,
  `.delete(`, `runTransaction`, `FieldValue` ou um `require('./backfillHashStore')`
  aparecerem.
- **O classificador do hash é consumido, não reimplementado** (`REC-41`): não há
  `createHash` nem `chaveDaCompra` neste módulo. Duas regras para o mesmo campo
  divergiriam.
- **Determinismo**: reexecutar sobre os mesmos dados devolve o mesmo número
  (`REC-34`); o banco sai com a mesma versão documento a documento (`REC-35`).
- **Paginação** por cursor sobre `documentId()`, parada por esgotamento,
  fronteiras em 0/1/199/200/201 derivadas de `TAMANHO_PAGINA` (`REC-28`);
  resultado independe do tamanho de página e a retomada soma (`REC-29`).
- **Sem identidade no retorno**: as amostras não carregam uid nem valor recuperado
  (`REC-37`).

## 11. Documento público e Rules

Esta OS **não escreve nada**, então a questão é vacuosa por construção — mas a
propriedade continua provada a montante: `purchaseTokenHash` mora no documento
interno, e `BFH-33` (OS anterior) demonstra que o documento público sai byte a
byte igual.

`firestore.rules` não foi tocada. `playerEntitlements/{uid}/interno/**` já é
`allow read, write: if false` para cliente **e** admin — só o Admin SDK alcança.
Nenhum arquivo Dart foi alterado: nenhum dos três campos atravessa a fronteira do
cliente. Portanto os gates de Rules e Flutter não precisam ser reexecutados.

---

# 12. GATES DE DECISÃO

### GATE A — `planoBase` é recuperável de forma determinística?

**SIM.** Fonte: `compras/{hash}.concessao.planoBase`, persistida idêntica nas
cinco gerações de `validarCompraPlay` desde `767b74a`. Não é leitura nova: o
caminho de produção atual já trata esse campo como autoritativo para creditar a
parcela de ativação.

Ressalva de fidelidade: as gerações históricas gravaram `lineItems[0]`, enquanto
`consolidarAssinatura` hoje escolhe o item de **maior expiração**. Para assinatura
de item único são idênticos; divergem só em troca de plano no meio do período — e
esse caso cai em `AMBIGUO` ou `INCONSISTENTE`, nunca em `AUTO`.

### GATE B — `inicioEm` é recuperável de forma determinística?

**NÃO.** Nenhuma das cinco gerações persistiu `startTime`. As três datas que
existem em `compras/` são carimbos de validação deste sistema ou o fim do período
cobrado — nenhuma é o início da assinatura na Google, e usar qualquer uma seria a
inferência que a OS proíbe.

### GATE C — Quantos entitlements legados podem ser restaurados integralmente?

**Zero. Por dois motivos independentes, e é importante não confundi-los.**

1. **Estrutural**: nenhum direito *migrado* pode ser restaurado integralmente,
   porque `inicioEm` não tem fonte. Isso vale para qualquer população, em
   qualquer momento — é propriedade do dado histórico, não do tamanho da base.
2. **Empírico**: a população legada real é **zero**. O censo rodou em 15/08/2026
   contra `buraco-master-vip` (commit `c885eff`, branch
   `claude/legacy-vip-population-census-e784c2`, **local — o push foi bloqueado**)
   e mediu universo 0 com `esgotou: true`. `usuarios/`, `playerEntitlements/`,
   `compras/` e `fichasConcessoes/` **não existem** na base. O único registro de
   billing é a notificação de teste do Play Console.

Percentual: indefinido — não se calcula percentual sobre denominador zero.

A classe `AUTO_RECUPERAVEL` **existe e funciona** (`EFE-11`, `EFE-12`), mas
alcança apenas entitlements que já têm `inicioEm` — ou seja, os escritos pela
Play, não os migrados.

### GATE D — Quantos continuarão incapazes de receber ficha mensal?

**Zero hoje, porque não há ninguém.** Estruturalmente, a causa única para o
direito migrado é `inicioEm` ausente — e ela é 100% da população migrada, seja
qual for o tamanho dela (`REC-14`, `REC-27`: `porBloqueio.inicioEm` = total de
migrados).

### GATE E — Executar só o backfill de `purchaseTokenHash` antes dos outros campos é comercialmente seguro?

| Dimensão | Resposta |
|---|---|
| **Segurança técnica** | **SIM.** Provado na OS anterior: das 14 situações, duas mudam de veredito, ambas restringindo; 864 combinações sem nenhuma passar de recusado para aceito; e ele **fecha** duas proteções hoje inexistentes (titularidade e desfecho terminal) |
| **Efeito funcional** | **NENHUM** sobre fichas. Sem `planoBase` e `inicioEm`, o direito migrado continua recebendo zero (`EFE-13`). O ganho real do backfill de hash é de **integridade de ciclo de vida**, não econômico |
| **Risco de interpretação** | **ALTO, e é o risco principal.** Um relatório dizendo "N hashes preenchidos" será lido como "N jogadores voltaram a receber ficha". Por isso o dry-run do hash já reporta `autoAptoAFicha` separado, e por isso este documento existe |

### GATE F — Há segurança suficiente para uma futura OS de aplicação real do backfill combinado?

**NÃO.** Bloqueadores, em ordem:

1. **`inicioEm` não tem fonte.** Sem resolvê-lo, o backfill combinado não entrega
   ficha a ninguém migrado. Qualquer solução exigirá **decisão comercial**
   (arbitrar uma data e assumir as consequências), não recuperação de dado — e
   isso está fora do que esta OS autoriza.
2. **O defeito do teto** (`EFE-34`): parcelas acima de 24 nunca são entregues.
   Inalcançável hoje, alcançável no instante em que uma data antiga for gravada.
3. **O lote retroativo** (`EFE-32`): até 24.500 fichas por jogador num tick,
   dependendo da data escolhida.
4. **`concederFichasMensais` não está implantada.** O codebase `billing` em
   produção é anterior à branch e não tem a função — a entrega mensal nunca rodou.
   Restaurar metadados para alimentar uma rotina que não existe é ordem invertida.
5. **População zero.** Não há a quem aplicar. A decisão sensata é arquivar o
   mecanismo e reabrir quando houver base — com a regra já escrita e testada.

---

## 13. Testes

| Suíte | Antes | Depois |
|---|---|---|
| `functions-billing` (`npm test`) | 249 | **309** |

60 casos novos: 44 em `recuperacaoMetadados.test.js` (REC-01..REC-42) e 16 em
`recuperacaoEfeitos.test.js` (EFE-10..EFE-34).

## 14. Confirmações

- Nenhum backfill real executado.
- Nenhuma alteração em produção.
- Nenhum deploy.
- Nenhuma concessão de fichas disparada.
- Nenhum usuário migrado, nenhuma assinatura alterada.
- Nada tocado na Play Console nem nos produtos Google Play.
- Nenhuma inferência comercial usada.
- Nenhum dado existente sobrescrito.
- Nenhum merge em `main`, nenhum force push.
- Nenhum caso ambíguo escondido sob fallback.
