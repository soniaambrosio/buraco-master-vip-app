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
import 'pages/torneios_preview_page.dart';
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
import 'screens/loja_categoria_screen.dart';
import 'services/online_service.dart';
import 'services/configuracoes_service.dart';
import 'screens/splash_oficial_screen.dart';
import 'screens/preparando_partida_screen.dart';
import 'screens/hall_screen.dart';
import 'screens/onde_jogar_screen.dart';
import 'widgets/convite_vip.dart';
import 'mesa.dart';

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
  // Blindado: no celular o Firebase sobe normal; no navegador (versão web de
  // teste), se a config de Android não inicializar, o jogo roda mesmo assim —
  // só o login Google fica indisponível, que não é necessário pra jogar/testar.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ',
        appId: '1:203886484007:android:734aaa61ca5ca68b29cc02',
        messagingSenderId: '203886484007',
        projectId: 'buraco-master-vip',
        storageBucket: 'buraco-master-vip.firebasestorage.app',
      ),
    );
  } catch (_) {
    // Ambiente sem Firebase configurado (ex.: web de teste) — segue o jogo.
  }
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
      // Banner de temporada abre a CENTRAL DE TORNEIOS (1ª entrega, mocks do contrato).
      onAbrirTemporada: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TorneiosPreviewPage()),
      ),
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
  // Estado REAL: carrega do disco (SharedPreferences) e persiste cada mudança.
  Configuracoes _config = const Configuracoes(versaoApp: '1.0.0');

  @override
  void initState() {
    super.initState();
    ConfiguracoesService.instance.carregar(versaoApp: '1.0.0').then((c) {
      if (mounted) setState(() => _config = c);
    });
  }

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

  // Cabeçalho: usa o login real quando existir; senão, valores neutros.
  PerfilResumo _montarPerfil() {
    var apelido = 'Você';
    var email = '';
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        if ((u.displayName ?? '').isNotEmpty) apelido = u.displayName!;
        email = u.email ?? '';
      }
    } catch (_) {
      // Firebase indisponível (ex.: web de teste) — segue com neutro.
    }
    return PerfilResumo(
      apelido: apelido,
      email: email,
      vip: false,
      moedas: 0,
    );
  }

  Future<void> _salvar(Configuracoes novo) async {
    setState(() => _config = novo); // aplica na hora na UI
    await ConfiguracoesService.instance.salvar(novo); // persiste no disco
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
      // Logout REAL (blindado — não quebra se o Firebase não estiver ativo).
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        _aviso('Você saiu da conta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfiguracoesScreen(
      perfil: _montarPerfil(),
      config: _config,
      onVoltar: () => Navigator.of(context).maybePop(),
      callbacks: ConfiguracoesCallbacks(
        onAlterar: _salvar,
        onEditarPerfil: _abrirPerfil,
        onAssinaturaVip: _abrirLoja,
        onMoedasCompras: _abrirLoja,
        onBloqueados: () => _aviso('Jogadores bloqueados — em breve.'),
        onRegras: _abrirComoJogar,
        onSuporte: () => _aviso('Suporte — em breve.'),
        onTermos: () => _aviso('Termos e privacidade — em breve.'),
        onAvaliar: () => _aviso('Avaliar na loja — em breve.'),
        onSair: _confirmarSaida,
      ),
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
      onAbrirCategoria: (categoria) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _LojaCategoriaPreviewHost(categoria: categoria),
            ),
          ),
      onPresentear: (itemId) => _aviso('Escolha um amigo para receber $itemId'),
      onBuscarPresenteado: (_) {},
      onEnviarPresente: (itemId, jogadorId) =>
          _aviso('Presente $itemId enviado para $jogadorId'),
    );
  }
}

// ===================== LOJA · TELA DE CATEGORIA (host — Codex UI + Claude liga depois) =====================
// Aberta pela grade COSMÉTICOS do hub da Loja (onAbrirCategoria). Callbacks mockados;
// o Claude liga saldo/inventário/comprar/equipar no LojaService (ver PLANO-LOJA-COSMETICOS.md).
class _LojaCategoriaPreviewHost extends StatelessWidget {
  final LojaCategoria categoria;
  const _LojaCategoriaPreviewHost({required this.categoria});

  void _aviso(BuildContext context, String texto) {
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

  void _nav(BuildContext context, NavDestino destino) {
    switch (destino) {
      case NavDestino.inicio:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case NavDestino.loja:
        Navigator.of(context).pop();
        break;
      case NavDestino.ranking:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _RankingPreviewHost()),
        );
        break;
      case NavDestino.perfil:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PerfilPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LojaCategoriaScreen(
      vm: LojaCategoriaVM.mock(categoria),
      onVoltar: () => Navigator.of(context).pop(),
      onComprarMoedas: () =>
          _aviso(context, 'Carteira — compra de moedas fica com o Claude'),
      onComprar: (id) => _aviso(context, 'Abrindo compra de $id'),
      onConfirmarCompra: (id) =>
          _aviso(context, 'Compra de $id — economia real fica com o Claude'),
      onEquipar: (id) =>
          _aviso(context, 'Equipar $id — inventário real fica com o Claude'),
      onItemBloqueado: (id) =>
          _aviso(context, '$id está bloqueado (VIP ou progressão)'),
      onPresentear: (id) => _aviso(context, 'Escolha quem vai receber $id 💜'),
      onBuscarPresenteado: (_) {},
      onEnviarPresente: (itemId, jogadorId) =>
          _aviso(context, 'Presente $itemId enviado para $jogadorId'),
      onNav: (destino) => _nav(context, destino),
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

  // Modal de "Regras do Hall" — explica as 5 categorias de glória (antes não abria nada).
  void _mostrarRegras(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF2160D08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x55EFB94A)),
        ),
        title: const Text('📜 Regras do Hall',
            style: TextStyle(color: Color(0xFFF6E2A6), fontWeight: FontWeight.w900)),
        content: const SingleChildScrollView(
          child: Text(
            'O Hall dos Imortais celebra os melhores por período:\n\n'
            '🏆 Campeão de hoje — quem mais venceu no dia.\n'
            '👑 Melhor dupla — a parceria mais afiada.\n'
            '🔥 Maior sequência — o maior embalo de vitórias.\n'
            '⭐ Rei/Rainha da semana — o destaque dos últimos 7 dias.\n'
            '🌙 Lenda do mês — o nome que dominou o mês.\n\n'
            'Tudo é automático pelos resultados das partidas. Jogue, vença e '
            'entre para a história! 🃏',
            style: TextStyle(color: Color(0xFFEFE3CC), fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi',
                style: TextStyle(color: Color(0xFFEFB94A), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HallScreen(
      vm: HallVM.mock(),
      onVoltar: () => Navigator.of(context).maybePop(),
      onVerRegras: () => _mostrarRegras(context),
      onVerPerfil: (id) => _aviso(context, 'Abrir perfil: $id'),
      onPresentear: (id) => _aviso(context, 'Escolha um presente para homenagear $id 👑'),
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
        if (id == 'privada') {
          // ONLINE de verdade (Trilha A): criar/entrar por código no servidor.
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _OnlineLobbyHost()),
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

// ===================== ONLINE — LOBBY / CONEXÃO (Trilha A · fatia A1) =====================
// Conecta no servidor real (Railway), cria/entra numa mesa por código e mostra o
// estado que o servidor devolve. Prova a conexão ponta-a-ponta do app com o online.
// A mesa visual completa (renderizar a partida do servidor) é a próxima fatia (A2).
class _OnlineLobbyHost extends StatefulWidget {
  const _OnlineLobbyHost();
  @override
  State<_OnlineLobbyHost> createState() => _OnlineLobbyHostState();
}

class _OnlineLobbyHostState extends State<_OnlineLobbyHost> {
  final OnlineService _srv = OnlineService();
  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _apelido = TextEditingController(text: 'Você');

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);

  @override
  void initState() {
    super.initState();
    _srv.addListener(_atualizar);
    _srv.conectar();
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _srv.removeListener(_atualizar);
    _srv.desligar();
    _codigo.dispose();
    _apelido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _srv.visao;
    final List<Widget> corpo;
    if (v == null) {
      corpo = _entrada();
    } else if (v['lobby'] == true) {
      corpo = _lobby(v);
    } else {
      corpo = _emJogo(v);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF120A06),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C130C),
        foregroundColor: _ouroClaro,
        title: const Text('Jogar Online'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusChip(),
                  if (_srv.erro != null) ...[
                    const SizedBox(height: 12),
                    _erroBox(_srv.erro!),
                  ],
                  const SizedBox(height: 18),
                  ...corpo,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip() {
    final (cor, txt) = switch (_srv.status) {
      OnlineStatus.conectado => (const Color(0xFF27AE60), 'conectado ao servidor'),
      OnlineStatus.conectando => (_ouro, 'conectando…'),
      OnlineStatus.erro => (const Color(0xFFE05B5B), 'sem conexão'),
      OnlineStatus.desconectado => (_mut, 'desconectado'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(txt, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  Widget _erroBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x33E05B5B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x55E05B5B)),
        ),
        child: Text(msg, style: const TextStyle(color: Color(0xFFF6C9C9), fontSize: 12.5)),
      );

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _mut),
        filled: true,
        fillColor: const Color(0xFF1C130C),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x33EFB94A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _ouro),
        ),
      );

  // Ainda não entrou numa mesa: criar ou entrar por código.
  List<Widget> _entrada() {
    final pronto = _srv.conectado;
    return [
      TextField(controller: _apelido, style: const TextStyle(color: _texto), decoration: _dec('Seu apelido')),
      const SizedBox(height: 16),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ouro, foregroundColor: const Color(0xFF1C130C),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto
            ? () => _srv.criarMesa(apelido: _apelido.text.trim().isEmpty ? 'Você' : _apelido.text.trim())
            : null,
        child: const Text('Criar mesa', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Expanded(child: Divider(color: Color(0x33EFB94A))),
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('ou', style: TextStyle(color: _mut))),
          Expanded(child: Divider(color: Color(0x33EFB94A))),
        ]),
      ),
      TextField(
        controller: _codigo,
        style: const TextStyle(color: _texto, letterSpacing: 1.5),
        textCapitalization: TextCapitalization.characters,
        decoration: _dec('Código da mesa (ex.: BURACO-0001)'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ouroClaro, side: const BorderSide(color: _ouro),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto && _codigo.text.trim().isNotEmpty
            ? () => _srv.entrarMesa(
                codigo: _codigo.text.trim().toUpperCase(),
                apelido: _apelido.text.trim().isEmpty ? 'Você' : _apelido.text.trim())
            : null,
        child: const Text('Entrar por código', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ];
  }

  // Na sala, aguardando os jogadores.
  List<Widget> _lobby(Map<String, dynamic> v) {
    final assentos = (v['assentos'] as List?) ?? const [];
    final ehCriador = v['criador'] == true;
    return [
      const Text('Código da mesa', textAlign: TextAlign.center, style: TextStyle(color: _mut, fontSize: 12)),
      const SizedBox(height: 4),
      SelectableText(
        '${v['codigo'] ?? '—'}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _ouroClaro, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
      const SizedBox(height: 6),
      const Text('Compartilhe o código com quem vai jogar 🃏',
          textAlign: TextAlign.center, style: TextStyle(color: _mut, fontSize: 12)),
      const SizedBox(height: 18),
      ...List.generate(assentos.length, (i) {
        final a = assentos[i] as Map?;
        final vazio = a == null || a['vazio'] == true;
        final nome = vazio ? 'aguardando…' : (a['apelido'] ?? 'jogador').toString();
        final ehVoce = !vazio && a['ehVoce'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C130C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ehVoce ? _ouro : const Color(0x22EFB94A)),
          ),
          child: Row(children: [
            Text('Cadeira ${i + 1}', style: const TextStyle(color: _mut, fontSize: 12)),
            const Spacer(),
            Text(nome + (ehVoce ? ' (você)' : ''),
                style: TextStyle(color: vazio ? _mut : _texto, fontWeight: FontWeight.w700)),
          ]),
        );
      }),
      const SizedBox(height: 12),
      if (ehCriador)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ouro, foregroundColor: const Color(0xFF1C130C),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _srv.iniciarPartida(),
          child: const Text('Iniciar partida', style: TextStyle(fontWeight: FontWeight.w800)),
        )
      else
        const Text('O criador da mesa inicia a partida.',
            textAlign: TextAlign.center, style: TextStyle(color: _mut, fontSize: 12)),
      const SizedBox(height: 10),
      TextButton(onPressed: () => _srv.sair(), child: const Text('Sair da mesa', style: TextStyle(color: _mut))),
    ];
  }

  // Partida em andamento: mostra o estado do servidor (prova que a visão chega).
  // A renderização completa da mesa online é a fatia A2.
  List<Widget> _emJogo(Map<String, dynamic> v) {
    final placar = (v['placar'] as Map?) ?? const {};
    final mao = (v['suaMao'] as List?) ?? const [];
    final suaVez = v['suaVez'] == true;
    final topo = v['lixoTopo'] as Map?;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C130C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33EFB94A)),
        ),
        child: Column(children: [
          Text(suaVez ? '👉 Sua vez!' : '⏳ Vez de outro jogador',
              style: TextStyle(color: suaVez ? _ouroClaro : _mut, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Placar  —  Nós ${placar['nos'] ?? 0}  ×  ${placar['eles'] ?? 0} Eles',
              style: const TextStyle(color: _texto)),
          const SizedBox(height: 6),
          Text('Rodada ${v['rodada'] ?? '-'}  ·  ${(v['modalidade'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(color: _mut, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Cartas na sua mão: ${mao.length}', style: const TextStyle(color: _texto)),
          if (topo != null)
            Text('Topo do lixo: ${topo['valor'] ?? ''} ${topo['naipe'] ?? ''}',
                style: const TextStyle(color: _mut, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x2227AE60),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x5527AE60)),
        ),
        child: const Text(
          '✅ Conectado e recebendo a partida do servidor!\n'
          'A mesa visual completa online é a próxima fatia (A2).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFBFE9CC), fontSize: 12.5, height: 1.4),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(onPressed: () => _srv.sair(), child: const Text('Sair da mesa', style: TextStyle(color: _mut))),
    ];
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

