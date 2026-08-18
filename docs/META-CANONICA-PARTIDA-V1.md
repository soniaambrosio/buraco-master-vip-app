# Meta canônica de partida 1500 / 2000 / 3000 — V1

**Veredito: `PASS — META CANÔNICA 1500/2000/3000 CONFIGURÁVEL NO LOBBY E AUTORITATIVA NO SERVIDOR V1`**

| Repositório | Branch | HEAD | Base |
| --- | --- | --- | --- |
| app | `claude/meta-canonica-lobby-v1` | `864a15a` | `089cb5e` |
| servidor | `claude/meta-canonica-partida-v1` | `1d7c0be` | `3016f64` |

Publicadas sem merge, sem PR e sem deploy.

---

## 1. Gate Zero

| Pergunta | Resposta |
| --- | --- |
| Branch produtiva da Casca/Home/Onde Jogar/Lobby | `integracao/avatar-ranking-estatisticas-navegacao-publica-v1` @ `089cb5e` |
| Branch mais recente do servidor com criação de mesa | `homologacao/alvo-operacional-credencial-v1` @ `3016f64` |
| Contrato atual de `metaPontos` | já viajava por mesa, **sem validação nenhuma** |
| Testes que já cobrem criação e entrada | 379 casos no servidor; 809 no app |

**Sobre a escolha da base do app:** existem dois topos de 18/08 e eles são
incomparáveis — `089cb5e` e `claude/chat-transporte-real-v1` @ `3d124b0`.
Medidos por conteúdo, `089cb5e` contém tudo o que `3d124b0` contém das
linhagens canônicas do produto, e mais três (avatar+ranking compostos,
navegação ao Perfil público, contrato de estatísticas). O lobby é byte a byte o
mesmo nos dois. Chat é folha à parte e não entra aqui.

**Sobre a base do servidor:** `3016f64` **contém** `274c50d` (a linhagem de mesa
privada/VIP mais recente), e é o alvo operacional canonizado — o commit que
`GET /versao` responde. Não há escolha a fazer: é o único topo que carrega as
duas coisas.

**A tela órfã não foi promovida.** `configurar_mesa_screen.dart` continua sem
rota e sem teste, exatamente como o laudo anterior a encontrou. Nada dela foi
importado: o seletor novo tem 30 linhas e mora no lobby.

## 2. STOP — a meta É atributo da mesa

Confirmado por código e por teste antes de qualquer edição:
`criarMesa` recebia `metaPontos`, `sala.metaPontos` existia, e
`iniciarPartida` já criava o jogo com ele (`server.js:4743`). Não houve
`BLOCKED`.

O que **não** existia era validação: `metaPontos: msg.metaPontos` entrava cru,
e uma mesa de meta 7 (ou de meta `"2000"`, ou `NaN`) era aceita. Era esse o
buraco, e não a ausência do campo.

## 3. A lista branca, e o padrão

```js
const METAS_CANONICAS = Object.freeze([1500, 2000, 3000]);
const META_PADRAO = 2000;
```

**Recusar não é cair no padrão.** Só a **ausência** do campo vira 2.000 — é o
cliente antigo, que não sabe que existe meta. Valor **presente** é uma escolha:
fora da lista se recusa, em vez de virar outra coisa nas costas de quem
escolheu. Se `1999` virasse `2000` calado, a pessoa jogaria uma partida que não
pediu e ninguém saberia. `META-07` mede exatamente essa diferença.

A recusa acontece **antes** de sortear código e antes do gate de admissão:
pedido recusado não deixa sala meio construída nem código em uso. Cada um dos
18 valores recusados tem um caso próprio que confere isso (`META-06/*`).

**O padrão é declarado, e de propósito não é `METAS_CANONICAS[0]`.** Derivar o
padrão da ordem da vitrine faz reordenar botão trocar regra sem ninguém notar.
`META-05` (servidor) e `MET-02` (app) caem se alguém amarrar os dois de novo.

### O padrão anterior era 3.000 — e não era uma decisão

Exigido pela §5 da OS, que manda parar e relatar se já houvesse outro padrão
autoritativo homologado. **Não havia.** O 3.000 aparecia como valor escrito na
assinatura de três funções (`criarJogo`, `criarMesa` do servidor e
`OnlineService.criarMesa`), sem OS, sem laudo e sem documento de homologação em
nenhum dos dois repositórios. Não era um padrão do produto: era o número que
estava lá.

Uma ressalva honesta: `criarJogo` **continua** com 3.000 na assinatura, e isso é
deliberado. Ele é o motor, e responde a outra pergunta ("um jogo criado sem
mesa vai até quanto?"). Nenhuma mesa passa por esse caminho — a sala sempre
entrega a meta dela explicitamente, e `META-13` prova. Mexer no motor seria
mexer em regra do Buraco, que a §19 proíbe.

## 4. A mesa congela o que aceitou

`metaPontos` é `writable:false` na sala, como `categoriaCompetitiva` já era.

Não é zelo decorativo: quem entrou por código entrou **numa mesa de 2.000**, e
entrada, reconexão e revanche não podem transformá-la. A trava é estrutural
porque a alternativa seria confiar que nenhum caminho futuro escreva no campo —
e caminho futuro sempre existe. A mutação `MUT-8` mostra o que acontece sem
ela: o despachante passa a gravar `msg.metaPontos` na entrada, e três casos
caem de uma vez.

O início lê a meta da **sala**. `META-14` manda `iniciarPartida` com meta no
payload para provar que ninguém a consulta.

## 5. A superfície produtiva

No lobby, e não na maquete. Antes: um campo de apelido e um botão. Agora:

```
Meta da partida
[ 1.500 pontos ] [ 2.000 pontos ] [ 3.000 pontos ]
```

Três decisões que valem registro:

1. **A meta é um tipo, não um `int`.** `MetaDePontos` é enumeração fechada de
   três valores, e `criarMesa` só aceita esse tipo. Enquanto fosse `int`,
   "mandar 1.732" seria uma linha válida em qualquer ponto do cliente. Não é o
   cliente validando em nome do servidor — é o pedido inválido não nascendo.
2. **O toque define, não alterna.** Um `onSelected` que obedecesse ao booleano
   do Material deixaria apagar o botão aceso, e "mesa sem meta escolhida" não é
   um estado que exista no domínio.
3. **Meta fora do catálogo vira traço, não vira o padrão.** Se um dia as duas
   listas divergirem, o sintoma tem de ser visível. Desenhar 2.000 sobre uma
   mesa de 5.000 esconderia a divergência de quem poderia notá-la.

**Dentro da sala não há seletor.** A mesa já existe e o servidor congelou a
meta dela; oferecer o botão ali seria oferecer uma ação que não acontece. Quem
entra por código **vê** a meta (`Meta: 2.000 pontos`) e não a escolhe — e o
comando de entrada não tem por onde carregá-la.

## 6. A cicatriz da OS anterior

Abrir um campo de `msg` na criação da mesa é exatamente a hora em que a aposta
voltaria de carona. Cinco casos existem só para impedir isso:

| Caso | O que afirma |
| --- | --- |
| `APO-GUARDA-01` | `msg.aposta` continua sem leitor em ponto nenhum do bundle |
| `APO-GUARDA-02` | nenhum `msg.saldo`, `msg.custo`, `msg.fichas`, `msg.moedas`, `msg.recompensa`, `msg.premio`, `msg.preco` |
| `APO-GUARDA-03` | mesa com meta escolhida continua com a aposta **do processo** |
| `APO-GUARDA-04` | a chamada de `criarMesa` no despachante carrega três campos de `msg`: apelido, modalidade e meta |
| `APO-GUARDA-05` | `entrarMesa` não recebe meta do despachante |

E do lado do app, `MET-10` lê o payload real escrito no fio e exige que as
chaves sejam exatamente `tipo`, `apelido`, `metaPontos` e `modalidade`.

`APO-01` a `APO-05`, da OS anterior, seguem verdes e intocados.

## 7. Testes

| Suíte | Antes | Depois |
| --- | --- | --- |
| servidor (`npm test`) | 379 / 379 | **418 / 418** |
| app (`flutter test`) | 809 ✓ / 4 ✖ | **823 ✓ / 4 ✖** |

As 4 falhas do app são de **carregamento**, nos mesmos quatro arquivos
(`colecoes/evidencias_visuais`, `colecoes/kit_pioneiros`,
`torneios/motor_torneios`, `torneios/reward_grants`) — as suítes que só montam
com o overlay de dados do CI. Falhavam iguais na base intocada; não são desta
OS. Analyzer: 38 issues antes e 38 depois, todas do `flutter_lints` em arquivos
que esta OS não tocou.

### O que aconteceu com as mesas de meta 100 da suíte do servidor

Oito arquivos criavam mesas de meta 100 (e um de meta 1) para chegar ao
encerramento sem jogar 2.000 pontos de bot. Com a lista branca isso deixou de
ser possível — e **não** foi aberta porta de teste para permiti-lo: um
servidor que aceita meta 100 quando o teste pede não é o servidor que roda.

A mesa passou a nascer canônica, e quem encurta a partida é o **jogo**, depois
de iniciado (`sala.jogo.metaPontos = 100`) — estado do motor, que essas suítes
já reescrevem à mão para forçar placar e encerramento. Onde a meta curta era
apenas decorativa (o teste forçava `placar = metaPontos` logo depois), o campo
saiu. Nenhuma asserção foi afrouxada ou removida.

### Auditoria do fecho alcançável

De 48 para 49 arquivos, com o novo nomeado no próprio teste
(`lib/services/meta_de_pontos.dart`) — mesma disciplina das duas composições
anteriores. O total é alarme de crescimento **inesperado**; crescimento
previsto se declara.

## 8. Mutações — 12, todas detectadas

Cada mutação foi aplicada sobre o commit publicado, medida por `numstat` (para
não creditar mutante que não pegou) e revertida.

| # | Mutação | Detectada por |
| --- | --- | --- |
| 1 | remove 2.000 da lista canônica | `META-01`, `META-03`, `META-05` (6 falhas) |
| 2 | padrão do servidor vira 3.000 | `META-05` |
| 3 | servidor aceita qualquer inteiro | 11 falhas em `META-06/*` |
| 4 | valor inválido cai no padrão | 20 falhas |
| 5 | tira a trava de imutabilidade | `META-10` |
| 6 | início ignora a meta da sala | `META-13`, `META-14`, `META-17` |
| 7 | projeção do lobby omite a meta | `META-15` |
| 8 | entrada/reconexão gravam a meta | `META-10`, `META-11`, `META-12` |
| 9 | cliente manda o padrão em vez do que foi tocado | `MET-04`, `MET-06`, `MET-08`, `MET-09` |
| 10 | padrão do cliente muda em silêncio | `MET-02`, `MET-07` |
| 11 | o toque alterna em vez de definir | `MET-09` |
| 12 | meta desconhecida vira o padrão na tela | `MET-12` |

## 9. O que esta OS não fez

Nada de economia, Billing, carteira, ranking, cortesia VIP, preço, prêmio,
regras do Buraco ou deploy. A meta é ortogonal à topologia: pública, privada e
VIP usam o mesmo motor e a mesma lista — nenhuma meta diferente foi inventada
para VIP.

**Sem deploy.** O servidor em produção continua rodando o commit anterior: até
que `1d7c0be` seja implantado, uma mesa criada pelo app novo com meta 1.500
chega a um servidor que aceita o valor sem validá-lo. O comportamento visível é
o mesmo; o que ainda não vale lá é a recusa.

---

## Anexo — como reproduzir

```bash
cd F:/Projetos/buraco-servidor && npm test
```

```bash
cd app && flutter test test/casca/meta_canonica_lobby_test.dart
```
