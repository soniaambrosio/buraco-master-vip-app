# Relatório de paridade — C9-C (modo sombra + comparador)

**Commit:** `c822926` (sobre `9332aaa`). **Suíte:** 272 `test()`. **Autoridade:** OFF (inalterada). **Regras/spec `bmv-regras-2026.08`:** inalteradas.

## O que o comparador faz
`app/lib/motor/modo_sombra.dart` roda o motor LEGADO (autoritativo) e o CANÔNICO sobre o MESMO estado projetado e compara. É **puro e sem autoridade**: opera sobre **clones reconstruídos** a partir da projeção, com o **EnvelopeRuntime COMPLETO** — nenhum efeito em UI/comportamento. A flag de **SOMBRA** (`MotorConfig.sombraAtiva`) é **separada** da de autoridade.

**Pipeline (6 etapas):** (1) execução dupla; (2) normalização (via `EstadoJogo.assinatura()`/`normalizar()`); (3) comparação; (4) classificação `CONVERGE | EXC-01..04 | INESPERADA | canonicoRecusou`; (5) diff estruturado (`CampoDiff` por campo); (6) `Replay` automático (por **snapshot**, Ajuste 3) para toda divergência INESPERADA.

**Transação semântica + estabilização:** chamadas legadas viram transações canônicas; a comparação só ocorre **após estabilizar** (o comparador resolve o `mortoPendente` indireto → `PegarMorto(viaDescarte)`, espelhando o que o legado dobra em `descartar`).

**Classificação honesta (Adendo 5):** uma divergência só é `EXCEÇÃO` se a transação **declarar** um id **conhecido** em `excecoesSombra` (EXC-01..04). Divergência **não declarada** ou com **id inexistente** é **sempre INESPERADA** — nada é varrido para uma EXC genérica. (Mesma disciplina do `critEsperado` do C8.)

## Descoberta da sombra (correção de mapeamento, não de regra)
O comparador **imediatamente pegou uma divergência real de convenção**: o **topo do monte** difere entre os motores — legado compra `monte.removeAt(0)` (topo = frente), canônico `monte.removeLast()` (topo = último). Sem reconciliar, os dois motores comprariam **cartas diferentes** do mesmo monte. **Reconciliado revertendo o monte na projeção** (`paraCanonico`/`aplicarEmJogo`), nas duas direções — **round-trip do C9-B permanece exato** (a reversão dupla se cancela; C9-MAP-01..09 seguem verdes). É correção de **mapeamento**, não de regra.

## Divergência de comportamento REGISTRADA (não escondida)
`monte vazio + morto disponível`: o **legado converte** o morto em monte e compra (`_mortosConvertidos++`); o **canônico RECUSA** (`'monte vazio'`). O comparador classifica como `canonicoRecusou` e **gera Replay** (finding C9-SOMBRA-04). **Não é rule change do C9-C** — é uma divergência de comportamento a **reconciliar antes do roteamento (C9-D)**. Fica **declarada aqui**, não silenciada.

## Paridade (cenários exercitados no C9-C)
| Cenário | Transação | Resultado esperado | Teste |
|---|---|---|---|
| Compra do monte (monte não-vazio) | `comprarMonte@0` | **CONVERGE** | C9-SOMBRA-01 |
| Descarte normal (mão ≥ 2) | `descartar@0` | **CONVERGE** | C9-SOMBRA-02 |
| Injeção de divergência (descarta h2 legado × h1 canônico) | custom | **INESPERADA** + diff + Replay | C9-SOMBRA-03 |
| Monte vazio + morto (legado converte × canônico recusa) | `comprarMonte@0` | **canonicoRecusou** + Replay | C9-SOMBRA-04 |
| Divergência declarada EXC conhecida | custom (exc=EXC-01) | **excecao** (idExcecao=EXC-01) | C9-SOMBRA-05 |
| Divergência com id EXC **inexistente** | custom (exc=EXC-99) | **INESPERADA** (não esconde) | C9-SOMBRA-06 |
| Replay reproduzível por snapshot | — | snapshot fiel + reaplica ações | C9-SOMBRA-07 |
| Invariante `seed` OU snapshot | — | `reproduzivel` correto | C9-SOMBRA-08 |
| Sombra separada da autoridade | — | flag sombra ≠ autoridade | C9-SOMBRA-09 |

**Meta:** ZERO divergências **inesperadas** entre os cenários **convergentes declarados** (01, 02). As divergências de 03/06 são **injeções propositais** (prova do detector); 04 é um **finding declarado**; 05 é o **mecanismo** de classificação EXC.

## Cobertura e limites (sem "silent caps")
- **Cobre:** transações de **compra do monte** e **descarte** (normal e, via estabilização, descarte→morto indireto), mais o pipeline completo (diff, classificação, Replay).
- **Ainda NÃO exercitado na sombra (declarado, não escondido):** transações de **`baixar`** (atômica/multi-jogo) e **`bater`** — que no legado dobram morto/batida e no canônico são transições explícitas; e os **cenários de meld** que disparam **EXC-01..04** (trinca com curinga, abertura múltipla, lixo desacoplado, grupo de ases). Estes entram numa expansão da sombra antes do C9-D/C10.
- **Findings a reconciliar antes do C9-D:** (a) monte vazio → morto (legado converte × canônico recusa); confirmar se o canônico modela a conversão em outro passo. (b) revisar demais caminhos de `baixar`/`bater` sob a mesma lente.

## Entregáveis
- **Bundle:** `BMV-APP-C9-C-c822926.bundle` (requer `9332aaa`, fast-forward).
- **Diff:** `C9-C-c822926.diff`.
- **Arquivos:** `motor/modo_sombra.dart` (novo), `rules/replay.dart` (seed opcional + invariante), `motor/projecao_estado.dart` (reversão do monte), testes C9-SOMBRA-01..09.
- **Revisão estática independente:** sem erros de compilação; 1 defeito lógico pego e corrigido (fase pós-legado estagnada → limpeza do transporte antes de projetar, espelhando `AdaptadorLegado._saida`).