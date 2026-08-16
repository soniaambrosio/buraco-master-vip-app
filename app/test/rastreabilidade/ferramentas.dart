// ferramentas.dart — fixtures compartilhadas dos testes de rastreabilidade.
//
// Não é arquivo de teste: não tem `main()` e não é coletado pelo runner. Existe
// para que os sete arquivos de caso montem a MESMA mesa, e para que uma
// mudança de contrato quebre em um lugar só.
//
// As fixtures usam as portas públicas dos motores, nunca campos privados: o
// `Jogo` é encerrado mexendo em `placar`/`encerrada`, que são públicos e que
// `teste_encerramento.dart` já usa pelo mesmo motivo — simular partidas
// inteiras para testar rastreabilidade seria testar o Motor de novo.

import 'package:buraco_master_vip/integracao/vinculo_mesa.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/identidade_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/ledger_competitivo.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:buraco_master_vip/torneios/match_contract.dart';
import 'package:buraco_master_vip/torneios/participants.dart';

/// Instante fixo. Teste não espera relógio.
final DateTime agora = DateTime.utc(2026, 8, 11, 15, 0, 0);
final DateTime depois = DateTime.utc(2026, 8, 11, 16, 0, 0);

const String kMatchId = 'match-f1-mesa-1';
const String kOutroMatchId = 'match-f1-mesa-2';

/// O chamador com autoridade — o servidor de partidas.
const ChamadorAutorizado servidor = ChamadorAutorizado(
  autenticado: true,
  papel: 'motorDePartidas',
  id: 'srv-1',
);

/// Um jogador comum autenticado. Não tem autoridade nenhuma.
const ChamadorAutorizado jogadorComum = ChamadorAutorizado(
  autenticado: true,
  papel: 'jogador',
  id: 'uid-alice',
);

const ChamadorAutorizado anonimo = ChamadorAutorizado(
  autenticado: false,
  papel: 'jogador',
  id: '',
);

/// Política de ranking de TESTE. Não é a do jogo — a do jogo não existe (ver
/// `PoliticaDeRanking.pendente`). Serve para exercitar a mecânica do ledger.
const PoliticaDeRanking politicaDeTeste =
    PoliticaDeRanking(id: 'teste', versao: 1);

/// Delta fixo, para o teste poder afirmar o número exato.
CalculoDeDelta deltaFixo(int valor) => ({
      required registro,
      required userId,
      required saldoAtual,
    }) =>
        valor;

/// Delta que depende do lado: vencedor ganha, perdedor perde.
CalculoDeDelta deltaPorResultado({int ganho = 25, int perda = -15}) => ({
      required registro,
      required userId,
      required saldoAtual,
    }) =>
        registro.ladoDe(userId) == registro.ladoVencedor ? ganho : perda;

// --------------------------------------------------------------- identidade

IdentidadePartida identidadeRanqueada({
  String matchId = kMatchId,
  String modalidade = 'ABERTO',
}) =>
    IdentidadePartida.cunhada(
      matchId: matchId,
      tipo: TipoDePartida.publicaRanqueada,
      origem: OrigemDaIdentidade.servidor,
      modalidade: modalidade,
      criadaEm: agora,
    );

IdentidadePartida identidadeCasual({String matchId = kMatchId}) =>
    IdentidadePartida.cunhada(
      matchId: matchId,
      tipo: TipoDePartida.publicaCasual,
      origem: OrigemDaIdentidade.servidor,
      modalidade: 'ABERTO',
      criadaEm: agora,
    );

// ------------------------------------------------------------- participantes

/// Quatro humanos, um por assento. `uid-a` e `uid-c` são `nos`; `uid-b` e
/// `uid-d` são `eles`, pela lei de assentos de `Jogo`.
Map<int, ParticipantePartida> quatroHumanos() => {
      for (var i = 0; i < 4; i++)
        i: ParticipantePartida(
          classe: ClasseDeParticipante.humano,
          userId: 'uid-${String.fromCharCode(97 + i)}',
          assento: i,
        ),
    };

/// Dois humanos e dois robôs.
Map<int, ParticipantePartida> doisHumanosDoisRobos() => {
      0: ParticipantePartida(
          classe: ClasseDeParticipante.humano, userId: 'uid-a', assento: 0),
      1: ParticipantePartida(
          classe: ClasseDeParticipante.humano, userId: 'uid-b', assento: 1),
      2: ParticipantePartida(
          classe: ClasseDeParticipante.robo, botId: 'bot-1', assento: 2),
      3: ParticipantePartida(
          classe: ClasseDeParticipante.robo, botId: 'bot-2', assento: 3),
    };

RegistroDePartida registroRanqueado({
  String matchId = kMatchId,
  Map<int, ParticipantePartida>? assentos,
  List<String> espectadores = const [],
}) =>
    RegistroDePartida.abrir(
      identidade: identidadeRanqueada(matchId: matchId),
      participantes: [
        ...(assentos ?? quatroHumanos()).values,
        for (final uid in espectadores)
          ParticipantePartida(
              classe: ClasseDeParticipante.espectador, userId: uid),
      ],
      metaPontos: 1500,
    );

RegistroDePartida registroCasual({String matchId = kMatchId}) =>
    RegistroDePartida.abrir(
      identidade: identidadeCasual(matchId: matchId),
      participantes: quatroHumanos().values.toList(),
      metaPontos: 1500,
    );

// ------------------------------------------------------------------- motor

Jogo jogoNovo([String modalidade = 'ABERTO']) {
  final j = Jogo(const ['A', 'B', 'C', 'D'], const ['A', 'B', 'C', 'D'],
      const ['🐶', '🐰', '🦊', '🐱']);
  j.modalidade = modalidade;
  j.metaPontos = 1500;
  return j;
}

MotorPartida motorDe(Jogo j, {String partidaId = kMatchId}) => MotorPartida(
      partidaId: partidaId,
      jogo: j,
      agora: () => 1700000000000,
    );

/// Encerra o `Jogo` por placar, sem simular a partida — mesma técnica de
/// `teste_encerramento.dart`, e pelo mesmo motivo.
void encerrarJogo(Jogo j, {required int nos, required int eles, int rodada = 3}) {
  j.placar['nos'] = nos;
  j.placar['eles'] = eles;
  j.rodada = rodada;
  j.encerrada = true;
}

/// Cache das fixtures de desfecho.
///
/// NÃO é otimização. `Jogo` embaralha no construtor, e `impressaoEstado` mede o
/// estado do jogo — então dois `Jogo` recém-criados produzem desfechos com
/// impressões DIFERENTES, que a ingestão trata (corretamente) como divergentes.
/// Um teste de "o mesmo desfecho reenviado" precisa reenviar o MESMO desfecho, e
/// não um sósia com outras cartas na mesa.
final Map<String, DesfechoCanonicoPartida> _desfechos = {};

/// Desfecho conclusivo por meta atingida, com `nos` vencendo.
///
/// Estável para os mesmos argumentos — ver [_desfechos].
DesfechoCanonicoPartida desfechoNormal({
  String matchId = kMatchId,
  int nos = 1520,
  int eles = 1180,
  DateTime? em,
}) =>
    _desfechos.putIfAbsent('normal|$matchId|$nos|$eles|$em', () {
      final j = jogoNovo();
      encerrarJogo(j, nos: nos, eles: eles);
      return capturarDesfecho(
        motorDe(j, partidaId: matchId),
        encerradaEm: em ?? depois,
      );
    });

/// Desfecho por abandono, declarado pela autoridade.
DesfechoCanonicoPartida desfechoAbandono({
  String matchId = kMatchId,
  String ladoVencedor = 'nos',
  String autoridade = 'srv-1',
}) =>
    _desfechos.putIfAbsent('abandono|$matchId|$ladoVencedor|$autoridade', () {
      final j = jogoNovo();
      j.placar['nos'] = 300;
      j.placar['eles'] = 120;
      j.rodada = 2;
      return capturarDesfecho(
        motorDe(j, partidaId: matchId),
        encerradaEm: depois,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.abandono,
          ladoVencedor: ladoVencedor,
          autoridade: autoridade,
          declaradaEm: depois,
        ),
      );
    });

/// Desfecho de anulação.
DesfechoCanonicoPartida desfechoAnulado({String matchId = kMatchId}) =>
    _desfechos.putIfAbsent('anulado|$matchId', () {
      final j = jogoNovo();
      j.placar['nos'] = 400;
      j.placar['eles'] = 400;
      j.rodada = 2;
      return capturarDesfecho(
        motorDe(j, partidaId: matchId),
        encerradaEm: depois,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.anulada,
          autoridade: 'admin-1',
          declaradaEm: depois,
        ),
      );
    });

/// Desfecho de partida ainda viva.
DesfechoCanonicoPartida desfechoEmAndamento({String matchId = kMatchId}) =>
    capturarDesfecho(motorDe(jogoNovo(), partidaId: matchId),
        encerradaEm: depois);

// ------------------------------------------------------------------ torneio

/// `Participante.dupla` ordena os membros e monta o `participanteId` como
/// `a+b`. Os ids esperados nos testes são, portanto, `uid-a+uid-c` e
/// `uid-b+uid-d` — e não rótulos inventados.
const String kParticipanteNos = 'uid-a+uid-c';
const String kParticipanteEles = 'uid-b+uid-d';

SolicitacaoPartida solicitacaoDeDupla({String matchId = kMatchId}) =>
    SolicitacaoPartida(
      matchId: matchId,
      tournamentId: 't1',
      editionId: 'e1',
      faseId: 'f1',
      mesaId: 'f1-mesa-1',
      assentos: [
        Participante.dupla('uid-a', 'uid-c'),
        Participante.dupla('uid-b', 'uid-d'),
      ],
      modalidade: 'ABERTO',
      metaPontos: 1500,
      solicitadaEm: agora,
    );

VinculoDeMesa vinculoDeDupla({String matchId = kMatchId}) =>
    montarVinculoPadrao(solicitacaoDeDupla(matchId: matchId));
