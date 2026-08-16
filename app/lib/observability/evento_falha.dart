// evento_falha.dart — a única forma de uma falha virar dado enviável.
//
// Não existe construtor público que aceite texto cru: `EventoFalha` só nasce
// de [EventoFalha.de], que passa mensagem, contexto, stack e cadeia de causas
// pelo [Redator]. Quem quiser burlar a redação teria de reescrever este
// arquivo — e o teste adversarial pega.

import 'package:flutter/foundation.dart';

import 'identidade_build.dart';
import 'redacao.dart';
import 'trilha_operacional.dart';

/// Peso do evento. Fatal é o que derruba a experiência; não fatal é o que o
/// app absorveu mas alguém precisa olhar.
enum Severidade { fatal, naoFatal }

/// Por qual porta a falha entrou. Serve para provar que as quatro portas do
/// contrato estão de fato ligadas.
enum OrigemFalha {
  /// `FlutterError.onError` — erro síncrono do framework (build, layout…).
  framework,

  /// `runZonedGuarded` — erro assíncrono não tratado.
  zona,

  /// `PlatformDispatcher.instance.onError` — erro vindo do dispatcher/plataforma.
  plataforma,

  /// `Observabilidade.registrarFalha(...)` — chamada explícita do app.
  manual,
}

/// Uma falha já redigida, pronta para sair do dispositivo.
@immutable
class EventoFalha {
  final Severidade severidade;
  final OrigemFalha origem;

  /// Nome do tipo da exceção (`StateError`, `PlatformException`…).
  /// Nome de TIPO nunca é PII e é o que agrupa bem no painel.
  final String tipo;

  /// Mensagem já redigida.
  final String mensagem;

  /// Stack já redigido. Vazio quando não havia stack.
  final String stack;

  /// Cadeia de causas, do erro externo para o mais interno, já redigida.
  final List<String> causas;

  /// Contexto já redigido. Sempre inclui a identidade da build.
  final Map<String, String> contexto;

  /// Marcos operacionais que antecederam a falha.
  final List<String> trilha;

  final IdentidadeBuild identidade;

  const EventoFalha._({
    required this.severidade,
    required this.origem,
    required this.tipo,
    required this.mensagem,
    required this.stack,
    required this.causas,
    required this.contexto,
    required this.trilha,
    required this.identidade,
  });

  /// Constrói um evento a partir de um erro cru. Único caminho de entrada.
  factory EventoFalha.de({
    required Object? erro,
    required StackTrace? stack,
    required IdentidadeBuild identidade,
    required Severidade severidade,
    required OrigemFalha origem,
    Map<String, Object?>? contexto,
    TrilhaOperacional? trilha,
    String? mensagem,
    Redator redator = const Redator(),
  }) {
    final ctx = <String, String>{
      ...redator.contexto(contexto),
      // A identidade entra DEPOIS e não é redigida: é ela que responde
      // "qual build quebrou?", e nenhum campo dela é PII.
      ...identidade.paraContexto(),
      'evento.origem': origem.name,
      'evento.severidade': severidade.name,
    };
    return EventoFalha._(
      severidade: severidade,
      origem: origem,
      tipo: erro == null ? 'DesconhecidoSemErro' : erro.runtimeType.toString(),
      mensagem: redator.texto(mensagem ?? '$erro'),
      stack: redator.stack(stack),
      causas: redator.cadeiaDeCausas(erro),
      contexto: Map<String, String>.unmodifiable(ctx),
      trilha: List<String>.unmodifiable(trilha?.nomes ?? const <String>[]),
      identidade: identidade,
    );
  }

  bool get ehFatal => severidade == Severidade.fatal;

  /// Chave de deduplicação.
  ///
  /// Um mesmo defeito costuma entrar por duas portas (o framework reporta e a
  /// zona também), e o contrato proíbe dupla emissão. A assinatura ignora a
  /// ORIGEM de propósito: é o mesmo defeito, entrou por onde entrar.
  ///
  /// Só os primeiros frames do stack entram: os de baixo são o loop de eventos
  /// e variam entre as portas para o mesmo defeito.
  String get assinatura {
    final frames = stack
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .join('|');
    return '$tipo::$mensagem::$frames::${severidade.name}';
  }

  Map<String, Object?> paraJson() => <String, Object?>{
        'severidade': severidade.name,
        'origem': origem.name,
        'tipo': tipo,
        'mensagem': mensagem,
        'stack': stack,
        'causas': causas,
        'contexto': contexto,
        'trilha': trilha,
        'build': identidade.paraJson(),
      };

  @override
  String toString() =>
      'EventoFalha(${severidade.name}/${origem.name} $tipo: $mensagem @ ${identidade.resumo})';
}
