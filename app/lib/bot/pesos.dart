// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1.
//
// PESOS E REGRAS ESTRATÉGICAS — CENTRALIZADOS E VERSIONADOS.
//
// Nenhum número mágico de estratégia pode viver espalhado em `mesa.dart` (nem
// em qualquer outro lugar): todo peso da função de utilidade e toda restrição
// dura desta OS estão aqui, num objeto `const` com carimbo de versão.
//
// Duas coisas MUITO diferentes moram neste arquivo, e a separação é proposital:
//
//  1) `PesosHeuristicos` — os pesos da função de utilidade. Mudar um peso muda
//     a PREFERÊNCIA do bot. Nada aqui torna uma jogada legal ou ilegal.
//  2) `RegrasEstrategicas` — as RESTRIÇÕES DURAS aprovadas nesta OS (não
//     descartar curinga, não sujar canastra limpa, etc.). São filtros sobre
//     alternativas que a autoridade canônica já considera legais: o bot decide
//     não usá-las. Continuam sem poder tornar legal o que o motor recusa.
//
// Cada flag de `RegrasEstrategicas` existe também como PONTO DE DESLIGAMENTO:
// o relatório de não-vacuidade desliga uma por vez e mostra o teste
// correspondente caindo. Uma regra que não pode ser desligada é uma regra que
// não pode ser provada.
library;

/// Restrições estratégicas DURAS aprovadas nesta OS. Todas ligadas por padrão.
///
/// Desligar qualquer uma NÃO libera jogada ilegal — apenas devolve ao bot uma
/// alternativa que a autoridade já aceitava e que a política desta OS proíbe.
class RegrasEstrategicas {
  /// §2 — proibido descartar "2" e Joker.
  final bool proibeDescartarCuringa;

  /// §3 — proibido sujar canastra limpa (ou forte potencial de limpa) com
  /// curinga só para baixar mais cartas.
  final bool protegeCanastraLimpa;

  /// §3 — curinga só entra em jogo novo com ganho estratégico claro; uso
  /// gratuito (a combinação fecharia naturalmente) é penalizado com força.
  final bool preservaCuringa;

  /// §2 — o descarte pondera o dano à própria estrutura.
  final bool avaliaDanoEstrutural;

  /// §1 — preservar cartas úteis aos jogos públicos da dupla tem valor.
  final bool preservaCartaDoParceiro;

  /// §2 — evitar entregar extensão/lixo aos jogos públicos adversários.
  final bool evitaAlimentarAdversario;

  /// §4/§5 — o plano de turno é comparado JÁ COM o descarte resultante; uma
  /// baixada legal que obriga um descarte ruim perde para não baixar.
  final bool planoIncluiDescarte;

  /// §6 — não bater/fechar prematuramente prejudicando o parceiro sem ameaça.
  final bool prudenciaBatida;

  /// OS 3 — usar a MEMÓRIA PÚBLICA de descartes do parceiro como evidência
  /// ao escolher o descarte.
  ///
  /// Apesar de morar entre as "restrições duras", esta flag NÃO filtra nada:
  /// ela liga um TERMO da função de utilidade. Está aqui, e não solta em outro
  /// lugar, porque é o interruptor exigido pela OS — desligá-la tem de devolver
  /// a decisão da V1 bit a bit, e é isso que os testes provam.
  ///
  /// DESLIGADA por padrão: a `RegrasEstrategicas()` sem argumentos é a V1.
  final bool usaMemoriaDescarteParceiro;

  const RegrasEstrategicas({
    this.proibeDescartarCuringa = true,
    this.protegeCanastraLimpa = true,
    this.preservaCuringa = true,
    this.avaliaDanoEstrutural = true,
    this.preservaCartaDoParceiro = true,
    this.evitaAlimentarAdversario = true,
    this.planoIncluiDescarte = true,
    this.prudenciaBatida = true,
    this.usaMemoriaDescarteParceiro = false,
  });

  RegrasEstrategicas copyWith({
    bool? proibeDescartarCuringa,
    bool? protegeCanastraLimpa,
    bool? preservaCuringa,
    bool? avaliaDanoEstrutural,
    bool? preservaCartaDoParceiro,
    bool? evitaAlimentarAdversario,
    bool? planoIncluiDescarte,
    bool? prudenciaBatida,
    bool? usaMemoriaDescarteParceiro,
  }) =>
      RegrasEstrategicas(
        proibeDescartarCuringa:
            proibeDescartarCuringa ?? this.proibeDescartarCuringa,
        protegeCanastraLimpa: protegeCanastraLimpa ?? this.protegeCanastraLimpa,
        preservaCuringa: preservaCuringa ?? this.preservaCuringa,
        avaliaDanoEstrutural: avaliaDanoEstrutural ?? this.avaliaDanoEstrutural,
        preservaCartaDoParceiro:
            preservaCartaDoParceiro ?? this.preservaCartaDoParceiro,
        evitaAlimentarAdversario:
            evitaAlimentarAdversario ?? this.evitaAlimentarAdversario,
        planoIncluiDescarte: planoIncluiDescarte ?? this.planoIncluiDescarte,
        prudenciaBatida: prudenciaBatida ?? this.prudenciaBatida,
        usaMemoriaDescarteParceiro:
            usaMemoriaDescarteParceiro ?? this.usaMemoriaDescarteParceiro,
      );
}

/// Pesos da função de utilidade DA DUPLA (não da mão do bot). Todos os valores
/// são positivos; o sinal (prêmio ou custo) está na fórmula do avaliador.
class PesosHeuristicos {
  /// Carimbo de versão (entra no rastro de auditoria da decisão).
  final String versao;

  // ---------- objetivos de rodada ----------
  /// Abrir o jogo da dupla nesta rodada (sem mínimo em disputa).
  final double abertura;

  /// Abrir cumprindo o mínimo de VULNERABILIDADE (o gargalo real da rodada).
  final double aberturaVulneravel;

  /// Zerar a mão pegando o MORTO.
  final double morto;

  /// Bater (encerrar a rodada).
  final double batida;

  /// Bater cedo demais, com o parceiro carregado e sem ameaça adversária.
  /// Precisa superar `batida` — senão a prudência não muda decisão nenhuma.
  final double batidaPrematura;

  // ---------- mesa e mão: MESMA MOEDA (pontos) ----------
  //
  // Os três pesos abaixo existem para comparar coisas comparáveis. Mesa e mão
  // são medidas em PONTOS: a mesa pelo que já vale (cartas + bônus de canastra)
  // mais o potencial não realizado; a mão pelo MESMO potencial, descontado,
  // mais o quanto ela está encaixada. Sem essa moeda única não dá para decidir
  // se baixar compensa — e a primeira calibração, que misturava nível com
  // delta, decidia errado nos dois sentidos (ora não baixava nada, ora parava
  // uma carta antes da canastra).

  /// Por ponto de valor dos jogos da dupla na mesa (cartas + bônus + potencial).
  final double valorMesa;

  /// Por ponto de POTENCIAL de canastra guardado na mão. Menor que `valorMesa`
  /// de propósito: potencial na mão ainda precisa ser comprado E baixado, e na
  /// mesa o parceiro também pode estender.
  final double potencialMao;

  /// Por ponto de LIGAÇÃO da mão (vizinhanças e reserva de curinga).
  final double ligacoesMao;

  /// Por carta de jogo NOVO exposta sem canastra/abertura/morto/batida no plano.
  final double exposicaoSemGanho;

  /// Ganho de comprar um topo que ESTENDE jogo público da dupla (Aberto).
  final double topoUtilAoJogo;

  /// Por ponto de carta morta (deadwood) que sobra na mão.
  final double deadwood;

  /// Por ponto de carta na mão (risco de virar desconto no fim da rodada).
  final double maoResidual;

  /// Tamanho de mão a partir do qual segurar carta passa a pesar contra.
  final int limiarMaoConfortavel;

  /// FOLGA aplicada ao limiar na hora da COMPRA.
  ///
  /// A compra acontece antes da fase de jogo: as cartas que acabaram de entrar
  /// ainda vão passar pelo baixar/estender/descartar deste mesmo turno. Cobrar
  /// o inchaço com o limiar cheio no momento da compra fazia o bot NUNCA pegar
  /// o lixo — medido: o lixo chegou a 42 cartas sem ninguém recolher, e a dupla
  /// morreu de fome de material. O custo continua existindo; ele só é cobrado
  /// com a folga do que o turno ainda vai colocar na mesa.
  final int folgaDeCompra;

  /// Custo QUADRÁTICO por carta acima do limiar: `peso * excesso²`.
  ///
  /// É quadrático de propósito. O valor de estrutura cresce mais ou menos
  /// linearmente com o tamanho da mão, então um custo linear nunca alcança:
  /// o bot fica com 25+ cartas na mão, sem baixar nada, "preservando estrutura"
  /// até o fim da rodada — que é uma forma de sabotagem tão real quanto baixar
  /// tudo. Sendo quadrático, o custo é quase nulo numa mão normal e vira
  /// dominante exatamente quando a mão incha.
  final double excedenteMao;

  // ---------- curinga ----------
  /// Por curinga comprometido numa baixada SEM ganho decisivo.
  final double custoCuringa;

  /// Adicional por curinga GRATUITO — a combinação fecharia sem ele.
  final double custoCuringaGratuito;

  // ---------- descarte ----------
  /// Por ponto de dano estrutural que o descarte causa à própria mão.
  final double danoDescarte;

  /// Por ponto de risco do descarte para os jogos públicos adversários.
  final double riscoDescarte;

  /// Descartar carta que serve aos jogos públicos da própria dupla.
  final double descarteUtilAoParceiro;

  /// Descartar carta ADJACENTE a jogo público da dupla (extensão natural).
  final double descarteAdjacenteAoParceiro;

  /// OS 3 — PRÊMIO por descartar carta que o PARCEIRO já dispensou publicamente
  /// nesta mão (mesmo valor e naipe). É evidência negativa de interesse, não
  /// certeza sobre a mão dele.
  ///
  /// TETO DE CALIBRAÇÃO, e a razão de o número ser pequeno: ele precisa perder
  /// para TODO termo que a §6 põe acima dele. O menor passo não-nulo de
  /// qualquer termo concorrente é `riscoDescarte * 1 = 6` (uma nota de risco
  /// mínima — que qualquer carta de 10 pontos já tem). Um prêmio ≥ 6 seria
  /// capaz de virar uma decisão em que a alternativa é ESTRITAMENTE mais
  /// segura, e isso a OS proíbe. Por isso o valor fica abaixo de 6, e o
  /// efeito é o de um desempate entre alternativas estruturalmente próximas.
  ///
  /// Para comparação, os vizinhos diretos deste termo:
  ///   descarteUtilAoParceiro      34   (carta estende jogo público da dupla)
  ///   descarteAdjacenteAoParceiro 12   (carta encosta em jogo público)
  ///   riscoDescarte * nota        6+   (menor passo de risco)
  ///   danoDescarte * força        2,2 por ponto de estrutura
  final double memoriaDescarteParceiro;

  /// Plano que baixa e deixa o turno SEM descarte legal (beco sem saída do
  /// motor). Pesado de propósito: só compensa quando o ganho é grande demais
  /// para recusar — na prática, a abertura sob mínimo de vulnerabilidade.
  final double turnoSemSaida;

  // ---------- compra ----------
  /// Valor neutro de comprar 1 carta desconhecida do monte (linha de base).
  final double compraMonteBase;

  /// Por carta ENTERRADA que vem junto na compra do lixo (volume ≠ qualidade).
  final double compraLixoVolume;

  /// Por ponto de carta enterrada esperado como peso morto na mão.
  final double compraLixoLastro;

  const PesosHeuristicos({
    this.versao = 'bmv-bot-heuristico-v1',
    this.abertura = 30,
    this.aberturaVulneravel = 140,
    this.morto = 220,
    this.batida = 160,
    this.batidaPrematura = 300,
    this.valorMesa = 0.40,
    this.potencialMao = 0.28,
    this.ligacoesMao = 0.35,
    this.exposicaoSemGanho = 0.4,
    this.topoUtilAoJogo = 8,
    this.deadwood = 0.35,
    this.maoResidual = 0.10,
    this.limiarMaoConfortavel = 15,
    this.folgaDeCompra = 4,
    this.excedenteMao = 4.0,
    this.custoCuringa = 60,
    this.custoCuringaGratuito = 110,
    this.danoDescarte = 2.2,
    this.riscoDescarte = 6.0,
    this.descarteUtilAoParceiro = 34,
    this.descarteAdjacenteAoParceiro = 12,
    this.memoriaDescarteParceiro = 0,
    this.turnoSemSaida = 80,
    this.compraMonteBase = 6,
    this.compraLixoVolume = 3.0,
    this.compraLixoLastro = 0.15,
  });

  /// Cópia com pesos trocados. Existe para a comparação V1 × V2 e para as
  /// provas de reprodução (peso zero tem de devolver a V1 bit a bit) — nunca
  /// para espalhar número de estratégia fora deste arquivo.
  PesosHeuristicos copyWith({
    String? versao,
    double? abertura,
    double? aberturaVulneravel,
    double? morto,
    double? batida,
    double? batidaPrematura,
    double? valorMesa,
    double? potencialMao,
    double? ligacoesMao,
    double? exposicaoSemGanho,
    double? topoUtilAoJogo,
    double? deadwood,
    double? maoResidual,
    int? limiarMaoConfortavel,
    int? folgaDeCompra,
    double? excedenteMao,
    double? custoCuringa,
    double? custoCuringaGratuito,
    double? danoDescarte,
    double? riscoDescarte,
    double? descarteUtilAoParceiro,
    double? descarteAdjacenteAoParceiro,
    double? memoriaDescarteParceiro,
    double? turnoSemSaida,
    double? compraMonteBase,
    double? compraLixoVolume,
    double? compraLixoLastro,
  }) =>
      PesosHeuristicos(
        versao: versao ?? this.versao,
        abertura: abertura ?? this.abertura,
        aberturaVulneravel: aberturaVulneravel ?? this.aberturaVulneravel,
        morto: morto ?? this.morto,
        batida: batida ?? this.batida,
        batidaPrematura: batidaPrematura ?? this.batidaPrematura,
        valorMesa: valorMesa ?? this.valorMesa,
        potencialMao: potencialMao ?? this.potencialMao,
        ligacoesMao: ligacoesMao ?? this.ligacoesMao,
        exposicaoSemGanho: exposicaoSemGanho ?? this.exposicaoSemGanho,
        topoUtilAoJogo: topoUtilAoJogo ?? this.topoUtilAoJogo,
        deadwood: deadwood ?? this.deadwood,
        maoResidual: maoResidual ?? this.maoResidual,
        limiarMaoConfortavel:
            limiarMaoConfortavel ?? this.limiarMaoConfortavel,
        folgaDeCompra: folgaDeCompra ?? this.folgaDeCompra,
        excedenteMao: excedenteMao ?? this.excedenteMao,
        custoCuringa: custoCuringa ?? this.custoCuringa,
        custoCuringaGratuito:
            custoCuringaGratuito ?? this.custoCuringaGratuito,
        danoDescarte: danoDescarte ?? this.danoDescarte,
        riscoDescarte: riscoDescarte ?? this.riscoDescarte,
        descarteUtilAoParceiro:
            descarteUtilAoParceiro ?? this.descarteUtilAoParceiro,
        descarteAdjacenteAoParceiro:
            descarteAdjacenteAoParceiro ?? this.descarteAdjacenteAoParceiro,
        memoriaDescarteParceiro:
            memoriaDescarteParceiro ?? this.memoriaDescarteParceiro,
        turnoSemSaida: turnoSemSaida ?? this.turnoSemSaida,
        compraMonteBase: compraMonteBase ?? this.compraMonteBase,
        compraLixoVolume: compraLixoVolume ?? this.compraLixoVolume,
        compraLixoLastro: compraLixoLastro ?? this.compraLixoLastro,
      );
}

/// Configuração completa da camada estratégica: pesos + restrições + limites de
/// busca + semente determinística.
class ConfiguracaoBot {
  final PesosHeuristicos pesos;
  final RegrasEstrategicas regras;

  /// Semente. NÃO sorteia carta e NÃO altera legalidade: entra apenas no
  /// desempate determinístico entre planos de score idêntico. Mesma mesa +
  /// mesma configuração + mesma semente => mesma decisão, sempre.
  final int seed;

  /// Orçamento de nós da busca de planos. Estourar NÃO é silencioso: a decisão
  /// carrega `Razao.buscaTruncada` no rastro.
  final int orcamentoBusca;

  /// Quantas baixadas candidatas seguem para a avaliação COMPLETA (com o
  /// descarte simulado). O corte é por pré-score e também vira rastro.
  final int maxBaixadasAvaliadas;

  /// Quantos DESCARTES são expandidos por baixada candidata. Numa mão grande o
  /// produto (baixadas × descartes) é o que domina o custo do turno: sem este
  /// corte, um turno chegou a 2 segundos numa mão de 21 cartas. O ranking do
  /// corte usa os MESMOS sinais da pontuação final (dano e risco), então o que
  /// cai fora é a cauda, não o candidato certo — e o corte vira rastro.
  final int maxDescartesPorBaixada;

  const ConfiguracaoBot({
    this.pesos = const PesosHeuristicos(),
    this.regras = const RegrasEstrategicas(),
    this.seed = 0,
    this.orcamentoBusca = 6000,
    this.maxBaixadasAvaliadas = 64,
    this.maxDescartesPorBaixada = 10,
  });

  ConfiguracaoBot comRegras(RegrasEstrategicas r) => ConfiguracaoBot(
        pesos: pesos,
        regras: r,
        seed: seed,
        orcamentoBusca: orcamentoBusca,
        maxBaixadasAvaliadas: maxBaixadasAvaliadas,
        maxDescartesPorBaixada: maxDescartesPorBaixada,
      );

  /// Cópia com PESOS trocados (mesmas regras, mesma semente, mesmo orçamento).
  ConfiguracaoBot comPesos(PesosHeuristicos ps) => ConfiguracaoBot(
        pesos: ps,
        regras: regras,
        seed: seed,
        orcamentoBusca: orcamentoBusca,
        maxBaixadasAvaliadas: maxBaixadasAvaliadas,
        maxDescartesPorBaixada: maxDescartesPorBaixada,
      );

  /// Configuração aprovada na OS de Inteligência do Bot V1.
  ///
  /// PRESERVADA INTACTA. Ela é a linha de base de toda comparação e o caminho
  /// de rollback: nenhum peso e nenhuma regra dela mudaram nesta OS — o que a
  /// V2 acrescenta vem de campos NOVOS, com padrão neutro (flag desligada,
  /// peso zero), de modo que `v1` continua produzindo a mesma decisão de antes.
  static const v1 = ConfiguracaoBot();

  /// OS 3 — configuração com a MEMÓRIA PÚBLICA DE DESCARTES ligada.
  ///
  /// Difere da V1 em exatamente duas coisas: a flag
  /// `usaMemoriaDescarteParceiro` e o peso `memoriaDescarteParceiro`. Todo o
  /// resto — pesos, orçamento, largura de busca, semente e política de
  /// desempate — é literalmente o mesmo, para que a comparação meça o SINAL e
  /// não uma segunda mudança embutida.
  ///
  /// O valor 4 é o resultado da calibração registrada no relatório: abaixo do
  /// teto de 6 imposto pela precedência (§6) e alto o bastante para virar
  /// decisões entre alternativas estruturalmente próximas.
  static const v2 = ConfiguracaoBot(
    pesos: PesosHeuristicos(
      versao: 'bmv-bot-heuristico-v2-descartes-publicos',
      memoriaDescarteParceiro: 4,
    ),
    regras: RegrasEstrategicas(usaMemoriaDescarteParceiro: true),
  );
}
