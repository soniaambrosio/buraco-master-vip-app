/**
 * backfillHash.js — recuperar o `purchaseTokenHash` que a migracao gravou `null`.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * `migrarEntitlementsLegado` grava `purchaseTokenHash: null` em todo direito que
 * vem de `usuarios/{uid}`, e o cabecalho dela justifica isso dizendo que
 * `compras/{hash}` guarda o hash e nunca o token, portanto nao ha como
 * reconsultar a Google. A primeira metade e verdade; a conclusao nao cobre o
 * campo que ela apaga:
 *
 *   - RECONSULTAR a Google exige o TOKEN EM CLARO (`interno.purchaseToken`).
 *     Esse de fato nao existe para compra antiga, e continua irrecuperavel.
 *   - `concederFichasMensais` NAO usa o token. Usa o HASH, e so ele, para montar
 *     `fichasConcessoes/{hash}_{indice}`.
 *
 * E o hash existe: `chaveDaCompra` e `sha256(token)` em hex, e o resultado dela
 * E O ID DO DOCUMENTO de `compras/{hash}`. Desde `fe4cdb5` a MESMA transacao que
 * gravava `usuarios/{uid}.vip = true` gravava `compras/{sha256(token)}` com o
 * `uid` do comprador. Nao ha reconstrucao aqui: ha leitura de uma chave que
 * sempre esteve gravada.
 *
 * PREENCHER ESTE CAMPO NAO E INERTE, E E POR ISSO QUE O MODULO E SEPARADO
 *
 * `purchaseTokenHash` alimenta `mesmoToken` em `decidirAtualizacao`, e `mesmoToken`
 * governa titularidade, desfecho terminal e heranca de campo. Um `null` que vira
 * valor MUDA o que o sistema aceita dali em diante. O documento
 * `docs/BACKFILL-PURCHASETOKENHASH.md` faz a analise antes/depois caso a caso; o
 * resumo operacional e:
 *
 *   - hoje, um entitlement SEM hash nao tem protecao de titularidade nenhuma:
 *     `if (!mesmoToken && fonte !== 'validacao') { if (atual.purchaseTokenHash) ... }`
 *     nao dispara quando o campo e nulo, entao QUALQUER evento passa;
 *   - e nao tem protecao de desfecho terminal: `terminalVigente` exige
 *     `mesmoToken`, entao um estorno gravado pode ser ressuscitado por uma
 *     leitura atrasada que ainda diga ACTIVE.
 *
 * Preencher LIGA as duas protecoes. O risco espelhado — o hash certo bloquear um
 * evento legitimo com `token_superado` — e o que a regra AUTO existe para tornar
 * impossivel, e o argumento esta em `atribuiveis` mais abaixo.
 *
 * O QUE ESTE ARQUIVO NAO FAZ
 *
 * Nao inventa hash. Nao escolhe entre candidatos. Nao migra entitlement, nao
 * concede VIP, nao credita ficha, nao consulta a Google e nao decide politica
 * comercial. O unico valor que ele grava e um id de documento que ja existia em
 * `compras/`.
 *
 * ZERO ESCRITA NO DRY-RUN, E ISSO E ESTRUTURAL
 *
 * Mesma disciplina de `diagnosticoPopulacao.js`: o modo nao e um booleano lido em
 * cada ponto de escrita — e a AUSENCIA da porta. Sem `gravarHash` injetado nao
 * existe, dentro deste arquivo, nenhuma expressao capaz de escrever. Um dry-run
 * que compartilha o caminho de escrita com um flag depende de o flag estar certo
 * em toda chamada; este depende de o codigo de escrita nao ter sido passado.
 *
 * E O CLASSIFICADOR E UM SO. `classificarBackfill` responde a pergunta de
 * elegibilidade para os dois modos, e a execucao real re-avalia a mesma regra
 * DENTRO da transacao (ver `backfillHashStore.js`). Duas implementacoes de
 * elegibilidade divergem, e a que divergir vai ser a que ninguem olhou.
 */

'use strict';

const { chaveDaCompra } = require('./entitlementStore');
const { ESTADO: ESTADO_COMPRA } = require('./idempotencia');
const { rotuloToken } = require('./entitlement');
const { varrerPorPagina, TAMANHO_PAGINA, MAX_PAGINAS } = require('./varredura');

/**
 * Formato do valor produzido por `chaveDaCompra`: sha256 em hex minusculo.
 *
 * A conferencia existe porque o hash vira ID DE DOCUMENTO em
 * `fichasConcessoes/{hash}_{indice}`, e um valor fora de formato ali produziria
 * uma chave de livro-razao que nunca mais casa com a que a Play geraria. Um id de
 * `compras/` que nao tenha esta forma nao foi escrito por `chaveDaCompra` e nao e
 * fonte confiavel de coisa nenhuma.
 */
const FORMATO_HASH = /^[0-9a-f]{64}$/;

/** Marca de procedencia gravada junto do hash. Ver `backfillHashStore.js`. */
const ORIGEM_BACKFILL = 'backfill_compras';

/**
 * As classes de elegibilidade. Sao EXCLUSIVAS e cobrem todo o universo varrido:
 * cada uid examinado cai em exatamente uma, e a soma fecha com `examinados`.
 *
 * SOMENTE `AUTO` e candidata a escrita. Todas as outras existem para serem
 * CONTADAS — um backfill que aja sobre duvida e um backfill que corrompe.
 */
const CLASSE = {
  /** Correlacao inequivoca: exatamente um hash historico, sem nada que o desminta. */
  AUTO: 'auto',
  /** Mais de um `compras/` atribuivel a este uid. Escolher seria palpite. */
  AMBIGUO: 'ambiguo',
  /** O que ja esta gravado discorda das fontes historicas. Nunca sobrescrever. */
  CONFLITO: 'conflito',
  /** Nenhum `compras/` correlacionavel. Para este jogador o hash nao existe aqui. */
  SEM_FONTE: 'sem_fonte',
  /** Ja tem hash, e ele confere (ou nada o contradiz). Nao ha o que fazer. */
  JA_PREENCHIDO: 'ja_preenchido',
  /** Nao ha entitlement (ou nao ha documento interno) para receber o campo. */
  FORA_DO_ESCOPO: 'fora_do_escopo',
  /** A correlacao com `compras/` nao foi executada: nao se afirma nem uma coisa nem outra. */
  NAO_INVESTIGADO: 'nao_investigado',
};

/**
 * Por que a classe foi essa. Strings estaveis: elas aparecem no relatorio e sao
 * o que o operador le antes de decidir. Um `motivo` generico transformaria
 * quatorze situacoes distintas em "nao deu".
 */
const MOTIVO = {
  SEM_ENTITLEMENT: 'sem_entitlement',
  SEM_DOCUMENTO_INTERNO: 'sem_documento_interno',
  HASH_ATUAL_CONFERE: 'hash_atual_confere',
  HASH_ATUAL_SEM_FONTE_PARA_CONFERIR: 'hash_atual_sem_fonte_para_conferir',
  HASH_ATUAL_FORA_DE_FORMATO: 'hash_atual_fora_de_formato',
  HASH_ATUAL_NAO_ESTA_EM_COMPRAS: 'hash_atual_nao_esta_em_compras',
  HASH_ATUAL_DISCORDA_DO_TOKEN: 'hash_atual_discorda_do_token',
  CORRELACAO_NAO_EXECUTADA: 'correlacao_nao_executada',
  COMPRA_DE_OUTRO_TITULAR: 'compra_de_outro_titular',
  NENHUMA_COMPRA_ATRIBUIVEL: 'nenhuma_compra_atribuivel',
  UNICA_COMPRA_NAO_CONCEDIDA: 'unica_compra_nao_concedida',
  MULTIPLAS_COMPRAS_ATRIBUIVEIS: 'multiplas_compras_atribuiveis',
  CANDIDATO_DISCORDA_DO_TOKEN: 'candidato_discorda_do_token',
  CORRELACAO_INEQUIVOCA: 'correlacao_inequivoca',
};

/** Por que a varredura parou antes de esgotar. `null` quando ela esgotou. */
const PARADA = {
  TETO_DE_PAGINAS: 'teto_de_paginas',
  TETO_DE_ESCRITAS: 'teto_de_escritas',
};

/** Sentinela interna para interromper a varredura no teto de escritas. */
const PARAR = Symbol('parar-varredura');

function ehHashValido(v) {
  return typeof v === 'string' && FORMATO_HASH.test(v);
}

function textoNaoVazio(v) {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

/**
 * A REGRA DE ELEGIBILIDADE, inteira, pura e sem I/O.
 *
 * Usada pelo dry-run, pela execucao real e — de novo — dentro da transacao de
 * escrita. Uma regra so.
 *
 * A ORDEM DAS PERGUNTAS E DELIBERADA, e cada degrau recusa antes de o proximo
 * poder conceder:
 *
 *   1. ha onde gravar?                     senao FORA_DO_ESCOPO
 *   2. o que ja esta la e valido?          senao CONFLITO (formato)
 *   3. ja tem hash?                        entao JA_PREENCHIDO ou CONFLITO
 *   4. a correlacao rodou?                 senao NAO_INVESTIGADO
 *   5. ha compra de outro titular no lote? entao CONFLITO
 *   6. quantas compras sao atribuiveis?    0 -> SEM_FONTE, >1 -> AMBIGUO
 *   7. a unica compra foi concedida?       senao SEM_FONTE
 *   8. o token em claro desmente?          entao CONFLITO
 *   -> AUTO
 *
 * `atribuiveis` E O CRITERIO QUE FECHA O RISCO DE `token_superado`, e o criterio
 * nao foi escolhido por gosto: ele e EXATAMENTE o de `titularDoToken`
 * (`entitlementStore.js`), que e o portao por onde toda RTDN passa antes de
 * chegar a `decidirAtualizacao` — a notificacao so encontra dono se existir
 * `compras/{hash}` com `uid` e `assinatura: true`.
 *
 * Disso decorre a garantia: se este uid tem UM SO `compras/` atribuivel, entao
 * toda RTDN que consegue alcancar o entitlement dele carrega esse mesmo hash, e
 * portanto `mesmoToken` sera VERDADEIRO depois do backfill. Nenhum evento que
 * hoje e aceito passa a ser recusado por `token_superado`.
 *
 * `estado: 'concedida'` NAO entra em `atribuiveis` de proposito, e entra so na
 * escolha do valor: `titularDoToken` nao olha o estado, entao uma compra parada
 * em `em_validacao` ainda pode trazer uma RTDN. Exclui-la da CONTAGEM faria um
 * uid com duas compras parecer inequivoco e reabriria exatamente o risco que o
 * paragrafo acima fecha. Ela e contada como ambiguidade e recusada como fonte.
 *
 * @param {object} args
 * @param {string} args.uid
 * @param {object|null} args.publico   `playerEntitlements/{uid}`
 * @param {object|null} args.interno   `playerEntitlements/{uid}/interno/billing`
 * @param {Array<{hash: string, dados: object}>|null} [args.compras]
 *        Registros de `compras/` deste uid. `null` significa NAO INVESTIGADO —
 *        distinto de `[]`, que significa investigado e vazio. Sem a distincao um
 *        backfill rodado sem correlacao reportaria "sem fonte" para a base
 *        inteira, que e a conclusao mais cara possivel.
 * @returns {{classe: string, motivo: string, hash: string|null, fatos: object}}
 *          `hash` so e nao-nulo em AUTO. Ele e o valor a gravar, e nada mais.
 */
function classificarBackfill({ uid, publico, interno, compras = null }) {
  const temEntitlement = publico != null;
  const temInterno = interno != null;

  const hashAtualBruto = interno ? interno.purchaseTokenHash : null;
  const hashAtual = ehHashValido(hashAtualBruto) ? hashAtualBruto : null;
  const tokenEmClaro = interno ? textoNaoVazio(interno.purchaseToken) : null;
  // O token em claro, quando existe, e a prova DIRETA de qual e o hash. Ele nunca
  // CRIA um AUTO — a fonte autorizada por esta OS e `compras/` — mas ele
  // DESMENTE: um candidato que nao bata com `sha256(token)` esta errado, e um
  // desmentido vale mais que uma correlacao.
  const hashDoToken = tokenEmClaro ? chaveDaCompra(tokenEmClaro) : null;

  const investigouCompras = compras != null;
  const lote = investigouCompras ? compras : [];

  const outroTitular = lote.some(
    (c) => c && c.dados && c.dados.uid && c.dados.uid !== uid
  );

  // Mesmo criterio de `titularDoToken`. Ver o cabecalho desta funcao.
  const atribuiveis = lote.filter(
    (c) =>
      c &&
      ehHashValido(c.hash) &&
      c.dados &&
      c.dados.uid === uid &&
      c.dados.assinatura === true
  );
  const concedidas = atribuiveis.filter(
    (c) => c.dados.estado === ESTADO_COMPRA.CONCEDIDA
  );

  const fatos = {
    temEntitlement,
    temInterno,
    temHash: Boolean(hashAtual),
    hashForaDeFormato: Boolean(hashAtualBruto) && !hashAtual,
    temToken: Boolean(tokenEmClaro),
    origem: (publico && publico.origem) || null,
    estado: (publico && publico.estado) || null,
    // O hash e NECESSARIO para a ficha mensal e NAO e suficiente, e medir isso e
    // parte da entrega. `concederFichasMensais` tambem exige `planoBase` (senao
    // `planoDoCatalogo` devolve null e o jogador cai em `semPlano`) e `inicioEm`
    // (senao `mesesDecorridos` devolve -1 e nenhum indice vence — em silencio,
    // sem nem contar como `semPlano`). O direito MIGRADO nasce sem os dois. Ver
    // `IMP-33`, e a secao F de `docs/BACKFILL-PURCHASETOKENHASH.md`.
    temPlanoBase: Boolean(publico && publico.planoBase),
    temInicioEm: Boolean(publico && publico.inicioEm),
    investigouCompras,
    comprasAtribuiveis: atribuiveis.length,
    comprasConcedidas: concedidas.length,
  };

  const saida = (classe, motivo, hash = null) => ({
    uid,
    classe,
    motivo,
    hash,
    // O relatorio nunca carrega o hash inteiro: oito caracteres correlacionam
    // duas linhas de log da mesma compra e nao reconstroem nada. Mesma regra de
    // `rotuloToken`, que e de onde ela vem.
    rotuloHash: hash ? rotuloToken(hash) : null,
    fatos,
  });

  // 1. Ha onde gravar?
  if (!temEntitlement) return saida(CLASSE.FORA_DO_ESCOPO, MOTIVO.SEM_ENTITLEMENT);
  if (!temInterno) {
    // A migracao e a validacao escrevem os DOIS documentos sempre; um publico sem
    // interno e anomalia. Criar o interno aqui produziria um documento com um
    // campo so, sem `uid` nem `esquema`, e um backfill nao e lugar de inventar
    // documento. Recusar mantem dry-run e escrita dizendo a MESMA coisa.
    return saida(CLASSE.FORA_DO_ESCOPO, MOTIVO.SEM_DOCUMENTO_INTERNO);
  }

  // 2. O que ja esta gravado tem forma de hash?
  if (fatos.hashForaDeFormato) {
    return saida(CLASSE.CONFLITO, MOTIVO.HASH_ATUAL_FORA_DE_FORMATO);
  }

  // 3. Ja tem hash: nao ha backfill a fazer, mas ha conferencia a fazer.
  if (hashAtual) {
    if (hashDoToken && hashDoToken !== hashAtual) {
      return saida(CLASSE.CONFLITO, MOTIVO.HASH_ATUAL_DISCORDA_DO_TOKEN);
    }
    if (!investigouCompras) {
      return saida(CLASSE.JA_PREENCHIDO, MOTIVO.HASH_ATUAL_SEM_FONTE_PARA_CONFERIR);
    }
    if (atribuiveis.length > 0 && !atribuiveis.some((c) => c.hash === hashAtual)) {
      return saida(CLASSE.CONFLITO, MOTIVO.HASH_ATUAL_NAO_ESTA_EM_COMPRAS);
    }
    return saida(CLASSE.JA_PREENCHIDO, MOTIVO.HASH_ATUAL_CONFERE);
  }

  // 4. Sem correlacao nao se afirma nem que da, nem que nao da.
  if (!investigouCompras) {
    return saida(CLASSE.NAO_INVESTIGADO, MOTIVO.CORRELACAO_NAO_EXECUTADA);
  }

  // 5. Um lote que traz compra de outro titular esta contando outra historia.
  if (outroTitular) return saida(CLASSE.CONFLITO, MOTIVO.COMPRA_DE_OUTRO_TITULAR);

  // 6. Cardinalidade.
  if (atribuiveis.length === 0) {
    return saida(CLASSE.SEM_FONTE, MOTIVO.NENHUMA_COMPRA_ATRIBUIVEL);
  }
  if (atribuiveis.length > 1) {
    // NAO ha desempate aqui, e a ausencia e deliberada. `diagnosticoPopulacao.js`
    // desempata por `concessao.vipExpiraEm` contra o prazo do legado porque ele
    // CONTA quantos hashes sao recuperaveis em principio. Este modulo GRAVA, e as
    // duas perguntas nao merecem o mesmo limiar: um desempate que acerta em 99%
    // dos casos chaveia o livro-razao do 1% na assinatura errada, para sempre.
    return saida(CLASSE.AMBIGUO, MOTIVO.MULTIPLAS_COMPRAS_ATRIBUIVEIS);
  }

  // 7. A unica atribuivel precisa ser uma compra que de fato CONCEDEU o direito.
  if (concedidas.length !== 1) {
    return saida(CLASSE.SEM_FONTE, MOTIVO.UNICA_COMPRA_NAO_CONCEDIDA);
  }

  const candidato = concedidas[0].hash;

  // 8. O desmentido direto, quando ele existe.
  if (hashDoToken && hashDoToken !== candidato) {
    return saida(CLASSE.CONFLITO, MOTIVO.CANDIDATO_DISCORDA_DO_TOKEN);
  }

  return saida(CLASSE.AUTO, MOTIVO.CORRELACAO_INEQUIVOCA, candidato);
}

/** Somatorio vazio, com todas as chaves presentes desde o inicio. */
function resumoZerado() {
  const zeros = (obj) => {
    const saida = {};
    for (const v of Object.values(obj)) saida[v] = 0;
    return saida;
  };
  return {
    examinados: 0,
    porClasse: zeros(CLASSE),
    porMotivo: zeros(MOTIVO),
    /**
     * Jogadores em que a visita ESTOUROU. Nao entram em `porClasse`, porque nao
     * chegaram a ser classificados — contá-los como uma classe faria uma falha de
     * infraestrutura parecer um veredito sobre o jogador.
     */
    comFalha: 0,
    /**
     * Entre os AUTO, quantos ficariam de fato aptos a receber a parcela mensal.
     *
     * Existe porque o hash e necessario e nao suficiente, e um relatorio que so
     * dissesse "N seriam preenchidos" seria lido como "N voltam a receber ficha".
     * Ver os fatos `temPlanoBase` / `temInicioEm` em `classificarBackfill`.
     */
    autoAptoAFicha: 0,
    autoSemPlanoOuInicio: 0,
    escritas: {
      tentadas: 0,
      aplicadas: 0,
      recusadas: 0,
      /** Por que o commit recusou. Preenchido sob demanda: os motivos vem do store. */
      porMotivo: {},
    },
  };
}

/** Soma dois resumos. Uma execucao inteira e a soma das execucoes retomadas. */
function somarResumos(a, b) {
  const soma = resumoZerado();
  soma.examinados = a.examinados + b.examinados;
  soma.comFalha = a.comFalha + b.comFalha;
  soma.autoAptoAFicha = a.autoAptoAFicha + b.autoAptoAFicha;
  soma.autoSemPlanoOuInicio = a.autoSemPlanoOuInicio + b.autoSemPlanoOuInicio;
  for (const grupo of ['porClasse', 'porMotivo']) {
    for (const chave of Object.keys(soma[grupo])) {
      soma[grupo][chave] = a[grupo][chave] + b[grupo][chave];
    }
  }
  for (const campo of ['tentadas', 'aplicadas', 'recusadas']) {
    soma.escritas[campo] = a.escritas[campo] + b.escritas[campo];
  }
  for (const fonte of [a.escritas.porMotivo, b.escritas.porMotivo]) {
    for (const [k, v] of Object.entries(fonte)) {
      soma.escritas.porMotivo[k] = (soma.escritas.porMotivo[k] || 0) + v;
    }
  }
  return soma;
}

/**
 * Cria o backfill sobre portas injetadas.
 *
 * O MODO E DERIVADO DA PORTA, E NAO DE UM FLAG. Sem `gravarHash` este objeto e
 * incapaz de escrever — nao ha, no corpo abaixo, nenhuma outra expressao que
 * toque em banco.
 *
 * @param {object} portas
 * @param {function({cursor: string|null, tamanho: number}): Promise<Array<{uid: string}>>}
 *   portas.paginaDeEntitlements
 *   Ate `tamanho` ids de `playerEntitlements/`, ordenados por id, depois de
 *   `cursor`. Pagina menor que `tamanho` significa FIM.
 * @param {function(string): Promise<{publico: object|null, interno: object|null}>}
 *   portas.lerEntitlement
 * @param {function(string): Promise<Array<{hash: string, dados: object}>>}
 *   [portas.lerComprasDoJogador]
 *   OPCIONAL. Ausente = correlacao nao executada, e o relatorio diz isso em vez
 *   de concluir "sem fonte".
 * @param {function({uid: string, hash: string}): Promise<{aplicado: boolean, motivo: string}>}
 *   [portas.gravarHash]
 *   OPCIONAL, e a sua ausencia E o dry-run. Ver `backfillHashStore.js`.
 * @param {function(): string} [portas.agora]
 * @param {function(string, object): void} [portas.registrarErro] Recebe (mensagem, {uid}).
 */
function criarBackfillHash({
  paginaDeEntitlements,
  lerEntitlement,
  lerComprasDoJogador = null,
  gravarHash = null,
  agora,
  registrarErro = () => {},
}) {
  const relogio = agora || (() => new Date().toISOString());
  const podeEscrever = typeof gravarHash === 'function';

  /**
   * Percorre `playerEntitlements/` inteira, classifica cada uid e — se e somente
   * se a porta de escrita existir — grava os AUTO.
   *
   * @param {object} [args]
   * @param {string|null} [args.cursorInicial]  retomada por id de documento
   * @param {number} [args.tamanhoPagina]
   * @param {number} [args.maxPaginas]   teto DECLARADO — ver `varredura.js`
   * @param {number} [args.maxEscritas]  teto do LOTE PILOTO. Quando morde, a
   *   varredura para e devolve `esgotou: false` com o cursor. Nunca corta em
   *   silencio, e nunca vale no dry-run (que nao escreve).
   * @param {number} [args.amostrasPorClasse]
   */
  async function executar({
    cursorInicial = null,
    tamanhoPagina = TAMANHO_PAGINA,
    maxPaginas = MAX_PAGINAS,
    maxEscritas = Infinity,
    amostrasPorClasse = 5,
  } = {}) {
    const instanteDaVarredura = relogio();
    const resumo = resumoZerado();
    const amostras = {};

    // O ultimo documento CONCLUIDO, e nao o ultimo visitado. `varrerPorPagina`
    // avanca o cursor dele ANTES do trabalho (para que um documento problematico
    // nao prenda a varredura num laco), entao usar aquele cursor numa parada por
    // teto de escritas puliria em silencio o AUTO que nao chegou a ser gravado.
    let ultimoConcluido = cursorInicial;
    let parada = null;

    const visitar = async (uid) => {
      const { publico, interno } = await lerEntitlement(uid);
      const compras = lerComprasDoJogador
        ? (await lerComprasDoJogador(uid)) || []
        : null;

      const c = classificarBackfill({ uid, publico, interno, compras });

      resumo.examinados += 1;
      resumo.porClasse[c.classe] += 1;
      resumo.porMotivo[c.motivo] += 1;

      // A amostra NAO carrega uid nem hash inteiro: `rotuloHash` sao oito
      // caracteres, e nada aqui identifica a pessoa. Um relatorio administrativo
      // circula; uma lista de gente com direito pago nao deveria circular junto.
      const balde = (amostras[c.classe] ||= []);
      if (balde.length < amostrasPorClasse) {
        balde.push({
          classe: c.classe,
          motivo: c.motivo,
          rotuloHash: c.rotuloHash,
          fatos: c.fatos,
        });
      }

      if (c.classe === CLASSE.AUTO) {
        if (c.fatos.temPlanoBase && c.fatos.temInicioEm) resumo.autoAptoAFicha += 1;
        else resumo.autoSemPlanoOuInicio += 1;
      }

      if (c.classe !== CLASSE.AUTO || !podeEscrever) return;

      if (resumo.escritas.aplicadas >= maxEscritas) {
        parada = PARADA.TETO_DE_ESCRITAS;
        throw PARAR;
      }

      resumo.escritas.tentadas += 1;
      const r = await gravarHash({ uid, hash: c.hash });
      if (r && r.aplicado) resumo.escritas.aplicadas += 1;
      else resumo.escritas.recusadas += 1;

      const motivo = (r && r.motivo) || 'sem_motivo';
      resumo.escritas.porMotivo[motivo] =
        (resumo.escritas.porMotivo[motivo] || 0) + 1;
    };

    let resultado;
    try {
      resultado = await varrerPorPagina({
        lerPagina: async ({ cursor, tamanho }) => {
          const docs = await paginaDeEntitlements({ cursor, tamanho });
          return docs.map((d) => ({ id: d.uid, valor: d.uid }));
        },
        aoVisitar: async (_valor, uid) => {
          try {
            await visitar(uid);
          } catch (e) {
            // A parada por teto de escritas NAO e falha: ela e a unica excecao
            // que atravessa este `catch`, e e o que faz o teto ser um corte
            // declarado em vez de um jogador contado como problema.
            if (e === PARAR) throw e;
            // Um jogador problematico nao impede que os seguintes sejam
            // examinados — mesma escolha de `fichasVarredura.js`, e pelo mesmo
            // motivo: o cursor ja avancou, e a execucao seguinte tenta de novo
            // sobre um mecanismo idempotente.
            resumo.comFalha += 1;
            registrarErro(e && e.message ? e.message : String(e), { uid });
          }
          ultimoConcluido = uid;
        },
        tamanhoPagina,
        maxPaginas,
        cursorInicial,
      });
    } catch (e) {
      if (e !== PARAR) throw e;
      resultado = { esgotou: false, cursor: ultimoConcluido };
    }

    if (resultado.esgotou === false && parada == null) {
      parada = PARADA.TETO_DE_PAGINAS;
    }

    return {
      modo: podeEscrever ? 'escrita' : 'dry_run',
      correlacionouCompras: Boolean(lerComprasDoJogador),
      resumo,
      amostras,
      // As leituras que a OS pede pelo nome, derivadas do resumo em vez de
      // contadas a parte: dois contadores para o mesmo fato divergem.
      examinados: resumo.examinados,
      seriamAlterados: resumo.porClasse[CLASSE.AUTO],
      permaneceriamIntocados:
        resumo.examinados - resumo.porClasse[CLASSE.AUTO],
      jaCorretos: resumo.porClasse[CLASSE.JA_PREENCHIDO],
      esgotou: resultado.esgotou !== false,
      cursor: resultado.esgotou !== false ? null : resultado.cursor,
      parada,
      varridoEm: instanteDaVarredura,
    };
  }

  return { executar };
}

/**
 * As portas de LEITURA sobre o Firestore.
 *
 * O CORPO INTEIRO DESTA FUNCAO SO CONTEM `.get()`. Ela mora aqui, e nao solta em
 * `index.js`, pela mesma razao que `criarPortasFirestore` de
 * `diagnosticoPopulacao.js`: fiacao em `index.js` e inalcancavel por
 * `node --test`, e foi assim que o teto de 500 assinantes atravessou uma
 * homologacao inteira. `BFH-40` le este arquivo e falha se qualquer API de
 * escrita aparecer nele.
 *
 * `compras` e consultada so por `where('uid','==',uid)`, com o filtro de
 * `assinatura` e `estado` feito em memoria: duas igualdades exigiriam indice
 * composto declarado, e um backfill nao deve depender de deploy de indice.
 */
function criarPortasDeLeitura({ db, FieldPath }) {
  return {
    paginaDeEntitlements: async ({ cursor, tamanho }) => {
      let q = db
        .collection('playerEntitlements')
        .orderBy(FieldPath.documentId())
        .limit(tamanho);
      if (cursor) q = q.startAfter(cursor);
      const p = await q.get();
      return p.docs.map((d) => ({ uid: d.id }));
    },

    lerEntitlement: async (uid) => {
      const ref = db.collection('playerEntitlements').doc(uid);
      const [pub, int] = await Promise.all([
        ref.get(),
        ref.collection('interno').doc('billing').get(),
      ]);
      return {
        publico: pub.exists ? pub.data() : null,
        interno: int.exists ? int.data() : null,
      };
    },

    lerComprasDoJogador: async (uid) => {
      const p = await db.collection('compras').where('uid', '==', uid).get();
      return p.docs.map((d) => ({ hash: d.id, dados: d.data() }));
    },
  };
}

module.exports = {
  CLASSE,
  MOTIVO,
  PARADA,
  FORMATO_HASH,
  ORIGEM_BACKFILL,
  ehHashValido,
  classificarBackfill,
  resumoZerado,
  somarResumos,
  criarBackfillHash,
  criarPortasDeLeitura,
};
