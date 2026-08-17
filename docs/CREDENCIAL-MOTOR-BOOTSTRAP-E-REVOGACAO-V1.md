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
| Branch | `claude/bootstrap-credencial-motor-revogacao-v1` |
| Base | `claude/provisionador-claim-motor-partidas-v1` |
| SHA da base | `831eb81cc55e67ce6c01a3cf4c592616559e968e` |
| Metade do servidor | `soniaambrosio/buraco-servidor`, branch `claude/credencial-renovavel-motor-railway-v1` |

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
| Destino validado **antes** de emitir | Descobrir que o caminho é inválido depois de materializar o refresh token deixaria uma credencial viva sem ninguém para guardá-la |
| Destino **fora** do repositório | Um refresh token na árvore de trabalho é um `git add` de distância de virar segredo versionado — e segredo versionado **não se apaga**: fica no histórico |
| Destino **inexistente** | Sobrescrever apagaria uma credencial talvez em uso no Railway **agora** |
| Escrita atômica com temporário | Falha no meio deixaria **meio refresh token**, que o operador colaria sem perceber |
| `verifyIdToken(_, true)` no próprio bootstrap | Entregar ao Railway uma credencial cuja sessão já está revogada produziria um servidor que nunca autentica, e o defeito seria procurado no lugar errado |

A recusa do destino é por **caminho resolvido**, não por texto (`BOOT-19b`):
`/repo/functions/../app/cred.env` continua dentro, e é a forma mais fácil de
furar uma checagem escrita com `startsWith`.

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
| `functions` · **bootstrap da credencial** | — | **39 ✅** |
| `functions` · **receptor, revogação (puro)** | — | **32 ✅** |
| `functions` · **receptor, revogação (emulador)** | — | **9 ✅** |
| `functions` · idempotência da conquista (Firestore) | 10 ✅ | 10 ✅ |
| `firebase/testes` · regras, suíte integrada | 120 ✅ | 120 ✅ |
| `functions-economia` | 63 ✅ | 63 ✅ |
| `tsc --noEmit` | ✅ | ✅ |

**80 casos novos, 228 de regressão, 0 falhas, 0 pulados.**

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

## 10. Estado do Git

| | |
|---|---|
| Branch | `claude/bootstrap-credencial-motor-revogacao-v1` |
| Commits | 5, separados por responsabilidade |
| Push | normal, sem `--force` |
| Merge / PR / Deploy | nenhum |
| Árvore | limpa |

Arquivos novos: `functions/scripts/bootstrap_credencial_motor.js`, três suítes em
`functions/test/`, este documento. Alterados:
`functions/src/autoridade.ts` (a guarda com revogação),
`functions/src/rastreabilidade.ts` (a guarda passou a ser aguardada) e
`functions/package.json` (alvos de teste).
