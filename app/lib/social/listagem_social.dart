// listagem_social.dart — o CONTRATO de ordenação e paginação (OS §22 a §24).
//
// ONDE A PAGINAÇÃO ACONTECE DE VERDADE, para não haver engano
// ---------------------------------------------------------------------------
//
// No BANCO. `paginaDeAmigos` e `paginaDeSolicitacoes`, em
// `functions-social/src/repositorio.ts`, consultam as projeções
// (`users/{uid}/friends` e `users/{uid}/friendRequests`) com `orderBy` e cursor
// do Firestore, sustentadas por índices declarados em `firestore.indexes.json`.
//
// Este arquivo NÃO é esse caminho. Ele é o que define, num lugar só e de forma
// testável:
//
//   * a CHAVE DE ORDENAÇÃO de §22 — apelido normalizado, publicId como
//     desempate técnico. [EntradaSocial.chaveOrdem] é a definição executável, e
//     o índice composto do Firestore é o espelho dela. Se um dia os dois
//     divergirem, a lista muda de ordem entre páginas e o cursor pula itens;
//     manter a definição aqui torna a divergência visível num teste em vez de
//     num relato de jogador.
//   * os LIMITES de página ([kPaginaPadrao], [kPaginaMaxima]), que a §22 exige
//     e que o TypeScript lê daqui em vez de repetir.
//   * [paginarAmigos], a implementação de referência da mesma ordenação para
//     quem já tem a lista inteira em mãos — hoje, os testes de domínio.
//
// POR QUE O APELIDO NÃO É COPIADO PARA A PROJEÇÃO, e sim resolvido na leitura
// ---------------------------------------------------------------------------
//
// A projeção guarda `apelidoOrdenacao` (para o `orderBy`) e o `publicId`. O
// apelido EXIBIDO e o avatar vêm de `publicProfiles` na hora da consulta. É o
// que faz §31-I ("alteração de apelido refletida sem trocar publicId") valer por
// construção: a troca aparece imediatamente, sem depender de nenhuma propagação
// ter dado certo. O leque que atualiza `apelidoOrdenacao` nos amigos mexe só na
// ORDEM — falhar ali desalinha a posição na lista, nunca o nome mostrado.
//
// AS DUAS LISTAS SÃO ORDENADAS POR CRITÉRIOS DIFERENTES, e não por descuido:
// amigos por apelido (§22); solicitações por `solicitadaEm` decrescente, porque
// §25 proíbe teto de solicitações RECEBIDAS — essa lista é ilimitada por decisão
// antiabuso, e recência é a ordem que se espera de uma caixa de entrada.

import 'apresentacao.dart';

/// Tamanho padrão de página das listas sociais.
///
/// §22: "Não carregar lista ilimitada de uma vez." O padrão é conservador; o
/// cliente pode pedir menos, nunca mais que [kPaginaMaxima].
const int kPaginaPadrao = 25;

/// Teto duro de itens por página.
///
/// Existe para que "paginado" não vire "paginado em uma página só" quando alguém
/// mandar `limite: 100000`.
const int kPaginaMaxima = 50;

/// Normaliza o tamanho de página pedido pelo cliente.
int tamanhoDePagina(Object? pedido) {
  if (pedido is! num) return kPaginaPadrao;
  final n = pedido.toInt();
  if (n <= 0) return kPaginaPadrao;
  return n > kPaginaMaxima ? kPaginaMaxima : n;
}

/// Uma entrada de lista social, já resolvida para apresentação pública.
///
/// NÃO TEM UID (§21). A estrutura interna do backend usa UID; esta classe é a
/// fronteira onde ele para. Se alguém acrescentar um campo `uid` aqui, o teste
/// `LST — nenhuma entrada carrega UID` quebra.
class EntradaSocial {
  final String publicId;
  final String apelido;
  final String? avatarRef;

  /// `amigosDesde` na lista de amigos; `solicitadaEm` nas listas de solicitação.
  final String? desde;

  const EntradaSocial({
    required this.publicId,
    required this.apelido,
    required this.avatarRef,
    required this.desde,
  });

  /// A chave de ordenação de §22: apelido normalizado, publicId como desempate.
  ///
  /// O publicId não é decoração no desempate: apelido não é único (§7), então
  /// sem ele duas pessoas homônimas teriam ordem indefinida entre páginas — e a
  /// paginação por cursor exigiria estabilidade que não existiria.
  ///
  /// O separador é ESPAÇO, e ele é o menor caractere que um apelido válido pode
  /// conter (controles abaixo de U+0020 são recusados por [recusaDeApelido]).
  /// Isso garante que um apelido que é prefixo de outro venha primeiro: "ana"
  /// antes de "ana bia", porque no ponto de comparação o espaço do separador
  /// enfrenta o `b` do apelido mais longo.
  String get chaveOrdem => '${chaveDeOrdenacao(apelido)} $publicId';

  Map<String, Object?> toJson() => {
        'publicId': publicId,
        'apelido': apelido,
        'avatarRef': avatarRef,
        'desde': desde,
      };
}

/// Uma página de lista social.
class PaginaSocial {
  final List<EntradaSocial> itens;

  /// Cursor opaco para a próxima página, ou `null` quando acabou.
  ///
  /// OPACO POR CONTRATO: o cliente devolve o que recebeu, sem interpretar. Hoje
  /// é a [EntradaSocial.chaveOrdem] do último item; se amanhã a ordenação mudar,
  /// nenhum cliente quebra.
  final String? proximoCursor;

  /// Quantos itens existem no total, quando o total é conhecido e barato.
  ///
  /// É conhecido na lista de amigos (a lista inteira foi carregada) e `null` nas
  /// solicitações recebidas (ilimitadas por §25). `null` significa "não
  /// perguntei", e não "zero".
  final int? total;

  const PaginaSocial({
    required this.itens,
    required this.proximoCursor,
    required this.total,
  });

  Map<String, Object?> toJson() => {
        'itens': itens.map((e) => e.toJson()).toList(growable: false),
        'proximoCursor': proximoCursor,
        'total': total,
      };
}

/// Ordena e fatia uma lista de amigos já resolvida (§22).
///
/// [cursor] é o [EntradaSocial.chaveOrdem] do último item da página anterior;
/// `null` na primeira página. A comparação é ESTRITAMENTE MAIOR, então o item do
/// cursor não se repete — e porque a chave inclui o publicId, que é único, não há
/// como um item ser pulado por empate.
PaginaSocial paginarAmigos(
  List<EntradaSocial> todos, {
  String? cursor,
  int limite = kPaginaPadrao,
}) {
  final ordenados = [...todos]
    ..sort((a, b) => a.chaveOrdem.compareTo(b.chaveOrdem));

  final restantes = cursor == null
      ? ordenados
      : ordenados.where((e) => e.chaveOrdem.compareTo(cursor) > 0).toList();

  final pagina = restantes.take(limite).toList(growable: false);
  final acabou = pagina.length >= restantes.length;

  return PaginaSocial(
    itens: pagina,
    proximoCursor: acabou || pagina.isEmpty ? null : pagina.last.chaveOrdem,
    total: ordenados.length,
  );
}
