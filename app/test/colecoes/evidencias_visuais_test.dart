// evidencias_visuais_test.dart — gerador de prints do contrato.
//
// NAO E A TELA DO PRODUTO E NAO PROPOE LAYOUT.
//
// A ordem de servico pede prints do estado elegivel, do resgate, do inventario e
// de um item equipado. Como a apresentacao definitiva e da etapa Codex, este
// arquivo monta o andaime MINIMO capaz de provar que o contrato funciona e que as
// regras da arte sao respeitaveis: fundo escuro neutro, BoxFit.contain, margem
// interna de 8% e transparencia real. Nada aqui e sugestao de design, e nada
// disto entra em lib/ — o aplicativo nao ganhou nenhum widget novo.
//
// Escreve PNG em vez de comparar golden de proposito: comparacao exigiria fonte
// identica entre maquinas, e o objetivo aqui e produzir evidencia, nao travar o
// build. Por isso este arquivo fica FORA do portao de qualidade do CI.
//
// Uso:
//   flutter test test/colecoes/evidencias_visuais_test.dart
// As imagens saem em test/colecoes/evidencias/.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:buraco_master_vip/colecoes/colecao_campanha.dart';
import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:buraco_master_vip/colecoes/colecao_inventario.dart';
import 'package:buraco_master_vip/colecoes/colecao_resgate.dart';
import 'package:buraco_master_vip/colecoes/colecao_ui_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'uid_evidencia';
final _agora = DateTime.utc(2026, 8, 6, 12);
const _saida = 'test/colecoes/evidencias';

/// Chave do trecho capturado.
final _alvo = GlobalKey();

Map<String, dynamic> _lerJson(String nome) => jsonDecode(
      File('test/colecoes/data/$nome').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Tenta usar uma fonte real do sistema. Sem isso o ambiente de teste desenha
/// cada glifo como um retangulo e o print fica ilegivel. Se nao achar nenhuma, a
/// evidencia das ARTES continua valida — so as legendas ficam ruins.
Future<void> _carregarFonte() async {
  const candidatas = [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
  ];
  for (final caminho in candidatas) {
    final arquivo = File(caminho);
    if (!arquivo.existsSync()) continue;
    final loader = FontLoader('EvidenciaSans')
      ..addFont(Future.value(arquivo.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

Future<void> _capturar(WidgetTester tester, String nome) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_alvo));
  final imagem = await boundary.toImage(pixelRatio: 1.0);
  try {
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    Directory(_saida).createSync(recursive: true);
    File('$_saida/$nome.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  } finally {
    // Sem `dispose` a imagem de ~1400x1180 fica retida e o teste nao encerra:
    // o PNG chega a ser gravado, mas o processo so sai pelo timeout.
    imagem.dispose();
  }
}

void main() {
  final catalogo = CatalogoColecoes.fromMap(_lerJson('catalogo.seed.json'));
  final campanhaRaiz = _lerJson('campanha_pioneiros_2026.seed.json');
  final bruto = jsonDecode(jsonEncode(campanhaRaiz['campanha'])) as Map<String, dynamic>;
  bruto['status'] = 'active';
  final campanha = CampanhaColecao.fromMap(bruto);

  InventarioUsuario completo() => InventarioUsuario(
        _uid,
        campanha.rewardIds.map((id) => ItemInventario(
              userId: _uid,
              itemId: id,
              collectionId: campanha.collectionId,
              origem: OrigemItem.campanha,
              campaignId: campanha.campaignId,
              campaignVersion: campanha.version,
              unlockedAt: _agora,
            )),
      );

  ColecaoVM montar({
    required InventarioUsuario inventario,
    bool elegivel = true,
    SituacaoResgate? situacao,
  }) =>
      montarColecaoVM(
        campanha: campanha,
        catalogo: catalogo,
        inventario: inventario,
        veredicto: elegivel
            ? const VeredictoElegibilidade.elegivel()
            : const VeredictoElegibilidade.recusado(RecusaElegibilidade.semEvidencia),
        featureFlagLigada: true,
        situacao: situacao,
      );

  // Um teste por estado, de proposito. Encadear as quatro capturas num unico
  // teste estoura o limite de 10 minutos do `flutter test`: cada estado remonta
  // a arvore e paga a decodificacao das dez artes de novo. Separados, cada print
  // sai em poucos minutos e um estado que falhe nao leva os outros junto.
  void evidencia(String titulo, String nome, String legenda, ColecaoVM Function() build) {
    testWidgets(
      titulo,
      (tester) async {
        await _carregarFonte();
        tester.view.physicalSize = const Size(1400, 1180);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final vm = build();
        await tester.pumpWidget(_Painel(vm: vm, legenda: legenda));

        // A decodificacao do PNG e assincrona e o ambiente de teste nao a
        // executa sozinho: sem `runAsync` o print sai com os cards vazios. A
        // partir da segunda chamada isto e barato, porque as artes ja estao no
        // cache de imagens.
        await tester.runAsync(() async {
          for (final r in vm.recompensas) {
            await precacheImage(
                ResizeImage(AssetImage(r.assetPath!), width: 480),
                tester.element(find.byKey(_alvo)));
          }
        });

        // Pumps contados, e nao `pumpAndSettle`: cada `Image.asset` novo abre um
        // ImageStream, e esperar "assentar" trava ate o timeout mesmo com tudo
        // ja resolvido. Dois quadros bastam para o conteudo aparecer.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await _capturar(tester, nome);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  // --- 01: convite --------------------------------------------------------
  evidencia(
    '01 estado elegivel, kit ainda nao resgatado',
    '01_elegivel_nao_resgatado',
    'Convite: dez pecas visiveis, nenhuma possuida, botao de resgate ativo.',
    () {
      final vm = montar(inventario: InventarioUsuario.vazio(_uid));
      expect(vm.estado, EstadoColecao.eligibleUnclaimed);
      expect(vm.podeResgatar, isTrue);
      return vm;
    },
  );

  // --- 02: resgate concluido ----------------------------------------------
  evidencia(
    '02 resgate concluido, colecao desbloqueada',
    '02_resgate_concluido',
    'Resgate: dez de dez possuidos numa unica operacao.',
    () {
      final vm = montar(inventario: completo(), situacao: SituacaoResgate.concedido);
      expect(vm.estado, EstadoColecao.claimed);
      expect(vm.possuidos, 10);
      return vm;
    },
  );

  // --- 03: segunda chamada -------------------------------------------------
  evidencia(
    '03 inventario apos segunda chamada',
    '03_inventario_ja_resgatado',
    'Segunda chamada: alreadyClaimed, mesmo inventario, sem duplicidade.',
    () {
      final vm = montar(inventario: completo(), situacao: SituacaoResgate.jaResgatado);
      expect(vm.estado, EstadoColecao.alreadyClaimed);
      expect(vm.possuidos, 10, reason: 'repetir a chamada nao duplica nem remove');
      return vm;
    },
  );

  // --- 04: equipagem -------------------------------------------------------
  evidencia(
    '04 itens equipados respeitando a exclusividade de slot',
    '04_itens_equipados',
    'Equipagem: 5 slots ativos; 3 mascotes possuidos e 1 equipado.',
    () {
      // Equipa um item por slot e ainda troca o mascote, para o print mostrar os
      // tres mascotes possuidos com apenas um ativo.
      var inv = completo();
      for (final id in [
        ColecaoItemIds.pioneerCrown,
        ColecaoItemIds.pioneerEmblem,
        ColecaoItemIds.pioneerMascotBulldog,
        ColecaoItemIds.pioneerVortex,
        ColecaoItemIds.pioneerThrone,
      ]) {
        inv = inv.equipar(id, catalogo).inventario!;
      }
      final troca = inv.equipar(ColecaoItemIds.pioneerMascotDragon, catalogo);
      expect(troca.desequipados, [ColecaoItemIds.pioneerMascotBulldog]);
      inv = troca.inventario!;
      expect(inv.equipadosNoSlot('mascote', catalogo), hasLength(1));

      return montar(inventario: inv, situacao: SituacaoResgate.jaResgatado);
    },
  );
}

/// Andaime de captura. Cru de proposito: nada aqui e proposta visual.
class _Painel extends StatelessWidget {
  final ColecaoVM vm;
  final String legenda;

  const _Painel({required this.vm, required this.legenda});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _alvo,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'EvidenciaSans', color: Colors.white),
          // Fundo escuro neutro, conforme RegrasDeExibicao.fundoEscuroNeutro.
          child: ColoredBox(
            color: const Color(0xFF120C18),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vm.titulo,
                      style: const TextStyle(
                          fontFamily: 'EvidenciaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE8C67A))),
                  const SizedBox(height: 4),
                  Text('estado: ${vm.estado.name}  ·  possuidos: '
                      '${vm.possuidos}/${vm.recompensas.length}  ·  '
                      'podeResgatar: ${vm.podeResgatar}'),
                  const SizedBox(height: 2),
                  Text(legenda, style: const TextStyle(fontSize: 12, color: Color(0xFFB9A7C7))),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 5,
                      childAspectRatio: 0.78,
                      children: vm.recompensas.map(_card).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(RecompensaVM r) {
    final marca = r.equipped
        ? 'EQUIPADO'
        : r.owned
            ? (r.canEquip ? 'possuido' : 'possuido (fixo)')
            : 'bloqueado';
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: r.equipped ? const Color(0xFFE8C67A) : const Color(0xFF3A2E46)),
                borderRadius: BorderRadius.circular(8),
              ),
              // Margem interna de 8% do lado: as artes 03, 04, 05, 07 e 08
              // ocupam quase todo o canvas e encostariam na borda sem isso.
              padding: EdgeInsets.all(c.maxWidth * RegrasDeExibicao.paddingVisualMinimo),
              child: Opacity(
                opacity: r.owned ? 1.0 : 0.28,
                // BoxFit.contain: a peca inteira sempre aparece. Nenhum clip,
                // nenhuma mascara, nenhuma placa atras da arte.
                //
                // `cacheWidth` decodifica no tamanho de exibicao em vez dos
                // 1254x1254 originais. Nao recorta e nao deforma — muda apenas
                // o custo de decodificacao, que aqui cai cerca de quinze vezes.
                // A camada visual definitiva deve fazer o mesmo: dez artes
                // decodificadas em tamanho cheio custam ~63 MB de memoria.
                child: Image.asset(r.assetPath!, fit: BoxFit.contain, cacheWidth: 480),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(r.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'EvidenciaSans', fontSize: 10)),
        Text('${r.slot ?? "sem slot"} · $marca',
            style: TextStyle(
                fontFamily: 'EvidenciaSans',
                fontSize: 9,
                color: r.equipped ? const Color(0xFFE8C67A) : const Color(0xFF9A8AA8))),
      ],
    );
  }
}
