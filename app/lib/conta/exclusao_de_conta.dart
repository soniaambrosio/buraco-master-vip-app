// exclusao_de_conta.dart — o vocabulário do cliente para "excluir minha conta".
//
// PURO: sem Firebase, sem Flutter. É o que permite que o controlador e a tela
// sejam testados sem emulador — mesma fronteira que `identidade_publica_sessao.
// dart` estabelece para o módulo de sessão.
//
// ---------------------------------------------------------------------------
// A DECISÃO QUE ORGANIZA ESTE ARQUIVO: O AVISO NÃO É TEXTO DO APLICATIVO
// ---------------------------------------------------------------------------
//
// A tela de exclusão precisa dizer o que vai acontecer. O caminho fácil seria
// escrever a lista no Dart — "seu perfil, suas amizades, suas fichas...". Ela
// ficaria certa por umas semanas.
//
// O que a envelhece é previsível: alguém acrescenta uma coleção ao backend,
// classifica na matriz de `functions-conta/src/inventario.ts`, e o texto do
// aplicativo continua prometendo o que prometia antes — agora errado, e errado
// justamente na tela em que a pessoa decide algo irreversível.
//
// Por isso [ResumoDaExclusao] vem do SERVIDOR, derivado da mesma matriz que o
// executor obedece. O aplicativo desenha; ele não decide o conteúdo, e não tem
// como divergir.
//
// O que o aplicativo AINDA escreve à mão são as duas advertências que não vêm
// da matriz porque não são sobre dados — ver [kAvisosQueNaoVemDaMatriz].

import 'package:flutter/foundation.dart';

/// As cinco classes da matriz de retenção. Espelha `CLASSE` de
/// `functions-conta/src/inventario.ts`.
///
/// O cliente precisa delas para AGRUPAR o aviso: "isto some", "isto fica sem
/// seu nome", "isto fica sem ligação com você", "isto fica". Três listas numa
/// tela só, sem rótulo, viram uma parede de caminhos de coleção.
enum ClasseDeRetencao {
  apagar('APAGAR'),
  anonimizar('ANONIMIZAR'),
  desvincular('DESVINCULAR'),
  reter('RETER'),
  naoAplicavel('NAO_APLICAVEL');

  final String wire;
  const ClasseDeRetencao(this.wire);

  static ClasseDeRetencao? porWire(String wire) {
    for (final c in ClasseDeRetencao.values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// Uma linha do aviso: o que é, de que domínio vem, e por quê.
@immutable
class LinhaDoAviso {
  /// O caminho no banco, como a matriz o escreve. Não é para o jogador comum —
  /// é para quem pede a explicação completa, e para o suporte conferir.
  final String caminho;

  /// `social`, `billing`, `moderacao`... Serve para agrupar por assunto.
  final String dominio;

  /// A justificativa que a matriz carrega. É ela que responde "por que vocês
  /// guardam minhas denúncias?" sem precisar de um humano do outro lado.
  final String porque;

  const LinhaDoAviso({
    required this.caminho,
    required this.dominio,
    required this.porque,
  });

  static LinhaDoAviso? doWire(Object? bruto) {
    if (bruto is! Map) return null;
    final caminho = bruto['caminho'];
    if (caminho is! String || caminho.isEmpty) return null;
    return LinhaDoAviso(
      caminho: caminho,
      dominio: bruto['dominio'] is String ? bruto['dominio'] as String : '',
      porque: bruto['porque'] is String ? bruto['porque'] as String : '',
    );
  }
}

/// Uma inscrição em torneio que impede a exclusão agora.
@immutable
class BloqueioDeTorneio {
  final String tournamentId;
  final String editionId;
  final String status;

  const BloqueioDeTorneio({
    required this.tournamentId,
    required this.editionId,
    required this.status,
  });

  static BloqueioDeTorneio? doWire(Object? bruto) {
    if (bruto is! Map) return null;
    return BloqueioDeTorneio(
      tournamentId: bruto['tournamentId'] is String ? bruto['tournamentId'] as String : '',
      editionId: bruto['editionId'] is String ? bruto['editionId'] as String : '',
      status: bruto['status'] is String ? bruto['status'] as String : '',
    );
  }
}

/// O que o servidor responde quando perguntam "o que acontece se eu sair?".
@immutable
class ResumoDaExclusao {
  final bool podeExcluir;

  /// Por que não pode, quando não pode. `null` quando pode.
  final String? recusa;

  /// As inscrições que travaram, nomeadas — "cancele suas inscrições" sem dizer
  /// quais manda a pessoa procurar.
  final List<BloqueioDeTorneio> bloqueios;

  /// A palavra que o jogador vai digitar. Vem do servidor porque é o servidor
  /// que a confere: se as duas divergissem, a tela recusaria o que o backend
  /// aceita, ou pior.
  final String palavraDeConfirmacao;

  final List<LinhaDoAviso> apagado;
  final List<LinhaDoAviso> anonimizado;
  final List<LinhaDoAviso> desvinculado;
  final List<LinhaDoAviso> retido;

  const ResumoDaExclusao({
    required this.podeExcluir,
    required this.recusa,
    required this.bloqueios,
    required this.palavraDeConfirmacao,
    required this.apagado,
    required this.anonimizado,
    required this.desvinculado,
    required this.retido,
  });

  static List<LinhaDoAviso> _linhas(Object? bruto) {
    if (bruto is! List) return const [];
    return bruto
        .map(LinhaDoAviso.doWire)
        .whereType<LinhaDoAviso>()
        .toList(growable: false);
  }

  /// Converte a resposta da callable.
  ///
  /// TOLERANTE POR DECISÃO: campo ausente vira lista vazia, e não exceção. O
  /// aviso é informativo; derrubar a tela porque uma das quatro listas não veio
  /// deixaria o jogador sem NENHUMA informação em vez de com quase toda.
  ///
  /// A única coisa que NÃO é tolerada é `podeExcluir` ausente — ela vira
  /// `false`, e o caminho seguro é não deixar excluir por engano.
  factory ResumoDaExclusao.doWire(Map<Object?, Object?> dados) {
    final palavra = dados['palavraDeConfirmacao'];
    return ResumoDaExclusao(
      podeExcluir: dados['podeExcluir'] == true,
      recusa: dados['recusa'] is String ? dados['recusa'] as String : null,
      bloqueios: dados['bloqueios'] is List
          ? (dados['bloqueios'] as List)
                .map(BloqueioDeTorneio.doWire)
                .whereType<BloqueioDeTorneio>()
                .toList(growable: false)
          : const [],
      // Sem palavra no wire, o campo fica VAZIO e a tela não consegue habilitar
      // o botão. É o comportamento certo: uma palavra inventada aqui seria
      // recusada pelo servidor de qualquer forma, e o jogador veria um erro sem
      // explicação depois de digitar.
      palavraDeConfirmacao: palavra is String ? palavra : '',
      apagado: _linhas(dados['apagado']),
      anonimizado: _linhas(dados['anonimizado']),
      desvinculado: _linhas(dados['desvinculado']),
      retido: _linhas(dados['retido']),
    );
  }
}

/// As advertências que NÃO vêm da matriz, e por que elas existem.
///
/// A matriz descreve DADOS. Estas duas descrevem CONSEQUÊNCIAS fora do banco, e
/// nenhuma classificação de coleção as produziria:
///
///   1. A ASSINATURA NA GOOGLE PLAY NÃO É CANCELADA. Excluir a conta apaga o
///      direito VIP daqui; não mexe na cobrança recorrente, que é um contrato
///      entre a pessoa e a Google. Sem este aviso, alguém sairia do aplicativo e
///      continuaria pagando — e descobriria na fatura seguinte.
///
///   2. NÃO HÁ DESFAZER, E NÃO HÁ VOLTAR COM A MESMA CONTA. Uma conta nova é
///      uma conta nova: outro UID, outro `publicId`, ranking do zero, fichas
///      zeradas, amizades perdidas.
const List<String> kAvisosQueNaoVemDaMatriz = [
  'A assinatura VIP na Google Play NÃO é cancelada por aqui. Se você tem uma '
      'assinatura ativa, cancele-a na Play Store antes de excluir a conta — '
      'senão a cobrança continua.',
  'Não há como desfazer. Se você criar uma conta nova depois, ela começa do '
      'zero: outro código de jogador, ranking zerado, fichas zeradas e sem as '
      'amizades.',
];

// ---------------------------------------------------------------------------
// FALHA
// ---------------------------------------------------------------------------

/// Por que a exclusão não aconteceu.
///
/// Enum, e não a string do servidor, pela mesma razão do módulo social: a tela
/// escreve a mensagem em português e não pode depender do TEXTO que veio do
/// backend. O código é contrato; o texto é para o log.
enum MotivoFalhaExclusao {
  /// Ninguém autenticado.
  naoAutenticado,

  /// A credencial não foi apresentada há pouco. É o único motivo que a tela
  /// resolve sozinha: pede a senha de novo e tenta outra vez.
  reautenticacaoNecessaria,

  /// A palavra digitada não confere.
  confirmacaoInvalida,

  /// Há inscrição ativa em torneio que não terminou.
  torneioEmAndamento,

  /// A exclusão começou e parou no meio. RETOMÁVEL: chamar de novo continua.
  parcial,

  /// Rede, cota, indisponibilidade. Vale tentar de novo.
  indisponivel,

  desconhecida,
}

@immutable
class FalhaExclusao implements Exception {
  final MotivoFalhaExclusao motivo;
  final String detalhe;

  /// Inscrições que travaram, quando o motivo é [torneioEmAndamento].
  final List<BloqueioDeTorneio> bloqueios;

  const FalhaExclusao(
    this.motivo,
    this.detalhe, {
    this.bloqueios = const [],
  });

  /// A pessoa pode tentar de novo sem mudar nada?
  ///
  /// `parcial` entra aqui, e é o caso menos óbvio: a exclusão FALHOU no meio, e
  /// mesmo assim a ação certa é repetir — o backend retoma de onde parou. Tratar
  /// como definitiva deixaria a conta meio apagada sem caminho de volta.
  bool get vaiAdiantarTentarDeNovo =>
      motivo == MotivoFalhaExclusao.indisponivel ||
      motivo == MotivoFalhaExclusao.parcial;

  @override
  String toString() => 'FalhaExclusao(${motivo.name}): $detalhe';
}

/// O desfecho de uma tentativa de exclusão.
@immutable
class ResultadoDaExclusao {
  final bool concluida;

  /// O backend já tinha concluído numa chamada anterior. Não é erro: é a
  /// resposta certa para o duplo toque e para o retry depois de a rede cair
  /// entre a execução e a resposta.
  final bool repeticao;

  const ResultadoDaExclusao({required this.concluida, required this.repeticao});

  factory ResultadoDaExclusao.doWire(Map<Object?, Object?> dados) =>
      ResultadoDaExclusao(
        concluida: dados['concluida'] == true,
        repeticao: dados['repeticao'] == true,
      );
}
