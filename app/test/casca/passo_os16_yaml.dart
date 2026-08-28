// passo_os16_yaml.dart — a AUTORIDADE ESTRUTURAL do passo do portão da OS 16.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE
// ---------------------------------------------------------------------------
//
// A OS 16-C1 pôs o portão nos três workflows e provou, por TEXTO, que a linha
// de invocação estava viva, dentro do passo certo e antes da âncora. A OS 16-R2
// mostrou que isso não basta: cinco gestos MENORES que a raiz completa deixavam
// o caminho oficial verde sem que o portão decidisse nada.
//
//   X01  `continue-on-error: true` DEPOIS de `run:` — a janela textual entre o
//        nome do passo e a linha do comando não alcança o que vem depois dela;
//   X02  `if: false` depois de `run:` — ninguém olhava `if:`;
//   X03  `if: false` antes de `run:` — idem;
//   X05  `continue-on-error: true` só no `build.yml` — um arquivo, uma linha;
//   X06  `exit 0` na linha seguinte, DENTRO do mesmo `run:` — a linha da
//        invocação continuava impecável, e o código de saída do passo virava 0.
//
// Todos os cinco têm a mesma raiz: a decisão morava em `grep`, em substring e
// em número de linha. `continue-on-error`, `if` e o corpo de um `run:` não são
// texto próximo — são NÓS de um documento YAML. Quem quiser decidir sobre eles
// tem de ler o documento como documento.
//
// ---------------------------------------------------------------------------
// O QUE ESTE MÓDULO DECIDE
// ---------------------------------------------------------------------------
//
// Dado o texto de um workflow e o que o contrato exige dele, devolve a lista de
// falhas. Lista vazia é a ÚNICA forma de aprovar. Não existe caminho em que
// documento ilegível, nó ausente, tipo inesperado ou exceção do parser produza
// lista vazia: erro é VERMELHO, nunca `return` e nunca conformidade.
//
// O passo canônico tem de ser, cumulativamente:
//
//   vivo        — é um nó de `jobs.<job>.steps`, não texto solto;
//   único       — exatamente um passo com o nome canônico no arquivo inteiro, e
//                 exatamente um passo cujo `run` invoca o portão — o mesmo nó;
//   exato       — o mapping do passo tem SOMENTE `name` e `run`. Qualquer outra
//                 chave (`if`, `continue-on-error`, `working-directory`,
//                 `shell`, `env`, `uses`, `id`, `timeout-minutes`) muda se,
//                 como ou com que resultado o comando roda, e REPROVA;
//   íntegro     — o `run`, normalizado, é UMA única instrução, idêntica à
//                 invocação do contrato. Nada antes, nada depois: `exit 0`,
//                 `|| true`, `; true`, `echo`, heredoc e redirecionamento
//                 deixam de ser uma linha extra e passam a ser uma reprovação;
//   alcançável  — o job que o contém não é desligado por `if:` nem absolvido
//                 por `continue-on-error:`, e não desvia o comando por
//                 `defaults.run` (diretório ou shell);
//   anterior    — vem, na MESMA lista de passos, antes do passo que contém a
//                 âncora contratada.
//
// Este arquivo é lido por DOIS caminhos oficiais, e é o mesmo arquivo nos dois:
//
//   1. `app/test/casca/auditoria_casca_test.dart` — a autoridade que os gates
//      já reconhecem (`cascaaud` no agregador e `flutter test test/casca` no
//      `build.yml`);
//   2. `ferramentas/ci/passo_os16/bin/passo_os16.dart` — a CLI que
//      `ferramentas/ci/portao_os16.sh` executa.
//
// Uma implementação, dois consumidores: não há como as duas autoridades
// discordarem, porque não são duas.

import 'package:yaml/yaml.dart';

/// Uma reprovação estrutural, com o código que a identifica na campanha.
class FalhaPassoOS16 {
  const FalhaPassoOS16(this.codigo, this.mensagem);

  final String codigo;
  final String mensagem;

  @override
  String toString() => 'REPROVA [$codigo] $mensagem';
}

/// As ÚNICAS chaves aceitas no mapping do passo canônico.
///
/// A lista é fechada de propósito: enumerar o que é proibido deixaria de fora o
/// próximo atributo que o GitHub Actions inventar. Enumerar o que é permitido
/// reprova o desconhecido por construção.
const Set<String> kChavesCanonicasPassoOS16 = <String>{'name', 'run'};

/// Audita UM workflow contra o que o contrato exige do passo do portão.
///
/// Devolve a lista de falhas — vazia significa aprovado, e é o único jeito de
/// aprovar.
List<FalhaPassoOS16> auditarPassoOS16({
  required String caminho,
  required String textoYaml,
  required String nomePasso,
  required String invocacao,
  required String ancora,
}) {
  final falhas = <FalhaPassoOS16>[];
  void reprova(String codigo, String mensagem) =>
      falhas.add(FalhaPassoOS16(codigo, '$caminho: $mensagem'));

  // -------------------------------------------------------------------------
  // O documento
  // -------------------------------------------------------------------------
  dynamic raiz;
  try {
    raiz = loadYaml(textoYaml.replaceAll('\r\n', '\n'));
  } catch (e) {
    reprova('Y01', 'YAML inválido — o documento não pôde ser lido: $e');
    return falhas;
  }
  if (raiz is! YamlMap) {
    reprova('Y02', 'a raiz do workflow não é um mapa YAML');
    return falhas;
  }
  final jobs = raiz['jobs'];
  if (jobs is! YamlMap) {
    reprova('Y03', '`jobs` ausente ou não é um mapa — não há passo que valha');
    return falhas;
  }

  // `defaults.run` no nível do WORKFLOW muda o diretório e o shell de TODOS os
  // passos, sem tocar em nenhum deles.
  falhas.addAll(_auditarDefaults(raiz, 'workflow', caminho, 'Y04', 'Y05'));

  // -------------------------------------------------------------------------
  // Varredura estrutural: quem se chama assim, e quem invoca o portão
  // -------------------------------------------------------------------------
  final canonicos = <_Passo>[];
  final invocadores = <_Passo>[];

  for (final entrada in jobs.nodes.entries) {
    final idJob = entrada.key.toString();
    final job = entrada.value.value;
    if (job is! YamlMap) {
      reprova('Y06', 'o job `$idJob` não é um mapa YAML');
      continue;
    }
    final passos = job['steps'];
    if (passos == null) continue;
    if (passos is! YamlList) {
      reprova('Y07', '`steps` do job `$idJob` não é uma lista YAML');
      continue;
    }
    for (var i = 0; i < passos.length; i++) {
      final passo = passos[i];
      if (passo is! YamlMap) {
        reprova('Y08', 'o passo #${i + 1} do job `$idJob` não é um mapa YAML');
        continue;
      }
      final atual = _Passo(idJob, job, passos, i, passo);
      final nome = passo['name'];
      if (nome is String && nome == nomePasso) canonicos.add(atual);
      final run = passo['run'];
      if (run is String && run.contains(invocacao)) invocadores.add(atual);
    }
  }

  if (canonicos.isEmpty) {
    reprova('Y10',
        'nenhum passo se chama "$nomePasso" — o portão saiu do workflow');
  }
  if (canonicos.length > 1) {
    reprova(
        'Y11',
        '${canonicos.length} passos se chamam "$nomePasso" — um deles é isca, '
            'e o portão deixou de ser único');
  }
  if (invocadores.isEmpty) {
    reprova('Y12',
        'nenhum passo executa "$invocacao" — o comando virou texto ou sumiu');
  }
  if (invocadores.length > 1) {
    reprova(
        'Y13',
        '${invocadores.length} passos executam "$invocacao" — invocação '
            'duplicada permite neutralizar a real e deixar a isca verde');
  }
  if (canonicos.length != 1 || invocadores.length != 1) return falhas;

  final passo = canonicos.single;
  if (!identical(passo.mapa, invocadores.single.mapa)) {
    reprova(
        'Y14',
        'o passo "$nomePasso" não é o que executa o portão — o comando foi '
            'movido para o passo "${invocadores.single.nome}"');
    return falhas;
  }

  // -------------------------------------------------------------------------
  // O mapping do passo: SOMENTE `name` e `run`
  // -------------------------------------------------------------------------
  final chaves = passo.mapa.keys.map((k) => k.toString()).toSet();
  final intrusas = chaves.difference(kChavesCanonicasPassoOS16).toList()..sort();
  if (intrusas.isNotEmpty) {
    reprova(
        'Y20',
        'o passo do portão carrega ${intrusas.map((c) => '`$c`').join(', ')} '
            '— o passo canônico tem SOMENTE `name` e `run`, porque toda outra '
            'chave muda se, como ou com que resultado o comando roda');
  }
  final faltando = kChavesCanonicasPassoOS16.difference(chaves).toList()..sort();
  if (faltando.isNotEmpty) {
    reprova('Y21',
        'o passo do portão não tem ${faltando.map((c) => '`$c`').join(', ')}');
  }

  // -------------------------------------------------------------------------
  // O corpo do `run`: uma instrução, exata
  // -------------------------------------------------------------------------
  final run = passo.mapa['run'];
  if (run is! String) {
    reprova('Y22',
        '`run` do passo do portão não é um escalar de texto: ${run.runtimeType}');
  } else {
    final instrucoes = run
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (instrucoes.length != 1) {
      reprova(
          'Y23',
          '`run` do passo do portão tem ${instrucoes.length} instrução(ões) '
              '— o passo canônico tem UMA, e nada antes nem depois dela: '
              '${instrucoes.map((l) => '"$l"').join(' ; ')}');
    } else if (instrucoes.single != invocacao) {
      reprova(
          'Y24',
          '`run` do passo do portão é "${instrucoes.single}" e o contrato '
              'exige exatamente "$invocacao" — qualquer sufixo neutraliza o '
              'código de saída');
    }
  }

  // -------------------------------------------------------------------------
  // O job que contém o passo: alcançável e sem absolvição
  // -------------------------------------------------------------------------
  if (passo.job.containsKey('if')) {
    reprova(
        'Y30',
        'o job `${passo.idJob}`, que contém o portão, é condicional '
            '(`if: ${passo.job['if']}`) — um job desligado não decide nada');
  }
  final coeJob = passo.job['continue-on-error'];
  if (coeJob != null && coeJob != false) {
    reprova(
        'Y31',
        'o job `${passo.idJob}` está com `continue-on-error: $coeJob` — a '
            'reprovação do portão não chegaria à conclusão do workflow');
  }
  falhas.addAll(_auditarDefaults(
      passo.job, 'job `${passo.idJob}`', caminho, 'Y32', 'Y33'));

  // -------------------------------------------------------------------------
  // A ordem: o portão vem ANTES da âncora, na mesma lista de passos
  // -------------------------------------------------------------------------
  var iAncora = -1;
  for (var i = 0; i < passo.passos.length; i++) {
    final outro = passo.passos[i];
    if (outro is! YamlMap) continue;
    final corpo = outro['run'];
    final nome = outro['name'];
    if ((corpo is String && corpo.contains(ancora)) ||
        (nome is String && nome.contains(ancora))) {
      iAncora = i;
      break;
    }
  }
  if (iAncora < 0) {
    reprova(
        'Y40',
        'o job `${passo.idJob}` perdeu a âncora "$ancora" — o portão não '
            'guarda mais nada');
  } else if (passo.indice >= iAncora) {
    reprova(
        'Y41',
        'o portão é o passo #${passo.indice + 1} e a âncora "$ancora" é o '
            'passo #${iAncora + 1} — o portão roda tarde demais para impedir '
            'o que a âncora produz');
  }

  return falhas;
}

/// `defaults.run` desvia diretório e shell de todos os passos de uma vez.
List<FalhaPassoOS16> _auditarDefaults(
  YamlMap escopo,
  String rotulo,
  String caminho,
  String codigoDiretorio,
  String codigoShell,
) {
  final falhas = <FalhaPassoOS16>[];
  final defaults = escopo['defaults'];
  if (defaults is! YamlMap) return falhas;
  final run = defaults['run'];
  if (run is! YamlMap) return falhas;

  final dir = run['working-directory'];
  if (dir != null && dir != '.' && dir != './') {
    falhas.add(FalhaPassoOS16(
        codigoDiretorio,
        '$caminho: `defaults.run.working-directory: $dir` no $rotulo — o '
            'portão deixaria de rodar na raiz do checkout'));
  }
  final shell = run['shell'];
  if (shell != null && shell != 'bash') {
    falhas.add(FalhaPassoOS16(
        codigoShell,
        '$caminho: `defaults.run.shell: $shell` no $rotulo — outro shell pode '
            'interpretar o comando de outro jeito'));
  }
  return falhas;
}

/// Um passo localizado na estrutura: o job, a lista e o índice.
class _Passo {
  const _Passo(this.idJob, this.job, this.passos, this.indice, this.mapa);

  final String idJob;
  final YamlMap job;
  final YamlList passos;
  final int indice;
  final YamlMap mapa;

  String get nome {
    final n = mapa['name'];
    return n is String ? n : '(sem nome)';
  }
}
