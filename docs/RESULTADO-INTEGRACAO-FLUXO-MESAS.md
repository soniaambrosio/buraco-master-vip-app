# RESULTADO — Integração do Fluxo de Mesas

Fecha o ciclo aberto por `docs/MAPA-INTEGRACAO-FLUXO-MESAS.md` e
`docs/PLANO-EXECUCAO-INTEGRACAO-FLUXO-MESAS.md`.

- Branch: `integracao/fluxo-mesas`
- Base: `a1a1927680ba4cff431650d09519675bdf10aad4` (`codex/configuracao-mesas-fluxo`)
- Sem merge, sem release, sem deploy. `main`, `consolidacao/apk-geral-bmv`,
  backend/Firebase, Billing e as branches de motor não foram tocados.

---

## 1. Decisões aplicadas

| Divergência | Decisão | O que significou na prática |
|---|---|---|
| **A** — orientação | **A1** | A composição de assentos aprovada foi preservada **e** a preferência V/H/A do adendo foi implementada, com layout horizontal real. |
| **B** — escopo/autoridade | **B1** | A camada UI/contratos foi ligada de ponta a ponta. O que depende de autoridade de backend/motor ficou registrado como integração futura (seção 5). |
| **C** — verificação | **C1** | O scaffold do CI foi reproduzido localmente e `flutter analyze` + `flutter test` rodaram de verdade (seção 3). |
| **G** — arquivos estranhos (§22) | registrado | Nada foi apagado. Ver `MAPA` seção J. |

---

## 2. O que passou a funcionar

**Configuração → runtime.** Onde jogar continua sendo a única porta onde se
escolhe o tipo de mesa e agora navega para `MesaFlowPreviewHost`, que atravessa a
fronteira por `MesaFlowPlan`. A `MesaScreen` canônica ganhou o parâmetro aditivo
`renderer` (`MesaRendererContract`, que carrega o `MesaLaunchSpec`): modalidade,
meta, tempo, chat, aposta/pote, espectadores e código da sala chegam ao runtime, e
a pele sai do contexto — Mesa Privada usa a pele premium **sem virar Mesa VIP**.

**Orientação V/H/A.** Disponível em Configurações → JOGO e no menu da própria
Mesa. O `MesaOrientationGuard` entra abaixo da camada de estado: girar escolhe
entre `_buildMesaVertical` e `_buildMesaHorizontal` e nada mais. O horizontal é
composição nova — as três faixas empilhadas viram três colunas e o rodapé põe a
identidade ao lado da mão — sem `RotatedBox`.

**Quarentena (§17).** `_ConfigMesaPreviewHost` e `_OnlineLobbyHost` continuam no
arquivo, documentados, sem nenhuma rota apontando para eles.

**Defeitos reais corrigidos**, todos encontrados ao cobrir o fluxo com teste:

1. `_rodarBots` seguia jogando depois do dispose da Mesa, mexendo em áudio e em
   `ScrollController` já descartados — sair da mesa não encerrava a partida.
2. A preparação dava `await` num som decorativo; sem plugin de áudio disponível a
   chamada não completa e o jogador ficava preso na tela de preparação.
3. A celebração dava `await` no som antes de animar; sem áudio, o confete inteiro
   sumia — o oposto do adendo §10.5.
4. A folha do menu da Mesa estourava em tela deitada baixa; agora rola.

---

## 3. Verificação real

Scaffold reproduzido conforme `.github/workflows/build.yml` (`flutter create` +
overlay de `app/lib`, `app/test`, `app/assets` + as mesmas deps + `jni: 1.0.0`).

> **Divergência de ambiente:** a máquina tem **Flutter 3.41.4 / Dart 3.11.1**; o CI
> fixa **3.44.8**. Os números abaixo são desta versão. Vale reconfirmar no CI.

| | base `a1a1927` | HEAD desta branch |
|---|---|---|
| `flutter analyze` | 0 erros · 13 warnings · 120 infos (**133**) | 0 erros · 13 warnings · 138 infos (**151**) |
| `flutter test` | **117 verdes · 6 falhas** | **149 verdes · 0 falhas · 0 pulados** |

Os 18 infos novos são todos `avoid_relative_lib_imports`, dos arquivos de teste
novos — a mesma convenção `../lib/...` que os 11 arquivos de teste já existentes
seguem. **Nenhum erro e nenhum warning novo.**

As 6 falhas da base não vinham do código: o `flutter_test` roda em 800×600
lógicos, uma janela de desktop deitada, e as telas do fluxo são desenhadas para
telefone em retrato — o conteúdo caía fora da viewport e, dentro dos scrollables,
os widgets nem chegavam a ser construídos.

---

## 4. Regressão visual (§25)

A mesa vertical aprovada foi medida geometricamente na base e no HEAD, nas mesmas
superfícies. **Todas as regiões conferidas ficaram idênticas** — cabeçalho
(modalidade, rodada, pontuação), bandeja central (monte, mortos) e o rodapé do
jogador, em 390×844 e em 320×640.

> ### ⚠️ Uma mudança perceptível, aguardando aprovação
>
> A coluna de ações da mesa (chat / expressões / som) **subiu 45 px**, porque
> ganhou um quarto botão: o **menu da Mesa**, que o adendo §5 exige para trocar a
> orientação sem sair da partida. A coluna é ancorada pela base, então qualquer
> botão novo desloca os anteriores para cima. Os três botões antigos mantêm
> tamanho, ordem e alinhamento — só a altura mudou.
>
> Se a posição atual não puder mudar, a alternativa é tirar o menu do rail e
> colocá-lo em outro ponto da mesa — o que precisa de decisão de layout.

O horizontal é composição **nova** e não tem referência aprovada para comparar.
A matriz de responsividade do adendo §9 roda como teste, sem filtro de overflow,
de 320×640 a 1280×400: nenhum estouro, e cada tamanho recebe a composição que
cabe. Abaixo de 560 de largura útil a Mesa fica na composição vertical em vez de
espremer as colunas, porque pedir rotação não garante que o aparelho gire.

**Limite conhecido, não alcançável em telefone:** numa janela com menos de 560 de
largura *e* menos de ~358 de altura (só desktop/web redimensionável) a composição
vertical não cabe. Telefone deitado tem 640×360 e recebe a composição deitada.

Para ver as duas orientações lado a lado, com o scaffold já montado:

```bash
cp app/tools/print_mesa.dart app_build/lib/ && cd app_build && flutter run -d chrome -t lib/print_mesa.dart
```

O harness vive em `app/tools/`, fora de `app/lib/` — o CI copia só `app/lib/.`,
então ele nunca é embarcado no APK.

---

## 5. Pendências de backend/motor (integração futura)

Nada disto foi improvisado nesta branch, e nenhuma linhagem proibida foi tocada:

- VIP, Passe Convidado, saldo, aposta e pote **autoritativos**;
- criação/entrada real de sala, código real, matchmaking, espectadores;
- persistência de bloqueio/denúncia;
- **motor 1×1 real** — a UI e a preparação já suportam 2 jogadores, mas o motor
  nasceu com 4 assentos. `MesaFlowPlan.podeUsarRuntimeLegado` só libera 4, e a
  seleção 1×1 para na prévia com aviso explícito (coberto por teste). Por isso a
  orientação com 2 assentos não pôde ser exercitada em runtime;
- fonte real de `eventoId` + assentos vencedores para a celebração. Hoje vem do
  motor local; é o **seam único** — trocar só a origem desses dois valores.
