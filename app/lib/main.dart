// main.dart — a porta de entrada do aplicativo, e só isso.
//
// ---------------------------------------------------------------------------
// O QUE SAIU DAQUI
// ---------------------------------------------------------------------------
//
// Este arquivo tinha 2.172 linhas e era, na prática, uma BANCADA DE PRÉVIAS: a
// raiz abria `SplashOficialScreen(proximaTela: _InicioPreviewHost)`, e junto
// moravam quinze hosts de pré-visualização — Ranking, Recompensas, Amigos,
// Saguão, Loja, Hall, Configurar Mesa, Torneios — cada um construindo o `.mock()`
// da sua tela. Moravam aqui também duas classes que ninguém alcançava: uma
// `SplashScreen` antiga, substituída pela oficial, e uma `HomeScreen` que
// carregava o segundo `FirebaseAuth.instance.authStateChanges().listen` do
// aplicativo e um cabeçalho com saldo e liga escritos no código.
//
// Tudo isso saiu. As TELAS continuam no repositório, com seus mocks, e continuam
// compilando: elas são catálogo visual e material dos testes. O que deixou de
// existir é o CAMINHO — nenhuma rota que nasça em `main()` chega a uma delas.
//
// O que ficou aqui é o mínimo que só pode acontecer no início do processo:
// inicializar o binding e o Firebase. Quem monta sessão, autenticação e
// transporte é `casca/raiz_do_aplicativo.dart`; quem decide a tela é
// `casca/casca_de_producao.dart`.
//
// ---------------------------------------------------------------------------
// A COSTURA COM A OBSERVABILIDADE (P0 V3)
// ---------------------------------------------------------------------------
//
// A camada de observabilidade nasceu numa linhagem paralela, e lá o `main()`
// dela também era uma linha só — mas construía `BuracoApp`, que era justamente
// a bancada de prévias descrita acima. A integração NÃO troca uma raiz pela
// outra: mantém a raiz REAL da Casca e adota a ordem de inicialização da
// observabilidade, que é o que aquela folha tinha de melhor aqui.
//
// Por que a chamada é uma linha só: `runBuracoMasterVip` guarda a ordem inteira
// (zona protegida → binding → hooks globais → inicialização opcional → runApp)
// dentro de `observability/runtime.dart`. Espalhar essa ordem de volta pelo
// `main.dart` foi exatamente o que permitiu, na base antiga, que a falha do
// Firebase virasse um `catch (_) {}` mudo.
//
// O `ensureInitialized()` não mora mais aqui DE PROPÓSITO: ele precisa acontecer
// dentro da zona protegida, senão erros do binding escapam da captura. Quem o
// chama é o runtime, no lugar certo.

// `material.dart` NÃO é importado aqui, e a ausência é consequência da costura:
// com `runApp` movido para dentro de `runBuracoMasterVip`, este arquivo não
// constrói mais widget nenhum — só nomeia a raiz, que vem da Casca.
import 'package:firebase_core/firebase_core.dart';

import 'casca/raiz_do_aplicativo.dart';
import 'observability/coletor_crashlytics.dart';
import 'observability/observability.dart';

/// Configuração do projeto Firebase.
///
/// Estes valores NÃO são segredo: identificam o projeto e vão gravados em todo
/// aplicativo distribuído, por construção do SDK. Quem protege os dados são as
/// regras de segurança e a autenticação, não o sigilo destas strings.
const FirebaseOptions _opcoesDoFirebase = FirebaseOptions(
  apiKey: 'AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ',
  appId: '1:203886484007:android:734aaa61ca5ca68b29cc02',
  messagingSenderId: '203886484007',
  projectId: 'buraco-master-vip',
  storageBucket: 'buraco-master-vip.firebasestorage.app',
);

void main() => runBuracoMasterVip(
      // A raiz REAL de produção — a mesma da Casca V2. É ela que monta sessão,
      // autenticação e transporte, e é ela que decide qual tela aparece.
      construirApp: () => const RaizDoAplicativo(),

      // Único ponto do aplicativo que conhece o fornecedor de crash reporting.
      // Em debug e em teste ele é ignorado (ver `deveUsarColetorReal`), então
      // nenhum evento de suíte sai da máquina.
      coletor: ColetorCrashlytics(),

      // BLINDADO, e de propósito: no celular o Firebase sobe normalmente; no
      // navegador de teste, se a configuração de Android não inicializar, o
      // aplicativo abre mesmo assim. Sem Firebase não há como autenticar ninguém, e
      // a casca mostra isso — tela pública sem provedor de entrada, dizendo o
      // motivo. É a verdade daquele ambiente, e não um estado inventado.
      //
      // O que mudou: o `catch (_) {}` mudo virou um evento NÃO FATAL. O
      // aplicativo continua subindo exatamente como antes — a diferença é que
      // agora alguém fica sabendo que subiu sem serviço de contas.
      antesDeRodar: () => Firebase.initializeApp(options: _opcoesDoFirebase),
    );
