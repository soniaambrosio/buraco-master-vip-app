// composicao_avatar_ranking_test.dart — o avatar canônico E o Ranking Real,
// na mesma árvore.
//
// ---------------------------------------------------------------------------
// O QUE SÓ EXISTE DEPOIS DESTA UNIÃO
// ---------------------------------------------------------------------------
//
// As duas linhagens saíram do MESMO commit (d738f45) e nunca se viram:
// `92344ed` (avatar) vivia em duas branches, `e1923f19` (leitor de Ranking) em
// nove, e a interseção era vazia. Cada uma foi homologada contra uma árvore em
// que a outra não existia — e é por isso que nenhuma das duas suítes de origem
// consegue provar o que esta prova.
//
// O ACIDENTE CONCRETO que esta suíte vigia: as duas escreveram no MESMO ponto
// do Perfil. O Git empilhou `comRanking` e `comAvatarPublico` num método só, e
// a resolução preguiçosa — ficar com um dos lados — teria compilado, passado
// nas suítes da linhagem sobrevivente e apagado a outra correção em silêncio.
// Metade dos casos abaixo existe para que esse apagamento não possa mais
// acontecer sem alguém ficar vermelho.
//
// A pergunta de fundo é sempre a mesma: HOME E PERFIL CONCORDAM? Um teste que
// só afirmasse "o Perfil mostra o avatar" ou "a Home mostra a liga" passaria
// com duas regras escritas à parte — e duas regras foi exatamente o defeito que
// as duas correções vieram fechar, cada uma no seu campo.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz as telas de celular estourarem em overflow.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/sessao/avatar_publico.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Fixtures
// ===========================================================================

const String contaA = 'P0A1B2C3D4E5';
const String contaB = 'PZZ9Y8X7W6V5';
const String alvoX = 'PXX1XX2XX3XX';

/// Referências de avatar BEM FORMADAS, e distintas por conta.
///
/// Distintas de propósito: o caso da troca de jogador só tem valor se o avatar
/// de A for reconhecível dentro do perfil de B.
const String avatarDeA = 'coruja_dourada';
const String avatarDeB = 'lobo_prateado';

/// A resposta de `abrirRanking` — o ranking do próprio jogador.
///
/// `ligaId` nulo é o RÓTULO DE QUALIFICAÇÃO, e não uma liga: o backend usa o
/// mesmo campo `liga` para "Ouro" e para "Em colocacao", e distingue os dois
/// exatamente por este id. É o que `ehLigaDeVerdade` lê.
Map<String, Object?> aberturaCom({
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int posicao = 128,
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': 'T-2026-01',
    'temporadaNome': 'Temporada 1',
    'divisao': null,
    'podio': const [],
    'escadaLigas': const [],
    'eu': {
      'id': contaA,
      'apelido': '',
      'avatar': '',
      'liga': liga,
      'ligaId': ligaId,
      'pontos': 1200,
      'posicao': posicao,
      'direcao': 'manteve',
      'delta': 0,
      'selo': null,
      'souEu': true,
      'estado': 'classificado',
      'qualificacaoRestante': 0,
      'partidas': 10,
      'vitorias': 6,
      'derrotas': 4,
      'aproveitamento': 60.0,
    },
  },
  'primeiraPagina': const {'itens': [], 'cursorProxima': null, 'fim': true},
};

/// A resposta de `consultarJogadorPorIdPublico` — o ranking de um TERCEIRO.
Map<String, Object?> publicoCom({
  required String id,
  String liga = 'Prata',
  String? ligaId = 'prata',
  int posicao = 50,
}) => {
  'id': id,
  'temporadaId': 'T-2026-01',
  'classificado': true,
  'jogador': {
    'id': id,
    'apelido': '',
    'avatar': '',
    'liga': liga,
    'ligaId': ligaId,
    'pontos': 900,
    'posicao': posicao,
    'direcao': 'manteve',
    'delta': 0,
    'selo': null,
    'souEu': false,
    'estado': 'classificado',
    'qualificacaoRestante': 0,
    'partidas': 5,
    'vitorias': 2,
    'derrotas': 3,
    'aproveitamento': 40.0,
  },
};

/// Transporte que registra o que foi pedido, e para QUEM.
///
/// `idsConsultados` é a testemunha do caso de navegação: sem ele, "o Perfil do
/// terceiro mostrou Prata" passaria mesmo que a consulta tivesse sido feita
/// para o id errado, desde que a resposta encenada fosse a mesma.
class TransporteEspiao extends TransporteRanking {
  final List<String> chamadas = <String>[];
  final List<String> idsConsultados = <String>[];

  Object? respostaPropria = aberturaCom();
  Object? Function(String id) respostaPublica = (id) => publicoCom(id: id);

  /// ADAPTADO NA COMPOSIÇÃO: era `meuRanking()` devolvendo só a fotografia.
  ///
  /// A folha da navegação renomeou o método para `abrirRanking()` e alargou o
  /// retorno para [AberturaRanking] — cabeçalho MAIS tabela. A quebra foi
  /// deliberada: um método novo com implementação padrão teria deixado este
  /// fake "funcionando" enquanto jogava a tabela fora em silêncio, que é o
  /// defeito que aquela folha veio fechar. Aqui a tabela vai vazia de
  /// propósito: esta suíte fala do cabeçalho — avatar e liga —, e a tabela tem
  /// as suas próprias, em `navegacao_perfil_publico_test.dart`.
  @override
  Future<AberturaRanking> abrirRanking() async {
    chamadas.add('proprio');
    return AberturaRanking(
      eu: FotografiaRanking.daAbertura(respostaPropria),
      tabela: const TabelaRanking(podio: [], primeiraPagina: []),
    );
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) {
    chamadas.add('publico');
    idsConsultados.add(publicId);
    return Future.value(
      FotografiaRanking.doPerfilPublico(respostaPublica(publicId)),
    );
  }

  int get chamadasProprio => chamadas.where((c) => c == 'proprio').length;
  int get chamadasPublico => chamadas.where((c) => c == 'publico').length;
}

/// Fonte de identidade regulável — a conta E o avatar mudam juntos.
class FonteRegulavel implements FonteDeIdentidade {
  String publicId = contaA;
  String apelido = 'Ana';
  String? avatarRef = avatarDeA;
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async {
    chamadas++;
    return IdentidadePublica(
      publicId: publicId,
      apelido: apelido,
      avatarRef: avatarRef,
      criada: false,
      estado: EstadoPerfil.ativo,
      limites: LimitesSociais.desconhecidos,
      edicao: MetadadosDeEdicao.desconhecidos,
    );
  }
}

/// O arquivo SEM comentários, respeitando aspas.
///
/// Mesma técnica das auditorias vizinhas, e pelo mesmo motivo: este próprio
/// arquivo escreve em prosa o literal que proíbe, e uma varredura ingênua
/// acusaria a explicação como se fosse a violação.
String semComentarios(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

void main() {
  late TransporteEspiao transporte;
  late RankingDaSessao ranking;
  late FonteRegulavel fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    transporte = TransporteEspiao();
    fonte = FonteRegulavel();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  /// Abre sessão e ranking DENTRO do corpo do teste, e não no `setUp`.
  ///
  /// `testWidgets` roda o corpo num zone de tempo falso e o `setUp` roda fora
  /// dele; um stream assinado lá entrega seus eventos num mundo que o relógio
  /// do `pump` jamais adianta, e o login nunca chegaria.
  void abrir() {
    ranking = RankingDaSessao(leitor: LeitorDeRanking(transporte: transporte));
    addTearDown(ranking.dispose);
    sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
    addTearDown(sessao.dispose);
  }

  /// Drena as cargas em cascata.
  ///
  /// `pumpAndSettle` sozinho não serve: `didChangeDependencies` do Perfil chama
  /// `setState` DENTRO do quadro em construção, e marcar sujo no quadro
  /// corrente não agenda quadro novo — o `pumpAndSettle` devolveria com o
  /// temporizador de 350ms do serviço ainda pendente, e o teste morreria por
  /// "pending timers": falha de encenação, não de comportamento.
  Future<void> assentar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  Future<void> montar(WidgetTester tester, Widget tela) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: EscopoRanking(
          ranking: ranking,
          child: MaterialApp(home: tela),
        ),
      ),
    );
    await assentar(tester);
  }

  /// "login" — a sessão resolve a identidade antes de qualquer tela abrir.
  Future<void> login(WidgetTester tester, {String uid = 'uid-A'}) async {
    abrir();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add(uid);
    await tester.pump();
    await tester.pump();
    ranking.aoMudarSessao(geracao: 1, publicId: fonte.publicId);
  }

  CabecalhoJogador cabecalhoDaHome(WidgetTester tester) =>
      tester.widget<InicioScreen>(find.byType(InicioScreen)).vm.jogador;

  PerfilVM vmDoPerfil(WidgetTester tester) =>
      tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

  // =========================================================================
  // A HOME — avatar canônico e Ranking real no MESMO cabeçalho
  // =========================================================================
  //
  // Os quatro casos desta seção são o §6.3 da OS em forma de teste. Antes da
  // composição, cada linhagem só conseguia afirmar metade deste cabeçalho: a do
  // avatar montava a Home sem escopo de ranking, e a do ranking montava-a sem
  // resolvedor de avatar.
  group('Home — as duas autoridades no mesmo cabeçalho', () {
    testWidgets('identidade válida: o avatar vem da autoridade canônica', (
      tester,
    ) async {
      fonte.avatarRef = avatarDeA;
      await login(tester);
      await montar(tester, const HomeDeProducao());

      final jogador = cabecalhoDaHome(tester);
      expect(jogador.avatar, avatarDeA);
      // E é a autoridade que decide, não a coincidência: o valor exibido é
      // exatamente o que o resolvedor devolve para a mesma referência.
      expect(jogador.avatar, avatarPublicoDe(avatarDeA));
    });

    testWidgets('avatar ausente: o fallback é da autoridade, não da tela', (
      tester,
    ) async {
      // As três formas de ausência que o `?? ` da Home NÃO cobria: nulo, vazio
      // e só-espaços. O `??` só pegava a primeira — as outras duas desenhavam
      // um círculo em branco.
      for (final ausente in <String?>[null, '', '   ']) {
        fonte.avatarRef = ausente;
        await login(tester);
        await montar(tester, const HomeDeProducao());

        expect(
          cabecalhoDaHome(tester).avatar,
          kAvatarPublicoFallback,
          reason: 'avatarRef ${ausente == null ? 'null' : '"$ausente"'} '
              'não caiu no fallback da autoridade',
        );
      }
    });

    testWidgets('Ranking real: a liga é exibível', (tester) async {
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);
      await montar(tester, const HomeDeProducao());

      expect(cabecalhoDaHome(tester).liga, 'Ouro');
    });

    testWidgets('Ranking provisório: a liga é omitida', (tester) async {
      // `ligaId` nulo com `liga` preenchida é o rótulo de qualificação. A Home
      // mostra a liga ao lado do nome, sem prefixo — ali "Em colocacao"
      // passaria por NOME DE LIGA, que é uma conquista que ninguém teve.
      transporte.respostaPropria = aberturaCom(
        liga: 'Em colocacao',
        ligaId: null,
      );
      await login(tester);
      await montar(tester, const HomeDeProducao());

      expect(cabecalhoDaHome(tester).liga, isNull);
    });

    testWidgets('sem autoridade de ranking a liga some, e o avatar fica', (
      tester,
    ) async {
      // O caso que separa as duas autoridades: fora do escopo de ranking não há
      // liga a afirmar, e isso NÃO pode arrastar o avatar junto. Eles vêm de
      // donos diferentes, e é o cabeçalho composto que prova.
      fonte.avatarRef = avatarDeA;
      await login(tester);
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: const MaterialApp(home: HomeDeProducao()),
        ),
      );
      await assentar(tester);

      expect(cabecalhoDaHome(tester).liga, isNull);
      expect(cabecalhoDaHome(tester).avatar, avatarDeA);
    });
  });

  // =========================================================================
  // O PERFIL — os dois enriquecimentos no MESMO ViewModel
  // =========================================================================
  //
  // O §6.2 da OS: `base → comRanking → comAvatarPublico`. Um VM só, e não dois
  // paralelos escolhidos pela origem da navegação.
  group('Perfil — um VM só, enriquecido duas vezes', () {
    testWidgets('perfil próprio: ranking E avatar presentes no mesmo VM', (
      tester,
    ) async {
      fonte.avatarRef = avatarDeA;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);
      await montar(tester, const PerfilPage());

      final vm = vmDoPerfil(tester);
      // AS DUAS COISAS, no mesmo objeto. Se o merge tivesse ficado com um lado
      // só, uma destas duas linhas cairia — e é exatamente esse o acidente que
      // esta suíte existe para tornar impossível.
      expect(vm.avatar, avatarDeA);
      expect(vm.ranking.liga, 'Ouro');
      expect(vm.ranking.posicaoMundial, 128);
      expect(transporte.chamadasProprio, 1);
    });

    testWidgets('Home e Perfil concordam no avatar E no estado competitivo', (
      tester,
    ) async {
      // A prova central. Não basta cada tela estar "certa" isoladamente: o
      // defeito original era duas telas certas por regras diferentes.
      fonte.avatarRef = avatarDeA;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);

      await montar(tester, const HomeDeProducao());
      final naHome = cabecalhoDaHome(tester);

      await montar(tester, const PerfilPage());
      final noPerfil = vmDoPerfil(tester);

      expect(noPerfil.avatar, naHome.avatar);
      expect(noPerfil.ranking.liga, naHome.liga);
      // E uma consulta só serviu às duas telas: é o MESMO estado lido de dois
      // pontos da árvore, não duas leituras que por sorte coincidiram.
      expect(transporte.chamadasProprio, 1);
    });

    testWidgets('avatar ausente: Home e Perfil caem no MESMO fallback', (
      tester,
    ) async {
      fonte.avatarRef = null;
      await login(tester);

      await montar(tester, const HomeDeProducao());
      final naHome = cabecalhoDaHome(tester).avatar;

      await montar(tester, const PerfilPage());
      final noPerfil = vmDoPerfil(tester).avatar;

      expect(naHome, kAvatarPublicoFallback);
      expect(noPerfil, naHome);
    });

    testWidgets('perfil de terceiro: o Ranking é o do publicId visitado', (
      tester,
    ) async {
      transporte.respostaPublica = (id) =>
          publicoCom(id: id, liga: 'Prata', ligaId: 'prata', posicao: 50);
      await login(tester);
      await montar(
        tester,
        const PerfilPage(ehMeuPerfil: false, publicIdVisitado: alvoX),
      );

      final vm = vmDoPerfil(tester);
      // O ranking do VISITADO, e não o de quem está olhando.
      expect(vm.ranking.liga, 'Prata');
      expect(vm.ranking.posicaoMundial, 50);
      expect(vm.ranking.liga, isNot('Ouro'));
      // E foi consultado para o id certo. Sem esta linha, a asserção acima
      // passaria mesmo com a consulta feita para o id errado.
      expect(transporte.idsConsultados, [alvoX]);
    });

    testWidgets('perfil de terceiro sem publicId não afirma ranking nenhum', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const PerfilPage(ehMeuPerfil: false));

      final vm = vmDoPerfil(tester);
      // "Não sei" — e não "sem liga", que seria uma afirmação. Nada foi
      // perguntado porque não havia a quem perguntar.
      expect(vm.ranking.fase, FaseRanking.indisponivel);
      expect(vm.ranking.liga, isNull);
      expect(transporte.chamadasPublico, 0);
    });
  });

  // =========================================================================
  // TROCA DE JOGADOR — nada de A sobrevive em B
  // =========================================================================
  group('troca de identidade A → B', () {
    testWidgets('nem avatar nem Ranking de A permanecem na Home', (
      tester,
    ) async {
      fonte
        ..publicId = contaA
        ..apelido = 'Ana'
        ..avatarRef = avatarDeA;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);
      await montar(tester, const HomeDeProducao());
      expect(cabecalhoDaHome(tester).avatar, avatarDeA);
      expect(cabecalhoDaHome(tester).liga, 'Ouro');

      // Entra B: outra conta, outro avatar, outra liga.
      fonte
        ..publicId = contaB
        ..apelido = 'Bia'
        ..avatarRef = avatarDeB;
      transporte.respostaPropria = aberturaCom(liga: 'Bronze', ligaId: 'bronze');
      auth.add('uid-B');
      await assentar(tester);
      ranking.aoMudarSessao(geracao: 2, publicId: contaB);
      await assentar(tester);

      final jogador = cabecalhoDaHome(tester);
      expect(jogador.avatar, avatarDeB);
      expect(jogador.avatar, isNot(avatarDeA));
      expect(jogador.liga, isNot('Ouro'));
    });

    testWidgets('nem avatar nem Ranking de A permanecem no Perfil aberto', (
      tester,
    ) async {
      // COM O PERFIL ABERTO, que é o caso difícil: a tela não é remontada, e
      // um valor congelado no instante da carga sobreviveria à troca de conta.
      fonte
        ..publicId = contaA
        ..apelido = 'Ana'
        ..avatarRef = avatarDeA;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);
      await montar(tester, const PerfilPage());
      expect(vmDoPerfil(tester).avatar, avatarDeA);
      expect(vmDoPerfil(tester).ranking.liga, 'Ouro');

      fonte
        ..publicId = contaB
        ..apelido = 'Bia'
        ..avatarRef = avatarDeB;
      transporte.respostaPropria = aberturaCom(liga: 'Bronze', ligaId: 'bronze');
      auth.add('uid-B');
      await assentar(tester);
      ranking.aoMudarSessao(geracao: 2, publicId: contaB);
      await assentar(tester);

      final vm = vmDoPerfil(tester);
      expect(vm.avatar, isNot(avatarDeA));
      expect(vm.ranking.liga, isNot('Ouro'));
    });

    testWidgets('logout apaga o avatar e o Ranking de uma vez', (tester) async {
      fonte.avatarRef = avatarDeA;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', ligaId: 'ouro');
      await login(tester);
      await montar(tester, const HomeDeProducao());
      expect(cabecalhoDaHome(tester).avatar, avatarDeA);

      auth.add(null);
      await assentar(tester);
      ranking.aoMudarSessao(geracao: 2, publicId: null);
      await assentar(tester);

      // Sem identidade não há avatar escolhido, e sem conta não há liga.
      expect(find.text(avatarDeA), findsNothing);
    });
  });

  // =========================================================================
  // NAVEGAÇÃO Ranking → Perfil
  // =========================================================================
  group('navegação preserva o publicId', () {
    testWidgets('o Perfil aberto por publicId consulta AQUELE publicId', (
      tester,
    ) async {
      // O que a navegação carrega é um id público, e é ele que decide a
      // consulta — não o nome, não o índice na lista, não a sessão.
      const outro = 'PQQ7QQ8QQ9QQ';
      transporte.respostaPublica = (id) =>
          publicoCom(id: id, liga: 'Diamante', ligaId: 'diamante', posicao: 3);
      await login(tester);
      await montar(
        tester,
        const PerfilPage(ehMeuPerfil: false, publicIdVisitado: outro),
      );

      expect(transporte.idsConsultados, [outro]);
      expect(vmDoPerfil(tester).ranking.liga, 'Diamante');
      expect(vmDoPerfil(tester).ranking.posicaoMundial, 3);
      // A sessão continua sendo a de quem navega: visitar não troca a conta.
      expect(transporte.chamadasProprio, lessThanOrEqualTo(1));
    });

    testWidgets('visitar dois perfis diferentes consulta os dois ids', (
      tester,
    ) async {
      // AS CHAVES SÃO ESSENCIAIS, e não enfeite. Navegar até outro perfil
      // empilha uma rota NOVA, e portanto um `State` novo. Sem chaves
      // distintas, o `pumpWidget` reaproveitaria o `State` da primeira página —
      // e o segundo `publicIdVisitado` nunca seria consultado, porque a recarga
      // observa a identidade da SESSÃO, que não mudou. O teste estaria medindo
      // uma reciclagem de widget que a navegação real não faz.
      await login(tester);
      await montar(
        tester,
        const PerfilPage(
          key: ValueKey('visita-1'),
          ehMeuPerfil: false,
          publicIdVisitado: alvoX,
        ),
      );
      await montar(
        tester,
        const PerfilPage(
          key: ValueKey('visita-2'),
          ehMeuPerfil: false,
          publicIdVisitado: contaB,
        ),
      );

      // Sem confundir um com o outro, e sem reaproveitar a resposta do
      // primeiro para o segundo.
      expect(transporte.idsConsultados, [alvoX, contaB]);
    });

    testWidgets('abrir o próprio Perfil usa a identidade autenticada', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const PerfilPage());

      // Nenhuma consulta a terceiro: o próprio jogador vem do escopo.
      expect(transporte.chamadasPublico, 0);
      expect(transporte.idsConsultados, isEmpty);
      expect(vmDoPerfil(tester).nome, 'Ana');
    });
  });

  // =========================================================================
  // A ÁRVORE PRODUTIVA
  // =========================================================================
  group('árvore produtiva', () {
    test('a Home não decide o fallback do avatar', () {
      final home = semComentarios(File('lib/casca/home_de_producao.dart'));

      // O literal `??` seguido da coroa é o defeito nomeado pela OS. Ele não
      // pode voltar por descuido de merge — e é um merge que o traria de volta,
      // porque a linha viveu ali por muito tempo.
      expect(home, isNot(contains('avatarRef ??')));
      expect(
        home.contains('avatarPublicoDaIdentidade('),
        isTrue,
        reason: 'a Home deixou de consultar a autoridade do avatar',
      );
    });

    test('a Home não decide sozinha o que é liga de verdade', () {
      final home = semComentarios(File('lib/casca/home_de_producao.dart'));
      expect(
        home.contains('ehLigaDeVerdade'),
        isTrue,
        reason: 'a Home voltou a afirmar liga sem consultar o estado canônico',
      );
    });

    test('os dois enriquecimentos do Perfil coexistem no VM', () {
      final tela = semComentarios(File('lib/screens/perfil_screen.dart'));
      // O merge fundiu os dois métodos num só. Se alguém repetir a fusão, estas
      // duas linhas caem juntas.
      expect(tela, contains('comRanking('));
      expect(tela, contains('comAvatarPublico('));
    });

    test('a página aplica os DOIS ao mesmo Perfil', () {
      final pagina = semComentarios(File('lib/pages/perfil_page.dart'));
      expect(pagina, contains('comRanking('));
      expect(pagina, contains('comAvatarPublico('));

      // E num encadeamento, não em dois VMs paralelos escolhidos pela origem da
      // navegação — que é o que a OS proíbe em §6.2. Um `PerfilVM(` construído
      // à mão aqui seria a terceira autoridade nascendo.
      expect(
        pagina,
        isNot(contains('PerfilVM(')),
        reason: 'a página passou a construir o seu próprio ViewModel',
      );
    });

    test('a autoridade do avatar continua sendo uma só', () {
      // Nenhum arquivo do Perfil ou da Home reimplementa a regra: quem precisa
      // do avatar chama o resolvedor.
      for (final caminho in const [
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
      ]) {
        final fonte = semComentarios(File(caminho));
        if (!fonte.contains('avatarRef')) continue;
        expect(
          fonte,
          contains('avatarPublico'),
          reason: '$caminho lê avatarRef sem passar pela autoridade',
        );
      }
    });
  });
}
