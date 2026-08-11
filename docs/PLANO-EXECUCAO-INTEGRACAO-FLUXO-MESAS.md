# PLANO DE EXECUÇÃO — Integração do Fluxo de Mesas

> Complementa `docs/MAPA-INTEGRACAO-FLUXO-MESAS.md`.
> Cada item traz **arquivo:linha**, o que muda e o risco. Ordena do mais seguro
> ao que exige **aprovação de regressão visual (OS §25)** ou **decisão de escopo**.
>
> **Restrição de verificação:** o egress de Flutter/Dart/Google (incl. `pub.dev`)
> está bloqueado neste ambiente de nuvem; **não é possível rodar `flutter analyze`
> nem os testes aqui**. Todo item abaixo deve ser validado por `flutter analyze` +
> `flutter test` num ambiente com Flutter **3.44.8** (máquina da Sônia ou um passo
> de CI). Ver seção “Verificação”.

Estado: `integracao/fluxo-mesas` (base `a1a1927…`). Já commitado: MAPA (docs) e
`fix(mesas): SBTL→STBL` (main.dart:1468, texto visível do modal legado).

---

## 1. Concluído (seguro, verificável por inspeção)

- **STBL:** `main.dart:1468` — texto visível `SBTL → STBL`. Não altera regra
  (motor aceita as duas grafias — `test/teste_motor.dart` NOME-01). Comentários do
  motor e o protótipo em quarentena **não** foram tocados. ✔ commit `210a1eb`.
- Observação (não alterado, aguardando decisão): `screens/como_jogar_screen.dart:525`
  ainda exibe `'SBTL'` como nome de modalidade. Fora do host de configuração citado
  pelos docs; por §20 (não alterar textos aprovados sem necessidade) **não** mexi.
  Confirmar se quer unificar para STBL também.

---

## 2. Celebração de vitória — ligação (additivo, baixo risco visual)

**Onde:** `mesa.dart:3333 _overlayFimRodada()` (constrói `ResultadoPartidaScreen`).
`CelebracaoVitoriaLayer` é `Stack` passthrough + `IgnorePointer` e já é **idempotente
por `eventoId`** (`_eventoExecutado == vm.eventoId`), com áudio à prova de falha.

**Mudança proposta (envolver o resultado):**
```dart
// no topo de mesa.dart:
import 'screens/resultado_vitoria_adapter.dart';
import 'screens/resultado_partida_celebrado.dart';

// substituir o `return ResultadoPartidaScreen(...)` por:
final resultado = ResultadoPartidaScreen(/* … campos atuais inalterados … */);
final celebracao = celebracaoVitoriaDoResultado(
  eventoId: _eventoResultado,               // ver abaixo — estável por partida
  fimPartida: finalPartida,                 // NÃO celebra fim de rodada
  assentosVencedores: _assentosVencedores(), // do motor local (fonte de runtime)
  jogadores: _jogadoresResultado(),
  somHabilitado: _efeitosSonorosLigados,    // respeitar preferência global
);
return ResultadoPartidaCelebrado(resultado: resultado, celebracao: celebracao);
```

**Detalhes a implementar:**
- `_eventoResultado`: token **estável por partida encerrada** (idempotência real).
  Definir um campo `String? _eventoResultadoId;` setado **uma única vez** quando
  `_j.encerrada` passa a `true` (ex.: `'fim-<matchToken>'`; se não houver matchToken,
  gerar um no início da partida). Não recompute por rebuild.
- `_assentosVencedores()`: derivar da dupla vencedora do motor local
  (`_j.placar['nos'] >= _j.placar['eles']` → assentos “nós” {0,2}; senão {1,3}) —
  **confirmar** o mapeamento assento→dupla no `_jogadoresResultado()`.
- `_efeitosSonorosLigados`: ler a preferência global (há `ConfiguracoesService` +
  `_soundEnabled` local). Adendo §4: `efeitosSonoros == false` silencia som mas
  mantém o visual.
- **Decisão B embutida:** hoje o motor local é a autoridade do runtime. Deixar este
  ponto como **único seam**: quando o servidor/motor autoritativo chegar, trocar só a
  origem de `eventoId` + `assentosVencedores`. Documentar no código.

**Testes a adicionar** (`test/`): fim de partida dispara 1×; fim de rodada não dispara;
rebuild não repete (mesmo `eventoId`); perdedor não toca som; `efeitosSonoros=false`
silencia; empate/sem vencedor não dispara. (O contrato já tem
`vitoria_celebracao_contract_test.dart`.)

**Risco:** additivo; não redesenha `ResultadoPartidaScreen`. Toca `mesa.dart`, mas em
método de UI, autorizado pelo `ADENDO-CELEBRACAO-VITORIA.md` §8. **Não verificável aqui.**

---

## 3. Fluxo de configuração → runtime (médio risco; decisão B)

**Problema atual:** `main.dart` usa `_ConfigMesaPreviewHost` (L1358) com
`PreparandoPartidaVM.mock` (L1509) e `publica ? MesaVariant.publica : MesaVariant.vip`
(L1501–1502); a `MesaScreen` canônica (`mesa.dart:1272`) só aceita
`variant/modalidade/metaPontos/tempoSegundos/vulnerabilidade` — **perde** modo, chat,
aposta, espectadores, código, cadeiras e o **contexto privado**.

**Plano:**
1. Portar a cadeia de `screens/mesa_flow_preview_host.dart` (host limpo já pronto)
   para substituir `_ConfigMesaPreviewHost`, **sem redesenhar** as telas.
2. Ao “CRIAR MESA”: `MesaFlowPlan.fromVm(configMesaVm)`; se `!plan.valido`, não seguir.
3. Preparação via `preparando_partida_config_adapter` (fim dos mocks); 2/4 destinos reais.
4. **Estender `MesaScreen`** com parâmetros opcionais que carreguem
   `MesaLaunchSpec`/`MesaRendererContract` (contexto + pele) — **aditivo** (defaults
   atuais preservam o comportamento). Consumo de chat/aposta/espectadores/código/
   cadeiras no runtime é **pendência de backend (B)**; por ora, transportar e exibir o
   que já é visual, mantendo o contexto vivo (Privada ≠ VIP).
5. Garantir que a config exibida corresponde ao tipo vindo de **Onde jogar** (Pública
   só pública, etc.) — já é assim nas telas; a ligação não pode reintroduzir seletor.
6. Quarentenar `_OnlineLobbyHost` e as rotas legadas L1848/L1896 que abrem o
   configurador fora de “Onde jogar” (sem faxina destrutiva — §17).

**Testes:** `configurar_mesa_ui_contract_test`, `mesa_flow_plan_test`,
`mesa_flow_preview_host_test`, `mesa_launch_spec_test`, preparação 2/4. **Não
verificável aqui.**

**Risco:** cirurgia em `main.dart` + API pública da `MesaScreen`. Precisa de
`flutter analyze`/testes para não regredir. **Recomendo aplicar/validar onde o Flutter roda.**

---

## 4. Orientação Vertical/Horizontal/Automática (decisão A + **§25**)

Componentes prontos: `MesaOrientacaoSelector`, `MesaOrientationGuard`
(`OrientationBuilder` + `SystemChrome`, restaura `portraitUp` no dispose),
`MesaOrientationService` (SharedPreferences, default vertical).

**Parte de baixo risco (aditiva):**
- **Configurações → JOGO** (`configuracoes_screen.dart:241`): inserir
  `MesaOrientacaoSelector` ligado ao `MesaOrientationService` (persistência local).
- Espelhar a mesma opção no **menu da Mesa**.

**Parte de alto risco (§25 — exige aprovação e é a entrega real do adendo):**
- Em `mesa.dart` (`MesaScreen`), envolver a árvore com `MesaOrientationGuard` **abaixo
  da camada de estado** (não recriar `_j`/motor/timer/conexão ao girar) e ramificar
  `_buildMesaVertical(...)` (composição aprovada atual) vs **novo** `_buildMesaHorizontal(...)`.
- `_buildMesaHorizontal` é **composição responsiva nova** (proibido `RotatedBox` 90°),
  preservando legibilidade das cartas, mão, monte/lixo/mortos, avatares/timer,
  placar/meta/rodada, chat e controles — usando a largura extra de forma útil.
- **Composição de assentos** (local embaixo, parceiro à frente, oponentes nas laterais)
  preservada nas duas orientações (concilia OS colada §11 e o adendo).

> **A implementar só após decisão A + sign-off visual.** Refatorar a apresentação de
> uma tela de 3375 linhas sem `analyze`/golden é alto risco; recomendo fazer incremental
> com validação visual (golden/prints) antes de assumir.

**Testes:** `mesa_orientation_contract_test` (existe) + widget da opção em Configurações
+ troca de orientação sem reconstrução do estado autoritativo.

---

## 5. Idempotência de UI, estados e navegação (additivo)

- **Duplo toque:** desabilitar enquanto em curso os botões críticos — criar mesa,
  entrar, confirmar config, iniciar, sair, voltar após resultado (guardas `bool _emCurso`).
- **Loading/erro/vazio:** cada operação assíncrona relevante com estado explícito +
  retry (criar/entrar; mesa cheia/indisponível; partida encerrada; conexão perdida).
- **Navegação:** auditar `push/pop/pushReplacement`; não duplicar telas/partidas;
  não recelebrar ao voltar (idempotência do `eventoId` cobre a celebração); não abrir
  duas mesas por toque duplo.

**Risco:** additivo, mas espalhado por `main.dart`/telas. Verificar por análise/testes.

---

## 6. Verificação (obrigatória — OS §24/§28)

Como este ambiente não roda Flutter, escolher um caminho:

- **(rec.) Passo de CI de qualidade:** adicionar workflow que roda
  `flutter analyze` + `flutter test` (suíte completa, não só os 2 alvos atuais) no push
  da branch, com Flutter **3.44.8** e as mesmas deps
  (`firebase_core firebase_auth google_sign_in:^6.2.1 audioplayers web_socket_channel
  shared_preferences` + override `jni:1.0.0`). Gera os números de baseline e “novos”.
- **Máquina da Sônia:** aplicar os commits e rodar `flutter pub get && flutter analyze
  && flutter test` localmente (mesma versão).

Registrar: baseline vs novos (analyze) e quantidade exata de testes (verdes/falhas/pulados).

---

## 7. Pendências que dependem de backend/motor (fora desta OS)

VIP/Passe/saldo/aposta/pote autoritativos; criação/entrada real de sala; código real;
matchmaking; espectadores autoritativos; bloqueio/denúncia persistentes; **motor 1×1
real**; fonte real de `eventoId`+assentos vencedores. Todos com “costura” limpa deixada
pelos itens 2–3. Não podem ser concluídos sem tocar linhagens proibidas (§26/§13).

---

## 8. Decisões que ainda bloqueiam os itens 3–4

- **A — Orientação:** confirmar A1 (preservar assentos **e** construir V/H/A com layout
  horizontal real). Isso libera o item 4 (com §25).
- **B — Escopo/autoridade:** confirmar B1 (ligar UI/contratos + celebração agora;
  backend/motor como pendências). Isso libera itens 2–3 na parte visual/contratual.
- **Verificação:** escolher o caminho da seção 6.
