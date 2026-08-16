# Matriz das três composições candidatas — RC V1

Medição congelada em **2026-08-16, 00:47–00:55 (-03)**. Os SHA abaixo foram lidos às
00:47:33 e permaneceram idênticos nos três snapshots da janela (ver
[`ARBITRAGEM-LINHAGEM-RC-V1.md`](ARBITRAGEM-LINHAGEM-RC-V1.md) §1).

Apelidos usados: **C1** = `integracao/release-canonica-predeploy-v1`,
**C2** = `integracao/rc-unica-predeploy-v1`,
**C3** = `claude/composicao-operacional-release-v1-6b0496`.

---

## 1. Matriz comparativa

| Critério | C1 — release-canonica-predeploy-v1 | C2 — rc-unica-predeploy-v1 | C3 — composicao-operacional-release-v1 |
| --- | --- | --- | --- |
| SHA local | `8ee179dba919ede73002a76255eb72aff2e2c7d9` | `c4fdddae1d265f8fe0f1aa235ab0c6b6754c3c99` | `96a9fff9ebfc943fc8149fdafd8906af78be6dcc` |
| SHA remoto | **ausente** | **ausente** | **ausente** |
| Merge-base com `0cea0d6` | `0cea0d6…` — descende da base ✔ | `0cea0d6…` ✔ | `0cea0d6…` ✔ |
| Árvore remota reproduzível | **Não** — 6 commits de conteúdo sem folha publicada | **Não** — HEAD não publicado, mas todo o conteúdo vem de folhas publicadas | **Não** — 1 commit funcional próprio, sem folha de origem |
| Commits acima da base | 339 | 220 | 190 |
| Folhas integradas (merges de folha) | 22 | 12 | 6 |
| Folhas centrais cobertas (de 13) | **12** (falta F13) | 10 | 5 |
| Gate disponível no momento da composição | **Sim** — mesclado em `764160f` | Não | Não |
| Motor C + Motor D | **Sim**, na ordem C→D (`563c23f` → `8bbad91`) + canonização do lixo (`ec9f88b`) | Não | Não |
| Commits exclusivos não publicados | 28 (19 merges + 9 diretos) | 12 (todos merges) | 7 (6 merges + 1 direto) |
| Correções funcionais próprias | Nenhuma | Nenhuma | **1** — `96a9fff feat(online): logout e troca de conta invalidam a sessão autenticada` |
| Conflitos já resolvidos | 15 dos 22 merges registram conflito no corpo da mensagem | Desconhecido — merge ainda aberto | Não declarado |
| Evidência da resolução | Corpo das mensagens de merge | — | — |
| Arquivos fora da RC (transporte/backup/agente/build) | 0 | 0 | 0 |
| Arquivos na árvore | 729 | 658 | 622 |
| Artes da Loja | 46 ✔ | 46 ✔ | 46 ✔ |
| Manifesto de proveniência da composição | Parcial — `docs/RC-V1-MANIFESTO-DE-COMPOSICAO.md`, herdado da OS de proteção, não descreve estes 22 merges | Ausente | Ausente |
| Testes executados sobre o HEAD | Nenhum recibo do portão na árvore | Nenhum | Nenhum |
| Worktree | 4 arquivos modificados + 1 não rastreado | **MERGE_HEAD ativo, 13 caminhos em conflito** | 1 não rastreado |
| **Elegível** | **Não** | **Não** | **Não** |

---

## 2. Cobertura de folhas, folha a folha

`SIM` = ancestral do HEAD da candidata.

| Alvo | SHA | C1 | C2 | C3 |
| --- | --- | :-: | :-: | :-: |
| F01 identidade de sessão | `3c6eb8da` | SIM | SIM | SIM |
| F02 busca por apelido | `e97bac89` | SIM | SIM | — |
| F03 economia | `42928c30` | SIM | SIM | SIM |
| F04 ranking/ligas/hall | `428c4587` | SIM | SIM | SIM |
| F05 Kit Pioneiros | `bce06fee` | SIM | SIM | SIM |
| F06 WS auth (cliente) | `13582ddf` | SIM | SIM | SIM |
| F07 visão do espectador | `fcd478d7` | SIM | SIM | — |
| F08 billing VIP comercial (doc) | `625769d2` | SIM | SIM | — |
| F09 portão P0 integrado | `d8b45c39` | SIM | SIM | — |
| F10 runner sandbox cleanup | `9fd3a67a` | SIM | SIM | — |
| F11 **Motor C** | `4cae8aef` | SIM | — | — |
| F12 **Motor D** (C10 rev.2) | `a600b4e2` | SIM | — | — |
| F13 play-billing-aab-interno | `bbba26de` | — | — | — |
| **Gate da RC** | `836b0424` | SIM | — | — |
| Δ artes da Loja + Billing comercial | `e65495d6` | SIM | SIM | SIM |
| Δ garantia de encerramento de turno | `f41eea0e` | SIM | — | — |
| Δ exclusão de conta / conformidade | `1acc5f99` | SIM | SIM | SIM |
| Δ Billing de produção | `125ec969` | SIM | SIM | — |
| Δ Android API 36 | `7e77cfe4` | SIM | — | — |
| Δ seeds sem staging do CI | `37494dde` | SIM | — | — |
| Δ canonização da trava do lixo | `948f194e` | SIM | — | — |
| Doc censo de telas | `a97866ce` | SIM | — | — |
| Doc estado de produção | `047486f2` | SIM | — | SIM |
| Doc publicação Play | `604f3620` | SIM | — | — |
| Doc proteção das folhas | `7d521106` | — (conteúdo por cherry-pick) | — | — |

**F13 (`feat/play-billing-aab-interno @ bbba26de`)** não está em nenhuma candidata. Está a 5
commits da base e traz apenas configuração de build; a árvore Android publicável e o Billing
funcional entram pela linhagem `correcao/assets-loja-v1 @ e65495d6`, presente nas três.

---

## 3. Os commits que cada candidata inventou

### C1 — 9 commits diretos, nenhum funcional

| Commit | Assunto | Origem |
| --- | --- | --- |
| `054406e`, `7a90811`, `836b042` | gate único de RC, evidência, recusa de recibo antigo | `claude/gate-automatizado-rc-v1-819647` — **publicada por esta OS** |
| `54252af`, `c7f69a7`, `1b4ce1d` | manifesto de composição da OS de proteção | cherry-pick de `claude/protecao-folhas-rc-v1-f2cc65 @ 7d52110` (publicada; SHA diferente) |
| `9bc57d9`, `dd54251` | auditoria de observabilidade | cherry-pick de `claude/observabilidade-buraco-vip-f3cd12 @ f3f9e53` — **não publicada** |
| `8ee179d` | censo da população legada VIP | cherry-pick de `claude/legacy-vip-population-census-e784c2 @ c885eff` — **não publicada** |

Nenhum toca código de produção: são documentação e a ferramenta do portão.

### C2 — nenhum commit direto

Os 12 commits exclusivos são todos merges. Em compensação, o merge nº 13 está **aberto**:
13 caminhos em conflito, entre eles `app/lib/mesa.dart`, `app/lib/motor/motor_partida.dart`,
`app/lib/motor/desfecho_partida.dart` (both-added), `firebase/firestore.rules`,
`functions/src/index.ts` e `functions/package.json` — exatamente a colisão dos motores e do
backend.

### C3 — 1 commit funcional próprio

`96a9fff feat(online): logout e troca de conta invalidam a sessão autenticada`. É código de
produção escrito durante a composição, sem folha de origem, sem OS que o aprove e sem
homologação própria. Pelo critério 6.1 da OS, isso sozinho torna a candidata inelegível.

C3 é, aliás, um **fork de C1**: as duas compartilham `a048883`, `f9840e6`, `6e53dcd` e
`047486f`. C3 divergiu de C1 em `a048883` e seguiu por conta própria.

---

## 4. Por que nenhuma passa nos critérios mínimos (§6.1)

| Critério mínimo | C1 | C2 | C3 |
| --- | :-: | :-: | :-: |
| Descende da base obrigatória | ✔ | ✔ | ✔ |
| HEAD publicado | ✘ | ✘ | ✘ |
| Reproduzível só com objetos publicados | ✘ (2 branches-fonte não publicadas) | ✘ | ✘ |
| Não depende de arquivos sujos nem de MERGE_HEAD | ✘ (4 modificados, 2 deles testes) | ✘ (merge aberto) | ✘ (1 não rastreado) |
| Sem alteração funcional improvisada | ✔ | ✔ | ✘ |
| Manifesto completo de proveniência | ✘ (parcial/herdado) | ✘ | ✘ |
| Não omite folha necessária | ✔ | ✘ (sem Motores C e D) | ✘ (5/13) |
| Não duplica implementações incompatíveis | não verificado (sem execução do portão) | ✘ | não verificado |
| Sem transporte/backup/arquivo de agente | ✔ | ✔ | ✔ |
| Cada conflito com evidência verificável | parcial (15 de 22) | ✘ | ✘ |
