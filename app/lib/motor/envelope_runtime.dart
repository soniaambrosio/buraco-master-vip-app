// C9-B — ENVELOPE de runtime: carrega ao lado da projeção canônica TODOS os
// campos do `Jogo` legado que NÃO estão no `EstadoJogo` canônico, para que
// nenhum campo operacional desapareça silenciosamente (matriz do PLANO-C9 v2.1).
//
// Categorias carregadas aqui:
//  • RUNTIME ENVELOPE (operacionais): cont, lixoUnicoCompradoId,
//    mortosConvertidos, iniciadorRodada, rodadaContada, lixoTopoObrigatorio,
//    integridadeErro, assentoQueBateu, rodada, placar, encerrada, pontosRodada.
//  • UI/SIDECAR (pass-through, sem efeito de regra): apelidos, avatares, mascotes.
//
// NÃO contém regra. NÃO importa `mesa.dart` (é só um contêiner de dados tipado).
// `pontosRodada` usa `Map<String, Object?>?` (não `dynamic`) — é o detalhe da
// última rodada contada no legado, transportado como dado opaco/pass-through.
class EnvelopeRuntime {
  // ---- RUNTIME ENVELOPE: operacionais privados no legado (via seam) ----
  final int cont; // _cont: gerador de ids de carta (unicidade)
  final String? lixoUnicoCompradoId; // _lixoUnicoCompradoId: anti "turno nulo"
  final int mortosConvertidos; // _mortosConvertidos: §8.1 (NÃO afeta o −100)
  final int iniciadorRodada; // _iniciadorRodada: rotação de início
  final bool rodadaContada; // _rodadaContada: contagem já aplicada

  // ---- RUNTIME ENVELOPE: operacionais públicos no legado ----
  final String? lixoTopoObrigatorio; // obrigação de uso do topo do lixo
  final String? integridadeErro; // trava crítica de integridade do baralho
  final int? assentoQueBateu; // assento específico (canônico só tem a dupla)
  final int rodada; // contador de rodada
  final Map<String, int> placar; // placar ACUMULADO nos/eles (canônico é por-rodada)
  final bool encerrada; // partida acabou (canônico usa rodadaEncerrada)
  final Map<String, Object?>? pontosRodada; // detalhe da última rodada contada

  // ---- UI/SIDECAR (pass-through) ----
  final List<String> apelidos;
  final List<String> avatares;
  final List<String> mascotes;

  const EnvelopeRuntime({
    required this.cont,
    required this.lixoUnicoCompradoId,
    required this.mortosConvertidos,
    required this.iniciadorRodada,
    required this.rodadaContada,
    required this.lixoTopoObrigatorio,
    required this.integridadeErro,
    required this.assentoQueBateu,
    required this.rodada,
    required this.placar,
    required this.encerrada,
    required this.pontosRodada,
    required this.apelidos,
    required this.avatares,
    required this.mascotes,
  });

  /// Envelope neutro (defaults do `Jogo` recém-criado). Usado quando só há o
  /// `EstadoJogo` canônico disponível (ex.: adaptador legado sobre a porta, que
  /// só recebe estado canônico — os campos operacionais nuançados ficam para o
  /// C9-C, onde o runtime carrega o envelope completo).
  factory EnvelopeRuntime.vazio() => const EnvelopeRuntime(
        cont: 0,
        lixoUnicoCompradoId: null,
        mortosConvertidos: 0,
        iniciadorRodada: -1,
        rodadaContada: false,
        lixoTopoObrigatorio: null,
        integridadeErro: null,
        assentoQueBateu: null,
        rodada: 0,
        placar: {'nos': 0, 'eles': 0},
        encerrada: false,
        pontosRodada: null,
        apelidos: <String>[],
        avatares: <String>[],
        mascotes: <String>[],
      );
}
