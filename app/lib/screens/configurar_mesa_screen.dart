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
        podeAlternar: true,
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
          pontosOpcoes: const [1500, 2000],
          tempo: 30,
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
          pontosOpcoes: const [1500, 2000, 3000],
          tempo: 30,
          tempoOpcoes: const [15, 30, 45],
          chat: ChatMesa.completo,
          aposta: null,
          espectadores: true,
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
          pontosOpcoes: const [1500, 2000, 3000],
          tempo: 30,
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
  static const _dark = Color(0xFF120A06);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x33EFB94A);
  static const _muted = Color(0xFF9D8C68);
  static const _text = Color(0xFFF3E9D7);
  static const _green = Color(0xFF0D422B);
  static const _greenBorder = Color(0xFF1D6B4A);

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Color(0xFF050201)],
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _TopBar(onVoltar: onVoltar),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _sectionTitle('TIPO DE MESA'),
                        _TipoMesaControl(
                          vm: vm,
                          onTipo: onTipo,
                          onTipoBloqueado: onTipoBloqueado,
                        ),
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
                          _sectionTitle('ENTRADA (aposta em moedas)'),
                          _NumberSegments(
                            values: vm.aposta!.opcoes,
                            selected: vm.aposta!.valor,
                            labelBuilder: (value) =>
                                value == 0 ? 'Grátis' : _formatNumber(value),
                            onChanged: onAposta,
                          ),
                          const SizedBox(height: 9),
                          _PotCard(aposta: vm.aposta!),
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
                        if (vm.espectadores != null) ...[
                          _gap(),
                          _sectionTitle('ESPECTADORES'),
                          _BoolControl(
                            value: vm.espectadores!,
                            onChanged: onEspectadores,
                          ),
                        ],
                        if (vm.codigo != null) ...[
                          _gap(),
                          _sectionTitle('CÓDIGO DA SALA'),
                          _CodeRow(code: vm.codigo!, onCopiar: onCopiar),
                        ],
                        if (vm.cadeiras != null) ...[
                          _gap(),
                          _sectionTitle('CADEIRAS'),
                          ...vm.cadeiras!.map(
                            (cadeira) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _ChairCard(
                                cadeira: cadeira,
                                onTap: () => onAlternarCadeira(cadeira.id),
                              ),
                            ),
                          ),
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
  final VoidCallback onVoltar;

  const _TopBar({required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
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
          const Text(
            'Configurar mesa',
            style: TextStyle(
              color: ConfigurarMesaScreen._goldHi,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoMesaControl extends StatelessWidget {
  final ConfigMesaVM vm;
  final ValueChanged<TipoMesa> onTipo;
  final ValueChanged<TipoMesa> onTipoBloqueado;

  const _TipoMesaControl({
    required this.vm,
    required this.onTipo,
    required this.onTipoBloqueado,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TipoMesa.values.map((tipo) {
        final selected = vm.tipo == tipo;
        final blocked = !vm.ehVip && tipo != TipoMesa.publica;
        final label = switch (tipo) {
          TipoMesa.publica => 'Pública',
          TipoMesa.vip => 'VIP',
          TipoMesa.privada => 'Privada',
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: tipo == TipoMesa.privada ? 0 : 7,
            ),
            child: _SegmentButton(
              selected: selected,
              onTap: () => blocked ? onTipoBloqueado(tipo) : onTipo(tipo),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _segmentTextStyle(selected),
                    ),
                  ),
                  if (blocked) ...[
                    const SizedBox(width: 4),
                    const _AssetIcon(
                      path: 'assets/configurar_mesa/cadeado.webp',
                      size: 17,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModalidadeControl extends StatelessWidget {
  final ModalidadeJogo selecionada;
  final ValueChanged<ModalidadeJogo> onChanged;

  const _ModalidadeControl({
    required this.selecionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const subtitles = {
      ModalidadeJogo.aberto: 'lixo à vista',
      ModalidadeJogo.fechado: 'aceita trinca',
      ModalidadeJogo.sbtl: 'sem trinca',
    };
    const labels = {
      ModalidadeJogo.aberto: 'Aberto',
      ModalidadeJogo.fechado: 'Fechado',
      ModalidadeJogo.sbtl: 'SBTL',
    };

    return Row(
      children: ModalidadeJogo.values.map((value) {
        final selected = value == selecionada;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: value == ModalidadeJogo.sbtl ? 0 : 7,
            ),
            child: _SegmentButton(
              selected: selected,
              minHeight: 48,
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
            padding: EdgeInsets.only(
              right: value == ChatMesa.desligado ? 0 : 7,
            ),
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
            child: Text('Não', style: _segmentTextStyle(!value)),
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

  const _NumberSegments({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: _SegmentButton(
              selected: values[i] == selected,
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

  const _SegmentButton({
    required this.selected,
    required this.onTap,
    required this.child,
    this.minHeight = 35,
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
                  ? const Color(0xFFFFD66A)
                  : ConfigurarMesaScreen._border,
            ),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE9A2), Color(0xFFEFB43D)],
                  )
                : null,
            color: selected ? null : ConfigurarMesaScreen._card,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x55EFB94A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
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
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: ConfigurarMesaScreen._green,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ConfigurarMesaScreen._greenBorder),
          ),
          child: const Row(
            children: [
              _AssetIcon(
                path: 'assets/configurar_mesa/livro_regras.webp',
                size: 24,
              ),
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
              _AssetIcon(
                path: 'assets/configurar_mesa/seta.webp',
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PotCard extends StatelessWidget {
  final ApostaVM aposta;

  const _PotCard({required this.aposta});

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF21160B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6B4A0C)),
      ),
      child: Row(
        children: [
          const _AssetIcon(
            path: 'assets/configurar_mesa/saco_moedas.webp',
            size: 24,
          ),
          const SizedBox(width: 7),
          const Text(
            'Pote em jogo',
            style: TextStyle(
              color: ConfigurarMesaScreen._goldHi,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const _AssetIcon(
            path: 'assets/configurar_mesa/moeda.webp',
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            ConfigurarMesaScreen._formatNumber(aposta.pote),
            style: const TextStyle(
              color: ConfigurarMesaScreen._text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const Text(
            'aposta × jogadores',
            style: TextStyle(
              color: ConfigurarMesaScreen._muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String code;
  final VoidCallback onCopiar;

  const _CodeRow({required this.code, required this.onCopiar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: SizedBox(
              height: 46,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Text(
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
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: onCopiar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              backgroundColor: ConfigurarMesaScreen._gold,
              foregroundColor: const Color(0xFF3D280A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Copiar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(radius);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = const Color(0xFFA37412)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChairCard extends StatelessWidget {
  final CadeiraVM cadeira;
  final VoidCallback onTap;

  const _ChairCard({required this.cadeira, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final liberated = cadeira.estado == EstadoCadeira.liberada;
    return Container(
      minHeight: 63,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: ConfigurarMesaScreen._card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF176343)),
      ),
      child: Row(
        children: [
          _ChairAvatar(value: cadeira.icone),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  cadeira.subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ConfigurarMesaScreen._muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: cadeira.podeAlternar ? onTap : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 29,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: liberated
                      ? const Color(0xFF0B4A31)
                      : const Color(0xFF503606),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AssetIcon(
                      path: liberated
                          ? 'assets/configurar_mesa/globo.webp'
                          : 'assets/configurar_mesa/cadeado.webp',
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      liberated ? 'Liberada' : 'Travada',
                      style: TextStyle(
                        color: liberated
                            ? const Color(0xFF5DE5AF)
                            : ConfigurarMesaScreen._gold,
                        fontSize: 10,
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

  const _ChairAvatar({required this.value});

  @override
  Widget build(BuildContext context) {
    final isAsset = value.startsWith('assets/');
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A1D0E),
        border: Border.all(color: const Color(0xFF8B6517)),
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

class _Footer extends StatelessWidget {
  final ConfigMesaVM vm;
  final VoidCallback onCriarMesa;

  const _Footer({required this.vm, required this.onCriarMesa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0502),
        border: Border(top: BorderSide(color: Color(0xFF155E43))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
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
                const SizedBox(height: 1),
                Row(
                  children: [
                    const _AssetIcon(
                      path: 'assets/configurar_mesa/moeda.webp',
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vm.custoCriar == 0
                          ? 'Grátis'
                          : ConfigurarMesaScreen._formatNumber(vm.custoCriar),
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
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: onCriarMesa,
                style: FilledButton.styleFrom(
                  backgroundColor: ConfigurarMesaScreen._gold,
                  foregroundColor: const Color(0xFF3A2508),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Criar mesa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
