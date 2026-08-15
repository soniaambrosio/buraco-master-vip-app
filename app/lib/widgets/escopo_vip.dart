// escopo_vip.dart — o portao VIP disponivel para a arvore de widgets inteira.
//
// POR QUE UM ESCOPO, E NAO UMA CONSULTA POR TELA
//
// Cada host de `main.dart` que precisa saber se o jogador e VIP poderia abrir a
// propria escuta de `playerEntitlements/{uid}`. Foi mais ou menos isso que
// aconteceu ate aqui, e o resultado foi que cada tela acabou com o proprio
// booleano — um deles nascendo `true` por padrao de uma `VM.mock()`. Varias
// escutas tambem significam varias respostas possiveis para a mesma pergunta no
// mesmo instante, e a pergunta "este jogador e VIP?" nao pode ter duas respostas.
//
// Com o escopo, ha UMA escuta por sessao e uma resposta so. Uma tela nova que
// esqueca de consultar o escopo nao ganha VIP por engano: ela simplesmente nao
// tem de onde tirar um `true`.
//
// A SESSAO ENTRA POR STREAM, E ISSO E O QUE FECHA O LOGOUT
//
// `FirebaseAuth.instance.currentUser` lido uma vez em `initState` e uma
// fotografia: quem entrasse depois nao seria observado, e quem TROCASSE de conta
// continuaria com o retrato do jogador anterior. Aqui a identidade chega por
// `authStateChanges()`, e cada mudanca reprograma o portao — que descarta o
// direito antigo antes de qualquer leitura nova.
//
// O STREAM E INJETAVEL para que a invariante de troca de conta seja exercitavel
// em `flutter test`, onde `FirebaseAuth.instance` nao existe. Ver
// `app/test/billing/portao_vip_test.dart` e `escopo_vip_test.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../billing/acesso_vip.dart';

/// Disponibiliza um [PortaoVip] para os descendentes.
///
/// Quem consome chama [EscopoVip.de], que devolve o retrato JA DECIDIDO. Nao ha
/// como um descendente alcancar um setter — nao existe nenhum.
class EscopoVip extends StatefulWidget {
  const EscopoVip({
    super.key,
    required this.portao,
    required this.sessoes,
    required this.child,
  });

  /// O portao que decide. Quem o cria e responsavel por [PortaoVip.encerrar].
  final PortaoVip portao;

  /// O uid da sessao ao longo do tempo. `null` em cada emissao significa
  /// logout. Em producao e `FirebaseAuth.instance.authStateChanges()` mapeado
  /// para o uid.
  final Stream<String?> sessoes;

  final Widget child;

  /// O acesso VIP do jogador da sessao corrente.
  ///
  /// Fora de um [EscopoVip] devolve [AcessoVip.indefinido], que BLOQUEIA. Um
  /// widget montado por engano fora da arvore do escopo perde o acesso VIP; ele
  /// nunca ganha. Essa e a direcao certa da falha, e por isso aqui nao ha
  /// `assert` de escopo obrigatorio.
  static AcessoVip de(BuildContext context) {
    final heranca =
        context.dependOnInheritedWidgetOfExactType<_HerancaVip>();
    // `atual` e recalculado contra o relogio a cada build: um direito que vence
    // com a tela aberta deixa de liberar no proximo quadro, sem depender de o
    // Firestore emitir evento nenhum no segundo do vencimento.
    return heranca?.portao.atual ?? const AcessoVip.indefinido();
  }

  @override
  State<EscopoVip> createState() => _EscopoVipState();
}

class _EscopoVipState extends State<EscopoVip> {
  StreamSubscription<String?>? _escutaSessao;
  StreamSubscription<AcessoVip>? _escutaAcesso;

  /// Sobe a cada fato novo. E o que faz o [InheritedWidget] notificar: o proprio
  /// [AcessoVip] nao serve de gatilho porque ele e recalculado a cada leitura e
  /// duas instancias equivalentes nao sao identicas.
  int _revisao = 0;

  @override
  void initState() {
    super.initState();
    _escutaSessao = widget.sessoes.listen(
      widget.portao.usarSessao,
      // Falha na propria escuta de sessao vira logout: sem identidade confiavel
      // nao ha direito a afirmar.
      onError: (Object _) => widget.portao.usarSessao(null),
    );
    _escutaAcesso = widget.portao.mudancas.listen((_) {
      if (mounted) setState(() => _revisao++);
    });
  }

  @override
  void dispose() {
    _escutaSessao?.cancel();
    _escutaAcesso?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HerancaVip(
      portao: widget.portao,
      revisao: _revisao,
      child: widget.child,
    );
  }
}

class _HerancaVip extends InheritedWidget {
  const _HerancaVip({
    required this.portao,
    required this.revisao,
    required super.child,
  });

  final PortaoVip portao;
  final int revisao;

  @override
  bool updateShouldNotify(_HerancaVip anterior) =>
      revisao != anterior.revisao || !identical(portao, anterior.portao);
}
