# OS 40-C1 — Fechamento externo e fail-closed do contrato de exports V1

**Base:** `correcao/rankingfn-pf01-contrato-exports-v1` @ `fda24a27b52628d36ed77870cc6335f829229f47`
**Branch:** `correcao/os40-c1-guarda-externa-exports-v1`
**Natureza:** correção da **defesa**, não da regra. A superfície nominal de exports entregue em `fda24a27` não muda uma linha; muda **quem responde por ela**.

---

## 1. A base, conferida

    git ls-remote origin refs/heads/correcao/rankingfn-pf01-contrato-exports-v1
      fda24a27b52628d36ed77870cc6335f829229f47        (1ª leitura)
      fda24a27b52628d36ed77870cc6335f829229f47        (2ª leitura, após fetch com refspec completo)

    refs/heads/correcao/rankingfn-pf01-contrato-exports-v1    fda24a27b5…
    refs/remotes/origin/correcao/rankingfn-pf01-contrato-…    fda24a27b5…

`fda24a27` descende de `21ddf47` (raiz P). Árvore limpa na partida e na chegada.

## 2. Os três escapes da R1 são um escape só

A guarda de `fda24a27` era um **par recíproco finito**: `PF-01` cobrava
`SF-01`/`SF-02`, e `SF-01` cobrava `PF-01`. O relatório daquela correção já
declarava o limite — *"desmontar os dois no mesmo commit passa"*. A rehomologação
mostrou que não era preciso desmontar nada: bastava tirar os dois do **alvo**.

| escape | o que bastava fazer | por que passava |
|---|---|---|
| 1 | tirar as duas suítes do alvo do `npm test` | nenhuma das duas roda para reclamar |
| 2 | apontar o alvo para uma suíte-isca verde | idem, e o gate fica verde medindo outra coisa |
| 3 | apagar `SF-01`/`SF-02` mantendo os comentários | `PF-01` fazia `arquivo.includes("SF-01")` sobre **texto cru**, e o cabeçalho cita os dois nomes |

Os três são o mesmo defeito: **a presença no alvo era cobrada de dentro do
alvo**. Uma suíte que cobra a própria presença só fala quando está presente.

## 3. Onde a autoridade passou a morar

`rankingfn` deixou de ser gate sem contrato e passou a ter **contrato completo**
em `scripts/ci/gates_os_integracao.txt`, interpretado por
`scripts/ci/verificar_contrato_suites.sh` — peça **já obrigatória**, **externa a
`functions-ranking`**, que roda na FASE A (antes de Flutter, de Node e de
emulador) e **falha por conta própria**, sem depender de ser somada num portão
adiante.

Não há reciprocidade nova: o verificador não é fiscalizado pelas suítes que ele
guarda. Quem responde pela presença dele é a arquitetura que já existia — a
chave `contratosui` na fonte única, o agregador reprovando por ausência de
resultado, e a exigência (dentro da própria FASE A) de que a invocação continue
escrita no YAML.

### O contrato registrado

    rankingfn
        executor   ( cd functions-ranking && npm test ) 2>&1 | tee t_rankingfn.log; echo ${PIPESTATUS[0]} > exit_rankingfn
        alvo       functions-ranking/package.json
        exigealvo  "test": "tsc && node --test test/politica.test.js … test/composicao.test.js"
        casos      465
        contador   pass [0-9]+
        suite      functions-ranking/test/passe.test.js
        sha256     7c20bd7f7e763e7757dd06394656ea58d2dcadb4dbb10397704cf37b5a8eea7c
        provas     54
        exige      test("PF-01:            · SUPERFICIE_IMPLANTADA = {
        exige      [...esperados].sort(),  · casosDeclaradosEm(GUARDA)
        exige      corpoDoCaso(GUARDA, "SF-01")  · corpoDoCaso(GUARDA, "SF-02")
        exige      functions-ranking/test/superficie.test.js
        suite      functions-ranking/test/superficie.test.js
        sha256     89599b79dfbd8827e35c5723b5c16a71da60a70a42f602d4343c7355e0c5c62c
        provas     3
        exige      test("SF-01:  · test("SF-02:  · test("SF-03:
        exige      const ALVO_OFICIAL =
        exige      casosDeclaradosEm(PASSE).includes("PF-01")
        exige      corpoDoCaso(PASSE, "PF-01")
        exige      listaLiteral(fonte, codebase, "'")
        exige      pkg.scripts.test,

(as linhas `exige` estão agrupadas acima só para caber na página; na fonte cada
literal ocupa a sua.)

E, em `verificar_contrato_suites.sh`, os pisos que a fonte **não pode rebaixar**:

    CONTRATOS_MINIMOS   … rankingfn
    PISOS_PROVAS        … rankingfn:57      (a SOMA das duas suítes: 54 + 3)
    PISOS_CASOS         … rankingfn:465

### O que o guardião externo confirma, exigência por exigência

| exigência da OS | como |
|---|---|
| caminho exato de `passe.test.js` | `suite` + `sha256` próprios, e o literal dentro de `exigealvo` |
| caminho exato de `superficie.test.js` | idem |
| comando oficial sem suíte-isca | `exigealvo` congela a linha `"test": "…"` **inteira** |
| execução das duas suítes | `alvo` exige que o `package.json` **nomeie cada `suite` declarada** |
| piso mínimo de casos | `casos 465` + `contador pass [0-9]+`, lidos do log na FASE B |
| presença de `SF-01`/`SF-02`/`SF-03` | `exige test("SF-01:` … sobre o código **sem comentário** |
| presença de `PF-01` | `exige test("PF-01:` no próprio `passe.test.js` |
| marcador do gate produzido | `exit_rankingfn` conferido no YAML |

## 4. O vocabulário que faltava

Um gate de **codebase** roda vários arquivos, e o vocabulário só sabia falar de
um. Três acréscimos, todos fail-closed.

### `suite` passa a ser repetível

`sha256`/`provas`/`conta`/`exige` pertencem à `suite` declarada acima deles. A
metade não declarada ficava sem digest, sem piso e sem `exige` — e era ali que
se podia tirar do alvo a suíte que guarda a outra.

`PISOS_PROVAS` passa a valer sobre a **soma** das declarações do gate. Um gate de
uma suíte só — todos, menos `rankingfn` — se comporta exatamente como antes; os
quinze contratos anteriores continuam valendo palavra por palavra, e as
conferências que dependem de atributo do gate foram movidas para o fim da
entrada, para que a ordem em que os atributos aparecem deixe de importar (os
contratos existentes declaram `executor` **depois** de `suite`).

### `alvo` + `exigealvo` — quando o executor não nomeia o arquivo

O contrato sempre exigiu que o `executor` **citasse** a suíte: sem isso ele
aceitaria um passo que roda outra coisa — produtor sem alvo, o degrau seguinte ao
gate fantasma. Mas um passo que roda `npm test` não cita arquivo nenhum: quem
nomeia as suítes é o `package.json`. Sem `alvo`, um gate de codebase só entraria
no contrato **afrouxando** aquela exigência. `alvo` fecha a cadeia inteira, elo
por elo, em vez de afrouxar:

    executor   ->  cita o diretório do alvo       (o passo roda AQUELE codebase)
    alvo       ->  nomeia CADA suite declarada    (o comando oficial roda AQUELAS suítes)
    exigealvo  ->  literais no alvo               (o comando oficial não mudou de forma)

A busca dentro do alvo ignora comentário **e conhece a chave de comentário de
JSON** (`"//…"`, como este repositório documenta `scripts`): repetir o caminho de
uma suíte numa chave de prosa não substitui rodá-la.

### O alvo não tem `sha256`, e isso é decisão

Um `package.json` muda por versão de dependência, e um digest que reprova a cada
bump vira pressão para afrouxar a guarda. O que esta OS congela do alvo é o
**comando oficial**, por `exigealvo` — nominal, legível no diff, imune a bump, e
mais informativo que um digest sobre o que exatamente não pode mudar. A
integridade das duas **suítes** continua com digest, que é onde ela pertence.

## 5. Código, e não comentário

`PF-01` deixou de ler texto cru. `casosDeclaradosEm()` e `corpoDoCaso()` leem o
**código sem comentário** e casam com a **declaração** `test("SF-01: …")`; manter
os nomes em cabeçalho, comentário ou documentação não satisfaz mais nada. As duas
funções carregam **sentinela**: se a limpeza de comentário comer o arquivo (bloco
mal fechado), elas reprovam em vez de ficarem verdes por ausência — que é o modo
mais silencioso de uma guarda textual morrer.

`SF-01` parou de cobrar a própria presença e passou a cobrar a do outro lado.
`SF-03` (novo) congela o alvo oficial por **igualdade exata**: `includes` aceitava
acréscimo, e era por ali que a isca entrava. `PF-01` cobra de volta, agora sobre
código, que os três casos `SF` continuem declarados **e que cada corpo ainda
compare**.

As duas suítes continuam se cobrando — mas como **redundância**, e não como
autoridade. Nenhuma das duas é mais o único lugar onde a ausência da outra
aparece.

## 6. Provas

    functions-ranking  npm test                          exit 0    465/465   (base: 464/464)
    FASE A             verificar_contrato_suites.sh      exit 0    16 contratos conferidos
    composloja         node --test loja_functions        exit 0     35/35
    composneg          node --test negativas             exit 0     21/21
    proveni            node --test proveniencia          exit 0     13/13
    portaoci           teste_portao_os_integracao.sh     exit 0     38/38
    contratosui        teste_contrato_suites.sh          exit 1     40 ok / 1 falha   <- VERMELHO HERDADO, §9

Linha de base medida em `fda24a27` **antes** de qualquer alteração, para
comparação: `rankingfn` 464/464 · FASE A 15 contratos · composloja 35/35 ·
composneg 21/21 · portaoci 38/38 · **`contratosui` 33 ok / 1 falha (T27)**.

## 7. Campanha negativa — 28 mutações, zero escapes

Cada mutação é aplicada **sozinha** à árvore, medida e revertida. Uma mutação só
conta como detectada quando o detector fica vermelho **e a saída diz por quê** —
sem essa exigência, uma guarda que reprovasse sempre passaria na campanha
inteira. O controle final confirma que a árvore íntegra fica verde nos dois
detectores.

### As 13 da R1 — 13/13 vermelhas

| | mutação | detector | reprova por |
|---|---|---|---|
| M1 | export obrigatório some (`consultarHall`) | PF-01 | `mudou de superfície de deploy` |
| M2 | export renomeado (`aplicarSancao`) | PF-01 | idem |
| M3 | 12º export em `functions-ranking` | PF-01 | idem |
| M4 | 12º export em `functions-moderacao` | PF-01 | idem |
| M5 | `PF-01` volta a conferir quantidade | SF-01 | `deixou de comparar a relação de nomes` |
| M6 | a relação nominal de `PF-01` é esvaziada | SF-01 | `a relação nominal … está vazia` |
| M7 | um nome sai da relação de `PF-01` | SF-01 | `não é mais a superfície do disco` |
| M8 | o caso `PF-01` é apagado | SF-01 | `o caso PF-01 não é mais declarado` |
| M9 | `passe.test.js` sai do alvo | **FASE A** | `o alvo … nao roda a suite` |
| M10 | `superficie.test.js` sai do alvo | **FASE A** | idem |
| M11 | a guarda some (`SF-01`/`02`/`03`) | PF-01 | `a guarda SF-01 de PF-01 sumiu` |
| M12 | a lista congelada da composição diverge | SF-02 | `não é mais a do disco` |
| M13 | `passe.test.js` é apagado | **FASE A** | `suite removida ou renomeada` |

M9, M10 e M13 mudaram de detector: na R1 quem os pegava era a própria dupla
(quando pegava). Agora quem os pega é o guardião externo, **antes** de qualquer
teste rodar.

### As 10 desta OS — 10/10 vermelhas

| | mutação | detector | reprova por |
|---|---|---|---|
| N1 | `SF-01`/`SF-02` apagados, **comentários mantidos** | PF-01 | `a guarda SF-01 de PF-01 sumiu` |
| N2 | somente `SF-01` trivializado | PF-01 | `SF-01 virou fachada` |
| N3 | somente `SF-02` trivializado | PF-01 | `SF-02 virou fachada` |
| N4 | `superficie.test.js` retirada do alvo | FASE A | `nao roda a suite` |
| N5 | `passe.test.js` retirada do alvo | FASE A | `nao roda a suite` |
| N6 | o alvo aponta para **suíte-isca verde** | FASE A | `nao roda a suite` + `sumiu do alvo` |
| N7 | o total executado cai (465 → 462) | FASE B | `executou 462 caso(s) e o piso e 465` |
| N8 | o contrato de `rankingfn` some da fonte | FASE A | `perdeu o contrato de conteudo` |
| N9 | o executor sai do workflow | FASE A | `nao tem a linha do executor` |
| N10 | `rankingfn` marcado como não executado | agregador | `rankingfn NAO EXECUTADO` |

N1 é a que a R1 apontou nominalmente: sob a guarda antiga ela ficava **verde**.

### Segunda volta — o digest realinhado, 5/5 vermelhas

A assinatura sozinha não é guarda de conteúdo: quem trivializa uma suíte pode ler
o digest que o verificador imprime e escrevê-lo na fonte. Cada caso abaixo
trivializa **e realinha o `sha256` no mesmo movimento**; a FASE A tem de continuar
vermelha **por outro motivo que não o digest**.

| | mutação | reprova por |
|---|---|---|
| R1 | `SF-01` trivializado + digest realinhado | `o bloco casosDeclaradosEm(PASSE).includes("PF-01") sumiu` |
| R2 | `SF-02` trivializado + digest realinhado | `o bloco listaLiteral(fonte, codebase, "'") sumiu` |
| R3 | `SF-01`/`SF-02` apagados (comentários mantidos) + digest realinhado | `o bloco test("SF-01: sumiu` |
| R4 | `PF-01` volta a contar + digest realinhado | `o bloco [...esperados].sort(), sumiu` |
| R5 | o caso `PF-01` apagado + digest realinhado | `o bloco test("PF-01: sumiu` |

Foram `R2` e `R4` que exigiram as duas últimas linhas `exige` do contrato: sem
elas, as duas passavam pela FASE A depois do realinhamento.

### E a bancada pegou uma regressão desta própria OS

`T21 — TODOS os contratos removidos` apagava os atributos por uma **lista de
nomes escrita à mão**, e ela ficou para trás quando `alvo` e `exigealvo`
nasceram. O caso continuava vermelho — mas por **sobrar contrato**, e não pela
mensagem que ele mede. Um caso que reprova pelo motivo errado é um caso que
deixou de medir. Passou a apagar **qualquer** atributo indentado, e não envelhece
mais com o vocabulário.

Sete casos novos entraram na matriz de `contratosui` para o elo novo:

    T35  suíte tirada do alvo oficial                      => VERMELHO
    T36  suíte-isca acrescentada ao alvo                   => VERMELHO
    T37  alvo apagado                                      => VERMELHO
    T38  `exigealvo` sem `alvo`                            => VERMELHO
    T39  `alvo` sem nenhum `exigealvo`                     => VERMELHO
    T40  segunda `suite` do gate removida da fonte         => VERMELHO (o piso é a SOMA)
    T41  contrato de `rankingfn` esvaziado                 => VERMELHO

E a bancada passou a copiar os `alvo` declarados na fonte pela mesma porta por
onde já copiava as `suite` — da **fonte**, e não de uma lista escrita nela.

## 8. Preservações

Cinco arquivos no diff, e nenhum deles fora de `functions-ranking/test/` e
`scripts/ci/`:

    functions-ranking/test/passe.test.js
    functions-ranking/test/superficie.test.js
    scripts/ci/gates_os_integracao.txt
    scripts/ci/teste_contrato_suites.sh
    scripts/ci/verificar_contrato_suites.sh

Intocados, byte a byte: todo `functions-*/src` (inclusive os **11 exports
canônicos** de `functions-moderacao`, com `emitirEventoDeSistema` e
`consultarCatalogoDeComunicacao`), `functions-ranking/package.json`,
`firebase.json`, `contrato/chat-transporte-v1.json`, Ranking, Hall, Perfil,
Social, o workflow `ci-os-integracao.yml` (gatilhos, branches e permissões
inclusive) e a correção de PF-01 entregue em `fda24a27` — a relação
`SUPERFICIE_IMPLANTADA` não perdeu nem ganhou um nome.

## 9. Fora de escopo, declarado

### O vermelho herdado de `contratosui` / T27 — reproduzido, não corrigido

`T27 CONTROLE — evidência completa e datada => VERDE` **já falhava em
`fda24a27`**, e falha aqui. A causa não é do contrato: é da **fixture** da
bancada. `resultados()` escreve log para quatro gates
(`comunicacao`, `chatdom`, `portaoci`, `contratosui`), e a FASE B exige log de
**todo** gate contratado.

    base fda24a27   33 ok / 1 falha (T27)   11 gates sem log na fixture
    esta OS         40 ok / 1 falha (T27)   12 gates sem log na fixture

Os onze da base: `avatarcanon`, `avatarhml`, `perfilvis`, `rknavpub`,
`compavrank`, `compnavpub`, `socialestado`, `socialleitor`, `socialtela`,
`audsocial`, `a11yamigos`. **O décimo segundo é `rankingfn`, e ele é desta OS** —
a OS 40-C1 previu essa ausência adicional e a declara aqui em vez de escondê-la
completando a fixture, porque completar a fixture **só para `rankingfn`** deixaria
os onze anteriores no escuro e faria esta OS parecer ter consertado o que não
consertou. A correção certa é genérica — a fixture deve gerar log a partir da
relação de contratados, e não de uma lista escrita à mão — e pertence a uma OS de
`contratosui`.

**Efeito colateral declarado:** com sete casos novos, o placar de `contratosui`
subiu de 33 para 40 casos verdes, e a subconferência `casos` da FASE B para o
gate `contratosui` (piso 34 na base, agora 40 na fonte) deixou de reprovar por
`33 < 34`. O **gate continua VERMELHO** — T27 falha, `exit_contratosui` = 1 —, mas
a mudança de estado daquela subconferência está registrada para não ser lida como
correção.

### Duas armadilhas de medição desta máquina

- **`node --test` em paralelo, no Windows/Node 24.** A primeira medição de base
  leu `411 tests / 1 fail` com `passe.test.js` derrubado por
  `Error: UNKNOWN: unknown error, write` num socket do harness — e não por
  assertiva nenhuma. O mesmo arquivo, rodado sozinho, deu 54/54 verde, e a
  repetição do `npm test` deu 464/464. **Um vermelho de `node --test` com stack
  em `internal/test_runner/harness` não é um caso reprovado.**
- **Disco C: com 0,35 GB livres.** As bancadas usam `mktemp -d`, e o disco cheio
  somado à exaustão de `fork` do Cygwin (havia outra sessão medindo em paralelo)
  produziu um **falso escape** — `R4` foi relatado como escape quando o que
  falhou foi o `sed` do realinhamento, que não chegou a rodar. A campanha passou
  a **conferir que o realinhamento pegou** antes de medir, e os temporários foram
  movidos para `F:` (6,9 TB livres). A repetição em série deu 5/5.

### Herdados de `fda24a27`, ainda abertos

- Os comentários `//` dos blocos `ranking` e `moderacao` em `firebase.json`
  continuam desatualizados. São comentários — o Firebase implanta o que o
  `index.ts` exporta —, e corrigi-los exige tocar `firebase.json`, proibido aqui.
- `docs/COMPOSICAO-PERFIL-SOCIAL-RAIZ-P-V1.md` §7 continua atribuindo a falha a
  `functions-ranking`. A errata é `docs/CORRECAO-RANKINGFN-PF01-CONTRATO-EXPORTS-V1.md`.

### Limite honesto que continua de pé

Nenhuma verificação que vive dentro de um workflow cobre a **remoção do próprio
workflow**. O que esta OS garante é que a remoção não é silenciosa: `rankingfn`
está na fonte única, o agregador reprova por ausência de resultado, a FASE A
exige que a invocação do verificador continue escrita no YAML, e o `executor` do
gate é conferido linha a linha contra ele.
