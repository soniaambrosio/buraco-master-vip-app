// app_check_android_test.dart — o gate `appcheckandroid`.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE GUARDA
// ---------------------------------------------------------------------------
//
// Três coisas, e as três estavam sem guarda nenhuma antes da OS 50.1:
//
//   1. que a atestação é ATIVADA, no único ponto do processo que serve —
//      depois de `Firebase.initializeApp()` e antes de `runApp()`;
//   2. que o provedor é escolhido por CONSTANTE DE COMPILAÇÃO, para que o
//      artefato de release não carregue o provedor de depuração;
//   3. que a recusa da autoridade (`unauthenticated`) é lida como CREDENCIAL
//      OU ATESTAÇÃO, e não como conclusão sobre a sessão do jogador.
//
// POR QUE TANTA LEITURA DE FONTE. Nada disto pode ser exercitado rodando
// `main()`: `Firebase.initializeApp` exige plataforma Android de verdade, e
// `FirebaseAppCheck.instance` morre com `[core/no-app]` fora dela. O que dá
// para provar em bancada é a FORMA — e a forma é exatamente o que importa
// aqui, porque foi a forma (`const` + `kReleaseMode`) que a OS escolheu para
// tornar "não há depuração no release" estrutural em vez de uma promessa.
//
// A LEITURA IGNORA COMENTÁRIO, e isso não é detalhe. Os comentários de
// `main.dart` citam `AndroidDebugProvider` e `AndroidPlayIntegrityProvider`
// pelo nome, para explicar a dobra de constante. Uma busca textual crua
// contaria as citações junto com o código, e uma suíte esvaziada cujos
// comentários repetissem os literais passaria sem provar nada.
//
// A PROVA DE QUE ESTE GATE EXISTE NO PORTÃO NÃO MORA AQUI. Ela mora em
// `test/casca/auditoria_casca_test.dart` (gate `cascaaud`), pelo mesmo motivo
// que a prova do `perfilvis` mora lá: uma guarda escrita dentro do arquivo que
// ela guarda morre junto com ele.
library;

import 'dart:io';

import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:flutter_test/flutter_test.dart';

/// O arquivo SEM comentários, respeitando aspas para que uma `//` dentro de
/// string literal não seja confundida com início de comentário.
///
/// Cópia deliberada do auxiliar de `auditoria_casca_test.dart`: importar de lá
/// acoplaria dois gates obrigatórios, e apagar o de lá derrubaria este junto.
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

int _ocorrencias(String texto, String agulha) {
  var n = 0;
  var de = 0;
  while (true) {
    final i = texto.indexOf(agulha, de);
    if (i < 0) return n;
    n++;
    de = i + agulha.length;
  }
}

/// O appId do registro Firebase de TESTE ("BMV Teste"), que é o que o fonte
/// compartilhado carrega.
const String _appIdDeTeste = '1:203886484007:android:734aaa61ca5ca68b29cc02';

/// O appId do registro Firebase OFICIAL da Play. Ele NÃO pode aparecer no
/// fonte: quem o injeta é `release-aab.yml`, na cópia de `app_build/`.
const String _appIdOficial = '1:203886484007:android:b1cd95baa0b9e6e629cc02';

const String _serverClientId =
    '203886484007-a5e1ob9b7uequoffj6u76h5vltici9a4.apps.googleusercontent.com';

void main() {
  final porta = File('lib/main.dart');
  final autenticacao = File('lib/sessao/autenticacao_firebase.dart');
  final transporte = File('lib/sessao/fonte_identidade_firebase.dart');
  final release = File('../.github/workflows/release-aab.yml');

  group('a ativação de App Check na porta de entrada', () {
    test('N01 a porta de entrada importa o plugin de App Check', () {
      expect(
        _codigo(porta),
        contains("import 'package:firebase_app_check/firebase_app_check.dart'"),
        reason: 'sem o import não há atestação nenhuma — e o pubspec declara o '
            'plugin desde antes, o que faz a ausência parecer intencional',
      );
    });

    test('N02 a ativação existe, e é uma só', () {
      expect(
        _ocorrencias(_codigo(porta), 'FirebaseAppCheck.instance.activate('),
        1,
        reason: 'zero é o estado anterior a esta OS; mais de uma é ativação '
            'repetida, e a segunda venceria a primeira em silêncio',
      );
    });

    test('N03 a ativação vem DEPOIS de Firebase.initializeApp', () {
      final codigo = _codigo(porta);
      final init = codigo.indexOf('Firebase.initializeApp(');
      final ativa = codigo.indexOf('FirebaseAppCheck.instance.activate(');
      expect(init, greaterThanOrEqualTo(0));
      expect(ativa, greaterThanOrEqualTo(0));
      expect(
        ativa,
        greaterThan(init),
        reason: 'antes do initializeApp, `FirebaseAppCheck.instance` resolve '
            '`Firebase.app()` sem app e morre com [core/no-app]',
      );
    });

    test('N04 a ativação vem ANTES de runApp', () {
      final codigo = _codigo(porta);
      final ativa = codigo.indexOf('FirebaseAppCheck.instance.activate(');
      final roda = codigo.indexOf('runApp(');
      expect(roda, greaterThanOrEqualTo(0));
      expect(
        ativa,
        lessThan(roda),
        reason: 'toda callable nasce no initState da raiz, que só roda depois '
            'do runApp — ativar depois é ativar tarde',
      );
    });

    test('N05 runApp é a última instrução de main()', () {
      final codigo = _codigo(porta);
      final roda = codigo.indexOf('runApp(');
      final depois = codigo.substring(roda + 'runApp('.length);
      expect(
        depois.replaceAll(RegExp(r'\s'), ''),
        'constRaizDoAplicativo());}',
        reason: 'qualquer coisa executável depois do runApp desfaz a garantia '
            'de ordem que N04 mede',
      );
    });

    test('N06 a ativação tem try/catch PRÓPRIO', () {
      final codigo = _codigo(porta);
      expect(
        _ocorrencias(codigo, 'try {'),
        2,
        reason: 'um único try é o defeito: uma falha do Firebase pularia a '
            'ativação em silêncio, e não é isso que se quer dizer',
      );

      // O `catch` que fecha o bloco do Firebase tem de vir ANTES da ativação —
      // é isso que prova que a ativação não está dentro daquele `try`.
      final init = codigo.indexOf('Firebase.initializeApp(');
      final fechaPrimeiro = codigo.indexOf('catch', init);
      final ativa = codigo.indexOf('FirebaseAppCheck.instance.activate(');
      expect(
        fechaPrimeiro,
        lessThan(ativa),
        reason: 'a ativação está dentro do try do Firebase — a falha dele '
            'engoliria a dela',
      );
      expect(
        codigo.indexOf('catch', ativa),
        greaterThan(ativa),
        reason: 'a ativação precisa do catch dela; sem ele, um ambiente sem '
            'configuração Android derruba o main()',
      );
    });

    test('N07 o provedor é constante de compilação sobre kReleaseMode', () {
      final codigo = _codigo(porta);
      expect(
        codigo,
        contains('const AndroidAppCheckProvider kProvedorDeAtestacao'),
        reason: 'declarado como variável, os dois provedores sobrevivem no '
            'artefato',
      );
      expect(
        codigo,
        contains('kReleaseMode'),
        reason: 'sem kReleaseMode não há dobra de constante',
      );
    });

    test('N08 o release usa Play Integrity, e só ele', () {
      final codigo = _codigo(porta);
      expect(_ocorrencias(codigo, 'AndroidPlayIntegrityProvider()'), 1);
      final k = codigo.indexOf('kReleaseMode');
      final play = codigo.indexOf('AndroidPlayIntegrityProvider()');
      final debug = codigo.indexOf('AndroidDebugProvider()');
      expect(
        play,
        greaterThan(k),
        reason: 'o provedor do release é o do ramo verdadeiro do condicional',
      );
      expect(
        play,
        lessThan(debug),
        reason: 'os ramos estão trocados: o release ganharia o provedor de '
            'depuração, e a atestação passaria a valer de graça',
      );
    });

    test('N09 a depuração usa o provedor de depuração, e só ela', () {
      final codigo = _codigo(porta);
      expect(_ocorrencias(codigo, 'AndroidDebugProvider()'), 1);
      expect(
        codigo,
        contains(': AndroidDebugProvider()'),
        reason: 'o provedor de depuração tem de estar no ramo falso do '
            'condicional — em qualquer outro lugar ele alcança o release',
      );
    });

    test('N10 a escolha não é feita em tempo de execução', () {
      final codigo = _codigo(porta);
      expect(
        codigo,
        isNot(contains('if (kReleaseMode)')),
        reason: 'um `if` de execução mantém as DUAS classes no artefato, e '
            'basta um engano de configuração para distribuir atestação de graça',
      );
      expect(
        RegExp(r'AndroidAppCheckProvider\s+\w+\s*\(\s*\)\s*(\{|=>)')
            .hasMatch(codigo),
        isFalse,
        reason: 'função ou getter devolvendo provedor tem o mesmo efeito de um '
            '`if`: o compilador não pode remover o ramo não tomado',
      );
    });

    test('N11 nenhum token de depuração entra no repositório', () {
      final texto = porta.readAsStringSync();
      expect(
        RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
            .hasMatch(texto),
        isFalse,
        reason: 'o SDK imprime um token novo por instalação e ele se cadastra '
            'no console — token nenhum se versiona',
      );
      expect(texto, isNot(contains('FIREBASE_APPCHECK_DEBUG_TOKEN')));
    });

    test('N12 o fonte continua apontando para o registro de TESTE', () {
      final codigo = _codigo(porta);
      expect(
        _ocorrencias(codigo, _appIdDeTeste),
        1,
        reason: 'o APK de teste depende deste registro; trocar aqui quebra o '
            'login do aparelho onde se desenvolve',
      );
      expect(
        codigo,
        isNot(contains(_appIdOficial)),
        reason: 'o appId oficial entra na cópia de app_build/, e só lá — se ele '
            'aparecer aqui, a substituição do release deixa de achar o alvo',
      );
    });
  });

  group('o pipeline de release aponta o registro oficial', () {
    test('N13 o serverClientId é procurado onde ele realmente vive', () {
      if (!release.existsSync()) return;
      final texto = release.readAsStringSync();
      expect(
        texto,
        contains("autenticacao = 'app_build/lib/sessao/autenticacao_firebase.dart'"),
        reason: 'a conferência do Web client precisa apontar para o arquivo que '
            'o contém — apontar para o arquivo antigo trava o AAB inteiro',
      );
    });

    test('N14 o serverClientId NÃO é procurado em main.dart', () {
      if (!release.existsSync()) return;
      final texto = release.readAsStringSync();
      expect(
        texto,
        isNot(contains('serverClientId Web sumiu do main.dart')),
        reason: 'era esta a conferência obsoleta: ela levantava AssertionError '
            'em toda execução, e nenhum bundle saía do pipeline',
      );
    });

    test('N15 o Web client existe uma vez no arquivo conferido', () {
      expect(
        _ocorrencias(_codigo(autenticacao), _serverClientId),
        1,
        reason: 'se o valor sumir ou duplicar aqui, a conferência do release '
            'reprova — e é para reprovar mesmo',
      );
    });

    test('N16 a substituição acontece, e exige exatamente uma ocorrência', () {
      if (!release.existsSync()) return;
      final texto = release.readAsStringSync();
      expect(
        texto,
        contains('s = s.replace(antigo, novo)'),
        reason: 'sem a substituição, o bundle oficial sai com o appId do '
            'registro de TESTE — e é o registro que decide se o Play Integrity '
            'fecha',
      );
      expect(
        texto,
        contains('if n != 1:'),
        reason: 'sem a exigência de unicidade, um fonte com duas ocorrências '
            'passa e uma delas fica para trás',
      );
    });

    test('N17 o passo confere o próprio resultado', () {
      if (!release.existsSync()) return;
      expect(
        release.readAsStringSync(),
        contains('if s.count(novo) != 1 or antigo in s:'),
        reason: 'uma substituição que erra o alvo e segue em frente produz um '
            'bundle que compila e fala com o registro errado',
      );
    });

    test('N18 os dois appIds continuam nomeados no ambiente do workflow', () {
      if (!release.existsSync()) return;
      final texto = release.readAsStringSync();
      expect(texto, contains('BMV_FIREBASE_APP_ID_POC'));
      expect(texto, contains(_appIdOficial));
    });
  });

  group('a recusa de atestação é neutra, e admite nova tentativa', () {
    test('N19 o transporte não conclui nada sobre a sessão', () {
      final codigo = _codigo(transporte);
      expect(
        codigo,
        contains(
          "'unauthenticated' => MotivoFalhaIdentidade.credencialOuAtestacao",
        ),
        reason: 'com enforceAppCheck, o MESMO código chega de credencial '
            'recusada, de App Check ausente e de App Check inválido',
      );
      expect(
        codigo,
        isNot(contains('MotivoFalhaIdentidade.naoAutenticado')),
        reason: 'o motivo antigo era uma conclusão que o código recebido não '
            'autoriza',
      );
    });

    test('N20 com sessão viva, credencial-ou-atestação admite nova tentativa',
        () {
      expect(
        identidadeAdmiteNovaTentativa(
          MotivoFalhaIdentidade.credencialOuAtestacao,
          haSessaoLocal: true,
        ),
        isTrue,
        reason: 'é o caso da atestação ausente: a sessão está intacta e '
            'repetir é justamente o que resolve',
      );
    });

    test('N21 sem sessão local, a recusa é terminal', () {
      expect(
        identidadeAdmiteNovaTentativa(
          MotivoFalhaIdentidade.credencialOuAtestacao,
          haSessaoLocal: false,
        ),
        isFalse,
        reason: 'sem sessão, insistir na mesma credencial não leva a lugar '
            'nenhum',
      );
    });

    test('N22 soluço e desconhecido admitem, com ou sem sessão', () {
      for (final motivo in const [
        MotivoFalhaIdentidade.indisponivel,
        MotivoFalhaIdentidade.desconhecida,
      ]) {
        expect(
          identidadeAdmiteNovaTentativa(motivo, haSessaoLocal: true),
          isTrue,
        );
        expect(
          identidadeAdmiteNovaTentativa(motivo, haSessaoLocal: false),
          isTrue,
        );
      }
    });

    test('N23 recusa explícita e resposta inválida não admitem', () {
      for (final motivo in const [
        MotivoFalhaIdentidade.recusado,
        MotivoFalhaIdentidade.respostaInvalida,
      ]) {
        expect(
          identidadeAdmiteNovaTentativa(motivo, haSessaoLocal: true),
          isFalse,
          reason: 'repetir não resolve nenhum dos dois, e oferecer o botão '
              'seria mentir para quem clica',
        );
      }
    });

    test('N24 o estado de falha com sessão viva oferece tentar de novo', () {
      const estado = EstadoIdentidadeSessao.falhou(
        'uid-a',
        FalhaIdentidade(MotivoFalhaIdentidade.credencialOuAtestacao),
      );
      expect(estado.podeTentarDeNovo, isTrue);
    });

    test('N25 a falha de atestação NÃO derruba a sessão', () {
      const estado = EstadoIdentidadeSessao.falhou(
        'uid-a',
        FalhaIdentidade(MotivoFalhaIdentidade.credencialOuAtestacao),
      );
      expect(estado.fase, FaseIdentidade.falha);
      expect(estado.uid, 'uid-a');
      expect(
        estado.autenticado,
        isTrue,
        reason: '§10: falha de identidade não derruba o resto da sessão — '
            'ninguém é deslogado por não ter conseguido atestar',
      );
    });

    test('N26 o predicado de motivo sozinho NÃO responde por atestação', () {
      expect(
        MotivoFalhaIdentidade.credencialOuAtestacao.transitoria,
        isFalse,
        reason: 'o motivo sozinho não sabe se há sessão, e por isso não pode '
            'responder — quem responde é identidadeAdmiteNovaTentativa',
      );
      expect(
        identidadeAdmiteNovaTentativa(
          MotivoFalhaIdentidade.credencialOuAtestacao,
          haSessaoLocal: true,
        ),
        isNot(MotivoFalhaIdentidade.credencialOuAtestacao.transitoria),
        reason: 'ler `transitoria` no lugar do predicado é exatamente a '
            'regressão que esta suíte existe para pegar',
      );
    });
  });
}
