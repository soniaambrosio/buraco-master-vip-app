import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mesa_orientation_contract.dart';

class MesaOrientacaoSelector extends StatelessWidget {
  final MesaOrientacaoPreferida valor;
  final ValueChanged<MesaOrientacaoPreferida> onChanged;

  const MesaOrientacaoSelector({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MesaOrientacaoPreferida.values.map((item) {
        final selecionado = item == valor;
        final icone = switch (item) {
          MesaOrientacaoPreferida.vertical => Icons.stay_current_portrait_rounded,
          MesaOrientacaoPreferida.horizontal => Icons.stay_current_landscape_rounded,
          MesaOrientacaoPreferida.automatica => Icons.screen_rotation_rounded,
        };
        return ChoiceChip(
          selected: selecionado,
          onSelected: (_) => onChanged(item),
          avatar: Icon(
            icone,
            size: 17,
            color: selecionado
                ? const Color(0xFF3A2508)
                : const Color(0xFFEFB94A),
          ),
          label: Text(MesaOrientationContract.label(item)),
          selectedColor: const Color(0xFFEFB94A),
          backgroundColor: const Color(0xFF1C130C),
          side: BorderSide(
            color: selecionado
                ? const Color(0xFFFFD66A)
                : const Color(0x44EFB94A),
          ),
          labelStyle: TextStyle(
            color: selecionado
                ? const Color(0xFF3A2508)
                : const Color(0xFFF6E2A6),
            fontWeight: FontWeight.w800,
          ),
        );
      }).toList(growable: false),
    );
  }
}

/// Aplica a preferência somente enquanto a Mesa está aberta e restaura o app
/// ao retrato ao sair. A troca de orientação é puramente visual e não deve
/// recriar estado de jogo, conexão, timer, mão ou chat.
class MesaOrientationGuard extends StatefulWidget {
  final MesaOrientacaoPreferida preferencia;
  final Widget Function(
    BuildContext context,
    MesaOrientacaoEfetiva orientacao,
  ) builder;

  const MesaOrientationGuard({
    super.key,
    required this.preferencia,
    required this.builder,
  });

  @override
  State<MesaOrientationGuard> createState() => _MesaOrientationGuardState();
}

class _MesaOrientationGuardState extends State<MesaOrientationGuard> {
  @override
  void initState() {
    super.initState();
    _aplicar(widget.preferencia);
  }

  @override
  void didUpdateWidget(covariant MesaOrientationGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferencia != widget.preferencia) {
      _aplicar(widget.preferencia);
    }
  }

  Future<void> _aplicar(MesaOrientacaoPreferida preferencia) {
    return SystemChrome.setPreferredOrientations(
      MesaOrientationContract.deviceOrientations(preferencia),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, deviceOrientation) {
        final efetiva = MesaOrientationContract.resolver(
          preferencia: widget.preferencia,
          dispositivo: deviceOrientation,
        );
        return widget.builder(context, efetiva);
      },
    );
  }
}
