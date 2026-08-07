// participants.dart — identidade da unidade que disputa o torneio.
//
// Camada pura: sem Firestore, sem UI.
//
// POR QUE EXISTE: em torneio individual quem pontua e o jogador; em torneio de
// dupla quem pontua e a DUPLA, e nenhum dos dois jogadores sozinho. Classificacao,
// avanco de fase e campeao precisam de uma chave unica para essa unidade, e usar
// `userId` direto quebraria em dupla — dois jogadores teriam duas linhas na
// classificacao de uma competicao que eles disputam juntos.
//
// O identificador de dupla e DERIVADO dos membros ordenados, nunca sorteado: a
// mesma dupla produz a mesma chave em qualquer maquina, em qualquer momento, sem
// consultar nada. Isso e o que permite deduplicar resultado no cliente e no
// servidor com o mesmo resultado.

import 'tournament_model.dart';

/// Unidade que disputa a edicao: um jogador, ou uma dupla.
class Participante {
  /// Identificador canonico. Em individual e o proprio `userId`; em dupla e
  /// `userA+userB` com os dois ordenados alfabeticamente.
  final String participanteId;

  /// Jogadores que compoem a unidade. Um em individual, dois em dupla.
  final List<String> membros;

  final TipoParticipacao tipo;

  const Participante._(this.participanteId, this.membros, this.tipo);

  /// Participante individual.
  factory Participante.individual(String userId) {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'nao pode ser vazio');
    }
    if (userId.contains(separador)) {
      throw ArgumentError.value(userId, 'userId', 'nao pode conter "$separador"');
    }
    return Participante._(userId, [userId], TipoParticipacao.individual);
  }

  /// Dupla. A ordem dos argumentos e irrelevante: `dupla(a, b)` e `dupla(b, a)`
  /// produzem o mesmo [participanteId], senao a mesma dupla teria duas linhas na
  /// classificacao dependendo de quem clicou em "convidar".
  factory Participante.dupla(String userA, String userB) {
    for (final u in [userA, userB]) {
      if (u.isEmpty) {
        throw ArgumentError.value(u, 'membro', 'nao pode ser vazio');
      }
      if (u.contains(separador)) {
        throw ArgumentError.value(u, 'membro', 'nao pode conter "$separador"');
      }
    }
    if (userA == userB) {
      throw ArgumentError.value(userB, 'userB', 'dupla exige dois jogadores distintos');
    }
    final membros = [userA, userB]..sort();
    return Participante._(
      membros.join(separador),
      List.unmodifiable(membros),
      TipoParticipacao.dupla,
    );
  }

  /// Separador dos membros na chave. Nao pode aparecer em `userId`, sob pena de
  /// duas duplas distintas colidirem em uma so chave.
  static const separador = '+';

  bool contem(String userId) => membros.contains(userId);

  /// Reconstroi a partir do identificador canonico.
  ///
  /// Recusa entrada malformada em vez de assumir individual: um id de dupla
  /// corrompido lido como jogador solto viraria uma linha fantasma na
  /// classificacao.
  factory Participante.deId(String participanteId) {
    if (participanteId.isEmpty) {
      throw const FormatException('participanteId vazio.');
    }
    final partes = participanteId.split(separador);
    if (partes.length == 1) return Participante.individual(partes.first);
    if (partes.length == 2) {
      if (partes[0].compareTo(partes[1]) >= 0) {
        throw FormatException(
            'participanteId de dupla deve ter os membros ordenados (recebido: $participanteId).');
      }
      return Participante.dupla(partes[0], partes[1]);
    }
    throw FormatException('participanteId invalido: $participanteId.');
  }

  @override
  bool operator ==(Object other) =>
      other is Participante && other.participanteId == participanteId;

  @override
  int get hashCode => participanteId.hashCode;

  @override
  String toString() => 'Participante($participanteId)';
}
