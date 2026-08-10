# Relatório de paridade — C9-C (modo sombra + comparador)

**Commit:** `0379145` (C9-C `c822926`/`3381a21` + **C9-C-fix**). **Suíte:** 273 `test()`. **Autoridade:** OFF. **Regras/spec `bmv-regras-2026.08`:** inalteradas.
**C9-C-fix:** commit original `0379145`; aplicado na branch `auditoria/regras-bmv` por cherry-pick sobre `3381a21`, gerando `d9cd88f`.

O fix passa a persistir Replay por snapshot completo `{canonico, envelope}`, incluindo o `EnvelopeRuntime` necessário à reprodução fiel. `Replay.reproduzivel` exige seed ou snapshot completo validável. O teste `C9-SOMBRA-10` comprova reprodução de divergência dependente de `lixoTopoObrigatorio`.
## O que o comparador faz
`app/lib/motor/modo_sombra.dart` roda o motor LEGADO (autoritativo) e o CANÔNICO sobre o MESMO estado projetado e compara. É **puro e sem autoridade**: opera sobre **clones reconstruídos** com o **EnvelopeRuntime COMPLETO** — nenhum efeito em UI/comportamento. A flag de **SOMBRA** (`MotorConfig.sombraAtiva`) é **separada** da de autoridade.

**Pipeline (6 etapas):** (1) execução dupla; (2) normalização (`EstadoJogo.assinatura()`/`normalizar()`); (3) comparação; (4) classificação `CONVERGE | EXC-01..04 | INESPERADA | canonicoRecusou`; (5) diff estruturado (`CampoDiff`); (6) `Replay` automático (por **snapshot**) para toda divergência INESPERADA.

**Transação semântica + estabilização:** chamadas legadas viram transações canônicas; comparação só **após estabilizar** (resolve `mortoPendente` indireto → `PegarMorto(viaDescarte)`).

**Classificação honesta:** só é `EXCEÇÃO` se a transação **declarar** um id **conhecido** em `excecoesSombra`. Não declarada ou id inexistente → **INESPERADA** (nada varrido para EXC genérica).

## Replay reproduzível (C9-C-fix)
- **Snapshot COMPLETO:** `_replay()` persiste `{'canonico': EstadoJogo, 'envelope': EnvelopeRuntime completo}` (15 campos runtime+sidecar). Sem o envelope, uma divergência que **depende** dele (ex.: `lixoTopoObrigatorio`) não se reproduziria.
- **Invariante `reproduzivel`:** `seed != null` **OU** snapshot **COMPLETO validável** — o snapshot precisa conter as duas partes (`canonico` **e** `envelope`); um mapa arbitrário (ex.: `{'a':1}`) **não** conta. A validação estrutural vive em `rules/replay.dart` de forma **genérica** (só o contrato de topo), mantendo `rules/` **desacoplado** de `mesa.dart`; o snapshot trafega como mapa genérico. Nunca se inventa seed.

## Descoberta da sombra (correção de mapeamento, não de regra)
Topo do monte divergia — legado `monte.removeAt(0)` (frente) × canônico `monte.removeLast()` (último). Reconciliado revertendo o monte na projeção (round-trip do C9-B permanece exato). Mapeamento, não regra.

## Divergência de comportamento REGISTRADA (não escondida)
`monte vazio + morto`: legado converte morto→monte e compra; canônico RECUSA. Classificado `canonicoRecusou` + Replay (C9-SOMBRA-04). Divergência a **reconciliar antes do C9-D** — declarada, não silenciada.

## Paridade (cenários exercitados)
| Cenário | Resultado | Teste |
|---|---|---|
| Compra do monte (monte não-vazio) | **CONVERGE** | C9-SOMBRA-01 |
| Descarte normal | **CONVERGE** | C9-SOMBRA-02 |
| Injeção (descarta h2 legado × h1 canônico) | **INESPERADA** + diff + Replay | C9-SOMBRA-03 |
| Monte vazio + morto (legado converte × canônico recusa) | **canonicoRecusou** + Replay | C9-SOMBRA-04 |
| Divergência declarada EXC conhecida | **excecao** (EXC-01) | C9-SOMBRA-05 |
| Divergência com id EXC inexistente | **INESPERADA** (não esconde) | C9-SOMBRA-06 |
| Replay reproduzível por snapshot (projeção completa) | snapshot fiel + reaplica | C9-SOMBRA-07 |
| Invariante `seed` OU snapshot COMPLETO validável | positivo + 2 negativos + seed | C9-SOMBRA-08 |
| Sombra separada da autoridade | flag sombra ≠ autoridade | C9-SOMBRA-09 |
| **Divergência DEPENDENTE do envelope (`lixoTopoObrigatorio`)** | **INESPERADA**, Replay reconstrói o envelope e reproduz a MESMA classificação | **C9-SOMBRA-10** |

**Meta:** ZERO divergências **inesperadas** entre os cenários convergentes declarados (01, 02). 03/06/10 são divergências propositais/dependentes (prova do detector e da persistência do envelope); 04 é finding declarado; 05 é o mecanismo de EXC.

## Cobertura e limites (sem "silent caps")
- **Cobre:** compra do monte, descarte (normal e, via estabilização, → morto indireto), pipeline completo (diff, classificação, Replay com snapshot completo).
- **Ainda NÃO exercitado (declarado):** transações de `baixar`/`bater` e os cenários de meld que disparam EXC-01..04. Entram numa expansão da sombra antes do C9-D/C10.
- **Findings a reconciliar antes do C9-D:** (a) monte vazio → morto (legado converte × canônico recusa); (b) ampliar a sombra para `baixar`/`bater` + EXC-01..04 reais.

## Entregáveis
- **Bundle:** `BMV-APP-C9-C-fix-0379145.bundle`. **Diff:** `C9-C-fix-0379145.diff` (aplica por conteúdo sobre `3381a21`).
- **Arquivos:** `motor/modo_sombra.dart` (serialização envelope/projeção; snapshot completo), `rules/replay.dart` (invariante `reproduzivel` corrigido), testes C9-SOMBRA-07/08/10.
- **Revisão estática independente (2×):** sem erros de compilação; defeitos pegos e corrigidos (fase pós-legado estagnada no C9-C; snapshot sem envelope + `reproduzivel` fraco no C9-C-fix).