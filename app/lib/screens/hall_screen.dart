import 'package:flutter/material.dart';

enum HallCategoria {
  campeaoHoje,
  melhorDupla,
  maiorSequencia,
  reiRainhaSemana,
  lendaMes,
}

class EstatHall {
  final String valor;
  const EstatHall(this.valor);
}

class HonradoHall {
  final HallCategoria categoria;
  final String id;
  final String nome;
  final String avatar;
  final String? avatar2;
  final List<EstatHall> stats;
  final bool vazio;

  const HonradoHall({
    required this.categoria,
    required this.id,
    required this.nome,
    required this.avatar,
    this.avatar2,
    required this.stats,
    this.vazio = false,
  });
}

class HallVM {
  final List<HonradoHall> honrados;
  const HallVM({required this.honrados});

  factory HallVM.mock() {
    return const HallVM(
      honrados: [
        HonradoHall(
          categoria: HallCategoria.campeaoHoje,
          id: 'sonia',
          nome: 'Sônia Rainha',
          avatar: '👑',
          stats: [EstatHall('342'), EstatHall('18'), EstatHall('68%')],
        ),
        HonradoHall(
          categoria: HallCategoria.melhorDupla,
          id: 'sonia-claudia',
          nome: 'Sônia & Cláudia',
          avatar: '👑',
          avatar2: '🐰',
          stats: [EstatHall('287'), EstatHall('71%'), EstatHall('94%')],
        ),
        HonradoHall(
          categoria: HallCategoria.maiorSequencia,
          id: 'beto',
          nome: 'Beto',
          avatar: '🦊',
          stats: [EstatHall('27'), EstatHall('3'), EstatHall('Hoje')],
        ),
        HonradoHall(
          categoria: HallCategoria.reiRainhaSemana,
          id: 'marina',
          nome: 'Marina',
          avatar: '🐱',
          stats: [EstatHall('156'), EstatHall('74%'), EstatHall('12')],
        ),
        HonradoHall(
          categoria: HallCategoria.lendaMes,
          id: 'ricardo',
          nome: 'Ricardo',
          avatar: '🐻',
          stats: [EstatHall('892'), EstatHall('34'), EstatHall('77%')],
        ),
      ],
    );
  }
}

/// Hall dos Imortais guiado integralmente pela arte oficial.
///
/// O fundo contém molduras, títulos, rótulos e navegação. Esta tela apenas
/// posiciona avatares, nomes, estatísticas e zonas de toque nas coordenadas
/// percentuais estabelecidas pelo `hall-preview.html`.
class HallScreen extends StatefulWidget {
  const HallScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onVerRegras,
    required this.onVerPerfil,
    required this.onPresentear,
    required this.onEnviarPresente,
    required this.onNav,
  });

  final HallVM vm;
  final VoidCallback onVoltar;
  final VoidCallback onVerRegras;
  final ValueChanged<String> onVerPerfil;
  final ValueChanged<String> onPresentear;
  final void Function(String id, String presenteId) onEnviarPresente;
  final ValueChanged<String> onNav;

  @override
  State<HallScreen> createState() => _HallScreenState();
}

class _HallScreenState extends State<HallScreen> {
  static const double _aspecto = 640 / 1137;

  HonradoHall? _categoria(HallCategoria categoria) {
    for (final item in widget.vm.honrados) {
      if (item.categoria == categoria) return item;
    }
    return null;
  }

  Future<void> _abrirRegras() async {
    widget.onVerRegras();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.82),
      builder: (context) => const _ModalRegrasHall(),
    );
  }

  Future<void> _abrirPresentes(HonradoHall? honrado) async {
    if (honrado == null || honrado.vazio) return;
    widget.onPresentear(honrado.id);
    final presente = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(.84),
      builder: (context) => _ModalPresentesHall(nome: honrado.nome),
    );
    if (presente != null && mounted) {
      widget.onEnviarPresente(honrado.id, presente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campeao = _categoria(HallCategoria.campeaoHoje);
    final dupla = _categoria(HallCategoria.melhorDupla);
    final sequencia = _categoria(HallCategoria.maiorSequencia);
    final semana = _categoria(HallCategoria.reiRainhaSemana);
    final mes = _categoria(HallCategoria.lendaMes);

    return Scaffold(
      backgroundColor: const Color(0xFF090501),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width / _aspecto;

                  return SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Avatares ficam abaixo da arte e aparecem pelos furos transparentes.
                        _avatar(campeao, width, height, 23.0, 36.2, 16.2),
                        _avatar(dupla, width, height, 18.4, 53.8, 6.6),
                        _avatar(
                          dupla,
                          width,
                          height,
                          26.7,
                          53.8,
                          6.6,
                          segundo: true,
                        ),
                        _avatar(sequencia, width, height, 71.2, 53.6, 13.2),
                        _avatar(semana, width, height, 22.0, 74.8, 13.8),
                        _avatar(mes, width, height, 70.7, 74.7, 13.8),

                        Positioned.fill(
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/hall/painel_gloria.webp',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),

                        // Nomes — percentuais copiados do HTML oficial.
                        _nome(campeao, width, height, 57.0, 35.8, 14),
                        _nome(dupla, width, height, 22.5, 57.6, 9.5),
                        _nome(sequencia, width, height, 71.2, 57.6, 10.5),
                        _nome(semana, width, height, 22.0, 78.9, 9.5),
                        _nome(mes, width, height, 70.7, 78.9, 10.5),

                        // Campeão de hoje.
                        _valor(campeao, 0, width, height, 43.0, 38.5, 16),
                        _valor(campeao, 1, width, height, 58.5, 38.5, 16),
                        _valor(campeao, 2, width, height, 74.5, 38.5, 16),

                        // Melhor dupla.
                        _valor(dupla, 0, width, height, 8.0, 61.7, 12),
                        _valor(dupla, 1, width, height, 22.5, 61.7, 12),
                        _valor(dupla, 2, width, height, 38.5, 61.7, 12),

                        // Maior sequência: o terceiro valor “Hoje” pertence à arte.
                        _valor(sequencia, 0, width, height, 56.5, 61.7, 12),
                        _valor(sequencia, 1, width, height, 71.5, 61.7, 12),

                        // Rei/Rainha da semana.
                        _valor(semana, 0, width, height, 8.0, 81.7, 12),
                        _valor(semana, 1, width, height, 22.5, 81.7, 12),
                        _valor(semana, 2, width, height, 38.5, 81.7, 12),

                        // Lenda do mês.
                        _valor(mes, 0, width, height, 56.5, 81.7, 12),
                        _valor(mes, 1, width, height, 71.5, 81.7, 12),
                        _valor(mes, 2, width, height, 85.5, 81.7, 12),

                        // Zonas de toque invisíveis, também copiadas do HTML.
                        _zona(width, height, 2.0, 1.5, 11, 6, widget.onVoltar),
                        _zona(width, height, 90.0, 1.5, 9, 6, _abrirRegras),

                        _zona(width, height, 78.0, 27.5, 18, 6.5,
                            () => _abrirPresentes(campeao)),
                        _zona(width, height, 28.0, 50.5, 14, 6,
                            () => _abrirPresentes(dupla)),
                        _zona(width, height, 82.0, 50.5, 16, 6,
                            () => _abrirPresentes(sequencia)),
                        _zona(width, height, 28.0, 71.5, 14, 6,
                            () => _abrirPresentes(semana)),
                        _zona(width, height, 82.0, 71.5, 16, 6,
                            () => _abrirPresentes(mes)),

                        _zonaPerfil(campeao, width, height, 78.0, 35.5, 18, 6.5),
                        _zonaPerfil(dupla, width, height, 28.0, 58.5, 14, 6),
                        _zonaPerfil(sequencia, width, height, 82.0, 58.5, 16, 6),
                        _zonaPerfil(semana, width, height, 28.0, 79.5, 14, 6),
                        _zonaPerfil(mes, width, height, 82.0, 79.5, 16, 6),

                        _zona(width, height, 58.0, 88.5, 34, 5, _abrirRegras),
                        _zona(width, height, 22.0, 91.5, 18, 7,
                            () => widget.onNav('ranking')),
                        _zona(width, height, 41.0, 91.5, 18, 7,
                            () => widget.onNav('estatisticas')),
                        _zona(width, height, 60.0, 91.5, 17, 7,
                            () => widget.onNav('presentes')),
                        _zona(width, height, 79.0, 91.5, 19, 7,
                            () => widget.onNav('perfil')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(
    HonradoHall? honrado,
    double width,
    double height,
    double left,
    double top,
    double sizePercent, {
    bool segundo = false,
  }) {
    final vazio = honrado == null || honrado.vazio;
    final avatar = segundo ? honrado?.avatar2 : honrado?.avatar;
    final diameter = width * sizePercent / 100;

    return Positioned(
      left: width * left / 100 - diameter / 2,
      top: height * top / 100 - diameter / 2,
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.25, -.35),
              colors: [Color(0xFF3A2606), Color(0xFF120B03)],
            ),
          ),
          child: vazio || avatar == null || avatar.isEmpty
              ? const SizedBox.shrink()
              : _AvatarConteudo(valor: avatar),
        ),
      ),
    );
  }

  Widget _nome(
    HonradoHall? honrado,
    double width,
    double height,
    double left,
    double top,
    double fontSize,
  ) {
    if (honrado == null || honrado.vazio) return const SizedBox.shrink();
    return Positioned(
      left: width * left / 100,
      top: height * top / 100,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xD1080502),
            border: Border.all(color: const Color(0x66EFB94A)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
          ),
          child: Text(
            honrado.nome,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: const Color(0xFFF6E2A6),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _valor(
    HonradoHall? honrado,
    int indice,
    double width,
    double height,
    double left,
    double top,
    double fontSize,
  ) {
    final texto = honrado == null || honrado.vazio || indice >= honrado.stats.length
        ? '—'
        : honrado.stats[indice].valor;
    return Positioned(
      left: width * left / 100,
      top: height * top / 100,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: Text(
          texto,
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFFF6E2A6),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
              Shadow(color: Color(0x55EFB94A), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zonaPerfil(
    HonradoHall? honrado,
    double width,
    double height,
    double left,
    double top,
    double w,
    double h,
  ) {
    return _zona(width, height, left, top, w, h, () {
      if (honrado != null && !honrado.vazio) {
        widget.onVerPerfil(honrado.id);
      }
    });
  }

  Widget _zona(
    double width,
    double height,
    double left,
    double top,
    double w,
    double h,
    VoidCallback onTap,
  ) {
    return Positioned(
      left: width * left / 100,
      top: height * top / 100,
      width: width * w / 100,
      height: height * h / 100,
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, splashColor: Colors.white10),
        ),
      ),
    );
  }
}

class _AvatarConteudo extends StatelessWidget {
  const _AvatarConteudo({required this.valor});
  final String valor;

  @override
  Widget build(BuildContext context) {
    if (valor.startsWith('assets/')) {
      return Image.asset(valor, fit: BoxFit.cover, filterQuality: FilterQuality.high);
    }
    if (valor.startsWith('http://') || valor.startsWith('https://')) {
      return Image.network(
        valor,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.person_rounded, color: Color(0xFFEFB94A)),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Text(valor),
      ),
    );
  }
}

class _ModalRegrasHall extends StatelessWidget {
  const _ModalRegrasHall();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF160F22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xAAB98BFF), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '📜 Regras do Hall',
                    style: TextStyle(
                      color: Color(0xFFE6D0FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFC3B0E8)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text.rich(
              TextSpan(
                style: TextStyle(color: Color(0xFFCDBFE8), fontSize: 12, height: 1.5),
                children: [
                  TextSpan(text: 'O '),
                  TextSpan(text: 'Hall dos Imortais', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' honra os melhores do Buraco, atualizado automaticamente pelos seus resultados:\n\n'),
                  TextSpan(text: '🏆 Campeão de hoje', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' — quem mais venceu nas últimas 24h.\n'),
                  TextSpan(text: '👥 Melhor dupla', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' — parceria com maior taxa de vitória e entrosamento.\n'),
                  TextSpan(text: '🔥 Maior sequência', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' — o recorde de vitórias seguidas.\n'),
                  TextSpan(text: '👑 Rei/Rainha da semana', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' — o nº 1 dos últimos 7 dias.\n'),
                  TextSpan(text: '⭐ Lenda do mês', style: TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: ' — o maior vencedor do mês.\n\nJogue, vença e conquiste seu lugar entre as lendas! ✨'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenteHall {
  final String id;
  final String emoji;
  final String nome;
  final int preco;
  const _PresenteHall(this.id, this.emoji, this.nome, this.preco);
}

class _ModalPresentesHall extends StatelessWidget {
  const _ModalPresentesHall({required this.nome});
  final String nome;

  static const presentes = [
    _PresenteHall('rosa', '🌹', 'Rosa', 50),
    _PresenteHall('bombom', '🍫', 'Bombom', 100),
    _PresenteHall('champanhe', '🥂', 'Champanhe', 200),
    _PresenteHall('diamante', '💎', 'Diamante', 500),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF160F22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xAAB98BFF), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '🎁 Enviar presente',
                    style: TextStyle(
                      color: Color(0xFFE6D0FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFC3B0E8)),
                ),
              ],
            ),
            Text(
              'Homenageie $nome com um presente 👑',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCDBFE8), fontSize: 12),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: presentes.map((presente) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(presente.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF241748), Color(0xFF1A1030)],
                      ),
                      border: Border.all(color: const Color(0x66B98BFF)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(presente.emoji, style: const TextStyle(fontSize: 38)),
                        const SizedBox(height: 5),
                        Text(
                          presente.nome,
                          style: const TextStyle(
                            color: Color(0xFFD9CFFB),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '🪙 ${presente.preco}',
                          style: const TextStyle(
                            color: Color(0xFFF6D77A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
