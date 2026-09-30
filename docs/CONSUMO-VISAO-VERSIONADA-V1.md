# Consumo seguro da visão autoritativa versionada — Flutter V1

O aplicativo passa a **ordenar e deduplicar** o que chega em `{tipo:'estado'}`
antes que aquilo altere o estado canônico, a mesa ou a tela.

- Branch: `claude/consumo-visao-versionada-flutter-v1`
- Base: `claude/ligacao-motor-canonico-casca-v2-p0` @ `4b3c460`
- Contrato do servidor (só referência, não editado):
  `buraco-servidor`, `claude/versionamento-visao-autoritativa-v1` @ `7e7572b`
- Sem deploy, sem regra do Buraco tocada, sem interface reformulada.

---

## 1. O que faltava

O servidor já carimbava cada emissão. O cliente ignorava o carimbo: no
`case 'estado'` do `OnlineService`, toda mensagem substituía a projeção do
assento. Num socket que entrega em ordem isso quase sempre acerta — e o
"quase" é reenvio, retransmissão pós-reconexão e corrida entre emissões. Todas
chegam pelo socket certo, com a geração certa, e desfaziam na tela o que já
tinha acontecido.

Havia ainda uma heurística de ordem na camada de apresentação
(`EstadoMesaOnline.substitui`) lendo `visao['versaoEstado']` — **dentro** da
visão. O contrato põe o carimbo como *irmão* de `visao`, nunca filho, então
aquele campo era `null` em toda execução real e o método respondia "pode
substituir" para tudo: uma autoridade que nunca existiu, com aparência de estar
funcionando. Foi removida.

## 2. Ponto único de validação

`OnlineService._aoReceber`, `case 'estado'` — em
[`app/lib/services/online_service.dart`](../app/lib/services/online_service.dart).

É o único lugar do aplicativo onde um envelope autoritativo entra, e o único
escritor de `OnlineService.visao` (o outro é o descarte, que a zera). A decisão
de ordem é tomada **antes** de qualquer mutação, e a política mora em
[`app/lib/services/ordem_da_visao.dart`](../app/lib/services/ordem_da_visao.dart).

```
socket → guarda de geração do transporte → case 'estado'
                                              ↓
                                    OrdemDaVisao.avaliar(envelope)
                                              ↓
                        ┌─────────────────────┴──────────────────┐
                    aceitar/duplicada                        descarte
                        ↓                                        ↓
          aplica snapshot (só em "aceitar")              return — nada
                        ↓
          OrdemDaVisao.talvezEncerramento(...)
                        ↓
                 aoEncerrar?.call(...)
```

O carimbo é lido do **envelope** (`msg`), não da visão. Um `versaoEstado` que
apareça dentro de `visao` não é o carimbo e não tem autoridade de ordem.

## 3. Conduta por entrada

| Entrada | Conduta |
|---|---|
| primeira visão carimbada da projeção ativa | aceita, qualquer que seja o número |
| versão maior que a última aceita | aceita |
| versão menor | `atrasada` — descartada inteira, marcador intocado |
| mesma versão + mesmo `eventoId` | `duplicada` — snapshot não reaplicado |
| mesma versão + `eventoId` diferente | `inconsistente` — não substitui o estado |
| `versaoEstado`/`eventoId` malformados, ou um sem o outro | `ilegivel` — descarte, marcador intocado |
| `(0, null)` | `semEstadoAutoritativo` — o servidor disse que não há estado |
| sem carimbo, antes de qualquer carimbada | aceita (modo legado, §5) |
| sem carimbo, depois de uma carimbada | `legadaTardia` — recusada |
| mensagem de conexão/geração anterior | descartada antes de tudo, pela guarda de geração que já existia |

Nenhuma conduta de descarte chama `notifyListeners`, redesenha, limpa o erro na
tela ou toca o marcador. O descarte é inteiro: uma mensagem atrasada que zerasse
a explicação da recusa já seria mutação parcial.

## 4. Escopo do marcador — dois livros, duas vidas

Esta é a decisão central da entrega.

| Registro | Vive com | Reiniciado por |
|---|---|---|
| **marcador de ordem** (versão + `eventoId` aceitos) | a **projeção** | `_limparProjecao` — reconexão, saída, sessão nova |
| **livro dos efeitos terminais** (`eventoId`s despachados) | a **mesa** | `_encerrarMesa` — sair da mesa, sessão nova |

Nada é persistido em disco. Os dois vivem em memória, com a conexão.

A assimetria é o miolo, e trocá-la produz dois defeitos opostos:

- **marcador vivo demais** — o servidor *não* cria versão nova para quem
  reconecta (reconectar não muta a sala), então ele reenvia a versão vigente. Um
  marcador que sobrevivesse à queda leria esse reenvio como duplicata e deixaria
  a mesa **em branco** até a jogada seguinte;
- **livro curto demais** — o mesmo reenvio traz o encerramento de novo. Um livro
  zerado na reconexão dispararia diálogo, navegação e som **pela segunda vez**
  para quem só caiu e voltou.

Entrar em outra sala reinicia os dois: a sala nova tem contador próprio, e um
`versaoEstado` numericamente **menor** que o da anterior é o caso normal.

## 5. Envelopes legados

O servidor de `7e7572b` **não está implantado**. O que está em produção não
carimba. Exigir os campos agora deixaria o aplicativo publicado sem jogo online
nenhum, então a tolerância é obrigatória — e é estreita:

- aceita-se envelope sem carimbo **apenas enquanto a projeção ativa nunca
  aceitou um carimbado**;
- depois da primeira visão carimbada, uma sem carimbo é recusada
  (`legadaTardia`). Um servidor que carimba não deixa de carimbar no meio da
  partida: isso é anomalia, não compatibilidade;
- **nada é fabricado**. Sem número no fio, o marcador não avança, e a decisão
  devolve `versaoEstado`/`eventoId` nulos;
- a tolerância volta a valer quando a projeção reinicia — reiniciar é dizer "o
  retrato que eu tinha não vale mais", e a geração seguinte renegocia do zero.

No modo legado o efeito terminal também é deduplicado, por uma marca booleana
por mesa em vez de `eventoId`. É deduplicação **mais fraca**, e está declarada
como tal no código: sem identificador no fio, é a única coisa verdadeira que se
sabe.

## 6. Snapshot e efeito terminal são coisas separadas

O envelope terminal **não é descartado inteiro** só porque sua visão já foi
aplicada. As duas idempotências são diferentes:

- **aplicação do snapshot** — pode se repetir à vontade; reconectar *exige* que
  se repita, senão a mesa não volta a ser desenhada;
- **processamento do evento terminal** — não pode se repetir nunca. Diálogo de
  resultado, navegação, som, animação, registro local, tentativa de recompensa.

`OrdemDaVisao.talvezEncerramento` **não consulta o marcador de ordem**, e a
independência é o requisito: perguntar a ele "já vi esta versão?" responderia
SIM sempre que `avaliar` tivesse acabado de aceitá-la — e o efeito seria engolido
pela própria aplicação do retrato que o trouxe. Ele roda também na `duplicada`,
porque uma duplicata não muda o estado mas continua sendo o servidor declarando
o fim.

A chave de deduplicação é o `eventoId`, tratado como **opaco**: não se lê nada de
dentro dele, e ele não é identidade estável da partida — é identidade da
*emissão*.

### O ponto de saída

`OnlineService.aoEncerrar` — um slot, chamado uma vez por encerramento
autoritativo. Um slot e não uma lista de ouvintes: vários seriam vários donos de
"a partida acabou", cada um com sua noção de já ter tratado.

**Hoje ninguém assina.** Ligar diálogo ou navegação ali é trabalho de interface,
que esta OS proíbe. O que se entrega é o ponto de saída com a garantia de
disparo único.

## 7. Colisão nominal — `versaoEstado` ≠ `versaoEstadoFinal`

| Nome | O que é | Onde vive |
|---|---|---|
| `versaoEstado` | versão monotônica da visão autoritativa, da **sala** | irmão de `visao`, no evento `estado` |
| `versaoEstadoFinal` | `jogo.rodada` — conta **rodadas** | envelope de encerramento, e já existia antes deste contrato |

Não são o mesmo número e não podem ser comparados, mapeados um sobre o outro,
nem renomeados. Ordenar snapshots por número de rodada faria a mesa descartar
toda emissão que não virasse a rodada — quase todas.

No aplicativo, `versaoEstadoFinal` é campo de
`rastreabilidade/registro_partida.dart` e **não foi tocado**. Nada em
`ordem_da_visao.dart` o lê. Dois casos fixam a distinção
(`versaoEstadoFinal não participa da ordenação`).

## 8. Matriz de testes

| Arquivo | Casos | O que prova |
|---|---|---|
| `app/test/casca/ordem_da_visao_test.dart` | 34 (novos) | a política: leitura do carimbo, ordem, modo legado, escopo dos dois livros, encerramento, colisão nominal |
| `app/test/casca/mesa_online_test.dart` | +13 (novos) | que a política está no **caminho**: transporte de produção, socket falso, tela montada |
| `app/test/casca/adaptador_visao_online_test.dart` | grupo `ordem` (5) trocado por `a ordem não mora nesta camada` (2) | que a apresentação não voltou a ter opinião sobre ordem |

Cobertura da matriz mínima da OS: primeira visão · sequência crescente ·
10→12→11 · duplicata exata · mesma versão com outro `eventoId` · mensagem
malformada · ausência de versão no modo legado · visão sem versão depois de uma
versionada · reconexão e reenvio da visão vigente · callback tardio da conexão
anterior · logout/login com nova geração · entrada em outra sala · nova geração
com versão numericamente menor · snapshot e encerramento compartilhando
metadados · encerramento retransmitido · evento terminal ainda executado quando
o snapshot correspondente já foi aplicado · `versaoEstadoFinal` fora da
ordenação · mensagem descartada sem `notifyListeners`, sem renderização e sem
mutação parcial.

### Prova de que a matriz morde

Três defeitos injetados de propósito, e revertidos:

| Defeito injetado | Testes que caíram |
|---|---|
| ausência do bloqueio de visão atrasada (`versão menor` passa a ser aceita) | **5** |
| marcador reiniciado a cada envelope, dentro da mesma geração | **4** |
| deduplicação que engole o evento terminal (`talvezEncerramento` recusa a duplicata) | **1** |

## 9. Riscos residuais

1. **O terceiro defeito derruba um caso só, e é de unidade.** Hoje o
   `OnlineService` chama `avaliar` e `talvezEncerramento` na mesma sequência de
   instruções, sem nada que possa falhar entre as duas — então o estado
   "snapshot aplicado, efeito ainda não despachado" **não é alcançável** pelo
   caminho de produção atual. A garantia existe no objeto de política, e vale
   para o dia em que alguém puser um `return` ou um lote entre os dois passos.
   Foi assim que a OS pediu, e é onde o caso é honesto.
2. **A tolerância legada é por projeção, não por mesa.** Uma reconexão que caia
   num servidor sem carimbo, depois de a partida já ter recebido visões
   carimbadas, volta a ser aceita. Preferiu-se isso a congelar a mesa: o app
   publicado fala hoje com um servidor que não carimba, e o rollback do servidor
   é um cenário real.
3. **Nenhum consumidor assina `aoEncerrar`.** O disparo único está provado por
   teste, mas nada acontece na tela quando ele sai — é a fatia seguinte.
4. **O evento `fim` do servidor continua ignorado.** Ele não carrega carimbo
   (`{tipo:'fim', resumo, placar}`), e o cliente nunca o tratou. O encerramento
   que este arquivo despacha vem da visão (`encerrada: true`), que é carimbada.
   Se um dia o `fim` passar a carregar efeito próprio, ele precisará do carimbo
   para ser deduplicado.
5. **A tela do lobby ainda lê `srv.visao` cru** para desenhar o lobby
   (`v['assentos']`, `v['codigo']`). Isso não é ordem — o mapa que ela lê já
   passou pelo portão —, mas é leitura crua fora do adaptador, e continua como
   estava.
