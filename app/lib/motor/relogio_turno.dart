// relogio_turno.dart — TEMPO DE JOGADA (OS-01 §7).
//
// Diretriz da OS: "O relógio visual do cliente não deve ser a fonte de verdade
// do tempo da partida." E, por decisão desta ordem de serviço, o cronômetro
// DEFINITIVO e a expiração AUTORITATIVA ficam no servidor Node/Railway.
//
// O que existe aqui, então, é o modelo do tempo — não o dono dele:
//
//   * [RelogioTurno] guarda um PRAZO (instante de fim na linha do tempo do
//     servidor), não um contador. Quem guarda contador perde tempo quando o app
//     vai para segundo plano; quem guarda prazo apenas relê o relógio e acerta
//     sozinho. Isso resolve "aplicativo em background" e "reconexão durante
//     timer" sem nenhuma lógica extra.
//
//   * [SincronizacaoRelogio] traduz o relógio do aparelho para o do servidor.
//     O relógio do celular pode estar minutos errado; sem essa tradução, um
//     prazo do servidor viraria "já expirou" ou "faltam 3 minutos".
//
//   * [ExpiracaoTurno] descreve o que o servidor decidiu fazer quando o tempo
//     acabou. O cliente LÊ; não decide.
//
// Nada neste arquivo dispara timer, toca em rede ou lê o relógio do sistema.
// Todas as funções recebem `agoraMs` de fora — é o que as torna determinísticas
// e testáveis sem esperar tempo real passar.

/// Quem produziu este relógio.
enum FonteRelogio {
  /// Veio do servidor: é a verdade da partida.
  servidor,

  /// Estimado pelo cliente enquanto o servidor não responde. Serve só para a
  /// tela não ficar congelada; nunca para decidir jogada.
  provisorioLocal,
}

/// O prazo do turno corrente.
class RelogioTurno {
  /// Assento a quem o prazo pertence.
  final int assento;

  /// Início do turno em epoch ms, na LINHA DO TEMPO DO SERVIDOR.
  final int inicioMs;

  /// Duração concedida ao turno, em ms.
  final int duracaoMs;

  /// Versão do estado da partida em que este prazo foi emitido. Um relógio de
  /// uma versão antiga é lixo: o turno já virou.
  final int versaoEstado;

  final FonteRelogio fonte;

  const RelogioTurno({
    required this.assento,
    required this.inicioMs,
    required this.duracaoMs,
    required this.versaoEstado,
    this.fonte = FonteRelogio.servidor,
  });

  /// Relógio provisório para a tela não ficar sem nada enquanto o servidor não
  /// mandou o dele. Marcado como não-autoridade de propósito.
  factory RelogioTurno.provisorio({
    required int assento,
    required int inicioMs,
    required int duracaoMs,
    int versaoEstado = -1,
  }) =>
      RelogioTurno(
        assento: assento,
        inicioMs: inicioMs,
        duracaoMs: duracaoMs,
        versaoEstado: versaoEstado,
        fonte: FonteRelogio.provisorioLocal,
      );

  /// Só o relógio do servidor pode embasar uma decisão de partida.
  bool get ehAutoridade => fonte == FonteRelogio.servidor;

  /// Instante do fim do turno, na linha do tempo do servidor.
  int get fimMs => inicioMs + duracaoMs;

  /// Quanto falta, em ms, nunca negativo. [agoraMs] já deve estar na linha do
  /// tempo do servidor (use [SincronizacaoRelogio.agoraNoServidor]).
  int restanteMs(int agoraMs) {
    final r = fimMs - agoraMs;
    return r < 0 ? 0 : r;
  }

  /// Segundos restantes, arredondados para cima — é o que a barra de turno
  /// mostra. 0,2s restante ainda é "1", porque exibir "0" com tempo sobrando
  /// assusta o jogador.
  int restanteSegundos(int agoraMs) => (restanteMs(agoraMs) + 999) ~/ 1000;

  /// Fração decorrida entre 0 e 1 — para a barra de progresso.
  double fracaoDecorrida(int agoraMs) {
    if (duracaoMs <= 0) return 1;
    final d = (agoraMs - inicioMs) / duracaoMs;
    if (d.isNaN) return 1;
    return d < 0 ? 0 : (d > 1 ? 1 : d);
  }

  /// O prazo já passou? Observação importante: `true` aqui NÃO significa que o
  /// turno acabou — significa que o cliente pode parar de esperar uma jogada e
  /// mostrar "aguardando o servidor". Quem encerra o turno é o servidor.
  bool expirou(int agoraMs) => agoraMs >= fimMs;

  /// Este relógio ainda descreve o estado [versaoAtual]?
  bool valeParaVersao(int versaoAtual) =>
      versaoEstado < 0 || versaoEstado == versaoAtual;

  Map<String, Object?> toJson() => {
        'assento': assento,
        'inicioMs': inicioMs,
        'duracaoMs': duracaoMs,
        'versaoEstado': versaoEstado,
        'fonte': fonte.name,
      };

  /// Lê o relógio que veio do servidor. Retorna `null` se a mensagem não trouxer
  /// um prazo utilizável — o chamador então mantém o que já tinha.
  static RelogioTurno? deJson(Object? raw) {
    if (raw is! Map) return null;
    final assento = raw['assento'];
    final inicio = raw['inicioMs'];
    final duracao = raw['duracaoMs'];
    if (assento is! num || inicio is! num || duracao is! num) return null;
    if (duracao <= 0) return null;
    final fonte = raw['fonte'] == FonteRelogio.provisorioLocal.name
        ? FonteRelogio.provisorioLocal
        : FonteRelogio.servidor;
    final versao = raw['versaoEstado'];
    return RelogioTurno(
      assento: assento.toInt(),
      inicioMs: inicio.toInt(),
      duracaoMs: duracao.toInt(),
      versaoEstado: versao is num ? versao.toInt() : -1,
      fonte: fonte,
    );
  }

  @override
  String toString() =>
      'RelogioTurno(assento=$assento, fim=$fimMs, v=$versaoEstado, ${fonte.name})';
}

/// Traduz o relógio do aparelho para o relógio do servidor.
///
/// Método: para cada troca de mensagem sabemos quando enviamos, quando o
/// servidor carimbou e quando recebemos. O carimbo do servidor aconteceu em
/// algum ponto entre o envio e a chegada; o melhor palpite é o meio do caminho.
/// Guardamos a amostra de MENOR ida-e-volta, porque é a menos contaminada por
/// congestionamento — amostras lentas mentem mais.
class SincronizacaoRelogio {
  int _offsetMs = 0;
  int _melhorRttMs = 1 << 30;
  int _amostras = 0;

  /// servidor − dispositivo, em ms.
  int get offsetMs => _offsetMs;

  /// Menor ida-e-volta observada, em ms.
  int get melhorRttMs => _amostras == 0 ? 0 : _melhorRttMs;

  int get amostras => _amostras;

  /// Já temos alguma medida? Enquanto não, o offset é 0 e os prazos do servidor
  /// devem ser tratados como aproximados.
  bool get sincronizado => _amostras > 0;

  /// Registra uma troca. [enviadoEm] e [recebidoEm] são do relógio do
  /// dispositivo; [servidorEm] é o carimbo do servidor.
  void registrarAmostra({
    required int enviadoEm,
    required int recebidoEm,
    required int servidorEm,
  }) {
    final rtt = recebidoEm - enviadoEm;
    if (rtt < 0) return; // relógio do aparelho andou para trás: amostra inútil
    if (_amostras > 0 && rtt > _melhorRttMs) {
      _amostras++;
      return; // amostra pior que a que já temos
    }
    _melhorRttMs = rtt;
    _offsetMs = servidorEm - (enviadoEm + rtt ~/ 2);
    _amostras++;
  }

  /// Converte um instante do dispositivo para a linha do tempo do servidor.
  int agoraNoServidor(int agoraDispositivo) => agoraDispositivo + _offsetMs;

  /// Caminho inverso — útil para agendar um alarme local a partir de um prazo
  /// do servidor.
  int paraODispositivo(int instanteServidor) => instanteServidor - _offsetMs;

  void reiniciar() {
    _offsetMs = 0;
    _melhorRttMs = 1 << 30;
    _amostras = 0;
  }
}

/// O que o servidor fez quando o tempo do turno acabou.
///
/// O cliente recebe isto pronto; não é ele quem escolhe a ação. As opções
/// espelham o que a mesa já faz hoje quando o cronômetro zera (comprar do monte
/// e descartar), mais os desfechos de ausência que só o servidor pode declarar.
enum AcaoPorExpiracao {
  /// Compra do monte e descarta automaticamente — a jogada mínima legal.
  jogadaAutomatica,

  /// Turno passou sem jogada (regra da modalidade, se aplicável).
  turnoPerdido,

  /// O assento passou a ser conduzido por robô.
  substituidoPorRobo,

  /// O servidor encerrou a partida por inviabilidade de continuar.
  partidaEncerrada,
}

/// Registro de uma expiração de turno decidida pelo servidor.
class ExpiracaoTurno {
  final int assento;
  final int rodada;

  /// Instante da decisão, epoch ms do servidor.
  final int emMs;
  final AcaoPorExpiracao acao;

  /// Versão do estado imediatamente após a decisão.
  final int versaoEstado;

  const ExpiracaoTurno({
    required this.assento,
    required this.rodada,
    required this.emMs,
    required this.acao,
    required this.versaoEstado,
  });

  Map<String, Object?> toJson() => {
        'assento': assento,
        'rodada': rodada,
        'emMs': emMs,
        'acao': acao.name,
        'versaoEstado': versaoEstado,
      };

  static ExpiracaoTurno? deJson(Object? raw) {
    if (raw is! Map) return null;
    final assento = raw['assento'];
    final emMs = raw['emMs'];
    if (assento is! num || emMs is! num) return null;
    final acao = AcaoPorExpiracao.values.where((a) => a.name == raw['acao']);
    if (acao.isEmpty) return null;
    final rodada = raw['rodada'];
    final versao = raw['versaoEstado'];
    return ExpiracaoTurno(
      assento: assento.toInt(),
      rodada: rodada is num ? rodada.toInt() : 0,
      emMs: emMs.toInt(),
      acao: acao.first,
      versaoEstado: versao is num ? versao.toInt() : -1,
    );
  }
}
