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

// ===================== MESA DE JOGO (partida) =====================
class Carta {
  final String valor;
  final String naipe;
  final bool curinga;
  const Carta(this.valor, this.naipe, {this.curinga = false});
  bool get vermelho => naipe == '♥' || naipe == '♦';
}

const _cartaVermelho = Color(0xFFA32D2D);
const _cartaPreto = Color(0xFF2C2C2A);
const _cremeCarta = Color(0xFFF6F3EA);

Widget _cartaFace(Carta c, {double w = 52}) {
  final h = w * 88 / 54;
  final cor = c.curinga
      ? const Color(0xFFB8860B)
      : (c.vermelho ? _cartaVermelho : _cartaPreto);
  final suit = c.curinga ? '★' : c.naipe;
  Widget corner() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.curinga ? '★' : c.valor,
              style: TextStyle(
                  color: cor,
                  fontSize: w * 0.27,
                  fontWeight: FontWeight.w800,
                  height: 1.0)),
          Text(c.curinga ? '' : c.naipe,
              style: TextStyle(color: cor, fontSize: w * 0.22, height: 1.0)),
        ],
      );
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFFBF9F4), Color(0xFFF1ECE0)],
        stops: [0, 0.42, 1],
      ),
      borderRadius: BorderRadius.circular(w * 0.19),
      border: Border.all(color: const Color(0x8CA09682)),
      boxShadow: const [
        BoxShadow(color: Color(0x6B000000), blurRadius: 9, offset: Offset(0, 4))
      ],
    ),
    child: Stack(
      children: [
        Positioned(left: 4, top: 3, child: corner()),
        Center(
          child: Text(suit,
              style: TextStyle(
                  color: cor.withOpacity(0.9),
                  fontSize: w * 0.56,
                  fontWeight: FontWeight.w600)),
        ),
        Positioned(
            right: 4,
            bottom: 3,
            child: Transform.rotate(angle: pi, child: corner())),
      ],
    ),
  );
}

Widget _cartaVerso({double w = 52}) {
  final h = w * 88 / 54;
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A3110), Color(0xFF241608)],
      ),
      borderRadius: BorderRadius.circular(w * 0.19),
      border: Border.all(color: _dourado, width: 1.4),
      boxShadow: const [
        BoxShadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 3))
      ],
    ),
    child: Center(
      child: Container(
        width: w * 0.60,
        height: h * 0.72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x66EFB94A)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('👑', style: TextStyle(fontSize: w * 0.3)),
      ),
    ),
  );
}

Widget _mini(Carta c, {double w = 26}) {
  final h = w * 52 / 36;
  final cor = c.curinga
      ? const Color(0xFFB8860B)
      : (c.vermelho ? _cartaVermelho : _cartaPreto);
  return Container(
    width: w,
    height: h,
    padding: const EdgeInsets.only(left: 2, top: 1),
    decoration: BoxDecoration(
      color: _cremeCarta,
      borderRadius: BorderRadius.circular(w * 0.16),
      border: Border.all(color: const Color(0x55000000), width: 0.6),
      boxShadow: const [
        BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.curinga ? '★' : c.valor,
            style: TextStyle(
                color: cor,
                fontSize: w * 0.44,
                fontWeight: FontWeight.w800,
                height: 1.0)),
        Text(c.curinga ? '' : c.naipe,
            style: TextStyle(color: cor, fontSize: w * 0.34, height: 1.0)),
      ],
    ),
  );
}

Widget _jogo(List<Carta> cartas) {
  const mw = 26.0;
  const sp = 15.0;
  final n = cartas.length;
  final totalW = mw + (n - 1) * sp;
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0x47000000),
      borderRadius: BorderRadius.circular(7),
    ),
    child: SizedBox(
      width: totalW,
      height: mw * 52 / 36 + 2,
      child: Stack(
        children: [
          for (int i = 0; i < n; i++)
            Positioned(left: i * sp, child: _mini(cartas[i], w: mw)),
        ],
      ),
    ),
  );
}

Widget _assento(String nome, String ini, int cartas, {bool vez = false}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3A2606),
          border: Border.all(
              color: vez ? _dourado : const Color(0x66EFB94A),
              width: vez ? 2.4 : 1.4),
          boxShadow: vez
              ? [BoxShadow(color: _dourado.withOpacity(0.6), blurRadius: 12)]
              : null,
        ),
        child: Text(ini,
            style: const TextStyle(
                color: _douradoClaro, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
      const SizedBox(height: 3),
      Text(nome,
          style: TextStyle(
              color: vez ? _dourado : Colors.white70,
              fontSize: 11,
              fontWeight: vez ? FontWeight.bold : FontWeight.normal)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🂠 ', style: TextStyle(fontSize: 9, color: Colors.white38)),
          Text('$cartas',
              style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
        ],
      ),
    ],
  );
}

class MesaScreen extends StatelessWidget {
  const MesaScreen({super.key});

  void _breveMesa(BuildContext c, String o) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
      content: Text('$o — a lógica da partida chega na próxima fatia 👍'),
      duration: const Duration(milliseconds: 1400),
      backgroundColor: const Color(0xFF2A1B0E),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const mao = <Carta>[
      Carta('A', '♠'),
      Carta('K', '♥'),
      Carta('Q', '♥'),
      Carta('J', '♥'),
      Carta('10', '♣'),
      Carta('9', '♦'),
      Carta('8', '♦'),
      Carta('7', '♦'),
      Carta('5', '♣'),
      Carta('', '', curinga: true),
      Carta('3', '♠'),
    ];
    const nosMelds = <List<Carta>>[
      [
        Carta('4', '♥'),
        Carta('5', '♥'),
        Carta('6', '♥'),
        Carta('7', '♥'),
        Carta('8', '♥'),
        Carta('9', '♥'),
        Carta('10', '♥'),
      ],
      [Carta('Q', '♣'), Carta('Q', '♠'), Carta('Q', '♦')],
    ];
    const elesMelds = <List<Carta>>[
      [Carta('3', '♦'), Carta('4', '♦'), Carta('5', '♦'), Carta('6', '♦')],
      [Carta('K', '♥'), Carta('K', '♠'), Carta('K', '♦')],
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0704),
      body: SafeArea(
        child: Column(
          children: [
            _topo(context),
            Expanded(child: _feltroMesa(context, elesMelds, nosMelds)),
            _maoEAcoes(context, mao),
          ],
        ),
      ),
    );
  }

  Widget _topo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: _dourado),
          ),
          const Text('Treino · você + 3 robôs',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C130C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorda),
            ),
            child: const Text('NÓS 1520 · 1105 ELES',
                style: TextStyle(
                    color: _douradoClaro,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _feltroMesa(BuildContext context, List<List<Carta>> elesMelds,
      List<List<Carta>> nosMelds) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.9, -1),
          end: Alignment(0.9, 1),
          colors: [
            Color(0xFFE0982B),
            Color(0xFF8A5E1A),
            Color(0xFF5C3D10),
            Color(0xFF8A5E1A),
            Color(0xFFE0982B),
          ],
          stops: [0, 0.25, 0.5, 0.75, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x77000000), blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _assento('Rosa · parceira', 'RS', 11),
            const SizedBox(height: 4),
            _tagMelds('ELES', elesMelds),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _assento('Zé', 'ZE', 9),
                  Expanded(child: _centro(context)),
                  _assento('Ana', 'AN', 8),
                ],
              ),
            ),
            _tagMelds('NÓS', nosMelds),
          ],
        ),
      ),
    );
  }

  Widget _tagMelds(String lado, List<List<Carta>> melds) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(lado,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final m in melds) _jogo(m)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centro(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC1C130C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _dourado, width: 1),
          ),
          child: const Text('Sua vez',
              style: TextStyle(
                  color: _douradoClaro,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                GestureDetector(
                    onTap: () => _breveMesa(context, 'Comprar do monte'),
                    child: _cartaVerso(w: 46)),
                const SizedBox(height: 3),
                const Text('Monte · 78',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 14),
            Column(
              children: [
                GestureDetector(
                    onTap: () => _breveMesa(context, 'Pegar o lixo'),
                    child: _cartaFace(const Carta('6', '♣'), w: 46)),
                const SizedBox(height: 3),
                const Text('Lixo · 14',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _maoEAcoes(BuildContext context, List<Carta> mao) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: _cardBorda)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sua mão · 11 cartas',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 2),
          _leque(mao),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _btnAcao(context, '🂠', 'Comprar'),
              _btnAcao(context, '🗑️', 'Pegar lixo'),
              _btnAcao(context, '⬇️', 'Baixar'),
              _btnAcao(context, '👊', 'Bater'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btnAcao(BuildContext context, String emoji, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _breveMesa(context, label),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C130C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorda),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leque(List<Carta> cartas) {
    const cw = 50.0;
    const sp = 26.0;
    final n = cartas.length;
    final totalW = cw + (n - 1) * sp;
    final mid = (n - 1) / 2;
    final ch = cw * 88 / 54;
    return SizedBox(
      height: ch + 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: totalW,
          height: ch + 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < n; i++)
                Positioned(
                  left: i * sp,
                  bottom: 6 - ((i - mid).abs() * 1.1),
                  child: Transform.rotate(
                    angle: (i - mid) * 0.04,
                    alignment: Alignment.bottomCenter,
                    child: _cartaFace(cartas[i], w: cw),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
