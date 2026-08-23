// OS 43.1 — LEITOR DA FONTE ÚNICA DOS PORTÕES DO BOT.
//
// O formato tem exatamente dois níveis, e a diferença entre eles é a MARGEM:
//
//   NOME-DO-PORTAO          <- ENTRADA  (coluna 0)
//     chave: valor          <- ATRIBUTO (indentado)
//
// A distinção não é decorativa. Um leitor que trata atributo como entrada
// transforma `suite:`, `sha256:` e `exige:` em portões inexistentes e reprova
// um repositório íntegro — foi assim que uma trava anterior desta família
// deixou de distinguir os estados que existia para distinguir. Aqui a margem
// é a única coisa que decide, e as duas violações (atributo na margem,
// entrada indentada) são ERRO explícito, não interpretação silenciosa.
//
// FAIL-CLOSED: qualquer desvio — chave desconhecida, chave repetida, chave
// obrigatória ausente, atributo órfão, arquivo vazio — levanta `FormatException`.
// Nenhum caminho deste arquivo devolve "vazio, então tudo bem".
library;

/// Chaves OBRIGATÓRIAS de toda entrada. Lista fechada: chave fora dela é erro.
const Set<String> chavesObrigatorias = <String>{
  'suite',
  'executor',
  'sha256',
  'provas',
  'casos',
  'exige',
};

/// Uma entrada da fonte única.
class EntradaPortao {
  final String nome;
  final String suite;
  final String executor;
  final String sha256;
  final int provas;
  final List<String> casos;
  final Map<String, int> exige;

  const EntradaPortao({
    required this.nome,
    required this.suite,
    required this.executor,
    required this.sha256,
    required this.provas,
    required this.casos,
    required this.exige,
  });

  /// Caminho da suíte a partir da RAIZ DO PACOTE DE TESTE (`app_build`), que é
  /// onde `flutter test` roda. A fonte única declara o caminho do REPOSITÓRIO
  /// (`app/test/...`) porque é lá que ele tem identidade; o CI copia
  /// `app/test/` para `app_build/test/`, e é essa a tradução — literal, e não
  /// um "acha o arquivo em algum lugar".
  String get suiteNoPacote {
    const prefixo = 'app/';
    if (!suite.startsWith(prefixo)) {
      throw FormatException(
          'suite deve ser declarada a partir da raiz do repositório '
          '(esperado começar com "$prefixo"): "$suite"');
    }
    return suite.substring(prefixo.length);
  }
}

/// Lê a fonte única. `texto` é o conteúdo integral do arquivo.
List<EntradaPortao> lerFonteUnica(String texto) {
  final linhas = texto.replaceAll('\r\n', '\n').split('\n');
  final brutas = <String, Map<String, String>>{};
  final ordem = <String>[];
  String? atual;

  for (var i = 0; i < linhas.length; i++) {
    final linha = linhas[i];
    final numero = i + 1;
    if (linha.trim().isEmpty) continue;
    if (linha.trimLeft().startsWith('#')) continue;

    final indentada = linha.startsWith(' ') || linha.startsWith('\t');
    final pareceAtributo = RegExp(r'^\s*[a-z0-9_]+\s*:').hasMatch(linha);

    if (!indentada) {
      // MARGEM: só pode ser nome de entrada. Se parece atributo, é erro.
      if (pareceAtributo) {
        throw FormatException(
            'linha $numero: atributo na MARGEM — atributo tem de ser '
            'indentado, senão vira portão fantasma: "$linha"');
      }
      final nome = linha.trim();
      if (!RegExp(r'^[A-Z0-9][A-Z0-9-]*$').hasMatch(nome)) {
        throw FormatException(
            'linha $numero: nome de entrada inválido: "$nome"');
      }
      if (brutas.containsKey(nome)) {
        throw FormatException('linha $numero: entrada repetida: "$nome"');
      }
      brutas[nome] = <String, String>{};
      ordem.add(nome);
      atual = nome;
      continue;
    }

    // INDENTADA: só pode ser atributo de uma entrada já aberta.
    if (atual == null) {
      throw FormatException(
          'linha $numero: atributo órfão, sem entrada acima: "$linha"');
    }
    if (!pareceAtributo) {
      throw FormatException(
          'linha $numero: linha indentada que não é atributo '
          '"chave: valor": "$linha"');
    }
    final corte = linha.indexOf(':');
    final chave = linha.substring(0, corte).trim();
    final valor = linha.substring(corte + 1).trim();
    if (!chavesObrigatorias.contains(chave)) {
      throw FormatException(
          'linha $numero: chave desconhecida "$chave" — a lista é fechada '
          '(${chavesObrigatorias.join(', ')})');
    }
    if (brutas[atual]!.containsKey(chave)) {
      throw FormatException(
          'linha $numero: chave repetida "$chave" em "$atual"');
    }
    if (valor.isEmpty) {
      throw FormatException('linha $numero: chave "$chave" sem valor');
    }
    brutas[atual]![chave] = valor;
  }

  if (ordem.isEmpty) {
    throw const FormatException(
        'fonte única SEM nenhuma entrada — uma varredura que passa com a '
        'árvore vazia não é portão');
  }

  final saida = <EntradaPortao>[];
  for (final nome in ordem) {
    final m = brutas[nome]!;
    final faltando = chavesObrigatorias.difference(m.keys.toSet());
    if (faltando.isNotEmpty) {
      throw FormatException(
          'entrada "$nome" sem as chaves obrigatórias: '
          '${(faltando.toList()..sort()).join(', ')}');
    }
    final sha = m['sha256']!;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw FormatException(
          'entrada "$nome": sha256 não é um digest de 64 hex minúsculos');
    }
    final provas = int.tryParse(m['provas']!);
    if (provas == null || provas <= 0) {
      throw FormatException('entrada "$nome": provas inválido');
    }
    final casos = m['casos']!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (casos.length != provas) {
      throw FormatException(
          'entrada "$nome": provas=$provas mas a lista tem ${casos.length} '
          'casos — o número e a lista não podem discordar');
    }
    if (casos.toSet().length != casos.length) {
      throw FormatException('entrada "$nome": caso repetido em "casos"');
    }
    final exige = <String, int>{};
    for (final par in m['exige']!.split(',')) {
      final t = par.trim();
      if (t.isEmpty) continue;
      final mm = RegExp(r'^([A-Z_]+)>=(-?\d+)$').firstMatch(t);
      if (mm == null) {
        throw FormatException(
            'entrada "$nome": exigência mal formada "$t" '
            '(esperado CHAVE>=numero)');
      }
      if (exige.containsKey(mm.group(1))) {
        throw FormatException(
            'entrada "$nome": exigência repetida "${mm.group(1)}"');
      }
      exige[mm.group(1)!] = int.parse(mm.group(2)!);
    }
    if (exige.isEmpty) {
      throw FormatException('entrada "$nome": "exige" sem nenhuma exigência');
    }
    saida.add(EntradaPortao(
      nome: nome,
      suite: m['suite']!,
      executor: m['executor']!,
      sha256: sha,
      provas: provas,
      casos: casos,
      exige: exige,
    ));
  }
  return saida;
}
