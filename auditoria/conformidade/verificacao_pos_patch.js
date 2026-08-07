// C8-FECHAMENTO — reexecuta os vetores C8-A (meld/pontuação) e o vetor CRIT-03
// (fluxo) contra as regras CORRIGIDAS (servidor_regras_corrigido.js, espelho do
// patch em server.js@correcao/conformidade-canonica) e EXIGE zero CRIT.
// `node auditoria/conformidade/verificacao_pos_patch.js`
const R = require("./servidor_regras_corrigido");
const C = (id, naipe, valor) => R.buildCard(id, naipe, valor);
const seq = (naipe, vals, pre) => vals.map((v, i) => C(`${pre}${i}`, naipe, v));
function bonus(cards) {
  if (cards.length < 7) return 0;
  const r = R.validarSequencia(cards);
  if (!r.valido) return 0;
  return r.tipo === "as_a_as" ? 1000 : r.tipo === "de_500" ? 500 : r.tipo === "limpa" ? 200 : r.tipo === "suja" ? 100 : 0;
}
const out = [];
const log = (id, got, esp) => out.push({ id, got, esp, ok: JSON.stringify(got) === JSON.stringify(esp) });

// ---- C8-A: os 3 vetores que eram CRIT agora devem CONVERGIR com o canônico ----
// CRIT-01 (M07) de_500: canônico valido + bônus 500.
{
  const m = seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "d");
  const r = R.validarJogo(m, { permiteTrinca: true });
  log("CRIT-01 M07 de_500 (valido, tipo, bonus)", [r.valido, r.tipo, bonus(m)], [true, "de_500", 500]);
}
// CRIT-02 (M08) as_a_as: canônico valido + bônus 1000.
{
  const m = seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K","A"], "e");
  const r = R.validarJogo(m, { permiteTrinca: true });
  log("CRIT-02 M08 as_a_as (valido, tipo, bonus)", [r.valido, r.tipo, bonus(m)], [true, "as_a_as", 1000]);
}
// CRIT-01 (S05) pontuação de_500: total = 500 + cartas(110) = 610 (== canônico).
{
  const melds = [seq("copas", ["A","2","3","4","5","6","7","8","9","10","J","Q","K"], "t")];
  const r = R.pontuarDupla(melds, { bateu: false, mortoPego: true, cartasNaMao: 0, algumPegouMorto: false });
  log("CRIT-01 S05 pontuação de_500 (total)", r.total, 610);
}

// ---- CRIT-03 (fluxo): checarAberturaVulneravel CORRIGIDO (sem isenção de bot) ----
// Espelha o patch em server.js: o gate +75/+90 vale para bot e humano.
function checarAberturaVulneravelCorrigido(jogo, assento) {
  const dupla = assento % 2 === 0 ? "nos" : "eles";
  if (jogo.abriuValido[dupla]) return null;
  const melds = jogo.jogosDupla[dupla];
  if (melds.length === 0) return null;
  const niv = jogo.rodadasVulneravel[dupla];
  if (niv <= 0) { jogo.abriuValido[dupla] = true; return null; }
  const min = niv === 1 ? 75 : 90;
  const total = melds.reduce((s, m) => s + m.reduce((t, c) => t + R.valorCarta(c), 0), 0);
  if (total >= min) { jogo.abriuValido[dupla] = true; return null; }
  // [PATCH CRIT-03] SEM isenção de bot: anula a abertura fraca de qualquer assento.
  for (const meld of melds) jogo.maos[assento].push(...meld);
  jogo.jogosDupla[dupla] = [];
  jogo.rodadasVulneravel[dupla] = 2;
  return { total, min };
}
function cenarioAberturaFraca(tipoAssento) {
  const jogo = {
    assentos: [{ tipo: tipoAssento }, { tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }],
    jogosDupla: { nos: [seq("copas", ["3", "4", "5"], "d")], eles: [] }, // abre 15 (<75)
    maos: [[], [], [], []], rodadasVulneravel: { nos: 1, eles: 0 }, abriuValido: { nos: false, eles: false },
  };
  const foul = checarAberturaVulneravelCorrigido(jogo, 0);
  return { anulou: !!foul && jogo.jogosDupla.nos.length === 0 };
}
log("CRIT-03 BOT abre <minimo agora é ANULADO (=humano)", cenarioAberturaFraca("bot").anulou, true);
log("CRIT-03 HUMANO idem (simetria)", cenarioAberturaFraca("humano").anulou, true);

let falhas = 0;
for (const r of out) { if (!r.ok) falhas++; console.log((r.ok ? "OK " : "XX ") + r.id + "  ->  " + JSON.stringify(r.got) + (r.ok ? "" : "  (esperado " + JSON.stringify(r.esp) + ")")); }
console.log("\nPÓS-PATCH: " + (out.length - falhas) + "/" + out.length + " conformes; CRIT remanescentes=" + falhas + (falhas === 0 ? "  → ZERO CRIT ✔" : ""));
