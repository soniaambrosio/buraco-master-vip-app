// presenca.dart — PRESENÇA, CONEXÃO, ABANDONO E SUBSTITUIÇÃO (OS-01 §8 e §10).
//
// Fronteira desta ordem de serviço, respeitada linha a linha neste arquivo:
//
//   O CLIENTE pode DESCONFIAR. Só o SERVIDOR pode DECLARAR.
//
// Ou seja: o app calcula, a partir do último heartbeat, se um assento parece
// oscilando ou sumido — e isso serve para a tela mostrar "conexão instável",
// esmaecer o avatar, avisar o parceiro. O app NUNCA conclui que alguém
// abandonou, nunca troca ninguém por robô e nunca encerra partida. Essas três
// decisões pertencem ao servidor Node/Railway, que é quem enxerga todos os
// jogadores e é a autoridade da partida.
//
// A trava dessa fronteira é mecânica, não é comentário: [PoliticaPresenca]
// simplesmente não sabe produzir os estados terminais — ver [EstadoPresenca].
//
// Também aqui vale o princípio do §8 da OS: "evitar declarar abandono
// imediatamente em pequenas oscilações de internet". Por isso a escada de
// tolerância tem um degrau intermediário (`instavel`) antes de `ausente`.

/// Situação de um assento.
enum EstadoPresenca {
  /// Heartbeat recente. Tudo normal.
  online,

  /// O heartbeat atrasou além do esperado, mas ainda dentro da tolerância de
  /// oscilação. A partida segue: ninguém é penalizado por um túnel de metrô.
  instavel,

  /// Sem sinal há tempo demais para ser oscilação. O servidor pode começar a
  /// contar o prazo de abandono a partir daqui.
  ausente,

  /// TERMINAL — só o servidor declara. O assento saiu da partida.
  abandonou,

  /// TERMINAL — só o servidor declara. O assento está sendo conduzido por robô.
  substituidoPorRobo,
}

extension EstadoPresencaX on EstadoPresenca {
  /// Estados que apenas o servidor pode declarar.
  bool get ehTerminal =>
      this == EstadoPresenca.abandonou ||
      this == EstadoPresenca.substituidoPorRobo;

  /// O assento ainda está jogando por conta própria?
  bool get jogandoSozinho =>
      this == EstadoPresenca.online || this == EstadoPresenca.instavel;
}

/// Degraus de tolerância. Os valores são o ponto de partida acordado com a
/// mesa; o servidor manda os dele em `parametrosPresenca` e o cliente adota,
/// para as duas pontas contarem igual.
class ParametrosPresenca {
  /// De quanto em quanto tempo o cliente envia heartbeat.
  final int intervaloHeartbeatMs;

  /// Silêncio acima disto vira `instavel`.
  final int toleranciaInstavelMs;

  /// Silêncio acima disto vira `ausente`.
  final int toleranciaAusenteMs;

  /// A partir de `ausente`, quanto o SERVIDOR espera antes de considerar
  /// abandono. O cliente só carrega o número para exibir a contagem — não é ele
  /// quem aplica.
  final int prazoAbandonoMs;

  const ParametrosPresenca({
    this.intervaloHeartbeatMs = 5000,
    this.toleranciaInstavelMs = 12000,
    this.toleranciaAusenteMs = 45000,
    this.prazoAbandonoMs = 180000,
  });

  static const ParametrosPresenca padrao = ParametrosPresenca();

  Map<String, Object?> toJson() => {
        'intervaloHeartbeatMs': intervaloHeartbeatMs,
        'toleranciaInstavelMs': toleranciaInstavelMs,
        'toleranciaAusenteMs': toleranciaAusenteMs,
        'prazoAbandonoMs': prazoAbandonoMs,
      };

  /// A escada faz sentido?
  ///
  /// Se `instavel >= ausente`, o degrau intermediário desaparece e um jogador
  /// com oscilação leve seria classificado direto como ausente — exatamente o
  /// que o §8 proíbe. Parâmetros incoerentes são pior que parâmetros ausentes.
  bool get coerente =>
      intervaloHeartbeatMs > 0 &&
      toleranciaInstavelMs > 0 &&
      toleranciaAusenteMs > toleranciaInstavelMs &&
      prazoAbandonoMs >= 0;

  /// Lê os parâmetros que o servidor mandou.
  ///
  /// [base] é o que já está em uso — e é para onde a leitura cai quando o
  /// campo falta. Isso é deliberado: uma mensagem com um único campo não pode
  /// zerar os outros três de volta ao padrão de fábrica. E se o conjunto final
  /// for incoerente, [base] é devolvido inteiro: **nunca se troca uma
  /// configuração válida por lixo.**
  static ParametrosPresenca deJson(Object? raw, {ParametrosPresenca base = padrao}) {
    if (raw is! Map) return base;
    int ler(String k, int padraoValor) {
      final v = raw[k];
      return v is num && v > 0 ? v.toInt() : padraoValor;
    }

    final lido = ParametrosPresenca(
      intervaloHeartbeatMs: ler('intervaloHeartbeatMs', base.intervaloHeartbeatMs),
      toleranciaInstavelMs: ler('toleranciaInstavelMs', base.toleranciaInstavelMs),
      toleranciaAusenteMs: ler('toleranciaAusenteMs', base.toleranciaAusenteMs),
      prazoAbandonoMs: ler('prazoAbandonoMs', base.prazoAbandonoMs),
    );
    return lido.coerente ? lido : base;
  }

  @override
  bool operator ==(Object other) =>
      other is ParametrosPresenca &&
      other.intervaloHeartbeatMs == intervaloHeartbeatMs &&
      other.toleranciaInstavelMs == toleranciaInstavelMs &&
      other.toleranciaAusenteMs == toleranciaAusenteMs &&
      other.prazoAbandonoMs == prazoAbandonoMs;

  @override
  int get hashCode => Object.hash(intervaloHeartbeatMs, toleranciaInstavelMs,
      toleranciaAusenteMs, prazoAbandonoMs);
}

/// Classificação de presença a partir do silêncio observado.
///
/// Função pura e sem estado. Por construção ela devolve apenas
/// `online | instavel | ausente` — os estados terminais não são alcançáveis
/// daqui, e é isso que impede o app de declarar abandono por conta própria.
class PoliticaPresenca {
  final ParametrosPresenca parametros;
  const PoliticaPresenca([this.parametros = ParametrosPresenca.padrao]);

  /// [ultimoHeartbeatMs] e [agoraMs] na linha do tempo do servidor.
  EstadoPresenca classificar({
    required int ultimoHeartbeatMs,
    required int agoraMs,
  }) {
    final silencio = agoraMs - ultimoHeartbeatMs;
    if (silencio >= parametros.toleranciaAusenteMs) return EstadoPresenca.ausente;
    if (silencio >= parametros.toleranciaInstavelMs) return EstadoPresenca.instavel;
    return EstadoPresenca.online;
  }

  /// Quanto falta, em ms, para o servidor poder considerar abandono. Só existe
  /// para a tela mostrar a contagem ao parceiro; não aplica nada.
  int msAteAbandonoPossivel({
    required int ultimoHeartbeatMs,
    required int agoraMs,
  }) {
    final limite = ultimoHeartbeatMs +
        parametros.toleranciaAusenteMs +
        parametros.prazoAbandonoMs;
    final falta = limite - agoraMs;
    return falta < 0 ? 0 : falta;
  }
}

/// Presença de um assento, como o cliente a conhece.
class PresencaAssento {
  final int assento;
  final EstadoPresenca estado;

  /// Último heartbeat conhecido, epoch ms do servidor.
  final int ultimoHeartbeatMs;

  /// Desde quando o assento está neste [estado], epoch ms do servidor.
  final int desdeMs;

  /// O estado veio do servidor (autoridade) ou é palpite local para a tela?
  final bool doServidor;

  const PresencaAssento({
    required this.assento,
    required this.estado,
    required this.ultimoHeartbeatMs,
    required this.desdeMs,
    this.doServidor = false,
  });

  PresencaAssento copiarCom({
    EstadoPresenca? estado,
    int? ultimoHeartbeatMs,
    int? desdeMs,
    bool? doServidor,
  }) =>
      PresencaAssento(
        assento: assento,
        estado: estado ?? this.estado,
        ultimoHeartbeatMs: ultimoHeartbeatMs ?? this.ultimoHeartbeatMs,
        desdeMs: desdeMs ?? this.desdeMs,
        doServidor: doServidor ?? this.doServidor,
      );

  Map<String, Object?> toJson() => {
        'assento': assento,
        'estado': estado.name,
        'ultimoHeartbeatMs': ultimoHeartbeatMs,
        'desdeMs': desdeMs,
        'doServidor': doServidor,
      };

  static PresencaAssento? deJson(Object? raw) {
    if (raw is! Map) return null;
    final assento = raw['assento'];
    if (assento is! num) return null;
    final estados = EstadoPresenca.values.where((e) => e.name == raw['estado']);
    if (estados.isEmpty) return null;
    final hb = raw['ultimoHeartbeatMs'];
    final desde = raw['desdeMs'];
    return PresencaAssento(
      assento: assento.toInt(),
      estado: estados.first,
      ultimoHeartbeatMs: hb is num ? hb.toInt() : 0,
      desdeMs: desde is num ? desde.toInt() : 0,
      doServidor: true,
    );
  }
}

/// Presença dos quatro assentos.
///
/// Duas entradas, com pesos deliberadamente diferentes:
///   * [aplicarDoServidor] — verdade. Sobrescreve tudo, inclusive terminais.
///   * [reavaliarLocalmente] — palpite. Só mexe em assentos que o servidor não
///     declarou terminais, e só entre `online`/`instavel`/`ausente`.
class MapaPresenca {
  ParametrosPresenca _parametros;
  PoliticaPresenca _politica;
  final Map<int, PresencaAssento> _porAssento = {};

  MapaPresenca({ParametrosPresenca parametros = ParametrosPresenca.padrao})
      : _parametros = parametros,
        _politica = PoliticaPresenca(parametros);

  /// Limiares em uso. Começam nos padrões e passam a ser os do servidor assim
  /// que ele os informa — ver [adotarParametros].
  ParametrosPresenca get parametros => _parametros;

  /// AUTORIDADE. Adota os limiares que o servidor mandou.
  ///
  /// Sem isto, o cliente pintaria "instável" num relógio e o servidor contaria
  /// ausência noutro: as duas pontas mostrariam histórias diferentes do mesmo
  /// jogador. Devolve `true` quando algo mudou de fato.
  bool adotarParametros(ParametrosPresenca novos) {
    if (!novos.coerente || novos == _parametros) return false;
    _parametros = novos;
    _politica = PoliticaPresenca(novos);
    return true;
  }

  PresencaAssento? operator [](int assento) => _porAssento[assento];

  List<PresencaAssento> get todos {
    final l = _porAssento.values.toList()
      ..sort((a, b) => a.assento - b.assento);
    return List.unmodifiable(l);
  }

  EstadoPresenca estadoDe(int assento) =>
      _porAssento[assento]?.estado ?? EstadoPresenca.online;

  /// AUTORIDADE. Substitui a presença dos assentos informados pelo servidor.
  void aplicarDoServidor(Object? lista) {
    if (lista is! List) return;
    for (final item in lista) {
      final p = PresencaAssento.deJson(item);
      if (p != null) _porAssento[p.assento] = p;
    }
  }

  /// Registra um heartbeat observado (do próprio jogador ou repassado pelo
  /// servidor). Um heartbeat NÃO ressuscita um assento que o servidor declarou
  /// terminal — só o servidor desfaz o que o servidor declarou.
  void registrarHeartbeat(int assento, int emMs) {
    final atual = _porAssento[assento];
    if (atual != null && atual.estado.ehTerminal) return;
    final voltou = atual == null || atual.estado != EstadoPresenca.online;
    _porAssento[assento] = PresencaAssento(
      assento: assento,
      estado: EstadoPresenca.online,
      ultimoHeartbeatMs: emMs,
      desdeMs: voltou ? emMs : (atual.desdeMs),
      doServidor: false,
    );
  }

  /// PALPITE, para a tela. Reclassifica os assentos não-terminais com base no
  /// silêncio. Nunca produz `abandonou` nem `substituidoPorRobo`.
  void reavaliarLocalmente(int agoraMs) {
    for (final assento in _porAssento.keys.toList()) {
      final atual = _porAssento[assento]!;
      if (atual.estado.ehTerminal) continue;
      final novo = _politica.classificar(
        ultimoHeartbeatMs: atual.ultimoHeartbeatMs,
        agoraMs: agoraMs,
      );
      if (novo == atual.estado) continue;
      _porAssento[assento] = atual.copiarCom(
        estado: novo,
        desdeMs: agoraMs,
        doServidor: false,
      );
    }
  }

  /// Quanto falta para o servidor PODER declarar abandono neste assento.
  /// Informativo — ver [PoliticaPresenca.msAteAbandonoPossivel].
  int msAteAbandonoPossivel(int assento, int agoraMs) {
    final atual = _porAssento[assento];
    if (atual == null || atual.estado.ehTerminal) return 0;
    return _politica.msAteAbandonoPossivel(
      ultimoHeartbeatMs: atual.ultimoHeartbeatMs,
      agoraMs: agoraMs,
    );
  }

  Map<String, Object?> toJson() => {
        'parametros': _parametros.toJson(),
        'assentos': [for (final p in todos) p.toJson()],
      };
}

/// Por que um assento saiu da partida.
enum MotivoSaida {
  /// O jogador pediu para sair.
  voluntario,

  /// O servidor declarou ausência prolongada.
  ausenciaProlongada,

  /// Decisão administrativa/antifraude do servidor.
  removidoPeloServidor,

  /// A partida não tinha como continuar (ex.: mesa esvaziou).
  inviabilidadeDaPartida,
}

/// Registro de saída, produzido pelo SERVIDOR e apenas lido pelo app.
///
/// A ordem de serviço proíbe inventar regra: por isso não há penalidade
/// calculada aqui. [penalidadePontos] carrega o que o servidor aplicou, e
/// `null` significa "o servidor não informou" — não significa zero.
class RegistroAbandono {
  final String partidaId;
  final int assento;
  final MotivoSaida motivo;

  /// Epoch ms do servidor.
  final int emMs;
  final int rodada;

  /// O assento passou a ser conduzido por robô depois da saída?
  final bool substituidoPorRobo;

  /// O jogador ainda pode voltar e retomar o assento?
  final bool retornoPermitido;

  /// Penalidade aplicada pelo servidor, se houver e se informada.
  final int? penalidadePontos;

  const RegistroAbandono({
    required this.partidaId,
    required this.assento,
    required this.motivo,
    required this.emMs,
    required this.rodada,
    this.substituidoPorRobo = false,
    this.retornoPermitido = false,
    this.penalidadePontos,
  });

  Map<String, Object?> toJson() => {
        'partidaId': partidaId,
        'assento': assento,
        'motivo': motivo.name,
        'emMs': emMs,
        'rodada': rodada,
        'substituidoPorRobo': substituidoPorRobo,
        'retornoPermitido': retornoPermitido,
        'penalidadePontos': penalidadePontos,
      };

  static RegistroAbandono? deJson(Object? raw) {
    if (raw is! Map) return null;
    final assento = raw['assento'];
    final emMs = raw['emMs'];
    if (assento is! num || emMs is! num) return null;
    final motivos = MotivoSaida.values.where((m) => m.name == raw['motivo']);
    if (motivos.isEmpty) return null;
    final rodada = raw['rodada'];
    final pen = raw['penalidadePontos'];
    return RegistroAbandono(
      partidaId: raw['partidaId'] is String ? raw['partidaId'] as String : '',
      assento: assento.toInt(),
      motivo: motivos.first,
      emMs: emMs.toInt(),
      rodada: rodada is num ? rodada.toInt() : 0,
      substituidoPorRobo: raw['substituidoPorRobo'] == true,
      retornoPermitido: raw['retornoPermitido'] == true,
      penalidadePontos: pen is num ? pen.toInt() : null,
    );
  }
}
