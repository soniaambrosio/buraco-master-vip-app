# Portão de Release Candidate

`node ferramentas/portao-rc/portao-rc.js`

Uma pergunta, uma resposta: **esta Release Candidate está apta a prosseguir?**
PASS ou FAIL, com código de saída, lista do que rodou, lista do que **não** rodou,
quantidade de casos provados, falha original preservada, estado do encerramento e
um recibo assinado *desta* execução.

---

## A regra central

> **Ausência de prova não é aprovação.**

Um portão ingênuo pergunta "alguma suíte falhou?". Essa pergunta sai verde em
quatro situações distintas em que a RC **não** foi provada:

| situação | exit code do runner | o que o portão ingênuo diz |
|---|---|---|
| a suíte não rodou | 0 | verde |
| a suíte encolheu (arquivo saiu do glob) | 0 | verde |
| o ambiente não subiu e nada executou | 0 ou 1 | verde ou "falha de teste" |
| a execução terminou prendendo porta | 0 | verde |

As quatro reprovam aqui.

## As regras, uma a uma

| regra | efeito |
|---|---|
| suíte executou e falhou | FAIL — exit 1 |
| suíte **obrigatória** não executou | FAIL — exit 5 (ou 4, se foi o ambiente que impediu) |
| suíte executou incompleta (pulou, cancelou, encolheu) | FAIL — exit 5 |
| **teste verde + cleanup vermelho** | FAIL — exit 6 |
| processo órfão sobreviveu | FAIL — exit 6 |
| trava (lock) residual | FAIL — exit 6 |
| porta não drenada, *quando aplicável* | FAIL — exit 6 |
| árvore suja ao fim | FAIL — exit 6 |
| recibo de outra execução no lugar deste | FAIL — exit 5 |

### Códigos de saída

```
0  PASS
1  falha funcional — alguma suíte rodou inteira e reprovou
2  uso incorreto do próprio portão
4  ambiente/ferramenta impediu suíte obrigatória
5  ausência de prova — obrigatória ausente, não solicitada, ou suíte incompleta
6  cleanup incompleto — órfão, trava, porta presa ou árvore suja
```

**Precedência:** `5 → 4 → 1 → 6`. Não é arbitrária, e é a mesma doutrina de
`firebase/testes/relatorio-testes.js` um nível abaixo:

- **ausência de prova vem antes de falha funcional** porque uma execução com
  suíte obrigatória faltando não é um veredito sobre o código. Anunciar "falha
  funcional" ali mandaria caçar asserção quebrada — e, pior, declararia que o
  resto foi provado;
- **cleanup vem por último** porque ele só precisa conseguir transformar VERDE em
  vermelho. Se já existe vermelho de suíte, o diagnóstico dele é mais útil, e o
  cleanup segue registrado no recibo sem sequestrar o código de saída.

A ordem das suítes na lista não muda a classe do vermelho (há teste para isso).

---

## O catálogo

`ferramentas/portao-rc/catalogo.js` **é a política**. O orquestrador só executa o
que está declarado ali; o veredito só julga o que o orquestrador devolveu.

| chave | frente | obrigatória |
|---|---|---|
| `flutter-analyze` | Flutter | sim |
| `flutter-testes` | Flutter | sim |
| `billing` | Billing | sim |
| `functions-torneios` | Functions | sim |
| `social-puro` | Social | sim |
| `moderacao-puro` | Moderação | sim |
| `runners-emulador` | Runners de emulador | sim |
| `portao-rc` | Portão | sim |
| `regras-firestore` | Firestore Rules | sim |
| `social-emulador` | Social | sim |
| `moderacao-emulador` | Moderação | sim |
| `colecoes-emulador` | Integração | sim |
| `servidor` | Servidor | **não — fora desta base** |
| `ranking` | Ranking | **não — fora desta base** |
| `economia` | Economia | **não — fora desta base** |

### As três frentes fora da base

São **declaradas, e não omitidas**. Uma RC que não cobre o servidor precisa
*dizer* que não cobre o servidor — o silêncio seria lido como cobertura. Elas
aparecem na seção `COBERTURA` do relatório, com endereço:

- **`servidor`** — a autoridade da partida vive no repositório `buraco-servidor`,
  fora deste git. Aqui o Firebase cobre só Auth e persistência.
- **`ranking`** — `functions-ranking/` não existe neste commit; vive na linhagem
  `claude/player-account-deletion-flow-d04d45`.
- **`economia`** — `functions-economia/` vive em `feat/economia-boas-vindas-vitorias`.

Elas **não reprovam** porque o código não está neste commit — reprovar seria
acusar esta base de um buraco que ela não tem. No dia em que a base passar a
contê-las, `--exigir=<chave>` as promove a obrigatórias e a ausência passa a
reprovar.

---

## Descoberta da suíte Dart: por varredura, nunca por lista

Este é o defeito concreto que o portão fecha. Nesta árvore existem **dois**
buracos de descoberta simultâneos:

1. **`flutter test` solto** descobre apenas `*_test.dart`. Sete arquivos
   versionados usam o prefixo `teste_` (`teste_motor.dart`,
   `teste_motor_resiliencia.dart`, `teste_integracao_motores.dart`,
   `teste_moderacao.dart`, `teste_visao_espectador.dart`, `teste_social.dart`,
   `teste_encerramento.dart`) e ficam **invisíveis**.
2. **`ci-os-integracao.yml`** não usa o glob — chama cada suíte por caminho, numa
   lista literal escrita à mão. A lista ficou para trás: `test/moderacao/`,
   `test/motor/` e `test/rastreabilidade/` inteiros estão fora do portão do CI
   hoje, sem que nada fique vermelho.

O portão varre `app/test/` e passa os caminhos **explicitamente**, e depois
confere no `--machine` que **todo arquivo pedido emitiu evento `suite`**. Um
arquivo novo entra no portão no dia em que é escrito; um arquivo que some derruba
o piso. Nenhuma das duas coisas depende de alguém lembrar de editar uma lista.

Ficam de fora, com motivo registrado e visível no relatório:

- `test/rastreabilidade/ferramentas.dart` — biblioteca de apoio, sem casos;
- `test/colecoes/evidencias_visuais_test.dart` — gerador de PNG que depende de
  fonte do sistema; vermelho ali não afirma regressão de produto. Decisão já
  registrada no cabeçalho do próprio arquivo e no `ci-os-integracao.yml`.

### Piso de casos

Cada suíte declara um `piso` — o mínimo de casos para o portão aceitar que ela
rodou inteira. É **piso, e não igualdade**: um caso novo não fica devendo edição
de configuração, mas um caso que **some** derruba. Um `describe`/`group` pulado
inteiro não soma no rodapé `skipped`, então o total é a única frente que enxerga
esse buraco.

Os pisos das suítes de emulador **não** moram no catálogo: já moram no
`--esperado=N` dos alvos internos de `firebase/testes/package.json`, e o runner os
aciona. Duas cópias do número divergiriam na primeira vez que alguém acrescentasse
um caso.

---

## Encerramento

O portão confere cinco coisas depois que a última suíte termina:

- **processos órfãos** — só conta o que **esta** execução subiu. Cada filho é
  registrado antes de nascer. Um portão que varresse a máquina atrás de
  `java.exe` reprovaria por causa do Android Studio aberto na outra janela, e
  seria desligado na primeira semana;
- **trava residual** — o `.lock` do Emulator Suite de pé depois de todos
  terminarem significa que algum runner morreu sem passar pelo `finally`;
- **dreno das portas** — as oito portas do Emulator Suite, por teste de **bind** e
  não por leitura de `netstat` (sockets em `TIME_WAIT` não impedem nada e não
  são medidos). Só cobrado **quando aplicável**: se nenhum emulador subiu, não há
  o que drenar;
- **encerramento das suítes** — uma suíte cujo `runner-emulador.js` saiu com
  classe `CLEANUP-INCOMPLETO` (exit 6: testes passaram, portas ficaram presas)
  reprova **mesmo que as portas tenham drenado depois**. O portão mede as portas
  no fim de tudo, e até lá o rabo de alguns segundos já passou; se só o retrato
  final valesse, o estrago sumiria do recibo — a suíte seguinte esperou, o dreno
  final disse "ok", e ninguém saberia que uma execução entregou o ambiente preso;
- **árvore limpa** — `git status --porcelain` no fim, descontando a sujeira que já
  existia ao iniciar. Quem roda o portão com trabalho em andamento não é acusado
  do próprio rascunho; o portão responde pelo que **ele** sujou.

O portão **mata o órfão e remove a trava, e reprova mesmo assim**. Os dois passos
não se substituem: matar protege a próxima execução (que é o dano concreto);
reprovar protege a verdade do recibo (uma execução que precisou de faxina não foi
uma execução limpa).

### A encenação de CI

Quatro suítes Dart leem seeds de `app/test/{torneios,colecoes}/data/`, que não
existem na árvore — o CI as copia de `app/data/`. O portão monta essa encenação
antes e a desmonta no `finally`, **sempre**, inclusive quando a execução morre no
meio. O que sobrar aparece como árvore suja e reprova: um portão que sujasse a
árvore para se provar verde seria o mesmo defeito, do lado do versionamento.

---

## O recibo

Gravado em `.portao-rc/` (ignorado pelo git — um PASS de terça não pode viajar
para a árvore de quem clonar na sexta).

**Recibo antigo não pode passar por execução atual.** Três amarras, e as três
precisam bater:

1. **`execucaoId`** — UUID sorteado no início de cada corrida. Responde "este
   arquivo foi escrito por *mim*?";
2. **`commit`** — responde "sobre *qual* código?". Um verde do commit anterior não
   diz nada sobre este;
3. **`terminadoEm`** — responde "*quando*?". Recibo sem hora de término é recibo
   de execução que não acabou.

E a amarra que fecha o circuito: o portão **apaga qualquer recibo anterior antes
de começar**. Se, ao terminar, encontrar no lugar um recibo com outro
`execucaoId`, houve duas corridas concorrentes sobre a mesma árvore — e nenhuma
das duas pode assinar a RC, porque as duas se atrapalharam.

```bash
node ferramentas/portao-rc/portao-rc.js --conferir
```

Lê o último recibo e responde se ele vale **para esta árvore**: recusa recibo de
outro commit, sem hora de término, com mais de 12h, ou de execução parcial.
Ausência de recibo não é aprovação — é a prova de que o portão não rodou aqui.

---

## Uso

```bash
# execução completa — a única que pode sair PASS
node ferramentas/portao-rc/portao-rc.js

# só o que não precisa de JVM (depuração; nunca sai PASS)
node ferramentas/portao-rc/portao-rc.js --sem-emulador

# recorte (depuração; nunca sai PASS)
node ferramentas/portao-rc/portao-rc.js --apenas=billing,social-puro

# promove uma frente fora da base a obrigatória
node ferramentas/portao-rc/portao-rc.js --exigir=ranking

# lê o último recibo e valida contra a árvore atual
node ferramentas/portao-rc/portao-rc.js --conferir

# mostra o catálogo e a varredura da suíte Dart
node ferramentas/portao-rc/portao-rc.js --listar
```

**Execução parcial nunca é PASS.** `--apenas` e `--sem-emulador` existem para
depurar, e o portão continua respondendo a mesma pergunta: as obrigatórias que
ficaram de fora entram como `NÃO SOLICITADA` e reprovam com exit 5. Um perfil que
pudesse sair verde seria um interruptor para desligar o portão, e um portão com
interruptor não é portão.

---

## O que o portão não faz, de propósito

- **não reescreve falha de teste.** O texto original do runner atravessa inteiro
  até o relatório. A camada de agregação não pode transformar falha funcional em
  erro genérico de infraestrutura;
- **não repete suíte vermelha.** Repetir teste até passar é a definição de portão
  mentiroso. A única repetição nesta árvore é a do `runner-emulador.js`, para o
  caso em que o emulador **não chegou a subir** por porta — limitada a uma vez e
  só para quem não deixou recibo;
- **não tem default de sucesso.** Nada usa `?? 0` sobre exit code: um default de
  zero é exatamente a construção que transforma ausência em aprovação;
- **não altera lógica de produção.** O portão lê; ele não conserta.

## Java

O emulador do Firestore é uma JVM. Nesta máquina `java` não está no `PATH`, mas o
JDK 21 do Android Studio está instalado — o portão procura no `PATH`, em
`JAVA_HOME` e no JBR, e exporta o que achar para os filhos.

Procurar **não é afrouxar**: se não houver java em lugar nenhum, as quatro suítes
de Emulator Suite ficam `IMPEDIDA` e, por serem obrigatórias, **reprovam** com
exit 4. O que a busca evita é reprovar por configuração de `PATH` quando a
ferramenta existe.

## Carga dos codebases: um vermelho que mentia

Medido nesta árvore em **duas execuções independentes** — pelo portão e pelo
comando documentado `npm run emulador:moderacao` rodado sozinho:

```
!!  functions: Failed to load function definition from source:
    FirebaseError: User code failed to load. Cannot determine backend
    specification. Timeout after 10000.
```

`functions-moderacao` estoura o limite de **10s** para declarar o backend. O
emulador **sobe assim mesmo, sem o codebase**. As 16 chamadas a
`registrarDenuncia`/`bloquearJogador` voltam `FirebaseError: not-found`, e a
suíte reprova por asserção — 45 casos, 29 passam, 16 falham.

O `runner-emulador.js` classifica isso, com razão pelo que ele enxerga, como
**FALHA-FUNCIONAL**: a suíte rodou inteira e as asserções falharam. Só que o
diagnóstico manda para o lugar errado — ninguém vai achar defeito em
`registrarDenuncia`, porque a Function **nunca chegou a existir** naquela
execução.

O portão trata isso em duas frentes:

1. **Diagnóstico** — `lerCargaDeCodebases` amarra cada `Failed to load` ao
   diretório da linha `Watching "<dir>"` que a precede, e reclassifica a suíte
   como `IMPEDIDA` quando é **o codebase sob teste** que não carregou. Continua
   reprovando (obrigatória impedida, exit 4 em vez de 1); o que muda é para onde
   quem lê o vermelho vai olhar.

   A atribuição por diretório é o ponto difícil: `--only functions:<codebase>`
   **não** restringe o carregamento no firebase-tools 15 — o emulador percorre
   todos os codebases do `firebase.json`, e vários falham de propósito por não
   estarem compilados (`functions/lib/index.js` não existe quando ninguém pediu
   torneios). Contar qualquer falha de carga reprovaria até as execuções que
   passaram, inclusive a do social, que roda 67 casos verdes com essas mesmas
   linhas na saída.

2. **Acomodação** — o portão exporta `FUNCTIONS_DISCOVERY_TIMEOUT=120` (segundos)
   para os filhos. A causa é tamanho de carga, e não lógica: cada codebase carrega
   um `domain_bundle.js` de ~80 KB gerado por `dart compile js`.

   **Isto não afrouxa teste.** Nenhuma asserção muda, nenhum piso baixa, nenhum
   pulo é perdoado. O que muda é a Function *existir*, para que a suíte possa ter
   veredito. Se o codebase ainda assim não carregar, o portão reprova como
   `IMPEDIDA`. É a mesma natureza da busca por java no JBR: acomodação de
   ambiente, para que o vermelho fale do produto e não da máquina.

## Testes do próprio portão

```bash
cd ferramentas/portao-rc && node --test portao-rc.test.js
```

Um portão que não se prova não pode reprovar ninguém — e o argumento é mais forte
aqui do que numa suíte comum: um defeito neste código não aparece como bug de
produto, aparece como release aprovada que não devia ter saído, e ninguém procura
por ela.

Nada nos testes sobe emulador, chama Flutter ou toca a rede. É deliberado: a regra
"teste verde + cleanup vermelho reprova" precisa ser barata de provar, senão não é
provada. A própria suíte do portão é uma das suítes obrigatórias do portão.
