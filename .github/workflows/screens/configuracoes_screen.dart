import 'package:flutter/material.dart';

enum MaoJogador { destro, canhoto }

class ConfigVM {
  final String nome;
  final String email;
  final String avatar;
  final bool ehVip;
  final String? vipInfo;
  final bool musica;
  final bool efeitos;
  final bool vibracao;
  final bool notificacoes;
  final bool animacoes;
  final bool ordenarCartas;
  final bool mostrarOnline;
  final MaoJogador mao;
  final String versao;
  final String quemConvida;

  const ConfigVM({
    required this.nome,
    required this.email,
    required this.avatar,
    required this.ehVip,
    required this.vipInfo,
    required this.musica,
    required this.efeitos,
    required this.vibracao,
    required this.notificacoes,
    required this.animacoes,
    required this.ordenarCartas,
    required this.mostrarOnline,
    required this.mao,
    required this.versao,
    required this.quemConvida,
  });

  factory ConfigVM.mock({bool ehVip = true}) {
    return ConfigVM(
      nome: 'Sônia Rainha',
      email: 'sonia.ambrosio@gmail.com',
      avatar: '👑',
      ehVip: ehVip,
      vipInfo: ehVip ? 'Renova em 24/08 · Mensal' : null,
      musica: true,
      efeitos: true,
      vibracao: false,
      notificacoes: true,
      animacoes: true,
      ordenarCartas: true,
      mostrarOnline: true,
      mao: MaoJogador.destro,
      versao: '2.0.0',
      quemConvida: 'Amigos',
    );
  }

  ConfigVM copyWith({
    String? nome,
    String? email,
    String? avatar,
    bool? ehVip,
    String? vipInfo,
    bool limparVipInfo = false,
    bool? musica,
    bool? efeitos,
    bool? vibracao,
    bool? notificacoes,
    bool? animacoes,
    bool? ordenarCartas,
    bool? mostrarOnline,
    MaoJogador? mao,
    String? versao,
    String? quemConvida,
  }) {
    return ConfigVM(
      nome: nome ?? this.nome,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      ehVip: ehVip ?? this.ehVip,
      vipInfo: limparVipInfo ? null : (vipInfo ?? this.vipInfo),
      musica: musica ?? this.musica,
      efeitos: efeitos ?? this.efeitos,
      vibracao: vibracao ?? this.vibracao,
      notificacoes: notificacoes ?? this.notificacoes,
      animacoes: animacoes ?? this.animacoes,
      ordenarCartas: ordenarCartas ?? this.ordenarCartas,
      mostrarOnline: mostrarOnline ?? this.mostrarOnline,
      mao: mao ?? this.mao,
      versao: versao ?? this.versao,
      quemConvida: quemConvida ?? this.quemConvida,
    );
  }
}

class ConfiguracoesScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x5530B67A);
  static const _divider = Color(0x221EAE79);
  static const _text = Color(0xFFF1E8D8);
  static const _muted = Color(0xFFAA9870);

  final ConfigVM vm;
  final VoidCallback onVoltar;
  final VoidCallback onEditarPerfil;
  final VoidCallback onAssinaturaVip;
  final VoidCallback onMoedasCompras;
  final void Function(String id, bool valor) onToggle;
  final ValueChanged<MaoJogador> onMao;
  final VoidCallback onQuemConvida;
  final VoidCallback onBloqueados;
  final VoidCallback onComoJogar;
  final VoidCallback onSuporte;
  final VoidCallback onAvaliar;
  final VoidCallback onSair;

  const ConfiguracoesScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onEditarPerfil,
    required this.onAssinaturaVip,
    required this.onMoedasCompras,
    required this.onToggle,
    required this.onMao,
    required this.onQuemConvida,
    required this.onBloqueados,
    required this.onComoJogar,
    required this.onSuporte,
    required this.onAvaliar,
    required this.onSair,
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
              final horizontal = compact ? 12.0 : 14.0;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(onVoltar: onVoltar, compact: compact),
                        SizedBox(height: compact ? 14 : 18),
                        _ProfileHeader(vm: vm, compact: compact),
                        SizedBox(height: compact ? 16 : 18),
                        _SectionTitle('CONTA', compact: compact),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          children: [
                            _NavRow(
                              icon: '✏️',
                              label: 'Editar perfil',
                              onTap: onEditarPerfil,
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '💎',
                              label: vm.ehVip ? 'Assinatura VIP' : 'Assine o VIP',
                              subtitle: vm.ehVip ? vm.vipInfo : 'Conheça os benefícios VIP',
                              onTap: onAssinaturaVip,
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '🪙',
                              label: 'Moedas e compras',
                              onTap: onMoedasCompras,
                              compact: compact,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 18),
                        _SectionTitle('SOM E NOTIFICAÇÕES', compact: compact),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          children: [
                            _ToggleRow(
                              icon: '🎵',
                              label: 'Música',
                              value: vm.musica,
                              onChanged: (value) => onToggle('musica', value),
                              compact: compact,
                            ),
                            _ToggleRow(
                              icon: '🔊',
                              label: 'Efeitos sonoros',
                              value: vm.efeitos,
                              onChanged: (value) => onToggle('efeitos', value),
                              compact: compact,
                            ),
                            _ToggleRow(
                              icon: '📳',
                              label: 'Vibração',
                              value: vm.vibracao,
                              onChanged: (value) => onToggle('vibracao', value),
                              compact: compact,
                            ),
                            _ToggleRow(
                              icon: '🔔',
                              label: 'Notificações',
                              value: vm.notificacoes,
                              onChanged: (value) => onToggle('notificacoes', value),
                              compact: compact,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 18),
                        _SectionTitle('JOGO', compact: compact),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          children: [
                            _ToggleRow(
                              icon: '✨',
                              label: 'Animações',
                              value: vm.animacoes,
                              onChanged: (value) => onToggle('animacoes', value),
                              compact: compact,
                            ),
                            _ToggleRow(
                              icon: '🔢',
                              label: 'Ordenar cartas automaticamente',
                              value: vm.ordenarCartas,
                              onChanged: (value) => onToggle('ordenarCartas', value),
                              compact: compact,
                            ),
                            _HandRow(
                              value: vm.mao,
                              onChanged: onMao,
                              compact: compact,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 18),
                        _SectionTitle('PRIVACIDADE', compact: compact),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          children: [
                            _ToggleRow(
                              icon: '🟢',
                              label: 'Mostrar quando estou online',
                              value: vm.mostrarOnline,
                              onChanged: (value) => onToggle('mostrarOnline', value),
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '✉️',
                              label: 'Quem pode me convidar',
                              subtitle: vm.quemConvida,
                              onTap: onQuemConvida,
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '🚫',
                              label: 'Jogadores bloqueados',
                              onTap: onBloqueados,
                              compact: compact,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 18),
                        _SectionTitle('GERAL', compact: compact),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          children: [
                            _NavRow(
                              icon: '📖',
                              label: 'Como jogar / Regras',
                              onTap: onComoJogar,
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '💬',
                              label: 'Suporte',
                              onTap: onSuporte,
                              compact: compact,
                            ),
                            _NavRow(
                              icon: '⭐',
                              label: 'Avaliar o app',
                              onTap: onAvaliar,
                              compact: compact,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 18 : 20),
                        _LogoutButton(onTap: onSair, compact: compact),
                        const SizedBox(height: 14),
                        Text(
                          'Buraco Master VIP · versão ${vm.versao}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted.withValues(alpha: .55),
                            fontSize: compact ? 10.5 : 11.5,
                          ),
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
                  color: ConfiguracoesScreen._gold,
                  fontSize: compact ? 29 : 31,
                  height: .8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        Text(
          'Configurações',
          style: TextStyle(
            color: ConfiguracoesScreen._goldHi,
            fontSize: compact ? 19 : 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ConfigVM vm;
  final bool compact;

  const _ProfileHeader({required this.vm, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: compact ? 98 : 108,
      padding: EdgeInsets.all(compact ? 13 : 15),
      decoration: BoxDecoration(
        color: ConfiguracoesScreen._card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ConfiguracoesScreen._border),
      ),
      child: Row(
        children: [
          _AvatarView(avatar: vm.avatar, compact: compact),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vm.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ConfiguracoesScreen._goldHi,
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vm.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ConfiguracoesScreen._muted,
                    fontSize: compact ? 11.5 : 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (vm.ehVip) ...[
            const SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE9A4), Color(0xFFE9AE31)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55EFB94A),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                'VIP 💎',
                style: TextStyle(
                  color: const Color(0xFF2B1A08),
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  final String avatar;
  final bool compact;

  const _AvatarView({required this.avatar, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 66.0 : 72.0;
    Widget child;
    if (avatar.startsWith('assets/')) {
      child = Image.asset(avatar, fit: BoxFit.cover);
    } else if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      child = Image.network(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('👑', style: TextStyle(fontSize: 33)),
        ),
      );
    } else {
      child = Center(
        child: Text(
          avatar.isEmpty ? '👑' : avatar,
          style: TextStyle(fontSize: compact ? 34 : 38),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFE49B), Color(0xFFE9A91E)],
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFF291B0D),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool compact;

  const _SectionTitle(this.text, {required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Text(
        text,
        style: TextStyle(
          color: ConfiguracoesScreen._gold,
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        separated.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: ConfiguracoesScreen._divider,
          ),
        );
      }
      separated.add(children[index]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: ConfiguracoesScreen._card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ConfiguracoesScreen._border),
        ),
        child: Column(children: separated),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool compact;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 58 : 64),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 13 : 15,
              vertical: subtitle == null ? 10 : 8,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 32 : 36,
                  child: Text(
                    icon,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: compact ? 21 : 23),
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ConfiguracoesScreen._text,
                          fontSize: compact ? 14.5 : 16,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ConfiguracoesScreen._muted,
                            fontSize: compact ? 10.5 : 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '›',
                  style: TextStyle(
                    color: ConfiguracoesScreen._muted.withValues(alpha: .8),
                    fontSize: compact ? 24 : 26,
                    height: 1,
                    fontWeight: FontWeight.w300,
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

class _ToggleRow extends StatelessWidget {
  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 58 : 64),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 15),
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 32 : 36,
                  child: Text(
                    icon,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: compact ? 21 : 23),
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ConfiguracoesScreen._text,
                      fontSize: compact ? 14.5 : 16,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _GoldSwitch(
                  value: value,
                  onChanged: onChanged,
                  compact: compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  const _GoldSwitch({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final width = compact ? 48.0 : 52.0;
    final height = compact ? 28.0 : 30.0;
    final knob = height - 6;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE7A91D) : const Color(0xFF4B443A),
          borderRadius: BorderRadius.circular(999),
          boxShadow: value
              ? const [
                  BoxShadow(
                    color: Color(0x33EFB94A),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  final MaoJogador value;
  final ValueChanged<MaoJogador> onChanged;
  final bool compact;

  const _HandRow({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 58 : 64),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 15),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 32 : 36,
              child: Text(
                '🖐️',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: compact ? 21 : 23),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                'Mão',
                style: TextStyle(
                  color: ConfiguracoesScreen._text,
                  fontSize: compact ? 14.5 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _HandSegmented(
              value: value,
              onChanged: onChanged,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _HandSegmented extends StatelessWidget {
  final MaoJogador value;
  final ValueChanged<MaoJogador> onChanged;
  final bool compact;

  const _HandSegmented({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF100A06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentOption(
            label: 'Destro',
            selected: value == MaoJogador.destro,
            onTap: () => onChanged(MaoJogador.destro),
            compact: compact,
          ),
          _SegmentOption(
            label: 'Canhoto',
            selected: value == MaoJogador.canhoto,
            onTap: () => onChanged(MaoJogador.canhoto),
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: selected ? ConfiguracoesScreen._gold : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF2A1A08)
                  : ConfiguracoesScreen._muted,
              fontSize: compact ? 11 : 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _LogoutButton({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sair da conta',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: compact ? 50 : 54,
          decoration: BoxDecoration(
            color: const Color(0xFF451717),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF9A332E)),
          ),
          child: Center(
            child: Text(
              'Sair da conta',
              style: TextStyle(
                color: const Color(0xFFE77B70),
                fontSize: compact ? 17 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
