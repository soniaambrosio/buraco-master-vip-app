import 'package:shared_preferences/shared_preferences.dart';

import '../screens/mesa_orientation_contract.dart';

class MesaOrientationService {
  MesaOrientationService._();

  static final MesaOrientationService instance = MesaOrientationService._();

  static const _key = 'cfg_mesa_orientacao';

  MesaOrientacaoPreferida _atual = MesaOrientacaoPreferida.vertical;
  MesaOrientacaoPreferida get atual => _atual;

  Future<MesaOrientacaoPreferida> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_key) ?? MesaOrientacaoPreferida.vertical.index;
    final idx = raw.clamp(0, MesaOrientacaoPreferida.values.length - 1).toInt();
    _atual = MesaOrientacaoPreferida.values[idx];
    return _atual;
  }

  Future<void> salvar(MesaOrientacaoPreferida preferencia) async {
    _atual = preferencia;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, preferencia.index);
  }
}
