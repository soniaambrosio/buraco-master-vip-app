// sessao_reconexao.dart — O LADO DO APP NA QUEDA E NA VOLTA (OS-01 §6 e §9).
//
// O que dá errado hoje: o jogador toca em "descartar", o quadro sai, a conexão
// cai antes da resposta. O app não sabe se o servidor recebeu. Se reenviar,
// pode descartar duas vezes; se não reenviar, a jogada some e o turno estoura
// no relógio. As duas saídas são ruins.
//
// A saída correta é reenviar SEM RISCO, e é o que esta sessão faz: todo comando
// carrega um eventoId estável, guardado enquanto não houver confirmação. Na
// volta, reenvia-se o MESMO eventoId. Se o servidor já tinha aplicado, ele
// responde `duplicado` com o resultado original e nada acontece duas vezes
// (ver `MotorPartida.aplicar`). Se não tinha, aplica agora.
//
// A outra metade é não regredir: mensagens de estado chegam fora de ordem
// depois de uma reconexão, e uma visão velha sobrescrevendo a nova faria as
// cartas "voltarem" na tela. [aplicarVisaoDoServidor] só aceita versão MAIOR
// que a já aplicada.
//
// Esta classe é de transporte e ordenação. Ela não julga regra, não conta tempo
// e não decide presença.

import 'comando_partida.dart';
import 'diagnostico.dart';
import 'motor_partida.dart' show FonteDeTempo;
import 'presenca.dart';
import 'relogio_turno.dart';

/// Gera eventoIds estáveis e únicos dentro de uma sessão.
///
/// Formato `<prefixo>-<n>`. O prefixo deve ser único por sessão de jogador
/// (ex.: uid abreviado + instante de entrada na mesa) — quem o fornece é quem
/// tem essa informação. Sem sorteio: o teste precisa de ids previsíveis.
class GeradorEventoId {
  final String prefixo;
  int _n = 0;

  GeradorEventoId(this.prefixo) : assert(prefixo != '');

  String proximo() => '$prefixo-${++_n}';

  int get emitidos => _n;
}

/// Um comando enviado e ainda sem confirmação.
class ComandoPendente {
  final ComandoPartida comando;
  final int primeiroEnvioMs;
  int ultimoEnvioMs;
  int tentativas;

  ComandoPendente(this.comando, int emMs)
      : primeiroEnvioMs = emMs,
        ultimoEnvioMs = emMs,
        tentativas = 1;
}

/// Por que uma visão do servidor foi descartada.
enum MotivoDescarte { versaoAntiga, versaoRepetida, formatoInvalido }

/// Sessão de partida do lado do cliente.
class SessaoReconexao {
  final String partidaId;
  final GeradorEventoId ids;
  final DiarioPartida diario;
  final FonteDeTempo agora;

  /// Depois de quantas tentativas o app para de reenviar e passa a pedir o
  /// estado inteiro. Reenviar para sempre esconde um problema real do servidor.
  final int maxTentativas;

  /// Assento do jogador nesta mesa, como o servidor informou.
  int? meuAssento;

  /// Última visão aceita.
  Map<String, Object?>? visao;

  /// Versão da última visão aceita. `-1` = nunca recebeu estado.
  int versaoAplicada = -1;

  /// Prazo do turno, como veio na última visão.
  RelogioTurno? relogio;

  /// Presença dos assentos, como veio na última visão.
  final MapaPresenca presenca;

  /// Tradução entre o relógio do aparelho e o do servidor.
  final SincronizacaoRelogio sincronia = SincronizacaoRelogio();

  final Map<String, ComandoPendente> _pendentes = {};

  /// Comandos que estouraram [maxTentativas]. A UI deve avisar o jogador e
  /// pedir o estado completo ao servidor em vez de insistir.
  final List<ComandoPartida> desistidos = [];

  /// A sessão está esperando a visão INTEGRAL de retomada?
  ///
  /// Nasce `true` e volta a `true` a cada queda. Enquanto for `true`, nenhum
  /// comando pendente é liberado para reenvio — ver [comandosParaReenviar].
  bool _aguardandoRetomada = true;

  SessaoReconexao({
    required this.partidaId,
    required this.ids,
    DiarioPartida? diario,
    MapaPresenca? presenca,
    FonteDeTempo? agora,
    this.maxTentativas = 5,
  })  : diario = diario ?? DiarioPartida(partidaId),
        presenca = presenca ?? MapaPresenca(),
        agora = agora ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Comandos aguardando confirmação, na ordem em que foram enviados.
  List<ComandoPartida> get pendentes {
    final l = _pendentes.values.toList()
      ..sort((a, b) => a.primeiroEnvioMs.compareTo(b.primeiroEnvioMs));
    return List.unmodifiable([for (final p in l) p.comando]);
  }

  bool get temPendencias => _pendentes.isNotEmpty;

  /// A sessão está travada esperando a retomada integral.
  bool get aguardandoRetomada => _aguardandoRetomada;

  /// A sessão pode jogar: já recebeu a retomada e conhece a versão atual.
  ///
  /// Ter `versaoAplicada >= 0` NÃO basta — depois de uma queda, a versão que a
  /// sessão guarda é a de antes do apagão, e agir sobre ela é agir sobre o
  /// passado.
  bool get prontaParaJogar => !_aguardandoRetomada && versaoAplicada >= 0;

  // ------------------------------------------------------------------ envio

  /// Marca um comando como enviado e passa a rastreá-lo.
  ///
  /// Devolve o próprio comando para encadear com o envio pelo WebSocket.
  ComandoPartida registrarEnvio(ComandoPartida cmd) {
    final ts = agora();
    final ja = _pendentes[cmd.eventoId];
    if (ja != null) {
      ja.tentativas++;
      ja.ultimoEnvioMs = ts;
    } else {
      _pendentes[cmd.eventoId] = ComandoPendente(cmd, ts);
    }
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.comando,
      acao: 'ENVIADO',
      assento: cmd.assento,
      eventoId: cmd.eventoId,
      versaoAntes: versaoAplicada,
      dados: {
        'comando': cmd.tipo.name,
        'tentativa': _pendentes[cmd.eventoId]!.tentativas,
      },
    );
    return cmd;
  }

  /// Cria um comando já com eventoId novo e a versão que o cliente enxerga.
  ///
  /// A trava otimista sai daqui de graça: o comando nasce amarrado ao estado
  /// que o jogador tinha na tela quando tocou.
  ComandoPartida novoComando({
    required int assento,
    required TipoComando tipo,
    List<String> cartas = const [],
    int? indiceJogo,
    bool travarNaVersao = true,
  }) =>
      ComandoPartida(
        eventoId: ids.proximo(),
        assento: assento,
        tipo: tipo,
        ids: cartas,
        indiceJogo: indiceJogo,
        versaoEsperada:
            travarNaVersao && versaoAplicada >= 0 ? versaoAplicada : null,
      );

  /// Registra a resposta do servidor a um comando.
  void confirmar(ResultadoComando r) {
    final pendente = _pendentes.remove(r.eventoId);
    diario.anotar(
      ts: agora(),
      tipo: r.status == StatusComando.duplicado
          ? TipoEvento.duplicado
          : TipoEvento.comando,
      acao: 'CONFIRMADO',
      assento: pendente?.comando.assento,
      eventoId: r.eventoId,
      versaoDepois: r.versaoEstado,
      resultado: r.status.name,
      erro: r.codigoErro,
      dados: {
        'tentativas': pendente?.tentativas ?? 0,
        if (pendente != null) 'comando': pendente.comando.tipo.name,
      },
    );
  }

  // ------------------------------------------------------- estado que chega

  /// Aplica a visão INTEGRAL de retomada — a resposta do servidor ao `retomar`.
  ///
  /// É a única entrada que destrava o reenvio dos pendentes, e a única que
  /// aceita a MESMA versão que a sessão já tinha. Aceitar a versão igual é
  /// necessário, não é frouxidão: é perfeitamente possível que nada tenha
  /// mudado durante a queda — ninguém jogou, o turno não virou —, e recusar
  /// essa resposta deixaria a sessão travada para sempre esperando uma versão
  /// maior que nunca virá.
  ///
  /// Versão realmente antiga continua sendo recusada, mesmo aqui.
  bool aplicarRetomada(Object? bruta) =>
      aplicarVisaoDoServidor(bruta, retomada: true);

  /// Aceita (ou descarta) uma visão vinda do servidor.
  ///
  /// Retorna `true` quando a visão foi adotada. Descarta — com registro no
  /// diário — versões menores, e também versões repetidas quando NÃO se trata
  /// de retomada: depois de uma reconexão é normal chegarem mensagens fora de
  /// ordem, e deixar uma visão velha vencer faria a carta "voltar" na tela.
  ///
  /// Uma visão comum que chega enquanto a sessão espera retomada é aplicada
  /// (é estado mais novo), mas **não destrava** o reenvio: só a retomada
  /// integral faz isso.
  bool aplicarVisaoDoServidor(Object? bruta, {bool retomada = false}) {
    final ts = agora();
    if (bruta is! Map) {
      _descartar(ts, MotivoDescarte.formatoInvalido, null);
      return false;
    }
    final nova = Map<String, Object?>.from(bruta);
    final v = nova['versaoEstado'];
    if (v is! num) {
      _descartar(ts, MotivoDescarte.formatoInvalido, null);
      return false;
    }
    final versao = v.toInt();
    if (versao < versaoAplicada) {
      _descartar(ts, MotivoDescarte.versaoAntiga, versao);
      return false;
    }
    if (versao == versaoAplicada && visao != null && !retomada) {
      _descartar(ts, MotivoDescarte.versaoRepetida, versao);
      return false;
    }

    final anterior = visao?['impressaoDaMao'];
    visao = nova;
    versaoAplicada = versao;
    final assento = nova['assento'];
    if (assento is num) meuAssento = assento.toInt();
    relogio = RelogioTurno.deJson(nova['relogio']);

    // Presença: primeiro os LIMIARES do servidor, depois os estados. A ordem
    // importa — adotar os estados sob a régua antiga faria a próxima
    // reavaliação local reclassificar tudo de novo.
    final p = nova['presenca'];
    var parametrosAdotados = false;
    if (p is Map) {
      parametrosAdotados = presenca.adotarParametros(
        ParametrosPresenca.deJson(p['parametros'], base: presenca.parametros),
      );
      presenca.aplicarDoServidor(p['assentos']);
    }

    if (retomada) _aguardandoRetomada = false;

    final impressao = nova['impressaoDaMao'];
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.reconexao,
      acao: retomada ? 'RETOMADA_APLICADA' : 'VISAO_APLICADA',
      assento: meuAssento,
      rodada: nova['rodada'] is num ? (nova['rodada'] as num).toInt() : null,
      vez: nova['vez'] is num ? (nova['vez'] as num).toInt() : null,
      versaoDepois: versao,
      dados: {
        'impressaoDaMao': impressao is String ? impressao : null,
        // Quando a impressão muda sem comando nosso no meio, é exatamente o
        // caso "voltei e minha mão estava diferente" — fica marcado no log.
        'maoMudou': anterior is String && impressao is String && anterior != impressao,
        'mesaBloqueada': nova['mesaBloqueada'] == true,
        if (retomada) 'pendentesLiberados': _pendentes.length,
        if (parametrosAdotados) 'parametrosPresencaAdotados': true,
      },
    );
    return true;
  }

  void _descartar(int ts, MotivoDescarte motivo, int? versao) {
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.reconexao,
      acao: 'VISAO_DESCARTADA',
      assento: meuAssento,
      versaoAntes: versaoAplicada,
      erro: motivo.name,
      dados: {'versaoRecebida': versao},
    );
  }

  // ------------------------------------------------------------- reconexão

  /// A conexão caiu.
  ///
  /// Não descarta pendente nenhum — eles continuam válidos justamente porque
  /// têm eventoId. Mas TRAVA a sessão: a partir daqui, nada é reenviado até a
  /// retomada integral chegar.
  void aoCair() {
    _aguardandoRetomada = true;
    diario.anotar(
      ts: agora(),
      tipo: TipoEvento.reconexao,
      acao: 'CONEXAO_PERDIDA',
      assento: meuAssento,
      versaoAntes: versaoAplicada,
      dados: {'pendentes': _pendentes.length},
    );
  }

  /// A conexão voltou.
  ///
  /// **Não libera nada.** Só registra que a sessão está de volta e continua
  /// travada esperando a retomada. O app deve enviar `retomar` e, quando a
  /// resposta chegar, passá-la por [aplicarRetomada]; só então
  /// [comandosParaReenviar] devolve a fila.
  ///
  /// Essa separação é o ponto: reenviar comando sem saber a versão atual é
  /// precisamente o que produz jogada duplicada, e um método que devolvesse a
  /// fila aqui convidaria a esse erro.
  void aoReconectar() {
    _aguardandoRetomada = true;
    diario.anotar(
      ts: agora(),
      tipo: TipoEvento.reconexao,
      acao: 'RECONECTADO',
      assento: meuAssento,
      versaoAntes: versaoAplicada,
      dados: {
        'pendentes': _pendentes.length,
        'aguardandoRetomada': true,
        'pedirEstadoCompleto': true,
      },
    );
  }

  /// Comandos liberados para reenvio, com o MESMO eventoId — o que torna o
  /// reenvio inofensivo se o servidor já os tiver aplicado.
  ///
  /// Devolve **lista vazia** enquanto [aguardandoRetomada] for verdadeiro.
  /// Comandos que já passaram de [maxTentativas] saem da fila e vão para
  /// [desistidos]: insistir neles esconderia um problema do servidor.
  List<ComandoPartida> comandosParaReenviar() {
    final ts = agora();
    if (_aguardandoRetomada) {
      diario.anotar(
        ts: ts,
        tipo: TipoEvento.reconexao,
        acao: 'REENVIO_BLOQUEADO',
        assento: meuAssento,
        versaoAntes: versaoAplicada,
        erro: 'AGUARDANDO_RETOMADA',
        dados: {'pendentes': _pendentes.length},
      );
      return const [];
    }
    final reenviar = <ComandoPartida>[];
    for (final p in pendentes) {
      final estado = _pendentes[p.eventoId]!;
      if (estado.tentativas >= maxTentativas) {
        _pendentes.remove(p.eventoId);
        desistidos.add(p);
        continue;
      }
      estado.tentativas++;
      estado.ultimoEnvioMs = ts;
      reenviar.add(p);
    }
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.reconexao,
      acao: 'REENVIO_LIBERADO',
      assento: meuAssento,
      versaoAntes: versaoAplicada,
      dados: {'reenviar': reenviar.length, 'desistidos': desistidos.length},
    );
    return List.unmodifiable(reenviar);
  }

  /// O app precisa pedir a retomada completa ao servidor?
  ///
  /// Verdadeiro enquanto a sessão estiver travada, enquanto nunca tiver
  /// recebido estado, ou quando desistiu de algum comando e portanto não sabe
  /// mais se ele valeu.
  bool get precisaRetomadaCompleta =>
      _aguardandoRetomada || versaoAplicada < 0 || desistidos.isNotEmpty;

  /// Descarta os comandos abandonados depois que a retomada fechou o buraco.
  void retomadaConcluida() => desistidos.clear();

  // ---------------------------------------------------------------- relógio

  /// Segundos restantes do turno para a barra de tempo, já traduzidos para a
  /// linha do tempo do servidor. `null` quando não há prazo conhecido.
  int? segundosRestantes(int agoraNoDispositivo) {
    final r = relogio;
    if (r == null) return null;
    return r.restanteSegundos(sincronia.agoraNoServidor(agoraNoDispositivo));
  }

  /// Registra uma troca com o servidor para calibrar o relógio.
  void calibrarRelogio({
    required int enviadoEm,
    required int recebidoEm,
    required int servidorEm,
  }) =>
      sincronia.registrarAmostra(
        enviadoEm: enviadoEm,
        recebidoEm: recebidoEm,
        servidorEm: servidorEm,
      );
}
