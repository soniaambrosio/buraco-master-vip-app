// C10 (rev.1) — DERIVAÇÃO FORA DO ISOLATE DE UI.
//
// A entrega anterior alegava que `Future(() => derivar(...))` tirava a busca
// combinatória do caminho do frame. Não tira: `Future` só adianta a execução
// para uma volta seguinte do event loop, no MESMO isolate. Quando a travessia
// roda, ela roda inteira, e o frame trava exatamente do mesmo jeito.
//
// Aqui a derivação vai para OUTRO isolate, via `compute` do Flutter. As
// travessias continuam idênticas — nenhum teto de cartas, de candidatos, de
// melds ou de tempo foi introduzido, e o conjunto de resultados legais é o
// mesmo. O que mudou é ONDE a CPU é gasta.
//
// `compute` foi escolhido em vez de `Isolate.run` porque `dart:isolate` não
// existe na web, e o projeto tem alvo web (`.github/workflows/web.yml`). Na web
// `compute` executa no mesmo isolate — não há isolates lá, e essa é a
// degradação honesta, não um contorno.
//
// Payloads: `EstadoJogo`, `RuleSpec`, `CartaId` e as ações canônicas são objetos
// Dart simples, sem closures, handles nativos ou recursos de plataforma —
// transferíveis entre isolates do mesmo grupo.
import 'package:flutter/foundation.dart' show compute;

import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/rule_spec.dart';
import 'autoridade_canonica.dart';

/// Argumento da derivação dos candidatos de compra do lixo Fechado/STBL.
class ArgsCandidatosLixo {
  final EstadoJogo estado;
  final int assento;
  final RuleSpec spec;
  const ArgsCandidatosLixo(this.estado, this.assento, this.spec);
}

/// Argumento da derivação das partições de uma seleção de cartas.
class ArgsParticoes {
  final EstadoJogo estado;
  final int assento;
  final RuleSpec spec;
  final List<CartaId> selecao;
  const ArgsParticoes(this.estado, this.assento, this.spec, this.selecao);
}

// Funções TOP-LEVEL: `compute` não aceita closures.
List<ComprarLixo> _rodarCandidatosLixo(ArgsCandidatosLixo a) =>
    derivarCandidatosCompraLixoFechado(a.estado, a.assento, a.spec);

List<Baixar> _rodarParticoes(ArgsParticoes a) =>
    derivarParticoesAbertura(a.estado, a.assento, a.spec, a.selecao);

/// Candidatos de compra do lixo, derivados fora do isolate de UI.
Future<List<ComprarLixo>> candidatosLixoForaDoFrame(ArgsCandidatosLixo a) =>
    compute(_rodarCandidatosLixo, a);

/// Partições de uma seleção, derivadas fora do isolate de UI.
Future<List<Baixar>> particoesForaDoFrame(ArgsParticoes a) =>
    compute(_rodarParticoes, a);
