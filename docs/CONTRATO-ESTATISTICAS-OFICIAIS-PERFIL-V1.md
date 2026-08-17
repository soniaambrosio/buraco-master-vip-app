# Contrato canônico das estatísticas oficiais do Perfil — V1

**Natureza:** contrato executável, **sem ativação**. Nenhum escritor foi criado,
nenhum transporte foi ligado, nenhum documento do Firestore foi escrito, nenhuma
Rule foi alterada, nenhum deploy foi feito, nenhum XP foi concedido.

**Base:** `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`
@ `6e428e8575e2df4a504148a948305838cf3ff2d4`

**Referência somente leitura:** `claude/auditoria-estatisticas-perfil-v1-2b1039`
@ `73b9a548f98a34db41585d6b47f17ab618f9b47b` — o laudo
`docs/ARBITRAGEM-ESTATISTICAS-PERFIL-V1.md`, que emitiu
`FAIL — AUTORIDADES CONCORRENTES`. Este documento é a resposta a ele.

---

## 1. O que esta OS resolve, e o que ela deliberadamente não resolve

A arbitragem provou que **o mesmo fato físico — uma partida que acabou no
servidor Railway — produziria hoje dois registros divergentes dos mesmos oito
campos do Perfil**, com regras diferentes, identidade diferente e disciplina de
idempotência diferente.

Esta OS **não desliga** nenhuma das duas autoridades e **não liga** nenhuma
terceira. Ela escreve, de forma conferível e executável, **o que a autoridade
certa vai receber e como vai contar** — para que a arbitragem venha antes da
atividade, e não depois. Enquanto não houver escritor, não há como as duas
começarem a gravar ao mesmo tempo.

---

## 2. Decisões de produto aprovadas

| Assunto | Decisão |
|---|---|
| **Período** | **Vitalício.** Temporada pertence ao Ranking e não redefine os contadores do Perfil. |
| **Modalidades que contam** | Somente `publica_casual` e `publica_ranqueada`, concluídas autoritativamente. |
| **Modalidades que não contam** | `privada`, `treino`, `simulada`; partida cancelada; partida sem encerramento autoritativo; partida com identificador de demonstração; partida com robô participante ou substituição definitiva por robô. |
| **Reconexão** | Não cria ocorrência nova. O `matchId` é estável e é ele — não o `eventoId` — que entra na chave de lançamento. |
| **Abandono** | **Inelegível nesta versão.** Só produzirá estatística quando existir encerramento autoritativo **com responsabilidade identificável**. |
| **Resultado** | Cada jogador elegível recebe exatamente **uma** partida. Vitória e derrota são da **dupla**: os dois integrantes do lado vencedor recebem vitória, os dois do outro recebem derrota. |
| **Empate** | Todos recebem uma partida e um empate. **Ninguém** recebe vitória; **ninguém** recebe derrota. |
| **Aproveitamento** | `vitórias ÷ partidas concluídas elegíveis`, em porcentagem com uma casa. **Empate permanece no denominador.** Com zero partidas, `0` — nunca `NaN`, nunca infinito. **Derivado, nunca armazenado.** |
| **Canastras** | Fato **da dupla**. Cada integrante recebe crédito integral pelas canastras da sua dupla na partida. Limpas e sujas guardadas **separadas**; o total é derivado. Não se inventa qual parceiro "fez". |
| **XP / nível** | Contrato **reservado**, recompensa **não inventada**. `xpTotal` é vitalício e só pode ser concedido por política backend versionada. Nenhum XP é concedido aqui. |
| **Título** | Não pertence à autoridade das estatísticas. O título competitivo continua vindo de Ranking/conquistas. |

### 2.1 O efeito colateral aceito das canastras

Creditar a canastra inteira aos dois integrantes faz a **soma global de canastras
por jogador ser o dobro da soma por dupla**. Isso é consequência da decisão, não
um erro de conta, e está registrado aqui porque o número exibido responde
*"quantas canastras a minha dupla fez comigo na mesa"*, e não *"quantas eu fiz
sozinha"*. A alternativa — ratear meia canastra para cada um — produziria meio
número; a outra — escolher um autor — exigiria informação que **não existe em
lugar nenhum do sistema**.

### 2.2 Por que abandono não conta, em uma linha

O registro oficial marca que houve abandono e **não diz quem abandonou**
(`functions-ranking/src/projecao.ts:65-72`). Atribuir a derrota sem responsável
identificável é inventar; atribuí-la aos quatro, punir inocente.

---

## 3. As duas autoridades, e onde cada uma está agora

### Autoridade futura (a certa)

```
servidor Node → envelope FatoPartidaOficialV1
              → [ TRANSPORTE — não existe ]
              → escritor de estatísticas oficiais — NÃO EXISTE
              → EstatisticasOficiaisPerfilV1 por jogador
              → projeção pública por publicPlayerId
```

O que **existe** depois desta OS: o envelope, o redutor puro e o agregado. O que
**não existe**, e continua não existindo de propósito: produtor, transporte,
escritor, coleção, Rule e leitor.

### Autoridade concorrente ainda existente — **não desativada**

O **cofre local do servidor Node**, a fábrica `"contas"` de
`buraco-servidor@85d0eee` `server.js:3293`, persistida em `contas.json` num
volume do Railway. Ela está **viva em produção** e **não foi tocada por esta
OS** — nenhum arquivo do servidor foi alterado.

As cinco propriedades que a desqualificam, todas verificáveis no laudo:

1. **identidade errada** — id gerado no aparelho, não o UID nem o `publicId`;
2. **persistência errada** — arquivo em volume, não Firestore;
3. **sem idempotência** — `c.partidas += 1` a seco, protegido só por
   `sala.liquidada`, um booleano em memória;
4. **sem recorte de modalidade** — conta qualquer partida liquidada;
5. **empate vira vitória** — `placar.nos >= placar.eles ? "nos" : "eles"`
   (`server.js:3447`).

E ela conta canastras que **sempre valem zero**: `registrarPartida` lê
`j.canastras || 0`, e o único chamador monta cada jogador sem o campo.

> **O risco declarado pelo próprio servidor** (`server.js:4225`): *"cortar a
> economia local para a autoridade do Firestore vai exigir homologação e ativação
> coordenadas, senão o jogador recebe duas vezes"*. É por isso que esta OS não
> liga nada.

`contas.js` permanece **intocado e marcado como autoridade concorrente ainda não
desativada**. Desligá-lo é OS própria.

### O que também não foi tocado

* `projetarJogador` (`functions-ranking/src/projecao.ts:159`) — intocado.
  `aproveitamentoDe` do mesmo arquivo é **reusado** pelo agregado, de propósito:
  duas versões do mesmo número seriam o defeito que esta OS elimina.
* `PerfilService.statsDemo` continua `false`; o Perfil continua **escondendo o
  que não tem**, e os números de demonstração continuam inalcançáveis.
* `app/lib/` tem **delta zero**. `app/lib/main.dart` permanece byte-idêntico
  (blob `57d8ab1e098a4407fdcbff37838d62dc956cb6bd`).

---

## 4. Vocabulário de modalidade — fechado, e por quê

Existem hoje **três vocabulários incompatíveis**:

| origem | símbolos |
|---|---|
| domínio Dart (canônico) | `publica_casual`, `publica_ranqueada`, `privada`, `torneio`, `treinamento`, `contra_robos` |
| servidor Node | `publica`, `privada`, `simulada` — e o envelope emitido carrega `tipoPartida: "publica"`, que **não distingue casual de ranqueada** |
| ranking | `AMBIENTE_COMPETITIVO = ["publica_ranqueada"]`, um único elemento |

A enumeração deste contrato é **fechada** nos cinco símbolos aprovados
(`publica_casual`, `publica_ranqueada`, `privada`, `treino`, `simulada`) e **não
aceita nenhum dos outros como equivalente silencioso**. `"publica"` não vira
`"publica_casual"` por adivinhação — adivinhar aqui é decidir, sem arbitragem, se
a partida de alguém conta.

**Consequência prática, e ela é intencional:** o envelope que o servidor produz
hoje seria **recusado** por este contrato. A tradução é trabalho do **produtor**,
na próxima OS, porque quem sabe se a mesa nasceu ranqueada é quem a abriu.

**`torneio` não está na enumeração.** A decisão de produto diz "contam *somente*
Mesa Pública casual e Mesa VIP/ranqueada", e partida de torneio não está na
lista. Um envelope com `modalidade: "torneio"` é recusado como símbolo
desconhecido. O efeito é o mesmo de inelegível — nenhuma estatística —, mas o
diagnóstico é diferente, e isso está listado como risco residual na §10.

---

## 5. O contrato do fato — `FatoPartidaOficialV1`

Implementação de referência: `functions-ranking/src/estatisticas/contrato.ts`.
Artefato compartilhável: `docs/contratos/fato-partida-oficial-v1.schema.json`.

| campo | tipo | observação |
|---|---|---|
| `versaoContrato` | `1` | qualquer outro valor **recusa** o envelope |
| `matchId` | id estável | reconexão não o muda |
| `eventoId` | id estável | identifica a **afirmação**, não a partida |
| `encerradaEm` | ISO 8601 UTC com `Z` | instante autoritativo |
| `modalidade` | enum fechada de 5 | §4 |
| `estadoTerminal` | `concluida` \| `cancelada` \| `abandonada` | |
| `encerramentoAutoritativo` | booleano | desfecho observado/remontado/inferido é `false` |
| `ambienteCompetitivo` | booleano | **trava**: tem de ser exatamente `modalidade === "publica_ranqueada"` |
| `empate` | booleano | verdadeiro exatamente quando `ladoVencedor` é `null` |
| `ladoVencedor` | `nos` \| `eles` \| `null` | |
| `equipes.{nos,eles}` | `pontos`, `canastrasLimpas`, `canastrasSujas` | canastra é da dupla |
| `participantes[4]` | `uid`, `publicPlayerId`, `equipe`, `assento`, `classe`, `substituidoPorBot` | os quatro assentos, sempre |
| `houveSubstituicaoPorBot` | booleano | conferido contra os assentos |
| `origem` | `autoridade` (`motorDePartidas` \| `admin`), `instancia` | espelha o claim de `registrarEncerramentoPartida` |

### Regras do analisador — **aceita ou recusa, nunca normaliza**

Não completa campo ausente com zero, não converte texto em número, não apara
espaço, não adivinha modalidade. Cada normalização silenciosa viraria uma regra
de negócio escondida num analisador.

Recusas específicas, além das de tipo e de enumeração:

* **propriedade inesperada em qualquer nível** — envelope, `equipes`, cada
  equipe, cada participante e `origem`;
* **identificador de demonstração** — `matchId`/`eventoId` que comece por `demo`,
  `test`/`teste`, `mock`, `exemplo`, `sample`, `fixture` ou `fake`;
* **`publicPlayerId` fora do formato canônico** — validado por `idPublicoValido`
  de `functions-ranking/src/identidade.ts:93`, **reusado e não reimplementado**;
* **lei da mesa violada** — pares são `nos`, ímpares são `eles`
  (`app/lib/rastreabilidade/registro_partida.dart:145-146`; a mesma conta em
  `server.js:1729`). Assento 1 declarado em `nos` recusa o envelope;
* **assentos que não sejam exatamente {0,1,2,3}**, ou identidade repetida na mesa;
* **`ambienteCompetitivo` incoerente com a modalidade**;
* **`empate` e `ladoVencedor` contraditórios**;
* **`houveSubstituicaoPorBot` que não bate com os assentos**.

### Recusa de envelope ≠ partida inelegível

São respostas distintas de propósito. **Envelope recusado** é defeito do produtor
e merece alarme. **Partida inelegível** é o dia a dia — a maior parte das mesas é
privada ou de treino — e não merece nenhum.

---

## 6. O agregado — `EstatisticasOficiaisPerfilV1`

Implementação: `functions-ranking/src/estatisticas/agregado.ts`.

**Guardado:** `versaoContrato`, `partidas`, `vitorias`, `empates`, `derrotas`,
`canastrasLimpas`, `canastrasSujas`, `xpTotal`, `versaoXp`, `atualizadoEm`.

**Derivado, nunca guardado:** `canastras` (limpas + sujas), `aproveitamento`,
`nivel`.

> Guardar um derivado é criar uma segunda autoridade sobre o mesmo número. Se ele
> divergir da conta, o derivado está errado — e quando é persistido, não há como
> saber disso.

### Invariantes

1. todos os contadores são **inteiros não negativos**;
2. `partidas = vitorias + empates + derrotas`;
3. total de canastras é `canastrasLimpas + canastrasSujas`;
4. aproveitamento fica entre **0 e 100**, e é `0` — nunca `NaN` — com zero
   partidas;
5. **`xpTotal` tem de ser `0` enquanto `versaoXp` for `null`**;
6. valor ilegível, fracionário ou negativo é **recusado**, nunca normalizado.

### Idempotência — onde ela mora, e onde ela não mora

`aplicarDelta` é puro e **não** decide se um lançamento já aconteceu: uma função
pura não tem como saber, e fingir que sabe seria a forma mais rápida de contar
duas vezes. A idempotência é do **escritor**, pelo id do documento, no padrão que
o codebase já usa (`functions-ranking/src/resultado.ts:478`).

Duas chaves determinísticas são fornecidas:

| chave | forma | serve para |
|---|---|---|
| `chaveDoFato` | `matchId\|eventoId` | reconhecer **entrega repetida do mesmo evento** |
| `chaveDeLancamento` | `matchId\|publicPlayerId\|estatisticasOficiais\|v1` | id do documento de lançamento por jogador |

O `eventoId` fica **fora** da chave de lançamento de propósito: reconexão e
reenvio produzem eventos diferentes para a mesma partida, e se ele entrasse, cada
reenvio pareceria lançamento novo — que é exatamente o defeito do cofre local.

---

## 7. Identidade, privacidade e a obrigação que fica registrada

* **UID** é identidade **interna**. Ele existe no envelope porque o backend
  precisa dele para achar o documento, e **não** existe no delta. A fronteira é
  essa linha.
* A projeção pública usa **exclusivamente `publicPlayerId`**.
* É proibido publicar: UID, e-mail, identificador do aparelho, chave local de
  `contas.js`, código interno da sala, parceiro ou adversários da partida, e
  histórico detalhado sem autorização específica.

**Obrigação formalizada, não implementada:** antes de a estatística real aparecer
em Perfil **visitado**, é pré-condição que ou (a) a exclusão da conta remova a
estatística pública identificável, ou (b) o registro histórico seja anonimizado de
maneira irreversível. Esta OS **não** implementa exclusão. Publicar estatística
agregada antes disso cria dado pessoal publicável sem política de remoção — e
isso precisa ser sequenciado, não descoberto depois.

---

## 8. Artefato compartilhável

`docs/contratos/fato-partida-oficial-v1.schema.json` — JSON Schema
2020-12, independente de linguagem, para ser espelhado pelo servidor Railway na
próxima OS.

| | |
|---|---|
| **git blob (LF, como versionado)** | `9c23c651f7121efc9d3605f743b125810910d8de` |
| **sha256 do conteúdo versionado** | `d4bf6dc6008ed711f5a507199f8683628693baac064341765b9ee9f893e53dfc` |
| **bytes** | 24.569 |

Contém enumerações fechadas, campos obrigatórios, `additionalProperties: false`
em **todos** os níveis, versão explícita (`x-versaoContrato`), **2 exemplos
válidos** e **9 exemplos inválidos** com o motivo de cada um.

**O schema e o código são conferidos um contra o outro por teste**, e não por
boa vontade: os exemplos válidos têm de passar pelo analisador, os inválidos têm
de ser recusados por ele, e as cinco enumerações e a lista de campos obrigatórios
são comparadas símbolo a símbolo com as constantes do TypeScript. Um schema que
diverge do analisador é pior do que nenhum: promete ao vizinho uma forma que a
nossa porta não aceita.

Três invariantes **não são expressáveis** em JSON Schema e estão declarados
dentro do próprio arquivo (`x-invariantesNaoExpressaveis`): assentos exatamente
{0,1,2,3}, identidade não repetida na mesa, e coerência de
`houveSubstituicaoPorBot`. Os três são conferidos pelo analisador e por teste.

**Zero dependência nova.** Nenhum validador de schema foi adicionado — a
conferência usa o próprio analisador do contrato, o que é mais forte do que
validar contra uma biblioteca: prova que a **nossa porta** aceita o que o
artefato promete.

---

## 9. Matriz mínima — 30 casos, todos verdes

Suíte: `functions-ranking/test/estatisticas.test.js` (**69 testes**, 0 falhas).

| # | caso | resultado |
|---|---|---|
| 1 | pública casual concluída conta | ✔ |
| 2 | pública ranqueada concluída conta | ✔ |
| 3 | privada não conta | ✔ |
| 4 | treino não conta | ✔ |
| 5 | simulada não conta | ✔ |
| 6 | cancelada não conta | ✔ |
| 7 | sem encerramento autoritativo não conta | ✔ |
| 8 | robô participante torna inelegível | ✔ |
| 9 | dupla vencedora: duas vitórias | ✔ |
| 10 | dupla perdedora: duas derrotas | ✔ |
| 11 | empate: quatro partidas e quatro empates | ✔ |
| 12 | empate produz zero vitória | ✔ |
| 13 | empate produz zero derrota | ✔ |
| 14 | canastra limpa creditada aos dois parceiros | ✔ |
| 15 | canastra suja creditada aos dois parceiros | ✔ |
| 16 | adversário não recebe canastra da outra dupla | ✔ |
| 17 | reconexão mantém o mesmo `matchId` | ✔ |
| 18 | duplicação de `eventoId` é identificável | ✔ |
| 19 | UID nunca aparece na projeção pública | ✔ |
| 20 | identificador local do aparelho é recusado | ✔ |
| 21 | zero partidas produz 0% | ✔ |
| 22 | aproveitamento inclui empate no denominador | ✔ |
| 23 | agregado negativo é recusado | ✔ |
| 24 | quebra de `partidas = resultados` é recusada | ✔ |
| 25 | versão desconhecida é recusada | ✔ |
| 26 | campo inesperado no envelope é recusado | ✔ |
| 27 | XP permanece zero sem concessão autorizada | ✔ |
| 28 | nenhuma fórmula local de nível é promovida | ✔ |
| 29 | título não é calculado pelo redutor | ✔ |
| 30 | nenhuma escrita externa acontece | ✔ |

Além da matriz, a suíte prova: abandono inelegível (6b), substituição definitiva
por robô (8b), o cofre local e o UID recusados como `publicPlayerId` (20b, 20c),
XP sem política recusado pelo agregado (27b), ausência de implementação de
política de XP (28b), a lei da mesa, a coerência de ambiente competitivo e
empate, instantes malformados, mesa incompleta, identidade repetida, e a
coerência integral com o schema.

### O caso 30, e por que ele é estrutural

Nenhum teste de comportamento prova a **ausência** de um efeito que ninguém
chamou. A prova é sobre o texto: uma varredura do código-fonte dos três módulos,
**com os comentários removidos**, atrás de `firestore`, `firebase-admin`,
`admin.`, `FieldValue`, `collection(`, `.set(`, `.update(`, `.delete(`,
`increment`, `onCall`, `onDocument`, `onSchedule`, `fetch(`, `XMLHttpRequest`,
`require(`, `process.`, `Date.now`, `Math.random`, `setTimeout`, `setInterval` e
`console.`. E uma segunda varredura confirma que os módulos só importam
`../identidade`, `../projecao`, `./contrato` e `./agregado`.

---

## 10. Provas negativas por mutação — 12 injetadas, 12 mortas

Cada mutação foi injetada, **conferida pelo `git diff --numstat`** (para provar
que atingiu o arquivo certo), executada contra a suíte inteira e revertida. As
doze **compilaram** — logo, cada morte é comportamental ou estrutural, e não um
erro de compilação disfarçado de cobertura.

| # | mutação | arquivo (numstat) | caiu |
|---|---|---|---|
| M01 | contar Mesa Privada | `contrato.ts` (+1) | caso 3 |
| M02 | contar Treino | `contrato.ts` (+1) | caso 4 |
| M03 | transformar empate em vitória | `redutor.ts` (+1/−1) | caso 12 |
| M04 | retirar empate do denominador | `agregado.ts` (+1/−1) | caso 22 |
| M05 | creditar canastra a apenas um parceiro | `redutor.ts` (+1/−1) | casos 14 e 16 |
| M06 | aceitar partida com robô | `redutor.ts` (+1/−1) | casos 8 e 8b |
| M07 | aceitar modalidade desconhecida | `contrato.ts` (+1/−1) | "modalidade desconhecida é RECUSADA" e a coerência dos exemplos inválidos do schema |
| M08 | expor UID na projeção | `redutor.ts` (+1/−1) | **caso 19** e mais seis |
| M09 | permitir contador negativo | `agregado.ts` (+1/−1) | caso 23 |
| M10 | incorporar a fórmula local de XP | `agregado.ts` (+1/−4) | caso 28 |
| M11 | exportar nova Cloud Function | `index.ts` (+3) | "nenhuma Cloud Function nova nasce" |
| M12 | executar I/O no redutor | `redutor.ts` (+1) | a varredura estrutural do caso 30 |

Árvore restaurada e suíte de volta a **399 passes, 0 falhas** depois da última
reversão.

---

## 11. Portões executados

| portão | antes | depois |
|---|---|---|
| `functions-ranking` — `npm test` (tsc + unitários) | 330 passes, 0 falhas | **399 passes, 0 falhas** |
| suíte nova do domínio | não existia | **69 passes, 0 falhas** |
| `tsc --noEmit` (`npm run lint`) | limpo | **limpo** |
| Rules — `emulador:integrado` (5 suítes, um `firestore.rules`) | — | **147 passes, 0 falhas** (1 SKIP: Functions sociais, que este alvo não sobe) |
| Ranking — `test:emulador` (integração contra o Firestore) | — | **27 passes, 0 falhas** |
| exports do entrypoint `functions-ranking/src/index.ts` | **11** | **11** |
| varredura de segredos no diff | — | **nada encontrado** |
| fecho produtivo a partir de `main.dart` | **44 arquivos** | **44 arquivos, idêntico** |
| delta em `app/` | — | **zero** |
| delta em `firebase/` e `firebase.json` | — | **zero** |
| dependências novas | — | **zero** |

Rules e o fecho produtivo têm "antes = depois" **por construção**: `firebase/` e
`app/` têm delta zero, e nenhum arquivo do servidor foi tocado.

**Testes de economia e de conquista:** não existem como suíte de backend nesta
base — economia vive em `functions-billing` e as menções a conquista estão em
suítes Flutter (`app/test/casca/`, `app/test/ranking/`). Como `app/` e
`functions-billing/` têm delta zero, nenhuma delas é alcançável por esta
mudança. Isto está registrado como **não executado por não ser afetado**, e não
como executado.

---

## 12. O que muda no deploy: nada

`functions-ranking/src/index.ts` **não importa** este domínio. Os três módulos
compilam e ficam em `lib/`, sem que nenhuma Cloud Function nova nasça — a
contagem de `export const` do entrypoint continua **11**, e há teste que reprova
se ela mudar.

`firebase.json` não foi tocado. A escolha de **onde o futuro escritor mora**
(este codebase ou um próprio) fica em aberto de propósito: `functions-ranking` é
onde o domínio pôde ser provado hoje — tem o gate de `tsc`, a suíte, a cobertura
de CI e a função `aproveitamentoDe` que o agregado reusa —, mas as estatísticas
são **vitalícias** e o ranking é **por temporada**, e essa diferença pode
justificar unidade de implantação separada quando o escritor existir.

---

## 13. Riscos residuais

1. **A autoridade concorrente continua viva.** `contas.js` grava hoje, em
   produção, com empate virando vitória e sem recorte de modalidade. Esta OS não
   a desligou, e nada aqui impede que ela continue.
2. **O produtor não fala este contrato.** O envelope atual do servidor não tem
   `canastrasSujas`, não distingue casual de ranqueada, e usa `partidaId` /
   `placarFinal` / `duplaVencedora` onde este contrato usa `matchId` / `equipes`
   / `ladoVencedor`. **Todo envelope produzido hoje seria recusado.**
3. **`canastrasSujas` não tem fonte.** A distinção limpa/suja existe no motor
   (`app/lib/mesa.dart:380` e `:509`, contadas em `:278`), mas **para no `Jogo`**:
   `LadoDaMesa` só propaga `canastrasLimpas`. Propagá-la é trabalho de quem
   emitir o fato.
4. **`torneio` é recusado como símbolo desconhecido**, e não como modalidade
   conhecida e inelegível. O efeito prático é o mesmo (nenhuma estatística), mas
   o diagnóstico difere e o produtor não consegue sequer relatar uma partida de
   torneio. Se a resposta desejada for "torneio conta" ou "torneio é
   explicitamente inelegível", isso é decisão de produto e muda a enumeração.
5. **Sem política de exclusão de conta.** A obrigação está formalizada (§7) e não
   implementada. Publicar estatística no Perfil visitado antes dela cria dado
   pessoal sem caminho de remoção.
6. **`players/{uid}`, o leitor órfão** de `functions/src/index.ts:78-117`,
   continua lá e continua devolvendo `nivel: null`. Enquanto existir, é uma
   quarta resposta latente para "qual é o nível deste jogador".
7. **A barreira de identificador de demonstração é por nome**, e portanto
   grosseira. Ela serve contra fixture, não contra adversário; contra adversário
   quem vale é o claim `motorDePartidas`.

---

## 14. Próximos passos, na ordem em que destravam

1. **OS — Canonização da modalidade e do envelope de encerramento V1.** Fazer o
   Railway emitir **exatamente** este contrato: vocabulário canônico, decisão de
   onde a mesa nasce ranqueada, `canastrasSujas` propagada, e a tradução
   `partidaId → matchId`. Ainda sem autoridade concorrente nova.
2. **OS — Desligamento do cofre local.** Decidir o destino de `contas.json`
   (descartar / arquivar), sabendo que ele guarda **totais sem eventos** e que seu
   id **não é o UID** — não é migrável com fidelidade. Inclui o que acontece com
   o cliente HTML, hoje seu único consumidor.
3. **OS — Transporte autenticado Railway → Functions**, com o claim
   `motorDePartidas` e os estados que a outbox já reservou.
4. **OS — Escritor e coleção**, com Rules e índice, usando `chaveDeLancamento`
   como **id de documento** — nunca `increment` sem chave.
5. **OS — Política de exclusão de conta e anonimização.** Precede a publicação da
   estatística em Perfil visitado.
6. **OS — Leitor do Perfil.** A menor de todas: trocar o corpo de
   `PerfilService.carregar()` pela leitura real, sem mudar assinatura nem visual.
   Os tipos anuláveis já estão certos.
7. **Nível, XP e título como produto.** Nenhuma OS de engenharia os resolve: não
   há fórmula aprovada, catálogo nem regra de concessão. Até que existam, o certo
   é o que o Perfil já faz — **não desenhar**.

---

*Emitido em 2026-08-17. Nenhuma escrita produtiva, nenhum deploy, nenhuma Rule
alterada, nenhum arquivo do servidor tocado.*
