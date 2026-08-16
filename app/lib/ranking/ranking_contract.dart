// ranking_contract.dart — o que o cliente ESPERA receber de uma fonte oficial de
// Ranking. Nenhum tipo aqui calcula posição, pontos, liga ou temporada: tudo é
// dado recebido e repetido. A regra de autoridade da OS é simples — o Flutter
// exibe classificação, não a produz.
//
// Deliberadamente sem `package:flutter`: contrato é domínio, não apresentação.
// A tradução para os tipos visuais (`RankingVM` e companhia) vive em
// `ranking_apresentacao.dart`.

/// Recorte do ranking pedido à fonte. Espelha as três abas da tela sem depender
/// da UI (a tela tem o seu próprio `RankingAba`).
enum RankingEscopo { temporada, global, amigos }

/// Movimento da posição desde a última apuração — informado pela fonte.
enum RankingDirecao { subiu, desceu, estavel }

/// Uma linha do ranking, exatamente como a fonte publicou.
class RankingJogador {
  /// Identificador **público** do jogador (UID). Nunca e-mail, nunca token:
  /// é isto que atravessa para a tela de Perfil.
  final String id;

  final String apelido;

  /// Emoji, caminho `assets/...` ou URL — a tela aceita os três.
  final String avatar;

  /// Rótulo da liga **oficial** do jogador. O cliente não descobre liga.
  final String liga;

  /// Pontuação oficial.
  final int pontos;

  /// Posição oficial na classificação. Não é índice de lista: vem da fonte e é
  /// exibida como veio.
  final int posicao;

  final RankingDirecao direcao;

  /// Quantas posições o jogador andou. Sem significado quando [direcao] é
  /// [RankingDirecao.estavel].
  final int delta;

  /// Selo de destaque concedido pela fonte (caminho de asset), se houver.
  final String? selo;

  /// Marca a linha do jogador local. Quem decide é a fonte, comparando com a
  /// identidade autenticada — o cliente não adivinha por apelido.
  final bool souEu;

  const RankingJogador({
    required this.id,
    required this.apelido,
    required this.avatar,
    required this.liga,
    required this.pontos,
    required this.posicao,
    this.direcao = RankingDirecao.estavel,
    this.delta = 0,
    this.selo,
    this.souEu = false,
  });

  /// Chave de deduplicação entre páginas. Usa o id quando a fonte o publica e
  /// cai na posição quando não publica — sem isso, uma fonte sem id faria toda
  /// página nova parecer repetida.
  String get chave => id.isNotEmpty ? id : 'posicao:$posicao';
}

/// Divisão atual do jogador dentro da liga, como publicada pela fonte.
class RankingDivisao {
  final String nome;
  final String icone;
  final int pontos;
  final int pontosProxima;
  final int faltamPontos;
  final String proximaDivisao;
  final int posicaoLiga;

  const RankingDivisao({
    required this.nome,
    required this.icone,
    required this.pontos,
    required this.pontosProxima,
    required this.faltamPontos,
    required this.proximaDivisao,
    required this.posicaoLiga,
  });
}

/// Um degrau da escada de ligas. `atual` também vem da fonte.
class RankingLigaDegrau {
  final String nome;
  final String icone;
  final bool atual;

  const RankingLigaDegrau({
    required this.nome,
    required this.icone,
    required this.atual,
  });
}

/// Cabeçalho do escopo: o que aparece acima da lista.
class RankingResumo {
  final RankingEscopo escopo;

  /// Texto pronto da temporada (“Temporada acaba em 12d 6h”). Vazio quando o
  /// escopo não tem contagem. O cliente não calcula prazo de temporada.
  final String faixaTempo;

  final RankingDivisao? divisao;
  final List<RankingJogador> podio;
  final List<RankingLigaDegrau> escadaLigas;

  const RankingResumo({
    required this.escopo,
    this.faixaTempo = '',
    this.divisao,
    this.podio = const [],
    this.escadaLigas = const [],
  });
}

/// Uma página da lista.
class RankingPagina {
  final List<RankingJogador> itens;

  /// Cursor opaco da próxima página. `null` quando não há próxima.
  final String? cursorProxima;

  /// Fim reconhecido pela fonte. Independe de a página vir vazia: uma fonte
  /// pode devolver página cheia e ainda assim dizer que acabou.
  final bool fim;

  const RankingPagina({
    required this.itens,
    this.cursorProxima,
    this.fim = false,
  });

  static const RankingPagina vazia =
      RankingPagina(itens: [], cursorProxima: null, fim: true);
}

/// Resposta da primeira chamada de um escopo: cabeçalho + primeira página numa
/// ida só, para a tela não ter dois estados de erro concorrentes.
class RankingAbertura {
  final RankingResumo resumo;
  final RankingPagina primeiraPagina;

  const RankingAbertura({required this.resumo, required this.primeiraPagina});
}

/// A fonte oficial não respondeu — ou ainda não existe.
///
/// É lançada, e não devolvida como lista vazia, justamente para que ninguém
/// confunda “não há ranking publicado” com “o ranking está vazio”.
class RankingIndisponivel implements Exception {
  /// Texto curto, já em português e exibível ao jogador.
  final String motivo;

  const RankingIndisponivel(this.motivo);

  @override
  String toString() => 'RankingIndisponivel: $motivo';
}
