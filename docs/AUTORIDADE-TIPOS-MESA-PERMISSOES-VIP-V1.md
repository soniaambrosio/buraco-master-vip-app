# OS 2 — ARBITRAGEM E CANONIZAÇÃO AUTORITATIVA DOS TIPOS DE MESA, PERMISSÕES VIP E PASSE DE CORTESIA V1

**Natureza:** arbitragem + composição controlada + implementação autoritativa.
Dois repositórios.

---

## 1. BRANCHES EFETIVAS

| Repositório | Branch | Base | SHA da base |
| --- | --- | --- | --- |
| `buraco-master-vip-app` | `claude/autoridade-tipos-mesa-permissoes-v1` | `integracao/release-canonica-predeploy-v1` | `8ee179dba919ede73002a76255eb72aff2e2c7d9` |
| `buraco-servidor` | `integracao/mesa-privada-vip-individual-v1` | `integracao/gate-vip-credencial-backend-v1` | `e4bad5218a1d5b2215c370ecff577d4c2a8d6509` |

A branch preferencial da OS (`claude/autoridade-tipos-mesa-permissoes-v1`) não
existia e foi criada com o nome exato. A branch pré-criada pelo ambiente
(`claude/autoridade-tipos-mesa-permissoes-v1-30449f`) nascia de `0cea0d6`
(`consolidacao/apk-geral-bmv`) — uma linhagem **sem nenhum diretório de
Functions**, sem `firebase.json` e sem Rules. Ela foi abandonada, não movida.

---

## 2. GATE ZERO

### 2.1 A ref que contém `e4bad521…`

O SHA citado pela OS tem 39 caracteres (falta um dígito). O objeto real é
`e4bad5218a1d5b2215c370ecff577d4c2a8d6509`, e ele **não está no repositório do
aplicativo**: ele é a ponta de `integracao/gate-vip-credencial-backend-v1` no
repositório **`buraco-servidor`**, publicada em `origin`.

Duas consultas independentes às refs remotas (`git ls-remote origin` nos dois
repositórios, 143 e 17 refs respectivamente) confirmam:

| Entrega | Repositório | Ref | SHA |
| --- | --- | --- | --- |
| Gate VIP/Ranqueada | servidor | `claude/gate-autoritativo-entrada-vip-ranqueada-v1` | `504d68fe9eaa5af6d26c880e95fcf23b3bf553d8` |
| Credencial renovável do motor | servidor | `claude/credencial-renovavel-motor-railway-v1` | `85d0eee5286fd1deba5c2ae85176b76e714e6690` |
| Correção do Secure Token | servidor | `correcao/credencial-motor-secure-token-v2` | `deed131f7f880cee3c86d1c7c12f184d459b5e08` |
| **Admissão VIP composta** | servidor | `integracao/gate-vip-credencial-backend-v1` | **`e4bad521…6509`** |
| Composição credencial V2 + UUID | servidor | `integracao/credencial-motor-v2-auditoria-uuid-v1` | `c8ab95c427cfb66d3cd6d6c991a3ff617b45a637` |
| Correção do falso positivo de UUID | servidor | `correcao/teste-espectador-uuid-falso-positivo-v1` | `fd99260b07a25be6587c017bd172d21ebff4f641` |
| Fluxo de mesas | app | `integracao/fluxo-mesas` | `7a75bab49ca18a2876f43f69996de4903b9d6ccc` |
| Auditoria do passe quinzenal | app | `auditoria/passe-vip-quinzenal-cortesia-v1` | `afd08b766d99601be1c9402bec39f79485a996d3` |
| RC predeploy (base escolhida) | app | `integracao/release-canonica-predeploy-v1` | `8ee179dba919ede73002a76255eb72aff2e2c7d9` |

### 2.2 Ancestralidade — repositório do servidor

```
                7e7572b (versionamento da visão)
                 /            \
   504d68f (gate VIP)      85d0eee (credencial)          fd99260 (UUID)
            \                 /                             |
             c1c5007 ——— merge                              |
                  \                                         |
                   a04b18a ——— merge deed131                |
                        \                                   |
                      e4bad52  ────── esta OS ────► 99cf718 (merge fd99260)
                                                          |
                                                      274c50d
```

`merge-base(e4bad52, c8ab95c) == deed131`. As duas linhagens do servidor
divergem: `c8ab95c` tem `fd99260` e **não** tem o gate nem o adaptador;
`e4bad52` tem o gate e o adaptador e **não** tem `fd99260`. Esta OS fechou a
divergência pelo lado barato — mesclou `fd99260`, cujo diff **não toca uma
linha de código de produção** (`server.js` é byte a byte idêntico antes e
depois do merge, conferido por `git diff --stat HEAD~1 HEAD -- server.js`).

### 2.3 Ancestralidade — repositório do aplicativo, e a divisão declarada

**A base canônica do aplicativo ESTÁ DIVIDIDA.** Isto é registrado aqui como a
OS manda, e a decisão de prosseguir está justificada logo abaixo.

Três linhagens, nenhuma contendo outra (`git branch --contains` por marcador):

| Marcador | Linhagem | Contém |
| --- | --- | --- |
| `8ee179d` | `integracao/release-canonica-predeploy-v1` | **os 8 codebases de Functions**, `android/`, `servidor/`, `web/`, VIP client enforcement (`921f3fd`) |
| `e0cf917` | `correcao/ci-composicao-perfil-mesa-ranking-v2-v1` | portão de CI (36 gates), perfil + mesa online + ranking real V2, ligação `4b3c460` |
| `41a767a` | `integracao/avatar-publico-ranking-real-v2-v1` | avatar público + ranking real V2 |

Nenhuma ref do repositório contém `8ee179d` **e** `e0cf917`.

**Por que isso não bloqueou a OS.** A divisão é real e é *client-side*. Medida
sobre as superfícies que esta OS toca, `8ee179d` é **superconjunto estrito**:

```
git diff --stat 8ee179d e0cf917 -- functions-* firebase firebase.json
  → 54 arquivos, 124 inserções, 16.764 REMOÇÕES
```

Ou seja: as linhagens mais recentes estão **atrás** no backend — faltam-lhes
`functions-conta`, `functions-economia`, o RTDN, a reconciliação, o backfill, o
repositório social e os testes de entitlement. `functions-ranking` é idêntico
nas duas. Começar por `e0cf917` significaria implementar a autoridade sobre um
backend do qual metade não existe.

Todas as edições desta OS ficam em `functions-mesas/` (novo), `functions-conta/`,
`firebase/firestore.rules` e `firebase.json`. **Nenhum arquivo de `app/lib/` foi
tocado** — que é exatamente a superfície em que `e0cf917` e `41a767a` estão à
frente. A composição futura é uma união sem interseção.

### 2.4 O caminho produtivo, ponta a ponta

| Pergunta da OS | Resposta ANTES desta OS | Resposta DEPOIS |
| --- | --- | --- |
| quem cria a mesa | `criarMesa` no servidor, via `msg` | igual |
| quem escolhe o tipo | configuração do processo (`TIPO_PARTIDA`, `CATEGORIA_COMPETITIVA`) | igual |
| quem valida o tipo | `normalizarCategoria` (servidor) | + `traduzirDoServidor` (backend), que recusa combinações impossíveis |
| quem valida o VIP | **ninguém** — o adaptador respondia `SEM_URL` | `admitirEmMesaVip`, sobre `playerEntitlements` |
| quem emite a credencial | `credencial_motor` (servidor), claim `motorDePartidas` | igual |
| quem consome a cortesia | **ninguém — a cortesia não existia** | a transação de `admitirEmMesaVip` |
| quem confirma a cadeira | `admitirNoAssento` → `concluirAdmissao` | igual, agora com resposta real |
| quem registra o início | `iniciarPartida` (servidor) | igual |
| quem decide se pontua | `TipoDePartida.alteraRanking` (Dart) | igual — esta OS **consome**, não redefine |

### 2.5 Concorrência com a OS de Presentes

`claude/presentes-sociais-autoridade-f1444c` existe como worktree em
`0cea0d6` e **não tem nenhum commit** — nem publicada, nem local. Delta previsto
zero.

Ainda assim, esta OS foi desenhada para não colidir com ela **mesmo que ela
avance**: o passe de cortesia mora em coleção própria (`passesVip/{uid}`), e
`functions-mesas` **não escreve em `playerEntitlements`** — há teste estrutural
que varre `src/` inteiro e falha se aparecer uma escrita
(`ELE-ESP-03`). Nenhuma dependência sequencial declarada.

---

## 3. O CONTRATO DOS QUATRO TIPOS

Autoridade única: `functions-mesas/src/tipos.ts`.

| Tipo canônico | Ranking | Exige VIP individual | Cortesia serve | Aposta | Espectadores | Código | Cadeiras |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `publica` | não | não | — | **não** | não | não | não |
| `vipRanqueada` | **sim** | sim | **sim** | sim | sim | não | não |
| `privada` | não | **sim** | **não** | sim | sim | **sim** | **sim** |
| `treino` | não | não | não | não | não | não | não |

### A tradução das duas dimensões do servidor

O servidor não fala esta taxonomia. Ele fala `tipoPartida` × `categoriaCompetitiva`,
e a tradução é explícita, num ponto só, com as combinações impossíveis
**recusadas** em vez de adivinhadas:

| tipoPartida | categoria | resolve para |
| --- | --- | --- |
| `publica` | `casual` | `publica` |
| `publica` | `vip_ranqueada` | `vipRanqueada` |
| `privada` | `casual` | `privada` |
| `privada` | `vip_ranqueada` | **RECUSA** — seria sala fechada alimentando o Ranking |
| `simulada` | qualquer | `treino` |
| qualquer outra coisa | | **RECUSA** |

`categoria desconhecida` **não** vira `casual`. Rebaixar transformaria erro de
configuração em mesa aberta e gratuita, em silêncio, justamente na dimensão que
decide quem paga.

### Não existe `isVip`

Um booleano colaria duas perguntas que **divergem justamente na Mesa Privada**:

```
"esta mesa exige elegibilidade VIP?"  →  vipRanqueada E privada
"esta mesa alimenta o Ranking?"       →  SÓ vipRanqueada
"a cortesia serve aqui?"              →  SÓ vipRanqueada
```

`TAX-14` cai se alguém simplificar as duas primeiras numa só.

---

## 4. MATRIZ FINAL DE PERMISSÕES

| Ação | Pública | VIP/Ranqueada | Privada | Treino |
| --- | --- | --- | --- | --- |
| criar | autenticado | autenticado | **assinatura ativa** | local |
| ingressar | autenticado | assinatura **ou** cortesia | **assinatura ativa própria** | — |
| ocupar cadeira | autenticado | assinatura **ou** cortesia | **assinatura ativa própria, por cadeira** | — |
| controlar cadeiras | — | — | **só o proprietário** | — |
| ver como espectador | conforme política existente | idem | idem | — |
| alimentar Ranking | não | **sim** | não | não |
| movimentar carteira | não | conforme economia canônica | conforme economia canônica | **não** |

**O código da Mesa Privada não é benefício.** Ele localiza a sala. Possuir o
código não concede assinatura, entitlement nem direito de ocupar cadeira; um não
assinante com código válido é recusado (`DEC-PRI-02`, `INT-10`). Uma assinatura
não libera familiares nem convidados: a elegibilidade é conferida **por
ocupante**, no instante da admissão (`DEC-PRI-03`, `PRI-02`).

A cortesia quinzenal **não** autoriza Mesa Privada, e a recusa tem motivo próprio
(`CORTESIA_NAO_SERVE_PRIVADA`) para que o operador distinga "a regra funcionou"
de "faltou benefício" (`DEC-COR-05`, `INT-11`).

---

## 5. AUTORIDADES REUTILIZADAS, E A ÚNICA CRIADA

| Autoridade | Situação | Onde |
| --- | --- | --- |
| Gate de admissão ao assento | **reutilizado**, ampliado | servidor, `avaliarAdmissaoAoAssento` |
| Adaptador servidor → backend | **reutilizado**, intocado | servidor, módulo `admissao_vip` |
| Credencial renovável do motor | **reutilizada**, intocada | servidor, `credencial_motor` |
| Elegibilidade VIP (assinatura) | **reutilizada** — só leitura | `playerEntitlements`, do codebase `billing` |
| Carteira e economia | **reutilizada**, não redesenhada | `functions-economia` |
| Ranking / ambiente competitivo | **reutilizado** | `TipoDePartida.alteraRanking` + `functions-ranking` |
| Matriz de retenção | **estendida** | `functions-conta/src/inventario.ts` |
| **Passe quinzenal de cortesia** | **CRIADA** — não existia | `functions-mesas/src/passe.ts` |
| **Backend de `admissao-vip-v1`** | **CRIADO** — não existia | `functions-mesas/src/index.ts` |

### Por que ler `playerEntitlements` aqui não é um segundo leitor

`src/elegibilidade.ts` **não** consulta a Google, não interpreta RTDN, não decide
estado e não escreve. Ele lê o documento que a autoridade do Billing já escreveu
e aplica a mesma regra de vigência — estado com acesso **e** prazo correndo.

`require("../functions-billing/entitlement")` não serve: cada codebase tem
`source` próprio em `firebase.json`, e um `require` para fora do diretório
compila na bancada e quebra no deploy. O espelho de `ESTADOS_COM_ACESSO` é
conferido por teste **contra o arquivo original** (`ELE-ESP-02`), pelo padrão que
`functions-conta/src/plano.ts` já usa para `STATUS_INSCRICAO_ATIVA`.

---

## 6. O PONTO EXATO DE CONSUMO DA CORTESIA

`functions-mesas/src/firestore.ts`, dentro de `db.runTransaction`, no mesmo
`tx` que grava `admissoesDeMesa/{tentativaEntradaId}` e a âncora de assento.

**Não existe instante** em que o passe esteja gasto e a admissão não exista, nem
o contrário.

O que **não** consome: abrir a tela, escolher modalidade, alterar configuração,
voltar da tela, ser recusado por qualquer motivo, entrar em mesa pública, ter
assinatura ativa, reconectar ao próprio assento.

**As duas idempotências, que não são a mesma:**

| | Chave | Mecanismo |
| --- | --- | --- |
| **repetição** (retry de rede) | mesma `tentativaEntradaId` | `admissoesDeMesa/{id}` já existe → devolve o resultado anterior, sem efeito novo |
| **concorrência** (dois aparelhos) | tentativas *diferentes*, mesmo passe | as duas transações tocam `passesVip/{uid}`; o Firestore serializa, a segunda reexecuta e lê `usadoEm` preenchido |

O adaptador do servidor já deduplica concorrência **do transporte** (voos
compartilhados por `tentativaEntradaId`). A divisão é essa: lá se deduplica o
voo, aqui se deduplica a repetição **e** a disputa pelo direito.

**Abandono não devolve o passe.** Não há função de devolução, e a ausência é o
entregável: `PAS-21` varre a superfície do módulo e falha se aparecer qualquer
`devolver|estornar|reembolsar|restaurar|desfazer`.

### O calendário do passe

```
índiceJanela = floor((agora − âncora) / 15 dias)
recebidoEm   = âncora + índice × 15 dias
expiraEm     = recebidoEm + 7 dias
```

A chave de idempotência é o **índice da janela**, derivado do calendário — nunca
a data. É essa propriedade que faz duas execuções simultâneas colidirem no mesmo
documento. Uma chave por timestamp não teria.

Assinante ativo **não recebe**, e a âncora **não se move**: quem cancela volta a
receber na primeira janela seguinte, sem carência artificial criada por ter sido
cliente pagante (`PAS-10`, `PAS-11`).

Expiração é **conclusão do relógio na leitura** — não há agendador, e não há
escrita no segundo do vencimento (`PAS-15`).

---

## 7. ARQUIVOS ALTERADOS

### `buraco-master-vip-app` — 3 commits

```
edfc3e2  feat(mesas): dominio canonico dos tipos de mesa, politica e cortesia
1685d49  feat(mesas): admissao autoritativa, contrato admissao-vip-v1
70bdbc1  feat(mesas): regras das colecoes novas e matriz de retencao
```

| Arquivo | |
| --- | --- |
| `functions-mesas/src/tipos.ts` | novo — taxonomia e tradução |
| `functions-mesas/src/politica.ts` | novo — campos e valores por tipo |
| `functions-mesas/src/passe.ts` | novo — passe quinzenal, domínio puro |
| `functions-mesas/src/salas.ts` | novo — código, impressão, limitador, cadeiras |
| `functions-mesas/src/elegibilidade.ts` | novo — leitura de assinatura (espelho) |
| `functions-mesas/src/decisao.ts` | novo — o veredito, puro |
| `functions-mesas/src/firestore.ts` | novo — a transação |
| `functions-mesas/src/index.ts` | novo — `admitirEmMesaVip` + 3 callables |
| `functions-mesas/test/*.test.js` | novo — 7 suítes puras + 1 de emulador |
| `functions-mesas/{package.json,tsconfig.json,.gitignore}` | novo |
| `firebase.json` | + codebase `mesas` |
| `firebase/firestore.rules` | + bloco de 6 coleções |
| `functions-conta/src/inventario.ts` | + 7 itens de retenção |
| `functions-conta/src/plano.ts` | + etapa `mesas` |

### `buraco-servidor` — 2 commits

```
99cf718  merge: incorpora a correcao do falso positivo de UUID (fd99260)
274c50d  feat(mesa-privada): elegibilidade por ocupante, codigo com entropia,
         e a aposta fora do cliente
```

| Arquivo | |
| --- | --- |
| `server.js` | `gerarCodigoPadrao`, `apostaDeEntrada`, `tipoPartidaDeclarado`, gate |
| `test/gate_vip.test.js` | `MESA-11` reescrito, `MESA-11b` e `MESA-11c` novos |
| `test/mesa_privada.test.js` | novo — 18 provas |

---

## 8. OS TRÊS DEFEITOS ENCONTRADOS NO SERVIDOR

### 8.1 O código da sala tinha ~13 bits

```js
"BURACO-" + Math.floor(1000 + Math.random() * 9000)     // NOVE MIL códigos
```

Gerador **não criptográfico**, espaço percorrível em segundos por um script.
Numa mesa que exige VIP de cada ocupante isso nem é a pior parte: a pior parte é
que o código, sendo adivinhável, vira um canal de descoberta de quem está
jogando com quem.

Agora: 8 símbolos de um alfabeto de 25 (**~37 bits**) a partir de
`crypto.randomBytes`, reduzidos por **rejeição** e não por módulo — 256 não é
múltiplo de 25, e o módulo daria aos seis primeiros símbolos ~1,22× a chance dos
demais. `COD-03` (mil códigos, mil valores) derruba sozinho o gerador antigo;
`COD-05` mede a planura da distribuição sobre 40 mil símbolos.

O banco guarda a **impressão SHA-256**, nunca o código, e a impressão é o **id do
documento** — o que torna a enumeração impossível em vez de difícil (`INT-14`).

### 8.2 O cliente escolhia o valor de entrada

`criarMesa` lia `msg.aposta`, e `sala.aposta` alimenta `registrarPartida`, que
move o cofre de moedas. O cliente escolhia quanto o cofre movimentava.

Agora é configuração do **processo** (`apostaDeEntrada`), com padrão **zero** e
normalização fechada (configuração inválida vira zero, nunca `NaN`). `APO-01`
prova estruturalmente que `msg.aposta` não é lido em ponto nenhum do transporte.

### 8.3 A topologia PADRÃO é `privada`, e isso quase trancou o jogo

`TIPO_PADRAO` é `privada` — ele descreve a verdade da base e responde a outra
pergunta ("esta partida conta para conquista pessoal?"). A primeira versão desta
OS fez a exigência de VIP olhar para a topologia **resolvida**, e o resultado foi
a suíte inteira travando: toda instância não configurada passou a exigir
autorização, sem adaptador para responder.

A exigência olha para a topologia **declarada**. Ninguém-declarou não é uma
declaração. `MESA-11c` existe para que isso não volte a acontecer.

---

## 9. TESTES EXECUTADOS

| Suíte | Casos | Falhas | Baseline na base |
| --- | ---: | ---: | --- |
| `functions-mesas` (puras: TAX, POL, PAS, SAL, DEC, ELE, ESP) | **142** | 0 | não existia |
| `functions-mesas` (emulador do Firestore: INT) | **21** | 0 | não existia |
| `functions-conta` (inventário, plano, reautenticação, diário) | **81** | 0 | **80/81 — falhava** |
| `buraco-servidor` (48 suítes) | **368** | 0 | 333/333 |
| **Total** | **612** | **0** | |

### A suíte de emulador pagou por si duas vezes

Ela existe porque os casos 24, 26 e 27 medem comportamento do **banco**, não do
código. Na primeira execução ela encontrou **um defeito de produção que nenhum
dobre de memória encontraria**, e na segunda encontrou um engano de teste:

1. **`resolverConviteDeMesaPrivada` gravava antes de ler.** O contador do
   limitador era gravado, e só então o vínculo do convite era lido — e o
   Firestore recusa transação que leia depois de escrever. **Toda resolução de
   convite falharia em produção.** Corrigido: as duas leituras acontecem juntas,
   antes de qualquer escrita, mesmo quando o limitador já vai barrar (uma
   leitura desperdiçada no caso raro é o preço de não ter dois caminhos, que
   divergiriam na primeira manutenção).

2. **`INT-10` esperava o motivo errado.** Um convidado sem assinatura numa Mesa
   Privada é recusado por `CORTESIA_NAO_SERVE_PRIVADA`, e não por
   `SEM_ASSINATURA_NEM_CORTESIA` — porque a admissão **materializa a janela do
   passe antes de decidir**, e portanto todo jogador que chega pela primeira vez
   *tem* cortesia. O motivo registrado diz a coisa certa ao operador: a regra
   funcionou, não faltou benefício. O teste ganhou também a asserção de que a
   cortesia dele **continua intacta** — ser recusado não pode cobrar.

### Mapa dos casos obrigatórios da OS

| § | Casos | Onde |
| --- | --- | --- |
| 12.1 Pública | 1, 3–9 | `DEC-PUB-01`, `TAX-09`, `POL-NEG-01/03/04`, `POL-01/02/04/05` |
| 12.1 Pública | 2 (sem sessão) | `index.ts` — `uidDe` lança `unauthenticated`; e o `onRequest` recusa 401 sem claim |
| 12.2 VIP | 10–13, 20 | `DEC-VIP-01/02/03/04`, `ELE-01/02/04`, `POL-NEG-05/06` |
| 12.2 VIP | 14–18 (credencial) | `verifyIdToken(token, true)` + claim; **as provas moram na suíte da credencial do servidor** (`CRED-*`, 60 casos) e não foram reimplementadas |
| 12.2 VIP | 19 | `ESP-05` + `TAX-11` |
| 12.3 Cortesia | 21–23, 25, 28–34 | `PAS-*`, `DEC-COR-*` |
| 12.3 Cortesia | 24, 26, 27 | `INT-02`, `INT-03`, `INT-04` — emulador, **21/21 verde** |
| 12.4 Privada | 35–50 (emenda) | `DEC-PRI-*`, `SAL-*`, `PRI-*`, `INT-09/10/11/12/13` |
| 12.5 Treino | 47–54 | `DEC-TRE-01/02`, `DEC-COR-07`, `POL-10`, `POL-NEG-07`, `TAX-09` |
| 12.6 Integração | 55–63 | suíte do servidor, verde (368), e `functions-conta` (81) |
| 12.6 | 64 (Presentes) | nenhuma extensão de entitlement foi tocada — `ELE-ESP-03` |

### §13 — provas de segurança ("não basta alterar no cliente")

`POL-NEG-01..11`, `DEC-NEG-01..04`, `APO-01/02`, `SAL-16`. Cobrem: enum do tipo,
rota, parâmetro, JSON, `isVip`, valor da entrada, `publicId`, código privado,
identificador da sala, papel de proprietário, marcador de Ranking e resultado do
Treino.

`DEC-NEG-01` monta o payload completo que um aplicativo modificado enviaria
(doze campos venenosos de uma vez) e exige que o veredito seja **idêntico** ao do
payload limpo.

---

## 10. ANÁLISE ESTÁTICA

```
functions-mesas   tsc --noEmit --strict   →  0 diagnósticos
functions-conta   tsc (inventario, plano, reautenticacao, diario)  →  0
buraco-servidor   sem analisador (JS puro, sem dependências)
```

`tsconfig.json` do codebase novo copia o de `functions-conta`: `strict`,
`noImplicitReturns`, `noUnusedLocals`, `noFallthroughCasesInSwitch`. Os dois
últimos são o que transforma "um tipo de mesa novo sem tratamento" em erro de
compilação, e não em `default` silencioso.

---

## 11. PROVA DE ÁRVORE LIMPA E NÃO PROPAGAÇÃO

- Árvore limpa nos dois worktrees ao final (`git status --porcelain` vazio).
- **Sem merge** em branch de integração geral, **sem PR**, **sem deploy**, **sem
  publicação na Play**.
- `main` intocada nos dois repositórios.
- Nenhum segredo, nenhuma URL de produção, nenhuma ativação.
- `npm start` do servidor continua `node server.js`, e o `package.json` dele
  continua sem `dependencies`.

**As branches locais ainda NÃO foram publicadas** — ver §12.

---

## 12. RISCOS RESIDUAIS E O QUE NÃO FOI EXECUTADO

1. **Como rodar a suíte de emulador nesta máquina.** Não é risco, é
   procedimento — e ele custou tempo para ser descoberto, então fica escrito.
   ```bash
   npm --prefix functions-mesas run test:emulador
   ```
   Três coisas que fazem esse comando falhar por motivos que não são o código:
   - o `java` do `PATH` não serve; o que funciona é o JBR do Android Studio
     (`C:/Program Files/Android/Android Studio/jbr/bin`, OpenJDK 21);
   - a porta **8080 costuma estar ocupada** por outra sessão de emulador. O
     sintoma é `Could not start Firestore Emulator, port taken`, e ele se parece
     com suíte quebrada. A saída é `--config` com um arquivo que declare outra
     porta (foi usada a 8099) — sem derrubar a sessão alheia;
   - `npm install` neste repositório deixou a árvore **incompleta duas vezes**
     (faltou `gaxios`, dependência transitiva de `gcp-metadata`). O sintoma é
     `Cannot find module 'gaxios'` vindo de dentro do `firebase-admin`, e não de
     código deste projeto. Conferir com
     `ls functions-mesas/node_modules/gaxios` antes de suspeitar do teste.

2. **As branches não foram publicadas.** O critério de aceite exige branch local
   e remota no mesmo SHA. Isso não foi feito: publicar é ação externa e não foi
   autorizada nesta OS. Comandos:
   ```bash
   git -C F:/Projetos/wt-tipos-mesa push -u origin claude/autoridade-tipos-mesa-permissoes-v1
   ```
   ```bash
   git -C F:/Projetos/wt-mesa-priv push -u origin integracao/mesa-privada-vip-individual-v1
   ```

3. **A base do aplicativo continua dividida.** Esta OS não a compôs — ela
   escolheu o lado correto para a superfície que tocou e manteve as edições
   fora de `app/lib/`. A composição mínima recomendada está em §13.

4. **O contrato `admissao-vip-v1` não carrega `tipoPartida`.** A topologia é
   derivada no backend de um fato do **protocolo**, e não de um palpite sobre o
   banco: o servidor só chama este endpoint em dois casos — `vip_ranqueada`, ou
   topologia `privada` declarada, que viaja como `casual`. Mesa pública casual
   **não chega aqui** (`PRI-05` mede isso do lado do servidor). Logo, `casual`
   no fio significa `privada`.

   **Uma versão anterior deste código deduzia a topologia pela existência de
   `salasPrivadas/{codigoDaSala}`, e isso era uma falha ABERTA:** uma sala
   privada ainda não registrada resolvia para `publica`, que não exige VIP
   nenhum — o dono sentava de graça na própria sala exclusiva, e o furo era
   invisível porque a entrada funcionava. `INT-18` existe para que não volte.

   Ainda assim, a derivação continua sendo derivação. A forma correta é
   `tipoPartida` entrar no contrato numa **v2**, com as duas pontas versionadas
   e o adaptador do servidor estendido — trabalho pequeno, e que deve ser feito
   antes de existir um terceiro caminho que chame este endpoint.

5. **A Mesa Privada precisa ser registrada ANTES de alguém sentar.** Com a
   derivação acima, uma sala privada não registrada recusa com
   `SALA_INEXISTENTE` — inclusive para o dono assinante. Isso é falha fechada,
   e é o comportamento correto; mas significa que a ordem
   `criar no servidor → registrar no backend → convidar` é obrigatória, e hoje
   nada a impõe do lado do cliente. Ordenar as duas chamadas é trabalho da OS
   visual, e é a primeira coisa que ela precisa acertar.

6. **O cofre local do servidor continua sendo uma segunda autoridade sobre
   estatística.** Esta OS tirou o valor de entrada das mãos do cliente e não
   unificou o cofre — isso é de outra OS, já registrada.

7. **`admitirEmMesaVip` é o primeiro `onRequest` do projeto.** A autenticação
   dele é feita à mão, num lugar só. Ela não tem App Check — de propósito, pelo
   mesmo critério de `registrarEncerramentoPartida`: quem chama não é um
   aparelho. A prova de autoridade é o claim `motorDePartidas` num token
   assinado, com `verifyIdToken(token, true)` para que credencial **revogada**
   pare de funcionar antes de expirar sozinha.

8. **A economia paga por modalidade sem olhar quem entrou como cortesia.**
   `functions-economia` credita por `publica_ranqueada`. Se a Mesa VIP for de
   uma modalidade que paga, o passe passa a ter valor econômico indireto. Não é
   defeito hoje — é decisão a tomar quando a mesa VIP existir de fato em
   produção.

---

## 13. RECOMENDAÇÃO PARA A OS SEGUINTE

**Antes da OS visual do "Onde jogar", duas coisas:**

1. **Executar a suíte de emulador** (§12.1). Sem ela, "consumo atômico e
   idempotente" é uma afirmação de projeto, não um fato medido.

2. **Compor a base do aplicativo.** A composição mínima é
   `8ee179d ∪ e0cf917`, e ela tem interseção de arquivos praticamente nula: uma
   linhagem tem o backend, a outra tem o cliente. A ordem importa — partir de
   `8ee179d` e trazer `e0cf917`, porque o backend é o lado que esta OS acabou de
   estender.

**Para a OS visual em si**, a autoridade já responde a tudo que a tela precisa
perguntar, e nada disso deve ser recalculado no Flutter:

| Pergunta da tela | Quem responde |
| --- | --- |
| tenho passe utilizável? quando vence? quando vem o próximo? | `consultarPasseDeCortesia` |
| que campos mostrar para este tipo? | `camposPermitidos(tipo)` |
| que valores oferecer? | `PONTOS_CANONICOS`, `TEMPOS_CANONICOS`, … |
| posso criar Mesa Privada? | `criacaoExigeAssinaturaAtiva` + o portão VIP existente |
| qual o convite da minha sala? | `registrarMesaPrivada` (uma vez, na resposta) |
| onde fica a sala deste convite? | `resolverConviteDeMesaPrivada` |

A tela **não** deve ter um caminho que decida admissão. Ela antecipa a recusa
para não empurrar o jogador a uma porta que vai fechar — e a porta continua sendo
`admitirEmMesaVip`.

Um ponto de atenção para o desenho: a tela de configuração atual
(`configurar_mesa_screen.dart`) oferece `[1500, 3000]`. A política canônica é
`[1500, 2000, 3000]`. Falta o 2.000 na tela, e ele não foi acrescentado aqui
porque §15 desta OS proíbe tocar interface.
