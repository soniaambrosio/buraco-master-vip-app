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
//
// ---------------------------------------------------------------------------
// E QUANDO O BACKEND CHEGOU
// ---------------------------------------------------------------------------
//
// Chegou, e não reabriu nada — porque o contrato real publica exatamente os
// dois valores que a higienização acima já esperava: `posicao: 0` para quem
// ainda não foi apurado (`POSICAO_NAO_APURADA`) e `liga: ''` quando não há
// escada. A tradução de `FotografiaRanking` para cá mora nas fábricas
// [EstadoRanking.daFotografia] e [EstadoRanking.daFalha], e é a ÚNICA do app: o
// leitor não interpreta, ele encaminha. É o que mantém verdadeira a auditoria
// "a interpretação de 'sem ranking' mora num lugar só" mesmo agora que existe
// autoridade do outro lado.

import 'ranking_transporte.dart';

/// Em que ponto está o conhecimento do cliente sobre o ranking do jogador.
///
/// As fases são estados DISTINTOS de propósito: "ainda não perguntei", "estou
/// perguntando", "perguntei e deu erro" e "tenho a resposta" levam a
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

  /// A autoridade recusou por credencial: não há sessão, ela expirou, ou a
  /// leitura foi negada para esta conta.
  ///
  /// Separada de [falha] porque a AÇÃO é outra. Numa falha recuperável, tentar
  /// de novo é a coisa certa e o botão diz isso; aqui, insistir só repete a
  /// recusa — quem resolve é entrar na conta de novo. Oferecer "tentar
  /// novamente" para uma sessão morta é prometer o que o botão não cumpre.
  sessaoInvalida,
}

/// O estado competitivo do jogador tal como o cliente pode afirmá-lo.
class EstadoRanking {
  /// Em que ponto está o conhecimento sobre o ranking.
  final FaseRanking fase;

  // Guardados crus e PRIVADOS. O que sai daqui passa pelos getters.
  final String? _liga;
  final int? _posicaoMundial;

  /// O id estável da Liga (`bronze`, `prata`, …), quando o rótulo É uma Liga.
  ///
  /// NULO durante colocação e revalidação, porque nesses casos [liga] carrega um
  /// ESTADO (`Em colocacao`) e não o nome de uma Liga. É o que permite a tela
  /// decidir se o prefixo "Liga" cabe na frente do rótulo sem manter uma lista
  /// local de nomes — que é justamente o que o Caso A da OS proíbe.
  final String? ligaId;

  /// A temporada a que esta fotografia pertence.
  ///
  /// Não é exibida em lugar nenhum hoje. Existe porque uma fotografia SEM
  /// temporada não pode ser guardada em cache com honestidade: sem ela não há
  /// como saber que a virada de temporada tornou o valor guardado obsoleto, e
  /// misturar duas temporadas é afirmar uma colocação que não existe mais.
  final String? temporadaId;

  const EstadoRanking._({
    required this.fase,
    String? liga,
    int? posicaoMundial,
    this.ligaId,
    this.temporadaId,
  }) : _liga = liga,
       _posicaoMundial = posicaoMundial;

  /// Não há autoridade de ranking, ou ela não foi consultada.
  const EstadoRanking.indisponivel({String? temporadaId})
    : this._(fase: FaseRanking.indisponivel, temporadaId: temporadaId);

  /// A consulta está em voo.
  const EstadoRanking.carregando() : this._(fase: FaseRanking.carregando);

  /// A consulta falhou, e insistir pode resolver.
  const EstadoRanking.falha() : this._(fase: FaseRanking.falha);

  /// A credencial não serve: sem sessão, expirada ou recusada.
  const EstadoRanking.sessaoInvalida()
    : this._(fase: FaseRanking.sessaoInvalida);

  /// A autoridade respondeu.
  ///
  /// Os parâmetros são opcionais porque uma resposta legítima pode não conter
  /// nenhum deles — é o caso do jogador que ainda não entrou na tabela. Passar
  /// `liga: ''` ou `posicaoMundial: 0` é o mesmo que não passar: os getters
  /// higienizam.
  const EstadoRanking.disponivel({
    String? liga,
    int? posicaoMundial,
    String? ligaId,
    String? temporadaId,
  }) : this._(
         fase: FaseRanking.disponivel,
         liga: liga,
         posicaoMundial: posicaoMundial,
         ligaId: ligaId,
         temporadaId: temporadaId,
       );

  /// O que a autoridade disse, traduzido para o que se pode afirmar.
  ///
  /// É a ÚNICA porta de entrada de dado real, e ela é rasa de propósito: não
  /// deduz liga a partir de pontuação, não completa temporada ausente e não
  /// corrige colocação estranha — só entrega os valores crus aos getters, que
  /// já sabiam recusar zero e vazio antes de existir backend.
  factory EstadoRanking.daFotografia(FotografiaRanking foto) =>
      EstadoRanking.disponivel(
        liga: foto.rotuloLiga,
        posicaoMundial: foto.posicao,
        ligaId: foto.ligaId,
        temporadaId: foto.temporadaId,
      );

  /// A falha, traduzida para a fase que muda o que a tela oferece.
  ///
  /// `semTemporada` vira [FaseRanking.indisponivel] e não [FaseRanking.falha]
  /// porque não é erro: a autoridade respondeu, e a resposta foi "não há
  /// temporada em andamento". Chamar isso de falha poria um botão de tentar de
  /// novo na frente de uma ausência que nenhuma insistência muda.
  ///
  /// `naoEncontrado` também vira indisponível: um id público sem colocação
  /// nenhuma não é um defeito, é um perfil que não está na tabela.
  factory EstadoRanking.daFalha(MotivoFalhaRanking motivo) => switch (motivo) {
    MotivoFalhaRanking.semTemporada ||
    MotivoFalhaRanking.naoEncontrado => const EstadoRanking.indisponivel(),
    MotivoFalhaRanking.naoAutenticado ||
    MotivoFalhaRanking.recusado => const EstadoRanking.sessaoInvalida(),
    MotivoFalhaRanking.indisponivel ||
    MotivoFalhaRanking.respostaInvalida ||
    MotivoFalhaRanking.desconhecida => const EstadoRanking.falha(),
  };

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

  /// O rótulo é o nome de uma Liga, e não um estado de qualificação.
  ///
  /// O backend usa o MESMO campo para os dois: `'Bronze'` é Liga, `'Em
  /// colocacao'` não é. Quem distingue é `ligaId`, que vem nulo no segundo caso.
  /// A tela precisa saber porque o prefixo fixo "Liga" só cabe na frente do
  /// primeiro — "Liga Em colocacao" não é português.
  bool get ehLigaDeVerdade => temLiga && ligaId != null;

  /// Insistir pode mudar o resultado.
  ///
  /// Só a falha recuperável. Ausência declarada não vira botão (não há o que
  /// tentar) e sessão inválida também não (tentar de novo repete a recusa).
  bool get podeTentarDeNovo => fase == FaseRanking.falha;

  @override
  bool operator ==(Object outro) =>
      identical(this, outro) ||
      outro is EstadoRanking &&
          outro.fase == fase &&
          outro.liga == liga &&
          outro.posicaoMundial == posicaoMundial &&
          outro.ligaId == ligaId &&
          outro.temporadaId == temporadaId;

  @override
  int get hashCode =>
      Object.hash(fase, liga, posicaoMundial, ligaId, temporadaId);

  @override
  String toString() =>
      'EstadoRanking(${fase.name}, liga: $liga, posicao: $posicaoMundial, '
      'ligaId: $ligaId, temporada: $temporadaId)';
}

/// O que a casca consegue afirmar sobre ranking QUANDO NÃO HÁ LEITOR.
///
/// Continua existindo, e continua sendo uma só, porque nem toda montagem da
/// casca tem transporte: uma tela aberta num teste de widget, ou a casca antes
/// de o escopo de ranking existir, precisa de um valor — e o valor certo é
/// "não sei", nunca uma liga.
///
/// O que MUDOU com o leitor real: este valor deixou de ser o único produtor.
/// Agora ele é o piso — o que vale enquanto ninguém perguntou —, e quem
/// pergunta recebe [EstadoRanking.daFotografia] ou [EstadoRanking.daFalha]. As
/// duas superfícies continuam lendo a mesma decisão; ela só passou a ter uma
/// fonte a mais, e ambas moram neste arquivo.
const EstadoRanking rankingDaCascaPublicavel = EstadoRanking.indisponivel();
