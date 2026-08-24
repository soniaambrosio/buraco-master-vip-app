// escolha_assento_screen.dart — a camada VISUAL da escolha de assento.
//
// ---------------------------------------------------------------------------
// ESTA TELA NÃO SABE FALAR COM O SERVIDOR
// ---------------------------------------------------------------------------
//
// Ela recebe uma mesa já tipada (a mesma que o Lobby desenha, do mesmo
// retrato), a fase do pedido e a recusa, e desenha. Não pede, não confirma,
// não navega e — o ponto inteiro desta OS — NÃO MARCA CADEIRA COMO OCUPADA.
//
// A ocupação que aparece aqui é sempre a do último retrato do servidor. Entre
// o toque e o ACK a cadeira pedida continua desenhada como LIVRE, com a
// seleção por fora; pintá-la de ocupada seria o cliente afirmando o que só o
// servidor sabe, e ela pode muito bem voltar recusada.
//
// ---------------------------------------------------------------------------
// A MESA PODE SUMIR DEBAIXO DESTA TELA
// ---------------------------------------------------------------------------
//
// O retrato se atualiza sozinho a cada poucos segundos, e a mesa que estava
// aqui pode ter enchido, começado ou acabado. Quando ela sai da lista, [mesa]
// chega nulo e a tela DIZ isso — em vez de continuar desenhando a fotografia
// velha com botões que levariam recusa.
//
// ---------------------------------------------------------------------------
// O QUE É ANUNCIADO, E POR QUE SÓ ISSO
// ---------------------------------------------------------------------------
//
// Há UMA região viva na tela: a linha de estado. Ela existe só quando há algo
// transitório a dizer — pedido em voo, recusa, confirmação — e o texto dela é
// estável dentro de cada estado. Pôr `liveRegion` no cabeçalho ou nas cadeiras
// faria o leitor de tela repetir a mesa inteira a cada atualização automática
// da lista, que é a cada poucos segundos, para sempre.

import 'package:flutter/material.dart';

import '../descoberta/estado_descoberta.dart';
import '../descoberta/modelo_descoberta.dart';
import '../ingresso/estado_ingresso.dart';
import '../ingresso/modelo_ingresso.dart';

/// A escolha de assento de UMA mesa pública.
class EscolhaAssentoScreen extends StatelessWidget {
  const EscolhaAssentoScreen({
    super.key,
    required this.mesa,
    required this.fase,
    required this.assentoSolicitado,
    required this.recusa,
    required this.onVoltar,
    required this.onAtualizar,
    this.faseDaDescoberta = FaseDaDescoberta.disponivel,
    this.confirmacao,
    this.onEscolherAssento,
    this.onEntrarEmQualquerLugar,
  });

  /// A mesa, do retrato vigente. `null` quando ela saiu da lista.
  final MesaPublica? mesa;

  final FaseDoIngresso fase;

  /// A cadeira PEDIDA, enquanto o pedido está em voo. Não é ocupação.
  final int? assentoSolicitado;

  final RecusaDeIngresso? recusa;

  /// O que o servidor confirmou. Só existe depois do ACK, e serve para a tela
  /// dizer o que aconteceu enquanto a navegação sai.
  final IngressoConfirmado? confirmacao;

  /// A fase da descoberta, para distinguir "a mesa sumiu" de "ainda não sei".
  final FaseDaDescoberta faseDaDescoberta;

  final VoidCallback onVoltar;
  final VoidCallback onAtualizar;

  /// Pede UMA cadeira. Nulo em prévia isolada de tela.
  final void Function(int assento)? onEscolherAssento;

  /// Pede ingresso SEM escolher cadeira — o campo não vai no fio e o servidor
  /// aplica a ordem dele. Nulo em prévia isolada.
  final VoidCallback? onEntrarEmQualquerLugar;

  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);
  static const _feltro = Color(0xFF123020);
  static const _feltroBorda = Color(0x882F7D4D);
  static const _verdeClaro = Color(0xFFA9D6BB);
  static const _vermelho = Color(0xFFE39A8A);

  /// Piso de toque. A mesma régua do Lobby.
  static const double _alvoMinimo = 48;

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
                children: [_cabecalho(), Expanded(child: _corpo())],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CABEÇALHO
  // -------------------------------------------------------------------------

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onVoltar,
            tooltip: 'Voltar',
            icon: const Icon(
              Icons.chevron_left,
              color: _gold,
              size: 30,
              semanticLabel: 'Voltar',
            ),
            constraints: const BoxConstraints(
              minWidth: _alvoMinimo,
              minHeight: _alvoMinimo,
            ),
          ),
          const Expanded(
            child: Text(
              'Escolha seu lugar',
              style: TextStyle(
                color: _goldHi,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onAtualizar,
            tooltip: 'Atualizar a mesa',
            icon: const Icon(
              Icons.refresh_rounded,
              color: _gold,
              size: 26,
              semanticLabel: 'Atualizar a mesa',
            ),
            constraints: const BoxConstraints(
              minWidth: _alvoMinimo,
              minHeight: _alvoMinimo,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CORPO
  // -------------------------------------------------------------------------

  Widget _corpo() {
    final m = mesa;
    if (m == null) return _semMesa();

    // `ListView` e não `Column`: em 320 dp com fonte a 200% quatro cadeiras
    // mais cabeçalho passam da altura da tela, e sem rolagem o conteúdo sairia
    // pela borda — e um nó semântico fora da viewport não existe para o leitor
    // de tela, o que faria a cadeira 4 sumir de quem mais precisa dela.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _resumoDaMesa(m),
        const SizedBox(height: 12),
        _linhaDeEstado(),
        for (final a in m.assentos) _linhaDeAssento(m, a),
        const SizedBox(height: 10),
        _acaoAutomatica(m),
      ],
    );
  }

  Widget _semMesa() {
    final aindaCarregando =
        faseDaDescoberta == FaseDaDescoberta.carregando ||
        faseDaDescoberta == FaseDaDescoberta.ociosa;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        Semantics(
          container: true,
          label: aindaCarregando
              ? 'Carregando a mesa. Estamos pedindo a lista ao servidor.'
              : 'Esta mesa não está mais na lista. Ela pode ter enchido ou a '
                    'partida pode ter começado. Volte e escolha outra.',
          excludeSemantics: true,
          child: Column(
            children: [
              Icon(
                aindaCarregando
                    ? Icons.hourglass_top_rounded
                    : Icons.table_restaurant_rounded,
                color: _mut,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                aindaCarregando ? 'Carregando a mesa…' : 'Mesa indisponível',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                aindaCarregando
                    ? 'Estamos pedindo a lista ao servidor.'
                    : 'Ela pode ter enchido ou a partida pode ter começado. '
                          'Volte e escolha outra.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mut,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _botao(rotulo: 'Voltar para as mesas', aoTocar: onVoltar)),
      ],
    );
  }

  Widget _resumoDaMesa(MesaPublica m) {
    final linha =
        '${m.modalidade.rotulo} · Meta ${m.metaPontos} · '
        '${m.jogadores} de ${m.capacidade} '
        '${m.jogadores == 1 ? 'jogador' : 'jogadores'} · '
        '${m.vagas} ${m.vagas == 1 ? 'vaga' : 'vagas'}';
    return Semantics(
      container: true,
      label: '${m.nome}. $linha. ${m.estadoIngresso.rotulo}.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _card,
          border: Border.all(color: _borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.nome,
              style: const TextStyle(
                color: _goldHi,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              linha,
              style: const TextStyle(color: _mut, fontSize: 12.5, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              m.estadoIngresso.rotulo,
              style: TextStyle(
                color: m.ingressavel ? _verdeClaro : _mut,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // A LINHA DE ESTADO — a única região viva da tela
  // -------------------------------------------------------------------------

  /// O texto transitório, ou `null` quando não há nada a anunciar.
  String? get textoDeEstado {
    final r = recusa;
    if (r != null) return r.mensagem;
    final c = confirmacao;
    if (fase == FaseDoIngresso.confirmado && c != null) return c.anuncio;
    if (fase == FaseDoIngresso.solicitando) {
      final a = assentoSolicitado;
      return a == null
          ? 'Pedindo um lugar nesta mesa. Aguarde a resposta do servidor.'
          : 'Pedindo a posição ${a + 1}. Aguarde a resposta do servidor.';
    }
    return null;
  }

  Widget _linhaDeEstado() {
    final texto = textoDeEstado;
    if (texto == null) return const SizedBox.shrink();
    final erro = recusa != null;
    final ok = recusa == null && fase == FaseDoIngresso.confirmado;
    final cor = erro ? _vermelho : (ok ? _verdeClaro : _mut);
    return Semantics(
      liveRegion: true,
      label: texto,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF2A1B0E),
          border: Border.all(color: erro ? _vermelho : _borda),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              erro
                  ? Icons.report_problem_rounded
                  : (ok
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_top_rounded),
              size: 16,
              color: cor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: cor, fontSize: 12.5, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // AS QUATRO CADEIRAS
  // -------------------------------------------------------------------------

  /// A frase de UMA cadeira, para quem usa leitor de tela.
  ///
  /// Diz a posição, quem está lá e — quando o lugar é escolhível — que dá para
  /// escolhê-lo. O estado `selected` conta o resto, e o `enabled` conta se o
  /// gesto vale agora.
  String fraseDoAssento(MesaPublica m, AssentoPublico a) {
    final posicao = 'Posição ${a.assento + 1}';
    if (a.ocupado) {
      if (a.ehBot) return '$posicao, robô';
      final nome = a.apelido;
      return nome == null || nome.isEmpty
          ? '$posicao, ocupada'
          : '$posicao, $nome';
    }
    if (!m.ingressavel) return '$posicao, livre, indisponível nesta mesa';
    if (assentoSolicitado == a.assento && fase == FaseDoIngresso.solicitando) {
      return '$posicao, pedido enviado, aguardando o servidor';
    }
    return '$posicao, livre, sentar aqui';
  }

  Widget _linhaDeAssento(MesaPublica m, AssentoPublico a) {
    final escolher = onEscolherAssento;
    final emVoo = fase == FaseDoIngresso.solicitando;
    final selecionado = emVoo && assentoSolicitado == a.assento;
    // ESCOLHÍVEL = livre, mesa ingressável, sem pedido em voo e com porta.
    //
    // Nenhuma dessas quatro é opinião sobre ocupação: `a.ocupado` e
    // `m.ingressavel` vêm do servidor, `emVoo` é a trava do toque duplo e
    // `escolher` é a existência da porta.
    final escolhivel = !a.ocupado && m.ingressavel && !emVoo && escolher != null;

    final conteudo = _conteudoDoAssento(m, a, selecionado: selecionado);

    if (!escolhivel) {
      // Nó tocável que não faz nada é pior que nenhum. Ocupada, mesa fechada
      // ou pedido em voo: é texto, com estado, e não botão.
      return Semantics(
        container: true,
        enabled: false,
        selected: selecionado,
        label: fraseDoAssento(m, a),
        excludeSemantics: true,
        child: conteudo,
      );
    }

    // `excludeSemantics` AQUI LEVARIA O TOQUE JUNTO — a lição da OS 38.2. A
    // semântica ENVOLVE o `InkWell` (herdando a ação dele) e quem tem a
    // semântica descartada é só o conteúdo de dentro.
    return Semantics(
      button: true,
      enabled: true,
      selected: false,
      label: fraseDoAssento(m, a),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => escolher(a.assento),
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(child: conteudo),
        ),
      ),
    );
  }

  Widget _conteudoDoAssento(
    MesaPublica m,
    AssentoPublico a, {
    required bool selecionado,
  }) {
    final livre = !a.ocupado;
    final rotulo = livre
        ? 'Livre'
        : (a.ehBot ? 'Robô' : (a.apelido ?? 'Jogador'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(minHeight: _alvoMinimo),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selecionado
            ? const Color(0xFF3A2A15)
            : (livre ? const Color(0xFF150E08) : _feltro),
        border: Border.all(
          color: selecionado ? _gold : (livre ? _borda : _feltroBorda),
          width: selecionado ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            livre
                ? Icons.event_seat_outlined
                : (a.ehBot ? Icons.smart_toy_outlined : Icons.person_rounded),
            size: 18,
            color: livre ? _mut : _verdeClaro,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Posição ${a.assento + 1}',
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  rotulo,
                  style: TextStyle(
                    color: livre ? _mut : _texto,
                    fontSize: 12.5,
                    fontWeight: livre ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (livre && m.ingressavel)
            Text(
              selecionado ? 'Pedindo…' : 'Sentar',
              style: TextStyle(
                color: selecionado ? _goldHi : _gold,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // A AÇÃO SECUNDÁRIA — ingresso sem escolher
  // -------------------------------------------------------------------------

  Widget _acaoAutomatica(MesaPublica m) {
    final entrar = onEntrarEmQualquerLugar;
    if (entrar == null || !m.ingressavel) return const SizedBox.shrink();
    if (fase == FaseDoIngresso.solicitando) return const SizedBox.shrink();
    return Center(
      child: _botao(
        rotulo: 'Entrar em qualquer lugar',
        aoTocar: entrar,
        // O texto explica o que o servidor faz — e NÃO promete uma cadeira.
        // Prometer "você senta ao lado de fulano" seria reproduzir aqui o
        // algoritmo do servidor, que é o caminho mais curto para os dois
        // discordarem.
        detalhe: 'O servidor escolhe o lugar disponível.',
      ),
    );
  }

  Widget _botao({
    required String rotulo,
    required VoidCallback aoTocar,
    String? detalhe,
  }) {
    return Semantics(
      button: true,
      label: detalhe == null ? rotulo : '$rotulo. $detalhe',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: _alvoMinimo,
                minWidth: 160,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF3A2A15),
                border: Border.all(color: _gold, width: 1.4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rotulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _goldHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detalhe != null)
                    Text(
                      detalhe,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _mut, fontSize: 11.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
