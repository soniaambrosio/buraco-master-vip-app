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

import 'dart:io';

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
      // CONVERTIDO PARA A ARQUITETURA DA RAIZ P.
      //
      // Este caso exigia `GATES="...perfilvis..."` e `for k in ...perfilvis...`
      // DENTRO do YAML. Na folha de origem isso era exato — era o mecanismo M
      // que protegia a suíte. A raiz P ABOLIU as duas listas embutidas: elas
      // eram o defeito CI-02 (a lista da evidência divergindo da lista do
      // agregador, e o portão ficando verde com gate vermelho). A relação de
      // gates vive em `scripts/ci/gates_os_integracao.txt`, e copiá-la para o
      // YAML é proibido pelo cabeçalho daquele arquivo.
      //
      // Exigir aqui o que a raiz proíbe faria as duas fontes únicas se
      // reprovarem mutuamente. A prova foi CONVERTIDA, e continua provando o
      // mesmo: que apagar a suíte não silencia o gate. Ficou mais forte, na
      // verdade — além de executor e registro, confere o CONTRATO (digest e
      // piso), que o mecanismo M não tinha.
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();
      expect(
        texto,
        contains('roda perfilvis  test/perfil/identidade_visitada_test.dart'),
        reason: 'o gate perfilvis não executa mais a suíte',
      );

      final fonte = File('../scripts/ci/gates_os_integracao.txt');
      if (!fonte.existsSync()) return;
      final relacao = fonte.readAsStringSync();
      expect(
        RegExp(r'^perfilvis$', multiLine: true).hasMatch(relacao),
        isTrue,
        reason: 'perfilvis saiu da fonte única de gates — o agregador deixa '
            'de percorrê-lo e ele passa a rodar sem decidir nada',
      );
      for (final atributo in const [
        'suite      app/test/perfil/identidade_visitada_test.dart',
        'executor   roda perfilvis test/perfil/identidade_visitada_test.dart',
      ]) {
        expect(
          relacao,
          contains(atributo),
          reason: 'o contrato de perfilvis perdeu "$atributo"',
        );
      }
      expect(
        RegExp(r'perfilvis[^a-z]', multiLine: true).hasMatch(relacao),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // O PORTÃO DA ATESTAÇÃO ANDROID
  //
  // Mesma ideia, e pelo mesmo motivo, do bloco acima: a guarda de um gate não
  // pode morar dentro da suíte que ele executa. `app_check_android_test.dart`
  // prova que `main.dart` ativa App Check na ordem certa e com o provedor
  // certo; se ALGUÉM apagar aquele arquivo, aquelas provas somem sem um ruído.
  //
  // A prova de que ele existe e é obrigatório mora AQUI — num gate que já é
  // obrigatório, que fala da casca, e cuja porta de entrada é justamente o
  // arquivo em questão. Não é mistura de assunto: `main.dart` é o objeto desta
  // auditoria desde a primeira linha dela.
  // -------------------------------------------------------------------------
  group('o portão da atestação Android', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');
    final fonte = File('../scripts/ci/gates_os_integracao.txt');

    test('a suíte existe na árvore', () {
      expect(
        File('test/casca/app_check_android_test.dart').existsSync(),
        isTrue,
        reason: 'a suíte que prova a ativação do App Check sumiu — e some em '
            'silêncio, porque ausência vira NÃO EXECUTADO no portão',
      );
    });

    test('o workflow a executa e a considera no portão', () {
      if (!workflow.existsSync()) return;
      // A LINHA TEM DE ESTAR VIVA, e não só presente. `contains` do literal
      // casaria com `# roda appcheckandroid …` — a forma mais barata de tirar
      // um gate do ar sem apagar nada, e foi assim que a campanha negativa
      // desta OS mediu esta guarda passando enquanto o gate não rodava. A
      // âncora de início de linha só admite espaço antes do `roda`.
      expect(
        RegExp(
          r'^[ \t]*roda appcheckandroid '
          r'test/casca/app_check_android_test\.dart[ \t]*$',
          multiLine: true,
        ).hasMatch(workflow.readAsStringSync()),
        isTrue,
        reason: 'o gate appcheckandroid não executa mais a suíte — apagado, '
            'renomeado ou comentado',
      );

      if (!fonte.existsSync()) return;
      final relacao = fonte.readAsStringSync();
      expect(
        RegExp(r'^appcheckandroid$', multiLine: true).hasMatch(relacao),
        isTrue,
        reason: 'appcheckandroid saiu da fonte única de gates — o agregador '
            'deixa de percorrê-lo e ele passa a rodar sem decidir nada',
      );
      for (final atributo in const [
        'suite      app/test/casca/app_check_android_test.dart',
        'executor   roda appcheckandroid test/casca/app_check_android_test.dart',
      ]) {
        expect(
          relacao,
          contains(atributo),
          reason: 'o contrato de appcheckandroid perdeu "$atributo"',
        );
      }
    });

    test('o verificador de contrato exige o gate e não deixa o piso cair', () {
      final verificador = File('../scripts/ci/verificar_contrato_suites.sh');
      if (!verificador.existsSync()) return;
      final texto = verificador.readAsStringSync();
      expect(
        RegExp(r'CONTRATOS_MINIMOS=.*appcheckandroid').hasMatch(texto),
        isTrue,
        reason: 'sem a régua, apagar a entrada inteira da fonte única passa em '
            'SILÊNCIO — e um gate que some sem reprovar é um gate que não existe',
      );
      expect(
        RegExp(r'PISOS_PROVAS=.*appcheckandroid:26').hasMatch(texto),
        isTrue,
        reason: 'sem o piso declarado aqui, rebaixar `provas` na fonte única '
            'esvazia a suíte com o portão verde',
      );
      expect(
        RegExp(r'PISOS_CASOS=.*appcheckandroid:26').hasMatch(texto),
        isTrue,
        reason: 'o piso executado é a outra metade: `provas` é estático e não '
            'vê caso que deixou de rodar',
      );
    });
  });
}
