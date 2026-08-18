// passe.ts — O PASSE VIP QUINZENAL DE CORTESIA, como DOMINIO PURO.
//
// Uma entrada em partida VIP, disponibilizada a cada 15 dias, valida por 7.
//
// Modulo puro: nao le banco, nao importa firebase-admin e NAO LE O RELOGIO. O
// instante entra sempre por parametro (`agora`), pela mesma disciplina que
// `EntitlementVip.vigenteEm` ja impoe no dominio Dart. Uma funcao de
// elegibilidade que chama `Date.now()` por dentro e impossivel de testar na
// fronteira, e a fronteira e justamente onde o defeito mora.
//
// ===========================================================================
// AS TRES DECISOES QUE SUSTENTAM O RESTO
// ===========================================================================
//
// 1. O PASSE E DOCUMENTO PROPRIO, NAO ENTITLEMENT.
//
//    `playerEntitlements/{uid}` responde "tem VIP agora?" — um estado
//    CONTINUO. O passe e uma ENTRADA UNICA. Modelar um como o outro liberaria
//    Salao VIP, catalogo, cosmeticos, Mesa Privada e elegibilidade de torneio
//    por sete dias inteiros, quando o produto aprovado e uma partida.
//
//    E ha o lado do Billing: aquela colecao e o tradutor da Google, e todo
//    documento dela descreve uma compra real. `reconciliarEntitlements` varre
//    `vipAtivo == true && expiraEm <= agora`; o RTDN reconsulta a Google por
//    `purchaseToken`. Um passe de cortesia nao tem token, e seria reconciliado
//    contra uma compra que nunca existiu.
//
// 2. A CADENCIA E ANCORADA NO RECEBIMENTO, NUNCA NO USO.
//
//    Ancorar em uso ou em expiracao faria o intervalo derivar do
//    comportamento do jogador: quem usasse no setimo dia receberia o proximo
//    cada vez mais tarde. Ancorado no recebimento, o ciclo e fixo. E a mesma
//    escolha que `fichas.js` faz ao contar as parcelas a partir de `inicioEm`.
//
// 3. A CHAVE DE IDEMPOTENCIA E O INDICE DA JANELA, NUNCA A DATA.
//
//    Este e o ponto mais importante do arquivo. `indiceDaJanela` e derivado do
//    CALENDARIO: e o mesmo numero independentemente de quando a rotina rode.
//    Duas execucoes simultaneas na mesma janela produzem o mesmo indice,
//    colidem no mesmo documento e a segunda perde a transacao. Uma chave por
//    timestamp NAO teria essa propriedade — dois instantes distintos gerariam
//    duas concessoes, e o jogador terminaria com dois passes.
//
//    E o precedente exato de `fichasConcessoes/{hash}_{indice}` do Billing.
//
// ===========================================================================
// EXPIRACAO NAO GERA ESCRITA
// ===========================================================================
//
// Um passe vencido nao e apagado por rotina nenhuma. Ele e CONCLUSAO DO
// RELOGIO na leitura, exatamente como `acesso_vip.dart` documenta para a
// assinatura: "expiracao nao gera escrita no Firestore no segundo do
// vencimento". Guardar `utilizavel: true` seria guardar um veredito com prazo,
// e vereditos com prazo apodrecem no banco.
//
// Consequencia direta: NAO HA AGENDADOR nesta OS. A janela e materializada sob
// demanda, quando alguem pergunta pelo passe ou tenta usar um. O passe so
// interessa a quem vai jogar, entao materializar na visita cobre 100% dos
// casos uteis.

// ===========================================================================
// AS CONSTANTES DO PRODUTO
// ===========================================================================

const MS_POR_DIA = 24 * 60 * 60 * 1000;

/// Um passe a cada 15 dias.
export const JANELA_MS = 15 * MS_POR_DIA;

/// Cada passe vale 7 dias a partir do recebimento.
export const VALIDADE_MS = 7 * MS_POR_DIA;

/// Versao do documento gravado. Existe para que uma mudanca de forma seja
/// declarada em vez de deduzida por quem ler o banco depois.
export const ESQUEMA_PASSE = 1;

// ===========================================================================
// A FORMA DO DOCUMENTO
// ===========================================================================

/// `passesVip/{uid}` — o passe CORRENTE, e so ele.
///
/// Um documento por jogador, e nao uma colecao de passes, porque "nao acumula"
/// precisa ser invariante de ESCRITA e nao de leitura. Se a nao-acumulacao
/// ficasse a cargo do leitor ("mostre so o mais recente"), dois passes
/// coexistiriam no banco e qualquer consumidor novo voltaria a poder gastar os
/// dois. Aqui a janela N+1 SOBRESCREVE a janela N no mesmo documento, na mesma
/// transacao: nao ha instante em que existam dois.
export type DocumentoPasse = {
  esquema: number;
  /// Instante em que a PRIMEIRA janela deste jogador comecou. Nunca se move —
  /// nem quando ele usa, nem quando expira, nem quando ele assina.
  ancoraEm: string;
  /// Indice da janela do passe corrente. Derivado do calendario.
  indiceJanela: number;
  /// Quando o passe corrente foi recebido.
  recebidoEm: string;
  /// `recebidoEm + 7 dias`.
  expiraEm: string;
  /// Instante do consumo, ou `null` se ainda nao foi usado.
  usadoEm: string | null;
  /// Identidade da admissao que o consumiu. Prova de que o gasto teve destino.
  usadoNaAdmissao: string | null;
};

/// O que a leitura conclui sobre o passe, contra o relogio de AGORA.
export type EstadoDoPasse = {
  /// Da para entrar numa mesa VIP com este passe neste instante?
  utilizavel: boolean;
  indiceJanela: number;
  recebidoEm: string;
  expiraEm: string;
  usadoEm: string | null;
  /// Quando comeca a proxima janela. E a resposta de "quando vem o proximo".
  proximaElegibilidadeEm: string;
};

// ===========================================================================
// O CALENDARIO
// ===========================================================================

function ms(instante: string): number {
  const t = Date.parse(instante);
  if (!Number.isFinite(t)) throw new TypeError("instante invalido: nao e ISO-8601");
  return t;
}

function iso(epoch: number): string {
  return new Date(epoch).toISOString();
}

/// Em que janela quinzenal cai `agora`, contando de `ancoraEm`.
///
/// Janela 0 e a da propria ancora. Instante anterior a ancora devolve indice
/// negativo, e quem chama trata isso como "ainda nao ha janela" — nao existe
/// caminho aqui que normalize o passado para zero, porque isso esconderia
/// relogio errado em vez de mostrar.
export function indiceDaJanela(ancoraEm: string, agora: string): number {
  return Math.floor((ms(agora) - ms(ancoraEm)) / JANELA_MS);
}

/// Os instantes da janela `indice`.
export function janelaDe(ancoraEm: string, indice: number): {
  recebidoEm: string;
  expiraEm: string;
  proximaElegibilidadeEm: string;
} {
  const inicio = ms(ancoraEm) + indice * JANELA_MS;
  return {
    recebidoEm: iso(inicio),
    expiraEm: iso(inicio + VALIDADE_MS),
    proximaElegibilidadeEm: iso(inicio + JANELA_MS),
  };
}

// ===========================================================================
// A LEITURA
// ===========================================================================

/// O estado do passe contra o relogio, sem escrever nada.
///
/// Tres condicoes, todas necessarias:
///   1. nao foi usado;
///   2. `agora` ja alcancou `recebidoEm`;
///   3. `agora` ainda nao alcancou `expiraEm`.
///
/// A fronteira e ESTRITA no fim (`agora < expiraEm`): no instante exato do
/// vencimento o passe ja nao vale. Mesma disciplina de `vigenteEm`.
export function estadoDoPasse(doc: DocumentoPasse, agora: string): EstadoDoPasse {
  const t = ms(agora);
  const utilizavel =
    doc.usadoEm === null && t >= ms(doc.recebidoEm) && t < ms(doc.expiraEm);
  return {
    utilizavel,
    indiceJanela: doc.indiceJanela,
    recebidoEm: doc.recebidoEm,
    expiraEm: doc.expiraEm,
    usadoEm: doc.usadoEm,
    proximaElegibilidadeEm: janelaDe(doc.ancoraEm, doc.indiceJanela + 1).recebidoEm,
  };
}

// ===========================================================================
// A CONCESSAO
// ===========================================================================

export const CONCESSAO = {
  /// Grava o documento devolvido em `proposta`.
  CONCEDER: "conceder",
  /// Nada a fazer: a janela corrente ja foi concedida.
  NADA: "nada",
  /// Assinante ativo nao recebe cortesia — e a ancora NAO se move.
  ASSINANTE: "assinante",
} as const;

export type Concessao = (typeof CONCESSAO)[keyof typeof CONCESSAO];

export type DecisaoConcessao =
  | { acao: typeof CONCESSAO.CONCEDER; proposta: DocumentoPasse }
  | { acao: typeof CONCESSAO.NADA }
  | { acao: typeof CONCESSAO.ASSINANTE };

/// Decide se ha passe novo a materializar.
///
/// ASSINANTE ATIVO NAO RECEBE, E A ANCORA NAO SE MOVE. As duas metades importam
/// e sao decisoes registradas, nao efeitos colaterais:
///
///   nao receber ....... conceder a quem ja tem VIP criaria estoque invisivel,
///                       que a regra "nao acumula" existe para impedir;
///   nao mover ......... se a ancora avancasse durante a assinatura, quem
///                       cancelasse ficaria com uma carencia artificial de ate
///                       15 dias, criada por ter sido cliente pagante. O
///                       calendario segue correndo por baixo, e o ex-assinante
///                       volta a receber na primeira janela seguinte.
///
/// `assinaturaAtiva` chega DE FORA: quem responde isso e a autoridade do
/// Billing (`playerEntitlements`), e este modulo nao tem — nem deve ter —
/// opiniao propria sobre assinatura.
export function decidirConcessao(entrada: {
  atual: DocumentoPasse | null;
  agora: string;
  assinaturaAtiva: boolean;
}): DecisaoConcessao {
  const { atual, agora, assinaturaAtiva } = entrada;

  if (assinaturaAtiva) return { acao: CONCESSAO.ASSINANTE };

  // Primeira visita: a ancora nasce agora, na janela 0.
  if (atual === null) {
    const j = janelaDe(agora, 0);
    return {
      acao: CONCESSAO.CONCEDER,
      proposta: {
        esquema: ESQUEMA_PASSE,
        ancoraEm: agora,
        indiceJanela: 0,
        recebidoEm: j.recebidoEm,
        expiraEm: j.expiraEm,
        usadoEm: null,
        usadoNaAdmissao: null,
      },
    };
  }

  const indice = indiceDaJanela(atual.ancoraEm, agora);

  // Indice menor ou igual ao corrente: nada mudou (ou o relogio andou para
  // tras, e nesse caso conceder seria conceder duas vezes na mesma janela).
  if (indice <= atual.indiceJanela) return { acao: CONCESSAO.NADA };

  // Janela nova. O passe anterior — usado ou nao — deixa de existir na mesma
  // escrita. E aqui que "nao acumula" vira invariante.
  const j = janelaDe(atual.ancoraEm, indice);
  return {
    acao: CONCESSAO.CONCEDER,
    proposta: {
      esquema: ESQUEMA_PASSE,
      ancoraEm: atual.ancoraEm,
      indiceJanela: indice,
      recebidoEm: j.recebidoEm,
      expiraEm: j.expiraEm,
      usadoEm: null,
      usadoNaAdmissao: null,
    },
  };
}

// ===========================================================================
// O CONSUMO
// ===========================================================================

export const RECUSA_PASSE = {
  INEXISTENTE: "PASSE_INEXISTENTE",
  EXPIRADO: "PASSE_EXPIRADO",
  JA_USADO: "PASSE_JA_USADO",
  AINDA_NAO_VIGENTE: "PASSE_AINDA_NAO_VIGENTE",
} as const;

export type RecusaPasse = (typeof RECUSA_PASSE)[keyof typeof RECUSA_PASSE];

export type DecisaoConsumo =
  | { ok: true; documento: DocumentoPasse }
  | { ok: false; motivo: RecusaPasse };

/// Marca o passe como consumido por uma admissao.
///
/// Funcao PURA: ela devolve o documento que DEVE ser gravado, e nao grava. Quem
/// grava e `firestore.ts`, dentro da MESMA transacao que ocupa o assento — e
/// essa simultaneidade e o coracao da secao 6.3 da OS. Separar as duas coisas
/// (consumir aqui, sentar depois) abriria a janela em que o passe some sem o
/// jogador entrar.
///
/// ABANDONO NAO DEVOLVE O PASSE, e isso e deliberado: se a admissao foi
/// confirmada, o direito foi exercido. Devolver por abandono criaria um passe
/// infinito para quem entrasse e saisse.
export function decidirConsumo(entrada: {
  atual: DocumentoPasse | null;
  agora: string;
  admissaoId: string;
}): DecisaoConsumo {
  const { atual, agora, admissaoId } = entrada;

  if (atual === null) return { ok: false, motivo: RECUSA_PASSE.INEXISTENTE };
  if (atual.usadoEm !== null) return { ok: false, motivo: RECUSA_PASSE.JA_USADO };

  const t = ms(agora);
  if (t < ms(atual.recebidoEm)) {
    return { ok: false, motivo: RECUSA_PASSE.AINDA_NAO_VIGENTE };
  }
  if (t >= ms(atual.expiraEm)) return { ok: false, motivo: RECUSA_PASSE.EXPIRADO };

  return {
    ok: true,
    documento: { ...atual, usadoEm: agora, usadoNaAdmissao: admissaoId },
  };
}
