# Plano de ativação controlada — credencial do motor V1

> **Este documento não ativa nada.** Ele é o roteiro para a janela operacional
> futura, e foi escrito por uma OS **somente leitura**: zero deploy, zero claim,
> zero Railway, zero Firebase produtivo, zero smoke, zero segredo lido.

---

## 0. Veredito

# BLOCKED — PRÉ-CONDIÇÃO OPERACIONAL NÃO COMPROVADA

O roteiro abaixo está **completo e executável**, e passa a valer no instante em
que a pré-condição §2 for fechada. O que impede autorizar a ativação "amanhã" não
é falta de plano — é que **o código que a ativação precisa exercitar não está em
lugar nenhum que a ativação alcance**.

A evidência impossível de produzir hoje, e só ela:

> **O app/Functions não tem alvo implantável.** Há linhagens incomparáveis
> carregando autoridades distintas — credencial, moderação, Billing/RTDN, P0 —
> e nenhuma folha do repositório carrega todas. O smoke chamaria uma Function
> cujo dono não está decidido.

**O lado do servidor foi canonizado** (`3016f64`, §1) e não bloqueia mais: a
credencial tem consumidor real e o commit implantado é observável por
`GET /versao`. Detalhamento em §2.4-bis e §2.5.

> Histórico: as §2.2 e §2.3 abaixo descrevem o estado da OS anterior, quando o
> produtor ainda não tinha consumidor. Ficam registradas porque explicam **por
> que** o alvo do servidor mudou — não porque ainda valham.

Tudo o mais desta OS está fechado.

---

## 1. Entradas

| Papel | Repositório | Branch | SHA |
|---|---|---|---|
| **Servidor — ALVO IMPLANTÁVEL** | `soniaambrosio/buraco-servidor` | `homologacao/alvo-operacional-credencial-v1` | `3016f647e8ab4e8def3677868c3b309ddaee7763` |
| Servidor — referência homologada | `soniaambrosio/buraco-servidor` | `integracao/credencial-motor-v2-auditoria-uuid-v1` | `c8ab95c427cfb66d3cd6d6c991a3ff617b45a637` |
| App — requisito de credencial | `soniaambrosio/buraco-master-vip-app` | `correcao/credencial-motor-contrato-runbook-v2` | `c3d6ab98795ca49deaaa9e2e974c95d07bfe8467` |
| **App — ALVO IMPLANTÁVEL** | — | — | **NÃO CANONIZADO — ver §2.5** |

Resolvidos por dois caminhos independentes (`git ls-remote` e REST API do GitHub),
concordantes.

**O alvo do servidor mudou** na OS de canonização: `3016f64` descende de
`274c50d` (`integracao/mesa-privada-vip-individual-v1`), que **contém** `deed131`,
`fd99260` e `e4bad52`, e cujo `credencial_motor` e `auth_firebase` são **byte a
byte idênticos** aos homologados em `c8ab95c`. Sobre ele foi acrescentada a prova
de SHA (§3). Suíte: 379/379.

Não usar: `deed131` isolada · `72bc99c` (commit de merge) · `85d0eee` (base) ·
`c8ab95c` como alvo de deploy (é a **referência** homologada, e não tem o
consumidor da credencial).

### Revalidação por leitura (Gate Zero §3.4)

| Invariante | Onde | Estado |
|---|---|---|
| receptor exige `checkRevoked: true` | `functions/src/autoridade.ts` — `verificadorComRevogacao` chama `auth.verifyIdToken(token, true)` | ✅ |
| receptor decide sobre o token **verificado**, não sobre `req.auth` | `conferirAutoridadeDePartida`, passo 4 | ✅ |
| produtor exige JWT estrito (3 segmentos base64url não vazios) | `partesDoToken`, módulo `auth_firebase` | ✅ |
| `project_id` do envelope não decide confiança | `interpretarResposta` — o campo não é lido; `FALHA.PROJETO_DIVERGENTE` não existe | ✅ |
| `motorDePartidas === true` estrito nos dois lados | `conferirSanidade` (`p[CLAIM] !== true`) e `autorizaComoMotorDePartidas` (`=== true`) | ✅ |
| grafia do claim idêntica | produtor `CLAIM` = receptor `CLAIM_MOTOR_DE_PARTIDAS` = `"motorDePartidas"` | ✅ |

### Runbook — 12/12

Conferido em `docs/CREDENCIAL-MOTOR-BOOTSTRAP-E-REVOGACAO-V1.md`: pré-requisitos,
dry-run, concessão (por referência ao runbook irmão), inspeção, bootstrap,
Railway, smoke identificável e reversível, rollback, corte com token cacheado,
rotação em 90 dias, vazamento em seis tempos, limitação da junta. O smoke real
segue marcado **NÃO EXECUTADO** nas três seções.

---

## 2. A pré-condição que bloqueia — e o que fecha ela

### 2.1 Nenhuma das duas entradas está em `main`

| | `main` | contém a entrada? |
|---|---|---|
| app | `fb9edb5` | **NÃO** |
| servidor | `1828d42` | **NÃO** |

Consequência direta no passo 8 (smoke): `registrarEncerramentoPartida` **em
produção** é a versão de `main`, que **não** tem `conferirAutoridadeDePartida`
com `checkRevoked`. Um smoke contra ela mediria o receptor antigo. Pior: o smoke
negativo §9.4 ("token de sessão revogada deve recusar") **falharia** — e falharia
por ausência de deploy, não por defeito, o que é exatamente o tipo de resultado
que faz uma equipe concluir errado que o corte funciona.

### 2.2 Na linhagem de entrada, o produtor não é carregado por ninguém

Em `c8ab95c`, `credencial_motor` **não é requerido por módulo nenhum**. O
`ws_server` carrega `servidor`, `contas`, `outbox` e `auth_firebase` — e não a
credencial. Ela é, ali, código alcançável só por `require` manual.

Isso não invalida a credencial (a rehomologação a aprovou), mas muda o que a
ativação significa: **subir `c8ab95c` no Railway com as quatro variáveis não faz
o servidor pedir token nenhum.** O passo 7 só acontece por invocação manual
dentro do contêiner.

### 2.3 Existe uma linhagem onde o produtor É consumido — e não é esta

`soniaambrosio/buraco-servidor`, branch **`integracao/gate-vip-credencial-backend-v1`**
(`e4bad52`): ali `ws_server` faz
`const { criarCredencialDoMotor } = require("./credencial_motor")` e a usa no
adaptador de admissão VIP. O `credencial_motor` dessa branch bate byte a byte com
o das entradas.

**Julgamento explícito sobre o STOP do §3 da OS:** essa branch **não** é uma
"ativação operacional já implementada/publicada". Ela é implementação de
*consumidor*, e o seu próprio laudo declara "zero deploy · zero segredo · zero
ativação". Não existe, em nenhum dos dois repositórios, branch com roteiro de
ativação, credencial provisionada ou smoke executado. Portanto **o STOP não
dispara** e não há roteiro paralelo sendo recriado.

Mas a decisão de **qual linhagem ativar** é da proprietária, e muda o objetivo:

| Alvo | O que a ativação entrega |
|---|---|
| `c8ab95c` (entrada mandatada) | prova a credencial e **fecha a junta** produtor→Google→receptor. Nenhum comportamento de produção muda. |
| linhagem com `e4bad52` | além disso, liga a credencial ao gate VIP — e passa a ter efeito em produção. |

Este plano é escrito para o **primeiro** alvo, que é o que a OS mandou e o que
tem menor superfície.

### 2.4-bis O que a OS de canonização RESOLVEU

Duas das três travas caíram:

| Trava | Estado |
|---|---|
| produtor sem consumidor | **RESOLVIDA.** O alvo `3016f64` liga a credencial: `ws_server` a constrói **uma vez** e a passa ao adaptador de admissão VIP, que põe o ID token no cabeçalho da chamada ao backend. Provado por comportamento, não por leitura. |
| SHA de produção não observável | **RESOLVIDA no servidor.** `GET /versao` devolve o commit implantado, derivado de variável **injetada pela plataforma**. Ver §3. |
| entradas fora de `main` | **CONTINUA ABERTA** — e agora com um agravante, o §2.5. |

### 2.5 O alvo de Functions NÃO existe

Medido sobre 152 pontas publicadas do repositório do app. Para o codebase
`functions/` (torneios — onde vivem a guarda de autoridade, conquistas e
rastreabilidade) há **linhagens incomparáveis**, e nenhuma folha carrega todas as
autoridades:

| Autoridade | Onde vive | A linhagem da credencial contém? |
|---|---|---|
| credencial + guarda com `checkRevoked` | `docs/plano-ativacao-credencial-motor-v1` | — (é ela) |
| economia | contido | ✅ |
| coleções / kit pioneiros | contido | ✅ |
| **moderação / chat** | `claude/chat-transporte-real-v1` | ❌ |
| **Billing / RTDN** | duas linhagens independentes | ❌ |
| **P0 final integrada** | `homologacao/p0-final-integrada` | ❌ |

A melhor folha do repositório carrega **4 de 7** autoridades. A linhagem da
credencial carrega **3 de 7**. **Não existe branch que seja o alvo de produção
das Functions**, e escolher `main` não resolve: `main` (`fb9edb5`) não contém a
credencial nem as demais.

Consequência para esta janela: os passos 8, 9 e 14 — smoke, identidade gravada e
recusa do token cacheado — dependem de uma Function implantada que hoje **não
tem dono**. Até que uma OS de composição produza esse alvo, a janela não abre.

### 2.4 O que fecha a pré-condição

Uma OS separada, anterior a esta janela, que **componha e implante**:

1. app: linhagem contendo `c3d6ab9` implantada em `buraco-master-vip`, com
   `registrarEncerramentoPartida` servindo a guarda com `checkRevoked`;
2. servidor: `c8ab95c` implantado no Railway;
3. prova de qual SHA está em produção nos dois lados — hoje isso não é
   observável, e é pré-requisito de todo o §14 (ABORT).

Enquanto (1), (2) e (3) não existirem, **não autorizar a janela**.

---

## 3. Mapa de componentes

Nomes e responsabilidades. **Nenhum valor de segredo.**

### Firebase

| Item | Valor |
|---|---|
| Projeto | `buraco-master-vip` |
| Região das Functions | `southamerica-east1` |
| Function **receptora** do smoke | `registrarEncerramentoPartida` (callable, `opcoesServidor` — **sem** App Check, porque quem chama é servidor, não app) |
| Guarda de autoridade | `conferirAutoridadeDePartida` (biblioteca, **não** é Function — `index.ts` não a reexporta) |
| Provisionamento | `functions/scripts/provisionar_claim_motor_partidas.js` — **script administrativo**, roda sob credencial do operador. Não é Function implantada. |
| Bootstrap da credencial | `functions/scripts/bootstrap_credencial_motor.js` — idem |
| Claim exigido | `motorDePartidas`, booleano `true` estrito |
| Coleções que o smoke pode tocar | `matches/{matchId}`, `matches/{matchId}/events/*`, `rankingLedger`, `fraudSignals`, `users/{uid}/matchHistory/{matchId}`, `playerAchievements/{...}/items/*` |
| Caminho da revogação | `admin.auth().revokeRefreshTokens(<UID>)` + `provisionar… revoke` |

> Os 11 exports do entrypoint são a superfície de implantação. Um export a mais
> vira Cloud Function; conferir a contagem antes de qualquer deploy.

### Servidor / Railway

| Variável | Natureza |
|---|---|
| `FIREBASE_MOTOR_REFRESH_TOKEN` | **SENSÍVEL** — é a credencial. Único material secreto desta ativação. |
| `FIREBASE_WEB_API_KEY` | semi-pública (viaja no app), mas tratar como segredo de configuração |
| `FIREBASE_MOTOR_UID` | configuração — identifica o UID técnico |
| `FIREBASE_PROJECT_ID` | configuração pública — **já existia** (WS-AUTH) |

- **Inicialização:** `lerConfiguracao` roda na construção do provedor. Falta uma
  → falta tudo: `obterIdToken()` rejeita com `SEM_CONFIGURACAO` e **não vai à
  rede**. Fail-closed comprovado (caso I28 da rehomologação).
- **Cache/refresh:** token em memória, renovado quando falta menos que a margem
  de **5 minutos** para o `exp` **do próprio token** (não o `expires_in` do
  corpo). Chamadas concorrentes compartilham um único voo. Falha descarta o token
  em memória. Rotação do refresh token é absorvida em memória; reiniciar o
  processo volta ao segredo do Railway, que é a fonte da verdade.
- **Nada em disco, nada em log**, nos dois sentidos.
- **Prova do commit implantado:** `GET /versao` → `{"sha","origem"}`. O valor sai
  de variável **injetada pela plataforma** (`RAILWAY_GIT_COMMIT_SHA`,
  `SOURCE_VERSION`, `GIT_COMMIT_SHA`), validada com forma de SHA de git (7–40
  hexadecimais); qualquer outra coisa vira `null`, nunca texto ecoado. **Não há
  fonte que o operador digite** — uma variável escrita à mão provaria o que
  alguém escreveu, e não o que foi implantado. O cliente não escolhe nada: query,
  cabeçalho e corpo não mudam a resposta. Suíte `test/versao_sha.test.js`,
  11 casos.
- **Do lado do Firebase não existe mecanismo equivalente.** `K_REVISION` do Cloud
  Run identifica a revisão, não o commit de origem. Fechar isso é parte da OS de
  composição das Functions (§2.5) — sem alvo canonizado, não há onde implementar.

### Operador — o que é humano e o que é automático

| Passo | Natureza |
|---|---|
| criar/eleger o UID técnico | **humano**, console Firebase |
| conceder o claim | humano dispara o script; a escrita é automática |
| bootstrap da credencial | humano dispara; emissão e gravação automáticas |
| copiar para o Railway | **humano**, e é o único momento em que o segredo é manipulado |
| apagar o arquivo local | **humano** |
| subir o serviço | automático (deploy do Railway) |
| obter ID token / smoke | **humano**, invocação controlada |
| censo, limpeza, inspeção de log | humano |
| revogação | humano |

---

## 4. Autoridade de concessão

| Pergunta | Resposta |
|---|---|
| Quem pode conceder `motorDePartidas` | quem tiver credencial administrativa do projeto — `GOOGLE_APPLICATION_CREDENTIALS` apontando para chave **fora** do repositório, ou `gcloud auth application-default login`. Hoje: a titular do projeto. |
| Para qual UID | o **UID técnico dedicado**, `<UID_DO_MOTOR>`. Nunca uma conta de jogador, nunca a conta da titular. |
| Por qual mecanismo | `functions/scripts/provisionar_claim_motor_partidas.js grant` |
| Como provar booleano `true` | `… inspect` devolve `concedido` **apenas** se `claims[CLAIM] === true`. `"true"`, `1`, `"1"` e `{}` são reportados como ausente e **corrigidos** pelo `grant`. |
| Como verificar que não nasceu claim paralelo | o plano do `grant` imprime `preservados` — a lista ordenada dos claims alheios. Comparar com o `inspect` de antes: tem de ser **idêntica**. `setCustomUserClaims` sobrescreve o mapa inteiro; é essa lista que prova que nada sumiu e nada nasceu. |
| Como remover o claim | `… revoke --commit --confirmar-projeto <PROJETO>` — **remove a chave**, não grava `false`. |
| Como revogar sessões | `admin.auth().revokeRefreshTokens(<UID_DO_MOTOR>)` |

**Travas do provisionador**, todas verificadas: ensaio é o padrão; `inspect`
recusa `--commit`; `grant`/`revoke` exigem `--confirmar-projeto` **idêntico** a
`--project` (dupla digitação); nenhuma flag de senha, provedor ou chave de
serviço existe.

---

## 5. Sequência de ativação

Cada passo tem **precondição · ação · prova · rollback**. Placeholders em
`<MAIÚSCULAS>`. Nenhum valor real aparece aqui.

### Passo 1 — Censo ANTES

- **Precondição:** §2 fechada; SHAs de produção conhecidos e iguais aos aprovados —
  no servidor isto se **lê**, não se afirma: `curl <HOST>/versao`.
- **Ação:** contar documentos nas seis coleções da §3 e registrar `T0` (UTC).
  Registrar também o `estado()` do provedor, se o serviço já estiver no ar.
- **Prova:** seis números escritos, com hora. Sem eles a limpeza (passo 11) não
  tem como ser conferida.
- **Rollback:** n/a — leitura pura.

### Passo 2 — Identidade técnica

- **Precondição:** UID técnico existe e **não** é conta de jogador.
- **Ação:** eleger/anotar `<UID_DO_MOTOR>`.
- **Prova:** `inspect` responde para esse UID; e o UID **não** aparece em
  `users/`, ranking, economia ou histórico de partidas.
- **Rollback:** n/a.
- **ABORT** se o UID já tiver `motorDePartidas` e ninguém souber quem concedeu.

### Passo 3 — Concessão do claim

- **Precondição:** passo 2 provado; credencial administrativa no ambiente.
- **Ação:**

```bash
# ENSAIO primeiro — não escreve
node scripts/provisionar_claim_motor_partidas.js inspect \
  --project <PROJETO> --uid <UID_DO_MOTOR>

node scripts/provisionar_claim_motor_partidas.js grant \
  --project <PROJETO> --uid <UID_DO_MOTOR>

# só então, a escrita
node scripts/provisionar_claim_motor_partidas.js grant \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --commit --confirmar-projeto <PROJETO>
```

- **Prova:** `inspect` responde `concedido`; a lista `preservados` é **idêntica**
  à do ensaio.
- **Rollback:** `revoke --commit --confirmar-projeto <PROJETO>`. **Totalmente
  reversível.**

### Passo 4 — Material de bootstrap

- **Precondição:** passo 3 provado; diretório privado **fora** do repositório.

```bash
mkdir -m 700 -p ~/.bmv-credenciais      # o script NÃO cria diretório
export FIREBASE_WEB_API_KEY=...          # nunca em argumento

node scripts/bootstrap_credencial_motor.js \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --saida ~/.bmv-credenciais/motor.env    # ENSAIO

node scripts/bootstrap_credencial_motor.js \
  --project <PROJETO> --uid <UID_DO_MOTOR> \
  --saida ~/.bmv-credenciais/motor.env \
  --commit --confirmar-projeto <PROJETO>
```

- **Prova:** o ensaio termina sem emitir nada; a gravação imprime o destino e o
  modo. **Em POSIX, `0600`.** Em Windows o script avisa em voz alta que o modo
  **não valeu** e que a proteção é a ACL — se aparecer "modo pedido", a máquina
  não sustenta a promessa.
- **Rollback:** apagar o arquivo **e** revogar sessões (passo 13), porque o
  refresh token já existe a partir daqui.
- **PONTO DE VIRADA:** a partir deste passo existe material vivo no mundo.

### Passo 5 — Instalar no Railway

- **Precondição:** passo 4 provado; arquivo ainda não copiado para lugar nenhum.
- **Ação:** criar/atualizar os quatro segredos do §3 no Railway. **Aplicar de uma
  vez.** Em seguida **apagar** o arquivo local.
- **Prova:** os quatro nomes existem no painel; o arquivo local não existe mais.
- **Rollback:** remover as variáveis; o serviço volta a `SEM_CONFIGURACAO`, que é
  fail-closed.

### Passo 6 — Subida controlada

- **Precondição:** passo 5 aplicado.
- **Ação:** deixar o serviço reiniciar com o ambiente novo.
- **Prova:** o serviço sobe; `estado()` reporta `configurada: true`,
  `faltando: []`, `temToken: false`, `renovacoes: 0`.
- **Rollback:** remover as variáveis e reiniciar.
- **Nota da §2.2:** em `c8ab95c` **nada** pede token sozinho. `renovacoes` ficar
  em 0 aqui é o **esperado**, não um defeito.

### Passo 7 — Obter o ID token

- **Precondição:** passo 6 provado.
- **Ação:** invocação controlada no contêiner —
  `require("./server.js").require("credencial_motor")`, construir o provedor e
  chamar `obterIdToken()` **uma vez**.
- **Prova:** resolve; `estado().temToken === true`, `renovacoes === 1`,
  `expiraEmMs` a mais de 5 min de distância. **Ler `estado()` inteiro e conferir
  que nenhum campo carrega token, prefixo ou hash.**
- **Rollback:** nenhum efeito externo — o token só existe em memória.
- **Se falhar**, ler o código pela tabela §7.2 do runbook: `SEM_CONFIGURACAO`,
  `HTTP 400/403`, `UID_DIVERGENTE`, `AUDIENCE_INVALIDO`/`ISSUER_INVALIDO`,
  `SEM_AUTORIDADE`, `EXPIRACAO_INVALIDA`. **`PROJETO_DIVERGENTE` não pode
  aparecer** — se aparecer, alguém restaurou a comparação que quebrava a
  credencial: ABORT.

### Passo 8 — Smoke autenticado

Definido por inteiro em §6. Precondição: passo 7 provado e censo do passo 1 em
mãos.

### Passo 9 — Confirmar a identidade gravada

- **Ação:** ler `matches/<MATCH_ID_DE_TESTE>`.
- **Prova:** o documento existe **e o autor é `<UID_DO_MOTOR>`** — não `admin`,
  não um jogador. É esta a asserção que prova que a autoridade veio da credencial
  e não de outra porta.
- **Rollback:** passo 11.

### Passo 10 — Inspeção de logs

Definida em §8. Janela `T0 → agora`, nos dois lados.

### Passo 11 — Limpeza

- **Ação:** apagar, **nesta ordem**, e sempre `delete`, nunca `update`:

```text
1. matches/<MATCH_ID_DE_TESTE>/events/*        (subcoleção primeiro)
2. matches/<MATCH_ID_DE_TESTE>
3. rankingLedger        — lançamentos com esse matchId
4. fraudSignals         — sinais com esse matchId
5. users/<UID_DE_TESTE>/matchHistory/<MATCH_ID_DE_TESTE>
6. playerAchievements   — só se o smoke tiver disparado conquista
```

- **Prova:** passo 12.

### Passo 12 — Validação pós-limpeza

- **Prova:** as seis coleções voltam **exatamente** à contagem do passo 1. Um
  smoke que não some é um smoke que sujou o ranking de produção.
- **Rollback:** se algo não some, **parar** e tratar como incidente de dados —
  não seguir para a revogação com sujeira no banco.

### Passo 13 — Revogação de teste

> **LEIA A §7 ANTES.** Este passo derruba a identidade inteira.

- **Precondição:** passos 11 e 12 provados; bootstrap de reposição **preparado**;
  janela combinada.
- **Ação:** registrar `estado()` (para que "recusou" não se confunda com "renovou
  no meio"), então `revokeRefreshTokens(<UID_DO_MOTOR>)` e, em seguida,
  `provisionar… revoke --commit --confirmar-projeto <PROJETO>`.
- **Prova:** passo 14.
- **Rollback:** não existe "desfazer revogação". O caminho de volta é o passo 15.

### Passo 14 — O token antigo deixa de autorizar

- **Ação:** com o token **ainda em cache** (sem forçar renovação), chamar
  `registrarEncerramentoPartida`.
- **Prova, e são duas:**
  1. `estado().renovacoes` **não subiu** — é o token velho que foi apresentado;
  2. a chamada é **recusada**, e o censo das seis coleções mostra **zero**
     escritas.
- Se a chamada for **aceita**: `checkRevoked` não está valendo em produção.
  **ABORT** e abrir OS.
- **Complemento:** forçar renovação. A troca no Secure Token deve **falhar** (o
  refresh token foi revogado). Se ainda devolver token, conferir o payload: ele
  **não** pode carregar `motorDePartidas`.

### Passo 15 — A credencial nova volta a funcionar

- **Ação:** repetir passos 3 → 4 → 5 → 6 → 7, e o smoke da §6.
- **Prova:** smoke PASS de novo, com `<MATCH_ID_DE_TESTE>` **novo**, e limpeza
  conferida de novo.
- **Só depois deste passo a janela está fechada.**

---

## 6. Smoke positivo

| | |
|---|---|
| **Function** | `registrarEncerramentoPartida` (`southamerica-east1`) |
| **Chamador** | o servidor, com `Authorization: Bearer <ID_TOKEN_DO_MOTOR>` |
| **Identidade** | `<UID_DO_MOTOR>` |

**Payload sintético** — a Function exige `plano.registro` com `matchId` e
`estado`:

```jsonc
{
  "plano": {
    "registro": {
      "matchId": "smoke-<AAAAMMDD>-<HHMM>-<INICIAIS>",
      "estado": "<ESTADO_MINIMO_QUE_O_CONTRATO_ACEITA>",
      "jogadores": ["<UID_DE_TESTE_1>", "<UID_DE_TESTE_2>"],
      "pontuacao": "<A MINIMA QUE O CONTRATO ACEITA>"
    }
  }
}
```

Regras do artefato:

- `matchId` **tem** de começar com `smoke-` — é o prefixo que o torna varrível e
  apagável;
- jogadores são **identidades de teste do projeto**, nunca contas reais;
- **nunca** usar `matchId` de partida real, nem reaproveitar um `matchId` de smoke
  anterior (a Function é idempotente e devolveria `jaRegistrado`, mascarando o
  resultado).

**Documentos que PODEM nascer:** os seis da §5 passo 11 — e nenhum outro.

**PASS do smoke** exige as quatro coisas, juntas:

1. a chamada retorna aceite, **sem** `permission-denied`;
2. `matches/<MATCH_ID_DE_TESTE>` existe e o **autor é `<UID_DO_MOTOR>`**;
3. nenhum documento nasceu **fora** da lista permitida;
4. a varredura de log da §8 vem limpa.

Falhar qualquer uma é FAIL do smoke — e FAIL manda para o rollback, não para
"tentar de novo".

---

## 7. Smoke negativo — obrigatório

O caminho feliz sozinho não prova defesa. Preparar, **sem executar agora**:

| # | Caso | Como montar | Esperado |
|---|---|---|---|
| 9.1 | **sem claim** | UID de teste **sem** `motorDePartidas`; token novo dele | recusa |
| 9.2 | **claim truthy inválido** | conceder `"true"` e `1` **por escrita direta** num UID de teste (não pelo `grant`, que corrige) | recusa nos dois |
| 9.3 | **token expirado** | guardar um ID token e usá-lo depois do `exp` | recusa |
| 9.4 | **sessão revogada** | passo 14 da §5 | recusa, e `renovacoes` não sobe |
| 9.5 | **UID divergente** | token de um UID, `req.auth` de outro | recusa por identidade divergente |
| 9.6 | **bearer ausente/malformado** | sem cabeçalho; `bearer` minúsculo; dois espaços; token vazio; `Basic` | recusa em todos |
| 9.7 | **credencial antiga após rotação** | guardar o refresh token antigo; após o passo 15, tentar trocá-lo | a troca falha |

Todos contra **identidades de teste**. Em **nenhum** caso pode nascer documento —
conferir com o censo depois de cada um.

> 9.2 exige escrita direta de claim malformado. Fazer isso **apenas** em UID de
> teste, e removê-lo ao final. Nunca no `<UID_DO_MOTOR>`.

---

## 8. Logs

Correlacionar, na janela `T0 → fim`, nos dois lados (Railway e Cloud Logging):

| Evento | Onde | O que confirma |
|---|---|---|
| início do servidor | Railway | subiu com o ambiente novo |
| renovação | Railway | `renovacoes` subiu de 0 para 1 |
| rejeição | ambos | o código de falha, e **só** o código |
| smoke | Cloud Logging | uma invocação de `registrarEncerramentoPartida` com o UID do motor |
| revogação | ambos | a recusa do passo 14 |

### Checklist de padrões PROIBIDOS no log

Varrer a janela inteira. **Qualquer ocorrência é incidente de vazamento** (§9):

- [ ] refresh token, inteiro ou em prefixo
- [ ] ID token, inteiro ou em prefixo
- [ ] custom token
- [ ] `FIREBASE_WEB_API_KEY` / qualquer `AIza…`
- [ ] `ya29.…`
- [ ] cabeçalho `Authorization:` com valor
- [ ] corpo de resposta do Secure Token
- [ ] bloco `BEGIN … PRIVATE KEY`
- [ ] despejo de ambiente completo (**não** rodar Firebase CLI com `--debug` na
      janela, por isso)

O módulo, por construção, não escreve em `console` e não interpola resposta
remota em mensagem de erro. O checklist existe para pegar quem **chamar** o
módulo errado, não o módulo.

---

## 9. Vazamento — roteiro emergencial

Se **qualquer** material sensível aparecer, em qualquer passo. Não existe
"rotacionar depois com calma".

```text
T+0  PARAR    — suspender o uso; não fazer mais chamadas.
T+0  CORTAR   — revokeRefreshTokens(<UID_DO_MOTOR>)
                provisionar… revoke --commit --confirmar-projeto <PROJETO>
                As DUAS: a primeira mata o que circula, a segunda impede a próxima.
T+0  AVISAR   — a titular do projeto e quem opera o Railway.
T+1  CONTER   — remover o secret do Railway; se vazou por log, purgar o log; se
                por arquivo, apagar em TODAS as cópias.
T+2  INSPECIONAR — janela: da primeira exposição possível até T+0.
                • Cloud Logging de registrarEncerramentoPartida com o UID do motor,
                  agrupado por origem — origem inesperada = uso indevido;
                • matches com autor do motor no período, comparado com o que o
                  servidor de fato encerrou;
                • rankingLedger e fraudSignals no mesmo intervalo;
                • Auth: eventos de troca de token do UID.
                "Nada encontrado" só vale ESCRITO, com a janela declarada.
T+3  REEMITIR — bootstrap novo, secret novo.
T+4  REPARAR  — reverter escritas indevidas achadas em T+2.
T+5  ESCREVER — como vazou, e o que muda para não repetir.
```

Depois de T+3, **repetir o smoke da §6**, e só então declarar o serviço bom.
Confirmar, ao final, que o material antigo **não funciona**: a troca do refresh
token revogado tem de falhar.

---

## 10. Ponto de não retorno

| Ação | Classe |
|---|---|
| censo, `inspect`, ensaios, leitura de log | **totalmente reversível** — não escreve |
| `grant --commit` | **totalmente reversível** — `revoke` desfaz |
| bootstrap `--commit` | **impacto imediato** — cria material vivo. Reverter exige revogar. |
| escrever segredos no Railway | **reversível com janela** — remover devolve o fail-closed |
| smoke | **reversível com janela** — os seis deletes da §5 passo 11 |
| `revokeRefreshTokens` | **DESTRUTIVA para a sessão técnica** |
| `revoke` do claim | reversível, mas só junto com reemissão |

### A armadilha, escrita para não ser esquecida

**`revokeRefreshTokens(<UID>)` derruba a identidade INTEIRA — inclusive a
credencial que você acabou de gerar.** Não existe revogação seletiva de refresh
token no Firebase Auth.

A sequência **errada**, que parece certa:

```text
gerar nova  →  revogar antiga  →  descobrir que revogou a nova junto
```

A ordem **correta**, e é a da §5:

```text
… → 13 REVOGAR  →  14 PROVAR que o antigo não autoriza
                →  15 REEMITIR (grant → bootstrap → Railway → token → smoke)
```

A reemissão é **passo obrigatório do roteiro**, não uma nota de rodapé. Quem
pular o passo 15 fica com o servidor sem credencial e sem entender por quê.

---

## 11. Rollback — "deu errado no minuto 7"

Roteiro independente. Para cada caso: **parar → revogar → remover → restaurar →
provar.**

| Caso | Parar | Revogar | Remover | Restaurar | Provar |
|---|---|---|---|---|---|
| variável do Railway errada | suspender chamadas | — | corrigir/remover a variável | reaplicar as quatro | `estado()`: `configurada: true`, `faltando: []` |
| token não obtido | suspender | — | — | ler o código pela tabela §7.2 e corrigir a **configuração** | `obterIdToken()` resolve; `renovacoes === 1` |
| token obtido, chamada recusada | suspender | — | — | conferir claim (`inspect`) e o SHA implantado do receptor | `inspect` = `concedido`; chamada aceita |
| chamada aceita com **identidade errada** | **parar tudo** | `revokeRefreshTokens` | secret do Railway | reemitir | autor em `matches` = `<UID_DO_MOTOR>` |
| log suspeito | suspender | — | — | ir para §9 antes de qualquer coisa | varredura da §8 limpa |
| credencial vazada | — | §9 inteira | — | — | material antigo não troca |
| **revogação acidental** | suspender | (já feita) | — | passo 15: grant → bootstrap → Railway → token | smoke PASS |
| servidor não inicializa | suspender deploy | — | variáveis novas | voltar ao deploy anterior | serviço no ar como antes |
| receptor indisponível | **não** seguir para o smoke | — | — | esperar/abrir incidente | `registrarEncerramentoPartida` responde |

Regra transversal: **rollback não inclui alterar código.** Se o retorno ao estado
anterior exigir mudar código, é ABORT + OS nova.

---

## 12. Janela operacional

Blocos, sem precisão falsa de segundos.

| Bloco | Passos | Ordem de grandeza | Alguém de plantão? |
|---|---|---|---|
| pré-checagem | 1–2 | dezenas de minutos | não |
| concessão | 3 | minutos | não |
| configuração | 4–6 | dezenas de minutos | **sim** — a partir do passo 4 há material vivo |
| smoke | 7–10 | dezenas de minutos | **sim** |
| limpeza | 11–12 | minutos a dezenas de minutos | **sim** |
| revogação e prova | 13–14 | dezenas de minutos | **sim, obrigatório** |
| reemissão e validação final | 15 | repete 3–10 | **sim, obrigatório** |

**Plantão para rollback imediato é obrigatório do passo 4 ao 15**, sem intervalo.
A outbox do servidor absorve os encerramentos do período; combinar a janela com
isso em mente. Não é um teste de terça-feira à tarde.

---

## 13. Critérios de ABORT

Abortar **imediatamente** — não improvisar, não corrigir na janela:

- [ ] SHA operacional diferente do esperado, em qualquer um dos dois lados
      (no servidor, `GET /versao` responde o commit; `null` ali é ABORT também —
      significa que a plataforma não injetou, e o que roda não é identificável)
- [ ] branch divergente aparecer no caminho da ativação
- [ ] produção já estiver usando credencial desconhecida
- [ ] o claim técnico já existir em identidade **não documentada**
- [ ] segredo com formato inesperado
- [ ] smoke produzir documento **fora** da lista permitida
- [ ] log expuser token de qualquer espécie
- [ ] UID observado não for `<UID_DO_MOTOR>`
- [ ] token revogado **continuar autorizando** no receptor
- [ ] o servidor precisar de **alteração de código** para funcionar
- [ ] `PROJETO_DIVERGENTE` aparecer em qualquer log

> **Nenhuma correção de código durante a janela.** Se código precisar mudar,
> abortar, restaurar pelo §11 e abrir OS.

---

## 14. A limitação que esta ativação existe para fechar

A junta **produtor → Google Secure Token → receptor** nunca foi medida, e não é
mensurável em emulador: ele emite `{"alg":"none"}`, e um token assinado por nós
mediria o nosso arnês, não o contrato do Google. As duas metades estão
verificadas separadamente — 59 casos independentes no produtor, 46 no receptor,
13/13 mutações detectadas, Rules 120/120.

**O smoke da §6 é a única prova possível dessa junta.** É por isso que ele é
obrigatório na janela, e é por isso que esta OS não o executou.

---

## 15. Checklist de completude do roteiro

Este documento só está íntegro se **todos** os blocos abaixo existirem. Uma
futura "limpeza de documentação" que apague qualquer linha desta tabela está
apagando metade do procedimento.

| Bloco | Seção | Presente |
|---|---|---|
| pré-condição | §2 | ✅ |
| ativação | §5 (15 passos) | ✅ |
| smoke positivo | §6 | ✅ |
| smoke negativo | §7 (7 casos) | ✅ |
| revogação | §5 passos 13–14, §10 | ✅ |
| rotação | §5 passo 15, runbook §8.3 | ✅ |
| vazamento | §9 (seis tempos) | ✅ |
| rollback | §11 (9 cenários) | ✅ |
| censo | §5 passos 1 e 12 | ✅ |
| logs | §8 (+ checklist de proibidos) | ✅ |
| limpeza | §5 passo 11 | ✅ |
| PASS final | §16 | ✅ |

Há um teste de controle que verifica esta presença:
`functions/test/plano_ativacao_completude.test.js`.

---

## 16. PASS final da janela

A ativação só pode ser declarada concluída quando **todas** forem verdade:

1. censo antes e depois **iguais** nas seis coleções;
2. smoke positivo PASS pelos quatro critérios da §6;
3. os sete smokes negativos da §7 recusaram, **cada um**, sem gerar documento;
4. token cacheado recusado após revogação, com `renovacoes` **inalterado**;
5. credencial reemitida funcionando (passo 15), com smoke novo PASS e limpo;
6. varredura de log da §8 sem **nenhum** padrão proibido;
7. `PROJETO_DIVERGENTE` não apareceu em lugar nenhum;
8. nenhuma alteração de código durante a janela.

Faltando qualquer uma: **não** declarar PASS. Rollback pelo §11 e OS nova.
