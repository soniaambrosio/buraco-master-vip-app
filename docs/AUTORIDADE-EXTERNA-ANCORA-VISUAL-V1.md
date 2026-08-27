# Autoridade externa da âncora das provas visuais — V1

Contrato da autoridade que torna a **âncora** das provas visuais da carta
obrigatória do lixo verificável **de fora dela mesma**, e que torna a execução
das duas portas verificável **de fora dos dois workflows**. Entregue pela
OS 29-C7 sobre `69d63a47c5ec6eec387d36da0215f47c554148bf` (OS 29-C6).

Este documento **não é um manifesto concorrente**: não há segundo agregador,
segunda lista de gates, segundo veredito nem segunda fonte de verdade. A
autoridade canônica continua sendo `.github/workflows/` —
`ci-os-integracao.yml` e o portão de qualidade do `build.yml` —, e o que esta
OS acrescentou vive dentro dela.

---

## 1. O residual que esta autoridade fecha

A OS 29-C6 entregou o terceiro nó, `ancoravis`, e com ele matou o residual C10:
esvaziar as duas metades que se guardam mutuamente e realinhar os digests
deixou de sair verde, porque os digests do CÓDIGO das duas passaram a morar num
terceiro arquivo que aquele gesto não toca.

A OS 29-R5 mediu o que sobrou, e o que sobrou **era a própria âncora**. Seis
escapes:

| escape | gesto | por que passava |
|---|---|---|
| E1 | a âncora sai das DUAS portas, arquivos e contratos intactos | o `build.yml` só conferia que o ARQUIVO existe, e o comando que o executaria era cobrado por `contains` |
| E2 | um `#` na frente do `flutter test test/casca test/cartas` | presença textual não é execução: o passo saía VERDE com zero teste e os 343 casos caíam juntos |
| E3 | âncora esvaziada, os dois digests recarimbados, `ANCORA_PISO=1` | os três números que decidiam o que a âncora É moravam nos arquivos que o gesto já estava editando |
| E4 | `ANCORA_PISO` atribuído duas vezes | o leitor pegava a PRIMEIRA atribuição, o shell obedece à ÚLTIMA |
| E5 | a campanha reduzida a `C6-01 a C6-20.` | o caso que a vigiava pedia duas cadeias de seis letras |
| E6 | o produtor do carimbo movido uma linha adiante | `linhaViva` conferia que a linha EXISTE, nunca ONDE ela está |

A raiz de E1, E3 e E6 é a mesma: **uma autoridade cujo conteúdo, cujos números
e cuja posição só são conferidos por arquivos que o gesto já está tocando não é
uma autoridade.** Este documento e
`app/test/casca/autoridade_ancora_visual_test.dart` são o quarto nó.

---

## 2. Os quatro nós, e o que cada um congela

| nó | arquivo | gate | natureza |
|---|---|---|---|
| A | `app/test/casca/auditoria_casca_test.dart` | `cascaaud` | a metade que guarda o desenho |
| B | `app/test/casca/mesa_treino_alvos_reais_test.dart` | `mesac1` | a metade recíproca, na mesa montada |
| C | `app/test/casca/ancora_provas_visuais_test.dart` | `ancoravis` | a âncora externa de A e B |
| D | `app/test/casca/autoridade_ancora_visual_test.dart` | `autancora` | a autoridade externa de C |

A e B **não foram tocados por esta OS**: continuam byte a byte idênticos a
`27e688fc2ab0d53947cc0556bf79eb7b3e4ed6db`.

**D carrega cópia própria, e nenhum desses valores é calculado a partir do alvo
que ele verifica:**

* o **caminho canônico** da âncora, `test/casca/ancora_provas_visuais_test.dart`;
* o **piso mínimo** contratado — 16 casos — e o número vigente;
* a **relação nominal** dos casos da âncora, em ordem;
* o **digest do CÓDIGO** da âncora: sem comentário, sem as linhas marcadas
  `[digest-movel]`, sem linha vazia e sem espaço à direita;
* o **piso de afirmações não triviais** dela;
* as **declarações estruturais** sem as quais ela não confere coisa nenhuma;
* a **execução obrigatória** nas duas portas, cobrada como LINHA VIVA de um
  passo NOMEADO;
* o **vínculo com as duas portas**, incluindo o piso do portão do APK;
* o **vínculo com a campanha `C6-01` a `C6-20`** do contrato da âncora.

**E C guarda D de volta**, pelo conteúdo: caminho, número de casos, relação
nominal, digest do código, piso de afirmações, ausência de aspa tripla,
presença nas duas portas e os dois donos do digest.

---

## 3. Como cada escape foi fechado

### E1 — retirada coordenada das duas portas

A entrada da âncora é cobrada nas **quatro** listas do alvo oficial (`GATES`,
`LISTA` e as **duas** declarações idênticas de `OBRIGATORIOS`) e no **laço vivo
de obrigatórios** do `build.yml`. As duas cobranças moram em C **e** em D, que
são arquivos diferentes dos dois workflows atacados. Tirar a entrada das duas
portas deixa as duas suítes rodando pela varredura de diretório do
`build.yml` — e elas reprovam nominalmente pela entrada que sumiu. Apagar
também os arquivos reprova no laço, que os nomeia um a um.

### E2 — o comando comentado

O comando do portão do APK deixou de ser cobrado por `contains`. Ele é cobrado
como **linha viva de um passo nomeado**: o workflow é lido por passos, o corpo
de heredoc e as linhas de comentário são descartados, as continuações de `\`
são juntadas, e o que resta é o que o shell executa. `#`, `echo`, `if false`,
`|| true`, heredoc, diretório a menos e passo renomeado reprovam.

E o passo deixou de poder anunciar verde sem execução:

```
flutter test test/casca test/cartas --reporter expanded 2>&1 | tee ../t_apk_casca.log
```

é seguido da captura de `${PIPESTATUS[0]}`, da conferência do exit, da extração
do placar real do log e da conferência contra `APK_PISO`. **Zero teste com exit
0 fica VERMELHO.**

### E3 — a âncora esvaziada com os números recarimbados

D congela o **conteúdo** da âncora, não o carimbo dela. Esvaziar a âncora
reprova em D mesmo depois de recarimbar `ANCORA_DIGEST` no alvo oficial,
`ancora-digest:` no contrato dela e `ANCORA_PISO`.

### E4 — a atribuição-isca

Para cada variável que decide execução, identidade ou evidência —
`ANCORA_ARQUIVO`, `ANCORA_CONTRATO`, `ANCORA_DIGEST`, `ANCORA_PISO`,
`AUTORIDADE_ARQUIVO`, `AUTORIDADE_CONTRATO`, `AUTORIDADE_DIGEST`,
`AUTORIDADE_PISO`, `BMV_PORTA_ANCORAVIS` e `APK_PISO` — exige-se **exatamente
uma atribuição viva no passo autorizado**, com valor literal fechado (sem
expansão, sem substituição de comando, sem aspas), e **nenhuma** atribuição
viva do mesmo nome em qualquer outro passo. Guarda e shell passam a concordar
sobre qual valor governa.

### E5 — a campanha esvaziada

As campanhas são lidas como **tabela**, e não por `contains`: identificadores um
a um, únicos, na ordem contratada, cada um com descrição material do gesto, com
quem acusa e com o resultado esperado; a conta de vermelhos e de controles é
conferida, e o último vetor tem de ser o controle verde.

### E6 — o carimbo deslocado

A **posição** do produtor passou a ser contrato, e a evidência deixou de ter
modo degradado:

1. limpeza das evidências anteriores;
2. porta declarada e carimbo novo, gerado e exportado;
3. execução das suítes protegidas;
4. logs e marcadores;
5. execução de `ancoravis`;
6. execução de `autancora`;
7. agregação e veredito.

Nenhuma invocação de suíte pode preceder o carimbo, e o carimbo não pode
preceder a limpeza. **Ausência de carimbo é VERMELHA**: C e D não têm ramo
`if (!carimbo.existsSync()) return;`. Cada porta declara o próprio nome em
`BMV_PORTA_ANCORAVIS` e o carimbo desta corrida em `BMV_CARIMBO_ANCORAVIS`, e
o valor de ambiente tem de bater com o arquivo — um `carimbo_ancoravis`
guardado de outra corrida e reapresentado não casa.

---

## 4. O vínculo de conteúdo desta autoridade

O alvo oficial declara, ao lado do `exige autancora`:

```
AUTORIDADE_ARQUIVO=app/test/casca/autoridade_ancora_visual_test.dart
AUTORIDADE_CONTRATO=docs/AUTORIDADE-EXTERNA-ANCORA-VISUAL-V1.md
AUTORIDADE_DIGEST=<sha256 do arquivo, com CR removido>
AUTORIDADE_PISO=20
```

e as confere com linhas vivas: o `sha256sum` do arquivo contra
`AUTORIDADE_DIGEST`, o digest declarado **neste documento** contra
`AUTORIDADE_DIGEST`, e o **placar real** do `--reporter expanded` contra
`AUTORIDADE_PISO`.

O digest desta autoridade tem, portanto, **três donos**: o alvo oficial, este
contrato e a âncora — que carrega o digest do CÓDIGO dela.

O digest vigente, que o alvo oficial e este documento têm de dizer, é:

autoridade-digest: ae604af3652b97e7b4957bfaaee8205ac2b1d877cc879a1b7b8142b1e1acc29a

---

## 5. O piso do portão do APK

O portão do APK confere o placar real contra `APK_PISO`, e o piso vigente é
**369**: os 343 casos da árvore da OS 29-C6, mais os seis casos novos da âncora
e os vinte da autoridade externa desta OS. Nenhum dos 343 anteriores pode
desaparecer sem alguém reprovar — o piso é uma desigualdade, e a relação
nominal dos casos protegidos está em C.

---

## 6. Onde cada nó é executado

* **`ci-os-integracao.yml`**, passo `1+2 — analyze + suítes Flutter (captura
  exit codes sem abortar)`: `roda cascaaud`, `exige mesac1`, `exige ancoravis`,
  `exige autancora` — nesta ordem, todas depois do carimbo. As chaves
  `ancoravis` e `autancora` estão nas quatro listas do veredito.
* **`build.yml`**, passo `PORTÃO DE PRODUÇÃO — casca real (roteamento, mocks,
  dados pessoais)`: o laço de obrigatórios nomeia os seis arquivos um a um, e a
  varredura roda `test/casca` e `test/cartas` inteiros, com exit e placar
  consumidos.

---

## 7. Campanha negativa da OS 29-C7

Trinta e dois vetores, cada um aplicado **isoladamente** sobre a árvore
íntegra, com âncora de mutação conferida, exit individual, causa nominal e
restauração conferida por `git write-tree`.

| # | sabotagem | quem reprova | resultado esperado |
|---|---|---|---|
| C7-01 | E1 — a âncora sai do alvo oficial E do laço do `build.yml`, arquivos e contratos intactos | `ancoravis` e `autancora`, pela varredura de diretório | VERMELHO |
| C7-02 | E2 — o comando do portão do APK comentado com um único `#` | `ancoravis` e `autancora` — linha viva do passo nomeado | VERMELHO |
| C7-03 | E3 — âncora esvaziada, `ANCORA_DIGEST` recarimbado nos dois donos, `ANCORA_PISO=1` | `autancora` — digest do CÓDIGO da âncora | VERMELHO |
| C7-04 | E4 — `ANCORA_PISO=1` inserido DEPOIS da atribuição legítima | `ancoravis` e `autancora` — atribuição viva única | VERMELHO |
| C7-05 | E5 — a campanha do contrato da âncora reduzida a `C6-01` e `C6-20` | `ancoravis` e `autancora` — a campanha lida como tabela | VERMELHO |
| C7-06 | E6 — o produtor do carimbo movido para depois de `exige ancoravis` | `ancoravis` e `autancora` — a ordem do passo | VERMELHO |
| C7-07 | o comando do portão do APK envolvido em `if false` | `ancoravis` e `autancora` — linha viva | VERMELHO |
| C7-08 | o comando do portão do APK seguido de uma disjunção incondicional que engole o exit da execução | `ancoravis` e `autancora` — linha viva, e a proibição explícita da disjunção | VERMELHO |
| C7-09 | a execução do portão do APK substituída por um `echo` do mesmo texto | `ancoravis` e `autancora` — linha viva e proibição de `echo` | VERMELHO |
| C7-10 | o portão do APK perde a conferência de placar vazio e sai verde com zero teste | `ancoravis` e `autancora` — as sete linhas vivas do bloco | VERMELHO |
| C7-11 | `ANCORA_PISO=1` inserido ANTES da atribuição legítima | `ancoravis` e `autancora` — atribuição viva única | VERMELHO |
| C7-12 | `ANCORA_DIGEST` atribuído duas vezes, a segunda com o digest sabotado | `ancoravis` e `autancora` — atribuição viva única | VERMELHO |
| C7-13 | `ANCORA_ARQUIVO` atribuído duas vezes, a segunda apontando para uma isca | `ancoravis` e `autancora` — atribuição viva única | VERMELHO |
| C7-14 | âncora trivializada com TODOS os números recarimbados: alvo, contrato e piso | `autancora` — digest do código, casos nominais e piso de afirmações | VERMELHO |
| C7-15 | a autoridade externa apagada da árvore | `ancoravis`, `exige` do alvo oficial e o laço do `build.yml` | VERMELHO |
| C7-16 | autoridade externa esvaziada e os dois donos do digest dela recarimbados | `ancoravis` — digest do CÓDIGO da autoridade | VERMELHO |
| C7-17 | a campanha deste contrato reduzida aos rótulos extremos `C7-01` e `C7-32` | `ancoravis` e `autancora` — a campanha lida como tabela | VERMELHO |
| C7-18 | o identificador intermediário `C6-10` removido da campanha da âncora | `ancoravis` e `autancora` — ordem e contagem | VERMELHO |
| C7-19 | o identificador `C6-09` duplicado para completar a contagem | `ancoravis` e `autancora` — unicidade e ordem | VERMELHO |
| C7-20 | a ordem de `C6-04` e `C6-05` trocada na campanha da âncora | `ancoravis` e `autancora` — ordem contratada | VERMELHO |
| C7-21 | o carimbo movido para depois da PRIMEIRA suíte protegida | `ancoravis` e `autancora` — a ordem do passo | VERMELHO |
| C7-22 | o produtor do carimbo apagado do alvo oficial | `ancoravis` e `autancora` — linha viva ausente, e a porta sem carimbo | VERMELHO |
| C7-23 | carimbo de outra corrida reapresentado, com o ambiente desta | `ancoravis` e `autancora` — o carimbo de disco não casa com o de ambiente | VERMELHO |
| C7-24 | o log de `cascaaud` fabricado com o placar correto, sem chamada nominal | `ancoravis` — a chamada nominal dos casos no log | VERMELHO |
| C7-25 | o marcador `exit_mesac1` fabricado sem log correspondente | `ancoravis` — marcador sem log é marcador fabricado | VERMELHO |
| C7-26 | suíte-isca da âncora, com os vinte e dois nomes de caso e corpos vazios | `autancora` — digest do código e piso de afirmações | VERMELHO |
| C7-27 | retirada coordenada de fonte, executor e suíte: entrada, chave das listas e arquivo | `autancora` pela varredura, e o laço do `build.yml` | VERMELHO |
| C7-28 | E2 combinado com E3: comando do APK comentado, âncora esvaziada e todos os digests e pisos recarimbados | `autancora` — o digest do CÓDIGO da âncora, que o gesto não alcança | VERMELHO |
| C7-29 | `autancora` retirado das DUAS declarações de `OBRIGATORIOS` | `ancoravis` e `autancora` — as quatro listas | VERMELHO |
| C7-30 | `autancora` retirado só de `LISTA` | `ancoravis` e `autancora` — a lista que o veredito percorre | VERMELHO |
| C7-31 | `APK_PISO` baixado de 369 para 1 | `ancoravis` e `autancora` — o piso da segunda porta | VERMELHO |
| C7-32 | estado íntegro, sem nenhuma alteração na árvore | controle, **necessariamente verde** | VERDE |

---

## 8. O que continua aberto, e é registrado como tal

1. **O gesto coordenado que sobra tem cinco arquivos de três naturezas.** Para
   neutralizar C e D ao mesmo tempo é preciso reescrever, no MESMO commit:
   `app/test/casca/ancora_provas_visuais_test.dart`,
   `app/test/casca/autoridade_ancora_visual_test.dart`,
   `.github/workflows/ci-os-integracao.yml` (quatro números),
   `docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md` e este documento — e,
   se as duas metades protegidas também forem tocadas, mais dois arquivos e o
   `build.yml`. Nenhum subconjunto próprio deste gesto sai verde, e nenhum
   gesto menor executa zero teste e produz verde. **Isto não é proteção
   absoluta**: é um limite estrutural de toda guarda por conteúdo, e o degrau
   seguinte é revisão humana. O diff de um gesto assim é evidente — cinco
   arquivos de três naturezas mudando juntos, com dois digests e dois pisos
   realinhados.

2. **`ci-os-integracao.yml` só dispara em `push` para
   `integracao/os-final-backend-flutter` e por `workflow_dispatch`**, e o
   `workflow_dispatch` só é oferecido pelo GitHub para workflow presente na
   branch **padrão** — onde este arquivo nunca chegou. A metade de evidência de
   execução (carimbo, marcador, log, placar e chamada nominal) só é exercida
   onde esse alvo roda. Nas folhas de correção, C e D rodam pelo portão do APK
   e cobram tudo o que é estrutural, mais a evidência que AQUELA porta produz.
   Isso é anterior a esta OS e não foi alterado por ela.

3. **A porta é declarada por ambiente.** Quem controla o ambiente do executor
   controla a porta declarada — e é por isso que o nome da porta de cada passo
   é cobrado, letra por letra, como atribuição viva única dentro do passo
   nomeado: mudar a porta exige editar o workflow, e editar o workflow reprova
   em C e em D.
