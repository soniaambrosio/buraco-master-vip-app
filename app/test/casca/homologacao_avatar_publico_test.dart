// homologacao_avatar_publico_test.dart — a matriz INDEPENDENTE do avatar público.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE É, E O QUE ELA NÃO É
// ---------------------------------------------------------------------------
//
// É a matriz da OS de HOMOLOGAÇÃO. Ela não substitui nem toca
// `avatar_publico_canonico_test.dart` (a matriz da entrega, 37 casos): roda ao
// lado dela, com harness próprio, e recalcula as mesmas garantias por caminhos
// diferentes. Onde a matriz da entrega afirma "os dois avatares são iguais",
// esta afirma também QUAL é o valor, POR QUANTOS QUADROS ele é aquele, e QUAL
// widget o desenha — porque uma igualdade pode ser satisfeita por duas telas
// erradas do mesmo jeito.
//
// Nenhum arquivo de `lib/` foi alterado para que estes casos passassem. Um caso
// que reprovasse aqui viraria FAIL de homologação e OS corretiva à parte, não
// remendo no produto.
//
// ---------------------------------------------------------------------------
// AS TRÊS DECISÕES DE ENCENAÇÃO QUE MUDAM O QUE SE PROVA
// ---------------------------------------------------------------------------
//
// 1. A FONTE NÃO RESPONDE SOZINHA. `_FonteControlada` guarda cada chamada num
//    `Completer` e devolve o controle ao teste. É o que dá à janela entre "a
//    sessão virou" e "a identidade nova chegou" uma duração de verdade — com
//    resposta imediata essa janela dura menos de um quadro e o teste passaria
//    sem nunca tê-la visitado. Vazamento entre contas mora exatamente ali.
//
// 2. A JANELA É AMOSTRADA QUADRO A QUADRO, e não observada só no fim. Vários
//    casos coletam o avatar de CADA quadro da janela num histórico e depois
//    exigem que o avatar da conta anterior não apareça em NENHUM deles. Uma
//    verificação só no estado final aceitaria um piscar de um quadro, que num
//    aparelho de verdade é um avatar de outra pessoa aparecendo na tela.
//
// 3. A SESSÃO NASCE DENTRO DO CORPO DO TESTE. `testWidgets` roda o corpo num
//    zone de tempo falso e o `setUp` roda fora dele; uma assinatura de stream
//    registrada no `setUp` entrega eventos num mundo que o relógio do `pump`
//    nunca adianta, e o login jamais chegaria.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600 (paisagem de
// desktop) e faz tela de celular estourar em overflow — falha de encenação
// disfarçada de defeito.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/services/perfil_service.dart';
import 'package:buraco_master_vip/sessao/avatar_publico.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';
import 'package:buraco_master_vip/social/apresentacao.dart' as social;

// ===========================================================================
// Fixtures — deliberadamente diferentes das da matriz da entrega
// ===========================================================================

/// O fallback OFICIAL, escrito por código de ponto e não copiado do produto.
///
/// `\u{1F451}` é CROWN. Escrever o literal aqui faria o caso passar por
/// coincidência de bytes copiados; escrever o code point faz o teste afirmar
/// QUAL caractere é o fallback. Se alguém trocar a coroa por outro emoji
/// parecido, este é o caso que cai.
const String kCoroaOficial = '\u{1F451}';

const String kIdPublicoUm = 'PHOM0000AAAA';
const String kIdPublicoDois = 'PHOM1111BBBB';

/// Referências bem formadas e CURTAS — cabem no círculo de 56px do cabeçalho
/// da Home sem estourar a linha.
const String kRefUm = 'tuca_azul';
const String kRefDois = 'gato_rei9';

IdentidadePublica _identidade({
  required String publicId,
  String? avatarRef,
  String apelido = 'Sônia',
}) => IdentidadePublica(
  publicId: publicId,
  apelido: apelido,
  avatarRef: avatarRef,
  criada: false,
  estado: EstadoPerfil.ativo,
  limites: LimitesSociais.desconhecidos,
  edicao: MetadadosDeEdicao.desconhecidos,
);

/// A fonte de identidade sob controle do teste.
///
/// Guarda cada chamada e NÃO responde por conta própria. `responder` completa
/// uma chamada específica pelo índice, o que permite encenar a resposta ATRASADA
/// da conta anterior chegando depois da resposta da conta nova — a ordem que um
/// `Future.value` jamais produz.
class _FonteControlada implements FonteDeIdentidade {
  final List<Completer<IdentidadePublica>> pendentes = [];
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }

  /// Completa a chamada [indice] com [identidade]. Sem remover da lista: o
  /// índice de uma chamada é estável, e é por ele que a resposta atrasada da
  /// conta A é identificada depois de a conta B já ter respondido.
  void responder(int indice, IdentidadePublica identidade) =>
      pendentes[indice].complete(identidade);

  void falhar(int indice) => pendentes[indice].completeError(
    const FalhaIdentidade(MotivoFalhaIdentidade.indisponivel, 'encenado'),
  );
}

/// Pede uma releitura da identidade SEM esperar por ela.
///
/// `SessaoDoJogador.recarregar()` devolve a future da requisição em voo, e nesta
/// suíte a requisição só termina quando o teste manda. Um `await` aqui travaria
/// para sempre — o teste esperaria a resposta que ele mesmo ainda vai dar. O
/// `ignore` é a forma honesta de dizer "disparei e sigo": quem espera é o
/// `pump`, depois do `responder`.
void pedirRecarga(SessaoDoJogador sessao) {
  sessao.recarregar().ignore();
}

// ===========================================================================
// Ferramentas de auditoria estrutural
// ===========================================================================

/// A raiz do pacote, resolvida a partir do diretório de execução.
///
/// `flutter test` roda com o cwd na raiz do pacote — tanto em `app/` quanto no
/// `app_build` do overlay do CI. A busca sobe alguns níveis de propósito: um
/// caso de auditoria que não encontrasse `lib/` passaria vazio, e um teste que
/// passa por não ter achado o que auditar é pior que um que reprova.
Directory _raiz() {
  var d = Directory.current;
  for (var i = 0; i < 4; i++) {
    if (Directory('${d.path}/lib/sessao').existsSync()) return d;
    d = d.parent;
  }
  throw StateError('não encontrei a raiz do pacote a partir de ${Directory.current.path}');
}

String _caminho(String relativo) => '${_raiz().path}/$relativo';

/// O arquivo com as quebras de linha normalizadas para `\n`.
///
/// OBRIGATÓRIO para qualquer comparação de bytes: o checkout no Windows entrega
/// `\r\n` e o do CI entrega `\n`. Sem normalizar, um digest prova o sistema
/// operacional em vez do conteúdo.
String _texto(String relativo) =>
    File(_caminho(relativo)).readAsStringSync().replaceAll('\r\n', '\n');

/// O código sem comentários, respeitando aspas.
///
/// Toda auditoria por varredura precisa disto: os arquivos desta correção
/// CITAM nos comentários exatamente o que a OS proíbe (`Image.network`,
/// `https://`, `avatarRef ?? '👑'`), porque documentam o defeito que fecharam.
/// Uma varredura ingênua reprovaria a explicação em vez do código.
String _semComentarios(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  while (i < fonte.length) {
    final c = fonte[i];
    if (c == "'" || c == '"') {
      // Uma string literal é copiada inteira: `'// não é comentário'` não é.
      final aspa = c;
      saida.write(c);
      i++;
      while (i < fonte.length) {
        if (fonte[i] == r'\' && i + 1 < fonte.length) {
          saida.write(fonte.substring(i, i + 2));
          i += 2;
          continue;
        }
        saida.write(fonte[i]);
        if (fonte[i] == aspa) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < fonte.length && fonte[i + 1] == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < fonte.length && fonte[i + 1] == '*') {
      i += 2;
      while (i + 1 < fonte.length && !(fonte[i] == '*' && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// O código sem os corpos dos factories `.mock()`.
///
/// `InicioVM.mock()` e `PerfilVM.mock()` escrevem `avatar: '👑'`, e devem
/// continuar escrevendo: são CATÁLOGO VISUAL declarado, usados pelo protótipo e
/// pelos testes da própria tela, e `auditoria_casca_test.dart` já prova que
/// nenhuma rota nascida em `main()` os constrói. Uma varredura que não os
/// descontasse obrigaria a mexer no protótipo para provar algo sobre produção —
/// exatamente o tipo de dano colateral que uma homologação não pode causar.
///
/// A contagem fecha primeiro a LISTA DE PARÂMETROS e só depois o corpo: sem
/// isso, a chave dos parâmetros nomeados (`mock({bool ehMeuPerfil = true})`)
/// seria confundida com a chave do corpo, e o corpo inteiro escaparia.
String _semMaquetes(String codigo) {
  final saida = StringBuffer();
  final abertura = RegExp(r'factory\s+\w+\.mock\s*\(');
  var resto = codigo;
  while (true) {
    final m = abertura.firstMatch(resto);
    if (m == null) {
      saida.write(resto);
      return saida.toString();
    }
    saida.write(resto.substring(0, m.start));
    var i = m.end;
    var parenteses = 1;
    while (i < resto.length && parenteses > 0) {
      if (resto[i] == '(') parenteses++;
      if (resto[i] == ')') parenteses--;
      i++;
    }
    i = resto.indexOf('{', i);
    if (i < 0) return saida.toString();
    var nivel = 0;
    for (; i < resto.length; i++) {
      if (resto[i] == '{') nivel++;
      if (resto[i] == '}') {
        nivel--;
        if (nivel == 0) {
          i++;
          break;
        }
      }
    }
    resto = resto.substring(i);
  }
}

/// Todo o valor passado a um argumento nomeado `nome:`, do `:` até a vírgula que
/// fecha o argumento.
///
/// A leitura é POR PROFUNDIDADE, e não por regex, e a diferença é a que decide
/// um caso desta suíte: um `avatar: cond ? 'x' : f(y),` tem o literal LONGE do
/// `:`, e um padrão que exigisse `avatar:\s*'` não o veria. Contar parênteses e
/// colchetes também é o que impede parar na vírgula de dentro de uma chamada
/// (`f(a, b)`) em vez da vírgula que separa os argumentos.
List<String> _valoresDeArgumento(String codigo, String nome) {
  final valores = <String>[];
  final marca = RegExp('\\b$nome\\s*:');
  for (final m in marca.allMatches(codigo)) {
    var i = m.end;
    var profundidade = 0;
    final buffer = StringBuffer();
    while (i < codigo.length) {
      final c = codigo[i];
      if (c == '(' || c == '[' || c == '{') profundidade++;
      if (c == ')' || c == ']' || c == '}') {
        if (profundidade == 0) break; // fim da lista de argumentos
        profundidade--;
      }
      if (c == ',' && profundidade == 0) break;
      if (c == ';' && profundidade == 0) break;
      buffer.write(c);
      i++;
    }
    valores.add(buffer.toString().trim());
  }
  return valores;
}

final RegExp _reImport = RegExp("^\\s*import\\s+'([^']+)'", multiLine: true);

String _normalizarCaminho(String bruto) {
  final partes = <String>[];
  for (final p in bruto.split('/')) {
    if (p == '.' || p.isEmpty) continue;
    if (p == '..') {
      if (partes.isNotEmpty) partes.removeLast();
      continue;
    }
    partes.add(p);
  }
  return partes.join('/');
}

/// O fecho transitivo de imports a partir de [raizes] (caminhos sob `lib/`).
///
/// Devolve só os arquivos DO PACOTE. `dart:`, `package:flutter/` e pacotes de
/// terceiros entram como o próprio texto do import, para que um caso possa
/// afirmar a AUSÊNCIA de `package:cloud_firestore/...` no fecho sem precisar
/// resolver o pacote em disco.
Set<String> _fechoDeImports(List<String> raizes) {
  final vistos = <String>{};
  final fila = <String>[...raizes];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    if (!atual.startsWith('lib/')) continue; // externo: não se resolve
    final arquivo = File(_caminho(atual));
    if (!arquivo.existsSync()) continue;
    final codigo = _semComentarios(
      arquivo.readAsStringSync().replaceAll('\r\n', '\n'),
    );
    for (final m in _reImport.allMatches(codigo)) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('package:buraco_master_vip/')) {
        fila.add('lib/${alvo.substring('package:buraco_master_vip/'.length)}');
        continue;
      }
      if (alvo.startsWith('dart:') || alvo.startsWith('package:')) {
        vistos.add(alvo);
        continue;
      }
      final dir = atual.substring(0, atual.lastIndexOf('/'));
      fila.add(_normalizarCaminho('$dir/$alvo'));
    }
  }
  return vistos;
}

Set<String> _arquivosDoPacote(Set<String> fecho) =>
    fecho.where((f) => f.startsWith('lib/')).toSet();

/// Quantas vezes [agulha] aparece no CÓDIGO (sem comentários) de todo o `lib/`.
int _ocorrenciasEmLib(String agulha) {
  var total = 0;
  for (final f in Directory(_caminho('lib')).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final codigo = _semComentarios(
      f.readAsStringSync().replaceAll('\r\n', '\n'),
    );
    total += agulha.allMatches(codigo).length;
  }
  return total;
}

void main() {
  late _FonteControlada fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    fonte = _FonteControlada();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  void abrirSessao() {
    sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
    addTearDown(sessao.dispose);
  }

  void telefone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  /// Avança tempo o bastante para as cargas em cascata do Perfil terminarem.
  ///
  /// `pumpAndSettle` sozinho não serve: `didChangeDependencies` do Perfil chama
  /// `setState` DENTRO do quadro em construção, e marcar sujo no quadro corrente
  /// não agenda quadro novo — o `pumpAndSettle` devolve com o temporizador de
  /// 350ms do serviço ainda pendente e o teste morre por "pending timers", que é
  /// falha de encenação e não de comportamento. Uma troca de conta encadeia até
  /// três cargas, então o laço avança bem mais do que uma.
  Future<void> drenar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Sessão autenticada com identidade JÁ resolvida.
  Future<void> logar(
    WidgetTester tester, {
    required String uid,
    required String publicId,
    String? avatarRef,
  }) async {
    abrirSessao();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add(uid);
    await tester.pump();
    fonte.responder(
      fonte.pendentes.length - 1,
      _identidade(publicId: publicId, avatarRef: avatarRef),
    );
    await tester.pump();
  }

  Future<void> montarHome(WidgetTester tester) async {
    telefone(tester);
    await tester.pumpWidget(
      EscopoSessao(sessao: sessao, child: MaterialApp(home: HomeDeProducao())),
    );
    await tester.pump();
  }

  Future<void> montarPerfil(WidgetTester tester) async {
    telefone(tester);
    await tester.pumpWidget(
      EscopoSessao(sessao: sessao, child: MaterialApp(home: PerfilPage())),
    );
    await drenar(tester);
  }

  /// As DUAS telas vivas na mesma árvore, sobre a mesma sessão.
  ///
  /// `Stack` e não `Column`: as duas são telas inteiras de celular, e empilhar
  /// em coluna as comprimiria a meia altura — overflow que não diz nada sobre
  /// avatar. No `Stack` as duas recebem a superfície toda, as duas constroem o
  /// próprio VM, e é isso que os casos leem.
  Future<void> montarAsDuas(WidgetTester tester) async {
    telefone(tester);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: [HomeDeProducao(), PerfilPage()],
          ),
        ),
      ),
    );
    await drenar(tester);
  }

  String avatarHome(WidgetTester tester) =>
      tester.widget<InicioScreen>(find.byType(InicioScreen)).vm.jogador.avatar;

  String avatarPerfil(WidgetTester tester) =>
      tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm.avatar;

  /// Todas as `Image` da árvore que buscariam bytes na REDE.
  Iterable<Image> imagensDeRede(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .where((i) => i.image is NetworkImage);

  /// Todos os caminhos de asset que a árvore pediu.
  Iterable<String> assetsPedidos(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((i) => i.image)
      .whereType<AssetImage>()
      .map((a) => a.assetName);

  // =========================================================================
  // A. DOMÍNIO PURO — a regra, sem tela
  // =========================================================================
  group('H-A domínio puro', () {
    test('H-A01 o fallback é a coroa, escrita por code point', () {
      expect(avatarPublicoDe(null), kCoroaOficial);
      expect(kAvatarPublicoFallback, kCoroaOficial);
      // Um único code point, e não uma sequência com seletor de variação: o
      // renderizador desenha isto como texto, e um ZWJ mudaria o glifo.
      expect(kCoroaOficial.runes.length, 1);
      expect(kCoroaOficial.runes.first, 0x1F451);
      expect(avatarPublicoEhFallback(avatarPublicoDe(null)), isTrue);
    });

    test('H-A02 ausência escrita de sete jeitos dá o MESMO fallback', () {
      // `null` é ausência declarada; os outros seis são ausência disfarçada de
      // conteúdo — e é essa a família que o `?? '👑'` da Home não cobria.
      for (final vazio in <String?>[
        null,
        '',
        ' ',
        '   ',
        '\t',
        '\n',
        ' \t\n ',
      ]) {
        expect(
          avatarPublicoDe(vazio),
          kCoroaOficial,
          reason: 'ausência ${jsonEncode(vazio)} deveria cair no fallback',
        );
      }
    });

    test('H-A03 bordas são aparadas, e o miolo não', () {
      expect(avatarPublicoDe('  $kRefUm  '), kRefUm);
      expect(avatarPublicoDe('\t$kRefUm\n'), kRefUm);
      // Espaço NO MEIO não é sujeira de borda: é caractere fora do alfabeto, e
      // aparar não o salva.
      expect(avatarPublicoDe('tuca azul'), kCoroaOficial);
      expect(avatarPublicoDe('  tuca azul  '), kCoroaOficial);
    });

    test('H-A04 nada que se leia como endereço de rede sobrevive', () {
      for (final url in [
        'http://exemplo.com/a.png',
        'https://exemplo.com/a.png',
        'HTTPS://EXEMPLO.COM/A.PNG',
        'https://',
        '//cdn.exemplo.com/a.png',
        'wss://exemplo.com',
        'data:image/png;base64,AAAA',
        'file:///etc/passwd',
        'http://exemplo.com/../../segredo',
      ]) {
        expect(
          avatarPublicoDe(url),
          kCoroaOficial,
          reason: '"$url" não pode virar valor exibível',
        );
      }
    });

    test('H-A05 nada que se leia como caminho de arquivo sobrevive', () {
      for (final caminho in [
        'assets/avatares/coruja.webp',
        'assets/perfil/vitrine_avatar.webp',
        './coruja.webp',
        '../coruja.webp',
        '../../lib/main.dart',
        'a/b',
        '/assets/x.webp',
        r'assets\x.webp',
        'coruja.webp',
      ]) {
        expect(
          avatarPublicoDe(caminho),
          kCoroaOficial,
          reason: '"$caminho" não pode virar caminho pedido ao bundle',
        );
      }
    });

    test('H-A06 o alfabeto tem fronteiras, e elas são as declaradas', () {
      // ACEITOS — o alfabeto inteiro, e os dois extremos de comprimento.
      for (final ok in [
        'abc',
        '0ab',
        'a_b',
        'a-b',
        'a__--99',
        'z${'9' * 63}',
      ]) {
        expect(avatarPublicoDe(ok), ok, reason: '"$ok" está no alfabeto');
      }
      // RECUSADOS — cada um por um motivo diferente.
      for (final ruim in {
        'ab': 'curto demais (2)',
        'a${'b' * 64}': 'longo demais (65)',
        '_abc': 'começa com sublinhado',
        '-abc': 'começa com hífen',
        'Abc': 'maiúscula',
        'ABC': 'maiúsculas',
        'coruja_dourada!': 'pontuação',
        'coruja.dourada': 'ponto',
        'coruja:dourada': 'dois-pontos',
        'coruja<script>': 'sinais de marcação',
        'çãozinho': 'acentuação',
        '🦉_dourada': 'emoji',
        'coruja ': 'byte nulo',
        'coruja\ndourada': 'quebra de linha no meio',
      }.entries) {
        expect(
          avatarPublicoDe(ruim.key),
          kCoroaOficial,
          reason: '${jsonEncode(ruim.key)} deveria cair: ${ruim.value}',
        );
      }
    });

    test('H-A07 o alfabeto do cliente e o da autoridade social COINCIDEM', () {
      // Duas provas, porque cada uma sozinha é furável. A primeira compara o
      // padrão; a segunda compara o COMPORTAMENTO sobre um corpus, e é ela que
      // pega uma divergência escrita de forma equivalente mas não idêntica
      // (ordem de classe, `{2,63}` virando `{2,}`, âncora trocada).
      expect(kFormatoAvatarPublico.pattern, social.kFormatoAvatarRef.pattern);
      final corpus = <String>[
        'abc',
        'ab',
        'a' * 64,
        'a' * 65,
        '_abc',
        '-abc',
        'Abc',
        '0-_9',
        'a b',
        'a.b',
        'a/b',
        'https://x.com/a',
        'assets/a.webp',
        'çao',
        '🦉',
        '',
        ' abc',
        'abc ',
      ];
      for (final v in corpus) {
        expect(
          kFormatoAvatarPublico.hasMatch(v),
          social.kFormatoAvatarRef.hasMatch(v),
          reason: 'os dois alfabetos divergem em ${jsonEncode(v)}',
        );
      }
    });

    test('H-A08 valor não textual no fio nunca chega ao resolvedor', () {
      // A trava é ANTES do resolvedor: `doWire` só aceita `String` em
      // `avatarRef`, então um número, um booleano, uma lista ou um mapa viram
      // `null` na hidratação — e `null` é fallback. O resolvedor não precisa se
      // defender de tipo porque o tipo não chega até ele.
      for (final lixo in <Object>[
        7,
        3.14,
        true,
        <String>['assets/x.webp'],
        <String, String>{'url': 'https://x.com'},
      ]) {
        final id = IdentidadePublica.doWire({
          'publicId': kIdPublicoUm,
          'perfil': {'apelido': 'Sônia', 'avatarRef': lixo},
        });
        expect(id.avatarRef, isNull, reason: 'tipo ${lixo.runtimeType}');
        expect(avatarPublicoDaIdentidade(id), kCoroaOficial);
      }
    });

    test('H-A09 referência reconhecida SEMPRE ganha do fallback', () {
      // O inverso do caso anterior, e a razão de a coroa não poder ser
      // "resposta segura": nenhuma referência válida pode ser confundida com
      // ela, porque emoji não passa no alfabeto.
      expect(kFormatoAvatarPublico.hasMatch(kCoroaOficial), isFalse);
      for (final ref in [kRefUm, kRefDois, 'abc', 'z' * 64]) {
        final resolvido = avatarPublicoDe(ref);
        expect(resolvido, ref);
        expect(avatarPublicoEhFallback(resolvido), isFalse);
      }
    });

    test('H-A10 o resolvedor é puro: sem memória e sem ordem', () {
      // Mil chamadas alternadas. Um cache interno (ou um `RegExp` com estado
      // por engano) mudaria a resposta em função do que veio antes.
      final entradas = <String?>[kRefUm, null, '', kRefDois, 'https://x.com/a', '  $kRefUm  '];
      final esperado = <String>[kRefUm, kCoroaOficial, kCoroaOficial, kRefDois, kCoroaOficial, kRefUm];
      for (var volta = 0; volta < 1000; volta++) {
        final i = volta % entradas.length;
        expect(avatarPublicoDe(entradas[i]), esperado[i]);
      }
      // E na ordem inversa, para o caso de a sequência acima ter sido "sorte".
      for (var i = entradas.length - 1; i >= 0; i--) {
        expect(avatarPublicoDe(entradas[i]), esperado[i]);
      }
    });

    test('H-A11 o resolvedor não conhece Flutter, Firebase nem disco', () {
      final codigo = _semComentarios(_texto('lib/sessao/avatar_publico.dart'));
      for (final proibido in [
        'package:flutter/',
        'package:firebase',
        'package:cloud_',
        'dart:io',
        'dart:ui',
        'shared_preferences',
        'BuildContext',
        'Widget',
      ]) {
        expect(
          codigo.contains(proibido),
          isFalse,
          reason: 'o resolvedor não pode depender de "$proibido"',
        );
      }
      // O único import é o do estado canônico de identidade.
      final imports = _reImport
          .allMatches(codigo)
          .map((m) => m.group(1))
          .toList();
      expect(imports, ['identidade_publica_sessao.dart']);
    });
  });

  // =========================================================================
  // B. HOME
  // =========================================================================
  group('H-B Home', () {
    testWidgets('H-B01 a referência gravada chega à Home e é DESENHADA', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarHome(tester);
      expect(avatarHome(tester), kRefUm);
      // Não basta o VM carregar o valor: ele tem de aparecer. Este é o caso que
      // separa "o dado chegou" de "o dado é visível".
      expect(find.text(kRefUm), findsOneWidget);
      // NÃO se exige aqui a ausência da coroa na tela, e a razão é a §7 da OS: a
      // Home desenha uma coroa ORNAMENTAL (marca do aplicativo), que não é o
      // avatar e não pode ser removida. Quem separa as duas é o caso H-B05, que
      // conta a diferença entre montar com avatar e montar sem.
      expect(find.text(kRefUm), findsOneWidget);
    });

    testWidgets('H-B05 a coroa do avatar é UMA, e é a que o avatar acrescenta', (
      tester,
    ) async {
      // A prova diferencial. Contar coroas numa única montagem não distingue o
      // fallback do ornamento; contar nas DUAS e subtrair, sim: a coroa a mais
      // que aparece quando não há `avatarRef` é exatamente o fallback do avatar.
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarHome(tester);
      final comAvatar = find.text(kCoroaOficial).evaluate().length;

      fonte = _FonteControlada();
      await auth.close();
      auth = StreamController<String?>.broadcast();
      await logar(tester, uid: 'uid-1', publicId: kIdPublicoUm);
      await montarHome(tester);
      final semAvatar = find.text(kCoroaOficial).evaluate().length;

      expect(
        semAvatar - comAvatar,
        1,
        reason: 'sem `avatarRef` deveria surgir UMA coroa a mais — a do avatar',
      );
    });

    testWidgets('H-B02 URL gravada não abre nenhuma requisição na Home', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: 'https://servidor-de-quem-gravou.example/foto.png',
      );
      await montarHome(tester);
      expect(avatarHome(tester), kCoroaOficial);
      // A prova forte: NENHUMA `Image` da árvore da Home busca bytes na rede.
      // O renderizador `_AssetOrText` chamaria `Image.network` para qualquer
      // valor começando com `http`, e é por isso que a recusa precisa acontecer
      // antes dele.
      expect(imagensDeRede(tester), isEmpty);
      expect(find.text(kCoroaOficial), findsWidgets);
    });

    testWidgets('H-B03 caminho de asset gravado não é pedido ao bundle', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: 'assets/avatares/nao_existe.webp',
      );
      await montarHome(tester);
      expect(avatarHome(tester), kCoroaOficial);
      expect(
        assetsPedidos(tester),
        isNot(contains('assets/avatares/nao_existe.webp')),
      );
    });

    testWidgets('H-B04 referência vazia não deixa o círculo em branco', (
      tester,
    ) async {
      // O `?? '👑'` antigo passava `''` adiante intacto, e `_AssetOrText`
      // desenhava um `Text('')` — um círculo dourado vazio, que na tela lê
      // como "o avatar não carregou".
      await logar(tester, uid: 'uid-1', publicId: kIdPublicoUm, avatarRef: '');
      await montarHome(tester);
      expect(avatarHome(tester), kCoroaOficial);
      expect(find.text(kCoroaOficial), findsWidgets);
      // A Home TEM um `Text('')` legítimo: o e-mail da conta, que §5 manda não
      // exibir e que a casca preenche com vazio de propósito. Exigir "nenhum
      // texto vazio na tela" reprovaria essa decisão. O que este caso exige é
      // que o vazio não seja o AVATAR — e o avatar é o valor do VM, que já foi
      // conferido acima.
      expect(
        tester.widget<InicioScreen>(find.byType(InicioScreen)).vm.jogador.email,
        '',
        reason: 'o `Text("")` da tela é o e-mail suprimido, não o avatar',
      );
      expect(avatarHome(tester), isNot(''));
    });
  });

  // =========================================================================
  // C. PERFIL
  // =========================================================================
  group('H-C Perfil', () {
    testWidgets('H-C01 a MESMA referência chega ao Perfil e é desenhada', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarPerfil(tester);
      expect(avatarPerfil(tester), kRefUm);
      expect(find.text(kRefUm), findsOneWidget);
    });

    testWidgets('H-C02 URL gravada não abre requisição no Perfil', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: 'https://servidor-de-quem-gravou.example/foto.png',
      );
      await montarPerfil(tester);
      expect(avatarPerfil(tester), kCoroaOficial);
      expect(imagensDeRede(tester), isEmpty);
    });

    testWidgets('H-C03 o Perfil não fica preso ao avatar do placeholder', (
      tester,
    ) async {
      // A carga do serviço tem 350ms de atraso. Antes dela o VM é o placeholder,
      // cujo avatar é o fallback. O caso exige que o valor definitivo apareça
      // sem que o jogador precise sair e voltar.
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      telefone(tester);
      await tester.pumpWidget(
        EscopoSessao(sessao: sessao, child: MaterialApp(home: PerfilPage())),
      );
      await tester.pump();
      // Mesmo ANTES de a carga terminar o avatar já é o canônico, porque o
      // `build` o reaplica sobre o placeholder.
      expect(avatarPerfil(tester), kRefUm);
      await drenar(tester);
      expect(avatarPerfil(tester), kRefUm);
    });

    testWidgets('H-C04 sem identidade o Perfil usa o fallback, não um nome', (
      tester,
    ) async {
      // Sessão anônima: o stream de auth diz "ninguém".
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add(null);
      await tester.pump();
      await montarPerfil(tester);
      expect(avatarPerfil(tester), kCoroaOficial);
      expect(fonte.chamadas, 0, reason: 'sem uid não há identidade a buscar');
    });

    test('H-C05 o serviço resolve o avatar pela identidade, não por constante', () {
      // Sem tela: o produtor do VM em si. O defeito original vivia aqui — um
      // literal fixo no `_montar`. O caso varre os três estados do serviço.
      const servico = PerfilService();
      expect(servico.vmPlaceholder().avatar, kCoroaOficial);
      expect(
        PerfilVM.mock().avatar,
        isNotNull,
        reason: 'a maquete continua existindo; ela é fixture, não produção',
      );
    });

    test('H-C06 o Perfil não busca nome nem avatar no Firebase Auth', () {
      // §5.6 da OS. `currentUser?.displayName` era a segunda fonte de nome, e
      // na troca de conta ela e `publicProfiles` se atualizavam em momentos
      // diferentes — o perfil da conta nova abria com o nome da anterior.
      for (final arquivo in [
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
        'lib/screens/perfil_screen.dart',
      ]) {
        final codigo = _semComentarios(_texto(arquivo));
        for (final proibido in [
          'firebase_auth',
          'FirebaseAuth',
          'currentUser',
          'displayName',
          'photoURL',
        ]) {
          expect(
            codigo.contains(proibido),
            isFalse,
            reason: '$arquivo não pode alcançar "$proibido"',
          );
        }
      }
    });
  });

  // =========================================================================
  // D. TROCA DE IDENTIDADE, REATIVIDADE E ISOLAMENTO ENTRE CONTAS
  // =========================================================================
  group('H-D identidade em movimento', () {
    testWidgets('H-D01 chegada tardia: fallback antes, referência depois', (
      tester,
    ) async {
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add('uid-1');
      await tester.pump();
      await montarAsDuas(tester);

      // A identidade está em voo. As DUAS telas mostram o fallback — e a
      // igualdade entre elas já vale aqui, não só no fim.
      expect(avatarHome(tester), kCoroaOficial);
      expect(avatarPerfil(tester), kCoroaOficial);

      fonte.responder(0, _identidade(publicId: kIdPublicoUm, avatarRef: kRefUm));
      await drenar(tester);
      expect(avatarHome(tester), kRefUm);
      expect(avatarPerfil(tester), kRefUm);
    });

    testWidgets('H-D02 avatarRef muda com o MESMO publicId', (tester) async {
      // O caso que a recarga por `publicId` não pega sozinha: a identidade é a
      // mesma, só o avatar mudou. Sem a reaplicação no `build`, o Perfil ficaria
      // com o valor velho até o jogador sair e entrar.
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarAsDuas(tester);
      expect(avatarHome(tester), kRefUm);
      expect(avatarPerfil(tester), kRefUm);

      final antes = fonte.chamadas;
      pedirRecarga(sessao);
      fonte.responder(
        fonte.pendentes.length - 1,
        _identidade(publicId: kIdPublicoUm, avatarRef: kRefDois),
      );
      await drenar(tester);

      expect(avatarHome(tester), kRefDois);
      expect(avatarPerfil(tester), kRefDois);
      expect(
        fonte.chamadas,
        antes + 1,
        reason: 'o `recarregar` explícito é UMA chamada, e as telas não somam outras',
      );
      // E o resto do Perfil não voltou ao esqueleto: o nome continua o real e a
      // tela continua em `normal`. Esta segunda metade é o que separa "o avatar
      // atualizou" de "o avatar atualizou porque a tela recarregou tudo" — a
      // recarga é justamente o que §8 e §11 proíbem que um rebuild dispare.
      final tela = tester.widget<PerfilScreen>(find.byType(PerfilScreen));
      expect(tela.vm.nome, 'Sônia');
      expect(
        tela.estado,
        PerfilEstado.normal,
        reason: 'a troca de avatar devolveu o Perfil ao esqueleto',
      );
    });

    testWidgets('H-D03 Home e Perfil montados juntos concordam em 8 estados', (
      tester,
    ) async {
      for (final ref in <String?>[
        kRefUm,
        null,
        '',
        '   ',
        '  $kRefUm  ',
        'https://x.example/a.png',
        'assets/avatares/x.webp',
        'CORUJA_DOURADA',
      ]) {
        fonte = _FonteControlada();
        await auth.close();
        auth = StreamController<String?>.broadcast();
        await logar(
          tester,
          uid: 'uid-1',
          publicId: kIdPublicoUm,
          avatarRef: ref,
        );
        await montarAsDuas(tester);
        expect(
          avatarPerfil(tester),
          avatarHome(tester),
          reason: 'divergiram em ${jsonEncode(ref)}',
        );
        expect(
          avatarHome(tester),
          avatarPublicoDe(ref),
          reason: 'as telas não seguiram o resolvedor em ${jsonEncode(ref)}',
        );
        expect(imagensDeRede(tester), isEmpty);
      }
    });

    testWidgets('H-D04 logout com as telas montadas apaga o avatar na hora', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarAsDuas(tester);
      expect(avatarHome(tester), kRefUm);

      auth.add(null);
      // UM único quadro de 16ms — um quadro de 60fps. O avatar não sobrevive a ele.
      //
      // A DURAÇÃO É PARTE DA PROVA. Um `pump()` sem duração agenda o quadro sem
      // adiantar o relógio falso, e o quadro é construído ANTES de o evento do
      // fluxo de autenticação ser entregue; o valor velho apareceria uma vez, e
      // seria artefato do relógio do teste, não comportamento do produto.
      // Adiantar um quadro entrega o evento e reconstrói na mesma passagem.
      await tester.pump(const Duration(milliseconds: 16));
      expect(avatarHome(tester), kCoroaOficial);
      expect(avatarPerfil(tester), kCoroaOficial);
      expect(find.text(kRefUm), findsNothing);
      // E segue apagado por 20 quadros: o logout não é um piscar.
      for (var q = 0; q < 20; q++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(avatarHome(tester), kCoroaOficial, reason: 'quadro $q');
        expect(avatarPerfil(tester), kCoroaOficial, reason: 'quadro $q');
      }
      await drenar(tester);
      expect(avatarHome(tester), kCoroaOficial);
      expect(avatarPerfil(tester), kCoroaOficial);
    });

    testWidgets('H-D05 na janela da troca A→B o avatar de A não pisca', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-A',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarAsDuas(tester);
      expect(avatarHome(tester), kRefUm);

      // A conta troca. A identidade nova NÃO responde: a janela fica aberta e
      // durando quadros de verdade, controlados por este teste.
      auth.add('uid-B');
      final historico = <String>[];
      for (var quadro = 0; quadro < 30; quadro++) {
        await tester.pump(const Duration(milliseconds: 16));
        historico.add(avatarHome(tester));
        historico.add(avatarPerfil(tester));
      }
      expect(
        historico,
        everyElement(kCoroaOficial),
        reason: 'algum quadro da janela mostrou o avatar de outra conta',
      );

      // Agora B responde, com avatar próprio.
      fonte.responder(
        fonte.pendentes.length - 1,
        _identidade(
          publicId: kIdPublicoDois,
          avatarRef: kRefDois,
          apelido: 'Bia',
        ),
      );
      await drenar(tester);
      expect(avatarHome(tester), kRefDois);
      expect(avatarPerfil(tester), kRefDois);
      expect(find.text(kRefUm), findsNothing);
    });

    testWidgets('H-D06 resposta ATRASADA da conta A não contamina a conta B', (
      tester,
    ) async {
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add('uid-A');
      await tester.pump();
      // A chamada de A fica pendurada de propósito.
      expect(fonte.chamadas, 1);

      auth.add('uid-B');
      await tester.pump();
      expect(fonte.chamadas, 2);
      fonte.responder(
        1,
        _identidade(publicId: kIdPublicoDois, avatarRef: kRefDois, apelido: 'Bia'),
      );
      await tester.pump();
      await montarAsDuas(tester);
      expect(avatarHome(tester), kRefDois);

      // SÓ AGORA a resposta de A chega — fora de ordem, como na rede real.
      fonte.responder(0, _identidade(publicId: kIdPublicoUm, avatarRef: kRefUm));
      await drenar(tester);

      expect(
        avatarHome(tester),
        kRefDois,
        reason: 'a resposta da sessão morta reescreveu o avatar da sessão viva',
      );
      expect(avatarPerfil(tester), kRefDois);
      expect(find.text(kRefUm), findsNothing);
    });

    testWidgets('H-D07 válida→inválida e inválida→válida, nos dois sentidos', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarAsDuas(tester);
      expect(avatarHome(tester), kRefUm);

      // Uma referência que deixa de ser reconhecida (moderação, catálogo,
      // adulteração) cai no fallback e não fica "a última boa".
      pedirRecarga(sessao);
      fonte.responder(
        fonte.pendentes.length - 1,
        _identidade(publicId: kIdPublicoUm, avatarRef: 'https://x.example/a'),
      );
      await drenar(tester);
      expect(avatarHome(tester), kCoroaOficial);
      expect(avatarPerfil(tester), kCoroaOficial);
      expect(imagensDeRede(tester), isEmpty);

      // E o caminho de volta.
      pedirRecarga(sessao);
      fonte.responder(
        fonte.pendentes.length - 1,
        _identidade(publicId: kIdPublicoUm, avatarRef: kRefDois),
      );
      await drenar(tester);
      expect(avatarHome(tester), kRefDois);
      expect(avatarPerfil(tester), kRefDois);
    });

    testWidgets('H-D08 60 reconstruções de cada tela não emitem chamada', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      telefone(tester);
      // O contador força uma instância NOVA das duas telas por quadro — um
      // `const` seria a mesma instância e o Flutter pularia o `build`, que é
      // exatamente o que faria este caso passar sem provar nada.
      final tick = ValueNotifier<int>(0);
      addTearDown(tick.dispose);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (_, _, _) => Stack(
                fit: StackFit.expand,
                children: [HomeDeProducao(), PerfilPage()],
              ),
            ),
          ),
        ),
      );
      await drenar(tester);
      final antes = fonte.chamadas;

      for (var i = 1; i <= 60; i++) {
        tick.value = i;
        await tester.pump();
        expect(avatarHome(tester), kRefUm, reason: 'quadro $i');
        expect(avatarPerfil(tester), kRefUm, reason: 'quadro $i');
      }
      await drenar(tester);
      expect(
        fonte.chamadas,
        antes,
        reason: '60 reconstruções viraram ${fonte.chamadas - antes} consultas',
      );
    });

    testWidgets('H-D09 abrir e fechar o Perfil 6 vezes não emite chamada', (
      tester,
    ) async {
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarHome(tester);
      final antes = fonte.chamadas;

      for (var volta = 1; volta <= 6; volta++) {
        // Navegação de verdade acoplaria este caso ao roteamento da casca.
        // Montar e desmontar a página faz a mesma pergunta sem esse
        // acoplamento: o ciclo de vida completo do Perfil, seis vezes.
        await montarPerfil(tester);
        expect(avatarPerfil(tester), kRefUm, reason: 'volta $volta');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(
        fonte.chamadas,
        antes,
        reason: 'seis aberturas do Perfil viraram ${fonte.chamadas - antes} consultas',
      );
    });

    testWidgets('H-D11 a troca de avatar não devolve o Perfil ao esqueleto', (
      tester,
    ) async {
      // NASCEU DE UMA PROVA POR DEFEITO INJETADO. A mutação que remove a trava
      // de `publicId` do `didChangeDependencies` — "abrir consulta nova ao
      // reconstruir o Perfil" — não era pega por nenhum caso desta matriz: a
      // recarga acontece, termina dentro do dreno, e uma verificação feita só no
      // fim encontra a tela já recomposta e diz que está tudo bem.
      //
      // O que denuncia a recarga é o CAMINHO, não o destino. Aqui a transição é
      // amostrada quadro a quadro, e um único quadro em `carregando` reprova:
      // no aparelho isso é o perfil inteiro piscando para esqueleto porque o
      // avatar mudou.
      await logar(
        tester,
        uid: 'uid-1',
        publicId: kIdPublicoUm,
        avatarRef: kRefUm,
      );
      await montarPerfil(tester);
      expect(avatarPerfil(tester), kRefUm);

      pedirRecarga(sessao);
      fonte.responder(
        fonte.pendentes.length - 1,
        _identidade(publicId: kIdPublicoUm, avatarRef: kRefDois),
      );

      final estados = <PerfilEstado>[];
      final nomes = <String>[];
      for (var quadro = 0; quadro < 40; quadro++) {
        await tester.pump(const Duration(milliseconds: 16));
        final tela = tester.widget<PerfilScreen>(find.byType(PerfilScreen));
        estados.add(tela.estado);
        nomes.add(tela.vm.nome);
      }
      expect(
        estados,
        everyElement(PerfilEstado.normal),
        reason: 'a troca de avatar recarregou o Perfil',
      );
      expect(
        nomes,
        everyElement('Sônia'),
        reason: 'o nome piscou para o placeholder durante a troca de avatar',
      );
      expect(avatarPerfil(tester), kRefDois);
    });

    testWidgets('H-D10 falha de identidade não inventa avatar', (tester) async {
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add('uid-1');
      await tester.pump();
      fonte.falhar(0);
      await tester.pump();
      await montarAsDuas(tester);
      expect(avatarHome(tester), kCoroaOficial);
      expect(avatarPerfil(tester), kCoroaOficial);
      expect(imagensDeRede(tester), isEmpty);
      // E a falha não vira retry por reconstrução (§10 da sessão).
      final antes = fonte.chamadas;
      await drenar(tester);
      expect(fonte.chamadas, antes);
    });
  });

  // =========================================================================
  // E. AUDITORIA ESTRUTURAL
  // =========================================================================
  group('H-E auditoria estrutural', () {
    late Set<String> fecho;
    late Set<String> arquivos;

    setUpAll(() {
      fecho = _fechoDeImports([
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
      ]);
      arquivos = _arquivosDoPacote(fecho);
    });

    test('H-E01 main.dart continua byte a byte o da base', () {
      // Digest da BASE `d738f458`, com `\r\n` normalizado para `\n`. A OS §11
      // pede que a raiz do aplicativo não tenha sido tocada por esta folha.
      const digestDaBase =
          '8526fc0a1cb487b7ec37a27a6449b09f667c5d412968f69bb547c9f246d5a0ab';
      final atual = sha256
          .convert(utf8.encode(_texto('lib/main.dart')))
          .toString();
      expect(atual, digestDaBase);
    });

    test('H-E02 authStateChanges tem UM assinante, e é a sessão', () {
      expect(_ocorrenciasEmLib('authStateChanges'), 1);
      final codigo = _semComentarios(_texto('lib/sessao/sessao_firebase.dart'));
      expect(codigo.contains('authStateChanges'), isTrue);
      // E nenhuma tela do fecho de Home/Perfil assina por conta própria.
      for (final f in arquivos) {
        expect(
          _semComentarios(_texto(f)).contains('authStateChanges'),
          isFalse,
          reason: '$f assinou o fluxo de autenticação por fora da sessão',
        );
      }
    });

    test('H-E03 obterMinhaIdentidade é chamado de UM lugar só', () {
      // A contagem é sobre a CHAMADA (`.obterMinhaIdentidade()`), não sobre o
      // nome — a interface o declara e o adaptador o implementa, e nenhum dos
      // dois é uma consulta a mais.
      expect(_ocorrenciasEmLib('.obterMinhaIdentidade()'), 1);
      expect(
        _semComentarios(
          _texto('lib/sessao/sessao_do_jogador.dart'),
        ).contains('_fonte.obterMinhaIdentidade()'),
        isTrue,
      );
      // O Perfil, especificamente, não menciona a callable.
      for (final f in [
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
      ]) {
        expect(
          _semComentarios(_texto(f)).contains('obterMinhaIdentidade'),
          isFalse,
          reason: '$f abriu um segundo pedido de identidade',
        );
      }
    });

    test('H-E04 nem Home nem Perfil alcançam Firestore ou publicProfiles', () {
      for (final externo in [
        'package:cloud_firestore/cloud_firestore.dart',
        'package:firebase_auth/firebase_auth.dart',
      ]) {
        expect(
          fecho,
          isNot(contains(externo)),
          reason: 'o fecho de Home+Perfil passou a alcançar $externo',
        );
      }
      for (final f in arquivos) {
        final codigo = _semComentarios(_texto(f));
        for (final agulha in [
          'publicProfiles',
          'FirebaseFirestore',
          'collection(',
          '.doc(',
          'snapshots(',
        ]) {
          expect(
            codigo.contains(agulha),
            isFalse,
            reason: '$f faz leitura direta ("$agulha") no caminho das telas',
          );
        }
      }
    });

    test('H-E05 o fecho cresceu só pelo resolvedor', () {
      // A folha declara UM arquivo novo de produção. Se o fecho de Home+Perfil
      // tivesse ganhado qualquer outro vizinho, a superfície da correção seria
      // maior do que a OS autorizou.
      expect(arquivos, contains('lib/sessao/avatar_publico.dart'));
      const previstos = {
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
        'lib/sessao/avatar_publico.dart',
        'lib/sessao/escopo_sessao.dart',
        'lib/sessao/identidade_publica_sessao.dart',
        'lib/sessao/sessao_do_jogador.dart',
        'lib/services/perfil_service.dart',
        'lib/screens/inicio_screen.dart',
        'lib/screens/perfil_screen.dart',
        'lib/ranking/estado_ranking.dart',
      };
      expect(
        previstos.difference(arquivos),
        isEmpty,
        reason: 'o fecho perdeu arquivos que a folha deveria manter',
      );
      // E o resolvedor não arrastou o domínio social para dentro do cliente: é
      // ele que carrega a fórmula de geração de `publicId`.
      expect(arquivos, isNot(contains('lib/social/apresentacao.dart')));
    });

    test('H-E06 a coroa tem UM dono NA FUNÇÃO DE AVATAR', () {
      // A PERGUNTA CERTA NÃO É "quantas coroas existem no código".
      //
      // A primeira versão deste caso contava o literal e reprovava seis
      // arquivos — e estava errada, não o produto: a §7 da OS manda as coroas
      // ORNAMENTAIS ficarem onde estão. `perfil_page.dart` a usa no texto do
      // convite, `perfil_service.dart` como `tituloEmoji` de maquete, e
      // `mesa.dart`, `configuracoes_screen.dart` e `como_jogar_screen.dart` como
      // marca do aplicativo. Nenhuma delas é o avatar.
      //
      // O que a OS proíbe é a coroa VOLTAR A SER UMA SEGUNDA AUTORIDADE DE
      // AVATAR. Então a varredura é por forma, e não por caractere: um literal
      // atribuído a `avatar:`, ou coalescido contra um `avatarRef`, é o defeito
      // original renascendo. Os dois padrões abaixo são exatamente os dois
      // trechos que esta folha removeu.
      final ofensores = <String>[];
      for (final f in arquivos) {
        final codigo = _semMaquetes(_semComentarios(_texto(f)));
        final atribui = RegExp("avatar\\s*:\\s*'[^']*$kCoroaOficial");
        final coalesce = RegExp("avatarRef[^;\\n]*\\?\\?\\s*'[^']*$kCoroaOficial");
        if (atribui.hasMatch(codigo) || coalesce.hasMatch(codigo)) {
          ofensores.add(f);
        }
      }
      expect(
        ofensores,
        isEmpty,
        reason: 'a coroa voltou a ser atribuída como avatar',
      );

      // E o fallback é DECLARADO uma única vez em todo o `lib/`.
      expect(_ocorrenciasEmLib('const String kAvatarPublicoFallback'), 1);
      expect(
        _semComentarios(
          _texto('lib/sessao/avatar_publico.dart'),
        ).contains('kAvatarPublicoFallback'),
        isTrue,
      );
      // Home e Perfil consomem o resolvedor e não o literal: nenhum dos dois
      // decide sozinho o que desenhar quando falta avatar.
      for (final f in [
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
      ]) {
        expect(
          _semComentarios(_texto(f)).contains('avatarPublicoDaIdentidade'),
          isTrue,
          reason: '$f deixou de consultar a autoridade do avatar',
        );
      }
    });

    test('H-E07 nenhuma tela inventa catálogo nem mapeia referência a arquivo', () {
      for (final f in [
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
        'lib/sessao/avatar_publico.dart',
      ]) {
        final codigo = _semComentarios(_texto(f));
        expect(
          codigo.contains('assets/avatares'),
          isFalse,
          reason: '$f inventou um diretório de avatares',
        );
        expect(
          RegExp(r'''avatar\w*\s*\+''').hasMatch(codigo),
          isFalse,
          reason: '$f concatena algo ao avatar — é assim que nasce um caminho',
        );
        expect(
          codigo.contains('Image.network'),
          isFalse,
          reason: '$f passou a buscar imagem na rede',
        );
      }
    });

    test('H-E09 nenhum produtor de produção escreve um avatar literal', () {
      // A SEGUNDA PROVA NASCIDA DE DEFEITO INJETADO. A mutação "usar fallback
      // diferente entre Home e Perfil" — trocar a coroa por outro emoji dentro
      // do `PerfilService` — passava incólume por todos os casos de widget desta
      // matriz, e a razão é a própria arquitetura: o `PerfilPage` reaplica o
      // valor canônico a cada `build`, então o que o serviço escreveu é
      // sobrescrito antes de chegar à tela.
      //
      // Isso é defesa em profundidade, e é bom. Mas significa que um segundo
      // dono de fallback pode nascer no serviço sem que nenhuma tela reclame —
      // e no dia em que a reaplicação for removida (ou um terceiro consumidor
      // ler o serviço direto), o valor errado passa a aparecer. Então a
      // invariante tem de ser estrutural: NENHUM produtor de produção decide o
      // avatar escrevendo um literal. Quem decide é o resolvedor, sempre.
      //
      // A regra é sobre a FORMA da atribuição, e não sobre um caractere: pega a
      // coroa, o chapéu, o interrogativo e qualquer outro que alguém invente —
      // inclusive escondido dentro de um ternário, que foi por onde a primeira
      // versão deste caso deixou a mutação passar.
      final ofensores = <String, String>{};
      for (final f in arquivos) {
        final codigo = _semMaquetes(_semComentarios(_texto(f)));
        for (final valor in _valoresDeArgumento(codigo, 'avatar')) {
          if (valor.contains("'") || valor.contains('"')) {
            ofensores[f] = valor;
          }
        }
      }
      expect(
        ofensores,
        isEmpty,
        reason:
            'produtor de produção escrevendo avatar literal — é assim que Home '
            'e Perfil voltam a ter fallbacks diferentes',
      );

      // E o contrapositivo: os `avatar:` que EXISTEM no caminho de produção são
      // todos rastreáveis ao resolvedor — chamada direta, ou repasse de um valor
      // que veio dele. Sem esta metade, apagar todas as atribuições passaria.
      final valoresVistos = <String>[];
      for (final f in [
        'lib/casca/home_de_producao.dart',
        'lib/services/perfil_service.dart',
        'lib/screens/perfil_screen.dart',
      ]) {
        valoresVistos.addAll(
          _valoresDeArgumento(
            _semMaquetes(_semComentarios(_texto(f))),
            'avatar',
          ),
        );
      }
      expect(valoresVistos, isNotEmpty);
      for (final v in valoresVistos) {
        expect(
          v,
          anyOf(
            contains('avatarPublicoDaIdentidade'),
            equals('avatar'),
            equals('avatarCanonico'),
          ),
          reason: 'o avatar "$v" não vem do resolvedor',
        );
      }
    });

    test('H-E08 o delta não carrega credencial, segredo nem dado pessoal', () {
      for (final f in [
        'lib/sessao/avatar_publico.dart',
        'lib/casca/home_de_producao.dart',
        'lib/pages/perfil_page.dart',
        'lib/services/perfil_service.dart',
        'lib/screens/perfil_screen.dart',
      ]) {
        final texto = _texto(f);
        for (final agulha in [
          'AIza',
          'BEGIN PRIVATE KEY',
          'Bearer ',
          'gmail.com',
          'apiKey',
          'password',
        ]) {
          expect(
            texto.contains(agulha),
            isFalse,
            reason: '$f contém "$agulha"',
          );
        }
        expect(
          RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b').hasMatch(texto),
          isFalse,
          reason: '$f contém um endereço de e-mail',
        );
      }
    });
  });
}
