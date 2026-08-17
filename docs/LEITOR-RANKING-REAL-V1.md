# Leitor real de ranking na Casca V2 — contrato, decisões e laudo

Branch `claude/leitor-ranking-real-casca-v2-v1`, a partir de
`bc74e30a148a56b00ca7db691a378584efaa5207`
(`claude/perfil-ranking-estado-canonico-v1-cac971`, homologada), que contém
`ec16a65` como ancestral.

Autoridade contratual lida, sem merge:
`0b0aa63be668a103edc4706e1889b94f1e4b9079`.

---

## 1. O contrato real, medido

Lido em `functions-ranking/src/index.ts` e `src/projecao.ts` @ `0b0aa63`.

| | `abrirRanking` | `consultarJogadorPorIdPublico` |
|---|---|---|
| Autenticação | obrigatória (`unauthenticated`) | obrigatória |
| App Check | `enforceAppCheck: true` | `enforceAppCheck: true` |
| Região | `southamerica-east1` | `southamerica-east1` |
| Entrada | `{ escopo, limite? }` | `{ publicPlayerId }` |
| Sucesso | `{ resumo: { temporadaId, temporadaNome, divisao, podio[], escadaLigas[], eu }, primeiraPagina }` | `{ id, temporadaId, classificado, jogador }` |
| Sem colocação | `resumo.eu == null` | `classificado: false`, `jogador: null` |
| Erros | `failed-precondition` (sem temporada), `invalid-argument` (escopo) | `not-found`, `invalid-argument` |

Campos do `JogadorPublicado` que esta OS consome:

| Campo | Tipo | Observação |
|---|---|---|
| `liga` | `string` | **Rótulo pronto para a tela.** `'Bronze'`, `'Em colocacao'` ou `''` |
| `ligaId` | `string \| null` | `'bronze'`… ou **nulo** quando o rótulo é um estado, não uma Liga |
| `posicao` | `int` | **`0` = `POSICAO_NAO_APURADA`**, publicado de propósito |
| `temporadaId` | `string \| null` | nulo é legítimo em `consultarJogadorPorIdPublico` |

`divisao` vem sempre `null` no backend — as faixas dentro de uma Liga não
existem. Não é exibida, e não foi inventada.

## 2. A decisão sobre Bronze: **Caso A**

O backend devolve **nome público pronto**. Portanto:

- o texto recebido é preservado e passa só pela higienização do
  `EstadoRanking`;
- **não** existe tabela local de nomes de liga no cliente;
- a auditoria estrutural **não** precisou ser afrouxada. Ela continua
  reprovando `Bronze`, `Diamante`, posição e liga fabricada em telas, mocks
  alcançáveis e serviços — e ganhou uma irmã que proíbe qualquer nome de liga
  dentro de `lib/ranking/`, justamente para que o Caso A não vire Caso B por
  descuido.

O risco que a homologação de `bc74e30` previu — "um mapeamento `bronze` →
`'Bronze'` vai brigar com o gate" — **não se materializou**, porque o
mapeamento não é necessário. O contrato já resolvia isso do outro lado.

Um efeito colateral do Caso A precisou de decisão: como `liga` também carrega
`'Em colocacao'`, o prefixo fixo `💎 Liga` do Perfil produziria
"💎 Liga Em colocacao". A guarda é `ligaId != null`
(`EstadoRanking.ehLigaDeVerdade`) — um campo real do contrato, não uma lista de
nomes.

## 3. O encaixe que já existia

O `EstadoRanking` homologado higieniza `0`, negativo e string vazia nos
*getters*. O contrato real publica **exatamente** esses dois valores para
ausência: `posicao: 0` e `liga: ''`. Nenhuma adaptação foi necessária no
núcleo — o que a OS anterior escreveu contra um backend hipotético descreve o
backend verdadeiro.

Três acréscimos, todos de campos que o contrato **fornece**:

- `ligaId` — distingue Liga de estado de qualificação;
- `temporadaId` — sem ele não há como invalidar cache na virada de temporada;
- `FaseRanking.acessoRecusado` e `FaseRanking.sessaoInvalida` — separadas de
  `falha` e **uma da outra**, porque a **ação** é outra em cada uma. Numa falha
  recuperável tentar de novo resolve. Numa recusa de acesso não se sabe se a
  causa é credencial ou atestação, então a tela não acusa a sessão e oferece
  insistir. Só quando não existe sessão local é que "entre de novo" passa a ser
  uma afirmação verificável — e aí é `sessaoInvalida`.

## 4. Invalidação: sessão, cache, temporada

**Geração.** `SessaoDoJogador.geracao` já subia uma vez por troca de sessão. A
raiz repassa por `RankingDaSessao.aoMudarSessao`, que repassa ao leitor. Toda
resposta carrega a geração em que foi pedida; se ela avançou, a resposta é
**descartada antes de qualquer escrita** — nem a tela, nem o cache.

**Ordem, por chave.** Cada chave tem um número de pedido. Uma resposta cujo
número não é mais o último não pode sobrescrever a mais recente. Vale mesmo
quando a antiga chega depois — o caso que ninguém encena e todo mundo sofre.

**Ordem, global.** A guarda acima é por chave, e a homologação independente
mostrou que isso não basta: com duas chaves em voo e uma virada de temporada no
meio, cada resposta é a mais recente *da sua própria chave*, e mesmo assim uma
delas fala de um mundo que acabou. Ver a seção 4.1.

**Descarte é `null`.** O leitor devolve `EstadoRanking?`. `null` **não** é "sem
ranking" (isso é `indisponivel`, um valor); é "não aplique". Quem chama não faz
nada — a única reação correta.

**Cache.** Chaveado por `(publicId da conta, alvo, publicId do alvo)`. Só a
chave do alvo deixaria a fotografia de A visível para B; só a da conta juntaria
o perfil próprio com o de um visitado. Troca de sessão limpa tudo. Só
fotografia boa entra: guardar falha faria o retry seguinte mostrar o erro
anterior como se fosse dado.

**Temporada.** A virada só é perceptível quando uma resposta revela um
`temporadaId` diferente — o cliente não tem calendário, e inventar um seria a
mesma classe de erro que inventar liga. Quando a virada é aceita, todas as
fotografias de outra temporada saem do cache de uma vez.

**Retry.** Idempotente por dedupe de voo: três toques no botão emitem uma
chamada. Mesma garantia que `SessaoDoJogador.recarregar` já dava.

## 4.1. A temporada vencida entre chaves (defeito corrigido)

A primeira versão desta entrega tratava **qualquer** resposta que chegasse como
autoridade sobre a temporada corrente. A homologação independente reproduziu o
que isso permite:

```
1. rankingPublico(contaA, alvoX)  emitido enquanto era T1, fica em voo
2. meuRanking(contaA)             emitido depois, responde T2, é aplicado
3. a resposta de T1 finalmente chega
   -> era DEVOLVIDA ao consumidor como se fosse atual
   -> e ainda DESPEJAVA do cache a fotografia boa de T2
```

A correção não compara `temporadaId`. Não dá: o identificador é opaco, e ordená-lo
por string funcionaria hoje e mentiria no dia em que a autoridade emitisse
`verao`/`inverno`, um ULID, ou qualquer coisa que não ordene. Também não vale
tratar a última resposta *recebida* como a mais nova — resposta atrasada chega
por último justamente por estar atrasada.

O que o cliente sabe com certeza é **a ordem em que ele perguntou**. Então o
leitor guarda duas coisas: a temporada aceita e o **número do pedido** que a
estabeleceu (`_temporadaAceita` e `_pedidoDaTemporada`). Uma resposta de outra
temporada só troca a aceita se nasceu de um pedido posterior ao que estabeleceu
a atual. Nascida antes, é notícia velha: não é devolvida, não entra no cache,
não invalida nada e não muda a temporada aceita.

Três casos continuam passando de propósito:

- `temporadaId` nulo — o contrato publica nulo em
  `consultarJogadorPorIdPublico` quando não há temporada vigente. É ausência de
  notícia, não notícia de virada: não estabelece, não derruba, não invalida;
- mesma temporada, de outra chave, chegando fora de ordem — não há nada de
  vencido nela;
- temporada diferente vinda de pedido posterior — é a virada de verdade.

A **troca de sessão zera também a temporada aceita**, e essa linha não é
higiene: sem ela, a conta que entra herdaria a autoridade temporal da que saiu e
descartaria como "vencida" a resposta legítima da conta nova.

Portão: `app/test/ranking/regressao_leitor_ranking_test.dart`, grupo A.

## 5. Acessibilidade

Lido em voz alta, o que estava na tela virava lixo: três fragmentos soltos, o
emoji anunciado como "diamante" — que parece o *nome* de uma liga —, o `·` como
ruído, o `#` como "cerquilha", e o travessão da ausência como "traço".

A linha inteira virou **um** nó semântico com uma frase escrita para ser
ouvida, e os filhos saem da árvore de acessibilidade (`excludeSemantics`) para
que o leitor não anuncie a frase **e depois** soletre os fragmentos.

| Estado | Anúncio |
|---|---|
| liga + posição | `Liga Ouro. Posição 128 no mundo.` |
| liga sem posição válida | `Liga Prata. Sem colocação no mundo.` |
| resposta sem colocação | `Ainda não classificado.` |
| carregando | `Carregando sua classificação.` |
| falha | `Não foi possível carregar sua classificação. Use o botão de tentar novamente.` |
| sessão inválida | `Classificação indisponível: entre na sua conta de novo.` |
| indisponível | `Classificação ainda não disponível.` |

## 6. Onde o ranking real chega

| Superfície | Origem | Observação |
|---|---|---|
| Home | `EscopoRanking.meuEstadoDe` | rótulo de qualificação **não** entra: o cabeçalho mostra a liga sem prefixo, e ali um estado passaria por nome de liga |
| Perfil próprio | `EscopoRanking.meuEstadoDe`, lido no `build` | acompanha a consulta em voo em vez de congelar o valor da carga |
| Perfil visitado | `LeitorDeRanking.rankingPublico` | resultado **não** entra no estado da casca — é de outra pessoa |
| Compartilhamento | `PerfilVM.ranking` | cada trecho só entra se houver o que afirmar |

Fora do escopo (prévias, testes de widget de outras telas) tudo continua
valendo `rankingDaCascaPublicavel`. Sem autoridade não se afirma nada — e essa
é a razão de os 749 casos anteriores continuarem verdes sem uma linha de
adaptação.

## 7. App Check: a pendência externa, e o defeito que ela expôs

`opcoesCliente` do backend traz `enforceAppCheck: true`. O app declara
`firebase_app_check` no `pubspec.yaml` mas **não o ativa** (decisão registrada
no próprio pubspec: a ativação acontece antes da abertura pública). Enquanto
estiver assim, as duas callables recusam em produção. Isso **não** é introduzido
por esta OS: `obterMinhaIdentidade`, já em produção, tem a mesma exigência.

**A recusa chega como `unauthenticated`, e não como `permission-denied`.** Esta
seção afirmava o contrário, e era leitura errada do contrato. Medido em
`firebase-functions@6.6.0`, `lib/common/providers/https.js` — a faixa que
`functions-ranking/package.json` declara (`^6.1.0`):

```js
if (tokenStatus.auth === "INVALID")                    throw new HttpsError("unauthenticated", "Unauthenticated");
if (tokenStatus.app  === "INVALID" && enforceAppCheck) throw new HttpsError("unauthenticated", "Unauthenticated");
if (tokenStatus.app  === "MISSING" && enforceAppCheck) throw new HttpsError("unauthenticated", "Unauthenticated");
```

Três causas, um código só. Credencial recusada e App Check ausente ou inválido
são **indistinguíveis** do lado do cliente — e nas duas últimas a sessão do
jogador está viva.

A primeira versão desta entrega traduzia `unauthenticated` para
`FaseRanking.sessaoInvalida`, e a tela dizia *"Classificação indisponível: entre
na sua conta de novo."* — sem botão de tentar novamente. Com o App Check não
ativado, era o que **toda** chamada produzia: o único conselho errado, e nenhuma
das ações certas.

O que existe agora:

| Situação | Código | Motivo | Fase | Retry |
|---|---|---|---|---|
| Sem sessão local | `unauthenticated` | `credencialOuAtestacao` | `sessaoInvalida` | não |
| Credencial recusada, sessão local viva | `unauthenticated` | `credencialOuAtestacao` | `acessoRecusado` | **sim** |
| App Check ausente/inválido, sessão local viva | `unauthenticated` | `credencialOuAtestacao` | `acessoRecusado` | **sim** |
| Leitura negada para a conta | `permission-denied` | `recusado` | `acessoRecusado` | **sim** |
| Soluço transitório | `unavailable`, `internal`, … | `indisponivel` | `falha` | sim |

O transporte **preserva a ambiguidade** — não tem como desfazê-la. Quem decide é
`EstadoRanking.daFalha`, que exige `haSessaoLocal` como parâmetro obrigatório: um
valor padrão faria a chamada esquecida escolher um lado sozinha, e o lado que ela
escolheria em silêncio é o que produziu o defeito.

Com sessão viva, a tela diz *"Não foi possível acessar sua classificação. Tente
novamente."* — não acusa a sessão de nada e aponta para a única ação que pode
funcionar. **Nenhum logout é disparado por falha de ranking**, nem sessão,
identidade, geração ou perfil são apagados. **Nenhum dado é inventado.**

A ativação do App Check continua sendo pendência externa e fora do escopo (§8
desta OS proíbe ativá-la).

Portão: `app/test/ranking/regressao_leitor_ranking_test.dart`, grupo B.

## 8. Números

Medidos numa árvore limpa, com a pré-condição conhecida dos seeds de
`app/data/` reproduzida em `test/colecoes/data/` e `test/torneios/data/`.

| | Base `bc74e30` | Entrega `93c4d748` | Correção |
|---|---|---|---|
| `flutter test` (glob `*_test.dart`) | 749 | 790 | **812** |
| Suítes `teste_*.dart` | 549 | 549 | **549** |
| **Total** | 1298 | 1339 | **1361** |
| `flutter analyze` — erros | 0 | 0 | **0** |

Nenhum caso removido, pulado, comentado ou neutralizado em nenhuma das duas
etapas. `dart format` limpo em todos os arquivos novos. Os dois PNGs de
evidência que a suíte regenera foram restaurados antes de cada commit.

**Sobre o número absoluto de issues do `analyze`:** as 38 da coluna de entrega
foram medidas no CI, com o Flutter 3.44.8 que o workflow pina. Fora dele o
conjunto de lints é outro, e o valor absoluto não é reproduzível — a medição
local desta correção dá 98, e a da própria `93c4d748` na mesma máquina dá 98
também. O que vale como portão é a comparação no MESMO toolchain: a lista
normalizada de advertências é idêntica entre a entrega e a correção, e os erros
seguem em zero nas duas.
