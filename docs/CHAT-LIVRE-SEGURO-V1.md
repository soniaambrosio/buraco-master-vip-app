# Chat Livre Seguro V1 — fundação canônica

Contrato da OS de Arbitragem e Fundação Canônica do Chat Livre Seguro.
Este documento descreve **o que foi construído**, **onde mora a autoridade** e
**o que continua faltando**. Não descreve tela nenhuma: a UI não faz parte desta
entrega, por decisão da própria OS — primeiro o contrato seguro, depois a ligação.

---

## 1. O que existia antes (Gate Zero)

Levantamento sobre `correcao/ci-composicao-perfil-mesa-ranking-v2-v1`
(`e0cf91791913e1345c9181e1fb2f0a0871d30fe2`):

| Coisa | Estado antes desta OS |
| --- | --- |
| Chat server-side | **Não existia.** Nenhum arquivo com `chat`/`mensagem`/`msg` no nome, em nenhuma branch remota. |
| Chat no servidor Node | **Não existia.** `buraco-servidor` não menciona chat, e não declara nenhuma dependência. |
| `registrarDenuncia` | Existia, com `tipo: "mensagem"` e `messageId` já previstos em `Referencias`. |
| `bloquearJogador` / `desbloquearJogador` | Existiam. Registro unilateral. |
| `consultarContato` | Existia, e já era declarada "porta única das rotas sociais". |
| `avaliarContato` (domínio) | Existia, com efeito **simétrico** já decidido. |
| `playerModeration` | Existia, consolidando quatro campos de sanção. |
| Evidência de mensagem | `cliente_atestada`, com a limitação registrada em código e em `docs/MODERACAO.md`. |
| Gate de `functions-moderacao` | **Não existia.** A codebase não tinha gate nenhum no CI. |

**Não houve STOP.** A condição de parada da OS (encontrar um segundo backend de
chat não composto) não se materializou: não há chat em lugar nenhum, e portanto
não há duas linhagens a compor.

---

## 2. Autoridade escolhida (§14)

### A mensagem nasce no Firebase, em `functions-moderacao`

Não por preferência — **por eliminação**:

- O servidor de partidas (Node/Railway) **não declara uma única dependência** em
  `package.json`, e portanto não alcança o Firestore. Para ele decidir envio,
  seria preciso dar-lhe `firebase-admin` e uma credencial, e ele passaria a ser
  um **segundo leitor** de bloqueio e de `playerModeration`.
- As três coisas que a decisão precisa consultar — `users/{uid}/blocks`,
  `playerModeration/{uid}` e o veredito `avaliarContato` — **já moram** em
  `functions-moderacao`.
- A barreira de idempotência (`executarUmaVez`) e a ponte com o domínio Dart
  também já moram ali.

**Uma gravação, uma decisão.** Não há gravação concorrente entre Railway e
Firestore, que é o que a §14 proíbe.

### Repartição de papéis

Igual à que `functions-moderacao/src/index.ts` já declarava para denúncia e sanção:

```
QUEM DECIDE  -> app/lib/chat/ (domínio Dart), via js_bridge + domain.ts
QUEM EXECUTA -> functions-moderacao/src/index.ts (auth, leitura, transação, escrita)
QUEM AUTORIZA -> firebase/firestore.rules
```

---

## 3. O modelo

### Coleções

| Coleção | Quem escreve | Quem lê | Por quê |
| --- | --- | --- | --- |
| `chatChannels/{canalId}` | `definirCanalDeChat` (claim `motorDePartidas` ou `admin`) | só admin | Carrega UIDs de participantes. É o **contexto estável** da §10. |
| `chatMessages/{messageId}` | `enviarMensagemChat` | só admin | Carrega `autorUid` e `destinatarios`. A entrega ao jogador é a **projeção**. |
| `moderationTasks/{messageId}` | a barreira existente | só admin | Reserva de idempotência, compartilhada com denúncia e sanção. |

Nenhuma das três tem um `allow write` verdadeiro para cliente. Nenhuma tem
leitura de cliente.

### Por que o jogador não lê `chatMessages`

As regras do Firestore liberam ou negam o **documento inteiro** — não há como
permitir ler `conteudo` e esconder `autorUid`. E `destinatarios` é pior que o UID:
ele diria a cada jogador **quem não recebeu**, que é o mesmo que publicar quem
bloqueou quem.

O jogador recebe a **projeção** (`projetarMensagem`), montada por lista de
permissão e passada por `exigirEntregaSegura`. A distribuição aos outros
aparelhos é do transporte — ver §7 abaixo.

### A mensagem gravada

```
chatMessages/{messageId}
  messageId       derivado: sha256(autorUid|intentId), 32 hex
  canalId         do documento do canal
  superficie      do documento do canal
  autorUid        de req.auth.uid            <- NUNCA sai na projeção
  autorPublicId   de playerIdentities/{uid}
  conteudo        texto do jogador, apenas aparado nas pontas
  destinatarios   [uid] já filtrado por bloqueio  <- NUNCA sai na projeção
  enviadaEm       instante do servidor, ISO-8601 com fuso
  esquema         1
```

### A projeção entregue

```
messageId, autorPublicId, superficie, canalId, conteudo, enviadaEm, esquema
```

Sete campos, lista fechada, com teste que reprova se um oitavo aparecer.
Nenhum campo diz `html`, `markdown` ou `formato`: **o conteúdo é texto opaco**, e
a ausência de campo de marcação é contrato — quem renderizar renderiza como texto.

---

## 4. O que o cliente escolhe, e o que não escolhe

**Manda:** `intentId`, `canalId`, `superficie`, `conteudo`.

**Não manda** — e o pedido é **recusado inteiro** se vier (não ignorado em
silêncio, para que a prova negativa seja possível):

- autoria: `uid`, `autorUid`, `senderUid`, `publicId`
- identidade da mensagem: `messageId`, `enviadaEm`, `timestamp`
- transporte: `socketId`, `connectionId`, `geracao`, `tentativa`, `ip`, `sessionId`
- credencial: `token`, `idToken`, `claims`, `admin`
- estado administrativo: `playerModeration`, `chatSilenciadoAte`, `suspensoAte`, …

A lista canônica é `kCamposProibidosNoEnvio` em `app/lib/chat/mensagem.dart`.

---

## 5. Conteúdo (§6)

Texto livre é texto livre: **não há lista de frases prontas e não há filtro moral
de palavras** — a OS proíbe as duas coisas nesta entrega.

Limites **operacionais**:

| Regra | Valor / comportamento |
| --- | --- |
| Tipo | `String` obrigatório. Map, List e número → `conteudoNaoTexto`. |
| Vazio | Aparado nas pontas; nada sobrando → `conteudoVazio`. |
| Tamanho | 300 **pontos de código** (`runes.length` no Dart == `[...s].length` no JS). |
| Controle | C0, DEL, C1, U+2028, U+2029 → **recusa**, nunca remoção silenciosa. |
| Normalização | Só `trim`. Não colapsa espaço, não corta, não corrige. |

A medida em pontos de código (e não unidades UTF-16) é o que faz cliente e
servidor recusarem **exatamente** as mesmas mensagens: 300 emojis fora do BMP
contam 600 em `String.length`, e a divergência viraria recusa inexplicável.

Recusar caractere de controle em vez de removê-lo tem razão prática: quem
removesse entregaria ao jogador um texto diferente do que ele escreveu, e faria a
**evidência de uma denúncia divergir do que foi digitado**.

---

## 6. Bloqueio (§7) — consumido, nunca redecidido

A pergunta "este par pode se falar?" tem **uma** resposta no projeto:
`avaliarContato` em `app/lib/moderacao/relacao_social.dart`, inclusive a decisão
de que o efeito é **simétrico** mesmo com registro unilateral. O chat chama
aquela função **por par** e obedece.

### As duas perguntas são diferentes

1. **A mensagem existe?** Vale para o autor, uma vez: conteúdo, superfície,
   assento, intenção, sanção.
2. **Quem recebe?** Vale por par.

Numa mesa de quatro, quem me bloqueou não me lê e os outros dois leem. Recusar a
mensagem inteira porque **um** jogador me bloqueou entregaria a qualquer um o
poder de me calar na mesa; entregar a mensagem a quem me bloqueou tornaria o
bloqueio decorativo.

**Exceção:** se o filtro zerar a lista (mesa de dois com bloqueio), a mensagem é
**recusada**. Aceitar e não entregar a ninguém deixaria o jogador falando com uma
parede acreditando que foi lido.

---

## 7. Sanções (§8)

| `TipoSancao` | Campo consolidado | Impede chat? |
| --- | --- | --- |
| `advertencia` | — | não (sem efeito técnico, por definição) |
| `muteTemporario` | `chatSilenciadoAte` | **sim** |
| `restricaoSocial` | `socialRestritoAte` | **sim** |
| `suspensaoTemporaria` | `suspensoAte` | **sim** |
| `suspensaoPermanente` | `suspensaoPermanente` | **sim** |

Sanção **não é por par**: ela cala o autor para a mesa inteira.

### A suspensão temporária, e por que isso não é política inventada

`app/lib/moderacao/sancao.dart` documenta `suspensaoTemporaria` como *"impede
entrar na aplicação por um prazo"*. Quem não entra na aplicação não fala na mesa —
negar o chat é **leitura literal do efeito já escrito**, não regra nova.

### PENDÊNCIA REGISTRADA: `suspensoAte` não é consultado pelas rotas sociais

`consultarContato` (`functions-moderacao/src/index.ts`) e
`functions-social/src/repositorio.ts` consultam `suspensaoPermanente` mas **não**
consultam `suspensoAte`. Ou seja: hoje, uma suspensão **temporária** não impede
convite nem pedido de amizade.

Esta OS **não mexeu** naquelas rotas: alterar o veredito de `avaliarContato`
mudaria o comportamento de amizade e convite, que estão fora do seu escopo. O
chat nasce fechado (consulta os dois campos); a correção das rotas sociais é
decisão a tomar à parte.

---

## 8. Superfícies (§11)

| Superfície da OS | Valor no domínio | Política | Evidência |
| --- | --- | --- | --- |
| mesa | `mesaDePartida` | **LIBERADO** | `ChatMesa.completo` nas três variantes de `TipoMesa` em `configurar_mesa_screen.dart`; coluna de chat em `mesa.dart`. |
| sala privada | `mesaDePartida` | **LIBERADO** | `TipoMesa.privada` também traz `ChatMesa.completo`. É a mesma superfície técnica — uma partida com gente sentada — variando só o `TipoDePartida`. |
| VIP / Ranqueada | `mesaDePartida` | **LIBERADO** | `TipoMesa.vip` traz `ChatMesa.completo`. Idem. |
| espectador | `espectadorDeMesa` | **NÃO LIBERADO** | Nenhuma decisão de produto diz que quem assiste conversa com quem joga, e a §11 proíbe concluir isso automaticamente. |
| lobby público | `saguaoPublico` | **DECISÃO DE PRODUTO AUSENTE** | `saguao_screen.dart` anuncia *"Converse por falas prontas · sem digitação"*; e `chatPublicoSoMaiores` é preferência gravada em `SharedPreferences` pelo próprio aparelho — **não existe autoridade de idade no backend**. |

O espectador é recusado **nas duas direções**: não fala e **não recebe**. Receber
é metade de conversar, e liberar só a escuta entregaria a mesa a uma plateia que
os jogadores não escolheram.

`naoLiberado` e `decisaoAusente` são valores **distintos** de propósito: o
espectador é recusa deliberada, o saguão é pendência de produto. Colapsar os dois
esconderia qual dos dois precisa de decisão.

O *chat premium por falas prontas* do VIP é outra funcionalidade (frases
predefinidas), não construída aqui e não afetada por esta entrega.

---

## 9. Idempotência (§9)

`messageId = sha256(chaveComposta([autorUid, intentId]))[0..32]`

**Determinista** → retry, toque duplo e reconexão convergem no mesmo documento.
**Opaco** → não carrega o UID, ao contrário de `chaveDeDenuncia`
(`${uid}|${reportIntentId}`). A diferença tem razão concreta: o id de uma denúncia
só aparece em coleção restrita a admin, enquanto o `messageId` viaja para os
outros jogadores e é referenciado numa denúncia.

A reserva usa a barreira existente, com o `messageId` como chave:

```
executarUmaVez(messageId, {
  tarefa: "enviarMensagemChat",
  ator: autorUid,
  alvo: canalId,
  impressao: sha256([superficie, canalId, conteudo]),
}, tx => tx.create(chatMessages/{messageId}, documento))
```

A `impressao` é o que a chave **não** carrega. Sem ela, reaproveitar o mesmo
`intentId` com outro texto encontraria a chave reservada e a autoridade
responderia sucesso sem gravar a mensagem nova — a mensagem pedida desapareceria
com uma confirmação na mão de quem pediu. É o mesmo defeito que
`conferirConformidade` já corrigiu para denúncia e sanção.

**Na repetição, a mensagem gravada é relida e projetada.** Devolver o documento
montado na hora daria um `enviadaEm` diferente do gravado, e o cliente veria a
mesma mensagem com dois horários.

---

## 10. Contexto (§10)

**Estável** (identifica onde a mensagem pertence): `canalId`, `superficie`,
`participantes`, autor autenticado. Tudo em `chatChannels/{canalId}`, escrito pelo
motor.

**Transitório** (nunca entra): conexão, socket id, geração de transporte, instante
de retry. Uma reconexão legítima **não muda nenhum campo** do canal e **não muda**
o `messageId` — e campo de transporte no payload é recusado, então não há por onde
ele influenciar a derivação.

---

## 11. Denúncia de mensagem (§12)

O comentário antigo em `registrarDenuncia` dizia o que fazer quando o chat
virasse server-side. É exatamente o que foi feito, e nada mais:

| Situação | `origem` | Conteúdo |
| --- | --- | --- |
| `chatMessages/{messageId}` existe | `servidor` | lido do documento; a cópia do cliente é **descartada** |
| não existe, cliente atestou | `cliente_atestada` | o que o aparelho afirmou |
| não existe, sem atestado | `referencia` | só a referência |

O **autor** da evidência vem do **documento**, não de `denunciadoUid`: sem isso,
denunciar a mensagem de A dizendo que ela é de B gravaria uma evidência que acusa
B do que A escreveu.

`cliente_atestada` **não foi apagada**, e a sobrevivência dela é **delimitada**:
vale para as superfícies sem mensagem autoritativa (o saguão, e a mesa enquanto o
transporte não estiver ligado) e para o histórico já gravado, que não se migra.

---

## 12. Fronteira e o que NÃO foi ligado

### BLOCKED — o transporte, e o produtor do canal

`definirCanalDeChat` existe, exige o claim `motorDePartidas` e é provada; **mas
ninguém a chama**. O servidor de partidas não alcança o Firebase.

Consequências, todas com falha **fechada**:

- Sem canal declarado, `enviarMensagemChat` recusa **toda** mensagem
  (`canalDesconhecido`). Não há caminho em que a ausência do produtor abra o chat.
- A mensagem é gravada e projetada, mas **não é distribuída** aos outros
  aparelhos. `destinatarios` fica gravado justamente para que a entrega, quando
  existir, não precise redecidir bloqueio.

É o mesmo padrão que o repositório já usa noutras OSs: autoridade entregue,
produtor pendente.

### Para ligar, é preciso decidir

1. **Quem chama `definirCanalDeChat`.** O servidor Node precisaria de
   `firebase-admin` + credencial (a credencial renovável do motor já existe em
   `buraco-servidor`), ou o cliente precisaria de um caminho autorizado que não
   deixe o remetente declarar quem está sentado.
2. **Como a mensagem chega aos outros aparelhos.** Ou o servidor lê
   `chatMessages` e faz o fan-out, ou o cliente escuta por um caminho novo — e
   nesse caso a projeção precisa virar documento próprio, porque o documento
   gravado não pode ser lido pelo jogador.
3. **O saguão.** Precisa de decisão de produto e de uma autoridade de idade, que
   hoje não existe.

---

## 13. Provas

| Suíte | Gate | Prova |
| --- | --- | --- |
| `app/test/chat/chat_test.dart` | `chatdom` | A DECISÃO: conteúdo, superfície, assento, idempotência derivada, filtro por par, trava de projeção. |
| `functions-moderacao/test/chat.test.js` | `moderacaofn` | A PROJEÇÃO e a EVIDÊNCIA, puras: lista de permissão, trava em profundidade, três desfechos da §12. |
| `firebase/testes/chat.test.js` | `regras` | A AUTORIZAÇÃO: ninguém grava mensagem, ninguém lê o documento, e o bloco novo não afrouxou o vizinho. |
| `functions-moderacao/test/integracao.chat.emulador.test.js` | `chatemu` | O LIMITE REAL: anônimo recusado, retry e concorrência que não duplicam, bloqueio lido do Firestore nas duas direções, sanção, denúncia com evidência server-side. |

Três gates novos na fonte única (`scripts/ci/gates_os_integracao.txt`):
`chatdom`, `moderacaofn`, `chatemu`. A suíte de regras entrou em `test:integrado`,
que o gate `regras` já executa.

`moderacaofn` fecha uma lacuna **anterior** ao chat: `functions-moderacao` não
tinha gate nenhum. A codebase que hospeda denúncia, bloqueio, sanção e
`consultarContato` podia deixar de compilar sem o CI dizer uma palavra.
