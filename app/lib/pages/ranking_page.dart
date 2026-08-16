import 'package:flutter/material.dart';

import '../ranking/ranking_apresentacao.dart';
import '../ranking/ranking_contract.dart';
import '../ranking/ranking_paginacao.dart';
import '../screens/perfil_screen.dart' show NavDestino;
import '../screens/ranking_screen.dart';
import '../services/ranking_service.dart';
import 'hall_page.dart';
import 'perfil_page.dart';

/// Controlador da tela de Ranking (camada de lógica).
///
/// Substitui o `_RankingPreviewHost` que vivia no `main.dart` e desenhava
/// `RankingVM.mock()`. Responsabilidade: pedir os dados ao [RankingService],
/// administrar estados e paginação, e ligar os callbacks da UI a navegação
/// real. **Não altera o visual** — a interface é 100% da [RankingScreen].
///
/// Autoridade: nada aqui decide posição, pontos, liga, temporada ou premiação.
/// A tela repete o que a fonte publicou.
class RankingPage extends StatefulWidget {
  const RankingPage({
    super.key,
    this.service = const RankingSemFonte(),
    this.escopoInicial = RankingEscopo.temporada,
  });

  /// Fonte dos dados. O padrão é a implementação honesta de “ainda não há fonte
  /// oficial”; trocar por uma fonte real é trocar este argumento.
  final RankingService service;

  final RankingEscopo escopoInicial;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  /// Um paginador por aba: trocar de aba não mistura listas nem refaz a busca
  /// da aba anterior, e voltar para uma aba já carregada não dispara rede.
  final Map<RankingEscopo, RankingPaginador> _paginadores = {};

  late RankingEscopo _escopo;

  @override
  void initState() {
    super.initState();
    _escopo = widget.escopoInicial;
    _paginador.abrir().then(_reconstruir);
  }

  @override
  void dispose() {
    // Corta todos: resposta que ainda estiver viajando é descartada ao chegar,
    // em vez de mexer em tela que já saiu.
    for (final paginador in _paginadores.values) {
      paginador.descartar();
    }
    super.dispose();
  }

  RankingPaginador get _paginador => _paginadores.putIfAbsent(
        _escopo,
        () => RankingPaginador(service: widget.service, escopo: _escopo),
      );

  void _reconstruir([Object? _]) {
    if (!mounted) return;
    setState(() {});
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1400),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _trocarAba(RankingAba aba) {
    final escopo = escopoDaAba(aba);
    if (escopo == _escopo) return;
    setState(() => _escopo = escopo);
    _paginador.abrir().then(_reconstruir);
  }

  void _recarregar() {
    final paginador = _paginador;
    final futuro = paginador.recarregar();
    _reconstruir();
    futuro.then(_reconstruir);
  }

  void _carregarMais() {
    final paginador = _paginador;
    if (paginador.carregandoMais || !paginador.temMais) return;
    final futuro = paginador.carregarMais();
    _reconstruir();
    futuro.then((_) {
      if (!mounted) return;
      setState(() {});
      // Falha de página posterior avisa sem apagar o que já está na tela.
      final erro = paginador.erroDePagina;
      if (erro != null) _aviso(erro);
    });
  }

  /// Ranking → Perfil. A tela entrega a POSIÇÃO tocada; aqui ela vira o
  /// identificador público na página que já está em mãos. Sem id publicado,
  /// não se navega — posição não é chave de navegação.
  void _verJogador(int posicao) {
    final paginador = _paginador;
    final id = idNaPosicao(
      posicao,
      resumo: paginador.resumo,
      itens: paginador.itens,
    );
    if (id == null) {
      _aviso('Este jogador ainda não tem perfil público.');
      return;
    }
    final souEu = _souEu(posicao);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerfilPage(ehMeuPerfil: souEu, jogadorId: souEu ? null : id),
      ),
    );
  }

  bool _souEu(int posicao) {
    final paginador = _paginador;
    for (final j in paginador.resumo?.podio ?? const <RankingJogador>[]) {
      if (j.posicao == posicao) return j.souEu;
    }
    for (final j in paginador.itens) {
      if (j.posicao == posicao) return j.souEu;
    }
    return false;
  }

  RankingEstado _estadoDaTela(RankingFase fase) {
    switch (fase) {
      case RankingFase.inicial:
      case RankingFase.carregando:
        return RankingEstado.carregando;
      case RankingFase.pronto:
        return RankingEstado.normal;
      case RankingFase.vazio:
        return RankingEstado.vazio;
      case RankingFase.erro:
        return RankingEstado.erro;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginador = _paginador;
    final estado = _estadoDaTela(paginador.fase);

    final vm = montarRankingVM(
      escopo: _escopo,
      resumo: paginador.resumo,
      itens: paginador.itens,
    );

    return RankingScreen(
      vm: vm,
      estado: estado,
      mensagemErro: paginador.mensagemErro,
      onVoltar: () => Navigator.of(context).maybePop(),
      onTrocarAba: _trocarAba,
      onAbrirHall: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HallPage()),
      ),
      onVerJogador: _verJogador,
      onRecarregar: _recarregar,
      // “Carregar mais” só aparece quando existe próxima página de verdade.
      onCarregarMais: paginador.temMais ? _carregarMais : null,
      onNavTap: (destino) {
        switch (destino) {
          case NavDestino.inicio:
            Navigator.of(context).maybePop();
            break;
          case NavDestino.ranking:
            break;
          case NavDestino.loja:
            _aviso('Loja VIP — chega nas próximas fatias 👍');
            break;
          case NavDestino.perfil:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const PerfilPage()),
            );
            break;
        }
      },
    );
  }
}
