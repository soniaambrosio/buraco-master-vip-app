// C9-A — CONFIG das flags do motor (camada de costura; NÃO é regra, NÃO é
// runtime). Duas flags INDEPENDENTES, compile-time configuráveis via
// `bool.fromEnvironment`, ambas OFF por padrão, com override explícito por
// injeção (construtor const) para testes.
//
// A flag de SOMBRA é SEPARADA da de AUTORIDADE: observar (sombra) nunca implica
// decidir (autoridade). Ver PLANO-C9-MOTOR-FLAG (Adendo 1).
class MotorConfig {
  /// AUTORIDADE: quando true, o motor canônico decide o estado real (só no
  /// C9-D). Padrão: OFF. Em compilação, controlada por
  /// `--dart-define=BMV_MOTOR_CANONICO=true`.
  final bool canonicoAtivo;

  /// SOMBRA: quando true, o canônico roda em paralelo apenas para COMPARAR
  /// (C9-C), sem autoridade. Padrão: OFF. Controlada por
  /// `--dart-define=BMV_MOTOR_SOMBRA=true`.
  final bool sombraAtiva;

  /// Override explícito (injeção) — usado por testes e pela composição da
  /// costura. Ambas OFF por padrão.
  const MotorConfig({this.canonicoAtivo = false, this.sombraAtiva = false});

  /// Config a partir do AMBIENTE DE COMPILAÇÃO (compile-time). Ambas OFF por
  /// padrão; nada muda em runtime sem passar `--dart-define` explícito.
  factory MotorConfig.doAmbiente() => const MotorConfig(
        canonicoAtivo:
            bool.fromEnvironment('BMV_MOTOR_CANONICO', defaultValue: false),
        sombraAtiva:
            bool.fromEnvironment('BMV_MOTOR_SOMBRA', defaultValue: false),
      );

  @override
  String toString() =>
      'MotorConfig(canonicoAtivo: $canonicoAtivo, sombraAtiva: $sombraAtiva)';
}
