// barreira_temporal_ranking_test.dart — a barreira temporal do leitor, no
// detalhe em que ela ainda vazava.
//
// ---------------------------------------------------------------------------
// O QUE A RODADA ANTERIOR NÃO PEGOU
// ---------------------------------------------------------------------------
//
// `regressao_leitor_ranking_test.dart` fechou o defeito A na ordem em que a OS
// o descreveu: a temporada nova chega pelo pedido de número MAIOR, e a atrasada
// pelo menor. A correção passou nessa ordem e continuou vazando na inversa.
//
//   R1 — dois pedidos em voo, #1 (próprio) e #2 (público).
//        O servidor atende #1 DEPOIS da virada  → devolve T2.
//        O servidor atende #2 ANTES da virada   → devolve T1.
//        Como `2 < 1` é falso, T1 passava: era devolvida como atual, entrava no
//        cache e despejava a fotografia de T2.
//
// A raiz não é a comparação em si — é a ÂNCORA. `_pedidoDaTemporada` guardava o
// número do pedido que ESTABELECEU a temporada. Um pedido posterior que apenas
// CONFIRMA a vigente não movia a âncora, então ela ficava presa lá atrás e tudo
// numerado acima dela passava.
//
// ---------------------------------------------------------------------------
// A REGRA QUE ESTA SUÍTE FIXA
// ---------------------------------------------------------------------------
//
// Só pode TROCAR a temporada aceita um pedido emitido DEPOIS de o cliente ter
// aprendido a temporada atual. Pedidos que já estavam em voo naquele instante
// são contemporâneos, não posteriores — e entre contemporâneos o cliente não
// tem como saber qual o servidor atendeu primeiro. Diante do desconhecido, ele
// mantém o que já sabe e espera a próxima pergunta, que é sequencialmente
// posterior e resolve sozinha.
//
// A âncora, portanto, é `_sequencia` no instante em que a temporada foi
// aprendida — e "aprendida" inclui CONFIRMADA, que era a linha que faltava.
//
// NENHUM ATRASO REAL: o transporte responde quando o teste manda.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
// `EstadoRanking`/`FaseRanking` chegam pelo `export` de `perfil_screen.dart`,
// que é a superfície que a casca declara.
import 'package:buraco_master_vip/screens/perfil_screen.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';
const contaB = 'P9Z8Y7X6W5V4';
const alvoX = 'PXX1XX2XX3XX';
const alvoY = 'PYY1YY2YY3YY';

FotografiaRanking foto({
  required String? temporadaId,
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int posicao = 7,
}) => FotografiaRanking(
  temporadaId: temporadaId,
  rotuloLiga: liga,
  ligaId: ligaId,
  posicao: posicao,
  classificado: true,
);

/// Transporte que só responde quando o teste manda, e por chamada nomeada.
class _TransporteManual extends TransporteRanking {
  final Map<String, List<Completer<FotografiaRanking>>> _fila =
      <String, List<Completer<FotografiaRanking>>>{};

  final List<String> emitidas = <String>[];

  Future<FotografiaRanking> _abrir(String chave) {
    emitidas.add(chave);
    final c = Completer<FotografiaRanking>();
    (_fila[chave] ??= <Completer<FotografiaRanking>>[]).add(c);
    return c.future;
  }

  // A fila continua sendo de fotografias: o que estas suítes encenam é a ORDEM
  // das respostas, e a tabela não participa disso. Vazia, e não ausente, porque
  // é o que a autoridade de verdade devolve numa abertura.
  @override
  Future<AberturaRanking> abrirRanking() async => AberturaRanking(
    eu: await _abrir('proprio'),
    tabela: const TabelaRanking(podio: [], primeiraPagina: []),
  );

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) =>
      _abrir('publico:$publicId');

  Completer<FotografiaRanking> pendente(String chave) =>
      _fila[chave]!.firstWhere((c) => !c.isCompleted);

  /// O n-ésimo pedido daquela chave, na ordem de emissão.
  ///
  /// Necessário porque [pendente] devolve sempre o MAIS ANTIGO, e os casos de
  /// troca de sessão precisam justamente do contrário: fazer o voo NOVO
  /// terminar antes do velho. Errar isso escreve um teste que encena a ordem
  /// oposta à que ele diz encenar — e passa por motivo nenhum.
  Completer<FotografiaRanking> pedido(String chave, int indice) =>
      _fila[chave]![indice];

  void responder(String chave, FotografiaRanking f) =>
      pendente(chave).complete(f);

  void falhar(String chave, MotivoFalhaRanking motivo) =>
      pendente(chave).completeError(FalhaRanking(motivo, 'teste'));

  int emitidasDe(String chave) => emitidas.where((e) => e == chave).length;
}

void main() {
  late _TransporteManual t;
  late LeitorDeRanking leitor;

  setUp(() {
    t = _TransporteManual();
    leitor = LeitorDeRanking(transporte: t);
  });

  // =========================================================================
  // R1 — a ordem inversa
  // =========================================================================
  group('R1 — a virada chega pelo pedido de número MENOR', () {
    test('R1a — T1 do pedido #2 não derruba T2 do pedido #1', () async {
      // Os dois nascem juntos, antes de qualquer resposta. É o que os torna
      // contemporâneos: nenhum foi emitido sabendo do resultado do outro.
      final vooProprio = leitor.meuRanking(contaPublicId: contaA); // #1
      final vooPublico = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      ); // #2

      // O servidor atendeu #1 DEPOIS da virada.
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      expect((await vooProprio)!.temporadaId, 'T2');

      // E #2 ANTES dela. Número maior, notícia mais velha — a combinação que
      // a rodada anterior deixava passar.
      t.responder(
        'publico:$alvoX',
        foto(temporadaId: 'T1', liga: 'Prata', ligaId: 'prata', posicao: 50),
      );

      expect(
        await vooPublico,
        isNull,
        reason: 'T1 de um pedido contemporâneo foi aceita como atual',
      );
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
      );
      // E a fotografia boa continua de pé.
      final propria = leitor.emCache(contaPublicId: contaA);
      expect(propria, isNotNull);
      expect(propria!.temporadaId, 'T2');
      expect(propria.liga, 'Ouro');
    });

    test('R1b — a ordem original continua fechada', () async {
      // A mesma prova de A1, refeita aqui para que R1 não conserte uma ordem
      // quebrando a outra. As duas têm de valer ao mesmo tempo.
      final vooPublico = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      ); // #1
      final vooProprio = leitor.meuRanking(contaPublicId: contaA); // #2

      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      expect((await vooProprio)!.temporadaId, 'T2');

      t.responder('publico:$alvoX', foto(temporadaId: 'T1', liga: 'Prata'));
      expect(await vooPublico, isNull);
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
    });

    test('R1c — a virada sequencial LEGÍTIMA continua sendo aceita', () async {
      // O contrapeso indispensável: apertar a barreira não pode transformar o
      // leitor em algo que nunca mais aprende que a temporada virou.
      final primeiro = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await primeiro;

      // Emitido DEPOIS de a resposta anterior ter chegado: é posterior de
      // verdade, e não contemporâneo.
      final segundo = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      final novo = await segundo;

      expect(novo, isNotNull);
      expect(novo!.temporadaId, 'T2');
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
    });
  });

  // =========================================================================
  // R2 — a confirmação reancora
  // =========================================================================
  group('R2 — confirmar a temporada move a âncora', () {
    test(
      'R2a — depois de confirmada, o contemporâneo divergente não passa',
      () async {
        // #1 estabelece T1.
        final p1 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
        await p1;

        // #2 e #3 nascem juntos.
        final p2 = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        ); // #2
        final p3 = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoY,
        ); // #3

        // #3 CONFIRMA T1. Sem reancorar, a âncora ficaria no pedido #1 e o
        // divergente #2 (2 > 1) passaria.
        t.responder('publico:$alvoY', foto(temporadaId: 'T1', liga: 'Ouro'));
        expect((await p3)!.temporadaId, 'T1');

        // #2 diverge, e é contemporâneo da confirmação.
        t.responder('publico:$alvoX', foto(temporadaId: 'T9', liga: 'Lenda'));
        expect(
          await p2,
          isNull,
          reason: 'a confirmação não reancorou a barreira',
        );
        // E a confirmação não pode ter despejado nada: T1 continua sendo T1.
        expect(
          leitor
              .emCache(contaPublicId: contaA, alvoPublicId: alvoY)!
              .temporadaId,
          'T1',
        );
        expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
      },
    );

    test(
      'R2b — a confirmação NÃO despeja o cache da própria temporada',
      () async {
        final p1 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
        await p1;

        final p2 = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        );
        t.responder('publico:$alvoX', foto(temporadaId: 'T1', liga: 'Ouro'));
        await p2;

        // As duas fotografias são da MESMA temporada: nenhuma é incompatível.
        expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Prata');
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX)!.liga,
          'Ouro',
        );
      },
    );

    test(
      'R2c — depois de reancorada, um pedido REALMENTE posterior vira',
      () async {
        final p1 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1'));
        await p1;

        final p2 = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        );
        t.responder('publico:$alvoX', foto(temporadaId: 'T1'));
        await p2;

        // Emitido depois de tudo: tem o direito de virar.
        final p3 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T2', liga: 'Lenda'));
        expect((await p3)!.temporadaId, 'T2');
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
          isNull,
          reason: 'a fotografia de T1 sobreviveu a uma virada legítima',
        );
      },
    );
  });

  // =========================================================================
  // R3 — pedido igual à barreira
  // =========================================================================
  group('R3 — resposta divergente cujo pedido EMPATA com a barreira', () {
    test('R3a — empate não é posterior: a divergente não passa', () async {
      // #1 e #2 nascem juntos, então `_sequencia` vale 2 quando #1 responde.
      // A âncora fica em 2, e o próprio #2 empata com ela.
      final p1 = leitor.meuRanking(contaPublicId: contaA); // #1
      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      ); // #2

      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await p1;

      t.responder('publico:$alvoX', foto(temporadaId: 'T2', liga: 'Ouro'));
      expect(
        await p2,
        isNull,
        reason: 'empate com a barreira foi tratado como posterior',
      );
      // A temporada aceita não se moveu, e o cache não foi despejado.
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
    });

    test('R3b — e o empate não deixa a barreira envenenada', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.responder('proprio', foto(temporadaId: 'T1'));
      await p1;
      t.responder('publico:$alvoX', foto(temporadaId: 'T2'));
      await p2;

      // A recusa acima não pode ter travado o leitor: o próximo pedido, este
      // sim posterior, aprende T2 normalmente.
      final p3 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Lenda'));
      expect((await p3)!.temporadaId, 'T2');
    });
  });

  // =========================================================================
  // R4 — temporada nula
  // =========================================================================
  group('R4 — `temporadaId` nulo é ausência de notícia', () {
    test('R4a — nulo não estabelece, não derruba e não despeja', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await p1;

      // O contrato publica `temporadaId: null` em
      // `consultarJogadorPorIdPublico` quando não há temporada vigente.
      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.responder('publico:$alvoX', foto(temporadaId: null, liga: 'Ouro'));
      final semTemporada = await p2;

      // Passa — não há nada de vencido numa resposta que não afirma temporada.
      expect(semTemporada, isNotNull);
      expect(semTemporada!.temporadaId, isNull);
      expect(semTemporada.liga, 'Ouro');
      // E não mexeu na aceita nem no cache alheio.
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
    });

    test('R4b — nulo não move a âncora', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      // #1 responde nulo: nada é aprendido, então a âncora continua zerada e a
      // primeira temporada real ainda pode ser estabelecida por quem vier.
      t.responder('proprio', foto(temporadaId: null));
      await p1;
      t.responder('publico:$alvoX', foto(temporadaId: 'T1', liga: 'Ouro'));
      final comTemporada = await p2;
      expect(comTemporada, isNotNull);
      expect(comTemporada!.temporadaId, 'T1');
    });

    test('R4c — fotografia sem temporada sobrevive a uma virada', () async {
      final p1 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.responder('publico:$alvoX', foto(temporadaId: null, liga: 'Ouro'));
      await p1;

      final p2 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await p2;

      // Ela não afirma pertencer a temporada nenhuma, então não pode estar
      // errada sobre esta.
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNotNull,
      );
    });
  });

  // =========================================================================
  // R5 — falha de transporte
  // =========================================================================
  group('R5 — a falha não mexe na autoridade temporal', () {
    test('R5a — falha não estabelece nem derruba temporada', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await p1;

      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.falhar('publico:$alvoX', MotivoFalhaRanking.indisponivel);
      final falhou = await p2;

      expect(falhou, isNotNull);
      expect(falhou!.fase, FaseRanking.falha);
      // A falha não carrega temporada, então não pode ter aprendido nem
      // esquecido nada.
      expect(falhou.temporadaId, isNull);
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
      );
    });

    test('R5b — depois da falha, a virada legítima ainda é aceita', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1'));
      await p1;

      final p2 = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.indisponivel);
      await p2;

      final p3 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Lenda'));
      expect((await p3)!.temporadaId, 'T2');
    });

    test('R5c — exceção fora do vocabulário também não move nada', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      await p1;

      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.pendente('publico:$alvoX').completeError(StateError('boom'));
      final estado = await p2;

      expect(estado!.fase, FaseRanking.falha);
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
    });
  });

  // =========================================================================
  // R6 — a resposta recusada não altera NADA
  // =========================================================================
  group('R6 — recusar é não tocar em nada', () {
    test(
      'R6a — retorno, cache e fotografia ficam exatamente como estavam',
      () async {
        final p1 = leitor.meuRanking(contaPublicId: contaA); // #1
        final p2 = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        ); // #2

        t.responder(
          'proprio',
          foto(temporadaId: 'T2', liga: 'Ouro', ligaId: 'ouro', posicao: 3),
        );
        await p1;

        // A fotografia boa, fotografada ANTES da chegada da vencida.
        final antes = leitor.emCache(contaPublicId: contaA)!;

        t.responder(
          'publico:$alvoX',
          foto(temporadaId: 'T1', liga: 'Prata', ligaId: 'prata', posicao: 50),
        );
        final recusada = await p2;

        // 1. retorno: descarte, e não um estado.
        expect(recusada, isNull);
        // 2. cache do alvo: nada foi criado.
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
          isNull,
        );
        // 3. fotografia existente: idêntica, campo a campo.
        final depois = leitor.emCache(contaPublicId: contaA)!;
        expect(depois, antes);
        expect(depois.liga, 'Ouro');
        expect(depois.ligaId, 'ouro');
        expect(depois.posicaoMundial, 3);
        expect(depois.temporadaId, 'T2');
        expect(depois.fase, FaseRanking.disponivel);
      },
    );

    test('R6b — a recusa não muda a temporada aceita', () async {
      final p1 = leitor.meuRanking(contaPublicId: contaA);
      final p2 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.responder('proprio', foto(temporadaId: 'T2'));
      await p1;
      t.responder('publico:$alvoX', foto(temporadaId: 'T1'));
      await p2;

      // Se a recusada tivesse virado a aceita, uma resposta de T2 vinda depois
      // seria tratada como virada e despejaria o cache. Ela não é.
      final p3 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoY,
      );
      t.responder('publico:$alvoY', foto(temporadaId: 'T2', liga: 'Lenda'));
      expect((await p3)!.temporadaId, 'T2');
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
    });
  });

  // =========================================================================
  // R7 — troca de sessão com voo antigo terminando depois do novo
  // =========================================================================
  group('R7 — o voo velho termina depois do novo', () {
    test(
      'R7a — a resposta da conta anterior não é aplicada nem guardada',
      () async {
        final vooDeA = leitor.meuRanking(contaPublicId: contaA);
        leitor.aoMudarSessao(1);
        final vooDeB = leitor.meuRanking(contaPublicId: contaB);

        // O NOVO (índice 1) termina primeiro...
        t.pedido('proprio', 1).complete(foto(temporadaId: 'T1', liga: 'Prata'));
        // ...e só depois o velho (índice 0).
        t.pedido('proprio', 0).complete(foto(temporadaId: 'T2', liga: 'Lenda'));

        expect((await vooDeB)!.liga, 'Prata');
        expect(await vooDeA, isNull);
        expect(leitor.emCache(contaPublicId: contaA), isNull);
        expect(leitor.emCache(contaPublicId: contaB)!.liga, 'Prata');
      },
    );

    test(
      'R7b — o voo velho não leva a temporada da conta anterior junto',
      () async {
        final vooDeA = leitor.meuRanking(contaPublicId: contaA);
        leitor.aoMudarSessao(1);
        final vooDeB = leitor.meuRanking(contaPublicId: contaB);

        // O voo NOVO (índice 1) termina primeiro.
        t.pedido('proprio', 1).complete(foto(temporadaId: 'T1', liga: 'Prata'));
        await vooDeB;
        // A resposta da conta que saiu fala de T2. Ela não pode virar a
        // autoridade temporal da conta que entrou.
        t.pedido('proprio', 0).complete(foto(temporadaId: 'T2', liga: 'Lenda'));
        expect(await vooDeA, isNull);

        // Prova: uma resposta legítima de T1 para B continua sendo aceita.
        final outro = leitor.rankingPublico(
          contaPublicId: contaB,
          alvoPublicId: alvoX,
        );
        t.responder('publico:$alvoX', foto(temporadaId: 'T1', liga: 'Ouro'));
        final aceita = await outro;
        expect(aceita, isNotNull);
        expect(aceita!.temporadaId, 'T1');
        expect(leitor.emCache(contaPublicId: contaB)!.liga, 'Prata');
      },
    );

    test('R7d — MESMA conta, geração nova: o velho não despeja o novo', () async {
      // A chave inclui a conta, então trocar de jogador dá chaves diferentes e
      // o voo velho não encosta na entrada do novo. O caso que morde é a
      // recarga de sessão: a geração sobe, `_emVoo` é esvaziado, mas a conta é
      // a MESMA — e aí os dois voos disputam a mesma chave.
      final vooVelho = leitor.meuRanking(contaPublicId: contaA);
      leitor.aoMudarSessao(1);
      final vooNovo = leitor.meuRanking(contaPublicId: contaA);
      expect(t.emitidasDe('proprio'), 2);

      // O velho (índice 0) termina primeiro e some.
      t.pedido('proprio', 0).complete(foto(temporadaId: 'T2'));
      expect(await vooVelho, isNull);

      // O novo continua em voo: o toque seguinte tem de reusá-lo.
      final terceiro = leitor.meuRanking(contaPublicId: contaA);
      expect(
        t.emitidasDe('proprio'),
        2,
        reason: 'o voo velho removeu o voo novo da mesma chave',
      );

      t.pedido('proprio', 1).complete(foto(temporadaId: 'T1', liga: 'Ouro'));
      expect((await vooNovo)!.liga, 'Ouro');
      expect((await terceiro)!.liga, 'Ouro');
      expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Ouro');
    });

    test('R7c — o voo velho não remove o voo novo do mapa de dedupe', () async {
      // O defeito que sobrava: o `finally` removia a chave incondicionalmente,
      // e a chave em voo depois de `aoMudarSessao` é a do pedido NOVO. O velho,
      // ao terminar, despejava o novo — e o dedupe furava para quem chamasse
      // em seguida.
      final vooVelho = leitor.meuRanking(contaPublicId: contaA);
      leitor.aoMudarSessao(1);
      final vooNovo = leitor.meuRanking(contaPublicId: contaB);
      expect(t.emitidasDe('proprio'), 2);

      // O velho termina ANTES do novo, e some.
      t.pendente('proprio').complete(foto(temporadaId: 'T2'));
      expect(await vooVelho, isNull);

      // O novo ainda está em voo: um terceiro toque tem de reusá-lo.
      final terceiro = leitor.meuRanking(contaPublicId: contaB);
      expect(
        t.emitidasDe('proprio'),
        2,
        reason: 'o voo velho derrubou o novo do dedupe',
      );

      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
      expect((await vooNovo)!.liga, 'Ouro');
      expect((await terceiro)!.liga, 'Ouro');
    });
  });

  // =========================================================================
  // R8 — três toques, uma chamada
  // =========================================================================
  group('R8 — o retry continua idempotente', () {
    test('R8a — três toques seguidos produzem UMA chamada', () async {
      final a = leitor.meuRanking(contaPublicId: contaA);
      final b = leitor.meuRanking(contaPublicId: contaA);
      final c = leitor.meuRanking(contaPublicId: contaA);
      expect(t.emitidasDe('proprio'), 1);

      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
      expect((await a)!.liga, 'Ouro');
      expect((await b)!.liga, 'Ouro');
      expect((await c)!.liga, 'Ouro');
    });

    test('R8b — três toques DEPOIS de uma troca de sessão também', () async {
      leitor.meuRanking(contaPublicId: contaA);
      leitor.aoMudarSessao(1);
      final a = leitor.meuRanking(contaPublicId: contaB);
      final b = leitor.meuRanking(contaPublicId: contaB);
      final c = leitor.meuRanking(contaPublicId: contaB);
      expect(
        t.emitidasDe('proprio'),
        2,
        reason: 'um voo do pedido antigo mais UM do novo, e nada além',
      );

      // O velho resolve no meio do caminho, e não pode abrir espaço para uma
      // quarta chamada.
      t.pendente('proprio').complete(foto(temporadaId: 'T2'));
      final d = leitor.meuRanking(contaPublicId: contaB);
      expect(t.emitidasDe('proprio'), 2);

      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
      for (final voo in [a, b, c, d]) {
        expect((await voo)!.liga, 'Ouro');
      }
    });

    test('R8c — depois de resolver, um toque novo emite chamada nova', () async {
      final a = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T1'));
      await a;
      expect(t.emitidasDe('proprio'), 1);

      // Idempotência é sobre toques CONCORRENTES. Depois que o voo terminou, o
      // retry precisa mesmo perguntar de novo — senão o botão não faz nada.
      leitor.meuRanking(contaPublicId: contaA);
      expect(t.emitidasDe('proprio'), 2);
    });
  });
}
