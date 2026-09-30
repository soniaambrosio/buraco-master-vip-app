import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'perfil_screen.dart' show NavDestino;

enum LojaCategoria { dorsos, molduras, avatares, mascotes, efeitos, emojis }

/// O andamento da compra, na linguagem da TELA.
///
/// POR QUE NÃO É O `EstadoCompra` DO BILLING. `lib/screens/` não importa
/// `lib/billing/`, e a direção da dependência é de propósito: a tela conhece o
/// Billing pelo adaptador, o Billing não conhece a tela. Quem traduz é
/// `loja_vip_adaptador.dart`, do mesmo jeito que já traduz os planos.
///
/// A tradução também é decisão de produto, e não só de camada: `aguardandoValidacao`
/// e `aguardandoRevalidacao` viram UM estado aqui porque pedem a mesma coisa de
/// quem lê — esperar, sem comprar de novo. E nenhum deles pode virar "você é
/// VIP": ver [EstadoDaCompraNaLoja.concluida], que é o mais perigoso da lista.
enum EstadoDaCompraNaLoja {
  /// Nada em curso. É o único estado em que assinar fica disponível.
  ociosa,

  /// O fluxo da Play foi aberto e a pessoa está decidindo.
  iniciando,

  /// A Play aceitou o pedido e o pagamento ainda não se concretizou.
  pendente,

  /// Pagou, e o servidor ainda não confirmou. Não há direito nenhum aqui.
  aguardandoConfirmacao,

  /// O servidor aceitou a compra e gravou o que ela concede.
  ///
  /// ISTO NÃO É "O JOGADOR É VIP", e o texto correspondente não pode dizer que
  /// é. O selo responde a `playerEntitlements/{uid}` e só a ele — ver
  /// `PainelBilling.mostrarComoVip`. Uma compra validada com assinatura em
  /// `ON_HOLD` é exatamente este estado, sem VIP nenhum.
  concluida,

  /// A pessoa desistiu.
  cancelada,

  /// O servidor recusou de forma definitiva. Nada foi concedido.
  recusada,

  /// A Play devolveu erro, ou não houve veredito do servidor.
  erro,
}

extension EstadoDaCompraNaLojaTexto on EstadoDaCompraNaLoja {
  /// O que dizer a quem está olhando. `null` quando não há nada a dizer.
  ///
  /// NENHUM destes textos afirma direito. O mais próximo é o de
  /// [EstadoDaCompraNaLoja.concluida], e ele fala de liberação EM CURSO, não de
  /// acesso obtido: quem acende o selo é o backend, e a tela não sabe antes dele.
  String? get mensagem => switch (this) {
    EstadoDaCompraNaLoja.ociosa => null,
    EstadoDaCompraNaLoja.iniciando => 'Abrindo o pagamento na Google Play…',
    EstadoDaCompraNaLoja.pendente =>
      'Pagamento aguardando aprovação. Assim que for aprovado, sua assinatura é '
          'liberada.',
    EstadoDaCompraNaLoja.aguardandoConfirmacao =>
      'Compra registrada. Estamos confirmando com o servidor — não é preciso '
          'comprar de novo.',
    EstadoDaCompraNaLoja.concluida =>
      'Compra confirmada. Seu acesso VIP é liberado assim que o servidor '
          'terminar de registrar.',
    EstadoDaCompraNaLoja.cancelada => 'Compra cancelada. Nada foi cobrado.',
    EstadoDaCompraNaLoja.recusada =>
      'Não foi possível validar esta compra. Nada foi concedido.',
    EstadoDaCompraNaLoja.erro =>
      'A Google Play não conseguiu concluir a compra. Tente de novo em '
          'instantes.',
  };

  /// Há uma tentativa VIVA? Enquanto houver, assinar fica indisponível.
  ///
  /// [EstadoDaCompraNaLoja.pendente] entra aqui, e é a inclusão que mais importa:
  /// pagamento em aprovação é compra viva, e oferecer "assinar" ali é convidar a
  /// pessoa a pagar duas vezes pela mesma assinatura.
  bool get emCurso =>
      this == EstadoDaCompraNaLoja.iniciando ||
      this == EstadoDaCompraNaLoja.pendente ||
      this == EstadoDaCompraNaLoja.aguardandoConfirmacao;
}

/// O modelo de exibição da Loja.
///
/// TODOS OS CAMPOS DE ACERVO SÃO OMISSÍVEIS, e isso é o que permite a mesma
/// tela servir à maquete e ao aplicativo publicável. A maquete ([LojaVM.mock])
/// preenche tudo; a Loja de produção preenche só o que tem autoridade — hoje o
/// selo VIP (`playerEntitlements/{uid}`) e os planos (`formattedPrice` da Play).
///
/// [moedas] e [gemas] são NULÁVEIS pela mesma razão que `CabecalhoJogador.moedas`
/// é na Home: não há autoridade de economia alcançável pelo cliente, e um `0`
/// desenhado não é modéstia — é a afirmação de que alguém consultou a carteira
/// e ela estava vazia. Nulo faz o elemento sair da tela.
///
/// As listas vazias têm o mesmo efeito: sem pacote, sem categoria e sem amigo,
/// a seção inteira não é desenhada. Uma vitrine de cosméticos com preço, sem
/// catálogo e sem saldo por trás, seria uma promessa comercial sem produto.
class LojaVM {
  final int? moedas;
  final int? gemas;
  final bool ehVip;
  final List<PlanoVipLoja> planos;
  final List<String> beneficiosVip;
  final List<PacoteMoedas> pacotes;
  final List<CategoriaCosmetico> categorias;
  final List<AmigoPresente> amigos;

  const LojaVM({
    this.moedas,
    this.gemas,
    required this.ehVip,
    this.planos = const <PlanoVipLoja>[],
    this.beneficiosVip = const <String>[],
    this.pacotes = const <PacoteMoedas>[],
    this.categorias = const <CategoriaCosmetico>[],
    this.amigos = const <AmigoPresente>[],
  });

  factory LojaVM.mock({bool ehVip = false}) {
    return LojaVM(
      moedas: 1000,
      gemas: 12,
      ehVip: ehVip,
      planos: const [
        PlanoVipLoja(
          id: 'mensal',
          nome: 'Mensal',
          preco: 'R\$ 19,90',
          porMes: 'R\$ 19,90/mês',
          destaque: false,
        ),
        PlanoVipLoja(
          id: 'trimestral',
          nome: 'Trimestral',
          preco: 'R\$ 49,90',
          porMes: 'R\$ 16,63/mês',
          selo: '-16%',
          destaque: false,
        ),
        PlanoVipLoja(
          id: 'anual',
          nome: 'Anual',
          preco: 'R\$ 149,90',
          porMes: 'R\$ 12,49/mês',
          selo: 'MELHOR VALOR · -37%',
          destaque: true,
        ),
      ],
      beneficiosVip: const [
        '🚫 Sem anúncios',
        '🔒 Salas privadas',
        '🎁 Bônus diário',
        '💎 Itens exclusivos',
        '⭐ Selo VIP',
      ],
      pacotes: const [
        PacoteMoedas(
          id: 'punhado',
          emoji: '🪙',
          moedas: 1000,
          preco: 'R\$ 4,90',
        ),
        PacoteMoedas(
          id: 'bolso',
          emoji: '💰',
          moedas: 2200,
          bonus: '+10%',
          preco: 'R\$ 9,90',
          selo: 'Popular',
        ),
        PacoteMoedas(
          id: 'bau',
          emoji: '🧰',
          moedas: 4800,
          bonus: '+20%',
          preco: 'R\$ 19,90',
        ),
        PacoteMoedas(
          id: 'cofre',
          emoji: '💎',
          moedas: 13000,
          bonus: '+30%',
          preco: 'R\$ 49,90',
          selo: 'Melhor valor',
        ),
        PacoteMoedas(
          id: 'tesouro',
          emoji: '🏆',
          moedas: 28000,
          bonus: '+40%',
          preco: 'R\$ 99,90',
        ),
      ],
      categorias: const [
        CategoriaCosmetico(
          id: LojaCategoria.dorsos,
          icone: '🂠',
          label: 'Dorsos',
          subtitulo: '28 skins',
        ),
        CategoriaCosmetico(
          id: LojaCategoria.molduras,
          icone: '🖼️',
          label: 'Molduras',
          subtitulo: 'Carnaval · VIP',
        ),
        CategoriaCosmetico(
          id: LojaCategoria.avatares,
          icone: '🙂',
          label: 'Avatares',
          subtitulo: '34 no acervo',
        ),
        CategoriaCosmetico(
          id: LojaCategoria.mascotes,
          icone: '🦊',
          label: 'Mascotes',
          subtitulo: '38 bichinhos',
        ),
        CategoriaCosmetico(
          id: LojaCategoria.efeitos,
          icone: '✨',
          label: 'Efeitos',
          subtitulo: 'de vitória',
        ),
        CategoriaCosmetico(
          id: LojaCategoria.emojis,
          icone: '😄',
          label: 'Emojis',
          subtitulo: 'reações VIP',
        ),
      ],
      amigos: const [
        AmigoPresente(id: 'claudia', nome: 'Cláudia', avatar: '🐰'),
        AmigoPresente(id: 'marina', nome: 'Marina', avatar: '🐱'),
        AmigoPresente(id: 'beto', nome: 'Beto', avatar: '🦊'),
        AmigoPresente(id: 'ricardo', nome: 'Ricardo', avatar: '🐻'),
        AmigoPresente(id: 'fernanda', nome: 'Fernanda', avatar: '🐶'),
        AmigoPresente(id: 'paulo', nome: 'Paulo', avatar: '🐵'),
        AmigoPresente(id: 'ana', nome: 'Ana Bella', avatar: '🐨'),
        AmigoPresente(id: 'julia', nome: 'Júlia Lima', avatar: '🦁'),
      ],
    );
  }

  /// Troca so o que ja tem fonte real, preservando o resto da maquete.
  ///
  /// A vitrine de cosmeticos, os pacotes de moedas e a lista de amigos continuam
  /// sendo `LojaVM.mock`: nao ha produto, catalogo nem backend por tras deles
  /// ainda. O VIP tem — [ehVip] vem de `playerEntitlements/{uid}` e [planos] vem
  /// do que a Play Store devolveu — e por isso so esses dois sao substituiveis
  /// aqui. Misturar os dois numa fabrica so faria a maquete parecer dado real.
  LojaVM copiarCom({
    bool? ehVip,
    List<PlanoVipLoja>? planos,
    int? moedas,
    int? gemas,
  }) {
    return LojaVM(
      moedas: moedas ?? this.moedas,
      gemas: gemas ?? this.gemas,
      ehVip: ehVip ?? this.ehVip,
      planos: planos ?? this.planos,
      beneficiosVip: beneficiosVip,
      pacotes: pacotes,
      categorias: categorias,
      amigos: amigos,
    );
  }
}

class PlanoVipLoja {
  final String id;
  final String nome;
  final String preco;
  final String porMes;
  final String? selo;
  final bool destaque;

  const PlanoVipLoja({
    required this.id,
    required this.nome,
    required this.preco,
    required this.porMes,
    this.selo,
    required this.destaque,
  });
}

class PacoteMoedas {
  final String id;
  final String emoji;
  final int moedas;
  final String? bonus;
  final String preco;
  final String? selo;

  const PacoteMoedas({
    required this.id,
    required this.emoji,
    required this.moedas,
    this.bonus,
    required this.preco,
    this.selo,
  });
}

class CategoriaCosmetico {
  final LojaCategoria id;
  final String icone;
  final String label;
  final String subtitulo;

  const CategoriaCosmetico({
    required this.id,
    required this.icone,
    required this.label,
    required this.subtitulo,
  });
}

class AmigoPresente {
  final String id;
  final String nome;
  final String avatar;

  const AmigoPresente({
    required this.id,
    required this.nome,
    required this.avatar,
  });
}

class LojaScreen extends StatefulWidget {
  static const gold = Color(0xFFEFB94A);
  static const goldHi = Color(0xFFF6E2A6);
  static const card = Color(0xFF1C130C);
  static const border = Color(0x33EFB94A);
  static const text = Color(0xFFEFE3CC);
  static const muted = Color(0xFF8A7C5E);

  final LojaVM vm;
  final VoidCallback onVoltar;
  final ValueChanged<NavDestino> onNav;
  final VoidCallback onComprarMoedas;

  /// A INTENÇÃO COMERCIAL CONFIRMADA. Quem chama isto abre o fluxo da Play.
  ///
  /// Este callback já existia, e o que mudou foi QUEM o chama. Ele nascia do
  /// toque no card de plano — selecionar e comprar eram o mesmo gesto, e três
  /// toques abriam três cobranças. Agora ele só é alcançado pelo botão
  /// "Continuar" da folha de confirmação, depois de a pessoa ter visto plano,
  /// preço e periodicidade.
  final ValueChanged<String> onAssinar;

  /// Escolher um plano na vitrine. NÃO compra nada.
  ///
  /// Existe separado de [onAssinar] justamente para que a separação seja
  /// verificável de fora: um teste consegue provar que tocar no card produz
  /// seleção e nenhuma intenção comercial.
  final ValueChanged<String>? onSelecionarPlano;

  final ValueChanged<String> onComprarPacote;
  final ValueChanged<String> onConfirmarCompra;
  final ValueChanged<LojaCategoria> onAbrirCategoria;
  final ValueChanged<String> onPresentear;
  final ValueChanged<String> onBuscarPresenteado;
  final void Function(String itemId, String jogadorId) onEnviarPresente;

  /// O que dizer quando não há nada a oferecer.
  ///
  /// Aparece no lugar da grade de planos quando o jogador não é VIP e a Play não
  /// devolveu plano nenhum. Sem isto, a vitrine ficaria com o cabeçalho da
  /// assinatura e um vazio embaixo — que se lê como falha do aplicativo, e não
  /// como "não há oferta agora".
  final String? avisoDaVitrine;

  /// Em que pé está a compra, para exibir E para travar a ação.
  ///
  /// O padrão é [EstadoDaCompraNaLoja.ociosa] para que a maquete e os testes
  /// visuais continuem montando a tela sem saber de Billing. Quem tem a verdade
  /// é `LojaDeProducao`, que a repassa a cada quadro.
  final EstadoDaCompraNaLoja estadoDaCompra;

  const LojaScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onNav,
    required this.onComprarMoedas,
    required this.onAssinar,
    required this.onComprarPacote,
    required this.onConfirmarCompra,
    required this.onAbrirCategoria,
    required this.onPresentear,
    required this.onBuscarPresenteado,
    required this.onEnviarPresente,
    this.onSelecionarPlano,
    this.avisoDaVitrine,
    this.estadoDaCompra = EstadoDaCompraNaLoja.ociosa,
  });

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final GlobalKey _moedasKey = GlobalKey();
  String? _planoSelecionado;

  /// A TRAVA LOCAL DE INTENÇÃO, e por que ela existe além de [_travado].
  ///
  /// O estado da compra chega por `stream`, e stream não entrega no mesmo
  /// quadro: entre confirmar e o `iniciando` aparecer há uma janela em que
  /// `widget.estadoDaCompra` ainda diz `ociosa`. É exatamente nessa janela que
  /// moram os três toques rápidos. Esta variável a fecha SINCRONAMENTE.
  ///
  /// Ela não substitui a trava por estado, e nem poderia: quem reabre o
  /// aplicativo no meio de um pagamento pendente chega com `pendente` sem nunca
  /// ter tocado em nada nesta sessão.
  bool _intencaoEnviada = false;

  @override
  void initState() {
    super.initState();
    _planoSelecionado = _planoDestaque?.id ??
        (widget.vm.planos.isNotEmpty ? widget.vm.planos.first.id : null);
  }

  @override
  void didUpdateWidget(covariant LojaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.vm.planos.any((p) => p.id == _planoSelecionado)) {
      _planoSelecionado = _planoDestaque?.id ??
          (widget.vm.planos.isNotEmpty ? widget.vm.planos.first.id : null);
    }

    // A tentativa terminou (deu certo, deu errado ou foi cancelada): a trava
    // local sai do caminho e a pessoa pode tentar de novo. Enquanto o estado for
    // `emCurso`, quem segura é `_travado`, não esta variável.
    if (_intencaoEnviada && !widget.estadoDaCompra.emCurso) {
      _intencaoEnviada = false;
    }

    _anunciarTransicoes(oldWidget);
  }

  // -------------------------------------------------------------------------
  // Anúncio
  // -------------------------------------------------------------------------

  /// Fala UMA VEZ por transição, e só na transição.
  ///
  /// POR QUE `announce` E NÃO UMA REGIÃO VIVA. Região viva anuncia quando o nó é
  /// atualizado, e a Loja reconstrói a cada quadro — `_ehVip` é recalculado
  /// contra o relógio em `LojaDeProducao`. Uma região viva sobre a faixa de
  /// status repetiria a mesma frase sem que nada tivesse mudado, e uma sobre a
  /// tela inteira releria a vitrine junto. Comparar o widget anterior com o atual
  /// é o que dá "uma vez por transição" de verdade.
  ///
  /// A faixa de status continua existindo na tela e na árvore semântica: quem
  /// perdeu o anúncio a encontra explorando, em vez de depender de tê-lo ouvido.
  void _anunciarTransicoes(LojaScreen anterior) {
    if (widget.estadoDaCompra != anterior.estadoDaCompra) {
      final texto = widget.estadoDaCompra.mensagem;
      if (texto != null) _falar(texto);
    }

    // O selo VIP não é consequência da compra: ele vem de
    // `playerEntitlements/{uid}`, e pode acender numa sessão que não comprou
    // nada. Por isso o anúncio é da MUDANÇA do direito, e não do fim do fluxo.
    if (widget.vm.ehVip && !anterior.vm.ehVip) {
      _falar('Seu acesso VIP está ativo.');
    }
  }

  /// `sendAnnouncement`, e não o `announce` que está depreciado desde a 3.35.
  ///
  /// A janela vem do `View` desta árvore, e não do `implicitView` global — que é
  /// exatamente a incompatibilidade com múltiplas janelas que a depreciação
  /// aponta.
  void _falar(String texto) {
    final direcao = Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.sendAnnouncement(View.of(context), texto, direcao);
  }

  // -------------------------------------------------------------------------
  // Intenção comercial
  // -------------------------------------------------------------------------

  /// Assinar está disponível agora?
  bool get _travado => _intencaoEnviada || widget.estadoDaCompra.emCurso;

  PlanoVipLoja? get _planoDestaque {
    for (final plano in widget.vm.planos) {
      if (plano.destaque) return plano;
    }
    return null;
  }

  PlanoVipLoja? _planoPorId(String id) {
    for (final plano in widget.vm.planos) {
      if (plano.id == id) return plano;
    }
    return widget.vm.planos.isNotEmpty ? widget.vm.planos.first : null;
  }

  String? _formatarOpcional(int? valor) =>
      valor == null ? null : _formatarInteiro(valor);

  String _formatarInteiro(int valor) {
    final texto = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      final restante = texto.length - i;
      buffer.write(texto[i]);
      if (restante > 1 && restante % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }

  void _rolarParaMoedas() {
    widget.onComprarMoedas();
    final context = _moedasKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: .05,
      );
    }
  }

  /// Escolher um plano. NÃO COMPRA — e a ausência da chamada é o ponto.
  ///
  /// Aqui morava `widget.onAssinar(plano.id)`, uma linha abaixo do `setState`.
  /// Era ela que fazia o gesto de explorar a vitrine abrir o diálogo de cobrança
  /// da Play, sem confirmação e sem limite de repetição.
  void _selecionarPlano(PlanoVipLoja plano) {
    setState(() => _planoSelecionado = plano.id);
    widget.onSelecionarPlano?.call(plano.id);
  }

  /// A confirmação, que é o único caminho até [LojaScreen.onAssinar].
  ///
  /// Mostra o que a OS exige antes de encaminhar à Play: qual plano, o preço que
  /// a PLAY formatou, a periodicidade, e as duas saídas. Nenhum desses valores
  /// nasce aqui — todos vêm do [PlanoVipLoja] que o adaptador montou.
  Future<void> _abrirConfirmacaoDeAssinatura(PlanoVipLoja plano) async {
    if (_travado) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ConfirmacaoAssinaturaSheet(
        plano: plano,
        onCancelar: () => Navigator.of(sheetContext).pop(),
        onContinuar: () {
          // Fecha ANTES de emitir. A folha some do caminho no mesmo quadro, e o
          // segundo toque numa folha que já não existe não tem onde cair.
          Navigator.of(sheetContext).pop();
          _emitirIntencao(plano.id);
        },
      ),
    );
  }

  /// O ÚNICO ponto do arquivo que chama [LojaScreen.onAssinar].
  ///
  /// A trava é conferida de novo aqui, e não só no botão: um botão desabilitado
  /// é uma afirmação sobre o quadro em que foi pintado, e esta função é o lugar
  /// onde a intenção de fato sai.
  void _emitirIntencao(String basePlanId) {
    if (_travado) return;
    setState(() => _intencaoEnviada = true);
    widget.onAssinar(basePlanId);
  }

  Future<void> _abrirCompra(PacoteMoedas pacote) async {
    widget.onComprarPacote(pacote.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CompraSheet(
        pacote: pacote,
        moedasFormatadas: _formatarInteiro(pacote.moedas),
        onConfirmar: () {
          Navigator.of(sheetContext).pop();
          widget.onConfirmarCompra(pacote.id);
        },
      ),
    );
  }

  Future<void> _abrirPresente({
    required String itemId,
    required String titulo,
    required String emoji,
  }) async {
    widget.onPresentear(itemId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PresenteSheet(
        titulo: titulo,
        emoji: emoji,
        amigos: widget.vm.amigos,
        onBuscar: widget.onBuscarPresenteado,
        onEnviar: (jogadorId) {
          Navigator.of(sheetContext).pop();
          widget.onEnviarPresente(itemId, jogadorId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Color(0xFF000000)],
            stops: [0, .56, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _TopBar(
                    moedas: _formatarOpcional(widget.vm.moedas),
                    onVoltar: widget.onVoltar,
                    onCarteira: _rolarParaMoedas,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _VipShowcase(
                            vm: widget.vm,
                            selectedPlanId: _planoSelecionado,
                            avisoDaVitrine: widget.avisoDaVitrine,
                            estadoDaCompra: widget.estadoDaCompra,
                            travado: _travado,
                            onPlanoTap: _selecionarPlano,
                            onAssinarSelecionado: () {
                              final id = _planoSelecionado;
                              if (id == null) return;
                              final plano = _planoPorId(id);
                              if (plano == null) return;
                              _abrirConfirmacaoDeAssinatura(plano);
                            },
                            onPresentear: () {
                              final id = _planoSelecionado ?? 'mensal';
                              final plano = _planoPorId(id);
                              _abrirPresente(
                                itemId: 'vip_$id',
                                titulo: plano == null
                                    ? 'Assinatura VIP'
                                    : 'VIP ${plano.nome}',
                                emoji: '👑',
                              );
                            },
                          ),
                          // SEÇÃO SEM ACERVO NÃO É DESENHADA. Um título "MOEDAS"
                          // com uma faixa vazia embaixo lê-se como erro de
                          // carregamento; e um título com pacotes de maquete
                          // lê-se como oferta. Sem pacote, a seção inteira sai.
                          if (widget.vm.pacotes.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _SectionTitle(key: _moedasKey, label: 'MOEDAS'),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 262,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: widget.vm.pacotes.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final pacote = widget.vm.pacotes[index];
                                  return _PacoteCard(
                                    pacote: pacote,
                                    moedas: _formatarInteiro(pacote.moedas),
                                    onComprar: () => _abrirCompra(pacote),
                                    onPresentear: () => _abrirPresente(
                                      itemId: pacote.id,
                                      titulo: '${_formatarInteiro(pacote.moedas)} moedas',
                                      emoji: pacote.emoji,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (widget.vm.categorias.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _SectionTitle(label: 'COSMÉTICOS'),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final spacing = 10.0;
                                final itemWidth =
                                    (constraints.maxWidth - spacing * 2) / 3;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: [
                                    for (final categoria in widget.vm.categorias)
                                      SizedBox(
                                        width: itemWidth,
                                        height: 126,
                                        child: _CategoriaCard(
                                          categoria: categoria,
                                          onTap: () =>
                                              widget.onAbrirCategoria(categoria.id),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _BottomNav(onTap: widget.onNav),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  /// O saldo já formatado, ou `null` quando não há autoridade de carteira — e
  /// aí a pastilha inteira, com o `+` que leva aos pacotes, não é desenhada.
  final String? moedas;
  final VoidCallback onVoltar;
  final VoidCallback onCarteira;

  const _TopBar({
    required this.moedas,
    required this.onVoltar,
    required this.onCarteira,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          // VOLTAR, e não "‹". O glifo continua sendo o desenho; o nome
          // acessível agora é uma palavra.
          //
          // O NOME É `label`, E NÃO `tooltip`. Um `IconButton(tooltip: …)`
          // parece resolver e não resolve do mesmo jeito: o texto vai para
          // `SemanticsData.tooltip`, o `label` continua VAZIO, e o nó fica
          // sendo um botão sem nome para qualquer leitura que pergunte pelo
          // nome. É o mesmo padrão dos cards e da navegação — um nó, um nome,
          // uma ação — e é o que torna a regra "nenhum acionável sem nome"
          // verificável de uma vez só.
          Semantics(
            button: true,
            label: 'Voltar',
            onTap: onVoltar,
            excludeSemantics: true,
            child: InkResponse(
              onTap: onVoltar,
              radius: 26,
              child: const SizedBox(
                // Era 35×42. Reprovava nas duas dimensões.
                width: 48,
                height: 48,
                child: Center(
                  child: Text(
                    '‹',
                    style: TextStyle(
                      color: LojaScreen.gold,
                      fontSize: 36,
                      height: .9,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // O título é o nome da tela. Marcado como cabeçalho, ele vira ponto de
          // salto para quem navega por cabeçalhos, e é o que o leitor de tela
          // encontra primeiro ao explorar.
          Semantics(
            header: true,
            child: const Text(
              'Loja',
              style: TextStyle(
                color: LojaScreen.goldHi,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          if (moedas != null)
            Semantics(
              button: true,
              // O emoji, o número e o `+` eram três nós sem verbo. Um nome
              // explícito diz o saldo E o que o toque faz.
              label: 'Saldo: ${moedas!} moedas. Comprar mais moedas',
              excludeSemantics: true,
              onTap: onCarteira,
              child: InkWell(
            onTap: onCarteira,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
              decoration: BoxDecoration(
                color: LojaScreen.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF0A7656), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    moedas!,
                    style: const TextStyle(
                      color: LojaScreen.goldHi,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: LojaScreen.gold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '+',
                      style: TextStyle(
                        color: Color(0xFF3B2607),
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
        ],
      ),
    );
  }
}

class _VipShowcase extends StatelessWidget {
  final LojaVM vm;
  final String? selectedPlanId;
  final String? avisoDaVitrine;
  final EstadoDaCompraNaLoja estadoDaCompra;
  final bool travado;
  final ValueChanged<PlanoVipLoja> onPlanoTap;
  final VoidCallback onAssinarSelecionado;
  final VoidCallback onPresentear;

  const _VipShowcase({
    required this.vm,
    required this.selectedPlanId,
    required this.onPlanoTap,
    required this.onAssinarSelecionado,
    required this.onPresentear,
    required this.estadoDaCompra,
    required this.travado,
    this.avisoDaVitrine,
  });

  PlanoVipLoja? get _selecionado {
    for (final p in vm.planos) {
      if (p.id == selectedPlanId) return p;
    }
    return vm.planos.isEmpty ? null : vm.planos.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF49320D), Color(0xFF2B1A08), Color(0xFF1D1107)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF9A7521), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x332E1900), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('👑', style: TextStyle(fontSize: 43)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.ehVip ? 'Você é VIP 👑' : 'Buraco Master VIP',
                      style: const TextStyle(
                        color: LojaScreen.goldHi,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vm.ehVip
                          ? 'benefícios premium ativos na sua conta'
                          : 'o pacote completo de quem ama o jogo',
                      style: TextStyle(
                        color: LojaScreen.goldHi.withValues(alpha: .82),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (vm.beneficiosVip.isNotEmpty) const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              for (final beneficio in vm.beneficiosVip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xAA1D1107),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0x338F6B23)),
                  ),
                  child: Text(
                    beneficio,
                    style: const TextStyle(
                      color: Color(0xFFD8C69E),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          if (vm.ehVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF123E2C),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF2A966D)),
              ),
              child: const Row(
                children: [
                  Text('✓', style: TextStyle(color: Color(0xFF66E5AF), fontSize: 23)),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Seu acesso VIP está ativo',
                      style: TextStyle(
                        color: Color(0xFFB8F5D9),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: LojaScreen.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else if (vm.planos.isNotEmpty) ...[
            _PlanosGrid(
              planos: vm.planos,
              selectedPlanId: selectedPlanId,
              onTap: onPlanoTap,
            ),
            const SizedBox(height: 14),
            // A AÇÃO INEQUÍVOCA. Ela nomeia o plano escolhido, então quem a ouve
            // sabe o que vai assinar sem ter de lembrar em qual card estava.
            _AcaoAssinar(
              plano: _selecionado,
              travado: travado,
              onAssinar: onAssinarSelecionado,
            ),
          ]
          // Sem plano nenhum a oferecer, o lugar da grade recebe a explicação —
          // e não um vazio, que se lê como tela quebrada.
          else if (avisoDaVitrine != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xAA1D1107),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x338F6B23)),
              ),
              child: Text(
                avisoDaVitrine!,
                style: const TextStyle(
                  color: Color(0xFFD8C69E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          // A FAIXA FICA FORA DO if/else DE PROPÓSITO. Um pagamento pendente
          // sobrevive ao fechamento do aplicativo: quem reabre no meio dele
          // chega com o catálogo ainda carregando e sem plano nenhum na tela —
          // e é justamente aí que precisa ler "não é preciso comprar de novo".
          // Presa ao ramo dos planos, a explicação sumiria no único caso em que
          // ela é indispensável.
          _FaixaDeStatus(estado: estadoDaCompra),
          // PRESENTEAR EXIGE A QUEM. A folha de amigos alimenta a lista do
          // seletor; sem ela o botão abriria uma folha vazia e prometeria um
          // envio que não existe.
          if (vm.amigos.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPresentear,
              icon: const Text('🎁', style: TextStyle(fontSize: 18)),
              label: const Text('Presentear assinatura VIP'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LojaScreen.goldHi,
                side: const BorderSide(color: Color(0xFF9A7521)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// A ação comercial, e o que ela diz de si mesma
// ===========================================================================

/// O botão que assume a compra, separado da vitrine que a escolhe.
///
/// O nome muda com o plano selecionado — "Assinar plano anual", e não "Assinar".
/// É o que permite a quem chegou aqui pelo leitor de tela, sem ver a grade,
/// saber o que está prestes a contratar.
class _AcaoAssinar extends StatelessWidget {
  final PlanoVipLoja? plano;
  final bool travado;
  final VoidCallback onAssinar;

  const _AcaoAssinar({
    required this.plano,
    required this.travado,
    required this.onAssinar,
  });

  @override
  Widget build(BuildContext context) {
    final p = plano;
    if (p == null) return const SizedBox.shrink();
    final rotulo = 'Assinar plano ${p.nome.toLowerCase()}';
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        // `null` é o que produz `hasEnabledState` SEM `isEnabled` na árvore —
        // o desabilitado vira estado anunciado, e não só um botão mais claro.
        onPressed: travado ? null : onAssinar,
        style: FilledButton.styleFrom(
          backgroundColor: LojaScreen.gold,
          foregroundColor: const Color(0xFF3D2705),
          // 3,49:1 sobre o fundo da vitrine: acima da régua de 3:1 para
          // elemento gráfico, que é o que um botão desabilitado precisa
          // continuar sendo — visível, e claramente fora de uso.
          disabledBackgroundColor: const Color(0xFF6B5526),
          disabledForegroundColor: const Color(0xFFE8DCC0),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        child: Text(
          travado ? 'Aguarde…' : rotulo,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// O andamento da compra, escrito na tela.
///
/// Existe além do anúncio porque anúncio não deixa rastro: quem chegou depois
/// dele, quem estava com o foco em outro lugar, ou quem simplesmente não ouviu,
/// precisa de um lugar onde a informação ainda esteja.
class _FaixaDeStatus extends StatelessWidget {
  final EstadoDaCompraNaLoja estado;

  const _FaixaDeStatus({required this.estado});

  @override
  Widget build(BuildContext context) {
    final texto = estado.mensagem;
    if (texto == null) return const SizedBox.shrink();

    final problema = estado == EstadoDaCompraNaLoja.recusada ||
        estado == EstadoDaCompraNaLoja.erro;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: problema ? const Color(0xFF3A1512) : const Color(0xFF14251D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  problema ? const Color(0xFFC2705F) : const Color(0xFF3E7A63),
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              // 8,93:1 e 9,41:1 sobre os fundos acima.
              color: problema
                  ? const Color(0xFFFFD9D2)
                  : const Color(0xFFCFEBDD),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// A confirmação que falta entre escolher e pagar.
///
/// Ela existe para que a compra tenha DOIS gestos deliberados, e para que o
/// segundo mostre o que o primeiro não mostrava: o preço e a periodicidade lado
/// a lado, na mesma frase que a ação.
///
/// NENHUM VALOR NASCE AQUI. `preco` é o `formattedPrice` que a Play devolveu,
/// `porMes` é aritmética sobre ele, e `nome` vem do período que a própria Play
/// informou. Ver `loja_vip_adaptador.dart`.
class _ConfirmacaoAssinaturaSheet extends StatefulWidget {
  final PlanoVipLoja plano;
  final VoidCallback onContinuar;
  final VoidCallback onCancelar;

  const _ConfirmacaoAssinaturaSheet({
    required this.plano,
    required this.onContinuar,
    required this.onCancelar,
  });

  @override
  State<_ConfirmacaoAssinaturaSheet> createState() =>
      _ConfirmacaoAssinaturaSheetState();
}

class _ConfirmacaoAssinaturaSheetState
    extends State<_ConfirmacaoAssinaturaSheet> {
  /// A terceira trava, e a mais local de todas.
  ///
  /// `_travado` protege a tela e `_intencaoEnviada` protege a sessão; esta
  /// protege o quadro. Entre o toque em "Continuar" e a folha sair da árvore há
  /// um intervalo em que um segundo toque ainda encontra o botão vivo.
  bool _confirmado = false;

  void _continuar() {
    if (_confirmado) return;
    setState(() => _confirmado = true);
    widget.onContinuar();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plano;
    final economia = p.selo;
    return _SheetShell(
      // O cabeçalho, e portanto o "X", fica FORA da rolagem: fechar é sempre um
      // gesto só, mesmo quando o corpo precisa rolar.
      cabecalho: const _SheetHeader(
        title: 'Confirmar assinatura',
        subtitle: 'Revise antes de continuar',
        rotuloFechar: 'Fechar confirmação de assinatura',
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Semantics(
            container: true,
            // Um nó só, na ordem em que a frase faz sentido falada. Solto, o
            // preço seria lido sem saber de qual plano, e a periodicidade sem
            // saber de qual preço.
            label: 'Plano ${p.nome}. '
                'Preço ${p.preco}. '
                'Cobrança ${p.porMes}.'
                '${economia == null ? '' : ' Economia de ${_soDigitos(economia)} por cento.'}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF150E09),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: LojaScreen.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plano ${p.nome}',
                    style: const TextStyle(
                      color: LojaScreen.goldHi,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.preco,
                    style: const TextStyle(
                      color: LojaScreen.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.porMes,
                    style: const TextStyle(
                      color: Color(0xFFC9B78C),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Você será levado à Google Play para concluir o pagamento. '
            'O acesso VIP é liberado depois que o servidor confirmar a compra.',
            style: TextStyle(
              color: Color(0xFFCBBB95),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirmado ? null : _continuar,
            style: FilledButton.styleFrom(
              backgroundColor: LojaScreen.gold,
              foregroundColor: const Color(0xFF3D2705),
              disabledBackgroundColor: const Color(0xFF6B5526),
              disabledForegroundColor: const Color(0xFFE8DCC0),
              minimumSize: const Size.fromHeight(48),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            child: const Text('Continuar para o pagamento'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _confirmado ? null : widget.onCancelar,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE4D6B0),
              minimumSize: const Size.fromHeight(48),
              textStyle:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// `-37%` vira `37`, para a frase falada não começar por "menos".
String _soDigitos(String selo) {
  final b = StringBuffer();
  for (final c in selo.split('')) {
    if (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) b.write(c);
  }
  final s = b.toString();
  return s.isEmpty ? selo : s;
}

class _PlanosGrid extends StatelessWidget {
  final List<PlanoVipLoja> planos;
  final String? selectedPlanId;
  final ValueChanged<PlanoVipLoja> onTap;

  const _PlanosGrid({
    required this.planos,
    required this.selectedPlanId,
    required this.onTap,
  });

  /// AQUI MORAVA `height: 132`.
  ///
  /// A altura fixa cortava o conteúdo do card em 200%: os dois cards com selo
  /// estouravam 52 e 53 pontos, e o que saía da caixa era o fim da pilha — o
  /// "por mês" e o desconto. Quem aumenta a fonte perdia exatamente a informação
  /// de economia.
  ///
  /// A troca é `Wrap` por linhas de `IntrinsicHeight`: os cards de uma mesma
  /// linha continuam com a MESMA altura — que era o que a altura fixa comprava —
  /// só que agora essa altura é a do card mais alto, e não um número escrito
  /// aqui. Em 100% o desenho é o mesmo; em 200% a linha cresce.
  @override
  Widget build(BuildContext context) {
    if (planos.isEmpty) return const SizedBox.shrink();
    const espaco = 8.0;
    final colunas = planos.length <= 3 ? planos.length : 2;

    final linhas = <List<PlanoVipLoja>>[];
    for (var i = 0; i < planos.length; i += colunas) {
      linhas.add(planos.sublist(
        i,
        i + colunas > planos.length ? planos.length : i + colunas,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var l = 0; l < linhas.length; l++) ...[
          if (l > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < colunas; c++) ...[
                  if (c > 0) const SizedBox(width: espaco),
                  Expanded(
                    child: c < linhas[l].length
                        ? _PlanoCard(
                            plano: linhas[l][c],
                            selected: linhas[l][c].id == selectedPlanId,
                            onTap: () => onTap(linhas[l][c]),
                          )
                        // Buraco de linha incompleta: ocupa a coluna para os
                        // cards restantes não esticarem.
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanoCard extends StatelessWidget {
  final PlanoVipLoja plano;
  final bool selected;
  final VoidCallback onTap;

  const _PlanoCard({
    required this.plano,
    required this.selected,
    required this.onTap,
  });

  /// O rótulo falado do card, montado dos MESMOS campos que ele desenha.
  ///
  /// A ordem é a da frase, não a do layout, e o desconto vira "economia de 37
  /// por cento" em vez de "menos trinta e sete por cento" — que é como um leitor
  /// de tela pronuncia `-37%`, e que diz a coisa errada.
  ///
  /// O estado de escolha NÃO entra aqui: quem o comunica é o `selected` da
  /// árvore, e repeti-lo no texto faria o leitor dizer duas vezes.
  String get _rotulo {
    final selo = plano.selo;
    final economia = selo == null
        ? ''
        : ' Economia de ${_soDigitos(selo)} por cento.';
    return 'Plano ${plano.nome}. ${plano.preco}. ${plano.porMes}.$economia';
  }

  @override
  Widget build(BuildContext context) {
    final highlight = plano.destaque || selected;
    // UM NÓ SÓ, e o `excludeSemantics` é o que garante isso: sem ele, o nome, o
    // preço, o "por mês" e o selo continuariam sendo quatro textos que o
    // compilador de semântica junta por acaso, e o `selected` moraria num nó
    // diferente do que carrega a ação.
    //
    // A ação declarada aqui é SELECIONAR. Era `onAssinar`, e trocá-la é o
    // conserto: o duplo-toque do leitor de tela sobre um card de vitrine deixa
    // de abrir uma cobrança.
    return Semantics(
      button: true,
      selected: selected,
      label: _rotulo,
      onTap: onTap,
      excludeSemantics: true,
      child: Stack(
      clipBehavior: Clip.none,
      children: [
        // O CARD É O FILHO QUE DIMENSIONA A PILHA, e não mais um
        // `Positioned.fill` dentro de uma caixa de altura escrita à mão. É esta
        // troca que faz o conteúdo mandar na altura.
        Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(17),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: highlight
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF8DEA0), Color(0xFFEAB43E)],
                        )
                      : null,
                  color: highlight ? null : const Color(0xFF211406),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: highlight ? const Color(0xFFF7D36A) : const Color(0xFF66501A),
                    width: highlight ? 1.4 : 1,
                  ),
                  boxShadow: highlight
                      ? const [
                          BoxShadow(
                            color: Color(0x33F3C64F),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 20, 7, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        plano.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlight ? const Color(0xFF5A3A06) : const Color(0xFFD7C9A9),
                          fontSize: 13.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          plano.preco,
                          style: TextStyle(
                            color: highlight ? const Color(0xFF3D2705) : LojaScreen.goldHi,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plano.porMes,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Era `#6D4A12`: 4,21:1 sobre a base do gradiente,
                          // abaixo da régua. `#4E3208` fica no mesmo marrom da
                          // identidade e dá 6,22:1 no pior extremo.
                          color: highlight
                              ? const Color(0xFF4E3208)
                              : const Color(0xFFAE9E79),
                          fontSize: 10.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (plano.selo != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          plano.selo!.contains('·')
                              ? plano.selo!.split('·').last.trim()
                              : plano.selo!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            // O PIOR PAR DA AUDITORIA: verde-menta sobre
                            // dourado dava 1,14:1 — o desconto era invisível
                            // justamente no card em destaque, que é o que
                            // sempre carrega o maior desconto. `#0F3D2A` é o
                            // mesmo verde, escurecido até 6,45:1 no pior
                            // extremo do gradiente. Fora do destaque, o
                            // verde-menta original já passava com folga e fica.
                            color: highlight
                                ? const Color(0xFF0F3D2A)
                                : const Color(0xFF5BE0A2),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (plano.selo != null && plano.selo!.contains('MELHOR'))
          Positioned(
            top: -9,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: LojaScreen.gold,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                plano.selo!.split('·').first.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4B3005),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: LojaScreen.gold,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
      ),
    );
  }
}

class _PacoteCard extends StatelessWidget {
  final PacoteMoedas pacote;
  final String moedas;
  final VoidCallback onComprar;
  final VoidCallback onPresentear;

  const _PacoteCard({
    required this.pacote,
    required this.moedas,
    required this.onComprar,
    required this.onPresentear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
              decoration: BoxDecoration(
                color: LojaScreen.card,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFF146047), width: 1.2),
              ),
              child: Column(
                children: [
                  Text(pacote.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: 7),
                  Text(
                    moedas,
                    style: const TextStyle(
                      color: LojaScreen.goldHi,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    child: pacote.bonus == null
                        ? null
                        : Text(
                            pacote.bonus!,
                            style: const TextStyle(
                              color: Color(0xFF6CE2A9),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onComprar,
                      style: FilledButton.styleFrom(
                        backgroundColor: LojaScreen.gold,
                        foregroundColor: const Color(0xFF3D2705),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        pacote.preco,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextButton.icon(
                    onPressed: onPresentear,
                    icon: const Text('🎁', style: TextStyle(fontSize: 14)),
                    label: const Text('Presentear'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDCC991),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pacote.selo != null)
            Positioned(
              top: -8,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: pacote.selo == 'Popular'
                      ? const Color(0xFFB33438)
                      : const Color(0xFF5C2F88),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  pacote.selo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final CategoriaCosmetico categoria;
  final VoidCallback onTap;

  const _CategoriaCard({required this.categoria, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          decoration: BoxDecoration(
            color: LojaScreen.card,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF146047), width: 1.1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(categoria.icone, style: const TextStyle(fontSize: 31)),
                const SizedBox(height: 7),
                Text(
                  categoria.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDCCDA8),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  categoria.subtitulo,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LojaScreen.muted,
                    fontSize: 10.5,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompraSheet extends StatelessWidget {
  final PacoteMoedas pacote;
  final String moedasFormatadas;
  final VoidCallback onConfirmar;

  const _CompraSheet({
    required this.pacote,
    required this.moedasFormatadas,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      cabecalho: const _SheetHeader(
        title: 'Confirmar compra',
        subtitle: 'Revise antes de comprar',
        rotuloFechar: 'Fechar confirmação de compra',
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF150E09),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: LojaScreen.border),
            ),
            child: Row(
              children: [
                Text(pacote.emoji, style: const TextStyle(fontSize: 38)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$moedasFormatadas moedas',
                        style: const TextStyle(
                          color: LojaScreen.goldHi,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (pacote.bonus != null)
                        Text(
                          '${pacote.bonus} de bônus',
                          style: const TextStyle(
                            color: Color(0xFF66DDA5),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  pacote.preco,
                  style: const TextStyle(
                    color: LojaScreen.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onConfirmar,
            style: FilledButton.styleFrom(
              backgroundColor: LojaScreen.gold,
              foregroundColor: const Color(0xFF3D2705),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            child: const Text('Comprar agora'),
          ),
        ],
      ),
    );
  }
}

class _PresenteSheet extends StatefulWidget {
  final String titulo;
  final String emoji;
  final List<AmigoPresente> amigos;
  final ValueChanged<String> onBuscar;
  final ValueChanged<String> onEnviar;

  const _PresenteSheet({
    required this.titulo,
    required this.emoji,
    required this.amigos,
    required this.onBuscar,
    required this.onEnviar,
  });

  @override
  State<_PresenteSheet> createState() => _PresenteSheetState();
}

class _PresenteSheetState extends State<_PresenteSheet> {
  String _termo = '';
  String? _selecionado;

  List<AmigoPresente> get _filtrados {
    final termo = _termo.trim().toLowerCase();
    if (termo.isEmpty) return widget.amigos;
    return widget.amigos
        .where((amigo) =>
            amigo.nome.toLowerCase().contains(termo) || amigo.id.toLowerCase().contains(termo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return _SheetShell(
      bottomInset: bottom,
      cabecalho: _SheetHeader(
        title: '🎁 Presentear · ${widget.titulo}',
        subtitle: 'Escolha quem vai receber',
        rotuloFechar: 'Fechar seleção de presente',
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 13),
          TextField(
            onChanged: (value) {
              setState(() => _termo = value);
              widget.onBuscar(value);
            },
            style: const TextStyle(color: LojaScreen.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar jogador pelo nome ou ID…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: .35)),
              prefixIcon: const Icon(Icons.search, color: LojaScreen.gold, size: 20),
              filled: true,
              fillColor: const Color(0xFF120C08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: LojaScreen.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: LojaScreen.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: LojaScreen.gold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _filtrados.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum amigo encontrado',
                          style: TextStyle(color: LojaScreen.muted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final amigo = _filtrados[index];
                        final selected = amigo.id == _selecionado;
                        return InkWell(
                          onTap: () => setState(() => _selecionado = amigo.id),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF233A26)
                                  : const Color(0xFF160F09),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4AAA75)
                                    : LojaScreen.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(amigo.avatar, style: const TextStyle(fontSize: 27)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    amigo.nome,
                                    style: const TextStyle(
                                      color: LojaScreen.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Text(
                                    '✓',
                                    style: TextStyle(
                                      color: Color(0xFF66E5AF),
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _selecionado == null ? null : () => widget.onEnviar(_selecionado!),
            icon: Text(widget.emoji, style: const TextStyle(fontSize: 18)),
            label: const Text('Enviar presente'),
            style: FilledButton.styleFrom(
              backgroundColor: LojaScreen.gold,
              disabledBackgroundColor: const Color(0xFF4B3C21),
              foregroundColor: const Color(0xFF3D2705),
              disabledForegroundColor: const Color(0xFF857657),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// A casca das folhas modais, com CABEÇALHO FIXO E CORPO ROLÁVEL.
///
/// ---------------------------------------------------------------------------
/// O QUE ESTAVA ERRADO
/// ---------------------------------------------------------------------------
///
/// Ela era `Center > Container > child`, e o `child` de cada folha é um `Column`
/// de altura mínima. Não havia região de rolagem nenhuma: quando o conteúdo
/// passava da altura disponível, o `Column` estourava e o excedente
/// simplesmente deixava de existir para quem olha — e para quem lê.
///
/// A medição da folha de confirmação, antes desta correção:
///
///     largura  escala   estouro   "Continuar"        "Cancelar"
///     320 dp   130%     51 pt     554..617 visível   640..659 FORA
///     320 dp   150%     sim       707..779 FORA      800..822 FORA
///     320 dp   200%     sim      1115..1243 FORA    1261..1290 FORA
///     360 dp   175%     195 pt    817..901 FORA      921..946 FORA
///     412 dp   200%     168 pt    913..1009 FORA    1027..1056 FORA
///
/// Sete das quinze combinações obrigatórias estouravam. Em seis delas os DOIS
/// botões comerciais ficavam inteiramente fora da tela, e a 320 dp / 200% eles
/// nem apareciam na árvore semântica — a folha oferecia uma decisão de compra
/// sem oferecer as duas saídas dela. Arrastar não movia nada (não havia o que
/// rolar) e o `Tab` conseguia FOCAR botões que nunca entravam na tela.
///
/// ---------------------------------------------------------------------------
/// POR QUE O CABEÇALHO FICA FORA DA ROLAGEM
/// ---------------------------------------------------------------------------
///
/// Rolar a folha inteira também resolveria o estouro, e foi descartado: o "X" é
/// a saída da folha, e uma saída que depende de rolar até ela é pior do que uma
/// que está sempre no mesmo lugar. Com o cabeçalho fixo, fechar é sempre um
/// gesto só, em qualquer escala.
///
/// [Flexible] com `SingleChildScrollView` dá o comportamento nos dois sentidos:
/// quando o corpo cabe, ele fica do tamanho do conteúdo e NÃO rola — não há
/// deslocamento artificial em tela ampla; quando não cabe, ele ocupa o que
/// sobrou e rola.
class _SheetShell extends StatelessWidget {
  /// O que fica FIXO no alto. Fora da região de rolagem, de propósito.
  final Widget? cabecalho;

  /// O que rola quando não couber.
  final Widget child;

  final double bottomInset;

  const _SheetShell({
    required this.child,
    this.cabecalho,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF21150D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF755A1D), width: 1.2)),
              ),
              // O padding saiu do `Container` e entrou nas duas partes: o do
              // corpo precisa ficar DENTRO da área rolável, senão a margem de
              // baixo vira uma faixa morta que o último botão nunca alcança.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cabecalho != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: cabecalho,
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        cabecalho == null ? 10 : 0,
                        18,
                        18,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  /// O nome acessível do "X".
  ///
  /// Ele era um `IconButton` com `Icons.close` e sem `tooltip`: o nó existia,
  /// tinha papel de botão e 48×48 — e rótulo VAZIO. Cada folha passa um nome
  /// contextual, porque "Fechar" sozinho não diz o que se está fechando quando
  /// há mais de uma folha na tela ao longo do fluxo.
  final String rotuloFechar;

  const _SheetHeader({
    required this.title,
    required this.subtitle,
    this.rotuloFechar = 'Fechar',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF765F32),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LojaScreen.goldHi,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    // Era `LojaScreen.muted` (#8A7C5E): 4,35:1, logo abaixo da
                    // régua. Mesma família, dois tons acima.
                    style: const TextStyle(
                      color: Color(0xFFAB9C78),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Mesmo motivo do Voltar: o nome é `label`. Com `tooltip` o rótulo
            // ficaria vazio, que é exatamente o estado auditado.
            Semantics(
              button: true,
              label: rotuloFechar,
              onTap: () => Navigator.of(context).pop(),
              excludeSemantics: true,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close, color: LojaScreen.goldHi),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final ValueChanged<NavDestino> onTap;
  const _BottomNav({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: LojaScreen.border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 4),
      child: Row(
        children: [
          _item(NavDestino.inicio, 'Início', 'assets/ranking/nav_inicio.webp', false),
          _item(NavDestino.ranking, 'Ranking', 'assets/ranking/nav_ranking.webp', false),
          _item(NavDestino.loja, 'Loja', 'assets/ranking/nav_loja.webp', true),
          _item(NavDestino.perfil, 'Perfil', 'assets/ranking/nav_perfil.webp', false),
        ],
      ),
    );
  }

  Widget _item(NavDestino destino, String label, String asset, bool active) {
    return Expanded(
      // Um nó por destino: papel de botão, nome, e o `selected` que diz qual
      // aba é a de agora. Antes NENHUM item carregava `selected` — nem o
      // próprio "Loja", que é a tela em que a pessoa está —, e a distinção
      // existia só na cor e no peso da fonte.
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        onTap: () => onTap(destino),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onTap(destino),
          child: ConstrainedBox(
            // 90×47 era o tamanho medido, e 47 reprova por um ponto. O mínimo
            // agora é declarado, e não uma consequência do conteúdo.
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // A MARCA DA ABA ATUAL, que não é cor. Um traço dourado sobre o
                // item ativo dá 11,11:1 contra a barra — acima da régua de 3:1
                // para elemento gráfico — e continua legível para quem não
                // distingue o dourado do branco acinzentado.
                Container(
                  height: 3,
                  width: 22,
                  decoration: BoxDecoration(
                    color: active ? LojaScreen.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Image.asset(
                  asset,
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 26, height: 26),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // Era branco a 26% de opacidade: 2,20:1 sobre a barra, para
                    // três dos quatro destinos, o tempo todo. A 55% dá 6,27:1.
                    color: active
                        ? LojaScreen.gold
                        : Colors.white.withValues(alpha: .55),
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
