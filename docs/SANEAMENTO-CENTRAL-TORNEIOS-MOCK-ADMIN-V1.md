# Saneamento produtivo da Central de Torneios — mock e admin V1

**Veredito:** `PASS — CENTRAL DE TORNEIOS SEM FERRAMENTAS MOCK E ADMIN PROTEGIDO POR AUTORIDADE V1`

Base: `claude/integracao-splash-rive-constelacao-v1 @ 9a2c404` (a folha canônica da
linhagem da Casca V2, de 19/08/2026). Publicada sem merge, sem PR e sem deploy.

---

## Gate Zero

### 1. Qual Central de Torneios é alcançável na Casca V2

**Nenhuma.** O fecho transitivo de imports que nasce em `lib/main.dart` tem 50
arquivos em `9a2c404`, e não há um único arquivo de torneios entre eles.
`lib/casca/` inteiro não menciona a palavra "torneio"; `main.dart` a menciona uma
vez, num comentário que registra o que saiu.

`TorneiosPreviewPage` (o host), `CentralTorneiosScreen`, `AdminTorneiosScreen` e
`ModeloTorneioScreen` só se referenciam entre si — e aparecem uma vez em
`test/casca/auditoria_casca_test.dart`, numa lista de maquetes cuja
**alcançabilidade é proibida** e já roda no CI.

Isso muda a leitura dos dois P0 do censo. Eles foram medidos em
`auditoria/censo-telas-prontidao-v1 @ a97866c`, cuja base é
`consolidacao/apk-geral-bmv @ 0cea0d6` — o `main.dart` de 2.172 linhas, a bancada
de prévias, onde `main.dart:373` levava o banner de temporada direto à
`TorneiosPreviewPage()`. Ali os dois defeitos eram reais e produtivos.

Na linhagem da Casca V2 eles já estão fora do caminho produtivo **por exclusão**.
E é exatamente aí que mora o problema que esta OS resolve: a exclusão protege o
binário de hoje e não protege nada de amanhã. `mostrarAdmin: true` e o seletor de
cenários continuavam escritos, esperando o dia em que a Central fosse ligada à
Casca — e voltariam junto com ela, sem que ninguém decidisse isso.

### 2. Onde está a autoridade real de papel

Existe, é uma só, e é do backend: o **custom claim `admin` do Firebase Auth**.
Quatro consumidores independentes já o tratam como a autoridade:

| Consumidor | Linha |
|---|---|
| `firebase/firestore.rules` — `ehAdmin()` e `admin()` | `request.auth.token.admin == true` |
| `firebase/functions/index.js` — `exigirAdmin()` | `token.admin !== true` → `permission-denied` |
| `functions-ranking/src/index.ts` | `token.motorDePartidas !== true && token.admin !== true` |
| `functions/src/rastreabilidade.ts` | `token.admin === true` → `"administrador"` |

**Não havia produtor, e continua não havendo.** `setCustomUserClaims` não aparece
em nenhum arquivo do repositório. Ver a seção de residuais.

**Não havia consumidor no cliente.** `getIdTokenResult()` não era chamado em lugar
nenhum; a `SessaoDoJogador` emitia o ID Token como string opaca e nada lia claim.

### 3. As 7 telas de torneio são produto ou preview

**Preview, as sete.** Todas são alimentadas exclusivamente por `TorneiosMockData`
a partir de `pages/torneios_preview_page.dart`; nenhuma fala com serviço,
Firestore ou callable, e os 19 callbacks de `TorneiosCallbacks` eram todos
`_toast(...)`.

| # | Tela | Fonte |
|---|---|---|
| 1 | `CentralTorneiosScreen` | `TorneiosMockData.cards()` |
| 2 | `TorneioDetalhesScreen` | `TorneiosMockData.detalhes()` |
| 3 | `SalaEsperaTorneioScreen` | `TorneiosMockData.sala()` |
| 4 | `ClassificacaoTorneioScreen` | `TorneiosMockData.classificacaoVM()` |
| 5 | `ResultadoTorneioScreen` | `TorneiosMockData.resultado()` |
| 6 | `AdminTorneiosScreen` | `TorneiosMockData.admin()` |
| 7 | `ModeloTorneioScreen` | `TorneiosMockData.modelo()` |

Isso é coerente com [`torneios-motor-pendencias-de-regra`]: os números do mock
(64 vagas, 4 rodadas, 1.500 pontos) são material de tela, não regra de competição.
**A OS não os tocou**, conforme a regra "não corrigir dados mock das outras telas
por tabela".

---

## O que foi entregue

### O seletor "Cenários mock" saiu inteiro

Não só do host: **do componente**. `CentralTorneiosScreen` tinha
`onAbrirCenariosMock` na própria API pública, e o `IconButton` de laboratório era
renderizado sempre que o chamador passasse o callback. Saíram o parâmetro, o
botão, a folha de ~35 cenários encenados (`_abrirCenariosMock`), o `_cenarioTile`
e o `_abrirSalaComStatus` que só ela usava. `torneios_preview_page.dart` caiu de
279 para 180 linhas.

Um atalho que "só existe quando o host o liga" volta sozinho no dia em que alguém
religa o host. Por isso ele não podia continuar sendo uma opção do componente.

### `mostrarAdmin` deixou de existir

O `bool` era uma **afirmação do chamador sobre o jogador**. Foi substituído por
`FonteDePapel autoridade` — uma porta com um método, que a tela *pergunta*.

    // antes
    CentralTorneiosScreen(..., mostrarAdmin: true, onAbrirAdmin: _abrirAdmin)

    // agora
    CentralTorneiosScreen(...)                       // padrão: SemPapel → sem atalho
    CentralTorneiosScreen(..., autoridade: autoridadeAdministrativaDe(sessao))

O padrão é `SemPapel()`: **o esquecimento erra para o lado fechado**.

### A guarda mora na tela, não no botão

`AdminTorneiosScreen` passou a **exigir** `autoridade` no construtor — sem padrão,
de propósito. Não existe forma de compilar a tela de gestão sem dizer quem
autoriza, e a verificação acontece dentro dela, antes de qualquer leitura de
`widget.torneios`.

Esconder o atalho na Central protege contra o *toque*. Uma rota é alcançável de
outros jeitos — um `Navigator.push` escrito noutro arquivo, um atalho de
navegação, um deep link no dia em que houver um. Com a guarda na tela, construí-la
diretamente não adianta.

Três estados, e são distintos de propósito: `null` (perguntando), `false`
(negado), `true` (liberado). "Verificando" e "negado" desenham o **mesmo quadro**,
mudando só a última linha — se desenhassem quadros diferentes, o tempo de resposta
viraria um oráculo sobre o papel da conta.

### A autoridade vem do claim assinado, e falha fechado

Camada de sessão, seguindo o padrão já estabelecido por `credencial_de_sessao.dart`:

- `sessao/papel_de_sessao.dart` — a porta `FonteDePapel` (um método booleano) e o
  padrão `SemPapel`. Sem imports, sem `conceder`/`definir`/`assumir`.
- `sessao/sessao_firebase.dart` — `PapelDoFirebase`, que lê
  `getIdTokenResult().claims['admin'] == true`. **Único ponto do cliente que sabe
  ler o claim**, com teste estrutural que falha se surgir um segundo.
- `SessaoDoJogador.temAutoridadeAdministrativa()` — a única porta, com a **trava de
  geração**: entre perguntar e receber há um `await`, e uma troca de conta cabe
  inteira nele. Sem a trava, o "sim" de quem acabou de sair seria entregue à conta
  nova.
- `casca/autoridade_administrativa_de_producao.dart` — o adaptador
  `autoridadeAdministrativaDe(sessao)`, com igualdade por sessão (é ela que faz a
  tela distinguir "mesma conta, reconstruiu" de "conta diferente").

**O cliente não inventa papel: ele lê o que o backend assinou.** E a interface
nunca é o portão — mesmo que este leitor errasse para mais, quem recusa a operação
continua sendo a regra do Firestore e a Cloud Function. Por `ehAdministrador()`
falhar fechado, o pior erro possível da tela é esconder de quem tinha direito.

---

## Prova

| Medição | Resultado |
|---|---|
| Suíte nova `test/torneios/saneamento_mock_admin_test.dart` | **26 verdes** |
| `flutter test` (glob) | **1.227 verdes** |
| Os seis alvos de prefixo `teste_*` | **459 verdes** (132+196+10+64+42+15) |
| Total | **1.686 verdes** |
| `flutter analyze` vs `9a2c404` | **38 issues, 0 erros — conjunto idêntico** |
| Mutações injetadas | **10 injetadas, 10 detectadas** |

### As dez mutações

| # | Mutação | Veredito |
|---|---|---|
| M1 | Central nasce com o atalho aberto (`_podeAdministrar = true`) | pegou |
| M2 | Central ignora a troca de autoridade durante o `await` | pegou |
| M3 | Tela de gestão desenha sem verificar | pegou |
| M4 | Tela de gestão aceita autoridade opcional (`= const SemPapel()`) | pegou |
| M5 | Sessão perde a trava de geração no papel | pegou |
| M6 | Sessão consulta papel sem estar autenticada | pegou |
| M7 | Provedor que lança vira autoridade | pegou |
| M8 | Seletor de cenários de laboratório volta a `lib/` | pegou |
| M9 | `mostrarAdmin` volta como parâmetro | pegou |
| M10 | Segundo leitor do claim `admin` fora da sessão | pegou |

### Portões de CI

A suíte entrou nos **dois** workflows, porque eles medem coisas diferentes:

- `build.yml` — passo próprio, "PORTÃO DE AUTORIDADE". O portão da casca ali roda
  `flutter test test/casca`, que mede o fecho de `main()` — e a Central está fora
  dele, então a ausência passaria sem ser medida.
- `ci-os-integracao.yml` — `roda torneiosmk`, com a chave `torneiosmk` acrescentada
  à lista do veredito verde/vermelho (sem isso o alvo rodaria e não pesaria).

### A auditoria do fecho foi atualizada, com nome

`test/casca/avatar_publico_canonico_test.dart` afirma o tamanho exato do fecho
alcançável. Ele foi de **50 para 51**, e o arquivo que entrou está declarado:
`lib/sessao/papel_de_sessao.dart` (importado por `sessao_do_jogador.dart` e
`sessao_firebase.dart`, que já estavam lá; não arrasta nada — não tem import).

Foi acrescentada também a afirmação **negativa**: o adaptador
`casca/autoridade_administrativa_de_producao.dart` **não** está no fecho, porque
ainda não tem chamador. Se ele aparecer lá sem a Central ter sido ligada, alguém o
chamou de um lugar que esta auditoria não previu, e o teste denuncia.

---

## Residuais registrados

1. **O claim `admin` não tem produtor.** `setCustomUserClaims` não existe no
   repositório. Consequência prática: hoje ninguém é administrador, a área de
   gestão não aparece para conta nenhuma, e a Sônia não consegue se conceder o
   papel pelo aplicativo — por construção, já que "cliente não inventa papel". Para
   ativar, o claim precisa ser gravado pelo Admin SDK (console, script ou callable
   de bootstrap), exatamente como foi feito para `motorDePartidas`. **Esta OS não
   fabricou esse produtor**, e a ausência dele é o lado seguro: a falha é fechada.

2. **`PapelDoFirebase` não tem teste de comportamento.** Ele depende do SDK do
   Firebase, que não sobe dentro de `flutter test` — a mesma limitação de
   `CredencialDoFirebase`. O que a suíte prova é que ele é o **único** leitor do
   claim no cliente (prova estrutural) e que tudo acima dele falha fechado.

3. **Claim atrasado.** `getIdTokenResult()` devolve o token em cache; um papel
   concedido agora só aparece na próxima renovação do token, ou depois de reentrar.
   É comportamento do Firebase, e é o lado seguro do atraso — o backend confere o
   claim a cada chamada, independentemente do que a tela desenhou.

4. **A Central continua fora do caminho produtivo.** A OS proibiu ligar o motor de
   torneios, e ela não foi ligada. O que mudou é que, quando for, não haverá
   ferramenta de laboratório nem papel fabricado vindo junto.

5. **Transbordo de layout no cartão da Central.** `torneios_screens.dart` acusa
   `RenderFlex overflowed` sob a fonte substituta do runner (código de produto que
   esta OS não tocou). A suíte filtra **só** esse diagnóstico, de forma estreita;
   qualquer outra exceção continua reprovando.

---

## Arquivos

**Novos**

- `app/lib/sessao/papel_de_sessao.dart`
- `app/lib/casca/autoridade_administrativa_de_producao.dart`
- `app/test/torneios/saneamento_mock_admin_test.dart`

**Alterados**

- `app/lib/screens/torneios_screens.dart` — Central sem seletor mock e sem
  `mostrarAdmin`; gestão com autoridade obrigatória e guarda própria
- `app/lib/pages/torneios_preview_page.dart` — sem a folha de cenários, sem
  `mostrarAdmin: true`, sem rota de admin
- `app/lib/sessao/sessao_do_jogador.dart` — `temAutoridadeAdministrativa()`
- `app/lib/sessao/sessao_firebase.dart` — `PapelDoFirebase`
- `app/test/casca/avatar_publico_canonico_test.dart` — fecho 50 → 51, declarado
- `.github/workflows/build.yml`, `.github/workflows/ci-os-integracao.yml` — portões
