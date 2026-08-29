// suites_obrigatorias_test.dart — a guarda de INSTRUMENTAÇÃO do CI, na máquina
// de quem edita, e a autoridade EXTERNA sobre o piso de toque e sobre o
// conteúdo da suíte de alvos de Amigos.
//
// ---------------------------------------------------------------------------
// OS DOIS DEFEITOS QUE ESTE ARQUIVO FECHA
// ---------------------------------------------------------------------------
//
// (1) O DESLIGAMENTO SILENCIOSO. O agregador do `ci-os-integracao.yml` roda
// cada suíte por caminho, e o auxiliar `roda` escreve `nao_<chave>` quando o
// arquivo não está lá. O portão trata `nao_<chave>` como NÃO EXECUTADO, e NÃO
// EXECUTADO **não reprova** — o que é a decisão certa para os gates que
// dependem de codebase Firebase que pode não existir na branch em que o CI
// roda, e continua valendo para eles. A conta que sobra é desconfortável:
// `rm test/amigos/a11y_alvos_amigos_test.dart` deixava o run VERDE.
//
// (2) A AUTORIDADE DE DENTRO. `a11y_alvos_amigos_test.dart` guarda o piso de
// 48 pontos e os 75 casos DENTRO de si. Enquanto os dois moram só lá, baixar o
// piso para 40, apagar 74 casos e deixar um trivial, ou mover os nomes para
// comentários é edição de UM arquivo — e a cadeia inteira fica verde, porque
// não existe ninguém de fora para discordar. `test/contrato_alvos_amigos.txt`
// é esse ninguém: ele congela o piso, as 75 identidades em ordem e a impressão
// digital dos corpos, e este arquivo é quem LÊ a suíte e confere se ela ainda
// é o que o contrato diz.
//
// ---------------------------------------------------------------------------
// POR QUE UM ANALISADOR, E NÃO UM `grep`
// ---------------------------------------------------------------------------
//
// Contar `test(` com `grep` é a forma mais fácil de fabricar um verde: os 75
// nomes viram uma lista morta, ou strings dentro de um comentário, e o número
// fecha. O analisador abaixo varre a fonte separando CÓDIGO de comentário e de
// literal, e só aceita como identidade o que for uma CHAMADA `testWidgets(` de
// verdade, dentro do `main`, dentro de um `group`, com nome literal. Nome em
// comentário não conta; nome em string solta não conta; `xtestWidgets(` não
// conta; declaração dentro de função que ninguém chama não conta, porque está
// fora do `main`.
//
// E o nome sozinho não basta: o contrato guarda também a IMPRESSÃO DIGITAL dos
// corpos normalizados. Trocar as afirmações por `expect(true, isTrue)` — mesmo
// mantendo os 75 nomes e a mesma quantidade de `expect` — muda a impressão.
//
// ---------------------------------------------------------------------------
// A PROTEÇÃO CRUZADA COM O SHELL
// ---------------------------------------------------------------------------
//
// `scripts/ci/verificar_suites_obrigatorias.sh` roda no passo 0 e sai com
// código próprio. Trocar o `exit "$falhas"` final dele por `exit 0`, mantendo
// todas as mensagens, deixaria o passo verde com a decisão retirada — e nenhum
// `grep` de mensagem veria isso. Este arquivo confere a IMPRESSÃO DIGITAL da
// região de decisão daquele script; ele confere a deste. As duas impressões
// moram FORA das regiões que medem, senão cada edição mudaria o que a outra
// mede e o par nunca fecharia.
//
// E este arquivo confere o PASSO no workflow: nome, comando vivo, posição
// antes das suítes protegidas e consumo do código de saída. Substituir a
// invocação por `true` reprova aqui.
//
// ---------------------------------------------------------------------------
// ELE NÃO É A RAIZ DE CONFIANÇA, E ISSO IMPORTA
// ---------------------------------------------------------------------------
//
// Ele roda como gate (`suitesobrig`), então a mesma tolerância se aplica a ele:
// apagá-lo daria NÃO EXECUTADO. Quem fecha esse laço é o passo 0. E se os DOIS
// caírem juntos, quem reclama é `test/amigos/matriz_amigos_test.dart`, que roda
// como gate próprio e exige a existência dos dois. São três pernas, e derrubar
// duas quaisquer ainda deixa a terceira de pé.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// OS CARIMBOS
// ===========================================================================
//
// Vivem FORA da região de decisão, e a razão é aritmética: o shell mede a
// região de decisão DESTE arquivo, e este arquivo mede a do shell. Se os
// carimbos morassem dentro das regiões, atualizar um mudaria o que o outro
// mede, e o par nunca fecharia.
//
// Eles são a SEGUNDA cópia do contrato. Baixar o piso exige mexer no contrato,
// aqui e no shell — três arquivos, duas naturezas de autoridade.

/// O manifesto, relativo à raiz do app.
///
/// `flutter test` roda com a raiz do app como diretório corrente — `app_build`
/// no CI, `app` num checkout normal —, então o caminho vale nos dois.
const _manifesto = 'test/suites_obrigatorias.txt';

/// O contrato externo dos alvos de Amigos.
const _contrato = 'test/contrato_alvos_amigos.txt';

/// A suíte que o contrato descreve.
const _suiteDeAlvos = 'test/amigos/a11y_alvos_amigos_test.dart';

/// O piso de DECLARAÇÕES das suítes que esta OS trouxe para o portão.
///
/// Registrar no manifesto impede que elas sumam; estes números impedem a outra
/// metade do ataque, que é a suíte ficar no lugar, com o mesmo nome e o mesmo
/// caminho, e esvaziar por dentro. Sem eles, `matriz_amigos_test.dart` podia
/// virar um `expect(1, 1)` sem que nada mudasse de cor.
///
/// Eles são PISO, e não igualdade: crescer é livre, encolher é decisão.
const _pisosDeDeclaracao = <String, int>{
  'test/casca/homologacao_casca_v2_test.dart': 13,
  'test/amigos/matriz_amigos_test.dart': 24,
};

/// O verificador do passo 0. Um nível acima da raiz do app, nas duas árvores.
const _verificador = '../scripts/ci/verificar_suites_obrigatorias.sh';

/// O workflow que roda os gates.
const _workflow = '../.github/workflows/ci-os-integracao.yml';

/// As entradas que esta OS declarou obrigatórias, escritas AQUI.
///
/// Sem isto, esvaziar `suites_obrigatorias.txt` seria uma saída silenciosa: o
/// arquivo continuaria existindo, bem formado, e não guardaria mais nada. O
/// manifesto pode CRESCER com decisões futuras; encolher abaixo destas linhas é
/// o que este caso proíbe.
const _minimas = <String, String>{
  'a11yamigos': 'test/amigos/a11y_alvos_amigos_test.dart',
  'matrizamigos': 'test/amigos/matriz_amigos_test.dart',
  'cascav2': 'test/casca/homologacao_casca_v2_test.dart',
  'suitesobrig': 'test/ci/suites_obrigatorias_test.dart',
};

/// O piso de toque, em pontos lógicos, como a suíte deve declará-lo.
const _pisoCarimbado = '48.0';

/// Quantas identidades de caso a suíte produz.
const _casosCarimbados = 75;

/// Quantos SÍTIOS `testWidgets(` existem na fonte. Menor que 75 porque cinco
/// deles vivem em laços sobre as dez cenas.
const _declaracoesCarimbadas = 30;

/// Quantas vezes a suíte compara área medida com o piso.
///
/// Um piso declarado e nunca comparado é decoração; este número é o que impede
/// que as comparações sumam uma a uma sem ninguém notar.
const _comparacoesCarimbadas = 17;

/// Quantos `expect(` os corpos dos 30 sítios somam.
const _afirmacoesCarimbadas = 71;

/// A impressão digital das 75 identidades e dos 30 corpos normalizados.
const _digestCarimbado =
    'f5f1d3879b9a5745b364298114eb8a911e474b1325163d72e89b24b6652e3ad6';

/// A impressão digital da região de decisão do verificador shell.
const _digestDecisaoVerificador =
    '89db79124a609052111bdb8a5c6013c429a6e4eb2bb38720f102c75f4c7d350f';

const _marcaInicioShell = '# ---8<--- DECISAO INICIO';
const _marcaFimShell = '# ---8<--- DECISAO FIM';

/// O passo que invoca o verificador, e o passo que roda as suítes protegidas.
const _nomeDoPassoZero =
    '0 — suítes obrigatórias presentes (falha FECHADA, antes dos gates)';
const _nomeDoPassoDasSuites =
    '1+2 — analyze + suítes Flutter (captura exit codes sem abortar)';
const _invocacaoDoPassoZero =
    'bash scripts/ci/verificar_suites_obrigatorias.sh app_build '
    '.github/workflows/ci-os-integracao.yml 2>&1 | tee t_suites.log';

// ---8<--- DECISAO INICIO

// ===========================================================================
// Leitura de arquivo, sempre normalizada
// ===========================================================================

/// O conteúdo de [caminho] com os `\r` fora.
///
/// O repositório é editado no Windows, onde o checkout grava CRLF; o CI roda no
/// Linux, onde não. Sem normalizar, toda impressão digital daria dois valores
/// conforme a máquina, e o shell — que também tira o `\r` — discordaria daqui.
String _ler(String caminho) {
  final arquivo = File(caminho);
  if (!arquivo.existsSync()) {
    throw StateError(
      'arquivo ausente: "$caminho" (corrente: ${Directory.current.path})',
    );
  }
  return arquivo.readAsStringSync().replaceAll('\r', '');
}

/// As linhas ENTRE [inicio] e [fim], sem as próprias marcas.
///
/// Junta com `\n` e termina com `\n`, que é exatamente o que o `awk` do shell
/// entrega ao `sha256sum`.
String _regiao(String conteudo, String inicio, String fim) {
  final linhas = conteudo.split('\n');
  final dentro = <String>[];
  var ligado = false;
  for (final l in linhas) {
    if (!ligado) {
      if (l.contains(inicio)) ligado = true;
      continue;
    }
    if (l.contains(fim)) break;
    dentro.add(l);
  }
  if (dentro.isEmpty) return '';
  return '${dentro.join('\n')}\n';
}

String _impressao(String texto) =>
    sha256.convert(utf8.encode(texto)).toString();

// ===========================================================================
// O analisador da suíte
// ===========================================================================

/// Um literal de string encontrado na fonte.
class _Literal {
  const _Literal(this.inicio, this.fim, this.conteudo);

  /// Índice da primeira aspa.
  final int inicio;

  /// Índice logo depois da última aspa.
  final int fim;

  /// O texto ENTRE as aspas, cru — a interpolação continua escrita.
  final String conteudo;
}

bool _ehIdent(String c) =>
    RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// A fonte de um arquivo Dart, separada em código, comentário e literal.
///
/// É o que separa "o nome do caso está declarado" de "o nome do caso está
/// escrito em algum lugar do arquivo".
class _FonteDart {
  _FonteDart(this.texto) {
    comentario = List<bool>.filled(texto.length, false);
    literal = List<bool>.filled(texto.length, false);
    var i = 0;
    while (i < texto.length) {
      final c = texto[i];
      final proximo = i + 1 < texto.length ? texto[i + 1] : '';

      if (c == '/' && proximo == '/') {
        while (i < texto.length && texto[i] != '\n') {
          comentario[i] = true;
          i++;
        }
        continue;
      }
      if (c == '/' && proximo == '*') {
        var prof = 0;
        while (i < texto.length) {
          final a = texto[i];
          final b = i + 1 < texto.length ? texto[i + 1] : '';
          if (a == '/' && b == '*') {
            prof++;
            comentario[i] = comentario[i + 1] = true;
            i += 2;
            continue;
          }
          if (a == '*' && b == '/') {
            prof--;
            comentario[i] = comentario[i + 1] = true;
            i += 2;
            if (prof == 0) break;
            continue;
          }
          comentario[i] = true;
          i++;
        }
        continue;
      }
      if (c == "'" || c == '"' || (c == 'r' && (proximo == "'" || proximo == '"'))) {
        i = _lerLiteral(i);
        continue;
      }
      i++;
    }
  }

  final String texto;
  late final List<bool> comentario;
  late final List<bool> literal;
  final List<_Literal> literais = [];

  bool ehCodigo(int i) => !comentario[i] && !literal[i];

  /// Lê um literal a partir de [inicio] e devolve o índice logo após ele.
  int _lerLiteral(int inicio) {
    var i = inicio;
    final cru = texto[i] == 'r';
    if (cru) i++;
    final aspa = texto[i];
    final triplo =
        i + 2 < texto.length && texto[i + 1] == aspa && texto[i + 2] == aspa;
    final delim = triplo ? aspa * 3 : aspa;
    final abre = i + delim.length;
    var j = abre;
    while (j < texto.length) {
      if (!cru && texto[j] == r'\') {
        j += 2;
        continue;
      }
      if (!cru && texto[j] == r'$') {
        // Interpolação. `${...}` pode conter literais aninhados, então a
        // profundidade de chaves é contada e as strings de dentro são puladas
        // pelo mesmo leitor. Sem isso, um `'${m['k']}'` fecharia a string na
        // aspa errada e todo o resto do arquivo viraria literal.
        if (j + 1 < texto.length && texto[j + 1] == '{') {
          var prof = 0;
          var k = j + 1;
          while (k < texto.length) {
            final c = texto[k];
            if (c == '{') {
              prof++;
              k++;
              continue;
            }
            if (c == '}') {
              prof--;
              k++;
              if (prof == 0) break;
              continue;
            }
            if (c == "'" || c == '"') {
              k = _pularLiteralSimples(k);
              continue;
            }
            k++;
          }
          j = k;
          continue;
        }
        j++;
        continue;
      }
      if (texto.startsWith(delim, j)) {
        final fim = j + delim.length;
        for (var k = inicio; k < fim; k++) {
          literal[k] = true;
        }
        literais.add(_Literal(inicio, fim, texto.substring(abre, j)));
        return fim;
      }
      j++;
    }
    // Literal sem fecho: o arquivo está quebrado, e o compilador dirá isso
    // antes de qualquer caso rodar.
    for (var k = inicio; k < texto.length; k++) {
      literal[k] = true;
    }
    return texto.length;
  }

  /// Pula um literal simples de dentro de uma interpolação, sem registrá-lo.
  int _pularLiteralSimples(int inicio) {
    final aspa = texto[inicio];
    var j = inicio + 1;
    while (j < texto.length) {
      if (texto[j] == r'\') {
        j += 2;
        continue;
      }
      if (texto[j] == aspa) return j + 1;
      j++;
    }
    return texto.length;
  }

  /// Cada chamada `nome(` que é CÓDIGO de verdade: onde o nome começa e onde
  /// abre o parêntese dos argumentos.
  ///
  /// A vizinhança importa: `xtestWidgets(` e `meuGroup(` NÃO entram, porque o
  /// caractere anterior é de identificador. É o que separa uma declaração de
  /// caso de uma chamada parecida que não declara nada.
  List<({int inicio, int paren})> sitiosDeChamada(String nome) {
    final saida = <({int inicio, int paren})>[];
    var i = texto.indexOf(nome);
    while (i >= 0) {
      final antes = i == 0 ? ' ' : texto[i - 1];
      var p = i + nome.length;
      while (p < texto.length && texto[p].trim().isEmpty) {
        p++;
      }
      if (ehCodigo(i) &&
          !_ehIdent(antes) &&
          p < texto.length &&
          texto[p] == '(') {
        saida.add((inicio: i, paren: p));
      }
      i = texto.indexOf(nome, i + 1);
    }
    return saida;
  }

  /// O índice do fecho que casa com o [abre] em [aberto]/[fechado].
  int casarPar(int abre, String aberto, String fechado) {
    var prof = 0;
    for (var i = abre; i < texto.length; i++) {
      if (!ehCodigo(i)) continue;
      if (texto[i] == aberto) prof++;
      if (texto[i] == fechado) {
        prof--;
        if (prof == 0) return i;
      }
    }
    throw StateError('par "$aberto$fechado" sem fecho a partir de $abre');
  }

  /// O primeiro literal que começa depois de [pos], pulando espaço em branco.
  _Literal literalLogoApos(int pos) {
    var i = pos;
    while (i < texto.length && texto[i].trim().isEmpty) {
      i++;
    }
    for (final l in literais) {
      if (l.inicio == i) return l;
    }
    throw StateError(
      'o argumento em $pos não é um literal de string: '
      '"${texto.substring(pos, (pos + 40).clamp(0, texto.length))}"',
    );
  }

  /// [trecho] sem comentários e com o espaço em branco colapsado.
  String normalizar(int inicio, int fim) {
    final buf = StringBuffer();
    for (var i = inicio; i < fim; i++) {
      if (comentario[i]) continue;
      buf.write(texto[i]);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Um sítio `testWidgets(` da fonte.
class _Sitio {
  _Sitio(this.inicio, this.fimArgs, this.nome, this.corpo, this.afirmacoes);
  final int inicio;
  final int fimArgs;
  final String nome;
  final String corpo;
  final int afirmacoes;
}

/// O que o analisador extraiu da suíte.
class _Leitura {
  _Leitura({
    required this.piso,
    required this.identidades,
    required this.corpos,
    required this.afirmacoes,
    required this.comparacoes,
    required this.cenas,
  });

  final String piso;
  final List<String> identidades;
  final List<String> corpos;
  final int afirmacoes;
  final int comparacoes;
  final List<String> cenas;

  /// A entrada da impressão digital.
  ///
  /// Nome E corpo. Só os nomes deixariam passar a trivialização que preserva a
  /// lista; só os corpos deixariam passar a troca de nomes.
  String get material {
    final buf = StringBuffer()
      ..writeln('piso=$piso')
      ..writeln('declaracoes=${corpos.length}')
      ..writeln('casos=${identidades.length}');
    for (final i in identidades) {
      buf.writeln(i);
    }
    buf.writeln('--');
    for (final c in corpos) {
      buf.writeln(c);
    }
    return buf.toString();
  }
}

_Leitura _analisar(String caminho) {
  final f = _FonteDart(_ler(caminho));

  // O `main`, e o que está fora dele não conta.
  final sitiosMain = f.sitiosDeChamada('main');
  if (sitiosMain.isEmpty) {
    throw StateError('"$caminho" não declara `main`');
  }
  final aberturaMain = f.casarPar(sitiosMain.first.paren, '(', ')');
  var i = aberturaMain + 1;
  while (i < f.texto.length && f.texto[i] != '{') {
    i++;
  }
  final corpoMainInicio = i;
  final corpoMainFim = f.casarPar(corpoMainInicio, '{', '}');

  bool dentroDoMain(int p) => p > corpoMainInicio && p < corpoMainFim;

  // As cenas, lidas do mapa `final cenas = <...>{ 'chave': fn, ... }`.
  //
  // A AUSÊNCIA DO MAPA NÃO É ERRO AQUI, e a distinção custou uma volta. Uma
  // suíte trocada por um caso trivial não tem mapa nenhum; estourar por isso
  // trocaria o veredito que interessa — "a suíte declara 1 identidade e o
  // contrato exige 75" — por um erro de leitura que não diz o que sumiu. Quem
  // cobra o mapa é o LAÇO: se existe um `for` sobre `cenas.entries` e não
  // existem cenas, aí sim a fonte é incoerente, e o erro diz isso.
  final cenas = <String>[];
  final posCenas = f.texto.indexOf('final cenas');
  if (posCenas >= 0 && f.ehCodigo(posCenas)) {
    var j = posCenas;
    while (j < f.texto.length && !(f.texto[j] == '{' && f.ehCodigo(j))) {
      j++;
    }
    final mapaInicio = j;
    final mapaFim = f.casarPar(mapaInicio, '{', '}');
    for (final l in f.literais) {
      if (l.inicio <= mapaInicio || l.fim >= mapaFim) continue;
      var k = l.fim;
      while (k < f.texto.length && f.texto[k].trim().isEmpty) {
        k++;
      }
      if (k < f.texto.length && f.texto[k] == ':') cenas.add(l.conteudo);
    }
  }

  // Os grupos.
  final grupos = <({String nome, int inicio, int fim})>[];
  for (final g in f.sitiosDeChamada('group')) {
    if (!dentroDoMain(g.inicio)) continue;
    grupos.add((
      nome: f.literalLogoApos(g.paren + 1).conteudo,
      inicio: g.inicio,
      fim: f.casarPar(g.paren, '(', ')'),
    ));
  }

  // Os laços sobre as cenas.
  final lacos = <({int inicio, int fim})>[];
  for (final p in f.sitiosDeChamada('for')) {
    final abre = f.casarPar(p.paren, '(', ')');
    if (f.normalizar(p.paren + 1, abre) != 'final cena in cenas.entries') {
      continue;
    }
    var k = abre + 1;
    while (k < f.texto.length && f.texto[k] != '{') {
      k++;
    }
    lacos.add((inicio: k, fim: f.casarPar(k, '{', '}')));
  }

  // Os sítios de declaração.
  final expects = f.sitiosDeChamada('expect');
  final sitios = <_Sitio>[];
  for (final t in f.sitiosDeChamada('testWidgets')) {
    if (!dentroDoMain(t.inicio)) {
      throw StateError(
        'há um `testWidgets(` fora do `main` em "$caminho" (posição '
        '${t.inicio}): declaração que ninguém executa não é caso',
      );
    }
    final fecha = f.casarPar(t.paren, '(', ')');
    sitios.add(
      _Sitio(
        t.inicio,
        fecha,
        f.literalLogoApos(t.paren + 1).conteudo,
        f.normalizar(t.paren + 1, fecha),
        expects.where((e) => e.inicio > t.paren && e.inicio < fecha).length,
      ),
    );
  }

  // A expansão, na ordem em que o executor as produz: dentro de cada grupo, os
  // itens em ordem de fonte; e dentro de um laço, CENA por fora e declaração
  // por dentro — que é a ordem do corpo do laço, e não a ordem dos sítios.
  final identidades = <String>[];
  for (final g in grupos) {
    final doGrupo = sitios
        .where((s) => s.inicio > g.inicio && s.inicio < g.fim)
        .toList();
    final lacosDoGrupo = lacos
        .where((l) => l.inicio > g.inicio && l.inicio < g.fim)
        .toList();
    final itens = <({int pos, List<_Sitio> sitios, bool porCena})>[];
    for (final s in doGrupo) {
      final laco = lacosDoGrupo
          .where((l) => s.inicio > l.inicio && s.inicio < l.fim)
          .toList();
      if (laco.isEmpty) {
        itens.add((pos: s.inicio, sitios: [s], porCena: false));
      }
    }
    for (final l in lacosDoGrupo) {
      final dentro = doGrupo
          .where((s) => s.inicio > l.inicio && s.inicio < l.fim)
          .toList();
      if (dentro.isEmpty) continue;
      itens.add((pos: l.inicio, sitios: dentro, porCena: true));
    }
    itens.sort((a, b) => a.pos.compareTo(b.pos));
    for (final item in itens) {
      if (!item.porCena) {
        final s = item.sitios.single;
        if (s.nome.contains(r'${')) {
          throw StateError('o caso "${s.nome}" interpola fora de um laço');
        }
        identidades.add('${g.nome} ${s.nome}');
        continue;
      }
      if (cenas.isEmpty) {
        throw StateError(
          'há um laço sobre `cenas.entries` em "$caminho" e o mapa `cenas` '
          'não foi encontrado — a fonte não fecha consigo mesma',
        );
      }
      for (final cena in cenas) {
        for (final s in item.sitios) {
          if (!s.nome.contains(r'${cena.key}')) {
            throw StateError(
              'o caso "${s.nome}" está num laço de cenas e não usa a cena',
            );
          }
          identidades.add(
            '${g.nome} ${s.nome.replaceAll(r'${cena.key}', cena)}',
          );
        }
      }
    }
  }

  // O piso DECLARADO pela suíte.
  final piso = RegExp(r'^const double _piso = ([0-9.]+);$', multiLine: true)
      .firstMatch(f.texto)
      ?.group(1);
  if (piso == null) {
    throw StateError('"$caminho" não declara `const double _piso`');
  }

  var comparacoes = 0;
  var de = f.texto.indexOf('greaterThanOrEqualTo(_piso)');
  while (de >= 0) {
    if (f.ehCodigo(de)) comparacoes++;
    de = f.texto.indexOf('greaterThanOrEqualTo(_piso)', de + 1);
  }

  return _Leitura(
    piso: piso,
    identidades: identidades,
    corpos: [for (final s in sitios) s.corpo],
    afirmacoes: sitios.fold(0, (a, s) => a + s.afirmacoes),
    comparacoes: comparacoes,
    cenas: cenas,
  );
}

// ===========================================================================
// O contrato
// ===========================================================================

class _Contrato {
  _Contrato(this.chaves, this.casos);
  final Map<String, String> chaves;
  final List<({String numero, String identidade})> casos;
}

_Contrato _lerContrato() {
  final chaves = <String, String>{};
  final casos = <({String numero, String identidade})>[];
  for (final bruta in _ler(_contrato).split('\n')) {
    final linha = bruta.trimRight();
    if (linha.trim().isEmpty || linha.trimLeft().startsWith('#')) continue;
    final caso = RegExp(r'^caso (\d\d) (.+)$').firstMatch(linha);
    if (caso != null) {
      casos.add((numero: caso.group(1)!, identidade: caso.group(2)!));
      continue;
    }
    final campos = linha.split(RegExp(r'\s+'));
    if (campos.length != 2) {
      throw StateError('linha malformada no contrato: "$bruta"');
    }
    if (chaves.containsKey(campos[0])) {
      throw StateError('chave repetida no contrato: "${campos[0]}"');
    }
    chaves[campos[0]] = campos[1];
  }
  return _Contrato(chaves, casos);
}

// ===========================================================================
// O manifesto
// ===========================================================================

typedef _Entrada = ({String chave, String caminho, String bruta});

List<_Entrada> _lerManifesto() {
  final saida = <_Entrada>[];
  for (final bruta in _ler(_manifesto).split('\n')) {
    final linha = bruta.trim();
    if (linha.isEmpty || linha.startsWith('#')) continue;
    final campos = linha.split(RegExp(r'\s+'));
    if (campos.length != 2) {
      throw StateError('linha malformada no manifesto: "$bruta"');
    }
    saida.add((chave: campos[0], caminho: campos[1], bruta: bruta));
  }
  return saida;
}

// ===========================================================================
// O workflow
// ===========================================================================

/// As linhas de um passo `- name: <nome>`, até o começo do passo seguinte.
({int indice, List<String> linhas}) _passo(List<String> linhas, String nome) {
  final abre = RegExp(r'^\s*- name:\s*"?(.*?)"?\s*$');
  var indice = -1;
  for (var i = 0; i < linhas.length; i++) {
    final m = abre.firstMatch(linhas[i]);
    if (m != null && m.group(1) == nome) {
      indice = i;
      break;
    }
  }
  if (indice < 0) {
    throw StateError('o workflow não tem mais o passo "$nome"');
  }
  final corpo = <String>[];
  for (var i = indice + 1; i < linhas.length; i++) {
    if (abre.hasMatch(linhas[i]) || RegExp(r'^\s*- uses:').hasMatch(linhas[i])) {
      break;
    }
    corpo.add(linhas[i]);
  }
  return (indice: indice, linhas: corpo);
}

void main() {
  group('as suítes obrigatórias continuam no disco', () {
    test('S1 — o manifesto existe e tem entradas', () {
      expect(
        _lerManifesto(),
        isNotEmpty,
        reason: 'a lista de suítes obrigatórias foi esvaziada',
      );
    });

    test('S2 — cada entrada do manifesto aponta para um arquivo que existe', () {
      for (final e in _lerManifesto()) {
        expect(
          File(e.caminho).existsSync(),
          isTrue,
          reason:
              'a suíte obrigatória "${e.caminho}" (gate ${e.chave}) foi '
              'removida ou renomeada. No CI ela viraria NÃO EXECUTADO, que o '
              'portão não reprova — é exatamente esse silêncio que este caso '
              'existe para quebrar.',
        );
      }
    });

    test('S3 — o manifesto não encolheu abaixo do mínimo desta OS', () {
      final mapa = {for (final e in _lerManifesto()) e.chave: e.caminho};
      for (final m in _minimas.entries) {
        expect(
          mapa[m.key],
          m.value,
          reason:
              'o gate "${m.key}" saiu do manifesto, ou mudou de caminho sem '
              'que este caso fosse atualizado junto',
        );
      }
    });

    test('S4 — nenhuma chave repetida', () {
      final chaves = _lerManifesto().map((e) => e.chave).toList();
      expect(
        chaves.toSet(),
        hasLength(chaves.length),
        reason: 'chave duplicada no manifesto: $chaves',
      );
    });

    test('S5 — as suítes obrigatórias são arquivos de teste de verdade', () {
      // Um caminho que não termina em `_test.dart` não é descoberto pelo
      // `flutter test`, e apontar o manifesto para um arquivo qualquer seria
      // uma forma de manter a lista cheia com a suíte desligada.
      for (final e in _lerManifesto()) {
        expect(
          e.caminho.endsWith('_test.dart'),
          isTrue,
          reason: '"${e.caminho}" não é uma suíte (gate ${e.chave})',
        );
        expect(
          File(e.caminho).readAsStringSync(),
          contains('void main('),
          reason: '"${e.caminho}" não declara `main` (gate ${e.chave})',
        );
      }
    });
  });

  group('o contrato externo dos alvos de Amigos', () {
    test('C1 — o contrato existe e concorda com o carimbo desta guarda', () {
      final c = _lerContrato();
      expect(
        c.chaves['piso'],
        _pisoCarimbado,
        reason: 'o piso do contrato saiu de $_pisoCarimbado',
      );
      expect(c.chaves['suite'], _suiteDeAlvos);
      expect(c.chaves['casos'], '$_casosCarimbados');
      expect(c.chaves['declaracoes'], '$_declaracoesCarimbadas');
      expect(c.chaves['comparacoes'], '$_comparacoesCarimbadas');
      expect(c.chaves['afirmacoes'], '$_afirmacoesCarimbadas');
      expect(
        c.chaves['digest'],
        _digestCarimbado,
        reason:
            'a impressão dos casos foi recarimbada no contrato sem passar por '
            'esta guarda — recarimbar em um arquivo só é exatamente o que a '
            'autoridade externa existe para impedir',
      );
    });

    test('C2 — as 75 identidades estão numeradas, em ordem e sem repetição', () {
      final c = _lerContrato();
      expect(c.casos, hasLength(_casosCarimbados));
      expect(
        [for (final x in c.casos) x.numero],
        [for (var i = 1; i <= _casosCarimbados; i++) '$i'.padLeft(2, '0')],
      );
      final nomes = [for (final x in c.casos) x.identidade];
      expect(
        nomes.toSet(),
        hasLength(nomes.length),
        reason: 'o contrato repete uma identidade',
      );
    });

    test('C3 — a suíte declara o piso que o contrato contratou', () {
      final l = _analisar(_suiteDeAlvos);
      expect(
        l.piso,
        _pisoCarimbado,
        reason:
            'a suíte declara `_piso = ${l.piso}` e o contrato exige '
            '$_pisoCarimbado — baixar o piso dentro da suíte deixou de ser '
            'uma edição de um arquivo só',
      );
      expect(l.piso, _lerContrato().chaves['piso']);
    });

    test('C4 — o piso é COMPARADO, e não só declarado', () {
      // Um piso escrito e nunca usado é decoração. Este número é o que impede
      // que as comparações sumam uma a uma.
      expect(_analisar(_suiteDeAlvos).comparacoes, _comparacoesCarimbadas);
    });

    test('C5 — a suíte declara exatamente as 75 identidades do contrato', () {
      final l = _analisar(_suiteDeAlvos);
      expect(
        l.identidades,
        [for (final x in _lerContrato().casos) x.identidade],
        reason:
            'as identidades executáveis da suíte não são mais as do contrato: '
            'alguma foi removida, renomeada, duplicada ou mudou de posição',
      );
    });

    test('C6 — a contagem de sítios e de afirmações não encolheu', () {
      final l = _analisar(_suiteDeAlvos);
      expect(
        l.corpos,
        hasLength(_declaracoesCarimbadas),
        reason: 'a suíte deixou de ter $_declaracoesCarimbadas declarações',
      );
      expect(
        l.afirmacoes,
        _afirmacoesCarimbadas,
        reason: 'os corpos dos casos deixaram de somar as mesmas afirmações',
      );
      for (final corpo in l.corpos) {
        expect(
          corpo,
          contains('expect('),
          reason: 'há um caso sem nenhuma afirmação: ${corpo.substring(0, 60)}',
        );
      }
    });

    test('C7 — a impressão digital dos nomes E dos corpos bate', () {
      final l = _analisar(_suiteDeAlvos);
      final impressao = _impressao(l.material);
      expect(
        impressao,
        _digestCarimbado,
        reason:
            'o conteúdo material da suíte mudou. Trocar as afirmações por '
            'triviais, mesmo mantendo os 75 nomes e a mesma contagem de '
            '`expect`, cai aqui.',
      );
      expect(impressao, _lerContrato().chaves['digest']);
    });

    test('C8 — as dez cenas continuam sendo dez', () {
      expect(_analisar(_suiteDeAlvos).cenas, hasLength(10));
    });
  });

  group('a instrumentação do CI continua com corpo e com decisão', () {
    test('I1 — o verificador shell existe e sua decisão não foi mexida', () {
      final regiao = _regiao(
        _ler(_verificador),
        _marcaInicioShell,
        _marcaFimShell,
      );
      expect(
        regiao,
        isNotEmpty,
        reason:
            'a região de decisão do verificador sumiu — um script que só '
            'imprime mensagens e não decide nada é pior que nenhum script',
      );
      expect(
        regiao,
        contains('exit "\$falhas"'),
        reason: 'o verificador não sai mais com o próprio veredito',
      );
      expect(
        _impressao(regiao),
        _digestDecisaoVerificador,
        reason:
            'o corpo do verificador mudou. Trocar o `exit "\$falhas"` final '
            'por `exit 0`, mantendo todas as mensagens, cai aqui — e é por '
            'isso que a impressão é do CORPO, e não de uma frase dele.',
      );
    });

    test('I2 — o passo 0 existe, com o comando vivo e antes das suítes', () {
      final linhas = _ler(_workflow).split('\n');
      final zero = _passo(linhas, _nomeDoPassoZero);
      final suites = _passo(linhas, _nomeDoPassoDasSuites);

      expect(
        zero.indice,
        lessThan(suites.indice),
        reason:
            'o passo 0 deixou de vir antes das suítes protegidas — verificar '
            'depois de rodar é verificar tarde',
      );

      final vivas = zero.linhas
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(
        vivas,
        contains(_invocacaoDoPassoZero),
        reason:
            'a invocação do verificador não está viva no passo 0. Trocá-la '
            'por `true`, por um `echo` ou comentá-la cai aqui.',
      );
      expect(
        vivas.where((l) => l == 'true' || l == ':'),
        isEmpty,
        reason: 'há um comando inerte no lugar da decisão do passo 0',
      );
      expect(
        vivas.where((l) => l.contains('verificar_suites_obrigatorias.sh')),
        hasLength(1),
        reason:
            'o passo 0 invoca o verificador mais de uma vez — uma segunda '
            'invocação inerte esconde qual delas decide',
      );
      expect(
        vivas.where((l) => l.startsWith('st=')),
        contains('st=\${PIPESTATUS[0]}'),
        reason: 'o passo 0 não captura mais o código de saída do verificador',
      );
      expect(
        vivas,
        contains('exit "\$st"'),
        reason:
            'o passo 0 não consome mais o código de saída — registrar o exit '
            'numa variável e não sair com ele é o mesmo que não verificar',
      );
      // E o verificador é invocado UMA vez no workflow inteiro: uma segunda
      // invocação em outro passo confundiria quem procura a decisão.
      expect(
        linhas.where((l) => l.contains('verificar_suites_obrigatorias.sh')),
        hasLength(1),
      );
    });

    test('I4 — as suítes que entraram no portão não esvaziaram por dentro', () {
      // ---------------------------------------------------------------
      // POR QUE ESTE CASO EXISTE
      // ---------------------------------------------------------------
      //
      // `homologacao_casca_v2_test.dart` existia, passava e NÃO ERA GATE: uma
      // matriz de homologação inteira podia ficar vermelha sem que o run
      // mudasse de cor. Entrar no manifesto resolve a remoção silenciosa; o
      // piso resolve a outra metade, que é a suíte continuar no lugar e por
      // dentro virar um caso só. Vale igual para a matriz responsiva.
      for (final p in _pisosDeDeclaracao.entries) {
        final f = _FonteDart(_ler(p.key));
        final declaracoes =
            f.sitiosDeChamada('testWidgets').length +
            f.sitiosDeChamada('test').length;
        expect(
          declaracoes,
          greaterThanOrEqualTo(p.value),
          reason:
              '"${p.key}" caiu para $declaracoes declarações; o piso desta OS '
              'é ${p.value}',
        );
      }
    });

    test('I3 — cada suíte obrigatória está registrada nas três listas', () {
      // O mesmo que o shell confere, em Dart: assim a desincronia entre
      // manifesto e workflow aparece em `flutter test`, sem esperar o Actions.
      final linhas = _ler(_workflow).split('\n');
      // O alinhamento em colunas do workflow é cosmético: `roda cascav2` tem
      // quatro espaços e `roda matrizamigos` tem um. Comparar sem colapsar o
      // branco faria a guarda reprovar por estética.
      final normalizadas = linhas
          .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
          .toList();
      for (final e in _lerManifesto()) {
        expect(
          normalizadas,
          contains('roda ${e.chave} ${e.caminho}'),
          reason: 'o workflow não roda a suíte obrigatória "${e.chave}"',
        );
        // TODAS as linhas que começam assim, e não a primeira. O passo da
        // evidência tem dois `for k in $GATES`, e eles vêm ANTES da lista
        // nominal do portão: olhar só a primeira ocorrência acusaria de
        // ausente uma chave que está registrada.
        expect(
          linhas
              .where((l) => l.trim().startsWith('GATES="'))
              .expand((l) => l.split(RegExp(r'[\s"]+'))),
          contains(e.chave),
          reason: '"${e.chave}" está fora da lista GATES da evidência',
        );
        expect(
          linhas
              .where((l) => l.trim().startsWith('for k in '))
              .expand((l) => l.split(RegExp(r'[\s;]+'))),
          contains(e.chave),
          reason: '"${e.chave}" está fora da lista do portão',
        );
      }
    });
  });
}

// ---8<--- DECISAO FIM
