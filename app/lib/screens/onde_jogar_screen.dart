import 'package:flutter/material.dart';

// ============================================================================
// TELA ONDE JOGAR (seletor de mesa) — build do Claude.
// Reproduz ondejogar-appnavegavel.html: 4 cards (Pública · VIP · Privada · Treino).
// Abre pelo JOGAR do Início → onEscolher(id) → Configurar Mesa (ou Mesa, no Treino).
// ============================================================================

enum CorBadge { verde, ouro, nenhuma }

class OndeJogarVM {
  final List<OpcaoMesa> opcoes;
  final bool ehVip;
  const OndeJogarVM({required this.opcoes, this.ehVip = false});

  factory OndeJogarVM.mock({bool ehVip = false}) => OndeJogarVM(
        ehVip: ehVip,
        opcoes: const [
          OpcaoMesa(
            id: 'publica',
            icone: '🌎',
            titulo: 'Mesa Pública',
            badge: 'GRÁTIS',
            corBadge: CorBadge.verde,
            descricao:
                'Aberta a todos. As cadeiras enchem com qualquer jogador online. Porta de entrada gratuita (com anúncios).',
          ),
          OpcaoMesa(
            id: 'vip',
            icone: '💎',
            titulo: 'Mesa VIP',
            badge: 'VIP',
            corBadge: CorBadge.ouro,
            descricao:
                'O lounge premium: só assinantes VIP, clima especial e sem anúncios. Matchmaking entre VIPs.',
            nota: '🔒 Benefício de assinante',
            destaque: true,
            bloqueado: true,
          ),
          OpcaoMesa(
            id: 'privada',
            icone: '🔑',
            titulo: 'Mesa Privada',
            badge: 'VIP cria',
            corBadge: CorBadge.ouro,
            descricao:
                'Você cria com um código e convida quem quiser. Trave as cadeiras pra jogar só com a família, ou libere pra completar com gente online.',
            nota: '🔒 Só VIP cria · convidados entram com código',
          ),
          OpcaoMesa(
            id: 'treino',
            icone: '🤖',
            titulo: 'Treino',
            descricao:
                'Você e 3 robôs, offline. Perfeito pra praticar sem pressa antes de encarar a galera.',
          ),
        ],
      );
}

class OpcaoMesa {
  final String id; // 'publica' | 'vip' | 'privada' | 'treino'
  final String icone;
  final String titulo;
  final String? badge;
  final CorBadge corBadge;
  final String descricao;
  final String? nota;
  final bool destaque;
  final bool bloqueado;

  const OpcaoMesa({
    required this.id,
    required this.icone,
    required this.titulo,
    this.badge,
    this.corBadge = CorBadge.nenhuma,
    required this.descricao,
    this.nota,
    this.destaque = false,
    this.bloqueado = false,
  });
}

class OndeJogarScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);

  final OndeJogarVM vm;
  final VoidCallback onVoltar;
  final ValueChanged<String> onEscolher;

  const OndeJogarScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onEscolher,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: onVoltar,
                          icon: const Icon(Icons.chevron_left, color: _gold, size: 30),
                          splashRadius: 22,
                        ),
                        const Text('Onde jogar',
                            style: TextStyle(color: _goldHi, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Text('Escolha a mesa pra começar a partida 🃏',
                        style: TextStyle(color: _mut, fontSize: 13)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      children: vm.opcoes.map(_cardOpcao).toList(),
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

  Widget _cardOpcao(OpcaoMesa o) {
    return GestureDetector(
      onTap: () => onEscolher(o.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: o.destaque ? _gold : _borda,
            width: o.destaque ? 1.8 : 1,
          ),
          boxShadow: o.destaque
              ? [BoxShadow(color: _gold.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: -2)]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1C10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x55EFB94A)),
              ),
              alignment: Alignment.center,
              child: Text(o.icone, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(o.titulo,
                            style: const TextStyle(
                                color: _goldHi, fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                      if (o.badge != null) ...[
                        const SizedBox(width: 8),
                        _badge(o.badge!, o.corBadge),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(o.descricao,
                      style: const TextStyle(color: _texto, fontSize: 12, height: 1.3)),
                  if (o.nota != null) ...[
                    const SizedBox(height: 6),
                    Text(o.nota!,
                        style: const TextStyle(color: _mut, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text('›', style: TextStyle(color: _mut, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String txt, CorBadge cor) {
    late Color bg, fg;
    switch (cor) {
      case CorBadge.verde:
        bg = const Color(0x3327AE60);
        fg = const Color(0xFF7FE0A3);
        break;
      case CorBadge.ouro:
        bg = const Color(0x33EFB94A);
        fg = _goldHi;
        break;
      case CorBadge.nenhuma:
        bg = Colors.transparent;
        fg = _mut;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(txt, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
