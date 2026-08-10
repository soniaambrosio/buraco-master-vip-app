// C9-B — ADAPTADOR LEGADO da porta do motor: DELEGA ao motor antigo
// (`mesa.dart`), sem reimplementar regra. É STATELESS sobre a porta: a cada
// chamada reconstrói um `Jogo` transitório a partir do `EstadoJogo` (projeção)
// e invoca o método legado correspondente, projetando o resultado de volta.
//
// LIMITE HONESTO (documentado; nada some em silêncio):
//  • A porta só recebe `EstadoJogo` canônico (sem o EnvelopeRuntime). Logo o
//    transitório usa envelope NEUTRO — nuances operacionais dependentes do
//    envelope (obrigação do topo do lixo, trava do lixo único) só entram no
//    C9-C, onde o runtime carrega o envelope completo.
//  • `Baixar` (atômico/multi-jogo), `PegarMorto` e `Bater` NÃO têm método
//    legado 1:1 (o legado DOBRA morto/batida dentro de `baixar`/`descartar`).
//    Traduzi-los é a "transação semântica" do C9-C: aqui eles retornam uma
//    RECUSA EXPLÍCITA e rotulada (nunca lançam, nunca escondem).
//  • `ehLegal` deriva de `aplicar(...).legal` (mesma construção do canônico) e
//    `acoesLegais` filtra a base por `ehLegal` — refletindo o que o legado
//    EXPÕE diretamente; a divergência com o canônico é justamente o que o
//    C9-C compara.
import '../mesa.dart';
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/rule_spec.dart';
import '../rules/gerador/gerador.dart';
import 'envelope_runtime.dart';
import 'porta_motor.dart';
import 'projecao_estado.dart';

class AdaptadorLegado implements PortaMotor {
  const AdaptadorLegado();

  /// Reconstrói um `Jogo` transitório a partir do estado canônico (envelope
  /// neutro — ver limite honesto no topo).
  Jogo _transitorio(EstadoJogo estado) {
    final j = Jogo.paraCostura();
    aplicarEmJogo(j, estado, EnvelopeRuntime.vazio());
    return j;
  }

  /// Projeta o estado de SAÍDA após uma mutação legada. Limpa o transporte de
  /// fase (setado por `_transitorio`) para que a fase reflita o estado legado
  /// PÓS-operação (derivada de jaComprou; o legado nunca fica em mortoPendente).
  EstadoJogo _saida(Jogo j) {
    j.costuraFaseCanonica = null;
    return paraCanonico(j).canonico;
  }

  @override
  bool ehVez(EstadoJogo estado, int assento) {
    final j = _transitorio(estado);
    return !j.rodadaEncerrada && j.vez == assento;
  }

  @override
  ResultadoJogada aplicar(
      EstadoJogo estado, int assento, Acao acao, RuleSpec spec) {
    final j = _transitorio(estado);
    switch (acao) {
      case ComprarMonte():
        final ok = j.comprarMonte(assento);
        return ok
            ? ResultadoJogada(legal: true, proximoEstado: _saida(j))
            : ResultadoJogada.recusa('motor legado recusou comprarMonte');
      case ComprarLixo():
        final r = j.comprarLixo(assento, modalidade: j.modalidade);
        final ok = r['ok'] == true;
        return ok
            ? ResultadoJogada(legal: true, proximoEstado: _saida(j))
            : ResultadoJogada.recusa(
                (r['erro']?.toString()) ?? 'motor legado recusou comprarLixo');
      case Descartar(carta: final id):
        final err = j.descartar(assento, id);
        return err == null
            ? ResultadoJogada(legal: true, proximoEstado: _saida(j))
            : ResultadoJogada.recusa(err);
      case Baixar():
        return ResultadoJogada.recusa(
            'AdaptadorLegado: Baixar exige transação semântica atômica '
            '(multi-jogo/topo do lixo) — escopo do C9-C.');
      case PegarMorto():
        return ResultadoJogada.recusa(
            'AdaptadorLegado: PegarMorto é dobrado em baixar/descartar no '
            'legado — tradução por transição explícita é do C9-C.');
      case Bater():
        return ResultadoJogada.recusa(
            'AdaptadorLegado: Bater é dobrado em baixar/descartar no legado — '
            'tradução por transição explícita é do C9-C.');
    }
  }

  @override
  bool ehLegal(EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
      aplicar(estado, assento, acao, spec).legal;

  @override
  List<Acao> acoesLegais(EstadoJogo estado, int assento, RuleSpec spec,
      {List<Acao> candidatos = const []}) {
    final base = <Acao>[
      const ComprarMonte(),
      const ComprarLixo(),
      const PegarMorto(),
      const PegarMorto(viaDescarte: true),
      const Bater(),
      for (final c in estado.maos[assento]) Descartar(c.id),
      ...candidatos,
    ];
    return [
      for (final a in base)
        if (ehLegal(estado, assento, a, spec)) a,
    ];
  }
}
