// motor_partida.dart — A CASCA RESILIENTE DO MOTOR (OS-01 §6, §9, §13, §16).
//
// `Jogo` (mesa.dart) sabe TUDO sobre buraco e NADA sobre rede. Está certo assim:
// as regras não deveriam mudar porque a conexão caiu. O que faltava era a camada
// entre o motor e o mundo — a que responde às perguntas que a partida online faz
// e o jogo de mesa não:
//
//   "esse comando já chegou antes?"          → idempotência por eventoId
//   "sobre qual estado ele foi pensado?"     → versaoEstado / trava otimista
//   "o que este assento pode ver?"           → VisaoAssento
//   "onde exatamente a mão mudou?"           → DiarioPartida
//   "como devolvo o jogador ao lugar certo?" → SnapshotPartida
//
// Ordem das checagens em [aplicar] — a ordem importa e é testada:
//
//   1. envelope estrutural   (COMANDO_INVALIDO)
//   2. eventoId já aplicado  (duplicado — devolve o resultado ORIGINAL)
//   3. mesa bloqueada        (ESTADO_CORROMPIDO)
//   4. versão esperada       (VERSAO_DESATUALIZADA)
//   5. assento válido        (ASSENTO_INVALIDO)
//   6. rodada/partida vivas  (RODADA_ENCERRADA / PARTIDA_ENCERRADA)
//   7. é a vez dele          (FORA_DE_TURNO)
//   8. o motor decide        (REGRA)
//
// O passo 2 vem antes do 4 de propósito: um reenvio depois de queda carrega a
// versão ANTIGA. Se a versão fosse conferida primeiro, o reenvio da jogada que
// já valeu seria recusado como desatualizado e o cliente concluiria que a
// jogada se perdeu — exatamente o bug que esta camada existe para impedir.
//
// Invariante central: comando recusado NÃO altera nada. Nem o estado, nem a
// versão, nem o cache de idempotência.

import '../mesa.dart';
import 'comando_partida.dart';
import 'diagnostico.dart';
import 'presenca.dart';
import 'relogio_turno.dart';
import 'snapshot_partida.dart';
import 'visao_assento.dart';

/// Fonte de tempo injetável.
///
/// Só carimba log e presença — NÃO decide prazo de turno (isso é do servidor,
/// ver `relogio_turno.dart`). É injetável para o teste não depender de esperar
/// tempo real passar.
typedef FonteDeTempo = int Function();

int _tempoDoSistema() => DateTime.now().millisecondsSinceEpoch;

/// Motor de partida com controle de concorrência, idempotência e diagnóstico.
class MotorPartida {
  final String partidaId;
  final Jogo jogo;
  final DiarioPartida diario;
  final MapaPresenca presenca;
  final FonteDeTempo agora;

  /// Quantos eventoIds ficam memorizados. A janela precisa cobrir com folga o
  /// pior caso de reenvio (queda longa + fila do cliente); 256 cobre várias
  /// rodadas inteiras de quatro jogadores.
  final int janelaIdempotencia;

  /// Prazo do turno corrente, como o servidor informou. `null` = o servidor
  /// ainda não mandou.
  RelogioTurno? relogio;

  int _versao;
  final Map<String, ResultadoComando> _aplicados = {};
  final List<String> _ordemAplicados = [];

  MotorPartida({
    required this.partidaId,
    required this.jogo,
    DiarioPartida? diario,
    MapaPresenca? presenca,
    FonteDeTempo? agora,
    this.janelaIdempotencia = 256,
    int versaoInicial = 0,
  })  : diario = diario ?? DiarioPartida(partidaId),
        presenca = presenca ?? MapaPresenca(),
        agora = agora ?? _tempoDoSistema,
        _versao = versaoInicial;

  /// Versão do estado. Sobe em toda mutação aceita e em nada mais.
  int get versaoEstado => _versao;

  /// A mesa está travada pela auditoria de integridade?
  bool get bloqueada => jogo.integridadeErro != null;

  /// eventoIds memorizados, do mais antigo para o mais novo.
  List<String> get eventosAplicados => List.unmodifiable(_ordemAplicados);

  // ---------------------------------------------------------------- comandos

  /// Aplica um comando. Nunca lança: toda falha vira [ResultadoComando].
  ResultadoComando aplicar(ComandoPartida cmd) {
    final ts = agora();

    // 1. envelope
    final problema = cmd.problemaEstrutural;
    if (problema != null) {
      return _recusar(cmd, ErroComando.comandoInvalido, problema, ts);
    }

    // 2. já aplicado? devolve o resultado original SEM refazer nada.
    final anterior = _aplicados[cmd.eventoId];
    if (anterior != null) {
      diario.anotar(
        ts: ts,
        tipo: TipoEvento.duplicado,
        acao: _acao(cmd.tipo),
        assento: cmd.assento,
        rodada: jogo.rodada,
        vez: jogo.vez,
        eventoId: cmd.eventoId,
        versaoAntes: _versao,
        versaoDepois: _versao,
        resultado: StatusComando.duplicado.name,
        dados: {'versaoOriginal': anterior.versaoEstado},
      );
      return anterior.comoDuplicado(_versao);
    }

    // 3. mesa bloqueada
    if (bloqueada) {
      return _recusar(cmd, ErroComando.estadoCorrompido,
          'a mesa está bloqueada para auditoria', ts);
    }

    // 4. trava otimista
    final esperada = cmd.versaoEsperada;
    if (esperada != null && esperada != _versao) {
      return _recusar(
        cmd,
        ErroComando.versaoDesatualizada,
        'a partida já está na versão $_versao (o comando esperava $esperada)',
        ts,
        dados: {'versaoEsperada': esperada},
      );
    }

    // 5. assento
    if (cmd.assento < 0 || cmd.assento > 3) {
      return _recusar(cmd, ErroComando.assentoInvalido, 'assento fora de 0..3', ts);
    }

    // `ordenarMao` só reordena a mão do próprio dono: não depende de turno nem
    // de rodada viva, e não informa nada a ninguém.
    if (cmd.tipo == TipoComando.ordenarMao) {
      final antes = SnapshotPartida.impressaoDeCartas(jogo.maos[cmd.assento]);
      jogo.ordenar(cmd.assento);
      return _aceitar(cmd, ts, efeitos: {'impressaoDaMao': antes});
    }

    // 6. rodada e partida vivas
    if (jogo.encerrada) {
      return _recusar(cmd, ErroComando.partidaEncerrada, 'a partida já acabou', ts);
    }
    if (jogo.rodadaEncerrada) {
      return _recusar(cmd, ErroComando.rodadaEncerrada, 'a rodada já acabou', ts);
    }

    // 7. turno
    if (jogo.vez != cmd.assento) {
      return _recusar(
        cmd,
        ErroComando.foraDeTurno,
        'não é a vez deste assento',
        ts,
        dados: {'vezAtual': jogo.vez},
      );
    }

    // 8. o motor decide
    return _executar(cmd, ts);
  }

  ResultadoComando _executar(ComandoPartida cmd, int ts) {
    switch (cmd.tipo) {
      case TipoComando.comprarMonte:
        final rodadaAntes = jogo.rodadaEncerrada;
        final ok = jogo.comprarMonte(cmd.assento);
        if (ok) return _aceitar(cmd, ts, efeitos: {'origem': 'monte'});
        // O motor devolve `false` em dois casos MUITO diferentes: compra
        // recusada (nada mudou) e rodada encerrada por falta de carta para
        // comprar (o estado mudou). Sem separar os dois, uma rodada terminaria
        // sem a versão subir e os clientes ficariam presos na versão anterior.
        if (jogo.rodadaEncerrada != rodadaAntes) {
          return _aceitar(cmd, ts,
              efeitos: {'rodadaEncerrada': true, 'motivo': 'monte_e_mortos_vazios'});
        }
        return _recusar(cmd, ErroComando.regra, 'não dá para comprar agora', ts);

      case TipoComando.comprarLixo:
        final r = jogo.comprarLixo(cmd.assento, modalidade: jogo.modalidade);
        if (r['ok'] == true) {
          return _aceitar(cmd, ts,
              efeitos: {'origem': 'lixo', 'qtd': r['qtd'] as int? ?? 0});
        }
        return _recusar(cmd, ErroComando.regra, r['erro']?.toString(), ts);

      case TipoComando.baixar:
        final r = jogo.baixar(cmd.assento, cmd.ids.toList());
        if (r['ok'] == true) return _aceitar(cmd, ts, efeitos: _efeitosDe(r));
        return _recusar(cmd, ErroComando.regra, r['erro']?.toString(), ts);

      case TipoComando.estender:
        final r = jogo.estender(cmd.assento, cmd.indiceJogo!, cmd.ids.toList());
        if (r['ok'] == true) return _aceitar(cmd, ts, efeitos: _efeitosDe(r));
        return _recusar(cmd, ErroComando.regra, r['erro']?.toString(), ts);

      case TipoComando.descartar:
        final erro = jogo.descartar(cmd.assento, cmd.ids.first);
        if (erro == null) {
          return _aceitar(cmd, ts, efeitos: {
            'vezAgora': jogo.vez,
            'rodadaEncerrada': jogo.rodadaEncerrada,
          });
        }
        return _recusar(cmd, ErroComando.regra, erro, ts);

      case TipoComando.ordenarMao:
        // Tratado antes das checagens de turno.
        return _recusar(cmd, ErroComando.comandoInvalido, 'caminho inválido', ts);
    }
  }

  static Map<String, Object?> _efeitosDe(Map<String, dynamic> r) => {
        if (r['tipo'] != null) 'tipo': r['tipo'],
        if (r['pegouMorto'] == true) 'pegouMorto': true,
        if (r['bateu'] == true) 'bateu': true,
      };

  ResultadoComando _aceitar(
    ComandoPartida cmd,
    int ts, {
    Map<String, Object?> efeitos = const {},
  }) {
    final antes = _versao;
    _versao++;
    final resultado = ResultadoComando(
      eventoId: cmd.eventoId,
      status: StatusComando.aplicado,
      versaoEstado: _versao,
      efeitos: efeitos,
    );
    _memorizar(cmd.eventoId, resultado);
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.comando,
      acao: _acao(cmd.tipo),
      assento: cmd.assento,
      rodada: jogo.rodada,
      vez: jogo.vez,
      eventoId: cmd.eventoId,
      versaoAntes: antes,
      versaoDepois: _versao,
      resultado: StatusComando.aplicado.name,
      dados: {
        // `qtdCartas`, não `cartas`: o diário censura a chave `cartas` por
        // princípio, e aqui o que interessa é o número, nunca o conteúdo.
        'qtdCartas': cmd.ids.length,
        'impressaoDaMao': DiarioPartida.impressaoDaMao(jogo, cmd.assento),
        'monteRestante': jogo.monte.length,
        'lixoTamanho': jogo.lixo.length,
        ...efeitos,
      },
    );
    // A auditoria do motor roda em cada jogada; se ela reprovou, o log precisa
    // registrar em qual comando a mesa travou — é a primeira pergunta do suporte.
    if (jogo.integridadeErro != null) {
      diario.anotar(
        ts: ts,
        tipo: TipoEvento.integridade,
        acao: 'MESA_BLOQUEADA',
        assento: cmd.assento,
        rodada: jogo.rodada,
        eventoId: cmd.eventoId,
        versaoDepois: _versao,
        erro: jogo.integridadeErro,
      );
    }
    return resultado;
  }

  ResultadoComando _recusar(
    ComandoPartida cmd,
    String codigo,
    String? mensagem,
    int ts, {
    Map<String, Object?> dados = const {},
    String? acao,
  }) {
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.rejeicao,
      acao: acao ?? _acao(cmd.tipo),
      assento: cmd.assento,
      rodada: jogo.rodada,
      vez: jogo.vez,
      eventoId: cmd.eventoId,
      versaoAntes: _versao,
      versaoDepois: _versao,
      resultado: StatusComando.rejeitado.name,
      erro: codigo,
      dados: dados,
    );
    return ResultadoComando(
      eventoId: cmd.eventoId,
      status: StatusComando.rejeitado,
      versaoEstado: _versao,
      codigoErro: codigo,
      mensagem: mensagem,
    );
  }

  void _memorizar(String eventoId, ResultadoComando r) {
    _aplicados[eventoId] = r;
    _ordemAplicados.add(eventoId);
    while (_ordemAplicados.length > janelaIdempotencia) {
      _aplicados.remove(_ordemAplicados.removeAt(0));
    }
  }

  static String _acao(TipoComando t) {
    switch (t) {
      case TipoComando.comprarMonte:
        return 'COMPRAR_MONTE';
      case TipoComando.comprarLixo:
        return 'COMPRAR_LIXO';
      case TipoComando.baixar:
        return 'BAIXAR';
      case TipoComando.estender:
        return 'ESTENDER';
      case TipoComando.descartar:
        return 'DESCARTAR';
      case TipoComando.ordenarMao:
        return 'ORDENAR_MAO';
    }
  }

  // ------------------------------------------------------------------- robô

  /// Conduz o turno do robô no [assento].
  ///
  /// Existe aqui, e não solto, para o robô passar pelas MESMAS travas de turno,
  /// bloqueio e versionamento que um humano — §11 da OS. O robô não recebe o
  /// `Jogo`: ele age através desta porta, igual a todo mundo.
  ResultadoComando conduzirRobo(int assento, {required String eventoId}) {
    final ts = agora();
    final cmd = ComandoPartida(
      eventoId: eventoId,
      assento: assento,
      tipo: TipoComando.comprarMonte, // placeholder: o log usa acao TURNO_ROBO
    );
    ResultadoComando negar(String codigo, String msg) =>
        _recusar(cmd, codigo, msg, ts, acao: 'TURNO_ROBO');

    final anterior = _aplicados[eventoId];
    if (anterior != null) return anterior.comoDuplicado(_versao);
    if (bloqueada) return negar(ErroComando.estadoCorrompido, 'mesa bloqueada');
    if (assento < 0 || assento > 3) {
      return negar(ErroComando.assentoInvalido, 'assento fora de 0..3');
    }
    if (jogo.encerrada) {
      return negar(ErroComando.partidaEncerrada, 'partida encerrada');
    }
    if (jogo.rodadaEncerrada) {
      return negar(ErroComando.rodadaEncerrada, 'rodada encerrada');
    }
    if (jogo.vez != assento) {
      return negar(ErroComando.foraDeTurno, 'não é a vez do robô');
    }
    jogo.botJoga(assento);
    final antes = _versao;
    _versao++;
    final resultado = ResultadoComando(
      eventoId: eventoId,
      status: StatusComando.aplicado,
      versaoEstado: _versao,
      efeitos: {'robo': true, 'vezAgora': jogo.vez},
    );
    _memorizar(eventoId, resultado);
    diario.anotar(
      ts: ts,
      tipo: TipoEvento.comando,
      acao: 'TURNO_ROBO',
      assento: assento,
      rodada: jogo.rodada,
      vez: jogo.vez,
      eventoId: eventoId,
      versaoAntes: antes,
      versaoDepois: _versao,
      resultado: StatusComando.aplicado.name,
      dados: {'monteRestante': jogo.monte.length, 'lixoTamanho': jogo.lixo.length},
    );
    return resultado;
  }

  // -------------------------------------------------------- ciclo da rodada

  /// Apura a rodada encerrada e soma no placar. Idempotente pela proteção do
  /// próprio `Jogo` (`contarPontos` só conta uma vez).
  bool apurarRodada() {
    if (!jogo.rodadaEncerrada) return false;
    final jaTinha = jogo.pontosRodada != null;
    jogo.contarPontos();
    if (jaTinha) return false;
    _versao++;
    diario.anotar(
      ts: agora(),
      tipo: TipoEvento.rodada,
      acao: 'RODADA_APURADA',
      rodada: jogo.rodada,
      versaoDepois: _versao,
      dados: {
        'placarNos': jogo.placar['nos'],
        'placarEles': jogo.placar['eles'],
        'duplaQueBateu': jogo.duplaQueBateu,
        'partidaEncerrada': jogo.encerrada,
      },
    );
    return true;
  }

  /// Redistribui para a próxima rodada, mantendo o placar.
  bool iniciarNovaRodada() {
    if (jogo.encerrada) return false;
    jogo.novaRodada();
    _versao++;
    // Uma rodada nova é um baralho novo: os eventoIds da rodada anterior não
    // têm mais a que se referir, e mantê-los só gastaria a janela.
    _aplicados.clear();
    _ordemAplicados.clear();
    diario.anotar(
      ts: agora(),
      tipo: TipoEvento.rodada,
      acao: 'RODADA_INICIADA',
      rodada: jogo.rodada,
      vez: jogo.vez,
      versaoDepois: _versao,
    );
    return true;
  }

  // ------------------------------------------------------------------ visão

  /// O que [assento] pode ver — ver `visao_assento.dart`.
  Map<String, Object?> visaoDe(int assento) => VisaoAssento.de(
        jogo,
        assento,
        versaoEstado: _versao,
        partidaId: partidaId,
        relogio: relogio,
        presenca: presenca,
      );

  /// Registra o prazo de turno que o servidor informou.
  void aplicarRelogioDoServidor(RelogioTurno? novo) {
    if (novo == null) return;
    relogio = novo;
    diario.anotar(
      ts: agora(),
      tipo: TipoEvento.relogio,
      acao: 'RELOGIO_DO_SERVIDOR',
      assento: novo.assento,
      versaoDepois: _versao,
      dados: {'fimMs': novo.fimMs, 'versaoRelogio': novo.versaoEstado},
    );
  }

  // --------------------------------------------------------------- snapshot

  /// Estado completo, pronto para persistir ou trafegar.
  ///
  /// Inclui a janela de idempotência: sem ela, um servidor que reiniciou
  /// aceitaria de novo comandos que já valeram, e o jogador que estava
  /// reenviando compraria duas vezes.
  Map<String, Object?> snapshot() => {
        'partidaId': partidaId,
        'versaoEstado': _versao,
        'jogo': SnapshotPartida.capturar(jogo),
        'relogio': relogio?.toJson(),
        'idempotencia': [
          for (final id in _ordemAplicados)
            if (_aplicados[id] != null) _aplicados[id]!.toJson(),
        ],
      };

  /// Impressão digital do estado — dois pontos no tempo com a mesma impressão
  /// provam que a partida não mudou entre eles.
  String get impressao => SnapshotPartida.impressao(SnapshotPartida.capturar(jogo));

  /// Reconstrói o motor a partir de um snapshot.
  ///
  /// Propaga [ErroSnapshot] quando o estado é impossível: uma mesa corrompida
  /// não pode ser reaberta em silêncio (§3 da OS).
  static MotorPartida restaurar(
    Map<String, Object?> snapshot, {
    DiarioPartida? diario,
    MapaPresenca? presenca,
    FonteDeTempo? agora,
    int janelaIdempotencia = 256,
  }) {
    final bruto = snapshot['jogo'];
    if (bruto is! Map) {
      throw const ErroSnapshot('ESTRUTURA_INVALIDA', 'bloco "jogo" ausente');
    }
    final jogo = SnapshotPartida.restaurar(Map<String, Object?>.from(bruto));
    final partidaId =
        snapshot['partidaId'] is String ? snapshot['partidaId'] as String : '';
    final versao = snapshot['versaoEstado'];
    final motor = MotorPartida(
      partidaId: partidaId,
      jogo: jogo,
      diario: diario ?? DiarioPartida(partidaId),
      presenca: presenca,
      agora: agora,
      janelaIdempotencia: janelaIdempotencia,
      versaoInicial: versao is num ? versao.toInt() : 0,
    );
    motor.relogio = RelogioTurno.deJson(snapshot['relogio']);
    final idem = snapshot['idempotencia'];
    if (idem is List) {
      for (final e in idem) {
        final r = ResultadoComando.deJson(e);
        if (r != null && r.status == StatusComando.aplicado) {
          motor._memorizar(r.eventoId, r);
        }
      }
    }
    motor.diario.anotar(
      ts: motor.agora(),
      tipo: TipoEvento.snapshot,
      acao: 'PARTIDA_RESTAURADA',
      rodada: jogo.rodada,
      vez: jogo.vez,
      versaoDepois: motor._versao,
      dados: {
        'eventosMemorizados': motor._ordemAplicados.length,
        'mesaBloqueada': jogo.integridadeErro != null,
      },
    );
    return motor;
  }
}
