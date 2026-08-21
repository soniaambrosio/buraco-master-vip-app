# OS 12.1-C1 — sobrevivência fail-closed do gate `torneiosa11y`

Correção **exclusiva da proteção de CI** da entrega OS 12.1. A correção
semântica permanece como foi aprovada: `app/lib` não foi tocado, nenhum
retângulo mudou, o estouro reservado à OS 12.2 continua onde a OS 12 o mediu.

- Base congelada: `claude/torneios-mock-admin-cleanup-b0e388` @ `c65a61b724fdceb3661bc26e3fb6b1b4e11f525e`
- Folha da OS 12.1: `claude/a11y-torneios-p0-semantico-v1-3b34db` @ `c8971e741ae02451135d6e8b9edbe3d515896170`
- Esta correção: `correcao/os12-1-c1-torneiosa11y-fail-closed-v1`, 1 commit sobre `c8971e7`
- 2 arquivos, +333/−6. **Zero** em `app/lib`.

---

## 1. O defeito, medido antes de qualquer edição

`roda()` escreve `nao_<chave>` quando o **arquivo** não existe, e o veredito
tratava `nao_<chave>` como neutro — "NÃO EXECUTADO", sem somar no `fail`.

Isso é deliberado para a maior parte da lista: alvos de emulador e de Node
dependem de serviço externo, e um passo que nem chegou a rodar não é evidência
de regressão do código. Só que o mesmo tratamento fazia de **apagar a suíte** a
maneira mais barata de voltar ao verde — a única forma de "consertar" um portão
vermelho sem consertar nada.

Os falsos-verdes foram **reproduzidos por execução** sobre `c8971e7`, antes de
qualquer edição, numa bancada que extrai os três blocos de shell do próprio
YAML por parse (não por leitura) e os executa como o Actions os executaria:

| cenário | `c8971e7` (antes) |
|---|---|
| suíte presente e verde | VERDE `exit 0` — controle |
| suíte presente e **vermelha** | VERMELHO `exit 1` — controle negativo |
| suíte **apagada** | **VERDE `exit 0`** |
| suíte **renomeada** | **VERDE `exit 0`** |
| linha produtora removida | **VERDE `exit 0`** |
| chave fora das duas listas | **VERDE `exit 0`** |
| registro **e** produtor removidos | **VERDE `exit 0`** |
| passo não chegou a rodar | **VERDE `exit 0`** |
| `NÃO EXECUTADO` falsificado | **VERDE `exit 0`** |
| marcador removido | **VERDE `exit 0`** |
| chave fora do laço do agregador | **VERDE `exit 0`** |

Nove caminhos distintos levavam "não executado" a verde.

---

## 2. A forma da correção: uma declaração, dois consumidores

A obrigatoriedade mora no **`env:` do job**, e em nenhum outro lugar:

```yaml
jobs:
  validar:
    runs-on: ubuntu-latest
    env:
      GATES_OBRIGATORIOS: torneiosa11y
```

**Por que ali, e não numa variável de shell.** Cada passo do Actions é um shell
próprio, então uma variável de shell teria de ser digitada duas vezes — no passo
de evidência e no do veredito — e duas cópias digitadas divergem. O `env:` do
job é entregue a **todos** os passos, inclusive aos `if: always()`. É UMA
declaração, lida por todos os consumidores, sem lista nova no YAML e sem arquivo
novo. Nenhuma lista foi duplicada, e nenhuma família de gate foi criada.

Sobre ela, quatro mudanças:

1. **`exige()`**, irmã de `roda()` com uma diferença: ausência do arquivo é
   FALHA (`exit_<chave>=1`), e não `nao_<chave>`. `torneiosa11y` passou a usá-la.
   `roda` continua existindo e continua correto para todo o resto — `NÃO
   EXECUTADO` é reservado a ausência real de artefato, e há branches legítimas
   sem as suítes novas.
2. **O veredito** trata `nao_<chave>` e marcador ausente como FALHA para toda
   chave declarada, e **reprova de saída** se `GATES_OBRIGATORIOS` estiver
   ausente ou vazio: um portão que não protege nada não pode sair verde
   fingindo que protegeu.
3. **A conferência de percurso.** Declarar uma chave obrigatória não vale nada
   se ela puder sair do laço em silêncio. O laço **acumula** o que percorreu em
   `PERCORRIDOS`, e é o acumulado — e não uma segunda cópia digitada — que a
   conferência lê no fim.
4. **A evidência** lê a mesma fonte. Sem isso ela marcaria "NÃO EXECUTADO"
   (neutro) para o gate que acabou de deixar o portão vermelho, e quem lesse o
   relatório procuraria a causa no lugar errado.

**A lista percorrida continua LITERAL na linha do `for`.** Isto é deliberado:
há auditoria neste repositório que casa a chave DENTRO da própria linha do laço,
e mover a lista para uma variável derruba essa auditoria sem que nada de errado
tenha acontecido. Acumular dentro do laço dá a mesma garantia sem esse custo.

### A metade de dentro

A metade de fora não cobre o **rebaixamento com a suíte intacta**: trocar
`exige` por `roda`, ou tirar `torneiosa11y` da declaração. Nesses casos nada
fica vermelho no dia da mudança — o estrago só aparece quando alguém apagar a
suíte, e aí não há mais nada de pé para reclamar. Quem precisa reclamar é algo
que **roda**, e o único lugar que roda e é obrigatório é a própria suíte.

Por isso o §7 novo de `app/test/torneios/a11y_p0_semantico_test.dart` (10
provas) lê os dois workflows e afirma a declaração, o produtor, o helper, as
duas listas, o consumo da fonte única, a checagem de vazio, a conferência de
percurso e o portão irmão do `build.yml`. Pôr a guarda **dentro** da suíte já
obrigatória é o que termina a regressão de "quem guarda o guarda".

As afirmações são de **linha ancorada** (`^\s*chave:`), e não de substring: uma
linha de comentário do YAML começa em `#` e por construção não pode satisfazê-las.
Isso importa porque este workflow explica em comentário tudo o que faz,
inclusive as chaves que cita.

---

## 3. Provas negativas

### 3.1 O agregador — 14 cenários, mesma bancada da §1

| cenário | `c8971e7` | agora |
|---|---|---|
| suíte presente e verde | VERDE | **VERDE** |
| suíte presente e vermelha | VERMELHO | **VERMELHO** |
| suíte apagada | VERDE | **VERMELHO** |
| suíte renomeada | VERDE | **VERMELHO** |
| produtor removido | VERDE | **VERMELHO** |
| registro removido das duas listas | VERDE | **VERMELHO** |
| registro **e** produtor removidos | VERDE | **VERMELHO** |
| passo não chegou a rodar | VERDE | **VERMELHO** |
| `NÃO EXECUTADO` falsificado | VERDE | **VERMELHO** |
| marcador removido | VERDE | **VERMELHO** |
| chave fora do laço do agregador | VERDE | **VERMELHO** |
| `exige` rebaixado a `roda` (+ suíte apagada) | — | **VERMELHO** |
| chave fora da fonte única (+ suíte apagada) | — | **VERMELHO** |
| fonte única removida do `env:` | — | **VERMELHO** |
| rebaixamento total: `roda` + declaração esvaziada + suíte apagada | — | **VERMELHO** |
| declaração **substituída** por outra chave + `roda` + suíte apagada | — | VERDE — ver §6.3 |
| suíte presente mas **esvaziada** (conteúdo trivial) | VERDE | VERDE — ver §6.2 |

O caminho verde continua verde: o endurecimento não reprova quem não deve.

### 3.2 A guarda de dentro — 17 mutações, 17 detectadas

Cada mutação foi injetada **sozinha** nos workflows reais, com a suíte rodada em
seguida e os workflows restaurados antes da próxima.

| # | mutação | resultado |
|---|---|---|
| M01 | linha produtora removida | DETECTADA |
| M02 | `exige` rebaixado a `roda` | DETECTADA |
| M03 | chave fora de `GATES_OBRIGATORIOS` | DETECTADA |
| M04 | `env:` do job removido | DETECTADA |
| M05 | declaração duplicada | DETECTADA |
| M05c | `env:` de passo sobrescreve o do job com `""` | DETECTADA |
| M06 | lista de obrigatórios redigitada num shell | DETECTADA |
| M07 | chave fora do laço do veredito | DETECTADA |
| M08 | chave fora da lista de evidência | DETECTADA |
| M09 | `exige` escreve `nao_` em vez de `exit` | DETECTADA |
| M10 | veredito sem a checagem de declaração vazia | DETECTADA |
| M11 | veredito sem a conferência de percurso | DETECTADA |
| M12 | veredito não acumula `PERCORRIDOS` | DETECTADA |
| M13 | veredito consulta literal no lugar da fonte única | DETECTADA |
| M14 | `build.yml` sem o portão de acessibilidade | DETECTADA |
| M15 | `build.yml` não executa mais a suíte | DETECTADA |
| M16 | workflow esvaziado (árvore vazia) | DETECTADA — 8 provas |

**Uma mutação mediu o instrumento e foi refeita.** A primeira versão de M05
injetava `GATES_OBRIGATORIOS_2:` — uma chave de nome diferente, que consumidor
nenhum lê. Ela "sobreviveu" porque não era um defeito: é YAML morto. Trocada
pelas duas que importam — a duplicata verdadeira da mesma chave (M05) e o `env:`
de passo, que tem precedência e esvazia a declaração exatamente onde ela seria
lida (M05c). As duas ficam vermelhas.

---

## 4. Gates executados

| gate | alvo | resultado |
|---|---|---|
| `torneiosa11y` | `test/torneios/a11y_p0_semantico_test.dart` | **29/29** (19 da OS 12.1 + 10 novos) |
| `torneiosmk` | `test/torneios/saneamento_mock_admin_test.dart` | **26/26** |
| `mtorneios` | `test/torneios/motor_torneios_test.dart` | **179/179** |
| `torneios` | `test/torneios/reward_grants_test.dart` | **80/80** |
| `casca` + `cascaaud` | `test/casca` (portão do `build.yml`) | **244/244** |
| `analyze` | `flutter analyze --no-fatal-infos --no-fatal-warnings lib test` | **exit 0** |

`flutter analyze` devolve **40 issues, todas `info`, em `c8971e7` e agora** — e
os conjuntos são idênticos linha a linha após normalizar linha e coluna. As 219
linhas acrescentadas à suíte não introduziram nenhum achado novo.

`test/casca` inclui `auditoria_casca_test.dart`, que é a suíte que refatorações
do veredito costumam derrubar. Ela passa: a lista literal do `for` foi
preservada de propósito.

---

## 5. O que NÃO mudou

Conferido por parse de YAML, e não por leitura:

```
ci-os-integracao.yml   push:[integracao/os-final-backend-flutter] + workflow_dispatch
                       permissions {contents: write}
                       jobs=validar   runs-on=ubuntu-latest   passos=20
```

Gatilhos, permissões, jobs e contagem de passos idênticos antes e depois.
Mudaram apenas corpos de `run:`, um nome de passo, e o `env:` novo do job.
`build.yml` e `web.yml` não foram tocados.

Preservado e conferido por execução: os dois `IconButton` com `semanticLabel`,
o `Switch` sob `MergeSemantics`, nomes, papéis, estados e callbacks, os
retângulos, o estouro reservado à OS 12.2 (a suíte o afirma **por valor** e fica
vermelha se alguém o corrigir aqui), a ausência de mock, de `mostrarAdmin`, de
claim administrativo e de rota produtiva.

Nada de Functions, Rules ou servidor. Nenhuma permissão de CI foi ampliada.

---

## 6. Folgas que ficam registradas, e não são desta OS

1. **`torneiosmk` continua NÃO obrigatório**, e continua fora da lista da
   evidência. Apagar `saneamento_mock_admin_test.dart` ainda deixa o agregador
   verde. É o mesmo defeito, na suíte da OS anterior; fechá-lo é decisão de quem
   arbitra aquela entrega, e a mudança é uma palavra na declaração.

2. **Conteúdo de suíte não é protegido.** A suíte presente mas esvaziada —
   arquivo no lugar, conteúdo trivial que passa — deixa o portão **VERDE**,
   medido na bancada. `exige` responde "o arquivo existe e o comando passou", e
   é tudo o que ele sabe perguntar. O contador cai visivelmente e gate nenhum o
   lê. É buraco **do chassi**, presente também na base; o remédio (sha256 +
   piso de casos + blocos normativos) vive noutra linhagem e não existe nesta
   árvore.

3. **A folga que resta, medida — e ela é menor do que parece.** Esvaziar a
   declaração **não** abre caminho: `GATES_OBRIGATORIOS` vazio derruba o portão
   pela checagem da §2.2. O caminho mínimo que ainda chega ao verde exige
   **substituir** a declaração por outra chave, rebaixar `exige` para `roda` e
   apagar a suíte — três edições deliberadas no mesmo arquivo, e mesmo assim o
   portão do `build.yml` continua vermelho e continua bloqueando o APK, o que
   pede uma quarta edição num segundo workflow.

   Remoção parcial sempre acende: apagar a suíte acende `exige`; rebaixar a
   declaração acende a guarda de dentro; apagar a guarda de dentro é apagar a
   suíte, que acende `exige` e o portão do `build.yml`. Proteção absoluta não
   existe, e não adianta fingir que sim.

---

## 7. Estado

Árvore limpa, `local == remoto`, sem `--force`, sem PR, sem merge, sem deploy.
A OS 12.2 permanece bloqueada até a rehomologação independente desta correção.
