# Composição e homologação da Release Candidate V1 — relatório de parada

**Veredito: FAIL — parada no precheck da §4. Nenhum merge foi executado.**

Data da execução: **2026-08-16, 00:15–00:27 (-03)**
Worktree: `buraco-master-vip-app/rc-v1-composition-qa-29b435`
Manifesto de proveniência: [`RC-V1-MANIFESTO-PROVENIENCIA.md`](RC-V1-MANIFESTO-PROVENIENCIA.md)

A OS proíbe iniciar a composição enquanto houver ref móvel, sessão paralela movimentando as
folhas, worktree ativa com trabalho não salvo ou commit funcional existente apenas
localmente. As quatro condições estavam presentes simultaneamente, e a mais grave delas —
outras sessões compondo a mesma RC neste momento — não é contornável por nenhuma ordem de
merge.

---

## 1. Motivo da parada

### 1.1 Três composições concorrentes de RC estão em andamento agora

Durante o precheck, três worktrees desta máquina estavam mesclando **as mesmas folhas desta
OS**, em branches que não existem no `origin`:

| Worktree | Branch | Estado às 00:26 |
| --- | --- | --- |
| `release-canonica-v1-874ff7` | `integracao/release-canonica-predeploy-v1` | merge em curso, 84 caminhos sujos |
| `vip-production-readiness-4194df` | `integracao/rc-unica-predeploy-v1` | merge em curso, 69 caminhos sujos |
| `release-v1-composition-6b0496` | `claude/composicao-operacional-release-v1-6b0496` | criada **durante** este precheck |

As mensagens de merge dessas sessões são inequívocas:

```text
merge(rc): economia de boas-vindas e vitorias (feat/economia-boas-vindas-vitorias @ 42928c3)
merge(rc): busca por apelido e descoberta social (claude/busca-apelido-descoberta-social-b56465 @ e97bac8)
merge(rc): portao automatizado de Release Candidate e runners de emulador (claude/gate-automatizado-rc-v1-819647 @ 836b042)
merge(rc): exclusao de conta, conformidade Play e identidade de sessao canonica
merge(composicao): arvore Android publicavel, artes da Loja e ciclo de vida do Billing (correcao/assets-loja-v1 @ e65495d)
```

São as folhas 1, 2, 3, 10 e o delta das artes da Loja — exatamente o escopo desta OS.
Compor uma quarta árvore em paralelo produziria mais uma linhagem concorrente, e é o
oposto do que a missão pede ("**a primeira árvore canônica e reproduzível**").

### 1.2 Refs em movimento, provado por três snapshots

Snapshots de `refs/heads/` + `refs/remotes/` tirados às **00:21:0x**, **00:22:03** e
**00:26:54**:

| Ref | t0 (00:21) | t1 (00:22) | t2 (00:26) |
| --- | --- | --- | --- |
| `integracao/release-canonica-predeploy-v1` | `a048883f` | `9c46889e` | `dc00fc9a` |
| `integracao/rc-unica-predeploy-v1` | `746326da` | `3168677c` | `421caee6` |
| `claude/canonizacao-estado-lixo-v1-75a307` | `25e8d172` | `c7f4a573` | `948f194e` |
| `claude/composicao-operacional-release-v1-6b0496` | *não existia* | `70884320` | `12334641` |

Além disso, entre t1 e t2 a branch `claude/canonizacao-estado-lixo-v1-75a307` **passou a
existir no `origin`** — outra sessão publicou durante a medição. Nenhum manifesto congelado
sobreviveria a esse ritmo: qualquer SHA que eu fixasse estaria vencido antes do primeiro
merge.

### 1.3 O gate exigido pela §11 não existe no remoto

`claude/gate-automatizado-rc-v1-819647 @ 836b0424edaca64d4c62d10edc4d3f57a86c6880` — 3.640
linhas em `ferramentas/portao-rc/`, `docs/PORTAO-RC.md` e `docs/PORTAO-RC-EVIDENCIA.md` —
**não está em nenhuma ref do `origin`**:

```bash
git for-each-ref --contains 836b0424edaca64d4c62d10edc4d3f57a86c6880 refs/remotes/origin/
# (vazio)
```

A ancestralidade que a §5 mandava provar está confirmada — `836b042` contém `9fd3a67`, e a
folha 10 seria integralmente coberta pela descendente. Mas a §11 exige executar esse portão
no HEAD final e emitir recibo. Uma RC homologada por uma ferramenta que existe só no disco
de uma máquina não é reproduzível, e integrá-la violaria a §4 ("folha concluída sem proteção
remota").

### 1.4 Correção funcional do motor apenas local

`claude/canonizacao-estado-lixo-v1-75a307` — *"fix(motor): canonizar a trava do lixo único"*
— é posterior a `claude/garantia-encerramento-turno-v1 @ f41eea0e` e toca exatamente a
autoridade canônica que a §8 manda manter ligada. Estava sendo escrita durante o precheck
(`M app/test/teste_motor.dart` não commitado às 00:21) e só foi publicada às 00:26. Compor o
Motor D sem ela entregaria uma RC já vencida na semana em que nasce.

---

## 2. O que ficou provado antes da parada

A parada é do **merge**, não da auditoria. O precheck foi executado por inteiro e o
manifesto está congelado. Em resumo:

* **Base autorizada confirmada.** `consolidacao/apk-geral-bmv @ 0cea0d6d68f2c93613b985f4aa85800d77cf42d7`,
  idêntica à âncora da OS. `main @ fb9edb5c…` confirmada como placeholder e não utilizada.
* **`release/rc-v1` não existe** em nenhum dos dois remotos — não há árvore anterior a
  preservar nem a reconciliar de forma não destrutiva.
* **As 13 folhas centrais foram resolvidas no remoto** e **todas as 13 âncoras da OS
  conferem** com o SHA remoto completo. Uma única divergência, local: a ref local da folha 12
  aponta para C10 rev.3 (`88d12ac`) enquanto o remoto aponta para rev.2 (`a600b4e2`) — ambas
  ancestrais da folha viva do Motor D, e portanto reconciliável sem perda.
* **Duas folhas centrais estão cobertas por descendente** (1 → `1acc5f99`; 12 → `f41eea0e`)
  e não devem receber merge próprio.
* **O delta posterior foi classificado**: 6 entregas funcionais vivas, 26 cobertas por
  ancestralidade, 4 documentais, 2 travadas por decisão de produto e as demais excluídas com
  justificativa.
* **Artes da Loja reconciliadas em conferência**: `correcao/assets-loja-v1 @ e65495d6` traz
  **46** arquivos em `app/assets/loja/`, contra **0** na base, em diff puramente aditivo
  (`46 files changed, 0 insertions(+), 0 deletions(-)`).
* **Rota do Billing identificada**: a linhagem funcional `homologacao/play-billing-comercial @ 0ea96c29`
  está contida em `correcao/assets-loja-v1 @ e65495d6` **e** em
  `claude/billing-vip-production-activation-525b63 @ 125ec969`; `feat/play-billing-aab-interno @ bbba26de`
  **não** a cobre (5 commits além da base, contra 54).
* **Servidor auditado**: as três âncoras conferem, a árvore está limpa, e a conciliação
  entre `seguranca/ws-auth-identidade` e `enforcement/visao-espectador` produz **um único
  conflito, em `server.js`** — `package.json` não conflita.

### 2.1 Defeito de instrumentação corrigido no caminho

O clone deste worktree tinha refspec de fetch reduzido a duas branches, o que fazia
`git fetch --all --prune` responder "up to date" enquanto 72 refs de rastreamento
permaneciam congeladas em estados antigos. Toda medição de ancestralidade feita nesse estado
seria falsa. O refspec foi restaurado para `+refs/heads/*:refs/remotes/origin/*` e o fetch
refeito — 96 branches remotas resolvidas. É a única alteração de configuração desta sessão;
nenhuma ref remota foi criada, movida ou apagada.

---

## 3. O que **não** foi feito

| Ação | Estado |
| --- | --- |
| Criação de `release/rc-v1` (app) | Não executada |
| Criação da RC do servidor | Não executada |
| Merge em `main` | Não |
| Merge em `consolidacao/apk-geral-bmv` | Não |
| Rebase, squash, cherry-pick substitutivo | Não |
| Force-push, reset destrutivo | Não |
| Remoção de teste, desligamento de funcionalidade, restauração de mock | Não |
| Alteração de regra de negócio | Não |
| Deploy, Play Console, geração de AAB/APK | Não |
| Publicação de branch no remoto | Não |
| Gates da §11 | Não executados — só fazem sentido sobre o HEAD final, que não existe |

Nenhuma branch existente foi tocada. Este relatório e o manifesto foram commitados em
`diagnostico/rc-v1-parada-precheck`, criada a partir da base autorizada `0cea0d6` e mantida
**local** — a §14 autoriza publicar apenas as branches novas de RC.

---

## 4. Decisões que a OS exigia e que continuam pendentes

Estas não são dúvidas minhas: são pontos que a composição encontraria e que a OS manda
relatar em vez de improvisar.

1. **Qual das três composições em curso é a RC.** Há três árvores concorrentes sendo
   construídas em paralelo nesta máquina (§1.1). Enquanto elas existirem, "a primeira árvore
   canônica" é ambígua por construção. É preciso escolher uma linhagem — ou encerrar as
   outras — antes de qualquer nova tentativa.
2. **Publicação do gate da RC.** `claude/gate-automatizado-rc-v1-819647 @ 836b042` precisa
   chegar ao `origin` antes de ser exigível como portão de homologação.
3. **Mesa: qual entrega vale.** `integracao/fluxo-mesas-pronto-claude @ daa6bad9` e
   `integracao/orientacao-mesa-atualizada @ 74d20a64` trazem a orientação automática da Mesa
   em dois heads diferentes, ambos de 2026-08-15, nenhum ancestral do outro nem da folha 4.
   Qual é a aprovada não está documentado, e a §12 proíbe resolver a colisão de `MesaScreen`
   nesta OS.

---

## 5. Pendências herdadas do Censo (§12 — registradas, não corrigidas)

Continuam válidas e fora do escopo desta OS:

* entrada direta na Home, sem login alcançável;
* identidade fixa "Sônia Rainha" e demais dados fixos;
* dez das doze superfícies alimentadas por `VM.mock()`;
* `RankingSemFonte` — Ranking sem fonte Firestore no cliente;
* colisão entre as duas implementações de `MesaScreen`;
* ampliação ao toque inexistente;
* Admin de Torneios e "Cenários mock" expostos;
* ausência de telas para coleções, moderação, social e rastreabilidade;
* consumidores de rastreabilidade ausentes;
* substituição definitiva dos mocks por contratos reais.

---

## 6. Estado final das árvores

| Repositório | Branch | HEAD | Árvore |
| --- | --- | --- | --- |
| App (este worktree) | `diagnostico/rc-v1-parada-precheck` | `0cea0d6` + 1 commit de documentação | Limpa |
| Servidor | `seguranca/ws-auth-identidade` | `71199e81ff44d41c8fcdb41cd866b38c0cf14fee` | Limpa, intocada |

As demais worktrees desta máquina não foram tocadas por esta sessão; várias delas estavam
sujas ou em merge no momento da medição, por conta de sessões paralelas.
