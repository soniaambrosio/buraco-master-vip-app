# Correção V2 — contrato do Secure Token e completude operacional da credencial do Motor

> ## `PASS` da correção
>
> **O bloqueio morreu, as validações do JWT continuam estritas, e o runbook chegou
> a 12/12.**
>
> A homologação independente reprovou a V1 por dois motivos, e os dois estão
> fechados. O módulo do servidor comparava `project_id` da resposta do Secure
> Token com `FIREBASE_PROJECT_ID` — campo que é o **número** do projeto, e nunca o
> id textual: o Railway falharia fechado com `PROJETO_DIVERGENTE` e **nunca**
> obteria ID token. A comparação foi **removida**, e não substituída. E o runbook,
> que estava em 9 de 12, ganhou os três procedimentos ausentes.
>
> **Zero ativação · zero deploy · zero PR · zero merge · zero secret ·
> nenhuma credencial real criada, emitida ou exposta.**

| | |
|---|---|
| Este laudo | metade do **app** |
| Metade do servidor | `soniaambrosio/buraco-servidor`, `docs/CORRECAO-CONTRATO-SECURE-TOKEN-V2.md` |
| Data | 2026-08-17 |

---

## 1. Gate Zero

Quatro refs, resolvidas por **duas** consultas `ls-remote` — uma por repositório.

| Papel | Ref | SHA | Exigido |
|---|---|---|---|
| App · base | `homologacao/credencial-renovavel-motor-revogacao-v1` | `a6b6b5bd84986d9fddfd59410e50938434ae6583` | ✅ |
| App · correção | `correcao/credencial-motor-contrato-runbook-v2` | *(nova — não existia no remoto)* | ✅ |
| Servidor · base | `claude/credencial-renovavel-motor-railway-v1` | `85d0eee5286fd1deba5c2ae85176b76e714e6690` | ✅ |
| Servidor · correção | `correcao/credencial-motor-secure-token-v2` | *(nova — não existia no remoto)* | ✅ |

- **Bases ancestrais**: as duas branches de correção nascem exatamente dos SHAs
  acima, e cada uma tem **um** commit de trabalho mais o laudo.
- **Árvores limpas** antes e depois, nos dois repositórios.
- **Dois worktrees exclusivos**, criados para esta correção
  (`F:/Projetos/wt-cred-v2-app`, `F:/Projetos/wt-cred-v2-srv`). O worktree que a
  homologação usou não foi tocado.
- **Nenhuma sonda da homologação foi reaproveitada como teste.** Os casos novos
  são escritos aqui, vivem dentro das suítes dos repositórios, e rodam no CI de
  quem clonar.
- **Nenhum segredo, nenhum projeto real.** As fixtures usam a marca própria
  (`SEGREDO-DE-TESTE-`), e os projetos são de teste.

---

## 2. Inventário — exatamente os arquivos permitidos

| App | |
|---|---|
| `M` | `functions/scripts/bootstrap_credencial_motor.js` |
| `M` | `functions/test/bootstrap_credencial.test.js` |
| `M` | `docs/CREDENCIAL-MOTOR-BOOTSTRAP-E-REVOGACAO-V1.md` |
| `A` | `docs/CORRECAO-CREDENCIAL-MOTOR-CONTRATO-E-RUNBOOK-V2.md` *(este laudo)* |

| Servidor | |
|---|---|
| `M` | `server.js` |
| `M` | `test/credencial_motor.test.js` |
| `M` | `docs/CREDENCIAL-RENOVAVEL-MOTOR-V1.md` |
| `A` | `docs/CORRECAO-CONTRATO-SECURE-TOKEN-V2.md` |

**Nenhum terceiro arquivo.** `functions/src/autoridade.ts` foi **mutado e
revertido** durante a medição do §5 (mutação 8) e voltou byte a byte; não está no
delta. `functions/package.json` não mudou: nenhum alvo de teste novo foi preciso.

---

## 3. A correção do contrato (servidor)

O detalhe técnico está no laudo do servidor e na decisão **6** de
`docs/CREDENCIAL-RENOVAVEL-MOTOR-V1.md`. Em uma frase: **o envelope da resposta
não decide projeto; o token decide.**

| | V1 | V2 |
|---|---|---|
| `json.project_id` vs `FIREBASE_PROJECT_ID` | comparado, recusava | **removido** |
| `json.project_id` exigido como string | sim | **não é exigido** |
| `FALHA.PROJETO_DIVERGENTE` | existia | **não existe** |
| `json.user_id` vs UID | conferido | conferido |
| `aud`, `iss`, `sub`, `exp`, claim | conferidos | **conferidos, iguais** |
| Fixture `respostaOk()` | `project_id: PROJETO` | `project_id: "1234567890"` |

A fixture é o ponto que explica por que a suíte da V1 passava com a credencial
quebrada: ela **afirmava a suposição** do módulo em vez de testá-la.

---

## 4. O endurecimento do bootstrap (app)

Três achados menores da homologação, fechados. Nenhum deles era caminho aberto;
os três eram defesa em profundidade com uma camada a menos.

| Achado | O que era | O que passou a ser |
|---|---|---|
| **D** | `--saida` igual à **raiz do repositório** escapava da barreira "está dentro?" (`path.relative(raiz, raiz) === ''`) e só era barrada pela seguinte | primeiro motivo de recusa, com mensagem própria (`BOOT-19c`, `BOOT-19d`) |
| **E** | diretório-pai não era verificado: com `--saida <dir-inexistente>/c.env --commit` o script **emitia o custom token, trocava**, e só então falhava no `openSync` | o preflight exige pai **existente, diretório e gravável** — e o script **não cria diretório** (`BOOT-25`, `BOOT-25b`, `BOOT-25c`) |
| **H** | permissão do **diretório** não era gerenciada | POSIX: pai gravável por grupo/outros → **RECUSA**; apenas legível → **AVISO**. Windows: nada é avaliado, e a saída diz "modo **pedido**" (`BOOT-26`…`BOOT-26d`) |

A decisão ficou **pura** (`validarDestino`) e a leitura de disco isolada
(`sondarDestino`), que responde "não existe / não gravável" para qualquer erro —
e essas duas respostas recusam. Uma sonda ausente ou incompleta também recusa
(`BOOT-25d`): o preflight falha **fechado**.

**O padrão dry-run não mudou.** Sem `--commit` nada é emitido, e `BOOT-01`/`BOOT-02`
continuam medindo isso pelo contador do dublê, não pela mensagem.

### Por que a recusa, e não o `mkdir -p`

Criar árvore de diretórios para guardar um segredo é decisão do operador. Um
`mkdir -p` embutido transformaria o erro de digitação — que é o acidente que
estamos evitando — num diretório novo em lugar nenhum, com a credencial dentro.

### Por que o diretório apenas legível avisa, e não recusa

`0755` é o modo do `~` de quase toda máquina POSIX. Recusar ali empurraria o
operador a improvisar. O que vaza num diretório legível é o **nome** do arquivo —
o conteúdo continua `0600`. O que **é** recusado é o diretório gravável por
terceiros, porque ali o `0600` não protege coisa alguma: trocam o arquivo por um
link simbólico entre o `rename` e a leitura.

---

## 5. Runbook — 9/12 → **12/12**

Os três ausentes foram escritos, em
`docs/CREDENCIAL-MOTOR-BOOTSTRAP-E-REVOGACAO-V1.md`.

| # | Item | Onde | O que ele entrega |
|---|---|---|---|
| 6 | **Smoke autenticado** | §7.1 | sete passos: token obtido, chamada autorizada, identidade conferida no documento gravado, varredura de log, e uma operação de teste **identificável** (prefixo `smoke-`) e **reversível** (as seis coleções, com censo antes e depois) |
| 9 | **Token cacheado recusado** | §8.2 | o corte medido pelo que ele alcança: registrar o instante **sem** registrar o token, revogar sessões, remover a claim, chamar **sem forçar renovação**, exigir recusa com zero escritas, forçar renovação, e exigir que a emissão nova **também** não tenha autoridade |
| 11 | **Rotação e vazamento** | §8.3 | periodicidade (90 dias), responsável, geração, substituição atômica no Railway, validação, revogação da anterior, e uma resposta emergencial em seis tempos com inspeção de logs e rollback |

Tudo com **placeholders**. **Nenhum passo foi executado.**

### O que a §8.3 registra e é fácil errar

`revokeRefreshTokens` **não** revoga "aquele refresh token": revoga o **UID
inteiro**, inclusive a credencial recém-criada. Por isso a rotação tem seis
etapas e não quatro — validar, revogar, e **reemitir**. Quem tentar economizar a
reemissão fica com o servidor sem credencial e sem entender por quê.

### Os procedimentos não podem ser apagados em silêncio

Um procedimento que só existe em Markdown some num commit de "limpeza" sem nada
ficar vermelho. `BOOT-29`…`BOOT-33` afirmam a presença dos **elementos** que
tornam cada procedimento executável — pré-requisito, passo, critério de sucesso,
reversão — e que a tabela de prontidão tem doze linhas, todas fechadas. Não
afirmam prosa.

---

## 6. Limitação do emulador — registrada, não maquiada

Está em §10 do runbook, e não virou teste verde:

- o emulador de Auth emite ID token `{"alg":"none"}`, **assinatura vazia**;
- ele **não** prova a cadeia com assinatura real;
- um token assinado à mão **também não** substitui a emissão do Google — mediria
  o nosso arnês, não o contrato;
- **o smoke com token real (§7.1) é obrigatório** na OS operacional futura.

As duas divergências travam a cadeia em sentidos **opostos**: o token cru do
emulador é recusado pelo módulo do servidor (`TOKEN_ILEGIVEL` — correto para
produção), e um token com assinatura acrescentada passa no servidor e é recusado
pelo receptor, que verifica de verdade. Por isso a integração cruzada continua
**não exercitada**, e o que existe são as duas metades medidas separadamente.

---

## 7. Poder de detecção — **13 mutações, 13 detectadas**

Cada uma aplicada isoladamente, medida e revertida. As duas árvores voltaram aos
SHAs exatos.

| # | Mutação | Repo | Caso derrubado |
|---|---|---|---|
| 1 | restaurar `project_id === FIREBASE_PROJECT_ID` | srv | `CRED-18`, `18b`, `18c`, `18d`, `18e` (+28 outros) |
| 2 | aceitar `aud` incorreto | srv | **`CRED-18f`**, `CRED-21` |
| 3 | aceitar `iss` incorreto | srv | **`CRED-18g`**, `CRED-21` |
| 4 | aceitar UID divergente | srv | **`CRED-18i`**, `CRED-17` |
| 5 | aceitar claim *truthy* | srv | **`CRED-18j`**, `CRED-20` |
| 6 | reutilizar token expirado | srv | `CRED-11`, `12`, `12b`, `15`, `15b` |
| 7 | abrir segunda renovação concorrente | srv | `CRED-13`, `14`, `14b` |
| 8 | reverificar token revogado **sem** `checkRevoked` | app | **`REC-06c`**, e só ele |
| 9 | emitir credencial **antes** do preflight | app | `BOOT-19`, `19d`, `20`, `25`, `25b`, **`28`** |
| 10 | permitir saída dentro do repositório | app | `BOOT-19`, `19b`, **`28`** |
| 11 | remover o smoke do runbook | app | **`BOOT-29`** |
| 12 | remover o procedimento de cache revogado | app | **`BOOT-30`** |
| 13 | remover rotação e resposta a vazamento | app | **`BOOT-31`** |

### Duas coisas que a tabela não mostra

**A mutação 1 derruba 33 casos, e isso é o ponto.** A comparação restaurada
quebra praticamente toda a suíte — porque a fixture agora carrega a forma
**medida** do campo. Na V1 ela não derrubava nenhum, porque a fixture carregava a
suposição. A diferença entre 0 e 33 é exatamente o defeito de prova que a
homologação apontou.

**A mutação 7 quase escapou — por um erro do arnês, não do código.**
`if (emVoo) return emVoo;` aparece **duas** vezes no bundle: em `auth_firebase` e
em `credencial_motor`. A primeira tentativa mutou a ocorrência errada, a suíte
ficou verde, e o relatório teria dito "mutante não detectado" sobre um mutante
que nunca foi aplicado onde se pensava. O arnês passou a exigir **escopo** — o
alvo tem de aparecer **uma** vez dentro do módulo declarado — e a mutação, feita
no lugar certo, cai em `CRED-13`, `CRED-14` e `CRED-14b`. Foi conferido o
`numstat` de cada mutação antes de creditar qualquer veredito.

### Artefato produzido pelas mutações 9 e 10, e removido

As duas escreveram `cred.env` na raiz e em `functions/` — que é **o artefato que
a guarda existe para impedir**, e a prova de que a guarda funciona. Conteúdo:
`SEGREDO-DE-TESTE-refresh-token`, sem valor real. **Removidos**; as árvores estão
limpas.

---

## 8. Regressão — nenhuma

| Suíte | Exigido | Medido |
|---|---|---|
| `functions` · provisionador (puro) | 21 | **21** ✅ |
| `functions` · provisionador (emulador de Auth) | 14 | **14** ✅ |
| `functions` · **bootstrap** | 39 antes dos novos | **39 + 17 = 56** ✅ |
| `functions` · receptor (puro) | 32 | **32** ✅ |
| `functions` · receptor (emulador) | 9 | **9** ✅ |
| `functions` · conquista (Firestore) | 10 | **10** ✅ |
| `firebase/testes` · Rules | 120 | **120** ✅ |
| `functions-economia` | 63 | **63** ✅ |
| `tsc --noEmit` | limpo | ✅ |
| Exports do entrypoint | 11 | **11** ✅ (`REC-17`) |
| Servidor · `npm test` | 228 antes dos novos | **228 + 14 − 1 = 241** ✅ |
| Servidor · `npm start` | inalterado | `node server.js` ✅ |
| Servidor · dependências | zero novas | `package.json` **não está no delta** ✅ |

O `−1` do servidor é o antigo `CRED-18` ("project_id divergente é recusado"),
removido porque afirmava um contrato inexistente. Nenhum outro caso da V1 mudou
de veredito.

---

## 9. Veredito

| Critério (§12 da OS) | Resultado |
|---|---|
| O bloqueio do `project_id` morre | ✅ removido, e não substituído |
| As validações de JWT permanecem estritas | ✅ `aud`, `iss`, `sub`, `user_id`, `exp`, claim — nove casos novos só para isso |
| O runbook chega a 12/12 | ✅ §11 do runbook |
| Todas as mutações detectadas | ✅ **13/13** |
| Inventário sem terceiro arquivo | ✅ |
| Sem regressão | ✅ |
| Árvores limpas | ✅ |

# `PASS` da correção

**A ativação continua PROIBIDA.** Ela depende de re-homologação independente e de
uma OS operacional — e, antes das duas, do smoke com token real, que é a única
coisa capaz de provar a junta entre o produtor e o receptor. Este laudo prova que
o caminho deixou de estar bloqueado; não prova que ele foi percorrido.

## 10. Confirmações finais

- **Zero ativação.** Nenhum usuário técnico criado, nenhum claim concedido,
  nenhum custom token ou refresh token real emitido.
- **Zero deploy, zero PR, zero merge.** As duas branches foram publicadas com
  push normal, sem `--force`.
- **Zero secret alterado.** Nada tocado no Railway, no Firebase Auth ou em
  configuração de produção. Nenhuma chamada contra projeto real.
- **Bases intactas** no remoto.
- **Árvores limpas** nos dois worktrees, depois das treze mutações.
