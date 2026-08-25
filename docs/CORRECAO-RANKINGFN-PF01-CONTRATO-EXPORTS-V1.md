# Correção — `rankingfn` PF-01 e o contrato de exports V1

**Base:** `integracao/perfil-social-funcional-raiz-p-v1` @ `21ddf47b6320c1e5ddf1c64659d928b68c1f0889`
**Branch:** `correcao/rankingfn-pf01-contrato-exports-v1`
**Natureza:** correção independente de dívida herdada. **Não** reabre nem altera o PASS de `21ddf47`.

---

## 1. O vermelho, reproduzido

    functions-ranking $ npm test
    ℹ tests 462   ℹ pass 461   ℹ fail 1

    ✖ PF-01: NENHUMA Cloud Function produtiva nova é exportada
      AssertionError: functions-moderacao/src/index.ts mudou de superfície de deploy
      11 !== 9

Idêntico ao registrado em `docs/COMPOSICAO-PERFIL-SOCIAL-RAIZ-P-V1.md` §7 (461/462).

## 2. A divergência era de OUTRA codebase

A OS descreve o defeito como *"`functions-ranking`: PF-01 espera 9, implementação
tem 11"*. **Não é o que o vermelho diz**, e a diferença muda a decisão:

| entrada de PF-01 | esperado | disco | veredito |
|---|---:|---:|---|
| `functions/src/index.ts` | 7 | 7 | verde |
| `functions-moderacao/src/index.ts` | **9** | **11** | **a falha** |
| `functions-ranking/src/index.ts` | 11 | 11 | verde |
| `functions-social/src/index.ts` | 15 | 15 | verde |

`functions-ranking` **já esperava e já tinha 11**. A atribuição a `functions-ranking`
vem de o caso morar em `functions-ranking/test/passe.test.js` e reprovar o gate
`rankingfn` — o gate é do ranking, o assunto não era.

### Os onze exports de `functions-ranking`, nominalmente

`aoRegistrarResultadoOficial`, `processarResultado`, `abrirTemporadaDeRanking`,
`encerrarTemporadaDeRanking`, `reprocessarBacklogDeRanking`, `apurarRanking`,
`diagnosticarRanking`, `abrirRanking`, `paginarRanking`,
`consultarJogadorPorIdPublico`, `consultarHall`.

Os onze são de `0b0aa63` (autoridade única de `publicId`), têm consumidor no
cliente (`app/lib/ranking/ranking_transporte_firebase.dart`,
`app/lib/casca/ranking_de_producao.dart`), contrato publicado
(`docs/CONTRATO-RANKING-CLIENTE.md`) e Rules/índices correspondentes.

## 3. Prova de que a composição Perfil/Social não causou nada disto

    git rev-parse 5aa8263:functions-ranking/src   -> 7a3af094fe3af0c20e0a4a335a99e722831c6ebf
    git rev-parse 21ddf47:functions-ranking/src   -> 7a3af094fe3af0c20e0a4a335a99e722831c6ebf
    git rev-parse 5aa8263:functions-moderacao/src -> 373b5f1c469e7ef99b1351e42b12fb2a3843a275
    git rev-parse 21ddf47:functions-moderacao/src -> 373b5f1c469e7ef99b1351e42b12fb2a3843a275

Árvores idênticas: a composição não tocou nenhuma das duas.

## 4. Autoridade — os dois exports são canônicos, o piso é que era velho

`functions-moderacao` foi de **9 para 11** em `6986de9`
(*feat(comunicacao): autoridade canonica de comunicacao controlada v1*), com
`emitirEventoDeSistema` e `consultarCatalogoDeComunicacao`.

    f25026e  6      denúncia, bloqueio, sanção
    4522f41  8   ┐  Chat Livre Seguro V1
    3d124b0  9   ┘
    6986de9 11      Comunicação Controlada V1   <- os dois em questão

`git merge-base --is-ancestor 6986de9 5aa8263` → **verdadeiro**: os dois exports
são **anteriores à raiz P**.

O piso de `9`, por outro lado, foi congelado em `c9efc20`
(*merge(canonica): Passe VIP quinzenal e o codebase de ranking*), cujo comentário
no próprio caso registra o retrato que ele tirou: *"moderacao 6 -> 9 · O Chat
Livre Seguro trouxe `definirCanalDeChat`, `enviarMensagemChat` e
`enviarMensagemChatPeloMotor`"*. Aquela linhagem **não continha** `6986de9`. O
piso não ficou errado — ele nasceu anterior aos dois exports.

Os dois têm produtor, consumidor, contrato e documentação:

| | `emitirEventoDeSistema` | `consultarCatalogoDeComunicacao` |
|---|---|---|
| produtor | `functions-moderacao/src/index.ts:1429` | `functions-moderacao/src/index.ts:1569` |
| contrato | `contrato/chat-transporte-v1.json` → `funcoes.eventoDeSistema` | idem → `funcoes.catalogo` |
| documentação | `docs/COMUNICACAO-CONTROLADA-V1.md` §9 e §11 | idem §4 e §11 |
| já congelado | `ferramentas/composicao/loja_functions.test.js` (gate `composloja`) | idem |
| autorização | única porta de evento **sem autor** | leitura do catálogo autoritativo da UI |

**Decisão: os 11 são canônicos nas duas codebases.** Remover qualquer um dos dois
quebraria a Comunicação Controlada V1 e contrariaria uma lista já congelada e
verde sob outro gate — além de exigir mexer em Functions fora de
`functions-ranking`, que a OS proíbe.

## 5. O que mudou

### `functions-ranking/test/passe.test.js` — PF-01 deixa de contar

A expectativa numérica virou **relação nominal exata** por codebase
(`SUPERFICIE_IMPLANTADA`), comparada com `assert.deepEqual` contra o que o disco
de fato exporta, lido sem comentário pela **mesma** extração de
`ferramentas/composicao/loja_functions.test.js`.

Um número não distinguia "entrou export novo" de "trocaram um export por outro",
e reprovava sem dizer qual. A relação nominal responde às três perguntas —
sumiu? renomearam? entrou um décimo segundo? — e faz a atualização aparecer no
diff com o nome da função dentro dela.

### `functions-ranking/test/superficie.test.js` — a guarda da guarda (novo)

Uma relação nominal tem um jeito de morrer que a contagem não tinha: esvaziar a
lista, ou trocar o corpo do caso por fachada, mantendo nome e registro. A guarda
**mora fora do arquivo que ela guarda** — uma guarda dentro de `passe.test.js`
some junto com ele e é trivializada pela mesma edição.

- **SF-01** — PF-01 existe, está no alvo explícito do `npm test`, usa
  `deepEqual` sobre `SUPERFICIE_IMPLANTADA`, e a relação **escrita** nele é, nome
  por nome, a do disco.
- **SF-02** — a lista congelada em `ferramentas/composicao/loja_functions.test.js`
  também é a do disco.

As duas apontam para o **disco**, não uma para a outra: assim as duas listas
ficam impedidas de divergir sem que nenhuma vire "a fonte" da outra. E PF-01
devolve a gentileza exigindo que `SF-01` e `SF-02` continuem existindo.

### `functions-ranking/package.json`

`test/superficie.test.js` entra no alvo explícito do `npm test` (alvo nominal, não
glob — um arquivo novo não passa a rodar sem alguém decidir).

**Nada fora de `functions-ranking/` foi tocado.** Ranking, Hall, Perfil, Social,
Amigos, presença, convites, trava de 30 dias do apelido, arquitetura P de gates,
`firebase.json`, workflow e `scripts/ci/` estão byte a byte como em `21ddf47`.

## 6. Provas

    functions-ranking  npm test                       exit 0   464/464  (era 461/462)
    composloja         node --test loja_functions      exit 0    35/35
    composneg          node --test negativas           exit 0    21/21

`rankingfn` **não tem bloco de contrato** (`suite`/`sha256`/`provas`) em
`scripts/ci/gates_os_integracao.txt`, e nenhuma linha de contrato daquele arquivo
cita `passe.test.js`, `superficie.test.js` ou `functions-ranking/package.json` —
então `contratosui` não podia regredir por esta mudança, e a fonte única não foi
editada.

### Campanha de mutação — 13/13 detectadas

| | mutação | reprova por |
|---|---|---|
| M1 | export obrigatório **desaparece** (`consultarHall`) | PF-01 |
| M2 | export **renomeado** (`aplicarSancao` → `aplicarSancoes`) | PF-01 |
| M3 | **12º export** não aprovado em `functions-ranking` | PF-01 |
| M4 | **12º export** não aprovado em `functions-moderacao` | PF-01 |
| M5 | a validação **volta a conferir só quantidade** | SF-01 |
| M6 | a relação nominal de PF-01 é **esvaziada** | SF-01 |
| M7 | um nome é **apagado** da relação de PF-01 | SF-01 |
| M8 | o **caso PF-01 é apagado** de `passe.test.js` | SF-01 |
| M9 | `passe.test.js` **sai do alvo** do `npm test` | SF-01 |
| M10 | `superficie.test.js` **sai do alvo** do `npm test` | SF-01 |
| M11 | a **guarda some** (SF-01/SF-02 removidos) | PF-01 |
| M12 | a lista congelada da composição **diverge** do disco | SF-02 |
| M13 | `passe.test.js` é **apagado** | alvo nominal do `npm test` quebra |

Limite honesto: M11 prova que trivializar **um** dos dois arquivos cai. Desmontar
os **dois** no mesmo commit passa — como em qualquer par recíproco finito. O que
se garante é que a remoção não é silenciosa: ela aparece inteira no diff.

## 7. Fora de escopo, registrado

- O comentário `//` do bloco `ranking` em `firebase.json` ainda lista
  `garantirIdentidadePublica`, que foi removida em `0b0aa63`, e o do bloco
  `moderacao` lista só as seis originais. São comentários — o Firebase implanta o
  que o `index.ts` exporta, não o que o manifesto descreve —, mas estão
  desatualizados. Corrigi-los exige tocar `firebase.json`, fora do escopo desta OS.
- `docs/COMPOSICAO-PERFIL-SOCIAL-RAIZ-P-V1.md` §7 atribui a falha a
  `functions-ranking`. Não foi editado: aquele documento é o registro do PASS de
  `21ddf47`, e §0 desta OS proíbe alterá-lo. Este relatório é a errata.
