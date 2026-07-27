import 'package:firebase_auth/firebase_auth.dart';

import '../screens/perfil_screen.dart';

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
  static const bool statsDemo = true;

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

  String _nomeReal() {
    final u = FirebaseAuth.instance.currentUser;
    final n = u?.displayName?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Jogador(a)';
  }

  /// Carrega o perfil. FASE 2: substituir o corpo por leitura no Firestore.
  Future<PerfilVM> carregar({bool ehMeuPerfil = true}) async {
    await Future.delayed(const Duration(milliseconds: 350)); // simula I/O (Fase 2: await Firestore)
    return _montar(ehMeuPerfil: ehMeuPerfil, nome: _nomeReal(), demo: statsDemo);
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
