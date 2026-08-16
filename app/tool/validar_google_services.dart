// validar_google_services.dart — portão do arquivo de configuração Firebase.
//
// Roda no CI antes do Gradle. O plugin google-services até reclama quando o
// pacote não bate, mas a mensagem dele é obscura e chega no meio de um log de
// build de sete minutos. Aqui a reprovação é a primeira coisa que aparece.
//
// Uso:
//   dart run app/tool/validar_google_services.dart \
//     --json=<caminho do google-services.json> \
//     --esperado=app/data/observabilidade/firebase_app_oficial.json
//
// Exit: 0 PASS · 1 FAIL · 2 erro de uso.
//
// O conteúdo do google-services.json NUNCA é impresso — nem em erro.

import 'dart:io';

import '../lib/observability/config_firebase.dart';

void main(List<String> args) {
  String? valor(String nome) {
    for (final a in args) {
      if (a.startsWith('--$nome=')) return a.substring(nome.length + 3);
    }
    return null;
  }

  final caminhoJson = valor('json');
  final caminhoEsperado = valor('esperado');
  if (caminhoJson == null || caminhoEsperado == null) {
    stderr.writeln('uso: --json=<google-services.json> --esperado=<app oficial>');
    exit(2);
  }

  final arquivoEsperado = File(caminhoEsperado);
  if (!arquivoEsperado.existsSync()) {
    stderr.writeln('ERRO: descrição do app oficial não encontrada: $caminhoEsperado');
    exit(2);
  }

  final AppFirebaseEsperado esperado;
  try {
    esperado = AppFirebaseEsperado.deJson(arquivoEsperado.readAsStringSync());
  } catch (e) {
    stderr.writeln('ERRO: $caminhoEsperado não é um descritor válido: $e');
    exit(2);
  }

  final arquivoJson = File(caminhoJson);
  final conteudo = arquivoJson.existsSync() ? arquivoJson.readAsStringSync() : '';

  final r = validarGoogleServices(conteudoJson: conteudo, esperado: esperado);

  stdout.writeln('===== CONFIGURAÇÃO FIREBASE =====');
  stdout.writeln('projeto esperado:  ${esperado.projectId}');
  stdout.writeln('pacote esperado:   ${esperado.packageName}');
  stdout.writeln('App ID esperado:   ${esperado.mobilesdkAppId}');
  stdout.writeln('apps no arquivo:   ${r.clientesEncontrados}');
  for (final p in r.pacotesEncontrados) {
    stdout.writeln('  · $p${p == esperado.packageName ? '   <- o esperado' : ''}');
  }
  stdout.writeln('---------------------------------');
  stdout.writeln(r.veredito);

  // Anotação do GitHub Actions: sobe o motivo para o topo do run, em vez de
  // deixá-lo enterrado num log que só quem tem acesso de admin baixa.
  for (final motivo in r.reprovacoes) {
    stdout.writeln('::error title=google-services.json::$motivo');
  }
  exit(r.codigoDeSaida);
}
