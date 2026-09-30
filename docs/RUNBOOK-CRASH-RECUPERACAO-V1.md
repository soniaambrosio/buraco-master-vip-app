# Runbook — crash em campo: triagem, identificação e recuperação (V1)

Este documento é para ser aberto **durante** o incidente. Ele responde três
perguntas, nesta ordem: **qual build quebrou**, **onde quebrou** e **como
recuperamos**.

Papéis são funções, não pessoas: *plantão* (quem viu primeiro e conduz),
*responsável pela release* (quem tem acesso ao CI e à Play) e *revisor*
(segunda pessoa antes de qualquer publicação). Uma pessoa pode acumular
funções; nenhuma etapa marcada com **duas pessoas** pode ser feita sozinha.

---

## 0. Regra que vale em todas as etapas

**Nunca copie token, e-mail, UID, `purchaseToken`, mão de cartas, chat ou
payload de WebSocket para ticket, planilha, mensagem ou relatório.** Se
aparecer `[REDIGIDO]` num evento, isso é a redação funcionando — não peça o
valor original, não vá buscá-lo no dispositivo e não o cole em lugar nenhum.

O que você pode e deve copiar, sempre: `versionName`, `versionCode`, SHA,
ambiente, tipo da exceção, mensagem já redigida, stack redigido e a trilha de
marcos operacionais. Isso é suficiente para diagnosticar; se não for, o que
falta é **mais instrumentação sem PII**, não menos redação.

---

## 1. Triagem — severidade e alcance (primeiros 15 minutos)

Classifique com o que já está no painel. Não espere reproduzir.

| Severidade | O que caracteriza | Ação inicial |
|---|---|---|
| **S1** | Crash no arranque, ou perda de partida/compra em curso. Alcance amplo. | Iniciar decisão de rollback (§4) já. |
| **S2** | Fluxo principal quebrado (entrar em mesa, jogar, comprar) mas o app abre. | Hotfix priorizado; rollback se S2 crescer. |
| **S3** | Fluxo secundário, tela isolada, ou erro não fatal recorrente. | Corrigir na próxima release ordinária. |
| **S4** | Ruído: erro não fatal raro, já tratado pelo app. | Backlog. |

**Alcance** — três medidas, nesta ordem:

1. Quantos **dispositivos distintos** (não eventos) atingidos.
2. Se o crash está concentrado num único `build.versionCode` ou espalhado.
3. Se começou junto de uma publicação. Cruze o horário do primeiro evento com
   o `versionCode` da release mais recente.

> Um crash concentrado no `versionCode` mais novo e que começa na publicação é
> regressão até prova em contrário — trate como S1/S2 mesmo com poucos
> dispositivos, porque o alcance ainda vai crescer com a distribuição.

---

## 2. Identificar a build e o commit exatos

Todo evento carrega estas chaves. Elas são gravadas no binário por
`--dart-define` no momento do build, e **não existe caminho de código que as
altere em execução** — o que o evento diz é o que foi compilado.

```
build.versionName    ex.: 1.0.0
build.versionCode    ex.: 130
build.sha            ex.: 0cea0d6d68f2c93613b985f4aa85800d77cf42d7
build.branch         ex.: consolidacao/apk-geral-bmv
build.ambiente       homologacao | producao
```

Do SHA para o código:

```bash
git -C <repo> show --stat <sha>
```

Do SHA para a **build inteira** (artefato e símbolos): abra o manifesto
`MANIFESTO-BUILD.json`, publicado como artefato `bmv-identidade-build` do run
que gerou a release. Ele traz Flutter/Dart usados e o `sha256` do APK e de
cada mapa de símbolos.

Confirmar que o APK em mãos é o mesmo do manifesto:

```bash
sha256sum app-arm64-v8a-release.apk
```

Se o hash **não** bater com o do manifesto, pare: você está investigando um
artefato diferente do que foi publicado, e qualquer conclusão sairá errada.

Reproduzir a identidade de um commit, a qualquer momento:

```bash
git -C <repo> checkout <sha>
dart run app/tool/gate_identidade_build.dart --ambiente=producao --defines
```

O `versionCode` é `git rev-list --count HEAD`: o mesmo commit sempre devolve o
mesmo número, em qualquer máquina, hoje ou daqui a um ano.

---

## 3. Onde quebrou — lendo o evento

Ordem de leitura, do mais barato ao mais caro:

1. **`tipo` + `mensagem`** — nome da exceção e texto já redigido.
2. **`evento.origem`** — por qual porta entrou:
   - `framework` → erro síncrono de build/layout. Olhe a árvore de widgets.
   - `zona` → `Future` sem tratamento. Olhe I/O, WebSocket, Firebase.
   - `plataforma` → canal nativo ou erro fora do isolate do Dart.
   - `manual` → o app detectou e reportou; leia o `contexto`.
3. **`trilha`** — os marcos até a falha, ex.:
   `appIniciado > telaInicio > telaMesa > onlineQueda`.
4. **`stack`** — já redigido, com pacote, arquivo e linha preservados.

O stack no painel deve vir **legível**, com pacote, arquivo e linha:

```
#0  GatilhoHomologacao.armarSePedido.<anonymous closure>
    (package:buraco_master_vip/observability/gatilho_homologacao.dart:81)
```

**Se ele vier VAZIO, o problema é de build, não do defeito.** A causa foi
medida: `--split-debug-info` faz o stack chegar ao Crashlytics sem nenhuma
linha. A build de homologação/produção com Crashlytics não usa a flag
exatamente por isso (ver `docs/CRASHLYTICS-ANDROID-EVIDENCIA-V1.md` §6).
Antes de investigar o defeito, confirme de qual workflow o artefato saiu.

Para artefato antigo compilado com a flag, o stack tem endereços em vez de
nomes e precisa de `flutter symbolize -i <stack> -d app.android-arm64.symbols`,
com o arquivo de símbolo **do mesmo `versionCode`** — símbolo de outra build
produz nomes plausíveis e errados, que é pior do que não ter símbolo nenhum.
`firebase crashlytics:symbols:upload` **não** resolve isso: aquele comando trata
símbolo nativo de NDK (breakpad), não os `.symbols` do Dart.

### Para qual app Firebase este artefato reporta?

O projeto tem quatro aplicativos Android e só um é o oficial. O APK responde
sozinho:

```bash
aapt2 dump resources <apk> | grep -A1 'string/google_app_id'
```

Tem de ser `1:203886484007:android:b1cd95baa0b9e6e629cc02`
(`io.github.soniaambrosio.buracomastervip`). Se for outro, os crashes daquele
artefato estão indo para um painel que ninguém acompanha — e a ausência de
eventos ali não significa ausência de falhas.

---

## 4. Rollback ou hotfix

Decida por estes critérios, não por sensação:

**Rollback** quando qualquer um valer:
- severidade S1;
- a build anterior é sabidamente boa e está a menos de ~48 h de distância;
- a causa ainda não é conhecida depois de 60 minutos de investigação;
- a correção toca regra de jogo, economia, Billing ou protocolo (áreas onde
  um hotfix apressado costuma criar o segundo incidente).

**Hotfix** quando **todas** valerem:
- a causa está identificada e é localizada;
- existe teste que reproduz a falha e passa a falhar sem a correção;
- a mudança não toca as áreas listadas acima;
- há revisor disponível (**duas pessoas**).

**Procedimento de rollback** (**duas pessoas**):
1. Identificar o `versionCode` bom anterior no livro-razão
   `app/data/observabilidade/versioncode_ledger.json`.
2. Na Play Console, interromper o lançamento da versão ruim.
3. **Não** republicar o artefato antigo com o mesmo `versionCode` — a Play
   recusa, e o gate também. Rollback de conteúdo se faz com um `versionCode`
   **novo** apontando para o commit bom.
4. Registrar no livro-razão o `versionCode` novo emitido.

**Procedimento de hotfix** (**duas pessoas**):
1. Branch a partir do commit **publicado** (o do evento), não do topo.
2. Teste que reproduz a falha primeiro; correção depois.
3. `flutter analyze` + suíte completa verdes.
4. Gate de identidade verde (§6).
5. Revisor aprova; então publica.

---

## 5. Preservar evidência

Antes de mexer em qualquer coisa, guarde — **sem PII**:

- `versionName`, `versionCode`, SHA, branch, ambiente;
- `MANIFESTO-BUILD.json` da build afetada;
- o diretório de símbolos correspondente;
- exportação dos eventos do painel (já redigidos na origem);
- horário do primeiro e do último evento, e a contagem de dispositivos.

Guarde num ticket do repositório, referenciando o SHA. **Não** anexe log
bruto de dispositivo, exportação de banco, nem captura de tela que mostre
e-mail, apelido ou saldo de jogador.

Se precisar de um dispositivo específico para investigar, peça ao jogador
para descrever o que fez — não peça acesso à conta, não peça captura da tela
de perfil e não solicite identificadores.

---

## 6. Validar depois de corrigir

```bash
# 1. Suíte e análise estática
flutter analyze
flutter test

# 2. Identidade da build que vai sair (antes de compilar)
dart run app/tool/gate_identidade_build.dart --ambiente=producao --sem-artefatos

# 3. Compilar carimbando a identidade e produzindo símbolos
DEFINES=$(dart run app/tool/gate_identidade_build.dart --ambiente=producao --defines)
flutter build apk --release --split-per-abi --split-debug-info=build/simbolos $DEFINES

# 4. Identidade do artefato (depois de compilar) + manifesto
dart run app/tool/gate_identidade_build.dart --ambiente=producao \
  --artefato=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  --simbolos=build/simbolos \
  --manifesto=MANIFESTO-BUILD.json

# 5. Registrar o versionCode emitido (commit revisado, nunca automático)
dart run app/tool/gate_identidade_build.dart --ambiente=producao --registrar ...
```

Exit code `0` é PASS, `1` é FAIL, `2` é erro de uso ou de ambiente.

Depois de publicar, acompanhe por **24 h**: taxa de crash por
`build.versionCode` novo comparada à anterior, e ausência do `tipo` de
exceção corrigido. Só encerre o incidente quando o `versionCode` novo tiver
volume comparável ao antigo — taxa baixa com pouco tráfego não prova nada.

---

## 7. Quando o crash reporting está indisponível

O coletor pode estar fora do ar, desligado, ou a build pode ter subido sem
identidade válida (nesse caso ela **não** envia nada, por decisão de projeto:
crash sem SHA não responde "qual build quebrou?").

Sinais de que é isso, e não ausência de crash:
- queda abrupta de **todos** os eventos, inclusive não fatais;
- nenhum evento com o `versionCode` recém-publicado, enquanto instalações
  crescem.

O que fazer:

1. **Não** conclua que o app está saudável. Ausência de evento não é evidência
   de ausência de falha.
2. Confirme a identidade da build publicada:
   `dart run app/tool/gate_identidade_build.dart --ambiente=producao --defines`
   no commit publicado, e compare com o `MANIFESTO-BUILD.json` do run.
   Identidade improvável explica o silêncio.
3. Use as fontes independentes do coletor:
   - **Play Console → Android vitals** (ANR e crash nativo, independem do SDK);
   - avaliações e suporte, lidos como sinal agregado — sem copiar dados
     pessoais para o ticket;
   - logs do servidor Node (Railway): queda de conexões WebSocket por
     `versionCode` é um bom sinal indireto de crash em massa no cliente.
4. Trate como **S2 no mínimo** até restabelecer a visibilidade.
5. Restabelecido o coletor, **não** reprocesse nada retroativamente: os
   eventos daquele intervalo não existem e não vão existir. Registre a janela
   cega no ticket.

Falha do próprio coletor **nunca** derruba o app: ela vira o contador
`Observabilidade.instancia.falhasDoColetor` e o marco `coletorIndisponivel` na
trilha. Se esse marco aparecer em eventos que chegaram, o coletor estava
degradado — leve isso em conta ao medir alcance.

---

## 8. Correlação de jogador

**Não existe.** A camada não emite nenhum identificador de jogador, nem
pseudônimo, nem rotativo. A decisão é deliberada: nenhuma pergunta de
diagnóstico deste app precisou até hoje de "qual jogador", e um identificador
que existe acaba sendo usado.

Se algum dia for estritamente necessário, o requisito é: pseudônimo (nunca
derivado de UID), rotativo por sessão, documentado aqui, e removido assim que
a investigação fechar. Até lá, agrupe por `versionCode`, `tipo` de exceção e
trilha — foi o que bastou.

---

## 9. Checklist de encerramento

- [ ] Causa raiz descrita no ticket, com SHA.
- [ ] Correção com teste que falha sem ela.
- [ ] `flutter analyze` e suíte completa verdes.
- [ ] Gate de identidade PASS na build corrigida.
- [ ] `versionCode` novo registrado no livro-razão, em commit revisado.
- [ ] Manifesto e símbolos arquivados junto do artefato.
- [ ] 24 h de acompanhamento concluídas.
- [ ] Nenhum token, e-mail, UID ou payload em qualquer artefato do incidente.
