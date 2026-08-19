# Contrato — Identidade Pública e Grafo Social (v1)

Documento de contrato da OS **Identidade Pública do Jogador e Grafo Social v1**.

Base: `homologacao/p0-integrada-a90557` @ `f9814f9`.

Quem lê isto para **integrar** (Perfil, Ranking, Hall, Amigos, Mesa) precisa das
seções 1, 2, 8, 9 e 12. Quem lê para **manter** precisa do resto.

---

## 0. Em uma frase

O UID identifica a conta para o sistema. O **publicId** identifica o jogador para
outros jogadores. O **apelido** é como ele quer aparecer. **Amizade** é uma
relação bilateral. **Bloqueio** continua sendo autoridade social superior à
amizade. Nenhuma dessas responsabilidades se mistura com outra.

---

## 1. As três identidades

| | o que é | onde vive | quem vê |
|---|---|---|---|
| **UID** | identidade interna do Firebase Auth | `users/{uid}`, `request.auth.uid`, `playerModeration/{uid}` | só o backend |
| **publicId** | identificador público, aleatório, imutável | `playerIdentities/{uid}` e `publicIdIndex/{publicId}` | todo mundo |
| **apresentação** | apelido + referência de avatar | `publicProfiles/{publicId}` | todo mundo |

**O publicId não deriva do UID** e **não depende do apelido**: o jogador troca de
apelido quantas vezes quiser sem trocar de identidade pública.

### Formato

```
P + 12 símbolos de base32 de Crockford sem I, L, O e U
exemplo: P0123456789AB
```

- 60 bits de entropia; colisão **detectada** (a reserva é um `create` que falha
  se o id já existir) e não apenas considerada improvável.
- Entrada é normalizada: minúsculas, hífens e espaços são aceitos, e `I`/`L`/`O`
  digitados no lugar de `1`/`0` são reparados. `U` **não** tem reparo — ele saiu
  do alfabeto por outro motivo (palavra acidental) e não se parece com nada.

#### Por que este formato, e não o `BMV-XXXXXXXXXX` do exemplo da OS

Porque **já existe uma implementação** deste identificador, em
`functions-ranking/src/identidade.ts`, na branch
`claude/ranking-ligas-backend-auth-ea5ceb`. A §9 da OS manda "aproveitar a
implementação existente, se houver". Há. Alfabeto, comprimento e prefixo são
idênticos aos dela — um id gerado aqui é válido lá, e vice-versa.

Ver a seção 11 (**Consolidação com o Ranking**) para o que ainda precisa
acontecer no dia em que as duas árvores se encontrarem.

---

## 2. O documento público

`publicProfiles/{publicId}` é o **primeiro documento deliberadamente público do
banco**. Qualquer jogador autenticado lê qualquer perfil — é isso que permite
`Ranking/Hall → publicId → Ver Perfil` sem que nenhuma dessas telas conheça UID.

> **Emenda da OS de Busca e Descoberta v1:** *ler* continua público; *varrer* não.
> O `allow list` desta coleção passou a exigir admin. A leitura por ID
> (`allow get`) não mudou, e é ela que sustenta tudo o que está descrito acima —
> nenhuma tela nem Function deste contrato usava `list`. Ver
> [CONTRATO-BUSCA-APELIDO-DESCOBERTA.md](CONTRATO-BUSCA-APELIDO-DESCOBERTA.md),
> seção "O achado".

### Campos permitidos — lista fechada

```
publicId  apelido  apelidoOrdenacao  avatarRef  estado  criadoEm  atualizadoEm  esquema
```

A lista vive em `camposPublicos`, em `app/lib/social/apresentacao.dart`, e é
**aplicada**: `exigirDocumentoPublicoLimpo` roda no servidor antes de **cada**
escrita e derruba a operação se aparecer chave fora dela.

### Campos proibidos

UID, e-mail, telefone, token, providerId, claims, Billing, entitlement,
assinatura, fichas, compras, denúncias, sanções, moderação interna, endereço,
CPF, bloqueios, mutes.

**Por que uma lista, e não um recorte de leitura:** o Firestore não projeta campo
por regra de segurança — uma regra libera ou nega o documento **inteiro**. Logo
"campo público" e "documento público" são a mesma coisa. Se um e-mail encostar
neste documento, ele está publicado, mesmo que nenhuma tela o desenhe.

É a mesma disciplina que a moderação já aplicou ao separar `reports/` (registro
administrativo) de `users/{uid}/reportReceipts` (comprovante do denunciante).

### Estado

`ativo` | `indisponivel`. Um estado **desconhecido** num documento gravado é
tratado como `indisponivel`, nunca como `ativo`: um estado que este código não
entende pode ser exatamente "banido".

---

## 3. Apelido

- `trim` nas bordas; espaços consecutivos colapsam para um.
- 3 a 24 **caracteres visíveis** (runas — emoji conta 1, não 2).
- Unicode normal aceito, inclusive acentos.
- Recusados: controles C0/C1, `DEL`, zero-width, marcas e overrides
  bidirecionais, juntadores invisíveis, BOM. O motivo é impersonação: dois
  apelidos que se **desenham** idênticos e são strings diferentes.
- **Não é único.** Quem desempata é o publicId (§7 da OS).
- Trocar o apelido **não** troca o publicId.

`apelidoOrdenacao` é derivado (minúsculas + acento dobrado) e **recalculado a
cada escrita**; o cliente nunca o envia. Serve só para ordenar — o que aparece na
tela é o `apelido` original, com acento e caixa.

### Não implementado nesta OS (§7)

Filtro de palavrões, moderação de nomes por IA, reserva de nomes famosos, selo de
verificação.

---

## 4. Avatar

`avatarRef` é uma **referência**, não um dado livre. Formato aceito:

```
^[a-z0-9][a-z0-9_-]{2,63}$
```

O alfabeto exclui exatamente os caracteres das quatro coisas que a §8 proíbe:
`:` e `/` (URL, caminho), `<` e `>` (HTML), `.` (caminho relativo, extensão) e
espaço (payload livre). A recusa depende de uma lista curta de coisas **boas**, e
não de uma lista de coisas ruins que alguém precisa lembrar de manter.

### Pendência registrada

**Não existe catálogo canônico de avatar nesta árvore.** O catálogo de coleções
(`app/data/colecoes/catalogo.seed.json`) tem os slots `mascote`, `efeito`,
`coroa`, `emblema` e `vitrine` — não tem avatar. `app/lib/services/perfil_service.dart`
desenha o avatar como um emoji fixo, que é placeholder de tela.

Enquanto `kCatalogoAvatares` estiver vazio, a validação é **só de formato**. No
dia em que houver catálogo, basta preencher a constante: a validação passa a
exigir pertencimento sem que nenhuma chamada mude. O teste `AVA-04` já prova esse
caminho.

`avatarRef` é `null` por padrão, e a ausência é tratada — nunca substituída pelo
UID nem por avatar derivado de e-mail.

---

## 5. O grafo social

### Fonte de verdade

`friendships/{pairKey}` — **um documento por par**.

```
pairKey = uidMenor + "|" + uidMaior      (calculado pelo servidor)
```

A chave é determinística e ordenada, e é ela que torna impossível existirem `A-B`
e `B-A` como documentos distintos: as duas chamadas produzem o mesmo texto, e a
segunda encontra o documento da primeira.

```jsonc
{
  "pairKey": "uidA|uidB",
  "membros": ["uidA", "uidB"],        // ordenados; sustenta o array-contains
  "estado": "pendente" | "amigos",
  "solicitanteUid": "uidA",
  "destinatarioUid": "uidB",
  "solicitadaEm": "2026-08-11T…Z",
  "amigosDesde": "2026-08-11T…Z" | null,
  "publicIds": { "uidA": "P…", "uidB": "P…" },
  "esquema": 1
}
```

**"Nenhuma relação" é a AUSÊNCIA do documento.** Recusar, cancelar e remover
apagam. Guardar um `estado: "recusada"` criaria uma lápide que ninguém consulta,
com política de expiração própria, e — pior — faria "não somos nada" ter duas
representações, que é o tipo de ambiguidade que produz bug de idempotência.

**`publicIds` é a única denormalização do documento**, e ela é segura para
sempre: o publicId é imutável, então não existe evento que a invalide. Apelido e
avatar **não** estão aqui, deliberadamente — eles mudam.

### Não existe estado `bloqueada`

A §12 lista "relação bloqueada" entre os estados necessários, e a forma **certa**
de atender isso é não guardá-lo aqui. Ver seção 7.

### Projeções derivadas

| coleção | papel | ordenada por |
|---|---|---|
| `users/{uid}/friends/{outroUid}` | lista de amigos | `apelidoOrdenacao`, `publicId` |
| `users/{uid}/friendRequests/{outroUid}` | solicitações, com `direcao` | `solicitadaEm` desc, `publicId` |

Elas existem por **um** motivo concreto: ordenar a lista de amigos por apelido
exige que a chave de ordenação esteja num campo indexável do lado de **quem
consulta** — e o apelido do amigo é diferente para cada um dos dois membros do
par, então o documento canônico não tem onde guardar os dois.

**São escritas na MESMA transação da fonte.** Criar, aceitar, recusar, cancelar e
remover tocam canônico e projeções juntos ou nenhum dos dois: não há janela em
que A liste B e B não liste A.

### Contadores

`playerSocial/{uid}` = `{ uid, amigos, solicitacoesEnviadas, atualizadoEm }`,
escrito na mesma transação. Contador transacional em vez de `count()` — que não
roda dentro de transação — porque o teto precisa ser exato, e porque §26 exige
provar que uma chamada repetida **não** incrementa duas vezes.

Valores são escritos em **absoluto** a partir do que foi lido na transação
(`Math.max(0, n-1)`), e não com `increment(-1)`: um contador que já estivesse
errado se corrige em vez de afundar para negativo.

---

## 6. Reconciliação

O único caminho que pode deixar uma projeção velha é a **troca de apelido**, que
atualiza `apelidoOrdenacao` em até 200 documentos **fora de transação**.

**O estrago máximo disso é cosmético.** `apelidoOrdenacao` só ordena; o apelido
**exibido** é lido de `publicProfiles` na hora da consulta. Uma propagação que
falhe coloca um amigo na posição errada da lista — nunca com o nome errado. A
§31-I ("alteração de apelido refletida sem trocar publicId") vale por construção,
sem depender de nenhuma propagação ter dado certo.

Reparo: `reconciliarPerfilSocial` (callable, **só admin**) reconstrói projeções e
contadores de um jogador a partir de `friendships`. Se as duas discordarem, o
canônico vence — é por isso que ele é o canônico.

---

## 7. Bloqueio e mute

### Bloqueio é soberano, e é consumido — nunca duplicado

A fonte canônica continua sendo `users/{uid}/blocks/{alvoUid}`, escrita por
`bloquearJogador` no codebase de **moderação**. Esta OS **não criou** um segundo
mecanismo de bloqueio, e o teste `não existe segunda coleção de bloqueio` é o
alarme para quem tentar.

A decisão "pode haver contato?" é a função `avaliarContato` de
`app/lib/moderacao/relacao_social.dart` — a **mesma** função que
`functions-moderacao` chama. O bundle social a compila junto
(`js_bridge.dart` importa `moderacao/relacao_social.dart`), então existe **uma**
implementação. Se um dia o bloqueio ganhar uma regra nova, ela vale nos dois
codebases no mesmo commit.

### Defesa em duas camadas

1. **Toda** operação social lê o bloqueio **dentro da própria transação**. É isso
   que faz a §27 valer: "A aceita enquanto B bloqueia A" não pode terminar em
   amizade ativa.
2. O gatilho `aoBloquearJogador` reage a `users/{uid}/blocks/{alvo}` e desfaz a
   amizade e as solicitações nos dois sentidos.

**A janela entre o bloqueio e a faxina não é explorável**: durante ela a amizade
existe no banco, mas nenhuma ação social passa. A faxina alinha o banco com a
realidade; ela não é o que produz a realidade.

**Por que gatilho e não uma chamada dentro de `bloquearJogador`:** os dois
codebases são unidades de implantação independentes, e fazer a moderação chamar o
social significaria que um deploy quebrado da faxina derrubaria a capacidade de
**bloquear** alguém — a ferramenta de proteção mais urgente do aplicativo. A
dependência aponta para o lado seguro.

### Desbloquear não restaura nada

Amizade não volta. Solicitação antiga não renasce. Nova amizade exige nova
interação.

### Mute não é bloqueio

Silêncio pessoal (`users/{uid}/mutes/{alvo}`) é preferência de exibição. Ele
**não** remove amizade, **não** impede amizade, **não** vira bloqueio e **não**
altera o grafo. Não há nenhum parâmetro de mute em nenhuma função deste domínio —
a ausência é a implementação.

---

## 8. Contrato de leitura pública

### `verPerfilPublico({ publicId })` — a porta única (§31-C)

Ranking, Hall, lista de amigos, solicitações, participantes de mesa e o próprio
Perfil chamam **esta** função. Não há um endpoint de perfil por tela.

```jsonc
{
  "perfil": { "publicId": "P…", "apelido": "Maria", "avatarRef": null, "desde": null },
  "relacao": "nenhuma" | "solicitacaoEnviada" | "solicitacaoRecebida"
           | "amigos" | "bloqueadoPorMim" | "indisponivel" | "euMesmo",
  "acoes": ["adicionarAmigo", "bloquear"],
  "amigosDesde": "2026-08-11T…Z" | null
}
```

**UID não é necessário no cliente e não aparece na resposta.** A resolução
`publicId → uid` acontece exclusivamente no backend, em `publicIdIndex`, que é
negada a todo cliente.

### Ações por estado (§31-B)

| relação | ações |
|---|---|
| `nenhuma` | `adicionarAmigo`, `bloquear` |
| `solicitacaoEnviada` | `cancelarSolicitacao`, `bloquear` |
| `solicitacaoRecebida` | `aceitarSolicitacao`, `recusarSolicitacao`, `bloquear` |
| `amigos` | `removerAmigo`, `bloquear` |
| `bloqueadoPorMim` | `desbloquear` |
| `indisponivel` | *(nenhuma)* |
| `euMesmo` | `editarPerfil` |

`indisponivel` cobre **dois fatos diferentes** — "o outro me bloqueou" e "estou
com restrição social" — de propósito. O cliente sabe que não pode interagir; não
sabe por quê. Nem o botão de bloquear é oferecido: ele seria, por si, a
informação. Nada de "Fulano bloqueou você".

**A interface não inventa permissões, e também não as deduz.** A lista vem
pronta. O backend revalida cada ação de qualquer modo: `acoes` serve para
desenhar botão, não para autorizar.

### Perfil próprio vs. de terceiro (§31-E)

A **mesma** fonte canônica de apresentação. O que muda é a função:
`obterMinhaIdentidade` devolve, além do perfil, os metadados de **edição**
(limites de apelido, se há catálogo de avatar) e os limites sociais. Esses campos
não existem na resposta pública destinada a terceiros — são respostas de funções
diferentes, e não um documento só com recorte.

### Indisponível (§31-G)

Conta inexistente e conta desativada respondem **igual**:
`not-found` + `details.recusa = "perfilPublicoNaoDisponivel"`. Distinguir as duas
diria quais ids já pertenceram a alguém.

Um publicId **malformado** é outra história: responde
`perfilPublicoInvalido`, porque o cliente já sabe sozinho que a string não tem o
formato — a distinção ajuda a tela sem contar nada de ninguém.

---

## 9. Superfície de Functions

Região: `southamerica-east1`. Codebase: `social` (`functions-social/`).
App Check exigido em produção; dispensado sob o emulador.

| função | papel |
|---|---|
| `obterMinhaIdentidade` | obtém/cria o publicId (idempotente) + perfil próprio |
| `atualizarPerfilPublico` | apelido e/ou avatar |
| `verPerfilPublico` | perfil + relação + ações, por publicId |
| `localizarJogadorPorIdentidade` | versão magra: só a apresentação |
| `enviarSolicitacaoAmizade` | pedido — ou aceite do inverso (§27) |
| `aceitarSolicitacaoAmizade` | só o destinatário |
| `recusarSolicitacaoAmizade` | só o destinatário |
| `cancelarSolicitacaoAmizade` | só o remetente |
| `removerAmizade` | qualquer um dos dois; bilateral |
| `listarAmigos` | paginado, por apelido |
| `listarSolicitacoesRecebidas` | paginado, por recência |
| `listarSolicitacoesEnviadas` | paginado, por recência |
| `aoBloquearJogador` | gatilho de faxina (Firestore) |
| `reconciliarPerfilSocial` | reparo administrativo |
| `buscarJogadoresPorApelido` | busca por apelido — **acrescentada pela OS de Busca**; contrato próprio em [CONTRATO-BUSCA-APELIDO-DESCOBERTA.md](CONTRATO-BUSCA-APELIDO-DESCOBERTA.md) |

Todas recebem **publicId**, nunca UID de terceiro. Todas passam por
`exigirRespostaSegura`, que varre a resposta em profundidade e **lança** se
encontrar chave privada — inclusive aninhada e dentro de lista. Falhar a chamada
é melhor que entregar o UID.

### Paginação

Cursor **opaco** (base64 de duas partes). O cliente devolve o que recebeu, sem
interpretar; se a ordenação mudar amanhã, nenhum aplicativo instalado quebra.
Cursor corrompido é tratado como "primeira página" — devolver 500 daria a quem
tenta forjar um sinal de que acertou o formato.

Página padrão 25, teto 50.

---

## 10. Limites e códigos de erro

### Limites (§25) — centralizados em `app/lib/social/amizade.dart`

| limite | valor |
|---|---|
| amizades ativas por jogador | **200** |
| solicitações pendentes **enviadas** | **50** |
| solicitações pendentes **recebidas** | **sem teto** |

A ausência de teto nas recebidas é a implementação de §25, não um esquecimento:
um teto ali seria uma arma — contas descartáveis encheriam a caixa da vítima e
ninguém mais conseguiria adicioná-la, para sempre.

O TypeScript **não** tem cópia desses números: `LIMITES` vem do domínio Dart pela
ponte. Dois lugares com o número 200 já são um lugar a mais.

### Códigos (§35)

Estáveis, em `details.recusa`. A convenção é a do projeto (camelCase, como
`RecusaDenuncia` e `RecusaBloqueio`), e **não** o `SCREAMING_SNAKE` do exemplo da
OS — §35 manda usar a convenção real do projeto, e misturar as duas faria o
cliente tratar `autoDenuncia` e `AUTO_AMIZADE_INVALIDA` no mesmo `switch`.

```
identidadeNaoEncontrada     perfilPublicoNaoDisponivel   perfilPublicoInvalido
autoAmizadeInvalida         jaSaoAmigos                  solicitacaoJaExiste
solicitacaoNaoEncontrada    naoEDestinatario             naoERemetente
relacaoBloqueada            limiteAmigos                 limiteSolicitacoes
apelidoInvalido             avatarInvalido               identificadorInvalido
```

`relacaoBloqueada` é **deliberadamente opaco**: um código só para "eu bloqueei",
"fui bloqueado" e "estou com restrição social".

**O cliente nunca deve depender do TEXTO do erro** — só do código.

### Idempotência

Não há tabela de intenções (`socialTasks`) e ela não é necessária: o estado da
relação entre dois jogadores é único e a chave do documento é função do par.
Enviar duas vezes encontra a mesma pendência; aceitar duas vezes encontra a
amizade feita; remover duas vezes encontra o vazio.

Toda resposta repetida vem como **sucesso** com `repeticao: true` e
`motivo: "<código>"` — nunca erro. Devolver erro faria o cliente tentar de novo, e
a próxima tentativa também "falharia": um laço que só termina quando o jogador
desiste. Mesmo padrão do `jaRegistrada: true` da denúncia.

### Concorrência cruzada (§27)

| cenário | desfecho |
|---|---|
| A pede a B enquanto B já pediu a A | vira **aceite** (`aceitarInversa`). Quem chega por último aceita. |
| A aceita enquanto B bloqueia A | **bloqueio prevalece** — a leitura do bloqueio está na mesma transação |
| A remove enquanto B envia nova solicitação | serializado pela transação sobre `friendships/{pairKey}` |

A alternativa que §27 permite para o primeiro caso (recusar a duplicidade) foi
descartada porque produz tela sem saída: os dois se convidaram, os dois veem
"solicitação enviada", e nenhum vê o botão de aceitar.

---

## 11. Contrato para Ranking e Hall — sem acoplamento

**`functions-ranking` NÃO foi alterado por esta OS.** O que segue é contrato para
a consolidação futura, não integração.

### O que o Ranking precisa, e já pode obter

- **`publicId → perfil`**: `verPerfilPublico` ou `localizarJogadorPorIdentidade`.
  Ranking e Hall nunca precisam de UID.
- **"os amigos do jogador autenticado"** (a aba `amigos`, que hoje não produz
  resultado real por falta de grafo): `listarAmigos` devolve as identidades
  públicas paginadas. Para uso interno do backend de ranking, a consulta é
  `friendships where membros array-contains uid and estado == "amigos"`, e o
  `publicIds[outro]` do documento dá a identidade sem uma segunda leitura.

### O que precisava ser decidido na consolidação — **RESOLVIDO**

> **Atualização.** A consolidação aconteceu, na OS de integração Identidade
> Pública × Ranking v1 (branch `integracao/identidade-publica-ranking-v1`). Os
> três itens abaixo foram executados: `garantirIdPublico` e o gerador do ranking
> foram **removidos**, `rankingPublicIds` deixou de existir, e
> `rankingStandings.apelido`/`.avatar` passaram a ser projeção de
> `publicProfiles`. A autoridade única é esta.
>
> O texto original fica abaixo, sem edição, porque ele é o registro de que o
> conflito foi previsto e não descoberto tarde. Ver
> [AUTORIDADE-DE-IDENTIDADE-PUBLICA.md](AUTORIDADE-DE-IDENTIDADE-PUBLICA.md).

O `functions-ranking` da branch paralela mantém o **seu próprio** par de
coleções: `rankingPlayers/{uid}.publicPlayerId` e `rankingPublicIds/{publicId}`.
Esta OS mantém `playerIdentities/{uid}` e `publicIdIndex/{publicId}`.

**O formato é idêntico** (mesmo alfabeto, mesmo comprimento, mesmo prefixo), o
que torna o encontro uma **reconciliação de dados**, e não uma quebra de
contrato. Na consolidação:

1. `garantirIdPublico` em `functions-ranking/src/firestore.ts` deve **parar de
   cunhar** e passar a ler `playerIdentities/{uid}` — a autoridade de identidade
   é uma só, e é esta.
2. Se já houver dados nas duas, migrar `rankingPublicIds` para `publicIdIndex`
   preservando os ids já emitidos (eles podem estar em links de perfil).
3. `rankingPlayers.apelido` — que hoje é lido de `anterior?.apelido` e **nunca é
   escrito por ninguém** — deve sair, ou passar a ser resolvido de
   `publicProfiles` na leitura. A lacuna que a OS de ranking registrou ("não
   existe fonte segura de apelido") é exatamente o que este documento fecha.

Nada disso é feito aqui, por decisão da §41.

---

## 12. Segurança — o que está provado

| afirmação | onde é provado |
|---|---|
| UID não sai na API pública | `chaves.test.js` (trava, inclusive aninhada e em lista) + `social.test.js` (respostas reais) |
| e-mail/Billing/moderação não saem | `chaves.test.js`, `teste_social.dart` PUB-02, `social.test.js` |
| cliente não cria amizade diretamente | `social.test.js` — `friendships` write negado |
| cliente não muda o publicId | `social.test.js` — `playerIdentities` write negado |
| cliente não escolhe o próprio publicId | `social.test.js` — payload com `publicId` é ignorado |
| bloqueio não pode ser contornado | `social.test.js` §18, §27, §31-H |
| identidade não deriva do UID | `teste_social.dart` IDN-05 + `social.test.js` |
| o mapa `publicId → uid` é invisível ao cliente | `social.test.js` — `publicIdIndex` negado a todos |
| a lista de amigos não vaza UID nem na CHAVE | `social.test.js` — `users/{uid}/friends` negado até ao dono |
| contador não pode ser zerado para furar o teto | `social.test.js` — `playerSocial` write negado |

**Detalhe que se perde numa leitura rápida:** as projeções `users/{uid}/friends`
e `users/{uid}/friendRequests` são negadas **até ao dono**, porque o **id do
documento é o UID do outro jogador**. Um `list` ali devolveria a lista de UIDs
dos amigos sem que nenhum **campo** carregasse UID — o vazamento estaria na
chave, não no valor.

---

## 13. Mapa da implementação

### Domínio (decide) — `app/lib/social/`

| arquivo | assunto |
|---|---|
| `erros_sociais.dart` | códigos estáveis, `kEsquemaSocial` |
| `identidade_publica.dart` | formato, geração, normalização, estado do perfil |
| `apresentacao.dart` | apelido, avatar, `PerfilPublico`, a trava de campos |
| `amizade.dart` | chave do par, estados, vereditos, limites, vista e ações |
| `listagem_social.dart` | ordenação, cursor, tamanho de página |
| `js_bridge.dart` | ponte para o Node — **importa `moderacao/relacao_social.dart`** |

### Execução — `functions-social/src/`

| arquivo | assunto |
|---|---|
| `domain.ts` | carrega o bundle; `LIMITES` vem daqui |
| `chaves.ts` | coleções, projeção pública, trava de vazamento (**puro**) |
| `repositorio.ts` | identidade, contato, transação da relação, listas, faxina, reconciliação |
| `index.ts` | callables, gatilho, tradução de recusa em `HttpsError` |

### Regras e índices

- `firebase/firestore.rules` — bloco **6/6**
- `firebase/firestore.indexes.json` — 3 índices novos (`friends`,
  `friendRequests`, `friendships`)

### Testes

| suíte | como roda | o que prova |
|---|---|---|
| `app/test/social/teste_social.dart` | `flutter test` | decisão pura |
| `functions-social/test/chaves.test.js` | `node --test` (sem emulador) | a trava de vazamento |
| `firebase/testes/social.test.js` (regras) | `emulators:exec --only firestore` | quem lê e quem escreve |
| `firebase/testes/social.test.js` (Functions) | `npm run emulador:social` | idempotência, concorrência, respostas reais |

---

## 14. Escolhas que valem revisitar

### A ordenação por apelido custa uma projeção

A alternativa considerada foi carregar as ≤200 amizades e ordenar em memória:
zero fan-out, zero reconciliação, sempre fresco — mas ~600 leituras por página em
vez de ~50. Com o teto em 200 as duas funcionam; a projeção ganhou por custo.

**O limiar em que o desenho muda:** se o teto de amizades subir acima de ~1000, a
alternativa em memória deixa de ser viável de vez e a projeção passa a ser
obrigatória (já é o que está feito). Se o teto **cair** muito, vale reconsiderar
apagar a projeção e simplificar.

### O piso de 3 caracteres pega nomes CJK curtos

`花子` ("Hanako") tem duas runas e é um nome próprio completo em japonês. O piso
de 3 da §7 o recusa. Ficou assim porque a faixa é a que a OS especifica —
afrouxar por conta própria mexeria numa política de nomes. O teste `APE-05b`
existe para que a limitação seja um fato conhecido, e não uma descoberta de
suporte.

---

## 15. Lacunas e dependências

| lacuna | consequência hoje | quem resolve |
|---|---|---|
| **Catálogo de avatar não existe** | `avatarRef` valida só formato | OS de vitrine/coleções |
| **`functions-ranking` não consolidado** | duas coleções de identidade em branches diferentes | OS de consolidação — ver seção 11 |
| **Exclusão/desativação de conta não existe no projeto** | `EstadoPerfilPublico.indisponivel` está implementado e testado, mas **nada o escreve**: não há fluxo de exclusão nesta árvore. O perfil de uma conta removida permaneceria `ativo`. | OS de LGPD/exclusão. Quando ela existir, basta gravar `estado: "indisponivel"` — a leitura já respeita. |
| **Solicitação pendente não expira** | uma pendência recusada pode ser reenviada imediatamente; pendências antigas ficam para sempre | decisão de produto |
| ~~**Sem busca por apelido**~~ | **RESOLVIDA.** `buscarJogadoresPorApelido` existe; ver [CONTRATO-BUSCA-APELIDO-DESCOBERTA.md](CONTRATO-BUSCA-APELIDO-DESCOBERTA.md) | OS de Busca e Descoberta Social v1 |
| **Sem UI** | esta OS entrega backend e contrato; `app/lib/screens/amigos_screen.dart` ainda é a tela estática anterior | OS de UI social |
| **Nenhuma Function foi implantada** | tudo foi exercitado no emulador; não houve deploy | operação |
