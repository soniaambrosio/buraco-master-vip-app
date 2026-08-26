# Rehomologação independente OS 39-R1 — Tema Real VIP, iconografia e responsividade dos Ajustes

**Veredito final: `FAIL`.** Iconografia, elegibilidade e fallback passam com
folga e foram medidos por instrumento próprio, sem reaproveitar uma linha da
suíte auditada. A responsividade reprova pela regra que a própria OS escreveu na
§6: o estouro de 22 px em 320 dp a 200% **foi reproduzido**, e a §6 proíbe
reclassificá-lo como PASS por ser dívida herdada. Junto dele vieram dois achados
que a candidata não registra — um alvo de toque de 47 px em todas as 108 células
medidas e, mais grave, **uma metade estruturalmente vazia da guarda `ART-14`**.

Nada foi corrigido. Nada foi composto. A candidata está byte a byte como foi
congelada.

---

## 1. Gate Zero

| verificação | resultado |
| --- | --- |
| branch | `integracao/tema-real-vip-assets-aprovados-v1` |
| HEAD local | `0b6b5770923eb21ff17917510dc0b265d3d27f1c` |
| remote-tracking `origin/...` | `0b6b5770923eb21ff17917510dc0b265d3d27f1c` |
| `git ls-remote` — 1ª leitura | `0b6b5770923eb21ff17917510dc0b265d3d27f1c` |
| `git ls-remote` — 2ª leitura, independente | `0b6b5770923eb21ff17917510dc0b265d3d27f1c` |
| base `claude/tema-real-vip-iconografia-ajustes-v1` | `929113bed40ceb16ca90242320c9254e0954278d` (local = tracking = remoto) |
| `merge-base --is-ancestor 929113b 0b6b577` | **ancestral: SIM** |
| refspec de busca | `+refs/heads/*:refs/remotes/origin/*` — completo |
| árvore de trabalho | limpa |
| `origin/main` | `fb9edb5c…` — não usado, não tocado |

Os cinco commits acima da base, e nenhum posterior:

```
0b6b577  2026-08-22 18:13:58  docs(tema): o laudo da OS 39, e a enumeracao de 27 corrigida
8f7f0b4  2026-08-22 17:48:33  fix(build): os montadores de APK nao empacotavam a arte declarada
a7549fb  2026-08-22 17:31:15  test(tema): o grupo ART abre os WebP, e o gate temavip cresce de 38 para 52
3d1ab2a  2026-08-22 17:31:12  feat(tema): a arte e declarada e o Tema Real e ATIVADO
edd9c10  2026-08-22 17:30:34  feat(tema): os 28 assets aprovados do Tema Real entram na arvore
```

Nenhum SHA recarimbado: as datas de commit são monotônicas e o último SHA que
toca código/assets é `8f7f0b4`, exatamente como a OS declara. Ponta `0b6b577`
mexe só em documentação (`git diff --stat 8f7f0b4 0b6b577` → dois arquivos em
`docs/`).

**Gate Zero: PASS.** Nenhum merge, PR, deploy, publicação ou uso de `main`.

### Bancada

`git worktree add --detach /c/os39r1 0b6b577` — **NTFS**, porque em exFAT uma
suíte pode simplesmente não carregar e o runner segue em frente. Montagem pelo
próprio `tools/ci/montar_app.sh` da candidata, com `app_build/` **dentro** da
raiz do repositório, que é onde o CI o cria — é o que faz `../scripts/…` e
`../.github/…` resolverem para as provas que auditam a árvore.

Único desvio, e ele não toca a candidata: `flutter pub get` aborta nesta máquina
com *"Building with plugins requires symlink support"* (Modo de Desenvolvedor
desligado). Contorno: apagar `app_build/{ios,macos,linux,windows}` depois do
`flutter create`. Android não usa `.plugin_symlinks`, e o APK não muda.

---

## 2. Iconografia — `PASS`

### 2.1 Cabeçalho e proveniência (leitor próprio, em Node, sem a suíte)

`_r1/art_header.js` abre os 28 arquivos byte a byte, decodifica o cabeçalho
RIFF/VP8L na mão e confere contra a **tabela de origem** de
`docs/ORIGEM-ICONES-TEMA-REAL.md` — e não contra a tabela que mora dentro da
suíte auditada.

```
ARQUIVOS_NO_DIRETORIO=28     NAO_WEBP=[]      LINHAS_ORIGEM=28
CONFORMES=28/28              PROBLEMAS=NENHUM
NOMES_NO_CONTRATO_DART=28
DART_MENOS_DISCO=[]   DISCO_MENOS_DART=[]   DART_MENOS_ORIGEM=[]
```

Conferido em cada um dos 28: `RIFF`, `WEBP`, chunk **`VP8L`** (sem perda),
assinatura `0x2F`, versão 0, largura 256, altura 256, bit de alfa ligado,
tamanho declarado no RIFF coerente com o arquivo, **nenhum chunk extra depois do
VP8L**, SHA-256 idêntico ao registro de origem e número de bytes idêntico ao
registro de origem.

### 2.2 Pixels (sonda própria, `dart:ui`, sem a suíte)

`_r1/probe/os39_r1_arte_test.dart` decodifica os 28 e mede.

| medida | limiar | pior caso medido | arquivo |
| --- | --- | --- | --- |
| pixel totalmente transparente | > 0 | 24.473 | `fichas_e_compras` |
| pixel totalmente opaco | > 0 | 121 | `termos_e_privacidade` |
| cantos opacos | 0 | **0 em todos os 28** | — |
| anel de borda de 1 px pintado | < 2 % | **0,69 %** | `notificacoes` |
| branco opaco | < 10 % | **2,00 %** | `editar_perfil` (o vidro do espelho) |
| cobertura de tinta | > 5 % | 16,34 % | `secao_geral` |
| cobertura a 18 px | 15 % – 98 % | **16,36 %** | `secao_geral` |

`R1|FALHAS|NENHUMA`.

> **Falso negativo que eu mesmo produzi, e vale registrar.** A primeira versão
> desta sonda mediu o anel de borda com **8 px** de largura e reprovou quatro
> arquivos (`efeitos_sonoros`, `notificacoes`, `presenca_online`,
> `secao_privacidade`, entre 2,6 % e 3,1 %). Não é fundo assado — é desenho que
> encosta na borda. A medida que distingue as duas coisas é o anel de **1 px**,
> onde um fundo chapado daria 100 % e o pior caso real dá 0,69 %. Sabotagem que
> não pega e limiar que reprova o íntegro custam a mesma coisa: uma volta.

### 2.3 Prova visual

Folha de contato dos 28 sobre **magenta chapado** — qualquer fundo branco, preto
ou xadrez apareceria como retângulo. `capturas_r1/R1-folha-28-em-128px.png` e
`R1-folha-28-em-18px.png`. Confirmam a olho: alfa real nos 28, linguagem visual
única (ouro/roxo), nenhum texto, letra, número, marca d'água ou URL, e silhueta
ainda distinguível a 18 px.

### 2.4 Fonte única da declaração

`- assets/ajustes/real/` aparece **uma vez** em `app/pubspec.yaml`. Varredura da
árvore inteira por nomes de arquivo da arte, fora da bancada:

```
app/lib/tema/conjunto_real_vip.dart          (o contrato)
app/test/casca/tema_real_vip_ajustes_test.dart (a suíte)
docs/ORIGEM-ICONES-TEMA-REAL.md              (o registro de origem)
docs/LAUDO-*.md                              (laudos)
```

Nenhum workflow, script ou manifesto repete a lista dos 28. Os montadores citam
só o **diretório** (`build.yml`, `montar_app.sh`), que é o que a `ART-15` exige.
**Nenhuma lista concorrente foi criada.**

### 2.5 Reserva

`secao_geral.webp` fica a **1,36 ponto percentual** do piso de legibilidade a
18 px (16,36 % contra 15 %). É o único dos 28 com essa margem; os demais estão
acima de 25 %. Não reprova — mas uma segunda versão da arte um pouco mais fina
derruba `ART-08` sem que ninguém tenha mexido no código.

---

## 3. Elegibilidade VIP — `PASS`

Medido na **tela montada**, pelo caminho de produção
(`resolverTemaDeAjustes` + `conjuntoRealDisponivel`), varrendo a árvore inteira
e comparando conjuntos. Sonda própria: `_r1/probe/os39_r1_matriz_test.dart`.

| # | estado do jogador | tema | motivo | assets | glifos variáveis | misturada |
| --- | --- | --- | --- | ---: | ---: | --- |
| 1 | VIP completo ativo | `realVip` | `concedido` | 27 | 0 | não |
| 2 | carência com benefício vigente | `realVip` | `concedido` | 27 | 0 | não |
| 3 | público / sem sessão | `padrao` | `semDireitoVigente` | 0 | 27 | não |
| 4 | passe de cortesia (sem entitlement) | `padrao` | `semDireitoVigente` | 0 | 27 | não |
| 5a | VIP expirado | `padrao` | `semDireitoVigente` | 0 | 27 | não |
| 5b | VIP revogado | `padrao` | `semDireitoVigente` | 0 | 27 | não |
| 5c | VIP reembolsado | `padrao` | `semDireitoVigente` | 0 | 27 | não |
| 6a | estado desconhecido | `padrao` | `autoridadeIndefinida` | 0 | 27 | não |
| 6b | erro de leitura | `padrao` | `autoridadeIndefinida` | 0 | 27 | não |
| 6c | ainda carregando | `padrao` | `autoridadeIndefinida` | 0 | 27 | não |
| 7a | um asset AUSENTE, VIP ativo | `padrao` | `conjuntoIncompleto` | 0 | 27 | não |
| 7b | um asset CORROMPIDO, VIP ativo | `padrao` | `conjuntoIncompleto` | 0 | 27 | não |

`totalIcones = 32` em todas as doze linhas — a tela montou de verdade em cada
uma; varredura de árvore vazia passaria em qualquer asserção de ausência.

**Nenhuma linha é parcialmente luxuosa.** A coluna `MISTURADA` é `false` nas
doze; `assets > 0` e `glifos variáveis > 0` nunca coexistem.

O passe de cortesia é impossível por construção, não por comportamento: nem
`resolucao_tema_ajustes.dart`, nem `conjunto_real_vip.dart`, nem `acesso_vip.dart`,
nem `entitlement_repositorio.dart` leem `playerCourtesyPass`, e
`functions-ranking/src/passe.ts` não escreve em `playerEntitlements`. Não há
porta por onde o passe chegue.

### As seis ações invariantes

| chave | Tema Padrão | Tema Real | igual |
| --- | --- | --- | --- |
| `voltar` | `IconeMaterial` | `IconeMaterial` | sim |
| `avancar` | `IconeMaterial` | `IconeMaterial` | sim |
| `expandir` | `IconeMaterial` | `IconeMaterial` | sim |
| `confirmar` | `IconeMaterial` | `IconeMaterial` | sim |
| `sair` | `IconeMaterial` | `IconeMaterial` | sim |
| `excluirConta` | `IconeMaterial` | `IconeMaterial` | sim |

`IconeAjustes.invariantes` é exatamente esse conjunto de seis, e `divergentes =
nenhuma`. 34 chaves = 28 variáveis + 6 invariantes.

---

## 4. Fallback — `PASS`

O fallback é **por conjunto**, e a decisão acontece antes da montagem da tela:
`conjuntoRealDisponivel` abre os 28 arquivos, um a um, e devolve `false` — nunca
lança — em qualquer falha. As linhas 7a e 7b da matriz acima provam o desfecho
com arquivo ausente e com arquivo de zero byte: tela **inteira** em Tema Padrão,
com motivo `conjuntoIncompleto`.

Não existe o estado "meia tela dourada", e não existe caminho de rede:
`FonteDeIcone` tem duas formas e só duas (`IconeMaterial`, `IconeDeAsset`), e a
proibição de URL vale por construção do tipo.

---

## 5. Responsividade — `FAIL`

Sonda própria, **absoluta** (não comparativa): `_r1/probe/os39_r1_responsividade_test.dart`.
**108 células** — 3 larguras × 3 escalas × 2 temas × 4 perfis, mais 3 estados de
assinatura em 320 dp e uma passada em superfície alta para varrer a árvore
inteira. Orientação vertical em todas.

### 5.1 O residual da §6 — REPRODUZIDO

```
320dp@200% | publico | nome=curto | selo=sim | saldo=sim | maiorEstouro=22.0
320dp@200% | publico | nome=longo | selo=sim | saldo=sim | maiorEstouro=22.0
320dp@200% | vip     | nome=curto | selo=sim | saldo=sim | maiorEstouro=22.0
320dp@200% | vip     | nome=longo | selo=sim | saldo=sim | maiorEstouro=22.0
320dp@200% | publico | assinatura=ativa/expirada/indisponivel | maiorEstouro=22.0
320dp@200% | vip     | assinatura=ativa/expirada/indisponivel | maiorEstouro=22.0
ALTA|320dp@200% | publico e vip                              | maiorEstouro=22.0
```

**12 das 108 células**, todas em 320 dp a 200 %, e todas com a pastilha `VIP`
presente. Some quando `selo=nao`. É `A RenderFlex overflowed by 22 pixels on the
right`, no cabeçalho, entre o apelido flexível (`Flexible`, com elipse) e a
pastilha `VIP` (largura fixa) — exatamente onde o laudo original o descreve.
**Idêntico nos dois temas**: o Tema Real não acrescenta nem tira um pixel.

A §6 é explícita: *"Se ainda existir: RESPONSIVIDADE: FAIL. Não poderá ser
reclassificada como PASS apenas porque já era um defeito herdado."* Ele existe.

### 5.2 Achado novo — a metade de estouro da `ART-14` é estruturalmente vazia

O indicador de estouro do Flutter reporta **uma única vez por RenderObject**
(`_overflowReportNeeded`). A `ART-14` mede o Tema Padrão e **em seguida** o Tema
Real com um segundo `pumpWidget` sobre a **mesma árvore de elementos** — os
mesmos `RenderFlex`. A segunda medição herda o sinalizador já consumido e
devolve conjunto vazio. Logo `estouroReal.difference(estouroPadrao)` é vazio
**por construção**, e a asserção não pode falhar.

Experimento decisivo (`_r1/probe/os39_r1_art14_test.dart`), 320 dp a 200 %:

| caso | Tema Padrão | Tema Real |
| --- | --- | --- |
| **E1** — ordem `padrão → real`, árvore reaproveitada (o que a `ART-14` faz) | `22 pixels` | *(nada)* |
| **E2** — ordem invertida `real → padrão`, árvore reaproveitada | *(nada)* | `22 pixels` |
| **E3** — árvore NOVA para cada tema | `22 pixels` | `22 pixels` |

E2 é a prova de que quem cala o segundo é a **ordem**, não o tema. E3 é a medida
honesta: os dois estouram igual.

**Consequência:** se uma versão futura do Tema Real acrescentasse um estouro que
o Padrão não tem, a `ART-14` continuaria verde. A outra metade da prova — os
cortes silenciosos por `didExceedMaxLines` — não sofre disso, porque lê estado
do `RenderParagraph` e não um relatório de uma vez só. O grupo `ART` inteiro
segue válido; o que está furado é este eixo desta prova.

### 5.3 Demais eixos da §6

| eixo | resultado |
| --- | --- |
| sobreposição apelido × selo VIP × saldo | **nenhuma** nas 108 células |
| alinhamento horizontal dos ícones de linha | **uma única coluna** em todas as células, nos dois temas |
| espaçamento vertical | preservado; nenhuma célula perde linha ou seção |
| alvos tocáveis ≥ 48 dp | **reprova** — ver abaixo |
| texto cortado | **reprova** — ver abaixo |
| botão destrutivo | `Excluir minha conta` conserva o tratamento destrutivo nos dois temas; nenhum ícone luxuoso o veste |

**Alvos abaixo de 48 dp.** Em **todas as 108 células**, nos dois temas, há ao
menos um alvo de **47,0 × 47,0 dp** — 1 dp abaixo do mínimo. Nas seis células de
superfície alta a 100 %, onde a árvore inteira existe, aparece um segundo:
`Excluir minha conta`, com **40,0 dp** de altura. Anterior a esta OS e idêntico
nos dois temas — mas a §6 pede o mínimo de 48 dp, e ele não é cumprido.

**Texto cortado.** 82 das 108 células têm **2** textos cortados em silêncio
(`didExceedMaxLines`), 4 têm 1 e 22 têm nenhum. Diagnóstico nominal: o e-mail
(`ana@ex.com`) em toda escala, e o apelido (`Ana`) a partir de 200 %. Os dois têm
`maxLines: 1` com `TextOverflow.ellipsis` — é corte por desenho, não por
acidente, e é idêntico nos dois temas. A §6 pede "nenhum texto cortado".

### 5.4 Limite declarado desta medição

`flutter test` não carrega fonte de verdade: cada glifo vira um quadrado de
largura fixa. As **geometrias** medidas acima são reais, mas o número **22 px**
nasce das métricas da fonte de teste, não da fonte do aparelho. É a mesma base
sobre a qual o laudo original mediu os mesmos 22 px, então a comparação entre os
dois laudos é legítima; a confirmação em aparelho continua pendente (§6 abaixo).

### 5.5 Matriz de capturas

18 capturas em `capturas_r1/R1-<largura>dp-<escala>pct-<tema>.png`
(320/360/412 dp × 100/150/200 % × público/VIP), com `precacheImage` dentro de
`runAsync` — sem ele os ícones saem em branco e a evidência mente. Mais as duas
folhas de contato dos 28. Pelo motivo da §5.4, elas provam **layout e arte**, não
tipografia.

---

## 6. Empacotamento do APK — bundle `PASS`, demonstração em aparelho `NÃO EXECUTADA`

### 6.1 O APK foi construído

`flutter build apk --debug`, a partir da bancada montada pelo próprio
`tools/ci/montar_app.sh` da candidata, em `C:\os39r1\app_build` (caminho curto,
NTFS), com `JAVA_HOME` na JBR do Android Studio e `org.gradle.jvmargs=-Xmx4G`.

| item | valor |
| --- | --- |
| tarefa | `assembleDebug`, **exit 0**, 331,4 s |
| artefato | `build/app/outputs/flutter-apk/app-debug.apk` |
| tamanho | 249.973.169 bytes |
| SHA-256 do APK | `27bec849847ecafb154d1bd01e9866bab55766ed785eec36a3ebc5bf01272fb7` |
| SHA-1 emitido pelo Flutter | `7b432f811eaabf17c488294e417068b06ddf3d02` |

### 6.2 Os 28 estão dentro, byte a byte

`unzip -l` lista **exatamente 28** entradas em
`assets/flutter_assets/assets/ajustes/real/`, somando 1.415.242 bytes. Extraídos
e conferidos contra o disco:

```
28 OK        (0 DIFERE)
```

Os 28 SHA-256 dentro do APK são idênticos aos 28 do repositório — que já haviam
sido conferidos contra o registro de origem na §2.1. A cadeia fecha:
**pacote aprovado → árvore → bundle**, sem uma recompressão no caminho.

### 6.3 Nenhuma pasta declarada chegou vazia

As 21 pastas declaradas em `pubspec.yaml`, contadas dentro do APK:

```
assets/splash                       2      assets/ajustes/real                 28
assets/sons                         8      assets/mesa_vip                      2
assets/baralho                     56      assets/loja/dorsos                   8
assets/perfil                      23      assets/loja/molduras                10
assets/ranking                     15      assets/loja/avatares                 8
assets/ranking/selos               10      assets/loja/mascotes                 6
assets/hall                         1      assets/loja/efeitos                  6
assets/inicio                      11      assets/loja/emojis                   8
assets/configurar_mesa              8      assets/torneios/capas                5
assets/torneios/premiacao/coroas    7      assets/torneios/premiacao/selos      8
assets/colecoes/pioneiros_2026     10
```

**Zero pastas vazias**, 240 arquivos de asset no bundle — o mesmo número que a
montagem reporta em disco. É a confirmação empírica de que a correção de
`8f7f0b4` funciona: o buraco que a OS 39 fechou era exatamente uma pasta
declarada chegando vazia em silêncio.

### 6.4 Instalação e execução

```
adb install -r -d app-debug.apk        →  Success
pm path com.buracomastervip.poc.buraco_master_vip
   → /data/app/~~FFxgAKbS2n…/base.apk
am start …/.MainActivity               →  mResumedActivity: …/.MainActivity
versionCode=1  versionName=1.0.0  minSdk=24  targetSdk=36
```

AVD `BMV_API_31`. Captura em `capturas_r1/R1-emulador-01.png`: o aplicativo
sobe, renderiza a marca e **para no portão de autenticação** ("Entrar com
Google").

> **Efeito colateral que preciso declarar.** O AVD já tinha o pacote instalado
> numa versão mais alta, e o `install` normal recusou com
> `INSTALL_FAILED_VERSION_DOWNGRADE`. Usei `adb install -r -d` para forçar o
> rebaixamento. **A instalação anterior do AVD `BMV_API_31` foi substituída por
> este APK de bancada** e não tenho o artefato antigo para devolvê-la. Nada foi
> desinstalado, e nenhum dado de usuário foi tocado.

### 6.5 O que NÃO foi demonstrado, e por quê

A §7 pede três demonstrações em aparelho: conta pública → ícones públicos, VIP
vigente → ícones luxuosos, e troca de estado → tema integralmente atualizado.

**As três estão NÃO EXECUTADAS.** A tela de Ajustes fica atrás do login Google,
e o Tema Real exige um documento real em `playerEntitlements/{uid}` — a coleção
que só o Billing escreve. Chegar lá exigiria autenticar com uma conta Google da
proprietária e forjar, ou comprar, um entitlement VIP em produção. Não fiz
nenhuma das duas coisas: a primeira usa credencial que não me cabe usar, e a
segunda escreveria em autoridade de produção numa OS que proíbe deploy.

O que substitui essa evidência, e não a substitui inteiramente: as doze linhas da
§3, medidas na **tela montada** pelo caminho de produção, incluindo `ART-12`
(o VIP vigente recebe o Tema Real sem `registrado:` e sem `verificarConjunto:`
— a mesma chamada que o host faz) e `ART-13` (o público continua no Padrão pelo
mesmo caminho).

**Conforme a §7, não declaro homologação final do APK.**

---

## 7. Testes exigidos pela §8

Nenhum teste da candidata foi alterado para rodar.

| comando | resultado |
| --- | --- |
| `flutter test test/casca/tema_real_vip_ajustes_test.dart` | **53/53**, exit 0 |
| `flutter test test/casca` | **234/234**, exit 0 |
| `flutter test` | **1730/1730**, exit 0 |
| `dart analyze lib test` | **196 issues**, exit **2** — 0 erros, 12 warnings, 184 infos |
| `bash scripts/ci/verificar_contrato_suites.sh . .github/workflows/ci-os-integracao.yml` | 7 contratos conferidos, exit 0 |
| `bash scripts/ci/teste_portao_os_integracao.sh` | **38/38**, exit 0, `TESTE DO PORTÃO: VERDE` |
| `bash scripts/ci/teste_contrato_suites.sh` | **35/35**, exit 0, `TESTE DO CONTRATO: VERDE` |
| `node --test ferramentas/composicao/negativas.test.js` (gate `composneg`) | **21/21**, exit 0 |

`temavip` no contrato: assinatura `b5f2a076…` conferida, `provas 53 >= 53`,
**17 blocos `exige`** conferidos.

**Sobre o `exit 2` do analyzer.** `dart analyze` reprova em `info`; o CI da
candidata usa `flutter analyze --no-fatal-infos --no-fatal-warnings`, que é outro
critério. **Zero das 196 ocorrências foi introduzida por esta OS**: apenas uma
cai em arquivo que a OS 39 tocou — `unnecessary_string_interpolations` em
`tema_real_vip_ajustes_test.dart:554` — e ela **já existia na base**, no mesmo
`ELG-06`, em `929113b:…:322`. Os grandes blocos são
`avoid_relative_lib_imports` (69), `unnecessary_underscores` (61) e
`deprecated_member_use` (28), todos fora do alcance desta entrega.

**Limite conhecido de `flutter test`.** O runner só descobre `*_test.dart`; os
seis alvos com prefixo `teste_` ficam fora do glob. Isso não afeta nenhum eixo
desta OS — nenhum deles toca tema, ícone ou Ajustes — mas o número 1730 é o da
descoberta por glob, não o da árvore Dart inteira.

---

## 8. As 15 sabotagens

Arnês próprio (`_r1/campanha.sh`): para cada vetor, cópia byte a byte do alvo,
mutação, **conferência de que a mutação pegou**, execução do acusador, e
restauração conferida por `cmp`. Sabotagem que não pega vira `ABORTADO`, nunca
"verde". Zero resíduo `.r1bak` ao final.

| # | sabotagem | acusador | veredito |
| --- | --- | --- | --- |
| C00 | CONTROLE de entrada — árvore íntegra | `temavip` | **VERDE** |
| S01 | remover um WebP (`musica.webp`) | `ART-01` | **PEGOU** |
| S02 | renomear um WebP (`idioma.webp`) | `ART-01` | **PEGOU** |
| S03 | acrescentar um 29º arquivo | `ART-01` | **PEGOU** |
| S04 | corromper um WebP (`suporte.webp` truncado) | `ART-02`/`ART-04` | **PEGOU** |
| S05 | trocar um hash na tabela aprovada | `ART-02` | **PEGOU** |
| S06 | remover o diretório do `pubspec` | `ART-09` | **PEGOU** |
| S07 | virar `kConjuntoRealVipRegistrado` para `false` | `ART-10` | **PEGOU** |
| S08 | resolução passa a ler `playerCourtesyPass` | `ELG-05` | **PEGOU** |
| S09 | `concedeTemaReal` passa a aceitar `publico` | `ELG-01/04/07` | **PEGOU** |
| S10 | um asset cai para o glifo Padrão | `AST-10`/`AST-14` | **PEGOU** |
| S11 | uma das seis invariantes vira luxuosa | `AST-10`/`A11Y-32` | **PEGOU** |
| S12 | remover o registro do gate `temavip` da fonte única | **`composneg` (PN-12)** | **PEGOU** |
| S13 | remover o executor do gate `temavip` | verificador | **PEGOU** |
| S14 | substituir a suíte por teste trivial | contrato (`sha256`) | **PEGOU** |
| S15 | reduzir `provas 53` para `provas 10` na fonte única | — | **ESCAPOU** |
| S16 | *(vetor meu)* suíte trivial + `sha256` recarimbado + `provas 1` | 17 blocos `exige` | **PEGOU** |
| C99 | CONTROLE de saída — árvore restaurada | `temavip` | **VERDE** |

**Placar: 15 de 16 pegas, 2 controles verdes, 1 escape contido.**

### S12 — o acusador do laudo original está incompleto

O laudo da OS 39 credita "verificador + `composneg`". O **verificador sozinho
sai exit 0**: ele percorre o que está na fonte, e o que sumiu da fonte ele não
procura. Quem pega é o `composneg`, no caso `PN-12` — *"todo resultado produzido
é percorrido"*: o workflow continua escrevendo `exit_temavip` e o gate deixou de
existir na fonte, que é o defeito CI-02 na forma original. **Pega, mas por um
acusador só**, e não pelos dois.

### S15 — escape real, e o tamanho exato dele

Baixar `provas 53` para `provas 10` na fonte única deixa **verificador exit 0,
`composneg` exit 0 e a suíte `temavip` exit 0**. A causa é nominal: a tabela
`PISOS_PROVAS` de `verificar_contrato_suites.sh` traz
`comunicacao, chatdom, portaoci, contratosui, comunicacaoemu, composloja` —
**e não traz `temavip`**. Sem piso no código, o número declarado na fonte pode
cair sem que ninguém reclame. O laudo original credita a S15 a "contrato (piso no
código)"; esse piso **não existe** para este gate.

**O escape é contido, e o vetor S16 mede o tamanho.** Levei a sabotagem à
conclusão: suíte substituída por `expect(1, 1)`, `sha256` **recalculado** e
recarimbado na fonte, `provas` baixado para `1`. Assinatura ok, `provas 1 >= 1`
ok — e o verificador reprovou assim mesmo, com **17 linhas nomeadas**:

```
CONTRATO DE SUITE: o bloco group('ELG sumiu ...
CONTRATO DE SUITE: o bloco group('ART sumiu ...
CONTRATO DE SUITE: o bloco ('ART-02 cada arquivo confere com o SHA-256 aprovado sumiu ...
CONTRATO DE SUITE: o bloco kConjuntoRealVipRegistrado, isTrue sumiu ...
CONTRATO DE SUITE: o bloco ('ART-15 toda pasta declarada é REALMENTE empacotada sumiu ...
                                                              (17 no total)
```

Ou seja: para `temavip`, **o `provas` é decorativo e quem segura a linha são os
17 blocos `exige`**. A entrega não fica exposta a esvaziamento da suíte; o que
está exposto é o número, e a afirmação do laudo original sobre ele.

---

## 9. Achados que a candidata não registra

1. **`ART-14` — metade vazia.** §5.2. O eixo de estouro não pode reprovar.
2. **`PISOS_PROVAS` sem `temavip`.** §8/S15. O `provas` da fonte única pode ser
   rebaixado em silêncio.
3. **Acusador do S12 mal atribuído.** §8/S12. É `composneg`, não o verificador.
4. **Alvo de toque de 47,0 dp em 100 % das células.** §5.3. Um dp abaixo do
   mínimo da §6, nos dois temas, herdado.
5. **`secao_geral.webp` a 1,36 pp do piso de 18 px.** §2.5.

---

## 10. Armadilhas de medição desta rehomologação

Registradas porque cada uma quase produziu um veredito errado.

* **Estouro reportado uma vez por RenderObject.** Reaproveitar a árvore entre
  células apaga o estouro da segunda medição em diante. Minha primeira matriz
  achou o estouro só na primeira célula e concluiu que o Tema Real o eliminava.
  A árvore nova por célula desfez o engano — e o mesmo mecanismo é o defeito da
  `ART-14`.
* **Anel de borda de 8 px reprova arte legítima.** §2.2.
* **`AssetBundle` falso quebra `AssetImage`.** Ele busca `AssetManifest.bin`
  antes do arquivo; a captura sai com os ícones em branco. Em `flutter test`,
  `rootBundle` **serve** os assets declarados — é ele que deve servir a captura.
* **`build/unit_test_assets` é cache e não se invalida.** Quando a sabotagem S06
  tirou a pasta do `pubspec`, o staging foi regravado **sem** a arte e ficou
  assim. Toda sonda posterior que usasse `rootBundle` mediu um bundle sem os 28 —
  e a matriz da §3 saiu inteira em `conjuntoIncompleto`, o que se lê como defeito
  gravíssimo da entrega. Apagar o diretório e repetir devolveu as doze linhas
  corretas. A suíte da candidata é imune porque lê do disco.
* **`FakeAsync` engole `PortaoVip` e `rootBundle`.** `Future.delayed(Duration.zero)`
  e `load()` não devolvem sob relógio falso: o caso morre em dez minutos, marcado
  `did not complete`, sem uma linha de diagnóstico. Tudo que depende de relógio ou
  I/O real vai para dentro de `runAsync`, onde `pump` é proibido — a montagem fica
  fora.
* **O timeout da ferramenta não mata a árvore de processos.** Confirmado duas
  vezes aqui. Antes de disparar o próximo `flutter test`, esperar `Get-Process`
  ficar vazio — e nunca matar por nome, porque esta máquina roda outras sessões.

---

## 11. Veredito por eixo

```
ICONOGRAFIA:        PASS
ELEGIBILIDADE VIP:  PASS
FALLBACK:           PASS
RESPONSIVIDADE:     FAIL
EMPACOTAMENTO APK:  BUNDLE PASS / DEMONSTRACAO EM APARELHO NAO EXECUTADA
GATES:              PASS com ressalva
VEREDITO FINAL:     FAIL
```

**RESPONSIVIDADE: FAIL** — pela §6, sem reclassificação: o estouro de 22 px em
320 dp a 200 % foi reproduzido em 12 das 108 células. Somam-se o alvo de 47,0 dp
em todas elas, o de 40,0 dp em `Excluir minha conta`, os dois textos cortados em
82 células, e a `ART-14` incapaz de reprovar por estouro.

**GATES: PASS com ressalva** — os oito gates saem verdes e o `temavip` está
inteiro na fonte única com assinatura, contagem e 17 blocos. As ressalvas são
`dart analyze` saindo 2 por `info` herdado (zero introduzido por esta OS) e o
escape contido da S15.

**VEREDITO FINAL: FAIL.** Um PASS de iconografia não esconde o FAIL de
responsividade — que é o que a §9 desta OS manda separar. A arte está correta,
provada byte a byte e pixel a pixel; a autoridade está correta; o fallback está
correto. O que reprova é o eixo que a OS mandou não perdoar, e ele reprova
igual nos dois temas.

---

## 12. Nada foi corrigido

Nenhum arquivo da candidata foi modificado. `git status --porcelain
--untracked-files=all` na bancada não lista um único arquivo rastreado
modificado; as entradas não rastreadas são todas de `_r1/` (sondas, arnês e
logs desta rehomologação). Não houve merge, composição, PR, deploy, publicação
de APK, tag ou Release. `origin/main` segue em `fb9edb5`.
