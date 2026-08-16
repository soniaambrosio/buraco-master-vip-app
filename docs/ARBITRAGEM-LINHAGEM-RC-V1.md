# Arbitragem, congelamento e preparação da linhagem RC V1

**Veredito: PASS.**
Decisão de arbitragem: **abandonar as três composições como candidatas de release e criar a
RC nova a partir de `0cea0d6`**, usando o roteiro de merges da C1 como referência. As três
branches ficam preservadas para auditoria — nenhuma foi apagada, movida ou modificada.

Execução: **2026-08-16, 00:47–01:00 (-03)**, worktree
`buraco-master-vip-app/rc-v1-composition-qa-29b435`.

Documentos irmãos:
[`MATRIZ-CANDIDATAS-RC-V1.md`](MATRIZ-CANDIDATAS-RC-V1.md) ·
[`DECISAO-MESA-RC-V1.md`](DECISAO-MESA-RC-V1.md) ·
[`INSUMOS-PUBLICADOS-RC-V1.md`](INSUMOS-PUBLICADOS-RC-V1.md)

---

## 1. Concorrência — a janela ficou estável

### 1.1 Fetch confiável

O refspec já estava corrigido pela OS anterior e foi reconferido:

```text
remote.origin.fetch = +refs/heads/*:refs/remotes/origin/*
refs remotas antes do fetch: 98   ·   depois: 98   ·   ls-remote --heads: 97
```

Nenhuma conclusão deste relatório usa `refs/remotes/`; toda leitura de estado remoto vem de
`git ls-remote origin` no momento da consulta.

### 1.2 Três snapshots de `ls-remote`

| Snapshot | Horário | Resultado |
| --- | --- | --- |
| A | 00:47:33 | 97 heads |
| B | 00:50:58 | idêntico a A |
| C | 00:55:06 | idêntico a B, **exceto** as duas branches publicadas por esta OS |
| D (confirmação) | 01:01:26 | idêntico a C — nenhuma mudança |

As duas únicas diferenças em toda a janela são `claude/gate-automatizado-rc-v1-819647` e
`diagnostico/rc-v1-parada-precheck` — ambas empurradas por mim, nas §5 e §9.

### 1.3 As refs vigiadas não se moveram

| Ref | 00:47 | 00:50 | 00:55 |
| --- | --- | --- | --- |
| `integracao/release-canonica-predeploy-v1` | `8ee179d` | `8ee179d` | `8ee179d` |
| `integracao/rc-unica-predeploy-v1` | `c4fddda` | `c4fddda` | `c4fddda` |
| `claude/composicao-operacional-release-v1-6b0496` | `96a9fff` | `96a9fff` | `96a9fff` |
| `claude/gate-automatizado-rc-v1-819647` | `836b042` | `836b042` | `836b042` |
| `claude/canonizacao-estado-lixo-v1-75a307` | `948f194` | `948f194` | `948f194` |
| `integracao/fluxo-mesas-pronto-claude` | `daa6bad` | `daa6bad` | `daa6bad` |
| `integracao/orientacao-mesa-atualizada` | `74d20a6` | `74d20a6` | `74d20a6` |

Comparação com a OS anterior, que media movimento a cada minuto: entre 00:21 e 00:26 quatro
refs mudaram e uma branch nova surgiu. Entre 00:39 e 00:42 as três composições pararam. Da
minha primeira leitura em diante, nada mais se moveu. As mtimes dos `index` das worktrees
concorrentes confirmam: 00:39:26, 00:40:40 e 00:42:14, todas anteriores ao início desta
auditoria.

**Conclusão: não há processo ativo modificando as branches auditadas.** A OS pôde seguir
para a arbitragem.

### 1.4 Worktrees com operação pendente

| Worktree | Branch | HEAD | Sujos | Operação |
| --- | --- | --- | --- | --- |
| `vip-production-readiness-4194df` | `integracao/rc-unica-predeploy-v1` | `c4fddda` | 13 | **MERGE_HEAD ativo** — `UU app/lib/mesa.dart`, `UU app/lib/motor/motor_partida.dart`, `AA app/lib/motor/desfecho_partida.dart`, `AA firebase/firestore.rules`, `AA functions/src/index.ts` … |
| `release-canonica-v1-874ff7` | `integracao/release-canonica-predeploy-v1` | `8ee179d` | 5 | nenhuma — mas há 4 arquivos modificados fora de commit, dois deles suítes (`mesa_orientacao_runtime_test.dart`, `sessao/telas_consomem_identidade_test.dart`) |
| `release-v1-composition-6b0496` | `claude/composicao-operacional-release-v1-6b0496` | `96a9fff` | 1 | nenhuma — `?? firebase/codebases.inventario.json` |
| outras 8 worktrees | — | — | 1 a 11 | nenhuma; sujeira de build, `.dart_tool/`, `firestore-debug.log` |

Nada foi limpo, abortado ou concluído. O merge aberto em `vip-production-readiness-4194df`
permanece exatamente como estava.

---

## 2. Gate automatizado — publicado e homologado

```text
claude/gate-automatizado-rc-v1-819647
local  : 836b0424edaca64d4c62d10edc4d3f57a86c6880
remoto : 836b0424edaca64d4c62d10edc4d3f57a86c6880
```

Publicado como branch nova (`* [new branch]`), sem force-push. Homologação completa — árvore
limpa, `836b042` contém `9fd3a67`, ferramentas em `ferramentas/portao-rc/`, **66/66 testes
PASS com zero pulos**, as quatro demonstrações exigidas presentes na evidência, nenhum
secret e nenhum recibo de ambiente versionado — está detalhada em
[`INSUMOS-PUBLICADOS-RC-V1.md`](INSUMOS-PUBLICADOS-RC-V1.md) §3.

Com isso, o insumo que travava a homologação da RC deixou de existir só no disco.

---

## 3. Arbitragem das três composições

A matriz completa está em [`MATRIZ-CANDIDATAS-RC-V1.md`](MATRIZ-CANDIDATAS-RC-V1.md). O
resumo:

| | C1 `release-canonica-predeploy-v1` | C2 `rc-unica-predeploy-v1` | C3 `composicao-operacional-release-v1` |
| --- | --- | --- | --- |
| HEAD | `8ee179d` (339 commits) | `c4fddda` (220) | `96a9fff` (190) |
| Folhas centrais | **12/13** | 10/13 | 5/13 |
| Motores C e D | **sim, C→D, + canonização do lixo** | não | não |
| Gate | **sim** | não | não |
| Código próprio inventado | nenhum | nenhum | **1 commit funcional** |
| Estado do worktree | 4 modificados fora de commit | **merge aberto, 13 conflitos** | 1 não rastreado |
| Publicado | não | não | não |

### 3.1 Por que C1 não venceu, apesar de ser a melhor

C1 é, de longe, a composição mais avançada: 22 merges de folha, ordem correta dos motores
(Motor C em `563c23f`, Motor D em `8bbad91`, canonização do lixo em `ec9f88b`), 46 artes,
gate embutido, 15 dos 22 merges com conflito registrado no corpo da mensagem, e nenhum
arquivo de transporte, backup ou agente na árvore.

Mesmo assim reprova em quatro dos dez critérios mínimos da §6.1:

1. **HEAD não publicado.** A branch não existe no `origin`.
2. **Não é reproduzível só com objetos publicados.** Seis dos seus commits diretos são
   cherry-picks de branches documentais, e duas dessas fontes —
   `claude/observabilidade-buraco-vip-f3cd12` e `claude/legacy-vip-population-census-e784c2`
   — continuam apenas locais.
3. **Depende de arquivos sujos.** Há 4 modificações fora de commit no worktree, duas em
   suítes de teste. Não dá para afirmar que o HEAD é o estado que a sessão considerava
   pronto.
4. **Não tem manifesto da própria composição.** O `docs/RC-V1-MANIFESTO-DE-COMPOSICAO.md`
   que ela carrega é o documento da OS de proteção das folhas, anterior, e não descreve
   estes 22 merges nem as resoluções de conflito.

Some-se que **nenhum teste foi executado sobre o HEAD**: não há recibo do portão na árvore,
e portanto a coexistência dos Motores C e D — o ponto mais delicado da composição — está
afirmada pela ordem dos merges, não demonstrada.

### 3.2 Por que C2 e C3 estão fora sem discussão

**C2** está no meio de um merge, com `AA` (ambos adicionaram) em
`app/lib/motor/desfecho_partida.dart`, `functions/src/index.ts` e `firebase/firestore.rules`
— exatamente a colisão dos motores e do backend. Além disso não tem os Motores C e D nem o
gate. Uma composição interrompida no conflito mais difícil não é candidata.

**C3** é um fork de C1 em `a048883` que cobre 5 das 13 folhas e traz um commit de código de
produção próprio, `96a9fff feat(online): logout e troca de conta invalidam a sessão
autenticada`, sem folha, sem OS e sem homologação. O critério 6.1 rejeita alteração funcional
improvisada durante a composição — e este é o caso exato.

### 3.3 Decisão

Não há vencedora inequívoca. Pela regra 6.2:

> **DECISÃO: ABANDONAR AS TRÊS COMO CANDIDATAS DE RELEASE**
> **RECOMENDAÇÃO: CRIAR NOVA RC LIMPA A PARTIR DE `0cea0d6`**

As três branches permanecem intactas no disco, para auditoria. Nenhuma foi apagada.

**Isso não joga fora o trabalho da C1.** A ordem de merges dela é um roteiro válido, e todas
as folhas que ela integrou estão publicadas (as duas exceções documentais estão listadas em
[`INSUMOS-PUBLICADOS-RC-V1.md`](INSUMOS-PUBLICADOS-RC-V1.md) §4). A RC nova pode reproduzir
o mesmo caminho a partir do remoto, com manifesto próprio e com o portão executado no HEAD
final — que agora existe publicado.

---

## 4. Mesa

**Classificação E — nenhuma apta. Bloqueio formal, com OS própria recomendada.**

O achado que decide: `daa6bad9` e `74d20a64` têm **a mesma árvore**
(`447c19b2a9865ae4496c022b01715de906040f3a`). São a mesma entrega, uma em 1 commit e a outra
em 3. Não há disputa entre elas.

O problema é com a entrega aprovada: **nenhuma das duas descende de
`integracao/fluxo-mesas @ 7a75bab`**. As duas nasceram de `codex/configuracao-mesas-fluxo @ a1a1927`
e chegam sem quatro suítes que a aprovada tem, com `mesa.dart` divergindo em 637 linhas e
com conflito real em `app/lib/mesa.dart` e `app/lib/screens/configuracoes_screen.dart`.

A RC já herda a Mesa aprovada pela folha 4 (`integracao/ranking-ligas-hall` contém
`7a75bab`). Detalhamento e recomendação em [`DECISAO-MESA-RC-V1.md`](DECISAO-MESA-RC-V1.md).

---

## 5. Insumos

* **7 de 7 folhas funcionais posteriores publicadas**, com `local == remoto` conferido por
  `ls-remote` — inclusive a canonização da trava do lixo (`948f194`), que era o insumo
  funcional mais arriscado do precheck anterior.
* **As 2 branches documentais que faltavam foram publicadas** por autorização complementar,
  depois desta arbitragem: `claude/observabilidade-buraco-vip-f3cd12 @ f3f9e53d4a9b298dcbe7783bb6ee49678feeaf09`
  e `claude/legacy-vip-population-census-e784c2 @ c885effdeb731b9732c715cf64188cff6a3e0bb5`,
  ambas com `local == remoto`. Com isso **não resta insumo apenas local**, e o critério que
  reprovava a C1 por irreprodutibilidade passa a depender só do HEAD dela, não das fontes.
  Verificações e a ressalva de exposição estão em
  [`INSUMOS-PUBLICADOS-RC-V1.md`](INSUMOS-PUBLICADOS-RC-V1.md) §4.
* **4 deltas documentais** classificados à parte.
* **2 decisões de produto** seguem bloqueadas e registradas como tais, sem disfarce técnico.

---

## 6. Proibições observadas

| Proibição | Cumprida |
| --- | --- |
| Criar `release/rc-v1` | Não criada |
| Integrar folha funcional / merge funcional | Nenhum |
| Continuar MERGE_HEAD de outra sessão / `merge --continue` | Não |
| Aproveitar alteração não commitada de outro agente | Não |
| Resolver conflitos | Não — a única simulação (`merge-tree --write-tree`) não escreve em árvore alguma |
| Modificar código funcional | Não |
| Alterar `main` | Não |
| Deploy / AAB / Play Console | Não |
| Force-push, rebase, squash | Não — os dois pushes criaram branches novas |
| Apagar branches | Não |
| Eleger composição por número de commits | Não — C1 lidera em commits e mesmo assim foi reprovada |
| Tratar ref local congelada como espelho do servidor | Não — todo estado remoto veio de `ls-remote` |
