import 'package:flutter/material.dart';

import '../ranking/estado_ranking.dart';

export '../ranking/estado_ranking.dart' show EstadoRanking, FaseRanking;

enum PerfilEstado { carregando, normal, erro }

enum NavDestino { inicio, ranking, loja, perfil }

class PerfilStats {
  final int vitorias;
  final int partidas;

  /// Canastras — NULÁVEL, e é o único dos quatro que é.
  ///
  /// A lista branca de `projetarJogador` publica partidas, vitórias, derrotas e
  /// aproveitamento de um jogador, e NÃO publica canastras. Quando o Perfil
  /// passou a mostrar os números de um terceiro, ficou faltando exatamente um
  /// dos quatro quadradinhos — e as duas saídas ruins eram escrever zero
  /// (afirmar que a pessoa nunca fez canastra) ou esconder os outros três
  /// (jogar fora o que a autoridade publicou de verdade).
  ///
  /// Nulo é a terceira, e é a mesma regra que o resto desta tela já segue: nível,
  /// XP e título são nulos pelo mesmo motivo, e [EstadoRanking] existe inteiro
  /// para poder dizer "não sei" sobre liga. Um tipo que não sabe dizer isso
  /// obriga quem o constrói a mentir.
  final int? canastras;
  final int aproveitamento;

  const PerfilStats({
    required this.vitorias,
    required this.partidas,
    required this.canastras,
    required this.aproveitamento,
  });
}

class UltimaConquista {
  final String titulo;
  final String subtitulo;
  final String imagem;
  final String raridade;

  const UltimaConquista({
    required this.titulo,
    required this.subtitulo,
    required this.imagem,
    required this.raridade,
  });
}

class Conquista {
  final String id;
  final String label;
  final String icone;
  final bool desbloqueada;

  const Conquista({
    required this.id,
    required this.label,
    required this.icone,
    required this.desbloqueada,
  });
}

class ItemVitrine {
  final String slot;
  final String nome;
  final String icone;

  const ItemVitrine({
    required this.slot,
    required this.nome,
    required this.icone,
  });
}

class Presente {
  final String id;
  final String nome;
  final String icone;
  final int quantidade;

  const Presente({
    required this.id,
    required this.nome,
    required this.icone,
    required this.quantidade,
  });
}

/// O que a tela precisa saber sobre um jogador VISITADO.
///
/// ---------------------------------------------------------------------------
/// NÃO É UM SEGUNDO PERFIL PÚBLICO
/// ---------------------------------------------------------------------------
///
/// A autoridade sobre quem é um terceiro continua sendo uma só — a projeção que
/// o backend publica e que o cliente lê como `JogadorPublicoRanking`. Isto aqui
/// é a TRADUÇÃO dela para a linguagem da tela, e existe por uma razão de
/// fronteira: o `PerfilService` não pode conhecer o transporte de ranking (há
/// auditoria que o exige), então alguém tem de atravessar essa fronteira. Quem
/// atravessa é o `PerfilPage`, num ponto só.
///
/// O VALOR DE SER UM OBJETO, e não três parâmetros soltos: nome, avatar e
/// números viajam JUNTOS ou não viajam. Foi exatamente a possibilidade de eles
/// viajarem separados que produziu o defeito que este tipo veio fechar — um
/// perfil com a liga de B e o nome de A. Um objeto só não tem como ser montado
/// pela metade a partir de duas pessoas.
class RetratoVisitado {
  const RetratoVisitado({
    required this.nome,
    required this.avatar,
    required this.stats,
  });

  /// Como este jogador se apresenta aos outros. Nunca o nome de quem olha.
  final String nome;

  /// Já resolvido pela autoridade canônica de avatar — a mesma da Home e do
  /// perfil próprio. Não há segundo fallback: referência ausente ou malformada
  /// de um terceiro cai na MESMA coroa que a de qualquer um.
  final String avatar;

  /// Os números que a autoridade pública publicou sobre ele.
  final PerfilStats stats;
}

/// View-model visual do contrato entregue pelo Claude.
///
/// Nesta branch de UI, o factory [mock] existe somente para validar o protótipo.
/// Na integração, o Claude substitui a origem dos dados pelos models/serviços reais.
class PerfilVM {
  final bool ehMeuPerfil;
  final String nome;
  final String avatar;
  final String mascote;
  final String moldura;
  final String dorso;
  final String efeito;

  // O QUE PODE SER NULO, E POR QUÊ.
  //
  // Progressão (nível/XP/título), estatísticas, presentes e conquistas são
  // NULÁVEIS porque hoje não existe autoridade que os informe: nada grava
  // resultado de partida no cliente, não há sistema de XP, título é concedido e
  // quem sabe o que foi desbloqueado é o backend de recompensas, que o cliente
  // ainda não lê. Nulo aqui quer dizer "não há fonte", e a tela responde não
  // desenhando o elemento — a mesma regra que a Home de produção já seguia.
  //
  // O MOTIVO DE NÃO SEREM ZERO. `nivel: 1`, `stats: 0/0/0/0` e oito troféus
  // apagados pareciam modéstia, e são o contrário: um zero desenhado é uma
  // AFIRMAÇÃO. Diz que a pessoa jogou e não ganhou, que foi avaliada e ficou na
  // base. Ninguém a avaliou. Um perfil vazio é feio; um perfil que inventa é
  // pior.
  //
  // [conquistas] distingue os dois casos que a lista vazia colapsava: `null` é
  // "não há fonte" e a seção inteira sai; `[]` é uma fonte que respondeu "nenhuma
  // ainda", e aí o recado de estado vazio é legítimo. É a mesma separação que
  // [FaseRanking] faz para liga e colocação.
  final int? nivel;
  final int? xpAtual;
  final int? xpProximo;
  final String? titulo;
  final String? tituloEmoji;

  /// O estado competitivo, como um valor só.
  ///
  /// ERA `String liga` + `int posicaoMundial`, e o preço eram dois campos
  /// obrigatórios que o produtor tinha de preencher mesmo sem ter o dado — o
  /// serviço preenchia com `'Bronze'` e `0`, e a tela desenhava os dois como se
  /// fossem conquista e colocação. Um tipo que não sabe dizer "não sei" obriga
  /// quem o constrói a mentir.
  ///
  /// Não é anulável, e isso é de propósito: [EstadoRanking] JÁ sabe dizer "não
  /// sei" por dentro, com quatro fases distintas. Um `EstadoRanking?` teria dois
  /// jeitos de escrever a mesma ausência, e a duplicidade é justamente o que
  /// produziu o Bronze.
  final EstadoRanking ranking;
  final PerfilStats? stats;
  final UltimaConquista? ultimaConquista;
  final int? presentesCount;
  final List<Conquista>? conquistas;
  final List<ItemVitrine> vitrine;
  final List<Presente> presentes;

  const PerfilVM({
    required this.ehMeuPerfil,
    required this.nome,
    required this.avatar,
    required this.mascote,
    required this.moldura,
    required this.dorso,
    required this.efeito,
    required this.nivel,
    required this.xpAtual,
    required this.xpProximo,
    required this.titulo,
    required this.tituloEmoji,
    required this.ranking,
    required this.stats,
    required this.ultimaConquista,
    required this.presentesCount,
    required this.conquistas,
    required this.vitrine,
    required this.presentes,
  });

  // Os DOIS enriquecimentos abaixo vivem lado a lado de propósito, e o merge
  // que os juntou é a razão deste comentário existir: o Git empilhou os dois
  // corpos num método só, e a resolução preguiçosa — ficar com um — apagaria em
  // silêncio metade de uma correção já homologada.
  //
  // Eles não competem porque não escrevem no mesmo campo: `comRanking` só toca
  // `ranking`, `comAvatarPublico` só toca `avatar`. Encadeá-los em qualquer
  // ordem dá o mesmo VM, e é por isso que a página pode aplicá-los em sequência
  // sem que um desfaça o outro.
  //
  // Nenhum dos dois é um `copyWith` genérico, e a recusa é a mesma nos dois
  // casos: os outros campos têm um produtor só, e abrir a porta para remendá-los
  // na tela é exatamente como nasce a segunda autoridade que as duas correções
  // vieram fechar.

  /// O mesmo perfil, com outro estado competitivo.
  ///
  /// Existe porque o ranking é a única parte do VM que muda SOZINHA depois da
  /// carga: o resto vem de uma consulta que já terminou, e ele vem de outra que
  /// ainda pode estar em voo. Sem isto, a página teria de recarregar o perfil
  /// inteiro para trocar uma liga — ou, pior, congelar o ranking no instante da
  /// carga e nunca mais atualizá-lo.
  PerfilVM comRanking(EstadoRanking outro) => PerfilVM(
    ehMeuPerfil: ehMeuPerfil,
    nome: nome,
    avatar: avatar,
    mascote: mascote,
    moldura: moldura,
    dorso: dorso,
    efeito: efeito,
    nivel: nivel,
    xpAtual: xpAtual,
    xpProximo: xpProximo,
    titulo: titulo,
    tituloEmoji: tituloEmoji,
    ranking: outro,
    stats: stats,
    ultimaConquista: ultimaConquista,
    presentesCount: presentesCount,
    conquistas: conquistas,
    vitrine: vitrine,
    presentes: presentes,
  );

  /// O mesmo perfil, com o avatar substituído pelo valor canônico da sessão.
  ///
  /// EXISTE POR CAUSA DA REATIVIDADE, e é o único campo que ganha este
  /// tratamento. O `PerfilVM` é montado por uma carga assíncrona, e a carga só
  /// se repete quando o `publicId` muda; um `avatarRef` trocado DENTRO da mesma
  /// identidade não moveria aquele gatilho, e o Perfil ficaria com o avatar
  /// velho até o jogador sair e entrar de novo. Reaplicando a resolução a cada
  /// `build`, o avatar exibido passa a ser função direta do estado vivo — sem
  /// recarga, sem esqueleto piscando e sem uma segunda consulta.
  PerfilVM comAvatarPublico(String avatarCanonico) => PerfilVM(
    ehMeuPerfil: ehMeuPerfil,
    nome: nome,
    avatar: avatarCanonico,
    mascote: mascote,
    moldura: moldura,
    dorso: dorso,
    efeito: efeito,
    nivel: nivel,
    xpAtual: xpAtual,
    xpProximo: xpProximo,
    titulo: titulo,
    tituloEmoji: tituloEmoji,
    ranking: ranking,
    stats: stats,
    ultimaConquista: ultimaConquista,
    presentesCount: presentesCount,
    conquistas: conquistas,
    vitrine: vitrine,
    presentes: presentes,
  );

  factory PerfilVM.mock({bool ehMeuPerfil = true}) {
    return PerfilVM(
      ehMeuPerfil: ehMeuPerfil,
      nome: 'Aurora',
      avatar: '👑',
      mascote: '🦊',
      moldura: 'assets/perfil/vitrine_moldura.webp',
      dorso: 'assets/perfil/vitrine_dorso.webp',
      efeito: 'assets/perfil/vitrine_efeito.webp',
      nivel: 24,
      xpAtual: 3240,
      xpProximo: 5000,
      titulo: 'Rainha da Canastra',
      tituloEmoji: '👑',
      // Maquete: liga e colocação são AFIRMADAS aqui porque este factory existe
      // só para o protótipo visual. Nenhuma rota que nasça em `main()` o
      // alcança — quem monta o Perfil publicável é o `PerfilService`.
      ranking: const EstadoRanking.disponivel(
        liga: 'Diamante',
        posicaoMundial: 128,
      ),
      stats: const PerfilStats(
        vitorias: 342,
        partidas: 1204,
        canastras: 89,
        aproveitamento: 68,
      ),
      ultimaConquista: const UltimaConquista(
        titulo: 'Primeira Batida Real',
        subtitulo: 'Marco de Jornada · Comum Especial · desbloqueada hoje',
        imagem: 'assets/perfil/ultima_conquista.webp',
        raridade: 'Comum Especial',
      ),
      presentesCount: 12,
      conquistas: const [
        Conquista(
          id: 'primeiro_lugar',
          label: '1º lugar',
          icone: 'assets/perfil/conquista_1_lugar.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'sequencia_10',
          label: 'Sequência 10',
          icone: 'assets/perfil/conquista_sequencia_10.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'cem_canastras',
          label: '100 canastras',
          icone: 'assets/perfil/conquista_100_canastras.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'diamante',
          label: 'Chegou ao Diamante',
          icone: 'assets/perfil/conquista_diamante.webp',
          desbloqueada: true,
        ),
        Conquista(
          id: 'campeao',
          label: 'Campeão',
          icone: 'assets/perfil/conquista_campeao.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'imortal',
          label: 'Imortal',
          icone: 'assets/perfil/conquista_imortal.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'lenda',
          label: 'Lenda',
          icone: 'assets/perfil/conquista_lenda.webp',
          desbloqueada: false,
        ),
        Conquista(
          id: 'perfeito',
          label: 'Perfeito',
          icone: 'assets/perfil/conquista_perfeito.webp',
          desbloqueada: false,
        ),
      ],
      vitrine: const [
        ItemVitrine(
          slot: 'avatar',
          nome: 'Avatar',
          icone: 'assets/perfil/vitrine_avatar.webp',
        ),
        ItemVitrine(
          slot: 'moldura',
          nome: 'Moldura',
          icone: 'assets/perfil/vitrine_moldura.webp',
        ),
        ItemVitrine(
          slot: 'mascote',
          nome: 'Mascote',
          icone: 'assets/perfil/vitrine_mascote.webp',
        ),
        ItemVitrine(
          slot: 'dorso',
          nome: 'Dorso',
          icone: 'assets/perfil/vitrine_dorso.webp',
        ),
        ItemVitrine(
          slot: 'efeito',
          nome: 'Efeito',
          icone: 'assets/perfil/vitrine_efeito.webp',
        ),
      ],
      presentes: const [
        Presente(
          id: 'rosa',
          nome: 'Rosa',
          icone: 'assets/perfil/presente_rosa.webp',
          quantidade: 5,
        ),
        Presente(
          id: 'bombom',
          nome: 'Bombom',
          icone: 'assets/perfil/presente_bombom.webp',
          quantidade: 3,
        ),
        Presente(
          id: 'champanhe',
          nome: 'Champanhe',
          icone: 'assets/perfil/presente_champanhe.webp',
          quantidade: 2,
        ),
        Presente(
          id: 'diamante',
          nome: 'Diamante',
          icone: 'assets/perfil/presente_diamante.webp',
          quantidade: 2,
        ),
      ],
    );
  }
}

class PerfilScreen extends StatefulWidget {
  final PerfilVM vm;
  final PerfilEstado estado;
  final String? mensagemErro;
  final VoidCallback onVoltar;
  final VoidCallback onAbrirConfig;
  final VoidCallback onTrocarAvatar;
  final VoidCallback onEditarNick;
  final VoidCallback onEditarPerfil;
  final VoidCallback onAbrirPresentes;
  final VoidCallback onFecharPresentes;
  final VoidCallback onVerTodasConquistas;
  final ValueChanged<String> onVerConquista;
  final VoidCallback onVerUltimaConquista;
  final VoidCallback onTrocarVitrine;
  final VoidCallback onCompartilhar;
  final VoidCallback onRecarregar;
  final ValueChanged<NavDestino> onNavTap;

  /// Abrir o ranking completo a partir da LINHA COMPETITIVA.
  ///
  /// -------------------------------------------------------------------------
  /// POR QUE É OPCIONAL
  /// -------------------------------------------------------------------------
  ///
  /// Nulo é o estado honesto de quem monta esta tela sem casca — dezenas de
  /// testes de widget e o catálogo visual. Sem autoridade de ranking alcançável
  /// não há tabela para abrir, e uma linha tocável que não leva a lugar nenhum
  /// é pior do que uma linha que não se oferece.
  ///
  /// Com o callback, e SÓ com ele, a linha vira alvo de toque: ganha área
  /// mínima, um nó de acessibilidade de botão e a seta que diz que ali se
  /// aperta. Sem ele, o desenho é byte a byte o que sempre foi.
  final VoidCallback? onAbrirRanking;

  const PerfilScreen({
    super.key,
    required this.vm,
    this.estado = PerfilEstado.normal,
    this.mensagemErro,
    required this.onVoltar,
    required this.onAbrirConfig,
    required this.onTrocarAvatar,
    required this.onEditarNick,
    required this.onEditarPerfil,
    required this.onAbrirPresentes,
    required this.onFecharPresentes,
    required this.onVerTodasConquistas,
    required this.onVerConquista,
    required this.onVerUltimaConquista,
    required this.onTrocarVitrine,
    required this.onCompartilhar,
    required this.onRecarregar,
    required this.onNavTap,
    this.onAbrirRanking,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x33EFB94A);
  static const _roxoBorda = Color(0xAAB98BFF);

  PerfilVM get vm => widget.vm;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Expanded(child: _conteudo()),
              _navInferior(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    switch (widget.estado) {
      case PerfilEstado.carregando:
        return _carregando();
      case PerfilEstado.erro:
        return _erro();
      case PerfilEstado.normal:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topo(),
              _hero(),
              _xp(),
              _stats(),
              if (vm.ultimaConquista != null) ...[
                _tituloSecao('ÚLTIMA CONQUISTA'),
                _ultimaConquista(vm.ultimaConquista!),
              ],
              _presentes(),
              // Sem fonte de conquistas, a seção inteira sai — título incluído.
              // Deixar o título com um recado embaixo já seria afirmar: "ainda
              // sem conquistas" é uma frase sobre a vida da pessoa, e ninguém
              // conferiu isso. Com fonte que responde vazio, o recado volta.
              if (vm.conquistas != null) ...[
                _tituloSecao(
                  'CONQUISTAS',
                  acao: 'ver todas ›',
                  onAcao: widget.onVerTodasConquistas,
                ),
                _conquistas(vm.conquistas!),
              ],
              _tituloSecao(
                'VITRINE EQUIPADA',
                acao: vm.ehMeuPerfil ? 'trocar ›' : null,
                onAcao: vm.ehMeuPerfil ? widget.onTrocarVitrine : null,
              ),
              _vitrine(),
              _botoes(),
            ],
          ),
        );
    }
  }

  Widget _topo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _botaoTopo(
            tooltip: 'Voltar',
            onTap: widget.onVoltar,
            child: const Icon(Icons.chevron_left_rounded, color: _ouro, size: 29),
          ),
          const SizedBox(width: 2),
          const Text(
            'Perfil',
            style: TextStyle(
              color: _ouroClaro,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const Spacer(),
          _botaoTopo(
            tooltip: 'Configurações',
            onTap: widget.onAbrirConfig,
            child: const Icon(Icons.settings_rounded, color: Color(0xFFD9C79A), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _botaoTopo({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        children: [
          SizedBox(
            width: 126,
            height: 126,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      transform: GradientRotation(3.66),
                      colors: [
                        Color(0xFF7A5A1E),
                        Color(0xFFF6E2A6),
                        Color(0xFFD5A84A),
                        Color(0xFFF6E2A6),
                        Color(0xFF8A6528),
                        Color(0xFFF6E2A6),
                        Color(0xFF7A5A1E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ouro.withValues(alpha: .33),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF120A06),
                    ),
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-.2, -.35),
                      colors: [Color(0xFF3A2606), Color(0xFF1A1206)],
                    ),
                    border: Border.all(color: _ouro.withValues(alpha: .33), width: 2),
                  ),
                  child: Center(child: _icone(vm.avatar, 44)),
                ),
                // Sem sistema de progressão ligado, não há nível para carimbar
                // no avatar. O selo some inteiro em vez de mostrar "1".
                if (vm.nivel != null)
                  Positioned(
                    left: 0,
                    bottom: 8,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_ouroClaro, Color(0xFFD5A84A)],
                        ),
                        border: Border.all(color: const Color(0xFF3A2606), width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Text(
                        '${vm.nivel}',
                        style: const TextStyle(
                          color: Color(0xFF3A2606),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const RadialGradient(
                        center: Alignment(-.2, -.3),
                        colors: [Color(0xFF4A3416), Color(0xFF231607)],
                      ),
                      border: Border.all(color: _ouro, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: _icone(vm.mascote, 22),
                  ),
                ),
                if (vm.ehMeuPerfil)
                  Positioned(
                    right: 1,
                    top: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTrocarAvatar,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_ouroClaro, Color(0xFFE0A83A)],
                            ),
                            border: Border.all(color: const Color(0xFF241812), width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                          child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF3A2606), size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  vm.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ouroClaro,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
              ),
              if (vm.ehMeuPerfil) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onEditarNick,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: .33),
                      border: Border.all(color: _borda),
                    ),
                    child: const Icon(Icons.edit_rounded, color: _ouro, size: 15),
                  ),
                ),
              ],
            ],
          ),
          // Título honorífico só existe se alguém o concedeu. Sem fonte, a
          // faixa inteira sai — 'Novato(a)' também é um título inventado, e um
          // que o jogo põe na pessoa sem ela ter feito nada para merecê-lo.
          if (vm.titulo != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF2A1E0C), Color(0xFF191007)]),
                border: Border.all(color: _ouro.withValues(alpha: .30)),
              ),
              child: Text(
                vm.tituloEmoji == null ? vm.titulo! : '${vm.tituloEmoji} ${vm.titulo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF0D99A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 7),
          // A LINHA COMPETITIVA.
          //
          // O rótulo e o valor da liga ficam sempre — sem liga, o valor é o
          // travessão de [EstadoRanking.ligaParaExibicao], que é uma ausência
          // admitida e não desloca o cabeçalho. Já a colocação SOME quando não
          // existe: não há travessão que faça `#` parecer honesto, e o trecho
          // é o último da linha, então tirá-lo não mexe em mais nada.
          //
          // O PREFIXO "Liga" SÓ APARECE DIANTE DE UMA LIGA. O backend usa o
          // mesmo campo para o nome da Liga e para o estado de qualificação
          // ("Em colocacao"), e distingue os dois por `ligaId`. Sem esta
          // guarda, a tela escreveria "💎 Liga Em colocacao" — que não é
          // português e, pior, faz um estado passar por conquista.
          _linhaCompetitiva(vm.ranking),
        ],
      ),
    );
  }

  /// A liga e a colocação, para os olhos e para o leitor de tela.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE A SEMÂNTICA NÃO É O TEXTO VISÍVEL
  /// ---------------------------------------------------------------------
  ///
  /// Lido em voz alta, o que está na tela vira lixo. "💎 Liga", "Ouro" e "·
  /// #128 no mundo" chegam como três fragmentos soltos, o emoji é anunciado
  /// como "diamante" — que parece o NOME de uma liga —, o `·` vira ruído e o
  /// `#` costuma sair como "cerquilha". E o travessão da ausência, que aos
  /// olhos se lê como "não tem", é anunciado como "traço".
  ///
  /// Por isso o bloco inteiro vira UM nó semântico com uma frase escrita para
  /// ser ouvida, e os filhos saem da árvore de acessibilidade. Não é
  /// duplicação: é a mesma informação dita de dois jeitos, cada um no seu
  /// meio. O que não pode acontecer — e é o que `excludeSemantics` impede — é
  /// o leitor de tela anunciar a frase E depois soletrar os fragmentos.
  ///
  /// Os estados não numéricos são anunciados como estados, e nunca como uma
  /// liga vazia: "carregando" não é ausência de liga, e "ainda não
  /// classificado" não é o mesmo que "não consegui carregar".
  Widget _linhaCompetitiva(EstadoRanking ranking) {
    final linha = Semantics(
      container: true,
      excludeSemantics: true,
      label: _anuncioCompetitivo(ranking),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          if (ranking.ehLigaDeVerdade || !ranking.temLiga)
            const Text(
              '💎 Liga',
              style: TextStyle(color: Color(0xFFCFC0A0), fontSize: 12),
            ),
          Text(
            ranking.ligaParaExibicao,
            style: const TextStyle(
              color: Color(0xFF9FDCFF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ranking.temPosicao)
            Text(
              '· #${ranking.posicaoMundial} no mundo',
              style: const TextStyle(color: Color(0xFFCFC0A0), fontSize: 12),
            ),
        ],
      ),
    );

    final abrir = widget.onAbrirRanking;
    if (abrir == null) return linha;

    // O NÓ DE DENTRO CONTINUA INTACTO, e isso não é detalhe de implementação: a
    // frase que o leitor de tela anuncia sobre a classificação foi escrita para
    // ser ouvida e está fixada por teste. O botão é um nó A MAIS, por fora, com
    // o rótulo da AÇÃO — quem navega por acessibilidade ouve o que a linha diz e
    // depois o que dá para fazer com ela, em vez de perder um dos dois.
    return Semantics(
      button: true,
      label: 'Ver o ranking completo',
      child: InkWell(
        onTap: abrir,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          // A linha tem 15 pixels de texto. Sem este piso, o alvo de toque seria
          // menor que um terço do mínimo das diretrizes — e num lugar onde o
          // dedo erra para cima cai no apelido e para baixo na barra de XP.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: linha),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCFC0A0),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A frase que o leitor de tela anuncia.
  static String _anuncioCompetitivo(EstadoRanking ranking) {
    switch (ranking.fase) {
      case FaseRanking.carregando:
        return 'Carregando sua classificação.';
      case FaseRanking.falha:
        return 'Não foi possível carregar sua classificação. '
            'Use o botão de tentar novamente.';
      // NEUTRO, e essa é a correção: a recusa pode ser de credencial OU de
      // atestação (App Check), e daqui não dá para saber qual. A frase não
      // acusa a sessão de nada e aponta para a única ação que pode funcionar.
      case FaseRanking.acessoRecusado:
        return 'Não foi possível acessar sua classificação. Tente novamente.';
      case FaseRanking.sessaoInvalida:
        return 'Classificação indisponível: entre na sua conta de novo.';
      case FaseRanking.indisponivel:
        return 'Classificação ainda não disponível.';
      case FaseRanking.disponivel:
        final liga = ranking.liga;
        final posicao = ranking.posicaoMundial;
        if (liga == null && posicao == null) return 'Ainda não classificado.';
        // Liga sem `ligaId` é rótulo de qualificação, e é anunciado como ele
        // é — "Em colocacao" —, sem a palavra Liga na frente.
        final ligaDita = ranking.ehLigaDeVerdade
            ? 'Liga $liga'
            : (liga ?? 'Sem liga');
        if (posicao == null) return '$ligaDita. Sem colocação no mundo.';
        return '$ligaDita. Posição $posicao no mundo.';
    }
  }

  Widget _xp() {
    // Barra de XP sem sistema de XP seria uma barra vazia dizendo que a pessoa
    // está no começo de uma jornada que o jogo ainda não conta. Os três campos
    // andam juntos: meia barra é tão inventada quanto a barra inteira.
    final nivel = vm.nivel;
    final xpAtual = vm.xpAtual;
    final xpProximo = vm.xpProximo;
    if (nivel == null || xpAtual == null || xpProximo == null) {
      return const SizedBox.shrink();
    }
    final progresso = xpProximo <= 0 ? 0.0 : (xpAtual / xpProximo).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Nível '),
                    TextSpan(
                      text: '$nivel',
                      style: const TextStyle(color: _ouro, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${_numero(xpAtual)} / ${_numero(xpProximo)} XP',
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .33),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ouro.withValues(alpha: .15)),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * progresso,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_ouroClaro, Color(0xFFE0A83A)]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    // Vitórias, partidas e canastras vêm de resultado de partida gravado. Nada
    // grava resultado no cliente hoje, então quatro zeros não seriam "o placar
    // de quem ainda não jogou" — seriam um placar sem placar nenhum atrás.
    final stats = vm.stats;
    if (stats == null) return const SizedBox.shrink();
    final canastras = stats.canastras;
    // O quadradinho de canastras SOME quando não há fonte, em vez de mostrar
    // zero. Vale para o perfil visitado, onde a lista branca da autoridade
    // pública não publica canastras — e três números verdadeiros valem mais que
    // quatro com um inventado.
    final dados = [
      (_numero(stats.vitorias), 'Vitórias'),
      (_numero(stats.partidas), 'Partidas'),
      if (canastras != null) (_numero(canastras), 'Canastras'),
      ('${stats.aproveitamento}%', 'Aproveit.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          for (var i = 0; i < dados.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borda),
                ),
                child: Column(
                  children: [
                    Text(
                      dados[i].$1,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _ouroClaro,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dados[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(color: _textoSec, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ),
            if (i != dados.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tituloSecao(
    String titulo, {
    String? acao,
    VoidCallback? onAcao,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: _ouro,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (acao != null)
            InkWell(
              onTap: onAcao,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text(acao, style: const TextStyle(color: _textoSec, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ultimaConquista(UltimaConquista conquista) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onVerUltimaConquista,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
              ),
              border: Border.all(color: _ouro.withValues(alpha: .50), width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                _imagem(conquista.imagem, 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏅 ${conquista.titulo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ouroClaro, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conquista.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC9A86A), fontSize: 10.5, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _ouro, size: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presentes() {
    // Presente é item de inventário, e não existe inventário ligado no cliente.
    // Sem fonte, o baú não é desenhado — um baú que abre vazio é pior do que
    // ele não estar ali.
    final quantos = vm.presentesCount;
    if (quantos == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrirPresentes,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A1748), Color(0xFF1A1030)],
              ),
              border: Border.all(color: _roxoBorda, width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                _imagem('assets/perfil/presentes_bau.webp', 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎁 Meus Presentes',
                        style: TextStyle(color: Color(0xFFE6D0FF), fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'presentes que você recebeu · $quantos',
                        style: const TextStyle(color: Color(0xFFC3B0E8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFD9C2FF), size: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A grade de conquistas de uma fonte que RESPONDEU.
  ///
  /// Recebe a lista por parâmetro, e não por `vm.conquistas`, porque quem
  /// decide se a seção existe é [_conteudo] — aqui a lista já é uma resposta, e
  /// vazia significa "nenhuma ainda", que é um recado legítimo.
  Widget _conquistas(List<Conquista> conquistas) {
    if (conquistas.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borda),
        ),
        child: const Text(
          'Ainda sem conquistas. Sua primeira vitória já abre esse caminho. 👑',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textoSec, fontSize: 12, height: 1.35),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        itemCount: conquistas.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final conquista = conquistas[index];
          return Opacity(
            opacity: conquista.desbloqueada ? 1 : .72,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onVerConquista(conquista.id),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(3, 7, 3, 5),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borda),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child: _imagem(conquista.icone, 46))),
                      const SizedBox(height: 2),
                      Text(
                        '${conquista.desbloqueada ? '' : '🔒 '}${conquista.label}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textoSec, fontSize: 8.5, height: 1.05),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vitrine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var i = 0; i < vm.vitrine.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borda),
                ),
                child: Column(
                  children: [
                    _imagem(vm.vitrine[i].icone, 30),
                    const SizedBox(height: 4),
                    Text(
                      vm.vitrine[i].nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textoSec, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            if (i != vm.vitrine.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _botoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          if (vm.ehMeuPerfil) ...[
            Expanded(
              child: _botaoAcao(
                icon: Icons.edit_rounded,
                label: 'Editar perfil',
                primario: true,
                onTap: widget.onEditarPerfil,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _botaoAcao(
              icon: Icons.link_rounded,
              label: 'Compartilhar',
              primario: false,
              onTap: widget.onCompartilhar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoAcao({
    required IconData icon,
    required String label,
    required bool primario,
    required VoidCallback onTap,
  }) {
    final corConteudo = primario ? const Color(0xFF3A2606) : _ouro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: primario
                ? const LinearGradient(colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)])
                : null,
            border: primario ? null : Border.all(color: _ouro.withValues(alpha: .50), width: 1.4),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: corConteudo, size: 20),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: corConteudo,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navInferior() {
    final itens = const [
      (NavDestino.inicio, 'Início', 'assets/perfil/nav_inicio.webp'),
      (NavDestino.ranking, 'Ranking', 'assets/perfil/nav_ranking.webp'),
      (NavDestino.loja, 'Loja', 'assets/perfil/nav_loja.webp'),
      (NavDestino.perfil, 'Perfil', 'assets/perfil/nav_perfil.webp'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: _borda)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          for (final item in itens)
            Expanded(
              child: InkWell(
                onTap: () => widget.onNavTap(item.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(opacity: item.$1 == NavDestino.perfil ? 1 : .42, child: _imagem(item.$3, 24)),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$1 == NavDestino.perfil ? _ouro : Colors.white.withValues(alpha: .25),
                          fontSize: 10.5,
                          fontWeight: item.$1 == NavDestino.perfil ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _abrirPresentes() async {
    widget.onAbrirPresentes();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1236), Color(0xFF120A1E)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: _roxoBorda, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🎁 Meus Presentes',
                      style: TextStyle(color: Color(0xFFE6D0FF), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: .33),
                      ),
                      child: const Icon(Icons.close_rounded, color: Color(0xFFD9C2FF), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Presentes que você recebeu dos amigos e fãs 💜',
                style: TextStyle(color: Color(0xFFC3B0E8), fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              if (vm.presentes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('Nenhum presente recebido ainda.', style: TextStyle(color: Color(0xFFC3B0E8))),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vm.presentes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: .82,
                  ),
                  itemBuilder: (context, index) {
                    final presente = vm.presentes[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF241748), Color(0xFF1A1030)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0x66B98BFF)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: Center(child: _imagem(presente.icone, 46))),
                          const SizedBox(height: 3),
                          Text(
                            presente.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFD9CFFB), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '×${presente.quantidade}',
                            style: const TextStyle(color: Color(0xFFF6D77A), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
    widget.onFecharPresentes();
  }

  Widget _carregando() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          _topo(),
          const SizedBox(height: 26),
          _skeleton(width: 118, height: 118, circular: true),
          const SizedBox(height: 14),
          _skeleton(width: 190, height: 25),
          const SizedBox(height: 10),
          _skeleton(width: 220, height: 27),
          const SizedBox(height: 24),
          _skeleton(width: double.infinity, height: 9),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(child: _skeleton(width: double.infinity, height: 68)),
                if (i != 3) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _skeleton(width: double.infinity, height: 76),
          const SizedBox(height: 12),
          _skeleton(width: double.infinity, height: 76),
        ],
      ),
    );
  }

  Widget _skeleton({required double width, required double height, bool circular = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: .055),
        border: Border.all(color: _borda),
      ),
    );
  }

  Widget _erro() {
    return Column(
      children: [
        _topo(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: _ouro, size: 46),
                  const SizedBox(height: 14),
                  Text(
                    widget.mensagemErro ?? 'Não foi possível carregar este perfil.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _texto, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.onRecarregar,
                    style: FilledButton.styleFrom(backgroundColor: _ouro, foregroundColor: const Color(0xFF3A2606)),
                    child: const Text('Tentar de novo', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _icone(String valor, double tamanho) {
    if (valor.startsWith('assets/')) return _imagem(valor, tamanho);
    return Text(valor, style: TextStyle(fontSize: tamanho));
  }

  Widget _imagem(String asset, double tamanho) {
    return Image.asset(
      asset,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: _ouro, size: tamanho * .72),
    );
  }

  static String _numero(int valor) {
    final texto = valor.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return valor < 0 ? '-$buffer' : buffer.toString();
  }
}
