/**
 * diagnosticoPopulacao.js — o RAIO-X da migracao, antes de migrar.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * `migrarEntitlementsLegado` (index.js) sabe migrar, mas nao sabe RESPONDER se
 * deve. Rodar a migracao para descobrir quantos jogadores ela atinge e o tipo de
 * decisao que nao da para desfazer: a migracao grava, e o que ela grava vira o
 * `atual` que `decidirAtualizacao` protege dali em diante com
 * `legado_nao_sobrescreve`. Um numero errado descoberto depois da escrita custa
 * uma limpeza manual em documento de jogador pagante.
 *
 * Entao esta e a pergunta que faltava ter resposta: QUEM exatamente esta em
 * `usuarios/{uid}` com `vip: true`, o que a migracao faria com cada um, e quantos
 * dos casos terminam com o jogador em situacao pior do que a de hoje.
 *
 * O QUE MUDOU DESDE A PRIMEIRA VERSAO (`diagnosticoLegado.js`, da auditoria de
 * prontidao) — este arquivo E aquele, renomeado, com tres correcoes de alcance:
 *
 *   1. O UNIVERSO DEIXOU DE SER SO `usuarios/`. Contar "quantos ja tem
 *      entitlement sem hash" varrendo apenas o legado responde a pergunta errada:
 *      desde a consolidacao o Billing PAROU de gravar `vip` em `usuarios/`, entao
 *      o assinante comercial novo nao esta no legado e era invisivel. O universo
 *      agora e a UNIAO `usuarios/` + `playerEntitlements/`, com deduplicacao por
 *      uid — ver `FASE` mais abaixo.
 *
 *   2. A VARREDURA DEIXOU DE SER DE UMA PAGINA SO. A versao anterior devolvia
 *      uma pagina e o cursor, e cabia a quem chamava somar. Um diagnostico que
 *      depende de o operador nao parar no meio nao e um diagnostico: e uma
 *      amostra com aparencia de censo. Agora percorre ate esgotar, e quando o
 *      teto de paginas morde ele devolve `esgotou: false` com o cursor —
 *      declarado, nunca silencioso.
 *
 *   3. `purchaseTokenHash` DEIXOU DE SER TRATADO COMO PERDIDO POR DECRETO. Ver
 *      o bloco a seguir, que e o achado central desta OS.
 *
 * O HASH NAO E IRRECUPERAVEL PARA TODO MUNDO — E ISTO PRECISA SER MEDIDO
 *
 * O cabecalho de `migrarEntitlementsLegado` afirma, corretamente, que
 * `compras/{hash}` guarda o HASH e nunca o token, e conclui que nao ha como
 * reconsultar a Google. As duas coisas sao verdade. Mas dai NAO decorre que o
 * `purchaseTokenHash` esteja perdido, e a migracao grava `purchaseTokenHash: null`
 * como se estivesse:
 *
 *   - reconsultar a Google exige o TOKEN EM CLARO (`interno.purchaseToken`), e
 *     esse de fato nao existe para as compras antigas;
 *   - `concederFichasMensais` NAO precisa do token. Ela precisa do HASH, e so
 *     dele, para montar a chave do livro-razao `fichasConcessoes/{hash}_{indice}`.
 *
 * E o hash existe: `chaveDaCompra` e `sha256(token)` em hex, e o resultado dela e
 * o ID DO DOCUMENTO de `compras/{hash}`. Isso vale desde `fe4cdb5`, o commit que
 * criou este codebase — a MESMA transacao que gravava `usuarios/{uid}.vip = true`
 * gravava `compras/{sha256(token)}` com o `uid` do comprador. Quem virou legado
 * por este codebase, portanto, tem o proprio hash guardado, como chave, a uma
 * consulta `where('uid','==',uid)` de distancia.
 *
 * Nao e reconstrucao, nao e aproximacao e nao e palpite: e o mesmo valor que
 * `chaveDaCompra` produziria se o token estivesse a mao. Este modulo NAO grava
 * esse hash em lugar nenhum — ele so CONTA quantos jogadores o tem disponivel,
 * porque essa contagem e a diferenca entre "a ficha mensal do migrado e uma perda
 * inevitavel" e "e uma perda evitavel que ninguem tinha medido".
 *
 * O que continua irrecuperavel, e o modulo separa: quem tem `vip: true` sem
 * NENHUM registro em `compras/` — VIP concedido a mao, importado de outro
 * sistema, ou anterior a este codebase. Para esses nao ha hash em lugar nenhum, e
 * dizer isso com numero e parte da entrega.
 *
 * ZERO ESCRITA, E ISSO E ESTRUTURAL — NAO UMA PROMESSA
 *
 * Nenhuma funcao de classificacao ou de varredura deste arquivo recebe `db`,
 * transacao ou porta capaz de escrever: as dependencias sao leitores. Um `dry-run`
 * que compartilha o caminho de escrita com um `flag` booleano depende de o flag
 * estar certo em toda chamada; este depende de o codigo de escrita nao existir
 * aqui dentro.
 *
 * `criarPortasFirestore` e a UNICA funcao que toca no `db`, mora neste arquivo em
 * vez de virar fiacao solta em `index.js` (que nenhum teste alcanca), e seu corpo
 * inteiro e composto de `.get()`. A garantia e verificavel por `grep`, e
 * `DIAG-31` a verifica lendo o proprio fonte — se alguem colar um `set` aqui, um
 * teste quebra antes da revisao humana.
 *
 * O QUE ESTE ARQUIVO NAO FAZ
 *
 * Nao consulta a Google, nao decide politica, nao migra, nao concede VIP e nao
 * credita ficha. Ele projeta o que a migracao FARIA, usando a mesma regra que ela
 * usa, e conta.
 */

'use strict';

const crypto = require('crypto');

const { ESTADO, instante, anteriorA } = require('./entitlement');
const { varrerPorPagina, TAMANHO_PAGINA, MAX_PAGINAS } = require('./varredura');

/**
 * Categorias da populacao.
 *
 * Sao EXCLUSIVAS e cobrem todo o universo: cada uid examinado cai em exatamente
 * uma, e a soma das contagens fecha com `examinados`. Uma categoria `outros` que
 * absorvesse o que nao encaixa esconderia justamente o caso que ninguem previu —
 * que e o caso que interessa num diagnostico. O que NAO e exclusivo (as
 * sobreposicoes que a OS pede) vive em `INTERSECAO`, contado a parte.
 */
const CATEGORIA = {
  /** `vip` nao e `true` e nao ha entitlement: fora de tudo. */
  FORA_DA_POPULACAO: 'fora_da_populacao',
  /**
   * Sem legado VIP, com entitlement. E o assinante COMERCIAL NORMAL do desenho
   * atual: depois da consolidacao o Billing parou de gravar `vip` em `usuarios/`,
   * entao quem comprou desde entao existe so aqui.
   */
  SO_ENTITLEMENT: 'so_entitlement',
  /** Legado VIP + entitlement vindo da Play (validacao ou RTDN). Migracao nao toca. */
  JA_COBERTO_PELA_PLAY: 'ja_coberto_pela_play',
  /** Legado VIP + entitlement de origem `legado_usuarios`. Migracao ja passou. */
  JA_MIGRADO: 'ja_migrado',
  /** Legado VIP, sem entitlement, prazo no futuro: a migracao concede ate o prazo. */
  MIGRAVEL_VIGENTE: 'migravel_vigente',
  /** Legado VIP, sem entitlement, prazo no passado: a migracao grava expirado. */
  MIGRAVEL_VENCIDO: 'migravel_vencido',
  /** Legado VIP, sem entitlement, sem prazo utilizavel: a migracao PULA. */
  BLOQUEADO_SEM_PRAZO: 'bloqueado_sem_prazo',
  /**
   * Entitlement sem documento em `usuarios/{uid}`. Nao deveria existir — todo
   * jogador tem perfil — e por isso e categoria propria em vez de virar
   * `so_entitlement`: e o unico jeito de a contagem denunciar perfil apagado com
   * direito pago sobrevivendo.
   */
  ENTITLEMENT_ORFAO: 'entitlement_orfao',
  /**
   * Dados contraditorios ou impossiveis de classificar com seguranca. Hoje: `vip`
   * com valor "verdadeiro" que NAO e o booleano `true` (`1`, `'true'`, `'sim'`) e
   * sem entitlement. A migracao filtra por `where('vip','==',true)`, entao ela
   * nunca ve esses documentos — o EFEITO e o mesmo de `fora_da_populacao`, mas
   * afirmar que a pessoa esta fora da populacao seria afirmar algo falso sobre
   * ela. A diferenca entre "nao tem VIP" e "tem VIP gravado de um jeito que o
   * codigo nao le" e a diferenca entre um numero e um incidente.
   */
  INCLASSIFICAVEL: 'inclassificavel',
};

/**
 * Alertas por jogador. Nao sao erros: sao consequencias conhecidas do estado
 * atual ou da migracao que precisam ser contadas para virar decisao de negocio.
 */
const ALERTA = {
  /**
   * O jogador tem (ou teria) direito VIP VIGENTE e mesmo assim nao recebe a
   * parcela mensal, porque nao ha `purchaseTokenHash` para chavear o livro-razao.
   *
   * ESTE E O NUMERO QUE A OS PEDE. Ele conta so quem tem beneficio real a perder
   * — direito vigente hoje, ou vigente depois da migracao. A versao anterior deste
   * modulo emitia o alerta tambem para direito ja vencido, o que inflava a conta
   * com perdas ficticias: quem esta expirado nao receberia ficha nem com hash.
   */
  SEM_FICHA_MENSAL: 'sem_ficha_mensal',
  /**
   * Sem o TOKEN EM CLARO nao ha o que perguntar a Google, entao
   * `reconciliarEntitlementDoJogador` nao alcanca este jogador.
   *
   * A condicao e `interno.purchaseToken`, e nao o hash — sao campos diferentes e
   * so um deles serve de credencial de consulta. A versao anterior conflacionava
   * os dois; a distincao importa porque o hash e recuperavel de `compras/` e o
   * token nao e.
   */
  SEM_RECONSULTA_POSSIVEL: 'sem_reconsulta_possivel',
  /** Prazo vencido no legado pode ser assinatura renovada que o legado nao viu. */
  POSSIVEL_PAGANTE_REBAIXADO: 'possivel_pagante_rebaixado',
  /** A migracao nao grava nada: o jogador fica sem registro de VIP em lugar nenhum. */
  SUMICO_SILENCIOSO: 'sumico_silencioso',
  /** Legado promete prazo MAIOR que o entitlement ja gravado. Merece olho humano. */
  DIVERGENCIA_DE_PRAZO: 'divergencia_de_prazo',
  /**
   * Precisa de hash e ELE EXISTE, como id de um `compras/{hash}` deste uid. A
   * perda da ficha mensal, para este jogador, e evitavel.
   */
  HASH_RECUPERAVEL_DE_COMPRAS: 'hash_recuperavel_de_compras',
  /**
   * Precisa de hash, ha mais de um `compras/` de assinatura e nenhum criterio
   * deterministico escolhe entre eles. Recuperavel em principio, mas nao sem
   * decisao — e escolher errado chavearia o livro-razao na assinatura errada.
   */
  HASH_AMBIGUO: 'hash_ambiguo',
  /**
   * Precisa de hash e NAO ha nenhum `compras/` de assinatura para este uid. Para
   * este jogador o hash e irrecuperavel pelos dados desta arvore.
   */
  HASH_IRRECUPERAVEL: 'hash_irrecuperavel',
  /**
   * Ha evidencia de compra de assinatura em `compras/`, o que torna o jogador um
   * pagante comprovado por este codebase — independentemente do que o legado ou o
   * entitlement digam hoje.
   */
  EVIDENCIA_COMERCIAL: 'evidencia_comercial',
};

/**
 * Defeitos de DADO, nao de politica. Separados de `ALERTA` de proposito: alerta e
 * consequencia esperada de uma regra conhecida; inconsistencia e coisa que nao
 * deveria ser possivel e que nenhuma decisao comercial resolve.
 */
const INCONSISTENCIA = {
  /** `vip` truthy mas nao booleano: invisivel para `where('vip','==',true)`. */
  VIP_NAO_BOOLEANO: 'vip_nao_booleano',
  /** `vipExpiraEm` presente mas nao interpretavel como data. */
  PRAZO_ILEGIVEL: 'prazo_ilegivel',
  /** Entitlement sem `estado`. */
  ENTITLEMENT_SEM_ESTADO: 'entitlement_sem_estado',
  /** Entitlement sem `origem`: nao da para dizer se veio da Play ou da migracao. */
  ENTITLEMENT_SEM_ORIGEM: 'entitlement_sem_origem',
  /** `vipAtivo: true` sem `expiraEm`: acesso sem prazo, que o desenho nao preve. */
  ENTITLEMENT_ATIVO_SEM_PRAZO: 'entitlement_ativo_sem_prazo',
  /**
   * `vipAtivo: true` com `expiraEm` no passado. A varredura de vencimento fecha
   * esses documentos a cada 30 minutos, entao um punhado e normal; um monte
   * significa que ela nao esta rodando.
   */
  ENTITLEMENT_ATIVO_VENCIDO: 'entitlement_ativo_vencido',
  /** `origem: 'legado_usuarios'` COM hash: a migracao grava `null`, sempre. */
  MIGRADO_COM_HASH: 'migrado_com_hash',
  /** Origem da Play SEM hash: a validacao e o RTDN sempre gravam o hash. */
  PLAY_SEM_HASH: 'play_sem_hash',
  /** Mais de um `compras/` de assinatura sem criterio para escolher. */
  MULTIPLOS_HASHES_CANDIDATOS: 'multiplos_hashes_candidatos',
  /** Um `compras/` devolvido para este uid registra outro titular. */
  COMPRA_DE_OUTRO_TITULAR: 'compra_de_outro_titular',
};

/** O que `migrarEntitlementsLegado` faria com este documento. */
const ACAO_DA_MIGRACAO = {
  NADA_FORA_DA_POPULACAO: 'nada_fora_da_populacao',
  NADA_LEGADO_NAO_SOBRESCREVE: 'nada_legado_nao_sobrescreve',
  PULAR_SEM_PRAZO: 'pular_sem_prazo',
  GRAVAR_ATIVO: 'gravar_ativo',
  GRAVAR_EXPIRADO: 'gravar_expirado',
};

/**
 * Sobreposicoes que a OS pede nomeadas.
 *
 * Um cruzamento generico de todas as facetas contra todas produziria dezenas de
 * numeros sem leitor. Estas sao as combinacoes que mudam uma decisao, cada uma
 * contada uma vez por jogador.
 */
const INTERSECAO = {
  /** Tem `usuarios.vip == true` E tem entitlement. */
  LEGADO_E_ENTITLEMENT: 'legado_e_entitlement',
  /** Tem os dois, e o entitlement esta sem hash. */
  LEGADO_E_ENTITLEMENT_SEM_HASH: 'legado_e_entitlement_sem_hash',
  /** Legado VIP com prazo vigente E evidencia de compra em `compras/`. */
  LEGADO_ATIVO_E_EVIDENCIA_COMERCIAL: 'legado_ativo_e_evidencia_comercial',
  /** Seria migrado hoje E o hash esta disponivel: a perda da ficha e evitavel. */
  MIGRAVEL_COM_HASH_RECUPERAVEL: 'migravel_com_hash_recuperavel',
  /** Seria migrado hoje E nao ha hash em lugar nenhum: perda inevitavel. */
  MIGRAVEL_SEM_HASH_RECUPERAVEL: 'migravel_sem_hash_recuperavel',
  /**
   * `bloqueado_sem_prazo` COM evidencia de compra. E o grupo mais delicado: ha
   * prova de que pagou e nao ha prazo para reconstruir o direito.
   */
  SEM_PRAZO_COM_EVIDENCIA_COMERCIAL: 'sem_prazo_com_evidencia_comercial',
  /** Entitlement com acesso vigente HOJE e sem hash: perde ficha agora. */
  ENTITLEMENT_VIGENTE_SEM_HASH: 'entitlement_vigente_sem_hash',
  /** Entitlement com acesso vigente HOJE e sem token: nao pode ser reconsultado. */
  ENTITLEMENT_VIGENTE_SEM_TOKEN: 'entitlement_vigente_sem_token',
  /** Legado diz VIP, entitlement diz que nao ha acesso. Contradicao entre fontes. */
  LEGADO_VIP_E_ENTITLEMENT_SEM_ACESSO: 'legado_vip_e_entitlement_sem_acesso',
};

/** Fases da varredura. O cursor de retomada carrega qual delas estava correndo. */
const FASE = {
  /** `usuarios/` — o legado, e o entitlement de cada um deles. */
  USUARIOS: 'usuarios',
  /**
   * `playerEntitlements/` — para alcancar quem NAO tem documento em `usuarios/`
   * com o mesmo uid. Quem tem ja foi contado na fase anterior e e PULADO aqui;
   * a deduplicacao e uma leitura de documento por uid, e nao um conjunto em
   * memoria, para que o custo nao cresca com a base.
   */
  ENTITLEMENTS: 'entitlements',
};

/** Origem gravada por `migracaoLegado.js`. */
const ORIGEM_LEGADO = 'legado_usuarios';

/**
 * Rotulo anonimo e ESTAVEL de um uid, para os exemplos do relatorio.
 *
 * Doze caracteres do sha256. Nao e reversivel — de proposito: o relatorio circula
 * e nao deve carregar identidade. Mas e DETERMINISTICO, entao um operador que ja
 * suspeita de um uid especifico calcula o rotulo dele e confere se aparece na
 * amostra, sem que o diagnostico precise enumerar ninguem.
 */
function rotuloUid(uid) {
  return crypto.createHash('sha256').update(String(uid)).digest('hex').slice(0, 12);
}

/** O direito descrito por este entitlement da acesso NESTE instante? */
function entitlementVigente(publico, agora) {
  return Boolean(
    publico && publico.vipAtivo === true && anteriorA(agora, publico.expiraEm)
  );
}

/**
 * Classifica UM uid. Pura: sem I/O, sem relogio proprio.
 *
 * A projecao de `acao` espelha, de proposito, a ordem de decisao real —
 * `decidirAtualizacao` recusa `fonte: 'migracao'` sobre qualquer documento ja
 * existente (`legado_nao_sobrescreve`), e so depois disso a migracao olha o
 * prazo. Inverter a ordem aqui faria o diagnostico prometer escrita onde a
 * migracao nao escreve.
 *
 * @param {object} args
 * @param {string} args.uid
 * @param {object|null} args.legado    `usuarios/{uid}`
 * @param {object|null} args.publico   `playerEntitlements/{uid}`
 * @param {object|null} args.interno   `playerEntitlements/{uid}/interno/billing`
 * @param {Array<{hash: string, dados: object}>|null} [args.compras]
 *        Registros de `compras/` deste uid. `null` significa NAO INVESTIGADO —
 *        distinto de `[]`, que significa investigado e vazio. Sem essa distincao
 *        um diagnostico rodado sem a correlacao reportaria "hash irrecuperavel"
 *        para a base inteira, que e a conclusao mais cara possivel.
 * @param {string} args.agora          ISO-8601
 */
function classificarJogador({
  uid,
  legado,
  publico,
  interno,
  compras = null,
  agora,
}) {
  const alertas = [];
  const inconsistencias = [];
  const interseccoes = [];

  const existeLegado = legado != null;
  const dados = legado || {};

  // --- o que o legado diz --------------------------------------------------
  const vipLegado = dados.vip === true;
  const vipTruthyNaoBooleano = !vipLegado && Boolean(dados.vip);
  if (vipTruthyNaoBooleano) inconsistencias.push(INCONSISTENCIA.VIP_NAO_BOOLEANO);

  const prazoPresente = dados.vipExpiraEm != null && dados.vipExpiraEm !== '';
  const expiraEmLegado = instante(dados.vipExpiraEm);
  if (prazoPresente && !expiraEmLegado) {
    inconsistencias.push(INCONSISTENCIA.PRAZO_ILEGIVEL);
  }
  const legadoVigente = Boolean(expiraEmLegado && anteriorA(agora, expiraEmLegado));

  // --- o que o entitlement diz ---------------------------------------------
  const temEntitlement = publico != null;
  const origem = temEntitlement ? publico.origem || null : null;
  const origemLegado = origem === ORIGEM_LEGADO;

  // Hash e token sao campos DIFERENTES e servem a coisas diferentes: o hash
  // chaveia o livro-razao das fichas, o token consulta a Google. Tratar os dois
  // como um so foi o que fez a ficha mensal do migrado parecer irreparavel.
  const temHash = Boolean(interno && interno.purchaseTokenHash);
  const temToken = Boolean(interno && interno.purchaseToken);
  const vigenteAgora = entitlementVigente(publico, agora);

  if (temEntitlement) {
    if (!publico.estado) inconsistencias.push(INCONSISTENCIA.ENTITLEMENT_SEM_ESTADO);
    if (!origem) inconsistencias.push(INCONSISTENCIA.ENTITLEMENT_SEM_ORIGEM);
    if (publico.vipAtivo === true) {
      if (!publico.expiraEm) {
        inconsistencias.push(INCONSISTENCIA.ENTITLEMENT_ATIVO_SEM_PRAZO);
      } else if (!anteriorA(agora, publico.expiraEm)) {
        inconsistencias.push(INCONSISTENCIA.ENTITLEMENT_ATIVO_VENCIDO);
      }
    }
    if (origemLegado && temHash) inconsistencias.push(INCONSISTENCIA.MIGRADO_COM_HASH);
    if (origem && !origemLegado && !temHash) {
      inconsistencias.push(INCONSISTENCIA.PLAY_SEM_HASH);
    }
  }

  // --- evidencia comercial em `compras/` -----------------------------------
  //
  // O id do documento E o `purchaseTokenHash`. Ver o cabecalho: nao ha
  // reconstrucao aqui, ha leitura de uma chave que sempre esteve gravada.
  const investigouCompras = compras != null;
  let candidatos = [];
  let evidenciaComercial = false;

  if (investigouCompras) {
    if (compras.some((c) => c && c.dados && c.dados.uid && c.dados.uid !== uid)) {
      inconsistencias.push(INCONSISTENCIA.COMPRA_DE_OUTRO_TITULAR);
    }
    const assinaturas = compras.filter(
      (c) =>
        c &&
        c.hash &&
        c.dados &&
        c.dados.assinatura === true &&
        (!c.dados.uid || c.dados.uid === uid)
    );
    evidenciaComercial = assinaturas.length > 0;
    candidatos = assinaturas.map((c) => c.hash);

    if (candidatos.length > 1) {
      // Desempate DETERMINISTICO: o prazo que aquela compra concedeu, congelado
      // em `compras/{hash}.concessao.vipExpiraEm`, contra o prazo que o legado
      // carrega hoje. Quando exatamente um casa, a escolha nao e palpite.
      const casam = expiraEmLegado
        ? assinaturas.filter(
            (c) =>
              instante(c.dados.concessao && c.dados.concessao.vipExpiraEm) ===
              expiraEmLegado
          )
        : [];
      if (casam.length === 1) candidatos = [casam[0].hash];
      else inconsistencias.push(INCONSISTENCIA.MULTIPLOS_HASHES_CANDIDATOS);
    }
  }

  if (evidenciaComercial) alertas.push(ALERTA.EVIDENCIA_COMERCIAL);

  // --- categoria e acao ----------------------------------------------------
  let categoria;
  let acao;

  if (!existeLegado) {
    // So chegamos aqui pela fase de entitlements, e so para uid sem perfil.
    categoria = CATEGORIA.ENTITLEMENT_ORFAO;
    acao = ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO;
  } else if (!vipLegado) {
    // A migracao filtra por `where('vip','==',true)` e nao ve nada disto.
    acao = ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO;
    if (temEntitlement) categoria = CATEGORIA.SO_ENTITLEMENT;
    else if (vipTruthyNaoBooleano) categoria = CATEGORIA.INCLASSIFICAVEL;
    else categoria = CATEGORIA.FORA_DA_POPULACAO;
  } else if (temEntitlement) {
    categoria = origemLegado ? CATEGORIA.JA_MIGRADO : CATEGORIA.JA_COBERTO_PELA_PLAY;
    acao = ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE;
  } else if (!expiraEmLegado) {
    // O pior caso, e o mais facil de nao notar: a migracao incrementa `semPrazo`
    // e segue. Nenhum documento nasce, entao o jogador nao aparece nem como
    // expirado — ele simplesmente nao existe para o consumidor.
    categoria = CATEGORIA.BLOQUEADO_SEM_PRAZO;
    acao = ACAO_DA_MIGRACAO.PULAR_SEM_PRAZO;
  } else {
    categoria = legadoVigente
      ? CATEGORIA.MIGRAVEL_VIGENTE
      : CATEGORIA.MIGRAVEL_VENCIDO;
    acao = legadoVigente
      ? ACAO_DA_MIGRACAO.GRAVAR_ATIVO
      : ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO;
  }

  const seriaMigrado =
    acao === ACAO_DA_MIGRACAO.GRAVAR_ATIVO ||
    acao === ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO;

  // --- alertas de consequencia ---------------------------------------------
  if (categoria === CATEGORIA.BLOQUEADO_SEM_PRAZO) {
    alertas.push(ALERTA.SUMICO_SILENCIOSO);
  }
  if (categoria === CATEGORIA.MIGRAVEL_VENCIDO) {
    // Pode ser um ex-assinante (correto) ou um assinante que renovou depois da
    // ultima escrita do legado (incorreto, e invisivel daqui). Os dois casos sao
    // indistinguiveis SEM O TOKEN — e essa indistinguibilidade e exatamente o
    // numero que o operador precisa ver antes de decidir migrar.
    alertas.push(ALERTA.POSSIVEL_PAGANTE_REBAIXADO);
  }

  // Reconsulta depende do TOKEN EM CLARO, que nao existe nem para o migrado nem
  // para quem ainda vai ser migrado.
  const perderaReconsulta = seriaMigrado || (temEntitlement && !temToken);
  if (perderaReconsulta) alertas.push(ALERTA.SEM_RECONSULTA_POSSIVEL);

  // A ficha mensal so e perdida por quem TERIA ficha: direito vigente hoje, ou
  // vigente logo depois da migracao. Contar vencido aqui inflaria a resposta da
  // OS com perda ficticia.
  const teraAcessoVigente =
    acao === ACAO_DA_MIGRACAO.GRAVAR_ATIVO ? true : vigenteAgora;
  const perderaFicha = teraAcessoVigente && !temHash;
  if (perderaFicha) alertas.push(ALERTA.SEM_FICHA_MENSAL);

  if (perderaFicha) {
    if (!investigouCompras) {
      // Sem a correlacao nao se afirma nem que da, nem que nao da. O silencio
      // aqui e o que impede o relatorio de concluir "irrecuperavel" de graca.
    } else if (candidatos.length === 1) {
      alertas.push(ALERTA.HASH_RECUPERAVEL_DE_COMPRAS);
    } else if (candidatos.length > 1) {
      alertas.push(ALERTA.HASH_AMBIGUO);
    } else {
      alertas.push(ALERTA.HASH_IRRECUPERAVEL);
    }
  }

  // O legado diz que o direito vai mais longe do que o entitlement afirma. Nao e
  // a migracao que resolve (ela nao sobrescreve): e caso de reconciliacao manual,
  // e por isso vira alerta e nao categoria.
  if (
    temEntitlement &&
    expiraEmLegado &&
    publico.expiraEm &&
    anteriorA(publico.expiraEm, expiraEmLegado) &&
    anteriorA(agora, expiraEmLegado)
  ) {
    alertas.push(ALERTA.DIVERGENCIA_DE_PRAZO);
  }

  // --- interseccoes --------------------------------------------------------
  if (vipLegado && temEntitlement) {
    interseccoes.push(INTERSECAO.LEGADO_E_ENTITLEMENT);
    if (!temHash) interseccoes.push(INTERSECAO.LEGADO_E_ENTITLEMENT_SEM_HASH);
    if (!vigenteAgora) {
      interseccoes.push(INTERSECAO.LEGADO_VIP_E_ENTITLEMENT_SEM_ACESSO);
    }
  }
  if (vipLegado && legadoVigente && evidenciaComercial) {
    interseccoes.push(INTERSECAO.LEGADO_ATIVO_E_EVIDENCIA_COMERCIAL);
  }
  if (seriaMigrado) {
    if (candidatos.length === 1) {
      interseccoes.push(INTERSECAO.MIGRAVEL_COM_HASH_RECUPERAVEL);
    } else if (investigouCompras && candidatos.length === 0) {
      interseccoes.push(INTERSECAO.MIGRAVEL_SEM_HASH_RECUPERAVEL);
    }
  }
  if (categoria === CATEGORIA.BLOQUEADO_SEM_PRAZO && evidenciaComercial) {
    interseccoes.push(INTERSECAO.SEM_PRAZO_COM_EVIDENCIA_COMERCIAL);
  }
  if (vigenteAgora && !temHash) {
    interseccoes.push(INTERSECAO.ENTITLEMENT_VIGENTE_SEM_HASH);
  }
  if (vigenteAgora && !temToken) {
    interseccoes.push(INTERSECAO.ENTITLEMENT_VIGENTE_SEM_TOKEN);
  }

  return {
    rotulo: rotuloUid(uid),
    categoria,
    acao,
    alertas,
    inconsistencias,
    interseccoes,
    // Fatos booleanos, sem nada que identifique a pessoa. `expiraEm` NAO entra:
    // e um dado por jogador, e o relatorio se resolve com contagem.
    fatos: {
      temLegado: existeLegado,
      vipLegado,
      legadoVigente,
      temEntitlement,
      origemLegado,
      temHash,
      temToken,
      vigenteAgora,
      evidenciaComercial,
      hashesCandidatos: candidatos.length,
    },
    estadoAtual: temEntitlement ? publico.estado || null : null,
    estadoProjetado: seriaMigrado
      ? acao === ACAO_DA_MIGRACAO.GRAVAR_ATIVO
        ? ESTADO.ATIVO
        : ESTADO.EXPIRADO
      : null,
  };
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
    porFase: { [FASE.USUARIOS]: 0, [FASE.ENTITLEMENTS]: 0 },
    porCategoria: zeros(CATEGORIA),
    porAcao: zeros(ACAO_DA_MIGRACAO),
    porAlerta: zeros(ALERTA),
    porInconsistencia: zeros(INCONSISTENCIA),
    porInterseccao: zeros(INTERSECAO),
    /**
     * Quantos uids tiveram `compras/` consultada. Menor que `examinados`
     * significa que a correlacao rodou parcialmente — e um relatorio que nao
     * diga isso passaria "sem evidencia" por "sem compra".
     */
    correlacaoDeCompras: 0,
  };
}

/**
 * Acumula uma classificacao no resumo. Separado de `diagnosticar` para que o
 * teste consiga somar sem montar portas.
 */
function acumular(resumo, classificacao, fase = FASE.USUARIOS) {
  resumo.examinados += 1;
  resumo.porFase[fase] += 1;
  resumo.porCategoria[classificacao.categoria] += 1;
  resumo.porAcao[classificacao.acao] += 1;
  for (const a of classificacao.alertas) resumo.porAlerta[a] += 1;
  for (const i of classificacao.inconsistencias) resumo.porInconsistencia[i] += 1;
  for (const x of classificacao.interseccoes) resumo.porInterseccao[x] += 1;
  return resumo;
}

/**
 * Soma dois resumos.
 *
 * Existe porque uma varredura que devolve `esgotou: false` produz o total em
 * PEDACOS, e somar pedaco a mao em cada chamador seria a chance de o relatorio
 * final divergir da soma das partes. `DIAG-24` prova que uma execucao inteira e
 * a soma das execucoes retomadas.
 */
function somarResumos(a, b) {
  const soma = resumoZerado();
  soma.examinados = a.examinados + b.examinados;
  soma.correlacaoDeCompras = a.correlacaoDeCompras + b.correlacaoDeCompras;
  for (const grupo of [
    'porFase',
    'porCategoria',
    'porAcao',
    'porAlerta',
    'porInconsistencia',
    'porInterseccao',
  ]) {
    for (const chave of Object.keys(soma[grupo])) {
      soma[grupo][chave] = a[grupo][chave] + b[grupo][chave];
    }
  }
  return soma;
}

/**
 * Cria o diagnostico sobre portas de LEITURA.
 *
 * @param {object} portas
 * @param {function({cursor: string|null, tamanho: number}): Promise<Array<{uid: string, dados: object}>>}
 *   portas.paginaDeUsuarios
 *   Ate `tamanho` documentos de `usuarios/`, ordenados por id, depois de
 *   `cursor`. Pagina menor que `tamanho` significa FIM.
 * @param {function({cursor: string|null, tamanho: number}): Promise<Array<{uid: string, dados: object}>>}
 *   portas.paginaDeEntitlements  idem para `playerEntitlements/`.
 * @param {function(string): Promise<object|null>} portas.lerUsuario
 * @param {function(string): Promise<{publico: object|null, interno: object|null}>}
 *   portas.lerEntitlement
 * @param {function(string): Promise<Array<{hash: string, dados: object}>>}
 *   [portas.lerComprasDoJogador]
 *   OPCIONAL. Ausente = correlacao nao executada, e o relatorio diz isso em vez
 *   de concluir "irrecuperavel".
 * @param {function(): string} [portas.agora]
 *
 * NAO existe porta de escrita, e a ausencia e a garantia. Ver o cabecalho.
 */
function criarDiagnosticoPopulacao({
  paginaDeUsuarios,
  paginaDeEntitlements,
  lerUsuario,
  lerEntitlement,
  lerComprasDoJogador = null,
  agora,
}) {
  const relogio = agora || (() => new Date().toISOString());

  /**
   * Percorre o universo inteiro e projeta o efeito da migracao.
   *
   * @param {object} [args]
   * @param {{fase: string, cursor: string|null}|null} [args.cursorInicial]
   *        Retomada. `fase` diz em qual colecao continuar.
   * @param {number} [args.tamanhoPagina]
   * @param {number} [args.maxPaginas]  teto DECLARADO — ver `varredura.js`.
   * @param {number} [args.amostrasPorCategoria]
   *        quantos exemplos ANONIMOS guardar por categoria, para o operador
   *        conferir casos concretos sem despejar a base no retorno.
   */
  async function diagnosticar({
    cursorInicial = null,
    tamanhoPagina = TAMANHO_PAGINA,
    maxPaginas = MAX_PAGINAS,
    amostrasPorCategoria = 5,
  } = {}) {
    const instanteDaVarredura = relogio();
    const resumo = resumoZerado();
    const amostras = {};

    const registrar = async (uid, legado, fase) => {
      const { publico, interno } = await lerEntitlement(uid);
      let compras = null;
      if (lerComprasDoJogador) {
        compras = (await lerComprasDoJogador(uid)) || [];
        resumo.correlacaoDeCompras += 1;
      }

      const classificacao = classificarJogador({
        uid,
        legado,
        publico,
        interno,
        compras,
        agora: instanteDaVarredura,
      });

      acumular(resumo, classificacao, fase);

      const balde = (amostras[classificacao.categoria] ||= []);
      if (balde.length < amostrasPorCategoria) balde.push(classificacao);
    };

    // O teto de paginas e do DIAGNOSTICO INTEIRO, e nao de cada fase: dar
    // `maxPaginas` a cada uma dobraria em silencio o limite que o chamador pediu.
    let orcamento = maxPaginas;
    const faseInicial = cursorInicial ? cursorInicial.fase : FASE.USUARIOS;
    const posicaoInicial = cursorInicial ? cursorInicial.cursor : null;

    if (faseInicial === FASE.USUARIOS) {
      const r = await varrerPorPagina({
        lerPagina: async ({ cursor, tamanho }) => {
          const docs = await paginaDeUsuarios({ cursor, tamanho });
          return docs.map((d) => ({ id: d.uid, valor: d.dados }));
        },
        aoVisitar: (dados, uid) => registrar(uid, dados, FASE.USUARIOS),
        tamanhoPagina,
        maxPaginas: orcamento,
        cursorInicial: posicaoInicial,
      });
      orcamento -= r.paginas;
      if (!r.esgotou) {
        return {
          resumo,
          amostras,
          esgotou: false,
          cursor: { fase: FASE.USUARIOS, cursor: r.cursor },
          varridoEm: instanteDaVarredura,
        };
      }
    }

    const r2 = await varrerPorPagina({
      lerPagina: async ({ cursor, tamanho }) => {
        const docs = await paginaDeEntitlements({ cursor, tamanho });
        return docs.map((d) => ({ id: d.uid, valor: d.dados }));
      },
      aoVisitar: async (_dados, uid) => {
        // Deduplicacao contra a fase anterior. Uma leitura por uid em vez de um
        // conjunto em memoria: o conjunto cresceria com a base, e uma retomada
        // por cursor nem teria como reconstrui-lo.
        const legado = await lerUsuario(uid);
        if (legado != null) return;
        await registrar(uid, null, FASE.ENTITLEMENTS);
      },
      tamanhoPagina,
      maxPaginas: orcamento,
      cursorInicial: faseInicial === FASE.ENTITLEMENTS ? posicaoInicial : null,
    });

    return {
      resumo,
      amostras,
      esgotou: r2.esgotou,
      cursor: r2.esgotou ? null : { fase: FASE.ENTITLEMENTS, cursor: r2.cursor },
      varridoEm: instanteDaVarredura,
    };
  }

  return { diagnosticar };
}

/**
 * As portas de leitura sobre o Firestore.
 *
 * O CORPO INTEIRO DESTA FUNCAO SO CONTEM `.get()`. Ela mora aqui, e nao solta em
 * `index.js`, porque fiacao em `index.js` e inalcancavel por `node --test` —
 * importar aquele arquivo puxa `firebase-functions` — e foi exatamente assim que
 * o teto de 500 assinantes atravessou uma homologacao inteira. `DIAG-31` le este
 * arquivo e falha se qualquer API de escrita aparecer nele.
 *
 * `compras` e consultada so por `where('uid','==',uid)`, com o filtro de
 * `assinatura` feito em memoria: duas igualdades mais `orderBy(__name__)` exigiria
 * indice composto declarado, e um diagnostico nao deve depender de deploy de
 * indice para rodar.
 *
 * @param {object} deps
 * @param {object} deps.db
 * @param {object} deps.FieldPath namespace com `documentId()`
 */
function criarPortasFirestore({ db, FieldPath }) {
  const pagina = (colecao) => async ({ cursor, tamanho }) => {
    let q = db.collection(colecao).orderBy(FieldPath.documentId()).limit(tamanho);
    if (cursor) q = q.startAfter(cursor);
    const p = await q.get();
    return p.docs.map((d) => ({ uid: d.id, dados: d.data() }));
  };

  return {
    paginaDeUsuarios: pagina('usuarios'),
    paginaDeEntitlements: pagina('playerEntitlements'),

    lerUsuario: async (uid) => {
      const d = await db.collection('usuarios').doc(uid).get();
      return d.exists ? d.data() : null;
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
  CATEGORIA,
  ALERTA,
  INCONSISTENCIA,
  ACAO_DA_MIGRACAO,
  INTERSECAO,
  FASE,
  ORIGEM_LEGADO,
  rotuloUid,
  classificarJogador,
  resumoZerado,
  acumular,
  somarResumos,
  criarDiagnosticoPopulacao,
  criarPortasFirestore,
};
