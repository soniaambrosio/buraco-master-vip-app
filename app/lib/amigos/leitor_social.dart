// leitor_social.dart — quem fala com o grafo social, e o único que fala.
//
// Mesmo desenho de `ranking/leitor_ranking.dart`, e pelas mesmas razões: uma
// autoridade remota, várias superfícies lendo, e um punhado de casos que só
// aparecem quando a resposta demora — pedido vencido, troca de conta no meio do
// voo, três toques em "tentar de novo" virando três chamadas.
//
// ---------------------------------------------------------------------------
// O CLIENTE NÃO GUARDA GRAFO — E ESTA É A REGRA QUE ORGANIZA O ARQUIVO
// ---------------------------------------------------------------------------
//
// O que mora aqui são PÁGINAS que o servidor devolveu, e nada mais. Não existe
// um conjunto de arestas, não existe `Map<publicId, éMeuAmigo>`, e não existe
// nenhuma função que responda "somos amigos?" a partir do que está em memória.
// Quem responde isso é `verPerfilPublico`, sempre.
//
// A tentação é óbvia e o preço é conhecido: com um mapa local, aceitar um
// pedido viraria "mover o item da lista A para a lista B", que é rápido, é
// bonito e está errado na hora em que o mesmo jogador aceitou pelo tablet — a
// tela mostraria uma amizade que o banco não tem, ou esconderia uma que tem.
// Pior: para desenhar os botões da linha movida seria preciso DEDUZIR as ações
// a partir do estado, e a dedução ignora bloqueio e sanção, que o servidor
// conhece e o cliente não.
//
// Então depois de cada ação aceita este leitor faz duas coisas, nessa ordem:
//
//   1. SUBTRAI a linha da lista onde ela estava. Subtrair é seguro porque a
//      autoridade acabou de dizer que aquela pendência não existe mais; a
//      alternativa (deixar a linha) mostraria um botão que responderia
//      `repeticao` para sempre.
//   2. RELÊ `verPerfilPublico` daquele jogador, e é dessa resposta — não de
//      dedução local — que saem a relação e as ações novas.
//
// Nenhuma das duas ADICIONA jogador a lista nenhuma. Quem entra na lista de
// amigos é a próxima leitura de `listarAmigos`, e por isso [aposAcao] marca as
// listas como vencidas.
//
// ---------------------------------------------------------------------------
// A GERAÇÃO DE SESSÃO
// ---------------------------------------------------------------------------
//
// Igual ao leitor de ranking: quem assina a sessão é a casca, e ela avisa aqui
// por [aoMudarSessao]. Tudo o que estava em voo perde o direito de ser aplicado
// e as listas são esvaziadas — a lista de amigos de A não pode aparecer para B
// nem por um quadro.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'estado_social.dart';
import 'transporte_social.dart';

/// Em que ponto da vida uma lista social está.
///
/// [naoCarregada] e [pronta] com lista vazia são coisas DIFERENTES, e é para
/// isso que a fase existe: a primeira desenha um carregando, a segunda desenha
/// "você ainda não tem amigos". Uma tela que olhasse `itens.isEmpty` diria a
/// segunda frase nos quatro casos, inclusive quando a consulta falhou.
enum FaseSocial { naoCarregada, carregando, pronta, falha }

/// O estado de UMA lista social (amigos, recebidas ou enviadas).
@immutable
class ListaSocial {
  const ListaSocial({
    this.fase = FaseSocial.naoCarregada,
    this.pagina = PaginaSocial.vazia,
    this.falha,
    this.carregandoMais = false,
  });

  final FaseSocial fase;
  final PaginaSocial pagina;
  final FalhaSocial? falha;

  /// Uma página SEGUINTE está em voo. Separado de [fase] de propósito: durante
  /// o "carregar mais" a lista continua pronta e visível, e trocar a fase faria
  /// a tela piscar de volta para o esqueleto.
  final bool carregandoMais;

  List<JogadorPublico> get itens => pagina.itens;
  bool get temMais => pagina.temMais;
  bool get vaziaEConfirmada =>
      fase == FaseSocial.pronta && pagina.itens.isEmpty;

  /// Vale oferecer "tentar de novo"?
  bool get podeTentarDeNovo =>
      fase == FaseSocial.falha && (falha?.transitoria ?? false);

  ListaSocial _com({
    FaseSocial? fase,
    PaginaSocial? pagina,
    FalhaSocial? falha,
    bool? carregandoMais,
    bool limparFalha = false,
  }) => ListaSocial(
    fase: fase ?? this.fase,
    pagina: pagina ?? this.pagina,
    falha: limparFalha ? null : (falha ?? this.falha),
    carregandoMais: carregandoMais ?? this.carregandoMais,
  );
}

/// Qual lista social.
enum QualLista { amigos, recebidas, enviadas }

/// O estado da busca por apelido.
@immutable
class BuscaSocial {
  const BuscaSocial({
    this.fase = FaseSocial.naoCarregada,
    this.termo = '',
    this.resultados,
    this.falha,
  });

  final FaseSocial fase;

  /// O termo do pedido MAIS RECENTE — o que a pessoa quer ver, não o que já
  /// chegou. Comparar com `resultados?.termo` é como a tela sabe que o que está
  /// na tela ainda é do que está escrito.
  final String termo;

  final ResultadosDeBusca? resultados;
  final FalhaSocial? falha;

  bool get emVoo => fase == FaseSocial.carregando;

  /// A busca respondeu, e não achou ninguém.
  ///
  /// SÓ com [FaseSocial.pronta]: sem a fase, "ninguém encontrado" apareceria
  /// enquanto a consulta ainda corria e também depois de ela falhar.
  bool get semResultados =>
      fase == FaseSocial.pronta && (resultados?.vazio ?? false);
}

/// Como uma ação social terminou.
@immutable
class RespostaDeAcao {
  const RespostaDeAcao({required this.desfecho, required this.vista});

  final DesfechoSocial desfecho;

  /// A vista da relação DEPOIS da ação, relida da autoridade.
  ///
  /// `null` quando a releitura não foi possível — o jogador deixou de ser
  /// exponível, ou a rede caiu entre uma chamada e outra. Nulo NÃO é motivo
  /// para deduzir a relação: a tela mostra a linha sem botões e a próxima
  /// abertura resolve.
  final ResultadoSocial? vista;

  /// O desfecho pedido já valia. Sucesso, e não erro.
  bool get repeticao => desfecho.repeticao;
}

/// O leitor do grafo social da sessão.
class LeitorSocial extends ChangeNotifier {
  LeitorSocial({required TransporteSocial transporte})
    : _transporte = transporte;

  final TransporteSocial _transporte;

  int _geracao = 0;
  int _sequencia = 0;

  /// O número do último pedido emitido por lista. Só o mais recente tem direito
  /// de responder — uma resposta atrasada que chega depois de um recarregar é
  /// descartada em vez de sobrescrever o que já está na tela.
  final Map<QualLista, int> _ultimoPedido = <QualLista, int>{};

  /// Pedidos em voo por lista, para que três toques em "tentar de novo" não
  /// abram três chamadas.
  final Map<QualLista, Future<void>> _emVoo = <QualLista, Future<void>>{};

  final Map<QualLista, ListaSocial> _listas = <QualLista, ListaSocial>{
    QualLista.amigos: const ListaSocial(),
    QualLista.recebidas: const ListaSocial(),
    QualLista.enviadas: const ListaSocial(),
  };

  BuscaSocial _busca = const BuscaSocial();
  int _ultimaBusca = 0;

  /// Quantas chamadas de transporte foram realmente emitidas. Diagnóstico de
  /// teste — nunca um número de produto.
  int get chamadasEmitidas => _chamadas;
  int _chamadas = 0;

  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }

  /// Notifica DEPOIS do trecho síncrono em curso.
  ///
  /// -------------------------------------------------------------------------
  /// POR QUE NÃO É `notifyListeners()` DIRETO
  /// -------------------------------------------------------------------------
  ///
  /// Porque quem começa uma consulta é a tela, e a tela começa em
  /// `didChangeDependencies` — que roda DENTRO da construção da árvore. Um
  /// `notifyListeners()` ali marca o `EscopoSocial` como sujo no meio do
  /// próprio `build`, e o framework lança "setState() or markNeedsBuild()
  /// called during build". Não é um aviso cosmético: a árvore ficaria com um
  /// ancestral sujo que aquele quadro já passou, e o estado publicado só
  /// apareceria no quadro seguinte, por acidente.
  ///
  /// O ranking resolveu o mesmo problema por outro caminho — quem dispara lá é
  /// um listener da sessão, nunca um `build` (ver o comentário em
  /// `raiz_do_aplicativo.dart`). Aqui não dá: a consulta social nasce de a tela
  /// ter sido aberta, e "ter sido aberta" é um evento de construção.
  ///
  /// Então a defesa fica NO LEITOR, e vale para todo chamador presente e
  /// futuro: este objeto nunca notifica dentro do trecho síncrono de quem o
  /// chamou. Só os caminhos de PARTIDA usam isto; os de chegada já estão depois
  /// de um `await`, e ali `notifyListeners()` direto é seguro e imediato.
  void _notificarEmBreve() {
    scheduleMicrotask(() {
      if (_descartado) return;
      notifyListeners();
    });
  }

  ListaSocial lista(QualLista qual) => _listas[qual]!;
  ListaSocial get amigos => lista(QualLista.amigos);
  ListaSocial get recebidas => lista(QualLista.recebidas);
  ListaSocial get enviadas => lista(QualLista.enviadas);
  BuscaSocial get busca => _busca;

  /// A sessão avançou: logout, troca de conta, recarga.
  ///
  /// Esvazia tudo. É o que impede a lista de amigos de A de aparecer para B —
  /// inclusive num teste em que os dois tenham o mesmo `publicId` por descuido.
  void aoMudarSessao(int geracao) {
    if (geracao == _geracao) return;
    _geracao = geracao;
    _ultimoPedido.clear();
    _emVoo.clear();
    _ultimaBusca = 0;
    for (final qual in QualLista.values) {
      _listas[qual] = const ListaSocial();
    }
    _busca = const BuscaSocial();
    _notificarEmBreve();
  }

  // -------------------------------------------------------------------------
  // Listas
  // -------------------------------------------------------------------------

  /// Carrega a primeira página, se ainda não houver uma.
  ///
  /// IDEMPOTENTE de propósito: é o método que a tela chama em
  /// `didChangeDependencies`, e ali ele roda a cada mudança de dependência. Sem
  /// a guarda, abrir o teclado viraria uma consulta.
  Future<void> garantir(QualLista qual) {
    final atual = lista(qual);
    if (atual.fase != FaseSocial.naoCarregada) return Future<void>.value();
    return recarregar(qual);
  }

  /// Relê a primeira página, descartando o que havia.
  Future<void> recarregar(QualLista qual) {
    final jaVoando = _emVoo[qual];
    if (jaVoando != null) return jaVoando;

    final numero = ++_sequencia;
    final geracao = _geracao;
    _ultimoPedido[qual] = numero;
    _listas[qual] = lista(qual)._com(
      fase: FaseSocial.carregando,
      carregandoMais: false,
      limparFalha: true,
    );
    _notificarEmBreve();

    final voo = _executarPagina(qual, numero, geracao, null);
    _emVoo[qual] = voo;
    return voo;
  }

  /// Pede a página seguinte, se houver cursor.
  ///
  /// O cursor viaja OPACO — o que veio, volta. Não há como o cliente "pular
  /// para a página 5": a paginação social é sequencial por decisão do contrato.
  Future<void> carregarMais(QualLista qual) {
    final atual = lista(qual);
    final cursor = atual.pagina.proximoCursor;
    if (cursor == null || atual.carregandoMais) return Future<void>.value();
    final jaVoando = _emVoo[qual];
    if (jaVoando != null) return jaVoando;

    final numero = ++_sequencia;
    final geracao = _geracao;
    _ultimoPedido[qual] = numero;
    _listas[qual] = atual._com(carregandoMais: true);
    _notificarEmBreve();

    final voo = _executarPagina(qual, numero, geracao, cursor);
    _emVoo[qual] = voo;
    return voo;
  }

  Future<void> _executarPagina(
    QualLista qual,
    int numero,
    int geracao,
    String? cursor,
  ) async {
    _chamadas++;
    try {
      final pagina = await switch (qual) {
        QualLista.amigos => _transporte.listarAmigos(cursor: cursor),
        QualLista.recebidas => _transporte.listarSolicitacoesRecebidas(
          cursor: cursor,
        ),
        QualLista.enviadas => _transporte.listarSolicitacoesEnviadas(
          cursor: cursor,
        ),
      };
      if (!_valido(qual, numero, geracao)) return;
      final anterior = lista(qual);
      _listas[qual] = anterior._com(
        fase: FaseSocial.pronta,
        // Concatena só no "carregar mais". Num recarregar, a página nova
        // SUBSTITUI — senão um item removido no servidor ficaria na tela para
        // sempre, porque nenhuma concatenação subtrai.
        pagina: cursor == null ? pagina : anterior.pagina.seguida(pagina),
        carregandoMais: false,
        limparFalha: true,
      );
      notifyListeners();
    } on FalhaSocial catch (e) {
      if (!_valido(qual, numero, geracao)) return;
      final anterior = lista(qual);
      _listas[qual] = anterior._com(
        // Falhar no "carregar mais" NÃO derruba o que já está na tela: a fase
        // continua pronta, e o jogador perde a página seguinte, não a lista.
        fase: cursor == null ? FaseSocial.falha : FaseSocial.pronta,
        carregandoMais: false,
        falha: e,
      );
      notifyListeners();
    } finally {
      // Só o dono retira o próprio voo: depois de `aoMudarSessao` pode haver um
      // voo órfão e um novo na mesma lista, e o órfão ao terminar removeria a
      // entrada do novo — abrindo uma chamada a mais no toque seguinte.
      if (_ultimoPedido[qual] == numero) _emVoo.remove(qual);
    }
  }

  bool _valido(QualLista qual, int numero, int geracao) =>
      geracao == _geracao && _ultimoPedido[qual] == numero;

  // -------------------------------------------------------------------------
  // Busca
  // -------------------------------------------------------------------------

  /// Procura jogadores pelo apelido.
  ///
  /// SEM VALIDAÇÃO DE TAMANHO AQUI. O mínimo e o máximo do termo são do
  /// servidor (`avaliarConsultaDeBusca`), e copiá-los para cá criaria dois
  /// lugares dizendo o que é um termo aceitável. O que este método faz é não
  /// GASTAR chamada com termo vazio — que não é regra de negócio, é a diferença
  /// entre pedir e não pedir nada.
  ///
  /// Quem quiser evitar uma ida ao servidor por letra digitada usa
  /// `IdentidadePublica.edicao.apelidoMinimo`, que a sessão já recebeu de
  /// `obterMinhaIdentidade` — do servidor, portanto, e não de uma constante
  /// local. Sem identidade carregada não há mínimo, e aí não há gate: pedir e
  /// receber `consultaMuitoCurta` é melhor que inventar o número.
  Future<void> buscar(String termo, {String? modo}) async {
    final limpo = termo.trim();
    final numero = ++_sequencia;
    final geracao = _geracao;
    _ultimaBusca = numero;

    if (limpo.isEmpty) {
      _busca = const BuscaSocial();
      _notificarEmBreve();
      return;
    }

    _busca = BuscaSocial(
      fase: FaseSocial.carregando,
      termo: limpo,
      // Os resultados anteriores FICAM enquanto a nova consulta corre: a lista
      // some e volta a cada letra se forem descartados, e o que a pessoa vê
      // pisca sem que nada tenha mudado.
      resultados: _busca.resultados,
    );
    _notificarEmBreve();

    _chamadas++;
    try {
      final r = await _transporte.buscarPorApelido(limpo, modo: modo);
      if (geracao != _geracao || _ultimaBusca != numero) return;
      _busca = BuscaSocial(
        fase: FaseSocial.pronta,
        termo: limpo,
        resultados: r,
      );
      notifyListeners();
    } on FalhaSocial catch (e) {
      if (geracao != _geracao || _ultimaBusca != numero) return;
      _busca = BuscaSocial(fase: FaseSocial.falha, termo: limpo, falha: e);
      notifyListeners();
    }
  }

  /// Limpa a busca e volta às abas normais.
  void limparBusca() {
    _ultimaBusca = ++_sequencia;
    _busca = const BuscaSocial();
    _notificarEmBreve();
  }

  // -------------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------------

  /// Executa uma ação de amizade e devolve o que a AUTORIDADE passou a dizer.
  ///
  /// Lança [FalhaSocial] quando a ação é recusada. Não engole: quem chama
  /// precisa poder dizer à pessoa o que aconteceu, e um `catch` silencioso aqui
  /// faria o botão parecer ter funcionado.
  Future<RespostaDeAcao> agir(AcaoSocial acao, String publicId) async {
    final alvo = publicId.trim();
    if (alvo.isEmpty) {
      // Nem sai do aparelho. Do outro lado viraria `invalid-argument`, e a
      // pessoa teria esperado uma chamada para ver um erro sobre um dado que
      // ela não escolheu.
      throw const FalhaSocial(
        MotivoFalhaSocial.pedidoInvalido,
        'publicIdVazio',
      );
    }

    _chamadas++;
    final desfecho = await _transporte.agir(acao, alvo);

    // A PARTIR DAQUI A AÇÃO JÁ ACONTECEU no servidor. Nada abaixo pode lançar
    // para quem chamou como se a ação tivesse falhado.
    _subtrair(acao, alvo);

    ResultadoSocial? vista;
    try {
      _chamadas++;
      vista = await _transporte.verPerfilPublico(alvo);
    } on FalhaSocial {
      // A releitura falhou. A relação fica "não sei" — e não deduzida.
      vista = null;
    }
    if (vista != null) _substituirNaBusca(vista);
    _vencerListas();
    notifyListeners();
    return RespostaDeAcao(desfecho: desfecho, vista: vista);
  }

  /// Tira a linha da lista em que a ação a tornou obsoleta.
  ///
  /// SÓ SUBTRAI, e só onde a autoridade acabou de dizer que a pendência acabou.
  /// Não move para lista nenhuma: quem entra na lista de amigos é a leitura
  /// seguinte de `listarAmigos`, e é [_vencerListas] que a provoca.
  void _subtrair(AcaoSocial acao, String publicId) {
    final QualLista? de = switch (acao) {
      AcaoSocial.aceitarSolicitacao ||
      AcaoSocial.recusarSolicitacao => QualLista.recebidas,
      AcaoSocial.cancelarSolicitacao => QualLista.enviadas,
      AcaoSocial.removerAmigo => QualLista.amigos,
      // `adicionarAmigo` não subtrai de lugar nenhum: ela CRIA uma pendência
      // enviada, e criar é justamente o que este método se proíbe de fazer.
      _ => null,
    };
    if (de == null) return;
    final atual = lista(de);
    _listas[de] = atual._com(pagina: atual.pagina.sem(publicId));
  }

  /// Troca a linha correspondente nos resultados de busca pela vista nova.
  ///
  /// É aqui que "estado da amizade refletido de volta na UI" acontece na tela
  /// de descoberta, e ele vem inteiro da resposta da autoridade — relação E
  /// ações. Nenhuma das duas é deduzida.
  void _substituirNaBusca(ResultadoSocial vista) {
    final r = _busca.resultados;
    if (r == null) return;
    var mudou = false;
    final novos = <ResultadoSocial>[];
    for (final item in r.itens) {
      if (item.publicId == vista.publicId) {
        novos.add(vista);
        mudou = true;
      } else {
        novos.add(item);
      }
    }
    if (!mudou) return;
    _busca = BuscaSocial(
      fase: _busca.fase,
      termo: _busca.termo,
      resultados: ResultadosDeBusca(
        termo: r.termo,
        itens: List.unmodifiable(novos),
        truncado: r.truncado,
        modo: r.modo,
      ),
    );
  }

  /// Marca as listas já carregadas como vencidas.
  ///
  /// VENCIDA, e não recarregada agora: recarregar as três a cada ação seriam
  /// três chamadas para uma tela que mostra uma aba de cada vez. Como a fase
  /// volta a [FaseSocial.naoCarregada], o próximo [garantir] consulta de novo.
  ///
  /// QUEM CHAMA `garantir` DEPOIS DE UMA AÇÃO É A TELA, para a aba que está
  /// visível — este leitor não sabe qual é, e adivinhar seria ele decidir o que
  /// vale a pena consultar em nome de uma superfície que ele não enxerga.
  ///
  /// A lista que NUNCA foi carregada continua não carregada — não há o que
  /// vencer, e mexer nela abriria uma consulta que ninguém pediu.
  void _vencerListas() {
    for (final qual in QualLista.values) {
      final atual = lista(qual);
      if (atual.fase == FaseSocial.naoCarregada) continue;
      _listas[qual] = ListaSocial(
        fase: FaseSocial.naoCarregada,
        // A página SOBREVIVE ao vencimento: é o que a tela mostra enquanto a
        // releitura corre, e é o que faz a linha subtraída sumir na hora em vez
        // de esperar a resposta.
        pagina: atual.pagina,
      );
    }
  }
}
