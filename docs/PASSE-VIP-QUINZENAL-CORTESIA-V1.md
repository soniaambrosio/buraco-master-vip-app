# OS 3 — Backend canônico do Passe VIP Quinzenal de Cortesia V1

> ## `PASS`
>
> **PASS — O PASSE VIP QUINZENAL DE CORTESIA TEM AUTORIDADE TRANSACIONAL ÚNICA**
>
> Uma porta só materializa o passe, dentro de transação; não há acumulação, não
> há acesso direto do cliente, não há autoridade concorrente, e o recibo
> idempotente está modelado e provado — **sem ativar a admissão VIP em
> produção**.
>
> **Zero Cloud Function nova · zero scheduler · zero deploy · zero segredo ·
> zero delta em Flutter e no servidor Railway · 18/18 mutações detectadas.**

| | |
| --- | --- |
| Base | `correcao/ci-composicao-perfil-mesa-ranking-v2-v1` @ `e0cf91791913e1345c9181e1fb2f0a0871d30fe2` |
| Branch | `claude/backend-passe-vip-quinzenal-cortesia-v1` |
| Referência (leitura) | `buraco-servidor` `integracao/gate-vip-credencial-backend-v1` @ `e4bad5218a1d5b2215c370ecff577d4c2a8d6509` |
| Arbitragem de origem | `auditoria/passe-vip-quinzenal-cortesia-v1` @ `afd08b766d99601be1c9402bec39f79485a996d3` |

As quatro referências foram confirmadas por duas consultas independentes ao
remoto (`git ls-remote` e API REST do GitHub) antes da primeira edição.

## Gate Zero

| Verificação | Resultado |
| --- | --- |
| Autoridade equivalente para o passe | **não existe** — `quinzenal`/`cortesia`/`passeVip` só aparecem como recorrência de torneio |
| `playerEntitlements` | é a autoridade da **assinatura paga**; não foi reutilizada |
| Escritor concorrente | nenhum |
| Scheduler existente | um só, `tickTorneios` (torneios), anterior a esta OS |
| Exports produtivos | 42, distribuídos em seis codebases |
| Árvore | limpa |

Baselines medidos antes de editar: `rankingfn` **330**, `rankingint` **27**,
`regras` **147**.

## O codebase escolhido, e por quê

`functions-ranking`. O passe governa a entrada na mesa **VIP/Ranqueada**, que é
a modalidade competitiva oficial — e a competição mora ali. É também o único
codebase TypeScript com transação, suíte de emulador e ciclos temporais já
estabelecidos (`temporadas.ts`), então o modelo nasce dentro dos padrões da casa
em vez de ao lado deles.

Não foi o `billing`: o passe de cortesia não passa pela Play, não tem recibo de
pagamento, não estorna e não renova por assinatura. Acoplá-lo ao ciclo de vida
de uma compra é exatamente a confusão que a OS manda evitar.

**Nenhum codebase novo foi criado** — criar um exigiria editar `firebase.json` e
acrescentaria superfície de implantação, que §10 proíbe.

## O modelo persistente

```
playerCourtesyPass/{uid} ............... CONTROLE  (retrato do ciclo vigente)
playerCourtesyPass/{uid}/cycles/{id} ... HISTÓRICO (um por ciclo, nunca apagado)
```

Controle: `versaoContrato`, `cicloAtualId`, `recebidoEm`, `validoAte`,
`proximaElegibilidadeEm`, `consumidoEm`, `cicloEncerradoEm`,
`ultimaMaterializacaoEm`.

Ciclo: o mesmo par de datas, mais `consumidoEm`, `encerradoEm`, `contextoDoRecibo`,
`tentativaEntradaId`, `admissaoId`, `versaoContrato`.

O `cicloId` é **opaco e não derivado** (`randomUUID`): não é o uid, não é a
data, não é posição e não é contador — todos se deduzem de fora, e um
identificador dedutível deixa de identificar. Há teste que afirma que dois
jogadores criando no mesmo instante recebem ids distintos e que nenhum contém o
próprio uid.

O histórico **não é apagado**: é dele que sai a idempotência do recibo.

## Autoridade temporal, e os limites exatos

```
validoAte              = recebidoEm +  7 dias
proximaElegibilidadeEm = recebidoEm + 15 dias
```

As duas fronteiras são **simétricas e opostas**, e isso é contrato:

| Instante | Resposta |
| --- | --- |
| `agora <  validoAte` | disponível |
| `agora == validoAte` | **já expirado** — sete dias é a duração, não o último instante |
| `agora <  proximaElegibilidadeEm` | aguarda, sem passe |
| `agora == proximaElegibilidadeEm` | **novo ciclo já pode nascer** |

Todo o cálculo é do backend, com relógio injetado nos testes (`agoraMs`). Em
produção vem de `Date.now()` do servidor; nenhuma data do cliente participa, e
há teste estrutural que afirma que a porta não lê nada de requisição.

**Consumir não antecipa nada. Expirar também não.** A âncora é `recebidoEm`, e
ela não se move — as duas situações caem no mesmo ramo `aguardar`.

**Ciclos perdidos não acumulam.** Um ciclo novo é ancorado no instante **real**
da materialização, não na elegibilidade que passou: quem sumiu dois meses recebe
**um** passe agora, e não quatro atrasados.

## A porta única, e a transação

`materializarPasseDeCortesia(uid, agoraMs)` — a única função do projeto que cria
ciclo, calcula data ou decide disponibilidade. A regra inteira mora em
`passe.ts` (puro); `firestore.ts` só a aplica.

Cinco ramos: `criar_primeiro`, `reaproveitar`, `criar_novo`, `aguardar`,
`falha_fechada`. **`reaproveitar` não escreve** — materializar de novo sem o
tempo passar não toca o documento, e isso é medido por `updateTime` no emulador,
não prometido pelo código.

Concorrência: oito chamadas simultâneas do mesmo jogador produzem **um** ciclo —
a transação reexecuta as perdedoras, que releem um controle que já tem ciclo. A
corrida da virada dos quinze dias tem caso próprio.

## Um defeito que só o banco pegou

A primeira proteção contra regressão de relógio era `ultimaMaterializacaoEm` com
`instanteEfetivo = max(agora, última)`. **A suíte pura passou e estava errada.**

O caminho que observa o passe vencido é `aguardar`, e `aguardar` não escrevia —
então o marcador nunca avançava, e um relógio que voltasse atrás encontrava o
passe outra vez dentro da validade. O teste puro passou porque o *fixture*
afirmava um estado (`ultimaMaterializacaoEm` adiantado) que o executor nunca
produzia. Só a prova contra o emulador (`PEE-03`) derrubou.

A correção troca **comparação por fato**: `cicloEncerradoEm` é gravado uma vez,
na primeira constatação de que o ciclo acabou. Dali em diante o ciclo está
encerrado porque está escrito — e escrito não depende de relógio. É o único
caminho de leitura que escreve, e escreve **no máximo uma vez por ciclo**
(`precisaEncerrar` já é falso na segunda consulta).

## Projeções

| | contém |
| --- | --- |
| Proprietário | `versaoContrato`, `disponivel`, `validoAte`, `proximaElegibilidadeEm` |
| Pública | existe **apenas** enquanto disponível; consumido ou expirado, **desaparece** |

Nenhuma das duas carrega uid, token, `tentativaEntradaId`, `admissaoId`,
`cicloId` nem campo interno de auditoria — afirmado nos quatro estados. Estado
malformado projeta ausência, e o motivo interno não vaza.

**O Flutter não foi alterado.**

## O recibo de admissão — modelado, não ativado

`planejarRecibo(ciclo, contexto, uidDoDono, agoraMs)` é puro: não escreve, não
sorteia e não consome.

| Situação | Plano |
| --- | --- |
| primeira vez desta tentativa | `consumir` |
| **mesma** `tentativaEntradaId` já consumiu | `recuperar` — o **mesmo** `admissaoId` |
| tentativa diferente, ciclo já consumido | `recusar` |
| tentativa de outro jogador | `recusar` |
| ciclo encerrado ou expirado | `recusar` |

A regra que isto existe para garantir: **uma queda de conexão depois da aprovação
não pode queimar o passe.** O servidor aprova, a rede cai, o jogador volta com a
mesma tentativa — porque é o gate de `buraco-servidor@e4bad52` que a cunha e a
conserva. Consumir de novo custaria quinze dias por causa de um cabo; recusar
tiraria a entrada que ele já ganhou. A resposta certa é a terceira.

### A idempotência é vinculada ao CONTEXTO ESTÁVEL

A primeira versão deixava `tentativaEntradaId` como chave **solta**: qualquer
pedido que reapresentasse aquela string — de outra sala, de outra partida, para
outro assento — receberia de volta o mesmo `admissaoId` e entraria numa mesa que
ninguém autorizou. Idempotência é *"mesma tentativa **no mesmo contexto**"*;
"mesma string" não é idempotência, é portão aberto.

O ciclo passou a persistir `contextoDoRecibo`, gravado **na mesma transição** que
o recibo — não existe instante com `admissaoId` sem contexto para conferi-lo:

| Campo | Por que é estável |
| --- | --- |
| `uid` | o dono do passe |
| `codigoDaSala` | a tentativa nasce depois de a sala ser escolhida |
| `identidadeDaPartida` | `partidaId`, congelado em `iniciarPartida`; `null` **é** um valor |
| `assento` | o gate cunha a tentativa depois de resolver o assento alvo |
| `categoriaCompetitiva` | imutável na sala, por construção do gate |

**O que fica de fora importa tanto quanto o que fica dentro:** `reconexao` (a
classificação) e tudo que é de transporte. Uma reapresentação quase sempre chega
classificada como reconexão — foi a conexão que caiu. Se isso entrasse no
contexto estável, a recuperação falharia exatamente no caso que ela existe para
atender.

| Situação | Resposta |
| --- | --- |
| mesma tentativa + mesmo contexto | `recuperar` — o mesmo `admissaoId` |
| mesma tentativa + sala/partida/assento/categoria diferentes | `contexto_divergente` |
| mesma tentativa + só `reconexao`/transporte diferentes | `recuperar` |
| mesma tentativa + contexto **ausente** no documento | `contexto_divergente` — quem não pode ser conferido não é recuperado |
| jogador diferente | `tentativa_de_outro_jogador`, antes de qualquer contexto |

`aplicarConsumo` é a única forma de produzir um ciclo consumido, e ela **não**
recalcula `proximaElegibilidadeEm`.

Nesta OS: **nenhum endpoint produtivo de admissão foi exportado, o Railway não
foi tocado e nenhum consumo real acontece.**

## Segurança (Rules, bloco 8/8)

`allow read: if false` e `allow write: if false` no controle **e** na
subcoleção — regra de Firestore não desce por herança, então `cycles` tem
`match` próprio.

É o bloco mais fechado do arquivo: em `playerModeration` o dono lê o próprio
documento; aqui **nem o dono**, porque o documento interno carrega
`tentativaEntradaId` e `admissaoId`, que são a chave de idempotência do consumo.
O que é dele, ele recebe pela projeção.

Nem o admin escreve por aqui. A autoridade escreve pelo Admin SDK, que não passa
por Rules — e é essa a única porta.

## Testes

| Suíte | Antes | Depois |
| --- | --- | --- |
| `rankingfn` (`functions-ranking npm test`) | 330 | **385** |
| `rankingint` (emulador) | 27 | **27** |
| `regras` (`test:integrado`, agora 8 blocos) | 147 | **161** |
| `passeint` (emulador, nova — GATE OBRIGATÓRIO) | — | **18** |
| `billing` | 13 | 13 |
| `socialfn` | 45 | 45 |
| `socialdom` · `torneiosfn` | verde | verde |

Alvos novos, seguindo a regra da casa de listas explícitas (nunca glob):
`functions-ranking` → `test/passe.test.js` no `npm test` e
`npm run test:emulador:passe`; `firebase/testes` → `npm run test:passe`, e
`passe.test.js` entrou no `test:integrado`.

### A suíte transacional é GATE OBRIGATÓRIO, nas três pontas

Ela rodava e não era portão — o mesmo defeito CI-02 que esta composição existe
para não repetir. Agora:

1. **fonte única** — `passeint` em `scripts/ci/gates_os_integracao.txt`
   (36 → **37 gates**);
2. **workflow** — passo `3f3` em `ci-os-integracao.yml`, que produz
   `exit_passeint`;
3. **prova de ausência** — se a suíte sumir, o passo escreve `nao_passeint`, e o
   agregador reprova em `nao_<gate>` por contrato do cabeçalho da fonte única.
   Apagar a suíte não deixa o portão verde: deixa vermelho.

Provado localmente contra o agregador real: todos os gates em `exit 0` → VERDE;
`exit_passeint` = 1 → **VERMELHO**; `nao_passeint` → **VERMELHO**
(`obrigatórios: 37 | verdes: 36`).

E dois invariantes novos no `portaoci`, para que remover qualquer uma das duas
pontas fique vermelho: `I4a` (o gate está na fonte única) e `I4b` (o YAML produz
`exit_passeint` **e** escreve `nao_passeint`).

### Um guarda que foi estreitado, e não afrouxado

`identidade.test.js` proibia aleatoriedade em **toda** fonte do ranking, porque
`randomBytes` era o insumo de `garantirIdPublico` — e o ranking não é a
autoridade de identidade pública. A premissa escrita ali era "um codebase que não
precisa de aleatoriedade para nada mais". Ela mudou: o passe exige id opaco por
contrato.

A saída não foi abrir o guarda. A aleatoriedade foi concentrada em
`src/ids_opacos.ts` — três linhas, sem Firestore, sem jogador, sem identidade —,
o guarda passou a isentar **esse arquivo e só ele**, e um caso novo varre a
exceção atrás de `publicId`, `publicPlayerId`, `playerIdentities`,
`publicIdIndex`, `uid` e `firestore`, além de exigir que ela continue com no
máximo oito linhas de código. Uma exceção que cresce deixa de ser exceção.

## Provas negativas — 18/18

Cada mutação foi aplicada, o delta em bytes medido, a matriz rodada, e o arquivo
revertido e conferido por `sha256`.

| # | Mutação | Δ bytes | Quem matou |
| - | --- | --- | --- |
| 1 | validade de oito dias | +1 | `PT-01/03/04`, `PE-03` (11) |
| 2 | ciclo de quatorze dias | −1 | `PT-01`, `PC-03/04/05` (10) |
| 3 | consumo reinicia a quinzena | +62 | `PR-08` |
| 4 | ciclos perdidos acumulam | +9 | `PC-05` |
| 5 | criação fora de transação | −27 | `PEK-01` (emulador) |
| 6 | duas chamadas, dois ciclos | +3 | `PEK-01/02` (emulador) |
| 7 | reutilização de `playerEntitlements` | 0 | `PF-03` |
| 8 | leitura direta pelo cliente | +42 | `PRL-01` (Rules) |
| 9 | escrita direta pelo cliente | +42 | `PRE-01..07` (Rules, 6) |
| 10 | UID na projeção | +34 | typecheck (`tsc`) |
| 11 | mesma tentativa consome duas vezes | −31 | `PR-02`, `PR-09` |
| 12 | export acidental de endpoint | +94 | `PF-01` |
| 13 | malformado normalizado em silêncio | +8 | `PE-07` |
| 14 | encerramento não registrado | −29 | `PC-10c` |
| **15** | **remove a conferência de contexto** (chave volta a ser solta) | −131 | `PR-02b`, `PR-02e` |
| **16** | aceita recibo **sem contexto** guardado | −1 | `PR-02e`, `PR-02f` |
| **17** | tira `passeint` da fonte única | −10 | `portaoci` (`I4a`) |
| **18** | tira o passo produtor de `exit_passeint` do workflow | +7 | `portaoci` (`I4b`) |

As quatro últimas entraram com a correção do veredito FAIL, junto com a
reexecução da #11 — que agora é morta por **três** casos em vez de dois, porque
`PR-02d` (reapresentação por reconexão) também exige a recuperação.

A #7 tem delta zero porque `playerCourtesyPass` e `playerEntitlements` têm o
mesmo comprimento; a aplicação foi confirmada pelo próprio roteiro, que aborta se
o texto não mudar. A #10 é morta pelo compilador, e não por asserção: o tipo
`ProjecaoDoProprietario` não declara `uid`, então o campo a mais não compila —
detecção legítima, e registrada como tal.

Mutações §12.13 (torneio/ranking/assinatura alterando a concessão) são cobertas
estruturalmente por `PEF-02`, que prova que materializar não escreve em
`rankingPlayers`, `rankingStandings`, `rankingLedger`, `matches`,
`playerModeration` nem `usuarios`.

## Declaração

Não houve **deploy**, **ativação**, **PR** nem **merge em `main`**. Nenhum
scheduler foi criado. Nenhuma Cloud Function produtiva nova foi exportada — a
contagem por codebase (7 / 6 / 11 / 14) é fixada por teste, e o `index.ts` do
ranking não importa o módulo do passe. Nenhum segredo entrou. Delta **zero** em
`app/` (Flutter) e no servidor Railway.

**Sobre `playerEntitlements`, com precisão.** A frase anterior deste laudo dizia
que ela "não foi lida, escrita nem mencionada", e isso era **falso** — a suíte
de emulador escreve nela. O correto:

* **`playerEntitlements` não foi reutilizada como autoridade.** Nenhum código de
  produção a lê, escreve ou menciona: `PF-03` varre `passe.ts` e `firestore.ts`
  e reprova se o nome aparecer;
* **a suíte de emulador escreve nela de propósito, como fixture.** `PEF-01`
  semeia `{vip:true, origem:"assinatura-paga"}`, roda três materializações e
  confere por `updateTime` que o documento **não foi tocado nem uma vez**. É o
  contrário de reutilizar: é a prova, contra o banco, de que a cortesia e a
  assinatura não se encostam;
* nas **Rules**, ela continua negada pelo fecho padrão do arquivo, e `PRF-01`
  afirma isso para os quatro papéis — o bloco 8/8 não abriu porta para ela.

## Riscos residuais

1. **A porta existe e não tem chamador.** `materializarPasseDeCortesia` e
   `projetarPasseParaODono` não são alcançáveis por nenhuma Cloud Function — por
   decisão da OS. Enquanto a admissão não existir, o passe só é materializado
   por teste. Isso é o desenho, mas significa que **nenhum jogador real tem
   passe hoje**.
2. **O consumo é planejado, não executado.** `planejarRecibo` e `aplicarConsumo`
   são puros e provados; falta a porta transacional que os aplique contra o
   banco — ela é da OS de admissão, junto com a emissão do `admissaoId`.
3. **`firestore.indexes.json` não foi tocado.** As duas coleções só são
   acessadas por id de documento, então nenhum índice composto é necessário
   hoje. Se a admissão passar a consultar ciclos por campo, o índice será
   preciso — e o emulador **não** cobra índice composto, então isso não
   apareceria nos testes.
4. **A monotonia depende de a autoridade ser consultada.** `cicloEncerradoEm` só
   é gravado quando alguém pergunta pelo passe depois de ele vencer. Um jogador
   que nunca mais abra o app e cujo relógio de servidor regrida entre duas
   consultas muito distantes ainda teria a janela — estreitíssima, e fechada na
   primeira consulta.
5. **O gate `regras` ficou mais pesado.** `test:integrado` passou de cinco para
   seis suítes no mesmo emulador; a corrida local leva ~2 min.
6. **Encadear `emulators:exec` na mesma sessão trava.** Três execuções em
   sequência fizeram a terceira ficar presa disputando a porta 8080 com o dreno
   da anterior — `emulators:exec` devolve o terminal antes de soltar a porta.
   Matar o processo no meio deixa o ambiente sujo e produz falhas que não são de
   lógica (uma corrida assim deu 7 falhas que não reproduzem). Rodar os gates de
   emulador **um por vez**, conferindo que 8080 e 4400 estão livres entre eles.
7. **O aquecimento do canal gRPC era cobrado de uma asserção.** A primeira
   chamada ao Firestore paga o estabelecimento do canal; numa máquina carregada
   isso levou **185 s**, e como ela caía dentro de `PEC-01`, o relatório fazia
   parecer que criar o primeiro passe era lento — quando todos os outros casos
   ficavam abaixo de 700 ms. Foi movido para um `before()` próprio, com a
   explicação no lugar. O custo continua existindo; o que mudou é que ele agora
   aparece onde é, e não disfarçado de defeito de lógica.
