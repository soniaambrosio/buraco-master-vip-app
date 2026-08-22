// navegacao_perfil_publico_test.dart — a matriz da OS "Projeção canônica do
// ranking e navegação ao Perfil público".
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTA SUÍTE GUARDA
// ---------------------------------------------------------------------------
//
// `abrirRanking` sempre devolveu jogadores REAIS em `resumo.podio[]` e
// `primeiraPagina.itens[]`, cada um com `publicPlayerId` e `souEu` decididos
// pelo servidor. O cliente lia a resposta e guardava um campo: `resumo.eu`. Os
// jogadores eram descartados dentro do parser — não por decisão de produto, mas
// porque ninguém tinha escrito o tipo que os receberia.
//
// A consequência não é cosmética. Enquanto a única lista de gente de verdade do
// sistema não existisse no aplicativo, qualquer tela de ranking teria de
// INVENTAR jogadores — e é essa a família de defeitos desta linhagem inteira:
// Liga Bronze para quem nunca jogou, `#0 no mundo`, o Hall com cinco nomes
// escritos no código, Amigos com `beto` e `claudia`.
//
// ---------------------------------------------------------------------------
// AS DUAS COISAS QUE ESTA SUÍTE NÃO DEIXA VOLTAR
// ---------------------------------------------------------------------------
//
// 1. QUE UM JOGADOR SE PERCA. Os dezessete campos de `JogadorPublicado` chegam
//    campo a campo, e a comparação é do OBJETO INTEIRO — não de três campos
//    escolhidos, que é como uma perda passa despercebida.
//
// 2. QUE O CLIENTE DECIDA "SOU EU". A comparação acontece em uma linha do
//    sistema, e ela é do servidor (`projecao.ts`). Aqui há um caso que encena
//    um terceiro cujo `publicPlayerId` é IGUAL ao da conta logada e cujo
//    `souEu` é `false` — a lista que qualquer heurística local classificaria
//    errado.
//
// NENHUM ATRASO REAL: o transporte falso responde quando o teste mandar.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/ranking_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
// `EstadoRanking` e `FaseRanking` chegam reexportados por `perfil_screen.dart`.
import 'package:buraco_master_vip/ranking/estado_tabela_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Fixtures — todos com a FORMA do contrato real
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';
const contaB = 'P9Z8Y7X6W5V4';
const alvoX = 'PXX1XX2XX3XX';
const alvoY = 'PYY1YY2YY3YY';

/// Um jogador publicado, com os dezessete campos de `JogadorPublicado`.
Map<String, Object?> jogadorBruto({
  required String id,
  String apelido = '',
  String avatar = '',
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int pontos = 1200,
  int posicao = 1,
  String direcao = 'manteve',
  int delta = 0,
  String? selo,
  bool souEu = false,
  String estado = 'classificado',
  int qualificacaoRestante = 0,
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
  'pontos': pontos,
  'posicao': posicao,
  'direcao': direcao,
  'delta': delta,
  'selo': selo,
  'souEu': souEu,
  'estado': estado,
  'qualificacaoRestante': qualificacaoRestante,
  'partidas': partidas,
  'vitorias': vitorias,
  'derrotas': derrotas,
  'aproveitamento': aproveitamento,
};

/// A resposta inteira de `abrirRanking`.
Map<String, Object?> abertura({
  String? temporadaId = 'T-2026-01',
  Object? eu,
  List<Map<String, Object?>> podio = const [],
  List<Map<String, Object?>> primeiraPagina = const [],
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'faixaTempo': 'em andamento',
    'fimEm': null,
    'divisao': null,
    'podio': podio,
    'escadaLigas': const [],
    'eu': eu,
  },
  'primeiraPagina': {
    'itens': primeiraPagina,
    'cursorProxima': null,
    'fim': true,
  },
};

Map<String, Object?> publicoCom({
  required String id,
  String liga = 'Prata',
  String? temporadaId = 'T-2026-01',
}) => {
  'id': id,
  'temporadaId': temporadaId,
  'classificado': true,
  'jogador': jogadorBruto(id: id, liga: liga, ligaId: 'prata', posicao: 50),
};

/// Uma tabela de três: eu no pódio, e dois terceiros na página.
Map<String, Object?> aberturaPovoada({String? temporadaId = 'T-2026-01'}) =>
    abertura(
      temporadaId: temporadaId,
      eu: jogadorBruto(id: contaA, apelido: 'Dona', souEu: true, posicao: 2),
      podio: [
        jogadorBruto(id: alvoX, apelido: 'Primeira', posicao: 1, pontos: 2000),
        jogadorBruto(id: contaA, apelido: 'Dona', posicao: 2, souEu: true),
        jogadorBruto(id: alvoY, apelido: 'Terceiro', posicao: 3, pontos: 900),
      ],
      primeiraPagina: [
        jogadorBruto(id: alvoX, apelido: 'Primeira', posicao: 1, pontos: 2000),
        jogadorBruto(id: contaA, apelido: 'Dona', posicao: 2, souEu: true),
        jogadorBruto(id: alvoY, apelido: 'Terceiro', posicao: 3, pontos: 900),
      ],
    );

// ===========================================================================
// Transporte espião
// ===========================================================================

class TransporteEspiao extends TransporteRanking {
  final List<String> chamadas = <String>[];
  final List<String> idsConsultados = <String>[];
  final List<Completer<AberturaRanking>> aberturas = [];
  final List<Completer<FotografiaRanking>> publicos = [];

  /// Quando falso, cada chamada fica pendurada até o teste completá-la.
  bool automatico = true;
  Object? respostaAbertura = aberturaPovoada();
  Object? respostaPublica = publicoCom(id: alvoX);
  FalhaRanking? falhaAbertura;

  @override
  Future<AberturaRanking> abrirRanking() {
    chamadas.add('abertura');
    if (!automatico) {
      final c = Completer<AberturaRanking>();
      aberturas.add(c);
      return c.future;
    }
    final falha = falhaAbertura;
    if (falha != null) return Future<AberturaRanking>.error(falha);
    return Future.value(AberturaRanking.daResposta(respostaAbertura));
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) {
    chamadas.add('publico');
    idsConsultados.add(publicId);
    if (!automatico) {
      final c = Completer<FotografiaRanking>();
      publicos.add(c);
      return c.future;
    }
    return Future.value(FotografiaRanking.doPerfilPublico(respostaPublica));
  }

  int get chamadasAbertura => chamadas.where((c) => c == 'abertura').length;
  int get chamadasPublico => chamadas.where((c) => c == 'publico').length;
}

class FonteRegulavel implements FonteDeIdentidade {
  String publicId = contaA;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: publicId,
    apelido: 'Dona',
    avatarRef: null,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );
}

/// Duas esperas encadeadas: identidade por `Future`, depois os 350ms do serviço
/// de perfil. Mesma ferramenta da suíte de composição.
Future<void> assentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

String textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

// ===========================================================================
// Auditoria estrutural — as mesmas ferramentas das suítes vizinhas
// ===========================================================================

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
        if (i + 1 < fonte.length) saida.write(fonte[i + 1]);
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

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

String _barras(String p) => p.replaceAll(r'\', '/');

String _resolver(String de, String alvo) {
  if (alvo.startsWith('package:buraco_master_vip/')) {
    return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(de).split('/')..removeLast();
  for (final parte in alvo.split('/')) {
    if (parte == '..') {
      base.removeLast();
    } else if (parte != '.') {
      base.add(parte);
    }
  }
  return base.join('/');
}

Set<String> alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(semComentarios(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

/// Quem CONSTRÓI uma classe, entre os alcançáveis. O declarante é excluído: o
/// `class X` traz o próprio construtor junto, e contá-lo faria toda autoridade
/// parecer duplicada por definição.
List<String> quemConstroi(Set<String> alcancaveis, String classe) {
  final saida = <String>[];
  for (final caminho in alcancaveis) {
    final f = File(caminho);
    if (!f.existsSync()) continue;
    final fonte = semComentarios(f);
    if (RegExp('class\\s+$classe\\b').hasMatch(fonte)) continue;
    if (fonte.contains('$classe(')) saida.add(_barras(caminho));
  }
  return saida..sort();
}

void main() {
  // =========================================================================
  // N1 — a projeção preserva o que a autoridade publicou
  // =========================================================================
  group('N1 — pódio e primeira página, campo a campo', () {
    test('N1a — os dezessete campos atravessam sem perda', () {
      final lida = AberturaRanking.daResposta(
        abertura(
          eu: jogadorBruto(id: contaA, souEu: true),
          podio: [
            jogadorBruto(
              id: alvoX,
              apelido: 'Primeira',
              avatar: '🦊',
              liga: 'Lenda',
              ligaId: 'lenda',
              pontos: 2431,
              posicao: 1,
              direcao: 'subiu',
              delta: 3,
              selo: 'campea',
              souEu: false,
              estado: 'classificado',
              qualificacaoRestante: 0,
              partidas: 41,
              vitorias: 30,
              derrotas: 9,
              aproveitamento: 73.2,
            ),
          ],
        ),
      );

      final j = lida.tabela!.podio.single;
      // O OBJETO INTEIRO, e não três campos escolhidos: é assim que uma perda
      // de campo aparece em vez de passar.
      expect(
        j,
        const JogadorPublicoRanking(
          publicPlayerId: alvoX,
          apelido: 'Primeira',
          avatar: '🦊',
          rotuloLiga: 'Lenda',
          ligaId: 'lenda',
          pontos: 2431,
          posicao: 1,
          direcao: 'subiu',
          delta: 3,
          selo: 'campea',
          souEu: false,
          estado: 'classificado',
          qualificacaoRestante: 0,
          partidas: 41,
          vitorias: 30,
          derrotas: 9,
          aproveitamento: 73.2,
        ),
      );
    });

    test('N1b — a ORDEM e a quantidade são as da autoridade', () {
      final lida = AberturaRanking.daResposta(aberturaPovoada());
      expect(lida.tabela!.podio.map((j) => j.publicPlayerId).toList(), [
        alvoX,
        contaA,
        alvoY,
      ]);
      expect(lida.tabela!.primeiraPagina.map((j) => j.posicao).toList(), [
        1,
        2,
        3,
      ]);
    });

    test('N1c — pódio e primeira página são listas SEPARADAS', () {
      final lida = AberturaRanking.daResposta(
        abertura(
          eu: null,
          podio: [jogadorBruto(id: alvoX, posicao: 1)],
          primeiraPagina: [
            jogadorBruto(id: alvoX, posicao: 1),
            jogadorBruto(id: alvoY, posicao: 2),
          ],
        ),
      );
      expect(lida.tabela!.podio, hasLength(1));
      expect(lida.tabela!.primeiraPagina, hasLength(2));
    });

    test('N1d — `eu: null` continua sendo resposta, e a tabela sobrevive', () {
      final lida = AberturaRanking.daResposta(
        abertura(eu: null, podio: [jogadorBruto(id: alvoX)]),
      );
      expect(lida.eu.classificado, isFalse);
      expect(lida.eu.posicao, 0);
      expect(lida.tabela!.podio, hasLength(1));
    });

    test('N1e — `aproveitamento` inteiro é aceito; `posicao` texto, não', () {
      // JSON entrega `0` (int) para quem não jogou e `60.0` (double) para quem
      // jogou. Recusar o int transformaria jogador novo em resposta inválida.
      final ok = AberturaRanking.daResposta(
        abertura(podio: [jogadorBruto(id: alvoX, aproveitamento: 0)]),
      );
      expect(ok.tabela!.podio.single.aproveitamento, 0.0);

      expect(
        () => AberturaRanking.daResposta({
          'resumo': {
            'temporadaId': 'T1',
            'podio': [
              {...jogadorBruto(id: alvoX), 'posicao': '1'},
            ],
            'eu': null,
          },
          'primeiraPagina': const {'itens': []},
        }),
        throwsA(
          isA<FalhaRanking>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaRanking.respostaInvalida,
          ),
        ),
      );
    });

    test('N1f — uma linha malformada derruba a LISTA, e não some sozinha', () {
      // Pular a linha ruim mudaria em silêncio quem está em cada posição.
      expect(
        () => AberturaRanking.daResposta(
          abertura(
            podio: [
              jogadorBruto(id: alvoX, posicao: 1),
              {...jogadorBruto(id: alvoY, posicao: 2)}..remove('souEu'),
            ],
          ),
        ),
        throwsA(isA<FalhaRanking>()),
      );
    });
  });

  // =========================================================================
  // N2 — `publicPlayerId` nunca vira UID
  // =========================================================================
  group('N2 — o identificador é o público, e só ele', () {
    test('N2a — a projeção não tem campo onde um uid caberia', () {
      // Estrutural: não há como um uid entrar num objeto que não tem lugar
      // para ele. A varredura é sobre o ARQUIVO da projeção.
      final fonte = semComentarios(File('lib/ranking/ranking_transporte.dart'));
      for (final proibido in const [
        'uid',
        'userId',
        'FirebaseAuth',
        'currentUser',
      ]) {
        expect(
          fonte,
          isNot(contains(proibido)),
          reason: 'a fronteira do ranking passou a conhecer $proibido',
        );
      }
    });

    test('N2b — o ponto de navegação só lê `publicPlayerId` e `souEu`', () {
      final fonte = semComentarios(
        File('lib/casca/navegacao_perfil_publico.dart'),
      );
      expect(fonte, contains('jogador.souEu'));
      expect(fonte, contains('jogador.publicPlayerId'));
      for (final proibido in const [
        'uid',
        'apelido',
        'posicao',
        'EscopoSessao',
        'publicId ==',
      ]) {
        expect(
          fonte,
          isNot(contains(proibido)),
          reason: 'a decisão de "sou eu" passou a olhar $proibido',
        );
      }
    });

    test('N2c — o id publicado chega intacto ao objeto', () {
      final lida = AberturaRanking.daResposta(
        abertura(podio: [jogadorBruto(id: alvoX)]),
      );
      expect(lida.tabela!.podio.single.publicPlayerId, alvoX);
    });
  });

  // =========================================================================
  // N3–N5, N10 — o ponto único de navegação
  // =========================================================================
  group('N3–N10 — a decisão de qual Perfil abrir', () {
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

    // Abertos DENTRO do teste: `testWidgets` roda num zone de tempo falso, e um
    // stream assinado no `setUp` nunca entregaria o login para o `pump`.
    void abrir() {
      ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);
      sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
      addTearDown(sessao.dispose);
    }

    Future<void> montarRanking(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: EscopoRanking(
            ranking: ranking,
            child: const MaterialApp(home: RankingDeProducao()),
          ),
        ),
      );
      await assentar(tester);
    }

    testWidgets('N3 — tocar em MIM abre o Perfil do dono', (tester) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      await tester.tap(find.text('você').first);
      await assentar(tester);

      expect(find.byType(PerfilScreen), findsOneWidget);
      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.ehMeuPerfil, isTrue);
      expect(
        pagina.publicIdVisitado,
        isNull,
        reason: 'o dono foi aberto pela cadeia do visitante',
      );
    });

    testWidgets('N4 — o próprio jogador NÃO produz chamada de perfil público', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);
      expect(transporte.chamadasPublico, 0);

      await tester.tap(find.text('você').first);
      await assentar(tester);

      expect(
        transporte.chamadasPublico,
        0,
        reason: 'o dono foi consultado pela callable reservada a terceiro',
      );
      expect(transporte.idsConsultados, isEmpty);
    });

    testWidgets('N5 — tocar num TERCEIRO usa exatamente o publicPlayerId dele', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      transporte.respostaPublica = publicoCom(id: alvoY);
      await montarRanking(tester);

      await tester.tap(find.text('Terceiro').first);
      await assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.ehMeuPerfil, isFalse);
      expect(pagina.publicIdVisitado, alvoY);
      expect(transporte.idsConsultados, [alvoY]);
    });

    testWidgets('N5b — `souEu` MANDA, mesmo com o id igual ao da conta', (
      tester,
    ) async {
      // A LISTA QUE QUALQUER HEURÍSTICA LOCAL CLASSIFICARIA ERRADO: a linha tem
      // o mesmo `publicPlayerId` da conta logada e `souEu: false`. Só o
      // servidor sabe que o uid é outro.
      transporte.respostaAbertura = abertura(
        eu: jogadorBruto(id: contaA, souEu: true),
        primeiraPagina: [
          jogadorBruto(id: contaA, apelido: 'Homônima', souEu: false),
        ],
      );
      transporte.respostaPublica = publicoCom(id: contaA);
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      await tester.tap(find.text('Homônima'));
      await assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(
        pagina.ehMeuPerfil,
        isFalse,
        reason: 'a tela comparou o publicId com o da sessão em vez de ler souEu',
      );
      expect(pagina.publicIdVisitado, contaA);
    });

    testWidgets('N10 — terceiro com `publicPlayerId` vazio não navega', (
      tester,
    ) async {
      transporte.respostaAbertura = abertura(
        eu: jogadorBruto(id: contaA, souEu: true),
        primeiraPagina: [jogadorBruto(id: '', apelido: 'Sem id')],
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      await tester.tap(find.text('Sem id'));
      await assentar(tester);

      expect(
        find.byType(PerfilScreen),
        findsNothing,
        reason: 'abriu um Perfil sem ter a quem perguntar',
      );
      expect(transporte.chamadasPublico, 0);
      // E a tela do ranking continua onde estava.
      expect(find.byType(RankingDeProducao), findsOneWidget);
    });

    testWidgets('N10b — id só de espaços também não navega', (tester) async {
      transporte.respostaAbertura = abertura(
        eu: jogadorBruto(id: contaA, souEu: true),
        primeiraPagina: [jogadorBruto(id: '   ', apelido: 'Espacos')],
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      await tester.tap(find.text('Espacos'));
      await assentar(tester);

      expect(find.byType(PerfilScreen), findsNothing);
      expect(transporte.chamadasPublico, 0);
    });

    testWidgets('N10c — o DONO abre mesmo sem id na linha', (tester) async {
      // O perfil do dono não depende do `publicPlayerId` da linha: identidade
      // vem do escopo de sessão. Recusar aqui deixaria a pessoa sem perfil por
      // um campo que a tela dela nem lê.
      transporte.respostaAbertura = abertura(
        eu: jogadorBruto(id: contaA, souEu: true),
        primeiraPagina: [
          jogadorBruto(id: '', apelido: 'Eu mesma', souEu: true),
        ],
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      await tester.tap(find.text('Eu mesma'));
      await assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.ehMeuPerfil, isTrue);
      expect(transporte.chamadasPublico, 0);
    });

    testWidgets('N14 — voltar do Perfil público preserva o ranking', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      transporte.respostaPublica = publicoCom(id: alvoY);
      await montarRanking(tester);
      final aberturasAntes = transporte.chamadasAbertura;

      await tester.tap(find.text('Terceiro').first);
      await assentar(tester);
      expect(find.byType(PerfilScreen), findsOneWidget);

      // O gesto REAL: `pageBack()` procura o botão de voltar do Material, e o
      // Perfil desenha o seu próprio. Tocar no controle que a pessoa toca é o
      // que faz este caso provar a volta, e não a mecânica do Navigator.
      await tester.tap(find.byTooltip('Voltar'));
      await assentar(tester);

      expect(find.byType(RankingDeProducao), findsOneWidget);
      final texto = textoDaTela(tester);
      expect(texto, contains('Primeira'));
      expect(texto, contains('Terceiro'));
      expect(
        transporte.chamadasAbertura,
        aberturasAntes,
        reason: 'voltar recarregou o ranking do zero',
      );
    });

    testWidgets('N15 — cada linha é um botão com área de toque suficiente', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montarRanking(tester);

      // A frase é escrita para ser OUVIDA, e diz o que dá para fazer.
      expect(
        find.bySemanticsLabel(
          'Posição 1. Primeira. Ouro. Toque para ver o perfil.',
        ),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(
          'Posição 2. Dona. Ouro. Você. Toque para ver o perfil.',
        ),
        findsWidgets,
      );

      // Toda linha tocável tem pelo menos a altura mínima declarada.
      final alvos = find.byType(InkWell);
      expect(alvos, findsWidgets);
      for (var i = 0; i < tester.widgetList(alvos).length; i++) {
        final tamanho = tester.getSize(alvos.at(i));
        expect(
          tamanho.height,
          greaterThanOrEqualTo(kAlturaMinimaDaLinha),
          reason: 'alvo de toque menor que o mínimo na posição $i',
        );
      }
      handle.dispose();
    });
  });

  // =========================================================================
  // N6–N9 — as garantias do leitor, exercidas pela navegação
  // =========================================================================
  group('N6–N9 — voo, cache e troca de sessão', () {
    late TransporteEspiao transporte;
    late LeitorDeRanking leitor;

    setUp(() {
      transporte = TransporteEspiao();
      transporte.automatico = false;
      leitor = LeitorDeRanking(transporte: transporte);
    });

    test('N6 — três toques no MESMO terceiro reutilizam o voo', () async {
      final a = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      final b = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      final c = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      expect(transporte.chamadasPublico, 1, reason: 'três toques, um voo');

      transporte.publicos.single.complete(
        FotografiaRanking.doPerfilPublico(publicoCom(id: alvoX)),
      );
      expect((await a)!.liga, 'Prata');
      expect((await b)!.liga, 'Prata');
      expect((await c)!.liga, 'Prata');
      expect(transporte.chamadasPublico, 1);
    });

    test('N6b — abertura e projeção compartilham UM voo', () async {
      // `meuRanking` é uma projeção de `abrirRanking`: mesma chave, mesmo voo.
      final completo = leitor.abrirRanking(contaPublicId: contaA);
      final estreito = leitor.meuRanking(contaPublicId: contaA);
      expect(transporte.chamadasAbertura, 1);

      transporte.aberturas.single.complete(
        AberturaRanking.daResposta(aberturaPovoada()),
      );
      expect((await completo)!.tabela.podio, hasLength(3));
      expect((await estreito)!.liga, 'Ouro');
      expect(transporte.chamadasAbertura, 1);
    });

    test('N7 — dois terceiros NÃO compartilham cache nem voo', () async {
      final vooX = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      final vooY = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoY,
      );
      expect(
        transporte.chamadasPublico,
        2,
        reason: 'dois alvos distintos viraram um voo só',
      );
      expect(transporte.idsConsultados, [alvoX, alvoY]);

      transporte.publicos[0].complete(
        FotografiaRanking.doPerfilPublico(publicoCom(id: alvoX)),
      );
      transporte.publicos[1].complete(
        FotografiaRanking.doPerfilPublico(
          publicoCom(id: alvoY, liga: 'Diamante'),
        ),
      );
      expect((await vooX)!.liga, 'Prata');
      expect((await vooY)!.liga, 'Diamante');

      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX)!.liga,
        'Prata',
      );
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoY)!.liga,
        'Diamante',
      );
    });

    test('N8 — troca de sessão esvazia cache e desarma os voos antigos',
        () async {
      final voo = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      transporte.publicos.single.complete(
        FotografiaRanking.doPerfilPublico(publicoCom(id: alvoX)),
      );
      await voo;
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNotNull,
      );

      leitor.aoMudarSessao(2);

      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
        reason: 'a fotografia de um terceiro sobreviveu à troca de conta',
      );
      // E o próximo pedido é um voo NOVO, e não o antigo reaproveitado.
      leitor.rankingPublico(contaPublicId: contaB, alvoPublicId: alvoX);
      expect(transporte.chamadasPublico, 2);
    });

    test('N9 — resposta antiga não substitui a sessão nova', () async {
      final velho = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );

      leitor.aoMudarSessao(2);
      final novo = leitor.rankingPublico(
        contaPublicId: contaB,
        alvoPublicId: alvoX,
      );

      // O NOVO responde primeiro; depois chega o velho, atrasado.
      transporte.publicos[1].complete(
        FotografiaRanking.doPerfilPublico(
          publicoCom(id: alvoX, liga: 'Diamante'),
        ),
      );
      expect((await novo)!.liga, 'Diamante');

      transporte.publicos[0].complete(
        FotografiaRanking.doPerfilPublico(publicoCom(id: alvoX, liga: 'Prata')),
      );
      expect(
        await velho,
        isNull,
        reason: 'a resposta da sessão anterior foi aplicada',
      );
      expect(
        leitor.emCache(contaPublicId: contaB, alvoPublicId: alvoX)!.liga,
        'Diamante',
        reason: 'a resposta velha despejou a fotografia da conta nova',
      );
    });

    test('N8b — a tabela morre junto com a sessão', () async {
      final notificador = RankingDaSessao(leitor: leitor);
      addTearDown(notificador.dispose);

      notificador.aoMudarSessao(geracao: 1, publicId: contaA);
      transporte.aberturas.single.complete(
        AberturaRanking.daResposta(aberturaPovoada()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notificador.tabela.podio, hasLength(3));

      notificador.aoMudarSessao(geracao: 2, publicId: null);
      expect(
        notificador.tabela,
        tabelaDaCascaPublicavel,
        reason: 'a lista de jogadores sobreviveu ao logout',
      );
      expect(notificador.tabela.podio, isEmpty);
    });
  });

  // =========================================================================
  // N11 — os cinco estados, e nenhum deles inventa dado
  // =========================================================================
  group('N11 — os estados da tela', () {
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
      ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);
      sessao = SessaoDoJogador(fonte: FonteRegulavel(), uids: auth.stream);
      addTearDown(sessao.dispose);
    }

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: EscopoRanking(
            ranking: ranking,
            child: const MaterialApp(home: RankingDeProducao()),
          ),
        ),
      );
      await assentar(tester);
    }

    testWidgets('N11a — CARREGANDO não desenha lista nem "ninguém"', (
      tester,
    ) async {
      transporte.automatico = false;
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: EscopoRanking(
            ranking: ranking,
            child: const MaterialApp(home: RankingDeProducao()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('Ninguém classificado')));
      expect(texto, isNot(contains('#')));
    });

    testWidgets('N11b — VAZIO só é dito quando a autoridade respondeu', (
      tester,
    ) async {
      transporte.respostaAbertura = abertura(eu: null);
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      expect(textoDaTela(tester), contains('Ninguém classificado'));
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('N11c — ACESSO RECUSADO é neutro e oferece insistir', (
      tester,
    ) async {
      transporte.falhaAbertura = const FalhaRanking(
        MotivoFalhaRanking.credencialOuAtestacao,
        'teste',
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final texto = textoDaTela(tester);
      expect(texto, contains('Não foi possível acessar o ranking'));
      // NÃO acusa a sessão: o mesmo código chega de App Check ausente.
      expect(texto, isNot(contains('entre na sua conta')));
      expect(texto, isNot(contains('expirou')));
      expect(find.text('Tentar de novo'), findsOneWidget);

      // E não inventa NADA no lugar dos jogadores.
      expect(texto, isNot(contains('Primeira')));
      expect(texto, isNot(contains('Ninguém classificado')));
      expect(texto, isNot(contains('#1')));
    });

    testWidgets('N11d — o retry emite UMA chamada nova, não três', (
      tester,
    ) async {
      transporte.falhaAbertura = const FalhaRanking(
        MotivoFalhaRanking.indisponivel,
        'teste',
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(transporte.chamadasAbertura, 1);

      // O sucesso chega no retry, e a lista aparece.
      transporte.falhaAbertura = null;
      await tester.tap(find.text('Tentar de novo'));
      await assentar(tester);

      expect(transporte.chamadasAbertura, 2);
      expect(textoDaTela(tester), contains('Primeira'));
    });

    testWidgets('N11e — SEM TEMPORADA não vira erro nem botão', (tester) async {
      transporte.falhaAbertura = const FalhaRanking(
        MotivoFalhaRanking.semTemporada,
        'teste',
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      expect(textoDaTela(tester), contains('ainda não está sendo publicado'));
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('N11f — SUCESSO desenha o que veio, e `posicao: 0` vira —', (
      tester,
    ) async {
      transporte.respostaAbertura = abertura(
        eu: jogadorBruto(id: contaA, souEu: true, posicao: 0),
        primeiraPagina: [
          jogadorBruto(id: alvoX, apelido: 'Novata', posicao: 0, liga: ''),
        ],
      );
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final texto = textoDaTela(tester);
      expect(texto, contains('Novata'));
      expect(texto, contains('—'));
      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('Bronze')));
    });

    testWidgets('N11g — fora do escopo de ranking a tela não afirma nada', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RankingDeProducao()));
      await tester.pumpAndSettle();

      final texto = textoDaTela(tester);
      expect(texto, contains('ainda não está sendo publicado'));
      expect(texto, isNot(contains('Ninguém classificado')));
    });
  });

  // =========================================================================
  // N12–N13 — maquete continua sem ligação produtiva
  // =========================================================================
  group('N12–N13 — nada de maquete no caminho', () {
    late Set<String> alcancaveis;

    setUpAll(() {
      alcancaveis = alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis, contains('lib/casca/ranking_de_producao.dart'));
      expect(alcancaveis, contains('lib/casca/navegacao_perfil_publico.dart'));
    });

    test('N12 — Hall, Amigos e a tela de Ranking de maquete ficam de fora', () {
      // REANCORADO PARA A RAIZ P.
      //
      // `hall_screen` e `ranking_screen` deixaram de ser maquete: a integração
      // Ranking/Ligas/Hall removeu `HallVM.mock()` e `RankingVM.mock()` dos dois
      // arquivos, e eles viraram apresentação pura, alimentada por
      // `HallService`/`RankingService`. A raiz P sozinha já os alcança.
      //
      // `amigos_screen` continua órfã, e continua proibida pelos DOIS lados —
      // caminho e construção.
      expect(
        alcancaveis,
        isNot(contains('lib/screens/amigos_screen.dart')),
        reason: 'a maquete de Amigos entrou num caminho que nasce em main()',
      );
      expect(quemConstroi(alcancaveis, 'AmigosScreen'), isEmpty);

      // E as duas telas promovidas não podem ter trazido a maquete de volta.
      for (final fabrica in const ['HallVM.mock', 'RankingVM.mock']) {
        final constroem = alcancaveis.where((c) {
          final f = File(c);
          if (!f.existsSync()) return false;
          final fonte = semComentarios(f);
          if (!fonte.contains('$fabrica(')) return false;
          return !fonte.contains('factory $fabrica(');
        }).toList();
        expect(
          constroem,
          isEmpty,
          reason: '$fabrica voltou a ser construída no caminho de produção',
        );
      }
    });

    test('N13 — nenhum slug de maquete existe no código alcançável', () {
      // REANCORADO PARA A RAIZ P: a varredura passa a descontar o factory.
      //
      // Estes slugs continuam proibidos, e a raiz P os tem — em
      // `loja_screen.dart` e `loja_categoria_screen.dart`, DENTRO do factory
      // `LojaVM.mock()`, que a Loja de produção não chama (ela monta o próprio
      // VM). É fixture declarada: a mesma categoria de `PerfilVM.mock()`, que
      // esta suíte já aceitava por viver em arquivo alcançável.
      //
      // A busca desconta o corpo dos factories `.mock()` e continua exigindo
      // ZERO fora deles — que é onde o slug faria mal, porque só dali ele
      // poderia chegar a `publicIdVisitado`.
      const slugs = [
        "'beto'",
        "'claudia'",
        "'fernanda'",
        "'mateus'",
        "'sofia'",
        "'larissa'",
        "'ricardo'",
        "'voce'",
        'SONIA-RAINHA',
      ];
      final achados = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        var fonte = semComentarios(f);
        final mock = fonte.indexOf('.mock(');
        if (mock >= 0) {
          final abre = fonte.lastIndexOf('factory', mock);
          if (abre >= 0) fonte = fonte.substring(0, abre);
        }
        for (final slug in slugs) {
          if (fonte.contains(slug)) achados.add('$caminho: $slug');
        }
      }
      expect(achados, isEmpty);
    });

    test('N13b — `publicIdVisitado` só recebe o campo da projeção', () {
      // REANCORADO PARA A RAIZ P, e a prova ficou mais forte.
      //
      // A linhagem funcional tinha um alimentador só. A raiz P tem outros dois,
      // anteriores a esta composição. A lista continua EXAUSTIVA e cada
      // expressão é nomeada: nenhuma é posição, índice ou uid.
      // `souEu ? null : id` vem de `idNaPosicao`, que resolve posição -> ID
      // PÚBLICO dentro da página que a tela já tem em mãos e devolve `null`
      // quando a fonte não publicou id — a posição nunca vira chave de
      // navegação. O `id` do Hall vem da projeção do `HallService`.
      final achados = <String>[];
      final atribuicao = RegExp(r'publicIdVisitado\s*:\s*([^,)\n]+)');
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final fonte = semComentarios(f);
        if (RegExp(r'class\s+PerfilPage\b').hasMatch(fonte)) continue;
        for (final m in atribuicao.allMatches(fonte)) {
          achados.add('${_barras(caminho)} -> ${m.group(1)!.trim()}');
        }
      }
      expect(achados, [
        'lib/pages/ranking_page.dart -> souEu ? null : id',
        'lib/pages/hall_page.dart -> id',
        'lib/casca/navegacao_perfil_publico.dart -> jogador.publicPlayerId',
      ], reason: 'alguém passou a alimentar o Perfil visitado por outra fonte');

      // E ninguém pode passar a identificar o visitado por posição/índice/uid.
      for (final proibido in const [
        'publicIdVisitado: posicao',
        'publicIdVisitado: index',
        'publicIdVisitado: uid',
        'publicIdVisitado: user.uid',
      ]) {
        for (final caminho in alcancaveis) {
          final f = File(caminho);
          if (!f.existsSync()) continue;
          expect(
            semComentarios(f),
            isNot(contains(proibido)),
            reason: '$caminho passou a identificar o visitado por $proibido',
          );
        }
      }
    });

    test('N13c — o Perfil VISITADO é construído num lugar só', () {
      // REANCORADO PARA A RAIZ P: os produtores viraram LISTA FECHADA.
      //
      // Na linhagem funcional havia dois. A raiz P chegou com mais tres, todos
      // anteriores a esta composição: as páginas da integração Ranking/Ligas/
      // Hall e o host da Loja. A lista continua FECHADA — um sexto produtor
      // reprova —, e o que era "um lugar só" virou "estes cinco, e cada um
      // provado em N13b".
      expect(quemConstroi(alcancaveis, 'PerfilPage'), [
        'lib/casca/home_de_producao.dart',
        'lib/casca/loja_de_producao.dart',
        'lib/casca/navegacao_perfil_publico.dart',
        'lib/pages/hall_page.dart',
        'lib/pages/ranking_page.dart',
      ]);

      // E a Home constrói SÓ a forma do dono: nada de id de terceiro ali.
      final home = semComentarios(File('lib/casca/home_de_producao.dart'));
      expect(home, contains('const PerfilPage()'));
      expect(home, isNot(contains('publicIdVisitado')));
      expect(home, isNot(contains('ehMeuPerfil')));
    });

    test('N13d — a tela do ranking não tem jogador escrito dentro', () {
      final fonte = semComentarios(
        File('lib/casca/ranking_de_producao.dart'),
      );
      expect(fonte, isNot(contains('.mock(')));
      for (final proibido in const [
        'JogadorPublicoRanking(',
        'Bronze',
        'Diamante',
      ]) {
        expect(
          fonte,
          isNot(contains(proibido)),
          reason: 'a tela passou a fabricar $proibido',
        );
      }
    });
  });

  // =========================================================================
  // N16 — a porta produtiva a partir do Perfil
  // =========================================================================
  group('N16 — o Perfil abre o ranking real', () {
    testWidgets('N16a — a linha competitiva leva ao ranking', (tester) async {
      final transporte = TransporteEspiao();
      final ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      final sessao = SessaoDoJogador(fonte: FonteRegulavel(), uids: auth.stream);
      addTearDown(sessao.dispose);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: EscopoRanking(
            ranking: ranking,
            child: const MaterialApp(home: PerfilPage()),
          ),
        ),
      );
      await assentar(tester);
      expect(find.byType(PerfilScreen), findsOneWidget);
      final aberturasAntes = transporte.chamadasAbertura;

      await tester.tap(find.bySemanticsLabel('Ver o ranking completo'));
      await assentar(tester);

      expect(find.byType(RankingDeProducao), findsOneWidget);
      expect(textoDaTela(tester), contains('Primeira'));
      // ABRIR NÃO PERGUNTA: a tela lê o estado que o Perfil já consumia.
      expect(
        transporte.chamadasAbertura,
        aberturasAntes,
        reason: 'abrir o ranking abriu uma callable nova',
      );
    });

    testWidgets('N16b — sem callback, a linha competitiva não vira botão', (
      tester,
    ) async {
      // O catálogo visual e as dezenas de testes que montam a tela sem casca
      // continuam com o desenho de sempre.
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(
            vm: PerfilVM.mock().comRanking(
              const EstadoRanking.disponivel(
                liga: 'Ouro',
                posicaoMundial: 12,
                ligaId: 'ouro',
              ),
            ),
            onVoltar: () {},
            onAbrirConfig: () {},
            onTrocarAvatar: () {},
            onEditarNick: () {},
            onEditarPerfil: () {},
            onAbrirPresentes: () {},
            onFecharPresentes: () {},
            onVerTodasConquistas: () {},
            onVerConquista: (_) {},
            onVerUltimaConquista: () {},
            onTrocarVitrine: () {},
            onCompartilhar: () {},
            onRecarregar: () {},
            onNavTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Ver o ranking completo'), findsNothing);
      // E a frase da classificação continua exatamente a mesma.
      expect(
        find.bySemanticsLabel('Liga Ouro. Posição 12 no mundo.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
