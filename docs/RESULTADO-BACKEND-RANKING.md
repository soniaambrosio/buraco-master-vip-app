# RESULTADO — Backend autoritativo de Ranking, Ligas e Temporadas

> **SUPERADO EM PARTE PELA POLÍTICA COMPETITIVA V1.** Este é o relatório da OS
> **anterior**, preservado como registro. Duas das suas conclusões centrais
> deixaram de valer:
>
> 1. **"A regra competitiva continua não existindo"** — existe agora, e está em
>    [`POLITICA-COMPETITIVA-V1.md`](POLITICA-COMPETITIVA-V1.md): Elo em dupla
>    versionado como `competitiva@v1`, sete Ligas, colocação/revalidação, soft
>    reset e desempate de cinco critérios. `PoliticaDeRanking.pendente` deixou de
>    ser a política ativa, embora continue existindo como valor legítimo.
> 2. **A lacuna de teste declarada na §7 foi FECHADA.** A transação, a
>    idempotência de banco, a concorrência e a paginação por cursor passaram a ser
>    exercitadas contra o Firestore real — 16 provas em
>    `functions-ranking/test/integracao.emulador.test.js`, via
>    `npm run test:emulador`. O que **continua** sem exercício de ponta a ponta são
>    as Cloud Functions **chamáveis** (App Check, claims, `onCall`); a integração
>    ataca a camada de execução (`firestore.ts`) diretamente.
>
> Tudo o mais deste documento continua válido, inclusive as pendências de
> apelido/avatar, grafo social e Hall, que a OS nova **não** tocou.

Fecha o ciclo aberto por [`MAPA-BACKEND-RANKING.md`](MAPA-BACKEND-RANKING.md).
Relatório exigido pela seção 30 da OS.

---

## 1. Git

| | |
|---|---|
| repositório | `buraco-master-vip-app` |
| branch | `claude/ranking-ligas-backend-auth-ea5ceb` |
| hash da base | `f9814f95ec675d920ff285a135f01154d5cffb48` (`homologacao/p0-integrada-a90557`) |
| commits | 2 |
| merge | **não** |
| deploy | **não** |
| release / APK / AAB | **não** |

A base **não** é `origin/main`: aquele commit (`fb9edb5`) é um esqueleto de projeto
Flutter de exemplo, sem `firebase/`, `functions/` nem `app/lib/`. A base integrada
já existia e não foi preciso montar nenhuma — `f9814f9` contém, por
ancestralidade, a consolidação Firebase (`1dc26dd`), a rastreabilidade (`c2e34ad`,
o hash citado na OS) e a moderação (`f25026e`).

Consultadas sem merge: `integracao/ranking-ligas-hall` (`428c458`),
`spectator-view-server-enforcement`, `ws-auth-identidade`, `origin/codex/ranking-ui`.

---

## 2. A resposta curta

**A arquitetura foi construída. A regra competitiva continua não existindo, e não
foi inventada.**

A seção 31 pede exatamente essa separação, e ela é o resultado desta OS:

- **problema técnico, resolvido:** não havia autoridade, persistência,
  idempotência, concorrência, temporada, posição, paginação, identidade pública
  nem segurança. Agora há.
- **decisão de produto, devolvida:** quanto vale uma vitória, quais são as ligas
  e suas faixas, e o que acontece na virada de temporada. Continua em aberto — a
  lista completa está na seção 8.

O estado operacional de hoje, dito sem rodeio: **com o sistema no ar, nenhuma
partida pontuaria.** Toda partida oficial cairia em `rankingBacklog` com o motivo
`politica_nao_definida`, e o ranking ficaria vazio. Isso não é um defeito — é o
comportamento correto de um sistema que se recusa a inventar a regra. E o backlog
é o que transforma essa ausência em uma **lista de trabalho reprocessável** em vez
de um buraco silencioso.

---

## 3. Arquitetura

### Fonte oficial do resultado

`matches/{matchId}`, escrito por `registrarEncerramentoPartida`
(`functions/src/rastreabilidade.ts`, claim `motorDePartidas` ou `admin`), no
formato de `RegistroDePartida.toJson()`. **Esta OS não escreve nessa coleção** —
só lê. Redecidir quem venceu criaria uma segunda opinião sobre o resultado.

O campo que decide se a partida entra no ranking é `alteraRanking`, **lido** e não
recalculado: `TipoDePartida.alteraRanking` no domínio Dart é declarado como "a
ÚNICA fonte disso no sistema", e continua sendo.

### Onde o ranking é consolidado

| coleção | papel |
|---|---|
| `rankingSeasons/{seasonId}` | a temporada. Autoridade sobre "qual é a vigente" |
| `rankingLadders/{ladderId}` | a escada de ligas. **Vazia** |
| `rankingStandings/{seasonId\|uid}` | a classificação — uma linha por jogador **por temporada** |
| `rankingPlayers/{uid}` | agregado de vida inteira (escopo `global`); `publicPlayerId` é **projeção** da identidade canônica¹ |
| ~~`rankingPublicIds/{publicPlayerId}`~~ | **removida**¹ — o índice reverso canônico é `publicIdIndex`, de `functions-social` |
| `rankingContributions/{chave}` | a prova de que uma partida contribuiu, **e** a chave de idempotência |
| `rankingBacklog/{matchId}` | resultado oficial que ainda não pontuou |
| `rankingAudit/{eventoId}` | trilha das operações administrativas |
| `rankingTasks/{chave}` | idempotência de apuração e virada |
| `hallEntries/{seasonId\|categoria}` | o Hall. **Vazio** |

¹ OS de integração Identidade Pública × Ranking v1. Este codebase deixou de
emitir `publicId`: ele lê `playerIdentities/{uid}` e nunca escreve nas coleções
canônicas de identidade. Ver
[AUTORIDADE-DE-IDENTIDADE-PUBLICA.md](AUTORIDADE-DE-IDENTIDADE-PUBLICA.md).
| `rankingLedger/{matchId\|userId\|motivo}` | **já existia** (rastreabilidade). Esta OS escreve nela sem redefini-la |

**A temporada anterior nunca é sobrescrita** porque o `seasonId` está na chave do
documento: a temporada seguinte grava em documentos com outro id. Não há passo de
"arquivar" que possa falhar.

### Onde a Liga é definida

`functions-ranking/src/ligas.ts`, aplicando a escada de `rankingLadders`. A escada
é conferida antes de classificar alguém — faixa invertida, sobreposta, com buraco,
com liga duplicada ou com teto no meio é **recusada**, e a coleção sai vazia de
fábrica.

Sem escada, `ligaId` é `null` e o cliente exibe ausência. **Não há default**: cair
no degrau mais baixo por omissão seria decidir rebaixamento.

### Onde a temporada é definida

`rankingSeasons`, com máquina de estados `planejada` → `vigente` → `encerrada` e a
invariante **no máximo uma vigente**, conferida dentro da transação de abertura.
Sem ela, `temporadaVigente()` teria que escolher entre duas e escolheria pela
ordem que o Firestore devolvesse — o jogador veria classificações diferentes
conforme a hora do dia.

Não foi unificada com o campo `temporada` do Motor de Torneios: ali é texto livre
de agrupamento anual, e fundir as duas exigiria decidir que a virada do ranking
acontece junto com o encerramento anual de torneios. Pendência registrada.

### Como funciona a idempotência

Chave: `rankingContributions/{matchId|seasonId|politicaId|vN}`, que **é o id do
documento**. Cada pedaço tem função:

- `matchId` — uma partida contribui no máximo uma vez;
- `seasonId` — a mesma partida reprocessada para outra temporada é outra
  contribuição, o que permite reconstruir uma temporada sem que a chave da
  original atrapalhe;
- `politica@vN` — trocar a regra e recalcular vira contribuição **nova**, com
  trilha própria, em vez de reescrita silenciosa da antiga.

Duas barreiras: uma leitura antes da transação (caso comum) e um `get` dentro dela
(duas execuções que passaram pela primeira ao mesmo tempo). Os lançamentos do
ledger têm a sua própria, herdada da rastreabilidade: `matchId|userId|motivo`,
também como id de documento.

**A ordem das guardas importa e é a mesma do domínio Dart:** idempotência é
verificada **antes** da política. Invertido, um retry depois de uma troca de regra
viraria erro permanente em vez de "já processado".

### Como funciona a concorrência

Transação do Firestore. Duas partidas do mesmo jogador que terminem juntas
disputam o mesmo documento de standing; o Firestore detecta o conflito e
reexecuta a perdedora, que lê o saldo já atualizado e aplica o próprio delta em
cima dele.

**Deliberadamente não se usa `FieldValue.increment`** no standing, embora fosse
mais barato: o incremento atômico não devolve o valor anterior, e sem ele não há
`rankingBefore`. O ledger perderia a invariante `antes + delta == depois` e viraria
um contador sem auditoria.

### Como funciona o desempate

`pontos DESC, publicPlayerId ASC`.

O primeiro critério é o único competitivo, e não foi inventado. O segundo é
**técnico e neutro**, que é o que a seção 10 permite quando a política não existe.
Ele dá ordem **total** (ids são únicos), **estável** (não mudam entre apurações) e
**indexável** (vira o segundo campo do índice e o `startAfter` do cursor).

Não é regra competitiva: não premia quem jogou menos, quem tem mais vitórias nem
quem chegou antes. Como o id público é opaco e atribuído sem relação com
desempenho, a ordem entre empatados é arbitrária de propósito — ninguém consegue
jogá-la a favor. Há teste específico travando isso.

A posição é **densa e única**: 1, 2, 3… Empatados recebem posições diferentes.
Posição compartilhada é convenção competitiva, e escolher uma seria decidir
produto.

### Como funciona a paginação

Cursor opaco (base64url de `{versão, escopo, seasonId, pontos, publicPlayerId}`),
aplicado como `startAfter` sobre o índice composto. A consulta pede `limite + 1`
documentos: receber `limite` ou menos **prova** que não há próxima página, sem uma
segunda ida ao banco.

O cursor é conferido contra o escopo **e** a temporada. O cliente mantém três
paginadores independentes; sem essa conferência, um cursor da aba "temporada"
aplicado à consulta "global" devolveria uma página plausível do lugar errado, e a
lista pularia gente sem nenhum sinal de erro.

Não carrega uid, e-mail nem token — só os dois campos que a próxima consulta
precisa.

**Escalabilidade:** nenhuma leitura integral. O teto de página é 100 (um pedido de
100 000 é truncado, não atendido). A apuração percorre a temporada em lotes de 400
com `startAfter`, e não carregando tudo em memória — que seria a mesma varredura
proibida, só que escondida dentro da Function.

### Como a posição é atribuída

Numa passagem de apuração, não na leitura. O Firestore não tem `rank()`, e contar
quantos estão acima de um jogador custa uma leitura por jogador acima dele.

**Consequência honesta, declarada:** a posição é a da última apuração, não a deste
milissegundo. Uma partida que acabou de pontuar mexe no saldo na hora e na posição
na próxima apuração. É também o que torna `direcao` e `delta` do contrato do
cliente definíveis — "subiu 3 posições" exige dois instantes para comparar.

### Como o Hall consome autoridade

Não consome, porque não há o que consumir — e essa é a resposta da seção 14.

`consultarHall` devolve, para cada uma das cinco categorias, um **estado
explícito**: `disponivel`, `sem_vencedor` (o critério rodou e não elegeu ninguém —
ausência legítima) ou `criterio_nao_definido` (o caso de hoje). Erro técnico sai
como exceção, não como estado. Os quatro casos que a OS pede ficam distinguíveis.

Nenhuma das cinco pode ser derivada hoje, e por motivos diferentes — não é só
"falta a fórmula". `melhorDupla`, por exemplo, precisa de identidade de **dupla
persistente**, e o registro de partida só tem lados de mesa, que são posições de
uma partida e não uma dupla que existe entre partidas. O detalhe por categoria
está no cabeçalho de `consultarHall`.

`hallEntries` sai vazia, as Rules negam escrita a todos, e há teste que **falha se
alguém a preencher**.

### Identidade pública e privacidade

O id público é aleatório, atribuído uma vez e persistido nos dois sentidos —
12 símbolos base32 (60 bits), com colisão detectada e retentada em transação, não
apenas considerada improvável. Hash do uid seria reversível por força bruta; HMAC
criaria uma chave cuja rotação mudaria o id de todo mundo; sequencial vazaria
ordem de cadastro e convidaria à enumeração.

A projeção para o cliente é **lista branca**, não lista negra. Com `delete
linha.uid`, qualquer campo acrescentado no futuro passaria a ser publicado por
omissão, e o vazamento aconteceria no dia em que alguém adicionasse um campo sem
lembrar da projeção. Com lista branca, o esquecimento produz um campo ausente na
tela — visível, chato e inofensivo.

`souEu` é decidido no servidor comparando UIDs, numa única linha do sistema.
Nunca por apelido.

---

## 4. Testes

### Antes

| suíte | resultado |
|---|---|
| Rules no emulador (`test:integrado`) | **71** verdes, 0 falhas |
| `functions-ranking` | não existia |

### Depois

| suíte | resultado |
|---|---|
| Rules no emulador (`test:integrado`) | **112** verdes, 0 falhas (**+41**) |
| `functions-ranking` (`tsc && node --test`) | **173** verdes, 0 falhas |
| `functions-billing` (`node --test`) | **13** verdes, 0 falhas — inalterada |
| `functions` / torneios (`tsc --noEmit`) | exit 0 — inalterada |
| **total** | **298** verdes, **0 falhas** |

**O emulador foi realmente usado.** Java não está instalado nesta máquina; o
Firestore Emulator rodou com o JBR do Android Studio como `JAVA_HOME`
(OpenJDK 21.0.9), com `firebase-tools` 15.26.0. Reproduzir:

```bash
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador:integrado
```

**Honestidade sobre o que NÃO foi executado ponta a ponta** (seção 24): as
41 provas de emulador exercitam as **Rules** contra o `firestore.rules` real, no
Firestore Emulator — não são teste unitário. Mas elas **não** chamam as Cloud
Functions: subir o emulador de Functions exigiria compilar o `domain_bundle.js`
dos codebases vizinhos, dependência que a suíte de regras não tem (é a mesma
limitação declarada em `emulador:rastreabilidade`). Portanto:

- **executado contra emulador:** Rules dos seis blocos, no mesmo arquivo.
- **executado sem emulador:** a lógica de ordenação, cursor, liga, política,
  ledger, temporada, apuração e projeção — módulos puros, 173 casos.
- **NÃO executado:** as Functions chamáveis contra o emulador, e portanto a
  transação de `processarResultadoOficial` e a paginação **contra o Firestore
  real**. A lógica que elas orquestram está coberta; a orquestração em si não.

Essa é a lacuna real desta entrega, e ela está declarada em vez de arredondada.

### Cobertura da seção 23

| grupo | onde |
|---|---|
| pontuação: primeira, vitória, derrota, empate, múltiplas, delta zero, saldo negativo | `test/ledger.test.js` |
| reprocessamento da mesma partida | `test/resultado.test.js`, `test/ledger.test.js` |
| partidas concorrentes | transação (§3); **não coberto por teste** — ver lacuna acima |
| ordenação, desempate, paginação, cursor, fim da lista | `test/ordenacao.test.js` |
| jogador fora da primeira página; posição com 1–6 dígitos | `test/apuracao.test.js` |
| liga: limite inferior, superior, mudança de faixa, config inválida | `test/ligas.test.js` |
| temporada: início, término, passada, atual, fechamento duas vezes | `test/temporadas.test.js` |
| segurança: alterar pontuação, liga, entrar no Hall, leitura autorizada | `firebase/testes/ranking.test.js` (emulador) |
| idempotência: mesma partida, fechamento duas vezes, evento atrasado, retry | `test/resultado.test.js`, `test/temporadas.test.js` |

### Regressão fora do escopo

Zero arquivos tocados em `app/`, `functions/`, `functions-billing/`,
`functions-moderacao/` e `firebase/functions/` — verificado por `git diff --name-only`.

Em `firestore.rules`, o diff removeu **4 linhas, todas de comentário** (contagem de
blocos e a menção a "ranking" como coleção futura). **Nenhuma linha `allow` foi
removida ou alterada** — verificado por `grep`. Os 71 testes de regras anteriores
continuam verdes contra o arquivo com o bloco novo, que é justamente onde um bloco
poderia afrouxar o do vizinho.

A suíte Flutter não foi executada: o `app/` não é um projeto Flutter autônomo (o
CI o monta com `flutter create` + overlay), e **nenhum arquivo Dart foi tocado**.
A evidência aqui é o escopo do diff, não uma execução.

---

## 5. O que mudou fora de `functions-ranking/`

Cinco arquivos, todos aditivos:

| arquivo | mudança | por quê |
|---|---|---|
| `firebase/firestore.rules` | Bloco 6/6 + cabeçalho | a coleção nova precisa do próprio `match`; sem ele o fecho padrão negaria até o backend ler |
| `firebase/firestore.indexes.json` | 4 índices compostos | sem eles a ordem oficial e o cursor não existem |
| `firebase.json` | codebase `ranking` | unidade de implantação independente, como as outras quatro |
| `firebase/testes/package.json` | alvos `test:ranking` e `test:integrado` | a suíte nova precisa de um alvo |
| `.gitignore` | `/functions-ranking/lib/` | saída de `tsc`, como nos vizinhos |

**Uma mudança merece justificativa explícita** (seção 26): o
`.github/workflows/ci-os-integracao.yml`. O passo de regras rodava `npm test`, que
é só segurança + moderação — a suíte de rastreabilidade **já estava fora do portão
antes desta OS**, e a de ranking entraria fora também. Passou a rodar
`test:integrado`, e ganhou o passo `3d` para o codebase novo. Sem isso, a entrega
não seria validada pelo portão do projeto.

> Registrado e **não corrigido**: `functions-moderacao` continua sem passo próprio
> no CI. É anterior a esta OS e está fora do escopo dela.

---

## 6. Compatibilidade (seção 26)

Não foram alterados: motor da partida, regras do Buraco, STBL, matchmaking,
Billing, economia, espectadores, moderação, configuração da Mesa, UI do Ranking,
UI do Hall, servidor Node/Railway.

O único ponto de contato com linhagem alheia é a **leitura** de `matches/{matchId}`
e a **escrita** em `rankingLedger` — ambas previstas pela OS de Rastreabilidade,
que criou as duas coleções e deixou o ledger sem produtor.

---

## 7. Duplicação declarada

`functions-ranking/src/ledger.ts` espelha `ledger_competitivo.dart`, e
`resultado.ts` espelha `EstadoDaPartida.terminal`. Não é descuido: a ponte
`dart compile js` deste projeto exporta o domínio de **torneios**, e o cabeçalho de
`functions/src/rastreabilidade.ts` já registrava a mesma limitação com as mesmas
palavras.

Os pontos duplicados, para quem for unificar as pontes:

1. `PAPEIS_DE_AUTORIDADE` — `rastreabilidade.ts` e `functions-ranking/src/index.ts`
2. `ehTerminal` / `estadoTerminal` — `rastreabilidade.ts` e `resultado.ts`
3. invariante e chave do lançamento — `ledger_competitivo.dart` e `ledger.ts`
4. `PoliticaDeRanking.pendente` — `ledger_competitivo.dart` e `politica.ts`

A pendência de unificar continua em `docs/OS-RASTREABILIDADE-PARTIDAS.md`.

---

## 8. Dependências abertas — **decisão de produto**

Nenhuma foi improvisada, e nenhuma está escondida atrás de um valor default.

### Bloqueiam o ranking funcionar

1. **Fórmula de pontuação.** Quanto vale vitória, derrota, empate e abandono;
   se depende da força do adversário; se há piso. Sem ela **nada pontua**.
   Onde entra: registrar uma calculadora em `functions-ranking/src/politica.ts`.
2. **Lista oficial de ligas e faixas.** A arte tem sete (Bronze, Prata, Ouro,
   Platina, Diamante, Imperial, Lenda); não há decisão registrada sobre quais
   valem nem sobre os limites. Onde entra: um documento em `rankingLadders`.
3. **Política de temporada.** Duração, e o que acontece na virada: a pontuação
   zera, é reduzida ou é mantida? A liga da temporada anterior influencia a
   próxima? Hoje a temporada nova simplesmente começa vazia, **por consequência
   da modelagem e não por política escolhida**.

### Bloqueiam partes da tela

4. **Desempate competitivo.** Vale o desempate técnico documentado até haver
   decisão. Candidatos: confronto direto, mais vitórias, menos partidas, quem
   atingiu a pontuação primeiro.
5. **Divisão dentro da liga.** `RankingDivisao` do contrato pede nome, ícone,
   `pontosProxima`, `faltamPontos` e `posicaoLiga`. Depende de (2).
6. **Critérios do Hall**, categoria por categoria. `melhorDupla` depende também de
   uma decisão anterior: existe "dupla" como entidade persistente, ou só lados de
   mesa por partida?
7. **Critérios dos selos.** A arte tem nove (`top_1`, `canastra_limpa`,
   `rei_do_morto`, `sequencia_quente`…). O campo existe e sai `null`.

### Dependências técnicas, não de produto

8. **Fonte de apelido e avatar.** Não existe documento de perfil no backend.
   `apelido` e `avatar` saem vazios. É a lacuna mais visível na tela.
9. **Grafo social.** A aba "amigos" recusa explicitamente. `blocks` e `mutes` são
   da moderação e listam o oposto de amigos.
10. **Posição no escopo global.** A apuração percorre a temporada, não a vida
    inteira; o agregado global sai com `posicao: 0`. Uma segunda passagem sobre
    `rankingPlayers` resolveria — não foi construída porque nenhuma tela pede
    posição global hoje.
11. **Agendamento da apuração.** `apurarRanking` existe e é idempotente, mas
    ninguém a chama sozinha. Falta um `onSchedule`; a frequência é decisão de
    operação (ela define de quanto em quanto tempo a posição "envelhece").
12. **Temporada de ranking × temporada de torneios.** Devem coincidir?

---

## 9. Encerramento

- sem merge (`main` e `consolidacao/apk-geral-bmv` intactas);
- sem deploy Firebase, sem release, sem APK/AAB, sem Play Console;
- sem alteração de motor, regras do Buraco, STBL, pontuação de partida;
- sem alteração de Billing, economia, saldo/fichas ou entitlement;
- sem alteração de moderação, matchmaking, espectadores ou servidor de partidas;
- sem alteração de UI;
- nenhum dado fictício no caminho de produção: o registro de calculadoras sai
  vazio, `rankingLadders` sai vazia e `hallEntries` sai vazia — as três com teste
  que falha se alguém as preencher.

Arquivos de outras linhagens tocados: **nenhum em `app/` e nenhum nos outros
quatro codebases**. Os cinco arquivos compartilhados alterados estão na seção 5,
todos aditivos.
