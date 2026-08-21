// transporte_social_firebase.dart — o adaptador real das callables sociais.
//
// É o ÚNICO arquivo deste módulo que importa `cloud_functions`. Todo o resto
// (estado, leitor, escopo, telas) fica puro e testável sem emulador — a mesma
// fronteira que `sessao/fonte_identidade_firebase.dart` estabelece para a
// identidade e que `colecoes/colecao_firebase.dart` estabelece para o catálogo.
//
// A REGIÃO PRECISA CASAR com a declarada em `functions-social/src/index.ts`
// (`opcoesCliente.region`). Chamar a região errada devolve `not-found`, e
// `not-found` é justamente o código que o contrato social usa para "esse
// jogador não existe ou não pode ser exposto" — confundir os dois faria o
// aplicativo dizer que a pessoa não existe toda vez que o deploy fosse para
// outra região. Por isso a constante é IMPORTADA de `fonte_identidade_firebase`
// e não recopiada: é o mesmo codebase, e duas cópias divergem.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../sessao/fonte_identidade_firebase.dart' show kRegiaoFuncoesSociais;
import 'estado_social.dart';
import 'transporte_social.dart';

/// Os nomes das callables, tal como `functions-social/src/index.ts` os exporta.
///
/// CONSTANTES NOMEADAS, e não literais espalhados pelos métodos: é o que
/// permite a um teste conferir o contrato do fio sem instanciar Firebase, e o
/// que faz um rename no backend aparecer como uma linha só a mudar aqui.
const String kCallableBuscarPorApelido = 'buscarJogadoresPorApelido';
const String kCallableVerPerfilPublico = 'verPerfilPublico';
const String kCallableListarAmigos = 'listarAmigos';
const String kCallableListarAmigosOnline = 'listarAmigosOnline';
const String kCallableAtualizarPresenca = 'atualizarPresencaSocial';
const String kCallableAparecerOffline = 'definirAparecerOffline';
const String kCallableEnviarConviteMesa = 'enviarConviteMesa';
const String kCallableListarConvitesMesa = 'listarConvitesMesa';
const String kCallableResponderConviteMesa = 'responderConviteMesa';
const String kCallableListarRecebidas = 'listarSolicitacoesRecebidas';
const String kCallableListarEnviadas = 'listarSolicitacoesEnviadas';
const String kCallableRegistrarIndicacao = 'registrarIndicacao';

/// A callable de cada ação de amizade.
///
/// MAPA, e não `switch`: um `switch` sobre enum obriga a tratar todos os casos,
/// inclusive `bloquear` e `editarPerfil`, e o tratamento honesto deles seria
/// `throw` — que é o que [TransporteSocialFirebase.agir] já faz, uma vez, para
/// tudo o que não está aqui. Com o mapa, "não sei executar" é a ausência da
/// chave, e acrescentar uma ação é acrescentar uma linha.
const Map<AcaoSocial, String> kCallablesDeAcao = {
  AcaoSocial.adicionarAmigo: 'enviarSolicitacaoAmizade',
  AcaoSocial.aceitarSolicitacao: 'aceitarSolicitacaoAmizade',
  AcaoSocial.recusarSolicitacao: 'recusarSolicitacaoAmizade',
  AcaoSocial.cancelarSolicitacao: 'cancelarSolicitacaoAmizade',
  AcaoSocial.removerAmigo: 'removerAmizade',
};

class TransporteSocialFirebase implements TransporteSocial {
  TransporteSocialFirebase({FirebaseFunctions? functions})
    : _injetado = functions;

  FirebaseFunctions? _injetado;

  /// Resolvido na primeira chamada, e não no construtor — `instanceFor` exige
  /// `Firebase.initializeApp()` já executado, e a árvore é montada antes.
  FirebaseFunctions get _functions => _injetado ??=
      FirebaseFunctions.instanceFor(region: kRegiaoFuncoesSociais);

  @override
  Future<ResultadosDeBusca> buscarPorApelido(
    String termo, {
    String? modo,
    int? limite,
  }) async {
    // O termo vai CRU. Ver o contrato em `transporte_social.dart`: normalizar
    // aqui seria uma segunda `chaveDeBusca`, e a busca deixaria de encontrar o
    // que a gravação indexou no dia em que as duas divergissem.
    final bruto = await _chamar(kCallableBuscarPorApelido, {
      'termo': termo,
      ?'modo': modo,
      ?'limite': limite,
    });
    return ResultadosDeBusca.doWire(termo, bruto);
  }

  @override
  Future<ResultadoSocial> verPerfilPublico(String publicId) async {
    final bruto = await _chamar(kCallableVerPerfilPublico, {
      'publicId': publicId,
    });
    return ResultadoSocial.doPerfilPublico(bruto);
  }

  @override
  Future<PaginaSocial> listarAmigos({String? cursor, int? limite}) =>
      _pagina(kCallableListarAmigos, cursor, limite);

  @override
  Future<PaginaSocial> listarAmigosOnline() =>
      _pagina(kCallableListarAmigosOnline, null, null);

  @override
  Future<bool> atualizarPresenca() async {
    final r = await _chamar(kCallableAtualizarPresenca, const {});
    return r['aparecerOffline'] == true;
  }

  @override
  Future<void> definirAparecerOffline(bool valor) async {
    await _chamar(kCallableAparecerOffline, {'aparecerOffline': valor});
  }

  @override
  Future<void> enviarConviteMesa({
    required String publicId,
    required String codigo,
    required String tipoMesa,
  }) async {
    await _chamar(kCallableEnviarConviteMesa, {
      'publicId': publicId,
      'codigo': codigo,
      'tipoMesa': tipoMesa,
    });
  }

  @override
  Future<List<ConviteMesa>> listarConvitesMesa() async {
    final bruto = await _chamar(kCallableListarConvitesMesa, const {});
    final itens = bruto['itens'];
    if (itens is! List) return const [];
    return List.unmodifiable([
      for (final item in itens)
        if (item is Map) ConviteMesa.doWire(item.cast<Object?, Object?>()),
    ]);
  }

  @override
  Future<RespostaConviteMesa> responderConviteMesa(
    String conviteId, {
    required bool aceitar,
  }) async {
    final bruto = await _chamar(kCallableResponderConviteMesa, {
      'conviteId': conviteId,
      'aceitar': aceitar,
    });
    return RespostaConviteMesa.doWire(bruto);
  }

  @override
  Future<PaginaSocial> listarSolicitacoesRecebidas({
    String? cursor,
    int? limite,
  }) => _pagina(kCallableListarRecebidas, cursor, limite);

  @override
  Future<PaginaSocial> listarSolicitacoesEnviadas({
    String? cursor,
    int? limite,
  }) => _pagina(kCallableListarEnviadas, cursor, limite);

  @override
  Future<DesfechoSocial> agir(AcaoSocial acao, String publicId) async {
    final nome = kCallablesDeAcao[acao];
    if (nome == null) {
      // ERRO DE PROGRAMAÇÃO, e não falha de rede — por isso `ArgumentError` e
      // não `FalhaSocial`. Uma tela que peça `bloquear` a este transporte está
      // pedindo ao codebase errado: bloqueio é moderação, e o social só REAGE
      // a ele por gatilho.
      throw ArgumentError.value(
        acao,
        'acao',
        'não é uma ação de amizade — ver kAcoesDeAmizade',
      );
    }
    final bruto = await _chamar(nome, {'publicId': publicId});
    return DesfechoSocial.doWire(bruto);
  }

  @override
  Future<void> registrarIndicacao(String codigo) async {
    await _chamar(kCallableRegistrarIndicacao, {'codigo': codigo});
  }

  Future<PaginaSocial> _pagina(String nome, String? cursor, int? limite) async {
    final bruto = await _chamar(nome, {
      // O cursor viaja OPACO, exatamente como veio. Nem inspecionado, nem
      // recodificado: do lado do servidor ele é base64url de um par de campos,
      // e reconstruí-lo aqui amarraria o cliente à ordenação de hoje.
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      ?'limite': limite,
    });
    return PaginaSocial.doWire(bruto);
  }

  /// O ponto ÚNICO em que uma callable social é chamada e traduzida.
  ///
  /// Único de propósito: a tradução de erro é política (o que é transitório, o
  /// que vale um "tentar de novo", o que nunca deve ser repetido com o mesmo
  /// texto), e sete cópias dela divergiriam na primeira pressa.
  Future<Map<Object?, Object?>> _chamar(
    String nome,
    Map<String, Object?> dados,
  ) async {
    try {
      final chamada = _functions.httpsCallable(nome);
      final resposta = await chamada.call<Object?>(dados);
      final corpo = resposta.data;
      if (corpo is! Map) {
        throw const FalhaSocial(
          MotivoFalhaSocial.respostaInvalida,
          'resposta não é um objeto',
        );
      }
      return corpo.cast<Object?, Object?>();
    } on FalhaSocial {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw FalhaSocial(_traduzir(e.code), _recusaDe(e.details) ?? e.code);
    } on FirebaseException catch (e) {
      throw FalhaSocial(_traduzir(e.code), e.code);
    }
  }

  /// O código de recusa do domínio, quando o servidor o mandou em `details`.
  ///
  /// `recusar()` em `functions-social/src/index.ts` sempre embrulha o motivo em
  /// `{ recusa }`. Lê-lo dá à tela o vocabulário exato — `consultaMuitoCurta`,
  /// `limiteDeAmigos`, `autoAmizadeInvalida` — em vez de só a categoria HTTP.
  static String? _recusaDe(Object? detalhes) {
    if (detalhes is Map) {
      final r = detalhes['recusa'];
      if (r is String && r.isNotEmpty) return r;
    }
    return null;
  }

  /// Traduz o código do Firebase para o motivo de domínio.
  ///
  /// `internal` entra em [MotivoFalhaSocial.indisponivel] pelo mesmo motivo que
  /// na identidade: é o código de exceção não tratada na Function, quase sempre
  /// transitório (cold start, contenção), e negar o retry deixaria o jogador
  /// preso por um soluço do servidor.
  ///
  /// `failed-precondition` é REGRA DE NEGÓCIO e não é transitório: o servidor
  /// recusou por lotação, autoamizade ou bloqueio, e repetir dá o mesmo. A tela
  /// mostra o motivo; não oferece "tentar de novo".
  static MotivoFalhaSocial _traduzir(String codigo) => switch (codigo) {
    'unauthenticated' => MotivoFalhaSocial.naoAutenticado,
    'permission-denied' => MotivoFalhaSocial.recusado,
    'not-found' => MotivoFalhaSocial.naoEncontrado,
    'invalid-argument' => MotivoFalhaSocial.pedidoInvalido,
    'failed-precondition' => MotivoFalhaSocial.regraDeNegocio,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' ||
    'resource-exhausted' ||
    'internal' => MotivoFalhaSocial.indisponivel,
    _ => MotivoFalhaSocial.desconhecida,
  };
}
