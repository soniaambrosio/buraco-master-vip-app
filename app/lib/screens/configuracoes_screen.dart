import 'package:flutter/material.dart';

enum MaoDominante { destro, canhoto }

enum Idioma { ptBR }

enum QuemMeConvida { todos, somenteAmigos, ninguem }

@immutable
class PerfilResumo {
  final String apelido;
  final String email;
  final bool vip;
  final String? vipPlano;
  final String? vipValidoAte;

  /// Saldo, ou `null` quando não há autoridade de economia que o informe.
  ///
  /// Era obrigatório, e quem montava a tela sem fonte passava `0` — que a
  /// pessoa lê como "estou sem moedas", e não como "o aplicativo ainda não sabe
  /// quantas". Nulo tira o número da tela em vez de afirmar um.
  final int? moedas;

  const PerfilResumo({
    required this.apelido,
    required this.email,
    required this.vip,
    this.vipPlano,
    this.vipValidoAte,
    required this.moedas,
  });
}

@immutable
class Configuracoes {
  final bool musica;
  final bool efeitosSonoros;
  final bool vibracao;
  final bool notificacoes;
  final bool animacoes;
  final bool ordenarCartasAuto;
  final bool confirmarDescarte;
  final MaoDominante maoDominante;
  final QuemMeConvida quemMeConvida;
  final bool chatPublicoSoMaiores;
  final bool mostrarOnline;
  final Idioma idioma;
  final String versaoApp;

  const Configuracoes({
    this.musica = true,
    this.efeitosSonoros = true,
    this.vibracao = false,
    this.notificacoes = true,
    this.animacoes = true,
    this.ordenarCartasAuto = true,
    this.confirmarDescarte = false,
    this.maoDominante = MaoDominante.destro,
    this.quemMeConvida = QuemMeConvida.todos,
    this.chatPublicoSoMaiores = true,
    this.mostrarOnline = true,
    this.idioma = Idioma.ptBR,
    this.versaoApp = '',
  });

  Configuracoes copyWith({
    bool? musica,
    bool? efeitosSonoros,
    bool? vibracao,
    bool? notificacoes,
    bool? animacoes,
    bool? ordenarCartasAuto,
    bool? confirmarDescarte,
    MaoDominante? maoDominante,
    QuemMeConvida? quemMeConvida,
    bool? chatPublicoSoMaiores,
    bool? mostrarOnline,
    Idioma? idioma,
    String? versaoApp,
  }) {
    return Configuracoes(
      musica: musica ?? this.musica,
      efeitosSonoros: efeitosSonoros ?? this.efeitosSonoros,
      vibracao: vibracao ?? this.vibracao,
      notificacoes: notificacoes ?? this.notificacoes,
      animacoes: animacoes ?? this.animacoes,
      ordenarCartasAuto: ordenarCartasAuto ?? this.ordenarCartasAuto,
      confirmarDescarte: confirmarDescarte ?? this.confirmarDescarte,
      maoDominante: maoDominante ?? this.maoDominante,
      quemMeConvida: quemMeConvida ?? this.quemMeConvida,
      chatPublicoSoMaiores:
          chatPublicoSoMaiores ?? this.chatPublicoSoMaiores,
      mostrarOnline: mostrarOnline ?? this.mostrarOnline,
      idioma: idioma ?? this.idioma,
      versaoApp: versaoApp ?? this.versaoApp,
    );
  }
}

@immutable
class ConfiguracoesCallbacks {
  final void Function(Configuracoes atualizado) onAlterar;
  final VoidCallback onEditarPerfil;
  final VoidCallback onAssinaturaVip;
  final VoidCallback onMoedasCompras;
  final VoidCallback onBloqueados;
  final VoidCallback onRegras;
  final VoidCallback onSuporte;
  final VoidCallback onTermos;
  final VoidCallback onAvaliar;
  final VoidCallback onSair;

  const ConfiguracoesCallbacks({
    required this.onAlterar,
    required this.onEditarPerfil,
    required this.onAssinaturaVip,
    required this.onMoedasCompras,
    required this.onBloqueados,
    required this.onRegras,
    required this.onSuporte,
    required this.onTermos,
    required this.onAvaliar,
    required this.onSair,
  });
}

class ConfiguracoesScreen extends StatelessWidget {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _roxo = Color(0xFFB36CFF);
  static const _fundo = Color(0xFF080503);
  static const _card = Color(0xFF1C130C);
  static const _cardSecundario = Color(0xFF130D08);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x44EFB94A);

  final PerfilResumo perfil;
  final Configuracoes config;
  final ConfiguracoesCallbacks callbacks;
  final VoidCallback onVoltar;

  const ConfiguracoesScreen({
    super.key,
    required this.perfil,
    required this.config,
    required this.callbacks,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Colors.black],
            stops: [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _topo(context),
                  Expanded(
                    child: Scrollbar(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 22),
                        children: [
                          _perfilCard(),
                          _secao(
                            titulo: 'CONTA',
                            icone: Icons.person_outline_rounded,
                            children: [
                              _navTile(
                                icone: Icons.edit_rounded,
                                titulo: 'Editar perfil',
                                subtitulo: 'Apelido, foto e informações públicas',
                                onTap: callbacks.onEditarPerfil,
                              ),
                              _navTile(
                                icone: Icons.workspace_premium_rounded,
                                titulo: 'Assinatura VIP',
                                subtitulo: perfil.vip
                                    ? '${perfil.vipPlano ?? 'Plano VIP'}${perfil.vipValidoAte == null ? '' : ' · até ${perfil.vipValidoAte}'}'
                                    : 'Conheça os benefícios da assinatura',
                                destaque: perfil.vip,
                                onTap: callbacks.onAssinaturaVip,
                              ),
                              _navTile(
                                icone: Icons.monetization_on_outlined,
                                titulo: 'Moedas e compras',
                                subtitulo: perfil.moedas == null
                                    ? 'Pacotes de moedas e histórico'
                                    : '${perfil.moedas} moedas disponíveis',
                                onTap: callbacks.onMoedasCompras,
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'SOM E NOTIFICAÇÕES',
                            icone: Icons.volume_up_outlined,
                            children: [
                              _toggleTile(
                                icone: Icons.music_note_rounded,
                                titulo: 'Música',
                                subtitulo: 'Trilha musical do aplicativo',
                                valor: config.musica,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(musica: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.graphic_eq_rounded,
                                titulo: 'Efeitos sonoros',
                                subtitulo: 'Cartas, canastras e avisos da mesa',
                                valor: config.efeitosSonoros,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(efeitosSonoros: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.vibration_rounded,
                                titulo: 'Vibração',
                                subtitulo: 'Avisar quando chegar a sua vez',
                                valor: config.vibracao,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(vibracao: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.notifications_active_outlined,
                                titulo: 'Notificações',
                                subtitulo: 'Convites, recompensas e novidades',
                                valor: config.notificacoes,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(notificacoes: v),
                                ),
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'JOGO',
                            icone: Icons.style_outlined,
                            children: [
                              _toggleTile(
                                icone: Icons.auto_awesome_motion_rounded,
                                titulo: 'Animações',
                                subtitulo: 'Movimentos e celebrações visuais',
                                valor: config.animacoes,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(animacoes: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.sort_rounded,
                                titulo: 'Ordenar cartas automaticamente',
                                subtitulo: 'Organiza a mão por naipe e valor',
                                valor: config.ordenarCartasAuto,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(ordenarCartasAuto: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.fact_check_outlined,
                                titulo: 'Confirmar antes de descartar',
                                subtitulo: 'Evita descarte por toque acidental',
                                valor: config.confirmarDescarte,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(confirmarDescarte: v),
                                ),
                              ),
                              _choiceTile<MaoDominante>(
                                context: context,
                                icone: Icons.pan_tool_alt_outlined,
                                titulo: 'Mão dominante',
                                valor: config.maoDominante,
                                label: _maoLabel,
                                opcoes: MaoDominante.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(maoDominante: v),
                                ),
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'PRIVACIDADE',
                            icone: Icons.shield_outlined,
                            children: [
                              _choiceTile<QuemMeConvida>(
                                context: context,
                                icone: Icons.person_add_alt_1_rounded,
                                titulo: 'Quem pode me convidar',
                                valor: config.quemMeConvida,
                                label: _conviteLabel,
                                opcoes: QuemMeConvida.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(quemMeConvida: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.forum_outlined,
                                titulo: 'Chat público só para maiores',
                                subtitulo: 'Restringe o acesso conforme a conta',
                                valor: config.chatPublicoSoMaiores,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(chatPublicoSoMaiores: v),
                                ),
                              ),
                              _toggleTile(
                                icone: Icons.visibility_outlined,
                                titulo: 'Mostrar quando estou online',
                                subtitulo: 'Amigos poderão ver sua presença',
                                valor: config.mostrarOnline,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(mostrarOnline: v),
                                ),
                              ),
                              _navTile(
                                icone: Icons.block_rounded,
                                titulo: 'Jogadores bloqueados',
                                subtitulo: 'Rever ou desbloquear jogadores',
                                onTap: callbacks.onBloqueados,
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'GERAL',
                            icone: Icons.tune_rounded,
                            children: [
                              _choiceTile<Idioma>(
                                context: context,
                                icone: Icons.language_rounded,
                                titulo: 'Idioma',
                                valor: config.idioma,
                                label: _idiomaLabel,
                                opcoes: Idioma.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(idioma: v),
                                ),
                              ),
                              _navTile(
                                icone: Icons.menu_book_outlined,
                                titulo: 'Regras e como jogar',
                                subtitulo: 'Aberto, Fechado e STBL',
                                onTap: callbacks.onRegras,
                              ),
                              _navTile(
                                icone: Icons.support_agent_rounded,
                                titulo: 'Suporte',
                                subtitulo: 'Fale com a equipe do aplicativo',
                                onTap: callbacks.onSuporte,
                              ),
                              _navTile(
                                icone: Icons.policy_outlined,
                                titulo: 'Termos e privacidade',
                                subtitulo: 'Documentos e políticas do serviço',
                                onTap: callbacks.onTermos,
                              ),
                              _navTile(
                                icone: Icons.star_rate_rounded,
                                titulo: 'Avaliar o aplicativo',
                                subtitulo: 'Conte sua experiência na loja',
                                onTap: callbacks.onAvaliar,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _sairButton(),
                          const SizedBox(height: 16),
                          Text(
                            config.versaoApp.isEmpty
                                ? 'Buraco Master VIP'
                                : 'Versão ${config.versaoApp}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textoSec,
                              fontSize: 11,
                              letterSpacing: .35,
                            ),
                          ),
                        ],
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

  Widget _topo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: onVoltar,
            icon: const Icon(Icons.chevron_left_rounded, color: _ouro, size: 31),
          ),
          const Text(
            'Configurações',
            style: TextStyle(
              color: _ouroClaro,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const Spacer(),
          const Icon(Icons.settings_rounded, color: _ouro, size: 23),
        ],
      ),
    );
  }

  Widget _perfilCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borda),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2B1B0C),
              border: Border.all(color: _ouro, width: 1.4),
            ),
            child: Text(
              perfil.apelido.trim().isEmpty
                  ? '👑'
                  : perfil.apelido.trim().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: _ouroClaro,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        perfil.apelido,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (perfil.vip) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _roxo.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _roxo.withValues(alpha: .70),
                          ),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            color: Color(0xFFE2C9FF),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  perfil.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textoSec, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // A pastilha de saldo só aparece quando há saldo a mostrar. Ver
          // [PerfilResumo.moedas].
          if (perfil.moedas case final int saldo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: _cardSecundario,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borda),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: _ouro,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$saldo',
                    style: const TextStyle(
                      color: _ouroClaro,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _secao({
    required String titulo,
    required IconData icone,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
            child: Row(
              children: [
                Icon(icone, color: _ouro, size: 17),
                const SizedBox(width: 7),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: _ouroClaro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _borda),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x22EFB94A),
                      indent: 54,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Uma linha que leva a outro lugar, com a fronteira semântica declarada.
  ///
  /// O rótulo desta linha nunca esteve vazio — o [InkWell] recolhe os dois
  /// textos sozinho. O que ela não tinha era um NÓ PRÓPRIO garantido, e isso
  /// só não aparecia porque as linhas vizinhas também não tinham: quando
  /// várias anotações de toque disputam o mesmo nó de cima, o Flutter é
  /// obrigado a separar todas. Bastou as preferências ao redor ganharem nós
  /// declarados para a última linha implícita da seção parar de disputar e
  /// escorregar para dentro do cabeçalho — "PRIVACIDADE Jogadores bloqueados
  /// Rever ou desbloquear jogadores", um botão só, com o nome da seção colado.
  ///
  /// Declarar o nó tira a árvore da mão dessa heurística: cada linha desta
  /// tela é um controle porque ela diz que é, e não porque as vizinhas
  /// estavam brigando. [onTap] é o mesmo de sempre — a linha continua com um
  /// caminho só para ser acionada.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE [MergeSemantics], E NÃO `excludeSemantics`
  /// ---------------------------------------------------------------------
  ///
  /// Os dois produzem UM nó, e é aí que param de ser equivalentes.
  /// `excludeSemantics` **descarta** a subárvore: junto com os dois textos ia
  /// embora o [Focus] que o [InkWell] carrega dentro dele, e com ele a ação
  /// `SemanticsAction.focus` e as marcas de focável/focado. A linha continuava
  /// legível para o leitor de tela e sumia do canal de foco de entrada —
  /// teclado, D-pad, varredura por acionador —, que passava a existir no widget
  /// sem ser anunciado a ninguém.
  ///
  /// [MergeSemantics] **funde** em vez de descartar: o `tap` e o foco reais do
  /// [InkWell] sobem para o mesmo nó que carrega o nome. O único fragmento que
  /// ainda precisa sair é o texto, e por um motivo estreito — ele já está
  /// dentro de [label], e deixá-lo entrar duplicaria o título na fala. Daí o
  /// [ExcludeSemantics] apertado em volta do conteúdo pintado, e não em volta
  /// do controle.
  Widget _navTile({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    bool destaque = false,
  }) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: true,
        label: '$titulo. $subtitulo',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Row(
                  children: [
                    _iconeTile(icone, destaque: destaque),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: TextStyle(
                              color: destaque
                                  ? const Color(0xFFE2C9FF)
                                  : _texto,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textoSec,
                              fontSize: 10.4,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _textoSec,
                      size: 23,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Uma preferência de liga/desliga — para os olhos e para o leitor de tela.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE A LINHA INTEIRA VIRA UM NÓ SÓ
  /// ---------------------------------------------------------------------
  ///
  /// Aos olhos esta linha é óbvia: o nome da preferência à esquerda, o
  /// [Switch] à direita, e tocar em qualquer um dos dois alterna. Na árvore de
  /// acessibilidade ela chegava partida em DOIS controles concorrentes, e
  /// nenhum dos dois completo:
  ///
  ///   - o texto, dentro do [GestureDetector], virava um nó tocável chamado
  ///     "Música / Trilha musical do aplicativo" que não dizia se a música
  ///     estava ligada;
  ///   - o [Switch], irmão dele, virava um segundo nó — este sabendo o estado,
  ///     mas com rótulo VAZIO: "ativado", sobre o quê ninguém dizia.
  ///
  /// Quem navega por leitor de tela encontrava dezoito paradas para nove
  /// preferências, metade delas anônimas. Nas de PRIVACIDADE isso não é
  /// desconforto: a pessoa alterna se sua presença aparece, ou quem pode
  /// falar com ela, sem ouvir o que está alternando.
  ///
  /// Por isso a linha inteira passa a ser UM nó com as três coisas que todo
  /// controle precisa ter — nome, estado e ação. É a mesma régua de
  /// `perfil_screen.dart`.
  ///
  /// ---------------------------------------------------------------------
  /// QUEM DIZ CADA COISA — E POR QUE NÃO É ESTE MÉTODO
  /// ---------------------------------------------------------------------
  ///
  /// [MergeSemantics] funde a linha num nó só sem apagar ninguém, e essa
  /// diferença decide quem é a autoridade de cada campo:
  ///
  ///   - o **nome** é a única coisa que este método declara, porque é a única
  ///     que não existe em lugar nenhum: o [Switch] não sabe do que ele é o
  ///     interruptor;
  ///   - **estado, ação, `enabled` e foco** sobem do próprio [Switch]. Ele já
  ///     publica `toggled` a partir do mesmo [valor] que o desenha, `enabled`
  ///     a partir do seu [onChanged], `tap` que chama esse [onChanged], e o
  ///     [Focus] que o torna alcançável por teclado e por acionador.
  ///
  /// Declarar `toggled` aqui de novo criaria uma segunda fonte para um estado
  /// que já tem dono, e um `enabled` fixo mentiria no dia em que o interruptor
  /// pudesse ser desabilitado. O canal de acessibilidade descreve o controle
  /// real; ele não monta um controle paralelo ao lado.
  ///
  /// O [ExcludeSemantics] é apertado de propósito: cerca só o texto pintado —
  /// que já está dentro de [label] e duplicaria o título na fala — e deixa o
  /// [Switch] inteiro de fora da exclusão.
  Widget _toggleTile({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    // O toque no texto alterna igual ao toque no interruptor. Continua sendo
    // gesto, não semântica: quem responde ao leitor de tela é o [Switch].
    void alternar() => onChanged(!valor);

    return MergeSemantics(
      child: Semantics(
        label: '$titulo. $subtitulo',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 5, 8),
          child: Row(
            children: [
              _iconeTile(icone),
              const SizedBox(width: 11),
              Expanded(
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: alternar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              color: _texto,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            style: const TextStyle(
                              color: _textoSec,
                              fontSize: 10.4,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Switch(
                value: valor,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFF2A1700),
                activeTrackColor: _ouro,
                inactiveThumbColor: const Color(0xFF8A806B),
                inactiveTrackColor: const Color(0xFF3A3026),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uma preferência de valor entre poucos — e a mesma régua do [_toggleTile].
  ///
  /// Aqui o rótulo nunca esteve vazio: o [InkWell] recolhia os dois textos e
  /// saía como "Mão dominante / Destro". O que faltava era a FRONTEIRA. Sem um
  /// nó declarado, a anotação de toque do [InkWell] escorregava para o nó de
  /// cima quando esta linha era a última da seção, e a pessoa ouvia
  /// "JOGO Mão dominante Destro" como um botão só — o título da seção grudado
  /// no controle.
  ///
  /// Declarar o nó resolve as duas coisas de uma vez: o controle passa a ter
  /// nome próprio (o que a preferência é, e o valor que está valendo agora) e
  /// para de invadir o que está em volta. `abrir` é o mesmo e único caminho
  /// para trocar o valor, e ele continua saindo do [InkWell] — que é também
  /// quem carrega o foco desta linha, preservado pelo [MergeSemantics] como
  /// no [_navTile].
  Widget _choiceTile<T>({
    required BuildContext context,
    required IconData icone,
    required String titulo,
    required T valor,
    required String Function(T) label,
    required List<T> opcoes,
    required ValueChanged<T> onChanged,
  }) {
    void abrir() => _abrirEscolha<T>(
      context: context,
      titulo: titulo,
      valor: valor,
      opcoes: opcoes,
      label: label,
      onChanged: onChanged,
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: true,
        label: '$titulo. ${label(valor)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: abrir,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Row(
                  children: [
                    _iconeTile(icone),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _cardSecundario,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borda),
                      ),
                      child: Text(
                        label(valor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ouroClaro,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: _textoSec,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEscolha<T>({
    required BuildContext context,
    required String titulo,
    required T valor,
    required List<T> opcoes,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) async {
    final escolhido = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF17100A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borda),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ouroClaro,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final opcao in opcoes)
                  _opcaoDaEscolha<T>(
                    context: context,
                    opcao: opcao,
                    valor: valor,
                    label: label,
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (escolhido != null && escolhido != valor) onChanged(escolhido);
  }

  /// Uma opção da folha de escolha — e a marca de "esta é a que está valendo".
  ///
  /// ---------------------------------------------------------------------
  /// TRÊS SINAIS VISUAIS, NENHUM DELES SEMÂNTICO
  /// ---------------------------------------------------------------------
  ///
  /// Aos olhos, a opção corrente se distingue por fundo dourado, borda dourada
  /// e um ✓ à direita. Nenhum dos três chega ao leitor de tela: cor e borda
  /// não são semântica, e o ✓ é um [Icon] sem rótulo — decorativo por
  /// construção. A folha era anunciada como botões idênticos, e quem não vê a
  /// tela não tinha como saber qual estava valendo antes de trocar.
  ///
  /// `selected` é a marca que existe exatamente para isso, e ela não decide
  /// nada: repete, no canal de acessibilidade, a mesma comparação
  /// `opcao == valor` que pinta o fundo. A escolha continua saindo por
  /// [Navigator.pop] — o mesmo `escolher` que o toque usa, e é por isso que
  /// esta opção virou um método: para não existir uma segunda função de
  /// escolher só para a acessibilidade chamar.
  Widget _opcaoDaEscolha<T>({
    required BuildContext context,
    required T opcao,
    required T valor,
    required String Function(T) label,
  }) {
    final atual = opcao == valor;
    void escolher() => Navigator.of(context).pop(opcao);

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: true,
        selected: atual,
        label: label(opcao),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: escolher,
            child: ExcludeSemantics(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: atual ? _ouro.withValues(alpha: .14) : _cardSecundario,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: atual ? _ouro : _borda),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(opcao),
                        style: TextStyle(
                          color: atual ? _ouroClaro : _texto,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (atual)
                      const Icon(Icons.check_rounded, color: _ouro, size: 21),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconeTile(IconData icone, {bool destaque = false}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: destaque
            ? _roxo.withValues(alpha: .14)
            : _ouro.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque
              ? _roxo.withValues(alpha: .55)
              : _ouro.withValues(alpha: .24),
        ),
      ),
      child: Icon(
        icone,
        color: destaque ? const Color(0xFFDDBBFF) : _ouro,
        size: 18,
      ),
    );
  }

  /// O único caminho de saída — e o único controle desta tela que a varredura
  /// pegava sem papel e sem habilitação.
  ///
  /// Ele nunca esteve anônimo: o texto dentro do [InkWell] já dava o nome. O
  /// que faltava era o resto do contrato, e a varredura de I1/I2 é cega de
  /// propósito — ela olha TODO nó acionável, e não uma lista de controles
  /// conhecidos. Deixar este de fora exigiria uma exceção escrita na suíte, e
  /// uma varredura com lista de exceções é a que deixa passar o próximo.
  Widget _sairButton() {
    // Sem `label`: o nome já vem do texto pintado, e a fusão o traz junto.
    // Declarar aqui de novo o diria duas vezes na fala.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: true,
        child: _sairInterno(),
      ),
    );
  }

  Widget _sairInterno() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: callbacks.onSair,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0E0E),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF8C3535)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFFA2A2), size: 20),
              SizedBox(width: 8),
              Text(
                'Sair da conta',
                style: TextStyle(
                  color: Color(0xFFFFC2C2),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maoLabel(MaoDominante valor) {
    switch (valor) {
      case MaoDominante.destro:
        return 'Destro';
      case MaoDominante.canhoto:
        return 'Canhoto';
    }
  }

  String _conviteLabel(QuemMeConvida valor) {
    switch (valor) {
      case QuemMeConvida.todos:
        return 'Todos';
      case QuemMeConvida.somenteAmigos:
        return 'Só amigos';
      case QuemMeConvida.ninguem:
        return 'Ninguém';
    }
  }

  String _idiomaLabel(Idioma valor) {
    switch (valor) {
      case Idioma.ptBR:
        return 'Português (Brasil)';
    }
  }
}
