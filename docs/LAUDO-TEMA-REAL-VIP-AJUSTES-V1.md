# Laudo — Tema Real VIP e iconografia canônica das Configurações V1

## Veredito

```text
PASS ESTRUTURAL — ATIVAÇÃO DO TEMA REAL BLOQUEADA POR ASSETS
```

A arquitetura inteira está entregue, provada e com portão de CI. O Tema Real não
acende hoje, e por um motivo só: **os 28 arquivos de arte não existem em nenhuma
ref do repositório**. Enquanto não existirem, todo mundo — inclusive o assinante
VIP em dia — recebe o Tema Padrão, que é o fallback integral da §7 funcionando
como especificado.

A lista exata do que falta está na seção 7.

---

## 1. Branch e SHA

| item | valor |
| --- | --- |
| branch | `claude/tema-real-vip-iconografia-ajustes-v1` |
| SHA do código | `dc3a46bc13267949cb7d96da0cf4c627b507c855` |
| ponta remota no selamento | `79e6ad89243606c2351930132b63c493d5758f65` |
| local == remoto | sim, por `git ls-remote` (não por `refs/remotes/`) |
| árvore | limpa |
| deploy / PR / merge / force | nenhum |

**Sobre os dois SHAs, e por que eles não podem ser um só.** Um documento não pode
conter o próprio SHA: o commit que sela este laudo é, por construção, posterior ao
SHA que ele nomeia. `79e6ad8` é a ponta remota **no instante do selamento**; o
commit que carrega esta própria tabela é o seguinte, e é documental como os
outros — mesma classe, mesmo diretório, nenhuma linha fora de `docs/`.

O que fica provado, e é a afirmação que importa, é que **o código não mudou desde
`dc3a46b`**:

```text
git diff-tree -r --name-status dc3a46b HEAD
A   docs/LAUDO-TEMA-REAL-VIP-AJUSTES-V1.md
```

Uma linha, e só ela, em toda a árvore. As árvores de `app/`, `scripts/`,
`.github/`, `android/`, `firebase/`, `ferramentas/`, `tools/`, `servidor/`, `web/`
e das nove codebases de Functions têm **hash idêntico** nos dois commits — o de
`app/` é `f3f195ee59b2` dos dois lados. Nenhum código, asset, teste, gate,
workflow ou dependência foi tocado depois de `dc3a46b`.

## 2. Base e ancestralidade

| item | valor |
| --- | --- |
| base | `correcao/os24-c3-gate-comunicacao-emulador-v1` @ `d1eb537ca873a5866ef0abeb456c5dceb7c1ec44` |
| data da base | 2026-08-22 (folha maximal mais recente) |
| `merge-base(HEAD, origin/main)` | `2ddadde` — o merge do PR #1, de julho |
| `HEAD ⟷ main` | 581 ⟷ 5 |
| `origin/main` | segue em `fb9edb5`, intocada |

**Gate Zero, duas passagens.** `git ls-remote --heads origin` devolveu **203
refs** nas duas consultas, com `diff` vazio entre elas; `remote.origin.fetch` é
`+refs/heads/*:refs/remotes/origin/*` (não truncado). Folhas maximais por dump de
DAG: **74**.

**A base não é `main` placeholder** — `main` é um ramo lateral de cinco commits
("Add files via upload", "Goodbye World", "noop") que nenhum trabalho tocou.

**Por que esta folha, e não a da acessibilidade.** A tela de Ajustes com o
endurecimento semântico da OS 30 (`5688281`) existe em **3 refs**, e nenhuma
delas tem `app/lib/elegibilidade/entitlement.dart` nem
`app/lib/billing/acesso_vip.dart`. A autoridade VIP existe em **21 refs**, e
nenhuma delas tem a tela endurecida. `merge-base` entre as duas linhagens é
`79063e07` — a raiz —, com **372 ⟷ 28** de divergência. Compor as duas seria
exatamente a composição não autorizada que a §3.1 proíbe. Escolhida a linhagem
que tem a AUTORIDADE, porque sem ela a OS não tem do que consumir; a
acessibilidade foi entregue nesta linhagem por prova própria (seção 9).

## 3. Tela produtiva identificada

| item | caminho |
| --- | --- |
| tela | `app/lib/screens/configuracoes_screen.dart` |
| host produtivo | `app/lib/casca/configuracoes_de_producao.dart` |
| serviço de preferências | `app/lib/services/configuracoes_service.dart` |

**Não existem telas concorrentes de Configurações.** A varredura da árvore por
`config|ajuste|settings` devolve exatamente esses três arquivos mais os de
`configurar_mesa`, que é outra tela (configuração de MESA, não de conta).

## 4. Autoridade VIP consumida

```text
playerEntitlements/{uid}          (escrito só pelo Billing)
        ↓  EntitlementRepositorio.observar(uid)
   PortaoVip  (recomputa vigência contra o relógio a cada leitura)
        ↓  AcessoVip
   resolverTemaDeAjustes           → TemaIconografia
        ↓
   ConjuntoDeIcones                → a tela
```

`EntitlementVip.vigenteEm` é a definição única: `vipAtivo && estado concede &&
agora < expiraEm`. As três condições juntas — um documento incoerente (revogado
com `vipAtivo: true`) não concede.

**O achado deste Gate Zero:** `PortaoVip` existia na árvore e **não era
instanciado em lugar nenhum** de `app/lib/`. As telas o citavam em comentário
("em produção o valor vem de `EscopoVip.de(context)`"), e o host dos Ajustes
trazia `vip: false` escrito à mão, com um comentário afirmando que não havia
autoridade alcançável pelo cliente. Havia — é a mesma porta que a Loja usa. Esta
OS é o primeiro consumidor real dela.

Os cinco estados da §8:

| estado | origem | tema |
| --- | --- | --- |
| `publico` | sem sessão, sem documento, ou `nunca_teve` | Padrão |
| `vipCompletoAtivo` | `ativo` vigente | **Real** |
| `vipCompletoEmCarenciaComBeneficio` | `em_carencia` / `cancelado_vigente` vigentes | **Real** |
| `vipCompletoExpirado` | expirado, revogado, reembolsado, em espera, pausado, pendente | Padrão |
| `desconhecido` | carregando, falha de leitura, estado que o cliente não conhece | Padrão |

## 5. Prova de separação do passe de cortesia

O passe quinzenal mora em `playerCourtesyPass/{uid}`, coleção do backend
`functions-ranking`. A prova é **estrutural**, e é a única honesta: não existe
leitor. `ELG-05` percorre os seis arquivos do caminho do tema — os três de
`lib/tema/`, `acesso_vip.dart`, `entitlement_repositorio.dart` e o host — e exige
que nenhum deles, **fora de comentário**, mencione `playerCourtesyPass` ou
`courtesyPass`. E confere que `functions-ranking/src/passe.ts` continua sem tocar
`playerEntitlements`.

`ELG-06` fecha as outras portas da §8: a decisão de tema não pode citar código,
sala, mesa, amigo, inventário ou item equipado.

## 6. Mapa dos dois conjuntos

**34 chaves** no contrato. **28 variáveis** (o Tema Real pode redesenhar) e
**6 invariantes**.

| chave | Tema Padrão (glifo) | Tema Real (arquivo) |
| --- | --- | --- |
| `editarPerfil` | `edit_rounded` | `editar_perfil.webp` |
| `assinaturaVip` | `workspace_premium_rounded` | `assinatura_vip.webp` |
| `fichasECompras` | `monetization_on_outlined` | `fichas_e_compras.webp` |
| `musica` | `music_note_rounded` | `musica.webp` |
| `efeitosSonoros` | `graphic_eq_rounded` | `efeitos_sonoros.webp` |
| `vibracao` | `vibration_rounded` | `vibracao.webp` |
| `notificacoes` | `notifications_active_outlined` | `notificacoes.webp` |
| `animacoes` | `auto_awesome_motion_rounded` | `animacoes.webp` |
| `ordenarCartas` | `sort_rounded` | `ordenar_cartas.webp` |
| `mao` | `pan_tool_alt_outlined` | `mao.webp` |
| `presencaOnline` | `visibility_outlined` | `presenca_online.webp` |
| `convites` | `person_add_alt_1_rounded` | `convites.webp` |
| `jogadoresBloqueados` | `block_rounded` | `jogadores_bloqueados.webp` |
| `comoJogar` | `menu_book_outlined` | `como_jogar.webp` |
| `suporte` | `support_agent_rounded` | `suporte.webp` |
| `avaliarAplicativo` | `star_rate_rounded` | `avaliar_aplicativo.webp` |
| `secaoConta` | `person_outline_rounded` | `secao_conta.webp` |
| `secaoSomENotificacoes` | `volume_up_outlined` | `secao_som_e_notificacoes.webp` |
| `secaoJogo` | `style_outlined` | `secao_jogo.webp` |
| `secaoPrivacidade` | `shield_outlined` | `secao_privacidade.webp` |
| `secaoGeral` | `tune_rounded` | `secao_geral.webp` |
| `tituloAjustes` | `settings_rounded` | `titulo_ajustes.webp` |
| `confirmarDescarte` | `fact_check_outlined` | `confirmar_descarte.webp` |
| `chatPublico` | `forum_outlined` | `chat_publico.webp` |
| `idioma` | `language_rounded` | `idioma.webp` |
| `termosEPrivacidade` | `policy_outlined` | `termos_e_privacidade.webp` |
| `orientacaoMesa` | `screen_rotation_outlined` | `orientacao_mesa.webp` |
| `saldoDeFichas` | `monetization_on_rounded` | `saldo_de_fichas.webp` |
| **`voltar`** | `chevron_left_rounded` | *idêntico* |
| **`avancar`** | `chevron_right_rounded` | *idêntico* |
| **`expandir`** | `expand_more_rounded` | *idêntico* |
| **`confirmar`** | `check_rounded` | *idêntico* |
| **`sair`** | `logout_rounded` | *idêntico* |
| **`excluirConta`** | `person_remove_outlined` | *idêntico* |

As seis invariantes estão **dentro** do contrato, e não fora dele, para que a
varredura possa exigir que TODO ícone da tela venha daqui: uma chave de fora
seria o buraco por onde a mistura voltaria. `sair` e `excluirConta` são
invariantes por §11.4 — ação destrutiva não pode parecer prêmio VIP; as setas e o
`check` porque dourar uma seta não a torna mais seta.

## 7. Origem dos assets — e o que exatamente falta

**Nenhum dos 28 arquivos existe.** A varredura de `app/assets/` sobre as 203 refs
remotas devolve doze diretórios (`baralho`, `loja`, `perfil`, `ranking`,
`torneios`, `colecoes`, `inicio`, `configurar_mesa`, `hall`, `mesa_vip`,
`splash`, `sons`) e nenhum ícone de Ajustes em nenhum deles. Também não existe
catálogo ou registro de assets de ícones em ref alguma.

Nenhum arquivo novo foi gerado ou incorporado — a §5 e a §6 proíbem, e a proibição
foi respeitada literalmente.

Faltam, em `app/assets/ajustes/real/`:

```
editar_perfil.webp          notificacoes.webp        secao_privacidade.webp
assinatura_vip.webp         animacoes.webp           secao_geral.webp
fichas_e_compras.webp       ordenar_cartas.webp      titulo_ajustes.webp
musica.webp                 mao.webp                 confirmar_descarte.webp
efeitos_sonoros.webp        presenca_online.webp     chat_publico.webp
vibracao.webp               convites.webp            idioma.webp
                            jogadores_bloqueados.webp termos_e_privacidade.webp
                            como_jogar.webp          orientacao_mesa.webp
                            suporte.webp             saldo_de_fichas.webp
                            avaliar_aplicativo.webp
                            secao_conta.webp
                            secao_som_e_notificacoes.webp
```

O registro de origem, com requisitos por arquivo e o procedimento de ativação em
quatro passos, está em `docs/ORIGEM-ICONES-TEMA-REAL.md`.

**`assets/ajustes/real/` NÃO foi declarado no `pubspec.yaml`, e não podia ser:**
o Flutter reprova o build quando um diretório declarado não existe. Declarar antes
da arte quebraria a árvore inteira por causa de um tema que ninguém ainda vê. A
declaração é o passo 2 da ativação.

## 8. Regra de fallback

Duas condições, e as duas têm de valer:

* a autoridade canônica diz que o benefício VIP completo está em vigor **agora**;
* o conjunto luxuoso INTEIRO está registrado e legível.

Faltando qualquer uma, o resultado é Tema Padrão **para a tela toda**. Três
camadas sustentam isso:

1. **construção** — `ConjuntoDeIcones` verifica a completude no construtor; um
   conjunto ao qual falte uma chave não chega a existir, ele lança;
2. **pré-checagem** — `conjuntoRealDisponivel` abre os 28 arquivos um a um e só
   responde `true` se todos abrirem. A decisão acontece ANTES da montagem, então
   o estado "meia tela dourada" não é alcançável;
3. **último recurso** — se ainda assim um arquivo falhar em tempo de desenho, o
   buraco fica do tamanho do ícone e a tela não cai (§7: falha de asset não
   bloqueia Ajustes).

O fallback não gera erro visível, não altera elegibilidade, não modifica
preferência e não navega. O diagnóstico é sanitizado — vocabulário fechado
(`tema=… estado=… motivo=…`), sem uid, e-mail, caminho de arquivo ou mensagem de
exceção — e **não vai para `debugPrint`**: a auditoria da casca (`cascaaud`)
proíbe log nesta camada, e foi ela que reprovou a primeira versão. O diagnóstico é
formado e entregue a quem monta a tela, se essa pessoa disser para onde.

## 9. Dados literais removidos e corrigidos

| §  | antes | depois |
| --- | --- | --- |
| 9  | avatar = inicial do apelido | `IdentidadePublica.avatarRef`, com a inicial como fallback |
| 9  | `email: ''` (fixo no host) | `EscopoAutenticacao.de(context).emailDaConta` |
| 9  | `vip: false` (fixo no host) | `AcessoVip.liberado`, da autoridade |
| 10 | `'${vipPlano} · até ${vipValidoAte}'` (strings) | nove estados + plano + data + renovação, campos do documento |
| 11.1 | `Moedas e compras` / `moedas disponíveis` | `Fichas e compras` / `fichas disponíveis` |
| 11.2 | — | `ComoJogarScreen` preservada, rota inalterada |
| 11.3 | — | já vinha de `String.fromEnvironment('BMV_VERSAO_APP')`; agora com prova |
| 11.4 | — | `Sair da conta` inalterado: vermelho, confirmação, sem ouro |

`Sônia Rainha`, o e-mail da maquete, `Renova em 24/08`, `Mensal` como literal,
`versão 2.0.0` e saldo literal **não existem em `app/lib/`**. A gate `cascaaud`
já guardava parte disso e continua verde.

**O e-mail** aparece nesta tela privada e em nenhuma superfície pública. `DAD-22`
prova os dois lados: que `email`/`emailVerified` continuam na lista de campos
PROIBIDOS de `lib/social/apresentacao.dart`, e que `perfil_page.dart` e
`identidade_publica_sessao.dart` não falam de e-mail. Ele veio pela autoridade de
CONTA (`ComandosDeAutenticacao.emailDaConta`, getter concreto com padrão `null`),
e não pela `IdentidadePublica` — porque e-mail é dado de conta, não de perfil.

## 10. Testes e contagens

**Suíte nova:** `app/test/casca/tema_real_vip_ajustes_test.dart` — **38 provas**,
os 38 itens da §15, em seis grupos: `ELG` (8), `AST` (6), `EST` (6), `DAD` (6),
`A11Y` (6), `NRG` (6).

| medida | base `d1eb537` | HEAD `dc3a46b` |
| --- | --- | --- |
| `flutter test` (app inteiro) | 1677 / 1677 | **1715 / 1715** |
| `flutter test test/casca` | 181 | 219 |
| `dart analyze lib test` | 41 issues, 0 erros | **40 issues, 0 erros** |

O issue a menos é um `duplicate_import` que existia no host (o mesmo
`escopo_sessao.dart` importado duas vezes) e saiu junto.

**Campanha de mutação: 12 sabotagens, 12 vermelhos, controles verdes nas duas
pontas.**

| # | mutação | quem acusa |
| --- | --- | --- |
| M01 | um ícone padrão some do contrato | `ConjuntoDeIcones` (construção) |
| M02 | um ícone VIP obrigatório some do manifesto | `AST-10` |
| M03 | mistura parcial: uma chave variável volta ao glifo no Tema Real | `AST-14` |
| M04 | o passe de cortesia entra na decisão de tema | `ELG-05` |
| M05 | variável local substitui a autoridade VIP | `ELG-01/04/07` |
| M06 | `Moedas e compras` reaparece | `DAD-24` |
| M07 | versão fixa `2.0.0` no lugar da build | `DAD-25` |
| M08 | o arquivo do ícone volta a ser lido pelo leitor de tela | `A11Y-28` |
| M09 | fallback deixa de ser integral | `AST-11` |
| M10 | a suíte é esvaziada mantendo nome e caminho | contrato (`sha256`) |
| M11 | o arquivo de teste é removido | contrato (`arquivo`) |
| M12 | o gate sai do agregador oficial | verificador + `composneg` |

**Três armadilhas de medição que custaram uma rodada cada**, registradas no
cabeçalho da suíte: `pumpAndSettle` não devolve nesta tela (reprova por timeout de
dez minutos, não por defeito); `SemanticsHandle` tem de ser solto DENTRO do corpo,
porque o binding confere handles antes dos `tearDown`; e uma prova de ausência que
lê o arquivo casa com o **comentário** que explica a ausência — foi assim que
"a tela não escreve `Renova em 24/08`" reprovou por causa da linha que documenta
que ela não escreve.

## 11. Gate de CI

| peça | o que entrou |
| --- | --- |
| `scripts/ci/gates_os_integracao.txt` | gate `temavip` com contrato completo: `suite`, `executor`, `sha256`, `provas 38`, e onze `exige` |
| `.github/workflows/ci-os-integracao.yml` | um passo: `roda temavip test/casca/tema_real_vip_ajustes_test.dart` |
| `scripts/ci/teste_contrato_suites.sh` | o fixture passou a produzir `t_temavip.log`; assinatura atualizada no mesmo commit |

Sem `casos`: o piso executado exigiria log, e a matriz do próprio verificador monta
a evidência sem ele — é o mesmo arranjo que `chatdom` usa. A trava de conteúdo
continua inteira por `sha256` + `provas` + `exige`.

**Nenhuma permissão ou gatilho de workflow foi ampliado.** O `on:` do
`ci-os-integracao.yml` não foi tocado; só um passo `run` a mais dentro do job que
já existia.

Portões conferidos localmente sobre o `git archive` do HEAD:

```text
verificar_contrato_suites.sh   7 conferidos, tudo no lugar
teste_portao_os_integracao.sh  38 casos ok, 0 falhas — VERDE
teste_contrato_suites.sh       35 casos ok, 0 falhas — VERDE
composicao/negativas.test.js   21 pass, 0 fail
composicao/loja_functions.js   35 pass, 0 fail
```

## 12. Arquivos alterados

```text
 .github/workflows/ci-os-integracao.yml         |    8 +
 app/lib/casca/configuracoes_de_producao.dart   |  208 ++++-
 app/lib/screens/configuracoes_screen.dart      |  401 ++++++---
 app/lib/sessao/autenticacao_firebase.dart      |   17 +
 app/lib/sessao/comandos_de_autenticacao.dart   |   16 +
 app/lib/tema/conjunto_real_vip.dart            |  146 ++++   (novo)
 app/lib/tema/iconografia_ajustes.dart          |  306 ++++++   (novo)
 app/lib/tema/resolucao_tema_ajustes.dart       |  192 ++++   (novo)
 app/test/casca/bancada_online.dart             |    3 +
 app/test/casca/casca_producao_test.dart        |    3 +
 app/test/casca/homologacao_casca_v2_test.dart  |    3 +
 app/test/casca/tema_real_vip_ajustes_test.dart | 1107 +++++++   (novo)
 app/test/mesa_orientacao_runtime_test.dart     |    8 +-
 docs/ORIGEM-ICONES-TEMA-REAL.md                |   90 ++   (novo)
 scripts/ci/gates_os_integracao.txt             |   38 +-
 scripts/ci/teste_contrato_suites.sh            |    3 +
 16 arquivos, 2428 inserções, 121 remoções
```

Os três `+3` em `app/test/casca/` são o mesmo getter `emailDaConta => null` nos
dublês de autenticação — `ComandosDeAutenticacao` é `implements`, e `implements`
exige redeclarar até o membro concreto.

## 13. Prova de não alteração do Perfil público

`git diff --name-only d1eb537..HEAD -- app/lib/pages app/lib/social app/lib/colecoes app/lib/billing functions-ranking firebase`
devolve **vazio**. Nada do Perfil público, do catálogo, do inventário, do Billing,
do backend do passe ou das Rules foi tocado.

Além disso, `NRG-33..38` afirmam por leitura de árvore que nenhum desses módulos
conhece `IconeAjustes`, `TemaIconografia` ou `ajustes/real`, e que a superfície do
tema é **exatamente** cinco arquivos: os três de `lib/tema/`, a tela e o host.

## 14. Estado da árvore

Limpa. `git status --porcelain` vazio.

## 15. Confirmação local == remoto

Conferido por `git ls-remote`, e não por `refs/remotes/` — o mapa local mente
quando o refspec está truncado, e aqui ele foi conferido (`+refs/heads/*:refs/remotes/origin/*`).

```text
local    79e6ad89243606c2351930132b63c493d5758f65
remoto   79e6ad89243606c2351930132b63c493d5758f65   refs/heads/claude/tema-real-vip-iconografia-ajustes-v1
árvore   limpa (git status --porcelain vazio)
```

Commits posteriores ao SHA do código, e o que cada um tocou:

| SHA | assunto | arquivos |
| --- | --- | --- |
| `f1be5d09ceba81d8b68206274761d33d9d354310` | `docs(tema): o laudo do Tema Real VIP dos Ajustes` | `A docs/LAUDO-TEMA-REAL-VIP-AJUSTES-V1.md` |
| `79e6ad89243606c2351930132b63c493d5758f65` | `docs(tema): o laudo separa o SHA do codigo da ponta da branch` | `M docs/LAUDO-TEMA-REAL-VIP-AJUSTES-V1.md` |

Os dois são **exclusivamente documentais**, e não por leitura da mensagem de
commit: `git diff --name-status dc3a46b..HEAD -- . ':(exclude)docs'` devolve
vazio, e o `diff-tree` recursivo da seção 1 devolve uma linha só.

Push normal, sem `--force`.

## 16. Zero deploy, PR e merge

* nenhum `firebase deploy`, nenhum build de release;
* nenhum PR aberto (o remoto sugeriu a URL; ela não foi usada);
* `origin/main` segue em `fb9edb5c6963964161f1e8834b57f50fe77074a1`.

## 17. Pendências

1. **Os 28 arquivos de arte** (seção 7). É o único bloqueio da ativação.
2. **Nome comercial do plano.** A linha da assinatura mostra o identificador
   técnico do produto (`master_vip_mensal`) porque `playerEntitlements` guarda o
   PRODUTO, não o catálogo — o nome "Mensal" vem do período que a consulta da Play
   devolve, e essa consulta acontece na Loja, não aqui. Inventar o nome a partir
   do produto seria afirmar um período que ninguém consultou. Ligar o catálogo aos
   Ajustes é OS própria.
3. **Saldo de fichas.** A linha comercial mostra "Pacotes de fichas e histórico"
   e não um saldo, porque não há autoridade de economia alcançável pelo cliente
   nesta linhagem. A pastilha de saldo existe e só aparece quando houver fonte.
4. **A tela de Ajustes desta linhagem não tem o endurecimento semântico da OS 30**
   (`MergeSemantics`, fronteiras declaradas, `enabled` e foco nos 22 controles).
   Aquele trabalho vive na Família A, que não tem a autoridade VIP (seção 2).
   Compor as duas famílias é decisão de arbitragem, não desta OS. O que esta OS
   entregou de acessibilidade está provado por `A11Y-27..32` e não regride:
   alvos ≥ 48 dp, ícone nenhum na árvore semântica, nomes acessíveis idênticos nos
   dois temas, e — corrigidos aqui — três estouros de fileira e dois cortes
   silenciosos em 160% de escala de fonte.
