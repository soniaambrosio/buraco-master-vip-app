// passo_os16.dart — a CLI que `ferramentas/ci/portao_os16.sh` executa.
//
// Casca fina, de propósito: toda a decisão mora em
// `app/test/casca/passo_os16_yaml.dart`, o MESMO arquivo que
// `app/test/casca/auditoria_casca_test.dart` importa. O portão em bash e a
// autoridade Dart dos gates não decidem cada um do seu jeito — decidem com o
// mesmo código, sobre a mesma estrutura.
//
// Uso:   dart run ferramentas/ci/passo_os16/bin/passo_os16.dart [raiz]
// Saída: 0 = os TRÊS workflows aprovados.  1 = qualquer falha.
//
// Ausência é REPROVAÇÃO em todos os caminhos: contrato que não existe, contrato
// vazio, contrato que não enumera três workflows, workflow que sumiu, YAML que
// não abre. Nenhum deles sai zero.

import 'dart:io';

import '../../../../app/test/casca/passo_os16_yaml.dart';

const String _contratoRelativo = 'app/test/casca/contrato_os16_resultado.txt';

int main(List<String> argumentos) {
  final raiz = argumentos.isEmpty ? '.' : argumentos.first;
  final falhas = <String>[];

  final arquivoContrato = File('$raiz/$_contratoRelativo');
  if (!arquivoContrato.existsSync()) {
    stdout.writeln('REPROVA [Y90] contrato ausente: $_contratoRelativo — '
        'ausência NÃO é conformidade');
    return _fim(1);
  }
  // O CR sai antes de qualquer leitura: com `core.autocrlf=true` o mesmo commit
  // chega em LF no runner e em CRLF no Windows, e os campos deste contrato são
  // partidos por `|` e por espaço — um `\r` grudado no último campo reprovaria
  // a árvore ÍNTEGRA.
  final contrato = arquivoContrato.readAsStringSync().replaceAll('\r', '');
  if (contrato.trim().isEmpty) {
    stdout.writeln('REPROVA [Y91] contrato vazio: $_contratoRelativo');
    return _fim(1);
  }

  final invocacoes = _repetida(contrato, 'invocacao');
  if (invocacoes.length != 1) {
    stdout.writeln('REPROVA [Y92] o contrato declara ${invocacoes.length} '
        'invocação(ões) — esperava exatamente 1');
    return _fim(1);
  }
  final invocacao = invocacoes.single;

  final declarados = _repetida(contrato, 'workflow');
  if (declarados.length != 3) {
    stdout.writeln('REPROVA [Y93] o contrato enumera ${declarados.length} '
        'workflow(s) — a OS 16 protege exatamente 3');
    return _fim(1);
  }

  for (final entrada in declarados) {
    final partes = entrada.split('|').map((s) => s.trim()).toList();
    if (partes.length != 3) {
      falhas.add('REPROVA [Y94] entrada de workflow malformada: "$entrada"');
      continue;
    }
    final caminho = partes[0];
    final nomePasso = partes[1];
    final ancora = partes[2];

    final arquivo = File('$raiz/$caminho');
    if (!arquivo.existsSync()) {
      falhas.add('REPROVA [Y95] workflow ausente: $caminho — ausência NÃO é '
          'conformidade');
      continue;
    }

    // Exceção do parser, tipo inesperado, nó ausente: tudo VERMELHO. Não há
    // `catch` que devolva conformidade.
    List<FalhaPassoOS16> achados;
    try {
      achados = auditarPassoOS16(
        caminho: caminho,
        textoYaml: arquivo.readAsStringSync(),
        nomePasso: nomePasso,
        invocacao: invocacao,
        ancora: ancora,
      );
    } catch (e) {
      falhas.add('REPROVA [Y96] $caminho: a auditoria estrutural falhou: $e');
      continue;
    }
    if (achados.isEmpty) {
      stdout.writeln('  ok  $caminho: passo canônico único, exato, alcançável '
          'e anterior à âncora');
    } else {
      falhas.addAll(achados.map((f) => f.toString()));
    }
  }

  for (final f in falhas) {
    stdout.writeln(f);
  }
  return _fim(falhas.isEmpty ? 0 : 1);
}

int _fim(int codigo) {
  exitCode = codigo;
  return codigo;
}

/// Todos os valores de uma chave `chave: valor` do contrato.
List<String> _repetida(String contrato, String chave) {
  final saida = <String>[];
  for (final linha in contrato.split('\n')) {
    if (!linha.startsWith('$chave:')) continue;
    saida.add(linha.substring(chave.length + 1).trim());
  }
  return saida;
}
