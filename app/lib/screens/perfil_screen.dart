import 'package:flutter/material.dart';

enum PerfilEstado { carregando, normal, erro }

enum NavDestino { inicio, ranking, loja, perfil }

class PerfilStats {
  final int vitorias;
  final int partidas;
  final int canastras;
  final int aproveitamento;

  const PerfilStats({
    required this.vitorias,
    required this.partidas,
    required this.canastras,
    required this.aproveitamento,
  });
}

class UltimaConquista {
  final String titulo;
  final String subtitulo;
  final String imagem;
  final String raridade;

  const UltimaConquista({
    required this.titulo,
    required this.subtitulo,
    required this.imagem,
    required this.raridade,
  });
}

class Conquista {
  final String id;
  final String label;
  final String icone;
  final bool desbloqueada;

  const Conquista({
    required this.id,
    required this.label,
    required this.icone,
    required this.desbloqueada,
  });
}

class ItemVitrine {
  final String slot;
  final String nome;
  final String icone;

  const ItemVitrine({
    required this.slot,
    required this.nome,
    required this.icone,
  });
}

class Presente {
  final String id;
  final String nome;
  final String icone;
  final int quantidade;

  const Presente({
    required this.id,
    required this.nome,
    required this.icone,
    required this.quantidade,
  });
}

/// View-model visual do contrato entregue pelo Claude.
///
/// Nesta branch de UI, o factory [mock] existe somente para validar o protótipo.
/// Na integração, o Claude substitui a origem dos dados pelos models/serviços reais.
class PerfilVM {
  final bool ehMeuPerfil;
  final String nome;
  final String avatar;
  final String mascote;
  final String moldura;
  final String dorso;
  final String efeito;
  final int nivel;
  final int xpAtual;
  final int xpProximo;
  final String titulo;
  final String tituloEmoji;
  final String liga;
  final int posicaoMundial;
  final PerfilStats stats;
  final UltimaConquista? ultimaConquista;
  final int presentesCount;
  final List<Conquista> conquistas;
  final List<ItemVitrine> vitrine;
  final List<Presente> presentes;

  const PerfilVM({
    required this.ehMeuPerfil,
    required this.nome,
    required this.avatar,
    required this.mascote,
    required this.moldura,
    required this.dorso,
    required this.efeito,
    required this.nivel,
    required this.xpAtual,
    required this.xpProximo,
    required this.titulo,
    required this.tituloEmoji,
    required this.liga,
    required this.posicaoMundial,
    required this.stats,
    required this.ultimaConquista,
    required this.presentesCount,
    required this.conquistas,
    required this.vitrine,
    required this.presentes,
  });

  factory PerfilVM.mock({bool ehMeuPerfil = true}) {
    return PerfilVM(
      ehMeuPerfil: ehMeuPerfil,
      nome: 'Sônia Rainha',
      avatar: '👑',
      mascote: '🦊',
      moldura: 'assets/perfil/vitrine_moldura.webp',
      dorso: 'assets/perfil/vitrine_dorso.webp',
      efeito: 'assets/perfil/vitrine_efeito.webp',
      nivel: 24,
      xpAtual: 3240,
      xpProximo: 5000,
      titulo: 'Rainha da Canastra',
      tituloEmoji: '👑',
      liga: 'Diamante',
      posicaoMundial: 128,
      stats: const PerfilStats(
        vitorias: 342,
        partidas: 1204,
        canastras: 89,
        aproveitamento: 68,
      ),
      ultimaConquista: const UltimaConquista(
        titulo: 'Primeira Batida Real',
        subtitulo: 'Marco de Jornada · Comum Especial · desbloqueada hoje',
        imagem: 'assets/perfil/ultima_conquista.webp',
        raridade: 'Comum Especial',
      ),
      presentesCount: 12,
      conquistas: const [
        Conquista(
          id: 'primeiro_lugar',
          label: '1º lugar',
          icone: 'assets/perfil/conquista_1_lugar.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'sequencia_10',
          label: 'Sequência 10',
          icone: 'assets/perfil/conquista_sequencia_10.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'cem_canastras',
          label: '100 canastras',
          icone: 'assets/perfil/conquista_100_canastras.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'diamante',
          label: 'Chegou ao Diamante',
          icone: 'assets/perfil/conquista_diamante.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'campeao',
          label: 'Campeão',
          icone: 'assets/perfil/conquista_campeao.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'imortal',
          label: 'Imortal',
          icone: 'assets/perfil/conquista_imortal.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'lenda',
          label: 'Lenda',
          icone: 'assets/perfil/conquista_lenda.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'perfeito',
          label: 'Perfeito',
          icone: 'assets/perfil/conquista_perfeito.webp',
          desbloqueada: false,
        ),
      ],
      vitrine: const [
        ItemVitrine(
          slot: 'avatar',
          nome: 'Avatar',
          icone: 'assets/perfil/vitrine_avatar.webp',
        ),
        ItemVitrine(
          slot: 'moldura',
          nome: 'Moldura',
          icone: 'assets/perfil/vitrine_moldura.webp',
        ),
        ItemVitrine(
          slot: 'mascote',
          nome: 'Mascote',
          icone: 'assets/perfil/vitrine_mascote.webp',
        ),
        ItemVitrine(
          slot: 'dorso',
          nome: 'Dorso',
          icone: 'assets/perfil/vitrine_dorso.webp',
        ),
        ItemVitrine(
          slot: 'efeito',
          nome: 'Efeito',
          icone: 'assets/perfil/vitrine_efeito.webp',
        ),
      ],
      presentes: const [
        Presente(
          id: 'rosa',
          nome: 'Rosa',
          icone: 'assets/perfil/presente_rosa.webp',
          quantidade: 5,
        ),
        Presente(
          id: 'bombom',
          nome: 'Bombom',
          icone: 'assets/perfil/presente_bombom.webp',
          quantidade: 3,
        ),
        Presente(
          id: 'champanhe',
          nome: 'Champanhe',
          icone: 'assets/perfil/presente_champanhe.webp',
          quantidade: 2,
        ),
        Presente(
          id: 'diamante',
          nome: 'Diamante',
          icone: 'assets/perfil/presente_diamante.webp',
          quantidade: 2,
        ),
      ],
    );
  }
}

class PerfilScreen extends StatefulWidget {
  final PerfilVM vm;
  final PerfilEstado estado;
  final String? mensagemErro;
  final VoidCallback onVoltar;
  final VoidCallback onAbrirConfig;
  final VoidCallback onTrocarAvatar;
  final VoidCallback onEditarNick;
  final VoidCallback onEditarPerfil;
  final VoidCallback onAbrirPresentes;
  final VoidCallback onFecharPresentes;
  final VoidCallback onVerTodasConquistas;
  final ValueChanged<String> onVerConquista;
  final VoidCallback onVerUltimaConquista;
  final VoidCallback onTrocarVitrine;
  final VoidCallback onCompartilhar;
  final VoidCallback onRecarregar;
  final ValueChanged<NavDestino> onNavTap;

  const PerfilScreen({
    super.key,
    required this.vm,
    this.estado = PerfilEstado.normal,
    this.mensagemErro,
    required this.onVoltar,
    required this.onAbrirConfig,
    required this.onTrocarAvatar,
    required this.onEditarNick,
    required this.onEditarPerfil,
    required this.onAbrirPresentes,
    required this.onFecharPresentes,
    required this.onVerTodasConquistas,
    required this.onVerConquista,
    required this.onVerUltimaConquista,
    required this.onTrocarVitrine,
    required this.onCompartilhar,
    required this.onRecarregar,
    required this.onNavTap,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x33EFB94A);
  static const _roxoBorda = Color(0xAAB98BFF);

  PerfilVM get vm => widget.vm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Colors.black],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _conteudo()),
              _navInferior(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    switch (widget.estado) {
      case PerfilEstado.carregando:
        return _carregando();
      case PerfilEstado.erro:
        return _erro();
      case PerfilEstado.normal:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topo(),
              _hero(),
              _xp(),
              _stats(),
              if (vm.ultimaConquista != null) ...[
                _tituloSecao('ÚLTIMA CONQUISTA'),
                _ultimaConquista(vm.ultimaConquista!),
              ],
              _presentes(),
              _tituloSecao(
                'CONQUISTAS',
                acao: 'ver todas ›',
                onAcao: widget.onVerTodasConquistas,
              ),
              _conquistas(),
              _tituloSecao(
                'VITRINE EQUIPADA',
                acao: vm.ehMeuPerfil ? 'trocar ›' : null,
                onAcao: vm.ehMeuPerfil ? widget.onTrocarVitrine : null,
              ),
              _vitrine(),
              _botoes(),
            ],
          ),
        );
    }
  }

  Widget _topo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _botaoTopo(
            tooltip: 'Voltar',
            onTap: widget.onVoltar,
            child: const Icon(Icons.chevron_left_rounded, color: _ouro, size: 29),
          ),
          const SizedBox(width: 2),
          const Text(
            'Perfil',
            style: TextStyle(
              color: _ouroClaro,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const Spacer(),
          _botaoTopo(
            tooltip: 'Configurações',
            onTap: widget.onAbrirConfig,
            child: const Icon(Icons.settings_rounded, color: Color(0xFFD9C79A), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _botaoTopo({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        children: [
          SizedBox(
            width: 126,
            height: 126,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      transform: GradientRotation(3.66),
                      colors: [
                        Color(0xFF7A5A1E),
                        Color(0xFFF6E2A6),
                        Color(0xFFD5A84A),
                        Color(0xFFF6E2A6),
                        Color(0xFF8A6528),
                        Color(0xFFF6E2A6),
                        Color(0xFF7A5A1E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ouro.withValues(alpha: .33),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF120A06),
                    ),
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-.2, -.35),
                      colors: [Color(0xFF3A2606), Color(0xFF1A1206)],
                    ),
                    border: Border.all(color: _ouro.withValues(alpha: .33), width: 2),
                  ),
                  child: Center(child: _icone(vm.avatar, 44)),
                ),
                Positioned(
                  left: 0,
                  bottom: 8,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_ouroClaro, Color(0xFFD5A84A)],
                      ),
                      border: Border.all(color: const Color(0xFF3A2606), width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      '${vm.nivel}',
                      style: const TextStyle(
                        color: Color(0xFF3A2606),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const RadialGradient(
                        center: Alignment(-.2, -.3),
                        colors: [Color(0xFF4A3416), Color(0xFF231607)],
                      ),
                      border: Border.all(color: _ouro, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: _icone(vm.mascote, 22),
                  ),
                ),
                if (vm.ehMeuPerfil)
                  Positioned(
                    right: 1,
                    top: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTrocarAvatar,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_ouroClaro, Color(0xFFE0A83A)],
                            ),
                            border: Border.all(color: const Color(0xFF241812), width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                          child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF3A2606), size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  vm.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ouroClaro,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
              ),
              if (vm.ehMeuPerfil) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onEditarNick,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: .33),
                      border: Border.all(color: _borda),
                    ),
                    child: const Icon(Icons.edit_rounded, color: _ouro, size: 15),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF2A1E0C), Color(0xFF191007)]),
              border: Border.all(color: _ouro.withValues(alpha: .30)),
            ),
            child: Text(
              '${vm.tituloEmoji} ${vm.titulo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF0D99A),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Text('💎 Liga', style: TextStyle(color: Color(0xFFCFC0A0), fontSize: 12)),
              Text(
                vm.liga,
                style: const TextStyle(color: Color(0xFF9FDCFF), fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                '· #${vm.posicaoMundial} no mundo',
                style: const TextStyle(color: Color(0xFFCFC0A0), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _xp() {
    final progresso = vm.xpProximo <= 0 ? 0.0 : (vm.xpAtual / vm.xpProximo).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Nível '),
                    TextSpan(
                      text: '${vm.nivel}',
                      style: const TextStyle(color: _ouro, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${_numero(vm.xpAtual)} / ${_numero(vm.xpProximo)} XP',
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .33),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ouro.withValues(alpha: .15)),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * progresso,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_ouroClaro, Color(0xFFE0A83A)]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final dados = [
      (_numero(vm.stats.vitorias), 'Vitórias'),
      (_numero(vm.stats.partidas), 'Partidas'),
      (_numero(vm.stats.canastras), 'Canastras'),
      ('${vm.stats.aproveitamento}%', 'Aproveit.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          for (var i = 0; i < dados.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borda),
                ),
                child: Column(
                  children: [
                    Text(
                      dados[i].$1,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _ouroClaro,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dados[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(color: _textoSec, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ),
            if (i != dados.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tituloSecao(
    String titulo, {
    String? acao,
    VoidCallback? onAcao,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: _ouro,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (acao != null)
            InkWell(
              onTap: onAcao,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text(acao, style: const TextStyle(color: _textoSec, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ultimaConquista(UltimaConquista conquista) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onVerUltimaConquista,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
              ),
              border: Border.all(color: _ouro.withValues(alpha: .50), width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                _imagem(conquista.imagem, 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏅 ${conquista.titulo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ouroClaro, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conquista.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC9A86A), fontSize: 10.5, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _ouro, size: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presentes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrirPresentes,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A1748), Color(0xFF1A1030)],
              ),
              border: Border.all(color: _roxoBorda, width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                _imagem('assets/perfil/presentes_bau.webp', 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎁 Meus Presentes',
                        style: TextStyle(color: Color(0xFFE6D0FF), fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'presentes que você recebeu · ${vm.presentesCount}',
                        style: const TextStyle(color: Color(0xFFC3B0E8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFD9C2FF), size: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conquistas() {
    if (vm.conquistas.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borda),
        ),
        child: const Text(
          'Ainda sem conquistas. Sua primeira vitória já abre esse caminho. 👑',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textoSec, fontSize: 12, height: 1.35),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        itemCount: vm.conquistas.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final conquista = vm.conquistas[index];
          return Opacity(
            opacity: conquista.desbloqueada ? 1 : .72,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onVerConquista(conquista.id),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(3, 7, 3, 5),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borda),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child: _imagem(conquista.icone, 46))),
                      const SizedBox(height: 2),
                      Text(
                        '${conquista.desbloqueada ? '' : '🔒 '}${conquista.label}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textoSec, fontSize: 8.5, height: 1.05),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vitrine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var i = 0; i < vm.vitrine.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borda),
                ),
                child: Column(
                  children: [
                    _imagem(vm.vitrine[i].icone, 30),
                    const SizedBox(height: 4),
                    Text(
                      vm.vitrine[i].nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textoSec, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            if (i != vm.vitrine.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _botoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          if (vm.ehMeuPerfil) ...[
            Expanded(
              child: _botaoAcao(
                icon: Icons.edit_rounded,
                label: 'Editar perfil',
                primario: true,
                onTap: widget.onEditarPerfil,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _botaoAcao(
              icon: Icons.link_rounded,
              label: 'Compartilhar',
              primario: false,
              onTap: widget.onCompartilhar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoAcao({
    required IconData icon,
    required String label,
    required bool primario,
    required VoidCallback onTap,
  }) {
    final corConteudo = primario ? const Color(0xFF3A2606) : _ouro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: primario
                ? const LinearGradient(colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)])
                : null,
            border: primario ? null : Border.all(color: _ouro.withValues(alpha: .50), width: 1.4),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: corConteudo, size: 20),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: corConteudo,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navInferior() {
    final itens = const [
      (NavDestino.inicio, 'Início', 'assets/perfil/nav_inicio.webp'),
      (NavDestino.ranking, 'Ranking', 'assets/perfil/nav_ranking.webp'),
      (NavDestino.loja, 'Loja', 'assets/perfil/nav_loja.webp'),
      (NavDestino.perfil, 'Perfil', 'assets/perfil/nav_perfil.webp'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: _borda)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          for (final item in itens)
            Expanded(
              child: InkWell(
                onTap: () => widget.onNavTap(item.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(opacity: item.$1 == NavDestino.perfil ? 1 : .42, child: _imagem(item.$3, 24)),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$1 == NavDestino.perfil ? _ouro : Colors.white.withValues(alpha: .25),
                          fontSize: 10.5,
                          fontWeight: item.$1 == NavDestino.perfil ? FontWeight.w700 : FontWeight.w400,
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

  Future<void> _abrirPresentes() async {
    widget.onAbrirPresentes();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1236), Color(0xFF120A1E)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: _roxoBorda, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🎁 Meus Presentes',
                      style: TextStyle(color: Color(0xFFE6D0FF), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: .33),
                      ),
                      child: const Icon(Icons.close_rounded, color: Color(0xFFD9C2FF), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Presentes que você recebeu dos amigos e fãs 💜',
                style: TextStyle(color: Color(0xFFC3B0E8), fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              if (vm.presentes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('Nenhum presente recebido ainda.', style: TextStyle(color: Color(0xFFC3B0E8))),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vm.presentes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: .82,
                  ),
                  itemBuilder: (context, index) {
                    final presente = vm.presentes[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF241748), Color(0xFF1A1030)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0x66B98BFF)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: Center(child: _imagem(presente.icone, 46))),
                          const SizedBox(height: 3),
                          Text(
                            presente.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFD9CFFB), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '×${presente.quantidade}',
                            style: const TextStyle(color: Color(0xFFF6D77A), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
    widget.onFecharPresentes();
  }

  Widget _carregando() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          _topo(),
          const SizedBox(height: 26),
          _skeleton(width: 118, height: 118, circular: true),
          const SizedBox(height: 14),
          _skeleton(width: 190, height: 25),
          const SizedBox(height: 10),
          _skeleton(width: 220, height: 27),
          const SizedBox(height: 24),
          _skeleton(width: double.infinity, height: 9),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(child: _skeleton(width: double.infinity, height: 68)),
                if (i != 3) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _skeleton(width: double.infinity, height: 76),
          const SizedBox(height: 12),
          _skeleton(width: double.infinity, height: 76),
        ],
      ),
    );
  }

  Widget _skeleton({required double width, required double height, bool circular = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: .055),
        border: Border.all(color: _borda),
      ),
    );
  }

  Widget _erro() {
    return Column(
      children: [
        _topo(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: _ouro, size: 46),
                  const SizedBox(height: 14),
                  Text(
                    widget.mensagemErro ?? 'Não foi possível carregar este perfil.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _texto, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.onRecarregar,
                    style: FilledButton.styleFrom(backgroundColor: _ouro, foregroundColor: const Color(0xFF3A2606)),
                    child: const Text('Tentar de novo', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _icone(String valor, double tamanho) {
    if (valor.startsWith('assets/')) return _imagem(valor, tamanho);
    return Text(valor, style: TextStyle(fontSize: tamanho));
  }

  Widget _imagem(String asset, double tamanho) {
    return Image.asset(
      asset,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: _ouro, size: tamanho * .72),
    );
  }

  static String _numero(int valor) {
    final texto = valor.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return valor < 0 ? '-$buffer' : buffer.toString();
  }
}
