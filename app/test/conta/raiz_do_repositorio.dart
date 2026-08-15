// raiz_do_repositorio.dart — onde fica o repositório, visto de dentro do teste.
//
// NÃO É UM ARQUIVO DE TESTE (não termina em `_test.dart`, então o glob do
// `flutter test` o ignora). É o suporte de duas suítes desta OS que precisam ler
// arquivos que NÃO estão sob `app/`: `web/`, `docs/` e
// `.github/workflows/release-aab.yml`.
//
// ---------------------------------------------------------------------------
// POR QUE ANDAR PARA CIMA, E NÃO USAR UM CAMINHO RELATIVO FIXO
// ---------------------------------------------------------------------------
//
// Porque o diretório de trabalho do `flutter test` muda conforme de onde se
// roda, e as duas formas são legítimas neste projeto:
//
//     app/         quando se roda a suíte direto na árvore de verdade
//     app_build/   quando se roda dentro do scaffold que o CI monta
//
// Um `../web` fixo funciona nas duas — mas só por coincidência, e a coincidência
// acaba no dia em que alguém rodar de um terceiro lugar. Subir procurando o
// marcador do repositório funciona sempre, e falha com uma mensagem que diz o
// que houve em vez de um "arquivo não encontrado" sobre um caminho relativo.

import 'dart:io';

/// O marcador da raiz. `.firebaserc` é bom marcador por ser pequeno, estável e
/// único: existe uma vez só, na raiz, e não há um segundo em subdiretório
/// nenhum — ao contrário de `pubspec.yaml`, que existe em `app/` também.
const String _marcador = '.firebaserc';

/// A raiz do repositório, subindo a partir do diretório de trabalho.
///
/// Lança com uma mensagem explicativa se não achar. FALHAR É O CERTO: as suítes
/// que dependem disto conferem o recurso web de exclusão de conta, e um "não
/// achei os arquivos, então passa" transformaria a prova de conformidade numa
/// suíte que passa sem conferir nada.
Directory raizDoRepositorio() {
  var atual = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    if (File('${atual.path}/$_marcador').existsSync()) return atual;
    final pai = atual.parent;
    if (pai.path == atual.path) break;
    atual = pai;
  }
  throw StateError(
    'não encontrei a raiz do repositório (procurei por "$_marcador" subindo a '
    'partir de "${Directory.current.path}"). Estas suítes leem arquivos fora '
    'de app/ — web/, docs/ e .github/ — e não podem ser verificadas sem ela.',
  );
}

/// Lê um arquivo pelo caminho relativo à raiz do repositório.
String lerDaRaiz(String caminhoRelativo) {
  final arquivo = File('${raizDoRepositorio().path}/$caminhoRelativo');
  if (!arquivo.existsSync()) {
    throw StateError('arquivo esperado não existe: $caminhoRelativo');
  }
  return arquivo.readAsStringSync();
}
