// excluir_conta_screen.dart — a tela de "Excluir minha conta".
//
// SEM I/O. Não importa `cloud_functions`, `firebase_auth` nem `firebase_core`, e
// isso não é preferência: `app/test/sessao/auditoria_identidade_test.dart` varre
// `lib/screens/` e `lib/pages/` e FALHA se encontrar `httpsCallable` ou
// `cloud_functions`. Aqui a tela desenha [ControladorDeExclusao.fase] e chama
// três métodos dele; quem fala com o servidor é a porta, atrás do controlador.
//
// ---------------------------------------------------------------------------
// AS TRÊS DECISÕES DE DESENHO, E O QUE CADA UMA EVITA
// ---------------------------------------------------------------------------
//
// 1. O AVISO VEM DO SERVIDOR, E É AGRUPADO POR DESTINO. Quatro listas — o que
//    some, o que fica sem seu nome, o que fica sem ligação com você, o que fica.
//    A quarta é a que costuma faltar nos aplicativos, e é a que responde a
//    pergunta que o jogador realmente tem: "vocês vão guardar o quê?".
//
// 2. A JUSTIFICATIVA FICA A UM TOQUE, E NÃO NA CARA. Despejar as trinta linhas
//    da matriz na primeira dobra faz ninguém ler nada. Cada grupo abre.
//
// 3. O BOTÃO SÓ ACENDE COM A PALAVRA DIGITADA. É o portão contra o toque
//    acidental — o único dos três que a tela participa. Os outros dois
//    (autenticação e reautenticação) são do servidor, e a tela nem os vê.

import 'package:flutter/material.dart';

import '../conta/controlador_exclusao.dart';
import '../conta/exclusao_de_conta.dart';

class ExcluirContaScreen extends StatefulWidget {
  const ExcluirContaScreen({
    super.key,
    required this.controlador,
    required this.onVoltar,
    required this.onConcluida,
  });

  final ControladorDeExclusao controlador;
  final VoidCallback onVoltar;

  /// Chamado quando a conta foi excluída e a sessão já morreu. É o host que
  /// decide para onde ir — a tela não conhece a árvore de navegação.
  final VoidCallback onConcluida;

  @override
  State<ExcluirContaScreen> createState() => _ExcluirContaScreenState();
}

class _ExcluirContaScreenState extends State<ExcluirContaScreen> {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _fundo = Color(0xFF080503);
  static const _card = Color(0xFF1C130C);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x44EFB94A);
  static const _perigo = Color(0xFF8C3535);
  static const _perigoClaro = Color(0xFFFFC2C2);

  final TextEditingController _campo = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controlador.addListener(_aoMudar);
    // O aviso é buscado UMA vez, aqui. `carregarAviso` é idempotente, então um
    // rebuild não vira uma segunda chamada — mesma trava de `garantirCarregada`
    // em `SessaoDoJogador`.
    widget.controlador.carregarAviso();
  }

  @override
  void dispose() {
    widget.controlador.removeListener(_aoMudar);
    _campo.dispose();
    super.dispose();
  }

  void _aoMudar() {
    if (!mounted) return;
    setState(() {});
    if (widget.controlador.fase == FaseDaExclusao.concluida) {
      widget.onConcluida();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _topo(),
                Expanded(child: _corpo(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            // Durante a execução não há volta: as etapas do backend já estão
            // rodando, e sair da tela não as cancela. Esconder o botão é mais
            // honesto do que oferecer um cancelamento que não existe.
            onPressed: widget.controlador.fase == FaseDaExclusao.excluindo
                ? null
                : widget.onVoltar,
            icon: const Icon(Icons.chevron_left_rounded, color: _ouro, size: 31),
          ),
          // `Expanded` + `ellipsis`: o título é longo e a barra tem o botão de
          // voltar ao lado. Num `Row` sem flex ele estoura a largura em telas
          // estreitas — e a fonte substituta do `flutter_test` é mais larga que
          // a real, então o teste vê o estouro antes do aparelho.
          const Expanded(
            child: Text(
              'Excluir minha conta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ouroClaro,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(ControladorDeExclusao c) {
    switch (c.fase) {
      case FaseDaExclusao.inicial:
      case FaseDaExclusao.carregandoAviso:
        return const Center(
          key: Key('exclusao-carregando'),
          child: CircularProgressIndicator(color: _ouro),
        );

      case FaseDaExclusao.bloqueada:
        return _bloqueada(c);

      case FaseDaExclusao.reautenticando:
        return const Center(
          key: Key('exclusao-reautenticando'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _ouro),
              SizedBox(height: 16),
              Text(
                'Confirme sua identidade para continuar.',
                style: TextStyle(color: _textoSec, fontSize: 12.5),
              ),
            ],
          ),
        );

      case FaseDaExclusao.excluindo:
        return const Center(
          key: Key('exclusao-executando'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _ouro),
              SizedBox(height: 16),
              Text(
                'Excluindo sua conta. Não feche o aplicativo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textoSec, fontSize: 12.5),
              ),
            ],
          ),
        );

      case FaseDaExclusao.concluida:
        return const Center(
          key: Key('exclusao-concluida'),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: _ouro, size: 44),
                SizedBox(height: 14),
                Text(
                  'Sua conta foi excluída.',
                  style: TextStyle(
                    color: _ouroClaro,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );

      case FaseDaExclusao.falhou:
        return _falhou(c);

      case FaseDaExclusao.aguardandoConfirmacao:
        return _aviso(c);
    }
  }

  // -------------------------------------------------------------------- aviso

  Widget _aviso(ControladorDeExclusao c) {
    final resumo = c.resumo;
    if (resumo == null) return const SizedBox.shrink();

    return ListView(
      key: const Key('exclusao-aviso'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        _alerta(),
        const SizedBox(height: 14),
        _grupo(
          chave: 'apagado',
          titulo: 'O que é apagado',
          subtitulo: 'Some do sistema e não volta.',
          icone: Icons.delete_outline_rounded,
          linhas: resumo.apagado,
        ),
        _grupo(
          chave: 'anonimizado',
          titulo: 'O que fica sem o seu nome',
          subtitulo:
              'A linha continua existindo, sem apelido e sem foto — para não '
              'reescrever a colocação de quem jogou com você.',
          icone: Icons.visibility_off_outlined,
          linhas: resumo.anonimizado,
        ),
        _grupo(
          chave: 'desvinculado',
          titulo: 'O que fica sem ligação com você',
          subtitulo:
              'O registro permanece, e o vínculo com a sua identidade é cortado.',
          icone: Icons.link_off_rounded,
          linhas: resumo.desvinculado,
        ),
        _grupo(
          chave: 'retido',
          titulo: 'O que é guardado, e por quê',
          subtitulo:
              'Registros que não são só seus: partidas com outras pessoas, '
              'denúncias em aberto e comprovantes de compra.',
          icone: Icons.inventory_2_outlined,
          linhas: resumo.retido,
        ),
        const SizedBox(height: 8),
        _confirmacao(c, resumo),
      ],
    );
  }

  Widget _alerta() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0E0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _perigo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _perigoClaro, size: 21),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Antes de continuar',
                  style: TextStyle(
                    color: _perigoClaro,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // As duas advertências que NÃO vêm da matriz porque não são sobre
          // dados: a assinatura da Play, que continua cobrando, e a ausência de
          // desfazer. Ver `kAvisosQueNaoVemDaMatriz`.
          for (final aviso in kAvisosQueNaoVemDaMatriz)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $aviso',
                style: const TextStyle(
                  color: Color(0xFFE8C9C9),
                  fontSize: 11.8,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grupo({
    required String chave,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required List<LinhaDoAviso> linhas,
  }) {
    if (linhas.isEmpty) return const SizedBox.shrink();

    return Container(
      key: Key('exclusao-grupo-$chave'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _ouro,
          collapsedIconColor: _textoSec,
          leading: Icon(icone, color: _ouro, size: 20),
          title: Text(
            '$titulo (${linhas.length})',
            style: const TextStyle(
              color: _texto,
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitulo,
              style: const TextStyle(
                color: _textoSec,
                fontSize: 10.6,
                height: 1.3,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            for (final linha in linhas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linha.caminho,
                      style: const TextStyle(
                        color: _ouroClaro,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linha.porque,
                      style: const TextStyle(
                        color: _textoSec,
                        fontSize: 10.6,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirmacao(ControladorDeExclusao c, ResumoDaExclusao resumo) {
    final habilitado = c.confirmacaoConfere(_campo.text);
    final palavra = resumo.palavraDeConfirmacao;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Para confirmar, digite $palavra',
            style: const TextStyle(
              color: _texto,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('exclusao-campo-confirmacao'),
            controller: _campo,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: _texto, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: palavra,
              hintStyle: const TextStyle(color: Color(0xFF6B6252)),
              filled: true,
              fillColor: const Color(0xFF130D08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borda),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ouro),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('exclusao-botao-confirmar'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8E2F2B),
              disabledBackgroundColor: const Color(0xFF3A2020),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            // `null` desabilita: o portão contra o toque acidental.
            onPressed: habilitado ? () => c.confirmar(_campo.text) : null,
            child: Text(
              'Excluir minha conta',
              style: TextStyle(
                color: habilitado ? _perigoClaro : const Color(0xFF7A6A6A),
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- bloqueada

  Widget _bloqueada(ControladorDeExclusao c) {
    final bloqueios = c.resumo?.bloqueios ?? const <BloqueioDeTorneio>[];
    return ListView(
      key: const Key('exclusao-bloqueada'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Icon(Icons.emoji_events_outlined, color: _ouro, size: 40),
        const SizedBox(height: 14),
        const Text(
          'Você ainda está em um torneio',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ouroClaro,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Uma conta que some no meio de um torneio deixa a mesa sem fechar e '
          'prende os outros jogadores. Cancele suas inscrições e volte aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textoSec, fontSize: 12.2, height: 1.4),
        ),
        const SizedBox(height: 16),
        // NOMEIA as inscrições: "cancele suas inscrições" sem dizer quais manda
        // a pessoa procurar.
        for (final b in bloqueios)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borda),
            ),
            child: Text(
              '${b.tournamentId} · edição ${b.editionId}',
              style: const TextStyle(color: _texto, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------- falhou

  Widget _falhou(ControladorDeExclusao c) {
    final falha = c.falha;
    return Center(
      key: const Key('exclusao-falhou'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _perigoClaro, size: 40),
            const SizedBox(height: 14),
            Text(
              _mensagem(falha),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _texto, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (falha?.vaiAdiantarTentarDeNovo ?? true)
              FilledButton(
                key: const Key('exclusao-botao-tentar-de-novo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B1B0C),
                ),
                onPressed: c.tentarDeNovo,
                child: const Text(
                  'Tentar de novo',
                  style: TextStyle(color: _ouroClaro, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A mensagem sai do MOTIVO, e nunca do texto que veio do servidor.
  ///
  /// O backend manda o código em `details.recusa` exatamente para isto. Escrever
  /// a frase aqui é o que permite melhorar o texto do servidor sem quebrar a
  /// tela — e o que garante que o jogador leia português, e não um identificador.
  static String _mensagem(FalhaExclusao? falha) {
    switch (falha?.motivo) {
      case MotivoFalhaExclusao.confirmacaoInvalida:
        return 'A palavra digitada não confere. Nada foi excluído.';
      case MotivoFalhaExclusao.reautenticacaoNecessaria:
        return 'Não conseguimos confirmar sua identidade. Entre de novo e '
            'tente outra vez.';
      case MotivoFalhaExclusao.naoAutenticado:
        return 'Sua sessão expirou. Entre de novo para continuar.';
      case MotivoFalhaExclusao.torneioEmAndamento:
        return 'Você ainda tem inscrição ativa em um torneio. Cancele e volte.';
      case MotivoFalhaExclusao.parcial:
        // O texto é diferente dos outros de propósito: parte da conta JÁ foi
        // excluída. Dizer "não foi possível" faria a pessoa supor que nada
        // aconteceu — e ela precisa saber que tem de terminar.
        return 'A exclusão começou e não terminou. Toque em "Tentar de novo" '
            'para concluir de onde parou.';
      case MotivoFalhaExclusao.indisponivel:
        return 'Não conseguimos falar com o servidor agora. Nada foi excluído.';
      case MotivoFalhaExclusao.desconhecida:
      case null:
        return 'Algo deu errado. Nada foi excluído.';
    }
  }
}
