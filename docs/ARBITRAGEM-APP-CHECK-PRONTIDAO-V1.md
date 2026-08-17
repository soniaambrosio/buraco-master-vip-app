# ARBITRAGEM DA ATIVAÇÃO DO FIREBASE APP CHECK — V1

**Natureza:** somente leitura e documental. Nenhum provider, enforcement, debug
token, Play Integrity, secret, API, deploy ou configuração de console foi
ativado, criado ou alterado por esta arbitragem.

**Repositório:** `soniaambrosio/buraco-master-vip-app`
**Referência:** `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`
**SHA:** `6e428e8575e2df4a504148a948305838cf3ff2d4`
**Branch documental:** `auditoria/app-check-prontidao-v1`
**Data:** 17/08/2026

---

## 1. Gate Zero

| # | Exigência | Resultado | Evidência |
| --- | --- | --- | --- |
| 1 | SHA confirmado duas vezes | **OK** | `git log --oneline -1 6e428e8` → `docs: laudo da composicao Perfil + Mesa Online + Ranking Real V2`; `git ls-remote origin integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1` → `6e428e8575e2df4a504148a948305838cf3ff2d4`. Os dois batem |
| 2 | Branch nasce da referência, não de `main` | **OK** | `git checkout -b auditoria/app-check-prontidao-v1 6e428e8…`; `git rev-parse HEAD` = `6e428e8…` conferido DEPOIS do checkout |
| 3 | Não incorporar CI, avatar ou encerramento da UI | **OK** | Nenhum arquivo fora de `docs/` foi tocado |
| 4 | Package ID, App ID e variantes registrados | **OK** | §6. Impressões digitais de assinatura truncadas a 12 caracteres |
| 5 | Documentação oficial atual | **OK** | Firebase App Check — provider de depuração (Flutter), providers padrão (Flutter), provider Play Integrity (Android), App Check para Cloud Functions |
| 6 | Console estritamente somente leitura | **OK** | Única consulta emitida: `firebase apps:list ANDROID --project buraco-master-vip --debug` (GET). Ver a ressalva de §6.4 |

Um ponto de método, porque muda a leitura de tudo o que vem depois: a
**superfície de risco desta ativação não é o que existe em `app/lib/`, e sim o
que o binário publicado alcança a partir de `main()`**. As duas medidas divergem
por um fator grande nesta branch, e a diferença é o que separa um veredito
alarmista de um veredito verdadeiro. Ver §4.4.

---

## 2. Resumo executivo

O App Check **não existe no cliente**. A dependência está declarada e travada,
nunca é importada e nunca é ativada. Ao mesmo tempo, **o backend já exige App
Check em 35 callables**, e é isto que faz a pergunta ser urgente: hoje essas
funções só respondem porque **nunca foram exercidas por um cliente de produção**
ou porque a exigência está atrás de uma variável de ambiente desligada.

O bloqueio **não é de ordem de bootstrap** — essa está definida e é provável em
código (§4.5). O bloqueio é externo, e o achado central é este:

> **O aplicativo desta branch inicializa contra o app Firebase errado.**
> `app/lib/main.dart` fixa `appId` `1:…:android:734aaa61…`, que é o registro
> **"BMV Teste"**, pacote `com.buracomastervip.poc.buraco_master_vip`. O app
> oficial da Play é `io.github.soniaambrosio.buracomastervip`, registro
> `1:…:android:b1cd95ba…`. Play Integrity atesta pacote **e** certificado de
> assinatura; um App Check ligado sobre o registro errado recusa o aplicativo
> oficial, e um ligado sobre o registro certo recusa o binário que o CI produz.

Veredito: **BLOCKED — CONFIGURAÇÃO EXTERNA AUSENTE** (§9).

---

## 3. Inventário do cliente

### 3.1 A dependência

| Item | Valor | Arquivo |
| --- | --- | --- |
| Declaração | `firebase_app_check: ^0.4.6` | [app/pubspec.yaml:44](app/pubspec.yaml:44) |
| Versão travada | `0.4.6` (hosted, pub.dev) | [app/pubspec.lock:252](app/pubspec.lock:252) |
| `firebase_core` | `4.13.0` | [app/pubspec.lock](app/pubspec.lock) |
| Importações de `firebase_app_check` em `app/lib/` | **ZERO** | varredura em todo `app/lib/**/*.dart` |
| Chamadas a `FirebaseAppCheck.instance.activate` | **ZERO** | idem |
| Providers configurados | **NENHUM** | idem |
| Tokens de debug no repositório | **NENHUM** | idem |
| Tratamento de falha do App Check | **NENHUM ESPECÍFICO** | ver §3.4 |
| Telemetria/logs de App Check | **NENHUM** | idem |

O comentário em [app/pubspec.yaml:41](app/pubspec.yaml:41) declara a intenção
explicitamente: *a integração fica pronta aqui, porém DESLIGADA por padrão […]
a ativação acontece antes da abertura pública, não agora.* Não é esquecimento;
é uma decisão registrada, e esta arbitragem a confirma como ainda válida.

A dependência declarada e não usada tem um custo já pago e um benefício real: o
plugin Android entra no APK, a resolução de versões já está travada em
`pubspec.lock`, e portanto **a OS de implementação não terá de mexer em
dependências** — só em código de inicialização. Isso importa porque o alvo
Android **não é versionado** neste repositório (não há `android/`; o CI roda
`flutter create` a cada build), então mudar dependência é mais caro aqui do que
num projeto Flutter comum.

### 3.2 A ordem exata de bootstrap

`app/lib/main.dart` tem 59 linhas e faz três coisas, nesta ordem:

```
main()
 ├─ WidgetsFlutterBinding.ensureInitialized()            main.dart:44
 ├─ await Firebase.initializeApp(options: _opcoesDoFirebase)   main.dart:52
 │     └─ envolvido em try/catch que ENGOLE a falha      main.dart:51-55
 └─ runApp(const RaizDoAplicativo())                     main.dart:57
      │
      └─ _RaizDoAplicativoState.initState()              raiz_do_aplicativo.dart:112
          ├─ criarSessaoDoJogador()                      raiz_do_aplicativo.dart:116
          │    └─ SessaoDoJogador(...)  →  scheduleMicrotask(garantirCarregada)
          │                                              sessao_do_jogador.dart:92
          │         └─ 1ª CALLABLE: obterMinhaIdentidade
          ├─ AutenticacaoFirebase()                      raiz_do_aplicativo.dart:118
          ├─ criarOnlineServiceDaSessao(_sessao)         raiz_do_aplicativo.dart:124
          ├─ PonteSessaoOnline(...)                      raiz_do_aplicativo.dart:128
          └─ _sincronizarRanking()                       raiz_do_aplicativo.dart:142
               └─ 2ª CALLABLE: abrirRanking
```

### 3.3 Primeiro acesso a cada serviço

| Serviço | Primeiro acesso | Momento |
| --- | --- | --- |
| **Core** | `Firebase.initializeApp` — [main.dart:52](app/lib/main.dart:52) | dentro de `main()`, antes de `runApp` |
| **Auth** | `FirebaseAuth.instance` — [sessao_firebase.dart:57](app/lib/sessao/sessao_firebase.dart:57) | `initState` da raiz |
| **Functions** | `FirebaseFunctions.instanceFor` — [fonte_identidade_firebase.dart:42](app/lib/sessao/fonte_identidade_firebase.dart:42) e [ranking_transporte_firebase.dart:66](app/lib/ranking/ranking_transporte_firebase.dart:66) | resolução preguiçosa, na 1ª chamada |
| **Firestore** | `FirebaseFirestore.instance` — [colecao_firebase.dart:36](app/lib/colecoes/colecao_firebase.dart:36) | **inalcançável pela raiz** (§4.4) |
| **Storage** | — | **NÃO USADO**: `firebase_storage` não existe no `pubspec.yaml`, não existe no `pubspec.lock`, e `firebase.json` não declara bloco `storage` |

A resolução preguiçosa de `FirebaseFunctions` é deliberada e está comentada nos
dois adaptadores: `instanceFor` exige `initializeApp` já executado, e resolver
no construtor obrigaria todo teste a subir o Firebase. Para App Check isso é
uma **vantagem**: nenhuma instância de Functions nasce antes do `runApp`.

### 3.4 Inicialização por variante Android

**`main.dart` não diferencia variante.** As 59 linhas têm um único caminho, sem
`kDebugMode`, `kReleaseMode`, `kProfileMode` ou `fromEnvironment`. Debug, profile
e release executam exatamente as mesmas linhas.

**O fecho da raiz, porém, diferencia — e o precedente é bom.** Varredura por
`kDebugMode|kReleaseMode|kProfileMode|fromEnvironment` nos 44 arquivos
alcançáveis devolve 7 ocorrências, concentradas em três arquivos:

| Arquivo | Uso |
| --- | --- |
| [lib/services/endpoint_servidor.dart:91](app/lib/services/endpoint_servidor.dart:91) | `perfil: kReleaseMode ? … : …` — escolhe o perfil de endpoint pela variante |
| [lib/services/endpoint_servidor.dart:63,70](app/lib/services/endpoint_servidor.dart:63) | `String.fromEnvironment` / `bool.fromEnvironment` — URL e permissão de endpoint inseguro, injetadas em tempo de build |
| [lib/casca/configuracoes_de_producao.dart:37](app/lib/casca/configuracoes_de_producao.dart:37) | `kVersaoDoAplicativo` por `String.fromEnvironment` |
| [lib/sessao/autenticacao_firebase.dart:38](app/lib/sessao/autenticacao_firebase.dart:38) | `kServerClientIdGoogle` por `String.fromEnvironment` |

Isto é **melhor** do que a ausência de precedente, e a OS de implementação deve
copiar a forma de `endpoint_servidor.dart`: a decisão é uma **constante de
compilação** (`kReleaseMode` / `const fromEnvironment`), e não um valor lido em
tempo de execução. Constante de compilação permite ao compilador **eliminar o
ramo morto**, e é isso que faz "o provider de depuração não existe no binário de
release" ser uma propriedade estrutural em vez de uma promessa.

Consequência para hoje: **não existe caminho pelo qual um provider de depuração
vaze para o release**, porque não existe provider nenhum. A OS de implementação é
quem **introduz** esse risco — por isso a separação precisa nascer junto com o
`activate()`, e no formato acima (§7, passo 1.2).

### 3.5 O tratamento de falha que já existe, e o que ele significa

Não há tratamento de App Check. Há, porém, **tratamento de `unauthenticated`**,
e ele está em dois estados de maturidade diferentes — a diferença é o achado de
código mais importante deste laudo.

**Caminho do Ranking — PRONTO.** [ranking_transporte.dart:55-108](app/lib/ranking/ranking_transporte.dart:55)
define `MotivoFalhaRanking.credencialOuAtestacao`, com o nome comprido de
propósito. O comentário mede o comportamento real de `firebase-functions` 6.x
(`lib/common/providers/https.js`): sob `enforceAppCheck: true`, o código
`unauthenticated` chega em **três** situações — token de auth inválido, token de
App Check inválido, token de App Check ausente. Nas duas últimas a sessão está
viva. [estado_ranking.dart:210-219](app/lib/ranking/estado_ranking.dart:210)
desfaz a ambiguidade no único lugar que pode: com sessão local viva, o estado é
o neutro `acessoRecusado`, **com botão de tentar de novo e sem afirmar que a
sessão expirou**. É exatamente o comportamento que a ativação do App Check
exige, e ele já está escrito e testado.

**Caminho da Identidade — NÃO PRONTO.**
[fonte_identidade_firebase.dart:78](app/lib/sessao/fonte_identidade_firebase.dart:78)
traduz `'unauthenticated' => MotivoFalhaIdentidade.naoAutenticado`. O nome
afirma o que não foi provado, e a consequência é mecânica:
[identidade_publica_sessao.dart:95-115](app/lib/sessao/identidade_publica_sessao.dart:95)
documenta `naoAutenticado` como *"Não adianta repetir com a mesma credencial"* e
o exclui de `transitoria`. Como só o motivo transitório justifica oferecer
"tentar de novo", **a falha de App Check na identidade vira um beco sem saída,
sem botão** — para uma condição que a repetição resolve.

É o mesmo defeito que a OS do Leitor de Ranking já fechou do outro lado, ainda
aberto neste. **P0 de código para a OS futura.**

Atenuante importante, e verificada: **isso não desloga ninguém.** A única
chamada a `FirebaseAuth.instance.signOut()` em todo `app/lib/` está em
[autenticacao_firebase.dart:124](app/lib/sessao/autenticacao_firebase.dart:124),
acionada apenas pelo comando explícito do jogador. Nenhum caminho de erro
desloga. O item "retry sem logout indevido" da matriz (§8) já parte de uma base
correta — o que falta é o retry, não a ausência de logout.

### 3.6 Telemetria

Não há telemetria de App Check, e não há telemetria de callable em geral. O que
existe é diagnóstico local com redação deliberada de dados:
`ranking_transporte_firebase.dart` monta o detalhe como `nome/codigo: mensagem`
e **exclui o `publicPlayerId` de propósito**; `online_service.dart` passa toda
mensagem de erro por `redigir()`. Uma OS futura que queira medir rejeição de App
Check terá de **acrescentar** superfície de observação, e deve fazê-lo
respeitando essa mesma regra.

---

## 4. O que o binário publicado realmente alcança

### 4.1 O método

O fecho transitivo dos `import` a partir de `app/lib/main.dart`, ignorando
`package:` e `dart:`. É a mesma definição que as auditorias estruturais desta
linhagem já usam ([auditoria_casca_test.dart:96-103](app/test/casca/auditoria_casca_test.dart:96),
[composicao_perfil_ranking_test.dart:275-278](app/test/composicao/composicao_perfil_ranking_test.dart:275)),
reexecutada aqui de forma independente.

### 4.2 O resultado

**44 arquivos** são alcançáveis a partir da raiz de produção.

### 4.3 As callables que o binário publicado emite

| Callable | Codebase | Região | Enforcement no backend | Alcançável pela raiz |
| --- | --- | --- | --- | --- |
| `obterMinhaIdentidade` | `social` | `southamerica-east1` | `enforceAppCheck` ligado fora do emulador | **SIM** |
| `abrirRanking` | `ranking` | `southamerica-east1` | `enforceAppCheck: true` fixo | **SIM** |
| `consultarJogadorPorIdPublico` | `ranking` | `southamerica-east1` | `enforceAppCheck: true` fixo | **SIM** |

**São três. Só três.**

### 4.4 O que NÃO está alcançável, e por que isso muda o veredito

| Arquivo | Superfície | Alcançável |
| --- | --- | --- |
| `lib/colecoes/colecao_firebase.dart` | `claimPioneerKit` + Firestore direto (`users/{uid}/inventory`) | **NÃO** |
| `lib/screens/amigos_screen.dart` | Firestore direto | **NÃO** |
| `lib/app/lib/screens/amigos_screen.dart` | Firestore direto (cópia em caminho aninhado duplicado) | **NÃO** |

Isto é decisivo. **Nenhum acesso direto a Firestore parte da raiz de produção
nesta branch**, e a única callable de Firestore/coleções (`claimPioneerKit`) é
inalcançável. A superfície real de uma ativação de App Check aqui é: **três
callables, uma região, dois codebases**.

Uma OS futura que ligue o enforcement de **Firestore** no console estará
protegendo uma superfície que o binário desta branch **não usa** — e derrubando,
se alguma outra branch a religar, um caminho que ninguém testou. O enforcement
de Firestore e o de Cloud Functions são chaves separadas no console; esta
arbitragem recomenda tratá-las separadamente, e nesta ordem.

### 4.5 A prova de ordem: App Check nasce antes ou depois da primeira callable?

**Hoje: nem antes nem depois — não nasce.**

**A ordem exigida, porém, é alcançável e provável.** A primeira callable é
emitida por `scheduleMicrotask(garantirCarregada)`, agendado no construtor de
`SessaoDoJogador` ([sessao_do_jogador.dart:92](app/lib/sessao/sessao_do_jogador.dart:92)),
que só é construído dentro de `initState` da raiz, que só roda depois de
`runApp` — que é a **última** linha de `main()`, depois do `await
Firebase.initializeApp`. Logo:

> Qualquer `await FirebaseAppCheck.instance.activate(...)` colocado entre
> [main.dart:55](app/lib/main.dart:55) e [main.dart:57](app/lib/main.dart:57)
> **precede provadamente toda callable do aplicativo**. A janela existe, é
> única, e não há caminho concorrente que a contorne.

Duas armadilhas nessa mesma janela, ambas com precedente medido neste projeto:

1. **O `try/catch` de `initializeApp` engole falhas de propósito.** Um
   `activate()` colocado *dentro* daquele bloco herdaria a mesma tolerância; um
   colocado *fora* dele estoura o `main()` inteiro se o Firebase não subiu. O
   `activate()` precisa do **seu próprio** `try/catch`, pelo mesmo motivo
   documentado em [main.dart:46-50](app/lib/main.dart:46) — sem isso, o
   navegador de teste e qualquer ambiente sem configuração Android param de
   abrir o aplicativo.
2. **Nada de resolver a instância como argumento.** O laudo do Crashlytics
   registra o caso: `FirebaseCrashlytics.instance` avaliado como argumento
   rodava antes da chamada, dava `[core/no-app]` e matava o `main()` sem UI e
   sem observabilidade — e nenhum teste em Dart pegava. `FirebaseAppCheck.instance`
   tem a mesma dependência de `Firebase.app()`.

### 4.6 O portão que a OS futura vai encontrar

`main.dart` está **fixado por hash** em
[composicao_perfil_ranking_test.dart:737-748](app/test/composicao/composicao_perfil_ranking_test.dart:737):
o teste `C16` calcula o SHA-256 do arquivo normalizado (`\r\n` → `\n`) e o
compara com `8526fc0a1cb487b7ec37a27a6449b09f667c5d412968f69bb547c9f246d5a0ab`.

Qualquer OS que ative App Check **precisa** alterar `main.dart` e, portanto,
**precisa atualizar essa constante no mesmo commit**. Não é obstáculo — é o
portão fazendo o trabalho dele. Há ainda dois limites do
[auditoria_casca_test.dart:254-263](app/test/casca/auditoria_casca_test.dart:254):
o arquivo não pode conter `Preview` e não pode passar de 120 linhas (hoje tem
59). O bloco de App Check cabe com folga.

---

## 5. Inventário do backend

Seis codebases, declarados em [firebase.json](firebase.json). Todos em
`firebase-functions ^6.1.0`.

### 5.1 Enforcement por codebase

| Codebase | Fonte | Forma do enforcement | Onde |
| --- | --- | --- | --- |
| `ranking` | `functions-ranking` | `{ enforceAppCheck: true, region: "southamerica-east1" }` — **fixo, sem escape** | [functions-ranking/src/index.ts:92](functions-ranking/src/index.ts:92) |
| `torneios` | `functions` | `{ enforceAppCheck: true, … }` — **fixo, sem escape** | [functions/src/index.ts:31](functions/src/index.ts:31), [functions/src/rastreabilidade.ts:40](functions/src/rastreabilidade.ts:40) |
| `social` | `functions-social` | `process.env.FUNCTIONS_EMULATOR !== "true"` — ligado em produção, dispensado sob emulador | [functions-social/src/index.ts:60](functions-social/src/index.ts:60) |
| `moderacao` | `functions-moderacao` | idem | [functions-moderacao/src/index.ts:45](functions-moderacao/src/index.ts:45) |
| `colecoes` | `firebase/functions` | `process.env.ENFORCE_APP_CHECK === 'true'` — **DESLIGADO por padrão** | [firebase/functions/index.js:47](firebase/functions/index.js:47) |
| `billing` | `functions-billing` | **AUSENTE** | [functions-billing/index.js:149-150](functions-billing/index.js:149) |

As duas formas condicionais merecem leitura atenta, porque são de qualidade
diferente:

- `FUNCTIONS_EMULATOR` é posto pelo **próprio emulador** e nunca vale `"true"`
  numa instância implantada. O comentário em
  [functions-social/src/index.ts:54-59](functions-social/src/index.ts:54)
  registra o raciocínio: *não há caminho pelo qual um cliente real desligue esta
  verificação, porque ela não lê nada que venha do pedido.* Correto.
- `ENFORCE_APP_CHECK` é uma variável **nossa**, e o comentário em
  [firebase/functions/index.js:38-47](firebase/functions/index.js:38) diz por
  que está desligada: ligar antes de o app publicar uma versão com App Check
  *derrubaria o resgate de todo mundo, inclusive do teste fechado*. É o mesmo
  raciocínio desta arbitragem, escrito meses antes.

### 5.2 A enumeração completa

**35 callables com App Check exigido** (fixo ou ligado em produção). Contagem
por varredura de `export const … = onCall(opcoesCliente`, codebase a codebase:

| Codebase | N | Callables | Chamador no app |
| --- | --- | --- | --- |
| `ranking` | **9** | `abrirTemporadaDeRanking`, `encerrarTemporadaDeRanking`, `reprocessarBacklogDeRanking`, `apurarRanking`, `diagnosticarRanking`, **`abrirRanking`**, `paginarRanking`, **`consultarJogadorPorIdPublico`**, `consultarHall` | **`abrirRanking` e `consultarJogadorPorIdPublico`**: `ranking_transporte_firebase.dart`. Os demais: **nenhum chamador no app** |
| `torneios` | **7** | `inscreverEmTorneio`, `cancelarInscricaoTorneio`, `consolidarConvitesDaTemporada`, `responderConviteEncerramento` (index.ts); `consultarPartidaPorMatchId`, `consultarExtratoCompetitivo`, `registrarSinalAntifraude` (rastreabilidade.ts) | **nenhum chamador no app** |
| `social` | **13** | **`obterMinhaIdentidade`**, `atualizarPerfilPublico`, `verPerfilPublico`, `localizarJogadorPorIdentidade`, `enviarSolicitacaoAmizade`, `aceitarSolicitacaoAmizade`, `recusarSolicitacaoAmizade`, `cancelarSolicitacaoAmizade`, `removerAmizade`, `listarAmigos`, `listarSolicitacoesRecebidas`, `listarSolicitacoesEnviadas`, `reconciliarPerfilSocial` | **`obterMinhaIdentidade`**: `fonte_identidade_firebase.dart`. Os demais: **nenhum chamador no app** |
| `moderacao` | **6** | `registrarDenuncia`, `bloquearJogador`, `desbloquearJogador`, `consultarContato`, `aplicarSancao`, `revogarSancao` | **nenhum chamador no app** |

Só **3 das 35** têm chamador no binário publicável desta branch (§4.3). As 32
restantes exigem App Check de um cliente que, aqui, não existe.

**Sem enforcement — e cada caso por um motivo diferente:**

| Função | Codebase | Situação | Leitura |
| --- | --- | --- | --- |
| `validarCompraPlay` | `billing` | **App Check ausente**, região `us-central1` (única fora de `southamerica-east1`) | Ver §5.4 |
| `claimPioneerKit`, `grantPioneerEligibility`, `revokePioneerKit` | `colecoes` | atrás de `ENFORCE_APP_CHECK`, hoje **desligado** | Correto para o estado atual. Ligar é um passo de runbook sem alterar código — mas **só depois** de o app publicar uma versão com App Check |
| `receberResultadoPartida`, `registrarEncerramentoPartida`, `processarResultado` | `torneios`, `ranking` | `opcoesServidor` — sem App Check, **de propósito** | **Correto e não deve mudar.** Quem chama é o servidor Node, com claim `motorDePartidas`. Play Integrity atesta *aplicativo Android*; exigi-lo de um servidor tornaria a função inalcançável pelo chamador legítimo |
| `tickTorneios`, `aoConcluirEdicao`, `aoBloquearJogador`, `aoRegistrarResultadoOficial` | vários | gatilhos e agendados | App Check **não se aplica** a `onSchedule`/`onDocument*` |

### 5.3 Consumo manual de `req.app`

**ZERO.** Nenhuma das seis codebases lê `req.app`, `request.app` ou
`rawRequest` para inspecionar o token de App Check. Toda a verificação é
delegada ao runtime pela opção `enforceAppCheck`.

Isso tem uma consequência prática que a §8 explora: **não há, hoje, nenhum ponto
do backend capaz de distinguir "App Check ausente" de "App Check inválido" para
registro**. Uma OS futura que precise dessa distinção — e a §8 argumenta que
precisa, ao menos temporariamente — terá de acrescentar leitura de `req.app`,
que a documentação oficial descreve como o campo que carrega os dados do App
Check, incluindo o app ID.

### 5.4 O caso `validarCompraPlay`, e por que ele não é um esquecimento

`validarCompraPlay` é a **única** callable de cliente sem App Check, e é a que
move dinheiro. À primeira vista parece a lacuna mais grave do inventário. Não é
— ou pelo menos não é simples:

1. Está em **`us-central1`**, sozinha. As outras cinco codebases estão em
   `southamerica-east1`. Uma ativação de App Check por região não a alcança.
2. Ela já **não é alcançável pela raiz de produção desta branch**: nenhum
   arquivo do fecho transitivo importa Billing.
3. A memória do projeto registra que a venda está bloqueada por motivo externo
   (o produto `master_vip` não existe na Play Console), e que a linha de Billing
   Flutter vive em outra branch, que **não deve ser mesclada** por conter um
   defeito conhecido de vazamento de VIP entre contas.

Portanto: **registrar, não corrigir aqui.** Ligar App Check em
`validarCompraPlay` sem coordenar com a branch de Billing que a chama é a receita
para uma compra recusada em produção. É item de uma OS de Billing, não desta
linhagem.

---

## 6. Console e Play — o que foi verificado e o que não foi

### 6.1 Apps Android registrados no projeto (VERIFICADO)

Consulta somente leitura: `firebase apps:list ANDROID --project buraco-master-vip --debug`
(GET `firebase.googleapis.com/v1beta1/projects/buraco-master-vip/androidApps`).

| appId (sufixo) | displayName | packageName | SHA-1 | SHA-256 |
| --- | --- | --- | --- | --- |
| `…1a8d6087…` | Buraco Master VIP (Android) | `com.buracomastervip.app` | 1 (`9bbb3186b218…`) | 1 (`07b92e0275d5…`) |
| **`…734aaa61…`** | **BMV Teste** | **`com.buracomastervip.poc.buraco_master_vip`** | 2 (`afc88565c58b…`, `9532748903781…`) | **NENHUM** |
| `…7d871ec4…` | buraco-master-vip Android | `com.mycompany.buracomastervip` | 1 (`9bbb3186b218…`) | 1 (`07b92e0275d5…`) |
| **`…b1cd95ba…`** | **Buraco Master VIP Oficial** | **`io.github.soniaambrosio.buracomastervip`** | 1 (`83738c7a9ac9…`) | **NENHUM** |

Todos `state: ACTIVE`, todos compartilhando a mesma `apiKeyId`. Impressões
digitais truncadas a 12 caracteres nesta publicação.

### 6.2 O desalinhamento de três pontas (VERIFICADO)

| Onde | Identificador | Fonte |
| --- | --- | --- |
| `main.dart` inicializa contra | `1:…:android:734aaa61…` = **BMV Teste** | [main.dart:37](app/lib/main.dart:37) |
| O CI monta o APK com applicationId | `com.buracomastervip.poc.buraco_master_vip` | [.github/workflows/build.yml:24](.github/workflows/build.yml:24), `flutter create --org com.buracomastervip.poc` |
| A Play Console publica o pacote | `io.github.soniaambrosio.buracomastervip` | [functions-billing/index.js:55](functions-billing/index.js:55) |
| O app Firebase canônico é | `1:…:android:b1cd95ba…` | apps:list + laudo do Crashlytics |

O binário do CI é **internamente coerente** — pacote `…poc…` contra registro
`BMV Teste`, que tem esse mesmo pacote. É por isso que nada quebra hoje: Auth e
Functions não checam pacote. **Play Integrity checa.**

Existem, portanto, dois desalinhamentos distintos, e é preciso não confundi-los:

- **`main.dart` × app oficial.** O binário publicável aponta para o registro de
  teste. Precisa ser corrigido antes de qualquer ativação — e isso **também é
  pré-requisito de Crashlytics**, que já registrou o mesmo problema ("o app roda
  e manda crash para um painel que ninguém abre").
- **CI × Play.** O pipeline de build não produz o applicationId que a Play
  publica. Enquanto isso valer, **nenhum artefato do CI pode ser usado para
  homologar App Check**: ele será atestado contra o pacote errado.

### 6.3 O que os documentos oficiais exigem, confrontado com o medido

Da documentação do provider Play Integrity:

| Exigência oficial | Estado medido |
| --- | --- |
| App selecionado/adicionado na Google Play Console, com o projeto Cloud vinculado | **NÃO VERIFICADO** (§6.4) |
| *"O projeto selecionado aqui precisa ser o mesmo projeto Firebase em que você registra seu app"* | **NÃO VERIFICADO** |
| Ser **Owner** do projeto a vincular | **NÃO VERIFICADO** |
| *"Você precisará fornecer a impressão digital SHA-256 do certificado de assinatura do app"* | **REPROVA como está**: o app **Oficial** (`…b1cd95ba…`) tem **zero SHA-256** registrado. O app **BMV Teste** também tem **zero** |
| Distribuição exclusiva na Play exige `PLAY_RECOGNIZED` **e** `LICENSED`; fora da Play, nenhum dos dois; nos dois canais, `PLAY_RECOGNIZED` sem `LICENSED` | **DECISÃO NÃO TOMADA** — depende de a distribuição ser só Play ou também fora dela |
| `activate()` deve rodar **depois** de `Firebase.initializeApp()` | **JANELA EXISTE E É ÚNICA** (§4.5) |
| Antes do enforcement, produtos Firebase **não exigem** token válido; as métricas do console mostram a distribuição | **É o que torna a estratégia de §7 possível** |

O item da SHA-256 é o mais objetivo e o mais fácil de subestimar: **os dois apps
que importam não têm nenhuma registrada**. Não é uma configuração de App Check —
é uma configuração do registro do app Android, e ela precede tudo.

### 6.4 O que NÃO pôde ser verificado, e por quê

A CLI do Firebase **não expõe comandos de App Check**. A leitura do estado real
exigiria chamar `firebaseappcheck.googleapis.com` diretamente, o que por sua vez
exigiria extrair um token de acesso da sessão da CLI. **Essa tentativa foi
bloqueada pelo classificador de permissões desta sessão, e não foi contornada.**

Registrado como **`NÃO VERIFICADO`**, sem presunção em nenhuma direção:

| Item | Estado |
| --- | --- |
| API App Check (`firebaseappcheck.googleapis.com`) habilitada no projeto | **NÃO VERIFICADO** |
| Provider Play Integrity registrado para `…b1cd95ba…` | **NÃO VERIFICADO** |
| Provider Play Integrity registrado para `…734aaa61…` | **NÃO VERIFICADO** |
| Enforcement por serviço (Cloud Functions / Firestore / Auth) | **NÃO VERIFICADO** |
| Métricas de App Check já coletando | **NÃO VERIFICADO** |
| Debug tokens já cadastrados | **NÃO VERIFICADO** |
| Vínculo Firebase ↔ Google Play Console | **NÃO VERIFICADO** |
| Trilhas da Play (interna / fechada / produção) e quais pacotes têm | **NÃO VERIFICADO** |
| TTL de token configurado | **NÃO VERIFICADO** |
| Play Integrity API habilitada no projeto Cloud | **NÃO VERIFICADO** |

**Como fechar, em leitura pura:** abrir o console em
`Firebase → Compilação e versão → App Check → Apps` e ler; e na Play Console,
`Configurações → Vínculos de API → Firebase`. Ambos são telas de leitura. Esta
arbitragem recomenda que a OS de implementação **comece por essa leitura**, e
não pela primeira linha de código.

---

## 7. Estratégia segura de ativação

Sequência proposta. Cada passo diz **quem** age e **em que superfície** — e as
superfícies não se misturam de propósito, porque o histórico deste projeto mostra
que confundir "mudou o código" com "mudou o console" é o que produz o diagnóstico
errado.

### Fase 0 — Alinhar identidade (sem tocar em App Check)

| # | Ação | Superfície | Responsável |
| --- | --- | --- | --- |
| 0.1 | Ler o estado real do console e da Play; converter os `NÃO VERIFICADO` de §6.4 em fatos | **Console (leitura)** | Sônia |
| 0.2 | Decidir o alvo: `io.github.soniaambrosio.buracomastervip`, app `…b1cd95ba…` | decisão | Sônia |
| 0.3 | Trocar o `appId` de `main.dart` para o app oficial e **atualizar o hash de `C16`** | **Código** | OS de implementação |
| 0.4 | Fazer o pipeline produzir o applicationId oficial (hoje `--org com.buracomastervip.poc`) | **Código (CI)** | OS de implementação |
| 0.5 | Registrar a SHA-256 do certificado de assinatura no app Firebase oficial | **Console Firebase** | Sônia |
| 0.6 | Vincular o projeto Firebase à Play Console e habilitar a Play Integrity API | **Play + Cloud** | Sônia (precisa ser Owner) |

**Sem a Fase 0 inteira, nada abaixo funciona.** 0.3 e 0.4 andam juntas: separá-las
produz um binário cujo pacote não bate com o registro que ele declara.

### Fase 1 — Instrumentar o cliente

| # | Ação | Superfície |
| --- | --- | --- |
| 1.1 | `activate()` em `main.dart`, entre `initializeApp` e `runApp`, com `try/catch` próprio (§4.5) | **Código** |
| 1.2 | Provider por variante: depuração fora de release, Play Integrity em release. A seleção deve ser **constante de compilação** (`kReleaseMode` / `const fromEnvironment`), copiando a forma de [endpoint_servidor.dart:91](app/lib/services/endpoint_servidor.dart:91) — só assim o ramo morto é eliminado do binário (§3.4) | **Código** |
| 1.3 | Corrigir o P0 de §3.5: `unauthenticated` na identidade vira motivo ambíguo e **retryável**, espelhando `credencialOuAtestacao` | **Código** |
| 1.4 | Atualizar o hash de `C16` | **Código** |

### Fase 2 — Depuração, em ambiente de desenvolvimento apenas

| # | Ação | Superfície |
| --- | --- | --- |
| 2.1 | Rodar build de depuração, colher o token do log | Máquina |
| 2.2 | Cadastrar em `App Check → Apps → Gerenciar tokens de depuração` | **Console Firebase** |
| 2.3 | Exercer as três callables de §4.3 e ver token válido nas métricas | **Console (leitura)** |

O token de depuração *"permite acesso aos seus serviços de back-end sem um
dispositivo válido"*. **Não vai para o repositório e não vai para build de
release** — a barreira de 1.2 é o que garante isso estruturalmente, e não a
disciplina de quem faz o build.

### Fase 3 — Play Integrity em release, ainda sem enforcement

| # | Ação | Superfície |
| --- | --- | --- |
| 3.1 | Build de release assinado com o certificado cuja SHA-256 foi registrada em 0.5 | **Código/CI** |
| 3.2 | Subir para uma trilha de teste da Play (o provider precisa do reconhecimento da Play) | **Play** |
| 3.3 | Instalar pela trilha e exercer as três callables | Aparelho |
| 3.4 | **Observar métricas por um período com tráfego real** | **Console (leitura)** |

O passo 3.4 é o que a documentação oficial protege ao dizer que os produtos não
exigem token válido até o enforcement ser ligado. **É a única oportunidade de
descobrir o desalinhamento antes que ele recuse alguém.** Não pular.

### Fase 4 — Liberar versão compatível

| # | Ação | Superfície |
| --- | --- | --- |
| 4.1 | Publicar a versão com App Check para os canais que serão protegidos | **Play** |
| 4.2 | Esperar a adoção subir nas métricas | **Console (leitura)** |

**A ordem é irreversível na prática:** enforcement ligado antes de a versão
compatível estar nas mãos das pessoas recusa quem está numa versão anterior. Foi
exatamente o que o comentário de
[firebase/functions/index.js:38-47](firebase/functions/index.js:38) previu, e por
isso `ENFORCE_APP_CHECK` nasceu desligado.

### Fase 5 — Ampliar o enforcement, um serviço por vez

| Ordem | Alvo | Por quê |
| --- | --- | --- |
| 1º | **Cloud Functions** — `ranking` e `social` | Já exigem App Check no código; são as três callables que o app realmente emite. É o único enforcement cuja superfície esta arbitragem mediu por inteiro |
| 2º | `colecoes` — `ENFORCE_APP_CHECK=true` | Uma variável de ambiente; **só depois** de o resgate voltar a ser alcançável e ter sido exercido sob App Check |
| 3º | **Firestore** | Hoje **inalcançável pela raiz** (§4.4). Ligar antes de outra branch reabrir esse caminho protege o que não é usado e prepara uma armadilha para quem reabrir |
| 4º | **Billing** | Região diferente, branch diferente, defeito conhecido. Item de outra OS (§5.4) |

### Rollback

| Situação | Reversão | Custo | Superfície |
| --- | --- | --- | --- |
| Enforcement de Functions derruba tráfego | Desligar no console | **Segundos**, sem deploy | **Console** |
| `colecoes` recusando resgate | `ENFORCE_APP_CHECK` de volta a falso + deploy do codebase | Minutos | **Firebase** |
| `activate()` quebrando a abertura | Reverter o commit e republicar | **Dias** — passa pela revisão da Play | **Play** |
| Provider mal configurado | Corrigir no console | Minutos | **Console** |

A assimetria é a lição operacional: **o console reverte em segundos; a Play
reverte em dias.** Por isso toda a incerteza deve ser resolvida nas Fases 2–3,
onde a correção é barata, e o enforcement só é ligado quando não sobra dúvida.

### Resposta a indisponibilidade do provider

| Sintoma | O que é | Resposta certa | Resposta errada |
| --- | --- | --- | --- |
| Falha transitória do Play Integrity | Token não emitido; callable recusa com `unauthenticated` | **Repetir.** Exige o P0 de 1.3 | Deslogar ou mandar "entre de novo" |
| Aparelho sem Play Store / instalação fora da Play | Play Integrity não atesta | Recusa esperada; decisão de negócio (§6.3, `PLAY_RECOGNIZED`/`LICENSED`) | Fallback silencioso para depuração |
| Queda ampla do serviço | Rejeição em massa | **Desligar o enforcement no console** — segundos | Republicar o app |

---

## 8. Matriz futura de testes

`(E)` = emulador ou `flutter test`, sem produção · `(A)` = aparelho + console ·
`(P)` = exige Play Console

| # | Caso | Esperado | Onde | Observação |
| --- | --- | --- | --- | --- |
| 1 | Token válido | Callable responde | (A) | O caminho feliz |
| 2 | Token **ausente** | `unauthenticated`; UI **neutra com retry** | (E) | Encenável: `FirebaseFunctionsException('unauthenticated')` nos fakes. **Reprova hoje** no caminho de identidade (§3.5) |
| 3 | Token **inválido** | Idem ao #2 | (E) | Indistinguível de #2 no cliente — e isso é o contrato, não um defeito |
| 4 | Token **expirado** | Renovação transparente; se falhar, cai em #2 | (A) | O SDK renova sozinho |
| 5 | Debug **autorizado** | Callable responde | (A) | Prova a Fase 2 |
| 6 | Debug **não autorizado** | Recusa | (A) | Prova que o token de depuração é mesmo uma lista de permissão |
| 7 | **Autenticado sem App Check** | `unauthenticated` **sem deslogar**, com retry | (E) | **O caso central de toda esta arbitragem.** É o que o Ranking já faz e a Identidade ainda não |
| 8 | **App Check sem sessão** | `unauthenticated` — e aqui é sessão de verdade | (E) | Prova que `haSessaoLocal: false` continua produzindo `sessaoInvalida` |
| 9 | Troca de usuário | Token de App Check **não** é reemitido (é do app, não da conta); a geração da sessão sobe | (E) | Confirma que App Check e sessão são eixos independentes |
| 10 | Reinstalação | Token novo emitido de forma transparente | (A) | Debug token **não** sobrevive |
| 11 | Aparelho **sem Play Store** | Play Integrity não atesta | (A) | Ver §7, resposta a indisponibilidade |
| 12 | Instalação **fora da Play** | Depende de `PLAY_RECOGNIZED`/`LICENSED` | (P) | **Decisão de negócio pendente** (§6.3) |
| 13 | **Teste fechado** | Atestação funciona na trilha | (P) | Fase 3 |
| 14 | Falha **temporária** do provider | Recusa transitória; retry resolve | (A) | Difícil de forçar; observar em métricas |
| 15 | **Retry sem logout indevido** | Nenhum caminho de erro chama `signOut` | (E) | **Passa hoje** — provado por varredura: a única chamada é a do comando explícito |

Onze dos quinze casos (#1–#10, #14, #15) são exercíveis **sem produção**; os
quatro restantes (#11–#13 e a validação real de #14) exigem aparelho e Play.

Dois avisos de método, ambos com precedente medido neste projeto:

1. **Casos #2, #3, #7 e #8 pertencem a `flutter test`**, não ao emulador. O
   emulador de Functions **dispensa** App Check por construção
   (`FUNCTIONS_EMULATOR !== "true"`), então ele **não consegue** produzir a
   recusa. Quem produz é um fake que lança `FirebaseFunctionsException` — que é
   como a suíte de regressão do leitor de ranking já testa.
2. **Suítes com prefixo `teste_` ficam fora do glob padrão** de `flutter test` e
   fora do CI. Casos novos devem nascer como `*_test.dart`.

---

## 9. Veredito

# BLOCKED — CONFIGURAÇÃO EXTERNA AUSENTE

O bloqueio **não é de autoridade nem de ordem de bootstrap**. A ordem está
definida, é única e é provável em código: a janela entre
[main.dart:55](app/lib/main.dart:55) e [main.dart:57](app/lib/main.dart:57)
precede toda callable do aplicativo, e a autoridade sobre a sessão é única e não
disputada. Se o único obstáculo fosse código, esta arbitragem entregaria
`READY`.

O que bloqueia é externo, e são cinco fatos:

1. **`main.dart` inicializa contra o app Firebase errado** — `BMV Teste` /
   `com.buracomastervip.poc.buraco_master_vip`, e não o oficial
   `io.github.soniaambrosio.buracomastervip`.
2. **Nenhum dos dois apps que importam tem SHA-256 registrada**, e a
   documentação oficial a exige para o provider Play Integrity.
3. **O CI produz um applicationId que a Play não publica** — nenhum artefato do
   pipeline atual serve para homologar App Check.
4. **O vínculo Firebase ↔ Play Console é `NÃO VERIFICADO`**, e é pré-requisito
   oficial.
5. **A distribuição (só Play, ou também fora dela) é uma decisão de negócio não
   tomada**, e ela determina `PLAY_RECOGNIZED`/`LICENSED`.

Há ainda um **P0 de código** que não bloqueia sozinho, mas que precisa entrar na
mesma OS: `unauthenticated` na identidade é traduzido como não-retryável (§3.5).
Ligar App Check antes de corrigi-lo transforma uma falha de atestação num beco
sem saída para quem está legitimamente logado.

### 9.1 Arquivos que uma OS futura tocaria

| Arquivo | O quê | Por quê |
| --- | --- | --- |
| [app/lib/main.dart](app/lib/main.dart) | `appId` oficial; `activate()` entre `initializeApp` e `runApp`; `try/catch` próprio; provider por variante | Única janela que precede toda callable |
| [app/test/composicao/composicao_perfil_ranking_test.dart:746](app/test/composicao/composicao_perfil_ranking_test.dart:746) | Atualizar o SHA-256 fixado em `C16` | O portão reprova qualquer mudança em `main.dart` |
| [app/lib/sessao/fonte_identidade_firebase.dart:78](app/lib/sessao/fonte_identidade_firebase.dart:78) | `unauthenticated` → motivo ambíguo | **P0** — hoje afirma o que não foi provado |
| [app/lib/sessao/identidade_publica_sessao.dart:94](app/lib/sessao/identidade_publica_sessao.dart:94) | Motivo ambíguo e retryável | Par do anterior |
| [.github/workflows/build.yml:24](.github/workflows/build.yml:24) e `--org` | applicationId oficial | Sem isso o artefato é atestado contra o pacote errado |
| [firebase/functions/index.js:47](firebase/functions/index.js:47) | Nada no código — só `ENFORCE_APP_CHECK` no deploy | O mecanismo já existe |
| `app/test/**` | Casos #2, #3, #7, #8 como `*_test.dart` | §8 |

**Não tocar:** `functions-ranking/src/index.ts`, `functions/src/index.ts`,
`functions-social/src/index.ts`, `functions-moderacao/src/index.ts` — o
enforcement já está correto. E **não** acrescentar App Check às `opcoesServidor`:
tornaria as funções inalcançáveis pelo servidor Node.

### 9.2 Responsáveis

| Ação | Superfície | Quem |
| --- | --- | --- |
| Ler o estado do console e da Play (§6.4) | Console/Play (leitura) | **Sônia** |
| Decidir o alvo de pacote e a distribuição | decisão | **Sônia** |
| Registrar SHA-256; vincular à Play; habilitar Play Integrity; cadastrar debug token; ligar enforcement | **Console/Play (escrita)** | **Sônia** (exige Owner) |
| `main.dart`, `C16`, P0 da identidade, applicationId do CI, testes | **Código** | **OS de implementação** |
| `ENFORCE_APP_CHECK=true` | **Deploy do codebase `colecoes`** | **OS de implementação**, após Fase 4 |

### 9.3 Testável sem produção × exige console ou Play

| Sem produção (`flutter test` / emulador) | Exige console ou Play |
| --- | --- |
| Ordem de bootstrap: `activate()` antes da 1ª callable | Registro do provider Play Integrity |
| Casos #2, #3, #7, #8, #9, #15 da matriz | Atestação real (#1, #5, #6, #10, #11) |
| Que o P0 da identidade foi corrigido | Métricas de adoção |
| Que nenhum caminho de erro desloga | Enforcement e seu rollback |
| Que o binário de release não carrega provider de depuração | Trilha fechada (#13) |
| `C16` atualizado e auditorias verdes | Vínculo Firebase ↔ Play |

### 9.4 Riscos, e o que cada um custa

| Risco | Se acontecer | Mitigação |
| --- | --- | --- |
| Enforcement antes da versão compatível | **Recusa de quem está numa versão anterior** | Fase 4 antes da 5; desligar reverte em segundos |
| Provider de depuração num build de release | Atestação de graça para qualquer um | Seleção por variante estrutural (1.2), não por disciplina |
| Enforcement com o registro de app desalinhado | **Recusa universal** | Fase 0 inteira antes de tudo |
| Falha de atestação lida como sessão morta | Jogador mandado a logar numa conta em que já está | **P0 de 1.3** |
| Ligar Firestore junto com Functions | Armadilha para quem reabrir o caminho de coleções | Enforcement um serviço por vez (Fase 5) |
| Ligar Billing junto | Compra recusada em `us-central1` | Fora do escopo; OS de Billing (§5.4) |
| `activate()` dentro do `try/catch` de `initializeApp` | Falha engolida; App Check silenciosamente ausente | `try/catch` próprio, e não o herdado |

---

## 10. Limites declarados desta arbitragem

1. **Somente leitura.** Nada foi ativado, criado, alterado ou implantado. A
   única consulta remota emitida foi um GET de `apps:list`.
2. **O estado do App Check no console é `NÃO VERIFICADO`** — a CLI não o expõe, e
   a extração de token de acesso foi bloqueada pelo classificador de permissões e
   **não foi contornada**. §6.4 lista item por item.
3. **A medição vale para `6e428e8`.** Outras branches têm topologia diferente:
   `claimPioneerKit`, Firestore direto e Billing podem estar alcançáveis nelas, e
   aí a superfície de §4.4 muda.
4. **Nenhum teste foi executado.** A reachability de §4 foi computada por
   varredura de imports, com o mesmo algoritmo das auditorias estruturais da
   linhagem, não pela execução delas.
5. **A documentação oficial foi lida em 17/08/2026.** Os requisitos do provider
   Play Integrity mudaram no passado; reconferi-los na véspera da ativação é
   parte da Fase 0.
