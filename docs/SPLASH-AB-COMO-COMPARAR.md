# Splash A x Splash B — como olhar as duas

Existem **duas aberturas** no repositório, e as duas são de verdade. Esta OS
produziu a segunda; **nenhuma decisão foi tomada** sobre qual fica.

| | Splash A — oficial | Splash B — Rive |
|---|---|---|
| Arquivo | `app/lib/screens/splash_oficial_screen.dart` | `app/lib/casca/splash/splash_rive_screen.dart` |
| Como anima | desenhada em Flutter | arte animada no editor da Rive |
| Assets | `logo_splash_oficial.webp` + `splash_intro.mp3` | `splash.riv` + os mesmos logo e som |
| É o padrão? | **sim** | não |

---

## Rodar cada uma

Splash A (é o padrão — nada a fazer):

```bash
flutter run
```

Splash B:

```bash
flutter run --dart-define=BMV_SPLASH=rive
```

O mesmo vale para `flutter build apk` e `flutter build appbundle`. Qualquer
outro valor (`Rive`, `RIVE`, vazio, escrita errada) cai na **oficial** de
propósito: um erro de digitação no comando de build não pode trocar a abertura
de um aplicativo publicado.

---

## O estado da arte (leia antes de testar a B)

**`app/assets/splash/splash.riv` ainda não existe no repositório.** Enquanto não
existir, a Splash B abre pelo **fallback estático** — fundo escuro, logo e o
nome do jogo. Não é defeito: é o comportamento exigido, e ele tem teste.

Para plugar a arte quando ela ficar pronta, basta **um passo**:

```
app/assets/splash/splash.riv
```

Nada mais precisa mudar. A pasta já está declarada no `pubspec`, o CI já copia o
arquivo se ele estiver lá, e o carregador já aponta para esse caminho.

---

## O que já está garantido (e provado em teste)

`app/test/casca/splash_rive_test.dart` — 31 casos, e cada um deles foi conferido
mutando o código e exigindo vermelho.

- **A animação não decide destino.** Quem decide continua sendo a sessão
  canônica, em `casca_de_producao.dart`. As duas aberturas apenas *avisam* que
  terminaram.
- **Autenticado vai para a Home, não autenticado vai para o Login** — com a
  Splash B ligada, igual à A.
- **A arte pode falhar de quatro jeitos** (runtime não sobe, asset ausente,
  bytes corrompidos, arte sem artboard) e o roteamento é o mesmo.
- **A arte pode nunca responder** e a abertura termina assim mesmo. Quem conclui
  é um relógio de duração fixa, armado antes do carregamento. Sem isso, uma arte
  que não carrega vira um aplicativo aberto e parado.
- **Nunca há tela branca.** O fallback está desenhado desde o primeiro quadro; a
  arte entra por cima quando fica pronta.
- **O arquivo é lido uma vez** e devolvido ao sair da tela.
- **Nada de segundo dono de sessão:** a camada da abertura não conhece
  `FirebaseAuth`, não lê a sessão e não inicializa Firebase.
- **A duração das duas é a mesma** (3800 ms), senão a comparação não seria uma
  comparação.

---

## Medir

`SplashRiveScreen` aceita `onMedicao`, que entrega uma vez, ao fim da abertura:

- `ateAArte` — quanto levou até a arte estar desenhável (nulo se nunca ficou);
- `total` — a abertura inteira;
- `usouFallback` — terminou sem a arte;
- `motivoDaFalha` — por quê.

**Registre, não promova a requisito.** Número de máquina de desenvolvimento não
vira limite universal — o aparelho da jogadora é que decide.

---

## Se a decisão for ficar com a A

Some `app/lib/casca/splash/`, a linha `rive:` do `pubspec`, o `rive:^0.14.11` do
`flutter pub add` em `build.yml`, o passo opcional de cópia do `.riv` e este
arquivo. A dependência foi mantida contida num arquivo só
(`fonte_rive_real.dart`) exatamente para que desistir dela seja isso, e não uma
caçada.
