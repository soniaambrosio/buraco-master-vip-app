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
        gatesDaEvidencia(texto),
        contains('perfilvis'),
        reason: 'perfilvis saiu da evidência publicada',
      );
      // -------------------------------------------------------------------
      // POR QUE ESTA CONFERÊNCIA NÃO OLHA MAIS A LINHA DO `for`
      // -------------------------------------------------------------------
      //
      // Ela olhava: a regex exigia a chave DENTRO da linha do laço. Enquanto a
      // lista do veredito era literal ali, as duas coisas eram a mesma; quando
      // a OS 29-C1 moveu a lista para `LISTA="..."` — para que a conferência de
      // gates obrigatórios lesse a MESMA lista que o laço percorre —, a regex
      // parou de casar e reprovou um portão íntegro.
      //
      // Escrever a lista literal no `for` E numa variável devolveria a regex ao
      // verde e criaria duas declarações da mesma lista, que é o defeito que a
      // C1 tinha ido corrigir: elas divergem, e a que decide não é a que se lê.
      //
      // Então o que se confere agora é o que sempre importou — que a chave está
      // na lista que o laço PERCORRE. `listaDoVeredito` só devolve a lista
      // depois de confirmar que o laço a percorre; se alguém trocar
      // `for k in $LISTA` por outra coisa, ela falha alto em vez de aprovar uma
      // lista que ninguém lê.
      expect(
        listaDoVeredito(texto),
        contains('perfilvis'),
        reason: 'perfilvis saiu do portão verde/vermelho — passaria a rodar '
            'sem poder reprovar',
      );
    });
  });

  // ===========================================================================
  // O PORTÃO DAS SUÍTES QUE NÃO PODEM SUMIR NEM DEIXAR DE SER CONFERIDAS
  // ===========================================================================
  //
  // Mesma ideia do grupo acima, um degrau mais fundo.
  //
  // `exige` fecha o caminho do ARQUIVO ausente, e a lista `OBRIGATORIOS` do
  // veredito fecha os dois caminhos do gate que não executa. Só que declarar uma
  // chave obrigatória é, ele próprio, um ato que ninguém conferia: a OS 29-R1
  // injetou a mutação de tirar `mesac1` de `OBRIGATORIOS` e ela SOBREVIVEU,
  // porque nenhuma suíte lia essa lista. O portão continuava verde tendo perdido
  // a única coisa que o obrigava a reprovar.
  //
  // A conferência mora AQUI, e não dentro das suítes que ela protege, pelo mesmo
  // motivo do grupo de cima: uma prova escrita dentro do que ela garante morre
  // junto com ele. `cascaaud` é obrigatório, fala de outro assunto, e roda nos
  // dois workflows.
  group('o portão das suítes obrigatórias da Mesa de Treino', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');
    final build = File('../.github/workflows/build.yml');

    /// A chave do gate e a suíte que ela vigia, relativa a `app/`.
    const suites = <String, String>{
      'mesacar': 'test/casca/mesa_treino_caracterizacao_test.dart',
      'mesaa11y': 'test/casca/mesa_treino_acessivel_test.dart',
      'mesac1': 'test/casca/mesa_treino_alvos_reais_test.dart',
      'disposicao': 'test/cartas/disposicao_da_mao_test.dart',
    };

    test('as quatro suítes existem na árvore', () {
      for (final e in suites.entries) {
        expect(
          File(e.value).existsSync(),
          isTrue,
          reason: 'a suíte do gate ${e.key} sumiu — e some em silêncio, porque '
              'ausência de arquivo vira NÃO EXECUTADO no portão',
        );
      }
    });

    test('o workflow as exige, e não apenas as roda', () {
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();

      for (final e in suites.entries) {
        // `exige`, e não `roda`: a diferença entre as duas é o que acontece
        // quando o arquivo não está lá. `roda` escreve NÃO EXECUTADO, e NÃO
        // EXECUTADO não soma no fail.
        expect(
          RegExp(
            '^ *exige +' + e.key + ' +' + RegExp.escape(e.value) + r'[ \t]*[\r\n]',
            multiLine: true,
          ).hasMatch(texto),
          isTrue,
          reason: 'o gate ${e.key} não exige ${e.value} — foi rebaixado para '
              'roda, apontado para outro caminho, ou saiu do workflow',
        );
      }
    });

    test('as quatro chaves estão nas três listas do veredito', () {
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();

      final gates = gatesDaEvidencia(texto);
      final lista = listaDoVeredito(texto);
      final obrigatorios = declaracoesDe(texto, 'OBRIGATORIOS');

      // As duas declarações de OBRIGATORIOS — a do passo da evidência e a do
      // veredito — são shells diferentes, então a lista se repete. Repetida e
      // DIVERGENTE seria pior do que não existir: o relatório diria uma coisa e
      // o portão faria outra.
      expect(
        obrigatorios,
        hasLength(2),
        reason: 'o workflow declara ${obrigatorios.length} listas de gates '
            'obrigatórios, e são duas: a da evidência e a do veredito',
      );
      expect(
        obrigatorios.first,
        orderedEquals(obrigatorios.last),
        reason: 'as duas declarações de OBRIGATORIOS divergiram',
      );

      for (final chave in suites.keys) {
        expect(gates, contains(chave),
            reason: '$chave saiu da evidência publicada');
        expect(lista, contains(chave),
            reason: '$chave saiu da lista que o veredito percorre — passaria a '
                'rodar sem poder reprovar');
        expect(obrigatorios.first, contains(chave),
            reason: '$chave deixou de ser obrigatório: um passo que não chegue '
                'a rodar volta a sair VERDE');
      }
    });

    test('o build.yml nomeia os quatro caminhos e roda os dois diretórios', () {
      if (!build.existsSync()) return;
      final texto = build.readAsStringSync();

      for (final caminho in suites.values) {
        expect(
          texto,
          contains('app/' + caminho),
          reason: 'o portão de qualidade do APK não nomeia $caminho — apagá-lo '
              'derrubaria a contagem e deixaria o portão verde',
        );
      }
      // test/cartas não cai dentro de test/casca: sem os dois nomes, a regra da
      // mão deixa de rodar no portão que produz o APK.
      expect(
        texto,
        contains('flutter test test/casca test/cartas'),
        reason: 'o portão do APK parou de rodar um dos dois diretórios',
      );
    });
  });

  // =========================================================================
  // A GUARDA EXTERNA DA SUÍTE DO DESENHO DA OBRIGAÇÃO (OS 29-C4)
  // =========================================================================
  //
  // POR QUE ESTA GUARDA MORA AQUI, E NÃO NO ARQUIVO QUE ELA GUARDA.
  //
  // `mesa_treino_alvos_reais_test.dart` é o portão do gate `mesac1`, e o caso
  // que prova o DESENHO da carta obrigatória do lixo é a única coisa daquele
  // arquivo que ninguém confere. A OS 29-C3 escreveu a conferência lá dentro; a
  // OS 29-R3 mediu o que isso não pega, e são seis sabotagens:
  //
  //   * apagar o grupo inteiro (`mesac1 +26`, `cascaaud +23`);
  //   * um arquivo-isca de mesmo nome, que troca corpo E guarda no mesmo gesto
  //     (`build.yml exit 0`, "PORTÃO VERDE");
  //   * uma isca que LÊ a guarda, cita os nove nomes dela e traz catorze
  //     `expect` vazios;
  //   * retirar do caso a afirmação de `USE ESTA`, da borda ou da sombra, uma a
  //     uma — os nomes sobreviviam no laço "e em nenhuma outra", e o piso de
  //     afirmações era atingido pelo que sobrava.
  //
  // A raiz das quatro é a mesma: a guarda cobrava MENÇÃO, e morava dentro do
  // que a isca substitui. Aqui ela cobra três coisas de naturezas diferentes, e
  // é a soma delas que fecha:
  //
  //   1. IDENTIDADE — o digest normalizado do arquivo inteiro. Isca, corpo
  //      trocado, linha a menos: reprova na hora, sem precisar saber o que
  //      mudou.
  //   2. FORMA — os nomes e a quantidade EXATA dos casos, e os trechos
  //      protegidos, delimitados por marcadores que ficam FORA dos corpos e por
  //      isso sobrevivem a um corpo trocado.
  //   3. CONTEÚDO — cada prova exigida tem de aparecer DENTRO do argumento de
  //      um `expect`, o número de vezes pedido. É o que separa afirmar de
  //      citar, e é o que a contagem de `expect(` nunca separou.
  //
  // O digest sozinho seria uma âncora que se realinha: quem esvaziasse o
  // arquivo atualizaria a constante no mesmo commit e seguiria. Por isso 2 e 3
  // continuam de pé DEPOIS do realinhamento — e é essa a mutação que a OS 29-C4
  // acrescentou à campanha.
  //
  // A metade RECÍPROCA mora na suíte protegida: ela confere que este bloco
  // existe, que os casos dele continuam aqui e que o código dele bate com um
  // digest. Nenhum dos dois cai sozinho, e derrubar o par derruba dois gates.
  //
  // O digest deste bloco, que a suíte protegida guarda, é calculado sobre o
  // CÓDIGO — sem comentário — e sem a linha marcada `[digest-movel]`. As duas
  // exclusões existem para que os dois arquivos não entrem em recursão e para
  // que revisar prosa não exija recalcular nada.
  // >>> GUARDA EXTERNA DA SUITE DO DESENHO - INICIO
  group('a guarda externa da suíte do desenho da obrigação', () {
    const alvo = 'test/casca/mesa_treino_alvos_reais_test.dart';

    /// O digest normalizado do arquivo protegido. [digest-movel]
    const digestDaSuite = '85aa96eb291e9b354e6b690adbdfa56be627f4bc48d74404a10583d277621470'; // [digest-movel]

    /// Os casos da suíte protegida, na ordem em que ela os declara.
    ///
    /// Nomes E quantidade: só a quantidade deixaria trocar um caso por outro, e
    /// só os nomes deixariam acrescentar um caso vazio para inflar o placar.
    const casosEsperados = <String>[
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

    /// O que cada trecho protegido tem de continuar AFIRMANDO, e quantas vezes.
    ///
    /// A agulha é procurada dentro do ARGUMENTO de um `expect`, nunca no texto
    /// solto: citar `temBordaDaObrigacao(` num comentário, num nome de variável
    /// ou num `reason` não é afirmar nada com ele.
    const afirmacoes = <String, Map<String, int>>{
      'SINAIS DA OBRIGACAO': <String, int>{
        'cor.a': 1,
        'kContrasteMinimoDaOrientacao': 1,
        'find.text(kOrientacaoDaObrigacao)': 1,
        'orientacoesNaCarta(': 2,
        'temBordaDaObrigacao(': 2,
        'temSombraDaObrigacao(': 2,
        'sombraTemGeometria(': 1,
        'anunciosDaObrigacao(': 1,
        'homonimas.length': 1,
      },
      'GUARDA DO DESENHO DA OBRIGACAO': <String, int>{
        'selecionadasNaMao(': 2,
        'fileirasDaMao(': 1,
        'anunciosDaObrigacao(': 1,
        'find.text(kOrientacaoDaObrigacao)': 1,
        'temBordaDaObrigacao(': 1,
        'temSombraDaObrigacao(': 1,
        'orientacoesNaCarta(': 1,
        'cartasNaOrdemDeLeitura(tester)': 1,
      },
      'LARGURAS NOMINAIS': <String, int>{
        'kLargurasNominais': 2,
        'voltas': 1,
        'visitadas': 1,
        '<double>{320, 360, 412}': 1,
      },
      'DESTAQUE SEM OBRIGACAO': <String, int>{
        'anunciosDaObrigacao(': 2,
        'find.text(kOrientacaoDaObrigacao)': 1,
        'temBordaDaObrigacao(': 1,
        'temSombraDaObrigacao(': 1,
        'orientacoesNaCarta(': 1,
        'kBaralhosSemObrigacao': 1,
      },
      'MOTOR DA OBRIGACAO': <String, int>{
        'lixoTopoObrigatorio': 4,
        'j.vez': 3,
        'j.descartar(': 2,
        'j.baixar(': 1,
        'j.comprarLixo(': 2,
        'j.jaComprou': 1,
        'm.gemea.id': 2,
      },
    };

    /// O que cada trecho protegido tem de continuar CHAMANDO.
    ///
    /// Chamada não é afirmação, e por isso a lista é curta: só entra aqui o que
    /// não pode viver dentro de um `expect` — montar o estado, avançar o
    /// relógio, cumprir a obrigação, visitar os quatro momentos.
    const chamadas = <String, Map<String, int>>{
      'GUARDA DO DESENHO DA OBRIGACAO': <String, int>{
        'abrirComObrigacaoDoLixo(': 1,
        'comHomonimaNaMao: true': 1,
        'pump(kDepoisDoDourado)': 1,
        'cumprirAObrigacao(': 1,
        'exigirOsTresSinais(': 5,
        "momento: 'escolhida'": 1,
        "momento: 'desmarcada'": 1,
        "momento: 'no rebuild'": 1,
        "momento: 'reorganizada'": 1,
      },
      'LARGURAS NOMINAIS': <String, int>{'pisoEm(': 1},
      'DESTAQUE SEM OBRIGACAO': <String, int>{
        'abrirComObrigacaoDoLixo(': 1,
        'abrirMesaDeTreino(': 1,
      },
      'MOTOR DA OBRIGACAO': <String, int>{'mesaPosta()': 2, 'Jogo(': 1},
    };

    /// O piso de afirmações de cada trecho protegido.
    ///
    /// Grosseiro de propósito: ele não julga qualidade, só impede que o trecho
    /// vire casca depois que alguém realinhar o digest.
    const pisoDeAfirmacoes = <String, int>{
      'SINAIS DA OBRIGACAO': 14,
      'GUARDA DO DESENHO DA OBRIGACAO': 10,
      'LARGURAS NOMINAIS': 6,
      'DESTAQUE SEM OBRIGACAO': 8,
      'MOTOR DA OBRIGACAO': 14,
    };

    String semFimDeLinhaDeMaquina(String t) =>
        t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    String digestDe(String t) =>
        sha256.convert(utf8.encode(semFimDeLinhaDeMaquina(t))).toString();

    String fonte() {
      final f = File(alvo);
      expect(
        f.existsSync(),
        isTrue,
        reason: 'a suíte protegida não está em $alvo — e some em silêncio, '
            'porque ausência de arquivo vira NÃO EXECUTADO no portão',
      );
      return semFimDeLinhaDeMaquina(f.readAsStringSync());
    }

    List<String> codigo(String texto) => <String>[
          for (final l in texto.split('\n'))
            if (!l.trimLeft().startsWith('//')) l,
        ];

    String trecho(String texto, String nome) {
      final linhas = texto.split('\n');
      final a = linhas.indexWhere((l) => l.trim() == '// >>> $nome - INICIO');
      final b = linhas.indexWhere((l) => l.trim() == '// <<< $nome - FIM');
      expect(
        a,
        greaterThanOrEqualTo(0),
        reason: 'o marcador de início de "$nome" sumiu da suíte protegida',
      );
      expect(
        b,
        greaterThan(a),
        reason: 'o marcador de fim de "$nome" sumiu ou trocou de lugar com o '
            'de início',
      );
      return codigo(linhas.sublist(a + 1, b).join('\n')).join('\n');
    }

    /// Os argumentos de cada `expect(...)`, com parênteses balanceados e aspas
    /// respeitadas.
    ///
    /// Contar `expect(` seria contar menção — a OS 29-R3 passou por uma isca
    /// com catorze `expect` vazios. O que interessa é o que está DENTRO.
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
        while (p < corpo.length && nivel > 0) {
          final c = corpo[p];
          if (aspa != null) {
            if (c == r'\') {
              p += 2;
              continue;
            }
            if (c == aspa) aspa = null;
          } else if (c == "'" || c == '"') {
            aspa = c;
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

    List<String> casosDe(String texto) => RegExp(
          "^\\s*(?:testWidgets|test)\\(\\s*'((?:[^'\\\\]|\\\\.)*)'",
          multiLine: true,
        ).allMatches(codigo(texto).join('\n')).map((m) => m.group(1)!).toList();

    test('a suíte protegida está no caminho declarado e bate com o digest', () {
      final texto = fonte();
      expect(
        digestDe(texto),
        digestDaSuite,
        reason: 'o conteúdo de $alvo mudou. Se a mudança é legítima, o digest '
            'novo entra AQUI no mesmo commit — é esse gesto que impede que a '
            'suíte seja trocada por uma isca de mesmo nome sem ninguém ver',
      );
      // Um digest bate com um arquivo vazio tão bem quanto com o certo, se
      // alguém realinhar os dois. O tamanho é a segunda pergunta.
      final linhas = texto.split('\n').length;
      expect(
        linhas,
        greaterThan(1000),
        reason: 'a suíte protegida encolheu para $linhas linhas',
      );
    });

    test('os casos da suíte protegida são exatamente estes', () {
      final casos = casosDe(fonte());
      expect(
        casos,
        orderedEquals(casosEsperados),
        reason: 'os casos de $alvo deixaram de ser os declarados: um caso '
            'retirado sai do placar em silêncio, e um caso acrescentado infla '
            'o placar sem provar nada',
      );
      expect(
        casos.toSet(),
        hasLength(casos.length),
        reason: 'dois casos da suíte protegida têm o mesmo nome',
      );
    });

    test('cada trecho protegido continua AFIRMANDO o que promete', () {
      final texto = fonte();
      for (final nome in pisoDeAfirmacoes.keys) {
        final corpo = trecho(texto, nome);
        final argumentos = argumentosDeExpect(corpo);
        expect(
          argumentos.length,
          greaterThanOrEqualTo(pisoDeAfirmacoes[nome]!),
          reason: 'o trecho "$nome" ficou com ${argumentos.length} afirmações',
        );
        for (final e in (afirmacoes[nome] ?? const <String, int>{}).entries) {
          final quantas = argumentos.where((a) => a.contains(e.key)).length;
          expect(
            quantas,
            greaterThanOrEqualTo(e.value),
            reason: 'o trecho "$nome" afirma ${e.key} $quantas vez(es), e a '
                'prova pede ${e.value}: a agulha continuar escrita no arquivo '
                'não é a mesma coisa que ela estar dentro de um expect',
          );
        }
        for (final e in (chamadas[nome] ?? const <String, int>{}).entries) {
          final quantas = e.key.allMatches(corpo).length;
          expect(
            quantas,
            greaterThanOrEqualTo(e.value),
            reason: 'o trecho "$nome" chama ${e.key} $quantas vez(es), e a '
                'prova pede ${e.value}',
          );
        }
      }
    });

    test('a suíte exercita 320, 360 e 412 e protege o piso de 48', () {
      final texto = fonte();
      expect(
        texto,
        contains('const List<double> kLargurasNominais = <double>[320, 360, 412];'),
        reason: 'as três larguras nomeadas pela OS deixaram de estar '
            'declaradas em $alvo',
      );
      expect(
        texto,
        contains('const double kPisoExigido = 48.0;'),
        reason: 'o piso de toque deixou de ser 48 na suíte protegida',
      );
      // O piso é afirmado com desigualdade, e por isso o NÚMERO precisa de uma
      // afirmação própria: sem ela, baixá-lo de 48 para 46 sai verde.
      final guardaDoPiso = argumentosDeExpect(codigo(texto).join('\n'))
          .where((a) => a.replaceAll(' ', '').startsWith('kPisoExigido,48.0'))
          .toList();
      expect(
        guardaDoPiso,
        isNotEmpty,
        reason: 'o piso de 48 é usado com greaterThanOrEqualTo e não tem '
            'guarda própria: baixar a constante do TESTE passaria despercebido',
      );
      final larguras = trecho(texto, 'LARGURAS NOMINAIS');
      for (final l in <String>['320', '360', '412']) {
        expect(
          larguras,
          contains(l),
          reason: 'o cenário de $l pontos saiu do trecho que os exercita',
        );
      }
    });

    test('a suíte protegida guarda esta auditoria de volta', () {
      final texto = fonte();
      for (final t in <String>[
        "const String kCaminhoDaGuardaExterna = 'test/casca/auditoria_casca_test.dart';",
        '// >>> GUARDA EXTERNA DA SUITE DO DESENHO - INICIO',
        'kDigestDaGuardaExterna',
        'blocoDaGuardaExterna(',
      ]) {
        expect(
          texto,
          contains(t),
          reason: 'a metade recíproca da guarda saiu da suíte protegida: sem '
              'ela, retirar este bloco seria um gesto isolado e silencioso',
        );
      }
    });
  });
  // <<< GUARDA EXTERNA DA SUITE DO DESENHO - FIM
}

// ===========================================================================
// LER AS LISTAS DO WORKFLOW COMO LISTAS, E NÃO COMO TEXTO
// ===========================================================================
//
// Uma regex sobre o texto cru confunde a FORMA da declaração com o CONTEÚDO
// dela. Foi o que derrubou `cascaaud` na OS 29-C1: a chave continuava
// conferida, e a linha em que ela aparecia tinha mudado. Aqui a declaração é
// lida uma vez e vira lista de chaves; o que os casos afirmam é pertinência.

/// Toda declaração de shell `NOME="a b c"` do workflow, já quebrada em chaves.
List<List<String>> declaracoesDe(String texto, String nome) =>
    RegExp('^ *' + nome + '="([^"]*)"', multiLine: true)
        .allMatches(texto)
        .map((m) => m
            .group(1)!
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList())
        .toList();

/// A lista de gates da evidência publicada.
List<String> gatesDaEvidencia(String texto) {
  final ds = declaracoesDe(texto, 'GATES');
  expect(
    ds,
    hasLength(1),
    reason: 'o workflow tem ${ds.length} declarações de GATES, e tem de ter uma',
  );
  return ds.single;
}

/// A lista de gates que o veredito PERCORRE.
///
/// Devolvê-la sem conferir o laço seria aprovar uma lista que ninguém lê: a
/// pertinência só significa alguma coisa se o `for` percorrer esta variável.
List<String> listaDoVeredito(String texto) {
  expect(
    RegExp(r'for +k +in +\$LISTA *; *do').hasMatch(texto),
    isTrue,
    reason: 'o veredito deixou de percorrer a variável LISTA — a conferência '
        'de gates obrigatórios passaria a ler uma lista diferente da que decide',
  );
  final ds = declaracoesDe(texto, 'LISTA');
  expect(
    ds,
    hasLength(1),
    reason: 'o workflow tem ${ds.length} declarações de LISTA, e tem de ter '
        'uma: duas divergem, e a que decide não é a que se lê',
  );
  return ds.single;
}
