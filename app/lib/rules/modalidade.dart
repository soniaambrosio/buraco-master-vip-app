// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
// O motor antigo (class Jogo em mesa.dart) continua PADRÃO e autoritativo.
//
// Modalidades canônicas do Buraco Master VIP.
enum Modalidade {
  aberto,
  fechado,
  stbl;

  /// Converte texto do motor antigo/servidor em Modalidade.
  /// Aceita o typo histórico 'SBTL' como alias de 'STBL'.
  static Modalidade deTexto(String s) {
    switch (s.trim().toLowerCase()) {
      case 'aberto':
        return Modalidade.aberto;
      case 'fechado':
        return Modalidade.fechado;
      case 'stbl':
      case 'sbtl':
        return Modalidade.stbl;
      default:
        throw ArgumentError('Modalidade desconhecida: "$s"');
    }
  }

  /// Texto canônico em maiúsculas (compatível com o campo `modalidade` atual).
  String get texto {
    switch (this) {
      case Modalidade.aberto:
        return 'ABERTO';
      case Modalidade.fechado:
        return 'FECHADO';
      case Modalidade.stbl:
        return 'STBL';
    }
  }
}
