// C8-B — HARNESS SÓ-LEITURA do FLUXO do servidor. Copia VERBATIM as funções de
// fluxo do módulo "jogo" (server.js@be72bb6) e as EXECUTA sobre estados jogo{}
// sintéticos, para dar EVIDÊNCIA EMPÍRICA ao relatório. Não sobe o servidor,
// não abre porta, não acessa rede/produção, não altera o servidor.
// Reexecução: `node auditoria/conformidade/fluxo_harness.js`.
const R = require("./servidor_regras_extraidas");
const { validarSequencia, validarJogo, valorCarta, buildCard } = R;

const CARTAS_POR_MAO = 11, CARTAS_POR_MORTO = 11;
const duplaDoAssento = (a) => (a % 2 === 0 ? "nos" : "eles");
const permiteTrinca = (jogo) => jogo && jogo.modalidade === "fechado";
const validarJogoMesa = (jogo, cartas) => validarJogo(cartas, { permiteTrinca: permiteTrinca(jogo) });
const idxNaMao = (jogo, assento, id) => jogo.maos[assento].findIndex((c) => c.id === id);
const topoLixo = (jogo) => (jogo.lixo.length ? jogo.lixo[jogo.lixo.length - 1] : null);

// ---- VERBATIM do server.js (módulo jogo) ----
function validarVez(jogo, assento, { precisaComprar, precisaTerComprado } = {}) {
  if (jogo.encerrada) return { ok: false, erro: "a partida já terminou" };
  if (jogo.rodadaEncerrada) return { ok: false, erro: "a rodada já terminou" };
  if (jogo.vez !== assento) return { ok: false, erro: "não é a sua vez" };
  if (precisaComprar && jogo.jaComprou) return { ok: false, erro: "você já comprou nesta jogada" };
  if (precisaTerComprado && !jogo.jaComprou) return { ok: false, erro: "compre uma carta antes de baixar/descartar" };
  return { ok: true };
}
function comprarMonte(jogo, assento) {
  const v = validarVez(jogo, assento, { precisaComprar: true });
  if (!v.ok) return v;
  if (jogo.monte.length === 0) {
    if (jogo.mortos.length > 0) { jogo.monte = jogo.mortos.shift(); }
    else { encerrarRodadaPorEsgotamento(jogo); return { ok: false, erro: "monte e mortos esgotados — rodada encerrada" }; }
  }
  const carta = jogo.monte.shift();
  jogo.maos[assento].push(carta);
  jogo.jaComprou = true;
  jogo.lixoCompradoNoTurno = null;
  return { ok: true, carta };
}
function baixar(jogo, assento, idsCartas) {
  const v = validarVez(jogo, assento, { precisaTerComprado: true });
  if (!v.ok) return v;
  if (!idsCartas || idsCartas.length < 3) return { ok: false, erro: "um jogo tem no mínimo 3 cartas" };
  const cartas = [];
  for (const id of idsCartas) {
    const idx = idxNaMao(jogo, assento, id);
    if (idx === -1) return { ok: false, erro: "carta " + id + " não está na sua mão" };
    cartas.push(jogo.maos[assento][idx]);
  }
  const res = validarJogoMesa(jogo, cartas);
  if (!res.valido) return { ok: false, erro: res.motivo || "jogo inválido" };
  const dupla = duplaDoAssento(assento);
  const maoRestBaixar = jogo.maos[assento].length - cartas.length;
  if (baixadaTravaria(jogo, dupla, maoRestBaixar, jogo.jogosDupla[dupla].concat([cartas]))) {
    return { ok: false, erro: ERRO_TRAVARIA };
  }
  const ids = new Set(idsCartas);
  jogo.maos[assento] = jogo.maos[assento].filter((c) => !ids.has(c.id));
  jogo.jogosDupla[dupla].push(cartas);
  quitarTravaTopoSePreciso(jogo, assento, ids);
  return Object.assign({ ok: true, tipo: res.tipo }, aoZerarMaoBaixando(jogo, assento));
}
function quitarTravaTopoSePreciso(jogo, assento, idsSet) {
  if (jogo.deveUsarTopo && jogo.deveUsarTopo.assento === assento && idsSet.has(jogo.deveUsarTopo.idTopo)) jogo.deveUsarTopo = null;
}
function aoZerarMaoBaixando(jogo, assento) {
  if (jogo.maos[assento].length !== 0) return null;
  const dupla = duplaDoAssento(assento);
  if (!jogo.mortoPego[dupla] && jogo.mortos.length > 0) {
    jogo.maos[assento] = jogo.mortos.shift(); jogo.mortoPego[dupla] = true; return { pegouMorto: true };
  }
  if (duplaPodeBater(jogo, dupla)) { encerrarRodada(jogo, dupla); return { bateu: true }; }
  return null;
}
function topoTemUsoLegal(jogo, assento, topo) {
  const mao = jogo.maos[assento];
  const jogos = jogo.jogosDupla[duplaDoAssento(assento)];
  const cand = mao.filter((c) => c.id !== topo.id);
  for (const meld of jogos) {
    if (validarJogoMesa(jogo, meld.concat([topo])).valido) return true;
    for (let a = 0; a < cand.length; a++) {
      if (validarJogoMesa(jogo, meld.concat([topo, cand[a]])).valido) return true;
      for (let b = a + 1; b < cand.length; b++) {
        if (validarJogoMesa(jogo, meld.concat([topo, cand[a], cand[b]])).valido) return true;
      }
    }
  }
  for (let a = 0; a < cand.length; a++) {
    for (let b = a + 1; b < cand.length; b++) {
      if (validarJogoMesa(jogo, [topo, cand[a], cand[b]]).valido) return true;
    }
  }
  return false;
}
function comprarLixo(jogo, assento) {
  const v = validarVez(jogo, assento, { precisaComprar: true });
  if (!v.ok) return v;
  if (jogo.lixo.length === 0) return { ok: false, erro: "o lixo está vazio" };
  const topo = topoLixo(jogo);
  if (jogo.modalidade !== "aberto") {
    if (!topoTemUsoLegal(jogo, assento, topo)) return { ok: false, erro: "o topo do lixo não tem uso imediato (carta não tem mola)" };
    jogo.deveUsarTopo = { assento, idTopo: topo.id };
  }
  const qtd = jogo.lixo.length;
  jogo.lixoCompradoNoTurno = jogo.lixo.slice();
  jogo.maos[assento] = jogo.maos[assento].concat(jogo.lixo);
  jogo.lixo = [];
  jogo.jaComprou = true;
  return { ok: true, qtd, topo };
}
function checarAberturaVulneravel(jogo, assento) {
  const dupla = duplaDoAssento(assento);
  if (jogo.abriuValido[dupla]) return null;
  const melds = jogo.jogosDupla[dupla];
  if (melds.length === 0) return null;
  const niv = jogo.rodadasVulneravel[dupla];
  if (niv <= 0) { jogo.abriuValido[dupla] = true; return null; }
  const min = niv === 1 ? 75 : 90;
  const total = melds.reduce((s, m) => s + m.reduce((t, c) => t + valorCarta(c), 0), 0);
  if (total >= min) { jogo.abriuValido[dupla] = true; return null; }
  if (jogo.assentos[assento].tipo !== "humano") { jogo.abriuValido[dupla] = true; return null; }
  for (const meld of melds) jogo.maos[assento].push(...meld);
  jogo.jogosDupla[dupla] = [];
  let lixoVoltou = false;
  if (jogo.lixoCompradoNoTurno && jogo.lixoCompradoNoTurno.length) {
    const idsLixo = new Set(jogo.lixoCompradoNoTurno.map((c) => c.id));
    jogo.maos[assento] = jogo.maos[assento].filter((c) => !idsLixo.has(c.id));
    jogo.lixo = jogo.lixoCompradoNoTurno.slice(); jogo.lixoCompradoNoTurno = null; jogo.jaComprou = false; lixoVoltou = true;
  }
  jogo.rodadasVulneravel[dupla] = 2; jogo.deveUsarTopo = null;
  return { total, min, lixoVoltou };
}
function descartar(jogo, assento, idCarta) {
  const v = validarVez(jogo, assento, { precisaTerComprado: true });
  if (!v.ok) return v;
  if (jogo.deveUsarTopo && jogo.deveUsarTopo.assento === assento) {
    return { ok: false, erro: "você comprou o lixo — precisa usar a carta do topo antes de descartar" };
  }
  const foul = checarAberturaVulneravel(jogo, assento);
  if (foul) return { ok: false, erro: "abertura ANULADA (" + foul.total + " < " + foul.min + ")" };
  const idx = idxNaMao(jogo, assento, idCarta);
  if (idx === -1) return { ok: false, erro: "carta não está na sua mão" };
  const dupla = duplaDoAssento(assento);
  const zeraria = jogo.maos[assento].length === 1;
  const podeBatidaFinal = jogo.mortoPego[dupla] || jogo.mortos.length === 0;
  if (zeraria && podeBatidaFinal && !duplaPodeBater(jogo, dupla)) {
    return { ok: false, erro: "pra bater você precisa de uma canastra na mesa da dupla" };
  }
  const carta = jogo.maos[assento].splice(idx, 1)[0];
  jogo.lixo.push(carta);
  if (jogo.maos[assento].length === 0) {
    if (!jogo.mortoPego[dupla] && jogo.mortos.length > 0) {
      jogo.maos[assento] = jogo.mortos.shift(); jogo.mortoPego[dupla] = true; passarVez(jogo);
      return { ok: true, descarte: carta, pegouMorto: true };
    }
    encerrarRodada(jogo, dupla); return { ok: true, descarte: carta, bateu: true };
  }
  passarVez(jogo);
  return { ok: true, descarte: carta };
}
function duplaPodeBater(jogo, dupla) {
  const aceitaSuja = jogo.modalidade === "fechado";
  return jogo.jogosDupla[dupla].some((meld) => {
    if (meld.length < 7) return false;
    const res = validarSequencia(meld);
    if (!res.valido) return false;
    if (res.tipo === "limpa" || res.tipo === "de_500") return true;
    return aceitaSuja && res.tipo === "suja";
  });
}
function baixadaTravaria(jogo, dupla, maoRestante, meldsFuturos) {
  if (maoRestante >= 2) return false;
  const temLimpa = meldsFuturos.some((m) => {
    if (m.length < 7) return false;
    const r = validarSequencia(m);
    return r.valido && (r.tipo === "limpa" || r.tipo === "de_500");
  });
  const mortoDisp = !jogo.mortoPego[dupla] && jogo.mortos.length > 0;
  return !(temLimpa || mortoDisp);
}
const ERRO_TRAVARIA = "ficaria com uma carta impossível de descartar (sem canastra limpa e sem morto)";
function passarVez(jogo) {
  if (jogo.monte.length === 0) {
    if (jogo.mortos.length === 0) { encerrarRodadaPorEsgotamento(jogo); return; }
    jogo.monte = jogo.mortos.shift();
  }
  jogo.vez = (jogo.vez + 1) % 4; jogo.jaComprou = false; jogo.deveUsarTopo = null; jogo.lixoCompradoNoTurno = null;
}
function encerrarRodadaPorEsgotamento(jogo) { encerrarRodada(jogo, null); }
function encerrarRodada(jogo, duplaQueBateu) {
  if (jogo.rodadaEncerrada) return;
  jogo.rodadaEncerrada = true; jogo.duplaQueBateu = duplaQueBateu;
}

// ---- utilidades de teste ----
const C = (id, naipe, valor) => buildCard(id, naipe, valor);
const seq = (naipe, vals, pre) => vals.map((v, i) => C(`${pre}${i}`, naipe, v));
const morto11 = (pre) => Array.from({ length: 11 }, (_, i) => C(`${pre}${i}`, "copas", "5"));
function mkJogo(o = {}) {
  return {
    modalidade: o.modalidade || "fechado", metaPontos: o.metaPontos || 1500,
    monte: o.monte || [C("mo0", "espadas", "K")], lixo: o.lixo || [],
    mortos: o.mortos || [], maos: o.maos || [[], [], [], []],
    jogosDupla: o.jogosDupla || { nos: [], eles: [] },
    mortoPego: o.mortoPego || { nos: false, eles: false },
    rodadasVulneravel: o.rodadasVulneravel || { nos: 0, eles: 0 },
    abriuValido: o.abriuValido || { nos: false, eles: false },
    assentos: o.assentos || [{ tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }],
    vez: o.vez == null ? 0 : o.vez, jaComprou: !!o.jaComprou, encerrada: false, rodadaEncerrada: !!o.rodadaEncerrada,
    deveUsarTopo: o.deveUsarTopo || null, lixoCompradoNoTurno: null,
  };
}
function idsDo(jogo) {
  const s = [];
  for (const m of jogo.maos) for (const c of m) s.push(c.id);
  for (const c of jogo.monte) s.push(c.id);
  for (const c of jogo.lixo) s.push(c.id);
  for (const mm of jogo.mortos) for (const c of mm) s.push(c.id);
  for (const g of jogo.jogosDupla.nos) for (const c of g) s.push(c.id);
  for (const g of jogo.jogosDupla.eles) for (const c of g) s.push(c.id);
  return s.sort();
}
const out = [];
const log = (id, got, esperado) => out.push({ id, got, esperado, ok: got === esperado });

// T12 fora da vez
log("T12 comprarMonte fora da vez", comprarMonte(mkJogo({ vez: 0 }), 1).erro, "não é a sua vez");
log("T12 baixar fora da vez", baixar(mkJogo({ vez: 0, jaComprou: true }), 1, ["a", "b", "c"]).erro, "não é a sua vez");
// T07 compra dupla
log("T07 compra dupla", comprarMonte(mkJogo({ vez: 0, jaComprou: true }), 0).erro, "você já comprou nesta jogada");
// T08 descarte antes de comprar
log("T08 descarte antes da compra", descartar(mkJogo({ vez: 0, jaComprou: false, maos: [[C("h", "copas", "3")], [], [], []] }), 0, "h").erro, "compre uma carta antes de baixar/descartar");
// T13 rodada encerrada
log("T13 rodada encerrada", comprarMonte(mkJogo({ vez: 0, rodadaEncerrada: true }), 0).erro, "a rodada já terminou");
// T03 lixo fechado: topo com uso -> ok + deveUsarTopo; depois descarte travado
{
  const jogo = mkJogo({ modalidade: "fechado", vez: 0, lixo: [C("lx", "copas", "5")],
    maos: [[C("m3", "copas", "3"), C("m4", "copas", "4"), C("z", "ouros", "K")], [], [], []] });
  const r = comprarLixo(jogo, 0);
  log("T03 comprarLixo topo com uso (fechado)", r.ok === true && !!jogo.deveUsarTopo, true);
  log("T03 descarte travado ate usar topo", descartar(jogo, 0, "z").erro, "você comprou o lixo — precisa usar a carta do topo antes de descartar");
}
// T03b topo SEM uso -> rejeita
{
  const jogo = mkJogo({ modalidade: "fechado", vez: 0, lixo: [C("lx", "copas", "K")],
    maos: [[C("a", "ouros", "3"), C("b", "espadas", "7")], [], [], []] });
  log("T03b comprarLixo topo sem uso (fechado)", comprarLixo(jogo, 0).erro, "o topo do lixo não tem uso imediato (carta não tem mola)");
}
// T04 enterradas NÃO justificam: topo sozinho sem uso; carta ENTERRADA completaria, mas está no lixo, não na mão
{
  // lixo = [enterrada 4copas, topo 5copas]; mão tem 3copas e 6copas. topo(5)+3+? na mão: 3,5 e falta 4 (que está enterrada).
  // topoTemUsoLegal vê só mão(3,6)+topo(5): 3-5 não forma sem 4; 5-6 precisa 7; nenhum jogo -> rejeita.
  const jogo = mkJogo({ modalidade: "fechado", vez: 0,
    lixo: [C("ent", "copas", "4"), C("top", "copas", "5")],
    maos: [[C("h3", "copas", "3"), C("h6", "copas", "6")], [], [], []] });
  log("T04 enterrada nao justifica compra", comprarLixo(jogo, 0).erro, "o topo do lixo não tem uso imediato (carta não tem mola)");
}
// T05 aberto pega lixo sem baixar
{
  const jogo = mkJogo({ modalidade: "aberto", vez: 0, lixo: [C("lx", "copas", "K")], maos: [[C("x", "ouros", "3")], [], [], []] });
  const r = comprarLixo(jogo, 0);
  log("T05 aberto pega lixo sem baixar", r.ok === true && jogo.deveUsarTopo === null, true);
}
// T09 morto DIRETO (zera baixando, mantem a vez)
{
  const jogo = mkJogo({ vez: 0, jaComprou: true, mortos: [morto11("k")], mortoPego: { nos: false, eles: false },
    maos: [seq("copas", ["3", "4", "5"], "d"), [], [], []] });
  const r = baixar(jogo, 0, ["d0", "d1", "d2"]);
  log("T09 morto direto pegouMorto", r.pegouMorto === true, true);
  log("T09 morto direto mantem a vez", jogo.vez, 0);
  log("T09 morto direto mao=11", jogo.maos[0].length, 11);
}
// T09 morto INDIRETO (zera descartando, passa a vez)
{
  const jogo = mkJogo({ vez: 0, jaComprou: true, mortos: [morto11("k")], mortoPego: { nos: false, eles: false },
    maos: [[...seq("copas", ["3", "4", "5"], "d"), C("ext", "ouros", "Q")], [], [], []] });
  baixar(jogo, 0, ["d0", "d1", "d2"]); // sobra 1 (ext)
  const r = descartar(jogo, 0, "ext");
  log("T10 morto indireto pegouMorto", r.pegouMorto === true, true);
  log("T10 morto indireto passa a vez", jogo.vez, 1);
}
// T10 batida no descarte (morto cumprido + canastra limpa)
{
  const jogo = mkJogo({ vez: 0, jaComprou: true, mortos: [], mortoPego: { nos: true, eles: false },
    jogosDupla: { nos: [seq("copas", ["3", "4", "5", "6", "7", "8", "9"], "L")], eles: [] },
    maos: [[C("u", "ouros", "K")], [], [], []] });
  const r = descartar(jogo, 0, "u");
  log("T10 batida no descarte", r.bateu === true && jogo.rodadaEncerrada === true, true);
}
// T11 baixar a ultima carta sem morto/canastra -> rejeita
{
  const jogo = mkJogo({ vez: 0, jaComprou: true, mortos: [], mortoPego: { nos: true, eles: false },
    maos: [seq("copas", ["3", "4", "5"], "d"), [], [], []] });
  log("T11 baixar ultima sem morto/canastra", baixar(jogo, 0, ["d0", "d1", "d2"]).erro, ERRO_TRAVARIA);
}
// T14 conservacao de IDs numa sequencia comprar->baixar->descartar
{
  const jogo = mkJogo({ vez: 0, monte: [C("mo0", "espadas", "K")], mortos: [morto11("k")],
    maos: [[...seq("copas", ["3", "4", "5"], "d"), C("ext", "ouros", "Q")], [], [], []] });
  const antes = idsDo(jogo); // inclui o topo do monte (mo0), que será MOVIDO p/ mão
  comprarMonte(jogo, 0);
  baixar(jogo, 0, ["d0", "d1", "d2"]);
  const depois = idsDo(jogo);
  // Conservação = MESMO multiconjunto de IDs (comprar/baixar MOVEM cartas, não criam).
  const conserva = antes.length === depois.length && antes.every((id, i) => id === depois[i]);
  log("T14 conservacao de IDs (nada some/duplica)", conserva, true);
}

// CRIT-03 (decisão Sônia): o MOTOR do servidor ISENTA bots do foul de abertura
// vulnerável (l.1974 `if tipo !== "humano"`), enquanto o canônico aplica o mínimo
// +75/+90 UNIFORMEMENTE (avaliarBaixar não conhece humano/bot). Vetor cross-engine
// específico: mesma abertura fraca de dupla vulnerável, assento BOT × assento HUMANO.
{
  // BOT vulnerável (nível 1 → mín 75) abre fraco (15) → servidor DEIXA em pé (sem foul).
  const bot = mkJogo({ modalidade: "fechado", vez: 0, jaComprou: true,
    rodadasVulneravel: { nos: 1, eles: 0 },
    assentos: [{ tipo: "bot" }, { tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }],
    maos: [[...seq("copas", ["3", "4", "5"], "d"), C("kx", "ouros", "K"), C("qx", "ouros", "Q")], [], [], []] });
  baixar(bot, 0, ["d0", "d1", "d2"]);           // abre 15 pts (< 75)
  const rb = descartar(bot, 0, "kx");            // servidor: bot isento → descarte OK e abertura FICA
  log("CRIT-03 servidor deixa BOT abrir <minimo (fica em pe)", rb.ok === true && bot.jogosDupla.nos.length === 1, true);

  // HUMANO no MESMO caso → foul: abertura ANULADA e descarte recusado (assimetria).
  const hum = mkJogo({ modalidade: "fechado", vez: 0, jaComprou: true,
    rodadasVulneravel: { nos: 1, eles: 0 },
    assentos: [{ tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }, { tipo: "humano" }],
    maos: [[...seq("copas", ["3", "4", "5"], "d"), C("kx", "ouros", "K"), C("qx", "ouros", "Q")], [], [], []] });
  baixar(hum, 0, ["d0", "d1", "d2"]);
  const rh = descartar(hum, 0, "kx");            // humano: foul → recusa e anula
  log("CRIT-03 servidor ANULA HUMANO no mesmo caso (assimetria bot×humano)", rh.ok === false && hum.jogosDupla.nos.length === 0, true);
  // Canônico: avaliarBaixar aplica o mínimo aos DOIS (rejeita no baixar). A assimetria
  // acima é a divergência CRIT-03 — bloqueia online até o servidor validar bot=humano.
}

let falhas = 0;
for (const r of out) {
  const marca = r.ok ? "OK " : "XX ";
  if (!r.ok) falhas++;
  console.log(marca + r.id + "  ->  " + JSON.stringify(r.got) + (r.ok ? "" : "  (esperado " + JSON.stringify(r.esperado) + ")"));
}
console.log("\nRESUMO: " + (out.length - falhas) + "/" + out.length + " cenários com comportamento esperado; falhas=" + falhas);
