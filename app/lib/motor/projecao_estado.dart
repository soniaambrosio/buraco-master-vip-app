// C9-B — PROJEÇÃO Jogo (legado) <-> EstadoJogo (canônico) + EnvelopeRuntime,
// conforme a MATRIZ COMPLETA de estado do PLANO-C9 v2.1:
//   • CANÔNICO  -> round-trip EXATO em EstadoJogo;
//   • DERIVADO  -> reconstruído por função pura (jaComprou <-> fase);
//   • RUNTIME ENVELOPE -> carregado no EnvelopeRuntime (cada campo preservado);
//   • UI/SIDECAR -> pass-through no EnvelopeRuntime;
//   • DESCARTADO -> _rnd (aleatoriedade; ver Replay/C9-C) e constantes estáticas.
// Nenhum campo operacional desaparece silenciosamente. NENHUMA regra aqui.
// `rules/` continua sem importar `mesa.dart` — quem importa os dois é a costura.
import '../mesa.dart';
import '../rules/estado.dart';
import '../rules/modalidade.dart';
import 'envelope_runtime.dart';

/// Resultado da projeção do estado legado: o snapshot canônico + o envelope
/// com tudo que o canônico não modela.
class ProjecaoBMV {
  final EstadoJogo canonico;
  final EnvelopeRuntime envelope;
  const ProjecaoBMV(this.canonico, this.envelope);
}

// ---- conversões de carta (CANÔNICO) ----
CartaSnapshot _cs(Carta c) => CartaSnapshot(c.id, c.naipe, c.valor, c.ehCoringa);

/// PÚBLICA: `Carta` legada -> `CartaSnapshot` canônico. O livro de proveniência
/// do `Jogo` guarda SNAPSHOTS (o registro de um descarte é imutável por
/// natureza), e o caminho legado precisa da MESMA conversão que a projeção usa
/// — duplicá-la criaria uma segunda tradução, com risco de divergir.
CartaSnapshot snapshotDeCarta(Carta c) => _cs(c);
Carta _carta(CartaSnapshot s) => Carta(s.id, s.naipe, s.valor, s.curinga);

List<CartaSnapshot> _lcs(List<Carta> l) => [for (final c in l) _cs(c)];
List<Carta> _lc(List<CartaSnapshot> l) => [for (final s in l) _carta(s)];
List<List<CartaSnapshot>> _mcs(List<List<Carta>> m) => [for (final l in m) _lcs(l)];
List<List<Carta>> _mc(List<List<CartaSnapshot>> m) => [for (final l in m) _lc(l)];

// ---- modalidade (CANÔNICO com conversão de tipo String <-> enum) ----
// Legado: 'ABERTO' | 'FECHADO' | 'SBTL'.  Canônico: aberto | fechado | stbl.
// C10 — PÚBLICA: a costura da pontuação/classificação precisa da MESMA conversão
// para derivar a RuleSpec da partida. Duplicá-la criaria uma segunda autoridade.
Modalidade modalidadeCanonicaDe(String legado) => _modDe(legado);

Modalidade _modDe(String legado) {
  switch (legado.toUpperCase()) {
    case 'FECHADO':
      return Modalidade.fechado;
    case 'SBTL':
    case 'STBL':
      return Modalidade.stbl;
    case 'ABERTO':
    default:
      return Modalidade.aberto;
  }
}

String _modTexto(Modalidade m) {
  switch (m) {
    case Modalidade.fechado:
      return 'FECHADO';
    case Modalidade.stbl:
      return 'SBTL';
    case Modalidade.aberto:
      return 'ABERTO';
  }
}

// ---- FASE (DERIVADO + transporte para preservar as TRÊS fases) ----
// Preferência: o transporte da costura (`costuraFaseCanonica`), que carrega a
// fase canônica EXATA (compra | jogo | mortoPendente). Sem transporte (snapshot
// legado puro), o legado NUNCA fica em repouso em `mortoPendente` — deriva-se
// de `jaComprou`.
FaseTurno _faseCanonicaDe(String? transporte, bool jaComprou) {
  switch (transporte) {
    case 'compra':
      return FaseTurno.compra;
    case 'jogo':
      return FaseTurno.jogo;
    case 'mortoPendente':
      return FaseTurno.mortoPendente;
    default:
      return jaComprou ? FaseTurno.jogo : FaseTurno.compra;
  }
}

// ---- clone PROFUNDO de mapas aninhados (pontosRodada) ----
// Evita referências compartilhadas entre origem/envelope/alvo (o detalhe da
// rodada contém mapas aninhados, ex.: {detalhe: {de500: 1, ...}}).
Object? _deepCloneVal(Object? v) {
  if (v is Map) return _deepMapClone(v);
  if (v is List) return [for (final x in v) _deepCloneVal(x)];
  return v; // primitivos imutáveis
}

Map<String, Object?> _deepMapClone(Map src) {
  final out = <String, Object?>{};
  for (final e in src.entries) {
    out[e.key.toString()] = _deepCloneVal(e.value);
  }
  return out;
}

/// Jogo legado -> (EstadoJogo canônico, EnvelopeRuntime). Só leitura do Jogo.
ProjecaoBMV paraCanonico(Jogo j) {
  final canonico = EstadoJogo(
    // ----- CANÔNICO (1:1) -----
    modalidade: _modDe(j.modalidade),
    metaPontos: j.metaPontos,
    // C9-C: convenção do TOPO do monte difere entre os motores — legado compra
    // `monte.removeAt(0)` (topo = frente), canônico `monte.removeLast()` (topo =
    // último). Para representar a MESMA próxima-compra, o monte é REVERTIDO na
    // projeção (e revertido de volta em aplicarEmJogo). Round-trip permanece
    // exato; sem isto os dois motores comprariam cartas diferentes.
    monte: _lcs(j.monte).reversed.toList(),
    lixo: _lcs(j.lixo),
    mortos: _mcs(j.mortos),
    maos: _mcs(j.maos),
    jogosDupla: {
      for (final e in j.jogosDupla.entries) e.key: _mcs(e.value),
    },
    rodadasVulneravel: {...j.rodadasVulneravel},
    primeiraBaixadaFeita: {...j.primeiraBaixadaFeita},
    vez: j.vez,
    mortoPego: {...j.mortoPego},
    rodadaEncerrada: j.rodadaEncerrada,
    duplaQueBateu: j.duplaQueBateu,
    // ----- DERIVADO + transporte: preserva as TRÊS fases -----
    fase: _faseCanonicaDe(j.costuraFaseCanonica, j.jaComprou),
    // ----- CANÔNICO (1:1): proveniência pública dos descartes da mão -----
    // Round-trip EXATO, como as demais zonas. Não é derivado de nada: se o
    // `Jogo` não tem registro (lixo de fixture, snapshot antigo), a projeção
    // sai vazia em vez de inventar autoria.
    descartes: [for (final d in j.descartes) d.copia()],
  );

  final envelope = EnvelopeRuntime(
    // RUNTIME ENVELOPE — privados (via seam)
    cont: j.costuraCont,
    lixoUnicoCompradoId: j.costuraLixoUnicoCompradoId,
    mortosConvertidos: j.costuraMortosConvertidos,
    iniciadorRodada: j.costuraIniciadorRodada,
    rodadaContada: j.costuraRodadaContada,
    // RUNTIME ENVELOPE — públicos
    lixoTopoObrigatorio: j.lixoTopoObrigatorio,
    integridadeErro: j.integridadeErro,
    assentoQueBateu: j.assentoQueBateu,
    rodada: j.rodada,
    placar: {...j.placar},
    encerrada: j.encerrada,
    pontosRodada: j.pontosRodada == null ? null : _deepMapClone(j.pontosRodada!),
    // UI/SIDECAR
    apelidos: [...j.apelidos],
    avatares: [...j.avatares],
    mascotes: [...j.mascotes],
  );

  return ProjecaoBMV(canonico, envelope);
}

/// Aplica (patch) o estado canônico + envelope de volta num `Jogo` alvo.
/// CANÔNICO: escreve exatamente. DERIVADO: fase -> jaComprou. ENVELOPE: cada
/// campo restaurado. UI/SIDECAR: são `final` no legado — vêm da CONSTRUÇÃO do
/// alvo (`Jogo.paraCostura(apelidos:..., ...)`), por isso não são reatribuídos
/// aqui; o round-trip os preserva via envelope + construção.
void aplicarEmJogo(Jogo alvo, EstadoJogo e, EnvelopeRuntime env) {
  // ----- CANÔNICO -----
  alvo.modalidade = _modTexto(e.modalidade);
  alvo.metaPontos = e.metaPontos;
  // C9-C: reverte de volta o monte (ver paraCanonico) — topo canônico (último)
  // volta a ser o topo legado (frente). Round-trip exato.
  alvo.monte = _lc(e.monte).reversed.toList();
  alvo.lixo = _lc(e.lixo);
  alvo.mortos = _mc(e.mortos);
  alvo.maos = _mc(e.maos);
  alvo.jogosDupla = {
    for (final en in e.jogosDupla.entries) en.key: _mc(en.value),
  };
  alvo.rodadasVulneravel = {...e.rodadasVulneravel};
  alvo.primeiraBaixadaFeita = {...e.primeiraBaixadaFeita};
  alvo.vez = e.vez;
  alvo.mortoPego = {...e.mortoPego};
  alvo.rodadaEncerrada = e.rodadaEncerrada;
  alvo.duplaQueBateu = e.duplaQueBateu;
  alvo.descartes = [for (final d in e.descartes) d.copia()];
  // ----- DERIVADO: fase -> jaComprou (jogo|mortoPendente => comprou) -----
  alvo.jaComprou = e.fase != FaseTurno.compra;
  // ----- TRANSPORTE: carrega a fase canônica EXATA (as três) na costura -----
  alvo.costuraFaseCanonica = e.fase.name;
  // ----- RUNTIME ENVELOPE (privados via seam) -----
  alvo.costuraCont = env.cont;
  alvo.costuraLixoUnicoCompradoId = env.lixoUnicoCompradoId;
  alvo.costuraMortosConvertidos = env.mortosConvertidos;
  alvo.costuraIniciadorRodada = env.iniciadorRodada;
  alvo.costuraRodadaContada = env.rodadaContada;
  // ----- RUNTIME ENVELOPE (públicos) -----
  alvo.lixoTopoObrigatorio = env.lixoTopoObrigatorio;
  alvo.integridadeErro = env.integridadeErro;
  alvo.assentoQueBateu = env.assentoQueBateu;
  alvo.rodada = env.rodada;
  alvo.placar = {...env.placar};
  alvo.encerrada = env.encerrada;
  alvo.pontosRodada = env.pontosRodada == null
      ? null
      : Map<String, dynamic>.from(_deepMapClone(env.pontosRodada!));
}
