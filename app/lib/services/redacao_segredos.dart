// redacao_segredos.dart — apaga segredo de qualquer texto que possa ser visto.
//
// ---------------------------------------------------------------------------
// POR QUE ISSO EXISTE
//
// A credencial da conexão é um Firebase ID Token: um JWT que vale por uma hora
// e que, na mão de outra pessoa, É a conta. Ele não pode aparecer em log,
// mensagem de erro, `toString()`, captura de tela, relatório de falha nem
// documentação.
//
// O caminho normal já cuida disso: o token sai uma única vez, dentro da
// mensagem `auth`, e nada mais o toca. O problema é o caminho ANORMAL — a
// exceção que traz o corpo da mensagem junto, o `toString()` de um objeto de
// erro, o texto de diagnóstico que alguém acrescenta depois. Nesses lugares o
// segredo entra por acidente, e é justamente onde ninguém está olhando.
//
// Então a regra aqui é a inversa da usual: em vez de confiar que o segredo não
// chegou, este arquivo assume que chegou e apaga. É barato, e o custo de errar
// para o outro lado é uma conta invadida.
//
// Vale para tudo que identifica ou dá acesso: token, uid, e-mail,
// `purchaseToken` da Play e chaves/segredos em geral.
// ---------------------------------------------------------------------------

/// Marca que substitui o segredo. Igual em todos os casos de propósito: quem lê
/// o log precisa saber que havia algo ali, e nada além disso.
const String marcaDeRedacao = '[REDIGIDO]';

/// JWT: três blocos base64url separados por ponto. É o formato do ID Token do
/// Firebase e o da maioria das credenciais que passam por aqui.
final RegExp _jwt = RegExp(
  r'\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b',
);

/// Campo nomeado carregando segredo, em JSON ou em texto solto:
/// `"token":"..."`, `token=...`, `purchaseToken: ...`, `apiKey=...`.
final RegExp _campoSensivel = RegExp(
  r'''(["']?\b(?:id_?token|access_?token|refresh_?token|token|purchase_?token|senha|password|secret|api_?key|authorization|bearer|uid|user_?id|credential)\b["']?\s*[:=]\s*)(["']?)([^"'\s,;&}\]]+)\2''',
  caseSensitive: false,
);

/// `Authorization: Bearer <token>` — cabeçalho, que aparece em dump de request.
final RegExp _bearer = RegExp(
  r'\bBearer\s+[A-Za-z0-9._~+/=-]{8,}',
  caseSensitive: false,
);

/// E-mail. Dado pessoal: não é credencial, mas identifica a pessoa e não tem o
/// que fazer em log.
final RegExp _email = RegExp(
  r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
);

/// Qualquer coisa depois de `?` ou `&` numa URL. Credencial NÃO vai em query
/// string neste app — isto aqui é a rede de segurança para o dia em que alguém
/// colar uma URL de outro lugar num texto de diagnóstico.
final RegExp _queryDeUrl = RegExp(r'([?&][^=\s]+=)([^\s&#]+)');

/// Devolve [texto] sem segredo. Seguro para log, para a UI e para anexar em
/// relatório de erro.
String redigir(String texto) {
  if (texto.isEmpty) return texto;
  var s = texto;
  // A ordem importa: o JWT sai primeiro, senão o casamento por campo poderia
  // recortar só um pedaço dele e deixar o resto legível.
  s = s.replaceAll(_jwt, marcaDeRedacao);
  s = s.replaceAll(_bearer, 'Bearer $marcaDeRedacao');
  s = s.replaceAllMapped(_campoSensivel, (m) => '${m[1]}${m[2]}$marcaDeRedacao${m[2]}');
  s = s.replaceAll(_email, marcaDeRedacao);
  s = s.replaceAllMapped(_queryDeUrl, (m) => '${m[1]}$marcaDeRedacao');
  return s;
}

/// Versão para qualquer objeto — o caso comum é uma exceção cujo `toString()`
/// traz junto o que causou a falha.
String redigirObjeto(Object? valor) =>
    valor == null ? '' : redigir(valor.toString());
