// mesa.dart — MESA DE JOGO + MOTOR (Jogo), separado do main.dart em 30/07/2026.
// Aqui vivem: o MOTOR (Jogo, Carta, regras, robô) e a UI da MESA (MesaScreen).
// Objetivo: o Codex mexe no visual da mesa AQUI; o main.dart (online, rotas e as
// outras telas) fica intocado. Acaba a colisão dos dois no mesmo arquivo.
// main.dart importa este arquivo e usa MesaScreen / MesaVariant.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'screens/resultado_partida_screen.dart';
// C9-D — camada de costura da AUTORIDADE canônica (atrás da flag; OFF por padrão).
import 'motor/motor_config.dart';
import 'motor/autoridade_canonica.dart';
// C10 — costura da classificação/pontuação canônicas no consumidor real.
import 'motor/pontuacao_costura.dart';
import 'motor/projecao_estado.dart' show paraCanonico;
// C10 (rev.1) — derivação combinatória FORA do isolate de UI.
import 'motor/derivacao_fora_do_frame.dart';
import 'rules/acoes.dart';
import 'rules/estado.dart' show EstadoJogo;
import 'rules/rule_spec.dart';
// OS BOT-IA V1 — camada ESTRATÉGICA do robô. Ela observa, gera alternativas,
// pontua e escolhe uma INTENÇÃO; quem valida e aplica continua sendo a
// autoridade canônica, pelas mesmas entradas do humano. Ver `lib/bot/`.
import 'bot/executor_bot.dart';
import 'bot/pesos.dart';

// ===================== MESA DE JOGO — VERDE + MOTOR (fatia 2) =====================
// Visual: porte fiel de claude/mesa-verde-APROVADA.html (aprovado pela Sônia).
// Lógica: motor portado do motor testado (carta.js/canastra.js/jogo.js), modalidade ABERTO.
//   Fatia 1: baralho, distribuição, comprar do monte, descartar, passar a vez, robôs simples.
//   Fatia 2 (esta): BAIXAR jogos, ESTENDER, canastras (limpa/suja/500), BATER — jogos reais na mesa.
//   Interação 100% no toque: seleciona cartas -> toca na área NÓS (baixar) ou num jogo (estender);
//   seleciona 1 carta -> toca no lixo (descartar). Pegar-lixo e IA que baixa ficam pra fatia 3.

// ---------- MODELO ----------
class Carta {
  final String id;
  final String? naipe; // 'copas','ouros','paus','espadas' | null (joker)
  final String valor; // 'A'..'K' | 'JOKER'
  final bool ehCoringa;
  const Carta(this.id, this.naipe, this.valor, this.ehCoringa);
}

const _naipeSimb = {'copas': '♥', 'ouros': '♦', 'paus': '♣', 'espadas': '♠'};
bool _cartaVermelha(Carta c) => c.naipe == 'copas' || c.naipe == 'ouros';
String _cartaSimb(Carta c) => c.ehCoringa && c.valor == 'JOKER' ? '★' : (_naipeSimb[c.naipe] ?? '');
String _cartaRotulo(Carta c) => c.valor == 'JOKER' ? '★' : c.valor;

// ===== AUDITORIA DE REGRAS (fase diagnóstica) — liga logs [AUD ...] no console.
// Só instrumentação/observação; NÃO altera regras nem layout.
// DESLIGADA por padrão; liga com --dart-define=AUD_REGRAS=true.
const bool kAuditoriaRegras = bool.fromEnvironment('AUD_REGRAS');

// imagem real da carta (baralho enviado pela Sônia). JOKER alterna entre os dois
// desenhos de curinga (usando o id pra dar variedade); dorso do baralho pro monte/mortos.
const String _dorsoAsset = 'assets/baralho/dorso.webp';
String _cartaAsset(Carta c) {
  if (c.valor == 'JOKER') {
    final h = c.id.codeUnits.fold<int>(0, (a, b) => a + b);
    return h.isEven ? 'assets/baralho/joker.webp' : 'assets/baralho/joker2.webp';
  }
  return 'assets/baralho/${c.naipe}_${c.valor}.webp';
}

// ---------- MOTOR ----------
class Jogo {
  final Random _rnd; // semeável p/ testes determinísticos (produção = sem seed)
  int _cont = 0;
  static const _naipes = ['copas', 'ouros', 'paus', 'espadas'];
  static const _valores = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  static const _ordem = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  // Ordem SÓ pra exibir a mão (crescente, A no fim). Não afeta validação de sequência.
  static const _ordemVisualMao = ['2','3','4','5','6','7','8','9','10','J','Q','K','A'];
  static const cartasPorMao = 11;
  static const cartasPorMorto = 11;

  List<List<Carta>> maos = [[], [], [], []];
  List<Carta> monte = [];
  List<List<Carta>> mortos = [];
  List<Carta> lixo = [];
  Map<String, bool> mortoPego = {'nos': false, 'eles': false};
  Map<String, List<List<Carta>>> jogosDupla = {'nos': [], 'eles': []};
  int vez = 0;
  bool jaComprou = false;
  bool rodadaEncerrada = false;
  // Fechado/SBTL: ao pegar o lixo, o id da carta do TOPO que o jogador é
  // OBRIGADO a usar (baixar/estender) antes de descartar. null = sem pendência.
  String? lixoTopoObrigatorio;
  // §5.2 ABERTO: quem compra um lixo de UMA carta só não pode devolver essa
  // mesma carta como descarte no mesmo turno (anti "turno nulo").
  //
  // OS CANONIZAÇÃO DO LIXO V1 — a AUTORIDADE desta regra é
  // `EstadoJogo.lixoUnicoCompradoId` (rules/estado.dart), decidida pelo gerador
  // único. Este campo continua existindo por dois motivos, nenhum deles
  // "segunda fonte de verdade": (1) o motor LEGADO de rollback precisa do seu
  // próprio slot; (2) sob autoridade canônica ele é PROJEÇÃO — `aplicarEmJogo`
  // o escreve a partir do estado canônico, como já fazia com a fase.
  String? _lixoUnicoCompradoId;
  // §8.1: mortos convertidos em monte nesta rodada. É EVENTO DE BARALHO, e
  // NÃO afeta a pontuação: a dupla que ficou sem morto paga o -100 assim mesmo
  // (correção de regra da revisão do C10 parte 2 — antes isentava).
  int _mortosConvertidos = 0;
  // §3.2: quem inicia a rodada — sorteado na 1ª, rotaciona nas seguintes.
  int _iniciadorRodada = -1;
  // BLOQUEIO CRÍTICO (doc 31/07): integridade do baralho. null = íntegro;
  // senão, código auditável — e o motor RECUSA novas jogadas (nunca "conserta"
  // inventando carta).
  String? integridadeErro;
  // Modalidade da mesa: 'ABERTO' | 'FECHADO' | 'SBTL'. Governa a trava do lixo,
  // a batida (limpa obrigatória ou não) e, futuramente, trincas. Setada pela UI.
  String modalidade = 'ABERTO';
  String? duplaQueBateu;
  int? assentoQueBateu;
  int rodada = 0;

  // ===== FATIA 4: PLACAR / FIM DE RODADA / FIM DE PARTIDA =====
  int metaPontos = 1500;
  Map<String, int> placar = {'nos': 0, 'eles': 0};
  bool encerrada = false; // partida acabou (bateu a meta)
  Map<String, dynamic>? pontosRodada; // detalhamento da última rodada contada
  bool _rodadaContada = false;

  // ===== VULNERABILIDADE (regras seção 11) — mínimo de pontos p/ a 1ª baixada =====
  // Derivada do placar ACUMULADO da dupla, reavaliada no início de cada rodada.
  // < 1500 pts: livre. 1ª rodada a 1500+ → mínimo 75. 2ª rodada seguida a 1500+ → 90 (teto).
  // Só bloqueia a PRIMEIRA baixada da dupla na rodada; depois de aberta, os turnos são livres.
  // Vulnerável a partir de metaPontos/2 (750 na meta 1500; 1500 na meta 3000).
  int get _limiteVulneravel => metaPontos ~/ 2;
  Map<String, int> rodadasVulneravel = {'nos': 0, 'eles': 0};
  Map<String, bool> primeiraBaixadaFeita = {'nos': false, 'eles': false};

  // Mínimo de pontos que a 1ª baixada da dupla precisa somar nesta rodada.
  // 0 = sem restrição (dupla não vulnerável, ou já abriu jogo nesta rodada).
  // 1ª rodada vulnerável → 75; a partir da 2ª seguida → 90 (decisão da Sônia).
  int minimoParaDescer(String dupla) {
    if (primeiraBaixadaFeita[dupla] ?? false) return 0;
    final r = rodadasVulneravel[dupla] ?? 0;
    if (r <= 0) return 0;
    return r == 1 ? 75 : 90;
  }

  final List<String> apelidos;
  final List<String> avatares;
  final List<String> mascotes;

  // ===== C9-D — AUTORIDADE canônica atrás da flag =====
  /// Flag de AUTORIDADE (e sombra). PADRÃO OFF => o fluxo permanece 100% legado,
  /// sem alterar resultado observável, pontuação, turno, lixo, morto, jogos,
  /// eventos ou sidecars. Só com `canonicoAtivo=true` o caminho canônico assume.
  final MotorConfig motorConfig;

  /// Injeção do projetor SÓ para exercitar a FALHA técnica de projeção nos
  /// testes (null => a autoridade usa `paraCanonico`). Nunca setado em produção.
  Projetor? projetorAutoridadeTest;

  /// Telemetria/diagnóstico da última FALHA TÉCNICA (costura/projeção/
  /// transporte). NÃO é game-state (fora da projeção/envelope); só registra
  /// evidência quando a falha técnica ocorre. Null caso contrário.
  ///
  /// C10 — o nome antigo era `ultimoFallbackTecnico`: sob autoridade única NÃO
  /// existe mais fallback nenhum, nem semântico nem técnico. A evidência
  /// continua sendo registrada; o que sumiu é a rota para o legado.
  Map<String, dynamic>? ultimaFalhaTecnica;

  /// C10 (rev.2) — a mesa está OCUPADA por uma derivação combinatória em curso
  /// ou por uma escolha humana pendente (o seletor de uso do topo / de partição
  /// da seleção). Enquanto estiver ligada, NENHUMA jogada é aceita: o estado que
  /// o jogador está vendo — e sobre o qual os candidatos foram derivados — não
  /// pode mudar por baixo dele.
  ///
  /// A trava mora AQUI, e não só na tela, de propósito: uma guarda de UI depende
  /// de todo ponto de entrada lembrar de checá-la (foi assim que `_estender`
  /// ficou de fora na rev.1). No modelo, é invariante — vale para qualquer
  /// consumidor, atual ou futuro.
  ///
  /// Quem deriva é responsável por LIBERAR antes de aplicar a jogada escolhida:
  /// terminada a escolha, a janela de risco acabou e a transação é síncrona.
  bool mesaOcupadaPorDerivacao = false;

  /// Recusa padrão enquanto a mesa está ocupada (null = livre).
  Map<String, dynamic>? get _recusaSeOcupada => mesaOcupadaPorDerivacao
      ? const {
          'ok': false,
          'erro': 'aguarde: a mesa está conferindo as jogadas possíveis.',
          'ocupada': true,
        }
      : null;

  /// C10 (rev.3) — PAUSA TÉCNICA do fluxo AUTOMÁTICO. Ligada quando a jogada
  /// automática por tempo esgotado aborta por falha técnica; a partir daí
  /// nenhuma nova jogada automática começa.
  ///
  /// Existe porque `PARTIDA PAUSADA` era só um texto: o `Timer.periodic` seguia
  /// vivo com `_turnSeconds == 0` e o tick seguinte tentava tudo de novo — nova
  /// compra, novo descarte, nova falha técnica. A pausa precisava ser de ESTADO,
  /// não de mensagem.
  ///
  /// Escopo deliberado: tranca só o caminho AUTOMÁTICO. O jogador continua livre
  /// para agir — a falha foi do piloto automático, e decidir tentar de novo na
  /// mão é escolha humana. Nada aqui avança turno nem inventa recuperação.
  bool pausadaPorFalhaTecnica = false;

  /// C10 (rev.1) — CONTADOR monotônico de falhas técnicas. `ultimaFalhaTecnica`
  /// sozinha não distingue "falhou agora" de "falhou há três jogadas": quem
  /// precisa reagir a uma falha NOVA compara este contador antes e depois. É o
  /// que torna o fail-closed do robô verificável em vez de heurístico.
  int falhasTecnicas = 0;

  /// OS BOT-IA V1 — configuração da camada estratégica do robô (pesos +
  /// restrições + semente). Trocá-la muda a PREFERÊNCIA do bot e nada mais: a
  /// legalidade continua sendo decidida pela autoridade canônica. Existe para o
  /// relatório de NÃO-VACUIDADE — desligar uma regra por vez e ver o teste
  /// correspondente cair.
  ConfiguracaoBot configuracaoBot = ConfiguracaoBot.v1;

  /// OS BOT-IA V1 — rastro AUDITÁVEL da última decisão estratégica: candidatos
  /// considerados, features, score e o reasonCode que venceu (§8).
  Map<String, dynamic>? ultimaDecisaoBot;

  /// OS BOT-IA V1 — IMPASSES estratégicos registrados nesta partida. Hoje só um
  /// caso chega aqui: a mão em que TODA carta legalmente descartável é curinga,
  /// contra a política do §2. Fica registrado de propósito — a OS proíbe criar
  /// exceção silenciosa, e este campo é o que torna o caso visível.
  final List<Map<String, dynamic>> impassesEstrategicos = [];

  Jogo(this.apelidos, this.avatares, this.mascotes,
      {int? seed, this.motorConfig = const MotorConfig()})
      : _rnd = seed == null ? Random() : Random(seed) {
    _distribuir();
  }

  /// Roteia a jogada pela autoridade canônica (fronteira atômica). Usa o
  /// projetor injetado (testes) ou `paraCanonico` (produção).
  ResultadoAutoridade _rodarAutoridade(int assento, List<Acao> acoes) =>
      projetorAutoridadeTest == null
          ? aplicarComAutoridade(this, assento, acoes)
          : aplicarComAutoridade(this, assento, acoes,
              projetar: projetorAutoridadeTest!);

  /// C10 — FAIL-CLOSED. Registra a evidência da falha TÉCNICA e devolve a
  /// mensagem de recusa. Sob autoridade única, falha técnica NÃO roteia para o
  /// legado: a jogada é RECUSADA com o `Jogo` intacto (a autoridade só falha
  /// antes de qualquer efeito observável) e a evidência fica em
  /// `ultimaFalhaTecnica` para telemetria/Replay. Recusa de REGRA nunca passa
  /// por aqui — ela tem o seu próprio desfecho.
  String _falharFechado(String metodo, ResultadoAutoridade r) {
    falhasTecnicas++;
    ultimaFalhaTecnica = {
      'metodo': metodo,
      'motivo': r.motivo,
      'evidencia': r.evidencia,
    };
    return 'falha técnica do motor em $metodo: a jogada foi recusada e nada '
        'foi alterado (${r.motivo ?? 'sem motivo'}).';
  }

  // ===================================================================
  // C9-B COSTURA (seam) — acesso MÍNIMO à projeção Jogo <-> EstadoJogo
  // (motor/projecao_estado.dart). SÓ leitura/escrita direta de estado;
  // NENHUMA regra aqui, NENHUM método existente alterado. Inventário desta
  // costura (aditiva):
  //   1) construtor `Jogo.paraCostura` — instância VAZIA (não distribui);
  //   2) acessores dos 5 campos operacionais PRIVADOS (os demais campos do
  //      envelope já são públicos). Autoridade OFF por padrão; comportamento
  //      legado 100% preservado (nada abaixo é chamado no fluxo antigo).
  // ===================================================================

  /// Instância VAZIA (sem `_distribuir`) para a projeção/costura preencher o
  /// estado a partir de um `EstadoJogo`. Não sorteia cartas; não roda regra.
  Jogo.paraCostura(
      {List<String>? apelidos,
      List<String>? avatares,
      List<String>? mascotes,
      this.motorConfig = const MotorConfig()})
      : apelidos = apelidos ?? const <String>[],
        avatares = avatares ?? const <String>[],
        mascotes = mascotes ?? const <String>[],
        _rnd = Random(0);

  int get costuraCont => _cont;
  set costuraCont(int v) => _cont = v;
  String? get costuraLixoUnicoCompradoId => _lixoUnicoCompradoId;
  set costuraLixoUnicoCompradoId(String? v) => _lixoUnicoCompradoId = v;
  int get costuraMortosConvertidos => _mortosConvertidos;
  set costuraMortosConvertidos(int v) => _mortosConvertidos = v;
  int get costuraIniciadorRodada => _iniciadorRodada;
  set costuraIniciadorRodada(int v) => _iniciadorRodada = v;
  bool get costuraRodadaContada => _rodadaContada;
  set costuraRodadaContada(bool v) => _rodadaContada = v;

  // C9-B-fix — ESTADO DE TRANSPORTE mínimo da FASE canônica (compra | jogo |
  // mortoPendente). O legado só distingue 2 estados de turno (jaComprou), então
  // `mortoPendente` (estado semântico real do RulesEngine, exigido por
  // PegarMorto(viaDescarte)) seria perdido no round-trip. Este slot carrega a
  // fase EXATA através da costura. NÃO é regra: nenhum método legado lê/escreve
  // este campo; o fluxo OFF ignora-o por completo. `null` = sem transporte
  // (snapshot legado puro; a projeção então deriva a fase de jaComprou).
  String? _costuraFaseCanonica;
  String? get costuraFaseCanonica => _costuraFaseCanonica;
  set costuraFaseCanonica(String? v) => _costuraFaseCanonica = v;

  String _duplaKey(int a) => a % 2 == 0 ? 'nos' : 'eles';
  Carta? get lixoTopo => lixo.isEmpty ? null : lixo.last;
  bool get suaVez => vez == 0;
  String _novoId() => 'c${++_cont}';

  List<Carta> _gerarBaralho() {
    final cs = <Carta>[];
    for (var b = 0; b < 2; b++) {
      for (final n in _naipes) {
        for (final v in _valores) {
          cs.add(Carta(_novoId(), n, v, v == '2'));
        }
      }
      // 2 curingões (JOKER) por baralho → 4 no total. Perfil BMV_STANDARD_108:
      // 108 cartas jogáveis nas TRÊS modalidades (Aberto/Fechado/STBL).
      cs.add(Carta(_novoId(), null, 'JOKER', true));
      cs.add(Carta(_novoId(), null, 'JOKER', true));
    }
    return cs;
  }

  void _embaralhar(List<Carta> cs) {
    for (var i = cs.length - 1; i > 0; i--) {
      final j = _rnd.nextInt(i + 1);
      final t = cs[i]; cs[i] = cs[j]; cs[j] = t;
    }
  }

  List<Carta> _tirar(List<Carta> pool, int n) {
    final out = pool.sublist(0, n);
    pool.removeRange(0, n);
    return out;
  }

  void _distribuir() {
    final pool = _gerarBaralho();
    _embaralhar(pool);
    maos = [for (var a = 0; a < 4; a++) _tirar(pool, cartasPorMao)];
    mortos = [_tirar(pool, cartasPorMorto), _tirar(pool, cartasPorMorto)];
    monte = pool;
    lixo = [];
    mortoPego = {'nos': false, 'eles': false};
    jogosDupla = {'nos': [], 'eles': []};
    // §3.2: sorteia quem começa na 1ª rodada; nas seguintes, rotaciona.
    _iniciadorRodada =
        _iniciadorRodada < 0 ? _rnd.nextInt(4) : (_iniciadorRodada + 1) % 4;
    vez = _iniciadorRodada;
    jaComprou = false; rodadaEncerrada = false; duplaQueBateu = null; assentoQueBateu = null; rodada += 1;
    _rodadaContada = false; pontosRodada = null;
    _mortosConvertidos = 0;
    lixoTopoObrigatorio = null;
    _lixoUnicoCompradoId = null;
    // Reavalia a vulnerabilidade da rodada que começa, a partir do placar acumulado.
    for (final d in ['nos', 'eles']) {
      if (placar[d]! >= _limiteVulneravel) {
        rodadasVulneravel[d] = (rodadasVulneravel[d] ?? 0) + 1;
      } else {
        rodadasVulneravel[d] = 0;
      }
      primeiraBaixadaFeita[d] = false;
    }
    ordenar(0); // mão do jogador já começa organizada
    auditarIntegridade(); // auditoria pós-distribuição (invariantes globais)
  }

  // ===== AUDITORIA DE INTEGRIDADE DO BARALHO (BLOQUEIO CRÍTICO, doc 31/07) =====
  // Invariantes: 108 cartas no total; nenhum id em duas zonas; nenhum id criado
  // ou sumido; máx. 2 cópias de cada valor+naipe (4 Jokers); toda carta em
  // exatamente uma zona. Cartas "virt_" (desenho do coringa) NUNCA entram aqui.
  Map<String, List<Carta>> _zonas() => {
        'monte': monte,
        'lixo': lixo,
        for (var i = 0; i < mortos.length; i++) 'morto${i + 1}': mortos[i],
        for (var a = 0; a < 4; a++) 'mao$a': maos[a],
        'jogosNos': [for (final j in jogosDupla['nos']!) ...j],
        'jogosEles': [for (final j in jogosDupla['eles']!) ...j],
      };

  /// Valida os invariantes globais após cada mutação. Se algo estiver
  /// impossível, grava o código em [integridadeErro] e o jogo bloqueia
  /// novas jogadas (preserva o estado pra auditoria — não inventa carta).
  bool auditarIntegridade() {
    final vistos = <String, String>{}; // cardId -> zona
    final porValorNaipe = <String, int>{};
    var total = 0;
    for (final e in _zonas().entries) {
      for (final c in e.value) {
        total++;
        final zonaAnterior = vistos[c.id];
        if (zonaAnterior != null) {
          integridadeErro =
              'CARD_PRESENT_IN_MULTIPLE_ZONES: ${c.id} (${_cartaRotulo(c)}) em $zonaAnterior e ${e.key}';
          return false;
        }
        vistos[c.id] = e.key;
        if (c.id.startsWith('virt_')) {
          integridadeErro = 'VIRTUAL_CARD_IN_STATE: ${c.id} em ${e.key}';
          return false;
        }
        final chave = '${c.naipe ?? 'JOKER'}:${c.valor}';
        final n = (porValorNaipe[chave] ?? 0) + 1;
        porValorNaipe[chave] = n;
        final limite = c.valor == 'JOKER' ? 4 : 2;
        if (n > limite) {
          integridadeErro =
              'DUPLICATE_RANK_SUIT_OVERFLOW: $chave x$n (última em ${e.key})';
          return false;
        }
      }
    }
    if (total != 108) {
      integridadeErro = 'DECK_TOTAL_MISMATCH: $total cartas (esperado 108) · ${contagemPorZona()}';
      return false;
    }
    integridadeErro = null;
    return true;
  }

  /// Contagem de cartas por zona (relatório de teste/telemetria).
  String contagemPorZona() =>
      _zonas().entries.map((e) => '${e.key}=${e.value.length}').join(' · ');

  // ===== PONTUAÇÃO (porte fiel de motor/jogo.js: pontuarDuplaJogo + contarPontos) =====
  // canastra: as_a_as=1000, de_500=500, limpa=200, suja=100; + cartas baixadas;
  // + bônus de batida (100); − cartas na mão; − morto não pego (−100, só se ALGUÉM pegou).
  Map<String, dynamic> _pontuarDupla(String dupla,
      {required bool bateu, required bool mortoPegoDupla, required int cartasNaMao, required bool algumPegouMorto}) {
    int pontosCanastras = 0, pontosCartas = 0;
    final det = {'asAas': 0, 'de500': 0, 'limpas': 0, 'sujas': 0, 'baixadas': 0};
    for (final meld in jogosDupla[dupla]!) {
      if (meld.length >= 7) {
        final res = _validarJogoMesa(meld); // trinca-canastra pontua no Fechado
        if (res['valido'] == true) {
          switch (res['tipo']) {
            case 'as_a_as': pontosCanastras += 1000; det['asAas'] = det['asAas']! + 1; break;
            case 'de_500': pontosCanastras += 500; det['de500'] = det['de500']! + 1; break;
            case 'limpa': pontosCanastras += 200; det['limpas'] = det['limpas']! + 1; break;
            case 'suja': pontosCanastras += 100; det['sujas'] = det['sujas']! + 1; break;
          }
        }
      }
      for (final c in meld) pontosCartas += _pontos(c);
    }
    det['baixadas'] = pontosCartas;
    final bonusBatida = bateu ? 100 : 0;
    // C10 (rev.1): a conversão §8.1 NÃO isenta ninguém. Antes havia aqui um
    // `_mortosConvertidos == 0` que suprimia a penalidade — mesmo defeito
    // corrigido no canônico. O ramo legado passa a cobrar igual, para o
    // rollback não aplicar uma regra que a direção já rejeitou.
    final penalidadeMorto =
        (!mortoPegoDupla && algumPegouMorto) ? -100 : 0;
    final descontoMao = -cartasNaMao;
    final total = pontosCanastras + pontosCartas + bonusBatida + descontoMao + penalidadeMorto;
    return {'total': total, 'canastras': pontosCanastras, 'bonusBatida': bonusBatida,
      'penalidadeMorto': penalidadeMorto, 'descontoMao': descontoMao, 'detalhe': det};
  }

  // Placar em tempo real (somente exibição): pontos já garantidos na mesa nesta
  // rodada = canastras + cartas baixadas da dupla. NÃO altera a contagem oficial
  // de fim de rodada (bônus de batida, cartas na mão e morto entram só no final).
  int pontosMesaAoVivo(String dupla) {
    // C10 — mesma autoridade do fim de rodada: o número exibido durante a
    // rodada não pode discordar do número que será contado no final.
    if (motorConfig.canonicoAtivo) {
      return pontosMesaCanonico(jogosDupla[dupla]!, specCanonica);
    }
    int p = 0;
    for (final meld in jogosDupla[dupla]!) {
      if (meld.length >= 7) {
        final res = _validarJogoMesa(meld);
        if (res['valido'] == true) {
          switch (res['tipo']) {
            case 'as_a_as': p += 1000; break;
            case 'de_500': p += 500; break;
            case 'limpa': p += 200; break;
            case 'suja': p += 100; break;
          }
        }
      }
      for (final c in meld) p += _pontos(c);
    }
    return p;
  }

  // ===================== AUDITORIA / INSTRUMENTAÇÃO (só leitura) =====================
  // Invariante P0: TODO meld ARMAZENADO na mesa precisa passar no validador oficial.
  // Devolve a descrição de cada meld ilegal encontrado (vazio = mesa 100% legal).
  // Não altera estado nem comportamento — serve para provar estado × render.
  List<String> auditarMeldsArmazenados() {
    final falhas = <String>[];
    for (final dupla in const ['nos', 'eles']) {
      final jogos = jogosDupla[dupla]!;
      for (var i = 0; i < jogos.length; i++) {
        final m = jogos[i];
        final r = _validarJogoMesa(m);
        if (r['valido'] != true) {
          final desc = m
              .map((c) => '${c.valor}${c.naipe == null ? '' : '/${c.naipe}'}#${c.id}')
              .join(' ');
          falhas.add('$dupla[$i] ILEGAL (${r['motivo']}): $desc');
        }
      }
    }
    return falhas;
  }

  // Descrição textual de um meld (para logs de auditoria: valor/naipe + id).
  static String descreverMeld(List<Carta> m) => m
      .map((c) => '${c.valor}${c.naipe == null ? '' : '/${c.naipe}'}#${c.id}')
      .join(' ');

  // Empacotamento FFD dos jogos por linha — MESMA lógica do _packedMelds, extraída
  // pura para teste fiel da colagem visual. `larguras` = largura de cada jogo na ordem
  // original; devolve as linhas como listas de índices originais (ordenados). Sem efeito
  // colateral. Usada tanto pelo render (_packedMelds) quanto pelo teste AUD-02.
  static List<List<int>> empacotarLinhasFFD(
      List<double> larguras, double larguraUtil, double spacing) {
    final ordem = [for (var i = 0; i < larguras.length; i++) i]
      ..sort((a, b) => larguras[b].compareTo(larguras[a]));
    final linhas = <List<int>>[];
    final ocupado = <double>[];
    for (final i in ordem) {
      final w = larguras[i];
      var alvo = -1;
      for (var r = 0; r < linhas.length; r++) {
        if (ocupado[r] + spacing + w <= larguraUtil) {
          alvo = r;
          break;
        }
      }
      if (alvo == -1) {
        linhas.add([i]);
        ocupado.add(w);
      } else {
        linhas[alvo].add(i);
        ocupado[alvo] += spacing + w;
      }
    }
    for (final l in linhas) {
      l.sort();
    }
    return linhas;
  }

  // Conta as duas duplas, soma no placar e marca a partida encerrada se bateu a meta.
  // Auto-protegida: só conta uma vez por rodada.
  void contarPontos() {
    if (_rodadaContada || !rodadaEncerrada) return;
    _rodadaContada = true;
    final algumPegouMorto = mortoPego['nos']! || mortoPego['eles']!;
    final res = <String, dynamic>{};
    // C10 — sob AUTORIDADE ÚNICA quem pontua é o motor canônico
    // (`pontuacao_canonica` + `meld_validator`). Isso fecha a EXC-04: a
    // classificação do grupo de ases (e de qualquer meld) deixa de ter dois
    // donos na hora de contar. A tabela de pontos é a mesma; o que acaba é a
    // segunda autoridade.
    //
    // A conversão §8.1 NÃO isenta o -100 de quem ficou sem morto (correção de
    // regra da revisão do C10 parte 2). Ela segue registrada no envelope
    // (`_mortosConvertidos`) como evento de baralho, sem efeito de pontuação.
    final spec = motorConfig.canonicoAtivo ? specCanonica : null;
    for (final dupla in ['nos', 'eles']) {
      final assentos = dupla == 'nos' ? [0, 2] : [1, 3];
      final Map<String, dynamic> r;
      if (spec != null) {
        r = pontuarDuplaCanonico(
          melds: jogosDupla[dupla]!,
          mao: [for (final a in assentos) ...maos[a]],
          bateu: duplaQueBateu == dupla,
          mortoPego: mortoPego[dupla]!,
          algumPegouMorto: algumPegouMorto,
          spec: spec,
        );
      } else {
        final cartasNaMao = assentos.fold<int>(0, (s, a) => s + maos[a].fold<int>(0, (t, c) => t + _pontos(c)));
        r = _pontuarDupla(dupla,
            bateu: duplaQueBateu == dupla,
            mortoPegoDupla: mortoPego[dupla]!,
            cartasNaMao: cartasNaMao,
            algumPegouMorto: algumPegouMorto);
      }
      res[dupla] = r;
      placar[dupla] = placar[dupla]! + (r['total'] as int);
    }
    pontosRodada = res;
    // §9.2: a partida só encerra quando alguém cruza a meta E não há empate
    // exato — empate na meta força uma RODADA EXTRA até desempatar.
    final n = placar['nos']!, e = placar['eles']!;
    if ((n >= metaPontos || e >= metaPontos) && n != e) encerrada = true;
  }

  // Nova rodada: mantém o placar, redistribui tudo o resto.
  void novaRodada() {
    if (encerrada) return;
    _distribuir();
  }

  // ---------- VALIDAÇÃO DE SEQUÊNCIA / CANASTRA (porte de canastra.js) ----------
  Map<String, dynamic> _finalizar(String tipoBase, int qtdCuringas, int tamanho) {
    String tipo;
    if (tamanho < 7) {
      tipo = 'aberta';
    } else if (tipoBase == 'de_curinga') {
      tipo = 'de_curinga';
    } else if (tipoBase == 'de_as') {
      tipo = 'de_as';
    } else if (tipoBase == 'as_a_as') {
      tipo = 'as_a_as';
    } else if (tipoBase == 'de_500') {
      tipo = 'de_500';
    } else {
      tipo = qtdCuringas > 0 ? 'suja' : 'limpa';
    }
    return {'valido': true, 'tipo': tipo, 'qtd_curingas': qtdCuringas};
  }

  Map<String, dynamic> validarSequencia(List<Carta> cartas) {
    if (cartas.length < 3) return {'valido': false, 'motivo': 'Mínimo de 3 cartas para formar um jogo'};
    final curingas = cartas.where((c) => c.ehCoringa).toList();
    final naoCuringas = cartas.where((c) => !c.ehCoringa).toList();
    // §4.2 (Diretriz Oficial): um jogo aceita NO MÁXIMO 1 curinga substituto.
    // Jogo só de curingas não existe mais (a antiga "canastra de curingas" saiu).
    if (curingas.length == cartas.length) {
      return {'valido': false, 'motivo': 'um jogo precisa de cartas naturais (máximo 1 curinga)'};
    }
    if (curingas.isEmpty && naoCuringas.every((c) => c.valor == 'A')) return _finalizar('de_as', 0, cartas.length);

    final jokers = cartas.where((c) => c.valor == 'JOKER').toList();
    final dois = cartas.where((c) => c.valor == '2').toList();
    final comuns = cartas.where((c) => c.valor != '2' && c.valor != 'JOKER').toList();
    final naipesComuns = comuns.map((c) => c.naipe).toSet();
    if (naipesComuns.length > 1) return {'valido': false, 'motivo': 'Todas as cartas não-coringa devem ser do mesmo naipe'};
    final naipeSeq = comuns.isNotEmpty ? comuns[0].naipe : (dois.isNotEmpty ? dois[0].naipe : null);

    final interpretacoes = <Map<String, List<Carta>>>[];
    for (int mascara = 0; mascara < (1 << dois.length); mascara++) {
      final comoCuringa = <Carta>[], comoNatural = <Carta>[];
      for (int i = 0; i < dois.length; i++) {
        if ((mascara & (1 << i)) != 0) { comoCuringa.add(dois[i]); } else { comoNatural.add(dois[i]); }
      }
      if (comoNatural.any((c) => naipeSeq != null && c.naipe != naipeSeq)) continue;
      interpretacoes.add({'comoCuringa': comoCuringa, 'comoNatural': comoNatural});
    }
    interpretacoes.sort((a, b) => a['comoCuringa']!.length - b['comoCuringa']!.length);

    const N = 13;
    Map<String, int>? encaixa(List<Carta> naturais, int qtdCuringas, int teto) {
      final ases = naturais.where((c) => c.valor == 'A').toList();
      final outros = naturais.where((c) => c.valor != 'A').toList();
      final idxOutros = outros.map((c) => _ordem.indexOf(c.valor)).toList();
      if (idxOutros.toSet().length != idxOutros.length) return null;
      if (ases.length > 2) return null;
      var combos = <List<int>>[[]];
      for (int k = 0; k < ases.length; k++) {
        final prox = <List<int>>[];
        for (final cb in combos) { prox.add([...cb, 0]); prox.add([...cb, N]); }
        combos = prox;
      }
      Map<String, int>? melhor;
      for (final asIdx in combos) {
        final indices = [...idxOutros, ...asIdx]..sort();
        if (indices.toSet().length != indices.length) continue;
        final minIdx = indices.first, maxIdx = indices.last;
        final span = maxIdx - minIdx + 1;
        final lacunas = span - indices.length;
        if (lacunas > qtdCuringas) continue;
        final sobra = qtdCuringas - lacunas;
        if (sobra > 0) {
          final cabeNoInicio = minIdx - sobra >= 0;
          final cabeNoFim = maxIdx + sobra <= teto;
          if (!cabeNoInicio && !cabeNoFim) continue;
        }
        if (melhor == null || maxIdx > melhor['maxIdx']!) {
          melhor = {'minIdx': minIdx, 'maxIdx': maxIdx, 'qtdNaturais': indices.length};
        }
      }
      return melhor;
    }

    String motivoFalha = 'Lacuna na sequência maior que o número de curingas disponíveis';
    for (final interp in interpretacoes) {
      final qtdCuringas = jokers.length + interp['comoCuringa']!.length;
      if (qtdCuringas > 1) { motivoFalha = 'Máximo de 1 curinga por sequência'; continue; }
      final naturais = [...comuns, ...interp['comoNatural']!];
      if (naturais.isEmpty) continue;
      final faixa = encaixa(naturais, qtdCuringas, N);
      if (faixa != null) {
        String tipoBase = 'sequencia';
        if (qtdCuringas == 0) {
          final vals = naturais.map((c) => c.valor).toList();
          final nAses = vals.where((v) => v == 'A').length;
          final outrosDistintos = vals.where((v) => v != 'A').toSet();
          final r2aK = ['2','3','4','5','6','7','8','9','10','J','Q','K'];
          final temDois2aoK = r2aK.every((r) => outrosDistintos.contains(r)) && outrosDistintos.length == 12;
          if (temDois2aoK && nAses == 2 && naturais.length == 14) {
            tipoBase = 'as_a_as';
          } else if (temDois2aoK && nAses == 1 && naturais.length == 13) {
            tipoBase = 'de_500';
          }
        }
        return _finalizar(tipoBase, qtdCuringas, cartas.length);
      }
    }
    return {'valido': false, 'motivo': motivoFalha};
  }

  // §4.3 TRINCA — SÓ no Fechado: 3+ cartas NATURAIS do MESMO VALOR (naipes livres).
  // Spec canônica (Sônia + servidor): NÃO aceita curinga — nem JOKER, nem "2" usado
  // como substituto de outro valor. Três "2" naturais formam trinca de 2 (válida).
  // A trinca NUNCA vira canastra: sem bônus limpa/suja e NÃO libera a batida.
  Map<String, dynamic> _validarTrinca(List<Carta> cartas) {
    if (cartas.length < 3) {
      return {'valido': false, 'motivo': 'uma trinca tem no mínimo 3 cartas'};
    }
    if (cartas.any((c) => c.valor == 'JOKER')) {
      return {
        'valido': false,
        'motivo': 'Joker não entra em trinca — só cartas naturais do mesmo valor'
      };
    }
    final valor = cartas.first.valor;
    if (cartas.any((c) => c.valor != valor)) {
      return {
        'valido': false,
        'motivo':
            'trinca: todas as cartas devem ter o mesmo valor (naturais); 2 e Joker não entram como curinga'
      };
    }
    // Sempre tipo 'trinca' (nunca canastra), sem curinga.
    return {'valido': true, 'tipo': 'trinca', 'qtd_curingas': 0, 'trinca': true};
  }

  // Validador OFICIAL por modalidade (§2/§10):
  // ABERTO/STBL — só sequência (mesmo naipe); trinca proibida (ás só em sequência).
  // FECHADO — sequência OU trinca/lavadeira.
  Map<String, dynamic> _validarJogoMesa(List<Carta> cartas) {
    final fechado = modalidade.toLowerCase() == 'fechado';
    if (fechado) {
      final t = _validarTrinca(cartas);
      if (t['valido'] == true) return t;
      final r = validarSequencia(cartas);
      if (r['valido'] == true) return r;
      return r; // motivo da sequência é o mais útil pro jogador
    }
    final soAses = cartas.isNotEmpty && cartas.every((c) => c.valor == 'A' && !c.ehCoringa);
    final r = validarSequencia(cartas);
    if (r['valido'] == true && !soAses) return r;
    if (soAses) {
      return {'valido': false, 'motivo': 'trinca só vale no FECHADO — aqui o ás entra apenas em sequência'};
    }
    return r;
  }

  bool _canastraLiberaBatida(List<Carta> meld) {
    if (meld.length < 7) return false;
    final r = _validarJogoMesa(meld);
    if (r['valido'] != true) return false;
    if (r['trinca'] == true) return false; // trinca NUNCA é canastra nem libera batida
    // Fechado: QUALQUER canastra (7+) de sequência libera a batida — suja basta (§6.4).
    if (modalidade.toLowerCase() == 'fechado') return true;
    // Aberto/STBL: exige canastra LIMPA (limpa, 500 ou 1000).
    final t = r['tipo'];
    return t == 'limpa' || t == 'de_500' || t == 'as_a_as';
  }

  bool duplaPodeBater(String dupla) => jogosDupla[dupla]!.any(_canastraLiberaBatida);

  bool _baixadaTravaria(String dupla, int maoRestante, List<List<Carta>> futuros) {
    if (maoRestante >= 2) return false;
    final temLimpa = futuros.any(_canastraLiberaBatida);
    final mortoDisp = !mortoPego[dupla]! && mortos.isNotEmpty;
    return !(temLimpa || mortoDisp);
  }

  String get erroTravaria => modalidade.toLowerCase() == 'fechado'
      ? 'não dá pra baixar isso: você ficaria com uma carta que não pode descartar (sem canastra pra bater e sem morto). Segure mais uma carta.'
      : 'não dá pra baixar isso: você ficaria com uma carta que não pode descartar (sem canastra LIMPA pra bater e sem morto). Segure mais uma carta.';

  Map<String, dynamic>? _aoZerarMaoBaixando(int assento) {
    if (maos[assento].isNotEmpty) return null;
    final dupla = _duplaKey(assento);
    if (!mortoPego[dupla]! && mortos.isNotEmpty) {
      maos[assento] = mortos.removeAt(0);
      mortoPego[dupla] = true;
      return {'pegouMorto': true};
    }
    if (duplaPodeBater(dupla)) {
      rodadaEncerrada = true; duplaQueBateu = dupla; assentoQueBateu = assento;
      return {'bateu': true};
    }
    return null;
  }

  /// C10 — RuleSpec canônica desta partida (modalidade + meta). É a MESMA spec
  /// que a autoridade deriva da projeção; aqui serve à classificação e à
  /// pontuação do consumidor.
  RuleSpec get specCanonica =>
      specCanonicaDaPartida(modalidade, metaPontos);

  /// Instantâneo mínimo (antes da transação) do que a UI aprovada precisa saber
  /// depois: quantos jogos a dupla tinha, se já havia pego o morto e se a
  /// rodada já estava encerrada.
  (int, bool, bool) _instantaneoDupla(int assento) {
    final dupla = _duplaKey(assento);
    return (
      jogosDupla[dupla]!.length,
      mortoPego[dupla] ?? false,
      rodadaEncerrada,
    );
  }

  /// C10 — reconstrói, a partir do PÓS-ESTADO canônico já commitado, as três
  /// chaves de FEEDBACK que a mesa aprovada consome (`tipo`, `pegouMorto`,
  /// `bateu`). Não é regra: a regra já decidiu; isto é leitura do resultado.
  ///
  /// `tipo` = classificação canônica do ÚLTIMO meld tocado pela jogada (o jogo
  /// novo mais recente ou, se a jogada só estendeu, o jogo estendido) — é o
  /// meld que a tela celebra. `tipos` traz todos os melds tocados, para a
  /// jogada composta (abertura múltipla).
  Map<String, dynamic> _desfechoBaixada(
    int assento,
    (int, bool, bool) antes,
    List<List<String>> jogosNovos,
    List<Extensao> extensoes,
  ) {
    final dupla = _duplaKey(assento);
    final melds = jogosDupla[dupla]!;
    final spec = specCanonica;
    final indices = <int>[
      for (final e in extensoes)
        if (e.indiceJogo >= 0 && e.indiceJogo < melds.length) e.indiceJogo,
      for (var i = antes.$1; i < melds.length; i++) i,
    ];
    final tipos = <String>[];
    for (final i in indices) {
      final t = tipoCanonicoDeMeld(melds[i], spec);
      if (t != null) tipos.add(t);
    }
    final pegouMorto = !antes.$2 && (mortoPego[dupla] ?? false);
    final bateu =
        !antes.$3 && rodadaEncerrada && duplaQueBateu == dupla;
    return {
      if (tipos.isNotEmpty) 'tipo': tipos.last,
      if (tipos.isNotEmpty) 'tipos': tipos,
      if (pegouMorto) 'pegouMorto': true,
      if (bateu) 'bateu': true,
    };
  }

  // ---------- JOGADAS ----------
  bool comprarMonte(int assento) {
    if (mesaOcupadaPorDerivacao) return false; // C10 (rev.2) — mesa ocupada
    // C10 — AUTORIDADE ÚNICA: o canônico decide/aplica (transação atômica) e é
    // o ÚNICO caminho. Recusa de regra recusa; falha técnica FALHA FECHADO.
    if (motorConfig.canonicoAtivo) {
      final r = _rodarAutoridade(assento, const [ComprarMonte()]);
      if (r.aplicou) return true;
      if (r.recusaCanonica) return false; // recusa de REGRA — sem legado
      _falharFechado('comprarMonte', r); // falha TÉCNICA — sem legado
      return false;
    }
    if (integridadeErro != null) return false; // partida bloqueada p/ auditoria
    if (rodadaEncerrada || vez != assento || jaComprou) return false;
    if (monte.isEmpty) {
      if (mortos.isNotEmpty) {
        monte = mortos.removeAt(0); // §8.1: morto de menor índice vira monte
        _mortosConvertidos++;
      } else { rodadaEncerrada = true; return false; }
    }
    maos[assento].add(monte.removeAt(0));
    jaComprou = true;
    auditarIntegridade();
    return true;
  }

  // PEGAR O LIXO INTEIRO.
  // - ABERTO: compra LIVRE, sem obrigação de usar o topo (regra confirmada).
  // - FECHADO/SBTL: só pode pegar se a carta do TOPO tiver USO IMEDIATO — formar
  //   um jogo novo com 2 cartas da mão OU estender um jogo já baixado da dupla.
  /// C10 — TODOS os candidatos ATÔMICOS de compra do lixo Fechado/STBL para
  /// `assento`, derivados pela autoridade canônica a partir do topo VISÍVEL +
  /// mão + jogos já expostos da dupla (cartas enterradas ficam de fora).
  ///
  /// Auto-derivar ≠ auto-decidir: esta função ENUMERA; quem consome decide
  /// (0 -> recusa, 1 -> executa, 2+ -> o jogador escolhe). No Aberto devolve
  /// lista vazia — lá a compra é livre e não precisa justificar o topo.
  List<ComprarLixo> candidatosCompraLixo(int assento, {DiagnosticoLixo? diag}) {
    final spec = specCanonica;
    if (!spec.exigeUsoDoTopoNoLixo) return const <ComprarLixo>[];
    return derivarCandidatosCompraLixoFechado(
        paraCanonico(this).canonico, assento, spec,
        diag: diag);
  }

  /// C10 (rev.1) — mensagem de recusa da compra do lixo sem uso do topo.
  /// Exposta para que o consumidor possa recusar SEM mandar derivar tudo de
  /// novo só para descobrir que a lista está vazia.
  String get erroLixoSemUsoDoTopo => lixo.isEmpty
      ? 'o lixo está vazio'
      : 'No fechado, só dá pra pegar o lixo se o topo '
          '(${_cartaRotulo(lixo.last)}) tiver uso imediato: formar um '
          'jogo novo com cartas da mão ou estender um jogo já baixado.';

  /// C10 — executa UMA compra do lixo já escolhida, como transação ATÔMICA
  /// (recolhe o lixo E baixa/estende o uso do topo no mesmo commit).
  Map<String, dynamic> comprarLixoAtomico(int assento, ComprarLixo escolha) {
    final ocupada = _recusaSeOcupada; // C10 (rev.2)
    if (ocupada != null) return ocupada;
    if (!motorConfig.canonicoAtivo) {
      return {
        'ok': false,
        'erro': 'compra atômica do lixo só existe sob a autoridade canônica',
      };
    }
    final antes = _instantaneoDupla(assento);
    final qtd = lixo.length;
    final r = _rodarAutoridade(assento, [escolha]);
    if (r.aplicou) {
      return {
        'ok': true,
        'qtd': qtd,
        ..._desfechoBaixada(assento, antes, escolha.jogosNovos, escolha.extensoes),
      };
    }
    if (r.recusaCanonica) {
      return {
        'ok': false,
        'erro': r.motivo ?? 'compra do lixo recusada pelo motor canônico',
      };
    }
    // C10 — falha TÉCNICA: recusa fechada, sem legado (o `Jogo` está intacto).
    return {'ok': false, 'erro': _falharFechado('comprarLixo', r)};
  }

  /// Compra do lixo. O parâmetro `modalidade` é do contrato LEGADO; sob
  /// autoridade canônica a modalidade vem da própria partida (fonte única).
  ///
  /// C10 — no Fechado/STBL aplica o contrato ATÔMICO derivando os candidatos:
  /// 0 -> recusa; 1 -> executa; 2+ -> NÃO escolhe pelo jogador, devolve
  /// `escolhaNecessaria` com os candidatos para o consumidor apresentar. É
  /// PROIBIDO resolver a ambiguidade voltando ao comportamento diferido legado
  /// (comprar agora e cobrar o uso do topo depois).
  Map<String, dynamic> comprarLixo(int assento, {String modalidade = 'ABERTO'}) {
    final ocupada = _recusaSeOcupada; // C10 (rev.2)
    if (ocupada != null) return ocupada;
    if (motorConfig.canonicoAtivo) {
      if (!specCanonica.exigeUsoDoTopoNoLixo) {
        // Aberto: compra LIVRE, para a mão — sem uso obrigatório do topo.
        return comprarLixoAtomico(assento, const ComprarLixo());
      }
      final cands = candidatosCompraLixo(assento);
      if (cands.isEmpty) return {'ok': false, 'erro': erroLixoSemUsoDoTopo};
      if (cands.length == 1) return comprarLixoAtomico(assento, cands.single);
      return {
        'ok': false,
        'escolhaNecessaria': true,
        'candidatos': cands,
        'erro': 'há ${cands.length} formas legais de usar o topo '
            '(${_cartaRotulo(lixo.last)}): escolha uma.',
      };
    }
    if (integridadeErro != null) return {'ok': false, 'erro': integridadeErro};
    if (rodadaEncerrada || vez != assento || jaComprou) return {'ok': false, 'erro': 'não dá pra pegar o lixo agora'};
    if (lixo.isEmpty) return {'ok': false, 'erro': 'o lixo está vazio'};
    if (modalidade.toLowerCase() != 'aberto' && !_topoLixoTemUso(assento)) {
      return {
        'ok': false,
        'erro': 'No fechado, só dá pra pegar o lixo se o topo (${_cartaRotulo(lixo.last)}) '
            'tiver uso imediato: formar um jogo novo com 2 cartas da mão ou estender um jogo já baixado.',
      };
    }
    final qtd = lixo.length;
    final topo = lixo.last; // guarda o topo antes de esvaziar o lixo
    maos[assento].addAll(lixo);
    lixo = [];
    jaComprou = true;
    // Fechado/SBTL: nasce a OBRIGAÇÃO de usar o topo antes de descartar.
    lixoTopoObrigatorio =
        modalidade.toLowerCase() != 'aberto' ? topo.id : null;
    // §5.2 ABERTO: lixo de UMA carta — essa carta não pode voltar como
    // descarte no mesmo turno (anti turno nulo).
    _lixoUnicoCompradoId =
        (modalidade.toLowerCase() == 'aberto' && qtd == 1) ? topo.id : null;
    auditarIntegridade();
    return {'ok': true, 'qtd': qtd};
  }

  // A carta do topo do lixo tem uso imediato E LEGAL? (estende um jogo baixado da
  // dupla, ou fecha um jogo novo de 3+ com 2 cartas da mão — respeitando o mínimo
  // de pontos quando a dupla está vulnerável). Usado pela trava do Fechado.
  bool _topoLixoTemUso(int assento) {
    if (lixo.isEmpty) return false;
    final topo = lixo.last;
    final dupla = _duplaKey(assento);
    // 1) topo estende um jogo já baixado da dupla (extensão nunca é bloqueada)
    for (final jogo in jogosDupla[dupla]!) {
      if (_validarJogoMesa([...jogo, topo])['valido'] == true) return true;
    }
    // 2) topo forma jogo novo de 3 com 2 cartas da mão
    final minimo = minimoParaDescer(dupla); // 0 se não vulnerável / já abriu
    final mao = maos[assento];
    for (var i = 0; i < mao.length; i++) {
      for (var j = i + 1; j < mao.length; j++) {
        final combo = [topo, mao[i], mao[j]];
        if (_validarJogoMesa(combo)['valido'] != true) continue;
        if (minimo > 0) {
          final pts = combo.fold<int>(0, (s, c) => s + _pontos(c));
          if (pts < minimo) continue; // baixada nova seria ilegal (vulnerável)
        }
        return true;
      }
    }
    return false;
  }

  // ORGANIZAR A MÃO: agrupa por naipe (cores alternadas p/ leitura) e ordena por
  // sequência (A,2,3…K). O 2 fica na posição natural dele dentro do naipe (ajuda a
  // enxergar A-2-3); coringas sem naipe (JOKER) vão pro fim.
  static const _naipeOrdem = {'copas': 0, 'espadas': 1, 'ouros': 2, 'paus': 3};
  void ordenar(int assento) {
    maos[assento].sort((a, b) {
      final na = a.naipe == null ? 99 : (_naipeOrdem[a.naipe] ?? 98);
      final nb = b.naipe == null ? 99 : (_naipeOrdem[b.naipe] ?? 98);
      if (na != nb) return na - nb;
      return _ordemVisualMao.indexOf(a.valor) - _ordemVisualMao.indexOf(b.valor);
    });
  }

  // Ordena um JOGO BAIXADO para EXIBIR em sequência crescente (2→A, ou A-2-3
  // quando o Ás é baixo). MELD-003: TODO curinga (JOKER **ou 2 usado como
  // substituto**) vai pro buraco da sequência — nunca fica ordenado pelo valor
  // físico "2". O 2 natural (mesmo naipe, posição contígua) fica onde é. Só exibição.
  List<Carta> ordenarMeld(List<Carta> meld) {
    final jokers = meld.where((c) => c.valor == 'JOKER').toList();
    final naoJokers = meld.where((c) => c.valor != 'JOKER').toList();
    final asBaixo = naoJokers.any((c) => c.valor == '2' || c.valor == '3');
    int rank(Carta c) {
      if (c.valor == 'A') return asBaixo ? 0 : 13; // A baixo = 0 (contíguo ao 2)
      return _ordem.indexOf(c.valor); // A=0, 2=1, 3=2 … K=12
    }

    final outros = naoJokers.where((c) => c.valor != '2').toList();
    final dois = naoJokers.where((c) => c.valor == '2').toList();
    final naipeJogo = outros.isNotEmpty
        ? outros.first.naipe
        : (dois.isNotEmpty ? dois.first.naipe : null);

    // Decide cada 2: NATURAL (mesmo naipe e o rank 1 encaixa contíguo) ou
    // CURINGA de exibição (naipe diferente, ou não encaixa como natural).
    final doisNaturais = <Carta>[];
    final doisCuringa = <Carta>[];
    for (final d in dois) {
      if (d.naipe != naipeJogo) {
        doisCuringa.add(d);
        continue;
      }
      final ranks = [...outros.map(rank), ...doisNaturais.map(rank), 1]..sort();
      final semDuplicata = ranks.toSet().length == ranks.length;
      final lacunas = (ranks.last - ranks.first + 1) - ranks.length;
      final curingasDisponiveis = jokers.length + doisCuringa.length;
      if (semDuplicata && lacunas <= curingasDisponiveis) {
        doisNaturais.add(d);
      } else {
        doisCuringa.add(d);
      }
    }

    // 2º passe: o Ás só é BAIXO se a sequência realmente ocupa a ponta de baixo
    // (tem um 2 NATURAL ou um 3). Um 2 usado como curinga não puxa o Ás pra
    // frente (10-J-[2]-K-A fica com o Ás no ALTO, onde ele pertence).
    final asBaixoFinal = doisNaturais.isNotEmpty ||
        outros.any((c) => c.valor == '3');
    int rankFinal(Carta c) {
      if (c.valor == 'A') return asBaixoFinal ? 0 : 13;
      return _ordem.indexOf(c.valor);
    }

    final naturais = [...outros, ...doisNaturais]
      ..sort((a, b) => rankFinal(a).compareTo(rankFinal(b)));
    final curingas = [...jokers, ...doisCuringa];
    if (curingas.isEmpty) return naturais;
    if (naturais.isEmpty) return curingas;

    final out = <Carta>[];
    final fila = [...curingas];
    for (int i = 0; i < naturais.length; i++) {
      out.add(naturais[i]);
      if (fila.isNotEmpty &&
          i < naturais.length - 1 &&
          rankFinal(naturais[i + 1]) - rankFinal(naturais[i]) == 2) {
        out.add(fila.removeAt(0)); // curinga tapa o buraco
      }
    }
    out.addAll(fila); // sem buraco → curinga na ponta
    return out;
  }

  // EXIBIÇÃO (#9): qual carta cada CORINGA (JOKER) "ocupa" no jogo baixado.
  // Recebe o meld JÁ ORDENADO (por ordenarMeld) e devolve uma lista paralela:
  // posição i => Carta virtual que o coringa daquela posição representa, ou null
  // se a carta i não for um coringa-substituto. Só afeta o desenho da mesa.
  List<Carta?> substitutosMeld(List<Carta> ordenado) {
    final out = List<Carta?>.filled(ordenado.length, null);
    final naturais = ordenado.where((c) => c.valor != 'JOKER').toList();
    if (naturais.isEmpty) return out; // canastra só de curingas: nada a substituir

    // TRINCA (mesmo valor, naipes diferentes): o coringa vira mais uma daquele valor.
    final mesmoValor = naturais.every((c) => c.valor == naturais.first.valor);
    if (mesmoValor) {
      final valor = naturais.first.valor;
      final naipesUsados = naturais.map((c) => c.naipe).toSet();
      final naipeLivre = _naipes.firstWhere(
        (n) => !naipesUsados.contains(n),
        orElse: () => naturais.first.naipe ?? 'espadas',
      );
      for (var i = 0; i < ordenado.length; i++) {
        if (ordenado[i].valor == 'JOKER') {
          out[i] = Carta('virt_${ordenado[i].id}', naipeLivre, valor, false);
        }
      }
      return out;
    }

    // SEQUÊNCIA (mesmo naipe): o coringa ocupa o buraco (4-★-6 → 5) ou a ponta.
    final naipe = naturais.first.naipe;
    // Ás baixo quando a sequência ORDENADA começa na ponta de baixo (A/2/3) —
    // coerente com o 2º passe do ordenarMeld (2-curinga não puxa o Ás).
    final asBaixo = naturais.first.valor == 'A' ||
        naturais.first.valor == '2' ||
        naturais.first.valor == '3';
    int rankOf(Carta c) {
      if (c.valor == 'A') return asBaixo ? 0 : 13; // A baixo = 0 (igual ordenarMeld)
      return _ordem.indexOf(c.valor); // 2=1 … K=12
    }
    String valorDoRank(int r) {
      if (r == 13) return 'A';
      if (r >= 0 && r < _ordem.length) return _ordem[r]; // r=0 → 'A' baixo
      return '';
    }
    for (var i = 0; i < ordenado.length; i++) {
      if (ordenado[i].valor != 'JOKER') continue;
      final antes = i > 0 ? ordenado[i - 1] : null;
      final depois = i < ordenado.length - 1 ? ordenado[i + 1] : null;
      int? alvoRank;
      if (antes != null && antes.valor != 'JOKER' &&
          depois != null && depois.valor != 'JOKER') {
        final ra = rankOf(antes), rd = rankOf(depois);
        if (rd - ra == 2) alvoRank = ra + 1; // buraco de 1
      } else if (antes != null && antes.valor != 'JOKER') {
        alvoRank = rankOf(antes) + 1; // coringa na ponta de cima
      } else if (depois != null && depois.valor != 'JOKER') {
        alvoRank = rankOf(depois) - 1; // coringa na ponta de baixo
      }
      if (alvoRank != null && naipe != null) {
        final v = valorDoRank(alvoRank);
        if (v.isNotEmpty) {
          out[i] = Carta('virt_${ordenado[i].id}', naipe, v, false);
        }
      }
    }
    return out;
  }

  /// C10 — BAIXADA ATÔMICA canônica: um ou mais jogos NOVOS + extensões numa
  /// ÚNICA transação. É a forma pela qual a abertura MÚLTIPLA (EXC-02) e a
  /// extensão existem sob a autoridade única — não há rota paralela.
  /// Exige autoridade canônica (sob rollback legado, o legado não representa
  /// jogada composta; ver `baixar`/`estender`).
  Map<String, dynamic> baixarAtomico(
    int assento, {
    List<List<String>> jogosNovos = const [],
    List<Extensao> extensoes = const [],
    String rotulo = 'baixar',
  }) {
    final ocupada = _recusaSeOcupada; // C10 (rev.2)
    if (ocupada != null) return ocupada;
    if (!motorConfig.canonicoAtivo) {
      return {
        'ok': false,
        'erro': 'baixada atômica só existe sob a autoridade canônica',
      };
    }
    final antes = _instantaneoDupla(assento);
    final r = _rodarAutoridade(
        assento, [Baixar(jogosNovos: jogosNovos, extensoes: extensoes)]);
    if (r.aplicou) {
      return {
        'ok': true,
        ..._desfechoBaixada(assento, antes, jogosNovos, extensoes),
      };
    }
    if (r.recusaCanonica) {
      return {
        'ok': false,
        'erro': r.motivo ?? 'baixada recusada pelo motor canônico',
      };
    }
    // C10 — falha TÉCNICA: recusa fechada, sem legado (o `Jogo` está intacto).
    return {'ok': false, 'erro': _falharFechado(rotulo, r)};
  }

  /// C10 (rev.1) — PARTIÇÕES legais da seleção do jogador em jogos novos.
  /// Enumera; não escolhe. Uma seleção que forma um único meld devolve
  /// exatamente uma partição — o gesto de sempre segue igual.
  List<Baixar> particoesDaSelecao(int assento, List<String> ids,
      {DiagnosticoLixo? diag}) {
    if (!motorConfig.canonicoAtivo) return const <Baixar>[];
    return derivarParticoesAbertura(
        paraCanonico(this).canonico, assento, specCanonica, ids,
        diag: diag);
  }

  Map<String, dynamic> baixar(int assento, List<String> ids) {
    final ocupada = _recusaSeOcupada; // C10 (rev.2)
    if (ocupada != null) return ocupada;
    // C10 — AUTORIDADE ÚNICA: baixada é transação canônica atômica (com
    // estabilização de morto direto/batida quando a baixada zera a mão).
    if (motorConfig.canonicoAtivo) {
      return baixarAtomico(assento, jogosNovos: [ids], rotulo: 'baixar');
    }
    if (integridadeErro != null) return {'ok': false, 'erro': integridadeErro};
    if (rodadaEncerrada || vez != assento || !jaComprou) return {'ok': false, 'erro': 'compre uma carta antes de baixar'};
    if (ids.length < 3) return {'ok': false, 'erro': 'um jogo tem no mínimo 3 cartas'};
    if (ids.toSet().length != ids.length) return {'ok': false, 'erro': 'carta repetida no jogo'};
    final cartas = <Carta>[];
    for (final id in ids) {
      final idx = maos[assento].indexWhere((c) => c.id == id);
      if (idx < 0) return {'ok': false, 'erro': 'carta não está na sua mão'};
      cartas.add(maos[assento][idx]);
    }
    final res = _validarJogoMesa(cartas);
    if (kAuditoriaRegras) {
      debugPrint('[AUD baixar] assento=$assento ids=$ids '
          'cartas={${descreverMeld(cartas)}} -> '
          '${res['valido'] == true ? 'OK tipo=${res['tipo']}' : 'REJEITADO: ${res['motivo']}'}');
    }
    if (res['valido'] != true) return {'ok': false, 'erro': res['motivo'] ?? 'jogo inválido'};
    final dupla = _duplaKey(assento);
    // Gate de vulnerabilidade (seção 11): a PRIMEIRA baixada da dupla na rodada
    // precisa somar o mínimo exigido quando a dupla está vulnerável (1500+ pts).
    final minimo = minimoParaDescer(dupla);
    if (minimo > 0) {
      final pontosBaixada = cartas.fold<int>(0, (s, c) => s + _pontos(c));
      if (pontosBaixada < minimo) {
        return {'ok': false,
          'erro': 'Vulnerável: a 1ª baixada precisa somar $minimo pts (esta soma $pontosBaixada).'};
      }
    }
    final maoRest = maos[assento].length - cartas.length;
    final futuros = [...jogosDupla[dupla]!, cartas];
    if (_baixadaTravaria(dupla, maoRest, futuros)) return {'ok': false, 'erro': erroTravaria};
    final idset = ids.toSet();
    maos[assento] = maos[assento].where((c) => !idset.contains(c.id)).toList();
    jogosDupla[dupla]!.add(cartas);
    if (kAuditoriaRegras) {
      final falhas = auditarMeldsArmazenados();
      if (falhas.isNotEmpty) {
        debugPrint('[AUD !!! MELD ILEGAL ARMAZENADO após baixar] ${falhas.join(' | ')}');
      }
    }
    if (lixoTopoObrigatorio != null && idset.contains(lixoTopoObrigatorio)) {
      lixoTopoObrigatorio = null; // topo do lixo usado numa baixada → obrigação cumprida
    }
    primeiraBaixadaFeita[dupla] = true; // dupla abriu jogo nesta rodada
    final zer = _aoZerarMaoBaixando(assento);
    auditarIntegridade();
    return {'ok': true, 'tipo': res['tipo'], ...?zer};
  }

  Map<String, dynamic> estender(int assento, int indiceJogo, List<String> ids) {
    // C10 (rev.2) — a rev.1 travou monte, lixo e baixada durante a derivação e
    // ESQUECEU a extensão: dava para alterar a mesa por baixo de um seletor
    // aberto. É esse buraco que a trava no MODELO fecha de uma vez.
    final ocupada = _recusaSeOcupada;
    if (ocupada != null) return ocupada;
    // C10 — AUTORIDADE ÚNICA: estender NÃO é uma rota paralela; é uma baixada
    // canônica com `extensoes`. Até o C9-D este método furava a autoridade
    // (validava e mutava direto), o que deixava um buraco no corte canônico.
    if (motorConfig.canonicoAtivo) {
      return baixarAtomico(assento,
          extensoes: [Extensao(indiceJogo, ids)], rotulo: 'estender');
    }
    if (integridadeErro != null) return {'ok': false, 'erro': integridadeErro};
    if (rodadaEncerrada || vez != assento || !jaComprou) return {'ok': false, 'erro': 'compre uma carta antes'};
    final dupla = _duplaKey(assento);
    final jogos = jogosDupla[dupla]!;
    if (indiceJogo < 0 || indiceJogo >= jogos.length) return {'ok': false, 'erro': 'jogo não existe'};
    final alvo = jogos[indiceJogo];
    if (ids.isEmpty) return {'ok': false, 'erro': 'nenhuma carta pra estender'};
    if (ids.toSet().length != ids.length) return {'ok': false, 'erro': 'carta repetida'};
    final cartas = <Carta>[];
    for (final id in ids) {
      final idx = maos[assento].indexWhere((c) => c.id == id);
      if (idx < 0) return {'ok': false, 'erro': 'carta não está na sua mão'};
      cartas.add(maos[assento][idx]);
    }
    final res = _validarJogoMesa([...alvo, ...cartas]);
    if (kAuditoriaRegras) {
      debugPrint('[AUD estender] assento=$assento jogo=$indiceJogo '
          'alvo={${descreverMeld(alvo)}} +{${descreverMeld(cartas)}} -> '
          '${res['valido'] == true ? 'OK tipo=${res['tipo']}' : 'REJEITADO: ${res['motivo']}'}');
    }
    if (res['valido'] != true) return {'ok': false, 'erro': res['motivo'] ?? 'extensão inválida'};
    final maoRest = maos[assento].length - cartas.length;
    final futuros = [for (int i = 0; i < jogos.length; i++) i == indiceJogo ? [...alvo, ...cartas] : jogos[i]];
    if (_baixadaTravaria(dupla, maoRest, futuros)) return {'ok': false, 'erro': erroTravaria};
    final idset = ids.toSet();
    maos[assento] = maos[assento].where((c) => !idset.contains(c.id)).toList();
    jogos[indiceJogo] = [...alvo, ...cartas];
    if (kAuditoriaRegras) {
      final falhas = auditarMeldsArmazenados();
      if (falhas.isNotEmpty) {
        debugPrint('[AUD !!! MELD ILEGAL ARMAZENADO após estender] ${falhas.join(' | ')}');
      }
    }
    if (lixoTopoObrigatorio != null && idset.contains(lixoTopoObrigatorio)) {
      lixoTopoObrigatorio = null; // topo do lixo usado numa extensão → obrigação cumprida
    }
    final zer = _aoZerarMaoBaixando(assento);
    auditarIntegridade();
    return {'ok': true, 'tipo': res['tipo'], ...?zer};
  }

  // retorna null se ok; senão string de erro
  String? descartar(int assento, String idCarta) {
    if (mesaOcupadaPorDerivacao) {
      return 'aguarde: a mesa está conferindo as jogadas possíveis.';
    }
    // C9-D — AUTORIDADE ON: descarte como transação canônica ATÔMICA (com
    // estabilização de morto INDIRETO/batida quando o descarte zera a mão).
    if (motorConfig.canonicoAtivo) {
      final r = _rodarAutoridade(assento, [Descartar(idCarta)]);
      if (r.aplicou) return null;
      if (r.recusaCanonica) {
        return r.motivo ?? 'descarte recusado pelo motor canônico';
      }
      // C10 — falha TÉCNICA: recusa fechada, sem legado (o `Jogo` está intacto).
      return _falharFechado('descartar', r);
    }
    if (integridadeErro != null) return integridadeErro;
    if (rodadaEncerrada || vez != assento || !jaComprou) return 'não é sua vez';
    // Fechado/SBTL: pegou o lixo? tem que USAR o topo antes de descartar.
    if (lixoTopoObrigatorio != null &&
        maos[assento].any((c) => c.id == lixoTopoObrigatorio)) {
      final t = maos[assento].firstWhere((c) => c.id == lixoTopoObrigatorio);
      return 'Você pegou o lixo: use a carta do topo (${_cartaRotulo(t)}) '
          'num jogo (baixando ou estendendo) antes de descartar.';
    }
    // §5.2 ABERTO: comprou o lixo de uma carta só? não pode devolver a mesma.
    if (_lixoUnicoCompradoId != null && _lixoUnicoCompradoId == idCarta) {
      return 'Você pegou essa carta sozinha do lixo — não pode devolvê-la no mesmo turno.';
    }
    final idx = maos[assento].indexWhere((c) => c.id == idCarta);
    if (idx < 0) return 'carta não está na mão';
    final dupla = _duplaKey(assento);
    final zeraria = maos[assento].length == 1;
    final podeBatidaFinal = mortoPego[dupla]! || mortos.isEmpty;
    if (zeraria && podeBatidaFinal && !duplaPodeBater(dupla)) {
      return modalidade.toLowerCase() == 'fechado'
          ? 'pra bater você precisa de pelo menos uma canastra (7+) na mesa da dupla'
          : 'pra bater você precisa de uma canastra LIMPA na mesa da dupla';
    }
    final c = maos[assento].removeAt(idx);
    lixo.add(c);
    if (maos[assento].isEmpty) {
      if (!mortoPego[dupla]! && mortos.isNotEmpty) {
        maos[assento] = mortos.removeAt(0);
        mortoPego[dupla] = true;
        _passarVez();
        auditarIntegridade();
        return null;
      }
      rodadaEncerrada = true; duplaQueBateu = dupla; assentoQueBateu = assento;
      auditarIntegridade();
      return null;
    }
    _passarVez();
    auditarIntegridade();
    return null;
  }

  void _passarVez() {
    lixoTopoObrigatorio = null; // pendência do topo não atravessa a vez
    _lixoUnicoCompradoId = null; // trava do lixo único vale só no próprio turno
    if (monte.isEmpty) {
      if (mortos.isEmpty) { rodadaEncerrada = true; return; }
      monte = mortos.removeAt(0); // §8.1: conversão de morto em monte
      _mortosConvertidos++;
    }
    vez = (vez + 1) % 4;
    jaComprou = false;
  }

  // ============ IA DO ROBÔ (fatia 3 — porte de motor/bot.js) ============
  static int _pontos(Carta c) {
    if (c.valor == 'A') return 15;
    if (c.valor == 'JOKER') return 50;
    if (c.valor == '2') return 10;
    if (['8', '9', '10', 'J', 'Q', 'K'].contains(c.valor)) return 10;
    return 5; // 3..7
  }

  static const int _minJogoPraGastarCuringa = 5;

  // maior corrida do mesmo naipe; usa no máx. 1 curinga se permitir3ComCuringa
  List<Carta>? _melhorCorrida(List<Carta> mao, bool permitir3ComCuringa) {
    const naipes = ['copas', 'ouros', 'paus', 'espadas'];
    List<Carta>? melhor;
    int idxBaixo(String v) => _ordem.indexOf(v);
    int idxAlto(String v) => v == 'A' ? _ordem.length : _ordem.indexOf(v);
    for (final naipe in naipes) {
      final cartasDoNaipe = mao.where((c) => c.naipe == naipe).toList();
      final temAs = cartasDoNaipe.any((c) => c.valor == 'A');
      final mapeamentos = temAs ? <int Function(String)>[idxBaixo, idxAlto] : <int Function(String)>[idxBaixo];
      for (final mapa in mapeamentos) {
        final doNaipe = cartasDoNaipe.toList()..sort((a, b) => mapa(a.valor) - mapa(b.valor));
        final curingasMesmoNaipe = mao.where((c) => c.ehCoringa && c.valor == '2' && c.naipe == naipe).toList();
        final doisOutroNaipe = mao.where((c) => c.ehCoringa && c.valor == '2' && c.naipe != naipe).toList();
        final jokers = mao.where((c) => c.valor == 'JOKER').toList();
        final curingasOrdenados = [...curingasMesmoNaipe, ...doisOutroNaipe, ...jokers];
        final unicas = <Carta>[];
        final vistos = <String>{};
        for (final c in doNaipe) {
          if (!vistos.contains(c.valor)) { unicas.add(c); vistos.add(c.valor); }
        }
        if (unicas.isEmpty) continue;
        for (int i = 0; i < unicas.length; i++) {
          final seq = <Carta>[unicas[i]];
          int curingasUsados = 0;
          final idsNaSeq = <String>{unicas[i].id};
          for (int j = i + 1; j < unicas.length; j++) {
            final distancia = mapa(unicas[j].valor) - mapa(seq.last.valor);
            if (distancia == 1) {
              seq.add(unicas[j]); idsNaSeq.add(unicas[j].id);
            } else if (distancia == 2 && curingasUsados < 1 && permitir3ComCuringa) {
              Carta? cur;
              for (final c in curingasOrdenados) { if (!idsNaSeq.contains(c.id)) { cur = c; break; } }
              if (cur == null) break;
              seq.add(cur); idsNaSeq.add(cur.id);
              seq.add(unicas[j]); idsNaSeq.add(unicas[j].id);
              curingasUsados++;
            } else {
              break;
            }
          }
          if (seq.length == 2 && curingasUsados < 1 && permitir3ComCuringa) {
            Carta? curPonta;
            for (final c in curingasOrdenados) { if (!idsNaSeq.contains(c.id)) { curPonta = c; break; } }
            if (curPonta != null) { seq.add(curPonta); idsNaSeq.add(curPonta.id); curingasUsados++; }
          }
          if (seq.length >= 3) {
            final usaCuringaComoTapa = curingasUsados > 0;
            if (usaCuringaComoTapa && !permitir3ComCuringa) continue;
            final res = validarSequencia(seq);
            if (res['valido'] == true && (melhor == null || seq.length > melhor!.length)) melhor = seq;
          }
        }
      }
    }
    return melhor;
  }

  List<Carta>? _escolherCorrida(List<Carta> mao, bool permissivo) {
    final comCuringa = _melhorCorrida(mao, true);
    if (permissivo) return comCuringa;
    final semCuringa = _melhorCorrida(mao, false);
    final tamSem = semCuringa?.length ?? 0;
    final tamCom = comCuringa?.length ?? 0;
    if (tamSem >= 3 && tamSem >= tamCom) return semCuringa;
    if (tamCom >= _minJogoPraGastarCuringa) return comCuringa;
    return tamSem >= 3 ? semCuringa : null;
  }

  // agrupa a mão em jogos (guloso) + anexa curinga órfão na ponta do maior jogo
  Map<String, dynamic> _agruparMao(List<Carta> mao, bool permissivo) {
    final jogos = <List<Carta>>[];
    var restantes = mao.toList();
    bool progrediu = true;
    while (progrediu) {
      progrediu = false;
      final melhor = _escolherCorrida(restantes, permissivo);
      if (melhor != null && melhor.length >= 3) {
        jogos.add(melhor);
        final usados = melhor.map((c) => c.id).toSet();
        restantes = restantes.where((c) => !usados.contains(c.id)).toList();
        progrediu = true;
      }
    }
    bool podeAnexar(Carta c) => permissivo || c.valor == '2';
    final minParaAnexar = permissivo ? 3 : _minJogoPraGastarCuringa - 1;
    Carta? orfao;
    for (final c in restantes) { if (c.ehCoringa && podeAnexar(c)) { orfao = c; break; } }
    while (orfao != null) {
      final alvos = jogos.where((j) => j.length >= minParaAnexar && !j.any((c) => c.ehCoringa) && j.map((c) => c.valor).toSet().length > 1).toList()
        ..sort((a, b) => b.length - a.length);
      if (alvos.isEmpty) break;
      alvos.first.add(orfao);
      final oid = orfao.id;
      restantes = restantes.where((c) => c.id != oid).toList();
      orfao = null;
      for (final c in restantes) { if (c.ehCoringa && podeAnexar(c)) { orfao = c; break; } }
    }
    return {'jogos': jogos, 'sobra': restantes};
  }

  int _vizinhos(List<Carta> mao, Carta carta) {
    if (carta.ehCoringa) return 99;
    int n = 0;
    for (final c in mao) {
      if (c.id == carta.id || c.ehCoringa) continue;
      if (c.naipe == carta.naipe && (_ordem.indexOf(c.valor) - _ordem.indexOf(carta.valor)).abs() <= 2) n++;
    }
    return n;
  }

  // descarte SEGURO: protege combos em formação, evita curinga, evita servir ao adversário
  Carta _decidirDescarte(List<Carta> mao, List<List<Carta>> jogosAdversario) {
    final sobra = _agruparMao(mao, true)['sobra'] as List<Carta>;
    final candidatas = sobra.isNotEmpty ? sobra : mao.toList();
    final semCuringa = candidatas.where((c) => !c.ehCoringa).toList();
    var pool = semCuringa.isNotEmpty ? semCuringa : candidatas;
    bool ehPerigosa(Carta carta) => jogosAdversario.any((j) => validarSequencia([...j, carta])['valido'] == true);
    final seguras = pool.where((c) => !ehPerigosa(c)).toList();
    if (seguras.isNotEmpty) pool = seguras;
    pool.sort((a, b) {
      final pa = _pontos(a), pb = _pontos(b);
      if (pa != pb) return pa - pb;
      return _vizinhos(mao, a) - _vizinhos(mao, b);
    });
    return pool.first;
  }

  // Porte fiel de bot.js::decidirCompra — decide LIXO vs MONTE no início do turno.
  // Pega o lixo quando o topo (1) estende um jogo já baixado da dupla, ou
  // (2) aumenta as cartas em corridas da mão. Senão, compra do monte.
  // Essa inteligência existia no motor JS e tinha sumido no porte pro Flutter.
  bool _botDeveComprarLixo(int assento) {
    final topo = lixoTopo;
    if (topo == null) return false;
    final dupla = _duplaKey(assento);
    // 1) topo estende algum jogo da dupla?
    for (final jogo in jogosDupla[dupla]!) {
      if (_validarJogoMesa([...jogo, topo])['valido'] == true) return true;
    }
    // 2) o topo aumenta as cartas em corridas da mão?
    int cartasEmCorridas(List<Carta> mao) {
      final jogos = _agruparMao(mao, true)['jogos'] as List<List<Carta>>;
      return jogos.fold<int>(0, (s, j) => s + j.length);
    }
    final sem = cartasEmCorridas(maos[assento]);
    final com = cartasEmCorridas([...maos[assento], topo]);
    return com > sem;
  }

  // Porte de bot.js::decidirPegarMorto + decidirBater — o robô deve "fechar" a mão?
  // true se consegue ZERAR a mão agora E (o morto ainda está disponível pra pegar,
  // OU já pegou o morto e a dupla terá canastra LIMPA pra bater).
  bool _botDeveFechar(int assento) {
    final sobra = _agruparMao(maos[assento], true)['sobra'] as List<Carta>;
    if (sobra.isNotEmpty) return false; // não zera a mão nesta jogada
    final dupla = _duplaKey(assento);
    final mortoDisponivel = !mortoPego[dupla]! && mortos.isNotEmpty;
    if (mortoDisponivel) return true; // decidirPegarMorto
    // decidirBater: precisa de canastra LIMPA (já na mesa ou formada agora)
    final grupos = _agruparMao(maos[assento], true)['jogos'] as List<List<Carta>>;
    final finais = [...jogosDupla[dupla]!, ...grupos];
    if (!finais.any(_canastraLiberaBatida)) return false;
    // Prudência de batida (seção 24): não bater deixando o PARCEIRO com a mão
    // cheia (vira ponto negativo) — salvo se um adversário está prestes a bater
    // (mão <= 3) ou o parceiro já tem poucas cartas. Contagem de cartas é info pública.
    final parceiro = (assento + 2) % 4;
    final advs = [(assento + 1) % 4, (assento + 3) % 4];
    final ameacaAdversario = advs.any((a) => maos[a].length <= 3);
    if (maos[parceiro].length > 8 && !ameacaAdversario) return false; // espera
    return true;
  }

  // Trava de segurança: só deixa uma baixada ZERAR a mão se o zerar for LEGAL
  // (pega o morto disponível, ou bate com canastra limpa). Evita mão vazia travada.
  bool _baixadaSeguraParaZerar(int assento, List<Carta> g) {
    final zeraria = g.length >= maos[assento].length;
    if (!zeraria) return true;
    final dupla = _duplaKey(assento);
    final mortoDisponivel = !mortoPego[dupla]! && mortos.isNotEmpty;
    if (mortoDisponivel) return true;
    final finais = [...jogosDupla[dupla]!, g];
    return finais.any(_canastraLiberaBatida);
  }

  // OS BOT-IA V1 — a COMPRA, a ABERTURA COMPOSTA e a escolha entre candidatos
  // de lixo saíram daqui. Eram três decisões gulosas independentes
  // (`_botCompra`, `_botAbrir`, `_botEscolheCompraLixo`), cada uma parando no
  // primeiro resultado legal. Agora são alternativas PONTUADAS pela camada
  // estratégica (`lib/bot/`), comparadas pelo estado final do turno.
  //
  // O que NÃO mudou, e não pode mudar: a legalidade e a aplicação seguem sendo
  // do canônico, e o robô só escolhe DENTRO dos candidatos que a autoridade
  // derivou (`candidatosCompraLixo`).

  /// C10 — INVARIANTE do robô sob autoridade única: mão vazia com a rodada
  /// aberta e a vez ainda no assento é IMPOSSÍVEL (qualquer ação que zeraria a
  /// mão é recusada ou estabilizada em morto/batida pela autoridade). Se
  /// acontecer, é falha de costura: registra e PARA — jamais chama `_passarVez`,
  /// que mutaria vez/morto/envelope por fora da autoridade.
  bool _botMaoVaziaSemSaida(int assento) {
    if (!motorConfig.canonicoAtivo) {
      if (vez == assento) _passarVez();
      return true;
    }
    falhasTecnicas++;
    ultimaFalhaTecnica = {
      'metodo': 'botJoga',
      'motivo': 'mão vazia com a rodada aberta sob autoridade canônica',
      'evidencia': {'assento': assento, 'vez': vez},
    };
    return true;
  }

  /// C10 (rev.1) — FAIL-CLOSED do robô. Uma falha TÉCNICA significa que a
  /// costura/projeção/transporte quebrou; insistir com outra transação em cima
  /// de um motor que acabou de falhar é justamente o que o fail-closed proíbe.
  /// A partir da primeira falha técnica do turno, o robô PARA — não compra o
  /// monte depois de falhar no lixo, não tenta outro grupo depois de falhar ao
  /// baixar, não tenta outra extensão, não varre outros descartes.
  ///
  /// Recusa de REGRA não passa por aqui: essa o agente pode contornar com outra
  /// jogada, que é decisão estratégica dele.
  bool _botFalhouTecnicamente(int marca) => falhasTecnicas != marca;

  /// C10 (rev.2) — JOGADA AUTOMÁTICA por tempo esgotado, com o MESMO
  /// fail-closed do robô. Vive aqui, e não na tela, por duas razões: é lógica de
  /// jogo (compra + descarte), e na tela ela era intestável — o portão de
  /// qualidade não monta widget.
  ///
  /// C10 (rev.3) — CONTRATO do retorno, decidido pelo ESTADO EFETIVO:
  ///   `true`  = o turno realmente terminou (a vez passou) OU a rodada encerrou
  ///             legalmente;
  ///   `false` = nenhuma ação conseguiu concluir o turno.
  ///
  /// A rev.2 devolvia `true` por ter chegado ao fim do laço: se TODAS as cartas
  /// fossem recusadas por regra, a função dizia "concluí" sem descarte, sem
  /// mudança de vez e sem fim de rodada — e a tela seguia como se o turno
  /// automático tivesse acontecido. Agora o sucesso é medido, não presumido.
  ///
  /// Recusa de REGRA segue tentando a próxima carta (legítimo: a mão pode ter
  /// cartas que não se pode descartar). Falha TÉCNICA encerra a tentativa na
  /// hora. Nada de inventar descarte ou forçar `_passarVez`.
  ///
  /// Quem chama compara `falhasTecnicas` antes e depois para saber se a parada
  /// foi por falha técnica ou por esgotamento das opções legais.
  bool jogadaAutomatica(int assento) {
    // C10 (rev.3) — PAUSA TÉCNICA: depois da primeira falha técnica automática,
    // nenhuma nova tentativa começa. Sem isto a tela mostrava "PAUSADA" mas o
    // relógio seguia vivo e o tick seguinte tentava tudo de novo.
    if (pausadaPorFalhaTecnica) return false;
    if (mesaOcupadaPorDerivacao) return false;
    if (integridadeErro != null) return false;
    if (rodadaEncerrada || vez != assento) return false;

    final marca = falhasTecnicas;
    final vezAntes = vez;

    if (!jaComprou) {
      comprarMonte(assento);
      if (falhasTecnicas != marca) {
        pausadaPorFalhaTecnica = true;
        return false;
      }
      ordenar(assento);
    }
    if (jaComprou && !rodadaEncerrada) {
      for (final c in List<Carta>.from(maos[assento])) {
        final erro = descartar(assento, c.id);
        if (falhasTecnicas != marca) {
          pausadaPorFalhaTecnica = true; // sem segundo descarte, sem novo tick
          return false;
        }
        if (erro == null) break; // descartou: o turno acabou
      }
    }
    // SUCESSO medido pelo estado: a vez passou, ou a rodada encerrou legalmente
    // (batida, morto indireto que devolve à compra, exaustão do baralho).
    return rodadaEncerrada || vez != vezAntes;
  }

  /// OS BOT-IA V1 — PROJEÇÃO só-leitura para a camada estratégica.
  ///
  /// Usa `paraCanonico` diretamente (o mesmo caminho de `candidatosCompraLixo`),
  /// e NÃO o projetor injetável da autoridade: quem exercita falha técnica de
  /// projeção exercita a APLICAÇÃO, que é onde ela importa. Ainda assim vem
  /// protegida — se projetar quebrar, isso é falha TÉCNICA e o robô para.
  EstadoJogo? _projetarParaBot(String metodo) {
    try {
      return paraCanonico(this).canonico;
    } catch (e) {
      falhasTecnicas++;
      ultimaFalhaTecnica = {
        'metodo': metodo,
        'motivo': 'projeção para a camada estratégica falhou: $e',
        'evidencia': {'erro': '$e'},
      };
      return null;
    }
  }

  /// OS BOT-IA V1 — registra o rastro da decisão e, se houver, o IMPASSE.
  /// O impasse NUNCA é silencioso: fica no `Jogo`, observável e testável.
  void _registrarDecisaoBot(DecisaoBot d) {
    ultimaDecisaoBot = d.toJson();
    if (d.impasse) {
      impassesEstrategicos.add({
        'razao': d.razao,
        'diagnostico': d.diagnosticoImpasse,
        'rodada': rodada,
      });
    }
  }

  // ROBÔ — sob AUTORIDADE CANÔNICA o turno é decidido pela camada estratégica
  // (`lib/bot/`): observa por uma visão mascarada, gera PLANOS COMPLETOS de
  // turno, pontua e escolhe UMA intenção. Sob rollback legado continua valendo
  // o robô guloso de sempre (`_botJogaLegado`), que é o que o rollback existe
  // para preservar.
  void botJoga(int assento) {
    if (integridadeErro != null) return; // partida bloqueada p/ auditoria
    if (rodadaEncerrada || vez != assento) return;
    // C10 (rev.1) — marca de FAIL-CLOSED: qualquer falha técnica daqui em diante
    // encerra o turno do robô na hora, sem segunda transação.
    final marca = falhasTecnicas;
    if (motorConfig.canonicoAtivo) {
      _botJogaEstrategico(assento, marca);
      return;
    }
    _botJogaLegado(assento, marca);
  }

  /// OS BOT-IA V1 — turno do robô sob a autoridade canônica.
  ///
  /// Estrutura: COMPRA decidida na visão pública (sem simular carta que ainda
  /// não é conhecida), depois um laço de JOGO que aplica o plano vencedor e
  /// REAVALIA do zero sempre que a mão troca — que é o caso do morto (§6/§11).
  ///
  /// O fail-closed do C10 continua inteiro: a primeira falha TÉCNICA encerra o
  /// turno sem segunda transação, e nada aqui muta estado por fora do motor.
  void _botJogaEstrategico(int assento, int marca) {
    final executor = ExecutorBot(specCanonica, cfg: configuracaoBot);

    // ---------- 1) COMPRA ----------
    if (!jaComprou) {
      final estado = _projetarParaBot('botJoga:compra');
      if (estado == null) return;
      final cands = specCanonica.exigeUsoDoTopoNoLixo
          ? candidatosCompraLixo(assento)
          : const <ComprarLixo>[];
      final d = executor.decidirCompra(estado, assento, candidatosLixo: cands);
      _registrarDecisaoBot(d);
      final escolha = d.acoes.isEmpty ? const ComprarMonte() : d.acoes.first;
      if (escolha is ComprarLixo) {
        final r = (escolha.jogosNovos.isEmpty && escolha.extensoes.isEmpty)
            ? comprarLixo(assento, modalidade: modalidade)
            : comprarLixoAtomico(assento, escolha);
        // C10 (rev.1) FAIL-CLOSED: falha técnica no lixo NÃO vira compra do
        // monte. O motor quebrou; a segunda transação está proibida.
        if (_botFalhouTecnicamente(marca)) return;
        if (r['ok'] != true) {
          // Recusa de REGRA: a intenção morreu, mas comprar é obrigatório para
          // o turno existir. O monte é a outra alternativa legal, não um atalho.
          comprarMonte(assento);
          if (_botFalhouTecnicamente(marca)) return;
        }
      } else {
        comprarMonte(assento);
        if (_botFalhouTecnicamente(marca)) return;
      }
    }
    if (rodadaEncerrada) return;

    // ---------- 2) JOGO ----------
    // O laço só dá outra volta quando a MÃO TROCA (morto pego) ou quando a
    // autoridade recusa a intenção por regra — nos dois casos o certo é
    // reavaliar, não insistir. O teto existe para o turno não girar.
    const maxVoltas = 8;
    for (var volta = 0; volta < maxVoltas; volta++) {
      if (rodadaEncerrada || vez != assento) return;
      if (maos[assento].isEmpty) {
        _botMaoVaziaSemSaida(assento);
        return;
      }
      final estado = _projetarParaBot('botJoga:jogo');
      if (estado == null) return;
      final d = executor.decidirJogo(estado, assento);
      _registrarDecisaoBot(d);
      if (d.vazia) return; // §9 fail-safe: sem plano, o robô não inventa jogada
      final dupla = _duplaKey(assento);
      final plano = d.plano;

      if (plano?.baixada != null) {
        final b = plano!.baixada!;
        final mortoAntes = mortoPego[dupla] ?? false;
        final r = baixarAtomico(
          assento,
          jogosNovos: [for (final j in b.jogosNovos) [...j]],
          extensoes: b.extensoes,
          rotulo: b.jogosNovos.isEmpty ? 'estender' : 'baixar',
        );
        if (_botFalhouTecnicamente(marca)) return;
        if (r['ok'] != true) continue; // recusa de REGRA: reavalia, não insiste
        if (rodadaEncerrada) return;
        // §11 — a mão trocou pelo morto: o plano anterior não vale mais.
        if ((mortoPego[dupla] ?? false) != mortoAntes) continue;
        if (maos[assento].isEmpty) {
          _botMaoVaziaSemSaida(assento);
          return;
        }
      }

      final descarte = plano?.descarte ?? _primeiroDescarteDe(d);
      if (descarte == null) return;
      final erro = descartar(assento, descarte.carta);
      if (_botFalhouTecnicamente(marca)) return;
      if (erro == null) return; // descartou: o turno acabou
      // Recusa de REGRA no descarte: reavalia com o estado atual em vez de
      // varrer a mão às cegas (era assim que o robô antigo "encontrava" carta).
    }
  }

  /// Primeiro `Descartar` das ações da decisão (defesa; o plano já traz o seu).
  Descartar? _primeiroDescarteDe(DecisaoBot d) {
    for (final a in d.acoes) {
      if (a is Descartar) return a;
    }
    return null;
  }

  // ROBÔ LEGADO (fatia 3): compra (lixo se valer, senão monte), BAIXA os jogos
  // possíveis, ESTENDE cartas soltas, FECHA (morto/batida) quando vale, e
  // descarta com critério. Alcançável SOMENTE por `MotorConfig.legadoRollback()`
  // — é o robô que o rollback preserva, e por isso não recebeu a camada nova.
  void _botJogaLegado(int assento, int marca) {
    if (!jaComprou) {
      // Compra inteligente: tenta o lixo quando o topo é útil; senão, o monte.
      // A LEGALIDADE (compra justificada no Fechado/SBTL, §5.3) é do motor:
      // o robô passa a modalidade e obedece à MESMA trava dos humanos.
      if (_botDeveComprarLixo(assento) &&
          comprarLixo(assento, modalidade: modalidade)['ok'] == true) {
        // pegou o lixo
      } else {
        comprarMonte(assento);
      }
    }
    if (_botFalhouTecnicamente(marca)) return; // fail-closed: nem tenta o resto
    if (rodadaEncerrada) return;
    final dupla = _duplaKey(assento);

    // 1b) baixa os jogos que dá (baixar() já respeita a trava/validade)
    final grupos = _agruparMao(maos[assento], false)['jogos'] as List<List<Carta>>;
    for (final g in grupos) {
      if (rodadaEncerrada) break;
      if (!g.every((c) => maos[assento].any((m) => m.id == c.id))) continue; // mão mudou (pegou morto)
      if (!_baixadaSeguraParaZerar(assento, g)) continue; // nunca zerar ilegal (mão vazia travada)
      baixar(assento, g.map((c) => c.id).toList());
      if (_botFalhouTecnicamente(marca)) return; // não tenta outro grupo
    }

    // 2) estende cartas soltas nos jogos da dupla
    bool progrediu = true;
    while (progrediu && !rodadaEncerrada) {
      progrediu = false;
      final jogos = jogosDupla[dupla]!;
      for (int i = 0; i < jogos.length; i++) {
        // REGRA DE OURO (seção 20 da diretriz): nunca SUJAR uma canastra LIMPA
        // já formada (7+ sem curinga) só pra estender — perde valor e é "burrice".
        final ehLimpaCompleta = jogos[i].length >= 7 &&
            _validarJogoMesa(jogos[i])['tipo'] == 'limpa';
        Carta? achou;
        for (final c in maos[assento]) {
          final res = _validarJogoMesa([...jogos[i], c]);
          if (res['valido'] != true) continue;
          if (ehLimpaCompleta && res['tipo'] != 'limpa') continue; // sujaria → pula
          achou = c;
          break;
        }
        if (achou == null) continue;
        final r = estender(assento, i, [achou.id]);
        if (_botFalhouTecnicamente(marca)) return; // não tenta outra extensão
        if (r['ok'] == true) {
          progrediu = true;
          break;
        }
      }
    }

    // 2.5) FECHAMENTO (porte de decidirPegarMorto + decidirBater): quando dá pra
    // ZERAR a mão, baixa agressivo pra PEGAR O MORTO (se disponível) ou BATER
    // (se já pegou o morto e terá canastra limpa). A trava impede zerar ilegal.
    if (_botDeveFechar(assento)) {
      bool fechando = true;
      while (fechando && !rodadaEncerrada && maos[assento].isNotEmpty) {
        fechando = false;
        final fecha = _agruparMao(maos[assento], true)['jogos'] as List<List<Carta>>;
        for (final g in fecha) {
          if (!g.every((c) => maos[assento].any((m) => m.id == c.id))) continue;
          if (!_baixadaSeguraParaZerar(assento, g)) continue;
          final r = baixar(assento, g.map((c) => c.id).toList());
          if (_botFalhouTecnicamente(marca)) return; // não tenta outro grupo
          if (r['ok'] == true) {
            fechando = true;
            break;
          }
        }
      }
    }

    if (rodadaEncerrada) return;
    if (maos[assento].isEmpty) {
      // Rede de segurança: mão vazia sem bater não deveria ocorrer (as travas
      // acima evitam). No legado, passa a vez pra não travar o loop dos robôs;
      // sob autoridade canônica isso é impossível — ver `_botMaoVaziaSemSaida`.
      _botMaoVaziaSemSaida(assento);
      return;
    }

    // 2.7) OBRIGAÇÃO DO TOPO (§5.3 Fechado/SBTL) — bloco LEGADO.
    // Sob autoridade canônica (C10) esta pendência NÃO nasce: a compra do lixo
    // no Fechado/STBL é ATÔMICA, o topo já foi usado no mesmo commit e
    // `lixoTopoObrigatorio` permanece nulo a rodada inteira. O bloco fica
    // reservado ao rollback legado — sob o canônico ele burlaria a autoridade
    // (a rede de segurança abaixo LIMPA a obrigação mutando o envelope direto).
    if (!motorConfig.canonicoAtivo &&
        lixoTopoObrigatorio != null &&
        maos[assento].any((c) => c.id == lixoTopoObrigatorio)) {
      final topoId = lixoTopoObrigatorio!;
      var usou = false;
      final jogosDaDupla = jogosDupla[dupla]!;
      for (int i = 0; i < jogosDaDupla.length && !usou; i++) {
        usou = estender(assento, i, [topoId])['ok'] == true;
      }
      if (!usou) {
        final mao = maos[assento].toList();
        busca:
        for (int i = 0; i < mao.length; i++) {
          for (int k = i + 1; k < mao.length; k++) {
            if (mao[i].id == topoId || mao[k].id == topoId) continue;
            if (baixar(assento, [topoId, mao[i].id, mao[k].id])['ok'] == true) {
              usou = true;
              break busca;
            }
          }
        }
      }
      // Rede de segurança absoluta: se a mão mudou e o uso ficou impossível,
      // libera a pendência pra mesa NUNCA travar (o servidor real valida antes).
      if (!usou) lixoTopoObrigatorio = null;
    }
    if (rodadaEncerrada) return;
    if (maos[assento].isEmpty) {
      _botMaoVaziaSemSaida(assento);
      return;
    }

    // 3) descarta (encerra a vez)
    final adv = jogosDupla[dupla == 'nos' ? 'eles' : 'nos']!;
    final alvo = _decidirDescarte(maos[assento], adv);
    if (descartar(assento, alvo.id) != null) {
      // Falha TÉCNICA no descarte: não varre as outras cartas — o motor acabou
      // de quebrar, e insistir é exatamente o que o fail-closed proíbe. Recusa
      // de REGRA, sim, pode ser contornada com outra carta.
      if (_botFalhouTecnicamente(marca)) return;
      for (final c in maos[assento].toList()) {
        if (descartar(assento, c.id) == null) return;
        if (_botFalhouTecnicamente(marca)) return;
      }
    }
  }
}

// ===================== MESA DE JOGO — FUNCIONAL VIP (CODEX) =====================
// Camada visual aprovada pela Sônia em 29/07/2026.
// Regras, motor, pontuação, robôs, Firebase e contratos continuam preservados.

const _mGold = Color(0xFFE5B84F);
const _mGoldHi = Color(0xFFFFE7A0);
const _mPurple = Color(0xFF9D43D8);
const _mPurpleHi = Color(0xFFD690FF);
const _mFelt = Color(0xFF080808);
const _mPanel = Color(0xEE101010);
const _mRed = Color(0xFFB3262D);
const _mBlack = Color(0xFF121212);

Color _corCarta(Carta c) =>
    c.valor == 'JOKER' ? _mGold : (_cartaVermelha(c) ? _mRed : _mBlack);

class _VipFeltPainter extends CustomPainter {
  const _VipFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = RadialGradient(
      center: const Alignment(0, -0.08),
      radius: 1.1,
      colors: const [Color(0x182B2030), Color(0x080F0B12), Color(0x00000000)],
      stops: const [0, 0.55, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = glow);

    final grain = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.55;
    for (double y = 3; y < size.height; y += 9) {
      final shift = (y ~/ 9).isEven ? 0.0 : 4.0;
      for (double x = shift; x < size.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.45, grain);
      }
    }

    final vignette = RadialGradient(
      radius: 0.84,
      colors: const [Color(0x00000000), Color(0x55000000)],
      stops: const [0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MesaVariant { publica, vip }

class _PublicFeltPainter extends CustomPainter {
  const _PublicFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final felt = RadialGradient(
      center: const Alignment(0, -0.12),
      radius: 1.08,
      colors: const [
        Color(0xFF174D36),
        Color(0xFF0D3928),
        Color(0xFF062719),
      ],
      stops: const [0, 0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = felt);

    final grain = Paint()
      ..color = const Color(0x0BFFFFFF)
      ..strokeWidth = 0.55;
    for (double y = 3; y < size.height; y += 9) {
      final shift = (y ~/ 9).isEven ? 0.0 : 4.0;
      for (double x = shift; x < size.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.45, grain);
      }
    }

    final vignette = RadialGradient(
      radius: 0.88,
      colors: const [Color(0x00000000), Color(0x65000000)],
      stops: const [0.58, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MesaScreen extends StatefulWidget {
  final MesaVariant variant;
  final String modalidade;
  final int metaPontos;
  final int tempoSegundos;
  final int? vulnerabilidadeNos;
  final int? vulnerabilidadeEles;

  /// C10 — ROLLBACK explícito e PRÉ-TRANSAÇÃO do motor da partida LOCAL.
  /// `null` (padrão) = a partida NASCE em `MotorConfig.producao()` (autoridade
  /// canônica ON). O único caminho para o legado é passar aqui, ANTES da
  /// partida, `MotorConfig.legadoRollback()` — nunca por jogada, nunca por
  /// recusa de regra, nunca por falha técnica.
  final MotorConfig? motorConfig;

  /// Configuração EFETIVA do motor desta mesa — a MESMA expressão que o ROOT
  /// usa para nascer. Pública para que o portão de qualidade prove o padrão
  /// (produção) sem precisar montar a tela inteira: o teste de widget exigiria
  /// os assets do baralho declarados no pubspec, o que no CI só acontece
  /// DEPOIS do portão.
  MotorConfig get configEfetivaDoMotor => motorConfig ?? MotorConfig.producao();

  const MesaScreen({
    super.key,
    this.variant = MesaVariant.vip,
    this.modalidade = 'ABERTO',
    this.metaPontos = 1500,
    this.tempoSegundos = 45,
    this.vulnerabilidadeNos,
    this.vulnerabilidadeEles,
    this.motorConfig,
  });

  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> {
  late Jogo _j;
  final Set<int> _sel = <int>{};
  final ScrollController _handScroll = ScrollController();
  final ScrollController _discardScroll = ScrollController();

  bool _botsRodando = false;

  /// C10 (rev.2) — a mesa está ocupada por uma derivação combinatória (uso do
  /// topo do lixo OU partição da seleção) ou por uma escolha humana pendente.
  /// O nome antigo (`_derivandoLixo`) descrevia só metade dos casos desde que a
  /// abertura múltipla passou a derivar também.
  ///
  /// Espelha `Jogo.mesaOcupadaPorDerivacao`, que é a trava de verdade: esta aqui
  /// serve para a tela reagir (desabilitar o toque, sinalizar espera). A recusa
  /// não depende dela — depende do modelo.
  bool _mesaOcupadaPorDerivacao = false;
  bool _soundEnabled = true;
  String? _msg;
  Set<String> _recentlyBoughtIds = <String>{};
  String? _lastPurchaseSource;
  String? _celebratingMeldKey;
  int? _expandedAvatarSeat;
  Timer? _purchaseGlowTimer;
  Timer? _celebrationTimer;
  Timer? _turnTimer;
  int _turnSeconds = 45;
  int _clockSeat = 0;

  final Map<int, EstadoAmizade> _amizades = <int, EstadoAmizade>{
    1: EstadoAmizade.disponivel,
    2: EstadoAmizade.amigos,
    3: EstadoAmizade.disponivel,
  };
  bool _conviteRevancheEnviado = false;
  bool _anuncioAssistido = false;
  bool _anuncioDisponivel = true;
  bool _assinanteSemAnuncios = false;

  AudioPlayer? _pCarta;
  AudioPlayer? _pEvento;

  String get _modalidade => widget.modalidade;
  bool get _mesaVip => widget.variant == MesaVariant.vip;
  Color get _feltColor =>
      _mesaVip ? _mFelt : const Color(0xFF062719);
  String get _cardBackAsset => _mesaVip
      ? 'assets/baralho/dorso.webp'
      : 'assets/baralho/dorso_publico.webp';
  int? _vulnerabilidadeDaDupla(String dupla) {
    final minimo = _j.minimoParaDescer(dupla);
    if (minimo > 0) return minimo;
    return dupla == 'nos' ? widget.vulnerabilidadeNos : widget.vulnerabilidadeEles;
  }

  /// C10 (rev.2) — GUARDA ÚNICA das entradas humanas mutantes da mesa (monte,
  /// lixo, baixar, estender) e da jogada automática. A rev.1 espalhava
  /// `_derivandoLixo` por alguns pontos e esquecia outros; agora a condição de
  /// "posso agir" mora num lugar só.
  bool get _minhaVezAtiva =>
      _j.suaVez &&
      !_j.rodadaEncerrada &&
      !_botsRodando &&
      !_mesaOcupadaPorDerivacao;

  /// C10 — ROOT da partida LOCAL. A partida NASCE canônica: a autoridade é do
  /// `RulesEngine` desde a primeira jogada. O rollback é CONFIGURAÇÃO, escolhida
  /// aqui (`widget.motorConfig = MotorConfig.legadoRollback()`) antes de existir
  /// qualquer transação — jamais um fallback disparado no meio da partida.
  Jogo _novoJogo() {
    final jogo = Jogo(
      const ['você', 'Cláudia', 'Mateus', 'Sofia'],
      const ['👑', '🙂', '😎', 'RN'],
      const ['🐶', '🐰', '🦊', '🐱'],
      motorConfig: widget.configEfetivaDoMotor,
    );
    jogo.metaPontos = widget.metaPontos;
    jogo.modalidade = widget.modalidade;
    return jogo;
  }

  @override
  void initState() {
    super.initState();
    _j = _novoJogo();
    _turnSeconds = widget.tempoSegundos;
    _clockSeat = _j.vez;
    try {
      _pCarta = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pEvento = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // A mesa continua funcional mesmo quando o dispositivo não oferece áudio.
    }
    _startTurnClock();
    // §3.2: o 1º jogador é SORTEADO — se caiu num robô, os robôs abrem a rodada.
    if (_j.vez != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rodarBots();
      });
    }
  }

  @override
  void dispose() {
    _purchaseGlowTimer?.cancel();
    _celebrationTimer?.cancel();
    _turnTimer?.cancel();
    _handScroll.dispose();
    _discardScroll.dispose();
    _pCarta?.dispose();
    _pEvento?.dispose();
    super.dispose();
  }

  void _startTurnClock() {
    _turnTimer?.cancel();
    // C10 (rev.3) — depois de uma pausa técnica o relógio não volta a rodar.
    if (_j.pausadaPorFalhaTecnica) {
      _turnTimer = null;
      return;
    }
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_j.rodadaEncerrada) return;
      if (_clockSeat != _j.vez) {
        setState(() {
          _clockSeat = _j.vez;
          _turnSeconds = widget.tempoSegundos;
        });
        return;
      }
      // C10 (rev.3) — pausa TÉCNICA: o relógio não volta a disparar a jogada
      // automática. A trava de estado é `_j.pausadaPorFalhaTecnica`; esta
      // checagem só evita o tick inútil (o timer já foi cancelado na parada).
      if (_j.pausadaPorFalhaTecnica) return;
      if (_turnSeconds > 0) {
        setState(() => _turnSeconds -= 1);
      } else {
        // Tempo esgotou: na vez do humano o app joga sozinho e passa a vez.
        if (_j.vez == 0 && !_j.rodadaEncerrada && !_botsRodando) {
          _autoJogarPorTempo();
        }
      }
    });
  }

  /// Jogada automática quando o cronômetro zera na vez do humano.
  ///
  /// C10 (rev.2) — FAIL-CLOSED, pela MESMA noção monotônica que o robô usa. A
  /// rev.1 corrigiu o robô e esqueceu deste caminho: ele comprava o monte,
  /// falhava tecnicamente e mesmo assim varria a mão inteira tentando descartar,
  /// e no fim chamava `_rodarBots` como se o turno tivesse terminado normalmente.
  ///
  /// Agora, na primeira falha técnica: para na hora, NÃO tenta outra carta, NÃO
  /// passa a vez para os robôs e diz o que aconteceu. A evidência
  /// (`ultimaFalhaTecnica`) fica preservada para diagnóstico.
  void _autoJogarPorTempo() {
    if (_j.vez != 0 || _j.rodadaEncerrada || _botsRodando) return;
    // Não atropela derivação nem escolha humana em andamento.
    if (_mesaOcupadaPorDerivacao) return;
    // C10 (rev.3) — já pausada por falha técnica: nem tenta.
    if (_j.pausadaPorFalhaTecnica) return;

    final marca = _j.falhasTecnicas;
    final concluiu = _j.jogadaAutomatica(0);
    // Falha técnica: para aqui. Não passa a vez para os robôs e não finge que o
    // turno automático terminou. A evidência está em `_j.ultimaFalhaTecnica`.
    if (_j.falhasTecnicas != marca) return _pararPorFalhaTecnica();
    if (!concluiu) return;
    _sel.clear();
    _msg = 'Tempo esgotado — jogada automática.';
    if (_j.rodadaEncerrada) _j.contarPontos();
    if (mounted) setState(() {});
    _scrollDiscardToEnd();
    _rodarBots();
  }

  /// C10 (rev.3) — parada EFETIVA da jogada automática por falha técnica.
  ///
  /// A rev.2 só exibia `PARTIDA PAUSADA`: o `Timer.periodic` continuava vivo com
  /// `_turnSeconds == 0`, e o tick seguinte chamava tudo de novo — nova compra,
  /// novo descarte, nova falha. A mensagem não correspondia ao estado do fluxo.
  ///
  /// Agora a pausa é real em duas camadas: `Jogo.pausadaPorFalhaTecnica` (a
  /// trava de estado, que `jogadaAutomatica` respeita venha de onde vier) e o
  /// cancelamento do relógio (que evita até o tick inútil). A vez continua onde
  /// está, os robôs NÃO são acionados e `ultimaFalhaTecnica` é preservada.
  void _pararPorFalhaTecnica() {
    _j.pausadaPorFalhaTecnica = true; // redundante com o modelo, e explícito
    _turnTimer?.cancel();
    _turnTimer = null;
    if (!mounted) return;
    setState(() => _msg = 'PARTIDA PAUSADA · falha técnica do motor na jogada '
        'automática; nada foi alterado.');
  }

  void _syncTurnClock({bool force = false}) {
    if (force || _clockSeat != _j.vez) {
      _clockSeat = _j.vez;
      _turnSeconds = widget.tempoSegundos;
    }
  }

  void _play(AudioPlayer? player, String arquivo, double volume) {
    if (!_soundEnabled || player == null) return;
    try {
      player.stop();
      player.play(AssetSource('sons/$arquivo'), volume: volume);
    } catch (_) {}
  }

  void _somCarta() => _play(_pCarta, 'carta.mp3', 0.95);
  void _somCompra() => _play(_pCarta, 'carta.mp3', 1.0);
  void _somErro() => _play(_pEvento, 'erro.mp3', 0.9);
  void _somMorto() => _play(_pEvento, 'morto.mp3', 1.0);
  void _somVitoria() => _play(_pEvento, 'vitoria.mp3', 1.0);

  void _somCanastra(String? tipo) {
    switch (tipo) {
      case 'as_a_as':
        _play(_pEvento, 'canastra1000.mp3', 1.0);
        break;
      case 'de_500':
        _play(_pEvento, 'canastra500.mp3', 1.0);
        break;
      case 'suja':
        _play(_pEvento, 'canastra_suja.mp3', 1.0);
        break;
      default:
        _play(_pEvento, 'canastra200.mp3', 1.0);
    }
  }

  void _somJogada(Map<String, dynamic> resultado,
      {required bool novaCanastra}) {
    if (resultado['bateu'] == true) {
      _somVitoria();
      return;
    }
    if (novaCanastra) {
      _somCanastra(resultado['tipo'] as String?);
      return;
    }
    if (resultado['pegouMorto'] == true) {
      _somMorto();
      return;
    }
    _somCarta();
  }

  void _tapCard(int index) {
    setState(() {
      if (_sel.contains(index)) {
        _sel.remove(index);
      } else {
        _sel.add(index);
      }
      _msg = null;
    });
  }

  void _mostrarCompra(Set<String> ids, String origem) {
    if (ids.isEmpty) return;
    _purchaseGlowTimer?.cancel();
    setState(() {
      _recentlyBoughtIds = ids;
      _lastPurchaseSource = origem;
      _msg = null;
    });
    _purchaseGlowTimer = Timer(const Duration(milliseconds: 1850), () {
      if (!mounted) return;
      setState(() {
        _recentlyBoughtIds = <String>{};
        _lastPurchaseSource = null;
      });
    });
  }

  void _celebrateMeld(String dupla, int index) {
    _celebrationTimer?.cancel();
    setState(() => _celebratingMeldKey = '$dupla-$index');
    _celebrationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _celebratingMeldKey = null);
    });
  }

  void _scrollDiscardToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_discardScroll.hasClients) return;
      _discardScroll.animateTo(
        _discardScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _tapMonte() {
    if (!_minhaVezAtiva || _j.jaComprou) return; // guarda única
    final antes = _j.maos[0].map((c) => c.id).toSet();
    final ok = _j.comprarMonte(0);
    // C10 — EXAUSTÃO (monte E mortos vazios): sob a autoridade canônica a
    // compra é uma transição LEGAL que ENCERRA a rodada sem carta comprada.
    // O consumidor precisa fechar a contagem, senão a rodada morre sem placar.
    if (_j.rodadaEncerrada) {
      _j.contarPontos();
      setState(() {
        _msg = 'Acabaram as cartas: a rodada encerrou.';
        _syncTurnClock();
      });
      return;
    }
    if (!ok) return;
    _j.ordenar(0);
    final novos = _j.maos[0]
        .where((c) => !antes.contains(c.id))
        .map((c) => c.id)
        .toSet();
    _mostrarCompra(novos, 'monte');
    _somCompra();
  }

  /// C10 — COMPRA do lixo no consumidor real, sob o contrato ATÔMICO.
  ///
  /// Aberto: compra livre. Fechado/STBL: os candidatos vêm da autoridade
  /// canônica e o consumidor aplica 0 -> recusa / 1 -> executa / 2+ -> o
  /// JOGADOR escolhe. Nunca compra "para a mão" com a obrigação do topo
  /// pendente — esse era o comportamento diferido do legado.
  ///
  /// RESPONSIVIDADE (rev.2): a derivação roda em OUTRO ISOLATE (`compute`) nas
  /// plataformas nativas; na web cai no mesmo event loop, porque lá não existem
  /// isolates. Nos dois casos o conjunto de candidatos LEGAIS é idêntico — não
  /// há teto, amostragem nem corte semântico para "ficar rápido".
  Future<void> _comprarLixoNoToque() async {
    if (_mesaOcupadaPorDerivacao) return; // reentrância: um toque por vez
    final antes = _j.maos[0].map((c) => c.id).toSet();

    final Map<String, dynamic> resultado;
    if (!_j.specCanonica.exigeUsoDoTopoNoLixo) {
      resultado = _j.comprarLixo(0, modalidade: _modalidade);
    } else {
      try {
        final cands = await _derivarForaDoFrame(
          () => candidatosLixoForaDoFrame(ArgsCandidatosLixo(
              paraCanonico(_j).canonico, 0, _j.specCanonica)),
          aviso: 'Conferindo os usos do topo…',
          manterOcupado: true,
        );
        if (!mounted) return;
        if (cands.isEmpty) {
          // C10 (rev.1): NÃO chama `comprarLixo`, que derivaria tudo de novo só
          // para descobrir que não há candidato. A recusa é montada a partir do
          // resultado que já temos.
          resultado = {'ok': false, 'erro': _j.erroLixoSemUsoDoTopo};
        } else if (cands.length == 1) {
          _liberarMesa(); // libera ANTES de aplicar: a trava recusaria a jogada
          resultado = _j.comprarLixoAtomico(0, cands.single);
        } else {
          // A mesa continua OCUPADA enquanto o seletor está aberto — é o que
          // impede qualquer jogada (inclusive a automática do cronômetro) de
          // mexer no estado por baixo da escolha do jogador.
          final escolha = await _escolherCompraLixo(cands);
          if (!mounted) return;
          if (escolha == null) return; // desistiu: nada acontece
          _liberarMesa();
          resultado = _j.comprarLixoAtomico(0, escolha);
        }
      } finally {
        _liberarMesa();
      }
    }

    if (resultado['ok'] != true) {
      setState(() => _msg = resultado['erro'] as String?);
      _somErro();
      return;
    }
    _j.ordenar(0);
    final novos = _j.maos[0]
        .where((c) => !antes.contains(c.id))
        .map((c) => c.id)
        .toSet();
    _sel.clear();
    _mostrarCompra(novos, 'lixo');
    // A compra ATÔMICA pode ter baixado/estendido, virado canastra, pego o
    // morto ou até batido no mesmo commit — o feedback segue o desfecho real.
    final tipo = resultado['tipo'] as String?;
    final novaCanastra = tipo != null && tipo != 'aberta';
    if (resultado['bateu'] == true ||
        resultado['pegouMorto'] == true ||
        novaCanastra) {
      _somJogada(resultado, novaCanastra: novaCanastra);
    } else {
      _somCompra();
    }
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _msg = resultado['bateu'] == true
          ? 'Você bateu!'
          : (resultado['pegouMorto'] == true ? 'Você pegou o morto.' : null);
      _syncTurnClock();
    });
  }

  /// C10 (rev.2) — OCUPA a mesa (modelo + tela) e sinaliza a espera pelo canal
  /// de mensagem que já existe — nenhum elemento novo entra no layout aprovado.
  void _ocuparMesa(String aviso) {
    _j.mesaOcupadaPorDerivacao = true; // trava de verdade: recusa no modelo
    setState(() {
      _mesaOcupadaPorDerivacao = true; // espelho: a tela reage
      _msg = aviso;
    });
  }

  /// LIBERA a mesa. Chamado no fim da derivação e, obrigatoriamente, ANTES de
  /// aplicar a jogada escolhida — terminada a escolha, a janela de risco acabou
  /// e a transação é síncrona.
  void _liberarMesa({String? avisoAtual}) {
    _j.mesaOcupadaPorDerivacao = false;
    if (!mounted) return;
    setState(() {
      _mesaOcupadaPorDerivacao = false;
      if (avisoAtual != null && _msg == avisoAtual) _msg = null;
    });
  }

  /// C10 (rev.2) — roda uma derivação combinatória em OUTRO ISOLATE (`compute`,
  /// ver `motor/derivacao_fora_do_frame.dart`) com a mesa ocupada.
  ///
  /// Em plataformas nativas a travessia roda mesmo fora do isolate de UI, e o
  /// frame corre solto. Na WEB não há isolates: `compute` cai no mesmo event
  /// loop e a espera aparece — degradação honesta, não contorno. Em nenhum dos
  /// dois casos o conjunto de resultados muda: não há teto de cartas,
  /// candidatos, melds nem tempo.
  ///
  /// `manterOcupado` deixa a mesa ocupada depois do retorno — usado quando um
  /// seletor vai abrir em seguida e o estado não pode mudar por baixo dele;
  /// nesse caso quem chama é responsável por chamar `_liberarMesa`.
  Future<T> _derivarForaDoFrame<T>(
    Future<T> Function() tarefa, {
    required String aviso,
    bool manterOcupado = false,
  }) async {
    _ocuparMesa(aviso);
    try {
      return await tarefa();
    } finally {
      if (!manterOcupado) {
        _liberarMesa(avisoAtual: aviso);
      } else if (mounted && _msg == aviso) {
        setState(() => _msg = null);
      }
    }
  }

  Future<void> _tapLixo() async {
    if (!_minhaVezAtiva) return; // guarda única
    if (!_j.jaComprou) {
      await _comprarLixoNoToque();
      return;
    }

    if (_sel.length != 1) {
      setState(() =>
          _msg = 'Selecione uma carta e toque no lixo para descartar.');
      return;
    }

    final id = _j.maos[0][_sel.first].id;
    final mortoAntes = _j.mortoPego['nos'] == true;
    final erro = _j.descartar(0, id);
    if (erro != null) {
      setState(() => _msg = erro);
      _somErro();
      return;
    }

    if (!mortoAntes && _j.mortoPego['nos'] == true) {
      _somMorto();
    } else if (_j.rodadaEncerrada && _j.duplaQueBateu == 'nos') {
      _somVitoria();
    } else if (!_j.rodadaEncerrada) {
      _somCarta();
    }
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = null;
      _syncTurnClock();
    });
    _scrollDiscardToEnd();
    await _rodarBots();
  }

  /// C10 (rev.1) — BAIXAR pelo gesto aprovado, agora com abertura MÚLTIPLA.
  ///
  /// O gesto é o mesmo de sempre: seleciona as cartas, toca no feltro. O que
  /// mudou é a interpretação — a autoridade deriva todas as maneiras legais de
  /// repartir EXATAMENTE aquela seleção em jogos. 0 → recusa; 1 → executa;
  /// 2+ → o jogador escolhe. Seleção de um meld só continua dando uma partição,
  /// então o comportamento do gesto de sempre não mudou.
  ///
  /// É assim que a dupla vulnerável abre quando o mínimo depende da SOMA dos
  /// jogos: ela seleciona as cartas dos dois (ou três) jogos de uma vez.
  Future<void> _baixar() async {
    if (!_minhaVezAtiva || !_j.jaComprou) return; // guarda única
    if (_sel.length < 3) {
      setState(() => _msg =
          'Selecione três ou mais cartas e toque no feltro para baixar.');
      return;
    }
    final novoIndice = _j.jogosDupla['nos']!.length;
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();

    final Map<String, dynamic> resultado;
    try {
      final particoes = await _derivarForaDoFrame(
        () => particoesForaDoFrame(ArgsParticoes(
            paraCanonico(_j).canonico, 0, _j.specCanonica, ids)),
        aviso: 'Conferindo as formas de baixar…',
        manterOcupado: true,
      );
      if (!mounted) return;
      if (particoes.isEmpty) {
        // Nenhuma partição legal. A MENSAGEM vem da autoridade, pela baixada
        // simples — é ela que sabe dizer se o problema é o meld, o mínimo de
        // vulnerabilidade ou a trava de esvaziar a mão. Isso NÃO regenera
        // partições: `baixar` faz uma transação canônica direta.
        _liberarMesa(); // libera ANTES de aplicar: a trava recusaria a jogada
        resultado = _j.baixar(0, ids);
      } else if (particoes.length == 1) {
        _liberarMesa();
        resultado = _j.baixarAtomico(0, jogosNovos: particoes.single.jogosNovos);
      } else {
        // Mesa OCUPADA enquanto o seletor está aberto.
        final escolha = await _escolherParticao(particoes);
        if (!mounted) return;
        if (escolha == null) return; // desistiu: nada acontece
        _liberarMesa();
        resultado = _j.baixarAtomico(0, jogosNovos: escolha.jogosNovos);
      }
    } finally {
      _liberarMesa();
    }

    if (resultado['ok'] != true) {
      setState(() => _msg = resultado['erro'] as String?);
      _somErro();
      return;
    }
    _j.ordenar(0);
    final tipo = resultado['tipo'] as String?;
    final novaCanastra = tipo != null && tipo != 'aberta';
    _somJogada(resultado, novaCanastra: novaCanastra);
    if (novaCanastra) _celebrateMeld('nos', novoIndice);
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      final n = (resultado['tipos'] as List?)?.length ?? 1;
      _msg = resultado['bateu'] == true
          ? 'Você bateu!'
          : (resultado['pegouMorto'] == true
              ? 'Você pegou o morto.'
              : (n > 1 ? '$n jogos baixados.' : 'Jogo baixado.'));
    });
  }

  void _estender(int indiceJogo) {
    if (!_minhaVezAtiva || !_j.jaComprou) return;
    if (_sel.isEmpty) {
      _showMeldZoom('nos', indiceJogo);
      return;
    }
    final jogos = _j.jogosDupla['nos']!;
    if (indiceJogo < 0 || indiceJogo >= jogos.length) return;
    final sashAntes = _sashDeMeld(jogos[indiceJogo]);
    final ids = _sel.map((i) => _j.maos[0][i].id).toList();
    final resultado = _j.estender(0, indiceJogo, ids);
    if (resultado['ok'] != true) {
      setState(() => _msg = resultado['erro'] as String?);
      _somErro();
      return;
    }
    _j.ordenar(0);
    // C10 — sob autoridade canônica o commit REATRIBUI `jogosDupla`; a lista
    // capturada antes da jogada ficou obsoleta. Reler é obrigatório, senão a
    // tarja/celebração leem o PRÉ-estado e nunca disparam.
    final jogosPos = _j.jogosDupla['nos']!;
    final sashDepois = indiceJogo < jogosPos.length
        ? _sashDeMeld(jogosPos[indiceJogo])
        : Sash.nenhuma;
    final novaCanastra =
        sashDepois != Sash.nenhuma && sashDepois != sashAntes;
    _somJogada(resultado, novaCanastra: novaCanastra);
    if (novaCanastra) _celebrateMeld('nos', indiceJogo);
    if (_j.rodadaEncerrada) _j.contarPontos();
    setState(() {
      _sel.clear();
      _msg = resultado['bateu'] == true
          ? 'Você bateu!'
          : (resultado['pegouMorto'] == true
              ? 'Você pegou o morto.'
              : 'Jogo estendido.');
    });
  }

  Future<void> _rodarBots() async {
    _botsRodando = true;
    String? travou;
    while (_j.vez != 0 && !_j.rodadaEncerrada && _j.integridadeErro == null) {
      await Future.delayed(const Duration(milliseconds: 650));
      final vezAntes = _j.vez;
      _j.botJoga(_j.vez);
      // C10 — GUARDA DE PROGRESSO. Sob autoridade única o robô não pode mais
      // "destravar" o turno mutando o estado por fora (`_passarVez` direto);
      // então, se um turno terminar sem a vez avançar nem a rodada encerrar, o
      // laço PARA aqui em vez de girar para sempre. Não é um caminho de regra:
      // é a rede que substitui a mutação ilegal por uma parada visível.
      if (_j.vez == vezAntes && !_j.rodadaEncerrada) {
        travou = 'o robô do assento $vezAntes não conseguiu concluir o turno';
        break;
      }
      _somCarta();
      _syncTurnClock();
      _scrollDiscardToEnd();
      if (mounted) setState(() {});
    }
    _botsRodando = false;
    if (travou != null && mounted) {
      setState(() => _msg = 'PARTIDA PAUSADA · $travou');
      return;
    }
    if (_j.integridadeErro != null && mounted) {
      // Integridade violada: preserva o estado, bloqueia a partida e mostra
      // o código auditável (nunca tenta "consertar" inventando carta).
      setState(() => _msg = 'PARTIDA BLOQUEADA · ${_j.integridadeErro}');
      return;
    }
    if (_j.rodadaEncerrada) {
      _j.contarPontos();
      if (_j.duplaQueBateu == 'nos') _somVitoria();
    }
    _syncTurnClock();
    if (mounted) setState(() {});
  }

  Sash _sashDeMeld(List<Carta> cartas) {
    if (cartas.length < 7) return Sash.nenhuma;
    // Validador por modalidade: no Fechado a trinca-canastra também ganha tarja.
    // C10 — sob autoridade canônica quem classifica é o motor canônico, o mesmo
    // que pontua no fim da rodada: a tarja nunca discorda do placar.
    final tipo = _j.motorConfig.canonicoAtivo
        ? tipoCanonicoDeMeld(cartas, _j.specCanonica)
        : (_j._validarJogoMesa(cartas)['valido'] == true
            ? _j._validarJogoMesa(cartas)['tipo'] as String?
            : null);
    if (tipo == null) return Sash.nenhuma;
    switch (tipo) {
      case 'limpa':
        return Sash.limpa;
      case 'suja':
        return Sash.suja;
      case 'de_500':
        return Sash.n500;
      case 'as_a_as':
        return Sash.n1000;
      default:
        return Sash.nenhuma;
    }
  }

  String _sashLabel(Sash sash) {
    switch (sash) {
      case Sash.limpa:
        return 'LIMPA · 200';
      case Sash.suja:
        return 'SUJA · 100';
      case Sash.n500:
        return 'CANASTRA · 500';
      case Sash.n1000:
        return 'CANASTRA · 1000';
      case Sash.nenhuma:
        return '';
    }
  }

  Color _sashColor(Sash sash) {
    switch (sash) {
      case Sash.limpa:
        return const Color(0xFF9D43D8);
      case Sash.suja:
        return const Color(0xFF4B7ED8);
      case Sash.n500:
        return const Color(0xFFC44CCB);
      case Sash.n1000:
        return const Color(0xFFE5B84F);
      case Sash.nenhuma:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _board()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(3, 3, 3, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: _mGold, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: _headerMetric(
              Icons.group_work_rounded,
              'Modalidade',
              _modalidade,
              _mPurpleHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 21,
            child: _headerMetric(
              Icons.monetization_on_rounded,
              'Mesa',
              '${_j.metaPontos}',
              _mGoldHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 19,
            child: _headerMetric(
              Icons.sync_rounded,
              'Rodada',
              '${_j.rodada}',
              _mPurpleHi,
            ),
          ),
          _headerDivider(),
          Expanded(
            flex: 32,
            child: _scoreMetric(),
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(
        width: 1,
        height: 45,
        color: const Color(0x665B421C),
      );

  Widget _headerMetric(
      IconData icon, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          Icon(icon, color: _mGold, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFFF2E7C8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreMetric() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: _mGold, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pontuação',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFFF2E7C8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Nós ',
                          style: TextStyle(color: _mPurpleHi),
                        ),
                        TextSpan(
                          text: '${_j.placar['nos']! + _j.pontosMesaAoVivo('nos')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const TextSpan(
                          text: '  Eles ',
                          style: TextStyle(color: Color(0xFFF1C15B)),
                        ),
                        TextSpan(
                          text: '${_j.placar['eles']! + _j.pontosMesaAoVivo('eles')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Núcleo central deliberadamente compacto. A altura economizada é
        // devolvida principalmente à área de jogos da dupla de baixo.
        const centralHeight = 104.0; // núcleo mais compacto (centro menor)
        const playerDockHeight = 170.0; // HUD mais baixo; mão preservada
        return Container(
          margin: const EdgeInsets.fromLTRB(3, 0, 3, 3),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE6A1), Color(0xFF6A4415), Color(0xFFE0B45D)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _feltColor,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border.all(color: const Color(0xFF15100A), width: 1.5),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _mesaVip
                        ? const _VipFeltPainter()
                        : const _PublicFeltPainter(),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 12,
                        child: _meldArea('eles', top: true),
                      ),
                      SizedBox(height: centralHeight, child: _centralTray()),
                      Expanded(
                        flex: 12,
                        child: _meldArea('nos', top: false),
                      ),
                      const SizedBox(height: playerDockHeight),
                    ],
                  ),
                ),
                Positioned(
                  left: 1,
                  top: 56,
                  child: _sidePlayer(1, left: true),
                ),
                Positioned(
                  right: 1,
                  top: 56,
                  child: _sidePlayer(3, left: false),
                ),
                Positioned(
                  left: 1,
                  bottom: playerDockHeight + 8,
                  child: _sidePlayer(2, left: true),
                ),
                // Chat / expressões / som — coluna vertical discreta na lateral direita.
                Positioned(
                  right: 4,
                  bottom: playerDockHeight + 8,
                  child: _actionRail(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: playerDockHeight,
                  child: _playerDock(),
                ),
                if (_msg != null)
                  Positioned.fill(
                    child: Align(
                      alignment: const Alignment(0, -0.12),
                      child: _feedbackToast(),
                    ),
                  ),
                if (_j.rodadaEncerrada)
                  Positioned.fill(child: _overlayFimRodada()),
                if (_expandedAvatarSeat != null)
                  Positioned.fill(
                    child: _avatarOverlay(_expandedAvatarSeat!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _meldArea(String dupla, {required bool top}) {
    final jogos = _j.jogosDupla[dupla]!;
    final vulnerabilidade = _vulnerabilidadeDaDupla(dupla);
    final podeBaixar = dupla == 'nos' &&
        _minhaVezAtiva &&
        _j.jaComprou &&
        _sel.length >= 3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: dupla == 'nos' ? _baixar : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A área de jogos sempre ocupa toda a largura útil da mesa.
          // Cada jogo conserva sua largura natural e o Wrap organiza os blocos
          // lado a lado; quando não há espaço, o próximo jogo desce de linha.
          final larguraUtil = max(0.0, constraints.maxWidth);

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: jogos.isEmpty
                    ? (podeBaixar
                        ? Center(
                            child: AnimatedOpacity(
                              opacity: 1,
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                'TOQUE NO FELTRO PARA BAIXAR',
                                style: TextStyle(
                                  color: _mPurpleHi,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.hardEdge,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: larguraUtil,
                            maxWidth: larguraUtil,
                          ),
                          child: _packedMelds(dupla, jogos, larguraUtil),
                        ),
                      ),
              ),
              Positioned(
                top: 6,
                left: 7,
                right: 7,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _areaLabel(top ? 'ELES' : 'NÓS', top: top),
                      if (vulnerabilidade != null) ...[
                        const SizedBox(width: 7),
                        _vulnerabilityBadge(vulnerabilidade),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _areaLabel(String label, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x88000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x337D5A24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: top ? const Color(0xFFD7A45A) : const Color(0xFFC67BFF),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _vulnerabilityBadge(int valor) {
    final accent = valor >= 95
        ? const Color(0xFFE86A80)
        : const Color(0xFFE5B84F);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xEE160D12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent, width: 1),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.45), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: accent, size: 12),
            const SizedBox(width: 4),
            Text(
              'VULNERABILIDADE +$valor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7.4,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empacotamento dos jogos (patch item 8): aproveita toda a largura útil.
  // First-Fit-Decreasing — coloca os blocos MAIORES primeiro e encaixa os
  // menores nas lacunas das linhas já abertas. Cada jogo é um bloco INDIVISÍVEL
  // (nunca quebra a sequência); só a POSIÇÃO do bloco muda. Dentro da linha,
  // reordena por índice original pra manter a leitura estável.
  Widget _packedMelds(String dupla, List<List<Carta>> jogos, double larguraUtil) {
    const double cardWidth = 66.0; // igual ao _meldWidget
    const double step = 20.0; // desloc. horizontal maior: índice+naipe visíveis
    const double spacing = 12.0; // P0-A: gap entre melds distintos (com divisor discreto)
    const double runSpacing = 6.0;
    double larguraJogo(List<Carta> m) =>
        cardWidth + (m.length - 1).clamp(0, 999) * step;

    // índices por linha (FFD) — função pura, MESMA usada no teste AUD-02
    final linhas = Jogo.empacotarLinhasFFD(
        [for (final g in jogos) larguraJogo(g)], larguraUtil, spacing);

    if (kAuditoriaRegras) {
      for (var r = 0; r < linhas.length; r++) {
        if (linhas[r].length < 2) continue;
        // DOIS+ jogos DISTINTOS na MESMA linha: risco de "colagem" visual.
        debugPrint('[AUD render/_packedMelds] dupla=$dupla linha=$r '
            'jogos=${linhas[r].length} gap_entre_jogos=${spacing}px '
            'sobreposicao_interna_step=${step}px '
            '${spacing < step ? '(gap < step → PODEM PARECER 1 JOGO SÓ)' : ''}');
        for (var p = 0; p < linhas[r].length; p++) {
          final idx = linhas[r][p];
          final m = jogos[idx];
          debugPrint('    jogo[$idx] = {${Jogo.descreverMeld(m)}}');
          if (p > 0) {
            final ant = jogos[linhas[r][p - 1]];
            final ultimaAnt = ant.isNotEmpty ? ant.last : null;
            final primeiraAtual = m.isNotEmpty ? m.first : null;
            debugPrint('      fronteira: ultima_do_jogo_${linhas[r][p - 1]}='
                '${ultimaAnt == null ? '-' : Jogo.descreverMeld([ultimaAnt])} | '
                'primeira_do_jogo_$idx='
                '${primeiraAtual == null ? '-' : Jogo.descreverMeld([primeiraAtual])} | '
                'gap=${spacing}px step=${step}px');
          }
          // Confirmação específica do caso A♥/A♦: ases de naipes DIFERENTES em
          // jogos DISTINTOS colados na mesma linha (é render, não estado).
          for (var q = 0; q < p; q++) {
            final outro = jogos[linhas[r][q]];
            for (final a in m.where((c) => c.valor == 'A')) {
              for (final b in outro.where((c) => c.valor == 'A' && c.naipe != a.naipe)) {
                debugPrint('[AUD A♥/A♦] ases de naipes DIFERENTES em MELDS DIFERENTES '
                    'colados: jogo[$idx] tem ${a.valor}/${a.naipe}#${a.id} e '
                    'jogo[${linhas[r][q]}] tem ${b.valor}/${b.naipe}#${b.id} '
                    '→ são jogos SEPARADOS (render/colagem), NÃO um meld ilegal.');
              }
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < linhas.length; r++) ...[
          if (r > 0) const SizedBox(height: runSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k < linhas[r].length; k++) ...[
                // P0-A: separador SÓ entre melds distintos — gap 12px com um
                // divisor dourado discreto de 1px (não parece parte de carta).
                if (k > 0)
                  const SizedBox(
                    width: spacing,
                    height: 77,
                    child: Center(
                      child: SizedBox(
                        width: 1,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x66E5B84F)),
                        ),
                      ),
                    ),
                  ),
                _meldWidget(dupla, linhas[r][k], jogos[linhas[r][k]]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _meldWidget(String dupla, int index, List<Carta> cartas) {
    cartas = _j.ordenarMeld(cartas); // jogo baixado em ordem crescente
    final subs = _j.substitutosMeld(cartas); // #9: coringa mostra a carta que ocupa
    // #2: tamanho único da mesa (grande, boa visualização) — igual monte/lixo/mão.
    // Patch visual: sobreposição mais fechada (13) mantendo a carta no mesmo tamanho.
    const cardWidth = 66.0;
    const cardHeight = 77.0; // proporção real do asset 907x1058 (66 * 1058/907)
    const step = 20.0; // igual ao _packedMelds: índice+naipe visíveis em cada carta
    final count = cartas.length;
    final totalWidth = cardWidth + (count - 1) * step;
    final sash = _sashDeMeld(cartas);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (dupla == 'nos' &&
            _sel.isNotEmpty &&
            _minhaVezAtiva &&
            _j.jaComprou) {
          _estender(index);
        } else {
          _showMeldZoom(dupla, index);
        }
      },
      child: SizedBox(
        width: totalWidth,
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                left: i * step,
                top: 0,
                child: _meldCardFace(
                  cartas[i],
                  subs[i],
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
            if (sash != Sash.nenhuma)
              Positioned(
                left: 1,
                right: 1,
                bottom: 0,
                child: _canastraRibbon(sash, false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _canastraRibbon(Sash sash, bool celebrating) {
    final color = _sashColor(sash);
    return AnimatedScale(
      scale: celebrating ? 1.04 : 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.96),
              Color.lerp(color, Colors.black, 0.52)!.withOpacity(0.96),
            ],
          ),
          border: Border.all(color: _mGoldHi, width: 0.8),
        ),
        child: Text(
          _sashLabel(sash),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.45,
          ),
        ),
      ),
    );
  }

  Widget _centralTray() {
    // #2: monte/lixo/mortos no MESMO tamanho da mesa e da mão (medida única).
    const cardWidth = 66.0;
    const cardHeight = 77.0; // proporção real do asset 907x1058 (66 * 1058/907)
    final podeComprar = _minhaVezAtiva && !_j.jaComprou;
    final podeDescartar = _minhaVezAtiva && _j.jaComprou && _sel.length == 1;
    final monteGlow = podeComprar ||
        (_lastPurchaseSource == 'monte' && _recentlyBoughtIds.isNotEmpty);
    final lixoGlow = podeDescartar ||
        (_lastPurchaseSource == 'lixo' && _recentlyBoughtIds.isNotEmpty);

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _mPanel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF8C6729), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _centralPile(
            bottomLabel: 'MONTE',
            count: _j.monte.length,
            child: _backCard(
              width: cardWidth,
              height: cardHeight,
              glowing: monteGlow,
            ),
            onTap: _tapMonte,
          ),
          const SizedBox(width: 5),
          Expanded(child: _discardPile(glowing: lixoGlow)),
          const SizedBox(width: 5),
          _centralPile(
            topLabel: 'MORTO',
            bottomLabel: '1',
            showCount: false,
            child: _j.mortos.isNotEmpty
                ? _backCard(width: cardWidth, height: cardHeight)
                : _emptyCard(width: cardWidth, height: cardHeight),
          ),
          const SizedBox(width: 5),
          _centralPile(
            topLabel: 'MORTO',
            bottomLabel: '2',
            showCount: false,
            child: _j.mortos.length > 1
                ? _backCard(width: cardWidth, height: cardHeight)
                : _emptyCard(width: cardWidth, height: cardHeight),
          ),
        ],
      ),
    );
  }

  Widget _centralPile({
    String? topLabel,
    required String bottomLabel,
    int count = 0,
    bool showCount = true,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final content = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        if (topLabel != null)
          Positioned(
            left: 3,
            right: 3,
            top: 3,
            child: _centralOverlayLabel(topLabel, compact: true),
          ),
        Positioned(
          left: 3,
          right: 3,
          bottom: 3,
          child: _centralOverlayLabel(bottomLabel),
        ),
        if (showCount)
          Positioned(
            top: -5,
            right: -5,
            child: _countCircle(count),
          ),
      ],
    );

    return onTap == null
        ? content
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          );
  }

  Widget _centralOverlayLabel(String text, {bool compact = false}) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 3,
        vertical: compact ? 1 : 1.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xD90A080B),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x668C6729), width: 0.6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFFF0DFB7),
          fontSize: compact ? 6.4 : 7,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: compact ? 0.25 : 0.45,
        ),
      ),
    );
  }

  Widget _discardPile({required bool glowing}) {
    const cardWidth = 66.0;
    const cardHeight = 77.0; // proporção real do asset 907x1058 (66 * 1058/907)
    const step = 18.0;
    final aberto = _modalidade.toLowerCase() == 'aberto';
    final cards = aberto
        ? _j.lixo
        : (_j.lixo.isEmpty ? <Carta>[] : <Carta>[_j.lixo.last]);
    final totalWidth = cards.isEmpty
        ? cardWidth
        : cardWidth + (cards.length - 1) * step;

    return GestureDetector(
      onTap: _tapLixo,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: glowing
                  ? Border.all(color: _mPurpleHi, width: 1.2)
                  : null,
            ),
            child: cards.isEmpty
                ? _emptyCard(width: cardWidth, height: cardHeight)
                : SingleChildScrollView(
                    controller: aberto ? _discardScroll : null,
                    scrollDirection: Axis.horizontal,
                    physics: aberto
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalWidth,
                      height: cardHeight,
                      child: Stack(
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            Positioned(
                              left: i * step,
                              child: _frontCard(
                                cards[i],
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: 3,
            right: 3,
            bottom: 3,
            child: _centralOverlayLabel(aberto ? 'LIXO ABERTO' : 'LIXO'),
          ),
          // Contador do lixo — SOBRE a carta do topo (canto sup. dir. da carta),
          // longe do monte e dos mortos pra não poluir aquele canto.
          Positioned(
            top: -6,
            left: cardWidth - 22,
            child: _countCircle(_j.lixo.length),
          ),
        ],
      ),
    );
  }

  // Carta de um jogo baixado: se for um CORINGA que ocupa outra carta (#9),
  // mostra a FACE da carta substituída + um selo ★ discreto no canto pra deixar
  // claro que ali mora um coringa. Cartas normais caem no _frontCard de sempre.
  Widget _meldCardFace(
    Carta original,
    Carta? substituto, {
    required double width,
    required double height,
  }) {
    if (substituto == null) {
      return _frontCard(original, width: width, height: height);
    }
    // Curinga baixado (aprovado pela Sônia, 03/08): a carta renderizada é
    // SEMPRE o curinga REAL (joker.webp / o próprio 2) — NUNCA a carta
    // substituída. O motor mantém internamente o valor substituído para validar
    // a sequência; aqui ele aparece só como indicação DISCRETA "=X".
    // Vale para os jogos na mesa E para o modal ampliado (mesma função).
    final String repr = _cartaRotulo(substituto); // valor representado: '5','J'…
    final BorderRadius raio = BorderRadius.circular(width * 0.09);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // arte REAL do curinga na casa que ele ocupa (joker.webp / o 2)
        _frontCard(original, width: width, height: height),
        // contorno violeta fino: sinal discreto de "aqui mora um curinga"
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: raio,
                border: Border.all(color: _mPurple, width: 1.2),
              ),
            ),
          ),
        ),
        // indicação discreta do valor representado (=X), sem cobrir a arte
        Positioned(
          left: width * 0.05,
          bottom: width * 0.05,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.07, vertical: width * 0.015),
            decoration: BoxDecoration(
              color: const Color(0xE64B2367),
              borderRadius: BorderRadius.circular(width * 0.11),
              border: Border.all(color: _mGoldHi, width: 0.6),
            ),
            child: Text(
              '=$repr',
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.19,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _frontCard(
    Carta carta, {
    required double width,
    required double height,
  }) {
    // Patch visual: SEM moldura/stroke e SEM sombra — o feltro aparece direto
    // atrás da carta. Só cantos arredondados + recorte da imagem.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        _cartaAsset(carta),
        fit: BoxFit.contain, // proporção 907/1058 sem deformar
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _backCard({
    required double width,
    required double height,
    bool glowing = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.1),
        gradient: glowing
            ? const LinearGradient(colors: [_mPurpleHi, _mGoldHi])
            : const LinearGradient(colors: [_mGoldHi, Color(0xFF694317)]),

      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.08),
        child: Image.asset(
          _cardBackAsset,
          fit: BoxFit.contain, // proporção 907/1058 sem deformar
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _emptyCard({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x12000000),
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: const Color(0x558C6729), width: 1),
      ),
      child: const Icon(Icons.style_outlined, color: Color(0x447B3F91), size: 25),
    );
  }

  Widget _countCircle(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: count < 10 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: count < 10 ? null : BorderRadius.circular(12),
        color: const Color(0xEE080808),
        border: Border.all(color: _mGold, width: 1.2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _mGoldHi,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _sidePlayer(int seat, {required bool left}) {
    final active = _j.vez == seat && !_j.rodadaEncerrada;
    final count = _j.maos[seat].length;

    // Fora do turno o assento não reserva largura da mesa: somente uma pequena
    // aba fica visível na borda. O avatar abre apenas no turno ou por toque.
    if (!active) {
      return GestureDetector(
        onTap: () => setState(() => _expandedAvatarSeat = seat),
        child: SizedBox(
          width: 12,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left ? -7 : null,
                right: left ? null : -7,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xEE100B12),
                    borderRadius: BorderRadius.horizontal(
                      right: left ? const Radius.circular(10) : Radius.zero,
                      left: left ? Radius.zero : const Radius.circular(10),
                    ),
                    border: Border.all(color: _mGold, width: 1),
                  ),
                ),
              ),
              Positioned(
                left: left ? -2 : null,
                right: left ? null : -2,
                top: 11,
                child: Container(
                  width: 18,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xF20A0A0A),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _mGold, width: 1),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: _mGoldHi,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _expandedAvatarSeat = seat),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xEE100B12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _mGold, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatarCircle(seat, size: 42, active: true),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                _j.apelidos[seat].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFEADCC1),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _countCircle(count),
            const SizedBox(height: 3),
            _turnBadge(compact: true),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle(int seat,
      {required double size, required bool active}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.25, -0.35),
          colors: [Color(0xFF4E2E65), Color(0xFF140C17)],
        ),
        border: Border.all(
          color: active ? _mPurpleHi : _mGold,
          width: active ? 2.8 : 2,
        ),

      ),
      child: Text(
        _j.avatares[seat],
        style: TextStyle(fontSize: size * 0.42, color: _mGoldHi),
      ),
    );
  }

  Widget _turnBadge({bool compact = false}) {
    final danger = _turnSeconds <= 10;
    final size = compact ? 33.0 : 52.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF090909),
        border: Border.all(
          color: danger ? const Color(0xFFFF5D68) : _mPurpleHi,
          width: compact ? 2 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (danger ? const Color(0xFFFF5D68) : _mPurple)
                .withOpacity(0.55),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_turnSeconds',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 12 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (!compact)
            const Text(
              'SEG',
              style: TextStyle(
                color: Color(0xFFD8C8E8),
                fontSize: 6,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railButton(Icons.chat_bubble_rounded, () {
          setState(() => _msg = 'Chat — ligação final com o Claude.');
        }),
        const SizedBox(height: 7),
        _railButton(Icons.sentiment_satisfied_alt_rounded, () {
          setState(() => _msg = 'Expressões — ligação final com o Claude.');
        }),
        const SizedBox(height: 7),
        _railButton(
          _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          () => setState(() => _soundEnabled = !_soundEnabled),
        ),
      ],
    );
  }

  Widget _railButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xEE0A0A0A),
          border: Border.all(color: _mGold, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: _mGoldHi, size: 20),
      ),
    );
  }

  Widget _playerDock() {
    final active = _j.vez == 0 && !_j.rodadaEncerrada;
    return Column(
      children: [
        SizedBox(
          height: 42, // HUD do jogador mais baixo (libera altura p/ jogos)
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _expandedAvatarSeat = 0),
                child: _avatarCircle(0, size: 40, active: active),
              ),
              const SizedBox(width: 7),
              Text(
                'VOCÊ  •  ${_j.maos[0].length} cartas',
                style: TextStyle(
                  color: active ? _mPurpleHi : _mGoldHi,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 10),
                _turnBadge(compact: true),
              ],
              // Chat/expressões/som agora ficam numa coluna vertical à direita
              // da mesa (_actionRail no _board). Aqui no rodapé fica só o jogador.
            ],
          ),
        ),
        Expanded(
          child: Padding(
            // margem inferior segura em aparelhos com barra de navegação (#8)
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewPadding.bottom,
            ),
            child: _hand(),
          ),
        ),
      ],
    );
  }

  Widget _hand() {
    final hand = _j.maos[0];
    final count = hand.length;
    if (count == 0) return const SizedBox();

    // #2: mão no MESMO tamanho da mesa/monte/lixo (medida única em todo o jogo).
    const cardWidth = 66.0;
    const cardHeight = 77.0; // proporção real do asset 907x1058 (66 * 1058/907)
    // Sobreposição compacta e AUTOMÁTICA conforme a quantidade: trecho visível
    // de cada carta entre 32% (poucas cartas) e 25% (muitas) da largura, sem
    // reduzir a carta. A última carta continua inteira (Stack) e a mão mantém
    // scroll horizontal. Ajuste SÓ visual — não altera estado, seleção nem regras.
    // Mão do jogador com passo horizontal MAIOR (índice+naipe sempre visíveis):
    // ~0.42 (poucas cartas → passo ~28px) reduzindo até ~0.33 (mãos grandes → ~22px).
    // Carta mantida 66x77; scroll horizontal preservado.
    final double frac = count <= 12
        ? 0.42
        : count >= 24
            ? 0.33
            : 0.42 - (count - 12) * (0.09 / 12);
    final double step = cardWidth * frac;
    const selectedLift = 8.0; // elevação da selecionada reduzida (P0-A/mão)
    final active = _minhaVezAtiva;
    final totalWidth = cardWidth + (count - 1) * step;

    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) {
        final priorityA = (_sel.contains(a) ? 2 : 0) +
            (_recentlyBoughtIds.contains(hand[a].id) ? 1 : 0);
        final priorityB = (_sel.contains(b) ? 2 : 0) +
            (_recentlyBoughtIds.contains(hand[b].id) ? 1 : 0);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        return a.compareTo(b);
      });

    final cards = SizedBox(
      width: totalWidth,
      height: cardHeight + selectedLift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final index in order)
            Positioned(
              left: index * step,
              bottom: 0,
              child: GestureDetector(
                onTap: active ? () => _tapCard(index) : null,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  offset: Offset(
                    0,
                    // Mão sempre RETA: só a carta selecionada sobe. As recém-compradas
                    // ficam alinhadas (o destaque delas é a moldura dourada, não a altura).
                    _sel.contains(index) ? -selectedLift / cardHeight : 0,
                  ),
                  child: _handCard(
                    hand[index],
                    selected: _sel.contains(index),
                    purchased: _recentlyBoughtIds.contains(hand[index].id),
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -7,
            right: -8,
            child: _countCircle(count),
          ),
        ],
      ),
    );

    return ClipRect(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: Offset(0, active ? 0 : 0.50),
        child: SingleChildScrollView(
          controller: _handScroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, selectedLift, 14, 0),
          child: cards,
        ),
      ),
    );
  }

  Widget _handCard(
    Carta carta, {
    required bool selected,
    required bool purchased,
    required double width,
    required double height,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        height: height,
        padding: EdgeInsets.all(selected || purchased ? 2 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: purchased
              ? const LinearGradient(colors: [_mGoldHi, _mPurpleHi, _mGold])
              : (selected
                  ? const LinearGradient(colors: [_mPurpleHi, _mGoldHi, _mPurple])
                  : null),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _cartaAsset(carta),
                  fit: BoxFit.contain, // proporção 907/1058 sem deformar
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            if (purchased)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white, _mGold]),
                    boxShadow: [BoxShadow(color: _mGoldHi, blurRadius: 8)],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 10,
                    color: Color(0xFF4E2D05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackToast() {
    final text = _msg ?? '';
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xF2140D16),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xAA9D43D8)),
            boxShadow: const [
              BoxShadow(color: Color(0x559D43D8), blurRadius: 8),
            ],
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF3E9FF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// C10 — rótulo legível de UM candidato de compra do lixo, para o seletor.
  /// Descreve o que a transação faz; não decide nada.
  String _rotuloCandidatoLixo(ComprarLixo c) {
    final partes = <String>[];
    final mesa = _j.jogosDupla['nos']!;
    for (final ext in c.extensoes) {
      final cartas = _cartasPorIds(ext.cartas).map(_cartaRotulo).join(' ');
      partes.add('estender o jogo ${ext.indiceJogo + 1} com $cartas');
    }
    for (final jogo in c.jogosNovos) {
      final cartas = _cartasPorIds(jogo).map(_cartaRotulo).join(' ');
      partes.add('baixar $cartas');
    }
    if (partes.isEmpty) return 'pegar o lixo';
    // Mostra o tamanho do jogo estendido para o jogador comparar alternativas.
    if (c.jogosNovos.isEmpty && c.extensoes.length == 1) {
      final i = c.extensoes.single.indiceJogo;
      if (i >= 0 && i < mesa.length) {
        partes[0] = '${partes[0]} (jogo de ${mesa[i].length} cartas)';
      }
    }
    return partes.join(' + ');
  }

  List<Carta> _cartasPorIds(List<String> ids) {
    final visiveis = <Carta>[..._j.maos[0], if (_j.lixo.isNotEmpty) _j.lixo.last];
    return [
      for (final id in ids)
        ...visiveis.where((c) => c.id == id).take(1),
    ];
  }

  /// C10 (rev.1) — SELETOR MÍNIMO das PARTIÇÕES da seleção. Mesma regra do
  /// seletor do lixo: a autoridade enumera tudo, a folha só apresenta, e
  /// cancelar não baixa nada.
  Future<Baixar?> _escolherParticao(List<Baixar> particoes) {
    String rotulo(Baixar b) => b.jogosNovos
        .map((g) => _cartasPorIds(g).map(_cartaRotulo).join(' '))
        .join('  +  ');
    return _escolherNaFolha<Baixar>(
      titulo: 'Como baixar estas ${_sel.length} cartas?',
      subtitulo: 'Há mais de uma forma legal de repartir a seleção.',
      itens: particoes,
      rotulo: rotulo,
    );
  }

  /// C10 — SELETOR MÍNIMO: quando há 2+ usos legais do topo, quem escolhe é o
  /// jogador. A lista vem inteira da autoridade canônica (nenhum candidato é
  /// omitido); a folha só apresenta. Cancelar não compra nada.
  Future<ComprarLixo?> _escolherCompraLixo(List<ComprarLixo> cands) {
    final topo = _j.lixo.isEmpty ? '' : _cartaRotulo(_j.lixo.last);
    return _escolherNaFolha<ComprarLixo>(
      titulo: 'Como usar o topo ($topo)?',
      subtitulo: 'O lixo só vem junto com um destes usos.',
      itens: cands,
      rotulo: _rotuloCandidatoLixo,
    );
  }

  /// Folha de escolha ÚNICA para os dois seletores mínimos (uso do topo e
  /// partição da seleção). Só apresenta a lista que a autoridade produziu —
  /// nada é omitido, ordenado por preferência nem pré-selecionado. Cancelar
  /// devolve null e não executa nada.
  Future<T?> _escolherNaFolha<T>({
    required String titulo,
    required String subtitulo,
    required List<T> itens,
    required String Function(T) rotulo,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xF4120D14),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _mGold, width: 1.1),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: _mGoldHi,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: const TextStyle(color: Color(0xFFB6A8BE), fontSize: 10.5),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => Navigator.of(ctx).pop(itens[i]),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1220),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _mPurple, width: 1),
                      ),
                      child: Text(
                        rotulo(itens[i]),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12.2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFFB6A8BE))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMeldZoom(String dupla, int index) {
    final jogos = _j.jogosDupla[dupla]!;
    if (index < 0 || index >= jogos.length) return;
    final cards = _j.ordenarMeld(jogos[index]); // ampliado em ordem
    final subs = _j.substitutosMeld(cards); // #9: coringa ocupa a carta
    final sash = _sashDeMeld(cards);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar jogo ampliado',
      barrierColor: const Color(0xCC000000),
      transitionDuration: const Duration(milliseconds: 230),
      pageBuilder: (_, __, ___) {
        const width = 92.0;
        const height = 107.0; // proporção real 907/1058 (92 * 1058/907) — sem letterbox
        const step = 49.0;
        final total = width + (cards.length - 1) * step;
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
                    decoration: BoxDecoration(
                      color: const Color(0xF4120D14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _mGold, width: 1.3),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAA9D43D8), blurRadius: 22),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              dupla == 'nos' ? 'JOGO — NÓS' : 'JOGO — ELES',
                              style: const TextStyle(
                                color: _mGoldHi,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            _countCircle(cards.length),
                          ],
                        ),
                        if (sash != Sash.nenhuma) ...[
                          const SizedBox(height: 7),
                          _canastraRibbon(sash, false),
                        ],
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: total,
                            height: height,
                            child: Stack(
                              children: [
                                for (var i = 0; i < cards.length; i++)
                                  Positioned(
                                    left: i * step,
                                    child: _meldCardFace(
                                      cards[i],
                                      subs[i],
                                      width: width,
                                      height: height,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Toque fora para recolher',
                          style: TextStyle(
                            color: Color(0xFFBFAECD),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _avatarOverlay(int seat) {
    return GestureDetector(
      onTap: () => setState(() => _expandedAvatarSeat = null),
      child: Container(
        color: const Color(0xB8000000),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          builder: (_, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: Container(
            width: 190,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
            decoration: BoxDecoration(
              color: const Color(0xF4150D18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _mGold, width: 1.4),
              boxShadow: const [
                BoxShadow(color: Color(0xAA9D43D8), blurRadius: 25),
                BoxShadow(color: Color(0x66E5B84F), blurRadius: 14),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _avatarCircle(
                  seat,
                  size: seat == 0 ? 122 : 92,
                  active: _j.vez == seat && !_j.rodadaEncerrada,
                ),
                const SizedBox(height: 12),
                Text(
                  _j.apelidos[seat].toUpperCase(),
                  style: const TextStyle(
                    color: _mPurpleHi,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_j.maos[seat].length} cartas na mão',
                  style: const TextStyle(
                    color: Color(0xFFE2D4B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Toque fora para fechar',
                  style: TextStyle(
                    color: Color(0xFFB6A8BE),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DetalhePontuacaoVM _detalhePontuacao(String dupla) {
    final rodada = _j.pontosRodada;
    if (rodada == null) return DetalhePontuacaoVM.vazio();
    final bruto = rodada[dupla];
    if (bruto is! Map<String, dynamic>) return DetalhePontuacaoVM.vazio();
    final detalhe = bruto['detalhe'];
    final det = detalhe is Map<String, dynamic>
        ? detalhe
        : <String, dynamic>{};
    return DetalhePontuacaoVM(
      total: (bruto['total'] as int?) ?? 0,
      canastras: (bruto['canastras'] as int?) ?? 0,
      cartasBaixadas: (det['baixadas'] as int?) ?? 0,
      bonusBatida: (bruto['bonusBatida'] as int?) ?? 0,
      descontoMao: (bruto['descontoMao'] as int?) ?? 0,
      penalidadeMorto: (bruto['penalidadeMorto'] as int?) ?? 0,
      limpas: (det['limpas'] as int?) ?? 0,
      sujas: (det['sujas'] as int?) ?? 0,
      de500: (det['de500'] as int?) ?? 0,
      de1000: (det['asAas'] as int?) ?? 0,
    );
  }

  List<JogadorResultadoVM> _jogadoresResultado() {
    return List<JogadorResultadoVM>.generate(
      _j.apelidos.length,
      (seat) => JogadorResultadoVM(
        assento: seat,
        nome: _j.apelidos[seat],
        avatar: _j.avatares[seat],
        souEu: seat == 0,
      ),
    );
  }

  void _continuarRodada() {
    setState(() {
      _j.novaRodada();
      _sel.clear();
      _msg = null;
      _conviteRevancheEnviado = false;
      _anuncioAssistido = false;
      _syncTurnClock(force: true);
    });
    // §3.2: o iniciador rotaciona a cada rodada — se for robô, eles começam.
    if (_j.vez != 0 && !_j.rodadaEncerrada) _rodarBots();
  }

  void _convidarRevanche() {
    setState(() {
      _conviteRevancheEnviado = true;
      _msg = 'Convite de revanche enviado para a mesa.';
    });
  }

  void _jogarNovamente() {
    setState(() {
      _j = _novoJogo();
      _sel.clear();
      _msg = null;
      _conviteRevancheEnviado = false;
      _anuncioAssistido = false;
      _syncTurnClock(force: true);
    });
  }

  void _adicionarAmigo(int seat) {
    if (seat == 0) return;
    setState(() {
      _amizades[seat] = EstadoAmizade.enviado;
      _msg = 'Convite de amizade enviado para ${_j.apelidos[seat]}.';
    });
  }

  void _verAnuncioRecompensado() {
    if (!_anuncioDisponivel || _anuncioAssistido || _assinanteSemAnuncios) {
      return;
    }
    setState(() {
      _anuncioAssistido = true;
      _msg = 'Recompensa do anúncio registrada na prévia.';
    });
  }

  void _voltarAoLobby() {
    Navigator.of(context).pop();
  }

  Widget _overlayFimRodada() {
    final finalPartida = _j.encerrada;
    String title;
    if (finalPartida) {
      title = _j.placar['nos']! >= _j.placar['eles']!
          ? 'NÓS VENCEMOS!'
          : 'ELES VENCERAM';
    } else if (_j.duplaQueBateu == 'nos') {
      title = 'NÓS BATEMOS!';
    } else if (_j.duplaQueBateu == 'eles') {
      title = 'ELES BATERAM';
    } else {
      title = 'BARALHO ESGOTADO';
    }

    return ResultadoPartidaScreen(
      fimPartida: finalPartida,
      mesaVip: _mesaVip,
      rodada: _j.rodada,
      titulo: title,
      pontosNos: _j.placar['nos'] ?? 0,
      pontosEles: _j.placar['eles'] ?? 0,
      detalheNos: _detalhePontuacao('nos'),
      detalheEles: _detalhePontuacao('eles'),
      jogadores: _jogadoresResultado(),
      amizades: Map<int, EstadoAmizade>.unmodifiable(_amizades),
      conviteRevancheEnviado: _conviteRevancheEnviado,
      anuncioDisponivel: _anuncioDisponivel,
      anuncioAssistido: _anuncioAssistido,
      assinanteSemAnuncios: _assinanteSemAnuncios,
      recompensaAnuncio: '+50 fichas de continuidade',
      onContinuar: _continuarRodada,
      onConvidarRevanche: _convidarRevanche,
      onJogarNovamente: _jogarNovamente,
      onVoltarLobby: _voltarAoLobby,
      onAdicionarAmigo: _adicionarAmigo,
      onVerAnuncio: _verAnuncioRecompensado,
    );
  }

}

enum Sash { nenhuma, limpa, suja, n500, n1000 }
