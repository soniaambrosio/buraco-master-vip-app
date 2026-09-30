// Identidade de build, manifesto reprodutível e o gate de release.
//
// O gate é a única coisa entre um APK e a Play. Cada regra dele existe porque
// a alternativa é irrecuperável depois de publicada: não se "desemite" um
// versionCode, e não se descobre depois qual commit gerou um artefato que
// ninguém carimbou.

import 'package:buraco_master_vip/observability/identidade_build.dart';
import 'package:buraco_master_vip/observability/manifesto_build.dart';
import 'package:buraco_master_vip/observability/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

const String shaA = '0cea0d6d68f2c93613b985f4aa85800d77cf42d7';
const String shaB = 'fb9edb5c6963964161f1e8834b57f50fe77074a1';

IdentidadeBuild identidade({
  String versionName = '1.4.2',
  int versionCode = 412,
  String sha = shaA,
  String branch = 'consolidacao/apk-geral-bmv',
  AmbienteBuild ambiente = AmbienteBuild.producao,
}) =>
    IdentidadeBuild(
      versionName: versionName,
      versionCode: versionCode,
      sha: sha,
      branch: branch,
      ambiente: ambiente,
      flutterVersion: '3.44.8',
      dartVersion: '3.11.1',
    );

/// 64 hex — a forma de um sha256 de artefato.
String hashFalso(String semente) => sha256DoTexto(semente);

void main() {
  group('sha256 em Dart puro', () {
    test('vetores oficiais do FIPS 180-4', () {
      expect(sha256DoTexto(''),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(sha256DoTexto('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(
          sha256DoTexto(
              'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
          '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    });

    test('bloco longo, que força mais de uma rodada de compressão', () {
      expect(sha256DoTexto('a' * 1000),
          '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3');
    });

    test('hasheia bytes crus, não só texto', () {
      expect(sha256Hex(const <int>[]), sha256DoTexto(''));
      expect(sha256Hex(const <int>[0x61, 0x62, 0x63]), sha256DoTexto('abc'));
    });
  });

  group('identidade de build', () {
    test('identidade completa é provável', () {
      expect(identidade().provavel, isTrue);
      expect(identidade().pendencias, isEmpty);
      expect(identidade().resumo, '1.4.2 (412) · 0cea0d6 · producao');
    });

    test('denuncia SHA ausente, malformado e versionCode inválido', () {
      expect(identidade(sha: '').pendencias, contains('SHA ausente'));
      expect(identidade(sha: 'abc123').pendencias,
          contains('SHA malformado (esperado 40 hex minúsculo)'));
      expect(identidade(versionCode: 0).pendencias,
          contains('versionCode inválido (<= 0)'));
      expect(identidade(versionCode: -3).pendencias,
          contains('versionCode inválido (<= 0)'));
      expect(identidade(versionName: '').pendencias, contains('versionName ausente'));
      expect(identidade(versionName: 'v1').pendencias,
          contains('versionName fora de x.y.z'));
      expect(identidade(branch: '').pendencias, contains('branch ausente'));
    });

    test('só homologação e produção aceitam coletor real', () {
      expect(AmbienteBuild.producao.aceitaColetorReal, isTrue);
      expect(AmbienteBuild.homologacao.aceitaColetorReal, isTrue);
      expect(AmbienteBuild.desenvolvimento.aceitaColetorReal, isFalse);
      expect(AmbienteBuild.teste.aceitaColetorReal, isFalse);
      expect(AmbienteBuild.porNome('inexistente'), AmbienteBuild.desenvolvimento);
    });

    test('vai e volta por JSON sem perder nada', () {
      final ida = identidade();
      expect(IdentidadeBuild.deJson(ida.paraJson()), ida);
    });

    test('a identidade lida do binário sem defines é improvável', () {
      // Sem `--dart-define`, é exatamente o caso de um APK compilado sem
      // carimbo: o gate tem de reprovar. Só vale quando a suíte roda sem os
      // defines — com eles, o teste seguinte é que manda.
      final doBinario = IdentidadeBuild.doBinario();
      if (doBinario.sha.isNotEmpty) return;
      expect(doBinario.provavel, isFalse);
      expect(doBinario.pendencias, contains('SHA ausente'));
    });

    // Prova de ponta a ponta do carimbo: quando o build passa os defines que
    // o gate imprime, a identidade chega DENTRO do binário e é provável.
    // Rode com as linhas de `gate_identidade_build.dart --defines`.
    final doBinario = IdentidadeBuild.doBinario();
    test(
      'a identidade gravada por --dart-define chega ao binário',
      () {
        expect(doBinario.provavel, isTrue,
            reason: doBinario.pendencias.join('; '));
        expect(doBinario.sha, hasLength(40));
        expect(doBinario.versionCode, greaterThan(0));
        expect(doBinario.branch, isNotEmpty);
      },
      skip: doBinario.sha.isEmpty
          ? 'sem --dart-define; ver docs/OBSERVABILIDADE-EVIDENCIA-V1.md'
          : false,
    );
  });

  group('manifesto reprodutível', () {
    ManifestoBuild montar({Map<String, String>? artefatos}) => ManifestoBuild(
          identidade: identidade(),
          artefatos: artefatos ??
              <String, String>{
                'app-arm64-v8a-release.apk': hashFalso('apk'),
              },
          simbolos: <String, String>{
            'simbolos/app.android-arm64.symbols': hashFalso('symbols'),
          },
        );

    test('o mesmo commit e os mesmos artefatos dão bytes idênticos', () {
      expect(montar().paraJsonCanonico(), montar().paraJsonCanonico());
      expect(montar().impressaoDigital, montar().impressaoDigital);
    });

    test('a ordem de inserção das chaves não muda o resultado', () {
      final a = ManifestoBuild(
        identidade: identidade(),
        artefatos: <String, String>{'z.apk': hashFalso('z'), 'a.apk': hashFalso('a')},
      );
      final b = ManifestoBuild(
        identidade: identidade(),
        artefatos: <String, String>{'a.apk': hashFalso('a'), 'z.apk': hashFalso('z')},
      );
      expect(a.paraJsonCanonico(), b.paraJsonCanonico());
      expect(a.impressaoDigital, b.impressaoDigital);
    });

    test('outro commit dá outra impressão digital', () {
      final outro = ManifestoBuild(
        identidade: identidade(sha: shaB),
        artefatos: <String, String>{'app.apk': hashFalso('apk')},
      );
      expect(outro.impressaoDigital, isNot(montar().impressaoDigital));
    });

    test('o manifesto não carrega segredo', () {
      expect(montar().semSegredos, isTrue);
      final envenenado = ManifestoBuild(
        identidade: identidade(branch: 'wip/AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ'),
        artefatos: <String, String>{'app.apk': hashFalso('apk')},
      );
      expect(envenenado.semSegredos, isFalse);
    });

    test('o manifesto contém o que a investigação precisa', () {
      final json = montar().paraJsonCanonico();
      expect(json, contains(shaA));
      expect(json, contains('"versionCode": 412'));
      expect(json, contains('3.44.8'));
      expect(json, contains('simbolos/app.android-arm64.symbols'));
    });
  });

  group('livro-razão de versionCode', () {
    final livro = LivroDeVersionCode(<RegistroVersionCode>[
      const RegistroVersionCode(versionCode: 410, sha: shaB, branch: 'main'),
      const RegistroVersionCode(versionCode: 411, sha: shaA, branch: 'main'),
    ]);

    test('lê e escreve JSON de forma estável', () {
      final relido = LivroDeVersionCode.deJson(livro.paraJsonCanonico());
      expect(relido.registros, hasLength(2));
      expect(relido.maiorVersionCode, 411);
      expect(relido.paraJsonCanonico(), livro.paraJsonCanonico());
    });

    test('livro vazio ou texto vazio não quebram', () {
      expect(LivroDeVersionCode.vazio().maiorVersionCode, 0);
      expect(LivroDeVersionCode.deJson('').registros, isEmpty);
      expect(LivroDeVersionCode.deJson('   ').registros, isEmpty);
    });

    test('registrar o mesmo par (versionCode, sha) é idempotente', () {
      final igual = livro.com(
          const RegistroVersionCode(versionCode: 411, sha: shaA, branch: 'main'));
      expect(igual.registros, hasLength(2));
      expect(identical(igual, livro), isTrue);
    });

    test('novo registro entra ordenado', () {
      final novo = livro.com(const RegistroVersionCode(
          versionCode: 500, sha: shaB, branch: 'rc'));
      expect(novo.registros.last.versionCode, 500);
      expect(novo.maiorVersionCode, 500);
    });
  });

  group('gate de release', () {
    final livro = LivroDeVersionCode(<RegistroVersionCode>[
      const RegistroVersionCode(versionCode: 410, sha: shaB, branch: 'main'),
    ]);

    ManifestoBuild manifestoDe(IdentidadeBuild id) => ManifestoBuild(
          identidade: id,
          artefatos: <String, String>{'app.apk': hashFalso('apk')},
          simbolos: <String, String>{'app.symbols': hashFalso('sym')},
        );

    ResultadoGate rodar({
      IdentidadeBuild? id,
      bool arvoreLimpa = true,
      LivroDeVersionCode? l,
      ManifestoBuild? manifesto,
      bool exigirArtefatos = true,
    }) {
      final identidadeUsada = id ?? identidade(versionCode: 412);
      return avaliarGate(
        identidade: identidadeUsada,
        arvoreLimpa: arvoreLimpa,
        livro: l ?? livro,
        manifesto: manifesto ?? manifestoDe(identidadeUsada),
        exigirArtefatos: exigirArtefatos,
      );
    }

    test('build íntegra passa, e o exit code é 0', () {
      final r = rodar();
      expect(r.aprovado, isTrue, reason: r.veredito);
      expect(r.codigoDeSaida, 0);
      expect(r.veredito, startsWith('PASS'));
    });

    test('REPROVA árvore suja', () {
      final r = rodar(arvoreLimpa: false);
      expect(r.aprovado, isFalse);
      expect(r.codigoDeSaida, 1);
      expect(r.reprovacoes.join(), contains('árvore suja'));
    });

    test('REPROVA SHA ausente', () {
      final r = rodar(id: identidade(sha: ''));
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('SHA ausente'));
    });

    test('REPROVA versionCode repetido com outro commit', () {
      final r = rodar(id: identidade(versionCode: 410, sha: shaA));
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('versionCode repetido'));
    });

    test('ACEITA reemitir o mesmo versionCode para o MESMO commit', () {
      final r = rodar(id: identidade(versionCode: 410, sha: shaB));
      expect(r.aprovado, isTrue, reason: r.veredito);
    });

    test('REPROVA versionCode regressivo', () {
      final r = rodar(id: identidade(versionCode: 9, sha: shaA));
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('versionCode regressivo'));
    });

    test('REPROVA versionCode inválido', () {
      final r = rodar(id: identidade(versionCode: 0));
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('versionCode inválido'));
    });

    test('REPROVA artefato sem hash de 64 hex', () {
      final id = identidade(versionCode: 412);
      final r = rodar(
        id: id,
        manifesto: ManifestoBuild(
            identidade: id, artefatos: <String, String>{'app.apk': 'curto'}),
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('artefato sem sha256 válido'));
    });

    test('REPROVA mapa de símbolos sem hash válido', () {
      final id = identidade(versionCode: 412);
      final r = rodar(
        id: id,
        manifesto: ManifestoBuild(
          identidade: id,
          artefatos: <String, String>{'app.apk': hashFalso('apk')},
          simbolos: <String, String>{'app.symbols': 'nope'},
        ),
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('mapa de símbolos'));
    });

    test('REPROVA quando não há artefato para provar identidade', () {
      final id = identidade(versionCode: 412);
      final r = rodar(id: id, manifesto: ManifestoBuild(identidade: id));
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('não declara nenhum artefato'));
    });

    test('REPROVA manifesto ausente quando artefatos são exigidos', () {
      final r = avaliarGate(
        identidade: identidade(versionCode: 412),
        arvoreLimpa: true,
        livro: livro,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('manifesto ausente'));
    });

    test('modo pré-build valida identidade sem exigir artefato', () {
      final id = identidade(versionCode: 412);
      final r = avaliarGate(
        identidade: id,
        arvoreLimpa: true,
        livro: livro,
        manifesto: ManifestoBuild(identidade: id),
        exigirArtefatos: false,
      );
      expect(r.aprovado, isTrue, reason: r.veredito);
    });

    test('acumula todas as reprovações, não para na primeira', () {
      final r = rodar(id: identidade(sha: '', versionCode: 0), arvoreLimpa: false);
      expect(r.reprovacoes.length, greaterThanOrEqualTo(3));
      expect(r.veredito, startsWith('FAIL'));
    });
  });
}
