// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Ajuste obrigatório 8 — replay determinístico: seed + versão da spec +
// modalidade + estado inicial + sequência de ações. Serve para transformar
// QUALQUER bug real numa reprodução exata e, daí, num teste de conformidade.
import 'acoes.dart';
import 'modalidade.dart';

class Replay {
  /// Semente da distribuição determinística (Jogo(..., seed:)).
  final int seed;

  /// Versão da RuleSpec sob a qual o replay foi gravado (RuleSpec.versaoCanonica).
  final String versaoSpec;

  final Modalidade modalidade;
  final int metaPontos;

  /// Sequência de ações a reaplicar sobre o estado inicial.
  final List<Acao> acoes;

  /// Estado inicial serializado, quando o bug NÃO parte do começo da partida.
  /// Nulo => o estado inicial é derivado de (seed, modalidade, metaPontos).
  final Map<String, dynamic>? estadoInicialSerializado;

  const Replay({
    required this.seed,
    required this.versaoSpec,
    required this.modalidade,
    this.metaPontos = 1500,
    this.acoes = const [],
    this.estadoInicialSerializado,
  });

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'versaoSpec': versaoSpec,
        'modalidade': modalidade.texto,
        'metaPontos': metaPontos,
        'acoes': [for (final a in acoes) a.toJson()],
        if (estadoInicialSerializado != null)
          'estadoInicial': estadoInicialSerializado,
      };

  static Replay fromJson(Map<String, dynamic> j) => Replay(
        seed: j['seed'] as int,
        versaoSpec: j['versaoSpec'] as String,
        modalidade: Modalidade.deTexto(j['modalidade'] as String),
        metaPontos: (j['metaPontos'] as int?) ?? 1500,
        acoes: [
          for (final a in (j['acoes'] as List? ?? const []))
            acaoDeJson((a as Map).cast<String, dynamic>()),
        ],
        estadoInicialSerializado:
            (j['estadoInicial'] as Map?)?.cast<String, dynamic>(),
      );
}
