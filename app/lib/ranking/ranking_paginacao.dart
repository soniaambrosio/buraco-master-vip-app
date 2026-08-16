// ranking_paginacao.dart — a máquina de estados da lista de Ranking.
//
// Fica separada da tela de propósito: paginação, deduplicação, refresh,
// concorrência e descarte são exatamente as regras da OS §10/§11, e é muito
// mais honesto testá-las sem widget no meio.
//
// O que ela NÃO faz, e não pode passar a fazer: ordenar, recalcular posição,
// somar ponto, decidir liga, disparar premiação ou escrever qualquer estado
// oficial. Ela acumula o que a fonte devolveu, na ordem em que devolveu.

import 'ranking_contract.dart';
import '../services/ranking_service.dart';

/// Situação da lista, do ponto de vista de quem desenha.
enum RankingFase {
  /// Ainda não pediu nada.
  inicial,

  /// Primeira carga (ou recarga) em voo.
  carregando,

  /// Tem conteúdo para mostrar.
  pronto,

  /// A fonte respondeu, e não há ninguém neste escopo.
  vazio,

  /// A fonte não respondeu.
  erro,
}

/// Acumula as páginas de **um** escopo de ranking.
///
/// Cada aba da tela tem o seu paginador; trocar de aba não mistura listas nem
/// refaz a busca da aba anterior.
class RankingPaginador {
  RankingPaginador({required this.service, required this.escopo});

  final RankingService service;
  final RankingEscopo escopo;

  final List<RankingJogador> _itens = [];
  final Set<String> _chaves = <String>{};

  RankingResumo? _resumo;
  String? _cursor;
  bool _fim = false;

  RankingFase _fase = RankingFase.inicial;
  String? _mensagemErro;
  String? _erroDePagina;

  bool _emVoo = false;
  bool _carregandoMais = false;
  bool _descartado = false;

  /// Cada abertura/recarga recebe um número. Resposta que chega com número
  /// velho é de um pedido que já não interessa — e é jogada fora em vez de
  /// duplicar item ou ressuscitar tela descartada.
  int _geracao = 0;

  RankingFase get fase => _fase;
  String? get mensagemErro => _mensagemErro;

  /// Erro ao buscar uma página **posterior**. Fica separado de [mensagemErro]
  /// justamente para não apagar o que já estava carregado (OS §10).
  String? get erroDePagina => _erroDePagina;

  RankingResumo? get resumo => _resumo;
  List<RankingJogador> get itens => List.unmodifiable(_itens);

  bool get temMais => !_fim && _cursor != null;
  bool get carregandoMais => _carregandoMais;
  bool get ocupado => _emVoo || _carregandoMais;
  bool get descartado => _descartado;

  /// Primeira carga do escopo. **Idempotente**: voltar para a tela, reconstruir
  /// o widget ou chamar duas vezes não dispara busca repetida nem duplica item.
  Future<void> abrir() {
    if (_descartado) return Future<void>.value();
    if (_fase != RankingFase.inicial) return Future<void>.value();
    return _abrirDoZero();
  }

  /// Pull-to-refresh e “tentar de novo”. Substitui o conteúdo em vez de
  /// concatenar — por isso refresh nunca duplica jogador.
  Future<void> recarregar() {
    if (_descartado) return Future<void>.value();
    return _abrirDoZero();
  }

  Future<void> _abrirDoZero() async {
    final geracao = ++_geracao;
    _emVoo = true;
    _carregandoMais = false;
    _fase = RankingFase.carregando;
    _mensagemErro = null;
    _erroDePagina = null;

    try {
      final abertura = await service.abrir(escopo);
      if (_ignorar(geracao)) return;

      _itens.clear();
      _chaves.clear();
      _resumo = abertura.resumo;
      _absorver(abertura.primeiraPagina);
      _fase = _vazio ? RankingFase.vazio : RankingFase.pronto;
    } catch (e) {
      if (_ignorar(geracao)) return;
      _mensagemErro = _motivo(e);
      _fase = RankingFase.erro;
    } finally {
      if (geracao == _geracao) _emVoo = false;
    }
  }

  /// Próxima página. Chamada concorrente é ignorada — rolar rápido ou tocar
  /// duas vezes em “Carregar mais” não dispara duas buscas iguais.
  Future<void> carregarMais() async {
    if (_descartado || _carregandoMais || _emVoo) return;
    final cursor = _cursor;
    if (_fim || cursor == null) return;

    final geracao = _geracao;
    _carregandoMais = true;
    _erroDePagina = null;

    try {
      final pagina = await service.proximaPagina(escopo, cursor);
      if (_ignorar(geracao)) return;
      _absorver(pagina);
      if (_fase != RankingFase.pronto && !_vazio) _fase = RankingFase.pronto;
    } catch (e) {
      if (_ignorar(geracao)) return;
      // O que já veio continua na tela; só a página nova falhou. O cursor
      // permanece, então tocar de novo tenta a MESMA página.
      _erroDePagina = _motivo(e);
    } finally {
      if (geracao == _geracao) _carregandoMais = false;
    }
  }

  /// Desmonta. Respostas que ainda estiverem viajando são descartadas ao
  /// chegar, em vez de mexer em estado de tela que já saiu.
  void descartar() {
    _descartado = true;
    _geracao++;
    _emVoo = false;
    _carregandoMais = false;
  }

  bool get _vazio => _itens.isEmpty && (_resumo?.podio.isEmpty ?? true);

  bool _ignorar(int geracao) => _descartado || geracao != _geracao;

  /// Acrescenta a página preservando a ordem de chegada e descartando quem já
  /// está na lista. É aqui que mora a garantia de “sem jogador repetido entre
  /// páginas”.
  void _absorver(RankingPagina pagina) {
    for (final jogador in pagina.itens) {
      if (_chaves.add(jogador.chave)) _itens.add(jogador);
    }
    _cursor = pagina.cursorProxima;
    _fim = pagina.fim || pagina.cursorProxima == null;
  }

  String _motivo(Object erro) {
    if (erro is RankingIndisponivel) return erro.motivo;
    return 'Não consegui carregar o ranking agora.';
  }
}
