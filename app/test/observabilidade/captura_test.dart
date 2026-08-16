// As quatro portas de captura, e as três invariantes que valem em todas elas.
//
// Os testes instalam um handler-sentinela ANTES da camada. Ele é o "handler
// anterior" que a camada promete não mascarar — se ele parar de ser chamado, a
// observabilidade estará escondendo erro, que é o oposto do que ela existe
// para fazer.

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:buraco_master_vip/observability/coletor.dart';
import 'package:buraco_master_vip/observability/evento_falha.dart';
import 'package:buraco_master_vip/observability/identidade_build.dart';
import 'package:buraco_master_vip/observability/observabilidade.dart';
import 'package:buraco_master_vip/observability/runtime.dart';
import 'package:buraco_master_vip/observability/trilha_operacional.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const IdentidadeBuild identidadeDeTeste = IdentidadeBuild(
  versionName: '1.4.2',
  versionCode: 412,
  sha: '0cea0d6d68f2c93613b985f4aa85800d77cf42d7',
  branch: 'claude/observabilidade-build-recuperacao-v1',
  ambiente: AmbienteBuild.producao,
  flutterVersion: '3.44.8',
  dartVersion: '3.11.1',
);

/// Coletor que quebra em tudo. O app tem de sobreviver a ele.
class ColetorQuebrado implements ColetorDeFalhas {
  ColetorQuebrado({this.quebraNoIniciar = true});
  final bool quebraNoIniciar;
  int tentativasDeEnvio = 0;

  @override
  String get nome => 'quebrado';

  @override
  Future<bool> iniciar(IdentidadeBuild identidade) async {
    if (quebraNoIniciar) throw StateError('coletor indisponível');
    return true;
  }

  @override
  Future<void> enviar(EventoFalha evento) async {
    tentativasDeEnvio++;
    throw StateError('rede caiu no meio do envio');
  }

  @override
  Future<void> marco(MarcoOperacional marco) async =>
      throw StateError('marco falhou');
}

/// Coletor que aceita iniciar mas explode SÍNCRONO, antes de virar Future.
class ColetorExplosivoSincrono implements ColetorDeFalhas {
  @override
  String get nome => 'explosivo';
  @override
  Future<bool> iniciar(IdentidadeBuild identidade) async => true;
  @override
  Future<void> enviar(EventoFalha evento) => throw StateError('boom síncrono');
  @override
  Future<void> marco(MarcoOperacional marco) => throw StateError('boom síncrono');
}

void main() {
  late ColetorEmMemoria memoria;
  late List<FlutterErrorDetails> sentinelaFramework;
  late List<Object> sentinelaPlataforma;
  FlutterExceptionHandler? frameworkOriginal;
  bool Function(Object, StackTrace)? plataformaOriginal;
  DateTime agora = DateTime.utc(2026, 8, 16, 12);

  setUp(() {
    memoria = ColetorEmMemoria();
    sentinelaFramework = <FlutterErrorDetails>[];
    sentinelaPlataforma = <Object>[];
    agora = DateTime.utc(2026, 8, 16, 12);

    frameworkOriginal = FlutterError.onError;
    plataformaOriginal = PlatformDispatcher.instance.onError;
    // Sentinela no lugar do handler do próprio flutter_test: assim o teste
    // consegue afirmar que a camada REPASSA, sem que repassar reprove o teste.
    FlutterError.onError = sentinelaFramework.add;
    PlatformDispatcher.instance.onError = (e, s) {
      sentinelaPlataforma.add(e);
      return true;
    };
  });

  tearDown(() {
    Observabilidade.instancia.desinstalar();
    FlutterError.onError = frameworkOriginal;
    PlatformDispatcher.instance.onError = plataformaOriginal;
  });

  Future<Observabilidade> instalar({
    ColetorDeFalhas? coletor,
    Duration janela = const Duration(seconds: 10),
  }) =>
      Observabilidade.instalar(
        identidade: identidadeDeTeste,
        coletorReal: coletor ?? memoria,
        forcarColetorReal: true,
        relogio: () => agora,
        janelaDeduplicacao: janela,
      );

  group('porta 1 — erro síncrono do framework', () {
    test('captura, classifica como fatal e repassa ao handler anterior', () async {
      await instalar();
      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('layout impossível'),
        stack: StackTrace.current,
        library: 'widgets library',
      ));

      expect(memoria.eventos, hasLength(1));
      final e = memoria.eventos.single;
      expect(e.origem, OrigemFalha.framework);
      expect(e.severidade, Severidade.fatal);
      expect(e.tipo, 'StateError');
      expect(e.mensagem, contains('layout impossível'));
      expect(e.contexto['flutter.biblioteca'], 'widgets library');
      // Invariante: não mascarou.
      expect(sentinelaFramework, hasLength(1));
    });

    test('erro marcado como silent vira NÃO fatal', () async {
      await instalar();
      FlutterError.onError!(FlutterErrorDetails(
        exception: ArgumentError('esperado'),
        stack: StackTrace.current,
        silent: true,
      ));
      expect(memoria.eventos.single.severidade, Severidade.naoFatal);
      expect(memoria.fatais, isEmpty);
      expect(memoria.naoFatais, hasLength(1));
    });
  });

  group('porta 2 — erro de plataforma/dispatcher', () {
    test('captura como fatal e repassa', () async {
      final obs = await instalar();
      final tratado = PlatformDispatcher.instance.onError!(
        StateError('canal de plataforma morreu'),
        StackTrace.current,
      );

      expect(tratado, isTrue);
      expect(memoria.eventos.single.origem, OrigemFalha.plataforma);
      expect(memoria.eventos.single.severidade, Severidade.fatal);
      expect(sentinelaPlataforma, hasLength(1));
      expect(obs.ativo, isTrue);
    });
  });

  group('porta 3 — erro assíncrono não tratado', () {
    test('a zona protegida entrega o erro à camada', () async {
      final capturados = <EventoFalha>[];
      final coletor = ColetorEmMemoria();

      await executarObservado(
        identidade: identidadeDeTeste,
        coletor: coletor,
        forcarColetorReal: true,
        instalarHooks: false,
        relogio: () => agora,
        corpo: (obs) async {
          // Erro assíncrono sem `await`: ninguém o pega, só a zona.
          unawaited(Future<void>.microtask(
              () => throw StateError('futuro solto explodiu')));
        },
      );
      // Deixa a microtask rodar depois que o corpo terminou.
      await Future<void>.delayed(Duration.zero);

      capturados.addAll(coletor.eventos);
      expect(capturados, hasLength(1));
      expect(capturados.single.origem, OrigemFalha.zona);
      expect(capturados.single.severidade, Severidade.fatal);
      expect(capturados.single.mensagem, contains('futuro solto explodiu'));
    });
  });

  group('porta 4 — registro explícito', () {
    test('padrão é não fatal e aceita contexto', () async {
      final obs = await instalar();
      obs.registrarFalha(
        StateError('reconexão falhou'),
        contexto: <String, Object?>{'tentativa': 3, 'uid': 'abc'},
      );
      final e = memoria.eventos.single;
      expect(e.severidade, Severidade.naoFatal);
      expect(e.origem, OrigemFalha.manual);
      expect(e.contexto['tentativa'], '3');
      expect(e.contexto['uid'], '[REDIGIDO]');
    });

    test('fatal e não fatal chegam classificados e separáveis', () async {
      final obs = await instalar();
      obs.registrarFalha(StateError('grave'), severidade: Severidade.fatal);
      obs.registrarFalha(StateError('leve'), severidade: Severidade.naoFatal);
      expect(memoria.fatais, hasLength(1));
      expect(memoria.naoFatais, hasLength(1));
    });
  });

  group('deduplicação', () {
    test('o mesmo erro por duas portas emite uma vez só', () async {
      final obs = await instalar();
      final erro = StateError('o mesmo defeito');
      final stack = StackTrace.current;

      obs.capturarDoFramework(
          FlutterErrorDetails(exception: erro, stack: stack));
      obs.capturarDaPlataforma(erro, stack);

      expect(memoria.eventos, hasLength(1));
      expect(obs.eventosDeduplicados, 1);
    });

    test('passada a janela, o mesmo erro volta a ser emitido', () async {
      final obs = await instalar(janela: const Duration(seconds: 10));
      final erro = StateError('repetido');
      final stack = StackTrace.current;

      obs.capturarDaPlataforma(erro, stack);
      agora = agora.add(const Duration(seconds: 11));
      obs.capturarDaPlataforma(erro, stack);

      expect(memoria.eventos, hasLength(2));
    });

    test('erros diferentes não se deduplicam entre si', () async {
      final obs = await instalar();
      obs.registrarFalha(StateError('um'));
      obs.registrarFalha(StateError('outro'));
      expect(memoria.eventos, hasLength(2));
    });

    test('severidade diferente não é o mesmo evento', () async {
      final obs = await instalar();
      obs.registrarFalha(StateError('x'), severidade: Severidade.fatal);
      obs.registrarFalha(StateError('x'), severidade: Severidade.naoFatal);
      expect(memoria.eventos, hasLength(2));
    });
  });

  group('coletor indisponível', () {
    test('coletor que falha ao iniciar não impede o startup', () async {
      var corpoRodou = false;
      final quebrado = ColetorQuebrado();

      await executarObservado(
        identidade: identidadeDeTeste,
        coletor: quebrado,
        forcarColetorReal: true,
        instalarHooks: false,
        corpo: (obs) async {
          corpoRodou = true;
        },
      );

      expect(corpoRodou, isTrue, reason: 'o app precisa subir mesmo assim');
      expect(Observabilidade.instancia.coletor, isA<ColetorNulo>());
      expect(Observabilidade.instancia.falhasDoColetor, greaterThan(0));
      expect(Observabilidade.instancia.trilha.marcos,
          contains(MarcoOperacional.coletorIndisponivel));
    });

    test('coletor que explode no envio não propaga o erro', () async {
      final quebrado = ColetorQuebrado(quebraNoIniciar: false);
      final obs = await instalar(coletor: quebrado);

      expect(() => obs.registrarFalha(StateError('qualquer')), returnsNormally);
      await Future<void>.delayed(Duration.zero);
      expect(quebrado.tentativasDeEnvio, 1);
      expect(obs.falhasDoColetor, greaterThan(0));
    });

    test('coletor que explode SÍNCRONO também é contido', () async {
      final obs = await instalar(coletor: ColetorExplosivoSincrono());
      expect(() => obs.registrarFalha(StateError('qualquer')), returnsNormally);
      expect(() => obs.marco(MarcoOperacional.telaMesa), returnsNormally);
      expect(obs.falhasDoColetor, greaterThan(0));
    });

    test('o erro original não é mascarado quando o coletor está quebrado',
        () async {
      await instalar(coletor: ColetorQuebrado(quebraNoIniciar: false));
      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('erro real'),
        stack: StackTrace.current,
      ));
      expect(sentinelaFramework, hasLength(1));
      expect(sentinelaFramework.single.exception.toString(), contains('erro real'));
    });
  });

  group('coleta desligada em debug/teste', () {
    test('sem forçar, a suíte nunca liga o coletor real', () async {
      final obs = await Observabilidade.instalar(
        identidade: identidadeDeTeste,
        coletorReal: memoria,
        instalarHooks: false,
      );
      expect(obs.coletor, isA<ColetorNulo>());
      expect(memoria.vezesIniciado, 0);

      obs.registrarFalha(StateError('nada disso sai daqui'));
      expect(memoria.eventos, isEmpty);
    });

    test('a regra de autorização, ramo a ramo', () {
      bool decidir(IdentidadeBuild id, {required bool debug}) =>
          Observabilidade.deveUsarColetorReal(
              identidade: id, ehDebug: debug, forcar: false);

      // debug barra mesmo com identidade perfeita em produção
      expect(decidir(identidadeDeTeste, debug: true), isFalse);
      // release + produção + identidade provável: libera
      expect(decidir(identidadeDeTeste, debug: false), isTrue);
      // ambiente de desenvolvimento não fala com coletor real
      expect(
        decidir(
            const IdentidadeBuild(
              versionName: '1.4.2',
              versionCode: 412,
              sha: '0cea0d6d68f2c93613b985f4aa85800d77cf42d7',
              branch: 'main',
              ambiente: AmbienteBuild.desenvolvimento,
            ),
            debug: false),
        isFalse,
      );
      // release em produção, mas SEM sha: não sobe (não teria com o que cruzar)
      expect(
        decidir(
            const IdentidadeBuild(
              versionName: '1.4.2',
              versionCode: 412,
              sha: '',
              branch: 'main',
              ambiente: AmbienteBuild.producao,
            ),
            debug: false),
        isFalse,
      );
      // `forcar` é o que a própria suíte usa, e só ela
      expect(
        Observabilidade.deveUsarColetorReal(
            identidade: identidadeDeTeste, ehDebug: true, forcar: true),
        isTrue,
      );
    });
  });

  group('identidade e trilha em todo evento', () {
    test('todo evento carrega versão, versionCode, ambiente e SHA', () async {
      final obs = await instalar();
      obs.registrarFalha(StateError('x'));
      final ctx = memoria.eventos.single.contexto;
      expect(ctx['build.versionName'], '1.4.2');
      expect(ctx['build.versionCode'], '412');
      expect(ctx['build.ambiente'], 'producao');
      expect(ctx['build.sha'], identidadeDeTeste.sha);
      expect(memoria.eventos.single.identidade.resumo,
          '1.4.2 (412) · 0cea0d6 · producao');
    });

    test('a trilha acompanha a falha, na ordem em que aconteceu', () async {
      final obs = await instalar();
      // A própria instalação já registrou `coletorIniciado`.
      expect(obs.trilha.nomes, <String>['coletorIniciado']);

      obs.marco(MarcoOperacional.appIniciado);
      obs.marco(MarcoOperacional.telaInicio);
      obs.marco(MarcoOperacional.telaMesa);
      obs.registrarFalha(StateError('x'));

      expect(memoria.eventos.single.trilha, <String>[
        'coletorIniciado',
        'appIniciado',
        'telaInicio',
        'telaMesa',
      ]);
      expect(memoria.marcos, hasLength(4));
    });

    test('a trilha não cresce sem limite', () {
      final trilha = TrilhaOperacional(capacidade: 3);
      for (var i = 0; i < 10; i++) {
        trilha.registrar(MarcoOperacional.telaMesa);
      }
      trilha.registrar(MarcoOperacional.partidaEncerrada);
      expect(trilha.marcos, hasLength(3));
      expect(trilha.marcos.last, MarcoOperacional.partidaEncerrada);
    });

    test('nenhum evento carrega chave que identifique jogador', () async {
      final obs = await instalar();
      obs.registrarFalha(
        StateError('erro'),
        contexto: <String, Object?>{'uid': 'x', 'email': 'a@b.c'},
      );
      final json = memoria.eventos.single.paraJson().toString();
      expect(json, isNot(contains('a@b.c')));
      // Não há correlação de jogador: a camada não emite nenhuma. Ver o
      // runbook, seção "Correlação de jogador".
      expect(memoria.eventos.single.contexto.keys.any((k) => k.contains('jogador')),
          isFalse);
    });
  });

  test('a instância inerte antes de instalar é segura', () {
    final inerte = Observabilidade.instancia;
    expect(() => inerte.registrarFalha(StateError('x')), returnsNormally);
    expect(() => inerte.marco(MarcoOperacional.appIniciado), returnsNormally);
  });
}
