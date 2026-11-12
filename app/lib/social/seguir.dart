// seguir.dart — o domínio de SEGUIR (SOCIAL-02, fundação C1).
//
// Contrato: pacote BMV_SOCIAL_02_PACOTE_APROVADO_V1 — registro de decisões
// finais (Q1–Q4), adendo A1–A3 (ordem de avaliação, espelhos P1–P4, ciclo da
// conta) e CONTRATO_SOCIAL_02_V2.
//
// QUEM DECIDE É ESTE ARQUIVO. O TypeScript lê os documentos dentro da
// transação, entrega os fatos crus e grava o que o veredito mandar. Nenhum `if`
// de política de seguir mora no TypeScript.
//
// O QUE ESTA FUNDAÇÃO NÃO FAZ: não lê banco, não conhece relógio (o instante vem
// de fora), não gera identificadores aleatórios e não cria nenhuma operação
// pública. As callables chegam nas etapas seguintes.

import '../elegibilidade/entitlement.dart';
import '../moderacao/corte_relacao.dart';

// ===========================================================================
// LIMITES APROVADOS (Q4) — janelas MÓVEIS, teto RÍGIDO
// ===========================================================================

/// Até 30 novas criações em QUALQUER intervalo de 10 minutos, por ator.
const Duration kJanelaRitmoCurta = Duration(minutes: 10);
const int kMaximoCriacoesJanelaCurta = 30;

/// Até 300 novas criações em QUALQUER intervalo de 24 horas, por ator.
const Duration kJanelaRitmoLonga = Duration(hours: 24);
const int kMaximoCriacoesJanelaLonga = 300;

/// Até 3 novas criações para o MESMO alvo nas últimas 24 horas.
const Duration kJanelaRitmoPorAlvo = Duration(hours: 24);
const int kMaximoCriacoesPorAlvo = 3;

/// Até 100 pedidos ENVIADOS PENDENTES por ator. Teto RÍGIDO: o contador técnico
/// é lido e gravado na mesma transação da criação.
const int kTetoPedidosPendentesEnviados = 100;

/// Versão do formato dos documentos de seguir.
const int kEsquemaSeguir = 1;

/// Mesmo critério do `intentId` da Moderação (`exigirIdSeguro`).
final RegExp _formatoIntencao = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Partes de token: opacas, geradas pelo servidor em base64url.
final RegExp _formatoParteDeToken = RegExp(r'^[A-Za-z0-9_-]*$');

const String _separadorDeToken = '.';

// ===========================================================================
// VOCABULÁRIO
// ===========================================================================

/// Estado FÍSICO do canônico de uma direção (seguidor → seguido).
///
/// `nenhum` é o canônico ausente. `encerrado` é a lápide que guarda a última
/// referência e o histórico de ritmo do par.
enum EstadoSeguir {
  nenhum,
  pendente,
  confirmado,
  encerrado;

  bool get ativo =>
      this == EstadoSeguir.pendente || this == EstadoSeguir.confirmado;

  /// `null` para nome desconhecido: documento corrompido não vira estado.
  static EstadoSeguir? porNome(Object? nome) {
    for (final e in EstadoSeguir.values) {
      if (e.name == nome) return e;
    }
    return null;
  }
}

/// Regime de privacidade do perfil, para decidir entre seguir e pedir.
enum PrivacidadeSocial {
  publico,
  privado;

  /// Q1: público enquanto o jogador nunca escolheu (campo ausente). Um valor
  /// presente e desconhecido é lido como PRIVADO: na dúvida, não se abre o que
  /// o jogador pode ter fechado (D01: a escolha privada é preservada).
  static PrivacidadeSocial porNome(Object? nome) {
    if (nome == null || nome == 'publico') return PrivacidadeSocial.publico;
    return PrivacidadeSocial.privado;
  }
}

/// As mutações sobre uma direção. O01/O02 são uma operação só: o servidor
/// escolhe entre vínculo imediato e pedido pela privacidade lida na transação.
enum OperacaoSeguir {
  seguir,
  cancelarPedido,
  aprovarPedido,
  recusarPedido,
  deixarDeSeguir,
  removerSeguidor;

  /// Operações que CRIAM ou CONFIRMAM vínculo. Exigem as duas pontas VIP.
  bool get criacao =>
      this == OperacaoSeguir.seguir || this == OperacaoSeguir.aprovarPedido;

  /// A direção afetada sai do ator (ator → alvo)? As demais entram no ator
  /// (alvo → ator).
  bool get naSaida =>
      this == OperacaoSeguir.seguir ||
      this == OperacaoSeguir.cancelarPedido ||
      this == OperacaoSeguir.deixarDeSeguir;

  static OperacaoSeguir? porNome(Object? nome) {
    for (final o in OperacaoSeguir.values) {
      if (o.name == nome) return o;
    }
    return null;
  }
}

/// Recusas de seguir. Tudo o que vem do lado do alvo cai em [acaoIndisponivel],
/// sem motivo (D07).
enum RecusaSeguir {
  /// Alvo inexistente, removido ou em exclusão: igual a inexistente.
  perfilPublicoNaoDisponivel,

  /// O plano do PRÓPRIO ator não dá gestão social (Q2, linha de base).
  requerVip,

  /// Impedimento do alvo, do contato ou do ciclo de conta do ator.
  acaoIndisponivel,

  acaoSobreSiMesmo,

  /// O token visto é de outra geração ou de outro estado. O cliente relê.
  referenciaObsoleta,

  /// Forma inválida, ou a última intenção reaproveitada em outro comando.
  pedidoInvalido,

  ritmoExcedido,
  limitePedidosPendentes,

  /// O contador técnico de pendentes está desconhecido: falha fechada.
  limiteIndisponivel,
}

/// Os quatro espelhos possíveis de UMA direção A → B (adendo A1).
enum EspelhoSeguir {
  /// P1 — `users/A/seguindo/B`.
  seguindoDoSeguidor,

  /// P2 — `users/B/seguidores/A`.
  seguidoresDoSeguido,

  /// P3 — `users/A/pedidosSeguirEnviados/B`.
  pedidoEnviadoDoSeguidor,

  /// P4 — `users/B/pedidosSeguirRecebidos/A`.
  pedidoRecebidoDoSeguido,
}

/// Ações de seguir que a visita pode oferecer (D07, opção B).
enum AcaoSeguir {
  seguir,
  solicitarSeguir,
  cancelarPedidoSeguir,
  deixarDeSeguir,
  aprovarPedidoSeguir,
  recusarPedidoSeguir,
  removerSeguidor,
}

// ===========================================================================
// VIGÊNCIA VIP — a definição ÚNICA, reutilizada
// ===========================================================================

/// O jogador tem VIP em [agora], para o Social?
///
/// É [EntitlementVip.vigenteEm], a mesma definição do `PortaoVip` e da
/// Moderação. Não há cópia da regra aqui. VIP manual com entitlement canônico
/// válido conta (D08); passes de Mesas e Ranking moram em outras coleções, que o
/// Social não lê.
///
/// Documento ilegível vira SEM DIREITO, como na Comunicação: um direito que não
/// dá para provar não é um direito.
bool vipSocialVigenteEm(
  String uid,
  Map<String, Object?>? documento,
  DateTime agora,
) {
  try {
    return EntitlementVip.fromMap(uid, documento).vigenteEm(agora.toUtc());
  } catch (_) {
    return false;
  }
}

// ===========================================================================
// ESTADO EFETIVO, TOKEN E IMPRESSÃO
// ===========================================================================

/// O estado que vale para toda decisão: um canônico ativo que nasceu sob um
/// corte antigo está LOGICAMENTE ENCERRADO, mesmo antes da faxina.
EstadoSeguir estadoEfetivoSeguir({
  required EstadoSeguir fisico,
  required String? corteNaCriacao,
  required String? corteAtual,
}) {
  if (!fisico.ativo) return fisico;
  return nasceuSobOCorteAtual(
    corteNaCriacao: corteNaCriacao,
    corteAtual: corteAtual,
  )
      ? fisico
      : EstadoSeguir.encerrado;
}

/// O token que o cliente vê e devolve: a referência do canônico da direção e o
/// corte do par. Opaco para o cliente; as duas partes são comparadas aqui.
class TokenSeguir {
  const TokenSeguir({this.ref, this.corte});

  final String? ref;
  final String? corte;

  /// O token de um par que nunca teve canônico nem corte.
  static const TokenSeguir vazio = TokenSeguir();

  /// `null` quando as duas partes são ausentes.
  String? codificar() {
    final r = _parteNormalizada(ref);
    final c = _parteNormalizada(corte);
    if (r == null && c == null) return null;
    return '${r ?? ''}$_separadorDeToken${c ?? ''}';
  }

  /// `null` para token malformado. `null` ou ausente na entrada é o token vazio.
  static TokenSeguir? ler(Object? bruto) {
    if (bruto == null) return TokenSeguir.vazio;
    if (bruto is! String) return null;
    final partes = bruto.split(_separadorDeToken);
    if (partes.length != 2) return null;
    if (!_formatoParteDeToken.hasMatch(partes[0])) return null;
    if (!_formatoParteDeToken.hasMatch(partes[1])) return null;
    return TokenSeguir(
      ref: _parteNormalizada(partes[0]),
      corte: _parteNormalizada(partes[1]),
    );
  }
}

String? _parteNormalizada(String? s) => (s == null || s.isEmpty) ? null : s;

/// A chave da intenção, sempre escopada ao ator.
String chaveDaIntencaoSeguir(String atorUid, String intencaoId) =>
    '$atorUid|$intencaoId';

/// A impressão do comando: operação, direção e token visto (adendo §4.0).
///
/// O mesmo `intencaoId` com outra impressão é reuso, e não reenvio.
String impressaoDoComandoSeguir({
  required OperacaoSeguir operacao,
  required String? tokenVisto,
}) =>
    '${operacao.name}|${operacao.naSaida ? 'saida' : 'entrada'}|'
    '${tokenVisto ?? '-'}';

// ===========================================================================
// ESPELHOS P1–P4
// ===========================================================================

/// Os espelhos que EXISTEM no estado dado. Todo escritor da direção grava estes
/// e apaga os outros da mesma direção (adendo A1).
Set<EspelhoSeguir> espelhosDoEstadoSeguir(EstadoSeguir estado) {
  if (estado == EstadoSeguir.confirmado) {
    return const {
      EspelhoSeguir.seguindoDoSeguidor,
      EspelhoSeguir.seguidoresDoSeguido,
    };
  }
  if (estado == EstadoSeguir.pendente) {
    return const {
      EspelhoSeguir.pedidoEnviadoDoSeguidor,
      EspelhoSeguir.pedidoRecebidoDoSeguido,
    };
  }
  return const {};
}

/// Variação do contador técnico de pendentes ENVIADOS do seguidor da direção
/// numa transição de [antes] (físico) para [depois].
int deltaPendentesEnviados({
  required EstadoSeguir antes,
  required EstadoSeguir depois,
}) {
  final era = antes == EstadoSeguir.pendente ? 1 : 0;
  final sera = depois == EstadoSeguir.pendente ? 1 : 0;
  return sera - era;
}

// ===========================================================================
// RITMO — janelas MÓVEIS exatas
// ===========================================================================

/// Os instantes que caem no intervalo móvel que termina em [agora].
///
/// Um instante futuro (relógio divergente) CONTA: na dúvida, o limite pesa.
List<DateTime> instantesNaJanela(
  Iterable<DateTime> instantes,
  DateTime agora,
  Duration janela,
) {
  final limite = agora.subtract(janela);
  final dentro = instantes.where((t) => t.isAfter(limite)).toList()..sort();
  return dentro;
}

/// O que o ritmo diz de uma nova criação.
RecusaSeguir? avaliarRitmoDeCriacao({
  required Iterable<DateTime> criacoesDoAtor,
  required Iterable<DateTime> criacoesNoPar,
  required DateTime agora,
}) {
  if (instantesNaJanela(criacoesDoAtor, agora, kJanelaRitmoCurta).length >=
      kMaximoCriacoesJanelaCurta) {
    return RecusaSeguir.ritmoExcedido;
  }
  if (instantesNaJanela(criacoesDoAtor, agora, kJanelaRitmoLonga).length >=
      kMaximoCriacoesJanelaLonga) {
    return RecusaSeguir.ritmoExcedido;
  }
  if (instantesNaJanela(criacoesNoPar, agora, kJanelaRitmoPorAlvo).length >=
      kMaximoCriacoesPorAlvo) {
    return RecusaSeguir.ritmoExcedido;
  }
  return null;
}

// ===========================================================================
// O VEREDITO DE UM COMANDO
// ===========================================================================

/// Tudo o que o TypeScript leu dentro da transação, sem interpretação.
class EntradaComandoSeguir {
  const EntradaComandoSeguir({
    required this.operacao,
    required this.atorUid,
    required this.alvoUid,
    required this.intencaoId,
    required this.tokenVisto,
    required this.atorVip,
    required this.alvoVip,
    required this.contatoPermitido,
    required this.atorEmExclusao,
    required this.alvoEmExclusao,
    required this.estadoFisico,
    required this.refAtual,
    required this.corteNaCriacao,
    required this.corteAtual,
    required this.ultimaIntencaoChave,
    required this.ultimaIntencaoImpressao,
    required this.privacidadeAlvo,
    required this.criacoesDoAtor,
    required this.criacoesNoPar,
    required this.pendentesEnviadosDoAtor,
    required this.agora,
  });

  final OperacaoSeguir operacao;
  final String atorUid;
  final String alvoUid;
  final String intencaoId;

  /// O token como chegou do cliente. Validado aqui.
  final Object? tokenVisto;

  final bool atorVip;
  final bool alvoVip;

  /// Veredito de contato da Moderação, como ele é hoje (sem ampliação).
  final bool contatoPermitido;

  final bool atorEmExclusao;
  final bool alvoEmExclusao;

  /// Canônico da direção afetada.
  final EstadoSeguir estadoFisico;
  final String? refAtual;
  final String? corteNaCriacao;
  final String? ultimaIntencaoChave;
  final String? ultimaIntencaoImpressao;

  /// Corte atual do par (ausente = `null`).
  final String? corteAtual;

  /// Privacidade do SEGUIDO. Só pesa em [OperacaoSeguir.seguir].
  final PrivacidadeSocial privacidadeAlvo;

  /// Histórico de criações do ator (`playerSocialRitmo`) e do par (canônico).
  ///
  /// `null` = histórico DESCONHECIDO (campo ausente ou formato que não é lista).
  /// Lista vazia = histórico conhecido e vazio, que é como um ator ou par novo
  /// se apresenta. Uma criação só é autorizada com os dois históricos
  /// conhecidos: desconhecido não vira "zero criações".
  final List<DateTime>? criacoesDoAtor;
  final List<DateTime>? criacoesNoPar;

  /// Contador técnico de pendentes enviados do ator. `null` = desconhecido.
  /// Um valor negativo também é tratado como desconhecido: não é contagem.
  final int? pendentesEnviadosDoAtor;

  final DateTime agora;
}

/// O veredito. Só há escrita quando [novoEstado] não é `null`.
class VereditoSeguir {
  const VereditoSeguir._({
    required this.aceita,
    required this.recusa,
    required this.repeticao,
    required this.estadoEfetivo,
    this.novoEstado,
    this.deltaPendentes = 0,
    this.consumirRitmo = false,
    this.criacoesDoAtorApos,
    this.criacoesNoParApos,
    this.chaveIntencao,
    this.impressao,
  });

  factory VereditoSeguir.recusado(
    RecusaSeguir recusa,
    EstadoSeguir estadoEfetivo,
  ) =>
      VereditoSeguir._(
        aceita: false,
        recusa: recusa,
        repeticao: false,
        estadoEfetivo: estadoEfetivo,
      );

  /// O desfecho pedido JÁ VALE: sucesso, sem escrita.
  factory VereditoSeguir.repeticao(EstadoSeguir estadoEfetivo) =>
      VereditoSeguir._(
        aceita: true,
        recusa: null,
        repeticao: true,
        estadoEfetivo: estadoEfetivo,
      );

  final bool aceita;
  final RecusaSeguir? recusa;
  final bool repeticao;

  /// O estado efetivo da direção depois do veredito (o atual, sem escrita).
  final EstadoSeguir estadoEfetivo;

  /// O estado físico a gravar. `null` = nenhuma escrita.
  final EstadoSeguir? novoEstado;

  /// Aplicado ao contador técnico do SEGUIDOR da direção.
  final int deltaPendentes;

  /// Só O01/O02 confirmadas consomem ritmo.
  final bool consumirRitmo;
  final List<DateTime>? criacoesDoAtorApos;
  final List<DateTime>? criacoesNoParApos;

  final String? chaveIntencao;
  final String? impressao;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'repeticao': repeticao,
        'estadoEfetivo': estadoEfetivo.name,
        'novoEstado': novoEstado?.name,
        'deltaPendentes': deltaPendentes,
        'consumirRitmo': consumirRitmo,
        'criacoesDoAtorApos': criacoesDoAtorApos
            ?.map((t) => t.toUtc().toIso8601String())
            .toList(growable: false),
        'criacoesNoParApos': criacoesNoParApos
            ?.map((t) => t.toUtc().toIso8601String())
            .toList(growable: false),
        'espelhos': novoEstado == null
            ? null
            : espelhosDoEstadoSeguir(novoEstado!)
                .map((p) => p.name)
                .toList(growable: false),
        'chaveIntencao': chaveIntencao,
        'impressao': impressao,
      };
}

/// Decide um comando de seguir, na ORDEM do adendo §2 — que não pode ser
/// reordenada:
///
///   1. forma; 4. impedimentos; 5. fronteira de geração; 6. estado efetivo;
///   7. deduplicação na geração atual; 8. desfecho já alcançado;
///   9. pré-condição de estado e referência; 10. limites; 11. escrita.
///
/// (2 e 3 — resolver o alvo e ler os documentos — são do TypeScript.)
VereditoSeguir avaliarComandoSeguir(EntradaComandoSeguir e) {
  final op = e.operacao;

  // 1. FORMA
  if (e.atorUid.isEmpty || e.alvoUid.isEmpty) {
    return VereditoSeguir.recusado(RecusaSeguir.pedidoInvalido, e.estadoFisico);
  }
  if (e.atorUid == e.alvoUid) {
    return VereditoSeguir.recusado(
        RecusaSeguir.acaoSobreSiMesmo, e.estadoFisico);
  }
  if (!_formatoIntencao.hasMatch(e.intencaoId)) {
    return VereditoSeguir.recusado(RecusaSeguir.pedidoInvalido, e.estadoFisico);
  }
  final token = TokenSeguir.ler(e.tokenVisto);
  if (token == null) {
    return VereditoSeguir.recusado(RecusaSeguir.pedidoInvalido, e.estadoFisico);
  }

  final efetivo = estadoEfetivoSeguir(
    fisico: e.estadoFisico,
    corteNaCriacao: e.corteNaCriacao,
    corteAtual: e.corteAtual,
  );

  // 4. IMPEDIMENTOS — recusam mesmo um reenvio.
  if (e.atorEmExclusao) {
    return VereditoSeguir.recusado(RecusaSeguir.acaoIndisponivel, efetivo);
  }
  if (e.alvoEmExclusao) {
    if (op.criacao) {
      return VereditoSeguir.recusado(
          RecusaSeguir.perfilPublicoNaoDisponivel, efetivo);
    }
    // Encerramento contra conta em exclusão: sem escrita. A exclusão remove o
    // vínculo, e nenhum uso social é possível até lá (adendo A3).
    return VereditoSeguir.repeticao(EstadoSeguir.nenhum);
  }
  if (!e.atorVip) {
    return VereditoSeguir.recusado(RecusaSeguir.requerVip, efetivo);
  }
  if (op.criacao) {
    if (!e.contatoPermitido || !e.alvoVip) {
      return VereditoSeguir.recusado(RecusaSeguir.acaoIndisponivel, efetivo);
    }
  }

  // 5. FRONTEIRA DE GERAÇÃO — nada de outra geração passa daqui.
  if (_parteNormalizada(token.corte) != _parteNormalizada(e.corteAtual)) {
    return VereditoSeguir.recusado(RecusaSeguir.referenciaObsoleta, efetivo);
  }

  // 7. DEDUPLICAÇÃO, restrita à geração atual.
  final chave = chaveDaIntencaoSeguir(e.atorUid, e.intencaoId);
  final impressao = impressaoDoComandoSeguir(
    operacao: op,
    tokenVisto: token.codificar(),
  );
  if (e.ultimaIntencaoChave == chave) {
    if (e.ultimaIntencaoImpressao == impressao) {
      return VereditoSeguir.repeticao(efetivo);
    }
    return VereditoSeguir.recusado(RecusaSeguir.pedidoInvalido, efetivo);
  }

  // 8. DESFECHO JÁ ALCANÇADO — pelo estado EFETIVO.
  final encerradoOuNenhum =
      efetivo == EstadoSeguir.nenhum || efetivo == EstadoSeguir.encerrado;
  switch (op) {
    case OperacaoSeguir.seguir:
      if (efetivo.ativo) return VereditoSeguir.repeticao(efetivo);
    case OperacaoSeguir.aprovarPedido:
      if (efetivo == EstadoSeguir.confirmado) {
        return VereditoSeguir.repeticao(efetivo);
      }
    case OperacaoSeguir.cancelarPedido:
    case OperacaoSeguir.recusarPedido:
    case OperacaoSeguir.deixarDeSeguir:
    case OperacaoSeguir.removerSeguidor:
      if (encerradoOuNenhum) return VereditoSeguir.repeticao(efetivo);
  }

  // 9. PRÉ-CONDIÇÃO de estado e de referência.
  final bool estadoCabe;
  switch (op) {
    case OperacaoSeguir.seguir:
      estadoCabe = encerradoOuNenhum;
    case OperacaoSeguir.aprovarPedido:
    case OperacaoSeguir.cancelarPedido:
    case OperacaoSeguir.recusarPedido:
      estadoCabe = efetivo == EstadoSeguir.pendente;
    case OperacaoSeguir.deixarDeSeguir:
    case OperacaoSeguir.removerSeguidor:
      estadoCabe = efetivo == EstadoSeguir.confirmado;
  }
  if (!estadoCabe) {
    return VereditoSeguir.recusado(RecusaSeguir.referenciaObsoleta, efetivo);
  }
  if (_parteNormalizada(token.ref) != _parteNormalizada(e.refAtual)) {
    return VereditoSeguir.recusado(RecusaSeguir.referenciaObsoleta, efetivo);
  }

  // O estado novo.
  final EstadoSeguir novo;
  switch (op) {
    case OperacaoSeguir.seguir:
      novo = e.privacidadeAlvo == PrivacidadeSocial.privado
          ? EstadoSeguir.pendente
          : EstadoSeguir.confirmado;
    case OperacaoSeguir.aprovarPedido:
      novo = EstadoSeguir.confirmado;
    case OperacaoSeguir.cancelarPedido:
    case OperacaoSeguir.recusarPedido:
    case OperacaoSeguir.deixarDeSeguir:
    case OperacaoSeguir.removerSeguidor:
      novo = EstadoSeguir.encerrado;
  }

  // 10. LIMITES — só a criação de saída (O01/O02) consome e é limitada.
  final consome = op == OperacaoSeguir.seguir;
  List<DateTime>? historicoDoAtorApos;
  List<DateTime>? historicoNoParApos;
  if (consome) {
    // Sem os dois históricos conhecidos, o limite não é comprovável: falha
    // fechada, sem estado novo e sem consumo.
    final doAtor = e.criacoesDoAtor;
    final noPar = e.criacoesNoPar;
    if (doAtor == null || noPar == null) {
      return VereditoSeguir.recusado(RecusaSeguir.limiteIndisponivel, efetivo);
    }
    final recusaDeRitmo = avaliarRitmoDeCriacao(
      criacoesDoAtor: doAtor,
      criacoesNoPar: noPar,
      agora: e.agora,
    );
    if (recusaDeRitmo != null) {
      return VereditoSeguir.recusado(recusaDeRitmo, efetivo);
    }
    if (novo == EstadoSeguir.pendente) {
      final pendentes = e.pendentesEnviadosDoAtor;
      if (pendentes == null || pendentes < 0) {
        return VereditoSeguir.recusado(
            RecusaSeguir.limiteIndisponivel, efetivo);
      }
      // O pedido físico que esta transição substitui já estava contado.
      final saldo =
          pendentes + deltaPendentesEnviados(antes: e.estadoFisico, depois: novo);
      if (saldo > kTetoPedidosPendentesEnviados) {
        return VereditoSeguir.recusado(
            RecusaSeguir.limitePedidosPendentes, efetivo);
      }
    }
    historicoDoAtorApos =
        instantesNaJanela(doAtor, e.agora, kJanelaRitmoLonga)..add(e.agora);
    historicoNoParApos =
        instantesNaJanela(noPar, e.agora, kJanelaRitmoPorAlvo)..add(e.agora);
  }

  // 11. ESCRITA.
  return VereditoSeguir._(
    aceita: true,
    recusa: null,
    repeticao: false,
    estadoEfetivo: novo,
    novoEstado: novo,
    deltaPendentes: deltaPendentesEnviados(antes: e.estadoFisico, depois: novo),
    consumirRitmo: consome,
    criacoesDoAtorApos: historicoDoAtorApos,
    // O histórico por alvo sobrevive a encerramento, corte e recriação: só a
    // criação o atualiza, e os demais escritores o preservam no canônico.
    criacoesNoParApos: historicoNoParApos,
    chaveIntencao: chave,
    impressao: impressao,
  );
}

// ===========================================================================
// FAXINA POR CORTE
// ===========================================================================

/// O que a faxina faz com o canônico de uma direção depois de um corte.
///
/// Só encerra o que nasceu sob corte ANTIGO. Uma relação nova, criada depois do
/// desbloqueio sob o corte atual, não é tocada (S32b).
class VereditoFaxinaSeguir {
  const VereditoFaxinaSeguir({required this.encerrar, required this.deltaPendentes});

  final bool encerrar;
  final int deltaPendentes;

  Map<String, Object?> toJson() => {
        'encerrar': encerrar,
        'deltaPendentes': deltaPendentes,
        'espelhos': const <String>[],
      };
}

VereditoFaxinaSeguir avaliarFaxinaSeguir({
  required EstadoSeguir fisico,
  required String? corteNaCriacao,
  required String? corteAtual,
}) {
  final efetivo = estadoEfetivoSeguir(
    fisico: fisico,
    corteNaCriacao: corteNaCriacao,
    corteAtual: corteAtual,
  );
  final encerrar = fisico.ativo && efetivo == EstadoSeguir.encerrado;
  return VereditoFaxinaSeguir(
    encerrar: encerrar,
    deltaPendentes: encerrar
        ? deltaPendentesEnviados(antes: fisico, depois: EstadoSeguir.encerrado)
        : 0,
  );
}

// ===========================================================================
// AÇÕES DA VISITA (D07, opção B)
// ===========================================================================

/// As ações de seguir que a visita autorizada pode oferecer.
///
/// Lista vazia para observador gratuito (R08), em exclusão, diante de contato
/// impedido ou no próprio perfil. Nada aqui revela o plano do alvo: a ausência
/// de uma ação não diz o motivo. A execução revalida tudo de qualquer modo.
List<AcaoSeguir> acoesDeSeguir({
  required bool euMesmo,
  required bool observadorVip,
  required bool alvoVip,
  required bool contatoPermitido,
  required bool observadorEmExclusao,
  required bool alvoEmExclusao,
  required PrivacidadeSocial privacidadeAlvo,
  required EstadoSeguir efetivoSaida,
  required EstadoSeguir efetivoEntrada,
}) {
  if (euMesmo ||
      !observadorVip ||
      observadorEmExclusao ||
      alvoEmExclusao ||
      !contatoPermitido) {
    return const [];
  }
  final acoes = <AcaoSeguir>[];

  if (efetivoSaida == EstadoSeguir.pendente) {
    acoes.add(AcaoSeguir.cancelarPedidoSeguir);
  } else if (efetivoSaida == EstadoSeguir.confirmado) {
    acoes.add(AcaoSeguir.deixarDeSeguir);
  } else if (alvoVip) {
    acoes.add(privacidadeAlvo == PrivacidadeSocial.privado
        ? AcaoSeguir.solicitarSeguir
        : AcaoSeguir.seguir);
  }

  if (efetivoEntrada == EstadoSeguir.pendente) {
    if (alvoVip) acoes.add(AcaoSeguir.aprovarPedidoSeguir);
    acoes.add(AcaoSeguir.recusarPedidoSeguir);
  } else if (efetivoEntrada == EstadoSeguir.confirmado) {
    acoes.add(AcaoSeguir.removerSeguidor);
  }

  return List<AcaoSeguir>.unmodifiable(acoes);
}
