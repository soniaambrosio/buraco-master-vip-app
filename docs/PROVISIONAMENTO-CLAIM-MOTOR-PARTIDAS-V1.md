# Provisionamento do claim `motorDePartidas` — V1

O claim tinha **três consumidores e nenhum emissor**. Esta entrega cria o
emissor, prova a cadeia inteira contra o emulador e documenta a ativação. Ela
**não** implementa a outbox, não envia encerramento e não toca no Perfil.

> **PASS — PROVISIONADOR PRONTO**
> **ATIVAÇÃO OPERACIONAL AINDA NÃO EXECUTADA**
>
> A cadeia da Primeira Batida Real **não** está completa: faltam a outbox, o
> transporte e o leitor do Perfil. Esta OS removeu o bloqueio de autoridade, e
> só ele.

| | |
|---|---|
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Branch | `claude/provisionador-claim-motor-partidas-v1` |
| Base | `claude/autoridade-conquista-primeira-batida-real-v1` |
| SHA da base | `6c6fcbccceefa4b10a5c484536d686e66c7b5546` |

---

## 1. Por que esta base, e não outra

A escolha foi **medida**, não herdada do enunciado. Das 121 branches remotas,
**47 contêm** `functions/src/rastreabilidade.ts`. Mas o arquivo tem apenas duas
versões distintas:

| Versão do blob | Branches | Contém |
|---|---|---|
| `cc64ee4…` | 46 | `registrarEncerramentoPartida` sem a conquista |
| `e3fbbb7…` | **1** | a versão que avalia a conquista na mesma transação |

A única branch com o blob novo é também a única com `functions/src/conquistas.ts`.
Logo a base é **inequívoca**, e não houve ambiguidade a arbitrar.

Genealogia: `feat/economia-boas-vindas-vitorias` (`42928c30…`) é **ancestral**
da base — a conquista foi construída sobre a economia. Merge-base com `main`:
`2ddadde7…`.

---

## 2. Identidade técnica

**Nenhuma identidade técnica existia**, e esta OS **não cria credencial real**.
O que ela entrega é o modelo e o ciclo de vida; a criação é o passo operacional
da §9.

### Modelo

Um usuário do Firebase Auth **dedicado**, criado pelo Admin SDK, sem provedor de
login social e **sem senha** — ele nunca faz login interativo. Obtém ID token
por troca de *custom token*, que só quem tem credencial administrativa emite.

### Isolamento exigido

| Regra | Como se sustenta |
|---|---|
| Não é jogador humano | Criada pelo Admin SDK, fora do fluxo de cadastro do app |
| Não aparece em ranking, Perfil, amizade ou economia | Nunca recebe documento em `users/`, `publicProfiles/`, `rankingLedger/` ou `usuarios/` — nada a cria, porque ela não joga |
| Não recebe VIP, fichas nem conquista | A conquista exige participante `humano` com assento; ela não senta |
| Não compartilha UID com administrador humano | O papel `admin` é outro claim, concedido a outra conta; o provisionador **nunca** escreve `admin` |
| Não é criada pelo cliente | `firestore.rules` nega escrita, e o Auth não expõe criação com claim |

### Ciclo de vida

Criada na ativação → claim concedido → usada pelo transporte → claim revogado
quando o transporte for desligado ou a chave rotacionar. **Rotação não exige
identidade nova**: revoga-se a sessão, não a conta.

---

## 3. O provisionador

`functions/scripts/provisionar_claim_motor_partidas.js`

### Por que um script, e não uma Cloud Function

Uma Function que concedesse `motorDePartidas` seria uma superfície de rede cujo
comprometimento entrega a autoridade da partida inteira — quem a obtivesse
escreveria o próprio placar. O script roda sob credencial administrativa já
controlada, não escuta porta, e nenhum aparelho o alcança. **Nenhuma Function
foi criada nesta OS.**

### Por que dentro de `functions/`

`firebase-admin` é dependência de `functions/`, e o Node resolve módulos a
partir do diretório do próprio script — um arquivo em `firebase/scripts/` não
alcançaria `functions/node_modules`. Três travas impedem que ele vire função
implantada:

1. `tsconfig.json` tem `include: ["src"]` — `scripts/` não é compilado;
2. `index.ts` não o reexporta — e `index.ts` faz `export * from "./rastreabilidade"`,
   então **todo export de lá viraria uma Cloud Function**;
3. `firebase.json` passou a listar `scripts` e `test` em `ignore` — eles nem
   sobem no pacote.

**Verificado:** o entrypoint compilado exporta 11 símbolos, os mesmos 11 de
antes, todos Cloud Functions preexistentes.

### Operações

| Operação | Escreve? | Comportamento |
|---|---|---|
| `inspect` | nunca | Relata o estado e se o token **autorizaria** |
| `grant` | só com `--commit` | Concede, preservando os demais claims |
| `revoke` | só com `--commit` | **Remove a chave**, preservando os demais |
| *(ensaio)* | — | É o **padrão**: sem `--commit`, nada é escrito |

`inspect` **recusa** `--commit`: aceitar a flag onde ela é inócua ensinaria o
operador que ela é inofensiva, e nas outras duas operações ela não é.

### Proteção contra o projeto errado

Duas travas independentes:

1. **Dupla digitação** — `--commit` exige `--confirmar-projeto <id>` idêntico a
   `--project`. Divergiu, não escreve.
2. **Conferência do SDK** — depois de inicializar, o projeto que o Admin SDK
   resolveu (de env, credencial ou metadata) é comparado ao pedido. Diferente,
   aborta antes de qualquer escrita.

Mais a forma do id (`^[a-z][a-z0-9-]{3,29}$`), que barra argumento trocado de
lugar antes de o SDK sequer carregar.

### Política de grant/revoke

**Preservação é o ponto mais delicado.** `setCustomUserClaims` **sobrescreve** o
mapa inteiro; ele não mescla. Um grant desatento que gravasse
`{motorDePartidas: true}` apagaria o `admin` de quem o tivesse — e ninguém
notaria até alguém perder acesso. O provisionador lê os claims atuais, altera
**apenas** a chave alvo e regrava o resto intacto.

**Grant corrige tipo errado.** A guarda exige `=== true`; um claim que chegou
como `"true"`, `1` ou `false` — o que um provisionamento manual produz — não
autoriza nada, e por isso é **reescrito**, não aceito.

**Revoke remove a chave** em vez de gravar `false`. As duas são igualmente
seguras para a guarda, mas remover não deixa lápide: um mapa que acumula
`false` vira ruído em que ninguém enxerga o que está de fato concedido.

Ambas são **idempotentes**: repetir não escreve e relata `ja_concedido` /
`ja_revogado`.

---

## 4. Propagação e renovação do token

É a parte que o transporte vai herdar, e a mais fácil de errar.

> **Custom claim só existe dentro de um ID token, e ID token não muda depois de
> emitido.** Conceder o claim **não** altera nenhum token já em circulação.

Provado, e nos dois sentidos:

- **INT-01** — depois do `grant`, o token emitido *antes* continua **não**
  autorizando. Só depois de renovar (`grant_type=refresh_token`) o claim aparece,
  como **booleano** `true`, e a guarda aceita.
- **INT-02b** — depois do `revoke`, o claim já saiu da conta e mesmo assim o
  token velho **ainda autoriza**, até ser renovado.

### O que isso obriga o transporte a fazer

1. Renovar o ID token **antes** de usá-lo, e não guardar um indefinidamente.
2. Para cortar acesso **na hora** — e não esperar o token expirar — revogar as
   sessões (`revokeRefreshTokens`) **além** de revogar o claim.
3. Quem verifica precisa passar `checkRevoked: true`; sem isso, em produção, um
   token revogado continua verificando até expirar.

### Duas armadilhas medidas

**Resolução de um segundo.** `tokensValidAfterTime` é gravado com precisão de
segundo, e a recusa só dispara quando `auth_time < validSince`. Revogar no mesmo
segundo em que o token foi emitido deixa os dois **iguais** — medido:
`auth_time` e `validSince` ambos em `1786937626` — e a checagem não dispara.
Quem cortar acesso e conferir no mesmo segundo vai concluir, errado, que o corte
falhou. A suíte espera pelo **fato** (revoga até o carimbo ultrapassar o token),
e não por um prazo fixo.

**Divergência emulador × produção.** Neste emulador, `verifyIdToken` recusa o
token revogado **mesmo sem** `checkRevoked`. Em produção, não: sem a flag, o
token revogado continua verificando. A divergência ficou **registrada e não
virou asserção** — fixar o comportamento do emulador prenderia a suíte a um
detalhe do `firebase-tools`, e fixar o de produção faria a suíte falhar aqui. A
regra que vale para o transporte é a conservadora: **passe `true`**.

---

## 5. Contrato de autorização

A guarda saiu de dentro de `exigirAutoridadeDePartida` para
`functions/src/autoridade.ts` — módulo que `index.ts` **não** reexporta, logo
biblioteca e não superfície de implantação, pelo mesmo motivo que
`conquistas.ts` existe separado.

**Nada foi afrouxado.** A comparação continua `=== true`; mudou o endereço, e
com ele a possibilidade de prová-la. Antes, a regra só era alcançável chamando a
função inteira — e uma regra de permissão que nenhum teste alcança é uma regra
que só se descobre errada em produção. Nenhuma linha de `export` mudou em
`rastreabilidade.ts`, e o contorno implantado é idêntico.

| Entrada | Autoriza? | Provado em |
|---|---|---|
| `motorDePartidas: true` (booleano) | **sim** | INT-01 |
| claim ausente | não | INT-01, INT-09 |
| `false` | não | PLA-07, VER-01 |
| string `"true"` | não | INT-08 |
| número `1` / string `"1"` | não | PLA-07 |
| jogador comum autenticado | não | INT-09 |
| token inválido ou vazio | não | INT-10 |
| token revogado (com `checkRevoked`) | não | INT-02 |
| `admin: true` | **sim** — por papel próprio, anterior a esta OS | INT-09 |

`admin` continua autorizando: é a saída de emergência, decidida antes desta
entrega. Ficou **fixado em teste** para que ninguém o remova sem perceber, e
para deixar explícito que **não é o provisionador que o concede**.

App Check não foi removido de função alguma.

---

## 6. Testes

| Suíte | Casos | Resultado |
|---|---|---|
| `functions` · provisionador (puro) | 21 | ✅ |
| `functions` · provisionador (emulador de Auth) | 14 | ✅ |
| `functions` · idempotência da conquista (Firestore) | 10 | ✅ |
| `firebase/testes` · regras, suíte integrada | 120 | ✅ |
| `functions-economia` | 63 | ✅ |
| `tsc --noEmit` | — | ✅ |

**35 casos novos, 193 de regressão, 0 falhas, 0 pulados.**

A suíte integrada usa a guarda **real** (`lib/autoridade.js`, compilada de
`src/autoridade.ts`, a mesma que `exigirAutoridadeDePartida` chama).
Reimplementar o predicado no teste provaria apenas que sei escrever `=== true`
duas vezes.

A suíte falha alto se `FIREBASE_AUTH_EMULATOR_HOST` não estiver definido, em vez
de se pular: uma suíte de segurança que se auto-pula é uma suíte que ninguém
percebe que parou de rodar.

### Comandos

```bash
cd functions && npm run test:provisionador        # puro, sem emulador
cd functions && npm run emulador:provisionador    # cadeia completa (Auth)
cd functions && npm run emulador:conquistas       # regressão da conquista
cd firebase/testes && npm run emulador:integrado  # regressão das regras
cd functions-economia && npm test                 # regressão da economia
```

O emulador de Firestore exige JVM; o de Auth, **não** — por isso
`emulador:provisionador` sobe `--only auth` e roda em máquina sem Java.

---

## 7. Segurança

- **Nenhuma credencial no repositório.** Nenhuma chave, nenhum
  `serviceAccount.json`, nenhuma senha — em argumento, log ou documento. Há
  teste que varre a fonte do provisionador atrás de `BEGIN PRIVATE KEY`,
  `private_key`, `AIza`, `Bearer `, `client_secret` e `refresh_token`.
- **Saída redigida.** O UID sai mascarado (`moto…7a`) — o bastante para o
  operador conferir, pouco demais para um log colado num chamado entregar a
  identidade técnica. Dos outros claims sai só o **nome**, nunca o valor.
- **Falha com código diferente de zero**, sempre: uso inválido e leitura
  impossível saem `1`; verificação pós-escrita reprovada sai `2`.
- **Não cria identidade.** UID inexistente é erro, não convite para criar.
- Precedente do projeto para segredo real, quando a ativação exigir:
  `defineSecret(...)` + Secret Manager, como em `PLAY_SERVICE_ACCOUNT_JSON`.
  **Nada foi populado nesta OS.**

---

## 8. Comandos operacionais

Placeholders. Substituir na execução; **não** versionar valores reais.

```bash
cd functions

# 1. Ver o estado (nunca escreve)
node scripts/provisionar_claim_motor_partidas.js inspect \
  --project <PROJETO> --uid <UID_DO_MOTOR>

# 2. Ensaiar a concessão (nada é escrito)
node scripts/provisionar_claim_motor_partidas.js grant \
  --project <PROJETO> --uid <UID_DO_MOTOR>

# 3. Conceder de verdade (dupla digitação do projeto)
node scripts/provisionar_claim_motor_partidas.js grant \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --commit --confirmar-projeto <PROJETO>

# 4. Revogar
node scripts/provisionar_claim_motor_partidas.js revoke \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --commit --confirmar-projeto <PROJETO>
```

A credencial administrativa vem do ambiente
(`GOOGLE_APPLICATION_CREDENTIALS` apontando para chave **fora** do repositório,
ou `gcloud auth application-default login`). O script não recebe segredo por
argumento — argumento aparece em histórico de shell e em lista de processos.

---

## 9. Ativação futura

Nenhum passo abaixo foi executado.

| # | Passo | Onde | Estado |
|---|---|---|---|
| 1 | Criar o usuário técnico do Motor de Partidas pelo Admin SDK, sem provedor e sem senha | Firebase Auth | **pendente** |
| 2 | Guardar o UID em segredo operacional (não no Git) | Secret Manager | **pendente** |
| 3 | Rodar `inspect` e confirmar que ele **não** tem o claim | operador | **pendente** |
| 4 | Rodar `grant` em **ensaio** e conferir o plano | operador | **pendente** |
| 5 | Rodar `grant --commit --confirmar-projeto` | operador | **pendente** |
| 6 | Conferir por `inspect` que autoriza | operador | **pendente** |
| 7 | Definir como o Railway obtém ID token renovado sem chave versionada | **OS do transporte** | **pendente** |

O passo 7 **não é desta OS** e continua sendo o item que impede o transporte de
existir: o servidor Node é zero-dependência por decisão documentada e não pode
receber `firebase-admin`. As saídas possíveis — um intermediário que troque
custom token por ID token, ou credencial de workload — são decisão da OS
seguinte, e nenhuma delas foi escolhida aqui.

## 10. Rollback

Em um comando, e sem implantar nada:

```bash
node scripts/provisionar_claim_motor_partidas.js revoke \
  --project <PROJETO> --uid <UID_DO_MOTOR> --commit --confirmar-projeto <PROJETO>
```

Depois disso, **renovar ou revogar as sessões** — senão um token já emitido
continua autorizando até expirar (§4). Para corte imediato:
`admin.auth().revokeRefreshTokens(<UID>)`, e o verificador com `checkRevoked`.

Rollback de código: a branch não foi mesclada; descartá-la desfaz tudo. O único
arquivo de produção tocado é `rastreabilidade.ts`, e apenas para importar a
guarda extraída — sem mudança de comportamento nem de contorno implantado.

---

## 11. Riscos residuais

1. **A ativação continua manual.** Nada garante que o passo 5 seja executado no
   projeto certo além das duas travas do script. A dupla digitação reduz, não
   elimina.
2. **`admin` também autoriza.** Quem tem `admin` escreve encerramento sem
   precisar do claim novo. É anterior a esta OS e está fixado em teste, mas
   amplia a superfície além da identidade técnica.
3. **Não há auditoria de concessão.** O script imprime o que fez, e o log fica
   no terminal do operador. Registrar concessões em coleção auditável seria
   outra OS — e teria de resolver quem pode ler.
4. **Revogar o claim não corta acesso imediato** (§4). Sem revogar sessões, a
   janela é a validade do token.
5. **A divergência emulador × produção** na verificação de revogação significa
   que este ponto está provado no emulador, e apenas *documentado* para produção.

---

## 12. Armadilhas registradas, e não corrigidas aqui

Pertencem à **OS de outbox e tradução do envelope**. Nenhuma foi tocada.

| # | Armadilha |
|---|---|
| 1 | O servidor envia `meta_alcancada`; as Functions esperam `meta_atingida` |
| 2 | Divergência equivalente em `tipoPartida` (`publica`/`privada`/`simulada` × `publica_casual`/`publica_ranqueada`/`privada`/`torneio`/…) |
| 3 | `impressaoEstado` no servidor é a impressão **viva** da sala, recalculada a cada mudança |
| 4 | Essa impressão **não pode** ser lida de novo na retentativa — a convergência leria divergência e recusaria para sempre |
| 5 | A ingestão aceita **quatro** campos: `matchId`, `desfecho`, `diario`, `ordem` |
| 6 | Os dezesseis campos do envelope **não** podem ser encaminhados crus |

**A regra da conquista não pode ser duplicada no Node.** Ela vive em
`app/lib/conquistas/primeira_batida_real.dart`, alcançada pelas Functions via
`dart compile js`. A tradução do envelope deve morar do lado que já enxerga esse
domínio.

---

## 13. Estado do Git

| | |
|---|---|
| Branch | `claude/provisionador-claim-motor-partidas-v1` |
| Commits | 4, separados por responsabilidade |
| Push | normal, sem `--force` |
| Merge | nenhum |
| PR | nenhum |
| Deploy | nenhum |
| Árvore | limpa |

Arquivos: `functions/src/autoridade.ts` (novo),
`functions/scripts/provisionar_claim_motor_partidas.js` (novo), duas suítes
novas em `functions/test/`, e três alterados —
`functions/src/rastreabilidade.ts` (só o `import` da guarda extraída),
`functions/package.json` (alvos de teste) e `firebase.json` (`ignore`).
