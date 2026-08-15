# RC V1 — MANIFESTO DE COMPOSIÇÃO

Gerado pela **OS — Proteção das Folhas Locais e Preparação da Release Candidate V1**.
Data de apuração: 2026-08-15.

Todos os hashes deste documento foram confirmados **diretamente no servidor** via
`git ls-remote origin refs/heads/<branch>`. Nenhum valor veio de remote-tracking local.

Esta OS **não integrou nada**: nenhum merge, rebase, cherry-pick, squash, reset,
force-push ou deploy foi executado. `main` e `consolidacao/apk-geral-bmv` não
foram tocadas. `release/rc-v1` não foi criada.

---

## 1. BASE

```text
Base autorizada para a futura RC:
consolidacao/apk-geral-bmv @ 0cea0d6d68f2c93613b985f4aa85800d77cf42d7

main é base autorizada? NÃO
main @ fb9edb5c6963964161f1e8834b57f50fe77074a1
```

Revalidação da divergência (Fase B):

| Medida | Valor |
| --- | --- |
| `merge-base origin/main consolidacao/apk-geral-bmv` | `2ddadde71d220ff11ebe455cfca050bb4bf0ea83` |
| `rev-list --left-right --count origin/main...consolidacao` | `5  90` |

`main` carrega 5 commits exclusivos, e o conteúdo deles é placeholder declarado:
`Add files via upload`, `Update print statement to say 'Goodbye World'`,
`Update main.dart`, `noop`, `chore: remover arquivo noop criado por engano`.
A consolidação carrega 90 commits exclusivos de produto.

**O estado não mudou desde a auditoria anterior.** Ambas as refs estão idênticas
local e remotamente, e nenhuma foi movida por esta OS.

---

## 2. FOLHAS OBRIGATÓRIAS DA RC

13 folhas. Todas verificadas contra o servidor. Todas com commits exclusivos —
nenhuma é ancestral de outra (matriz de ancestralidade cruzada 13×13 vazia).

A coluna **exclusivos** conta commits não alcançáveis por `consolidacao` **nem
pelas outras 12 folhas**. É a medida de perda real caso a folha seja omitida.

| # | Branch | Hash remoto confirmado | Tema | Exclus. | Classificação |
| --: | --- | --- | --- | --: | --- |
| 1 | `claude/runner-sandbox-cleanup-c0461a` | `9fd3a67ab7a6e9ad8a6a7ac17ad2e2735db86f0a` | Runners de emulador / sandbox de CI | 7 | FOLHA |
| 2 | `claude/busca-apelido-descoberta-social-b56465` | `e97bac89450d510d158f895b707ae3b75d5898f4` | Busca por apelido / descoberta social | 3 | FOLHA |
| 3 | `claude/identidade-sessao-canonica-flutter` | `3c6eb8da7da59fd2f6823d770b9eeb67ddf94d69` | Identidade de sessão no cliente | 10 | FOLHA |
| 4 | `feat/economia-boas-vindas-vitorias` | `42928c30aa0cf9d38aa7c74a84ca4897b22d14ab` | Economia básica (fichas/moedas) | 8 | FOLHA |
| 5 | `homologacao/billing-vip-comercial` | `625769d29d4892945caacb943e1dc7ac868a0904` | Homologação Billing VIP (documental) | 4 | FOLHA — ver §6 |
| 6 | `homologacao/p0-final-integrada` | `d8b45c39593770e5f21fa826cd399181fba79acc` | Portão P0 técnico | 1 | FOLHA — **publicada nesta OS** |
| 7 | `integracao/motores-torneios-partidas-v1` | `4cae8aef503583aa7a2db6fe8bb34e103779a048` | Motor C — sessão de partida + torneios | 11 | FOLHA — ver §9 |
| 8 | `claude/kit-pioneiros-2026-1b56ed` | `bce06feea866d0e7ca1bbafaa5a36de7507e7a60` | Kit Pioneiros 2026 | 19 | **FOLHA ÓRFÃ OBRIGATÓRIA** |
| 9 | `claude/ws-auth-identidade-1fc213` | `13582ddfa0f9b8cccc81b20e51705bf666ca8754` | WS auth/identidade (lado app) | 2 | FOLHA |
| 10 | `claude/spectator-view-server-enforcement-c154ee` | `fcd478d7153638d82e99f1cad35e8a2235a285ca` | Visão espectador (doc no app) | 1 | FOLHA |
| 11 | `integracao/ranking-ligas-hall` | `428c4587f9ab771bc785d27a1174b069fc15f20b` | Ranking, ligas e hall | 82 | FOLHA |
| 12 | `claude/buraco-c10-parte-2-5eb70e` | `a600b4e22807cb9da1c5b5e982019d5c6a94cade` | Motor D — autoridade canônica de regras | 66 | FOLHA — **publicada nesta OS** |
| 13 | `feat/play-billing-aab-interno` | `bbba26dedf72695ca14166edaf32e11c250dce35` | Play Billing / AAB teste interno | 5 | **OPCIONAL** — ver §3 |

**13/13 protegidas remotamente.**

### Ordem de composição proposta

A ordem abaixo é **proposta**, não decidida — a decisão pertence à OS seguinte.
Ela deriva de dependência de camada, não de nome de branch: identidade e
economia sustentam ranking e billing; os motores tocam `mesa.dart` e devem
entrar por último, quando o alvo já estiver estável.

1. `claude/identidade-sessao-canonica-flutter` (identidade de sessão)
2. `claude/busca-apelido-descoberta-social-b56465` (descoberta social)
3. `feat/economia-boas-vindas-vitorias` (economia)
4. `integracao/ranking-ligas-hall` (ranking — maior superfície)
5. `claude/kit-pioneiros-2026-1b56ed` (órfã; ver §7)
6. `claude/ws-auth-identidade-1fc213`
7. `claude/spectator-view-server-enforcement-c154ee`
8. `homologacao/billing-vip-comercial`
9. `homologacao/p0-final-integrada`
10. `claude/runner-sandbox-cleanup-c0461a` (CI)
11. `integracao/motores-torneios-partidas-v1` (Motor C)
12. `claude/buraco-c10-parte-2-5eb70e` (Motor D — **depende da decisão do §9**)
13. `feat/play-billing-aab-interno` (opcional)

---

## 3. FOLHAS OPCIONAIS

| Branch | Hash remoto confirmado | Motivo |
| --- | --- | --- |
| `feat/play-billing-aab-interno` | `bbba26dedf72695ca14166edaf32e11c250dce35` | Mantida como **opcional** por decisão anterior; a publicação na Play está bloqueada por pipeline (AAB, `applicationId`, keystore, ícone), não por código. |
| `feat/play-billing-aab-interno-limpa` | `8ef9ba3ea7f8d05fe1bb659d8ce016044e60addc` | **Variante sobre a base errada.** Nasce de `2ddadde` (linhagem placeholder de `main`), não da consolidação. Carrega 6 commits fora das 13 folhas, mas 3 deles são a mesma intenção refeita na base certa em `feat/play-billing-aab-interno`. Já protegida no remoto. Não integrar. |

---

## 4. NÓS INTERMEDIÁRIOS — JÁ CONTIDOS, NÃO MESCLAR

Verificado por `git rev-list --count <branch> --not <13 folhas> consolidacao`.
Todos retornaram **0** — integralmente alcançáveis pelas folhas. Mesclá-los
separadamente só produziria ruído de histórico.

| Branch | Commits fora das folhas |
| --- | --: |
| `claude/moderation-reports-blocking-social-08ef72` | 0 |
| `claude/moderation-ci-gate-9520bc` | 0 |
| `claude/ranking-ligas-backend-auth-ea5ceb` | 0 |
| `claude/politica-competitiva-v1-3e139e` | 0 |
| `integracao/identidade-publica-ranking-v1` | 0 |
| `correcao/p0-elegibilidade-vip-lifecycle` | 0 |
| `integracao/rtdn-vip-producao` | 0 |
| `integracao/play-billing-flutter` | 0 |
| `claude/identidade-publica-grafo-social-78d184` | 0 |
| `claude/claimpioneerkit-homologacao-941659` | 0 |
| `integracao/fluxo-mesas` | 0 |
| `claude/motor-de-torneios-f161b9` | 0 |
| `homologacao/play-billing-comercial` | 0 |
| `claude/emulator-runners-robustness-99cda2` | 0 |
| `claude/motor-partidas-resiliencia-3a775f` | 0 |
| `claude/os-integracao-final-backend-flutter-f7aa07` | 0 |
| `claude/torneios-recompensas-dominio-c55748` | 0 |
| `claude/local-assets-registry-a06883` | 0 |
| `claude/ci-fail-closed-emulador-v1` | 0 |
| `claude/goofy-kowalevski-099256` | 0 |
| `codex/configuracao-mesas-fluxo` | 0 |
| `correcao/consolidacao-bmv-limpa` | 0 |
| `homologacao/p0-integrada-a90557` | 0 |
| `claude/buraco-vip-game-traceability-3eb66c` | 0 |
| `claude/torneios-capas-oficiais-ac3bef` | 0 |
| `claude/torneios-premiacao-assets-3ef5b8` | 0 |
| `auditoria/regras-bmv` | 0 |

### Aliases e ancestrais da linhagem C10

A linhagem do Motor D é **linear** — publicar a folha preservou tudo:

```text
c10-parte2      1dfa572241ff6d9310f53363dc95cbf9304552a8
      └─> c10-parte2-rev1  dd48ee30000b75a58bf257308f56421f646c4fed
              └─> c10-parte2-rev2 == claude/buraco-c10-parte-2-5eb70e
                                  a600b4e22807cb9da1c5b5e982019d5c6a94cade
```

`c10-parte2` é ancestral de `c10-parte2-rev1`, que é ancestral da folha.
`c10-parte2-rev2` aponta para o mesmo commit da folha.
`claude/android-aab-production-build-ea6bbc` aponta para o mesmo commit de
`claude/vip-production-readiness-4194df` (`7a91e1f9`), já publicado.

Nenhum desses aliases foi publicado — seriam redundância sem trabalho único.
Nenhum foi apagado, conforme §18 da OS.

---

## 5. FOLHAS ÓRFÃS

| Branch | Hash remoto confirmado | Situação |
| --- | --- | --- |
| `claude/kit-pioneiros-2026-1b56ed` | `bce06feea866d0e7ca1bbafaa5a36de7507e7a60` | **ÓRFÃ OBRIGATÓRIA.** 19 commits fora de toda outra folha e da consolidação. Exige merge próprio. |

Ver §7 para a apuração.

---

## 6. FASE C4 — AS DUAS BRANCHES DE HOMOLOGAÇÃO DO PLAY BILLING

A auditoria registrou dois nomes. **Não são a mesma branch.**

```text
merge-base = 962846ea8fae257d5823e15de1315b4ce1c0f771
  ("docs(billing): a integracao, o contrato, e o que ficou bloqueado")

rev-list --left-right --count play-billing-comercial...billing-vip-comercial
  = 6   4
```

| Pergunta da OS | Resposta |
| --- | --- |
| 1. São branches distintas? | **SIM.** Divergem no mesmo ponto-base, 6 commits de um lado e 4 do outro. |
| 2. Uma contém a outra? | **NÃO.** Nenhuma é ancestral da outra. |
| 3. Uma é só homologação/documentação posterior? | **SIM** — `homologacao/billing-vip-comercial` (`625769d2`) tem 4 commits, todos `docs(homologacao)` / `homologacao(billing)`. |
| 4. Qual é folha real? | **Ambas carregam trabalho único**, mas o **código** está em `homologacao/play-billing-comercial` (`0ea96c29`): `fix(loja)` selo VIP concedido pelo próprio app, `fix(billing)` `encerrar()` deixava VIP do jogador anterior, `feat(billing)` assinatura entrega fichas uma vez só. |
| 5. Qual precisa ser preservada? | **As duas — e as duas já estão protegidas.** `0ea96c29` e `625769d2` confirmados no servidor. |

> **Achado que a OS de composição precisa resolver.**
> A lista das 13 folhas nomeia `homologacao/billing-vip-comercial`, que é a
> branch **documental**. A correção do vazamento de VIP entre contas no
> `encerrar()` vive em `homologacao/play-billing-comercial`. Pela contagem de
> contenção (§4) essa branch dá 0 commits fora das folhas — ou seja, o código
> **está** alcançável pelo conjunto —, mas a rota pela qual ele entra na RC
> precisa ser explicitada antes da composição, e não presumida pelo nome.

Nenhuma das duas foi renomeada ou excluída.

---

## 7. FASE G — PIONEER KIT

```text
Pioneer Kit domínio está contido em alguma folha da RC? NÃO
```

`claude/kit-pioneiros-2026-1b56ed @ bce06feea866d0e7ca1bbafaa5a36de7507e7a60`
retorna **19 commits** não alcançáveis por `consolidacao/apk-geral-bmv` nem pelas
outras 12 folhas. Não é ancestral de nenhuma folha, e nenhuma folha é ancestral
dela.

Classificação formal: **FOLHA ÓRFÃ OBRIGATÓRIA**. Não integrada nesta OS.

`claude/claimpioneerkit-homologacao-941659` (`8d7fc048`) é a homologação
correspondente e está **contida** (0 commits fora) — é nó intermediário.

---

## 8. SERVIDOR (`buraco-servidor`) — SEPARADO DO APP

Repositório: `https://github.com/soniaambrosio/buraco-servidor.git`
Working tree limpo. Nenhum push foi necessário — tudo já estava protegido.

| Ref | Hash | Local | Remoto | local == remoto |
| --- | --- | --- | --- | --- |
| `main` | `1828d42ef2c95329e81b439b4939353326c2b036` | sim | sim | **SIM** |
| `seguranca/ws-auth-identidade` | `71199e81ff44d41c8fcdb41cd866b38c0cf14fee` | sim | sim | **SIM** |
| `enforcement/visao-espectador` | `3c8b07ef6281ba2c986c1d391c90792a205fa73f` | não (só remoto) | sim | **N/A — protegida no servidor** |

Ambos os hashes batem exatamente com os valores auditados anteriormente.
Outras refs remotas presentes: `correcao/conformidade-canonica` (`09835bdb`),
`transporte-srv2` (`2fdeda53`).

### Conflito previsto — registrado, não resolvido

As duas branches saem do mesmo ponto (`main @ 1828d42`) e divergem 2 × 1 commits.

```text
merge-base = 1828d42ef2c95329e81b439b4939353326c2b036
rev-list --left-right --count ws-auth...espectador = 2  1

INTERSEÇÃO DE ARQUIVOS TOCADOS:
  server.js
  package.json
```

| Branch | Arquivos tocados |
| --- | --- |
| `seguranca/ws-auth-identidade` | `docs/WS-AUTH-IDENTIDADE.md`, `package.json`, `server.js`, `test/ajuda_auth.js`, `test/auth_token.test.js`, `test/regressao_auth.test.js`, `test/ws_auth.test.js` |
| `enforcement/visao-espectador` | `package.json`, `server.js`, `test/ajuda.js`, `test/espectador.test.js`, `test/regressao.test.js`, `test/ws.test.js` |

**Integração realizada: NÃO.** O conflito em `server.js` e `package.json` fica
para a OS de composição. Note que os arquivos de teste também são pares
paralelos (`ajuda.js`/`ajuda_auth.js`, `ws.test.js`/`ws_auth.test.js`,
`regressao.test.js`/`regressao_auth.test.js`) — a duplicação de harness é parte
do trabalho de conciliação, não só o `server.js`.

---

## 9. DECISÃO PENDENTE — AUTORIDADE DO MOTOR C × MOTOR D

Esta OS **não decide** a autoridade. Produz a evidência técnica.

```text
merge-base C/D = 27b3f3679f7ee27584cfddeddbcd61e2e5fcce0d
  ("feat(mesa): curinga baixado com contorno violeta fino + badge mínima")

rev-list --left-right --count C...D = 30   66
arquivos tocados por C vs base: 75
arquivos tocados por D vs base: 107
```

### Interseção de arquivos — apenas 2

```text
.github/workflows/build.yml
app/lib/mesa.dart
```

Os diretórios `app/lib/motor/` das duas linhagens **não compartilham um único
nome de arquivo**. `app/lib/motor/` de C tem `motor_partida.dart`,
`comando_partida.dart`, `desfecho_partida.dart`, `snapshot_partida.dart`,
`visao_assento.dart`, `presenca.dart`, `relogio_turno.dart`,
`sessao_reconexao.dart`, `diagnostico.dart`. O de D tem
`autoridade_canonica.dart`, `adaptador_canonico.dart`, `adaptador_legado.dart`,
`fabrica_motor.dart`, `porta_motor.dart`, `porta`/`composicao.dart`,
`modo_sombra.dart`, `projecao_estado.dart`, `pontuacao_costura.dart`,
`motor_config.dart`, `derivacao_fora_do_frame.dart`, `envelope_runtime.dart`.

### Dossiê

```text
Motor C — integracao/motores-torneios-partidas-v1 @ 4cae8aef503583aa7a2db6fe8bb34e103779a048

responsabilidade:
  CICLO DE VIDA DA SESSÃO DE PARTIDA. Turno, relógio, presença, abandono,
  reconexão, snapshot/retomada, visão por assento, diário de diagnóstico e o
  contrato canônico de encerramento. NÃO decide regra de jogo.

entry point:
  app/lib/motor/motor_partida.dart -> class MotorPartida
  comandos entram por app/lib/motor/comando_partida.dart (ComandoPartida ->
  ResultadoComando/StatusComando)

consumidores:
  app/lib/integracao/adaptador_partida_torneio.dart
  app/lib/integracao/registro_partidas.dart
  app/lib/mesa.dart  (apenas 56 linhas ADITIVAS — ver abaixo)
  app/test/integracao/teste_integracao_motores.dart
  app/test/teste_motor_resiliencia.dart

testes:
  449 casos nos 4 arquivos de teste tocados
    teste_integracao_motores.dart      64
    teste_motor_resiliencia.dart      126
    torneios/motor_torneios_test.dart 179
    torneios/reward_grants_test.dart   80

integrações:
  torneios (adaptador + registro de partidas)
  backend: functions/src/index.ts, domain.ts, idempotency.ts,
           firebase/firestore.rules, firestore.indexes.json, firebase.json
  docs: docs/MOTOR-PARTIDAS-ARQUITETURA.md,
        docs/MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md
  encerramento: class DesfechoCanonicoPartida (app/lib/motor/desfecho_partida.dart)
                — existe SOMENTE nesta linhagem
  pontuação: consome pontosRodada de mesa.dart; não pontua
  rastreabilidade: DiarioPartida / EventoDiagnostico
```

```text
Motor D — claude/buraco-c10-parte-2-5eb70e @ a600b4e22807cb9da1c5b5e982019d5c6a94cade

responsabilidade:
  AUTORIDADE CANÔNICA DE REGRA E PONTUAÇÃO. Quem valida meld, compra do lixo,
  baixada, descarte e quem conta a rodada. NÃO gerencia sessão, presença,
  relógio nem reconexão.

entry point:
  app/lib/motor/porta_motor.dart (PortaMotor) selecionada por
  app/lib/motor/fabrica_motor.dart (selecionarMotor -> TipoMotor.legado|canonico)
  composição concreta em app/lib/motor/composicao.dart
  regra propriamente dita em app/lib/rules/ (meld_validator, pontuacao_canonica,
  rule_spec, acoes, estado, gerador, morto, modalidade, replay)

consumidores:
  app/lib/mesa.dart — INVASIVO: 1285 inserções / 185 remoções.
  Todo caminho de jogada passa por `if (motorConfig.canonicoAtivo)`.

testes:
  365 casos em app/test/teste_motor.dart (+ app/test/conformidade_fixture.dart,
  fixture sem casos próprios)

integrações:
  backend: NENHUM arquivo de functions/ ou firestore.rules.
           Toca apenas harnesses de auditoria em auditoria/conformidade/*.js
           (node_harness, fluxo_harness, servidor_regras_extraidas/corrigido,
            verificacao_bundle_real, verificacao_pos_patch)
  docs/homologação: claude/STATUS-MOTOR-CANONICO.md,
                    claude/RELATORIO-C10-PARTE2-PROMOCAO.md,
                    RELATORIO-C10-PARTE2-REVISAO-1/2, RELATORIO-C9C-SOMBRA,
                    auditoria/conformidade/RELATORIO-C8*, RELATORIO-DART-NODE-C8
  torneios: nenhuma
```

```text
Podem coexistir intencionalmente?: SIM — e a evidência é forte.

  As responsabilidades são disjuntas: C orquestra a SESSÃO, D decide a REGRA.
  Não há colisão de nome de arquivo em app/lib/motor/. Não há colisão de
  backend (C mexe em functions/ e rules; D não toca nenhum dos dois).
  O contrato de encerramento (DesfechoCanonicoPartida) existe só em C;
  D não tem desfecho_partida.dart nem qualquer classe equivalente — o que D
  monta perto do encerramento (DetalhePontuacaoVM, mesa.dart:~4345) é um
  view-model de tela, não um contrato de domínio.

Existe duplicação funcional?: NÃO na responsabilidade. SIM na superfície de edição.

  O único ponto de duplicação é `app/lib/mesa.dart`, e ele é assimétrico:
    - C adiciona 56 linhas, PURAMENTE ADITIVAS: `estadoInternoParaSnapshot()`,
      `aplicarEstadoInternoDeSnapshot()`, `descarteProibidoId`,
      `canastrasLimpasNaRodada()`. C não altera nenhuma regra; ele EXPÕE
      estado que já existia para o codec de snapshot e para a visão do assento.
    - D reescreve os métodos de regra e pontuação de mesa.dart.

  A costura de C SOBREVIVE à reescrita de D — verificado, não presumido:
    - Os cinco escalares privados que o snapshot de C precisa continuam
      existindo em mesa.dart de D:
        _cont (6 ocorrências), _lixoUnicoCompradoId (7), _mortosConvertidos (8),
        _iniciadorRodada (6), _rodadaContada (6)
    - O formato de `pontosRodada[dupla]['detalhe']` que
      `canastrasLimpasNaRodada()` lê é preservado por D
      (mesa.dart:387 e :413 montam {'asAas','de500','limpas','sujas','baixadas'}).
    - app/lib/motor/pontuacao_costura.dart declara explicitamente que devolve
      "o resultado no FORMATO que a UI aprovada já consome".

  Ou seja: D preservou deliberadamente exatamente o contrato do qual C depende.
  O conflito em mesa.dart é textual e localizado, não semântico.

Qual arquivo decide a autoridade em runtime?:
  app/lib/mesa.dart:1953
      MotorConfig get configEfetivaDoMotor => motorConfig ?? MotorConfig.producao();

  Sustentado por:
    app/lib/motor/motor_config.dart  — as duas flags (canonicoAtivo, sombraAtiva),
      ambas OFF no construtor const, mas MotorConfig.producao() liga a autoridade
    app/lib/motor/fabrica_motor.dart — selecionarMotor(config)
    app/lib/motor/composicao.dart    — portaDoAmbiente() usa MotorConfig.doAmbiente(),
      que é OFF por padrão salvo --dart-define=BMV_MOTOR_CANONICO=true

  ATENÇÃO À ASSIMETRIA: o ROOT da partida local nasce em `MotorConfig.producao()`
  (autoridade ON), enquanto `composicao.dart`/`portaDoAmbiente()` nasce OFF.
  São dois portões com padrões opostos no mesmo repositório. O rollback é
  explícito e pré-transação (`MotorConfig.legadoRollback()`), nunca por jogada —
  não existe fallback automático.

Que decisão humana é necessária antes da composição?:

  1. CONFIRMAR A COEXISTÊNCIA. A evidência diz que C e D não competem pela mesma
     responsabilidade. Se a coexistência for aceita, não há "escolha de motor" —
     há UM merge de mesa.dart a costurar. Se for recusada, alguém precisa dizer
     qual responsabilidade some, e isso descarta trabalho aprovado dos dois lados.

  2. DEFINIR QUEM PONTUA NO ENCERRAMENTO. C fecha a partida por
     DesfechoCanonicoPartida lendo `pontosRodada`. D torna o canônico o dono de
     `pontosRodada`. A composição precisa declarar que o desfecho de C passa a
     consumir a pontuação de D — é a costura natural, mas precisa ser dita.

  3. DEFINIR O PADRÃO DA FLAG NA RC. `MotorConfig.producao()` (ON) no root da
     partida local × `portaDoAmbiente()` (OFF) na composição. A RC precisa de um
     único padrão declarado.

  4. DECIDIR A ORDEM. Entrar D antes de C deixa mesa.dart reescrito e força as 56
     linhas de C a reancorar. Entrar C antes de D é mais barato: as 56 linhas de
     C são aditivas e sobrevivem à reescrita de D com contrato verificado.
     Recomendação técnica desta OS: C (ordem 11) antes de D (ordem 12).
```

---

## 10. CONFLITOS PREVISTOS NA COMPOSIÇÃO

Reexecutado contra as refs **atuais**, após as publicações desta OS.

| Par | Interseção de arquivos | Natureza |
| --- | --- | --- |
| Motor C × Motor D | `app/lib/mesa.dart`, `.github/workflows/build.yml` | `mesa.dart`: aditivo (C) × reescrita (D), contrato preservado — costurável. `build.yml`: dois jobs de CI diferentes no mesmo arquivo. |
| `seguranca/ws-auth-identidade` × `enforcement/visao-espectador` (servidor) | `server.js`, `package.json` | Duas evoluções paralelas do mesmo `server.js` a partir de `main`. Harness de teste também duplicado em pares paralelos. |
| `homologacao/play-billing-comercial` × `homologacao/billing-vip-comercial` | divergem de `962846e` | Código × documentação. Ver §6. |

Nenhum conflito foi resolvido nesta OS.

---

## 11. O QUE ESTA OS PUBLICOU

8 branches publicadas por push simples, cada uma confirmada por
`git ls-remote origin refs/heads/<branch>` após o push.

| Branch | Hash confirmado no servidor | Por quê |
| --- | --- | --- |
| `claude/buraco-c10-parte-2-5eb70e` | `a600b4e22807cb9da1c5b5e982019d5c6a94cade` | Folha D da RC. 18 commits sem cópia remota. Prioridade 1 da OS. |
| `homologacao/p0-final-integrada` | `d8b45c39593770e5f21fa826cd399181fba79acc` | Folha da RC. 1 commit sem cópia remota. |
| `claude/player-account-deletion-flow-d04d45` | `b304f591e1dfc8e59a416de896863158e4cfcb02` (ver nota) | 2 commits de trabalho único (exclusão/retenção de conta). Fora das 13 folhas. |
| `claude/vip-production-readiness-4194df` | `7a91e1f9088549d891a749c6624b6d54071bfbb0` | 1 commit único: dry-run do legado + ciclo de vida RTDN. |
| `claude/sleepy-kilby-f8ff3f` | `37494dde53dbd3826f1cce14f84792a193992517` | 1 commit único: localizar seeds sem depender do staging do CI. |
| `claude/google-play-publication-v1-bf8d5d` | `604f36200c8f927a46364c2d094a9a4c06e8500b` | 1 commit único: auditoria do pacote Google Play V1. |
| `backup/os3-antes-limpeza` | `279d7bf82df1742b7cc7348d60f75e1323081ca8` | 1 commit único: atualização de dependências do backend billing. |
| `correcao/vip-client-enforcement-beneficios-v1` | `8e47d4defa9491083eee3c6ee95f058738e3c25b` | **Apareceu durante a OS.** 1 commit único: `fix(vip): o cliente deixa de conceder VIP, e passa apenas a refleti-lo` — fecha o gate de prontidão VIP. Ver nota. |

> **Nota sobre `claude/player-account-deletion-flow-d04d45`.**
> Essa branch **moveu durante esta OS**. No snapshot inicial estava em
> `aad09df99fe5a4ecdd567396efbd98bc2f00bcaf`; no momento do push estava em
> `b304f591e1…` (`test(conta): os dez casos da OS contra o Firestore e o Auth de
> verdade`). Verificado: `aad09df9` **é ancestral** de `b304f591` — nada se
> perdeu, outra sessão adicionou um commit em cima. O worktree dessa branch
> ainda tem trabalho não versionado (`?? app/lib/conta/`), ou seja, **há uma
> sessão ativa escrevendo nela**. O hash dela vai mudar de novo.

> **Nota sobre `correcao/vip-client-enforcement-beneficios-v1`.**
> Essa branch estava em `0ea96c29` (contida, nada a preservar) no snapshot
> inicial e **ganhou um commit durante esta OS**. A varredura final a pegou:
> `8e47d4de fix(vip): o cliente deixa de conceder VIP, e passa apenas a
> refleti-lo`. Foi publicada. O worktree dela também tem trabalho ativo não
> versionado (`M functions-billing/test/apoio/firestore_falso.js`,
> `?? functions-billing/varredura.js`, `?? functions-billing/fichasVarredura.js`,
> `?? app/test/colecoes/data/`, `?? app/test/torneios/data/`) — **outra sessão
> está escrevendo nela agora**. Só o que estava commitado foi preservado.

> **Consequência operacional para a OS de composição.**
> Duas branches se moveram sozinhas durante uma OS de ~1h. Esta fotografia é
> válida para o instante em que foi tirada. Antes de compor a RC, **refazer o
> `git ls-remote` e a varredura de commits não protegidos**, e confirmar que as
> sessões paralelas dessas duas branches encerraram — senão a RC vai nascer
> sem a última entrega delas.

---

## 12. BLOQUEADORES DE PRESERVAÇÃO

```text
NENHUM.
```

Nenhuma branch exigiu force, rebase, reescrita, reset ou merge para ser
preservada. Todos os pushes foram criação de ref nova (`[new branch]`).

Divergência examinada e descartada como risco:

```text
auditoria/regras-bmv
  local  4e35594357880bb5fef413019b5727bb982fbd42
  remoto 14b8d032732866631715504707fb32aad2c82f51
  merge-base = 4e35594357880bb5fef413019b5727bb982fbd42  (== o local)
  left/right = 0  11
```

O local é **ancestral direto** do remoto. Não é divergência: é ponteiro local
atrasado em 11 commits. Zero trabalho exclusivo. Nenhuma ação necessária, e um
`git pull` resolveria — não executado porque está fora do escopo desta OS.

`claude/emulator-runners-robustness-99cda2` (Fase C1) **já está reconciliada**:
local e remoto ambos em `91b864dc111754d228476d0f68e05752a624aea7`. O remoto
defasado em `6bb7582…` que a auditoria observou não existe mais. Nenhum push
foi necessário e nenhum force foi cogitado.

`claude/moderation-ci-gate-9520bc` (Fase C7): local == remoto
(`f12708059f75b37fd19059034390e956c2654890`) e 0 commits fora das folhas.
**Decisão registrada: nenhuma ação.** Já está protegida e já está contida —
criar redundância seria estética, não preservação.

---

## 13. ESTADO FINAL

```text
Branches locais no app:                        75
Refs remotas no app no inicio da OS:           73
Refs remotas no app ao final da OS:            83
  criadas por esta OS:                          9
  criadas por sessao paralela:                  1
    (claude/android-api-36-compat-a62a58 — nao fui eu; ja contida)
Branches locais com trabalho único não salvo:   0
Folhas obrigatórias protegidas:             13/13
Repositório do servidor:            já protegido, 0 pushes necessários

main alterada:                                 NÃO
consolidacao/apk-geral-bmv alterada:           NÃO
release/rc-v1 criada:                          NÃO
merge / rebase / cherry-pick / squash:         NÃO
force-push / --force-with-lease / reset:       NÃO
branches excluídas:                            NÃO
deploy / Firebase / Functions / Play:          NÃO
```

---

## 14. PRÓXIMA OS

**OS — COMPOSIÇÃO E HOMOLOGAÇÃO DA RELEASE CANDIDATE V1**, que deverá:

1. resolver a decisão de coexistência C × D do §9 (as 4 perguntas);
2. esclarecer a rota do código de billing do §6 antes de compor;
3. criar `release/rc-v1` a partir de
   `consolidacao/apk-geral-bmv @ 0cea0d6d68f2c93613b985f4aa85800d77cf42d7`;
4. compor as 13 folhas na ordem acordada;
5. conciliar `server.js` no repositório do servidor.
