// Endereco do servidor que entra no AAB de release — validacao e prova.
//
// Uso (antes do build): imprime a forma canonica em stdout, ou sai com 1.
//   dart run tools/android/bin/verificar_endpoint.dart \
//     --arquivo=tools/android/release/servidor_url.txt
//
// Uso (depois do build): prova que o valor esta compilado no artefato.
//   dart run tools/android/bin/verificar_endpoint.dart \
//     --arquivo=tools/android/release/servidor_url.txt \
//     --aab=app_build/build/app/outputs/bundle/release/app-release.aab
//
// A politica e a razao de cada peca estao em `lib/endpoint_de_release.dart`.
import 'dart:io';

import 'package:bmv_android/endpoint_de_release.dart';

void main(List<String> argumentos) {
  final args = <String, String>{};
  for (final a in argumentos) {
    final m = RegExp(r'^--([a-z-]+)=(.*)$').firstMatch(a);
    if (m == null) {
      stderr.writeln('argumento nao reconhecido: $a');
      exit(2);
    }
    args[m.group(1)!] = m.group(2)!;
  }
  final caminho = args['arquivo'];
  if (caminho == null || caminho.isEmpty) {
    stderr.writeln(
      'uso: --arquivo=<servidor_url.txt> [--aab=<app-release.aab>]',
    );
    exit(2);
  }

  try {
    final arquivo = File(caminho);
    if (!arquivo.existsSync()) {
      throw EndpointDeReleaseInvalido(
        '$caminho nao existe — nenhum backend foi autorizado para o release',
      );
    }
    final endpoint = validarEndpointDeRelease(
      lerArquivoDeEndpoint(arquivo.readAsStringSync()),
    );

    final aab = args['aab'];
    if (aab == null) {
      stdout.writeln(endpoint);
      return;
    }
    final c = conferirEndpointNoAab(File(aab).readAsBytesSync(), endpoint);
    stdout.writeln('endpoint autorizado: $endpoint');
    c.ocorrenciasPorAbi.forEach(
      (so, n) => stdout.writeln('  $so: $n ocorrencia(s)'),
    );
    stdout.writeln('literais ws(s):// no artefato:');
    for (final e in c.enderecosWebSocket.toList()..sort()) {
      stdout.writeln('  $e');
    }
    stdout.writeln(
      'OK: o endereco autorizado esta compilado em todas as ABIs.',
    );
  } on EndpointDeReleaseInvalido catch (e) {
    stderr.writeln('ERRO: ${e.motivo}');
    exit(1);
  }
}
