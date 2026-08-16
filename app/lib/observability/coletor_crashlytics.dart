// coletor_crashlytics.dart — adaptador do Firebase Crashlytics.
//
// É o ÚNICO arquivo do app que conhece o fornecedor de crash reporting.
// Trocar de fornecedor é escrever outro arquivo deste tamanho e mudar um
// argumento no `main.dart`; nada da captura, da redação ou da deduplicação
// muda junto.
//
// Ponto de segurança que justifica o formato: o adaptador NUNCA recebe o erro
// cru. Ele recebe um [EventoFalha], que já passou pelo [Redator], e reembala
// isso num [FalhaRedigida] antes de entregar ao SDK. Assim não existe caminho
// em que o `toString()` original de uma exceção — onde mora o token — chegue
// ao painel do fornecedor.

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'coletor.dart';
import 'evento_falha.dart';
import 'identidade_build.dart';
import 'trilha_operacional.dart';

/// Exceção-fachada com texto já redigido. É ela, e não o erro original, que
/// vai para o SDK do fornecedor.
class FalhaRedigida implements Exception {
  FalhaRedigida(this.tipoOriginal, this.mensagem);

  /// Nome do tipo do erro original — agrupa bem no painel e não é PII.
  final String tipoOriginal;

  /// Mensagem já redigida.
  final String mensagem;

  @override
  String toString() => '$tipoOriginal: $mensagem';
}

class ColetorCrashlytics implements ColetorDeFalhas {
  ColetorCrashlytics({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  String get nome => 'crashlytics';

  @override
  Future<bool> iniciar(IdentidadeBuild identidade) async {
    // Identidade improvável não sobe: um crash sem SHA não responde
    // "qual build quebrou?" e contamina o painel com ruído.
    if (!identidade.provavel) return false;

    await _crashlytics.setCrashlyticsCollectionEnabled(true);
    for (final e in identidade.paraContexto().entries) {
      await _crashlytics.setCustomKey(e.key, e.value);
    }
    return true;
  }

  @override
  Future<void> enviar(EventoFalha evento) async {
    for (final e in evento.contexto.entries) {
      await _crashlytics.setCustomKey(e.key, e.value);
    }
    await _crashlytics.recordError(
      FalhaRedigida(evento.tipo, evento.mensagem),
      // Stack já redigido. `fromString` preserva os frames como texto, que é
      // o que o de-obfuscador precisa quando cruza com o mapa de símbolos da
      // MESMA build (ver o manifesto: `simbolos`).
      StackTrace.fromString(evento.stack),
      reason: evento.causas.length > 1 ? evento.causas.last : null,
      information: <Object>[
        'origem=${evento.origem.name}',
        'build=${evento.identidade.resumo}',
        if (evento.trilha.isNotEmpty) 'trilha=${evento.trilha.join('>')}',
        ...evento.causas.map((c) => 'causa=$c'),
      ],
      fatal: evento.ehFatal,
    );
  }

  @override
  Future<void> marco(MarcoOperacional marco) => _crashlytics.log(marco.name);
}
