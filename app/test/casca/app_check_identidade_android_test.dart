// app_check_identidade_android_test.dart — a matriz da OS de App Check.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE PROVA, E O QUE ELA HONESTAMENTE NÃO PODE PROVAR
// ---------------------------------------------------------------------------
//
// Dois tipos de afirmação convivem aqui, e misturá-los seria mentir sobre a
// força da evidência:
//
//   ESTRUTURAL — lê o código-fonte e afirma sobre a FORMA dele. É o único jeito
//   de provar coisas que só existem depois da compilação AOT de release: a
//   ordem de duas linhas dentro de `main()`, a eliminação de um ramo morto, a
//   ausência de um identificador. `flutter test` roda em JIT de depuração, com
//   `kReleaseMode == false`; nenhum `expect` deste processo consegue observar o
//   binário de release. O que ele consegue é garantir que o código foi escrito
//   na forma que o compilador sabe dobrar — e essa é a garantia real.
//
//   COMPORTAMENTAL — constrói os objetos de domínio e exerce a decisão. É o que
//   prova o P0 da Identidade: dado `unauthenticated` com sessão viva, o estado
//   oferece "tentar de novo"; e o retry, quando dá certo, recupera a identidade.
//
// A técnica de despojar comentários antes de varrer é a mesma de
// `auditoria_casca_test.dart`, e pelo mesmo motivo: este arquivo e o `main.dart`
// explicam em prosa o que é proibido, e uma varredura ingênua acusaria a
// explicação como violação. Pior: o jeito de "consertar" seria apagar a
// documentação.

import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/main.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Ferramentas de varredura
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
/// É ISTO que "alcançável" significa aqui, e a distinção decide o veredito: a
/// superfície de risco de uma ativação de App Check não é o que existe em
/// `lib/`, e sim o que o binário publicado consegue chegar a executar partindo
/// de `main()`. Mesmo algoritmo de `auditoria_casca_test.dart`.
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
/// para as Cloud Functions e nunca rodam no aplicativo. Mesmo recorte de
/// `auditoria_casca_test.dart`.
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

// ===========================================================================
// Fonte de identidade encenada
// ===========================================================================

/// Uma fonte que responde o que o caso pedir, uma resposta por chamada.
///
/// Existe para encenar o que o emulador NÃO consegue: o emulador de Functions
/// dispensa App Check por construção (`FUNCTIONS_EMULATOR !== "true"` em
/// `functions-social/src/index.ts`), então ele nunca produz a recusa que esta
/// suíte precisa. Quem produz é este fake.
class _FonteEncenada implements FonteDeIdentidade {
  final List<Completer<IdentidadePublica>> pendentes = [];
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }

  void recusarPorAtestacao() => pendentes.last.completeError(
    const FalhaIdentidade(
      MotivoFalhaIdentidade.credencialOuAtestacao,
      'unauthenticated',
    ),
  );

  void responder(String publicId) => pendentes.last.complete(
    IdentidadePublica(
      publicId: publicId,
      apelido: '',
      avatarRef: null,
      criada: false,
      estado: EstadoPerfil.ativo,
      limites: LimitesSociais.desconhecidos,
      edicao: MetadadosDeEdicao.desconhecidos,
    ),
  );
}

Future<void> _assentar() => Future<void>.delayed(Duration.zero);

void main() {
  late String raiz;

  setUpAll(() {
    raiz = _codigo(File('lib/main.dart'));
    // Uma varredura que não achou nada seria um verde falso: todos os `expect`
    // de ausência passariam sobre uma string vazia.
    expect(raiz, contains('void main()'), reason: 'a matriz precisa do que ler');
  });

  // =========================================================================
  // §6.1 a §6.3 — a ordem do bootstrap
  // =========================================================================
  group('ordem do bootstrap', () {
    test('1 — Firebase.initializeApp precede a ativação do App Check', () {
      final init = raiz.indexOf('Firebase.initializeApp');
      final ativa = raiz.indexOf('FirebaseAppCheck.instance.activate');
      expect(init, isNonNegative, reason: 'initializeApp sumiu de main()');
      expect(ativa, isNonNegative, reason: 'App Check não é ativado em main()');
      expect(
        init,
        lessThan(ativa),
        reason:
            'FirebaseAppCheck.instance resolve Firebase.app(); ativado antes '
            'de initializeApp, morre com [core/no-app] e o app abre sem '
            'atestação nenhuma',
      );
    });

    test('2 — a ativação do App Check precede runApp', () {
      final ativa = raiz.indexOf('FirebaseAppCheck.instance.activate');
      final roda = raiz.indexOf('runApp(');
      expect(roda, isNonNegative);
      expect(
        ativa,
        lessThan(roda),
        reason:
            'runApp é a última linha de main() e é ele que constrói a raiz — '
            'ativar depois deixaria a primeira callable sair sem token',
      );
    });

    test('a ativação tem try/catch PRÓPRIO, e não o herdado do initializeApp', () {
      final init = raiz.indexOf('Firebase.initializeApp');
      final primeiroCatch = raiz.indexOf('catch', init);
      final ativa = raiz.indexOf('FirebaseAppCheck.instance.activate');
      expect(
        primeiroCatch,
        lessThan(ativa),
        reason:
            'a ativação caiu DENTRO do try/catch do initializeApp, que engole '
            'falhas de propósito — o App Check sumiria em silêncio',
      );
      // E ela própria é guardada: sem isso, um ambiente sem configuração
      // Android derruba o main() inteiro e o aplicativo não abre.
      expect(raiz.indexOf('catch', ativa), isNonNegative);
    });

    test('3 — nenhuma das callables sai de main()', () {
      for (final proibido in const [
        'httpsCallable',
        'FirebaseFunctions',
        'obterMinhaIdentidade',
        'abrirRanking',
        'consultarJogadorPorIdPublico',
      ]) {
        expect(
          raiz,
          isNot(contains(proibido)),
          reason: 'main() emitiria $proibido antes de qualquer coisa',
        );
      }
    });

    test('3 — as callables ALCANÇÁVEIS saem de dois adaptadores, e main() não importa nenhum', () {
      final alcancaveis = _alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis.length, greaterThan(5));

      final emissores = <String>[
        for (final caminho in alcancaveis)
          if (File(caminho).existsSync() &&
              _codigo(File(caminho)).contains('httpsCallable'))
            caminho,
      ]..sort();
      expect(emissores, [
        'lib/ranking/ranking_transporte_firebase.dart',
        'lib/sessao/fonte_identidade_firebase.dart',
      ], reason: 'apareceu um terceiro emissor alcançável pela raiz');

      // E o terceiro emissor que existe em `lib/` continua FORA do alcance da
      // raiz. O registro é deliberado: `colecoes/colecao_firebase.dart` chama
      // `claimPioneerKit`, cujo enforcement no backend está atrás de
      // `ENFORCE_APP_CHECK`, hoje desligado. No dia em que alguém reabrir esse
      // caminho, é este `expect` que avisa que a superfície mudou.
      final todos = <String>[
        for (final f in _fontesDoCliente())
          if (_codigo(f).contains('httpsCallable')) _barras(f.path),
      ];
      expect(todos.length - emissores.length, 1);
      expect(
        todos.where((c) => !emissores.contains(c)).single,
        endsWith('lib/colecoes/colecao_firebase.dart'),
      );

      // main.dart importa a casca, e a casca só é construída dentro de runApp.
      expect(raiz, isNot(contains('fonte_identidade_firebase')));
      expect(raiz, isNot(contains('ranking_transporte_firebase')));
    });
  });

  // =========================================================================
  // §6.4 a §6.6 — o provedor por variante
  // =========================================================================
  group('provedor por variante de build', () {
    test('4 e 5 — a escolha é UMA constante de compilação sobre kReleaseMode', () {
      expect(
        raiz,
        contains('const AndroidAppCheckProvider kProvedorDeAtestacao'),
        reason: 'a seleção deixou de ser constante de compilação',
      );
      expect(raiz, contains('kReleaseMode'));
      // Um por lado, e só um: duas menções significariam um segundo caminho.
      expect('AndroidPlayIntegrityProvider'.allMatches(raiz), hasLength(1));
      expect('AndroidDebugProvider'.allMatches(raiz), hasLength(1));
      // E a ordem dos ramos: release é o lado verdadeiro de kReleaseMode.
      expect(
        raiz.indexOf('AndroidPlayIntegrityProvider'),
        lessThan(raiz.indexOf('AndroidDebugProvider')),
        reason: 'os ramos trocaram de lado — release ganharia o depurador',
      );
    });

    test('5 — fora de release o provedor efetivo é o de depuração', () {
      // Este processo roda em JIT de depuração, então kReleaseMode é falso e a
      // constante já foi dobrada para o lado de depuração. É a única metade do
      // par que um teste consegue observar de verdade.
      expect(kReleaseMode, isFalse);
      expect(kProvedorDeAtestacao, isA<AndroidDebugProvider>());
      expect(kProvedorDeAtestacao.type, 'debug');
      expect(const AndroidPlayIntegrityProvider().type, 'playIntegrity');
    });

    test('6 — não há caminho de depuração decidido em tempo de execução', () {
      // O que tornaria o ramo morto VIVO no release: um `if` de runtime, uma
      // variável, um `fromEnvironment` que o build pudesse ligar por engano.
      for (final proibido in const [
        'if (kDebugMode',
        'if (!kReleaseMode',
        'bool.fromEnvironment',
        'String.fromEnvironment',
        'debugToken',
      ]) {
        expect(
          raiz,
          isNot(contains(proibido)),
          reason:
              '$proibido faria as duas classes sobreviverem no artefato de '
              'release, e aí a separação viraria disciplina em vez de estrutura',
        );
      }
    });

    test('6 — nenhum outro arquivo do cliente ativa App Check', () {
      final ativadores = <String>[
        for (final f in _fontesDoCliente())
          if (_codigo(f).contains('FirebaseAppCheck')) _barras(f.path),
      ];
      expect(ativadores, hasLength(1));
      expect(ativadores.single, endsWith('lib/main.dart'));
    });
  });

  // =========================================================================
  // §6.7, §6.8 e §6.14 — a identidade Android e o que não pode entrar no Git
  // =========================================================================
  group('identidade Android', () {
    test('7 — o pacote oficial é o único declarado no cliente', () {
      expect(kPacoteAndroidOficial, 'io.github.soniaambrosio.buracomastervip');
      final declarantes = <String>[
        for (final f in _fontesDoCliente())
          if (_codigo(f).contains(kPacoteAndroidOficial)) _barras(f.path),
      ];
      expect(
        declarantes,
        hasLength(1),
        reason: 'uma segunda cópia literal do pacote diverge no primeiro dia',
      );
      expect(declarantes.single, endsWith('lib/main.dart'));
    });

    test('7 — o appId configurado é o do app Firebase OFICIAL', () {
      expect(raiz, contains('1:203886484007:android:b1cd95baa0b9e6e629cc02'));
      expect(raiz, contains("projectId: 'buraco-master-vip'"));
    });

    test('8 e 9 — o pacote e o appId de teste não existem em lugar nenhum do cliente', () {
      const proibidos = <String, String>{
        '734aaa61': 'o appId do registro "BMV Teste"',
        'com.buracomastervip.poc': 'o pacote de PoC',
        '1a8d6087': 'o appId de "Buraco Master VIP (Android)"',
        '7d871ec4': 'o appId de "buraco-master-vip Android"',
        'com.mycompany': 'o pacote de scaffold do Flutter',
      };
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final codigo = _codigo(f);
        for (final entrada in proibidos.entries) {
          if (codigo.contains(entrada.key)) {
            infratores.add('${_barras(f.path)}: ${entrada.value}');
          }
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'Play Integrity valida o par (pacote, certificado) contra o '
            'registro que o appId nomeia — qualquer um destes de volta recusa '
            'o aplicativo oficial',
      );
    });

    test('14 — nenhum token, chave privada ou segredo no cliente', () {
      const assinaturas = <String>[
        '-----BEGIN',
        'appCheckDebugToken',
        'FIREBASE_APP_CHECK_DEBUG_TOKEN',
        'private_key',
        'serviceAccount',
      ];
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final codigo = _codigo(f);
        for (final a in assinaturas) {
          if (codigo.contains(a)) infratores.add('${_barras(f.path)}: $a');
        }
      }
      expect(infratores, isEmpty);
    });
  });

  // =========================================================================
  // §6.10 a §6.13 — o P0 da Identidade
  // =========================================================================
  group('unauthenticated não é sessão morta', () {
    test('10 — recusa por credencial ou atestação COM sessão viva permite retry', () {
      const falha = FalhaIdentidade(
        MotivoFalhaIdentidade.credencialOuAtestacao,
        'unauthenticated',
      );
      final estado = EstadoIdentidadeSessao.falhou('uid-a', falha);

      expect(estado.fase, FaseIdentidade.falha);
      expect(estado.autenticado, isTrue);
      expect(
        estado.podeTentarDeNovo,
        isTrue,
        reason:
            'é o caso central da OS: App Check ausente ou inválido devolve '
            'unauthenticated com a sessão intacta, e repetir resolve',
      );
    });

    test('12 — sem sessão local, o mesmo motivo NÃO promete retry', () {
      expect(
        MotivoFalhaIdentidade.credencialOuAtestacao.permiteNovaTentativa(
          haSessaoLocal: false,
        ),
        isFalse,
        reason:
            'sem sessão local a afirmação passa a ser verificável, e insistir '
            'na mesma chamada não conserta quem não está logado',
      );
      expect(
        MotivoFalhaIdentidade.credencialOuAtestacao.permiteNovaTentativa(
          haSessaoLocal: true,
        ),
        isTrue,
      );
      // O caminho próprio da sessão realmente ausente continua existindo, e é
      // outra FASE — não uma falha com botão.
      expect(
        EstadoIdentidadeSessao.deslogado.fase,
        FaseIdentidade.naoAutenticado,
      );
      expect(EstadoIdentidadeSessao.deslogado.podeTentarDeNovo, isFalse);
      expect(EstadoIdentidadeSessao.deslogado.autenticado, isFalse);
    });

    test('o motivo ambíguo não se declara transitório sozinho', () {
      // `transitoria` responde "adianta repetir SEM saber de mais nada". Para
      // este motivo a resposta honesta é não: falta a prova de sessão.
      expect(MotivoFalhaIdentidade.credencialOuAtestacao.transitoria, isFalse);
      expect(MotivoFalhaIdentidade.indisponivel.transitoria, isTrue);
      expect(MotivoFalhaIdentidade.desconhecida.transitoria, isTrue);
      // E os definitivos continuam definitivos, com ou sem sessão.
      for (final motivo in const [
        MotivoFalhaIdentidade.recusado,
        MotivoFalhaIdentidade.respostaInvalida,
      ]) {
        expect(motivo.permiteNovaTentativa(haSessaoLocal: true), isFalse);
        expect(motivo.permiteNovaTentativa(haSessaoLocal: false), isFalse);
      }
    });

    test('11 — o retry recupera a Identidade depois da recusa por atestação', () async {
      final fonte = _FonteEncenada();
      final auth = StreamController<String?>.broadcast();
      final sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
      addTearDown(() {
        sessao.dispose();
        auth.close();
      });

      auth.add('uid-a');
      await _assentar();
      expect(fonte.chamadas, 1);

      // O App Check recusa: sessão viva, identidade sem carregar.
      fonte.recusarPorAtestacao();
      await _assentar();
      expect(sessao.estado.fase, FaseIdentidade.falha);
      expect(sessao.estado.publicId, isNull);
      expect(sessao.estado.podeTentarDeNovo, isTrue);

      // O gesto explícito de "tentar de novo" — e desta vez o token saiu.
      final voo = sessao.recarregar();
      await _assentar();
      expect(fonte.chamadas, 2);
      fonte.responder('pub-a');
      await voo;
      await _assentar();

      expect(sessao.estado.fase, FaseIdentidade.disponivel);
      expect(sessao.estado.publicId, 'pub-a');
      expect(
        sessao.estado.uid,
        'uid-a',
        reason: 'a identidade recuperada é da MESMA sessão que falhou',
      );
    });

    test('o adaptador traduz `unauthenticated` para o motivo AMBÍGUO', () {
      // Estrutural, e por necessidade: `_traduzir` é privado e o caminho
      // público exige uma `FirebaseFunctions` de verdade, que só existe com o
      // Firebase inicializado. O que dá para afirmar sem emulador é a linha da
      // tradução — e é justamente ela que, escrita errado, transforma uma
      // recusa de atestação em "entre de novo".
      final fonte = _codigo(
        File('lib/sessao/fonte_identidade_firebase.dart'),
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        fonte,
        contains(
          "'unauthenticated' => MotivoFalhaIdentidade.credencialOuAtestacao",
        ),
        reason:
            'unauthenticated cobre credencial inválida, App Check inválido e '
            'App Check ausente — concluir qualquer uma das três aqui é afirmar '
            'o que o código recebido não autoriza',
      );
      // E o motivo que ela produz é o que oferece retry com sessão viva.
      expect(
        MotivoFalhaIdentidade.credencialOuAtestacao.permiteNovaTentativa(
          haSessaoLocal: true,
        ),
        isTrue,
      );
    });

    test('13 — nenhum caminho de erro desloga', () {
      // A varredura é sobre o cliente inteiro, e não sobre o que a raiz alcança:
      // um signOut escondido numa tela órfã volta a ser alcançável no dia em que
      // alguém reabrir a rota.
      final quemDesloga = <String>[
        for (final f in _fontesDoCliente())
          if (_codigo(f).contains('signOut')) _barras(f.path),
      ];
      expect(
        quemDesloga,
        hasLength(1),
        reason: 'um segundo lugar capaz de deslogar é um logout sem gesto',
      );
      expect(quemDesloga.single, endsWith('lib/sessao/autenticacao_firebase.dart'));

      // E a sessão não desmonta por falha: o uid sobrevive à recusa, que é o
      // que permite o retry de #11 pertencer à mesma conta.
      const falha = FalhaIdentidade(
        MotivoFalhaIdentidade.credencialOuAtestacao,
        'unauthenticated',
      );
      final estado = EstadoIdentidadeSessao.falhou('uid-a', falha);
      expect(estado.uid, 'uid-a');
      expect(estado.autenticado, isTrue);
    });
  });
}
