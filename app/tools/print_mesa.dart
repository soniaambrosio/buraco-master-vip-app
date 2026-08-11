// Harness de prints da Mesa canonica — ferramenta de conferencia visual.
//
// NAO faz parte do app: fica fora de `app/lib/`, entao o CI (que copia
// `app/lib/.`) nunca o embarca. Para usar, copie para dentro do scaffold e rode
// com ele como entrypoint:
//
//   cp app/tools/print_mesa.dart app_build/lib/
//   cd app_build && flutter run -d chrome -t lib/print_mesa.dart
//
// Renderiza a MesaScreen em tamanhos fixos, lado a lado com o rotulo, para
// comparar a composicao vertical aprovada com a composicao deitada nova
// (docs/RESULTADO-INTEGRACAO-FLUXO-MESAS.md, secao 4).
import 'package:flutter/material.dart';

import 'mesa.dart';
import 'screens/mesa_orientation_contract.dart';
import 'services/mesa_orientation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Automatica deixa cada quadro escolher pela propria proporcao, entao os
  // quatro tamanhos aparecem juntos na mesma pagina.
  await MesaOrientationService.instance
      .salvar(MesaOrientacaoPreferida.automatica);
  runApp(const _PrintApp());
}

class _PrintApp extends StatelessWidget {
  const _PrintApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101010),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: const [
                _Quadro(
                  rotulo: 'VERTICAL — 390 x 844 (aprovada)',
                  tamanho: Size(390, 844),
                ),
                _Quadro(
                  rotulo: 'HORIZONTAL — 844 x 390 (nova)',
                  tamanho: Size(844, 390),
                ),
                _Quadro(
                  rotulo: 'VERTICAL — 320 x 640 (estreito)',
                  tamanho: Size(320, 640),
                ),
                _Quadro(
                  rotulo: 'HORIZONTAL — 740 x 320 (baixo)',
                  tamanho: Size(740, 320),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Quadro extends StatelessWidget {
  const _Quadro({required this.rotulo, required this.tamanho});

  final String rotulo;
  final Size tamanho;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(
            color: Color(0xFFEFB94A),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: tamanho.width,
          height: tamanho.height,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x55EFB94A)),
          ),
          child: MediaQuery(
            data: MediaQueryData(size: tamanho),
            child: const MesaScreen(),
          ),
        ),
      ],
    );
  }
}
