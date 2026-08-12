/**
 * Prova a fronteira de privacidade e a marcacao "sou eu".
 *
 * Cobre a secao 23 ("Seguranca": leitura publica apenas dos campos autorizados) e
 * as secoes 15, 16 e 17.
 *
 * O VAZAMENTO QUE ESTA SUITE EXISTE PARA IMPEDIR nao e o de hoje — e o de daqui a
 * seis meses, quando alguem acrescentar um campo ao standing (`email` para o
 * suporte, `deviceId` para antifraude) e nao lembrar que existe uma projecao.
 * Com lista branca, o esquecimento produz um campo ausente na tela. Sem ela,
 * produz um dado exposto.
 *
 * Tambem cobre a decisao de identidade: `resultado_da_projecao.id` e o
 * `publicPlayerId`, NUNCA o uid.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  projetarJogador,
  CAMPOS_PUBLICADOS,
  CAMPOS_PROIBIDOS,
  acharCampoProibido,
  POSICAO_NAO_APURADA,
} = require("../lib/projecao");
const { idPublicoValido, chaveDeStanding } = require("../lib/identidade");

const STANDING = {
  seasonId: "2026-A",
  uid: "uid-secreto-do-firebase",
  publicPlayerId: "PABC123XYZ456",
  apelido: "Dona Sonia",
  avatar: "assets/avatares/1.webp",
  pontos: 1234,
  partidasComputadas: 42,
  posicao: 7,
  posicaoAnterior: 12,
  direcao: "subiu",
  deltaPosicao: 5,
  ligaId: "alta",
  ligaNome: "ALTA",
  selo: "assets/ranking/selos/top_3.webp",
  atualizadoEm: "2026-08-11T20:00:00.000Z",
  estadoCompetitivo: "classificado",
  partidasDeQualificacao: 10,
  qualificacaoExigida: 10,
  vitorias: 25,
  derrotas: 15,
  empates: 2,
  saldoPontos: 3400,
  abandonos: 0,
  ratingAtingidoEm: "2026-08-10T12:00:00.000Z",
};

describe("projecao: o uid NAO atravessa", () => {
  test("a linha publicada nao contem uid em nenhum campo", () => {
    const publicada = projetarJogador(STANDING, "outro-uid");
    assert.equal(acharCampoProibido(publicada), null);
    assert.equal(JSON.stringify(publicada).includes("uid-secreto-do-firebase"), false);
  });

  test("`id` e o identificador PUBLICO", () => {
    const publicada = projetarJogador(STANDING, null);
    assert.equal(publicada.id, "PABC123XYZ456");
    assert.notEqual(publicada.id, STANDING.uid);
  });

  test("a projecao publica EXATAMENTE os campos declarados", () => {
    // Lista branca: um campo novo em `JogadorPublicado` sem atualizar
    // CAMPOS_PUBLICADOS quebra aqui, o que forca a decisao consciente de
    // publica-lo.
    const publicada = projetarJogador(STANDING, null);
    assert.deepEqual(Object.keys(publicada).sort(), [...CAMPOS_PUBLICADOS].sort());
  });

  test("campos internos do standing ficam de fora", () => {
    const publicada = projetarJogador(STANDING, null);
    // `ligaId` SAIU desta lista com a Politica Competitiva v1, e passou a ser
    // publicado de proposito: o rotulo `liga` agora pode dizer "Em colocacao",
    // que nao e uma Liga, e o cliente precisa de um campo estavel para escolher
    // arte. Ele nao carrega dado de pessoa nenhuma.
    for (const interno of [
      "seasonId",
      "uid",
      "partidasComputadas",
      "posicaoAnterior",
      "ligaNome",
      "atualizadoEm",
      "saldoPontos",
      "ratingAtingidoEm",
      "partidasDeQualificacao",
    ]) {
      assert.equal(interno in publicada, false, `"${interno}" vazou`);
    }
  });
});

describe("projecao: sou eu (secao 15)", () => {
  test("verdadeiro para o proprio jogador", () => {
    assert.equal(projetarJogador(STANDING, "uid-secreto-do-firebase").souEu, true);
  });

  test("falso para terceiro", () => {
    assert.equal(projetarJogador(STANDING, "outra-pessoa").souEu, false);
  });

  test("falso para quem nao esta autenticado", () => {
    assert.equal(projetarJogador(STANDING, null).souEu, false);
  });

  test("a comparacao NAO usa apelido", () => {
    // "Nunca usar nickname como identidade" (secao 15). Duas contas com o mesmo
    // apelido nao podem virar a mesma pessoa.
    const homonimo = { ...STANDING, uid: "outro-uid", apelido: "Dona Sonia" };
    assert.equal(projetarJogador(homonimo, "uid-secreto-do-firebase").souEu, false);
  });
});

describe("projecao: campos ausentes viram ausencia, e nao invencao", () => {
  test("sem liga, o rotulo sai vazio", () => {
    // E nao "Bronze". O cliente exibe vazio.
    const semLiga = { ...STANDING, ligaId: null, ligaNome: null };
    assert.equal(projetarJogador(semLiga, null).liga, "");
  });

  test("em colocacao, o rotulo e o ESTADO e nao uma Liga", () => {
    // SECAO 15. O caso perigoso e o de baixo: a linha JA TEM `ligaId` gravado
    // (de uma temporada anterior, ou de um bug), e mesmo assim o jogador em
    // colocacao nao pode aparecer como Bronze.
    const colocando = { ...STANDING, estadoCompetitivo: "em_colocacao", partidasDeQualificacao: 3 };
    const p = projetarJogador(colocando, null);
    assert.equal(p.liga, "Em colocacao");
    assert.equal(p.ligaId, null, "estado vence liga gravada");
    assert.equal(p.qualificacaoRestante, 7);
  });

  test("em revalidacao, idem, com o rotulo proprio", () => {
    const revalidando = {
      ...STANDING,
      estadoCompetitivo: "em_revalidacao",
      qualificacaoExigida: 5,
      partidasDeQualificacao: 2,
    };
    const p = projetarJogador(revalidando, null);
    assert.equal(p.liga, "Em revalidacao");
    assert.equal(p.ligaId, null);
    assert.equal(p.qualificacaoRestante, 3);
  });

  test("classificado publica a Liga e nao tem qualificacao restante", () => {
    const p = projetarJogador(STANDING, null);
    assert.equal(p.liga, "ALTA");
    assert.equal(p.ligaId, "alta");
    assert.equal(p.qualificacaoRestante, 0);
  });

  test("os campos de apresentacao da secao 24 saem calculados", () => {
    const p = projetarJogador(STANDING, null);
    assert.equal(p.partidas, 42);
    assert.equal(p.vitorias, 25);
    assert.equal(p.derrotas, 15);
    // 25/42 = 59.52...%, com uma casa. Empate nao conta como vitoria nem como
    // derrota, entao vitorias + derrotas (40) < partidas (42).
    assert.equal(p.aproveitamento, 59.5);
  });

  test("sem partida, o aproveitamento e 0 e nao NaN", () => {
    const novo = { ...STANDING, partidasComputadas: 0, vitorias: 0 };
    assert.equal(projetarJogador(novo, null).aproveitamento, 0);
  });

  test("sem apuracao, a posicao sai 0", () => {
    // 0 nao e posicao valida em classificacao nenhuma, entao nao pode ser
    // confundido com "esta em primeiro".
    const semPosicao = { ...STANDING, posicao: null };
    assert.equal(projetarJogador(semPosicao, null).posicao, POSICAO_NAO_APURADA);
    assert.equal(POSICAO_NAO_APURADA, 0);
  });

  test("sem apelido, sai vazio — e nao um nome gerado", () => {
    const semNome = { ...STANDING, apelido: "", avatar: "" };
    const p = projetarJogador(semNome, null);
    assert.equal(p.apelido, "");
    assert.equal(p.avatar, "");
  });

  test("sem selo, sai nulo", () => {
    assert.equal(projetarJogador({ ...STANDING, selo: null }, null).selo, null);
  });
});

describe("projecao: o varredor de campo proibido", () => {
  test("acha campo proibido no topo", () => {
    assert.equal(acharCampoProibido({ uid: "x" }), "$.uid");
  });

  test("acha campo proibido aninhado", () => {
    assert.equal(acharCampoProibido({ resumo: { eu: { email: "a@b.c" } } }), "$.resumo.eu.email");
  });

  test("acha campo proibido dentro de lista", () => {
    assert.equal(acharCampoProibido({ itens: [{ id: "P1" }, { userId: "u" }] }), "$.itens[1].userId");
  });

  test("resposta limpa passa", () => {
    assert.equal(
      acharCampoProibido({
        resumo: { escopo: "temporada", podio: [projetarJogador(STANDING, null)] },
        primeiraPagina: { itens: [projetarJogador(STANDING, null)], fim: true },
      }),
      null
    );
  });

  test("a lista de proibidos cobre o que a secao 17 nomeia", () => {
    for (const exigido of ["email", "uid", "token", "deviceId", "ip"]) {
      assert.ok(CAMPOS_PROIBIDOS.includes(exigido), `faltou "${exigido}"`);
    }
  });
});

describe("identidade publica (secao 16)", () => {
  // A GERACAO NAO E MAIS TESTADA AQUI PORQUE NAO ACONTECE MAIS AQUI. Ate a OS de
  // integracao de identidade este bloco provava `idPublicoDeBytes` — o gerador
  // que este codebase mantinha em paralelo com o do dominio social. O gerador foi
  // removido (ver src/identidade.ts), e com ele os testes de geracao.
  //
  // A COBERTURA NAO ENCOLHEU, MUDOU DE DONO. O determinismo por bytes, o alfabeto
  // sem I/L/O/U, o comprimento e a recusa de bytes insuficientes sao provados em
  // app/test/social/teste_social.dart e functions-social/test/chaves.test.js, que
  // testam a UNICA implementacao que ainda existe. Ver
  // test/identidade.test.js deste codebase para a prova de que o gerador nao
  // voltou.
  //
  // O que sobra aqui e o que o ranking continua fazendo: RECONHECER um id.
  test("validacao de formato recusa lixo antes de tocar o banco", () => {
    assert.equal(idPublicoValido("PABC123XYZ456"), true);
    assert.equal(idPublicoValido("P0000000000000"), false, "13 simbolos apos o P");
    assert.equal(idPublicoValido("ABC123XYZ456"), false, "sem prefixo");
    assert.equal(idPublicoValido("PABC123XYZ45I"), false, "letra fora do alfabeto");
    assert.equal(idPublicoValido("PABC123XYZ45"), false, "curto demais");
    assert.equal(idPublicoValido(""), false);
    assert.equal(idPublicoValido(null), false);
    assert.equal(idPublicoValido(42), false);
  });

  test("um uid do Firebase nao passa como id publico", () => {
    assert.equal(idPublicoValido("uid-secreto-do-firebase"), false);
  });
});

describe("chave de standing", () => {
  test("a temporada vem primeiro", () => {
    // Com a temporada na frente, todas as linhas de uma temporada ficam
    // contiguas por documentId. Invertido, nao ficariam.
    assert.equal(chaveDeStanding("2026-A", "u1"), "2026-A|u1");
  });

  test("temporadas diferentes nao colidem para o mesmo jogador", () => {
    // A garantia da secao 6: a temporada seguinte grava em documento com OUTRO
    // id, e nao tem como sobrescrever a anterior.
    assert.notEqual(chaveDeStanding("2026-A", "u1"), chaveDeStanding("2026-B", "u1"));
  });
});
