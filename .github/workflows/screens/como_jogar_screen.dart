import 'package:flutter/material.dart';

class ComoJogarScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x33EFB94A);
  static const _text = Color(0xFFEFE3CC);
  static const _muted = Color(0xFFCDBF9D);

  final VoidCallback onVoltar;
  final VoidCallback onJogarTreino;

  const ComoJogarScreen({
    super.key,
    required this.onVoltar,
    required this.onJogarTreino,
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
            colors: [
              Color(0xFF241812),
              Color(0xFF120A06),
              Color(0xFF000000),
            ],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth <= 370;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 14,
                      8,
                      compact ? 12 : 14,
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(onVoltar: onVoltar, compact: compact),
                        const SizedBox(height: 8),
                        _OwlGreeting(compact: compact),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'O objetivo',
                          icon: '🎯',
                          child: _RichBody(
                            parts: const [
                              _BodyPart('Formar '),
                              _BodyPart('jogos', bold: true),
                              _BodyPart(' (sequências ou trincas), fechar '),
                              _BodyPart('canastras', bold: true),
                              _BodyPart(' e '),
                              _BodyPart('bater', bold: true),
                              _BodyPart(' antes da dupla adversária. Ganha quem chegar primeiro na '),
                              _BodyPart('meta de pontos', bold: true),
                              _BodyPart('.'),
                            ],
                            compact: compact,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'A distribuição',
                          icon: '🃏',
                          child: _RichBody(
                            parts: const [
                              _BodyPart('Cada jogador recebe '),
                              _BodyPart('11 cartas', bold: true),
                              _BodyPart('. No centro ficam o '),
                              _BodyPart('monte', bold: true),
                              _BodyPart(' (pra comprar), o '),
                              _BodyPart('lixo', bold: true),
                              _BodyPart(' (descarte) e os '),
                              _BodyPart('2 mortos', bold: true),
                              _BodyPart(' — que você pega quando bate.'),
                            ],
                            compact: compact,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'A sua vez, em 3 passos',
                          icon: '🔄',
                          child: _Steps(compact: compact),
                        ),
                        const SizedBox(height: 16),
                        const _SectionCard(
                          title: 'Canastras',
                          icon: '👑',
                          child: _Canastras(),
                        ),
                        const SizedBox(height: 16),
                        const _SectionCard(
                          title: 'As 3 modalidades',
                          icon: '🎲',
                          child: _Modalidades(),
                        ),
                        const SizedBox(height: 16),
                        const _SectionCard(
                          title: 'Pontuação (resumo)',
                          icon: '🏆',
                          child: _ScoreTable(),
                        ),
                        const SizedBox(height: 16),
                        _TrainingButton(
                          compact: compact,
                          onTap: onJogarTreino,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onVoltar;
  final bool compact;

  const _TopBar({required this.onVoltar, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Voltar',
          child: InkResponse(
            onTap: onVoltar,
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 9, 6),
              child: Text(
                '‹',
                style: TextStyle(
                  color: ComoJogarScreen._gold,
                  fontSize: compact ? 29 : 31,
                  height: .8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        Text(
          'Como jogar',
          style: TextStyle(
            color: ComoJogarScreen._goldHi,
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OwlGreeting extends StatelessWidget {
  final bool compact;

  const _OwlGreeting({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DEFB94A)),
      ),
      child: Row(
        children: [
          Text('🦉', style: TextStyle(fontSize: compact ? 38 : 42)),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: const Color(0xFFE6D4A6),
                  fontSize: compact ? 12.5 : 13,
                  height: 1.4,
                ),
                children: const [
                  TextSpan(text: 'Oi! Eu sou o '),
                  TextSpan(
                    text: 'Professor Coruja',
                    style: TextStyle(
                      color: ComoJogarScreen._goldHi,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: '. Em 1 minutinho te ensino o Buraco — depois é só praticar no Treino! 🃏',
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

class _SectionCard extends StatelessWidget {
  final String title;
  final String icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: ComoJogarScreen._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ComoJogarScreen._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ComoJogarScreen._gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _BodyPart {
  final String text;
  final bool bold;

  const _BodyPart(this.text, {this.bold = false});
}

class _RichBody extends StatelessWidget {
  final List<_BodyPart> parts;
  final bool compact;

  const _RichBody({required this.parts, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: parts
            .map(
              (part) => TextSpan(
                text: part.text,
                style: TextStyle(
                  color: part.bold
                      ? ComoJogarScreen._text
                      : ComoJogarScreen._muted,
                  fontWeight: part.bold ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            )
            .toList(),
      ),
      style: TextStyle(
        fontSize: compact ? 12.5 : 13,
        height: 1.5,
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  final bool compact;

  const _Steps({required this.compact});

  @override
  Widget build(BuildContext context) {
    const items = [
      (number: '1', icon: '🂠', label: 'Comprar'),
      (number: '2', icon: '⬇️', label: 'Baixar jogos'),
      (number: '3', icon: '🗑️', label: 'Descartar'),
    ];

    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: _StepCard(
              number: items[index].number,
              icon: items[index].icon,
              label: items[index].label,
              compact: compact,
            ),
          ),
          if (index != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String icon;
  final String label;
  final bool compact;

  const _StepCard({
    required this.number,
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 5,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ComoJogarScreen._gold,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF3A2606),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: const Color(0xFFD9C79A),
              fontSize: compact ? 9.5 : 10.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Canastras extends StatelessWidget {
  const _Canastras();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _CanastraCard(
            title: 'LIMPA',
            description: '7 cartas, sem curinga',
            points: '+200',
            clean: true,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _CanastraCard(
            title: 'SUJA',
            description: '7 cartas, com curinga',
            points: '+100',
            clean: false,
          ),
        ),
      ],
    );
  }
}

class _CanastraCard extends StatelessWidget {
  final String title;
  final String description;
  final String points;
  final bool clean;

  const _CanastraCard({
    required this.title,
    required this.description,
    required this.points,
    required this.clean,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = clean
        ? ComoJogarScreen._goldHi
        : const Color(0xFFE0928A);
    final pointsColor = clean
        ? ComoJogarScreen._gold
        : const Color(0xFFE07A6E);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: clean
              ? const [Color(0xFF2A2410), Color(0xFF191407)]
              : const [Color(0xFF2A1410), Color(0xFF190A07)],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: clean
              ? const Color(0x55EFB94A)
              : const Color(0x889C302E),
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB6A884),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            points,
            style: TextStyle(
              color: pointsColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Modalidades extends StatelessWidget {
  const _Modalidades();

  @override
  Widget build(BuildContext context) {
    const items = [
      (name: 'Aberto', subtitle: 'lixo espalhado'),
      (name: 'Fechado', subtitle: 'aceita trinca'),
      (name: 'SBTL', subtitle: 'tradicional'),
    ];

    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    items[index].name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD9C79A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[index].subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A7C5E),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (label: 'Canastra limpa', value: '200'),
      (label: 'Canastra suja', value: '100'),
      (label: 'Bater', value: '100'),
      (label: 'Curinga / Ás', value: '20 / 15'),
      (label: 'Cartas na mão (ao bater adversário)', value: '− pontos'),
    ];

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            decoration: BoxDecoration(
              border: index == rows.length - 1
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: .05),
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[index].label,
                    style: const TextStyle(
                      color: ComoJogarScreen._muted,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rows[index].value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: ComoJogarScreen._goldHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrainingButton extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _TrainingButton({required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: compact ? 14 : 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44EFB94A),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '🤖 Jogar treino contra robôs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF3A2606),
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
