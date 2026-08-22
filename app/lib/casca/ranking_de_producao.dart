// ranking_de_producao.dart — o ranking REAL, e a porta produtiva para o Perfil
// público.
//
// ---------------------------------------------------------------------------
// POR QUE UMA TELA NOVA, E NÃO `screens/ranking_screen.dart`
// ---------------------------------------------------------------------------
//
// A tela do Codex existe, é bonita e continua no repositório como catálogo
// visual. O que ela não pode fazer é entrar num caminho que nasce em `main()`:
// ela carrega dados históricos e de demonstração — jogadores, ligas e Hall
// escritos no próprio arquivo —, e ligá-la aqui publicaria maquete como se
// fosse classificação. É a mesma decisão que a Home já tomou ao deixar o item
// "Ranking" apagado em vez de abrir a prévia.
//
// Esta tela é o contrário: ela não tem um único jogador escrito dentro. Tudo o
// que desenha veio de `abrirRanking`, e quando não veio nada ela diz isso.
//
// ---------------------------------------------------------------------------
// CINCO ESTADOS, E NENHUM DELES É "LISTA VAZIA"
// ---------------------------------------------------------------------------
//
// carregando ......... a consulta está em voo
// vazio .............. a autoridade respondeu, e não há ninguém classificado
// acesso recusado .... credencial OU atestação, sem se saber qual — com botão
// falha recuperável .. soluço, timeout, cold start — com botão
// sucesso ............ pódio e primeira página, como vieram
//
// Mais dois que a tela também trata e a OS não listou porque não são estados
// de erro: `indisponivel` (não há autoridade alcançável, ou a temporada acabou)
// e `sessaoInvalida` (não há sessão local, e insistir só repete a recusa —
// então não há botão).
//
// A distinção entre os cinco não é enfeite. Quatro deles desenham uma lista
// vazia; se a tela olhasse `itens.isEmpty` em vez da fase, todos os quatro
// virariam "ainda não há ninguém no ranking", e dois deles esconderiam do
// jogador o botão que resolveria o problema dele.
//
// ---------------------------------------------------------------------------
// O QUE ESTA TELA NÃO FAZ
// ---------------------------------------------------------------------------
//
// Não pergunta nada. Ela LÊ `EscopoRanking`, que é o mesmo estado que a Home e
// o cabeçalho do Perfil leem — uma abertura, uma resposta, três superfícies que
// não podem divergir. Abrir e fechar esta tela dez vezes não emite chamada
// nenhuma; quem emite é a sessão, ao mudar, e o gesto de "tentar de novo".
//
// Não decide de quem é o perfil que abre. Isso é de
// `navegacao_perfil_publico.dart`, e a razão de ser um arquivo separado está lá.
//
// Não ordena, não filtra e não completa a lista. A ordem é de `ordenacao.ts`.

import 'package:flutter/material.dart';

import '../ranking/escopo_ranking.dart';
import '../ranking/estado_ranking.dart';
import '../ranking/estado_tabela_ranking.dart';
import '../ranking/ranking_transporte.dart' show JogadorPublicoRanking;
import 'navegacao_perfil_publico.dart';

/// Altura mínima de uma linha tocável.
///
/// 56 e não 48: 48 é o piso das diretrizes, e uma linha de ranking carrega três
/// blocos de texto de tamanhos diferentes. Com 48 exatos, a primeira fonte
/// grande do sistema já empurra o conteúdo para fora.
const double kAlturaMinimaDaLinha = 56;

class RankingDeProducao extends StatelessWidget {
  const RankingDeProducao({super.key});

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);

  @override
  Widget build(BuildContext context) {
    final tabela = EscopoRanking.tabelaDe(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Colors.black],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topo(context),
              Expanded(child: _conteudo(context, tabela)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topo(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Voltar',
          child: InkResponse(
            onTap: () => Navigator.of(context).maybePop(),
            radius: 24,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(Icons.chevron_left_rounded, color: _ouro, size: 29),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        const Text(
          'Ranking',
          style: TextStyle(
            color: _ouroClaro,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      ],
    ),
  );

  Widget _conteudo(BuildContext context, EstadoTabelaRanking tabela) {
    switch (tabela.fase) {
      case FaseRanking.carregando:
        return const _Aviso(
          mensagem: 'Carregando o ranking…',
          mostrarProgresso: true,
        );

      // Não há autoridade alcançável, ou ela respondeu que não há temporada em
      // andamento. Sem botão: insistir não abre uma temporada.
      case FaseRanking.indisponivel:
        return const _Aviso(
          mensagem: 'O ranking ainda não está sendo publicado.',
        );

      // NEUTRO. `unauthenticated` chega tanto de credencial recusada quanto de
      // App Check ausente, e daqui não dá para saber qual — então a frase não
      // acusa a sessão de nada e oferece a única ação que pode funcionar.
      case FaseRanking.acessoRecusado:
        return _Aviso(
          mensagem: 'Não foi possível acessar o ranking agora.',
          onTentarDeNovo: () => EscopoRanking.talvezDe(context)?.recarregar(),
        );

      case FaseRanking.falha:
        return _Aviso(
          mensagem: 'Não consegui carregar o ranking agora.',
          onTentarDeNovo: () => EscopoRanking.talvezDe(context)?.recarregar(),
        );

      // Há prova de que não existe sessão local. Aqui insistir só repetiria a
      // recusa, e um botão que não cumpre o que promete é pior que nenhum.
      case FaseRanking.sessaoInvalida:
        return const _Aviso(
          mensagem: 'Ranking indisponível: entre na sua conta de novo.',
        );

      case FaseRanking.disponivel:
        if (tabela.vaziaComResposta) {
          // ESTA FRASE SÓ PODE SER DITA AQUI. É uma afirmação sobre a
          // temporada — "conferi, e não há ninguém" —, e nas outras quatro
          // fases ela seria um palpite.
          return const _Aviso(
            mensagem: 'Ninguém classificado nesta temporada ainda.',
          );
        }
        return _lista(tabela);
    }
  }

  Widget _lista(EstadoTabelaRanking tabela) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
    children: [
      if (tabela.podio.isNotEmpty) ...[
        const _TituloSecao('PÓDIO'),
        for (final jogador in tabela.podio)
          _LinhaJogador(jogador: jogador, destaque: true),
      ],
      if (tabela.primeiraPagina.isNotEmpty) ...[
        const _TituloSecao('CLASSIFICAÇÃO'),
        for (final jogador in tabela.primeiraPagina)
          _LinhaJogador(jogador: jogador),
      ],
    ],
  );
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
    child: Text(
      texto,
      style: const TextStyle(
        color: RankingDeProducao._textoSec,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Uma linha da tabela — e o gesto que leva ao Perfil daquele jogador.
class _LinhaJogador extends StatelessWidget {
  const _LinhaJogador({required this.jogador, this.destaque = false});

  final JogadorPublicoRanking jogador;

  /// Linha de pódio: só muda a moldura. NÃO muda o que a linha afirma.
  final bool destaque;

  /// Como chamar o jogador.
  ///
  /// FALLBACK DE APRESENTAÇÃO, e não de identidade — a mesma regra que a Home
  /// aplica ao cabeçalho. O `publicPlayerId` entra quando não há apelido
  /// escolhido porque ele É o identificador público da pessoa; o que nunca
  /// entra é um nome inventado, um número de linha ou um rótulo genérico que
  /// afirme algo sobre quem ela é.
  String get _nome =>
      jogador.apelido.trim().isEmpty ? jogador.publicPlayerId : jogador.apelido;

  /// A colocação, quando é uma colocação de verdade.
  ///
  /// `posicao: 0` é `POSICAO_NAO_APURADA` no servidor, e vira travessão — nunca
  /// `#0`, que a família de defeitos desta linhagem já colocou na tela uma vez.
  String get _colocacao => jogador.posicao < 1 ? '—' : '#${jogador.posicao}';

  /// A liga, quando há rótulo. Vazio some: um espaço em branco entre parênteses
  /// não é informação.
  String get _liga => jogador.rotuloLiga.trim();

  String get _anuncio {
    final partes = <String>[
      if (jogador.posicao >= 1)
        'Posição ${jogador.posicao}'
      else
        'Sem colocação apurada',
      _nome,
      if (_liga.isNotEmpty) _liga,
      if (jogador.souEu) 'Você',
    ];
    return '${partes.join('. ')}. Toque para ver o perfil.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: _anuncio,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: RankingDeProducao._card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                abrirPerfilDoJogador(context, AlvoDePerfil.doRanking(jogador)),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: kAlturaMinimaDaLinha,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: destaque
                      ? RankingDeProducao._ouro.withValues(alpha: .55)
                      : RankingDeProducao._borda,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _colocacao,
                      style: TextStyle(
                        color: destaque
                            ? RankingDeProducao._ouroClaro
                            : RankingDeProducao._textoSec,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RankingDeProducao._texto,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_liga.isNotEmpty)
                          Text(
                            _liga,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9FDCFF),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // "Você" SÓ SAI DE `souEu`, que é decidido no servidor sobre o
                  // uid. Não há aqui nenhuma comparação com a sessão local.
                  if (jogador.souEu)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: RankingDeProducao._ouro.withValues(alpha: .5),
                        ),
                      ),
                      child: const Text(
                        'você',
                        style: TextStyle(
                          color: RankingDeProducao._ouroClaro,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

/// Um recado no meio da tela, com botão só quando insistir resolve.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.mensagem,
    this.onTentarDeNovo,
    this.mostrarProgresso = false,
  });

  final String mensagem;
  final VoidCallback? onTentarDeNovo;
  final bool mostrarProgresso;

  @override
  Widget build(BuildContext context) {
    final acao = onTentarDeNovo;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarProgresso) ...[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: RankingDeProducao._ouro,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RankingDeProducao._textoSec,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              // Área de toque com o piso das diretrizes, e não só o texto.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
                child: OutlinedButton(
                  onPressed: acao,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RankingDeProducao._ouroClaro,
                    side: const BorderSide(color: RankingDeProducao._borda),
                  ),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
