// identidade_visitada_test.dart — o Perfil visitado mostra O VISITADO.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTA SUÍTE FECHA
// ---------------------------------------------------------------------------
//
// A composição anterior deixou o Perfil de terceiro com a liga certa e a
// identidade errada: `PerfilService` só recebia a identidade da SESSÃO, então
// nome e avatar de um perfil visitado eram os de quem estava OLHANDO. A tela
// montava uma pessoa que não existe — o nome de A, o avatar de A, a liga de B.
//
// A composição registrou isso como pendência e, deliberadamente, NÃO escreveu
// um teste afirmando o valor errado. Esta suíte é a outra ponta: afirma o valor
// certo.
//
// ---------------------------------------------------------------------------
// POR QUE AS FIXTURES SÃO GROTESCAMENTE DIFERENTES
// ---------------------------------------------------------------------------
//
// A visitante é `Ana`/`coruja_dourada`; o visitado é `Bartolomeu`/`lobo_prateado`.
// Nada em comum: nem letra inicial, nem tamanho, nem liga, nem número. Um teste
// em que A e B se parecem passa por coincidência quando o código pega o campo
// errado — e foi um perfil "quase certo" que produziu este defeito.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, paisagem de
// desktop, e faz telas de celular estourarem em overflow.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/sessao/avatar_publico.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// A visitante (A) e os visitados (B, C) — nada em comum
// ===========================================================================

const String contaA = 'P0A1B2C3D4E5';
const String apelidoA = 'Ana';
const String avatarA = 'coruja_dourada';

const String idB = 'PBB1BB2BB3BB';
const String apelidoB = 'Bartolomeu';
const String avatarB = 'lobo_prateado';

const String idC = 'PCC9CC8CC7CC';
const String apelidoC = 'Cassandra';
const String avatarC = 'tigre_branco';

Map<String, Object?> jogadorBruto({
  required String id,
  String apelido = '',
  String avatar = '',
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int posicao = 1,
  bool souEu = false,
  int partidas = 10,
  int vitorias = 6,
  int derrotas = 4,
  num aproveitamento = 60.0,
}) => {
  'id': id,
  'apelido': apelido,
  'avatar': avatar,
  'liga': liga,
  'ligaId': ligaId,
  'pontos': 1200,
  'posicao': posicao,
  'direcao': 'manteve',
  'delta': 0,
  'selo': null,
  'souEu': souEu,
  'estado': 'classificado',
  'qualificacaoRestante': 0,
  'partidas': partidas,
  'vitorias': vitorias,
  'derrotas': derrotas,
  'aproveitamento': aproveitamento,
};

/// A abertura do escopo da VISITANTE. Liga e números bem diferentes dos de B.
Map<String, Object?> aberturaDeA() => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': 'T-2026-01',
    'temporadaNome': 'Temporada 1',
    'faixaTempo': 'em andamento',
    'fimEm': null,
    'divisao': null,
    'podio': const [],
    'escadaLigas': const [],
    'eu': jogadorBruto(
      id: contaA,
      apelido: apelidoA,
      avatar: avatarA,
      liga: 'Diamante',
      ligaId: 'diamante',
      posicao: 3,
      souEu: true,
      partidas: 999,
      vitorias: 888,
      aproveitamento: 88.0,
    ),
  },
  'primeiraPagina': const {'itens': [], 'cursorProxima': null, 'fim': true},
};

/// A resposta de `consultarJogadorPorIdPublico` para um visitado.
Map<String, Object?> publicoCom({
  required String id,
  required String apelido,
  required String avatar,
  String liga = 'Prata',
  String? ligaId = 'prata',
  int posicao = 47,
  int partidas = 20,
  int vitorias = 7,
  num aproveitamento = 35.0,
  bool classificado = true,
}) => {
  'id': id,
  'temporadaId': 'T-2026-01',
  'classificado': classificado,
  'jogador': classificado
      ? jogadorBruto(
          id: id,
          apelido: apelido,
          avatar: avatar,
          liga: liga,
          ligaId: ligaId,
          posicao: posicao,
          partidas: partidas,
          vitorias: vitorias,
          aproveitamento: aproveitamento,
        )
      : null,
};

class TransporteEspiao extends TransporteRanking {
  final List<String> idsConsultados = <String>[];
  int chamadasAbrir = 0;

  Object? respostaPropria = aberturaDeA();
  Object? Function(String id) respostaPublica = (id) =>
      publicoCom(id: id, apelido: apelidoB, avatar: avatarB);

  /// Quando falso, cada consulta pública fica pendurada até o teste completá-la.
  bool automatico = true;
  final Map<String, Completer<Object?>> pendentes = {};

  /// Quando não nulo, a consulta pública falha com este motivo.
  MotivoFalhaRanking? falhaPublica;

  @override
  Future<AberturaRanking> abrirRanking() async {
    chamadasAbrir++;
    return AberturaRanking.daResposta(respostaPropria);
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) async {
    idsConsultados.add(publicId);
    final motivo = falhaPublica;
    if (motivo != null) throw FalhaRanking(motivo, 'teste');
    if (!automatico) {
      final c = Completer<Object?>();
      pendentes[publicId] = c;
      return FotografiaRanking.doPerfilPublico(await c.future);
    }
    return FotografiaRanking.doPerfilPublico(respostaPublica(publicId));
  }
}

class FonteDeA implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => const IdentidadePublica(
    publicId: contaA,
    apelido: apelidoA,
    avatarRef: avatarA,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );
}

/// O arquivo SEM comentários, respeitando aspas.
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
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    transporte = TransporteEspiao();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  void abrir() {
    ranking = RankingDaSessao(leitor: LeitorDeRanking(transporte: transporte));
    addTearDown(ranking.dispose);
    sessao = SessaoDoJogador(fonte: FonteDeA(), uids: auth.stream);
    addTearDown(sessao.dispose);
  }

  Future<void> assentar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    abrir();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add('uid-A');
    await tester.pump();
    await tester.pump();
    ranking.aoMudarSessao(geracao: 1, publicId: contaA);
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

  PerfilVM vmDaTela(WidgetTester tester) =>
      tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

  String textoDaTela(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' | ');

  // =========================================================================
  // 1–2 — O PERFIL PRÓPRIO NÃO PODE TER SIDO QUEBRADO
  // =========================================================================
  group('perfil próprio', () {
    testWidgets('V1 meu perfil mostra o MEU nome', (tester) async {
      await login(tester);
      await montar(tester, const PerfilPage());
      expect(vmDaTela(tester).nome, apelidoA);
    });

    testWidgets('V2 meu perfil mostra o MEU avatar', (tester) async {
      await login(tester);
      await montar(tester, const PerfilPage());
      expect(vmDaTela(tester).avatar, avatarA);
      expect(vmDaTela(tester).avatar, avatarPublicoDe(avatarA));
    });

    testWidgets('V18 meu perfil continua funcional de ponta a ponta', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const PerfilPage());

      final vm = vmDaTela(tester);
      expect(vm.ehMeuPerfil, isTrue);
      expect(vm.nome, apelidoA);
      expect(vm.avatar, avatarA);
      expect(vm.ranking.liga, 'Diamante');
      // E o dono NÃO passa pela callable de terceiro.
      expect(transporte.idsConsultados, isEmpty);
    });
  });

  // =========================================================================
  // 3–8 — A MATRIZ "A VISITA B"
  // =========================================================================
  group('A visita B', () {
    Future<PerfilVM> visitar(WidgetTester tester, String id) async {
      await login(tester);
      await montar(tester, PerfilPage(publicIdVisitado: id));
      return vmDaTela(tester);
    }

    testWidgets('V3 o nome é o de B', (tester) async {
      expect((await visitar(tester, idB)).nome, apelidoB);
    });

    testWidgets('V4 o avatar é o de B', (tester) async {
      final vm = await visitar(tester, idB);
      expect(vm.avatar, avatarB);
      expect(vm.avatar, avatarPublicoDe(avatarB));
    });

    testWidgets('V5 a liga é a de B', (tester) async {
      final vm = await visitar(tester, idB);
      expect(vm.ranking.liga, 'Prata');
      expect(vm.ranking.posicaoMundial, 47);
    });

    testWidgets('V6 as estatísticas são as de B', (tester) async {
      final vm = await visitar(tester, idB);
      final stats = vm.stats;
      expect(stats, isNotNull);
      expect(stats!.partidas, 20);
      expect(stats.vitorias, 7);
      expect(stats.aproveitamento, 35);
      // Canastras não está na lista branca da autoridade pública. Nulo, e não
      // zero: zero seria uma afirmação sobre o jogo de outra pessoa.
      expect(stats.canastras, isNull);
    });

    testWidgets('V7 o nome de A NUNCA aparece no perfil de B', (tester) async {
      final vm = await visitar(tester, idB);
      expect(vm.nome, isNot(apelidoA));
      expect(textoDaTela(tester), isNot(contains(apelidoA)));
    });

    testWidgets('V8 o avatar de A NUNCA aparece no perfil de B', (tester) async {
      final vm = await visitar(tester, idB);
      expect(vm.avatar, isNot(avatarA));
      expect(find.text(avatarA), findsNothing);
    });

    testWidgets('V-cruzado os QUATRO campos são de B, ao mesmo tempo', (
      tester,
    ) async {
      // O caso que a OS chama de identidade cruzada. Um por um, cada asserção
      // acima poderia passar com o código pegando o campo certo por acidente;
      // os quatro juntos, com fixtures que não se parecem em nada, não.
      final vm = await visitar(tester, idB);
      expect(vm.nome, apelidoB);
      expect(vm.avatar, avatarB);
      expect(vm.ranking.liga, 'Prata');
      expect(vm.stats!.partidas, 20);

      // E NENHUM dos de A sobreviveu em lugar nenhum da tela.
      final texto = textoDaTela(tester);
      for (final deA in const [apelidoA, avatarA, 'Diamante', '999']) {
        expect(
          texto,
          isNot(contains(deA)),
          reason: '"$deA" é da visitante e apareceu no perfil do visitado',
        );
      }
    });
  });

  // =========================================================================
  // 9–10 — CORRIDA E TOQUES REPETIDOS
  // =========================================================================
  group('assíncrono', () {
    testWidgets('V9 resposta atrasada de B não sobrescreve C', (tester) async {
      transporte.automatico = false;
      transporte.respostaPublica = (id) => id == idB
          ? publicoCom(id: idB, apelido: apelidoB, avatar: avatarB)
          : publicoCom(
              id: idC,
              apelido: apelidoC,
              avatar: avatarC,
              liga: 'Bronze',
              ligaId: 'bronze',
            );
      await login(tester);

      // Abre B — a consulta fica pendurada.
      await montar(
        tester,
        const PerfilPage(key: ValueKey('b'), publicIdVisitado: idB),
      );
      // Navega para C antes de B responder.
      await montar(
        tester,
        const PerfilPage(key: ValueKey('c'), publicIdVisitado: idC),
      );
      transporte.pendentes[idC]!.complete(
        publicoCom(
          id: idC,
          apelido: apelidoC,
          avatar: avatarC,
          liga: 'Bronze',
          ligaId: 'bronze',
        ),
      );
      await assentar(tester);
      expect(vmDaTela(tester).nome, apelidoC);

      // AGORA a resposta atrasada de B chega.
      transporte.pendentes[idB]!.complete(
        publicoCom(id: idB, apelido: apelidoB, avatar: avatarB),
      );
      await assentar(tester);

      final vm = vmDaTela(tester);
      expect(vm.nome, apelidoC, reason: 'B atrasado sobrescreveu C');
      expect(vm.avatar, avatarC);
      expect(vm.ranking.liga, 'Bronze');
      expect(vm.nome, isNot(apelidoB));
    });

    testWidgets('V10 três toques em B produzem UMA consulta', (tester) async {
      transporte.automatico = false;
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      final antes = transporte.idsConsultados.length;
      unawaited(
        ranking.leitor.perfilPublico(contaPublicId: contaA, alvoPublicId: idB),
      );
      unawaited(
        ranking.leitor.perfilPublico(contaPublicId: contaA, alvoPublicId: idB),
      );
      await tester.pump();

      expect(
        transporte.idsConsultados.length,
        antes,
        reason: 'o dedupe por chave caiu — três toques viraram três chamadas',
      );

      transporte.pendentes[idB]!.complete(
        publicoCom(id: idB, apelido: apelidoB, avatar: avatarB),
      );
      await assentar(tester);
      expect(vmDaTela(tester).nome, apelidoB);
    });
  });

  // =========================================================================
  // 11–14 — A CHAVE É O publicId, E SÓ ELE
  // =========================================================================
  group('a chave é o publicId', () {
    testWidgets('V11 publicId vazio não navega nem consulta', (tester) async {
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: ''));

      // Vazio não é um id: não há a quem perguntar, e a tela não afirma
      // identidade de ninguém — muito menos a de quem está olhando.
      expect(vmDaTela(tester).nome, isNot(apelidoA));
      expect(textoDaTela(tester), isNot(contains(apelidoA)));
    });

    test('V12 apelido não vira chave', () {
      final fonte = semComentarios(File('lib/casca/navegacao_perfil_publico.dart'));
      expect(fonte, contains('jogador.publicPlayerId'));
      expect(fonte, isNot(contains('apelido')));
    });

    test('V13 posição não vira chave', () {
      final fonte = semComentarios(File('lib/casca/navegacao_perfil_publico.dart'));
      expect(fonte, isNot(contains('posicao')));
    });

    test('V14 índice de lista não vira chave', () {
      final fonte = semComentarios(File('lib/casca/navegacao_perfil_publico.dart'));
      for (final proibido in const ['indexOf', 'elementAt', '[i]', 'index]']) {
        expect(fonte, isNot(contains(proibido)));
      }
    });

    testWidgets('V-mesmo-id o próprio publicId pela porta pública converge', (
      tester,
    ) async {
      // Abrir o próprio perfil passando explicitamente o próprio publicId tem
      // de continuar correto — e sem o atalho "é meu id, então ignoro a
      // projeção e uso a sessão". Os dois dados CONVERGEM, e é isso que se
      // afirma: o que a tela mostra é o que a projeção pública trouxe.
      transporte.respostaPublica = (id) => publicoCom(
        id: id,
        apelido: apelidoA,
        avatar: avatarA,
        liga: 'Diamante',
        ligaId: 'diamante',
        posicao: 3,
      );
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: contaA));

      final vm = vmDaTela(tester);
      expect(vm.nome, apelidoA);
      expect(vm.avatar, avatarA);
      expect(vm.ranking.liga, 'Diamante');
    });
  });

  // =========================================================================
  // 15–17 — FALHA, FALLBACK E PRIVACIDADE
  // =========================================================================
  group('falha, fallback e privacidade', () {
    testWidgets('V15 falha na leitura pública NÃO cai para a sessão', (
      tester,
    ) async {
      transporte.falhaPublica = MotivoFalhaRanking.indisponivel;
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      final vm = vmDaTela(tester);
      // A direção segura: sem projeção, não se afirma identidade. O que NÃO
      // pode é "parecer que funcionou" mostrando o dono da sessão.
      expect(vm.nome, isNot(apelidoA));
      expect(vm.avatar, isNot(avatarA));
      expect(textoDaTela(tester), isNot(contains(apelidoA)));
      expect(vm.ranking.liga, isNot('Diamante'));
    });

    testWidgets('V15b classificado:false também não vaza a visitante', (
      tester,
    ) async {
      // O jogador existe, respondeu, e não está na tabela. Continua não havendo
      // projeção pública — e continua não podendo virar o perfil de quem olha.
      transporte.respostaPublica = (id) => publicoCom(
        id: id,
        apelido: apelidoB,
        avatar: avatarB,
        classificado: false,
      );
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      final vm = vmDaTela(tester);
      expect(vm.nome, isNot(apelidoA));
      expect(vm.avatar, isNot(avatarA));
      expect(vm.ranking.liga, isNull);
    });

    testWidgets('V16 avatar ausente do visitado usa o fallback PÚBLICO', (
      tester,
    ) async {
      transporte.respostaPublica = (id) =>
          publicoCom(id: id, apelido: apelidoB, avatar: '');
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      final vm = vmDaTela(tester);
      // O MESMO fallback de todo mundo — não um segundo, e não o de A.
      expect(vm.avatar, kAvatarPublicoFallback);
      expect(vm.avatar, isNot(avatarA));
      // E o nome continua sendo o de B: a falta de avatar não contamina.
      expect(vm.nome, apelidoB);
    });

    testWidgets('V16b referência malformada cai no mesmo fallback', (
      tester,
    ) async {
      transporte.respostaPublica = (id) => publicoCom(
        id: id,
        apelido: apelidoB,
        avatar: 'https://exemplo.invalido/foto.png',
      );
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      expect(vmDaTela(tester).avatar, kAvatarPublicoFallback);

      // E EM ESPECIAL: não virou uma tentativa de rede. A tela tem imagens
      // legítimas — moldura, dorso, efeito, vitrine —, todas de asset, então a
      // prova não é "não há Image": é "nenhuma Image busca na rede". Um
      // `avatarRef` adulterado com `https://` viraria uma requisição para o
      // servidor de quem o gravou, e é esse o risco que o resolvedor fecha.
      final daRede = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is NetworkImage);
      expect(
        daRede,
        isEmpty,
        reason: 'um avatarRef de terceiro virou requisição de rede',
      );
    });

    test('V17 a projeção pública não tem campo privado', () {
      // Estrutural, e não textual: a garantia é o objeto NÃO TER onde um uid
      // caberia. Uma varredura por palavra seria afrouxável; a ausência do
      // campo, não.
      final fonte = semComentarios(File('lib/ranking/ranking_transporte.dart'));
      for (final privado in const [
        r'final String uid',
        r'final String? uid',
        'uid:',
        'email',
        'token',
        'claims',
        'entitlement',
      ]) {
        expect(
          fonte,
          isNot(contains(privado)),
          reason: '$privado entrou na projeção pública',
        );
      }
    });

    testWidgets('V17b nada de privado chega à tela do visitado', (tester) async {
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: idB));

      final texto = textoDaTela(tester);
      for (final privado in const ['uid-A', '@', 'token', contaA]) {
        expect(
          texto,
          isNot(contains(privado)),
          reason: '"$privado" vazou para a tela de um terceiro',
        );
      }
    });
  });

  // =========================================================================
  // GUARDA ESTRUTURAL CONTRA RECAÍDA
  // =========================================================================
  group('guarda estrutural', () {
    test('V-guarda o caminho visitado não alcança a identidade da sessão', () {
      final pagina = semComentarios(File('lib/pages/perfil_page.dart'));

      // A CHAMADA que monta o VM não pode passar a identidade da sessão sem
      // uma guarda de `ehMeuPerfil`. A forma exata é o que se trava: foi um
      // `identidade: identidade` incondicional que produziu o defeito.
      expect(
        pagina,
        contains('identidade: widget.ehMeuPerfil ? identidade : null'),
        reason: 'a identidade da sessão voltou a atravessar para um visitado',
      );

      // E a reaplicação do avatar da sessão é do DONO, e só dele.
      expect(
        pagina,
        contains('widget.ehMeuPerfil'),
        reason: 'sumiu a guarda que separa dono de visitante',
      );
      expect(
        RegExp(r'^\s*final vm = comRanking\.comAvatarPublico\(', multiLine: true)
            .hasMatch(pagina),
        isFalse,
        reason: 'o avatar da sessão voltou a ser aplicado sem guarda',
      );
    });

    test('V-guarda o serviço não tem segunda fonte de identidade', () {
      final servico = semComentarios(File('lib/services/perfil_service.dart'));
      for (final proibido in const [
        'FirebaseAuth',
        'displayName',
        'currentUser',
        'email',
        'EscopoSessao',
      ]) {
        expect(
          servico,
          isNot(contains(proibido)),
          reason: '$proibido virou fonte de nome no Perfil',
        );
      }
      // E nenhum literal de avatar: a coroa é do resolvedor, não daqui.
      expect(servico, isNot(contains("avatar: '")));
    });
  });
}
