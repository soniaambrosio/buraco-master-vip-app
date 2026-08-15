# Portão de RC — evidência de homologação

Execuções reais nesta máquina, sobre o commit `054406e`
(branch `claude/gate-automatizado-rc-v1-819647`, base `9fd3a67`).

O portão em si: [`ferramentas/portao-rc/`](../ferramentas/portao-rc) · doc: [PORTAO-RC.md](PORTAO-RC.md)

---

## 1. Demonstração de PASS

```bash
node ferramentas/portao-rc/portao-rc.js
```

**`VEREDITO: PASS` — exit 0 — 1440 casos provados — 12 suítes executadas.**

| suíte | veredito | casos | tempo |
|---|---|---|---|
| `flutter-analyze` | PASS | 0 | 21.3s |
| `flutter-testes` | PASS | **1052** | 34.4s |
| `billing` | PASS | 13 | 7.1s |
| `functions-torneios` | PASS | 0 | 13.8s |
| `social-puro` | PASS | 19 | 11.7s |
| `moderacao-puro` | PASS | 13 | 20.6s |
| `runners-emulador` | PASS | 40 | 11.2s |
| `portao-rc` | PASS | 66 | 1.3s |
| `regras-firestore` | PASS | 105 | 17.8s |
| `social-emulador` | PASS | 67 | 2.4min |
| `moderacao-emulador` | PASS | 45 | 1.9min |
| `colecoes-emulador` | PASS | 20 | 1.1min |
| `servidor` | AUSENTE (opcional) | — | — |
| `ranking` | AUSENTE (opcional) | — | — |
| `economia` | AUSENTE (opcional) | — | — |

Cleanup: trava `ok` · órfãos `ok` · dreno `ok` · encerramento das suítes `ok` ·
árvore `ok`.

**1052 casos Dart contra os 536 que o glob enxerga.** A varredura de `app/test/`
achou 18 arquivos de suíte, **7 deles com prefixo `teste_`** — invisíveis ao
`flutter test` solto. Também entraram `test/moderacao/`, `test/motor/` e
`test/rastreabilidade/`, que a lista literal do `ci-os-integracao.yml` deixou
para trás.

---

## 2. Demonstração de FAIL — falha funcional

Injetado um caso que falha de propósito, em
`app/test/teste_demonstracao_falha.dart`. O nome é deliberado: com prefixo
`teste_`, o arquivo é **invisível** ao `flutter test` solto — se o portão o
pegar, a varredura funciona.

```bash
node ferramentas/portao-rc/portao-rc.js
```

**`VEREDITO: FAIL` — exit 1 — 1442 casos — 1 falha.**

1442 = 1440 + os 2 casos do arquivo injetado: **o arquivo foi descoberto**.

A falha original atravessa sem ser reescrita:

```
1. flutter-testes: a suite rodou inteira e REPROVOU
   Falha original preservada (nao reescrita por esta camada):
     ✗ DEMONSTRACAO — falha injetada de proposito
       este caso FALHA de proposito: o portao tem que reprovar a RC
         Expected: <5>
           Actual: <4>
         falha injetada pela demonstracao do portao de RC
```

Arquivo removido em seguida; árvore limpa.

---

## 3. Demonstração de FAIL — cleanup

Plantada uma trava residual do Emulator Suite e rodado um recorte:

```bash
node ferramentas/portao-rc/portao-rc.js --apenas=portao-rc
```

**`VEREDITO: FAIL` — exit 5.**

```
  CLEANUP
  trava do emulador   FALHA  C:\...\Temp\bmv-emulador-demo-bmv.lock
  processos orfaos    ok
  dreno das portas    nao aplicavel (nenhum emulador subiu)
  encerramento das suites ok
  arvore de trabalho  ok

  12. TRAVA RESIDUAL do Emulator Suite
     Sobrou o arquivo de trava:  C:\...\bmv-emulador-demo-bmv.lock
     dono registrado: alvo=social pid=20856
```

Três coisas de uma vez nesta execução:

- **a trava residual foi detectada e reprovou**, com o dono registrado;
- **o portão removeu a trava e reprovou mesmo assim** — verificado depois: o
  arquivo não existe mais. Matar protege a próxima execução; reprovar protege a
  verdade do recibo;
- **execução parcial nunca é PASS**: as 11 obrigatórias fora do recorte saíram
  `NÃO SOLICITADA [REPROVA]`, e as 3 opcionais `[não reprova]`. O exit foi **5** e
  não 6 porque a precedência documentada é `SEM_PROVA → AMBIENTE → FUNCIONAL →
  CLEANUP`: com suíte obrigatória sem rodar, o portão não tem veredito sobre o
  código, e dizer "cleanup" ali seria responder a pergunta menor.

---

## 4. Um vermelho que mentia — e o que o portão fez com ele

**Antes** de qualquer acomodação, a primeira execução completa deu:

```
moderacao-emulador: FALHA (45 casos) — 29 pass, 16 fail
```

As 16 falhas eram **todos** os casos dos dois blocos que chamam Cloud Function.
Causa real, no log do emulador:

```
!!  functions: Failed to load function definition from source:
    FirebaseError: User code failed to load. Cannot determine backend
    specification. Timeout after 10000.
```

`functions-moderacao` estourou o limite de 10s para declarar o backend, o
emulador subiu **sem ele**, e cada chamada voltou `FirebaseError: not-found`.

**Confirmado como pré-existente, não causado pelo portão:** o comando documentado
`npm run emulador:moderacao`, rodado sozinho, reproduz exatamente o mesmo
resultado — 45 casos, 29 pass, 16 fail, mesmo timeout.

O `runner-emulador.js` classificou como `FALHA-FUNCIONAL` — correto pelo que ele
enxerga (a suíte rodou inteira, as asserções falharam), mas manda procurar
defeito em `registrarDenuncia`, uma Function que **nunca existiu naquela
execução**.

Com `FUNCTIONS_DISCOVERY_TIMEOUT=120`:

```
+  functions: Loaded functions definitions from source: registrarDenuncia,
   bloquearJogador, desbloquearJogador, consultarContato, aplicarSancao,
   revogarSancao.
report tests=45 pass=45 fail=0 ... class=OK
```

**45/45.** As 16 falhas eram 100% ambiente — nenhum defeito de produto.

Nenhuma asserção foi alterada, nenhum piso baixou, nenhum pulo foi perdoado. O
que mudou foi a Function **existir**, para que a suíte pudesse ter veredito. E o
portão passou a diagnosticar o caso: `lerCargaDeCodebases` amarra cada
`Failed to load` ao codebase da linha `Watching` anterior e, quando é o codebase
sob teste, reprova como `IMPEDIDA` (exit 4) em vez de `FALHA` (exit 1) — mesma
reprovação, diagnóstico no lugar certo.

---

## 5. Os quatro pulos declarados de `regras-firestore`

Primeira execução: `regras-firestore: INCOMPLETA (105 casos)`. O rodapé dizia
`skipped 0`, e mesmo assim havia **quatro diretivas `# SKIP`** — o buraco que
`relatorio-testes.js` documenta: `describe` pulado inteiro não soma no contador.

Os quatro são **por projeto**: `emulador:integrado` sobe só o Firestore, então os
blocos que chamam Cloud Function saem `# SKIP` ali. Eles não ficam sem prova —
cada um é coberto por uma suíte de emulador que o próprio portão executa como
obrigatória:

| pulo | provado por |
|---|---|
| `registrarDenuncia` | `moderacao-emulador` |
| `bloqueio pela Function` | `moderacao-emulador` |
| `claimPioneerKit` | `colecoes-emulador` |
| `Functions sociais` | `social-emulador` |

A exceção é **nominal**, nunca por contagem: quatro pulos esperados e quatro
pulos diferentes dão o mesmo número. E um teste do portão exige que toda suíte
apontada como cobertura exista no catálogo **e seja obrigatória** — se alguma
deixasse de ser, os quatro pulos virariam buraco real e o teste quebraria.

---

## 6. Testes do próprio portão

```bash
cd ferramentas/portao-rc && node --test portao-rc.test.js
```

**66 casos, 66 passam.** Nenhum sobe emulador, chama Flutter ou toca a rede — a
regra "teste verde + cleanup vermelho reprova" precisa ser barata de provar,
senão não é provada.

Cobrem, entre outros: as cinco reprovações duras; a precedência dos códigos de
saída (inclusive que a ordem das suítes na lista não muda a classe do vermelho);
as cinco frentes de cleanup, independentes; a recusa de recibo antigo por commit,
por idade, por perfil parcial e por falta de hora de término; a atribuição de
falha de carga ao codebase certo; e a varredura da suíte Dart.

Dois defeitos reais do próprio portão foram pegos por esses testes durante o
desenvolvimento:

- a encenação de seeds era desmontada na ordem errada (`rmdir` antes de esvaziar
  a pasta), deixando árvore suja — que o próprio portão reprovaria;
- o recibo era gravado **antes** da re-decisão por conflito, então o arquivo podia
  dizer `PASS` enquanto a tela dizia `FAIL`. O documento é justamente o que
  sobrevive para ser lido depois.

---

## 7. Cobertura — o que esta RC não cobre

Declaradas no catálogo, com endereço, e visíveis em toda execução:

| frente | onde vive |
|---|---|
| `servidor` | repositório `buraco-servidor` (fora deste git) |
| `ranking` | branch `claude/player-account-deletion-flow-d04d45` |
| `economia` | branch `feat/economia-boas-vindas-vitorias` |

Não reprovam, porque o código não está neste commit — reprovar seria acusar esta
base de um buraco que ela não tem. Mas aparecem na seção `COBERTURA` de todo
relatório: **uma RC que não cobre o servidor precisa dizer que não cobre o
servidor.** `--exigir=<chave>` as promove a obrigatórias no dia em que a base
passar a contê-las.
