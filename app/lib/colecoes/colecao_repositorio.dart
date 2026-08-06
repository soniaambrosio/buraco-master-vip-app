// colecao_repositorio.dart — contrato de acesso a dados do modulo de colecoes.
//
// Camada pura: sem Firestore, sem Cloud Functions, sem Flutter. Aqui mora a
// INTERFACE; a implementacao real vive em colecao_firebase.dart.
//
// POR QUE SEPARAR
// O dominio (catalogo, campanha, resgate, inventario) nao pode depender do
// Firebase, senao cada teste precisaria de emulador e trocar de backend viraria
// reescrita. Com a interface no meio, os 100+ casos da suite rodam em memoria e
// o adaptador real e testado a parte, contra fakes e contra o emulador.

import 'colecao_campanha.dart';
import 'colecao_inventario.dart';
import 'colecao_resgate.dart';

/// Por que a chamada ao backend falhou.
///
/// Os codigos espelham os que a Cloud Function devolve (ver
/// firebase/functions/index.js). Sao os mesmos nomes usados em
/// [RecusaResgate]/[RecusaElegibilidade] sempre que o motivo coincide, para nao
/// existirem dois vocabularios para a mesma coisa.
enum FalhaBackend {
  /// Ninguem autenticado. O resgate exige login.
  naoAutenticado('unauthenticated'),

  /// O servidor recusou: nao elegivel, campanha inativa, fora da janela.
  recusado('permission-denied'),

  /// Campanha ou documento ausente.
  naoEncontrado('not-found'),

  /// Estado inconsistente que exige decisao administrativa — por exemplo,
  /// comprovante de outra versao da campanha.
  precondicaoFalhou('failed-precondition'),

  /// Rede, timeout ou indisponibilidade. E o unico caso em que repetir faz
  /// sentido, e e seguro repetir: o resgate e idempotente.
  indisponivel('unavailable'),

  /// Qualquer outra coisa.
  desconhecida('unknown');

  final String wire;
  const FalhaBackend(this.wire);

  /// Repetir tem chance de resolver.
  bool get vaiAdiantarRepetir =>
      this == indisponivel || this == desconhecida;
}

/// Erro tipado do adaptador. Carrega o codigo e a mensagem crua do servidor,
/// para o log; a tela usa apenas [falha].
class ErroColecao implements Exception {
  final FalhaBackend falha;
  final String detalhe;

  const ErroColecao(this.falha, this.detalhe);

  @override
  String toString() => 'ErroColecao(${falha.wire}): $detalhe';
}

/// O que a Cloud Function devolveu.
class RespostaResgate {
  final SituacaoResgate situacao;

  /// Itens que o jogador passa a ter. Vem do servidor, nao do cliente.
  final List<String> itemIds;

  /// Quantos documentos a transacao gravou. Zero em `jaResgatado`.
  final int gravados;

  const RespostaResgate({
    required this.situacao,
    required this.itemIds,
    required this.gravados,
  });

  /// Traduz o `status` do wire. Recusa valor desconhecido em vez de assumir
  /// sucesso: um status novo no servidor nao pode virar "resgatado" no cliente.
  factory RespostaResgate.doWire(Map<String, dynamic> dados) {
    final status = dados['status'];
    final situacao = switch (status) {
      'claimed' => SituacaoResgate.concedido,
      'reconciled' => SituacaoResgate.reconciliado,
      'alreadyClaimed' => SituacaoResgate.jaResgatado,
      _ => throw ErroColecao(
          FalhaBackend.desconhecida, 'status de resgate desconhecido: $status'),
    };
    final ids = (dados['itemIds'] as List?)?.cast<String>() ?? const <String>[];
    if (ids.isEmpty) {
      throw const ErroColecao(
          FalhaBackend.desconhecida, 'resposta de resgate sem itemIds');
    }
    return RespostaResgate(
      situacao: situacao,
      itemIds: List.unmodifiable(ids),
      gravados: (dados['gravados'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Acesso aos dados do modulo de colecoes.
abstract interface class ColecaoRepositorio {
  /// Configuracao da campanha.
  Future<CampanhaColecao> carregarCampanha(String campaignId);

  /// Estado da feature flag da campanha. Separada da campanha de proposito: a
  /// flag e infraestrutura e precisa desligar tudo sem editar o documento.
  Future<bool> featureFlagLigada(CampanhaColecao campanha);

  /// Evidencias que a fonte confiavel afirma sobre o jogador.
  ///
  /// O cliente le isto apenas para escolher qual tela mostrar. Quem concede e o
  /// servidor, que le as mesmas fontes por conta propria.
  Future<EvidenciaElegibilidade> carregarEvidencia({
    required String campaignId,
    required String uid,
  });

  Future<InventarioUsuario> carregarInventario({
    required String uid,
    String? collectionId,
  });

  /// Aciona o resgate na camada segura. Idempotente: repetir devolve
  /// `jaResgatado`, nunca duplica.
  Future<RespostaResgate> resgatar(String campaignId);

  /// Persiste a equipagem ja decidida pelo dominio.
  ///
  /// Recebe o resultado de [InventarioUsuario.equipar] em vez de decidir sozinho
  /// quem sai: a regra de exclusividade de slot mora no dominio, e duplica-la
  /// aqui abriria espaco para os dois discordarem.
  Future<void> aplicarEquipagem({
    required String uid,
    required String itemIdEquipado,
    required List<String> itemIdsDesequipados,
  });
}
