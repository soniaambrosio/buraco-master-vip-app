// seeds.dart — localizacao dos seeds versionados para as suites de teste.
//
// NAO E UM ARQUIVO DE TESTE: nao termina em `_test.dart`, entao nem
// `flutter test` (que so faz glob de `**/*_test.dart`) nem o CI (que roda cada
// suite por caminho explicito) tentam executa-lo.
//
// O PROBLEMA QUE ISTO RESOLVE
//
// Os seeds sao versionados em `app/data/<dominio>/`, mas as suites liam
// `test/<dominio>/data/<nome>` — um caminho que so existe DEPOIS do passo
// "Copiar suites de teste + seeds" do workflow, que os copia para dentro do
// scaffold `app_build/`. Consequencia: verde no CI, e quatro suites falhando no
// CARREGAMENTO (nao no assert) para quem rodasse `flutter test` numa arvore
// limpa. Uma falha de layout se apresentando como regressao.
//
// A resolucao abaixo aceita os dois layouts, na ordem em que cada um e o mais
// especifico. `flutter test` sempre roda com o diretorio corrente na raiz do
// pacote, entao ancorar no CWD e deterministico — e ja e a convencao desta
// suite, que tambem varre `Directory('lib/torneios')` do mesmo jeito.
//
// Nenhum seed e duplicado e nada e gerado em tempo de teste: os arquivos de
// `app/data/` continuam sendo a unica fonte da verdade.

import 'dart:convert';
import 'dart:io';

/// Caminhos onde um seed pode estar, do mais especifico ao mais geral.
///
/// 1. `test/<dominio>/data/` — layout do CI, onde o workflow copia os seeds
///    para dentro do scaffold `app_build/` (la nao existe `data/`).
/// 2. `data/<dominio>/` — arvore do repositorio com o CWD em `app/`, que e como
///    `flutter test` roda localmente.
/// 3. `app/data/<dominio>/` — mesma arvore, mas com o CWD na raiz do
///    repositorio, para invocacoes fora do pacote.
/// Caminhos do seed LEGADO, na mesma ordem e pelo mesmo criterio.
///
/// Existe separado de [_candidatos] porque o legado NAO pode ser alcancavel
/// pelo mesmo nome do ativo: um `lerSeed('torneios', ...)` que caisse no
/// legado por engano devolveria modelos aposentados para quem pediu os
/// vigentes, e o teste ficaria verde provando a coisa errada.
List<String> _candidatosLegado(String dominio, String nome) => [
      'test/$dominio/data/legado/$nome',
      'data/$dominio/legado/$nome',
      'app/data/$dominio/legado/$nome',
    ];

List<String> _candidatos(String dominio, String nome) => [
      'test/$dominio/data/$nome',
      'data/$dominio/$nome',
      'app/data/$dominio/$nome',
    ];

/// Devolve o arquivo do seed `nome` do dominio `dominio` (`torneios`,
/// `colecoes`, ...), procurando nos layouts conhecidos.
///
/// Falha alto e com a lista completa do que foi tentado: seed ausente e erro de
/// configuracao, e o teste nao deve seguir com dado inventado.
File arquivoDeSeed(String dominio, String nome) {
  final tentados = _candidatos(dominio, nome);
  for (final caminho in tentados) {
    final arquivo = File(caminho);
    if (arquivo.existsSync()) return arquivo;
  }
  throw StateError(
    'seed nao encontrado: $dominio/$nome\n'
    'diretorio corrente: ${Directory.current.path}\n'
    'caminhos tentados:\n  ${tentados.join('\n  ')}',
  );
}

/// Le e decodifica o seed `nome` do dominio `dominio`.
Map<String, dynamic> lerSeed(String dominio, String nome) =>
    jsonDecode(arquivoDeSeed(dominio, nome).readAsStringSync())
        as Map<String, dynamic>;

/// Devolve o arquivo do seed LEGADO `nome` do dominio `dominio`.
///
/// Seed legado e material de MIGRACAO E TESTE, e nao de producao: ele mora
/// numa subpasta que o glob `app/data/<dominio>/*.json` nao alcanca, entao
/// nenhum carregador produtivo o encontra por acidente — e nenhuma edicao
/// nasce dele, porque quem le por aqui e teste.
File arquivoDeSeedLegado(String dominio, String nome) {
  final tentados = _candidatosLegado(dominio, nome);
  for (final caminho in tentados) {
    final arquivo = File(caminho);
    if (arquivo.existsSync()) return arquivo;
  }
  throw StateError(
    'seed legado nao encontrado: $dominio/legado/$nome\n'
    'diretorio corrente: ${Directory.current.path}\n'
    'caminhos tentados:\n  ${tentados.join('\n  ')}',
  );
}

/// Le e decodifica o seed LEGADO `nome` do dominio `dominio`.
Map<String, dynamic> lerSeedLegado(String dominio, String nome) =>
    jsonDecode(arquivoDeSeedLegado(dominio, nome).readAsStringSync())
        as Map<String, dynamic>;
