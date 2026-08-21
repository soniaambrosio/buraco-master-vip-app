// leitor_ranking_real_test.dart — a prova de que o ranking exibido é o que a
// autoridade disse, e de que ele pertence a quem está olhando.
//
// ---------------------------------------------------------------------------
// O QUE MUDOU DE ALVO
// ---------------------------------------------------------------------------
//
// `estado_canonico_ranking_test.dart` provou que a casca não INVENTA liga. Esta
// suíte prova a metade seguinte, que só passou a existir agora que há backend:
// que a liga exibida VEIO da autoridade, e que ela não é de outra pessoa, de
// outra temporada nem de uma pergunta que ninguém está mais fazendo.
//
// O perigo mudou de forma. Antes era um literal escrito no código. Agora é um
// valor verdadeiro, aplicado tarde demais — a liga do jogador A aparecendo para
// o B depois de uma troca de conta é pior que Bronze inventado, porque parece
// certo.
//
// NENHUM ATRASO REAL. O transporte falso resolve quando o teste manda, e é isso
// que torna "a resposta antiga chega depois da nova" um caso determinístico em
// vez de uma corrida que passa nove vezes em dez.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/estado_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

/// A resposta de `abrirRanking` para um jogador que ESTÁ na tabela.
Map<String, Object?> aberturaCom({
  required String liga,
  required int posicao,
  String? ligaId = 'bronze',
  String? temporadaId = 'T-2026-01',
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'divisao': null,
    'podio': const [],
    'escadaLigas': const [],
    'eu': {
      'id': 'P0A1B2C3D4E5',
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

/// A resposta de `abrirRanking` para quem ainda não pontuou: `eu` NULO.
Map<String, Object?> aberturaSemColocacao({
  String? temporadaId = 'T-2026-01',
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'divisao': null,
    'podio': const [],
    'escadaLigas': const [],
    'eu': null,
  },
  'primeiraPagina': const {'itens': [], 'cursorProxima': null, 'fim': true},
};

/// A resposta de `consultarJogadorPorIdPublico`.
Map<String, Object?> perfilPublicoCom({
  required String id,
  required String liga,
  required int posicao,
  String? ligaId = 'ouro',
  String? temporadaId = 'T-2026-01',
}) => {
  'id': id,
  'temporadaId': temporadaId,
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

/// Transporte cuja resposta o teste escolhe, e cujo MOMENTO o teste escolhe.
class TransporteFalso extends TransporteRanking {
  TransporteFalso();

  /// Quando `true`, cada chamada fica pendurada até o teste completá-la.
  bool manual = false;

  final List<Completer<FotografiaRanking>> pendentesProprio = [];
  final List<Completer<FotografiaRanking>> pendentesPublico = [];
  final List<String> idsConsultados = [];

  Object? respostaPropria;
  Object? respostaPublica;
  FalhaRanking? falhaPropria;

  int chamadasProprio = 0;
  int chamadasPublico = 0;

  /// Uma abertura sem tabela encenada: estas suítes provam as guardas sobre o
  /// CABEÇALHO, e a tabela vazia é o que a autoridade devolve numa temporada
  /// sem classificado — nada de inventar jogadores aqui.
  static AberturaRanking _abertura(FotografiaRanking eu) => AberturaRanking(
    eu: eu,
    tabela: const TabelaRanking(podio: [], primeiraPagina: []),
  );

  @override
  Future<AberturaRanking> abrirRanking() async {
    chamadasProprio++;
    if (manual) {
      final c = Completer<FotografiaRanking>();
      pendentesProprio.add(c);
      return _abertura(await c.future);
    }
    final falha = falhaPropria;
    if (falha != null) return Future<AberturaRanking>.error(falha);
    return _abertura(FotografiaRanking.daAbertura(respostaPropria));
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) {
    chamadasPublico++;
    idsConsultados.add(publicId);
    if (manual) {
      final c = Completer<FotografiaRanking>();
      pendentesPublico.add(c);
      return c.future;
    }
    return Future.value(FotografiaRanking.doPerfilPublico(respostaPublica));
  }
}

PerfilVM vmCom(EstadoRanking ranking) => PerfilVM(
  ehMeuPerfil: true,
  nome: 'Sônia',
  avatar: '👑',
  mascote: '🦊',
  moldura: 'assets/perfil/vitrine_moldura.webp',
  dorso: 'assets/perfil/vitrine_dorso.webp',
  efeito: 'assets/perfil/vitrine_efeito.webp',
  nivel: 7,
  xpAtual: 0,
  xpProximo: 1000,
  titulo: 'Novato(a)',
  tituloEmoji: '🃏',
  ranking: ranking,
  stats: const PerfilStats(
    vitorias: 0,
    partidas: 0,
    canastras: 0,
    aproveitamento: 0,
  ),
  ultimaConquista: null,
  presentesCount: 0,
  conquistas: const [],
  vitrine: const [],
  presentes: const [],
);

Future<void> montarPerfil(WidgetTester tester, EstadoRanking ranking) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: vmCom(ranking),
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
}

String textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// O arquivo SEM comentários, respeitando aspas. Mesma técnica de
/// `estado_canonico_ranking_test.dart` — uma auditoria que lê comentário se
/// auto-sabota, e "consertar" seria apagar a explicação do defeito.
String codigo(File f) {
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

const contaA = 'P0A1B2C3D4E5';
const contaB = 'P9Z8Y7X6W5V4';

void main() {
  // =========================================================================
  // 1 e 2 — as duas callables, lidas de verdade
  // =========================================================================
  group('o transporte lê o contrato real', () {
    test('CASO 1 — abrirRanking devolve a fotografia do próprio jogador', () {
      final foto = FotografiaRanking.daAbertura(
        aberturaCom(liga: 'Ouro', posicao: 128, ligaId: 'ouro'),
      );
      expect(foto.rotuloLiga, 'Ouro');
      expect(foto.ligaId, 'ouro');
      expect(foto.posicao, 128);
      expect(foto.temporadaId, 'T-2026-01');
      expect(foto.classificado, isTrue);
    });

    test('CASO 2 — consultarJogadorPorIdPublico devolve a do visitado', () {
      final foto = FotografiaRanking.doPerfilPublico(
        perfilPublicoCom(
          id: contaB,
          liga: 'Prata',
          posicao: 7,
          ligaId: 'prata',
        ),
      );
      expect(foto.rotuloLiga, 'Prata');
      expect(foto.posicao, 7);
      expect(foto.classificado, isTrue);
    });

    test('`eu: null` é resposta legítima, e não erro', () {
      final foto = FotografiaRanking.daAbertura(aberturaSemColocacao());
      expect(foto.classificado, isFalse);
      expect(foto.rotuloLiga, isEmpty);
      expect(foto.posicao, 0);
      // A temporada sobrevive: é dela que a fotografia vazia faz parte.
      expect(foto.temporadaId, 'T-2026-01');
    });

    test('`classificado: false` também', () {
      final foto = FotografiaRanking.doPerfilPublico({
        'id': contaB,
        'temporadaId': 'T-2026-01',
        'classificado': false,
        'jogador': null,
      });
      expect(foto.classificado, isFalse);
      expect(EstadoRanking.daFotografia(foto).temAlgumDado, isFalse);
    });
  });

  // =========================================================================
  // 3 a 7 e 17 — o que o valor real vira na tela
  // =========================================================================
  group('a fotografia real vira estado honesto', () {
    EstadoRanking doWire(Map<String, Object?> m) =>
        EstadoRanking.daFotografia(FotografiaRanking.daAbertura(m));

    test('CASO 3 — liga presente e posição positiva atravessam', () {
      final e = doWire(aberturaCom(liga: 'Ouro', posicao: 128, ligaId: 'ouro'));
      expect(e.liga, 'Ouro');
      expect(e.posicaoMundial, 128);
      expect(e.ehLigaDeVerdade, isTrue);
      expect(e.temporadaId, 'T-2026-01');
    });

    test('CASO 4 — posição ZERO da autoridade não é colocação', () {
      // `POSICAO_NAO_APURADA` é literalmente `0` no backend. Este é o caso em
      // que o contrato real produz o valor que gerava o `#0`.
      final e = doWire(aberturaCom(liga: 'Prata', posicao: 0, ligaId: 'prata'));
      expect(e.liga, 'Prata');
      expect(e.posicaoMundial, isNull);
      expect(e.temPosicao, isFalse);
    });

    test('CASO 5 — posição negativa também não', () {
      final e = doWire(aberturaCom(liga: 'Prata', posicao: -3));
      expect(e.posicaoMundial, isNull);
    });

    test('CASO 6 — liga vazia ou só de espaços não é liga', () {
      expect(doWire(aberturaCom(liga: '', posicao: 5)).liga, isNull);
      expect(doWire(aberturaCom(liga: '   ', posicao: 5)).liga, isNull);
      // E sem liga o rótulo não vira uma: o travessão é ausência admitida.
      expect(doWire(aberturaCom(liga: '', posicao: 5)).ligaParaExibicao, '—');
    });

    test('CASO 7 — ausência total: fase disponível, nada afirmado', () {
      final e = doWire(aberturaSemColocacao());
      expect(e.fase, FaseRanking.disponivel);
      expect(e.liga, isNull);
      expect(e.posicaoMundial, isNull);
      expect(e.temAlgumDado, isFalse);
    });

    test('CASO 17 — Bronze REAL da autoridade é preservado', () {
      // A auditoria estrutural proíbe o literal `Bronze` em código alcançável.
      // Este teste é o outro lado da mesma moeda: um Bronze que veio de fora
      // NÃO pode desaparecer só por ter o mesmo texto do antigo placeholder.
      final e = doWire(
        aberturaCom(liga: 'Bronze', posicao: 4217, ligaId: 'bronze'),
      );
      expect(e.liga, 'Bronze');
      expect(e.posicaoMundial, 4217);
      expect(e.ehLigaDeVerdade, isTrue);
    });

    test('rótulo de qualificação não é uma Liga', () {
      // `ligaId: null` com rótulo preenchido é como o backend diz "em
      // colocação". O texto é exibível; a palavra "Liga" na frente, não.
      final e = doWire(
        aberturaCom(liga: 'Em colocacao', posicao: 0, ligaId: null),
      );
      expect(e.liga, 'Em colocacao');
      expect(e.ehLigaDeVerdade, isFalse);
    });
  });

  // =========================================================================
  // 15 e 16 — o que fazer quando não vem fotografia
  // =========================================================================
  group('falhas viram fases, e cada fase oferece outra coisa', () {
    test('CASO 15 — erro de autenticação não vira "sem ranking"', () {
      // A afirmação original deste caso continua valendo nos DOIS ramos: recusa
      // de acesso nunca é ausência de ranking, e nunca carrega liga.
      //
      // O que mudou é que o motivo deixou de se chamar `naoAutenticado`: o
      // código `unauthenticated` também chega de App Check ausente ou inválido,
      // e a decisão sobre a sessão passou a exigir prova.
      final semSessao = EstadoRanking.daFalha(
        MotivoFalhaRanking.credencialOuAtestacao,
        haSessaoLocal: false,
      );
      expect(semSessao.fase, FaseRanking.sessaoInvalida);
      // Sem sessão, insistir só repete a recusa.
      expect(semSessao.podeTentarDeNovo, isFalse);
      expect(semSessao.liga, isNull);

      final comSessao = EstadoRanking.daFalha(
        MotivoFalhaRanking.credencialOuAtestacao,
        haSessaoLocal: true,
      );
      expect(comSessao.fase, FaseRanking.acessoRecusado);
      expect(comSessao.fase, isNot(FaseRanking.indisponivel));
      expect(comSessao.liga, isNull);
    });

    test('CASO 16 — payload malformado é falha, e não ausência', () {
      expect(
        () => FotografiaRanking.daAbertura({'resumo': 'isto não é um objeto'}),
        throwsA(isA<FalhaRanking>()),
      );
      expect(
        () => FotografiaRanking.daAbertura({
          'resumo': {'eu': <String, Object?>{}},
        }),
        throwsA(isA<FalhaRanking>()),
      );
      // `classificado: true` sem jogador é contradição do contrato, e não uma
      // metade a completar.
      expect(
        () => FotografiaRanking.doPerfilPublico({
          'id': contaB,
          'classificado': true,
          'jogador': null,
        }),
        throwsA(isA<FalhaRanking>()),
      );
      final e = EstadoRanking.daFalha(
        MotivoFalhaRanking.respostaInvalida,
        haSessaoLocal: true,
      );
      expect(e.fase, FaseRanking.falha);
      expect(e.podeTentarDeNovo, isTrue);
    });

    test('sem temporada é ausência declarada, não erro', () {
      final e = EstadoRanking.daFalha(
        MotivoFalhaRanking.semTemporada,
        haSessaoLocal: true,
      );
      expect(e.fase, FaseRanking.indisponivel);
      expect(e.podeTentarDeNovo, isFalse);
    });
  });

  // =========================================================================
  // 8 a 14 — o leitor: ordem, sessão e cache
  // =========================================================================
  group('o leitor protege a resposta contra o tempo', () {
    late TransporteFalso transporte;
    late LeitorDeRanking leitor;

    setUp(() {
      transporte = TransporteFalso();
      leitor = LeitorDeRanking(transporte: transporte);
    });

    test('CASO 8 — falha, retry, sucesso', () async {
      transporte.falhaPropria = const FalhaRanking(
        MotivoFalhaRanking.indisponivel,
        'unavailable',
      );
      final primeiro = await leitor.meuRanking(contaPublicId: contaA);
      expect(primeiro!.fase, FaseRanking.falha);
      expect(primeiro.podeTentarDeNovo, isTrue);

      transporte.falhaPropria = null;
      transporte.respostaPropria = aberturaCom(liga: 'Ouro', posicao: 3);
      final segundo = await leitor.meuRanking(contaPublicId: contaA);
      expect(segundo!.liga, 'Ouro');
      expect(segundo.posicaoMundial, 3);
    });

    test('retry é idempotente: três toques, uma chamada', () async {
      transporte.manual = true;
      final a = leitor.meuRanking(contaPublicId: contaA);
      final b = leitor.meuRanking(contaPublicId: contaA);
      final c = leitor.meuRanking(contaPublicId: contaA);
      expect(transporte.chamadasProprio, 1);
      transporte.pendentesProprio.single.complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Ouro', posicao: 3)),
      );
      expect((await a)!.liga, 'Ouro');
      expect((await b)!.liga, 'Ouro');
      expect((await c)!.liga, 'Ouro');
    });

    test('CASO 9 — a resposta antiga não sobrescreve a nova', () async {
      transporte.manual = true;
      final antiga = leitor.meuRanking(contaPublicId: contaA);
      // A sessão recarrega: o voo anterior perde o direito de responder, e uma
      // pergunta nova é emitida.
      leitor.aoMudarSessao(1);
      final nova = leitor.meuRanking(contaPublicId: contaA);
      expect(transporte.pendentesProprio.length, 2);

      // A NOVA responde primeiro, e a ANTIGA chega depois — a ordem que quebra
      // implementações ingênuas.
      transporte.pendentesProprio[1].complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Lenda', posicao: 1)),
      );
      transporte.pendentesProprio[0].complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Prata', posicao: 900)),
      );

      expect((await nova)!.liga, 'Lenda');
      // `null` é descarte: quem chamou não publica nada.
      expect(await antiga, isNull);
      // E o cache guardou a nova, não a atrasada.
      expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Lenda');
    });

    test('CASO 10 — logout durante a chamada descarta a resposta', () async {
      transporte.manual = true;
      final voo = leitor.meuRanking(contaPublicId: contaA);
      leitor.aoMudarSessao(1); // logout
      transporte.pendentesProprio.single.complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Ouro', posicao: 3)),
      );
      expect(await voo, isNull);
      // Nem o cache recebeu: a resposta é de uma sessão que acabou.
      expect(leitor.emCache(contaPublicId: contaA), isNull);
    });

    test('CASO 11 — troca de jogador durante a chamada', () async {
      transporte.manual = true;
      final vooDeA = leitor.meuRanking(contaPublicId: contaA);
      leitor.aoMudarSessao(1);
      final vooDeB = leitor.meuRanking(contaPublicId: contaB);

      // A resposta de A chega DEPOIS de B já estar logado.
      transporte.pendentesProprio[0].complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Lenda', posicao: 1)),
      );
      transporte.pendentesProprio[1].complete(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Prata', posicao: 500)),
      );

      expect(await vooDeA, isNull);
      expect((await vooDeB)!.liga, 'Prata');
      expect(leitor.emCache(contaPublicId: contaA), isNull);
    });

    test('CASO 12 — dois publicId simultâneos não se atropelam', () async {
      transporte.manual = true;
      final x = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: 'PXXXXXXXXXXX',
      );
      final y = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: 'PYYYYYYYYYYY',
      );
      expect(transporte.chamadasPublico, 2);
      expect(transporte.idsConsultados, ['PXXXXXXXXXXX', 'PYYYYYYYYYYY']);

      // Fora de ordem, de propósito.
      transporte.pendentesPublico[1].complete(
        FotografiaRanking.doPerfilPublico(
          perfilPublicoCom(id: 'PYYYYYYYYYYY', liga: 'Ouro', posicao: 2),
        ),
      );
      transporte.pendentesPublico[0].complete(
        FotografiaRanking.doPerfilPublico(
          perfilPublicoCom(id: 'PXXXXXXXXXXX', liga: 'Prata', posicao: 50),
        ),
      );

      // CADA UM COM O SEU. Um contador global de sequência faria o primeiro
      // virar descarte sem motivo — os dois pedidos são legítimos.
      expect((await x)!.liga, 'Prata');
      expect((await y)!.liga, 'Ouro');
    });

    test('CASO 13 — o cache não vaza entre jogadores', () async {
      transporte.respostaPropria = aberturaCom(liga: 'Lenda', posicao: 1);
      await leitor.meuRanking(contaPublicId: contaA);
      expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Lenda');

      // Sem troca de sessão, perguntar por outra conta não encontra nada dela.
      expect(leitor.emCache(contaPublicId: contaB), isNull);

      // E com troca de sessão, o de A morre.
      leitor.aoMudarSessao(1);
      expect(leitor.emCache(contaPublicId: contaA), isNull);
    });

    test('o perfil próprio e o visitado não dividem entrada', () async {
      transporte.respostaPropria = aberturaCom(liga: 'Lenda', posicao: 1);
      transporte.respostaPublica = perfilPublicoCom(
        id: 'PXXXXXXXXXXX',
        liga: 'Prata',
        posicao: 50,
      );
      await leitor.meuRanking(contaPublicId: contaA);
      await leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: 'PXXXXXXXXXXX',
      );
      expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Lenda');
      expect(
        leitor
            .emCache(contaPublicId: contaA, alvoPublicId: 'PXXXXXXXXXXX')!
            .liga,
        'Prata',
      );
    });

    test(
      'CASO 14 — virada de temporada invalida a fotografia anterior',
      () async {
        transporte.respostaPublica = perfilPublicoCom(
          id: 'PXXXXXXXXXXX',
          liga: 'Prata',
          posicao: 50,
          temporadaId: 'T-2026-01',
        );
        await leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: 'PXXXXXXXXXXX',
        );
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: 'PXXXXXXXXXXX'),
          isNotNull,
        );

        // Uma resposta de OUTRA temporada chega para outro alvo. A fotografia
        // velha não é "ainda válida": ela é de uma temporada que acabou.
        transporte.respostaPropria = aberturaCom(
          liga: 'Ouro',
          posicao: 3,
          temporadaId: 'T-2026-02',
        );
        await leitor.meuRanking(contaPublicId: contaA);

        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: 'PXXXXXXXXXXX'),
          isNull,
        );
        expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T-2026-02');
      },
    );

    test('exceção fora do vocabulário não derruba quem chamou', () async {
      transporte.manual = true;
      final voo = leitor.meuRanking(contaPublicId: contaA);
      transporte.pendentesProprio.single.completeError(StateError('boom'));
      final estado = await voo;
      expect(estado!.fase, FaseRanking.falha);
    });
  });

  // =========================================================================
  // 19 e 20 — as superfícies
  // =========================================================================
  group('Home e Perfil leem a mesma autoridade', () {
    testWidgets('CASO 19 — o mesmo objeto alimenta as duas', (tester) async {
      final transporte = TransporteFalso()
        ..respostaPropria = aberturaCom(
          liga: 'Ouro',
          posicao: 128,
          ligaId: 'ouro',
        );
      final ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);

      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      // Enquanto a consulta corre, o estado é `carregando` — e não uma liga.
      expect(ranking.meuEstado.fase, FaseRanking.carregando);
      expect(ranking.meuEstado.liga, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoRanking(
            ranking: ranking,
            child: Builder(
              builder: (context) =>
                  Text(EscopoRanking.meuEstadoDe(context).ligaParaExibicao),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ranking.meuEstado.liga, 'Ouro');
      // A tela que lê pelo escopo vê exatamente isso. Não há segunda consulta:
      // uma autoridade, um valor.
      expect(find.text('Ouro'), findsOneWidget);
      expect(transporte.chamadasProprio, 1);
    });

    testWidgets('a Home não mostra rótulo de qualificação como liga', (
      tester,
    ) async {
      final transporte = TransporteFalso()
        ..respostaPropria = aberturaCom(
          liga: 'Em colocacao',
          posicao: 0,
          ligaId: null,
        );
      final ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoRanking(ranking: ranking, child: const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(ranking.meuEstado.ehLigaDeVerdade, isFalse);
    });

    test('CASO 20 — sem autoridade, o convite não cita liga', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        vmCom(rankingDaCascaPublicavel),
      );
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('#')));
    });

    test('com autoridade, o convite cita o que ela disse', () {
      final estado = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(
          aberturaCom(liga: 'Bronze', posicao: 4217, ligaId: 'bronze'),
        ),
      );
      final texto = PerfilPage.textoDeCompartilhamento(vmCom(estado));
      expect(texto, contains('Liga Bronze'));
      expect(texto, contains('#4217 no mundo'));
    });

    test('posição zero da autoridade não sai do aparelho', () {
      final estado = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(aberturaCom(liga: 'Prata', posicao: 0)),
      );
      final texto = PerfilPage.textoDeCompartilhamento(vmCom(estado));
      expect(texto, contains('Liga Prata'));
      expect(texto, isNot(contains('#')));
    });
  });

  // =========================================================================
  // 21 e §6 — acessibilidade
  // =========================================================================
  group('a linha competitiva é anunciada, e não soletrada', () {
    testWidgets('CASO 21a — liga com posição', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(
        tester,
        const EstadoRanking.disponivel(
          liga: 'Ouro',
          posicaoMundial: 128,
          ligaId: 'ouro',
        ),
      );
      expect(
        find.bySemanticsLabel('Liga Ouro. Posição 128 no mundo.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CASO 21b — liga sem posição válida', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(
        tester,
        const EstadoRanking.disponivel(
          liga: 'Prata',
          posicaoMundial: 0,
          ligaId: 'prata',
        ),
      );
      expect(
        find.bySemanticsLabel('Liga Prata. Sem colocação no mundo.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CASO 21c — ranking indisponível', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, rankingDaCascaPublicavel);
      expect(
        find.bySemanticsLabel('Classificação ainda não disponível.'),
        findsOneWidget,
      );
      // E o travessão visual NÃO é anunciado como "traço".
      expect(find.bySemanticsLabel('—'), findsNothing);
      handle.dispose();
    });

    testWidgets('CASO 21d — atualização em andamento', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, const EstadoRanking.carregando());
      expect(
        find.bySemanticsLabel('Carregando sua classificação.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CASO 21e — falha com ação de tentar novamente', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, const EstadoRanking.falha());
      expect(
        find.bySemanticsLabel(
          'Não foi possível carregar sua classificação. '
          'Use o botão de tentar novamente.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('sessão inválida não promete retry', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, const EstadoRanking.sessaoInvalida());
      expect(
        find.bySemanticsLabel(
          'Classificação indisponível: entre na sua conta de novo.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('sem colocação nenhuma: "ainda não classificado"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, const EstadoRanking.disponivel());
      expect(find.bySemanticsLabel('Ainda não classificado.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CASO 18 — nenhum fallback aparece na tela sem autoridade', (
      tester,
    ) async {
      await montarPerfil(tester, rankingDaCascaPublicavel);
      final texto = textoDaTela(tester);
      for (final liga in const ['Bronze', 'Prata', 'Ouro', 'Diamante']) {
        expect(texto, isNot(contains(liga)), reason: '$liga apareceu do nada');
      }
      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('no mundo')));
    });
  });

  // =========================================================================
  // 22 — auditoria estrutural
  // =========================================================================
  group('auditoria — o literal competitivo não pode nascer no cliente', () {
    final arquivosDoRanking = Directory('lib/ranking')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    setUpAll(() {
      // Sem isto, o grupo inteiro seria um verde falso.
      expect(arquivosDoRanking, isNotEmpty);
    });

    test('nenhum nome de liga é escrito no módulo de ranking', () {
      // É o que o Caso A do contrato exige: o backend manda o rótulo pronto, e
      // um mapa local de nomes seria uma segunda autoridade sobre como as ligas
      // se chamam — que divergiria no primeiro dia em que uma fosse renomeada.
      //
      // A LISTA ABAIXO É DE PROIBIÇÃO, e por isso ela contém tanto os sete
      // nomes oficiais quanto `Imperial`, que NÃO é uma Liga. A canonização das
      // sete Ligas tirou Imperial da autoridade; mantê-la proibida aqui é o que
      // impede que ela volte pelo cliente, que é por onde ela entrou da
      // primeira vez. `Mestre` entrou na lista pelo mesmo motivo dos outros
      // seis: nome de Liga não se escreve no cliente, nem o novo.
      for (final f in arquivosDoRanking) {
        final fonte = codigo(f);
        for (final liga in const [
          'Bronze',
          'Prata',
          'Ouro',
          'Diamante',
          'Platina',
          'Mestre',
          'Imperial',
          'Lenda',
        ]) {
          expect(
            fonte,
            isNot(contains("'$liga'")),
            reason: '${f.path} passou a nomear ligas por conta própria',
          );
        }
      }
    });

    test('nenhum arquivo do ranking imprime identificador', () {
      // Diagnóstico com publicId é vazamento com outro nome.
      for (final f in arquivosDoRanking) {
        final fonte = codigo(f);
        expect(fonte, isNot(contains('print(')), reason: f.path);
        expect(fonte, isNot(contains('debugPrint')), reason: f.path);
      }
    });

    test('só o adaptador de Firebase conhece cloud_functions', () {
      // A fronteira que mantém leitor, estado e fotografia testáveis sem
      // emulador. Se ela vazar, os casos de concorrência acima deixam de ser
      // encenáveis e passam a exigir rede.
      final comFirebase = arquivosDoRanking
          .where((f) => codigo(f).contains('cloud_functions'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(comFirebase, ['lib/ranking/ranking_transporte_firebase.dart']);
    });

    test('a região das callables casa com a do backend', () {
      final fonte = codigo(
        File('lib/ranking/ranking_transporte_firebase.dart'),
      );
      // A mesma de `functions-ranking/src/index.ts`. Errar a região devolve
      // `not-found`, que é fácil de confundir com "jogador sem colocação".
      expect(fonte, contains("'southamerica-east1'"));
      expect(fonte, contains("'abrirRanking'"));
      expect(fonte, contains("'consultarJogadorPorIdPublico'"));
    });
  });
}
