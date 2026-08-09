// C9-B — COMPOSIÇÃO da costura (primeira costura de runtime, AUTORIDADE OFF).
// Registra os DOIS adaptadores concretos na fábrica e expõe a porta escolhida
// pela config do ambiente. Por padrão (BMV_MOTOR_CANONICO ausente) a autoridade
// é OFF => a fábrica devolve o AdaptadorLegado.
//
// IMPORTANTE (comportamento legado preservado): esta composição está DISPONÍVEL
// no runtime, mas o fluxo antigo (`mesa.dart`) NÃO é reroteado por ela no C9-B —
// nada aqui é chamado pelos métodos legados. O roteamento efetivo do runtime
// pela porta (autoridade ON, fronteira atômica) é o C9-D. `mesa.dart` não
// importa esta camada (sem ciclo).
import 'adaptador_canonico.dart';
import 'adaptador_legado.dart';
import 'fabrica_motor.dart';
import 'motor_config.dart';
import 'porta_motor.dart';

/// Fábrica padrão com os dois adaptadores concretos registrados.
FabricaMotor fabricaPadrao() => FabricaMotor(<TipoMotor, ConstrutorPorta>{
      TipoMotor.legado: () => const AdaptadorLegado(),
      TipoMotor.canonico: () => const AdaptadorCanonico(),
    });

/// Porta selecionada pela config compile-time do ambiente (autoridade OFF por
/// padrão => AdaptadorLegado).
PortaMotor portaDoAmbiente() => fabricaPadrao().criar(MotorConfig.doAmbiente());
