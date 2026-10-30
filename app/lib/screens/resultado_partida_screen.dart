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
                      _detalhamento(),
                      if (fimPartida) ...[
                        const SizedBox(height: 14),
                        _conviteRevanche(),
                        const SizedBox(height: 13),
                        _jogadores(),
                        const SizedBox(height: 14),
                        _acoesFinais(),
                        if (!assinanteSemAnuncios) ...[
                          const SizedBox(height: 10),
                          _anuncioRecompensado(),
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
            fontSize: 9,
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
            fontSize: 20,
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
      child: Row(
        children: [
          Expanded(child: _placarDupla('NÓS', pontosNos, _accent)),
          Container(width: 1, height: 38, color: const Color(0x667D5A24)),
          Expanded(child: _placarDupla('ELES', pontosEles, _goldHi)),
        ],
      ),
    );
  }

  Widget _placarDupla(String label, int pontos, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD9CDAF),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$pontos',
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detalhamento() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _detalheDupla('NÓS', detalheNos, _accent)),
        const SizedBox(width: 8),
        Expanded(child: _detalheDupla('ELES', detalheEles, _goldHi)),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                vm.total >= 0 ? '+${vm.total}' : '${vm.total}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD3C8D8),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            valor > 0 ? '+$valor' : '$valor',
            style: TextStyle(
              color: valor < 0 ? const Color(0xFFFFA6A6) : Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _conviteRevanche() {
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
      child: Row(
        children: [
          Container(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conviteRevancheEnviado
                      ? 'Convite enviado'
                      : 'Vamos jogar?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conviteRevancheEnviado
                      ? 'Aguardando os jogadores responderem.'
                      : 'Convide a mesa inteira para uma revanche.',
                  style: const TextStyle(
                    color: Color(0xFFD8CBDD),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: conviteRevancheEnviado ? null : onConvidarRevanche,
            child: Text(
              conviteRevancheEnviado ? 'ENVIADO' : 'CONVIDAR',
              style: TextStyle(
                color: conviteRevancheEnviado
                    ? const Color(0xFFB7D8C7)
                    : _goldHi,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jogadores() {
    final outros = jogadores.where((j) => !j.souEu).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'JOGADORES DA MESA',
          style: TextStyle(
            color: _gold,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: outros.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (_, index) => _jogadorCard(outros[index]),
        ),
      ],
    );
  }

  Widget _jogadorCard(JogadorResultadoVM jogador) {
    final estado = amizades[jogador.assento] ?? EstadoAmizade.disponivel;
    final bloqueado = estado == EstadoAmizade.bloqueado;
    final podeAdicionar = estado == EstadoAmizade.disponivel;
    late final String label;
    late final IconData icon;
    switch (estado) {
      case EstadoAmizade.disponivel:
        label = '+ AMIGO';
        icon = Icons.person_add_alt_1_rounded;
        break;
      case EstadoAmizade.enviado:
        label = 'ENVIADO';
        icon = Icons.schedule_send_rounded;
        break;
      case EstadoAmizade.amigos:
        label = 'AMIGOS';
        icon = Icons.people_alt_rounded;
        break;
      case EstadoAmizade.bloqueado:
        label = 'BLOQUEADO';
        icon = Icons.block_rounded;
        break;
    }

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
        children: [
          Container(
            width: 44,
            height: 44,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 27,
            child: OutlinedButton.icon(
              onPressed: podeAdicionar
                  ? () => onAdicionarAmigo(jogador.assento)
                  : null,
              icon: Icon(icon, size: 11),
              label: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 6.6,
                  fontWeight: FontWeight.w900,
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
            icon: const Icon(Icons.meeting_room_outlined, size: 17),
            label: const Text(
              'VOLTAR AO LOBBY',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE6D9C0),
              side: const BorderSide(color: Color(0x667D5A24)),
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

  Widget _anuncioRecompensado() {
    final habilitado = anuncioDisponivel && !anuncioAssistido;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x556B5A40)),
      ),
      child: Row(
        children: [
          Icon(
            anuncioAssistido
                ? Icons.check_circle_rounded
                : Icons.ondemand_video_rounded,
            color: anuncioAssistido ? const Color(0xFF7ED6A7) : _gold,
            size: 23,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anuncioAssistido
                      ? 'Recompensa recebida'
                      : 'Ver anúncio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  anuncioAssistido
                      ? recompensaAnuncio
                      : 'Opcional · $recompensaAnuncio',
                  style: const TextStyle(
                    color: Color(0xFFCABFD0),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: habilitado ? onVerAnuncio : null,
            child: Text(
              anuncioAssistido
                  ? 'RECEBIDO'
                  : (anuncioDisponivel ? 'ASSISTIR' : 'INDISPONÍVEL'),
              style: TextStyle(
                color: habilitado ? _goldHi : const Color(0xFF8A818D),
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF3C2405),
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
