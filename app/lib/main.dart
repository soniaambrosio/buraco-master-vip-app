import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pages/perfil_page.dart';
import 'screens/perfil_screen.dart' show NavDestino;
import 'screens/inicio_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/recompensas_screen.dart';
import 'screens/configurar_mesa_screen.dart';
import 'screens/resultado_partida_screen.dart';
import 'screens/amigos_screen.dart';
import 'screens/saguao_screen.dart';
import 'screens/configuracoes_screen.dart';
import 'screens/como_jogar_screen.dart';
import 'screens/loja_screen.dart';
import 'screens/splash_oficial_screen.dart';
import 'screens/preparando_partida_screen.dart';
import 'screens/hall_screen.dart';
import 'screens/onde_jogar_screen.dart';
import 'widgets/convite_vip.dart';

// Paleta da casa
const _dourado = Color(0xFFEFB94A);
const _douradoClaro = Color(0xFFF6E2A6);
const _fundoTopo = Color(0xFF241812);
const _fundoMeio = Color(0xFF120A06);
const _fundoBaixo = Color(0xFF000000);
const _cardBg = Color(0xFF1C130C);
const _cardBorda = Color(0x33EFB94A);

// Google Sign-In (serverClientId = Web client do Firebase)
final GoogleSignIn _gsi = GoogleSignIn(
  scopes: const ['email'],
  serverClientId:
      '203886484007-a5e1ob9b7uequoffj6u76h5vltici9a4.apps.googleusercontent.com',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ',
      appId: '1:203886484007:android:734aaa61ca5ca68b29cc02',
      messagingSenderId: '203886484007',
      projectId: 'buraco-master-vip',
      storageBucket: 'buraco-master-vip.firebasestorage.app',
    ),
  );
  runApp(const BuracoApp());
}

class BuracoApp extends StatelessWidget {
  const BuracoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buraco Master VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const SplashOficialScreen(
        proximaTela: _InicioPreviewHost(),
      ),
    );
  }
}

// ===================== SPLASH (abertura) =====================
class _Particula {
  double x, y, r, a, sp, ph, vy;
  bool big;
  _Particula(this.x, this.y, this.r, this.a, this.sp, this.ph, this.vy, this.big);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final List<_Particula> _ps = [];
  Size _size = Size.zero;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _elapsed = 0;
  double _tap = 0;
  bool _saiu = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  double _rr(double a, double b) => a + (b - a) * _rnd.nextDouble();

  void _semear(Size s) {
    _ps.clear();
    final n = (s.width * s.height / 9000).round().clamp(38, 72);
    for (var i = 0; i < n; i++) {
      _ps.add(_Particula(_rr(0, s.width), _rr(0, s.height), _rr(.6, 2.3),
          _rr(.25, .95), _rr(.7, 1.9), _rr(0, 6.283), _rr(-14, -4),
          _rnd.nextDouble() < 0.13));
    }
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    if (dt > 0.05) dt = 0.05;
    _last = elapsed;
    _elapsed += dt;
    final s = _size;
    if (s.width > 0) {
      if (_ps.isEmpty) _semear(s);
      for (final p in _ps) {
        p.ph += p.sp * dt * 2.4;
        p.y += p.vy * dt;
        if (p.y < -8) {
          p.y = s.height + 8;
          p.x = _rr(0, s.width);
        }
      }
    }
    if (_elapsed > 2.6 && _tap < 0.92) _tap = (_tap + dt).clamp(0.0, 0.92);
    if (_elapsed > 6.5) _entrar();
    if (mounted) setState(() {});
  }

  void _entrar() {
    if (_saiu) return;
    _saiu = true;
    _ticker.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) => const _InicioPreviewHost(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0704),
      body: GestureDetector(
        onTap: _entrar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/splash.jpg',
                fit: BoxFit.cover, alignment: Alignment.center),
            CustomPaint(painter: _PontinhosPainter(_ps), size: Size.infinite),
            Align(
              alignment: const Alignment(0, 0.92),
              child: Opacity(
                opacity: _tap,
                child: const Text(
                  'TOQUE PARA ENTRAR',
                  style: TextStyle(
                    color: Color(0xFFD6C49A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.8,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PontinhosPainter extends CustomPainter {
  final List<_Particula> ps;
  _PontinhosPainter(this.ps);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final tw = .5 + .5 * sin(p.ph);
      final al = (p.a * tw).clamp(0.0, 1.0);
      final rr = p.r * (p.big ? 2.3 : 1);
      final radius = rr * 4;
      final center = Offset(p.x, p.y);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final shader = RadialGradient(
        colors: [
          Color.fromRGBO(255, 242, 205, al),
          Color.fromRGBO(246, 226, 166, al * .5),
          const Color.fromRGBO(246, 226, 166, 0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);
      canvas.drawCircle(center, radius, Paint()..shader = shader);
      if (p.big && tw > .82) {
        final sp = Paint()
          ..color = Color.fromRGBO(255, 246, 215, al * .8)
          ..strokeWidth = .8;
        canvas.drawLine(Offset(p.x - rr * 5, p.y), Offset(p.x + rr * 5, p.y), sp);
        canvas.drawLine(Offset(p.x, p.y - rr * 5), Offset(p.x, p.y + rr * 5), sp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PontinhosPainter old) => true;
}

// ===================== INÍCIO — PRÉVIA VISUAL CODEX =====================
class _InicioPreviewHost extends StatefulWidget {
  const _InicioPreviewHost();

  @override
  State<_InicioPreviewHost> createState() => _InicioPreviewHostState();
}

class _InicioPreviewHostState extends State<_InicioPreviewHost> {
  InicioEstado _estado = InicioEstado.normal;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  void _abrirPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PerfilPage()),
    );
  }

  void _abrirRanking() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _RankingPreviewHost()),
    );
  }

  void _abrirMesa() {
    // JOGAR → Onde Jogar (seletor de mesa) → Configurar Mesa → Preparando → Mesa.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _OndeJogarPreviewHost()),
    );
  }

  void _abrirRecompensas() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _RecompensasPreviewHost()),
    );
  }

  void _abrirAmigos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AmigosPreviewHost()),
    );
  }

  void _abrirLobby() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _SaguaoPreviewHost()),
    );
  }

  void _abrirConfiguracoes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ConfiguracoesPreviewHost()),
    );
  }

  void _abrirComoJogar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ComoJogarPreviewHost()),
    );
  }

  void _abrirLoja() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _LojaPreviewHost()),
    );
  }

  void _menuTap(String id) {
    switch (id) {
      case 'perfil':
        _abrirPerfil();
        break;
      case 'ranking':
        _abrirRanking();
        break;
      case 'recompensas':
        _abrirRecompensas();
        break;
      case 'amigos':
        _abrirAmigos();
        break;
      case 'ajustes':
        _abrirConfiguracoes();
        break;
      case 'tutorial':
        _abrirComoJogar();
        break;
      case 'loja':
        _abrirLoja();
        break;
      case 'jogar':
        _abrirMesa();
        break;
      default:
        _aviso('$id — integração fica com o Claude');
    }
  }

  void _navTap(NavDestino destino) {
    switch (destino) {
      case NavDestino.inicio:
        break;
      case NavDestino.ranking:
        _abrirRanking();
        break;
      case NavDestino.loja:
        _abrirLoja();
        break;
      case NavDestino.perfil:
        _abrirPerfil();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InicioScreen(
      vm: InicioVM.mock(),
      estado: _estado,
      onJogar: _abrirMesa,
      onAbrirPerfil: _abrirPerfil,
      onHistorico: () => _aviso('Histórico — integração fica com o Claude'),
      onAbrirTemporada: () => _aviso('Temporada — integração fica com o Claude'),
      onAbrirLobby: _abrirLobby,
      onMenuTap: _menuTap,
      onRecarregar: () {
        setState(() => _estado = InicioEstado.carregando);
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _estado = InicioEstado.normal);
        });
      },
      onNavTap: _navTap,
    );
  }
}

// ===================== SAGUÃO / LOBBY (host) =====================
class _SaguaoPreviewHost extends StatefulWidget {
  const _SaguaoPreviewHost();

  @override
  State<_SaguaoPreviewHost> createState() => _SaguaoPreviewHostState();
}

class _SaguaoPreviewHostState extends State<_SaguaoPreviewHost> {
  SaguaoVM _vm = SaguaoVM.mock(sala: SalaSaguao.publico, ehVip: true);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1350),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  void _trocarSala(SalaSaguao sala) {
    setState(() {
      _vm = SaguaoVM.mock(sala: sala, ehVip: _vm.ehVip);
    });
  }

  void _enviar(String texto) {
    final mensagens = List<MsgSaguao>.of(_vm.mensagens)
      ..add(
        MsgSaguao(
          id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
          autor: 'Você',
          avatar: '',
          texto: texto,
          ehVoce: true,
          ehVip: _vm.sala == SalaSaguao.vip,
        ),
      );
    setState(() => _vm = _vm.copyWith(mensagens: mensagens));
  }

  void _presentearSalao(String presenteId) {
    PresenteVip? presente;
    for (final item in _vm.presentes) {
      if (item.id == presenteId) {
        presente = item;
        break;
      }
    }
    if (presente == null) return;
    _enviar('${presente.emoji} ${presente.nome} para o salão!');
    _aviso('${presente.nome} enviada — débito real fica com o Claude');
  }

  @override
  Widget build(BuildContext context) {
    return SaguaoScreen(
      vm: _vm,
      onVoltar: () => Navigator.of(context).pop(),
      onTrocarSala: _trocarSala,
      onVipBloqueado: () =>
          _aviso('Salão VIP — assinatura e gate ficam com o Claude'),
      onEnviarFala: (_, fala) => _enviar(fala),
      onEnviarEmoji: _enviar,
      onPresentearSalao: _presentearSalao,
      onPresentearJogador: (id) =>
          _aviso('Presente para $id — economia fica com o Claude'),
      onConvidar: (id) => _aviso('Convite para $id — ligação fica com o Claude'),
      onAssistir: (id) =>
          _aviso('Assistir $id — entrada como espectador fica com o Claude'),
      onEntrarMesa: (codigo) {
        _aviso('Entrando em $codigo — conexão real fica com o Claude');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MesaScreen()),
        );
      },
    );
  }
}

// ===================== AMIGOS (host) =====================
// Tela do Claude (visual + lógica). Fase A: mock navegável (busca/abas/pedidos
// funcionam sobre dados locais). Fase B: AmigosService + cloud_firestore em
// tempo real (presença, código real, recompensa de convite). Ver PLANO-TELA-AMIGOS.md.
class _AmigosPreviewHost extends StatefulWidget {
  const _AmigosPreviewHost();

  @override
  State<_AmigosPreviewHost> createState() => _AmigosPreviewHostState();
}

class _AmigosPreviewHostState extends State<_AmigosPreviewHost> {
  AmigosVM _vm = AmigosVM.mock();
  Timer? _debounce;

  // Diretório mock só pra a busca da Fase A ter o que devolver.
  // Fase B: substituído por query no Firestore (apelidoLower / codigo).
  static const List<ResultadoBusca> _diretorio = [
    ResultadoBusca(id: 'larissa', apelido: 'Larissa', avatar: '🐱', nivel: 9, online: true, relacao: RelacaoBusca.nenhuma),
    ResultadoBusca(id: 'ricardo', apelido: 'Ricardo', avatar: '🐻', nivel: 14, online: false, relacao: RelacaoBusca.nenhuma),
    ResultadoBusca(id: 'claudia', apelido: 'Cláudia', avatar: '🐰', nivel: 18, online: true, relacao: RelacaoBusca.jaAmigo),
    ResultadoBusca(id: 'joao', apelido: 'João', avatar: '🐼', nivel: 7, online: false, relacao: RelacaoBusca.pedidoEnviado),
    ResultadoBusca(id: 'paula', apelido: 'Paula', avatar: '🦉', nivel: 22, online: true, relacao: RelacaoBusca.nenhuma),
    ResultadoBusca(id: 'sonia', apelido: 'Sônia', avatar: '👑', nivel: 24, online: true, relacao: RelacaoBusca.ehVoce),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1300),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  void _buscar(String termo) {
    _debounce?.cancel();
    final t = termo.trim();
    if (t.isEmpty) {
      setState(() => _vm = _vm.semBusca());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final low = t.toLowerCase();
      final achados = _diretorio
          .where((r) => r.apelido.toLowerCase().contains(low) || vm_codigoBate(r, low))
          .toList();
      if (!mounted) return;
      setState(() => _vm = _vm.copyWith(termoBusca: t, resultados: achados));
    });
  }

  // Busca também pelo "código" (na Fase A só o próprio código bate; Fase B: código real por jogador).
  bool vm_codigoBate(ResultadoBusca r, String low) =>
      r.id == 'sonia' && _vm.meuCodigo.toLowerCase().contains(low);

  void _enviarPedido(String id) {
    setState(() {
      _vm = _vm.copyWith(
        resultados: _vm.resultados
            .map((r) => r.id == id
                ? ResultadoBusca(
                    id: r.id, apelido: r.apelido, avatar: r.avatar,
                    nivel: r.nivel, online: r.online, relacao: RelacaoBusca.pedidoEnviado)
                : r)
            .toList(),
      );
    });
    _aviso('Pedido enviado 🤝 (vira real com o Firestore — Fase B)');
  }

  void _responderPedido(String id, bool aceitar) {
    final pedido = _vm.pedidosRecebidos.firstWhere(
      (p) => p.id == id,
      orElse: () => const Pedido(id: '', apelido: ''),
    );
    final restantes = _vm.pedidosRecebidos.where((p) => p.id != id).toList();
    if (aceitar && pedido.id.isNotEmpty) {
      final novo = Amigo(
        id: pedido.id, apelido: pedido.apelido, avatar: pedido.avatar,
        status: StatusAmigo.livre, ultimoAcesso: 'agora',
      );
      setState(() {
        _vm = _vm.copyWith(
          pedidosRecebidos: restantes,
          online: [..._vm.online, novo],
          todos: [..._vm.todos, novo],
        );
      });
      _aviso('${pedido.apelido} agora é seu amigo! 🎉');
    } else {
      setState(() => _vm = _vm.copyWith(pedidosRecebidos: restantes));
      if (pedido.id.isNotEmpty) _aviso('Pedido de ${pedido.apelido} recusado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmigosScreen(
      vm: _vm,
      onVoltar: () => Navigator.of(context).pop(),
      onCopiarCodigo: () async {
        await Clipboard.setData(ClipboardData(text: _vm.meuCodigo));
        if (mounted) _aviso('Código ${_vm.meuCodigo} copiado');
      },
      onConvidarLink: () => _aviso('Compartilhar convite — integração fica com o Claude (Fase B)'),
      onBuscar: _buscar,
      onEnviarPedido: _enviarPedido,
      onResponderPedido: _responderPedido,
      onTrocarAba: (aba) => setState(() => _vm = _vm.copyWith(aba: aba)),
      onConvidar: (id) => _aviso('Convite pra mesa — integração fica com o Claude (Fase B)'),
      onAssistir: (id) => _aviso('Assistir a mesa — integração fica com o Claude (Fase B)'),
      onAbrirAmigo: (id) => _aviso('Opções do amigo — integração fica com o Claude (Fase B)'),
      onRecarregar: () => setState(() => _vm = AmigosVM.mock(aba: _vm.aba, ehVip: _vm.ehVip)),
      onAssinar: (plano) {
        // Fase B: aqui entra o Google Play Billing (assinatura recorrente real) +
        // a infra conta.vip / ehVip(). Ver ASSINATURA-VIP-INFRA.md.
        // No mock, "assinar" desbloqueia a prévia pra dar pra navegar a tela VIP.
        _aviso('Assinatura $plano — pagamento recorrente via Google Play (Fase B)');
        setState(() => _vm = _vm.copyWith(ehVip: true));
      },
    );
  }
}



// ===================== CONFIGURAÇÕES (host) =====================
class _ConfiguracoesPreviewHost extends StatefulWidget {
  const _ConfiguracoesPreviewHost();

  @override
  State<_ConfiguracoesPreviewHost> createState() =>
      _ConfiguracoesPreviewHostState();
}

class _ConfiguracoesPreviewHostState
    extends State<_ConfiguracoesPreviewHost> {
  ConfigVM _vm = ConfigVM.mock();

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1300),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _toggle(String id, bool valor) {
    setState(() {
      switch (id) {
        case 'musica':
          _vm = _vm.copyWith(musica: valor);
          break;
        case 'efeitos':
          _vm = _vm.copyWith(efeitos: valor);
          break;
        case 'vibracao':
          _vm = _vm.copyWith(vibracao: valor);
          break;
        case 'notificacoes':
          _vm = _vm.copyWith(notificacoes: valor);
          break;
        case 'animacoes':
          _vm = _vm.copyWith(animacoes: valor);
          break;
        case 'ordenarCartas':
          _vm = _vm.copyWith(ordenarCartas: valor);
          break;
        case 'mostrarOnline':
          _vm = _vm.copyWith(mostrarOnline: valor);
          break;
      }
    });
    _aviso('$id atualizado — persistência fica com o Claude');
  }

  void _abrirLoja() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _LojaPreviewHost()),
    );
  }

  void _abrirPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PerfilPage()),
    );
  }

  void _abrirComoJogar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ComoJogarPreviewHost()),
    );
  }

  Future<void> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C130C),
        title: const Text(
          'Sair da conta?',
          style: TextStyle(color: Color(0xFFF6E2A6)),
        ),
        content: const Text(
          'Você precisará entrar novamente para continuar jogando.',
          style: TextStyle(color: Color(0xFFD5C4A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8E2F2B),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair == true && mounted) {
      _aviso('Logout real fica com o Claude');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfiguracoesScreen(
      vm: _vm,
      onVoltar: () => Navigator.of(context).maybePop(),
      onEditarPerfil: _abrirPerfil,
      onAssinaturaVip: _abrirLoja,
      onMoedasCompras: _abrirLoja,
      onToggle: _toggle,
      onMao: (mao) {
        setState(() => _vm = _vm.copyWith(mao: mao));
        _aviso('Mão ${mao == MaoJogador.destro ? 'destro' : 'canhoto'}');
      },
      onQuemConvida: () {
        const opcoes = ['Amigos', 'Todos', 'Ninguém'];
        final atual = opcoes.indexOf(_vm.quemConvida);
        final proximo = opcoes[(atual + 1) % opcoes.length];
        setState(() => _vm = _vm.copyWith(quemConvida: proximo));
        _aviso('Convites: $proximo — lista real fica com o Claude');
      },
      onBloqueados: () =>
          _aviso('Jogadores bloqueados — integração fica com o Claude'),
      onComoJogar: _abrirComoJogar,
      onSuporte: () => _aviso('Suporte — canal real fica com o Claude'),
      onAvaliar: () =>
          _aviso('Google Play — abertura da loja fica com o Claude'),
      onSair: _confirmarSaida,
    );
  }
}

// ===================== COMO JOGAR (host) =====================
class _ComoJogarPreviewHost extends StatelessWidget {
  const _ComoJogarPreviewHost();

  @override
  Widget build(BuildContext context) {
    return ComoJogarScreen(
      onVoltar: () => Navigator.of(context).maybePop(),
      onJogarTreino: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino com 3 robôs — criação real fica com o Claude'),
            duration: Duration(milliseconds: 1300),
            backgroundColor: Color(0xFF2A1B0E),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MesaScreen()),
        );
      },
    );
  }
}


// ===================== LOJA VIP (host) =====================
class _LojaPreviewHost extends StatefulWidget {
  const _LojaPreviewHost();

  @override
  State<_LojaPreviewHost> createState() => _LojaPreviewHostState();
}

class _LojaPreviewHostState extends State<_LojaPreviewHost> {
  bool _ehVip = false;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1400),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _abrirRanking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const _RankingPreviewHost()),
    );
  }

  void _abrirPerfil() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PerfilPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LojaScreen(
      vm: LojaVM.mock(ehVip: _ehVip),
      onVoltar: () => Navigator.of(context).maybePop(),
      onNav: (destino) {
        switch (destino) {
          case NavDestino.inicio:
            Navigator.of(context).popUntil((route) => route.isFirst);
            break;
          case NavDestino.ranking:
            _abrirRanking();
            break;
          case NavDestino.loja:
            break;
          case NavDestino.perfil:
            _abrirPerfil();
            break;
        }
      },
      onComprarMoedas: () => _aviso('Pacotes de moedas'),
      onAssinar: (planoId) {
        _aviso('Plano $planoId selecionado — billing entra com o Claude');
        Future<void>.delayed(const Duration(milliseconds: 550), () {
          if (mounted) setState(() => _ehVip = true);
        });
      },
      onComprarPacote: (pacoteId) => _aviso('Revisando pacote $pacoteId'),
      onConfirmarCompra: (itemId) =>
          _aviso('Compra de $itemId — Google Play Billing entra com o Claude'),
      onAbrirCategoria: (categoria) =>
          _aviso('${categoria.name} — catálogo detalhado é o próximo contrato'),
      onPresentear: (itemId) => _aviso('Escolha um amigo para receber $itemId'),
      onBuscarPresenteado: (_) {},
      onEnviarPresente: (itemId, jogadorId) =>
          _aviso('Presente $itemId enviado para $jogadorId'),
    );
  }
}


// ===================== HALL DOS IMORTAIS (host) =====================
class _HallPreviewHost extends StatelessWidget {
  const _HallPreviewHost();

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return HallScreen(
      vm: HallVM.mock(),
      onVoltar: () => Navigator.of(context).maybePop(),
      onVerRegras: () {},
      onVerPerfil: (id) => _aviso(context, 'Abrir perfil: $id'),
      onPresentear: (id) {},
      onEnviarPresente: (id, presenteId) =>
          _aviso(context, 'Presente $presenteId enviado para $id'),
      onNav: (destino) {
        switch (destino) {
          case 'ranking':
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const _RankingPreviewHost()),
            );
            break;
          case 'perfil':
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PerfilPage()),
            );
            break;
          case 'estatisticas':
            _aviso(context, 'Minhas estatísticas — integração fica com o Claude');
            break;
          case 'presentes':
            _aviso(context, 'Inventário de presentes — integração fica com o Claude');
            break;
          default:
            break;
        }
      },
    );
  }
}


// ===================== ONDE JOGAR (host) =====================
class _OndeJogarPreviewHost extends StatelessWidget {
  const _OndeJogarPreviewHost();

  @override
  Widget build(BuildContext context) {
    return OndeJogarScreen(
      vm: OndeJogarVM.mock(),
      onVoltar: () => Navigator.of(context).maybePop(),
      onEscolher: (id) {
        if (id == 'treino') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MesaScreen()),
          );
          return;
        }
        final tipo = id == 'publica'
            ? TipoMesa.publica
            : id == 'vip'
                ? TipoMesa.vip
                : TipoMesa.privada;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ConfigMesaPreviewHost(tipoInicial: tipo)),
        );
      },
    );
  }
}

// ===================== RECOMPENSAS — PRÉVIA VISUAL CODEX =====================
class _RecompensasPreviewHost extends StatefulWidget {
  const _RecompensasPreviewHost();

  @override
  State<_RecompensasPreviewHost> createState() => _RecompensasPreviewHostState();
}

class _RecompensasPreviewHostState extends State<_RecompensasPreviewHost> {
  RecompensaEstado _estado = RecompensaEstado.normal;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RecompensasScreen(
      vm: RecompensasVM.mock(),
      estado: _estado,
      onVoltar: () => Navigator.of(context).pop(),
      onResgatarMissao: (id) => _aviso('Missão $id — resgate fica com o Claude'),
      onResgatarHoje: () => _aviso('Login diário — resgate fica com o Claude'),
      onAbrirBau: () => _aviso('Baú Real — integração fica com o Claude'),
      onFonteTap: (id) => _aviso('$id — integração fica com o Claude'),
      onRecarregar: () {
        setState(() => _estado = RecompensaEstado.carregando);
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _estado = RecompensaEstado.normal);
        });
      },
    );
  }
}

// ===================== CONFIGURAR MESA — PRÉVIA VISUAL CODEX =====================
class _ConfigMesaPreviewHost extends StatefulWidget {
  final TipoMesa tipoInicial;
  const _ConfigMesaPreviewHost({this.tipoInicial = TipoMesa.privada});

  @override
  State<_ConfigMesaPreviewHost> createState() => _ConfigMesaPreviewHostState();
}

class _ConfigMesaPreviewHostState extends State<_ConfigMesaPreviewHost> {
  late ConfigMesaVM _vm = ConfigMesaVM.mock(tipo: widget.tipoInicial);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1300),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  int get _jogadores => _vm.modo == ModoJogo.dois ? 2 : 4;

  String _modalidadeLabel(ModalidadeJogo modalidade) {
    switch (modalidade) {
      case ModalidadeJogo.aberto:
        return 'ABERTO';
      case ModalidadeJogo.fechado:
        return 'FECHADO';
      case ModalidadeJogo.sbtl:
        return 'STBL';
    }
  }

  ApostaVM? _apostaComPote(ApostaVM? aposta, {int? valor}) {
    if (aposta == null) return null;
    final novoValor = valor ?? aposta.valor;
    return aposta.copyWith(valor: novoValor, pote: novoValor * _jogadores);
  }

  void _trocarTipo(TipoMesa tipo) {
    setState(() {
      _vm = ConfigMesaVM.mock(tipo: tipo, ehVip: _vm.ehVip);
    });
  }

  void _trocarModo(ModoJogo modo) {
    setState(() {
      final jogadores = modo == ModoJogo.dois ? 2 : 4;
      final aposta = _vm.aposta;
      _vm = _vm.copyWith(
        modo: modo,
        aposta: aposta == null
            ? null
            : aposta.copyWith(pote: aposta.valor * jogadores),
      );
    });
  }

  void _alternarCadeira(String id) {
    final cadeiras = _vm.cadeiras;
    if (cadeiras == null) return;
    setState(() {
      _vm = _vm.copyWith(
        cadeiras: cadeiras.map((cadeira) {
          if (cadeira.id != id || !cadeira.podeAlternar) return cadeira;
          return cadeira.copyWith(
            estado: cadeira.estado == EstadoCadeira.travada
                ? EstadoCadeira.liberada
                : EstadoCadeira.travada,
          );
        }).toList(),
      );
    });
  }

  Future<void> _copiarCodigo() async {
    final codigo = _vm.codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (mounted) _aviso('Código $codigo copiado');
  }

  void _verRegras() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C130C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modalidades',
                style: TextStyle(
                  color: Color(0xFFEFB94A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 13),
              Text('Aberto — lixo à vista e compra livre.'),
              SizedBox(height: 8),
              Text('Fechado — compra justificada e aceita trinca.'),
              SizedBox(height: 8),
              Text('SBTL — sem trinca e bate somente com canastra limpa.'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConfigurarMesaScreen(
      vm: _vm,
      onVoltar: () => Navigator.of(context).pop(),
      onTipo: _trocarTipo,
      onTipoBloqueado: (tipo) =>
          _aviso('${tipo.name.toUpperCase()} é exclusivo para jogador VIP'),
      onModalidade: (value) => setState(() => _vm = _vm.copyWith(modalidade: value)),
      onVerRegras: _verRegras,
      onModo: _trocarModo,
      onPontos: (value) => setState(() => _vm = _vm.copyWith(pontos: value)),
      onAposta: (value) => setState(() {
        _vm = _vm.copyWith(aposta: _apostaComPote(_vm.aposta, valor: value));
      }),
      onTempo: (value) => setState(() => _vm = _vm.copyWith(tempo: value)),
      onChat: (value) => setState(() => _vm = _vm.copyWith(chat: value)),
      onEspectadores: (value) =>
          setState(() => _vm = _vm.copyWith(espectadores: value)),
      onCopiar: _copiarCodigo,
      onAlternarCadeira: _alternarCadeira,
      onCriarMesa: () {
        // Dono cria a mesa → tela "Preparando partida" (cadeiras enchendo) →
        // ao concluir, abre a MesaScreen jogável com a config escolhida.
        final variant = _vm.tipo == TipoMesa.publica
            ? MesaVariant.publica
            : MesaVariant.vip;
        final modalidade = _modalidadeLabel(_vm.modalidade);
        final metaPontos = _vm.pontos;
        final tempo = _vm.tempo;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreparandoPartidaScreen(
              vm: PreparandoPartidaVM.mock(ehVip: _vm.ehVip),
              onConcluido: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => MesaScreen(
                      variant: variant,
                      modalidade: modalidade,
                      metaPontos: metaPontos,
                      tempoSegundos: tempo,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ===================== INÍCIO (menu) =====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _banner = true;
  User? _user;
  bool _entrando = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  void _abrirPerfil() {
    // Fase 1 da colaboração: a UI é do Codex (PerfilScreen); o carregamento de
    // dados, estados e callbacks reais vivem no PerfilPage (Claude).
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PerfilPage(),
      ),
    );
  }

  void _abrirRanking() {
    // Prévia visual do contrato RankingVM. O Claude substitui este host pelo
    // RankingPage/RankingService quando conectar os dados reais.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _RankingPreviewHost(),
      ),
    );
  }

  void _abrirRecompensas() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _RecompensasPreviewHost(),
      ),
    );
  }

  void _breve(String o) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$o — chega nas próximas fatias 👍'),
        duration: const Duration(milliseconds: 1300),
        backgroundColor: const Color(0xFF2A1B0E),
      ),
    );
  }

  Future<void> _entrarGoogle() async {
    setState(() => _entrando = true);
    try {
      final acc = await _gsi.signIn();
      if (acc == null) {
        setState(() => _entrando = false);
        return;
      }
      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
          idToken: auth.idToken, accessToken: auth.accessToken);
      await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui entrar: $e')),
        );
      }
    }
    if (mounted) setState(() => _entrando = false);
  }

  Future<void> _sair() async {
    try {
      await _gsi.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_fundoTopo, _fundoMeio, _fundoBaixo],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      const Text('👑', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 6),
                      const Text('BURACO MASTER VIP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _dourado,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))])),
                      const SizedBox(height: 4),
                      const Text('o buraco como se joga na vida real',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 18),
                      _cardPerfil(),
                      if (_banner && _user != null) ...[
                        const SizedBox(height: 12),
                        _bannerBoasVindas(),
                      ],
                      const SizedBox(height: 12),
                      _cardTemporada(),
                      const SizedBox(height: 16),
                      _botaoJogar(),
                      const SizedBox(height: 22),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('MENU',
                            style: TextStyle(
                                color: _dourado,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                      ),
                      const SizedBox(height: 12),
                      _grade(),
                    ],
                  ),
                ),
              ),
              _bottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardDeco => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorda),
      );

  Widget _cardPerfil() {
    final u = _user;
    if (u == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          children: [
            const Text('🔐', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            const Text('Entre com sua conta Google',
                style: TextStyle(color: _dourado, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('pra salvar seu progresso e jogar online',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _entrando ? null : _entrarGoogle,
                icon: _entrando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A2606)))
                    : const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF3A2606))),
                label: const Text('Entrar com Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dourado,
                  foregroundColor: const Color(0xFF3A2606),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3A2606),
              border: Border.all(color: _dourado, width: 2),
              image: u.photoURL != null
                  ? DecorationImage(image: NetworkImage(u.photoURL!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: u.photoURL == null
                ? const Text('👑', style: TextStyle(fontSize: 28))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.displayName ?? 'Jogador(a)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _dourado, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(u.email ?? 'conectado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                const Text('🪙 1.000  ·  Liga Diamante',
                    style: TextStyle(color: _douradoClaro, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            onPressed: _sair,
            tooltip: 'Sair',
            icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _bannerBoasVindas() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14301E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x5540C070)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '🎉 '),
                TextSpan(text: 'Login de verdade funcionando! ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                TextSpan(text: 'sua conta Google está conectada.', style: TextStyle(color: Colors.white70)),
              ]),
              style: TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _banner = false),
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _cardTemporada() {
    return InkWell(
      onTap: () => _breve('Temporadas'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55EFB94A), width: 1.2),
        ),
        child: Row(
          children: [
            const Text('🎄', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Próxima temporada: Natal',
                      style: TextStyle(color: _dourado, fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('começa em 134 dias — já dá pra se preparar!',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _dourado),
          ],
        ),
      ),
    );
  }

  Widget _botaoJogar() {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const _ConfigMesaPreviewHost())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _dourado.withOpacity(0.45), blurRadius: 26, spreadRadius: 1)],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🃏  ', style: TextStyle(fontSize: 22)),
            Text('Jogar',
                style: TextStyle(color: Color(0xFF3A2606), fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _grade() {
    final itens = <List<String>>[
      ['👤', 'Perfil'], ['🏆', 'Ranking'], ['🎁', 'Recompensas'], ['👥', 'Amigos'],
      ['🛍️', 'Loja VIP'], ['🎲', 'Jogar'], ['📖', 'Como jogar'], ['⚙️', 'Ajustes'],
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.86,
      children: itens.map((it) => _tile(it[0], it[1])).toList(),
    );
  }

  Widget _tile(String emoji, String label) {
    return GestureDetector(
      onTap: label == 'Perfil'
          ? _abrirPerfil
          : label == 'Ranking'
              ? _abrirRanking
              : label == 'Recompensas'
                  ? _abrirRecompensas
                  : label == 'Jogar'
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const _ConfigMesaPreviewHost(),
                            ),
                          )
                      : () => _breve(label),
      child: Container(
        decoration: _cardDeco,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav() {
    Widget item(
      String emoji,
      String label,
      bool ativo, {
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        color: ativo ? _dourado : Colors.white38,
                        fontSize: 11,
                        fontWeight: ativo ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: _cardBorda)),
      ),
      child: Row(
        children: [
          item('🏠', 'Início', true),
          item('🏆', 'Ranking', false, onTap: _abrirRanking),
          item('🛍️', 'Loja', false, onTap: () => _breve('Loja VIP')),
          item('👤', 'Perfil', false, onTap: _abrirPerfil),
        ],
      ),
    );
  }
}

// ===================== RANKING — PRÉVIA VISUAL CODEX =====================
class _RankingPreviewHost extends StatefulWidget {
  const _RankingPreviewHost();

  @override
  State<_RankingPreviewHost> createState() => _RankingPreviewHostState();
}

class _RankingPreviewHostState extends State<_RankingPreviewHost> {
  RankingAba _aba = RankingAba.temporada;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1400),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = RankingVM.mock(aba: _aba);

    return RankingScreen(
      vm: vm,
      onVoltar: () => Navigator.of(context).maybePop(),
      onTrocarAba: (aba) => setState(() => _aba = aba),
      onAbrirHall: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const _HallPreviewHost()),
      ),
      onVerJogador: (posicao) => _aviso('Perfil da posição #$posicao'),
      onRecarregar: () => setState(() {}),
      onCarregarMais: null,
      onNavTap: (destino) {
        switch (destino) {
          case NavDestino.inicio:
            Navigator.of(context).maybePop();
            break;
          case NavDestino.ranking:
            break;
          case NavDestino.loja:
            _aviso('Loja VIP — chega nas próximas fatias 👍');
            break;
          case NavDestino.perfil:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PerfilPage()),
            );
            break;
        }
      },
    );
  }
}

// ===================== MESA DE JOGO — VERDE + MOTOR (fatia 2) =====================
// Visual: porte fiel de claude/mesa-verde-APROVADA.html (aprovado pela Sônia).
// Lógica: motor portado do motor testado (carta.js/canastra.js/jogo.js), modalidade ABERTO.
//   Fatia 1: baralho, distribuição, comprar do monte, descartar, passar a vez, robôs simples.
//   Fatia 2 (esta): BAIXAR jogos, ESTENDER, canastras (limpa/suja/500), BATER — jogos reais na mesa.
//   Interação 100% no toque: seleciona cartas -> toca na área NÓS (baixar) ou num jogo (estender);
//   seleciona 1 carta -> toca no lixo (descartar). Pegar-lixo e IA que baixa ficam pra fatia 3.

// ---------- MODELO ----------
class Carta {
  final String id;
  final String? naipe; // 'copas','ouros','paus','espadas' | null (joker)
  final String valor; // 'A'..'K' | 'JOKER'
  final bool ehCoringa;
  const Carta(this.id, this.naipe, this.valor, this.ehCoringa);
}

const _naipeSimb = {'copas': '♥', 'ouros': '♦', 'paus': '♣', 'espadas': '♠'};
bool _cartaVermelha(Carta c) => c.naipe == 'copas' || c.naipe == 'ouros';
String _cartaSimb(Carta c) => c.ehCoringa && c.valor == 'JOKER' ? '★' : (_naipeSimb[c.naipe] ?? '');
String _cartaRotulo(Carta c) => c.valor == 'JOKER' ? '★' : c.valor;

// imagem real da carta (baralho enviado pela Sônia). JOKER alterna entre os dois
// desenhos de curinga (usando o id pra dar variedade); dorso do baralho pro monte/mortos.
const String _dorsoAsset = 'assets/baralho/dorso.webp';
String _cartaAsset(Carta c) {
  if (c.valor == 'JOKER') {
    final h = c.id.codeUnits.fold<int>(0, (a, b) => a + b);
    return h.isEven ? 'assets/baralho/joker.webp' : 'assets/baralho/joker2.webp';
  }
  return 'assets/baralho/${c.naipe}_${c.valor}.webp';
}

// ---------- MOTOR ----------
class Jogo {
  final _rnd = Random();
  int _cont = 0;
  static const _naipes = ['copas', 'ouros', 'paus', 'espadas'];
  static const _valores = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  static const _ordem = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  static const cartasPorMao = 11;
  static const cartasPorMorto = 11;

  List<List<Carta>> maos = [[], [], [], []];
  List<Carta> monte = [];
  List<List<Carta>> mortos = [];
  List<Carta> lixo = [];
  Map<String, bool> mortoPego = {'nos': false, 'eles': false};
  Map<String, List<List<Carta>>> jogosDupla = {'nos': [], 'eles': []};
  int vez = 0;
  bool jaComprou = false;
  bool rodadaEncerrada = false;
  String? duplaQueBateu;
  int? assentoQueBateu;
  int rodada = 0;

  // ===== FATIA 4: PLACAR / FIM DE RODADA / FIM DE PARTIDA =====
  int metaPontos = 1500;
  Map<String, int> placar = {'nos': 0, 'eles': 0};
  bool encerrada = false; // partida acabou (bateu a meta)
  Map<String, dynamic>? pontosRodada; // detalhamento da última rodada contada
  bool _rodadaContada = false;

  final List<String> apelidos;
  final List<String> avatares;
  final List<String> mascotes;
  Jogo(this.apelidos, this.avatares, this.mascotes) {
    _distribuir();
  }

  String _duplaKey(int a) => a % 2 == 0 ? 'nos' : 'eles';
  Carta? get lixoTopo => lixo.isEmpty ? null : lixo.last;
  bool get suaVez => vez == 0;
  String _novoId() => 'c${++_cont}';

  List<Carta> _gerarBaralho() {
    final cs = <Carta>[];
    for (var b = 0; b < 2; b++) {
      for (final n in _naipes) {
        for (final v in _valores) {
          cs.add(Carta(_novoId(), n, v, v == '2'));
        }
      }
      // modalidade ABERTO nao usa curingao (jokers) — so os 2 sao coringa
    }
    return cs;
  }

  void _embaralhar(List<Carta> cs) {
    for (var i = cs.length - 1; i > 0; i--) {
      final j = _rnd.nextInt(i + 1);
      final t = cs[i]; cs[i] = cs[j]; cs[j] = t;
    }
  }

  List<Carta> _tirar(List<Carta> pool, int n) {
    final out = pool.sublist(0, n);
    pool.removeRange(0, n);
    return out;
  }

  void _distribuir() {
    final pool = _gerarBaralho();
    _embaralhar(pool);
    maos = [for (var a = 0; a < 4; a++) _tirar(pool, cartasPorMao)];
    mortos = [_tirar(pool, cartasPorMorto), _tirar(pool, cartasPorMorto)];
    monte = pool;
    lixo = [];
    mortoPego = {'nos': false, 'eles': false};
    jogosDupla = {'nos': [], 'eles': []};
    vez = 0; jaComprou = false; rodadaEncerrada = false; duplaQueBateu = null; assentoQueBateu = null; rodada += 1;
    _rodadaContada = false; pontosRodada = null;
    ordenar(0); // mão do jogador já começa organizada
  }

  // ===== PONTUAÇÃO (porte fiel de motor/jogo.js: pontuarDuplaJogo + contarPontos) =====
  // canastra: as_a_as=1000, de_500=500, limpa=200, suja=100; + cartas baixadas;
  // + bônus de batida (100); − cartas na mão; − morto não pego (−100, só se ALGUÉM pegou).
  Map<String, dynamic> _pontuarDupla(String dupla,
      {required bool bateu, required bool mortoPegoDupla, required int cartasNaMao, required bool algumPegouMorto}) {
    int pontosCanastras = 0, pontosCartas = 0;
    final det = {'asAas': 0, 'de500': 0, 'limpas': 0, 'sujas': 0, 'baixadas': 0};
    for (final meld in jogosDupla[dupla]!) {
      if (meld.length >= 7) {
        final res = validarSequencia(meld);
        if (res['valido'] == true) {
          switch (res['tipo']) {
            case 'as_a_as': pontosCanastras += 1000; det['asAas'] = det['asAas']! + 1; break;
            case 'de_500': pontosCanastras += 500; det['de500'] = det['de500']! + 1; break;
            case 'limpa': pontosCanastras += 200; det['limpas'] = det['limpas']! + 1; break;
            case 'suja': pontosCanastras += 100; det['sujas'] = det['sujas']! + 1; break;
          }
        }
      }
      for (final c in meld) pontosCartas += _pontos(c);
    }
    det['baixadas'] = pontosCartas;
    final bonusBatida = bateu ? 100 : 0;
    final penalidadeMorto = (!mortoPegoDupla && algumPegouMorto) ? -100 : 0;
    final descontoMao = -cartasNaMao;
    final total = pontosCanastras + pontosCartas + bonusBatida + descontoMao + penalidadeMorto;
    return {'total': total, 'canastras': pontosCanastras, 'bonusBatida': bonusBatida,
      'penalidadeMorto': penalidadeMorto, 'descontoMao': descontoMao, 'detalhe': det};
  }

  // Conta as duas duplas, soma no placar e marca a partida encerrada se bateu a meta.
  // Auto-protegida: só conta uma vez por rodada.
  void contarPontos() {
    if (_rodadaContada || !rodadaEncerrada) return;
    _rodadaContada = true;
    final algumPegouMorto = mortoPego['nos']! || mortoPego['eles']!;
    final res = <String, dynamic>{};
    for (final dupla in ['nos', 'eles']) {
      final assentos = dupla == 'nos' ? [0, 2] : [1, 3];
      final cartasNaMao = assentos.fold<int>(0, (s, a) => s + maos[a].fold<int>(0, (t, c) => t + _pontos(c)));
      final r = _pontuarDupla(dupla,
          bateu: duplaQueBateu == dupla,
          mortoPegoDupla: mortoPego[dupla]!,
          cartasNaMao: cartasNaMao,
          algumPegouMorto: algumPegouMorto);
      res[dupla] = r;
      placar[dupla] = placar[dupla]! + (r['total'] as int);
    }
    pontosRodada = res;
    if (placar['nos']! >= metaPontos || placar['eles']! >= metaPontos) encerrada = true;
  }

  // Nova rodada: mantém o placar, redistribui tudo o resto.
  void novaRodada() {
    if (encerrada) return;
    _distribuir();
  }

  // ---------- VALIDAÇÃO DE SEQUÊNCIA / CANASTRA (porte de canastra.js) ----------
  Map<String, dynamic> _finalizar(String tipoBase, int qtdCuringas, int tamanho) {
    String tipo;
    if (tamanho < 7) {
      tipo = 'aberta';
    } else if (tipoBase == 'de_curinga') {
      tipo = 'de_curinga';
    } else if (tipoBase == 'de_as') {
      tipo = 'de_as';
    } else if (tipoBase == 'as_a_as') {
      tipo = 'as_a_as';
    } else if (tipoBase == 'de_500') {
      tipo = 'de_500';
    } else {
      tipo = qtdCuringas > 0 ? 'suja' : 'limpa';
    }
    return {'valido': true, 'tipo': tipo, 'qtd_curingas': qtdCuringas};
  }

  Map<String, dynamic> validarSequencia(List<Carta> cartas) {
    if (cartas.length < 3) return {'valido': false, 'motivo': 'Mínimo de 3 cartas para formar um jogo'};
    final curingas = cartas.where((c) => c.ehCoringa).toList();
    final naoCuringas = cartas.where((c) => !c.ehCoringa).toList();
    if (curingas.length == cartas.length) return _finalizar('de_curinga', curingas.length, cartas.length);
    if (curingas.isEmpty && naoCuringas.every((c) => c.valor == 'A')) return _finalizar('de_as', 0, cartas.length);

    final jokers = cartas.where((c) => c.valor == 'JOKER').toList();
    final dois = cartas.where((c) => c.valor == '2').toList();
    final comuns = cartas.where((c) => c.valor != '2' && c.valor != 'JOKER').toList();
    final naipesComuns = comuns.map((c) => c.naipe).toSet();
    if (naipesComuns.length > 1) return {'valido': false, 'motivo': 'Todas as cartas não-coringa devem ser do mesmo naipe'};
    final naipeSeq = comuns.isNotEmpty ? comuns[0].naipe : (dois.isNotEmpty ? dois[0].naipe : null);

    final interpretacoes = <Map<String, List<Carta>>>[];
    for (int mascara = 0; mascara < (1 << dois.length); mascara++) {
      final comoCuringa = <Carta>[], comoNatural = <Carta>[];
      for (int i = 0; i < dois.length; i++) {
        if ((mascara & (1 << i)) != 0) { comoCuringa.add(dois[i]); } else { comoNatural.add(dois[i]); }
      }
      if (comoNatural.any((c) => naipeSeq != null && c.naipe != naipeSeq)) continue;
      interpretacoes.add({'comoCuringa': comoCuringa, 'comoNatural': comoNatural});
    }
    interpretacoes.sort((a, b) => a['comoCuringa']!.length - b['comoCuringa']!.length);

    const N = 13;
    Map<String, int>? encaixa(List<Carta> naturais, int qtdCuringas, int teto) {
      final ases = naturais.where((c) => c.valor == 'A').toList();
      final outros = naturais.where((c) => c.valor != 'A').toList();
      final idxOutros = outros.map((c) => _ordem.indexOf(c.valor)).toList();
      if (idxOutros.toSet().length != idxOutros.length) return null;
      if (ases.length > 2) return null;
      var combos = <List<int>>[[]];
      for (int k = 0; k < ases.length; k++) {
        final prox = <List<int>>[];
        for (final cb in combos) { prox.add([...cb, 0]); prox.add([...cb, N]); }
        combos = prox;
      }
      Map<String, int>? melhor;
      for (final asIdx in combos) {
        final indices = [...idxOutros, ...asIdx]..sort();
        if (indices.toSet().length != indices.length) continue;
        final minIdx = indices.first, maxIdx = indices.last;
        final span = maxIdx - minIdx + 1;
        final lacunas = span - indices.length;
        if (lacunas > qtdCuringas) continue;
        final sobra = qtdCuringas - lacunas;
        if (sobra > 0) {
          final cabeNoInicio = minIdx - sobra >= 0;
          final cabeNoFim = maxIdx + sobra <= teto;
          if (!cabeNoInicio && !cabeNoFim) continue;
        }
        if (melhor == null || maxIdx > melhor['maxIdx']!) {
          melhor = {'minIdx': minIdx, 'maxIdx': maxIdx, 'qtdNaturais': indices.length};
        }
      }
      return melhor;
    }

    String motivoFalha = 'Lacuna na sequência maior que o número de curingas disponíveis';
    for (final interp in interpretacoes) {
      final qtdCuringas = jokers.length + interp['comoCuringa']!.length;
      if (qtdCuringas > 1) { motivoFalha = 'Máximo de 1 curinga por sequência'; continue; }
      final naturais = [...comuns, ...interp['comoNatural']!];
      if (naturais.isEmpty) continue;
      final faixa = encaixa(naturais, qtdCuringas, N);
      if (faixa != null) {
        String tipoBase = 'sequencia';
        if (qtdCuringas == 0) {
          final vals = naturais.map((c) => c.valor).toList();
          final nAses = vals.where((v) => v == 'A').length;
          final outrosDistintos = vals.where((v) => v != 'A').toSet();
          final r2aK = ['2','3','4','5','6','7','8','9','10','J','Q','K'];
          final temDois2aoK = r2aK.every((r) => outrosDistintos.contains(r)) && outrosDistintos.length == 12;
          if (temDois2aoK && nAses == 2 && naturais.length == 14) {
            tipoBase = 'as_a_as';
          } else if (temDois2aoK && nAses == 1 && naturais.length == 13) {
            tipoBase = 'de_500';
          }
        }
        return _finalizar(tipoBase, qtdCuringas, cartas.length);
      }
    }
    return {'valido': false, 'motivo': motivoFalha};
  }

  // ABERTO: só sequência (ás só em sequência; trinca/de_as só valeriam no Fechado)
  Map<String, dynamic> _validarJogoMesa(List<Carta> cartas) {
    final soAses = cartas.isNotEmpty && cartas.every((c) => c.valor == 'A' && !c.ehCoringa);
    final r = validarSequencia(cartas);
    if (r['valido'] == true && !soAses) return r;
    if (soAses) return {'valido': false, 'motivo': 'no ABERTO o ás só entra em sequência'};
    return r;
  }

  bool _canastraLiberaBatida(List<Carta> meld) {
    if (meld.length < 7) return false;
    final r = validarSequencia(meld);
    if (r['valido'] != true) return false;
    final t = r['tipo'];
    return t == 'limpa' || t == 'de_500' || t == 'as_a_as';
  }

  bool duplaPodeBater(String dupla) => jogosDupla[dupla]!.any(_canastraLiberaBatida);

  bool _baixadaTravaria(String dupla, int maoRestante, List<List<Carta>> futuros) {
    if (maoRestante >= 2) return false;
    final temLimpa = futuros.any(_canastraLiberaBatida);
    final mortoDisp = !mortoPego[dupla]! && mortos.isNotEmpty;
    return !(temLimpa || mortoDisp);
  }

  static const erroTravaria =
      'não dá pra baixar isso: você ficaria com uma carta que não pode descartar (sem canastra LIMPA pra bater e sem morto). Segure mais uma carta.';

  Map<String, dynamic>? _aoZerarMaoBaixando(int assento) {
    if (maos[assento].isNotEmpty) return null;
    final dupla = _duplaKey(assento);
    if (!mortoPego[dupla]! && mortos.isNotEmpty) {
      maos[assento] = mortos.removeAt(0);
      mortoPego[dupla] = true;
      return {'pegouMorto': true};
    }
    if (duplaPodeBater(dupla)) {
      rodadaEncerrada = true; duplaQueBateu = dupla; assentoQueBateu = assento;
      return {'bateu': true};
    }
    return null;
  }

  // ---------- JOGADAS ----------
  bool comprarMonte(int assento) {
    if (rodadaEncerrada || vez != assento || jaComprou) return false;
    if (monte.isEmpty) {
      if (mortos.isNotEmpty) { monte = mortos.removeAt(0); } else { rodadaEncerrada = true; return false; }
    }
    maos[assento].add(monte.removeAt(0));
    jaComprou = true;
    return true;
  }

  // PEGAR O LIXO INTEIRO. No ABERTO a compra é livre: sem trava de "carta com mola"
  // e sem obrigação de usar o topo (regra confirmada). Leva o monte de descarte todo
  // pra mão. (fatia 3)
  Map<String, dynamic> comprarLixo(int assento) {
    if (rodadaEncerrada || vez != assento || jaComprou) return {'ok': false, 'erro': 'não dá pra pegar o lixo agora'};
    if (lixo.isEmpty) return {'ok': false, 'erro': 'o lixo está vazio'};
    final qtd = lixo.length;
    maos[assento].addAll(lixo);
    lixo = [];
    jaComprou = true;
    return {'ok': true, 'qtd': qtd};
  }

  // ORGANIZAR A MÃO: agrupa por naipe (cores alternadas p/ leitura) e ordena por
  // sequência (A,2,3…K). O 2 fica na posição natural dele dentro do naipe (ajuda a
  // enxergar A-2-3); coringas sem naipe (JOKER) vão pro fim.
  static const _naipeOrdem = {'copas': 0, 'espadas': 1, 'ouros': 2, 'paus': 3};
  void ordenar(int assento) {
    maos[assento].sort((a, b) {
      final na = a.naipe == null ? 99 : (_naipeOrdem[a.naipe] ?? 98);
      final nb = b.naipe == null ? 99 : (_naipeOrdem[b.naipe] ?? 98);
      if (na != nb) return na - nb;
      return _ordem.indexOf(a.valor) - _ordem.indexOf(b.valor);
    });
  }

  Map<String, dynamic> baixar(int assento, List<String> ids) {
    if (rodadaEncerrada || vez != assento || !jaComprou) return {'ok': false, 'erro': 'compre uma carta antes de baixar'};
    if (ids.length < 3) return {'ok': false, 'erro': 'um jogo tem no mínimo 3 cartas'};
    if (ids.toSet().length != ids.length) return {'ok': false, 'erro': 'carta repetida no jogo'};
    final cartas = <Carta>[];
    for (final id in ids) {
      final idx = maos[assento].indexWhere((c) => c.id == id);
      if (idx < 0) return {'ok': false, 'erro': 'carta não está na sua mão'};
      cartas.add(maos[assento][idx]);
    }
    final res = _validarJogoMesa(cartas);
    if (res['valido'] != true) return {'ok': false, 'erro': res['motivo'] ?? 'jogo inválido'};
    final dupla = _duplaKey(assento);
    final maoRest = maos[assento].length - cartas.length;
    final futuros = [...jogosDupla[dupla]!, cartas];
    if (_baixadaTravaria(dupla, maoRest, futuros)) return {'ok': false, 'erro': erroTravaria};
    final idset = ids.toSet();
    maos[assento] = maos[assento].where((c) => !idset.contains(c.id)).toList();
    jogosDupla[dupla]!.add(cartas);
    final zer = _aoZerarMaoBaixando(assento);
    return {'ok': true, 'tipo': res['tipo'], ...?zer};
  }

  Map<String, dynamic> estender(int assento, int indiceJogo, List<String> ids) {
    if (rodadaEncerrada || vez != assento || !jaComprou) return {'ok': false, 'erro': 'compre uma carta antes'};
    final dupla = _duplaKey(assento);
    final jogos = jogosDupla[dupla]!;
    if (indiceJogo < 0 || indiceJogo >= jogos.length) return {'ok': false, 'erro': 'jogo não existe'};
    final alvo = jogos[indiceJogo];
    if (ids.isEmpty) return {'ok': false, 'erro': 'nenhuma carta pra estender'};
    if (ids.toSet().length != ids.length) return {'ok': false, 'erro': 'carta repetida'};
    final cartas = <Carta>[];
    for (final id in ids) {
      final idx = maos[assento].indexWhere((c) => c.id == id);
      if (idx < 0) return {'ok': false, 'erro': 'carta não está na sua mão'};
      cartas.add(maos[assento][idx]);
    }
    final res = _validarJogoMesa([...alvo, ...cartas]);
    if (res['valido'] != true) return {'ok': false, 'erro': res['motivo'] ?? 'extensão inválida'};
    final maoRest = maos[assento].length - cartas.length;
    final futuros = [for (int i = 0; i < jogos.length; i++) i == indiceJogo ? [...alvo, ...cartas] : jogos[i]];
    if (_baixadaTravaria(dupla, maoRest, futuros)) return {'ok': false, 'erro': erroTravaria};
    final idset = ids.toSet();
    maos[assento] = maos[assento].where((c) => !idset.contains(c.id)).toList();
    jogos[indiceJogo] = [...alvo, ...cartas];
    final zer = _aoZerarMaoBaixando(assento);
    return {'ok': true, 'tipo': res['tipo'], ...?zer};
  }

  // retorna null se ok; senão string de erro
  String? descartar(int assento, String idCarta) {
    if (rodadaEncerrada || vez != assento || !jaComprou) return 'não é sua vez';
    final idx = maos[assento].indexWhere((c) => c.id == idCarta);
    if (idx < 0) return 'carta não está na mão';
    final dupla = _duplaKey(assento);
    final zeraria = maos[assento].length == 1;
    final podeBatidaFinal = mortoPego[dupla]! || mortos.isEmpty;
    if (zeraria && podeBatidaFinal && !duplaPodeBater(dupla)) {
      return 'pra bater você precisa de uma canastra LIMPA na mesa da dupla';
    }
    final c = maos[assento].removeAt(idx);
    lixo.add(c);
    if (maos[assento].isEmpty) {
      if (!mortoPego[dupla]! && mortos.isNotEmpty) {
        maos[assento] = mortos.removeAt(0);
        mortoPego[dupla] = true;
        _passarVez();
        return null;
      }
      rodadaEncerrada = true; duplaQueBateu = dupla; assentoQueBateu = assento;
      return null;
    }
    _passarVez();
    return null;
  }

  void _passarVez() {
    if (monte.isEmpty) {
      if (mortos.isEmpty) { rodadaEncerrada = true; return; }
      monte = mortos.removeAt(0);
    }
    vez = (vez + 1) % 4;
    jaComprou = false;
  }

  // ============ IA DO ROBÔ (fatia 3 — porte de motor/bot.js) ============
  static int _pontos(Carta c) {
    if (c.valor == 'A') return 15;
    if (c.valor == 'JOKER') return 50;
    if (c.valor == '2') return 10;
    if (['8', '9', '10', 'J', 'Q', 'K'].contains(c.valor)) return 10;
    return 5; // 3..7
  }

  static const int _minJogoPraGastarCuringa = 5;

  // maior corrida do mesmo naipe; usa no máx. 1 curinga se permitir3ComCuringa
  List<Carta>? _melhorCorrida(List<Carta> mao, bool permitir3ComCuringa) {
    const naipes = ['copas', 'ouros', 'paus', 'espadas'];
    List<Carta>? melhor;
    int idxBaixo(String v) => _ordem.indexOf(v);
    int idxAlto(String v) => v == 'A' ? _ordem.length : _ordem.indexOf(v);
    for (final naipe in naipes) {
      final cartasDoNaipe = mao.where((c) => c.naipe == naipe).toList();
      final temAs = cartasDoNaipe.any((c) => c.valor == 'A');
      final mapeamentos = temAs ? <int Function(String)>[idxBaixo, idxAlto] : <int Function(String)>[idxBaixo];
      for (final mapa in mapeamentos) {
        final doNaipe = cartasDoNaipe.toList()..sort((a, b) => mapa(a.valor) - mapa(b.valor));
        final curingasMesmoNaipe = mao.where((c) => c.ehCoringa && c.valor == '2' && c.naipe == naipe).toList();
        final doisOutroNaipe = mao.where((c) => c.ehCoringa && c.valor == '2' && c.naipe != naipe).toList();
        final jokers = mao.where((c) => c.valor == 'JOKER').toList();
        final curingasOrdenados = [...curingasMesmoNaipe, ...doisOutroNaipe, ...jokers];
        final unicas = <Carta>[];
        final vistos = <String>{};
        for (final c in doNaipe) {
          if (!vistos.contains(c.valor)) { unicas.add(c); vistos.add(c.valor); }
        }
        if (unicas.isEmpty) continue;
        for (int i = 0; i < unicas.length; i++) {
          final seq = <Carta>[unicas[i]];
          int curingasUsados = 0;
          final idsNaSeq = <String>{unicas[i].id};
          for (int j = i + 1; j < unicas.length; j++) {
            final distancia = mapa(unicas[j].valor) - mapa(seq.last.valor);
            if (distancia == 1) {
              seq.add(unicas[j]); idsNaSeq.add(unicas[j].id);
            } else if (distancia == 2 && curingasUsados < 1 && permitir3ComCuringa) {
              Carta? cur;
              for (final c in curingasOrdenados) { if (!idsNaSeq.contains(c.id)) { cur = c; break; } }
              if (cur == null) break;
              seq.add(cur); idsNaSeq.add(cur.id);
              seq.add(unicas[j]); idsNaSeq.add(unicas[j].id);
              curingasUsados++;
            } else {
              break;
            }
          }
          if (seq.length == 2 && curingasUsados < 1 && permitir3ComCuringa) {
            Carta? curPonta;
            for (final c in curingasOrdenados) { if (!idsNaSeq.contains(c.id)) { curPonta = c; break; } }
            if (curPonta != null) { seq.add(curPonta); idsNaSeq.add(curPonta.id); curingasUsados++; }
          }
          if (seq.length >= 3) {
            final usaCuringaComoTapa = curingasUsados > 0;
            if (usaCuringaComoTapa && !permitir3ComCuringa) continue;
            final res = validarSequencia(seq);
            if (res['valido'] == true && (melhor == null || seq.length > melhor!.length)) melhor = seq;
          }
        }
      }
    }
    return melhor;
  }

  List<Carta>? _escolherCorrida(List<Carta> mao, bool permissivo) {
    final comCuringa = _melhorCorrida(mao, true);
    if (permissivo) return comCuringa;
    final semCuringa = _melhorCorrida(mao, false);
    final tamSem = semCuringa?.length ?? 0;
    final tamCom = comCuringa?.length ?? 0;
    if (tamSem >= 3 && tamSem >= tamCom) return semCuringa;
    if (tamCom >= _minJogoPraGastarCuringa) return comCuringa;
    return tamSem >= 3 ? semCuringa : null;
  }

  // agrupa a mão em jogos (guloso) + anexa curinga órfão na ponta do maior jogo
  Map<String, dynamic> _agruparMao(List<Carta> mao, bool permissivo) {
    final jogos = <List<Carta>>[];
    var restantes = mao.toList();
    bool progrediu = true;
    while (progrediu) {
      progrediu = false;
      final melhor = _escolherCorrida(restantes, permissivo);
      if (melhor != null && melhor.length >= 3) {
        jogos.add(melhor);
        final usados = melhor.map((c) => c.id).toSet();
        restantes = restantes.where((c) => !usados.contains(c.id)).toList();
        progrediu = true;
      }
    }
    bool podeAnexar(Carta c) => permissivo || c.valor == '2';
    final minParaAnexar = permissivo ? 3 : _minJogoPraGastarCuringa - 1;
    Carta? orfao;
    for (final c in restantes) { if (c.ehCoringa && podeAnexar(c)) { orfao = c; break; } }
    while (orfao != null) {
      final alvos = jogos.where((j) => j.length >= minParaAnexar && !j.any((c) => c.ehCoringa) && j.map((c) => c.valor).toSet().length > 1).toList()
        ..sort((a, b) => b.length - a.length);
      if (alvos.isEmpty) break;
      alvos.first.add(orfao);
      final oid = orfao.id;
      restantes = restantes.where((c) => c.id != oid).toList();
      orfao = null;
      for (final c in restantes) { if (c.ehCoringa && podeAnexar(c)) { orfao = c; break; } }
    }
    return {'jogos': jogos, 'sobra': restantes};
  }

  int _vizinhos(List<Carta> mao, Carta carta) {
    if (carta.ehCoringa) return 99;
    int n = 0;
    for (final c in mao) {
      if (c.id == carta.id || c.ehCoringa) continue;
      if (c.naipe == carta.naipe && (_ordem.indexOf(c.valor) - _ordem.indexOf(carta.valor)).abs() <= 2) n++;
    }
    return n;
  }

  // descarte SEGURO: protege combos em formação, evita curinga, evita servir ao adversário
  Carta _decidirDescarte(List<Carta> mao, List<List<Carta>> jogosAdversario) {
    final sobra = _agruparMao(mao, true)['sobra'] as List<Carta>;
    final candidatas = sobra.isNotEmpty ? sobra : mao.toList();
    final semCuringa = candidatas.where((c) => !c.ehCoringa).toList();
    var pool = semCuringa.isNotEmpty ? semCuringa : candidatas;
    bool ehPerigosa(Carta carta) => jogosAdversario.any((j) => validarSequencia([...j, carta])['valido'] == true);
    final seguras = pool.where((c) => !ehPerigosa(c)).toList();
    if (seguras.isNotEmpty) pool = seguras;
    pool.sort((a, b) {
      final pa = _pontos(a), pb = _pontos(b);
      if (pa != pb) return pa - pb;
      return _vizinhos(mao, a) - _vizinhos(mao, b);
    });
    return pool.first;
  }

  // ROBÔ (fatia 3): compra, BAIXA os jogos possíveis, ESTENDE cartas soltas e descarta com critério
  void botJoga(int assento) {
    if (rodadaEncerrada || vez != assento) return;
    if (!jaComprou) comprarMonte(assento);
    if (rodadaEncerrada) return;
    final dupla = _duplaKey(assento);

    // 1) baixa os jogos que dá (baixar() já respeita a trava/validade)
    final grupos = _agruparMao(maos[assento], false)['jogos'] as List<List<Carta>>;
    for (final g in grupos) {
      if (rodadaEncerrada) break;
      if (!g.every((c) => maos[assento].any((m) => m.id == c.id))) continue; // mão mudou (pegou morto)
      baixar(assento, g.map((c) => c.id).toList());
    }

    // 2) estende cartas soltas nos jogos da dupla
    bool progrediu = true;
    while (progrediu && !rodadaEncerrada) {
      progrediu = false;
      final jogos = jogosDupla[dupla]!;
      for (int i = 0; i < jogos.length; i++) {
        Carta? achou;
        for (final c in maos[assento]) {
          if (_validarJogoMesa([...jogos[i], c])['valido'] == true) { achou = c; break; }
        }
        if (achou != null && estender(assento, i, [achou.id])['ok'] == true) { progrediu = true; break; }
      }
    }

    if (rodadaEncerrada || maos[assento].isEmpty) return;

    // 3) descarta (encerra a vez)
    final adv = jogosDupla[dupla == 'nos' ? 'eles' : 'nos']!;
    final alvo = _decidirDescarte(maos[assento], adv);
    if (descartar(assento, alvo.id) != null) {
      for (final c in maos[assento].toList()) {
        if (descartar(assento, c.id) == null) return;
      }
    }
  }
}

// ===================== MESA DE JOGO — FUNCIONAL VIP (CODEX) =====================
// Camada visual aprovada pela Sônia em 29/07/2026.
// Regras, motor, pontuação, robôs, Firebase e contratos continuam preservados.

const _mGold = Color(0xFFE5B84F);
const _mGoldHi = Color(0xFFFFE7A0);
const _mPurple = Color(0xFF9D43D8);
const _mPurpleHi = Color(0xFFD690FF);
const _mFelt = Color(0xFF080808);
const _mPanel = Color(0xEE101010);
const _mRed = Color(0xFFB3262D);
const _mBlack = Color(0xFF121212);

Color _corCarta(Carta c) =>
    c.valor == 'JOKER' ? _mGold : (_cartaVermelha(c) ? _mRed : _mBlack);

class _VipFeltPainter extends CustomPainter {
  const _VipFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = RadialGradient(
      center: const Alignment(0, -0.08),
      radius: 1.1,
      colors: const [Color(0x182B2030), Color(0x080F0B12), Color(0x00000000)],
      stops: const [0, 0.55, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = glow);

    final grain = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.55;
    for (double y = 3; y < size.height; y += 9) {
      final shift = (y ~/ 9).isEven ? 0.0 : 4.0;
      for (double x = shift; x < size.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.45, grain);
      }
    }

    final vignette = RadialGradient(
      radius: 0.84,
      colors: const [Color(0x00000000), Color(0x55000000)],
      stops: const [0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MesaVariant { publica, vip }

class _PublicFeltPainter extends CustomPainter {
  const _PublicFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final felt = RadialGradient(
      center: const Alignment(0, -0.12),
      radius: 1.08,
      colors: const [
        Color(0xFF174D36),
        Color(0xFF0D3928),
        Color(0xFF062719),
      ],
      stops: const [0, 0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = felt);

    final grain = Paint()
      ..color = const Color(0x0BFFFFFF)
      ..strokeWidth = 0.55;
    for (double y = 3; y < size.height; y += 9) {
      final shift = (y ~/ 9).isEven ? 0.0 : 4.0;
      for (double x = shift; x < size.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.45, grain);
      }
    }

    final vignette = RadialGradient(
      radius: 0.88,
      colors: const [Color(0x00000000), Color(0x65000000)],
      stops: const [0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MesaScreen extends StatefulWidget {
  final MesaVariant variant;
  final String modalidade;
  final int metaPontos;
  final int tempoSegundos;
  final int? vulnerabilidadeNos;
  final int? vulnerabilidadeEles;

  const MesaScreen({
    super.key,
    this.variant = MesaVariant.vip,
    this.modalidade = 'ABERTO',
    this.metaPontos = 1500,
    this.tempoSegundos = 45,
    this.vulnerabilidadeNos,
    this.vulnerabilidadeEles,
  });

  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> {
  late Jogo _j;
  final Set<int> _sel = <int>{};
  final ScrollController _handScroll = ScrollController();
  final ScrollController _discardScroll = ScrollController();

  bool _botsRodando = false;
  bool _soundEnabled = true;
  String? _msg;
  Set<String> _recentlyBoughtIds = <String>{};
  String? _lastPurchaseSource;
  String? _celebratingMeldKey;
  int? _expandedAvatarSeat;
  Timer? _purchaseGlowTimer;
  Timer? _celebrationTimer;
  Timer? _turnTimer;
  int _turnSeconds = 45;
  int _clockSeat = 0;

  final Map<int, EstadoAmizade> _amizades = <int, EstadoAmizade>{
    1: EstadoAmizade.disponivel,
    2: EstadoAmizade.amigos,
    3: EstadoAmizade.disponivel,
  };
  bool _conviteRevancheEnviado = false;
  bool _anuncioAssistido = false;
  bool _anuncioDisponivel = true;
  bool _assinanteSemAnuncios = false;

  AudioPlayer? _pCarta;
  AudioPlayer? _pEvento;

  String get _modalidade => widget.modalidade;
  bool get _mesaVip => widget.variant == MesaVariant.vip;
  Color get _feltColor =>
      _mesaVip ? _mFelt : const Color(0xFF062719);
  String get _cardBackAsset => _mesaVip
      ? 'assets/baralho/dorso.webp'
      : 'assets/baralho/dorso_publico.webp';
  int? _vulnerabilidadeDaDupla(String dupla) =>
      dupla == 'nos' ? widget.vulnerabilidadeNos : widget.vulnerabilidadeEles;

  bool get _minhaVezAtiva =>
      _j.suaVez && !_j.rodadaEncerrada && !_botsRodando;

  Jogo _novoJogo() {
    final jogo = Jogo(
      const ['você', 'Cláudia', 'Mateus', 'Sofia'],
      const ['👑', '🙂', '😎', 'RN'],
      const ['🐶', '🐰', '🦊', '🐱'],
    );
    jogo.metaPontos = widget.metaPontos;
    return jogo;
  }

  @override
  void initState() {
    super.initState();
    _j = _novoJogo();
    _turnSeconds = widget.tempoSegundos;
    _clockSeat = _j.vez;
    try {
      _pCarta = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pEvento = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // A mesa continua funcional mesmo quando o dispositivo não oferece áudio.
    }
    _startTurnClock();
  }

  @override
  void dispose() {
    _purchaseGlowTimer?.cancel();
    _celebrationTimer?.cancel();
    _turnTimer?.cancel();
    _handScroll.dispose();
    _discardScroll.dispose();
    _pCarta?.dispose();
    _pEvento?.dispose();
    super.dispose();
  }

  void _startTurnClock() {
    _turnTimer?.cancel();
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_j.rodadaEncerrada) return;
      if (_clockSeat != _j.vez) {
        setState(() {
          _clockSeat = _j.vez;
          _turnSeconds = widget.tempoSegundos;
        });
        return;
      }
      if (_turnSeconds > 0) {
        setState(() => _turnSeconds -= 1);
      }
    });
  }

  void _syncTurnClock({bool force = false}) {
    if (force || _clockSeat != _j.vez) {
      _clockSeat = _j.vez;
      _turnSeconds = widget.tempoSegundos;
    }
  }

  void _play(AudioPlayer? player, String arquivo, double volume) {
    if (!_soundEnabled || player == null) return;
    try {
      player.stop();
      player.play(AssetSource('sons/$arquivo'), volume: volume);
    } catch (_) {}
  }

  void _somCarta() => _play(_pCarta, 'carta.mp3', 0.95);
  void _somCompra() => _play(_pCarta, 'carta.mp3', 1.0);
  void _somErro() => _play(_pEvento, 'erro.mp3', 0.9);
  void _somMorto() => _play(_pEvento, 'morto.mp3', 1.0);
  void _somVitoria() => _play(_pEvento, 'vitoria.mp3', 1.0);

  void _somCanastra(String? tipo) {
    switch (tipo) {
      case 'as_a_as':
        _play(_pEvento, 'canastra1000.mp3', 1.0);
        break;
      case 'de_500':
        _play(_pEvento, 'canastra500.mp3', 1.0);
        break;
      case 'suja':
        _play(_pEvento, 'canastra_suja.mp3', 1.0);
        break;
      default:
        _play(_pEvento, 'canastra200.mp3', 1.0);
    }
  }

  void _somJogada(Map<String, dynamic> resultado,
      {required bool novaCanastra}) {
    if (resultado['bateu'] == true) {
      _somVitoria();
      return;
    }
    if (novaCanastra) {
      _somCanastra(resultado['tipo'] as String?);
      return;
    }
    if (resultado['pegouMorto'] == true) {
      _somMorto();
      return;
    }
    _somCarta();
  }

  void _tapCard(int index) {
    setState(() {
      if (_sel.contains(index)) {
        _sel.remove(index);
      } else {
        _sel.add(index);
      }
      _msg = null;
    });
  }

  void _mostrarCompra(Set<String> ids, String origem) {
    if (ids.isEmpty) return;
    _purchaseGlowTimer?.cancel();
    setState(() {
      _recentlyBoughtIds = ids;
      _lastPurchaseSource = origem;
      _msg = null;
    });
    _purchaseGlowTimer = Timer(const Duration(milliseconds: 1850), () {
      if (!mounted) return;
      setState(() {
        _recentlyBoughtIds = <String>{};
        _lastPurchaseSource = null;
      });
    });
  }

  void _celebrateMeld(String dupla, int index) {
    _celebrationTimer?.cancel();
    setState(() => _celebratingMeldKey = '$dupla-$index');
    _celebrationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _celebratingMeldKey = null);
    });
  }

  void _scrollDiscardToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_discardScroll.hasClients) return;
      _discardScroll.animateTo(
        _discardScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _tapMonte() {
    if (!_minhaVezAtiva || _j.jaComprou) return;
    final antes = _j.maos[0].map((c) => c.id).toSet();
    if (!_j.comprarMonte(0)) return;
    _j.ordenar(0);
    final novos = _j.maos[0]
        .where((c) => !antes.contains(c.id))
        .map((c) => c.id)
        .toSet();
    _mostrarCompra(novos, 'monte');
    _somCompra();
  }

  Future<void> _tapLixo() async {
    if (!_minhaVezAtiva) return;
    if (!_j.jaComprou) {
      final antes = _j.maos[0].map((c) => c.id).toSet();
      final resultado = _j.comprarLixo(0);
      if (resultado['ok'] != true) {
        setState(() => _msg = resultado['erro'] as String?);
        _somErro();
        return;
      }
      _j.ordenar(0);
      final novos = _j.maos[0]
          .where((c) => !antes.contains(c.id))
          .map((c) => c.id)
          .toSet();
      _sel.clear();
      _mostrarCompra(novos, 'lixo');
      _somCompra();
      return;
    }

    if (_sel.length != 1) {
      setState(() =>
          _msg = 'Selecione uma carta e toque no lixo para descartar.');
      return;
    }

    final id = _j.maos[0][_sel.first].id;
    final mortoAntes = _j.mortoPego['nos'] == true;
    final erro = _j.descartar(0, id);
    if (erro != null) {
      setState(() => _msg = erro);
      _somErro();
      return;
    }

    if (!mortoAntes && _j.mortoPego['nos'] == true) {
      _somMorto();
    } else if (_j.rodadaEncerrada && _j.duplaQueBateu == 'nos') {
      _somVitoria();
    } else if (!_j.rodadaEncerrada) {
      _somCarta();
    }
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = null;
      _syncTurnClock();
    });
    _scrollDiscardToEnd();
    await _rodarBots();
  }

  void _baixar() {
    if (!_minhaVezAtiva || !_j.jaComprou) return;
    if (_sel.length < 3) {
      setState(() => _msg =
          'Selecione três ou mais cartas e toque no feltro para baixar.');
      return;
    }
    final novoIndice = _j.jogosDupla['nos']!.length;
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();
    final resultado = _j.baixar(0, ids);
    if (resultado['ok'] != true) {
      setState(() => _msg = resultado['erro'] as String?);
      _somErro();
      return;
    }
    _j.ordenar(0);
    final tipo = resultado['tipo'] as String?;
    final novaCanastra = tipo != null && tipo != 'aberta';
    _somJogada(resultado, novaCanastra: novaCanastra);
    if (novaCanastra) _celebrateMeld('nos', novoIndice);
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = resultado['bateu'] == true
          ? 'Você bateu!'
          : (resultado['pegouMorto'] == true
              ? 'Você pegou o morto.'
              : 'Jogo baixado.');
    });
  }

  void _estender(int indiceJogo) {
    if (!_minhaVezAtiva || !_j.jaComprou) return;
    if (_sel.isEmpty) {
      _showMeldZoom('nos', indiceJogo);
      return;
    }
    final jogos = _j.jogosDupla['nos']!;
    if (indiceJogo < 0 || indiceJogo >= jogos.length) return;
    final sashAntes = _sashDeMeld(jogos[indiceJogo]);
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();
    final resultado = _j.estender(0, indiceJogo, ids);
    if (resultado['ok'] != true) {
      setState(() => _msg = resultado['erro'] as String?);
      _somErro();
      return;
    }
    _j.ordenar(0);
    final sashDepois = _sashDeMeld(jogos[indiceJogo]);
    final novaCanastra =
        sashDepois != Sash.nenhuma && sashDepois != sashAntes;
    _somJogada(resultado, novaCanastra: novaCanastra);
    if (novaCanastra) _celebrateMeld('nos', indiceJogo);
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = resultado['bateu'] == true
          ? 'Você bateu!'
          : (resultado['pegouMorto'] == true
              ? 'Você pegou o morto.'
              : 'Jogo estendido.');
    });
  }

  Future<void> _rodarBots() async {
    _botsRodando = true;
    while (_j.vez != 0 && !_j.rodadaEncerrada) {
      await Future.delayed(const Duration(milliseconds: 650));
      _j.botJoga(_j.vez);
      _somCarta();
      _syncTurnClock();
      _scrollDiscardToEnd();
      if (mounted) setState(() {});
    }
    _botsRodando = false;
    if (_j.rodadaEncerrada) {
      _j.contarPontos();
      if (_j.duplaQueBateu == 'nos') _somVitoria();
    }
    _syncTurnClock();
    if (mounted) setState(() {});
  }

  Sash _sashDeMeld(List<Carta> cartas) {
    if (cartas.length < 7) return Sash.nenhuma;
    final resultado = _j.validarSequencia(cartas);
    if (resultado['valido'] != true) return Sash.nenhuma;
    switch (resultado['tipo']) {
      case 'limpa':
        return Sash.limpa;
      case 'suja':
        return Sash.suja;
      case 'de_500':
        return Sash.n500;
      case 'as_a_as':
        return Sash.n1000;
      default:
        return Sash.nenhuma;
    }
  }

  String _sashLabel(Sash sash) {
    switch (sash) {
      case Sash.limpa:
        return 'LIMPA · 200';
      case Sash.suja:
        return 'SUJA · 100';
      case Sash.n500:
        return 'CANASTRA · 500';
      case Sash.n1000:
        return 'CANASTRA · 1000';
      case Sash.nenhuma:
        return '';
    }
  }

  Color _sashColor(Sash sash) {
    switch (sash) {
      case Sash.limpa:
        return const Color(0xFF9D43D8);
      case Sash.suja:
        return const Color(0xFF4B7ED8);
      case Sash.n500:
        return const Color(0xFFC44CCB);
      case Sash.n1000:
        return const Color(0xFFE5B84F);
      case Sash.nenhuma:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _board()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(3, 3, 3, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: _mGold, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: _headerMetric(
              Icons.group_work_rounded,
              'Modalidade',
              _modalidade,
              _mPurpleHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 21,
            child: _headerMetric(
              Icons.monetization_on_rounded,
              'Mesa',
              '${_j.metaPontos}',
              _mGoldHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 19,
            child: _headerMetric(
              Icons.sync_rounded,
              'Rodada',
              '${_j.rodada}',
              _mPurpleHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 32,
            child: _scoreMetric(),
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(
        width: 1,
        height: 45,
        color: const Color(0x665B421C),
      );

  Widget _headerMetric(
      IconData icon, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          Icon(icon, color: _mGold, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFFF2E7C8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreMetric() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: _mGold, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pontuação',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFFF2E7C8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Nós ',
                          style: TextStyle(color: _mPurpleHi),
                        ),
                        TextSpan(
                          text: '${_j.placar['nos']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const TextSpan(
                          text: '  Eles ',
                          style: TextStyle(color: Color(0xFFF1C15B)),
                        ),
                        TextSpan(
                          text: '${_j.placar['eles']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const centralHeight = 122.0;
        const playerDockHeight = 166.0;
        return Container(
          margin: const EdgeInsets.fromLTRB(3, 0, 3, 3),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE6A1), Color(0xFF6A4415), Color(0xFFE0B45D)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _feltColor,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border.all(color: const Color(0xFF15100A), width: 1.5),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _mesaVip
                        ? const _VipFeltPainter()
                        : const _PublicFeltPainter(),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(child: _meldArea('eles', top: true)),
                      SizedBox(height: centralHeight, child: _centralTray()),
                      Expanded(child: _meldArea('nos', top: false)),
                      const SizedBox(height: playerDockHeight),
                    ],
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 74,
                  child: _sidePlayer(1, left: true),
                ),
                Positioned(
                  right: 2,
                  top: 74,
                  child: _sidePlayer(3, left: false),
                ),
                Positioned(
                  left: 2,
                  bottom: playerDockHeight + 14,
                  child: _sidePlayer(2, left: true),
                ),
                Positioned(
                  right: 5,
                  bottom: playerDockHeight + 25,
                  child: _actionRail(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: playerDockHeight,
                  child: _playerDock(),
                ),
                if (_msg != null)
                  Positioned(
                    left: 74,
                    right: 74,
                    bottom: playerDockHeight + 5,
                    child: _feedbackToast(),
                  ),
                if (_j.rodadaEncerrada)
                  Positioned.fill(child: _overlayFimRodada()),
                if (_expandedAvatarSeat != null)
                  Positioned.fill(
                    child: _avatarOverlay(_expandedAvatarSeat!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _meldArea(String dupla, {required bool top}) {
    final jogos = _j.jogosDupla[dupla]!;
    final vulnerabilidade = _vulnerabilidadeDaDupla(dupla);
    final podeBaixar = dupla == 'nos' &&
        _minhaVezAtiva &&
        _j.jaComprou &&
        _sel.length >= 3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: dupla == 'nos' ? _baixar : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A área de jogos sempre ocupa toda a largura útil da mesa.
          // Cada jogo conserva sua largura natural e o Wrap organiza os blocos
          // lado a lado; quando não há espaço, o próximo jogo desce de linha.
          final larguraUtil = max(0.0, constraints.maxWidth - 20);

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: jogos.isEmpty
                    ? Center(
                        child: AnimatedOpacity(
                          opacity: podeBaixar ? 1 : 0.22,
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            podeBaixar
                                ? 'TOQUE NO FELTRO PARA BAIXAR'
                                : (top ? 'ELES' : 'NÓS'),
                            style: TextStyle(
                              color: podeBaixar ? _mPurpleHi : _mGold,
                              fontSize: podeBaixar ? 9 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(10, 40, 10, 7),
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: larguraUtil,
                            maxWidth: larguraUtil,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.start,
                            runAlignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            spacing: 6,
                            runSpacing: 7,
                            children: [
                              for (var index = 0;
                                  index < jogos.length;
                                  index++)
                                _meldWidget(dupla, index, jogos[index]),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 6,
                left: 7,
                right: 7,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _areaLabel(top ? 'ELES' : 'NÓS', top: top),
                      if (vulnerabilidade != null) ...[
                        const SizedBox(width: 7),
                        _vulnerabilityBadge(vulnerabilidade),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _areaLabel(String label, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x88000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x337D5A24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: top ? const Color(0xFFD7A45A) : const Color(0xFFC67BFF),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _vulnerabilityBadge(int valor) {
    final accent = valor >= 95
        ? const Color(0xFFE86A80)
        : const Color(0xFFE5B84F);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xEE160D12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent, width: 1),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.45), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: accent, size: 12),
            const SizedBox(width: 4),
            Text(
              'VULNERABILIDADE +$valor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7.4,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meldWidget(String dupla, int index, List<Carta> cartas) {
    const cardWidth = 64.0;
    const cardHeight = 96.0;
    // As cartas mantêm o tamanho aprovado. A compactação vem somente da
    // sobreposição: ficam aparentes principalmente o número e o naipe.
    const step = 17.0;
    final count = cartas.length;
    final totalWidth = cardWidth + (count - 1) * step;
    final sash = _sashDeMeld(cartas);
    final celebrating = _celebratingMeldKey == '$dupla-$index';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (dupla == 'nos' &&
            _sel.isNotEmpty &&
            _minhaVezAtiva &&
            _j.jaComprou) {
          _estender(index);
        } else {
          _showMeldZoom(dupla, index);
        }
      },
      child: AnimatedScale(
        scale: celebrating ? 1.08 : 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: celebrating ? const Color(0x249D43D8) : Colors.transparent,
            boxShadow: celebrating
                ? const [
                    BoxShadow(color: Color(0xAA9D43D8), blurRadius: 22),
                    BoxShadow(color: Color(0x88E5B84F), blurRadius: 14),
                  ]
                : null,
          ),
          child: SizedBox(
            width: totalWidth,
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < count; i++)
                  Positioned(
                    left: i * step,
                    top: 0,
                    child: _frontCard(
                      cartas[i],
                      width: cardWidth,
                      height: cardHeight,
                    ),
                  ),
                // O contador fica sobre o canto superior direito da última carta.
                Positioned(
                  top: -4,
                  right: -4,
                  child: _countCircle(count),
                ),
                // A classificação da canastra fica sobre as próprias cartas e
                // não cria uma linha externa nem aumenta o bloco do jogo.
                if (sash != Sash.nenhuma)
                  Positioned(
                    left: 1,
                    right: 1,
                    bottom: 2,
                    child: _canastraRibbon(sash, celebrating),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _canastraRibbon(Sash sash, bool celebrating) {
    final color = _sashColor(sash);
    return AnimatedScale(
      scale: celebrating ? 1.04 : 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.96),
              Color.lerp(color, Colors.black, 0.52)!.withOpacity(0.96),
            ],
          ),
          border: Border.all(color: _mGoldHi, width: 0.8),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.48), blurRadius: 7),
          ],
        ),
        child: Text(
          _sashLabel(sash),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.45,
          ),
        ),
      ),
    );
  }

  Widget _centralTray() {
    final podeComprar = _minhaVezAtiva && !_j.jaComprou;
    final podeDescartar = _minhaVezAtiva && _j.jaComprou && _sel.length == 1;
    final monteGlow = podeComprar ||
        (_lastPurchaseSource == 'monte' && _recentlyBoughtIds.isNotEmpty);
    final lixoGlow = podeDescartar ||
        (_lastPurchaseSource == 'lixo' && _recentlyBoughtIds.isNotEmpty);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: _mPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8C6729), width: 1.1),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _centralPile(
            label: 'MONTE',
            count: _j.monte.length,
            child: _backCard(width: 62, height: 93, glowing: monteGlow),
            onTap: _tapMonte,
          ),
          const SizedBox(width: 7),
          Expanded(child: _discardPile(glowing: lixoGlow)),
          const SizedBox(width: 7),
          _centralPile(
            label: 'MORTO\n(NÓS)',
            count: _j.mortos.isNotEmpty ? _j.mortos.first.length : 0,
            child: _j.mortos.isNotEmpty
                ? _backCard(width: 62, height: 93)
                : _emptyCard(width: 62, height: 93),
          ),
          const SizedBox(width: 7),
          _centralPile(
            label: 'MORTO\n(ELES)',
            count: _j.mortos.length > 1 ? _j.mortos[1].length : 0,
            child: _j.mortos.length > 1
                ? _backCard(width: 62, height: 93)
                : _emptyCard(width: 62, height: 93),
          ),
        ],
      ),
    );
  }

  Widget _centralPile({
    required String label,
    required int count,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(top: -7, right: -7, child: _countCircle(count)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFEADBB7),
            fontSize: 7.2,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    return onTap == null
        ? content
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          );
  }

  Widget _discardPile({required bool glowing}) {
    const cardWidth = 62.0;
    const cardHeight = 93.0;
    const step = 19.0;
    final cards = _j.lixo;
    final totalWidth = cards.isEmpty
        ? cardWidth
        : cardWidth + (cards.length - 1) * step;
    return GestureDetector(
      onTap: _tapLixo,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: glowing
                      ? const [
                          BoxShadow(color: Color(0xAA9D43D8), blurRadius: 13),
                          BoxShadow(color: Color(0x66E5B84F), blurRadius: 8),
                        ]
                      : null,
                ),
                child: cards.isEmpty
                    ? _emptyCard(width: cardWidth, height: cardHeight)
                    : SingleChildScrollView(
                        controller: _discardScroll,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: totalWidth,
                          height: cardHeight,
                          child: Stack(
                            children: [
                              for (var i = 0; i < cards.length; i++)
                                Positioned(
                                  left: i * step,
                                  child: _frontCard(
                                    cards[i],
                                    width: cardWidth,
                                    height: cardHeight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: -7,
                right: -7,
                child: _countCircle(cards.length),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'LIXO ABERTO',
            style: TextStyle(
              color: Color(0xFFEADBB7),
              fontSize: 7.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _frontCard(
    Carta carta, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
        border: Border.all(color: const Color(0x55FFFFFF), width: 0.7),
        boxShadow: const [
          BoxShadow(color: Color(0x77000000), blurRadius: 5, offset: Offset(1, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        _cartaAsset(carta),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _backCard({
    required double width,
    required double height,
    bool glowing = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.1),
        gradient: glowing
            ? const LinearGradient(colors: [_mPurpleHi, _mGoldHi])
            : const LinearGradient(colors: [_mGoldHi, Color(0xFF694317)]),
        boxShadow: glowing
            ? const [
                BoxShadow(color: Color(0xAA9D43D8), blurRadius: 13),
                BoxShadow(color: Color(0x66E5B84F), blurRadius: 8),
              ]
            : const [
                BoxShadow(color: Color(0x77000000), blurRadius: 5, offset: Offset(1, 2)),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.08),
        child: Image.asset(
          _cardBackAsset,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _emptyCard({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x12000000),
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: const Color(0x558C6729), width: 1),
      ),
      child: const Icon(Icons.style_outlined, color: Color(0x447B3F91), size: 25),
    );
  }

  Widget _countCircle(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: count < 10 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: count < 10 ? null : BorderRadius.circular(12),
        color: const Color(0xEE080808),
        border: Border.all(color: _mGold, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 5),
        ],
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _mGoldHi,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _sidePlayer(int seat, {required bool left}) {
    final active = _j.vez == seat && !_j.rodadaEncerrada;
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedAvatarSeat = seat),
            child: AnimatedScale(
              scale: active ? 1.18 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: _avatarCircle(seat, size: 46, active: active),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              _j.apelidos[seat].toUpperCase(),
              style: TextStyle(
                color: active ? _mPurpleHi : const Color(0xFFEADCC1),
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          _miniHiddenHand(seat, expanded: active, left: left),
          if (active) ...[
            const SizedBox(height: 4),
            _turnBadge(compact: true),
          ],
        ],
      ),
    );
  }

  Widget _miniHiddenHand(int seat,
      {required bool expanded, required bool left}) {
    final count = _j.maos[seat].length;
    final shown = min(count, 5);
    const cardWidth = 25.0;
    const cardHeight = 38.0;
    final step = expanded ? 12.0 : 7.0;
    final width = cardWidth + max(0, shown - 1) * step;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: width,
          height: cardHeight,
          child: Stack(
            children: [
              for (var i = 0; i < shown; i++)
                Positioned(
                  left: i * step,
                  child: _backCard(width: cardWidth, height: cardHeight),
                ),
            ],
          ),
        ),
        Positioned(
          top: -7,
          right: -8,
          child: _countCircle(count),
        ),
      ],
    );
  }

  Widget _avatarCircle(int seat,
      {required double size, required bool active}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.25, -0.35),
          colors: [Color(0xFF4E2E65), Color(0xFF140C17)],
        ),
        border: Border.all(
          color: active ? _mPurpleHi : _mGold,
          width: active ? 2.8 : 2,
        ),
        boxShadow: active
            ? const [
                BoxShadow(color: Color(0xAA9D43D8), blurRadius: 14),
                BoxShadow(color: Color(0x66E5B84F), blurRadius: 8),
              ]
            : const [
                BoxShadow(color: Color(0x77000000), blurRadius: 5, offset: Offset(0, 2)),
              ],
      ),
      child: Text(
        _j.avatares[seat],
        style: TextStyle(fontSize: size * 0.42, color: _mGoldHi),
      ),
    );
  }

  Widget _turnBadge({bool compact = false}) {
    final danger = _turnSeconds <= 10;
    final size = compact ? 33.0 : 52.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF090909),
        border: Border.all(
          color: danger ? const Color(0xFFFF5D68) : _mPurpleHi,
          width: compact ? 2 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (danger ? const Color(0xFFFF5D68) : _mPurple)
                .withOpacity(0.55),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_turnSeconds',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 12 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (!compact)
            const Text(
              'SEG',
              style: TextStyle(
                color: Color(0xFFD8C8E8),
                fontSize: 6,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railButton(Icons.chat_bubble_rounded, () {
          setState(() => _msg = 'Chat — ligação final com o Claude.');
        }),
        const SizedBox(height: 7),
        _railButton(Icons.sentiment_satisfied_alt_rounded, () {
          setState(() => _msg = 'Expressões — ligação final com o Claude.');
        }),
        const SizedBox(height: 7),
        _railButton(
          _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          () => setState(() => _soundEnabled = !_soundEnabled),
        ),
      ],
    );
  }

  Widget _railButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xEE0A0A0A),
          border: Border.all(color: _mGold, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: _mGoldHi, size: 20),
      ),
    );
  }

  Widget _playerDock() {
    final active = _j.vez == 0 && !_j.rodadaEncerrada;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 137,
          child: _hand(),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _expandedAvatarSeat = 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: active ? 1.18 : 1,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: _avatarCircle(0, size: 61, active: active),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xEE090909),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _mGold, width: 1),
                      boxShadow: const [
                        BoxShadow(color: Color(0x669D43D8), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOCÊ',
                          style: TextStyle(
                            color: active ? _mPurpleHi : _mGoldHi,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${_j.placar['nos']} pontos',
                          style: const TextStyle(
                            color: Color(0xFFDCCDAA),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    _turnBadge(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hand() {
    final hand = _j.maos[0];
    final count = hand.length;
    if (count == 0) return const SizedBox();

    const cardWidth = 88.0;
    const cardHeight = 132.0;
    const step = 47.0;
    const selectedLift = 15.0;
    final active = _minhaVezAtiva;
    final totalWidth = cardWidth + (count - 1) * step;

    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) {
        final priorityA = (_sel.contains(a) ? 2 : 0) +
            (_recentlyBoughtIds.contains(hand[a].id) ? 1 : 0);
        final priorityB = (_sel.contains(b) ? 2 : 0) +
            (_recentlyBoughtIds.contains(hand[b].id) ? 1 : 0);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        return a.compareTo(b);
      });

    final cards = SizedBox(
      width: totalWidth,
      height: cardHeight + selectedLift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final index in order)
            Positioned(
              left: index * step,
              bottom: 0,
              child: GestureDetector(
                onTap: active ? () => _tapCard(index) : null,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  offset: Offset(
                    0,
                    _sel.contains(index)
                        ? -selectedLift / cardHeight
                        : (_recentlyBoughtIds.contains(hand[index].id)
                            ? -7 / cardHeight
                            : 0),
                  ),
                  child: _handCard(
                    hand[index],
                    selected: _sel.contains(index),
                    purchased: _recentlyBoughtIds.contains(hand[index].id),
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -7,
            right: -8,
            child: _countCircle(count),
          ),
        ],
      ),
    );

    return ClipRect(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: Offset(0, active ? 0 : 0.50),
        child: SingleChildScrollView(
          controller: _handScroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, selectedLift, 14, 0),
          child: cards,
        ),
      ),
    );
  }

  Widget _handCard(
    Carta carta, {
    required bool selected,
    required bool purchased,
    required double width,
    required double height,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: purchased ? 1.05 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        height: height,
        padding: EdgeInsets.all(selected || purchased ? 2 : 0.8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: purchased
              ? const LinearGradient(colors: [_mGoldHi, _mPurpleHi, _mGold])
              : (selected
                  ? const LinearGradient(colors: [_mPurpleHi, _mGoldHi, _mPurple])
                  : const LinearGradient(colors: [Color(0x99FFFFFF), Color(0x557D5A24)])),
          boxShadow: purchased
              ? const [
                  BoxShadow(color: Color(0xCCF4D66E), blurRadius: 20, spreadRadius: 1),
                  BoxShadow(color: Color(0xAA9D43D8), blurRadius: 15),
                ]
              : (selected
                  ? const [
                      BoxShadow(color: Color(0xAA9D43D8), blurRadius: 14),
                      BoxShadow(color: Color(0x88E5B84F), blurRadius: 7),
                    ]
                  : const [
                      BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, -2)),
                    ]),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _cartaAsset(carta),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            if (purchased)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white, _mGold]),
                    boxShadow: [BoxShadow(color: _mGoldHi, blurRadius: 8)],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 10,
                    color: Color(0xFF4E2D05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackToast() {
    final text = _msg ?? '';
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xF2140D16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xAA9D43D8)),
          boxShadow: const [
            BoxShadow(color: Color(0x779D43D8), blurRadius: 11),
          ],
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF3E9FF),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _showMeldZoom(String dupla, int index) {
    final jogos = _j.jogosDupla[dupla]!;
    if (index < 0 || index >= jogos.length) return;
    final cards = List<Carta>.from(jogos[index]);
    final sash = _sashDeMeld(cards);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar jogo ampliado',
      barrierColor: const Color(0xCC000000),
      transitionDuration: const Duration(milliseconds: 230),
      pageBuilder: (_, __, ___) {
        const width = 92.0;
        const height = 138.0;
        const step = 49.0;
        final total = width + (cards.length - 1) * step;
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
                    decoration: BoxDecoration(
                      color: const Color(0xF4120D14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _mGold, width: 1.3),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAA9D43D8), blurRadius: 22),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              dupla == 'nos' ? 'JOGO — NÓS' : 'JOGO — ELES',
                              style: const TextStyle(
                                color: _mGoldHi,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            _countCircle(cards.length),
                          ],
                        ),
                        if (sash != Sash.nenhuma) ...[
                          const SizedBox(height: 7),
                          _canastraRibbon(sash, false),
                        ],
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: total,
                            height: height,
                            child: Stack(
                              children: [
                                for (var i = 0; i < cards.length; i++)
                                  Positioned(
                                    left: i * step,
                                    child: _frontCard(
                                      cards[i],
                                      width: width,
                                      height: height,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Toque fora para recolher',
                          style: TextStyle(
                            color: Color(0xFFBFAECD),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _avatarOverlay(int seat) {
    return GestureDetector(
      onTap: () => setState(() => _expandedAvatarSeat = null),
      child: Container(
        color: const Color(0xB8000000),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          builder: (_, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: Container(
            width: 190,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
            decoration: BoxDecoration(
              color: const Color(0xF4150D18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _mGold, width: 1.4),
              boxShadow: const [
                BoxShadow(color: Color(0xAA9D43D8), blurRadius: 25),
                BoxShadow(color: Color(0x66E5B84F), blurRadius: 14),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _avatarCircle(
                  seat,
                  size: seat == 0 ? 122 : 92,
                  active: _j.vez == seat && !_j.rodadaEncerrada,
                ),
                const SizedBox(height: 12),
                Text(
                  _j.apelidos[seat].toUpperCase(),
                  style: const TextStyle(
                    color: _mPurpleHi,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_j.maos[seat].length} cartas na mão',
                  style: const TextStyle(
                    color: Color(0xFFE2D4B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Toque fora para fechar',
                  style: TextStyle(
                    color: Color(0xFFB6A8BE),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DetalhePontuacaoVM _detalhePontuacao(String dupla) {
    final rodada = _j.pontosRodada;
    if (rodada == null) return DetalhePontuacaoVM.vazio();
    final bruto = rodada[dupla];
    if (bruto is! Map<String, dynamic>) return DetalhePontuacaoVM.vazio();
    final detalhe = bruto['detalhe'];
    final det = detalhe is Map<String, dynamic>
        ? detalhe
        : <String, dynamic>{};
    return DetalhePontuacaoVM(
      total: (bruto['total'] as int?) ?? 0,
      canastras: (bruto['canastras'] as int?) ?? 0,
      cartasBaixadas: (det['baixadas'] as int?) ?? 0,
      bonusBatida: (bruto['bonusBatida'] as int?) ?? 0,
      descontoMao: (bruto['descontoMao'] as int?) ?? 0,
      penalidadeMorto: (bruto['penalidadeMorto'] as int?) ?? 0,
      limpas: (det['limpas'] as int?) ?? 0,
      sujas: (det['sujas'] as int?) ?? 0,
      de500: (det['de500'] as int?) ?? 0,
      de1000: (det['asAas'] as int?) ?? 0,
    );
  }

  List<JogadorResultadoVM> _jogadoresResultado() {
    return List<JogadorResultadoVM>.generate(
      _j.apelidos.length,
      (seat) => JogadorResultadoVM(
        assento: seat,
        nome: _j.apelidos[seat],
        avatar: _j.avatares[seat],
        souEu: seat == 0,
      ),
    );
  }

  void _continuarRodada() {
    setState(() {
      _j.novaRodada();
      _sel.clear();
      _msg = null;
      _conviteRevancheEnviado = false;
      _anuncioAssistido = false;
      _syncTurnClock(force: true);
    });
  }

  void _convidarRevanche() {
    setState(() {
      _conviteRevancheEnviado = true;
      _msg = 'Convite de revanche enviado para a mesa.';
    });
  }

  void _jogarNovamente() {
    setState(() {
      _j = _novoJogo();
      _sel.clear();
      _msg = null;
      _conviteRevancheEnviado = false;
      _anuncioAssistido = false;
      _syncTurnClock(force: true);
    });
  }

  void _adicionarAmigo(int seat) {
    if (seat == 0) return;
    setState(() {
      _amizades[seat] = EstadoAmizade.enviado;
      _msg = 'Convite de amizade enviado para ${_j.apelidos[seat]}.';
    });
  }

  void _verAnuncioRecompensado() {
    if (!_anuncioDisponivel || _anuncioAssistido || _assinanteSemAnuncios) {
      return;
    }
    setState(() {
      _anuncioAssistido = true;
      _msg = 'Recompensa do anúncio registrada na prévia.';
    });
  }

  void _voltarAoLobby() {
    Navigator.of(context).pop();
  }

  Widget _overlayFimRodada() {
    final finalPartida = _j.encerrada;
    String title;
    if (finalPartida) {
      title = _j.placar['nos']! >= _j.placar['eles']!
          ? 'NÓS VENCEMOS!'
          : 'ELES VENCERAM';
    } else if (_j.duplaQueBateu == 'nos') {
      title = 'NÓS BATEMOS!';
    } else if (_j.duplaQueBateu == 'eles') {
      title = 'ELES BATERAM';
    } else {
      title = 'BARALHO ESGOTADO';
    }

    return ResultadoPartidaScreen(
      fimPartida: finalPartida,
      mesaVip: _mesaVip,
      rodada: _j.rodada,
      titulo: title,
      pontosNos: _j.placar['nos'] ?? 0,
      pontosEles: _j.placar['eles'] ?? 0,
      detalheNos: _detalhePontuacao('nos'),
      detalheEles: _detalhePontuacao('eles'),
      jogadores: _jogadoresResultado(),
      amizades: Map<int, EstadoAmizade>.unmodifiable(_amizades),
      conviteRevancheEnviado: _conviteRevancheEnviado,
      anuncioDisponivel: _anuncioDisponivel,
      anuncioAssistido: _anuncioAssistido,
      assinanteSemAnuncios: _assinanteSemAnuncios,
      recompensaAnuncio: '+50 fichas de continuidade',
      onContinuar: _continuarRodada,
      onConvidarRevanche: _convidarRevanche,
      onJogarNovamente: _jogarNovamente,
      onVoltarLobby: _voltarAoLobby,
      onAdicionarAmigo: _adicionarAmigo,
      onVerAnuncio: _verAnuncioRecompensado,
    );
  }

}

enum Sash { nenhuma, limpa, suja, n500, n1000 }
