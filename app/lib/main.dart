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

// ===================== MESA DE JOGO (partida) — VERDE + MOTOR (fatia 1) =====================
// Visual: porte fiel de claude/mesa-verde-APROVADA.html (aprovada pela Sônia).
// Lógica (fatia 1): motor enxuto portado do motor testado (carta.js/jogo.js):
//   baralho 108, distribuição (11/mão, 2 mortos), comprar do monte, descartar,
//   passar a vez + robôs simples (compram e descartam). Interação 100% no toque.
//   Baixar/estender/canastra/bater e a IA esperta entram nas próximas fatias.

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
String _cartaSimb(Carta c) => c.ehCoringa ? '★' : (_naipeSimb[c.naipe] ?? '');
String _cartaRotulo(Carta c) => c.ehCoringa ? '★' : c.valor;

// ---------- MOTOR ENXUTO (fatia 1) ----------
class Jogo {
  final _rnd = Random();
  int _cont = 0;
  static const _naipes = ['copas', 'ouros', 'paus', 'espadas'];
  static const _valores = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  static const cartasPorMao = 11;
  static const cartasPorMorto = 11;

  List<List<Carta>> maos = [[], [], [], []];
  List<Carta> monte = [];
  List<List<Carta>> mortos = [];
  List<Carta> lixo = [];
  List<bool> mortoPego = [false, false]; // [nos, eles]
  int vez = 0;
  bool jaComprou = false;
  bool rodadaEncerrada = false;
  int rodada = 0;

  final List<String> apelidos;
  final List<String> avatares;
  final List<String> mascotes;
  Jogo(this.apelidos, this.avatares, this.mascotes) {
    _distribuir();
  }

  int _dupla(int assento) => assento % 2; // 0/2 -> 0 (nós); 1/3 -> 1 (eles)
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
      cs.add(Carta(_novoId(), null, 'JOKER', true));
      cs.add(Carta(_novoId(), null, 'JOKER', true));
    }
    return cs;
  }

  void _embaralhar(List<Carta> cs) {
    for (var i = cs.length - 1; i > 0; i--) {
      final j = _rnd.nextInt(i + 1);
      final t = cs[i];
      cs[i] = cs[j];
      cs[j] = t;
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
    mortoPego = [false, false];
    vez = 0;
    jaComprou = false;
    rodadaEncerrada = false;
    rodada += 1;
  }

  // COMPRA do monte. Repõe do morto se esgotar. Retorna true se ok.
  bool comprarMonte(int assento) {
    if (rodadaEncerrada || vez != assento || jaComprou) return false;
    if (monte.isEmpty) {
      if (mortos.isNotEmpty) {
        monte = mortos.removeAt(0);
      } else {
        rodadaEncerrada = true;
        return false;
      }
    }
    maos[assento].add(monte.removeAt(0));
    jaComprou = true;
    return true;
  }

  // DESCARTE (encerra a vez). Fatia 1: sem batida/canastra (a mão não zera
  // porque ainda não dá pra baixar). Pega-morto fica pra quando houver baixada.
  bool descartar(int assento, String idCarta) {
    if (rodadaEncerrada || vez != assento || !jaComprou) return false;
    final idx = maos[assento].indexWhere((c) => c.id == idCarta);
    if (idx == -1) return false;
    final c = maos[assento].removeAt(idx);
    lixo.add(c);
    _passarVez();
    return true;
  }

  void _passarVez() {
    if (monte.isEmpty) {
      if (mortos.isEmpty) {
        rodadaEncerrada = true;
        return;
      }
      monte = mortos.removeAt(0);
    }
    vez = (vez + 1) % 4;
    jaComprou = false;
  }

  // ROBÔ simples (fatia 1): compra do monte e descarta uma carta ao acaso.
  void botJoga(int assento) {
    if (rodadaEncerrada || vez != assento) return;
    comprarMonte(assento);
    if (maos[assento].isEmpty) return;
    final i = _rnd.nextInt(maos[assento].length);
    descartar(assento, maos[assento][i].id);
  }
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
    c.ehCoringa ? const Color(0xFFB8860B) : (_cartaVermelha(c) ? _mRed : _mBlack);

// faixa de jogo (melds ainda são exemplo visual — baixar entra na fatia 2)
enum Sash { nenhuma, limpa, suja, n500 }

class MeldEx {
  final List<Carta> cartas;
  final Sash sash;
  final int cnt;
  const MeldEx(this.cartas, this.sash, this.cnt);
}

Carta _c(String v, String n) => Carta('x', n, v, v == '2');

// textura cross-hatch do feltro
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
  late Jogo _j;
  int _sel = -1;
  bool _botsRodando = false;

  // exemplos visuais de melds (fatia 2 liga de verdade)
  final List<MeldEx> _elesEx = [
    MeldEx([_c('A','paus'),_c('2','paus'),_c('3','paus'),_c('4','paus'),_c('5','paus'),_c('6','paus'),_c('7','paus'),_c('8','paus'),_c('9','paus'),_c('10','paus')], Sash.limpa, 10),
    MeldEx([_c('Q','paus'),_c('K','paus'),_c('A','paus')], Sash.nenhuma, 3),
  ];
  final List<MeldEx> _nosEx = [
    MeldEx([_c('3','ouros'),_c('4','ouros'),_c('5','ouros'),_c('6','ouros'),_c('7','ouros'),_c('8','ouros'),_c('9','ouros')], Sash.suja, 7),
    MeldEx([_c('5','paus'),_c('6','paus'),_c('7','paus')], Sash.nenhuma, 3),
  ];

  @override
  void initState() {
    super.initState();
    _j = Jogo(
      const ['você', 'Cláudia', 'Mateus', 'Sofia'],
      const ['👑', '🙂', '😎', 'RN'],
      const ['🐶', '🐰', '🦊', '🐱'],
    );
  }

  void _tapMonte() {
    if (_botsRodando || !_j.suaVez || _j.jaComprou || _j.rodadaEncerrada) return;
    setState(() => _j.comprarMonte(0));
  }

  Future<void> _tapLixo() async {
    if (_botsRodando || !_j.suaVez || !_j.jaComprou) return;
    if (_sel < 0 || _sel >= _j.maos[0].length) return;
    final id = _j.maos[0][_sel].id;
    setState(() {
      _j.descartar(0, id);
      _sel = -1;
    });
    await _rodarBots();
  }

  Future<void> _rodarBots() async {
    _botsRodando = true;
    while (_j.vez != 0 && !_j.rodadaEncerrada) {
      await Future.delayed(const Duration(milliseconds: 700));
      _j.botJoga(_j.vez);
      if (mounted) setState(() {});
    }
    _botsRodando = false;
    if (mounted) setState(() {});
  }

  String get _dica {
    if (_j.rodadaEncerrada) return 'Rodada encerrada';
    if (!_j.suaVez) return 'Vez de ${_j.apelidos[_j.vez]}...';
    if (!_j.jaComprou) return 'Sua vez — toque no MONTE para comprar';
    return 'Escolha uma carta e toque no LIXO para descartar';
  }

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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
      child: Row(
        children: [
          const Text('♛ ', style: TextStyle(color: _mGold, fontSize: 15, fontWeight: FontWeight.w800)),
          const Text('BURACO MASTER VIP', style: TextStyle(color: Color(0xFFEAD9A8), fontSize: 12, fontWeight: FontWeight.w800)),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2113), Color(0xFF181109)]),
                  border: Border.all(color: _mGold, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: const [
                  Text('meta 1500', style: TextStyle(color: _mGoldHi, fontSize: 12, fontWeight: FontWeight.w800)),
                  Text('ABERTO · rodada 1', style: TextStyle(color: Color(0xFFC9B98F), fontSize: 9)),
                ]),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF241A10), border: Border.all(color: const Color(0x44EFB94A))),
        child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFFD9C79A))),
      );

  Widget _mesa() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 3, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: _mRail, width: 2),
        gradient: const RadialGradient(center: Alignment(0, -0.2), radius: 0.95, colors: [Color(0xFF1D7059), Color(0xFF175946), Color(0xFF103528)], stops: [0, 0.55, 1]),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CrossHatch())),
          const Positioned(top: 0, left: 0, right: 0, bottom: 0, child: Center(child: Text('♛', style: TextStyle(fontSize: 110, color: Color(0x0DFFFFFF))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 18),
            child: Column(
              children: [
                _teamRow(eles: true),
                Expanded(child: _meldsBox(_elesEx)),
                _midBox(),
                _teamRow(eles: false),
                Expanded(child: _meldsBox(_nosEx)),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 72, child: Text(_dica, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE7D9B0), fontSize: 11, fontWeight: FontWeight.w600))),
          Positioned(left: 0, right: 0, bottom: 0, height: 128, child: _hand()),
        ],
      ),
    );
  }

  Widget _teamRow({required bool eles}) {
    final ptsCor = eles ? const Color(0xFFE7B7A6) : const Color(0xFF8FE0B0);
    final dotCor = eles ? const Color(0xFFD9483F) : const Color(0xFF37C98A);
    final dot = eles ? '●' : '◆';
    final ptsTxt = eles ? 'ELES 610 pts' : 'NÓS 1125 pts';
    // assentos: 0=você(nós), 1=Cláudia(eles), 2=Mateus(nós), 3=Sofia(eles)
    final chipL = eles
        ? _chip(a: 1, dir: false)
        : _chip(a: 2, dir: false);
    final chipR = eles
        ? _chip(a: 3, dir: true)
        : _chip(a: 0, dir: true, play: true);
    return SizedBox(
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 6, child: chipL),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$dot ', style: TextStyle(color: dotCor, fontSize: 10)),
              Text(ptsTxt, style: TextStyle(color: ptsCor, fontSize: 13.5, fontWeight: FontWeight.w800)),
            ]),
          ]),
          Positioned(right: 6, child: chipR),
        ],
      ),
    );
  }

  Widget _chip({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    final avatar = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: -6, left: dir ? null : -8, right: dir ? -8 : null,
          child: Container(
            width: 23, height: 23, alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const RadialGradient(center: Alignment(-0.2, -0.3), colors: [Color(0xFF4A3416), Color(0xFF231607)]),
              border: Border.all(color: const Color(0x66EFB94A)),
            ),
            child: Text(_j.mascotes[a], style: const TextStyle(fontSize: 13)),
          ),
        ),
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: const Color(0xFF2A1C10),
            border: Border.all(color: (play || ehVez) ? _mGoldHi : _mGold, width: ehVez ? 2.4 : 2),
            boxShadow: ehVez ? const [BoxShadow(color: Color(0xAAEFB94A), blurRadius: 9)] : null,
          ),
          child: Text(_j.avatares[a], style: const TextStyle(fontSize: 11, color: _mGoldHi)),
        ),
      ],
    );
    final label = Column(
      crossAxisAlignment: dir ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_j.apelidos[a], style: TextStyle(color: ehVez ? _mGoldHi : const Color(0xFFEDE3CC), fontSize: 11, fontWeight: FontWeight.w600)),
        Text('#${a + 1}', style: const TextStyle(color: Color(0xFFB9AD8E), fontSize: 9)),
      ],
    );
    final children = <Widget>[];
    if (dir) {
      children.add(label);
      children.add(const SizedBox(width: 5));
      children.add(_cpill('${_j.maos[a].length}'));
      children.add(const SizedBox(width: 5));
      children.add(avatar);
    } else {
      children.add(avatar);
      children.add(const SizedBox(width: 6));
      children.add(label);
      children.add(const SizedBox(width: 5));
      children.add(_cpill('${_j.maos[a].length}'));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _cpill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: _mPill, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0x1AFFFFFF))),
        child: Text(s, style: const TextStyle(color: _mPillTx, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _meldsBox(List<MeldEx> melds) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: _mBox, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))]),
      child: SingleChildScrollView(
        child: Wrap(spacing: 7, runSpacing: 8, children: [for (final m in melds) _meld(m)]),
      ),
    );
  }

  Widget _meld(MeldEx m) {
    final lab = {Sash.limpa: 'LIMPA', Sash.suja: 'SUJA', Sash.n500: '500'}[m.sash];
    return SizedBox(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
            decoration: BoxDecoration(color: const Color(0x0DFFFFFF), border: Border.all(color: const Color(0x1CFFFFFF)), borderRadius: BorderRadius.circular(5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [for (final c in m.cartas) _mcard(c)]),
          ),
          Positioned(
            top: -5, right: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15), height: 15, alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: _mMaroon1, borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0x44000000))),
              child: Text('${m.cnt}', style: const TextStyle(color: Color(0xFFF6E8DF), fontSize: 8.5, fontWeight: FontWeight.w800)),
            ),
          ),
          if (lab != null)
            Positioned(
              left: 4, right: 4, bottom: 0, height: 12,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: m.sash == Sash.suja
                      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB8433C), Color(0xFF9C302E)])
                      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF2CF), Color(0xFFE6BA5F), Color(0xFFC68F36)], stops: [0, 0.6, 1]),
                ),
                child: Text(lab, style: TextStyle(color: m.sash == Sash.suja ? const Color(0xFFFBE3DF) : const Color(0xFF5A3D0C), fontSize: 8, fontWeight: FontWeight.w800)),
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
      decoration: const BoxDecoration(color: _mCard, border: Border(right: BorderSide(color: Color(0x22000000), width: 0.5)), borderRadius: BorderRadius.all(Radius.circular(2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_cartaRotulo(c), style: TextStyle(color: cor, fontSize: _cartaRotulo(c).length > 1 ? 9 : 11, fontWeight: FontWeight.w800, height: 1)),
        Text(_cartaSimb(c), style: TextStyle(color: cor, fontSize: 8, height: 1)),
      ]),
    );
  }

  Widget _midBox() {
    final podeComprar = _j.suaVez && !_j.jaComprou && !_j.rodadaEncerrada && !_botsRodando;
    final podeDescartar = _j.suaVez && _j.jaComprou && _sel >= 0 && !_botsRodando;
    final topo = _j.lixoTopo;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _mBox, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))]),
      child: Row(
        children: [
          GestureDetector(
            onTap: _tapMonte,
            child: _pileco(pile: _back(destaque: podeComprar), label: 'monte', pill: '${_j.monte.length}'),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: _tapLixo,
            child: _pileco(
              pile: topo == null ? _ghost(destaque: podeDescartar) : _lixoCarta(topo, podeDescartar),
              label: 'lixo', pill: '${_j.lixo.length}',
            ),
          ),
          const Spacer(),
          _pileco(
            pile: SizedBox(width: 55, height: 48, child: Stack(children: [_back(), Positioned(left: 21, child: _back())])),
            label: 'mortos', pill: '${_j.mortos.length}',
          ),
        ],
      ),
    );
  }

  Widget _pileco({required Widget pile, required String label, required String pill}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      pile,
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Color(0xFFCFE6D8), fontSize: 9.5)),
        const SizedBox(width: 4),
        _cpill(pill),
      ]),
    ]);
  }

  Widget _back({bool destaque = false}) {
    return Container(
      width: 34, height: 48, alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_mMaroon1, _mMaroon2]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: destaque ? _mGoldHi : _mGold, width: destaque ? 2 : 1.4),
        boxShadow: destaque ? const [BoxShadow(color: Color(0x99EFB94A), blurRadius: 8)] : const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Container(
        width: 19, height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: const Color(0x55EFB94A)), borderRadius: BorderRadius.circular(4)),
        child: const Text('👑', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _lixoCarta(Carta c, bool destaque) {
    final cor = _corCarta(c);
    return Container(
      width: 34, height: 48,
      padding: const EdgeInsets.only(left: 3, top: 2),
      decoration: BoxDecoration(
        color: _mCard, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: destaque ? _mGoldHi : const Color(0x55000000), width: destaque ? 2 : 1),
        boxShadow: destaque ? const [BoxShadow(color: Color(0x99EFB94A), blurRadius: 8)] : const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_cartaRotulo(c), style: TextStyle(color: cor, fontSize: 13, fontWeight: FontWeight.w800, height: 1)),
        Text(_cartaSimb(c), style: TextStyle(color: cor, fontSize: 11, height: 1)),
      ]),
    );
  }

  Widget _ghost({bool destaque = false}) => Container(
        width: 34, height: 48,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: destaque ? _mGoldHi : const Color(0x3AFFFFFF), width: destaque ? 2 : 1.4),
        ),
      );

  Widget _hand() {
    const step = 26.0, cw = 50.0, ch = 84.0;
    final mao = _j.maos[0];
    final n = mao.length;
    if (n == 0) return const SizedBox();
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
              width: cw, height: ch,
              child: GestureDetector(
                onTap: () => setState(() => _sel = (_sel == i ? -1 : i)),
                child: _handCard(mao[i], i == _sel),
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
        color: _mCard, borderRadius: BorderRadius.circular(9),
        border: Border.all(color: sel ? _mGoldHi : const Color(0x33000000), width: sel ? 2 : 1),
        boxShadow: [BoxShadow(color: const Color(0x77000000), blurRadius: sel ? 14 : 8, offset: const Offset(0, -3))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_cartaRotulo(c), style: TextStyle(color: cor, fontSize: 19, fontWeight: FontWeight.w800, height: 1)),
              Text(_cartaSimb(c), style: TextStyle(color: cor, fontSize: 15, height: 1)),
            ]),
          ),
          if (sel) Center(child: Text(_cartaSimb(c), style: TextStyle(color: cor, fontSize: 30))),
        ],
      ),
    );
  }
}
