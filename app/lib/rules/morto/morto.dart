// C6 — MORTO e BATIDA no motor canônico, sobre o EstadoJogo imutável. SEM
// comportamento de produção: só a suíte de testes usa isto; o motor antigo
// (class Jogo) continua ativo em runtime.
//
// Regras canônicas (fiéis ao motor antigo):
//  - Morto: 11 cartas; pega-se o de MENOR índice disponível quando a dupla
//    zera a mão e ainda não pegou o seu; cada dupla pega no máximo 1.
//    Direto = zerou baixando (mesma vez, ainda descarta). Indireto = zerou
//    descartando (a vez passa).
//  - Batida: exige mão vazia + o morto já pego (ou não haver mais morto) + uma
//    CANASTRA que libere a batida. Trinca NUNCA libera. Fechado: qualquer
//    canastra (7+) de sequência (suja basta). Aberto/STBL: exige canastra LIMPA
//    (limpa / de_500 / as_a_as).
//  - Bônus de batida (+100) e penalidade de morto não pego (−100) são apurados
//    na PONTUAÇÃO (rules/pontuacao_canonica.dart), no fechamento da rodada.
import '../estado.dart';
import '../modalidade.dart';
import '../rule_spec.dart';
import '../meld/meld_validator.dart';

String _dupla(int a) => a % 2 == 0 ? 'nos' : 'eles';

enum FimMao { mortoDireto, mortoIndireto, batida }

class ResultadoMorto {
  final bool valido;
  final String? motivo;
  final FimMao? tipo;
  final int? indiceMortoPego; // índice (na lista atual) do morto pego
  final String? duplaQueBateu;
  final EstadoJogo? proximoEstado; // preenchido só se válido (aplicar puro)

  const ResultadoMorto({
    required this.valido,
    this.motivo,
    this.tipo,
    this.indiceMortoPego,
    this.duplaQueBateu,
    this.proximoEstado,
  });

  factory ResultadoMorto.recusa(String motivo) =>
      ResultadoMorto(valido: false, motivo: motivo);
}

/// Uma canastra (7+ sequência) que libera a batida na modalidade. Trinca nunca.
bool canastraLiberaBatida(List<CartaSnapshot> meld, RuleSpec spec) {
  if (meld.length < 7) return false;
  final r = validarJogoMesa(meld, spec);
  if (!r.valido || r.tipo != 'sequencia') return false; // trinca NUNCA
  if (spec.modalidade == Modalidade.fechado) return true; // qualquer 7+ (suja basta)
  return r.classificacao == 'limpa' ||
      r.classificacao == 'de_500' ||
      r.classificacao == 'as_a_as';
}

/// A dupla tem alguma canastra que libera a batida?
bool duplaPodeBater(EstadoJogo estado, String dupla, RuleSpec spec) =>
    (estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[])
        .any((m) => canastraLiberaBatida(m, spec));

/// É legal a dupla ESVAZIAR a mão agora? (há morto disponível pra pegar OU já
/// pode bater). Se não, encerrar a mão é ilegal (não pode fechar sem morto).
bool podeEsvaziarMao(EstadoJogo estado, int assento, RuleSpec spec) {
  if (estado.rodadaEncerrada) return false; // rodada fechada trava tudo
  final dupla = _dupla(assento);
  final mortoDisp =
      !(estado.mortoPego[dupla] ?? false) && estado.mortos.isNotEmpty;
  return mortoDisp || duplaPodeBater(estado, dupla, spec);
}

/// Pega o morto (direto ou indireto) de forma ATÔMICA. Precondições: mão vazia,
/// a dupla ainda não pegou o seu morto e há morto disponível.
ResultadoMorto pegarMorto(EstadoJogo estado, int assento,
    {bool viaDescarte = false}) {
  final dupla = _dupla(assento);
  if (estado.rodadaEncerrada) {
    return ResultadoMorto.recusa('a rodada já foi encerrada');
  }
  if (estado.maos[assento].isNotEmpty) {
    return ResultadoMorto.recusa('o morto só é pego com a mão vazia');
  }
  if (estado.mortoPego[dupla] ?? false) {
    return ResultadoMorto.recusa('a dupla já pegou o seu morto');
  }
  if (estado.mortos.isEmpty) {
    return ResultadoMorto.recusa('não há morto disponível');
  }
  // Invariante do morto: o pile a ser consumido (menor índice) tem exatamente
  // 11 cartas. Rejeita ANTES de clonar/remover — nada de mutação parcial.
  if (estado.mortos.first.length != 11) {
    return ResultadoMorto.recusa(
        'morto inválido: o pile precisa ter exatamente 11 cartas');
  }
  final proximo = estado.cloneProfundo();
  final morto = proximo.mortos.removeAt(0); // menor índice disponível
  proximo.maos[assento] = morto; // 11 cartas vão para a mão da dupla que zerou
  proximo.mortoPego[dupla] = true;
  // Direto: mesma vez (ainda precisa descartar). Indireto: a vez passa.
  final resultadoEstado =
      viaDescarte ? proximo.copyWith(vez: (assento + 1) % 4) : proximo;
  return ResultadoMorto(
    valido: true,
    tipo: viaDescarte ? FimMao.mortoIndireto : FimMao.mortoDireto,
    indiceMortoPego: 0,
    proximoEstado: resultadoEstado,
  );
}

/// Avalia (e aplica) a BATIDA. Mão vazia + morto cumprido (ou sem morto) +
/// canastra que libere. Encerra a rodada e marca a dupla que bateu.
ResultadoMorto avaliarBatida(EstadoJogo estado, int assento, RuleSpec spec) {
  final dupla = _dupla(assento);
  if (estado.rodadaEncerrada) {
    return ResultadoMorto.recusa('a rodada já foi encerrada');
  }
  if (estado.maos[assento].isNotEmpty) {
    return ResultadoMorto.recusa('para bater a mão precisa estar vazia');
  }
  final mortoOk =
      (estado.mortoPego[dupla] ?? false) || estado.mortos.isEmpty;
  if (!mortoOk) {
    return ResultadoMorto.recusa('não pode bater sem antes pegar o morto');
  }
  if (!duplaPodeBater(estado, dupla, spec)) {
    return ResultadoMorto.recusa(spec.modalidade == Modalidade.fechado
        ? 'para bater é preciso pelo menos uma canastra (7+) na mesa'
        : 'para bater é preciso uma canastra LIMPA na mesa');
  }
  final proximo = estado
      .cloneProfundo()
      .copyWith(rodadaEncerrada: true, duplaQueBateu: dupla);
  return ResultadoMorto(
    valido: true,
    tipo: FimMao.batida,
    duplaQueBateu: dupla,
    proximoEstado: proximo,
  );
}
