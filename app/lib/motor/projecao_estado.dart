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
Carta _carta(CartaSnapshot s) => Carta(s.id, s.naipe, s.valor, s.curinga);

List<CartaSnapshot> _lcs(List<Carta> l) => [for (final c in l) _cs(c)];
List<Carta> _lc(List<CartaSnapshot> l) => [for (final s in l) _carta(s)];
List<List<CartaSnapshot>> _mcs(List<List<Carta>> m) => [for (final l in m) _lcs(l)];
List<List<Carta>> _mc(List<List<CartaSnapshot>> m) => [for (final l in m) _lc(l)];

// ---- modalidade (CANÔNICO com conversão de tipo String <-> enum) ----
// Legado: 'ABERTO' | 'FECHADO' | 'SBTL'.  Canônico: aberto | fechado | stbl.
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

/// Jogo legado -> (EstadoJogo canônico, EnvelopeRuntime). Só leitura do Jogo.
ProjecaoBMV paraCanonico(Jogo j) {
  final canonico = EstadoJogo(
    // ----- CANÔNICO (1:1) -----
    modalidade: _modDe(j.modalidade),
    metaPontos: j.metaPontos,
    monte: _lcs(j.monte),
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
    // ----- DERIVADO: jaComprou -> fase -----
    // O legado NUNCA fica em `mortoPendente` em repouso (resolvido dentro de
    // descartar/baixar). Logo, snapshot legado => compra | jogo.
    fase: j.jaComprou ? FaseTurno.jogo : FaseTurno.compra,
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
    pontosRodada:
        j.pontosRodada == null ? null : Map<String, Object?>.from(j.pontosRodada!),
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
  alvo.monte = _lc(e.monte);
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
  // ----- DERIVADO: fase -> jaComprou (jogo|mortoPendente => comprou) -----
  alvo.jaComprou = e.fase != FaseTurno.compra;
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
      : Map<String, dynamic>.from(env.pontosRodada!);
}
