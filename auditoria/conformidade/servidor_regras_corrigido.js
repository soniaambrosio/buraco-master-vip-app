// C8-FECHAMENTO — EXTRATO CORRIGIDO (espelha o patch server.js@branch correcao/
// conformidade-canonica). CRIT-01/02/03 aplicados. Serve para reexecutar os vetores
// e provar 0 CRIT. NÃO é o deployado (esse fica em servidor_regras_extraidas.js).
// ORIGINAL:
// Origem: soniaambrosio/buraco-servidor  server.js @ be72bb6
//   sha256(server.js) = c43c3e98a6bd5d3bc1a7f184bcde33b86ee92e6ba8c935ea46139be37cf67dba
//   - módulo "carta":    NAIPES/VALORES/ORDEM_SEQUENCIA (l.25-31)
//   - módulo "canastra":  validarSequencia (l.138), validarTrinca (l.237),
//                         validarJogo (l.262), finalizar (l.279)
//   - módulo "jogo":      valorCarta (l.2148), pontuarDuplaJogo (l.2158) -> pontuarDupla
// Reproduzido VERBATIM (só recortado para funções puras). SEM I/O, SEM rede,
// SEM persistência, SEM segredos. NÃO altera e NÃO faz deploy no servidor.
// Serve apenas para rodar os mesmos vetores no Node e comparar com o Dart.

const NAIPES = ["copas", "ouros", "paus", "espadas"];
const VALORES_NUMERICOS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const ORDEM_SEQUENCIA = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

const MIN_CARTAS_SEQUENCIA = 3;
const MIN_CARTAS_CANASTRA = 7;
const MAX_CURINGAS_SEQUENCIA_NORMAL = 1;

// --- carta: monta uma carta no formato do servidor ({id,naipe,valor,eh_coringa}).
// eh_coringa segue criarCarta/criarJoker: o "2" é curinga natural (mantém naipe);
// o JOKER é curinga sem naipe.
function buildCard(id, naipe, valor) {
  return { id, naipe: valor === "JOKER" ? null : naipe, valor, eh_coringa: valor === "2" || valor === "JOKER" };
}

// ===== canastra (VERBATIM) =====
function validarSequencia(cartas) {
  if (!cartas || cartas.length < MIN_CARTAS_SEQUENCIA) {
    return { valido: false, motivo: `Mínimo de ${MIN_CARTAS_SEQUENCIA} cartas para formar um jogo` };
  }
  const curingas = cartas.filter((c) => c.eh_coringa);
  const naoCuringas = cartas.filter((c) => !c.eh_coringa);
  if (curingas.length === cartas.length) {
    return finalizar({ tipoBase: "de_curinga", qtdCuringas: curingas.length, tamanho: cartas.length });
  }
  if (curingas.length === 0 && naoCuringas.every((c) => c.valor === "A")) {
    return finalizar({ tipoBase: "de_as", qtdCuringas: 0, tamanho: cartas.length });
  }
  // [PATCH CRIT-01] de_500
  if (cartas.length === 13 && !cartas.some((c) => c.valor === "JOKER")) {
    const n = new Set(cartas.map((c) => c.naipe));
    if (n.size === 1 && !cartas.some((c) => c.naipe == null)) {
      const v = new Set(cartas.map((c) => c.valor));
      const alvo = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"];
      if (v.size === 13 && alvo.every((x) => v.has(x))) return finalizar({ tipoBase: "de_500", qtdCuringas: 0, tamanho: 13 });
    }
  }
  // [PATCH CRIT-02] as_a_as
  if (cartas.length === 14 && !cartas.some((c) => c.valor === "JOKER")) {
    const n = new Set(cartas.map((c) => c.naipe));
    if (n.size === 1 && !cartas.some((c) => c.naipe == null)) {
      const ases = cartas.filter((c) => c.valor === "A");
      const na = cartas.filter((c) => c.valor !== "A");
      const v = new Set(na.map((c) => c.valor));
      const alvo = ["2","3","4","5","6","7","8","9","10","J","Q","K"];
      if (ases.length === 2 && na.length === 12 && v.size === 12 && alvo.every((x) => v.has(x))) return finalizar({ tipoBase: "as_a_as", qtdCuringas: 0, tamanho: 14 });
    }
  }
  const jokers = cartas.filter((c) => c.valor === "JOKER");
  const dois = cartas.filter((c) => c.valor === "2");
  const comuns = cartas.filter((c) => c.valor !== "2" && c.valor !== "JOKER");
  const naipesComuns = new Set(comuns.map((c) => c.naipe));
  if (naipesComuns.size > 1) {
    return { valido: false, motivo: "Todas as cartas não-coringa devem ser do mesmo naipe" };
  }
  const naipeSeq = comuns.length ? comuns[0].naipe : (dois.length ? dois[0].naipe : null);
  const interpretacoes = [];
  for (let mascara = 0; mascara < (1 << dois.length); mascara++) {
    const comoCuringa = [], comoNatural = [];
    for (let i = 0; i < dois.length; i++) {
      if (mascara & (1 << i)) comoCuringa.push(dois[i]);
      else comoNatural.push(dois[i]);
    }
    if (comoNatural.some((c) => naipeSeq && c.naipe !== naipeSeq)) continue;
    interpretacoes.push({ comoCuringa, comoNatural });
  }
  interpretacoes.sort((a, b) => a.comoCuringa.length - b.comoCuringa.length);
  const idxBaixo = (v) => ORDEM_SEQUENCIA.indexOf(v);
  const idxAlto = (v) => (v === "A" ? ORDEM_SEQUENCIA.length : ORDEM_SEQUENCIA.indexOf(v));
  const encaixa = (naturais, qtdCuringas, mapa, teto) => {
    const valores = naturais.map((c) => c.valor);
    if (new Set(valores).size !== valores.length) return false;
    const indices = naturais.map((c) => mapa(c.valor)).sort((a, b) => a - b);
    const minIdx = indices[0];
    const maxIdx = indices[indices.length - 1];
    const span = maxIdx - minIdx + 1;
    const lacunasInternas = span - naturais.length;
    if (lacunasInternas > qtdCuringas) return false;
    const curingasSobrando = qtdCuringas - lacunasInternas;
    if (curingasSobrando > 0) {
      const cabeNoInicio = minIdx - curingasSobrando >= 0;
      const cabeNoFim = maxIdx + curingasSobrando <= teto;
      if (!cabeNoInicio && !cabeNoFim) return false;
    }
    return true;
  };
  let motivoFalha = "Lacuna na sequência maior que o número de curingas disponíveis";
  for (const interp of interpretacoes) {
    const qtdCuringas = jokers.length + interp.comoCuringa.length;
    if (qtdCuringas > MAX_CURINGAS_SEQUENCIA_NORMAL) {
      motivoFalha = `Máximo de ${MAX_CURINGAS_SEQUENCIA_NORMAL} curinga por sequência`;
      continue;
    }
    const naturais = comuns.concat(interp.comoNatural);
    if (naturais.length === 0) continue;
    let ok = encaixa(naturais, qtdCuringas, idxBaixo, ORDEM_SEQUENCIA.length - 1);
    if (!ok && naturais.some((c) => c.valor === "A")) {
      ok = encaixa(naturais, qtdCuringas, idxAlto, ORDEM_SEQUENCIA.length);
    }
    if (ok) {
      return finalizar({ tipoBase: "sequencia", qtdCuringas, tamanho: cartas.length });
    }
  }
  return { valido: false, motivo: motivoFalha };
}

function validarTrinca(cartas) {
  if (!cartas || cartas.length < MIN_CARTAS_SEQUENCIA) {
    return { valido: false, motivo: `Mínimo de ${MIN_CARTAS_SEQUENCIA} cartas para formar um jogo` };
  }
  if (cartas.some((c) => c.eh_coringa)) {
    return { valido: false, motivo: "curinga (2 ou Joker) não entra em trinca — só cartas naturais iguais" };
  }
  const valores = new Set(cartas.map((c) => c.valor));
  if (valores.size > 1) {
    return { valido: false, motivo: "Numa trinca, todas as cartas devem ser do mesmo valor" };
  }
  return finalizar({ tipoBase: "trinca", qtdCuringas: 0, tamanho: cartas.length });
}

function validarJogo(cartas, opts = {}) {
  const soAses = !!(cartas && cartas.length && cartas.every((c) => c && c.valor === "A" && !c.eh_coringa));
  const rSeq = validarSequencia(cartas);
  if (rSeq.valido && !(soAses && !opts.permiteTrinca)) return rSeq;
  if (opts.permiteTrinca) {
    const rTri = validarTrinca(cartas);
    if (rTri.valido) return rTri;
    return { valido: false, motivo: "não forma uma sequência nem uma trinca válida" };
  }
  if (soAses) return { valido: false, motivo: "no SBTL/Aberto o ás só entra em sequência (trinca de ases é só no Fechado)" };
  return rSeq;
}

function finalizar({ tipoBase, qtdCuringas, tamanho }) {
  let tipo;
  if (tamanho < MIN_CARTAS_CANASTRA) {
    tipo = "aberta";
  } else if (tipoBase === "de_curinga") {
    tipo = "de_curinga";
  } else if (tipoBase === "de_as") {
    tipo = "de_as";
  } else if (tipoBase === "de_500") {
    tipo = "de_500";
  } else if (tipoBase === "as_a_as") {
    tipo = "as_a_as";
  } else {
    tipo = qtdCuringas > 0 ? "suja" : "limpa";
  }
  return { valido: true, tipo, qtd_curingas: qtdCuringas };
}

// ===== jogo (VERBATIM: valorCarta; pontuarDuplaJogo -> pontuarDupla) =====
function valorCarta(c) {
  if (c.valor === "JOKER") return 50;
  if (c.valor === "A") return 15;
  if (["8", "9", "10", "J", "Q", "K", "2"].includes(c.valor)) return 10;
  return 5;
}

// Adaptação pura de pontuarDuplaJogo (l.2158): recebe as melds da dupla e as
// flags, em vez do objeto `jogo`. A LÓGICA é idêntica (bônus só de_500/limpa/
// suja via validarSequencia; batida +100; morto não pego -100; desconto da mão).
function pontuarDupla(melds, { bateu, mortoPego, cartasNaMao, algumPegouMorto }) {
  let pontosCanastras = 0, pontosCartas = 0;
  const detalhe = { de500: 0, asas: 0, limpas: 0, sujas: 0, baixadas: 0 };
  for (const meld of melds) {
    if (meld.length >= 7) {
      const res = validarSequencia(meld);
      if (res.valido) {
        if (res.tipo === "as_a_as") { pontosCanastras += 1000; detalhe.asas++; }
        else if (res.tipo === "de_500") { pontosCanastras += 500; detalhe.de500++; }
        else if (res.tipo === "limpa") { pontosCanastras += 200; detalhe.limpas++; }
        else if (res.tipo === "suja") { pontosCanastras += 100; detalhe.sujas++; }
      }
    }
    for (const c of meld) pontosCartas += valorCarta(c);
  }
  detalhe.baixadas = pontosCartas;
  const bonusBatida = bateu ? 100 : 0;
  const penalidadeMorto = (!mortoPego && algumPegouMorto) ? -100 : 0;
  const descontoMao = -(cartasNaMao || 0);
  const total = pontosCanastras + pontosCartas + bonusBatida + descontoMao + penalidadeMorto;
  return { total, pontosCanastras, pontosCartas, bonusBatida, penalidadeMorto, descontoMao, detalhe };
}

module.exports = {
  buildCard, validarSequencia, validarTrinca, validarJogo, valorCarta, pontuarDupla,
  ORIGEM: { repo: "soniaambrosio/buraco-servidor", commit: "be72bb6", arquivo: "server.js" },
};
