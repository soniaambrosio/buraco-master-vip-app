# OS 40-C2 — Fechamento léxico e externo da guarda de exports V1

**Base:** `correcao/os40-c1-guarda-externa-exports-v1` @ `5371a874cccd32672c502c198b1c63ad86506966`
**Branch:** `correcao/os40-c2-guarda-lexica-exige-exports-v1`
**Natureza:** correção da **defesa**, de novo. A superfície nominal de exports não muda
um nome, `PF-01`/`SF-01`/`SF-02`/`SF-03` não mudam uma linha, e a Function não muda
uma resposta. Muda **o que a guarda aceita como prova**, e **quem responde pelas
exigências dela**.

---

## 1. A base, conferida

    git ls-remote origin refs/heads/correcao/os40-c1-guarda-externa-exports-v1
      5371a874cccd32672c502c198b1c63ad86506966

    refs/heads/correcao/os40-c1-guarda-externa-…       5371a874cc…
    refs/remotes/origin/correcao/os40-c1-guarda-…      5371a874cc…

Pai `50c8cb4a`, sem merge depois dele; `merge-base` com `origin/main` em `2ddadde7`.
Contido por `correcao/os40-c1-guarda-externa-exports-v1` e pelo remoto dela, e por
mais nenhuma branch. Árvore limpa na partida, não rastreados inclusive.

Linha de base medida **antes** de qualquer alteração:

    rankingfn      npm test                        exit 0   465/465
    FASE A         verificar_contrato_suites.sh    exit 0   16 contratos
    contratosui    teste_contrato_suites.sh        exit 1   40 ok / 1 falha (T27)

## 2. Os dois escapes, reproduzidos antes de consertados

### B9 — a agulha muda de lugar, e a guarda continua achando

A busca do contrato era feita sobre o arquivo com as **linhas** de comentário
removidas por expressão regular:

    codigo_de() { tr -d '\r\000' < "$1" | grep -avE '^[[:blank:]]*("//|//|#)'; }

Isso deixa passar tudo o que não é linha inteira de comentário. Reproduzido em
`5371a87`, num movimento só:

    1. a guarda funcional some
       -  assert.ok(/assert\.deepEqual\(/.test(corpoDoCaso(GUARDA, "SF-01")), …);
       +  const inerte = `corpoDoCaso(GUARDA, "SF-01")`; void inerte;
    2. o digest é realinhado na fonte      sha256 → 5e99135225d0ef9b…

    FASE A                exit 0   "16 conferido(s), tudo no lugar"
    functions-ranking     exit 0   465/465

Verde nos dois lados, com a exigência `corpoDoCaso(GUARDA, "SF-01")` satisfeita
por um **template string** e a afirmação que ela protegia apagada.

### D9 e D9b — o manifesto guardava a si mesmo

As relações `exige` protegiam a suíte, e **nada protegia as relações**.

    D9   apagar da fonte:  exige  corpoDoCaso(GUARDA, "SF-01")
         FASE A            exit 0   "16 conferido(s), tudo no lugar"

    D9b  apagar a relação E a afirmação, e recarimbar o digest
         FASE A            exit 0
         functions-ranking exit 0   465/465

D9b é o escape completo: nada na árvore fica vermelho, e a guarda que a OS 40-C1
entregou deixa de existir sem deixar rastro.

### O T27, reproduzido nos seus dois motivos

    CONTRATO DE SUITE: 'contratosui' executou 34 caso(s) e o piso e 40 — a suite encolheu
    CONTRATO DE SUITE: o gate 'rankingfn' nao deixou log (…/t_rankingfn.log ausente ou vazio)
      … e mais onze gates na mesma situação

## 3. Código executável, e não texto que o imita

### A regra, e a decisão que ela carrega

Mais expressão regular não fecha B9, e não por falta de esforço: **uma varredura
sem estado não sabe se um `//` está dentro de uma string, nem se uma aspa está
dentro de um comentário.** O que fecha é ler o arquivo com **estado**, caractere a
caractere. Isso mora em `scripts/ci/codigo_executavel.awk` — um lexer determinista,
sem dependência nova, em `awk` porque a bancada deste gate declara por escrito que
roda **sem Node**.

Ele classifica cada caractere como CÓDIGO ou INERTE e responde uma pergunta:

> a agulha CONTA quando ao menos **um** caractere da ocorrência é código.

Não é "a agulha não pode encostar em string". `test("PF-01:` encosta de propósito:
`test(` é código e `"PF-01:` é o literal do nome do caso. O que a regra recusa é a
ocorrência **inteiramente contida em região inerte** — que é a forma de toda forja:
prosa que imita programa.

**Delimitador é inerte.** A aspa que abre a string pertence ao literal. Se ela
contasse como código, qualquer string teria âncora e voltaria a satisfazer o
contrato — que é exatamente o buraco a fechar.

### O que é inerte, por linguagem

| | inerte |
|---|---|
| `js` / `ts` | `//`, `///`, `/* */`, `'…'`, `"…"`, template, **literal de regex** |
| `dart` | idem, mais `'''`/`"""` e o `r'…'` cru; sem regex (o dart não tem literal) |
| `sh` | `#` em início de palavra, `'…'` (cru), `"…"`, `` `…` ``, `$'…'` |
| `json` | **nada**, exceto o par de chave de comentário `"//…": …` |

`json` é a exceção de propósito, e ela é decisão: **JSON não tem código.** Um
manifesto é dado do primeiro ao último byte, e exigir âncora de código nele
reprovaria todo `exigealvo` que existe. O que é inerte lá é a chave de prosa
`"//…"` — que é como este repositório documenta `scripts` —, e agora quem a
reconhece é um leitor com estado, e não um casamento de linha.

### Interpolação é código, e isso é explícito

Dentro de `${…}` (dart, js, e o `"…"` do sh, mais o `$(…)` do sh) o que está
escrito **executa** — então volta a valer como código. O **texto literal** do
template, em volta, continua inerte. A campanha prova as duas metades separadas:
`M5` e `M6` movem a agulha para o texto de um template de uma linha e de um
multilinha, e as duas ficam vermelhas. O `$nome` simples do dart **não** conta como
código: é um nome, e não uma expressão.

### Extensão desconhecida REPROVA

Adivinhar "deve ser código" seria a porta de saída: bastaria renomear a suíte para
uma extensão que o lexer não conhece e a agulha voltaria a valer em qualquer lugar.
`.js`/`.ts`/`.mjs`/`.cjs`, `.dart`, `.sh`/`.bash` e `.json` são o que ele lê; o
resto é `SEMLINGUA`, e `SEMLINGUA` é vermelho (`T50`).

### A sentinela

Um comentário de bloco sem fechar apagaria o arquivo inteiro, e **toda busca por
ausência ficaria verde** — o modo mais silencioso de uma guarda textual morrer. O
lexer emite `ABERTO` quando o arquivo termina dentro de comentário ou string, e
`SEMCODIGO` quando não achou uma linha de código. Os dois são vermelhos.

### A consequência: uma agulha precisa de âncora

Treze das oitenta e uma exigências da fonte única eram **conteúdo puro de string**
e passaram a ser recusadas com `INERTE` — a mensagem distingue "nunca esteve lá" de
"está lá, mas só como texto". Elas foram **reancoradas na fonte**, sem tocar em
suíte nenhuma:

| gate | antes | agora |
|---|---|---|
| `comunicacao` | `'ESP-02 CONTROLE` | `'ESP-02 CONTROLE: … em ${mesa.key}',` |
| `portaoci` | `GATES="[a-z]+ [a-z]+` | `grep -qE 'GATES="[a-z]+ [a-z]+` |
| `portaoci` | `for k in [a-z]+ [a-z]+ [a-z]+` | `grep -qE 'for k in [a-z]+ [a-z]+ [a-z]+'` |
| `contratosui` (10) | `T01 CONTROLE` … | `esperar 0 "T01 CONTROLE` … |
| `rankingfn` | `functions-ranking/test/superficie.test.js` | `GUARDA = "functions-ranking/test/superficie.test.js"` |

As de `contratosui` ficaram **mais fortes** de brinde: a agulha passou a carregar o
**exit esperado** de cada caso, e virar `esperar 1` em `esperar 0` deixou de ser
invisível.

### Um limite honesto, declarado

`'ESP-02 CONTROLE` é o único caso do repositório em que o nome do teste ocupa a
linha inteira — o dart quebra assim quando o nome é longo, e a chamada `test(` fica
na linha de cima. Sem código na própria linha, não há âncora possível: o contrato
passou a exigir o nome **inteiro**, interpolação inclusive, e a âncora dele é o
`${mesa.key}`. É estritamente mais forte do que era, e é menos forte do que os
outros oitenta.

## 4. As relações, congeladas fora do manifesto que elas guardam

Duas metades, e as duas moram em `verificar_contrato_suites.sh` — fora da fonte
única, pela mesma razão pela qual a fonte não se guarda sozinha.

### `PISOS_EXIGE` — a metade genérica, para os dezesseis

**Quantas** relações cada gate tem de continuar tendo. Todos os dezesseis pisos são
**exatos** hoje, então tirar uma linha `exige` de **qualquer** gate reprova.

### `RELACOES_CONGELADAS` — o conjunto nominal exato da folha

Contagem sozinha não basta: trocar uma relação por outra, renomear uma, ou
**duplicar** outra para conservar a quantidade continuaria passando. O conjunto
está escrito por extenso, **por suíte**, e a comparação é de igualdade exata, na
ordem:

    @ rankingfn functions-ranking/test/passe.test.js         7 relações (as de PF-01)
    @ rankingfn functions-ranking/test/superficie.test.js    8 relações
                                                           ── 15 no gate

Retirada, renomeação, duplicação, reordenação e troca de uma exigência entre as
duas suítes do gate reprovam todas por aí, e a mensagem diz qual das cinco foi.

### `SUITES_CONGELADAS` e `ALVOS_CONGELADOS` — a reciprocidade

Sozinho, o conjunto nominal teria um jeito de morrer calado: **renomear a suíte na
fonte** faria o bloco congelado dela deixar de casar com qualquer coisa, e um
conjunto que não casa com nada não reprova nada. Estas duas fecham o triângulo —
alvo, suíte e afirmação respondem um pelo outro, e nenhum dos três muda sozinho.

    SUITES_CONGELADAS  rankingfn: passe.test.js,superficie.test.js
    ALVOS_CONGELADOS   rankingfn: functions-ranking/package.json

E a conferência do conjunto roda **antes** de olhar o arquivo, e roda **mesmo com a
suíte ausente**: uma relação adulterada não pode ficar escondida atrás de um
arquivo que sumiu.

## 5. `contratosui` / T27 — a fixture passa a nascer da fonte

`resultados()` escrevia log para **quatro** gates, por uma lista escrita à mão. A
FASE B exige log de **todo** gate contratado, e os contratados são **dezesseis**:
`T27 CONTROLE` reprovava por doze logs que a bancada nunca escreveu, e o
`casos ok: 34` fabricado ainda batia contra um piso que já era 40.

Um CONTROLE que reprova não mede mais nada — e, pior, **todos** os casos de FASE B
passam a medir a falha do controle em vez da própria sabotagem.

A evidência passa a ser **derivada** da relação de contratados da fonte, com o
número de casos de cada gate lido do contrato dele. Nenhuma lista de gates escrita
à mão, e nenhum número fabricado. Cada log carrega as três formas de contador que
os contratos deste repositório usam — o `+N` do Flutter, o `casos ok: N` das
bancadas de shell e o `pass N` do `node --test` —, todas com o número do próprio
contrato; escrever só a forma de um deles obrigaria a fixture a saber qual gate usa
qual, que é a lista escrita à mão voltando pela porta dos fundos.

### E a derivação abre um buraco, que é fechado no mesmo lugar

Se a fixture sai da fonte, **tirar um gate da fonte encolhe a evidência e o oráculo
no mesmo movimento**, e a matriz segue verde medindo menos. Por isso o conjunto
**autoritativo** de contratados está congelado na bancada, por extenso, **fora da
relação derivada** — e `T42` compara os dois. Gate novo com contrato, gate que
perdeu o contrato, gate renomeado: um dos três lados muda, e o caso reprova
(`M20`, `M22`).

O piso de `contratosui` **subiu**, não desceu: `PISOS_PROVAS` de 37 para 61 e
`provas` na fonte de 44 para 61.

## 6. Provas

    functions-ranking  npm test                          exit 0    465/465
    FASE A             verificar_contrato_suites.sh      exit 0    16 contratos
    FASE B             evidência completa                exit 0
    contratosui        teste_contrato_suites.sh          exit 0    57 ok / 0 falhas
    portaoci           teste_portao_os_integracao.sh     exit 0    38/38
    agregador          portao_os_integracao.sh --listar  exit 0    63 gates

Linha de base, medida em `5371a87` antes de qualquer alteração, para comparação:
`rankingfn` 465/465 · FASE A 16 contratos · `portaoci` 38/38 · agregador 63 gates
· **`contratosui` 40 ok / 1 falha (T27)**.

`T27` voltou a ser CONTROLE VERDE, que era o pedido — e voltou por **evidência
completa**, e não por rebaixar o que ele mede: os três pisos de `contratosui`
subiram no mesmo commit (`provas` 44 → 61, `PISOS_PROVAS` 37 → 61, `casos` 40 →
57, `PISOS_CASOS` 34 → 57), e a matriz passou de 41 para 57 casos.

E a FASE A ficou **mais rápida** do que era, apesar de fazer mais: 18s contra 42s
da versão da base, medidos no mesmo minuto e no mesmo worktree. A leitura de cada
suíte passou a ser uma só — o lexer devolve a contagem de declarações e o veredito
das agulhas na mesma varredura —, e as validações de formato deixaram de custar um
`printf | grep` por atributo.

## 7. Campanha negativa — 23 sabotagens, zero escapes

Cada sabotagem é aplicada **sozinha** a uma cópia descartável reconstruída do zero,
com **âncora verificada** antes de medir (um `sed` que não pegou produz "escape"
que não existe — foi a armadilha da OS 40-C1), e só conta como detectada quando o
detector fica vermelho **e a saída diz por quê**. Controle verde antes e depois.

### Lote léxico — 10/10

| | sabotagem | reprova por |
|---|---|---|
| M1 | agulha só em comentário de linha | `só como comentario, string, template ou regex` |
| M2 | só em comentário de bloco | idem |
| M3 | só em string simples | idem |
| M4 | só em string dupla | idem |
| M5 | só em template de uma linha | idem |
| M6 | só em template multilinha | idem |
| M7 | só em expressão regular | idem |
| M8 | só na mensagem do `assert` | idem |
| M9 | só em concatenação de strings | idem |
| M10 | guarda trivializada, texto preservado em região inerte | idem |

Todas recarimbam o `sha256` no mesmo movimento — quem trivializa uma suíte lê o
digest que o verificador imprime e o escreve na fonte. Sem o recarimbo, as dez
mediriam a assinatura, e não o lexer.

### Lote `exige` — 7/7

| | sabotagem | reprova por |
|---|---|---|
| M11 | retirar uma relação de `PF-01` | `a relacao congelada sumiu da fonte` |
| M12 | retirar uma relação da superfície | idem |
| M13 | renomear uma relação | `declara uma relacao que nao esta congelada` |
| M14 | duplicar outra para conservar a quantidade | `a relacao congelada sumiu da fonte` |
| M15 | trocar o alvo mantendo a quantidade | `o 'alvo' de 'rankingfn' nao e o congelado` |
| M16 | retirar relação **e** afirmação juntas, com recarimbo | `a relacao congelada sumiu da fonte` |
| M17 | rebaixar o mínimo externo e recarimbar | `o piso de provas … foi baixado de 57 para 43` |

`M16` é o D9b da rehomologação. `M17` é a segunda volta do digest: o realinhamento
não compra nada, porque o piso não mora na fonte.

### Lote T27 — 6/6

| | sabotagem | detector | reprova por |
|---|---|---|---|
| M18 | a fixture volta a fabricar o literal `34` | `contratosui` | `FALHA T27` |
| M19 | a fixture apaga `t_rankingfn.log` | `contratosui` | `FALHA T27` |
| M20 | contrato novo na fonte, sem log | `contratosui` | `FALHA T42` |
| M21 | a fixture reduz o número de `rankingfn` | `contratosui` | `FALHA T27` |
| M22 | retirar um gate da relação que a fixture usa | `contratosui` | `FALHA T42` |
| M23 | `T27` trivializado, título mantido e identidade recarimbada | FASE A | `o bloco esperar 0 "T27 CONTROLE sumiu` |

`M20` e `M22` são a prova de que o oráculo **não** derivou junto: as duas encolhem
a fixture, e as duas ficam vermelhas no conjunto congelado.

### E dezesseis casos novos na matriz de `contratosui`

    T42  a relação de contratados da fonte é EXATAMENTE a congelada  => VERDE
    T43  agulha só em comentário de BLOCO                            => VERMELHO
    T44  agulha só em string                                         => VERMELHO
    T45  agulha só em texto de template                              => VERMELHO
    T46  agulha só em expressão regular                              => VERMELHO
    T47  agulha só em comentário NO FIM de linha de código           => VERMELHO
    T48  a mesma forja no dart                                       => VERMELHO
    T49  analisador léxico apagado                                   => VERMELHO
    T50  suíte com extensão que o lexer não conhece                  => VERMELHO
    T51  relação de conteúdo retirada da fonte                       => VERMELHO
    T52  relação renomeada                                           => VERMELHO
    T53  relação duplicada para conservar a quantidade               => VERMELHO
    T54  a segunda suíte do gate trocada na fonte                    => VERMELHO
    T55  o alvo trocado na fonte                                     => VERMELHO
    T56  relação E afirmação retiradas juntas, com recarimbo         => VERMELHO
    T57  gate que ganhou contrato e não tem log                      => VERMELHO

`T49` existe porque o lexer é um arquivo novo, e todo arquivo novo é uma superfície
de remoção nova: apagá-lo tem de ser vermelho, e não permissivo.

## 8. Preservações

Quatro arquivos no diff, e um deles é novo:

    scripts/ci/codigo_executavel.awk          (novo)
    scripts/ci/gates_os_integracao.txt
    scripts/ci/teste_contrato_suites.sh
    scripts/ci/verificar_contrato_suites.sh
    docs/OS40-C2-GUARDA-LEXICA-EXIGE-EXPORTS-V1.md   (este registro)

Intocados, byte a byte, e conferidos por digest na partida e na chegada:

    83b4b3be8d58b266  functions-ranking/src/index.ts
    569e5cf6c350c0e3  functions/src/index.ts
    6ee4c5d77e3113b7  functions-moderacao/src/index.ts
    38711b458ea91940  functions-social/src/index.ts
    fb6872f18b3f3713  functions-ranking/package.json
    4a0f144d31d3be27  firebase.json
    903bfd2db2fd1ade  ferramentas/composicao/loja_functions.test.js
    736a863b0b19b840  .github/workflows/ci-os-integracao.yml
    1c97a3048b630ec3  scripts/ci/portao_os_integracao.sh
    0ae02bb66558b78d  scripts/ci/teste_portao_os_integracao.sh
    7c20bd7f7e763e77  functions-ranking/test/passe.test.js
    89599b79dfbd8827  functions-ranking/test/superficie.test.js

**As duas suítes de `rankingfn` não mudaram uma linha.** As campanhas de `PF-01`,
`SF-01` e `SF-02` estão preservadas inteiras, e nenhum caso herdado foi perdido ou
renomeado. `app/lib`, `firebase/`, Torneios, Loja, Comunicação, Ajustes e
`fundacao_v1.dart` não aparecem no diff.

O quinto arquivo — este documento — é o único fora dos três artefatos que a OS
delimitou, e está aqui porque a própria OS exige que a semântica adotada para
interpolação seja mostrada e justificada.

## 9. Fora de escopo, declarado

### O que o lexer não resolve, e que nenhum lexer resolveria

Uma agulha que é **conteúdo puro de string** no arquivo genuíno não pode ser
distinguida da mesma string numa isca — as duas são o mesmo token. Por isso o
remédio não foi afrouxar a regra, e sim **reancorar o contrato**: a exigência passa
a citar a chamada que produz o literal. O único caso onde isso não coube na mesma
linha está declarado em §3.

### Heredoc de shell não é tratado

Nenhuma das duas suítes `.sh` protegidas usa heredoc, e por isso o lexer de `sh`
não os reconhece: o corpo de um heredoc seria lido como código. É uma folga
conhecida, e ela é estreita — abrir um heredoc num arquivo protegido muda o
`sha256`, e escrever a agulha dentro dele exigiria que a afirmação real tivesse
sumido, o que `RELACOES_CONGELADAS` e `PISOS_EXIGE` cobram do lado de fora.

### `/` de regex contra `/` de divisão

O lexer de `js` decide pelo último caractere significativo, e **na dúvida escolhe
regex** — de propósito: tratar regex como código é o que deixa a agulha passar;
tratar divisão como regex só torna a guarda mais exigente. Se algum dia isso
reprovar um arquivo legítimo, a mensagem dirá exatamente qual bloco, e a correção é
reancorar a exigência, não afrouxar o lexer.

### O limite que continua de pé, palavra por palavra

Nenhuma verificação que vive dentro de um workflow cobre a **remoção do próprio
workflow**. O que esta OS acrescenta a isso é uma superfície a menos de remoção
silenciosa: `codigo_executavel.awk` faltando é vermelho por conta própria, e não
"permissivo por ausência".

### Duas armadilhas de medição desta máquina

- **Outra sessão medindo em paralelo, e o tempo mente.** A primeira medição desta
  OS leu 47s e 57s para uma execução da FASE A e concluiu que a guarda nova estava
  cara. Era contenção: havia outra sessão rodando uma campanha noutro worktree, e a
  **versão da base**, medida no mesmo minuto, deu 42s e 46s. Medidas lado a lado e
  sem competição, a versão desta OS dá 18s. A matriz de `contratosui` levou 56
  minutos **com três medições concorrentes** e leva uma fração disso sozinha — e
  nenhum desses números diz nada sobre o runner do Actions.
- **Editar um script enquanto ele roda corrompe a execução, e não o arquivo.** Uma
  correção de comentário aplicada ao `teste_contrato_suites.sh` no meio de uma
  execução dele fez o bash reprovar com `syntax error` numa linha que estava
  correta em disco: o interpretador relê o arquivo por deslocamento de bytes, e a
  edição moveu tudo debaixo dele. A execução foi descartada e refeita.
- **`sleep` e `pkill` não existem como se espera.** `sleep` no arranjo desta
  máquina retorna na hora, e `pkill` não está instalado; esperar por um resultado
  exige laço com `ping -n`, e matar um processo exige `kill` por PID lido de
  `ps -ef`.

### Herdados de `fda24a27` e `5371a87`, ainda abertos

- Os comentários `//` dos blocos `ranking` e `moderacao` em `firebase.json`
  continuam desatualizados. São comentários, e corrigi-los exige tocar
  `firebase.json`, proibido aqui.
- `docs/COMPOSICAO-PERFIL-SOCIAL-RAIZ-P-V1.md` §7 continua atribuindo a falha a
  `functions-ranking`. A errata é `docs/CORRECAO-RANKINGFN-PF01-CONTRATO-EXPORTS-V1.md`.
