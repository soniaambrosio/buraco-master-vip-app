// ponte_integracao.dart — LIGA A RASTREABILIDADE AO QUE JÁ EXISTE, SEM MEXER NELE.
//
// Esta camada não pode pedir mudança ao Motor de Partidas (§1 da OS: "não
// alterar comportamento do Motor, salvo interface mínima indispensável e
// previamente existente"). Então a direção da seta é esta, e só esta:
//
//   rastreabilidade  →  lê  →  motor/ e integracao/
//   motor/ e integracao/  →  não sabem que esta camada existe
//
// Nenhum arquivo de `lib/motor/` ou `lib/integracao/` foi tocado por esta OS.
// Tudo que este arquivo faz é LER os tipos que eles já produzem — `VinculoDeMesa`,
// `MotorPartida`, `AberturaDePartida`, `DesfechoCanonicoPartida` — e traduzi-los
// para o registro auditável.
//
// É a mesma disciplina de `adaptador_partida_torneio.dart`: um arquivo que
// importa os dois lados para que nenhum dos dois precise importar o outro.

import '../integracao/registro_partidas.dart';
import '../integracao/vinculo_mesa.dart';
import '../motor/motor_partida.dart';
import 'identidade_partida.dart';
import 'registro_partida.dart';

/// Monta o registro auditável de uma partida de TORNEIO a partir do vínculo que
/// a integração já declarou.
///
/// O `matchId` é ADOTADO, não cunhado: é o mesmo texto que `VinculoDeMesa`,
/// `MotorPartida.partidaId` e `ResultadoPartida` carregam (§3, "se já existir
/// identificador equivalente, reutilizar").
///
/// A composição da mesa sai INTEIRA do vínculo. Nada é deduzido por ordem de
/// lista — o vínculo existe justamente para impedir isso, e repetir a dedução
/// aqui recriaria o bug que ele previne.
///
/// [assentosDeRobo] declara quais assentos a mesa preencheu com robô. Vem de
/// fora porque quem sabe disso é quem abriu a mesa: em torneio individual, os
/// assentos parceiros (2 e 3) ficam sem dono no vínculo, e "sem dono no torneio"
/// pode significar robô ou pode significar assento vazio. Adivinhar aqui seria
/// inventar participante.
RegistroDePartida registroDeTorneio({
  required VinculoDeMesa vinculo,
  required String modalidade,
  required int metaPontos,
  required DateTime criadaEm,
  Map<int, String> assentosDeRobo = const {},
  List<String> espectadores = const [],
}) {
  final identidade = IdentidadePartida.deTorneio(
    matchId: vinculo.matchId,
    modalidade: modalidade,
    criadaEm: criadaEm,
  );

  final participantes = <ParticipantePartida>[];
  for (final lado in vinculo.lados) {
    for (final jogador in lado.jogadores) {
      participantes.add(ParticipantePartida(
        classe: ClasseDeParticipante.humano,
        userId: jogador.userId,
        assento: jogador.assento,
        participanteId: lado.participanteId,
      ));
    }
  }

  final atribuidos = vinculo.assentosAtribuidos.toSet();
  for (final entrada in assentosDeRobo.entries) {
    if (atribuidos.contains(entrada.key)) {
      // Um assento que o torneio deu a uma pessoa não pode ser declarado robô:
      // é exatamente a troca "humano vira bot" que §7 proíbe.
      throw ArgumentError.value(
          entrada.key,
          'assentosDeRobo',
          'o assento ${entrada.key} pertence ao participante '
              '${vinculo.participanteNoAssento(entrada.key)} e não pode ser robô');
    }
    participantes.add(ParticipantePartida(
      classe: ClasseDeParticipante.robo,
      botId: entrada.value,
      assento: entrada.key,
    ));
  }

  for (final uid in espectadores) {
    participantes.add(ParticipantePartida(
      classe: ClasseDeParticipante.espectador,
      userId: uid,
    ));
  }

  return RegistroDePartida.abrir(
    identidade: identidade,
    participantes: participantes,
    metaPontos: metaPontos,
    tournamentId: vinculo.tournamentId,
    editionId: vinculo.editionId,
    faseId: vinculo.faseId,
    mesaId: vinculo.mesaId,
  );
}

/// Monta o registro de uma partida que NÃO é de torneio.
///
/// É o caminho que não existia antes desta OS: casual, ranqueada, privada,
/// treino e contra robôs não tinham identificador nenhum. O `matchId` precisa
/// vir cunhado pela autoridade — ver [IdentidadePartida.cunhada] e, para o que
/// acontece quando o cliente tenta escolher, [IdentidadePartida.doCliente].
///
/// [assentos] mapeia assento → participante. Explícito, sem default e sem
/// preenchimento automático: quem conhece a mesa é quem monta a mesa, mesma
/// regra de `VinculoDeMesa.declarar`.
RegistroDePartida registroAvulso({
  required IdentidadePartida identidade,
  required Map<int, ParticipantePartida> assentos,
  required int metaPontos,
  List<String> espectadores = const [],
}) {
  if (identidade.tipo == TipoDePartida.torneio) {
    throw ArgumentError.value(identidade.tipo.wire, 'tipo',
        'partida de torneio se monta por registroDeTorneio, a partir do vínculo');
  }
  final participantes = <ParticipantePartida>[];
  for (final entrada in assentos.entries) {
    final p = entrada.value;
    if (p.assento != entrada.key) {
      throw ArgumentError.value(
          entrada.key,
          'assentos',
          'a chave do mapa diz assento ${entrada.key} e o participante '
              '${p.chave} diz ${p.assento}');
    }
    participantes.add(p);
  }
  for (final uid in espectadores) {
    participantes.add(ParticipantePartida(
      classe: ClasseDeParticipante.espectador,
      userId: uid,
    ));
  }
  return RegistroDePartida.abrir(
    identidade: identidade,
    participantes: participantes,
    metaPontos: metaPontos,
  );
}

/// O `matchId` que uma abertura de partida já carrega.
///
/// Existe para deixar explícito, num símbolo, que a rastreabilidade NÃO gera id
/// próprio quando a integração já tem um. Quem for ligar as duas camadas
/// encontra esta função em vez de escrever `'rastro-' + algo`.
String matchIdDaAbertura(AberturaDePartida abertura) => abertura.partidaId;

/// O `matchId` de uma partida viva, lido do motor.
///
/// Mesma função da anterior, para o outro tipo de entrada. `MotorPartida`
/// chama o campo de `partidaId`; é o MESMO namespace do `matchId` — ver o
/// cabeçalho de `identidade_partida.dart`.
String matchIdDoMotor(MotorPartida motor) => motor.partidaId;

/// A identidade da rodada corrente de uma partida viva (§4).
///
/// Derivada de `Jogo.rodada` e `MotorPartida.versaoEstado`, que já existiam.
/// Nenhum campo novo foi pedido ao motor.
IdentidadeRodada rodadaCorrente(
  MotorPartida motor,
  IdentidadePartida identidade,
) {
  if (motor.partidaId != identidade.matchId) {
    throw ArgumentError.value(motor.partidaId, 'motor',
        'o motor é da partida ${motor.partidaId} e a identidade é da '
        '${identidade.matchId}');
  }
  return identidade.rodada(
    // `Jogo.rodada` começa em 1 e o construtor de IdentidadeRodada exige isso;
    // uma mesa recém-criada que ainda reportasse 0 viraria erro aqui, então o
    // piso é aplicado na leitura, onde a informação está.
    motor.jogo.rodada < 1 ? 1 : motor.jogo.rodada,
    versaoEstado: motor.versaoEstado,
  );
}
