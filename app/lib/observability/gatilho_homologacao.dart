// gatilho_homologacao.dart — o crash controlado que prova a cadeia inteira.
//
// Homologar crash reporting exige uma falha REAL, num aparelho, que chegue ao
// painel do fornecedor. Mock não prova nada: o que costuma quebrar é o plugin
// Gradle ausente, o google-services.json do app errado, ou o upload de
// símbolos que não aconteceu — nada disso um teste em Dart alcança.
//
// O risco óbvio é este gatilho sobreviver até a loja. A proteção NÃO é um `if`
// em tempo de execução:
//
//     static const bool armado = bool.fromEnvironment('BMV_CRASH_HOMOLOGACAO');
//
// `bool.fromEnvironment` é `const`. Sem o `--dart-define`, `armado` é `false`
// em tempo de COMPILAÇÃO, e o compilador AOT remove o corpo inteiro do
// binário. Numa build comercial o código não fica inacessível — ele não
// existe. Não há flag para virar, opção escondida, nem gesto secreto.
//
// A mensagem é curta de propósito: o [Redator] apaga qualquer sequência opaca
// com 24 caracteres ou mais, e um marcador longo sumiria justamente do evento
// que ele deveria marcar. O SHA não vai na mensagem porque já viaja em
// `build.sha`, em toda ocorrência.

import 'dart:async';

import 'evento_falha.dart';
import 'identidade_build.dart';
import 'observabilidade.dart';

/// A exceção que o gatilho lança.
///
/// Tipo próprio porque o painel agrupa por tipo: assim o crash de homologação
/// não se mistura com defeito de verdade, e some do painel com um filtro.
class CrashDeHomologacao implements Exception {
  const CrashDeHomologacao(this.marcador);
  final String marcador;

  @override
  String toString() => 'CrashDeHomologacao: $marcador';
}

/// Dispara uma falha controlada quando — e somente quando — a build foi
/// compilada com `--dart-define=BMV_CRASH_HOMOLOGACAO=true`.
class GatilhoHomologacao {
  const GatilhoHomologacao._();

  static const String chave = 'BMV_CRASH_HOMOLOGACAO';

  /// `false` em toda build que não passe o define. Constante de compilação.
  static const bool armado = bool.fromEnvironment(chave);

  /// Marcador curto (17 caracteres) para achar a ocorrência no painel.
  /// Curto de propósito: acima de 24 o [Redator] o apagaria.
  static const String marcador = 'BMV-HOMOLOG-CRASH';

  /// Quanto o app espera antes de quebrar.
  ///
  /// Não é zero: o Crashlytics precisa terminar a própria inicialização nativa
  /// antes de conseguir gravar o relatório em disco. Quebrar antes disso perde
  /// o evento, e o resultado parece "não chegou ao painel" quando na verdade
  /// nunca foi gravado.
  static const Duration espera = Duration(seconds: 8);

  /// Agenda o crash, se a build estiver armada. Chamar de dentro da zona
  /// protegida — é ela que classifica o erro como fatal.
  ///
  /// Sem o define, o `if (!armado)` é `if (!false)` resolvido em compilação e
  /// o resto do método é descartado pelo AOT.
  static void armarSePedido(Observabilidade obs) {
    if (!armado) return;

    obs.registrarFalha(
      const CrashDeHomologacao('$marcador armado'),
      severidade: Severidade.naoFatal,
      mensagem: 'gatilho de homologação armado; crash fatal em '
          '${espera.inSeconds}s',
    );

    Timer(espera, () {
      // Sem `await` e sem `catch`: o erro sobe para a zona protegida, que é
      // exatamente o caminho de uma falha assíncrona de verdade.
      throw const CrashDeHomologacao(marcador);
    });
  }

  /// Descrição para o log de build. Aparece no CI para que ninguém publique
  /// uma build armada sem perceber.
  static String descrever(IdentidadeBuild id) => armado
      ? 'ATENÇÃO: build ARMADA para crash de homologação '
          '(${id.resumo}). Não publicar.'
      : 'build normal: gatilho de homologação ausente do binário.';
}
