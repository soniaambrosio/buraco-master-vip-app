import 'package:flutter/material.dart';

import 'mesa_privada_social.dart';

enum TipoMesa { publica, vip, privada }
enum ModalidadeJogo { aberto, fechado, sbtl }
enum ModoJogo { dois, quatro }
enum ChatMesa { completo, soBaloes, desligado }
enum EstadoCadeira { travada, liberada }

class ApostaVM {
  final int valor;
  final List<int> opcoes;
  final int pote;

  const ApostaVM({
    required this.valor,
    required this.opcoes,
    required this.pote,
  });

  ApostaVM copyWith({int? valor, List<int>? opcoes, int? pote}) {
    return ApostaVM(
      valor: valor ?? this.valor,
      opcoes: opcoes ?? this.opcoes,
      pote: pote ?? this.pote,
    );
  }
}

class CadeiraVM {
  final String id;
  final String rotulo;
  final String subtitulo;
  final String icone;
  final EstadoCadeira estado;
  final bool podeAlternar;
  final bool ocupada;
  final bool ehVip;
  final bool passeConvidadoVip;

  const CadeiraVM({
    required this.id,
    required this.rotulo,
    required this.subtitulo,
    required this.icone,
    required this.estado,
    required this.podeAlternar,
    this.ocupada = false,
    this.ehVip = false,
    this.passeConvidadoVip = false,
  });

  CadeiraVM copyWith({
    EstadoCadeira? estado,
    bool? ocupada,
    bool? ehVip,
    bool? passeConvidadoVip,
  }) {
    return CadeiraVM(
      id: id,
      rotulo: rotulo,
      subtitulo: subtitulo,
      icone: icone,
      estado: estado ?? this.estado,
      podeAlternar: podeAlternar,
      ocupada: ocupada ?? this.ocupada,
      ehVip: ehVip ?? this.ehVip,
      passeConvidadoVip: passeConvidadoVip ?? this.passeConvidadoVip,
    );
  }
}

class ConfigMesaVM {
  final TipoMesa tipo;
  final bool ehVip;
  final ModalidadeJogo modalidade;
  final ModoJogo modo;
  final int pontos;
  final List<int> pontosOpcoes;
  final int tempo;
  final List<int> tempoOpcoes;
  final ChatMesa chat;
  final ApostaVM? aposta;
  final bool? espectadores;
  final String? codigo;
  final List<CadeiraVM>? cadeiras;
  final int custoCriar;

  const ConfigMesaVM({
    required this.tipo,
    required this.ehVip,
    required this.modalidade,
    required this.modo,
    required this.pontos,
    required this.pontosOpcoes,
    required this.tempo,
    required this.tempoOpcoes,
    required this.chat,
    required this.aposta,
    required this.espectadores,
    required this.codigo,
    required this.cadeiras,
    required this.custoCriar,
  });

  factory ConfigMesaVM.mock({
    TipoMesa tipo = TipoMesa.privada,
    bool ehVip = true,
  }) {
    const cadeiras = [
      CadeiraVM(
        id: 'dono',
        rotulo: 'Você',
        subtitulo: 'dono da mesa',
        icone: 'assets/configurar_mesa/chave.webp',
        estado: EstadoCadeira.travada,
        podeAlternar: false,
        ocupada: true,
        ehVip: true,
      ),
      CadeiraVM(
        id: 'convidado',
        rotulo: 'Cláudia',
        subtitulo: 'convidada confirmada',
        icone: '🐰',
        estado: EstadoCadeira.travada,
        podeAlternar: false,
        ocupada: true,
        ehVip: true,
      ),
      CadeiraVM(
        id: 'reservada',
        rotulo: 'Reservada',
        subtitulo: 'aguardando seu convite',
        icone: 'assets/configurar_mesa/assento_reservado.webp',
        estado: EstadoCadeira.travada,
        podeAlternar: true,
      ),
      CadeiraVM(
        id: 'aberta',
        rotulo: 'Aberta',
        subtitulo: 'completar com jogador VIP',
        icone: 'assets/configurar_mesa/globo.webp',
        estado: EstadoCadeira.liberada,
        podeAlternar: true,
      ),
    ];

    switch (tipo) {
      case TipoMesa.publica:
        return ConfigMesaVM(
          tipo: tipo,
          ehVip: ehVip,
          modalidade: ModalidadeJogo.fechado,
          modo: ModoJogo.quatro,
          pontos: 1500,
          pontosOpcoes: const [1500, 3000],
          tempo: 45,
          tempoOpcoes: const [15, 30, 45],
          chat: ChatMesa.completo,
          aposta: null,
          espectadores: null,
          codigo: null,
          cadeiras: null,
          custoCriar: 0,
        );
      case TipoMesa.vip:
        return ConfigMesaVM(
          tipo: tipo,
          ehVip: ehVip,
          modalidade: ModalidadeJogo.fechado,
          modo: ModoJogo.quatro,
          pontos: 1500,
          pontosOpcoes: const [1500, 3000],
          tempo: 45,
          tempoOpcoes: const [15, 30, 45],
          chat: ChatMesa.completo,
          aposta: const ApostaVM(
            valor: 500,
            opcoes: [0, 500, 1000, 5000],
            pote: 2000,
          ),
          espectadores: null,
          codigo: null,
          cadeiras: null,
          custoCriar: 250,
        );
      case TipoMesa.privada:
        return ConfigMesaVM(
          tipo: tipo,
          ehVip: ehVip,
          modalidade: ModalidadeJogo.fechado,
          modo: ModoJogo.quatro,
          pontos: 1500,
          pontosOpcoes: const [1500, 3000],
          tempo: 45,
          tempoOpcoes: const [15, 30, 45],
          chat: ChatMesa.completo,
          aposta: const ApostaVM(
            valor: 500,
            opcoes: [0, 500, 1000, 5000],
            pote: 2000,
          ),
          espectadores: true,
          codigo: 'BURACO-7K2M',
          cadeiras: cadeiras,
          custoCriar: 500,
        );
    }
  }

  ConfigMesaVM copyWith({
    TipoMesa? tipo,
    bool? ehVip,
    ModalidadeJogo? modalidade,
    ModoJogo? modo,
    int? pontos,
    List<int>? pontosOpcoes,
    int? tempo,
    List<int>? tempoOpcoes,
    ChatMesa? chat,
    ApostaVM? aposta,
    bool? espectadores,
    String? codigo,
    List<CadeiraVM>? cadeiras,
    int? custoCriar,
  }) {
    return ConfigMesaVM(
      tipo: tipo ?? this.tipo,
      ehVip: ehVip ?? this.ehVip,
      modalidade: modalidade ?? this.modalidade,
      modo: modo ?? this.modo,
      pontos: pontos ?? this.pontos,
      pontosOpcoes: pontosOpcoes ?? this.pontosOpcoes,
      tempo: tempo ?? this.tempo,
      tempoOpcoes: tempoOpcoes ?? this.tempoOpcoes,
      chat: chat ?? this.chat,
      aposta: aposta ?? this.aposta,
      espectadores: espectadores ?? this.espectadores,
      codigo: codigo ?? this.codigo,
      cadeiras: cadeiras ?? this.cadeiras,
      custoCriar: custoCriar ?? this.custoCriar,
    );
  }
}

class ConfigurarMesaScreen extends StatelessWidget {
  static const gold = Color(0xFFEFB94A);
  static const goldHi = Color(0xFFF6E2A6);
  static const card = Color(0xFF1C130C);
  static const border = Color(0x33EFB94A);
  static const muted = Color(0xFF9D8C68);
  static const text = Color(0xFFF3E9D7);
  static const green = Color(0xFF0D422B);
  static const greenBorder = Color(0xFF1D6B4A);
  static const purple = Color(0xFF6F43B5);

  final ConfigMesaVM vm;
  final VoidCallback onVoltar;
  final ValueChanged<TipoMesa> onTipo;
  final ValueChanged<TipoMesa> onTipoBloqueado;
  final ValueChanged<ModalidadeJogo> onModalidade;
  final VoidCallback onVerRegras;
  final ValueChanged<ModoJogo> onModo;
  final ValueChanged<int> onPontos;
  final ValueChanged<int> onAposta;
  final ValueChanged<int> onTempo;
  final ValueChanged<ChatMesa> onChat;
  final ValueChanged<bool> onEspectadores;
  final VoidCallback onCopiar;
  final ValueChanged<String> onAlternarCadeira;
  final VoidCallback onCriarMesa;
  final ValueChanged<String>? onConvidarCadeira;
  final void Function(String jogadorId, AcaoSocialPrivada acao)?
      onAcaoSocialPrivada;

  const ConfigurarMesaScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onTipo,
    required this.onTipoBloqueado,
    required this.onModalidade,
    required this.onVerRegras,
    required this.onModo,
    required this.onPontos,
    required this.onAposta,
    required this.onTempo,
    required this.onChat,
    required this.onEspectadores,
    required this.onCopiar,
    required this.onAlternarCadeira,
    required this.onCriarMesa,
    this.onConvidarCadeira,
    this.onAcaoSocialPrivada,
  });

  @override
  Widget build(BuildContext context) {
    final isVip = vm.tipo == TipoMesa.vip;
    final isPrivate = vm.tipo == TipoMesa.privada;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isVip
                ? const [Color(0xFF28172E), Color(0xFF130A12), Color(0xFF050201)]
                : isPrivate
                    ? const [
                        Color(0xFF20170E),
                        Color(0xFF100A05),
                        Color(0xFF030201),
                      ]
                    : const [
                        Color(0xFF241812),
                        Color(0xFF120A06),
                        Color(0xFF050201),
                      ],
            stops: const [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _TopBar(tipo: vm.tipo, onVoltar: onVoltar),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _IdentityHeader(tipo: vm.tipo),
                        if (isVip) ...[
                          const SizedBox(height: 10),
                          const _VipExperienceCard(),
                        ],
                        if (isPrivate) ...[
                          const SizedBox(height: 10),
                          const _PrivateExperienceCard(),
                          const SizedBox(height: 10),
                          const MesaPrivadaVipPolicyCard(),
                        ],
                        const _Gap(),
                        const _SectionTitle('MODALIDADE'),
                        _ModalidadeControl(
                          value: vm.modalidade,
                          onChanged: onModalidade,
                        ),
                        const SizedBox(height: 9),
                        _RulesCard(onTap: onVerRegras),
                        const _Gap(),
                        const _SectionTitle('MODO'),
                        _ModeControl(value: vm.modo, onChanged: onModo),
                        const _Gap(),
                        const _SectionTitle('PONTOS PARA VENCER'),
                        _NumberSegments(
                          values: vm.pontosOpcoes,
                          selected: vm.pontos,
                          labelBuilder: formatNumber,
                          onChanged: onPontos,
                        ),
                        if (vm.aposta != null) ...[
                          const _Gap(),
                          _SectionTitle(
                            isVip
                                ? 'APOSTA VIP (moedas)'
                                : 'ENTRADA (aposta em moedas)',
                          ),
                          _NumberSegments(
                            values: vm.aposta!.opcoes,
                            selected: vm.aposta!.valor,
                            labelBuilder: (value) =>
                                value == 0 ? 'Grátis' : formatNumber(value),
                            onChanged: onAposta,
                            vip: isVip,
                          ),
                          const SizedBox(height: 9),
                          _PotCard(aposta: vm.aposta!, vip: isVip),
                        ],
                        const _Gap(),
                        const _SectionTitle('TEMPO POR JOGADA'),
                        _NumberSegments(
                          values: vm.tempoOpcoes,
                          selected: vm.tempo,
                          labelBuilder: (value) => '${value}s',
                          onChanged: onTempo,
                        ),
                        const _Gap(),
                        const _SectionTitle('CHAT DA MESA'),
                        _ChatControl(
                          value: vm.chat,
                          onChanged: onChat,
                          privateMode: isPrivate,
                        ),
                        if (isPrivate) ...[
                          const SizedBox(height: 9),
                          const MesaPrivadaChatSafetyCard(),
                          const _Gap(),
                          _PrivateControls(
                            vm: vm,
                            onCopiar: onCopiar,
                            onEspectadores: onEspectadores,
                            onAlternarCadeira: onAlternarCadeira,
                            onConvidarCadeira: onConvidarCadeira,
                            onAcaoSocial: onAcaoSocialPrivada,
                          ),
                          const _Gap(),
                          _PrivateSummary(vm: vm),
                        ],
                      ],
                    ),
                  ),
                  _Footer(vm: vm, onCriarMesa: onCriarMesa),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String formatNumber(int value) {
    final text = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      out.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) out.write('.');
    }
    return out.toString();
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 14);
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          color: ConfigurarMesaScreen.goldHi,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .35,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TipoMesa tipo;
  final VoidCallback onVoltar;
  const _TopBar({required this.tipo, required this.onVoltar});

  String get title => switch (tipo) {
        TipoMesa.publica => 'Configurar Mesa Pública',
        TipoMesa.vip => 'Configurar Mesa VIP',
        TipoMesa.privada => 'Configurar Mesa Privada',
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            onPressed: onVoltar,
            icon: const Icon(Icons.chevron_left_rounded),
            color: ConfigurarMesaScreen.gold,
            iconSize: 29,
            tooltip: 'Voltar',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ConfigurarMesaScreen.goldHi,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  final TipoMesa tipo;
  const _IdentityHeader({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final data = switch (tipo) {
      TipoMesa.publica => (
          '🌎',
          'Mesa Pública',
          'GRÁTIS',
          'Aberta a todos • com anúncios',
          const Color(0xFF16472B),
          const Color(0xFF235D43),
          const [Color(0xFF10271E), Color(0xFF18120D)],
        ),
      TipoMesa.vip => (
          '💎',
          'Mesa VIP',
          'LOUNGE PREMIUM',
          'Só assinantes VIP • sem anúncios',
          const Color(0xFF54347A),
          const Color(0xFF9A72D2),
          const [Color(0xFF342047), Color(0xFF1B111D)],
        ),
      TipoMesa.privada => (
          '🔑',
          'Mesa Privada',
          'VIP',
          'Escolha parceiro e adversários • todos VIP',
          const Color(0xFF3C2A12),
          const Color(0xFF8A651A),
          const [Color(0xFF2A1C10), Color(0xFF17100B)],
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: data.$7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.$6),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: .22),
              border: Border.all(color: data.$6),
            ),
            child: Text(data.$1, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.$2,
                        style: const TextStyle(
                          color: ConfigurarMesaScreen.goldHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: data.$5,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data.$3,
                        style: const TextStyle(
                          color: ConfigurarMesaScreen.goldHi,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  data.$4,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipExperienceCard extends StatelessWidget {
  const _VipExperienceCard();
  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.workspace_premium_rounded,
      title: 'Experiência VIP',
      text: 'Aposta opcional em moedas • lounge exclusivo • sem anúncios',
      border: Color(0xFF6F43B5),
      iconColor: Color(0xFFEFB94A),
    );
  }
}

class _PrivateExperienceCard extends StatelessWidget {
  const _PrivateExperienceCard();
  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.groups_2_rounded,
      title: 'Monte sua mesa. E resolvam no baralho.',
      text:
          'Escolha seu parceiro, escolha seus adversários e controle as vagas da partida.',
      border: Color(0xFF3B6749),
      iconColor: Color(0xFF78E6A7),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color border;
  final Color iconColor;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.border,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF17150D),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.goldHi,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFB7C9B9),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalidadeControl extends StatelessWidget {
  final ModalidadeJogo value;
  final ValueChanged<ModalidadeJogo> onChanged;
  const _ModalidadeControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      ModalidadeJogo.aberto: ('Aberto', 'lixo à vista'),
      ModalidadeJogo.fechado: ('Fechado', 'aceita trinca'),
      ModalidadeJogo.sbtl: ('STBL', 'sem trinca'),
    };
    return Row(
      children: ModalidadeJogo.values.map((item) {
        final selected = item == value;
        final info = labels[item]!;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == ModalidadeJogo.sbtl ? 0 : 7),
            child: _Segment(
              selected: selected,
              minHeight: 52,
              onTap: () => onChanged(item),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(info.$1, style: _segmentStyle(selected)),
                  const SizedBox(height: 1),
                  Text(
                    info.$2,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF6C4A10)
                          : ConfigurarMesaScreen.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModeControl extends StatelessWidget {
  final ModoJogo value;
  final ValueChanged<ModoJogo> onChanged;
  const _ModeControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ModoJogo.values.map((item) {
        final selected = item == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == ModoJogo.quatro ? 0 : 8),
            child: _Segment(
              selected: selected,
              minHeight: 48,
              onTap: () => onChanged(item),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item == ModoJogo.dois ? '2 jogadores' : '4 jogadores',
                    style: _segmentStyle(selected),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item == ModoJogo.dois ? '1 × 1' : 'dupla 2 × 2',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF6C4A10)
                          : ConfigurarMesaScreen.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatControl extends StatelessWidget {
  final ChatMesa value;
  final ValueChanged<ChatMesa> onChanged;
  final bool privateMode;
  const _ChatControl({
    required this.value,
    required this.onChanged,
    required this.privateMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ChatMesa.values.map((item) {
        final selected = item == value;
        final label = switch (item) {
          ChatMesa.completo => privateMode ? 'Livre' : 'Completo',
          ChatMesa.soBaloes => 'Só balões',
          ChatMesa.desligado => 'Desligado',
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == ChatMesa.desligado ? 0 : 7),
            child: _Segment(
              selected: selected,
              onTap: () => onChanged(item),
              child: Text(label, style: _segmentStyle(selected)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NumberSegments extends StatelessWidget {
  final List<int> values;
  final int selected;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;
  final bool vip;
  const _NumberSegments({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.vip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: _Segment(
              selected: selected == values[i],
              vip: vip,
              onTap: () => onChanged(values[i]),
              child: Text(
                labelBuilder(values[i]),
                style: _segmentStyle(selected == values[i]),
              ),
            ),
          ),
          if (i < values.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double minHeight;
  final bool vip;
  const _Segment({
    required this.selected,
    required this.onTap,
    required this.child,
    this.minHeight = 40,
    this.vip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? (vip ? const Color(0xFFD7A9FF) : const Color(0xFFFFD66A))
                  : ConfigurarMesaScreen.border,
            ),
            gradient: selected
                ? LinearGradient(
                    colors: vip
                        ? const [Color(0xFFF1D8FF), Color(0xFFA66CD0)]
                        : const [Color(0xFFFFE9A2), Color(0xFFEFB43D)],
                  )
                : null,
            color: selected ? null : ConfigurarMesaScreen.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

TextStyle _segmentStyle(bool selected) => TextStyle(
      color: selected
          ? const Color(0xFF3C260A)
          : ConfigurarMesaScreen.goldHi.withValues(alpha: .78),
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );

class _RulesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _RulesCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: ConfigurarMesaScreen.green,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ConfigurarMesaScreen.greenBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Color(0xFF83F2B7), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ver regras das modalidades',
                  style: TextStyle(
                    color: Color(0xFF83F2B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF83F2B7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PotCard extends StatelessWidget {
  final ApostaVM aposta;
  final bool vip;
  const _PotCard({required this.aposta, required this.vip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: vip ? const Color(0xFF2D1B3A) : const Color(0xFF21160B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: vip ? ConfigurarMesaScreen.purple : const Color(0xFF6B4A0C),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded,
              color: ConfigurarMesaScreen.gold, size: 25),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vip ? 'Pote VIP em jogo' : 'Pote em jogo',
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.goldHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${ConfigurarMesaScreen.formatNumber(aposta.pote)} moedas',
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'aposta × jogadores',
            style: TextStyle(
              color: ConfigurarMesaScreen.muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateControls extends StatelessWidget {
  final ConfigMesaVM vm;
  final VoidCallback onCopiar;
  final ValueChanged<bool> onEspectadores;
  final ValueChanged<String> onAlternarCadeira;
  final ValueChanged<String>? onConvidarCadeira;
  final void Function(String jogadorId, AcaoSocialPrivada acao)? onAcaoSocial;

  const _PrivateControls({
    required this.vm,
    required this.onCopiar,
    required this.onEspectadores,
    required this.onAlternarCadeira,
    this.onConvidarCadeira,
    this.onAcaoSocial,
  });

  @override
  Widget build(BuildContext context) {
    final all = vm.cadeiras ?? const <CadeiraVM>[];
    final count = vm.modo == ModoJogo.dois ? 2 : 4;
    final chairs = all.take(count).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PrivateGroupTitle(
          icon: Icons.groups_2_rounded,
          title: 'MONTE SUA PARTIDA',
          subtitle:
              'Defina parceiro e adversários. Vagas liberadas só podem ser ocupadas por VIP ou Passe Convidado válido.',
        ),
        const SizedBox(height: 8),
        ...chairs.asMap().entries.map((entry) {
          final role = MesaPrivadaPolicy.papelDaCadeira(
            quantidadeJogadores: count,
            indice: entry.key,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChairCard(
              cadeira: entry.value,
              papel: role,
              onAlternar: () => onAlternarCadeira(entry.value.id),
              onConvidar: () => _convidar(context, entry.value, role),
              onAcaoSocial: onAcaoSocial,
            ),
          );
        }),
        const _ChairHintCard(),
        const SizedBox(height: 14),
        const _PrivateGroupTitle(
          icon: Icons.key_rounded,
          title: 'ACESSO À SALA',
          subtitle:
              'O código localiza a mesa. Para sentar, o servidor valida VIP ou Passe Convidado.',
        ),
        const SizedBox(height: 8),
        if (vm.codigo != null) _PrivateCodeCard(code: vm.codigo!, onCopiar: onCopiar),
        const SizedBox(height: 14),
        const _PrivateGroupTitle(
          icon: Icons.visibility_outlined,
          title: 'ESPECTADORES',
          subtitle:
              'Assistir pode ser liberado sem VIP; ocupar uma cadeira continua sendo benefício VIP.',
        ),
        const SizedBox(height: 8),
        _BoolChoice(value: vm.espectadores ?? false, onChanged: onEspectadores),
      ],
    );
  }

  void _convidar(
    BuildContext context,
    CadeiraVM cadeira,
    PapelCadeiraPrivada papel,
  ) {
    if (onConvidarCadeira != null) {
      onConvidarCadeira!(cadeira.id);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Convidar ${MesaPrivadaPolicy.papelLabel(papel).toLowerCase()} — integração fica com o Claude',
          ),
          duration: const Duration(milliseconds: 1300),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }
}

class _PrivateGroupTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PrivateGroupTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF173323),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF2D6C49)),
          ),
          child: Icon(icon, color: const Color(0xFF78E6A7), size: 17),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ConfigurarMesaScreen.goldHi,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ConfigurarMesaScreen.muted,
                  fontSize: 9.6,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChairCard extends StatelessWidget {
  final CadeiraVM cadeira;
  final PapelCadeiraPrivada papel;
  final VoidCallback onAlternar;
  final VoidCallback onConvidar;
  final void Function(String jogadorId, AcaoSocialPrivada acao)? onAcaoSocial;

  const _ChairCard({
    required this.cadeira,
    required this.papel,
    required this.onAlternar,
    required this.onConvidar,
    this.onAcaoSocial,
  });

  @override
  Widget build(BuildContext context) {
    final liberated = cadeira.estado == EstadoCadeira.liberada;
    final owner = papel == PapelCadeiraPrivada.dono;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: ConfigurarMesaScreen.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: liberated ? const Color(0xFF2D6C49) : const Color(0xFF6B4A0C),
        ),
      ),
      child: Row(
        children: [
          _ChairAvatar(value: cadeira.icone, liberated: liberated),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cadeira.rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ConfigurarMesaScreen.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    MesaPrivadaChairRoleBadge(papel: papel),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  cadeira.subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.muted,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                _AccessStatus(cadeira: cadeira),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (!owner && !cadeira.ocupada)
            IconButton(
              onPressed: onConvidar,
              tooltip: 'Convidar para esta cadeira',
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF78E6A7),
                size: 20,
              ),
            ),
          if (!owner && cadeira.ocupada)
            MesaPrivadaPlayerSafetyMenuButton(
              jogadorId: cadeira.id,
              onAcao: onAcaoSocial,
            ),
          _ChairLockButton(
            cadeira: cadeira,
            onTap: cadeira.podeAlternar ? onAlternar : null,
          ),
        ],
      ),
    );
  }
}

class _AccessStatus extends StatelessWidget {
  final CadeiraVM cadeira;
  const _AccessStatus({required this.cadeira});
  @override
  Widget build(BuildContext context) {
    if (!cadeira.ocupada) {
      return const Text(
        'Aguardando jogador',
        style: TextStyle(color: Color(0xFF9EAD9F), fontSize: 8.7),
      );
    }
    final label = cadeira.passeConvidadoVip
        ? '🎟 Passe Convidado VIP'
        : cadeira.ehVip
            ? '♛ VIP ativo'
            : '⚠ acesso pendente';
    return Text(
      label,
      style: TextStyle(
        color: cadeira.ehVip || cadeira.passeConvidadoVip
            ? const Color(0xFF78E6A7)
            : const Color(0xFFE7B7A6),
        fontSize: 8.7,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChairLockButton extends StatelessWidget {
  final CadeiraVM cadeira;
  final VoidCallback? onTap;
  const _ChairLockButton({required this.cadeira, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final open = cadeira.estado == EstadoCadeira.liberada;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: open ? const Color(0xFF0B4A31) : const Color(0xFF503606),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: open ? const Color(0xFF277A53) : const Color(0xFF70500C),
            ),
          ),
          child: Icon(
            open ? Icons.public_rounded : Icons.lock_rounded,
            size: 15,
            color: open ? const Color(0xFF5DE5AF) : ConfigurarMesaScreen.gold,
          ),
        ),
      ),
    );
  }
}

class _ChairAvatar extends StatelessWidget {
  final String value;
  final bool liberated;
  const _ChairAvatar({required this.value, required this.liberated});
  @override
  Widget build(BuildContext context) {
    final asset = value.startsWith('assets/');
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: liberated ? const Color(0xFF10291E) : const Color(0xFF2A1D0E),
        border: Border.all(
          color: liberated ? const Color(0xFF2D6C49) : const Color(0xFF8B6517),
        ),
      ),
      child: asset
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                value,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.event_seat_rounded,
                  color: ConfigurarMesaScreen.gold,
                ),
              ),
            )
          : Text(value, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _ChairHintCard extends StatelessWidget {
  const _ChairHintCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF11100B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF273A2E)),
      ),
      child: const Text(
        '🔒 Travada: reservada para seu convidado.  🌐 Liberada: o sistema pode completar com outro jogador VIP. Passe Convidado é cortesia ocasional e sempre validada.',
        style: TextStyle(
          color: Color(0xFF9EAD9F),
          fontSize: 9.1,
          height: 1.3,
        ),
      ),
    );
  }
}

class _PrivateCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopiar;
  const _PrivateCodeCard({required this.code, required this.onCopiar});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF21170C), Color(0xFF15100A)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF7C5B17)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Compartilhe o código com a sua turma',
            style: TextStyle(
              color: ConfigurarMesaScreen.muted,
              fontSize: 9.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen.goldHi,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onCopiar,
                style: FilledButton.styleFrom(
                  backgroundColor: ConfigurarMesaScreen.gold,
                  foregroundColor: const Color(0xFF3D280A),
                ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copiar'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Código não libera cadeira sozinho: VIP ativo ou Passe Convidado VIP válido é obrigatório para jogar.',
            style: TextStyle(
              color: Color(0xFF9EAD9F),
              fontSize: 8.7,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoolChoice extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BoolChoice({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segment(
            selected: value,
            onTap: () => onChanged(true),
            child: Text('Permitir', style: _segmentStyle(value)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Segment(
            selected: !value,
            onTap: () => onChanged(false),
            child: Text('Não permitir', style: _segmentStyle(!value)),
          ),
        ),
      ],
    );
  }
}

class _PrivateSummary extends StatelessWidget {
  final ConfigMesaVM vm;
  const _PrivateSummary({required this.vm});

  @override
  Widget build(BuildContext context) {
    final mode = vm.modo == ModoJogo.dois ? '2 jogadores' : '4 jogadores';
    final modalidade = switch (vm.modalidade) {
      ModalidadeJogo.aberto => 'Aberto',
      ModalidadeJogo.fechado => 'Fechado',
      ModalidadeJogo.sbtl => 'STBL',
    };
    final chat = switch (vm.chat) {
      ChatMesa.completo => 'Chat livre',
      ChatMesa.soBaloes => 'Só balões',
      ChatMesa.desligado => 'Chat desligado',
    };
    final bet = vm.aposta == null || vm.aposta!.valor == 0
        ? 'sem aposta'
        : '${ConfigurarMesaScreen.formatNumber(vm.aposta!.valor)} moedas';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF141008),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF5F481A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo da mesa',
            style: TextStyle(
              color: ConfigurarMesaScreen.goldHi,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SummaryChip('$modalidade • $mode'),
              _SummaryChip('${ConfigurarMesaScreen.formatNumber(vm.pontos)} pontos'),
              _SummaryChip(bet),
              _SummaryChip('${vm.tempo}s por jogada'),
              _SummaryChip(chat),
              _SummaryChip(vm.espectadores == true
                  ? 'espectadores permitidos'
                  : 'sem espectadores'),
              const _SummaryChip('jogadores VIP • Passe Convidado válido'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  const _SummaryChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF21180B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A3715)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD8C9A9),
          fontSize: 9.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ConfigMesaVM vm;
  final VoidCallback onCriarMesa;
  const _Footer({required this.vm, required this.onCriarMesa});

  @override
  Widget build(BuildContext context) {
    final public = vm.tipo == TipoMesa.publica;
    final vip = vm.tipo == TipoMesa.vip;
    final label = switch (vm.tipo) {
      TipoMesa.publica => 'CRIAR MESA PÚBLICA',
      TipoMesa.vip => 'CRIAR MESA VIP',
      TipoMesa.privada => 'CRIAR MESA PRIVADA',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0502),
        border: Border(top: BorderSide(color: Color(0xFF6B4A0C))),
      ),
      child: Row(
        children: [
          if (!public) ...[
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Custo criar',
                    style: TextStyle(
                      color: ConfigurarMesaScreen.goldHi,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '${ConfigurarMesaScreen.formatNumber(vm.custoCriar)} moedas',
                    style: const TextStyle(
                      color: ConfigurarMesaScreen.goldHi,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: onCriarMesa,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      vip ? const Color(0xFF9A6BC3) : ConfigurarMesaScreen.gold,
                  foregroundColor:
                      vip ? const Color(0xFF1A0F20) : const Color(0xFF3A2508),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
