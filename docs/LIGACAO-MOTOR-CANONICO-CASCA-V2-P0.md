# Ligação do motor canônico à Casca V2 — P0

Como a Casca V2 publicável alcança uma partida de verdade, e onde mora a
autoridade de cada coisa.

- **Base:** `bc74e30a148a56b00ca7db691a378584efaa5207`
  (`claude/perfil-ranking-estado-canonico-v1-cac971`)
- **Contrato do servidor conferido:** `buraco-servidor`,
  `16a692bbe95597536b3f9975ecf32e1bde58ebcb`
  (`claude/produtor-encerramento-autoritativo-v1`) — lido, nunca alterado.

---

## 1. Os dois caminhos

O aplicativo tem duas superfícies de jogo, e elas **não compartilham motor**.

### Treino — local, e continua local

```
main.dart
  └─ RaizDoAplicativo ........ monta sessão, autenticação, transporte, ponte
      └─ CascaDeProducao ..... lê a sessão e decide: Login ou Home
          └─ HomeDeProducao
              └─ OndeJogarDeProducao
                  └─ [Treino] → MesaScreen  (lib/mesa.dart)
                                 └─ Jogo    ← o motor roda NO APARELHO
```

Sem rede, sem credencial, sem socket, sem ranking. Esta OS não tocou em
`lib/mesa.dart`.

### Online — o servidor manda

```
OndeJogarDeProducao
  └─ [Mesa por código] → LobbyOnline
        │
        │  EscopoTransporte  →  OnlineService   (o ÚNICO, montado na raiz)
        │                            ↑↓ WebSocket autenticado
        │                       servidor Railway ← A AUTORIDADE
        │
        ├─ visao == null ............... entrada: criar mesa / entrar por código
        ├─ visao.lobby == true ......... sala de espera
        ├─ visão recusada .............. erro honesto + saída
        └─ visão de partida ............ MESA COMPLETA, no mesmo lugar da pilha
                │
                │  AdaptadorVisaoOnline.ler()  →  EstadoMesaOnline   (validado)
                │                                       ↓
                │                                 MesaOnlineScreen
                │                                       ↓ gesto
                │                            PortaDeComandosOnline
                │                                       ↓
                └────────────────────────────→  OnlineService → servidor
```

O laço fecha no servidor. **Nenhum `Jogo` é construído no caminho online** —
há teste de auditoria que falha se alguém construir um.

---

## 2. Autoridade de cada estado

| Estado | Quem decide | Como chega |
|---|---|---|
| Distribuição, mão, monte, mortos | servidor | `estado.visao.suaMao` / contagens |
| De quem é a vez | servidor | `vez`, `suaVez` |
| Já comprou nesta jogada | servidor | `jaComprou` |
| Validade de uma jogada | servidor | aceita → visão nova; recusa → `erro{motivo}` |
| Placar e rodada | servidor | `placar`, `rodada` |
| Jogos baixados | servidor | `jogosDupla` |
| Quem bateu, encerramento | servidor | `duplaQueBateu`, `encerrada` |
| Obrigação de usar o topo | servidor | `precisaUsarTopo` (cliente só destaca) |
| Assento desta conexão | servidor | `entrou{assento}` |
| Identidade | sessão canônica | `SessaoDoJogador` → `auth` |
| **Seleção de cartas** | **cliente** | local, visual, some a cada visão nova |
| **Intenção pendente** | **cliente** | trava de interface, não vai no fio |

O cliente decide **duas** coisas, e as duas são sobre o dedo da pessoa, não
sobre a partida.

---

## 3. Mensagem do servidor → estado de apresentação

`visaoDoAssento` (servidor) → `EstadoMesaOnline` (cliente):

| Campo da visão | Vira | Observação |
|---|---|---|
| `voceAssento` | `meuAssento` | conferido contra `entrou{assento}`; divergiu, recusa |
| `modalidade` | `modalidade` | obrigatório |
| `metaPontos` | `metaPontos` | **nulo permitido** — sem meta, a tela não mostra meta |
| `rodada` | `rodada` | obrigatório |
| `placar{nos,eles}` | `placarPorDupla` → `meusPontos` / `pontosAdversarios` | ver §5 |
| `vez`, `suaVez` | `vez`, `suaVez` | obrigatórios |
| `jaComprou` | `jaComprou` | obrigatório |
| `suaMao[]` | `minhaMao` | tudo-ou-nada: uma carta ilegível recusa a mão inteira |
| `assentos[]` | `assentos` | só `apelido`, `tipo`, `dupla`, `qtdCartas`, `ehVoce` |
| `monteQtd`, `lixoQtd`, `mortosQtd` | idem | inteiros ≥ 0, obrigatórios |
| `lixoTopo` | `lixoTopo` | **nulo = lixo vazio** |
| `lixoAberto` | `lixoAberto` | **nulo = não visível**, nunca "vazio" |
| `jogosDupla{nos,eles}` | `jogosPorDupla` → `meusJogos` / `jogosAdversarios` | |
| `encerrada`, `rodadaEncerrada` | idem | |
| `duplaQueBateu` | `duplaQueBateu` → `euBati` | nulo = ninguém bateu ainda |
| `pontosRodada` | `pontosRodada` | mapa cru, ainda não desenhado |
| `precisaUsarTopo` | `precisaUsarTopo` | destaca a carta; **não bloqueia** |
| `versaoEstado` | `versaoEstado` | **o servidor de `16a692b` não manda** — nulo |
| `jogadorId`, `avatar*` | — | **não atravessam**: esta fatia não desenha avatar |
| `maos`, `monte`, mãos alheias | — | **não existem na visão de assento** e não são lidos |

Estrutura inválida em qualquer campo obrigatório produz `VisaoRecusada`, e a
tela mostra "Não consegui entender a mesa" com uma saída. **Não há valor
padrão** — nada de `?? 0`, `?? []` ou carta vazia.

---

## 4. Gesto → comando do protocolo

| Gesto | Comando no fio | Habilitado quando |
|---|---|---|
| tocar o monte | `{tipo:'jogada', jogada:{tipo:'comprarMonte'}}` | vez + não comprou + monte > 0 |
| tocar o lixo | `…{tipo:'comprarLixo'}` | vez + não comprou + lixo > 0 |
| selecionar N + "Baixar" | `…{tipo:'baixar', ids:[…]}` | vez + já comprou + N ≥ 1 |
| selecionar 1 + "Descartar" | `…{tipo:'descartar', id}` | vez + já comprou + N = 1 |
| (porta expõe) estender | `…{tipo:'estender', indiceJogo, ids}` | vez + já comprou |
| "Sair" | `{tipo:'sair'}` | sempre — passa por cima da trava |

Todas as condições espelham `validarVez` do servidor, que é o portão único de
todas as jogadas. **Isto não é a regra reimplementada:** é o que a tela precisa
saber para não oferecer um botão que seria recusado. O julgamento continua
sendo do servidor, e uma capacidade aberta aqui não faz jogada nenhuma valer.

---

## 5. As três decisões que mereceram nome

### 5.1 A dupla é absoluta no fio e relativa na tela

No servidor, `nos` são os assentos **0 e 2** e `eles` são o **1 e 3** — sempre,
independentemente de quem lê. `placar.nos` **não** quer dizer "o placar de quem
está lendo".

O resumo anterior desenhava `'Nós ${placar['nos']} × ${placar['eles']} Eles'`.
Para quem sentasse nos assentos ímpares, isso mostrava **o placar do adversário
como se fosse o seu**. `EstadoMesaOnline.minhaDupla` fecha a troca: `meusPontos`,
`meusJogos` e `euBati` são relativos a quem está sentado, e a tela nunca precisa
conhecer a convenção do servidor.

### 5.2 Lobby → mesa é troca de corpo, não rota nova

A mesa é o **corpo da mesma rota** do lobby. Não há `push`.

A alternativa imperativa tem três defeitos, e os três aparecem em produção antes
de aparecer em teste:

1. `OnlineService` notifica a cada mensagem; um `push` no ouvinte empilha uma
   mesa por atualização recebida;
2. remendando com uma bandeira "já empurrei", um `pop` — o gesto de voltar do
   Android — devolve a pessoa a um lobby que afirma "aguardando jogadores"
   sobre uma partida em andamento;
3. rodada encerrada, queda, retomada e fim de partida viram, cada um, uma
   decisão de empilhar ou desempilhar, espalhada por vários pontos.

Sendo o corpo da rota, nada disso existe: o estado do servidor determina o que
se desenha, e voltar significa sair da tela do online. É o mesmo raciocínio
declarativo que `casca_de_producao.dart` usa para escolher entre Login e Home.

### 5.3 Idempotência sem `eventoId`

O protocolo **não tem** identificador de evento nem versão de estado. Dois
toques em "comprar" chegam ao servidor como duas compras, e ele não sabe dizer
que eram a mesma intenção.

Sem carimbo no fio, a idempotência é do lado do cliente — e é uma **trava**, não
um filtro de repetidos: enquanto uma intenção espera resposta, **nenhuma outra
sai**. É mais forte do que bloquear apenas a intenção equivalente, porque
"comprar" seguido de "descartar" antes da resposta também é uma dupla que não
pode acontecer.

A trava sai por **autoridade**: visão nova, recusa do servidor, ou queda da
conexão. Nunca por otimismo. Há um teto de espera (12 s) que devolve o controle
à pessoa sem aplicar nada e sem reenviar — porque uma mesa travada para sempre é
pior do que uma mesa que admite não ter ouvido resposta.

**Nada é aplicado localmente, em caso nenhum.** A tentação num jogo de cartas em
rede é tirar a carta da mão na hora e devolvê-la se o servidor recusar; nesse
intervalo a pessoa olha para uma mesa que não existe em lugar nenhum, e a
correção parece defeito ("a carta voltou sozinha").

---

## 6. Reconexão

| Momento | O que a mesa faz |
|---|---|
| conexão cai | mesa continua desenhada com o último retrato autoritativo; faixa avisa; **ações desabilitadas** |
| backoff tentando | idem — sumir com a mesa pareceria "a partida acabou" |
| socket novo aberto | nada muda na tela até a visão chegar |
| `autenticado` + `entrou` | ainda nada: assento sem visão não é mesa |
| `estado` novo | a mesa é substituída pelo retrato novo |
| mensagem do socket anterior | **descartada** — cada abertura tem crachá de geração |
| falha terminal | mensagem explícita + "Tentar de novo"; o ciclo automático para |
| logout / troca de conta | pilha de navegação inteira morre (chave de geração no `MaterialApp`), `visao` e `codigo` apagados |

Uma intenção pendente na hora da queda é destravada e **não reenviada**: o que
aconteceu com ela só o servidor sabe, e a visão da retomada é que vai dizer.

---

## 7. Campos omitidos por falta de autoridade

Nada aqui foi preenchido com valor plausível.

| O que não tem | Por quê |
|---|---|
| **Prazo do turno / cronômetro** | a visão de assento não traz relógio nenhum. Um contador desenhado aqui seria contagem inventada, e a pessoa acreditaria nela. |
| **`versaoEstado` no fio** | o servidor não manda. O campo é lido quando existe; a ausência **não** vira número de fabricação própria. A ordem, hoje, é a do socket. |
| **`eventoId` / idempotência no servidor** | não existe no protocolo. Ver §5.3. |
| **Avatar dos jogadores** | chega na visão, mas o adaptador não o transporta e esta fatia não desenha foto. |
| **`pontosRodada` detalhado** | transportado, ainda não desenhado — falta a tela de contagem. |
| **Vencedor sem `duplaQueBateu`** | partida encerrada sem o servidor dizer quem bateu mostra "A partida terminou" e o placar. Anunciar um vencedor seria inferência. |
| **Conquista, ranking, economia** | o cliente não concede nada por inferência. Fora do escopo desta OS. |

---

## 8. Riscos residuais

1. **Divergência da arte entre treino e online.** `lib/mesa.dart` tem 3434
   linhas e é a única superfície de jogo que funciona ponta a ponta; extrair
   dele as funções de arte para um módulo comum seria gastar o risco no lugar
   errado, e esta OS proíbe regredir o treino. O preço é a duplicação da
   convenção de nomes de asset. Está **vigiada por teste**
   (`auditoria_mesa_online_test.dart` lê a fonte dos dois e falha se
   divergirem). Quando alguém reformar `mesa.dart` por outro motivo, a extração
   fica barata e o teste vira desnecessário.

2. **Sem versão de estado, uma reordenação de mensagens não é detectável.** Um
   socket entrega em ordem, então o risco é teórico hoje. O mecanismo de
   comparação já existe e é testado; falta só o servidor mandar o campo.

3. **O teto de espera de 12 s é uma escolha, não uma medida.** Não há telemetria
   de latência real de partida. Curto demais destrava cedo e a pessoa pode
   tocar duas vezes; longo demais prende. O valor é parâmetro de construção.

4. **`estender` não tem gesto na tela.** A porta expõe o comando e ele é
   testado, mas escolher a qual jogo estender pede uma interação (arrastar
   sobre o jogo) que esta fatia não desenhou.

5. **Espectador não foi ligado.** O servidor tem `assistirMesa` e uma visão
   pública própria; o `OnlineService` não a expõe, e a OS não pedia.

6. **`afkBot` / `afkVoltar` não são acionados pelo cliente.** O servidor os
   suporta; sem eles, uma pessoa que se ausenta continua segurando o assento até
   o servidor decidir por conta própria.

---

## 9. Onde está cada coisa

| Arquivo | Papel |
|---|---|
| `lib/casca/mesa_online/estado_mesa_online.dart` | contrato de apresentação + adaptador da visão (a única porta de leitura) |
| `lib/casca/mesa_online/porta_de_comandos_online.dart` | a única porta de saída de comandos |
| `lib/casca/mesa_online/mesa_online_screen.dart` | a mesa desenhada |
| `lib/casca/mesa_online/arte_das_cartas.dart` | carta, dorso, pilha fechada |
| `lib/casca/lobby_online.dart` | entrada, lobby, e a troca de corpo para a mesa |
| `lib/services/online_service.dart` | transporte (alterado só para expor `erroCodigo`) |
| `test/casca/bancada_online.dart` | bancada compartilhada; visões copiadas do contrato |
| `test/casca/ligacao_mesa_caracterizacao_test.dart` | o que já funcionava e não pode regredir |
| `test/casca/adaptador_visao_online_test.dart` | leitura e recusa |
| `test/casca/porta_de_comandos_online_test.dart` | comandos, trava, classificação de recusa |
| `test/casca/mesa_online_test.dart` | o caminho inteiro, da Home à mesa |
| `test/casca/auditoria_mesa_online_test.dart` | a prova de ausência |
