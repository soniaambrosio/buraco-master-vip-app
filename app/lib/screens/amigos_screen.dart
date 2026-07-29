import 'package:flutter/material.dart';

// ============================================================================
// TELA AMIGOS — build do Claude (visual + lógica).
// Fase A: visual fiel ao amigos-preview.html (V2) + AmigosVM.mock() + callbacks.
// Fase B (com cloud_firestore): AmigosService com streams em tempo real,
// presença, código real e recompensa de convite. Ver PLANO-TELA-AMIGOS.md.
// ============================================================================

enum AmigosAba { online, todos, pedidos }

enum StatusAmigo { livre, naMesa, offline }

enum AmigosEstado { carregando, normal, erro }

enum RelacaoBusca { nenhuma, pedidoEnviado, jaAmigo, ehVoce }

class Amigo {
  final String id;
  final String apelido;
  final String avatar; // emoji por ora
  final int nivel;
  final StatusAmigo status;
  final String ultimoAcesso; // "agora" | "há 2 h" | "ontem" (aba Todos)
  final bool ehVoce; // fixa no topo em "Todos"

  const Amigo({
    required this.id,
    required this.apelido,
    this.avatar = '🙂',
    this.nivel = 1,
    this.status = StatusAmigo.offline,
    this.ultimoAcesso = '',
    this.ehVoce = false,
  });
}

class Pedido {
  final String id;
  final String apelido;
  final String avatar;
  final bool enviadoPorMim; // false = recebido (✓/✕) | true = enviado (só status)

  const Pedido({
    required this.id,
    required this.apelido,
    this.avatar = '🙂',
    this.enviadoPorMim = false,
  });
}

class ResultadoBusca {
  final String id;
  final String apelido;
  final String avatar;
  final int nivel;
  final bool online;
  final RelacaoBusca relacao;

  const ResultadoBusca({
    required this.id,
    required this.apelido,
    this.avatar = '🙂',
    this.nivel = 1,
    this.online = false,
    this.relacao = RelacaoBusca.nenhuma,
  });
}

class AmigosVM {
  final String meuCodigo; // "SONIA-RAINHA"
  final int recompensaConvite; // 500
  final AmigosAba aba;
  final List<Amigo> online;
  final List<Amigo> todos;
  final List<Pedido> pedidosRecebidos;
  final List<Pedido> pedidosEnviados;
  final String? termoBusca; // null/'' = abas normais; senão = modo busca
  final List<ResultadoBusca> resultados;
  final AmigosEstado estado;

  const AmigosVM({
    required this.meuCodigo,
    this.recompensaConvite = 500,
    this.aba = AmigosAba.online,
    this.online = const [],
    this.todos = const [],
    this.pedidosRecebidos = const [],
    this.pedidosEnviados = const [],
    this.termoBusca,
    this.resultados = const [],
    this.estado = AmigosEstado.normal,
  });

  bool get emBusca => (termoBusca ?? '').trim().isNotEmpty;

  AmigosVM copyWith({
    String? meuCodigo,
    int? recompensaConvite,
    AmigosAba? aba,
    List<Amigo>? online,
    List<Amigo>? todos,
    List<Pedido>? pedidosRecebidos,
    List<Pedido>? pedidosEnviados,
    String? termoBusca,
    List<ResultadoBusca>? resultados,
    AmigosEstado? estado,
  }) {
    return AmigosVM(
      meuCodigo: meuCodigo ?? this.meuCodigo,
      recompensaConvite: recompensaConvite ?? this.recompensaConvite,
      aba: aba ?? this.aba,
      online: online ?? this.online,
      todos: todos ?? this.todos,
      pedidosRecebidos: pedidosRecebidos ?? this.pedidosRecebidos,
      pedidosEnviados: pedidosEnviados ?? this.pedidosEnviados,
      termoBusca: termoBusca ?? this.termoBusca,
      resultados: resultados ?? this.resultados,
      estado: estado ?? this.estado,
    );
  }

  // Zera o termo de busca (copyWith não consegue setar null).
  AmigosVM semBusca() => AmigosVM(
        meuCodigo: meuCodigo,
        recompensaConvite: recompensaConvite,
        aba: aba,
        online: online,
        todos: todos,
        pedidosRecebidos: pedidosRecebidos,
        pedidosEnviados: pedidosEnviados,
        termoBusca: null,
        resultados: const [],
        estado: estado,
      );

  // Mock que bate com o amigos-preview.html (marcado pra o Claude substituir na Fase B).
  factory AmigosVM.mock({AmigosAba aba = AmigosAba.online}) {
    return AmigosVM(
      meuCodigo: 'SONIA-RAINHA',
      recompensaConvite: 500,
      aba: aba,
      online: const [
        Amigo(id: 'claudia', apelido: 'Cláudia', avatar: '🐰', nivel: 18, status: StatusAmigo.livre),
        Amigo(id: 'beto', apelido: 'Beto', avatar: '🦊', nivel: 25, status: StatusAmigo.naMesa),
        Amigo(id: 'fernanda', apelido: 'Fernanda', avatar: '🐶', nivel: 12, status: StatusAmigo.livre),
      ],
      todos: const [
        Amigo(id: 'voce', apelido: 'Você', avatar: '👑', nivel: 24, status: StatusAmigo.livre, ultimoAcesso: 'agora', ehVoce: true),
        Amigo(id: 'claudia', apelido: 'Cláudia', avatar: '🐰', nivel: 18, status: StatusAmigo.livre, ultimoAcesso: 'agora'),
        Amigo(id: 'beto', apelido: 'Beto', avatar: '🦊', nivel: 25, status: StatusAmigo.naMesa, ultimoAcesso: 'agora'),
        Amigo(id: 'fernanda', apelido: 'Fernanda', avatar: '🐶', nivel: 12, status: StatusAmigo.livre, ultimoAcesso: 'agora'),
        Amigo(id: 'mateus', apelido: 'Mateus', avatar: '🐻', nivel: 20, status: StatusAmigo.offline, ultimoAcesso: 'há 2 h'),
        Amigo(id: 'sofia', apelido: 'Sofia', avatar: '🐱', nivel: 15, status: StatusAmigo.offline, ultimoAcesso: 'ontem'),
      ],
      pedidosRecebidos: const [
        Pedido(id: 'larissa', apelido: 'Larissa', avatar: '🐱'),
        Pedido(id: 'ricardo', apelido: 'Ricardo', avatar: '🐻'),
      ],
      pedidosEnviados: const [
        Pedido(id: 'joao', apelido: 'João', avatar: '🐼', enviadoPorMim: true),
      ],
    );
  }
}

class AmigosScreen extends StatelessWidget {
  // paleta (do amigos-preview.html)
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);
  static const _verde = Color(0xFF8FE0B0);

  final AmigosVM vm;
  final VoidCallback onVoltar;
  final VoidCallback onCopiarCodigo;
  final VoidCallback onConvidarLink;
  final ValueChanged<String> onBuscar;
  final ValueChanged<String> onEnviarPedido;
  final void Function(String id, bool aceitar) onResponderPedido;
  final ValueChanged<AmigosAba> onTrocarAba;
  final ValueChanged<String> onConvidar;
  final ValueChanged<String> onAssistir;
  final ValueChanged<String> onAbrirAmigo;
  final VoidCallback onRecarregar;

  const AmigosScreen({
    super.key,
    required this.vm,
    required this.onVoltar,
    required this.onCopiarCodigo,
    required this.onConvidarLink,
    required this.onBuscar,
    required this.onEnviarPedido,
    required this.onResponderPedido,
    required this.onTrocarAba,
    required this.onConvidar,
    required this.onAssistir,
    required this.onAbrirAmigo,
    required this.onRecarregar,
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
                  _topBar(),
                  Expanded(
                    child: vm.estado == AmigosEstado.erro
                        ? _erro()
                        : RefreshIndicator(
                            color: _gold,
                            backgroundColor: _card,
                            onRefresh: () async => onRecarregar(),
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 20),
                              children: [
                                _cardConvite(),
                                _busca(),
                                if (!vm.emBusca) _tabs(),
                                const SizedBox(height: 6),
                                ..._conteudo(),
                              ],
                            ),
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

  // -------------------- top bar --------------------
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onVoltar,
            icon: const Icon(Icons.chevron_left, color: _gold, size: 30),
            splashRadius: 22,
          ),
          const Text(
            'Amigos',
            style: TextStyle(color: _goldHi, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // -------------------- card de convite --------------------
  Widget _cardConvite() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66EFB94A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Convide um amigo 🎉',
              style: TextStyle(color: _goldHi, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('vocês dois ganham quando ele jogar a 1ª partida',
              style: TextStyle(color: Color(0xFFD9C79A), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x55000000),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x66EFB94A)),
                  ),
                  child: Text(
                    vm.meuCodigo,
                    style: const TextStyle(
                        color: _goldHi, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                label: 'Copiar',
                onTap: onCopiarCodigo,
                bg: _gold,
                fg: const Color(0xFF3A2606),
              ),
            ],
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: onConvidarLink,
            child: Text('🪙 Ganhe ${vm.recompensaConvite} moedas por amigo',
                style: const TextStyle(color: _verde, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required VoidCallback onTap, required Color bg, required Color fg}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // -------------------- busca --------------------
  Widget _busca() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borda),
      ),
      child: TextField(
        onChanged: onBuscar,
        style: const TextStyle(color: _texto, fontSize: 13),
        cursorColor: _gold,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: InputBorder.none,
          icon: Padding(padding: EdgeInsets.only(left: 12), child: Text('🔍', style: TextStyle(fontSize: 13))),
          hintText: 'Buscar por apelido ou código…',
          hintStyle: TextStyle(color: Color(0xFF8A7C5E), fontSize: 13),
        ),
      ),
    );
  }

  // -------------------- abas --------------------
  Widget _tabs() {
    Widget tab(AmigosAba a, String label, int badge) {
      final on = vm.aba == a;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTrocarAba(a),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: on
                  ? const LinearGradient(colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)])
                  : null,
              color: on ? null : const Color(0x40000000),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: on ? Colors.transparent : const Color(0x12FFFFFF)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: on ? const Color(0xFF3A2606) : const Color(0xFFB6A884),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -10,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: const Color(0xFF9C302E), borderRadius: BorderRadius.circular(7)),
                      child: Text('$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        children: [
          tab(AmigosAba.online, 'Online', 0),
          tab(AmigosAba.todos, 'Todos', 0),
          tab(AmigosAba.pedidos, 'Pedidos', vm.pedidosRecebidos.length),
        ],
      ),
    );
  }

  // -------------------- conteúdo (por aba / busca) --------------------
  List<Widget> _conteudo() {
    if (vm.emBusca) return _conteudoBusca();
    switch (vm.aba) {
      case AmigosAba.online:
        return _abaOnline();
      case AmigosAba.todos:
        return _abaTodos();
      case AmigosAba.pedidos:
        return _abaPedidos();
    }
  }

  List<Widget> _conteudoBusca() {
    if (vm.resultados.isEmpty) {
      return [_vazio('Ninguém encontrado com “${vm.termoBusca}”.', 'Confira o apelido ou o código do parceiro.')];
    }
    return [
      _secTitulo('RESULTADOS'),
      ...vm.resultados.map(_rowResultado),
    ];
  }

  List<Widget> _abaOnline() {
    if (vm.online.isEmpty) {
      return [_vazio('Nenhum amigo online agora.', 'Convide a galera pelo seu código lá em cima 👆')];
    }
    return [
      _secTitulo('ONLINE AGORA'),
      ...vm.online.map(_rowOnline),
    ];
  }

  List<Widget> _abaTodos() {
    if (vm.todos.isEmpty) {
      return [_vazio('Você ainda não tem amigos.', 'Busque pelo apelido ou código pra adicionar.')];
    }
    return [
      _secTitulo('TODOS OS AMIGOS'),
      ...vm.todos.map(_rowTodos),
    ];
  }

  List<Widget> _abaPedidos() {
    final rec = vm.pedidosRecebidos;
    final env = vm.pedidosEnviados;
    if (rec.isEmpty && env.isEmpty) {
      return [_vazio('Nenhum pedido por aqui.', 'Quando alguém te adicionar, aparece nesta aba.')];
    }
    return [
      if (rec.isNotEmpty) _secTitulo('SOLICITAÇÕES (${rec.length})'),
      ...rec.map(_rowPedidoRecebido),
      if (env.isNotEmpty) _secTitulo('PEDIDOS ENVIADOS'),
      ...env.map(_rowPedidoEnviado),
    ];
  }

  // -------------------- linhas --------------------
  Widget _rowBase({required Widget avatar, required Widget meio, Widget? fim}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x10FFFFFF)),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(child: meio),
          if (fim != null) ...[const SizedBox(width: 8), fim],
        ],
      ),
    );
  }

  Widget _avatar(String emoji, {StatusAmigo? status}) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1C10),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x55EFB94A), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          if (status != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _corStatus(status),
                  shape: BoxShape.circle,
                  border: Border.all(color: _card, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _corStatus(StatusAmigo s) {
    switch (s) {
      case StatusAmigo.livre:
        return const Color(0xFF4BD07A);
      case StatusAmigo.naMesa:
        return const Color(0xFFE0953A);
      case StatusAmigo.offline:
        return const Color(0xFF666666);
    }
  }

  Widget _nome(String n) => Text(n,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _texto, fontSize: 13.5, fontWeight: FontWeight.w700));

  Widget _rowOnline(Amigo a) {
    final livre = a.status == StatusAmigo.livre;
    return _rowBase(
      avatar: _avatar(a.avatar, status: a.status),
      meio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nome(a.apelido),
          Text(livre ? '● Livre' : '● Numa mesa',
              style: TextStyle(
                  color: livre ? const Color(0xFF7FE0A3) : const Color(0xFFEFB46A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
      fim: livre
          ? _pill(label: 'Convidar', onTap: () => onConvidar(a.id), bg: const Color(0xFFE0A83A), fg: const Color(0xFF3A2606))
          : GestureDetector(
              onTap: () => onAssistir(a.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x99EFB46A), width: 1.3),
                ),
                child: const Text('🔒 Assistir',
                    style: TextStyle(color: Color(0xFFEFB46A), fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ),
    );
  }

  Widget _rowTodos(Amigo a) {
    return _rowBase(
      avatar: _avatar(a.avatar, status: a.ehVoce ? null : a.status),
      meio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _nome(a.ehVoce ? '${a.apelido} (você)' : a.apelido)),
            ],
          ),
          Text(a.ehVoce ? 'seu código: ${vm.meuCodigo}' : _subTodos(a),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _mut, fontSize: 10.5)),
        ],
      ),
      fim: a.ehVoce
          ? null
          : GestureDetector(
              onTap: () => onAbrirAmigo(a.id),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('⋯', style: TextStyle(color: _mut, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
    );
  }

  String _subTodos(Amigo a) {
    switch (a.status) {
      case StatusAmigo.livre:
        return '● Online · livre';
      case StatusAmigo.naMesa:
        return '● Online · numa mesa';
      case StatusAmigo.offline:
        return 'visto ${a.ultimoAcesso}';
    }
  }

  Widget _rowResultado(ResultadoBusca r) {
    Widget acao;
    switch (r.relacao) {
      case RelacaoBusca.nenhuma:
        acao = _pill(label: 'Adicionar', onTap: () => onEnviarPedido(r.id), bg: const Color(0xFFE0A83A), fg: const Color(0xFF3A2606));
        break;
      case RelacaoBusca.pedidoEnviado:
        acao = const Text('Pedido enviado', style: TextStyle(color: _mut, fontSize: 11, fontWeight: FontWeight.w700));
        break;
      case RelacaoBusca.jaAmigo:
        acao = const Text('Amigo ✓', style: TextStyle(color: _verde, fontSize: 11, fontWeight: FontWeight.w700));
        break;
      case RelacaoBusca.ehVoce:
        acao = const SizedBox.shrink();
        break;
    }
    return _rowBase(
      avatar: _avatar(r.avatar, status: r.online ? StatusAmigo.livre : null),
      meio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nome(r.apelido),
          Text('Nível ${r.nivel}${r.online ? ' · online' : ''}',
              style: const TextStyle(color: _mut, fontSize: 10.5)),
        ],
      ),
      fim: acao,
    );
  }

  Widget _rowPedidoRecebido(Pedido p) {
    return _rowBase(
      avatar: _avatar(p.avatar),
      meio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nome(p.apelido),
          const Text('quer ser seu amigo', style: TextStyle(color: _mut, fontSize: 10.5)),
        ],
      ),
      fim: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconeAcao('✓', const Color(0xFF1E5C37), const Color(0xFF8FE0B0), () => onResponderPedido(p.id, true)),
          const SizedBox(width: 6),
          _iconeAcao('✕', const Color(0xFF3A1414), const Color(0xFFE07A6E), () => onResponderPedido(p.id, false)),
        ],
      ),
    );
  }

  Widget _rowPedidoEnviado(Pedido p) {
    return _rowBase(
      avatar: _avatar(p.avatar),
      meio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nome(p.apelido),
          const Text('aguardando resposta', style: TextStyle(color: _mut, fontSize: 10.5)),
        ],
      ),
      fim: const Text('enviado', style: TextStyle(color: _mut, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _iconeAcao(String s, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(s, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }

  // -------------------- utilitários --------------------
  Widget _secTitulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 7),
        child: Text(t,
            style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      );

  Widget _vazio(String titulo, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _texto, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mut, fontSize: 12)),
          ],
        ),
      );

  Widget _erro() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não consegui carregar seus amigos.',
                style: TextStyle(color: _texto, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _pill(label: 'Tentar de novo', onTap: onRecarregar, bg: _gold, fg: const Color(0xFF3A2606)),
          ],
        ),
      );
}
