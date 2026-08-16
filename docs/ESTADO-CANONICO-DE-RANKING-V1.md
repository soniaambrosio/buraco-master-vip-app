# Estado canônico de ranking no Perfil — V1

Base: `origin/homologacao/casca-producao-auth-roteamento-v2` em `ec16a65`.

## O defeito

Com `PerfilService.statsDemo` desligado — que é o estado publicável — três
superfícies liam o mesmo fato, "não há autoridade de ranking alcançável", e
chegavam a três conclusões diferentes:

| Superfície | O que fazia | Veredito |
|---|---|---|
| Home | mandava `liga: null` e omitia a linha inteira | honesto |
| Perfil | recebia `'Bronze'` e `0` do serviço e desenhava `💎 Liga Bronze · #0 no mundo` | afirmação falsa |
| Compartilhamento | copiava `Liga ${vm?.liga ?? 'Bronze'}` para a área de transferência | afirmação falsa, **e fora do aparelho** |

Nenhum dos dois valores vinha de lugar nenhum. Eram o que os tipos `String` e
`int` exigiam de um produtor que não tinha o dado.

### Origem exata dos fallbacks

Três lugares, e é importante que sejam três, porque consertar só o que aparece
na tela deixaria os outros dois de pé:

1. **`app/lib/services/perfil_service.dart`** — a origem real:
   `liga: demo ? 'Diamante' : 'Bronze'` e `posicaoMundial: demo ? 128 : 0`.
2. **`app/lib/screens/perfil_screen.dart`** — o desenho incondicional:
   `'· #${vm.posicaoMundial} no mundo'`, sem guarda nenhuma.
3. **`app/lib/pages/perfil_page.dart`** — o fallback do texto público:
   `'Nível ${vm?.nivel ?? 1} · Liga ${vm?.liga ?? 'Bronze'}.'`.

Ausência de ranking não é Liga Bronze. Posição zero não é colocação: um jogador
que nunca disputou nada não está em último lugar do mundo, está **fora da
tabela**.

## O estado canônico adotado

`app/lib/ranking/estado_ranking.dart` — `EstadoRanking`, um valor só, com quatro
fases distintas:

| Fase | Significado |
|---|---|
| `indisponivel` | não há autoridade alcançável, ou ela não foi consultada |
| `carregando` | a consulta está em voo |
| `falha` | há autoridade, e ela não respondeu |
| `disponivel` | há resposta — o que **não** garante que haja liga ou colocação |

As fases não foram colapsadas de propósito: tratar "não sei" e "sei, e a pessoa
não está na tabela" como a mesma coisa foi o começo do caminho que produziu o
Bronze.

A higienização mora nos **getters**, e não em cada tela:

- `liga` devolve `null` fora de `disponivel`, e também quando a string é vazia
  ou só espaços;
- `posicaoMundial` devolve `null` fora de `disponivel`, e também quando o valor
  é `0` ou negativo.

Quem desenha nunca vê o valor bruto. Não há como uma tela ler `0` deste objeto
e decidir sozinha que aquilo dá `#0` — inclusive se o backend de ranking, no
dia em que for ligado, mandar zero no lugar de ausente.

`rankingDaCascaPublicavel` é a constante única que declara o que esta casca
consegue afirmar hoje: nada. Home e Perfil **leem** essa constante em vez de
cada uma concluir por conta própria o que significa "sem ranking" — era essa
decisão duplicada que deixava uma honesta e a outra inventando.

## Comportamento final

**Home.** Inalterado no que aparece: `CabecalhoJogador.liga` continua nulo e a
linha continua omitida. O que mudou é a procedência — o nulo agora vem de
`rankingDaCascaPublicavel.liga`, e não de um literal escrito na Home.

**Perfil.** O rótulo `💎 Liga` e o valor permanecem no lugar; sem liga, o valor
é `—`, uma ausência admitida que não se parece com nome de liga e não desloca o
cabeçalho. O trecho da colocação **some** quando não há colocação: não existe
travessão que faça `#` parecer honesto, e por ser o último item da linha, tirá-lo
não mexe em mais nada. Com dados reais, os dois aparecem normalmente.

**Compartilhamento.** Cada trecho competitivo só entra se houver o que afirmar.
Sem ranking, o convite não cita liga, colocação nem travessão — e continua sendo
um convite: perde a linha, não a função. Com ranking real, preserva liga e
colocação. É a superfície mais rigorosa das três, porque é a única que sai do
aparelho.

## Fixtures e demonstração

`PerfilService.statsDemo` continua existindo e continua `false`. Com a chave
ligada, liga e colocação voltam a ser afirmadas — e está correto, porque aí são
fixture declarada de prévia, não fallback de produção. O mesmo vale para
`PerfilVM.mock()`, que tem Liga Diamante e `#128` escritos dentro.

A prova de que nada disso alcança o aplicativo publicado é estrutural, não um
`grep` do dia do fechamento: a suíte varre o fecho transitivo dos imports a
partir de `lib/main.dart` e afirma que

- nenhum arquivo alcançável contém a liga inventada;
- nenhum arquivo alcançável interpola a colocação sem guarda;
- `PerfilVM.mock` não é **construída** por nada que nasça em `main()` (a
  declaração do factory não conta — ela mora na tela, que é catálogo visual);
- `statsDemo` só é lida dentro do próprio serviço;
- `EstadoRanking.indisponivel()` só é produzida em um arquivo, o que impede uma
  segunda superfície de voltar a decidir por conta própria.

## O que esta OS não fez

Não integrou o backend de ranking. `functions-ranking` existe no repositório,
mas nenhuma tela desta casca fala com ele, e o item "Ranking" da Home segue
apagado com aviso. A correção representa honestamente o estado indisponível;
ela não inventa uma integração.

Quando a autoridade chegar, quem passa a produzir `EstadoRanking` é ela, e
`rankingDaCascaPublicavel` deixa de ser lida. Nenhuma tela precisa mudar.

## Validação

- `flutter test`: **749** casos, todos verdes (baseline da `ec16a65`: 716).
- Suítes `teste_*.dart`, fora do glob padrão: **549** casos, todos verdes.
- `flutter analyze`: **38 issues, 0 erros** — linha a linha idêntico à base.
- `dart format`: aplicado aos arquivos criados e aos que já eram limpos na base.
  `perfil_screen.dart` e `perfil_service.dart` **não** foram formatados por
  inteiro: os dois já divergiam do formatador em `ec16a65`, e formatá-los somaria
  cerca de 400 linhas de ruído a uma mudança de 97.

As 4 suítes que dependem de seeds (`test/colecoes/data/`, `test/torneios/data/`)
exigem o overlay que o CI monta a partir de `app/data/`. Ele foi reproduzido
localmente e **não** foi commitado.
