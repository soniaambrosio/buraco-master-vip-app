/**
 * Política pura da indicação. Não conhece Firebase nem relógio global.
 *
 * O código de convite é o `publicId` canônico e imutável que o social já
 * publica. Não nasce aqui um segundo identificador de jogador.
 */

'use strict';

const VALOR_POR_JOGADOR = 500;
const TIPOS_ELEGIVEIS = Object.freeze([
  'publica_casual',
  'publica_ranqueada',
  'torneio',
]);
const LIMITE_DIARIO_ANTES_DE_REVISAO = 10;
const LIMITE_TOTAL_ANTES_DE_REVISAO = 50;
const ALFABETO_ID_PUBLICO = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

const RECUSA = Object.freeze({
  AUTO_INDICACAO: 'auto_indicacao',
  JA_VINCULADA: 'indicacao_ja_vinculada',
  PRIMEIRA_PARTIDA_JA_OCORREU: 'primeira_partida_ja_ocorreu',
  PARTIDA_NAO_FINALIZADA: 'partida_nao_finalizada',
  TIPO_NAO_ELEGIVEL: 'tipo_nao_elegivel',
  PARTIDA_COM_ROBO: 'partida_com_robo',
  PARTICIPANTES_INVALIDOS: 'participantes_invalidos',
});

function avaliarVinculo({ inviteeUid, referrerUid, jaVinculada, jaJogou }) {
  if (inviteeUid === referrerUid) return { aceita: false, recusa: RECUSA.AUTO_INDICACAO };
  if (jaVinculada) return { aceita: false, recusa: RECUSA.JA_VINCULADA };
  if (jaJogou) return { aceita: false, recusa: RECUSA.PRIMEIRA_PARTIDA_JA_OCORREU };
  return { aceita: true, recusa: null };
}

/**
 * Espelho explícito do contrato de identidade pública: tolera caixa, espaços,
 * hífens e as três ambiguidades visuais do alfabeto Crockford. A indicação não
 * cria um ID novo; apenas encontra o documento canônico já reservado.
 */
function normalizarCodigoPublico(bruto) {
  if (typeof bruto !== 'string') return null;
  const candidato = bruto
    .replace(/[\s-]/g, '')
    .toUpperCase()
    .replace(/[IL]/g, '1')
    .replace(/O/g, '0');
  if (candidato.length !== 13 || candidato[0] !== 'P') return null;
  for (const simbolo of candidato.slice(1)) {
    if (!ALFABETO_ID_PUBLICO.includes(simbolo)) return null;
  }
  return candidato;
}

function avaliarPartida(registro) {
  if (!registro || registro.estado !== 'finalizada') {
    return { elegivel: false, recusa: RECUSA.PARTIDA_NAO_FINALIZADA, uids: [] };
  }
  if (!TIPOS_ELEGIVEIS.includes(registro.tipo)) {
    return { elegivel: false, recusa: RECUSA.TIPO_NAO_ELEGIVEL, uids: [] };
  }
  if (registro.temRobo === true) {
    return { elegivel: false, recusa: RECUSA.PARTIDA_COM_ROBO, uids: [] };
  }
  const participantes = Array.isArray(registro.participantes) ? registro.participantes : [];
  const uids = [];
  const vistos = new Set();
  for (const p of participantes) {
    if (!p || p.classe !== 'humano') continue;
    if (typeof p.userId !== 'string' || p.userId.length === 0 || vistos.has(p.userId)) {
      return { elegivel: false, recusa: RECUSA.PARTICIPANTES_INVALIDOS, uids: [] };
    }
    vistos.add(p.userId);
    uids.push(p.userId);
  }
  if (uids.length < 2) {
    return { elegivel: false, recusa: RECUSA.PARTICIPANTES_INVALIDOS, uids: [] };
  }
  uids.sort();
  return { elegivel: true, recusa: null, uids };
}

function deveReterParaRevisao({ concedidasHoje = 0, concedidasTotal = 0 }) {
  return concedidasHoje >= LIMITE_DIARIO_ANTES_DE_REVISAO ||
    concedidasTotal >= LIMITE_TOTAL_ANTES_DE_REVISAO;
}

function chaveLedger(inviteeUid, beneficiarioUid) {
  return `primeira_partida|${inviteeUid}|${beneficiarioUid}`;
}

function chaveDia(agora) {
  return new Date(agora).toISOString().slice(0, 10);
}

module.exports = {
  VALOR_POR_JOGADOR,
  TIPOS_ELEGIVEIS,
  LIMITE_DIARIO_ANTES_DE_REVISAO,
  LIMITE_TOTAL_ANTES_DE_REVISAO,
  RECUSA,
  normalizarCodigoPublico,
  avaliarVinculo,
  avaliarPartida,
  deveReterParaRevisao,
  chaveLedger,
  chaveDia,
};
