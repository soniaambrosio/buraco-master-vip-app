import 'package:flutter/material.dart';

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

  const CadeiraVM({
    required this.id,
    required this.rotulo,
    required this.subtitulo,
    required this.icone,
    required this.estado,
    required this.podeAlternar,
  });

  CadeiraVM copyWith({EstadoCadeira? estado}) {
    return CadeiraVM(
      id: id,
      rotulo: rotulo,
      subtitulo: subtitulo,
      icone: icone,
      estado: estado ?? this.estado,
      podeAlternar: podeAlternar,
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
        rotulo: 'Você (dono)',
        subtitulo: 'criador da mesa',
        icone: 'assets/configurar_mesa/chave.webp',
        estado: EstadoCadeira.travada,
        podeAlternar: false,
      ),
      CadeiraVM(
        id: 'convidado',
        rotulo: 'Cláudia',
        subtitulo: 'entrou pelo código',
        icone: '🐰',
        estado: EstadoCadeira.travada,
        podeAlternar: false,
      ),
      CadeiraVM(
        id: 'reservada',
        rotulo: 'Reservada',
        subtitulo: 'aguardando convidado',
        icone: 'assets/configurar_mesa/assento_reservado.webp',
        estado: EstadoCadeira.travada,
        podeAlternar: true,
      ),
      CadeiraVM(
        id: 'aberta',
        rotulo: 'Aberta',
        subtitulo: 'qualquer jogador online',
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
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x33EFB94A);
  static const _muted = Color(0xFF9D8C68);
  static const _text = Color(0xFFF3E9D7);
  static const _green = Color(0xFF0D422B);
  static const _greenBorder = Color(0xFF1D6B4A);
  static const _purple = Color(0xFF6F43B5);

  final ConfigMesaVM vm;
  final VoidCallback onVoltar;

  // Mantidos no contrato para compatibilidade com o host existente. O tipo da
  // mesa é escolhido em "Onde jogar" e não volta a aparecer como seletor aqui.
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
                    ? const [Color(0xFF20170E), Color(0xFF100A05), Color(0xFF030201)]
                    : const [Color(0xFF241812), Color(0xFF120A06), Color(0xFF050201)],
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
                        _TableIdentityHeader(tipo: vm.tipo),
                        if (isVip) ...[
                          const SizedBox(height: 10),
                          const _VipExperienceCard(),
                        ],
                        if (isPrivate) ...[
                          const SizedBox(height: 10),
                          const _PrivateExperienceCard(),
                        ],
                        _gap(),
                        _sectionTitle('MODALIDADE'),
                        _ModalidadeControl(
                          selecionada: vm.modalidade,
                          onChanged: onModalidade,
                        ),
                        const SizedBox(height: 9),
                        _RulesCard(onTap: onVerRegras),
                        _gap(),
                        _sectionTitle('MODO'),
                        _ModoControl(
                          selecionado: vm.modo,
                          onChanged: onModo,
                        ),
                        _gap(),
                        _sectionTitle('PONTOS PARA VENCER'),
                        _NumberSegments(
                          values: vm.pontosOpcoes,
                          selected: vm.pontos,
                          labelBuilder: _formatNumber,
                          onChanged: onPontos,
                        ),
                        if (vm.aposta != null) ...[
                          _gap(),
                          _sectionTitle(
                            isVip ? 'APOSTA VIP (moedas)' : 'ENTRADA (aposta em moedas)',
                          ),
                          _NumberSegments(
                            values: vm.aposta!.opcoes,
                            selected: vm.aposta!.valor,
                            labelBuilder: (value) =>
                                value == 0 ? 'Grátis' : _formatNumber(value),
                            onChanged: onAposta,
                            vip: isVip,
                          ),
                          const SizedBox(height: 9),
                          _PotCard(aposta: vm.aposta!, vip: isVip),
                        ],
                        _gap(),
                        _sectionTitle('TEMPO POR JOGADA'),
                        _NumberSegments(
                          values: vm.tempoOpcoes,
                          selected: vm.tempo,
                          labelBuilder: (value) => '${value}s',
                          onChanged: onTempo,
                        ),
                        _gap(),
                        _sectionTitle('CHAT DA MESA'),
                        _ChatControl(
                          selecionado: vm.chat,
                          onChanged: onChat,
                        ),
                        if (isPrivate) ...[
                          _gap(),
                          _PrivateAccessSection(
                            vm: vm,
                            onCopiar: onCopiar,
                            onEspectadores: onEspectadores,
                            onAlternarCadeira: onAlternarCadeira,
                          ),
                          _gap(),
                          _PrivateSummaryCard(vm: vm),
                        ] else ...[
                          if (vm.espectadores != null) ...[
                            _gap(),
                            _sectionTitle('ESPECTADORES'),
                            _BoolControl(
                              value: vm.espectadores!,
                              onChanged: onEspectadores,
                            ),
                          ],
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

  static Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: _goldHi,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .35,
        ),
      ),
    );
  }

  static Widget _gap() => const SizedBox(height: 14);

  static String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }
}

class _TopBar extends StatelessWidget {
  final TipoMesa tipo;
  final VoidCallback onVoltar;

  const _TopBar({required this.tipo, required this.onVoltar});

  String get _titulo {
    switch (tipo) {
      case TipoMesa.publica:
        return 'Configurar Mesa Pública';
      case TipoMesa.vip:
        return 'Configurar Mesa VIP';
      case TipoMesa.privada:
        return 'Configurar Mesa Privada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            onPressed: onVoltar,
            icon: const Icon(Icons.chevron_left_rounded),
            color: ConfigurarMesaScreen._gold,
            iconSize: 29,
            splashRadius: 22,
            tooltip: 'Voltar',
          ),
          Expanded(
            child: Text(
              _titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ConfigurarMesaScreen._goldHi,
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

class _TableIdentityHeader extends StatelessWidget {
  final TipoMesa tipo;

  const _TableIdentityHeader({required this.tipo});

  @override
  Widget build(BuildContext context) {
    late String icon;
    late String title;
    late String badge;
    late String subtitle;
    late Color badgeBg;
    late Color badgeFg;
    late Color border;
    late List<Color> colors;

    switch (tipo) {
      case TipoMesa.publica:
        icon = '🌎';
        title = 'Mesa Pública';
        badge = 'GRÁTIS';
        subtitle = 'Aberta a todos • com anúncios';
        badgeBg = const Color(0xFF16472B);
        badgeFg = const Color(0xFF78E6A7);
        border = const Color(0xFF235D43);
        colors = const [Color(0xFF10271E), Color(0xFF18120D)];
        break;
      case TipoMesa.vip:
        icon = '💎';
        title = 'Mesa VIP';
        badge = 'LOUNGE PREMIUM';
        subtitle = 'Só assinantes VIP • sem anúncios';
        badgeBg = const Color(0xFF54347A);
        badgeFg = const Color(0xFFF4E6FF);
        border = const Color(0xFF9A72D2);
        colors = const [Color(0xFF342047), Color(0xFF1B111D)];
        break;
      case TipoMesa.privada:
        icon = '🔑';
        title = 'Mesa Privada';
        badge = 'VIP cria';
        subtitle = 'Você controla quem entra e quem assiste';
        badgeBg = const Color(0xFF3C2A12);
        badgeFg = ConfigurarMesaScreen._goldHi;
        border = const Color(0xFF8A651A);
        colors = const [Color(0xFF2A1C10), Color(0xFF17100B)];
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: tipo == TipoMesa.vip
            ? const [
                BoxShadow(
                  color: Color(0x336F43B5),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : tipo == TipoMesa.privada
                ? const [
                    BoxShadow(
                      color: Color(0x227C5B17),
                      blurRadius: 16,
                      spreadRadius: -5,
                    ),
                  ]
                : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(.22),
              border: Border.all(color: border.withOpacity(.85)),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 25)),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ConfigurarMesaScreen._goldHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeFg,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen._muted,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B3A), Color(0xFF171018)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ConfigurarMesaScreen._purple),
      ),
      child: const Row(
        children: [
          Text('♛', style: TextStyle(color: Color(0xFFEFB94A), fontSize: 22)),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Experiência VIP',
                  style: TextStyle(
                    color: Color(0xFFF6E2A6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aposta opcional em moedas • lounge exclusivo • sem anúncios',
                  style: TextStyle(
                    color: Color(0xFFC7B2D9),
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

class _PrivateExperienceCard extends StatelessWidget {
  const _PrivateExperienceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF17150D),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF3B6749)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF78E6A7), size: 22),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu espaço, suas regras',
                  style: TextStyle(
                    color: Color(0xFFF6E2A6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Convide por código e decida quais cadeiras podem completar online.',
                  style: TextStyle(
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
  final ModalidadeJogo selecionada;
  final ValueChanged<ModalidadeJogo> onChanged;

  const _ModalidadeControl({required this.selecionada, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      ModalidadeJogo.aberto: 'Aberto',
      ModalidadeJogo.fechado: 'Fechado',
      ModalidadeJogo.sbtl: 'SBTL',
    };
    const subtitles = {
      ModalidadeJogo.aberto: 'lixo à vista',
      ModalidadeJogo.fechado: 'aceita trinca',
      ModalidadeJogo.sbtl: 'sem trinca',
    };

    return Row(
      children: ModalidadeJogo.values.map((value) {
        final selected = value == selecionada;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value == ModalidadeJogo.sbtl ? 0 : 7),
            child: _SegmentButton(
              selected: selected,
              minHeight: 52,
              onTap: () => onChanged(value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(labels[value]!, style: _segmentTextStyle(selected)),
                  const SizedBox(height: 1),
                  Text(
                    subtitles[value]!,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF6C4A10)
                          : ConfigurarMesaScreen._muted,
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

class _ModoControl extends StatelessWidget {
  final ModoJogo selecionado;
  final ValueChanged<ModoJogo> onChanged;

  const _ModoControl({required this.selecionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ModoJogo.values.map((value) {
        final selected = value == selecionado;
        final label = value == ModoJogo.dois ? '2 jogadores' : '4 jogadores';
        final subtitle = value == ModoJogo.dois ? '1 × 1' : 'dupla 2 × 2';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value == ModoJogo.quatro ? 0 : 8),
            child: _SegmentButton(
              selected: selected,
              minHeight: 48,
              onTap: () => onChanged(value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: _segmentTextStyle(selected)),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF6C4A10)
                          : ConfigurarMesaScreen._muted,
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
  final ChatMesa selecionado;
  final ValueChanged<ChatMesa> onChanged;

  const _ChatControl({required this.selecionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      ChatMesa.completo: 'Completo',
      ChatMesa.soBaloes: 'Só balões',
      ChatMesa.desligado: 'Desligado',
    };

    return Row(
      children: ChatMesa.values.map((value) {
        final selected = value == selecionado;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value == ChatMesa.desligado ? 0 : 7),
            child: _SegmentButton(
              selected: selected,
              onTap: () => onChanged(value),
              child: Text(labels[value]!, style: _segmentTextStyle(selected)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BoolControl extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BoolControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentButton(
            selected: value,
            onTap: () => onChanged(true),
            child: Text('Permitir', style: _segmentTextStyle(value)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegmentButton(
            selected: !value,
            onTap: () => onChanged(false),
            child: Text('Não permitir', style: _segmentTextStyle(!value)),
          ),
        ),
      ],
    );
  }
}

class _NumberSegments extends StatelessWidget {
  final List<int> values;
  final int selected;
  final String Function(int value) labelBuilder;
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
            child: _SegmentButton(
              selected: values[i] == selected,
              vip: vip,
              onTap: () => onChanged(values[i]),
              child: Text(
                labelBuilder(values[i]),
                style: _segmentTextStyle(values[i] == selected),
              ),
            ),
          ),
          if (i < values.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double minHeight;
  final bool vip;

  const _SegmentButton({
    required this.selected,
    required this.onTap,
    required this.child,
    this.minHeight = 40,
    this.vip = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColors = vip
        ? const [Color(0xFFF1D8FF), Color(0xFFA66CD0)]
        : const [Color(0xFFFFE9A2), Color(0xFFEFB43D)];

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
                  : ConfigurarMesaScreen._border,
            ),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selectedColors,
                  )
                : null,
            color: selected ? null : ConfigurarMesaScreen._card,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: vip
                          ? const Color(0x446F43B5)
                          : const Color(0x55EFB94A),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

TextStyle _segmentTextStyle(bool selected) {
  return TextStyle(
    color: selected
        ? const Color(0xFF3C260A)
        : ConfigurarMesaScreen._goldHi.withOpacity(.78),
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );
}

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
            color: ConfigurarMesaScreen._green,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ConfigurarMesaScreen._greenBorder),
          ),
          child: const Row(
            children: [
              _AssetIcon(path: 'assets/configurar_mesa/livro_regras.webp', size: 24),
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
              Icon(Icons.chevron_right_rounded, color: Color(0xFF83F2B7), size: 20),
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

  const _PotCard({required this.aposta, this.vip = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: vip
            ? const LinearGradient(colors: [Color(0xFF2D1B3A), Color(0xFF181018)])
            : null,
        color: vip ? null : const Color(0xFF21160B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: vip ? ConfigurarMesaScreen._purple : const Color(0xFF6B4A0C),
        ),
      ),
      child: Row(
        children: [
          const _AssetIcon(path: 'assets/configurar_mesa/saco_moedas.webp', size: 25),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vip ? 'Pote VIP em jogo' : 'Pote em jogo',
                style: const TextStyle(
                  color: ConfigurarMesaScreen._goldHi,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const _AssetIcon(path: 'assets/configurar_mesa/moeda.webp', size: 17),
                  const SizedBox(width: 4),
                  Text(
                    ConfigurarMesaScreen._formatNumber(aposta.pote),
                    style: const TextStyle(
                      color: ConfigurarMesaScreen._text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            'aposta × jogadores',
            style: TextStyle(
              color: vip ? const Color(0xFFC7B2D9) : ConfigurarMesaScreen._muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateAccessSection extends StatelessWidget {
  final ConfigMesaVM vm;
  final VoidCallback onCopiar;
  final ValueChanged<bool> onEspectadores;
  final ValueChanged<String> onAlternarCadeira;

  const _PrivateAccessSection({
    required this.vm,
    required this.onCopiar,
    required this.onEspectadores,
    required this.onAlternarCadeira,
  });

  @override
  Widget build(BuildContext context) {
    final cadeiras = vm.cadeiras ?? const <CadeiraVM>[];
    final abertas = cadeiras
        .where((c) => c.estado == EstadoCadeira.liberada)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PrivateGroupTitle(
          icon: Icons.key_rounded,
          title: 'ACESSO À SALA',
          subtitle: 'O código é a porta de entrada dos seus convidados.',
        ),
        const SizedBox(height: 8),
        if (vm.codigo != null)
          _PrivateCodeCard(code: vm.codigo!, onCopiar: onCopiar),
        const SizedBox(height: 14),
        const _PrivateGroupTitle(
          icon: Icons.visibility_outlined,
          title: 'ESPECTADORES',
          subtitle: 'Você decide se outras pessoas podem assistir.',
        ),
        const SizedBox(height: 8),
        _PrivateSpectatorCard(
          value: vm.espectadores ?? false,
          onChanged: onEspectadores,
        ),
        const SizedBox(height: 14),
        _PrivateGroupTitle(
          icon: Icons.event_seat_outlined,
          title: 'CADEIRAS',
          subtitle: abertas == 0
              ? 'Todas protegidas: só convidados entram.'
              : '$abertas cadeira${abertas == 1 ? '' : 's'} liberada${abertas == 1 ? '' : 's'} para completar online.',
        ),
        const SizedBox(height: 8),
        ...cadeiras.map(
          (cadeira) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChairCard(
              cadeira: cadeira,
              onTap: () => onAlternarCadeira(cadeira.id),
            ),
          ),
        ),
        const SizedBox(height: 2),
        const _ChairHintCard(),
      ],
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
                  color: ConfigurarMesaScreen._goldHi,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ConfigurarMesaScreen._muted,
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

class _PrivateCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopiar;

  const _PrivateCodeCard({required this.code, required this.onCopiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
            'Compartilhe este código com quem vai jogar',
            style: TextStyle(
              color: ConfigurarMesaScreen._muted,
              fontSize: 9.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0905),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFA37412),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: ConfigurarMesaScreen._goldHi,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: onCopiar,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: ConfigurarMesaScreen._gold,
                    foregroundColor: const Color(0xFF3D280A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copiar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivateSpectatorCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivateSpectatorCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceCard(
            selected: value,
            icon: Icons.visibility_rounded,
            title: 'Permitir',
            subtitle: 'podem assistir',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChoiceCard(
            selected: !value,
            icon: Icons.visibility_off_rounded,
            title: 'Não permitir',
            subtitle: 'partida reservada',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF173323) : ConfigurarMesaScreen._card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF3E8B5E)
                  : ConfigurarMesaScreen._border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? const Color(0xFF78E6A7)
                    : ConfigurarMesaScreen._muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? ConfigurarMesaScreen._goldHi
                            : ConfigurarMesaScreen._text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ConfigurarMesaScreen._muted,
                        fontSize: 8.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChairCard extends StatelessWidget {
  final CadeiraVM cadeira;
  final VoidCallback onTap;

  const _ChairCard({required this.cadeira, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final liberated = cadeira.estado == EstadoCadeira.liberada;
    final fixed = !cadeira.podeAlternar;

    return Container(
      constraints: const BoxConstraints(minHeight: 65),
      padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
      decoration: BoxDecoration(
        color: ConfigurarMesaScreen._card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: liberated ? const Color(0xFF2D6C49) : const Color(0xFF6B4A0C),
        ),
      ),
      child: Row(
        children: [
          _ChairAvatar(value: cadeira.icone, liberated: liberated),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cadeira.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen._text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cadeira.subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen._muted,
                    fontSize: 9.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: fixed ? null : onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: liberated
                      ? const Color(0xFF0B4A31)
                      : fixed
                          ? const Color(0xFF2A2417)
                          : const Color(0xFF503606),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: liberated
                        ? const Color(0xFF277A53)
                        : const Color(0xFF70500C),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liberated ? Icons.public_rounded : Icons.lock_rounded,
                      size: 14,
                      color: liberated
                          ? const Color(0xFF5DE5AF)
                          : ConfigurarMesaScreen._gold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      liberated ? 'Liberada' : 'Travada',
                      style: TextStyle(
                        color: liberated
                            ? const Color(0xFF5DE5AF)
                            : ConfigurarMesaScreen._gold,
                        fontSize: 9.6,
                        fontWeight: FontWeight.w800,
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
}

class _ChairAvatar extends StatelessWidget {
  final String value;
  final bool liberated;

  const _ChairAvatar({required this.value, required this.liberated});

  @override
  Widget build(BuildContext context) {
    final isAsset = value.startsWith('assets/');
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: liberated ? const Color(0xFF10291E) : const Color(0xFF2A1D0E),
        border: Border.all(
          color: liberated ? const Color(0xFF2D6C49) : const Color(0xFF8B6517),
        ),
      ),
      alignment: Alignment.center,
      child: isAsset
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(value, fit: BoxFit.contain),
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF11100B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF273A2E)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF78E6A7)),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Travada: só quem recebeu o código ocupa a vaga.  •  Liberada: o sistema pode completar com jogador online.',
              style: TextStyle(
                color: Color(0xFF9EAD9F),
                fontSize: 9.2,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateSummaryCard extends StatelessWidget {
  final ConfigMesaVM vm;

  const _PrivateSummaryCard({required this.vm});

  String get modalidade {
    switch (vm.modalidade) {
      case ModalidadeJogo.aberto:
        return 'Aberto';
      case ModalidadeJogo.fechado:
        return 'Fechado';
      case ModalidadeJogo.sbtl:
        return 'SBTL';
    }
  }

  String get chat {
    switch (vm.chat) {
      case ChatMesa.completo:
        return 'Chat completo';
      case ChatMesa.soBaloes:
        return 'Só balões';
      case ChatMesa.desligado:
        return 'Chat desligado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final jogadores = vm.modo == ModoJogo.dois ? '2 jogadores' : '4 jogadores';
    final aposta = vm.aposta == null || vm.aposta!.valor == 0
        ? 'sem aposta'
        : '${ConfigurarMesaScreen._formatNumber(vm.aposta!.valor)} moedas';
    final espectadores = vm.espectadores == true
        ? 'espectadores permitidos'
        : 'sem espectadores';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141008),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF5F481A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 17, color: Color(0xFFEFB94A)),
              SizedBox(width: 7),
              Text(
                'Resumo da mesa',
                style: TextStyle(
                  color: Color(0xFFF6E2A6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SummaryChip(text: '$modalidade • $jogadores'),
              _SummaryChip(text: '${ConfigurarMesaScreen._formatNumber(vm.pontos)} pontos'),
              _SummaryChip(text: aposta),
              _SummaryChip(text: '${vm.tempo}s por jogada'),
              _SummaryChip(text: chat),
              _SummaryChip(text: espectadores),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String text;

  const _SummaryChip({required this.text});

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
        text,
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

  String get buttonLabel {
    switch (vm.tipo) {
      case TipoMesa.publica:
        return 'CRIAR MESA PÚBLICA';
      case TipoMesa.vip:
        return 'CRIAR MESA VIP';
      case TipoMesa.privada:
        return 'CRIAR MESA PRIVADA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final publica = vm.tipo == TipoMesa.publica;
    final vip = vm.tipo == TipoMesa.vip;
    final privada = vm.tipo == TipoMesa.privada;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0502),
        border: Border(
          top: BorderSide(
            color: vip
                ? ConfigurarMesaScreen._purple
                : privada
                    ? const Color(0xFF6B4A0C)
                    : const Color(0xFF155E43),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!publica) ...[
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Custo criar',
                    style: TextStyle(
                      color: ConfigurarMesaScreen._goldHi,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const _AssetIcon(
                        path: 'assets/configurar_mesa/moeda.webp',
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ConfigurarMesaScreen._formatNumber(vm.custoCriar),
                        style: const TextStyle(
                          color: ConfigurarMesaScreen._goldHi,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
                  backgroundColor: vip
                      ? const Color(0xFF9A6BC3)
                      : ConfigurarMesaScreen._gold,
                  foregroundColor: vip
                      ? const Color(0xFF1A0F20)
                      : const Color(0xFF3A2508),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
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

class _AssetIcon extends StatelessWidget {
  final String path;
  final double size;

  const _AssetIcon({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}
