import 'package:flutter/material.dart';

enum SalaSaguao { publico, vip }

enum StatusSaguao { livre, naMesa }

enum CategoriaFala { provocar, elogiar, chamarJogo, reacoes }

class SaguaoVM {
  final SalaSaguao sala;
  final bool ehVip;
  final int online;
  final int vipsOnline;
  final List<MsgSaguao> mensagens;
  final List<JogadorSaguao> jogadores;
  final List<MesaAberta> mesas;
  final List<CategoriaFalas> categorias;
  final List<String> emojis;
  final List<PresenteVip> presentes;

  const SaguaoVM({
    required this.sala,
    required this.ehVip,
    required this.online,
    required this.vipsOnline,
    required this.mensagens,
    required this.jogadores,
    required this.mesas,
    required this.categorias,
    required this.emojis,
    required this.presentes,
  });

  factory SaguaoVM.mock({
    SalaSaguao sala = SalaSaguao.publico,
    bool ehVip = true,
  }) {
    if (sala == SalaSaguao.vip) {
      return SaguaoVM(
        sala: sala,
        ehVip: ehVip,
        online: 128,
        vipsOnline: 42,
        mensagens: const [
          MsgSaguao(
            id: 'v1',
            autor: 'Marina',
            avatar: '🦁',
            texto: 'Boa noite, realeza! Quem topa uma dupla? 🥂',
            ehVoce: false,
            ehVip: true,
          ),
          MsgSaguao(
            id: 'v2',
            autor: 'Você',
            avatar: '',
            texto: 'Eu topo! Vamos no VIP-LOUNGE-1 ✨',
            ehVoce: true,
            ehVip: true,
          ),
          MsgSaguao(
            id: 'v3',
            autor: 'Larissa',
            avatar: '🦄',
            texto: '🌹 pra você, parceira!',
            ehVoce: false,
            ehVip: true,
          ),
          MsgSaguao(
            id: 'v4',
            autor: 'Ricardo',
            avatar: '🦉',
            texto: 'Preparem-se pra perder, majestades 😏',
            ehVoce: false,
            ehVip: true,
          ),
          MsgSaguao(
            id: 'v5',
            autor: 'Você',
            avatar: '',
            texto: 'Só na conversa, hein 😜',
            ehVoce: true,
            ehVip: true,
          ),
        ],
        jogadores: const [
          JogadorSaguao(
            id: 'marina',
            nome: 'Marina',
            avatar: '🦁',
            status: StatusSaguao.livre,
            ehVip: true,
          ),
          JogadorSaguao(
            id: 'ricardo',
            nome: 'Ricardo',
            avatar: '🦉',
            status: StatusSaguao.naMesa,
            ehVip: true,
          ),
          JogadorSaguao(
            id: 'larissa',
            nome: 'Larissa',
            avatar: '🦄',
            status: StatusSaguao.livre,
            ehVip: true,
          ),
          JogadorSaguao(
            id: 'beto',
            nome: 'Beto',
            avatar: '🦊',
            status: StatusSaguao.livre,
            ehVip: true,
          ),
        ],
        mesas: const [
          MesaAberta(
            codigo: 'VIP-LOUNGE-1',
            modalidade: 'Fechado',
            pontos: 3000,
            vagas: 1,
          ),
          MesaAberta(
            codigo: 'VIP-LOUNGE-2',
            modalidade: 'Aberto',
            pontos: 2000,
            vagas: 2,
          ),
          MesaAberta(
            codigo: 'VIP-LOUNGE-3',
            modalidade: 'Fechado',
            pontos: 5000,
            vagas: 1,
          ),
        ],
        categorias: const [
          CategoriaFalas(
            id: CategoriaFala.provocar,
            icone: '🎯',
            label: 'Provocar',
            falas: [
              'Tá inspirado hoje 😏',
              'Vai amarelar? 😜',
              'Só na conversa 😎',
              'Chorou, nobre? 😂',
              'Chega mais! 😏',
              'Cadê a canastra, majestade? 👀',
            ],
          ),
          CategoriaFalas(
            id: CategoriaFala.elogiar,
            icone: '👑',
            label: 'Elogiar',
            falas: [
              'Que honra! 👑',
              'Impecável! 💎',
              'Majestade! ✨',
              'Nobre jogada 🥂',
              'Parceria de ouro 🤝',
              'Digno da realeza 👑',
            ],
          ),
          CategoriaFalas(
            id: CategoriaFala.chamarJogo,
            icone: '🎴',
            label: 'Chamar pro jogo',
            falas: [
              'Bora, realeza ✨',
              'Procuro dupla nobre',
              'Entra no lounge 🥂',
              'Bora bater! 💪',
              'Falta 1 no VIP-LOUNGE',
              'Manda o código 👑',
            ],
          ),
          CategoriaFalas(
            id: CategoriaFala.reacoes,
            icone: '🥂',
            label: 'Reações',
            falas: [
              'Saúde! 🥂',
              '🌹 pra você',
              'Haha 👑',
              'Perfeito 💎',
              'Que noite! ✨',
              'Até a próxima! 👋',
            ],
          ),
        ],
        emojis: const [
          '👑',
          '🥂',
          '🌹',
          '💎',
          '✨',
          '😏',
          '🔥',
          '❤️',
          '🍾',
          '🎉',
          '🤝',
          '😎',
          '🙌',
          '👏',
          '😂',
          '😜',
          '🃏',
          '👊',
        ],
        presentes: const [
          PresenteVip(
            id: 'rosa',
            emoji: '🌹',
            nome: 'Rosa',
            custoMoedas: 50,
          ),
          PresenteVip(
            id: 'bombom',
            emoji: '🍫',
            nome: 'Bombom',
            custoMoedas: 100,
          ),
          PresenteVip(
            id: 'champanhe',
            emoji: '🍾',
            nome: 'Champanhe',
            custoMoedas: 200,
          ),
          PresenteVip(
            id: 'diamante',
            emoji: '💎',
            nome: 'Diamante',
            custoMoedas: 500,
          ),
        ],
      );
    }

    return SaguaoVM(
      sala: sala,
      ehVip: ehVip,
      online: 128,
      vipsOnline: 42,
      mensagens: const [
        MsgSaguao(
          id: 'p1',
          autor: 'Paulo',
          avatar: '🐼',
          texto: 'Alguém pra dupla no Fechado? 🃏',
          ehVoce: false,
          ehVip: false,
        ),
        MsgSaguao(
          id: 'p2',
          autor: 'Você',
          avatar: '',
          texto: 'Bora! Manda o código 👊',
          ehVoce: true,
          ehVip: false,
        ),
        MsgSaguao(
          id: 'p3',
          autor: 'Rita',
          avatar: '🐨',
          texto: 'Entra na BURACO-7K2M, tá com 1 vaga!',
          ehVoce: false,
          ehVip: false,
        ),
        MsgSaguao(
          id: 'p4',
          autor: 'Beto',
          avatar: '🦊',
          texto: 'Hoje ninguém me segura, hein 😏',
          ehVoce: false,
          ehVip: false,
        ),
        MsgSaguao(
          id: 'p5',
          autor: 'Você',
          avatar: '',
          texto: 'Veremos, campeão 😜',
          ehVoce: true,
          ehVip: false,
        ),
      ],
      jogadores: const [
        JogadorSaguao(
          id: 'claudia',
          nome: 'Cláudia',
          avatar: '🐰',
          status: StatusSaguao.livre,
          ehVip: false,
        ),
        JogadorSaguao(
          id: 'beto',
          nome: 'Beto',
          avatar: '🦊',
          status: StatusSaguao.naMesa,
          ehVip: false,
        ),
        JogadorSaguao(
          id: 'fernanda',
          nome: 'Fernanda',
          avatar: '🐶',
          status: StatusSaguao.livre,
          ehVip: false,
        ),
        JogadorSaguao(
          id: 'paulo',
          nome: 'Paulo',
          avatar: '🐵',
          status: StatusSaguao.livre,
          ehVip: false,
        ),
        JogadorSaguao(
          id: 'rita',
          nome: 'Rita',
          avatar: '🐨',
          status: StatusSaguao.naMesa,
          ehVip: false,
        ),
      ],
      mesas: const [
        MesaAberta(
          codigo: 'BURACO-7K2M',
          modalidade: 'Fechado',
          pontos: 1500,
          vagas: 1,
        ),
        MesaAberta(
          codigo: 'BURACO-9X4P',
          modalidade: 'Aberto',
          pontos: 1000,
          vagas: 2,
        ),
        MesaAberta(
          codigo: 'BURACO-3B8T',
          modalidade: 'Fechado',
          pontos: 2000,
          vagas: 1,
        ),
        MesaAberta(
          codigo: 'BURACO-5M2K',
          modalidade: 'Aberto',
          pontos: 1500,
          vagas: 3,
        ),
      ],
      categorias: const [
        CategoriaFalas(
          id: CategoriaFala.provocar,
          icone: '🎯',
          label: 'Provocar',
          falas: [
            'Tá voando, hein? 😏',
            'Vai perder essa! 😜',
            'Chorou? 😂',
            'Amarelou? 🐔',
            'Só na conversa 😎',
            'Bateu e assoprou 🤭',
            'Cadê a canastra? 👀',
          ],
        ),
        CategoriaFalas(
          id: CategoriaFala.elogiar,
          icone: '👏',
          label: 'Elogiar',
          falas: [
            'Boa jogada! 👏',
            'Que canastra! 🔥',
            'Jogou demais! 😮',
            'Parceria nota 10 🤝',
            'Mestre! 👑',
            'Tá voando bonito ✨',
          ],
        ),
        CategoriaFalas(
          id: CategoriaFala.chamarJogo,
          icone: '🎴',
          label: 'Chamar pro jogo',
          falas: [
            'Bora jogar! 🃏',
            'Procuro dupla',
            'Manda o código',
            'Bora bater! 💪',
            'Entra aí! 🎴',
            'Falta 1 pra fechar mesa',
          ],
        ),
        CategoriaFalas(
          id: CategoriaFala.reacoes,
          icone: '😅',
          label: 'Reações',
          falas: [
            'Haha 😂',
            'Ufa! 😮‍💨',
            'Vixe... 😬',
            'Valeu! ❤️',
            'Boa sorte! 🍀',
            'Até a próxima! 👋',
          ],
        ),
      ],
      emojis: const [
        '😄',
        '😂',
        '😅',
        '😜',
        '😏',
        '😎',
        '👏',
        '🔥',
        '🃏',
        '👑',
        '💪',
        '👊',
        '🤝',
        '❤️',
        '🍀',
        '🎉',
        '😱',
        '🙌',
      ],
      presentes: const [
        PresenteVip(
          id: 'rosa',
          emoji: '🌹',
          nome: 'Rosa',
          custoMoedas: 50,
        ),
        PresenteVip(
          id: 'bombom',
          emoji: '🍫',
          nome: 'Bombom',
          custoMoedas: 100,
        ),
        PresenteVip(
          id: 'champanhe',
          emoji: '🍾',
          nome: 'Champanhe',
          custoMoedas: 200,
        ),
        PresenteVip(
          id: 'diamante',
          emoji: '💎',
          nome: 'Diamante',
          custoMoedas: 500,
        ),
      ],
    );
  }

  SaguaoVM copyWith({
    SalaSaguao? sala,
    bool? ehVip,
    int? online,
    int? vipsOnline,
    List<MsgSaguao>? mensagens,
    List<JogadorSaguao>? jogadores,
    List<MesaAberta>? mesas,
    List<CategoriaFalas>? categorias,
    List<String>? emojis,
    List<PresenteVip>? presentes,
  }) {
    return SaguaoVM(
      sala: sala ?? this.sala,
      ehVip: ehVip ?? this.ehVip,
      online: online ?? this.online,
      vipsOnline: vipsOnline ?? this.vipsOnline,
      mensagens: mensagens ?? this.mensagens,
      jogadores: jogadores ?? this.jogadores,
      mesas: mesas ?? this.mesas,
      categorias: categorias ?? this.categorias,
      emojis: emojis ?? this.emojis,
      presentes: presentes ?? this.presentes,
    );
  }
}

class MsgSaguao {
  final String id;
  final String autor;
  final String avatar;
  final String texto;
  final bool ehVoce;
  final bool ehVip;

  const MsgSaguao({
    required this.id,
    required this.autor,
    required this.avatar,
    required this.texto,
    required this.ehVoce,
    required this.ehVip,
  });
}

class JogadorSaguao {
  final String id;
  final String nome;
  final String avatar;
  final StatusSaguao status;
  final bool ehVip;

  const JogadorSaguao({
    required this.id,
    required this.nome,
    required this.avatar,
    required this.status,
    required this.ehVip,
  });
}

class MesaAberta {
  final String codigo;
  final String modalidade;
  final int pontos;
  final int vagas;

  const MesaAberta({
    required this.codigo,
    required this.modalidade,
    required this.pontos,
    required this.vagas,
  });
}

class CategoriaFalas {
  final CategoriaFala id;
  final String icone;
  final String label;
  final List<String> falas;

  const CategoriaFalas({
    required this.id,
    required this.icone,
    required this.label,
    required this.falas,
  });
}

class PresenteVip {
  final String id;
  final String emoji;
  final String nome;
  final int custoMoedas;

  const PresenteVip({
    required this.id,
    required this.emoji,
    required this.nome,
    required this.custoMoedas,
  });
}

class SaguaoScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _text = Color(0xFFEFE3CC);
  static const _muted = Color(0xFF9D8C68);
  static const _publicCard = Color(0xFF1C130C);
  static const _vipCard = Color(0xFF221606);
  static const _free = Color(0xFF4BD07A);
  static const _busy = Color(0xFFE0953A);

  final SaguaoVM vm;
  final VoidCallback onVoltar;
  final ValueChanged<SalaSaguao> onTrocarSala;
  final VoidCallback onVipBloqueado;
  final void Function(CategoriaFala cat, String fala) onEnviarFala;
  final ValueChanged<String> onEnviarEmoji;
  final ValueChanged<String> onPresentearSalao;
  final ValueChanged<String> onPresentearJogador;
  final ValueChanged<String> onConvidar;
  final ValueChanged<String> onAssistir;
  final ValueChanged<String> onEntrarMesa;

  const SaguaoScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onTrocarSala,
    required this.onVipBloqueado,
    required this.onEnviarFala,
    required this.onEnviarEmoji,
    required this.onPresentearSalao,
    required this.onPresentearJogador,
    required this.onConvidar,
    required this.onAssistir,
    required this.onEntrarMesa,
  });

  bool get _vip => vm.sala == SalaSaguao.vip;
  Color get _card => _vip ? _vipCard : _publicCard;
  Color get _border => _vip ? const Color(0x55EFB94A) : const Color(0x33EFB94A);

  @override
  Widget build(BuildContext context) {
    final gradient = _vip
        ? const [Color(0xFF3A2A0E), Color(0xFF1C1206), Color(0xFF0A0602)]
        : const [Color(0xFF241812), Color(0xFF120A06), Color(0xFF000000)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
            stops: const [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _TopBar(
                    vip: _vip,
                    online: _vip ? vm.vipsOnline : vm.online,
                    onVoltar: onVoltar,
                  ),
                  _Doors(
                    sala: vm.sala,
                    ehVip: vm.ehVip,
                    onPublico: () => onTrocarSala(SalaSaguao.publico),
                    onVip: () {
                      if (vm.ehVip) {
                        onTrocarSala(SalaSaguao.vip);
                      } else {
                        onVipBloqueado();
                      }
                    },
                  ),
                  _Actions(
                    vip: _vip,
                    jogadores: _vip ? vm.vipsOnline : vm.online,
                    mesas: _vip ? 6 : 12,
                    onJogadores: () => _showPlayers(context),
                    onMesas: () => _showTables(context),
                  ),
                  Expanded(child: _MessageFeed(vm: vm, vip: _vip, card: _card, border: _border)),
                  _BottomCategories(
                    vm: vm,
                    vip: _vip,
                    onCategoria: (cat) => _showPhrases(context, cat),
                    onEmojis: () => _showEmojis(context),
                    onPresentes: () => _showGifts(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhrases(BuildContext context, CategoriaFalas categoria) {
    _openSheet(
      context,
      title: '${categoria.icone} ${_sheetTitle(categoria)}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categoria.falas.map((fala) {
          final provocar = categoria.id == CategoriaFala.provocar;
          return _OptionChip(
            label: fala,
            danger: provocar,
            vip: _vip,
            onTap: () {
              Navigator.of(context).pop();
              onEnviarFala(categoria.id, fala);
            },
          );
        }).toList(),
      ),
    );
  }

  String _sheetTitle(CategoriaFalas categoria) {
    switch (categoria.id) {
      case CategoriaFala.provocar:
        return _vip ? 'Provocações VIP' : 'Provocações';
      case CategoriaFala.elogiar:
        return 'Elogios';
      case CategoriaFala.chamarJogo:
        return 'Chamar pro jogo';
      case CategoriaFala.reacoes:
        return 'Reações';
    }
  }

  void _showEmojis(BuildContext context) {
    _openSheet(
      context,
      title: _vip ? '😀 Emojis VIP' : '😀 Emojis',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: vm.emojis.length,
        itemBuilder: (context, index) {
          final emoji = vm.emojis[index];
          return InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () {
              Navigator.of(context).pop();
              onEnviarEmoji(emoji);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _vip
                      ? const Color(0x26EFB94A)
                      : Colors.white.withValues(alpha: .07),
                ),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 25)),
            ),
          );
        },
      ),
    );
  }

  void _showGifts(BuildContext context) {
    if (!_vip) return;
    _openSheet(
      context,
      title: '🎁 Presentear o salão',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.45,
        ),
        itemCount: vm.presentes.length,
        itemBuilder: (context, index) {
          final presente = vm.presentes[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).pop();
              onPresentearSalao(presente.id);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x55EFB94A)),
              ),
              padding: const EdgeInsets.all(9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(presente.emoji, style: const TextStyle(fontSize: 27)),
                  const SizedBox(height: 3),
                  Text(
                    presente.nome,
                    style: const TextStyle(
                      color: Color(0xFFD9C79A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '🪙 ${_formatNumber(presente.custoMoedas)}',
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
        },
      ),
    );
  }

  void _showPlayers(BuildContext context) {
    _openSheet(
      context,
      title: _vip
          ? '👑 VIPs online · ${vm.vipsOnline}'
          : '👥 Jogadores online · ${vm.online}',
      child: Column(
        children: vm.jogadores.map((jogador) {
          return _PlayerRow(
            jogador: jogador,
            vip: _vip,
            onGift: () {
              Navigator.of(context).pop();
              onPresentearJogador(jogador.id);
            },
            onAction: () {
              Navigator.of(context).pop();
              if (jogador.status == StatusSaguao.livre) {
                onConvidar(jogador.id);
              } else {
                onAssistir(jogador.id);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showTables(BuildContext context) {
    _openSheet(
      context,
      title: _vip ? '🎴 Mesas VIP · 6' : '🎴 Mesas abertas · 12',
      child: Column(
        children: vm.mesas.map((mesa) {
          return _TableRow(
            mesa: mesa,
            vip: _vip,
            onTap: () {
              Navigator.of(context).pop();
              onEntrarMesa(mesa.codigo);
            },
          );
        }).toList(),
      ),
    );
  }

  void _openSheet(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .65),
      builder: (sheetContext) {
        return Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .76,
              ),
              decoration: BoxDecoration(
                color: _vip ? const Color(0xFF1A1206) : const Color(0xFF160F08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(top: BorderSide(color: _border)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 30,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _goldHi,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          tooltip: 'Fechar',
                          icon: Icon(
                            Icons.close_rounded,
                            color: _vip
                                ? const Color(0xFFC9A86A)
                                : const Color(0xFFB6A884),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool vip;
  final int online;
  final VoidCallback onVoltar;

  const _TopBar({
    required this.vip,
    required this.online,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onVoltar,
            tooltip: 'Voltar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: SaguaoScreen._gold,
              size: 28,
            ),
          ),
          Expanded(
            child: Text(
              vip ? '👑 Salão VIP' : 'Saguão',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SaguaoScreen._goldHi,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                shadows: vip
                    ? const [
                        Shadow(color: Color(0x44EFB94A), blurRadius: 8),
                      ]
                    : null,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: vip
                  ? const LinearGradient(
                      colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)],
                    )
                  : null,
              color: vip ? null : const Color(0xFF0E2A1C),
              borderRadius: BorderRadius.circular(20),
              border: vip
                  ? null
                  : Border.all(color: const Color(0x552F7D4D)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              vip ? '👑 $online VIPs' : '🟢 $online online',
              style: TextStyle(
                color: vip ? const Color(0xFF3A2606) : const Color(0xFF8FE0B0),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Doors extends StatelessWidget {
  final SalaSaguao sala;
  final bool ehVip;
  final VoidCallback onPublico;
  final VoidCallback onVip;

  const _Doors({
    required this.sala,
    required this.ehVip,
    required this.onPublico,
    required this.onVip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: _DoorButton(
              label: '💬 Lobby Público',
              active: sala == SalaSaguao.publico,
              publicDoor: true,
              onTap: onPublico,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DoorButton(
              label: '👑 VIP${ehVip ? '' : ' 🔒'}',
              active: sala == SalaSaguao.vip,
              publicDoor: false,
              onTap: onVip,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoorButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool publicDoor;
  final VoidCallback onTap;

  const _DoorButton({
    required this.label,
    required this.active,
    required this.publicDoor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vipTheme = !publicDoor && active;
    final publicTheme = publicDoor && active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: publicTheme
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFA7E8C1), Color(0xFF5FD08A)],
                  )
                : vipTheme
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)],
                      )
                    : null,
            color: active ? null : Colors.black.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : publicDoor
                      ? const Color(0x662F7D4D)
                      : const Color(0x55EFB94A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? publicTheme
                      ? const Color(0xFF123020)
                      : const Color(0xFF3A2606)
                  : publicDoor
                      ? const Color(0xFFA9D6BB)
                      : const Color(0xFFF0D99A),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final bool vip;
  final int jogadores;
  final int mesas;
  final VoidCallback onJogadores;
  final VoidCallback onMesas;

  const _Actions({
    required this.vip,
    required this.jogadores,
    required this.mesas,
    required this.onJogadores,
    required this.onMesas,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              vip: vip,
              label: vip ? '👑 VIPs online' : '👥 Jogadores',
              count: jogadores,
              onTap: onJogadores,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              vip: vip,
              label: vip ? '🎴 Mesas VIP' : '🎴 Mesas abertas',
              count: mesas,
              onTap: onMesas,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool vip;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.vip,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
          decoration: BoxDecoration(
            gradient: vip
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
                  )
                : null,
            color: vip ? null : SaguaoScreen._publicCard,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: vip ? const Color(0x55EFB94A) : const Color(0x33EFB94A),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: vip ? const Color(0xFFF0D99A) : const Color(0xFFE6D4A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: vip
                      ? const LinearGradient(
                          colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)],
                        )
                      : null,
                  color: vip ? null : const Color(0xFF12301E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: vip
                        ? const Color(0xFF3A2606)
                        : const Color(0xFF8FE0B0),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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

class _MessageFeed extends StatelessWidget {
  final SaguaoVM vm;
  final bool vip;
  final Color card;
  final Color border;

  const _MessageFeed({
    required this.vm,
    required this.vip,
    required this.card,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          itemCount: vm.mensagens.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(9, 2, 9, 8),
                child: Text(
                  vip
                      ? '💬 Chat premium por falas prontas · reações e presentes exclusivos 👑'
                      : '💬 Converse por falas prontas · sem digitação, ambiente seguro 🙂',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: vip ? const Color(0xFFC9A86A) : const Color(0xFF8A7C5E),
                    fontSize: 10,
                  ),
                ),
              );
            }
            final msg = vm.mensagens[index - 1];
            return _MessageBubble(
              msg: msg,
              vip: vip,
              card: card,
              border: border,
              maxWidth: constraints.maxWidth * .84,
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MsgSaguao msg;
  final bool vip;
  final Color card;
  final Color border;
  final double maxWidth;

  const _MessageBubble({
    required this.msg,
    required this.vip,
    required this.card,
    required this.border,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: msg.ehVoce
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: vip
                    ? const [Color(0xFF4A3410), Color(0xFF2A1C08)]
                    : const [Color(0xFF3A2A12), Color(0xFF241708)],
              )
            : vip
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
                  )
                : null,
        color: msg.ehVoce || vip ? null : card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(msg.ehVoce ? 12 : 3),
          topRight: Radius.circular(msg.ehVoce ? 3 : 12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${msg.autor}${msg.ehVip ? ' 👑' : ''}',
            style: const TextStyle(
              color: SaguaoScreen._gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            msg.texto,
            style: const TextStyle(
              color: SaguaoScreen._text,
              fontSize: 13,
              height: 1.23,
            ),
          ),
        ],
      ),
    );

    if (msg.ehVoce) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: vip ? const Color(0xFF3A2606) : const Color(0xFF2A1C10),
              shape: BoxShape.circle,
              border: Border.all(
                color: vip ? SaguaoScreen._gold : const Color(0x55EFB94A),
                width: vip ? 1.5 : 1.3,
              ),
            ),
            alignment: Alignment.center,
            child: Text(msg.avatar, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 7),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _BottomCategories extends StatelessWidget {
  final SaguaoVM vm;
  final bool vip;
  final ValueChanged<CategoriaFalas> onCategoria;
  final VoidCallback onEmojis;
  final VoidCallback onPresentes;

  const _BottomCategories({
    required this.vm,
    required this.vip,
    required this.onCategoria,
    required this.onEmojis,
    required this.onPresentes,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ...vm.categorias.map(
        (categoria) => _CategoryChip(
          label: '${categoria.icone} ${categoria.label}',
          danger: categoria.id == CategoriaFala.provocar,
          vip: vip,
          onTap: () => onCategoria(categoria),
        ),
      ),
      if (vip)
        _CategoryChip(
          label: '🎁 Presentes',
          gift: true,
          vip: true,
          onTap: onPresentes,
        ),
      _CategoryChip(
        label: '😀 Emojis',
        emoji: true,
        vip: vip,
        onTap: onEmojis,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: vip
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF170F06), Color(0xFF0D0805)],
              )
            : null,
        color: vip ? null : const Color(0xFF0D0805),
        border: Border(top: BorderSide(color: vip ? const Color(0x55EFB94A) : const Color(0x33EFB94A))),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'TOQUE NUMA CATEGORIA PRA MANDAR UMA FALA',
              style: TextStyle(
                color: vip ? const Color(0xFFC9A86A) : const Color(0xFF8A7C5E),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _withSpacing(chips, 7)),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children, double gap) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) result.add(SizedBox(width: gap));
      result.add(children[i]);
    }
    return result;
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool danger;
  final bool gift;
  final bool emoji;
  final bool vip;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.vip,
    required this.onTap,
    this.danger = false,
    this.gift = false,
    this.emoji = false,
  });

  @override
  Widget build(BuildContext context) {
    Color border;
    Color foreground;
    Color background;
    if (danger) {
      border = vip ? const Color(0xFFC98A3A) : const Color(0x889C302E);
      foreground = vip ? const Color(0xFFF6C98A) : const Color(0xFFE79A92);
      background = vip ? const Color(0xFF241708) : const Color(0xFF2A0F0D);
    } else {
      border = gift || emoji
          ? const Color(0x99EFB94A)
          : vip
              ? const Color(0x55EFB94A)
              : const Color(0x3DEFB94A);
      foreground = gift || emoji
          ? const Color(0xFFF6D77A)
          : vip
              ? const Color(0xFFF0D99A)
              : const Color(0xFFE6D4A6);
      background = Colors.black.withValues(alpha: .3);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool danger;
  final bool vip;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.danger,
    required this.vip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: danger
                ? vip
                    ? const Color(0xFF241708)
                    : const Color(0xFF2A0F0D)
                : Colors.black.withValues(alpha: .3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger
                  ? vip
                      ? const Color(0xFFC98A3A)
                      : const Color(0x889C302E)
                  : vip
                      ? const Color(0x55EFB94A)
                      : const Color(0x3DEFB94A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: danger
                  ? vip
                      ? const Color(0xFFF6C98A)
                      : const Color(0xFFE79A92)
                  : vip
                      ? const Color(0xFFF0D99A)
                      : const Color(0xFFE6D4A6),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final JogadorSaguao jogador;
  final bool vip;
  final VoidCallback onGift;
  final VoidCallback onAction;

  const _PlayerRow({
    required this.jogador,
    required this.vip,
    required this.onGift,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final livre = jogador.status == StatusSaguao.livre;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: vip ? SaguaoScreen._vipCard : SaguaoScreen._publicCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vip ? const Color(0x2EEFB94A) : Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: vip ? const Color(0xFF3A2606) : const Color(0xFF2A1C10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vip ? SaguaoScreen._gold : const Color(0x55EFB94A),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(jogador.avatar, style: const TextStyle(fontSize: 17)),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: livre ? SaguaoScreen._free : SaguaoScreen._busy,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: vip ? SaguaoScreen._vipCard : SaguaoScreen._publicCard,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (jogador.ehVip)
                const Positioned(
                  right: -7,
                  top: -9,
                  child: Text('👑', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jogador.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SaguaoScreen._text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  livre ? '● Livre' : '● Numa mesa',
                  style: TextStyle(
                    color: livre ? const Color(0xFF7FE0A3) : const Color(0xFFEFB46A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (vip) ...[
            _SmallOutlineButton(label: '🎁', onTap: onGift),
            const SizedBox(width: 6),
          ],
          _PlayerActionButton(
            label: livre ? 'Convidar' : 'Assistir',
            outlined: !livre && !vip,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallOutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x88EFB94A), width: 1.2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SaguaoScreen._gold,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PlayerActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;

  const _PlayerActionButton({
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: outlined
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)],
                ),
          borderRadius: BorderRadius.circular(9),
          border: outlined
              ? Border.all(color: const Color(0x99EFB46A), width: 1.2)
              : null,
        ),
        child: Text(
          outlined ? '🔒 $label' : label,
          style: TextStyle(
            color: outlined ? const Color(0xFFEFB46A) : const Color(0xFF3A2606),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final MesaAberta mesa;
  final bool vip;
  final VoidCallback onTap;

  const _TableRow({
    required this.mesa,
    required this.vip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        gradient: vip
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
              )
            : null,
        color: vip ? null : SaguaoScreen._publicCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vip ? const Color(0x66EFB94A) : const Color(0x33EFB94A),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mesa.codigo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SaguaoScreen._goldHi,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${mesa.modalidade} · ${_formatNumber(mesa.pontos)} pts',
                  style: TextStyle(
                    color: vip ? const Color(0xFFE0B45A) : const Color(0xFF8FBF9F),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: vip
                  ? const LinearGradient(
                      colors: [Color(0xFFF6E2A6), Color(0xFFD5A84A)],
                    )
                  : null,
              color: vip ? null : const Color(0xFF12301E),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${mesa.vagas} ${mesa.vagas == 1 ? 'vaga' : 'vagas'}',
              style: TextStyle(
                color: vip ? const Color(0xFF3A2606) : const Color(0xFF8FE0B0),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '🎴 Entrar',
                style: TextStyle(
                  color: Color(0xFF3A2606),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );
}
