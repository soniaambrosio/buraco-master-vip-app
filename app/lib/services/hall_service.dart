// hall_service.dart — fronteira única de dados do Hall dos Imortais.
//
// Mesma situação do Ranking (docs/MAPA-INTEGRACAO-RANKING-LIGAS-HALL.md §G):
// não existe fonte oficial ao alcance do app. A implementação embarcada é
// [HallSemFonte], que declara a ausência. Fabricar vencedor é justamente o que
// a OS proíbe — quem é imortal não se decide no cliente.

import '../hall/hall_contract.dart';

abstract class HallService {
  const HallService();

  /// Quadro atual do Hall.
  ///
  /// Lança [HallIndisponivel] quando a fonte não responde.
  Future<HallQuadro> quadro();
}

/// Implementação de produção **enquanto não houver fonte oficial**.
class HallSemFonte extends HallService {
  const HallSemFonte();

  static const String motivo =
      'O Hall dos Imortais ainda não está sendo publicado.';

  @override
  Future<HallQuadro> quadro() =>
      Future<HallQuadro>.error(const HallIndisponivel(motivo));
}
