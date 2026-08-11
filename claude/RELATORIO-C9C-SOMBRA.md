# Relatório de paridade — C9-C / C9-C2 (modo sombra + comparador)

**Status:** C9-C2c + C9-C2c-fix + C9-C2c-fix2 **APROVADO no CI #144 — SHA oficial `d0664c2`.**
**Commits (histórico):** C9-C `4e35594` (#140) + C9-C2a+fix `0d03526` (#141) + C9-C2b+fix `2bc7768` (#142) + C9-C2c+fix `fb4d066` + C9-C2c-fix2 → **oficial `d0664c2` (#144)**. **Suíte:** 291 `test()` — todos verdes. **Autoridade:** OFF. **Spec `bmv-regras-2026.08`:** inalterada. **mesa.dart:** continua padrão.

## O que o comparador faz
`app/lib/motor/modo_sombra.dart` roda o motor LEGADO (autoritativo) e o CANÔNICO sobre o MESMO estado projetado e compara. **Puro e sem autoridade**: opera sobre **clones reconstruídos** com o **EnvelopeRuntime COMPLETO**. Flag de **SOMBRA** separada da de autoridade.

**Pipeline:** execução dupla → normalização (`assinatura()`) → **quadrantes de legalidade** → comparação de **estado + envelope operacional relevante** → classificação → diff (`CampoDiff`) → `Replay` por snapshot completo `{canonico,envelope}` para toda divergência.

**Transações semânticas + estabilização:** chamadas legadas viram transações canônicas; o comparador **estabiliza** o que o legado dobra numa só chamada — morto INDIRETO (descarte→`mortoPendente`→PegarMorto viaDescarte), morto DIRETO (baixar esvazia→PegarMorto direto) e BATIDA (baixar/descarte esvazia com morto cumprido→Bater).

**Quadrantes de legalidade EXPLÍCITOS (C9-C2b + fix):** a legalidade de cada motor é **capturada** (`legadoAplicou = tx.aplicarLegado`; `canonicoAplicou = !rc.recusou`), **não deduzida da igualdade de estado**. Classificação: **ambos recusam → CONVERGE só se estado+envelope equivalentes**; **assimétrico** (um aplica, outro recusa) → **SEMPRE divergência** (INESPERADA+Replay, ou EXC verificada), **mesmo que os estados finais coincidam**; **ambos aplicam → compara efeitos**. Nada mascarado.

## C9-C2c — classificador VERIFICADOR de EXC (fechamento pré-C9-D)
A classificação de exceção deixou de aceitar a **tag** `excEsperada` como suficiente. Agora:

- `excVerificada = excEsperada != null && id ∈ excecoesSombra && _verificarExc(...)` — só é EXCEÇÃO se a **condição CONCRETA** da exceção for confirmada no par (pré-estado, transação, quadrante de legalidade).
- **EXC declarada SEM condição real → INESPERADA** (não vira EXC pela tag).
- **Condição real SEM id correto → INESPERADA** (nunca mascarada silenciosamente numa EXC).
- Substitui o antigo `excConhecida` (que aceitava a tag) por `excVerificada`, nas **duas** saídas (ramo assimétrico e ramo simétrico). Os quatro quadrantes de legalidade permanecem explícitos; toda INESPERADA gera diff + Replay completo `{canonico,envelope}`.

### C9-C2c-fix — verificador da EXC-02 comprova a ECONOMIA (não só o formato)
A revisão apontou possível **falso-positivo** em `_ehEXC02` (o predicado antigo confirmava só o *formato*: ≥2 jogos, dupla vulnerável abrindo, legado-recusa/canônico-aplica). Corrigido para exigir a **condição econômica concreta da EXC-02**, comprovada pela **autoridade canônica de abertura** (`avaliarBaixar` — que já aplica a tabela de pontos e o mínimo de vulnerabilidade; **nada é reimplementado no comparador**):

1. direção da assimetria: legado RECUSOU / canônico APLICOU;
2. ação canônica = UM `Baixar` atômico com ≥2 jogos novos;
3. dupla VULNERÁVEL e ainda ABRINDO;
4. **PRIMEIRO jogo, isolado, sujeito ao mínimo e ABAIXO dele** (`avaliarBaixar` de um meld válido-porém-insuficiente devolve `sujeitoAoMinimo=true`/`atingiuMinimo=false`; um meld **inválido** devolve `sujeitoAoMinimo=false` → não satisfaz, **não mascara**);
5. **CONJUNTO atômico ATINGE o mínimo** (é a SOMA que salva);
6. jogos VÁLIDOS pela autoridade canônica (`conjunto.valido`).

**Detector NEGATIVO `C9-EXC02-FORMATO-SEM-ECONOMIA`:** tag `EXC-02` + formato de abertura múltipla vulnerável + assimetria injetada (recusa do legado forçada), MAS o 1º jogo (sequência 8..A copas = 75) já atinge o mínimo sozinho → **INESPERADA** (`idExcecao` null + Replay completo), nunca `excecao`. Prova que só o formato não basta.

### C9-C2c-fix2 — `C9-SOMBRA-05` atualizado ao contrato do verificador
O CI #143 falhou apenas em `C9-SOMBRA-05`, teste obsoleto que presumia "tag conhecida ⇒ `excecao`". Reescrito (patch mínimo, só em `teste_motor.dart`) para usar o **cenário REAL verificável de EXC-02** — o mesmo setup de `C9-EXC02-REAL` — provando a classe `excecao` **sem afrouxar** `_verificarExc`. Asserções: `excecao`, `idExcecao=='EXC-02'`, `replayJson==null` (o ramo `excecao` não carrega Replay; só a INESPERADA carrega). `C9-EXC02-REAL` permanece como prova principal da exceção verdadeira. **CI #144 verde.**

### Verdade de campo das quatro EXC (verificada no código real, não por suposição)
| EXC | Descrição | Situação no código ATUAL | Como é coberta |
|---|---|---|---|
| **EXC-01** | Trinca com curinga | **RECONCILIADA**: o legado atual já recusa Joker em trinca (e o par de naipes distintos não vira sequência); canônico também recusa → **ambos recusam / CONVERGE**. | `C9-EXC01-RECONC` (não dirigível por transação — os dois convergem) |
| **EXC-02** | Abertura múltipla atômica | **DIVERGÊNCIA VIVA** (única dirigível por sombra): legado baixa 1 jogo/chamada (1º < mínimo → RECUSA), canônico soma os dois numa abertura atômica (≥ mínimo → ACEITA). Verificada pela ECONOMIA (C9-C2c-fix). | `C9-EXC02-REAL` e `C9-SOMBRA-05` (excecao+`EXC-02`); negativos `NAO-DECLARADA`, `SEM-COND`, `FORMATO-SEM-ECONOMIA` → INESPERADA |
| **EXC-03** | Lixo fechado desacoplado | **NÍVEL-FUNÇÃO apenas**: o `Acao ComprarLixo` não carrega `jogosNovos`, então não é dirigível por transação de sombra. | `C9-EXC03-FUNC` (chama `avaliarComprarLixo` direto: legado RECUSA topo<mínimo × canônico ACEITA desacoplado) |
| **EXC-04** | Grupo só de ases | **RECONCILIADA em nível de ESTADO**: Fechado ambos ACEITAM (mesmo meld baixado); Aberto ambos RECUSAM (o legado atual barra ás fora do Fechado). Resta só diferença de **classificação/pontuação** (de_as × trinca), fora da assinatura de estado. | `C9-EXC04-RECONC-FECHADO` (ambos aplicam) / `C9-EXC04-RECONC-ABERTO` (ambos recusam) |

O `_verificarExc` reflete isso: só `EXC-02` tem verificador de condição concreta (`_ehEXC02`, econômico). EXC-01/04 retornam `false` (reconciliadas, sem divergência de transação); EXC-03 idem (nível-função). Descrições em `sombra.dart` atualizadas para registrar a reconciliação.

### Reconciliação do finding "monte E mortos ambos vazios" (exaustão)
O canônico `aplicarLegal(ComprarMonte)` com **monte vazio + mortos vazios** agora **ENCERRA a rodada por exaustão** (`proximoEstado.rodadaEncerrada = true`), em vez de recusar — **mesmo efeito do legado** (que encerra a rodada e retorna `false` sem comprar). O legado escreve **só** `rodadaEncerrada=true` nesse caminho (sem score/vencedor/fase), e a `assinatura()` inclui `rodadaEncerrada` — logo os estados coincidem. `TransacaoSombra.comprarMonte` ficou ciente da exaustão (aplicou = comprou **ou** rodada acabou de encerrar). Teste `C9-C2c-EXHAUSTO` → **CONVERGE**.

## Replay reproduzível (C9-C-fix)
Snapshot COMPLETO `{canonico, envelope}` (15 campos runtime+sidecar). `reproduzivel` = seed **OU** snapshot completo validável. `rules/replay.dart` desacoplado de `mesa.dart`.

## Paridade (cenários exercitados — todos verdes no #144)
| Cenário | Resultado | Teste |
|---|---|---|
| Compra do monte (não-vazio) | CONVERGE | C9-SOMBRA-01 |
| Descarte normal | CONVERGE | C9-SOMBRA-02 |
| Injeção (descarta h2 × h1) | INESPERADA + Replay | C9-SOMBRA-03 |
| Monte vazio + morto (reconciliado §8.1 + envelope) | CONVERGE | C9-SOMBRA-04 |
| EXC classificada por condição REAL verificada (EXC-02) | excecao (EXC-02) | C9-SOMBRA-05 |
| EXC id DESCONHECIDO não esconde | INESPERADA + Replay | C9-SOMBRA-06 |
| Replay por snapshot completo | fiel + reaplica | C9-SOMBRA-07 |
| Divergência dependente do envelope | INESPERADA + Replay | C9-SOMBRA-10 |
| ComprarMonte ilegal (fase jogo): ambos recusam | CONVERGE, 0 conversões | C9-C2a-fix-NEG |
| baixar normal / inválido / esvazia→morto direto / esvazia→batida | CONVERGE | C9-BAIXAR-01/02/03, C9-BATER-01 |
| Assimetria de legalidade com ESTADO IGUAL | INESPERADA + Replay (não mascara) | C9-C2b-fix-ASSIM |
| Monte E mortos vazios (exaustão reconciliada) | CONVERGE | C9-C2c-EXHAUSTO |
| EXC-02 abertura múltipla vulnerável (condição econômica real) | excecao (EXC-02) | C9-EXC02-REAL |
| EXC-02 condição real SEM tag | INESPERADA + Replay | C9-EXC02-NAO-DECLARADA |
| EXC-02 declarada SEM condição real (descarte) | INESPERADA + Replay | C9-EXC02-SEM-COND |
| EXC-02 formato vulnerável + assimetria, mas 1º jogo já basta o mínimo | INESPERADA + Replay (economia não confere) | C9-EXC02-FORMATO-SEM-ECONOMIA |
| EXC-01 trinca c/ curinga (Fechado) | CONVERGE (ambos recusam) | C9-EXC01-RECONC |
| EXC-04 grupo de ases (Fechado) | CONVERGE (ambos aceitam trinca) | C9-EXC04-RECONC-FECHADO |
| EXC-04 grupo de ases (Aberto) | CONVERGE (ambos recusam) | C9-EXC04-RECONC-ABERTO |
| EXC-03 lixo fechado desacoplado (nível-função) | legado RECUSA × canônico ACEITA | C9-EXC03-FUNC |

**Meta final atingida:** ZERO inesperadas em TODOS os cenários convergentes. As únicas INESPERADAS são as **injeções propositais** (03, 06, 10) e os **negativos do verificador** (EXC-02 NAO-DECLARADA / SEM-COND / FORMATO-SEM-ECONOMIA) — todas com diff + Replay. `EXC-02-REAL` (e `C9-SOMBRA-05`) são as provas da exceção viva declarada+verificada.

## Cobertura e limites (sem "silent caps")
- **Cobre:** compra do monte (§8.1 e **exaustão**), descarte, baixar (normal/inválido/esvazia→morto direto/esvazia→batida), quadrantes de legalidade explícitos, **classificador verificador de EXC por condição concreta (econômica na EXC-02)**, pipeline completo (estado + envelope + Replay).
- **Limite honesto EXC-03:** só verificável em **nível de função** (`avaliarComprarLixo`), porque o `Acao ComprarLixo` não transporta `jogosNovos`. **Não** é silenciosamente omitido — é um teste à parte e está declarado aqui e em `sombra.dart`.
- **Diferença remanescente EXC-04:** de **classificação/pontuação** (de_as × trinca de ases), que não aparece na `assinatura()` de estado; será resolvida na pontuação canônica / aposentadoria do legado (C10).

## Entregáveis (rodada C9-C2c) — CONCLUÍDA
- **Aprovado no CI #144**, SHA oficial **`d0664c2`**. Arquivos tocados: `motor/modo_sombra.dart` (verificador `_verificarExc`/`_ehEXC02` econômico via `avaliarBaixar`, `excVerificada`, fábrica `aberturaMultipla`, `comprarMonte` ciente de exaustão, import de `abertura.dart`); `rules/gerador/gerador.dart` (ComprarMonte encerra rodada na exaustão); `rules/sombra.dart` (descrições EXC-01/EXC-04 RECONCILIADAS); `test/teste_motor.dart` (EXHAUSTO, EXC01/02/03/04, negativos incl. FORMATO-SEM-ECONOMIA, `C9-SOMBRA-05` atualizado, 6 helpers).
- **Revisão estática independente (3×) + investigação empírica do código legado:** confirmada a verdade de campo das quatro EXC, a convergência da exaustão e o verificador econômico da EXC-02.

## Próximo passo
**C9-C2 (fechamento de paridade pré-C9-D) — CONCLUÍDO e aprovado.** **C9-D permanece BLOQUEADO e não iniciado**, aguardando autorização da direção; o novo hash da branch oficial (versionamento desta documentação) será informado como **base do C9-D**.
