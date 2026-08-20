import 'dart:math' as math;

import 'package:flutter/material.dart';

enum EstadoAmizade { disponivel, enviado, amigos, bloqueado }

class JogadorResultadoVM {
  final int assento;
  final String nome;
  final String avatar;
  final bool souEu;

  const JogadorResultadoVM({
    required this.assento,
    required this.nome,
    required this.avatar,
    this.souEu = false,
  });
}

class DetalhePontuacaoVM {
  final int total;
  final int canastras;
  final int cartasBaixadas;
  final int bonusBatida;
  final int descontoMao;
  final int penalidadeMorto;
  final int limpas;
  final int sujas;
  final int de500;
  final int de1000;

  const DetalhePontuacaoVM({
    required this.total,
    required this.canastras,
    required this.cartasBaixadas,
    required this.bonusBatida,
    required this.descontoMao,
    required this.penalidadeMorto,
    required this.limpas,
    required this.sujas,
    required this.de500,
    required this.de1000,
  });

  factory DetalhePontuacaoVM.vazio() => const DetalhePontuacaoVM(
        total: 0,
        canastras: 0,
        cartasBaixadas: 0,
        bonusBatida: 0,
        descontoMao: 0,
        penalidadeMorto: 0,
        limpas: 0,
        sujas: 0,
        de500: 0,
        de1000: 0,
      );
}

class ResultadoPartidaScreen extends StatelessWidget {
  static const _gold = Color(0xFFE5B84F);
  static const _goldHi = Color(0xFFFFE7A0);
  static const _purple = Color(0xFF9D43D8);
  static const _purpleHi = Color(0xFFD690FF);
  static const _green = Color(0xFF2E8B57);

  // ---------------------------------------------------------------------
  // RÉGUA DE ACESSIBILIDADE DESTA TELA
  // ---------------------------------------------------------------------
  //
  // TIPOGRAFIA. A tela nasceu com texto produtivo entre 6,6 e 9 pt — abaixo
  // do que se lê num celular, e abaixo do piso da própria Casca, que não
  // desce de 10,5. Os tamanhos abaixo são a escala desta tela ancorada nesse
  // piso: nenhum texto produtivo abaixo de `_fsMinima`. A hierarquia entre
  // título, placar, detalhe e ação foi mantida — o que mudou foi o chão.
  static const double _fsMinima = 11; // chips e rótulos curtíssimos
  static const double _fsCorpo = 12; // linhas de detalhe e legendas
  static const double _fsRotulo = 13; // nomes, rótulos de seção
  static const double _fsAcao = 15; // texto dos botões de ação
  static const double _fsDestaque = 16; // total de cada dupla
  static const double _fsTitulo = 22; // "NÓS VENCEMOS!"
  static const double _fsPlacar = 26; // os pontos de cada dupla

  /// Piso do alvo tocável, em pontos lógicos. É o 48 do Material e do
  /// WCAG 2.5.5 — o mesmo número que `kMinInteractiveDimension` carrega.
  static const double _alvoMinimo = 48;

  /// Quanto o sistema está ampliando o texto. Serve para ADAPTAR o layout, e
  /// nunca para encolher fonte: acima de [_limiarDeEmpilhamento] as faixas
  /// horizontais viram coluna, porque a 200% não há largura de celular que as
  /// comporte lado a lado. A fonte segue crescendo em todos os casos.
  static const double _limiarDeEmpilhamento = 1.4;

  static double _escala(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_fsCorpo) / _fsCorpo;

  static bool _empilhar(BuildContext context) =>
      _escala(context) >= _limiarDeEmpilhamento;

  final bool fimPartida;
  final bool mesaVip;
  final int rodada;
  final String titulo;
  final int pontosNos;
  final int pontosEles;
  final DetalhePontuacaoVM detalheNos;
  final DetalhePontuacaoVM detalheEles;
  final List<JogadorResultadoVM> jogadores;
  final Map<int, EstadoAmizade> amizades;
  final bool conviteRevancheEnviado;
  final bool anuncioDisponivel;
  final bool anuncioAssistido;
  final bool assinanteSemAnuncios;
  final String recompensaAnuncio;
  final VoidCallback onContinuar;
  final VoidCallback onConvidarRevanche;
  final VoidCallback onJogarNovamente;
  final VoidCallback onVoltarLobby;
  final ValueChanged<int> onAdicionarAmigo;
  final VoidCallback onVerAnuncio;

  const ResultadoPartidaScreen({
    super.key,
    required this.fimPartida,
    required this.mesaVip,
    required this.rodada,
    required this.titulo,
    required this.pontosNos,
    required this.pontosEles,
    required this.detalheNos,
    required this.detalheEles,
    required this.jogadores,
    required this.amizades,
    required this.conviteRevancheEnviado,
    required this.anuncioDisponivel,
    required this.anuncioAssistido,
    required this.assinanteSemAnuncios,
    required this.recompensaAnuncio,
    required this.onContinuar,
    required this.onConvidarRevanche,
    required this.onJogarNovamente,
    required this.onVoltarLobby,
    required this.onAdicionarAmigo,
    required this.onVerAnuncio,
  });

  Color get _accent => mesaVip ? _purpleHi : const Color(0xFF7ED6A7);
  Color get _panel => mesaVip ? const Color(0xF4150D18) : const Color(0xF20D2118);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6000000),
      child: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight - 18;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: mesaVip
                          ? const Color(0xAA9D43D8)
                          : const Color(0x882E8B57),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cabecalho(),
                      const SizedBox(height: 12),
                      _placar(),
                      const SizedBox(height: 12),
                      _detalhamento(context),
                      if (fimPartida) ...[
                        const SizedBox(height: 14),
                        _conviteRevanche(context),
                        const SizedBox(height: 13),
                        _jogadores(context),
                        const SizedBox(height: 14),
                        _acoesFinais(),
                        if (!assinanteSemAnuncios) ...[
                          const SizedBox(height: 10),
                          _anuncioRecompensado(context),
                        ],
                      ] else ...[
                        const SizedBox(height: 14),
                        _botaoPrincipal(
                          label: 'PRÓXIMA RODADA',
                          icon: Icons.play_arrow_rounded,
                          onTap: onContinuar,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Column(
      children: [
        Icon(
          fimPartida ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
          color: _goldHi,
          size: 42,
        ),
        const SizedBox(height: 7),
        Text(
          fimPartida ? 'FIM DE PARTIDA' : 'FECHAMENTO DA RODADA $rodada',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _gold,
            fontSize: _fsCorpo,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _fsTitulo,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _placar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x669D43D8)),
      ),
      // A régua central acompanha a altura do placar: com fonte grande o
      // número ocupa duas linhas, e um traço de altura fixa viraria um toco.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _placarDupla('NÓS', pontosNos, _accent)),
            Container(width: 1, color: const Color(0x667D5A24)),
            Expanded(child: _placarDupla('ELES', pontosEles, _goldHi)),
          ],
        ),
      ),
    );
  }

  Widget _placarDupla(String label, int pontos, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFD9CDAF),
            fontSize: _fsCorpo,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$pontos',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: _fsPlacar,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detalhamento(BuildContext context) {
    final nos = _detalheDupla('NÓS', detalheNos, _accent);
    final eles = _detalheDupla('ELES', detalheEles, _goldHi);
    // Com o texto ampliado, duas colunas de detalhe num celular deixam cada
    // rótulo em três ou quatro linhas. Empilhar mantém o mesmo conteúdo, com
    // a mesma ordem de leitura, numa largura que ele cabe.
    if (_empilhar(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [nos, const SizedBox(height: 8), eles],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: nos),
        const SizedBox(width: 8),
        Expanded(child: eles),
      ],
    );
  }

  Widget _detalheDupla(String nome, DetalhePontuacaoVM vm, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Era um `Row` com o total sem flex: a 200% ele estourava a caixa
          // por 6,8 pt. `Wrap` mantém nome e total lado a lado enquanto
          // couberem e leva o total para a linha de baixo quando não couber —
          // sem cortar, sem sobrepor e sem diminuir o número.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  nome,
                  style: TextStyle(
                    color: color,
                    fontSize: _fsRotulo,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  vm.total >= 0 ? '+${vm.total}' : '${vm.total}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: _fsDestaque,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          _linha('Canastras', vm.canastras),
          _linha('Cartas baixadas', vm.cartasBaixadas),
          if (vm.bonusBatida != 0) _linha('Batida', vm.bonusBatida),
          if (vm.descontoMao != 0) _linha('Cartas na mão', vm.descontoMao),
          if (vm.penalidadeMorto != 0) _linha('Morto', vm.penalidadeMorto),
          if (vm.limpas + vm.sujas + vm.de500 + vm.de1000 > 0) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (vm.sujas > 0) _chip('SUJA ${vm.sujas}'),
                if (vm.limpas > 0) _chip('LIMPA ${vm.limpas}'),
                if (vm.de500 > 0) _chip('500 ${vm.de500}'),
                if (vm.de1000 > 0) _chip('1000 ${vm.de1000}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(String label, int valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 1,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD3C8D8),
                fontSize: _fsCorpo,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              valor > 0 ? '+$valor' : '$valor',
              style: TextStyle(
                color: valor < 0 ? const Color(0xFFFFA6A6) : Colors.white,
                fontSize: _fsCorpo,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x229D43D8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x669D43D8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF2E8FF),
          fontSize: _fsMinima,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _conviteRevanche(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: conviteRevancheEnviado
            ? const Color(0x331F9D63)
            : const Color(0x339D43D8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: conviteRevancheEnviado ? _green : _purple,
        ),
      ),
      child: _faixaComAcao(
        context,
        icone: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: conviteRevancheEnviado ? _green : _purple,
            shape: BoxShape.circle,
          ),
          child: Icon(
            conviteRevancheEnviado
                ? Icons.hourglass_top_rounded
                : Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        titulo: conviteRevancheEnviado ? 'Convite enviado' : 'Vamos jogar?',
        detalhe: conviteRevancheEnviado
            ? 'Aguardando os jogadores responderem.'
            : 'Convide a mesa inteira para uma revanche.',
        acao: _acaoDeTexto(
          rotulo: conviteRevancheEnviado ? 'ENVIADO' : 'CONVIDAR',
          cor: conviteRevancheEnviado ? const Color(0xFFB7D8C7) : _goldHi,
          onTap: conviteRevancheEnviado ? null : onConvidarRevanche,
        ),
      ),
    );
  }

  /// Faixa "ícone + texto + ação". Lado a lado enquanto o texto está no
  /// tamanho normal; com o texto ampliado a ação desce para a própria linha,
  /// em largura cheia, em vez de espremer o rótulo contra o botão.
  Widget _faixaComAcao(
    BuildContext context, {
    required Widget icone,
    required String titulo,
    required String detalhe,
    required Widget acao,
  }) {
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _fsRotulo,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detalhe,
          style: const TextStyle(
            color: Color(0xFFD8CBDD),
            fontSize: _fsCorpo,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (_empilhar(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icone,
              const SizedBox(width: 10),
              Expanded(child: texto),
            ],
          ),
          const SizedBox(height: 8),
          acao,
        ],
      );
    }

    return Row(
      children: [
        icone,
        const SizedBox(width: 10),
        Expanded(child: texto),
        acao,
      ],
    );
  }

  /// Ação secundária da faixa. O piso de 48 é explícito: sem ele o alvo
  /// dependeria do tema, e um tema com `MaterialTapTargetSize.shrinkWrap`
  /// devolveria o botão de 27 pt que esta tela tinha.
  Widget _acaoDeTexto({
    required String rotulo,
    required Color cor,
    required VoidCallback? onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, _alvoMinimo),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          color: cor,
          fontSize: _fsRotulo,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _jogadores(BuildContext context) {
    final outros = jogadores.where((j) => !j.souEu).toList();
    const espaco = 7.0;
    final escalador = MediaQuery.textScalerOf(context);
    // Largura mínima que um cartão precisa para caber nome e botão sem
    // espremer nenhum dos dois. Cresce com a fonte do sistema — é o que
    // decide quantas colunas cabem, em vez de um número fixo de três.
    final larguraMinima = escalador.scale(96);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'JOGADORES DA MESA',
          style: TextStyle(
            color: _gold,
            fontSize: _fsCorpo,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        // Era um `GridView` de três colunas com `childAspectRatio` fixo: a
        // altura do cartão não dependia do conteúdo, então texto ampliado
        // estourava a célula. Aqui a altura é a do conteúdo, e o número de
        // colunas é o que a largura comporta.
        LayoutBuilder(
          builder: (context, constraints) {
            final disponivel = constraints.maxWidth;
            final colunas = math.max(
              1,
              math.min(
                outros.length,
                ((disponivel + espaco) / (larguraMinima + espaco)).floor(),
              ),
            );
            final largura =
                (disponivel - espaco * (colunas - 1)) / colunas;
            return Wrap(
              spacing: espaco,
              runSpacing: espaco,
              children: [
                for (final jogador in outros)
                  SizedBox(
                    width: largura,
                    child: _jogadorCard(context, jogador),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _jogadorCard(BuildContext context, JogadorResultadoVM jogador) {
    final estado = amizades[jogador.assento] ?? EstadoAmizade.disponivel;
    final bloqueado = estado == EstadoAmizade.bloqueado;
    final podeAdicionar = estado == EstadoAmizade.disponivel;
    late final String label;
    late final IconData icon;
    // O rótulo visível é curto porque o cartão é estreito; o nome semântico
    // diz de quem se trata, que é o que um leitor de tela precisa ouvir para
    // distinguir três botões idênticos lado a lado.
    late final String nomeSemantico;
    switch (estado) {
      case EstadoAmizade.disponivel:
        label = '+ AMIGO';
        icon = Icons.person_add_alt_1_rounded;
        nomeSemantico = 'Adicionar ${jogador.nome} como amigo';
        break;
      case EstadoAmizade.enviado:
        label = 'ENVIADO';
        icon = Icons.schedule_send_rounded;
        nomeSemantico = 'Convite enviado para ${jogador.nome}';
        break;
      case EstadoAmizade.amigos:
        label = 'AMIGOS';
        icon = Icons.people_alt_rounded;
        nomeSemantico = 'Você já é amigo de ${jogador.nome}';
        break;
      case EstadoAmizade.bloqueado:
        label = 'BLOQUEADO';
        icon = Icons.block_rounded;
        nomeSemantico = '${jogador.nome} está bloqueado';
        break;
    }

    // O círculo do avatar acompanha a fonte do sistema: com ele fixo em 44 a
    // 200% o glifo passava a medir 42 e vazava para fora da borda.
    final ladoDoAvatar =
        MediaQuery.textScalerOf(context).scale(21).clamp(21.0, 46.0) * 2.1;

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: bloqueado
              ? const Color(0x55666666)
              : const Color(0x557D5A24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ladoDoAvatar,
            height: ladoDoAvatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF231629),
              border: Border.all(color: _gold, width: 1.2),
            ),
            child: Text(
              jogador.avatar,
              maxLines: 1,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            jogador.nome,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: _fsCorpo,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  podeAdicionar ? () => onAdicionarAmigo(jogador.assento) : null,
              icon: Icon(icon, size: 16),
              // O nome acessível fica DENTRO do botão, no lugar do rótulo
              // visível: é o nó do botão que o leitor de tela anuncia, e um
              // `Semantics` por fora viraria um nó irmão sem ação, deixando o
              // botão ainda anunciado como "+ AMIGO". O `ExcludeSemantics`
              // cobre só o texto decorativo — a ação de toque mora no botão,
              // que está acima dele, e não é afetada.
              label: Semantics(
                label: nomeSemantico,
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: _fsMinima,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: estado == EstadoAmizade.amigos
                    ? const Color(0xFF8FE1B6)
                    : _goldHi,
                side: BorderSide(
                  color: estado == EstadoAmizade.amigos
                      ? const Color(0xFF2E8B57)
                      : const Color(0xAAE5B84F),
                ),
                // Havia aqui uma caixa de altura fixa em vinte e sete pontos,
                // que é o alvo que o relatório mediu. O piso agora é o mesmo
                // dos demais controles da tela.
                minimumSize: const Size(0, _alvoMinimo),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoesFinais() {
    return Column(
      children: [
        _botaoPrincipal(
          label: conviteRevancheEnviado
              ? 'JOGAR NOVAMENTE'
              : 'VAMOS JOGAR?',
          icon: conviteRevancheEnviado
              ? Icons.replay_rounded
              : Icons.chat_bubble_rounded,
          onTap: conviteRevancheEnviado
              ? onJogarNovamente
              : onConvidarRevanche,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onVoltarLobby,
            icon: const Icon(Icons.meeting_room_outlined, size: 20),
            label: const Text(
              'VOLTAR AO LOBBY',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _fsAcao, fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE6D9C0),
              side: const BorderSide(color: Color(0x667D5A24)),
              minimumSize: const Size(0, _alvoMinimo),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _anuncioRecompensado(BuildContext context) {
    final habilitado = anuncioDisponivel && !anuncioAssistido;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x556B5A40)),
      ),
      child: _faixaComAcao(
        context,
        icone: Icon(
          anuncioAssistido
              ? Icons.check_circle_rounded
              : Icons.ondemand_video_rounded,
          color: anuncioAssistido ? const Color(0xFF7ED6A7) : _gold,
          size: 23,
        ),
        titulo: anuncioAssistido ? 'Recompensa recebida' : 'Ver anúncio',
        detalhe: anuncioAssistido
            ? recompensaAnuncio
            : 'Opcional · $recompensaAnuncio',
        acao: _acaoDeTexto(
          rotulo: anuncioAssistido
              ? 'RECEBIDO'
              : (anuncioDisponivel ? 'ASSISTIR' : 'INDISPONÍVEL'),
          cor: habilitado ? _goldHi : const Color(0xFF8A818D),
          onTap: habilitado ? onVerAnuncio : null,
        ),
      ),
    );
  }

  Widget _botaoPrincipal({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: _fsAcao, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF3C2405),
          minimumSize: const Size(0, _alvoMinimo),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: Color(0xFFFFF0B8)),
          ),
        ),
      ),
    );
  }
}
