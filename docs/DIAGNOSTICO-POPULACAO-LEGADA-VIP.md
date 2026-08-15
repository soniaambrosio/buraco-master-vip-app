# Diagnóstico da população legada VIP e o impacto de `purchaseTokenHash`

Relatório técnico da OS **DIAGNÓSTICO DA POPULAÇÃO LEGADA VIP + IMPACTO DE
`purchaseTokenHash`**.

**Veredito: INSTRUMENTO ENTREGUE E PROVADO — E O CENSO FOI EXECUTADO CONTRA
PRODUÇÃO. Ver §14, que é o resultado real e substitui o "não respondida" do
quadro abaixo.**

**O censo mediu uma população legada de ZERO.** As três coleções do universo —
`usuarios/`, `playerEntitlements/` e `compras/` — não existem no Firestore de
produção. Nenhuma compra jamais foi processada: o único registro de billing na
base é a *notificação de teste* do Play Console. Não há ninguém para migrar,
ninguém perde ficha mensal, e o backfill de hash discutido em §4 não tem
destinatário. §14 traz a execução, a prova de que o zero é medição e não cano
entupido, e o que isso muda na recomendação de §11.

**O achado que mudou a pergunta da OS continua valendo para o futuro:
`purchaseTokenHash` NÃO é irrecuperável.**
Para todo jogador que virou legado por este codebase, o hash está gravado — como
*chave de documento* — em `compras/{hash}`, e alcançável por uma consulta
`where('uid','==',uid)`. Não é reconstrução nem aproximação: é o mesmo valor que
`chaveDaCompra` produziria. A migração grava `purchaseTokenHash: null` sobre um
dado que existe. Ver §4, que é o centro deste relatório.

---

## 0. O que esta OS pôde e o que não pôde responder

A OS termina quando conseguirmos responder, com números: *quantos usuários
legados existem, quais podem ser migrados com segurança e exatamente quantos
seriam prejudicados pela ausência de `purchaseTokenHash`?*

| A pergunta | Situação |
| --- | --- |
| **Como** classificar cada jogador, com critério reproduzível | **Respondida** — §2, §3, em código e em teste |
| **Por que** o migrado perde a ficha mensal, na cadeia inteira | **Respondida** — §5 |
| **Se** o hash é recuperável, e para quem | **Respondida** — §4 |
| **Quantos** jogadores há em cada categoria | **RESPONDIDA em §14** — zero, medido em produção. O texto abaixo é o estado desta OS *antes* da execução, e fica como registro de por que o número faltava |

O que impede o número é acesso, não código. O diagnóstico é uma callable de
admin: ela precisa estar implantada e ser executada contra o Firestore de
produção. Esta OS proíbe explicitamente publicar Functions e fazer deploy — com
razão, porque implantar para medir seria uma mudança de produção feita para
responder uma pergunta de leitura. Não existe, nesta árvore, cópia ou exportação
da base real: rodar o instrumento contra o emulador mediria dados sintéticos e
produziria um número falso com aparência de censo.

**A população legada continua desconhecida em cardinalidade, e este relatório não
finge o contrário.** O que mudou é que agora existe um instrumento pronto,
somente-leitura e provado, e que a resposta esperada não é mais a que a auditoria
anterior supunha. O procedimento de execução está em §9.

---

## 1. Base, escopo e garantias

| Item | Valor |
| --- | --- |
| Branch | `claude/legacy-vip-population-diagnosis-fc64f7` |
| Base | `correcao/vip-client-enforcement-beneficios-v1` @ `921f3fd` |
| Fonte canônica do direito | `playerEntitlements/{uid}` |
| Migração real executada | **não** |
| Entitlement alterado | **nenhum** |
| VIP concedido / fichas creditadas | **nenhum** |
| Deploy / merge / Rules / RTDN / Play Console | **nada tocado** |

A base não é `main`: `origin/main` é placeholder (`fb9edb5`). A branch foi
reposicionada sobre o fluxo VIP/Billing homologado antes de qualquer alteração.

### A garantia de somente-leitura é estrutural

`diagnosticoPopulacao.js` não recebe `db`, transação ou qualquer porta capaz de
escrever — apenas leitores. Um *dry-run* com `flag` booleano depende de o flag
estar certo em toda chamada; este depende de o código de escrita não existir.
Três provas, e nenhuma delas é uma promessa em prosa:

- **DIAG-31** lê o próprio fonte do módulo e falha se `.set(`, `.update(`,
  `.delete(`, `.create(`, `.add(`, `runTransaction`, `batch(` ou `FieldValue`
  aparecerem fora de comentário;
- **DIAG-32** fotografa `caminho@versão` de todo o banco antes e depois de uma
  varredura completa e exige igualdade. Compara **versão**, e não a lista de
  caminhos: sobrescrever documento existente não criaria caminho novo, e a
  checagem ingênua deixaria a escrita passar;
- a callable é fechada por `request.auth.token.admin !== true`, o mesmo portão de
  `migrarEntitlementsLegado`.

---

## 2. Universo analisado

### 2.1 Fontes consultadas

| Coleção | Papel | Leitura |
| --- | --- | --- |
| `usuarios/{uid}` | legado: `vip`, `vipExpiraEm`, `vipProdutoId` | varredura paginada |
| `playerEntitlements/{uid}` | fonte canônica: `estado`, `vipAtivo`, `expiraEm`, `origem` | varredura paginada + leitura por uid |
| `playerEntitlements/{uid}/interno/billing` | `purchaseTokenHash`, `purchaseToken` | leitura por uid |
| `compras/{hash}` | registro de titularidade; **o id é o hash** | consulta `where('uid','==',uid)` |

`billingEvents/` e `fichasConcessoes/` **não** são consultadas: a primeira é
trilha de mensagens do Pub/Sub e não descreve população; a segunda descreve o que
já foi pago, e não quem tem direito.

### 2.2 O universo é a UNIÃO, e essa foi a primeira correção de alcance

A versão anterior do diagnóstico (`diagnosticoLegado.js`, da auditoria de
prontidão) varria apenas `usuarios/`. Isso responde a pergunta errada: desde a
consolidação, **o Billing parou de gravar `vip` em `usuarios/{uid}`**. O
assinante comercial de hoje não está no legado — ele existe só em
`playerEntitlements/`, e era invisível. Perguntas como "quantos já têm entitlement
sem hash" (item 9 da OS) não têm resposta possível varrendo só o legado.

O universo agora é `usuarios/` ∪ `playerEntitlements/`, em duas fases:

1. **fase `usuarios`** — visita todo `usuarios/{uid}` e, para cada um, lê o
   entitlement e as compras correspondentes. Varre a coleção **inteira**, e não
   `where('vip','==',true)`: herdar o filtro da migração tornaria impossível
   desmenti-la, e é justamente o filtro que esconde o `vip` mal tipado do §3.4;
2. **fase `entitlements`** — visita `playerEntitlements/{uid}` e **pula** quem já
   tem documento em `usuarios/`. A deduplicação é uma leitura por uid, e não um
   conjunto em memória: o conjunto cresceria com a base e uma retomada por cursor
   nem teria como reconstruí-lo.

Cada uid é contado **uma vez**, em **uma** categoria. A soma das categorias fecha
com `examinados` — verificado em DIAG-25 e DIAG-29.

---

## 3. Critérios de classificação

Reproduzíveis por leitura de código: `classificarJogador` é uma função **pura**,
sem I/O e sem relógio próprio — o instante entra por parâmetro.

### 3.1 As categorias (exclusivas)

| Categoria | Critério exato |
| --- | --- |
| `fora_da_populacao` | `usuarios.vip !== true`, sem entitlement |
| `so_entitlement` | sem legado VIP, **com** entitlement — o assinante comercial normal |
| `ja_coberto_pela_play` | `vip === true` + entitlement com `origem !== 'legado_usuarios'` |
| `ja_migrado` | `vip === true` + entitlement com `origem === 'legado_usuarios'` |
| `migravel_vigente` | `vip === true`, sem entitlement, `vipExpiraEm` no futuro |
| `migravel_vencido` | `vip === true`, sem entitlement, `vipExpiraEm` no passado |
| `bloqueado_sem_prazo` | `vip === true`, sem entitlement, sem `vipExpiraEm` utilizável |
| `entitlement_orfao` | entitlement **sem** documento em `usuarios/{uid}` |
| `inclassificavel` | `vip` "verdadeiro" mas não booleano, e sem entitlement |

A projeção de `acao` espelha a **ordem de decisão real**: `decidirAtualizacao`
recusa toda proposta de `fonte: 'migracao'` sobre documento existente
(`legado_nao_sobrescreve`) e só depois a migração olha o prazo. Inverter a ordem
aqui faria o diagnóstico prometer escrita onde a migração não escreve.

### 3.2 Mapa para os dez itens pedidos pela OS

| # | População pedida | Onde ela aparece |
| --- | --- | --- |
| 1 | legado ativo com prazo válido | `migravel_vigente` + parte de `ja_coberto`/`ja_migrado` |
| 2 | legado ativo sem prazo | `bloqueado_sem_prazo` |
| 3 | legado vencido | `migravel_vencido` |
| 4 | já possuem `playerEntitlements` | `so_entitlement` + `ja_coberto` + `ja_migrado` + `entitlement_orfao` |
| 5 | entitlement comercial normal | `so_entitlement` + `ja_coberto_pela_play` |
| 6 | legado **e** entitlement | interseção `legado_e_entitlement` |
| 7 | potencialmente migráveis | ações `gravar_ativo` + `gravar_expirado` |
| 8 | migrados hoje ficariam sem hash | **100% de (7)** — a migração grava `null`, sempre |
| 9 | entitlement sem hash hoje | interseção `entitlement_vigente_sem_hash` |
| 10 | contraditórios / inclassificáveis | `inclassificavel` + contadores `porInconsistencia` |

As categorias **não** são mutuamente exclusivas do ponto de vista da OS — o item
6 é uma sobreposição por definição. Por isso o resumo tem três eixos separados:
`porCategoria` (exclusivo, soma = total), `porAlerta` e `porInterseccao`
(sobrepostos, contados por jogador).

### 3.3 Interseções medidas

`legado_e_entitlement` · `legado_e_entitlement_sem_hash` ·
`legado_ativo_e_evidencia_comercial` · `migravel_com_hash_recuperavel` ·
`migravel_sem_hash_recuperavel` · `sem_prazo_com_evidencia_comercial` ·
`entitlement_vigente_sem_hash` · `entitlement_vigente_sem_token` ·
`legado_vip_e_entitlement_sem_acesso`.

Um cruzamento genérico de todas as facetas produziria dezenas de números sem
leitor; estas são as combinações que mudam uma decisão.

### 3.4 Inconsistências (item 10), e por que `vip: 1` é o caso mais perigoso

| Inconsistência | O que significa |
| --- | --- |
| `vip_nao_booleano` | `vip` é `1`, `'true'`, `'sim'`… |
| `prazo_ilegivel` | `vipExpiraEm` presente e não interpretável como data |
| `entitlement_sem_estado` / `entitlement_sem_origem` | documento incompleto |
| `entitlement_ativo_sem_prazo` | `vipAtivo: true` sem `expiraEm` |
| `entitlement_ativo_vencido` | `vipAtivo: true` com `expiraEm` no passado |
| `migrado_com_hash` | `origem: 'legado_usuarios'` **com** hash — impossível por construção |
| `play_sem_hash` | origem da Play **sem** hash — impossível por construção |
| `multiplos_hashes_candidatos` | mais de uma assinatura em `compras/`, sem desempate |
| `compra_de_outro_titular` | registro devolvido para o uid registra outro dono |

`vip_nao_booleano` merece destaque: a migração filtra por
`where('vip','==',true)`, então **ela nunca vê esses documentos**. O efeito é o
mesmo de estar fora da população — mas afirmar que a pessoa não tem VIP seria
afirmar algo falso sobre ela. A diferença entre "não tem VIP" e "tem VIP gravado
num tipo que o código não lê" é a diferença entre um número e um incidente. Por
isso vira categoria própria (`inclassificavel`), e não silêncio.

Distinção deliberada: **campo ausente não é defeito**, campo presente e ilegível
é. `{ vip: true }` sem `vipExpiraEm` é `bloqueado_sem_prazo` limpo;
`{ vip: true, vipExpiraEm: 'ontem' }` é `bloqueado_sem_prazo` **com**
`prazo_ilegivel`. Só o segundo é corrupção (DIAG-11).

---

## 4. `purchaseTokenHash` — origem, disponibilidade e recuperação

### 4.1 De onde ele nasce no fluxo comercial normal

`chaveDaCompra(token) = sha256(token)` em hex
(`entitlementStore.js:54`). Ele é gravado em **dois** lugares, na mesma validação:

1. como **id de documento** de `compras/{hash}` — `index.js:288`;
2. como campo `purchaseTokenHash` de `playerEntitlements/{uid}/interno/billing` —
   `index.js:396`, e igualmente pelo RTDN em `rtdn.js:167`.

### 4.2 Onde existe informação correlacionável

| Fonte | Contém o token cru? | Contém o hash? | Liga ao uid? |
| --- | --- | --- | --- |
| `compras/{hash}` | não | **sim — é o id do documento** | **sim** (campo `uid`) |
| `playerEntitlements/{uid}/interno/billing` | sim (`purchaseToken`) | sim | sim |
| `billingEvents/{messageId}` | não | só `rotuloToken` (8 chars) | sim |
| `fichasConcessoes/{hash}_{indice}` | não | **sim — no id** | sim |
| Play Console / RTDN | sim, em evento futuro | — | só via `compras/` |

### 4.3 O achado: o hash é recuperável, e para uma população inteira

O cabeçalho de `migrarEntitlementsLegado` afirma que `compras/{hash}` guarda o
hash e nunca o token, e conclui que não há como reconsultar a Google. **As duas
coisas são verdade, e a conclusão não se estende ao hash:**

- **reconsultar a Google exige o TOKEN EM CLARO** (`interno.purchaseToken`), e
  esse de fato não existe para as compras antigas — irrecuperável, confirmado;
- **`concederFichasMensais` não precisa do token.** Ela precisa do **hash**, e só
  dele, para montar `fichasConcessoes/{hash}_{indice}`.

E o hash existe. Verificado no histórico, não inferido: em `fe4cdb5` — o commit
que criou este codebase — **a mesma transação** que gravava
`usuarios/{uid}.vip = true` (linhas 276-279) gravava `compras/{sha256(token)}`
com o `uid` do comprador (linha 185). Quem virou legado por este codebase tem o
próprio hash guardado, como chave, a uma consulta `where('uid','==',uid)` de
distância.

Isso **não** é reconstrução, aproximação ou palpite: é o mesmo valor que
`chaveDaCompra` produziria com o token em mãos — criptograficamente idêntico,
porque é literalmente o resultado dela, persistido. A validade semântica também
se sustenta: `compras/{hash}.uid` prova a titularidade, e `assinatura === true`
prova que é assinatura e não consumível.

**A migração grava `purchaseTokenHash: null` sobre um dado que está disponível.**

### 4.4 Onde ele é, de fato, irrecuperável

Três grupos, e o diagnóstico os separa em vez de somá-los:

1. **sem nenhum `compras/` de assinatura** — VIP concedido à mão, importado de
   outro sistema, ou anterior a este codebase. Para esses **não há hash em lugar
   nenhum desta árvore**, e a perda é definitiva (`hash_irrecuperavel`);
2. **mais de uma assinatura em `compras/`** — recuperável em princípio, mas não
   sem escolher, e escolher errado chavearia o livro-razão na assinatura errada
   (`hash_ambiguo`). Há um desempate determinístico: `compras/{hash}.concessao.vipExpiraEm`
   guarda, congelado, o prazo que aquela compra concedeu; quando exatamente um
   casa com `usuarios.vipExpiraEm`, a escolha deixa de ser palpite (DIAG-18);
3. **o token cru**, para qualquer legado — irrecuperável, sem exceção. Nenhuma
   reconsulta à Play é possível para essa população, e nada nesta OS muda isso.

### 4.5 É possível recuperar sem consultar produção?

**Não.** A recuperação é uma consulta a `compras/`, que só existe em produção.
Mas ela é **leitura**, cabe dentro da mesma callable de diagnóstico, e já está
implementada como a porta `lerComprasDoJogador`. Nada foi fabricado, nenhum
placeholder foi gerado e nenhum token inexistente foi inferido — o módulo apenas
**conta** quantos jogadores têm o hash disponível. Sem a porta ligada, ele
declara `correlacaoDeCompras: 0` e **se recusa a afirmar** que o hash é
irrecuperável (DIAG-14, DIAG-34): concluir "irrecuperável" de graça é a conclusão
mais cara possível.

### 4.6 Hash e token são campos diferentes — e conflacioná-los foi o erro

A versão anterior do diagnóstico emitia `sem_reconsulta_possivel` a partir da
ausência do **hash**. A reconsulta olha `interno.purchaseToken` (`index.js:783`).
São campos distintos com destinos distintos: o hash é **chave de livro-razão**, o
token é **credencial de consulta**. Tratar os dois como um só é o que fez a ficha
mensal do migrado parecer irreparável. Corrigido e fixado em DIAG-13.

---

## 5. Benefício mensal — a cadeia técnica completa

```
playerEntitlements/{uid}                       ← elegibilidade
  vipAtivo == true                                (consulta da varredura)
        │
        ▼
expiraEm no futuro                             ← vigência temporal
        │                                         fichasVarredura.js:105
        ▼
planoDoCatalogo(catalogo[produtoId], planoBase) ← política (configuracao/billing)
        │                                         :107 — sem plano → semPlano++
        ▼
interno.purchaseTokenHash                      ← IDENTIFICADOR / IDEMPOTÊNCIA
        │                                         :113-121 ◀── AQUI O MIGRADO PARA
        ▼
fichasConcessoes/{hash}_{indice}               ← concessão, na MESMA transação
                                                  fichasStore.js:72
```

### 5.1 A condição exata que exclui o migrado

`fichasVarredura.js:114-121`:

```js
const interno = await lerInterno(uid);
const hash = interno ? interno.purchaseTokenHash : null;
if (!hash) {
  semPlano += 1;
  return;
}
```

O migrado tem `vipAtivo: true`, tem `expiraEm` no futuro, atravessa o catálogo — e
**para na linha do hash**. Mantém o VIP e não recebe a parcela. Fixado como
comportamento conhecido em **VARR-14**, que continua verde: esta OS mediu, não
mexeu.

Consequência de contagem: ele é somado a `semPlano`, o mesmo balde de quem tem
produto fora do catálogo. Dois motivos distintos num contador só — quem lê o log
do tick não distingue "catálogo desconfigurado" de "migrado sem hash".

### 5.2 Risco de duplicação se a condição for relaxada

A idempotência mora **na chave**, não na varredura: `fichasConcessoes/{hash}_{indice}`
é criada na mesma transação do crédito. O `uid` foi deliberadamente deixado fora
da chave — se entrasse, dois uids disputando o mesmo token dariam duas linhas e
crédito dobrado.

Relaxar a condição sem substituir a chave por outra igualmente determinística
**remove a barreira inteira**: sem chave estável, cada tick diário credita de
novo. A varredura roda todo dia e não guarda checkpoint — a proteção é a chave, e
só ela.

### 5.3 Existe identificador alternativo determinístico e seguro?

**Sim, e é o hash de verdade** — recuperado de `compras/{hash}` (§4.3), não
inventado. Ele preserva idempotência entre reexecuções pela razão mais forte
possível: **é o mesmo valor** que a chave teria se a compra tivesse passado pelo
fluxo atual. Uma linha `fichasConcessoes/{hash}_0` escrita hoje pelo migrado e
uma escrita amanhã por um RTDN que traga o mesmo token **colidem corretamente**, e
o jogador não recebe duas vezes.

As alternativas fabricadas não têm essa propriedade e não devem ser consideradas:
`uid` como chave quebraria a defesa contra dois uids no mesmo token; um hash
sintético (`sha256(uid + expiraEm)`) colidiria de forma errada — divergiria do
hash real quando a assinatura renovasse, pagando a mesma parcela duas vezes por
chaves diferentes. **Nada disso foi implementado, e nenhum `purchaseTokenHash`
artificial foi gerado nesta OS.**

### 5.4 Alcance de uma eventual correção

| Fluxo | Afetado por preencher o hash a partir de `compras/`? |
| --- | --- |
| Ficha mensal (`concederFichasMensais`) | **sim** — é o objetivo |
| Ficha de ativação (índice 0) | **sim**, e é desejável: o índice 0 passa a ser pagável |
| RTDN / renovação | **não** — o RTDN traz o token e recalcula o hash; se coincidir, `decidirAtualizacao` reconhece `mesmoToken` e **herda** o direito em vez de duplicá-lo |
| Cancelamento / reembolso | **não** — dependem de `estado`, não do hash |
| Reconsulta manual | **não** — depende de `purchaseToken`, que continua ausente |

O ponto mais delicado, e que precisa de teste próprio antes de qualquer
implementação: preencher o hash **muda o resultado de `mesmoToken`** em
`decidirAtualizacao` (`entitlement.js:350` e `:421`). Hoje o migrado tem
`purchaseTokenHash: null` e nunca casa com proposta nenhuma; com o hash correto
ele passa a casar com o RTDN daquela assinatura — o que é o comportamento certo,
mas é uma mudança de caminho, não um preenchimento inerte.

**Nenhuma mudança de política foi implementada nesta OS.** §5 mede e descreve.

---

## 6. Escala e paginação

O diagnóstico **não tem teto silencioso**. O algoritmo mora uma vez só, em
`varredura.js`, e foi extraído nesta OS para `varrerPorPagina` — o mesmo laço que
`concederFichasMensais` já usa, agora sobre um leitor de página injetado, para
que o diagnóstico pudesse reusá-lo **sem receber `db`** (o que destruiria a
garantia do §1).

| Propriedade | Como |
| --- | --- |
| Ordenação estável | `orderBy(FieldPath.documentId())` — id não empata e não muda |
| Cursor | `startAfter(ultimoId)`, avançado **antes** do trabalho |
| Lote configurável | `tamanhoPagina`, padrão `TAMANHO_PAGINA` = 200 |
| Término | **por esgotamento** ("página menor que o lote"), nunca por contagem |
| Anti-laço-infinito | `maxPaginas` = 500, do **diagnóstico inteiro** e não por fase |
| Teto declarado | `esgotou: false` + `cursor: {fase, cursor}` |

Duas decisões que evitam erro de medição: o orçamento de páginas é do diagnóstico
inteiro — dar `maxPaginas` a cada fase dobraria em silêncio o limite pedido; e a
retomada carrega a **fase**, porque um cursor sem ela recomeçaria a varredura na
coleção errada.

`somarResumos` existe para que somar pedaços seja código testado, e não aritmética
no relatório final.

### Fronteiras exercitadas

DIAG-25 roda o censo completo em **0, 1, 199, 200, 201, 499, 500, 501 e 1.200**
registros — imediatamente antes, exatamente em cima e imediatamente depois de
`TAMANHO_PAGINA` (200), mais a faixa 499/500/501. Os números são **derivados** de
`TAMANHO_PAGINA`, não escritos à mão: mudar o tamanho de página move as
fronteiras junto. Em cada caso: `esgotou === true`, `cursor === null`,
`examinados === n`, e a soma das categorias fecha com `n`.

DIAG-26 cobre a virada: os documentos de índice 200 e 201 recebem estado
diferente dos demais, e são exatamente os que um cursor errado perde ou repete.
DIAG-30 prova que o resultado **não depende do tamanho da página** — o mesmo
censo com lotes de 200 e de 7 devolve resumos idênticos.

---

## 7. Privacidade do relatório

O retorno da callable e este documento carregam **contagens**, não pessoas.

- **nenhum uid**, e-mail, token de compra, hash de token, credencial ou secret;
- amostras (até 5 por categoria) carregam `rotulo` — 12 caracteres de
  `sha256(uid)`. Não reversível, mas **determinístico**: um operador que já
  suspeita de uma conta calcula o rótulo dela e confere se aparece, sem que o
  diagnóstico enumere ninguém. É a única forma de exemplo que não distribui
  identidade;
- amostras não carregam datas por jogador — o relatório se resolve com contagem;
- o log de produção leva o resumo e **não** as amostras: rótulo anônimo continua
  sendo um dado por jogador, e log não é lugar de lista de gente;
- DIAG-33 serializa uma amostra e falha se o uid ou o hash aparecerem nela.

---

## 8. A tabela da entrega

**As quantidades não estão preenchidas porque o censo não foi executado** (§0). As
demais colunas **não** dependem de dados: saem da leitura de `migracaoLegado.js`,
`fichasVarredura.js` e `entitlement.js`, e valem como estão.

| Categoria | Qtd. | % | Pode migrar hoje? | Impacto mensal | Risco |
| --- | ---: | ---: | --- | --- | --- |
| `migravel_vigente` **com** hash recuperável | — | — | **Sim**, tecnicamente segura | Perde a ficha **hoje**; evitável com o hash de `compras/` | Baixo |
| `migravel_vigente` **sem** hash recuperável | — | — | Sim, **com perda** | Perde a ficha, e a perda é definitiva | **Médio** — pagante ativo sem benefício |
| `migravel_vigente` com hash **ambíguo** | — | — | Sim, com perda | Perde a ficha; recuperável só após desempate | Médio |
| `migravel_vencido` | — | — | Sim (grava expirado) | Nenhum (expirado não recebe) | **Alto** — pode ser pagante que renovou e o legado não viu |
| `bloqueado_sem_prazo` | — | — | **Não** — a migração pula | Nenhum: some de todo registro | **Alto** — sumiço silencioso |
| `bloqueado_sem_prazo` **com** evidência comercial | — | — | **Não** | Nenhum | **Crítico** — há prova de pagamento e nenhum prazo |
| `ja_migrado` (sem hash, vigente) | — | — | Já migrado | **Não recebe ficha hoje** (VARR-14) | Médio — corrigível sem migrar |
| `ja_coberto_pela_play` | — | — | Não precisa | Normal | Baixo |
| `so_entitlement` (comercial normal) | — | — | Não se aplica | Normal | Baixo |
| `entitlement_orfao` | — | — | Não se aplica | Depende do hash | Médio — perfil apagado com direito vivo |
| `inclassificavel` (`vip` mal tipado) | — | — | **Não** — a query não o vê | Nenhum | **Alto** — invisível para a migração |
| `fora_da_populacao` | — | — | Não se aplica | Nenhum | Nenhum |

**"Exatamente quantos seriam prejudicados pela ausência de `purchaseTokenHash`"**
é, no retorno do instrumento, `porAlerta.sem_ficha_mensal` — e ele se decompõe,
por construção verificada em DIAG-29, em exatamente três parcelas que somam ele
mesmo:

```
sem_ficha_mensal = hash_recuperavel_de_compras   (perda EVITÁVEL)
                 + hash_ambiguo                  (perda evitável após desempate)
                 + hash_irrecuperavel            (perda DEFINITIVA)
```

O alerta conta **apenas quem tem benefício real a perder** — direito vigente hoje
ou vigente logo após a migração. A versão anterior o emitia também para direito
vencido, o que inflava a resposta com perda fictícia: expirado não receberia
ficha nem com hash (DIAG-03).

---

## 9. Como obter os números

Somente-leitura, mas exige a Function implantada — **fora do escopo desta OS**.

1. mesclar/publicar a branch e implantar **apenas** o Billing:
   `firebase deploy --only functions:billing`;
2. chamar `diagnosticarPopulacaoVip` com credencial `admin: true`.

```bash
firebase functions:call diagnosticarPopulacaoVip --data '{"amostrasPorCategoria":5}'
```

3. se o retorno vier com `esgotou: false`, repetir passando `cursor` do retorno
   anterior e **somar** os resumos com `somarResumos`;
4. conferir `correlacaoDeCompras === examinados`. Se for menor, a correlação
   rodou parcialmente e **"sem evidência" não pode ser lido como "sem compra"**.

Custo: 1 leitura de página + (2 leituras + 1 consulta) por jogador. Para uma base
de 10.000 usuários, ~30.050 leituras. `correlacionarCompras: false` reduz para
~20.050, e desliga exatamente a pergunta que motivou a OS.

---

## 10. Situação da migração, por grupo

**A. Tecnicamente segura para migrar com a regra atual**
`migravel_vigente` com hash recuperável — migra, mantém acesso, e a ficha volta
assim que o hash for preenchido. É a única fatia sem perda residual.

**B. Tecnicamente migrável, mas com perda de benefício**
`migravel_vigente` sem hash recuperável ou com hash ambíguo. Recebem o acesso e
não recebem a ficha. Perda definitiva no primeiro caso.

**C. Exige decisão comercial (não técnica)**
`bloqueado_sem_prazo` — não há prazo para reconstruir o direito. As duas leituras
possíveis (conceder cortesia, ou não migrar) dependem do número, e o número
depende do censo. O subgrupo **com evidência comercial** é o mais delicado: há
prova de que pagou.
`migravel_vencido` — migra como expirado. Se a assinatura renovou depois da última
escrita do legado, é rebaixamento de pagante, e o sistema não tem como saber
sozinho: sem token, não há o que perguntar à Google.

**D. Exige correção técnica prévia**
`inclassificavel` — o `vip` mal tipado precisa ser normalizado, ou a migração
nunca os verá. `entitlement_orfao` e `entitlement_ativo_vencido` precisam ser
investigados: o segundo em volume significa que a varredura de vencimento não
está rodando.

**E. Não deve ser migrada**
`ja_coberto_pela_play`, `ja_migrado`, `so_entitlement`, `fora_da_populacao`. Para
as três primeiras a migração já é inócua por construção — `decidirAtualizacao`
recusa com `legado_nao_sobrescreve`.

---

## 11. Recomendação técnica

**Recomendação: medir antes de migrar, e corrigir o hash antes de decidir política
comercial. Nesta ordem, e nenhuma etapa foi executada aqui.**

1. **Rodar o censo** (§9). Sem ele, qualquer decisão sobre `bloqueado_sem_prazo` e
   `migravel_vencido` é opinião. Custa leituras e não muda nada.
2. **Tratar o preenchimento do hash a partir de `compras/` como OS própria, e
   anterior à migração em massa.** É o item de maior alavancagem deste
   diagnóstico: converte a perda da ficha mensal de "consequência inevitável" em
   "recuperável para a fatia que o censo medir", e o dado que ela usa é genuíno.
   Precisa de OS própria porque muda o resultado de `mesmoToken` em
   `decidirAtualizacao` (§5.4) — não é preenchimento inerte.
3. **Só depois decidir a política** de `bloqueado_sem_prazo` e `migravel_vencido`,
   com o número na mão. Decisão comercial, e **não** há autorização para tomá-la
   aqui.
4. **Normalizar `vip` mal tipado** antes da migração em massa, senão essa fatia
   fica para trás em silêncio.
5. **Separar o contador `semPlano`** de `concederFichasMensais` em dois motivos
   (§5.1): hoje "catálogo desconfigurado" e "migrado sem hash" são o mesmo número,
   e serão lidos como o mesmo problema.

Nenhuma dessas decisões foi executada. Esta OS mediu o mensurável, construiu o
instrumento para o resto, e parou.

---

## 12. Portões

| Suíte | Antes | Depois |
| --- | ---: | ---: |
| `functions-billing` — `npm test` | 145/145 | **179/179** |
| `functions-billing` — `node --test` sem alvos (caminho do CI) | 146 | **180** |

O `+1` sem alvos é o fantasma conhecido: `node --test` solto executa
`test/apoio/firestore_falso.js` como arquivo de teste. `npm test` (alvos
explícitos) é o número honesto, e o novo arquivo foi **adicionado aos alvos** —
sem isso ele rodaria no CI e não no portão local.

Regressões relevantes, todas verdes: **VARR-01…15** (a paginação das fichas, cujo
laço foi refatorado nesta OS), **migracao.test.js** (a migração projetada pelo
diagnóstico) e **entitlement.test.js**.

Não executado, e por quê: a suíte de Rules (`firebase/testes`) — `firestore.rules`
**não foi alterada**, e a callable usa o Admin SDK, que ignora regras. A suíte
Flutter — nenhum arquivo Dart foi tocado.

## 13. Arquivos

| Arquivo | O quê |
| --- | --- |
| `functions-billing/diagnosticoPopulacao.js` | o diagnóstico. Renomeado de `diagnosticoLegado.js` (auditoria de prontidão) e estendido: universo em união, varredura completa, correlação com `compras/`. **Renomeado, e não duplicado**, para não criar dois classificadores concorrentes |
| `functions-billing/test/diagnosticoPopulacao.test.js` | 34 casos, DIAG-01…34 |
| `functions-billing/varredura.js` | `varrerPorPagina` extraído; `varrerPaginado` reescrito sobre ele. Comportamento inalterado (VARR-01…15 verdes) |
| `functions-billing/index.js` | a callable `diagnosticarPopulacaoVip`, admin-only |
| `functions-billing/test/apoio/firestore_falso.js` | `retrato()` — caminho + versão, para provar ausência de escrita |
| `functions-billing/package.json` | novo alvo de teste |

---

# 14. O CENSO REAL — execução contra produção

Esta seção é a entrega da OS **EXECUÇÃO CONTROLADA DO CENSO REAL**. As seções
1–13 acima descrevem o instrumento; esta descreve **o que ele mediu**.

## 14.A Execução

| Item | Valor |
| --- | --- |
| Projeto | `buraco-master-vip` (número `203886484007`) |
| Banco | `(default)` — **o único do projeto**, `FIRESTORE_NATIVE`, `southamerica-east1`, criado em `2026-02-24T03:53:35Z`, free tier |
| Região das Functions | `us-central1` |
| Lógica executada | `functions-billing/diagnosticoPopulacao.js` @ `e9c2aa1e40278b501f56be1b9d58f407385c7622` — carregada por `require` do próprio arquivo da árvore, sem cópia |
| Callable | `diagnosticarPopulacaoVip` — **não implantada e não invocada** (ver 14.A.2) |
| Transporte das leituras | REST do Firestore via servidor MCP do `firebase-tools` 15.26.0 |
| Credencial | a já guardada por `firebase login` (`soniia.ambrosio@gmail.com`, proprietário). Nenhum segredo foi lido, criado, exportado ou impresso |
| Data/hora | `2026-08-15T17:42:21.370Z` (campo `varridoEm` do relatório) |
| Deploy realizado | **NENHUM** |
| Escritas | **NENHUMA** |

### 14.A.1 Páginas, cursores e esgotamento

| Fase | Páginas | Lidos | Cursor final |
| --- | ---: | ---: | --- |
| `usuarios` | 1 | 0 | — |
| `entitlements` | 1 | 0 | — |
| **Total** | **2** | **0** | `null` |

`esgotou: true`, `cursor: null`. Não houve teto operacional, não houve retomada,
não houve segunda chamada — e portanto não há risco de perda ou duplicidade
entre páginas. Universo deduplicado: **0**. `tamanhoPagina` 200, `maxPaginas`
500 (os padrões de `varredura.js`); a primeira página de cada fase já voltou
vazia, que é a evidência de fim que o módulo exige (página menor que o tamanho
pedido).

### 14.A.2 Por que NÃO houve deploy — e por que isso não é um atalho

A OS autoriza "o mínimo necessário" e prefere implantar somente a função
diagnóstica. O mínimo necessário acabou sendo **zero**, por duas razões que se
somam:

1. **A callable não poderia ser invocada mesmo se implantada.**
   `diagnosticarPopulacaoVip` é `onCall` com portão
   `request.auth.token.admin === true`. Produzir um ID token com esse claim exige
   ou a senha de uma conta administradora, ou uma chave de conta de serviço para
   emitir custom token. Não existe chave de conta de serviço nesta máquina (nem
   no repositório, nem em ADC — verificado), e manusear senha é vedado. Implantar
   teria criado uma função de produção que eu não conseguiria chamar: risco sem
   contrapartida.

2. **O escopo do deploy seria muito maior que a função diagnóstica — e escreveria.**
   Este é o achado incidental mais relevante da execução. O que está implantado
   hoje no projeto é uma versão **anterior** do codebase `billing`:

   | Função | Em produção hoje |
   | --- | --- |
   | `validarCompraPlay` | sim |
   | `notificacoesPlay` | sim |
   | `reconciliarEntitlements` | sim |
   | `reconciliarEntitlementDoJogador` | sim |
   | `migrarEntitlementsLegado` | sim |
   | **`concederFichasMensais`** | **NÃO** |

   `concederFichasMensais` é `onSchedule` e **credita fichas**. Publicar o
   codebase `billing` a partir desta branch criaria essa função e a poria a rodar
   por agendamento — exatamente o que a OS proíbe ("NÃO conceder fichas"). Um
   `--only functions:billing:diagnosticarPopulacaoVip` evitaria isso, mas esbarra
   na razão 1.

   Registro-o aqui porque é fato de produção que ninguém tinha medido: **a
   entrega mensal de fichas nunca rodou em produção.** Hoje isso é inócuo (não há
   assinante), mas vira P0 no dia da primeira venda.

### 14.A.3 O código executado é o aprovado — e o que não é

Honestidade sobre a fronteira, porque ela importa para a validade do número:

- **É o aprovado, sem cópia:** `classificarJogador`, `acumular`, `resumoZerado`,
  `criarDiagnosticoPopulacao` e `varrerPorPagina` foram carregados por `require`
  do arquivo da árvore em `e9c2aa1`. Nenhuma regra foi reescrita, reimplementada
  ou parafraseada.
- **Não é o aprovado:** as cinco portas de leitura. Em vez de
  `criarPortasFirestore` (Admin SDK), foram ligadas à REST do Firestore pelo
  transporte descrito acima, documento a documento com a mesma semântica
  (`orderBy(documentId())` ≡ ordem padrão `__name__ ASC` da REST).
- **Transporte unário de propósito:** `runQuery` e `runAggregationQuery` são
  *streaming*, e o proxy MCP devolveu para elas o primeiro pedaço seguido de um
  `500 INTERNAL` — com contagem `1` idêntica para sete coleções diferentes, que é
  assinatura de artefato de transporte, não de dado. Num censo isso truncaria em
  silêncio e chamaria de total. `listDocuments` é unário, pagina por `pageToken`,
  e foi o único caminho usado para contar.

## 14.B População — os números reais

**Universo total analisado: 0.** Todas as dezesseis cardinalidades pedidas pela
OS são **zero**, e todas pela mesma causa raiz: as coleções não existem.

| # | Categoria pedida pela OS | Quantidade |
| ---: | --- | ---: |
| 1 | Universo total analisado | **0** |
| 2 | Legado ativo com prazo válido (`migravel_vigente`) | 0 |
| 3 | Legado sem prazo (`bloqueado_sem_prazo`) | 0 |
| 4 | Legado vencido (`migravel_vencido`) | 0 |
| 5 | Com `playerEntitlements` | 0 |
| 6 | Entitlement comercial normal (`so_entitlement`) | 0 |
| 7 | Legado + entitlement (interseção) | 0 |
| 8 | Potencialmente migráveis (`gravar_ativo` + `gravar_expirado`) | 0 |
| 9 | Migráveis que hoje ficariam sem ficha mensal | 0 |
| 10 | Legados com `purchaseTokenHash` presente | 0 |
| 11 | Sem hash no entitlement, mas recuperável via `compras/{hash}` | 0 |
| 12 | Sem hash recuperável por nenhuma fonte | 0 |
| 13 | Com múltiplos `compras/{hash}` correlacionáveis | 0 |
| 14 | Registros contraditórios (`inclassificavel` + inconsistências) | 0 |
| 15 | Registros incompletos (entitlement sem estado/origem) | 0 |
| 16 | Não classificáveis automaticamente | 0 |

Interseções: todas as nove de `INTERSECAO` retornaram 0. Alertas: todos os nove
de `ALERTA` retornaram 0. Inconsistências: todas as dez retornaram 0. O relatório
bruto está em 14.F.

### 14.B.1 O estado real da base

Coleções existentes na raiz do banco `(default)`, com contagem por paginação:

| Coleção | Documentos | Observação |
| --- | ---: | --- |
| `usuarios` | **0** | não existe — coleção do **legado VIP**, o universo do censo |
| `playerEntitlements` | **0** | não existe — direitos comerciais |
| `compras` | **0** | não existe — **nenhuma compra jamais registrada** |
| `fichasConcessoes` | 0 | não existe — livro-razão das fichas |
| `publicProfiles` | 0 | não existe |
| `rankingLedger` | 0 | não existe |
| `users` | 1 | identidade canônica; a única conta tem só `displayName` |
| `billingEvents` | 1 | ver abaixo |
| `store_products` | 1 | `pack_starter` — catálogo semente |
| `tables` | 1 | uma mesa |
| `seasons` | 1 | `2026_S1` |
| `leaderboards` | 1 | `2026_S1` |
| `global_chat` | 1 | uma mensagem |

Um documento por coleção, com ids de semente reconhecíveis (`pack_starter`,
`2026_S1`): **esta é uma base de demonstração, não uma base com histórico.**

O único `billingEvents` fecha a questão:

```
decisao:     "notificacao_de_teste"
aplicado:    false
estado:      "concluido"
processadoEm: 2026-08-12T16:52:13.405Z
```

É a *notificação de teste* do Play Console — o botão "enviar notificação de
teste". Foi a única mensagem que o RTDN já recebeu, e ela não aplicou nada.
**Nenhuma compra real jamais atravessou este backend.** Isso é coerente com o
app nunca ter sido publicado na Play.

### 14.B.2 A prova de que o zero é medição, e não cano entupido

Um censo que examina 0 documentos produz um relatório **idêntico** ao de um censo
com o nome da coleção errado, o `parent` errado ou o decodificador quebrado.
Então o zero só vale acompanhado de controle negativo. Foram quatro provas, todas
com **o mesmo paginador, o mesmo decodificador e o mesmo transporte** do censo:

| Controle | Resultado |
| --- | --- |
| Paginador sobre `store_products` (povoada) | devolveu 1 doc, id `pack_starter` |
| Decodificação de tipos | `active` → booleano `true`; `coinsAmount` → número `500` |
| Paginador sobre `users` (povoada) | devolveu 1 doc, campos lidos |
| `get_document` por caminho direto | achou `store_products/pack_starter` |
| `get_document` em caminho inexistente | erro tratável, convertido em `null` — não falso positivo |
| Paginador sobre as três coleções do censo | 0, 0, 0 |

O transporte enxerga documento quando ele existe. Logo, o zero é o dado.

Foram fechadas também as duas saídas que "a coleção não aparece" deixaria aberta:

- **Outro banco?** Não. `listDatabases` retorna exatamente um: `(default)`.
- **Documento "faltante"** (id sem campos, existindo só como pai de subcoleção —
  seria o caso de `playerEntitlements/{uid}` com `interno/billing` embaixo)?
  Não. As três coleções foram relistadas com `showMissing: true` e voltaram
  vazias.

## 14.C Hash histórico

| Medida | Quantidade |
| --- | ---: |
| Legados com `purchaseTokenHash` já presente | 0 |
| Com exatamente um hash correlacionável | 0 |
| Com mais de um (ambíguos) | 0 |
| Sem nenhum (irrecuperáveis) | 0 |
| Com hash igual ao histórico de `compras/` | 0 |
| Com valor diferente | 0 |
| Com conflito de identidade/uid | 0 |

`compras/` está vazia, então não há hash histórico a recuperar — e também não há
nada a recuperar *de*. A correlação rodou zero vezes (`correlacaoDeCompras: 0`)
porque não houve jogador para correlacionar, e não porque tenha sido desligada:
a porta `lerComprasDoJogador` estava ligada, como no padrão da callable.

**O achado de §4 não é invalidado — ele fica sem destinatário hoje e continua
valendo para amanhã.** A propriedade que o sustenta (o id do documento de
`compras/` *é* o `sha256(token)`) é da mesma transação que grava a compra, e vale
para toda compra futura. Se o app for publicado e vender antes de a migração
rodar, é este mecanismo que evita a perda da ficha mensal.

## 14.D Impacto comercial

| Medida | Quantidade |
| --- | ---: |
| Ativos com benefício mensal a receber | 0 |
| Excluídos hoje apenas pela ausência do hash | 0 |
| Desses, com hash histórico recuperável | 0 |
| Continuariam sem solução após backfill | 0 |
| Vencidos (não devem inflar a perda) | 0 |

**Perda financeira real hoje: zero. Decisão comercial pendente por causa da
população legada: nenhuma.** Não há assinante, não há ex-assinante, não há
receita em risco.

O risco que sobra não é de população: é de **sequenciamento**. Ver 14.E.

## 14.E Recomendação

Classificação da população nos cinco grupos pedidos:

| Grupo | Quantidade |
| --- | ---: |
| Pronta para migração | 0 |
| Exige backfill antes | 0 |
| Exige decisão comercial | 0 |
| Exige investigação manual | 0 |
| Não deve migrar | 0 |

**Recomendação sobre a migração: não executar `migrarEntitlementsLegado` — não
por risco, mas por vacuidade.** Ela varreria uma coleção inexistente e gravaria
nada. Rodar não faz mal e não faz bem; o que faria mal é *tomar a decisão de
migração como resolvida* e esquecer que ela nunca foi exercitada contra dado
real.

O que a ausência de população muda, e que é a entrega prática desta OS:

1. **A migração legada deixou de ser um bloqueio de lançamento.** Ela estava na
   frente do VIP porque se supunha uma base a converter. Não há base. O caminho
   crítico para vender VIP é o de sempre: Play Console, preço, RTDN ativado.
2. **`concederFichasMensais` precisa ser implantada antes da primeira venda.**
   Hoje ela não existe em produção (14.A.2). Um assinante que compre antes disso
   não recebe parcela mensal nenhuma — e esse seria um defeito com dinheiro real
   atrás, ao contrário do que o censo acabou de medir.
3. **O backfill de hash de §4 vira prevenção, não reparo.** Não há o que
   consertar; há o que não deixar quebrar.
4. **Rodar o censo de novo é barato e deve ser refeito depois da primeira venda**,
   quando os números deixarem de ser zero. O procedimento está em §9 e em 14.A.

## 14.F Relatório bruto do instrumento

Retorno íntegro de `diagnosticar()`, sem edição:

```json
{
  "resumo": {
    "examinados": 0,
    "porFase": { "usuarios": 0, "entitlements": 0 },
    "porCategoria": {
      "fora_da_populacao": 0, "so_entitlement": 0, "ja_coberto_pela_play": 0,
      "ja_migrado": 0, "migravel_vigente": 0, "migravel_vencido": 0,
      "bloqueado_sem_prazo": 0, "entitlement_orfao": 0, "inclassificavel": 0
    },
    "porAcao": {
      "nada_fora_da_populacao": 0, "nada_legado_nao_sobrescreve": 0,
      "pular_sem_prazo": 0, "gravar_ativo": 0, "gravar_expirado": 0
    },
    "porAlerta": {
      "sem_ficha_mensal": 0, "sem_reconsulta_possivel": 0,
      "possivel_pagante_rebaixado": 0, "sumico_silencioso": 0,
      "divergencia_de_prazo": 0, "hash_recuperavel_de_compras": 0,
      "hash_ambiguo": 0, "hash_irrecuperavel": 0, "evidencia_comercial": 0
    },
    "porInconsistencia": {
      "vip_nao_booleano": 0, "prazo_ilegivel": 0, "entitlement_sem_estado": 0,
      "entitlement_sem_origem": 0, "entitlement_ativo_sem_prazo": 0,
      "entitlement_ativo_vencido": 0, "migrado_com_hash": 0, "play_sem_hash": 0,
      "multiplos_hashes_candidatos": 0, "compra_de_outro_titular": 0
    },
    "porInterseccao": {
      "legado_e_entitlement": 0, "legado_e_entitlement_sem_hash": 0,
      "legado_ativo_e_evidencia_comercial": 0, "migravel_com_hash_recuperavel": 0,
      "migravel_sem_hash_recuperavel": 0, "sem_prazo_com_evidencia_comercial": 0,
      "entitlement_vigente_sem_hash": 0, "entitlement_vigente_sem_token": 0,
      "legado_vip_e_entitlement_sem_acesso": 0
    },
    "correlacaoDeCompras": 0
  },
  "amostras": {},
  "esgotou": true,
  "cursor": null,
  "varridoEm": "2026-08-15T17:42:21.370Z"
}
```

## 14.G A tabela obrigatória da OS

| Categoria | Quantidade | % do universo | Hash recuperável? | Pode migrar hoje? | Impacto mensal | Risco |
| --- | ---: | ---: | --- | --- | --- | --- |
| Legado vigente (`migravel_vigente`) | 0 | — | n/a | n/a | 0 | nenhum |
| Legado vencido (`migravel_vencido`) | 0 | — | n/a | n/a | 0 | nenhum |
| Legado sem prazo (`bloqueado_sem_prazo`) | 0 | — | n/a | n/a | 0 | nenhum |
| Já migrado (`ja_migrado`) | 0 | — | n/a | n/a | 0 | nenhum |
| Já coberto pela Play | 0 | — | n/a | n/a | 0 | nenhum |
| Só entitlement (comercial normal) | 0 | — | n/a | n/a | 0 | nenhum |
| Entitlement órfão | 0 | — | n/a | n/a | 0 | nenhum |
| Inclassificável | 0 | — | n/a | n/a | 0 | nenhum |
| **Universo** | **0** | **—** | — | — | **0** | — |

A coluna de porcentagem fica vazia por impossibilidade aritmética: o
denominador é zero. Preenchê-la com `0%` afirmaria uma proporção que não existe.

## 14.H Segurança — confirmação explícita

| Garantia | Como foi assegurada |
| --- | --- |
| Nenhum documento alterado | o cliente MCP recusa, por lista branca, toda ferramenta fora de `list_collections`, `list_documents`, `get_document`, `query_collection`, `run_aggregation_query`, `list_databases`, `get_database`. As de escrita (`firestore_add_document`, `firestore_update_document`, `firestore_delete_document`) existem no servidor e **nunca foram chamadas** |
| Nenhum trigger de migração chamado | `migrarEntitlementsLegado` não foi invocada |
| Nenhum benefício concedido, nenhuma ficha creditada | `concederFichasMensais` sequer existe em produção |
| Nenhum token exposto | não há token na base; nenhum campo com nome sugestivo de segredo foi impresso (filtro explícito no script de contexto) |
| Nenhum hash individual publicado | não há hash na base; ids de `users`/`tables`/`global_chat` só apareceram como rótulo `sha256` de 12 caracteres |
| Nenhuma credencial no relatório | a credencial usada é a do `firebase login`; ela não foi lida, exportada nem impressa |
| Nenhum deploy | `firebase deploy` não foi executado em momento algum |

Verificação independente do estado pós-execução: as contagens de 14.B.1 foram
obtidas **depois** do censo, e continuam em 0/1 — nada nasceu durante a execução.

## 14.I Pós-execução

`diagnosticarPopulacaoVip` **não foi implantada**, então não há o que remover,
desativar ou limpar. Nenhuma recomendação de OS de remoção é necessária: o
projeto ficou exatamente como estava antes desta execução.

A função permanece no código, não em produção — que é onde ela deve ficar até
existir população para medir.

## 14.J Portões desta execução

| Suíte | Resultado |
| --- | ---: |
| `functions-billing` — `npm test` (alvos explícitos) | **179/179** |
| `functions-billing` — `node --test` sem alvos (caminho do CI de release) | **180/180** |

Nenhum arquivo de produção foi alterado por esta OS: a única mudança na árvore é
este documento.
