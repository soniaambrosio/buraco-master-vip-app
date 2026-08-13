/**
 * economia.js — A ECONOMIA BASICA DO JOGADOR. Logica pura, sem Firestore.
 *
 * O QUE E "ECONOMIA BASICA"
 *
 * Sao os tres movimentos que existem para TODO jogador, independentes de
 * assinatura VIP, de Kit Fundador/Pioneiro, de premio de torneio e de qualquer
 * promocao:
 *
 *   +100  ao entrar, uma vez por conta
 *    +15  por vitoria em partida valida
 *    -10  por derrota em partida valida, com piso absoluto em zero
 *
 * Nenhum desses valores depende de nada que o jogador tenha comprado. Por isso
 * eles vivem AQUI, e nao em `functions-billing/`: um deploy de economia basica
 * nao pode derrubar a validacao de compra, e uma mudanca de catalogo pago nao
 * pode mexer no que o jogador ganha por jogar. E a mesma razao pela qual
 * moderacao, torneios e billing sao codebases separados neste projeto —
 * ver o cabecalho de `firebase.json`.
 *
 * A CARTEIRA E A QUE JA EXISTIA
 *
 * O saldo do jogador mora em `usuarios/{uid}.fichas`, escrito hoje pelo
 * `functions-billing/fichasStore.js`. Este arquivo NAO cria uma segunda
 * carteira: ele credita e debita a MESMA, e o que o distingue e o `motivo`
 * gravado no livro-razao. Um saldo que sai da assinatura e um que sai de uma
 * vitoria sao a mesma ficha no bolso do jogador, e duas linhas diferentes na
 * auditoria.
 *
 * "MOEDAS" E "FICHAS" SAO A MESMA COISA NESTE PROJETO
 *
 * A OS fala em "moedas"; o codigo persistido fala em `fichas`. Elas NAO sao
 * moedas economicamente distintas: `moedas` so aparece em telas de UI com valor
 * fixo no proprio arquivo (`moedas: 1000` em `inicio_screen.dart`,
 * `loja_categoria_screen.dart`, `recompensas_screen.dart`), sem nenhuma escrita,
 * leitura ou campo correspondente no Firestore ou em qualquer Function. O unico
 * saldo que existe de verdade e `usuarios/{uid}.fichas`, e e nele que esta OS
 * mexe. (A `MoedaTipo.gemas` da vitrine e outra unidade, tambem so de tela, e
 * esta OS nao a toca.)
 *
 * O PISO E O QUE TORNA ISTO DIFERENTE DE UM `increment`
 *
 * `FieldValue.increment(-10)` nao sabe parar no zero: um jogador com 6 fichas
 * terminaria com -4. Por isso o debito le o saldo DENTRO da transacao e grava o
 * valor absoluto — ver `economiaStore.js`. A consequencia contabil esta em
 * [aplicarPiso]: o delta EFETIVO de quem tinha 6 e -6, e nao -10, para que a
 * invariante `antes + delta == depois` continue valendo em toda linha do
 * livro-razao. O -10 nominal e gravado ao lado, para a auditoria conseguir
 * distinguir "a politica cobrou 10" de "a carteira so tinha 6".
 */

'use strict';

/**
 * Livro-razao da economia basica. Uma linha por movimento, para sempre.
 *
 * Separado de `fichasConcessoes` (as parcelas da assinatura) e de
 * `rankingLedger` (a pontuacao competitiva) porque sao tres perguntas
 * diferentes: "o que a assinatura pagou", "por que a pontuacao mudou" e "por
 * que o saldo mudou por jogar". Misturar as tres numa colecao so obrigaria toda
 * consulta a filtrar por motivo antes de significar alguma coisa.
 */
const COL_LEDGER = 'economiaLedger';

/** A carteira canonica: `usuarios/{uid}`, campo `fichas`. */
const COL_CARTEIRA = 'usuarios';
const CAMPO_SALDO = 'fichas';
const CAMPO_SALDO_EM = 'fichasAtualizadoEm';

/**
 * Origem contabil de cada movimento (secao 9 da OS).
 *
 * Enum de texto estavel, e nao string solta no ponto de uso, pela mesma razao de
 * `MotivoLancamento` no dominio Dart: um motivo digitado a mao vira dez grafias
 * da mesma coisa e a auditoria deixa de conseguir agrupar.
 */
const MOTIVO = Object.freeze({
  BOAS_VINDAS: 'boas_vindas',
  VITORIA: 'vitoria_partida',
  DERROTA: 'derrota_partida',
});

/**
 * A politica comercial, em um lugar so.
 *
 * Constante, e nao configuracao no Firestore como o catalogo de billing, por uma
 * diferenca real entre as duas coisas: o valor de um produto pago muda com
 * promocao e precisa mudar sem deploy, enquanto estes tres numeros sao a
 * definicao da economia basica do jogo. Mudar um deles e uma decisao de produto
 * que merece revisao de codigo, e nao uma edicao no console.
 */
const POLITICA = Object.freeze({
  boasVindas: 100,
  vitoria: 15,
  derrota: -10,
});

/** Piso absoluto da carteira. O saldo nunca e gravado abaixo disto. */
const PISO = 0;

/**
 * Estados terminais em que a partida CONTOU como disputada.
 *
 * Espelho literal de `EstadoDaPartida.valeu`, em `app/lib/rastreabilidade/
 * registro_partida.dart`: `finalizada` e `abandonada` valeram, `cancelada` nao.
 * `cancelada` e o estado em que `MotivoEncerramento.anulada` desemboca — e por
 * isso "partida anulada nao movimenta carteira" nao precisa de checagem propria:
 * ela ja nao esta neste conjunto.
 *
 * A duplicacao do dominio Dart aqui e a mesma que `rastreabilidade.ts` ja
 * declara em `ehTerminal`, e pela mesma razao: a ponte `dart compile js` deste
 * projeto exporta o dominio de TORNEIOS, e nao o de rastreabilidade.
 */
const ESTADOS_QUE_VALEM = Object.freeze(['finalizada', 'abandonada']);

/**
 * Este TIPO de partida movimenta a carteira?
 *
 * PONTO DE DECISAO COMERCIAL EM ABERTO, e ele esta isolado nesta funcao de
 * proposito. A OS fechou "vitoria valida = +15" e "derrota valida = -10" sem
 * distinguir modalidade, e listou como nao-pagantes apenas as partidas anuladas,
 * canceladas, inconsistentes, nao concluidas, invalidas ou interrompidas sem
 * resultado oficial. `treinamento`, `contra_robos` e `privada` nao estao nessa
 * lista — logo, pela leitura literal da OS, elas pagam, e e isso que esta
 * implementado.
 *
 * O QUE ISSO CUSTA, e quem decidir precisa saber: uma mesa contra robos e uma
 * mesa privada sao os dois caminhos mais baratos de farmar +15 por partida. O
 * dominio ja tem o predicado que separaria isso — `TipoDePartida.alteraRanking`,
 * que vale so para `publica_ranqueada` e `torneio` — mas usa-lo aqui seria
 * inventar uma restricao comercial que a OS nao pediu, e contrariaria o proprio
 * `ledger_competitivo.dart`, que declara que economia e fichas NAO passam pelo
 * criterio de ranking.
 *
 * Quando a decisao existir, ela cabe nesta funcao e em nenhum outro lugar.
 */
function tipoMoveCarteira(_tipo) {
  return true;
}

/**
 * Chave deterministica do bonus de boas-vindas.
 *
 * Vinculada a identidade canonica da conta (o `uid` do Firebase Auth) e ao
 * evento — que e o que a secao 3 da OS exige. Sobrevive a logout, reinstalacao,
 * troca de aparelho e sessao nova porque nenhuma dessas coisas muda o `uid`.
 *
 * O separador `|` acompanha `LancamentoCompetitivo.chaveIdempotencia`
 * (`matchId|userId|motivo`), que ja e a convencao deste projeto para chave de
 * idempotencia composta.
 */
function chaveBoasVindas(uid) {
  return `${MOTIVO.BOAS_VINDAS}|${uid}`;
}

/**
 * Chave deterministica de um movimento de resultado de partida.
 *
 * `partida|{matchId}|{uid}|{motivo}` — a identidade que a secao 5 da OS pede
 * (`partidaId + uid + tipoDoResultado`). O motivo entra na chave pelo mesmo
 * motivo que entra na do ledger competitivo: sem ele, vitoria e derrota da mesma
 * partida colidiriam, e um estorno futuro seria recusado como duplicata do
 * lancamento que ele estorna.
 */
function chaveResultado(matchId, uid, motivo) {
  return `partida|${matchId}|${uid}|${motivo}`;
}

/**
 * O saldo lido da carteira, ou `null` se ele nao for afirmavel.
 *
 * Ausente conta como zero: uma conta que nunca recebeu nada nao tem o campo, e
 * isso e o estado normal de todo jogador novo. Qualquer outra coisa — texto,
 * `NaN`, fracao, negativo — devolve `null`, e quem chama RECUSA o movimento em
 * vez de chutar. Um saldo corrompido tratado como zero apagaria as fichas de um
 * jogador; tratado como duvida, ele so nao se move, e o defeito aparece no log.
 */
function saldoLegivel(valor) {
  if (valor === undefined || valor === null) return 0;
  if (typeof valor !== 'number' || !Number.isInteger(valor) || valor < PISO) {
    return null;
  }
  return valor;
}

/**
 * O delta EFETIVO e o saldo final, respeitando o piso.
 *
 * `saldoFinal = max(0, saldoAtual + delta)`, e o delta devolvido e a diferenca
 * que de fato aconteceu — nao o nominal. E o que mantem `antes + delta == depois`
 * verdadeiro em toda linha do livro-razao, que e a invariante de onde todo saldo
 * reconstruido por auditoria sai.
 *
 *   saldo 100, -10  ->  delta -10, depois  90
 *   saldo  10, -10  ->  delta -10, depois   0
 *   saldo   6, -10  ->  delta  -6, depois   0
 *   saldo   0, -10  ->  delta   0, depois   0
 */
function aplicarPiso(saldoAtual, deltaNominal) {
  const bruto = saldoAtual + deltaNominal;
  const depois = bruto < PISO ? PISO : bruto;
  return { delta: depois - saldoAtual, depois };
}

/**
 * De que lado da mesa esta este assento.
 *
 * Lei de assentos de `Jogo`, copiada de `ParticipantePartida.lado`: pares sao
 * `nos`, impares sao `eles`. Nao e convencao desta camada e por isso nao e
 * parametrizavel.
 */
function ladoDoAssento(assento) {
  if (!Number.isInteger(assento) || assento < 0 || assento > 3) return null;
  return assento % 2 === 0 ? 'nos' : 'eles';
}

/**
 * Por que uma partida nao movimentou carteira nenhuma.
 *
 * Todas benignas menos `registro_incoerente`: as outras descrevem partidas que
 * legitimamente nao pagam, e so essa descreve um documento que nao deveria
 * existir.
 */
const RECUSA = Object.freeze({
  SEM_REGISTRO: 'sem_registro',
  NAO_VALEU: 'partida_nao_valeu',
  SEM_VENCEDOR: 'partida_sem_vencedor',
  TIPO_NAO_PAGA: 'tipo_nao_move_carteira',
  INCOERENTE: 'registro_incoerente',
});

/**
 * OS MOVIMENTOS QUE UMA PARTIDA DEVE, derivados SO do registro server-owned.
 *
 * ESTA FUNCAO E A AUTORIDADE (secao 6 da OS). A entrada e o documento
 * `matches/{matchId}` — escrito exclusivamente por `registrarEncerramentoPartida`
 * e negado ao cliente pelo `firestore.rules` — e nao um payload. Nao existe
 * parametro por onde alguem declare que venceu, nem por onde declare o proprio
 * saldo: quem joga nao aparece nesta assinatura.
 *
 * As guardas, nesta ordem:
 *
 *   1. o registro existe e tem estado terminal que VALEU;
 *   2. existe um lado vencedor declarado (partida anulada nunca tem);
 *   3. o tipo movimenta carteira (ver [tipoMoveCarteira]);
 *   4. cada competidor humano autenticado vira exatamente um movimento.
 *
 * Robo, convidado e espectador ficam de fora sem checagem especial de nome:
 * `classe: 'humano'` e a unica que o dominio permite ter `userId`, e sem conta
 * nao ha carteira onde creditar.
 *
 * @param {object|null|undefined} registro documento `matches/{matchId}`
 * @returns {{movimentos: Array<{uid, motivo, deltaNominal}>, recusa: string|null}}
 */
function movimentosDoResultado(registro) {
  if (!registro || typeof registro !== 'object') {
    return { movimentos: [], recusa: RECUSA.SEM_REGISTRO };
  }

  if (!ESTADOS_QUE_VALEM.includes(registro.estado)) {
    // Cobre de uma vez: anulada (que vira `cancelada`), cancelada, e toda
    // partida que ainda nao chegou a estado terminal — criada, aguardando,
    // ativa, reconectando. Nenhuma delas tem resultado oficial.
    return { movimentos: [], recusa: RECUSA.NAO_VALEU };
  }

  const vencedor = registro.ladoVencedor;
  if (vencedor !== 'nos' && vencedor !== 'eles') {
    // Um estado que valeu sem lado vencedor e incoerente pelo proprio dominio
    // (`DesfechoCanonicoPartida` exige `ladoVencedor` em todo motivo que nao
    // seja `anulada`). Recusar e a leitura conservadora: pagar sem saber quem
    // ganhou seria pior que nao pagar.
    return { movimentos: [], recusa: RECUSA.SEM_VENCEDOR };
  }

  if (!tipoMoveCarteira(registro.tipo)) {
    return { movimentos: [], recusa: RECUSA.TIPO_NAO_PAGA };
  }

  const participantes = registro.participantes;
  if (!Array.isArray(participantes)) {
    return { movimentos: [], recusa: RECUSA.INCOERENTE };
  }

  const movimentos = [];
  const vistos = new Set();
  for (const p of participantes) {
    if (!p || typeof p !== 'object') return { movimentos: [], recusa: RECUSA.INCOERENTE };
    if (p.classe !== 'humano') continue;

    const uid = p.userId;
    if (typeof uid !== 'string' || uid.length === 0) {
      // O dominio garante `userId` em todo humano. Um documento sem ele foi
      // adulterado ou gravado por codigo que nao existe.
      return { movimentos: [], recusa: RECUSA.INCOERENTE };
    }
    if (vistos.has(uid)) {
      // A mesma conta em dois assentos e auto-jogo, e `RegistroDePartida.abrir`
      // ja recusa isso na criacao. Se chegou aqui, o registro nao veio de la.
      return { movimentos: [], recusa: RECUSA.INCOERENTE };
    }
    vistos.add(uid);

    const lado = ladoDoAssento(p.assento);
    if (lado === null) return { movimentos: [], recusa: RECUSA.INCOERENTE };
    if (typeof p.lado === 'string' && p.lado !== lado) {
      // O registro carrega `lado` denormalizado. Recalcular do assento e
      // conferir contra o gravado custa nada e pega o unico jeito de um humano
      // trocar de time depois do fato: editar o campo denormalizado.
      return { movimentos: [], recusa: RECUSA.INCOERENTE };
    }

    const venceu = lado === vencedor;
    movimentos.push({
      uid,
      motivo: venceu ? MOTIVO.VITORIA : MOTIVO.DERROTA,
      deltaNominal: venceu ? POLITICA.vitoria : POLITICA.derrota,
    });
  }

  // Ordem estavel por uid: dois processamentos da mesma partida tocam os
  // documentos na mesma ordem, o que torna a corrida entre eles reproduzivel em
  // teste em vez de depender da ordem dos assentos.
  movimentos.sort((a, b) => (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));
  return { movimentos, recusa: null };
}

module.exports = {
  COL_LEDGER,
  COL_CARTEIRA,
  CAMPO_SALDO,
  CAMPO_SALDO_EM,
  MOTIVO,
  POLITICA,
  PISO,
  ESTADOS_QUE_VALEM,
  RECUSA,
  tipoMoveCarteira,
  chaveBoasVindas,
  chaveResultado,
  saldoLegivel,
  aplicarPiso,
  ladoDoAssento,
  movimentosDoResultado,
};
