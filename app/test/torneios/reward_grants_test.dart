// reward_grants_test.dart — cobertura do dominio de concessao de recompensas.
//
// Dart puro sobre flutter_test: nao sobe widget, nao toca Firebase e nao le
// rede. Os seeds reais entram por arquivo (copiados para test/torneios/data/
// pelo workflow), e os casos positivos usam uma fixture com a arte marcada como
// pronta — no seed de producao TODA coroa e TODO selo ainda estao em
// `pendingAsset`, entao sem a fixture nenhum caminho feliz seria observavel.

import 'dart:convert';
import 'dart:io';

import 'package:buraco_master_vip/torneios/assets_registry.dart';
import 'package:buraco_master_vip/torneios/reward_grants.dart';
import 'package:buraco_master_vip/torneios/reward_policies.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _lerSeed(String nome) {
  final arquivo = File('test/torneios/data/$nome');
  if (!arquivo.existsSync()) {
    throw StateError('seed nao encontrado: ${arquivo.path}');
  }
  return jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
}

/// Copia o seed de assets marcando toda arte pendente como pronta.
Map<String, dynamic> _comArtesProntas(Map<String, dynamic> raiz) {
  final copia = jsonDecode(jsonEncode(raiz)) as Map<String, dynamic>;
  for (final a in (copia['assets'] as List).cast<Map<String, dynamic>>()) {
    if (a['status'] == 'pendingAsset') {
      a['status'] = 'ready';
      a['arquivoLocal'] = 'assets/torneios/fixture/${a['assetId']}.png';
    }
  }
  return copia;
}

/// Copia o seed de politicas removendo ou sobrescrevendo entradas.
Map<String, dynamic> _comPoliticas(
  Map<String, dynamic> raiz, {
  Set<String> remover = const {},
  Map<String, Map<String, dynamic>> sobrescrever = const {},
}) {
  final copia = jsonDecode(jsonEncode(raiz)) as Map<String, dynamic>;
  final lista = (copia['policies'] as List).cast<Map<String, dynamic>>();
  lista.removeWhere((p) => remover.contains(p['assetId']));
  for (final p in lista) {
    final novo = sobrescrever[p['assetId']];
    if (novo != null) p.addAll(novo);
  }
  copia['policies'] = lista;
  return copia;
}

void main() {
  final assetsRaiz = _lerSeed('assets_registry.seed.json');
  final politicasRaiz = _lerSeed('reward_policies.seed.json');

  // Seeds reais, sem modificacao.
  final assetsSeed = TorneioAssetsRegistry.fromMap(assetsRaiz);
  final politicasSeed = RewardPoliciesRegistry.fromMap(politicasRaiz);

  // Fixture com a arte produzida, para observar os casos positivos.
  final assetsProntos = TorneioAssetsRegistry.fromMap(_comArtesProntas(assetsRaiz));

  final base = DateTime.utc(2026, 3, 1, 12);

  ResultadoConcessao conceder(
    String assetId, {
    TorneioAssetsRegistry? assets,
    RewardPoliciesRegistry? politicas,
    String userId = 'u1',
    String tournamentId = 'tn-mensal',
    String editionId = 'ed-2026-03',
    DateTime? grantedAt,
    DateTime? proximaEdicaoEm,
    MotivoConcessao motivo = MotivoConcessao.participacao,
    int? colocacao,
    Iterable<RecompensaConcessao> historico = const <RecompensaConcessao>[],
  }) =>
      concederRecompensa(
        rewardId: 'rw-$assetId-$tournamentId-$editionId-$userId',
        userId: userId,
        tournamentId: tournamentId,
        editionId: editionId,
        assetId: assetId,
        grantedAt: grantedAt ?? base,
        motivo: motivo,
        colocacao: colocacao,
        proximaEdicaoEm: proximaEdicaoEm,
        assets: assets ?? assetsProntos,
        politicas: politicas ?? politicasSeed,
        historico: historico,
      );

  group('integridade dos seeds existentes', () {
    test('schemaVersion de cada seed', () {
      expect(assetsSeed.schemaVersion, 2);
      expect(politicasSeed.schemaVersion, 1);
    });

    test('toda coroa e selo tem exatamente uma politica', () {
      expect(() => politicasSeed.validarCobertura(assetsSeed), returnsNormally);
    });

    test('nenhuma arte de recompensa foi inventada: tudo segue pendingAsset', () {
      expect(
        assetsSeed.recompensaveis.every((a) => a.status == TorneioAssetStatus.pendingAsset),
        isTrue,
      );
      expect(assetsSeed.recompensaveis.every((a) => a.arquivoLocal == null), isTrue);
    });
  });

  group('1. selo permanente', () {
    final r = conceder(TorneioAssetIds.sealParticipant);

    test('e concedido', () => expect(r.concedida, isTrue));
    test('nao expira', () => expect(r.concessao!.expiresAt, isNull));
    test('marcado como permanente', () => expect(r.concessao!.permanente, isTrue));
  });

  group('2. coroa P3D', () {
    final r = conceder(TorneioAssetIds.crownParticipant);

    test('e concedida', () => expect(r.concedida, isTrue));
    test('expira em +3 dias',
        () => expect(r.concessao!.expiresAt, base.add(const Duration(days: 3))));
  });

  group('3. coroa P7D', () {
    final r = conceder(TorneioAssetIds.crownTop3,
        motivo: MotivoConcessao.colocacao, colocacao: 3);

    test('e concedida', () => expect(r.concedida, isTrue));
    test('expira em +7 dias',
        () => expect(r.concessao!.expiresAt, base.add(const Duration(days: 7))));
    test('guarda a colocacao', () => expect(r.concessao!.colocacao, 3));
  });

  group('4. mensal ate a proxima edicao', () {
    final proxima = base.add(const Duration(days: 30));
    final r = conceder(TorneioAssetIds.crownMonthlyChampion,
        proximaEdicaoEm: proxima, motivo: MotivoConcessao.colocacao, colocacao: 1);

    test('e concedida', () => expect(r.concedida, isTrue));
    test('expira na proxima edicao, nao no teto',
        () => expect(r.concessao!.expiresAt, proxima));
  });

  group('5. mensal limitado a P35D', () {
    test('proxima edicao atrasada corta no teto', () {
      final r = conceder(TorneioAssetIds.crownMonthlyChampion,
          proximaEdicaoEm: base.add(const Duration(days: 60)),
          motivo: MotivoConcessao.colocacao,
          colocacao: 1);
      expect(r.concessao!.expiresAt, base.add(const Duration(days: 35)));
    });

    test('proxima edicao indefinida usa o teto', () {
      final r = conceder(TorneioAssetIds.crownMonthlyChampion,
          motivo: MotivoConcessao.colocacao, colocacao: 1);
      expect(r.concessao!.expiresAt, base.add(const Duration(days: 35)));
    });
  });

  group('6. anual limitado a P370D', () {
    test('sem proxima edicao usa o teto', () {
      final r = conceder(TorneioAssetIds.crownAnnualChampion,
          motivo: MotivoConcessao.colocacao, colocacao: 1);
      expect(r.concessao!.expiresAt, base.add(const Duration(days: 370)));
    });

    test('proxima edicao alem do teto e cortada', () {
      final r = conceder(TorneioAssetIds.crownAnnualChampion,
          proximaEdicaoEm: base.add(const Duration(days: 400)),
          motivo: MotivoConcessao.colocacao,
          colocacao: 1);
      expect(r.concessao!.expiresAt, base.add(const Duration(days: 370)));
    });
  });

  group('7. Lenda Master permanente', () {
    final r = conceder(TorneioAssetIds.crownLegendMaster,
        motivo: MotivoConcessao.consagracao);

    test('e concedida', () => expect(r.concedida, isTrue));
    test('nunca expira', () => expect(r.concessao!.expiresAt, isNull));
    test('segue ativa em data remota',
        () => expect(r.concessao!.ativaEm(DateTime.utc(2099)), isTrue));

    test('permanente, porem FORA do contador', () {
      final c = r.concessao!;
      expect(c.permanente, isTrue);
      expect(c.acumulaContador, isFalse);
      final contagem = contarConcessoesPermanentes([c]);
      expect(contagem[const ChaveContador('u1', TorneioAssetIds.crownLegendMaster)], isNull);
      expect(
        contarPermanentesDe(<RecompensaConcessao>[c],
            userId: 'u1', assetId: TorneioAssetIds.crownLegendMaster),
        0,
      );
    });
  });

  group('8. ativo inexistente', () {
    final r = conceder('crown_inexistente');

    test('recusa por asset inexistente',
        () => expect(r.recusa, RecusaConcessao.assetInexistente));
    test('nao emite concessao', () => expect(r.concessao, isNull));
  });

  group('9. politica inexistente', () {
    test('asset sem politica declarada e recusado', () {
      final semPolitica = RewardPoliciesRegistry.fromMap(
          _comPoliticas(politicasRaiz, remover: {TorneioAssetIds.crownChampion}));
      final r = conceder(TorneioAssetIds.crownChampion, politicas: semPolitica);
      expect(r.recusa, RecusaConcessao.politicaInexistente);
    });
  });

  group('10. pendingAsset', () {
    test('arte pendente bloqueia a concessao', () {
      final r = conceder(TorneioAssetIds.crownChampion, assets: assetsSeed);
      expect(r.recusa, RecusaConcessao.artePendente);
    });

    test('podeAtivarRecompensa concorda', () {
      final v = podeAtivarRecompensa(
          assetId: TorneioAssetIds.sealChampion,
          assets: assetsSeed,
          politicas: politicasSeed);
      expect(v.permitido, isFalse);
      expect(v.recusa, RecusaConcessao.artePendente);
    });
  });

  group('11. pending_admin_definition', () {
    final coroa = politicasSeed[TorneioAssetIds.crownClosingChampion];

    test('crown_closing_champion segue com os tres campos pendentes', () {
      expect(coroa.expirationPolicy, ExpirationPolicy.pendingAdminDefinition);
      expect(coroa.defaultDuration, isNull);
      expect(coroa.hierarquia, isNull);
    });

    test('bloqueada mesmo com a arte pronta', () {
      final r = conceder(TorneioAssetIds.crownClosingChampion,
          motivo: MotivoConcessao.colocacao, colocacao: 1);
      expect(r.recusa, RecusaConcessao.politicaPendenteDefinicao);
    });

    test('resolverValidade tambem recusa', () {
      expect(resolverValidade(politica: coroa, grantedAt: base).recusa,
          RecusaConcessao.politicaPendenteDefinicao);
    });
  });

  group('12. hierarquia obrigatoria ausente', () {
    test('coroa com hierarquia nula e recusada', () {
      final semHierarquia = RewardPoliciesRegistry.fromMap(_comPoliticas(politicasRaiz,
          sobrescrever: {
            TorneioAssetIds.crownChampion: {'hierarquia': null}
          }));
      final r = conceder(TorneioAssetIds.crownChampion, politicas: semHierarquia);
      expect(r.recusa, RecusaConcessao.hierarquiaAusente);
    });

    test('selo com hierarquia nula continua valido', () {
      expect(
        podeAtivarRecompensa(
                assetId: TorneioAssetIds.sealChampion,
                assets: assetsProntos,
                politicas: politicasSeed)
            .permitido,
        isTrue,
      );
    });
  });

  group('13. idempotencia', () {
    final primeira = conceder(TorneioAssetIds.sealChampion).concessao!;

    test('chave e tournamentId|editionId|userId|assetId', () {
      expect(primeira.chaveIdempotencia,
          'tn-mensal|ed-2026-03|u1|${TorneioAssetIds.sealChampion}');
    });

    test('chave e determinista', () {
      expect(
        ChaveIdempotencia.de(
            tournamentId: 'tn-mensal',
            editionId: 'ed-2026-03',
            userId: 'u1',
            assetId: TorneioAssetIds.sealChampion),
        primeira.chaveIdempotencia,
      );
    });

    test('repeticao no mesmo torneio e edicao e recusada', () {
      final r = conceder(TorneioAssetIds.sealChampion, historico: [primeira]);
      expect(r.recusa, RecusaConcessao.concessaoDuplicada);
      expect(r.concessao, isNull);
    });

    test('outra edicao continua permitida', () {
      expect(
        conceder(TorneioAssetIds.sealChampion,
                editionId: 'ed-2026-04', historico: [primeira])
            .concedida,
        isTrue,
      );
    });

    test('outro jogador continua permitido', () {
      expect(
        conceder(TorneioAssetIds.sealChampion, userId: 'u2', historico: [primeira])
            .concedida,
        isTrue,
      );
    });

    test('mesma edicao e usuario em torneio DIFERENTE nao colide', () {
      final outroTorneio = conceder(TorneioAssetIds.sealChampion,
          tournamentId: 'tn-semanal', historico: [primeira]);
      expect(outroTorneio.concedida, isTrue);
      expect(outroTorneio.concessao!.chaveIdempotencia,
          isNot(primeira.chaveIdempotencia));
      expect(outroTorneio.concessao!.chaveIdempotencia,
          'tn-semanal|ed-2026-03|u1|${TorneioAssetIds.sealChampion}');
    });

    test('duplicidade dentro do mesmo torneio e edicao segue recusada apos o segundo torneio', () {
      final outroTorneio = conceder(TorneioAssetIds.sealChampion,
          tournamentId: 'tn-semanal', historico: [primeira]).concessao!;
      final historico = [primeira, outroTorneio];
      expect(conceder(TorneioAssetIds.sealChampion, historico: historico).recusa,
          RecusaConcessao.concessaoDuplicada);
      expect(
        conceder(TorneioAssetIds.sealChampion,
                tournamentId: 'tn-semanal', historico: historico)
            .recusa,
        RecusaConcessao.concessaoDuplicada,
      );
    });

    test('segmento vazio ou com separador e rejeitado', () {
      expect(
        () => ChaveIdempotencia.de(
            tournamentId: 't', editionId: 'ed|x', userId: 'u1', assetId: 'a'),
        throwsArgumentError,
      );
      expect(
        () => ChaveIdempotencia.de(
            tournamentId: '', editionId: 'ed', userId: 'u1', assetId: 'a'),
        throwsArgumentError,
      );
    });
  });

  group('14. historico individual preservado', () {
    final historico = <RecompensaConcessao>[];
    for (final ed in ['ed-2026-01', 'ed-2026-02', 'ed-2026-03']) {
      final r = conceder(TorneioAssetIds.sealParticipant,
          editionId: ed, historico: historico);
      if (r.concedida) historico.add(r.concessao!);
    }

    test('tres edicoes geram tres registros', () => expect(historico.length, 3));
    test('chaves distintas preservadas',
        () => expect(historico.map((c) => c.chaveIdempotencia).toSet().length, 3));

    test('a recusa de repeticao nao apaga o historico', () {
      final repetida = conceder(TorneioAssetIds.sealParticipant,
          editionId: 'ed-2026-02', historico: historico);
      expect(repetida.recusa, RecusaConcessao.concessaoDuplicada);
      expect(historico.length, 3);
    });
  });

  group('15. contador agregado', () {
    final historico = <RecompensaConcessao>[];
    for (final ed in ['ed-2026-01', 'ed-2026-02', 'ed-2026-03']) {
      final r = conceder(TorneioAssetIds.sealParticipant,
          editionId: ed, historico: historico);
      if (r.concedida) historico.add(r.concessao!);
    }
    final historicoMisto = <RecompensaConcessao>[
      ...historico,
      conceder(TorneioAssetIds.sealChampion, editionId: 'ed-2026-02').concessao!,
      conceder(TorneioAssetIds.sealParticipant, userId: 'u2', editionId: 'ed-2026-01')
          .concessao!,
      conceder(TorneioAssetIds.crownParticipant, editionId: 'ed-2026-05').concessao!,
      conceder(TorneioAssetIds.crownLegendMaster,
              editionId: 'ed-2026-06', motivo: MotivoConcessao.consagracao)
          .concessao!,
    ];
    final contagem = contarConcessoesPermanentes(historicoMisto);

    test('selo permanente acumula por jogador e ativo', () {
      expect(contagem[const ChaveContador('u1', TorneioAssetIds.sealParticipant)], 3);
      expect(contagem[const ChaveContador('u1', TorneioAssetIds.sealChampion)], 1);
    });

    test('jogadores contam separado', () {
      expect(contagem[const ChaveContador('u2', TorneioAssetIds.sealParticipant)], 1);
    });

    test('recompensa temporaria fica fora do contador', () {
      expect(contagem[const ChaveContador('u1', TorneioAssetIds.crownParticipant)], isNull);
    });

    test('permanente sem acumulaContador fica fora do contador', () {
      expect(contagem[const ChaveContador('u1', TorneioAssetIds.crownLegendMaster)], isNull);
    });

    test('a agregacao nao altera o historico', () {
      expect(historicoMisto.length, 7);
    });

    test('contador pontual concorda com o agregado', () {
      expect(
        contarPermanentesDe(historicoMisto,
            userId: 'u1', assetId: TorneioAssetIds.sealParticipant),
        3,
      );
      expect(
        contarPermanentesDe(historicoMisto,
            userId: 'u9', assetId: TorneioAssetIds.sealChampion),
        0,
      );
    });
  });

  group('snapshot de acumulaContador', () {
    test('o registro carrega a regra vigente na concessao', () {
      final selo = conceder(TorneioAssetIds.sealParticipant).concessao!;
      final coroa = conceder(TorneioAssetIds.crownLegendMaster,
              motivo: MotivoConcessao.consagracao)
          .concessao!;
      expect(selo.acumulaContador, isTrue);
      expect(coroa.acumulaContador, isFalse);
      expect(selo.toJson()['acumulaContador'], isTrue);
    });

    test('mudar a politica depois nao reescreve o passado do jogador', () {
      final antiga = conceder(TorneioAssetIds.sealParticipant).concessao!;
      expect(antiga.acumulaContador, isTrue);

      // A administracao desliga o contador do selo DEPOIS da concessao.
      final politicaNova = RewardPoliciesRegistry.fromMap(_comPoliticas(politicasRaiz,
          sobrescrever: {
            TorneioAssetIds.sealParticipant: {'acumulaContador': false}
          }));
      expect(politicaNova[TorneioAssetIds.sealParticipant].acumulaContador, isFalse);

      // O registro antigo continua contando: o contador le o snapshot.
      expect(
        contarPermanentesDe(<RecompensaConcessao>[antiga],
            userId: 'u1', assetId: TorneioAssetIds.sealParticipant),
        1,
      );

      // E uma concessao nova, sob a regra nova, ja nasce fora do contador.
      final nova = conceder(TorneioAssetIds.sealParticipant,
              editionId: 'ed-2026-09', politicas: politicaNova)
          .concessao!;
      expect(nova.acumulaContador, isFalse);
      expect(
        contarPermanentesDe(<RecompensaConcessao>[antiga, nova],
            userId: 'u1', assetId: TorneioAssetIds.sealParticipant),
        1,
      );
    });
  });

  group('janela de validade', () {
    final coroa = conceder(TorneioAssetIds.crownParticipant).concessao!;

    test('inativa antes de grantedAt', () {
      expect(coroa.ativaEm(base.subtract(const Duration(seconds: 1))), isFalse);
      expect(coroa.ativaEm(base.subtract(const Duration(days: 1))), isFalse);
    });

    test('ativa exatamente em grantedAt', () {
      expect(coroa.ativaEm(base), isTrue);
    });

    test('ativa dentro do prazo', () {
      expect(coroa.ativaEm(base.add(const Duration(days: 2))), isTrue);
    });

    test('inativa exatamente em expiresAt', () {
      expect(coroa.ativaEm(coroa.expiresAt!), isFalse);
    });

    test('inativa depois de expiresAt', () {
      expect(coroa.ativaEm(base.add(const Duration(days: 4))), isFalse);
    });

    test('permanente tambem so vale a partir de grantedAt', () {
      final selo = conceder(TorneioAssetIds.sealParticipant).concessao!;
      expect(selo.ativaEm(base.subtract(const Duration(seconds: 1))), isFalse);
      expect(selo.ativaEm(base), isTrue);
      expect(selo.ativaEm(DateTime.utc(2099)), isTrue);
    });
  });

  group('resolucao de validade — casos de borda', () {
    test('fixed_duration sem duracao e recusada', () {
      const politica = RecompensaPolitica(
          assetId: 'x',
          expirationPolicy: ExpirationPolicy.fixedDuration,
          defaultDuration: null,
          hierarquia: 1,
          acumulaContador: false);
      expect(resolverValidade(politica: politica, grantedAt: base).recusa,
          RecusaConcessao.duracaoAusente);
    });

    test('duracao nao positiva e recusada', () {
      const politica = RecompensaPolitica(
          assetId: 'x',
          expirationPolicy: ExpirationPolicy.untilNextEdition,
          defaultDuration: Duration.zero,
          hierarquia: 1,
          acumulaContador: false);
      expect(resolverValidade(politica: politica, grantedAt: base).recusa,
          RecusaConcessao.duracaoInvalida);
    });

    test('proxima edicao anterior a concessao e recusada', () {
      expect(
        resolverValidade(
                politica: politicasSeed[TorneioAssetIds.crownMonthlyChampion],
                grantedAt: base,
                proximaEdicaoEm: base.subtract(const Duration(days: 1)))
            .recusa,
        RecusaConcessao.proximaEdicaoInvalida,
      );
    });

    test('proxima edicao igual a concessao e recusada', () {
      expect(
        resolverValidade(
                politica: politicasSeed[TorneioAssetIds.crownMonthlyChampion],
                grantedAt: base,
                proximaEdicaoEm: base)
            .recusa,
        RecusaConcessao.proximaEdicaoInvalida,
      );
    });

    test('permanent ignora a proxima edicao', () {
      final v = resolverValidade(
          politica: politicasSeed[TorneioAssetIds.sealParticipant],
          grantedAt: base,
          proximaEdicaoEm: base.add(const Duration(days: 5)));
      expect(v.permanente, isTrue);
      expect(v.expiresAt, isNull);
    });
  });

  group('normalizacao e invariantes', () {
    test('grantedAt e expiresAt sao normalizados para UTC', () {
      final local = DateTime(2026, 3, 1, 9);
      final c = conceder(TorneioAssetIds.crownParticipant, grantedAt: local).concessao!;
      expect(c.grantedAt.isUtc, isTrue);
      expect(c.expiresAt!.isUtc, isTrue);
      expect(c.expiresAt, c.grantedAt.add(const Duration(days: 3)));
    });

    test('motivo por colocacao exige colocacao', () {
      expect(
        () => conceder(TorneioAssetIds.sealChampion, motivo: MotivoConcessao.colocacao),
        throwsArgumentError,
      );
    });

    test('colocacao nao vale em motivo que nao a admite', () {
      expect(
        () => conceder(TorneioAssetIds.sealChampion,
            motivo: MotivoConcessao.participacao, colocacao: 1),
        throwsArgumentError,
      );
    });

    test('toJson expoe os campos auditaveis', () {
      final json = conceder(TorneioAssetIds.crownTop3,
              motivo: MotivoConcessao.colocacao, colocacao: 3)
          .concessao!
          .toJson();
      expect(json['assetId'], TorneioAssetIds.crownTop3);
      expect(json['tournamentId'], 'tn-mensal');
      expect(json['editionId'], 'ed-2026-03');
      expect(json['userId'], 'u1');
      expect(json['motivo'], 'colocacao');
      expect(json['colocacao'], 3);
      expect(json['acumulaContador'], isFalse);
      expect(json['chaveIdempotencia'],
          'tn-mensal|ed-2026-03|u1|${TorneioAssetIds.crownTop3}');
      expect(json['grantedAt'], base.toIso8601String());
      expect(json['expiresAt'], base.add(const Duration(days: 7)).toIso8601String());
    });
  });

  group('hidratacao de registros persistidos', () {
    /// Registro tipico gravado, servido como mapa mutavel para cada caso poder
    /// corromper um campo por vez.
    Map<String, dynamic> gravado(String assetId,
            {MotivoConcessao motivo = MotivoConcessao.participacao, int? colocacao}) =>
        Map<String, dynamic>.from(
            conceder(assetId, motivo: motivo, colocacao: colocacao).concessao!.toJson());

    test('1. round-trip toJson -> fromMap preserva todos os campos', () {
      final original = conceder(TorneioAssetIds.crownTop3,
              motivo: MotivoConcessao.colocacao, colocacao: 3)
          .concessao!;
      final hidratada = RecompensaConcessao.fromMap(original.toJson());

      expect(hidratada.rewardId, original.rewardId);
      expect(hidratada.userId, original.userId);
      expect(hidratada.tournamentId, original.tournamentId);
      expect(hidratada.editionId, original.editionId);
      expect(hidratada.assetId, original.assetId);
      expect(hidratada.grantedAt, original.grantedAt);
      expect(hidratada.expiresAt, original.expiresAt);
      expect(hidratada.motivo, original.motivo);
      expect(hidratada.colocacao, original.colocacao);
      expect(hidratada.acumulaContador, original.acumulaContador);
      expect(hidratada.chaveIdempotencia, original.chaveIdempotencia);
      expect(hidratada.toJson(), original.toJson());
    });

    test('2. recompensa permanente volta permanente', () {
      final hidratada = RecompensaConcessao.fromMap(gravado(TorneioAssetIds.sealParticipant));
      expect(hidratada.expiresAt, isNull);
      expect(hidratada.permanente, isTrue);
      expect(hidratada.ativaEm(DateTime.utc(2099)), isTrue);
      expect(hidratada.ativaEm(base.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('3. recompensa temporaria volta com a mesma janela', () {
      final hidratada = RecompensaConcessao.fromMap(gravado(TorneioAssetIds.crownParticipant));
      expect(hidratada.permanente, isFalse);
      expect(hidratada.grantedAt.isUtc, isTrue);
      expect(hidratada.expiresAt!.isUtc, isTrue);
      expect(hidratada.expiresAt, base.add(const Duration(days: 3)));
      expect(hidratada.ativaEm(base), isTrue);
      expect(hidratada.ativaEm(hidratada.expiresAt!), isFalse);
    });

    test('4. hidratacao nao consulta a politica atual', () {
      final antiga = gravado(TorneioAssetIds.sealParticipant);
      expect(antiga['acumulaContador'], isTrue);

      // A administracao desliga o contador do selo DEPOIS da gravacao.
      final politicaNova = RewardPoliciesRegistry.fromMap(_comPoliticas(politicasRaiz,
          sobrescrever: {
            TorneioAssetIds.sealParticipant: {'acumulaContador': false}
          }));
      expect(politicaNova[TorneioAssetIds.sealParticipant].acumulaContador, isFalse);

      // O registro historico volta com o snapshot do dia, nao com a regra nova.
      final hidratada = RecompensaConcessao.fromMap(antiga);
      expect(hidratada.acumulaContador, isTrue);
      expect(
        contarPermanentesDe(<RecompensaConcessao>[hidratada],
            userId: 'u1', assetId: TorneioAssetIds.sealParticipant),
        1,
      );
    });

    test('5. data invalida e recusada', () {
      final semFuso = gravado(TorneioAssetIds.crownParticipant)
        ..['grantedAt'] = '2026-03-01T12:00:00.000';
      expect(() => RecompensaConcessao.fromMap(semFuso), throwsFormatException);

      final lixo = gravado(TorneioAssetIds.crownParticipant)..['grantedAt'] = 'ontem';
      expect(() => RecompensaConcessao.fromMap(lixo), throwsFormatException);

      final expiraAntes = gravado(TorneioAssetIds.crownParticipant)
        ..['expiresAt'] = base.subtract(const Duration(days: 1)).toIso8601String();
      expect(() => RecompensaConcessao.fromMap(expiraAntes), throwsFormatException);

      final tipoErrado = gravado(TorneioAssetIds.crownParticipant)
        ..['grantedAt'] = 1772000000000;
      expect(() => RecompensaConcessao.fromMap(tipoErrado), throwsFormatException);
    });

    test('6. campo obrigatorio ausente e recusado', () {
      for (final campo in const [
        'rewardId',
        'userId',
        'tournamentId',
        'editionId',
        'assetId',
        'grantedAt',
        'motivo',
        'acumulaContador',
        'chaveIdempotencia',
      ]) {
        final semCampo = gravado(TorneioAssetIds.sealParticipant)..remove(campo);
        expect(
          () => RecompensaConcessao.fromMap(semCampo),
          throwsFormatException,
          reason: 'campo ausente deveria derrubar a hidratacao: $campo',
        );
      }

      final vazio = gravado(TorneioAssetIds.sealParticipant)..['userId'] = '';
      expect(() => RecompensaConcessao.fromMap(vazio), throwsFormatException);
    });

    test('7. enum invalido e recusado', () {
      final motivoDesconhecido = gravado(TorneioAssetIds.sealParticipant)
        ..['motivo'] = 'motivo_que_nao_existe';
      expect(() => RecompensaConcessao.fromMap(motivoDesconhecido), throwsFormatException);

      final motivoNaoTexto = gravado(TorneioAssetIds.sealParticipant)..['motivo'] = 7;
      expect(() => RecompensaConcessao.fromMap(motivoNaoTexto), throwsFormatException);

      // Coerencia motivo x colocacao tambem vale na hidratacao.
      final semColocacao = gravado(TorneioAssetIds.crownTop3,
          motivo: MotivoConcessao.colocacao, colocacao: 3)
        ..['colocacao'] = null;
      expect(() => RecompensaConcessao.fromMap(semColocacao), throwsFormatException);

      final colocacaoIndevida = gravado(TorneioAssetIds.sealParticipant)..['colocacao'] = 1;
      expect(() => RecompensaConcessao.fromMap(colocacaoIndevida), throwsFormatException);
    });

    test('8. chave de idempotencia incompativel e recusada', () {
      final chaveTrocada = gravado(TorneioAssetIds.sealParticipant)
        ..['chaveIdempotencia'] = 'tn-outro|ed-2026-03|u1|${TorneioAssetIds.sealParticipant}';
      expect(() => RecompensaConcessao.fromMap(chaveTrocada), throwsFormatException);

      // Campo adulterado sem atualizar a chave tambem nao passa.
      final userTrocado = gravado(TorneioAssetIds.sealParticipant)..['userId'] = 'u9';
      expect(() => RecompensaConcessao.fromMap(userTrocado), throwsFormatException);

      final chaveMalFormada = gravado(TorneioAssetIds.sealParticipant)
        ..['chaveIdempotencia'] = 'sem-separadores';
      expect(() => RecompensaConcessao.fromMap(chaveMalFormada), throwsFormatException);
    });

    test('hidratada em lote alimenta o contador como a original', () {
      final historico = <RecompensaConcessao>[];
      for (final ed in ['ed-2026-01', 'ed-2026-02', 'ed-2026-03']) {
        final r = conceder(TorneioAssetIds.sealParticipant,
            editionId: ed, historico: historico);
        if (r.concedida) historico.add(r.concessao!);
      }
      final relidos =
          historico.map((c) => RecompensaConcessao.fromMap(c.toJson())).toList();

      expect(relidos.length, 3);
      expect(contarConcessoesPermanentes(relidos),
          contarConcessoesPermanentes(historico));
      expect(
        contarPermanentesDe(relidos,
            userId: 'u1', assetId: TorneioAssetIds.sealParticipant),
        3,
      );
      expect(relidos.map((c) => c.chaveIdempotencia).toSet().length, 3);
    });
  });
}
