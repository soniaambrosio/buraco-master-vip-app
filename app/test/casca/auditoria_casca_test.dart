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

/// As linhas de COMANDO de um passo do workflow, achado pelo nome.
///
/// POR QUE UM BLOCO, E NÃO O ARQUIVO INTEIRO. A OS 37-R1 mediu o preço de
/// afirmar com `contains` sobre o YAML todo: trocar `flutter test test/casca`
/// por `flutter test test/casca/casca_producao_test.dart` deixava a asserção
/// VERDE — o alvo estreitado contém o texto do alvo largo como prefixo —, e a
/// suíte protegida parava de rodar sem uma linha vermelha. Um `contains` acha
/// o que procura e não vê o que mudou em volta.
///
/// Duas coisas mudam aqui. A primeira é o RECORTE: um comando que existe em
/// outro passo não prova nada sobre este, então a busca começa no `- name:`
/// pedido e termina no próximo. A segunda é que COMENTÁRIO NÃO É COMANDO —
/// tanto o do YAML quanto o do shell dentro do `run: |` começam com `#`, e
/// nenhum dos dois executa coisa nenhuma. Sem esse filtro, comentar o comando
/// e deixar a frase escrita ao lado continuaria passando.
///
/// Devolve lista vazia quando o passo não existe — e aí a asserção de quem
/// chamou reprova, que é o comportamento certo: passo apagado é regressão.
List<String> _linhasDoPasso(String yaml, String nomeDoPasso) {
  final linhas = yaml.split('\n').map((l) => l.replaceAll('\r', '')).toList();
  final inicio = linhas.indexWhere(
    (l) => l.trimLeft().startsWith('- name:') && l.contains(nomeDoPasso),
  );
  if (inicio < 0) return const <String>[];
  final saida = <String>[];
  for (var i = inicio + 1; i < linhas.length; i++) {
    final linha = linhas[i];
    if (linha.trimLeft().startsWith('- name:')) break;
    if (linha.trimLeft().startsWith('#')) continue;
    saida.add(linha);
  }
  return saida;
}

/// [padrao] casa com alguma linha de comando de [linhas]?
bool _executa(List<String> linhas, RegExp padrao) =>
    linhas.any(padrao.hasMatch);

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
  // A SUÍTE DOS ESTADOS ANUNCIADOS SOBREVIVE, OU O PORTÃO CAI
  // =========================================================================
  //
  // POR QUE ESTA PROVA MORA AQUI. Pelo mesmo motivo do grupo acima, e a OS 37
  // mediu o preço de não ter feito isso na primeira vez: com
  // `a11y_estados_anunciados_test.dart` apagado, `flutter test test/casca`
  // passou de 267 para 247 casos e imprimiu `All tests passed`, exit 0. Vinte
  // provas de acessibilidade sumiram sem uma linha vermelha — porque o único
  // passo que as executa aponta para o DIRETÓRIO, e um diretório com menos
  // arquivos continua sendo um diretório válido.
  //
  // Uma prova escrita dentro da suíte morreria junto com ela. Escrita aqui,
  // num gate que já é obrigatório em `casca` (o diretório, no `build.yml`) e em
  // `cascaaud` (o caminho explícito, no `ci-os-integracao.yml`), ela sobrevive
  // ao apagamento e o denuncia.
  //
  // O QUE ESTE GRUPO NÃO FAZ, e por quê: ele não cria chave de gate nova, não
  // escreve `GATES=` e não acrescenta `for k in`. A OS 32 canonizou a família P
  // — os gates saem de UMA fonte, lida por um produtor só — e o jeito antigo de
  // registrar um gate aqui era digitar a mesma chave em duas listas do YAML,
  // que é exatamente o defeito que a OS 32 fechou. Registrar por conta própria
  // criaria a segunda autoridade de novo, nesta folha, para desfazer na
  // composição. A ligação da suíte à fonte única é UMA LINHA no inventário de P,
  // e é lá que ela será feita. Até lá, o contrato de conteúdo abaixo é o que
  // impede a suíte de sumir em silêncio.
  group('o portão dos estados anunciados', () {
    const caminho = 'test/casca/a11y_estados_anunciados_test.dart';

    // Os grupos que a OS 37 e a OS 37-C1 tornaram obrigatórios. A lista é de
    // CENÁRIOS, não de casos: renomear um caso é manutenção, apagar um eixo
    // inteiro é regressão, e só o segundo derruba isto aqui.
    const cenarios = <String>[
      "group('a vez'",
      "group('a recusa de comando'",
      "group('a recusa do lobby, tentativa a tentativa'",
      "group('a conexão'",
      "group('o login'",
      "group('a entrada na mesa'",
      "group('o monte e os mortos'",
      "group('o protocolo e a partida não mudaram'",
      "group('a recusa do lobby ao criar mesa'",
    ];

    // PISO, e não meta. Serve contra o arquivo esvaziado e contra o `main()`
    // trivial — dois casos que passam verdes e não provam nada. Subir o piso
    // quando a suíte crescer é opcional; baixá-lo exige explicar o que saiu.
    const pisoDeCasos = 36;

    test('a suíte existe na árvore', () {
      expect(
        File(caminho).existsSync(),
        isTrue,
        reason:
            'a suíte dos estados anunciados sumiu (apagada ou renomeada) — e '
            'some em silêncio, porque o passo do CI roda o diretório inteiro',
      );
    });

    test('a suíte ainda cobre os cenários obrigatórios', () {
      final f = File(caminho);
      if (!f.existsSync()) return; // o caso acima já reprovou por isso
      // SEM COMENTÁRIOS: um cenário comentado não é um cenário. É a mesma
      // razão de `_codigo` existir no resto deste arquivo.
      final fonte = _codigo(f);
      for (final cenario in cenarios) {
        expect(
          fonte,
          contains(cenario),
          reason: 'o cenário $cenario saiu da suíte dos estados anunciados',
        );
      }
    });

    test('a suíte não foi esvaziada', () {
      final f = File(caminho);
      if (!f.existsSync()) return;
      final fonte = _codigo(f);
      final casos = RegExp('testWidgets' r'\s*\(').allMatches(fonte).length;
      expect(
        casos,
        greaterThanOrEqualTo(pisoDeCasos),
        reason:
            'a suíte caiu para $casos casos (piso $pisoDeCasos) — um arquivo '
            'que existe e não afirma nada é pior do que um que não existe, '
            'porque o portão fica verde',
      );
    });

    // A ÂNCORA É ESTRUTURAL, e a fronteira de palavra é o que a OS 37-R1
    // provou indispensável. `flutter test test/casca` é PREFIXO de
    // `flutter test test/casca/casca_producao_test.dart` e de qualquer
    // subdiretório mais estreito: exigir que o próximo caractere seja espaço
    // ou fim de linha é o que separa "roda o diretório" de "roda um arquivo,
    // e o resto do diretório some".
    final rodaODiretorio = RegExp(r'(^|\s)flutter test test/casca(\s|$)');
    final copiaODiretorio = RegExp(
      r'(^|\s)cp -R app/test/casca/\. app_build/test/casca/(\s|$)',
    );

    test('o passo do build.yml copia e executa o DIRETÓRIO inteiro', () {
      // O overlay do CI roda a partir de `app_build/`, e o workflow fica dois
      // níveis acima. Fora do CI o arquivo pode não estar alcançável — e aí o
      // caso não tem o que afirmar, em vez de afirmar errado.
      final workflow = File('../.github/workflows/build.yml');
      if (!workflow.existsSync()) return;
      final passo = _linhasDoPasso(
        workflow.readAsStringSync(),
        'PORTÃO DE PRODUÇÃO — casca real',
      );

      expect(
        passo,
        isNotEmpty,
        reason:
            'o passo da casca sumiu do build.yml (apagado ou renomeado) — e '
            'com ele param de rodar todas as suítes que não têm chave própria',
      );
      // O ALVO É O DIRETÓRIO, de propósito: é essa forma que faz a suíte
      // rodar sem precisar de chave própria, e é ela que não pode encolher.
      expect(
        _executa(passo, rodaODiretorio),
        isTrue,
        reason:
            'o passo da casca deixou de executar `flutter test test/casca` '
            'como DIRETÓRIO — um alvo mais estreito (um arquivo, um '
            'subdiretório) contém o mesmo texto e apagaria a suíte em silêncio',
      );
      expect(
        _executa(passo, copiaODiretorio),
        isTrue,
        reason:
            'o passo deixou de copiar `test/casca` INTEIRO para o overlay — '
            'uma cópia seletiva roda e não encontra o que rodar',
      );
    });
  });

  // =========================================================================
  // O PORTÃO `cascaaud` CONTINUA REGISTRADO NOS TRÊS PONTOS
  // =========================================================================
  //
  // MESMA FORMA DO GRUPO `perfilvis`, e de propósito. Aquele grupo já existia
  // neste arquivo quando a OS 37-C1 escreveu o de cima, e a OS 37-R1 mostrou o
  // custo de não tê-lo copiado: tirar `cascaaud` do `for k in` que decide
  // verde/vermelho deixava TODA a proteção acima verde — a auditoria continuava
  // rodando, escrevia o exit code, e ninguém o lia.
  //
  // ISTO NÃO REGISTRA CHAVE NENHUMA. A chave `cascaaud` já existe no workflow
  // desde a OS da Casca de Produção; este grupo só LÊ o YAML e exige que ela
  // continue nos três lugares onde precisa estar. Não há `GATES=` escrito aqui,
  // não há `for k in` escrito aqui, e `.github/` não é tocado — que é
  // exatamente a distinção que a OS 32 canonizou: REGISTRAR uma chave nova
  // exigiria digitá-la em duas listas do YAML, o defeito que a família P
  // fechou; AFIRMAR que uma chave existente continua nas duas é leitura pura.
  //
  // O que a fonte única P vai absorver desta folha é o contrato de CONTEÚDO da
  // suíte dos estados anunciados, não este grupo: este continua valendo
  // enquanto o `ci-os-integracao.yml` desta linhagem tiver as duas listas
  // literais.
  group('o portão cascaaud', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');

    // O caminho registrado tem de ser o DESTE arquivo: registro que aponta
    // para outro lugar é registro morto, e um gate que executa outra coisa
    // não prova o que o nome dele promete.
    final rodaEstaAuditoria = RegExp(
      r'(^|\s)roda\s+cascaaud\s+test/casca/auditoria_casca_test\.dart(\s|$)',
    );
    final naEvidencia = RegExp(r'GATES="[^"]*\bcascaaud\b');
    final noVeredito = RegExp(r'for k in [^;]*\bcascaaud\b[^;]*; do');

    test('cascaaud executa ESTA auditoria', () {
      if (!workflow.existsSync()) return;
      final passo = _linhasDoPasso(
        workflow.readAsStringSync(),
        'analyze + suítes Flutter',
      );
      expect(
        passo,
        isNotEmpty,
        reason: 'o passo que roda as suítes Flutter sumiu do ci-os-integracao',
      );
      expect(
        _executa(passo, rodaEstaAuditoria),
        isTrue,
        reason:
            'o gate cascaaud não executa mais '
            'test/casca/auditoria_casca_test.dart — ou saiu, ou passou a '
            'apontar para outro arquivo',
      );
      // Coerência entre registro e execução: o caminho registrado existe.
      expect(
        File('test/casca/auditoria_casca_test.dart').existsSync(),
        isTrue,
        reason: 'o caminho registrado em cascaaud não existe na árvore',
      );
    });

    test('cascaaud está nas DUAS listas do portão', () {
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();
      // Nas DUAS: a da evidência publicada e a que decide verde/vermelho.
      // Estar só na primeira faz o gate aparecer no relatório e não reprovar.
      expect(
        naEvidencia.hasMatch(texto),
        isTrue,
        reason: 'cascaaud saiu da evidência publicada',
      );
      expect(
        noVeredito.hasMatch(texto),
        isTrue,
        reason:
            'cascaaud saiu do portão verde/vermelho — a auditoria passaria a '
            'rodar sem poder reprovar, e toda a proteção deste arquivo ficaria '
            'decorativa',
      );
    });

    test('cascaaud não está duplicado nem registrado morto', () {
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();
      final passo = _linhasDoPasso(texto, 'analyze + suítes Flutter');

      // DUPLICATA: dois `roda` para a mesma chave fazem o segundo sobrescrever
      // o exit code do primeiro, e o portão passa a ler só metade.
      expect(
        passo.where(rodaEstaAuditoria.hasMatch).length,
        1,
        reason: 'cascaaud aparece mais de uma vez entre os passos `roda`',
      );
      expect(
        RegExp(r'\bcascaaud\b').allMatches(texto).length,
        3,
        reason:
            'cascaaud deixou de aparecer exatamente três vezes no workflow '
            '(roda, GATES=, for k in) — sobra é registro duplicado, falta é '
            'registro morto',
      );
    });
  });

  // =========================================================================
  // TRÊS EXPLICAÇÕES QUE FORAM MEDIDAS FALSAS NÃO VOLTAM
  // =========================================================================
  //
  // Este arquivo despoja comentário antes de varrer, e por bom motivo. Aqui,
  // uma vez, ele faz o contrário — e a diferença é o que está sendo afirmado.
  //
  // Nos outros grupos o comentário é RUÍDO: a proibição fala de código, e a
  // prosa que a explica acusaria a si mesma. Aqui o comentário é o OBJETO. As
  // três frases abaixo não são estilo nem opinião: são afirmações sobre o que o
  // programa faz, e a OS 37 mediu as três e achou o contrário. Uma explicação
  // falsa custa mais caro que nenhuma, porque manda a próxima pessoa proteger o
  // caminho errado — e as três apontavam para o lugar errado ao mesmo tempo em
  // que a proteção verdadeira estava a três linhas de distância.
  //
  // O que cada uma dizia, e o que foi medido:
  //
  //   1. "um anúncio preso ao build fala quando alguém gira o aparelho" —
  //      NÃO fala. Com o anúncio movido para o `build`, girar o aparelho,
  //      dobrar a escala de fonte e selecionar uma carta continuam dando zero
  //      anúncio. Quem protege é a `SentinelaDeTransicao`.
  //
  //   2. "sem o `MergeSemantics` a propriedade fica num nó de contêiner e o
  //      rótulo num nó filho" — NÃO fica. `Semantics` sobre um `Text` único já
  //      funde: com e sem o envoltório o nó é o mesmo, mesmo id, região viva
  //      verdadeira, zero filhos.
  //
  //   3. "soltar o ouvinte é o que cala a tela" — NÃO é. Quem cala é a guarda
  //      de `mounted` no alto de `_atualizar`; sem o `removeListener` a tela
  //      desmontada continua muda. O descarte é higiene, e continua
  //      obrigatório por isso.
  //
  // A âncora de cada caso é um trecho curto e literal da frase refutada. Ela só
  // reaparece por reversão — reescrever a explicação com outras palavras não
  // dispara nada, que é o comportamento desejado.
  group('as explicações refutadas pela OS 37 não voltam', () {
    const refutadas = <String, (String, String)>{
      'lib/casca/mesa_online/mesa_online_screen.dart': (
        'um anúncio preso ao',
        'o anúncio no `build` não fala ao girar o aparelho — a sentinela o '
            'impede, e dar o crédito ao lugar da chamada manda a próxima '
            'pessoa proteger o caminho errado',
      ),
      'lib/casca/login_de_producao.dart': (
        'a propriedade fica num nó de contêiner',
        'sem o MergeSemantics o nó é IDÊNTICO — medido na OS 37',
      ),
      'lib/casca/lobby_online.dart': (
        'SOLTAR O OUVINTE É O QUE CALA A TELA',
        'quem cala a tela é a guarda de mounted, não o removeListener',
      ),
    };

    refutadas.forEach((caminho, par) {
      final (trecho, porque) = par;
      test('$caminho não afirma de novo o que foi medido falso', () {
        final f = File(caminho);
        expect(f.existsSync(), isTrue, reason: '$caminho sumiu');
        // COM comentário, de propósito: aqui a frase é o objeto da prova.
        expect(
          f.readAsStringSync(),
          isNot(contains(trecho)),
          reason: porque,
        );
      });
    });
  });
}
