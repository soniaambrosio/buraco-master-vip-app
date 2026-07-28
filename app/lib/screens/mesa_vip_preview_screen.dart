import 'dart:math' as math;

import 'package:flutter/material.dart';

const _vipGold = Color(0xFFE8BD60);
const _vipGoldHi = Color(0xFFFFE9A6);
const _vipPurple = Color(0xFF8F55C7);
const _vipPurpleHi = Color(0xFFD6A8FF);
const _vipPanel = Color(0xE80A0A0A);
const _vipBorder = Color(0xB3C99743);

class MesaVipPreviewScreen extends StatefulWidget {
  const MesaVipPreviewScreen({super.key});

  @override
  State<MesaVipPreviewScreen> createState() => _MesaVipPreviewScreenState();
}

class _MesaVipPreviewScreenState extends State<MesaVipPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  bool _minhaVez = false;
  bool _vulneravelEles = true;
  bool _vulneravelNos = true;

  static const _jogosEles = <List<_VipCard>>[
    [
      _VipCard('espadas', '7'),
      _VipCard('espadas', '8'),
      _VipCard('espadas', '9'),
      _VipCard('espadas', '10'),
      _VipCard('espadas', 'J'),
      _VipCard('espadas', 'Q'),
    ],
  ];

  static const _jogosNos = <List<_VipCard>>[
    [
      _VipCard('copas', '5'),
      _VipCard('copas', '6'),
      _VipCard('copas', '7'),
      _VipCard('copas', '8'),
    ],
    [
      _VipCard('paus', 'J'),
      _VipCard('paus', 'Q'),
      _VipCard('paus', 'K'),
    ],
  ];

  static const _lixo = <_VipCard>[
    _VipCard('ouros', 'Q'),
    _VipCard('copas', '3'),
    _VipCard('paus', '9'),
    _VipCard('espadas', '4'),
  ];

  static const _mao = <_VipCard>[
    _VipCard('espadas', 'A'),
    _VipCard('espadas', '3'),
    _VipCard('espadas', '5'),
    _VipCard('espadas', '6'),
    _VipCard('espadas', '8'),
    _VipCard('copas', 'A'),
    _VipCard('ouros', '5'),
    _VipCard('ouros', '7'),
    _VipCard('paus', '9'),
    _VipCard('paus', '10'),
    _VipCard('paus', 'K'),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/mesa_vip/fundo_preto_vip.webp',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x18000000), Color(0x4A000000)],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _header(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                8,
                                4,
                                8,
                                math.max(0.0, bottomInset - 2.0),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 43,
                                    child: _teamArea(
                                      top: true,
                                      jogos: _jogosEles,
                                    ),
                                  ),
                                  Expanded(flex: 14, child: _centralBand()),
                                  Expanded(
                                    flex: 43,
                                    child: _teamArea(
                                      top: false,
                                      jogos: _jogosNos,
                                      handReserve: 62,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: bottomInset,
                            height: 122,
                            child: _hand(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          height: 62,
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xF019140E), Color(0xF0060606)],
            ),
            border: Border.all(color: _vipBorder, width: 1.15),
          ),
          child: Row(
            children: [
              _roundButton(Icons.menu_rounded, _openTestMenu),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'BURACO MASTER VIP',
                        maxLines: 1,
                        style: TextStyle(
                          color: _vipGoldHi,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF603092), Color(0xFF2D163F)],
                        ),
                        border: Border.all(color: const Color(0xAAA86ADE)),
                      ),
                      child: const Text(
                        'MESA VIP',
                        style: TextStyle(
                          color: Color(0xFFF5E8FF),
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _metaRodada(),
              const SizedBox(width: 7),
              _roundButton(
                Icons.chat_bubble_outline_rounded,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat VIP — ligação pelo Claude.')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRodada() {
    Widget item(String label, String value) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFA89570),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: _vipGoldHi,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        );

    return SizedBox(
      width: 78,
      height: 38,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xC80A0908),
          border: Border.all(color: const Color(0x887B592A)),
        ),
        child: Row(
          children: [
            item('META', '1500'),
            Container(width: 1, height: 24, color: const Color(0x667B592A)),
            item('ROD.', '1'),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xD9100D0A),
            border: Border.all(color: const Color(0x887B592A)),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFEBD9A7)),
        ),
      );

  Widget _teamArea({
    required bool top,
    required List<List<_VipCard>> jogos,
    double handReserve = 0,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(2, top ? 3 : 2, 2, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x90050505),
        border: Border.all(color: const Color(0x886F5328), width: 1.1),
      ),
      child: Column(
        children: [
          _playerBar(top: top),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, handReserve),
              child: _gamesArea(jogos),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerBar({required bool top}) {
    final leftName = top ? 'Cláudia' : 'Mateus';
    final rightName = top ? 'Sofia' : 'você';
    final leftEmoji = top ? '🙂' : '😎';
    final rightEmoji = top ? 'RN' : '👑';
    final vulnerable = top ? _vulneravelEles : _vulneravelNos;
    final scoreLabel = top ? 'ELES 0' : 'NÓS 0';

    return SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 7,
            top: 6,
            bottom: 6,
            width: 136,
            child: _playerChip(
              name: leftName,
              emoji: leftEmoji,
              cards: top ? 11 : 9,
              alignRight: false,
            ),
          ),
          Positioned(
            right: 7,
            top: 6,
            bottom: 6,
            width: 136,
            child: _playerChip(
              name: rightName,
              emoji: rightEmoji,
              cards: top ? 7 : 12,
              alignRight: true,
              isUser: !top,
            ),
          ),
          Positioned(
            top: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xB40A0908),
                border: Border.all(color: const Color(0x667A5A2C)),
              ),
              child: Text(
                scoreLabel,
                style: TextStyle(
                  color: top
                      ? const Color(0xFFEAA59A)
                      : const Color(0xFF91E2B5),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: _vulnerableChip(active: vulnerable),
          ),
        ],
      ),
    );
  }

  Widget _playerChip({
    required String name,
    required String emoji,
    required int cards,
    required bool alignRight,
    bool isUser = false,
  }) {
    final avatar = Container(
      width: 45,
      height: 45,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF4F3619), Color(0xFF130D08)],
        ),
        border: Border.all(
          color: isUser ? _vipPurpleHi : _vipGold,
          width: isUser ? 2.4 : 1.8,
        ),
        boxShadow: isUser
            ? const [BoxShadow(color: Color(0x668F55C7), blurRadius: 9)]
            : const [],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );

    final info = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: alignRight
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (isUser)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF7048A0),
                  ),
                  child: const Text(
                    'VOCÊ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 5.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      alignRight ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFFF2E5C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            height: 17,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFF8F3C35), Color(0xFF4F1B1B)],
              ),
              border: Border.all(color: const Color(0x668D652D)),
            ),
            child: Text(
              '$cards',
              style: const TextStyle(
                color: Color(0xFFFFEAD8),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    return Row(
      children: alignRight
          ? [info, const SizedBox(width: 6), avatar]
          : [avatar, const SizedBox(width: 6), info],
    );
  }

  Widget _vulnerableChip({required bool active}) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = active ? _pulse.value : 0.0;
        return Transform.scale(
          scale: 1 + (0.025 * t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF472060), Color(0xFF170C20)],
                    )
                  : const LinearGradient(
                      colors: [Color(0x40181715), Color(0x30100C0A)],
                    ),
              border: Border.all(
                color: active
                    ? Color.lerp(_vipPurple, _vipGoldHi, t)!
                    : const Color(0x337B592A),
                width: active ? 1.15 : 0.8,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _vipPurple.withValues(alpha: 0.18 + 0.28 * t),
                        blurRadius: 7 + (7 * t),
                      ),
                    ]
                  : const [],
            ),
            child: Text(
              'VULNERÁVEL - 75',
              style: TextStyle(
                color: active
                    ? const Color(0xFFF7E8FF)
                    : const Color(0x667F735C),
                fontSize: 6.7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.45,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gamesArea(List<List<_VipCard>> jogos) {
    if (jogos.isEmpty) {
      return const Center(
        child: Text(
          'ESPAÇO PARA OS JOGOS',
          style: TextStyle(
            color: Color(0x2FFFFFFF),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Wrap(
        spacing: 10,
        runSpacing: 11,
        children: [for (final jogo in jogos) _meld(jogo)],
      ),
    );
  }

  Widget _meld(List<_VipCard> cards) {
    const cardW = 52.0;
    const cardH = 78.0;
    const step = cardW * 0.5;
    final totalW = ((cards.length - 1) * step) + cardW;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: const Color(0x52000000),
        border: Border.all(color: const Color(0x66855F2A)),
      ),
      child: SizedBox(
        width: totalW,
        height: cardH,
        child: Stack(
          children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                left: i * step,
                child: _card(cards[i], width: cardW, height: cardH),
              ),
          ],
        ),
      ),
    );
  }

  Widget _centralBand() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xE20A0908),
        border: Border.all(color: const Color(0x997B592A), width: 1.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _centerCell(
              label: 'MONTE',
              count: '34',
              child: _back(),
            ),
          ),
          _centerDivider(),
          Expanded(
            child: _centerCell(
              label: 'LIXO',
              count: '${_lixo.length}',
              onOpen: _openTrash,
              child: _card(_lixo.last, width: 49, height: 73),
            ),
          ),
          _centerDivider(),
          Expanded(
            child: _centerCell(
              label: 'MORTO 1',
              count: 'OK',
              child: _back(),
            ),
          ),
          _centerDivider(),
          Expanded(
            child: _centerCell(
              label: 'MORTO 2',
              count: 'OK',
              child: _back(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerDivider() => Container(
        width: 1,
        height: 76,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: const Color(0x447B592A),
      );

  Widget _centerCell({
    required String label,
    required String count,
    required Widget child,
    VoidCallback? onOpen,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Color(0xFFE2C981),
                  fontSize: 6.6,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.35,
                ),
              ),
            ),
            if (onOpen != null) ...[
              const SizedBox(width: 3),
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: const Color(0x332A1438),
                    border: Border.all(color: const Color(0x668F55C7)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 7, color: _vipPurpleHi),
                      SizedBox(width: 2),
                      Text(
                        'ABRIR',
                        style: TextStyle(
                          color: _vipPurpleHi,
                          fontSize: 5.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 15,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF523513), Color(0xFF211408)],
                  ),
                  border: Border.all(color: const Color(0x887B592A)),
                ),
                child: Text(
                  count,
                  style: const TextStyle(
                    color: Color(0xFFF1DEAA),
                    fontSize: 6.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _back() => Container(
        width: 49,
        height: 73,
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [_vipPurpleHi, _vipGold, Color(0xFF5C3611)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.5),
          child: Image.asset(
            'assets/mesa_vip/dorso_vip.webp',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      );

  Widget _hand() {
    const cardW = 66.0;
    const cardH = 99.0;
    const step = cardW * 0.5;
    final totalW = ((_mao.length - 1) * step) + cardW;

    return ClipRect(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: Offset(0, _minhaVez ? 0 : 0.5),
        child: Container(
          color: const Color(0xD9000000),
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: SizedBox(
              width: totalW,
              height: cardH + 8,
              child: Stack(
                children: [
                  for (var i = 0; i < _mao.length; i++)
                    Positioned(
                      left: i * step,
                      bottom: 0,
                      child: _card(_mao[i], width: cardW, height: cardH),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(_VipCard card, {required double width, required double height}) {
    final asset = 'assets/baralho/${card.suit}_${card.value}.webp';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x44FFFFFF), width: 0.7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: const Color(0xFFF3EDE0),
          child: Center(
            child: Text(
              '${card.value}${card.symbol}',
              style: TextStyle(
                color: card.red ? const Color(0xFF9C302E) : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTrash() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 245,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            colors: [Color(0xFF1A121D), Color(0xFF080706)],
          ),
          border: Border(top: BorderSide(color: _vipGold, width: 1.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined, color: _vipPurpleHi),
                const SizedBox(width: 8),
                const Text(
                  'LIXO ABERTO',
                  style: TextStyle(
                    color: _vipGoldHi,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_lixo.length} cartas',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _lixo.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final card = _lixo[index];
                  final isTop = index == _lixo.length - 1;
                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isTop ? _vipPurpleHi : const Color(0x557B592A),
                            width: isTop ? 1.7 : 1,
                          ),
                        ),
                        child: _card(card, width: 67, height: 101),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isTop ? 'TOPO' : '${index + 1}',
                        style: TextStyle(
                          color: isTop ? _vipPurpleHi : Colors.white38,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Text(
              'Visualização do lixo na modalidade ABERTO. A ligação da compra fica com o Claude.',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  void _openTestMenu() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF110D12),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.science_outlined, color: _vipGold),
                  title: Text(
                    'Controles do piloto visual',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('Serão substituídos pelos estados reais do Claude.'),
                ),
                SwitchListTile(
                  value: _minhaVez,
                  activeThumbColor: _vipPurpleHi,
                  title: const Text('Simular minha vez'),
                  subtitle: const Text('A mão sobe sem mudar a escala.'),
                  onChanged: (value) => update(() => _minhaVez = value),
                ),
                SwitchListTile(
                  value: _vulneravelEles,
                  activeThumbColor: _vipPurpleHi,
                  title: const Text('Adversários vulneráveis'),
                  onChanged: (value) => update(() => _vulneravelEles = value),
                ),
                SwitchListTile(
                  value: _vulneravelNos,
                  activeThumbColor: _vipPurpleHi,
                  title: const Text('Minha dupla vulnerável'),
                  onChanged: (value) => update(() => _vulneravelNos = value),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VipCard {
  final String suit;
  final String value;

  const _VipCard(this.suit, this.value);

  bool get red => suit == 'copas' || suit == 'ouros';

  String get symbol {
    switch (suit) {
      case 'copas':
        return '♥';
      case 'ouros':
        return '♦';
      case 'paus':
        return '♣';
      default:
        return '♠';
    }
  }
}
