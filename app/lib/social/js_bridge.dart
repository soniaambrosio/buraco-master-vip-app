// js_bridge.dart — expõe o domínio social para as Cloud Functions.
//
// MESMO MOTIVO DOS BRIDGES DE TORNEIOS E DE MODERAÇÃO: as Functions rodam em
// Node/TypeScript e a decisão é escrita em Dart. Reescrever "o que é um apelido
// válido", "quem pode aceitar" ou "quando o limite estoura" em TypeScript criaria
// uma SEGUNDA implementação das mesmas regras, e as duas divergiriam no primeiro
// dia em que alguém apertasse um limite só de um lado.
//
// FRONTEIRA: aqui só entra conversão de tipo. Nenhuma decisão mora neste arquivo.
// Autenticação, transação e escrita são do TypeScript; regra é do domínio; este
// arquivo é só o cabo entre os dois.
//
// Compilar com:
//   dart compile js -O2 -o functions-social/lib/domain_bundle.js \
//       app/lib/social/js_bridge.dart

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// O DOMÍNIO DE MODERAÇÃO ENTRA AQUI, e não é acidente de import.
//
// §18 manda CONSUMIR o bloqueio existente, nunca duplicá-lo. A forma mais forte
// de consumir é compilar a MESMA função no bundle social: `avaliarContato` de
// `moderacao/relacao_social.dart` é uma implementação só, testada pela suíte de
// moderação, e o codebase social a chama em vez de reescrever "quem pode falar
// com quem" em TypeScript.
import '../moderacao/relacao_social.dart' as moderacao;

import 'amizade.dart';
import 'apresentacao.dart';
import 'busca_apelido.dart';
import 'erros_sociais.dart';
import 'identidade_publica.dart';
import 'listagem_social.dart';

/// Objeto global que o Node enxerga como `globalThis.bmvSocial`.
@JS('bmvSocial')
external set _bmvSocial(JSObject valor);

typedef _Ponte = String Function(String);

Map<String, Object?> _entrada(String json) =>
    (jsonDecode(json) as Map).cast<String, Object?>();

int _inteiro(Object? v) => v is num ? v.toInt() : 0;

// ------------------------------------------------------------- identidade

String idPublicoDeBytesJson(String json) {
  final e = _entrada(json);
  final bytes =
      ((e['bytes'] as List?) ?? const []).map(_inteiro).toList(growable: false);
  try {
    return jsonEncode({'publicId': idPublicoDeBytes(bytes)});
  } on ArgumentError catch (erro) {
    return jsonEncode({'erro': '${erro.message}'});
  }
}

/// Normaliza e valida um id público vindo do cliente.
///
/// Devolve `{publicId: null}` em vez de erro quando não presta: entrada
/// malformada de cliente é caso comum, e um throw aqui viraria HTTP 500 no lugar
/// de uma recusa de domínio.
String normalizarIdPublicoJson(String json) {
  final e = _entrada(json);
  return jsonEncode({'publicId': normalizarIdPublico(e['publicId'])});
}

String recusaDeConsultaPublicaJson(String json) {
  final e = _entrada(json);
  final recusa = recusaDeConsultaPublica(
    idBruto: e['publicId'],
    existe: e['existe'] == true,
    estado: EstadoPerfilPublico.porNome(e['estado']),
  );
  return jsonEncode({'recusa': recusa?.name});
}

// ----------------------------------------------------------- apresentação

String avaliarAtualizacaoDeApresentacaoJson(String json) {
  final e = _entrada(json);
  final catalogo = ((e['catalogoAvatares'] as List?) ?? const [])
      .whereType<String>()
      .toSet();
  return jsonEncode(avaliarAtualizacaoDeApresentacao(
    apelidoBruto: e['apelido'] as String?,
    avatarRef: e['avatarRef'],
    removerAvatar: e['removerAvatar'] == true,
    agoraIso: (e['agora'] as String?) ?? '',
    catalogoAvatares: catalogo.isEmpty ? kCatalogoAvatares : catalogo,
  ).toJson());
}

/// A trava de §5: um documento que iria para `publicProfiles` pode ser gravado?
String conferirDocumentoPublicoJson(String json) {
  final e = _entrada(json);
  final doc = (e['documento'] as Map?)?.cast<String, Object?>() ?? const {};
  final ofensivas = conferirDocumentoPublico(doc);
  return jsonEncode({
    'ok': ofensivas.isEmpty,
    'ofensivas': ofensivas,
    // Marca separada para o log distinguir "campo desconhecido" de "dado
    // privado encostou no documento público" — o segundo é incidente.
    'privadas': ofensivas
        .where(camposProibidosNoPublico.contains)
        .toList(growable: false),
  });
}

/// Monta o documento público inicial de um jogador recém-identificado.
String perfilPublicoInicialJson(String json) {
  final e = _entrada(json);
  final agora = (e['agora'] as String?) ?? '';
  final apelidoBruto = (e['apelido'] as String?) ?? '';
  final apelido = normalizarApelido(apelidoBruto);
  // Apelido ausente ou impróprio no cadastro NÃO impede a identidade de nascer:
  // ela é pré-requisito de tudo. O perfil nasce sem apelido e a tela pede um.
  final apelidoFinal = recusaDeApelido(apelido) == null ? apelido : '';
  return jsonEncode(PerfilPublico(
    publicId: (e['publicId'] as String?) ?? '',
    apelido: apelidoFinal,
    avatarRef: null,
    estado: EstadoPerfilPublico.ativo,
    criadoEm: agora,
    atualizadoEm: agora,
  ).toJson());
}

// -------------------------------------------------------------- bloqueio

/// Reexporta o veredito de contato da MODERAÇÃO (§18).
///
/// Não há uma linha de política aqui: a função chamada é literalmente a mesma
/// que `functions-moderacao` usa. Se um dia o bloqueio ganhar uma regra nova,
/// ela vale nos dois codebases no mesmo commit, porque o código é um só.
String avaliarContatoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(moderacao.avaliarContato(
    origemBloqueouDestino: e['origemBloqueouDestino'] == true,
    destinoBloqueouOrigem: e['destinoBloqueouOrigem'] == true,
    origemComChatSilenciado: e['origemComChatSilenciado'] == true,
    origemComRestricaoSocial: e['origemComRestricaoSocial'] == true,
  ).toJson());
}

// ---------------------------------------------------------------- amizade

String chaveDoParJson(String json) {
  final e = _entrada(json);
  try {
    final a = (e['uidA'] as String?) ?? '';
    final b = (e['uidB'] as String?) ?? '';
    return jsonEncode({
      'pairKey': chaveDoPar(a, b),
      'membros': membrosOrdenados(a, b),
    });
  } on ArgumentError catch (erro) {
    return jsonEncode({'erro': '${erro.message}'});
  }
}

String avaliarSolicitacaoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarSolicitacao(
    solicitanteUid: (e['solicitanteUid'] as String?) ?? '',
    destinatarioUid: (e['destinatarioUid'] as String?) ?? '',
    estadoAtual: EstadoAmizade.porNome(e['estadoAtual']),
    solicitantePendenteUid: e['solicitantePendenteUid'] as String?,
    contatoPermitido: e['contatoPermitido'] == true,
    amigosDoSolicitante: _inteiro(e['amigosDoSolicitante']),
    amigosDoDestinatario: _inteiro(e['amigosDoDestinatario']),
    pendentesEnviadasDoSolicitante:
        _inteiro(e['pendentesEnviadasDoSolicitante']),
  ).toJson());
}

String avaliarAceiteJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarAceite(
    uidQueAceita: (e['uidQueAceita'] as String?) ?? '',
    estadoAtual: EstadoAmizade.porNome(e['estadoAtual']),
    destinatarioPendenteUid: e['destinatarioPendenteUid'] as String?,
    contatoPermitido: e['contatoPermitido'] == true,
    amigosDeQuemAceita: _inteiro(e['amigosDeQuemAceita']),
    amigosDoOutro: _inteiro(e['amigosDoOutro']),
  ).toJson());
}

String avaliarRecusaJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarRecusa(
    uidQueRecusa: (e['uidQueRecusa'] as String?) ?? '',
    estadoAtual: EstadoAmizade.porNome(e['estadoAtual']),
    destinatarioPendenteUid: e['destinatarioPendenteUid'] as String?,
  ).toJson());
}

String avaliarCancelamentoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarCancelamento(
    uidQueCancela: (e['uidQueCancela'] as String?) ?? '',
    estadoAtual: EstadoAmizade.porNome(e['estadoAtual']),
    solicitantePendenteUid: e['solicitantePendenteUid'] as String?,
  ).toJson());
}

String avaliarRemocaoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarRemocao(
    uidQueRemove: (e['uidQueRemove'] as String?) ?? '',
    estadoAtual: EstadoAmizade.porNome(e['estadoAtual']),
    ehMembro: e['ehMembro'] == true,
  ).toJson());
}

/// A vista de §31-A mais as ações de §31-B, numa travessia só.
///
/// Juntas de propósito: separá-las deixaria o TypeScript livre para calcular a
/// vista aqui e as ações lá, que é exatamente como as duas divergem.
String vistaDaRelacaoJson(String json) {
  final e = _entrada(json);
  final vista = vistaDaRelacao(
    uidObservador: (e['uidObservador'] as String?) ?? '',
    uidAlvo: (e['uidAlvo'] as String?) ?? '',
    estado: EstadoAmizade.porNome(e['estado']),
    solicitanteUid: e['solicitanteUid'] as String?,
    euBloqueeiOAlvo: e['euBloqueeiOAlvo'] == true,
    contatoPermitido: e['contatoPermitido'] == true,
  );
  return jsonEncode({
    'relacao': vista.name,
    'acoes': acoesDisponiveis(vista).map((a) => a.name).toList(growable: false),
  });
}

// ------------------------------------------------------------------ busca

/// Valida o pedido de busca e devolve a FAIXA de chaves a consultar.
///
/// O TypeScript recebe `chaveInicio`/`chaveFim` prontas e só as usa no
/// `where`/`orderBy`. Ele não sabe o que "prefixo" significa, e é assim que a
/// semântica da busca fica num lugar só.
String avaliarConsultaDeBuscaJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarConsultaDeBusca(
    termo: e['termo'],
    modo: e['modo'],
    limite: e['limite'],
  ).toJson());
}

/// A chave de comparação de um texto qualquer.
///
/// Exposta separadamente da consulta porque o TESTE de equivalência (§5: a
/// normalização da gravação e a da busca são a mesma) precisa comparar a chave
/// de um apelido com o `apelidoOrdenacao` gravado, sem passar pela validação.
String chaveDeBuscaJson(String json) {
  final e = _entrada(json);
  final termo = e['termo'];
  return jsonEncode({
    'chave': termo is String ? chaveDeBusca(termo) : null,
  });
}

/// Filtra os candidatos pelo bloqueio e rotula cada um com relação e ações.
///
/// ENTRA UID, NÃO SAI UID. Os uids dos candidatos são necessários para compor a
/// relação (quem é o solicitante? sou eu mesmo?) e morrem nesta função: o mapa
/// devolvido tem `publicId`, `relacao` e `acoes`, e mais nada.
String projetarResultadosDeBuscaJson(String json) {
  final e = _entrada(json);
  final candidatos = ((e['candidatos'] as List?) ?? const []).map((bruto) {
    final m = (bruto as Map).cast<String, Object?>();
    return CandidatoDeBusca(
      publicId: (m['publicId'] as String?) ?? '',
      uidAlvo: (m['uidAlvo'] as String?) ?? '',
      estado: EstadoAmizade.porNome(m['estado']),
      solicitanteUid: m['solicitanteUid'] as String?,
      euBloqueeiOAlvo: m['euBloqueeiOAlvo'] == true,
      alvoMeBloqueou: m['alvoMeBloqueou'] == true,
    );
  }).toList(growable: false);

  final resultados = projetarResultadosDeBusca(
    uidObservador: (e['uidObservador'] as String?) ?? '',
    candidatos: candidatos,
    observadorComChatSilenciado: e['observadorComChatSilenciado'] == true,
    observadorComRestricaoSocial: e['observadorComRestricaoSocial'] == true,
  );

  return jsonEncode({
    'itens': resultados.map((r) => r.toJson()).toList(growable: false),
  });
}

// --------------------------------------------------------------- listagem

String paginarAmigosJson(String json) {
  final e = _entrada(json);
  final itens = ((e['itens'] as List?) ?? const []).map((bruto) {
    final m = (bruto as Map).cast<String, Object?>();
    return EntradaSocial(
      publicId: (m['publicId'] as String?) ?? '',
      apelido: (m['apelido'] as String?) ?? '',
      avatarRef: m['avatarRef'] as String?,
      desde: m['desde'] as String?,
    );
  }).toList(growable: false);

  return jsonEncode(paginarAmigos(
    itens,
    cursor: e['cursor'] as String?,
    limite: tamanhoDePagina(e['limite']),
  ).toJson());
}

/// Os limites e constantes que o TypeScript precisa conhecer.
///
/// Vêm daqui, e não de uma cópia em TS, porque §25 pede limites "centralizados/
/// configuráveis" e "não espalhar números mágicos". Dois lugares com o número 200
/// já são um lugar a mais.
String constantesJson(String _) => jsonEncode({
      'limiteAmigos': kLimiteAmigos,
      'limiteSolicitacoesEnviadas': kLimiteSolicitacoesEnviadas,
      'limiteSolicitacoesRecebidas': kLimiteSolicitacoesRecebidas,
      'comprimentoIdPublico': kComprimentoIdPublico,
      'prefixoIdPublico': kPrefixoIdPublico,
      'tamanhoTotalIdPublico': kTamanhoTotalIdPublico,
      'apelidoMinimo': kApelidoMinimo,
      'apelidoMaximo': kApelidoMaximo,
      'paginaPadrao': kPaginaPadrao,
      'paginaMaxima': kPaginaMaxima,
      'consultaMinima': kConsultaMinima,
      'consultaMaxima': kConsultaMaxima,
      'resultadosPadrao': kResultadosPadrao,
      'resultadosMaximo': kResultadosMaximo,
      'buscaComCursor': !kSemCursor,
      'esquema': kEsquemaSocial,
      'camposPublicos': camposPublicos.toList(growable: false),
      'errosConhecidos':
          ErroSocial.values.map((e) => e.name).toList(growable: false),
    });

void main() {
  final api = <String, _Ponte>{
    'idPublicoDeBytes': idPublicoDeBytesJson,
    'normalizarIdPublico': normalizarIdPublicoJson,
    'recusaDeConsultaPublica': recusaDeConsultaPublicaJson,
    'avaliarAtualizacaoDeApresentacao': avaliarAtualizacaoDeApresentacaoJson,
    'conferirDocumentoPublico': conferirDocumentoPublicoJson,
    'perfilPublicoInicial': perfilPublicoInicialJson,
    'avaliarContato': avaliarContatoJson,
    'chaveDoPar': chaveDoParJson,
    'avaliarSolicitacao': avaliarSolicitacaoJson,
    'avaliarAceite': avaliarAceiteJson,
    'avaliarRecusa': avaliarRecusaJson,
    'avaliarCancelamento': avaliarCancelamentoJson,
    'avaliarRemocao': avaliarRemocaoJson,
    'vistaDaRelacao': vistaDaRelacaoJson,
    'avaliarConsultaDeBusca': avaliarConsultaDeBuscaJson,
    'chaveDeBusca': chaveDeBuscaJson,
    'projetarResultadosDeBusca': projetarResultadosDeBuscaJson,
    'paginarAmigos': paginarAmigosJson,
    'constantes': constantesJson,
  };

  final exportado = JSObject();
  api.forEach((nome, fn) {
    exportado.setProperty(
        nome.toJS, ((JSString entrada) => fn(entrada.toDart).toJS).toJS);
  });
  _bmvSocial = exportado;
}
