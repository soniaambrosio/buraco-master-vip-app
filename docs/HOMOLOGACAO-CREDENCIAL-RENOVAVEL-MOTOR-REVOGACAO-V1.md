# Homologação independente — Credencial renovável do Motor e revogação efetiva V1

> ## `FAIL`
>
> **A revogação passou inteira. A produção da credencial, não.**
>
> O receptor faz exatamente o que se exigiu dele: verifica o bearer bruto com
> `checkRevoked: true`, uma única vez, sem plano B, e recusa **antes** de tocar
> qualquer documento. Isso está provado ponta a ponta, contra Firestore real, por
> contagem de escritas.
>
> O que reprova é o outro lado da ponte. **A integração cruzada não fecha**: o
> módulo do servidor compara `project_id` da resposta do Secure Token com o
> `FIREBASE_PROJECT_ID`, e esse campo **não é o id do projeto**. Medido: o
> endpoint devolve `"12345"`. Com isso, o Railway nunca obtém token — falha
> fechada, sem risco de segurança, e sem funcionar.
>
> E o **runbook não está operacionalmente completo**: faltam três dos doze itens
> exigidos pela §11.
>
> **Zero deploy · zero ativação · zero PR · zero merge · zero secret alterado ·
> nenhuma credencial real criada ou exposta.**

| | |
|---|---|
| Laudo | `homologacao/credencial-renovavel-motor-revogacao-v1` |
| Base do laudo | `8b91388d88724b5f4d70118f1530a1ceea838057` |
| Data | 2026-08-17 |

---

## 1. Gate Zero — independência e refs

Cada uma das quatro refs foi resolvida por **duas** consultas `ls-remote`
independentes. As oito leituras concordaram.

| Papel | Ref | SHA resolvido (2×) | Exigido |
|---|---|---|---|
| App · candidata | `claude/bootstrap-credencial-motor-revogacao-v1` | `8b91388d88724b5f4d70118f1530a1ceea838057` | ✅ |
| App · base | `claude/provisionador-claim-motor-partidas-v1` | `831eb81cc55e67ce6c01a3cf4c592616559e968e` | ✅ |
| Servidor · candidata | `claude/credencial-renovavel-motor-railway-v1` | `85d0eee5286fd1deba5c2ae85176b76e714e6690` | ✅ |
| Servidor · base | `claude/versionamento-visao-autoritativa-v1` | `7e7572b3471bcec2a6968e6084f56dd407cef601` | ✅ |

### Ancestralidade e ausência de merges

```
app:  merge-base(831eb81, 8b91388) = 831eb81   (a base É o ponto de partida)
      e7339bf → b9dcafb → 5d9b524 → a38d08e → 8b91388     5 commits, 1 pai cada

srv:  merge-base(7e7572b, 85d0eee) = 7e7572b
      abda620 → 6cb4f3a → 616e68b → 85d0eee                4 commits, 1 pai cada
```

`git log --merges` devolve vazio nos dois intervalos. **Nenhum merge não
declarado.**

### Ambiente

`node v24.14.0` · `npm 11.9.0` · `firebase-tools 15.26.0` · `Dart 3.11.1` ·
`OpenJDK 21.0.9 (JBR)` · `MINGW64_NT-10.0-26200` / Windows 11.

### Isolamento

Quatro **worktrees novos e exclusivos**, criados para esta homologação e
descartáveis. Nenhum resultado, worktree, medição ou relatório da implementação
foi reaproveitado — as sondas desta homologação são código próprio, escrito do
zero, e vivem fora dos dois repositórios.

---

## 2. Inventário dos deltas

**Exatamente os declarados. Nenhum terceiro arquivo.**

| App (`831eb81..8b91388`) | |
|---|---|
| `A` | `docs/CREDENCIAL-MOTOR-BOOTSTRAP-E-REVOGACAO-V1.md` |
| `M` | `functions/package.json` |
| `A` | `functions/scripts/bootstrap_credencial_motor.js` |
| `M` | `functions/src/autoridade.ts` |
| `M` | `functions/src/rastreabilidade.ts` |
| `A` | `functions/test/bootstrap_credencial.test.js` |
| `A` | `functions/test/revogacao_receptor.test.js` |
| `A` | `functions/test/revogacao_receptor_integrado.test.js` |

| Servidor (`7e7572b..85d0eee`) | |
|---|---|
| `A` | `docs/CREDENCIAL-RENOVAVEL-MOTOR-V1.md` |
| `M` | `server.js` |
| `A` | `test/credencial_motor.test.js` |

### Conferências obrigatórias

| Item | Resultado |
|---|---|
| Exports do entrypoint | **11 na base, 11 na candidata**, os mesmos onze nomes |
| Cloud Function criada por acidente | nenhuma — `autoridade.ts` não é reexportado, `scripts/` fora de `tsconfig.include` e no `ignore` |
| `functions/package.json` | só alvos de teste; **nenhuma** dependência, `deploy` intocado |
| Dependência no servidor | **`package.json` do servidor não está no delta** — não mudou |
| `npm start` | `node server.js`, inalterado |
| Segredo versionado | nenhum arquivo `.pem`, `.key`, `.env`, `service-account*` em nenhuma das duas árvores |
| `firebase/`, `functions-economia/`, `app/` | **byte a byte idênticos** à base |

`autoridade.ts` é **somente adição**: `git diff` não tem uma única linha removida,
e `autorizaComoMotorDePartidas` é idêntica à da base.

---

## 3. Fronteira de confiança (§3)

Sonda própria: `sonda_receptor.js`, 28 casos, contra `lib/autoridade.js` compilado
da candidata.

| § | Exigência | Verificado por | Resultado |
|---|---|---|---|
| 3.1 | Railway guarda só refresh token + identificadores públicos | 4 variáveis, nenhuma é chave privada | ✅ |
| 3.2 | Servidor sem Admin SDK e sem chave privada | varredura da fonte: só o URL **público** de certificado x509 | ✅ |
| 3.3 | ID token nasce só da troca no endpoint oficial | sem transporte, sem token; `securetoken.googleapis.com/v1/token` | ✅ |
| 3.4 | `verifyIdToken(token, true)` | **32 invocações na sonda, 0 sem `checkRevoked === true`** | ✅ |
| 3.5 | Sem fallback, retry ou catch que reverifique sem a flag | ver abaixo | ✅ |
| 3.6 | `motorDePartidas === true`, booleano estrito | ver abaixo | ✅ |
| 3.7 | Autenticação válida sem a claim não concede autoridade | recusa com `sem_autoridade` | ✅ |
| 3.8 | Verificação antes de qualquer mutação | ver §6 — contagem de escritas | ✅ |

### 3.5 — a prova de que não há segunda verificação

A asserção não é sobre o resultado, e sim sobre a **contagem**. O dublê desta
sonda **aceita** quando a flag não vem — que é o comportamento de **produção**, e
o oposto do emulador. Se houvesse plano B, a autoridade seria concedida.

| Caso | Invocações | Resultado |
|---|---|---|
| token bom | 1 | autoriza |
| `auth/id-token-revoked` | **1** | recusa |
| `auth/id-token-expired` | 1 | recusa |
| `auth/argument-error` | 1 | recusa |
| `auth/invalid-id-token` | 1 | recusa |
| `auth/user-disabled` | 1 | recusa |
| `auth/internal-error` | 1 | recusa |
| `auth/network-request-failed` | 1 | recusa |
| exceção **síncrona** do SDK | 1 | recusa, sem escapar |
| bearer ausente ou malformado (18 formas) | **0** | recusa antes de chegar ao SDK |

### 3.6 — o quanto o `=== true` é estrito

Recusam: ausente, `false`, `"true"`, `"TRUE"`, `1`, `"1"`, `0`, `{}`, `[]`,
`"sim"`, **`new Boolean(true)`**, `suporte: true`, `admin: false`, `admin: "true"`.
Autorizam: `motorDePartidas: true` e `admin: true` (papel próprio, anterior à
entrega, fixado em teste).

Os quatro casos *truthy* — `{}`, `[]`, `"sim"`, `new Boolean(true)` — são os que
uma comparação frouxa deixaria passar. Nenhum passa.

---

## 4. Bootstrap administrativo (§4)

Sonda própria: `sonda_bootstrap.js`, **33 casos**, projeto e credenciais falsos.
Nenhum usuário, claim ou refresh token real criado.

| Exigência | Resultado |
|---|---|
| Ensaio é o padrão | ✅ `createCustomToken` chamado **0** vez; disco não tocado |
| Ensaio ainda valida projeto, uid, claim e destino | ✅ |
| `--project` ≡ `--confirmar-projeto`, literalmente | ✅ recusa maiúscula, espaço à esquerda/direita, um caractere a menos |
| Projeto resolvido pelo SDK também concorda | ✅ aborta **antes** de ler o usuário |
| Arquivo existente não é sobrescrito | ✅ e o conteúdo anterior fica intacto |
| Arquivo com permissão restritiva | ⚠️ parcial — ver achado **H** |
| Tokens nunca em stdout, stderr ou erro | ✅ em **todos** os 19 pontos de falha e no sucesso |
| Falha não deixa artefato parcial | ✅ 19 pontos, diretório byte a byte igual ao de antes |
| `uid`, `sub`, `aud`, `iss`, projeto e claim conferidos | ✅ |
| Verificação criptográfica **e com revogação** antes de aceitar | ✅ `verifyIdToken(idToken, true)` |
| Nenhum caminho entrega o segredo quando algo falha | ✅ |

### Os 19 pontos de falha enumerados

argumentos inválidos · destino no repositório · destino existente · sem Web API
Key · projeto resolvido diferente · usuário inexistente · claim ausente · claim
com tipo errado · erro ao emitir custom token · rede caiu · resposta truncada ·
JSON inválido · sem `refreshToken` · sem `idToken` · identidade divergente ·
verificação recusou · disco falhou · `fsync` falhou · `rename` falhou.

Em cada um: código de saída ≠ 0, **zero** arquivos novos ou remanescentes, e
nenhum fragmento de segredo na saída.

---

## 5. Cliente do Railway (§5)

Sonda própria: `sonda_cliente.js`, **45 casos**.

| Exigência | Resultado |
|---|---|
| Primeiro pedido obtém token | ✅ |
| Reutiliza dentro da janela segura | ✅ 1 pedido para 2 chamadas |
| Renova ao entrar na margem | ✅ medido nos dois lados: 1 s antes reutiliza, 1 s depois renova |
| Token expirado nunca é enviado | ✅ inclusive quando a renovação falha; o vencido é **descartado** |
| Concorrentes compartilham uma renovação | ✅ **250 chamadas → 1 pedido**, todas com o mesmo token |
| Falha libera a concorrência | ✅ lote inteiro falha junto com 1 pedido; a chamada seguinte tenta de novo |
| Timeout, conexão morta, resposta grande, JSON inválido, campos ausentes | ✅ todos fecham |
| Erros sem refresh token, ID token, API key ou `Authorization` | ✅ 6 cenários, mensagem **e** stack varridos |
| `sub`, `aud`, `iss`, projeto, UID divergentes recusados | ✅ |
| `"true"`, `1`, `{}`, claim ausente recusados | ✅ |
| Cache não sobrevive a troca de configuração | ✅ instâncias distintas, tokens distintos, pedidos distintos |
| Sem loop ilimitado de retry | ✅ 1 falha = 1 tentativa; sem `setInterval`, sem `setTimeout` agendado, sem laço |
| Servidor sobe sem a configuração do motor | ✅ `ws_server.iniciar` existe; nenhuma variável nova é exigida |

25 formas de resposta ruim foram exercitadas (HTTP 400/401/403/429/500/503/302,
JSON quebrado, campos faltando, `expires_in` inválido, identidade divergente).
Todas fecham com código tipado.

---

## 6. Revogação efetiva (§6) e a prova de §3.8

Sonda própria: `sonda_integrada.js`, **16 casos**, contra os emuladores de **Auth
e Firestore**, invocando `registrarEncerramentoPartida.run(...)` de verdade.

### A prova é a contagem de escritas, não a mensagem de erro

Censo de seis coleções antes e depois de cada chamada: `matches`,
`matches/{id}/events`, `rankingLedger`, `fraudSignals`, `playerAchievements`,
`users/{uid}/matchHistory`.

| Caso | Erro | Escritas |
|---|---|---|
| Token de sessão **revogada** | `permission-denied` | **0** |
| Sem a claim | `permission-denied` | **0** |
| **Bearer ausente, com `req.auth.token` completo e mentindo** | `permission-denied` | **0** |
| `req.auth` mentindo sobre a identidade | `permission-denied` | **0** |
| **Contraprova — token bom** | — | `matches +1`, `events +1`, `rankingLedger +1`, `fraudSignals +1`, `matchHistory +1` |

A contraprova é o que dá sentido às quatro linhas acima: sem ela, "zero escrita"
seria compatível com um plano que não escreve em situação nenhuma.

O terceiro caso é o ataque exato que a entrega fecha: antes dela, a decisão saía
de `req.auth.token`, e um chamador que apresentasse esse mapa sem bearer algum
teria escrito o próprio resultado.

### Matriz da §6

| Cenário | Exigido | Observado |
|---|---|---|
| Token válido, claim booleana | aceito | ✅ |
| Sem claim | recusado | ✅ `sem_autoridade` |
| Claim `false` | recusado | ✅ |
| Claim `"true"` | recusado | ✅ |
| Token inválido | recusado | ✅ `token_recusado` |
| Token expirado | recusado | ✅ |
| Token de **outro projeto** | recusado | ✅ *(motivo diverge — ver nota)* |
| Token de outro UID | recusado | ✅ `identidade_divergente` |
| Token **revogado** | recusado | ✅ |
| Token revogado **vindo do cache do Railway** | recusado pelo receptor | ✅ |
| Emissão posterior à revogação, sem claim | recusada | ✅ |
| Revogar sessões + remover claim | acesso encerrado | ✅ |

**Nota sobre "outro projeto".** Neste emulador, `verifyIdToken` de um projeto
aceita token de outro (o `aud` não barra), e a recusa acabou vindo do papel
(`sem_autoridade`). Em produção o `aud` barra antes. O que a §6 exige — **recusa**
— vale nos dois casos, mas o *motivo* observado aqui é artefato do emulador e
está registrado como tal, não como contrato.

### A divergência emulador × produção, tratada explicitamente

Este emulador recusa token revogado **mesmo sem** a flag. Por isso **nenhum**
resultado de emulador foi usado como prova de `checkRevoked`. A prova é a
contagem de invocações da §3.5, que roda sem emulador nenhum.

---

## 7. Poder de detecção (§7)

Doze mutações, aplicadas nos worktrees, medidas e revertidas. **Doze detectadas.**

| # | Mutação | Caso derrubado — sonda independente | Caso derrubado — suíte do repositório |
|---|---|---|---|
| 1 | remover o `true` de `verifyIdToken` | `H-R02`, `H-R03`, asserção global (26 invocações sem a flag) | `REC-06`, `REC-06c` |
| 2 | após recusa, reverificar sem `true` | `H-R02`, `H-R03`, `H-R04` (3 invocações sem a flag) | `REC-06c` **apenas** |
| 3 | aceitar qualquer *truthy* na claim | 8 casos `H-P-` | `REC-10`, `REC-11`, `REC-11b` |
| 4 | reutilizar token expirado do cache | `H-C11`, `H-C12` | `CRED-11`, `CRED-12`, `CRED-12b`, `CRED-15`, `CRED-15b` |
| 5 | remover a renovação antecipada | `H-C11` | `CRED-11` |
| 6 | permitir duas renovações simultâneas | `H-C13`, `H-C14` | `CRED-13`, `CRED-14`, `CRED-14b` |
| 7 | aceitar `aud`/`iss`/UID divergente | 5 casos `H-C2x` | `CRED-17`, `CRED-21` |
| 8 | imprimir refresh token em erro de transporte | `H-S04` | `CRED-32` |
| 9 | escrever o segredo em ensaio | `H-B01` | `BOOT-01`, `BOOT-02` |
| 10 | aceitar projeto confirmado ≠ resolvido | `H-B11`, `H-B2x` | `BOOT-13` |
| 11 | deixar arquivo parcial após falha | 3 casos `H-B2x`, `H-B36` | `BOOT-23` |
| 12 | **autorizar antes de concluir a verificação** | `H-E01`, `H-E02`, `H-E03`, `H-E04` — **com escritas reais acontecendo** | `REC-16b` |

Duas observações que valem mais que a tabela:

**A mutação 2 só é pega por um teste.** `REC-06c` é a única barreira da suíte do
repositório contra o plano-B sem flag — e ela existe porque essa mesma mutação
escapou da rodada anterior de defeitos injetados. Removê-la reabre o buraco.

**A mutação 12 é a que a §3.8 existe para pegar**, e só a sonda com Firestore real
mostra o dano: com ela aplicada, os quatro casos passam a **escrever** em
`matches`, `rankingLedger`, `fraudSignals` e `matchHistory` apesar da recusa.

Todas revertidas. As quatro árvores voltaram aos SHAs exatos, sem alteração
rastreada.

---

## 8. Regressão (§8)

Mesmo ambiente, worktrees separados.

| Suíte | Base | Candidata |
|---|---|---|
| `functions` · provisionador (puro) | **21** ✅ | **21** ✅ |
| `functions` · provisionador (emulador de Auth) | **14** ✅ | **14** ✅ |
| `functions` · conquista (Firestore) | **10** ✅ | **10** ✅ |
| `functions` · bootstrap | — | **39** ✅ |
| `functions` · receptor (puro) | — | **32** ✅ |
| `functions` · receptor (emulador) | — | **9** ✅ |
| `firebase/testes` · regras integradas | *idêntico*¹ | **120** ✅ |
| `functions-economia` | *idêntico*¹ | **63** ✅ |
| `tsc --noEmit` | ✅ | ✅ |
| Exports do entrypoint | **11** | **11** |
| Servidor · `npm test` | **181** ✅ | **228** ✅ |

¹ `firebase/` e `functions-economia/` **não estão no delta** — são byte a byte
idênticos à base, o que torna a execução na base uma repetição do mesmo binário.
Foram executados na candidata.

**Nenhuma regressão. 80 casos novos no app, 47 no servidor.**

---

## 9. O falso positivo do UUID (§9) — sonda determinística

`carimbarEstado` faz `sala.eventoId = crypto.randomUUID()`, e o arnês
`varrerSegredos` procura cada id de carta como **substring** de cada string do
payload. Um UUID é hexadecimal: se contiver `c1818`, o arnês acusa vazamento de
uma carta que não vazou. **É defeito de prova, não de código.**

### Determinístico, sem depender do acaso

| Entrada controlada | Achados |
|---|---|
| `eventoId = "9f2ac1818b7e4d5fa0c31d2e4b6a8c90"` | `["raiz.eventoId contém c1818"]` |
| `eventoId = "9f2af0f0b7e4d5fa0f31d2e4b6a8f90f"` | `[]` |

Idêntico nas duas árvores. Em 200 000 UUIDs, ~0,03 % contêm um de cinco ids alvo;
com ~108 cartas vivas e dezenas de eventos por partida, isso sobe para a casa de
poucos por cento por execução — que é o que se mede.

### Não foi introduzido pela candidata

Impressões digitais **idênticas** na base e na candidata:

| Artefato | sha256 (16 primeiros) |
|---|---|
| `carimbarEstado` | `cd4758c1bbbe1e17` |
| `test/ajuda.js` (`varrerSegredos`) | `6f35dbcb1def5bc8` |
| `test/espectador.test.js` | `4f90753bc9eb14a6` |

### Frequência medida nos worktrees limpos

| Árvore | Falhas | Execuções de `npm test` | Achados |
|---|---|---|---|
| Base `7e7572b` | **2** | 20 | `c1770`, `c1781` |
| Candidata `85d0eee` | **1** | 20 | `c1826` |

### Não mascara falha da credencial, e não contamina esta homologação

- O módulo `credencial_motor` **não usa** `randomUUID` e não é alcançado pelo
  caminho do espectador — e **ninguém o carrega**, então ele não participa de
  partida alguma.
- A suíte da credencial, isolada: **0 falhas em 30 execuções**.
- Nenhuma sonda desta homologação toca o caminho de espectador/costura.

**Não corrigido nesta OS**, conforme instruído.

---

## 10. Auditoria de segredos (§10)

| Item | Estado |
|---|---|
| Credenciais reais usadas ou impressas | **nenhuma** |
| Dump de ambiente anexado | **não** |
| `firebase-tools --debug` | **não usado nesta homologação** |
| Tokens em fixtures, snapshots ou relatório | **nenhum** — as sondas usam a marca própria `XX-HOMOLOG-SEGREDO-XX-` |
| Valor de secret neste laudo, mesmo parcial | **nenhum** |
| Identidades criadas | só no **emulador**, prefixos `hmlg-*`/`dbg-*`, removidas ao fim |
| Chamada contra projeto real | **nenhuma** |
| **Chave OpenAI exposta na execução anterior** | **revogada: sim** |

Varredura dos artefatos da homologação por `AIza…`, `BEGIN PRIVATE KEY`, `sk-…`,
`ya29.…` e JWT literal: **nenhuma ocorrência**.

---

## 11. Prontidão operacional (§11) — **9 de 12**

| # | Item | Estado |
|---|---|---|
| 1 | Criação/seleção da identidade dedicada | ✅ |
| 2 | Concessão estrita da claim | ✅ |
| 3 | Geração segura do refresh token | ✅ |
| 4 | Armazenamento como secret no Railway | ✅ |
| 5 | Variáveis públicas necessárias | ✅ |
| 6 | **Smoke test autenticado** | ❌ **ausente** |
| 7 | Renovação após expiração | ✅ |
| 8 | Corte emergencial: revogar sessões **e** remover claim | ✅ com a ordem correta e o porquê |
| 9 | **Verificar que o token cacheado passa a ser recusado** | ❌ **ausente como procedimento** |
| 10 | Rollback | ✅ |
| 11 | **Rotação periódica e resposta a vazamento** | ❌ só citado como risco residual |
| 12 | Nenhum token nos logs | ✅ |

Os itens 6 e 9 são os que fecham o laço operacional: sem eles, o operador ativa a
credencial e **não tem como saber se funcionou**, nem como confirmar que o corte
de emergência de fato cortou. O item 11 não tem procedimento — o documento diz
que trocar a credencial é rodar o bootstrap de novo, mas não define periodicidade
nem o que fazer diante de um vazamento.

---

## 12. Achados

### A — `project_id` não é o project ID · **BLOQUEANTE**

`interpretarResposta` recusa a resposta quando
`json.project_id !== FIREBASE_PROJECT_ID`.

**Medido contra o Secure Token do emulador:**

```
FIREBASE_PROJECT_ID esperado ... "bmv-homolog"
resposta.project_id ............ "12345"          ← número, não id
resposta.user_id ............... == uid (correto)
payload.aud .................... "bmv-homolog"    ← o id está AQUI
payload.iss .................... "https://securetoken.google.com/bmv-homolog"
```

Consequência: **`obterIdToken()` sempre lança `PROJETO_DIVERGENTE`.** O Railway
nunca obtém token e a cadeia nunca começa. Falha **fechada** — não há risco de
segurança —, mas a funcionalidade inteira fica inoperante, e isso só apareceria
na ativação.

**A produção não pôde ser medida** (nenhuma chamada real é autorizada). As duas
evidências disponíveis divergem: a referência de resposta do Identity Platform
descreve `project_id` como "Your Google Cloud project ID", enquanto a documentação
do próprio fluxo de refresh fala em validação por **project number**
(`PROJECT_NUMBER_MISMATCH`), e o emulador devolve um número. **A dúvida, sozinha,
já é bloqueante para ativação: o campo nunca foi exercitado contra o endpoint
real.**

**A suíte da implementação não pega isso** porque a fixture `respostaOk()`
codifica `project_id: PROJETO` — ela afirma a suposição em vez de testá-la.

**Recomendação.** Remover a comparação. Ela não acrescenta segurança: `user_id` já
é conferido, e `aud`/`iss` do próprio token — que **são** verificados, e são
criptograficamente ligados ao token — já prendem o projeto. Se a comparação for
mantida, aceitar tanto o id quanto o número, e registrar em teste **qual** dos
dois o endpoint real devolve.

### B — A cadeia cruzada é inverificável localmente · **impeditivo de prova**

Duas divergências do emulador travam a cadeia em **sentidos opostos**:

| Forma do token | Módulo do servidor | Receptor do app |
|---|---|---|
| Cru do emulador (`{"alg":"none"}`, assinatura **vazia**) | recusa `TOKEN_ILEGIVEL` | aceitaria |
| Com assinatura acrescentada (forma de produção) | aceita | **recusa** |

`partesDoToken` exige os três segmentos não vazios — correto para produção, onde
o token é RS256 assinado, e incompatível com o emulador, que nunca assina. **Não é
defeito da candidata**, mas significa que **a integração cruzada nunca foi
exercitada** — nem pela implementação nem por esta homologação.

O que **está** verificado são as duas metades separadamente: o produtor
(45 casos, resposta com forma de produção) e o receptor (16 casos, token do
emulador, guarda e Firestore reais).

### C — Runbook incompleto · **bloqueante por §12**

Itens 6, 9 e 11 da §11 ausentes.

### D — `--saida` igual à raiz escapa da primeira barreira · **menor**

`path.relative(raiz, raiz)` é a string vazia, e a condição exige `relativo !== ''`
para considerar "dentro do repositório". A própria raiz passa pela primeira
barreira e é barrada pela segunda (*destino já existe* — e a raiz sempre existe).
**Recusado na prática**, confirmado pelo `main` real, sem emitir nada. É defesa em
profundidade que perdeu uma camada, não um caminho aberto.

### E — Destino em diretório inexistente queima a credencial · **menor**

`validarDestino` roda antes da emissão exatamente para evitar isso, mas **não
verifica se o diretório-pai existe**. Medido: com `--saida <dir-inexistente>/c.env`
e `--commit`, o script **emite o custom token, faz a troca** e só então falha no
`openSync`, saindo com código 2. Nenhum arquivo fica para trás e nada vaza — mas
um erro de digitação no caminho materializa uma credencial que precisa ser
revogada. Acrescentar a checagem do diretório à validação prévia fecha o caso.

### F — Claim pela cadeia de protótipos · **menor, pré-existente**

`token[papel] === true` lê pela cadeia de protótipos:
`autorizaComoMotorDePartidas(Object.create({admin:true}))` devolve `true`.
**Não alcançável pelo caminho real**, e verificado: o payload de um JWT com
`"__proto__"` passa por `JSON.parse`, que cria uma propriedade **própria** e não
altera o `[[Prototype]]` — a leitura devolve `false`. A função é **byte a byte
idêntica à da base**, então isto não é da candidata. `Object.hasOwn` fecharia.

### G — Falso positivo do UUID · **pré-existente, não da candidata**

Ver §9. Impressões digitais idênticas às da base.

### H — Permissão de diretório não é gerenciada · **menor**

A §4 pede "diretório e arquivo" com permissões restritivas. O arquivo nasce
`0600`, e **o temporário também** — não existe instante em que o segredo esteja
permissivo. O **diretório** não é criado nem ajustado pelo script (medido: modo
inalterado antes e depois). No POSIX isso expõe apenas o *nome* do arquivo. **No
Windows nem o modo do arquivo vale** — o script avisa, o que é a conduta certa,
mas a proteção efetiva ali é nenhuma. Gerar a credencial em máquina POSIX, ou
restringir por `icacls`, é o que resta.

---

## 13. Veredito (§12)

| Critério | Resultado |
|---|---|
| Os dois SHAs são os candidatos exatos | ✅ |
| Os deltas são os declarados | ✅ |
| **A integração cruzada fecha** | ❌ **achados A e B** |
| A revogação é fail-closed | ✅ |
| Não existe segunda verificação sem `checkRevoked` | ✅ |
| Todas as mutações detectadas | ✅ 12/12 |
| Não há regressão | ✅ |
| Nenhuma credencial criada, exposta ou ativada | ✅ |
| **Runbook operacionalmente completo** | ❌ **achado C** |

# `FAIL`

**Nada do que reprova é falha de segurança.** Autoridade, revogação, sigilo,
identidade e isolamento de projeto passaram inteiros — o isolamento, inclusive,
passou *estrito demais*, e é essa severidade excessiva que forma o achado A.

O que reprova é **prontidão**: a credencial, como está, muito provavelmente não
produz token nenhum em produção, e o runbook não permite descobrir isso nem
reagir a isso.

**A ativação operacional não pode ser autorizada.** Para chegar a PASS:

1. resolver o achado **A** — remover ou relaxar a comparação de `project_id`, com
   teste que registre o que o endpoint real devolve;
2. completar o runbook (**C**) nos itens 6, 9 e 11;
3. declarar o achado **B** como risco aceito, ou fechá-lo num ambiente que emita
   token assinado.

Os achados **D**, **E**, **F** e **H** não bloqueiam. **G** é anterior e alheio.

---

## 14. Confirmações finais

- **Zero deploy.** Nenhuma Cloud Function implantada.
- **Zero ativação.** Nenhum usuário técnico criado, nenhuma claim concedida,
  nenhum custom token ou refresh token real emitido.
- **Zero secret alterado.** Nada tocado no Railway, no Firebase Auth ou em
  configuração de produção.
- **Zero PR, zero merge.** Os dois repositórios candidatos permanecem intactos; o
  repositório do servidor foi tratado como **somente leitura**.
- **Bases intactas.** `831eb81` e `7e7572b` inalterados no remoto.
- **Árvores limpas.** Os quatro worktrees voltaram aos SHAs exatos após as doze
  mutações.
- Este laudo é o **único** arquivo desta branch.
