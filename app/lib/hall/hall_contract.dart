// hall_contract.dart — o que o cliente ESPERA receber de uma fonte oficial do
// Hall dos Imortais.
//
// A camada Flutter não escolhe quem é imortal. Ela recebe um quadro pronto:
// categoria, homenageado e as estatísticas já formatadas. Não há aqui nenhum
// critério de elegibilidade, desempate ou período — isso é autoridade.

/// As cinco glórias do Hall. A arte oficial (`assets/hall/painel_gloria.webp`)
/// reserva um lugar fixo para cada uma.
enum HallCategoria {
  campeaoHoje,
  melhorDupla,
  maiorSequencia,
  reiRainhaSemana,
  lendaMes,
}

/// Um homenageado, como a fonte publicou.
class HallHonrado {
  final HallCategoria categoria;

  /// Identificador **público** — é o que abre o perfil.
  final String id;

  final String nome;

  /// Emoji, caminho `assets/...` ou URL.
  final String avatar;

  /// Segundo avatar, só para [HallCategoria.melhorDupla].
  final String? avatar2;

  /// Estatísticas **já formatadas pela fonte** (“342”, “68%”, “Hoje”). O
  /// cliente não faz conta nem escolhe unidade: a arte tem três lugares e cada
  /// um recebe o texto que veio.
  final List<String> estatisticas;

  const HallHonrado({
    required this.categoria,
    required this.id,
    required this.nome,
    required this.avatar,
    this.avatar2,
    this.estatisticas = const [],
  });
}

/// O quadro completo do Hall num instante.
class HallQuadro {
  final List<HallHonrado> honrados;

  const HallQuadro({required this.honrados});

  static const HallQuadro vazio = HallQuadro(honrados: []);

  bool get semHonrados => honrados.isEmpty;

  /// O homenageado de uma categoria, ou `null` quando a fonte ainda não tem
  /// vencedor para ela — que é diferente de o Hall inteiro estar vazio.
  HallHonrado? porCategoria(HallCategoria categoria) {
    for (final honrado in honrados) {
      if (honrado.categoria == categoria) return honrado;
    }
    return null;
  }
}

/// A fonte oficial do Hall não respondeu — ou ainda não existe.
class HallIndisponivel implements Exception {
  /// Texto curto, já em português e exibível ao jogador.
  final String motivo;

  const HallIndisponivel(this.motivo);

  @override
  String toString() => 'HallIndisponivel: $motivo';
}
