// ancora_provas_visuais_test.dart — a ÂNCORA EXTERNA das provas visuais da
// carta obrigatória do lixo.
//
// POR QUE ESTE ARQUIVO EXISTE.
//
// A OS 29-C4 pôs a guarda do desenho da carta obrigatória FORA do arquivo que
// ela guarda, e a OS 29-C5 deu à metade recíproca a mesma força que ela cobra.
// O par ficou simétrico e forte, e mesmo assim a própria C5 registrou o que
// sobra — o residual C10:
//
//   esvaziar as DUAS metades no mesmo commit e realinhar o digest que sobra
//   sai VERDE, com o placar da árvore íntegra (`cascaaud +28`, `mesac1 +31`).
//
// E não é defeito de nenhuma das duas: uma guarda MÚTUA de dois nós não tem
// âncora fora de si. Tudo o que um cobra do outro está escrito num dos dois, e
// um gesto que toca os dois ao mesmo tempo é, para o par, indistinguível de uma
// mudança legítima.
//
// Este arquivo é o terceiro nó. Ele NÃO pergunta nada aos dois arquivos sobre
// si mesmos: as listas de casos, as declarações exigidas, as agulhas, os pisos
// e os digests do CÓDIGO das duas metades estão declarados AQUI, em cópia
// própria. Realinhar os dois digests um no outro não o alcança, porque ele
// carrega um terceiro par de digests que o gesto coordenado não sabe que
// existe — e, se souber, já é um gesto de TRÊS arquivos, declarado em três
// lugares de naturezas diferentes.
//
// E ele não se contenta com a árvore. Cinco dos casos abaixo leem a EVIDÊNCIA
// do executor verdadeiro: o carimbo que o alvo oficial escreve antes de rodar,
// os marcadores de saída e os logs `--reporter expanded` das duas suítes. Um
// marcador fabricado sem log, um log anterior ao carimbo, um placar abaixo do
// piso ou um caso protegido que não aparece na chamada nominal reprovam aqui.
//
// FAIL-CLOSED, E DE PROPÓSITO. Os grupos irmãos deste diretório escrevem
// `if (!workflow.existsSync()) return;` — e está certo para eles, que nasceram
// para sobreviver a recortes antigos da árvore. Esta âncora não: ela existe
// para ser a coisa que não se pode desligar em silêncio. Se o alvo oficial não
// estiver alcançável a partir de onde ela roda, ela REPROVA, porque "não
// consegui olhar" e "olhei e está certo" não podem sair iguais.
//
// ONDE ELA É EXECUTADA. Nos dois portões, e de propósito:
//
//   * `.github/workflows/ci-os-integracao.yml`, pela chave `ancoravis`, que
//     entra por `exige` e está nas TRÊS listas do veredito — de modo que o
//     passo que não roda também reprova;
//   * `.github/workflows/build.yml`, que roda `flutter test test/casca
//     test/cartas` no diretório inteiro. Esse comando é afirmado, letra por
//     letra, por `auditoria_casca_test.dart`, que é um dos dois arquivos
//     protegidos e não pode ser tocado sem derrubar o par.
//
// É essa segunda porta que fecha o buraco de apagar a ENTRADA: quem tirar
// `ancoravis` das listas do alvo oficial continua rodando esta âncora pelo
// portão do APK, e ela reprova nominalmente por causa da entrada que sumiu.

@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// OS ENDEREÇOS
// ===========================================================================

/// A guarda externa do desenho da obrigação (o gate `cascaaud`).
const String kCaminhoDaGuarda = 'test/casca/auditoria_casca_test.dart';

/// A suíte protegida, que prova o desenho na mesa montada (o gate `mesac1`).
const String kCaminhoDaSuiteProtegida =
    'test/casca/mesa_treino_alvos_reais_test.dart';

/// Esta âncora, como os dois workflows a nomeiam.
const String kCaminhoDestaAncora = 'test/casca/ancora_provas_visuais_test.dart';

/// A chave do gate desta âncora no alvo oficial.
const String kChaveDoGate = 'ancoravis';

/// As chaves dos dois gates cujas provas esta âncora torna obrigatórias.
const String kChaveDaGuarda = 'cascaaud';
const String kChaveDaSuiteProtegida = 'mesac1';

/// O alvo oficial e o portão que produz o APK, a partir de `app/`.
const String kAlvoOficial = '../.github/workflows/ci-os-integracao.yml';
const String kPortaoDoApk = '../.github/workflows/build.yml';

/// O comando que o portão do APK roda, e que `auditoria_casca_test.dart`
/// afirma letra por letra. É a porta que sobrevive ao apagamento da entrada.
const String kComandoDoPortaoDoApk = 'flutter test test/casca test/cartas';

/// O contrato desta autoridade, a partir da raiz — o SEGUNDO dono do digest
/// desta âncora, e onde a campanha que cobra o residual C10 está registrada.
const String kCaminhoDoContrato =
    'docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md';

// ===========================================================================
// A EVIDÊNCIA DO EXECUTOR VERDADEIRO
// ===========================================================================
//
// O alvo oficial roda as suítes a partir de `app_build/`, e escreve carimbo,
// marcadores e logs na raiz do workspace — um nível acima. Esta bancada tem a
// mesma forma: `app/` embaixo, a raiz em cima.

/// O carimbo que o alvo oficial escreve ANTES de rodar as suítes.
const String kCarimbo = '../carimbo_ancoravis';

/// O marcador de saída e o log de cada uma das duas suítes protegidas.
const String kMarcadorDaGuarda = '../exit_cascaaud';
const String kLogDaGuarda = '../t_cascaaud.log';
const String kMarcadorDaSuiteProtegida = '../exit_mesac1';
const String kLogDaSuiteProtegida = '../t_mesac1.log';

/// A linha com que o `--reporter expanded` fecha uma execução inteira.
const String kFechoDoPlacar = 'All tests passed!';

// ===========================================================================
// O QUE AS DUAS METADES SÃO — EM CÓPIA PRÓPRIA
// ===========================================================================

/// Os marcadores da metade que mora na guarda externa.
const String kInicioDaGuarda =
    '// >>> GUARDA EXTERNA DA SUITE DO DESENHO - INICIO';
const String kFimDaGuarda = '// <<< GUARDA EXTERNA DA SUITE DO DESENHO - FIM';

/// Os marcadores da metade recíproca, que mora na suíte protegida.
const String kInicioDaReciprocidade = '// >>> RECIPROCIDADE DA GUARDA - INICIO';
const String kFimDaReciprocidade = '// <<< RECIPROCIDADE DA GUARDA - FIM';

/// Os casos da metade que guarda, na ordem em que ela os declara.
const List<String> kCasosDaGuarda = <String>[
  'a suíte protegida está no caminho declarado e bate com o digest',
  'os casos da suíte protegida são exatamente estes',
  'cada trecho protegido continua AFIRMANDO o que promete',
  'a suíte exercita 320, 360 e 412 e protege o piso de 48',
  'a suíte protegida guarda esta auditoria de volta',
];

/// Os casos da suíte protegida, na ordem em que ela os declara.
///
/// Esta é a cópia da ÂNCORA. A guarda externa tem a dela, e a coincidência
/// entre as duas é o que um gesto de dois arquivos não consegue produzir.
const List<String> kCasosDaSuiteProtegida = <String>[
  'numa tela larga as onze cartas cabem numa fileira',
  'em 360 pontos a mão usa duas fileiras',
  'a mesa não estoura em nenhuma largura nomeada, nem no quadrado',
  'com a fonte do sistema em 200% o piso continua de pé',
  'o piso vale nas três larguras nomeadas: 320, 360 e 412',
  'vale em 400 pontos',
  'o toque em cada carta acerta a carta, e não a vizinha',
  'o piso exigido é 48, e o número é conferido e não só usado',
  'a leitura é 1…11, com as duas fileiras',
  'a leitura é a mesma em uma e em duas fileiras',
  'selecionar na fileira de cima não mexe na de baixo',
  'a reorganização da compra não quebra ordem nem piso',
  'é anunciada, e só numa carta',
  'acompanha a INSTÂNCIA, e não o valor e o naipe',
  'sobrevive à seleção, à desmarcação e ao rebuild',
  'sobrevive à mudança de fileira',
  'a compra comum do monte NÃO vira obrigação',
  'o destaque vermelho dura o que a obrigação durar',
  'sem obrigação viva, carta nenhuma fica com o destaque',
  'enquanto a pendência vive, nenhum descarte é aceito',
  'a baixada com o topo encerra a pendência antes de a vez virar',
  'cada um tem 48 × 48 de região acionável',
  'os discos continuam onde a mesa original os desenhou',
  'os cinco pontos de cada alvo respondem, e só ao dono',
  'os três alvos não se sobrepõem nem pegam o vizinho',
  'a mão desabilitada não oferece ação',
  'nó tocável nenhum fica sem nome',
  'o jogo baixado diz de quem é, quantas cartas e o que faz',
  'cada jogador é UM nó, e o avatar não vira o segundo',
  'os três atributos continuam escritos à mão',
  'a guarda externa desta suíte existe, e é ela que a protege',
];

/// Os casos das duas metades, que a chamada nominal do log tem de conter.
const List<String> kCasosDoDesenhoDaObrigacao = <String>[
  'é anunciada, e só numa carta',
  'acompanha a INSTÂNCIA, e não o valor e o naipe',
  'sobrevive à seleção, à desmarcação e ao rebuild',
  'sobrevive à mudança de fileira',
  'a compra comum do monte NÃO vira obrigação',
  'o destaque vermelho dura o que a obrigação durar',
  'sem obrigação viva, carta nenhuma fica com o destaque',
];

/// Sem estas declarações, a metade que guarda não confere coisa nenhuma —
/// ainda que conserve os cinco nomes de caso e os marcadores.
const List<String> kDeclaracoesDaGuarda = <String>[
  'const casosEsperados = <String>[',
  'const afirmacoes = <String, Map<String, int>>{',
  'const chamadas = <String, Map<String, int>>{',
  'const pisoDeAfirmacoes = <String, int>{',
  'const afirmacoesDaReciprocidade = <String, int>{',
  'const pisoDaReciprocidade = ',
  "const kTrechoDaReciprocidade = 'RECIPROCIDADE DA GUARDA';",
  'List<String> afirmacoesDe(String corpo)',
  'bool afirmacaoTrivial(String afirmacao)',
  'List<String> posicionais(String argumentos)',
  'List<String> argumentosDeExpect(String corpo)',
  'String semComentarios(String fonte)',
  'String semTextoDeString(String fonte)',
  'String trecho(String texto, String nome)',
  'String digestDe(String t)',
  'List<String> casosDe(String texto)',
  'orderedEquals(casosEsperados)',
];

/// O mesmo, do lado recíproco.
const List<String> kDeclaracoesDaReciprocidade = <String>[
  'final externa = File(kCaminhoDaGuardaExterna);',
  'blocoDaGuardaExterna(externa.readAsStringSync())',
  'orderedEquals(kCasosDaGuardaExterna)',
  'for (final d in kDeclaracoesDaGuardaExterna)',
  'naoTriviaisDaGuardaExterna(bloco)',
  'kAfirmacoesDaGuardaExterna.entries',
  'kPisoDaGuardaExterna',
  'kDigestDaGuardaExterna',
  'contains(kCaminhoDestaSuite)',
];

/// As declarações de topo da suíte protegida que sustentam a metade recíproca.
///
/// Elas moram FORA do bloco delimitado, e por isso precisam de conferência
/// própria: apagá-las não muda o digest do bloco.
const List<String> kDeclaracoesDeTopoDaSuiteProtegida = <String>[
  "const String kCaminhoDaGuardaExterna = 'test/casca/auditoria_casca_test.dart';",
  'const String kCaminhoDestaSuite =',
  'const String kDigestDaGuardaExterna = ',
  'const List<String> kCasosDaGuardaExterna = <String>[',
  'const List<String> kDeclaracoesDaGuardaExterna = <String>[',
  'const Map<String, int> kAfirmacoesDaGuardaExterna = <String, int>{',
  'const int kPisoDaGuardaExterna = ',
  'String blocoDaGuardaExterna(String texto) {',
  'String digestNormalizado(String trecho) =>',
];

/// O que a metade que guarda tem de continuar AFIRMANDO, dentro do PRIMEIRO
/// argumento posicional de um `expect`, e quantas vezes.
const Map<String, int> kAfirmacoesDaGuarda = <String, int>{
  'digestDe(texto)': 1,
  'linhas': 1,
  'casos': 2,
  'naoTriviais.length': 2,
  'quantas': 3,
  'guardaDoPiso': 1,
  'larguras': 1,
  'pisoDeAfirmacoes.containsKey(': 1,
  'afirmacoes.containsKey(': 1,
};

/// O mesmo, do lado recíproco.
const Map<String, int> kAfirmacoesDaReciprocidade = <String, int>{
  'externa.existsSync()': 1,
  'digestNormalizado(bloco)': 1,
  'casos': 2,
  'bloco': 3,
  'naoTriviais.length': 1,
  'quantas': 1,
};

/// Os pisos de afirmações NÃO TRIVIAIS de cada metade.
///
/// Grosseiros de propósito: não julgam qualidade, só impedem que a metade vire
/// casca depois que alguém realinhar os dois digests um no outro.
const int kPisoDaGuarda = 16;
const int kPisoDaReciprocidade = 8;

/// O digest do CÓDIGO de cada metade — sem comentário, sem a linha marcada
/// `[digest-movel]`, e sem espaço à direita.
///
/// É AQUI que o residual C10 morre. Os dois arquivos carregam o digest um do
/// outro, e um commit que esvazia os dois realinha os dois. Estes dois números
/// moram num terceiro arquivo, que o gesto coordenado não toca.
const String kDigestDoCodigoDaGuarda =
    '02135122f2f25894900c0347b37e2472752fb4f46afbc951a00e3d7c4b0d0aee';
const String kDigestDoCodigoDaReciprocidade =
    '3ddec94a74fed5cc9b29b220d52c9b619949dde6db217a16d37073370b11607b';

/// O placar mínimo de cada suíte protegida no log do executor verdadeiro.
const int kPisoDoPlacarDaGuarda = 28;
const int kPisoDoPlacarDaSuiteProtegida = 31;

/// Quantos casos esta âncora tem.
///
/// O alvo oficial declara o mesmo número em `ANCORA_PISO` e confere o placar
/// REAL desta suíte contra ele. Baixar o piso lá reprova aqui; esvaziar esta
/// âncora derruba o placar lá. Nenhum dos dois gestos se basta.
const int kCasosDestaAncora = 16;

// ===========================================================================
// OS VARREDORES
// ===========================================================================
//
// São os mesmos das duas metades, e estão duplicados de propósito. Importar os
// de lá faria a conferência depender do conferido: quem trivializasse as duas
// metades trivializaria junto o instrumento que as mede. A independência é o
// que faz o terceiro nó ser um terceiro nó.

/// Verdadeiro se a aspa em [k] abre uma string CRUA (`r'...'`).
///
/// `r'\'` é uma string crua de UM caractere. Um varredor que trate a barra como
/// escape consome a aspa de fechamento, perde o sincronismo e passa a ler o
/// resto do arquivo como texto — e daí em diante não enxerga `expect` nenhum.
bool aspaCrua(String fonte, int k) =>
    k > 0 &&
    fonte[k - 1] == 'r' &&
    (k == 1 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(fonte[k - 2]));

/// O texto sem comentário, respeitando aspas.
String semComentarios(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  var crua = false;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\' && !crua) {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(fonte, i);
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// O mesmo texto com o CONTEÚDO das strings esvaziado, aspas preservadas.
///
/// Escrever `temBordaDaObrigacao(` dentro de uma string é citar o nome, não
/// afirmar com ele.
String semTextoDeString(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  var crua = false;
  while (i < fonte.length) {
    final c = fonte[i];
    if (aspa != null) {
      if (c == r'\' && !crua) {
        i += 2;
        continue;
      }
      if (c == aspa) {
        aspa = null;
        saida.write(c);
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(fonte, i);
      saida.write(c);
      i++;
      continue;
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// Os argumentos de cada `expect(...)`, com parênteses balanceados e aspas
/// respeitadas.
List<String> argumentosDeExpect(String corpo) {
  const chamada = 'expect(';
  final colado = RegExp(r'[A-Za-z0-9_$.]');
  final saida = <String>[];
  var i = 0;
  while (true) {
    final k = corpo.indexOf(chamada, i);
    if (k < 0) break;
    if (k > 0 && colado.hasMatch(corpo[k - 1])) {
      i = k + chamada.length;
      continue;
    }
    var p = k + chamada.length;
    var nivel = 1;
    String? aspa;
    var crua = false;
    while (p < corpo.length && nivel > 0) {
      final c = corpo[p];
      if (aspa != null) {
        if (c == r'\' && !crua) {
          p += 2;
          continue;
        }
        if (c == aspa) aspa = null;
      } else if (c == "'" || c == '"') {
        aspa = c;
        crua = aspaCrua(corpo, p);
      } else if (c == '(') {
        nivel++;
      } else if (c == ')') {
        nivel--;
      }
      p++;
    }
    saida.add(corpo.substring(k + chamada.length, p - 1));
    i = p;
  }
  return saida;
}

/// Os argumentos POSICIONAIS de um `expect`, separados na vírgula de nível
/// zero. Tudo a partir do primeiro nomeado fica de fora — `reason:` é prosa de
/// reprovação, e citar a agulha nela não é afirmar com ela.
List<String> posicionais(String argumentos) {
  final saida = <String>[];
  var inicio = 0;
  var nivel = 0;
  String? aspa;
  var crua = false;
  for (var p = 0; p < argumentos.length; p++) {
    final c = argumentos[p];
    if (aspa != null) {
      if (c == r'\' && !crua) {
        p++;
        continue;
      }
      if (c == aspa) aspa = null;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(argumentos, p);
      continue;
    }
    if (c == '(' || c == '[' || c == '{') nivel++;
    if (c == ')' || c == ']' || c == '}') nivel--;
    if (c == ',' && nivel == 0) {
      saida.add(argumentos.substring(inicio, p));
      inicio = p + 1;
    }
  }
  saida.add(argumentos.substring(inicio));
  final nomeado = RegExp(r'^\s*[A-Za-z_][A-Za-z0-9_]*\s*:');
  final fim = saida.indexWhere(nomeado.hasMatch);
  return fim < 0 ? saida : saida.sublist(0, fim);
}

/// Verdadeiro se a afirmação não olha para programa nenhum: literal, string,
/// vazio, ou uma tautologia que passa em qualquer árvore.
bool afirmacaoTrivial(String afirmacao) {
  final a = afirmacao.trim();
  if (a.isEmpty) return true;
  if (RegExp(r"^'[^']*'$").hasMatch(a)) return true;
  if (RegExp(r'^"[^"]*"$').hasMatch(a)) return true;
  if (RegExp(r'^-?[0-9]+(\.[0-9]+)?$').hasMatch(a)) return true;
  if (a == 'true' || a == 'false' || a == 'null') return true;
  if (RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*!\1$').hasMatch(a)) {
    return true;
  }
  if (RegExp(r'^!([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*\1$').hasMatch(a)) {
    return true;
  }
  return false;
}

/// O PRIMEIRO argumento posicional de cada `expect` do trecho, já sem
/// comentário e com o conteúdo das strings esvaziado.
List<String> afirmacoesDe(String corpo) => argumentosDeExpect(
      semTextoDeString(semComentarios(corpo)),
    ).map((a) => posicionais(a).isEmpty ? '' : posicionais(a).first).toList();

/// As afirmações do trecho que olham para o programa.
List<String> naoTriviaisDe(String corpo) =>
    afirmacoesDe(corpo).where((x) => !afirmacaoTrivial(x)).toList();

/// Os nomes dos casos declarados no texto, na ordem.
List<String> casosDe(String texto) => RegExp(
      "^\\s*(?:testWidgets|test)\\(\\s*'((?:[^'\\\\]|\\\\.)*)'",
      multiLine: true,
    )
        .allMatches(semLinhaDeComentario(texto))
        .map((m) => m.group(1)!)
        .toList();

/// O texto sem as linhas que COMEÇAM com `//`.
String semLinhaDeComentario(String texto) => <String>[
      for (final l in normalizado(texto).split('\n'))
        if (!l.trimLeft().startsWith('//')) l,
    ].join('\n');

/// O mesmo texto com fim de linha de máquina normalizado.
///
/// Esta árvore é versionada com `autocrlf`: o MESMO arquivo tem CRLF na máquina
/// e LF no CI. Um digest cru diria que ele mudou toda vez que viaja.
String normalizado(String t) =>
    t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// O digest de um trecho, normalizado.
String digestDe(String t) =>
    sha256.convert(utf8.encode(normalizado(t))).toString();

// ===========================================================================
// LER OS ARQUIVOS
// ===========================================================================

/// O conteúdo de [caminho], ou uma reprovação nominal se ele não estiver lá.
String leitura(String caminho, String porque) {
  final f = File(caminho);
  expect(
    f.existsSync(),
    isTrue,
    reason: 'ausente: $caminho — $porque. Esta âncora é fail-closed: não '
        'conseguir olhar e olhar e estar certo não podem sair iguais',
  );
  return normalizado(f.readAsStringSync());
}

/// O CÓDIGO de um bloco delimitado: as linhas entre os marcadores, sem
/// comentário, sem a linha móvel do digest, sem espaço à direita.
String codigoDoBloco(String texto, String inicio, String fim, String onde) {
  final linhas = normalizado(texto).split('\n');
  final a = linhas.indexWhere((l) => l.trim() == inicio);
  final b = linhas.indexWhere((l) => l.trim() == fim);
  expect(
    a,
    greaterThanOrEqualTo(0),
    reason: 'o marcador de início de "$onde" sumiu — sem ele o bloco não tem '
        'fronteira, e o que se mede deixa de ser o que se declara',
  );
  expect(
    b,
    greaterThan(a),
    reason: 'o marcador de fim de "$onde" sumiu ou trocou de lugar com o de '
        'início',
  );
  return <String>[
    for (final l in linhas.sublist(a + 1, b))
      if (!l.trimLeft().startsWith('//') && !l.contains('[digest-movel]'))
        l.trimRight(),
  ].join('\n');
}

/// Toda declaração de shell `NOME="a b c"` do workflow, quebrada em chaves.
List<List<String>> declaracoesDe(String texto, String nome) =>
    RegExp('^ *' + nome + '="([^"]*)"', multiLine: true)
        .allMatches(texto)
        .map((m) => m
            .group(1)!
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList())
        .toList();

/// O valor de uma atribuição de shell SEM aspas, `NOME=valor`, VIVA — a linha
/// não pode começar por `#`.
String? atribuicaoViva(String texto, String nome) {
  final m = RegExp('^ *' + nome + r'=([^\s#]+)[ \t]*$', multiLine: true)
      .firstMatch(texto);
  return m?.group(1);
}

/// Verdadeiro se o workflow tem a linha [linha] VIVA — sem `#` na frente.
bool linhaViva(String texto, String linha) => RegExp(
      '^ *' + RegExp.escape(linha) + r'[ \t]*$',
      multiLine: true,
    ).hasMatch(texto);

/// O placar com que o `--reporter expanded` fechou o log: o `+N` da linha de
/// fecho. Devolve `-1` se o log não fechou verde.
int placarDo(String log) {
  final m = RegExp(r'\+([0-9]+):[^\n]*' + RegExp.escape(kFechoDoPlacar))
      .allMatches(log)
      .toList();
  if (m.isEmpty) return -1;
  return int.parse(m.last.group(1)!);
}

void main() {
  // =========================================================================
  // 1 — OS DOIS ARQUIVOS PROTEGIDOS
  // =========================================================================

  test('os dois arquivos protegidos estão no caminho declarado', () {
    for (final c in <String>[kCaminhoDaGuarda, kCaminhoDaSuiteProtegida]) {
      expect(
        File(c).existsSync(),
        isTrue,
        reason: 'o arquivo protegido $c sumiu da árvore — e some em silêncio '
            'no alvo oficial, porque ausência de arquivo vira NÃO EXECUTADO',
      );
    }
    // Um digest bate com um arquivo vazio tão bem quanto com o certo. O tamanho
    // é a segunda pergunta, e ela não depende de digest nenhum.
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda o desenho');
    final protegida =
        leitura(kCaminhoDaSuiteProtegida, 'é a suíte do desenho na mesa');
    expect(
      guarda.split('\n').length,
      greaterThan(1000),
      reason: 'a guarda externa encolheu para ${guarda.split('\n').length} '
          'linhas',
    );
    expect(
      protegida.split('\n').length,
      greaterThan(2000),
      reason: 'a suíte protegida encolheu para '
          '${protegida.split('\n').length} linhas',
    );
  });

  // =========================================================================
  // 2 — O ALVO OFICIAL EXECUTA AS DUAS
  // =========================================================================

  test('o alvo oficial executa as duas suítes protegidas, pelo caminho certo',
      () {
    final texto = leitura(
      kAlvoOficial,
      'é a autoridade canônica de gates, e sem ela nada aqui é obrigatório',
    );
    expect(
      linhaViva(texto, 'roda $kChaveDaGuarda   $kCaminhoDaGuarda'),
      isTrue,
      reason: 'o gate $kChaveDaGuarda deixou de executar $kCaminhoDaGuarda — '
          'foi apontado para outro caminho, comentado, ou saiu do alvo',
    );
    expect(
      RegExp(
        '^ *exige +' +
            kChaveDaSuiteProtegida +
            ' +' +
            RegExp.escape(kCaminhoDaSuiteProtegida) +
            r'[ \t]*$',
        multiLine: true,
      ).hasMatch(texto),
      isTrue,
      reason: 'o gate $kChaveDaSuiteProtegida não exige '
          '$kCaminhoDaSuiteProtegida — foi rebaixado para roda, desviado para '
          'uma isca, ou saiu do alvo',
    );
    // Executar sem estar nas listas é rodar sem poder reprovar.
    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(
      RegExp(r'for +k +in +\$LISTA *; *do').hasMatch(texto),
      isTrue,
      reason: 'o veredito deixou de percorrer a variável LISTA',
    );
    for (final k in <String>[kChaveDaGuarda, kChaveDaSuiteProtegida]) {
      expect(gates.single, contains(k),
          reason: '$k saiu da evidência publicada');
      expect(lista.single, contains(k),
          reason: '$k saiu da lista que o veredito percorre');
    }
  });

  test('o portão do APK roda o diretório inteiro e nomeia os três caminhos',
      () {
    final texto = leitura(
      kPortaoDoApk,
      'é a segunda porta desta âncora, e a única que sobrevive ao apagamento '
          'da entrada no alvo oficial',
    );
    expect(
      texto,
      contains(kComandoDoPortaoDoApk),
      reason: 'o portão do APK parou de rodar "$kComandoDoPortaoDoApk" — é '
          'esse comando que faz esta âncora ser executada mesmo depois de '
          'alguém tirar a entrada dela do alvo oficial',
    );
    for (final c in <String>[
      kCaminhoDaGuarda,
      kCaminhoDaSuiteProtegida,
      kCaminhoDestaAncora,
    ]) {
      expect(
        texto,
        contains('app/' + c),
        reason: 'o portão do APK não nomeia app/$c — apagá-lo derrubaria a '
            'contagem do diretório e deixaria o portão verde',
      );
    }
  });

  // =========================================================================
  // 3 — IDENTIDADE NOMINAL DOS CASOS
  // =========================================================================

  test('os casos das duas metades são exatamente estes', () {
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda');
    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');

    final daGuarda = casosDe(
      codigoDoBloco(guarda, kInicioDaGuarda, kFimDaGuarda, 'a metade que '
          'guarda'),
    );
    expect(
      daGuarda,
      orderedEquals(kCasosDaGuarda),
      reason: 'os casos da metade que guarda deixaram de ser os declarados '
          'nesta âncora: $daGuarda. Um caso retirado sai do placar em '
          'silêncio, e um renomeado troca a prova sem mexer na conta',
    );

    final daSuite = casosDe(protegida);
    expect(
      daSuite,
      orderedEquals(kCasosDaSuiteProtegida),
      reason: 'os casos da suíte protegida deixaram de ser os declarados '
          'nesta âncora: $daSuite',
    );
    expect(
      daSuite.toSet(),
      hasLength(daSuite.length),
      reason: 'dois casos da suíte protegida têm o mesmo nome',
    );
    // Os casos do DESENHO da obrigação são o objeto desta OS, e por isso são
    // cobrados um a um, e não só pela lista inteira.
    for (final c in kCasosDoDesenhoDaObrigacao) {
      expect(
        daSuite,
        contains(c),
        reason: 'o caso "$c" — que é uma das provas visuais da carta '
            'obrigatória — saiu da suíte protegida',
      );
    }
  });

  // =========================================================================
  // 4 — CONTEÚDO ESTRUTURAL INDISPENSÁVEL
  // =========================================================================

  test('cada metade tem as declarações sem as quais ela não confere nada', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    for (final d in kDeclaracoesDaGuarda) {
      expect(
        guarda,
        contains(d),
        reason: 'a metade que guarda perdeu a declaração "$d": ela pode '
            'conservar os cinco nomes de caso e ter perdido o mapa que diz o '
            'que conferir',
      );
    }

    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');
    final reciproca = codigoDoBloco(
      protegida,
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    for (final d in kDeclaracoesDaReciprocidade) {
      expect(
        reciproca,
        contains(d),
        reason: 'a metade recíproca perdeu a declaração "$d"',
      );
    }
    // As declarações de topo moram FORA do bloco: apagá-las não muda o digest
    // dele, e sem elas a metade recíproca não tem com que comparar.
    final codigoDeTopo = semLinhaDeComentario(protegida);
    for (final d in kDeclaracoesDeTopoDaSuiteProtegida) {
      expect(
        codigoDeTopo,
        contains(d),
        reason: 'a suíte protegida perdeu a declaração de topo "$d", que é o '
            'que a metade recíproca usa para conferir a guarda',
      );
    }
  });

  test('cada metade continua AFIRMANDO o que promete', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    final naoTriviaisDaGuarda = naoTriviaisDe(guarda);
    for (final e in kAfirmacoesDaGuarda.entries) {
      final quantas =
          naoTriviaisDaGuarda.where((a) => a.contains(e.key)).length;
      expect(
        quantas,
        greaterThanOrEqualTo(e.value),
        reason: 'a metade que guarda afirma ${e.key} $quantas vez(es), e esta '
            'âncora pede ${e.value}: a agulha continuar escrita no arquivo não '
            'é a mesma coisa que ela estar dentro do primeiro argumento de um '
            'expect',
      );
    }

    final reciproca = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    final naoTriviaisDaReciproca = naoTriviaisDe(reciproca);
    for (final e in kAfirmacoesDaReciprocidade.entries) {
      final quantas =
          naoTriviaisDaReciproca.where((a) => a.contains(e.key)).length;
      expect(
        quantas,
        greaterThanOrEqualTo(e.value),
        reason: 'a metade recíproca afirma ${e.key} $quantas vez(es), e esta '
            'âncora pede ${e.value}',
      );
    }
  });

  // =========================================================================
  // 5 — PISOS DE AFIRMAÇÕES NÃO TRIVIAIS
  // =========================================================================

  test('as duas metades continuam acima do piso de afirmações', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    final daGuarda = naoTriviaisDe(guarda);
    expect(
      daGuarda.length,
      greaterThanOrEqualTo(kPisoDaGuarda),
      reason: 'a metade que guarda ficou com ${daGuarda.length} afirmações que '
          'olham para a suíte protegida, de ${afirmacoesDe(guarda).length} '
          'expect: o resto é literal, tautologia ou string',
    );

    final reciproca = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    final daReciproca = naoTriviaisDe(reciproca);
    expect(
      daReciproca.length,
      greaterThanOrEqualTo(kPisoDaReciprocidade),
      reason: 'a metade recíproca ficou com ${daReciproca.length} afirmações '
          'que olham para a guarda, de ${afirmacoesDe(reciproca).length} '
          'expect',
    );
  });

  // =========================================================================
  // 6 — RECIPROCIDADE VIVA
  // =========================================================================

  test('as duas metades se guardam de volta, e os digests que elas declaram '
      'batem com o que está lá', () {
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda');
    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');

    // Apontamento mútuo.
    final blocoDaGuarda =
        codigoDoBloco(guarda, kInicioDaGuarda, kFimDaGuarda, 'a metade que '
            'guarda');
    expect(
      blocoDaGuarda,
      contains(kCaminhoDaSuiteProtegida),
      reason: 'a metade que guarda deixou de apontar para a suíte protegida',
    );
    expect(
      semLinhaDeComentario(protegida),
      contains(kCaminhoDaGuarda),
      reason: 'a suíte protegida deixou de apontar para a guarda externa',
    );

    // O digest que a guarda declara sobre a suíte protegida tem de ser o
    // digest DELA. Presente e errado é uma frase gentil.
    final declaradoLa = RegExp(r"const digestDaSuite = '([0-9a-f]{64})'")
        .firstMatch(guarda)
        ?.group(1);
    expect(
      declaradoLa,
      digestDe(protegida),
      reason: 'o digest que a guarda externa declara sobre a suíte protegida '
          'não é o da suíte protegida: a guarda ficou apontando para um '
          'arquivo que não existe mais',
    );

    // E o digest que a suíte protegida declara sobre o CÓDIGO da guarda tem de
    // ser o daquele bloco.
    final declaradoAqui =
        RegExp(r"const String kDigestDaGuardaExterna = '([0-9a-f]{64})'")
            .firstMatch(protegida)
            ?.group(1);
    expect(
      declaradoAqui,
      digestDe(blocoDaGuarda),
      reason: 'o digest que a suíte protegida declara sobre a guarda externa '
          'não é o do código da guarda externa',
    );
  });

  // =========================================================================
  // 7 — O VÍNCULO DE CONTEÚDO QUE O REALINHAMENTO COORDENADO NÃO ALCANÇA
  // =========================================================================

  test('o código das duas metades bate com o digest desta âncora', () {
    final blocoDaGuarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    expect(
      digestDe(blocoDaGuarda),
      kDigestDoCodigoDaGuarda,
      reason: 'o CÓDIGO da metade que guarda mudou. Este é o residual C10: os '
          'dois arquivos carregam o digest um do outro, e um commit que '
          'esvazia os dois realinha os dois. Este número mora num TERCEIRO '
          'arquivo. Se a mudança é legítima, ele entra aqui no mesmo commit',
    );

    final blocoReciproco = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    expect(
      digestDe(blocoReciproco),
      kDigestDoCodigoDaReciprocidade,
      reason: 'o CÓDIGO da metade recíproca mudou, e o digest dela nesta '
          'âncora não foi realinhado junto',
    );
  });

  // =========================================================================
  // 8 — O REGISTRO, O PRODUTOR, O MARCADOR, O LOG E O CONSUMIDOR
  // =========================================================================

  test('a entrada desta âncora está viva nas três listas do veredito', () {
    final texto = leitura(kAlvoOficial, 'é onde a entrada desta âncora mora');

    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    final obrigatorios = declaracoesDe(texto, 'OBRIGATORIOS');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(
      obrigatorios,
      hasLength(2),
      reason: 'o alvo declara ${obrigatorios.length} listas de gates '
          'obrigatórios, e são duas: a da evidência e a do veredito',
    );
    expect(
      obrigatorios.first,
      orderedEquals(obrigatorios.last),
      reason: 'as duas declarações de OBRIGATORIOS divergiram: o relatório '
          'diria uma coisa e o portão faria outra',
    );

    expect(gates.single, contains(kChaveDoGate),
        reason: '$kChaveDoGate saiu da evidência publicada');
    expect(lista.single, contains(kChaveDoGate),
        reason: '$kChaveDoGate saiu da lista que o veredito percorre — '
            'passaria a rodar sem poder reprovar');
    expect(obrigatorios.first, contains(kChaveDoGate),
        reason: '$kChaveDoGate deixou de ser obrigatório: um passo que não '
            'chegue a rodar voltaria a sair VERDE');
  });

  test('o comando que executa esta âncora está vivo, e não comentado', () {
    final texto = leitura(kAlvoOficial, 'é quem executa esta âncora');
    expect(
      RegExp(
        '^ *exige +' +
            kChaveDoGate +
            ' +' +
            RegExp.escape(kCaminhoDestaAncora) +
            r'[ \t]*$',
        multiLine: true,
      ).hasMatch(texto),
      isTrue,
      reason: 'o alvo oficial não exige $kCaminhoDestaAncora: o literal '
          'continuar escrito num comentário não executa nada, e `roda` no '
          'lugar de `exige` deixa a ausência do arquivo sair como NÃO '
          'EXECUTADO',
    );
  });

  test('o vínculo de conteúdo desta âncora está declarado no alvo oficial',
      () {
    final texto = leitura(kAlvoOficial, 'é onde o vínculo desta âncora mora');

    final arquivo = atribuicaoViva(texto, 'ANCORA_ARQUIVO');
    expect(
      arquivo,
      'app/' + kCaminhoDestaAncora,
      reason: 'o alvo oficial deixou de declarar ANCORA_ARQUIVO apontando '
          'para esta âncora — sem isso o digest confere outro arquivo',
    );

    final digest = atribuicaoViva(texto, 'ANCORA_DIGEST');
    expect(
      digest,
      digestDe(leitura(kCaminhoDestaAncora, 'é esta âncora')),
      reason: 'o digest desta âncora declarado no alvo oficial não é o desta '
          'âncora: o passo que a mede está medindo outra coisa',
    );

    final piso = atribuicaoViva(texto, 'ANCORA_PISO');
    expect(
      piso,
      '$kCasosDestaAncora',
      reason: 'o piso desta âncora no alvo oficial é $piso, e esta âncora tem '
          '$kCasosDestaAncora casos. Baixar o piso lá é como esvaziar a '
          'âncora aqui: os dois são o mesmo gesto, e nenhum se basta',
    );

    // O SEGUNDO DONO DO DIGEST.
    //
    // Um digest com um dono só é um digest que se realinha — é o residual C10
    // um degrau abaixo. O contrato desta autoridade é o segundo dono, e o alvo
    // oficial reprova se os dois números divergirem.
    final contrato = atribuicaoViva(texto, 'ANCORA_CONTRATO');
    expect(
      contrato,
      kCaminhoDoContrato,
      reason: 'o alvo oficial deixou de declarar ANCORA_CONTRATO apontando '
          'para $kCaminhoDoContrato: o digest desta âncora voltaria a ter um '
          'dono só',
    );
    final noContrato = RegExp('^ancora-digest: ([0-9a-f]{64})' + r'$',
            multiLine: true)
        .firstMatch(leitura('../' + kCaminhoDoContrato, 'é o contrato'))
        ?.group(1);
    expect(
      noContrato,
      digest,
      reason: 'o contrato declara o digest $noContrato e o alvo oficial '
          'declara $digest: um dos dois foi realinhado sozinho',
    );

    // O passo que confere o digest e o piso tem de estar VIVO. Comentá-lo
    // deixaria as declarações acima de pé, sem ninguém as ler.
    for (final l in <String>[
      r'd=$(tr -d "\r" < "$ANCORA_ARQUIVO" | sha256sum | cut -d" " -f1)',
      r'if [ "$d" != "$ANCORA_DIGEST" ]; then',
      r'c=$(grep -oE "^ancora-digest: [0-9a-f]{64}$" "$ANCORA_CONTRATO" | tail -1 | sed "s/.*: //")',
      r'if [ "$c" != "$ANCORA_DIGEST" ]; then',
      r'if [ -z "$n" ] || [ "$n" -lt "$ANCORA_PISO" ]; then',
      r'echo 1 > exit_ancoravis',
    ]) {
      expect(
        linhaViva(texto, l),
        isTrue,
        reason: 'o verificador externo do alvo oficial perdeu a linha viva '
            '`$l`: as declarações continuariam escritas e ninguém as leria',
      );
    }
  });

  test('o produtor do carimbo está vivo no alvo oficial', () {
    final texto = leitura(kAlvoOficial, 'é quem carimba antes de executar');
    expect(
      linhaViva(texto, 'date -u +%Y-%m-%dT%H:%M:%S.%NZ > carimbo_ancoravis'),
      isTrue,
      reason: 'o alvo oficial deixou de escrever carimbo_ancoravis ANTES de '
          'rodar as suítes. Sem o carimbo, um log guardado de outra execução '
          'passa por evidência desta',
    );
  });

  // =========================================================================
  // 9 — A EVIDÊNCIA DO EXECUTOR VERDADEIRO
  // =========================================================================
  //
  // O carimbo só existe onde o alvo oficial rodou. Onde ele não existe — no
  // portão do APK, e na bancada de quem está escrevendo — o que se pode
  // afirmar é que o PRODUTOR continua declarado, e isso já foi afirmado acima.
  // Onde ele existe, a evidência é cobrada inteira.

  test('as duas suítes protegidas executaram de verdade, e depois do carimbo',
      () {
    final carimbo = File(kCarimbo);
    if (!carimbo.existsSync()) {
      // Não é um `return` de conveniência: o produtor do carimbo já foi
      // afirmado no caso acima, e sem execução oficial não há log para ler.
      expect(
        linhaViva(
          leitura(kAlvoOficial, 'é quem carimba'),
          'date -u +%Y-%m-%dT%H:%M:%S.%NZ > carimbo_ancoravis',
        ),
        isTrue,
        reason: 'sem carimbo nesta execução, o mínimo é o produtor continuar '
            'declarado no alvo oficial',
      );
      return;
    }

    final quandoCarimbou = carimbo.statSync().modified;
    for (final par in <List<String>>[
      <String>[kChaveDaGuarda, kMarcadorDaGuarda, kLogDaGuarda],
      <String>[
        kChaveDaSuiteProtegida,
        kMarcadorDaSuiteProtegida,
        kLogDaSuiteProtegida,
      ],
    ]) {
      final chave = par[0];
      final marcador = File(par[1]);
      final log = File(par[2]);

      expect(
        marcador.existsSync(),
        isTrue,
        reason: 'há carimbo desta execução e o gate $chave não deixou '
            'marcador de saída: o passo não rodou',
      );
      expect(
        marcador.readAsStringSync().trim(),
        '0',
        reason: 'o gate $chave saiu com '
            '${marcador.readAsStringSync().trim()}',
      );
      expect(
        log.existsSync(),
        isTrue,
        reason: 'o gate $chave tem marcador de saída e não tem log: um '
            'marcador fabricado sem execução é exatamente isto',
      );
      expect(
        log.statSync().modified.isAfter(quandoCarimbou),
        isTrue,
        reason: 'o log do gate $chave é ANTERIOR ao carimbo desta execução '
            '(${log.statSync().modified} < $quandoCarimbou): é evidência de '
            'outra corrida, guardada e reapresentada',
      );
    }
  });

  test('o log de cada suíte protegida chama os casos pelo nome e fecha o '
      'placar', () {
    final carimbo = File(kCarimbo);
    if (!carimbo.existsSync()) {
      expect(
        linhaViva(
          leitura(kAlvoOficial, 'é quem carimba'),
          'date -u +%Y-%m-%dT%H:%M:%S.%NZ > carimbo_ancoravis',
        ),
        isTrue,
        reason: 'sem carimbo nesta execução, o mínimo é o produtor continuar '
            'declarado no alvo oficial',
      );
      return;
    }

    final logDaGuarda = leitura(kLogDaGuarda, 'é o log do gate cascaaud');
    final logDaSuite = leitura(kLogDaSuiteProtegida, 'é o log do gate mesac1');

    expect(
      placarDo(logDaGuarda),
      greaterThanOrEqualTo(kPisoDoPlacarDaGuarda),
      reason: 'o gate $kChaveDaGuarda fechou em ${placarDo(logDaGuarda)} '
          'casos, e o piso é $kPisoDoPlacarDaGuarda',
    );
    expect(
      placarDo(logDaSuite),
      greaterThanOrEqualTo(kPisoDoPlacarDaSuiteProtegida),
      reason: 'o gate $kChaveDaSuiteProtegida fechou em '
          '${placarDo(logDaSuite)} casos, e o piso é '
          '$kPisoDoPlacarDaSuiteProtegida',
    );

    // A chamada NOMINAL. O placar sozinho é uma conta: cinco casos novos e
    // vazios pagam cinco casos protegidos que sumiram.
    for (final c in kCasosDaGuarda) {
      expect(
        logDaGuarda,
        contains(c),
        reason: 'o caso "$c" da metade que guarda não foi chamado pelo nome '
            'no log do executor: ele não rodou nesta execução',
      );
    }
    for (final c in kCasosDoDesenhoDaObrigacao) {
      expect(
        logDaSuite,
        contains(c),
        reason: 'a prova visual "$c" não foi chamada pelo nome no log do '
            'executor: ela não rodou nesta execução',
      );
    }
    expect(
      logDaSuite,
      contains(kCasosDaSuiteProtegida.last),
      reason: 'o caso recíproco "${kCasosDaSuiteProtegida.last}" não foi '
          'chamado pelo nome no log do executor',
    );
  });

  // =========================================================================
  // 10 — A CAMPANHA QUE COBRA O RESIDUAL C10
  // =========================================================================

  test('o contrato desta âncora continua na árvore e nomeia o residual', () {
    final contrato = leitura(
      '../' + kCaminhoDoContrato,
      'é o contrato desta autoridade, e é onde a campanha negativa está '
          'registrada',
    );
    for (final t in <String>[
      'C6-01',
      'C6-20',
      kCaminhoDaGuarda,
      kCaminhoDaSuiteProtegida,
      kCaminhoDestaAncora,
      kChaveDoGate,
    ]) {
      expect(
        contrato,
        contains(t),
        reason: 'o contrato desta âncora deixou de registrar "$t": a campanha '
            'que cobra o residual C10 saiu do repositório',
      );
    }
  });
}
