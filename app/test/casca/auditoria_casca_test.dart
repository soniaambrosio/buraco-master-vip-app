// auditoria_casca_test.dart — a prova de AUSÊNCIA.
//
// A suíte irmã prova comportamento: dado um estado, o que a casca faz. Esta
// prova o que NÃO existe — e existe porque as três coisas que ela persegue já
// estiveram no código e voltariam sozinhas na primeira refatoração distraída:
//
//   * um segundo dono de autenticação (uma tela chamando `FirebaseAuth` ou
//     `GoogleSignIn` por conta própria);
//   * uma rota de produção que alcança maquete;
//   * dado pessoal de uma pessoa real escrito no código distribuído.
//
// POR QUE UM TESTE, E NÃO UM `grep` NO FECHAMENTO. Um grep prova o dia em que
// foi rodado. Este arquivo roda no CI junto com o resto, então a proibição
// continua valendo depois que esta OS fechar.
//
// A técnica de despojar comentários antes de varrer é a mesma de
// `sessao/auditoria_identidade_test.dart`, e pelo mesmo motivo: uma auditoria
// que lê comentário se auto-sabota. Este próprio módulo explica, em prosa, o
// que é proibido — e uma varredura ingênua acusaria a explicação como violação.
// Pior: o jeito de "consertar" seria apagar a documentação.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

/// O arquivo SEM comentários, respeitando aspas para que uma `//` dentro de
/// string literal não seja confundida com início de comentário.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';

    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
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
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// Junta um caminho relativo ao diretório de quem importa, resolvendo `..`.
String _resolver(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(deQuem).split('/')..removeLast();
  for (final parte in importado.split('/')) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(parte);
  }
  return base.join('/');
}

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// O fecho transitivo dos imports a partir de `lib/main.dart`.
///
/// É ISTO que "alcançável pela raiz de produção" significa nesta auditoria:
/// não o que existe em `lib/`, e sim o que o binário publicado consegue chegar
/// a executar partindo de `main()`.
Set<String> _alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(_codigo(f))) {
      final alvo = m.group(1)!;
      // Pacotes externos (`package:flutter/...`) e `dart:` não são nossos.
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

/// Todos os `.dart` do cliente — tudo em `lib/`, menos os bundles que compilam
/// para as Cloud Functions e nunca rodam no aplicativo.
List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final n = _barras(f.path);
          return !n.contains('/social/') &&
              !n.contains('/moderacao/') &&
              !n.endsWith('js_bridge.dart');
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  late Set<String> alcancaveis;

  setUpAll(() {
    alcancaveis = _alcancaveisDaRaiz();
    // Se a varredura não achou nada, o arquivo inteiro seria um verde falso.
    expect(
      alcancaveis,
      contains('lib/main.dart'),
      reason: 'a auditoria precisa ter o que ler',
    );
    expect(alcancaveis.length, greaterThan(5));
  });

  // =========================================================================
  // §4.1 — um dono de autenticação, e um só
  // =========================================================================
  group('não existe segundo dono de autenticação', () {
    test('authStateChanges é assinado num lugar só do cliente', () {
      final assinantes = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('authStateChanges')) {
          assinantes.add(_barras(f.path));
        }
      }
      expect(
        assinantes,
        hasLength(1),
        reason:
            'dois observadores do fluxo de autenticação são dois donos de '
            'sessão, e o segundo nunca conhece a geração do primeiro',
      );
      expect(assinantes.single, endsWith('lib/sessao/sessao_firebase.dart'));
    });

    test('só a camada de sessão importa firebase_auth ou google_sign_in', () {
      final permitidos = {
        'lib/sessao/sessao_firebase.dart',
        'lib/sessao/autenticacao_firebase.dart',
      };
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final n = _barras(f.path);
        if (permitidos.contains(n)) continue;
        final conteudo = _codigo(f);
        if (conteudo.contains('firebase_auth') ||
            conteudo.contains('google_sign_in')) {
          infratores.add(n);
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'uma tela que sabe acionar o provedor de autenticação decide '
            'sozinha o que fazer com o resultado — e é isso que faz dela um '
            'segundo dono, mesmo sem guardar estado',
      );
    });

    test('nenhuma tela alcançável guarda o usuário do provedor', () {
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (caminho.startsWith('lib/sessao/')) continue;
        final conteudo = _codigo(f);
        for (final termo in [
          'currentUser',
          'signInWithCredential',
          'signOut(',
        ]) {
          if (conteudo.contains(termo)) infratores.add('$caminho: $termo');
        }
      }
      expect(infratores, isEmpty);
    });

    test('o transporte continua sem saber falar com o provedor', () {
      // A garantia que a folha da conexão publicável já tinha, e que a casca
      // não pode ter afrouxado ao subir o transporte para a raiz.
      final transporte = _codigo(File('lib/services/online_service.dart'));
      expect(transporte, isNot(contains('firebase_auth')));
      expect(transporte, isNot(contains('FirebaseAuth')));
    });
  });

  // =========================================================================
  // §2 e §4.4 — nenhuma rota de produção alcança maquete
  // =========================================================================
  group('a raiz de produção não alcança maquete', () {
    test('nenhum arquivo alcançável CONSTRÓI um .mock()', () {
      // A DEFINIÇÃO de `.mock()` continua permitida: as telas seguem no
      // repositório como catálogo visual, e a auditoria não as proíbe de
      // existir. O que ela proíbe é alguém CHAMAR uma delas num caminho que
      // nasce em `main()`.
      final definicao = RegExp(r'factory\s+\w+\.mock');
      final chamada = RegExp(r'\b[A-Z]\w*\.mock\s*\(');
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final semDefinicoes = _codigo(f).replaceAll(definicao, '');
        final achado = chamada.firstMatch(semDefinicoes);
        if (achado != null) infratores.add('$caminho: ${achado.group(0)}');
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'dado de maquete alcançável pela raiz é dado inventado exibido '
            'como se fosse do jogador',
      );
    });

    test('main.dart não hospeda host de pré-visualização', () {
      final raiz = _codigo(File('lib/main.dart'));
      expect(raiz, isNot(contains('PreviewHost')));
      expect(raiz, isNot(contains('Preview')));
      // E continua enxuto: era este arquivo que crescia a cada tela nova.
      expect(
        File('lib/main.dart').readAsLinesSync().length,
        lessThan(120),
        reason: 'a porta de entrada não é lugar de tela',
      );
    });

    test('nenhuma tela de prévia declarada é alcançável', () {
      const maquetes = [
        'TorneiosPreviewPage',
        'MesaVipPreviewScreen',
        'LojaCosmeticosScreen',
        'ModeloTorneioScreen',
        'AdminTorneiosScreen',
      ];
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final conteudo = _codigo(f);
        for (final maquete in maquetes) {
          // A própria declaração não conta — o que conta é alguém alcançá-la.
          if (conteudo.contains('class $maquete')) continue;
          if (conteudo.contains(maquete)) {
            infratores.add('$caminho: $maquete');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('o Perfil alcançável não exibe números de demonstração', () {
      final servico = _codigo(File('lib/services/perfil_service.dart'));
      expect(
        servico,
        contains('static const bool statsDemo = false'),
        reason:
            'com a chave ligada, todo mundo abria o próprio perfil e via os '
            'números de outra pessoa',
      );
    });

    test('o ramo publicável do Perfil não escreve valor nenhum', () {
      // ESTE É O TESTE QUE FALTAVA, e a folha `casca-producao-auth-roteamento-v2`
      // é quem o trouxe. O caso acima checava só `statsDemo == false`, e era
      // EXATAMENTE por isso que o defeito passava por ele: desligar a chave
      // resolvia os números de marketing e deixava intacto o outro ramo do
      // ternário, que escrevia nível 1, título 'Novato(a)', quatro zeros de
      // estatística, zero presentes e oito conquistas travadas.
      //
      // A prova é do FORMATO do literal, e por isso é estrutural: um dia esses
      // campos vão receber valor do Firestore, e aí quem manda é o teste de
      // comportamento (`casca_producao_test.dart` e a suíte de ranking). O que
      // não pode voltar é a CONSTANTE escrita no código.
      //
      // A comparação normaliza espaços porque o formatador quebra estas linhas
      // de jeitos diferentes conforme o comprimento.
      final servico = _codigo(
        File('lib/services/perfil_service.dart'),
      ).replaceAll(RegExp(r'\s+'), ' ');

      const proibidos = [
        "liga: demo ? 'Diamante' : 'Bronze'",
        'posicaoMundial: demo ? 128 : 0',
        'nivel: demo ? 24 : 1',
        "titulo: demo ? 'Rainha da Canastra' : 'Novato(a)'",
        'presentesCount: demo ? 12 : 0',
        'conquistas: demo ? _catalogoDemo : _catalogoTravado',
      ];
      for (final linha in proibidos) {
        expect(
          servico,
          isNot(contains(linha)),
          reason: 'voltou a inventar valor para jogador sem fonte: $linha',
        );
      }

      final ausencias = <Pattern>[
        'nivel: demo ? 24 : null',
        'xpAtual: demo ? 3240 : null',
        'xpProximo: demo ? 5000 : null',
        "titulo: demo ? 'Rainha da Canastra' : null",
        'presentesCount: demo ? 12 : null',
        'conquistas: demo ? _catalogoDemo : null',
        // `stats` é o único cujo ramo demo tem vírgulas dentro, então a âncora
        // é o fim do construtor. A vírgula final é opcional (o formatador a
        // acrescenta quando quebra a linha), e por isso entra no casamento.
        RegExp(r'aproveitamento: 68,? ?\) : null'),
      ];
      for (final ausencia in ausencias) {
        expect(
          servico,
          contains(ausencia),
          reason: 'sem fonte, o campo precisa chegar AUSENTE: $ausencia',
        );
      }

      // E o catálogo "tudo travado" não pode reaparecer por nenhuma porta: oito
      // troféus apagados afirmam que a pessoa não ganhou nenhum, e quem sabe
      // isso é o backend de recompensas, que o cliente ainda não lê.
      expect(servico, isNot(contains('_catalogoTravado')));
    });

    test('o convite copiado não carrega valor inventado', () {
      // O `_compartilhar` montava 'Nível ${vm?.nivel ?? 1} · Liga
      // ${vm?.liga ?? 'Bronze'}'. Com os `??`, a afirmação inventada saía do
      // aplicativo pela área de transferência — o pior destino possível, porque
      // vai parar na conversa de outra pessoa.
      final pagina = _codigo(File('lib/pages/perfil_page.dart'));
      expect(pagina, isNot(contains("?? 'Bronze'")));
      expect(pagina, isNot(contains('?? 1')));
      expect(pagina, isNot(contains('Bronze')));
    });
  });

  // =========================================================================
  // §5 — nenhum dado pessoal real no código distribuído
  // =========================================================================
  group('nenhum dado pessoal real em lib/', () {
    test('nenhum e-mail de domínio real aparece no código', () {
      // `.invalido` e `.invalid` são reservados justamente para fixture, e por
      // isso são o único domínio aceito aqui.
      final email = RegExp(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
      );
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        for (final m in email.allMatches(_codigo(f))) {
          final achado = m.group(0)!;
          if (achado.endsWith('.invalido') || achado.endsWith('.invalid')) {
            continue;
          }
          infratores.add('${_barras(f.path)}: $achado');
        }
      }
      expect(infratores, isEmpty);
    });

    test('os dados pessoais conhecidos sumiram do código', () {
      // A lista é dos valores que ESTAVAM no código e iam embarcados em todo
      // APK: o nome de perfil e o e-mail da dona do projeto.
      const conhecidos = ['Sônia Rainha', 'soniia', 'soniia.ambrosio'];
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final dado in conhecidos) {
          if (conteudo.contains(dado)) {
            infratores.add('${_barras(f.path)}: $dado');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('a Home de produção não exibe o e-mail da conta', () {
      final home = _codigo(File('lib/casca/home_de_producao.dart'));
      // O campo existe no contrato da tela e é preenchido vazio de propósito.
      expect(home, contains("email: ''"));
    });
  });

  // =========================================================================
  // §4.5 — o transporte não nasce conectado nem duplicado
  // =========================================================================
  group('transporte único', () {
    test('só a raiz constrói OnlineService no código alcançável', () {
      final construtores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (caminho == 'lib/services/online_service.dart') continue;
        if (caminho == 'lib/services/ponte_sessao_online.dart') continue;
        final conteudo = _codigo(f);
        if (conteudo.contains('OnlineService(') ||
            conteudo.contains('criarOnlineServiceDaSessao(')) {
          construtores.add(_barras(caminho));
        }
      }
      expect(
        construtores,
        hasLength(1),
        reason: 'um transporte por tela é um socket por tela',
      );
      expect(construtores.single, 'lib/casca/raiz_do_aplicativo.dart');
    });

    test('a raiz monta a ponte de sessão', () {
      final raiz = _codigo(File('lib/casca/raiz_do_aplicativo.dart'));
      expect(
        raiz,
        contains('PonteSessaoOnline('),
        reason:
            'sem ponte montada na raiz, um logout fora do lobby não derruba '
            'socket nenhum',
      );
    });

    test('a raiz não conecta o transporte sozinha', () {
      final raiz = _codigo(File('lib/casca/raiz_do_aplicativo.dart'));
      expect(
        raiz,
        isNot(contains('.conectar()')),
        reason:
            'subir o transporte não é conectar: quem pede é o jogador, ao '
            'escolher jogar online',
      );
    });
  });

  // =========================================================================
  // §7 — nada de `print` novo nas camadas sensíveis
  // =========================================================================
  test('sessão, casca e transporte não escrevem em log', () {
    final infratores = <String>[];
    for (final f in _fontesDoCliente()) {
      final n = _barras(f.path);
      final sensivel =
          n.contains('/sessao/') ||
          n.contains('/casca/') ||
          n.endsWith('online_service.dart') ||
          n.endsWith('ponte_sessao_online.dart');
      if (!sensivel) continue;
      final conteudo = _codigo(f);
      // Fronteira de palavra obrigatória: sem ela, `showDialog(` acusa `log(`
      // e a auditoria reprova uma caixa de diálogo por escrever em log.
      for (final termo in [r'\bprint\(', r'\bdebugPrint\(', r'\blog\(']) {
        if (RegExp(termo).hasMatch(conteudo)) infratores.add('$n: $termo');
      }
    }
    expect(
      infratores,
      isEmpty,
      reason: 'é por log que credencial e identidade vazam sem ninguém ver',
    );
  });

  // =========================================================================
  // O PORTÃO DA IDENTIDADE VISITADA EXISTE, E A AUSÊNCIA DELE REPROVA
  // =========================================================================
  //
  // POR QUE ESTA PROVA MORA AQUI, E NÃO NA SUÍTE QUE ELA PROTEGE.
  //
  // O workflow trata arquivo de teste ausente como NÃO EXECUTADO, e NÃO
  // EXECUTADO não derruba o portão — é uma decisão antiga e deliberada, para que
  // um artefato que não existe naquele recorte não invente vermelho. O efeito
  // colateral é que apagar um arquivo de suíte SILENCIA o gate dele em vez de
  // quebrá-lo.
  //
  // Uma prova escrita dentro da própria suíte morreria junto com ela. Escrita
  // aqui — num gate que já é obrigatório e que fala de outro assunto — ela
  // sobrevive ao apagamento e o denuncia. É a mesma ideia do resto deste
  // arquivo: a garantia tem de morar fora do que ela garante.
  group('o portão da identidade visitada', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');

    test('a suíte existe na árvore', () {
      expect(
        File('test/perfil/identidade_visitada_test.dart').existsSync(),
        isTrue,
        reason: 'a suíte que prova o Perfil visitado sumiu — e some em silêncio, '
            'porque ausência vira NÃO EXECUTADO no portão',
      );
    });

    test('o workflow a executa e a considera no portão', () {
      // O overlay do CI roda a partir de `app_build/`, e o workflow fica dois
      // níveis acima. Fora do CI o arquivo pode não estar alcançável — e aí o
      // caso não tem o que afirmar, em vez de afirmar errado.
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();

      expect(
        texto,
        contains('roda perfilvis  test/perfil/identidade_visitada_test.dart'),
        reason: 'o gate perfilvis não executa mais a suíte',
      );
      // Nas DUAS listas: a da evidência publicada e a que decide verde/vermelho.
      // Estar só na primeira faria o gate aparecer no relatório e não reprovar.
      expect(
        RegExp(r'GATES="[^"]*\bperfilvis\b').hasMatch(texto),
        isTrue,
        reason: 'perfilvis saiu da evidência publicada',
      );
      expect(
        RegExp(r'for k in [^;]*\bperfilvis\b[^;]*; do').hasMatch(texto),
        isTrue,
        reason: 'perfilvis saiu do portão verde/vermelho — passaria a rodar '
            'sem poder reprovar',
      );
    });
  });

  // =========================================================================
  // O PORTÃO DA OS 16 — CONTRATO EXTERNO, PISOS E OS TRÊS WORKFLOWS
  // =========================================================================
  //
  // Mesma disciplina do grupo acima, e pelo mesmo motivo: apagar um arquivo de
  // suíte SILENCIA o gate dele. Só que a OS 16-R1 mostrou que EXISTIR não
  // basta. Três destruições continuavam saindo verdes:
  //
  //   1. trocar a suíte inteira por `expect(1 + 1, 2)`;
  //   2. baixar os pisos de 48 dp e 11 pt para 24 e 6 — na tela E na suíte, de
  //      forma coordenada, porque a comparação é `>=` e o número esperado
  //      morava dentro do próprio arquivo comparado;
  //   3. apagar os workflows, porque a checagem era `if (!existe) return`.
  //
  // A correção é fixar a régua FORA de quem a declara e de quem a usa. Este
  // grupo é a autoridade que os gates já reconhecem (`cascaaud` no agregador e
  // o portão da casca no `build.yml`). O contrato externo é
  // `app/test/casca/contrato_os16_resultado.txt`, e o digest dele está gravado
  // aqui, em literal: recarimbar o contrato junto com a sabotagem reprova neste
  // arquivo, e recarimbar também este arquivo ainda reprova em
  // `ferramentas/ci/portao_os16.sh`, que guarda 48 e 11 em literal.
  //
  // NÃO EXISTE `return` NESTE GRUPO. Ausência é reprovação.
  group('o portão da OS 16 — Resultado legível e tocável', () {
    test('o contrato externo existe, é a versão esperada e não foi recarimbado',
        () {
      final bruto = _obrigatorio(_caminhoContratoOS16);
      expect(
        bruto.trim(),
        isNotEmpty,
        reason: 'contrato vazio equivale a contrato ausente',
      );
      expect(
        _campo(bruto, 'contrato'),
        'os16-resultado-legivel-tocavel',
        reason: 'a identidade do contrato mudou',
      );
      expect(
        _campo(bruto, 'versao'),
        kVersaoContratoOS16,
        reason: 'versão inesperada do contrato da OS 16',
      );
      expect(
        _digestOS16(bruto),
        kDigestContratoOS16,
        reason: 'o contrato da OS 16 foi reescrito. Se a mudança é legítima, '
            'ela sobe a versão e recarimba os TRÊS lugares — contrato, esta '
            'autoridade e o verificador. Se não é, acabou de ser pega',
      );
      for (final chave in const <String>[
        'suite',
        'suite_digest_sha256',
        'suite_casos',
        'produtivo',
        'produtivo_digest_sha256',
        'piso_alvo_dp',
        'piso_fonte_pt',
        'verificador',
        'invocacao',
      ]) {
        expect(
          _quantos(bruto, chave),
          1,
          reason: 'a chave "$chave" tem de aparecer exatamente uma vez',
        );
      }
    });

    test('a suíte oficial está no caminho do contrato, com o digest dele', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      final caminho = _campo(contrato, 'suite');
      expect(
        caminho,
        'app/test/casca/a11y_resultado_partida_test.dart',
        reason: 'o caminho da suíte oficial foi redirecionado',
      );
      final fonte = _obrigatorio(caminho);
      expect(
        _digestOS16(fonte),
        _campo(contrato, 'suite_digest_sha256'),
        reason: 'a suíte que mede alvo tocável e tipografia do Resultado não é '
            'mais a que o contrato protege',
      );
      // A cópia que o gate REALMENTE executa vive dentro do scaffold. Se ela
      // sumir, o `flutter test test/casca` roda sem a suíte e ninguém percebe.
      expect(
        File('test/casca/a11y_resultado_partida_test.dart').existsSync(),
        isTrue,
        reason: 'a suíte não chegou ao diretório que o portão da casca roda',
      );
    });

    test('a cardinalidade e os nomes dos casos são os do contrato', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      final esperados = int.parse(_campo(contrato, 'suite_casos'));
      final arquivo = File('../${_campo(contrato, 'suite')}');
      final codigo = _semStrings(_codigo(arquivo));
      final nomes = _codigo(arquivo);

      final chamadas = RegExp(r'(^|[^A-Za-z0-9_$])(testWidgets|test)\s*\(')
          .allMatches(codigo)
          .length;
      expect(
        chamadas,
        esperados,
        reason: 'a suíte tem $chamadas caso(s) executável(is) e o contrato '
            'exige $esperados — trocar a suíte por um teste trivial cai aqui',
      );

      final lista = _repetida(contrato, 'caso');
      expect(
        lista.length,
        esperados,
        reason: 'o contrato lista ${lista.length} nome(s) para uma '
            'cardinalidade de $esperados',
      );
      for (final nome in lista) {
        expect(
          nome.allMatches(nomes).length,
          1,
          reason: 'caso obrigatório ausente, renomeado ou duplicado: "$nome"',
        );
      }
    });

    test('os pisos de 48 dp e 11 pt têm UMA atribuição, com esse valor', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      expect(
        _campo(contrato, 'piso_alvo_dp'),
        '${kPisoAlvoOS16.toInt()}',
        reason: 'o contrato afrouxou o piso de alvo tocável',
      );
      expect(
        _campo(contrato, 'piso_fonte_pt'),
        '${kPisoFonteOS16.toInt()}',
        reason: 'o contrato afrouxou o piso tipográfico',
      );

      for (final linha in _repetida(contrato, 'declaracao')) {
        final campos = linha.split(RegExp(r'\s+'));
        expect(campos.length, greaterThanOrEqualTo(3),
            reason: 'declaração malformada: "$linha"');
        final caminho = campos[0];
        final simbolo = campos[1];
        final valor = double.parse(campos[2]);
        expect(
          <double>[kPisoAlvoOS16, kPisoFonteOS16],
          contains(valor),
          reason: '"$simbolo" está declarado como $valor, fora da régua '
              '($kPisoAlvoOS16 / $kPisoFonteOS16)',
        );

        final codigo = _semStrings(_codigo(File('../$caminho')));
        final atribuicoes = RegExp('(^|[^A-Za-z0-9_])$simbolo\\s*=[^=]')
            .allMatches(codigo)
            .toList();
        expect(
          atribuicoes.length,
          1,
          reason: '"$simbolo" tem ${atribuicoes.length} atribuição(ões) em '
              '$caminho — a legítima pode estar escondida atrás de uma isca',
        );
        final trecho = codigo.substring(atribuicoes.single.start);
        final numero = RegExp('$simbolo\\s*=\\s*([0-9]+(\\.[0-9]+)?)')
            .firstMatch(trecho)!
            .group(1)!;
        expect(
          double.parse(numero),
          valor,
          reason: '"$simbolo" vale $numero em $caminho — a régua exige $valor',
        );
      }

      // Declarar o piso não basta: ele tem de ser COBRADO. Sem isto, trocar a
      // comparação por um número solto deixaria a constante intacta.
      for (final linha in _repetida(contrato, 'exigencia')) {
        final partes = linha.split(RegExp(r'\s+'));
        final caminho = partes[0];
        final minimo = int.parse(partes[1]);
        final literal = partes.sublist(2).join(' ');
        final codigo = _semStrings(_codigo(File('../$caminho')));
        expect(
          literal.allMatches(codigo).length,
          greaterThanOrEqualTo(minimo),
          reason: '"$literal" aparece menos de $minimo vez(es) em $caminho',
        );
      }
    });

    test('a tela produtiva está byte a byte como a OS 16 a aprovou', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      final caminho = _campo(contrato, 'produtivo');
      expect(
        caminho,
        'app/lib/screens/resultado_partida_screen.dart',
        reason: 'o caminho da tela produtiva foi redirecionado',
      );
      expect(
        _digestOS16(_obrigatorio(caminho)),
        _campo(contrato, 'produtivo_digest_sha256'),
        reason: 'a tela de Resultado mudou sem passar por uma OS',
      );
    });

    test('o verificador nomeado no contrato está na árvore', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      final caminho = _campo(contrato, 'verificador');
      expect(
        caminho,
        'ferramentas/ci/portao_os16.sh',
        reason: 'o contrato aponta outro verificador',
      );
      expect(
        _obrigatorio(caminho).trim(),
        isNotEmpty,
        reason: 'o verificador da OS 16 sumiu ou ficou vazio',
      );
    });

    test('os TRÊS workflows existem e invocam o portão da OS 16, vivo', () {
      final contrato = _obrigatorio(_caminhoContratoOS16);
      final invocacao = _campo(contrato, 'invocacao');
      final declarados = _repetida(contrato, 'workflow');
      expect(
        declarados.length,
        3,
        reason: 'a OS 16 protege exatamente três workflows',
      );

      for (final entrada in declarados) {
        final partes = entrada.split('|').map((s) => s.trim()).toList();
        final caminho = partes[0];
        final passo = partes[1];
        final ancora = partes[2];

        // Ausência REPROVA. Era exatamente aqui que morava o `if (!existe)
        // return` que deixava apagar os três workflows sem consequência.
        final texto = _obrigatorio(caminho);
        final linhas = texto.split('\n');

        final vivas = _invocacoesVivas(linhas, invocacao);
        expect(
          vivas.length,
          1,
          reason: '$caminho tem ${vivas.length} invocação(ões) viva(s) de '
              '"$invocacao" — esperava exatamente uma. Comando comentado, '
              'dentro de echo/printf/heredoc ou duplicado não conta',
        );

        final linha = linhas[vivas.single - 1];
        for (final neutralizador in const <String>[
          '|| true',
          '|| :',
          '||:',
          '|| echo',
          '/bin/true',
          '; true',
          '|| exit 0',
          '/dev/null',
        ]) {
          expect(
            linha.contains(neutralizador),
            isFalse,
            reason: '$caminho neutraliza o portão com "$neutralizador"',
          );
        }

        final iPasso = _primeiraLinhaCom(linhas, passo);
        expect(iPasso, greaterThan(0),
            reason: '$caminho não tem o passo "$passo"');
        expect(
          vivas.single,
          greaterThan(iPasso),
          reason: '$caminho: a invocação está fora do passo "$passo"',
        );

        final iAncora = _primeiraLinhaCom(linhas, ancora);
        expect(iAncora, greaterThan(0),
            reason: '$caminho perdeu a âncora "$ancora"');
        expect(
          vivas.single,
          lessThan(iAncora),
          reason: '$caminho: o portão foi deslocado para depois de "$ancora" '
              '— rodaria tarde demais para impedir o artefato',
        );
      }
    });

    test('o agregador continua executando e CONTANDO o gate a11yres', () {
      final texto = _obrigatorio('.github/workflows/ci-os-integracao.yml');
      expect(
        texto,
        contains('roda a11yres    test/casca/a11y_resultado_partida_test.dart'),
        reason: 'o gate a11yres não executa mais a suíte',
      );
      expect(
        RegExp(r'GATES="[^"]*\ba11yres\b').hasMatch(texto),
        isTrue,
        reason: 'a11yres saiu da evidência publicada',
      );
      expect(
        RegExp(r'for k in [^;]*\ba11yres\b[^;]*; do').hasMatch(texto),
        isTrue,
        reason: 'a11yres saiu do portão verde/vermelho — passaria a rodar '
            'sem poder reprovar',
      );
    });

    test('o portão obrigatório da casca alcança a suíte pelo diretório', () {
      // O `build.yml` roda `flutter test test/casca` inteiro, e é ele que
      // bloqueia o APK. Enquanto a suíte morar neste diretório, ela entra
      // nesse portão sem precisar de nome no workflow.
      expect(
        _obrigatorio('.github/workflows/build.yml'),
        contains('flutter test test/casca --reporter expanded'),
        reason: 'o portão da casca deixou de rodar o diretório inteiro, e a '
            'suíte de acessibilidade do Resultado saiu do gate do APK',
      );
    });
  });
}

// ===========================================================================
// RÉGUA E FERRAMENTAS DA OS 16
// ===========================================================================
//
// Os dois pisos e a versão do contrato ficam AQUI, em literal, porque esta
// autoridade é externa à suíte que os usa e à tela que os declara. O digest do
// contrato também: é ele que impede o recarimbo silencioso.

const double kPisoAlvoOS16 = 48;
const double kPisoFonteOS16 = 11;
const String kVersaoContratoOS16 = '1.0.0';
const String kDigestContratoOS16 =
    '3e3a85f2ba53b87ca2e7f310568dc57604ffdb27930fbf6d65cb6f43b311f133';

const String _caminhoContratoOS16 =
    'app/test/casca/contrato_os16_resultado.txt';

/// Lê um caminho RELATIVO À RAIZ do repositório. No CI o scaffold nasce dentro
/// da raiz, então `..` é a raiz — a mesma convenção que o resto deste arquivo
/// já usava para chegar aos workflows.
///
/// Ausência é FALHA, nunca `return`. Este era o buraco da OS 16-R1.
String _obrigatorio(String caminhoNaRaiz) {
  final f = File('../$caminhoNaRaiz');
  if (!f.existsSync()) {
    fail('OS 16: arquivo obrigatório ausente: $caminhoNaRaiz — ausência NÃO é '
        'conformidade');
  }
  return f.readAsStringSync().replaceAll('\r', '');
}

/// SHA-256 do conteúdo com o CR fora. O repositório está em
/// `core.autocrlf=true`: o mesmo commit chega em CRLF no Windows e em LF no
/// runner. O que o digest protege é o conteúdo, não o final de linha.
String _digestOS16(String conteudo) =>
    sha256.convert(utf8.encode(conteudo.replaceAll('\r', ''))).toString();

/// O único valor de uma chave `chave: valor` do contrato.
String _campo(String contrato, String chave) {
  final achados = _repetida(contrato, chave);
  if (achados.length != 1) {
    fail('OS 16: a chave "$chave" aparece ${achados.length} vez(es) no '
        'contrato — esperava exatamente uma');
  }
  return achados.single;
}

int _quantos(String contrato, String chave) => _repetida(contrato, chave).length;

/// Todos os valores de uma chave repetível (`caso`, `workflow`, `declaracao`).
List<String> _repetida(String contrato, String chave) {
  final saida = <String>[];
  for (final linha in contrato.split('\n')) {
    if (!linha.startsWith('$chave:')) continue;
    saida.add(linha.substring(chave.length + 1).trim());
  }
  return saida;
}

/// O fonte sem comentários E sem o CONTEÚDO das strings. Um `test(` escrito
/// dentro de uma string vira `''` e some — iscas textuais não contam como caso.
String _semStrings(String codigo) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < codigo.length) {
    final c = codigo[i];
    if (aspa != null) {
      if (c == r'\') {
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
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// As linhas (1-based) em que a invocação aparece como COMANDO: fora de
/// comentário, fora de `echo`/`printf`/heredoc e fora de string.
List<int> _invocacoesVivas(List<String> linhas, String invocacao) {
  final vivas = <int>[];
  for (var i = 0; i < linhas.length; i++) {
    final linha = linhas[i];
    final p = linha.indexOf(invocacao);
    if (p < 0) continue;
    if (linha.trimLeft().startsWith('#')) continue;
    final antes = linha.substring(0, p);
    if (antes.contains('echo') ||
        antes.contains('printf') ||
        antes.contains('<<')) {
      continue;
    }
    if ('"'.allMatches(antes).length.isOdd) continue;
    if ("'".allMatches(antes).length.isOdd) continue;
    vivas.add(i + 1);
  }
  return vivas;
}

/// A primeira linha (1-based) que contém [trecho]; 0 se não houver.
int _primeiraLinhaCom(List<String> linhas, String trecho) {
  for (var i = 0; i < linhas.length; i++) {
    if (linhas[i].contains(trecho)) return i + 1;
  }
  return 0;
}
