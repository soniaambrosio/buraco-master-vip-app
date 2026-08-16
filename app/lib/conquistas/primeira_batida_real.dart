// primeira_batida_real.dart — QUEM DECIDE a conquista `primeira_batida_real`.
//
// Esta é a regra, e ela existe UMA vez. A Cloud Function que grava a concessão
// não repete nenhum `if` daqui: ela chama este código compilado
// (`functions/lib/domain_bundle.js`, via `app/lib/torneios/js_bridge.dart`) pela
// mesma disciplina que `domain.ts` já declara para o Motor de Torneios —
// "escrever essas regras em TypeScript criaria uma segunda implementação do
// mesmo motor, e as duas divergiriam no primeiro dia".
//
// POR QUE ESTE ARQUIVO NÃO IMPORTA `RegistroDePartida`, que seria o tipo
// natural da entrada: `registro_partida.dart` → `motor/desfecho_partida.dart` →
// `motor/motor_partida.dart` → `mesa.dart` → `package:flutter/material.dart`.
// Flutter não compila para JS de servidor, e arrastar a árvore inteira para
// dentro do bundle por causa de uma leitura de campo travaria a ponte. Então a
// entrada é [FatosDoEncerramento]: os campos que a decisão realmente lê, no
// MESMO vocabulário de wire que `RegistroDePartida.toJson()` já publica.
//
// FRONTEIRA DE CONFIANÇA — o que este arquivo NÃO faz, e não deve passar a
// fazer:
//   * não recalcula vencedor, placar, pontuação nem legalidade de jogada;
//   * não deduz quem bateu (o assento vem do motor, ver o commit do contrato);
//   * não lê relógio (o `obtidaEm` é carimbado pelo servidor, na gravação);
//   * não conhece Firestore, título, descrição, arte nem recompensa.
//
// FAIL-CLOSED é a política em toda ausência: campo que não veio é "não sei", e
// "não sei" nunca concede. Um envelope antigo — gravado antes de o assento
// existir no contrato — é indistinguível, para esta função, de uma partida que
// acabou sem batida. As duas recusam.

/// Identificador canônico e estável da conquista.
///
/// É o id do documento em `playerAchievements/{uid}/items/{id}`, e é o mesmo
/// texto que o catálogo do cliente usará para achar título e arte. Trocá-lo
/// órfã as concessões já gravadas.
const String conquistaPrimeiraBatidaReal = 'primeira_batida_real';

/// Versão do contrato de concessão, gravada junto de cada concessão.
const int versaoContratoPrimeiraBatidaReal = 1;

/// A origem declarada da concessão, gravada no documento.
const String origemPrimeiraBatidaReal = 'encerramento_autoritativo_v1';

/// Por que uma partida encerrada NÃO gerou a conquista.
///
/// Cada valor é uma recusa distinta, e não um "erro" genérico: o log da Function
/// grava este código (e só ele) quando nada é concedido, e um motivo agregado
/// tornaria impossível responder "por que fulano não recebeu?" sem reabrir a
/// partida.
enum MotivoInelegibilidade {
  /// O registro não está num estado terminal de vitória.
  partidaNaoFinalizada('partida_nao_finalizada'),

  /// Terminou, mas não por conclusão natural: abandono, anulação ou decisão
  /// administrativa. Nenhum deles é "venceu com uma batida".
  encerramentoNaoNatural('encerramento_nao_natural'),

  /// Sem lado vencedor declarado — empate ou partida anulada.
  semVencedor('sem_vencedor'),

  /// A identidade da partida foi cunhada localmente, no próprio aparelho. Não
  /// houve autoridade processando nada.
  partidaNaoAutoritativa('partida_nao_autoritativa'),

  /// Treino, tutorial ou mesa contra robôs: não é partida real para conquista.
  tipoNaoConta('tipo_nao_conta'),

  /// A última rodada não terminou em batida legal — ou o envelope não disse
  /// quem bateu. As duas coisas recusam igual, de propósito.
  semBatidaFinalConhecida('sem_batida_final_conhecida'),

  /// Bateu quem perdeu. Acontece: bater a última rodada não é vencer a partida.
  batidaDoLadoPerdedor('batida_do_lado_perdedor'),

  /// O assento que bateu não corresponde a competidor nenhum do registro.
  assentoSemParticipante('assento_sem_participante'),

  /// Quem bateu foi robô, convidado ou espectador. Conquista é de gente com
  /// conta.
  executorNaoHumano('executor_nao_humano'),

  /// Participante humano sem `userId` utilizável — não há onde gravar.
  executorSemIdentidade('executor_sem_identidade'),

  /// O envelope se contradiz (lado vencedor que não existe no placar, assento
  /// em dois lados, participantes duplicados no mesmo assento).
  envelopeIncoerente('envelope_incoerente');

  final String wire;
  const MotivoInelegibilidade(this.wire);

  static MotivoInelegibilidade? porWire(String wire) {
    for (final m in MotivoInelegibilidade.values) {
      if (m.wire == wire) return m;
    }
    return null;
  }
}

/// Um competidor, como a decisão precisa conhecê-lo.
class ParticipanteNoEncerramento {
  /// `humano` | `robo` | `convidado` | `espectador` — o wire de
  /// `ClasseDeParticipante`.
  final String classe;

  /// UID da conta. Só humano tem.
  final String? userId;

  /// Assento 0..3. Espectador não ocupa assento e chega com `null`.
  final int? assento;

  const ParticipanteNoEncerramento({
    required this.classe,
    this.userId,
    this.assento,
  });

  /// É gente com conta? Espelha `ClasseDeParticipante.autenticado`.
  bool get humanoAutenticado => classe == 'humano';

  static ParticipanteNoEncerramento deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('participante: objeto esperado.');
    }
    final assento = raw['assento'];
    if (assento != null && assento is! num) {
      throw FormatException('participante: assento deve ser numérico ou nulo '
          '(recebido: $assento).');
    }
    return ParticipanteNoEncerramento(
      classe: '${raw['classe']}',
      userId: raw['userId'] as String?,
      assento: (assento as num?)?.toInt(),
    );
  }
}

/// Os fatos do encerramento que a decisão lê — nada além disso.
///
/// Todos os nomes e valores são os que `RegistroDePartida.toJson()` já publica.
/// Este objeto não é um segundo modelo de partida: é o recorte mínimo, e o teste
/// `fatos_espelham_o_registro_test.dart` prova que o recorte continua batendo
/// com o registro real.
class FatosDoEncerramento {
  /// Wire de `EstadoDaPartida`: `finalizada`, `abandonada`, `cancelada`, …
  final String estado;

  /// Wire de `MotivoEncerramento`: `meta_atingida`, `abandono`, …
  final String? motivoEncerramento;

  /// Wire de `OrigemDaIdentidade`: `servidor`, `torneio`, `local`.
  final String origemIdentidade;

  /// Wire de `TipoDePartida`: `publica_ranqueada`, `treinamento`, …
  final String tipo;

  /// `nos` | `eles` | null.
  final String? ladoVencedor;

  /// Assento de quem bateu na rodada que encerrou a partida, ou `null`.
  final int? assentoQueBateuFinal;

  /// Assentos de cada lado, como o placar os declara: `{'nos': [0,2], ...}`.
  final Map<String, List<int>> assentosPorLado;

  final List<ParticipanteNoEncerramento> participantes;

  FatosDoEncerramento({
    required this.estado,
    required this.motivoEncerramento,
    required this.origemIdentidade,
    required this.tipo,
    required this.ladoVencedor,
    required this.assentoQueBateuFinal,
    required Map<String, List<int>> assentosPorLado,
    required List<ParticipanteNoEncerramento> participantes,
  })  : assentosPorLado = Map.unmodifiable({
          for (final e in assentosPorLado.entries)
            e.key: List<int>.unmodifiable(e.value),
        }),
        participantes = List.unmodifiable(participantes);

  /// Lê os fatos do JSON de `RegistroDePartida`.
  ///
  /// Aceita o registro inteiro: assim a Function não escolhe campos, e um campo
  /// que mude de nome quebra aqui — num lugar coberto por teste — em vez de
  /// virar `null` silencioso do outro lado da ponte.
  static FatosDoEncerramento doRegistroJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('registro: objeto esperado.');
    }
    final identidade = raw['identidade'];
    if (identidade is! Map) {
      throw const FormatException('registro: identidade ausente.');
    }
    final participantes = raw['participantes'];
    if (participantes is! List) {
      throw const FormatException('registro: participantes deve ser lista.');
    }
    final assentoBatida = raw['assentoQueBateuFinal'];
    if (assentoBatida != null && assentoBatida is! num) {
      throw FormatException('registro: assentoQueBateuFinal deve ser numérico '
          'ou nulo (recebido: $assentoBatida).');
    }

    final porLado = <String, List<int>>{};
    final placar = raw['placar'];
    if (placar is List) {
      for (final p in placar) {
        if (p is! Map) continue;
        final lado = p['lado'];
        final assentos = p['assentos'];
        if (lado is! String || assentos is! List) continue;
        porLado[lado] = [
          for (final a in assentos)
            if (a is num) a.toInt(),
        ];
      }
    }

    return FatosDoEncerramento(
      estado: '${raw['estado']}',
      motivoEncerramento: raw['motivoEncerramento'] as String?,
      // A origem mora na identidade, e não na raiz: é ela que diz se houve
      // autoridade cunhando o id ou se a partida nasceu no aparelho.
      origemIdentidade: '${identidade['origem']}',
      tipo: '${raw['tipo'] ?? identidade['tipo']}',
      ladoVencedor: raw['ladoVencedor'] as String?,
      assentoQueBateuFinal: (assentoBatida as num?)?.toInt(),
      assentosPorLado: porLado,
      participantes: [
        for (final p in participantes) ParticipanteNoEncerramento.deJson(p),
      ],
    );
  }
}

/// O que a decisão devolve.
class VeredictoPrimeiraBatidaReal {
  /// UID que deve receber a conquista, ou `null` se ninguém deve.
  final String? userId;

  /// Assento do executor, quando houve um elegível. Só para o log e a prova.
  final int? assento;

  /// Por que não concedeu. `null` quando concedeu.
  final MotivoInelegibilidade? motivo;

  const VeredictoPrimeiraBatidaReal._({this.userId, this.assento, this.motivo});

  const VeredictoPrimeiraBatidaReal.conceder(String uid, int assento)
      : this._(userId: uid, assento: assento);

  const VeredictoPrimeiraBatidaReal.recusar(MotivoInelegibilidade motivo)
      : this._(motivo: motivo);

  bool get elegivel => userId != null;

  Map<String, Object?> toJson() => {
        'elegivel': elegivel,
        'userId': userId,
        'assento': assento,
        'motivo': motivo?.wire,
        'conquistaId': conquistaPrimeiraBatidaReal,
        'versaoContrato': versaoContratoPrimeiraBatidaReal,
        'origem': origemPrimeiraBatidaReal,
      };
}

/// Tipos de partida que contam para a conquista.
///
/// Lista FECHADA e positiva, no mesmo espírito de `TipoDePartida.alteraRanking`:
/// um tipo novo criado amanhã não entra sozinho — precisa ser escrito aqui, de
/// propósito, por alguém que decidiu.
///
/// `treinamento` e `contra_robos` ficam de fora porque são, por definição, mesa
/// de prática: o primeiro é tutorial, o segundo é a mesa cujos adversários são
/// robôs oficiais. Nenhum dos dois é "sua primeira partida".
///
/// `privada` fica DENTRO: é gente de verdade jogando de verdade, e não está em
/// nenhuma das exclusões da regra. Vale registrar, para quem for revisar a
/// política: ela é combinável (o dono escolhe os adversários), e por isso não
/// pontua ranking. Para uma conquista concedida UMA vez na vida, o custo dessa
/// combinação é um marco antecipado, não vantagem competitiva acumulável.
const Set<String> tiposQueContamParaConquista = {
  'publica_casual',
  'publica_ranqueada',
  'privada',
  'torneio',
};

/// Decide quem — se alguém — ganhou a `primeira_batida_real` neste encerramento.
///
/// A ordem das checagens é deliberada: do mais geral (a partida sequer é
/// elegível?) para o mais específico (esta pessoa é elegível?). Assim o motivo
/// devolvido é o mais informativo disponível, e não o primeiro tecnicamente
/// verdadeiro.
///
/// NÃO checa se o jogador já possui a conquista. Isso não é regra de
/// elegibilidade, é idempotência de gravação, e mora onde a gravação mora — no
/// id determinístico do documento, dentro da transação. Misturar as duas coisas
/// aqui exigiria que esta função lesse o banco, e ela não lê nada.
VeredictoPrimeiraBatidaReal avaliarPrimeiraBatidaReal(
  FatosDoEncerramento fatos,
) {
  // 1. A partida terminou de verdade, e terminou ganhando?
  if (fatos.estado != 'finalizada') {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.partidaNaoFinalizada);
  }
  // `encerrada_por_admin` também produz `finalizada`, e é justamente por isso
  // que o motivo é conferido à parte: uma partida fechada no braço pela
  // administração não teve batida encerrando nada.
  if (fatos.motivoEncerramento != 'meta_atingida') {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.encerramentoNaoNatural);
  }
  final vencedor = fatos.ladoVencedor;
  if (vencedor == null || vencedor.isEmpty) {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.semVencedor);
  }

  // 2. A partida foi processada por autoridade real, e é de um tipo que conta?
  if (fatos.origemIdentidade == 'local') {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.partidaNaoAutoritativa);
  }
  if (!tiposQueContamParaConquista.contains(fatos.tipo)) {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.tipoNaoConta);
  }

  // 3. Houve batida legal encerrando a partida, e sabemos de quem?
  final assento = fatos.assentoQueBateuFinal;
  if (assento == null) {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.semBatidaFinalConhecida);
  }

  final assentosVencedores = fatos.assentosPorLado[vencedor];
  if (assentosVencedores == null || assentosVencedores.isEmpty) {
    // Vencedor declarado que não tem assentos no placar: o envelope não fecha.
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.envelopeIncoerente);
  }
  if (!assentosVencedores.contains(assento)) {
    // Bateu e perdeu. É a checagem que impede a leitura ingênua "acabou com
    // batida dele, logo ele ganhou".
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.batidaDoLadoPerdedor);
  }

  // 4. Quem estava naquele assento?
  final ocupantes = [
    for (final p in fatos.participantes)
      if (p.assento == assento) p,
  ];
  if (ocupantes.isEmpty) {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.assentoSemParticipante);
  }
  if (ocupantes.length > 1) {
    // Dois participantes no mesmo assento: não dá para escolher, e escolher
    // errado premiaria a pessoa errada em definitivo.
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.envelopeIncoerente);
  }
  final executor = ocupantes.single;
  if (!executor.humanoAutenticado) {
    // Robô que bate não ganha nada. É a linha que impede a mesa contra robôs
    // de virar fábrica de conquista mesmo que o tipo dela fosse aceito.
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.executorNaoHumano);
  }
  final uid = executor.userId;
  if (uid == null || uid.isEmpty) {
    return const VeredictoPrimeiraBatidaReal.recusar(
        MotivoInelegibilidade.executorSemIdentidade);
  }

  // O parceiro do executor NUNCA chega aqui: a função devolve UM uid, o do
  // assento que bateu. Não existe caminho que devolva os dois.
  return VeredictoPrimeiraBatidaReal.conceder(uid, assento);
}
