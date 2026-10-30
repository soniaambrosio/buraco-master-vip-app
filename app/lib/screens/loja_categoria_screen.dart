import 'package:flutter/material.dart';

import 'perfil_screen.dart' show NavDestino;
import 'loja_screen.dart' show LojaCategoria;

enum Raridade { comum, raro, epico, lendario, vip }

enum MoedaTipo { moedas, gemas }

enum ItemEstado { bloqueado, disponivel, comprado, equipado }

extension LojaCategoriaVisual on LojaCategoria {
  String get titulo {
    switch (this) {
      case LojaCategoria.dorsos:
        return 'Dorsos de Carta';
      case LojaCategoria.molduras:
        return 'Molduras';
      case LojaCategoria.avatares:
        return 'Avatares';
      case LojaCategoria.mascotes:
        return 'Mascotes';
      case LojaCategoria.efeitos:
        return 'Efeitos de Vitória';
      case LojaCategoria.emojis:
        return 'Emojis VIP';
    }
  }

  String get descricao {
    switch (this) {
      case LojaCategoria.dorsos:
        return 'Personalize o verso das suas cartas.';
      case LojaCategoria.molduras:
        return 'Destaque seu perfil dentro e fora da mesa.';
      case LojaCategoria.avatares:
        return 'Escolha o rosto que representa seu jogo.';
      case LojaCategoria.mascotes:
        return 'Leve um companheiro especial para as partidas.';
      case LojaCategoria.efeitos:
        return 'Celebre vitórias com animações premium.';
      case LojaCategoria.emojis:
        return 'Expresse cada jogada com personalidade.';
    }
  }

  String get icone {
    switch (this) {
      case LojaCategoria.dorsos:
        return '🂠';
      case LojaCategoria.molduras:
        return '🖼️';
      case LojaCategoria.avatares:
        return '👤';
      case LojaCategoria.mascotes:
        return '🦉';
      case LojaCategoria.efeitos:
        return '✨';
      case LojaCategoria.emojis:
        return '😎';
    }
  }

  String get assetDestaque {
    switch (this) {
      case LojaCategoria.dorsos:
        return 'assets/loja/dorsos/imperio.webp';
      case LojaCategoria.molduras:
        return 'assets/loja/molduras/ametista.webp';
      case LojaCategoria.avatares:
        return 'assets/loja/avatares/duquesa.webp';
      case LojaCategoria.mascotes:
        return 'assets/loja/mascotes/coruja_jogadora.webp';
      case LojaCategoria.efeitos:
        return 'assets/loja/efeitos/coroa_triunfal.webp';
      case LojaCategoria.emojis:
        return 'assets/loja/emojis/malandro.webp';
    }
  }
}

class LojaCategoriaVM {
  final LojaCategoria categoria;
  final String titulo;
  final int moedas;
  final int gemas;
  final bool ehVip;
  final List<ItemCosmetico> itens;
  final List<AmigoPresente> amigos;

  const LojaCategoriaVM({
    required this.categoria,
    required this.titulo,
    required this.moedas,
    required this.gemas,
    required this.ehVip,
    required this.itens,
    required this.amigos,
  });

  factory LojaCategoriaVM.mock(LojaCategoria categoria) {
    final amigos = <AmigoPresente>[
      const AmigoPresente(id: 'ana_bella', nome: 'Ana Bella', avatar: '🐰'),
      const AmigoPresente(id: 'claudia', nome: 'Cláudia', avatar: '👑'),
      const AmigoPresente(id: 'beto', nome: 'Beto', avatar: '🦊'),
      const AmigoPresente(id: 'marina', nome: 'Marina', avatar: '🐱'),
      const AmigoPresente(id: 'julia', nome: 'Júlia Lima', avatar: '🐵'),
      const AmigoPresente(id: 'ricardo', nome: 'Ricardo', avatar: '🐻'),
    ];

    return LojaCategoriaVM(
      categoria: categoria,
      titulo: categoria.titulo,
      moedas: 1000,
      gemas: 28,
      ehVip: false,
      itens: _catalogoMock(categoria),
      amigos: amigos,
    );
  }
}

class ItemCosmetico {
  final String id;
  final String nome;
  final Raridade raridade;
  final int preco;
  final MoedaTipo moeda;
  final String previa;
  final ItemEstado estado;
  final bool soVip;
  final bool presenteavel;

  const ItemCosmetico({
    required this.id,
    required this.nome,
    required this.raridade,
    required this.preco,
    required this.moeda,
    required this.previa,
    required this.estado,
    required this.soVip,
    required this.presenteavel,
  });
}

class AmigoPresente {
  final String id;
  final String nome;
  final String avatar;

  const AmigoPresente({
    required this.id,
    required this.nome,
    required this.avatar,
  });
}

class LojaCategoriaScreen extends StatefulWidget {
  final LojaCategoriaVM vm;
  final VoidCallback onVoltar;
  final VoidCallback onComprarMoedas;
  final ValueChanged<String> onComprar;
  final ValueChanged<String> onConfirmarCompra;
  final ValueChanged<String> onEquipar;
  final ValueChanged<String> onItemBloqueado;
  final ValueChanged<String> onPresentear;
  final ValueChanged<String> onBuscarPresenteado;
  final void Function(String itemId, String jogadorId) onEnviarPresente;
  final ValueChanged<NavDestino> onNav;

  const LojaCategoriaScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onComprarMoedas,
    required this.onComprar,
    required this.onConfirmarCompra,
    required this.onEquipar,
    required this.onItemBloqueado,
    required this.onPresentear,
    required this.onBuscarPresenteado,
    required this.onEnviarPresente,
    required this.onNav,
  });

  @override
  State<LojaCategoriaScreen> createState() => _LojaCategoriaScreenState();
}

class _LojaCategoriaScreenState extends State<LojaCategoriaScreen> {
  static const _dourado = Color(0xFFEFB94A);
  static const _douradoClaro = Color(0xFFF6E2A6);
  static const _fundoTopo = Color(0xFF241812);
  static const _fundoMeio = Color(0xFF120A06);

  String? _amigoSelecionado;
  String _busca = '';

  List<AmigoPresente> get _amigosFiltrados {
    final termo = _normalizar(_busca.trim());
    if (termo.isEmpty) return widget.vm.amigos;
    return widget.vm.amigos
        .where((amigo) => _normalizar(amigo.nome).contains(termo))
        .toList(growable: false);
  }

  String _normalizar(String valor) {
    const de = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var resultado = valor;
    for (var i = 0; i < de.length; i++) {
      resultado = resultado.replaceAll(de[i], para[i]);
    }
    return resultado.toLowerCase();
  }

  void _abrirCompra(ItemCosmetico item) {
    widget.onComprar(item.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompraSheet(
        item: item,
        saldo: widget.vm.moedas,
        onConfirmar: () {
          widget.onConfirmarCompra(item.id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _abrirPresente(ItemCosmetico item) {
    widget.onPresentear(item.id);
    setState(() {
      _amigoSelecionado = null;
      _busca = '';
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final amigos = _amigosFiltrados;
            return _PresenteSheet(
              item: item,
              amigos: amigos,
              amigoSelecionado: _amigoSelecionado,
              onBusca: (termo) {
                widget.onBuscarPresenteado(termo);
                setState(() => _busca = termo);
                setSheetState(() {});
              },
              onSelecionar: (id) {
                setState(() => _amigoSelecionado = id);
                setSheetState(() {});
              },
              onEnviar: _amigoSelecionado == null
                  ? null
                  : () {
                      widget.onEnviarPresente(item.id, _amigoSelecionado!);
                      Navigator.of(sheetContext).pop();
                    },
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _amigoSelecionado = null;
          _busca = '';
        });
      }
    });
  }

  void _acaoPrincipal(ItemCosmetico item) {
    switch (item.estado) {
      case ItemEstado.bloqueado:
        widget.onItemBloqueado(item.id);
        break;
      case ItemEstado.disponivel:
        _abrirCompra(item);
        break;
      case ItemEstado.comprado:
        widget.onEquipar(item.id);
        break;
      case ItemEstado.equipado:
        widget.onEquipar(item.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_fundoTopo, _fundoMeio, Colors.black],
            stops: [0, .56, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _topo(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.vm.categoria.descricao,
                    style: const TextStyle(
                      color: Color(0xFFC9BA99),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final alturaCard = constraints.maxWidth <= 370 ? 262.0 : 274.0;
                    final larguraCard = (constraints.maxWidth - 39) / 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                      itemCount: widget.vm.itens.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 11,
                        mainAxisSpacing: 11,
                        childAspectRatio: larguraCard / alturaCard,
                      ),
                      itemBuilder: (_, index) {
                        final item = widget.vm.itens[index];
                        return _ItemCard(
                          categoria: widget.vm.categoria,
                          item: item,
                          ehVip: widget.vm.ehVip,
                          onPrincipal: () => _acaoPrincipal(item),
                          onPresentear: item.presenteavel
                              ? () => _abrirPresente(item)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              _navInferior(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onVoltar,
            icon: const Icon(Icons.chevron_left_rounded, color: _dourado, size: 32),
            tooltip: 'Voltar',
          ),
          Expanded(
            child: Text(
              widget.vm.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _douradoClaro,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _CarteiraChip(
            icone: '🪙',
            valor: widget.vm.moedas,
            onTap: widget.onComprarMoedas,
          ),
          const SizedBox(width: 6),
          _CarteiraChip(
            icone: '💎',
            valor: widget.vm.gemas,
            onTap: widget.onComprarMoedas,
          ),
        ],
      ),
    );
  }

  Widget _navInferior() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: Color(0x44EFB94A))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _navItem(NavDestino.inicio, Icons.home_rounded, 'Início', false),
            _navItem(NavDestino.loja, Icons.shopping_bag_rounded, 'Loja', true),
            _navItem(NavDestino.ranking, Icons.emoji_events_rounded, 'Ranking', false),
            _navItem(NavDestino.perfil, Icons.person_rounded, 'Perfil', false),
          ],
        ),
      ),
    );
  }

  Widget _navItem(NavDestino destino, IconData icone, String label, bool ativo) {
    return Expanded(
      child: InkWell(
        onTap: () => widget.onNav(destino),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: ativo ? _dourado : Colors.white30, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: ativo ? _dourado : Colors.white30,
                  fontSize: 10.5,
                  fontWeight: ativo ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LojaCosmeticosScreen extends StatelessWidget {
  final int moedas;
  final int gemas;
  final ValueChanged<LojaCategoria> onAbrirCategoria;
  final VoidCallback onComprarMoedas;
  final ValueChanged<NavDestino> onNav;

  const LojaCosmeticosScreen({
    super.key,
    required this.moedas,
    required this.gemas,
    required this.onAbrirCategoria,
    required this.onComprarMoedas,
    required this.onNav,
  });

  static const _dourado = Color(0xFFEFB94A);
  static const _douradoClaro = Color(0xFFF6E2A6);

  @override
  Widget build(BuildContext context) {
    final categorias = LojaCategoria.values;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF251713), Color(0xFF120A06), Colors.black],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOJA VIP',
                            style: TextStyle(
                              color: _douradoClaro,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'COSMÉTICOS',
                            style: TextStyle(
                              color: _dourado,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CarteiraChip(icone: '🪙', valor: moedas, onTap: onComprarMoedas),
                    const SizedBox(width: 6),
                    _CarteiraChip(icone: '💎', valor: gemas, onTap: onComprarMoedas),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Personalize sua experiência e equipe seus favoritos.',
                    style: TextStyle(color: Color(0xFFC9BA99), fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: categorias.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                    childAspectRatio: .83,
                  ),
                  itemBuilder: (_, index) {
                    final categoria = categorias[index];
                    return _CategoriaCard(
                      categoria: categoria,
                      onTap: () => onAbrirCategoria(categoria),
                    );
                  },
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0805),
                  border: Border(top: BorderSide(color: Color(0x44EFB94A))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      _LojaNavItem(
                        icon: Icons.home_rounded,
                        label: 'Início',
                        onTap: () => onNav(NavDestino.inicio),
                      ),
                      _LojaNavItem(
                        icon: Icons.shopping_bag_rounded,
                        label: 'Loja',
                        ativo: true,
                        onTap: () => onNav(NavDestino.loja),
                      ),
                      _LojaNavItem(
                        icon: Icons.emoji_events_rounded,
                        label: 'Ranking',
                        onTap: () => onNav(NavDestino.ranking),
                      ),
                      _LojaNavItem(
                        icon: Icons.person_rounded,
                        label: 'Perfil',
                        onTap: () => onNav(NavDestino.perfil),
                      ),
                    ],
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

class _CategoriaCard extends StatelessWidget {
  final LojaCategoria categoria;
  final VoidCallback onTap;

  const _CategoriaCard({required this.categoria, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C130C),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x55EFB94A)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    categoria.assetDestaque,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      categoria.icone,
                      style: const TextStyle(fontSize: 58),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                categoria.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF6E2A6),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver coleção',
                    style: TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded, color: Color(0xFFEFB94A), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final LojaCategoria categoria;
  final ItemCosmetico item;
  final bool ehVip;
  final VoidCallback onPrincipal;
  final VoidCallback? onPresentear;

  const _ItemCard({
    required this.categoria,
    required this.item,
    required this.ehVip,
    required this.onPrincipal,
    required this.onPresentear,
  });

  Color get _raridadeCor {
    switch (item.raridade) {
      case Raridade.comum:
        return const Color(0xFFB7AA92);
      case Raridade.raro:
        return const Color(0xFF5EA8FF);
      case Raridade.epico:
        return const Color(0xFFB98BFF);
      case Raridade.lendario:
        return const Color(0xFFEFB94A);
      case Raridade.vip:
        return const Color(0xFFF6E2A6);
    }
  }

  String get _raridadeLabel {
    switch (item.raridade) {
      case Raridade.comum:
        return 'COMUM';
      case Raridade.raro:
        return 'RARO';
      case Raridade.epico:
        return 'ÉPICO';
      case Raridade.lendario:
        return 'LENDÁRIO';
      case Raridade.vip:
        return 'VIP';
    }
  }

  String get _acaoLabel {
    switch (item.estado) {
      case ItemEstado.bloqueado:
        return item.soVip && !ehVip ? 'Só VIP' : 'Bloqueado';
      case ItemEstado.disponivel:
        return 'Comprar';
      case ItemEstado.comprado:
        return categoria == LojaCategoria.emojis ? 'Comprado' : 'Equipar';
      case ItemEstado.equipado:
        return '✓ Equipado';
    }
  }

  Color get _acaoFundo {
    switch (item.estado) {
      case ItemEstado.bloqueado:
        return Colors.white10;
      case ItemEstado.disponivel:
        return const Color(0xFFE4B144);
      case ItemEstado.comprado:
        return const Color(0xFF54348A);
      case ItemEstado.equipado:
        return const Color(0xFF2F7747);
    }
  }

  Color get _acaoTexto => item.estado == ItemEstado.disponivel
      ? const Color(0xFF3A2606)
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    final bloqueado = item.estado == ItemEstado.bloqueado;
    final equipado = item.estado == ItemEstado.equipado;

    return Opacity(
      opacity: bloqueado ? .58 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C130C),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: equipado ? _raridadeCor : _raridadeCor.withOpacity(.5),
            width: equipado ? 2 : 1,
          ),
          boxShadow: equipado
              ? [BoxShadow(color: _raridadeCor.withOpacity(.22), blurRadius: 12)]
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: BoxDecoration(
                  color: _raridadeCor.withOpacity(.14),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _raridadeCor.withOpacity(.55)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  _raridadeLabel,
                  style: TextStyle(
                    color: _raridadeCor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(child: _previa()),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    item.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF6E2A6),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (item.soVip) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFB94A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        color: Color(0xFF3A2606),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            if (item.estado == ItemEstado.disponivel)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.moeda == MoedaTipo.moedas ? '🪙' : '💎'),
                  const SizedBox(width: 3),
                  Text(
                    _formatarNumero(item.preco),
                    style: const TextStyle(
                      color: Color(0xFFF0D99A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 18),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: onPrincipal,
                      style: FilledButton.styleFrom(
                        backgroundColor: _acaoFundo,
                        foregroundColor: _acaoTexto,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        bloqueado ? '🔒 $_acaoLabel' : _acaoLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                if (onPresentear != null) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 43,
                    height: 34,
                    child: OutlinedButton(
                      onPressed: onPresentear,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Color(0x99B98BFF), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('🎁', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previa() {
    Widget imagem = Image.asset(
      item.previa,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded),
    );

    switch (categoria) {
      case LojaCategoria.dorsos:
        return Center(
          child: SizedBox(width: 68, height: 98, child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: imagem,
          )),
        );
      case LojaCategoria.molduras:
        return Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF4A2F0A), Color(0xFF171007)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('👑', style: TextStyle(fontSize: 27)),
                ),
                Positioned.fill(child: imagem),
              ],
            ),
          ),
        );
      case LojaCategoria.avatares:
        return Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66EFB94A), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagem,
          ),
        );
      case LojaCategoria.mascotes:
      case LojaCategoria.efeitos:
      case LojaCategoria.emojis:
        return Center(child: SizedBox(width: 100, height: 100, child: imagem));
    }
  }
}

class _CarteiraChip extends StatelessWidget {
  final String icone;
  final int valor;
  final VoidCallback onTap;

  const _CarteiraChip({required this.icone, required this.valor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(.34),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x44EFB94A)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icone, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                _formatarNumero(valor),
                style: const TextStyle(
                  color: Color(0xFFF6E2A6),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.add_circle_rounded, color: Color(0xFFEFB94A), size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompraSheet extends StatelessWidget {
  final ItemCosmetico item;
  final int saldo;
  final VoidCallback onConfirmar;

  const _CompraSheet({required this.item, required this.saldo, required this.onConfirmar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241708), Color(0xFF140B04)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0x99EFB94A), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Confirmar compra',
                    style: TextStyle(
                      color: Color(0xFFF6E2A6),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Revise antes de comprar:',
                style: TextStyle(color: Color(0xFFC9BA99), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33EFB94A)),
              ),
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  SizedBox(width: 64, height: 64, child: Image.asset(item.previa, fit: BoxFit.contain)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nome,
                          style: const TextStyle(
                            color: Color(0xFFF6E2A6),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.moeda == MoedaTipo.moedas ? '🪙' : '💎'} ${_formatarNumero(item.preco)}',
                          style: const TextStyle(color: Color(0xFFF0D99A), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seu saldo: 🪙 ${_formatarNumero(saldo)}',
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onConfirmar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE4B144),
                  foregroundColor: const Color(0xFF3A2606),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('Comprar agora', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenteSheet extends StatelessWidget {
  final ItemCosmetico item;
  final List<AmigoPresente> amigos;
  final String? amigoSelecionado;
  final ValueChanged<String> onBusca;
  final ValueChanged<String> onSelecionar;
  final VoidCallback? onEnviar;

  const _PresenteSheet({
    required this.item,
    required this.amigos,
    required this.amigoSelecionado,
    required this.onBusca,
    required this.onSelecionar,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final alturaMaxima = MediaQuery.of(context).size.height * .78;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1236), Color(0xFF120A1E)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: Color(0x99B98BFF), width: 1.5)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '🎁 Presentear · ${item.nome}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE6D0FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Busque o jogador que vai receber 💜',
                  style: TextStyle(color: Color(0xFFC3B0E8), fontSize: 12),
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                onChanged: onBusca,
                decoration: InputDecoration(
                  hintText: 'Buscar jogador pelo nome ou ID...',
                  hintStyle: const TextStyle(color: Color(0xFF8A7CA8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC3B0E8)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(.26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x55B98BFF), width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB98BFF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: amigos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Nenhum jogador encontrado 🔎',
                            style: TextStyle(color: Color(0xFF8A7CA8), fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: amigos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) {
                          final amigo = amigos[index];
                          final selecionado = amigo.id == amigoSelecionado;
                          return Material(
                            color: selecionado
                                ? const Color(0xFF241748)
                                : Colors.black.withOpacity(.22),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => onSelecionar(amigo.id),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selecionado
                                        ? const Color(0xFFB98BFF)
                                        : Colors.white12,
                                    width: 1.3,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF2A1C10),
                                        border: Border.all(color: const Color(0x55EFB94A)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(amigo.avatar, style: const TextStyle(fontSize: 17)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        amigo.nome,
                                        style: const TextStyle(
                                          color: Color(0xFFEFE3CC),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selecionado
                                            ? const Color(0xFFB98BFF)
                                            : Colors.transparent,
                                        border: Border.all(color: const Color(0x99B98BFF), width: 2),
                                      ),
                                      alignment: Alignment.center,
                                      child: selecionado
                                          ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF160F22))
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onEnviar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8A5CF0),
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('Enviar presente', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LojaNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  const _LojaNavItem({
    required this.icon,
    required this.label,
    this.ativo = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ativo ? const Color(0xFFEFB94A) : Colors.white30, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: ativo ? const Color(0xFFEFB94A) : Colors.white30,
                  fontSize: 10.5,
                  fontWeight: ativo ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatarNumero(int valor) {
  final texto = valor.toString();
  final partes = <String>[];
  for (var i = texto.length; i > 0; i -= 3) {
    final inicio = (i - 3).clamp(0, texto.length).toInt();
    partes.insert(0, texto.substring(inicio, i));
  }
  return partes.join('.');
}

List<ItemCosmetico> _catalogoMock(LojaCategoria categoria) {
  switch (categoria) {
    case LojaCategoria.dorsos:
      return const [
        ItemCosmetico(id: 'dorso_royal', nome: 'Royal', raridade: Raridade.comum, preco: 400, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/royal.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'dorso_diamante', nome: 'Diamante', raridade: Raridade.raro, preco: 600, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/diamante.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'dorso_elite', nome: 'Elite', raridade: Raridade.raro, preco: 800, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/elite.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'dorso_imperio', nome: 'Império', raridade: Raridade.lendario, preco: 1000, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/imperio.webp', estado: ItemEstado.equipado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'dorso_prestige', nome: 'Prestige', raridade: Raridade.epico, preco: 1200, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/prestige.webp', estado: ItemEstado.comprado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'dorso_luxo', nome: 'Luxo', raridade: Raridade.epico, preco: 1400, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/luxo.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'dorso_neon', nome: 'Neon', raridade: Raridade.epico, preco: 1600, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/neon.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'dorso_supremo', nome: 'Supremo', raridade: Raridade.vip, preco: 2000, moeda: MoedaTipo.moedas, previa: 'assets/loja/dorsos/supremo.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
    case LojaCategoria.molduras:
      return const [
        ItemCosmetico(id: 'moldura_realeza', nome: 'Realeza', raridade: Raridade.comum, preco: 600, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/realeza.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'moldura_ametista', nome: 'Ametista', raridade: Raridade.epico, preco: 900, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/ametista.webp', estado: ItemEstado.equipado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'moldura_fenix', nome: 'Fênix', raridade: Raridade.lendario, preco: 1200, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/fenix.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'moldura_neon', nome: 'Neon', raridade: Raridade.raro, preco: 800, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/neon.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'moldura_gelo_real', nome: 'Gelo Real', raridade: Raridade.epico, preco: 1500, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/gelo_real.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'moldura_ouro_velho', nome: 'Ouro Velho', raridade: Raridade.raro, preco: 700, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/ouro_velho.webp', estado: ItemEstado.comprado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'moldura_rubi', nome: 'Rubi', raridade: Raridade.lendario, preco: 1800, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/rubi.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'moldura_esmeralda', nome: 'Esmeralda', raridade: Raridade.lendario, preco: 2000, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/esmeralda.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'moldura_safira', nome: 'Safira', raridade: Raridade.lendario, preco: 2200, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/safira.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'moldura_perola_negra', nome: 'Pérola Negra', raridade: Raridade.vip, preco: 2500, moeda: MoedaTipo.moedas, previa: 'assets/loja/molduras/perola_negra.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
    case LojaCategoria.avatares:
      return const [
        ItemCosmetico(id: 'avatar_nobre', nome: 'Nobre', raridade: Raridade.comum, preco: 500, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/nobre.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'avatar_diva', nome: 'Diva', raridade: Raridade.raro, preco: 700, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/diva.webp', estado: ItemEstado.equipado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'avatar_magnata', nome: 'Magnata', raridade: Raridade.raro, preco: 900, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/magnata.webp', estado: ItemEstado.comprado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'avatar_duquesa', nome: 'Duquesa', raridade: Raridade.epico, preco: 1100, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/duquesa.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'avatar_barao', nome: 'Barão', raridade: Raridade.epico, preco: 1300, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/barao.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'avatar_condessa', nome: 'Condessa', raridade: Raridade.lendario, preco: 1500, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/condessa.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'avatar_lorde', nome: 'Lorde', raridade: Raridade.lendario, preco: 1800, moeda: MoedaTipo.moedas, previa: 'assets/loja/avatares/lorde.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'avatar_imperatriz', nome: 'Imperatriz', raridade: Raridade.vip, preco: 2200, moeda: MoedaTipo.gemas, previa: 'assets/loja/avatares/imperatriz.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
    case LojaCategoria.mascotes:
      return const [
        ItemCosmetico(id: 'mascote_coruja', nome: 'Coruja Jogadora', raridade: Raridade.comum, preco: 800, moeda: MoedaTipo.moedas, previa: 'assets/loja/mascotes/coruja_jogadora.webp', estado: ItemEstado.equipado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'mascote_gato', nome: 'Gato Malandro', raridade: Raridade.raro, preco: 1200, moeda: MoedaTipo.moedas, previa: 'assets/loja/mascotes/gato_malandro.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'mascote_bulldog', nome: 'Bulldog de Óculos', raridade: Raridade.epico, preco: 1800, moeda: MoedaTipo.moedas, previa: 'assets/loja/mascotes/bulldog_de_oculos.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'mascote_macaco', nome: 'Macaco Trapaceiro', raridade: Raridade.epico, preco: 2500, moeda: MoedaTipo.moedas, previa: 'assets/loja/mascotes/macaco_trapaceiro.webp', estado: ItemEstado.comprado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'mascote_mini_curinga', nome: 'Mini-Curinga', raridade: Raridade.lendario, preco: 4000, moeda: MoedaTipo.moedas, previa: 'assets/loja/mascotes/mini_curinga.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'mascote_dragao', nome: 'Dragão de Cartas', raridade: Raridade.vip, preco: 6000, moeda: MoedaTipo.gemas, previa: 'assets/loja/mascotes/dragao_de_cartas.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
    case LojaCategoria.efeitos:
      return const [
        ItemCosmetico(id: 'efeito_explosao', nome: 'Explosão VIP', raridade: Raridade.raro, preco: 1000, moeda: MoedaTipo.moedas, previa: 'assets/loja/efeitos/explosao_vip.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'efeito_chuva_ouro', nome: 'Chuva de Ouro', raridade: Raridade.epico, preco: 1400, moeda: MoedaTipo.moedas, previa: 'assets/loja/efeitos/chuva_de_ouro.webp', estado: ItemEstado.equipado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'efeito_coroa', nome: 'Coroa Triunfal', raridade: Raridade.lendario, preco: 1800, moeda: MoedaTipo.moedas, previa: 'assets/loja/efeitos/coroa_triunfal.webp', estado: ItemEstado.comprado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'efeito_gelo', nome: 'Mesa Congelando', raridade: Raridade.epico, preco: 2200, moeda: MoedaTipo.moedas, previa: 'assets/loja/efeitos/mesa_congelando.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'efeito_chamas', nome: 'Cartas em Chamas', raridade: Raridade.lendario, preco: 2600, moeda: MoedaTipo.moedas, previa: 'assets/loja/efeitos/cartas_em_chamas.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'efeito_confete', nome: 'Confete Real', raridade: Raridade.vip, preco: 3000, moeda: MoedaTipo.gemas, previa: 'assets/loja/efeitos/confete_real.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
    case LojaCategoria.emojis:
      return const [
        ItemCosmetico(id: 'emoji_malandro', nome: 'Malandro', raridade: Raridade.comum, preco: 200, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/malandro.webp', estado: ItemEstado.comprado, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'emoji_gargalhada', nome: 'Gargalhada', raridade: Raridade.comum, preco: 250, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/gargalhada.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'emoji_apaixonado', nome: 'Apaixonado', raridade: Raridade.raro, preco: 300, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/apaixonado.webp', estado: ItemEstado.disponivel, soVip: false, presenteavel: true),
        ItemCosmetico(id: 'emoji_surpreso', nome: 'Surpreso', raridade: Raridade.raro, preco: 350, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/surpreso.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'emoji_pensativo', nome: 'Pensativo', raridade: Raridade.epico, preco: 400, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/pensativo.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'emoji_furioso', nome: 'Furioso', raridade: Raridade.epico, preco: 450, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/furioso.webp', estado: ItemEstado.comprado, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'emoji_triste', nome: 'Triste', raridade: Raridade.epico, preco: 500, moeda: MoedaTipo.moedas, previa: 'assets/loja/emojis/triste.webp', estado: ItemEstado.disponivel, soVip: true, presenteavel: true),
        ItemCosmetico(id: 'emoji_piscadinha', nome: 'Piscadinha', raridade: Raridade.vip, preco: 600, moeda: MoedaTipo.gemas, previa: 'assets/loja/emojis/piscadinha.webp', estado: ItemEstado.bloqueado, soVip: true, presenteavel: true),
      ];
  }
}
