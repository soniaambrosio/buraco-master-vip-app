# Barreira temporal do leitor de ranking — v2

Branch `correcao/leitor-ranking-real-casca-v2-v2`, a partir de
`1c67777ff3675d0bc3a9382e31c98e9a6ba59a1c`
(`correcao/leitor-ranking-real-casca-v2-v1`).

A correção de acesso/App Check daquela branch é **preservada integralmente**.
Nada em `estado_ranking.dart`, `ranking_transporte.dart`,
`ranking_transporte_firebase.dart`, `perfil_screen.dart` ou
`leitor_ranking_real_test.dart` foi tocado, e o único hunk dela dentro do
leitor — `haSessaoLocal: chave.contaPublicId.trim().isNotEmpty` — continua onde
estava. A suíte B da regressão segue verde, 13/13.

---

## 1. O que ainda vazava

`_aceitarTemporada` ancorava em `_pedidoDaTemporada`: **o número do pedido que
estabeleceu a temporada**. Duas consequências, e as duas foram exploradas.

**Primeira — a âncora ficava presa.** Uma resposta que apenas *confirma* a
temporada vigente não movia o número. A barreira permanecia lá atrás, e
qualquer pedido de número maior podia derrubá-la.

**Segunda — a ordem inversa.** O caso reprovador, com os dois pedidos nascidos
juntos:

| | pedido | o servidor atendeu | devolveu |
|---|---|---|---|
| próprio | #1 | **depois** da virada | T2 |
| público | #2 | **antes** da virada | T1 |

`#1` estabelece T2 e ancora em **1**. `#2` chega com T1, e `2 < 1` é falso —
então a notícia velha passava: era devolvida como atual, entrava no cache e
despejava a fotografia boa de T2.

A rodada anterior só testou a ordem oposta (a temporada nova vindo do pedido de
número **maior**), e por isso passou.

## 2. A raiz

Supor que o pedido de número maior viu o mundo mais novo é a mesma classe de
erro que supor que o último a chegar é o mais recente.

**Pedidos contemporâneos não se ordenam entre si.** O cliente sabe quando
*emitiu* cada um; não sabe em que ordem o servidor os atendeu. Entre dois
pedidos que estavam no ar ao mesmo tempo, qualquer desempate é chute.

## 3. A regra nova

A barreira passa a ser **`_sequencia` no instante em que a temporada foi
aprendida** — o número do último pedido emitido até ali.

- tudo com número **≤** barreira já estava em voo naquele momento:
  contemporâneo, e não posterior;
- só um pedido emitido **depois** — cujo número é necessariamente maior — pode
  trocar a temporada aceita;
- entre contemporâneos divergentes, o leitor **mantém o que sabe**. A próxima
  pergunta é sequencialmente posterior e resolve sozinha, então a virada é
  aprendida na leitura seguinte em vez de ser adivinhada nesta.

Duas precisões que o caso exigiu:

- **"aprendida" inclui CONFIRMADA.** Uma resposta que repete a temporada
  vigente é notícia tão fresca quanto uma que a troca. Não reancorar nela era o
  segundo caminho para a barreira ficar para trás.
- **comparação estrita.** Empatar com a barreira é ser contemporâneo dela, e
  contemporâneo não é posterior. `numero <= _barreiraTemporal` recusa.
- **a âncora nunca anda para trás** (`max`): uma resposta atrasada que confirma
  a temporada é válida, mas não pode reabrir uma janela que uma resposta mais
  nova já fechou.

O que **não** mudou: `temporadaId` nulo continua sendo ausência de notícia — não
estabelece, não derruba, não despeja e não move a âncora; falha não carrega
temporada, então também não mexe em nada; e uma resposta recusada não altera
retorno, cache nem fotografia.

## 4. O segundo defeito, no mesmo arquivo

O `finally` de `_executar` fazia `_emVoo.remove(chave)` incondicional, apoiado
na suposição "só existe um voo por chave". A suposição é falsa depois de
`aoMudarSessao`, que esvazia `_emVoo` **sem cancelar o que está no ar**: o voo
velho continua vivo e, ao terminar, despejava do mapa o voo **novo** da mesma
chave. O dedupe furava e o toque seguinte abria uma chamada a mais.

Agora `_donoDoVoo` guarda o número do pedido dono do voo corrente, e cada voo
só retira o próprio.

Só morde quando a chave é a mesma nas duas gerações — ou seja, quando a
**conta não muda** (recarga de sessão). Com troca de jogador as chaves diferem
e o defeito não aparece, e é por isso que o caso R7d existe separado: sem ele,
a suíte passaria sem provar nada.

## 5. Os oito casos pedidos

| Grupo | Caso | Cobertura |
|---|---|---|
| R1 | ordem inversa | R1a (o reprovador), R1b (a ordem original continua fechada), R1c (a virada sequencial legítima continua sendo aceita) |
| R2 | confirmação reancora | R2a, R2b (confirmar não despeja a própria temporada), R2c |
| R3 | pedido igual à barreira | R3a, R3b (a recusa não envenena a barreira) |
| R4 | temporada nula | R4a, R4b (nulo não move a âncora), R4c (fotografia sem temporada sobrevive à virada) |
| R5 | falha de transporte | R5a, R5b, R5c (exceção fora do vocabulário) |
| R6 | recusa não altera nada | R6a (retorno, cache e fotografia campo a campo), R6b |
| R7 | voo antigo terminando depois do novo | R7a, R7b, R7c, **R7d** (mesma conta — o único que pega o dedupe) |
| R8 | três toques, uma chamada | R8a, R8b (depois de troca de sessão), R8c (depois de resolver, o retry pergunta de novo) |

R1c, R2c, R3b, R4b, R5b e R8c são contrapesos: apertar a barreira não pode
transformar o leitor em algo que nunca mais aprende que a temporada virou, nem
o retry em botão que não faz nada.

## 6. Números

Overlay dos seeds de `app/data/` reproduzido em `test/colecoes/data/` e
`test/torneios/data/`, como a pré-condição conhecida exige.

| | Base `1c67777` | Esta branch |
|---|---|---|
| `flutter test` (glob) | 812 | **835** |
| Suítes `teste_*.dart` | 549 | **549** |
| **Total** | 1361 | **1384** |
| `flutter analyze lib/ test/` | 38 issues, 0 erros | **38 issues, 0 erros** |

+23 casos, nenhum removido, pulado ou neutralizado. `dart format` limpo nos
dois arquivos desta branch.

**A suíte nova, rodada contra a base sem a correção: 17 verdes e 6 vermelhos** —
R1a, R2a, R3a, R6a, R6b e R7d. É a prova de que ela mede o que diz medir.

## 7. O que continua aberto, e não é desta branch

- **Ativação do App Check.** As duas callables exigem atestação; o app declara
  `firebase_app_check` e não o ativa. Pendência de infraestrutura.
- **`consultarJogadorPorIdPublico` sem chamador de produção.**
  `home_de_producao.dart` constrói `const PerfilPage()` sem `publicIdVisitado`,
  então `rankingPublico` é alcance latente — testado, ligado, mas nenhuma
  navegação chega lá.
