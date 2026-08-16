// lobby_online.dart — criar ou entrar numa mesa no servidor.
//
// ---------------------------------------------------------------------------
// A TELA NÃO É MAIS DONA DO TRANSPORTE
// ---------------------------------------------------------------------------
//
// Antes ela construía o `OnlineService` e a `PonteSessaoOnline` no
// `didChangeDependencies`, e os destruía ao sair. Duas coisas quebravam nisso, e
// as duas são exigência desta OS:
//
//   * um logout disparado FORA daqui — pela tela de Ajustes, que é onde o botão
//     de sair fica — não encontrava ponte nenhuma montada para derrubar o
//     socket. Ele morria junto com a tela, se a tela estivesse aberta, e por
//     acidente de ciclo de vida;
//
//   * duas rotas do lobby empilhadas construiriam dois transportes.
//
// Agora o transporte vem do escopo, montado uma vez pela raiz. Esta tela só faz
// duas coisas com ele: pede para conectar quando monta, e escuta para
// redesenhar. Não o desliga ao sair — sair da tela do lobby não é sair do jogo
// online, e derrubar a conexão aqui tiraria a pessoa da mesa por navegação.
//
// NÃO EXISTE AQUI um vigia de `FirebaseAuth.authStateChanges()`. A folha da
// conexão publicável tinha um: ao ver logout, chamava `encerrarPorLogout()`
// direto. Numa árvore com sessão canônica isso é um SEGUNDO dono de
// autenticação — uma tela com opinião própria sobre quem está logado, sem noção
// da geração da sessão. Quem observa a sessão e traduz cada troca numa única
// transição do transporte é a `PonteSessaoOnline`, montada na raiz. Ela cobre
// logout, login e troca de conta; o vigia cobria só logout.

import 'package:flutter/material.dart';

import '../services/online_service.dart';
import 'escopo_transporte.dart';

class LobbyOnline extends StatefulWidget {
  const LobbyOnline({super.key});

  @override
  State<LobbyOnline> createState() => _LobbyOnlineState();
}

class _LobbyOnlineState extends State<LobbyOnline> {
  OnlineService? _srv;
  bool _pediuConexao = false;

  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _apelido = TextEditingController(text: 'Você');

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final srv = EscopoTransporte.talvezDe(context);
    if (identical(srv, _srv)) return;
    _srv?.removeListener(_atualizar);
    _srv = srv;
    _srv?.addListener(_atualizar);

    // O PEDIDO DE CONEXÃO É DA PESSOA, e acontece uma vez: abrir esta tela é o
    // gesto de querer jogar online. A trava importa porque
    // `didChangeDependencies` roda de novo a cada notificação do escopo — sem
    // ela, cada mudança de status viraria um `conectar()` a mais.
    //
    // DEPOIS DO QUADRO, e não aqui dentro: `conectar()` muda o status na hora e
    // notifica, e o ouvinte desse aviso é o `EscopoTransporte`, que fica ACIMA
    // desta tela. Marcar um ancestral como sujo enquanto um descendente está
    // sendo construído é erro de framework — o Flutter constrói de cima para
    // baixo e já passou por ele.
    if (srv != null && !_pediuConexao) {
      _pediuConexao = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) srv.conectar();
      });
    }
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Só solta o ouvinte. O transporte continua vivo — ele é da raiz.
    _srv?.removeListener(_atualizar);
    _codigo.dispose();
    _apelido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final srv = _srv;
    if (srv == null) {
      // Fora da casca de produção (pré-visualização isolada). Não há transporte
      // e não se constrói um aqui — seria um segundo socket sem ponte.
      return const _MolduraDoLobby(
        corpo: [
          Text(
            'O jogo online não está disponível nesta visualização.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mut, fontSize: 13),
          ),
        ],
      );
    }

    final v = srv.visao;
    final List<Widget> corpo;
    if (v == null) {
      corpo = _entrada(srv);
    } else if (v['lobby'] == true) {
      corpo = _lobby(srv, v);
    } else {
      corpo = _emJogo(srv, v);
    }

    return _MolduraDoLobby(
      corpo: [
        _statusChip(srv),
        if (srv.erro != null) ...[
          const SizedBox(height: 12),
          _erroBox(srv.erro!),
        ],
        if (srv.falhaTerminal) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: srv.tentarNovamente,
              child: const Text(
                'Tentar de novo',
                style: TextStyle(
                  color: _ouroClaro,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ...corpo,
      ],
    );
  }

  Widget _statusChip(OnlineService srv) {
    final (cor, txt) = switch (srv.status) {
      OnlineStatus.conectado => (
        const Color(0xFF27AE60),
        'conectado ao servidor',
      ),
      OnlineStatus.conectando => (_ouro, 'conectando…'),
      // a conexão está aberta, mas o servidor ainda não aceitou a credencial —
      // nenhum comando de jogador roda nesse intervalo
      OnlineStatus.autenticando => (_ouro, 'identificando você…'),
      OnlineStatus.erro => (const Color(0xFFE05B5B), 'sem conexão'),
      OnlineStatus.naoAutenticado => (
        const Color(0xFFE05B5B),
        'entre na sua conta para jogar online',
      ),
      OnlineStatus.atualizacaoObrigatoria => (
        const Color(0xFFE05B5B),
        'atualize o aplicativo para jogar online',
      ),
      OnlineStatus.servidorDesatualizado => (
        const Color(0xFFE05B5B),
        'servidor em atualização — tente mais tarde',
      ),
      // este build saiu sem endereço de servidor utilizável — nenhuma tentativa
      // de rede conserta isso, então a mensagem aponta para o build, não para a
      // rede
      OnlineStatus.configuracaoInvalida => (
        const Color(0xFFE05B5B),
        'este aplicativo está mal configurado',
      ),
      // o ciclo automático desistiu: melhor dizer isso do que girar para sempre
      OnlineStatus.semConexao => (
        const Color(0xFFE05B5B),
        'sem conexão — toque para tentar de novo',
      ),
      OnlineStatus.desconectado => (_mut, 'desconectado'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          txt,
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
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
    child: Text(
      msg,
      style: const TextStyle(color: Color(0xFFF6C9C9), fontSize: 12.5),
    ),
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

  String get _apelidoEscolhido =>
      _apelido.text.trim().isEmpty ? 'Você' : _apelido.text.trim();

  // Ainda não entrou numa mesa: criar ou entrar por código.
  List<Widget> _entrada(OnlineService srv) {
    final pronto = srv.conectado;
    return [
      TextField(
        controller: _apelido,
        style: const TextStyle(color: _texto),
        decoration: _dec('Seu apelido'),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ouro,
          foregroundColor: const Color(0xFF1C130C),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto
            ? () => srv.criarMesa(apelido: _apelidoEscolhido)
            : null,
        child: const Text(
          'Criar mesa',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(child: Divider(color: Color(0x33EFB94A))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('ou', style: TextStyle(color: _mut)),
            ),
            Expanded(child: Divider(color: Color(0x33EFB94A))),
          ],
        ),
      ),
      TextField(
        controller: _codigo,
        style: const TextStyle(color: _texto, letterSpacing: 1.5),
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) => setState(() {}),
        decoration: _dec('Código da mesa (ex.: BURACO-0001)'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ouroClaro,
          side: const BorderSide(color: _ouro),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto && _codigo.text.trim().isNotEmpty
            ? () => srv.entrarMesa(
                codigo: _codigo.text.trim().toUpperCase(),
                apelido: _apelidoEscolhido,
              )
            : null,
        child: const Text(
          'Entrar por código',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ];
  }

  // Na sala, aguardando os jogadores.
  List<Widget> _lobby(OnlineService srv, Map<String, dynamic> v) {
    final assentos = (v['assentos'] as List?) ?? const [];
    final ehCriador = v['criador'] == true;
    return [
      const Text(
        'Código da mesa',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mut, fontSize: 12),
      ),
      const SizedBox(height: 4),
      SelectableText(
        '${v['codigo'] ?? '—'}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ouroClaro,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Compartilhe o código com quem vai jogar 🃏',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mut, fontSize: 12),
      ),
      const SizedBox(height: 18),
      ...List.generate(assentos.length, (i) {
        final a = assentos[i] as Map?;
        final vazio = a == null || a['vazio'] == true;
        final nome = vazio
            ? 'aguardando…'
            : (a['apelido'] ?? 'jogador').toString();
        final ehVoce = !vazio && a['ehVoce'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C130C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ehVoce ? _ouro : const Color(0x22EFB94A)),
          ),
          child: Row(
            children: [
              Text(
                'Cadeira ${i + 1}',
                style: const TextStyle(color: _mut, fontSize: 12),
              ),
              const Spacer(),
              Text(
                nome + (ehVoce ? ' (você)' : ''),
                style: TextStyle(
                  color: vazio ? _mut : _texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 12),
      if (ehCriador)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ouro,
            foregroundColor: const Color(0xFF1C130C),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: srv.iniciarPartida,
          child: const Text(
            'Iniciar partida',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        )
      else
        const Text(
          'O criador da mesa inicia a partida.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mut, fontSize: 12),
        ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: srv.sair,
        child: const Text('Sair da mesa', style: TextStyle(color: _mut)),
      ),
    ];
  }

  // Partida em andamento: mostra o estado do servidor (prova que a visão chega).
  // A renderização completa da mesa online é a fatia A2.
  List<Widget> _emJogo(OnlineService srv, Map<String, dynamic> v) {
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
        child: Column(
          children: [
            Text(
              suaVez ? '👉 Sua vez!' : '⏳ Vez de outro jogador',
              style: TextStyle(
                color: suaVez ? _ouroClaro : _mut,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Placar  —  Nós ${placar['nos'] ?? 0}  ×  ${placar['eles'] ?? 0} Eles',
              style: const TextStyle(color: _texto),
            ),
            const SizedBox(height: 6),
            Text(
              'Rodada ${v['rodada'] ?? '-'}  ·  ${(v['modalidade'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(color: _mut, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Cartas na sua mão: ${mao.length}',
              style: const TextStyle(color: _texto),
            ),
            if (topo != null)
              Text(
                'Topo do lixo: ${topo['valor'] ?? ''} ${topo['naipe'] ?? ''}',
                style: const TextStyle(color: _mut, fontSize: 12),
              ),
          ],
        ),
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
          style: TextStyle(
            color: Color(0xFFBFE9CC),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: srv.sair,
        child: const Text('Sair da mesa', style: TextStyle(color: _mut)),
      ),
    ];
  }
}

class _MolduraDoLobby extends StatelessWidget {
  const _MolduraDoLobby({required this.corpo});

  final List<Widget> corpo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A06),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C130C),
        foregroundColor: const Color(0xFFF6E2A6),
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
                children: corpo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
