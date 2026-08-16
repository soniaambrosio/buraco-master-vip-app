# Manifesto de proveniência da Release Candidate V1

Congelado em **2026-08-16, 00:21 (-03)**, no worktree
`buraco-master-vip-app/rc-v1-composition-qa-29b435`.

Todos os SHA foram resolvidos **no remoto**, via `git ls-remote --heads origin`, e não a
partir de refs locais. A coluna *Contida em* foi obtida com
`git for-each-ref --contains <sha> refs/remotes/origin/` depois de restaurar o refspec de
fetch completo (ver §0).

> **Este manifesto não descreve uma RC composta.** Ele descreve o estado que foi medido
> no precheck e que motivou a parada registrada em
> [`COMPOSICAO-HOMOLOGACAO-RC-V1.md`](COMPOSICAO-HOMOLOGACAO-RC-V1.md).

---

## 0. Correção aplicada antes de medir

O clone deste worktree tinha o refspec de fetch reduzido a duas branches:

```text
+refs/heads/consolidacao/apk-geral-bmv:refs/remotes/origin/consolidacao/apk-geral-bmv
+refs/heads/correcao/p0-elegibilidade-vip-lifecycle:refs/remotes/origin/correcao/p0-elegibilidade-vip-lifecycle
```

Com esse refspec, `git fetch --all --prune` retornava "up to date" enquanto 72 refs de
rastreamento ficavam congeladas em estados antigos — inclusive `origin/auditoria/regras-bmv`
parado em `14b8d03` (o remoto está em `88d12ac`) e `origin/claude/emulator-runners-robustness-99cda2`
parado em `6bb7582` (o remoto está em `91b864d`). Qualquer cálculo de ancestralidade feito
sobre aquele estado seria falso.

O refspec foi restaurado para `+refs/heads/*:refs/remotes/origin/*` e o fetch refeito.
Depois disso: **96 branches remotas**, todas resolvidas. Nenhuma branch remota foi criada,
movida ou apagada; a alteração é de configuração local de rastreamento.

---

## 1. Repositório do aplicativo — base autorizada

| Campo | Valor |
| --- | --- |
| Base autorizada | `consolidacao/apk-geral-bmv` |
| SHA remoto completo | `0cea0d6d68f2c93613b985f4aa85800d77cf42d7` |
| Confere com a OS | Sim (`0cea0d6d68f2c93613b985f4aa85800d77cf42d7`) |
| Base proibida | `main` @ `fb9edb5c6963964161f1e8834b57f50fe77074a1` — confirmada, não utilizada |
| `release/rc-v1` no remoto | **Não existe** (não há nada a preservar nem a reconciliar) |

---

## 2. Folhas centrais auditadas (13)

Ordem conforme a §5 da OS. *Vs. base* = commits atrás/à frente de
`origin/consolidacao/apk-geral-bmv`.

| # | Branch | SHA remoto completo | Âncora da OS | Vs. base | Tipo | Ancestral de outra folha | Decisão |
| --: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `claude/identidade-sessao-canonica-flutter` | `3c6eb8da7da59fd2f6823d770b9eeb67ddf94d69` | `3c6eb8da` ✔ | 0/49 | Funcional | Sim — `1acc5f99`, `0381aac2` | Coberta por descendente `claude/account-deletion-google-play-compliance-b94769` |
| 2 | `claude/busca-apelido-descoberta-social-b56465` | `e97bac89450d510d158f895b707ae3b75d5898f4` | `e97bac89` ✔ | 0/44 | Funcional | Não | Integrar |
| 3 | `feat/economia-boas-vindas-vitorias` | `42928c30aa0cf9d38aa7c74a84ca4897b22d14ab` | `42928c30` ✔ | 0/56 | Funcional | Não | Integrar |
| 4 | `integracao/ranking-ligas-hall` | `428c4587f9ab771bc785d27a1174b069fc15f20b` | `428c4587` ✔ | 0/82 | Funcional | Não (contém `integracao/fluxo-mesas` @ `7a75bab4`) | Integrar |
| 5 | `claude/kit-pioneiros-2026-1b56ed` | `bce06feea866d0e7ca1bbafaa5a36de7507e7a60` | `bce06fee` ✔ | 0/19 | Funcional | Não | Integrar |
| 6 | `claude/ws-auth-identidade-1fc213` | `13582ddfa0f9b8cccc81b20e51705bf666ca8754` | `13582ddf` ✔ | 0/2 | Funcional (cliente WS) | Não | Integrar |
| 7 | `claude/spectator-view-server-enforcement-c154ee` | `fcd478d7153638d82e99f1cad35e8a2235a285ca` | `fcd478d7` ✔ | 0/1 | Documental (o código é do servidor) | Não | Integrar como evidência do contrato do servidor |
| 8 | `homologacao/billing-vip-comercial` | `625769d29d4892945caacb943e1dc7ac868a0904` | `625769d2` ✔ | 0/52 | Predominantemente documental | Não | Integrar como evidência — **não é a rota funcional do Billing** (ver §5) |
| 9 | `homologacao/p0-final-integrada` | `d8b45c39593770e5f21fa826cd399181fba79acc` | `d8b45c39` ✔ | 0/42 | Funcional + documental | Não | Integrar |
| 10 | `claude/runner-sandbox-cleanup-c0461a` | `9fd3a67ab7a6e9ad8a6a7ac17ad2e2735db86f0a` | `9fd3a67` ✔ | 0/48 | Teste/infra | Sim — de `836b0424` (**apenas local**) | **Bloqueada** — ver §6 |
| 11 | `integracao/motores-torneios-partidas-v1` | `4cae8aef503583aa7a2db6fe8bb34e103779a048` | `4cae8aef` ✔ | 0/21 | Funcional (Motor C) | Não | Integrar — **antes** do Motor D |
| 12 | `claude/buraco-c10-parte-2-5eb70e` | `a600b4e22807cb9da1c5b5e982019d5c6a94cade` | `a600b4e2` ✔ | 9/66 | Funcional (Motor D) | Sim — `88d12aca`, `89fca389`, `f41eea0e` | Coberta por descendente `claude/garantia-encerramento-turno-v1` |
| 13 | `feat/play-billing-aab-interno` | `bbba26dedf72695ca14166edaf32e11c250dce35` | `bbba26de` ✔ | 0/5 | Configuração de build Android | Não | **Não contém** a linhagem funcional do Billing (5 commits além da base) |

**Divergência local × remoto na folha 12.** A ref local `claude/buraco-c10-parte-2-5eb70e`
aponta para `88d12acae2ec34502eaaf3052e4a9faf1c9079a1` (C10 rev.3), enquanto o remoto aponta
para `a600b4e22807cb9da1c5b5e982019d5c6a94cade` (C10 rev.2), que é o SHA ancorado pela OS.
A divergência é reconciliável e não destrutiva: `88d12ac` está protegido no remoto em
`origin/auditoria/regras-bmv`, e **ambos** os commits são ancestrais de
`claude/garantia-encerramento-turno-v1 @ f41eea0e`, que é a folha viva do Motor D.

---

## 3. Evolução da folha 10 — gate automatizado da RC

| Campo | Valor |
| --- | --- |
| Branch | `claude/gate-automatizado-rc-v1-819647` |
| SHA local | `836b0424edaca64d4c62d10edc4d3f57a86c6880` |
| Âncora da OS | `836b042` ✔ |
| SHA remoto | **ausente — a branch não existe no `origin`** |
| Contém `9fd3a67`? | Sim (`9fd3a67` é o quarto commit da linhagem) |
| Conteúdo | `ferramentas/portao-rc/` (5 módulos + suíte de 744 linhas), `docs/PORTAO-RC.md`, `docs/PORTAO-RC-EVIDENCIA.md` — 3.640 linhas em 10 arquivos |
| Contida em alguma ref remota? | **Não** — `git for-each-ref --contains 836b042 refs/remotes/origin/` retorna vazio |

A ancestralidade pedida pela §5 está provada: `836b042` **contém** `9fd3a67`, e a folha 10
seria integralmente coberta pela descendente. O problema não é de genealogia: é que a
descendente — a ferramenta exigida pela §11 para emitir o recibo do HEAD final — só existe
no disco desta máquina.

---

## 4. Delta posterior à auditoria das 13 folhas

### 4.1 Entregas funcionais vivas (não cobertas por nenhuma outra folha remota)

| Branch | SHA remoto completo | Vs. base | Tipo | O que traz | Decisão |
| --- | --- | --- | --- | --- | --- |
| `correcao/assets-loja-v1` | `e65495d69fcccc19088adbd8b665f8287ed22e96` | 0/59 | Funcional | As 46 artes da Loja **e** a linhagem `homologacao/play-billing-comercial` | Integrar |
| `claude/garantia-encerramento-turno-v1` | `f41eea0e1143f4b2e572a8a7105cbea8aea755f3` | 9/83 | Funcional | Conclusão legal do turno; contém C10 rev.2/rev.3 e o bot estratégico | Integrar (supersede as folhas 12 e o bot) |
| `claude/account-deletion-google-play-compliance-b94769` | `1acc5f99a98050d734d6fd5da9b5c2ebe30f407c` | 0/70 | Funcional + documental | Exclusão de conta, conformidade Play; contém a folha 1, política competitiva, ranking backend e `publicId` unificado | Integrar (supersede a folha 1) |
| `claude/billing-vip-production-activation-525b63` | `125ec96954b5d64800f268376db5c034e759ef66` | 0/62 | Funcional + documental | Ativação do Billing em produção; contém `play-billing-comercial`, backfill, recuperação de metadados e o enforcement VIP no cliente | Integrar |
| `claude/android-api-36-compat-a62a58` | `7e77cfe45f83bd547740c3fabd92aab965dbb02f` | 0/53 | Funcional (build) | Fixa `targetSdk 36` em vez de herdar do pin do Flutter | Integrar |
| `claude/sleepy-kilby-f8ff3f` | `37494dde53db3826f1cce14f84792a193992517` | 0/35 | Teste | Localiza os seeds sem depender do staging do CI | Integrar |

### 4.2 Entregas cobertas por ancestralidade (não merge-ar em separado)

| Branch | SHA remoto | Coberta por |
| --- | --- | --- |
| `claude/bot-ia-estrategica-v1` | `89fca3899aa680c303a0b227c051cb3b0a2d6b2a` | `f41eea0e` |
| `auditoria/regras-bmv` | `88d12acae2ec34502eaaf3052e4a9faf1c9079a1` | `f41eea0e`, `89fca389` |
| `claude/moderation-ci-gate-9520bc` | `f12708059f75b37fd19059034390e956c2654890` | `9fd3a67a` |
| `claude/ci-fail-closed-emulador-v1` | `c86aa9dde9caabeff14d6026a4d9aaefac3d88cc` | `9fd3a67a` |
| `claude/emulator-runners-robustness-99cda2` | `91b864dc111754d228476d0f68e05752a624aea7` | `9fd3a67a`, `f1270805`, `c86aa9dd` |
| `claude/claimpioneerkit-homologacao-941659` | `8d7fc04852f6888a0559b3cc2167acd3551da058` | `9fd3a67a` e outras |
| `claude/goofy-kowalevski-099256` | `8cc696d93b3a9bd6b342fd9a4d997d85d936e793` | `9fd3a67a` e outras |
| `claude/identidade-publica-grafo-social-78d184` | `fddcecc38615355bf16401778b7b2fd3bafea35b` | `e97bac89` (folha 2) |
| `integracao/identidade-publica-ranking-v1` | `0b0aa63be668a103edc4706e1889b94f1e4b9079` | `1acc5f99` |
| `claude/politica-competitiva-v1-3e139e` | `cad4515bdb16b9bf8e0d874a81e6ae302d6d4780` | `1acc5f99` |
| `claude/ranking-ligas-backend-auth-ea5ceb` | `af57fe8247dba699563ec608868fd9775da9c0b9` | `1acc5f99`, `cad4515b` |
| `claude/player-account-deletion-flow-d04d45` | `0381aac2fdadf7cd35a233c84b5677636d213661` | `1acc5f99` |
| `homologacao/play-billing-comercial` | `0ea96c292f5c9f21ae0a884507c79a4bed3b3d20` | `e65495d6`, `125ec969` |
| `integracao/play-billing-flutter` | `319bb8ff6b814df0e7da84459855aa4b4f5e4586` | `1acc5f99`, `e65495d6`, `125ec969` |
| `integracao/rtdn-vip-producao` | `a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9` | `e65495d6`, `125ec969`, `1acc5f99` |
| `correcao/vip-client-enforcement-beneficios-v1` | `921f3fd0683645c6e9f49e27949d7e7e48013dfe` | `125ec969` |
| `correcao/p0-elegibilidade-vip-lifecycle` | `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` | `e65495d6`, `125ec969`, `1acc5f99` |
| `claude/backfill-purchasetokenhash-4f3365` | `92a9fa0f661891cff0f5513e6b5ac59732371c3d` | `125ec969` |
| `claude/recuperacao-metadados-legados-vip` | `d00e3947be5a1dea58f5602bc52f06e077a3bd35` | `125ec969` |
| `claude/legacy-vip-population-diagnosis-fc64f7` | `e9c2aa1e40278b501f56be1b9d58f407385c7622` | `125ec969` e outras |
| `claude/vip-production-readiness-4194df` | `7a91e1f9088549d891a749c6624b6d54071bfbb0` | `e65495d6` |
| `claude/android-aab-production-build-ea6bbc` | `005940469aad011adc461b0653cf359fa87acbd7` | `e65495d6` |
| `integracao/os-final-backend-flutter` | `1dc26dd248cae6238ad69f9bf450cd9ba96ce2d3` | ampla |
| `integracao/fluxo-mesas` | `7a75bab49ca18a2876f43f69996de4903b9d6ccc` | `428c4587` (folha 4) |
| `claude/motor-de-torneios-f161b9` | `6f6826d020c313bbd15c1ab4804c5c5ba6040ad2` | `4cae8aef` (folha 11) |
| `claude/motor-partidas-resiliencia-3a775f` | `6917331320657a8dfb961fb8947f0b277a8e93fd` | ampla |

### 4.3 Documentais (evidência — integração precisa de justificativa própria)

| Branch | SHA remoto | Vs. base | Observação |
| --- | --- | --- | --- |
| `auditoria/censo-telas-prontidao-v1` | `a97866cecc467f833ac4a099cb5fbae107d3300d` | 0/1 | O Censo citado pela §2 da OS |
| `claude/production-state-audit-84542f` | `047486f21e300f34ccd1a7495f6a7b058b64f9b9` | 0/1 | Estado das três eras de produção |
| `claude/google-play-publication-v1-bf8d5d` | `604f36200c8f927a46364c2d094a9a4c06e8500b` | 0/1 | Auditoria do pacote Play |
| `claude/protecao-folhas-rc-v1-f2cc65` | `7d521106c52c720c266330b72c0d47e230e68bec` | 90/8 | Manifesto de composição anterior — **nasce de `main`**, não da base autorizada |

### 4.4 Não classificáveis por esta OS — dependem de decisão de produto

| Branch | SHA remoto | Vs. base | Por que trava |
| --- | --- | --- | --- |
| `integracao/fluxo-mesas-pronto-claude` | `daa6bad959c652638c9bd19752c21470d3f8b0c7` | 0/66 | "Orientação Vertical/Horizontal Automática" na Mesa, de 2026-08-15. Não é ancestral da folha 4 nem descendente dela; entra na colisão de `MesaScreen` que a §12 manda **não** resolver nesta OS |
| `integracao/orientacao-mesa-atualizada` | `74d20a64f64e4bb66a287484ba3c4ca98dd877eb` | 0/68 | Mesma entrega em outro head; qual das duas é a aprovada não está documentado |

### 4.5 Excluídas com justificativa

| Branch(es) | Motivo |
| --- | --- |
| `transporte-*` (28 branches), `agent/*`, `codex/*`, `upload-bundle`, `convite-vip`, `ci-evidencias` | Linhagem histórica de transporte/experimentos; nenhuma é folha de OS encerrada |
| `backup/os3-antes-limpeza` | Backup declarado |
| `correcao/consolidacao-bmv`, `correcao/consolidacao-bmv-limpa` | Superseded pela própria base |
| `feat/play-billing-aab-interno-limpa` @ `8ef9ba3ea7f8d05fe1bb659d8ce016044e60addc` | Nasce de `main` (90 commits atrás da base) |
| `main` @ `fb9edb5c6963964161f1e8834b57f50fe77074a1` | Base proibida pela §3 |

---

## 5. Rota funcional do Billing (§9 da OS)

Confirmado o que a OS antecipa: `homologacao/billing-vip-comercial @ 625769d2` é
predominantemente documental, e o código funcional está em
`homologacao/play-billing-comercial @ 0ea96c292f5c9f21ae0a884507c79a4bed3b3d20`.

Cobertura provada por ancestralidade:

```text
0ea96c29 (play-billing-comercial)
   ├── contida em e65495d6 (correcao/assets-loja-v1)
   └── contida em 125ec969 (claude/billing-vip-production-activation-525b63)
```

`feat/play-billing-aab-interno @ bbba26de` **não** cobre essa linhagem: está a 5 commits da
base, contra os 54 de `0ea96c29`. Integrá-la sozinha entregaria a configuração de build sem
o Billing funcional.

Ambas as folhas que cobrem `0ea96c29` também contêm
`integracao/play-billing-flutter @ 319bb8ff` — o commit cujo título é justamente
*"encerrar() deixava o VIP do jogador anterior no painel"*, ou seja, a correção de
`encerrar()` exigida pela §9 entra pela ancestralidade, sem merge avulso.

---

## 6. Artes da Loja (§6 da OS)

| Verificação | Resultado |
| --- | --- |
| Branch | `correcao/assets-loja-v1` |
| SHA remoto completo | `e65495d69fcccc19088adbd8b665f8287ed22e96` |
| Arquivos sob `app/assets/loja/` na folha | **46** |
| Arquivos sob `app/assets/loja/` na base `0cea0d6` | **0** |
| Diff base → folha | `46 files changed, 0 insertions(+), 0 deletions(-)` — todos binários novos, nenhuma arte pré-existente alterada |
| Subpastas | `avatares/` (8), `dorsos/`, `molduras/` e demais |

A folha é aditiva: não há risco de sobrescrita de arte. A conferência de `pubspec.yaml` e do
manifesto contra o código só faz sentido sobre o HEAD composto — que não existe.

---

## 7. Repositório do servidor

| Campo | Valor |
| --- | --- |
| Remoto | `https://github.com/soniaambrosio/buraco-servidor.git` |
| `main` (SHA remoto completo) | `1828d42ef2c95329e81b439b4939353326c2b036` — confere com a âncora `1828d42` |
| `seguranca/ws-auth-identidade` | `71199e81ff44d41c8fcdb41cd866b38c0cf14fee` — confere com `71199e81` |
| `enforcement/visao-espectador` | `3c8b07ef6281ba2c986c1d391c90792a205fa73f` — confere com `3c8b07ef` |
| `correcao/conformidade-canonica` | `09835bdb1dbd65e708840a2d03934fdc5eced234` — **ancestral de `main`**, já coberta |
| `transporte-srv2` | `2fdeda532d3580eeb57274870cc11cc98c9b5dce` — linhagem de transporte, excluída |
| `release/rc-v1` no remoto | Não existe |
| Árvore local | Limpa, em `seguranca/ws-auth-identidade @ 71199e81` |
| Worktrees | Uma só, sem trabalho pendente |

Genealogia: as duas folhas partem de `main @ 1828d42` (base comum confirmada por
`git merge-base`), com 2 e 1 commits respectivamente. Nenhuma contém a outra.

Simulação de conciliação sem escrita (`git merge-tree --write-tree`):

```text
CONFLICT (content): Merge conflict in server.js
```

Conflito **único**, em `server.js`. `package.json` não conflita, ao contrário do que a §10
antecipava. A composição do servidor é executável e de escopo pequeno — está bloqueada
apenas porque a §10 exige que a RC do aplicativo aponte para um contrato compatível, e a RC
do aplicativo não pôde ser criada.

---

## 8. Refs sem proteção remota, medidas no precheck

| Branch (somente local) | SHA em 00:21 | Tipo | Consequência |
| --- | --- | --- | --- |
| `claude/gate-automatizado-rc-v1-819647` | `836b0424edaca64d4c62d10edc4d3f57a86c6880` | Funcional (ferramenta de gate) | Sem ela, a §11 não pode ser cumprida |
| `claude/canonizacao-estado-lixo-v1-75a307` | `25e8d172…` → `c7f4a573…` | Funcional (motor) | Correção da trava do lixo único, posterior a `f41eea0e` |
| `integracao/release-canonica-predeploy-v1` | `a048883f…` → `9c46889e…` | Composição de RC em curso | Terceira RC concorrente |
| `integracao/rc-unica-predeploy-v1` | `746326da…` → `3168677c…` | Composição de RC em curso | Idem |
| `claude/composicao-operacional-release-v1-6b0496` | `708843204031…` (surgiu durante o precheck) | Composição de RC em curso | Idem |
| `claude/legacy-vip-population-census-e784c2` | `c885effdeb731b9732c715cf64188cff6a3e0bb5` | Documental | Censo da população legada VIP |
| `claude/observabilidade-buraco-vip-f3cd12` | `f3f9e53d4a9b298dcbe7783bb6ee49678feeaf09` | Documental | Auditoria de observabilidade |

---

## 9. Comandos usados

```bash
git -C . fetch origin --prune
git -C . ls-remote --heads origin
git -C . for-each-ref --format='%(objectname) %(refname:short)' refs/heads/ refs/remotes/origin/
git -C . rev-list --left-right --count origin/consolidacao/apk-geral-bmv...<folha>
git -C . for-each-ref --contains <sha> refs/remotes/origin/
git -C . ls-tree -r --name-only origin/correcao/assets-loja-v1 -- app/assets/loja
git -C . worktree list --porcelain
git -C <worktree> status --porcelain
git -C F:/Projetos/buraco-servidor merge-tree --write-tree --name-only \
    origin/seguranca/ws-auth-identidade origin/enforcement/visao-espectador
```
