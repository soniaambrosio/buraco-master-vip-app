# Inspeção ampliada segura de cosméticos — Loja e Perfil V1

## Gate Zero — a base, e por que não é `main`

A OS manda resolver remotamente a linhagem mais recente com Loja e Perfil
produtivos, e declarar BLOCKED se houver duas incomparáveis nessas superfícies.
Havia duas candidatas. Elas não empatam.

| | Casca V2 (`089cb5e` → `861d4d5`) | Billing/VIP (`8ce6fa0`) |
|---|---|---|
| `loja_categoria_screen.dart` | `a7c052a3` | `a7c052a3` — **idêntico** |
| `loja_screen.dart` | `816b2859` | `7ee92268` (+25 linhas: `copiarCom`) |
| `perfil_screen.dart` | `9b4aac49` (o mais recente do repo) | `e073f47f` |
| `app/lib/casca/` | 20 arquivos | **não existe** |
| Loja/Perfil alcançáveis por | `casca/home_de_producao.dart` | `main.dart` |

O desempate não é a data: é o que "produtivo" quer dizer. Em `8ce6fa0` a Loja e
o Perfil só são alcançáveis pela bancada de prévias do `main.dart`, porque a
Casca de produção **não existe** nessa linhagem. A única linhagem com as duas
telas penduradas numa casca de produção é a da Casca V2.

E na superfície que esta OS toca não há contenção nenhuma: a grade de
cosméticos (`loja_categoria_screen.dart`) é **byte a byte a mesma** nas duas. A
única diferença de Loja entre elas é o commit `6f39697`, que acrescenta
`LojaVM.copiarCom` para o selo VIP e os planos da Play — escopo de Billing, que
esta OS exclui, e que o próprio commit declara não tocar em cosméticos.

**Base adotada:** `861d4d5` (`origin/claude/configuracao-mesa-apostas-canonicas-v1`),
a cabeça mais recente dessa linhagem. Ela contém `089cb5e`
(`integracao/avatar-ranking-estatisticas-navegacao-publica-v1`, a composição
homologada de avatar + ranking + estatísticas + navegação) e acrescenta um único
arquivo de `docs/`.

**Branch:** `claude/inspecao-ampliada-cosmeticos-loja-perfil-v1`.

## O que foi feito

Um módulo só, `app/lib/cosmeticos/inspecao_ampliada.dart`, consumido pelas duas
telas. Ele expõe três coisas: `ItemInspecionavel` (o item reduzido ao que a
inspeção precisa), `AlvoDeInspecao` (a região tocável) e `InspecaoAmpliada` (o
cartão centralizado).

Pontos de toque ligados:

| Onde | O que amplia |
|---|---|
| Loja › grade de categoria | versos, molduras, avatares, mascotes, efeitos, emojis |
| Perfil › vitrine equipada | as peças em uso, uma por slot |
| Perfil › baú de presentes | cada presente recebido |
| Perfil › selo do herói | o mascote equipado |

### As três garantias, e onde cada uma mora

**Não compra e não equipa — por forma, não por cuidado.** O módulo não declara
callback nenhum: não há `VoidCallback`, `ValueChanged` nem campo de `Function`
em lugar algum dele. Um widget sem saída não tem como acionar compra. Para
transformar inspeção em compra seria preciso *acrescentar* um parâmetro, e o
caso M2 reprova exatamente isso. Pelo mesmo motivo o único `import` é o do
Material (caso M1): um arquivo que não conhece serviço não chama backend.

**O toque não atravessa para Comprar/Equipar — por layout.** Na Loja o
`AlvoDeInspecao` envolve **somente a arte**, que é irmã da linha de ações no
`Column` do card, nunca ancestral dela. Dois nós irmãos não disputam o mesmo
toque. Envolver o card inteiro devolveria a ambiguidade à arena de gestos, e é
por isso que o caso S2 mede a **árvore de widgets** com `find.descendant` em vez
de medir comportamento.

**Fecha pelos três caminhos.** Toque fora (`barrierDismissible`), X
(`IconButton` com `semanticLabel`) e voltar do sistema (a rota de diálogo, sem
`PopScope` nenhum). Cada um tem caso próprio, e F3 usa `handlePopRoute`, que
entra pelo mesmo canal de plataforma do botão físico do Android — é o único
jeito de flagrar uma rota presa.

### Proporção e acessibilidade

A arte usa `BoxFit.contain` sem exceção; `cover` recortaria a moldura pelas
bordas e `fill` esticaria o dorso até virar outro desenho. Prévias por glifo
(o mascote do Perfil é `'🦊'`) passam por `FittedBox` com o mesmo contrato. Os
casos E4/E5 leem o `fit` dos widgets montados, e M4 varre o módulo atrás de
qualquer ajuste deformante.

A imagem ampliada anuncia-se como `"<nome>, <categoria>, ampliado"`; o alvo
anuncia-se como botão `"Ampliar <nome>"`; o fechamento tem rótulo `"Fechar"` —
`semanticLabel` **e** `tooltip`, porque o tooltip vira a propriedade `tooltip`
do nó, que um leitor de tela pode ou não anunciar, e o que dá NOME ao botão é o
rótulo.

## Cobertura: 39 casos, 9 mutantes mortos

`app/test/cosmeticos/inspecao_ampliada_test.dart` — 39 casos, contra os 15
mínimos da OS. As oito categorias que a OS enumera têm caso próprio (C1–C8),
pelo mesmo widget compartilhado.

Três categorias — mesa/feltro, balão e efeito de entrada — **não têm catálogo
nesta base**: a Loja vende dorsos, molduras, avatares, mascotes, efeitos de
vitória e emojis. Os valores existem no enum e são exercitados pelo widget, de
modo que a vitrine de feltros, quando nascer, não inaugura comportamento — só
passa a categoria.

Toda mutação que a OS manda matar foi **injetada de verdade** num overlay do CI
e a suíte reprovou em todas:

| Mutação injetada | Morta por |
|---|---|
| o alvo passa a conter o botão de ação | S2, S3, F4, S6, S7, S8 |
| a barreira deixa de fechar por toque fora | F1 |
| um `PopScope` prende a rota | F1, F3 |
| o X para de fechar | F2, F4, V1, V2 |
| o fechamento perde o rótulo acessível | A2 |
| a arte passa a ser recortada (`BoxFit.cover`) | E4, M4 |
| o toque na arte aciona a ação principal (vira compra) | S1, S4, S5, V1, V2 |
| a inspeção lembra do item anterior | C2–C8, S4, S5, V1, V3 |
| a semântica da arte perde o nome do item | A1 |

Três sensores estruturais foram provados à parte, com mutantes que compilam: um
`VoidCallback` novo mata M2, um `import` de Firestore mata M1, `BoxFit.cover`
mata M4.

## Uma auditoria corrigida por precisão — sem afrouxar

`H-E09` (`homologacao_avatar_publico_test.dart`) reprovou o módulo novo por
`return 'Avatar'`. O extrator de argumentos nomeados marcava `\bavatar\s*:`, e
com isso lia `case CategoriaInspecao.avatar:` como se fosse um produtor
escrevendo avatar. Não é: um rótulo de `case` escolhe um ramo.

A marca passou a exigir que o nome **não venha depois de um ponto** — em Dart,
`X.avatar:` não pode ser argumento nomeado. A chave de mapa em texto
(`'avatar': '…'`) continua na mira de propósito, porque essa **é** uma forma
legítima de escrever o campo.

Que a regra não afrouxou está provado por quatro defeitos reinjetados em
`perfil_service.dart`, todos ainda mortos por H-E09: literal solto, literal
escondido em ternário, `??` com fallback e — a forma que um conserto
desatento teria soltado — chave de mapa em texto.

Do meu lado, o mapa de slots foi indexado **pela família** e não pelo nome do
slot, para não escrever `'avatar':` em código de produção. Ele mora no módulo, e
não no Perfil: a Loja e o Perfil chamam os mesmos cosméticos por nomes
diferentes, e uma segunda tabela seria uma segunda chance de as duas telas
discordarem sobre o que é um dorso.

O fecho alcançável da raiz foi de 48 para 49 arquivos, e o arquivo novo está
**nomeado** em `avatar_publico_canonico_test.dart`, na disciplina que o próprio
caso exige: o total é alarme de crescimento inesperado, e crescimento previsto
se declara.

## Portões de CI

| Workflow | Gate | Alvo |
|---|---|---|
| `build.yml` | PORTÃO DE VITRINE | `test/cosmeticos` (diretório) |
| `ci-os-integracao.yml` | `cosmet` | `test/cosmeticos/inspecao_ampliada_test.dart` |

O de `build.yml` gateia o diretório de propósito: quando nascer a inspeção de
feltros ou de balões, a suíte nova entra no portão sem ninguém precisar lembrar
de acrescentar uma linha. Nenhum gate existente foi removido nem afrouxado.

## Evidência local

Overlay do CI reproduzido em `C:\bmvcos` (scaffold `flutter create` +
`pubspec.yaml`/`pubspec.lock` do repositório + `app/lib` + assets sem `.dart` +
`app/test` + seeds), Flutter 3.41.4.

```
flutter analyze  →  103 issues (base 861d4d5: 103 — delta ZERO)
flutter test     →  1192 casos, All tests passed
                    (1153 da base + 39 novos)
```

O delta do analyze foi conferido por conjunto, sem linha e sem coluna: editar
acima desloca diagnósticos e inventa um "novo" e um "perdido" que não existem.
Conjuntos idênticos, nenhum apontamento novo, nenhum perdido.

## O que esta OS NÃO fez, e por quê

**A Loja continua inalcançável a partir da raiz.** `lib/screens/loja_screen.dart`
e `lib/screens/loja_categoria_screen.dart` **não estão** no fecho de imports de
`lib/main.dart` nesta linhagem: a Casca de produção não pendura a Loja em lugar
nenhum. A inspeção está implementada nas telas e coberta por suíte; ela passa a
existir para o jogador no dia em que a Loja for pendurada na casca — que é outra
OS, e não esta.

**`assets/loja/` não existe nesta base.** As 46 artes da Loja vivem noutra
branch. A suíte usa arte de `assets/perfil/` de propósito, para que um defeito de
empacotamento não se disfarce de defeito de inspeção.

**A folha de confirmação de compra desenha a prévia sem `errorBuilder`** — é o
único ponto da Loja que não tem, e com a arte ausente ele estoura. É anterior a
esta OS e fica **registrado, não corrigido**: mexer nele é mexer no caminho de
compra, que esta OS exclui. O caso S3 filtra esse erro **pelo nome**, e qualquer
outra exceção continua reprovando.

**Zero Functions, Rules, servidor, Billing e economia.** Nenhum arquivo fora de
`app/lib/`, `app/test/` e `.github/workflows/` foi tocado.


# V2 — a barra subiu: responsividade medida, e as dez mutações provadas aqui

A V1 acima entregou o módulo, os pontos de toque e 39 casos. A reemissão da OS
pede mais duas coisas que a V1 não cobria, e é isso que esta seção acrescenta:

* **§7 responsividade** — quatro superfícies e três formas de item, sem overflow.
  A V1 rodava tudo em 390×844 e em nenhum momento olhava a forma da arte.
* **§9 dez mutações** — a V1 provou nove. Faltavam nomeadas: *asset ausente gera
  crash*, *dois overlays simultâneos*, *Perfil usa item do visitante errado*, e
  *Back navega para fora em vez de fechar*.

Nada do módulo mudou. `app/lib/cosmeticos/inspecao_ampliada.dart`,
`loja_categoria_screen.dart` e `perfil_screen.dart` são byte a byte os de
`1800981` — a V2 é medição, não conserto. Que o comportamento já estivesse certo
não é o mesmo que estar provado, e era a prova que faltava.

## Os 17 casos novos

`app/test/cosmeticos/inspecao_ampliada_test.dart` foi de 39 para **56 casos**.

### R1–R12 — quatro telas × três formas

| | item vertical | item horizontal | item quadrado |
|---|---|---|---|
| **360×800** | R1 | R2 | R3 |
| **390×844** | R4 | R5 | R6 |
| **412×915** | R7 | R8 | R9 |
| **tablet 800×1280** | R10 | R11 | R12 |

O cruzamento não é zelo. A inspeção falha de dois jeitos diferentes, e cada um
mora num canto da matriz: o texto estoura na tela mais **baixa**, onde sobra
menos altura para o cabeçalho, o nome e o selo; e a arte se deforma na mais
**larga**, onde sobra folga e a tentação de esticar. Medir só o telefone do meio
não pega nem um nem outro — e era exatamente o telefone do meio que a V1 media.

Cada caso mede três coisas:

1. **Nada estourou.** Um `RenderFlex overflowed` é reportado na pintura e vira
   exceção em teste.
2. **O cartão cabe.** Overflow não é o único jeito de não caber: um cartão alto
   demais sai pela borda **sem reclamar**, porque o `Dialog` o centraliza e
   deixa transbordar. O caso compara o retângulo do conteúdo com o da tela.
3. **A arte não foi deformada nem cortada.** Aqui está o ponto que faz esses
   doze casos valerem alguma coisa: o caso **não olha o nome do `BoxFit`**. Ele
   pega o `fit` que o módulo realmente usou, aplica-o à imagem real na caixa
   real com `applyBoxFit`, e mede o retângulo que sairia pintado. `fill` e
   `fitWidth` mudam a proporção do destino; `cover` faz o destino ultrapassar a
   caixa, que é o corte. Os dois modos de falhar morrem em números.

**As três artes são reais, e escolhidas por medição.** `assets/baralho/dorso.webp`
(907×1210) é o cosmético mais vertical do repositório, `assets/perfil/presente_diamante.webp`
(170×115) o mais horizontal, e `assets/torneios/premiacao/selos/seal_runner_up.png`
(1024×1024) é exatamente quadrado. Uma imagem sintética provaria que o `contain`
funciona sobre uma imagem sintética.

**Por que os casos leem o asset do DISCO, e não do bundle.** No `build.yml` o
passo que **declara** os assets no `pubspec` roda depois dos portões de teste
(as artes já estão copiadas em `app_build/assets/`, mas o `rootBundle` ainda não
as conhece). Um `Image.asset` ali cai no `errorBuilder`, e um caso que medisse a
forma estaria medindo o ícone de falha — verde, e sem sentido. O
`_BundleDeDisco` da suíte lê o mesmo arquivo que vai para o APK, no CI e na
máquina, e o caso reprova alto se a arte sumir ou trocar de proporção.

Uma armadilha custou tempo e fica registrada: o `AssetImage` **não pede a arte
primeiro** — pede o `AssetManifest.bin`, para escolher a variante de densidade.
Um pacote que só saiba servir arquivos derruba a resolução inteira antes de
chegar na arte. O bundle da suíte responde a `AssetManifest*` com um manifesto
vazio, que é a resposta honesta: "esta arte não tem variante".

O portão de `build.yml` ganhou uma pré-condição pelas três artes: se uma sumir
da cópia de assets, o portão para **com o nome do arquivo**, em vez de a suíte
degradar em silêncio.

### X1–X5 — as armadilhas que faltavam

| Caso | O que ele impede |
|---|---|
| X1 | arte ausente derrubar a tela — o desenho de reserva aparece, o cartão continua de pé e ainda fecha |
| X2 | arte buscada por URL, nas três superfícies (módulo + as duas telas) |
| X3 | dois toques empilharem dois overlays — o segundo toque é dado **um quadro** depois do primeiro, com a inspeção ainda entrando |
| X4 | o Perfil visitado ampliar item que não é o tocado, e o zoom publicar algo que o perfil alheio não tinha |
| X5 | o voltar do sistema levar a pessoa para **fora** da vitrine em vez de só fechar a inspeção |

Dois detalhes de projeto valem registro:

**X3 mede a janela, e não o repouso.** O V2 da V1 já batia três vezes seguidas,
mas sempre esperando o `pumpAndSettle` — mede o estado calmo, quando a barreira
modal já está lá. A janela onde um segundo toque escaparia é o quadro em que a
inspeção está **entrando**, e é nele que X3 bate.

**X4 toca o SEGUNDO item da vitrine.** Uma inspeção que sempre abrisse o item de
índice zero passaria despercebida no primeiro card — que é justamente o que uma
pessoa toca primeiro quando confere à mão.

Sobre "Perfil usa item do visitante errado": nesta arquitetura o Perfil tem uma
**fonte só** — o `PerfilVM` que a página recebe. Não existe cache do dono do
aparelho para o item vazar de lá, então a forma matável dessa mutação é a troca
de identidade **dentro** da vitrine visitada, que é o que X4 mata. Onde a OS
manda não inventar publicação nova para permitir zoom, o caso confere o
contrário pelo que **não** apareceu: fechada a inspeção, o comando `trocar ›`
continua fora do perfil alheio.

## As dez mutações, injetadas nesta sessão

Cada uma foi escrita no código de produção, a suíte inteira rodou, e o código
foi restaurado. Nenhuma sobreviveu.

| # | Mutação injetada | Reprovaram |
|---|---|---|
| 1 | `BoxFit.contain` → `BoxFit.fill` na arte | E4, M4, **R1–R12** |
| 2 | `BoxFit.contain` → `BoxFit.cover` na arte | E4, M4, **R1–R12** |
| 3 | `errorBuilder` removido do `Image.asset` | **X1**, X3, X5, A1–A2, E1–E4, E6, F1–F4 |
| 4 | `showDialog` → `OverlayEntry` (sobreposição sem rota) | **X3**, **X5**, F1–F4, M5, S6, V1–V3, X1 |
| 5 | a vitrine do Perfil inspeciona sempre `vitrine[0]` | **X4**, V3 |
| 6 | desenho de reserva vira `Image.network(...)` | **X2**, **X1**, M3, X3, X5, A1–A2, E1–E4, E6, F1–F4 |
| 7 | `barrierDismissible: true` → `false` | F1, M5 |
| 8 | um `PopScope(canPop: false)` prende a rota | **X5**, F3, F1, M5 |
| 9 | o alvo de ampliação engole o card inteiro | S2, S4, S5, V2 |
| 10 | tocar na arte dispara a ação principal (vira compra) | S1, S4, S5, V1, V2 |

A número 4 é a que mais ensina. "Overlay" é a palavra da própria OS, e um
`OverlayEntry` é a leitura literal dela — só que uma sobreposição que não é rota
não absorve o toque de fora (abre duas) e não intercepta o voltar (o sistema
pop a tela de baixo). X3 e X5 existem para que essa leitura literal não passe.

A número 3 mostra por que X1 precisa de nome próprio: sem `errorBuilder`
quatorze casos caem, mas todos por motivos diferentes; só X1 diz o que
aconteceu.

## Evidência local

Mesmo overlay do CI em `C:\bmvcos`, Flutter 3.41.4.

```
flutter test test/cosmeticos  →  56 casos, All tests passed  (39 + 17)
flutter test                  →  1209 casos, All tests passed (1192 + 17)
flutter analyze               →  103 issues (base 1800981: 103 — delta ZERO)
                                 nenhum apontamento em lib/cosmeticos/ nem na suíte
```

## O que a V2 continua NÃO fazendo

Tudo o que a V1 já declarava segue de pé, e nada foi reaberto: a Loja continua
fora do fecho de `lib/main.dart`, `assets/loja/` continua não existindo nesta
linhagem, a folha de confirmação de compra continua sem `errorBuilder` (registrada,
não corrigida, porque é caminho de compra), e nenhum arquivo fora de `app/test/`
e `.github/workflows/` foi tocado nesta rodada.

---

**PASS — INSPEÇÃO AMPLIADA DOS COSMÉTICOS DA LOJA E DO PERFIL CANONIZADA V1**
