// ranking_da_sessao.dart — o estado competitivo do jogador logado, vivo.
//
// ---------------------------------------------------------------------------
// POR QUE UM NOTIFIER, E NÃO CADA TELA CHAMANDO O LEITOR
// ---------------------------------------------------------------------------
//
// Home e Perfil mostram o MESMO fato — a liga de quem está logado. Se cada uma
// perguntasse por conta própria, seriam duas chamadas, dois relógios e duas
// oportunidades de discordar: a Home mostrando Ouro enquanto o Perfil ainda diz
// carregando é o mesmo defeito da OS anterior com roupa nova, porque de novo
// haveria duas superfícies decidindo sozinhas o que exibir.
//
// Aqui há um estado só. Quem quiser mostrar liga escuta este notifier; quem
// quiser recarregar chama [recarregar]. As duas telas não podem divergir porque
// não há duas coisas para divergir.
//
// ---------------------------------------------------------------------------
// A SESSÃO MANDA, E ESTE ARQUIVO OBEDECE
// ---------------------------------------------------------------------------
//
// Este notifier não assina a sessão nem sabe o que é login: a casca já assina, e
// duas assinaturas do mesmo evento produziriam duas ordens de execução. A casca
// avisa por [aoMudarSessao], e é o `publicId` que dispara a leitura — não o uid,
// que é identidade interna e não sai daqui.

import 'package:flutter/foundation.dart';

import 'estado_ranking.dart';
import 'estado_tabela_ranking.dart';
import 'leitor_ranking.dart';

class RankingDaSessao extends ChangeNotifier {
  RankingDaSessao({required LeitorDeRanking leitor}) : _leitor = leitor;

  final LeitorDeRanking _leitor;

  /// O leitor, para quem precisa consultar OUTRO jogador.
  ///
  /// Exposto porque o ranking de um perfil visitado não pertence a este estado
  /// — ele é de outra pessoa e não pode entrar em [meuEstado] nem no cabeçalho
  /// da Home. Quem visita usa o leitor direto e guarda o resultado na própria
  /// tela, que morre quando ela fecha.
  LeitorDeRanking get leitor => _leitor;

  /// O estado competitivo do jogador autenticado.
  ///
  /// Começa em [rankingDaCascaPublicavel] — "ninguém perguntou ainda" —, que é
  /// o mesmo valor de quando não havia leitor nenhum. Não é um lugar reservado
  /// para uma liga: é a afirmação de que não há afirmação.
  EstadoRanking get meuEstado => _meuEstado;
  EstadoRanking _meuEstado = rankingDaCascaPublicavel;

  /// A tabela publicada na MESMA abertura que produziu [meuEstado].
  ///
  /// -------------------------------------------------------------------------
  /// POR QUE ELA MORA AQUI, E NÃO NA TELA QUE A DESENHA
  /// -------------------------------------------------------------------------
  ///
  /// Pelo mesmo motivo que [meuEstado]: uma tela que perguntasse por conta
  /// própria abriria uma segunda chamada de `abrirRanking` — a mesma callable,
  /// a mesma resposta — e as duas leituras poderiam divergir. Pior: o cabeçalho
  /// do Perfil e a lista do ranking mostrariam apurações diferentes da mesma
  /// temporada, e não haveria como dizer qual das duas está certa.
  ///
  /// Como as duas saem de [LeituraDeAbertura], elas são a MESMA resposta por
  /// construção. Não há caminho em que divirjam.
  EstadoTabelaRanking get tabela => _tabela;
  EstadoTabelaRanking _tabela = tabelaDaCascaPublicavel;

  String? _publicId;
  int _geracao = 0;
  bool _descartado = false;

  /// A casca avisa que a sessão mudou.
  ///
  /// Três eventos passam por aqui e têm desfechos diferentes:
  ///
  ///   - **logout** (`publicId == null`): volta ao piso e NÃO consulta. Sem
  ///     conta não há ranking a pedir, e pedir devolveria `unauthenticated`
  ///     como se fosse um problema.
  ///   - **troca de conta**: o estado anterior morre ANTES de a nova leitura
  ///     começar. Nem um frame com a liga de quem saiu.
  ///   - **mesma conta, mesma geração**: nada acontece. Um rebuild não é uma
  ///     pergunta, e esta é a linha que impede a rotação da tela de virar
  ///     rajada de chamadas.
  void aoMudarSessao({required int geracao, required String? publicId}) {
    if (_descartado) return;
    final mesmaSessao = geracao == _geracao && publicId == _publicId;
    if (mesmaSessao) return;

    _geracao = geracao;
    _publicId = publicId;
    _leitor.aoMudarSessao(geracao);

    if (publicId == null) {
      // A TABELA VAI JUNTO. Deixá-la de pé depois do logout manteria na tela
      // uma lista de jogadores lida em nome de uma conta que não existe mais —
      // e, com ela, os `publicPlayerId` que aquela lista carregava.
      _publicar(rankingDaCascaPublicavel, tabelaDaCascaPublicavel);
      return;
    }
    _consultar(publicId);
  }

  /// Retry explícito, nascido de um gesto.
  ///
  /// Idempotente por baixo: o leitor dedupa voos por chave, então apertar duas
  /// vezes não abre duas chamadas — mesma garantia que
  /// `SessaoDoJogador.recarregar` já dá para a identidade.
  Future<void> recarregar() async {
    final publicId = _publicId;
    if (_descartado || publicId == null) return;
    await _consultar(publicId);
  }

  Future<void> _consultar(String publicId) async {
    _publicar(
      const EstadoRanking.carregando(),
      const EstadoTabelaRanking.carregando(),
    );
    final resultado = await _leitor.abrirRanking(contaPublicId: publicId);
    // `null` é DESCARTE: a resposta perdeu a validade no caminho. Não publicar
    // é a reação certa — publicar qualquer coisa aqui seria escolher entre
    // apagar o que está na tela e mostrar dado de outra sessão.
    if (resultado == null || _descartado) return;
    _publicar(resultado.eu, resultado.tabela);
  }

  /// Publica os dois JUNTOS, e nunca um sem o outro.
  ///
  /// Um `_publicar` por campo abriria a janela em que a tela lê o cabeçalho
  /// novo ao lado da tabela velha — um quadro inteiro de leitura inconsistente,
  /// que é tempo de sobra para um toque acontecer.
  void _publicar(EstadoRanking estado, EstadoTabelaRanking tabela) {
    if (_meuEstado == estado && _tabela == tabela) return;
    _meuEstado = estado;
    _tabela = tabela;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
