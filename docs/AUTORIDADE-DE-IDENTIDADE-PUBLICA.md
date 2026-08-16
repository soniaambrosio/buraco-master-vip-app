# Autoridade de identidade pública

**OS de integração Identidade Pública × Ranking v1.**
Branch: `integracao/identidade-publica-ranking-v1`.

Este documento existe para que a pergunta

> Quem decide qual é o `publicId` deste jogador?

tenha **uma** resposta.

---

## 1. A regra central

**A camada de Identidade Pública é dona do `publicId`. O Ranking apenas
referencia essa identidade.**

O Ranking não cria, não escolhe, não repara em silêncio, não substitui e não
rotaciona `publicId`. O mesmo vale para Perfil, Hall futuro e qualquer outra
funcionalidade: todas referenciam, nenhuma emite.

## 2. Quem é dono de quê

| Domínio | Código | É autoridade sobre |
|---|---|---|
| **Identidade Pública / Social** | `functions-social/`, `app/lib/social/` | `publicId`, apelido, `avatarRef`, perfil público, grafo social |
| **Ranking / Ligas / Temporadas** | `functions-ranking/` | rating, liga, posição, temporada, estado de colocação/revalidação, ledger competitivo |

As três coleções canônicas de identidade, todas escritas **apenas** por
`functions-social`:

| Coleção | Conteúdo | Quem lê |
|---|---|---|
| `playerIdentities/{uid}` | `uid → publicId` | o dono (Rules), o backend |
| `publicIdIndex/{publicId}` | `publicId → uid` | **nenhum cliente**; admin para suporte |
| `publicProfiles/{publicId}` | apelido, `avatarRef` | qualquer autenticado |

O `publicId` é estável, opaco, único, não reutilizável, e independente de
apelido, avatar, ranking, liga, temporada e assinatura VIP. Mudar qualquer uma
dessas coisas **não** muda o `publicId`.

---

## 3. O que existia antes, e por que era um defeito

Duas linhas paralelas chegaram, cada uma, a uma autoridade de emissão completa:

| | Identidade Pública (`fddcecc`) | Ranking (`cad4515`) |
|---|---|---|
| gerador | `dominio.idPublicoDeBytes` (Dart) | `idPublicoDeBytes` (TS) |
| provisionamento | `garantirIdentidade(uid, apelido)` | `garantirIdPublico(uid)` |
| mapa `uid → id` | `playerIdentities/{uid}` | `rankingPlayers/{uid}.publicPlayerId` |
| mapa `id → uid` | `publicIdIndex/{publicId}` | `rankingPublicIds/{publicPlayerId}` |
| endpoint | `obterMinhaIdentidade` | `garantirIdentidadePublica` |

**As duas produziam o mesmo FORMATO** — base32 de Crockford sem `I`/`L`/`O`/`U`,
12 símbolos, prefixo `P`. Isso foi deliberado: o cabeçalho de
`app/lib/social/identidade_publica.dart` registra que adotou o formato do
ranking justamente para que a consolidação fosse "uma reconciliação de DADOS, e
não uma quebra de contrato".

Formato igual não é autoridade igual. Dois geradores independentes sobre o mesmo
formato produzem, para o mesmo jogador, **dois ids válidos e diferentes**, e nada
no sistema saberia qual é o dele: o perfil público diria um, o ranking diria
outro, e "abrir o perfil de quem está em 3º lugar" resolveria — ou não — conforme
qual mapa fosse consultado.

---

## 4. O que mudou

### 4.1 O gerador saiu do Ranking

`functions-ranking/src/identidade.ts` perdeu `idPublicoDeBytes`, e
`firestore.ts` perdeu `garantirIdPublico` e o `import { randomBytes }`.

**Removido, e não desligado por flag.** Uma flag é uma autoridade adormecida; a
ausência da função é a única prova durável.

### 4.2 A coleção própria saiu

`rankingPublicIds` não existe mais — nem no código, nem nas Rules, nem nos
índices. O caminho `publicId → uid` continua existindo **uma vez**, em
`publicIdIndex`.

### 4.3 O endpoint de emissão saiu

`ranking:garantirIdentidadePublica` → **`social:obterMinhaIdentidade`**

Não foi substituído por um encaminhamento. Um caminho de emissão dentro do
codebase competitivo continuaria sendo um caminho de emissão dentro do codebase
competitivo, e o próximo refactor o transformaria de novo num gerador local.

> **Mudança de contrato do cliente.** O app passa a chamar
> `obterMinhaIdentidade` no primeiro acesso — inclusive antes da tela de
> Ranking, porque identidade pública não é um conceito do ranking. Ela devolve
> `{ publicId, apelido, avatarRef }`, e não só o id.

### 4.4 O que o Ranking passou a fazer

| Função (`functions-ranking/src/firestore.ts`) | O que faz |
|---|---|
| `identidadeCanonicaDe(uid)` | lê `playerIdentities/{uid}.publicId`, ou `null` |
| `identidadesCanonicasDe(uids)` | o mesmo, em um `getAll` |
| `apresentacoesCanonicasDe(mapa)` | lê `publicProfiles/{publicId}` → `{apelido, avatar}` |
| `porIdPublico(id, season)` | resolve por `publicIdIndex`, não mais por mapa próprio |

Ler coleção de outro domínio pelo Admin SDK é normal e não move autoridade
nenhuma: **autoridade é quem escreve**.

`null` não é erro. Um jogador legitimamente ainda não provisionado é um estado
esperado do sistema — ver §5.

---

## 5. Ranking encontra jogador sem identidade

A décima segunda guarda, `decidirIdentidadePublica` em
`functions-ranking/src/resultado.ts`. É **pura**: recebe o mapa já resolvido, não
o Firestore.

Se qualquer competidor não tiver identidade canônica, a partida **não pontua** e
vai para `rankingBacklog` como `pendente`, com motivo `identidade_publica_ausente`.

O processamento competitivo **não**:

- inventa um `publicId`;
- usa UID como `publicId`;
- armazena `"unknown"`;
- armazena string vazia;
- gera identificador temporário;
- publica UID no ranking.

`null`, `undefined` e `""` são tratados como a mesma coisa — ausência. Um
documento de identidade meio gravado é, para o ranking, indistinguível de um que
não existe, e ambos precisam terminar em backlog.

**Por que backlog, e não erro:** é o mecanismo que este codebase já tinha para "o
resultado é real, falta uma peça" (falta de temporada, falta de política). O
item volta à fila com as onze guardas anteriores sendo reavaliadas, e a chave de
idempotência de `rankingContributions` continua sendo a mesma — um
reprocessamento tardio pontua **uma** vez.

**Por que é guarda separada, e não a linha 12 de `decidirProcessamento`:**
respondê-la custa uma leitura por competidor. As onze guardas anteriores são
puras. Fundi-las obrigaria a pagar essas leituras em toda escrita de `matches`,
inclusive nas Mesas Públicas, que a guarda 4 recusa sem tocar o banco.

**Um só competidor sem identidade segura a partida inteira.** Não há meio-termo:
pontuar três e deixar um de fora produziria um Elo que não fecha, porque a
expectativa de cada lado depende dos dois ratings.

---

## 6. Ordem de eventos

| Caso | Cenário | Resultado |
|---|---|---|
| **A** | identidade criada → primeira ranqueada | ranking usa o mesmo `publicId` |
| **B** | necessidade competitiva antes do provisionamento | backlog `pendente`; nenhuma segunda autoridade acionada; após provisionamento oficial, retoma e converge |
| **C** | retry da criação de identidade | mesmo `publicId`, `criada: false` |
| **D** | retry do processamento | mesmo `publicId`, `ja_processado`, sem contribuição duplicada |
| **E** | processamento concorrente | uma identidade pública |

### Concorrência e idempotência

`garantirIdentidade` é à prova de corrida por construção: a decisão inteira
acontece dentro de uma transação que **lê** `playerIdentities/{uid}` antes de
escrever, e a reserva em `publicIdIndex/{candidato}` é conferida na mesma
transação — candidato já tomado faz sortear outro (até 5 tentativas).

Provado com seis chamadas simultâneas: um único id, exatamente uma delas
respondendo `criada: true`, e um documento de cada em cada coleção.

---

## 7. Projeções denormalizadas

O Ranking **copia** três campos, e os três são projeção, nunca fonte:

| Campo em `rankingStandings` / `rankingPlayers` | Fonte canônica |
|---|---|
| `publicPlayerId` | `playerIdentities/{uid}.publicId` |
| `apelido` | `publicProfiles/{publicId}.apelido` |
| `avatar` | `publicProfiles/{publicId}.avatarRef` |

Projeção significa: quem quiser saber o apelido de verdade lê o perfil público.
A cópia existe para a lista não precisar de N leituras, e uma cópia velha nunca
torna o perfil errado — só a lista atrasada.

Até esta OS, `apelido` e `avatar` nasciam vazios porque não havia fonte no
backend (registrado como dependência aberta em `RESULTADO-BACKEND-RANKING.md`).
Agora há.

**Perfil ausente preserva o que já havia, e nunca cai para o uid.** É §31-F do
contrato social — "não usar UID como fallback caso apelido ou avatar estejam
ausentes" — provado do lado competitivo.

Alteração de apelido/avatar: não muda `publicId`, não muda rating, não muda
histórico competitivo, não cria jogador novo.

`avatarRef` no perfil, `avatar` na linha: os dois nomes já existiam nos dois
contratos, e renomear um deles seria mexer em contrato de cliente por estética. A
tradução acontece em `apresentacoesCanonicasDe`, uma vez.

---

## 8. UID × publicId

Serviços autenticados continuam trabalhando com UID internamente. Publicamente:

- `publicProfiles/{publicId}` é a identidade pública canônica;
- `rankingStandings` guarda `uid` porque é a chave de **escrita** e é negado a
  todo cliente pelas Rules; a linha só sai **projetada**, por
  `projetarJogador`, que troca o uid pelo `publicPlayerId`;
- nenhuma API pública exige que outro jogador conheça o UID de alguém.

A solução impede, e cada impedimento tem prova:

| Não pode acontecer | O que impede |
|---|---|
| um UID com dois `publicId` | `playerIdentities` é endereçada por uid; a transação lê antes de escrever |
| dois UIDs com o mesmo `publicId` | reserva em `publicIdIndex` conferida na transação |
| jogador reivindicar `publicId` alheio | `garantirIdentidade(uid, apelido)` não tem parâmetro de id; Rules negam escrita do cliente |
| rotação involuntária após retry | leitura do existente antes de sortear |
| duplicação por concorrência | transação + reserva |
| criação paralela por Ranking e Social | o Ranking não tem gerador |

---

## 9. Como se prova que o Ranking não cunha mais

`functions-ranking/test/identidade.test.js` varre a **árvore de fontes** e falha
se qualquer uma destas voltar:

1. import de aleatoriedade (`randomBytes`, `randomUUID`, `crypto`, `Math.random`);
2. função que produza id (`idPublicoDeBytes`, `garantirIdPublico`,
   `reservarIdPublico`, `cunharIdPublico`, `gerarIdPublico`);
3. indexação do alfabeto (`ALFABETO[...]`) — a forma mais curta de reconstruir um
   gerador sem usar nenhum dos nomes acima;
4. menção a `rankingPublicIds`;
5. escrita (`set`/`update`/`create`/`delete`, direta ou transacional) em
   `playerIdentities`, `publicIdIndex` ou `publicProfiles`;
6. a callable `garantirIdentidadePublica`.

**Por que varrer código-fonte em vez de chamar funções.** As outras suítes provam
comportamento: dado um estado, a função responde assim. Esta prova uma **ausência**
— "não existe, neste codebase, caminho que emita identidade" —, e ausência não se
prova chamando: a função que voltasse a existir teria nome novo e nenhum teste de
comportamento a chamaria.

É a mesma disciplina que o projeto já usa em `exigirRespostaSegura` (social) e
`acharCampoProibido` (projeção do ranking): varrer, em vez de confiar na revisão.

O mesmo arquivo confere que os **nomes** das três coleções canônicas batem com
`functions-social/src/chaves.ts` — os dois codebases não compartilham pacote npm,
então a repetição existe e é conferida por leitura do arquivo do vizinho.

---

## 10. Legado e reconciliação

`functions-social/src/auditoria.ts` (puro) + `functions-social/scripts/auditar-identidade.js`
(runner). Alvo: `npm run auditoria:emulador`.

**Dry-run por construção, não por promessa:** o módulo de decisão não importa
`firebase-admin` nem `getFirestore` — recebe o inventário já lido e classifica. O
runner não contém um único verbo de escrita, e `test/auditoria.test.js` prova as
duas coisas lendo os arquivos.

Contra produção, o runner recusa rodar sem `--eu-sei-que-e-producao`. A trava
existe porque a varredura é cara, não porque seja perigosa.

### Os sete achados de §15

| Código | Defeito | Severidade |
|---|---|---|
| `uid_sem_identidade` | UID sem identidade pública | reconciliável |
| `uid_com_dois_ids` | UID com mais de um `publicId` | **crítico** |
| `id_compartilhado` | mesmo `publicId` em UIDs diferentes | **crítico** |
| `projecao_aponta_para_id_inexistente` | documento competitivo → id inexistente | reconciliável |
| `projecao_divergente_do_canonico` | ranking com `publicId` ≠ canônico | reconciliável¹ |
| `perfil_orfao` | `publicProfile` sem dono | reconciliável |
| `projecao_orfa` | projeção competitiva sem uid | reconciliável |

¹ **crítico** quando a projeção carrega um id para um jogador **sem** identidade
canônica: é o rastro mais direto de uma segunda autoridade — o id existe, o
jogador existe, e não foi `playerIdentities` quem emitiu.

### Política de reconciliação (§16)

| Caso | Regra |
|---|---|
| 16.1 — Ranking sem `publicId` | associar ao canônico da Identidade Pública |
| 16.2 — Ranking com `publicId` igual | nenhuma ação |
| 16.3 — Ranking com `publicId` divergente | **a Identidade Pública vence**; não criar id novo |
| 16.4 — dois ids históricos para o mesmo UID | conflito auditável; o canônico vence; os demais viram histórico e **não** são apagados sem decisão registrada. **Não escolher pelo mais recente.** |
| 16.5 — mesmo `publicId` em dois UIDs | conflito **crítico**; **não** sobrescrever automaticamente um jogador com o outro |

### Histórico competitivo (§17)

A reconciliação de identidade **não** zera rating, não reinicia colocação, não
consome de novo partidas de colocação, não altera liga nem posição, não duplica
contribuição, não perde histórico e não altera o ledger competitivo.

`publicId` é identidade; não é chave semântica para reiniciar o jogador. A
referência pública muda, a carreira competitiva não recomeça.

**Nenhuma migração foi executada.** A primeira execução é dry-run, e a migração
é OS própria.

### Ledger (§18)

`rankingLedger` **não grava `publicId`** — a chave é `matchId|userId|motivo` e o
corpo carrega `userId`. Logo, não há registro histórico a reescrever, e o item 18
está satisfeito por construção: novos registros não podem divergir de um id que
eles não guardam.

---

## 11. O que a integração não podia mudar, e não mudou

**Política competitiva (§11):** rating inicial 1000, Elo, K=40 exclusivo da
colocação inicial, K=24 de classificados e revalidação, 10 partidas de colocação,
5 de revalidação, soft reset, faixas das ligas, critérios de desempate, política
de temporada, backlog, casual não pontua, torneio não alimenta Elo, elegibilidade.
Nenhum arquivo de regra competitiva foi tocado (`elo.ts`, `competicao.ts`,
`ligas.ts`, `politica.ts`, `temporadas.ts`, `apuracao.ts`, `ordenacao.ts`,
`ledger.ts` seguem idênticos a `cad4515`).

**Mesa Pública (§12):** continua casual, sem rating, sem liga, sem temporada, sem
posição — provado com identidade provisionada, que é a regressão imaginável
("agora que todo mundo tem identidade, a casual passou a criar linha").

**Torneios (§13):** continuam fora do Elo v1. A segunda guarda que impede
`alteraRanking` de tornar torneio elegível segue protegida por teste.

**VIP (§14):** identidade pública existe sem assinatura. VIP não compra rating,
não altera K, não melhora Elo, não muda colocação, não muda `publicId`, não
concede posição e não cria vantagem de partida. Nenhuma alteração em Billing.

**Grafo social:** intacto. Nenhuma funcionalidade social foi removida para
facilitar a integração.

---

## 12. Rules e índices

**Rules — alteradas, e a alteração aperta.** O bloco `rankingPublicIds` foi
**removido**: a coleção deixou de ter quem a escrevesse, e manter um `match` para
uma coleção que ninguém cria seria descrever uma porta de uma parede que não
existe. O fecho padrão (`match /{documento=**} { allow read, write: if false; }`)
a nega como nega qualquer caminho não declarado — o admin perdeu um `read` que
ali já era `false`, e nada foi afrouxado.

O arquivo passou a ser a união de **sete** blocos (social entrou como 6/7,
ranking virou 7/7), provados no **mesmo** `firestore.rules` por `test:integrado` —
que é onde um bloco poderia afrouxar o do vizinho, e social e ranking são
justamente os dois que falam de `publicId`.

**Índices — nenhum criado, nenhum alterado.** Os quatro caminhos criados ou
trocados resolvem por **ID de documento**, que o Firestore serve sem índice
declarado. Registrado em `firebase/firestore.indexes.json`, na chave
`//identidade-publica`.

> O emulador cria índice sozinho e **não** prova a necessidade de índice composto
> em produção. A conferência é por leitura do arquivo, e continua sendo portão de
> pré-deploy.

---

## 13. Functions no fluxo integrado

| Function | Codebase | Papel |
|---|---|---|
| `obterMinhaIdentidade` | social | **emite** (única) |
| `atualizarPerfilPublico` | social | apelido e `avatarRef` |
| `verPerfilPublico`, `localizarJogadorPorIdentidade` | social | leitura pública |
| `reconciliarPerfilSocial` | social | projeções sociais |
| `aoRegistrarResultadoOficial` / `processarResultado` | ranking | **consome** identidade |
| `abrirRanking` / `paginarRanking` | ranking | publica `publicPlayerId`, nunca uid |
| `consultarJogadorPorIdPublico` | ranking | resolve por `publicIdIndex` |
| ~~`garantirIdentidadePublica`~~ | ~~ranking~~ | **removida** |

Autenticação, App Check, claims e transacionalidade seguem como estavam. Nada foi
enfraquecido para facilitar teste: a suíte de integração usa dois `initializeApp`
justamente porque a topologia real são dois Admin SDK independentes.

---

## 14. Comportamento em falha

| Falha | Comportamento |
|---|---|
| identidade ausente no processamento | backlog `pendente`, retomável, idempotente |
| perfil público ausente | apelido/avatar preservam o anterior ou ficam vazios; **nunca** uid |
| colisão de id na emissão | detectada pela reserva; sorteia outro (5 tentativas), depois falha alto |
| falha parcial da transação competitiva | contribuição, ledger e classificação entram juntos ou não entram |
| retry após falha parcial | mesma chave de idempotência; nada dobra |
| leitura de identidade entre a guarda e a transação | pior caso é um ciclo de atraso (backlog), nunca um id errado |
