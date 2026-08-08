// C8 pós-deploy — GERA o conformidade_fixture.dart a partir dos MÓDULOS REAIS do
// server.js DEPLOYADO (corrigido). Carrega canastra/jogo sem subir o servidor.
// Uso: BMV_SERVER_JS=/caminho/buraco-servidor/server.js node gerar_fixture_deployado.js
// Emite: ../../app/test/conformidade_fixture.dart  e  resultados_node.json
// hashRegrasNode = sha256(server.js) — trava o fixture ao bundle deployado.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const SERVER_JS = process.env.BMV_SERVER_JS || process.argv[2];
if (!SERVER_JS || !fs.existsSync(SERVER_JS)) { console.error("Informe BMV_SERVER_JS."); process.exit(2); }
const raw = fs.readFileSync(SERVER_JS, "utf8");
const hashServer = crypto.createHash("sha256").update(raw).digest("hex");
const BOOT = '__require("ws_server").iniciar();';
if (!raw.includes(BOOT)) { console.error("bootstrap não encontrado"); process.exit(2); }
eval(raw.replace(BOOT, "globalThis.__BMV_REQUIRE = __require;"));
const __require = globalThis.__BMV_REQUIRE;
const canastra = __require("canastra");
const jogoM = __require("jogo");

const C = (id, naipe, valor) => ({ id, naipe: valor === "JOKER" ? null : naipe, valor });
const build = (specs) => specs.map((s) => ({ id: s.id, naipe: s.valor === "JOKER" ? null : s.naipe, valor: s.valor, eh_coringa: s.valor === "2" || s.valor === "JOKER" }));
const seq = (naipe, vals, pre) => vals.map((v, i) => C(`${pre}${i}`, naipe, v));
function nodeBonus(cards) {
  if (cards.length < 7) return 0;
  const r = canastra.validarSequencia(cards);
  if (!r.valido) return 0;
  return r.tipo === "as_a_as" ? 1000 : r.tipo === "de_500" ? 500 : r.tipo === "limpa" ? 200 : r.tipo === "suja" ? 100 : 0;
}
// Mesmos vetores do C8-A (node_harness). Pós-deploy: todos devem CONVERGIR → critEsperado null.
const MELD = [
  { id: "M01-limpa7", desc: "sequência limpa 7", modalidade: "fechado", permiteTrinca: true, cartas: seq("copas", ["3","4","5","6","7","8","9"], "a") },
  { id: "M02-suja7", desc: "sequência suja 7", modalidade: "fechado", permiteTrinca: true, cartas: [...seq("copas", ["3","4","5","6","7","8"], "b"), C("bJ", null, "JOKER")] },
  { id: "M03-trinca3", desc: "trinca natural 3", modalidade: "fechado", permiteTrinca: true, cartas: [C("t0","espadas","K"), C("t1","copas","K"), C("t2","ouros","K")] },
  { id: "M04-trinca-curinga", desc: "trinca com curinga (inválida)", modalidade: "fechado", permiteTrinca: true, cartas: [C("u0","espadas","K"), C("u1","copas","K"), C("u2",null,"JOKER")] },
  { id: "M05-ases3-fechado", desc: "grupo de 3 ases Fechado (EXC-04)", modalidade: "fechado", permiteTrinca: true, cartas: [C("v0","copas","A"), C("v1","ouros","A"), C("v2","espadas","A")] },
  { id: "M06-ases3-aberto", desc: "grupo de 3 ases Aberto (inválido)", modalidade: "aberto", permiteTrinca: false, cartas: [C("w0","copas","A"), C("w1","ouros","A"), C("w2","espadas","A")] },
  { id: "M07-de500", desc: "A–K limpa 13 (de_500)", modalidade: "fechado", permiteTrinca: true, cartas: seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "d") },
  { id: "M08-as_a_as", desc: "A–K–A (as_a_as)", modalidade: "fechado", permiteTrinca: true, cartas: seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K","A"], "e") },
  { id: "M09-naipes-mistos", desc: "naipes misturados (inválido)", modalidade: "fechado", permiteTrinca: true, cartas: [C("x0","copas","3"), C("x1","ouros","4"), C("x2","copas","5")] },
];
const SCORE = [
  { id: "S01-limpa7", desc: "canastra limpa 7", melds: [seq("copas", ["3","4","5","6","7","8","9"], "p")], mao: [], flags: { bateu: false, mortoPego: true, algumPegouMorto: false } },
  { id: "S02-batida", desc: "canastra + batida", melds: [seq("copas", ["3","4","5","6","7","8","9"], "q")], mao: [], flags: { bateu: true, mortoPego: true, algumPegouMorto: false } },
  { id: "S03-morto-nao-pego", desc: "morto não pego (−100)", melds: [seq("copas", ["3","4","5","6","7","8","9"], "r")], mao: [], flags: { bateu: false, mortoPego: false, algumPegouMorto: true } },
  { id: "S04-mao-desconta", desc: "desconto da mão", melds: [seq("copas", ["3","4","5","6","7","8","9"], "s")], mao: [C("m0","ouros","K"), C("m1",null,"JOKER")], flags: { bateu: false, mortoPego: true, algumPegouMorto: false } },
  { id: "S05-de500-pontos", desc: "pontuação de_500", melds: [seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "t")], mao: [], flags: { bateu: false, mortoPego: true, algumPegouMorto: false } },
];
function totalDupla(meldsSpec, maoSpec, flags) {
  const jogo = { duplaQueBateu: flags.bateu ? "nos" : null, mortoPego: { nos: flags.mortoPego, eles: flags.algumPegouMorto },
    maos: [build(maoSpec), [], [], []], jogosDupla: { nos: meldsSpec.map(build), eles: [] },
    placar: { nos: 0, eles: 0 }, metaPontos: 1500, rodadasVulneravel: { nos: 0, eles: 0 } };
  jogoM.contarPontos(jogo);
  return jogo.placar.nos;
}
const meldOut = MELD.map((v) => {
  const cards = build(v.cartas);
  const r = canastra.validarJogo(cards, { permiteTrinca: v.permiteTrinca });
  return { id: v.id, desc: v.desc, modalidade: v.modalidade, permiteTrinca: v.permiteTrinca, cartas: v.cartas, critEsperado: null, node: { valido: !!r.valido, tipo: r.tipo || null, bonus: nodeBonus(cards) } };
});
const scoreOut = SCORE.map((v) => ({ id: v.id, desc: v.desc, melds: v.melds, mao: v.mao, flags: v.flags, critEsperado: null, node: { total: totalDupla(v.melds, v.mao, v.flags) } }));
const fixture = { versaoSpec: "bmv-regras-2026.08", hashRegrasNode: hashServer, origem: { repo: "soniaambrosio/buraco-servidor", commit: "09835bd", arquivo: "server.js (DEPLOYADO/corrigido)" }, dataNota: "gerado dos módulos REAIS do server.js deployado", meld: meldOut, score: scoreOut };
fs.writeFileSync(path.join(__dirname, "resultados_node.json"), JSON.stringify(fixture, null, 2));
const jsonStr = JSON.stringify(fixture);
const dart = `// GERADO por auditoria/conformidade/gerar_fixture_deployado.js — NÃO EDITAR À MÃO.
// Lado NODE dos vetores C8 a partir dos MÓDULOS REAIS do server.js DEPLOYADO
// (corrigido, sha256 ${hashServer}). Pós-deploy: todos os vetores CONVERGEM
// (0 CRIT). hashRegrasNode trava o fixture ao bundle deployado.
const String c8FixtureJson = r'''${jsonStr}''';
`;
fs.writeFileSync(path.join(__dirname, "..", "..", "app", "test", "conformidade_fixture.dart"), dart);
console.log("fixture gerado do bundle real. hash=" + hashServer.slice(0, 12));
console.log("M07 de_500:", JSON.stringify(meldOut.find(m=>m.id==="M07-de500").node));
console.log("M08 as_a_as:", JSON.stringify(meldOut.find(m=>m.id==="M08-as_a_as").node));
console.log("S05 total:", scoreOut.find(s=>s.id==="S05-de500-pontos").node.total);
