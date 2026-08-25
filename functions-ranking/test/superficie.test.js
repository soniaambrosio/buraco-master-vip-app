/**
 * SF — A SUPERFÍCIE IMPLANTADA, E QUEM GUARDA QUEM A GUARDA.
 *
 * ---------------------------------------------------------------------------
 * POR QUE ESTE ARQUIVO EXISTE
 * ---------------------------------------------------------------------------
 *
 * `PF-01`, em `test/passe.test.js`, conferia a superfície de deploy CONTANDO
 * exports. A contagem mentiu: o piso de `functions-moderacao` foi congelado em
 * `c9efc20`, uma linhagem que ainda não continha `6986de9` (Comunicação
 * Controlada V1). A raiz P contém, e o caso passou a reprovar com `11 !== 9` —
 * sem dizer quais onze, e sem distinguir "entrou export novo" de "renomearam
 * um". A correção foi trocar a contagem por uma RELAÇÃO NOMINAL.
 *
 * Uma relação nominal, porém, tem um jeito novo de morrer que a contagem não
 * tinha: alguém pode esvaziá-la, ou trocar o corpo do caso por um `assert.ok`
 * de fachada, mantendo o nome, o arquivo e o registro no `npm test`. É o mesmo
 * buraco que a fonte única dos gates fechou com `sha256`/`provas`, e ele vale
 * aqui igual.
 *
 * ---------------------------------------------------------------------------
 * O QUE MUDOU NESTA CORREÇÃO (OS 40-C1)
 * ---------------------------------------------------------------------------
 *
 * A versão anterior fechava o buraco com um PAR RECÍPROCO — `PF-01` cobrava
 * `SF-01`/`SF-02`, e `SF-01` cobrava `PF-01` — e com `SF-01` cobrando A PRÓPRIA
 * PRESENÇA no alvo do `npm test`. Duas coisas erradas nisso, e a rehomologação
 * OS 40-R1 mediu as duas:
 *
 *   1. UM PAR RECÍPROCO FINITO CAI CALADO se as duas pontas caírem juntas. Tirar
 *      as duas suítes do alvo do `npm test`, ou apontar o alvo para uma
 *      suíte-isca verde, deixava o gate `rankingfn` inteiramente verde.
 *   2. UMA SUÍTE QUE COBRA A PRÓPRIA PRESENÇA não cobra nada: ela só roda se
 *      estiver presente, e o caso em que ela não está é justamente o caso em que
 *      ninguém pergunta.
 *
 * ENTÃO A AUTORIDADE MUDOU DE LUGAR. Quem afirma que estas duas suítes estão no
 * alvo oficial, que o alvo não ganhou isca, que o piso de casos não caiu e que
 * `PF-01`/`SF-01`/`SF-02` continuam declarados é o CONTRATO DE `rankingfn` em
 * `scripts/ci/gates_os_integracao.txt`, interpretado por
 * `scripts/ci/verificar_contrato_suites.sh` — que roda ANTES de qualquer teste,
 * falha por conta própria, e vive fora deste codebase. Estas duas suítes
 * continuam se cobrando, mas como REDUNDÂNCIA, e não como autoridade: nenhuma
 * das duas é mais o único lugar onde a ausência da outra aparece.
 *
 * ---------------------------------------------------------------------------
 * O QUE CADA CASO AFIRMA
 * ---------------------------------------------------------------------------
 *
 *   SF-01  PF-01 existe COMO CÓDIGO — declaração real, não menção em
 *          comentário —, valida por nome, e a relação nominal escrita nele é
 *          EXATAMENTE a do disco.
 *   SF-02  a mesma superfície, congelada por `ferramentas/composicao/
 *          loja_functions.test.js`, também é a do disco.
 *   SF-03  o alvo do `npm test` é EXATAMENTE o alvo oficial: nominal, sem
 *          glob, sem isca, sem arquivo fantasma, e com as duas suítes desta
 *          dupla dentro dele.
 *
 * SF-01 e SF-02 apontam para o DISCO, e não uma para a outra. É assim que duas
 * listas congeladas em arquivos diferentes ficam impedidas de divergir sem que
 * nenhuma das duas vire "a fonte" da outra — que seria criar uma terceira
 * autoridade sobre a mesma coisa.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const RAIZ = path.resolve(__dirname, "..", "..");
const leia = (p) => fs.readFileSync(path.join(RAIZ, p), "utf8");

const PASSE = "functions-ranking/test/passe.test.js";
const ESTA = "functions-ranking/test/superficie.test.js";
const PACOTE = "functions-ranking/package.json";
const CONGELADA = "ferramentas/composicao/loja_functions.test.js";

/// O ALVO OFICIAL do `npm test` deste codebase, congelado por escrito.
///
/// NOMINAL E NÃO GLOB, de propósito e desde a OS do Passe: um arquivo novo na
/// pasta passaria a rodar sem ninguém decidir, e um renomeado sairia da suíte em
/// silêncio. O que esta constante acrescenta é o outro lado — o alvo também não
/// pode ENCOLHER, nem ganhar uma isca verde no meio, sem aparecer no diff.
///
/// ESTE MESMO LITERAL ESTÁ CONGELADO FORA DAQUI, como `exigealvo` do contrato de
/// `rankingfn` em `scripts/ci/gates_os_integracao.txt`. É a diferença entre uma
/// constante e uma autoridade: trocar as duas passa a ser uma decisão escrita em
/// dois arquivos, num commit só, e legível no diff.
const ALVO_OFICIAL =
  "tsc && node --test test/politica.test.js test/ligas.test.js test/ordenacao.test.js" +
  " test/ledger.test.js test/temporadas.test.js test/apuracao.test.js test/projecao.test.js" +
  " test/resultado.test.js test/elo.test.js test/competicao.test.js test/elegibilidade.test.js" +
  " test/ciclo.test.js test/identidade.test.js test/passe.test.js test/superficie.test.js" +
  " test/estatisticas.test.js test/composicao.test.js";

/// As quatro codebases que PF-01 guarda, e o ponto de entrada implantado de cada
/// uma. São quatro, e não nove, porque foi sobre estas quatro que a OS do Passe
/// se comprometeu: as outras cinco têm o mesmo congelamento em `CONGELADA`, sob
/// o gate `composloja`.
const GUARDADAS = [
  ["functions", "functions/src/index.ts"],
  ["functions-moderacao", "functions-moderacao/src/index.ts"],
  ["functions-ranking", "functions-ranking/src/index.ts"],
  ["functions-social", "functions-social/src/index.ts"],
];

/// Uma fonte sem comentário. Mesma limpeza de `passe.test.js` e de `CONGELADA`:
/// uma varredura que não separe prosa de código casa com o comentário que
/// explica a remoção e passa a provar o texto em vez do programa.
///
/// A `sentinela` é o que TEM de sobrar depois da limpeza. Sem ela, um bloco de
/// comentário mal fechado apagaria o arquivo inteiro e toda busca por ausência
/// ficaria verde — que é o modo mais silencioso de uma guarda textual morrer.
function semComentario(fonte, sentinela) {
  const limpo = fonte
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^[ \t]*\/\/.*$/gm, "")
    .replace(/^[ \t]*\/\/\/.*$/gm, "");
  assert.ok(limpo.includes(sentinela), "a limpeza comeu o código: `" + sentinela + "` sumiu");
  return limpo;
}

const codigoDe = (fonte) => semComentario(fonte, "export");

/// Os identificadores dos casos DECLARADOS numa suíte — `test("XX-99: ...")` —,
/// lidos do CÓDIGO.
///
/// LIDOS DO CÓDIGO, e não do texto cru: manter `SF-01` num cabeçalho, num
/// comentário ou na documentação não pode satisfazer guarda nenhuma. Era esta a
/// falha que a OS 40-R1 apontou na versão anterior de PF-01, que fazia
/// `arquivo.includes("SF-01")` sobre o arquivo inteiro — e passava verde com os
/// dois casos apagados, desde que os comentários ficassem.
function casosDeclaradosEm(arquivo) {
  const codigo = semComentario(leia(arquivo), "require(");
  return [...codigo.matchAll(/(?:^|[^\w$.])test\(\s*["']([A-Za-z]{2}-[0-9]{2})\s*:/g)].map((m) => m[1]);
}

/// O corpo declarado de um caso: do `test("<id>:` até a próxima DECLARAÇÃO de
/// caso, ou até o fim do arquivo. Sempre sobre o código sem comentário — um
/// corpo trivializado cujo comentário antigo ficou por cima não pode continuar
/// respondendo pelo corpo que sumiu.
function corpoDoCaso(arquivo, id) {
  const codigo = semComentario(leia(arquivo), "require(");
  const abre = new RegExp('test\\(\\s*["\']' + id + '\\s*:').exec(codigo);
  assert.ok(abre !== null, "o caso " + id + " não é declarado em " + arquivo);
  const resto = codigo.slice(abre.index + abre[0].length);
  const proximo = /(?:^|[^\w$.])test\(\s*["'][A-Za-z]{2}-[0-9]{2}\s*:/.exec(resto);
  return proximo === null ? resto : resto.slice(0, proximo.index);
}

/// O que uma entrada de fato exporta, por nome e ordenado.
function exportsDe(arquivo) {
  const fonte = codigoDe(leia(arquivo));
  const achados = new Set();
  for (const m of fonte.matchAll(/^\s*export\s+const\s+([A-Za-z0-9_]+)/gm)) achados.add(m[1]);
  for (const m of fonte.matchAll(/exports\.([A-Za-z0-9_]+)\s*=/g)) achados.add(m[1]);
  return [...achados].sort();
}

const escapar = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/// Os nomes de uma lista literal `<chave>: [ ... ]` dentro de uma FONTE, lidos
/// como texto.
///
/// LIDOS COMO TEXTO, e não importados: `passe.test.js` e `CONGELADA` são suítes,
/// e `require` numa delas executaria os testes de dentro deste arquivo. O que se
/// quer aqui é o que está ESCRITO lá, que é justamente o que um `assert.ok(true)`
/// de fachada não teria.
function listaLiteral(fonte, chave, aspas) {
  const achado = new RegExp(aspas + escapar(chave) + aspas + "\\s*:\\s*\\[([^\\]]*)\\]").exec(fonte);
  assert.ok(achado !== null, "a relação nominal de `" + chave + "` sumiu");
  const nomes = [...achado[1].matchAll(/["']([A-Za-z0-9_]+)["']/g)].map((m) => m[1]);
  assert.ok(nomes.length > 0, "a relação nominal de `" + chave + "` está vazia");
  return nomes.sort();
}

describe("SF — a superfície de deploy não pode voltar a valer por contagem", () => {
  test("SF-01: PF-01 é código declarado, e sua relação nominal é a do disco", () => {
    // 1. EXISTE COMO CÓDIGO, com o nome que a OS do Passe registrou. Apagar o
    //    arquivo já derruba a suíte inteira, porque o alvo o nomeia; apagar só o
    //    CASO, não — e é esse o furo que esta linha fecha. A leitura é do código
    //    sem comentário: um `// PF-01` deixado para trás não responde por um
    //    caso que não existe mais.
    assert.ok(
      casosDeclaradosEm(PASSE).includes("PF-01"),
      "o caso PF-01 não é mais declarado em " + PASSE
    );

    // 2. E O OUTRO LADO CONTINUA NO ALVO. Quem afirma isto DE FORA é o contrato
    //    de `rankingfn` na fonte única; aqui a afirmação é redundante de
    //    propósito, e é sobre a OUTRA suíte — não sobre esta. Uma suíte que
    //    cobra a própria presença só fala quando está presente.
    const pkg = JSON.parse(leia(PACOTE));
    assert.ok(pkg.scripts.test.includes("test/passe.test.js"), "PF-01 saiu do `npm test`");

    // 3. E VALIDA POR NOME. Um corpo que voltasse a comparar quantidade não tem
    //    `deepEqual` sobre a relação, e um corpo trivial não tem nem a relação.
    const corpo = corpoDoCaso(PASSE, "PF-01");
    assert.ok(
      /assert\.deepEqual\(/.test(corpo),
      "PF-01 deixou de comparar a relação de nomes"
    );
    assert.ok(
      /SUPERFICIE_IMPLANTADA/.test(corpo),
      "PF-01 não consulta mais a superfície nominal"
    );

    // 4. A PROVA FORTE: o que está ESCRITO em PF-01 é, nome por nome, o que o
    //    disco exporta. Esvaziar a relação, deixar um nome de fora ou inventar
    //    um décimo segundo reprova aqui — mesmo que PF-01 fique verde por não
    //    olhar mais para ela.
    const fonte = leia(PASSE);
    for (const [, arquivo] of GUARDADAS) {
      assert.deepEqual(
        listaLiteral(fonte, arquivo, '"'),
        exportsDe(arquivo),
        arquivo + ": a relação nominal de PF-01 não é mais a superfície do disco"
      );
    }
  });

  test("SF-02: a superfície congelada da composição também é a do disco", () => {
    // A OUTRA LISTA CONGELADA. Ela é a autoridade sobre as NOVE codebases e é
    // cobrada pelo gate `composloja`; aqui se cobra apenas o recorte que PF-01
    // compartilha com ela. Enquanto as duas apontarem para o disco, atualizar
    // uma sem a outra fica vermelho — que é a divergência que se quer impedir.
    const fonte = leia(CONGELADA);
    for (const [codebase, arquivo] of GUARDADAS) {
      assert.deepEqual(
        listaLiteral(fonte, codebase, "'"),
        exportsDe(arquivo),
        codebase + ": a superfície congelada em " + CONGELADA + " não é mais a do disco"
      );
    }
  });

  test("SF-03: o alvo do `npm test` é exatamente o alvo oficial", () => {
    const pkg = JSON.parse(leia(PACOTE));

    // 1. IGUALDADE EXATA, e não `includes`. `includes` aceitava acréscimo: uma
    //    suíte-isca verde no fim da linha passava despercebida, e o gate ficava
    //    verde medindo outra coisa. Igualdade também recusa a REORDENAÇÃO e a
    //    troca do `tsc &&` da frente — o alvo compila antes de rodar porque o
    //    que ele testa é `lib/`, e sem isso a suíte prova o build anterior.
    assert.equal(
      pkg.scripts.test,
      ALVO_OFICIAL,
      "o alvo do `npm test` divergiu do alvo oficial congelado"
    );

    // 2. AS DUAS SUÍTES DESTA DUPLA ESTÃO NELE, nominadas. Redundante com a
    //    igualdade acima e escrito assim de propósito: se alguém realinhar
    //    `ALVO_OFICIAL` com um alvo mutilado, é aqui que a intenção aparece.
    for (const obrigatoria of ["test/passe.test.js", "test/superficie.test.js"]) {
      assert.ok(
        ALVO_OFICIAL.includes(" " + obrigatoria + " ") ||
          ALVO_OFICIAL.endsWith(" " + obrigatoria),
        obrigatoria + " não está mais no alvo oficial"
      );
    }

    // 3. E NENHUM ARQUIVO DO ALVO É FANTASMA. Um alvo que nomeia arquivo
    //    inexistente derruba o `npm test` inteiro com erro de módulo — barulho
    //    que se lê como "quebrou o Node", e não como "mexeram no alvo".
    const nomeados = [...ALVO_OFICIAL.matchAll(/(test\/[A-Za-z0-9_.-]+\.test\.js)/g)].map((m) => m[1]);
    assert.ok(nomeados.length >= 17, "o alvo oficial encolheu: " + nomeados.length + " suítes");
    for (const arquivo of nomeados) {
      assert.ok(
        fs.existsSync(path.join(RAIZ, "functions-ranking", arquivo)),
        "o alvo nomeia " + arquivo + ", que não existe no disco"
      );
    }

    // 4. E O ALVO NÃO VIROU GLOB. `node --test` sem arquivo varre a pasta, e aí
    //    um arquivo novo entra na suíte sem ninguém decidir.
    assert.ok(!/[*?]/.test(pkg.scripts.test), "o alvo do `npm test` virou glob");
    assert.equal(
      ESTA,
      "functions-ranking/test/" + path.basename(__filename),
      "esta suíte foi renomeada e o contrato de `rankingfn` ainda não sabe"
    );
  });
});
