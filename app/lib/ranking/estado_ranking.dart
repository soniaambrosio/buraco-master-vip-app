// estado_ranking.dart — o estado competitivo do jogador, como um valor só.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE
// ---------------------------------------------------------------------------
//
// Liga e colocação eram dois campos crus espalhados por três superfícies, e cada
// uma inventava o seu próprio fallback quando o dado não vinha:
//
//   - a Home mandava `liga: null` e omitia a linha — correto;
//   - o Perfil recebia do serviço `liga: 'Bronze'` e `posicaoMundial: 0`, e
//     desenhava `💎 Liga Bronze · #0 no mundo`;
//   - o texto de compartilhamento tinha um TERCEIRO fallback, `?? 'Bronze'`, e
//     copiava a mentira para fora do aparelho.
//
// Três leituras do MESMO estado — "não há autoridade de ranking" — e duas delas
// afirmando uma liga que ninguém atribuiu a ninguém. Ausência de ranking não é
// Liga Bronze; posição zero não é colocação. Um jogador que nunca disputou nada
// não está em último lugar do mundo, ele está FORA da tabela.
//
// A correção não é consertar cada fallback no lugar onde ele aparece — é tirar
// de todos eles o direito de ter fallback. `EstadoRanking` é o único lugar que
// decide o que pode ser afirmado, e Home, Perfil e compartilhamento passam a
// apenas perguntar.
//
// ---------------------------------------------------------------------------
// A REGRA
// ---------------------------------------------------------------------------
//
// Os getters [liga] e [posicaoMundial] devolvem `null` sempre que o valor não
// for uma afirmação competitiva válida — e isso inclui o caso em que a fonte
// mandou algo. Uma liga em branco não é liga; uma colocação `0` ou negativa não
// é colocação. A higienização mora AQUI, e não em cada tela, justamente para que
// o dia em que o backend de ranking chegar com um zero no lugar de um ausente
// não reabra o defeito por uma porta nova.
//
// Quem desenha nunca vê o valor bruto. Não há como uma tela ler `0` deste
// objeto e decidir sozinha que aquilo dá `#0`.

/// Em que ponto está o conhecimento do cliente sobre o ranking do jogador.
///
/// As quatro fases são estados DISTINTOS de propósito: "ainda não perguntei",
/// "estou perguntando", "perguntei e deu erro" e "tenho a resposta" levam a
/// tratamentos visuais diferentes, e colapsá-los foi o que produziu o Bronze.
enum FaseRanking {
  /// Não existe autoridade de ranking alcançável, ou ela ainda não foi
  /// consultada. É o estado da casca publicável hoje.
  indisponivel,

  /// A consulta está em voo.
  carregando,

  /// A consulta terminou em erro. Diferente de [indisponivel]: aqui há
  /// autoridade, e ela não respondeu.
  falha,

  /// Há resposta da autoridade. Isso NÃO garante que exista liga ou colocação:
  /// um jogador recém-chegado pode estar corretamente fora da tabela.
  disponivel,
}

/// O estado competitivo do jogador tal como o cliente pode afirmá-lo.
class EstadoRanking {
  /// Em que ponto está o conhecimento sobre o ranking.
  final FaseRanking fase;

  // Guardados crus e PRIVADOS. O que sai daqui passa pelos getters.
  final String? _liga;
  final int? _posicaoMundial;

  const EstadoRanking._({required this.fase, String? liga, int? posicaoMundial})
    : _liga = liga,
      _posicaoMundial = posicaoMundial;

  /// Não há autoridade de ranking, ou ela não foi consultada.
  const EstadoRanking.indisponivel() : this._(fase: FaseRanking.indisponivel);

  /// A consulta está em voo.
  const EstadoRanking.carregando() : this._(fase: FaseRanking.carregando);

  /// A consulta falhou.
  const EstadoRanking.falha() : this._(fase: FaseRanking.falha);

  /// A autoridade respondeu.
  ///
  /// Os dois parâmetros são opcionais porque uma resposta legítima pode não
  /// conter nenhum dos dois — é o caso do jogador que ainda não entrou na
  /// tabela. Passar `liga: ''` ou `posicaoMundial: 0` é o mesmo que não passar:
  /// os getters higienizam.
  const EstadoRanking.disponivel({String? liga, int? posicaoMundial})
    : this._(
        fase: FaseRanking.disponivel,
        liga: liga,
        posicaoMundial: posicaoMundial,
      );

  /// A liga, quando existe uma para afirmar. `null` em qualquer outro caso.
  ///
  /// Fora de [FaseRanking.disponivel] não há liga nenhuma — nem uma padrão, nem
  /// a última conhecida. Dentro dela, uma string vazia ou só de espaços é
  /// ausência, e não um nome de liga.
  String? get liga {
    if (fase != FaseRanking.disponivel) return null;
    final valor = _liga?.trim() ?? '';
    return valor.isEmpty ? null : valor;
  }

  /// A colocação mundial, quando é uma colocação de verdade. `null` no resto.
  ///
  /// Colocação começa em 1. `0` é o valor que o serviço usava para dizer "não
  /// sei", e negativo não significa nada — os dois viram ausência aqui, e é o
  /// que impede `#0` de voltar à tela por qualquer caminho.
  int? get posicaoMundial {
    if (fase != FaseRanking.disponivel) return null;
    final valor = _posicaoMundial;
    if (valor == null || valor < 1) return null;
    return valor;
  }

  /// Há liga a exibir.
  bool get temLiga => liga != null;

  /// Há colocação a exibir.
  bool get temPosicao => posicaoMundial != null;

  /// Há alguma informação competitiva a exibir.
  ///
  /// Falso tanto para "não sei" quanto para "sei, e a pessoa não está na
  /// tabela" — porque a tela faz a mesma coisa nos dois casos: não afirma nada.
  bool get temAlgumDado => temLiga || temPosicao;

  /// O texto da liga para um lugar da tela que precisa ocupar espaço.
  ///
  /// O travessão é uma ausência ADMITIDA: ele não se parece com um nome de liga
  /// e ninguém o lê como conquista. Serve ao rótulo fixo do Perfil, que fica no
  /// lugar para não deslocar o cabeçalho. Onde a linha inteira pode sumir — a
  /// Home, o compartilhamento — use [liga] e omita.
  String get ligaParaExibicao => liga ?? '—';

  @override
  bool operator ==(Object outro) =>
      identical(this, outro) ||
      outro is EstadoRanking &&
          outro.fase == fase &&
          outro.liga == liga &&
          outro.posicaoMundial == posicaoMundial;

  @override
  int get hashCode => Object.hash(fase, liga, posicaoMundial);

  @override
  String toString() =>
      'EstadoRanking(${fase.name}, liga: $liga, posicao: $posicaoMundial)';
}

/// O que a casca publicável consegue afirmar sobre ranking HOJE: nada.
///
/// Esta linhagem não tem autoridade de ranking alcançável pelo cliente. O
/// backend existe (`functions-ranking`), mas nenhuma tela desta casca fala com
/// ele — o item "Ranking" da Home está apagado e avisa que não está disponível.
///
/// A constante é uma só, e Home e Perfil leem ESTA, para que não haja como uma
/// superfície entender "sem ranking" de um jeito e a outra de outro. No dia em
/// que a autoridade chegar, quem passa a produzir [EstadoRanking] é ela, e este
/// valor deixa de ser lido — nenhuma tela precisa mudar.
const EstadoRanking rankingDaCascaPublicavel = EstadoRanking.indisponivel();
