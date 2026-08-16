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

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'casca/raiz_do_aplicativo.dart';

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

  runApp(const RaizDoAplicativo());
}
