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
// E O QUE A OS 30-C2 ACRESCENTOU
// ---------------------------------------------------------------------------
//
// Provar que o ARQUIVO está no disco não prova que ele ainda PROVA alguma
// coisa. Medido na rehomologação: trocar o corpo de
// `acessibilidade_configuracoes_test.dart` por um único `expect(1, 1)` —
// mantendo nome, caminho, sufixo `_test.dart` e o registro nas duas listas do
// workflow — deixava os cinco portões verdes, com trinta e quatro provas a
// menos no run e `exit_a11yconf` igual a zero.
//
// O manifesto passou a carregar, por suíte, um CONTRATO: a assinatura do
// conteúdo, o piso de provas e os blocos que têm de continuar lá. Ele mora
// FORA do arquivo que protege — é essa a única posição de onde dá para acusar
// o esvaziamento —, é versionado junto com o resto, e mudar a suíte de verdade
// passa a exigir mexer nele de propósito, o que aparece no diff.
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

import 'dart:convert';
import 'dart:io';

// `crypto` é dev_dependency declarada em `app/pubspec.yaml`, e o
// `ci-os-integracao.yml` copia esse pubspec para a bancada antes de rodar. O
// `build.yml`, que monta as dependências à mão, nunca copia nem executa
// `test/ci/` — ele roda `test/casca`. Por isso este import é seguro nos dois
// fluxos, e é o mesmo SHA-256 que o verificador em shell calcula.
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// O manifesto, relativo à raiz do app.
///
/// `flutter test` roda com a raiz do app como diretório corrente — `app_build`
/// no CI, `app` num checkout normal —, então o caminho vale nos dois.
const _manifesto = 'test/suites_obrigatorias.txt';

/// O contrato mínimo que ESTA OS declarou, escrito AQUI.
///
/// Sem isto, esvaziar `suites_obrigatorias.txt` seria uma saída silenciosa: o
/// arquivo continuaria existindo, bem formado, e não guardaria mais nada. O
/// mesmo vale para o contrato: baixar `provas` para 1 e apagar os `exige`
/// deixaria tudo coerente entre si e sem guardar coisa nenhuma. O manifesto
/// pode CRESCER com decisões futuras; encolher abaixo do que está aqui é o que
/// estes casos proíbem.
class _Minima {
  const _Minima(this.caminho, this.provas, this.blocos);

  final String caminho;
  final int provas;
  final List<String> blocos;
}

const _minimas = <String, _Minima>{
  'a11yconf': _Minima(
    'test/casca/acessibilidade_configuracoes_test.dart',
    35,
    <String>[
      // O contrato que a OS 30-C1 acrescentou, e que é exatamente o que um
      // corpo trivial faria sumir sem que nenhum gate percebesse.
      "('P1",
      "('P2",
      "('I1",
      "('I2",
      "('I3",
      "('I4",
      "('I5",
      "('I6",
    ],
  ),
  'suitesobrig': _Minima('test/ci/suites_obrigatorias_test.dart', 9, <String>[
    "('S1",
    "('S2",
    "('S3",
    "('S4",
    "('S5",
    "('S6",
    "('S7",
    "('S8",
    "('S9",
  ]),
};

/// Uma entrada do manifesto, já separada, com o contrato que veio embaixo dela.
class _Entrada {
  _Entrada(this.chave, this.caminho, this.bruta);

  final String chave;
  final String caminho;
  final String bruta;

  String? sha256Esperado;
  int? provasMinimas;
  final List<String> exige = <String>[];
}

/// A normalização de fim de linha, e ela precisa ser IDÊNTICA à do verificador.
///
/// O índice do git guarda LF e a árvore de trabalho no Windows tem CRLF
/// (`core.autocrlf=true`), enquanto o runner do Actions vê LF. Uma assinatura
/// sobre os bytes crus valeria numa plataforma e mentiria na outra. O
/// verificador em shell faz `tr -d '\r'`; aqui é o mesmo: remover TODO CR, e
/// não só o do par CRLF.
String _semCr(String s) => s.replaceAll('\r', '');

/// O que conta como PROVA para efeito de piso.
///
/// Uma declaração `test(` ou `testWidgets(` no começo da linha. É contagem
/// ESTÁTICA de propósito: a guarda precisa poder reprovar sem executar a suíte
/// que ela guarda, e antes dela.
final _declaracaoDeProva = RegExp(
  r'^[ \t]*(test|testWidgets)\(',
  multiLine: true,
);

int _contarProvas(String conteudoSemCr) =>
    _declaracaoDeProva.allMatches(conteudoSemCr).length;

String _assinar(String conteudoSemCr) =>
    sha256.convert(utf8.encode(conteudoSemCr)).toString();

String _conteudo(String caminho) => _semCr(File(caminho).readAsStringSync());

/// O conteúdo sem as linhas de comentário.
///
/// É sobre ele que o `exige` casa. Sem isso, uma suíte esvaziada cujos
/// comentários repetissem os literais satisfaria o contrato sem provar nada —
/// a forja mais barata que existe contra busca textual.
final _linhaDeComentario = RegExp(r'^[ \t]*//');

String _semComentarios(String conteudo) => conteudo
    .split('\n')
    .where((l) => !_linhaDeComentario.hasMatch(l))
    .join('\n');

List<_Entrada> _lerManifesto() {
  final arquivo = File(_manifesto);
  if (!arquivo.existsSync()) {
    throw StateError(
      'manifesto ausente em "$_manifesto" (corrente: ${Directory.current.path})',
    );
  }
  final saida = <_Entrada>[];
  for (final bruta in _semCr(arquivo.readAsStringSync()).split('\n')) {
    final linha = bruta.trim();
    if (linha.isEmpty || linha.startsWith('#')) continue;

    // Linha indentada é ATRIBUTO da entrada de cima; linha na margem é ENTRADA.
    if (bruta.startsWith(' ') || bruta.startsWith('\t')) {
      if (saida.isEmpty) {
        throw StateError('atributo antes de qualquer entrada: "$bruta"');
      }
      final corte = linha.indexOf(RegExp(r'\s'));
      if (corte < 0) {
        throw StateError('atributo sem valor no manifesto: "$bruta"');
      }
      final nome = linha.substring(0, corte);
      final valor = linha.substring(corte).trim();
      final alvo = saida.last;
      switch (nome) {
        case 'sha256':
          alvo.sha256Esperado = valor;
        case 'provas':
          final n = int.tryParse(valor);
          if (n == null) {
            throw StateError('"provas" nao e um numero: "$bruta"');
          }
          alvo.provasMinimas = n;
        case 'exige':
          alvo.exige.add(valor);
        default:
          throw StateError('atributo desconhecido "$nome" no manifesto');
      }
      continue;
    }

    final campos = linha.split(RegExp(r'\s+'));
    if (campos.length != 2) {
      throw StateError('linha malformada no manifesto: "$bruta"');
    }
    saida.add(_Entrada(campos[0], campos[1], bruta));
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
          m.value.caminho,
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

  // -------------------------------------------------------------------------
  // O CONTEÚDO, E NÃO SÓ O ARQUIVO — OS 30-C2
  // -------------------------------------------------------------------------
  //
  // Os cinco casos acima respondem "o arquivo está lá?". Os quatro abaixo
  // respondem "ele ainda prova o que dizia provar?". Sem eles, um corpo de uma
  // linha só, com o nome certo, atravessa a cadeia inteira.
  group('as suítes obrigatórias continuam PROVANDO', () {
    test('S6 — a assinatura do conteúdo de cada suíte confere', () {
      for (final e in _lerManifesto()) {
        expect(
          _assinar(_conteudo(e.caminho)),
          e.sha256Esperado,
          reason:
              'o conteúdo de "${e.caminho}" (gate ${e.chave}) mudou e a '
              'assinatura no manifesto não. Se a mudança é legítima, atualize '
              '`sha256` em "$_manifesto" no mesmo commit — é o diff dessa '
              'linha que torna a alteração visível.',
        );
      }
    });

    test('S7 — nenhuma suíte caiu abaixo do piso de provas', () {
      for (final e in _lerManifesto()) {
        final provas = _contarProvas(_conteudo(e.caminho));
        expect(
          provas,
          greaterThanOrEqualTo(e.provasMinimas!),
          reason:
              '"${e.caminho}" (gate ${e.chave}) declara $provas provas e o '
              'piso é ${e.provasMinimas}. Uma suíte que encolhe continua '
              'saindo verde no agregador — é por isso que o piso existe.',
        );
      }
    });

    test('S8 — os blocos obrigatórios continuam na suíte', () {
      for (final e in _lerManifesto()) {
        final conteudo = _semComentarios(_conteudo(e.caminho));
        for (final bloco in e.exige) {
          expect(
            conteudo,
            contains(bloco),
            reason:
                'o bloco $bloco sumiu de "${e.caminho}" (gate ${e.chave}). '
                'A busca é pelo literal de código com o parêntese da chamada, '
                'e ignora linhas de comentário — repetir o texto num '
                'comentário não satisfaz o contrato.',
          );
        }
      }
    });

    test('S9 — o contrato do manifesto não pode encolher nem faltar', () {
      final porChave = {for (final e in _lerManifesto()) e.chave: e};

      // Toda entrada declara contrato. Uma entrada sem `sha256`, sem `provas`
      // ou sem nenhum `exige` seria uma linha que não guarda nada.
      for (final e in porChave.values) {
        expect(
          e.sha256Esperado,
          isNotNull,
          reason: 'a entrada "${e.chave}" não declara `sha256`',
        );
        expect(
          RegExp(r'^[0-9a-f]{64}$').hasMatch(e.sha256Esperado ?? ''),
          isTrue,
          reason: 'o `sha256` de "${e.chave}" não é um digest de 64 hex',
        );
        expect(
          e.provasMinimas,
          isNotNull,
          reason: 'a entrada "${e.chave}" não declara `provas`',
        );
        expect(
          e.exige,
          isNotEmpty,
          reason: 'a entrada "${e.chave}" não declara nenhum `exige`',
        );
      }

      // E o contrato das chaves desta OS não encolhe abaixo do que está
      // escrito aqui, no código — senão baixar `provas` no manifesto seria a
      // saída silenciosa que o resto do arquivo existe para fechar.
      for (final m in _minimas.entries) {
        final e = porChave[m.key];
        expect(e, isNotNull, reason: 'o gate "${m.key}" saiu do manifesto');
        expect(
          e!.provasMinimas,
          greaterThanOrEqualTo(m.value.provas),
          reason:
              'o piso de "${m.key}" foi baixado de ${m.value.provas} para '
              '${e.provasMinimas} no manifesto',
        );
        for (final bloco in m.value.blocos) {
          expect(
            e.exige,
            contains(bloco),
            reason: 'o bloco $bloco saiu do contrato de "${m.key}"',
          );
        }
      }
    });
  });
}
