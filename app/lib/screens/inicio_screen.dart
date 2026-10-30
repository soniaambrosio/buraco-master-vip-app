import 'package:flutter/material.dart';

import 'perfil_screen.dart' show NavDestino;

enum InicioEstado { carregando, normal, erro }

class CabecalhoJogador {
  final String nome;
  final String email;
  final String avatar;
  final String? moldura;
  final int moedas;
  final String liga;

  const CabecalhoJogador({
    required this.nome,
    required this.email,
    required this.avatar,
    required this.moldura,
    required this.moedas,
    required this.liga,
  });
}

class TemporadaBanner {
  final String titulo;
  final String subtitulo;
  final String icone;

  const TemporadaBanner({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
  });
}

class LobbyBanner {
  final String titulo;
  final String subtitulo;
  final int online;
  final bool cadeadoVip;

  const LobbyBanner({
    required this.titulo,
    required this.subtitulo,
    required this.online,
    required this.cadeadoVip,
  });
}

class MenuItem {
  final String id;
  final String label;
  final String icone;
  final String? badge;

  const MenuItem({
    required this.id,
    required this.label,
    required this.icone,
    this.badge,
  });
}

class InicioVM {
  final CabecalhoJogador jogador;
  final TemporadaBanner? temporada;
  final LobbyBanner lobby;
  final List<MenuItem> menu;

  const InicioVM({
    required this.jogador,
    required this.temporada,
    required this.lobby,
    required this.menu,
  });

  factory InicioVM.mock() {
    return const InicioVM(
      jogador: CabecalhoJogador(
        nome: 'Sônia Rainha',
        email: 'soniia.ambrosio@gmail.com',
        avatar: '👑',
        moldura: null,
        moedas: 1000,
        liga: 'Diamante',
      ),
      temporada: TemporadaBanner(
        titulo: 'Próxima temporada: Natal',
        subtitulo: 'começa em 134 dias — já dá pra se preparar!',
        icone: 'assets/inicio/temporada_natal.webp',
      ),
      lobby: LobbyBanner(
        titulo: 'Lobby Público e VIP',
        subtitulo: 'ache seu parceiro e veja mesas abertas',
        online: 128,
        cadeadoVip: true,
      ),
      menu: [
        MenuItem(
          id: 'perfil',
          label: 'Perfil',
          icone: 'assets/inicio/menu_perfil.webp',
        ),
        MenuItem(
          id: 'ranking',
          label: 'Ranking',
          icone: 'assets/inicio/menu_ranking.webp',
        ),
        MenuItem(
          id: 'recompensas',
          label: 'Recompensas',
          icone: 'assets/inicio/menu_recompensas.webp',
        ),
        MenuItem(
          id: 'amigos',
          label: 'Amigos',
          icone: 'assets/inicio/menu_amigos.webp',
        ),
        MenuItem(
          id: 'loja',
          label: 'Loja VIP',
          icone: 'assets/inicio/menu_loja_vip.webp',
        ),
        MenuItem(
          id: 'jogar',
          label: 'Jogar',
          icone: 'assets/inicio/menu_jogar.webp',
        ),
        MenuItem(
          id: 'tutorial',
          label: 'Como jogar',
          icone: 'assets/inicio/menu_como_jogar.webp',
        ),
        MenuItem(
          id: 'ajustes',
          label: 'Ajustes',
          icone: 'assets/inicio/menu_ajustes.webp',
        ),
      ],
    );
  }
}

class InicioScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x33EFB94A);

  final InicioVM vm;
  final InicioEstado estado;
  final String? mensagemErro;
  final VoidCallback onJogar;
  final VoidCallback onAbrirPerfil;
  final VoidCallback onHistorico;
  final VoidCallback onAbrirTemporada;
  final VoidCallback onAbrirLobby;
  final ValueChanged<String> onMenuTap;
  final VoidCallback onRecarregar;
  final ValueChanged<NavDestino> onNavTap;

  const InicioScreen({
    super.key,
    required this.vm,
    required this.estado,
    required this.onJogar,
    required this.onAbrirPerfil,
    required this.onHistorico,
    required this.onAbrirTemporada,
    required this.onAbrirLobby,
    required this.onMenuTap,
    required this.onRecarregar,
    required this.onNavTap,
    this.mensagemErro,
  });

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
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Expanded(child: _body(context)),
                  _BottomNav(onTap: onNavTap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (estado == InicioEstado.erro) {
      return _ErrorState(
        mensagem: mensagemErro ?? 'Não foi possível carregar a tela inicial.',
        onRecarregar: onRecarregar,
      );
    }

    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: () => Future<void>.sync(onRecarregar),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 370;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, compact ? 8 : 11, 16, 16),
            children: [
              _Brand(compact: compact),
              SizedBox(height: compact ? 12 : 15),
              if (estado == InicioEstado.carregando)
                const _InicioSkeleton()
              else ...[
                _PlayerCard(
                  jogador: vm.jogador,
                  onTap: onAbrirPerfil,
                  onHistorico: onHistorico,
                ),
                if (vm.temporada != null) ...[
                  const SizedBox(height: 9),
                  _SeasonCard(
                    temporada: vm.temporada!,
                    onTap: onAbrirTemporada,
                  ),
                ],
                const SizedBox(height: 9),
                _LobbyCard(lobby: vm.lobby, onTap: onAbrirLobby),
                SizedBox(height: compact ? 9 : 11),
                _PlayButton(onTap: onJogar),
                SizedBox(height: compact ? 17 : 21),
                const Text(
                  'MENU',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 9),
                _MenuGrid(
                  items: vm.menu,
                  compact: compact,
                  onTap: onMenuTap,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool compact;
  const _Brand({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('👑', style: TextStyle(fontSize: compact ? 35 : 38)),
        const SizedBox(height: 2),
        Text(
          'BURACO MASTER VIP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: InicioScreen._gold,
            fontSize: compact ? 22 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? .8 : 1.1,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'o buraco como se joga na vida real',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .54),
            fontSize: compact ? 12 : 12.5,
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final CabecalhoJogador jogador;
  final VoidCallback onTap;
  final VoidCallback onHistorico;

  const _PlayerCard({
    required this.jogador,
    required this.onTap,
    required this.onHistorico,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 7, 11),
          decoration: BoxDecoration(
            color: InicioScreen._card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: InicioScreen._border),
          ),
          child: Row(
            children: [
              _Avatar(jogador: jogador),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jogador.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InicioScreen._gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      jogador.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .42),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Image.asset(
                          'assets/inicio/moeda.webp',
                          width: 15,
                          height: 15,
                          errorBuilder: (_, __, ___) => const Text('🪙'),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatarInteiro(jogador.moedas)} · Liga ${jogador.liga}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: InicioScreen._goldHi,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onHistorico,
                tooltip: 'Histórico',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.history_rounded,
                  color: Colors.white.withValues(alpha: .22),
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final CabecalhoJogador jogador;
  const _Avatar({required this.jogador});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3A2606),
        border: Border.all(color: InicioScreen._gold, width: 2),
      ),
      alignment: Alignment.center,
      child: _AssetOrText(
        value: jogador.avatar,
        fit: BoxFit.cover,
        textSize: 28,
        circular: true,
      ),
    );

    if (jogador.moldura == null || jogador.moldura!.isEmpty) return avatar;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(padding: const EdgeInsets.all(3), child: avatar),
          IgnorePointer(
            child: Image.asset(
              jogador.moldura!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final TemporadaBanner temporada;
  final VoidCallback onTap;

  const _SeasonCard({required this.temporada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      borderColor: const Color(0x55EFB94A),
      child: Row(
        children: [
          _AssetOrText(value: temporada.icone, width: 40, height: 40, textSize: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temporada.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: InicioScreen._gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  temporada.subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .54),
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: InicioScreen._gold, size: 25),
        ],
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  final LobbyBanner lobby;
  final VoidCallback onTap;

  const _LobbyCard({required this.lobby, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x882F7D4D), width: 1.2),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF123020), Color(0xFF0D2216)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.more_horiz_rounded, color: Color(0xFF54636A), size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lobby.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC3EFD3),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (lobby.cadeadoVip) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF6E2A6), Color(0xFFD5A84A)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('🔒', style: TextStyle(fontSize: 9)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '🟢 '),
                          TextSpan(text: '${lobby.online} online agora · '),
                          TextSpan(text: lobby.subtitulo),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFA9D6BB),
                        fontSize: 12,
                        height: 1.16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FE0B0), size: 25),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color borderColor;

  const _TapCard({required this.child, required this.onTap, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Jogar',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(38),
          child: Image.asset(
            'assets/inicio/botao_jogar.webp',
            width: 300,
            height: 75,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 300,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)],
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: const Text(
                '🃏  Jogar',
                style: TextStyle(
                  color: Color(0xFF3A2606),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  final bool compact;
  final ValueChanged<String> onTap;

  const _MenuGrid({required this.items, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: compact ? 9 : 10,
        crossAxisSpacing: compact ? 9 : 10,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(item.id),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: InicioScreen._card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: InicioScreen._border),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AssetOrText(
                          value: item.icone,
                          width: compact ? 38 : 40,
                          height: compact ? 38 : 40,
                          textSize: 28,
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            item.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .70),
                              fontSize: compact ? 10.4 : 11,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D1532),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: InicioScreen._gold, width: .7),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
        border: Border(top: BorderSide(color: InicioScreen._border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 4),
      child: Row(
        children: [
          _item(NavDestino.inicio, 'Início', 'assets/ranking/nav_inicio.webp', true),
          _item(NavDestino.ranking, 'Ranking', 'assets/ranking/nav_ranking.webp', false),
          _item(NavDestino.loja, 'Loja', 'assets/ranking/nav_loja.webp', false),
          _item(NavDestino.perfil, 'Perfil', 'assets/ranking/nav_perfil.webp', false),
        ],
      ),
    );
  }

  Widget _item(NavDestino destino, String label, String asset, bool active) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(destino),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                asset,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 28, height: 28),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: active ? InicioScreen._gold : Colors.white.withValues(alpha: .26),
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensagem;
  final VoidCallback onRecarregar;

  const _ErrorState({required this.mensagem, required this.onRecarregar});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('♣️', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 14),
                  Text(
                    mensagem,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: .68), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRecarregar,
                    style: FilledButton.styleFrom(
                      backgroundColor: InicioScreen._gold,
                      foregroundColor: const Color(0xFF3A2606),
                    ),
                    child: const Text('Tentar de novo'),
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

class _InicioSkeleton extends StatelessWidget {
  const _InicioSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double height, {double radius = 14}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .04)),
          ),
        );

    return Column(
      children: [
        box(80, radius: 16),
        const SizedBox(height: 9),
        box(68),
        const SizedBox(height: 9),
        box(68),
        const SizedBox(height: 12),
        Center(child: box(70, radius: 35)),
        const SizedBox(height: 22),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('MENU', style: TextStyle(color: InicioScreen._gold, letterSpacing: 2)),
        ),
        const SizedBox(height: 9),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: List.generate(8, (_) => box(76)),
        ),
      ],
    );
  }
}

class _AssetOrText extends StatelessWidget {
  final String value;
  final double? width;
  final double? height;
  final double textSize;
  final BoxFit fit;
  final bool circular;

  const _AssetOrText({
    required this.value,
    this.width,
    this.height,
    this.textSize = 24,
    this.fit = BoxFit.contain,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Center(child: Text(value, style: TextStyle(fontSize: textSize)));

    if (value.startsWith('assets/')) {
      return ClipOval(
        clipBehavior: circular ? Clip.antiAlias : Clip.none,
        child: Image.asset(
          value,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ClipOval(
        clipBehavior: circular ? Clip.antiAlias : Clip.none,
        child: Image.network(
          value,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    return SizedBox(width: width, height: height, child: fallback());
  }
}

String _formatarInteiro(int valor) {
  final digits = valor.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return valor < 0 ? '-$out' : out.toString();
}
