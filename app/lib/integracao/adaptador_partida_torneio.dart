// adaptador_partida_torneio.dart — A TRADUÇÃO, E SÓ ELA.
//
// Os dois motores nunca se falam diretamente. Este arquivo é o único que importa
// os dois, e é o único que pode: lib/motor não conhece torneio, lib/torneios não
// conhece baralho, e nenhum dos dois vai aprender.
//
// O fluxo inteiro, na ordem em que acontece:
//
//   SolicitacaoPartida        (o torneio pede)
//     → VinculoDeMesa         (quem é quem, declarado e congelado)
//     → RegistroDePartidas    (a mesa nasce, idempotente por matchId)
//     → ...a partida acontece, com as regras de sempre...
//     → DesfechoCanonicoPartida  (o Motor de Partidas diz como acabou)
//     → ResultadoPartida      (traduzido para o vocabulário esportivo)
//     → processarResultado    (o torneio valida e admite)
//     → classificação / fase / premiação
//
// O QUE ESTE ARQUIVO NÃO FAZ, E É O PONTO:
//   * não soma ponto — copia `LadoDaMesa.pontos`;
//   * não conta canastra — copia `LadoDaMesa.canastrasLimpas`;
//   * não decide vencedor — copia `DesfechoCanonicoPartida.ladoVencedor`;
//   * não decide abandono — só a autoridade declara, e o motor já filtrou isso;
//   * não classifica, não avança fase e não concede recompensa — quem faz isso é
//     o Motor de Torneios, depois, com o resultado nas mãos.
//
// Se um dia aparecer uma conta aqui, ela está no arquivo errado.

import 'dart:async';

import '../motor/desfecho_partida.dart';
import '../motor/motor_partida.dart';
import '../torneios/match_contract.dart';
import 'registro_partidas.dart';
import 'vinculo_mesa.dart';

/// A partida não tem como virar resultado ainda, ou não tem como virar resultado
/// nunca.
///
/// Falha alta e explícita, do jeito que a OS pede: é melhor a integração parar
/// aqui, com o motivo escrito, do que entregar à classificação um resultado
/// inventado que ninguém mais conseguiria desfazer.
class DesfechoNaoTraduzivel implements Exception {
  final String motivo;
  const DesfechoNaoTraduzivel(this.motivo);

  @override
  String toString() => 'DesfechoNaoTraduzivel: $motivo';
}

/// Tradução dos motivos do Motor de Partidas para os desfechos do torneio.
///
/// Tabela explícita e total: um motivo novo do lado do motor quebra a compilação
/// aqui em vez de cair num `default` que mandaria "normal" para o torneio.
DesfechoPartida desfechoDoTorneio(MotivoEncerramento motivo) {
  switch (motivo) {
    case MotivoEncerramento.metaAtingida:
      return DesfechoPartida.normal;
    case MotivoEncerramento.abandono:
      return DesfechoPartida.abandono;
    case MotivoEncerramento.encerradaPorAdmin:
      return DesfechoPartida.encerradaPorAdmin;
    case MotivoEncerramento.anulada:
      return DesfechoPartida.anulada;
  }
}

/// Converte um desfecho canônico no resultado que o torneio entende.
///
/// [vinculo] é obrigatório e é o que substitui qualquer palpite: o participante
/// de cada lado sai da declaração feita na abertura da mesa, nunca da ordem das
/// listas nem do placar.
///
/// Falha alto quando:
///   * o desfecho ainda não é conclusivo (partida em andamento);
///   * o vínculo é de outra partida;
///   * o lado vencedor do motor não tem participante vinculado.
ResultadoPartida traduzirDesfecho({
  required DesfechoCanonicoPartida desfecho,
  required VinculoDeMesa vinculo,
}) {
  if (desfecho.partidaId != vinculo.matchId) {
    throw DesfechoNaoTraduzivel(
        'o desfecho é da partida ${desfecho.partidaId} e o vínculo é da ${vinculo.matchId}.');
  }
  if (!desfecho.conclusivo) {
    throw DesfechoNaoTraduzivel(
        'a partida ${desfecho.partidaId} ainda está ${desfecho.estado.wire}; '
        'estado intermediário não vira resultado de torneio.');
  }
  final motivo = desfecho.motivo;
  if (motivo == null) {
    throw DesfechoNaoTraduzivel(
        'a partida ${desfecho.partidaId} está encerrada sem motivo canônico.');
  }

  final lados = <LadoResultado>[];
  for (final ladoMesa in desfecho.lados) {
    final vinculado = vinculo.porLado(ladoMesa.lado);
    if (vinculado == null) {
      throw DesfechoNaoTraduzivel(
          'o lado "${ladoMesa.lado}" da partida ${desfecho.partidaId} não tem participante '
          'vinculado — o vínculo declarado cobre ${vinculo.lados.map((l) => l.lado).toList()}.');
    }
    lados.add(LadoResultado(
      participanteId: vinculado.participanteId,
      // Copiados, não recalculados. Ver o cabeçalho deste arquivo.
      pontos: ladoMesa.pontos,
      canastrasLimpas: ladoMesa.canastrasLimpas,
    ));
  }

  String? vencedorId;
  if (motivo != MotivoEncerramento.anulada) {
    final ladoVencedor = desfecho.ladoVencedor;
    if (ladoVencedor == null) {
      throw DesfechoNaoTraduzivel(
          'a partida ${desfecho.partidaId} encerrou em ${motivo.wire} sem lado vencedor.');
    }
    final vinculado = vinculo.porLado(ladoVencedor);
    if (vinculado == null) {
      throw DesfechoNaoTraduzivel(
          'o lado vencedor "$ladoVencedor" não tem participante vinculado na partida '
          '${desfecho.partidaId}.');
    }
    vencedorId = vinculado.participanteId;
  }

  return ResultadoPartida(
    matchId: vinculo.matchId,
    tournamentId: vinculo.tournamentId,
    editionId: vinculo.editionId,
    faseId: vinculo.faseId,
    mesaId: vinculo.mesaId,
    lados: lados,
    vencedorId: vencedorId,
    desfecho: desfechoDoTorneio(motivo),
    encerradaEm: desfecho.encerradaEm,
  );
}

/// O Motor de Partidas visto pelo torneio.
///
/// Implementa [MotorDePartidas] — a interface declarada em match_contract.dart,
/// no domínio de torneios. A seta aponta em um sentido só: o adaptador conhece o
/// contrato, o contrato não conhece o adaptador.
class AdaptadorMotorDePartidas implements MotorDePartidas {
  final RegistroDePartidas registro;

  /// Como o vínculo de cada mesa é montado. O padrão cobre a mesa de dois lados
  /// que `formarMesas` produz hoje; trocar esta função é como um formato novo de
  /// mesa entra sem que nada mais mude.
  final VinculoDeMesa Function(SolicitacaoPartida) montarVinculo;

  /// Apelidos por assento para a mesa exibir. Recebe o vínculo porque só ele
  /// sabe quem senta onde. Devolver `null` deixa a mesa com rótulos neutros.
  final List<String>? Function(VinculoDeMesa)? apelidosDaMesa;

  AdaptadorMotorDePartidas({
    required this.registro,
    VinculoDeMesa Function(SolicitacaoPartida)? montarVinculo,
    this.apelidosDaMesa,
  }) : montarVinculo = montarVinculo ?? montarVinculoPadrao;

  @override
  Future<void> solicitarPartida(SolicitacaoPartida solicitacao) async {
    final jaAberta = await registro.buscar(solicitacao.matchId);
    if (jaAberta != null) {
      // Reenvio: a mesa já existe. Não recriar é o contrato
      // (`MotorDePartidas.solicitarPartida` exige idempotência por matchId).
      return;
    }
    final vinculo = montarVinculo(solicitacao);
    await registro.abrir(AberturaDePartida(
      partidaId: solicitacao.matchId,
      modalidade: solicitacao.modalidade,
      metaPontos: solicitacao.metaPontos,
      vinculo: vinculo,
      apelidos: apelidosDaMesa?.call(vinculo),
    ));
  }

  @override
  Future<void> cancelarPartida(String matchId) async {
    await registro.cancelar(matchId);
  }

  /// Fecha a partida e produz o resultado para o torneio.
  ///
  /// [ordem] é a única forma de encerrar por abandono, decisão administrativa ou
  /// anulação — e ela vem de fora, de quem tem autoridade. Sem ordem, a partida
  /// só encerra se a própria mesa tiver encerrado.
  ///
  /// Devolve `null` quando a partida ainda está em andamento: é resposta
  /// legítima de quem perguntou cedo demais, e o chamador não deve tratar como
  /// erro. Falha alto, isso sim, quando a partida não existe ou o vínculo sumiu.
  Future<ResultadoPartida?> encerrarEProduzirResultado({
    required String matchId,
    required DateTime encerradaEm,
    OrdemDeEncerramento? ordem,
  }) async {
    final motor = await registro.buscar(matchId);
    if (motor == null) {
      throw DesfechoNaoTraduzivel(
          'partida $matchId não está aberta neste registro.');
    }
    final vinculo = await registro.vinculoDe(matchId);
    if (vinculo == null) {
      throw DesfechoNaoTraduzivel(
          'partida $matchId existe mas não tem vínculo declarado — sem ele não há '
          'como dizer de quem é o resultado.');
    }
    final desfecho =
        capturarDesfecho(motor, encerradaEm: encerradaEm, ordem: ordem);
    if (!desfecho.conclusivo) return null;
    return traduzirDesfecho(desfecho: desfecho, vinculo: vinculo);
  }
}

/// Onde o torneio guarda o que já processou.
///
/// A idempotência do lado esportivo é por
/// [ResultadoPartida.chaveIdempotencia] (`tournamentId|editionId|matchId`), e é
/// uma camada DIFERENTE do `eventoId` do Motor de Partidas: aquele protege a
/// jogada, este protege o efeito esportivo. As duas precisam existir — reenviar
/// um resultado não pode somar pontos de novo nem conceder a mesma coroa duas
/// vezes, mesmo que nenhuma jogada tenha sido repetida.
abstract interface class HistoricoDeResultados {
  /// Chaves já processadas.
  FutureOr<Set<String>> processados();

  /// Registra a chave como processada. Deve ser atômico em relação a
  /// [processados] na implementação real — no servidor isso é uma transação.
  ///
  /// Devolve `true` se ESTA chamada foi a que gravou, e `false` se a chave já
  /// estava lá. É esse booleano que fecha a corrida entre dois processamentos
  /// simultâneos do mesmo resultado.
  FutureOr<bool> registrar(String chave);
}

/// Histórico em memória. Serve ao app e aos testes.
class HistoricoEmMemoria implements HistoricoDeResultados {
  final Set<String> _chaves = <String>{};

  HistoricoEmMemoria([Iterable<String> iniciais = const []]) {
    _chaves.addAll(iniciais);
  }

  @override
  Set<String> processados() => Set.unmodifiable(_chaves);

  @override
  bool registrar(String chave) => _chaves.add(chave);
}

/// Entrega um resultado ao Motor de Torneios.
///
/// É uma casca fina sobre [processarResultado]: toda a validação esportiva
/// continua sendo dele, e nada é recontado aqui. O que esta função acrescenta é
/// a gravação da chave de idempotência no mesmo passo da aceitação — sem isso, o
/// segundo envio de um resultado aceito seria aceito de novo.
///
/// [solicitacao] é a que o torneio emitiu para esta mesa. `null` quando o
/// torneio não reconhece o `matchId`, e o próprio [processarResultado] recusa
/// como `partidaDesconhecida`.
///
/// A ORDEM AQUI IMPORTA: consulta, processa, e só grava se aceitou. Gravar antes
/// de processar marcaria como processado um resultado que a validação recusou, e
/// a mesa nunca mais conseguiria enviar o resultado certo.
Future<ResultadoProcessamento> entregarResultado({
  required ResultadoPartida resultado,
  required SolicitacaoPartida? solicitacao,
  required bool edicaoEmDisputa,
  required HistoricoDeResultados historico,
}) async {
  final vistos = await historico.processados();
  final veredito = processarResultado(
    resultado: resultado,
    solicitacao: solicitacao,
    edicaoEmDisputa: edicaoEmDisputa,
    processados: vistos,
  );
  if (!veredito.processado) return veredito;

  final gravou = await historico.registrar(resultado.chaveIdempotencia);
  if (!gravou) {
    // Perdemos a corrida: outro processamento gravou a mesma chave entre a
    // consulta e a gravação. O efeito já aconteceu uma vez, então esta chamada
    // vira a recusa benigna de sempre — que é exatamente o que
    // `ResultadoProcessamento.idempotente` existe para o transporte reconhecer.
    return const ResultadoProcessamento.recusado(RecusaResultado.jaProcessado);
  }
  return veredito;
}

/// Atalho de leitura: o assento de um jogador na partida, ou `null`.
///
/// Existe para a camada de aplicação não precisar reimplementar a busca — e para
/// deixar registrado que a resposta vem do vínculo, nunca de índice de lista.
int? assentoDoJogador(VinculoDeMesa vinculo, String userId) {
  for (final lado in vinculo.lados) {
    final assento = lado.assentoDe(userId);
    if (assento != null) return assento;
  }
  return null;
}

/// Re-exporta o tipo do motor para quem consome só a integração.
typedef PartidaEmCurso = MotorPartida;
