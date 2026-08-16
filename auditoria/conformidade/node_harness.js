// C8 — HARNESS de conformidade (lado NODE). Roda os MESMOS vetores canônicos
// sobre o extrato de regras do servidor deployado e emite:
//   - resultados_node.json  (proveniência/auditoria)
//   - ../../app/test/conformidade_fixture.dart  (fixture lido pelo teste Dart)
// OFFLINE: não sobe o servidor, não abre porta, não acessa rede/produção.
// Reexecução: `node auditoria/conformidade/node_harness.js` a partir da raiz do repo.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const R = require("./servidor_regras_extraidas");

const extratoPath = path.join(__dirname, "servidor_regras_extraidas.js");
const hashRegrasNode = crypto.createHash("sha256").update(fs.readFileSync(extratoPath)).digest("hex");

const C = (id, naipe, valor) => ({ id, naipe: valor === "JOKER" ? null : naipe, valor });
const build = (specs) => specs.map((s) => R.buildCard(s.id, s.naipe, s.valor));

// Bônus de canastra do SERVIDOR para uma meld (mesma lógica de pontuarDupla).
function nodeBonus(cards) {
  if (cards.length < 7) return 0;
  const r = R.validarSequencia(cards);
  if (!r.valido) return 0;
  if (r.tipo === "de_500") return 500;
  if (r.tipo === "limpa") return 200;
  if (r.tipo === "suja") return 100;
  return 0;
}

// ---------- VETORES DE MELD (classificação/legalidade) ----------
// critEsperado: null = deve ser IGUAL; 'CRIT-xx' = divergência crítica conhecida.
const seq = (naipe, valores, pre) => valores.map((v, i) => C(`${pre}${i}`, naipe, v));
const MELD = [
  { id: "M01-limpa7", desc: "sequência limpa 7 (3–9 copas)", modalidade: "fechado", permiteTrinca: true,
    cartas: seq("copas", ["3","4","5","6","7","8","9"], "a"), critEsperado: null },
  { id: "M02-suja7", desc: "sequência suja 7 (3–8 copas + JOKER)", modalidade: "fechado", permiteTrinca: true,
    cartas: [...seq("copas", ["3","4","5","6","7","8"], "b"), C("bJ", null, "JOKER")], critEsperado: null },
  { id: "M03-trinca3", desc: "trinca natural de 3 (K K K)", modalidade: "fechado", permiteTrinca: true,
    cartas: [C("t0","espadas","K"), C("t1","copas","K"), C("t2","ouros","K")], critEsperado: null },
  { id: "M04-trinca-curinga", desc: "trinca com curinga (K K JOKER) — inválida", modalidade: "fechado", permiteTrinca: true,
    cartas: [C("u0","espadas","K"), C("u1","copas","K"), C("u2",null,"JOKER")], critEsperado: null },
  { id: "M05-ases3-fechado", desc: "grupo de 3 ases no Fechado (EXC-04: trinca × de_as)", modalidade: "fechado", permiteTrinca: true,
    cartas: [C("v0","copas","A"), C("v1","ouros","A"), C("v2","espadas","A")], critEsperado: null },
  { id: "M06-ases3-aberto", desc: "grupo de 3 ases no Aberto — inválido nos dois", modalidade: "aberto", permiteTrinca: false,
    cartas: [C("w0","copas","A"), C("w1","ouros","A"), C("w2","espadas","A")], critEsperado: null },
  { id: "M07-de500", desc: "A–K limpa 13 (de_500): canônico 500 × servidor limpa 200", modalidade: "fechado", permiteTrinca: true,
    cartas: seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "d"), critEsperado: "CRIT-01" },
  { id: "M08-as_a_as", desc: "A–K–A (as_a_as): canônico válido/1000 × servidor inválido", modalidade: "fechado", permiteTrinca: true,
    cartas: seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K","A"], "e"), critEsperado: "CRIT-02" },
  { id: "M09-naipes-mistos", desc: "naipes misturados — inválido nos dois", modalidade: "fechado", permiteTrinca: true,
    cartas: [C("x0","copas","3"), C("x1","ouros","4"), C("x2","copas","5")], critEsperado: null },
];

// ---------- VETORES DE PONTUAÇÃO ----------
const SCORE = [
  { id: "S01-limpa7", desc: "canastra limpa 7 sozinha", melds: [seq("copas", ["3","4","5","6","7","8","9"], "p")],
    mao: [], flags: { bateu: false, mortoPego: true, algumPegouMorto: false }, critEsperado: null },
  { id: "S02-batida", desc: "canastra limpa + batida (+100)", melds: [seq("copas", ["3","4","5","6","7","8","9"], "q")],
    mao: [], flags: { bateu: true, mortoPego: true, algumPegouMorto: false }, critEsperado: null },
  { id: "S03-morto-nao-pego", desc: "morto não pego (−100)", melds: [seq("copas", ["3","4","5","6","7","8","9"], "r")],
    mao: [], flags: { bateu: false, mortoPego: false, algumPegouMorto: true }, critEsperado: null },
  { id: "S04-mao-desconta", desc: "desconto das cartas na mão", melds: [seq("copas", ["3","4","5","6","7","8","9"], "s")],
    mao: [C("m0","ouros","K"), C("m1",null,"JOKER")], flags: { bateu: false, mortoPego: true, algumPegouMorto: false }, critEsperado: null },
  { id: "S05-de500-pontos", desc: "de_500 pontuação: canônico 500 × servidor 200", melds: [seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "t")],
    mao: [], flags: { bateu: false, mortoPego: true, algumPegouMorto: false }, critEsperado: "CRIT-01" },
];

// ---------- roda o lado NODE ----------
const meldOut = MELD.map((v) => {
  const cards = build(v.cartas);
  const r = R.validarJogo(cards, { permiteTrinca: v.permiteTrinca });
  return { id: v.id, desc: v.desc, modalidade: v.modalidade, permiteTrinca: v.permiteTrinca,
    cartas: v.cartas, critEsperado: v.critEsperado,
    node: { valido: !!r.valido, tipo: r.tipo || null, bonus: nodeBonus(cards) } };
});

const scoreOut = SCORE.map((v) => {
  const melds = v.melds.map(build);
  const mao = build(v.mao);
  const cartasNaMao = mao.reduce((s, c) => s + R.valorCarta(c), 0);
  const r = R.pontuarDupla(melds, { bateu: v.flags.bateu, mortoPego: v.flags.mortoPego,
    cartasNaMao, algumPegouMorto: v.flags.algumPegouMorto });
  return { id: v.id, desc: v.desc, melds: v.melds, mao: v.mao, flags: v.flags, critEsperado: v.critEsperado,
    node: { total: r.total, pontosCanastras: r.pontosCanastras, pontosCartas: r.pontosCartas,
      bonusBatida: r.bonusBatida, penalidadeMorto: r.penalidadeMorto, descontoMao: r.descontoMao } };
});

const fixture = { versaoSpec: "bmv-regras-2026.08", hashRegrasNode,
  origem: R.ORIGEM, dataNota: "clone só-leitura; server.js sha256 c43c3e98a6bd5d3bc1a7f184bcde33b86ee92e6ba8c935ea46139be37cf67dba",
  meld: meldOut, score: scoreOut };

fs.writeFileSync(path.join(__dirname, "resultados_node.json"), JSON.stringify(fixture, null, 2));

const dartPath = path.join(__dirname, "..", "..", "app", "test", "conformidade_fixture.dart");
const jsonStr = JSON.stringify(fixture);
const dart = `// GERADO por auditoria/conformidade/node_harness.js — NÃO EDITAR À MÃO.
// Lado NODE dos vetores de conformidade C8 (servidor deployado, só leitura).
// Origem: buraco-servidor/server.js@be72bb6 (sha256 c43c3e98…). Sem segredos.
// O teste Dart (C8-CONFORMIDADE) roda o motor canônico nos MESMOS vetores e
// compara com este fixture. hashRegrasNode trava o extrato usado.
const String c8FixtureJson = r'''${jsonStr}''';
`;
fs.writeFileSync(dartPath, dart);
console.log("OK meld=" + meldOut.length + " score=" + scoreOut.length + " hash=" + hashRegrasNode.slice(0, 12));
console.log("criticos node esperados:", [...new Set([...MELD, ...SCORE].filter(v => v.critEsperado).map(v => v.critEsperado))].join(","));
