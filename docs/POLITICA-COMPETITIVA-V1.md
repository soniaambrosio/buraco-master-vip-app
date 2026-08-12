# POLÍTICA COMPETITIVA V1 — ranking, ligas e temporadas

Documentação técnica exigida pela seção 34 da OS. Descreve a regra competitiva
que passou a valer, onde ela mora e o que ela deliberadamente não faz.

- Política: **`competitiva@v1`**
- Onde: [`functions-ranking/src/elo.ts`](../functions-ranking/src/elo.ts) (a
  aritmética) e [`functions-ranking/src/competicao.ts`](../functions-ranking/src/competicao.ts)
  (quem compete, em que estado, por qual escada)
- Registrada em: [`functions-ranking/src/index.ts`](../functions-ranking/src/index.ts),
  na carga do módulo

---

## 1. O princípio (§37 da OS)

> **Mesa Pública é o jogo casual. Mesa VIP/Ranqueada é o campeonato.
> O jogador paga para participar da competição, nunca para ter vantagem dentro dela.**

A segunda metade é verificável por ausência: não há ocorrência de `vip`,
`assinante`, `entitlement` ou `premium` em `elo.ts` nem em `competicao.ts`. O
acesso VIP decide se a partida **nasce** ranqueada — decisão da abertura da mesa,
fora deste codebase — e a partir daí o cálculo trata todo mundo igual.

A **visualização** do ranking não é exclusiva do VIP. `abrirRanking` e
`paginarRanking` exigem autenticação e App Check, e mais nada: não há checagem de
assinatura em nenhum caminho de leitura.

---

## 2. Casual × ranqueado, e por que são duas guardas

Duas perguntas diferentes, aplicadas em série. Nenhuma substitui a outra.

| campo | pergunta | valor |
|---|---|---|
| `alteraRanking` (do domínio Dart) | "produz lançamento no ledger competitivo?" | `publicaRanqueada \|\| torneio` |
| `AMBIENTE_COMPETITIVO` (desta OS) | "alimenta o **rating de temporada**?" | só `publica_ranqueada` |

**Usar só a primeira faria toda partida de torneio pontuar Elo**, porque no
domínio Dart `TipoDePartida.alteraRanking` inclui `torneio`. A §6 desta OS
respondeu uma pergunta mais estreita, e a segunda guarda é o que a implementa.

Resultado por tipo:

| tipo | pontua? | recusa |
|---|---|---|
| `publica_ranqueada` | **sim** | — |
| `publica_casual` | não | `nao_pontua` |
| `torneio` | não | `fora_do_ambiente_competitivo` |
| `privada` / `treinamento` / `contra_robos` | não | `fora_do_ambiente_competitivo` |
| tipo desconhecido | não | `fora_do_ambiente_competitivo` (lista branca) |

Mesa Pública pode registrar partida, estatística e histórico pessoal, e exibir
anúncio. O que ela não faz: mover rating, mover Liga, entrar na classificação,
contar como partida de colocação ou de revalidação.

**Torneios não alimentam este rating na v1.** Classificação própria, títulos,
premiação, Hall e troféus continuam sendo do Motor de Torneios, e nada disso
passa por aqui.

---

## 3. Natureza imutável da partida (§4)

A partida nasce casual ou ranqueada, e não muda depois.

A natureza observada na primeira vez fica gravada em `rankingBacklog/{matchId}.tipo`
e em `rankingContributions/{chave}.tipo`. Num reprocessamento, ela é comparada
com o documento oficial atual; se divergir, a recusa é `natureza_alterada`,
definitiva. Fecha os dois sentidos: casual promovida a ranqueada depois do
resultado, e ranqueada rebaixada a casual para apagar um resultado ruim.

---

## 4. A fórmula

Elo simplificado, individual, com a força medida por dupla.

```
ratingDaDupla   = média aritmética do rating dos integrantes (NÃO arredondada)
E               = 1 / (1 + 10 ^ ((ratingAdversária − ratingMinha) / 400))
delta           = arredondar( K × (resultadoReal − E) )
```

- `resultadoReal`: vitória `1`, empate `0.5`, derrota `0`.
- Os **dois integrantes da mesma dupla partem da mesma expectativa** — ela é
  propriedade do confronto, não do jogador. O que difere entre eles é o `K`.
- A média da dupla **não é arredondada**. Arredondá-la faria 1200+1401 e
  1200+1400 produzirem a mesma expectativa, e o rating do parceiro deixaria de
  importar em metade dos casos.

### Fator K (§10)

| estado | K |
|---|---|
| `em_colocacao` | **40** |
| `em_revalidacao` | 24 |
| `classificado` | 24 |

Cada jogador usa o **próprio** K, mesmo que o parceiro esteja em outro estado.

> **K=40 é exclusivo da colocação inicial.** A OS deixou a revalidação sem K
> atribuído — a §10 nomeia fatores para "em colocação" e "já classificado", e a
> §21 criou um terceiro estado sem lhe dar um. **Decisão de produto, tomada na
> aprovação desta OS:** as 5 partidas de revalidação **não** fazem o veterano
> voltar ao estado de colocação. Ele continua sendo jogador previamente
> classificado, apenas revalidando sua posição após o soft reset — então mantém
> K=24. O K alto existe para localizar quem o sistema ainda **não conhece**, e do
> veterano ele já sabe inclusive o rating com que terminou a temporada anterior,
> que é de onde o soft reset partiu.

**A linha de corte do K é "já foi classificado alguma vez?", e não "está em
qualificação?".** A distinção importa porque `emQualificacao` continua valendo
para outra coisa — contar partidas para a exigência (10 ou 5). Os dois estados
provisórios contam partidas; só um deles tem K alto. Em código, `kDoEstado`
compara contra `em_colocacao` diretamente, e não reaproveita `emQualificacao`.

### Arredondamento

**Meio para longe de zero**, e não `Math.round`. Com meio-para-cima, uma partida
equilibrada de K ímpar daria `+13` ao vencedor e `−12` ao perdedor: a mesa
ganharia um ponto do nada, a cada partida, para sempre. Isso é inflação de rating
por defeito de arredondamento, invisível até todo mundo estar em Lenda.

O arredondamento acontece **exatamente uma vez**, no delta final. Valores
intermediários (média da dupla, expectativa) ficam em ponto flutuante.

**O rating é armazenado como inteiro**, porque `aplicarLancamento` recusa ponto
flutuante no ledger — a soma `antes + delta == depois` para de fechar depois de
algumas centenas de lançamentos em float.

### A diferença de pontos NÃO multiplica o delta (§11)

Ganhar de 2.000 a 0 e ganhar de 100 a 90 valem o mesmo delta contra o mesmo
adversário. **Nenhuma função de `elo.ts` recebe placar** — a impossibilidade é de
assinatura, e não uma disciplina que alguém precisa lembrar de manter.

O saldo de pontos é registrado (`saldoPontos`) para estatística e para o 3º
critério de desempate, e não chega ao cálculo.

---

## 5. Colocação (§8)

Jogador sem histórico competitivo entra com `rating = 1000` e estado
`em_colocacao`, devendo **10 partidas ranqueadas válidas**.

Durante a colocação: o rating é calculado normalmente, e o jogador **não recebe
Liga** — a tela mostra `Em colocação`, nunca Bronze. Ao completar a 10ª, ele sai
do estado e recebe a Liga correspondente ao rating **daquele momento** (com o
delta da décima já aplicado).

Só partida ranqueada válida consome uma das 10. Casual, torneio, anulada e
incompleta são recusadas antes de chegar ao contador.

---

## 6. Revalidação (§21)

Jogador que já possuía classificação competitiva anterior entra na temporada
seguinte com soft reset e estado `em_revalidacao`, devendo **5 partidas**.

"Já possuía classificação anterior" significa **ter terminado uma temporada
classificado**. Quem entrou tarde, jogou 4 das 10 e viu a temporada acabar nunca
teve classificação — volta às 10 partidas, do 1000.

O carimbo de consolidação (`rankingPlayers/{uid}.ultimaTemporadaConsolidada` +
`.ratingFinalConsolidado`) é escrito **só para quem terminou classificado**, e
**não é apagado** por uma temporada em que o jogador não consolidou. Quem foi
Diamante em 2026-A, jogou 3 das 5 revalidações em 2026-B e sumiu, entra em 2026-C
com o soft reset do rating de 2026-A — o último que o sistema efetivamente mediu.

---

## 7. Soft reset (§20)

```
novoRating = arredondar( 1000 + 0,60 × (ratingFinalAnterior − 1000) )
```

| final anterior | novo |
|---|---|
| 1700 | 1420 |
| 1400 | 1240 |
| 1200 | 1120 |
| 1000 | 1000 |
| 800 | 880 |

Comprime a distância ao centro em 40%, **nos dois sentidos**. Não zera ninguém, e
**preserva a ordem** entre jogadores. O ponto fixo prático é 1001 e não 1000
(`softReset(1001) = 1000,6 → 1001`), o que é inofensivo.

---

## 8. As sete Ligas (§15)

| Liga | rating |
|---|---|
| Bronze | abaixo de 950 |
| Prata | 950 – 1099 |
| Ouro | 1100 – 1249 |
| Platina | 1250 – 1399 |
| Diamante | 1400 – 1549 |
| Mestre | 1550 – 1699 |
| Lenda | 1700 ou mais |

Definidas **uma única vez**, em `DEGRAUS_V1`. As duas pontas são abertas: Bronze
sem piso, Lenda sem teto — assim todo rating tem Liga, e não existe faixa órfã.

`conferirEscada` recusa escada com buraco entre faixas, sobreposição, ordem
invertida, liga duplicada, teto no meio ou piso no meio.

**A escada é resolvida por CÓDIGO**, pelo `ladderId` da temporada. `lerEscada`
consulta o registro em código **antes** do Firestore: um documento adulterado em
`rankingLadders` não rebaixa ninguém. A coleção continua servindo escadas futuras
que não sejam a oficial.

**Não existem** — e a §15 proíbe cada um: Bronze I/II/III, subdivisão, estrela,
ponto de promoção, partida de promoção, proteção contra queda, demotion shield.

Durante colocação/revalidação **não há Liga**, e isso vence qualquer `ligaId`
gravado na linha.

> **Ícones saem vazios nos sete.** A arte do cliente tem sete arquivos, mas o
> sexto se chama `liga_imperial.webp` enquanto a §15 nomeia a sexta liga como
> **Mestre**. Amarrar as duas coisas seria inventar uma associação de arte dentro
> de uma OS de regra competitiva. Dependência declarada.

---

## 9. Desempate da classificação (§17)

Ordem oficial da temporada, nesta sequência:

1. **rating** — maior primeiro
2. **vitórias na temporada** — maior primeiro
3. **saldo acumulado de pontos** das partidas ranqueadas — maior primeiro
4. **abandonos atribuídos ao jogador** — **menor** primeiro (único ascendente)
5. **`ratingAtingidoEm`** — quem chegou ao rating atual **primeiro**
6. `publicPlayerId` — desempate **técnico**, não competitivo

O 6º é permitido nominalmente pela §17 ("desempate puramente técnico posterior
para estabilidade de banco/paginação") sob duas condições que são cumpridas: não
é apresentado como regra competitiva, e não substitui os cinco acima. Ele existe
porque sem ordem **total** o `startAfter` do cursor não aponta para um ponto único
e páginas consecutivas repetem ou pulam linhas.

**O UID não é critério e não chega a essa camada.** `ChaveDeOrdem` não tem campo
de uid, e `valorDoCriterio` recusa qualquer campo fora da lista.

### Como o carimbo do critério 5 é capturado

`ratingAtingidoEm` é reescrito com o instante do **servidor** sempre que o **valor
do rating muda**, e preservado quando o rating fica igual. Responde literalmente
"desde quando este jogador está neste rating". Um delta zero não reinicia o
relógio. Entre dois jogadores com 1400, vem antes o que chegou a 1400 há mais
tempo e se manteve.

### O escopo global usa outra ordem

`rankingPlayers` (o escopo `global` do cliente) ordena por `pontosTotais DESC,
publicPlayerId ASC`. Os cinco critérios da §17 são definidos para "a ordenação
oficial da **temporada**"; o agregado de vida inteira não tem vitórias por
temporada, saldo por temporada nem o carimbo — aplicá-los ali exigiria inventar o
significado de cada um fora do recorte em que a OS os definiu.

---

## 10. Empate (§12)

`ladoVencedor == null` numa partida **finalizada** é o empate oficial: `0.5` para
os dois lados, aplicado contra a expectativa normal. O empate pune o favorito e
premia o azarão, e entre iguais não move ninguém.

A calculadora sabe tratá-lo. **Nenhum mecanismo foi inventado para criar
empates** — se o domínio produz ou não esse desfecho é assunto do domínio.

---

## 11. Abandono e WO (§14)

**Resultado competitivo e sanção comportamental são coisas separadas.**

Quando o servidor decreta oficialmente o WO (partida `abandonada` **com**
`ladoVencedor`), o Elo segue a fórmula padrão: derrota normal para a dupla
perdedora, vitória normal para a vencedora. **Sem multa adicional, sem pontos
extras retirados, sem alteração de fórmula por motivo disciplinar.** Sanção
pertence ao domínio de moderação.

Partida `abandonada` **sem** vencedor decretado **não pontua** (`desfecho_indefinido`):
sem decreto da autoridade não há desfecho, e tratá-la como empate daria 0,5 a
quem abandonou.

> **`abandonos` fica em zero hoje.** O registro oficial marca que houve abandono
> (`estado: abandonada`), mas **não diz quem abandonou** — não existe atribuição
> por jogador em `RegistroDePartida`. Atribuir aos dois integrantes do lado
> perdedor puniria o parceiro inocente, que seria regra inventada. O campo e o
> 4º critério de desempate existem e são exercitados por teste; a fonte que os
> alimenta é dependência de outra OS.

---

## 12. Partida anulada, inconsistente ou incompleta (§13)

Nunca alteram rating, e nunca consomem partida de colocação/revalidação.

| situação | recusa |
|---|---|
| `cancelada` | `nao_pontua` (o domínio grava `alteraRanking: false`) |
| `criada` / `aguardando` / `ativa` / `reconectando` | `nao_terminal` |
| competidor sem lado, um lado só, ou três lados | `lados_inconsistentes` |
| vencedor que não está na mesa | `desfecho_indefinido` |
| abandono sem vencedor decretado | `desfecho_indefinido` |

Todas são **definitivas**: delta zero e **não vão para o backlog**. Backlog é para
o que ainda *pode* vir a pontuar quando faltar uma peça.

---

## 13. Backlog e reprocessamento (§26)

`rankingBacklog/{matchId}` tem três situações:

| `situacao` | significado |
|---|---|
| `pendente` | falta uma peça (temporada, política). Será reprocessada. |
| `recusado` | nunca vai pontuar, e já se sabe por quê. |
| `processado` | virou pontuação. Escrito dentro da transação. |

O documento **não é apagado** no sucesso: perder-se-ia a informação de que a
partida esteve pendente e de com que `tipo` foi observada — que é o que sustenta
a guarda de imutabilidade da §4.

`reprocessarBacklogDeRanking({ cursor?, seasonId?, limite? })` esvazia a fila
**um lote por chamada** (máx. 30), devolvendo `cursor` e `fim`. Um laço até o fim
seria morto por tempo no meio, deixando o operador sem saber onde parou.

**A ordem é cronológica (`registradoEm ASC`), e isso não é cosmético:** o Elo não
é comutativo. Aplicar a partida de março depois da de abril daria ao jogador um
rating diferente, porque a expectativa de cada uma depende do rating vigente na
hora. Reprocessar na ordem de encerramento é o que faz o resultado do backlog ser
o mesmo que teria saído se a política existisse desde o início. Por isso o laço é
**sequencial**, e não `Promise.all`.

**Casual antiga no backlog não pontua retroativamente.** As guardas de
elegibilidade rodam contra o documento oficial **atual** e vêm **antes** da
checagem de idempotência — não existe caminho pelo qual um item guardado sob
regras antigas passe a pontuar.

Cada contribuição registra a política (`competitiva@v1`) no ledger e no documento
de contribuição.

---

## 14. Idempotência e concorrência (§§29 e 30)

**Idempotência** é do banco, não de um `if`: o id do documento em
`rankingContributions` **é** a chave `{matchId}|{seasonId}|{politicaId}|v{N}`. A
segunda gravação disputa o mesmo documento e o `tx.create` falha. Processar duas
vezes não dobra delta, não duplica ledger, não aumenta contagem de partidas nem
de vitórias, e não consome duas partidas de colocação. *Exercitado com 10
execuções simultâneas contra o emulador.*

**Concorrência**: tudo numa transação só — contribuição, lançamentos e
classificação entram juntos ou não entram. Duas partidas do mesmo jogador
disputam o mesmo documento de standing; o Firestore reexecuta a perdedora, que
lê o saldo já atualizado. **Não se usa `FieldValue.increment`** para o rating: o
incremento atômico não devolve o valor anterior, e sem ele não há `rankingBefore`
— o ledger perderia a propriedade `antes + delta == depois`. *Exercitado com 8
partidas simultâneas do mesmo jogador; a cadeia do ledger fecha.*

---

## 15. Versionamento (§25)

`POLITICA_COMPETITIVA_V1 = { id: "competitiva", versao: 1 }`.

Gravada em todo lançamento de `rankingLedger` e em toda `rankingContributions`.
Sem ela, reconstruir por que um jogador ganhou 13 pontos em março exigiria
adivinhar qual era o código em março.

**Quando incrementar:** qualquer alteração que faça a **mesma** partida produzir
um delta **diferente** — corrigir um K, mudar o divisor, mudar o arredondamento.
Corrigir um comentário não é. A versão nova não reescreve lançamentos antigos;
ela passa a valer para os próximos, e a chave de idempotência (que inclui
`politica|vN`) permite reprocessar uma temporada sob a regra nova sem colidir com
a antiga.

O identificador é espelhado no domínio Dart como
`PoliticaDeRanking.competitivaV1` — **constante de identificação, não de cálculo**.
O cliente não calcula delta (§28).

O mecanismo de pendência continua inteiro: uma temporada que declare
`nao_definida` (ou qualquer política sem calculadora registrada) **não pontua** e
acumula backlog.

---

## 16. Temporada (§§18 e 19)

Duração aprovada: **8 semanas**. As datas são parâmetros de
`abrirTemporadaDeRanking({ seasonId, inicioEm, fimEm })` — não há data fixa
espalhada na lógica.

Ao encerrar: a classificação final é congelada, o rating e a posição finais
continuam consultáveis, e nenhuma partida posterior altera a temporada. A
garantia é a chave do documento — `rankingStandings/{seasonId}|{uid}` —, e a
temporada seguinte grava em documentos com outro id.

Sequência do encerramento, e a ordem importa:

1. **apuração final** — para que a classificação congelada seja a definitiva, e
   não a da última passagem periódica;
2. **encerramento** — `status: encerrada`;
3. **consolidação** — carimba o rating final de cada classificado em
   `rankingPlayers`. Só depois do fechamento "final" quer dizer alguma coisa.

Um resultado que chegue para temporada já encerrada vai para o backlog
(`temporada_encerrada`), e não reabre nada.

---

## 17. Campos públicos (§§23 e 24)

`JogadorPublicado` — lista **branca**: campo novo no standing não vaza sozinho.

| campo | observação |
|---|---|
| `id` | é o `publicPlayerId`, **nunca** o UID |
| `apelido` / `avatar` | **vazios hoje** — não há fonte de perfil no backend |
| `liga` | rótulo pronto: nome da Liga, ou `Em colocação` / `Em revalidação` |
| `ligaId` | `null` durante a qualificação — é o campo com que se escolhe arte |
| `pontos` | o rating |
| `posicao` | `0` quando ainda não apurado |
| `direcao` / `delta` | movimento desde a apuração anterior |
| `estado` | `em_colocacao` / `em_revalidacao` / `classificado` |
| `qualificacaoRestante` | quantas partidas faltam. `0` para consolidados |
| `partidas` / `vitorias` / `derrotas` | contadores da temporada |
| `aproveitamento` | vitórias/partidas em %, uma casa. `0` sem partidas |
| `selo` | `null` hoje |
| `souEu` | decidido no servidor comparando UIDs — nunca apelido |

**UID e e-mail não fazem parte da resposta.** `CAMPOS_PROIBIDOS` é varrido
recursivamente em teste.

Apelido e avatar **não foram fabricados**: nada de derivar nome de e-mail, nada
de expor UID como fallback. Contrato compatível, campo vazio, ausência
documentada. A OS de identidade pública/grafo social trata isso.

---

## 18. Segurança (§28)

Nenhuma autoridade foi deslocada para o cliente. As Rules **não foram
afrouxadas** — o Bloco 6/6 de `firestore.rules` continua sem nenhum `allow write`
verdadeiro para estrutura autoritativa de ranking, e as 41 provas do bloco
continuam passando (112 no arquivo integrado).

O cliente não decide: se a partida é ranqueada, resultado, delta, rating, Liga,
colocação, soft reset, posição ou elegibilidade. Nenhuma função chamável aceita
`pontos`; a Liga é derivada e nunca recebida; `apurarRanking`,
`abrirTemporadaDeRanking`, `encerrarTemporadaDeRanking` e
`reprocessarBacklogDeRanking` exigem claim `admin`.

---

## 19. Limitações ainda existentes

1. ~~K da revalidação~~ — **resolvido**: K=24, decidido na aprovação da OS. Ver §4.
2. **`abandonos` fica em zero** — não há atribuição de abandono por jogador no
   registro oficial. O critério 4 do desempate é um no-op até que exista fonte.
3. **Ícones das Ligas vazios** — o asset da 6ª liga se chama `liga_imperial` e a
   OS a nomeia `Mestre`. Associação não inventada.
4. **Apelido e avatar vazios** — não há fonte de perfil **nesta árvore**. Ver a
   §21: existe fonte numa branch paralela.
5. **Escopo `amigos`** continua recusando com `failed-precondition` — não há
   grafo social **nesta árvore**. Idem §21.
6. **O emulador do Firestore não exige índice composto** — ele os cria sozinho.
   Um `firestore.indexes.json` incompleto passaria na integração e falharia em
   produção. A conferência do índice é por leitura, e continua sendo **portão de
   pré-deploy**.
7. **Backlog legado sem `situacao`** — a consulta de reprocessamento filtra por
   `situacao == "pendente"`, e documentos gravados pela OS anterior não têm o
   campo. Hoje isso é inócuo (nada foi implantado: nem merge, nem deploy), mas se
   houver deploy anterior a este, um backfill de uma linha é pré-requisito.
8. **O escopo `global` não tem posição apurada** — a apuração percorre a
   temporada, não a vida inteira. Herdado da OS anterior.
9. **As Cloud Functions chamáveis não foram exercitadas de ponta a ponta** (App
   Check, claims, `onCall`). A integração exercita a camada de execução
   (`firestore.ts`) diretamente contra o Firestore real.

---

## 20. Divergências de árvore registradas (§2)

A OS manda registrar divergência entre o que ela descreve e a árvore real. São
duas, e nenhuma foi mesclada — esta OS trabalhou sobre `af57fe8`, como mandado.

### 20.1 `integracao/ranking-ligas-hall` (`428c458`)

**Não contém `af57fe8`.** É a linha do **cliente** (contratos `RankingJogador` /
`HallQuadro`, telas, `RankingSemFonte`), construída sobre `7a75bab`. Esta OS é
backend, sobre `f9814f9`. As duas se encontram pelo adaptador descrito em
[`CONTRATO-RANKING-CLIENTE.md`](CONTRATO-RANKING-CLIENTE.md), que continua sendo
a peça que falta.

### 20.2 `claude/identidade-publica-grafo-social-78d184` (`fddcecc`) — **importante**

**Também não contém `af57fe8`**, e resolve duas coisas que este documento
declara como ausentes. Ela entrega o codebase `functions-social` com:

| ela tem | o que isso resolve aqui |
|---|---|
| `publicProfiles/{publicId}` com `apelido` e `avatarRef` | a fonte de perfil que falta às limitações 4 |
| grafo social (amizades) | a fonte que falta ao escopo `amigos`, limitação 5 |
| `playerIdentities/{uid}` + `publicIdIndex/{publicId}` | **uma segunda autoridade de identidade pública** |

**O ponto que exige atenção na consolidação:** hoje existem **duas autoridades
cunhando identidade pública** — `garantirIdPublico` em
[`functions-ranking/src/firestore.ts`](../functions-ranking/src/firestore.ts)
(`rankingPlayers.publicPlayerId` + `rankingPublicIds`) e `playerIdentities` +
`publicIdIndex` daquela branch. O **formato é deliberadamente idêntico** nas duas
(`P` + 12 símbolos de base32 de Crockford sem I/L/O/U), o que faz do encontro uma
**reconciliação de dados, e não uma quebra de contrato**.

Quando as duas linhas se juntarem, `garantirIdPublico` deve **parar de cunhar** e
passar a ler `playerIdentities/{uid}`; e `rankingStandings.apelido`/`.avatar` —
que hoje são lidos e nunca escritos por ninguém — saem, ou viram leitura de
`publicProfiles`. A `JogadorPublicado` já publica `apelido` e `avatar`, então o
contrato do cliente **não muda**: os campos apenas deixam de vir vazios.

Nada disso foi feito aqui, e nem deveria: a §32 desta OS proíbe explicitamente
criar fonte de apelido/avatar e grafo social. O registro existe para que a
consolidação não descubra o conflito tarde.

---

## 21. O que esta OS NÃO implementou (§32)

Nada disto foi criado: Hall da Imortalidade, selos, premiação de temporada,
cosméticos, economia/fichas, cobrança, Billing, anúncios, grafo social, amizades,
fonte de apelido/avatar, divisões I/II/III, ranking de torneios, bônus de streak,
decay por inatividade, proteção de Liga, partidas de promoção, temporada
comemorativa, multiplicador VIP, vantagem competitiva paga.
