// js_bridge.dart — expoe o dominio de moderacao para as Cloud Functions.
//
// MESMO MOTIVO DO BRIDGE DE TORNEIOS: as Functions rodam em Node/TypeScript e a
// decisao de moderacao e escrita em Dart. Reescrever "o que e uma denuncia
// valida" em TypeScript criaria uma SEGUNDA implementacao das mesmas regras, e
// as duas divergiriam no primeiro dia em que alguem apertasse um limite so de um
// lado — com o agravante de que, aqui, a versao frouxa e uma porta de abuso.
//
// `dart compile js` transforma ESTE arquivo (e o dominio que ele importa) num
// bundle que o Node carrega. A regra existe uma vez so, em Dart, testada pela
// mesma suite que o app usa (app/test/moderacao/).
//
// FRONTEIRA: aqui so entra conversao de tipo. Nenhuma decisao mora neste
// arquivo. Autenticacao, transacao e escrita sao do TypeScript; regra e do
// dominio; este arquivo e so o cabo entre os dois.
//
// Compilar com:
//   dart compile js -O2 -o functions-moderacao/lib/domain_bundle.js \
//       lib/moderacao/js_bridge.dart

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'denuncia.dart';
import 'relacao_social.dart';
import 'sancao.dart';

/// Objeto global que o Node enxerga como `globalThis.bmvModeracao`.
@JS('bmvModeracao')
external set _bmvModeracao(JSObject valor);

typedef _Ponte = String Function(String);

Map<String, Object?> _entrada(String json) =>
    (jsonDecode(json) as Map).cast<String, Object?>();

/// Converte nome de enum, devolvendo `null` quando o cliente mandou algo que nao
/// existe — em vez de estourar. Valor desconhecido e entrada invalida, e entrada
/// invalida merece recusa estruturada, nao erro 500.
T? _porNome<T extends Enum>(List<T> valores, Object? nome) {
  if (nome is! String) return null;
  for (final v in valores) {
    if (v.name == nome) return v;
  }
  return null;
}

DateTime? _instante(Object? v) {
  if (v is! String) return null;
  return DateTime.tryParse(v)?.toUtc();
}

// ------------------------------------------------------------------ denuncia

String avaliarDenunciaJson(String json) {
  final e = _entrada(json);

  final tipo = _porNome(TipoDenuncia.values, e['tipo']);
  if (tipo == null) {
    return jsonEncode(const VereditoDenuncia.recusada(
            RecusaDenuncia.categoriaInvalidaParaTipo, ['tipo'])
        .toJson());
  }

  final categoria = _porNome(CategoriaDenuncia.values, e['categoria']);
  if (categoria == null) {
    return jsonEncode(const VereditoDenuncia.recusada(
            RecusaDenuncia.categoriaInvalidaParaTipo, ['categoria'])
        .toJson());
  }

  final ref = (e['referencias'] as Map?)?.cast<String, Object?>() ?? const {};

  final veredito = avaliarDenuncia(
    denuncianteUid: (e['denuncianteUid'] as String?) ?? '',
    denunciadoUid: (e['denunciadoUid'] as String?) ?? '',
    tipo: tipo,
    categoria: categoria,
    reportIntentId: (e['reportIntentId'] as String?) ?? '',
    comentario: e['comentario'] as String?,
    referencias: ReferenciasDenuncia(
      matchId: ref['matchId'] as String?,
      roomId: ref['roomId'] as String?,
      messageId: ref['messageId'] as String?,
    ),
    jaNaJanela: (e['jaNaJanela'] as num?)?.toInt() ?? 0,
  );

  // A chave so acompanha o veredito aceito: calcular sobre entrada invalida
  // estouraria, e nao ha documento a criar de qualquer maneira.
  return jsonEncode({
    ...veredito.toJson(),
    if (veredito.aceita)
      'chave': chaveDeDenuncia(
        denuncianteUid: e['denuncianteUid']! as String,
        reportIntentId: e['reportIntentId']! as String,
      ),
    'esquema': kEsquemaDenuncia,
  });
}

/// Traduz o status interno no status que o denunciante pode ver.
String statusPublicoJson(String json) {
  final e = _entrada(json);
  final s = _porNome(StatusDenuncia.values, e['status']);
  return jsonEncode({
    'publico': (s ?? StatusDenuncia.recebida).publico.name,
  });
}

// ------------------------------------------------------------ relacao social

String avaliarBloqueioJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarBloqueio(
    bloqueadorUid: (e['bloqueadorUid'] as String?) ?? '',
    bloqueadoUid: (e['bloqueadoUid'] as String?) ?? '',
    jaBloqueados: (e['jaBloqueados'] as num?)?.toInt() ?? 0,
  ).toJson());
}

String avaliarMuteJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarMute(
    donoUid: (e['donoUid'] as String?) ?? '',
    alvoUid: (e['alvoUid'] as String?) ?? '',
  ).toJson());
}

String avaliarContatoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarContato(
    origemBloqueouDestino: e['origemBloqueouDestino'] == true,
    destinoBloqueouOrigem: e['destinoBloqueouOrigem'] == true,
    origemComChatSilenciado: e['origemComChatSilenciado'] == true,
    origemComRestricaoSocial: e['origemComRestricaoSocial'] == true,
  ).toJson());
}

// -------------------------------------------------------------------- sancao

String avaliarSancaoJson(String json) {
  final e = _entrada(json);

  final tipo = _porNome(TipoSancao.values, e['tipo']);
  if (tipo == null) {
    return jsonEncode(const VereditoSancao.recusada(
            RecusaSancao.identificadorInvalido, ['tipo'])
        .toJson());
  }

  final inicio = _instante(e['inicio']);
  if (inicio == null) {
    return jsonEncode(const VereditoSancao.recusada(
            RecusaSancao.prazoAusente, ['inicio'])
        .toJson());
  }

  final fimBruto = e['fim'];
  final fim = _instante(fimBruto);
  if (fimBruto != null && fim == null) {
    return jsonEncode(
        const VereditoSancao.recusada(RecusaSancao.prazoAusente, ['fim'])
            .toJson());
  }

  return jsonEncode(avaliarSancao(
    userId: (e['userId'] as String?) ?? '',
    responsavel: (e['responsavel'] as String?) ?? '',
    tipo: tipo,
    motivo: (e['motivo'] as String?) ?? '',
    inicio: inicio,
    fim: fim,
  ).toJson());
}

/// Dobra o historico de sancoes no efeito vigente em `agora`.
///
/// O servidor manda `agora` porque e ele quem congela o instante da operacao —
/// ver o comentario de topo de sancao.dart.
String consolidarSancoesJson(String json) {
  final e = _entrada(json);
  final agora = _instante(e['agora']);
  if (agora == null) {
    return jsonEncode({'erro': 'agora ausente ou sem fuso'});
  }

  final lista = (e['sancoes'] as List?) ?? const [];
  final sancoes = <Sancao>[];
  for (final item in lista) {
    sancoes.add(Sancao.fromMap((item as Map).cast<String, Object?>()));
  }

  return jsonEncode(
      consolidar((e['userId'] as String?) ?? '', sancoes, agora).toJson());
}

void main() {
  final api = <String, _Ponte>{
    'avaliarDenuncia': avaliarDenunciaJson,
    'statusPublico': statusPublicoJson,
    'avaliarBloqueio': avaliarBloqueioJson,
    'avaliarMute': avaliarMuteJson,
    'avaliarContato': avaliarContatoJson,
    'avaliarSancao': avaliarSancaoJson,
    'consolidarSancoes': consolidarSancoesJson,
  };

  final exportado = JSObject();
  api.forEach((nome, fn) {
    exportado.setProperty(
        nome.toJS, ((JSString entrada) => fn(entrada.toDart).toJS).toJS);
  });
  _bmvModeracao = exportado;
}
