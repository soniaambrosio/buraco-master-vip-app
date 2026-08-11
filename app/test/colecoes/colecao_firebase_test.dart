// colecao_firebase_test.dart — adaptador real de Firestore.
//
// Roda contra `fake_cloud_firestore`, que implementa a API do Firestore em
// memoria: sem emulador, sem rede, sem projeto. Cobre leitura de campanha,
// flag, evidencia e inventario, alem da gravacao de equipagem.
//
// O QUE ESTA SUITE NAO COBRE, e por que:
// a chamada `claimPioneerKit` e uma Cloud Function `https.onCall`, e nao existe
// fake oficial de `cloud_functions`. A traducao da resposta e dos codigos de
// erro e testada aqui de forma isolada ([RespostaResgate.doWire]); a chamada
// ponta a ponta fica em test/colecoes/integracao_emulador_test.dart, que so roda
// com o emulador de pe.

import 'package:buraco_master_vip/colecoes/colecao_campanha.dart';
import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:buraco_master_vip/colecoes/colecao_firebase.dart';
import 'package:buraco_master_vip/colecoes/colecao_repositorio.dart';
import 'package:buraco_master_vip/colecoes/colecao_resgate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'uid_teste';
const _campaignId = 'pioneiros_2026';

Map<String, dynamic> _campanha({
  String status = 'active',
  Object? startAt,
  Object? endAt,
}) =>
    {
      'campaignId': _campaignId,
      'collectionId': 'pioneiros_2026',
      'displayName': 'Kit Pioneiros 2026',
      'version': 1,
      'status': status,
      'featureFlag': 'kitPioneiros2026Enabled',
      'startAt': startAt,
      'endAt': endAt,
      'claimDeadline': null,
      'eligibilityMode': 'allowlist',
      'eligibilitySource': 'campaigns/$_campaignId/eligible/{uid}',
      'catalogVisibility': 'hidden',
      'grantMode': 'all_items_one_time',
      'rewardIds': ColecaoItemIds.pioneiros2026,
    };

Map<String, dynamic> _item(String itemId, {bool equipped = false}) => {
      'userId': _uid,
      'itemId': itemId,
      'collectionId': 'pioneiros_2026',
      'source': 'campanha',
      'campaignId': _campaignId,
      'campaignVersion': 1,
      'unlockedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 6, 12)),
      'equipped': equipped,
    };

void main() {
  late FakeFirebaseFirestore db;
  late ColecaoRepositorioFirebase repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ColecaoRepositorioFirebase(firestore: db);
  });

  // ==========================================================================
  group('campanha', () {
    test('le o documento e converte Timestamp em ISO com Z', () async {
      await db.doc('campaigns/$_campaignId').set(_campanha(
            startAt: Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
            endAt: Timestamp.fromDate(DateTime.utc(2026, 12, 1)),
          ));

      final campanha = await repo.carregarCampanha(_campaignId);
      expect(campanha.campaignId, _campaignId);
      expect(campanha.status, StatusCampanha.active);
      expect(campanha.startAt, DateTime.utc(2026, 8, 1));
      expect(campanha.startAt!.isUtc, isTrue,
          reason: 'a conversao na fronteira preserva a exigencia de UTC do dominio');
      expect(campanha.rewardIds, hasLength(10));
    });

    test('campanha ausente vira naoEncontrado, e nao null silencioso', () async {
      expect(
        () => repo.carregarCampanha(_campaignId),
        throwsA(isA<ErroColecao>()
            .having((e) => e.falha, 'falha', FalhaBackend.naoEncontrado)),
      );
    });

    test('campanha malformada vira precondicaoFalhou, nao erro de rede', () async {
      final bruto = _campanha();
      bruto['status'] = 'nao_existe_esse_status';
      await db.doc('campaigns/$_campaignId').set(bruto);

      expect(
        () => repo.carregarCampanha(_campaignId),
        throwsA(isA<ErroColecao>()
            .having((e) => e.falha, 'falha', FalhaBackend.precondicaoFalhou)),
      );
    });
  });

  // ==========================================================================
  group('feature flag', () {
    test('documento ausente significa desligada', () async {
      await db.doc('campaigns/$_campaignId').set(_campanha());
      final campanha = await repo.carregarCampanha(_campaignId);
      expect(await repo.featureFlagLigada(campanha), isFalse);
    });

    test('so `true` liga: valor ausente ou de outro tipo mantem desligada', () async {
      await db.doc('campaigns/$_campaignId').set(_campanha());
      final campanha = await repo.carregarCampanha(_campaignId);

      await db.doc('config/featureFlags').set({'outraFlag': true});
      expect(await repo.featureFlagLigada(campanha), isFalse);

      await db.doc('config/featureFlags').set({'kitPioneiros2026Enabled': 'true'});
      expect(await repo.featureFlagLigada(campanha), isFalse,
          reason: 'string "true" nao pode ligar campanha');

      await db.doc('config/featureFlags').set({'kitPioneiros2026Enabled': true});
      expect(await repo.featureFlagLigada(campanha), isTrue);
    });
  });

  // ==========================================================================
  group('evidencia de elegibilidade', () {
    test('sem documento, nenhuma evidencia', () async {
      final e = await repo.carregarEvidencia(campaignId: _campaignId, uid: _uid);
      expect(e.naAllowlist, isFalse);
      expect(e.concessaoAdministrativa, isFalse);
    });

    test('le as quatro evidencias da subcolecao', () async {
      await db.doc('campaigns/$_campaignId/eligible/$_uid').set({
        'naAllowlist': true,
        'participouTesteFechado': false,
        'concluiuPartidaNaJanela': true,
        'concessaoAdministrativa': false,
      });

      final e = await repo.carregarEvidencia(campaignId: _campaignId, uid: _uid);
      expect(e.naAllowlist, isTrue);
      expect(e.concluiuPartidaNaJanela, isTrue);
      expect(e.participouTesteFechado, isFalse);
    });

    test('a evidencia de um jogador nao vaza para outro', () async {
      await db.doc('campaigns/$_campaignId/eligible/$_uid').set({'naAllowlist': true});
      final outro = await repo.carregarEvidencia(campaignId: _campaignId, uid: 'outro');
      expect(outro.naAllowlist, isFalse);
    });
  });

  // ==========================================================================
  group('inventario', () {
    test('hidrata os itens e converte o server timestamp', () async {
      for (final id in ColecaoItemIds.pioneiros2026) {
        await db.doc('users/$_uid/inventory/$id').set(_item(id));
      }

      final inv = await repo.carregarInventario(uid: _uid);
      expect(inv.total, 10);
      final coroa = inv.buscar(ColecaoItemIds.pioneerCrown)!;
      expect(coroa.unlockedAt, DateTime.utc(2026, 8, 6, 12));
      expect(coroa.unlockedAt.isUtc, isTrue);
      expect(coroa.campaignVersion, 1);
    });

    test('filtra por colecao', () async {
      await db.doc('users/$_uid/inventory/a').set({..._item('a'), 'collectionId': 'outra'});
      await db
          .doc('users/$_uid/inventory/${ColecaoItemIds.pioneerCrown}')
          .set(_item(ColecaoItemIds.pioneerCrown));

      final inv = await repo.carregarInventario(uid: _uid, collectionId: 'pioneiros_2026');
      expect(inv.total, 1);
      expect(inv.possui(ColecaoItemIds.pioneerCrown), isTrue);
    });

    test('um documento corrompido nao esconde os outros nove', () async {
      for (final id in ColecaoItemIds.pioneiros2026) {
        await db.doc('users/$_uid/inventory/$id').set(_item(id));
      }
      // Estraga um: sem `source`, a hidratacao rejeita.
      await db.doc('users/$_uid/inventory/${ColecaoItemIds.pioneerVortex}').set({
        ..._item(ColecaoItemIds.pioneerVortex),
        'source': '',
      });

      final inv = await repo.carregarInventario(uid: _uid);
      expect(inv.total, 9);
      expect(inv.possui(ColecaoItemIds.pioneerVortex), isFalse,
          reason: 'a reconciliacao do resgate regrava o que faltar');
    });

    test('inventario vazio nao e erro', () async {
      final inv = await repo.carregarInventario(uid: _uid);
      expect(inv.total, 0);
    });
  });

  // ==========================================================================
  group('equipagem', () {
    test('grava a troca de slot em lote', () async {
      await db
          .doc('users/$_uid/inventory/${ColecaoItemIds.pioneerMascotBulldog}')
          .set(_item(ColecaoItemIds.pioneerMascotBulldog, equipped: true));
      await db
          .doc('users/$_uid/inventory/${ColecaoItemIds.pioneerMascotDragon}')
          .set(_item(ColecaoItemIds.pioneerMascotDragon));

      await repo.aplicarEquipagem(
        uid: _uid,
        itemIdEquipado: ColecaoItemIds.pioneerMascotDragon,
        itemIdsDesequipados: [ColecaoItemIds.pioneerMascotBulldog],
      );

      final inv = await repo.carregarInventario(uid: _uid);
      expect(inv.estaEquipado(ColecaoItemIds.pioneerMascotDragon), isTrue);
      expect(inv.estaEquipado(ColecaoItemIds.pioneerMascotBulldog), isFalse);
      expect(inv.total, 2, reason: 'equipar nao cria nem remove item');
    });

    test('a gravacao so toca o campo equipped', () async {
      final id = ColecaoItemIds.pioneerCrown;
      await db.doc('users/$_uid/inventory/$id').set(_item(id));

      await repo.aplicarEquipagem(
        uid: _uid,
        itemIdEquipado: id,
        itemIdsDesequipados: const [],
      );

      final doc = await db.doc('users/$_uid/inventory/$id').get();
      final dados = doc.data()!;
      expect(dados['equipped'], isTrue);
      // Os campos que provam a procedencia continuam intactos — e as regras
      // recusariam a gravacao se tivessem mudado junto.
      expect(dados['source'], 'campanha');
      expect(dados['campaignId'], _campaignId);
      expect(dados['campaignVersion'], 1);
      expect(dados['unlockedAt'], isA<Timestamp>());
    });
  });

  // ==========================================================================
  group('resposta do resgate', () {
    test('traduz os tres estados do wire', () {
      for (final caso in {
        'claimed': SituacaoResgate.concedido,
        'reconciled': SituacaoResgate.reconciliado,
        'alreadyClaimed': SituacaoResgate.jaResgatado,
      }.entries) {
        final r = RespostaResgate.doWire({
          'status': caso.key,
          'itemIds': ColecaoItemIds.pioneiros2026,
          'gravados': 10,
        });
        expect(r.situacao, caso.value);
        expect(r.itemIds, hasLength(10));
      }
    });

    test('status desconhecido nao vira sucesso', () {
      expect(
        () => RespostaResgate.doWire({
          'status': 'partiallyClaimed',
          'itemIds': ColecaoItemIds.pioneiros2026,
        }),
        throwsA(isA<ErroColecao>()),
      );
    });

    test('resposta sem itemIds e recusada', () {
      expect(
        () => RespostaResgate.doWire({'status': 'claimed', 'itemIds': <String>[]}),
        throwsA(isA<ErroColecao>()),
      );
    });

    test('so indisponibilidade convida a repetir', () {
      expect(FalhaBackend.indisponivel.vaiAdiantarRepetir, isTrue);
      expect(FalhaBackend.recusado.vaiAdiantarRepetir, isFalse,
          reason: 'insistir num nao elegivel so gera carga');
      expect(FalhaBackend.naoAutenticado.vaiAdiantarRepetir, isFalse);
    });
  });
}
