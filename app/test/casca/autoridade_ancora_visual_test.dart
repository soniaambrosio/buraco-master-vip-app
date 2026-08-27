// autoridade_ancora_visual_test.dart — a AUTORIDADE EXTERNA da âncora das
// provas visuais da carta obrigatória do lixo.
//
// POR QUE ESTE ARQUIVO EXISTE.
//
// A OS 29-C4 tirou a guarda do desenho da obrigação de dentro do arquivo que
// ela guarda. A OS 29-C5 deu à metade recíproca a mesma força. A OS 29-C6
// acrescentou o TERCEIRO nó — `ancora_provas_visuais_test.dart` — que carrega
// cópia própria do que as duas metades são, e com isso matou o residual C10.
//
// A OS 29-R5 mediu o que sobrou, e o que sobrou é a própria âncora. Tudo o que
// decidia o que ela É morava em três arquivos que um mesmo gesto já estava
// tocando:
//
//   * o conteúdo, nela mesma;
//   * `ANCORA_DIGEST` e `ANCORA_PISO`, no `ci-os-integracao.yml`;
//   * `ancora-digest:`, no contrato dela.
//
// Esvaziá-la para um `expect(1, 1)`, recarimbar os dois donos do digest e
// baixar `ANCORA_PISO` para 1 saía VERDE, com as duas metades protegidas
// intactas. Foi o escape E3.
//
// Este arquivo é o QUARTO nó, e ele não pergunta nada à âncora sobre si mesma.
// O caminho canônico dela, o piso de casos, a relação NOMINAL dos casos, o
// piso de afirmações, as declarações estruturais e o digest do CÓDIGO dela
// estão declarados AQUI, em cópia própria — e nenhum desses valores é
// calculado a partir do alvo que este arquivo verifica.
//
// E ELE NÃO É UM C10 DESLOCADO UM ARQUIVO ADIANTE. A âncora guarda esta
// autoridade de volta, pelo conteúdo, e o alvo oficial e o contrato desta
// autoridade são o segundo e o terceiro donos do digest dela. O gesto que
// neutraliza os dois de uma vez precisa, agora, de CINCO arquivos de três
// naturezas: as duas suítes Dart, o alvo oficial e os dois contratos em prosa.
// Esse residual está declarado com esse tamanho, e não como proteção absoluta.
//
// O QUE ELE MAIS COBRA, e que a OS 29-R5 mostrou que faltava:
//
//   * a EXECUÇÃO VIVA do portão do APK. Presença textual do comando não é
//     autoridade: um `#` na frente da linha derrubava os 343 casos de
//     `test/casca` e `test/cartas` e o passo saía VERDE, com uma linha de
//     saída e zero teste. Aqui o comando é cobrado como LINHA VIVA de um
//     passo NOMEADO, e o passo tem de consumir o exit real e conferir o
//     placar contra um piso;
//   * a SEMÂNTICA das atribuições de shell. O leitor da C6 pegava a primeira
//     atribuição e o shell obedece à última: exige-se exatamente UMA viva;
//   * a POSIÇÃO do produtor do carimbo. Uma linha movida desligava a metade de
//     evidência inteira;
//   * a INTEGRIDADE da campanha registrada. Dois rótulos de seis letras
//     pagavam dezenove sabotagens.
//
// FAIL-CLOSED, E DE PROPÓSITO. Este arquivo não tem ramo degradado: sem porta
// declarada ele reprova, porque "não consegui olhar" e "olhei e está certo"
// não podem sair iguais.
//
// ONDE ELE É EXECUTADO. Nas duas portas, como a âncora:
//
//   * `.github/workflows/ci-os-integracao.yml`, pela chave `autancora`, que
//     entra por `exige` e está nas quatro listas do veredito;
//   * `.github/workflows/build.yml`, que roda `flutter test test/casca
//     test/cartas` no diretório inteiro e nomeia este arquivo, um a um, no
//     laço de obrigatórios.

@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// OS ENDEREÇOS
// ===========================================================================

/// A âncora que esta autoridade verifica.
const String kAncora = 'test/casca/ancora_provas_visuais_test.dart';

/// Esta autoridade, como os dois workflows a nomeiam.
const String kEstaAutoridade = 'test/casca/autoridade_ancora_visual_test.dart';

/// As duas suítes que a âncora torna obrigatórias.
const String kGuarda = 'test/casca/auditoria_casca_test.dart';
const String kProtegida = 'test/casca/mesa_treino_alvos_reais_test.dart';

/// As chaves dos quatro gates do eixo.
const String kChaveDaGuarda = 'cascaaud';
const String kChaveDaProtegida = 'mesac1';
const String kChaveDaAncora = 'ancoravis';
const String kChaveDestaAutoridade = 'autancora';

/// As duas portas, a partir de `app/`.
const String kAlvo = '../.github/workflows/ci-os-integracao.yml';
const String kApk = '../.github/workflows/build.yml';

/// Os dois contratos em prosa, a partir da raiz.
const String kContratoDaAncora =
    'docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md';
const String kContratoDestaAutoridade =
    'docs/AUTORIDADE-EXTERNA-ANCORA-VISUAL-V1.md';

// ===========================================================================
// OS PASSOS QUE DECIDEM
// ===========================================================================
//
// Workflow não se lê como textão. Cada `run:` é um shell próprio: o mesmo
// comando escrito noutro passo roda em OUTRO shell e não substitui este, e uma
// linha dentro de um heredoc não roda em lugar nenhum. Tudo abaixo é lido POR
// PASSO NOMEADO, e só o que sobra depois de tirar comentário e corpo de
// heredoc conta como comando vivo.

const String kPassoDasSuites =
    '1+2 — analyze + suítes Flutter (captura exit codes sem abortar)';
const String kPassoDaEvidencia = 'Publicar evidência na branch ci-evidencias';
const String kPassoDoVeredito =
    'Portão verde/vermelho (gate que falhou, e gate OBRIGATÓRIO que não rodou)';
const String kPassoDoApk =
    'PORTÃO DE PRODUÇÃO — casca real (roteamento, mocks, dados pessoais)';

/// A linha VIVA que executa as duas pastas no portão do APK, letra por letra.
const String kComandoVivoDoApk =
    'flutter test test/casca test/cartas --reporter expanded 2>&1 | tee '
    '../t_apk_casca.log';

/// O piso de casos do portão do APK. 343 é o placar da árvore da OS 29-C6; o
/// acréscimo é exclusivamente dos casos novos da OS 29-C7.
const int kPisoDoApk = 369;

/// Os arquivos que o portão do APK nomeia um a um no laço de obrigatórios.
const List<String> kObrigatoriosDoApk = <String>[
  'app/test/casca/mesa_treino_caracterizacao_test.dart',
  'app/test/casca/mesa_treino_acessivel_test.dart',
  'app/test/casca/mesa_treino_alvos_reais_test.dart',
  'app/test/casca/ancora_provas_visuais_test.dart',
  'app/test/casca/autoridade_ancora_visual_test.dart',
  'app/test/cartas/disposicao_da_mao_test.dart',
];

// ===========================================================================
// A PORTA POR QUE ESTA EXECUÇÃO VEIO
// ===========================================================================

const String kEnvPorta = 'BMV_PORTA_ANCORAVIS';
const String kEnvCarimbo = 'BMV_CARIMBO_ANCORAVIS';
const String kPortaDoAlvo = 'alvo-oficial';
const String kPortaDoApk = 'portao-apk';
const String kArquivoDaPorta = '../porta_ancoravis';
const String kCarimbo = '../carimbo_ancoravis';

/// As duas aspas triplas, escritas de um jeito que NÃO as escreve: aspas
/// adjacentes se juntam em tempo de compilação, e este arquivo continua sem
/// conter a agulha que ele procura no outro.
const String kAspaTriplaSimples = "'" "'" "'";
const String kAspaTriplaDupla = '"' '"' '"';

/// As linhas vivas com que cada porta limpa a evidência anterior, declara-se e
/// gera o carimbo desta corrida.
const String kLimpezaDoAlvo =
    'rm -f carimbo_ancoravis porta_ancoravis t_cascaaud.log t_mesac1.log '
    't_ancoravis.log t_autancora.log exit_cascaaud exit_mesac1 '
    'exit_ancoravis exit_autancora nao_cascaaud nao_mesac1 nao_ancoravis '
    'nao_autancora';
const String kLimpezaDoApk =
    'rm -f t_apk_casca.log carimbo_ancoravis porta_ancoravis';
const String kGeraCarimbo =
    r'BMV_CARIMBO_ANCORAVIS="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)-$$-${RANDOM}"';
const String kExportaCarimbo =
    'export BMV_PORTA_ANCORAVIS BMV_CARIMBO_ANCORAVIS';
const String kEscrevePorta =
    "printf '%s' " r'"$BMV_PORTA_ANCORAVIS" > porta_ancoravis';
const String kEscreveCarimbo =
    "printf '%s' " r'"$BMV_CARIMBO_ANCORAVIS" > carimbo_ancoravis';

/// Toda invocação de suíte no passo das suítes do alvo oficial.
final RegExp kInvocacaoDeSuite = RegExp(r'^(roda|exige) +[a-z0-9]+ +\S+$');

// ===========================================================================
// O QUE A ÂNCORA É — EM CÓPIA PRÓPRIA
// ===========================================================================
//
// Nada daqui é derivado do arquivo verificado. É esta independência que faz
// deste arquivo uma autoridade, e não um espelho.

/// Quantos casos a âncora tem.
const int kCasosDaAncora = 22;

/// O piso mínimo de casos da âncora.
///
/// A OS 29-C6 entregou dezesseis, e este é o piso contratado; o número acima é
/// o do estado vigente, e os dois são conferidos.
const int kPisoDeCasosDaAncora = 16;

/// Os casos da âncora, na ordem em que ela os declara.
const List<String> kCasosDaAncoraExterna = <String>[
  'os dois arquivos protegidos estão no caminho declarado',
  'o alvo oficial executa as duas suítes protegidas, pelo caminho certo',
  'o portão do APK roda o diretório inteiro e nomeia os três caminhos',
  'os casos das duas metades são exatamente estes',
  'cada metade tem as declarações sem as quais ela não confere nada',
  'cada metade continua AFIRMANDO o que promete',
  'as duas metades continuam acima do piso de afirmações',
  'as duas metades se guardam de volta, e os digests que elas declaram batem com o que está lá',
  'o código das duas metades bate com o digest desta âncora',
  'a entrada desta âncora está viva nas três listas do veredito',
  'o comando que executa esta âncora está vivo, e não comentado',
  'o vínculo de conteúdo desta âncora está declarado no alvo oficial',
  'o produtor do carimbo está vivo no alvo oficial',
  'as duas suítes protegidas executaram de verdade, e depois do carimbo',
  'o log de cada suíte protegida chama os casos pelo nome e fecha o placar',
  'o contrato desta âncora continua na árvore e nomeia o residual',
  'o portão do APK consome o exit real e confere o placar contra o piso',
  'a autoridade externa desta âncora está na árvore, íntegra e viva',
  'a entrada da autoridade externa está viva nas duas portas',
  'as variáveis que decidem execução têm uma atribuição viva só',
  'a campanha desta OS está inteira, única, ordenada e com resultado',
  'esta execução veio por uma das duas portas, com carimbo desta corrida',
];

/// O piso de afirmações NÃO TRIVIAIS da âncora.
///
/// Grosseiro de propósito: não julga qualidade, só impede que ela vire casca
/// com os nomes de pé depois que alguém realinhar os digests.
const int kPisoDeAfirmacoesDaAncora = 131;

/// O digest do CÓDIGO da âncora — sem as linhas móveis, sem comentário, sem
/// linha vazia e sem espaço à direita.
///
/// É AQUI que o escape E3 morre: esvaziar a âncora reprova neste ponto mesmo
/// depois de recarimbar `ANCORA_DIGEST` no alvo oficial, `ancora-digest:` no
/// contrato dela e `ANCORA_PISO`, porque o que se confere é o CONTEÚDO, e o
/// número mora num arquivo que aquele gesto não toca.
///
/// A linha abaixo é móvel de propósito: ela não entra no digest DESTE arquivo,
/// e é isso que permite aos dois nós carregarem o digest um do outro sem
/// entrarem em recursão.
const String kDigestDoCodigoDaAncora = 'f9802ed7ca349bf4762b57b154766094b81cdf67e0dbf52377d26108be67aee1'; // [digest-movel]

/// As declarações sem as quais a âncora não confere coisa nenhuma — ainda que
/// conserve os vinte e dois nomes de caso e o tamanho.
const List<String> kDeclaracoesDaAncora = <String>[
  "const String kCaminhoDaGuarda = 'test/casca/auditoria_casca_test.dart';",
  'const List<String> kCasosDaGuarda = <String>[',
  'const List<String> kCasosDaSuiteProtegida = <String>[',
  'const Map<String, int> kAfirmacoesDaGuarda = <String, int>{',
  'const Map<String, int> kAfirmacoesDaReciprocidade = <String, int>{',
  'const String kDigestDoCodigoDaGuarda =',
  'const String kDigestDoCodigoDaReciprocidade =',
  'const String kDigestDoCodigoDaAutoridade =',
  'const int kCasosDestaAncora = 22;',
  'const int kPisoDoPortaoDoApk = 369;',
  'List<Passo> passosDe(String yaml) {',
  'List<String> comandosVivos(List<String> linhas) {',
  'String atribuicaoUnica(Passo p, String nome, String onde) {',
  'String portaDestaExecucao() {',
  'String codigoDe(String texto) {',
  'void conferirCampanha(',
];

// ===========================================================================
// AS DUAS CAMPANHAS REGISTRADAS
// ===========================================================================

const int kVetoresDaC6 = 20;
const int kControlesDaC6 = 1;
const int kVetoresDaC7 = 32;
const int kControlesDaC7 = 1;
const int kPisoDaDescricaoDoVetor = 20;

// ===========================================================================
// OS VARREDORES
// ===========================================================================
//
// São os mesmos que a âncora tem, e estão duplicados de propósito. Importar os
// dela faria a conferência depender do conferido: quem a trivializasse
// trivializaria junto o instrumento que a mede.

/// Verdadeiro se a aspa em [k] abre uma string CRUA (`r'...'`).
bool aspaCrua(String fonte, int k) =>
    k > 0 &&
    (fonte[k - 1] == 'r' || fonte[k - 1] == 'R') &&
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
/// zero. Tudo a partir do primeiro nomeado fica de fora: `reason:` é prosa de
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

/// Verdadeiro se a afirmação não olha para programa nenhum.
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

/// O PRIMEIRO argumento posicional de cada `expect`, sem comentário e com o
/// conteúdo das strings esvaziado.
List<String> afirmacoesDe(String corpo) => argumentosDeExpect(
      semTextoDeString(semComentarios(corpo)),
    ).map((a) => posicionais(a).isEmpty ? '' : posicionais(a).first).toList();

/// As afirmações que olham para o programa.
List<String> naoTriviaisDe(String corpo) =>
    afirmacoesDe(corpo).where((x) => !afirmacaoTrivial(x)).toList();

/// O mesmo texto com fim de linha de máquina normalizado.
String normalizado(String t) =>
    t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// O texto sem as linhas que COMEÇAM com `//`.
String semLinhaDeComentario(String texto) => <String>[
      for (final l in normalizado(texto).split('\n'))
        if (!l.trimLeft().startsWith('//')) l,
    ].join('\n');

/// Os nomes dos casos declarados no texto, na ordem.
List<String> casosDe(String texto) => RegExp(
      "^\\s*(?:testWidgets|test)\\(\\s*'((?:[^'\\\\]|\\\\.)*)'",
      multiLine: true,
    )
        .allMatches(semLinhaDeComentario(texto))
        .map((m) => m.group(1)!)
        .toList();

/// O digest de um trecho, normalizado.
String digestDe(String t) =>
    sha256.convert(utf8.encode(normalizado(t))).toString();

/// O CÓDIGO de um arquivo inteiro: sem as linhas móveis, sem comentário, sem
/// linha vazia e sem espaço à direita.
///
/// As linhas marcadas `[digest-movel]` saem ANTES de o comentário ser tirado —
/// senão a marca, que mora no comentário, sumiria junto e a linha voltaria a
/// contar.
String codigoDe(String texto) {
  final semMovel = <String>[
    for (final l in normalizado(texto).split('\n'))
      if (!l.trimRight().endsWith('// [digest-movel]')) l,
  ].join('\n');
  return <String>[
    for (final l in semComentarios(semMovel).split('\n'))
      if (l.trim().isNotEmpty) l.trimRight(),
  ].join('\n');
}

/// O conteúdo de [caminho], ou uma reprovação nominal se ele não estiver lá.
String leitura(String caminho, String porque) {
  final f = File(caminho);
  expect(
    f.existsSync(),
    isTrue,
    reason: 'ausente: $caminho — $porque. Esta autoridade é fail-closed: não '
        'conseguir olhar e olhar e estar certo não podem sair iguais',
  );
  return normalizado(f.readAsStringSync());
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

/// O placar com que o `--reporter expanded` fechou um log.
int placarDo(String log) {
  final m = RegExp(r'\+([0-9]+):[^\n]*All tests passed!')
      .allMatches(log)
      .toList();
  if (m.isEmpty) return -1;
  return int.parse(m.last.group(1)!);
}

// ===========================================================================
// LER O WORKFLOW COMO PASSOS
// ===========================================================================

/// Um passo do workflow: o nome declarado, o corpo cru e os comandos VIVOS.
class Passo {
  const Passo(this.nome, this.cru, this.comandos);
  final String nome;
  final List<String> cru;
  final List<String> comandos;
}

/// O corpo do bloco `run: |` de um passo, ainda com o recuo do arquivo.
List<String> corpoDoRun(List<String> cru) {
  final chave = RegExp(r'^(\s*)run:\s*\|-?\s*$');
  for (var k = 0; k < cru.length; k++) {
    final m = chave.firstMatch(cru[k]);
    if (m == null) continue;
    final recuo = m.group(1)!.length;
    final saida = <String>[];
    for (var j = k + 1; j < cru.length; j++) {
      final l = cru[j];
      if (l.trim().isEmpty) {
        saida.add('');
        continue;
      }
      if (l.length - l.trimLeft().length <= recuo) break;
      saida.add(l);
    }
    return saida;
  }
  return const <String>[];
}

/// O que o shell de um passo realmente executa: sem linha em branco, sem
/// comentário, sem corpo de heredoc, com as continuações de `\` juntadas.
List<String> comandosVivos(List<String> linhas) {
  final saida = <String>[];
  final abreHeredoc = RegExp('<<-?[ ]*[\'"]?([A-Za-z_][A-Za-z0-9_]*)[\'"]?');
  String? heredoc;
  var acumulado = '';
  for (final bruta in linhas) {
    final t = bruta.trim();
    if (heredoc != null) {
      if (t == heredoc) heredoc = null;
      continue;
    }
    if (t.isEmpty) continue;
    if (acumulado.isEmpty && t.startsWith('#')) continue;
    if (t.endsWith(r'\')) {
      final pedaco = t.substring(0, t.length - 1).trim();
      acumulado = acumulado.isEmpty ? pedaco : '$acumulado $pedaco';
      continue;
    }
    final comando = acumulado.isEmpty ? t : '$acumulado $t';
    acumulado = '';
    saida.add(comando);
    final h = abreHeredoc.firstMatch(comando);
    if (h != null) heredoc = h.group(1);
  }
  if (acumulado.isNotEmpty) saida.add(acumulado);
  return saida;
}

/// Todos os passos de um workflow.
List<Passo> passosDe(String yaml) {
  final linhas = normalizado(yaml).split('\n');
  final abre = RegExp(r'^(\s*)-\s+name:\s*(.*?)\s*$');
  final passos = <Passo>[];
  var i = 0;
  while (i < linhas.length) {
    final m = abre.firstMatch(linhas[i]);
    if (m == null) {
      i++;
      continue;
    }
    final recuo = m.group(1)!.length;
    var nome = m.group(2)!;
    if (nome.length >= 2 &&
        ((nome.startsWith('"') && nome.endsWith('"')) ||
            (nome.startsWith("'") && nome.endsWith("'")))) {
      nome = nome.substring(1, nome.length - 1);
    }
    final cru = <String>[linhas[i]];
    var j = i + 1;
    while (j < linhas.length) {
      final l = linhas[j];
      if (l.trim().isNotEmpty && l.length - l.trimLeft().length <= recuo) break;
      cru.add(l);
      j++;
    }
    passos.add(Passo(nome, cru, comandosVivos(corpoDoRun(cru))));
    i = j;
  }
  return passos;
}

/// O passo de [nome], ou uma reprovação nominal se ele sumiu ou foi renomeado.
Passo passo(String yaml, String nome, String onde) {
  final achados = passosDe(yaml).where((p) => p.nome == nome).toList();
  expect(
    achados,
    hasLength(1),
    reason: 'o passo "$nome" de $onde aparece ${achados.length} vezes. Um '
        'passo removido, renomeado ou duplicado muda o que executa sem mudar '
        'uma letra do que está escrito',
  );
  return achados.single;
}

/// O padrão de uma linha inteira, literal.
RegExp literal(String linha) => RegExp('^' + RegExp.escape(linha) + r'$');

/// O índice do primeiro comando vivo do passo que casa com [padrao], ou -1.
int indiceDe(Passo p, RegExp padrao) => p.comandos.indexWhere(padrao.hasMatch);

/// Quantos comandos vivos do passo casam com [padrao].
int vezesNoPasso(Passo p, RegExp padrao) =>
    p.comandos.where(padrao.hasMatch).length;

/// Os valores de toda atribuição VIVA de [nome] no passo, `export` incluído.
List<String> atribuicoesVivas(Passo p, String nome) {
  final padrao = RegExp('^(?:export +)?' + RegExp.escape(nome) + r'=(.*)$');
  return <String>[
    for (final c in p.comandos)
      if (padrao.hasMatch(c)) padrao.firstMatch(c)!.group(1)!,
  ];
}

/// O valor da ÚNICA atribuição viva de [nome] no passo.
///
/// A OS 29-R5 mediu o escape E4 nesta exata dobra: o leitor pegava a PRIMEIRA
/// atribuição e o shell obedece à ÚLTIMA, então bastava inserir uma segunda
/// linha para a guarda ler um valor e o portão usar outro.
String atribuicaoUnica(Passo p, String nome, String onde) {
  final vivas = atribuicoesVivas(p, nome);
  expect(
    vivas,
    hasLength(1),
    reason: 'o passo "${p.nome}" de $onde tem ${vivas.length} atribuições '
        'vivas de $nome (${vivas.join(" | ")}). O shell obedece à ÚLTIMA: uma '
        'segunda atribuição, antes ou depois da legítima, faz a guarda e a '
        'execução falarem de valores diferentes',
  );
  return vivas.single;
}

/// Verdadeiro se [valor] é um literal fechado.
bool valorLiteral(String valor) =>
    RegExp(r'^[A-Za-z0-9._/:+-]+$').hasMatch(valor);

// ===========================================================================
// A PORTA DESTA EXECUÇÃO
// ===========================================================================

/// A porta por que esta execução veio, conferida contra o carimbo desta
/// corrida. NÃO existe ramo "sem porta".
String portaDestaExecucao() {
  final porta = Platform.environment[kEnvPorta] ?? '';
  expect(
    <String>[kPortaDoAlvo, kPortaDoApk],
    contains(porta),
    reason: 'esta suíte foi executada sem porta declarada em $kEnvPorta '
        '(veio "$porta"). Ela é fail-closed de propósito: as duas portas '
        'oficiais declaram a porta e o carimbo antes de executar, e uma '
        'execução que não veio por nenhuma delas não tem evidência para '
        'apresentar',
  );
  final naEnv = Platform.environment[kEnvCarimbo] ?? '';
  expect(
    naEnv.isNotEmpty,
    isTrue,
    reason: 'a porta $porta não passou o carimbo desta corrida em '
        '$kEnvCarimbo',
  );
  final noDisco = File(kCarimbo);
  expect(
    noDisco.existsSync(),
    isTrue,
    reason: 'a porta $porta declarou o carimbo $naEnv e não escreveu '
        '$kCarimbo',
  );
  expect(
    noDisco.readAsStringSync().trim(),
    naEnv,
    reason: 'o carimbo em disco é "${noDisco.readAsStringSync().trim()}" e o '
        'desta corrida é "$naEnv": a evidência apresentada é de outra '
        'execução',
  );
  final arquivo = File(kArquivoDaPorta);
  expect(
    arquivo.existsSync(),
    isTrue,
    reason: 'a porta $porta não escreveu $kArquivoDaPorta',
  );
  expect(
    arquivo.readAsStringSync().trim(),
    porta,
    reason: 'o ambiente diz que a porta é $porta e o disco diz '
        '"${arquivo.readAsStringSync().trim()}"',
  );
  return porta;
}

// ===========================================================================
// LER A CAMPANHA REGISTRADA COMO TABELA
// ===========================================================================

/// Uma linha da tabela de campanha de um contrato.
class Vetor {
  const Vetor(this.id, this.gesto, this.acusador, this.resultado);
  final String id;
  final String gesto;
  final String acusador;
  final String resultado;
}

/// Os vetores declarados na TABELA de [markdown]. Um identificador escrito na
/// prosa, num comentário ou num texto-isca não é um vetor declarado.
List<Vetor> campanhaDe(String markdown, String prefixo) {
  final saida = <Vetor>[];
  for (final l in normalizado(markdown).split('\n')) {
    final t = l.trim();
    if (!t.startsWith('| $prefixo')) continue;
    final col = t.split('|').map((c) => c.trim()).toList();
    if (col.length < 6) continue;
    saida.add(Vetor(col[1], col[2], col[3], col[4]));
  }
  return saida;
}

/// Confere uma campanha inteira: identidade, unicidade, ordem, descrição
/// material, acusador, resultado esperado e a conta de vermelhos e controles.
void conferirCampanha(
  String markdown,
  String prefixo,
  int quantos,
  int controles,
  String onde,
) {
  final vetores = campanhaDe(markdown, prefixo);
  final esperados = <String>[
    for (var i = 1; i <= quantos; i++)
      '$prefixo-${i.toString().padLeft(2, '0')}',
  ];
  expect(
    vetores.map((v) => v.id).toList(),
    orderedEquals(esperados),
    reason: 'a campanha $prefixo de $onde declara '
        '${vetores.map((v) => v.id).join(", ")}, e o contrato são os '
        '$quantos identificadores de $prefixo-01 a ${esperados.last}, na '
        'ordem, cada um uma vez',
  );
  for (final v in vetores) {
    expect(
      v.gesto.length,
      greaterThanOrEqualTo(kPisoDaDescricaoDoVetor),
      reason: 'o vetor ${v.id} de $onde ficou com a descrição "${v.gesto}"',
    );
    expect(
      v.acusador.length,
      greaterThanOrEqualTo(5),
      reason: 'o vetor ${v.id} de $onde não diz quem o acusa',
    );
    expect(
      <String>['VERMELHO', 'VERDE'],
      contains(v.resultado),
      reason: 'o vetor ${v.id} de $onde declara o resultado esperado '
          '"${v.resultado}"',
    );
  }
  final verdes = vetores.where((v) => v.resultado == 'VERDE').length;
  expect(
    verdes,
    controles,
    reason: 'a campanha $prefixo de $onde tem $verdes controles verdes, e o '
        'contrato são $controles',
  );
  expect(
    vetores.length - verdes,
    quantos - controles,
    reason: 'a campanha $prefixo de $onde tem ${vetores.length - verdes} '
        'sabotagens vermelhas, e o contrato são ${quantos - controles}',
  );
  expect(
    vetores.isNotEmpty && vetores.last.resultado == 'VERDE',
    isTrue,
    reason: 'o último vetor da campanha $prefixo de $onde é o CONTROLE, e ele '
        'tem de ser explicitamente verde',
  );
}

void main() {
  // =========================================================================
  // 1 — A ÂNCORA, POR CONTEÚDO
  // =========================================================================

  test('a âncora existe no caminho canônico, e não encolheu', () {
    final ancora = leitura(
      kAncora,
      'é a âncora externa das provas visuais, e é ela que torna obrigatórias '
          'as duas metades que guardam o desenho da carta obrigatória',
    );
    // Um digest bate com um arquivo vazio tão bem quanto com o certo. O
    // tamanho é a segunda pergunta, e ela não depende de digest nenhum.
    expect(
      ancora.split('\n').length,
      greaterThan(1500),
      reason: 'a âncora encolheu para ${ancora.split('\n').length} linhas',
    );
    expect(
      File(kEstaAutoridade).existsSync(),
      isTrue,
      reason: 'esta autoridade não está no caminho canônico '
          '$kEstaAutoridade, que é o que os dois workflows nomeiam',
    );
  });

  test('os casos da âncora são exatamente estes, na ordem contratada', () {
    final ancora = leitura(kAncora, 'é a âncora');
    expect(
      casosDe(ancora),
      orderedEquals(kCasosDaAncoraExterna),
      reason: 'os casos da âncora deixaram de ser os declarados aqui. Esta '
          'lista é a cópia PRÓPRIA desta autoridade: renomear um caso, trocar '
          'um por outro, acrescentar um caso vazio para inflar o placar ou '
          'esvaziar a âncora inteira reprovam todos neste ponto, e nenhum '
          'deles é alcançado recarimbando ANCORA_DIGEST',
    );
    expect(
      casosDe(ancora).length,
      kCasosDaAncora,
      reason: 'a âncora tem ${casosDe(ancora).length} casos, e o contrato são '
          '$kCasosDaAncora',
    );
    expect(
      kCasosDaAncora,
      greaterThanOrEqualTo(kPisoDeCasosDaAncora),
      reason: 'o piso contratado da âncora é $kPisoDeCasosDaAncora casos, e '
          'esta autoridade passou a declarar $kCasosDaAncora',
    );
  });

  test('o código da âncora bate com o digest desta autoridade', () {
    final ancora = leitura(kAncora, 'é a âncora');
    expect(
      digestDe(codigoDe(ancora)),
      kDigestDoCodigoDaAncora,
      reason: 'o CÓDIGO da âncora não bate com o digest declarado aqui. É '
          'esta linha que fecha o escape E3 da OS 29-R5: esvaziar a âncora, '
          'recarimbar ANCORA_DIGEST no alvo oficial e ancora-digest: no '
          'contrato dela, e baixar ANCORA_PISO, reprova aqui — porque o que '
          'se confere é o conteúdo, e este número mora num quarto arquivo',
    );
  });

  test('a âncora não usa aspa tripla, que cega qualquer varredor', () {
    final ancora = leitura(kAncora, 'é a âncora');
    for (final aspa in <String>[kAspaTriplaSimples, kAspaTriplaDupla]) {
      expect(
        ancora.contains(aspa),
        isFalse,
        reason: 'a âncora passou a usar aspa tripla ($aspa). Todo varredor '
            'que respeita aspas lê a SEGUNDA aspa como fechamento, perde o '
            'sincronismo e passa a ler o resto do arquivo como texto: mediria '
            'o mesmo número num arquivo íntegro e num arquivo vazio',
      );
      expect(
        leitura(kEstaAutoridade, 'é esta autoridade').contains(aspa),
        isFalse,
        reason: 'esta autoridade passou a usar aspa tripla ($aspa), e ela '
            'é o instrumento que mede a âncora: cega, ela mediria o mesmo '
            'número num arquivo íntegro e num arquivo vazio',
      );
    }
  });

  test('a âncora continua afirmando acima do piso, e não virou casca', () {
    final ancora = leitura(kAncora, 'é a âncora');
    expect(
      naoTriviaisDe(ancora).length,
      greaterThanOrEqualTo(kPisoDeAfirmacoesDaAncora),
      reason: 'a âncora ficou com ${naoTriviaisDe(ancora).length} afirmações '
          'que olham para o programa, e o piso é $kPisoDeAfirmacoesDaAncora. '
          'Conservar os nomes dos casos e trocar os corpos por assertivas '
          'tautológicas é o gesto que esta contagem existe para pegar',
    );
  });

  test('a âncora carrega as declarações sem as quais ela não confere nada',
      () {
    final ancora = leitura(kAncora, 'é a âncora');
    for (final d in kDeclaracoesDaAncora) {
      expect(
        ancora,
        contains(d),
        reason: 'a âncora perdeu a declaração `$d`. Sem ela os nomes dos casos '
            'continuam de pé e o que eles conferem é outra coisa',
      );
    }
  });

  // =========================================================================
  // 2 — A ÂNCORA É EXECUTADA NAS DUAS PORTAS
  // =========================================================================

  test('o alvo oficial exige a âncora, viva, no passo que a executa', () {
    final texto = leitura(kAlvo, 'é a autoridade canônica de gates');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    expect(
      vezesNoPasso(
        p,
        RegExp('^exige +$kChaveDaAncora +' + RegExp.escape(kAncora) + r'$'),
      ),
      1,
      reason: 'o alvo oficial não exige $kAncora exatamente uma vez no passo '
          '"$kPassoDasSuites". O literal continuar escrito num comentário não '
          'executa nada; `roda` no lugar de `exige` deixa a ausência do '
          'arquivo sair como NÃO EXECUTADO; e o mesmo comando escrito noutro '
          'passo roda noutro shell',
    );
    for (final chave in <String>[kChaveDaGuarda, kChaveDaProtegida]) {
      expect(
        vezesNoPasso(p, RegExp('^(roda|exige) +$chave +\\S+' + r'$')),
        1,
        reason: 'o gate $chave deixou de ser invocado no passo das suítes',
      );
    }
  });

  test('a âncora está nas quatro listas do veredito do alvo oficial', () {
    final texto = leitura(kAlvo, 'é onde as listas do veredito moram');
    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    final obrigatorios = declaracoesDe(texto, 'OBRIGATORIOS');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(
      obrigatorios,
      hasLength(2),
      reason: 'o alvo declara ${obrigatorios.length} listas de obrigatórios, e '
          'são duas: a da evidência e a do veredito',
    );
    expect(
      obrigatorios.first,
      orderedEquals(obrigatorios.last),
      reason: 'as duas declarações de OBRIGATORIOS divergiram: o relatório '
          'diria uma coisa e o portão faria outra',
    );
    for (final chave in <String>[kChaveDaAncora, kChaveDestaAutoridade]) {
      expect(gates.single, contains(chave),
          reason: '$chave saiu da evidência publicada');
      expect(lista.single, contains(chave),
          reason: '$chave saiu da lista que o veredito percorre: passaria a '
              'rodar sem poder reprovar');
      expect(obrigatorios.first, contains(chave),
          reason: '$chave saiu da lista de obrigatórios da evidência');
      expect(obrigatorios.last, contains(chave),
          reason: '$chave saiu da lista de obrigatórios do veredito: um passo '
              'que não chegasse a rodar voltaria a sair VERDE');
    }
    expect(
      RegExp(r'for +k +in +\$LISTA *; *do').hasMatch(texto),
      isTrue,
      reason: 'o veredito deixou de percorrer a variável LISTA',
    );
  });

  test('o portão do APK nomeia a âncora no laço vivo de obrigatórios', () {
    final texto = leitura(kApk, 'é a segunda porta da âncora');
    final p = passo(texto, kPassoDoApk, 'o portão do APK');
    final laco =
        p.comandos.where((c) => c.startsWith('for obrigatoria in ')).toList();
    expect(
      laco,
      hasLength(1),
      reason: 'o portão do APK tem ${laco.length} laços de obrigatórios. É '
          'este laço que faz apagar um arquivo doer antes de a contagem do '
          'diretório cair — e é ele que reprova a retirada COORDENADA da '
          'âncora das duas portas',
    );
    for (final c in kObrigatoriosDoApk) {
      expect(
        laco.single,
        contains(c),
        reason: 'o portão do APK não nomeia $c no laço VIVO. Escrito num '
            'comentário, o caminho continua contido no arquivo e o laço não o '
            'confere',
      );
    }
  });

  test('o portão do APK executa as duas pastas numa linha viva', () {
    final texto = leitura(kApk, 'é a segunda porta da âncora');
    final p = passo(texto, kPassoDoApk, 'o portão do APK');
    expect(
      vezesNoPasso(p, literal(kComandoVivoDoApk)),
      1,
      reason: 'o passo "$kPassoDoApk" não executa exatamente uma vez a linha '
          'viva `$kComandoVivoDoApk`. Comentada com um único `#`, trocada por '
          'um `echo`, envolvida em `if false`, seguida de `|| true`, '
          'estreitada para um diretório só ou escrita dentro de um heredoc, '
          'ela continua CONTIDA no arquivo e não executa teste nenhum — foi o '
          'escape E2 da OS 29-R5, e ele derrubava os 343 casos de uma vez',
    );
    for (final proibido in <String>['|| true', 'if false']) {
      expect(
        p.comandos.where((c) => c.contains(proibido)).toList(),
        isEmpty,
        reason: 'o passo "$kPassoDoApk" ganhou `$proibido`',
      );
    }
    expect(
      p.cru.where((l) => l.contains('continue-on-error')).toList(),
      isEmpty,
      reason: 'o passo "$kPassoDoApk" ganhou continue-on-error, que reprova '
          'sem reprovar',
    );
    expect(
      p.comandos
          .where((c) => c.startsWith('echo') && c.contains('flutter test'))
          .toList(),
      isEmpty,
      reason: 'o comando de teste do portão do APK virou texto impresso',
    );
  });

  test('o portão do APK consome o exit real e confere o placar contra o piso',
      () {
    final texto = leitura(kApk, 'é a segunda porta da âncora');
    final p = passo(texto, kPassoDoApk, 'o portão do APK');
    const linhas = <String>[
      'set +e',
      r'APK_EXIT=${PIPESTATUS[0]}',
      'set -e',
      r'if [ "$APK_EXIT" != "0" ]; then',
      r'APK_PLACAR=$(grep -oE "\+[0-9]+: All tests passed!" ../t_apk_casca.log | grep -oE "[0-9]+" | tail -1)',
      r'if [ -z "$APK_PLACAR" ]; then',
      r'if [ "$APK_PLACAR" -lt "$APK_PISO" ]; then',
    ];
    for (final l in linhas) {
      expect(
        vezesNoPasso(p, literal(l)),
        1,
        reason: 'o portão do APK perdeu a linha viva `$l`. Sem ela o passo '
            'volta a declarar PORTÃO VERDE sem consumir o exit real e sem '
            'comprovar placar: zero teste com exit 0 sairia verde',
      );
    }
    expect(
      atribuicaoUnica(p, 'APK_PISO', 'o portão do APK'),
      '$kPisoDoApk',
      reason: 'o piso do portão do APK não é $kPisoDoApk. Ele é o placar da '
          'árvore da OS 29-C6 mais os casos novos da OS 29-C7, e baixá-lo é '
          'como apagar suíte',
    );
    final iFlutter = indiceDe(p, literal(kComandoVivoDoApk));
    expect(
      iFlutter,
      greaterThanOrEqualTo(0),
      reason: 'o portão do APK não tem a linha viva que executa as duas '
          'pastas: não existe execução cujo exit e cujo placar consumir',
    );
    final iExit = indiceDe(p, literal(r'APK_EXIT=${PIPESTATUS[0]}'));
    final iSePiso =
        indiceDe(p, literal(r'if [ "$APK_PLACAR" -lt "$APK_PISO" ]; then'));
    final iVerde = indiceDe(p, RegExp('^echo "PORTÃO VERDE'));
    expect(iVerde, greaterThanOrEqualTo(0),
        reason: 'o portão do APK não anuncia mais o próprio veredito');
    expect(iExit, greaterThan(iFlutter),
        reason: 'o exit é capturado antes de a execução acontecer');
    expect(iVerde, greaterThan(iSePiso),
        reason: 'o PORTÃO VERDE é anunciado antes de o piso ser conferido');
    expect(
      p.comandos.sublist(0, iFlutter).where((c) => c == 'exit 0').toList(),
      isEmpty,
      reason: 'o passo sai com sucesso ANTES de executar as suítes',
    );
    expect(
      p.comandos.where((c) => c == 'exit 1').length,
      greaterThanOrEqualTo(3),
      reason: 'as três conferências do portão do APK não reprovam: capturar o '
          'erro e sair verde é o mesmo que não capturar',
    );
  });

  // =========================================================================
  // 3 — ESTA AUTORIDADE É EXECUTADA NAS DUAS PORTAS
  // =========================================================================

  test('o alvo oficial exige esta autoridade e a torna obrigatória', () {
    final texto = leitura(kAlvo, 'é onde a entrada desta autoridade mora');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    expect(
      vezesNoPasso(
        p,
        RegExp('^exige +$kChaveDestaAutoridade +' +
            RegExp.escape(kEstaAutoridade) +
            r'$'),
      ),
      1,
      reason: 'o alvo oficial não exige $kEstaAutoridade exatamente uma vez',
    );
    final iAncora =
        indiceDe(p, RegExp('^exige +$kChaveDaAncora +' + RegExp.escape(kAncora) + r'$'));
    final iEsta = indiceDe(
        p,
        RegExp('^exige +$kChaveDestaAutoridade +' +
            RegExp.escape(kEstaAutoridade) +
            r'$'));
    expect(
      iEsta,
      greaterThan(iAncora),
      reason: 'esta autoridade é executada antes da âncora que ela verifica',
    );
  });

  test('o portão do APK nomeia esta autoridade no laço vivo', () {
    final texto = leitura(kApk, 'é a segunda porta desta autoridade');
    final p = passo(texto, kPassoDoApk, 'o portão do APK');
    final laco =
        p.comandos.where((c) => c.startsWith('for obrigatoria in ')).toList();
    expect(laco, hasLength(1), reason: 'o portão do APK perdeu o laço');
    expect(
      laco.single,
      contains('app/$kEstaAutoridade'),
      reason: 'o portão do APK não nomeia app/$kEstaAutoridade. Se esta '
          'autoridade pudesse sumir daqui em silêncio, apagá-la junto com a '
          'entrada do alvo oficial sairia verde',
    );
  });

  // =========================================================================
  // 4 — A SEMÂNTICA DAS ATRIBUIÇÕES
  // =========================================================================

  test('cada variável de decisão tem exatamente uma atribuição viva', () {
    const doAlvo = <String>[
      'ANCORA_ARQUIVO',
      'ANCORA_CONTRATO',
      'ANCORA_DIGEST',
      'ANCORA_PISO',
      'AUTORIDADE_ARQUIVO',
      'AUTORIDADE_CONTRATO',
      'AUTORIDADE_DIGEST',
      'AUTORIDADE_PISO',
      'BMV_PORTA_ANCORAVIS',
    ];
    const doApk = <String>['APK_PISO', 'BMV_PORTA_ANCORAVIS'];
    for (final par in <List<Object>>[
      <Object>[kAlvo, kPassoDasSuites, doAlvo, 'o alvo oficial'],
      <Object>[kApk, kPassoDoApk, doApk, 'o portão do APK'],
    ]) {
      final texto = leitura(par[0] as String, 'é ${par[3]}');
      final autorizado = passo(texto, par[1] as String, par[3] as String);
      for (final nome in par[2] as List<String>) {
        final valor = atribuicaoUnica(autorizado, nome, par[3] as String);
        expect(
          valorLiteral(valor),
          isTrue,
          reason: 'o valor de $nome em ${par[3]} é "$valor": valor composto em '
              'tempo de execução, expansão indireta ou fallback permissivo '
              'fazem a guarda e o shell falarem de coisas diferentes',
        );
        for (final outro in passosDe(texto)) {
          if (outro.nome == autorizado.nome) continue;
          expect(
            atribuicoesVivas(outro, nome),
            isEmpty,
            reason: '$nome também é atribuído vivo no passo "${outro.nome}" de '
                '${par[3]}: uma segunda autoridade sobre o mesmo valor',
          );
        }
      }
    }
  });

  test('o vínculo de conteúdo da âncora tem dois donos, e eles concordam', () {
    final texto = leitura(kAlvo, 'é o primeiro dono dos digests');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    final ancora = leitura(kAncora, 'é a âncora');
    final esta = leitura(kEstaAutoridade, 'é esta autoridade');

    expect(atribuicaoUnica(p, 'ANCORA_ARQUIVO', 'o alvo oficial'),
        'app/$kAncora',
        reason: 'ANCORA_ARQUIVO deixou de apontar para a âncora');
    expect(atribuicaoUnica(p, 'ANCORA_CONTRATO', 'o alvo oficial'),
        kContratoDaAncora,
        reason: 'ANCORA_CONTRATO deixou de apontar para o contrato dela');
    expect(atribuicaoUnica(p, 'ANCORA_DIGEST', 'o alvo oficial'),
        digestDe(ancora),
        reason: 'o digest da âncora no alvo oficial não é o dela');
    expect(atribuicaoUnica(p, 'ANCORA_PISO', 'o alvo oficial'), '$kCasosDaAncora',
        reason: 'o piso da âncora no alvo oficial deixou de ser '
            '$kCasosDaAncora — e baixá-lo é o gesto que a OS 29-R5 mediu como '
            'metade do escape E3');
    expect(atribuicaoUnica(p, 'AUTORIDADE_ARQUIVO', 'o alvo oficial'),
        'app/$kEstaAutoridade',
        reason: 'AUTORIDADE_ARQUIVO deixou de apontar para esta autoridade');
    expect(atribuicaoUnica(p, 'AUTORIDADE_CONTRATO', 'o alvo oficial'),
        kContratoDestaAutoridade,
        reason: 'AUTORIDADE_CONTRATO deixou de apontar para o contrato desta '
            'autoridade');
    expect(atribuicaoUnica(p, 'AUTORIDADE_DIGEST', 'o alvo oficial'),
        digestDe(esta),
        reason: 'o digest desta autoridade no alvo oficial não é o dela');
    expect(atribuicaoUnica(p, 'AUTORIDADE_PISO', 'o alvo oficial'),
        '${casosDe(esta).length}',
        reason: 'o piso desta autoridade no alvo oficial não é o número de '
            'casos dela');

    final naAncora = RegExp('^ancora-digest: ([0-9a-f]{64})' + r'$',
            multiLine: true)
        .firstMatch(leitura('../$kContratoDaAncora', 'é o contrato da âncora'))
        ?.group(1);
    expect(naAncora, digestDe(ancora),
        reason: 'o contrato da âncora declara $naAncora, e o digest dela é '
            '${digestDe(ancora)}');
    final nesta = RegExp('^autoridade-digest: ([0-9a-f]{64})' + r'$',
            multiLine: true)
        .firstMatch(
            leitura('../$kContratoDestaAutoridade', 'é o contrato desta'))
        ?.group(1);
    expect(nesta, digestDe(esta),
        reason: 'o contrato desta autoridade declara $nesta, e o digest dela é '
            '${digestDe(esta)}');

    for (final l in <String>[
      r'd=$(tr -d "\r" < "$ANCORA_ARQUIVO" | sha256sum | cut -d" " -f1)',
      r'if [ "$d" != "$ANCORA_DIGEST" ]; then',
      r'if [ "$c" != "$ANCORA_DIGEST" ]; then',
      r'if [ -z "$n" ] || [ "$n" -lt "$ANCORA_PISO" ]; then',
      r'echo 1 > exit_ancoravis',
      r'da=$(tr -d "\r" < "$AUTORIDADE_ARQUIVO" | sha256sum | cut -d" " -f1)',
      r'if [ "$da" != "$AUTORIDADE_DIGEST" ]; then',
      r'if [ "$ca" != "$AUTORIDADE_DIGEST" ]; then',
      r'if [ -z "$na" ] || [ "$na" -lt "$AUTORIDADE_PISO" ]; then',
      r'echo 1 > exit_autancora',
    ]) {
      expect(
        vezesNoPasso(p, literal(l)),
        greaterThanOrEqualTo(1),
        reason: 'o verificador externo do alvo oficial perdeu a linha viva '
            '`$l`: as declarações continuariam escritas e ninguém as leria',
      );
    }
  });

  // =========================================================================
  // 5 — A ORDEM DO CARIMBO E DAS INVOCAÇÕES
  // =========================================================================

  test('o carimbo nasce depois da limpeza e antes de toda suíte protegida',
      () {
    final texto = leitura(kAlvo, 'é quem carimba antes de executar');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    for (final l in <String>[
      kLimpezaDoAlvo,
      kGeraCarimbo,
      kExportaCarimbo,
      kEscrevePorta,
      kEscreveCarimbo,
    ]) {
      expect(
        vezesNoPasso(p, literal(l)),
        1,
        reason: 'o alvo oficial não executa exatamente uma vez `$l`. Produtor '
            'comentado, ausente, duplicado ou em bloco morto deixa a '
            'evidência desta corrida sem origem',
      );
    }
    final iLimpeza = indiceDe(p, literal(kLimpezaDoAlvo));
    final iCarimbo = indiceDe(p, literal(kEscreveCarimbo));
    expect(iLimpeza, lessThan(iCarimbo),
        reason: 'a limpeza da evidência anterior vem DEPOIS do carimbo novo');
    final invocacoes = <int>[
      for (var i = 0; i < p.comandos.length; i++)
        if (kInvocacaoDeSuite.hasMatch(p.comandos[i])) i,
    ];
    expect(invocacoes, isNotEmpty,
        reason: 'o passo das suítes não invoca suíte nenhuma');
    expect(
      invocacoes.first,
      greaterThan(iCarimbo),
      reason: 'a primeira invocação de suíte está na posição '
          '${invocacoes.first} e o carimbo na $iCarimbo. A OS 29-R5 mediu '
          'exatamente este gesto: o carimbo movido UMA linha para depois das '
          'suítes deixa-o mais novo que os logs, e a comparação que denuncia '
          'evidência reapresentada inverte de sinal — a metade de evidência '
          'inteira desliga sem nada ficar vermelho',
    );
  });

  test('a âncora roda depois das duas metades que ela lê', () {
    final texto = leitura(kAlvo, 'é quem ordena as invocações');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    final iGuarda =
        indiceDe(p, RegExp('^roda +$kChaveDaGuarda +' + RegExp.escape(kGuarda) + r'$'));
    final iProtegida = indiceDe(p,
        RegExp('^exige +$kChaveDaProtegida +' + RegExp.escape(kProtegida) + r'$'));
    final iAncora =
        indiceDe(p, RegExp('^exige +$kChaveDaAncora +' + RegExp.escape(kAncora) + r'$'));
    for (final par in <List<Object>>[
      <Object>[kChaveDaGuarda, iGuarda],
      <Object>[kChaveDaProtegida, iProtegida],
      <Object>[kChaveDaAncora, iAncora],
    ]) {
      expect(par[1], greaterThanOrEqualTo(0),
          reason: 'o gate ${par[0]} não é invocado no passo das suítes');
    }
    expect(iAncora, greaterThan(iGuarda),
        reason: 'a âncora lê o log de $kChaveDaGuarda e é invocada antes dele');
    expect(iAncora, greaterThan(iProtegida),
        reason: 'a âncora lê o log de $kChaveDaProtegida e é invocada antes '
            'dele');
  });

  // =========================================================================
  // 6 — A RECIPROCIDADE
  // =========================================================================

  test('a âncora guarda esta autoridade de volta, e pelo conteúdo', () {
    final ancora = leitura(kAncora, 'é a âncora');
    for (final agulha in <String>[
      kEstaAutoridade,
      'kDigestDoCodigoDaAutoridade',
      'kCasosDaAutoridadeExterna',
      'AUTORIDADE_DIGEST',
      'AUTORIDADE_PISO',
      kContratoDestaAutoridade,
    ]) {
      expect(
        ancora,
        contains(agulha),
        reason: 'a âncora deixou de nomear "$agulha": esta autoridade '
            'passaria a ser um nó que ninguém guarda, e remover, esvaziar ou '
            'recarimbar ela sairia verde. Uma autoridade que não é guardada '
            'de volta é o mesmo residual deslocado um arquivo adiante',
      );
    }
    final esta = leitura(kEstaAutoridade, 'é esta autoridade');
    expect(
      naoTriviaisDe(esta).length,
      greaterThanOrEqualTo(40),
      reason: 'esta autoridade ficou com ${naoTriviaisDe(esta).length} '
          'afirmações que olham para o programa: ela mesma virou casca',
    );
  });

  // =========================================================================
  // 7 — OS DOIS CONTRATOS E AS DUAS CAMPANHAS
  // =========================================================================

  test('os dois contratos estão na árvore e declaram as duas campanhas', () {
    final daAncora = leitura(
      '../$kContratoDaAncora',
      'é o contrato da âncora, e é onde a campanha da OS 29-C6 está '
          'registrada',
    );
    final desta = leitura(
      '../$kContratoDestaAutoridade',
      'é o contrato desta autoridade, e é onde a campanha da OS 29-C7 está '
          'registrada',
    );
    conferirCampanha(
        daAncora, 'C6', kVetoresDaC6, kControlesDaC6, 'o contrato da âncora');
    conferirCampanha(desta, 'C7', kVetoresDaC7, kControlesDaC7,
        'o contrato desta autoridade');
    for (final t in <String>[
      kAncora,
      kEstaAutoridade,
      kChaveDaAncora,
      kChaveDestaAutoridade,
      kComandoVivoDoApk,
      '$kPisoDoApk',
    ]) {
      expect(
        desta,
        contains(t),
        reason: 'o contrato desta autoridade deixou de registrar "$t"',
      );
    }
  });

  // =========================================================================
  // 8 — A PORTA DESTA EXECUÇÃO
  // =========================================================================

  test('esta execução veio por uma das duas portas, com carimbo desta corrida',
      () {
    final porta = portaDestaExecucao();
    final alvo = passo(
        leitura(kAlvo, 'é a primeira porta'), kPassoDasSuites, 'o alvo oficial');
    final apk =
        passo(leitura(kApk, 'é a segunda porta'), kPassoDoApk, 'o portão do APK');
    expect(
      atribuicaoUnica(alvo, kEnvPorta, 'o alvo oficial'),
      kPortaDoAlvo,
      reason: 'o alvo oficial deixou de se declarar como $kPortaDoAlvo',
    );
    expect(
      atribuicaoUnica(apk, kEnvPorta, 'o portão do APK'),
      kPortaDoApk,
      reason: 'o portão do APK deixou de se declarar como $kPortaDoApk. Se as '
          'duas portas se declarassem iguais, uma delas cobraria de si '
          'evidência que não produz, ou deixaria de cobrar a que produz',
    );
    expect(
      vezesNoPasso(apk, literal(kLimpezaDoApk)),
      1,
      reason: 'o portão do APK perdeu a limpeza da evidência anterior',
    );
    if (porta == kPortaDoAlvo) {
      // Nesta porta as duas metades protegidas já rodaram, e a evidência delas
      // existe. A âncora a cobra inteira; aqui basta que ela EXISTA e seja
      // desta corrida — o que já foi conferido acima pelo carimbo.
      for (final marcador in <String>['../exit_cascaaud', '../exit_mesac1']) {
        expect(
          File(marcador).existsSync(),
          isTrue,
          reason: 'há carimbo do alvo oficial e o marcador $marcador não '
              'existe: o passo não rodou',
        );
        expect(
          File(marcador).readAsStringSync().trim(),
          '0',
          reason: 'o marcador $marcador não saiu zero',
        );
      }
      expect(
        placarDo(leitura('../t_cascaaud.log', 'é o log de cascaaud')),
        greaterThanOrEqualTo(28),
        reason: 'o gate cascaaud fechou abaixo do piso de 28',
      );
      expect(
        placarDo(leitura('../t_mesac1.log', 'é o log de mesac1')),
        greaterThanOrEqualTo(31),
        reason: 'o gate mesac1 fechou abaixo do piso de 31',
      );
      return;
    }
    // Na porta do APK as duas metades rodam nesta mesma invocação, ao lado
    // desta autoridade: não há log delas para ler. O que se cobra é o piso da
    // execução que está acontecendo, e ele é cobrado nominalmente.
    expect(
      atribuicaoUnica(apk, 'APK_PISO', 'o portão do APK'),
      '$kPisoDoApk',
      reason: 'esta execução veio pelo portão do APK e o piso dele não é '
          '$kPisoDoApk',
    );
  });
}
