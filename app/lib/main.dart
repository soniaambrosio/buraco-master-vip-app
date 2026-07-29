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
import 'screens/recompensas_screen.dart';
import 'screens/mesa_screen.dart' as mesa_visual;
import 'screens/configurar_mesa_screen.dart';
import 'screens/amigos_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/mesa_vip_preview_screen.dart';

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
      home: const SplashScreen(),
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
    // JOGAR → Configurar Mesa (visual do Codex) → "Criar mesa" abre a MesaScreen
    // jogável (motor do Claude). Fluxo real do jogo.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ConfigMesaPreviewHost()),
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
      case 'jogar':
        _abrirMesa();
        break;
      case 'amigos':
        _abrirAmigos();
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
        _aviso('Loja VIP — integração fica com o Claude');
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
      onAbrirLobby: () => _aviso('Lobby — integração fica com o Claude'),
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

class _MesaCodexPreviewHost extends StatefulWidget {
  const _MesaCodexPreviewHost();

  @override
  State<_MesaCodexPreviewHost> createState() => _MesaCodexPreviewHostState();
}

class _MesaCodexPreviewHostState extends State<_MesaCodexPreviewHost> {
  Set<String> _selecionadas = const {'mao_as'};

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1000),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _alternarCarta(String id) {
    setState(() {
      final novas = Set<String>.from(_selecionadas);
      if (!novas.add(id)) novas.remove(id);
      _selecionadas = novas;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = mesa_visual.MesaVM.mock(selecionadas: _selecionadas);
    return mesa_visual.MesaScreen(
      vm: vm,
      onMenu: () => _aviso('Menu da partida — conexão entra com o Claude'),
      onChat: () => _aviso('Chat da mesa — conexão entra com o Claude'),
      onComprarMonte: () => _aviso('Comprar do monte'),
      onPegarLixo: () => _aviso('Pegar o lixo'),
      onTapCarta: _alternarCarta,
      onBaixar: () => _aviso('Baixar cartas selecionadas'),
      onEstender: (meldId) => _aviso('Estender no jogo $meldId'),
      onDescartar: () => _aviso('Descartar carta selecionada'),
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

  void _abrirRanking() {
    // Prévia visual do Ranking (host do Codex). O Claude troca por RankingPage
    // ao conectar os dados reais.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _RankingPreviewHost()),
    );
  }

  void _abrirMesaVip() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MesaVipPreviewScreen()),
    );
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
          .push(MaterialPageRoute(builder: (_) => const MesaScreen())),
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
      ['🛍️', 'Loja VIP'], ['👑', 'Mesa VIP'], ['📖', 'Como jogar'], ['⚙️', 'Ajustes'],
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
              : label == 'Mesa VIP'
                  ? _abrirMesaVip
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
      onAbrirHall: () => _aviso('Hall dos Imortais — conexão entra com o Claude'),
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
const String _dorsoAsset = 'assets/baralho/dorso_publica.webp';
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

  // ===== VULNERABILIDADE (regra do motor: 1500 -> 75 -> 90, teto 90) =====
  static const int _limiarVulneravel = 1500;
  Map<String, int> _rodadasVuln = {'nos': 0, 'eles': 0};
  void _reavaliarVulnerabilidade() {
    for (final d in ['nos', 'eles']) {
      if (placar[d]! >= _limiarVulneravel) {
        _rodadasVuln[d] = (_rodadasVuln[d]! + 1).clamp(0, 2);
      }
    }
  }
  int vulneravelMinimo(String dupla) {
    final r = _rodadasVuln[dupla] ?? 0;
    if (r <= 0) return 0;
    return r == 1 ? 75 : 90;
  }
  bool vulneravel(String dupla) => vulneravelMinimo(dupla) > 0;
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
    _reavaliarVulnerabilidade();
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

  // ORGANIZAR A MÃO: agrupa por naipe e ordena cada naipe por sequência (A,2,3…K),
  // depois INTERCALA AS CORES (vermelho ↔ preto) pra melhor visualização — nunca deixa
  // dois naipes da mesma cor colados quando dá pra evitar. O 2 fica na posição natural
  // dele dentro do naipe (ajuda a enxergar A-2-3); coringas sem naipe (JOKER) vão pro fim.
  static const _naipesVermelhos = ['copas', 'ouros'];
  static const _naipesPretos = ['espadas', 'paus'];
  void ordenar(int assento) {
    // 1) separa por naipe e ordena cada grupo por valor (A→K)
    final grupos = <String, List<Carta>>{};
    final coringasSemNaipe = <Carta>[]; // JOKER puro (naipe null)
    for (final c in maos[assento]) {
      if (c.naipe == null) {
        coringasSemNaipe.add(c);
      } else {
        (grupos[c.naipe!] ??= <Carta>[]).add(c);
      }
    }
    for (final g in grupos.values) {
      g.sort((a, b) => _ordem.indexOf(a.valor) - _ordem.indexOf(b.valor));
    }
    // 2) monta as filas de grupos por cor (só naipes presentes)
    final vermelhos = [for (final n in _naipesVermelhos) if (grupos[n] != null) grupos[n]!];
    final pretos = [for (final n in _naipesPretos) if (grupos[n] != null) grupos[n]!];
    // 3) intercala vermelho ↔ preto começando pela cor com mais grupos (empate = vermelho)
    final resultado = <Carta>[];
    var iv = 0, ip = 0;
    var vezVermelho = vermelhos.length >= pretos.length;
    while (iv < vermelhos.length || ip < pretos.length) {
      if (vezVermelho && iv < vermelhos.length) {
        resultado.addAll(vermelhos[iv++]);
      } else if (!vezVermelho && ip < pretos.length) {
        resultado.addAll(pretos[ip++]);
      } else if (iv < vermelhos.length) {
        resultado.addAll(vermelhos[iv++]);
      } else {
        resultado.addAll(pretos[ip++]);
      }
      vezVermelho = !vezVermelho;
    }
    resultado.addAll(coringasSemNaipe); // JOKER no fim
    maos[assento] = resultado;
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

// paleta da mesa verde
const _mGold = Color(0xFFE0B45D);
const _mGoldHi = Color(0xFFF4D47F);
const _mCard = Color(0xFFF3F0E8);
const _mRed = Color(0xFF9C302E);
const _mBlack = Color(0xFF2B2B28);
const _mMaroon1 = Color(0xFF7A2F22);
const _mMaroon2 = Color(0xFF471B11);
const _mPill = Color(0xFF123F30);
const _mPillTx = Color(0xFFE7D3A0);
const _mBox = Color(0xFF082E22);
const _mRail = Color(0xFF8A642B);

Color _corCarta(Carta c) =>
    c.valor == 'JOKER' ? const Color(0xFFB8860B) : (_cartaVermelha(c) ? _mRed : _mBlack);

class _CrossHatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x09000000)
      ..strokeWidth = 0.8;
    final shine = Paint()
      ..color = const Color(0x087FE0B2)
      ..strokeWidth = 0.7;
    for (double x = -size.height; x < size.width + size.height; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }
    for (double x = 0; x < size.width + size.height; x += 19) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), shine);
    }
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.78,
      height: size.height * 0.58,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = const Color(0x0AEDD69B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 0.78,
      colors: const [Color(0x00000000), Color(0x22000000)],
      stops: const [0.55, 1],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      onRecarregar: () => setState(() => _vm = AmigosVM.mock(aba: _vm.aba)),
    );
  }
}

// ===================== CONFIGURAR MESA (host) =====================
// Visual do Codex (ConfigurarMesaScreen). O Claude conecta a criação real da
// mesa depois; por ora "Criar mesa" abre a MesaScreen jogável (motor do Claude).
class _ConfigMesaPreviewHost extends StatefulWidget {
  const _ConfigMesaPreviewHost();

  @override
  State<_ConfigMesaPreviewHost> createState() => _ConfigMesaPreviewHostState();
}

class _ConfigMesaPreviewHostState extends State<_ConfigMesaPreviewHost> {
  ConfigMesaVM _vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);

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
        // Criação real da mesa fica com o Claude; por ora abre a mesa jogável.
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MesaScreen()),
        );
      },
    );
  }
}

class MesaScreen extends StatefulWidget {
  const MesaScreen({super.key});
  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> with SingleTickerProviderStateMixin {
  late Jogo _j;
  final Set<int> _sel = {};
  bool _botsRodando = false;
  String? _msg;
  Set<String> _recentlyBoughtIds = <String>{};
  String? _lastPurchaseSource;
  Timer? _purchaseGlowTimer;
  late final AnimationController _pulse; // brilho pulsante da vulnerabilidade

  // --- ÁUDIO: mp3 reais fornecidos pela Sônia (em assets/sons/) ---
  // dois "canais": um pro deslize de carta, outro pros eventos (canastra/morto/erro),
  // assim um não corta o outro se acontecerem quase juntos.
  AudioPlayer? _pCarta, _pEvento;

  @override
  void initState() {
    super.initState();
    _j = Jogo(
      const ['você', 'Cláudia', 'Mateus', 'Sofia'],
      const ['👑', '🙂', '😎', 'RN'],
      const ['🐶', '🐰', '🦊', '🐱'],
    );
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    try {
      _pCarta = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pEvento = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    } catch (_) {/* sem áudio, o jogo segue normal */}
  }

  @override
  void dispose() {
    _purchaseGlowTimer?.cancel();
    _pulse.dispose();
    _handScroll.dispose();
    _pCarta?.dispose();
    _pEvento?.dispose();
    super.dispose();
  }

  void _play(AudioPlayer? p, String arquivo, double vol) {
    if (p == null) return;
    try { p.stop(); p.play(AssetSource('sons/$arquivo'), volume: vol); } catch (_) {}
  }

  // deslize de carta: comprar, descartar, baixar simples, estender, jogadas dos robôs
  void _somCarta() => _play(_pCarta, 'carta.mp3', 0.95);
  void _somCompra() => _play(_pCarta, 'carta.mp3', 1.0);
  void _somErro() => _play(_pEvento, 'erro.mp3', 0.9);
  void _somMorto() => _play(_pEvento, 'morto.mp3', 1.0);
  void _somCanastra(String? tipo) {
    switch (tipo) {
      case 'as_a_as': _play(_pEvento, 'canastra1000.mp3', 1.0); break;
      case 'de_500':  _play(_pEvento, 'canastra500.mp3', 1.0); break;
      case 'suja':    _play(_pEvento, 'canastra_suja.mp3', 1.0); break;
      default:        _play(_pEvento, 'canastra200.mp3', 1.0); break; // limpa (e demais canastras)
    }
  }

  // decide o som de uma jogada (baixar/estender):
  // bater = SILÊNCIO por enquanto (a Sônia vai mandar um som de vitória);
  // formou canastra nova → fanfarra da canastra; pegou o morto → som do morto; senão → carta.
  void _somJogada(Map<String, dynamic> res, {required bool novaCanastra}) {
    if (res['bateu'] == true) { _somVitoria(); return; } // BATEU! (som de vitória da Sônia)
    if (novaCanastra) { _somCanastra(res['tipo'] as String?); return; }
    if (res['pegouMorto'] == true) { _somMorto(); return; }
    _somCarta();
  }

  void _somVitoria() => _play(_pEvento, 'vitoria.mp3', 1.0);

  bool get _minhaVezAtiva => _j.suaVez && !_j.rodadaEncerrada && !_botsRodando;

  void _tapCard(int i) {
    setState(() {
      if (_sel.contains(i)) { _sel.remove(i); } else { _sel.add(i); }
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

  void _tapMonte() {
    if (!_minhaVezAtiva || _j.jaComprou) return;
    final antes = _j.maos[0].map((c) => c.id).toSet();
    if (!_j.comprarMonte(0)) return;
    _j.ordenar(0);
    final novos = _j.maos[0].where((c) => !antes.contains(c.id)).map((c) => c.id).toSet();
    _mostrarCompra(novos, 'monte');
    _somCompra();
  }

  Future<void> _tapLixo() async {
    if (!_minhaVezAtiva) return;
    if (!_j.jaComprou) {
      // antes de comprar: tocar no lixo PEGA o monte de descarte inteiro
      final antes = _j.maos[0].map((c) => c.id).toSet();
      final res = _j.comprarLixo(0);
      if (res['ok'] != true) { setState(() => _msg = res['erro'] as String?); _somErro(); return; }
      _j.ordenar(0);
      final novos = _j.maos[0].where((c) => !antes.contains(c.id)).map((c) => c.id).toSet();
      _sel.clear();
      _mostrarCompra(novos, 'lixo');
      _somCompra();
      return;
    }
    if (_sel.length != 1) { return; }
    final id = _j.maos[0][_sel.first].id;
    final mortoAntes = _j.mortoPego['nos'] == true;
    final err = _j.descartar(0, id);
    if (err != null) { setState(() => _msg = err); _somErro(); return; }
    // descarte que zerou a mão e pegou o morto → som do morto; batida NOSSA → vitória; senão → carta
    if (!mortoAntes && _j.mortoPego['nos'] == true) { _somMorto(); }
    else if (_j.rodadaEncerrada && _j.duplaQueBateu == 'nos') { _somVitoria(); }
    else if (!_j.rodadaEncerrada) { _somCarta(); }
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() { _sel.clear(); _msg = null; });
    await _rodarBots();
  }

  void _baixar() {
    if (!_minhaVezAtiva || !_j.jaComprou) return;
    if (_sel.length < 3) { return; }
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();
    final res = _j.baixar(0, ids);
    if (res['ok'] != true) { setState(() => _msg = res['erro'] as String?); _somErro(); return; }
    _j.ordenar(0);
    // jogo baixado NOVO: se já nasce com 7+ cartas, é canastra
    final tipo = res['tipo'] as String?;
    _somJogada(res, novaCanastra: tipo != null && tipo != 'aberta');
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = res['bateu'] == true ? '🎉 Você BATEU!' : (res['pegouMorto'] == true ? 'Mão zerou — você pegou o MORTO!' : 'Jogo baixado! 🎴');
    });
  }

  void _estender(int indiceJogo) {
    if (!_minhaVezAtiva || !_j.jaComprou) return;
    if (_sel.isEmpty) { return; }
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();
    final jogosNos = _j.jogosDupla['nos']!;
    final antes = (indiceJogo >= 0 && indiceJogo < jogosNos.length) ? jogosNos[indiceJogo].length : 0;
    final res = _j.estender(0, indiceJogo, ids);
    if (res['ok'] != true) { setState(() => _msg = res['erro'] as String?); _somErro(); return; }
    _j.ordenar(0);
    // virou canastra só quando cruza de <7 pra >=7 (estender uma canastra já formada = carta)
    final depois = jogosNos[indiceJogo].length;
    _somJogada(res, novaCanastra: antes < 7 && depois >= 7);
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = res['bateu'] == true ? '🎉 Você BATEU!' : (res['pegouMorto'] == true ? 'Mão zerou — você pegou o MORTO!' : 'Jogo estendido! ➕');
    });
  }

  Future<void> _rodarBots() async {
    _botsRodando = true;
    while (_j.vez != 0 && !_j.rodadaEncerrada) {
      await Future.delayed(const Duration(milliseconds: 650));
      _j.botJoga(_j.vez);
      _somCarta();
      if (mounted) setState(() {});
    }
    _botsRodando = false;
    if (_j.rodadaEncerrada) {
      _j.contarPontos();
      if (_j.duplaQueBateu == 'nos') _somVitoria(); // parceiro bateu = vitória nossa
    }
    if (mounted) setState(() {});
  }

  // sash a partir do tipo de canastra
  Sash _sashDeMeld(List<Carta> m) {
    if (m.length < 7) return Sash.nenhuma;
    final r = _j.validarSequencia(m);
    if (r['valido'] != true) return Sash.nenhuma;
    switch (r['tipo']) {
      case 'limpa': return Sash.limpa;
      case 'suja': return Sash.suja;
      case 'de_500':
      case 'as_a_as': return Sash.n500;
      default: return Sash.nenhuma;
    }
  }

  // ===== ADAPTER: liga o motor (Jogo) ao visual novo do Codex (mesa_visual) =====
  mesa_visual.CartaVM _cvm(Carta c) => mesa_visual.CartaVM(
        id: c.id,
        valor: c.valor == 'JOKER' ? '★' : c.valor,
        naipe: c.naipe ?? '',
        coringa: c.ehCoringa,
      );

  mesa_visual.TipoMeld _tipoMeld(List<Carta> m) {
    if (m.length < 7) return mesa_visual.TipoMeld.comum;
    final r = _j.validarSequencia(m);
    if (r['valido'] != true) return mesa_visual.TipoMeld.comum;
    switch (r['tipo']) {
      case 'limpa':
        return mesa_visual.TipoMeld.limpa;
      case 'suja':
        return mesa_visual.TipoMeld.suja;
      case 'de_500':
      case 'as_a_as':
        return mesa_visual.TipoMeld.de500;
      default:
        return mesa_visual.TipoMeld.comum;
    }
  }

  List<mesa_visual.Meld> _meldsDupla(String dupla) {
    final jogos = _j.jogosDupla[dupla]!;
    return [
      for (var i = 0; i < jogos.length; i++)
        mesa_visual.Meld(
          id: '${dupla}_$i',
          cartas: jogos[i].map(_cvm).toList(),
          tipo: _tipoMeld(jogos[i]),
          contagem: jogos[i].length,
        ),
    ];
  }

  mesa_visual.JogadorMesa _jogadorVM(int assento, bool ehVoce) {
    const nomes = ['você', 'Cláudia', 'Mateus', 'Sofia'];
    const numeros = [7, 2, 4, 3];
    const avatares = ['🐶', '🐰', '🦊', '🐱'];
    return mesa_visual.JogadorMesa(
      nome: nomes[assento],
      numero: numeros[assento],
      cartas: _j.maos[assento].length,
      avatar: avatares[assento],
      ehVoce: ehVoce,
    );
  }

  mesa_visual.MesaVM _buildMesaVM() {
    return mesa_visual.MesaVM(
      titulo: 'BURACO MASTER VIP',
      meta: _j.metaPontos,
      modalidade: mesa_visual.Modalidade.aberto,
      rodada: _j.rodada,
      eles: mesa_visual.PlacarDupla(
        pontos: _j.placar['eles'] ?? 0,
        vulneravel: _j.vulneravel('eles'),
        vulneravelMinimo: _j.vulneravelMinimo('eles'),
      ),
      nos: mesa_visual.PlacarDupla(
        pontos: _j.placar['nos'] ?? 0,
        vulneravel: _j.vulneravel('nos'),
        vulneravelMinimo: _j.vulneravelMinimo('nos'),
      ),
      jogadoresEles: [_jogadorVM(1, false), _jogadorVM(3, false)],
      jogadoresNos: [_jogadorVM(2, false), _jogadorVM(0, true)],
      meldsEles: _meldsDupla('eles'),
      meldsNos: _meldsDupla('nos'),
      monte: mesa_visual.PilhaMonte(
        contagem: _j.monte.length,
        destaque: _minhaVezAtiva && !_j.jaComprou,
      ),
      lixo: mesa_visual.PilhaLixo(
        contagem: _j.lixo.length,
        topo: _j.lixo.isNotEmpty ? _cvm(_j.lixo.last) : null,
      ),
      mortosRestantes: _j.mortos.length,
      mao: _j.maos[0].map(_cvm).toList(),
      selecionadas: _sel.map((i) => _j.maos[0][i].id).toSet(),
      dica: _msg,
      minhaVez: _minhaVezAtiva,
    );
  }

  void _tapCartaPorId(String id) {
    final i = _j.maos[0].indexWhere((c) => c.id == id);
    if (i >= 0) _tapCard(i);
  }

  void _estenderPorId(String meldId) {
    if (!meldId.startsWith('nos_')) return;
    final i = int.tryParse(meldId.substring(4));
    if (i != null) _estender(i);
  }

  @override
  Widget build(BuildContext context) {
    return mesa_visual.MesaScreen(
      vm: _buildMesaVM(),
      onMenu: () {},
      onChat: () {},
      onComprarMonte: _tapMonte,
      onPegarLixo: _tapLixo,
      onTapCarta: _tapCartaPorId,
      onBaixar: _baixar,
      onEstender: _estenderPorId,
      onDescartar: _tapLixo,
    );
  }

  Widget _header() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF21160F), Color(0xFF100A07)],
            ),
            border: Border(bottom: BorderSide(color: Color(0x557D5A24), width: 1)),
            boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFF7D987), Color(0xFFB87B25)]),
                  border: Border.all(color: const Color(0xFFFFEDB2), width: 1),
                  boxShadow: const [BoxShadow(color: Color(0x66EFB94A), blurRadius: 8)],
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF3E2708), size: 20),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'BURACO MASTER VIP',
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xFFF4E5BC),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 62,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [Color(0xFF176C50), Color(0xFF0B3D2D)]),
                  border: Border.all(color: const Color(0xAA71D7AD)),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'MESA PÚBLICA',
                    style: TextStyle(color: Color(0xFFE8FFF4), fontSize: 6.8, fontWeight: FontWeight.w900, letterSpacing: 0.35),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _hIcon(Icons.menu_rounded),
              const SizedBox(width: 5),
              _hIcon(Icons.chat_bubble_outline_rounded),
            ]),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 62, child: _matchChip(Icons.flag_outlined, 'META', '${_j.metaPontos}')),
                const SizedBox(width: 4),
                SizedBox(width: 62, child: _matchChip(Icons.style_outlined, 'RODADA', '${_j.rodada}')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _hIcon(IconData icon) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF21170E),
          border: Border.all(color: const Color(0x668F6A31)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 17, color: const Color(0xFFE7D5A7)),
      );

  Widget _matchChip(IconData icon, String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 54),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: const Color(0xFF1B120B),
          border: Border.all(color: const Color(0x557D5A24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10.5, color: _mGold),
          const SizedBox(width: 3),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Color(0xFF9D8E6D), fontSize: 6.0, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(color: Color(0xFFF2E2B7), fontSize: 9.5, fontWeight: FontWeight.w900, height: 1)),
          ]),
        ]),
      );

  Widget _mesa() {
    return LayoutBuilder(builder: (context, cons) {
      // Geometria compacta: áreas superior e inferior dividem o espaço livre,
      // enquanto a faixa central usa altura fixa menor.
      final tableWidth = min(cons.maxWidth, 430.0);
      const handH = 120.0;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: tableWidth,
          child: Container(
            margin: const EdgeInsets.fromLTRB(7, 5, 7, 0),
            padding: const EdgeInsets.all(2.2),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2D287), Color(0xFF78541F), Color(0xFFD5AA55), Color(0xFF5B3C14)],
                stops: [0, 0.35, 0.72, 1],
              ),
              boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                border: Border.all(color: const Color(0xFF1B1108), width: 2),
                gradient: const RadialGradient(
                  center: Alignment(0, -0.16),
                  radius: 1.08,
                  colors: [Color(0xFF126247), Color(0xFF0A4533), Color(0xFF05261C)],
                  stops: [0, 0.58, 1],
                ),
              ),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _CrossHatch())),
                const Positioned.fill(child: Center(child: Icon(Icons.workspace_premium_rounded, size: 126, color: Color(0x08F7E0A6)))),
                Positioned.fill(
                  child: Column(children: [
                    Expanded(child: _areaJogo('eles')),
                    SizedBox(height: 92, child: _faixaCentral()),
                    Expanded(child: _areaJogo('nos', handReserve: handH + 6)),
                  ]),
                ),
                if (_msg != null)
                  Positioned(left: 16, right: 16, bottom: handH + 8, child: _feedbackToast()),
                Positioned(left: 0, right: 0, bottom: 0, height: handH, child: _hand()),
                if (_j.rodadaEncerrada) Positioned.fill(child: _overlayFimRodada()),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _feedbackToast() {
    final texto = _msg ?? '';
    final erro = texto.toLowerCase().contains('não') || texto.toLowerCase().contains('erro') || texto.toLowerCase().contains('selecione');
    final accent = erro ? const Color(0xFFFFC56E) : const Color(0xFFC99BFF);
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey<String>(texto),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [Color(0xF2281B12), Color(0xF2130D09)]),
            border: Border.all(color: accent.withValues(alpha: 0.62), width: 1.1),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 12), const BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Icon(erro ? Icons.info_outline_rounded : Icons.auto_awesome_rounded, color: accent, size: 17),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF3E8CE), fontSize: 9.5, fontWeight: FontWeight.w800, height: 1.15))),
          ]),
        ),
      ),
    );
  }

  Widget _areaJogo(String dupla, {double handReserve = 0}) {
    final eles = dupla == 'eles';
    return SizedBox(
      width: double.infinity,
      child: Column(children: [
        _teamRow(eles: eles),
        Expanded(child: _meldsBox(dupla, padTop: 5, padBottom: handReserve > 0 ? handReserve : 7)),
      ]),
    );
  }

  Widget _avatarCanto({required int a, required bool dir}) => _chip(a: a, dir: dir, play: a == 0);

  Widget _overlayFimRodada() {
    final venceu = _j.encerrada;
    final linhaNos = _linhaPlacar('nos');
    final linhaEles = _linhaPlacar('eles');
    String titulo;
    if (venceu) {
      final nosVenceu = _j.placar['nos']! >= _j.placar['eles']!;
      titulo = nosVenceu ? 'NÓS VENCEMOS!' : 'ELES VENCERAM';
    } else if (_j.duplaQueBateu == 'nos') {
      titulo = 'NÓS BATEMOS!';
    } else if (_j.duplaQueBateu == 'eles') {
      titulo = 'ELES BATERAM';
    } else {
      titulo = 'BARALHO ESGOTADO';
    }
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: const Color(0xD9000000),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF271A11), Color(0xFF111916), Color(0xFF17100B)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _mGold, width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 24), BoxShadow(color: Color(0x447C4DB7), blurRadius: 18)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFFFFE9A5), Color(0xFFC2872D)]), border: Border.all(color: const Color(0xFFFFF1C2))), child: Icon(venceu ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded, color: const Color(0xFF4B2D07), size: 31)),
            const SizedBox(height: 9),
            Text(venceu ? 'FIM DE PARTIDA' : 'RODADA ${_j.rodada}', style: const TextStyle(color: _mGoldHi, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF6E9C8), fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
            const SizedBox(height: 14),
            linhaNos,
            const SizedBox(height: 7),
            linhaEles,
            const SizedBox(height: 16),
            _botaoOverlay(
              venceu ? 'NOVA PARTIDA' : 'PRÓXIMA RODADA',
              () => setState(() {
                if (venceu) {
                  _j = Jogo(
                    const ['você', 'Cláudia', 'Mateus', 'Sofia'],
                    const ['👑', '🙂', '😎', 'RN'],
                    const ['🐶', '🐰', '🦊', '🐱'],
                  );
                } else {
                  _j.novaRodada();
                }
                _sel.clear();
                _msg = null;
              }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _linhaPlacar(String dupla) {
    final r = _j.pontosRodada?[dupla] as Map<String, dynamic>?;
    final det = r?['detalhe'] as Map?;
    final ganhou = (r?['total'] as int?) ?? 0;
    final eles = dupla == 'eles';
    final nome = eles ? 'ELES' : 'NÓS';
    final cor = eles ? const Color(0xFFF0B0A1) : const Color(0xFF91E2B5);
    final partes = <String>[];
    if (det != null) {
      if ((det['asAas'] ?? 0) > 0) partes.add('${det['asAas']}×1000');
      if ((det['de500'] ?? 0) > 0) partes.add('${det['de500']}×500');
      if ((det['limpas'] ?? 0) > 0) partes.add('${det['limpas']} limpa');
      if ((det['sujas'] ?? 0) > 0) partes.add('${det['sujas']} suja');
      partes.add('cartas ${det['baixadas'] ?? 0}');
      if ((r?['bonusBatida'] as int? ?? 0) != 0) partes.add('batida +100');
      if ((r?['penalidadeMorto'] as int? ?? 0) != 0) partes.add('morto −100');
      if ((r?['descontoMao'] as int? ?? 0) != 0) partes.add('mão ${r!['descontoMao']}');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: eles ? const Color(0x1FEF8170) : const Color(0x1F51D49A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: cor)),
          const SizedBox(width: 6),
          Text(nome, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('${ganhou >= 0 ? '+' : ''}$ganhou', style: TextStyle(color: ganhou >= 0 ? const Color(0xFFB7F4D2) : const Color(0xFFFFB7B0), fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Text('TOTAL ${_j.placar[dupla]}', style: const TextStyle(color: _mGoldHi, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
        if (partes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(partes.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 8.5, height: 1.2))),
      ]),
    );
  }

  Widget _botaoOverlay(String txt, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFE99D), Color(0xFFE0AA4D), Color(0xFFAE7121)]),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFF1BD)),
            boxShadow: const [BoxShadow(color: Color(0x559C6A21), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Text(txt, style: const TextStyle(color: Color(0xFF3F2707), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      );

  Widget _teamRow({required bool eles}) {
    final cor = eles ? const Color(0xFFF0A897) : const Color(0xFF88DEAF);
    // Posição aprovada: o usuário (índice 0) permanece no canto inferior direito.
    final chipL = eles ? _chip(a: 1, dir: false) : _chip(a: 2, dir: false);
    final chipR = eles ? _chip(a: 3, dir: true) : _chip(a: 0, dir: true, play: true);
    final label = eles ? 'ELES' : 'NÓS';
    final points = eles ? _j.placar['eles'] : _j.placar['nos'];
    final dupla = eles ? 'eles' : 'nos';
    return LayoutBuilder(builder: (context, cons) {
      final playerW = ((cons.maxWidth - 94) / 2).clamp(112.0, 138.0).toDouble();
      return Container(
        margin: const EdgeInsets.fromLTRB(6, 5, 6, 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xC9122D22), Color(0xB5081D16)]),
          border: Border.all(color: const Color(0x227FE0B2)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          SizedBox(width: playerW, child: Align(alignment: Alignment.centerLeft, child: chipL)),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), color: const Color(0xA40A1712), border: Border.all(color: cor.withValues(alpha: 0.38))),
                  child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: cor)),
                    const SizedBox(width: 5),
                    Text(label, style: TextStyle(color: cor, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.4, height: 1)),
                    const SizedBox(width: 5),
                    Text('$points', style: const TextStyle(color: Color(0xFFECE3CE), fontSize: 11, fontWeight: FontWeight.w900, height: 1)),
                  ]),
                ),
                _vulnPill(dupla),
              ]),
            ),
          ),
          SizedBox(width: playerW, child: Align(alignment: Alignment.centerRight, child: chipR)),
        ]),
      );
    });
  }

  // Container de vulnerabilidade entre os dois jogadores da dupla (pulsa/brilha).
  Widget _vulnPill(String dupla) {
    final minimo = _j.vulneravelMinimo(dupla);
    if (minimo == 0) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1.0 + 0.05 * t,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFF0A93A)]),
              border: Border.all(color: const Color(0xFFFFE9A8)),
              boxShadow: [BoxShadow(color: const Color(0xFFF0A93A).withValues(alpha: 0.35 + 0.5 * t), blurRadius: 5 + 12 * t, spreadRadius: t * 2.5)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFF3A1410)),
              const SizedBox(width: 3),
              Text('Vulnerável \u00b7 $minimo', style: const TextStyle(color: Color(0xFF3A1410), fontSize: 8.5, fontWeight: FontWeight.w900, height: 1)),
            ]),
          ),
        );
      },
    );
  }

  Widget _avatarSq({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    final user = a == 0;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Container(
        width: 43,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-0.25, -0.35), colors: [Color(0xFF5A3D1B), Color(0xFF211208)]),
          border: Border.all(color: ehVez ? const Color(0xFFC89AFF) : (user ? _mGoldHi : _mGold), width: ehVez ? 2.8 : 2),
          boxShadow: ehVez
              ? const [BoxShadow(color: Color(0xAA9B63E4), blurRadius: 13), BoxShadow(color: Color(0x66EFB94A), blurRadius: 7)]
              : const [BoxShadow(color: Color(0x77000000), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Text(_j.avatares[a], style: const TextStyle(fontSize: 18, color: _mGoldHi)),
      ),
      Positioned(
        bottom: -5,
        left: dir ? null : -7,
        right: dir ? -7 : null,
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Color(0xFF4A3014), Color(0xFF1D1007)]), border: Border.all(color: const Color(0xAAEFB94A)), boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 4)]),
          child: Text(_j.mascotes[a], style: const TextStyle(fontSize: 14)),
        ),
      ),
      if (ehVez) Positioned(top: -5, right: dir ? null : -3, left: dir ? -3 : null, child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC89AFF), border: Border.all(color: const Color(0xFFF5E9FF), width: 1.2), boxShadow: const [BoxShadow(color: Color(0xAAC89AFF), blurRadius: 6)]))),
    ]);
  }

  Widget _chip({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    final user = a == 0;
    final avatar = _avatarSq(a: a, dir: dir, play: play);
    final info = Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: dir ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: dir ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
            if (user && dir) ...[_userTag(), const SizedBox(width: 4)],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: dir ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(_j.apelidos[a], maxLines: 1, textAlign: dir ? TextAlign.right : TextAlign.left, style: TextStyle(color: ehVez ? const Color(0xFFE7D1FF) : const Color(0xFFF1E8D3), fontSize: 10.5, fontWeight: FontWeight.w900, height: 1.05)),
              ),
            ),
            if (user && !dir) ...[const SizedBox(width: 4), _userTag()],
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: dir ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
            Icon(Icons.style_rounded, size: 9, color: ehVez ? const Color(0xFFC89AFF) : const Color(0xFF9E8B68)),
            const SizedBox(width: 3),
            _countBadge(_j.maos[a].length),
          ]),
        ],
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: Row(children: dir ? [info, const SizedBox(width: 6), avatar] : [avatar, const SizedBox(width: 6), info]),
    );
  }

  Widget _userTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: const Color(0xFF7650A8), border: Border.all(color: const Color(0x88D0ABFF))),
        child: const Text('VOCÊ', style: TextStyle(color: Color(0xFFF7EFFF), fontSize: 5.5, fontWeight: FontWeight.w900, letterSpacing: 0.35)),
      );

  Widget _chipStrip({required int a, required bool dir, bool play = false}) => _chip(a: a, dir: dir, play: play);

  Widget _countBadge(int n) => Container(
        constraints: const BoxConstraints(minWidth: 21),
        height: 17,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9E4635), Color(0xFF61251C)]),
          border: Border.all(color: const Color(0x66F1C673)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Text('$n', style: const TextStyle(color: Color(0xFFFFEEE5), fontSize: 9.5, fontWeight: FontWeight.w900, height: 1)),
      );

  Widget _cpill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF153D30), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x337FE0B2))),
        child: Text(s, style: const TextStyle(color: Color(0xFFE8D6A6), fontSize: 7.5, fontWeight: FontWeight.w900, height: 1)),
      );

  Widget _meldsBox(String dupla, {double padTop = 5, double padBottom = 7}) {
    final melds = _j.jogosDupla[dupla]!;
    final interativo = dupla == 'nos';
    final podeBaixar = interativo && _minhaVezAtiva && _j.jaComprou && _sel.length >= 3;
    final title = interativo ? 'JOGOS DA SUA DUPLA' : 'JOGOS ADVERSÁRIOS';
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      padding: EdgeInsets.fromLTRB(7, padTop, 7, padBottom),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: podeBaixar ? const [Color(0xAA244C39), Color(0xAA102E23)] : const [Color(0x7A0D3B2B), Color(0x7208261C)]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: podeBaixar ? _mGoldHi : const Color(0x246DD4A2), width: podeBaixar ? 1.5 : 1),
        boxShadow: podeBaixar ? const [BoxShadow(color: Color(0x55EFB94A), blurRadius: 9)] : const [BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(interativo ? Icons.auto_awesome_rounded : Icons.shield_outlined, size: 10, color: podeBaixar ? _mGoldHi : const Color(0x668FD7B6)),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(color: podeBaixar ? _mGoldHi : const Color(0x668FD7B6), fontSize: 6.8, fontWeight: FontWeight.w900, letterSpacing: 0.55)),
          const Spacer(),
          if (melds.isNotEmpty) _cpill('${melds.length} ${melds.length == 1 ? 'jogo' : 'jogos'}'),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: melds.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(podeBaixar ? Icons.touch_app_rounded : Icons.style_outlined, color: podeBaixar ? _mGoldHi : const Color(0x3394CDB3), size: 21),
                    const SizedBox(height: 5),
                    Text(podeBaixar ? 'TOQUE PARA BAIXAR' : (interativo ? 'Seus jogos aparecerão aqui' : 'Nenhum jogo baixado'), style: TextStyle(color: podeBaixar ? _mGoldHi : const Color(0x55FFFFFF), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: podeBaixar ? 0.5 : 0)),
                  ]),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(spacing: 4, runSpacing: 6, children: [
                    for (int i = 0; i < melds.length; i++)
                      interativo ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _estender(i), child: _meld(melds[i])) : _meld(melds[i]),
                  ]),
                ),
        ),
      ]),
    );
    if (!interativo) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _baixar, child: box);
  }

  Widget _meld(List<Carta> cartas) {
    final sash = _sashDeMeld(cartas);
    final lab = {Sash.limpa: 'LIMPA', Sash.suja: 'SUJA', Sash.n500: 'VIP 500'}[sash];
    Color accent;
    List<Color> sashColors;
    Color labelColor;
    switch (sash) {
      case Sash.suja:
        accent = const Color(0xFFE66E62);
        sashColors = const [Color(0xFFCE5A4F), Color(0xFF7C2924)];
        labelColor = const Color(0xFFFFEBE8);
        break;
      case Sash.n500:
        accent = const Color(0xFFC99BFF);
        sashColors = const [Color(0xFFB989F0), Color(0xFF6B3FA0), Color(0xFFDAAC55)];
        labelColor = const Color(0xFFFFFFFF);
        break;
      case Sash.limpa:
        accent = const Color(0xFFF1C673);
        sashColors = const [Color(0xFFFFEDB1), Color(0xFFDFA94D), Color(0xFF98631E)];
        labelColor = const Color(0xFF4C3007);
        break;
      default:
        accent = const Color(0x667FE0B2);
        sashColors = const [Color(0xFF204C3A), Color(0xFF123326)];
        labelColor = const Color(0xFFE8F5EF);
    }
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: EdgeInsets.only(bottom: lab == null ? 0 : 11),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Color(0x22FFFFFF), Color(0x0AFFFFFF)]), border: Border.all(color: accent.withValues(alpha: 0.52)), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2))]),
        child: _meldCards(cartas),
      ),
      Positioned(
        top: -5,
        right: -5,
        child: Container(
          constraints: const BoxConstraints(minWidth: 17),
          height: 17,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF9E4635), Color(0xFF61251C)]), border: Border.all(color: const Color(0x99F1C673)), boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 4)]),
          child: Text('${cartas.length}', style: const TextStyle(color: Color(0xFFFFEEE5), fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ),
      if (lab != null)
        Positioned(
          left: 5,
          right: 5,
          bottom: 0,
          height: 13,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), gradient: LinearGradient(colors: sashColors), border: Border.all(color: accent.withValues(alpha: 0.65)), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)]),
            child: Text(lab, style: TextStyle(color: labelColor, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.65, height: 1)),
          ),
        ),
    ]);
  }

  List<Carta> _meldOrdenado(List<Carta> cartas) {
    final c = List<Carta>.from(cartas);
    c.sort((a, b) {
      final ja = a.valor == 'JOKER', jb = b.valor == 'JOKER';
      if (ja != jb) return ja ? 1 : -1;
      return Jogo._ordem.indexOf(a.valor) - Jogo._ordem.indexOf(b.valor);
    });
    return c;
  }

  Widget _meldCards(List<Carta> cartas) {
    // Sobreposição fixa e mais fechada, igual para todos os jogos.
    // A primeira carta mantém exatamente o mesmo tamanho das demais.
    const cw = 54.0, ch = 81.0, step = cw * 0.38;
    final ord = _meldOrdenado(cartas);
    final k = ord.length;
    final totalW = (k - 1) * step + cw;
    return SizedBox(
      width: totalW,
      height: ch,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (int i = 0; i < k; i++) Positioned(left: i * step, child: _mcard(ord[i]))],
      ),
    );
  }

  // Carta baixada: SÓ a carta (sem moldura, sem sombra).
  Widget _mcard(Carta c) => SizedBox(
        width: 54,
        height: 81,
        child: Image.asset(_cartaAsset(c), fit: BoxFit.fill, filterQuality: FilterQuality.high),
      );

  Widget _faixaCentral() {
    final podeComprar = _minhaVezAtiva && !_j.jaComprou;
    final podeDescartar = _minhaVezAtiva && _j.jaComprou && _sel.length == 1;
    final podePegarLixo = _minhaVezAtiva && !_j.jaComprou && _j.lixo.isNotEmpty;
    final monteComprado = _lastPurchaseSource == 'monte' && _recentlyBoughtIds.isNotEmpty;
    final lixoComprado = _lastPurchaseSource == 'lixo' && _recentlyBoughtIds.isNotEmpty;
    final monteDestaque = podeComprar || monteComprado;
    final lixoDestaque = podeDescartar || podePegarLixo || lixoComprado;
    final topo = _j.lixoTopo;

    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 1, 6, 1),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE8162119), Color(0xE808100C)],
          ),
          border: Border.all(color: const Color(0x997B5B2A), width: 1),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 68,
                child: _celula(
                  'MONTE',
                  Icons.layers_rounded,
                  _back(destaque: monteDestaque),
                  '${_j.monte.length}',
                  destaque: monteDestaque,
                  onTap: _tapMonte,
                ),
              ),
              _centralDivider(),
              SizedBox(
                width: 68,
                child: _celula(
                  'LIXO',
                  Icons.delete_outline_rounded,
                  topo == null ? _ghost(destaque: lixoDestaque) : _lixoCarta(topo, lixoDestaque),
                  '${_j.lixo.length}',
                  destaque: lixoDestaque,
                  onTap: _tapLixo,
                ),
              ),
              _centralDivider(),
              SizedBox(
                width: 68,
                child: _celula(
                  'MORTO 1',
                  Icons.style_outlined,
                  _j.mortos.isNotEmpty ? _back() : _ghost(),
                  _j.mortos.isNotEmpty ? 'OK' : '—',
                ),
              ),
              _centralDivider(),
              SizedBox(
                width: 68,
                child: _celula(
                  'MORTO 2',
                  Icons.style_outlined,
                  _j.mortos.length > 1 ? _back() : _ghost(),
                  _j.mortos.length > 1 ? 'OK' : '—',
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _centralDivider() => Container(width: 1, height: 67, margin: EdgeInsets.zero, color: const Color(0x337D5A24));

  Widget _celula(String label, IconData icon, Widget slot, String pill, {bool destaque = false, VoidCallback? onTap}) {
    final accent = destaque ? const Color(0xFFC99BFF) : const Color(0xFFB8A984);
    final conteudo = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: destaque ? const Color(0x174F2C70) : Colors.transparent),
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 8.5, color: accent),
          const SizedBox(width: 2),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: TextStyle(color: destaque ? const Color(0xFFE7D1FF) : const Color(0xFFD9CBA8), fontSize: 6.2, fontWeight: FontWeight.w900, letterSpacing: 0.25))),
        ]),
        const SizedBox(height: 1),
        Stack(clipBehavior: Clip.none, children: [
          slot,
          Positioned(top: -4, right: -5, child: Container(constraints: const BoxConstraints(minWidth: 18), height: 15, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), gradient: destaque ? const LinearGradient(colors: [Color(0xFF8F60C9), Color(0xFF5B367F)]) : const LinearGradient(colors: [Color(0xFF4A3820), Color(0xFF251A0E)]), border: Border.all(color: destaque ? const Color(0xAAC99BFF) : const Color(0x668F6A31))), child: Text(pill, style: TextStyle(color: destaque ? const Color(0xFFF5EAFF) : const Color(0xFFEAD9A8), fontSize: 7, fontWeight: FontWeight.w900)))),
        ]),
      ]),
    );
    return onTap == null ? conteudo : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: conteudo);
  }

  Widget _back({bool destaque = false, bool compacto = false}) {
    const w = 46.0;
    const h = 69.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: destaque ? const [BoxShadow(color: Color(0x99B27BE9), blurRadius: 12), BoxShadow(color: Color(0x66EFB94A), blurRadius: 8)] : null,
      ),
      child: Image.asset(_dorsoAsset, fit: BoxFit.fill, filterQuality: FilterQuality.high),
    );
  }

  Widget _lixoCarta(Carta c, bool destaque) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 69,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: destaque ? const [BoxShadow(color: Color(0x99B27BE9), blurRadius: 12), BoxShadow(color: Color(0x66EFB94A), blurRadius: 7)] : null,
        ),
        child: Image.asset(_cartaAsset(c), fit: BoxFit.fill, filterQuality: FilterQuality.high),
      );

  Widget _ghost({bool destaque = false, bool compacto = false}) => Container(
        width: 46,
        height: 69,
        decoration: BoxDecoration(color: destaque ? const Color(0x154F2C70) : const Color(0x0CFFFFFF), borderRadius: BorderRadius.circular(8), border: Border.all(color: destaque ? const Color(0xAAC99BFF) : const Color(0x3FDBC387), width: destaque ? 1.7 : 1.1)),
        child: Icon(Icons.style_outlined, color: destaque ? const Color(0x77C99BFF) : const Color(0x257FE0B2), size: 19),
      );

  final ScrollController _handScroll = ScrollController();

  Widget _hand() {
    final mao = _j.maos[0];
    final n = mao.length;
    if (n == 0) return const SizedBox();

    // A mão permanece em uma única linha e rola horizontalmente.
    // O passo maior deixa a leitura das cartas confortável e garante overflow
    // real quando a mão cresce, sem comprimir ou deformar os arquivos do baralho.
    const cw = 68.0, ch = 102.0, step = 46.0, lift = 15.0;
    final ativo = _minhaVezAtiva;
    final totalW = (n - 1) * step + cw;

    final cartas = LayoutBuilder(builder: (context, cons) {
      final order = List<int>.generate(n, (i) => i)
        ..sort((a, b) {
          final pa = (_sel.contains(a) ? 2 : 0) + (_recentlyBoughtIds.contains(mao[a].id) ? 1 : 0);
          final pb = (_sel.contains(b) ? 2 : 0) + (_recentlyBoughtIds.contains(mao[b].id) ? 1 : 0);
          if (pa != pb) return pa.compareTo(pb);
          return a.compareTo(b);
        });

      final stack = SizedBox(
        width: totalW,
        height: ch + lift,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in order)
              Positioned(
                left: i * step,
                bottom: 0,
                child: GestureDetector(
                  onTap: ativo ? () => _tapCard(i) : null,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    offset: Offset(
                      0,
                      _sel.contains(i)
                          ? -lift / ch
                          : (_recentlyBoughtIds.contains(mao[i].id) ? -7 / ch : 0),
                    ),
                    child: SizedBox(
                      width: cw,
                      height: ch,
                      child: _handCard(
                        mao[i],
                        _sel.contains(i),
                        _recentlyBoughtIds.contains(mao[i].id),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

      return RawScrollbar(
        controller: _handScroll,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thickness: 3,
        radius: const Radius.circular(3),
        thumbColor: const Color(0x99D6C18D),
        trackColor: const Color(0x331C130C),
        trackBorderColor: const Color(0x337D5A24),
        child: SingleChildScrollView(
          controller: _handScroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(8, lift, 12, 8),
          child: stack,
        ),
      );
    });

    // Fora da vez, a mão conserva a escala e desce exatamente 50% da sua altura.
    // Na vez do jogador, sobe verticalmente e fica 100% visível.
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x4406110D),
        border: Border.all(color: const Color(0x557D5A24), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: Offset(0, ativo ? 0 : 0.50),
        child: SizedBox(
          height: ch + lift,
          width: double.infinity,
          child: cartas,
        ),
      ),
    );
  }

  // SÓ a carta — sem moldura. Destaque da comprada/selecionada = brilho + estrelinha
  // (a elevação da comprada/selecionada continua no _hand, do Codex).
  Widget _handCard(Carta c, bool sel, bool comprada) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: comprada
              ? const [BoxShadow(color: Color(0xCCF4D66E), blurRadius: 22, spreadRadius: 2, offset: Offset(0, -4)), BoxShadow(color: Color(0xAA9C65D4), blurRadius: 17)]
              : (sel ? const [BoxShadow(color: Color(0xAA9C65D4), blurRadius: 15, offset: Offset(0, -2)), BoxShadow(color: Color(0x88EFB94A), blurRadius: 7)] : null),
        ),
        child: Stack(children: [
            Positioned.fill(child: Image.asset(_cartaAsset(c), fit: BoxFit.fill, filterQuality: FilterQuality.high)),
            if (comprada)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEFB94A)]), boxShadow: [BoxShadow(color: Color(0xFFF6D96A), blurRadius: 8)]),
                  child: const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF5B3507)),
                ),
              ),
          ]),
      );
}

enum Sash { nenhuma, limpa, suja, n500 }
