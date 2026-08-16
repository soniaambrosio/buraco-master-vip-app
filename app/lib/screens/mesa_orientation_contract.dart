import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MesaOrientacaoPreferida { vertical, horizontal, automatica }
enum MesaOrientacaoEfetiva { vertical, horizontal }

class MesaOrientationContract {
  const MesaOrientationContract._();

  static MesaOrientacaoEfetiva resolver({
    required MesaOrientacaoPreferida preferencia,
    required Orientation dispositivo,
  }) {
    switch (preferencia) {
      case MesaOrientacaoPreferida.vertical:
        return MesaOrientacaoEfetiva.vertical;
      case MesaOrientacaoPreferida.horizontal:
        return MesaOrientacaoEfetiva.horizontal;
      case MesaOrientacaoPreferida.automatica:
        return dispositivo == Orientation.landscape
            ? MesaOrientacaoEfetiva.horizontal
            : MesaOrientacaoEfetiva.vertical;
    }
  }

  static List<DeviceOrientation> deviceOrientations(
    MesaOrientacaoPreferida preferencia,
  ) {
    switch (preferencia) {
      case MesaOrientacaoPreferida.vertical:
        return const [DeviceOrientation.portraitUp];
      case MesaOrientacaoPreferida.horizontal:
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case MesaOrientacaoPreferida.automatica:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
  }

  static String label(MesaOrientacaoPreferida preferencia) {
    switch (preferencia) {
      case MesaOrientacaoPreferida.vertical:
        return 'Vertical';
      case MesaOrientacaoPreferida.horizontal:
        return 'Horizontal';
      case MesaOrientacaoPreferida.automatica:
        return 'Automática';
    }
  }
}
