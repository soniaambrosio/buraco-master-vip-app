// redacao.dart — o filtro entre a falha e o coletor.
//
// Regra da casa: NADA sai daqui sem passar por [Redator]. Mensagem, chave de
// contexto, valor de contexto, `toString()` da exceção e cada exceção aninhada
// da cadeia de causas passam pelo mesmo filtro — não existe atalho que
// contorne a redação, porque `EventoFalha` só se constrói através dela.
//
// A postura é adversarial: quando um valor é suspeito, ele some. Perder um
// detalhe de diagnóstico é barato; vazar um `purchaseToken` num ticket, não.
//
// Duas defesas independentes, para que uma falha não deixe o dado passar:
//   1. NEGAÇÃO POR CHAVE — se a chave se chama `uid`, `email`, `token`,
//      `purchaseToken`, `mao`…, o valor inteiro é substituído. Não importa
//      o formato do valor.
//   2. NEGAÇÃO POR FORMA — dentro de qualquer texto livre, o que TEM CARA de
//      segredo (JWT, chave de API, e-mail, blob opaco longo, carta de baralho)
//      é substituído mesmo sem chave nenhuma por perto.
//
// A rede larga da defesa 2 vale para MENSAGEM e CONTEXTO. Stack trace usa
// [Redator.stack], que aplica só os padrões inequívocos: um stack trace é
// estrutura gerada pelo compilador, e varrer blob opaco ali destruiria
// justamente o que responde "onde quebrou?".

/// Marca deixada no lugar do que foi removido. Aparece nos relatórios e é o
/// sinal de que a redação funcionou — não é erro.
const String marcaRedacao = '[REDIGIDO]';

/// Nomes de campo cujo VALOR nunca pode sair do dispositivo.
///
/// Comparação por conter-substring, em minúsculas: `firebaseIdToken`,
/// `x-access-token` e `TOKEN` caem todos em `token`.
const List<String> chavesProibidas = <String>[
  'uid',
  'userid',
  'user_id',
  'playerid',
  'accountid',
  'email',
  'mail',
  'nome',
  'name',
  'apelido',
  'nickname',
  'telefone',
  'phone',
  'cpf',
  'token',
  'jwt',
  'credential',
  'senha',
  'password',
  'secret',
  'apikey',
  'api_key',
  'authorization',
  'auth',
  'cookie',
  'session',
  'assinatura',
  'signature',
  'purchase',
  'order',
  'receipt',
  'mao',
  'hand',
  'cartas',
  'carta',
  'baralho',
  'lixo',
  'monte',
  'chat',
  'mensagem',
  'message',
  'texto',
  'payload',
  'body',
  'socket',
];

/// Filtro de saída. Sem estado — todos os métodos são puros e reentrantes.
class Redator {
  const Redator();

  // --- negação por forma -----------------------------------------------

  // JWT / ID token do Firebase: três segmentos base64url começando em `eyJ`.
  static final RegExp _jwt =
      RegExp(r'eyJ[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]*');

  // Chave de API do Google (a do `FirebaseOptions` tem exatamente esta forma).
  static final RegExp _chaveGoogle = RegExp(r'AIza[0-9A-Za-z_\-]{20,}');

  // OAuth client id (`...apps.googleusercontent.com`).
  static final RegExp _clientId =
      RegExp(r'[0-9]{6,}-[0-9a-z]{10,}\.apps\.googleusercontent\.com');

  static final RegExp _email =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

  static final RegExp _bearer =
      RegExp(r'(?:[Bb]earer|[Bb]asic)\s+[A-Za-z0-9._\-=/+]{8,}');

  // `chave: valor` / `chave=valor` / `"chave" : "valor"` em texto livre.
  //
  // A primeira alternativa do valor é a PRÓPRIA marca de redação. Sem ela, um
  // valor já redigido por uma regra anterior seria remordido aqui (o `]` final
  // ficaria de fora do casamento e sobraria no texto), e a redação deixaria de
  // ser idempotente — cada passada acrescentaria um `]`.
  static final RegExp _paresNomeados = RegExp(
    r'''(["']?)([A-Za-z_][A-Za-z0-9_\-]{1,40})\1\s*[:=]\s*(?:''' +
        RegExp.escape(marcaRedacao) +
        r'''|(["'])(?:\\.|(?!\3)[^\\])*\3|[^\s,;)}\]]+)''',
  );

  // Blob opaco: candidato a token ou UID solto, sem chave por perto.
  // 24 é o piso: um UID do Firebase tem 28 e um purchaseToken passa de 100.
  static final RegExp _blobOpaco = RegExp(r'[A-Za-z0-9_\-]{24,}');

  // Cartão / documento longo em dígitos puros.
  static final RegExp _digitosLongos = RegExp(r'\b\d{13,19}\b');

  // Carta privada do baralho: `copas_A`, `ouros:K`, `espadas 10`, `JOKER`.
  static final RegExp _carta = RegExp(
    r'\b(?:copas|ouros|paus|espadas)\s*[_: ]\s*(?:[AJQK]|10|[2-9])\b|\bJOKER\b',
    caseSensitive: false,
  );

  /// Hex puro é hash/SHA de build — é justamente o que precisamos ler, então
  /// sobrevive ao filtro de blob opaco. Um UID do Firebase é alfanumérico
  /// misto e não passa por aqui.
  static final RegExp _hexPuro = RegExp(r'^[0-9a-fA-F]+$');

  /// Padrões que valem em QUALQUER texto, inclusive stack trace e manifesto
  /// de build: só o que é segredo pela FORMA, sem a rede larga de blob opaco.
  ///
  /// Público porque o gate de release usa isto como auto-teste — se o
  /// manifesto muda ao passar por aqui, é porque tem segredo dentro dele.
  String formasInequivocas(String entrada) => _inequivocos(entrada);

  String _inequivocos(String entrada) {
    var s = entrada;
    s = s.replaceAll(_jwt, marcaRedacao);
    s = s.replaceAll(_chaveGoogle, marcaRedacao);
    s = s.replaceAll(_clientId, marcaRedacao);
    s = s.replaceAll(_bearer, marcaRedacao);
    s = s.replaceAll(_email, marcaRedacao);
    s = s.replaceAll(_carta, marcaRedacao);
    s = s.replaceAll(_digitosLongos, marcaRedacao);
    return s;
  }

  /// Limpa texto livre — mensagem de erro, `toString()` de exceção, valor de
  /// contexto. Aplica as duas defesas por inteiro.
  ///
  /// Idempotente: aplicar duas vezes dá o mesmo resultado.
  String texto(String? entrada) {
    if (entrada == null || entrada.isEmpty) return '';
    var s = _inequivocos(entrada);

    // `chave: valor` — pega o que só é segredo pelo nome do campo.
    s = s.replaceAllMapped(_paresNomeados, (m) {
      final aspaChave = m.group(1) ?? '';
      final chave = m.group(2) ?? '';
      if (!chaveEhProibida(chave)) return m.group(0)!;
      return '$aspaChave$chave$aspaChave: $marcaRedacao';
    });

    // Por último a varredura de blobs, que é a rede mais larga.
    s = s.replaceAllMapped(_blobOpaco, (m) {
      final v = m.group(0)!;
      return _hexPuro.hasMatch(v) ? v : marcaRedacao;
    });

    return s;
  }

  /// Limpa um stack trace. Só os padrões inequívocos: nomes de símbolo, de
  /// arquivo e de pacote precisam sobreviver para o stack ainda servir.
  String stack(Object? entrada) {
    if (entrada == null) return '';
    final s = '$entrada';
    if (s.isEmpty) return '';
    return _inequivocos(s);
  }

  /// `true` se o valor desta chave nunca pode sair.
  bool chaveEhProibida(String chave) {
    final c = chave.toLowerCase();
    for (final proibida in chavesProibidas) {
      if (c.contains(proibida)) return true;
    }
    return false;
  }

  /// Limpa um mapa de contexto.
  ///
  /// Chave proibida perde o valor mas MANTÉM a linha: saber que havia um
  /// `uid` no contexto é diagnóstico legítimo; saber qual, não.
  Map<String, String> contexto(Map<String, Object?>? entrada) {
    if (entrada == null || entrada.isEmpty) return const <String, String>{};
    final saida = <String, String>{};
    for (final e in entrada.entries) {
      final chave = texto(e.key);
      saida[chave] = chaveEhProibida(e.key) ? marcaRedacao : texto('${e.value}');
    }
    return saida;
  }

  /// Desenrola a cadeia de causas de uma exceção, redigindo cada elo.
  ///
  /// Exceção aninhada é o caminho clássico de vazamento: a mensagem de fora é
  /// inócua e o token está três `cause` abaixo. Aqui cada elo é redigido.
  List<String> cadeiaDeCausas(Object? erro, {int limite = 5}) {
    final elos = <String>[];
    Object? atual = erro;
    final vistos = <Object>{};
    var passos = 0;
    while (atual != null && passos < limite) {
      if (!vistos.add(atual)) break; // ciclo de causas
      elos.add(texto('$atual'));
      atual = _causaDe(atual);
      passos++;
    }
    return elos;
  }

  /// Tenta achar a causa de um erro sem conhecer o tipo concreto.
  ///
  /// `dynamic` é intencional: as bibliotecas não compartilham uma interface de
  /// causa, e um `NoSuchMethodError` aqui só significa "este erro não tem
  /// campo de causa" — o que é o caso normal, não um problema.
  static Object? _causaDe(Object erro) {
    for (final ler in <Object? Function(dynamic)>[
      (dynamic d) => d.causa,
      (dynamic d) => d.cause,
    ]) {
      try {
        final c = ler(erro);
        if (c != null && !identical(c, erro)) return c;
      } catch (_) {
        // Sem esse campo neste tipo — tenta o próximo nome.
      }
    }
    return null;
  }
}
