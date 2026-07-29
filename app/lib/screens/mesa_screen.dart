import 'dart:math' as math;

import 'package:flutter/material.dart';

enum Modalidade { aberto, fechado, sbtl }

enum TipoMeld { comum, limpa, suja, de500 }

class MesaVM {
  final String titulo;
  final int meta;
  final Modalidade modalidade;
  final int rodada;
  final PlacarDupla eles;
  final PlacarDupla nos;
  final List<JogadorMesa> jogadoresEles;
  final List<JogadorMesa> jogadoresNos;
  final List<Meld> meldsEles;
  final List<Meld> meldsNos;
  final PilhaMonte monte;
  final PilhaLixo lixo;
  final int mortosRestantes;
  final List<CartaVM> mao;
  final Set<String> selecionadas;
  final String? dica;
  final bool minhaVez;

  const MesaVM({
    required this.titulo,
    required this.meta,
    required this.modalidade,
    required this.rodada,
    required this.eles,
    required this.nos,
    required this.jogadoresEles,
    required this.jogadoresNos,
    required this.meldsEles,
    required this.meldsNos,
    required this.monte,
    required this.lixo,
    required this.mortosRestantes,
    required this.mao,
    required this.selecionadas,
    required this.dica,
    required this.minhaVez,
  });

  MesaVM copyWith({
    Set<String>? selecionadas,
    String? dica,
    bool removerDica = false,
    bool? minhaVez,
  }) {
    return MesaVM(
      titulo: titulo,
      meta: meta,
      modalidade: modalidade,
      rodada: rodada,
      eles: eles,
      nos: nos,
      jogadoresEles: jogadoresEles,
      jogadoresNos: jogadoresNos,
      meldsEles: meldsEles,
      meldsNos: meldsNos,
      monte: monte,
      lixo: lixo,
      mortosRestantes: mortosRestantes,
      mao: mao,
      selecionadas: selecionadas ?? this.selecionadas,
      dica: removerDica ? null : (dica ?? this.dica),
      minhaVez: minhaVez ?? this.minhaVez,
    );
  }

  factory MesaVM.mock({Set<String>? selecionadas}) {
    CartaVM c(String id, String valor, String naipe, {bool coringa = false}) {
      return CartaVM(id: id, valor: valor, naipe: naipe, coringa: coringa);
    }

    List<CartaVM> seq(String prefixo, String naipe, List<String> valores) {
      return [
        for (var i = 0; i < valores.length; i++)
          c('${prefixo}_$i', valores[i], naipe, coringa: valores[i] == '2'),
      ];
    }

    return MesaVM(
      titulo: 'BURACO MASTER VIP',
      meta: 1500,
      modalidade: Modalidade.aberto,
      rodada: 1,
      eles: const PlacarDupla(
        pontos: 610,
        vulneravel: true,
        vulneravelMinimo: 75,
      ),
      nos: const PlacarDupla(
        pontos: 1125,
        vulneravel: true,
        vulneravelMinimo: 75,
      ),
      jogadoresEles: const [
        JogadorMesa(
          nome: 'Cláudia',
          numero: 2,
          cartas: 10,
          avatar: '🙂',
          mascote: '🐺',
          ehVoce: false,
        ),
        JogadorMesa(
          nome: 'Sofia',
          numero: 3,
          cartas: 11,
          avatar: 'RN',
          mascote: '🐱',
          ehVoce: false,
        ),
      ],
      jogadoresNos: const [
        JogadorMesa(
          nome: 'Mateus',
          numero: 4,
          cartas: 13,
          avatar: '😎',
          mascote: '🦊',
          ehVoce: false,
        ),
        JogadorMesa(
          nome: 'você',
          numero: 7,
          cartas: 21,
          avatar: '👑',
          mascote: '🐶',
          ehVoce: true,
        ),
      ],
      meldsEles: [
        Meld(
          id: 'eles_paus_limpa',
          cartas: seq(
            'ep',
            'paus',
            const ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
          ),
          tipo: TipoMeld.limpa,
          contagem: 10,
        ),
        Meld(
          id: 'eles_espadas_limpa',
          cartas: seq(
            'ee',
            'espadas',
            const ['2', '3', '4', '5', '6', '7', '8'],
          ),
          tipo: TipoMeld.limpa,
          contagem: 7,
        ),
        Meld(
          id: 'eles_ouros',
          cartas: seq(
            'eo',
            'ouros',
            const ['2', '6', '7', '8', '9', '10'],
          ),
          tipo: TipoMeld.comum,
          contagem: 6,
        ),
        Meld(
          id: 'eles_paus_figuras',
          cartas: seq('ef', 'paus', const ['Q', 'K', 'A']),
          tipo: TipoMeld.comum,
          contagem: 3,
        ),
      ],
      meldsNos: [
        Meld(
          id: 'nos_espadas_500',
          cartas: seq(
            'ne',
            'espadas',
            const ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'],
          ),
          tipo: TipoMeld.de500,
          contagem: 13,
        ),
        Meld(
          id: 'nos_ouros_suja',
          cartas: seq('no', 'ouros', const ['3', '4', '5', '6', '7', '8', '9']),
          tipo: TipoMeld.suja,
          contagem: 7,
        ),
        Meld(
          id: 'nos_copas_suja',
          cartas: seq('nc', 'copas', const ['3', '4', '5', '6', '7', '8', '9', '10']),
          tipo: TipoMeld.suja,
          contagem: 8,
        ),
        Meld(
          id: 'nos_paus',
          cartas: seq('np', 'paus', const ['5', '6', '7']),
          tipo: TipoMeld.comum,
          contagem: 3,
        ),
        Meld(
          id: 'nos_ouros_figuras',
          cartas: seq('nf', 'ouros', const ['Q', 'K', 'A', '2']),
          tipo: TipoMeld.comum,
          contagem: 4,
        ),
      ],
      monte: const PilhaMonte(contagem: 10, destaque: true),
      lixo: const PilhaLixo(contagem: 0, topo: null),
      mortosRestantes: 2,
      mao: [
        c('mao_kh', 'K', 'copas'),
        c('mao_as', 'A', 'espadas'),
        c('mao_jd', 'J', 'ouros'),
        c('mao_qd', 'Q', 'ouros'),
        c('mao_kd', 'K', 'ouros'),
        c('mao_7c', '7', 'paus'),
        c('mao_3s', '3', 'espadas'),
        c('mao_6h', '6', 'copas'),
        c('mao_9c', '9', 'paus'),
        c('mao_2s', '2', 'espadas', coringa: true),
        c('mao_10h', '10', 'copas'),
      ],
      selecionadas: selecionadas ?? const {'mao_as'},
      dica: 'Lacuna na sequência maior que o número de curingas disponível',
      minhaVez: true,
    );
  }
}

class PlacarDupla {
  final int pontos;
  final bool vulneravel;
  final int vulneravelMinimo;

  const PlacarDupla({
    required this.pontos,
    required this.vulneravel,
    required this.vulneravelMinimo,
  });
}

class JogadorMesa {
  final String nome;
  final int numero;
  final int cartas;
  final String avatar;
  final String mascote;
  final bool ehVoce;

  const JogadorMesa({
    required this.nome,
    required this.numero,
    required this.cartas,
    required this.avatar,
    this.mascote = '🐾',
    required this.ehVoce,
  });
}

class Meld {
  final String id;
  final List<CartaVM> cartas;
  final TipoMeld tipo;
  final int contagem;

  const Meld({
    required this.id,
    required this.cartas,
    required this.tipo,
    required this.contagem,
  });
}

class PilhaMonte {
  final int contagem;
  final bool destaque;

  const PilhaMonte({required this.contagem, required this.destaque});
}

class PilhaLixo {
  final int contagem;
  final CartaVM? topo;

  const PilhaLixo({required this.contagem, required this.topo});
}

class CartaVM {
  final String id;
  final String valor;
  final String naipe;
  final bool coringa;

  const CartaVM({
    required this.id,
    required this.valor,
    required this.naipe,
    required this.coringa,
  });
}

class MesaScreen extends StatefulWidget {
  final MesaVM vm;
  final VoidCallback onMenu;
  final VoidCallback onChat;
  final VoidCallback onComprarMonte;
  final VoidCallback onPegarLixo;
  final ValueChanged<String> onTapCarta;
  final VoidCallback onBaixar;
  final ValueChanged<String> onEstender;
  final VoidCallback onDescartar;

  const MesaScreen({
    super.key,
    required this.vm,
    required this.onMenu,
    required this.onChat,
    required this.onComprarMonte,
    required this.onPegarLixo,
    required this.onTapCarta,
    required this.onBaixar,
    required this.onEstender,
    required this.onDescartar,
  });

  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
      lowerBound: 0.25,
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
    return Scaffold(
      backgroundColor: _MesaCores.fundo,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _Cabecalho(
                  vm: widget.vm,
                  onMenu: widget.onMenu,
                  onChat: widget.onChat,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    child: _MesaLonga(
                      vm: widget.vm,
                      pulse: _pulse,
                      onComprarMonte: widget.onComprarMonte,
                      onPegarLixo: widget.onPegarLixo,
                      onTapCarta: widget.onTapCarta,
                      onBaixar: widget.onBaixar,
                      onEstender: widget.onEstender,
                      onDescartar: widget.onDescartar,
                    ),
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

class _MesaCores {
  static const fundo = Color(0xFF17170F);
  static const dourado = Color(0xFFDCAB57);
  static const douradoClaro = Color(0xFFF1C673);
  static const trilho = Color(0xFF6F5324);
  static const painel = Color(0xFF0C3729);
  static const painelEscuro = Color(0xFF082A20);
  static const verdeClaro = Color(0xFF8FE0B0);
  static const rosaEles = Color(0xFFE7B7A6);
  static const vinho = Color(0xFF7A2F22);
  static const vermelho = Color(0xFF9C302E);
  static const creme = Color(0xFFF3F0E8);
  static const textoEscuro = Color(0xFF2B2B28);
}

class _Cabecalho extends StatelessWidget {
  final MesaVM vm;
  final VoidCallback onMenu;
  final VoidCallback onChat;

  const _Cabecalho({
    required this.vm,
    required this.onMenu,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 380;
        return Container(
          height: 96,
          padding: EdgeInsets.fromLTRB(compacto ? 10 : 14, 12, compacto ? 8 : 12, 8),
          color: const Color(0xFF0C0B07),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('♛', style: TextStyle(color: _MesaCores.douradoClaro, fontSize: 27)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          vm.titulo,
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color(0xFFF3E9D2),
                            fontSize: compacto ? 17 : 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: compacto ? 122 : 142,
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF241B11),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _MesaCores.douradoClaro, width: 1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'meta ${vm.meta}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: _MesaCores.douradoClaro,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_modalidade(vm.modalidade)} · rodada ${vm.rodada}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFE9D39B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              _BotaoCabecalho(icon: Icons.menu_rounded, onTap: onMenu),
              const SizedBox(width: 5),
              _BotaoCabecalho(icon: Icons.chat_bubble_outline_rounded, onTap: onChat),
            ],
          ),
        );
      },
    );
  }

  static String _modalidade(Modalidade modalidade) {
    switch (modalidade) {
      case Modalidade.aberto:
        return 'ABERTO';
      case Modalidade.fechado:
        return 'FECHADO';
      case Modalidade.sbtl:
        return 'SBTL';
    }
  }
}

class _BotaoCabecalho extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BotaoCabecalho({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF21170E),
            border: Border.all(color: const Color(0xAA6F5324)),
          ),
          child: Icon(icon, color: const Color(0xFFE6D6AF), size: 22),
        ),
      ),
    );
  }
}

class _MesaLonga extends StatelessWidget {
  final MesaVM vm;
  final Animation<double> pulse;
  final VoidCallback onComprarMonte;
  final VoidCallback onPegarLixo;
  final ValueChanged<String> onTapCarta;
  final VoidCallback onBaixar;
  final ValueChanged<String> onEstender;
  final VoidCallback onDescartar;

  const _MesaLonga({
    required this.vm,
    required this.pulse,
    required this.onComprarMonte,
    required this.onPegarLixo,
    required this.onTapCarta,
    required this.onBaixar,
    required this.onEstender,
    required this.onDescartar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(7, 0, 7, 14),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(18)),
        color: _MesaCores.trilho,
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(21), bottom: Radius.circular(15)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.28),
              radius: 1.1,
              colors: [Color(0xFF1D7059), Color(0xFF175946), Color(0xFF103528)],
              stops: [0, 0.57, 1],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _TramaFeltroPainter())),
              Column(
                children: [
                  _LinhaDupla(
                    jogadores: vm.jogadoresEles,
                    placar: vm.eles,
                    titulo: 'ELES',
                    nossaDupla: false,
                    pulse: pulse,
                  ),
                  _PainelMelds(
                    melds: vm.meldsEles,
                    altura: 330,
                    onTapFundo: () {},
                    onTapMeld: onEstender,
                  ),
                  _FaixaCentral(
                    monte: vm.monte,
                    lixo: vm.lixo,
                    mortosRestantes: vm.mortosRestantes,
                    temCartaSelecionada: vm.selecionadas.isNotEmpty,
                    onComprarMonte: onComprarMonte,
                    onPegarLixo: onPegarLixo,
                    onDescartar: onDescartar,
                  ),
                  _LinhaDupla(
                    jogadores: vm.jogadoresNos,
                    placar: vm.nos,
                    titulo: 'NÓS',
                    nossaDupla: true,
                    pulse: pulse,
                  ),
                  _PainelMelds(
                    melds: vm.meldsNos,
                    altura: 330,
                    onTapFundo: onBaixar,
                    onTapMeld: onEstender,
                  ),
                  if (vm.dica != null) _BarraDica(texto: vm.dica!),
                  _MaoJogador(
                    cartas: vm.mao,
                    selecionadas: vm.selecionadas,
                    minhaVez: vm.minhaVez,
                    onTapCarta: onTapCarta,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaDupla extends StatelessWidget {
  final List<JogadorMesa> jogadores;
  final PlacarDupla placar;
  final String titulo;
  final bool nossaDupla;
  final Animation<double> pulse;

  const _LinhaDupla({
    required this.jogadores,
    required this.placar,
    required this.titulo,
    required this.nossaDupla,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 370;
        return SizedBox(
          height: 105,
          child: Padding(
            padding: EdgeInsets.fromLTRB(compacto ? 8 : 12, 8, compacto ? 8 : 12, 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: compacto ? 96 : 105,
                  child: _ChipJogador(jogador: jogadores.first, direita: false),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nossaDupla ? '◆' : '●',
                              style: TextStyle(
                                color: nossaDupla ? const Color(0xFF42D792) : const Color(0xFFE55B57),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$titulo ${placar.pontos} pts',
                              style: TextStyle(
                                color: nossaDupla ? _MesaCores.verdeClaro : _MesaCores.rosaEles,
                                fontSize: compacto ? 18 : 20,
                                fontWeight: FontWeight.w900,
                                shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3)],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (placar.vulneravel) ...[
                        const SizedBox(height: 5),
                        AnimatedBuilder(
                          animation: pulse,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: _MesaCores.vermelho,
                                border: Border.all(color: const Color(0xFFFFE394), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD85A).withOpacity(0.18 + pulse.value * 0.35),
                                    blurRadius: 8 + pulse.value * 13,
                                    spreadRadius: pulse.value * 1.5,
                                  ),
                                ],
                              ),
                              child: Text(
                                '⚡ vulnerável +${placar.vulneravelMinimo}',
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFFFFF4D4),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: compacto ? 96 : 105,
                  child: _ChipJogador(jogador: jogadores.last, direita: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChipJogador extends StatelessWidget {
  final JogadorMesa jogador;
  final bool direita;

  const _ChipJogador({required this.jogador, required this.direita});

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF20170F),
            border: Border.all(color: _MesaCores.douradoClaro, width: 2.4),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 5)],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              jogador.avatar,
              style: TextStyle(
                color: const Color(0xFFFFE7B4),
                fontSize: jogador.avatar.length <= 2 ? 22 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          left: direita ? null : -12,
          right: direita ? -12 : null,
          bottom: -2,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3B2818),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xAA6F5324)),
            ),
            child: Text(jogador.mascote, style: const TextStyle(fontSize: 18)),
          ),
        ),
        if (jogador.ehVoce)
          Positioned(
            left: direita ? -40 : null,
            right: direita ? null : -40,
            top: 12,
            child: Container(
              constraints: const BoxConstraints(minWidth: 35),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF123F30),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x663C9A72)),
              ),
              child: Text(
                '${jogador.cartas}',
                style: const TextStyle(
                  color: Color(0xFFE7D3A0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );

    final nome = Column(
      crossAxisAlignment: direita ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          jogador.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF4E6C4),
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '#${jogador.numero}',
          style: const TextStyle(
            color: Color(0xFFBFE8D0),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );

    final children = <Widget>[];
    if (!direita) {
      children.addAll([avatar, const SizedBox(width: 8), Expanded(child: nome)]);
    } else {
      children.addAll([Expanded(child: nome), const SizedBox(width: 8), avatar]);
    }

    return Row(mainAxisAlignment: direita ? MainAxisAlignment.end : MainAxisAlignment.start, children: children);
  }
}

class _PainelMelds extends StatelessWidget {
  final List<Meld> melds;
  final double altura;
  final VoidCallback onTapFundo;
  final ValueChanged<String> onTapMeld;

  const _PainelMelds({
    required this.melds,
    required this.altura,
    required this.onTapFundo,
    required this.onTapMeld,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapFundo,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: double.infinity,
            height: altura,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            decoration: BoxDecoration(
              color: _MesaCores.painel.withOpacity(0.94),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x441F7D5D)),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 7, offset: Offset(0, 3)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  right: 8,
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 10,
                        children: [
                          for (final meld in melds)
                            _MeldWidget(meld: meld, onTap: () => onTapMeld(meld.id)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x253C7C65),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 4,
                      height: math.min(90, altura * 0.36).toDouble(),
                      decoration: BoxDecoration(
                        color: const Color(0x8A7BA894),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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

class _MeldWidget extends StatelessWidget {
  final Meld meld;
  final VoidCallback onTap;

  const _MeldWidget({required this.meld, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const cardW = 41.0;
    const cardH = 69.0;
    const step = 23.0;
    final width = cardW + math.max(0, meld.cartas.length - 1).toDouble() * step;
    final faixa = meld.tipo != TipoMeld.comum;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width + 4,
        height: cardH + 5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width + 4,
              height: cardH + 5,
              decoration: BoxDecoration(
                color: const Color(0xFF294C3E),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x665A8D79)),
              ),
            ),
            for (var i = 0; i < meld.cartas.length; i++)
              Positioned(
                left: 2 + i * step,
                top: 2,
                child: _MiniCarta(carta: meld.cartas[i], width: cardW, height: cardH),
              ),
            if (faixa)
              Positioned(
                left: 2,
                right: 2,
                bottom: 2,
                height: 20,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: meld.tipo == TipoMeld.suja
                        ? const Color(0xFFB43835)
                        : const Color(0xFFF0C65B),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 2)],
                  ),
                  child: Text(
                    _tipoMeld(meld.tipo),
                    style: TextStyle(
                      color: meld.tipo == TipoMeld.suja ? Colors.white : const Color(0xFF4C3109),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -5,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 25),
                height: 25,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _MesaCores.vinho,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x88712E21)),
                ),
                child: Text(
                  '${meld.contagem}',
                  style: const TextStyle(
                    color: Color(0xFFFFEAD0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tipoMeld(TipoMeld tipo) {
    switch (tipo) {
      case TipoMeld.comum:
        return '';
      case TipoMeld.limpa:
        return 'LIMPA';
      case TipoMeld.suja:
        return 'SUJA';
      case TipoMeld.de500:
        return '500';
    }
  }
}

class _MiniCarta extends StatelessWidget {
  final CartaVM carta;
  final double width;
  final double height;

  const _MiniCarta({required this.carta, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final vermelha = carta.naipe == 'copas' || carta.naipe == 'ouros';
    final cor = vermelha ? _MesaCores.vermelho : _MesaCores.textoEscuro;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(5, 3, 3, 2),
      decoration: BoxDecoration(
        color: _MesaCores.creme,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCFC8B9)),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 2, offset: Offset(1, 1))],
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: carta.valor),
              TextSpan(text: '\n${_naipe(carta.naipe)}', style: const TextStyle(fontSize: 11)),
            ],
          ),
          style: TextStyle(
            color: cor,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            height: 0.78,
          ),
        ),
      ),
    );
  }
}

class _FaixaCentral extends StatelessWidget {
  final PilhaMonte monte;
  final PilhaLixo lixo;
  final int mortosRestantes;
  final bool temCartaSelecionada;
  final VoidCallback onComprarMonte;
  final VoidCallback onPegarLixo;
  final VoidCallback onDescartar;

  const _FaixaCentral({
    required this.monte,
    required this.lixo,
    required this.mortosRestantes,
    required this.temCartaSelecionada,
    required this.onComprarMonte,
    required this.onPegarLixo,
    required this.onDescartar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 145,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _MesaCores.painel.withOpacity(0.96),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x441F7D5D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PilhaItem(
                rotulo: 'monte',
                contagem: monte.contagem,
                onTap: onComprarMonte,
                child: _VersoCarta(mostrarCheck: monte.destaque),
              ),
              const SizedBox(width: 10),
              _PilhaItem(
                rotulo: 'lixo',
                contagem: lixo.contagem,
                onTap: temCartaSelecionada ? onDescartar : onPegarLixo,
                child: lixo.topo == null
                    ? const _SlotLixoVazio()
                    : _MiniCarta(carta: lixo.topo!, width: 58, height: 87),
              ),
            ],
          ),
          const Spacer(),
          _Mortos(restantes: mortosRestantes),
        ],
      ),
    );
  }
}

class _PilhaItem extends StatelessWidget {
  final String rotulo;
  final int contagem;
  final Widget child;
  final VoidCallback onTap;

  const _PilhaItem({
    required this.rotulo,
    required this.contagem,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rotulo,
                  style: const TextStyle(
                    color: Color(0xFFE6F0E9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF123F30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x5549856D)),
                  ),
                  child: Text(
                    '$contagem',
                    style: const TextStyle(
                      color: Color(0xFFE7D3A0),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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
}

class _VersoCarta extends StatelessWidget {
  final bool mostrarCheck;
  final double width;
  final double height;

  const _VersoCarta({this.mostrarCheck = false, this.width = 58, this.height = 87});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7A2F22), Color(0xFF471B11)],
            ),
            border: Border.all(color: _MesaCores.dourado, width: 1.2),
            boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 4, offset: Offset(1, 3))],
          ),
          child: Center(
            child: Container(
              width: width * 0.58,
              height: height * 0.68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x889F6D2B)),
              ),
              child: Text('♛', style: TextStyle(color: _MesaCores.douradoClaro, fontSize: width * 0.42)),
            ),
          ),
        ),
        if (mostrarCheck)
          const Positioned(
            left: -4,
            top: -7,
            child: Text('✓', style: TextStyle(color: Color(0xFF70E59B), fontSize: 23, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }
}

class _SlotLixoVazio extends StatelessWidget {
  const _SlotLixoVazio();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BordaTracejadaPainter(),
      child: const SizedBox(width: 58, height: 87),
    );
  }
}

class _Mortos extends StatelessWidget {
  final int restantes;

  const _Mortos({required this.restantes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (restantes >= 1)
                  const Positioned(left: 9, child: _VersoCarta(width: 54, height: 82)),
                if (restantes >= 2)
                  const Positioned(right: 9, child: _VersoCarta(width: 54, height: 82)),
                if (restantes == 0)
                  const Text('—', style: TextStyle(color: Color(0x668FE0B0), fontSize: 40)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'mortos',
                style: TextStyle(color: Color(0xFFE6F0E9), fontSize: 12.5),
              ),
              const SizedBox(width: 5),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF123F30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x5549856D)),
                ),
                child: Text(
                  '$restantes',
                  style: const TextStyle(
                    color: Color(0xFFE7D3A0),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _BarraDica extends StatelessWidget {
  final String texto;

  const _BarraDica({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 9, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x55112118),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFE3A6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
        ),
      ),
    );
  }
}

class _MaoJogador extends StatelessWidget {
  final List<CartaVM> cartas;
  final Set<String> selecionadas;
  final bool minhaVez;
  final ValueChanged<String> onTapCarta;

  const _MaoJogador({
    required this.cartas,
    required this.selecionadas,
    required this.minhaVez,
    required this.onTapCarta,
  });

  @override
  Widget build(BuildContext context) {
    const cardW = 78.0;
    const cardH = 118.0;
    const step = 43.0;
    final stackW = cardW + math.max(0, cartas.length - 1).toDouble() * step;
    final baseTop = minhaVez ? 36.0 : 50.0;

    return Container(
      height: 182,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x33000000)],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: SizedBox(
          width: stackW,
          height: 182,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var i = 0; i < cartas.length; i++)
                AnimatedPositioned(
                  key: ValueKey(cartas[i].id),
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOutCubic,
                  left: i * step,
                  top: selecionadas.contains(cartas[i].id) ? 1 : baseTop,
                  child: GestureDetector(
                    onTap: () => onTapCarta(cartas[i].id),
                    child: _CartaMao(
                      carta: cartas[i],
                      selecionada: selecionadas.contains(cartas[i].id),
                      width: cardW,
                      height: cardH,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaMao extends StatelessWidget {
  final CartaVM carta;
  final bool selecionada;
  final double width;
  final double height;

  const _CartaMao({
    required this.carta,
    required this.selecionada,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final vermelha = carta.naipe == 'copas' || carta.naipe == 'ouros';
    final cor = vermelha ? _MesaCores.vermelho : _MesaCores.textoEscuro;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
      decoration: BoxDecoration(
        color: _MesaCores.creme,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selecionada ? const Color(0xFFE7C46F) : const Color(0xFFB7B0A1),
          width: selecionada ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selecionada ? const Color(0xAAE8C062) : const Color(0x66000000),
            blurRadius: selecionada ? 9 : 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: carta.valor),
                  TextSpan(text: '\n${_naipe(carta.naipe)}', style: const TextStyle(fontSize: 19)),
                ],
              ),
              style: TextStyle(
                color: cor,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 0.82,
              ),
            ),
          ),
          if (selecionada)
            Align(
              alignment: const Alignment(0, 0.45),
              child: Text(
                _naipe(carta.naipe),
                style: TextStyle(color: cor, fontSize: 38, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

class _TramaFeltroPainter extends CustomPainter {
  const _TramaFeltroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintA = Paint()
      ..color = const Color(0x12000000)
      ..strokeWidth = 0.65;
    final paintB = Paint()
      ..color = const Color(0x0CFFFFFF)
      ..strokeWidth = 0.45;

    const passo = 7.0;
    for (double x = -size.height; x < size.width + size.height; x += passo) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paintA);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paintB);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BordaTracejadaPainter extends CustomPainter {
  const _BordaTracejadaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rect);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = const Color(0x7772A08B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 4.0;
    double distance = 0;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length).toDouble();
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _naipe(String naipe) {
  switch (naipe) {
    case 'copas':
      return '♥';
    case 'ouros':
      return '♦';
    case 'espadas':
      return '♠';
    case 'paus':
      return '♣';
    default:
      return '';
  }
}
