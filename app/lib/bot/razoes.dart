// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1.
//
// REASON CODES: o vocabulário fechado com que a camada estratégica explica, por
// escrito e de forma testável, POR QUE uma alternativa venceu. Nenhuma decisão
// do bot sai daqui sem carregar um destes códigos.
//
// Estes códigos NÃO são regra: não autorizam nem proíbem jogada nenhuma. Eles
// descrevem a INTENÇÃO escolhida; a legalidade continua sendo decidida pela
// autoridade canônica (`rules/gerador/gerador.dart`) e aplicada por ela.
library;

/// Códigos de razão da decisão estratégica (vocabulário fechado e estável).
class Razao {
  Razao._();

  // ---------- fase de COMPRA ----------
  /// Comprou o lixo porque o uso obrigatório do topo põe estrutura na mesa.
  static const compraLixoEstrutura = 'COMPRA_LIXO_ESTRUTURA';

  /// Comprou o lixo porque o topo casa com a mão/mesa e o volume compensa.
  static const compraLixoVolume = 'COMPRA_LIXO_VOLUME';

  /// Comprou o monte: nenhum uso do lixo compensou o custo de recolhê-lo.
  static const compraMonte = 'COMPRA_MONTE';

  /// Comprou o monte porque o lixo não tinha uso legal do topo (Fechado/STBL).
  static const compraMonteSemUsoDoTopo = 'COMPRA_MONTE_SEM_USO_DO_TOPO';

  // ---------- fase de JOGO ----------
  /// Baixou porque a abertura VULNERÁVEL exigia o mínimo e este conjunto atinge.
  static const baixaAberturaMinima = 'BAIXA_ABERTURA_MINIMA';

  /// Baixou porque abrir agora vale mais do que segurar (sem mínimo em jogo).
  static const baixaAbertura = 'BAIXA_ABERTURA';

  /// Baixou/estendeu porque o ganho líquido supera o dano estrutural.
  static const baixaGanhoLiquido = 'BAIXA_GANHO_LIQUIDO';

  /// Baixou porque fecha canastra.
  static const baixaCanastra = 'BAIXA_CANASTRA';

  /// Baixou zerando a mão para PEGAR O MORTO.
  static const baixaMorto = 'BAIXA_MORTO';

  /// Baixou zerando a mão para BATER.
  static const baixaBatida = 'BAIXA_BATIDA';

  /// NÃO baixou: preservar a estrutura da mão vale mais que a baixada legal.
  static const preservaEstrutura = 'PRESERVA_ESTRUTURA';

  /// NÃO baixou/bateu: o parceiro ainda precisa de tempo e não há ameaça.
  static const adiaPorParceiro = 'ADIA_POR_PARCEIRO';

  /// Reavaliou o turno do zero depois de a mão trocar (morto recém-pego).
  static const reavaliaAposMorto = 'REAVALIA_APOS_MORTO';

  // ---------- DESCARTE ----------
  /// Descartou a carta de MENOR dano estrutural entre as legais e seguras.
  static const descarteMenorDano = 'DESCARTE_MENOR_DANO';

  /// Descartou evitando alimentar jogo público adversário.
  static const descarteSeguro = 'DESCARTE_SEGURO';

  /// Descartou preservando carta útil aos jogos públicos da dupla.
  static const descartePreservaParceiro = 'DESCARTE_PRESERVA_PARCEIRO';

  /// OS 3 — descartou uma carta que o PARCEIRO já dispensou publicamente nesta
  /// mão, e essa evidência foi DECISIVA: sem ela, outra alternativa venceria.
  ///
  /// A condição "decisiva" é verificada, não presumida: o executor refaz o
  /// argmax descontando a contribuição da memória e compara os vencedores. Uma
  /// razão emitida sempre que o sinal existisse seria ruído — diria "isto pesou"
  /// nos casos em que o sinal não mudou nada.
  static const descarteMemoriaParceiro = 'DESCARTE_MEMORIA_PARCEIRO';

  // ---------- IMPASSES (nunca silenciosos) ----------
  /// TODAS as cartas legais de descarte são curinga. A política desta OS proíbe
  /// descartar 2/Joker; o estado é excepcional e vai para decisão da Sônia.
  /// Ver `RELATORIO-BOT-IA-V1.md` §"Impasse documentado".
  static const impasseDescarteSoCuringa = 'IMPASSE_DESCARTE_SO_CURINGA';

  /// A busca de planos bateu o orçamento configurado. NUNCA é silencioso: quem
  /// consome vê este código no rastro e sabe que a cobertura foi parcial.
  static const buscaTruncada = 'BUSCA_TRUNCADA';

  /// Nenhum plano legal foi encontrado nesta fase (a autoridade decide o resto).
  static const semPlanoLegal = 'SEM_PLANO_LEGAL';

  /// OS 4 — o ORCAMENTO determinístico acabou antes de existir um plano
  /// completo avaliado, e a decisão veio do fallback legal.
  ///
  /// É um código de PRIMEIRA classe, e não um detalhe escondido no rastro:
  /// quem lê a decisão precisa saber que ela não foi escolhida por
  /// preferência estratégica, e sim porque a busca foi cortada. Esconder isso
  /// faria a telemetria dizer que o bot preferiu o que ele apenas aceitou.
  static const fallbackOrcamento = 'FALLBACK_ORCAMENTO';
}
