import 'package:flutter/material.dart';

import 'perfil_screen.dart' show NavDestino;

enum LojaCategoria { dorsos, molduras, avatares, mascotes, efeitos, emojis }

class LojaVM {
  final int moedas;
  final int gemas;
  final bool ehVip;
  final List<PlanoVipLoja> planos;
  final List<String> beneficiosVip;
  final List<PacoteMoedas> pacotes;
  final List<CategoriaCosmetico> categorias;
  final List<AmigoPresente> amigos;

  const LojaVM({
    required this.moedas,
    required this.gemas,
    required this.ehVip,
    required this.planos,
    required this.beneficiosVip,
    required this.pacotes,
    required this.categorias,
    required this.amigos,
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
  final ValueChanged<String> onAssinar;
  final ValueChanged<String> onComprarPacote;
  final ValueChanged<String> onConfirmarCompra;
  final ValueChanged<LojaCategoria> onAbrirCategoria;
  final ValueChanged<String> onPresentear;
  final ValueChanged<String> onBuscarPresenteado;
  final void Function(String itemId, String jogadorId) onEnviarPresente;

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
  });

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final GlobalKey _moedasKey = GlobalKey();
  String? _planoSelecionado;

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
  }

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

  void _selecionarPlano(PlanoVipLoja plano) {
    setState(() => _planoSelecionado = plano.id);
    widget.onAssinar(plano.id);
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
                    moedas: _formatarInteiro(widget.vm.moedas),
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
                            onPlanoTap: _selecionarPlano,
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
                          const SizedBox(height: 24),
                          const _SectionTitle(label: 'COSMÉTICOS'),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final spacing = 10.0;
                              final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
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
                                        onTap: () => widget.onAbrirCategoria(categoria.id),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
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
  final String moedas;
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
          InkResponse(
            onTap: onVoltar,
            radius: 25,
            child: const SizedBox(
              width: 35,
              height: 42,
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
          const Text(
            'Loja',
            style: TextStyle(
              color: LojaScreen.goldHi,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          InkWell(
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
                    moedas,
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
        ],
      ),
    );
  }
}

class _VipShowcase extends StatelessWidget {
  final LojaVM vm;
  final String? selectedPlanId;
  final ValueChanged<PlanoVipLoja> onPlanoTap;
  final VoidCallback onPresentear;

  const _VipShowcase({
    required this.vm,
    required this.selectedPlanId,
    required this.onPlanoTap,
    required this.onPresentear,
  });

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
          const SizedBox(height: 14),
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
          else
            _PlanosGrid(
              planos: vm.planos,
              selectedPlanId: selectedPlanId,
              onTap: onPlanoTap,
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPresentear,
            icon: const Text('🎁', style: TextStyle(fontSize: 18)),
            label: const Text('Presentear assinatura VIP'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LojaScreen.goldHi,
              side: const BorderSide(color: Color(0xFF9A7521)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    if (planos.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = planos.length <= 3 ? planos.length : 2;
        final spacing = 8.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            for (final plano in planos)
              SizedBox(
                width: width,
                height: 132,
                child: _PlanoCard(
                  plano: plano,
                  selected: plano.id == selectedPlanId,
                  onTap: () => onTap(plano),
                ),
              ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final highlight = plano.destaque || selected;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Material(
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
                  padding: const EdgeInsets.fromLTRB(7, 20, 7, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        plano.nome,
                        maxLines: 1,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlight
                              ? const Color(0xFF6D4A12)
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
                          style: const TextStyle(
                            color: Color(0xFF5BE0A2),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            title: 'Confirmar compra',
            subtitle: 'Revise antes de comprar',
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: '🎁 Presentear · ${widget.titulo}',
            subtitle: 'Escolha quem vai receber',
          ),
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

class _SheetShell extends StatelessWidget {
  final Widget child;
  final double bottomInset;

  const _SheetShell({required this.child, this.bottomInset = 0});

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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF21150D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF755A1D), width: 1.2)),
              ),
              child: child,
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

  const _SheetHeader({required this.title, required this.subtitle});

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
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LojaScreen.goldHi,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: LojaScreen.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: LojaScreen.goldHi),
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
                  color: active ? LojaScreen.gold : Colors.white.withValues(alpha: .26),
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
