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

---

**PASS — INSPEÇÃO AMPLIADA SEGURA DE COSMÉTICOS NA LOJA E PERFIL V1**
