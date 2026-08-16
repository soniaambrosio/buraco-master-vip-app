// C1 — andaime do RulesEngine canônico.
// C10 (parte 2): PARTICIPA DO RUNTIME LOCAL. Sob `MotorConfig.producao()` a
// partida real passa por aqui; o cabeçalho antigo dizia o contrário.
//
// Ajuste obrigatório 8 — replay determinístico: seed + versão da spec +
// modalidade + estado inicial + sequência de ações. Serve para transformar
// QUALQUER bug real numa reprodução exata e, daí, num teste de conformidade.
import 'acoes.dart';
import 'estado.dart' show FaseTurno;
import 'modalidade.dart';

class Replay {
  /// Semente da distribuição determinística (Jogo(..., seed:)).
  /// C9-C (Ajuste 3): OPCIONAL. Produção usa `Random()` sem seed reproduzível,
  /// então um replay de runtime reproduz-se pelo `estadoInicialSerializado`
  /// completo. Invariante: `reproduzivel` = seed != null OU snapshot completo.
  final int? seed;

  /// Versão da RuleSpec sob a qual o replay foi gravado (RuleSpec.versaoCanonica).
  final String versaoSpec;

  final Modalidade modalidade;
  final int metaPontos;

  /// Sequência de ações a reaplicar sobre o estado inicial.
  final List<Acao> acoes;

  /// Estado inicial serializado, quando o bug NÃO parte do começo da partida.
  /// Nulo => o estado inicial é derivado de (seed, modalidade, metaPontos).
  final Map<String, dynamic>? estadoInicialSerializado;

  /// FASE do turno no estado inicial (fase também é regra — precisa ser fiel no
  /// replay quando o bug parte do meio de um turno). Default: início (compra).
  final FaseTurno faseInicial;

  /// Chaves de topo EXIGIDAS de um snapshot de runtime COMPLETO (contrato do
  /// Replay; genérico — a camada `rules/` NÃO conhece o esquema interno de cada
  /// parte, só que um snapshot reproduzível carrega o estado canônico E o
  /// envelope de runtime). Preenchidas pela camada de sombra (motor/).
  static const Set<String> chavesSnapshotRuntime = {'canonico', 'envelope'};

  /// True se o snapshot inicial é COMPLETO (validável): contém as duas partes
  /// exigidas (canônico + envelope). Um mapa arbitrário (ex.: {'a':1}) NÃO é.
  bool get snapshotCompleto =>
      estadoInicialSerializado != null &&
      chavesSnapshotRuntime.every(estadoInicialSerializado!.containsKey);

  /// Invariante do Ajuste 3 (corrigido no C9-C-fix): um replay é reproduzível se
  /// tem seed determinística OU um snapshot COMPLETO validável — nunca por um
  /// simples "mapa não nulo". Nunca se inventa seed.
  bool get reproduzivel => seed != null || snapshotCompleto;

  const Replay({
    this.seed,
    required this.versaoSpec,
    required this.modalidade,
    this.metaPontos = 1500,
    this.acoes = const [],
    this.estadoInicialSerializado,
    this.faseInicial = FaseTurno.compra,
  });

  Map<String, dynamic> toJson() => {
        if (seed != null) 'seed': seed,
        'versaoSpec': versaoSpec,
        'modalidade': modalidade.texto,
        'metaPontos': metaPontos,
        'acoes': [for (final a in acoes) a.toJson()],
        'faseInicial': faseInicial.name,
        if (estadoInicialSerializado != null)
          'estadoInicial': estadoInicialSerializado,
      };

  static FaseTurno _faseDeTexto(String? s) {
    switch (s) {
      case 'jogo':
        return FaseTurno.jogo;
      case 'mortoPendente':
        return FaseTurno.mortoPendente;
      default:
        return FaseTurno.compra;
    }
  }

  static Replay fromJson(Map<String, dynamic> j) => Replay(
        seed: j['seed'] as int?,
        versaoSpec: j['versaoSpec'] as String,
        modalidade: Modalidade.deTexto(j['modalidade'] as String),
        metaPontos: (j['metaPontos'] as int?) ?? 1500,
        acoes: [
          for (final a in (j['acoes'] as List? ?? const []))
            acaoDeJson((a as Map).cast<String, dynamic>()),
        ],
        faseInicial: _faseDeTexto(j['faseInicial'] as String?),
        estadoInicialSerializado:
            (j['estadoInicial'] as Map?)?.cast<String, dynamic>(),
      );
}
