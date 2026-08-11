# Enforcement de visão de espectador no servidor autoritativo

**OS:** P0 — segurança / sigilo de informação de partida.
**Contrato:** `app/lib/motor/visao_espectador.dart` (`VisaoEspectador.de` /
`VisaoEspectador.segredos`), aprovado na OS de Moderação e **não redesenhado aqui**.

---

## 1. Onde o servidor realmente mora

A autoridade da partida **não está neste repositório**. Ela é um bundle Node
puro, sem dependências, servido por WebSocket:

| | |
|---|---|
| Repositório | `github.com/soniaambrosio/buraco-servidor` |
| Arquivo | `server.js` (arquivo único, ~4.000 linhas) |
| Base desta OS | `1828d42` (`main`) |
| Commit do enforcement | `3c8b07e`, branch `enforcement/visao-espectador` |
| Execução no Railway | `npm start` → `node server.js` (`package.json`) |
| Endpoint | `wss://buraco-servidor-production.up.railway.app` |

O patch aplicado está versionado aqui em
[`servidor/SERVIDOR-ESPECTADOR.patch`](../servidor/SERVIDOR-ESPECTADOR.patch),
no mesmo regime dos `SERVIDOR-CRIT*.diff` da auditoria C8.

### A fonte do bundle continua ausente

O cabeçalho do arquivo diz `GERADO por cliente/build_server_bundle.js — NÃO
EDITAR À MÃO`. Essa pasta `cliente/` **não existe em nenhum repositório
disponível**, e foi reconferido nesta OS: o `buraco-servidor.zip` versionado ao
lado do bundle contém apenas `server.js` e `package.json` — não a fonte.

É exatamente o caso da §24 da OS. O bundle foi corrigido diretamente, como já
havia sido feito (com autorização) para as divergências CRIT-01/02/03. Todos os
trechos novos estão marcados com `// [PATCH ESPECTADOR]` e a exceção está
declarada no cabeçalho do arquivo. **Se a pasta `cliente/` reaparecer, estas
mudanças precisam ser retroportadas para a fonte e o bundle regerado.**

O bundle preserva as fronteiras de módulo (`__fabricas["jogo"]`,
`["salas"]`, `["servidor"]`…), então a alteração ficou contida por módulo, e não
espalhada por um arquivo achatado.

---

## 2. Como o servidor distingue jogador de espectador

O papel sai de **um lugar só**: `conexoes[id].assento`, no módulo
`servidor/servidor.js`.

```js
function papelDe(c) {
  if (!c || c.codigo == null) return "nenhum";
  return Number.isInteger(c.assento) ? "jogador" : "espectador";
}
```

`c.assento` é escrito **exclusivamente** com o que `ger.criarMesa` /
`ger.entrarMesa` *devolvem* — isto é, com o assento que o gerenciador de salas
concedeu. Nenhum caminho do protocolo copia assento de dentro de `msg`.

A consequência é a propriedade que a OS pede: **não existe campo de payload
capaz de promover uma conexão**, porque `papelDe` não lê `msg`. Mandar
`souEspectador:false`, `viewerUid`, `playerUid`, `seat`, `assento`, `papel`,
`role`, `modo`, `debug`, `owner` — ou o que se inventar amanhã — não muda nada.

`papelDe` também **não consulta `jogadorId`**, de propósito: identidade alegada
não pode virar autorização nem por acidente (ver a ressalva na §7 abaixo).

---

## 3. Porta única de serialização

Ninguém fora de `salas.visaoPara` monta payload de estado:

```js
function visaoPara({ codigo, papel, assento } = {}) {
  if (papel === "jogador" && Number.isInteger(assento)) return visao(codigo, assento);
  if (papel === "espectador") return visaoEspectador(codigo);
  return { erro: "sem acesso a esta mesa" };   // fail-closed
}
```

Ela recebe o papel **já decidido pelo servidor** e delega para serializadores
separados, que não compartilham objeto:

- `visao(codigo, assento)` — visão de assento, **inalterada** nesta OS;
- `visaoEspectador(codigo)` → `J.visaoDoEspectador(jogo)`.

### Lista de permissão, não remoção de campos

`visaoDoEspectador` **constrói** o recorte público do zero. Não é
`visaoDoAssento` com campos deletados — e isso é a diferença que importa:

> Um campo secreto novo acrescentado ao assento não vaza por descuido: ele
> simplesmente **não existe** nesta função. Num builder compartilhado com um
> `if (espectador)`, o padrão se inverteria — o campo novo nasceria visível e
> alguém teria que lembrar de escondê-lo. Aqui, esquecer é omitir; lá, esquecer
> seria expor.

É a mesma justificativa que já estava escrita em `visao_espectador.dart`, e o
teste **ESPEC-10** prova que ela vale: o teste acrescenta `segredoNovoDoMotor`,
`antiCheat` e `segredoDoAssento` ao modelo e a visão pública continua limpa.

Tudo também é **cópia**. `visaoDoAssento` devolve referências vivas
(`suaMao: jogo.maos[assento]`, `jogosDupla: jogo.jogosDupla`); a visão pública
não deixa nenhum objeto mutável do jogo atravessar a fronteira.

### Tripwire

Antes de devolver, `visaoEspectador` varre o próprio payload contra
`segredosDoEspectador(jogo)`. Se um id secreto aparecer, o payload **não sai**:
falha fechada e registra só a **contagem** — nunca o id, que é o segredo.

A lista de permissão é a garantia; o tripwire é a segunda tranca.

---

## 4. O que quem assiste recebe

**Recebe:** identidade pública (apelido, tipo, dupla, avatar), assento, vez,
`jaComprou`, placar das duas duplas, vulnerabilidade e mínimo de abertura,
topo do lixo (e o lixo inteiro **só no ABERTO**, onde ele é público por regra),
jogos baixados, contagem de cartas por assento, `monteQtd`, `mortosQtd`,
`mortosTamanhos`, `mortoPego`, status da rodada/partida e `pontosRodada`
(agregados numéricos: total, bônus, desconto de mão, contadores de canastra).

**Não recebe:** conteúdo de mão nenhuma, ids do monte, ids dos mortos, ordem de
cartas em mão, `precisaUsarTopo`, `suaMao`, `suaVez`, `ehVoce`, estrutura ou
decisão de bot, seeds, dados de carteira.

Duas escolhas que merecem registro:

- **Contagem não é vazamento.** Quantas cartas cada um tem é o que qualquer
  pessoa em volta da mesa real conta com os olhos — mesmo critério do assento.
- **A obrigação do topo vira fato, não id.** Que alguém comprou o lixo e está
  devendo o topo é público (todo mundo viu). *Qual* é a carta, não: ela está na
  mão de quem comprou. O espectador recebe `obrigacaoTopoPendente: true`; o
  campo `precisaUsarTopo` não existe no recorte dele.

---

## 5. Rotas e eventos protegidos

O servidor **não tem REST de partida**: o HTTP só serve `/health` e
`/avatar/<id>`. Todo estado de mesa trafega por WebSocket, e por um único
caminho — `broadcastSala`, que recalcula o papel **a cada envio**:

```js
function broadcastSala(codigo) {
  for (const cid in conexoes) {
    const c = conexoes[cid];
    if (c.codigo !== codigo) continue;
    c.enviar({ tipo: "estado", visao: visaoDaConexao(c) });
  }
}
```

Como é o mesmo `papelDe` do snapshot inicial, **não existe evento incremental
que escape**: compra, descarte, batida, morto, nova rodada, encerramento e
ressincronização passam todos por aqui. A prova está na §8 da suíte, que roda
uma partida inteira e confere **cada payload no instante do envio**.

Ações foram fechadas ao espectador antes de chegarem ao motor
(`iniciarPartida`, `jogada`, `afkBot`, `afkVoltar`), e `sair` não mexe mais na
lista de assentos quando quem sai não tem assento.

O evento `fim` foi separado: quem jogou recebe `resumo` (moedas, XP, nível);
quem assiste recebe **só o placar** — carteira não é estado de mesa.

---

## 6. Reconexão

A reconexão **não é elevação de privilégio**. O papel é recalculado do zero a
cada entrada, a partir do estado do servidor: token velho, versão de estado
antiga ou `assento` guardado no cliente não devolvem nada.

Quem não ocupa assento naquela partida continua espectador — e o caminho de
sentar de novo segue fechado pela regra da mesa (`a partida já começou`).

> **Fora do escopo, e registrado:** este servidor **não tem retomada de
> assento**. Quem cai tem o assento convertido em bot (`sair`), e não há como
> reassumi-lo. Mudar isso é alteração funcional de reconexão, que a §13 da OS
> proíbe. O que esta OS fecha é a *autorização* da reconexão, não o recurso.

---

## 7. Ressalva importante: o transporte não autentica

**Este é um P0 separado, anterior a esta OS, e não foi resolvido por ela.**

O upgrade WebSocket não valida token nenhum, e a identidade vem do próprio
cliente:

```js
c.jogadorId = msg.jogadorId || c.jogadorId || null;
```

Ou seja: `jogadorId` é o que o cliente **disse** que é. A §5 da OS pede que a
identidade efetiva venha de "contexto autenticado" — **esse contexto não existe
neste servidor**.

Isso **não abre a visão de espectador**, e vale entender por quê: o sigilo
depende de *assento concedido*, não de identidade alegada. Alguém que minta o
`jogadorId` e peça para assistir continua sem assento, e portanto continua
espectador. Foi para preservar essa separação que `papelDe` ignora `jogadorId`.

O que a falta de autenticação afeta é **conta e carteira** — alguém pode
reivindicar o `jogadorId` de outra pessoa ao entrar numa mesa e jogar/pontuar
como ela. Fechar isso exige validar um token (Firebase Auth já é o login do
app) no handshake, e é trabalho de outra OS.

---

## 8. Testes

`npm test` no repositório do servidor — **38 testes, 38 verdes, 0 skips**.
Não havia suíte nenhuma nesse repositório antes desta OS.

| Suíte | Testes | Cobre |
|---|---|---|
| `test/espectador.test.js` | 23 | P0-01/02/03, ESPEC-01..10, prova estrutural, §21 |
| `test/regressao.test.js` | 14 | REG-01..13 (§18) |
| `test/ws.test.js` | 1 | a fronteira no transporte WebSocket real (§10) |

### Os três casos P0

| Caso | Teste | Resultado |
|---|---|---|
| **P0-01** endpoint direto | `P0-01: nenhuma mensagem do protocolo devolve visão de assento ao espectador` | **PASS** |
| **P0-02** UID de terceiro | `P0-02: reivindicar UID e assento de participante real não eleva acesso` | **PASS** |
| **P0-03** parâmetro adulterado | `P0-03: nenhum parâmetro de payload muda o nível de acesso` | **PASS** |

### Prova estrutural (§8)

A partida de teste carimba ids reconhecíveis (`SEGREDO-MAO2-7`, `SEGREDO-MONTE-13`,
`SEGREDO-MORTO0-4`…) em **tudo** o que é secreto, e a varredura percorre chaves,
strings, listas e objetos aninhados **em qualquer profundidade** — inclusive
segredo usado como *chave* e segredo *embutido em texto*. Não se procura por
nomes de campo conhecidos como `mao`: procura-se pelos **ids**.

Um detalhe que mudou a forma do teste: varrer o histórico no fim **mentiria**,
porque uma carta secreta legitimamente deixa de ser secreta ao ir para o lixo ou
para um jogo baixado. O invariante correto é pontual — no instante em que o
payload sai, nada que é secreto *naquele momento* pode estar dentro dele. É o
que o "espectador vigiado" faz, ao longo de uma partida inteira até o
encerramento.

### Testes que falham se a fronteira for afrouxada (§21)

Existem e são explícitos: acrescentar `mao` ao recorte, devolver snapshot de
jogador para espectador, reaproveitar o objeto do assento "limpando" campos
conhecidos, compartilhar objeto mutável com o jogo, e passar a confiar em
`seat`/`viewerUid` — cada um tem um teste que quebra alto.

### Mensagens de erro (§12)

Auditadas as duas pontas:

- **Para o espectador**, a recusa é genérica e sempre a mesma
  (`"você está assistindo a esta mesa"`), emitida **antes** do motor — que
  recusaria citando a carta. `ESPEC-09` prova que nenhum id chutado volta no
  texto.
- **Para o jogador**, as únicas mensagens que citam id (`"carta X não está na
  sua mão"`) apenas **ecoam o id que ele mesmo mandou**, e só sobre a própria
  mão — não servem de oráculo sobre mão alheia.
- `cartaTxt` (que formata carta legível) aparece **só** em `sala.log`, que
  nunca é transmitido.

---

## 9. Regressão

`REG-01..13` cobrem início de partida, compra, descarte, turno (fora da vez,
compra dupla, descarte sem compra), morto indireto, batida final, batida
ilegal, nova rodada preservando placar, queda de jogador, idempotência de
liquidação e do evento `fim`, finalização com carteira, convivência
jogador × espectador na mesma mesa, e serialização de jogadas concorrentes.

`REG-11` congela o **contrato da visão de assento**: os 23 campos, conferidos
um a um contra a lista anterior a esta OS. Se alguém acrescentar ou remover
campo do recorte do jogador, o teste acusa.

Sobre concorrência: o bundle trata uma mensagem por vez no laço de eventos do
Node, sem I/O no meio do despacho — duas jogadas que chegam juntas são
serializadas. Não há trava a testar; o que se prova é que a segunda enxerga o
efeito da primeira.

---

## 10. O que **não** foi tocado

Regras do Buraco, pontuação, vulnerabilidade, compra, descarte, morto, batida,
canastras, turno, motor de bot, ranking, torneios, matchmaking, Billing,
assinatura, entitlement, economia, fichas, loja, inventário, Kit Pioneiros e a
OS de Moderação (que segue fechada).

Os hunks do diff ficam **fora da faixa de regras** do bundle: nada entre as
linhas 36–1799 (carta/canastra/bot) e 1801–2275 (jogadas/pontuação) mudou.

Também fora, por decisão da OS: **bloqueados na mesma mesa** (é do matchmaking).

A única alteração de comportamento fora do sigilo é a fronteira de teste no fim
do arquivo — `node server.js` continua subindo o servidor exatamente como
antes; `require()` do arquivo (que só os testes fazem) não abre porta e expõe o
registro de módulos. Sem ela, a suíte não teria como rodar.
