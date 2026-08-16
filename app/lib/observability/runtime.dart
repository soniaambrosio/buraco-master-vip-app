// runtime.dart — a API única de inicialização do app.
//
// Existe uma função pública e só uma: [runBuracoMasterVip]. O `main()` do app
// deve ser uma linha chamando ela. Toda a ordem correta de inicialização
// (zona protegida → binding → hooks → Firebase → runApp) mora AQUI, e não
// espalhada pelo `main.dart`, para que a integração com o resto do app seja
// uma chamada e não uma cirurgia.
//
// Ordem e porquê:
//   1. Instala a observabilidade (portas 1 e 2 já ligadas).
//   2. Abre a zona protegida (porta 3) e faz TODO o resto dentro dela —
//      inclusive `ensureInitialized()`, senão erros do binding escapam da zona.
//   3. Roda a inicialização opcional do app (Firebase, preferências…). Se ela
//      falhar, vira evento NÃO FATAL e o app sobe assim mesmo: o jogo não
//      depende de Firebase para ser jogado.
//   4. `runApp`.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'coletor.dart';
import 'evento_falha.dart';
import 'identidade_build.dart';
import 'observabilidade.dart';
import 'trilha_operacional.dart';

/// Sobe o Buraco Master VIP com observabilidade ligada de ponta a ponta.
///
/// [construirApp] devolve o widget raiz. [antesDeRodar] é a inicialização
/// opcional (Firebase, preferências) — ela pode falhar sem derrubar o app.
///
/// [coletor] é o destino real dos eventos. Ele só é usado se o ambiente
/// permitir (ver `Observabilidade.deveUsarColetorReal`); em debug e em teste o
/// destino é sempre o [ColetorNulo].
Future<void> runBuracoMasterVip({
  required Widget Function() construirApp,
  Future<void> Function()? antesDeRodar,
  IdentidadeBuild? identidade,
  ColetorDeFalhas? coletor,
  bool forcarColetorReal = false,
}) {
  return executarObservado(
    identidade: identidade,
    coletor: coletor,
    forcarColetorReal: forcarColetorReal,
    corpo: (obs) async {
      // Dentro da zona, por exigência do `runZonedGuarded`.
      WidgetsFlutterBinding.ensureInitialized();
      obs.marco(MarcoOperacional.appIniciado);

      if (antesDeRodar != null) {
        try {
          await antesDeRodar();
        } catch (e, s) {
          // Antes desta camada, esta falha era um `catch (_) {}` mudo e o app
          // subia sem Firebase sem ninguém ficar sabendo. Agora ela é
          // reportada — e o app continua subindo.
          obs.marco(MarcoOperacional.firebaseIndisponivel);
          obs.registrarFalha(
            e,
            stack: s,
            severidade: Severidade.naoFatal,
            mensagem: 'inicialização opcional falhou; app segue sem ela',
          );
        }
      }

      runApp(construirApp());
    },
  );
}

/// Miolo de [runBuracoMasterVip], sem `runApp`.
///
/// Separado para que a suíte exercite exatamente o mesmo caminho de zona
/// protegida que roda em produção, sem precisar subir uma árvore de widgets.
Future<void> executarObservado({
  required Future<void> Function(Observabilidade obs) corpo,
  IdentidadeBuild? identidade,
  ColetorDeFalhas? coletor,
  bool forcarColetorReal = false,
  DateTime Function()? relogio,
  bool instalarHooks = true,
}) async {
  final obs = await Observabilidade.instalar(
    identidade: identidade,
    coletorReal: coletor,
    forcarColetorReal: forcarColetorReal,
    relogio: relogio,
    instalarHooks: instalarHooks,
  );

  final pronto = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        await corpo(obs);
      } finally {
        if (!pronto.isCompleted) pronto.complete();
      }
    },
    (erro, stack) {
      obs.capturarDaZona(erro, stack);
      // Se a zona morreu antes do corpo terminar, ninguém mais completaria.
      if (!pronto.isCompleted) pronto.complete();
    },
  );
  return pronto.future;
}
