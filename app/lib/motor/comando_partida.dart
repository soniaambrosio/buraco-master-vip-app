// comando_partida.dart — ENVELOPE DE JOGADA E RESULTADO (OS-01 §6).
//
// Hoje `online_service.dart` manda `{tipo:'descartar', id:'c12'}` e torce. Se o
// jogador tocar duas vezes, se a rede reenviar o quadro, ou se o app reconectar
// no meio da jogada, o servidor não tem como distinguir "o jogador quer
// descartar de novo" de "é a MESMA jogada chegando duas vezes". É assim que
// nasce a reclamação "eu descartei e a carta voltou".
//
// O envelope resolve isso com dois campos:
//
//   * eventoId       — identidade da INTENÇÃO. Reenviar a mesma intenção é
//                      seguro: o motor reconhece e devolve o resultado original
//                      sem aplicar de novo (ver `MotorPartida`).
//   * versaoEsperada — trava otimista. "Só aplique se a partida ainda estiver
//                      na versão que eu vi." Dois jogadores mandando comandos
//                      quase simultaneamente: o segundo é recusado com
//                      VERSAO_DESATUALIZADA em vez de agir sobre um estado que
//                      já mudou debaixo dele.
//
// Este arquivo é só o contrato — quem aplica é `motor_partida.dart`.

/// Jogadas que um assento pode pedir.
///
/// A lista é fechada de propósito: comando desconhecido é comando recusado.
/// "Encerrar rodada", "contar pontos" e "nova rodada" NÃO estão aqui — não são
/// pedidos de jogador, são transições que a autoridade da partida conduz.
enum TipoComando {
  comprarMonte,
  comprarLixo,
  baixar,
  estender,
  descartar,

  /// Reordena a própria mão. Não altera regra nem informação de ninguém, mas
  /// altera o snapshot do assento — por isso passa pelo mesmo caminho.
  ordenarMao,
}

/// Códigos de recusa. Estáveis: entram em log e em teste, não podem virar texto
/// livre.
class ErroComando {
  ErroComando._();

  /// A mesa está bloqueada pela auditoria de integridade.
  static const String estadoCorrompido = 'ESTADO_CORROMPIDO';

  /// O comando trazia `versaoEsperada` diferente da versão atual.
  static const String versaoDesatualizada = 'VERSAO_DESATUALIZADA';

  /// Não é a vez deste assento.
  static const String foraDeTurno = 'FORA_DE_TURNO';

  /// A rodada já acabou.
  static const String rodadaEncerrada = 'RODADA_ENCERRADA';

  /// A partida já acabou.
  static const String partidaEncerrada = 'PARTIDA_ENCERRADA';

  /// Assento fora de 0..3.
  static const String assentoInvalido = 'ASSENTO_INVALIDO';

  /// Envelope malformado (sem eventoId, campos faltando para o tipo, etc.).
  static const String comandoInvalido = 'COMANDO_INVALIDO';

  /// O motor recusou por regra de jogo. A mensagem do motor vai em
  /// `ResultadoComando.mensagem`.
  static const String regra = 'REGRA';
}

/// Pedido de jogada, pronto para trafegar.
class ComandoPartida {
  /// Identidade da intenção. Gerado pelo CLIENTE, estável entre reenvios.
  final String eventoId;

  final int assento;
  final TipoComando tipo;

  /// Cartas envolvidas (baixar/estender) ou a carta descartada (`descartar`
  /// usa o primeiro id).
  final List<String> ids;

  /// Índice do jogo da dupla, só para `estender`.
  final int? indiceJogo;

  /// Trava otimista. `null` = o cliente aceita aplicar sobre qualquer versão.
  final int? versaoEsperada;

  ComandoPartida({
    required this.eventoId,
    required this.assento,
    required this.tipo,
    List<String> ids = const [],
    this.indiceJogo,
    this.versaoEsperada,
  }) : ids = List.unmodifiable(ids);

  factory ComandoPartida.comprarMonte({
    required String eventoId,
    required int assento,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.comprarMonte,
        versaoEsperada: versaoEsperada,
      );

  factory ComandoPartida.comprarLixo({
    required String eventoId,
    required int assento,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.comprarLixo,
        versaoEsperada: versaoEsperada,
      );

  factory ComandoPartida.descartar({
    required String eventoId,
    required int assento,
    required String idCarta,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.descartar,
        ids: [idCarta],
        versaoEsperada: versaoEsperada,
      );

  factory ComandoPartida.baixar({
    required String eventoId,
    required int assento,
    required List<String> ids,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.baixar,
        ids: ids,
        versaoEsperada: versaoEsperada,
      );

  factory ComandoPartida.estender({
    required String eventoId,
    required int assento,
    required int indiceJogo,
    required List<String> ids,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.estender,
        ids: ids,
        indiceJogo: indiceJogo,
        versaoEsperada: versaoEsperada,
      );

  factory ComandoPartida.ordenarMao({
    required String eventoId,
    required int assento,
    int? versaoEsperada,
  }) =>
      ComandoPartida(
        eventoId: eventoId,
        assento: assento,
        tipo: TipoComando.ordenarMao,
        versaoEsperada: versaoEsperada,
      );

  /// O envelope tem o mínimo para ser executável? Não valida REGRA de jogo —
  /// isso é do motor.
  String? get problemaEstrutural {
    if (eventoId.trim().isEmpty) return 'eventoId vazio';
    switch (tipo) {
      case TipoComando.descartar:
        if (ids.length != 1) return 'descartar exige exatamente 1 carta';
        if (ids.first.trim().isEmpty) return 'id da carta vazio';
        break;
      case TipoComando.baixar:
        if (ids.isEmpty) return 'baixar exige as cartas do jogo';
        break;
      case TipoComando.estender:
        if (ids.isEmpty) return 'estender exige ao menos 1 carta';
        if (indiceJogo == null || indiceJogo! < 0) {
          return 'estender exige indiceJogo válido';
        }
        break;
      case TipoComando.comprarMonte:
      case TipoComando.comprarLixo:
      case TipoComando.ordenarMao:
        break;
    }
    return null;
  }

  /// O comando pretende alterar o estado da partida?
  bool get muta => true;

  Map<String, Object?> toJson() => {
        'eventoId': eventoId,
        'assento': assento,
        'tipo': tipo.name,
        if (ids.isNotEmpty) 'ids': ids,
        if (indiceJogo != null) 'indiceJogo': indiceJogo,
        if (versaoEsperada != null) 'versaoEsperada': versaoEsperada,
      };

  /// Lê um comando da rede. Retorna `null` quando o envelope é irreconhecível —
  /// o chamador responde COMANDO_INVALIDO.
  static ComandoPartida? deJson(Object? raw) {
    if (raw is! Map) return null;
    final eventoId = raw['eventoId'];
    final assento = raw['assento'];
    if (eventoId is! String || assento is! num) return null;
    final tipos = TipoComando.values.where((t) => t.name == raw['tipo']);
    if (tipos.isEmpty) return null;
    final idsRaw = raw['ids'];
    final ids = <String>[];
    if (idsRaw is List) {
      for (final e in idsRaw) {
        if (e is! String) return null;
        ids.add(e);
      }
    }
    final indice = raw['indiceJogo'];
    final versao = raw['versaoEsperada'];
    return ComandoPartida(
      eventoId: eventoId,
      assento: assento.toInt(),
      tipo: tipos.first,
      ids: ids,
      indiceJogo: indice is num ? indice.toInt() : null,
      versaoEsperada: versao is num ? versao.toInt() : null,
    );
  }

  @override
  String toString() => 'ComandoPartida(${tipo.name}, a$assento, $eventoId)';
}

/// Desfecho de um comando.
enum StatusComando {
  /// Alterou o estado. A versão subiu.
  aplicado,

  /// Já tinha sido aplicado antes com o mesmo eventoId. NADA foi refeito; o
  /// resultado devolvido é o original.
  duplicado,

  /// Não alterou nada.
  rejeitado,
}

/// Resposta do motor a um comando.
class ResultadoComando {
  final String eventoId;
  final StatusComando status;

  /// Versão do estado DEPOIS do comando (ou a atual, se nada mudou).
  final int versaoEstado;

  /// Código estável de recusa — ver [ErroComando]. `null` quando aceito.
  final String? codigoErro;

  /// Texto do motor para o jogador ler.
  final String? mensagem;

  /// Consequências relevantes ('tipo' da canastra, 'pegouMorto', 'bateu'...).
  final Map<String, Object?> efeitos;

  ResultadoComando({
    required this.eventoId,
    required this.status,
    required this.versaoEstado,
    this.codigoErro,
    this.mensagem,
    Map<String, Object?> efeitos = const {},
  }) : efeitos = Map.unmodifiable(efeitos);

  bool get ok => status != StatusComando.rejeitado;
  bool get alterouEstado => status == StatusComando.aplicado;

  /// Cópia deste resultado marcada como repetição — o que o motor devolve
  /// quando reconhece um eventoId já processado.
  ResultadoComando comoDuplicado(int versaoAtual) => ResultadoComando(
        eventoId: eventoId,
        status: StatusComando.duplicado,
        versaoEstado: versaoAtual,
        codigoErro: codigoErro,
        mensagem: mensagem,
        efeitos: efeitos,
      );

  Map<String, Object?> toJson() => {
        'eventoId': eventoId,
        'status': status.name,
        'versaoEstado': versaoEstado,
        if (codigoErro != null) 'codigoErro': codigoErro,
        if (mensagem != null) 'mensagem': mensagem,
        if (efeitos.isNotEmpty) 'efeitos': efeitos,
      };

  static ResultadoComando? deJson(Object? raw) {
    if (raw is! Map) return null;
    final eventoId = raw['eventoId'];
    final versao = raw['versaoEstado'];
    if (eventoId is! String || versao is! num) return null;
    final status = StatusComando.values.where((s) => s.name == raw['status']);
    if (status.isEmpty) return null;
    final efeitos = raw['efeitos'];
    return ResultadoComando(
      eventoId: eventoId,
      status: status.first,
      versaoEstado: versao.toInt(),
      codigoErro: raw['codigoErro'] as String?,
      mensagem: raw['mensagem'] as String?,
      efeitos: efeitos is Map ? Map<String, Object?>.from(efeitos) : const {},
    );
  }

  @override
  String toString() =>
      'ResultadoComando(${status.name}, v$versaoEstado, ${codigoErro ?? "ok"})';
}
