// estado_tabela_ranking.dart — a TABELA do ranking como o cliente pode
// afirmá-la.
//
// ---------------------------------------------------------------------------
// A MESMA DISCIPLINA DE `EstadoRanking`, APLICADA A UMA LISTA
// ---------------------------------------------------------------------------
//
// `EstadoRanking` existe porque "não sei a liga" e "sei, e não há liga" são
// estados diferentes que a tela tratava como um só — e o resultado foi Liga
// Bronze para quem nunca jogou. Uma lista tem exatamente o mesmo par de
// armadilhas, e elas se parecem ainda mais entre si:
//
//   - "não perguntei" ......... [FaseRanking.indisponivel] — lista vazia
//   - "estou perguntando" ..... [FaseRanking.carregando]   — lista vazia
//   - "perguntei e deu erro" .. [FaseRanking.falha]        — lista vazia
//   - "recusaram" ............. [FaseRanking.acessoRecusado] — lista vazia
//   - "perguntei, e não há
//      ninguém classificado" ... [FaseRanking.disponivel]  — lista vazia
//
// Cinco estados, uma única lista vazia. Uma tela que olhasse só
// `itens.isEmpty` desenharia "ainda não há ninguém no ranking" para os cinco —
// e quatro deles seriam mentira, sendo que dois são erros que a pessoa poderia
// resolver apertando um botão que a tela teria escondido.
//
// Por isso a fase é o campo que manda, e a lista só é lida depois de ela dizer
// [FaseRanking.disponivel].
//
// ---------------------------------------------------------------------------
// A FASE É COMPARTILHADA COM `EstadoRanking`, E ISSO É DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// Não há um `FaseTabela` paralelo. `abrirRanking` é UMA ida: o cabeçalho do
// jogador e a tabela nascem da mesma resposta, falham pelo mesmo código e são
// recusados pela mesma credencial. Dois vocabulários de fase abririam a porta
// para a tela dizer "sua classificação não carregou" ao lado de uma lista
// desenhada como se estivesse boa.
//
// A tradução de falha para fase mora em `faseDaFalhaDeRanking`, e é a mesma
// função que `EstadoRanking.daFalha` usa.

import 'estado_ranking.dart';
import 'ranking_transporte.dart';

/// A tabela do ranking tal como o cliente pode afirmá-la.
class EstadoTabelaRanking {
  const EstadoTabelaRanking._({
    required this.fase,
    this.podio = const <JogadorPublicoRanking>[],
    this.primeiraPagina = const <JogadorPublicoRanking>[],
    this.temporadaId,
  });

  /// Em que ponto está o conhecimento sobre a tabela.
  final FaseRanking fase;

  /// O pódio publicado. SÓ TEM SENTIDO em [FaseRanking.disponivel] — nas outras
  /// fases é vazio porque não há nada, e não porque a tabela esteja vazia.
  final List<JogadorPublicoRanking> podio;

  /// A primeira página publicada, sob a mesma regra do pódio.
  final List<JogadorPublicoRanking> primeiraPagina;

  /// A temporada a que esta tabela pertence, quando a autoridade a informa.
  final String? temporadaId;

  /// Não há autoridade alcançável, ou ninguém perguntou ainda.
  const EstadoTabelaRanking.indisponivel()
    : this._(fase: FaseRanking.indisponivel);

  /// A consulta está em voo.
  const EstadoTabelaRanking.carregando() : this._(fase: FaseRanking.carregando);

  /// Falhou, e insistir pode resolver.
  const EstadoTabelaRanking.falha() : this._(fase: FaseRanking.falha);

  /// Recusado, sem se saber se foi credencial ou atestação.
  const EstadoTabelaRanking.acessoRecusado()
    : this._(fase: FaseRanking.acessoRecusado);

  /// Não há sessão local: a recusa É sobre a sessão.
  const EstadoTabelaRanking.sessaoInvalida()
    : this._(fase: FaseRanking.sessaoInvalida);

  /// A autoridade respondeu, e esta é a tabela dela.
  ///
  /// As listas entram COMO VIERAM — mesma ordem, mesmos jogadores, mesmos
  /// campos. Não há reordenação local, não há remoção de quem tem `posicao: 0`
  /// e não há corte por tamanho: quem decide a ordem e o recorte é
  /// `ordenacao.ts`, e um cliente que "arruma" a lista passa a ter uma segunda
  /// opinião sobre classificação.
  factory EstadoTabelaRanking.daTabela(
    TabelaRanking tabela, {
    String? temporadaId,
  }) => EstadoTabelaRanking._(
    fase: FaseRanking.disponivel,
    podio: tabela.podio,
    primeiraPagina: tabela.primeiraPagina,
    temporadaId: temporadaId,
  );

  /// A falha, traduzida para a fase que muda o que a tela oferece.
  factory EstadoTabelaRanking.daFalha(
    MotivoFalhaRanking motivo, {
    required bool haSessaoLocal,
  }) => switch (faseDaFalhaDeRanking(motivo, haSessaoLocal: haSessaoLocal)) {
    FaseRanking.indisponivel => const EstadoTabelaRanking.indisponivel(),
    FaseRanking.acessoRecusado => const EstadoTabelaRanking.acessoRecusado(),
    FaseRanking.sessaoInvalida => const EstadoTabelaRanking.sessaoInvalida(),
    FaseRanking.falha ||
    FaseRanking.carregando ||
    FaseRanking.disponivel => const EstadoTabelaRanking.falha(),
  };

  /// Há resposta da autoridade E ela não trouxe ninguém.
  ///
  /// Exige [FaseRanking.disponivel] na definição, e é essa exigência que impede
  /// a tela de anunciar "ninguém classificado ainda" enquanto carrega ou
  /// depois de um erro.
  bool get vaziaComResposta =>
      fase == FaseRanking.disponivel && podio.isEmpty && primeiraPagina.isEmpty;

  /// Há jogadores a desenhar.
  bool get temJogadores =>
      fase == FaseRanking.disponivel &&
      (podio.isNotEmpty || primeiraPagina.isNotEmpty);

  /// Insistir pode mudar o resultado. Mesma regra de [EstadoRanking].
  bool get podeTentarDeNovo =>
      fase == FaseRanking.falha || fase == FaseRanking.acessoRecusado;

  @override
  bool operator ==(Object outro) =>
      identical(this, outro) ||
      outro is EstadoTabelaRanking &&
          outro.fase == fase &&
          outro.temporadaId == temporadaId &&
          _mesmaLista(outro.podio, podio) &&
          _mesmaLista(outro.primeiraPagina, primeiraPagina);

  @override
  int get hashCode => Object.hash(
    fase,
    temporadaId,
    Object.hashAll(podio),
    Object.hashAll(primeiraPagina),
  );

  /// Igualdade ELEMENTO A ELEMENTO, e não por identidade da lista.
  ///
  /// Cada resposta produz listas novas; comparar por identidade faria toda
  /// releitura parecer mudança, e quem escuta o estado notificaria a árvore
  /// inteira a cada vez — inclusive quando a resposta é idêntica à anterior.
  /// `listEquals` do Flutter faria o mesmo, mas este arquivo é domínio puro e
  /// não importa Flutter, pela mesma razão que `ranking_transporte.dart`.
  static bool _mesmaLista(
    List<JogadorPublicoRanking> a,
    List<JogadorPublicoRanking> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'EstadoTabelaRanking(${fase.name}, podio: ${podio.length}, '
      'pagina: ${primeiraPagina.length}, temporada: $temporadaId)';
}

/// O que a casca consegue afirmar sobre a TABELA quando não há leitor.
///
/// Espelha `rankingDaCascaPublicavel`: fora do escopo não há autoridade, e o
/// valor correto é "não sei" — nunca uma lista vazia com cara de ranking vazio.
const EstadoTabelaRanking tabelaDaCascaPublicavel =
    EstadoTabelaRanking.indisponivel();
