import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pages/perfil_page.dart';

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
      onTap: label == 'Perfil' ? _abrirPerfil : () => _breve(label),
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
          item('🏆', 'Ranking', false, onTap: () => _breve('Ranking')),
          item('🛍️', 'Loja', false, onTap: () => _breve('Loja VIP')),
          item('👤', 'Perfil', false, onTap: _abrirPerfil),
        ],
      ),
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
    c.valor == 'JOKER' ? const Color(0xFFB8860B) : (_cartaVermelha(c) ? _mRed : _mBlack);

class _CrossHatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0A000000)..strokeWidth = 1;
    final diag = size.width + size.height;
    for (final dir in [1.0, -1.0]) {
      canvas.save();
      if (dir < 0) { canvas.translate(size.width, 0); canvas.scale(-1, 1); }
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
  final Set<int> _sel = {};
  bool _botsRodando = false;
  String? _msg;

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
    try {
      _pCarta = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pEvento = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    } catch (_) {/* sem áudio, o jogo segue normal */}
  }

  @override
  void dispose() {
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

  void _tapMonte() {
    if (!_minhaVezAtiva || _j.jaComprou) return;
    setState(() { _j.comprarMonte(0); _j.ordenar(0); _msg = null; });
    _somCarta();
  }

  Future<void> _tapLixo() async {
    if (!_minhaVezAtiva) return;
    if (!_j.jaComprou) {
      // antes de comprar: tocar no lixo PEGA o monte de descarte inteiro
      final res = _j.comprarLixo(0);
      if (res['ok'] != true) { setState(() => _msg = res['erro'] as String?); _somErro(); return; }
      _j.ordenar(0);
      _somCarta();
      setState(() { _sel.clear(); _msg = 'Você pegou o LIXO (${res['qtd']} cartas)! Baixe/estenda e depois descarte.'; });
      return;
    }
    if (_sel.length != 1) { setState(() => _msg = 'Toque em UMA carta e depois no lixo pra descartar'); return; }
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
    if (_sel.length < 3) { setState(() => _msg = 'Selecione 3+ cartas em sequência (mesmo naipe) e toque aqui pra baixar'); return; }
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
    if (_sel.isEmpty) { setState(() => _msg = 'Selecione cartas da mão e toque no jogo pra estender'); return; }
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

  String get _dica {
    if (_msg != null) return _msg!;
    if (_j.rodadaEncerrada) return _j.duplaQueBateu == 'nos' ? '🎉 Rodada encerrada — NÓS batemos!' : 'Rodada encerrada';
    if (!_j.suaVez) return 'Vez de ${_j.apelidos[_j.vez]}...';
    if (!_j.jaComprou) return _j.lixo.isEmpty ? 'Sua vez — toque no MONTE pra comprar' : 'Sua vez — MONTE compra 1 · LIXO pega tudo';
    if (_sel.length >= 3) return 'Toque na área NÓS pra BAIXAR, ou num jogo pra estender';
    if (_sel.length == 1) return 'Toque no LIXO pra descartar, ou num jogo pra estender';
    return 'Selecione cartas: 3+ pra baixar · 1 pra descartar';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0906),
      body: SafeArea(
        bottom: false,
        child: Column(children: [_header(), Expanded(child: _mesa())]),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A351A), Color(0xFF24170A)],
            ),
            border: Border.all(color: const Color(0x88EFB94A)),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: _mGoldHi, size: 19),
        ),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'BURACO MASTER VIP',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: Color(0xFFF0E1B7),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _matchInfoPill(),
        const SizedBox(width: 7),
        _hIcon(Icons.menu_rounded),
        const SizedBox(width: 5),
        _hIcon(Icons.chat_bubble_outline_rounded),
      ]),
    );
  }

  Widget _matchInfoPill() => Container(
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF21170D),
          border: Border.all(color: const Color(0xA6EFB94A)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'meta ${_j.metaPontos}',
            style: const TextStyle(color: _mGoldHi, fontSize: 10.5, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            'rodada ${_j.rodada}',
            style: const TextStyle(color: Color(0xFFC9B98F), fontSize: 8.5, fontWeight: FontWeight.w600, height: 1),
          ),
        ]),
      );

  Widget _hIcon(IconData icon) => Container(
        width: 29,
        height: 29,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF21170D),
          border: Border.all(color: const Color(0x55EFB94A)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFFE2D1A7)),
      );

  Widget _mesa() {
    return Container(
      margin: const EdgeInsets.fromLTRB(7, 2, 7, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
        border: Border.all(color: _mRail, width: 1.6),
        gradient: const RadialGradient(
          center: Alignment(0, -0.18),
          radius: 1.02,
          colors: [Color(0xFF1A684F), Color(0xFF124735), Color(0xFF0B2B20)],
          stops: [0, 0.58, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x33795D2A), blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CrossHatch())),
        const Positioned.fill(
          child: Center(
            child: Text('♛', style: TextStyle(fontSize: 112, color: Color(0x0AFFFFFF))),
          ),
        ),
        Positioned.fill(
          child: Column(children: [
            Expanded(flex: 42, child: _areaJogo('eles')),
            Expanded(flex: 16, child: _faixaCentral()),
            Expanded(flex: 42, child: _areaJogo('nos')),
          ]),
        ),
        Positioned(left: 10, right: 10, bottom: 94, child: _turnBanner()),
        Positioned(left: 0, right: 0, bottom: 0, height: 96, child: _hand()),
        if (_j.rodadaEncerrada) Positioned.fill(child: _overlayFimRodada()),
      ]),
    );
  }

  Widget _turnBanner() {
    final erro = _msg != null;
    final minhaVez = _j.suaVez && !_j.rodadaEncerrada;
    final icon = erro
        ? Icons.info_outline_rounded
        : minhaVez
            ? Icons.touch_app_rounded
            : Icons.hourglass_top_rounded;
    final accent = erro
        ? const Color(0xFFF1C673)
        : minhaVez
            ? const Color(0xFF8FE0B0)
            : const Color(0xFFC9B98F);
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Container(
          key: ValueKey<String>(_dica),
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE62A2014), Color(0xE619120C)],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 7, offset: Offset(0, 2)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _dica,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: erro ? _mGoldHi : const Color(0xFFE9DFC5), fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.12),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // área de jogo de uma dupla (superior=eles / inferior=nos): jogos baixados + avatares nos cantos
  Widget _areaJogo(String dupla) {
    final eles = dupla == 'eles';
    return Column(children: [
      _teamRow(eles: eles),
      Expanded(
        child: _meldsBox(
          dupla,
          padTop: 5,
          padBottom: eles ? 8 : 42,
        ),
      ),
    ]);
  }

  // avatar sobreposto no canto: círculo + (AO LADO) nome em cima e selo de contagem embaixo
  Widget _avatarCanto({required int a, required bool dir}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    final info = Column(
      crossAxisAlignment: dir ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          child: Text(_j.apelidos[a], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: dir ? TextAlign.right : TextAlign.left,
              style: TextStyle(color: ehVez ? _mGoldHi : const Color(0xFFEDE3CC), fontSize: 11, fontWeight: FontWeight.w700, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
        ),
        const SizedBox(height: 3),
        _countBadge(_j.maos[a].length),
      ],
    );
    final av = _avatarSq(a: a, dir: dir, play: a == 0);
    final children = dir ? [info, const SizedBox(width: 6), av] : [av, const SizedBox(width: 6), info];
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  // ===== OVERLAY DE FIM DE RODADA / FIM DE PARTIDA (Fatia 4) =====
  Widget _overlayFimRodada() {
    final venceu = _j.encerrada;
    final linhaNos = _linhaPlacar('nos');
    final linhaEles = _linhaPlacar('eles');
    String titulo;
    if (venceu) {
      final nosVenceu = _j.placar['nos']! >= _j.placar['eles']!;
      titulo = nosVenceu ? '🏆 NÓS vencemos a partida!' : '😢 ELES venceram a partida';
    } else if (_j.duplaQueBateu == 'nos') {
      titulo = '🎉 NÓS batemos!';
    } else if (_j.duplaQueBateu == 'eles') {
      titulo = 'ELES bateram';
    } else {
      titulo = 'Rodada encerrada (baralho esgotou)';
    }
    return GestureDetector(
      onTap: () {}, // bloqueia toques na mesa atrás
      child: Container(
        color: const Color(0xCC000000),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF20313A), Color(0xFF14232B)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _mGold, width: 1.6),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('♛  ${venceu ? 'FIM DE PARTIDA' : 'Rodada ${_j.rodada}'}', style: const TextStyle(color: _mGoldHi, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF1E7CC), fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            linhaNos,
            const SizedBox(height: 8),
            linhaEles,
            const SizedBox(height: 16),
            _botaoOverlay(
              venceu ? '🔄  Nova partida' : '▶  Próxima rodada',
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
    final cor = eles ? const Color(0xFFE7B7A6) : const Color(0xFF8FE0B0);
    final partes = <String>[];
    if (det != null) {
      if ((det['asAas'] ?? 0) > 0) partes.add('${det['asAas']}×1000');
      if ((det['de500'] ?? 0) > 0) partes.add('${det['de500']}×500');
      if ((det['limpas'] ?? 0) > 0) partes.add('${det['limpas']} limpa');
      if ((det['sujas'] ?? 0) > 0) partes.add('${det['sujas']} suja');
      partes.add('cartas ${det['baixadas'] ?? 0}');
      if ((r?['bonusBatida'] as int? ?? 0) != 0) partes.add('bateu +100');
      if ((r?['penalidadeMorto'] as int? ?? 0) != 0) partes.add('s/ morto −100');
      if ((r?['descontoMao'] as int? ?? 0) != 0) partes.add('mão ${r!['descontoMao']}');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x22FFFFFF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text('$nome  ', style: TextStyle(color: cor, fontSize: 14, fontWeight: FontWeight.w800)),
            Text('${ganhou >= 0 ? '+' : ''}$ganhou', style: TextStyle(color: ganhou >= 0 ? const Color(0xFF9BE7BE) : const Color(0xFFE79B9B), fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          Text('total ${_j.placar[dupla]}', style: const TextStyle(color: _mGoldHi, fontSize: 14, fontWeight: FontWeight.w900)),
        ]),
        if (partes.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(partes.join(' · '), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5)),
        ),
      ]),
    );
  }

  Widget _botaoOverlay(String txt, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF2CF), Color(0xFFE6BA5F), Color(0xFFC68F36)], stops: [0, 0.6, 1]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Text(txt, style: const TextStyle(color: Color(0xFF4A3208), fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _teamRow({required bool eles}) {
    final ptsCor = eles ? const Color(0xFFE7B7A6) : const Color(0xFF8FE0B0);
    final dotCor = eles ? const Color(0xFFD8685C) : const Color(0xFF45D59A);
    final ptsTxt = eles ? 'ELES ${_j.placar['eles']}' : 'NÓS ${_j.placar['nos']}';
    final chipL = eles ? _chip(a: 1, dir: false) : _chip(a: 2, dir: false);
    final chipR = eles ? _chip(a: 3, dir: true) : _chip(a: 0, dir: true, play: true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 4, 7, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: chipL)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xB3162B21),
            border: Border.all(color: dotCor.withValues(alpha: 0.42)),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotCor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(ptsTxt, style: TextStyle(color: ptsCor, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
            const Text(' pts', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 8.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(child: Align(alignment: Alignment.centerRight, child: chipR)),
      ]),
    );
  }

  // só o visual do avatar (círculo + mascote), reaproveitado no topo e na faixa central
  Widget _avatarSq({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Positioned(
        bottom: -8, left: dir ? null : -13, right: dir ? -13 : null,
        child: Container(
          width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const RadialGradient(center: Alignment(-0.2, -0.3), colors: [Color(0xFF4A3416), Color(0xFF231607)]), border: Border.all(color: const Color(0x66EFB94A))),
          child: Text(_j.mascotes[a], style: const TextStyle(fontSize: 18)),
        ),
      ),
      Container(
        width: 42, height: 42, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A1C10), border: Border.all(color: (play || ehVez) ? _mGoldHi : _mGold, width: ehVez ? 3 : 2.2), boxShadow: ehVez ? const [BoxShadow(color: Color(0xAAEFB94A), blurRadius: 12)] : null),
        child: Text(_j.avatares[a], style: const TextStyle(fontSize: 18, color: _mGoldHi)),
      ),
    ]);
  }

  // chip horizontal (usado na barra de cima da dupla ELES)
  Widget _chip({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    final avatar = _avatarSq(a: a, dir: dir, play: play);
    final label = SizedBox(
      width: 48,
      child: Text(_j.apelidos[a], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: dir ? TextAlign.right : TextAlign.left, style: TextStyle(color: ehVez ? _mGoldHi : const Color(0xFFEDE3CC), fontSize: 11, fontWeight: FontWeight.w800)),
    );
    final children = <Widget>[];
    if (dir) {
      children.addAll([label, const SizedBox(width: 5), _countBadge(_j.maos[a].length), const SizedBox(width: 6), avatar]);
    } else {
      children.addAll([avatar, const SizedBox(width: 7), label, const SizedBox(width: 5), _countBadge(_j.maos[a].length)]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  // chip vertical compacto (usado ladeando a faixa central — dupla NÓS)
  Widget _chipStrip({required int a, required bool dir, bool play = false}) {
    final ehVez = _j.vez == a && !_j.rodadaEncerrada;
    return SizedBox(
      width: 54,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _avatarSq(a: a, dir: dir, play: play),
        const SizedBox(height: 3),
        Text(_j.apelidos[a], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: TextStyle(color: ehVez ? _mGoldHi : const Color(0xFFEDE3CC), fontSize: 10.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        _countBadge(_j.maos[a].length),
      ]),
    );
  }

  // contagem de cartas do jogador — mesmo estilo do selo de contagem dos jogos na mesa
  Widget _countBadge(int n) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 18,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA44A36), Color(0xFF6D291E)],
          ),
          border: Border.all(color: const Color(0x55F1C673)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Text('$n', style: const TextStyle(color: Color(0xFFFFF1E8), fontSize: 10.5, fontWeight: FontWeight.w900)),
      );

  Widget _cpill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: _mPill, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0x1AFFFFFF))),
        child: Text(s, style: const TextStyle(color: _mPillTx, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _meldsBox(String dupla, {double padTop = 64, double padBottom = 8}) {
    final melds = _j.jogosDupla[dupla]!;
    final interativo = dupla == 'nos';
    final podeBaixar = interativo && _minhaVezAtiva && _j.jaComprou && _sel.length >= 3;
    final box = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      // topo reservado pros avatares sobrepostos nos cantos não cobrirem os jogos
      padding: EdgeInsets.fromLTRB(8, padTop, 8, padBottom),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _mBox,
        borderRadius: BorderRadius.circular(14),
        border: podeBaixar ? Border.all(color: _mGoldHi, width: 1.4) : Border.all(color: const Color(0x22FFFFFF), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: melds.isEmpty
          ? Center(child: Text(interativo ? (podeBaixar ? 'Toque aqui para baixar' : 'Seus jogos aparecerão aqui') : 'Jogos da dupla', style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 9.5, fontWeight: FontWeight.w600)))
          : SingleChildScrollView(child: Wrap(spacing: 7, runSpacing: 8, children: [
              for (int i = 0; i < melds.length; i++)
                interativo
                    ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _estender(i), child: _meld(melds[i]))
                    : _meld(melds[i]),
            ])),
    );
    if (!interativo) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _baixar, child: box);
  }

  Widget _meld(List<Carta> cartas) {
    final sash = _sashDeMeld(cartas);
    final lab = {Sash.limpa: 'LIMPA', Sash.suja: 'SUJA', Sash.n500: '500'}[sash];
    return SizedBox(
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
          decoration: BoxDecoration(color: const Color(0x0DFFFFFF), border: Border.all(color: const Color(0x1CFFFFFF)), borderRadius: BorderRadius.circular(6)),
          child: _meldCards(cartas),
        ),
        Positioned(top: -5, right: -5, child: Container(
          constraints: const BoxConstraints(minWidth: 15), height: 15, alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: _mMaroon1, borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0x44000000))),
          child: Text('${cartas.length}', style: const TextStyle(color: Color(0xFFF6E8DF), fontSize: 8.5, fontWeight: FontWeight.w800)),
        )),
        if (lab != null) Positioned(left: 4, right: 4, bottom: 0, height: 12, child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: sash == Sash.suja
              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB8433C), Color(0xFF9C302E)])
              : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF2CF), Color(0xFFE6BA5F), Color(0xFFC68F36)], stops: [0, 0.6, 1])),
          child: Text(lab, style: TextStyle(color: sash == Sash.suja ? const Color(0xFFFBE3DF) : const Color(0xFF5A3D0C), fontSize: 8, fontWeight: FontWeight.w800)),
        )),
      ]),
    );
  }

  // jogo baixado em "leque": cartas sobrepostas, mostrando o canto (valor+naipe).
  // cabe sequências longas sem estourar e fica com cara de jogo de verdade.
  // ordena a EXIBIÇÃO do jogo em ordem crescente (A,2,3…K); coringa JOKER vai pro fim.
  // é só visual — a validade do jogo independe da ordem.
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
    const peek = 20.0, cw = 34.0, ch = 50.0;
    final ord = _meldOrdenado(cartas);
    final k = ord.length;
    final totalW = (k - 1) * peek + cw;
    return SizedBox(
      width: totalW, height: ch,
      child: Stack(clipBehavior: Clip.none, children: [
        for (int i = 0; i < k; i++) Positioned(left: i * peek, child: _mcard(ord[i])),
      ]),
    );
  }

  // carta da mesa (leque) = imagem real do baralho; o "peek" à esquerda mostra o canto (valor+naipe)
  Widget _mcard(Carta c) => Container(
        width: 34, height: 50,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(1, 0))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(_cartaAsset(c), fit: BoxFit.fill),
      );

  // FAIXA CENTRAL (18%): quatro áreas IGUAIS lado a lado — monte, lixo, morto 1, morto 2.
  Widget _faixaCentral() {
    final podeComprar = _minhaVezAtiva && !_j.jaComprou;
    final podeDescartar = _minhaVezAtiva && _j.jaComprou && _sel.length == 1;
    final podePegarLixo = _minhaVezAtiva && !_j.jaComprou && _j.lixo.isNotEmpty;
    final lixoDestaque = podeDescartar || podePegarLixo;
    final topo = _j.lixoTopo;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE60E3B2C), Color(0xE6092A20)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334FD39A), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      // monte + lixo JUNTOS bem à esquerda; os 2 mortos JUNTOS bem à direita (espaço no meio)
      child: Row(children: [
        _celula('monte', _back(destaque: podeComprar), '${_j.monte.length}', onTap: _tapMonte),
        const SizedBox(width: 8),
        _celula('lixo', topo == null ? _ghost(destaque: lixoDestaque) : _lixoCarta(topo, lixoDestaque), '${_j.lixo.length}', onTap: _tapLixo),
        const Spacer(),
        _celula('morto', _j.mortos.isNotEmpty ? _back() : _ghost(), _j.mortos.isNotEmpty ? '1' : '—'),
        const SizedBox(width: 8),
        _celula('morto', _j.mortos.length > 1 ? _back() : _ghost(), _j.mortos.length > 1 ? '1' : '—'),
      ]),
    );
  }

  // uma célula da faixa central (largura fixa; agrupadas por Spacer).
  // rótulo + contador JUNTOS em cima -> a margem de baixo fica livre pros avatares NÓS que sobem.
  Widget _celula(String label, Widget slot, String pill, {VoidCallback? onTap}) {
    final conteudo = Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFFD9E8DF), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.25)),
        const SizedBox(width: 4),
        _cpill(pill),
      ]),
      const SizedBox(height: 3),
      slot,
    ]);
    return onTap != null ? GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: conteudo) : conteudo;
  }

  // dorso do baralho (monte e mortos) = imagem real do dorso
  Widget _back({bool destaque = false}) {
    return Container(
      width: 46, height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: destaque ? _mGoldHi : const Color(0x66EFB94A), width: destaque ? 2 : 1),
        boxShadow: destaque ? const [BoxShadow(color: Color(0x99EFB94A), blurRadius: 8)] : const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_dorsoAsset, fit: BoxFit.cover),
    );
  }

  Widget _lixoCarta(Carta c, bool destaque) {
    return Container(
      width: 46, height: 64,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: destaque ? _mGoldHi : const Color(0x55000000), width: destaque ? 2 : 1), boxShadow: destaque ? const [BoxShadow(color: Color(0x99EFB94A), blurRadius: 8)] : const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))]),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_cartaAsset(c), fit: BoxFit.fill),
    );
  }

  Widget _ghost({bool destaque = false}) => Container(
        width: 46, height: 64,
        decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(7), border: Border.all(color: destaque ? _mGoldHi : const Color(0x3AFFFFFF), width: destaque ? 2 : 1.4)),
      );

  final ScrollController _handScroll = ScrollController();

  Widget _hand() {
    final mao = _j.maos[0];
    final n = mao.length;
    if (n == 0) return const SizedBox();
    // Cartas em TAMANHO NORMAL (nunca miniatura). A mão fica presa à base:
    //  - FORA da vez: desce 50% da altura (metade some pra baixo, cortada pela borda);
    //  - NA vez: sobe inteira (translateY 0). Só movimento vertical, escala igual.
    // Animação 300ms ease-out. Selecionar levanta a carta 16px.
    const cw = 52.0, ch = 78.0, gap = 6.0, lift = 16.0;
    const boxH = ch + lift; // folga no topo pra carta selecionada subir sem cortar
    final ativo = _minhaVezAtiva;
    final larguraCartas = n * cw + (n - 1) * gap + 24;
    final conteudo = LayoutBuilder(builder: (context, cons) {
      final row = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (int i = 0; i < n; i++)
          Padding(
            padding: EdgeInsets.only(right: i == n - 1 ? 0 : gap),
            child: GestureDetector(
              onTap: ativo ? () => _tapCard(i) : null,
              child: Transform.translate(
                offset: Offset(0, _sel.contains(i) ? -lift : 0),
                child: SizedBox(width: cw, height: ch, child: _handCard(mao[i], _sel.contains(i))),
              ),
            ),
          ),
      ]);
      return SingleChildScrollView(
        controller: _handScroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, lift, 12, 0),
        child: larguraCartas < cons.maxWidth
            ? SizedBox(width: cons.maxWidth - 24, child: Center(child: row))
            : row,
      );
    });
    // desliza a mão inteira meia-CARTA pra baixo quando não é a vez (metade some, cortada pela borda)
    return SizedBox(
      height: boxH,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        offset: Offset(0, ativo ? 0.0 : (ch * 0.5) / boxH),
        child: conteudo,
      ),
    );
  }

  // carta da MÃO = imagem real do baralho; destaque dourado quando selecionada
  Widget _handCard(Carta c, bool sel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sel ? _mGoldHi : const Color(0x33000000), width: sel ? 2.4 : 0.5),
        boxShadow: [BoxShadow(color: Color(sel ? 0x99000000 : 0x77000000), blurRadius: sel ? 16 : 9, offset: const Offset(0, -3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_cartaAsset(c), fit: BoxFit.fill),
    );
  }
}

enum Sash { nenhuma, limpa, suja, n500 }
