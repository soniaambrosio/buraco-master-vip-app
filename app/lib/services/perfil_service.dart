import '../ranking/estado_ranking.dart';
import '../screens/perfil_screen.dart';
import '../sessao/avatar_publico.dart';
import '../sessao/identidade_publica_sessao.dart';

/// Origem dos dados do Perfil (camada de lógica — Claude).
///
/// FASE 1: identidade REAL (sessão canônica) + arquitetura pronta. Como ainda
/// não existe persistência (sem Cloud Firestore, a mesa não grava resultados),
/// os NÚMEROS do perfil chegam AUSENTES — nulos, e não zerados. O que não tem
/// fonte não é desenhado, e é a mesma regra que a Home de produção segue.
///
/// FASE 2: trocar a origem por Firestore (`usuarios/{uid}`) dentro de [carregar],
/// SEM mudar a assinatura nem o visual. O nome já é real desde a Fase 1.
class PerfilService {
  const PerfilService();

  /// true  = mostra os números de exemplo (marketing/screenshots).
  /// false = estado publicável, em que TUDO o que não tem fonte chega ausente.
  ///
  /// DESLIGADO, e é decisão desta OS. Com ele ligado, qualquer pessoa que
  /// instalasse o aplicativo abria o próprio perfil e via nível 24, título
  /// "Rainha da Canastra", Liga Diamante, 342 vitórias, 1.204 partidas, quatro
  /// conquistas desbloqueadas e doze presentes — números que não vieram de lugar
  /// nenhum, apresentados como se fossem dela. Um perfil zerado é feio; um
  /// perfil que mente é pior.
  ///
  /// A chave permanece porque a tela precisa de um jeito de ser vista cheia para
  /// aprovação visual. O que não pode é o aplicativo publicado usá-la.
  static const bool statsDemo = false;

  // O catálogo "tudo travado" que existia aqui foi retirado junto com o resto
  // dos números sem fonte. Ele parecia inofensivo — oito troféus apagados —,
  // mas afirmava que a pessoa não desbloqueou nenhum, e quem sabe isso é o
  // backend de recompensas (`RecompensaConcessao`), que o cliente ainda não lê.
  // A Fase 2 traz o catálogo com o `desbloqueada` de verdade; até lá a seção
  // não é desenhada.

  static const List<Conquista> _catalogoDemo = [
    Conquista(id: 'primeiro_lugar', label: '1º lugar', icone: 'assets/perfil/conquista_1_lugar.webp', desbloqueada: true),
    Conquista(id: 'sequencia_10', label: 'Sequência 10', icone: 'assets/perfil/conquista_sequencia_10.webp', desbloqueada: true),
    Conquista(id: 'cem_canastras', label: '100 canastras', icone: 'assets/perfil/conquista_100_canastras.webp', desbloqueada: true),
    Conquista(id: 'diamante', label: 'Chegou ao Diamante', icone: 'assets/perfil/conquista_diamante.webp', desbloqueada: true),
    Conquista(id: 'campeao', label: 'Campeão', icone: 'assets/perfil/conquista_campeao.webp', desbloqueada: false),
    Conquista(id: 'imortal', label: 'Imortal', icone: 'assets/perfil/conquista_imortal.webp', desbloqueada: false),
    Conquista(id: 'lenda', label: 'Lenda', icone: 'assets/perfil/conquista_lenda.webp', desbloqueada: false),
    Conquista(id: 'perfeito', label: 'Perfeito', icone: 'assets/perfil/conquista_perfeito.webp', desbloqueada: false),
  ];

  /// Vitrine equipada (Fase 3 = inventário real). Por ora, os itens padrão.
  static const List<ItemVitrine> _vitrinePadrao = [
    ItemVitrine(slot: 'avatar', nome: 'Avatar', icone: 'assets/perfil/vitrine_avatar.webp'),
    ItemVitrine(slot: 'moldura', nome: 'Moldura', icone: 'assets/perfil/vitrine_moldura.webp'),
    ItemVitrine(slot: 'mascote', nome: 'Mascote', icone: 'assets/perfil/vitrine_mascote.webp'),
    ItemVitrine(slot: 'dorso', nome: 'Dorso', icone: 'assets/perfil/vitrine_dorso.webp'),
    ItemVitrine(slot: 'efeito', nome: 'Efeito', icone: 'assets/perfil/vitrine_efeito.webp'),
  ];

  static const List<Presente> _presentesDemo = [
    Presente(id: 'rosa', nome: 'Rosa', icone: 'assets/perfil/presente_rosa.webp', quantidade: 5),
    Presente(id: 'bombom', nome: 'Bombom', icone: 'assets/perfil/presente_bombom.webp', quantidade: 3),
    Presente(id: 'champanhe', nome: 'Champanhe', icone: 'assets/perfil/presente_champanhe.webp', quantidade: 2),
    Presente(id: 'diamante', nome: 'Diamante', icone: 'assets/perfil/presente_diamante.webp', quantidade: 2),
  ];

  /// Rótulo de apresentação para quem ainda não tem apelido escolhido.
  ///
  /// ANTES ISTO LIA `FirebaseAuth.instance.currentUser?.displayName`. Funcionava,
  /// e mesmo assim era uma segunda fonte de nome: o `displayName` do Google e o
  /// apelido de `publicProfiles` são autoridades diferentes, e na troca de conta
  /// elas se atualizam em momentos diferentes — o perfil do jogador novo abriria
  /// com o nome do anterior até o SDK acompanhar.
  ///
  /// 'Jogador(a)' é um RÓTULO, não um nome: ninguém consegue buscar por ele e
  /// ele não é gravado em lugar nenhum. Fallback de apresentação não é fallback
  /// de identidade.
  static const String _rotuloSemApelido = 'Jogador(a)';

  /// Carrega o perfil. FASE 2: substituir o corpo por leitura no Firestore.
  ///
  /// [identidade] é a identidade pública CANÔNICA da sessão, entregue por quem
  /// chama (o [PerfilPage] a lê do `EscopoSessao`). Este serviço não a busca: se
  /// buscasse, o Perfil viraria um segundo lugar que obtém identidade, e §12
  /// existe justamente para que só haja um.
  ///
  /// O apelido de `publicProfiles` GANHA do `displayName` do Google, porque é o
  /// nome que os outros jogadores veem — é a autoridade sobre como este jogador
  /// se chama dentro do jogo.
  Future<PerfilVM> carregar({
    bool ehMeuPerfil = true,
    IdentidadePublica? identidade,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350)); // simula I/O (Fase 2: await Firestore)
    final apelido = identidade?.apelido.trim() ?? '';
    // Sem apelido escolhido, o `publicId` é o que os outros jogadores veem —
    // ele É o identificador público, e exibi-lo não vaza nada. O rótulo genérico
    // fica para quando não há identidade nenhuma.
    final publico = identidade?.publicId ?? '';
    return _montar(
      ehMeuPerfil: ehMeuPerfil,
      nome: apelido.isNotEmpty
          ? apelido
          : (publico.isNotEmpty ? publico : _rotuloSemApelido),
      // O avatar segue a MESMA autoridade que o nome: o que veio de
      // `publicProfiles` dentro da identidade canônica. Antes desta linha o
      // serviço escrevia `avatar: '👑'` fixo — o apelido real ao lado de uma
      // coroa que ignorava o avatar escolhido.
      avatar: avatarPublicoDaIdentidade(identidade),
      demo: statsDemo,
    );
  }

  /// VM mínimo para o estado "carregando" (a tela mostra skeleton; nada é exibido).
  ///
  /// O ranking aqui é [FaseRanking.carregando], e não `indisponivel`: são
  /// estados diferentes, e este VM existe justamente durante a consulta.
  /// O avatar do placeholder é o FALLBACK, e não um avatar inventado: durante a
  /// carga não há identidade resolvida para consultar. Quem já tem identidade
  /// não fica preso a ele — o [PerfilPage] reaplica a resolução canônica a cada
  /// `build`, com o estado vivo da sessão.
  PerfilVM vmPlaceholder() => _montar(
    ehMeuPerfil: true,
    nome: '…',
    avatar: avatarPublicoDaIdentidade(null),
    demo: false,
    ranking: const EstadoRanking.carregando(),
  );

  PerfilVM _montar({required bool ehMeuPerfil, required String nome, required String avatar, required bool demo, EstadoRanking? ranking}) {
    return PerfilVM(
      ehMeuPerfil: ehMeuPerfil,
      nome: nome,
      avatar: avatar,
      mascote: '🦊',
      moldura: 'assets/perfil/vitrine_moldura.webp',
      dorso: 'assets/perfil/vitrine_dorso.webp',
      efeito: 'assets/perfil/vitrine_efeito.webp',
      // NULO É A RESPOSTA CERTA AQUI, e não o zero.
      //
      // O caminho não-demo escrevia nível 1, XP 0/1000 e título 'Novato(a)'.
      // Nenhum desses números veio de lugar nenhum: não existe sistema de XP e
      // título é concedido, não presumido. Com nulo, a tela não desenha o
      // elemento; quando a FASE 2 trouxer Firestore, é aqui que os valores
      // passam a chegar, e a tela volta a mostrá-los sem precisar mudar.
      nivel: demo ? 24 : null,
      xpAtual: demo ? 3240 : null,
      xpProximo: demo ? 5000 : null,
      titulo: demo ? 'Rainha da Canastra' : null,
      tituloEmoji: demo ? '👑' : null,
      // AQUI NASCIA O DEFEITO: `liga: demo ? 'Diamante' : 'Bronze'` e
      // `posicaoMundial: demo ? 128 : 0`. Com a chave de demonstração desligada
      // — que é o estado publicável — todo jogador recebia Liga Bronze e
      // colocação zero, e a tela desenhava os dois. Não vinham de lugar nenhum:
      // eram o valor que os tipos `String` e `int` exigiam de um produtor que
      // não tinha o dado.
      //
      // Com a chave LIGADA, liga e colocação continuam sendo afirmadas, porque
      // aí são fixture declarada de prévia. Desligada, o Perfil lê a MESMA
      // constante que a Home: não há autoridade de ranking nesta casca.
      ranking: ranking ??
          (demo
              ? const EstadoRanking.disponivel(liga: 'Diamante', posicaoMundial: 128)
              : rankingDaCascaPublicavel),
      // Quatro zeros não são "o placar de quem ainda não jogou": são um placar
      // sem placar nenhum atrás. Nada grava resultado de partida no cliente.
      stats: demo
          ? const PerfilStats(vitorias: 342, partidas: 1204, canastras: 89, aproveitamento: 68)
          : null,
      ultimaConquista: demo
          ? const UltimaConquista(
              titulo: 'Primeira Batida Real',
              subtitulo: 'Marco de Jornada · Comum Especial · desbloqueada hoje',
              imagem: 'assets/perfil/ultima_conquista.webp',
              raridade: 'Comum Especial',
            )
          : null,
      presentesCount: demo ? 12 : null,
      // NULO, e não `const []`: nulo diz "não perguntei a ninguém", e a lista
      // vazia diria "perguntei e a resposta foi nenhuma". Só a segunda autoriza
      // o recado "ainda sem conquistas" — e ninguém perguntou nada.
      conquistas: demo ? _catalogoDemo : null,
      vitrine: _vitrinePadrao,
      presentes: demo ? _presentesDemo : const [],
    );
  }
}
