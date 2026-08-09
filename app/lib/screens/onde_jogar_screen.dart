import 'package:flutter/material.dart';

// ============================================================================
// TELA ONDE JOGAR (seletor de mesa) — build visual.
// O jogador escolhe o ambiente aqui; a tela seguinte configura apenas o tipo
// escolhido. Treino continua abrindo diretamente a mesa.
// ============================================================================

enum CorBadge { verde, ouro, nenhuma }

class OndeJogarVM {
  final List<OpcaoMesa> opcoes;
  final bool ehVip;
  const OndeJogarVM({required this.opcoes, this.ehVip = false});

  // O mock abre como VIP para a prévia conseguir navegar por todos os ambientes.
  // Na integração real, Claude deve passar explicitamente o status da conta.
  factory OndeJogarVM.mock({bool ehVip = true}) => OndeJogarVM(
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
            // O host legado intercepta literalmente "privada" para abrir o
            // lobby online antigo. Este id mantém a prévia no fluxo novo.
            id: 'privada_config',
            icone: '🔑',
            titulo: 'Mesa Privada',
            badge: 'VIP cria',
            corBadge: CorBadge.ouro,
            descricao:
                'Você cria com um código e convida quem quiser. Trave as cadeiras pra jogar só com a família, ou libere pra completar com gente online.',
            nota: '🔒 Só VIP cria · convidados entram com código',
            bloqueado: true,
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
  final String id;
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
  final ValueChanged<String>? onBloqueado;
  final VoidCallback? onEntrarCodigo;

  const OndeJogarScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onEscolher,
    this.onBloqueado,
    this.onEntrarCodigo,
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
                        const Text(
                          'Onde jogar',
                          style: TextStyle(
                            color: _goldHi,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Text(
                      'Escolha a mesa pra começar a partida 🃏',
                      style: TextStyle(color: _mut, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      children: vm.opcoes.map((o) => _cardOpcao(context, o)).toList(),
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

  void _selecionar(BuildContext context, OpcaoMesa opcao) {
    final bloqueadaParaUsuario = opcao.bloqueado && !vm.ehVip;
    if (!bloqueadaParaUsuario) {
      onEscolher(opcao.id);
      return;
    }

    if (onBloqueado != null) {
      onBloqueado!(opcao.id);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            opcao.id == 'privada_config'
                ? 'Criar Mesa Privada é um benefício VIP. Convidados entram pelo código recebido.'
                : 'Mesa VIP é exclusiva para assinantes VIP.',
          ),
          duration: const Duration(milliseconds: 1700),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _entrarComCodigo(BuildContext context) {
    if (onEntrarCodigo != null) {
      onEntrarCodigo!();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Entrada por código pronta para ser ligada ao servidor.'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: Color(0xFF2A1B0E),
        ),
      );
  }

  Widget _cardOpcao(BuildContext context, OpcaoMesa o) {
    final bloqueadaParaUsuario = o.bloqueado && !vm.ehVip;
    final privada = o.id == 'privada_config';
    return GestureDetector(
      onTap: () => _selecionar(context, o),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: bloqueadaParaUsuario ? .78 : 1,
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
            boxShadow: o.destaque && !bloqueadaParaUsuario
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(o.icone, style: const TextStyle(fontSize: 26)),
                    if (bloqueadaParaUsuario)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0906),
                            shape: BoxShape.circle,
                            border: Border.all(color: _gold),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: _gold,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
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
                            o.titulo,
                            style: const TextStyle(
                              color: _goldHi,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (o.badge != null) ...[
                          const SizedBox(width: 8),
                          _badge(o.badge!, o.corBadge),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.descricao,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    if (o.nota != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        o.nota!,
                        style: const TextStyle(
                          color: _mut,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (privada) ...[
                      const SizedBox(height: 9),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('entrar-com-codigo'),
                            onTap: () => _entrarComCodigo(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10271E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF235D43)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.vpn_key_rounded,
                                    color: Color(0xFF78E6A7),
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TENHO UM CÓDIGO',
                                    style: TextStyle(
                                      color: Color(0xFF78E6A7),
                                      fontSize: 9.8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                bloqueadaParaUsuario
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: bloqueadaParaUsuario ? _gold : _mut,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String txt, CorBadge cor) {
    late Color bg;
    late Color fg;
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        txt,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
