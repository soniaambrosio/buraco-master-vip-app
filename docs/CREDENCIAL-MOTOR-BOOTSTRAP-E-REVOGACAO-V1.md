# Credencial do Motor: bootstrap e revogação efetiva — V1

Duas entregas que se completam:

1. **Bootstrap** — o operador troca **uma vez** uma credencial administrativa por
   um **refresh token**, que vira segredo do Railway. Fecha o passo 7 da ativação
   do provisionador (§9 de [PROVISIONAMENTO-CLAIM-MOTOR-PARTIDAS-V1.md](PROVISIONAMENTO-CLAIM-MOTOR-PARTIDAS-V1.md)).
2. **Revogação efetiva** — o receptor passa a **recusar token de sessão
   revogada**, em produção e não só no emulador. Fecha o risco residual §11.5 da
   mesma OS.

> **PASS — O MOTOR TEM CREDENCIAL RENOVÁVEL SEM CHAVE, E O RECEPTOR RECUSA TOKEN REVOGADO**
> **ATIVAÇÃO OPERACIONAL NÃO EXECUTADA**
>
> Nenhum usuário técnico foi criado, nenhum claim concedido, nenhum token
> emitido, nenhuma variável do Railway populada, nenhum deploy. Esta entrega é
> **infraestrutura de credencial**: ela ainda **não** envia a outbox nem traduz o
> envelope da partida.

| | |
|---|---|
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Branch | `correcao/credencial-motor-contrato-runbook-v2` |
| Base | `homologacao/credencial-renovavel-motor-revogacao-v1` |
| SHA da base | `a6b6b5bd84986d9fddfd59410e50938434ae6583` |
| Metade do servidor | `soniaambrosio/buraco-servidor`, branch `correcao/credencial-motor-secure-token-v2` |

> **V2 — corrigida depois da homologação independente.** Ela reprovou por dois
> motivos: o módulo do servidor comparava `project_id` da resposta do Secure Token
> com o `FIREBASE_PROJECT_ID` — campo que é o *project number*, e nunca o id
> textual —, e o runbook estava em 9 de 12. A comparação foi **removida** (ver
> `docs/CREDENCIAL-RENOVAVEL-MOTOR-V1.md` no repositório do servidor), o preflight
> do destino do bootstrap foi endurecido, e o runbook chegou a **12/12** (§11).
> **A ativação continua proibida** até re-homologação independente.

---

## 1. O desenho, inteiro

```text
Operador administrativo  (UMA VEZ, na máquina dele)
  ├── provisionar_claim_motor_partidas.js grant   →  motorDePartidas = true
  └── bootstrap_credencial_motor.js --commit
        ├── createCustomToken(uid)                     (Admin SDK)
        ├── POST identitytoolkit :signInWithCustomToken
        ├── confere sub / aud / iss / claim do ID token devolvido
        ├── verifyIdToken(idToken, true)               (checkRevoked)
        └── grava SÓ o refresh token, modo 0600, FORA do repositório

Railway  (PARA SEMPRE, sem credencial administrativa)
  └── credencial_motor.obterIdToken()
        └── POST securetoken /v1/token  (grant_type=refresh_token)
              → ID token novo, só em memória

Cloud Function  registrarEncerramentoPartida
  ├── protocolo callable verifica assinatura/exp/aud/iss  → req.auth
  ├── verifyIdToken(bearer bruto, true)                   → E REVOGAÇÃO
  ├── uid verificado === req.auth.uid                     → senão recusa
  └── motorDePartidas === true  (ou admin)                → senão recusa
```

**Por que o refresh token, e não o custom token.** Custom token expira em uma
hora e **só quem tem credencial administrativa o emite** — guardá-lo no Railway
obrigaria a rodar o bootstrap toda hora, e guardar a credencial que o emite
obrigaria a pôr uma chave de conta de serviço no Railway. As duas saídas são as
que a OS proíbe. O refresh token não expira por tempo, é revogável de fora, e
trocá-lo por ID token exige só a Web API Key, que não é segredo.

---

## 2. O bootstrap

`functions/scripts/bootstrap_credencial_motor.js`

### Ensaio é o padrão — e aqui é mais estrito que no provisionador

Sem `--commit`, **nenhum token é emitido**. Não é só a escrita em disco que fica
de fora: a própria criação do custom token, que é o ato irreversível de
materializar uma credencial, só acontece com `--commit`.

A prova não é a mensagem "ENSAIO" na saída — é o contador do dublê
(`BOOT-01`): `createCustomToken` foi chamado **zero** vez. Uma versão futura que
imprimisse ENSAIO e emitisse assim mesmo passaria num teste de saída e falha
neste.

### As travas, e por que cada uma existe

| Trava | O acidente que ela impede |
|---|---|
| Dupla digitação do projeto | Emitir a credencial em produção achando que era teste — e o segredo já nasce fora do lugar |
| Conferência do projeto resolvido pelo SDK | O SDK resolve o projeto de env, credencial ou metadata; se não é o pedido, aborta antes de ler o usuário |
| Forma do id de projeto | Argumento trocado de lugar, antes de o SDK sequer carregar |
| Claim `=== true` estrito | Uma credencial que o receptor recusa: o operador sairia com segredo no Railway e um servidor que não autentica |
| Destino validado **por inteiro e antes** de emitir | Descobrir que o caminho é inválido depois de materializar o refresh token deixaria uma credencial viva sem ninguém para guardá-la |
| Destino ≠ **raiz** do repositório | `path.relative(raiz, raiz)` é a string vazia: a raiz escapava da barreira "está dentro?" e só era barrada pela seguinte |
| Destino **fora** do repositório | Um refresh token na árvore de trabalho é um `git add` de distância de virar segredo versionado — e segredo versionado **não se apaga**: fica no histórico |
| Diretório-pai **existente, diretório e gravável** | Um erro de digitação no caminho fazia a V1 emitir o custom token, trocar, e só então falhar no `openSync` — credencial viva, ninguém para guardá-la |
| Diretório-pai **não gravável por outros** (POSIX) | Onde grupo ou "outros" escrevem, qualquer usuário troca o arquivo por um link simbólico; o 0600 do arquivo não protege nada aí |
| Arquivo **já existente** | Sobrescrever apagaria uma credencial talvez em uso no Railway **agora** |
| Escrita atômica com temporário | Falha no meio deixaria **meio refresh token**, que o operador colaria sem perceber |
| `verifyIdToken(_, true)` no próprio bootstrap | Entregar ao Railway uma credencial cuja sessão já está revogada produziria um servidor que nunca autentica, e o defeito seria procurado no lugar errado |

A recusa do destino é por **caminho resolvido**, não por texto (`BOOT-19b`):
`/repo/functions/../app/cred.env` continua dentro, e é a forma mais fácil de
furar uma checagem escrita com `startsWith`.

### O preflight do destino, e por que ele vem inteiro antes da emissão

`BOOT-28` é a garantia que junta as barreiras: para **cada** motivo de recusa de
destino — raiz do repositório, dentro do repositório, pai inexistente, arquivo já
existente — o contador do dublê afirma `createCustomToken === 0`,
`verifyIdToken === 0` e **zero** trocas REST. Não é sobre a mensagem de erro: é
sobre nada ter sido materializado.

O script **não cria diretório**. Criar árvore de diretórios para guardar segredo é
decisão do operador, e um `mkdir -p` embutido transformaria um erro de digitação
num diretório novo em lugar nenhum — com a credencial dentro.

### Permissões: o que é exigido, o que é avisado, e o que não é prometido

| Plataforma | Diretório-pai | Arquivo |
|---|---|---|
| POSIX | gravável por grupo/outros (`& 0o022`) → **RECUSA**, inclusive com *sticky bit* | criado `0600`, exclusivo (`wx`), e o temporário também |
| POSIX | apenas legível por outros (`& 0o077`, ex.: `~` em 0755) → **AVISO** | idem |
| Windows | modo POSIX **não é avaliado** | modo **pedido** 0600, e a saída diz que ele **não valeu** |

O aviso do modo legível não vira recusa de propósito: `0755` é o modo do `~` de
quase toda máquina POSIX, e recusar ali empurraria o operador a improvisar. O que
vaza num diretório legível é o **nome** do arquivo — o conteúdo continua `0600`.
O que **é** recusado é o diretório gravável por terceiros, porque ali o 0600 não
protege coisa alguma.

No Windows o script **nunca promete `0700` nem `0600`** (`BOOT-26c`, `BOOT-26d`):
a proteção efetiva vem da ACL herdada do diretório, e a saída diz "modo pedido",
não "modo". Um operador que lê `0600` seco conclui que o arquivo está protegido
quando ele pode não estar.

### O que sai, e o que nunca sai

Nenhum token é impresso. De um segredo sai **só o comprimento** — nem prefixo,
nem sufixo, nem hash: um prefixo de refresh token identifica o projeto, e um hash
estável permite correlacionar dois logs e concluir que é a mesma credencial. O
UID sai mascarado (`uid-…co`).

O arquivo gravado carrega **três** variáveis e nada mais. Não entram:

- o **ID token**, porque expira em uma hora e o servidor o obtém sozinho —
  gravá-lo ensinaria que existe um token para guardar, e não existe;
- o **custom token**, porque já cumpriu o papel dele naquela execução;
- a **Web API Key**, porque é configuração do projeto e não segredo.

A Web API Key vem de `FIREBASE_WEB_API_KEY`, **nunca de argumento**: argumento
aparece no histórico do shell e na lista de processos.

### Limitação declarada — Windows

`fs` ignora o modo POSIX no Windows. O `chmod` é chamado assim mesmo (é inócuo) e
o script **avisa** quando a plataforma não sustenta a restrição. Fingir que 0600
valeu ali seria a pior das saídas. O teste `BOOT-21` afirma o modo **pedido** e a
criação exclusiva em qualquer plataforma, e o modo **real** só onde o sistema o
sustenta.

---

## 3. A revogação efetiva

### O que estava errado

A OS anterior mediu e documentou: revogar o claim **não** invalida token já
emitido, e revogar as sessões só é notado por quem verifica com `checkRevoked`.
**O protocolo callable não verifica.** Um token de sessão revogada continuava
chegando com `motorDePartidas === true` — por até uma hora depois do corte.

E no emulador isso **não aparece**: lá `verifyIdToken` recusa o token revogado
mesmo sem a flag. É o tipo de divergência que faz uma equipe concluir, errado,
que o corte funciona.

### O que mudou

Só em `registrarEncerramentoPartida`, a única função que a autoridade da partida
chama. O bearer **bruto** (`req.rawRequest.headers.authorization`) é verificado
outra vez com `checkRevoked: true`, e a decisão de autoridade sai **desse** token
— não de `req.auth.token`.

**Isto não cria uma segunda autoridade.** Não há duas respostas possíveis: a
verificação com revogação é **estritamente mais forte** que a do protocolo (mesmo
conjunto de checagens, mais uma), e as duas identidades são comparadas — divergiu,
recusa. O protocolo continua sendo quem admite a requisição.

**Só aqui, e de propósito.** `verifyIdToken(_, true)` custa uma ida à rede. No
encerramento de partida isso acontece **uma vez por partida** — não por jogada,
não por leitura de perfil. `consultarPartidaPorMatchId`,
`consultarExtratoCompetitivo` e `registrarSinalAntifraude` **não** foram tocadas,
e há teste que o fixa (`REC-17d`).

### A prova de `checkRevoked: true`

Não é grep na fonte. `REC-06` injeta um dublê que **registra os argumentos** que
o código de produção passou, e afirma `=== true` no segundo. Um `false` acidental
quebra o arquivo em qualquer máquina, com ou sem emulador.

O motivo da recusa vai para o **log**, nunca para o chamador: distinguir "sessão
revogada" de "sem o claim" descreveria a defesa para quem a estivesse sondando. O
log não leva uid, token nem cabeçalho — diz o **quê**, não **quem**.

---

## 4. Superfície de implantação

| | Antes | Depois |
|---|---|---|
| Exports do entrypoint | **11** | **11** |
| Funções novas | — | **nenhuma** |
| App Check | inalterado | inalterado |
| Região | `southamerica-east1` | idem |
| Corpo transacional | — | **não tocado** |
| Deploy | — | **nenhum** |

Os módulos auxiliares moram fora da cadeia de `export *`: `autoridade.ts` não é
reexportado por `index.ts`, e `scripts/` está fora de `tsconfig.include` e no
`ignore` do `firebase.json`. `REC-17` conta os exports **pela estrutura da
fonte**, seguindo o `export *` — um export a mais em qualquer dos dois arquivos
viraria Cloud Function sem ninguém decidir, e o `tsc` não acusaria nada.

---

## 5. Testes

| Suíte | Antes | Depois |
|---|---|---|
| `functions` · provisionador (puro) | 21 ✅ | 21 ✅ |
| `functions` · provisionador (emulador de Auth) | 14 ✅ | 14 ✅ |
| `functions` · **bootstrap da credencial** | 39 ✅ | **51 ✅** *(V2: +12 do preflight)* |
| `functions` · **receptor, revogação (puro)** | — | **32 ✅** |
| `functions` · **receptor, revogação (emulador)** | — | **9 ✅** |
| `functions` · idempotência da conquista (Firestore) | 10 ✅ | 10 ✅ |
| `firebase/testes` · regras, suíte integrada | 120 ✅ | 120 ✅ |
| `functions-economia` | 63 ✅ | 63 ✅ |
| `tsc --noEmit` | ✅ | ✅ |

**80 casos novos na V1, mais 12 na V2; 0 falhas, 0 pulados.** No servidor: 228 na
V1 → **241** na V2 (+14 do contrato do Secure Token, −1 que afirmava o contrato
errado).

```bash
cd functions && npm run test:bootstrap          # sem rede, sem emulador
cd functions && npm run test:revogacao          # exige `npm run build`
cd functions && npm run emulador:revogacao      # guarda real x Admin SDK real
cd functions && npm run emulador:provisionador  # regressão do provisionador
cd functions && npm run emulador:conquistas     # regressão da conquista
cd firebase/testes && npm run emulador:integrado
cd functions-economia && npm test
```

---

## 6. Defeitos injetados

Doze mutações, aplicadas e revertidas. **Onze caíram; uma escapou, e virou teste.**

| # | Mutação | Repo | Caiu em |
|---|---|---|---|
| 1 | `verifyIdToken(token, false)` | A | `REC-06` |
| 2 | decidir por `req.auth.token` | A | `REC-16b` **e** `tsc` (TS6133) |
| 3 | log do refresh token | B | `CRED-32` |
| 4 | log do ID token | B | `CRED-32` |
| 5 | sem conferência do projeto | B | `CRED-18`, `CRED-21` |
| 6 | sem conferência do UID | B | `CRED-17`, `CRED-21` |
| 7 | reutilizar token expirado | B | `CRED-11`, `CRED-12`, `CRED-12b`, `CRED-15`, `CRED-15b` |
| 8 | uma renovação por chamada concorrente | B | `CRED-13`, `CRED-14`, `CRED-14b` |
| 9 | bootstrap escrevendo em ensaio | A | `BOOT-01`, `BOOT-02` |
| 10 | destino secreto dentro do repositório | A | `BOOT-19`, `BOOT-19b` |
| 11 | dependência no servidor | B | `CRED-33` |
| 12 | **token revogado aceito** | A | **escapou** → `REC-06c` |

### A que escapou

A mutação era um `catch` que, ao ver o token recusado com a flag, tentava de novo
**sem** ela — a "correção" que alguém escreveria depois de ver encerramentos
falhando em produção.

`REC-06` não a pegava: continua vendo o `true` da **primeira** chamada. A suíte do
emulador também não: naquele emulador a chamada sem a flag **também** recusa o
token revogado, então o resultado final não mudava. Em produção mudaria — lá a
chamada sem a flag **aceita** — e o corte imediato deixaria de existir sem nenhum
teste vermelho.

É a mesma divergência emulador × produção que esta entrega existe para resolver,
reaparecendo do lado da **prova**.

`REC-06c` não afirma o resultado: afirma a **contagem**. Uma segunda verificação
do mesmo token é, por si, o defeito — e isso é verificável sem emulador.
Confirmado nos dois sentidos: com a mutação, cai; sem ela, passa.

**Todas as mutações foram revertidas e as duas árvores estão limpas.** A mutação
10 chegou a criar `functions/cred.env` — o artefato que a guarda existe para
impedir, com o refresh token **de teste** (`SEGREDO-DE-TESTE-…`, sem valor real).
Removido.

---

## 7. Runbook de ativação

**Nenhum passo abaixo foi executado.**

```bash
cd functions
export FIREBASE_WEB_API_KEY=...   # nunca em argumento

# 1. conferir que o claim está concedido (nunca escreve)
node scripts/provisionar_claim_motor_partidas.js inspect \
  --project <PROJETO> --uid <UID_DO_MOTOR>

# 2. ENSAIAR o bootstrap — nenhum token é emitido
node scripts/bootstrap_credencial_motor.js \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --saida ~/bmv-credencial-motor.env

# 3. emitir de verdade (dupla digitação do projeto)
node scripts/bootstrap_credencial_motor.js \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --saida ~/bmv-credencial-motor.env \
  --commit --confirmar-projeto <PROJETO>

# 4. copiar as três variáveis para os segredos do Railway
# 5. APAGAR o arquivo — ele não tem por que sobreviver à cópia
```

A credencial administrativa vem do ambiente (`GOOGLE_APPLICATION_CREDENTIALS`
apontando para chave **fora** do repositório, ou
`gcloud auth application-default login`).

O **diretório** de `--saida` tem de existir e ser privado. Em POSIX:

```bash
mkdir -m 700 -p ~/.bmv-credenciais     # o script NÃO cria o diretório
```

### 7.1 Smoke autenticado — a prova de que a credencial FUNCIONA

**Nunca executado.** Este é o procedimento a rodar **depois** da ativação, e é o
único que responde "funcionou?" sem esperar a primeira partida real.

Ele existe porque a falha desta credencial é **silenciosa**: o Railway falha
fechado, o encerramento vai para a outbox, e o operador só descobre quando alguém
reclama de um ranking que não mudou. A homologação independente mostrou o caso
exato — a comparação de `project_id` teria feito `obterIdToken()` recusar **toda**
chamada, e nenhum teste local acusaria.

**Pré-requisitos:** os quatro segredos no Railway, o claim concedido, e o
transporte da OS seguinte no ar.

| Passo | O que fazer | O que tem de ser verdade |
|---|---|---|
| 1 | Anotar o instante `T0` (UTC) e o SHA implantado no Railway | dá para amarrar log a versão |
| 2 | No servidor, obter um token: `credencial_motor.obterIdToken()` | resolve; `estado().temToken === true`, `renovacoes === 1` |
| 3 | Ler `estado()` inteiro | **nenhum** campo carrega token, prefixo ou hash |
| 4 | Chamar `registrarEncerramentoPartida` com o desfecho de **teste** abaixo | HTTP 200, sem `permission-denied` |
| 5 | Ler o documento gravado em `matches/{MATCH_ID_DE_TESTE}` | existe, e o autor é o **UID do motor** — não `admin`, não um jogador |
| 6 | Varrer o log do Railway e o do Cloud Logging da janela `T0 → agora` | **zero** ocorrências de refresh token, ID token, API key ou `Authorization:` |
| 7 | Reverter (abaixo) | o ambiente volta ao que era |

**A operação de teste é identificável e reversível — por construção:**

```text
matchId      : smoke-<AAAAMMDD>-<HHMM>-<INICIAIS_DO_OPERADOR>
                 prefixo `smoke-` é o que torna o registro varrível e apagável
jogadores    : as identidades de teste do projeto, NUNCA contas reais
pontuação    : a mínima que o contrato aceita
```

**Reversão** — na ordem, e toda ela é `delete`, nunca `update`:

```text
1. matches/{MATCH_ID_DE_TESTE}/events/*        (subcoleção primeiro)
2. matches/{MATCH_ID_DE_TESTE}
3. rankingLedger  — os lançamentos com esse matchId
4. fraudSignals   — os sinais com esse matchId
5. users/{UID_DE_TESTE}/matchHistory/{MATCH_ID_DE_TESTE}
6. playerAchievements — só se o smoke tiver disparado conquista
```

Conferir o **censo depois**: as seis coleções voltam à contagem de antes. Um
smoke que não some é um smoke que sujou o ranking de produção.

**O que este procedimento NÃO prova:** que a credencial continua boa amanhã. Ele
é um corte no tempo. A prova de continuidade é a renovação (item 7 da §11), e a
de corte é a §8.2.

### 7.2 Se o smoke falhar — a leitura dos códigos

Cada código de `credencial_motor` aponta para um lugar diferente, e a
diferença importa porque três deles se parecem no sintoma ("não registrou").

| Código | Onde está o problema | Primeira coisa a olhar |
|---|---|---|
| `SEM_CONFIGURACAO` | falta variável no Railway | a mensagem diz **qual** |
| `HTTP 400/403` | refresh token inválido, revogado, ou API key de outro projeto | o par projeto × API key |
| `UID_DIVERGENTE` | o segredo do Railway é de **outra identidade** | qual bootstrap gerou aquele arquivo |
| `AUDIENCE_INVALIDO` / `ISSUER_INVALIDO` | a Web API Key é de outro projeto | `FIREBASE_PROJECT_ID` × a chave |
| `SEM_AUTORIDADE` | o claim foi removido depois da última renovação | o provisionador, `inspect` |
| `EXPIRACAO_INVALIDA` | relógio do servidor fora do lugar | NTP do container |

**Não existe mais `PROJETO_DIVERGENTE`.** Ele foi removido na correção do
contrato — ver `docs/CREDENCIAL-RENOVAVEL-MOTOR-V1.md` no repositório do
servidor. Se ele reaparecer num log, alguém restaurou a comparação que quebrava a
credencial.

### Segredos esperados no Railway

Só os **nomes**. Nenhum valor real em Git, teste, fixture, log, mensagem de erro,
documentação ou linha de comando.

| Variável | Natureza |
|---|---|
| `FIREBASE_MOTOR_REFRESH_TOKEN` | **segredo** |
| `FIREBASE_MOTOR_UID` | identidade esperada |
| `FIREBASE_PROJECT_ID` | projeto esperado — **já existe** (WS-AUTH) |
| `FIREBASE_WEB_API_KEY` | configuração do projeto |
| `FIREBASE_REGISTRAR_ENCERRAMENTO_URL` | *(futura, OS do transporte)* |

---

## 8. Rollback e corte de acesso

**Corte imediato**, agora que ele de fato funciona:

```bash
node -e "require('firebase-admin').initializeApp({projectId:'<PROJETO>'});require('firebase-admin').auth().revokeRefreshTokens('<UID_DO_MOTOR>')"
```

Isto derruba **o refresh token e todo ID token já emitido**, na hora — porque o
receptor agora consulta a revogação. Antes desta entrega, o token em circulação
continuaria valendo até expirar.

Para tirar a autoridade em definitivo, revogar **também** o claim:

```bash
node scripts/provisionar_claim_motor_partidas.js revoke \
  --project <PROJETO> --uid <UID_DO_MOTOR> --commit --confirmar-projeto <PROJETO>
```

**As duas coisas, e nesta ordem.** Revogar só o claim não derruba token já
emitido (`RECINT-03`); revogar só a sessão deixa a conta autorizada para a
próxima credencial.

Rollback de código: a branch não foi mesclada; descartá-la desfaz tudo.

---

### 8.2 Verificar que o token CACHEADO passa a ser recusado

**Nunca executado.** O corte da §8 só vale se ele alcançar o token que **já está
na memória do Railway** — e é justamente esse que um corte mal feito não alcança.
O ID token vive até uma hora; sem `checkRevoked`, ele continuaria sendo aceito
depois de a sessão ser revogada. Este procedimento mede isso, e não a mensagem de
erro.

O passo 1 é o que faz o resto ser prova: sem ele, "recusou" seria compatível com
"o servidor tinha renovado sozinho no meio do caminho".

| Passo | Ação | Exigência |
|---|---|---|
| 1 | Registrar `estado()` do provedor: `temToken`, `expiraEmMs`, `renovacoes`. **Registrar o instante, NUNCA o token** | há token em cache, e falta bem mais que a margem de 5 min para ele expirar |
| 2 | `revokeRefreshTokens(<UID_DO_MOTOR>)` | — |
| 3 | `provisionar_claim_motor_partidas.js revoke --commit --confirmar-projeto …` | claim removido |
| 4 | Chamar `registrarEncerramentoPartida` **sem forçar renovação** | `estado().renovacoes` **não** subiu: é o token velho que foi apresentado |
| 5 | Ler o resultado da chamada | **recusa**. Censo das seis coleções: **zero** escritas |
| 6 | Forçar renovação (reiniciar o serviço, ou esperar a margem) | a troca no Secure Token **falha**: o refresh token foi revogado |
| 7 | Se, e só se, a troca ainda devolver token: conferir o payload | o token novo **não** carrega `motorDePartidas` — a emissão posterior à revogação também não tem autoridade |

**O passo 4 é o caso que a entrega existe para fechar**, e o passo 7 é o que
fecha a porta de trás: revogar a sessão sem remover o claim deixaria a próxima
credencial nascer autorizada.

**Restauração** (só depois de medir): conceder o claim de novo com o
provisionador, rodar o bootstrap de novo — o refresh token antigo **está morto**,
e não há como ressuscitá-lo —, trocar o segredo no Railway, e repetir o smoke da
§7.1.

**Cuidado que este procedimento exige:** ele **derruba a credencial de produção**.
Rodar em janela combinada, com a outbox do servidor segurando os encerramentos, e
com o bootstrap de reposição já preparado. Não é um teste de terça-feira à tarde.

---

### 8.3 Rotação periódica e resposta a vazamento

**Nunca executado.** Nada aqui é automático hoje: são procedimentos manuais com o
dono declarado.

#### Rotação programada

| | |
|---|---|
| **Periodicidade** | a cada **90 dias**, e **sempre** que alguém que teve acesso à máquina do operador sair do projeto |
| **Responsável** | o dono da conta administrativa do Firebase (hoje, a titular do projeto) |
| **Janela** | combinada; a outbox do servidor absorve os encerramentos do intervalo |
| **Registro** | data, executante e resultado — **nunca** o token, nem prefixo, nem hash |

O refresh token **não expira sozinho**: quem o tiver produz ID tokens com
`motorDePartidas` até alguém revogar. Os 90 dias não são uma regra do Firebase —
são o limite que nós escolhemos para o tempo em que uma cópia esquecida continua
valendo.

```text
1. GERAR  — bootstrap num diretório privado, FORA do repositório
             mkdir -m 700 -p ~/.bmv-credenciais
             node scripts/bootstrap_credencial_motor.js \
               --project <PROJETO> --uid <UID_DO_MOTOR> \
               --saida ~/.bmv-credenciais/nova.env \
               --commit --confirmar-projeto <PROJETO>
           (o UID é o MESMO; o que muda é o refresh token)

2. SUBSTITUIR — no Railway, trocar FIREBASE_MOTOR_REFRESH_TOKEN e aplicar de uma
           vez. A troca do secret é o ponto atômico: o serviço reinicia com o
           valor novo, e o provedor volta a ler o ambiente (`CRED-16`).
           NÃO manter as duas credenciais convivendo "por segurança": duas
           credenciais vivas é o dobro do que se precisa revogar.

3. VALIDAR — smoke da §7.1, inteiro. Só depois dele a rotação está feita.

4. REVOGAR A ANTERIOR — revokeRefreshTokens(<UID_DO_MOTOR>).
           Isto mata TODA sessão do UID, inclusive a nova: por isso vem DEPOIS
           da validação, e por isso a etapa 5 existe.

5. REEMITIR — rodar o bootstrap de novo e repetir 2 e 3.
           É o preço de o corte ser por identidade, e não por credencial: o
           Firebase não revoga "aquele refresh token", revoga o UID inteiro.

6. APAGAR — os arquivos de bootstrap das etapas 1 e 5. Eles não têm por que
           sobreviver à cópia.
```

> **A etapa 4 derruba também a credencial nova.** Não há revogação seletiva de
> refresh token no Firebase Auth. Quem tentar economizar a etapa 5 fica com o
> servidor sem credencial e sem entender por quê.

#### Resposta a vazamento — a ordem é outra

Aqui **não** se valida antes de revogar. A credencial vazada está viva agora, e
quem a tem escreve encerramento de partida sob a autoria do motor.

```text
T+0   CORTAR
      revokeRefreshTokens(<UID_DO_MOTOR>)
      provisionar_claim_motor_partidas.js revoke --commit --confirmar-projeto <PROJETO>
      As DUAS coisas: a primeira mata o que circula, a segunda impede a próxima.
      O serviço fica sem credencial — é o estado desejado.

T+0   AVISAR  — a titular do projeto, e quem opera o Railway.

T+1   CONTER  — remover o secret do Railway; se o vazamento foi por log, purgar
      o log; se foi por arquivo, apagar o arquivo em todas as cópias.

T+2   INSPECIONAR — janela: da PRIMEIRA exposição possível até T+0.
      • Cloud Logging de `registrarEncerramentoPartida`: chamadas com o UID do
        motor, agrupadas por IP e origem. Origem inesperada = uso indevido.
      • Firestore: `matches` com autor do motor no período; comparar com as
        partidas que o servidor de fato encerrou.
      • `fraudSignals` e `rankingLedger` no mesmo intervalo.
      • Auth: eventos de troca de token do UID.
      Registrar o que foi olhado e o que se achou. "Nada encontrado" só vale
      escrito, com a janela declarada.

T+3   REEMITIR — bootstrap novo, secret novo, smoke da §7.1.

T+4   REPARAR — reverter as escritas indevidas encontradas em T+2, se houver.

T+5   ESCREVER — como vazou, e o que muda para não repetir.
```

**Rollback da resposta**: não existe "desfazer a revogação". Se o vazamento se
mostrar falso alarme, o caminho de volta é o mesmo — reemitir e validar. É de
propósito: uma revogação que se pudesse desfazer não seria um corte.

**Como um vazamento aparece.** O refresh token não é usado por humanos: ele só
existe no Railway e no arquivo que o operador deveria ter apagado. Os sintomas
plausíveis são encerramento de partida que o servidor não iniciou, `matches` com
`matchId` desconhecido, e chamadas ao receptor de origem estranha. Não há alarme
automático para nada disso hoje — está registrado como risco residual 4.

---

## 9. Riscos residuais

1. **O refresh token não expira sozinho.** Quem o obtiver produz ID tokens com
   `motorDePartidas` até alguém revogar as sessões. É o preço de não ter chave de
   serviço; a mitigação é o corte da §8, que agora é imediato.
2. **A ativação continua manual**, e é onde a credencial real nasce. As travas
   reduzem o erro de projeto; não o eliminam.
3. **`admin` também autoriza.** Anterior a esta OS, fixado em teste (`REC-14c`),
   e amplia a superfície além da identidade técnica.
4. **Não há auditoria de emissão.** O bootstrap imprime o que fez, e o log fica no
   terminal do operador. Registrar emissões em coleção auditável seria outra OS.
5. **Uma ida à rede a mais por encerramento.** É uma por partida, mas é latência
   nova num caminho que antes não a tinha — e uma indisponibilidade do Auth passa
   a impedir o registro do encerramento. A outbox do servidor é o que segura isso,
   e ela existe.
6. **O emulador continua mentindo sobre revogação.** Está registrado nas duas
   suítes e não virou asserção. O defeito 12 mostrou que a mentira alcança
   também a prova, não só o diagnóstico.
7. **Nada disto está exercitado de ponta a ponta**, porque o transporte não
   existe: o servidor produz a credencial, o receptor a exige, e ninguém ainda
   liga um ao outro.

---

## 10. Limitação do emulador — o que NÃO está provado

Isto é registrado como limitação, e **não** foi convertido em teste verde.

- **O emulador de Auth emite ID token `{"alg":"none"}`, com a assinatura vazia.**
  Ele não assina nada. A cadeia com assinatura real — que é a de produção — não é
  exercitável ali.
- **Por isso a integração cruzada nunca rodou de ponta a ponta.** As duas
  divergências travam a cadeia em sentidos opostos: o token cru do emulador é
  recusado pelo módulo do servidor (`TOKEN_ILEGIVEL`, porque `partesDoToken` exige
  os três segmentos não vazios — o certo para produção); e um token com assinatura
  acrescentada à mão passa no servidor e é recusado pelo receptor, que verifica de
  verdade.
- **Um token assinado artificialmente também não serve.** Assinar com chave nossa
  produz um token que só a nossa chave valida; o que precisa ser provado é que o
  **Google** emite, e que a **Function** aceita o que ele emitiu. Uma cadeia
  fechada com chave própria mediria o nosso arnês, não o contrato.
- **O `project_id` do envelope é o caso concreto de por que isso importa.** Ele só
  foi medido porque alguém foi olhar o campo; nenhuma suíte o teria pego, porque a
  fixture da V1 afirmava a suposição em vez de testá-la.

**Consequência operacional, explícita:** o **smoke com token real da §7.1 é
obrigatório** na OS operacional futura. Enquanto ele não rodar, o que existe são
as duas metades verificadas separadamente — o produtor (60 casos, resposta na
forma de produção) e o receptor (32 puros + 9 no emulador, com Firestore real) —
e **nenhuma** medição da junta entre elas.

Nenhum resultado de emulador foi usado como prova de `checkRevoked`, pelo mesmo
motivo: aquele emulador recusa token revogado **mesmo sem** a flag. A prova de
`checkRevoked` é a contagem de invocações de `REC-06`/`REC-06c`, que roda sem
emulador nenhum.

---

## 11. Prontidão operacional — **12 de 12**

A homologação independente pontuou **9 de 12** e nomeou os três ausentes. Estão
fechados.

| # | Item | Onde | Estado |
|---|---|---|---|
| 1 | Criação/seleção da identidade dedicada | §7, passo 1 | ✅ |
| 2 | Concessão estrita da claim | provisionador, §7 passo 1 | ✅ |
| 3 | Geração segura do refresh token | §2 e §7 passos 2–3 | ✅ |
| 4 | Armazenamento como secret no Railway | §7 passo 4 | ✅ |
| 5 | Variáveis públicas necessárias | §7, tabela de segredos | ✅ |
| 6 | **Smoke test autenticado** | **§7.1** | ✅ **novo** |
| 7 | Renovação após expiração | §7.2 (leitura dos códigos) + `CRED-11` | ✅ |
| 8 | Corte emergencial: revogar sessões **e** remover claim | §8 | ✅ |
| 9 | **Verificar que o token cacheado passa a ser recusado** | **§8.2** | ✅ **novo** |
| 10 | Rollback | §8 e §8.3 | ✅ |
| 11 | **Rotação periódica e resposta a vazamento** | **§8.3** | ✅ **novo** |
| 12 | Nenhum token nos logs | §7.1 passo 6, `BOOT-22`, `CRED-18n`, `CRED-32` | ✅ |

**Nenhum dos doze foi executado.** São procedimentos escritos, com dono,
pré-requisito, ordem, critério de sucesso e reversão — não um registro de
execução.

---

## 12. Estado do Git

| | |
|---|---|
| Branch | `correcao/credencial-motor-contrato-runbook-v2` |
| Base | `homologacao/credencial-renovavel-motor-revogacao-v1` @ `a6b6b5b` |
| Push | normal, sem `--force` |
| Merge / PR / Deploy | nenhum |
| Árvore | limpa |

Na V2 mudaram três arquivos e nasceu um:
`functions/scripts/bootstrap_credencial_motor.js` (preflight do destino),
`functions/test/bootstrap_credencial.test.js` (+12 casos), este documento, e
`docs/CORRECAO-CREDENCIAL-MOTOR-CONTRATO-E-RUNBOOK-V2.md` (o laudo corretivo).

Arquivos novos: `functions/scripts/bootstrap_credencial_motor.js`, três suítes em
`functions/test/`, este documento. Alterados:
`functions/src/autoridade.ts` (a guarda com revogação),
`functions/src/rastreabilidade.ts` (a guarda passou a ser aguardada) e
`functions/package.json` (alvos de teste).
