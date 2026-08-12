# Contrato — Busca por Apelido e Descoberta Social (v1)

> Complementa [CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md](CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md),
> que continua sendo o contrato da **identidade** e do **grafo**. Este documento
> trata apenas de **encontrar** um jogador pelo apelido público.
>
> Nada aqui substitui aquele contrato. `publicId` continua sendo a identidade,
> `publicProfiles/{publicId}` continua sendo a apresentação canônica e
> `friendships/{pairKey}` continua sendo a única fonte de amizade.

---

## 0. Em uma frase

O jogador digita um apelido, o servidor devolve no máximo vinte identidades
públicas — e nem o UID, nem quem bloqueou quem, nem a base inteira.

---

## 1. Identidade canônica × estrutura derivada de busca

A distinção que a OS §18 exige que este documento deixe explícita:

| | o que é | onde mora | quem manda |
|---|---|---|---|
| **identidade canônica** | `publicId` | `publicProfiles/{publicId}` (o ID do documento), `playerIdentities/{uid}`, `publicIdIndex/{publicId}` | **autoritativa** |
| **apresentação canônica** | `apelido`, `avatarRef` | `publicProfiles/{publicId}` | **autoritativa** |
| **amizade canônica** | estado da relação | `friendships/{pairKey}` | **autoritativa** |
| **chave de busca** | `apelidoOrdenacao` | `publicProfiles/{publicId}`, mesmo documento | **derivada, não autoritativa** |

`apelidoOrdenacao` é função do apelido, recalculada pelo servidor a cada
escrita, nunca aceita do cliente. Perdê-lo inteiro custaria a ordenação da lista
de amigos e a busca — e mais nada; ele se reconstrói reescrevendo o perfil. Ele
**não** é identidade, **não** é apresentação e **não** decide amizade.

### Não foi criada nenhuma coleção auxiliar

A OS §4 permite uma estrutura derivada de índice, desde que mínima, sem UID e
reconstruível. **A mínima possível é nenhuma.** `apelidoOrdenacao` já existia
desde a OS anterior — foi criado para ordenar a lista de amigos por apelido — e
já é exatamente a chave normalizada que uma busca precisa.

Um `nicknameIndex/{chave}` seria uma segunda cópia do mesmo campo. Duas cópias é
uma divergência esperando o dia em que alguém escrever só numa delas.

O teste de regras `BUSCA §4 — nao existe colecao auxiliar de indice de busca`
mantém isso verificável: se alguém criar uma, o fecho padrão do `firestore.rules`
a nega e o teste avisa que ela precisa das próprias regras antes de existir.

---

## 2. Normalização

Uma função, usada nos dois lados:

```
chaveDeBusca(texto) == chaveDeOrdenacao(normalizarApelido(texto))
apelidoOrdenacao    == chaveDeOrdenacao(apelido já normalizado na gravação)
```

`app/lib/social/busca_apelido.dart` não reimplementa nada: `chaveDeBusca` é
literalmente a composição das duas funções que a OS anterior já usava para
gravar. A equivalência exigida pela OS §5 vale **por construção**, não por
coincidência testada.

| entrada | tratamento |
|---|---|
| caixa alta/baixa | `toLowerCase()` |
| espaços nas bordas | aparados |
| espaços/tabulações repetidos | colapsados para um espaço |
| acento (á à ã â ä å é è ê ë í ì î ï ó ò õ ô ö ú ù û ü ç ñ ý) | dobrado para a letra base |
| emoji e demais Unicode | preservados |
| caractere de controle (C0, C1, DEL) | **recusado** |
| largura zero, marcas e overrides de direção, juntadores, BOM | **recusado** |
| entrada vazia (ou só espaço) | **recusada** |

O apelido **exibido** não muda: continua sendo `PerfilPublico.apelido`, com
acento e caixa originais. A chave só existe para comparar.

### Limitação conhecida

A dobra de acento é uma tabela escrita à mão (herdada da OS anterior) e cobre
caracteres **pré-compostos**. Um `á` escrito como `a` + U+0301 (acento
combinante) não é dobrado. Isso vale igualmente na gravação e na busca — logo
não produz divergência —, mas significa que dois apelidos visualmente idênticos
com composições Unicode diferentes são apelidos diferentes para a busca.
Resolver exigiria uma dependência de normalização Unicode (NFC/NFD) e é decisão
para uma versão futura.

### Testes

`NRM-01` a `NRM-09`, `NRM-EQ` e `NRM-EQ2` em
`app/test/social/busca_apelido_test.dart`. `NRM-EQ` compara, para o mesmo texto
bruto, a chave que a busca procura com o `apelidoOrdenacao` que a gravação grava
— pelos **dois** caminhos de escrita que existem (`perfilPublicoInicial` e
`atualizarPerfilPublico`). `NRM-EQ2` prova o outro lado: não existe termo que a
busca aceite e que nunca pudesse ter sido gravado como apelido.

---

## 3. Modalidades

| modo | comparação | consulta |
|---|---|---|
| `exato` (padrão da OS §6) | `apelidoOrdenacao == chave` | igualdade |
| `prefixo` (**padrão do parâmetro**) | `chave ≤ apelidoOrdenacao ≤ chave + U+10FFFF` | faixa ordenada |

Os dois correm sobre o mesmo campo e o mesmo índice. Prefixo é o padrão do
parâmetro porque é o que uma tela de busca faz enquanto a pessoa digita; exato é
a modalidade que a OS manda priorizar, e está disponível explicitamente.

Modo desconhecido é **recusado**, e não silenciosamente tratado como o padrão —
um `modo: "contem"` aceito faria o cliente acreditar numa busca que não existe.

### Por que U+10FFFF, e não U+F8FF

O idiom mais citado para prefixo no Firestore fecha a faixa em U+F8FF. U+F8FF
fica na Área de Uso Privado e é **menor** que qualquer emoji (que vivem acima de
U+1F000). Um apelido "Ana🎈" produziria chave maior que `"ana" + U+F8FF` e
**sumiria** da busca por "ana" — e apelido com emoji é legítimo, porque a
validação conta runas e não proíbe a faixa. U+10FFFF é o maior ponto de código
que existe. Teste `MOD-06`.

### O que a v1 não faz

Sem busca fuzzy, sem Levenshtein, sem **infixo** ("quem contém 'ana'"), sem
ranking de relevância, sem sugestão, sem histórico de pesquisa, sem descoberta
por telefone/e-mail/contatos/localização, sem "pessoas que talvez você conheça".

Prefixo e exato ancoram no começo da chave, que é o que uma faixa ordenada do
Firestore serve **sem estrutura nova**. É por caber na estrutura existente que
essa é a modalidade "segura comprovada" que a OS §6 pede. Teste
`prefixo NAO e infixo`.

---

## 4. A superfície

### `buscarJogadoresPorApelido({ termo, modo?, limite? })`

Região `southamerica-east1`, codebase `social`, App Check exigido em produção.
Exige autenticação.

**Pedido**

| campo | tipo | padrão | validação |
|---|---|---|---|
| `termo` | string | — | 3 a 24 caracteres **visíveis**, medidos depois da normalização |
| `modo` | `"exato"` \| `"prefixo"` | `"prefixo"` | valor desconhecido é recusado |
| `limite` | número | 10 | ≤ 0 ou inválido → padrão; > 20 → 20 |

**Resposta**

```json
{
  "itens": [
    {
      "publicId": "P0123456789AB",
      "apelido": "Dona Maria",
      "avatarRef": "coruja_dourada",
      "relacao": "nenhuma",
      "acoes": ["adicionarAmigo", "bloquear"]
    }
  ],
  "truncado": false,
  "modo": "prefixo"
}
```

**Cinco campos por item, e nada mais.** A allowlist é reaplicada em
`entradaDeBusca` (`functions-social/src/chaves.ts`) mesmo com a fonte já sendo
pública — defesa em profundidade, OS §7. Campo a campo, nunca por espalhamento:
um `{...perfil}` traria `apelidoOrdenacao`, `estado`, `criadoEm`,
`atualizadoEm` e `esquema`, nenhum privado, nenhum assunto de quem procura.

`desde` **não** existe aqui, embora exista nas listas de amigos: "amigos desde"
não é informação de descoberta.

`truncado: true` significa "havia mais correspondências **visíveis para quem
procura** do que coube". **Não é cursor** — ver seção 6 — e **não conta
bloqueados**: ver seção 7, "O oculto não existe nem no metadado".

Toda a resposta passa por `exigirRespostaSegura`, que varre em profundidade e
**lança** se encontrar chave privada, inclusive aninhada e dentro de lista.

---

## 5. Estado social no resultado

Vem de `vistaDaRelacao` + `acoesDisponiveis` — as **mesmas** funções que
`verPerfilPublico` usa. Nenhum vocabulário novo foi criado.

| `relacao` | `acoes` |
|---|---|
| `nenhuma` | `adicionarAmigo`, `bloquear` |
| `solicitacaoEnviada` | `cancelarSolicitacao`, `bloquear` |
| `solicitacaoRecebida` | `aceitarSolicitacao`, `recusarSolicitacao`, `bloquear` |
| `amigos` | `removerAmigo`, `bloquear` |
| `indisponivel` | *(nenhuma)* |
| `euMesmo` | `editarPerfil` |

`bloqueadoPorMim` **não aparece na busca** — quem eu bloqueei é omitido do
resultado (seção 7).

O estado é **composto na hora da leitura**, a partir de `friendships/{pairKey}` e
do bloqueio. A busca **não é fonte de amizade**: o botão que ela desenha é
desenho de botão, e cada ação é revalidada dentro da transação da Function
correspondente. Testes `SOC-01` a `SOC-07` e
`§10 — a busca nao e fonte de amizade`.

O próprio jogador aparece na própria busca, como `euMesmo`, sem ação social.
Omiti-lo criaria um oráculo ("meu perfil sumiu") sem proteger nada.

---

## 6. Anti-enumeração

A busca não pode virar um diretório de jogadores. Os controles, e o que cada um
fecha:

| controle | valor | o que impede |
|---|---|---|
| tamanho mínimo do termo | 3 caracteres visíveis, **medidos depois do trim** | "os jogadores cujo apelido começa com **a**" |
| tamanho máximo | 24 | termo ilimitado engordando log e consulta |
| teto de resultados | 20 (padrão 10) | uma consulta enxergar mais que uma janela |
| **ausência de cursor** | — | percorrer a base em passos de vinte |
| filtro `estado == "ativo"` | na consulta | contas desativadas na descoberta |
| validação estrita de parâmetros | modo desconhecido recusado | busca inexistente parecendo existir |
| sem curinga | `*` e `%` são texto comum | um termo que case com tudo |
| sem rota "listar todos" | — | — |
| `allow list` fechado em `publicProfiles` | admin | varredura direta, sem passar pela Function |
| App Check | exigido em produção | automação sem cliente legítimo |

### A ausência de paginação é a decisão central

Uma busca paginada é um diretório com passos: `limite=20` mais um cursor
percorre, em 500 chamadas, os 10.000 jogadores cujo apelido começa com "a". Sem
cursor, cada consulta enxerga no máximo vinte jogadores, e a única forma de ver
outros é escrever um termo **mais específico** — que exige saber o que se
procura, que é a definição de "buscar" em oposição a "listar".

A constante `kSemCursor` existe para que a ausência seja citável e testável: uma
ausência não aparece num diff. Testes `LIM-05` (domínio),
`a resposta de busca nao tem cursor` (Node puro) e
`§9 — NAO HA CURSOR` (emulador, que também prova que mandar `cursor` no payload
não muda nada).

### Risco residual, registrado e não resolvido

**Não há limite de taxa por chamador.** A OS §9 manda reutilizar infraestrutura
de rate limiting **se o projeto já tiver uma compatível**, e proíbe criar um
sistema paralelo de segurança sem necessidade comprovada. O que existe hoje é o
freio de denúncias da moderação — contagem por janela sobre a coleção `reports`,
que só funciona porque cada denúncia **é** um documento. Uma busca não deixa
documento, e criar uma coleção para contá-las seria exatamente o "histórico de
pesquisas" que a OS §6 proíbe implementar.

Consequência honesta: um cliente com App Check válido pode emitir muitas
consultas. Cada uma enxerga no máximo vinte jogadores e exige um termo de três
caracteres, então a varredura sistemática custa dezenas de milhares de chamadas
— mas ela não está *impedida*, só encarecida.

Isto é uma **lacuna registrada**, não um controle esquecido. Resolvê-la pede
infraestrutura genérica de quota (App Check já dá o gancho, ou Cloud Armor), que
serve a todo o backend e não só a esta OS.

---

## 7. Bloqueio

**Regra única: bloqueio em qualquer sentido remove da descoberta.**

| situação | resultado na busca |
|---|---|
| o alvo me bloqueou | **omitido** |
| eu bloqueei o alvo | **omitido** |
| sanção social/chat vigente sobre **mim** | aparece como `indisponivel`, sem ação nenhuma |
| nenhum dos dois | aparece normalmente |

### Por que omitir, e por que nos dois sentidos

**O alvo me bloqueou** — é a proteção que a OS §8 pede. Sem ela, a busca seria a
rota que devolve ao bloqueado o acesso que o bloqueio tirou: ele acharia a
pessoa, veria o perfil e tentaria a amizade.

**Eu bloqueei o alvo** — não é exigência da OS. É a mesma decisão que a moderação
já tomou em `avaliarContato` ao recusar as duas direções, e tem uma razão de
privacidade própria: se uma direção sumisse e a outra aparecesse como
"indisponível", **a diferença contaria de que lado veio o bloqueio**. Iguais, a
resposta é a mesma lista vazia nos dois casos — e também no caso de o apelido
simplesmente não existir. Teste `§8 — quem EU bloqueei tambem some, e a ausencia
e IGUAL nos dois casos`.

### Sanção não oculta

Um jogador com restrição social **vê** os resultados e não recebe ação nenhuma
sobre eles. Ocultar tudo faria a busca parecer quebrada em vez de restrita, e a
restrição é sobre **agir**, não sobre enxergar. Quem impede a ação de verdade é
`enviarSolicitacaoAmizade`, que relê o contato dentro da própria transação.

### O oculto não existe nem no metadado

Tirar o bloqueado da lista **não basta**. Se ele puder alterar qualquer coisa
observável — a contagem, a ordem ou o `truncado` — a ausência deixa de ser
ausência e vira sinal.

Uma consulta única de `limite + 1` documentos, filtrada depois, tem dois
vazamentos pelo mesmo buraco:

| defeito | como aparece |
|---|---|
| `truncado` calculado sobre o lote **bruto** | faixa `[A, B visíveis; C bloqueado]`, limite 2 → o lote de três diz "havia mais", quando para quem procura há exatamente dois. O mundo sem C responderia `truncado: false`. |
| o bloqueado **roubando vaga** | faixa `[A bloqueado; B, C, D visíveis]`, limite 2 → lê-se `[A, B]`, filtra-se A, devolve-se **um** item. C ficou de fora por um bloqueio que não é dele. |

A correção dos dois é a mesma: **`varrerVisiveis`** continua avançando na faixa
até juntar `limite + 1` candidatos **visíveis**, e só então decide.
`truncado = visíveis > limite`, nunca `brutos > limite`.

O avanço usa um `startAfter` que **nasce e morre dentro de uma chamada**. Não é
paginação: o contrato de §9 é que o *cliente* não pode avançar, e ele continua
sem cursor, sem campo de cursor na resposta e sem efeito ao mandar um no payload.

**Duas saídas, e só duas.** A varredura termina quando junta `limite + 1`
candidatos **visíveis** (há mais) ou quando a faixa **acaba** (não há). Não
existe uma terceira — *"parei por limite interno e presumo que truncou"* — e a
ausência dela é o desenho.

Uma versão intermediária desta OS tinha teto de cinco rodadas. Ele reintroduzia a
mesma classe de vazamento que a varredura existe para fechar: parar sem ter
esgotado a faixa fazia `truncado: true` depender de **quantos** estavam ocultos,
e deixava candidatos legítimos posteriores aos ocultos fora da resposta — o
"roubo de vaga", em escala maior. Raridade e custo de exploração não tornam a
propriedade verdadeira. **Ou o oculto é observacionalmente indistinguível do
inexistente, ou não é.**

`truncado = visíveis > limite`. Uma linha, sem nenhum termo sobre *como* a
varredura terminou — acrescentar um reabriria o vazamento.

**Terminação e custo.** A varredura termina porque a faixa é finita e a ordem é
**total**: cada rodada começa depois do último documento da anterior, consome ao
menos um documento e nunca revê o mesmo. O lote **dobra** a cada rodada
(`limite+1`, ×2, ×4, ×8, …, com teto de 200 documentos por ida), então o número
de idas ao banco cresce com o **logaritmo** da quantidade de ocultos: mil ocultos
custam cerca de dez rodadas, não cem. O teto de 200 é de **lote**, não de
varredura — quando o lote enche, a varredura faz outra rodada; ele nunca encerra
a busca e por isso não pode influenciar `truncado`.

Para a varredura continuar, **todo** candidato visto até ali precisa estar oculto
para quem procura — o que exige uma relação de bloqueio com cada um. Na prática a
primeira rodada resolve; para haver uma segunda é preciso que um oculto esteja
entre os primeiros resultados do termo. Uma varredura longa emite `logger.warn`
(observabilidade para a operação), sem mudar a resposta.

**Provas contra o emulador.** No describe `o candidato oculto nao existe, nem no
"truncado"`: um bloqueado responde igual a inexistente; vários bloqueados
respondem igual a inexistente; o bloqueado não rouba vaga; `truncado` conta os
visíveis; bloqueio nos dois sentidos dá a mesma resposta; a ausência de cursor
continua valendo inclusive quando `truncado: true`.

No describe `estresse: centenas de ocultos nao mudam a resposta`: **300 ocultos**
à frente de três legítimos — mais que os 93 (limite 2–3) e os 265 (limite padrão)
que cinco rodadas alcançavam. Prova simultaneamente que os legítimos continuam
preenchendo as vagas, que `truncado` depende só dos visíveis, e que **apagar 150
ocultos ou acrescentar 120 não altera nenhum campo** da resposta (`deepEqual` da
resposta inteira nos três estados).

Os dois describes trazem a contraprova de que os perfis escondidos **existem** e
são achados por um terceiro — sem ela, os testes de equivalência passariam com
uma busca simplesmente quebrada.

### O mecanismo é o canônico

Nenhuma coleção nova de bloqueio, nenhuma segunda regra. A busca lê
`users/{uid}/blocks/{outroUid}` — a fonte da OS de Moderação §8 — e o veredito
vem de `avaliarContato`, a **mesma função** compilada no bundle do domínio.

### A janela do gatilho não é explorável

A faxina `aoBloquearJogador` é assíncrona. Durante a janela, o documento
canônico ainda diz "amigos" — e a busca já não exibe a pessoa, porque lê o
bloqueio na hora. Testes `BLQ-03` (domínio) e
`§8 — o bloqueio some da busca antes de a faxina do gatilho rodar` (emulador).

---

## 8. O achado — `publicProfiles` era listável

A OS §17 manda documentar conflito com o contrato anterior em vez de redesenhar
em silêncio. Este é o único.

**O que havia.** A OS de Identidade Pública concedeu
`allow get, list: if autenticado()` a `publicProfiles`. O comentário da regra
justificava apenas a leitura por ID (`Ranking/Hall → publicId → Ver Perfil`); o
`list` entrou junto e **nunca teve consumidor**: as telas resolvem um publicId
por vez e as Functions usam o Admin SDK, que ignora regras.

**O que ele permitia.** `getDocs(collection('publicProfiles'))` devolvia o
apelido e o publicId de **todos** os jogadores, paginável até o fim da base. Isso
é a "listagem irrestrita de usuários" que a OS de Busca §20 item 4 proíbe — e
existia antes de haver qualquer busca.

**O que foi feito.** `allow get` intacto; `allow list` passou a exigir admin.

**Por que não é regressão do §12.** O que a OS anterior declarou foi um
documento *deliberadamente público*, e ele continua sendo: qualquer autenticado
lê qualquer perfil por ID. O que saiu foi a **varredura**, que nunca fez parte
daquele contrato — nenhuma frase dele descreve listar a coleção, nenhum teste
dele exercitava `list`, e nenhum código a usava. Testes
`BUSCA §12 — a leitura POR ID continua publica` e
`BUSCA §12 — o admin ainda lista`.

**Consequência para quem vier depois.** Uma tela que precise de "vários perfis de
uma vez" resolve por ID (`getAll` no servidor, `getDoc` no cliente) ou chama uma
Function. Não há caminho de cliente que enumere jogadores, e isso é intencional.

---

## 9. Rules

Sem coleção nova, portanto sem bloco `match` novo. A única alteração:

```
match /publicProfiles/{publicId} {
  allow get:  if autenticado();   // inalterado
  allow list: if ehAdmin();       // era: autenticado()
  allow write: if false;          // inalterado
}
```

Garantias que continuam valendo, todas cobertas por teste:

- nenhuma leitura pública de `users/{uid}`;
- `publicIdIndex` (o mapa `publicId → uid`) negado a todo cliente;
- `friendships`, `playerSocial`, `users/{uid}/friends` e
  `users/{uid}/friendRequests` negados até ao dono;
- nenhum cliente escreve `publicId`;
- nenhum cliente escreve `apelidoOrdenacao` — **que é o índice de busca**, e
  poder gravá-lo seria poder aparecer em qualquer consulta;
- nenhum cliente cria amizade diretamente.

---

## 10. Índices

**Um** índice novo. Nenhum existente foi tocado.

| coleção | escopo | campos | consulta que o exige |
|---|---|---|---|
| `publicProfiles` | COLLECTION | `estado` ASC, `apelidoOrdenacao` ASC, `publicId` ASC | `buscarJogadoresPorApelido`, nos **dois** modos |

- `estado` na frente porque é igualdade, e o Firestore exige igualdade antes de
  faixa. Filtrar depois faria o teto de resultados depender de quantas contas
  desativadas casaram com o termo.
- `apelidoOrdenacao` é a faixa (prefixo) ou a segunda igualdade (exato). **Um
  índice serve aos dois modos** — por isso não há um segundo.
- `publicId` desempata. Apelido não é único, e sem o segundo critério a ordem
  entre homônimos seria indefinida entre chamadas; a OS §14 exige resultado
  determinístico.

> **O emulador não cobra índice composto.** A suíte prova que a consulta devolve
> o resultado certo, não que o índice está declarado. A conferência do índice é
> de deploy — e o deploy não faz parte desta OS.

---

## 11. Códigos de erro

Três acrescentados a `ErroSocial`, **no fim do enum**, sem renomear nem remover
nenhum dos quinze anteriores (teste `ERB-02`).

| código | HTTP callable | quando |
|---|---|---|
| `consultaInvalida` | `invalid-argument` | termo não é texto, vazio depois de normalizado, com caractere de controle, ou modo desconhecido |
| `consultaMuitoCurta` | `invalid-argument` | menos de 3 caracteres visíveis |
| `consultaMuitoLonga` | `invalid-argument` | mais de 24 caracteres visíveis |

`invalid-argument`, e não `failed-precondition`: o servidor não está num estado
que impede a operação — o pedido é que não tem forma de pedido, e o cliente não
deve tentar de novo com o mesmo texto.

Os quatro casos de `consultaInvalida` compartilham um código de propósito: a tela
faz a mesma coisa com todos (pedir que a pessoa digite de novo). Qual foi fica no
log do servidor.

**Apelido inexistente não é erro.** Responde `itens: []`. Um `not-found` aqui
contaria com um código o que a lista já conta com um comprimento.

---

## 12. O que a busca custa

Caso comum — uma rodada de varredura resolve, 20 resultados:

| passo | leituras |
|---|---|
| consulta indexada (rodada 1) | 21 documentos (o +1 só decide `truncado`) |
| `publicId → uid` | 21, em um `getAll` |
| bloqueio nos dois sentidos + sanção do pesquisador | 43, em um `getAll` |
| `friendships/{pairKey}` — **só de quem vai aparecer** | 20, em um `getAll` |

Quatro idas ao banco, ~105 leituras. A alternativa ingênua — chamar
`estadoDeContato` por resultado — faria 60 leituras só de bloqueio, um terço
delas relendo o **mesmo** `playerModeration/{observador}`.

A relação de amizade é lida **depois** da varredura, e só dos visíveis: ela
decora o resultado, nunca decide se ele existe. Ler `friendships` de alguém que
vai ser escondido seria trabalho jogado fora — e faria a visibilidade parecer
depender dela.

Cada rodada extra custa uma consulta e dois `getAll`, e só acontece quando o
bloqueio descartou candidatos. Como o lote dobra, o número de rodadas cresce com
o **logaritmo** da quantidade de ocultos à frente dos visíveis; o limite superior
do custo é o tamanho da faixa consultada, e chegar perto dele exige uma relação
de bloqueio com cada candidato do caminho.

Uma busca que não devolve nada custa **uma** consulta: o caminho vazio encerra
antes da leitura das relações.

---

## 13. Segurança — o que está provado

| afirmação | onde |
|---|---|
| UID não sai na resposta | `RES-01`, `RES-02` (domínio); `§3 — o resultado NAO carrega UID` (emulador, compara com os UIDs reais das contas) |
| e-mail, Billing e moderação não saem | `§7 — o perfil PRIVADO nao entra no resultado` semeia `users/{uid}` com e-mail, `vip` e `fichas` e confere a resposta |
| perfil privado não sai | idem — a busca lê `publicProfiles`, nunca `users/{uid}` |
| campos internos do perfil não saem | `os campos INTERNOS do perfil publico nao viajam` (Node puro) |
| cliente não lista todos os usuários | `BUSCA §9 — o cliente NAO VARRE`, `nem uma consulta FILTRADA passa`, `§9 — nao existe rota que devolva todos` |
| cliente não acessa projeções privadas | suíte da OS anterior, inalterada |
| cliente não escolhe `publicId` | suíte da OS anterior, inalterada |
| cliente não escreve o índice derivado | `BUSCA §12 — o cliente nao escreve a chave de busca` |
| bloqueio não é contornável | `BLQ-01` a `BLQ-06`; `§8 —` (três testes de emulador) |
| a ausência não revela quem bloqueou | `BLQ-04`; `§8 — a ausencia e IGUAL nos dois casos` |
| o oculto não altera **nenhum** campo observável | `BLQ-07` a `BLQ-09` (domínio) e os sete testes do describe `o candidato oculto nao existe, nem no "truncado"` (emulador) |
| `truncado` conta visíveis, não brutos | `truncado conta os VISIVEIS, e nao o lote bruto` — provado por mutação: forçar uma rodada só derruba exatamente este teste |
| o oculto não rouba vaga de quem é visível | `o bloqueado NAO ROUBA A VAGA` — provado por mutação: cortar o lote bruto antes do filtro derruba este e mais três |
| a garantia **não tem teto** | os seis testes de `estresse: centenas de ocultos nao mudam a resposta`, com 300 ocultos — provado por mutação: reintroduzir o teto de cinco rodadas derruba `os legitimos preenchem as vagas` e `truncado depende SO dos visiveis` |
| amizade só pelo mecanismo canônico | `§10 — a busca nao e fonte de amizade` |
| resultado determinístico | `RES-04`; `o resultado e DETERMINISTICO entre chamadas` |

---

## 14. Lacunas

| lacuna | consequência hoje | quem resolve |
|---|---|---|
| **Sem limite de taxa por chamador** | varredura sistemática é cara, não impossível — ver seção 6 | infraestrutura genérica de quota (App Check/Cloud Armor), não esta OS |
| **Sem normalização Unicode NFC/NFD** | apelidos visualmente idênticos com composições diferentes não casam entre si | versão futura, se aparecer o caso real |
| **Sem busca por infixo** | "Solitaria" não encontra "Zarabatana Solitaria" | decisão de produto; exigiria estrutura nova |
| **Sem UI** | esta OS entrega backend e contrato | OS de UI social |
| **Índice composto não conferido por teste** | o emulador não cobra índice | deploy |
| **Nenhuma Function foi implantada** | tudo exercitado no emulador; não houve deploy | operação |
| **`estado: "indisponivel"` continua sem quem o escreva** | herdada da OS anterior: o filtro da busca funciona, mas nada marca conta removida | OS de LGPD/exclusão |
