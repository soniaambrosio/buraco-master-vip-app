/**
 * recuperacaoMetadados.js — o que falta, de onde viria, e quem fica apto.
 *
 * A PERGUNTA QUE ESTE MODULO RESPONDE
 *
 * A OS do `purchaseTokenHash` terminou com um achado que muda o plano: recuperar
 * o hash **nao basta**. `concederFichasMensais` exige TRES coisas do documento, e
 * a migracao do legado grava as tres em branco:
 *
 *   purchaseTokenHash  ausente -> `lerInterno` devolve null -> ramo `semPlano`
 *   planoBase          ausente -> `planoDoCatalogo` devolve null -> ramo `semPlano`
 *   inicioEm           ausente -> `mesesDecorridos` devolve -1 -> NENHUM indice
 *                                 vence, e isso nao aparece em contador nenhum
 *
 * Entao a pergunta desta OS nao e "quantos campos da para preencher", e sim
 * **quantos direitos legados ficam comprovadamente APTOS ao ciclo mensal** depois
 * de uma recuperacao que so use dado historico real. Um campo preenchido que nao
 * destrava a ficha nao vale nada para o jogador, e vale um mal-entendido caro
 * para a operacao.
 *
 * O QUE A INVESTIGACAO HISTORICA ENCONTROU (ver o relatorio, secao "Fontes")
 *
 * `validarCompraPlay` teve cinco geracoes — `767b74a`, `32b6709`, `fe4cdb5`,
 * `f2b06c1`/`4ef296e`, `83a522b` — e em TODAS elas o bloco de concessao de
 * assinatura grava exatamente os mesmos tres campos em `compras/{hash}`:
 *
 *     concessao.vip          = true
 *     concessao.vipExpiraEm  = lineItems[0].expiryTime
 *     concessao.planoBase    = lineItems[0].offerDetails.basePlanId
 *
 * Disso decorrem as duas respostas desta OS, e elas sao assimetricas:
 *
 *   `planoBase` E RECUPERAVEL. O valor esta persistido, e nao e leitura nova: o
 *   proprio caminho de producao de hoje ja le `concessao.planoBase` de
 *   `compras/{hash}` para creditar a parcela de ativacao (`index.js`, o bloco 6.2
 *   de `validarCompraPlay`). Usar a mesma fonte aqui nao inventa semantica
 *   nenhuma — usa a que o codebase ja trata como autoritativa.
 *
 *   `inicioEm` NAO E RECUPERAVEL. Nenhuma geracao jamais persistiu o
 *   `startTime` da assinatura. `startTime` so passou a ser LIDO em `f2b06c1`, ja
 *   dentro de `consolidarAssinatura`, e dali ele vai para `playerEntitlements` —
 *   nunca para `compras/`. Quem virou legado antes disso nao tem, em lugar nenhum
 *   desta arvore, a data em que a assinatura comecou.
 *
 * O QUE ESTE MODULO SE RECUSA A FAZER, E E O PONTO DA OS
 *
 * `compras/{hash}` TEM datas: `criadoEm` e `concedidoEm`, os dois
 * `serverTimestamp()`. Elas sao a hora em que ESTE SISTEMA validou a compra, e
 * nao a hora em que a assinatura comecou na Google. As duas coincidem so quando o
 * jogador validou no instante da compra; divergem em toda reentrega da Play
 * (troca de aparelho, reinstalacao), que e justamente o caso comum de quem tem
 * compra antiga. Usar uma no lugar da outra seria inferencia, e inferencia sobre
 * `inicioEm` nao e um chute inofensivo: `inicioEm` e o marco zero do indice de
 * parcela, entao errar a data erra QUANTAS parcelas o jogador recebe.
 *
 * `vipExpiraEm` menos o ciclo do plano tambem daria uma data. Daria o inicio do
 * ULTIMO periodo cobrado, que nao e o inicio da assinatura — e como o indice 0 e
 * a ATIVACAO, isso pagaria o bonus de ativacao de novo a cada renovacao.
 *
 * Por isso `avaliarInicioEm` devolve `SEM_FONTE` e nao tem ramo de fallback: as
 * fontes candidatas foram examinadas e nenhuma e equivalente. `REC-30` fixa o
 * esquema historico COMPLETO de `compras/` num objeto e prova que, mesmo com
 * todos os campos que ja existiram preenchidos, nenhuma data sai daqui.
 *
 * ZERO ESCRITA, E ISSO E ESTRUTURAL
 *
 * Mesma disciplina de `diagnosticoPopulacao.js` e `backfillHash.js`: nenhuma
 * funcao deste arquivo recebe `db`, transacao ou porta capaz de escrever, e o
 * arquivo nao importa `backfillHashStore.js`. `REC-40` le o proprio fonte e falha
 * se qualquer API de escrita aparecer.
 *
 * E O CLASSIFICADOR DO HASH NAO FOI REIMPLEMENTADO. Este modulo CONSOME
 * `classificarBackfill` de `backfillHash.js`. Duas regras de elegibilidade para o
 * mesmo campo divergiriam, e a que divergisse seria a que ninguem olhou.
 */

'use strict';

const {
  CLASSE: CLASSE_HASH,
  classificarBackfill,
  ehHashValido,
} = require('./backfillHash');
const { ESTADO: ESTADO_COMPRA } = require('./idempotencia');
const { anteriorA } = require('./entitlement');
const { varrerPorPagina, TAMANHO_PAGINA, MAX_PAGINAS } = require('./varredura');

/**
 * O veredito de UM campo. Sao exclusivos: cada campo de cada entitlement recebe
 * exatamente um.
 */
const VEREDITO = {
  /** Ja esta no documento, e nada o contradiz. */
  PRESENTE: 'presente',
  /** Ausente, e recuperavel de fonte historica unica e deterministica. */
  AUTO: 'auto',
  /** Ausente, e ha mais de uma fonte plausivel sem criterio para escolher. */
  AMBIGUO: 'ambiguo',
  /** Ausente, e nao ha fonte historica persistida que sirva. */
  SEM_FONTE: 'sem_fonte',
  /** O valor atual contradiz a fonte historica. NUNCA corrigir automaticamente. */
  INCONSISTENTE: 'inconsistente',
};

/**
 * A classe do entitlement, derivada dos tres vereditos de campo.
 *
 * Exclusivas e cobrindo todo o universo varrido: cada uid cai em exatamente uma,
 * e a soma fecha com `examinados`.
 */
const CLASSE = {
  /** Os tres campos ja existem. Nada a recuperar. */
  JA_CONSISTENTE: 'ja_consistente',
  /** Tudo que falta pode ser recuperado, e o entitlement fica APTO. */
  AUTO_RECUPERAVEL: 'auto_recuperavel',
  /** Parte e recuperavel, mas sobra ausencia que impede a aptidao. */
  AUTO_PARCIAL: 'auto_parcial',
  /** Ha campo com duas ou mais fontes plausiveis. */
  AMBIGUO: 'ambiguo',
  /** Nada do que falta tem fonte. */
  IRRECUPERAVEL: 'irrecuperavel',
  /** Algum valor atual contradiz a fonte historica. */
  INCONSISTENTE: 'inconsistente',
  /** Nao ha entitlement, ou nao ha documento interno. Fora do universo. */
  FORA_DO_ESCOPO: 'fora_do_escopo',
  /** A correlacao com `compras/` nao rodou: nao se conclui nada. */
  NAO_INVESTIGADO: 'nao_investigado',
};

/** Qual campo impede a aptidao, quando ela nao e alcancavel. */
const BLOQUEIO = {
  NENHUM: 'nenhum',
  HASH: 'purchaseTokenHash',
  PLANO: 'planoBase',
  INICIO: 'inicioEm',
  /** Mais de um campo bloqueia. O relatorio conta o conjunto, nao o primeiro. */
  MULTIPLOS: 'multiplos',
  /** O direito nao tem prazo vigente: nao receberia ficha nem completo. */
  SEM_DIREITO_VIGENTE: 'sem_direito_vigente',
};

/**
 * As datas que EXISTEM em `compras/{hash}` e que NAO servem de `inicioEm`.
 *
 * Listadas por nome, e nao esquecidas em silencio, porque a pergunta "por que nao
 * usar `criadoEm`?" vai ser feita de novo por quem ler isto daqui a seis meses. A
 * resposta e a mesma para as duas: sao carimbos do momento em que ESTE SISTEMA
 * validou, e nao do momento em que a assinatura comecou na Google. `REC-31` prova
 * que nenhuma delas vira `inicioEm`.
 */
const DATAS_HISTORICAS_QUE_NAO_SERVEM = Object.freeze([
  'criadoEm',
  'concedidoEm',
  'concessao.vipExpiraEm',
]);

function textoNaoVazio(v) {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

/**
 * As compras ATRIBUIVEIS a este uid.
 *
 * Mesmo criterio de `titularDoToken` (`entitlementStore.js`) e de
 * `classificarBackfill`, e a repeticao e deliberada: se a fonte do `planoBase`
 * fosse mais frouxa que a fonte do hash, uma compra que nao pode dar identidade
 * ao direito poderia dar PLANO a ele — e um plano de outra compra e exatamente a
 * "ampliacao indevida" que a OS manda impedir. Ver `REC-50`.
 */
function comprasAtribuiveis(compras, uid) {
  return compras.filter(
    (c) =>
      c &&
      ehHashValido(c.hash) &&
      c.dados &&
      c.dados.uid === uid &&
      c.dados.assinatura === true
  );
}

/**
 * O `planoBase` historico desta compra, se ela o registrou.
 *
 * A leitura e `concessao.planoBase`, que e onde as cinco geracoes de
 * `validarCompraPlay` gravaram `lineItems[0].offerDetails.basePlanId`. Nao ha
 * traducao, mapa de SKU nem tabela de equivalencia: o valor gravado la e do mesmo
 * vocabulario que `configuracao/billing` usa como chave de plano hoje, porque os
 * dois vem do mesmo `basePlanId` da Play.
 */
function planoDaCompra(dados) {
  return textoNaoVazio(dados && dados.concessao && dados.concessao.planoBase);
}

/**
 * Veredito do `planoBase`.
 *
 * @param {object} args
 * @param {string|null} args.atual   o que esta no entitlement hoje
 * @param {Array} args.atribuiveis   compras ja filtradas por titularidade
 */
function avaliarPlanoBase({ atual, atribuiveis }) {
  // So compra CONCEDIDA prova plano: um registro parado em `em_validacao` nunca
  // chegou a receber resposta da Google, entao o `concessao` dele esta vazio de
  // qualquer forma — e um `recusada` descreve uma compra que nao valeu.
  const concedidas = atribuiveis.filter(
    (c) => c.dados.estado === ESTADO_COMPRA.CONCEDIDA
  );
  const planos = concedidas.map((c) => planoDaCompra(c.dados)).filter(Boolean);
  const distintos = [...new Set(planos)];

  if (atual) {
    // Nunca sobrescrever. Se a fonte discorda, isso e um incidente para olho
    // humano, e nao um conserto automatico.
    if (distintos.length === 1 && distintos[0] !== atual) {
      return { veredito: VEREDITO.INCONSISTENTE, valor: null, motivo: 'plano_atual_discorda_da_fonte' };
    }
    return { veredito: VEREDITO.PRESENTE, valor: atual, motivo: 'plano_ja_no_documento' };
  }

  if (planos.length === 0) {
    return { veredito: VEREDITO.SEM_FONTE, valor: null, motivo: 'nenhuma_compra_registrou_plano' };
  }
  if (distintos.length > 1) {
    // Duas compras concedidas com planos DIFERENTES. Nao ha, no historico, nada
    // que diga qual delas originou o direito de hoje — e escolher a mais recente
    // ou a mais antiga seria exatamente a inferencia proibida.
    return { veredito: VEREDITO.AMBIGUO, valor: null, motivo: 'planos_historicos_divergentes' };
  }
  if (concedidas.length > 1) {
    // Mesmo plano em todas: a ambiguidade de QUAL compra nao afeta o VALOR. O
    // dado recuperado e o mesmo qualquer que seja a compra escolhida, entao nao
    // ha escolha a fazer — e por isso isto NAO e ambiguo.
    return { veredito: VEREDITO.AUTO, valor: distintos[0], motivo: 'plano_unico_em_varias_compras' };
  }
  return { veredito: VEREDITO.AUTO, valor: distintos[0], motivo: 'plano_de_compra_unica' };
}

/**
 * Veredito do `inicioEm`.
 *
 * NAO HA RAMO DE RECUPERACAO, e a ausencia dele e o resultado da investigacao,
 * nao um esquecimento. Ver o cabecalho: nenhuma das cinco geracoes de
 * `validarCompraPlay` persistiu `startTime`, e as duas datas que `compras/` tem
 * (`criadoEm`, `concedidoEm`) sao carimbos de validacao deste sistema, nao do
 * inicio da assinatura na Google.
 *
 * O parametro `compras` entra assim mesmo — sem ser usado para produzir valor —
 * porque e ele que torna a auditoria verificavel: `REC-30` chama esta funcao com
 * o esquema historico COMPLETO preenchido e prova que a saida continua
 * `SEM_FONTE`. Uma funcao que nao recebesse a fonte nao poderia ser acusada de
 * nada, e tambem nao poderia provar nada.
 */
function avaliarInicioEm({ atual, atribuiveis }) {
  if (atual) {
    return { veredito: VEREDITO.PRESENTE, valor: atual, motivo: 'inicio_ja_no_documento' };
  }
  const temAlgumaCompra = atribuiveis.length > 0;
  return {
    veredito: VEREDITO.SEM_FONTE,
    valor: null,
    motivo: temAlgumaCompra
      ? 'compras_existem_mas_nenhuma_registrou_inicio'
      : 'nenhuma_compra_atribuivel',
    /** As datas que existem e foram RECUSADAS, nomeadas. Ver a constante. */
    datasRecusadas: temAlgumaCompra ? [...DATAS_HISTORICAS_QUE_NAO_SERVEM] : [],
  };
}

/**
 * O direito descrito por este entitlement daria acesso NESTE instante?
 *
 * A aptidao a ficha exige isto antes de qualquer campo: `concederFichasMensais`
 * seleciona por `vipAtivo == true` e descarta quem passou do prazo. Contar como
 * "ficaria apto" alguem cujo direito ja venceu inflaria a resposta da OS com
 * aptidao ficticia.
 */
function direitoVigente(publico, agora) {
  return Boolean(
    publico && publico.vipAtivo === true && anteriorA(agora, publico.expiraEm)
  );
}

/**
 * Classifica UM entitlement. Pura: sem I/O, sem relogio proprio.
 *
 * @param {object} args
 * @param {string} args.uid
 * @param {object|null} args.publico   `playerEntitlements/{uid}`
 * @param {object|null} args.interno   `playerEntitlements/{uid}/interno/billing`
 * @param {Array<{hash: string, dados: object}>|null} [args.compras]
 *        `null` significa NAO INVESTIGADO — distinto de `[]`.
 * @param {string} args.agora  ISO-8601
 */
function classificarMetadados({ uid, publico, interno, compras = null, agora }) {
  // O hash NAO e reavaliado aqui: quem responde por ele e o classificador da OS
  // anterior, consumido inteiro.
  const hash = classificarBackfill({ uid, publico, interno, compras });

  if (hash.classe === CLASSE_HASH.FORA_DO_ESCOPO) {
    return {
      uid,
      classe: CLASSE.FORA_DO_ESCOPO,
      motivo: hash.motivo,
      campos: null,
      apto: { antes: false, depois: false },
      bloqueio: BLOQUEIO.SEM_DIREITO_VIGENTE,
      vigente: false,
    };
  }
  if (hash.classe === CLASSE_HASH.NAO_INVESTIGADO) {
    return {
      uid,
      classe: CLASSE.NAO_INVESTIGADO,
      motivo: hash.motivo,
      campos: null,
      apto: { antes: false, depois: false },
      bloqueio: BLOQUEIO.MULTIPLOS,
      vigente: direitoVigente(publico, agora),
    };
  }

  const atribuiveis = comprasAtribuiveis(compras || [], uid);

  // O veredito do hash, traduzido para o mesmo vocabulario dos outros dois.
  const vereditoDoHash = {
    [CLASSE_HASH.JA_PREENCHIDO]: VEREDITO.PRESENTE,
    [CLASSE_HASH.AUTO]: VEREDITO.AUTO,
    [CLASSE_HASH.AMBIGUO]: VEREDITO.AMBIGUO,
    [CLASSE_HASH.SEM_FONTE]: VEREDITO.SEM_FONTE,
    [CLASSE_HASH.CONFLITO]: VEREDITO.INCONSISTENTE,
  }[hash.classe];

  const campos = {
    purchaseTokenHash: {
      veredito: vereditoDoHash,
      valor: hash.hash,
      motivo: hash.motivo,
    },
    planoBase: avaliarPlanoBase({
      atual: textoNaoVazio(publico && publico.planoBase),
      atribuiveis,
    }),
    inicioEm: avaliarInicioEm({
      atual: textoNaoVazio(publico && publico.inicioEm),
      atribuiveis,
    }),
  };

  const vereditos = Object.values(campos).map((c) => c.veredito);
  const vigente = direitoVigente(publico, agora);

  // --- aptidao, antes e depois -------------------------------------------
  //
  // "Apto" e a conjuncao: os TRES campos presentes E direito vigente. Nao ha
  // aptidao parcial — faltando um, `concederFichasMensais` nao paga nada.
  const presenteAgora = (c) => c.veredito === VEREDITO.PRESENTE;
  const disponivelDepois = (c) =>
    c.veredito === VEREDITO.PRESENTE || c.veredito === VEREDITO.AUTO;

  const aptoAntes = vigente && Object.values(campos).every(presenteAgora);
  const aptoDepois = vigente && Object.values(campos).every(disponivelDepois);

  // --- o que bloqueia ------------------------------------------------------
  const faltantes = Object.entries(campos)
    .filter(([, c]) => !disponivelDepois(c))
    .map(([nome]) => nome);

  let bloqueio;
  if (!vigente) bloqueio = BLOQUEIO.SEM_DIREITO_VIGENTE;
  else if (faltantes.length === 0) bloqueio = BLOQUEIO.NENHUM;
  else if (faltantes.length > 1) bloqueio = BLOQUEIO.MULTIPLOS;
  else bloqueio = faltantes[0];

  // --- classe --------------------------------------------------------------
  //
  // A ordem e de recusa: contradicao vence ambiguidade, que vence ausencia. Um
  // entitlement com um campo inconsistente NAO e "parcialmente recuperavel", por
  // mais que os outros dois estejam prontos — a contradicao e o fato que precisa
  // chegar ao operador.
  let classe;
  if (vereditos.includes(VEREDITO.INCONSISTENTE)) classe = CLASSE.INCONSISTENTE;
  else if (vereditos.includes(VEREDITO.AMBIGUO)) classe = CLASSE.AMBIGUO;
  else if (vereditos.every((v) => v === VEREDITO.PRESENTE)) classe = CLASSE.JA_CONSISTENTE;
  else if (vereditos.every(
    (v) => v === VEREDITO.PRESENTE || v === VEREDITO.AUTO
  )) classe = CLASSE.AUTO_RECUPERAVEL;
  else if (vereditos.includes(VEREDITO.AUTO)) classe = CLASSE.AUTO_PARCIAL;
  else classe = CLASSE.IRRECUPERAVEL;

  return {
    uid,
    classe,
    motivo: null,
    campos,
    vigente,
    apto: { antes: aptoAntes, depois: aptoDepois },
    bloqueio,
    faltantes,
    origem: (publico && publico.origem) || null,
  };
}

/** Somatorio vazio, com todas as chaves presentes desde o inicio. */
function resumoZerado() {
  const zeros = (obj) => {
    const saida = {};
    for (const v of Object.values(obj)) saida[v] = 0;
    return saida;
  };
  const porCampo = () => ({
    purchaseTokenHash: zeros(VEREDITO),
    planoBase: zeros(VEREDITO),
    inicioEm: zeros(VEREDITO),
  });
  return {
    examinados: 0,
    comFalha: 0,
    porClasse: zeros(CLASSE),
    porCampo: porCampo(),
    porBloqueio: zeros(BLOQUEIO),
    /** A METRICA PRINCIPAL DA OS. Ver o cabecalho e a secao 10 da ordem. */
    aptidao: {
      vigentes: 0,
      aptosAntes: 0,
      aptosDepois: 0,
      /** `aptosDepois - aptosAntes`. Quem a recuperacao de fato destrava. */
      ganho: 0,
    },
  };
}

function acumular(resumo, c) {
  resumo.examinados += 1;
  resumo.porClasse[c.classe] += 1;
  resumo.porBloqueio[c.bloqueio] += 1;
  if (c.campos) {
    for (const [nome, campo] of Object.entries(c.campos)) {
      resumo.porCampo[nome][campo.veredito] += 1;
    }
  }
  if (c.vigente) resumo.aptidao.vigentes += 1;
  if (c.apto.antes) resumo.aptidao.aptosAntes += 1;
  if (c.apto.depois) resumo.aptidao.aptosDepois += 1;
  resumo.aptidao.ganho = resumo.aptidao.aptosDepois - resumo.aptidao.aptosAntes;
  return resumo;
}

/** Soma dois resumos. Uma execucao inteira e a soma das execucoes retomadas. */
function somarResumos(a, b) {
  const soma = resumoZerado();
  soma.examinados = a.examinados + b.examinados;
  soma.comFalha = a.comFalha + b.comFalha;
  for (const chave of Object.keys(soma.porClasse)) {
    soma.porClasse[chave] = a.porClasse[chave] + b.porClasse[chave];
  }
  for (const chave of Object.keys(soma.porBloqueio)) {
    soma.porBloqueio[chave] = a.porBloqueio[chave] + b.porBloqueio[chave];
  }
  for (const campo of Object.keys(soma.porCampo)) {
    for (const chave of Object.keys(soma.porCampo[campo])) {
      soma.porCampo[campo][chave] =
        a.porCampo[campo][chave] + b.porCampo[campo][chave];
    }
  }
  for (const chave of ['vigentes', 'aptosAntes', 'aptosDepois']) {
    soma.aptidao[chave] = a.aptidao[chave] + b.aptidao[chave];
  }
  soma.aptidao.ganho = soma.aptidao.aptosDepois - soma.aptidao.aptosAntes;
  return soma;
}

/**
 * Cria o diagnostico sobre portas de LEITURA.
 *
 * NAO existe porta de escrita, e a ausencia e a garantia — nao ha, neste arquivo,
 * nenhuma expressao capaz de escrever, e `REC-40` verifica isso pelo fonte. As
 * portas sao as mesmas de `backfillHash.criarPortasDeLeitura`, reusadas em vez de
 * reescritas.
 *
 * @param {object} portas
 * @param {function({cursor: string|null, tamanho: number}): Promise<Array<{uid: string}>>}
 *   portas.paginaDeEntitlements
 * @param {function(string): Promise<{publico: object|null, interno: object|null}>}
 *   portas.lerEntitlement
 * @param {function(string): Promise<Array<{hash: string, dados: object}>>}
 *   [portas.lerComprasDoJogador]  ausente = correlacao nao executada
 * @param {function(): string} [portas.agora]
 * @param {function(string, object): void} [portas.registrarErro]
 */
function criarDiagnosticoMetadados({
  paginaDeEntitlements,
  lerEntitlement,
  lerComprasDoJogador = null,
  agora,
  registrarErro = () => {},
}) {
  const relogio = agora || (() => new Date().toISOString());

  async function diagnosticar({
    cursorInicial = null,
    tamanhoPagina = TAMANHO_PAGINA,
    maxPaginas = MAX_PAGINAS,
    amostrasPorClasse = 5,
  } = {}) {
    const instanteDaVarredura = relogio();
    const resumo = resumoZerado();
    const amostras = {};

    const resultado = await varrerPorPagina({
      lerPagina: async ({ cursor, tamanho }) => {
        const docs = await paginaDeEntitlements({ cursor, tamanho });
        return docs.map((d) => ({ id: d.uid, valor: d.uid }));
      },
      aoVisitar: async (_valor, uid) => {
        try {
          const { publico, interno } = await lerEntitlement(uid);
          const compras = lerComprasDoJogador
            ? (await lerComprasDoJogador(uid)) || []
            : null;

          const c = classificarMetadados({
            uid,
            publico,
            interno,
            compras,
            agora: instanteDaVarredura,
          });
          acumular(resumo, c);

          // A amostra nao carrega uid nem valor recuperado: so o veredito por
          // campo e o que bloqueia. Um relatorio administrativo circula, e uma
          // lista de gente com direito pago nao deveria circular junto.
          const balde = (amostras[c.classe] ||= []);
          if (balde.length < amostrasPorClasse) {
            balde.push({
              classe: c.classe,
              origem: c.origem,
              vigente: c.vigente,
              bloqueio: c.bloqueio,
              apto: c.apto,
              vereditos: c.campos
                ? {
                    purchaseTokenHash: c.campos.purchaseTokenHash.veredito,
                    planoBase: c.campos.planoBase.veredito,
                    inicioEm: c.campos.inicioEm.veredito,
                  }
                : null,
            });
          }
        } catch (e) {
          // Um jogador problematico nao impede que os seguintes sejam
          // examinados — mesma escolha de `fichasVarredura.js`.
          resumo.comFalha += 1;
          registrarErro(e && e.message ? e.message : String(e), { uid });
        }
      },
      tamanhoPagina,
      maxPaginas,
      cursorInicial,
    });

    return {
      correlacionouCompras: Boolean(lerComprasDoJogador),
      resumo,
      amostras,
      examinados: resumo.examinados,
      esgotou: resultado.esgotou,
      cursor: resultado.esgotou ? null : resultado.cursor,
      varridoEm: instanteDaVarredura,
    };
  }

  return { diagnosticar };
}

module.exports = {
  VEREDITO,
  CLASSE,
  BLOQUEIO,
  DATAS_HISTORICAS_QUE_NAO_SERVEM,
  comprasAtribuiveis,
  planoDaCompra,
  avaliarPlanoBase,
  avaliarInicioEm,
  direitoVigente,
  classificarMetadados,
  resumoZerado,
  acumular,
  somarResumos,
  criarDiagnosticoMetadados,
};
