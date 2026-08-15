// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — §8 HeuristicEvaluator.
//
// Transforma um plano já legal numa NOTA, e — mais importante — deixa por
// escrito de que parcelas essa nota é feita. Cada `features[...]` é a
// contribuição JÁ COM SINAL de uma heurística; a soma é o score. Isso é o que
// torna a decisão auditável: dá para olhar a tabela e ver qual termo ganhou.
//
// A função de utilidade é DA DUPLA (§1). Ela pondera estrutura da própria mão,
// mas também o que os jogos públicos da dupla pedem, quanto o parceiro está
// carregado e o quanto o descarte serve ao adversário.
//
// Nenhum peso mora aqui: todos vêm de `PesosHeuristicos`. Nenhuma legalidade
// mora aqui: o plano só chega depois de aprovado pela autoridade.
import '../rules/estado.dart';
import '../rules/meld/meld_validator.dart' show validarJogoMesa;
import '../rules/pontuacao_canonica.dart' show bonusCanastra, pontosCartas;
import '../rules/rule_spec.dart';
import 'analise_mao.dart';
import 'gerador_candidatos.dart';
import 'modelo_parceiro.dart';
import 'pesos.dart';
import 'risco_descarte.dart';
import 'visao_informacao.dart';

/// Nota de uma alternativa + a decomposição que a explica.
class Avaliacao {
  final double score;

  /// Contribuição de cada heurística, já com sinal. Soma == `score`.
  final Map<String, double> features;

  const Avaliacao(this.score, this.features);

  factory Avaliacao.de(Map<String, double> f) {
    var s = 0.0;
    for (final v in f.values) {
      s += v;
    }
    return Avaliacao(s, f);
  }
}

/// Valor médio esperado de uma carta desconhecida (tabela canônica: as cartas
/// de 3 a 7 valem 5, de 8 a K valem 10, A vale 15, 2 vale 10, Joker 50). Usado
/// SÓ para precificar o lastro do lixo enterrado — nunca para adivinhar QUAL
/// carta está lá, o que seria informação oculta.
const double _valorEsperadoCartaDesconhecida = 8.0;

class AvaliadorHeuristico {
  final RuleSpec spec;
  final ConfiguracaoBot cfg;

  const AvaliadorHeuristico(this.spec, this.cfg);

  PesosHeuristicos get p => cfg.pesos;
  RegrasEstrategicas get r => cfg.regras;

  /// Avalia um PLANO COMPLETO da fase de jogo.
  Avaliacao avaliarPlano(
    PlanoTurno plano,
    VisaoInformacao inicial,
    ModeloParceiro parceiro,
    ModeloAdversario adversario,
  ) {
    final f = <String, double>{};

    // ---------- objetivos de rodada ----------
    if (plano.abriu) {
      f['abertura'] = p.abertura;
      if (plano.sujeitoAoMinimo) f['aberturaVulneravel'] = p.aberturaVulneravel;
    }
    if (plano.pegouMorto) f['morto'] = p.morto;
    if (plano.bateu) {
      f['batida'] = p.batida;
      // §6 — bater com o parceiro carregado e sem ameaça adversária custa mais
      // do que vale. O peso é maior que o da batida DE PROPÓSITO: sem isso a
      // prudência seria decorativa.
      if (r.prudenciaBatida && parceiro.batidaPrematura()) {
        f['batidaPrematura'] = -p.batidaPrematura;
      }
    }

    // ---------- mesa (NÍVEL, em pontos) ----------
    // Pontos das cartas + bônus de canastra + potencial ainda não realizado.
    // É NÍVEL, e não delta, de propósito: misturar nível (estrutura) com delta
    // (canastra nova) foi o que produziu o bot que fazia jogos de seis cartas e
    // parava — para ele, completar a canastra APAGAVA um potencial que a conta
    // valorizava mais que o próprio bônus.
    f['valorMesa'] = p.valorMesa * _valorDaMesa(plano.visaoFinal.meldsProprios);
    // §4 — expor estrutura sem benefício é custo, não neutro.
    if (plano.cartasExpostasEmJogosNovos > 0 &&
        !plano.ganhoDecisivo &&
        plano.canastrasNovas == 0) {
      f['exposicaoSemGanho'] =
          -p.exposicaoSemGanho * plano.cartasExpostasEmJogosNovos;
    }

    // Terminar o turno sem descarte legal é um beco sem saída do motor: a vez
    // não passa. Custa caro, mas não é proibido — às vezes é o único jeito de a
    // dupla abrir sob o mínimo de vulnerabilidade.
    if (plano.turnoIncompleto) f['turnoSemSaida'] = -p.turnoSemSaida;

    // ---------- mão restante (NÍVEL, na MESMA moeda) ----------
    //
    // O potencial da mão é o mesmo `potencialCanastra` da mesa, DESCONTADO:
    // uma corrida na mão ainda precisa ser comprada e baixada para virar bônus,
    // e a mesa também deixa o parceiro estender. É esse desconto que faz baixar
    // a corrida INTEIRA ser bom negócio e DESMONTÁ-LA ser péssimo — que é
    // exatamente a distinção que a §4 pede.
    //
    // Com a mão OCULTA (plano que pega o morto) não há mão a medir: pontuar as
    // 11 cartas novas seria ler o futuro do baralho (§7).
    if (!plano.visaoFinal.maoOculta) {
      final fim = AnaliseMao.analisar(plano.visaoFinal.mao, spec);
      f['potencialMao'] = p.potencialMao * fim.potencialCorridas;
      f['ligacoesMao'] = p.ligacoesMao * fim.pontosEstrutura;
      f['deadwood'] = -p.deadwood * fim.pontosDeadwood;
      f['maoResidual'] = -p.maoResidual * fim.pontosMao;
    }
    final excedente = _excedente(plano.visaoFinal.tamanhoMao);
    if (excedente > 0) f['excedenteMao'] = -excedente;

    // ---------- curinga (§3) ----------
    // O custo do curinga NÃO é perdoado por "ganho decisivo". Perdoá-lo fazia o
    // bot queimar o Joker em QUALQUER abertura que cumprisse o mínimo, mesmo
    // existindo um caminho natural com os mesmos pontos — exatamente o que a §3
    // proíbe. O ganho decisivo já vale 140/160/220 no score; se ele realmente
    // compensa, compensa PAGANDO o curinga, e a comparação decide sozinha.
    if (r.preservaCuringa) {
      final pagos = plano.curingasComprometidos - plano.curingasGratuitos;
      if (pagos > 0) f['custoCuringa'] = -p.custoCuringa * pagos;
      if (plano.curingasGratuitos > 0) {
        f['custoCuringaGratuito'] =
            -p.custoCuringaGratuito * plano.curingasGratuitos;
      }
    }

    // ---------- descarte (§2) ----------
    if (r.planoIncluiDescarte && plano.cartaDescartada != null) {
      final carta = plano.cartaDescartada!;
      if (r.avaliaDanoEstrutural) {
        // Dano medido na mão do MOMENTO do descarte (depois da baixada), que é
        // a mão final mais a carta que saiu. Medir na mão inicial acusaria de
        // "estruturada" uma carta cujos vizinhos já foram para a mesa.
        final maoNoDescarte = <CartaSnapshot>[
          ...plano.visaoFinal.mao,
          carta,
        ];
        final a = AnaliseMao.analisar(maoNoDescarte, spec);
        f['danoDescarte'] = -p.danoDescarte * a.dano(carta.id);
      }
      if (r.evitaAlimentarAdversario) {
        f['riscoDescarte'] = -p.riscoDescarte * adversario.avaliar(carta).nota;
      }
      if (r.preservaCartaDoParceiro) {
        if (parceiro.utilAosJogosDaDupla(carta)) {
          f['descarteUtilAoParceiro'] = -p.descarteUtilAoParceiro;
        } else if (parceiro.adjacenteAosJogosDaDupla(carta)) {
          f['descarteAdjacenteAoParceiro'] = -p.descarteAdjacenteAoParceiro;
        }
      }
    }

    return Avaliacao.de(f);
  }

  /// Valor dos jogos da dupla na mesa, em PONTOS: cartas + bônus de canastra +
  /// potencial ainda não realizado. Quem responde "isto é canastra e quanto
  /// vale" é a pontuação canônica, não uma tabela paralela do bot.
  int _valorDaMesa(List<List<CartaSnapshot>> melds) {
    var s = 0;
    for (final m in melds) {
      final r = validarJogoMesa(m, spec);
      if (!r.valido) continue;
      s += pontosCartas(r.ordenado) + bonusCanastra(r) + potencialCanastra(m.length);
    }
    return s;
  }

  /// Custo de segurar mão grande demais (quadrático acima do limiar).
  /// Na fase de COMPRA o limiar ganha a folga do que o turno ainda vai baixar.
  double _excedente(int tamanhoMao, {bool naCompra = false}) {
    final limiar =
        p.limiarMaoConfortavel + (naCompra ? p.folgaDeCompra : 0);
    final e = tamanhoMao - limiar;
    return e <= 0 ? 0 : p.excedenteMao * e * e;
  }

  /// Linha de base da compra: uma carta desconhecida do monte.
  Avaliacao avaliarCompraMonte({int tamanhoMaoAtual = 0}) {
    final f = <String, double>{'compraMonteBase': p.compraMonteBase};
    final ex = _excedente(tamanhoMaoAtual + 1, naCompra: true);
    if (ex > 0) f['excedenteMao'] = -ex;
    return Avaliacao.de(f);
  }

  /// Avalia comprar o LIXO com um uso do topo já derivado pela autoridade
  /// (Fechado/STBL). O uso é descrito pelo que ele põe na mesa; as cartas
  /// ENTERRADAS entram apenas como volume/lastro ESPERADO — jamais lidas.
  Avaliacao avaliarCompraLixo({
    required VisaoInformacao inicial,
    required int cartasNaMesa,
    required List<List<CartaSnapshot>> mesaDepois,
    required int curingasComprometidos,
    required bool abre,
    required bool sujeitoAoMinimo,
  }) {
    final f = <String, double>{};
    final enterradas = inicial.lixoTamanho > 0 ? inicial.lixoTamanho - 1 : 0;

    if (abre) {
      f['abertura'] = p.abertura;
      if (sujeitoAoMinimo) f['aberturaVulneravel'] = p.aberturaVulneravel;
    }
    // Mesma moeda da fase de jogo: o ganho é o quanto a MESA passa a valer.
    final ganhoMesa =
        _valorDaMesa(mesaDepois) - _valorDaMesa(inicial.meldsProprios);
    if (ganhoMesa != 0) f['valorMesa'] = p.valorMesa * ganhoMesa;
    if (enterradas > 0) {
      f['compraLixoVolume'] = p.compraLixoVolume * enterradas;
      f['compraLixoLastro'] =
          -p.compraLixoLastro * enterradas * _valorEsperadoCartaDesconhecida;
    }
    // Recolher o lixo inteiro incha a mão: o custo entra AQUI, na decisão, e
    // não só depois. Sem isto o bot compra volume que nunca vai conseguir usar.
    final ex = _excedente(inicial.tamanhoMao + inicial.lixoTamanho - cartasNaMesa,
        naCompra: true);
    if (ex > 0) f['excedenteMao'] = -ex;
    // Comprometer curinga só para justificar o topo é o mesmo erro da §3.
    final decisivo = abre && sujeitoAoMinimo;
    if (r.preservaCuringa && !decisivo && curingasComprometidos > 0) {
      f['custoCuringa'] = -p.custoCuringa * curingasComprometidos;
    }
    // Cartas expostas sem ganho: mesma conta da fase de jogo.
    if (cartasNaMesa > 0 && !decisivo) {
      f['exposicaoSemGanho'] = -p.exposicaoSemGanho * cartasNaMesa;
    }
    return Avaliacao.de(f);
  }

  /// Avalia comprar o lixo no ABERTO, onde a compra é livre e não exige uso do
  /// topo. Só o TOPO é lido (as enterradas seguem ocultas até a autorização): o
  /// ganho é o quanto o topo casa com a mão e com os jogos públicos da dupla.
  Avaliacao avaliarCompraLixoAberto({
    required VisaoInformacao inicial,
    required ModeloParceiro parceiro,
  }) {
    final f = <String, double>{};
    final topo = inicial.lixoTopo;
    if (topo == null) return Avaliacao.de(f);
    final enterradas = inicial.lixoTamanho - 1;

    final antes = AnaliseMao.analisar(inicial.mao, spec);
    final depois = AnaliseMao.analisar([...inicial.mao, topo], spec);
    final dPot = depois.potencialCorridas - antes.potencialCorridas;
    final dLig = depois.pontosEstrutura - antes.pontosEstrutura;
    if (dPot != 0) f['potencialMao'] = p.potencialMao * dPot;
    if (dLig != 0) f['ligacoesMao'] = p.ligacoesMao * dLig;
    if (parceiro.utilAosJogosDaDupla(topo)) {
      f['topoUtilAoJogo'] = p.topoUtilAoJogo;
    }
    if (enterradas > 0) {
      f['compraLixoVolume'] = p.compraLixoVolume * enterradas;
      f['compraLixoLastro'] =
          -p.compraLixoLastro * enterradas * _valorEsperadoCartaDesconhecida;
    }
    // No Aberto o lixo inteiro vai para a mão sem nada ir à mesa: é aqui que o
    // inchaço nasce, e é aqui que ele tem de custar.
    final ex = _excedente(inicial.tamanhoMao + inicial.lixoTamanho, naCompra: true);
    if (ex > 0) f['excedenteMao'] = -ex;
    return Avaliacao.de(f);
  }
}
