// config_firebase.dart — o google-services.json é do app certo?
//
// O projeto Firebase do Buraco Master VIP tem QUATRO aplicativos Android
// registrados, três deles históricos. Um `google-services.json` com o app
// errado não quebra o build: o app instala, roda, e manda crash para um painel
// que ninguém abre. O erro só aparece semanas depois, quando alguém pergunta
// por que o Crashlytics está vazio.
//
// Este arquivo transforma esse silêncio em falha de build.
//
// Dart puro, sem `package:flutter`: roda no gate (`dart run`) e é exercitado
// pela suíte, que é o que garante que CI e teste julguem pela mesma regra.
//
// REGRA DE SAÍDA: nenhuma mensagem daqui pode conter valor lido do arquivo.
// O google-services.json carrega chaves de API; as mensagens falam de
// PRESENÇA e de IGUALDADE, e citam apenas os valores ESPERADOS, que são
// públicos (viajam dentro de todo APK).

import 'dart:convert';

/// O aplicativo Android que esta release deve usar.
class AppFirebaseEsperado {
  const AppFirebaseEsperado({
    required this.projectId,
    required this.projectNumber,
    required this.packageName,
    required this.mobilesdkAppId,
    this.displayName = '',
  });

  final String projectId;
  final String projectNumber;
  final String packageName;
  final String mobilesdkAppId;
  final String displayName;

  factory AppFirebaseEsperado.deJson(String texto) {
    final j = jsonDecode(texto) as Map<String, Object?>;
    return AppFirebaseEsperado(
      projectId: (j['projectId'] as String?) ?? '',
      projectNumber: (j['projectNumber'] as String?) ?? '',
      packageName: (j['packageName'] as String?) ?? '',
      mobilesdkAppId: (j['mobilesdkAppId'] as String?) ?? '',
      displayName: (j['displayName'] as String?) ?? '',
    );
  }

  @override
  String toString() => '$packageName ($mobilesdkAppId)';
}

/// Veredito da conferência.
class ResultadoConfigFirebase {
  ResultadoConfigFirebase(List<String> reprovacoes, {this.clientesEncontrados = 0})
      : reprovacoes = List<String>.unmodifiable(reprovacoes);

  final List<String> reprovacoes;

  /// Quantos aplicativos Android o arquivo declara. Um `google-services.json`
  /// de projeto costuma trazer todos; saber quantos ajuda a diagnosticar.
  final int clientesEncontrados;

  bool get aprovado => reprovacoes.isEmpty;
  int get codigoDeSaida => aprovado ? 0 : 1;

  String get veredito => aprovado
      ? 'PASS — google-services.json corresponde ao app Android oficial'
      : 'FAIL — ${reprovacoes.length} reprovação(ões):\n  · ${reprovacoes.join('\n  · ')}';
}

/// Confere um `google-services.json` contra o app que a release exige.
///
/// [conteudoJson] é o arquivo cru. Ele NUNCA é ecoado, nem em pedaço.
ResultadoConfigFirebase validarGoogleServices({
  required String conteudoJson,
  required AppFirebaseEsperado esperado,
}) {
  if (conteudoJson.trim().isEmpty) {
    return ResultadoConfigFirebase(
        <String>['google-services.json vazio ou ausente']);
  }

  Map<String, Object?> raiz;
  try {
    final bruto = jsonDecode(conteudoJson);
    if (bruto is! Map<String, Object?>) {
      return ResultadoConfigFirebase(
          <String>['google-services.json não é um objeto JSON']);
    }
    raiz = bruto;
  } catch (_) {
    // A exceção do parser cita o trecho onde falhou — e esse trecho pode ser
    // uma chave de API. Por isso ela não entra na mensagem.
    return ResultadoConfigFirebase(
        <String>['google-services.json não é JSON válido']);
  }

  final reprovacoes = <String>[];

  final info = raiz['project_info'];
  if (info is! Map) {
    reprovacoes.add('bloco `project_info` ausente');
    return ResultadoConfigFirebase(reprovacoes);
  }

  final projectId = '${info['project_id'] ?? ''}';
  final projectNumber = '${info['project_number'] ?? ''}';
  if (projectId != esperado.projectId) {
    reprovacoes.add('project_id diverge: esperado `${esperado.projectId}`');
  }
  if (esperado.projectNumber.isNotEmpty && projectNumber != esperado.projectNumber) {
    reprovacoes
        .add('project_number diverge: esperado `${esperado.projectNumber}`');
  }

  final clientes = raiz['client'];
  if (clientes is! List || clientes.isEmpty) {
    reprovacoes.add('nenhum aplicativo declarado no bloco `client`');
    return ResultadoConfigFirebase(reprovacoes);
  }

  Map<String, Object?>? oClienteCerto;
  final pacotesVistos = <String>[];
  for (final c in clientes) {
    if (c is! Map) continue;
    final ci = c['client_info'];
    if (ci is! Map) continue;
    final aci = ci['android_client_info'];
    if (aci is! Map) continue;
    final pacote = '${aci['package_name'] ?? ''}';
    pacotesVistos.add(pacote);
    if (pacote == esperado.packageName) {
      oClienteCerto = c.cast<String, Object?>();
    }
  }

  if (oClienteCerto == null) {
    reprovacoes.add(
        'o arquivo não declara o pacote `${esperado.packageName}`; '
        'declara ${pacotesVistos.length} pacote(s), nenhum deles o esperado');
    return ResultadoConfigFirebase(reprovacoes,
        clientesEncontrados: pacotesVistos.length);
  }

  final ci = oClienteCerto['client_info'] as Map;
  final appId = '${ci['mobilesdk_app_id'] ?? ''}';
  if (appId != esperado.mobilesdkAppId) {
    // O App ID esperado é público; o encontrado NÃO é ecoado, para que uma
    // mensagem de erro não vire um inventário dos apps do projeto.
    reprovacoes.add(
        'mobilesdk_app_id do pacote `${esperado.packageName}` não é o esperado '
        '(`${esperado.mobilesdkAppId}`)');
  }

  final chaves = oClienteCerto['api_key'];
  final temChave = chaves is List &&
      chaves.any((k) =>
          k is Map && '${k['current_key'] ?? ''}'.trim().isNotEmpty);
  if (!temChave) {
    reprovacoes.add('o pacote `${esperado.packageName}` está sem `api_key`');
  }

  return ResultadoConfigFirebase(reprovacoes,
      clientesEncontrados: pacotesVistos.length);
}
