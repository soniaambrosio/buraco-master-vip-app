// observabilidade.dart — as quatro portas por onde uma falha entra.
//
//   1. FlutterError.onError                  → erro síncrono do framework
//   2. PlatformDispatcher.instance.onError   → erro de plataforma/dispatcher
//   3. runZonedGuarded                       → erro assíncrono não tratado
//   4. registrarFalha(...)                   → chamada explícita do app
//
// Três invariantes valem em TODAS elas, e cada uma tem teste próprio:
//
//   · O erro original nunca é mascarado. O handler anterior (por padrão o
//     `presentError`, que imprime no console) continua sendo chamado depois
//     de reportarmos. Instalar observabilidade não pode tornar o app mais
//     difícil de depurar do que era sem ela.
//   · Nada que aconteça no coletor escapa. Toda chamada de coletor passa por
//     `_protegido`. Um coletor que explode vira um contador, não um crash —
//     senão o remédio derruba o app que ele veio observar.
//   · O mesmo defeito não é emitido duas vezes. Framework e zona reportam o
//     mesmo erro em vários cenários; a janela de deduplicação corta isso.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'coletor.dart';
import 'evento_falha.dart';
import 'identidade_build.dart';
import 'redacao.dart';
import 'trilha_operacional.dart';

/// Fachada única da observabilidade. O app inteiro fala só com
/// `Observabilidade.instancia`.
class Observabilidade {
  Observabilidade._({
    required this.identidade,
    required ColetorDeFalhas coletor,
    required this.trilha,
    required DateTime Function() relogio,
    required this.janelaDeduplicacao,
    required this.redator,
  })  : _coletor = coletor,
        _relogio = relogio;

  /// Instância corrente. Antes de `instalar`, é uma instância inerte: chamar
  /// qualquer coisa nela é seguro e não faz nada.
  static Observabilidade instancia = Observabilidade._(
    identidade: const IdentidadeBuild(
      versionName: '',
      versionCode: 0,
      sha: '',
      branch: '',
      ambiente: AmbienteBuild.desenvolvimento,
    ),
    coletor: const ColetorNulo(),
    trilha: TrilhaOperacional(),
    relogio: DateTime.now,
    janelaDeduplicacao: const Duration(seconds: 10),
    redator: const Redator(),
  );

  final IdentidadeBuild identidade;
  final TrilhaOperacional trilha;
  final Duration janelaDeduplicacao;
  final Redator redator;

  ColetorDeFalhas _coletor;
  final DateTime Function() _relogio;

  /// Coletor efetivamente em uso. Em debug/teste, ou quando o coletor real
  /// recusou iniciar, é o [ColetorNulo].
  ColetorDeFalhas get coletor => _coletor;

  bool _ativo = false;
  bool get ativo => _ativo;

  /// Quantas vezes o coletor lançou. Diagnóstico do próprio diagnóstico.
  int falhasDoColetor = 0;

  /// Quantos eventos foram suprimidos por serem repetição.
  int eventosDeduplicados = 0;

  // Handlers que existiam antes de nós. Guardados para não mascarar nada e
  // para poder desinstalar por completo entre testes.
  FlutterExceptionHandler? _framewokAnterior;
  bool Function(Object, StackTrace)? _plataformaAnterior;
  bool _hooksInstalados = false;

  final Map<String, DateTime> _vistos = <String, DateTime>{};
  static const int _tetoDeAssinaturas = 128;

  /// Coletor real que ainda não pôde iniciar (o Firebase não subiu).
  ColetorDeFalhas? _coletorPendente;

  /// Eventos ocorridos antes do coletor existir.
  ///
  /// Pequeno de propósito: a janela entre instalar as portas e o Firebase
  /// subir é de milissegundos, e o que interessa dela é o começo — se algo
  /// quebrar aí, quebra logo. Guardar mais seria segurar memória para nada.
  final List<EventoFalha> _bufferInicial = <EventoFalha>[];
  static const int _tetoDoBuffer = 20;

  bool get aguardandoColetor => _coletorPendente != null;

  // --- instalação -------------------------------------------------------

  /// Instala a camada e liga as portas 1 e 2. A porta 3 (zona) é ligada por
  /// [runBuracoMasterVip], porque só quem cria a zona pode guardá-la.
  ///
  /// [coletorReal] só é usado quando o ambiente aceita coletor real E a
  /// identidade da build é provável E `iniciar()` devolve `true`. Em qualquer
  /// outro caso a instalação prossegue com [ColetorNulo] — nunca falha.
  static Future<Observabilidade> instalar({
    IdentidadeBuild? identidade,
    ColetorDeFalhas? coletorReal,
    bool forcarColetorReal = false,
    DateTime Function()? relogio,
    Duration janelaDeduplicacao = const Duration(seconds: 10),
    Redator redator = const Redator(),
    bool instalarHooks = true,
    bool adiarColetor = false,
  }) async {
    final id = identidade ?? IdentidadeBuild.doBinario();
    final obs = Observabilidade._(
      identidade: id,
      coletor: const ColetorNulo(),
      trilha: TrilhaOperacional(),
      relogio: relogio ?? DateTime.now,
      janelaDeduplicacao: janelaDeduplicacao,
      redator: redator,
    );
    instancia = obs;

    final autorizado = coletorReal != null &&
        deveUsarColetorReal(
          identidade: id,
          ehDebug: kDebugMode,
          forcar: forcarColetorReal,
        );
    if (autorizado && adiarColetor) {
      // O coletor real depende do Firebase, que ainda não subiu. Guardamos o
      // coletor e ligamos as portas AGORA mesmo assim: falha durante a
      // inicialização do Firebase é justamente o que ninguém consegue ver, e
      // é o que o buffer preserva até haver para onde mandar.
      obs._coletorPendente = coletorReal;
    } else if (autorizado) {
      final ok = await obs._protegidoAsync(
        () => coletorReal.iniciar(id),
        seFalhar: false,
      );
      if (ok == true) {
        obs._coletor = coletorReal;
        obs.marco(MarcoOperacional.coletorIniciado);
      } else {
        obs.marco(MarcoOperacional.coletorIndisponivel);
      }
    }

    if (instalarHooks) obs._ligarHooks();
    obs._ativo = true;
    return obs;
  }

  /// Decide se o coletor REAL pode ser ligado. Função pura de propósito: é a
  /// regra que separa "manda crash de verdade" de "não manda", então cada
  /// ramo dela tem teste, sem depender do modo em que a suíte roda.
  ///
  /// `flutter test` e `flutter run` rodam em JIT, onde `kDebugMode` é `true` —
  /// é por aí que sai a garantia "debug/test não enviam eventos reais".
  /// Release ainda precisa de ambiente que aceite coletor (homologação ou
  /// produção) e de identidade provável: um crash sem SHA não responde
  /// "qual build quebrou?" e só sujaria o painel.
  @visibleForTesting
  static bool deveUsarColetorReal({
    required IdentidadeBuild identidade,
    required bool ehDebug,
    required bool forcar,
  }) {
    if (forcar) return true;
    if (ehDebug) return false;
    if (!identidade.ambiente.aceitaColetorReal) return false;
    return identidade.provavel;
  }

  void _ligarHooks() {
    if (_hooksInstalados) return;
    _framewokAnterior = FlutterError.onError;
    _plataformaAnterior = PlatformDispatcher.instance.onError;

    FlutterError.onError = capturarDoFramework;
    PlatformDispatcher.instance.onError = capturarDaPlataforma;
    _hooksInstalados = true;
  }

  /// Devolve os handlers anteriores. Usado entre testes; em produção o app
  /// não desinstala.
  void desinstalar() {
    if (_hooksInstalados) {
      FlutterError.onError = _framewokAnterior;
      PlatformDispatcher.instance.onError = _plataformaAnterior;
      _hooksInstalados = false;
    }
    _ativo = false;
    _vistos.clear();
  }

  // --- as quatro portas -------------------------------------------------

  /// Porta 1 — erro síncrono do framework.
  void capturarDoFramework(FlutterErrorDetails detalhes) {
    _reportar(
      erro: detalhes.exception,
      stack: detalhes.stack,
      // `silent` é o próprio framework dizendo que este erro é esperado.
      severidade: detalhes.silent ? Severidade.naoFatal : Severidade.fatal,
      origem: OrigemFalha.framework,
      contexto: <String, Object?>{
        'flutter.biblioteca': detalhes.library ?? 'desconhecida',
      },
    );
    // Nunca mascarar: quem estava aqui antes continua sendo chamado.
    final anterior = _framewokAnterior;
    if (anterior != null) {
      anterior(detalhes);
    } else {
      FlutterError.presentError(detalhes);
    }
  }

  /// Porta 2 — erro de plataforma/dispatcher.
  ///
  /// Devolve `true` porque o erro FOI tratado (registrado e apresentado).
  bool capturarDaPlataforma(Object erro, StackTrace stack) {
    _reportar(
      erro: erro,
      stack: stack,
      severidade: Severidade.fatal,
      origem: OrigemFalha.plataforma,
    );
    final anterior = _plataformaAnterior;
    if (anterior != null) return anterior(erro, stack);
    FlutterError.presentError(
      FlutterErrorDetails(exception: erro, stack: stack, library: 'plataforma'),
    );
    return true;
  }

  /// Porta 3 — erro assíncrono não tratado, vindo da zona protegida.
  void capturarDaZona(Object erro, StackTrace stack) {
    _reportar(
      erro: erro,
      stack: stack,
      severidade: Severidade.fatal,
      origem: OrigemFalha.zona,
    );
    FlutterError.presentError(
      FlutterErrorDetails(exception: erro, stack: stack, library: 'zona'),
    );
  }

  /// Porta 4 — o app reportando algo que ele mesmo tratou.
  void registrarFalha(
    Object erro, {
    StackTrace? stack,
    Severidade severidade = Severidade.naoFatal,
    Map<String, Object?>? contexto,
    String? mensagem,
  }) {
    _reportar(
      erro: erro,
      stack: stack,
      severidade: severidade,
      origem: OrigemFalha.manual,
      contexto: contexto,
      mensagem: mensagem,
    );
  }

  /// Registra um marco operacional na trilha e no coletor.
  void marco(MarcoOperacional m) {
    trilha.registrar(m);
    _semDeixarEscapar(() => _coletor.marco(m));
  }

  // --- miolo ------------------------------------------------------------

  void _reportar({
    required Object? erro,
    required StackTrace? stack,
    required Severidade severidade,
    required OrigemFalha origem,
    Map<String, Object?>? contexto,
    String? mensagem,
  }) {
    // Construir o evento já redige tudo. Se a construção falhar, o app segue.
    final evento = _protegido<EventoFalha>(() => EventoFalha.de(
          erro: erro,
          stack: stack,
          identidade: identidade,
          severidade: severidade,
          origem: origem,
          contexto: contexto,
          trilha: trilha,
          mensagem: mensagem,
          redator: redator,
        ));
    if (evento == null) return;
    if (_ehRepeticao(evento.assinatura)) {
      eventosDeduplicados++;
      return;
    }
    if (_coletorPendente != null) {
      // Ainda não há para onde mandar. Segura até [ligarColetorPendente].
      _bufferInicial.add(evento);
      if (_bufferInicial.length > _tetoDoBuffer) _bufferInicial.removeAt(0);
      return;
    }
    _semDeixarEscapar(() => _coletor.enviar(evento));
  }

  /// Liga o coletor que ficou pendente e despeja o que aconteceu até aqui.
  ///
  /// Chamado por [runBuracoMasterVip] depois da inicialização do Firebase —
  /// antes disso `FirebaseCrashlytics.instance` lança `[core/no-app]`.
  ///
  /// Devolve `true` se o coletor real assumiu. Falhar aqui não é fatal: o app
  /// segue com o [ColetorNulo], como sempre.
  Future<bool> ligarColetorPendente() async {
    final pendente = _coletorPendente;
    if (pendente == null) return _coletor is! ColetorNulo;

    final ok = await _protegidoAsync(
      () => pendente.iniciar(identidade),
      seFalhar: false,
    );
    _coletorPendente = null;

    if (ok != true) {
      _bufferInicial.clear();
      marco(MarcoOperacional.coletorIndisponivel);
      return false;
    }

    _coletor = pendente;
    marco(MarcoOperacional.coletorIniciado);
    final atrasados = List<EventoFalha>.of(_bufferInicial);
    _bufferInicial.clear();
    for (final e in atrasados) {
      _semDeixarEscapar(() => _coletor.enviar(e));
    }
    return true;
  }

  bool _ehRepeticao(String assinatura) {
    final agora = _relogio();
    final anterior = _vistos[assinatura];
    if (anterior != null && agora.difference(anterior) < janelaDeduplicacao) {
      // Não renova o carimbo: senão um erro que repete a cada frame ficaria
      // suprimido para sempre e a falha sumiria do painel.
      return true;
    }
    if (_vistos.length >= _tetoDeAssinaturas) _podarAssinaturas(agora);
    _vistos[assinatura] = agora;
    return false;
  }

  void _podarAssinaturas(DateTime agora) {
    _vistos.removeWhere((_, quando) => agora.difference(quando) >= janelaDeduplicacao);
    if (_vistos.length < _tetoDeAssinaturas) return;
    // Ainda cheio (janela longa): descarta as mais antigas.
    final porIdade = _vistos.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in porIdade.take(_vistos.length - _tetoDeAssinaturas ~/ 2)) {
      _vistos.remove(e.key);
    }
  }

  /// Chama o coletor sem deixar nada escapar — nem exceção síncrona (um
  /// coletor que explode já na chamada) nem Future rejeitado (um que explode
  /// depois, quando ninguém mais está olhando).
  ///
  /// `catch (_)` amplo é deliberado, e é o ponto do contrato "falha do coletor
  /// nunca impede o app": aqui se engole inclusive `Error`, porque o único
  /// desfecho aceitável de um coletor quebrado é um contador subindo.
  void _semDeixarEscapar(Future<void> Function() acao) {
    try {
      acao().catchError((Object _) {
        falhasDoColetor++;
      });
    } catch (_) {
      falhasDoColetor++;
    }
  }

  /// Versão síncrona, para o trecho nosso que monta o evento.
  T? _protegido<T>(T Function() acao) {
    try {
      return acao();
    } catch (_) {
      falhasDoColetor++;
      return null;
    }
  }

  Future<T?> _protegidoAsync<T>(
    Future<T> Function() acao, {
    required T? seFalhar,
  }) async {
    try {
      return await acao();
    } catch (_) {
      falhasDoColetor++;
      return seFalhar;
    }
  }
}
