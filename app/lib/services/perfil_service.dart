import 'package:firebase_auth/firebase_auth.dart';

import '../screens/perfil_screen.dart';
import '../sessao/identidade_publica_sessao.dart';

/// O perfil pedido não pôde ser carregado por falta de fonte (jogador de fora,
/// perfil removido, ou origem ainda não publicada).
class PerfilIndisponivel implements Exception {
  /// Texto curto, já em português e exibível ao jogador.
  final String motivo;

  const PerfilIndisponivel(this.motivo);

  @override
  String toString() => 'PerfilIndisponivel: $motivo';
}

/// Origem dos dados do Perfil (camada de lógica — Claude).
///
/// FASE 1: identidade REAL (Firebase Auth) + arquitetura pronta. Como ainda não
/// existe persistência (sem Cloud Firestore, a mesa não grava resultados), os
/// NÚMEROS do perfil são de demonstração enquanto [statsDemo] = true — assim a
/// tela aprovada continua cheia. Vire para false quando quiser o estado honesto
/// de jogador novo (zerado).
///
/// FASE 2: trocar a origem por Firestore (`usuarios/{uid}`) dentro de [carregar],
/// SEM mudar a assinatura nem o visual. O nome já é real desde a Fase 1.
class PerfilService {
  const PerfilService();

  /// true  = mostra os números de exemplo aprovados (marketing/screenshots).
  /// false = estado real de jogador novo (nível 1, stats 0, conquistas travadas).
  ///
  /// DESLIGADO para a build de produção. Com `true`, o Perfil montava números
  /// inventados (nível, vitórias, canastras, conquistas desbloqueadas) ao lado
  /// do nome e da foto REAIS vindos do Firebase Auth — ou seja, o app afirmava
  /// ao jogador um histórico que ele não tem. É exatamente o que a política de
  /// *Misrepresentation* da Play trata, e não é uma questão de estilo: o dado
  /// era apresentado como sendo dele.
  ///
  /// Com `false` a mesma tela mostra o estado honesto de jogador novo — a
  /// própria classe já foi escrita para os dois casos ([_catalogoTravado] e
  /// [_catalogoDemo]), então nada de visual muda de forma; muda o conteúdo.
  ///
  /// Quando a Fase 2 ligar a leitura no Firestore dentro de [carregar], esta
  /// constante deixa de ter função e sai junto.
  static const bool statsDemo = false;

  /// Catálogo fixo de conquistas do jogo (definições). O `desbloqueada` real virá
  /// dos dados na Fase 2. Aqui, tudo travado (jogador novo).
  static const List<Conquista> _catalogoTravado = [
    Conquista(id: 'primeiro_lugar', label: '1º lugar', icone: 'assets/perfil/conquista_1_lugar.webp', desbloqueada: false),
    Conquista(id: 'sequencia_10', label: 'Sequência 10', icone: 'assets/perfil/conquista_sequencia_10.webp', desbloqueada: false),
    Conquista(id: 'cem_canastras', label: '100 canastras', icone: 'assets/perfil/conquista_100_canastras.webp', desbloqueada: false),
    Conquista(id: 'diamante', label: 'Chegou ao Diamante', icone: 'assets/perfil/conquista_diamante.webp', desbloqueada: false),
    Conquista(id: 'campeao', label: 'Campeão', icone: 'assets/perfil/conquista_campeao.webp', desbloqueada: false),
    Conquista(id: 'imortal', label: 'Imortal', icone: 'assets/perfil/conquista_imortal.webp', desbloqueada: false),
    Conquista(id: 'lenda', label: 'Lenda', icone: 'assets/perfil/conquista_lenda.webp', desbloqueada: false),
    Conquista(id: 'perfeito', label: 'Perfeito', icone: 'assets/perfil/conquista_perfeito.webp', desbloqueada: false),
  ];

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

  /// Nome do Firebase Auth — APRESENTAÇÃO, e só ela.
  ///
  /// Serve de último recurso VISUAL quando o jogador ainda não escolheu apelido.
  /// Não é identidade e não substitui `publicId` em lugar nenhum.
  ///
  /// O `try` cobre o mesmo ambiente que `main()` já cobre: sem Firebase
  /// inicializado (navegador de teste, teste de widget), o perfil abre com o
  /// nome genérico em vez de explodir.
  String _nomeDoAuth() {
    try {
      final n = FirebaseAuth.instance.currentUser?.displayName?.trim();
      if (n != null && n.isNotEmpty) return n;
    } catch (_) {
      // Sem Firebase: segue com o nome genérico.
    }
    return 'Jogador(a)';
  }

  /// UID do jogador autenticado, ou `null` sem Firebase disponível.
  String? uidAtual() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase indisponível (web de teste) — segue sem identidade.
    }
  }

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
  ///
  /// [jogadorId] é o seam aberto pela integração de Ranking/Hall: tocar num
  /// jogador da lista chega aqui com o **identificador público** (UID), nunca
  /// com e-mail. Quando ele aponta para outra pessoa, não há de onde ler — não
  /// existe persistência de perfil de terceiro — e o método falha em vez de
  /// devolver dado inventado. Ligar a fonte real é trocar só este trecho.
  ///
  /// Os dois parâmetros convivem porque respondem a perguntas diferentes:
  /// `identidade` diz COMO este jogador se chama; `jogadorId` diz DE QUEM é o
  /// perfil pedido. O nome canônico só se aplica ao perfil do próprio dono.
  Future<PerfilVM> carregar({
    bool ehMeuPerfil = true,
    IdentidadePublica? identidade,
    String? jogadorId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350)); // simula I/O (Fase 2: await Firestore)

    if (jogadorId != null && jogadorId.isNotEmpty && jogadorId != uidAtual()) {
      throw const PerfilIndisponivel(
        'O perfil deste jogador ainda não está disponível.',
      );
    }

    final apelido = identidade?.apelido.trim() ?? '';
    return _montar(
      ehMeuPerfil: ehMeuPerfil,
      nome: apelido.isNotEmpty ? apelido : _nomeDoAuth(),
      demo: statsDemo,
    );
  }

  /// VM mínimo para o estado "carregando" (a tela mostra skeleton; nada é exibido).
  PerfilVM vmPlaceholder() => _montar(ehMeuPerfil: true, nome: '…', demo: false);

  PerfilVM _montar({required bool ehMeuPerfil, required String nome, required bool demo}) {
    return PerfilVM(
      ehMeuPerfil: ehMeuPerfil,
      nome: nome,
      avatar: '👑',
      mascote: '🦊',
      moldura: 'assets/perfil/vitrine_moldura.webp',
      dorso: 'assets/perfil/vitrine_dorso.webp',
      efeito: 'assets/perfil/vitrine_efeito.webp',
      nivel: demo ? 24 : 1,
      xpAtual: demo ? 3240 : 0,
      xpProximo: demo ? 5000 : 1000,
      titulo: demo ? 'Rainha da Canastra' : 'Novato(a)',
      tituloEmoji: demo ? '👑' : '🃏',
      liga: demo ? 'Diamante' : 'Bronze',
      posicaoMundial: demo ? 128 : 0,
      stats: demo
          ? const PerfilStats(vitorias: 342, partidas: 1204, canastras: 89, aproveitamento: 68)
          : const PerfilStats(vitorias: 0, partidas: 0, canastras: 0, aproveitamento: 0),
      ultimaConquista: demo
          ? const UltimaConquista(
              titulo: 'Primeira Batida Real',
              subtitulo: 'Marco de Jornada · Comum Especial · desbloqueada hoje',
              imagem: 'assets/perfil/ultima_conquista.webp',
              raridade: 'Comum Especial',
            )
          : null,
      presentesCount: demo ? 12 : 0,
      conquistas: demo ? _catalogoDemo : _catalogoTravado,
      vitrine: _vitrinePadrao,
      presentes: demo ? _presentesDemo : const [],
    );
  }
}
