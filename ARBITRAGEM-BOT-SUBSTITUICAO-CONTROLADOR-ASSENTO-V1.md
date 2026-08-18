# OS 6 — ARBITRAGEM CANÔNICA DO BOT DE SUBSTITUIÇÃO ONLINE E CONTROLADOR DE ASSENTO V1

**Veredito: PASS — ARQUITETURA CANÔNICA DO BOT DE SUBSTITUIÇÃO ONLINE E CONTROLADOR DE ASSENTO DEFINIDA**

Arbitragem e desenho executável. Zero código de produção, zero port, zero
controlador implementado, zero deploy, zero merge, zero PR, zero alteração de
pesos. Nenhum arquivo fora deste laudo foi tocado.

---

## 0. Correção da premissa da OS 5 (ler antes de tudo)

A OS 5 concluiu que **não existe assunção de assento por bot**. Isso é
**verdadeiro para o caminho local** (`app/lib/mesa.dart`) e **falso para a
partida online**.

Na autoridade online (`buraco-servidor`, `server.js` em `c8ab95c`) o takeover
existe, está commitado e está **testado**:

```
server.js:4493  function sair({ codigo, assento })
server.js:4501    sala.jogo.assentos[assento].tipo = "bot";
server.js:4503    avancarBots(sala);   // "se era a vez dele, o bot assume"
server.js:5536  function desconectar(id)  →  ger.sair({ codigo, assento })
```

```
test/regressao.test.js       REG-08: "queda de jogador entrega o assento ao bot
                                      (comportamento preservado)"
test/regressao_auth.test.js  "afkBot entrega o assento ao servidor e afkVoltar devolve"
```

E existe **política de retorno**, também commitada: as mensagens `afkBot` /
`afkVoltar` (`server.js:5700` e `server.js:5712`) viram o assento para `"bot"` e
de volta para `"humano"`.

**O que de fato não existe é o produtor no cliente.** Em `d3effdc`,
`app/lib/services/online_service.dart` fala 11 tipos de mensagem e **nenhum**
deles é `afkBot` ou `afkVoltar` (`git grep afkBot d3effdc -- app/lib` = 0
ocorrências).

Consequência: o desenho pedido por esta OS **não parte do zero**. Ele parte de
um mecanismo que já roda em produção, sem controle do cliente e com uma política
de retorno quebrada — que é um problema pior do que a ausência, porque hoje
**ninguém sabe que ele está lá**.

---

## 1. Gate Zero

### 1.1 Refs resolvidas remotamente

**App — `soniaambrosio/buraco-master-vip-app`** (`git ls-remote origin`):

| ref | SHA |
|---|---|
| `claude/proveniencia-descartes-v1-818916` | `07eb4ff3113b310545eb0bebacbbcdc4215212ae` |
| `claude/bot-calibracao-descartes-publicos-v1` | `6b028be8ad19fbbcdf3d5511d0df0fafabb07a6b` |
| `claude/bot-orcamento-busca-stbl-v1` | `d3effdc119bd68ccf27fdcb628834a43baf5c6d8` |
| `homologacao/bot-cadeia-completa-abandono-v1` | `f58eff86db2b8d1c28422367065effff345f3c34` |
| `main` | `fb9edb5c6963964161f1e8834b57f50fe77074a1` |

O HEAD `f58eff8...` reportado pela OS resolve integralmente para
`f58eff86db2b8d1c28422367065effff345f3c34`. Confere.

**Servidor — `soniaambrosio/buraco-servidor`**: 17 heads remotas. A linhagem
canônica do motor online **não foi assumida pela memória**; foi resolvida por
continência:

`integracao/credencial-motor-v2-auditoria-uuid-v1` = **`c8ab95c427cfb66d3cd6d6c991a3ff617b45a637`**
contém `main` (`1828d42`), `integracao/ws-auth-visao-espectador-v1` (`8cd14c6`),
`claude/produtor-encerramento-autoritativo-v1` (`16a692b`),
`claude/versionamento-visao-autoritativa-v1` (`7e7572b`),
`enforcement/visao-espectador` (`3c8b07e`), `seguranca/ws-auth-identidade`,
`correcao/credencial-motor-secure-token-v2`, `correcao/conformidade-canonica`,
`correcao/teste-espectador-uuid-falso-positivo-v1` e
`claude/credencial-renovavel-motor-railway-v1`.

**`c8ab95c` é a linhagem mais avançada, mas NÃO é ordem total.** Cinco heads
ficam fora dela e nenhuma a contém:

| head fora de `c8ab95c` | SHA | diff em `server.js` vs `c8ab95c` |
|---|---|---|
| `integracao/gate-vip-credencial-backend-v1` | `e4bad52` | +966 / −16 |
| `integracao/mesa-privada-vip-individual-v1` | `274c50d` | +1087 / −19 |
| `claude/gate-autoritativo-entrada-vip-ranqueada-v1` | `504d68f` | +394 / −485 |
| `homologacao/primeira-batida-real-v1` | `baa3d8f` | +4 / −712 |
| `transporte-srv2` | `2fdeda5` | +36 / −2173 |

A OS seguinte **precisa declarar a base do servidor explicitamente**. Este laudo
mede contra `c8ab95c`.

### 1.2 Árvores limpas — uma NÃO está

| árvore | estado |
|---|---|
| app (worktree desta OS) | **limpa**, HEAD = `d3effdc` |
| `F:/Projetos/buraco-servidor` | **SUJA** |

O checkout local do servidor tem trabalho não commitado:

```
 M server.js                    +664 / −0
 M test/credencial_motor.test.js  +26 / −6
?? contrato/
?? test/chat_contrato.test.js
?? test/chat_transporte.test.js
```

É a folha de transporte de chat. **Nada está em risco**: `git diff cc8bd15 --
server.js` é **vazio** — o conteúdo sujo é exatamente o commit `cc8bd15`, já
publicado em `origin/claude/chat-transporte-real-v1`. O que está fora do lugar é
o **HEAD** (parado em `c8ab95c`), não o trabalho.

**Todo este laudo leu `git show c8ab95c:server.js`, nunca a árvore de
trabalho** — o extrato está em `scratchpad/os6/server_c8ab95c.js` (6126 linhas).
Verificado que o diff sujo é **puramente aditivo** e não toca `sair`,
`desconectar` nem `avancarBots`: o takeover descrito acima é código commitado,
não overlay local.

Fica registrado como pendência operacional: **a árvore local do servidor está com
uma folha por cima de outra.** Quem editar `server.js` nessa pasta mede a folha
errada — foi exatamente por isso que este laudo leu tudo por `git show`.

### 1.3 Inventário — Bot Dart (`d3effdc`, `app/lib/bot/`, 3.349 linhas)

| arquivo | linhas | papel |
|---|---|---|
| `gerador_candidatos.dart` | 675 | enumeração de planos |
| `executor_bot.dart` | 595 | **entrada única** (`decidirCompra`, `decidirJogo`) |
| `pesos.dart` | 487 | pesos da avaliação |
| `avaliador_heuristico.dart` | 313 | função de valor |
| `analise_mao.dart` | 274 | leitura da mão |
| `orcamento_busca.dart` | 273 | orçamento determinístico |
| `visao_informacao.dart` | 256 | **projeção mascarada** |
| `modelo_parceiro.dart` | 192 | inferência sobre o parceiro |
| `risco_descarte.dart` | 107 | risco do descarte |
| `razoes.dart` | 97 | rastro da decisão |
| `leitura_meld.dart` | 80 | leitura de jogos baixados |

### 1.4 Inventário — Bot JS / ISMCTS (`c8ab95c`, `server.js`)

| região | papel |
|---|---|
| `2633–2652` | Fase B3 — SO-ISMCTS "lite" (§26 da Diretriz) |
| `2660–2670` | perfis: `iniciante`, `intermediario`, `avancado`, `expert`, **`substituto`** |
| `2694–2712` | `cloneJogoB3` — clone para simulação |
| `2712–2742` | `amostrarDeterminizacao` — amostragem do multiconjunto não-visto |
| `2745–2790` | `valorEstadoB3` — função de valor |
| `2793–2825` | `ismctsEscolherDescarte` — busca anytime |
| `2826–3174` | `jogarTurnoBotCore` — heurística + aplicação do turno |
| `3175–3250` | `escolherDescarteLegal`, `jogarTurnoBot`, fallback seguro |
| `4317–4336` | `avancarBots` — laço do servidor |

O perfil `substituto` (`orcamentoMs: 40, margem: 55, substituto: true`,
`server.js:2666`) existe, é serializado ao cliente (`server.js:1753`) e
**nunca é ativado**: `grep 'substituto = true'` = 0 ocorrências. Quem assume um
assento abandonado hoje joga com o perfil **`avancado`** (padrão), não com o
perfil desenhado para substituir.

### 1.5 Os seis eixos exigidos pela OS, lado a lado

| eixo | Bot Dart (`d3effdc`) | Bot JS (`c8ab95c`) |
|---|---|---|
| **recebe estado** | `ExecutorBot.decidirCompra/decidirJogo(EstadoJogo, assento)` — recebe o estado cru e **projeta na entrada** | `jogarTurnoBotCore(jogo, assento)` — recebe `jogo` cru; **sem projeção** |
| **escolhe ação** | enumera planos → avalia → devolve `DecisaoBot` (proposta) | heurística + ISMCTS; **aplica direto no `jogo`** |
| **aplica orçamento** | contadores determinísticos: nós, transações de lixo, planos; teto por **decisão** | `Date.now() + orcamentoMs` (`server.js:2803, 2807, 2809`) |
| **informação privada** | **impossível por construção**: `VisaoInformacao` não tem campo para mão alheia, monte ou morto | tem acesso ao `jogo` inteiro; **por disciplina** não lê — `amostrarDeterminizacao` reamostra do não-visto e só lê **contagens** de mão (`proxCartas`, `minCartasOponente`), que são públicas |
| **aleatoriedade / tempo** | zero `Random`; um único `Stopwatch`, e o próprio código o define como **fusível**: *"só é consultado em pontos seguros da expansão, e só para abortar — nunca para escolher, ordenar ou desempatar"* | `Math.random()` na determinização (`server.js:2730`) **e** relógio no laço de iteração |
| **Fechado / STBL** | sim, via `RuleSpec` / `modalidade` | sim: `MODALIDADES` cobre `aberto`, `fechado`, `sbtl`; trava `deveUsarTopo`, `permiteTrinca` no Fechado, regra de batida por modalidade |

### 1.6 Autoridade real da partida online

**É o servidor Node.** Prova pelo protocolo: `online_service.dart` só envia
**intenções** (`criarMesa`, `entrarMesa`, `iniciarPartida`, `jogada` com
`comprarMonte` / `comprarLixo` / `descartar` / `baixar` / `estender`, `sair`) e
recebe estado. Nenhuma mensagem carrega estado calculado pelo cliente. O motor
Dart de `app/lib/motor/` **não decide nada online** — online ele é leitor da
visão do servidor.

Isto já satisfaz metade da regra do §5: **o cliente propõe, o servidor valida e
aplica.** Falta a outra metade — hoje o bot JS **não propõe, ele aplica**
(`jogarTurnoBotCore` muta `jogo`). Não é violação de segurança (ele roda dentro
da própria autoridade), mas é ausência da costura que o §5 exige e que qualquer
decisor externo obrigará a criar.

### 1.7 Onde vivem hoje a vez e o assento

```
server.js:4063   const salas = {};                  // memória do processo
server.js:1808   jogo.vez = 0;
server.js:2435   jogo.vez = (jogo.vez + 1) % 4;
                 sala.jogo.assentos[i] = { tipo, apelido, dupla }
                 sala.assentos[i]      = { tipo, apelido, jogadorId }
```

Três consequências que o desenho tem de respeitar:

1. **O "controlador de assento" que existe hoje é o campo `tipo`**, com domínio
   `{"humano","bot"}`. Ele **confunde quem joga com quem é dono do assento**.
2. **A posse sobrevive ao takeover.** `jogadorId` fica em `sala.assentos[i]` e é
   preservado em `iniciarPartida` (`idsPorAssento`), separado de
   `sala.jogo.assentos[i].tipo`. Ou seja: **o dono do assento não é perdido
   quando o controle passa ao bot.** Isto é a fundação do retorno humano, e ela
   já está no lugar.
3. **`salas` é memória volátil.** Reinício do processo (deploy incluído) apaga
   mesa, assento e takeover. Nenhuma janela de reconexão pode prometer
   sobrevivência a um deploy.

### 1.8 Reconexão, abandono e timeout

| evento | onde | o que acontece hoje |
|---|---|---|
| socket fecha | `desconectar` → `ger.sair` | assento vira `"bot"` **imediatamente**, sem janela |
| saída voluntária | `case "sair"` | mesmo caminho |
| AFK (2 estouros) | `case "afkBot"` | assento vira `"bot"` — **decidido pelo CLIENTE** |
| volta do AFK | `case "afkVoltar"` | assento volta a `"humano"`, efetivo no próximo turno dele |
| reconexão com assento | `case "entrarMesa"` | **RECUSADA**: `entrarMesa` responde `"a partida já começou"` |
| reconexão sem assento | `case "assistirMesa"` | entra como **espectador**, `c.assento = null` explícito |
| timeout de turno | — | **não existe no servidor**. O relógio de turno é do cliente; o único autômato de turno é `Jogo.jogadaAutomatica` (`mesa.dart:1685`), local, chamado só para o assento 0 |

**O defeito vivo, em uma frase:** quem cai no meio da partida perde o assento na
hora e **não tem caminho de volta** — `entrarMesa` recusa mesa iniciada e
`afkVoltar` exige a conexão que acabou de morrer. Ele só consegue voltar como
espectador da própria partida.

### 1.9 Controlador de assento em branch não composta — e STOP

Varredura das **17 heads remotas** do servidor, uma a uma, resolvendo cada SHA
por `ls-remote` (nunca por ref de rastreamento local): `grep -i controlador` em
`server.js` devolve **0 ocorrências em todas as 17**. `afkBot` está presente em
**todas as 17**, inclusive `main` — não é folha isolada, é comportamento
universal do servidor.

**STOP não disparado.** O censo fecha em:

- **bots: exatamente 2** — o Dart (`app/lib/bot/`) e o JS (`server.js` §B3);
- **mecanismos de takeover: exatamente 1** — a escrita em
  `assentos[i].tipo = "bot"`, com três chamadores (`sair`, `afkBot`,
  `iniciarPartida` preenchendo assento vazio). Três chamadores do mesmo
  mecanismo não são três autoridades.

**Não há terceira autoridade de bot ou de assento.**

---

## 2. Comparação explícita das alternativas

### A — O bot JS atual assume

- **Divergência do Bot Dart:** total. São dois algoritmos diferentes (ISMCTS
  amostrado vs enumeração de planos com avaliador heurístico), duas funções de
  valor e dois orçamentos. Nenhuma equivalência foi medida nem é mensurável hoje
  — o JS não é determinístico, então nem "mesmo estado, mesma jogada" existe
  como pergunta com resposta.
- **Regras não equivalentes:** o JS **não tem a Proveniência Pública de
  Descartes**. `grep 'descartes\|autoria de descarte'` em `server.js`: **zero**.
  A determinização só considera "visto" a própria mão, os jogos baixados e —
  fora do Aberto — **apenas o topo do lixo**. Toda a memória de mesa entregue
  pela OS 2 e calibrada pela OS 3 é **inexistente online**, para todo bot, desde
  o primeiro turno — não só no takeover.
- **Orçamento:** por relógio, nos dois eixos (deadline de iteração + `Math.random`
  na determinização). É exatamente o critério que a OS 4 recusou como autoridade
  de decisão. Efeito colateral concreto: **servidor sob carga produz bot mais
  fraco**, e ninguém consegue reproduzir a jogada para auditar.
- **Cobertura de Fechado/STBL:** boa. `MODALIDADES` cobre as três, com
  `deveUsarTopo`, `permiteTrinca` e regra de batida por modalidade.
- **Privacidade:** aceitável na prática, frágil no contrato. Recebe o `jogo`
  cru; não lê mão alheia (a determinização reamostra); lê contagens de mão, que
  são públicas. Não é bloqueador — **é bloqueador para promovê-lo a decisor
  canônico** sem antes existir projeção.
- **Testes existentes:** 273 `test()` no servidor. Sobre o bot: `COST-14`
  (partida com bots encerra uma vez), `ESPEC-06` (não vaza mão/decisão),
  `ID-04` (bot não recebe UID humano), `PART-09` (bot que bate não é
  beneficiário), `REG-08` (queda entrega o assento), `afkBot/afkVoltar`. **Todos
  mecânicos.** Zero testes de qualidade de decisão, de determinismo ou de
  orçamento — `grep -i "ismcts|jogarTurnoBot|B3_OPTS"` nos testes: **0**.
- **Esforço para homologá-lo ao mesmo padrão:** alto e recorrente. Seria
  refazer, em JS, a trilha das OS 2→4 (proveniência, calibração, orçamento
  determinístico, campanha de 384 partidas, rodada de mutação) — e depois
  mantê-la em paralelo com a trilha Dart, para sempre.

**Não escolher só porque já roda no servidor.** Mas registre-se o outro lado:
**ele já roda, já é testado no mecanismo, e é o que segura a mesa hoje.**

### B — Portar / reimplementar o Bot Dart no servidor

- **Lógica a duplicar:** o fecho de dependências do decisor Dart é
  `app/lib/bot/` (3.349 linhas) + `app/lib/rules/` (2.110 linhas) = **5.459
  linhas**, contra uma implementação de regras JS já existente e diferente.
  Portar o bot sem portar as regras cria um bot que raciocina sobre uma
  semântica e joga em outra; portar as duas cria **duas autoridades de regra**,
  que é precisamente o que a arquitetura do produto passou o ano eliminando.
- **Risco de divergência futura:** máximo. Cada ajuste de peso, cada correção de
  regra, cada OS de calibração passa a ter de ser aplicada duas vezes, em duas
  linguagens, por gente diferente, em repositórios diferentes.
- **Domínio compartilhável:** não há. Nada é compartilhado hoje entre Dart e JS
  além de prosa.
- **Prova de equivalência permanente:** só haveria uma forma honesta — um
  **corpus de conformidade** (estado → decisão esperada) executado nos dois
  runtimes em cada CI. Isso é construível, mas é uma terceira coisa a manter, e
  ele prova equivalência **onde o corpus toca**, nunca em geral.
- A OS admite reimplementação manual **só se houver mecanismo forte contra
  divergência**. O único mecanismo forte é não ter duas implementações.

### C — Bot Dart como autoridade de decisão separada

Duas variantes, tecnicamente muito diferentes. **A viabilidade das duas foi
verificada, não suposta:**

> O fecho de dependências do decisor Dart é **livre de Flutter**. `grep '^import'`
> por `flutter|dart:ui|dart:io` em `app/lib/bot/` (11 arquivos), `app/lib/rules/`
> (14 arquivos) e `app/lib/motor/` (13 arquivos) devolve **uma única ocorrência**:
> `motor/derivacao_fora_do_frame.dart` importa `package:flutter/foundation.dart
> show compute` — e esse arquivo é importado **somente por `mesa.dart`**, a UI.
> `executor_bot.dart` importa apenas `rules/` e os próprios módulos de `bot/`.
>
> **O decisor Dart já é código de servidor. Só nunca rodou num.**

**C1 — serviço Dart separado, chamado pelo backend.**

- Entrada/saída: o servidor envia a **projeção** do assento, recebe uma
  **intenção**; o servidor valida e aplica. Casa com o §5 sem folga.
- Latência: o custo de decisão medido na OS 4 é **0,55 s no pior caso** — o
  salto de rede é ruído perto disso; mas ele entra no caminho crítico de cada
  turno de bot, inclusive nas mesas 100% bot.
- **Disponibilidade é o problema real.** Serviço fora do ar = assento que não
  joga = mesa pendurada. Exige fallback, e o único fallback disponível é o bot
  JS — ou seja, **C1 não elimina o bot JS, promove-o a caminho degradado
  permanente**, e o produto passa a ter duas forças de jogo dependendo da saúde
  de um serviço.
- Deploy, autenticação entre serviços, isolamento, custo operacional: tudo novo,
  e o repositório do servidor hoje roda `npm start` sem `npm install`.

**C2 — decisor Dart compilado para dentro do processo do servidor.**

- `dart compile js` sobre o fecho `bot/` + `rules/` produz um módulo JS chamável
  pelo Node. **Uma fonte** (Dart), **um artefato** (JS), **um processo**.
- Mata o problema de B (não há segunda implementação — há um artefato **gerado**,
  e artefato gerado não diverge) e o de C1 (não há segundo deploy, segunda
  autenticação, nem indisponibilidade de rede).
- Determinismo e privacidade atravessam a compilação intactos: são propriedades
  do código-fonte, não do runtime.
- **Riscos ainda não medidos** — e é por isso que C2 não sai daqui como
  ACEITÁVEL puro: tamanho do artefato, convenção de chamada Dart→JS,
  comportamento de `int` (Dart `int` vira `number` em JS: 2^53, não 2^63 — os
  contadores do orçamento estão muito abaixo disso, mas isso precisa ser
  **provado**, não presumido), e o custo de o servidor passar a ter um passo de
  build.

---

## 3. Regra arquitetural e a fronteira que falta (§5)

A partida online já tem autoridade única sobre estado e aplicação: o servidor.
O que falta é a **fronteira de proposta**:

```
   ┌──────────────── AUTORIDADE (servidor) ────────────────┐
   │                                                       │
   │   estado canônico ──projeta──► VISÃO DO ASSENTO       │
   │        ▲                              │               │
   │        │                              ▼               │
   │   valida+aplica ◄──intenção──── DECISOR (bot)         │
   │                                                       │
   └───────────────────────────────────────────────────────┘
```

Regras da fronteira, que valem para **qualquer** opção escolhida:

1. O decisor recebe **só a projeção** do assento — nunca `sala.jogo`.
2. O decisor devolve **intenção**, jamais estado.
3. A autoridade **revalida** a intenção pelo mesmo caminho de uma jogada humana.
   Intenção ilegal é recusada, não corrigida em silêncio.
4. O decisor **não escreve nada**. Nem estado, nem log de partida, nem carimbo
   de versão.

Criar essa fronteira é **pré-requisito de C1 e C2, e é bom em si mesmo mesmo que
A vença** — é ela que torna a escolha do bot reversível.

---

## 4. Controlador de assento — o modelo proposto

Hoje `assentos[i].tipo ∈ {"humano","bot"}` responde a duas perguntas com um
campo só. O desenho separa as duas:

| conceito | campo | domínio | quem escreve |
|---|---|---|---|
| **posse** | `jogadorId` (já existe, em `sala.assentos[i]`) | uid ou `null` | só a admissão à mesa |
| **controle** | **`controle`** (novo, em `sala.jogo.assentos[i]`) | `humanoPresente` / `humanoAusente` / `botSubstituto` / `botDeMesa` | só o produtor de takeover |
| **rótulo** | `apelido`, `dificuldade` | — | admissão |

Distinção que o campo único não consegue fazer, e que é a razão de o modelo
existir:

- **`humanoAusente`** — a conexão caiu, a posse é dele, o controle ainda é dele;
  ninguém joga por esse assento ainda. É o estado que **hoje não existe**, e é
  exatamente o que falta para não tratar todo socket fechado como abandono.
- **`botSubstituto`** — bot jogando num assento **cuja posse é de um humano**.
  Distinto de **`botDeMesa`**, o bot que nasceu bot em `iniciarPartida` e nunca
  teve dono. Hoje os dois são o mesmo `"bot"`, e é por isso que o servidor não
  sabe a quem devolver o assento.

**Invariantes do controlador** (§6 da OS — e são para serem testadas):

- `controle` **não** toca mão, dupla, placar, morto, compromisso de lixo
  (`deveUsarTopo`) nem fase do turno (`jaComprou`). Ele responde **uma única
  pergunta**: *quem tem autoridade para fornecer a próxima intenção deste
  assento?*
- Mudança de `controle` **não é jogada**: não passa por `aplicarJogada`, não
  produz ação no log de partida, não altera `jogo.vez`.
- `jogadorId` é **imutável** durante a partida. Takeover nunca apaga a posse —
  se apagasse, o retorno seria impossível, que é o defeito de hoje.
- Toda troca de `controle` ocorre **entre turnos** daquele assento (ver §6).

---

## 5. Instante de takeover

Cinco eventos, hoje colapsados em dois caminhos. O desenho os separa:

| evento | detecção | efeito proposto |
|---|---|---|
| **queda transitória** | socket fecha | `controle := humanoAusente`. **Nenhum bot joga ainda.** Abre janela `T_ausencia`. |
| **janela de reconexão** | `T_ausencia` (proposta: 30 s, **e menor que o timeout de turno**) | reconexão autenticada com o mesmo `jogadorId` restaura `humanoPresente` |
| **abandono confirmado** | `T_ausencia` expira **ou** chega a vez do assento ausente | `controle := botSubstituto` |
| **timeout de turno** | relógio **do servidor** (hoje inexistente) | 1º estouro: aviso. 2º: `botSubstituto`. Substitui o `afkBot` dirigido pelo cliente. |
| **saída voluntária** (`sair`) | mensagem explícita | `controle := botSubstituto` **definitivo**; posse liberada ao fim da partida |

Duas afirmações que decorrem disto:

1. **Socket fechado deixa de ser abandonado definitivo.** Isso é hoje o
   comportamento, e é o que a OS proíbe.
2. **A mesa nunca pende.** Se o ausente é a vez, o takeover é imediato — a
   janela de reconexão só protege quem cai **fora** da própria vez.

**O timeout de turno tem de nascer no servidor.** Hoje ele é do cliente
(`afkBot`), e um cliente ausente não denuncia a própria ausência — é a razão
estrutural de o mecanismo atual nunca disparar em produção.

---

## 6. Política de retorno humano — proposta, com uma decisão de produto pendente

**Comparação exigida:**

| política | risco de dupla autoridade | efeito no produto | veredito |
|---|---|---|---|
| takeover **definitivo** até o fim | nenhum | brutal: quem perde 4G por 10 s perde a partida (e o rating). É o comportamento de **hoje**, por acidente | **rejeitada** |
| retorno **imediato** (no meio do turno) | **alto**: bot decidindo enquanto o humano volta ⇒ compra dupla, descarte duplo, turno partido entre duas autoridades | — | **rejeitada** |
| retorno **entre turnos** | nenhum, se o controle for lido no ingresso da intenção | volta rápido, sem turno partido | **RECOMENDADA** |
| retorno **na próxima mão** | nenhum | penalidade desproporcional (uma mão pode durar muitos minutos) | rejeitada |

**Proposta: retorno permitido, efetivo na fronteira do próximo turno do
assento.** O mecanismo que a torna segura:

- `controle` é lido **no ingresso da intenção**. Intenção humana chegando a um
  assento com `controle = botSubstituto` é **recusada**; proposta do decisor
  para um assento com `controle = humanoPresente` é **descartada**. Nunca há
  dois emissores válidos no mesmo instante.
- A troca só é aplicada **entre turnos**. Um turno começado por um controlador
  termina por ele. Isso elimina compra dupla e descarte duplo por construção,
  não por temporização.
- Se o humano volta durante o turno do bot, ele entra como `humanoPresente`
  **pendente**, e o controle troca quando aquele turno fecha.

**PENDENTE DE APROVAÇÃO DA SÔNIA — 3 decisões de produto, não técnicas:**

1. **`T_ausencia`** — 30 s é proposta, não medida. Depende de quanto tempo a
   mesa aceita esperar quando o ausente é a vez.
2. **Retorno após saída voluntária.** A proposta é **não** permitir (quem clica
   "sair" saiu). Alternativa: permitir enquanto a partida durar.
3. **Efeito no ranqueado.** Partida com `botSubstituto` num assento humano
   **pontua normalmente para a dupla?** Se sim, abre-se o incentivo de cair de
   propósito para o bot jogar melhor que você. Se não, abre-se a punição por
   queda de rede. **Esta é a que mais pesa** e não tem resposta técnica.

---

## 7. Continuidade de fase

O controlador **não representa** a fase — ela já está no estado, e é isso que
faz o takeover no meio de fase funcionar sem nada novo:

| fase | campo que já a representa (`c8ab95c`) |
|---|---|
| antes da compra | `jogo.jaComprou === false` |
| após compra do monte | `jogo.jaComprou === true` |
| após compra do lixo | `jaComprou` + `lixoCompradoNoTurno` |
| compromisso de lixo pendente | `jogo.deveUsarTopo = { assento, idTopo }` |
| após baixar, antes de descartar | `jaComprou` + jogos em `jogosDupla` |

**Regra: takeover nunca reinicia o turno.** Trocar `controle` não escreve em
nenhum destes campos. O decisor que entra recebe a projeção **com a fase
corrente** e produz a intenção seguinte — inclusive herdando o compromisso de
topo do humano que saiu, que é o caso difícil e o que o teste tem de cobrir.

Sobre `avancarBots`: hoje o laço para em `vez.tipo !== "bot"`. Com o controlador
ele passa a parar em `controle !== botSubstituto && controle !== botDeMesa` —
mudança de leitura, não de semântica de jogo.

---

## 8. Privacidade (§10)

| | Bot Dart | Bot JS |
|---|---|---|
| o que **recebe** | `EstadoJogo` cru, projetado na entrada | `jogo` cru, sem projeção |
| o que **consegue ler** | só a projeção: **não existe campo** para mão alheia, monte ou morto | tudo |
| o que **de fato lê** | a projeção | própria mão, jogos baixados, topo do lixo, **contagens** de mão (públicas) |
| garantia | **estrutural** | **disciplina** |

O JS **não é hoje um vazador**: `amostrarDeterminizacao` reamostra as mãos
alheias do multiconjunto não-visto, e o que ele lê das mãos alheias é o
**tamanho**, que é público em Buraco. Mas a garantia não é verificável por
construção, e nada impede o próximo avaliador de ler `j.maos[k]` por descuido —
não há tipo que recuse.

**Não é bloqueador para o JS continuar como está.** **É bloqueador para promovê-lo
a decisor canônico**: promover exige antes a projeção da §3, que é a mesma
projeção de que C1/C2 precisam. A fronteira paga por si em qualquer caminho.

---

## 9. Determinismo (§11)

O Bot Dart tem orçamento determinístico: contadores de nós, de transações de
compra de lixo e de planos avaliados; e o único relógio é declarado **fusível**,
com o contrato escrito no próprio código — *"só para abortar — nunca para
escolher, ordenar ou desempatar"* (`orcamento_busca.dart:129`). Abaixo do
fusível, mesmo estado ⇒ mesma decisão, sempre.

O Bot JS **não tem equivalente e não pode ter sem mudar de algoritmo**: a
iteração é limitada por `Date.now()` e a determinização é embaralhada por
`Math.random()`. Consequências que não podem ser aceitas em silêncio:

- **irreprodutibilidade** — nenhuma reclamação de jogador é auditável;
- **força acoplada à carga** — a mesma mesa joga pior quando o servidor está
  ocupado;
- **regressão indetectável** — sem decisão reprodutível não existe teste de
  qualidade de decisão, que é literalmente o estado atual (zero testes assim).

Caminho para o JS alcançar equivalência, se algum dia for preciso: PRNG semeado
(semente derivada do estado da partida, não do relógio) + orçamento por
**iterações**, não por milissegundos. É trabalho real, e ao terminá-lo o JS
ainda seria um segundo cérebro.

---

## 10. Proveniência Pública Canônica de Descartes (§12)

**Achado que decide muita coisa:** o servidor **não registra descartes com
autoria**. Zero ocorrências de histórico de descarte em `server.js` (`c8ab95c`).
O lixo é uma pilha de cartas; fora do Aberto, o bot JS só considera "visto" o
**topo**.

Portanto:

1. A camada de proveniência das OS 2/3 **não existe online hoje**, para nenhum
   bot, desde o primeiro turno — não é uma perda causada pelo takeover.
2. **Preservar a proveniência online é uma OS de servidor, não de bot**, e é
   pré-requisito de qualquer opção que use o decisor Dart (ele espera
   `descartesPublicos` na visão; sem produtor, a entrada chega vazia e a OS 3
   vira letra morta online).

**Regra para o bot que entra no meio da partida:** ele reconstrói **apenas** do
livro público de descartes da mão corrente, gravado pela autoridade no instante
do descarte, com autoria, **zerado a cada distribuição**. Nada de ler histórico
privado do motor, nada de deduzir autoria pela posição na pilha. O livro é
idêntico para os quatro assentos e para quem assiste — o bot que assume sabe
**exatamente o que um espectador sabe**, nem mais nem menos. É a mesma fronteira
que `visao_informacao.dart` já documenta e implementa no cliente.

---

## 11. Matriz de decisão

| eixo | **A** — JS atual assume | **B** — portar Dart para JS | **C1** — serviço Dart | **C2** — Dart compilado no processo |
|---|---|---|---|---|
| **segurança** | ok (in-process) | ok | superfície nova: rede + autenticação entre serviços | ok (in-process) |
| **autoridade** | bot **aplica**, não propõe — §5 não satisfeito | idem A | fronteira propor→validar→aplicar **obrigatória** | idem C1 |
| **determinismo** | **não** (relógio + `Math.random`) | herda o do Dart | preservado | preservado |
| **regras** | motor JS próprio, coerente consigo | **duas** implementações de regra | regra do decisor = regra do Dart; a do servidor continua sendo a autoridade | idem C1 |
| **STBL / Fechado** | coberto | coberto (após port) | coberto | coberto |
| **privacidade** | disciplina, sem projeção | disciplina | **estrutural** (a projeção é o formato do fio) | **estrutural** |
| **desempenho** | melhor (sem projeção, sem hop) | igual a A | +1 hop por turno de bot | projeção in-process; artefato a medir |
| **manutenção** | duas trilhas de calibração para sempre | **duas trilhas em duas linguagens** | uma trilha | uma trilha |
| **risco de divergência** | **alto e permanente** | **máximo** | nulo (uma fonte) | nulo (artefato gerado) |
| **esforço** | baixo agora, alto para homologar | **muito alto** | alto (infra nova) | médio (build + costura) |
| **deploy** | nenhum | nenhum | **segunda unidade** + fallback obrigatório | passo de build no servidor |
| **testabilidade** | ruim (decisão irreprodutível) | boa | boa | boa |
| **takeover no meio de fase** | funciona (a fase está no estado) | funciona | funciona | funciona |
| **VEREDITO** | **ACEITÁVEL COM CORREÇÕES** (só como interino) | **NÃO RECOMENDADO** | **ACEITÁVEL COM CORREÇÕES** | **ACEITÁVEL COM CORREÇÕES** ← destino |

Correções que cada veredito exige:

- **A:** rotular explicitamente como interino; ativar o perfil `substituto`
  (existe e nunca é ligado); **não** promover a canônico sem projeção.
- **C1:** definir e homologar o caminho degradado — e aceitar que ele mantém o
  bot JS vivo para sempre.
- **C2:** provar a compilação antes de comprometer (tamanho, convenção de
  chamada, semântica de `int`).

---

## 12. Recomendação

**Arquitetura canônica recomendada:**

> **Autoridade única no servidor. Controlador de assento explícito, separado da
> posse. Decisor atrás de uma fronteira `propor → validar → aplicar`. O decisor
> canônico é o Bot Dart, compilado para dentro do processo do servidor (C2). O
> bot JS permanece apenas como caminho degradado, com perfil `substituto`
> ativado, até C2 estar provado.**

Por que esta e não outra:

1. **A escolha do bot não é o problema urgente** — o problema urgente é que
   quem cai perde o assento sem volta. Isso se resolve **sem tocar em nenhum dos
   dois bots**, e não deve esperar pela arbitragem de força de jogo.
2. **A fronteira de proposta é obrigatória nos três caminhos** — ela é o que
   torna a escolha do bot **reversível**. Construí-la primeiro converte uma
   decisão irreversível numa configuração.
3. **B está morta** porque não existe mecanismo forte contra divergência, e a OS
   condiciona B exatamente a isso.
4. **C2 vence C1** porque elimina a indisponibilidade — e portanto elimina a
   necessidade de manter o bot JS como caminho degradado permanente. C1 nunca se
   livra do segundo cérebro; C2 sim.
5. **C2 é viável e isso foi verificado, não suposto:** o fecho de dependências do
   decisor (`bot/` + `rules/`) **não importa Flutter em nenhum arquivo**.

**Menor sequência de OS até a arquitetura recomendada:**

| OS | escopo | depende de |
|---|---|---|
| **7** | Controlador de assento + protocolo de ausência/retorno (servidor **e** cliente). Bot JS como está. **Fecha o defeito vivo.** | — |
| **8** | Proveniência pública de descartes na autoridade online (o livro com autoria que o servidor não tem) | — (paralelizável com a 7) |
| **9** | Spike do decisor portável: compilar o fecho `bot/`+`rules/` para JS e provar decisão idêntica contra corpus extraído da suíte Dart | — |
| **10** | Fronteira `propor → validar → aplicar` no servidor + costura do decisor Dart; JS vira degradado | 7, 8, 9 |

A OS 7 sozinha já entrega o valor de produto. As 8–10 entregam a unificação do
cérebro.

---

## 13. Esqueleto da próxima OS (executável)

**OS 7 — CONTROLADOR DE ASSENTO E PROTOCOLO DE AUSÊNCIA/RETORNO V1**

**Repositórios e bases**

- `soniaambrosio/buraco-servidor` — base **`c8ab95c427cfb66d3cd6d6c991a3ff617b45a637`**.
  Declarar no Gate Zero que `e4bad52`, `274c50d`, `504d68f`, `baa3d8f` e
  `2fdeda5` **não estão contidas** e não entram.
  **Sanear antes a árvore local**: ela está com o conteúdo de `cc8bd15`
  (`claude/chat-transporte-real-v1`) por cima de um HEAD em `c8ab95c`. Nada a
  salvar — só decidir se a folha de chat entra na base da OS 7.
- `soniaambrosio/buraco-master-vip-app` — base
  **`d3effdc119bd68ccf27fdcb628834a43baf5c6d8`**.

**Controlador de assento**

- Campo `controle` em `sala.jogo.assentos[i]`, domínio `humanoPresente` /
  `humanoAusente` / `botSubstituto` / `botDeMesa`.
- `jogadorId` imutável durante a partida; posse **nunca** apagada por takeover.
- `controle` fora da impressão de estado que gera versão? **Decidir explicitamente**
  — ver `CAMPOS_FORA_DA_IMPRESSAO` e `test/versao.test.js:567`, que já afirma
  que `afkBot`/`afkVoltar` mexem em `tipo` "de dentro do" carimbo.
- `avancarBots` passa a ler `controle`, não `tipo`.

**Produtor de takeover**

- `desconectar` → `humanoAusente` (**não** mais direto a bot).
- Janela `T_ausencia` no servidor; expiração **ou** chegada da vez → `botSubstituto`.
- **Timeout de turno no servidor** (novo) substituindo o `afkBot` dirigido pelo
  cliente. Manter `afkBot`/`afkVoltar` aceitos por compatibilidade de protocolo.
- `entrarMesa` passa a aceitar reentrada em mesa iniciada **quando** o
  `jogadorId` autenticado casa com um assento cujo `controle` é `humanoAusente`
  ou `botSubstituto` com posse — hoje ela recusa e é isso que fecha o retorno.
- Cliente: `online_service.dart` ganha reentrada + sinal de presença. **Sem isso
  a OS não tem produtor** — é o defeito exato que esta arbitragem encontrou.

**Bot escolhido:** JS atual, **interino**, com o perfil `substituto`
(`server.js:2666`) **ativado** ao entrar por `botSubstituto` — ele existe e
nunca foi ligado.

**Fronteira de autoridade:** inalterada nesta OS (o bot continua in-process).
Proibido criar a fronteira de proposta aqui — ela é da OS 10.

**Política de retorno:** entre turnos, conforme §6 — **condicionada às 3
aprovações pendentes da Sônia** (`T_ausencia`, retorno após saída voluntária,
efeito no ranqueado). Sem a 3ª, a OS entrega o mecanismo e deixa o efeito no
ranking desligado.

**Testes obrigatórios**

1. Queda fora da própria vez, volta dentro da janela ⇒ **nenhum turno jogado por
   bot**, controle restaurado.
2. Queda **na** própria vez ⇒ takeover imediato, mesa não pende.
3. Queda com **compromisso de topo pendente** (`deveUsarTopo`) ⇒ o bot herda o
   compromisso; o turno **não** reinicia; `jaComprou` preservado.
4. Retorno durante turno do bot ⇒ controle troca **só** na fronteira do turno;
   nenhuma compra dupla, nenhum descarte duplo.
5. Intenção humana com `controle = botSubstituto` ⇒ **recusada**.
6. `jogadorId` sobrevive a takeover e a retorno.
7. Saída voluntária ⇒ takeover definitivo; reentrada recusada.
8. `botDeMesa` (assento que nasceu bot) **nunca** aceita reivindicação de posse.
9. Espectador não obtém assento por nenhum destes caminhos (regressão de
   `ESPEC-06` / `test/espectador.test.js:240`).
10. `REG-08` e `afkBot`/`afkVoltar` continuam verdes — compatibilidade de
    protocolo com clientes não atualizados.

**Proibido na OS 7:** tocar em qualquer dos dois bots, alterar pesos, criar a
fronteira de proposta, iniciar port ou compilação.

---

## 14. Registro de proibições desta OS

Cumpridas: zero código de produção, zero port, zero controlador implementado,
zero deploy, zero merge, zero PR, zero alteração de pesos, zero "melhoria
rápida" no bot JS, zero takeover improvisado. Único arquivo adicionado: este
laudo. Nenhum harness de medição foi necessário — todas as afirmações saem de
leitura de refs commitadas.

**Base deste laudo:** `d3effdc` (app) e `c8ab95c` (servidor, lido por
`git show`, não da árvore de trabalho).
