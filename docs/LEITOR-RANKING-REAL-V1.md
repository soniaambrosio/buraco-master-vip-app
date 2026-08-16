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
- `FaseRanking.sessaoInvalida` — separada de `falha` porque a **ação** é outra:
  numa falha recuperável tentar de novo resolve; numa credencial recusada,
  insistir só repete a recusa, e oferecer "tentar novamente" é prometer o que o
  botão não cumpre.

## 4. Invalidação: sessão, cache, temporada

**Geração.** `SessaoDoJogador.geracao` já subia uma vez por troca de sessão. A
raiz repassa por `RankingDaSessao.aoMudarSessao`, que repassa ao leitor. Toda
resposta carrega a geração em que foi pedida; se ela avançou, a resposta é
**descartada antes de qualquer escrita** — nem a tela, nem o cache.

**Ordem.** Cada chave tem um número de pedido. Uma resposta cujo número não é
mais o último não pode sobrescrever a mais recente. Vale mesmo quando a antiga
chega depois — o caso que ninguém encena e todo mundo sofre.

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
mesma classe de erro que inventar liga. Quando aparece, todas as fotografias de
outra temporada saem do cache de uma vez.

**Retry.** Idempotente por dedupe de voo: três toques no botão emitem uma
chamada. Mesma garantia que `SessaoDoJogador.recarregar` já dava.

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

## 7. Pendência externa registrada

`opcoesCliente` do backend traz `enforceAppCheck: true`. O app declara
`firebase_app_check` no `pubspec.yaml` mas **não o ativa** (decisão registrada
no próprio pubspec: a ativação acontece antes da abertura pública). Enquanto
estiver assim, as duas callables recusam em produção com `permission-denied`.

Isso **não** é introduzido por esta OS: `obterMinhaIdentidade`, já em produção,
tem a mesma exigência. A recusa vira `MotivoFalhaRanking.recusado` →
`FaseRanking.sessaoInvalida`, que a tela mostra honestamente. **Nenhum dado é
inventado por causa disso.** É pendência de ativação, não de código, e está
fora do escopo desta OS (§9 proíbe mexer em backend e infraestrutura).

## 8. Números

Medidos numa árvore limpa, com a pré-condição conhecida dos seeds de
`app/data/` reproduzida em `test/colecoes/data/` e `test/torneios/data/`.

| | Base `bc74e30` | Esta branch |
|---|---|---|
| `flutter test` (glob `*_test.dart`) | 749 | **790** |
| Suítes `teste_*.dart` | 549 | **549** |
| **Total** | 1298 | **1339** |
| `flutter analyze` | 38 issues, 0 erros | **38 issues, 0 erros** |

+41 casos, nenhum removido, pulado ou neutralizado. `dart format` limpo em
todos os arquivos novos e alterados por esta OS. Os dois PNGs de evidência que
a suíte regenera foram restaurados antes de cada commit.
