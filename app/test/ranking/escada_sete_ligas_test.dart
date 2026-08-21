// escada_sete_ligas_test.dart — o portão da canonização das sete Ligas.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE GUARDA
// ---------------------------------------------------------------------------
//
// A escada competitiva oficial da v1 tem SETE degraus, em ordem crescente:
//
//   bronze  Bronze    abaixo de 950
//   prata   Prata     950 – 1.099
//   ouro    Ouro      1.100 – 1.249
//   platina Platina   1.250 – 1.399
//   diamante Diamante 1.400 – 1.549
//   mestre  Mestre    1.550 – 1.699
//   lenda   Lenda     1.700 ou mais
//
// Não existe oitava liga. Não existe Bronze I/II/III, Diamante III, estrela,
// subdivisão nem patente intermediária. "Imperial" é denominação visual LEGADA
// e não é apelido de nenhuma das sete — ela não volta como `ligaId`, como nome,
// como degrau nem como arte do catálogo.
//
// ---------------------------------------------------------------------------
// POR QUE ELE É DERIVADO, E NÃO UMA SEGUNDA LISTA
// ---------------------------------------------------------------------------
//
// Um gate que redigitasse os sete nomes seria a oitava cópia da escada, e
// divergiria da autoridade no primeiro dia em que alguém mexesse num dos dois
// lados. Este arquivo NÃO redigita: ele LÊ `DEGRAUS_V1` de
// `functions-ranking/src/competicao.ts` — que é a autoridade — e confere todo o
// resto CONTRA ela: a arte no disco, a maquete do catálogo visual, e o que as
// superfícies produtivas exibem.
//
// A única coisa escrita aqui à mão é a lista de sete `ligaId` do grupo L1, e
// ela é a AFIRMAÇÃO DE PRODUTO da OS: é o teste que reprova quando alguém
// acrescenta uma oitava liga ou renomeia uma das sete na própria autoridade.
// Sem ela, este arquivo provaria apenas coerência interna — e um sistema
// coerentemente errado passaria inteiro.
//
// ---------------------------------------------------------------------------
// AS TRÊS ARMADILHAS QUE ELE EVITA DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// 1. COMENTÁRIO NÃO É CÓDIGO. Este arquivo, `ranking_screen.dart` e
//    `competicao.ts` citam "Imperial" e "Diamante III" EM PROSA, para explicar
//    o que foi removido. Uma varredura ingênua acusaria a explicação da remoção
//    como se fosse a violação. Toda varredura aqui passa por [semComentarios].
//
// 2. ÁRVORE VAZIA PASSA. Um laço sobre uma lista que ficou vazia fica verde sem
//    provar nada. Todo grupo que varre ancora numa CONTAGEM antes de varrer.
//
// 3. AUSÊNCIA DO ARQUIVO NÃO É PERMISSÃO. Os arquivos que este gate lê são
//    exigidos, e não tolerados: se a autoridade não estiver alcançável, o gate
//    reprova em vez de devolver verde por não ter tido o que conferir.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/ranking_de_producao.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/estado_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/services/perfil_service.dart';

// ===========================================================================
// A DECISÃO DE PRODUTO — a única lista escrita à mão nesta suíte
// ===========================================================================

/// Os sete `ligaId` oficiais, em ordem crescente.
const ligasOficiais = <String>[
  'bronze',
  'prata',
  'ouro',
  'platina',
  'diamante',
  'mestre',
  'lenda',
];

/// Os sete nomes de exibição, na mesma ordem.
const nomesOficiais = <String>[
  'Bronze',
  'Prata',
  'Ouro',
  'Platina',
  'Diamante',
  'Mestre',
  'Lenda',
];

/// Os doze limites literais da seção 7.1 da OS.
const limitesDaOS = <int, String>{
  949: 'bronze',
  950: 'prata',
  1099: 'prata',
  1100: 'ouro',
  1249: 'ouro',
  1250: 'platina',
  1399: 'platina',
  1400: 'diamante',
  1549: 'diamante',
  1550: 'mestre',
  1699: 'mestre',
  1700: 'lenda',
};

/// A denominação legada. Ela não é liga, não é apelido e não é fallback.
const denominacaoLegada = 'mperial';

// ===========================================================================
// Leitura da AUTORIDADE — `functions-ranking/src/competicao.ts`
// ===========================================================================

/// Um degrau, exatamente como a autoridade o registra.
class Degrau {
  const Degrau({
    required this.ligaId,
    required this.nome,
    required this.icone,
    required this.pontosMinimos,
    required this.pontosMaximos,
  });

  final String ligaId;
  final String nome;
  final String icone;
  final int? pontosMinimos;
  final int? pontosMaximos;

  @override
  String toString() => '$ligaId($pontosMinimos..$pontosMaximos, $icone)';
}

/// A autoridade competitiva, no disco.
///
/// O overlay do CI roda a partir de `app_build/`, e o codebase de ranking fica
/// um nível acima — a mesma geometria que `auditoria_casca_test.dart` usa para
/// alcançar o workflow. A diferença é que ali a ausência é tolerada e AQUI ela
/// é falha: o assunto desta suíte É a autoridade, e um gate que devolve verde
/// quando não achou o que conferir é pior do que gate nenhum.
final File arquivoDaAutoridade = File('../functions-ranking/src/competicao.ts');

final RegExp _degrauTs = RegExp(
  r'\{\s*ligaId:\s*"([^"]*)"\s*,\s*'
  r'nome:\s*"([^"]*)"\s*,\s*'
  r'icone:\s*"([^"]*)"\s*,\s*'
  r'pontosMinimos:\s*(null|-?\d+)\s*,\s*'
  r'pontosMaximos:\s*(null|-?\d+)\s*,?\s*\}',
);

int? _inteiroOuNulo(String bruto) => bruto == 'null' ? null : int.parse(bruto);

/// Lê `DEGRAUS_V1` da autoridade.
///
/// Recorta o bloco da constante antes de casar: casar no arquivo inteiro
/// varreria também as escadas de exemplo dos comentários e os degraus que
/// outras constantes venham a declarar.
List<Degrau> lerAutoridade() {
  final fonte = arquivoDaAutoridade.readAsStringSync();
  const marca = 'export const DEGRAUS_V1';
  final inicio = fonte.indexOf(marca);
  if (inicio < 0) {
    throw StateError('DEGRAUS_V1 não existe mais em ${arquivoDaAutoridade.path}');
  }
  final fim = fonte.indexOf('];', inicio);
  if (fim < 0) {
    throw StateError('o bloco de DEGRAUS_V1 não fecha');
  }
  final bloco = fonte.substring(inicio, fim);
  return [
    for (final m in _degrauTs.allMatches(bloco))
      Degrau(
        ligaId: m.group(1)!,
        nome: m.group(2)!,
        icone: m.group(3)!,
        pontosMinimos: _inteiroOuNulo(m.group(4)!),
        pontosMaximos: _inteiroOuNulo(m.group(5)!),
      ),
  ];
}

/// A Liga de uma pontuação, aplicando a escada lida da autoridade.
///
/// É a MESMA regra de `ligaDe` em `ligas.ts`: percorre na ordem e devolve o
/// primeiro degrau que aceita. Reimplementá-la aqui não cria autoridade nova —
/// os limites continuam vindo do arquivo —, e é o que permite provar os doze
/// limites da seção 7.1 sem rodar Node.
String? ligaDe(List<Degrau> escada, int pontos) {
  for (final d in escada) {
    final dentroDoPiso = d.pontosMinimos == null || pontos >= d.pontosMinimos!;
    final dentroDoTeto = d.pontosMaximos == null || pontos <= d.pontosMaximos!;
    if (dentroDoPiso && dentroDoTeto) return d.ligaId;
  }
  return null;
}

// ===========================================================================
// Leitura da MAQUETE — `lib/screens/ranking_screen.dart`
// ===========================================================================

final File arquivoDaMaquete = File('lib/screens/ranking_screen.dart');

final RegExp _degrauDart = RegExp(
  r"LigaEscada\(\s*"
  r"ligaId:\s*'([^']*)'\s*,\s*"
  r"nome:\s*'([^']*)'\s*,\s*"
  r"icone:\s*'([^']*)'\s*,\s*"
  r"atual:\s*(true|false)\s*,?\s*\)",
);

class DegrauDaMaquete {
  const DegrauDaMaquete(this.ligaId, this.nome, this.icone, this.atual);
  final String ligaId;
  final String nome;
  final String icone;
  final bool atual;
}

List<DegrauDaMaquete> lerMaquete() {
  final fonte = semComentarios(arquivoDaMaquete);
  return [
    for (final m in _degrauDart.allMatches(fonte))
      DegrauDaMaquete(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4) == 'true'),
  ];
}

// ===========================================================================
// Ferramentas de varredura
// ===========================================================================

/// O código de um arquivo, sem comentários e com as strings preservadas.
///
/// Mesma máquina de estados de `casca/auditoria_casca_test.dart`: sem ela, a
/// prosa que EXPLICA a remoção de "Imperial" seria acusada de ser a violação.
String semComentarios(File f) {
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
        if (i + 1 < fonte.length) saida.write(fonte[i + 1]);
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

final RegExp _import = RegExp('import\\s+[\'"]([^\'"]+)[\'"]');

String _barras(String p) => p.replaceAll(r'\', '/');

String _resolver(String de, String alvo) {
  if (alvo.startsWith('package:buraco_master_vip/')) {
    return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(de).split('/')..removeLast();
  for (final parte in alvo.split('/')) {
    if (parte == '..') {
      base.removeLast();
    } else if (parte != '.') {
      base.add(parte);
    }
  }
  return base.join('/');
}

/// O fecho transitivo de imports a partir de `lib/main.dart`.
///
/// É ISTO que "superfície alcançável" significa nesta suíte: o que uma pessoa
/// consegue ver abrindo o aplicativo, e não o que existe na pasta.
Set<String> alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(semComentarios(f))) {
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

/// Todos os `.dart` de `lib/`.
List<File> todosOsFontes() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

// ===========================================================================
// Fixtures do contrato real — a FORMA que `abrirRanking` devolve
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';

Map<String, Object?> jogadorBruto({
  String id = contaA,
  String apelido = 'Sônia',
  String liga = 'Mestre',
  String? ligaId = 'mestre',
  int pontos = 1600,
  int posicao = 3,
  bool souEu = true,
  String estado = 'classificado',
  int qualificacaoRestante = 0,
}) => {
  'id': id,
  'apelido': apelido,
  'avatar': '',
  'liga': liga,
  'ligaId': ligaId,
  'pontos': pontos,
  'posicao': posicao,
  'direcao': 'manteve',
  'delta': 0,
  'selo': null,
  'souEu': souEu,
  'estado': estado,
  'qualificacaoRestante': qualificacaoRestante,
  'partidas': 12,
  'vitorias': 7,
  'derrotas': 5,
  'aproveitamento': 58.3,
};

Map<String, Object?> abertura({Object? eu, List<Map<String, Object?>>? itens}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': 'T-2026-01',
    'temporadaNome': 'Temporada 1',
    'faixaTempo': 'em andamento',
    'fimEm': null,
    'divisao': null,
    'podio': const <Map<String, Object?>>[],
    'escadaLigas': const <Map<String, Object?>>[],
    'eu': eu,
  },
  'primeiraPagina': {
    'itens': itens ?? [if (eu != null) eu as Map<String, Object?>],
    'cursorProxima': null,
    'fim': true,
  },
};

class TransporteFixo extends TransporteRanking {
  TransporteFixo(this.resposta);
  final Object? resposta;

  @override
  Future<AberturaRanking> abrirRanking() =>
      Future.value(AberturaRanking.daResposta(resposta));

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) =>
      Future.value(FotografiaRanking.semColocacao(temporadaId: 'T-2026-01'));
}

void telefone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

String textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// Monta o Ranking produtivo com a resposta que o caso quiser, pelo caminho
/// real: transporte → leitor → sessão → escopo → tela.
Future<void> montarRanking(WidgetTester tester, Object? resposta) async {
  telefone(tester);
  final ranking = RankingDaSessao(
    leitor: LeitorDeRanking(transporte: TransporteFixo(resposta)),
  );
  addTearDown(ranking.dispose);
  ranking.aoMudarSessao(geracao: 1, publicId: contaA);
  await tester.pumpWidget(
    EscopoRanking(
      ranking: ranking,
      child: const MaterialApp(home: RankingDeProducao()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

PerfilVM vmCom(EstadoRanking ranking) => PerfilVM(
  ehMeuPerfil: true,
  nome: 'Sônia',
  avatar: '👑',
  mascote: '🦊',
  moldura: 'assets/perfil/vitrine_moldura.webp',
  dorso: 'assets/perfil/vitrine_dorso.webp',
  efeito: 'assets/perfil/vitrine_efeito.webp',
  nivel: null,
  xpAtual: null,
  xpProximo: null,
  titulo: null,
  tituloEmoji: null,
  ranking: ranking,
  stats: null,
  ultimaConquista: null,
  presentesCount: null,
  conquistas: null,
  vitrine: const [],
  presentes: const [],
);

Future<void> montarPerfil(WidgetTester tester, PerfilVM vm) async {
  telefone(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: vm,
        onVoltar: () {},
        onAbrirConfig: () {},
        onTrocarAvatar: () {},
        onEditarNick: () {},
        onEditarPerfil: () {},
        onAbrirPresentes: () {},
        onFecharPresentes: () {},
        onVerTodasConquistas: () {},
        onVerConquista: (_) {},
        onVerUltimaConquista: () {},
        onTrocarVitrine: () {},
        onCompartilhar: () {},
        onRecarregar: () {},
        onNavTap: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Uma arte já decodificada: dimensões e o canal alfa de cada pixel.
class Arte {
  const Arte(this.largura, this.altura, this._pixels);
  final int largura;
  final int altura;
  final ByteData _pixels;

  int alfa(int x, int y) => _pixels.getUint8(((y * largura) + x) * 4 + 3);

  /// Quantos pixels são COMPLETAMENTE transparentes.
  int get vazios {
    var n = 0;
    for (var y = 0; y < altura; y++) {
      for (var x = 0; x < largura; x++) {
        if (alfa(x, y) == 0) n++;
      }
    }
    return n;
  }

  /// Quantos pixels são sólidos o bastante para contar como desenho.
  int get desenhados {
    var n = 0;
    for (var y = 0; y < altura; y++) {
      for (var x = 0; x < largura; x++) {
        if (alfa(x, y) > 200) n++;
      }
    }
    return n;
  }

  int get total => largura * altura;
}

/// Decodifica um asset do PACOTE e devolve a arte pronta para medição.
///
/// SÓ RODA DENTRO DE `tester.runAsync`, e não é detalhe de estilo:
/// `testWidgets` executa num relógio falso, e o `Future` que o decodificador
/// de imagem devolve é completado pela engine REAL, fora desse relógio. Sem
/// `runAsync`, o `await` nunca retorna e a suíte fica pendurada para sempre —
/// sem erro, sem timeout e sem uma linha de log dizendo o que houve. Custou
/// dez minutos de execução muda na primeira escrita deste arquivo.
///
/// E O `expect` FICA DE FORA. Uma asserção que falha DENTRO de `runAsync`
/// vira exceção em código assíncrono, e o `flutter_test` a reporta atribuída
/// ao caso ERRADO — depois de pendurar a execução. Aqui dentro só se colhe o
/// dado; quem julga é o corpo do caso, no relógio do teste.
Future<Arte> lerArte(String caminho) async {
  final dados = await rootBundle.load(caminho);
  final codec = await ui.instantiateImageCodec(dados.buffer.asUint8List());
  final quadro = await codec.getNextFrame();
  final imagem = quadro.image;
  final pixels = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
  final arte = Arte(imagem.width, imagem.height, pixels!);
  imagem.dispose();
  codec.dispose();
  return arte;
}

void main() {
  // =========================================================================
  // L1 — A AUTORIDADE
  // =========================================================================
  group('L1 — a escada oficial vive num lugar só, e tem sete degraus', () {
    late List<Degrau> escada;

    setUpAll(() {
      // FALHA FECHADA. Sem a autoridade alcançável, o grupo inteiro não tem o
      // que provar — e devolver verde nesse caso seria exatamente o buraco que
      // esta suíte existe para não abrir.
      expect(
        arquivoDaAutoridade.existsSync(),
        isTrue,
        reason:
            'a autoridade competitiva não está alcançável em '
            '${arquivoDaAutoridade.path} — o gate não pode passar sem lê-la',
      );
      escada = lerAutoridade();
      expect(
        escada,
        isNotEmpty,
        reason: 'DEGRAUS_V1 foi lido e veio vazio — a varredura mediria nada',
      );
    });

    test('L1a — são exatamente SETE degraus', () {
      expect(escada, hasLength(7));
    });

    test('L1b — os sete `ligaId`, na ordem crescente oficial', () {
      expect(escada.map((d) => d.ligaId).toList(), ligasOficiais);
    });

    test('L1c — os sete nomes de exibição, na mesma ordem', () {
      expect(escada.map((d) => d.nome).toList(), nomesOficiais);
    });

    test('L1d — Bronze tem piso ABERTO e Lenda tem teto ABERTO', () {
      expect(escada.first.pontosMinimos, isNull);
      expect(escada.last.pontosMaximos, isNull);
      // E só as pontas: um piso ou teto aberto no meio engoliria vizinhos.
      for (var i = 1; i < escada.length; i++) {
        expect(escada[i].pontosMinimos, isNotNull, reason: escada[i].ligaId);
      }
      for (var i = 0; i < escada.length - 1; i++) {
        expect(escada[i].pontosMaximos, isNotNull, reason: escada[i].ligaId);
      }
    });

    test('L1e — as faixas encaixam sem buraco e sem sobreposição', () {
      for (var i = 0; i < escada.length - 1; i++) {
        expect(
          escada[i + 1].pontosMinimos,
          escada[i].pontosMaximos! + 1,
          reason: 'entre ${escada[i].ligaId} e ${escada[i + 1].ligaId}',
        );
      }
    });

    test('L1f — OS DOZE LIMITES da seção 7.1, um a um', () {
      limitesDaOS.forEach((pontos, ligaId) {
        expect(ligaDe(escada, pontos), ligaId, reason: 'pontuação $pontos');
      });
      // A tabela do teste é a da OS; se ela encolher, o teste que a percorre
      // ficaria verde medindo menos. A contagem é a âncora.
      expect(limitesDaOS, hasLength(12));
    });

    test('L1g — PONTUAÇÃO NEGATIVA cai em Bronze, porque o piso é aberto', () {
      for (final pontos in const [-1, -100, -5000, -999999]) {
        expect(ligaDe(escada, pontos), 'bronze', reason: 'pontuação $pontos');
      }
    });

    test('L1h — toda pontuação tem Liga, dos dois lados', () {
      for (final pontos in const [-999999, 0, 949, 950, 1699, 1700, 999999]) {
        expect(ligaDe(escada, pontos), isNotNull, reason: 'pontuação $pontos');
      }
    });

    test('L1i — NÃO há subdivisão, estrela nem patente intermediária', () {
      final subdivisao = RegExp(r'\b(I{1,3}|IV|V|1|2|3)\b');
      for (final d in escada) {
        expect(
          subdivisao.hasMatch(d.nome),
          isFalse,
          reason: '"${d.nome}" parece subdividido',
        );
        for (final proibido in const [
          'divisao',
          'divisão',
          'estrela',
          'promocao',
          'promoção',
        ]) {
          expect(
            d.ligaId.toLowerCase().contains(proibido),
            isFalse,
            reason: '${d.ligaId} carrega "$proibido"',
          );
        }
      }
    });

    test('L1j — IMPERIAL não é `ligaId`, nome, degrau nem arte', () {
      for (final d in escada) {
        expect(d.ligaId.toLowerCase(), isNot(contains(denominacaoLegada)));
        expect(d.nome.toLowerCase(), isNot(contains(denominacaoLegada)));
        expect(d.icone.toLowerCase(), isNot(contains(denominacaoLegada)));
      }
    });

    test('L1k — a Mestre é o SEXTO degrau, e a Lenda é o sétimo', () {
      expect(escada[5].ligaId, 'mestre');
      expect(escada[5].pontosMinimos, 1550);
      expect(escada[5].pontosMaximos, 1699);
      expect(escada[6].ligaId, 'lenda');
      expect(escada[6].pontosMinimos, 1700);
      expect(escada[6].pontosMaximos, isNull);
    });
  });

  // =========================================================================
  // L2 — A ARTE
  // =========================================================================
  group('L2 — os sete degraus têm arte, e ela carrega', () {
    late List<Degrau> escada;

    setUpAll(() {
      expect(arquivoDaAutoridade.existsSync(), isTrue);
      escada = lerAutoridade();
      expect(escada, hasLength(7));
    });

    test('L2a — nenhum dos sete sai com `icone` vazio', () {
      for (final d in escada) {
        expect(d.icone, isNotEmpty, reason: '${d.ligaId} ficou sem arte');
      }
    });

    test('L2b — os sete caminhos são DISTINTOS', () {
      expect(escada.map((d) => d.icone).toSet(), hasLength(7));
    });

    test('L2c — cada arte declarada EXISTE no disco do aplicativo', () {
      for (final d in escada) {
        final f = File(d.icone);
        expect(
          f.existsSync(),
          isTrue,
          reason: '${d.ligaId}: a arte declarada não está em ${d.icone}',
        );
        expect(f.lengthSync(), greaterThan(0), reason: d.ligaId);
      }
    });

    test('L2d — `assets/ranking/` está DECLARADO no pubspec', () {
      final pubspec = File('pubspec.yaml');
      expect(
        pubspec.existsSync(),
        isTrue,
        reason: 'sem pubspec não há como afirmar que a arte entra no pacote',
      );
      expect(
        pubspec.readAsStringSync(),
        contains('- assets/ranking/'),
        reason: 'a pasta das Ligas saiu da lista de assets — a arte não seria '
            'empacotada, e nenhum erro de compilação avisaria',
      );
    });

    test('L2e — a Mestre aponta para a arte da Mestre', () {
      final mestre = escada.firstWhere((d) => d.ligaId == 'mestre');
      expect(mestre.icone, 'assets/ranking/liga_mestre.webp');
    });

    test('L2f — nenhuma arte do catálogo é a legada da Imperial', () {
      for (final d in escada) {
        expect(
          d.icone.toLowerCase(),
          isNot(contains(denominacaoLegada)),
          reason: '${d.ligaId} voltou a usar a arte legada',
        );
      }
    });

    test('L2g — a arte legada continua no disco, e FORA do catálogo', () {
      // A OS manda tirar do catálogo oficial e PERMITE que o arquivo permaneça
      // como legado não referenciado até uma limpeza independente. As duas
      // metades ficam afirmadas: nem o retorno ao catálogo nem a remoção
      // silenciosa do arquivo passam despercebidos.
      expect(File('assets/ranking/liga_imperial.webp').existsSync(), isTrue);
      expect(
        escada.any((d) => d.icone.contains('liga_imperial')),
        isFalse,
      );
    });

    test('L2h — a arte legada não é referenciada por nenhum código de `lib/`', () {
      final fontes = todosOsFontes();
      expect(fontes.length, greaterThan(20), reason: 'a varredura ficou sem árvore');
      for (final f in fontes) {
        expect(
          semComentarios(f),
          isNot(contains('liga_imperial')),
          reason: '${f.path} ainda carrega a arte legada',
        );
        expect(
          semComentarios(f),
          isNot(contains('divisao_diamante')),
          reason: '${f.path} ainda carrega a arte da subdivisão',
        );
      }
    });

    testWidgets('L2i — as SETE artes carregam pelo pacote e DECODIFICAM', (
      tester,
    ) async {
      // "Carregável" tem duas metades, e as duas são medidas aqui: o
      // `rootBundle` prova que o arquivo entrou no PACOTE (declaração no
      // pubspec), e o decodificador prova que os bytes são uma imagem de
      // verdade. Um arquivo truncado passa na primeira e morre na segunda.
      final artes = <String, Arte>{};
      await tester.runAsync(() async {
        for (final d in escada) {
          artes[d.ligaId] = await lerArte(d.icone);
        }
      });

      expect(artes, hasLength(7));
      for (final d in escada) {
        final arte = artes[d.ligaId]!;
        expect(arte.largura, greaterThan(0), reason: d.ligaId);
        expect(arte.altura, greaterThan(0), reason: d.ligaId);
        expect(
          arte.desenhados,
          greaterThan(0),
          reason: '${d.ligaId}: a arte decodifica e não tem pixel nenhum',
        );
      }
    });

    testWidgets('L2j — `liga_mestre.webp` é 256x256 com ALFA REAL', (
      tester,
    ) async {
      // 256 E NÃO 1024: as outras seis Ligas são 88x88 lógicos, e a lista da
      // escada as desenha em 30. A fonte de 1024 existe e está preservada
      // FORA do pacote, em `docs/artes/` — carregá-la aqui seria gastar um
      // megabyte de memória para pintar trinta pixels.
      late Arte arte;
      await tester.runAsync(() async {
        arte = await lerArte('assets/ranking/liga_mestre.webp');
      });

      expect(arte.largura, 256);
      expect(arte.altura, 256);

      // OS QUATRO CANTOS SÃO TRANSPARENTES. É a prova de que o canal alfa é
      // real, e não uma bandeira ligada num arquivo opaco.
      for (final (x, y) in const [(0, 0), (255, 0), (0, 255), (255, 255)]) {
        expect(
          arte.alfa(x, y),
          0,
          reason: 'o canto ($x,$y) não é transparente',
        );
      }

      // E HÁ ARTE NO MEIO: um arquivo inteiramente transparente passaria no
      // teste acima com louvor.
      expect(
        arte.desenhados,
        greaterThan(arte.total ~/ 10),
        reason: 'a arte da Mestre está vazia ou quase',
      );
    });

    testWidgets('L2k — não há fundo QUADRICULADO incorporado na Mestre', (
      tester,
    ) async {
      // O xadrez de transparência é artefato de exportação: o editor pinta o
      // padrão cinza-claro/cinza-escuro por baixo e alguém achata a imagem com
      // ele dentro. A assinatura dele é dura e é esta: NÃO SOBRA VAZIO. Uma
      // arte achatada sobre xadrez tem zero pixel completamente transparente,
      // porque cada quadradinho é sólido.
      //
      // A MEDIDA NÃO É "A BORDA É TODA VAZIA", e a diferença importa: esta arte
      // tem um elemento vertical que ENCOSTA no topo e na base, e catorze
      // pixels da moldura são legitimamente opacos. Exigir moldura limpa
      // reprovaria a arte por ser bem enquadrada. O que se exige é proporção:
      // xadrez achatado dá ~100% de moldura opaca, não 0,7%.
      late Arte arte;
      await tester.runAsync(() async {
        arte = await lerArte('assets/ranking/liga_mestre.webp');
      });

      expect(
        arte.vazios,
        greaterThan(arte.total ~/ 4),
        reason: 'só ${arte.vazios} de ${arte.total} pixels são vazios — uma arte sobre xadrez achatado não deixa vazio nenhum',
      );

      var opacosNaBorda = 0;
      var amostras = 0;
      for (var x = 0; x < arte.largura; x++) {
        for (final y in [0, 1, arte.altura - 2, arte.altura - 1]) {
          amostras++;
          if (arte.alfa(x, y) != 0) opacosNaBorda++;
        }
      }
      for (var y = 0; y < arte.altura; y++) {
        for (final x in [0, 1, arte.largura - 2, arte.largura - 1]) {
          amostras++;
          if (arte.alfa(x, y) != 0) opacosNaBorda++;
        }
      }
      expect(amostras, greaterThan(1000), reason: 'amostragem degenerada');
      expect(
        opacosNaBorda * 100,
        lessThan(amostras * 5),
        reason: 'a moldura tem $opacosNaBorda pixels opacos em $amostras — '
            'acima de 5% é fundo achatado, e não arte encostando na borda',
      );
    });
  });

  // =========================================================================
  // L3 — A MAQUETE ESPELHA A AUTORIDADE
  // =========================================================================
  group('L3 — o catálogo visual espelha a escada, e não a substitui', () {
    late List<Degrau> escada;
    late List<DegrauDaMaquete> maquete;

    setUpAll(() {
      expect(arquivoDaAutoridade.existsSync(), isTrue);
      expect(arquivoDaMaquete.existsSync(), isTrue);
      escada = lerAutoridade();
      maquete = lerMaquete();
      expect(escada, hasLength(7));
      expect(
        maquete,
        isNotEmpty,
        reason: 'a escada da maquete sumiu — nada seria conferido',
      );
    });

    test('L3a — a maquete tem os SETE degraus', () {
      expect(maquete, hasLength(7));
    });

    test('L3b — os `ligaId` batem com a autoridade, na mesma ordem', () {
      expect(
        maquete.map((d) => d.ligaId).toList(),
        escada.map((d) => d.ligaId).toList(),
      );
    });

    test('L3c — os NOMES batem com a autoridade, na mesma ordem', () {
      expect(
        maquete.map((d) => d.nome).toList(),
        escada.map((d) => d.nome).toList(),
      );
    });

    test('L3d — as ARTES batem com a autoridade, degrau a degrau', () {
      expect(
        maquete.map((d) => d.icone).toList(),
        escada.map((d) => d.icone).toList(),
      );
    });

    test('L3e — exatamente UM degrau está marcado como atual', () {
      expect(maquete.where((d) => d.atual).length, 1);
    });

    test('L3f — a Lenda está na maquete, e no topo', () {
      expect(maquete.last.ligaId, 'lenda');
      expect(maquete.last.nome, 'Lenda');
    });

    test('L3g — a maquete não desenha subdivisão nenhuma', () {
      final codigo = semComentarios(arquivoDaMaquete);
      for (final proibido in const [
        'Diamante III',
        'Diamante II',
        'Bronze I',
        'Prata I',
        'Ouro I',
        'Platina I',
        'DivisaoAtual',
        'proximaDivisao',
      ]) {
        expect(
          codigo,
          isNot(contains(proibido)),
          reason: 'a subdivisão "$proibido" voltou à maquete',
        );
      }
    });

    test('L3h — nenhum arquivo de `lib/` escreve "Imperial" em código', () {
      final fontes = todosOsFontes();
      expect(fontes.length, greaterThan(20), reason: 'a varredura ficou sem árvore');
      for (final f in fontes) {
        expect(
          semComentarios(f).toLowerCase(),
          isNot(contains(denominacaoLegada)),
          reason: '${f.path} voltou a nomear a denominação legada',
        );
      }
    });

    test('L3i — o catálogo visual NÃO é alcançável pela raiz de produção', () {
      // A maquete pode afirmar jogador; ela não pode ser exibida como produto.
      final alcancaveis = alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis.length, greaterThan(20));
      expect(alcancaveis, isNot(contains('lib/screens/ranking_screen.dart')));
    });
  });

  // =========================================================================
  // L4 — AS SUPERFÍCIES PRODUTIVAS
  // =========================================================================
  group('L4 — Ranking, Perfil e Home dizem a MESMA liga', () {
    testWidgets('L4a — o Ranking exibe o rótulo que a autoridade mandou', (
      tester,
    ) async {
      await montarRanking(tester, abertura(eu: jogadorBruto()));
      expect(textoDaTela(tester), contains('Mestre'));
    });

    testWidgets('L4b — o Perfil exibe a MESMA liga, do MESMO payload', (
      tester,
    ) async {
      // O mesmo mapa que alimentou o Ranking, atravessando o mesmo tradutor.
      final foto = FotografiaRanking.daAbertura(abertura(eu: jogadorBruto()));
      final estado = EstadoRanking.daFotografia(foto);
      expect(estado.liga, 'Mestre');
      expect(estado.ehLigaDeVerdade, isTrue);

      await montarPerfil(tester, vmCom(estado));
      expect(textoDaTela(tester), contains('Mestre'));
    });

    test('L4c — a Home conclui a MESMA coisa, pela mesma regra', () {
      // A Home lê `ehLigaDeVerdade ? liga : null` — a regra está em
      // `home_de_producao.dart` e é conferida aqui contra o mesmo estado.
      final foto = FotografiaRanking.daAbertura(abertura(eu: jogadorBruto()));
      final estado = EstadoRanking.daFotografia(foto);
      final ligaNaHome = estado.ehLigaDeVerdade ? estado.liga : null;
      expect(ligaNaHome, 'Mestre');
      expect(estado.ligaParaExibicao, 'Mestre');
    });

    testWidgets('L4d — EM COLOCAÇÃO nunca vira Bronze, em superfície nenhuma', (
      tester,
    ) async {
      final bruto = jogadorBruto(
        liga: 'Em colocacao',
        ligaId: null,
        estado: 'em_colocacao',
        qualificacaoRestante: 7,
      );
      final estado = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(abertura(eu: bruto)),
      );

      expect(estado.liga, 'Em colocacao');
      // NÃO é Liga: `ligaId` veio nulo, e é ele que distingue rótulo de estado.
      expect(estado.ehLigaDeVerdade, isFalse);

      await montarRanking(tester, abertura(eu: bruto));
      final noRanking = textoDaTela(tester);
      expect(noRanking, contains('Em colocacao'));
      expect(noRanking, isNot(contains('Bronze')));

      await montarPerfil(tester, vmCom(estado));
      final noPerfil = textoDaTela(tester);
      expect(noPerfil, contains('Em colocacao'));
      expect(noPerfil, isNot(contains('Bronze')));
      // E sem o prefixo fixo: "Liga Em colocacao" não é português nem verdade.
      expect(noPerfil, isNot(contains('Liga Em colocacao')));
    });

    testWidgets('L4e — EM REVALIDAÇÃO não vira Bronze nem a liga anterior', (
      tester,
    ) async {
      final bruto = jogadorBruto(
        liga: 'Em revalidacao',
        ligaId: null,
        estado: 'em_revalidacao',
        qualificacaoRestante: 3,
      );
      final estado = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(abertura(eu: bruto)),
      );
      expect(estado.liga, 'Em revalidacao');
      expect(estado.ehLigaDeVerdade, isFalse);

      await montarRanking(tester, abertura(eu: bruto));
      final texto = textoDaTela(tester);
      expect(texto, contains('Em revalidacao'));
      expect(texto, isNot(contains('Bronze')));
      // A liga da temporada passada também não vaza para cá.
      for (final nome in nomesOficiais) {
        expect(texto, isNot(contains(nome)), reason: '$nome vazou para a revalidação');
      }
    });

    test('L4f — LIGA DESCONHECIDA produz estado neutro, e não Bronze', () {
      // Um rótulo que o cliente não conhece é repassado como veio; o que ele
      // NUNCA faz é escolher uma das sete por conta própria. E sem `ligaId` ele
      // não afirma que aquilo é uma Liga.
      final foto = FotografiaRanking.daAbertura(
        abertura(eu: jogadorBruto(liga: 'Faixa Nova', ligaId: null)),
      );
      final estado = EstadoRanking.daFotografia(foto);
      expect(estado.liga, 'Faixa Nova');
      expect(estado.ehLigaDeVerdade, isFalse);

      // E o rótulo VAZIO é ausência declarada — travessão, nunca Bronze.
      final vazio = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(
          abertura(eu: jogadorBruto(liga: '', ligaId: null)),
        ),
      );
      expect(vazio.liga, isNull);
      expect(vazio.ligaParaExibicao, '—');
      expect(vazio.temLiga, isFalse);
    });

    test('L4g — sem resposta da autoridade, não há liga nenhuma', () {
      for (final estado in const [
        EstadoRanking.indisponivel(),
        EstadoRanking.carregando(),
        EstadoRanking.falha(),
      ]) {
        expect(estado.liga, isNull, reason: '$estado');
        expect(estado.ehLigaDeVerdade, isFalse, reason: '$estado');
        expect(estado.ligaParaExibicao, '—', reason: '$estado');
      }
      // E a constante que a casca publicável usa é uma dessas — não uma liga.
      expect(rankingDaCascaPublicavel.liga, isNull);
    });

    testWidgets('L4h — quem não pontuou não recebe Liga nenhuma', (
      tester,
    ) async {
      // `resumo.eu == null` é a resposta legítima para quem ainda não entrou na
      // tabela. Foi exatamente aqui que este aplicativo já escreveu Bronze.
      final estado = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(abertura(eu: null)),
      );
      expect(estado.liga, isNull);

      await montarPerfil(tester, vmCom(estado));
      expect(textoDaTela(tester), isNot(contains('Bronze')));
    });
  });

  // =========================================================================
  // L5 — NINGUÉM CONCEDE LIGA PELO CLIENTE
  // =========================================================================
  group('L5 — a Liga é derivada pela autoridade, e só por ela', () {
    late Set<String> alcancaveis;

    setUpAll(() {
      alcancaveis = alcancaveisDaRaiz();
      expect(
        alcancaveis.length,
        greaterThan(20),
        reason: 'o fecho produtivo ficou pequeno demais para provar alguma coisa',
      );
    });

    test('L5a — NENHUM limite da escada existe no código alcançável', () {
      // Esta é a prova estrutural de que o cliente não pode derivar Liga: ele
      // não tem as faixas. Sem elas, "sou Mestre" não é uma conta que caiba
      // aqui — é uma afirmação que só o servidor sabe fazer.
      final numeros = RegExp(
        r'\b(949|950|1099|1100|1249|1250|1399|1400|1549|1550|1699|1700)\b',
      );
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final achado = numeros.firstMatch(semComentarios(f));
        expect(
          achado,
          isNull,
          reason: '$caminho passou a conhecer o limite ${achado?.group(0)} — '
              'uma segunda tabela de faixas no cliente',
        );
      }
    });

    test('L5b — nada alcançável equipa Mestre ou Lenda', () {
      // As duas do topo são as que valem a pena forjar. Nenhum arquivo que a
      // pessoa alcança abrindo o aplicativo escreve os nomes delas.
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final codigo = semComentarios(f);
        for (final nome in const ['Mestre', 'Lenda']) {
          expect(
            codigo,
            isNot(contains("liga: '$nome'")),
            reason: '$caminho concede $nome sem passar pela autoridade',
          );
          expect(
            codigo,
            isNot(contains("ligaId: '${nome.toLowerCase()}'")),
            reason: '$caminho carimba ${nome.toLowerCase()} localmente',
          );
        }
      }
    });

    test('L5c — a preferência local não guarda liga', () {
      // SharedPreferences sobrevive à sessão e é editável com o aparelho na
      // mão: uma liga gravada ali seria uma liga concedida por quem tem acesso
      // ao arquivo.
      final suspeitas = RegExp(r"(setString|getString)\(\s*'[^']*liga");
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        expect(
          suspeitas.hasMatch(semComentarios(f)),
          isFalse,
          reason: '$caminho persiste liga na preferência local',
        );
      }
    });

    test('L5d — só `EstadoRanking.daFotografia` produz liga de verdade', () {
      // `ehLigaDeVerdade` exige `ligaId`, e o único construtor que o preenche a
      // partir de dado externo é o que lê a fotografia do transporte. Os outros
      // são estados neutros — e é isto que impede que um `EstadoRanking`
      // montado à mão em qualquer canto da casca vire uma Liga.
      const semId = EstadoRanking.disponivel(liga: 'Mestre');
      expect(semId.liga, 'Mestre');
      expect(
        semId.ehLigaDeVerdade,
        isFalse,
        reason: 'um estado montado à mão passou a valer como Liga',
      );

      final comAutoridade = EstadoRanking.daFotografia(
        FotografiaRanking.daAbertura(abertura(eu: jogadorBruto())),
      );
      expect(comAutoridade.ehLigaDeVerdade, isTrue);
      expect(comAutoridade.ligaId, 'mestre');
    });

    test('L5f — BRONZE não aparece como valor no código alcançável', () {
      // Bronze era O fallback, e por isso ele é o único dos sete nomes
      // proibido POR SI no fecho produtivo. Quando nada se sabia, a casca
      // escrevia `liga: 'Bronze'` e a pessoa lia um rebaixamento que nunca
      // aconteceu — em três lugares ao mesmo tempo, incluindo o texto que saía
      // do aparelho no compartilhamento.
      //
      // Os outros seis nomes NÃO estão proibidos aqui, e a assimetria é
      // deliberada: eles aparecem em fixture declarada de prévia (a maquete do
      // Perfil, a do Saguão), e nenhum deles jamais foi valor-padrão de coisa
      // nenhuma. Proibir os sete transformaria este caso numa briga com o
      // catálogo visual em vez de uma guarda contra o defeito real.
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        expect(
          semComentarios(f),
          isNot(contains("'Bronze'")),
          reason: '$caminho voltou a escrever Bronze — o fallback de quem não '
              'tem resposta da autoridade',
        );
      }
    });

    test('L5e — a chave de demonstração do Perfil está DESLIGADA', () {
      // Uma bandeira de depuração ligada em release equipara maquete a
      // produto: com ela ativa, o Perfil publicável volta a afirmar liga e
      // colocação de fixture.
      expect(PerfilService.statsDemo, isFalse);
    });
  });

  // =========================================================================
  // L6 — O PORTÃO SOBREVIVE A SI MESMO
  // =========================================================================
  group('L6 — este gate está registrado onde reprova', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');

    test('L6a — a suíte existe na árvore', () {
      expect(
        File('test/ranking/escada_sete_ligas_test.dart').existsSync(),
        isTrue,
        reason: 'a suíte da canonização sumiu — e ausência vira NÃO EXECUTADO',
      );
    });

    test('L6b — o manifesto das obrigatórias registra `ligas7`', () {
      final manifesto = File('test/suites_obrigatorias.txt');
      expect(manifesto.existsSync(), isTrue);
      expect(
        manifesto.readAsStringSync(),
        contains('ligas7'),
        reason: 'sem entrada no manifesto, apagar esta suíte volta a ser '
            'silencioso',
      );
    });

    test('L6c — o workflow executa a suíte e a considera no portão', () {
      // Fora do CI o workflow pode não estar alcançável. O caso não afirma
      // errado nesse caso — e o manifesto, conferido acima, continua valendo.
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();
      expect(
        texto,
        contains('roda ligas7     test/ranking/escada_sete_ligas_test.dart'),
        reason: 'o gate ligas7 não executa mais a suíte',
      );
      expect(
        RegExp(r'GATES="[^"]*\bligas7\b').hasMatch(texto),
        isTrue,
        reason: 'ligas7 saiu da evidência publicada',
      );
      expect(
        RegExp(r'for k in [^;]*\bligas7\b[^;]*; do').hasMatch(texto),
        isTrue,
        reason: 'ligas7 saiu do portão verde/vermelho',
      );
    });
  });
}
