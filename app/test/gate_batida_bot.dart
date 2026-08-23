// TEMPO LIMITE DO ARQUIVO — e por que ele precisa existir.
//
// O `package:test` mata um caso que passa do tempo limite, e o `flutter test`
// derruba o isolate inteiro quando isso acontece dentro de uma medição longa:
// o relatório sai com TODOS os casos marcados "did not complete" e sem
// mensagem nenhuma, o que parece defeito da suíte e não é. A medição deste
// portão leva dezenas de minutos por construção (são 26 partidas completas,
// jogadas duas vezes), então o limite tem de ser declarado aqui, no arquivo,
// e não por bandeira de linha de comando — quem rodar a suíte na mão precisa
// do mesmo limite que o CI.
@Timeout(Duration(hours: 4))
library;

// OS 43.1 — PORTÃO DETERMINÍSTICO DA CAPACIDADE DE BATIDA NATURAL DO BOT.
//
// O QUE ESTE ARQUIVO PROTEGE
// A capacidade de o robô FECHAR a mão de forma legal. É a única propriedade do
// bot que nenhum teste unitário alcança: bater exige que a dupla tenha chegado
// a uma canastra que libere a batida, tenha cumprido o morto e tenha zerado a
// mão — três coisas que só acontecem no fim de uma cadeia longa de decisões.
// Um bot que perdesse essa capacidade continuaria verde em toda a suíte atual,
// porque toda ela mede DECISÕES ISOLADAS sobre estados montados à mão. Aqui a
// medição é a partida inteira, e o número medido é quantas vezes ele bateu.
//
// NADA AQUI É FIXTURE
// Cada partida nasce de `Jogo(...)` com semente fixa e `MotorConfig.producao()`,
// isto é, 108 cartas distribuídas pelo motor real e todas as jogadas aplicadas
// pela autoridade canônica. Nenhuma mão é montada, nenhum estado é injetado,
// nenhuma canastra é posta na mesa para facilitar a batida. Se o bot bate, é
// porque ele jogou até lá.
//
// O ÚNICO DESVIO DA PRODUÇÃO, E POR QUE ELE EXISTE
// O FUSÍVEL TEMPORAL é desligado (`fusivelMs: 0`) — e só ele. O fusível é a
// única parte da busca que depende do RELÓGIO; deixá-lo ligado faria a máquina
// mais lenta cortar decisões que a máquina mais rápida completaria, e o portão
// deixaria de ser reprodutível: dois runners diferentes dariam contagens
// diferentes, e o portão passaria a medir o runner. Os TETOS DETERMINÍSTICOS
// (nós, transações de compra do lixo, planos avaliados) ficam exatamente nos
// valores de produção — são eles que limitam a busca aqui, como limitam lá.
//
// `ConfiguracaoBot.v2` (o padrão de produção que `Jogo.configuracaoBot` carrega)
// NÃO é alterada por este arquivo: a configuração de medição é DERIVADA dela em
// tempo de teste, e `GBB-03` exige que a de produção continue com o fusível
// ligado em 5000 ms.
//
// O QUE A PRIMEIRA MEDIÇÃO ENSINOU
// A versão inicial desta suíte exigia que TODA batida viesse com a razão
// `BAIXA_BATIDA`. Ela acusou duas divergências no corpus, e as duas eram uma
// só: em `STBL/semente 4` o robô do assento 3 comprou o lixo com uso ATÔMICO
// do topo, e a baixada exigida por essa compra consumiu a mão inteira — a
// autoridade estabilizou o turno em BATIDA ainda na fase de COMPRA. A decisão
// dizia `COMPRA_LIXO_ESTRUTURA`, e comprar foi exatamente o que se aplicou:
// não havia divergência nenhuma entre plano e ação, havia uma origem de batida
// que a medição não conhecia. Ver `kRazoesDeBatidaNaCompra`.
//
// COMO ELE FICA VERMELHO
// Os pisos por modalidade e o piso total estão declarados aqui como constantes
// e repetidos, de propósito, na fonte única (`test/gates/gates_bot.txt`) e na
// TRAVA que vive em `teste_motor.dart`. Baixar um piso exige editar os três, e
// cada um deles reprova sozinho.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/motor_config.dart';
import 'package:buraco_master_vip/motor/projecao_estado.dart' show paraCanonico;
import 'package:buraco_master_vip/rules/morto/morto.dart' as canonico;
import 'package:buraco_master_vip/rules/rule_spec.dart';
import 'package:buraco_master_vip/bot/orcamento_busca.dart';
import 'package:buraco_master_vip/bot/pesos.dart';
import 'package:buraco_master_vip/bot/razoes.dart';

import 'gates/sha256_puro.dart';

// =====================================================================
// CORPUS — constantes de COMPILAÇÃO, não parâmetros de ambiente.
//
// Ninguém encolhe este corpus por variável de ambiente na hora de rodar: para
// encolher é preciso editar o arquivo, e editar o arquivo muda o sha256 que a
// fonte única declara. É o que impede o portão de virar "roda uma semente e
// diz que mediu".
// =====================================================================

/// Nome da entrada desta suíte na fonte única.
const String kEntradaFonteUnica = 'GATE-BATIDA-NATURAL-BOT-V1';

/// As TRÊS modalidades. Retirar uma retira metade da regra de batida: no
/// Fechado qualquer canastra 7+ de sequência libera; no Aberto e no STBL só a
/// LIMPA. Um bot que perdesse a batida limpa continuaria verde só com Fechado.
const List<String> kModalidadesGate = <String>['ABERTO', 'FECHADO', 'STBL'];

/// Sementes fixas por modalidade, em BLOCO CONTÍGUO — nada de semente escolhida
/// a dedo por render batida. Os tamanhos diferem porque as taxas medidas
/// diferem: o Aberto exige canastra LIMPA e bate bem menos por rodada que o
/// Fechado. O relatório da OS registra a medição que dimensionou cada bloco.
const Map<String, List<int>> kSementesGate = <String, List<int>>{
  'ABERTO': <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  'FECHADO': <int>[1, 2, 3, 4, 5, 6, 7, 8],
  'STBL': <int>[1, 2, 3, 4, 5, 6, 7, 8],
};

/// PISOS de batidas legais por modalidade.
const Map<String, int> kPisosGate = <String, int>{
  'ABERTO': 12,
  'FECHADO': 25,
  'STBL': 16,
};

/// PISO agregado. É MAIOR que a soma dos pisos por modalidade (12+25+16 = 53)
/// de propósito: cumprir os três mínimos no limite não pode bastar.
const int kPisoTotalGate = 60;

/// Meta de pontos das partidas do corpus (a meta padrão do motor).
const int kMetaPontosGate = 1500;

/// Peso EXIGIDO da feature `batida` — e o valor que ela precisa ter no rastro
/// de toda batida vinda de um PLANO DE TURNO.
const double kPesoBatidaExigido = 160;

/// Razões com que uma batida pode nascer da fase de COMPRA.
///
/// A primeira medição deste portão acusou "divergência plano × ação" numa
/// batida do STBL, e a acusação estava errada — a medição é que estava
/// incompleta. O caso é real e vale registrar: em `STBL/semente 4`, o robô do
/// assento 3 comprou o lixo com uso ATÔMICO do topo, e a baixada exigida por
/// essa compra consumiu a mão inteira. A autoridade estabilizou o turno em
/// BATIDA, dentro da fase de compra, e o rastro daquela decisão trazia
/// `COMPRA_LIXO_ESTRUTURA` — porque a decisão foi COMPRAR, e comprar foi
/// exatamente o que se aplicou.
///
/// Isso NÃO é divergência: a ação aplicada é a ação declarada. Chamar de
/// divergência confundiria "a razão não diz batida" com "aconteceu outra
/// coisa". Mas também não pode ser aceito em silêncio — uma batida tem de vir
/// de uma razão que alguém escreveu de propósito. Por isso o vocabulário é
/// FECHADO: qualquer outra razão numa rodada encerrada por batida continua
/// sendo divergência.
const Set<String> kRazoesDeBatidaNaCompra = <String>{
  Razao.compraLixoEstrutura,
  Razao.compraLixoVolume,
};

/// Casos desta suíte, na ordem. A fonte única repete esta lista, e a TRAVA
/// compara as duas.
const List<String> kCasosGate = <String>[
  'GBB-01',
  'GBB-02',
  'GBB-03',
  'GBB-04',
  'GBB-05',
  'GBB-06',
  'GBB-07',
  'GBB-08',
  'GBB-09',
  'GBB-10',
  'GBB-11',
  'GBB-12',
  'GBB-13',
];

/// A suíte OBRIGATÓRIA do CI, onde vive a TRAVA que guarda este portão. A
/// relação é MÚTUA de propósito: `teste_motor.dart` importa este arquivo (e
/// deixa de compilar se ele sumir), e `GBB-13` exige que a TRAVA continue lá.
/// Assim nenhuma das duas metades pode ser removida sozinha em silêncio.
const String kCaminhoDaSuiteObrigatoria = 'test/teste_motor.dart';

/// Marcas que a TRAVA precisa ter em `teste_motor.dart`.
const List<String> kMarcasDaTrava = <String>[
  "group('OS 43.1 — TRAVA do portão de batida natural do bot'",
  "import 'gate_batida_bot.dart' as gate;",
  // A trava tem de continuar LENDO a evidência: sem isso ela deixa de
  // detectar o passo que não executou. A marca é a REFERÊNCIA à constante,
  // e não o caminho literal — que é justamente como o código honesto escreve.
  'File(gate.kArquivoEvidencia)',
  'TRAVA-01',
  'TRAVA-02',
  'TRAVA-03',
  'TRAVA-04',
  'TRAVA-05',
  'TRAVA-06',
  'TRAVA-07',
  'TRAVA-08',
  'TRAVA-09',
  'TRAVA-10',
];

/// Onde a EVIDÊNCIA é escrita. `teste_motor.dart` EXIGE este arquivo: sem ele,
/// o passo do portão não executou, e o portão obrigatório reprova.
const String kArquivoEvidencia = 'build/evidencia_gate_batida.json';

/// Caminho da própria suíte a partir da raiz do pacote de teste.
const String kCaminhoDaSuite = 'test/gate_batida_bot.dart';

/// Tetos ANTI-TRAVAMENTO da varredura. Não são regra: uma partida que os
/// atinge é registrada como truncada, e partida truncada reprova o portão.
const int _maxSegmentosPorRodada = 3000;
const int _maxRodadas = 60;

// =====================================================================
// CONFIGURAÇÃO DE MEDIÇÃO
// =====================================================================

/// A configuração de PRODUÇÃO do robô — a mesma que `Jogo.configuracaoBot`
/// carrega por padrão.
const ConfiguracaoBot producaoDoBot = ConfiguracaoBot.v2;

/// A configuração da MEDIÇÃO: produção com o FUSÍVEL TEMPORAL desligado, e nada
/// mais. Os tetos determinísticos vêm de `producaoDoBot`, não de números
/// escritos aqui — se a produção mudar um teto, a medição muda junto e o portão
/// continua medindo a busca que existe.
ConfiguracaoBot configuracaoDeMedicao() =>
    producaoDoBot.comLimites(LimitesBusca(
      nos: producaoDoBot.orcamentoBusca,
      transacoesCompraLixo: producaoDoBot.tetoTransacoesCompraLixo,
      planosAvaliados: producaoDoBot.tetoPlanosAvaliados,
      fusivelMs: 0,
    ));

String _duplaDoAssento(int assento) => assento % 2 == 0 ? 'nos' : 'eles';

// =====================================================================
// MEDIÇÃO DE UMA PARTIDA
// =====================================================================

/// O que uma partida do corpus produziu. Só contadores e um rastro textual —
/// nenhuma carta, nenhum estado privado.
class MedidaPartida {
  final String modalidade;
  final int semente;

  /// Rodadas encerradas com `duplaQueBateu != null`. É a ÚNICA definição de
  /// batida usada aqui, e ela vem do motor — não desta suíte.
  final int batidas;

  /// Batidas nascidas de um PLANO DE TURNO (razão `BAIXA_BATIDA`). São elas
  /// que carregam a feature `batida`.
  final int batidasPorPlano;

  /// Batidas nascidas da fase de COMPRA — a compra atômica do lixo que consome
  /// a mão inteira. Ver `kRazoesDeBatidaNaCompra`.
  final int batidasNaCompra;

  /// Rodadas encerradas SEM ninguém bater: baralho e mortos esgotados. Contado
  /// à parte de propósito. Esgotamento também encerra a rodada, e confundir os
  /// dois faria o portão dar por boa uma capacidade de batida inexistente.
  final int esgotamentos;

  /// Rodadas que EFETIVAMENTE encerraram, contadas na transição (aberta ->
  /// encerrada) e independentemente de qual dos dois desfechos ocorreu. É o
  /// total contra o qual a partição batida/esgotamento é conferida.
  final int rodadasEncerradas;

  final int rodadas;
  final int turnos;

  /// Decisões cujo rastro veio com a razão primária `BAIXA_BATIDA`.
  final int razaoBaixaBatida;

  /// Batida sem o plano correspondente, ou plano de batida sem batida.
  final int divergenciasPlanoAcao;

  /// Batida em que a habilitação canônica (morto cumprido + canastra que
  /// libera) não estava presente no pós-estado.
  final int batidasSemHabilitacao;

  /// Decisões que voltaram sem nenhuma ação.
  final int decisoesVazias;

  /// Turnos que terminaram sem conclusão: a rodada seguiu aberta e a vez não
  /// passou. É a forma OBSERVÁVEL de uma decisão vazia dentro de uma partida
  /// real — o rastro mostra a decisão, o estado mostra o turno pendurado.
  final int turnosSemConclusao;

  final int falhasTecnicas;
  final bool integro;
  final bool terminou;

  /// A partida bateu num teto anti-travamento (não deveria acontecer nunca).
  final bool truncada;

  /// Valores DISTINTOS que a feature `batida` assumiu nas batidas medidas.
  final List<double> featuresBatida;

  /// Rastro determinístico desta partida (entra no digest de reprodução).
  final String trilha;

  const MedidaPartida({
    required this.modalidade,
    required this.semente,
    required this.batidas,
    required this.batidasPorPlano,
    required this.batidasNaCompra,
    required this.esgotamentos,
    required this.rodadasEncerradas,
    required this.rodadas,
    required this.turnos,
    required this.razaoBaixaBatida,
    required this.divergenciasPlanoAcao,
    required this.batidasSemHabilitacao,
    required this.decisoesVazias,
    required this.turnosSemConclusao,
    required this.falhasTecnicas,
    required this.integro,
    required this.terminou,
    required this.truncada,
    required this.featuresBatida,
    required this.trilha,
  });
}

/// Joga UMA partida completa do corpus e mede a batida.
///
/// O laço é o mesmo do harness de partidas (`harness_partidas_bot.dart`): o
/// robô joga TODOS os quatro assentos, a rodada avança até encerrar e a partida
/// avança até a meta. O que muda é só o que se observa.
MedidaPartida medirPartida({
  required String modalidade,
  required int semente,
  required ConfiguracaoBot cfg,
  int metaPontos = kMetaPontosGate,
}) {
  final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
      const ['', '', '', ''],
      seed: semente, motorConfig: MotorConfig.producao());
  j.modalidade = modalidade;
  j.metaPontos = metaPontos;
  j.configuracaoBot = cfg;

  var batidas = 0,
      batidasPorPlano = 0,
      batidasNaCompra = 0,
      esgotamentos = 0,
      rodadasEncerradas = 0,
      rodadas = 0,
      turnos = 0,
      razaoBaixaBatida = 0,
      divergencias = 0,
      semHabilitacao = 0,
      decisoesVazias = 0,
      turnosSemConclusao = 0;
  var truncada = false;
  final features = <double>{};
  final trilha = StringBuffer('P|$modalidade|$semente\n');

  for (var rod = 0; rod < _maxRodadas && !j.encerrada; rod++) {
    rodadas++;
    var seg = 0;
    while (!j.rodadaEncerrada && seg < _maxSegmentosPorRodada) {
      seg++;
      turnos++;
      final assento = j.vez;
      final encerradaAntes = j.rodadaEncerrada;

      j.botJoga(assento);

      final d = j.ultimaDecisaoBot;
      final razao = d?['razao'];
      if (d != null && ((d['acoes'] as List?)?.isEmpty ?? true)) {
        decisoesVazias++;
      }
      if (razao == Razao.baixaBatida) razaoBaixaBatida++;
      if (!j.rodadaEncerrada && j.vez == assento) turnosSemConclusao++;

      final terminouAgora = j.rodadaEncerrada && !encerradaAntes;
      if (terminouAgora) rodadasEncerradas++;

      if (terminouAgora && j.duplaQueBateu != null) {
        batidas++;
        final dupla = j.duplaQueBateu!;
        trilha.write('B|$rod|$dupla|$assento|$razao\n');

        // ---- PLANO x AÇÃO, lado da AÇÃO ----
        // A rodada acabou em batida: a decisão que a produziu tem de ter DITO
        // o que ia fazer, com uma razão do vocabulário. Uma batida que o rastro
        // não explica é uma batida que ninguém escolheu — é acidente, e
        // acidente não é capacidade.
        if (razao == Razao.baixaBatida) {
          // Batida de PLANO DE TURNO: é ela que carrega a feature `batida`.
          batidasPorPlano++;
          final f = d?['features'];
          final fb = (f is Map) ? f['batida'] : null;
          if (fb is num) {
            features.add(fb.toDouble());
          } else {
            divergencias++;
          }
        } else if (kRazoesDeBatidaNaCompra.contains(razao)) {
          // Batida da fase de COMPRA — legítima e declarada. Não tem feature
          // `batida` porque não passou por plano de turno nenhum.
          batidasNaCompra++;
        } else {
          divergencias++;
        }
        if (_duplaDoAssento(assento) != dupla) divergencias++;

        // ---- HABILITAÇÃO, pela AUTORIDADE CANÔNICA ----
        // Não há reimplementação de regra aqui: `duplaPodeBater` é a mesma
        // função que a batida do humano consulta, e o estado consultado é a
        // projeção canônica do pós-estado real.
        final est = paraCanonico(j).canonico;
        final spec =
            RuleSpec.canonica(est.modalidade, metaPontos: est.metaPontos);
        final mortoCumprido =
            (est.mortoPego[dupla] ?? false) || est.mortos.isEmpty;
        if (!mortoCumprido) semHabilitacao++;
        if (!canonico.duplaPodeBater(est, dupla, spec)) semHabilitacao++;
      } else if (terminouAgora) {
        // ESGOTAMENTO — a rodada acabou sem ninguém bater. Nunca entra em
        // `batidas`: os dois ramos deste `if` são exclusivos, e a soma deles é
        // conferida contra `rodadasEncerradas` em GBB-09.
        esgotamentos++;
        trilha.write('E|$rod\n');
      } else if (razao == Razao.baixaBatida) {
        // ---- PLANO x AÇÃO, lado do PLANO ----
        // O turno terminou anunciando batida e a rodada seguiu aberta.
        divergencias++;
      }

      if (j.integridadeErro != null) break;
    }
    if (seg >= _maxSegmentosPorRodada) {
      truncada = true;
      break;
    }
    j.contarPontos();
    if (!j.encerrada) j.novaRodada();
  }
  if (rodadas >= _maxRodadas && !j.encerrada) truncada = true;

  trilha.write('F|$rodadas|$turnos|$batidas|$esgotamentos|'
      '${j.placar['nos']}|${j.placar['eles']}|${j.encerrada}\n');

  return MedidaPartida(
    modalidade: modalidade,
    semente: semente,
    batidas: batidas,
    batidasPorPlano: batidasPorPlano,
    batidasNaCompra: batidasNaCompra,
    esgotamentos: esgotamentos,
    rodadasEncerradas: rodadasEncerradas,
    rodadas: rodadas,
    turnos: turnos,
    razaoBaixaBatida: razaoBaixaBatida,
    divergenciasPlanoAcao: divergencias,
    batidasSemHabilitacao: semHabilitacao,
    decisoesVazias: decisoesVazias,
    turnosSemConclusao: turnosSemConclusao,
    falhasTecnicas: j.falhasTecnicas,
    integro: j.integridadeErro == null,
    terminou: j.encerrada,
    truncada: truncada,
    featuresBatida: features.toList()..sort(),
    trilha: trilha.toString(),
  );
}

/// O corpus inteiro, medido.
class MedidaCorpus {
  final List<MedidaPartida> partidas;
  const MedidaCorpus(this.partidas);

  int porModalidade(String m, int Function(MedidaPartida) campo) => partidas
      .where((p) => p.modalidade == m)
      .fold<int>(0, (a, p) => a + campo(p));

  int total(int Function(MedidaPartida) campo) =>
      partidas.fold<int>(0, (a, p) => a + campo(p));

  List<double> get featuresBatida {
    final s = <double>{};
    for (final p in partidas) {
      s.addAll(p.featuresBatida);
    }
    return s.toList()..sort();
  }

  /// Digest da execução. Duas execuções idênticas produzem a mesma string.
  String get digest {
    final sb = StringBuffer();
    for (final p in partidas) {
      sb.write(p.trilha);
    }
    return sha256Hex(utf8.encode(sb.toString()));
  }
}

MedidaCorpus medirCorpus(ConfiguracaoBot cfg) {
  final out = <MedidaPartida>[];
  for (final m in kModalidadesGate) {
    for (final s in kSementesGate[m]!) {
      out.add(medirPartida(modalidade: m, semente: s, cfg: cfg));
    }
  }
  return MedidaCorpus(out);
}

// =====================================================================
// EVIDÊNCIA
// =====================================================================

/// Digest da PRÓPRIA suíte, lido do disco. É o que amarra a evidência ao
/// arquivo que a fonte única declara: uma evidência produzida por outra versão
/// da suíte não serve de prova para esta.
String sha256DaSuite() =>
    sha256DeTextoNormalizado(File(kCaminhoDaSuite).readAsBytesSync());

void escreverEvidencia(Map<String, Object?> conteudo) {
  final f = File(kArquivoEvidencia);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(conteudo));
}

// =====================================================================
// SUÍTE
// =====================================================================

void main() {
  final cfg = configuracaoDeMedicao();
  MedidaCorpus? e1;
  MedidaCorpus? e2;

  // MEDIÇÃO SOB DEMANDA, e não em `setUpAll`.
  //
  // O corpus custa dezenas de minutos, e três casos desta suíte — GBB-02,
  // GBB-03 e GBB-13 — não dependem dele: eles conferem configuração e
  // estrutura. Num `setUpAll` esses três pagariam o corpus inteiro para ler uma
  // constante, e ninguém rodaria nenhum deles isoladamente. Aqui a medição
  // acontece na PRIMEIRA vez que alguém precisa dela, uma vez só, e quem não
  // precisa não paga.
  void medirUmaVez() {
    if (e1 != null) return;
    // DUAS EXECUÇÕES COMPLETAS do mesmo corpus, no mesmo processo. Não é
    // repetição decorativa: é a prova de que a contagem não depende de ordem de
    // iteração, de identidade de objeto nem de relógio. Se dependesse, os dois
    // digests divergiriam.
    final execucao1 = medirCorpus(cfg);
    final execucao2 = medirCorpus(cfg);
    e1 = execucao1;
    e2 = execucao2;

    escreverEvidencia(<String, Object?>{
      'entrada': kEntradaFonteUnica,
      'sha256Suite': sha256DaSuite(),
      'modalidades': kModalidadesGate,
      'sementes': kSementesGate,
      'metaPontos': kMetaPontosGate,
      'partidas': execucao1.partidas.length,
      'batidas': <String, int>{
        for (final m in kModalidadesGate)
          m: execucao1.porModalidade(m, (p) => p.batidas)
      },
      'batidasTotal': execucao1.total((p) => p.batidas),
      'batidasPorPlano': <String, int>{
        for (final m in kModalidadesGate)
          m: execucao1.porModalidade(m, (p) => p.batidasPorPlano)
      },
      'batidasNaCompra': <String, int>{
        for (final m in kModalidadesGate)
          m: execucao1.porModalidade(m, (p) => p.batidasNaCompra)
      },
      'razoesDeBatidaNaCompra': kRazoesDeBatidaNaCompra.toList()..sort(),
      'esgotamentos': <String, int>{
        for (final m in kModalidadesGate)
          m: execucao1.porModalidade(m, (p) => p.esgotamentos)
      },
      'razaoBaixaBatida': <String, int>{
        for (final m in kModalidadesGate)
          m: execucao1.porModalidade(m, (p) => p.razaoBaixaBatida)
      },
      'featureBatida': execucao1.featuresBatida,
      'divergenciasPlanoAcao': execucao1.total((p) => p.divergenciasPlanoAcao),
      'batidasSemHabilitacao': execucao1.total((p) => p.batidasSemHabilitacao),
      'decisoesVazias': execucao1.total((p) => p.decisoesVazias),
      'turnosSemConclusao': execucao1.total((p) => p.turnosSemConclusao),
      'falhasTecnicas': execucao1.total((p) => p.falhasTecnicas),
      'falhasIntegridade': execucao1.partidas.where((p) => !p.integro).length,
      'partidasTruncadas': execucao1.partidas.where((p) => p.truncada).length,
      'rodadas': execucao1.total((p) => p.rodadas),
      'rodadasEncerradas': execucao1.total((p) => p.rodadasEncerradas),
      'turnos': execucao1.total((p) => p.turnos),
      'pisos': kPisosGate,
      'pisoTotal': kPisoTotalGate,
      'fusivelDesligadoNaMedicao': cfg.fusivelBuscaMs == 0,
      'fusivelDeProducao': producaoDoBot.fusivelBuscaMs,
      'prudenciaBatida': cfg.regras.prudenciaBatida,
      'pesoBatida': producaoDoBot.pesos.batida,
      'tetos': <String, int>{
        'nos': cfg.orcamentoBusca,
        'transacoesCompraLixo': cfg.tetoTransacoesCompraLixo,
        'planosAvaliados': cfg.tetoPlanosAvaliados,
      },
      'digestExecucao1': execucao1.digest,
      'digestExecucao2': execucao2.digest,
      'determinismo': execucao1.digest == execucao2.digest,
      'casos': kCasosGate,
    });
  }

  MedidaCorpus medido() {
    medirUmaVez();
    return e1!;
  }

  MedidaCorpus reproducao() {
    medirUmaVez();
    return e2!;
  }

  // ---------- o que a medição É ----------

  test(
      'GBB-01 o corpus é de PARTIDAS REAIS de 108 cartas, com sementes fixas e '
      'as três modalidades', () {
    final execucao1 = medido();
    expect(kModalidadesGate, <String>['ABERTO', 'FECHADO', 'STBL']);
    expect(execucao1.partidas.length,
        kSementesGate.values.fold<int>(0, (a, l) => a + l.length));
    for (final m in kModalidadesGate) {
      final desta = execucao1.partidas.where((p) => p.modalidade == m).toList();
      expect(desta, isNotEmpty, reason: '$m sem nenhuma partida no corpus');
      expect(desta.map((p) => p.semente).toList(), kSementesGate[m],
          reason: '$m: as sementes jogadas têm de ser as declaradas');
      expect(desta.every((p) => p.rodadas > 0), isTrue);
      expect(desta.every((p) => p.turnos > 0), isTrue);
    }
    // As 108 cartas são conferidas pelo próprio motor: `auditarIntegridade`
    // roda a cada jogada e é ela que reprovaria um baralho diferente.
    expect(execucao1.partidas.every((p) => p.integro), isTrue,
        reason: 'integridade do baralho quebrada em alguma partida');
    // E conferidas aqui também, na distribuição inicial.
    final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
        const ['', '', '', ''],
        seed: kSementesGate['ABERTO']!.first,
        motorConfig: MotorConfig.producao());
    final total = j.monte.length +
        j.lixo.length +
        j.mortos.fold<int>(0, (a, m) => a + m.length) +
        j.maos.fold<int>(0, (a, m) => a + m.length);
    expect(total, 108);
    expect(j.mortos.length, 2);
    expect(j.maos.every((m) => m.length == 11), isTrue);
  });

  test(
      'GBB-02 a medição usa as REGRAS CANÔNICAS de produção e a prudência de '
      'batida LIGADA', () {
    expect(MotorConfig.producao().canonicoAtivo, isTrue);
    expect(cfg.regras.prudenciaBatida, isTrue,
        reason: 'medir com a prudência desligada mediria outro bot');
    expect(cfg.pesos.versao, producaoDoBot.pesos.versao);
    expect(cfg.pesos.batida, producaoDoBot.pesos.batida);
    expect(cfg.pesos.batidaPrematura, producaoDoBot.pesos.batidaPrematura);
    expect(cfg.regras.proibeDescartarCuringa, isTrue);
    expect(cfg.regras.protegeCanastraLimpa, isTrue);
    expect(cfg.regras.planoIncluiDescarte, isTrue);
    expect(cfg.seed, producaoDoBot.seed);
  });

  test(
      'GBB-03 o FUSÍVEL TEMPORAL está desligado SOMENTE na medição, e os tetos '
      'determinísticos são os de produção', () {
    expect(cfg.fusivelBuscaMs, 0, reason: 'o fusível tem de estar desligado');
    expect(producaoDoBot.fusivelBuscaMs, 5000,
        reason: 'a produção continua com o fusível LIGADO');
    expect(cfg.orcamentoBusca, producaoDoBot.orcamentoBusca);
    expect(
        cfg.tetoTransacoesCompraLixo, producaoDoBot.tetoTransacoesCompraLixo);
    expect(cfg.tetoPlanosAvaliados, producaoDoBot.tetoPlanosAvaliados);
    expect(cfg.maxBaixadasAvaliadas, producaoDoBot.maxBaixadasAvaliadas);
    expect(cfg.maxDescartesPorBaixada, producaoDoBot.maxDescartesPorBaixada);
    // E o teto determinístico continua sendo um teto de verdade.
    final orc = OrcamentoBuscaBot(cfg.limitesBusca);
    expect(orc.limites.nos, producaoDoBot.orcamentoBusca);
    expect(orc.limites.transacoesCompraLixo,
        producaoDoBot.tetoTransacoesCompraLixo);
    expect(orc.limites.fusivelMs, 0);
  });

  // ---------- os PISOS ----------

  test('GBB-04 ABERTO alcança o piso de batidas legais', () {
    final execucao1 = medido();
    final n = execucao1.porModalidade('ABERTO', (p) => p.batidas);
    expect(n, greaterThanOrEqualTo(kPisosGate['ABERTO']!),
        reason: 'ABERTO: $n batidas legais, piso ${kPisosGate['ABERTO']}');
  });

  test('GBB-05 FECHADO alcança o piso de batidas legais', () {
    final execucao1 = medido();
    final n = execucao1.porModalidade('FECHADO', (p) => p.batidas);
    expect(n, greaterThanOrEqualTo(kPisosGate['FECHADO']!),
        reason: 'FECHADO: $n batidas legais, piso ${kPisosGate['FECHADO']}');
  });

  test('GBB-06 STBL alcança o piso de batidas legais', () {
    final execucao1 = medido();
    final n = execucao1.porModalidade('STBL', (p) => p.batidas);
    expect(n, greaterThanOrEqualTo(kPisosGate['STBL']!),
        reason: 'STBL: $n batidas legais, piso ${kPisosGate['STBL']}');
  });

  test('GBB-07 o TOTAL de batidas legais alcança o piso agregado', () {
    final execucao1 = medido();
    final n = execucao1.total((p) => p.batidas);
    expect(n, greaterThanOrEqualTo(kPisoTotalGate),
        reason: 'total: $n batidas legais, piso $kPisoTotalGate');
  });

  // ---------- o que cada batida TEM de ser ----------

  test(
      'GBB-08 toda modalidade produz ao menos uma BAIXA_BATIDA, e a feature '
      '`batida` vale exatamente 160 em toda batida medida', () {
    final execucao1 = medido();
    for (final m in kModalidadesGate) {
      expect(execucao1.porModalidade(m, (p) => p.razaoBaixaBatida),
          greaterThanOrEqualTo(1),
          reason: '$m sem nenhuma decisão com razão ${Razao.baixaBatida}');
    }
    // O conjunto de valores DISTINTOS observados: uma lista com um elemento só,
    // e esse elemento é 160. Se uma única batida de plano tivesse outro peso, a
    // lista teria dois elementos.
    expect(execucao1.featuresBatida, <double>[kPesoBatidaExigido],
        reason: 'a feature `batida` do plano vencedor tem de ser sempre 160');
    expect(producaoDoBot.pesos.batida, kPesoBatidaExigido);
  });

  test(
      'GBB-09 zero divergência plano x ação, zero batida sem morto/canastra '
      'exigida, e ESGOTAMENTO nunca contado como batida', () {
    final execucao1 = medido();
    expect(execucao1.total((p) => p.divergenciasPlanoAcao), 0);
    expect(execucao1.total((p) => p.batidasSemHabilitacao), 0);
    // Toda batida veio de uma razão do VOCABULÁRIO: ou de um plano de turno
    // (`BAIXA_BATIDA`), ou da compra atômica do lixo que consome a mão. Não há
    // terceira origem, e a soma das duas tem de fechar com o total.
    expect(
        execucao1.total((p) => p.batidasPorPlano) +
            execucao1.total((p) => p.batidasNaCompra),
        execucao1.total((p) => p.batidas),
        reason: 'existe batida fora do vocabulário de razões');
    expect(execucao1.total((p) => p.batidasPorPlano), greaterThan(0));
    final batidas = execucao1.total((p) => p.batidas);
    final esgotados = execucao1.total((p) => p.esgotamentos);
    // O corpus precisa CONTER os dois desfechos, senão a distinção entre eles
    // nunca foi exercitada e a contagem passaria mesmo se eles fossem somados.
    expect(esgotados, greaterThan(0),
        reason: 'nenhuma rodada terminou por esgotamento: a distinção entre '
            'bater e acabar o baralho não foi exercitada');
    expect(batidas, greaterThan(0));
    expect(batidas + esgotados, execucao1.total((p) => p.rodadasEncerradas),
        reason: 'batida e esgotamento têm de PARTICIONAR as rodadas '
            'encerradas — nem sobrepor, nem deixar buraco');
  });

  test(
      'GBB-10 zero decisão vazia, zero turno sem conclusão, zero falha de '
      'integridade e nenhuma partida truncada', () {
    final execucao1 = medido();
    expect(execucao1.total((p) => p.decisoesVazias), 0);
    expect(execucao1.total((p) => p.turnosSemConclusao), 0);
    expect(execucao1.total((p) => p.falhasTecnicas), 0);
    expect(execucao1.partidas.where((p) => !p.integro).toList(), isEmpty);
    expect(execucao1.partidas.where((p) => p.truncada).toList(), isEmpty);
    expect(execucao1.partidas.where((p) => !p.terminou).toList(), isEmpty,
        reason: 'toda partida do corpus tem de chegar à meta');
  });

  // ---------- reprodução ----------

  test('GBB-11 duas execuções do corpus produzem resultados IDÊNTICOS', () {
    final execucao1 = medido();
    final execucao2 = reproducao();
    expect(execucao2.digest, execucao1.digest,
        reason: 'o corpus não é reprodutível: os digests divergiram');
    expect(execucao1.digest.length, 64);
    for (final m in kModalidadesGate) {
      expect(execucao2.porModalidade(m, (p) => p.batidas),
          execucao1.porModalidade(m, (p) => p.batidas),
          reason: m);
    }
    expect(execucao2.total((p) => p.batidas), execucao1.total((p) => p.batidas));
    expect(execucao2.total((p) => p.esgotamentos),
        execucao1.total((p) => p.esgotamentos));
    expect(execucao2.total((p) => p.turnos), execucao1.total((p) => p.turnos));
  });

  test('GBB-12 a EVIDÊNCIA foi escrita, e ela descreve ESTA execução', () {
    final execucao1 = medido();
    final f = File(kArquivoEvidencia);
    expect(f.existsSync(), isTrue, reason: 'evidência não foi escrita');
    final e = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    expect(e['entrada'], kEntradaFonteUnica);
    expect(e['sha256Suite'], sha256DaSuite());
    expect(e['determinismo'], isTrue);
    expect(e['digestExecucao1'], execucao1.digest);
    expect(e['batidasTotal'], execucao1.total((p) => p.batidas));
    expect(e['fusivelDesligadoNaMedicao'], isTrue);
    expect(e['fusivelDeProducao'], 5000);
    expect(e['prudenciaBatida'], isTrue);
    expect(e['pesoBatida'], kPesoBatidaExigido);
    expect(e['modalidades'], kModalidadesGate);
    expect(e['casos'], kCasosGate);
    expect(e['pisos'], kPisosGate);
    expect(e['pisoTotal'], kPisoTotalGate);
  });

  test('GBB-13 a TRAVA continua no portão OBRIGATÓRIO do CI', () {
    // A outra metade da proteção. `teste_motor.dart` importa esta suíte, então
    // apagá-la quebra a compilação de lá; este caso fecha o sentido inverso —
    // apagar a TRAVA de lá reprova aqui. Nenhuma das duas metades some sozinha
    // sem que o CI fique vermelho.
    final f = File(kCaminhoDaSuiteObrigatoria);
    expect(f.existsSync(), isTrue,
        reason: 'a suíte obrigatória do CI sumiu: $kCaminhoDaSuiteObrigatoria');
    final src = f.readAsStringSync();
    for (final marca in kMarcasDaTrava) {
      expect(src.contains(marca), isTrue,
          reason: 'a TRAVA do portão de batida perdeu a marca "$marca" em '
              '$kCaminhoDaSuiteObrigatoria');
    }
  });
}
