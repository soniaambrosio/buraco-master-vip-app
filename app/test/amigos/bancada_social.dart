// bancada_social.dart — o transporte social falso, e os construtores de wire.
//
// PORTA ESTREITA, e não um mock genérico. Este arquivo implementa
// `TransporteSocial` e nada mais: ele não sabe desenhar, não sabe navegar e não
// decide relação nenhuma. O que ele oferece é o que os casos da OS precisam
// encenar e que uma Cloud Function de verdade não deixa encenar:
//
//   * resposta que DEMORA (um `Completer` por chamada, resolvido à mão);
//   * resposta que chega FORA DE ORDEM;
//   * recusa com o código de domínio exato (`consultaMuitoCurta`, `limiteDeAmigos`);
//   * `verPerfilPublico` devolvendo uma vista DIFERENTE da que a busca trouxe —
//     que é o caso central de "estado da amizade refletido de volta na UI".
//
// A CONTAGEM DE CHAMADAS É PARTE DO CONTRATO, e não diagnóstico. Metade das
// afirmações desta OS é sobre quantas idas ao servidor um gesto produz: abrir a
// tela dez vezes tem de emitir uma consulta, e não dez; três toques em "tentar
// de novo" têm de emitir uma, e não três.

import 'dart:async';

import 'package:buraco_master_vip/amigos/estado_social.dart';
import 'package:buraco_master_vip/amigos/transporte_social.dart';

/// Uma chamada registrada, com o que foi pedido.
class ChamadaSocial {
  ChamadaSocial(
    this.metodo, {
    this.termo,
    this.publicId,
    this.cursor,
    this.acao,
  });

  final String metodo;
  final String? termo;
  final String? publicId;
  final String? cursor;
  final AcaoSocial? acao;

  @override
  String toString() =>
      '$metodo(${[if (termo != null) 'termo=$termo', if (publicId != null) 'id=$publicId', if (cursor != null) 'cursor=$cursor', if (acao != null) 'acao=${acao!.name}'].join(', ')})';
}

/// Transporte social falso e roteirável.
///
/// Por padrão responde na hora com o que estiver nos campos `resposta*`. Ligando
/// [manual], cada chamada devolve um `Future` que só termina quando o teste
/// mandar — é assim que "resposta vencida" e "voo em curso" viram casos.
class TransporteSocialFalso implements TransporteSocial {
  TransporteSocialFalso({this.manual = false});

  /// As respostas ficam pendentes até o teste resolvê-las.
  bool manual;

  final List<ChamadaSocial> chamadas = <ChamadaSocial>[];

  /// Os voos pendentes, na ordem em que nasceram. O teste os resolve na ordem
  /// que quiser — que é como "fora de ordem" é encenado.
  final List<Completer<Object?>> pendentes = <Completer<Object?>>[];

  ResultadosDeBusca respostaDaBusca = const ResultadosDeBusca(
    termo: '',
    itens: [],
    truncado: false,
    modo: ModoDeBusca.prefixo,
  );

  /// O que `verPerfilPublico` devolve, por `publicId`. Ausente devolve
  /// [perfilPadrao].
  final Map<String, ResultadoSocial> perfis = <String, ResultadoSocial>{};

  ResultadoSocial perfilPadrao = ResultadoSocial(
    jogador: jogadorFalso('P000000000001'),
    relacao: RelacaoSocial.nenhuma,
    acoes: const [AcaoSocial.adicionarAmigo],
  );

  PaginaSocial respostaAmigos = PaginaSocial.vazia;
  PaginaSocial respostaRecebidas = PaginaSocial.vazia;
  PaginaSocial respostaEnviadas = PaginaSocial.vazia;

  DesfechoSocial respostaDaAcao = const DesfechoSocial(
    repeticao: false,
    estado: 'pendente',
  );

  /// Quando não nulo, a PRÓXIMA chamada falha com isto e o campo se limpa.
  ///
  /// Uma falha só, e não um modo permanente: quase todo caso desta OS é "falhou
  /// uma vez, e depois deu certo" — o retry precisa poder dar certo para o
  /// teste provar que ele funciona.
  FalhaSocial? proximaFalha;

  /// Falha PERMANENTE, para os casos em que insistir não pode resolver.
  FalhaSocial? falhaFixa;

  int get totalDeChamadas => chamadas.length;

  int chamadasDe(String metodo) =>
      chamadas.where((c) => c.metodo == metodo).length;

  /// Resolve o voo pendente de índice [i] com [valor].
  void responder(int i, Object? valor) => pendentes[i].complete(valor);

  /// Resolve o voo pendente de índice [i] com uma falha.
  void falhar(int i, FalhaSocial f) => pendentes[i].completeError(f);

  Future<T> _responder<T>(ChamadaSocial c, T valor) {
    chamadas.add(c);
    final fixa = falhaFixa;
    if (fixa != null) return Future<T>.error(fixa);
    final uma = proximaFalha;
    if (uma != null) {
      proximaFalha = null;
      return Future<T>.error(uma);
    }
    if (!manual) return Future<T>.value(valor);
    final completer = Completer<Object?>();
    pendentes.add(completer);
    // O valor roteirado é o padrão: `responder(i, null)` devolve o que estava
    // configurado, e `responder(i, outraCoisa)` sobrescreve só aquele voo.
    return completer.future.then((v) => (v as T?) ?? valor);
  }

  @override
  Future<ResultadosDeBusca> buscarPorApelido(
    String termo, {
    String? modo,
    int? limite,
  }) => _responder(
    ChamadaSocial('buscar', termo: termo),
    ResultadosDeBusca(
      termo: termo,
      itens: respostaDaBusca.itens,
      truncado: respostaDaBusca.truncado,
      modo: respostaDaBusca.modo,
    ),
  );

  @override
  Future<ResultadoSocial> verPerfilPublico(String publicId) => _responder(
    ChamadaSocial('verPerfil', publicId: publicId),
    perfis[publicId] ?? perfilPadrao,
  );

  @override
  Future<PaginaSocial> listarAmigos({String? cursor, int? limite}) =>
      _responder(ChamadaSocial('listarAmigos', cursor: cursor), respostaAmigos);

  @override
  Future<PaginaSocial> listarSolicitacoesRecebidas({
    String? cursor,
    int? limite,
  }) => _responder(
    ChamadaSocial('listarRecebidas', cursor: cursor),
    respostaRecebidas,
  );

  @override
  Future<PaginaSocial> listarSolicitacoesEnviadas({
    String? cursor,
    int? limite,
  }) => _responder(
    ChamadaSocial('listarEnviadas', cursor: cursor),
    respostaEnviadas,
  );

  @override
  Future<DesfechoSocial> agir(AcaoSocial acao, String publicId) => _responder(
    ChamadaSocial('agir', publicId: publicId, acao: acao),
    respostaDaAcao,
  );
}

/// Um jogador público de teste.
JogadorPublico jogadorFalso(
  String publicId, {
  String apelido = '',
  String? avatarRef,
  String? desde,
}) => JogadorPublico(
  publicId: publicId,
  apelido: apelido,
  avatarRef: avatarRef,
  desde: desde,
);

/// Um resultado de busca de teste, com a relação e as ações do SERVIDOR.
ResultadoSocial resultadoFalso(
  String publicId, {
  String apelido = '',
  RelacaoSocial relacao = RelacaoSocial.nenhuma,
  List<AcaoSocial> acoes = const [AcaoSocial.adicionarAmigo],
}) => ResultadoSocial(
  jogador: jogadorFalso(publicId, apelido: apelido),
  relacao: relacao,
  acoes: acoes,
);

/// Uma página de teste.
PaginaSocial paginaFalsa(List<JogadorPublico> itens, {String? proximoCursor}) =>
    PaginaSocial(itens: itens, proximoCursor: proximoCursor);
