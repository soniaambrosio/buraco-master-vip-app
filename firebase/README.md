# Firebase — Kit Pioneiros 2026

Camada segura da coleção. **Nada aqui foi implantado.** Os arquivos estão
versionados e prontos; a publicação em produção é uma decisão da Sônia e exige
credenciais do projeto, que esta entrega não usou.

## O que tem nesta pasta

| Arquivo | Papel |
| --- | --- |
| `firestore.rules` | Regras de acesso. O cliente nunca escreve inventário, comprovante ou elegibilidade. |
| `firestore.indexes.json` | Três índices: inventário por coleção, itens equipados e auditoria de resgates. |
| `functions/index.js` | `claimPioneerKit`, `grantPioneerEligibility` e `revokePioneerKit`. |
| `scripts/seed_pioneiros_2026.js` | Publica catálogo e campanha lendo `app/data/colecoes/`. Idempotente. |
| `firebase.json` | Amarra regras, índices, funções e emuladores. |

## Modelo de dados

```
config/featureFlags                      { kitPioneiros2026Enabled: false }
campaigns/pioneiros_2026                 espelho de campanha_pioneiros_2026.seed.json
campaigns/pioneiros_2026/eligible/{uid}  evidências; só admin escreve
collections/pioneiros_2026               metadados da coleção
collections/pioneiros_2026/items/{itemId}
users/{uid}/inventory/{itemId}           id determinístico = itemId
users/{uid}/campaign_claims/{campaignId} comprovante, id determinístico
audit/{auto}                             trilha de ação administrativa
```

Os dois ids determinísticos são o que sustenta a idempotência: uma segunda
gravação colide no mesmo documento em vez de criar outro. Isso vale mesmo se o
aplicativo for reinstalado, o aparelho trocado ou a chamada repetida por timeout.

## Ordem de implantação

O passo 1 é o mais importante: publicar as regras **depois** de já existir dado
gravável deixaria uma janela em que o cliente poderia escrever no próprio
inventário.

```bash
cd firebase
firebase deploy --only firestore:rules --project <id>
```

```bash
cd firebase
firebase deploy --only firestore:indexes --project <id>
```

```bash
cd firebase/functions && npm install
firebase deploy --only functions --project <id>
```

Ensaio do seed (não grava nada):

```bash
node firebase/scripts/seed_pioneiros_2026.js --project <id>
```

Gravação do seed, depois de conferir o ensaio:

```bash
node firebase/scripts/seed_pioneiros_2026.js --project <id> --commit
```

## Ativar a campanha

O seed publica a campanha em `status: draft`, visibilidade `hidden` e com a
feature flag **desligada**. Nenhuma dessas três coisas muda por deploy: a
ativação é feita editando os documentos, sem novo build do aplicativo.

1. `config/featureFlags` → `kitPioneiros2026Enabled: true`
2. `campaigns/pioneiros_2026` → `status: "active"`
3. Definir `eligibilityMode` (`allowlist`, `closedTest`, `matchInWindow`,
   `hybrid` ou `adminGrant`) e, se houver, `startAt` / `endAt` / `claimDeadline`
   em ISO-8601 **com sufixo `Z`**.
4. Popular `campaigns/pioneiros_2026/eligible/{uid}` com a evidência
   correspondente.

Para desligar tudo em uma ação, basta voltar a flag para `false`: ela vence
status, janela e evidência.

## Administração

`grantPioneerEligibility` marca um UID como elegível caso a caso — **não**
concede o kit. O jogador continua resgatando pelo fluxo normal, o que mantém uma
única porta de escrita de inventário. Exige custom claim `admin: true` e grava
auditoria.

`revokePioneerKit` existe apenas como ferramenta de correção. Exige
`confirmar: true` e `motivo`, remove itens e comprovante numa transação e deixa
trilha em `audit/`. Não faz parte do fluxo comum.

O custom claim é atribuído fora do aplicativo:

```bash
firebase auth:import --help
```

## Testes

Dois portões, e eles provam coisas diferentes. Confundir um com o outro é o que
deixou `claimPioneerKit` sem nenhuma execução real desde a entrega original.

| Comando | O que prova |
| --- | --- |
| `npm run test:colecoes` | Só as **regras**. O bloco `claimPioneerKit` fica pulado de propósito. |
| `npm run emulador:colecoes` | Regras **e** chamadas reais a `claimPioneerKit`, contra Firestore + Auth + Functions. |
| `npm run emulador:moderacao` | Regras **e** chamadas reais às Functions de moderação. |
| `npm run emulador:social` | Regras **e** chamadas reais às Functions sociais. |
| `npm run test:runner` | A lógica do próprio portão. Não sobe emulador e não precisa de Java. |

Todos rodam de `firebase/testes` (depois de `npm install` lá).

### Quais deles o CI executa

`.github/workflows/ci-os-integracao.yml` protege as **três** suítes Firebase com
Emulator Suite, em passos próprios, sequenciais e bloqueantes:

| Passo | Suíte | Gate | O que o CI chama |
| --- | --- | --- | --- |
| 3d | **Social** | `socialemu` | `emulators:exec … npm run test:social:functions` |
| 3e | **Moderação** | `moderacaoemu` | `npm run emulador:moderacao` (o wrapper) |
| 3f | **Coleções** | `colecoesemu` | `emulators:exec … npm test` |

Moderação passa pelo wrapper porque ele é autocontido e classifica o desfecho:
qualquer exit diferente de zero — falha funcional (1), infraestrutura (3/4),
suíte incompleta (5), cleanup incompleto (6) — reprova o job. Nenhum dos três usa
`continue-on-error`.

Os três são **fail-closed**: para o portão ficar verde, cada um precisa ter
deixado um recibo que exista, não esteja vazio, contenha um exit code e esse
código seja `0`. Gate pulado, recibo ausente, vazio ou com conteúdo que não é um
exit code reprovam do mesmo jeito que um teste quebrado — ausência de evidência de
sucesso não é sucesso. Num job **cancelado** o portão é pulado, e o job sai
cancelado em vez de vermelho.

Sequenciais de propósito: paralelizá-los no mesmo host colocaria três execuções
disputando as mesmas portas e o mesmo `projectId`.

### Os três alvos de emulador são autocontidos

`npm run emulador:social` **faz o próprio build**. Não é mais necessário rodar
`npm run build:domain && npm run build` em `functions-social/` antes — o alvo
instala as dependências, compila o domínio Dart, compila o TypeScript e só então
sobe o emulador. O mesmo vale para `moderacao`; `colecoes` só instala, porque seu
`package.json` declara `main: index.js` e o emulador carrega o arquivo da árvore,
sem bundle que possa envelhecer.

Isso conserta um defeito concreto: com `functions-social/lib/` ausente, o alvo
subia assim mesmo, a Function respondia `functions/not-found` e **60+ casos eram
cancelados** — com o build manual escondido num pré-requisito de documentação que
ninguém era obrigado a ler.

Os três passam por `runner-emulador.js`, que faz, nesta ordem:

```text
java? → preparo/build → artefatos existem? → TRAVA → portas livres?
      → emulators:exec → confere o recibo → cleanup (sempre)
```

### Exclusividade: um Emulator Suite por vez

Os três alvos compartilham **as mesmas portas** (8080, 5001, 9099, 4000, 4400,
4500, 9299, 9499), o **mesmo `projectId` `demo-bmv`** e a **mesma trava**. Não
são alternativas independentes: são usuários de um recurso exclusivo. Duas
execuções sobrepostas não se revezam — sobem pela metade, e o estrago aparece
como *resultado de teste* (`assertFails` passando pelo motivo errado, dezenas de
casos cancelados), e não como erro de ambiente.

Quando outro runner já está ativo, o segundo **espera até 90 s** e depois falha
com `exit 3`, dizendo qual alvo e qual PID está segurando:

```text
[emulator-runner] target=moderacao class=INFRAESTRUTURA environment=busy reason=execucao concorrente
  alvo   social
  pid    2316
  desde  2026-08-12T18:05:00.244Z
```

`BMV_EMULADOR_ESPERA_MS=0` troca a espera por fail-fast; qualquer outro valor
ajusta o limite. **Não existe espera infinita** — estourado o limite, o runner
sai diferente de zero sem ter executado teste nenhum.

A trava guarda o PID e é validada a cada tentativa: uma execução encerrada a
Ctrl+C **não bloqueia o projeto**, porque uma trava cujo dono não responde é
tratada como obsoleta e substituída.

### A janela de drain (descoberta nesta OS)

No Windows, **`firebase emulators:exec` devolve o terminal antes de os processos
Java/Firebase soltarem as portas**. Medido nesta árvore: com o exec já retornado
e o exit code na mão, as sete portas continuaram escutando por alguns segundos —
e uma execução iniciada nesse intervalo encontra `Port 8080 is not open` mesmo
tendo checado as portas um instante antes.

Portanto, **checar as portas apenas antes da execução não basta**. O runner
mantém a trava até as portas terem realmente drenado, com espera limitada a 30 s
(`BMV_EMULADOR_DRENO_MS` ajusta):

```text
[emulator-runner] cleanup=ok ports=released
```

**Se o dreno estourar o limite, a execução é reprovada** — `class=CLEANUP-INCOMPLETO`,
`exit 6`, com as portas presas nomeadas. Uma execução que termina prendendo
recurso não é portão verde: ela acabou de sabotar a próxima. O resultado da suíte
continua no relatório, e o rótulo diz exatamente o que aconteceu:

```text
[emulator-runner] cleanup=FAIL ports=ui:4000 (ainda escutando apos 3s)
[emulator-runner] target=colecoes class=CLEANUP-INCOMPLETO tests=pass cleanup=fail
OS TESTES PASSARAM: a suite subiu, rodou inteira e nao teve falha, pulo
  nem cancelamento (tests=20 pass=20 fail=0 ...).
  O que falhou foi o ENCERRAMENTO.
```

A trava **cai** mesmo assim, e de propósito: uma trava sem dono vivo bloquearia o
projeto sem proteger nada — quem protege é o teste de bind que a próxima execução
faz. O que não pode acontecer é a liberação ser lida como "ambiente saudável", e
por isso ela é anunciada junto com o estrago.

Esse ramo é o **último** da classificação e só age sobre o que já seria verde:
uma asserção quebrada continua sendo `FALHA-FUNCIONAL`, e uma suíte encurtada
continua sendo `SUITE-INCOMPLETA`. O dreno só transforma verde em vermelho, nunca
esconde um vermelho que já existia.

### O portão distingue três desfechos

Quem lê um vermelho pergunta antes de tudo "é defeito meu ou da máquina?". Um
rótulo único obriga a ler o log inteiro para descobrir, então cada classe tem
rótulo e faixa de saída próprios:

| `class=` | exit | Significa |
| --- | ---: | --- |
| `OK` | 0 | Subiu, rodou **inteira** e passou. |
| `FALHA-FUNCIONAL` | 1 | Subiu, rodou inteira, e uma asserção falhou. Único caso em que o vermelho fala do código. |
| `INFRAESTRUTURA` | 3, 4 | Ambiente ocupado, build falhou, Java ausente, ou a suíte **não chegou a rodar**. Nenhum teste executou. |
| `SUITE-INCOMPLETA` | 5 | Subiu e rodou, mas **não inteira**: pulou, cancelou, encolheu ou não deixou recibo. |
| `CLEANUP-INCOMPLETO` | 6 | A suíte passou, mas a execução terminou com porta presa. Não é verde. |
| `INDETERMINADA` | *n* | Relatório íntegro e mesmo assim exit ≠ 0. Repassa o código. |

**Cancelamento vence falha.** Um caso cancelado não produziu veredito nenhum, e
uma execução com casos cancelados não é um veredito funcional — é uma execução
que não terminou. A falha real continua impressa e o exit continua diferente de
zero; o que o runner se recusa a fazer é chamar de "suíte executada" uma suíte
interrompida. Sem essa precedência, a linha de base desta OS (bundle ausente →
`not-found` no pai → 60+ filhos cancelados) sairia rotulada como defeito de
código.

### Nenhum teste parcial é considerado válido

Exit code 0 do `node --test` responde "nada falhou", e **não** "tudo rodou". Três
desfechos medidos aqui saem com código 0 sem ter provado nada, e o portão barra
os três:

1. **`describe` pulado inteiro.** Não soma em contador nenhum — nem em `tests`,
   nem em `skipped`. Falsificado nesta OS: `node --test` saiu **0**, com rodapé
   `fail 0, cancelled 0, skipped 0`, e ainda assim 33 casos tinham sumido
   (`tests 34`, e o piso é 67). Quem denuncia é a diretiva `# SKIP` na linha e o
   **piso** `--esperado=N`.
2. **Suíte encurtada.** Um arquivo que sai do alvo derruba o total sem derrubar
   o exit code. O piso é a rede.
3. **Cancelamento.** Marcado na linha (`was cancelled`) e no rodapé; as duas
   frentes são lidas, porque quando o processo morre no meio só a primeira chega
   a existir.

E há o **recibo**: `com-functions.js` escreve o relatório interpretado num
arquivo, sempre — inclusive quando a suíte falha. É como o resultado atravessa a
fronteira do `emulators:exec`, onde só passaria um exit code. Um `exec` que saia
0 sem recibo é um verde que ninguém provou, e o runner não o entrega.

### Armadilha de ambiente que sobrou

- **Java.** O emulador do Firestore precisa de `java` resolvível no `PATH`;
  `JAVA_HOME` sozinho não basta. O runner **confere antes de compilar** e diz
  onde achar o JDK, em vez de deixar o `emulators:exec` morrer depois do build
  com uma mensagem que não ajuda. Com o Android Studio instalado:
  `$env:PATH = "C:\Program Files\Android\Android Studio\jbr\bin;$env:PATH"`.

O ruído de carga dos outros codebases (`functions-billing`, `functions`,
`functions-moderacao`, `functions-social` reclamando de `lib/index.js` ausente)
é esperado: o Firebase CLI inspeciona todos mesmo com `--only
functions:colecoes`. Não impede `colecoes` de subir, e o comando sai com zero.

## Aviso sobre o escopo das regras

No Firestore, **caminho não declarado é caminho negado**. `firestore.rules` cobre
somente as coleções do Kit Pioneiros. Quando `usuarios/`, `partidas/`, `amigos/`
e as demais entrarem no ar, precisam ser acrescentadas ao mesmo arquivo — senão
o aplicativo perde acesso a elas no dia do deploy.

Hoje isso não é um problema: o aplicativo usa apenas Firebase Auth e ainda não
tem `cloud_firestore` nas dependências (ver `.github/workflows/build.yml`).
Adicionar o pacote é pré-requisito para ligar a campanha e está listado como
pendência no relatório.
