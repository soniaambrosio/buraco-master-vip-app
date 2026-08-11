// sancao.dart — INFRAESTRUTURA de sanção (OS de Moderação §11).
//
// Leia o título com atenção: este arquivo oferece o mecanismo, e não a política.
// A OS é explícita ao proibir inventar uma política disciplinar definitiva sem
// especificação de produto — "quantas denúncias procedentes levam a quantos dias
// de silêncio" NÃO está aqui, e não deve ser adivinhado por quem for mexer
// depois. O que está aqui é o suficiente para aplicar, expirar, revogar e
// consultar uma sanção que alguém com autoridade decidiu.
//
// NADA NESTE ARQUIVO É ESCRITO PELO JOGADOR. O cliente comum não cria, não
// altera e não apaga sanção; ele apenas lê o efeito que recai sobre ele próprio,
// para que a interface possa dizer "você está silenciado até tal hora" em vez de
// falhar sem explicação.
//
// O RELÓGIO VEM DE FORA. Nenhuma função aqui chama `DateTime.now()`. Uma sanção
// que expira no meio de uma operação precisa expirar no MESMO instante para
// todas as verificações daquela operação — senão a primeira checagem diz
// "silenciado" e a segunda, milissegundos depois, diz "livre", e o resultado
// passa a depender de onde o código olhou o relógio primeiro (§17 da OS).

import 'validacao.dart';

/// O que a sanção faz. A progressão entre elas é decisão de produto.
enum TipoSancao {
  /// Registro sem efeito técnico. Existe para que a primeira ocorrência fique
  /// no histórico sem punir.
  advertencia,

  /// Impede usar o chat. Não impede jogar.
  muteTemporario,

  /// Impede as rotas sociais (convite, mensagem privada). Não impede jogar.
  restricaoSocial,

  /// Impede entrar na aplicação por um prazo.
  suspensaoTemporaria,

  /// Impede entrar na aplicação sem prazo de término.
  suspensaoPermanente,
}

/// De onde veio a decisão.
enum OrigemSancao {
  /// Uma pessoa com autoridade decidiu, olhando as evidências.
  administrativa,

  /// Regra automática. Nenhuma existe hoje — o valor está aqui para que o dia em
  /// que existir não exija migrar os registros já gravados.
  automatica,
}

enum StatusSancao { ativa, revogada }

/// Por que a aplicação de uma sanção foi recusada.
enum RecusaSancao {
  identificadorInvalido,
  prazoAusente,
  prazoNoPassado,
  prazoEmSancaoPermanente,
  motivoAusente,
}

class VereditoSancao {
  final bool aceita;
  final RecusaSancao? recusa;
  final List<String> falhas;

  const VereditoSancao.aceita()
      : aceita = true,
        recusa = null,
        falhas = const [];
  const VereditoSancao.recusada(this.recusa, this.falhas) : aceita = false;

  Map<String, Object?> toJson() =>
      {'aceita': aceita, 'recusa': recusa?.name, 'falhas': falhas};
}

/// Precisa de prazo de término?
bool exigePrazo(TipoSancao t) =>
    t == TipoSancao.muteTemporario ||
    t == TipoSancao.restricaoSocial ||
    t == TipoSancao.suspensaoTemporaria;

/// Uma sanção registrada.
class Sancao {
  final String sancaoId;
  final String userId;
  final TipoSancao tipo;
  final String motivo;
  final DateTime inicio;

  /// `null` em advertência (instantânea) e em suspensão permanente (sem fim).
  final DateTime? fim;

  /// Quem decidiu. UID do administrador, nunca do jogador sancionado.
  final String responsavel;
  final OrigemSancao origem;
  final StatusSancao status;

  /// Denúncia que originou a sanção, quando houver.
  final String? reportId;

  Sancao({
    required this.sancaoId,
    required this.userId,
    required this.tipo,
    required this.motivo,
    required DateTime inicio,
    DateTime? fim,
    required this.responsavel,
    this.origem = OrigemSancao.administrativa,
    this.status = StatusSancao.ativa,
    this.reportId,
  })  : inicio = exigirUtc(inicio, 'inicio'),
        fim = fim == null ? null : exigirUtc(fim, 'fim');

  /// A sanção está valendo em [agora]?
  ///
  /// Revogada nunca vale. Sem `fim`, vale para sempre a partir do início — o que
  /// é correto tanto para suspensão permanente quanto para advertência, cujo
  /// efeito técnico é nenhum de qualquer maneira.
  bool vigenteEm(DateTime agora) {
    exigirUtc(agora, 'agora');
    if (status == StatusSancao.revogada) return false;
    if (agora.isBefore(inicio)) return false;
    final f = fim;
    if (f == null) return true;
    return agora.isBefore(f);
  }

  Map<String, Object?> toJson() => {
        'sancaoId': sancaoId,
        'userId': userId,
        'tipo': tipo.name,
        'motivo': motivo,
        'inicio': inicio.toIso8601String(),
        'fim': fim?.toIso8601String(),
        'responsavel': responsavel,
        'origem': origem.name,
        'status': status.name,
        if (reportId != null) 'reportId': reportId,
        'esquema': kEsquemaSancao,
      };

  static Sancao fromMap(Map<String, Object?> m) => Sancao(
        sancaoId: m['sancaoId']! as String,
        userId: m['userId']! as String,
        tipo: TipoSancao.values.byName(m['tipo']! as String),
        motivo: m['motivo']! as String,
        inicio: DateTime.parse(m['inicio']! as String).toUtc(),
        fim: m['fim'] == null
            ? null
            : DateTime.parse(m['fim']! as String).toUtc(),
        responsavel: m['responsavel']! as String,
        origem: OrigemSancao.values.byName(m['origem'] as String? ?? 'administrativa'),
        status: StatusSancao.values.byName(m['status'] as String? ?? 'ativa'),
        reportId: m['reportId'] as String?,
      );
}

/// Avalia um pedido de aplicação de sanção.
///
/// Quem chama já precisa ter provado que o solicitante é administrador — isso é
/// autorização, não domínio, e mora na Function.
VereditoSancao avaliarSancao({
  required String userId,
  required String responsavel,
  required TipoSancao tipo,
  required String motivo,
  required DateTime inicio,
  DateTime? fim,
}) {
  exigirUtc(inicio, 'inicio');

  final falhas = <String>[];
  if (!identificadorValido(userId)) falhas.add('userId');
  if (!identificadorValido(responsavel)) falhas.add('responsavel');
  if (falhas.isNotEmpty) {
    return VereditoSancao.recusada(RecusaSancao.identificadorInvalido, falhas);
  }

  final m = textoOpcional(motivo);
  if (m == null) {
    return VereditoSancao.recusada(
        RecusaSancao.motivoAusente, const ['motivo']);
  }

  if (exigePrazo(tipo)) {
    if (fim == null) {
      return VereditoSancao.recusada(RecusaSancao.prazoAusente, const ['fim']);
    }
    exigirUtc(fim, 'fim');
    // Prazo que já passou aplicaria uma sanção nascida expirada — quase sempre
    // erro de digitação, e silenciá-lo faria o administrador achar que puniu.
    if (!fim.isAfter(inicio)) {
      return VereditoSancao.recusada(
          RecusaSancao.prazoNoPassado, const ['fim']);
    }
  } else if (fim != null) {
    // Prazo numa permanente é contradição: ou é permanente, ou tem fim.
    return VereditoSancao.recusada(
        RecusaSancao.prazoEmSancaoPermanente, const ['fim']);
  }

  return const VereditoSancao.aceita();
}

/// Efeito consolidado das sanções de um jogador num instante.
///
/// É o documento que o servidor lê em UMA leitura antes de liberar chat ou rota
/// social — varrer o histórico inteiro a cada mensagem não escala.
class EstadoModeracao {
  final String userId;
  final DateTime? chatSilenciadoAte;
  final DateTime? socialRestritoAte;
  final DateTime? suspensoAte;
  final bool suspensaoPermanente;

  const EstadoModeracao({
    required this.userId,
    this.chatSilenciadoAte,
    this.socialRestritoAte,
    this.suspensoAte,
    this.suspensaoPermanente = false,
  });

  static bool _ate(DateTime? limite, DateTime agora) =>
      limite != null && agora.isBefore(limite);

  bool chatSilenciadoEm(DateTime agora) =>
      _ate(chatSilenciadoAte, exigirUtc(agora, 'agora'));

  bool socialRestritoEm(DateTime agora) =>
      _ate(socialRestritoAte, exigirUtc(agora, 'agora'));

  bool suspensoEm(DateTime agora) =>
      suspensaoPermanente || _ate(suspensoAte, exigirUtc(agora, 'agora'));

  bool get semRestricao =>
      chatSilenciadoAte == null &&
      socialRestritoAte == null &&
      suspensoAte == null &&
      !suspensaoPermanente;

  Map<String, Object?> toJson() => {
        'userId': userId,
        'chatSilenciadoAte': chatSilenciadoAte?.toIso8601String(),
        'socialRestritoAte': socialRestritoAte?.toIso8601String(),
        'suspensoAte': suspensoAte?.toIso8601String(),
        'suspensaoPermanente': suspensaoPermanente,
        'esquema': kEsquemaSancao,
      };

  static EstadoModeracao fromMap(Map<String, Object?> m) {
    DateTime? ler(String k) {
      final v = m[k];
      return v is String ? DateTime.parse(v).toUtc() : null;
    }

    return EstadoModeracao(
      userId: m['userId']! as String,
      chatSilenciadoAte: ler('chatSilenciadoAte'),
      socialRestritoAte: ler('socialRestritoAte'),
      suspensoAte: ler('suspensoAte'),
      suspensaoPermanente: m['suspensaoPermanente'] == true,
    );
  }
}

/// Dobra o histórico de sanções no efeito que vale em [agora].
///
/// Quando duas sanções do mesmo tipo se sobrepõem, vence a de término MAIS
/// DISTANTE: aplicar um segundo silêncio não pode encurtar o primeiro, senão
/// punir de novo viraria alívio.
EstadoModeracao consolidar(
  String userId,
  Iterable<Sancao> sancoes,
  DateTime agora,
) {
  exigirUtc(agora, 'agora');

  DateTime? chat, social, suspenso;
  var permanente = false;

  DateTime? maior(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  for (final s in sancoes) {
    if (s.userId != userId) continue;
    if (!s.vigenteEm(agora)) continue;

    switch (s.tipo) {
      case TipoSancao.advertencia:
        // Sem efeito técnico, por definição. Fica só no histórico.
        break;
      case TipoSancao.muteTemporario:
        chat = maior(chat, s.fim);
      case TipoSancao.restricaoSocial:
        social = maior(social, s.fim);
      case TipoSancao.suspensaoTemporaria:
        suspenso = maior(suspenso, s.fim);
      case TipoSancao.suspensaoPermanente:
        permanente = true;
    }
  }

  return EstadoModeracao(
    userId: userId,
    chatSilenciadoAte: chat,
    socialRestritoAte: social,
    suspensoAte: suspenso,
    suspensaoPermanente: permanente,
  );
}

/// Versão do formato dos documentos de sanção.
const int kEsquemaSancao = 1;
