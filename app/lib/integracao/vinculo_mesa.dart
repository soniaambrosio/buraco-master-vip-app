// vinculo_mesa.dart — QUEM DO TORNEIO É QUEM NA MESA.
//
// Este é o único lugar do sistema onde `participanteId` e `assento` se encontram,
// e ele existe porque a alternativa é catastrófica: associar por ORDEM DE LISTA.
//
// Ordem de lista parece funcionar até o dia em que funciona. `SolicitacaoPartida`
// declara os assentos em ordem e `Jogo` numera de 0 a 3; casar índice com índice
// é uma linha de código e uma bomba-relógio, porque a lista atravessa serialização,
// Firestore, fila de mensagens e reprocessamento — e basta uma dessas etapas
// reordenar para o campeão da edição ser outra pessoa, sem erro nenhum aparecer.
// Pior ainda seria deduzir a associação DEPOIS, pelo placar: em torneio de dupla o
// lado que pontuou tem dois jogadores, e inferir qual participante era qual a
// partir do resultado é adivinhação com cara de dado.
//
// Por isso o vínculo é:
//   * EXPLÍCITO   — cada jogador declara seu assento, um a um, por nome;
//   * VALIDADO    — confere contra a solicitação e contra a lei de assentos da
//                   mesa; qualquer divergência falha alto na hora de montar;
//   * IMUTÁVEL    — nenhum campo muda depois de construído, nenhuma lista é
//                   modificável, não há setter;
//   * PERSISTÍVEL — round-trip completo por JSON, para sobreviver a reinício de
//                   servidor e a reprocessamento de histórico.
//
// ESTE ARQUIVO NÃO JOGA BURACO E NÃO CLASSIFICA NINGUÉM. Ele é uma tabela de
// correspondência com opinião forte sobre estar certa.

import '../torneios/match_contract.dart';
import '../torneios/participants.dart';

/// Assento do Motor de Partidas ocupado por um jogador do torneio.
class AssentoDeJogador {
  /// `userId` do jogador — um dos [Participante.membros].
  final String userId;

  /// Assento na mesa, 0..3, como `Jogo` os numera.
  final int assento;

  const AssentoDeJogador({required this.userId, required this.assento});

  /// Lado da mesa a que o assento pertence, pela regra de `Jogo`: pares são
  /// `nos`, ímpares são `eles`. Não é convenção desta camada — é leitura da
  /// mesa, e por isso não pode ser parametrizada aqui.
  String get lado => assento.isEven ? 'nos' : 'eles';

  Map<String, Object?> toJson() => {'userId': userId, 'assento': assento};

  static AssentoDeJogador deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('vínculo: assento de jogador deve ser objeto.');
    }
    final userId = raw['userId'];
    final assento = raw['assento'];
    if (userId is! String || userId.isEmpty) {
      throw FormatException('vínculo: userId inválido (recebido: $userId).');
    }
    if (assento is! int) {
      throw FormatException('vínculo: assento deve ser int (recebido: $assento).');
    }
    return AssentoDeJogador(userId: userId, assento: assento);
  }

  @override
  String toString() => 'AssentoDeJogador($userId → $assento)';
}

/// Um participante do torneio e o(s) assento(s) que ele ocupa na mesa.
class VinculoLado {
  final String participanteId;

  /// `nos` | `eles`, no vocabulário de `Jogo`.
  final String lado;

  /// Jogadores do participante, cada um com seu assento. Um em individual, dois
  /// em dupla. A lista é ordenada por assento só para o JSON ficar estável — a
  /// associação NUNCA depende dessa ordem, sempre do par (`userId`, `assento`).
  final List<AssentoDeJogador> jogadores;

  VinculoLado({
    required this.participanteId,
    required this.lado,
    required List<AssentoDeJogador> jogadores,
  }) : jogadores = List.unmodifiable(
          List<AssentoDeJogador>.of(jogadores)
            ..sort((a, b) => a.assento - b.assento),
        ) {
    if (participanteId.isEmpty) {
      throw ArgumentError.value(
          participanteId, 'participanteId', 'não pode ser vazio');
    }
    if (lado != 'nos' && lado != 'eles') {
      throw ArgumentError.value(lado, 'lado', 'deve ser "nos" ou "eles"');
    }
    if (jogadores.isEmpty) {
      throw ArgumentError.value(jogadores, 'jogadores',
          'participante sem assento não está na mesa');
    }
  }

  List<int> get assentos =>
      List.unmodifiable([for (final j in jogadores) j.assento]);

  List<String> get membros =>
      List.unmodifiable([for (final j in jogadores) j.userId]);

  bool contem(String userId) => jogadores.any((j) => j.userId == userId);

  int? assentoDe(String userId) {
    for (final j in jogadores) {
      if (j.userId == userId) return j.assento;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'participanteId': participanteId,
        'lado': lado,
        'jogadores': [for (final j in jogadores) j.toJson()],
      };

  static VinculoLado deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('vínculo: lado deve ser objeto.');
    }
    final lista = raw['jogadores'];
    if (lista is! List) {
      throw const FormatException('vínculo: lado sem lista de jogadores.');
    }
    return VinculoLado(
      participanteId: '${raw['participanteId']}',
      lado: '${raw['lado']}',
      jogadores: [for (final j in lista) AssentoDeJogador.deJson(j)],
    );
  }

  @override
  String toString() => 'VinculoLado($participanteId = $lado $assentos)';
}

/// Por que um vínculo foi recusado.
///
/// Todas as recusas são falha alta na construção, não valor de retorno: um
/// vínculo errado que continuasse existindo contaminaria a partida inteira e só
/// apareceria na classificação final.
class VinculoInvalido implements Exception {
  final String motivo;
  const VinculoInvalido(this.motivo);

  @override
  String toString() => 'VinculoInvalido: $motivo';
}

/// A correspondência completa entre uma mesa do torneio e uma partida do motor.
///
/// Construído UMA vez, na solicitação da partida, e daí em diante só lido.
class VinculoDeMesa {
  final String matchId;
  final String tournamentId;
  final String editionId;
  final String faseId;
  final String mesaId;

  /// Exatamente dois: a mesa de buraco tem dois lados, e é por lado que `Jogo`
  /// pontua.
  final List<VinculoLado> lados;

  VinculoDeMesa._({
    required this.matchId,
    required this.tournamentId,
    required this.editionId,
    required this.faseId,
    required this.mesaId,
    required List<VinculoLado> lados,
  }) : lados = List.unmodifiable(lados);

  /// Declara o vínculo de uma partida solicitada.
  ///
  /// [assentosPorParticipante] é a declaração explícita: para cada
  /// `participanteId` da solicitação, o assento de CADA um de seus membros. Não
  /// há default, não há dedução por posição e não há caminho feliz que preencha
  /// o que o chamador não disse — quem conhece a mesa é quem monta a mesa.
  ///
  /// Falha alto em qualquer divergência:
  ///   * participante da solicitação sem declaração, ou declarado a mais;
  ///   * membro do participante sem assento, ou assento atribuído a alguém que
  ///     não é membro dele (o erro clássico do torneio de dupla);
  ///   * assento fora de 0..3, ou o mesmo assento em dois jogadores;
  ///   * membros do mesmo participante em lados opostos da mesa — em `Jogo`,
  ///     assentos 0/2 são uma dupla e 1/3 são a outra, então uma dupla partida
  ///     entre os dois lados pontuaria contra si mesma;
  ///   * dois participantes no mesmo lado.
  factory VinculoDeMesa.declarar({
    required SolicitacaoPartida solicitacao,
    required Map<String, Map<String, int>> assentosPorParticipante,
  }) {
    if (solicitacao.assentos.length != 2) {
      throw VinculoInvalido(
          'a mesa do Motor de Partidas tem dois lados; a solicitação ${solicitacao.matchId} '
          'traz ${solicitacao.assentos.length} participantes. Formar mesa com outro número '
          'de lados exige decisão de produto que esta camada não pode tomar.');
    }

    final esperados = {
      for (final p in solicitacao.assentos) p.participanteId: p,
    };
    final declarados = assentosPorParticipante.keys.toSet();
    if (declarados.length != esperados.length ||
        !declarados.containsAll(esperados.keys)) {
      throw VinculoInvalido(
          'os participantes declarados ($declarados) não são os da solicitação '
          '(${esperados.keys.toSet()}).');
    }

    final usados = <int, String>{};
    final lados = <VinculoLado>[];

    for (final entry in esperados.entries) {
      final participante = entry.value;
      final mapa = assentosPorParticipante[entry.key]!;

      final membrosEsperados = participante.membros.toSet();
      final membrosDeclarados = mapa.keys.toSet();
      if (membrosDeclarados.length != membrosEsperados.length ||
          !membrosDeclarados.containsAll(membrosEsperados)) {
        throw VinculoInvalido(
            'participante ${entry.key}: os jogadores com assento declarado '
            '($membrosDeclarados) não são os membros do participante '
            '($membrosEsperados).');
      }

      final jogadores = <AssentoDeJogador>[];
      for (final membro in participante.membros) {
        final assento = mapa[membro]!;
        if (assento < 0 || assento > 3) {
          throw VinculoInvalido(
              'participante ${entry.key}: assento $assento de $membro está fora de 0..3.');
        }
        final dono = usados[assento];
        if (dono != null) {
          throw VinculoInvalido(
              'assento $assento foi declarado para $membro e para $dono ao mesmo tempo.');
        }
        usados[assento] = membro;
        jogadores.add(AssentoDeJogador(userId: membro, assento: assento));
      }

      final ladosDosMembros = jogadores.map((j) => j.lado).toSet();
      if (ladosDosMembros.length != 1) {
        throw VinculoInvalido(
            'participante ${entry.key} ficou com jogadores em lados opostos da mesa '
            '(${jogadores.map((j) => '${j.userId}@${j.assento}').join(', ')}). '
            'Em Jogo, 0 e 2 são "nos" e 1 e 3 são "eles" — uma dupla dividida '
            'pontuaria contra si mesma.');
      }

      lados.add(VinculoLado(
        participanteId: entry.key,
        lado: ladosDosMembros.first,
        jogadores: jogadores,
      ));
    }

    if (lados[0].lado == lados[1].lado) {
      throw VinculoInvalido(
          'os dois participantes foram colocados no mesmo lado (${lados[0].lado}). '
          'Uma partida em que ninguém está do outro lado não tem adversário.');
    }

    return VinculoDeMesa._(
      matchId: solicitacao.matchId,
      tournamentId: solicitacao.tournamentId,
      editionId: solicitacao.editionId,
      faseId: solicitacao.faseId,
      mesaId: solicitacao.mesaId,
      lados: lados,
    );
  }

  VinculoLado? porParticipante(String participanteId) {
    for (final l in lados) {
      if (l.participanteId == participanteId) return l;
    }
    return null;
  }

  VinculoLado? porLado(String lado) {
    for (final l in lados) {
      if (l.lado == lado) return l;
    }
    return null;
  }

  /// Qual participante ocupa o [assento]. `null` quando o assento não pertence a
  /// ninguém do torneio — é o caso do parceiro-robô em torneio individual.
  String? participanteNoAssento(int assento) {
    for (final l in lados) {
      for (final j in l.jogadores) {
        if (j.assento == assento) return l.participanteId;
      }
    }
    return null;
  }

  /// Assentos que o torneio realmente atribuiu, em ordem crescente. Pode ser
  /// menor que quatro: torneio individual com dois participantes ocupa dois
  /// assentos, e os outros dois não têm dono no torneio.
  List<int> get assentosAtribuidos {
    final todos = <int>[for (final l in lados) ...l.assentos]..sort();
    return List.unmodifiable(todos);
  }

  Map<String, Object?> toJson() => {
        'matchId': matchId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'faseId': faseId,
        'mesaId': mesaId,
        'lados': [for (final l in lados) l.toJson()],
      };

  /// Reconstrói um vínculo persistido.
  ///
  /// Revalida a estrutura em vez de confiar no que estava gravado: um vínculo
  /// corrompido no banco é exatamente o caso em que ninguém quer descobrir o
  /// problema pela classificação.
  factory VinculoDeMesa.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('vínculo: $campo deve ser string não vazia (recebido: $v).');
      }
      return v;
    }

    final brutos = json['lados'];
    if (brutos is! List || brutos.length != 2) {
      throw const FormatException('vínculo: lados deve ser lista de exatamente 2 itens.');
    }
    final lados = [for (final l in brutos) VinculoLado.deJson(l)];

    if (lados[0].lado == lados[1].lado) {
      throw const FormatException('vínculo: os dois lados gravados são o mesmo.');
    }
    if (lados[0].participanteId == lados[1].participanteId) {
      throw const FormatException('vínculo: o mesmo participante nos dois lados.');
    }
    final assentos = <int>[for (final l in lados) ...l.assentos];
    if (assentos.toSet().length != assentos.length) {
      throw const FormatException('vínculo: assento repetido entre os lados.');
    }
    for (final l in lados) {
      for (final j in l.jogadores) {
        if (j.assento < 0 || j.assento > 3) {
          throw FormatException('vínculo: assento ${j.assento} fora de 0..3.');
        }
        if (j.lado != l.lado) {
          throw FormatException(
              'vínculo: ${j.userId} está no assento ${j.assento} (lado ${j.lado}) '
              'mas foi gravado no lado ${l.lado}.');
        }
      }
    }

    return VinculoDeMesa._(
      matchId: texto('matchId'),
      tournamentId: texto('tournamentId'),
      editionId: texto('editionId'),
      faseId: texto('faseId'),
      mesaId: texto('mesaId'),
      lados: lados,
    );
  }

  @override
  String toString() =>
      'VinculoDeMesa($matchId: ${lados.map((l) => '${l.participanteId}=${l.lado}').join(' x ')})';
}

/// Monta o vínculo padrão de uma mesa de dois lados a partir da solicitação.
///
/// Conveniência para o caminho que o Motor de Torneios realmente produz hoje
/// (`formarMesas` com `ladosPorMesa: 2`), e SÓ para ele. A atribuição é feita
/// aqui, uma vez, de forma declarada e auditável, e imediatamente congelada em
/// [VinculoDeMesa] — a partir daí ninguém mais olha para a ordem da lista.
///
/// Regra da atribuição, escrita para ser conferida:
///   * o primeiro participante da solicitação fica com o lado `nos`, o segundo
///     com `eles` — isso é uma CONVENÇÃO DE MONTAGEM, aplicada uma única vez e
///     registrada no vínculo, não uma dedução feita depois pelo resultado;
///   * participante individual ocupa um assento (0 ou 1); o assento parceiro
///     (2 ou 3) fica sem dono no torneio, porque o torneio não inscreveu ninguém
///     para ele;
///   * participante dupla ocupa os dois assentos do seu lado, na ordem em que
///     [Participante.membros] os lista — que é ordem alfabética estável, definida
///     em participants.dart, e não a ordem em que alguém clicou em "convidar".
///
/// Falha alto se a mesa não for de dois lados ou se algum participante tiver
/// mais de dois membros. Não há palpite para os casos que o projeto ainda não
/// definiu.
VinculoDeMesa montarVinculoPadrao(SolicitacaoPartida solicitacao) {
  if (solicitacao.assentos.length != 2) {
    throw VinculoInvalido(
        'montarVinculoPadrao só sabe mesa de 2 lados; a solicitação ${solicitacao.matchId} '
        'traz ${solicitacao.assentos.length}. Use VinculoDeMesa.declarar com os assentos '
        'explícitos quando o formato mudar.');
  }

  final mapa = <String, Map<String, int>>{};
  for (var lado = 0; lado < 2; lado++) {
    final participante = solicitacao.assentos[lado];
    final membros = participante.membros;
    if (membros.isEmpty || membros.length > 2) {
      throw VinculoInvalido(
          'participante ${participante.participanteId} tem ${membros.length} membros; '
          'a mesa comporta 1 ou 2 por lado.');
    }
    // lado 0 → assentos 0 e 2 ("nos"); lado 1 → assentos 1 e 3 ("eles").
    final assentos = [lado, lado + 2];
    mapa[participante.participanteId] = {
      for (var i = 0; i < membros.length; i++) membros[i]: assentos[i],
    };
  }

  return VinculoDeMesa.declarar(
    solicitacao: solicitacao,
    assentosPorParticipante: mapa,
  );
}
