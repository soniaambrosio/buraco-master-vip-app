// corte_relacao.dart — o CORTE de uma relação entre dois jogadores.
//
// SOCIAL-02, fundação (C1). Contrato: CONTRATO_SOCIAL_02_V2 §2.2 e §5.5, com o
// adendo A1–A3 (§2, fronteira de geração).
//
// O PROBLEMA QUE O CORTE RESOLVE. O bloqueio desfaz vínculos por um gatilho
// assíncrono. Se o jogador desbloquear antes de o gatilho rodar, o vínculo antigo
// ainda está "ativo" no banco e, sem o bloqueio, nada mais o impediria. O corte é
// um registro DURÁVEL do par, gravado junto com cada bloqueio e que o desbloqueio
// NÃO apaga: um vínculo só vale se nasceu sob o corte atual do par.
//
// POR QUE MORA EM MODERAÇÃO: quem grava o corte é quem grava o bloqueio. Os dois
// bundles de servidor (social e moderação) importam ESTE arquivo, e a regra
// existe uma vez só.
//
// FRONTEIRA DE IMPORTAÇÃO: este arquivo NÃO importa nada de `lib/social/`. Fora
// das pastas de bundle, um arquivo de `lib/moderacao/` é auditado como código do
// cliente (`test/sessao/auditoria_identidade_test.dart`), e o cliente não pode
// alcançar o domínio social. Nenhuma tela importa este arquivo.

/// Separador da chave do par. Não aparece em UID do Authentication.
const String kSeparadorChaveDeCorte = '|';

/// Nome da coleção do registro de corte (um documento por par não dirigido).
const String kColecaoCortesDeRelacao = 'cortesDeRelacao';

/// A chave do registro de corte de um par NÃO dirigido.
///
/// Os dois UIDs são ordenados: o corte é do par, e não de quem bloqueou. Um
/// bloqueio em qualquer sentido renova o mesmo registro.
///
/// Lança [ArgumentError] para UID vazio, UID com caractere reservado ou par de
/// um jogador consigo mesmo — entradas que nenhum chamador correto produz.
String chaveDoParDeCorte(String uidA, String uidB) {
  final membros = membrosDoParDeCorte(uidA, uidB);
  return '${membros[0]}$kSeparadorChaveDeCorte${membros[1]}';
}

/// Os dois UIDs do par, em ordem. Mesma validação de [chaveDoParDeCorte].
List<String> membrosDoParDeCorte(String uidA, String uidB) {
  _exigirUidDeCorte(uidA);
  _exigirUidDeCorte(uidB);
  if (uidA == uidB) {
    throw ArgumentError('o par de corte exige dois jogadores distintos');
  }
  final ordenados = <String>[uidA, uidB]..sort();
  return List<String>.unmodifiable(ordenados);
}

void _exigirUidDeCorte(String uid) {
  if (uid.isEmpty) {
    throw ArgumentError('uid vazio na chave do corte');
  }
  if (uid.contains(kSeparadorChaveDeCorte) || uid.contains('/')) {
    throw ArgumentError('uid com caractere reservado na chave do corte');
  }
}

/// O vínculo nasceu sob o corte ATUAL do par?
///
/// Par sem registro de corte tem corte "ausente". Vazio e ausente são o mesmo
/// valor: um vínculo legado, sem o campo, vale enquanto o par nunca teve corte, e
/// qualquer bloqueio posterior o invalida.
bool nasceuSobOCorteAtual({
  required String? corteNaCriacao,
  required String? corteAtual,
}) =>
    _corteNormalizado(corteNaCriacao) == _corteNormalizado(corteAtual);

String? _corteNormalizado(String? corte) =>
    (corte == null || corte.isEmpty) ? null : corte;
