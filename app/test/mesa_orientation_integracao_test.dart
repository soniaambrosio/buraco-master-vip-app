import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/mesa_orientation_contract.dart';
import '../lib/screens/mesa_orientation_widgets.dart';

// Prova da garantia central do adendo: a escolha do layout
// (Vertical/Horizontal/Automática) acontece ABAIXO da camada de estado. Trocar
// a orientação reconstrói apenas o subtree do builder — o estado "dono do
// motor", que fica ACIMA do MesaOrientationGuard, NÃO é recriado. Ou seja,
// girar não reinicia partida, timer, conexão, mão nem aposta.
//
// O harness imita exatamente a arquitetura de _MesaScreenState: um State pai
// guarda a identidade do "motor" (criada uma única vez em initState) e envolve
// o guard, cujo builder devolve telas diferentes por orientação.

int _motorInits = 0;

class _FakeMesa extends StatefulWidget {
  const _FakeMesa({super.key});

  @override
  State<_FakeMesa> createState() => _FakeMesaState();
}

class _FakeMesaState extends State<_FakeMesa> {
  late final Object motorIdentity; // representa _j (motor/partida)
  MesaOrientacaoPreferida pref = MesaOrientacaoPreferida.vertical;

  @override
  void initState() {
    super.initState();
    _motorInits++;
    motorIdentity = Object();
  }

  void trocar(MesaOrientacaoPreferida p) => setState(() => pref = p);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MesaOrientationGuard(
        preferencia: pref,
        builder: (context, efetiva) => Text(
          efetiva == MesaOrientacaoEfetiva.horizontal ? 'H' : 'V',
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'trocar orientação alterna o layout sem recriar o estado do motor',
    (tester) async {
      _motorInits = 0;
      final key = GlobalKey<_FakeMesaState>();

      await tester.pumpWidget(_FakeMesa(key: key));

      // Abre em Vertical (preferência padrão) e cria o motor exatamente 1x.
      expect(find.text('V'), findsOneWidget);
      expect(_motorInits, 1);
      final identidadeInicial = key.currentState!.motorIdentity;

      // Troca para Horizontal: só o subtree do builder muda.
      key.currentState!.trocar(MesaOrientacaoPreferida.horizontal);
      await tester.pump();
      expect(find.text('H'), findsOneWidget);

      // Volta para Vertical.
      key.currentState!.trocar(MesaOrientacaoPreferida.vertical);
      await tester.pump();
      expect(find.text('V'), findsOneWidget);

      // O motor NUNCA foi recriado: mesma identidade e um único initState.
      expect(
        identical(identidadeInicial, key.currentState!.motorIdentity),
        isTrue,
      );
      expect(_motorInits, 1);

      // Desmonta para o guard restaurar portraitUp sem timers pendentes.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
