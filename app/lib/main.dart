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
// inicializar o binding, o Firebase e a atestação. Quem monta sessão,
// autenticação e transporte é `casca/raiz_do_aplicativo.dart`; quem decide a
// tela é `casca/casca_de_producao.dart`.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'casca/raiz_do_aplicativo.dart';

/// Configuração do projeto Firebase.
///
/// Estes valores NÃO são segredo: identificam o projeto e vão gravados em todo
/// aplicativo distribuído, por construção do SDK. Quem protege os dados são as
/// regras de segurança e a autenticação, não o sigilo destas strings.
///
/// O `appId` AQUI É O DE TESTE, e continua sendo de propósito. Este fonte é
/// compartilhado pelos dois pipelines: `build.yml` monta o APK de teste com o
/// pacote `com.buracomastervip.poc.…`, que casa com este registro, e
/// `release-aab.yml` troca o `appId` pelo oficial na CÓPIA de `app_build/`
/// antes de compilar o bundle. Trocar aqui quebraria o login do APK de teste,
/// que é o aparelho onde se desenvolve.
const FirebaseOptions _opcoesDoFirebase = FirebaseOptions(
  apiKey: 'AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ',
  appId: '1:203886484007:android:734aaa61ca5ca68b29cc02',
  messagingSenderId: '203886484007',
  projectId: 'buraco-master-vip',
  storageBucket: 'buraco-master-vip.firebasestorage.app',
);

/// O provedor de atestação DESTE build. É uma CONSTANTE DE COMPILAÇÃO, e a
/// forma importa mais do que o valor.
///
/// `kReleaseMode` é `const`, então o `?:` inteiro é dobrado em tempo de
/// compilação: no release sobra só `AndroidPlayIntegrityProvider`, e
/// `AndroidDebugProvider` deixa de ser referenciado — o compilador o remove.
/// Escrito como função, `if` de tempo de execução ou leitura de variável, as
/// DUAS classes ficariam no artefato, e bastaria um engano de configuração para
/// distribuir atestação de graça. Mesma forma de `services/endpoint_servidor
/// .dart`, e é ela que torna "não há depuração no release" estrutural em vez de
/// uma promessa de quem faz o build.
///
/// O provedor de depuração NÃO carrega token embutido: o SDK imprime um token
/// novo a cada instalação, cadastrado no console à mão. Token nenhum entra aqui.
const AndroidAppCheckProvider kProvedorDeAtestacao = kReleaseMode
    ? AndroidPlayIntegrityProvider()
    : AndroidDebugProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BLINDADO, e de propósito: no celular o Firebase sobe normalmente; no
  // navegador de teste, se a configuração de Android não inicializar, o
  // aplicativo abre mesmo assim. Sem Firebase não há como autenticar ninguém, e
  // a casca mostra isso — tela pública sem provedor de entrada, dizendo o
  // motivo. É a verdade daquele ambiente, e não um estado inventado.
  try {
    await Firebase.initializeApp(options: _opcoesDoFirebase);
  } catch (_) {
    // Segue sem serviço de contas.
  }

  // App Check entra AQUI, e este ponto é o único que serve. DEPOIS de
  // `initializeApp`, porque `FirebaseAppCheck.instance` resolve `Firebase.app()`
  // e sem app inicializado morre com `[core/no-app]`. ANTES de `runApp`, que é a
  // última linha desta função — e como toda callable nasce no `initState` da
  // raiz, que só roda depois do `runApp`, esta linha PRECEDE PROVADAMENTE a
  // primeira chamada de rede do aplicativo.
  //
  // O `try/catch` é PRÓPRIO, e não o de cima, por duas razões opostas: dentro
  // daquele bloco, uma falha do Firebase pularia a ativação em silêncio; fora de
  // qualquer bloco, um ambiente sem configuração Android derrubaria o `main()`.
  // Falhar aqui deixa o app subir SEM atestação — as callables recusam com
  // `unauthenticated`, que Identidade e Ranking tratam como recusa neutra com
  // "tentar de novo". NINGUÉM É DESLOGADO por não ter conseguido atestar.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kProvedorDeAtestacao,
    );
  } catch (_) {
    // Segue sem atestação.
  }

  runApp(const RaizDoAplicativo());
}
