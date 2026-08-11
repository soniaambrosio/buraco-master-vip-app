# MAPA DE INTEGRAÇÃO — Fluxo de Mesas (OS §23)

> Entregável obrigatório da seção 23, **antes** de qualquer alteração de código.
> Conforme a regra da OS, este mapa **para e reporta** as divergências detectadas
> entre a OS colada, os adendos vinculantes e o código real, e aguarda decisão
> antes de codar.

Data de geração do mapa: 11/08/2026
Autor da sessão: Claude (Cowork), ambiente isolado na nuvem.

---

## A. Base e isolamento

| Item | Valor |
|---|---|
| Repositório | `github.com/soniaambrosio/buraco-master-vip-app` (clonado por HTTPS em ambiente isolado; SSH bloqueado pela rede do sandbox, autenticação via proxy do ambiente) |
| Branch de origem | `codex/configuracao-mesas-fluxo` |
| **HEAD remoto real da origem** | **`a1a1927680ba4cff431650d09519675bdf10aad4`** |
| Último commit da origem | `a1a1927 docs(hand-off): incluir celebracao de vitoria` |
| Branch de integração criada | `integracao/fluxo-mesas` (local, criada **a partir do HEAD acima**; ainda **não** enviada ao remoto) |
| Árvore | limpa; nenhuma alteração feita ainda |
| Base original da linhagem | `consolidacao/apk-geral-bmv` (conforme cabeçalho da OS do repo) |

Branches remotas **proibidas** de usar/mesclar (confirmadas presentes no remoto):
`main`, `consolidacao/apk-geral-bmv`, `integracao/os-final-backend-flutter`,
`integracao/motores-torneios-partidas-v1`, `claude/motor-partidas-resiliencia-3a775f`,
`claude/motor-de-torneios-f161b9`, `codex/mesa-vip-ui`, `correcao/consolidacao-bmv*`,
`transporte-mesa-final`. Nenhuma foi tocada.

---

## B. Ambiente de build (restrição crítica)

**Não existe `pubspec.yaml` versionado no repositório.** Não há scaffold Flutter
(`android/`, `ios/`, `web/`, `analysis_options.yaml`) versionado.

O projeto Flutter é **gerado em CI** pelo workflow canônico `.github/workflows/build.yml`
(“Build APK”):

1. `flutter create --org com.buracomastervip.poc --project-name buraco_master_vip app_build`
2. *Overlay* dos arquivos de UI reais (`app/lib`, `app/test`, `app/assets`) sobre `app_build/`
3. `flutter pub add firebase_core firebase_auth google_sign_in:^6.2.1 audioplayers web_socket_channel shared_preferences`
4. `dependency_overrides: jni: 1.0.0` (o `jni 1.0.1` quebra o `android/build.gradle`)
5. `minSdk 23`, keystore de teste, assinatura, build de APK release por ABI.

`/app_build/` está no `.gitignore` (“é artefato de build, não fonte”).

**Consequência para a OS §24 (`flutter pub get` / `flutter analyze` / testes):** para rodar
análise e testes localmente é preciso **reproduzir esse scaffold** no ambiente
(instalar Flutter SDK, `flutter create`, aplicar o overlay, adicionar as deps acima,
`flutter pub get`). `flutter analyze` e `flutter test` (unit/widget/contract) rodam sem
compilar o APK; o build Android completo (Firebase) exigiria toolchain Android e não é
necessário para análise/testes de unidade. Ver decisão **C** na seção de parada.

---

## C. Telas envolvidas (`app/lib/screens/`, 48 arquivos `.dart` em `lib`, 12 em `test`)

Fluxo de mesas / configuração:
- `onde_jogar_screen.dart` — escolha de ambiente (Pública/VIP/Privada/Treino). **Única** etapa de escolha de tipo.
- `configurar_mesa_screen.dart` — `ConfigurarMesaScreen` (config do ambiente já escolhido; sem seletor de tipo).
- `mesa_privada_social.dart` — social da Privada (cadeiras/convites/chat).
- `preparando_partida_screen.dart` — `PreparandoPartidaScreen` (distribui só para posições presentes: 2 ou 4).
- `mesa.dart::MesaScreen` — **Mesa canônica de runtime** (3375 linhas). Importada pelo `main.dart`.
- `screens/mesa_screen.dart::MesaScreen` — **protótipo em QUARENTENA** (1581 linhas). Não ligar.
- `resultado_partida_screen.dart` — `ResultadoPartidaScreen` (tela de resultado aprovada).
- `mesa_vip_preview_screen.dart`, `hall_screen.dart`, `saguao_screen.dart`, `inicio_screen.dart`, `splash_oficial_screen.dart` — telas de entorno.

Demais: `perfil_`, `ranking_`, `loja_`, `loja_categoria_`, `amigos_`, `recompensas_`,
`configuracoes_`, `como_jogar_`, `torneio_modelo_`, `torneios_screens/models`.

---

## D. Rotas / navegação (`app/lib/main.dart`, 2020 linhas)

Navegação **imperativa** por `MaterialPageRoute` (sem `routes:`/`onGenerateRoute` nomeadas).

Árvore ativa aprovada (Varredura §6): `SplashOficialScreen → _InicioPreviewHost → _OndeJogarPreviewHost`.

Pontos-chave e **estado legado ainda ativo** no `main.dart`:
- `_OndeJogarPreviewHost` (L1003) usa `OndeJogarVM.mock()` e navega para
  `_ConfigMesaPreviewHost(tipoInicial: tipo)` (L1031).
- **`_ConfigMesaPreviewHost` (L1358)** = host **legado com mocks**:
  - `PreparandoPartidaVM.mock(ehVip: _vm.ehVip)` (L1509);
  - padrão perigoso `publica ? MesaVariant.publica : MesaVariant.vip` (**L1501–1502**);
  - texto legado **`SBTL`** no modal de regras (**L1468**) — grafia oficial é **STBL**;
  - abre `MesaScreen()` **sem** transportar modo/chat/aposta/espectadores/código/cadeiras.
- `_OnlineLobbyHost` (L1042) = lobby privado legado (prova de conexão) — **fora** do fluxo aprovado; deve ficar em quarentena.
- Rotas antigas dentro de `HomeScreen` ainda apontam direto ao configurador (L1848, L1896) — legado.

---

## E. Contratos encontrados (camada visual/contratual — já entregue na linhagem)

| Contrato | Arquivo | API pública |
|---|---|---|
| Snapshot das escolhas | `screens/mesa_config_contract.dart` | `class MesaConfigContract` + `factory .fromVm(ConfigMesaVM)` |
| Validação visual | `screens/mesa_config_validator.dart` | `class MesaConfigValidation` |
| Fachada de travessia | `screens/mesa_flow_plan.dart` | `class MesaFlowPlan` + `factory .fromVm(...)`; `podeUsarRuntimeLegado`, `precisaMotorDoisJogadores` |
| Parâmetros p/ runtime | `screens/mesa_launch_spec.dart` | `enum MesaVisualVariant {publica, vip, privada}`, `class MesaLaunchSpec` |
| Contexto × pele | `screens/mesa_renderer_contract.dart` | `enum MesaRendererSkin {publica, premium}`, `enum MesaRuntimeContext {publica, vip, privada}`, `class MesaRendererContract` |
| Host limpo (referência) | `screens/mesa_flow_preview_host.dart` | substituto preparado do `_ConfigMesaPreviewHost` |
| Adapter de preparação | `screens/preparando_partida_config_adapter.dart` | contrato → `PreparandoPartidaVM` |
| Orientação | `screens/mesa_orientation_contract.dart` | `enum MesaOrientacaoPreferida {vertical, horizontal, automatica}`, `enum MesaOrientacaoEfetiva {vertical, horizontal}`, `class MesaOrientationContract` |
| Orientação (widgets) | `screens/mesa_orientation_widgets.dart` | `MesaOrientacaoSelector`, `MesaOrientationGuard` |
| Orientação (serviço) | `services/mesa_orientation_service.dart` | `MesaOrientationService` (SharedPreferences; default `vertical`) |

Testes de contrato presentes (`app/test/`): `mesa_config_contract_test`, `mesa_config_validator_test`,
`mesa_flow_plan_test`, `mesa_flow_preview_host_test`, `mesa_launch_spec_test`,
`configurar_mesa_ui_contract_test`, `preparando_partida_config_adapter_test`,
`preparando_partida_ui_contract_test`, `mesa_orientation_contract_test`,
`vitoria_celebracao_contract_test`, `teste_motor`, `torneios/reward_grants_test`.

---

## F. Estado atual: **preparado ≠ ligado** (o coração da integração)

Verificado por busca no código:

- **Contratos novos (MesaFlowPlan/MesaConfigContract/adapters/launch/renderer):**
  `main.dart` **NÃO os usa** ainda. O fluxo ativo continua no `_ConfigMesaPreviewHost` legado com mocks.
- **Componentes de orientação:** existem, mas **não são usados em nenhum fluxo ativo**.
  Em `mesa.dart` **não há** `_buildMesaVertical`/`_buildMesaHorizontal`, `OrientationBuilder`
  nem uso de `MesaOrientationGuard`. **O layout horizontal real da Mesa não existe** — só o enum/serviço/selector.
  Em `configuracoes_screen.dart` existe a seção `JOGO` (L241), mas **sem** a opção “Orientação da mesa”.
- **Componentes de vitória:** existem, mas **não são referenciados** por `main.dart` nem por
  `resultado_partida_screen.dart`. Estão apenas preparados (referenciam-se entre si).

Ou seja: a linhagem entregou **UI aprovada + contratos + componentes preparados**, e a
integração pedida é **ligá-los** ao fluxo real — porém a “autoridade” (backend/motor) é mock
nesta branch por decisão de projeto (ver divergência **B** abaixo).

---

## G. Orientação da mesa — o que o adendo realmente diz

`docs/OS-CLAUDE-ADENDO-ORIENTACAO-MESA.md` (vinculante) define “Orientação da Mesa” como
**preferência de orientação de TELA do aparelho**:

- opções **Vertical / Horizontal / Automática**; default **Vertical**;
- vale **só** para a Mesa de jogo; ao sair, restaura `portraitUp`;
- **proibido** apenas girar 90° a árvore vertical (`RotatedBox`) — o horizontal deve ser
  **composição responsiva própria**, legível;
- trocar orientação **não** pode reiniciar rodada/motor/`matchId`/timer/conexão/chat/aposta;
- adicionar a opção em **Configurações → JOGO** e também no menu da Mesa; persistir localmente;
- entrega final **exige o layout horizontal real** da Mesa canônica (não basta o enum).

Componentes já preparados citados pelo adendo: `mesa_orientation_contract.dart`,
`mesa_orientation_widgets.dart`, `mesa_orientation_service.dart`, `mesa_orientation_contract_test.dart`.

> ⚠️ **Isto NÃO é “orientação por assento”.** Ver divergência **A**.

---

## H. Componentes de vitória — encontrados

| Esperado pela OS | Caminho real | Status |
|---|---|---|
| `vitoria_celebracao.dart` | `app/lib/screens/vitoria_celebracao.dart` | `CelebracaoVitoriaVM`, `CelebracaoVitoriaLayer` (confete via `CustomPainter`), `_VencedoresBanner` — **preparado, não ligado** |
| `resultado_vitoria_adapter.dart` | `app/lib/screens/resultado_vitoria_adapter.dart` | `celebracaoVitoriaDoResultado(...)` — **preparado, não ligado** |
| `resultado_partida_celebrado.dart` | `app/lib/screens/resultado_partida_celebrado.dart` | `class ResultadoPartidaCelebrado` (wrapper) — **preparado, não ligado** |
| `vitoria_celebracao_contract_test.dart` | `app/test/vitoria_celebracao_contract_test.dart` | presente |
| `assets/sons/vitoria.mp3` | `app/assets/sons/vitoria.mp3` | presente (usar `AssetSource('sons/vitoria.mp3')`) |

Regras vinculantes do adendo de celebração: dispara **só** com resultado autoritativo
(`eventoId` + assentos vencedores + fim confirmado); **idempotente por `eventoId`**;
som só para a dupla vencedora e respeitando `efeitosSonoros`; rebuild/reconexão não repete;
nunca bloqueia a tela de resultado.

---

## I. Dependências externas

Pacotes usados no código / declarados no CI canônico:
`flutter`/`flutter_test`, `firebase_core`, `firebase_auth`, `google_sign_in ^6.2.1`,
`audioplayers`, `shared_preferences`, `web_socket_channel`; override `jni: 1.0.0`.

Serviços/estado: `services/online_service.dart` (WebSocket), `services/configuracoes_service.dart`
e `services/mesa_orientation_service.dart` (SharedPreferences), `services/perfil_service.dart`.

---

## J. Arquivos estranhos / de outras sessões (OS §22 — registrar, **não apagar**)

1. `/(raiz)/main.dart` (41 linhas) — `main.dart` solto na raiz; não é o canônico (`app/lib/main.dart`).
2. `/(raiz)/build.yml` (17 KB) — cópia **mais antiga** do workflow; difere do canônico `.github/workflows/build.yml` (28 KB) e **não** adiciona `shared_preferences`/`web_socket_channel`. Risco se algum processo usar a cópia da raiz.
3. `.github/workflows/main.dart` (141 KB) e `.github/workflows/screens/` — arquivos de código **fora de lugar** dentro de `workflows/`.
4. `app/lib/app/lib/screens/amigos_screen.dart` e `app/lib/app/lib/widgets/convite_vip.dart` — diretório `app/lib/app/lib/…` aninhado indevidamente (duplicatas).
5. `app/lib/mesa-verde-alvo.png` (imagem-alvo) e `app/lib/VARREDURA-BOTOES.md` — material de referência dentro de `lib/`.

Nenhum foi removido. Precisam de decisão explícita antes de qualquer limpeza.

---

## K. Divergências detectadas — **PARADA para decisão** (OS §23/§30)

### Divergência A — “Orientação da mesa”: assento × orientação de tela
- **Problema:** a OS colada trata “orientação” como **posição de assento fixa** (§11 “ORIENTAÇÃO POR ASSENTO”; §2 “não invertida / não rotacionada / não pode mudar”). O adendo **vinculante** define orientação como **preferência de tela Vertical/Horizontal/Automática que o jogador PODE trocar durante a partida**, exigindo um **layout horizontal novo**.
- **Origem:** a OS colada §11 aponta o `ADENDO-ORIENTACAO-MESA.md` como fonte da “orientação por assento”, mas o adendo **não fala de assentos** — fala de rotação de tela.
- **Alternativas:**
  - **A1 (recomendada):** tratar como **dois conceitos compatíveis** — (i) preservar a **composição de assentos** aprovada (local embaixo, parceiro à frente, oponentes nas laterais) como está; (ii) **implementar** a feature V/H/A do adendo com layout horizontal real, sem `RotatedBox`, sem reiniciar estado. Ambos os documentos proíbem o “girar por conveniência técnica”, então se reconciliam.
  - **A2:** congelar orientação (não fazer horizontal) — **viola** os critérios de aceite do adendo vinculante.
  - **A3:** só validar assentos agora e adiar o layout horizontal.
- **Impacto:** A1 implica **refatorar a camada de apresentação da `mesa.dart` (3375 linhas)** em `_buildMesaVertical`/`_buildMesaHorizontal` compartilhando estado — mudança perceptível que, pela OS §25, exige **aprovação de regressão visual**.
- **Recomendação:** **A1**, com o horizontal construído de forma incremental e validado contra a experiência aprovada (golden/contratos) antes de assumir.

### Divergência B — “Integração autoritativa” × proibições (a mais importante)
- **Problema:** a OS pede ligar VIP, Passe Convidado, saldo, aposta, matchmaking, criação/entrada de sala, código, cadeiras, motor 1×1 real e resultado autoritativo (`eventoId`) da celebração. Mas **esta branch é UI/contratos com mocks por decisão de projeto** (os próprios docs dizem: “continua propositalmente mock: servidor, saldo, assinatura, Passe, criação/entrada de sala e autoridade não foram implementados nessa camada”). A **autoridade** vive no **Motor de Partidas / backend / Firebase e nas branches** `integracao/os-final-backend-flutter`, `claude/motor-partidas-resiliencia`, `integracao/motores-torneios-partidas-v1` — que a OS **proíbe tocar ou mesclar**.
- **Origem:** escopo da branch (mock) × ambição da OS (autoritativo) com as fontes de autoridade fora de alcance.
- **Alternativas:**
  - **B1 (recomendada):** executar agora **a parte in-scope (UI/contratos)** — substituir o host legado pelo fluxo baseado em `MesaFlowPlan` levando **todas** as escolhas à `MesaScreen` canônica; `SBTL→STBL`; ligar a celebração **contra o contrato** com um ponto de injeção claro do resultado autoritativo; feature de orientação; idempotência de duplo toque; loading/erro/vazio; auditoria de navegação; testes. Deixar VIP/Passe/saldo/aposta/matchmaking/motor 1×1/resultado real como **pendências explícitas com “costura” limpa** para a sessão de backend.
  - **B2:** puxar as linhagens proibidas para completar a autoridade — **viola** as proibições da OS.
  - **B3:** implementar backend/motor novo nesta branch — **duplica** o motor (proibido) e reabre motores fechados.
- **Impacto:** B1 entrega valor real e mesclável sem violar proibições; o comportamento “final” autoritativo continua condicionado a uma integração de backend separada (que a própria OS destinou a outras linhagens). B2/B3 quebram a OS.
- **Recomendação:** **B1**.

### Divergência C — Testes/analyze exigem reconstruir o scaffold
- **Problema:** OS §24 exige `flutter pub get`/`analyze`/suítes; o repo **não tem `pubspec.yaml`/scaffold** (gerado em CI).
- **Alternativas:** **C1 (recomendada):** reproduzir o scaffold no ambiente (Flutter SDK + `flutter create` + overlay + deps do CI + `pub get`) e rodar `flutter analyze` + `flutter test` das suítes de unidade/widget/contrato. **C2:** confiar no CI (push + GitHub Actions) — mas o CI só monta APK e exige push. **C3:** pular — inaceitável pela OS.
- **Impacto:** C1 instala Flutter SDK (~1 GB) na nuvem; `analyze`/`test` de unidade não precisam do build Android.
- **Recomendação:** **C1**, fixando as **mesmas versões de deps do CI** para o resultado bater.

### Divergências menores (resolvidas / a confirmar)
- **D — Caminhos dos adendos:** a OS cita `docs/ADENDO-ORIENTACAO-MESA.md` e `docs/ADENDO-CELEBRACAO-VITORIA.md`; os arquivos reais são `docs/OS-CLAUDE-ADENDO-…`. Mesmo conteúdo. **Resolvido** (uso os reais).
- **E — Caminhos dos componentes de vitória e do som:** a OS lista sem prefixo; reais em `app/lib/screens/` e `app/assets/sons/vitoria.mp3`. **Resolvido**.
- **F — OS colada × OS do repo:** a OS colada (“INTEGRAÇÃO FINAL”) não existe no repo; o repo tem `OS-CLAUDE-INTEGRACAO-FLUXO-MESAS.md`. São muito alinhadas; trato a **colada como instrução da sessão** e os **docs/adendos do repo como vinculantes** (a própria OS colada assim determina).
- **G — Arquivos estranhos §22:** ver seção J. Aguardando decisão.

---

## L. Escopo executável in-scope (se B1 for aprovado) vs. pendências

**In-scope nesta branch (sem tocar motor/backend/billing, sem merge proibido):**
1. Substituir `_ConfigMesaPreviewHost` legado pelo fluxo `MesaFlowPlan` → `PreparandoPartidaVM` (adapter) → `MesaScreen` canônica, **preservando todas as escolhas** e a pele/contexto (Pública=pública; VIP/Privada=premium; contexto privado vivo).
2. Garantir que a config exibida corresponde ao tipo escolhido em **Onde jogar** (sem seletor duplicado; Pública só pública; etc.).
3. `SBTL → STBL` no modal legado ao ligar o host.
4. Feature de **orientação V/H/A**: Configurações→JOGO + menu da Mesa; `MesaOrientationGuard`; **layout horizontal real** de `mesa.dart` (⚠ requer aprovação de regressão visual — §25).
5. **Celebração**: envolver `ResultadoPartidaScreen` com `ResultadoPartidaCelebrado`/`CelebracaoVitoriaLayer`, disparo **uma vez por `eventoId`**, som respeitando `efeitosSonoros`; ponto de injeção do resultado autoritativo bem definido; teste “celebra exatamente uma vez”.
6. Idempotência de **duplo toque** em botões críticos; estados **loading/erro/vazio**; auditoria de **navegação** (sem duplicar telas/partidas/celebração ao voltar).
7. Testes das suítes afetadas + `flutter analyze`.

**Pendências que dependem de backend/motor (fora do escopo desta OS / outras linhagens):**
- VIP/Passe Convidado/saldo/aposta/pote autoritativos; criação/entrada real de sala; código real; matchmaking; espectadores autoritativos; persistência de bloqueio/denúncia.
- **Motor 1×1 real** (a UI/pote/preparação já suportam 2; o motor nasceu com 4 assentos; `MesaFlowPlan.podeUsarRuntimeLegado` só libera 4).
- Fonte real de `eventoId` + assentos vencedores para a celebração.

---

## M. Confirmação de isolamento (até aqui)

Nenhum arquivo foi alterado. Nenhum merge feito. `main`, `consolidacao`, backend/Firebase,
Billing e motores **não foram tocados**. A branch `integracao/fluxo-mesas` existe apenas
localmente, criada a partir de `a1a1927…`. **Aguardando decisão nas divergências A, B, C
(e G) antes de escrever qualquer código.**
