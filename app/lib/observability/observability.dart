// observability.dart — porta de entrada da camada.
//
// O resto do app importa SÓ este arquivo. Manter uma superfície única é o que
// permite trocar coletor, redator ou formato de manifesto sem tocar em
// nenhuma tela.
//
// Uso no `main.dart`:
//
//     void main() => runBuracoMasterVip(
//           construirApp: () => const BuracoApp(),
//           coletor: ColetorCrashlytics(),
//           antesDeRodar: () => Firebase.initializeApp(options: ...),
//         );

export 'coletor.dart';
export 'evento_falha.dart' show EventoFalha, OrigemFalha, Severidade;
export 'identidade_build.dart';
export 'manifesto_build.dart';
export 'observabilidade.dart';
export 'redacao.dart' show marcaRedacao, Redator, chavesProibidas;
export 'runtime.dart';
export 'trilha_operacional.dart';
