# Comunicação Controlada, Chat Privado, Denúncia e Bloqueio — V1

Autoridade canônica de toda comunicação social do Buraco Master VIP.

> **A frase que governa tudo o que está aqui:**
>
> **SOMENTE A MESA PRIVADA ADMITE TEXTO DIGITADO LIVREMENTE.**
>
> E a segunda, que costuma ser esquecida quando a primeira é implementada:
> **VIP não significa chat livre.** O benefício VIP amplia o CATÁLOGO — falas
> premium, emojis, reações. Ele não abre o teclado.

---

## 1. A matriz canônica (§2 da OS)

| Ambiente | `wire` | Texto livre | Catálogo |
| --- | --- | --- | --- |
| Saguão Público | `saguao_publico` | ❌ | ✅ |
| Salão VIP | `salao_vip` | ❌ | ✅ (inclui premium) |
| Mesa Pública | `mesa_publica` | ❌ | ✅ (se o modo não for `desligado`) |
| Mesa VIP | `mesa_vip` | ❌ | ✅ (se o modo não for `desligado`) |
| Mesa Privada | `mesa_privada` | ✅ **só com `modo = completo`** | ✅ |
| Treino | `treino` | ❌ | ❌ |

A tabela mora em **um lugar só**: `permissaoDe()` em
`app/lib/comunicacao/ambiente.dart`. O teste `MAT-01`
(`app/test/comunicacao/comunicacao_test.dart`) varre os seis ambientes × três
modos e exige que a lista de pares com texto livre seja exatamente
`["mesa_privada/completo"]`.

### As duas travas, e por que são duas

1. **Configurar.** `chatsPermitidos()` em `functions-mesas/src/politica.ts`
   recusa `completo` fora da Mesa Privada. Uma mesa pública **não pode ser
   criada** com chat completo (`CHAT_INVALIDO`).
2. **Falar.** `permissaoDe()` recusa texto livre fora da Mesa Privada
   **mesmo que o documento do canal já traga `modo: completo`** — legado,
   defeito de escrita ou adulteração.

Uma trava só não bastaria: sem a primeira, a recusa apareceria no meio da
partida, para o jogador que não configurou nada; sem a segunda, um documento
errado abriria o teclado.

---

## 2. Quem decide o quê

```
CLIENTE            pede: intentId + (texto | itemId)
   │
SERVIDOR           acrescenta: autor (da conexão autenticada), canal (da sala),
DE PARTIDAS        e as DUAS DIMENSÕES da mesa (topologia × categoria)
   │
functions-moderacao   lê: canal, identidade pública, sanção, bloqueio, silêncio,
(EXECUTOR)                ritmo, direito VIP, sala privada, assentos admitidos
   │
app/lib/comunicacao   DECIDE: existe? de quem? para quem? no idioma de quem lê?
(DOMÍNIO, Dart)
```

Nenhum `if` de política vive no TypeScript. Se aparecer um, está no lugar errado
— é a mesma repartição que a OS de Moderação e a do Chat Livre já declaravam.

### Autoridades REUTILIZADAS (§4.4)

| Pergunta | Quem responde | Onde |
| --- | --- | --- |
| Que tipo de mesa é esta? | Autoridade dos tipos | `functions-mesas/src/tipos.ts` |
| Que chat esta mesa admite? | Autoridade dos tipos | `functions-mesas/src/politica.ts` |
| Este jogador tem VIP agora? | Domínio de elegibilidade | `app/lib/elegibilidade/entitlement.dart` (`EntitlementVip.vigenteEm`) |
| Estes dois podem se falar? | Domínio de moderação | `app/lib/moderacao/relacao_social.dart` (`avaliarContato`) |
| Este texto é válido? | Domínio do chat | `app/lib/chat/porta.dart` (`avaliarEnvio`) |
| Qual o `publicId` deste jogador? | Identidade pública | `playerIdentities` / `publicIdIndex` (functions-social escreve) |
| Que sanção pesa sobre ele? | Moderação | `playerModeration` |

**Nada disso foi recriado.** `avaliarComunicacao` **envolve** `avaliarEnvio` em
vez de substituí-la, e a pergunta que ela acrescenta é a que faltava: *texto
pode existir aqui?*

---

## 3. O contrato do evento (§5)

Cada comunicação tem **tipo explícito**. Não há um campo `texto` que sirva para
tudo — esse é justamente o defeito que a §5 proíbe, porque com ele o sistema
perde a localização, a moderação e a autenticidade de uma vez.

| Tipo | `wire` | Carrega | Quem pode pedir |
| --- | --- | --- | --- |
| Fala catalogada | `fala_catalogada` | `itemId` | jogador |
| Reação | `reacao_catalogada` | `itemId` | jogador |
| Emoji | `emoji_catalogado` | `itemId` | jogador |
| Texto privado | `texto_privado` | `conteudo` | jogador (só Mesa Privada) |
| Evento de sistema | `evento_de_sistema` | `eventoId` | **só a autoridade** |

### O documento gravado — `chatMessages/{messageId}`

UMA coleção para os cinco tipos. Não duas, e o motivo é operacional: a denúncia
precisa alcançar qualquer um deles pelo mesmo caminho, a idempotência é por
`messageId`, e a retenção é uma política só.

| Campo | Origem |
| --- | --- |
| `messageId` | derivado de `sha256(autor \| intenção)` — o cliente **não** escolhe |
| `autorUid`, `autorPublicId` | sessão autenticada / autoridade de identidade |
| `ambiente`, `superficie` | canal, resolvido pela autoridade |
| `tipo`, `itemId`, `chaveDeLocalizacao`, `fallbackOficial` | catálogo |
| `conteudo` | só em `texto_privado` |
| `destinatarios`, `silenciados` | decisão da autoridade — **nunca** saem na projeção |
| `enviadaEm`, `expiraEm` | relógio do servidor |
| `versaoDoCatalogo`, `versaoDoContrato` | carimbo |

### A projeção — o que o jogador recebe

Lista de **permissão** (`projetarComunicacao`), não remoção de campos: um campo
novo no documento não vaza por esquecimento. `autorUid`, `destinatarios`,
`silenciados` e `expiraEm` não existem na entrega.

`conteudo` só aparece em `texto_privado`. **Numa fala catalogada a frase pronta
não viaja** — se viajasse, o cliente renderizaria o texto que chegou em vez da
chave, e o jogador estrangeiro receberia português.

---

## 4. O catálogo (§6.2, §6.3)

Mora em código: `app/lib/comunicacao/catalogo.dart`, versão
`kVersaoDoCatalogo = 1`. Cada item declara id, tipo, categoria, ativo,
ambientes, versão mínima, direito exigido, **chave de localização**, **fallback
oficial**, recurso visual, cooldown e data de desativação.

O evento transporta **significado**, não frase:

```
itemId: convite_dupla_01
chaveDeLocalizacao: comunicacao.fala.convite_dupla_01
fallbackOficial: "Vamos fazer dupla?"
```

Cada cliente renderiza no idioma dele. Sem tradução, usa o **fallback oficial**
— que vem da autoridade, nunca do remetente.

**Texto exibível no lugar do id é recusado** (`textoNoLugarDoItem`). Um campo de
texto aceito "só para o fallback" seria texto livre com outro nome.

---

## 5. Anti-spam (§6.5)

Tudo no servidor. `app/lib/comunicacao/limites.dart`, configuração única em
`ConfiguracaoDeRitmo.padrao`:

| Limite | Padrão |
| --- | --- |
| Teto por janela | 20 / minuto |
| Rajada | 5 / 5 s |
| Repetição do mesmo item | 3 / 2 min |
| Cooldown por categoria | 2 s (emoji) … 45 s (chamar para jogo) |
| Cooldown de texto privado | 700 ms |
| Freio por abuso | 5 recusas seguidas → 2 min |

O estado vive em `chatRitmo/{uid}` — coleção própria, negada a todo cliente
(leitura inclusive: liberar a leitura entregaria o instante exato em que o freio
solta). **O estado é gravado nos dois desfechos**: sem isso, uma rajada de
pedidos recusados não contaria como abuso.

O que o jogador precisa saber volta em `liberaEmMs`, na resposta da chamada —
informação sobre o próprio pedido dele.

**O que acontece com o estado quando o jogador exclui a conta (OS 48).** O
documento é `APAGADO`, junto com as mensagens dele, na etapa `moderacaoDoJogador`
da autoridade de exclusão (`functions-conta`). A decisão e a justificativa vivem
em `functions-conta/src/inventario.ts`, item `moderacao.ritmoDeChat`, e estão
escritas por extenso na §4.1 de
[`EXCLUSAO-DE-CONTA-E-DADOS.md`](EXCLUSAO-DE-CONTA-E-DADOS.md).

A leitura contra a qual essa decisão precisa se defender é *"apagar o freio é
apagar punição"*, e ela é errada pela distinção que esta seção já faz: o
`bloqueadoAteMs` é um freio automático de dois minutos, sem responsável e sem
motivo. A ficha disciplinar é `playerModeration`, `sanctions`, `reports` e
`moderationAudit` — os quatro são **retidos** pela exclusão de conta, e nenhum
deles depende deste documento: a evidência de uma denúncia é *copiada* para o
registro dela, exatamente para sobreviver à expiração (§7.5).

**Esta seção não mudou por causa daquela OS.** Nenhum limite, nenhum cooldown,
nenhum campo e nenhuma rota foram alterados: o que passou a existir foi um
destino declarado para o documento no fluxo de exclusão de conta.

---

## 6. Mesa Privada: como o texto livre é conquistado (§7)

Para uma linha de texto existir, TUDO isto tem de ser verdade:

1. o canal foi declarado com topologia **`privada` DECLARADA** (não a resolvida
   — a resolvida vale `privada` por padrão e abriria o teclado em toda
   instância não configurada);
2. existe `salasPrivadas/{codigo}` — e ela só é criada por
   `registrarMesaPrivada`, que exige **assinatura ativa** do anfitrião;
3. a sala não está encerrada;
4. `modoDeChat` gravado na sala é `completo` — escolha do **anfitrião**,
   validada pela autoridade dos tipos. **Ausente é `desligado`**, nunca
   `completo`;
5. quem fala tem `assentosAdmitidos/{codigo}__{uid}` — a âncora que o gate VIP
   grava. Quem não tem é rebaixado a `fora_do_canal`: não fala e não recebe;
6. quem fala tem identidade pública;
7. não há sanção, bloqueio total nem ritmo excedido.

**O código da sala é usado e descartado.** Ele localiza a sala e o assento, e
**não** é gravado no canal: é a chave de entrada da Mesa Privada, e um canal que
o carregasse o entregaria a quem lesse o documento — inclusive dentro de uma
denúncia. Ele também não entra em log nenhum.

O passe quinzenal de cortesia **não** abre a Mesa Privada: quem decide isso é
`aceitaPasseDeCortesia()` na autoridade dos tipos, e ela responde apenas
`vipRanqueada`.

---

## 7. Silenciar ≠ bloquear (§9.1, §9.2)

| | Silenciar | Bloquear |
| --- | --- | --- |
| Quem escreve | o próprio jogador (`users/{uid}/mutes/{alvo}`) | a Function (`users/{uid}/blocks/{alvo}`) |
| Efeito | some da entrega **para quem silenciou** | comunicação entre o par é suprimida |
| A mensagem existe? | **sim**, é gravada e confirmada | se a lista de destino zera, é **recusada** |
| Notifica o alvo? | não | não |
| É sanção? | não | não |

A diferença aparece no dado: o veredito separa `destinatarios` de `silenciados`.
Se os silenciadores apenas sumissem da lista de destinatários, a mensagem que
ninguém quer ouvir seria indistinguível de mensagem barrada por bloqueio — e o
autor descobriria que foi silenciado, que é o que a §9.1 proíbe.

**Evento de sistema atravessa os dois.** Quem bloqueou alguém continua
precisando saber que a sala foi encerrada (§9.2: "preserva comandos necessários
do sistema e do jogo").

---

## 8. Denúncia (§9.3 a §9.6)

`registrarDenuncia` resolve o alvo em **três caminhos**, nesta ordem:

1. **pelo evento** — há `messageId` e o documento existe → o alvo é o **autor
   gravado**. Vence qualquer coisa que o pedido tenha dito. Sem isso, denunciar
   a mensagem de A afirmando que é de B geraria um registro acusando B;
2. **pelo `publicId`** — resolvido no backend por `publicIdIndex`, que é negado
   a todo cliente. É o que permite existir um botão "Denunciar" nas telas que
   **não conhecem UID** (Ranking, Hall, Perfil, mesa);
3. **pelo UID** — para chamadores internos que já o têm.

Alvo não resolvido responde `alvoNaoResolvido`, sem dizer se o `publicId`
existe — diferenciar transformaria a porta num verificador de contas válidas.

### Evidência mínima, por espécie (§9.5)

| Denunciado | Preserva |
| --- | --- |
| Texto | mensagem exata, autor (do documento), horário do servidor, sala, `messageId` |
| Item catalogado | `itemId`, **versão do catálogo**, **quantidade e padrão de repetição**, ambiente, canal |

A diferença tem razão: uma fala do catálogo nunca é ofensiva por si — ela foi
aprovada. O que ofende é a **repetição**. A janela examinada é de **uma hora
antes** do evento denunciado, e não a conversa inteira: varrer tudo seria a
retenção indiscriminada que a §9.5 proíbe.

O rate limit (20 denúncias/hora), a idempotência por `${uid}|${reportIntentId}`
e os estados (`recebida` → `emAnalise` → `procedente`/`improcedente`/
`arquivada`, projetados para o denunciante como `emAnalise`/`concluida`) são os
que a OS de Moderação já entregou. **Nada disso foi recriado.**

---

## 9. Eventos de sistema (§8)

Nascem **só** por `emitirEventoDeSistema`, que exige o claim `motorDePartidas`
ou `admin`. A garantia não é uma checagem de texto: **é a inexistência de
caminho.** O pedido do jogador não tem campo `eventoId`, e o domínio recusa
`tipo: evento_de_sistema` vindo dele (`eventoDeSistemaSemAutoridade`).

O evento **não tem autor**: `autorUid` e `autorPublicId` são `null` no documento
e ausentes na projeção. Essa ausência é o contrato — um evento com autor seria
indistinguível de uma fala.

"Pegue seu presente!" nasce de `sistema_presente_disponivel`, no catálogo da
autoridade, e é localizado pelo cliente.

Esta OS **não** cria presente, não move carteira e não concede assinatura.

---

## 10. Retenção e privacidade (§7.5, §11)

`chatMessages` grava `expiraEm = enviadaEm + 30 dias`. Trinta dias é o prazo em
que uma denúncia ainda pode ser aberta e triada; fora dele o documento não serve
a ninguém — a evidência de uma denúncia é **copiada** para o registro dela,
justamente para sobreviver à expiração.

> ⚠️ **O campo é metade do mecanismo.** A outra metade é a política de **TTL do
> Firestore** apontada para `expiraEm`, que é **configuração de projeto** e não
> se aplica por deploy de código. Esta OS proíbe deploy; o que ela entrega é o
> campo, esta documentação e a prova de que ele é gravado. Ver §12.

**O que nunca entra em log:** conteúdo de mensagem, código de sala, ID token,
e-mail, telefone, token de compra. `registroSeguro()`
(`functions-moderacao/src/comunicacao.ts`) é lista de permissão — **não existe
campo por onde texto de jogador entre no log**.

---

## 11. Superfícies de deploy

| Codebase | O que mudou |
| --- | --- |
| `moderacao` | `definirCanalDeChat` (ambiente), núcleo de envio, `emitirEventoDeSistema`, `consultarCatalogoDeComunicacao`, `registrarDenuncia` (alvo + evidência) |
| `mesas` | `chatsPermitidos()`, padrão `apenas_emotes`, `modoDeChat` na sala privada |

| Coleção | Escrita por | Leitura | Exclusão de conta |
| --- | --- | --- | --- |
| `chatMessages` | moderacao | admin | `APAGAR` (por `autorUid`) |
| `chatChannels` | moderacao (via motor) | admin | `DESVINCULAR` (`participantes`) |
| `chatRitmo` | moderacao | admin | `APAGAR` (OS 48) |
| `salasPrivadas`, `assentosAdmitidos` | **mesas** | moderacao **só lê** | `DESVINCULAR` / `APAGAR` |
| `playerEntitlements` | **billing** | moderacao **só lê**, sem interpretar | `APAGAR` |
| `publicIdIndex` | **social** | moderacao **só lê** | `DESVINCULAR` (lápide) |
| `users/{uid}/mutes` | o próprio jogador | moderacao lê para a entrega | `APAGAR` (dos dois lados) |

A última coluna é **cópia**, e a fonte é `functions-conta/src/inventario.ts`:
`test/inventario.test.js` cruza a matriz com `firebase/firestore.rules` e
reprova quando uma coleção declarada lá não tem destino. Foi assim que a lacuna
de `chatRitmo` apareceu — a coleção nasceu aqui, depois da matriz.

---

## 12. Ativação (o que falta, e não é código)

1. **TTL do Firestore** sobre `chatMessages.expiraEm` — console do projeto.
2. **Índice composto** `chatMessages(canalId, itemId, enviadaEm)` — já declarado
   em `firebase/firestore.indexes.json`, precisa de deploy de índices.
3. **Topologia declarada no servidor de partidas**: uma instância que hospede
   Mesa Privada precisa de `tipoPartida: "privada"` na configuração do processo.
   Sem declaração, o canal nasce como **Mesa Pública** — falas prontas, sem
   digitação. É o padrão restritivo, e é deliberado.
4. **Credencial do motor no Railway** — pendência anterior a esta OS. Sem ela a
   ponte de chat falha fechada e o jogo roda sem comunicação.

---

## 13. O que esta OS NÃO faz

Não desenha tela, não liga botão, não cria emoji novo, não define preço, não
toca no motor, no Ranking, na carteira nem na assinatura. Não faz deploy, PR nem
merge.

A ligação visual é da próxima OS, e ela recebe pronto: catálogo consultável,
recusa com motivo categórico (`familia`), `liberaEmMs` para o contador de
cooldown, e alvo de denúncia resolvível por `publicId` — a dependência que
bloqueou a OS de UI de denúncia em 19/08/2026.
