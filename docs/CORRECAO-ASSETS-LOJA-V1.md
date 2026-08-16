# Correção dos Assets da Loja V1

**OS:** Correção dos Assets da Loja V1 — Buraco Master VIP
**Base:** `005940469aad011adc461b0653cf359fa87acbd7` (branch `claude/android-aab-production-build-ea6bbc`)
**Branch desta OS:** `correcao/assets-loja-v1`
**Data:** 2026-08-15
**Escopo:** corrigir as 46 referências de `assets/loja/`. Sem upload, sem deploy,
sem tocar em mocks.

> Fecha o bloqueio #1 de [RELEASE-ANDROID-PRODUCAO-V1.md §17.1](RELEASE-ANDROID-PRODUCAO-V1.md).
> A configuração Android homologada naquela OS foi preservada integralmente:
> nada em `tools/android/`, `android/launcher-icon/` ou nos workflows mudou,
> exceto um ajuste no scanner de assets explicado na §6.

---

## 1. Resultado, em uma linha

**A arte existe. Sempre existiu.** Os 46 arquivos foram entregues pelo Codex
junto do contrato da tela e **nunca foram commitados**. Não havia nada a
redesenhar, nada a inventar e nenhum caminho errado a consertar.

| Pergunta da OS | Resposta |
|---|---|
| Quantas referências? | **46**, todas em `app/lib/screens/loja_categoria_screen.dart` |
| Quantas o arquivo existia com **outro nome**, exigindo correção de caminho? | **0** |
| Quantas eram **artes realmente inexistentes**? | **0** |
| Quantas foram **acrescentadas** ao repositório? | **46** |
| Placeholders criados? | **nenhum** |
| Gate removido ou afrouxado? | **não** — ver §6 |
| `errorBuilder` usado para esconder ausência? | **não** — nenhum foi tocado |

---

## 2. Inventário das 46 referências

Todas em `loja_categoria_screen.dart`, em dois pontos: o catálogo (linhas
1355–1415) e o seletor de capa de categoria (linhas 67–77, que reusa um item de
cada categoria como capa).

| Categoria | Qtd | Itens |
|---|---|---|
| **dorsos** | 8 | royal · diamante · elite · imperio · prestige · luxo · neon · supremo |
| **molduras** | 10 | realeza · ametista · fenix · neon · gelo_real · ouro_velho · rubi · esmeralda · safira · perola_negra |
| **avatares** | 8 | nobre · diva · magnata · duquesa · barao · condessa · lorde · imperatriz |
| **mascotes** | 6 | coruja_jogadora · gato_malandro · bulldog_de_oculos · macaco_trapaceiro · mini_curinga · dragao_de_cartas |
| **efeitos** | 6 | explosao_vip · chuva_de_ouro · coroa_triunfal · mesa_congelando · cartas_em_chamas · confete_real |
| **emojis** | 8 | malandro · gargalhada · apaixonado · surpreso · pensativo · furioso · triste · piscadinha |
| | **46** | |

---

## 3. Onde a arte estava

### 3.1 O que foi descartado primeiro

Antes de concluir qualquer coisa, três buscas negativas:

| Busca | Resultado |
|---|---|
| `git log --all --diff-filter=A -- "*assets/loja/*"` | **nenhum commit**, em nenhum dos 69 refs remotos nem em branch local |
| Varredura de **todos os objetos de todos os refs** (`git rev-list --all --objects`) por `loja/`, `royal`, `ametista`, `duquesa`, `imperatriz`, `magnata`, `prestige`, `supremo`, `perola`, `fenix`, `gargalhada` | **nenhum objeto** |
| Confronto com os assets já aprovados no repositório | **nenhuma correspondência** — ver §3.2 |

### 3.2 Por que os "quase-candidatos" não servem

| Candidato | Por que **não** é a arte da Loja sob outro nome |
|---|---|
| `perfil/vitrine_{avatar,moldura,mascote,dorso,efeito}.webp` | São ícones de **slot** do Perfil — representam a categoria vazia, não um item comprável. Usá-los como prévia seria exatamente o "placeholder silencioso" que a OS proíbe. |
| `colecoes/pioneiros_2026/*` (inclui um bulldog e um dragão) | O `catalogo.seed.json` os declara `purchasable/transferable/tradable/visibleInStore` **sempre false**: *"recompensa historica, fora da economia da loja"*. E o manifesto oficial da coleção proíbe *"recortar, redesenhar, recolorir ou achatar a transparência"*. |
| `baralho/dorso.webp`, `mesa_vip/dorso_vip.webp` | São dorsos em uso pela mesa. Nada os associa a um dos 8 dorsos vendidos; afirmar a correspondência seria inventar. |

### 3.3 Onde ela estava de fato

Fora do git, nos pacotes de entrega do Codex. **Cinco** pacotes distintos a
carregam:

```
buraco-master-vip-chats-mesa-espectadores-flutter.zip
buraco-master-vip-configuracoes-perfil-flutter.zip
buraco-master-vip-loja-cosmeticos-flutter.zip
buraco-master-vip-mesas-ajustes-consolidados-flutter.zip
loja-cosmeticos-codex-alteracoes.zip
```

Cada um traz `app/assets/loja/` com **46 `.webp` + `manifest.json`**. O conjunto
é **byte-idêntico nos cinco** (hash do conjunto ordenado: `8d06f4caee8306dc151a`),
então não há ambiguidade sobre qual é a versão boa. Usado como fonte:
`loja-cosmeticos-codex-alteracoes.zip`.

O contrato que acompanha a entrega (`CONTRATO-TELA-LOJA-COSMETICOS.md`) confirma
a intenção: *"o Codex monta a interface visual … o Claude liga a economia real
depois"*, e nomeia as prévias por categoria. A tela foi integrada; a arte ficou
para trás.

---

## 4. Conferência antes de aceitar a arte

### 4.1 Casamento exato, três vias

```
referências no código  46
arte no pacote         46
entradas no manifesto  46

manifesto == arquivos em disco ......... IDÊNTICOS
manifesto == referências do código ..... IDÊNTICOS
citadas sem arte ....................... nenhuma
arte sem citação ....................... nenhuma
```

### 4.2 Integridade de cada arquivo

Os 46 foram decodificados um a um: **todos** têm assinatura `RIFF…WEBP`, todos
decodificam, todos são RGBA (4 canais, alfa real). Dimensões por categoria:

| Categoria | Dimensões | Faixa de tamanho |
|---|---|---|
| dorsos | 80×120 | 2,0–2,7 KB |
| molduras | ~132×130 | 10,0–13,4 KB |
| avatares | ~119×120 | 6,3–10,1 KB |
| mascotes | ~110×124 | 6,0–8,2 KB |
| efeitos | ~120×118 | 8,4–15,5 KB |
| emojis | ~98×110 | 5,1–6,1 KB |

Total: **367 KB**. São prévias de card, na escala em que a grade de 2 colunas as
usa.

> O alfa real importa aqui: o pipeline já desliga o Impeller
> (`EnableImpeller=false`, em `preparar_release.dart`) justamente porque o app
> depende de `.webp` com transparência renderizado via Skia. Estas 46 entram
> nessa mesma categoria.

### 4.3 Conferência visual

Folha de contato das 46 artes gerada e inspecionada: avatares ilustrados,
dorsos com a marca "BURACO MASTER VIP", molduras circulares ornamentadas,
mascotes, efeitos e emojis dourados. **Arte final, não rascunho e não
placeholder.**

---

## 5. O que foi alterado

| Mudança | Detalhe |
|---|---|
| **+46 arquivos** em `app/assets/loja/{dorsos,molduras,avatares,mascotes,efeitos,emojis}/` | cópia byte a byte do pacote aprovado |
| **+1** `app/data/loja/loja_cosmeticos.manifest.json` | o manifesto da entrega, guardado ao lado dos outros seeds (`app/data/colecoes/`, `app/data/torneios/`). Fica **fora** do bundle de propósito: é documentação de contrato, não asset de runtime. |
| `app/pubspec.yaml` | seis linhas novas no bloco `assets:`, uma por categoria — o Flutter não inclui subpasta recursivamente |
| `app/lib/main.dart` | removido o bloco morto do splash antigo (§5.1) |
| `tools/android/bin/verificar_assets.dart` | scanner passa a ignorar linha de comentário (§6) |

**Nenhum mock foi tocado.** `LojaCategoriaVM.mock()` está byte a byte igual: os
46 caminhos que ela declara agora simplesmente existem.

### 5.1 A 47ª referência — `assets/splash.jpg`

O portão acusava **sete** divergências, não seis: além das 46 da Loja, havia
`assets/splash.jpg`, citado em `main.dart`.

Investigado separadamente: quem o carregava era a classe `SplashScreen`, com
**zero referências**. Ela, `_SplashScreenState`, `_Particula` e
`_PontinhosPainter` formavam um bloco de 154 linhas que só se citava entre si —
a tela de abertura real do app é `SplashOficialScreen`, declarada no `home:`.

Existe um `splash.jpg` numa pasta antiga fora deste repositório
(`F:/Projetos/buraco_master_vip/assets/`). **Não foi trazido.** Adicioná-lo
engordaria o bundle para alimentar código que nunca roda. O bloco morto foi
removido; o import de `dart:math`, que só ele usava, saiu junto.

---

## 6. O ajuste no portão — e por que não é afrouxamento

Depois de remover o bloco morto, o portão **continuou reprovando**: o comentário
que eu escrevi explicando a remoção contém a string `assets/splash.jpg`, e o
scanner varria o arquivo inteiro, comentário incluído.

A saída errada seria reescrever o comentário para enganar o próprio scanner. A
correção é o scanner ignorar **linha que é só comentário** — comentário não
carrega asset; o caminho ali é prosa, e o build nunca vai buscá-lo.

O corte é por **linha inteira**, e não a partir do primeiro `//` da linha, de
propósito: recortar em qualquer `//` destruiria toda URL dentro de string
(`'https://…'`) e criaria alarme falso pior que o resolvido. Referência de asset
real nunca mora numa linha que começa com comentário.

Efeito medido: de 121 para 120 caminhos varridos — exatamente a linha do
comentário, e nada mais. As três verificações do portão (citado-sem-arquivo,
arquivo-não-empacotado, declarado-sem-arquivo) continuam idênticas, e ele
continua *fail-closed*.

---

## 7. Gates

| gate | resultado | quantidade | observação |
|---|---|---|---|
| `verificar_assets.dart` | **APROVADO** | 120 citados · 212 em disco · 20 pastas | antes: REPROVADO com 7 divergências |
| `flutter analyze` | exit 0 | **104 issues** | 0 erros · 91 info · 13 warning. Baseline da OS anterior: 106 (93 info + 13 warning). **−2**, pela remoção do bloco morto. Nenhum warning novo. |
| `flutter test` (glob padrão) | passou | 602 | — |
| `teste_motor.dart` | passou | 132 | fora do glob |
| `teste_motor_resiliencia.dart` | passou | 196 | fora do glob |
| `teste_encerramento.dart` | passou | 10 | fora do glob |
| `teste_integracao_motores.dart` | passou | 64 | fora do glob |
| `teste_moderacao.dart` | passou | 42 | fora do glob |
| `teste_visao_espectador.dart` | passou | 15 | fora do glob |
| `node --test` (functions-billing) | passou | 123 | — |
| `flutter build appbundle --release` | **passou** | 1 AAB | §8 |
| `bundletool validate` | passou | exit 0 | §8 |
| `verificar_aab.dart` | passou | 7 permissões | §8 |

**Total: 1.061 testes Flutter + 123 Node, todos verdes.**

---

## 8. O AAB com a arte dentro

| Campo | Antes (OS anterior) | Agora |
|---|---|---|
| Assets no bundle | 166 | **212** (+46) |
| `assets/flutter_assets/assets/loja/` | 0 | **46** |
| Entradas no bundle | 946 | 992 |
| Tamanho | 130,52 MB | **130,87 MB** (+367 KB) |
| applicationId / versionCode / versionName | `io.github.soniaambrosio.buracomastervip` / 3 / 1.0.1 | inalterados |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 | inalterados |
| Permissões | 7 | 7, **mesmo conjunto exato** |
| Launcher icon | 5 densidades, 0 px de diferença | inalterado |
| Billing no dex | presente | presente |
| `com.buracomastervip` no manifesto | nenhuma ocorrência | nenhuma ocorrência |
| `bundletool validate` | exit 0 | exit 0 |

| Artefato | Valor |
|---|---|
| Caminho | `app_build/build/app/outputs/bundle/release/app-release.aab` |
| Tamanho | 137.230.539 bytes |
| SHA-256 | `4a631a7b843218f9d2e0ce5d89f0e36935730c20e6718305ae968c49bdce5ce6` |
| Assinado por | chave de **verificação local descartável** — a de upload só existe em Secrets |

---

## 9. O que isto muda no veredito

O bloqueio **#1** de [RELEASE-ANDROID-PRODUCAO-V1.md §17.1](RELEASE-ANDROID-PRODUCAO-V1.md)
está **fechado**: os assets necessários estão no artefato, e o pipeline oficial
não para mais no portão de assets.

**O veredito geral continua `REPROVADO` para o primeiro upload**, por dois
motivos que esta OS não podia tocar:

1. **Mocks** — 13 telas ainda montam `VM.mock()`. Fora do escopo por instrução
   explícita desta OS.
2. **Secrets de assinatura e `google-services.json`** — precisam existir no
   GitHub para o `release-aab.yml` rodar e produzir o AAB assinado pela chave de
   upload.

---

## 10. Risco remanescente

| Risco | Nota |
|---|---|
| A arte veio de pacote fora do git | Mitigado: cinco cópias independentes byte-idênticas, manifesto conferido contra disco e contra código, e cada arquivo decodificado. O `manifest.json` foi versionado junto para que a proveniência não dependa da pasta de Downloads. |
| Outras entregas do Codex podem ter o mesmo problema | O portão de assets é geral, não específico da Loja: hoje ele cobre as 20 pastas declaradas e os 120 caminhos citados. Uma entrega futura que esqueça a arte reprova o build. |
| `assets/splash.jpg` numa pasta antiga fora do repo | Registrado aqui. O código que o usava não existe mais. |

---

*Sem upload na Play, sem deploy, sem merge. Mocks intocados.*
