import 'package:flutter/material.dart';

import '../tema/iconografia_ajustes.dart';

import 'mesa_orientation_contract.dart';
import 'mesa_orientation_widgets.dart';

enum MaoDominante { destro, canhoto }

enum Idioma { ptBR }

enum QuemMeConvida { todos, somenteAmigos, ninguem }

/// Em que ponto do ciclo a assinatura VIP está, segundo a autoridade.
///
/// Os nomes são os da §10 da OS. Nenhum deles é decidido por esta tela: quem
/// os produz é o host, traduzindo `playerEntitlements/{uid}` — o mesmo
/// documento de onde sai o direito ao Tema Real. NÃO existe estado 'Mensal'
/// nem 'Renova em 24/08' escrito à mão: o plano e a data são campos.
enum SituacaoAssinaturaVip {
  /// A autoridade ainda não respondeu, ou respondeu com falha.
  indisponivel,

  /// Nunca houve compra.
  semAssinatura,

  ativa,

  /// Renovação desligada, período pago em curso.
  renovacaoCancelada,

  /// Pagamento falhou e a Play mantém o acesso enquanto tenta cobrar.
  emCarencia,

  pausada,

  /// Cobrança falhou e a carência acabou.
  emEspera,

  /// Compra existe e ainda não foi paga.
  pendente,

  /// Vencida, revogada ou reembolsada.
  expirada,
}

/// A linha 'Assinatura VIP', montada a partir da autoridade.
@immutable
class AssinaturaVipNaTela {
  const AssinaturaVipNaTela({
    this.situacao = SituacaoAssinaturaVip.indisponivel,
    this.plano,
    this.validoAte,
    this.renovacaoAutomatica = false,
  });

  final SituacaoAssinaturaVip situacao;

  /// Nome do plano, como o catálogo o informa. `null` quando não há plano
  /// conhecido — e aí a tela não inventa um.
  final String? plano;

  final DateTime? validoAte;

  final bool renovacaoAutomatica;
}

@immutable
class PerfilResumo {
  final String apelido;

  /// E-mail da conta autenticada. Visível AQUI, que é tela privada da própria
  /// pessoa, e em lugar nenhum do Perfil público. Vazio quando o provedor de
  /// autenticação não o informa.
  final String email;

  /// Avatar público canônico (`IdentidadePublica.avatarRef`). `null` quando a
  /// identidade ainda não carregou ou o jogador não escolheu um.
  final String? avatar;

  /// O jogador tem BENEFÍCIO VIP COMPLETO agora?
  ///
  /// VEM DA AUTORIDADE, e a tela não o deriva de nada — nem do plano escrito ao
  /// lado, nem do selo, nem de [assinatura]. Quem o produz é `PortaoVip`, que
  /// reavalia a vigência contra o relógio a cada leitura.
  final bool vip;

  final AssinaturaVipNaTela assinatura;

  /// Saldo de FICHAS, ou `null` quando não há autoridade de economia que o
  /// informe.
  ///
  /// Era obrigatório, e quem montava a tela sem fonte passava `0` — que a
  /// pessoa lê como 'estou sem fichas', e não como 'o aplicativo ainda não sabe
  /// quantas'. Nulo tira o número da tela em vez de afirmar um.
  final int? fichas;

  const PerfilResumo({
    required this.apelido,
    required this.email,
    this.avatar,
    required this.vip,
    this.assinatura = const AssinaturaVipNaTela(),
    required this.fichas,
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
  final VoidCallback onFichasECompras;
  final VoidCallback onBloqueados;
  final VoidCallback onRegras;
  final VoidCallback onSuporte;
  final VoidCallback onTermos;
  final VoidCallback onAvaliar;
  final VoidCallback onSair;

  /// Abre o fluxo de exclusão da própria conta.
  ///
  /// `required`, como os outros nove, e a obrigatoriedade é o ponto: um callback
  /// opcional com padrão inofensivo deixaria a tela compilar em qualquer host
  /// que esquecesse de ligá-lo, e o botão ficaria lá sem fazer nada. Sendo
  /// obrigatório, quem constrói a tela é obrigado a decidir para onde ele vai.
  final VoidCallback onExcluirConta;

  const ConfiguracoesCallbacks({
    required this.onAlterar,
    required this.onEditarPerfil,
    required this.onAssinaturaVip,
    required this.onFichasECompras,
    required this.onBloqueados,
    required this.onRegras,
    required this.onSuporte,
    required this.onTermos,
    required this.onAvaliar,
    required this.onSair,
    required this.onExcluirConta,
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

  /// Orientacao da Mesa (docs/OS-CLAUDE-ADENDO-ORIENTACAO-MESA §5).
  ///
  /// Vive fora de [Configuracoes] porque quem persiste e o
  /// `MesaOrientationService`, com chave propria. Opcional para nao quebrar
  /// quem ja constroi esta tela; sem o callback a linha nao aparece.
  final MesaOrientacaoPreferida orientacaoMesa;
  final ValueChanged<MesaOrientacaoPreferida>? onOrientacaoMesa;

  /// O TEMA DE ICONOGRAFIA INTEIRO, resolvido antes desta tela nascer.
  ///
  /// A tela pede o icone pela chave e nunca sabe se atras dela ha um glifo ou
  /// um arquivo. Ela tambem nao decide qual conjunto usar: recebe UM, e por
  /// isso nao existe caminho de codigo em que ela misture os dois. Quem
  /// resolve e `resolverTemaDeAjustes`, a partir da autoridade VIP canonica.
  ///
  /// O padrao e o conjunto publico: quem constroi esta tela sem dizer nada
  /// recebe os icones de hoje, nunca os luxuosos.
  final ConjuntoDeIcones icones;

  // NAO e `const`, e a razao e o `icones`: o conjunto padrao e construido em
  // tempo de execucao porque a completude dele e VERIFICADA na construcao
  // (ver `ConjuntoDeIcones`). Trocar a verificacao por uma tabela `const`
  // devolveria o construtor const e tiraria a unica trava que garante que
  // nenhum conjunto meio pronto chegue a existir.
  ConfiguracoesScreen({
    super.key,
    required this.perfil,
    required this.config,
    required this.callbacks,
    required this.onVoltar,
    this.orientacaoMesa = MesaOrientacaoPreferida.vertical,
    this.onOrientacaoMesa,
    ConjuntoDeIcones? icones,
  }) : icones = icones ?? conjuntoPadraoDeAjustes;

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
                          _perfilCard(context),
                          _secao(
                            titulo: 'CONTA',
                            chave: IconeAjustes.secaoConta,
                            children: [
                              _navTile(
                                chave: IconeAjustes.editarPerfil,
                                titulo: 'Editar perfil',
                                subtitulo: 'Apelido, foto e informações públicas',
                                onTap: callbacks.onEditarPerfil,
                              ),
                              _navTile(
                                chave: IconeAjustes.assinaturaVip,
                                titulo: 'Assinatura VIP',
                                subtitulo: _resumoDaAssinatura(perfil.assinatura),
                                destaque: perfil.vip,
                                onTap: callbacks.onAssinaturaVip,
                              ),
                              _navTile(
                                chave: IconeAjustes.fichasECompras,
                                titulo: 'Fichas e compras',
                                subtitulo: perfil.fichas == null
                                    ? 'Pacotes de fichas e histórico'
                                    : '${perfil.fichas} fichas disponíveis',
                                onTap: callbacks.onFichasECompras,
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'SOM E NOTIFICAÇÕES',
                            chave: IconeAjustes.secaoSomENotificacoes,
                            children: [
                              _toggleTile(
                                chave: IconeAjustes.musica,
                                titulo: 'Música',
                                subtitulo: 'Trilha musical do aplicativo',
                                valor: config.musica,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(musica: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.efeitosSonoros,
                                titulo: 'Efeitos sonoros',
                                subtitulo: 'Cartas, canastras e avisos da mesa',
                                valor: config.efeitosSonoros,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(efeitosSonoros: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.vibracao,
                                titulo: 'Vibração',
                                subtitulo: 'Avisar quando chegar a sua vez',
                                valor: config.vibracao,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(vibracao: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.notificacoes,
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
                            chave: IconeAjustes.secaoJogo,
                            children: [
                              _toggleTile(
                                chave: IconeAjustes.animacoes,
                                titulo: 'Animações',
                                subtitulo: 'Movimentos e celebrações visuais',
                                valor: config.animacoes,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(animacoes: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.ordenarCartas,
                                titulo: 'Ordenar cartas automaticamente',
                                subtitulo: 'Organiza a mão por naipe e valor',
                                valor: config.ordenarCartasAuto,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(ordenarCartasAuto: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.confirmarDescarte,
                                titulo: 'Confirmar antes de descartar',
                                subtitulo: 'Evita descarte por toque acidental',
                                valor: config.confirmarDescarte,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(confirmarDescarte: v),
                                ),
                              ),
                              _choiceTile<MaoDominante>(
                                context: context,
                                chave: IconeAjustes.mao,
                                titulo: 'Mão dominante',
                                valor: config.maoDominante,
                                label: _maoLabel,
                                opcoes: MaoDominante.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(maoDominante: v),
                                ),
                              ),
                              if (onOrientacaoMesa != null)
                                _orientacaoMesaTile(),
                            ],
                          ),
                          _secao(
                            titulo: 'PRIVACIDADE',
                            chave: IconeAjustes.secaoPrivacidade,
                            children: [
                              _choiceTile<QuemMeConvida>(
                                context: context,
                                chave: IconeAjustes.convites,
                                titulo: 'Quem pode me convidar',
                                valor: config.quemMeConvida,
                                label: _conviteLabel,
                                opcoes: QuemMeConvida.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(quemMeConvida: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.chatPublico,
                                titulo: 'Chat público só para maiores',
                                subtitulo: 'Restringe o acesso conforme a conta',
                                valor: config.chatPublicoSoMaiores,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(chatPublicoSoMaiores: v),
                                ),
                              ),
                              _toggleTile(
                                chave: IconeAjustes.presencaOnline,
                                titulo: 'Mostrar quando estou online',
                                subtitulo: 'Amigos poderão ver sua presença',
                                valor: config.mostrarOnline,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(mostrarOnline: v),
                                ),
                              ),
                              _navTile(
                                chave: IconeAjustes.jogadoresBloqueados,
                                titulo: 'Jogadores bloqueados',
                                subtitulo: 'Rever ou desbloquear jogadores',
                                onTap: callbacks.onBloqueados,
                              ),
                            ],
                          ),
                          _secao(
                            titulo: 'GERAL',
                            chave: IconeAjustes.secaoGeral,
                            children: [
                              _choiceTile<Idioma>(
                                context: context,
                                chave: IconeAjustes.idioma,
                                titulo: 'Idioma',
                                valor: config.idioma,
                                label: _idiomaLabel,
                                opcoes: Idioma.values,
                                onChanged: (v) => callbacks.onAlterar(
                                  config.copyWith(idioma: v),
                                ),
                              ),
                              _navTile(
                                chave: IconeAjustes.comoJogar,
                                titulo: 'Regras e como jogar',
                                subtitulo: 'Aberto, Fechado e STBL',
                                onTap: callbacks.onRegras,
                              ),
                              _navTile(
                                chave: IconeAjustes.suporte,
                                titulo: 'Suporte',
                                subtitulo: 'Fale com a equipe do aplicativo',
                                onTap: callbacks.onSuporte,
                              ),
                              _navTile(
                                chave: IconeAjustes.termosEPrivacidade,
                                titulo: 'Termos e privacidade',
                                subtitulo: 'Documentos e políticas do serviço',
                                onTap: callbacks.onTermos,
                              ),
                              _navTile(
                                chave: IconeAjustes.avaliarAplicativo,
                                titulo: 'Avaliar o aplicativo',
                                subtitulo: 'Conte sua experiência na loja',
                                onTap: callbacks.onAvaliar,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _sairButton(),
                          const SizedBox(height: 10),
                          _excluirContaButton(),
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
            // 48 dp EXPLICITOS. O padrao do IconButton e padding 8 em volta do
            // icone, e com o icone de 31 isso da 47,0 x 47,0 — um decimo de
            // milimetro abaixo do minimo, o bastante para reprovar a regua e
            // pequeno demais para alguem notar a olho.
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: IconeDeAjustes(
              conjunto: icones,
              chave: IconeAjustes.voltar,
              cor: _ouro,
              tamanho: 31,
            ),
          ),
          // FLEXIVEL, e nao fixo: em 160% de escala de fonte este titulo
          // empurrava a fileira 130 px para fora da tela. Sem `maxLines`, ele
          // quebra em vez de ser cortado — texto ampliado nao pode perder letra.
          const Flexible(
            child: Text(
              'Configurações',
              style: TextStyle(
                color: _ouroClaro,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ),
          const Spacer(),
          IconeDeAjustes(
            conjunto: icones,
            chave: IconeAjustes.tituloAjustes,
            cor: _ouro,
            tamanho: 23,
          ),
        ],
      ),
    );
  }

  /// O cartao de identidade do topo.
  ///
  /// TRES PECAS DISPUTAM A MESMA LINHA — avatar, bloco de identidade e pastilha
  /// de saldo —, e em 320 dp com fonte a 200% elas nao cabem: o bloco de
  /// identidade sobrava com 56 dp para uma pastilha `VIP` de 70,8 dp, e a
  /// fileira estourava 22 px. Encolher fonte, esconder o saldo ou tirar o selo
  /// resolveria o numero e pioraria a tela.
  ///
  /// O que se faz aqui e REFLUXO: quando a largura nao comporta os tres lado a
  /// lado, a pastilha de saldo desce para uma linha propria. A decisao e
  /// MEDIDA, nao estimada — [_larguraDaPastilhaDeSaldo] e [_pisoDoBlocoDeNome]
  /// usam `TextPainter` com a mesma escala de texto que a tela vai usar. Por
  /// isso a tela a 100% continua exatamente como era: o refluxo so acontece
  /// quando ele e a unica saida.
  Widget _perfilCard(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    final saldo = perfil.fichas;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borda),
      ),
      child: LayoutBuilder(
        builder: (context, restricoes) {
          final identidade = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatarDoPerfil(),
              const SizedBox(width: 12),
              Expanded(child: _blocoDeIdentidade()),
            ],
          );

          if (saldo == null) return identidade;

          final precisa = _kAvatar +
              12 +
              _pisoDoBlocoDeNome(escala) +
              8 +
              _larguraDaPastilhaDeSaldo(saldo, escala);

          if (restricoes.maxWidth >= precisa) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identidade),
                const SizedBox(width: 8),
                _pastilhaDeSaldo(saldo),
              ],
            );
          }

          // Nao coube: o saldo desce inteiro, sem encolher e sem sumir.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identidade,
              const SizedBox(height: 10),
              _pastilhaDeSaldo(saldo),
            ],
          );
        },
      ),
    );
  }

  /// Lado do circulo do avatar.
  static const double _kAvatar = 52;

  Widget _avatarDoPerfil() {
    return Container(
      width: _kAvatar,
      height: _kAvatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2B1B0C),
        border: Border.all(color: _ouro, width: 1.4),
      ),
      child: Text(
        _marcaDoAvatar(perfil),
        style: const TextStyle(
          color: _ouroClaro,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// Estilo do apelido. Fora do `build` porque a medicao do piso precisa dele.
  static const TextStyle _estiloApelido = TextStyle(
    color: _texto,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle _estiloSelo = TextStyle(
    color: Color(0xFFE2C9FF),
    fontSize: 9,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle _estiloSaldo = TextStyle(
    color: _ouroClaro,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  /// Apelido, selo e e-mail.
  ///
  /// O apelido e o selo vivem num `Wrap`, e nao num `Row`: se os dois nao
  /// couberem lado a lado, o selo DESCE — antes ele espremia o apelido ate zero
  /// e estourava mesmo assim.
  ///
  /// Nem o apelido nem o e-mail tem `maxLines`. Os dois sao texto essencial —
  /// o apelido identifica a pessoa e o e-mail identifica a CONTA —, e cortar
  /// qualquer um deles com reticencias e perder informacao que a tela existe
  /// para dar. Sem `maxLines` eles quebram em mais linhas, que e o que texto
  /// ampliado precisa poder fazer.
  Widget _blocoDeIdentidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(perfil.apelido, style: _estiloApelido),
            if (perfil.vip) _seloVip(),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          perfil.email,
          style: const TextStyle(color: _textoSec, fontSize: 11),
        ),
      ],
    );
  }

  Widget _seloVip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _roxo.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _roxo.withValues(alpha: .70)),
      ),
      child: const Text('VIP', style: _estiloSelo),
    );
  }

  /// A pastilha de saldo. So existe quando ha saldo a mostrar — ver
  /// [PerfilResumo.fichas].
  Widget _pastilhaDeSaldo(int saldo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _cardSecundario,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconeDeAjustes(
            conjunto: icones,
            chave: IconeAjustes.saldoDeFichas,
            cor: _ouro,
            tamanho: 17,
          ),
          const SizedBox(width: 4),
          Text('$saldo', style: _estiloSaldo),
        ],
      ),
    );
  }

  /// Quanto a pastilha de saldo ocupa, NA ESCALA DE TEXTO DESTA TELA.
  ///
  /// 9 + 9 de padding, 17 de icone (que nao escala), 4 de respiro, mais o
  /// numero medido, mais 1 + 1 de borda.
  static double _larguraDaPastilhaDeSaldo(int saldo, TextScaler escala) =>
      9 + 17 + 4 + _larguraDoTexto('$saldo', _estiloSaldo, escala) + 9 + 2;

  /// O MINIMO que o bloco de identidade precisa para nao estourar.
  ///
  /// O selo inteiro, o respiro, e espaco para quatro caracteres do apelido —
  /// abaixo disso a linha nao serve para nada, e e melhor o saldo descer.
  static double _pisoDoBlocoDeNome(TextScaler escala) =>
      7 + _larguraDoTexto('VIP', _estiloSelo, escala) + 7 + 2 +
      7 +
      _larguraDoTexto('MMMM', _estiloApelido, escala);

  static double _larguraDoTexto(
    String texto,
    TextStyle estilo,
    TextScaler escala,
  ) {
    final pintor = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textDirection: TextDirection.ltr,
      textScaler: escala,
      maxLines: 1,
    )..layout();
    final largura = pintor.width;
    pintor.dispose();
    return largura;
  }

  Widget _secao({
    required String titulo,
    required IconeAjustes chave,
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
                IconeDeAjustes(
                  conjunto: icones,
                  chave: chave,
                  cor: _ouro,
                  tamanho: 17,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      color: _ouroClaro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
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

  /// Orientacao da mesa: as tres opcoes ficam a vista, sem abrir outra folha,
  /// porque sao poucas e o jogador precisa reconhecer de imediato como a
  /// partida vai abrir.
  Widget _orientacaoMesaTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconeTile(IconeAjustes.orientacaoMesa),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orientação da mesa',
                      style: TextStyle(
                        color: _texto,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Vale só para a Mesa de jogo',
                      style: TextStyle(
                        color: _textoSec,
                        fontSize: 10.4,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MesaOrientacaoSelector(
            valor: orientacaoMesa,
            onChanged: onOrientacaoMesa!,
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconeAjustes chave,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    bool destaque = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              _iconeTile(chave, destaque: destaque),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: destaque ? const Color(0xFFE2C9FF) : _texto,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // SEM `maxLines`, e a razao e acessibilidade: com o teto
                    // de duas linhas, 160% de escala de fonte fazia o subtitulo
                    // ser CORTADO em silencio — sem erro, sem aviso, comendo o
                    // fim da frase. Em 100% os subtitulos desta tela cabem nas
                    // mesmas duas linhas, entao nada muda para quem nao amplia.
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
              IconeDeAjustes(
                conjunto: icones,
                chave: IconeAjustes.avancar,
                cor: _textoSec,
                tamanho: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconeAjustes chave,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 5, 8),
      child: Row(
        children: [
          _iconeTile(chave),
          const SizedBox(width: 11),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!valor),
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
    );
  }

  Widget _choiceTile<T>({
    required BuildContext context,
    required IconeAjustes chave,
    required String titulo,
    required T valor,
    required String Function(T) label,
    required List<T> opcoes,
    required ValueChanged<T> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirEscolha<T>(
          context: context,
          titulo: titulo,
          valor: valor,
          opcoes: opcoes,
          label: label,
          onChanged: onChanged,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              _iconeTile(chave),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardSecundario,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borda),
                ),
                // Idem: o valor escolhido quebra em vez de sumir pela borda.
                child: Text(
                  label(valor),
                  style: const TextStyle(
                    color: _ouroClaro,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              IconeDeAjustes(
                conjunto: icones,
                chave: IconeAjustes.expandir,
                cor: _textoSec,
                tamanho: 21,
              ),
            ],
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
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => Navigator.of(context).pop(opcao),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: opcao == valor
                              ? _ouro.withValues(alpha: .14)
                              : _cardSecundario,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: opcao == valor ? _ouro : _borda,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label(opcao),
                                style: TextStyle(
                                  color: opcao == valor ? _ouroClaro : _texto,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (opcao == valor)
                              IconeDeAjustes(
                                conjunto: icones,
                                chave: IconeAjustes.confirmar,
                                cor: _ouro,
                                tamanho: 21,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (escolhido != null && escolhido != valor) onChanged(escolhido);
  }

  Widget _iconeTile(IconeAjustes chave, {bool destaque = false}) {
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
      child: IconeDeAjustes(
        conjunto: icones,
        chave: chave,
        cor: destaque ? const Color(0xFFDDBBFF) : _ouro,
        tamanho: 18,
      ),
    );
  }

  Widget _sairButton() {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconeDeAjustes(
                conjunto: icones,
                chave: IconeAjustes.sair,
                cor: const Color(0xFFFFA2A2),
                tamanho: 20,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Sair da conta',
                  style: TextStyle(
                    color: Color(0xFFFFC2C2),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Excluir minha conta", abaixo de "Sair da conta".
  ///
  /// FORA DA SEÇÃO "CONTA", E DE PROPÓSITO. Lá em cima ele ficaria ao lado de
  /// "Editar perfil" e "Assinatura VIP" — três tiles idênticos, um deles
  /// irreversível, a um toque de distância um do outro. Aqui embaixo ele é o
  /// último item da tela, depois do fim da rolagem, com o desenho mais discreto
  /// dos dois botões vermelhos: quem chega nele chegou procurando.
  ///
  /// E é um `TextButton`, e não um `FilledButton` como o de sair: o botão mais
  /// destrutivo da tela é o menos chamativo dela. A ênfase visual pertence à
  /// ação que a pessoa vai querer nove em cada dez vezes, que é sair.
  Widget _excluirContaButton() {
    return Center(
      child: TextButton.icon(
        onPressed: callbacks.onExcluirConta,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // 48 dp de alvo, sem 48 dp de ENFASE: o piso de toque cresce, e o
          // desenho continua o mais discreto da tela — texto pequeno,
          // sublinhado, vermelho apagado. Alvo acessivel nao e destaque
          // visual.
          minimumSize: const Size(48, 48),
        ),
        icon: IconeDeAjustes(
          conjunto: icones,
          chave: IconeAjustes.excluirConta,
          cor: const Color(0xFF9C6A6A),
          tamanho: 17,
        ),
        label: const Text(
          'Excluir minha conta',
          style: TextStyle(
            color: Color(0xFF9C6A6A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0x559C6A6A),
          ),
        ),
      ),
    );
  }

  /// A marca do avatar no cabecalho.
  ///
  /// Ordem: avatar publico canonico (`IdentidadePublica.avatarRef`), depois a
  /// inicial do apelido, depois a coroa. A coroa e o fallback que ja existia
  /// para quem nao tem apelido — ela NAO e um selo VIP e nao muda com o tema.
  static String _marcaDoAvatar(PerfilResumo perfil) {
    final avatar = perfil.avatar?.trim() ?? '';
    if (avatar.isNotEmpty) return avatar;
    final apelido = perfil.apelido.trim();
    if (apelido.isEmpty) return '👑';
    return apelido.substring(0, 1).toUpperCase();
  }

  /// A linha da assinatura, campo a campo.
  ///
  /// Nao ha literal de plano nem de data aqui: o que existe sao os NOMES DOS
  /// ESTADOS da §10 e a formatacao de uma data que a autoridade forneceu. Sem
  /// autoridade, a tela diz que nao sabe — nunca que a pessoa nao assina.
  static String _resumoDaAssinatura(AssinaturaVipNaTela a) {
    final plano = (a.plano == null || a.plano!.trim().isEmpty)
        ? 'Plano VIP'
        : a.plano!.trim();
    final ate = a.validoAte;
    final data = ate == null ? null : _dataCurta(ate);
    switch (a.situacao) {
      case SituacaoAssinaturaVip.indisponivel:
        return 'Situacao da assinatura indisponivel agora';
      case SituacaoAssinaturaVip.semAssinatura:
        return 'Conheca os beneficios da assinatura';
      case SituacaoAssinaturaVip.ativa:
        if (data == null) return '$plano · Ativa';
        return a.renovacaoAutomatica
            ? '$plano · Renova em $data'
            : '$plano · Ativa ate $data';
      case SituacaoAssinaturaVip.renovacaoCancelada:
        return data == null
            ? '$plano · Renovacao cancelada'
            : '$plano · Renovacao cancelada, vale ate $data';
      case SituacaoAssinaturaVip.emCarencia:
        return '$plano · Pagamento pendente, acesso mantido';
      case SituacaoAssinaturaVip.pausada:
        return '$plano · Pausada';
      case SituacaoAssinaturaVip.emEspera:
        return '$plano · Cobranca em espera';
      case SituacaoAssinaturaVip.pendente:
        return '$plano · Pagamento nao confirmado';
      case SituacaoAssinaturaVip.expirada:
        return data == null ? '$plano · Expirada' : '$plano · Expirou em $data';
    }
  }

  static String _dataCurta(DateTime quando) {
    final local = quando.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
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
