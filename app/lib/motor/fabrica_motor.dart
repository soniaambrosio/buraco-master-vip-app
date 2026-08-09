// C9-A — SELETOR + FÁBRICA da porta do motor.
//
// Decide QUAL implementação usar a partir da flag de AUTORIDADE e delega a
// construção a um CONSTRUTOR registrado. C9-A NÃO instancia nenhum adaptador
// concreto (isso é C9-B): os construtores são INJETADOS. Sem fake que lance
// `UnimplementedError`; sem `dynamic`; sem mapear Jogo <-> EstadoJogo aqui;
// sem importar `mesa.dart`.
import 'motor_config.dart';
import 'porta_motor.dart';

/// Qual motor a costura deve usar.
enum TipoMotor { legado, canonico }

/// SELEÇÃO pura pela flag de AUTORIDADE. A flag de SOMBRA NÃO afeta a seleção
/// (sombra é observação, não autoridade).
TipoMotor selecionarMotor(MotorConfig config) =>
    config.canonicoAtivo ? TipoMotor.canonico : TipoMotor.legado;

/// Construtor de uma [PortaMotor] concreta. Os construtores reais são
/// registrados no C9-B (adaptador legado / adaptador canônico); nos testes de
/// C9-A são dublês reais (não lançam `UnimplementedError`).
typedef ConstrutorPorta = PortaMotor Function();

/// FÁBRICA: escolhe o tipo pela config e delega a um construtor registrado.
/// Não conhece nenhum adaptador concreto — só o mapa de construtores injetado.
class FabricaMotor {
  final Map<TipoMotor, ConstrutorPorta> _construtores;

  const FabricaMotor(this._construtores);

  /// Constrói a porta do motor SELECIONADO. Se o construtor do tipo escolhido
  /// não estiver registrado (uso indevido, ou antes do C9-B registrar os
  /// adaptadores), FALHA de forma explícita — NUNCA devolve um fake.
  PortaMotor criar(MotorConfig config) {
    final tipo = selecionarMotor(config);
    final construtor = _construtores[tipo];
    if (construtor == null) {
      throw StateError(
          'FabricaMotor: nenhum construtor registrado para $tipo. '
          'Os adaptadores concretos são registrados no C9-B.');
    }
    return construtor();
  }
}
