# Arbitragem somente leitura — autoridade das estatísticas do Perfil V1

**Natureza:** arbitragem estritamente somente leitura. Nada foi implementado,
corrigido, composto ou ativado.

**Base auditada:** `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`
@ `6e428e8575e2df4a504148a948305838cf3ff2d4`

**Repositórios lidos:**
`soniaambrosio/buraco-master-vip-app` @ `6e428e8` · `buraco-servidor`
@ `85d0eee` (`claude/credencial-renovavel-motor-railway-v1`)

---

## Veredito

> ## `FAIL — AUTORIDADES CONCORRENTES`

O motivo do veredito, em uma frase: **o mesmo fato físico — uma partida que
acabou no servidor Railway — hoje produz DOIS registros divergentes dos mesmos
oito campos**, com regras diferentes, chave de identidade diferente e disciplinas
de idempotência diferentes. Enquanto uma das duas não for desligada, ligar o
Perfil a "números reais" é escolher, sem arbitragem, qual das duas versões da
vida do jogador é a verdadeira.

O próprio servidor declara o risco, em `server.js:4225`:

> "cortar a economia local para a autoridade do Firestore vai exigir homologação
> e ativação coordenadas, senão o jogador recebe duas vezes: uma pelo cofre daqui
> e outra por quem consumir o envelope."

`FAIL` foi escolhido em vez de `BLOCKED` porque a concorrência **precede** as
ausências: mesmo que toda peça faltante fosse construída amanhã, o sistema
continuaria com dois donos do mesmo número. A arbitragem tem de vir primeiro. As
ausências e as indefinições de produto existem e estão na matriz da seção 7 — são
reais, mas são o segundo problema, não o primeiro.

---

## 1. As duas autoridades concorrentes

### Autoridade A — o cofre local do servidor Node (`contas.js`)

Vive dentro de `server.js` (fábrica `"contas"`, a partir de `server.js:3293`).
É a mais completa das duas, e é a **única das duas que está viva hoje**.

`contaPublica()` (`server.js:3385`) devolve, literalmente, sete dos oito campos
do Perfil:

```
nivel · xp · xpNoNivel · xpProxNivel (= próximo nível)
partidas · vitorias · derrotas · canastras · aproveitamento
```

Tem fórmula de XP fechada e versionada em código (`server.js:3315-3338`):

| constante | valor |
|---|---|
| `XP_VITORIA` | 100 |
| `XP_DERROTA` | 40 |
| `XP_POR_CANASTRA` | 15 |
| `XP_FRACAO_PLACAR` | 0,02 (2% dos pontos da dupla) |
| curva de nível | `xpAcumuladoParaNivel(n) = 50·(n−1)·n` |

Tem até ranking próprio e posição própria (`ranking()` em `server.js:3501`,
`posicaoNoRanking()` em `server.js:3509`), ordenáveis por `xp`, `vitorias` ou
`moedas`.

**Suas cinco propriedades desqualificantes**, todas verificáveis:

1. **Identidade errada.** O cabeçalho de `contas.js` declara: "cada jogador tem
   um `id` estável gerado no aparelho dele (estilo 'continuar como convidado').
   Nada de e-mail/senha aqui". Não é o UID do Firebase, não é o `publicId`
   canônico, e não sobrevive à troca de aparelho.
2. **Persistência errada.** Um `contas.json` num volume do Railway
   (`server.js:3348-3349`), não o Firestore.
3. **Sem idempotência própria.** `registrarPartida` (`server.js:3445`) faz
   `c.partidas += 1`, `c.vitorias += 1`, `c.canastras += canastras` a seco. A
   única proteção contra dupla contagem é a trava **em memória**
   `sala.liquidada` (`server.js:4182`). Não há chave de idempotência persistida,
   então nada distingue um reprocessamento de uma partida nova.
4. **Sem recorte de modalidade.** `registrarPartida` não olha `tipoPartida`. Ela
   conta qualquer partida que o gerenciador liquide.
5. **Empate vira vitória.** `const vencedora = placar.nos >= placar.eles ? "nos"
   : "eles"` (`server.js:3447`). Num empate, o lado `nos` é creditado com
   vitória e o lado `eles` com derrota. A autoridade B tem um contador `empates`
   separado — as duas discordam sobre o que é uma vitória.

**E ela conta canastras que sempre valem zero.** `registrarPartida` lê
`j.canastras || 0` (`server.js:3464`), mas o único chamador, `liquidar`
(`server.js:4203-4209`), monta cada jogador como `{ assento, id, apelido }` — sem
`canastras`. O contador `c.canastras` do cofre é incrementado por zero em toda
partida. **O campo existe, é exibido, e nunca sai de zero.**

### Autoridade B — o pipeline `matches` → `rankingStandings` (Firestore)

É a autoridade correta por desenho, e é a que **não está ligada**.

O caminho completo, e ele é bom:

```
servidor Node  →  envelope de encerramento
               →  outbox durável            (server.js:3606)
               →  [ NINGUÉM ENTREGA ]        ← o corte
               →  registrarEncerramentoPartida  (functions/src/rastreabilidade.ts:125)
               →  matches/{matchId}
               →  aoRegistrarResultadoOficial   (functions-ranking/src/index.ts:158)
               →  rankingStandings/{seasonId|uid}
               →  projetarJogador                (functions-ranking/src/projecao.ts:159)
               →  abrirRanking / paginarRanking / consultarJogadorPorIdPublico
```

`rankingStandings` guarda, por temporada (`functions-ranking/src/firestore.ts:752`
e `:768-776`): `partidasComputadas`, `vitorias`, `derrotas`, `empates`,
`saldoPontos`, `abandonos`, `estadoCompetitivo`, `ligaId`/`ligaNome`.
`rankingPlayers/{uid}` guarda o acumulado vitalício `partidasTotais` e
`pontosTotais` (`functions-ranking/src/firestore.ts:780-791`).

E — este é o achado mais útil de toda a arbitragem — **a projeção para o cliente
já publica quatro dos oito campos**. `JogadorPublicado`
(`functions-ranking/src/projecao.ts:114-131`) tem `partidas`, `vitorias`,
`derrotas` e `aproveitamento`, este último já calculado no servidor com uma casa
decimal (`aproveitamentoDe`, `projecao.ts:154`). Estão na lista branca
`CAMPOS_PUBLICADOS` (`projecao.ts:198-216`) e passam pela varredura de
`CAMPOS_PROIBIDOS` (`projecao.ts:222-233`), que bane `uid`, `userId`, `email`,
`entitlement` e mais seis nomes.

**O corte.** O cabeçalho da outbox, em `server.js:3609`, diz por extenso:

> "Guarda o envelope autoritativo de cada partida encerrada até que alguém o
> entregue. **Nesta versão NINGUÉM entrega**: não há rede aqui, de propósito."

Não existe, em nenhum dos dois repositórios, um chamador de
`registrarEncerramentoPartida`. Portanto `matches/{matchId}` nunca é escrito;
`aoRegistrarResultadoOficial` nunca dispara; `rankingStandings` está vazio; e
`projetarJogador`, que já sabe publicar as estatísticas, nunca tem uma linha para
projetar.

### O quadro da concorrência

| | A — cofre local | B — Firestore |
|---|---|---|
| chave de identidade | id gerado no aparelho | UID Firebase → `publicId` canônico |
| onde vive | `contas.json` (volume Railway) | `rankingStandings` / `rankingPlayers` |
| idempotência | nenhuma (trava em memória) | id de documento determinístico |
| recorte de modalidade | nenhum | `publica_ranqueada` apenas |
| empate | conta como vitória de `nos` | contador `empates` próprio |
| canastras | campo existe, sempre 0 | por dupla, no `matches` |
| XP / nível | fórmula fechada e versionada | **não existe** |
| está ligada? | **sim**, em produção | **não**, transporte cortado |
| quem consome | cliente HTML (`mesa-online.html`) | ninguém ainda |

**O aplicativo Flutter não lê nenhuma das duas.** `OnlineService`
(`app/lib/services/online_service.dart:556-595`) trata exatamente sete tipos de
mensagem — `autenticado`, `authFalhou`, `authExpirou`, `atualizacaoObrigatoria`,
`entrou`, `estado`, `erro`. `resumoFinal`, `conta`, `xp` e `moedas` não estão
entre eles. O cofre do servidor abastece o **cliente HTML**, que é outro front
end. Esta é uma boa notícia: a concorrência ainda não chegou ao Perfil que a OS
quer preencher, e desligá-la agora não quebra nada no Flutter.

---

## 2. As perguntas obrigatórias

### 1. Qual evento autoritativo encerra uma partida oficial?

A chamada `registrarEncerramentoPartida`
(`functions/src/rastreabilidade.ts:125`), que grava `matches/{matchId}` numa
transação única junto de `matches/{id}/events`, `rankingLedger`, `fraudSignals` e
`users/{uid}/matchHistory`. Exige o claim `motorDePartidas` ou `admin`
(`rastreabilidade.ts:47` e `:69-83`) — cliente autenticado comum é recusado com
`permission-denied`.

O produtor do envelope é `montarEnvelopeEncerramento` (`server.js:4013`), chamado
de `liquidar` (`server.js:4182`) e depositado na outbox.

**Estado: o evento existe, é bem desenhado, e não acontece.** Falta o
transporte autenticado Railway → Functions.

### 2. Existe chave idempotente por partida?

**Sim, no caminho Firestore. Não, no cofre local.**

No Firestore, a idempotência é por construção, não por checagem
(`rastreabilidade.ts:116-124`):

```
matches/{matchId}
matches/{matchId}/events/{eventId}
rankingLedger/{matchId|userId|motivo}
fraudSignals/{matchId|tipo|alvos}
users/{uid}/matchHistory/{matchId}
```

A contribuição ao ranking tem chave própria, `chaveDeContribuicao`
(`functions-ranking/src/resultado.ts:478`):
`matchId|seasonId|politicaId|vN` — que é o **id do documento** em
`rankingContributions`, então duas execuções concorrentes disputam a criação do
mesmo documento e o Firestore deixa só uma passar.

Há ainda uma barreira de convergência no nível do banco
(`rastreabilidade.ts:154-174`): se a partida já encerrou, um segundo desfecho
**divergente** é recusado com `failed-precondition`, e um reenvio **idêntico**
responde sucesso sem regravar.

A outbox do servidor também é idempotente, por existência de arquivo
(`server.js:3697`).

O cofre local, não. Ver seção 1, item 3.

### 3. Quais modalidades contam?

O vocabulário canônico é `TipoDePartida`
(`app/lib/rastreabilidade/identidade_partida.dart:67-99`):

| tipo | `alteraRanking` | alimenta rating de temporada |
|---|---|---|
| `publica_ranqueada` | sim | **sim** |
| `torneio` | sim | não (§6 da Política v1) |
| `publica_casual` | não | não |
| `privada` | não | não |
| `treinamento` | não | não |
| `contra_robos` | não | não |

`AMBIENTE_COMPETITIVO` (`functions-ranking/src/competicao.ts:106`) tem **um único
elemento**: `["publica_ranqueada"]`. As duas guardas são aplicadas em série
(`resultado.ts:279-299`).

**E aqui há um problema estrutural, independente de tudo o mais.** O servidor
Node fala outro vocabulário: `TIPOS_DE_PARTIDA = ["publica", "privada",
"simulada"]` (`server.js:3801`). O envelope carrega `tipoPartida: "publica"`
(`server.js:4043`) — que **não distingue casual de ranqueada**. Como
`"publica"` não está em `AMBIENTE_COMPETITIVO`, todo envelope produzido hoje
seria recusado como `fora_do_ambiente_competitivo` se o transporte fosse ligado
sem tradução. O servidor, como está, **não sabe dizer se uma mesa é ranqueada**.

### 4. Treino, Mesa Pública casual e partidas abandonadas contam?

* **Treino / `contra_robos`:** nunca contam para ranking, e a razão está escrita
  em `identidade_partida.dart:85-88` — mesa contra bots que valesse ranking seria
  "a forma mais barata de farmar pontuação que existe". Para **estatística de
  Perfil**, ninguém decidiu.
* **Mesa Pública casual:** não pontua ranking. Para estatística, a Política v1
  (`docs/POLITICA-COMPETITIVA-V1.md:54`) diz que ela "**pode** registrar partida,
  estatística e histórico pessoal". É uma permissão, não uma decisão: não define
  qual contador, com que recorte, nem onde é agregado.
* **Abandonadas:** `EstadoDaPartida.valeu` é `finalizada || abandonada`
  (`registro_partida.dart:222`), então abandono **conta como partida disputada**;
  `cancelada` não. Mas a atribuição de culpa não existe: o campo `abandonos` do
  standing "fica em zero hoje" porque "o registro oficial marca que houve
  abandono, mas não diz QUEM abandonou" (`projecao.ts:65-72`).

### 5. Vitória pertence à dupla ou ao jogador?

**O fato é da dupla; a atribuição ao jogador é derivada, e está resolvida.**

O registro grava `ladoVencedor` (`nos`/`eles`), não um vencedor individual. A
derivação para o jogador é `projetarParaJogador`
(`app/lib/rastreabilidade/historico_e_consulta.dart:182-187`): compara o lado do
participante com `ladoVencedor` e produz `ResultadoDoJogador.vitoria`,
`.derrota` ou `.semEfeito`.

O lado, por sua vez, vem do assento pela lei da mesa — pares são `nos`, ímpares
são `eles` (`registro_partida.dart:145-146`) — e não é parametrizável.

No standing, `vitorias` é incrementado por jogador
(`functions-ranking/src/competicao.ts:345`), com `empates` separado. Portanto
**"342 vitórias" é uma contagem individual de partidas em que a dupla do jogador
venceu** — o que é a leitura correta e precisa estar dito, porque não é a mesma
coisa que "342 vitórias minhas".

### 6. Canastra possui autoria individual ou apenas da dupla?

**Apenas da dupla, e em nenhum lugar do sistema há autoria individual.**

* No motor: `MotorPartida._canastrasLimpas` é um `Map<String,int>` com chaves
  `'nos'` e `'eles'` (`app/lib/motor/motor_partida.dart:80`), somado por dupla a
  cada apuração (`motor_partida.dart:431-432`).
* No desfecho: `LadoDaMesa.canastrasLimpas`, por lado
  (`app/lib/motor/desfecho_partida.dart:494-507`).
* No registro: `PlacarDoLado.canastrasLimpas`, cópia do desfecho, por lado
  (`app/lib/rastreabilidade/registro_partida.dart:263-291`).
* No ranking: `placar[].canastrasLimpas`, por lado
  (`functions-ranking/src/resultado.ts:61-65`).
* **No histórico do jogador: não existe.** `EntradaHistorico`
  (`historico_e_consulta.dart:49-133`) tem `pontosMeuLado` e `pontosOutroLado` e
  **nenhum campo de canastra**.
* **No envelope do servidor: não existe.** `montarEnvelopeEncerramento`
  (`server.js:4013-4058`) carrega `placarFinal: { nos, eles }` — só pontos.
* No cofre local: existe o campo, e ele é sempre incrementado por zero
  (seção 1).

Atribuir a canastra da dupla ao jogador seria **inventar regra**: numa canastra
construída a quatro mãos, creditar 100% aos dois integrantes dobra a contagem
global, e creditar 50% produz meia canastra. Isto é decisão de produto, e não
existe.

### 7. Reconexão e replay podem duplicar estatísticas?

**No caminho Firestore, não. No cofre local, sim.**

Firestore — três barreiras independentes:
1. id de documento determinístico em toda escrita (`rastreabilidade.ts:116-124`);
2. convergência transacional que recusa segundo desfecho divergente e aceita
   reenvio idêntico sem regravar (`rastreabilidade.ts:154-174`);
3. `jaProcessado` como guarda 9 de `decidirProcessamento`
   (`resultado.ts:355-362`), **posicionada antes da política** de propósito, para
   que um retry após troca de regra vire "já lançado" em vez de erro permanente.

Cofre local — a única barreira é `sala.liquidada`, um booleano em memória
(`server.js:4185`). Ela protege o caso normal (mesma sala, mesmo processo). Não
protege replay, reconstrução de sala com o mesmo `partidaId`, nem reprocessamento
administrativo. A assimetria é o risco concreto: num mesmo replay, a outbox
deduplicaria e o cofre contaria de novo.

Reconexão em si não liquida: `liquidar` exige `sala.jogo.encerrada`
(`server.js:4184`).

### 8. Existe armazenamento histórico suficiente para backfill?

**O esquema existe e é adequado. Os dados não existem.**

`users/{uid}/matchHistory/{matchId}` é gravado na mesma transação do
encerramento (`rastreabilidade.ts:205-211`), com id de documento igual ao
`matchId` — reprocessável sem duplicar. É legível pelo próprio dono direto pelas
Rules (`firebase/firestore.rules:216-218`). O conteúdo vem do domínio, via
`projetarParaJogador`, e não é remontado em TypeScript, "para não criar uma
segunda regra de privacidade que divergiria da primeira".

Com ele daria para reconstruir **vitórias, partidas e aproveitamento** de
qualquer recorte de modalidade — `EntradaHistorico` carrega `resultado`, `tipo`
e `modalidade`. **Não daria para reconstruir canastras** (o campo não está lá) nem
XP/nível (não há fórmula aprovada).

Três ressalvas:

1. **A coleção está vazia**, pela mesma razão de tudo o mais: o transporte está
   cortado, e o único escritor é `registrarEncerramentoPartida`.
2. **Ninguém a lê.** Uma varredura nos dois repositórios encontra `matchHistory`
   apenas em `functions/src/rastreabilidade.ts` (que escreve) e nos comentários
   das Rules. Não há agregador, e o aplicativo Flutter não a consulta.
3. O `contas.json` do volume Railway guarda **totais**, não eventos: não dá para
   auditá-lo, reprocessá-lo nem separar modalidade a posteriori. Não serve de
   fonte de backfill.

### 9. Ranking já mantém algum desses totais?

**Sim — três dos oito, e já com contrato de cliente pronto.**

`rankingStandings` mantém `partidasComputadas`, `vitorias`, `derrotas`,
`empates`, `saldoPontos`, `abandonos` (`firestore.ts:768-776`).
`rankingPlayers/{uid}` mantém `partidasTotais` vitalício (`firestore.ts:787`).

E `projetarJogador` (`projecao.ts:159-190`) **já publica** `partidas`,
`vitorias`, `derrotas` e `aproveitamento` pelas callables `abrirRanking`,
`paginarRanking` e `consultarJogadorPorIdPublico`
(`functions-ranking/src/index.ts:419`, `:459`, `:512`).

Duas ressalvas que mudam o significado dos números:

* **Recorte:** só `publica_ranqueada`. Um jogador que só joga Mesa Pública casual
  tem `partidas: 0` — o que é verdade para o campeonato e mentira para o Perfil,
  se o Perfil quiser dizer "quantas partidas você jogou".
* **Janela:** o standing é **por temporada**. Só `rankingPlayers.partidasTotais`
  é vitalício, e ele não tem `vitoriasTotais` par.

### 10. XP e nível possuem fórmula aprovada ou são somente protótipo?

**Não há fórmula aprovada. Há uma fórmula implementada e rodando, nunca
aprovada, no lugar errado — e um leitor órfão no lugar certo.**

* **No Firestore: nada.** Uma varredura por `xp` / `experiencia` em
  `functions*/src/` não retorna nenhuma ocorrência de sistema de progressão.
* **No servidor Node: fórmula completa**, `50·(n−1)·n`, com quatro constantes de
  ganho (`server.js:3315-3338`). Nunca passou por OS de produto.
* **No cliente: dois lugares com o mesmo número inventado.**
  `PerfilService._montar` produz `nivel: demo ? 24 : null`
  (`app/lib/services/perfil_service.dart:143-145`), e `statsDemo` está em `false`
  (`perfil_service.dart:29`) — o Perfil publicável não desenha nada.
  `app/lib/screens/recompensas_screen.dart:27` repete os mesmos `24 / 3240 /
  5000` num objeto local. Essa tela **não é alcançável** a partir da casca de
  produção: `home_de_producao.dart` empurra só `PerfilPage`,
  `ConfiguracoesDeProducao`, `OndeJogarDeProducao`, `MesaScreen` e `LobbyOnline`.
  É prévia, não vitrine — mas é uma segunda cópia do mesmo número inventado, e
  vale saber que ela existe antes que alguém a ligue.

**O leitor órfão.** `montarPerfil` (`functions/src/index.ts:78-117`), usado pela
elegibilidade de torneios, lê `players/{userId}` e extrai `dados.nivel`
(`index.ts:105`) e `dados.conquistas` (`index.ts:111`). A coleção `players/`
**não tem um único escritor** em nenhum dos codebases e **não aparece no
`firestore.rules`** — cai no `allow read, write: if false` do catch-all
(`firestore.rules:1006-1007`). É uma leitura que sempre devolve vazio, e portanto
`nivel: null` e `conquistas: []` permanentes. Não é autoridade; é um resquício.
A ironia está no comentário logo acima, em `index.ts:76`: "um `nivel` copiado
para o documento do jogador seria escrito pelo cliente em algum momento e viraria
porta para autoconceder elegibilidade".

### 11. O título vem do Ranking, de conquista ou de catálogo próprio?

**De nenhum dos três. Não existe autoridade de título.**

* **Ranking:** produz `liga` / `ligaId` (`projecao.ts:101-105`) e rótulos de
  estado (`Em colocacao`, `Em revalidacao`, `projecao.ts:147-151`). Liga é
  patamar, não título. Não há campo de título.
* **Conquistas:** não existem em código neste lineage. Uma varredura por
  `conquista` / `achievement` em `functions*/src/` retorna **uma única
  ocorrência**, que é a leitura órfã de `players/` da pergunta 10. No cliente,
  `_catalogoDemo` (`perfil_service.dart:38-47`) está atrás de `statsDemo=false`,
  e o comentário de `perfil_service.dart:31-36` explica que o catálogo "tudo
  travado" foi retirado porque afirmava que a pessoa não desbloqueou nada, e quem
  sabe isso é o backend de recompensas — que o cliente não lê.
* **Torneios:** `montarPerfil` monta `titulos` (`functions/src/index.ts:113`),
  mas o conteúdo é uma lista de `tournamentId` em que o jogador foi campeão
  (`index.ts:98-100`). São referências de edição, não títulos exibíveis.
* **Hall dos Imortais:** as cinco categorias respondem
  `criterio_nao_definido`, e `consultarHall` (`functions-ranking/src/index.ts:604`)
  documenta por que cada uma não pode ser derivada hoje.

"Rainha da Canastra" (`perfil_service.dart:146`) não vem de lugar nenhum.

### 12. Quais campos podem ser públicos no Perfil visitado?

Há duas portas, com respostas complementares, e ambas já protegem o UID.

**`verPerfilPublico`** (`functions-social/src/index.ts:235`) — apresentação e
relação social. Recebe `publicId`, nunca UID; devolve `perfil` (apelido,
avatar), `relacao`, `acoes` e `amigosDesde`. **Nenhuma estatística.** Conta
removida e conta inexistente respondem igual (`index.ts:253-256`).

**`consultarJogadorPorIdPublico`** (`functions-ranking/src/index.ts:512`) —
dado competitivo. Recebe `publicPlayerId`, valida o formato **antes de tocar o
banco** para fechar enumeração barata (`index.ts:515-519`), e devolve
`projetarJogador(...)`.

Portanto os campos já autorizados a serem públicos são a lista branca
`CAMPOS_PUBLICADOS` (`projecao.ts:198-216`):

```
id · apelido · avatar · liga · ligaId · pontos · posicao · direcao ·
delta · selo · souEu · estado · qualificacaoRestante ·
partidas · vitorias · derrotas · aproveitamento
```

**Quatro dos oito campos do Perfil já estão nessa lista.** Canastras, nível, XP e
título não estão — e para eles a decisão de publicidade ainda não foi tomada,
porque o dado não existe.

A disciplina que sustenta isso merece registro: é **lista branca, não lista
negra** (`projecao.ts:14-19`), então um campo novo no standing não vaza por
omissão; e `CAMPOS_PROIBIDOS` (`projecao.ts:222-233`) bane `uid`, `userId`,
`email`, `token`, `deviceId`, `purchaseToken`, `ip`, `denuncianteUid`, `sancao`
e `entitlement`, com varredura recursiva `acharCampoProibido` exercida em teste.

### 13. Existe política para exclusão de conta e anonimização?

**Não nesta base.** Uma varredura por `excluirConta`, `deleteAccount` e
`anonimiza` em `functions*/src/`, `app/lib` e `docs/` desta árvore não retorna
nada. Não há documento de retenção em `docs/`.

O que **existe** e é relevante para o desenho futuro:

* `verPerfilPublico` já trata conta removida — o domínio tem
  `recusaDeConsultaPublica` com estado, e a resposta é idêntica à de conta
  inexistente (`functions-social/src/index.ts:245-256`).
* As projeções já saem por `publicPlayerId`, nunca por UID, o que torna a
  anonimização de `rankingStandings` uma operação sobre `publicProfiles` em vez
  de uma varredura no ranking.
* `matches/{matchId}` é imutável em estado terminal por construção
  (`registro_partida.dart:18-22`) — o que é bom para auditoria e é exatamente a
  tensão que uma política de exclusão precisa resolver explicitamente.

**Consequência prática:** qualquer OS que passe a exibir estatística real no
Perfil público cria dado pessoal agregado e publicável **antes** de existir
política de exclusão. Isto precisa ser sequenciado, não descoberto depois.

### 14. O cliente possui algum caminho capaz de incrementar esses números?

**Não. Provado por três caminhos independentes.**

1. **Rules.** `matches` é `allow read: if ehAdmin(); allow write: if false`
   (`firestore.rules:500-502`) — o cliente não escreve **nem lê**.
   `rankingStandings` e `rankingPlayers` são `allow read: if false; allow write:
   if false` (`firestore.rules:908-909` e `:924-925`).
   `users/{uid}/matchHistory` é leitura do dono e `create, update, delete: if
   false` (`firestore.rules:216-218`). O catch-all final nega tudo o mais
   (`firestore.rules:1006-1007`).
2. **Claim.** `registrarEncerramentoPartida` exige `motorDePartidas` ou `admin`
   (`rastreabilidade.ts:69-83`). Um cliente autenticado comum recebe
   `permission-denied` com a mensagem "somente a autoridade da partida registra
   encerramento".
3. **Código do aplicativo.** Uma varredura em `app/lib` por `httpsCallable`
   encontra **uma única** chamada: `claimPioneerKit`
   (`app/lib/colecoes/colecao_firebase.dart:120`). Não há `.set(`, `.update(`
   nem `FieldValue.increment` contra nenhuma coleção de estatística.

O único caminho pelo qual o aplicativo hoje influencia contador é indireto e não
é do Flutter: jogar uma partida faz o **servidor** liquidar no cofre local — e o
Flutter, como visto, nem lê o resultado.

---

## 3. Provas negativas

A OS pede demonstração de que nenhuma proposta futura dependerá de seis coisas.
As seis, com a evidência:

**1. Contador incrementado pelo Flutter.** Impossível pelas Rules e pelo claim
(pergunta 14). O aplicativo não tem uma linha de escrita. Qualquer proposta que
precisasse disso teria de **abrir** uma porta que hoje está fechada em três
camadas, e isso seria uma edição visível em `firestore.rules`.

**2. Texto visual da mesa.** Os contadores nascem do estado do motor, não da
tela: `MotorPartida._canastrasLimpas` soma o que `Jogo.canastrasLimpasNaRodada`
apura (`motor_partida.dart:78-80`, `:431-432`), e `capturarDesfecho` copia o
placar de `jogo.placar` (`desfecho_partida.dart:494-506`). `RegistroDePartida`
declara não calcular placar nem decidir vencedor — "copia de
`DesfechoCanonicoPartida`" (`registro_partida.dart:12-16`).

**3. Posição inferida pelo cliente.** `posicao` vem do standing e é escrita pela
apuração; o processamento de partida **não a toca**, e o comentário diz por quê:
recalculá-la ali exigiria "saber quantos jogadores estão acima deste — a leitura
integral que a seção 19 proíbe" (`firestore.ts:753-756`). O cliente recebe
`posicao` já resolvida, com `POSICAO_NAO_APURADA = 0` como valor explícito de
"ainda não apurada" (`projecao.ts:134-140`). No cliente, `EstadoRanking` tem
quatro fases e sabe dizer "não sei" por dentro
(`app/lib/screens/perfil_screen.dart:117-129`) — foi o que eliminou o
Bronze/posição-zero inventados.

**4. UID exposto no Perfil público.** Garantido em três níveis: a projeção é
lista branca e devolve `publicPlayerId` (`projecao.ts:85-87`); `uid` está em
`CAMPOS_PROIBIDOS` com varredura recursiva (`projecao.ts:222-257`); e
`souEu` é decidido **dentro** de `projetarJogador`, comparando uids no servidor —
"a comparação acontece nesta linha, e em nenhuma outra do sistema"
(`projecao.ts:179`). O `verPerfilPublico` opera só sobre `publicId`.

**5. Eventos sem idempotência.** Toda escrita do caminho Firestore tem id de
documento determinístico (`rastreabilidade.ts:116-124`), a contribuição tem
`matchId|seasonId|politicaId|vN` (`resultado.ts:478-485`), e há convergência
transacional contra desfecho divergente (`rastreabilidade.ts:154-174`).
**A prova negativa falha para o cofre local**, que não tem nenhuma dessas coisas
— e é por isso que ele precisa ser desligado, não integrado.

**6. Dados de Treino misturados aos oficiais.** No caminho Firestore, a separação
é dupla e em série: `alteraRanking` no domínio Dart
(`identidade_partida.dart:98-99`) e `AMBIENTE_COMPETITIVO` no backend
(`competicao.ts:106`), com `resultado.ts:279-299` aplicando as duas. Há ainda a
guarda de **natureza imutável** (`resultado.ts:304-312`): uma partida observada
como `publica_casual` que depois diga `publica_ranqueada` é recusada com
`natureza_alterada`, fechando os dois sentidos da fraude. E
`IdentidadePartida.cunhada` recusa partida que pontue com identidade de origem
local (`identidade_partida.dart:221-229`) — "uma partida que pontua e cuja
identidade nasceu no próprio aparelho é a definição de pontuação forjável".
**A prova negativa falha para o cofre local**, que não filtra modalidade
nenhuma.

**Conclusão das provas negativas:** as seis se sustentam integralmente para o
caminho Firestore, e **quatro das seis falham para o cofre local do servidor**.
Isto é a fundamentação técnica do veredito `FAIL`: as duas autoridades não são
igualmente boas com pesos diferentes — uma delas viola por construção as
garantias que a outra prova.

---

## 4. Matriz campo por campo

| Campo | Autoridade existe? | Onde | Contrato de cliente | Bloqueio |
|---|---|---|---|---|
| **Vitórias** | Sim (B) | `rankingStandings.vitorias` | `JogadorPublicado.vitorias` ✅ | transporte cortado · recorte só ranqueada · janela por temporada |
| **Partidas** | Sim (B) | `rankingStandings.partidasComputadas` · `rankingPlayers.partidasTotais` | `JogadorPublicado.partidas` ✅ | idem |
| **Aproveitamento** | Sim (B) | derivado no servidor, `aproveitamentoDe()` | `JogadorPublicado.aproveitamento` ✅ | idem (deriva dos dois acima) |
| **Canastras** | **Não** | por dupla em `matches.placar[]`; ausente no envelope e no `matchHistory` | ✗ | sem produtor · sem autoria individual definida |
| **Nível** | **Concorrente** | fórmula viva no servidor Node; leitor órfão `players/{uid}.nivel` | ✗ | fórmula nunca aprovada · autoridade no lugar errado |
| **XP** | **Concorrente** | `ECON` + curva `50·(n−1)·n` (`server.js:3315-3338`) | ✗ | idem |
| **Próximo nível** | **Concorrente** | `progressoDeXp()` (`server.js:3334`) | ✗ | idem (derivado do XP) |
| **Título** | **Não** | nenhuma | ✗ | sem catálogo, sem regra de concessão, sem produtor |

**Leitura da matriz:** três campos estão a um transporte e uma decisão de recorte
de distância. Um campo (canastras) precisa de decisão de produto **e** de
produtor. Três campos (nível/XP/próximo nível) precisam de arbitragem antes de
qualquer construção. Um campo (título) não tem nada.

---

## 5. A menor sequência de OS

Sete OSs, na ordem em que se destravam. Nenhuma delas foi iniciada.

### OS-1 — Arbitragem e desligamento do cofre local `[FAIL → resolvido]`

**Precede tudo.** Decidir formalmente que a autoridade é o Firestore e que o
cofre local (`contas.js`) deixa de ser fonte de estatística, nível, XP e ranking.
Definir o destino de `contas.json` (descartar / arquivar / migrar), sabendo que
seu id não é o UID e que ele guarda totais sem eventos — ou seja, **não é
migrável com fidelidade**. Definir também o que acontece com o cliente HTML, que
hoje é o único consumidor.

*Risco de pular:* o próprio `server.js:4225` o nomeia — pagamento e contagem em
dobro.

### OS-2 — Vocabulário de modalidade no servidor

Fazer o servidor Node falar `TipoDePartida` canônico. Hoje ele só sabe
`publica | privada | simulada` (`server.js:3801`) e o envelope não distingue
casual de ranqueada (`server.js:4043`). Sem isto, **todo envelope entregue seria
recusado** como `fora_do_ambiente_competitivo`. Inclui decidir onde a mesa nasce
ranqueada (a Política v1 diz que é decisão de abertura de mesa, fora do codebase
competitivo).

### OS-3 — Semântica de produto das estatísticas do Perfil `[decisão da Sônia]`

Nada aqui é técnico. Seis perguntas, e cada uma muda o schema:

1. "Partidas" no Perfil é **vitalício** ou **da temporada**?
2. Conta **todas as modalidades** ou só as ranqueadas? (Hoje só existe a segunda,
   e um jogador de Mesa Pública casual veria `0`.)
3. Treino e `contra_robos` entram na estatística pessoal?
4. Partida abandonada conta como partida? (O domínio já diz que sim —
   `EstadoDaPartida.valeu` — mas o Perfil pode querer outra coisa.)
5. Empate: entra no aproveitamento como meia vitória, como não-vitória, ou vira
   um terceiro número exibido? (O standing já tem `empates` separado.)
6. Canastra: é da dupla, e o Perfil exibe "canastras da minha dupla"? Ou o
   produto quer autoria individual — e aí é preciso definir a regra de rateio, que
   **não existe em lugar nenhum** e não pode ser inventada por código.

### OS-4 — Transporte autenticado Railway → Functions

Ligar a outbox (`server.js:3606`) à chamada `registrarEncerramentoPartida`, com
o claim `motorDePartidas`, retentativa, e uso dos estados que a outbox já reservou
(`pendente` / `entregue` / `falhou`). A credencial renovável já existe no
servidor (`buraco-servidor@85d0eee`). Inclui a **tradução do envelope** para
`RegistroDePartida.toJson()`: hoje o envelope usa `partidaId`, `placarFinal`,
`duplaVencedora` e `participantes[{assento,uid,dupla,tipo}]`, e o consumidor
espera `matchId`, `placar[]`, `ladoVencedor` e
`participantes[{classe,userId,lado}]`.

*Depende de OS-1 (senão duplica) e OS-2 (senão tudo é recusado).*

### OS-5 — Schema de estatística vitalícia + idempotência

Só faz sentido depois da OS-3, que diz o que contar. Provavelmente uma projeção
por jogador alimentada pelo mesmo gatilho de `matches`, com chave de idempotência
no padrão que o codebase já usa (`matchId|uid|escopo` como **id de documento**,
nunca `increment` sem chave). Definir o recorte por modalidade como **campo do
schema**, não como filtro de leitura, para que mudar a política depois não
reescreva a história.

### OS-6 — Backfill

Só depois que houver dado. `users/{uid}/matchHistory` é a fonte certa — id de
documento é o `matchId`, então reprocessar não duplica — mas **não cobre
canastras** e a coleção está vazia hoje. Na prática, "backfill" aqui significa
"reprocessar o que a OS-4 passar a acumular", não "recuperar o passado": o
passado só existe no `contas.json`, em forma de totais não auditáveis.

### OS-7 — Leitor do Perfil

A menor das sete, e é a única que toca `PerfilService`. Trocar o corpo de
`carregar()` (`app/lib/services/perfil_service.dart:88-118`) pela leitura real,
**sem mudar a assinatura nem o visual** — a Fase 2 que o arquivo já anuncia em
`perfil_service.dart:12-13`. Os tipos anuláveis (`PerfilStats?`, `int? nivel`)
já estão certos e não precisam mudar: nulo continua sendo "não há fonte", e a
tela continua não desenhando o que não tem.

Para vitórias / partidas / aproveitamento, o contrato de servidor **já existe** e
não precisa de campo novo: `consultarJogadorPorIdPublico` já devolve os três. O
que falta no cliente é parseá-los — hoje `EstadoRanking`
(`app/lib/ranking/estado_ranking.dart:106-128`) carrega só liga, posição e
temporada.

### Fora de sequência, e precisa entrar em algum lugar

* **Política de exclusão de conta e anonimização** (pergunta 13). Não existe
  nesta base. Precisa preceder a **publicação** de estatística no Perfil
  visitado, não sucedê-la.
* **`players/{uid}`**, o leitor órfão de `functions/src/index.ts:78-117`. Ou
  ganha produtor, ou some. Enquanto estiver lá, é uma quarta resposta latente
  para "qual é o nível deste jogador".
* **Nível/XP/título como produto.** Nenhuma das sete OSs os resolve, porque não
  são problema de engenharia: não há fórmula aprovada, não há catálogo de
  títulos, não há regra de concessão. Até que existam, o certo é o que o Perfil
  já faz — não desenhar.

---

## 6. O que o Perfil faz hoje, e por que está certo

Vale registrar, porque a arbitragem poderia ser lida como uma lista de faltas.

`PerfilService.statsDemo` é `false` (`perfil_service.dart:29`), e com isso todos
os oito campos chegam **nulos**, não zerados. A tela responde não desenhando o
elemento (`perfil_screen.dart:558-560` para o nível, `:811-813` para a barra de
XP). O raciocínio está escrito em `perfil_screen.dart:101-105`:

> "`nivel: 1`, `stats: 0/0/0/0` e oito troféus apagados pareciam modéstia, e são
> o contrário: um zero desenhado é uma AFIRMAÇÃO. Diz que a pessoa jogou e não
> ganhou, que foi avaliada e ficou na base. Ninguém a avaliou."

Esta arbitragem confirma a premissa: **ninguém a avaliou**. Não há dado. O Perfil
publicável está correto exatamente por não inventar, e deve continuar assim até
que a OS-1 arbitre e a OS-4 ligue o cano.

Os números `24 / 3240 / 5000 / 342 / 1204 / 89 / 68%` e "Rainha da Canastra"
existem em dois lugares — `PerfilVM.mock` (`perfil_screen.dart:197-214`) e o
caminho `demo` de `PerfilService._montar` (`perfil_service.dart:143-181`) —, e
ambos estão atrás de chaves desligadas. Um terceiro lugar, `recompensas_screen.dart:27`,
repete `24 / 3240 / 5000` sem chave nenhuma, e só não aparece porque a tela não
é alcançável pela casca de produção.

---

## 7. Escopo e limites desta arbitragem

**O que foi lido:** `app/lib/` (Perfil, motor, rastreabilidade, ranking, casca,
serviços), `functions/`, `functions-ranking/`, `functions-social/`,
`firebase/firestore.rules`, `docs/`, e `server.js` do `buraco-servidor` @
`85d0eee`.

**O que NÃO foi feito, por ser somente leitura:** nenhum teste executado, nenhum
emulador iniciado, nenhuma leitura do Firestore de produção, nenhuma escrita,
nenhum deploy. As afirmações sobre coleções vazias são **inferências a partir da
ausência de escritor no código**, não observações do banco — e a inferência é
forte, porque `registrarEncerramentoPartida` é a única porta e ninguém a chama.

**O que não foi auditado:** `functions-billing`, `functions-moderacao` e o
domínio de torneios além do ponto em que tocam `players/` e `tournamentHistory`.
Nenhum deles é candidato a autoridade dos oito campos.

**Ramos fora desta base:** memória do projeto registra exclusão de conta e
conquistas entregues em outras linhagens. Elas **não estão contidas em
`6e428e8`** e por isso não contam como autoridade existente para esta base. Se a
Sônia quiser, uma arbitragem de contenção pode dizer se e como elas entram — mas
seria outra OS.

---

*Laudo emitido em 2026-08-17. Código, testes e configuração intocados; a única
alteração desta branch é este arquivo.*
