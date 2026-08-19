# Chat — transporte real V1

Liga a fundação do Chat Livre Seguro a um transporte entre jogadores sentados,
**sem mover a autoridade da mensagem**. Complementa
`docs/CHAT-LIVRE-SEGURO-V1.md`, que descreve a autoridade.

O caminho completo, ponta a ponta:

```
jogador → WebSocket (chat_enviar)
        → servidor deriva UID da conexão e canal da sala
        → enviarMensagemChatPeloMotor  (claim motorDePartidas)
        → núcleo: bloqueio + sanção + conteúdo + idempotência
        → projeção segura + lista de destinatários
        → servidor entrega chat_mensagem SÓ aos destinatários
        → chat_ack ao remetente
```

## A fronteira

| Decisão | Quem decide |
| --- | --- |
| quem está sentado, em que sala, qual conexão é de quem | **servidor** |
| autoria, `messageId`, instante, identidade pública | **`functions-moderacao`** |
| bloqueio, sanção, validade do texto, superfície | **`functions-moderacao`** |
| destinatários permitidos | **`functions-moderacao`** |
| para quais sockets entregar | **servidor** (usando a lista acima) |

O servidor **não** ganhou `firebase-admin`, não lê `users/{uid}/blocks`, não lê
`playerModeration`, não recalcula destinatários e não cunha `messageId`.
`test/chat_contrato.test.js` (CTR-B) varre o código — não os comentários — e
reprova se qualquer uma dessas coisas aparecer.

## Uma autoridade, dois adaptadores

`executarEnvioDeMensagem` é o núcleo transacional, e existe **uma vez**. Dois
adaptadores o alcançam:

- **`enviarMensagemChatPeloMotor`** — exige o claim `motorDePartidas` (ou
  `admin`). Recebe `autorUid` no payload porque o UID autenticado da chamada é o
  do **motor**, não o do autor; o que torna o campo confiável é o claim **mais** a
  conferência de que aquele UID ocupa o canal. Devolve `destinatarios` — o único
  ponto do sistema que devolve UIDs, e só para o transporte.
- **`enviarMensagemChat`** (ingresso direto do jogador) — **fechado**, com recusa
  nomeada `ingressoDiretoDesativado`.

### Por que o ingresso direto foi fechado

Não por segurança: ele nunca permitiu forjar autoria nem furar bloqueio. Foi por
**coerência de entrega**. Com dois ingressos produtivos, a mesma mensagem teria
consequências diferentes — pelo servidor ela grava **e entrega**; pelo caminho
direto gravaria e **não** seria entregue, porque ninguém estaria escutando por
ele. O resultado seria mensagem autoritativa que nenhum jogador recebe, e um
jogador convencido de que falou.

A porta **continua exportada**, com a decisão documentada no próprio código, em
vez de desaparecer sem rastro para quem for chamá-la amanhã.

## Identidade e ciclo de vida do canal

`canalId = sha256("canal-de-chat|" + código da sala)[0..32]`

- **Opaco**: o código da sala (`BURACO-1234`) é a *chave de entrada* de uma mesa
  privada e tem 4 dígitos. Ele não pode viajar na projeção nem numa denúncia.
- **Estável**: função só do código. Não depende de socket, assento, partida nem
  contador de reconexão — então **uma queda de conexão não cria outro canal**.

A composição vem de `sala.assentos[i]` com `tipo === "humano"` e `jogadorId` —
**estado da sala, não conexão**. Consequências:

| Evento | Efeito no canal |
| --- | --- |
| criar mesa | canal declarado, aberto |
| novo assento humano | composição atualizada |
| assistir (espectador) | **nada** — não entra na composição |
| bot preenche assento | **nada** — bot nunca entra |
| desconexão transitória (pós-início) | **nada** — `sair` não toca `sala.assentos` |
| reconexão | mesmo `canalId`, composição converge |
| partida encerrada (`liquidada`) | canal **fecha** |
| revanche (`iniciarPartida`) | canal **reabre** |

**A revanche não foi decidida por esta OS.** `aberto` deriva de
`!sala.liquidada`, e essa marca é ligada em `liquidar` e desligada em
`iniciarPartida` por `salas.js` — comportamento anterior ao chat. O canal
acompanha o que a sala já dizia.

A sincronização acontece dentro de `broadcastSala`, por onde todo estado estável
passa, e só dispara quando a **impressão** (composição + aceitação) muda. Uma
jogada comum não fala com a autoridade; uma reconexão também não.

## Semântica de entrega

| Camada | Garantia |
| --- | --- |
| autoridade | **exactly-once lógico** — mesma intenção + mesmo contexto + mesmo texto = um `messageId`, um registro |
| transporte | **at-least-once** com o **mesmo `messageId`** |

Se o servidor morrer entre a persistência e a transmissão, um retry reentrega a
**mesma** projeção com o **mesmo** id. É aceitável e é o que permite a UI futura
deduplicar por `messageId`. Um retry **nunca** vira segunda mensagem.

No retry, `destinatarios` sai do documento **gravado**, e não de um recálculo:
reentregar por uma lista nova faria a mesma mensagem alcançar um conjunto
diferente de pessoas.

## Protocolo no fio

| Tipo | Direção | Campos |
| --- | --- | --- |
| `chat_enviar` | cliente → servidor | `intentId`, `texto` |
| `chat_mensagem` | servidor → destinatário | `dados` = projeção segura |
| `chat_ack` | servidor → remetente | `intentId`, `resultado`, `messageId` \| `codigo` |

`resultado` ∈ {`aceita`, `repetida`, `recusada`}.

O envelope **não ganha informação nova**: `dados` é exatamente a projeção que a
autoridade montou. Nada de UID, token, socket ou lista interna atravessa o fio.

### Redação de erros

Os códigos são estáveis e **redigidos**: `indisponivel` cobre bloqueio **e**
sanção de terceiro sem dizer qual dos dois foi — dizer "B te bloqueou" entregaria
a decisão pessoal de B a quem ele bloqueou. `silenciado` é diferente: é sobre o
**próprio** remetente, e ele tem direito de saber.

A tradução é **lista de permissão**: um código novo na autoridade vira
`tente_de_novo`, nunca vaza cru.

## O contrato compartilhado

`contrato/chat-transporte-v1.json` existe **idêntico** nos dois repositórios, e
as duas suítes afirmam o mesmo digest (normalizado em LF, para não divergir entre
Windows e CI). Editar uma cópia e não a outra **reprova as duas**.

Ele congela: nome das Functions, região, campos de pedido e de resposta, campos
da projeção, vocabulário do WebSocket, papéis, superfícies e códigos de recusa.

## Riscos residuais

1. **Credencial do motor não está no Railway.** Sem as variáveis,
   `chatPonte.configurada()` é falso, o canal não é declarado e todo envio é
   recusado — falha fechada, e o jogo roda igual. Ligar em produção é
   configuração, não código.
2. **Sem retomada de assento.** O servidor não tem esse conceito (anterior a esta
   OS): pós-início, quem cai não volta ao assento. O canal mantém a pessoa na
   composição, o que é inofensivo (sem conexão não há entrega), mas significa que
   a composição é mais estável que a presença real.
3. **Sem histórico.** Esta OS entrega chat **ao vivo**. `chatMessages` continua
   armazenamento interno da moderação, não timeline. Quem reconecta não recebe o
   que perdeu.
4. **Saguão continua fora**, com decisão de produto ausente e sem autoridade de
   idade — inalterado pela fundação.
