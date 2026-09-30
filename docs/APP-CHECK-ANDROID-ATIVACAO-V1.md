# OS 50.1 — Ativação canônica do App Check no cliente Android e fechamento do pipeline de release V1

Base: `correcao/os42-c2-torneiobase-fail-closed-v1` @
`828d5a0e5a7e57a575ecd7b906629a746b6a4cc2`.

Esta OS fecha o veredito **BLOQUEADO** da auditoria OS 50: o cliente Flutter não
emitia um único token de App Check, e a entrega que resolveria isso existia,
provada, numa folha que **nenhuma ponta produtiva descendia** — de 233
referências do repositório, apenas duas a continham. O que entra aqui é código
novo escrito sobre a ponta P. Não é merge daquela folha, e o `build.yml` dela
não foi importado.

---

## 1. A ativação, e por que ela mora exatamente ali

`app/lib/main.dart` passou de 58 para 106 linhas. A ativação entra entre
`Firebase.initializeApp()` e `runApp()`, que é o único ponto do processo que
serve:

* **depois do `initializeApp`** porque `FirebaseAppCheck.instance` resolve
  `Firebase.app()`, e sem app inicializado morre com `[core/no-app]`;
* **antes do `runApp`**, que é a última instrução de `main()` — e como toda
  callable nasce no `initState` da raiz, que só roda depois do `runApp`, essa
  linha **precede provadamente** a primeira chamada de rede do aplicativo.

O `try/catch` é **próprio**, e não o do Firebase, por duas razões opostas:
dentro daquele bloco, uma falha do Firebase pularia a ativação em silêncio; fora
de qualquer bloco, um ambiente sem configuração Android derrubaria o `main()`.
Falhar ali deixa o aplicativo subir **sem atestação** — as callables recusam com
`unauthenticated`, e ninguém é deslogado por isso (§4).

## 2. A forma do provedor, que importa mais que o valor

```dart
const AndroidAppCheckProvider kProvedorDeAtestacao = kReleaseMode
    ? AndroidPlayIntegrityProvider()
    : AndroidDebugProvider();
```

`kReleaseMode` é `const`, então o `?:` inteiro é dobrado em tempo de compilação:
no release sobra só `AndroidPlayIntegrityProvider`, e `AndroidDebugProvider`
deixa de ser referenciado. Escrito como `if` de tempo de execução, função ou
variável, as **duas** classes ficariam no artefato, e bastaria um engano de
configuração para distribuir atestação de graça. É a mesma forma de
`services/endpoint_servidor.dart`, e é ela que torna "não há depuração no
release" estrutural em vez de uma promessa de quem faz o build.

Nenhum token de depuração entrou no repositório, e nenhum vai entrar: o SDK
imprime um token novo a cada instalação, e o cadastro é no console.

## 3. O `appId` continua o de teste no fonte — de propósito

O fonte é compartilhado pelos dois pipelines. `build.yml` monta o APK de teste
com pacote `com.buracomastervip.poc.…`, que casa com o registro "BMV Teste";
`release-aab.yml` troca o `appId` pelo oficial **na cópia de `app_build/`**.
Trocar no fonte quebraria o login do aparelho onde se desenvolve.

### O passo do release já estava quebrado, e não era por App Check

O passo *"Apontar o FirebaseOptions para o app Android OFICIAL"* conferia o
`serverClientId` do Google Sign-In **dentro de `main.dart`**, onde ele um dia
esteve. Ele mudou para `app/lib/sessao/autenticacao_firebase.dart` numa OS de
sessão, e a conferência ficou apontando para o arquivo antigo: o passo levantava
`AssertionError` em **toda** execução, e nenhum AAB saía do pipeline — por um
arquivo errado, não por um defeito de configuração.

O passo agora:

1. exige exatamente **uma** ocorrência do `appId` de teste;
2. substitui;
3. **confere o próprio resultado** — exatamente um `appId` oficial e zero de
   teste;
4. confere o `serverClientId` no arquivo onde ele vive, exigindo uma ocorrência.

A conferência do Web client foi mantida, e não removida: sem ela um bundle sem
Web client compila, sobe, e só falha no primeiro login real. Pacote, assinatura,
permissões, gatilhos e branding não foram tocados.

## 4. A recusa deixou de ser uma conclusão sobre a sessão

Uma callable com `enforceAppCheck` responde `unauthenticated` em três situações:
token de autenticação inválido, token de App Check inválido e token de App Check
ausente. Nas duas últimas a sessão está viva, e repetir é justamente o que
resolve.

`MotivoFalhaIdentidade.naoAutenticado` virou `credencialOuAtestacao` — mesmo
vocabulário, e pelo mesmo motivo, de `MotivoFalhaRanking.credencialOuAtestacao`,
que já tinha feito essa correção do outro lado do aplicativo. Quem decide é a
camada que sabe se há sessão local:

```dart
bool identidadeAdmiteNovaTentativa(
  MotivoFalhaIdentidade motivo, {
  required bool haSessaoLocal,
});
```

`EstadoIdentidadeSessao.podeTentarDeNovo` passa a consultar esse predicado com
`haSessaoLocal: autenticado`. `MotivoFalhaIdentidade.transitoria` continua
existindo para os motivos que se decidem sozinhos, e o seu doc-comment agora diz
que `credencialOuAtestacao` está fora dele de propósito — ler o getter no lugar
do predicado é exatamente a regressão que o caso N26 pega.

Nada aqui desloga ninguém: o predicado decide se aparece um botão, e a fase de
falha preserva o `uid`.

## 5. As amarras de `main.dart`, atualizadas de propósito

Três suítes fixavam o digest da porta de entrada, e as três foram recarimbadas
**no mesmo commit** que muda o arquivo, com o digest anterior preservado em
comentário:

| caso | suíte | gate |
|---|---|---|
| M19 | `app/test/casca/avatar_publico_canonico_test.dart` | `avatarcanon` |
| H-E01 | `app/test/casca/homologacao_avatar_publico_test.dart` | `avatarhml` |
| C16 | `app/test/composicao/composicao_perfil_ranking_test.dart` | `composicao` |

Dois desses gates têm contrato na fonte única, e o `sha256` do **arquivo de
teste** também subiu: `avatarcanon` e `avatarhml`. As contagens (`provas`,
`casos`) **não** mudaram — nenhum caso novo entrou nessas suítes.

`main.dart` continua abaixo do teto de 120 linhas que `auditoria_casca_test.dart`
cobra, com 14 linhas de folga.

## 6. O gate `appcheckandroid`

Suíte nova: `app/test/casca/app_check_android_test.dart`, **26 casos** em três
grupos — a ativação na porta de entrada (N01–N12), o pipeline de release
(N13–N18) e a leitura da recusa (N19–N26). Registrada na fonte única com
contrato completo (`suite`, `executor`, `sha256`, `provas 26`, `casos 26`, dez
`exige`) e no workflow.

A leitura de fonte **ignora comentário**, e isso não é detalhe: os comentários de
`main.dart` citam `AndroidDebugProvider` e `AndroidPlayIntegrityProvider` pelo
nome para explicar a dobra de constante, e uma busca textual crua contaria as
citações junto com o código.

`avatarcanon` **não** virou mistura de responsabilidades: nada de App Check
entrou nela além do digest que ela já guardava.

A prova de que o gate existe no portão **não mora na suíte** — mora em
`app/test/casca/auditoria_casca_test.dart` (gate `cascaaud`), pelo mesmo motivo
do `perfilvis`: uma guarda escrita dentro do arquivo que ela guarda morre junto
com ele. São três casos: a suíte existe, o workflow a executa e a fonte a
declara, e o verificador de contrato exige o gate e os pisos.

`verificar_contrato_suites.sh` ganhou `appcheckandroid` nas quatro réguas —
`CONTRATOS_MINIMOS`, `PISOS_PROVAS`, `PISOS_CASOS` e `PISOS_EXIGE`. Sem elas,
apagar a entrada inteira da fonte única passaria em silêncio.

## 7. Campanha negativa

Treze mutações, cada uma desfazendo **uma** decisão desta entrega. Zero escapes.

| # | mutação | detector | veredito |
|---|---|---|---|
| M01 | remover `activate()` | `appcheckandroid` | VERMELHO |
| M02 | mover a ativação para depois de `runApp()` | `appcheckandroid` | VERMELHO |
| M03 | usar Debug no release (ramos trocados) | `appcheckandroid` | VERMELHO |
| M04 | usar Play Integrity também no debug | `appcheckandroid` | VERMELHO |
| M05 | escolher o provedor com `if` de execução | `appcheckandroid` | VERMELHO |
| M06 | engolir a falha do Firebase no mesmo `catch` | `appcheckandroid` | VERMELHO |
| M07 | retirar o gate do workflow | `cascaaud` + `contratosui` | VERMELHO nos dois |
| M07b | retirar a entrada inteira da fonte única | `cascaaud` + `contratosui` | VERMELHO nos dois |
| M08 | trocar a suíte por isca (`expect(1, 1)`) | `contratosui` | VERMELHO |
| M09 | rebaixar `provas` e `casos` na fonte única | `contratosui` | VERMELHO |
| M10 | voltar a procurar `serverClientId` em `main.dart` | `appcheckandroid` | VERMELHO |
| M11 | impedir a substituição do `appId` | `appcheckandroid` | VERMELHO |
| M12 | tornar `unauthenticated` terminal com sessão viva | `appcheckandroid` | VERMELHO |

**A campanha achou um defeito na própria entrega, e ele foi corrigido.** Na
primeira volta, M07 comentou a linha `roda appcheckandroid …` no workflow e o
`cascaaud` ficou **VERDE**: a guarda usava `contains` do literal, e o literal
sobrevive dentro do comentário que o desliga. Só o `contratosui` reprovava. A
guarda passou a exigir a linha viva, com âncora de início de linha, e M07 hoje é
reprovada pelos dois detectores.

Duas observações honestas sobre o alcance:

* o harnês da campanha **falha ruidosamente** quando a âncora de uma mutação não
  casa exatamente uma vez. Uma mutação que não pegou, relatada como
  "sobreviveu", mentiria sobre a cobertura na direção errada;
* nenhuma verificação dentro de um workflow cobre a remoção do próprio workflow.
  O que estas guardas fazem é não deixar a remoção ser silenciosa.

## 8. O que continua bloqueado, e não é código

1. confirmar/cadastrar a SHA-256 do certificado oficial;
2. registrar o aplicativo Android oficial no App Check com Play Integrity;
3. cadastrar tokens de depuração **apenas no console**;
4. tratar separadamente o aplicativo web e a chave do reCAPTCHA;
5. só depois avaliar ativação/deploy dos backends protegidos.

Sem os dois primeiros, esta OS entrega código correto que **nenhum aparelho
consegue homologar** — é a OS 50-H1. E vale lembrar o custo já conhecido: o APK
de teste continua com pacote `.poc`, então ele não serve para homologar Play
Integrity contra o registro oficial.

Fora do escopo desta OS, por decisão dela: enforcement em Billing, regras de
Firestore para `playerEntitlements` e App Check web — todos na OS 50.2.
