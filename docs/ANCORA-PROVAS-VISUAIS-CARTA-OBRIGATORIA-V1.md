# Âncora externa das provas visuais da carta obrigatória do lixo — V1

Contrato da autoridade que torna obrigatórias, de fato, as provas visuais do
destaque da carta obrigatória do lixo. Entregue pela OS 29-C6 sobre
`27e688fc2ab0d53947cc0556bf79eb7b3e4ed6db` (OS 29-C5).

Este documento **não é um manifesto concorrente**: ele descreve a única
autoridade canônica de gates que já existia — `.github/workflows/`,
`ci-os-integracao.yml` e o portão de qualidade do `build.yml` — e a âncora que
passou a viver dentro dela. Não há segundo agregador, segunda lista de gates,
segundo veredito nem segunda fonte de verdade.

---

## 1. O residual que esta âncora fecha

A OS 29-C4 tirou a guarda do desenho da obrigação de dentro do arquivo que ela
guarda. A OS 29-C5 deu à metade recíproca as mesmas cinco exigências que ela
cobra. O par ficou simétrico, e a própria C5 registrou o que sobrou — o
residual **C10**:

> esvaziar as **duas** metades no mesmo commit e realinhar o digest que sobra
> sai VERDE, com o placar da árvore íntegra: `cascaaud +28`, `mesac1 +31`.

Não é defeito de nenhuma das duas. Uma guarda **mútua de dois nós** não tem
âncora fora de si: tudo o que um cobra do outro está escrito num dos dois, e um
gesto que toca os dois ao mesmo tempo é, para o par, indistinguível de uma
mudança legítima.

A C10 foi **reproduzida antes de qualquer edição desta OS**, na bancada, com as
duas metades esvaziadas e os dois digests realinhados:

| gate | placar com C10 aplicada | placar da árvore íntegra |
|---|---|---|
| `cascaaud` | `+28 All tests passed!` | `+28 All tests passed!` |
| `mesac1` | `+31 All tests passed!` | `+31 All tests passed!` |

Indistinguíveis. É esse o buraco.

---

## 2. Os três nós

| nó | arquivo | natureza |
|---|---|---|
| A — a metade que guarda | `app/test/casca/auditoria_casca_test.dart` | suíte Dart, gate `cascaaud` |
| B — a metade recíproca | `app/test/casca/mesa_treino_alvos_reais_test.dart` | suíte Dart, gate `mesac1` |
| C — a âncora externa | `app/test/casca/ancora_provas_visuais_test.dart` | suíte Dart, gate `ancoravis` |

A e B se guardam mutuamente e **não foram tocados por esta OS**: continuam byte
a byte idênticos a `27e688f`.

C não pergunta nada a A nem a B sobre si mesmos. Ele carrega **cópia própria**
de:

* a lista de casos de A (5 nomes, em ordem) e a de B (31 nomes, em ordem);
* as declarações sem as quais cada metade não confere nada;
* as agulhas que cada metade tem de continuar afirmando, e quantas vezes,
  **dentro do primeiro argumento posicional de um `expect`**;
* os pisos de afirmações não triviais das duas metades (16 e 8);
* **os digests do CÓDIGO das duas metades** — e é aqui que a C10 morre, porque
  esses dois números moram num terceiro arquivo que o gesto coordenado de dois
  não toca.

---

## 3. As dez exigências

| # | exigência | onde é cobrada |
|---|---|---|
| 1 | existência dos dois arquivos protegidos | `os dois arquivos protegidos estão no caminho declarado` |
| 2 | inclusão efetiva das duas suítes no alvo oficial | `o alvo oficial executa as duas suítes protegidas, pelo caminho certo` + `o portão do APK roda o diretório inteiro e nomeia os três caminhos` |
| 3 | execução real de ambas | `as duas suítes protegidas executaram de verdade, e depois do carimbo` |
| 4 | identidade nominal dos casos protegidos | `os casos das duas metades são exatamente estes` + a chamada nominal no log |
| 5 | pisos de casos e de provas | `as duas metades continuam acima do piso de afirmações` + `o log de cada suíte protegida chama os casos pelo nome e fecha o placar` |
| 6 | conteúdo estrutural indispensável das duas metades | `cada metade tem as declarações sem as quais ela não confere nada` + `cada metade continua AFIRMANDO o que promete` |
| 7 | reciprocidade da guarda | `as duas metades se guardam de volta, e os digests que elas declaram batem com o que está lá` |
| 8 | vínculo de conteúdo que o realinhamento coordenado não alcança | `o código das duas metades bate com o digest desta âncora` |
| 9 | evidência produzida pelo executor verdadeiro | carimbo, marcadores `exit_*` e logs `t_*.log` de `cascaaud` e `mesac1` |
| 10 | reprovação se registro, produtor, marcador, log ou consumidor sumirem | `a entrada desta âncora está viva nas três listas do veredito`, `o comando que executa esta âncora está vivo, e não comentado`, `o vínculo de conteúdo desta âncora está declarado no alvo oficial`, `o produtor do carimbo está vivo no alvo oficial`, `o contrato desta âncora continua na árvore e nomeia o residual` |

**Comentário, string, suíte-isca e comando estreitado não satisfazem nenhuma
delas.** As agulhas são procuradas depois de o texto passar por um varredor que
tira comentário respeitando aspas e esvazia o conteúdo das strings preservando
as aspas; só conta o que está no primeiro argumento **posicional** de um
`expect`, e afirmação trivial — literal, string, `true`, `null`, `x || !x` — não
conta para piso nenhum.

---

## 4. Onde a âncora é executada, e por que em dois lugares

* **`.github/workflows/ci-os-integracao.yml`** — chave `ancoravis`, por
  `exige`, **depois** de `cascaaud` e `mesac1` (é preciso que os logs deles já
  existam). A chave está nas **três** listas do veredito: `GATES`, `LISTA` e as
  **duas** declarações idênticas de `OBRIGATORIOS`. Estar em `OBRIGATORIOS` é o
  que faz "o passo não chegou a rodar" sair VERMELHO em vez de neutro.

* **`.github/workflows/build.yml`** — o portão de qualidade que produz o APK
  roda `flutter test test/casca test/cartas` no diretório inteiro, e a âncora
  entra na lista de arquivos obrigatórios nomeados um a um.

A segunda porta não é redundância: **é ela que fecha o gesto de apagar a
entrada.** Quem tirar `ancoravis` das listas do alvo oficial continua rodando a
âncora pelo portão do APK, e ela reprova nominalmente pela entrada que sumiu. E
o comando `flutter test test/casca test/cartas` é afirmado, letra por letra, por
`auditoria_casca_test.dart` — que é um dos dois arquivos protegidos e não pode
ser alterado sem derrubar o par.

---

## 5. O vínculo de conteúdo da própria âncora

Uma âncora que só é obrigatória não é âncora: esvaziá-la sairia verde com o
placar de zero caso. O alvo oficial declara três coisas, ao lado do `exige`:

```
ANCORA_ARQUIVO=app/test/casca/ancora_provas_visuais_test.dart
ANCORA_CONTRATO=docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md
ANCORA_DIGEST=<sha256 do arquivo, com CR removido>
ANCORA_PISO=16
```

e as confere com linhas vivas: o `sha256sum` do arquivo contra `ANCORA_DIGEST`,
o digest declarado **neste documento** contra `ANCORA_DIGEST`, e o **placar
real** que o `--reporter expanded` escreveu no log da própria âncora contra
`ANCORA_PISO`.

O digest desta âncora tem, portanto, **dois donos**: o alvo oficial e este
contrato. Um digest com um dono só é um digest que se realinha — quem esvazia a
âncora atualiza a linha do workflow no mesmo commit e segue. É o residual C10 um
degrau abaixo. O segundo dono é prosa revisável, e não código que ninguém lê.

O digest vigente, que os dois têm de dizer, é:

ancora-digest: 5fd548ac9beb9d29e4e7a125717025c12ed55534eb927004f6bba9dbff0924da

A âncora, do outro lado, afirma em Dart que essas declarações continuam vivas e
com **esses** valores — inclusive recalculando o próprio digest e comparando-o
com o do alvo oficial e com o deste contrato.

O resultado é que nenhum gesto isolado se basta:

* editar a âncora sem passar por aqui → digest não bate (reprova no alvo, e
  reprova na própria âncora);
* esvaziar a âncora e realinhar o digest **só no alvo** → este contrato diverge
  (reprova no alvo);
* esvaziar a âncora e realinhar o digest **só aqui** → o `sha256sum` do arquivo
  não bate com o alvo (reprova no alvo);
* baixar `ANCORA_PISO` → a âncora afirma o valor e reprova (no alvo e no
  portão do APK);
* comentar o bloco de conferência → a âncora afirma que as linhas estão vivas.

---

## 6. A evidência do executor verdadeiro

O alvo oficial escreve, **antes de rodar qualquer suíte**:

```
date -u +%Y-%m-%dT%H:%M:%S.%NZ > carimbo_ancoravis
```

A âncora, que roda depois das duas suítes protegidas, exige:

* `exit_cascaaud` e `exit_mesac1` existirem e valerem `0`;
* `t_cascaaud.log` e `t_mesac1.log` existirem;
* **cada log ser posterior ao carimbo** — um log guardado de outra corrida e
  reapresentado é anterior a ele;
* o placar de fecho de cada log ser ≥ 28 e ≥ 31;
* os cinco casos da metade que guarda, as sete provas visuais do destaque da
  obrigação e o caso recíproco aparecerem **pelo nome** na chamada do
  `--reporter expanded`.

Onde não há carimbo — no portão do APK e na bancada de quem está escrevendo —
não há execução oficial para ler, e o que se cobra é que o **produtor** do
carimbo continue declarado no alvo oficial. Isso não é um `return` de
conveniência: é a única afirmação honesta disponível ali, e ela é fail-closed.

---

## 7. Campanha negativa

Dezenove sabotagens, cada uma aplicada **isoladamente** sobre a árvore íntegra,
mais o controle verde. Todas ficam VERMELHAS com causa nominal.

| # | sabotagem | quem reprova |
|---|---|---|
| C6-01 | C10 verbatim: esvaziar as duas metades e realinhar todos os digests | `ancoravis` — `o código das duas metades bate com o digest desta âncora` |
| C6-02 | apagar os dois casos protegidos, preservando comentários e nomes | `ancoravis` — `os casos das duas metades são exatamente estes` |
| C6-03 | trivializar os dois corpos com assertivas tautológicas | `ancoravis` — digest do código, piso de afirmações e agulhas |
| C6-04 | retirar `auditoria_casca_test.dart` do alvo | `ancoravis` — `o alvo oficial executa as duas suítes protegidas` |
| C6-05 | retirar `mesa_treino_alvos_reais_test.dart` do alvo | `ancoravis` — idem |
| C6-06 | retirar ambas do alvo | `ancoravis` — idem |
| C6-07 | desviar o alvo inteiro para suíte-isca | `ancoravis` — caminho declarado e comando do portão do APK |
| C6-08 | apagar a entrada externa que torna as provas obrigatórias | `ancoravis`, executada pelo portão do APK — `a entrada desta âncora está viva nas três listas do veredito` |
| C6-09 | apagar entrada, produtor e arquivos juntos | `build.yml` — a lista de arquivos obrigatórios nomeados um a um |
| C6-10 | comentar o comando vivo mantendo o literal | `ancoravis` — `o comando que executa esta âncora está vivo, e não comentado` |
| C6-11 | fabricar marcador sem executar as suítes | `ancoravis` — `as duas suítes protegidas executaram de verdade` |
| C6-12 | fornecer log anterior ao carimbo | `ancoravis` — idem, pela comparação com o carimbo |
| C6-13 | reduzir o piso ao valor sabotado | `ancoravis` — `o vínculo de conteúdo desta âncora está declarado no alvo oficial` |
| C6-14 | neutralizar o verificador externo | `ancoravis` — as quatro linhas vivas do bloco de conferência |
| C6-15 | neutralizar somente a nova guarda | alvo oficial — `sha256sum` contra `ANCORA_DIGEST` |
| C6-16 | neutralizar guarda e realinhar seu digest | alvo oficial — placar real abaixo de `ANCORA_PISO` |
| C6-17 | renomear um caso preservando a quantidade | `ancoravis` — `os casos das duas metades são exatamente estes` |
| C6-18 | manter nomes e esvaziar apenas o conteúdo semântico | `ancoravis` — digest do código, agulhas e piso |
| C6-19 | remover a campanha que cobra C10 | `ancoravis` — `o contrato desta âncora continua na árvore e nomeia o residual` |
| C6-20 | estado íntegro | **VERDE**, necessariamente |

---

## 8. O que continua aberto, e é registrado como tal

1. **Um gesto de quatro arquivos coordenados** — reescrever A, B, C e as duas
   entradas dos dois workflows no mesmo commit — não é distinguível de uma
   entrega legítima por nenhuma máquina desta árvore. É o limite estrutural de
   toda guarda por conteúdo, e o degrau seguinte é revisão humana, não mais um
   nó.

2. **`ci-os-integracao.yml` só dispara em `push` para
   `integracao/os-final-backend-flutter` e por `workflow_dispatch`.** A metade
   de evidência de execução desta âncora — os casos que leem carimbo, marcador
   e log — só é exercida onde esse alvo roda. Nas folhas de correção, a âncora
   roda pelo portão do APK e cobra tudo o que é estrutural, mais o produtor do
   carimbo. Isso é anterior a esta OS e não foi alterado por ela.
