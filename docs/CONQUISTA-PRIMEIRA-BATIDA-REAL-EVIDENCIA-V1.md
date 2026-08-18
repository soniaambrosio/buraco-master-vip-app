# EVIDÊNCIA — Autoridade e concessão da `primeira_batida_real` V1

Veredito: **PASS**

- Branch: `claude/autoridade-conquista-primeira-batida-real-v1`
- Base: `origin/feat/economia-boas-vindas-vitorias` @ `42928c30aa0cf9d38aa7c74a84ca4897b22d14ab`
- Folha examinada: `origin/claude/buraco-c10-parte-2-5eb70e` @ `a600b4e22807cb9da1c5b5e982019d5c6a94cade` — **não integrada**, ver §4
- Contrato: `docs/CONQUISTA-PRIMEIRA-BATIDA-REAL-AUTORIDADE-V1.md`

---

## 1. Gate zero (OS §5)

```
$ git fetch --all --prune                                             exit 0
$ git status --porcelain                                              (vazio)

$ git ls-remote origin refs/heads/feat/economia-boas-vindas-vitorias
42928c30aa0cf9d38aa7c74a84ca4897b22d14ab
$ git rev-parse origin/feat/economia-boas-vindas-vitorias
42928c30aa0cf9d38aa7c74a84ca4897b22d14ab            IGUAIS

$ git ls-remote origin refs/heads/claude/buraco-c10-parte-2-5eb70e
a600b4e22807cb9da1c5b5e982019d5c6a94cade
$ git rev-parse origin/claude/buraco-c10-parte-2-5eb70e
a600b4e22807cb9da1c5b5e982019d5c6a94cade            IGUAIS

$ git checkout -b claude/autoridade-conquista-primeira-batida-real-v1 42928c30...
$ git rev-parse HEAD
42928c30aa0cf9d38aa7c74a84ca4897b22d14ab            HEAD inicial
```

O nome da branch estava livre local e remotamente — **não** foi preciso sufixo.

### Ancestralidade, provada e não presumida

```
$ git merge-base --is-ancestor a600b4e 42928c30   -> FALSO   (C10 NÃO é ancestral da base)
$ git merge-base --is-ancestor 42928c30 HEAD      -> VERDADEIRO
$ git merge-base a600b4e 42928c30                 -> 27b3f3679f7ee27584cfddeddbcd61e2e5fcce0d
$ git log --oneline 27b3f36..42928c30 | wc -l     -> 65   (a base avançou 65 commits)
$ git log --oneline 27b3f36..a600b4e  | wc -l     -> 66   (C10 avançou 66)
```

Duas linhagens que divergiram do mesmo ponto e nunca se reencontraram.

### A branch bloqueada continua intacta

```
$ git rev-parse claude/conquista-primeira-batida-real-v1-81af8a
300e14c59da9f5b3ac8876fd60f6602266b95e54
```

Não foi mesclada, não teve commit cherry-picked e **não foi publicada**.

## 2. Os cinco fatos (OS §5, bloqueio)

Todos prováveis — por isso a OS **não** parou em `BLOCKED`.

| Fato | Origem | Onde |
|---|---|---|
| partida encerrada autoritativamente | claim `motorDePartidas`/`admin` + `EstadoDaPartida` terminal + Rules negando escrita do cliente | `functions/src/rastreabilidade.ts:71` |
| dupla vencedora | `ladoVencedor` + `placar[].assentos`, cópia do desfecho | `registro_partida.dart` |
| **executor individual da batida** | `Jogo.assentoQueBateu` → desfecho → registro | **acrescentado nesta OS** |
| **batida legal** | implícita no anterior: `Jogo` só preenche o assento após `duplaPodeBater` | `mesa.dart:567` e `:901` |
| identidade autenticada | `ParticipantePartida.userId` com `classe == humano` | `registro_partida.dart` |

O ponto que fechou o gate: `assentoQueBateu` **já existia** no motor e estava
sendo descartado na captura do desfecho. Não foi preciso inventar fato nenhum,
nem inferir nada pelo cliente.

### Nenhum dado decisório vem do cliente (OS §5.7)

O cliente não tem caminho até `registrarEncerramentoPartida`: ela exige claim que
aparelho não tem. Tudo que decide vem de `matches/{matchId}`, que só a autoridade
escreve. O cliente só **lê** a própria conquista.

## 3. Arquivos alterados

| Arquivo | O quê |
|---|---|
| `app/lib/motor/desfecho_partida.dart` | `assentoQueBateuUltimaRodada` + validação de coerência + captura |
| `app/lib/rastreabilidade/registro_partida.dart` | `assentoQueBateuFinal` + cópia em `encerrarCom` + JSON |
| `app/lib/conquistas/primeira_batida_real.dart` | **novo** — a regra |
| `app/lib/torneios/js_bridge.dart` | entrada `avaliarPrimeiraBatidaReal` |
| `functions/src/domain.ts` | tipo e chamada da ponte |
| `functions/src/conquistas.ts` | **novo** — plano e gravação idempotente |
| `functions/src/rastreabilidade.ts` | concessão dentro da transação + log |
| `firebase/firestore.rules` | bloco `playerAchievements` |
| `app/test/conquistas/primeira_batida_real_test.dart` | **novo** — 36 casos |
| `app/test/conquistas/cadeia_autoritativa_test.dart` | **novo** — 16 casos |
| `firebase/testes/conquistas.test.js` | **novo** — 15 casos de Rules |
| `functions/test/conquista_idempotencia.test.js` | **novo** — 10 casos no emulador |
| `functions/package.json`, `firebase/testes/package.json` | alvos de teste |

**Não tocados:** Perfil, telas, `mesa.dart`, regras do Buraco, cálculo de
vitória, ranking, ligas, economia, Billing, moderação, `publicProfiles`, servidor.

## 4. C10 — exame e decisão (OS §6)

Não é ancestral (§1), então foi examinada. **Não contém a autoridade
necessária**, que é a condição da §6 para integrar:

```
$ git ls-tree -r --name-only a600b4e | grep -cE "^functions|rastreabilidade"
0
$ git diff --name-status 42928c30 a600b4e | grep -c "^D"
205        # arquivos que a BASE tem e C10 não
$ git diff --stat 42928c30 a600b4e | tail -1
321 files changed, 24164 insertions(+), 73334 deletions(-)
$ git diff --stat 42928c30 a600b4e -- app/lib/mesa.dart
1 file changed, 1285 insertions(+), 244 deletions(-)
```

C10 é a autoridade do motor **local**; partida local é exatamente o caminho que
nunca concede (`origem == local` → `partida_nao_autoritativa`). O fato que a
conquista consome do motor (`assentoQueBateu`) existe **nas duas** linhagens —
C10 inclusive o preserva em `autoridade_canonica.dart:485`.

Integrar significaria escolher entre duas linhagens de motor, arquivo a arquivo,
em `mesa.dart` com +1285/−244, **sem mudar uma linha do que esta OS entrega**.
Registrado como decisão em `...AUTORIDADE-V1.md` §9. Nenhum merge foi feito.

## 5. Testes

### Dart — `app/`

| Comando | Resultado | Exit |
|---|---|---|
| `flutter test` | **665** passaram (base: 613 · **+52**) | **0** |
| `flutter test test/teste_encerramento.dart` | **10** | **0** |
| `flutter test test/teste_motor.dart` | **132** | **0** |
| `flutter test test/teste_motor_resiliencia.dart` | **196** | **0** |
| `flutter analyze` | 42 issues · **0 erros** · 13 warnings | 1 (só `info`) |

**1003 testes Dart verdes.** O analyze é **idêntico** à baseline da base
intocada — zero erro novo, zero warning novo, zero info novo.

Os três `teste_*.dart` ficam fora do glob padrão do `flutter test` (prefixo
`teste_`) e por isso são invocados com alvo explícito, como o CI faz.

### Emulador do Firestore

| Comando | Resultado | Exit |
|---|---|---|
| `npm run test:conquistas` (Rules) | **15** passaram | **0** |
| `npm run test:integrado` (6 suítes de Rules) | **120** passaram | **0** |
| `functions: npm run test:conquistas` (idempotência) | **10** passaram | **0** |

O `test:integrado` é o que importa para não-regressão de segurança: as seis
suítes provam blocos do **mesmo** `firestore.rules`, que é onde um bloco novo
poderia afrouxar o do vizinho.

### Outros codebases de Functions

| Codebase | Resultado |
|---|---|
| `functions-economia` | **63** passaram · 0 falhas |
| `functions-billing` | **103** passaram · 0 falhas |
| `functions-moderacao` | **13** passaram · 0 falhas |
| `functions` (torneios) | `tsc --noEmit` **exit 0** |

**Total: 1312 testes verdes**, 0 falhas, 0 pulados.

### Cobertura da OS §13

**Elegibilidade (14 itens):** todos cobertos em
`app/test/conquistas/primeira_batida_real_test.dart`, um teste por afirmação,
mais os casos de envelope incoerente. E cobertos **de novo** ponta a ponta em
`cadeia_autoritativa_test.dart`, partindo do motor real.

**Idempotência (6 itens):** `functions/test/conquista_idempotencia.test.js`,
contra o emulador, dentro de transações de verdade. O caso 4 dispara **oito
transações simultâneas** sobre o mesmo documento inexistente e exige que
exatamente **uma** devolva `concedida`.

**Segurança (7 itens):** `firebase/testes/conquistas.test.js`.

### O que os testes provam sobre o motor

`cadeia_autoritativa_test.dart` joga partidas inteiras de robô até uma terminar
em batida e então afirma, sobre o estado real do motor: o assento está
preenchido, pertence à dupla que bateu, e `duplaPodeBater` era verdadeiro. Também
prova que rodada terminada sem batida deixa o assento nulo e que rodada nova zera
o assento da anterior — sem o que uma batida intermediária seria lida, no fim da
partida, como se fosse a final.

## 6. Reprodução

```bash
cd app && flutter pub get && flutter test
```

```bash
cd functions && npm install && npm run build:domain && npm run build && npm run lint
```

```bash
cd firebase && npx firebase emulators:exec --only firestore "cd testes && npm run test:integrado"
```

```bash
npx firebase emulators:exec --only firestore --project bmv-conquistas-teste "cd functions && npm run test:conquistas"
```

**Duas condições de ambiente,** nenhuma delas alterada por esta OS:

1. **Java não está no PATH.** O emulador roda com o JBR do Android Studio
   (JDK 21): `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"`.
2. **Quatro suítes Flutter precisam das seeds** copiadas para
   `app/test/torneios/data/` e `app/test/colecoes/data/`, como o CI faz. Sem
   isso, elas falham ao carregar — e não é regressão. As cópias **não** foram
   versionadas.

`app/test/colecoes/evidencias/*.png` são **regeradas** por
`evidencias_visuais_test.dart` a cada execução. Foram revertidas antes de cada
commit; não fazem parte desta entrega.

## 7. Superfície de deploy — defeito encontrado e corrigido

`src/index.ts` faz `export * from "./rastreabilidade"`, e o Firebase trata cada
export do entrypoint como definição de função a implantar. As duas funções
auxiliares exportadas para o teste de idempotência tinham levado a superfície de
**11 para 13** — um deploy tentaria publicar `planejarPrimeiraBatidaReal` como se
fosse um gatilho.

Corrigido em `ef0725c`: as duas mudaram para `src/conquistas.ts`, que nada
reexporta. Conferido por smoke test do entrypoint compilado:

```
$ GCLOUD_PROJECT=smoke node -e "console.log(Object.keys(require('./lib/index.js')).length)"
11        # as mesmas 11 da base
```

## 8. Fronteiras (OS §14)

- Perfil **não** alterado; mock **não** removido; "Última Conquista" **não**
  implementada; catálogo visual **não** criado — tudo é a OS seguinte;
- splash, Home, Loja, ranking e Hall intocados;
- Billing intocado;
- **sem deploy, sem AAB/APK, sem Firebase Console, sem Play Console**;
- `main` intocada; nenhuma RC composta;
- a branch bloqueada anterior **não** foi publicada;
- nenhum merge em ref existente, nenhum rebase, nenhum force-push;
- escopo limitado a **uma** conquista.

## 9. Bloqueadores remanescentes

Nenhum bloqueia esta entrega. Todos são da integração seguinte ou de operação.

1. **O produtor do envelope precisa passar a enviar `assentoQueBateuFinal`.**
   O plano de encerramento chega de **fora deste repositório** — do servidor
   Node/Railway. Enquanto ele não incluir o campo, toda avaliação recusa com
   `sem_batida_final_conhecida`: corretamente, e sem conceder nada errado. **É o
   item que mais importa para a conquista ter efeito em produção**, e é trabalho
   no outro repositório.
2. **Nada retroativo.** Ninguém tem a conquista hoje. Ela passa a ser concedida
   nos encerramentos daqui para frente — e em reenvios de encerramentos passados,
   se o envelope trouxer o assento.
3. **`UltimaConquista` e `Conquista` não têm `obtidaEm`** na linhagem do Perfil.
   Sem esse campo, "a mais recente por timestamp do servidor" não é expressável.
4. **O Perfil exibe "Primeira Batida Real" como mock** para todo mundo. Trocar é
   da OS seguinte, junto com ligar a fonte.
5. **Sem deploy.** Rules e Functions estão no repositório, não em produção.
6. **`privada` conta para a conquista** — decisão registrada em
   `...AUTORIDADE-V1.md` §3, aberta a revisão da proprietária.

## 10. Veredito

```
PASS
```

A autoridade real produz os cinco fatos; nenhum fato decisório é confiado ao
cliente; só o executor individual elegível recebe; a concessão é exatamente uma,
provada sob concorrência; as Rules bloqueiam escrita direta; elegibilidade,
concorrência e segurança estão verdes; não há regressão em nenhum módulo tocado.
