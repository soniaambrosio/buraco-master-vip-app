import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
        pageBuilder: (_, __, ___) => const HomeScreen(),
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
      onTap: () => _breve(label),
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
    Widget item(String emoji, String label, bool ativo) {
      return Expanded(
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
          item('🏆', 'Ranking', false),
          item('🛍️', 'Loja', false),
          item('👤', 'Perfil', false),
        ],
      ),
    );
  }
}

// ===================== MESA DE JOGO (partida) — VERDE APROVADA =====================
// Porte fiel de claude/mesa-verde-APROVADA.html. Interação 100% no toque (sem botões).
// Visual primeiro; lógica da partida entra na fatia seguinte.

class Carta {
  final String valor;
  final String naipe;
  final bool curinga;
  const Carta(this.valor, this.naipe, {this.curinga = false});
  bool get vermelho => naipe == '♥' || naipe == '♦';
}

// tipo de faixa do jogo
enum Sash { nenhuma, limpa, suja, n500 }

class Meld {
  final List<Carta> cartas;
  final Sash sash;
  final int cnt;
  const Meld(this.cartas, this.sash, this.cnt);
}

// paleta da mesa verde
const _mGold = Color(0xFFDCAB57);
const _mGoldHi = Color(0xFFF1C673);
const _mCard = Color(0xFFF3F0E8);
const _mRed = Color(0xFF9C302E);
const _mBlack = Color(0xFF2B2B28);
const _mMaroon1 = Color(0xFF7A2F22);
const _mMaroon2 = Color(0xFF471B11);
const _mPill = Color(0xFF123F30);
const _mPillTx = Color(0xFFE7D3A0);
const _mBox = Color(0xFF0C3729);
const _mRail = Color(0xFF6F5324);

Color _corCarta(Carta c) =>
    c.curinga ? const Color(0xFFB8860B) : (c.vermelho ? _mRed : _mBlack);

// textura cross-hatch do feltro (linhas finas 45°/-45°, bem sutis)
class _CrossHatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0A000000)
      ..strokeWidth = 1;
    final diag = size.width + size.height;
    for (final dir in [1.0, -1.0]) {
      canvas.save();
      if (dir < 0) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      for (double x = -size.height; x < diag; x += 4) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MesaScreen extends StatefulWidget {
  const MesaScreen({super.key});
  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> {
  // mão do jogador (a 2ª começa selecionada, como na HTML aprovada)
  final List<Carta> _mao = const [
    Carta('K', '♥'),
    Carta('A', '♠'),
    Carta('5', '♦'),
    Carta('J', '♦'),
    Carta('Q', '♦'),
    Carta('K', '♦'),
    Carta('7', '♣'),
    Carta('3', '♠'),
  ];
  int _sel = 1;

  final List<Meld> _eles = const [
    Meld([Carta('A','♣'),Carta('2','♣'),Carta('3','♣'),Carta('4','♣'),Carta('5','♣'),Carta('6','♣'),Carta('7','♣'),Carta('8','♣'),Carta('9','♣'),Carta('10','♣')], Sash.limpa, 10),
    Meld([Carta('2','♠'),Carta('3','♠'),Carta('4','♠'),Carta('5','♠'),Carta('6','♠'),Carta('7','♠'),Carta('8','♠')], Sash.limpa, 7),
    Meld([Carta('2','♦'),Carta('6','♦'),Carta('7','♦'),Carta('8','♦'),Carta('9','♦'),Carta('10','♦')], Sash.nenhuma, 6),
    Meld([Carta('Q','♣'),Carta('K','♣'),Carta('A','♣')], Sash.nenhuma, 3),
  ];
  final List<Meld> _nos = const [
    Meld([Carta('A','♠'),Carta('2','♠'),Carta('3','♠'),Carta('4','♠'),Carta('5','♠'),Carta('6','♠'),Carta('7','♠'),Carta('8','♠'),Carta('9','♠'),Carta('10','♠'),Carta('J','♠'),Carta('Q','♠'),Carta('K','♠')], Sash.n500, 13),
    Meld([Carta('3','♦'),Carta('4','♦'),Carta('5','♦'),Carta('6','♦'),Carta('7','♦'),Carta('8','♦'),Carta('9','♦')], Sash.suja, 7),
    Meld([Carta('3','♥'),Carta('4','♥'),Carta('5','♥'),Carta('6','♥'),Carta('7','♥'),Carta('8','♥'),Carta('9','♥'),Carta('10','♥')], Sash.suja, 8),
    Meld([Carta('5','♣'),Carta('6','♣'),Carta('7','♣')], Sash.nenhuma, 3),
    Meld([Carta('Q','♦'),Carta('K','♦'),Carta('A','♦')], Sash.nenhuma, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0906),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _mesa()),
          ],
        ),
      ),
    );
  }

  // ---------- header ----------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
      child: Row(
        children: [
          const Text('♛ ',
              style: TextStyle(color: _mGold, fontSize: 15, fontWeight: FontWeight.w800)),
          const Text('BURACO MASTER VIP',
              style: TextStyle(color: Color(0xFFEAD9A8), fontSize: 12, fontWeight: FontWeight.w800)),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A2113), Color(0xFF181109)]),
                  border: Border.all(color: _mGold, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('meta 1500',
                        style: TextStyle(color: _mGoldHi, fontSize: 12, fontWeight: FontWeight.w800)),
                    Text('ABERTO · rodada 1',
                        style: TextStyle(color: Color(0xFFC9B98F), fontSize: 9)),
                  ],
                ),
              ),
            ),
          ),
          _hIcon('☰'),
          const SizedBox(width: 5),
          _hIcon('💬'),
        ],
      ),
    );
  }

  Widget _hIcon(String s) => Container(
        width: 26, height: 26, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF241A10),
          border: Border.all(color: const Color(0x44EFB94A)),
        ),
        child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFFD9C79A))),
      );

  // ---------- mesa (feltro) ----------
  Widget _mesa() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 3, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: _mRail, width: 2),
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [Color(0xFF1D7059), Color(0xFF175946), Color(0xFF103528)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CrossHatch())),
          // marca d'água
          const Positioned(
            top: 0, left: 0, right: 0, bottom: 0,
            child: Center(
              child: Text('♛',
                  style: TextStyle(fontSize: 110, color: Color(0x0DFFFFFF))),
            ),
          ),
          // conteúdo em coluna
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 18),
            child: Column(
              children: [
                _teamRow(eles: true),
                Expanded(child: _meldsBox(_eles)),
                _midBox(),
                _teamRow(eles: false),
                Expanded(child: _meldsBox(_nos)),
              ],
            ),
          ),
          // dica
          const Positioned(
            left: 0, right: 0, bottom: 72,
            child: Text('Lacuna na sequência maior que o número de curingas disponível',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFE7D9B0), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          // mão
          Positioned(left: 0, right: 0, bottom: 0, height: 120, child: _hand()),
        ],
      ),
    );
  }

  // ---------- linha de time (ELES/NÓS) ----------
  Widget _teamRow({required bool eles}) {
    final ptsCor = eles ? const Color(0xFFE7B7A6) : const Color(0xFF8FE0B0);
    final dotCor = eles ? const Color(0xFFD9483F) : const Color(0xFF37C98A);
    final dot = eles ? '●' : '◆';
    final ptsTxt = eles ? 'ELES 610 pts' : 'NÓS 1125 pts';
    final chipL = eles
        ? _chip(masc: '🐰', ava: '🙂', nome: 'Cláudia', num: '#2', dir: false)
        : _chip(masc: '🦊', ava: '😎', nome: 'Mateus', num: '#4', dir: false);
    final chipR = eles
        ? _chip(masc: '🐱', ava: 'RN', nome: 'Sofia', num: '#3', dir: true)
        : _chip(masc: '🐶', ava: '👑', nome: 'você', num: '#7', dir: true, play: true, nCartas: '21');
    return SizedBox(
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 6, child: chipL),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$dot ', style: TextStyle(color: dotCor, fontSize: 10)),
                  Text(ptsTxt,
                      style: TextStyle(color: ptsCor, fontSize: 13.5, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 2),
              _vulnPill(),
            ],
          ),
          Positioned(right: 6, child: chipR),
        ],
      ),
    );
  }

  Widget _vulnPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFC8463D), Color(0xFF9C302E)]),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFFFDD93)),
        boxShadow: const [
          BoxShadow(color: Color(0xD9FFC45C), blurRadius: 12, spreadRadius: 3),
        ],
      ),
      child: const Text('⚡ vulnerável +75',
          style: TextStyle(color: Color(0xFFFFF2EE), fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _chip({
    required String masc,
    required String ava,
    required String nome,
    required String num,
    required bool dir,
    bool play = false,
    String? nCartas,
  }) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: -6,
          left: dir ? null : -8,
          right: dir ? -8 : null,
          child: Container(
            width: 23, height: 23, alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  colors: [Color(0xFF4A3416), Color(0xFF231607)]),
              border: Border.all(color: const Color(0x66EFB94A)),
            ),
            child: Text(masc, style: const TextStyle(fontSize: 13)),
          ),
        ),
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A1C10),
            border: Border.all(color: play ? _mGoldHi : _mGold, width: 2),
            boxShadow: play
                ? const [BoxShadow(color: Color(0x88EFB94A), blurRadius: 6)]
                : null,
          ),
          child: Text(ava, style: const TextStyle(fontSize: 11, color: _mGoldHi)),
        ),
      ],
    );
    final label = Column(
      crossAxisAlignment: dir ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nome,
            style: const TextStyle(color: Color(0xFFEDE3CC), fontSize: 11, fontWeight: FontWeight.w600)),
        Text(num, style: const TextStyle(color: Color(0xFFB9AD8E), fontSize: 9)),
      ],
    );
    final children = <Widget>[];
    if (dir) {
      children.add(label);
      if (nCartas != null) {
        children.add(const SizedBox(width: 5));
        children.add(_cpill(nCartas));
        children.add(const SizedBox(width: 5));
      } else {
        children.add(const SizedBox(width: 6));
      }
      children.add(avatar);
    } else {
      children.add(avatar);
      children.add(const SizedBox(width: 6));
      children.add(label);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _cpill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: _mPill,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Text(s,
            style: const TextStyle(color: _mPillTx, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  // ---------- caixa de jogos (melds) — mesmo tamanho, com scroll ----------
  Widget _meldsBox(List<Meld> melds) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _mBox,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [for (final m in melds) _meld(m)],
        ),
      ),
    );
  }

  Widget _meld(Meld m) {
    final lab = {Sash.limpa: 'LIMPA', Sash.suja: 'SUJA', Sash.n500: '500'}[m.sash];
    return SizedBox(
      // largura do quadro + folga p/ selo de contagem
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              border: Border.all(color: const Color(0x1CFFFFFF)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final c in m.cartas) _mcard(c)],
            ),
          ),
          // selo de contagem
          Positioned(
            top: -5, right: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15),
              height: 15, alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _mMaroon1,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x44000000)),
              ),
              child: Text('${m.cnt}',
                  style: const TextStyle(color: Color(0xFFF6E8DF), fontSize: 8.5, fontWeight: FontWeight.w800)),
            ),
          ),
          // faixa LIMPA/SUJA/500
          if (lab != null)
            Positioned(
              left: 4, right: 4, bottom: 0, height: 12,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: m.sash == Sash.suja
                      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0xFFB8433C), Color(0xFF9C302E)])
                      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF2CF), Color(0xFFE6BA5F), Color(0xFFC68F36)], stops: [0, 0.6, 1]),
                ),
                child: Text(lab,
                    style: TextStyle(
                        color: m.sash == Sash.suja ? const Color(0xFFFBE3DF) : const Color(0xFF5A3D0C),
                        fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mcard(Carta c) {
    final cor = _corCarta(c);
    return Container(
      width: 20, height: 32,
      padding: const EdgeInsets.only(top: 1),
      decoration: const BoxDecoration(
        color: _mCard,
        border: Border(right: BorderSide(color: Color(0x22000000), width: 0.5)),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.valor,
              style: TextStyle(color: cor, fontSize: c.valor.length > 1 ? 9 : 11, fontWeight: FontWeight.w800, height: 1)),
          Text(c.naipe, style: TextStyle(color: cor, fontSize: 8, height: 1)),
        ],
      ),
    );
  }

  // ---------- faixa do meio: monte + lixo | mortos ----------
  Widget _midBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _mBox,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          _pileco(
            pile: _back(check: true),
            label: 'monte', pill: '10',
          ),
          const SizedBox(width: 9),
          _pileco(pile: _ghost(), label: 'lixo', pill: '0'),
          const Spacer(),
          _pileco(
            pile: SizedBox(
              width: 55, height: 48,
              child: Stack(children: [
                _back(),
                Positioned(left: 21, child: _back()),
              ]),
            ),
            label: 'mortos', pill: '2',
          ),
        ],
      ),
    );
  }

  Widget _pileco({required Widget pile, required String label, required String pill}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pile,
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFCFE6D8), fontSize: 9.5)),
            const SizedBox(width: 4),
            _cpill(pill),
          ],
        ),
      ],
    );
  }

  Widget _back({bool check = false}) {
    final card = Container(
      width: 34, height: 48, alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_mMaroon1, _mMaroon2]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _mGold, width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Container(
        width: 19, height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x55EFB94A)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('👑', style: TextStyle(fontSize: 12)),
      ),
    );
    if (!check) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        const Positioned(
          top: -6, left: -4,
          child: Text('✓',
              style: TextStyle(color: Color(0xFF9FE06A), fontSize: 16, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _ghost() => Container(
        width: 34, height: 48,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x3AFFFFFF), width: 1.4),
        ),
      );

  // ---------- mão (cartas sobrepostas; a selecionada sobe e mostra o naipe grande) ----------
  Widget _hand() {
    const step = 26.0, cw = 50.0, ch = 84.0;
    final n = _mao.length;
    final totalW = cw + (n - 1) * step;
    return LayoutBuilder(builder: (context, cons) {
      final base = (cons.maxWidth - totalW) / 2;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < n; i++)
            Positioned(
              left: base + i * step,
              bottom: i == _sel ? 20 : -26,
              width: cw,
              height: ch,
              child: GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: _handCard(_mao[i], i == _sel),
              ),
            ),
        ],
      );
    });
  }

  Widget _handCard(Carta c, bool sel) {
    final cor = _corCarta(c);
    return Container(
      decoration: BoxDecoration(
        color: _mCard,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: sel ? _mGoldHi : const Color(0x33000000), width: sel ? 2 : 1),
        boxShadow: [
          BoxShadow(color: const Color(0x77000000), blurRadius: sel ? 14 : 8, offset: const Offset(0, -3)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.valor,
                    style: TextStyle(color: cor, fontSize: 19, fontWeight: FontWeight.w800, height: 1)),
                Text(c.naipe, style: TextStyle(color: cor, fontSize: 15, height: 1)),
              ],
            ),
          ),
          if (sel)
            Center(
              child: Text(c.naipe, style: TextStyle(color: cor, fontSize: 30)),
            ),
        ],
      ),
    );
  }
}
