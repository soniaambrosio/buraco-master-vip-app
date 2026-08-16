import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/screens/mesa_orientation_contract.dart';
import '../lib/services/mesa_orientation_service.dart';

void main() {
  group('MesaOrientationContract', () {
    test('vertical força layout vertical', () {
      expect(
        MesaOrientationContract.resolver(
          preferencia: MesaOrientacaoPreferida.vertical,
          dispositivo: Orientation.landscape,
        ),
        MesaOrientacaoEfetiva.vertical,
      );
      expect(
        MesaOrientationContract.deviceOrientations(
          MesaOrientacaoPreferida.vertical,
        ),
        [DeviceOrientation.portraitUp],
      );
    });

    test('horizontal força layout horizontal', () {
      expect(
        MesaOrientationContract.resolver(
          preferencia: MesaOrientacaoPreferida.horizontal,
          dispositivo: Orientation.portrait,
        ),
        MesaOrientacaoEfetiva.horizontal,
      );
      expect(
        MesaOrientationContract.deviceOrientations(
          MesaOrientacaoPreferida.horizontal,
        ),
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    });

    test('automática acompanha orientação do aparelho', () {
      expect(
        MesaOrientationContract.resolver(
          preferencia: MesaOrientacaoPreferida.automatica,
          dispositivo: Orientation.portrait,
        ),
        MesaOrientacaoEfetiva.vertical,
      );
      expect(
        MesaOrientationContract.resolver(
          preferencia: MesaOrientacaoPreferida.automatica,
          dispositivo: Orientation.landscape,
        ),
        MesaOrientacaoEfetiva.horizontal,
      );
    });
  });

  test('preferência de orientação persiste localmente', () async {
    SharedPreferences.setMockInitialValues({});
    final service = MesaOrientationService.instance;

    expect(await service.carregar(), MesaOrientacaoPreferida.vertical);
    await service.salvar(MesaOrientacaoPreferida.horizontal);
    expect(await service.carregar(), MesaOrientacaoPreferida.horizontal);
  });
}
