// suites_obrigatorias_test.dart — a mesma guarda do CI, na máquina de quem
// edita.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTE ARQUIVO FECHA
// ---------------------------------------------------------------------------
//
// O agregador do `ci-os-integracao.yml` roda cada suíte por caminho, e o
// auxiliar `roda` escreve `nao_<chave>` quando o arquivo não está lá. O portão
// trata `nao_<chave>` como NÃO EXECUTADO, e NÃO EXECUTADO **não reprova** — o
// que é a decisão certa para os gates que dependem de codebase Firebase que
// pode não existir na branch em que o CI roda, e continua valendo para eles.
//
// A conta que sobra é desconfortável: `rm test/casca/acessibilidade_configuracoes_test.dart`
// deixava o run VERDE. Um gate que some sem barulho é pior do que não ter gate,
// porque a tabela de evidência continua sendo publicada e continua parecendo
// completa.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO NOVO, E NÃO UM CASO NUMA SUÍTE EXISTENTE
// ---------------------------------------------------------------------------
//
// Porque a guarda não pode morar dentro do que ela guarda. Um caso escrito em
// `acessibilidade_configuracoes_test.dart` some junto com o arquivo, e não sobra
// ninguém para reclamar. Este arquivo é o único do repositório cuja razão de existir é
// a INSTRUMENTAÇÃO, e ele se lista no próprio manifesto — some ele, e o
// verificador do CI acusa.
//
// ---------------------------------------------------------------------------
// ELE NÃO É A RAIZ DE CONFIANÇA, E ISSO IMPORTA
// ---------------------------------------------------------------------------
//
// Ele roda como gate (`suitesobrig`), então a mesma tolerância se aplica a ele:
// apagá-lo daria NÃO EXECUTADO. Quem fecha esse laço é
// `scripts/ci/verificar_suites_obrigatorias.sh`, invocado num passo que sai com
// código diferente de zero por conta própria, antes de qualquer teste. Este
// arquivo é a metade RÁPIDA da guarda — o vermelho que aparece em `flutter
// test` sem esperar o Actions —, e a lista que os dois leem é a mesma.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O manifesto, relativo à raiz do app.
///
/// `flutter test` roda com a raiz do app como diretório corrente — `app_build`
/// no CI, `app` num checkout normal —, então o caminho vale nos dois.
const _manifesto = 'test/suites_obrigatorias.txt';

/// As entradas que esta OS declarou obrigatórias, escritas AQUI.
///
/// Sem isto, esvaziar `suites_obrigatorias.txt` seria uma saída silenciosa: o
/// arquivo continuaria existindo, bem formado, e não guardaria mais nada. O
/// manifesto pode CRESCER com decisões futuras; encolher abaixo destas duas
/// linhas é o que este caso proíbe.
const _minimas = <String, String>{
  'a11yconf': 'test/casca/acessibilidade_configuracoes_test.dart',
  'suitesobrig': 'test/ci/suites_obrigatorias_test.dart',
};

/// Uma linha do manifesto, já separada.
typedef _Entrada = ({String chave, String caminho, String bruta});

List<_Entrada> _lerManifesto() {
  final arquivo = File(_manifesto);
  if (!arquivo.existsSync()) {
    throw StateError(
      'manifesto ausente em "$_manifesto" (corrente: ${Directory.current.path})',
    );
  }
  final saida = <_Entrada>[];
  for (final bruta in arquivo.readAsLinesSync()) {
    final linha = bruta.trim();
    if (linha.isEmpty || linha.startsWith('#')) continue;
    final campos = linha.split(RegExp(r'\s+'));
    if (campos.length != 2) {
      throw StateError('linha malformada no manifesto: "$bruta"');
    }
    saida.add((chave: campos[0], caminho: campos[1], bruta: bruta));
  }
  return saida;
}

void main() {
  group('as suítes obrigatórias continuam no disco', () {
    test('S1 — o manifesto existe e tem entradas', () {
      final entradas = _lerManifesto();
      expect(
        entradas,
        isNotEmpty,
        reason: 'a lista de suítes obrigatórias foi esvaziada',
      );
    });

    test('S2 — cada entrada do manifesto aponta para um arquivo que existe', () {
      for (final e in _lerManifesto()) {
        expect(
          File(e.caminho).existsSync(),
          isTrue,
          reason:
              'a suíte obrigatória "${e.caminho}" (gate ${e.chave}) foi '
              'removida ou renomeada. No CI ela viraria NÃO EXECUTADO, que o '
              'portão não reprova — é exatamente esse silêncio que este caso '
              'existe para quebrar.',
        );
      }
    });

    test('S3 — o manifesto não encolheu abaixo do mínimo desta OS', () {
      final mapa = {for (final e in _lerManifesto()) e.chave: e.caminho};
      for (final m in _minimas.entries) {
        expect(
          mapa[m.key],
          m.value,
          reason:
              'o gate "${m.key}" saiu do manifesto, ou mudou de caminho sem '
              'que este caso fosse atualizado junto',
        );
      }
    });

    test('S4 — nenhuma chave repetida', () {
      final entradas = _lerManifesto();
      final chaves = entradas.map((e) => e.chave).toList();
      expect(
        chaves.toSet(),
        hasLength(chaves.length),
        reason: 'chave duplicada no manifesto: $chaves',
      );
    });

    test('S5 — as suítes obrigatórias são arquivos de teste de verdade', () {
      // Um caminho que não termina em `_test.dart` não é descoberto pelo
      // `flutter test`, e apontar o manifesto para um arquivo qualquer seria
      // uma forma de manter a lista cheia com a suíte desligada.
      for (final e in _lerManifesto()) {
        expect(
          e.caminho.endsWith('_test.dart'),
          isTrue,
          reason: '"${e.caminho}" não é uma suíte (gate ${e.chave})',
        );
        expect(
          File(e.caminho).readAsStringSync(),
          contains('void main('),
          reason: '"${e.caminho}" não declara `main` (gate ${e.chave})',
        );
      }
    });
  });
}
