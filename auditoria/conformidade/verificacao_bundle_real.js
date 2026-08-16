// C8-FECHAMENTO — PROVA CONTRA O BUNDLE REAL. Carrega os módulos de regra do
// server.js EFETIVAMENTE corrigido (branch correcao/conformidade-canonica) SEM
// subir o servidor (neutraliza só o bootstrap `ws_server.iniciar()`), e roda os
// vetores C8-A/C8-B nas funções REAIS (canastra/jogo/bot). Não abre porta, não
// acessa rede/produção. Uso:
//   BMV_SERVER_JS=/caminho/para/buraco-servidor/server.js node auditoria/conformidade/verificacao_bundle_real.js
const fs = require("fs");
const SERVER_JS = process.env.BMV_SERVER_JS || process.argv[2];
if (!SERVER_JS || !fs.existsSync(SERVER_JS)) {
  console.error("Informe o server.js corrigido em BMV_SERVER_JS ou argv[2]."); process.exit(2);
}
let src = fs.readFileSync(SERVER_JS, "utf8");
const BOOT = '__require("ws_server").iniciar();';
if (!src.includes(BOOT)) { console.error("bootstrap ws_server não encontrado — server.js inesperado"); process.exit(2); }
// Neutraliza APENAS o boot do WS (nada de listen/porta); expõe o loader de módulos.
src = src.replace(BOOT, "globalThis.__BMV_REQUIRE = __require;");
eval(src); // executa a IIFE: registra fábricas e expõe __require; NÃO sobe servidor
const __require = globalThis.__BMV_REQUIRE;
const canastra = __require("canastra");
const jogoM = __require("jogo");
const botM = __require("bot");

const C = (id, naipe, valor) => ({ id, naipe: valor === "JOKER" ? null : naipe, valor, eh_coringa: valor === "2" || valor === "JOKER" });
const seq = (n, vs, p) => vs.map((v, i) => C(p + i, n, v));
const AK = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const out = [];
const log = (id, got, esp) => out.push({ id, got, esp, ok: JSON.stringify(got) === JSON.stringify(esp) });

// CRIT-01 — de_500 reconhecido pelo motor real
{
  const r = canastra.validarJogo(seq("copas", AK, "d"), { permiteTrinca: true });
  log("REAL CRIT-01 de_500 (valido, tipo)", [r.valido, r.tipo], [true, "de_500"]);
}
// CRIT-02 — as_a_as reconhecido pelo motor real
{
  const r = canastra.validarJogo(seq("copas", [...AK, "A"], "e"), { permiteTrinca: true });
  log("REAL CRIT-02 as_a_as (valido, tipo)", [r.valido, r.tipo], [true, "as_a_as"]);
}
// CRIT-01 — pontuação real (contarPontos) + detalhe correto
function pontuar(meld) {
  const jogo = { duplaQueBateu: null, mortoPego: { nos: true, eles: true }, maos: [[], [], [], []],
    jogosDupla: { nos: [meld], eles: [] }, placar: { nos: 0, eles: 0 }, metaPontos: 1500, rodadasVulneravel: { nos: 0, eles: 0 } };
  jogoM.contarPontos(jogo);
  return { total: jogo.placar.nos, detalhe: jogo.pontosRodada.nos.detalhe };
}
{
  const p = pontuar(seq("copas", AK, "t")); // de_500: 500 + cartas 110 = 610
  log("REAL CRIT-01 pontuação de_500 (total)", p.total, 610);
  log("REAL CRIT-02 detalhe de_500 (de500=1, asas=0)", [p.detalhe.de500, p.detalhe.asas || 0], [1, 0]);
}
{
  const p = pontuar(seq("copas", [...AK, "A"], "u")); // as_a_as: 1000 + cartas 125 = 1125
  log("REAL CRIT-02 pontuação as_a_as (total)", p.total, 1125);
  log("REAL CRIT-02 detalhe as_a_as (asas=1, de500=0)", [p.detalhe.asas || 0, p.detalhe.de500], [1, 0]);
}
// CRIT-02 — estratégia do bot (decidirBater) reconhece as_a_as
{
  const r = botM.decidirBater({ mao: [], jogosMesaDupla: [seq("copas", [...AK, "A"], "b")], jaPegouMorto: true, permiteTrinca: true, bateComSuja: false });
  log("REAL CRIT-02 decidirBater reconhece as_a_as", r.deveBater, true);
}
// CRIT-03 — vulnerabilidade uniforme: BOT abrindo <mínimo é ANULADO (via descartar real)
{
  const jogo = {
    modalidade: "fechado", metaPontos: 1500,
    assentos: [{ tipo: "bot" }, { tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }],
    maos: [[C("last", "ouros", "K")], [], [], []], monte: [], mortos: [], lixo: [],
    jogosDupla: { nos: [seq("copas", ["3", "4", "5"], "w")], eles: [] }, // abre 15 (<75)
    mortoPego: { nos: true, eles: false }, rodadasVulneravel: { nos: 1, eles: 0 },
    abriuValido: { nos: false, eles: false }, placar: { nos: 0, eles: 0 },
    vez: 0, jaComprou: true, rodadaEncerrada: false, encerrada: false, deveUsarTopo: null, lixoCompradoNoTurno: null,
  };
  const r = jogoM.descartar(jogo, 0, "last");
  log("REAL CRIT-03 BOT <minimo é ANULADO (descarte recusado + mesa vazia)", [r.ok, jogo.jogosDupla.nos.length], [false, 0]);
}

let falhas = 0;
for (const r of out) { if (!r.ok) falhas++; console.log((r.ok ? "OK " : "XX ") + r.id + "  ->  " + JSON.stringify(r.got) + (r.ok ? "" : "  (esperado " + JSON.stringify(r.esp) + ")")); }
console.log("\nBUNDLE REAL (" + SERVER_JS + "): " + (out.length - falhas) + "/" + out.length + " conformes; CRIT remanescentes=" + falhas + (falhas === 0 ? "  → ZERO CRIT ✔" : ""));
process.exit(falhas === 0 ? 0 : 1);
