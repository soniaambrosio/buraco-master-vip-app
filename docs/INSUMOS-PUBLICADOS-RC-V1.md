# Insumos da RC V1 — estado de publicação

Verificado em **2026-08-16, 00:47–00:55 (-03)**, com `git ls-remote --heads origin` a cada
consulta. Nenhuma conclusão usa `refs/remotes/` como fonte.

---

## 1. Publicado por esta OS

| Branch | SHA local | SHA remoto | Igual | Observação |
| --- | --- | --- | :-: | --- |
| `claude/gate-automatizado-rc-v1-819647` | `836b0424edaca64d4c62d10edc4d3f57a86c6880` | idem | ✔ | Novo no remoto; sem force-push. Homologação na §3 |
| `diagnostico/rc-v1-parada-precheck` | `c8ed349a6cf3db63acd0d32a6508a3e1a568225b` | idem | ✔ | Contém somente `docs/COMPOSICAO-HOMOLOGACAO-RC-V1.md` e `docs/RC-V1-MANIFESTO-PROVENIENCIA.md`; pai = `0cea0d6` |

---

## 2. Folhas funcionais posteriores — todas publicadas

As seis folhas apontadas pela auditoria anterior, mais a canonização do lixo publicada
durante o precheck. Nenhuma depende de objeto local.

| # | Branch | SHA local == remoto | Base | Finalidade | Testes próprios | Ancestral de C1 / C2 / C3 | Pronta p/ integração |
| --: | --- | --- | --- | --- | --- | --- | :-: |
| 1 | `correcao/assets-loja-v1` | `e65495d69fcccc19088adbd8b665f8287ed22e96` ✔ | `0cea0d6` (+59) | 46 artes da Loja; carrega a linhagem `homologacao/play-billing-comercial @ 0ea96c29` | herdados da linhagem Billing | SIM / SIM / SIM | Sim |
| 2 | `claude/garantia-encerramento-turno-v1` | `f41eea0e1143f4b2e572a8a7105cbea8aea755f3` ✔ | `0cea0d6` (+83) | Motor D: conclusão legal do turno; contém C10 rev.2/rev.3 e o bot estratégico | 120/120 rodadas documentadas | SIM / — / — | Sim |
| 3 | `claude/account-deletion-google-play-compliance-b94769` | `1acc5f99a98050d734d6fd5da9b5c2ebe30f407c` ✔ | `0cea0d6` (+70) | Exclusão de conta e conformidade Play; carrega identidade de sessão, política competitiva, ranking backend e `publicId` único | matriz de retenção quebra a suíte se faltar coleção | SIM / SIM / SIM | Sim |
| 4 | `claude/billing-vip-production-activation-525b63` | `125ec96954b5d64800f268376db5c034e759ef66` ✔ | `0cea0d6` (+62) | Billing de produção; carrega backfill, recuperação de metadados e o enforcement VIP no cliente | suíte de rules e de Functions | SIM / SIM / — | Sim |
| 5 | `claude/android-api-36-compat-a62a58` | `7e77cfe45f83bd547740c3fabd92aab965dbb02f` ✔ | `0cea0d6` (+53) | Fixa `targetSdk 36` em vez de herdar do pin do Flutter | validação de configuração | SIM / — / — | Sim |
| 6 | `claude/sleepy-kilby-f8ff3f` | `37494dde53dbd3826f1cce14f84792a193992517` ✔ | `0cea0d6` (+35) | Localiza os seeds sem depender do staging do CI | 4 suítes Flutter dependentes de seed | SIM / — / — | Sim |
| 7 | `claude/canonizacao-estado-lixo-v1-75a307` | `948f194e5009640fb2fefe62c13d4ae8678be847` ✔ | `0cea0d6` (+85) | Canoniza a trava do lixo único (§5.2 do ABERTO) sob a autoridade canônica | bateria da §5.2 (regra, ciclo de vida, cópia, bot, varredura) | SIM / — / — | Sim |

> A canonização do lixo era, no precheck anterior, o insumo funcional mais arriscado por ser
> apenas local. Foi publicada por outra sessão às 00:26 e conferida aqui: local == remoto.

---

## 3. Homologação do gate (§5 da OS)

| Verificação | Resultado |
| --- | --- |
| Árvore limpa no SHA auditado | ✔ (worktree temporário em HEAD destacado `836b042`, `status --porcelain` vazio) |
| `836b042` contém `9fd3a67` | ✔ (`merge-base --is-ancestor`) |
| Ferramentas em `ferramentas/portao-rc/` | ✔ — `ambiente.js`, `catalogo.js`, `leitores.js`, `portao-rc.js`, `recibo.js`, `veredito.js`, `portao-rc.test.js` |
| Testes próprios | ✔ **66/66** — `tests 66 · suites 13 · pass 66 · fail 0 · cancelled 0 · skipped 0 · todo 0` (`node --test`, v24.14.0, 703 ms) |
| Demonstração de PASS | ✔ `docs/PORTAO-RC-EVIDENCIA.md` §1 |
| Demonstração de FAIL funcional | ✔ §2 |
| Demonstração de FAIL de cleanup | ✔ §3 |
| Rejeição de recibo antigo | ✔ §7 |
| Secrets no delta | ✔ nenhum (varredura por chaves de API, chaves privadas, tokens e senhas embutidas) |
| Recibos ou artefatos de ambiente versionados | ✔ nenhum — `/.portao-rc/` entra no `.gitignore` no próprio commit, com justificativa |
| Publicação | ✔ novo no remoto, sem force-push; `local == remoto == 836b0424edaca64d4c62d10edc4d3f57a86c6880` |

---

## 4. Ainda apenas locais — documentais

Nenhum dos dois é insumo funcional; nenhum pode constar do manifesto futuro da RC enquanto
não for publicado.

| Branch | SHA local | Conteúdo | Situação |
| --- | --- | --- | --- |
| `claude/observabilidade-buraco-vip-f3cd12` | `f3f9e53d4a9b298dcbe7783bb6ee49678feeaf09` | Auditoria de observabilidade, operação e recuperação de produção (V1) | Só no disco. Já foi levada para C1 por cherry-pick (`9bc57d9`, `dd54251`) |
| `claude/legacy-vip-population-census-e784c2` | `c885effdeb731b9732c715cf64188cff6a3e0bb5` | Censo da população legada VIP (resultado: zero) | Só no disco. Já foi levada para C1 por cherry-pick (`8ee179d`) |

Publicá-las é pré-requisito para que C1 — ou uma RC que replique o roteiro de C1 — seja
reproduzível a partir do servidor. Esta OS não estava autorizada a publicá-las: a §5 e a §9
autorizam nominalmente apenas o gate e o diagnóstico.

---

## 5. Deltas documentais — classificados à parte

| Branch | SHA remoto | Vs. base | Papel | Integrar? |
| --- | --- | --- | --- | --- |
| `auditoria/censo-telas-prontidao-v1` | `a97866cecc467f833ac4a099cb5fbae107d3300d` | +1 | Censo de telas: 27 ativas, 2 prontas | Evidência — justificar caso a caso |
| `claude/production-state-audit-84542f` | `047486f21e300f34ccd1a7495f6a7b058b64f9b9` | +1 | Estado real de produção (três eras) | Evidência |
| `claude/google-play-publication-v1-bf8d5d` | `604f36200c8f927a46364c2d094a9a4c06e8500b` | +1 | Auditoria do pacote de publicação Play | Evidência |
| `claude/protecao-folhas-rc-v1-f2cc65` | `7d521106c52c720c266330b72c0d47e230e68bec` | 90 atrás / +8 | Manifesto da OS de proteção — **nasce de `main`**, não da base autorizada | Evidência; se entrar, só por cherry-pick do documento |

---

## 6. Decisões de produto pendentes — não são decisões técnicas

Estas duas continuam bloqueadas e **não podem ser resolvidas por critério de engenharia**:

1. **Mesa.** Qual implementação de orientação sobrevive: a da entrega aprovada
   (`mesa_orientacao_runtime_test.dart`, em `7a75bab`) ou a das candidatas
   (`mesa_orientation_integracao_test.dart`, em `daa6bad`/`74d20a6`). Ver
   [`DECISAO-MESA-RC-V1.md`](DECISAO-MESA-RC-V1.md).
2. **`96a9fff feat(online): logout e troca de conta invalidam a sessão autenticada`**, em C3.
   É comportamento de produto escrito durante uma composição, sem folha nem OS de origem. Ou
   vira entrega própria, homologada, ou não entra na RC.

---

## 7. Servidor

| Campo | Valor |
| --- | --- |
| `main` | `1828d42ef2c95329e81b439b4939353326c2b036` |
| `seguranca/ws-auth-identidade` | `71199e81ff44d41c8fcdb41cd866b38c0cf14fee` — intacta, árvore limpa |
| `enforcement/visao-espectador` | `3c8b07ef6281ba2c986c1d391c90792a205fa73f` |
| `correcao/conformidade-canonica` | `09835bdb1dbd65e708840a2d03934fdc5eced234` — ancestral de `main`, já coberta |
| RC do servidor | Não existe; não criada por esta OS |

O repositório do servidor não foi tocado nesta OS.
