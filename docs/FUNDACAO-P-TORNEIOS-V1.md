# FUNDAÇÃO CONTRATUAL DE TORNEIOS V1 — OS 42

Base autorizada: `integracao/perfil-social-funcional-raiz-p-v1` @
`21ddf47b6320c1e5ddf1c64659d928b68c1f0889`.
Branch entregue: `integracao/fundacao-p-torneios-v1`, publicada sem PR, sem
merge, sem deploy e sem tocar `main`.

A autorização vale para a frente de Torneios. Ela **não** transforma `21ddf47`
em raiz global release-ready, e este documento não afirma isso em lugar nenhum.

---

## 1. Gate Zero

| # | verificação | resultado |
|---|---|---|
| 1 | `21ddf47…` confirmado remotamente | `git ls-remote origin refs/heads/integracao/perfil-social-funcional-raiz-p-v1` devolve o SHA exato |
| 2 | árvore limpa e ancestralidade | checkout em árvore nova, `status --porcelain` vazio; raiz P `5aa8263` é ancestral, 6 commits sobre ela |
| 3 | `99ef93a…` SUPERSEDED e proibida | fora da linhagem P; 505 arquivos contra 941; **não possui `scripts/ci/`**; contida em UMA ref remota (ela mesma); bifurca em `79063e0` |
| 4 | `b99f41a`, `929113b`, `d645bb9` não compostos | nenhum é ancestral nem descendente da base; a entrega descende **só** de `21ddf47` |
| 5 | inventário de Torneios | abaixo, seção 2 |
| 6 | residual `rankingfn PF-01` | reproduzido idêntico à base: **461/462**, única falha `PF-01`, `functions-moderacao/src/index.ts` **11 !== 9** |
| 7 | `functions-ranking/src` intocado | zero arquivos daquele diretório no diff da entrega |

O `rankingfn PF-01` é herdado e permanece **exatamente igual à base**.

**Mas ele NÃO é o único vermelho da base.** `contratosui` também reprova em
`21ddf47`, e a OS não o previu — ver 5.1. Como o §1 diz que "qualquer outro
vermelho é bloqueante", **o veredito desta entrega não é PASS**: é entrega
completa com um segundo vermelho herdado, medido nos dois lados e não
introduzido aqui.

### Por que `99ef93a` não podia ser base

Não é preferência de linhagem: é impossibilidade estrutural. A missão manda
registrar `torneiobase` na **fonte única P** — `scripts/ci/gates_os_integracao.txt`.
Esse arquivo **não existe** em `99ef93a`. Executar a OS ali exigiria recriar a
arquitetura de gates inteira, que é outra missão.

---

## 2. Inventário de Torneios na base

Superfície medida em `21ddf47`, e **idêntica** nas outras pontas da linhagem P:

* **domínio Dart** — 19 arquivos, 8.207 linhas em `app/lib/torneios/`;
* **seeds** — 3 em `app/data/torneios/` (`tournamentTemplates`, `assets_registry`,
  `reward_policies`);
* **Rules** — bloco próprio em `firebase/firestore.rules`, com
  `tournaments`, `editions`, `registrations`, `tournamentHistory`,
  `tournamentTasks` e `tournamentAudit`;
* **índices** — `editions`, `registrations` e `tournamentHistory` em
  `firebase/firestore.indexes.json`;
* **Functions** — codebase `torneios` = `functions/`, **7** `export const`;
* **cliente** — `torneios_screens.dart`, `torneio_modelo_screen.dart`,
  `torneios_models.dart`, `torneios_preview_page.dart`: prévia, sem consumidor
  produtivo de callable;
* **gates de CI existentes** — `torneios`, `mtorneios`, `torneiosfn`;
* **elegibilidade** — `app/lib/elegibilidade/composicao.dart` compõe
  `playerModeration/{uid}` + `playerEntitlements/{uid}`; o P0-1 (`players/{uid}`
  sem produtor) **já está corrigido nesta base**.

---

## 3. As decisões congeladas, e onde cada uma mora

Tudo em `app/lib/torneios/fundacao_v1.dart` — camada pura, sem Firestore, sem
Cloud Function, sem UI e sem relógio implícito.

| decisão | forma no código |
|---|---|
| acesso V1 `somente_convidados` | `kAcessoTorneiosV1` |
| seeds `publico` e `misto` SUPERSEDED | `kAcessosSupersededV1`, `situacaoDoSeedV1` |
| convite válido + VIP integral vigente | `avaliarAdmissaoV1` |
| VIP presenteado não concede acesso | `kOrigensVipIntegralV1` = `{play, legado_usuarios}` |
| participação individual; dupla dormente | `ParticipacaoV1`, `vigenteNaV1` |
| ciclo `rascunho → em_revisao → agendado` | `EstadoEditorialV1`, `kTransicoesEditoriaisV1` |
| criador e aprovador distintos | `avaliarTransicaoEditorialV1` |
| Hall sem candidatura órfã | `avaliarCandidaturaHallV1` |
| os limites da V1 | `kForaDaFundacaoV1`, dez itens |

### Três leituras que a OS não escreveu e a fundação precisou fixar

1. **`acesso: "vip"` não é SUPERSEDED, mas também não é a V1.** A OS declarou
   superseded apenas `publico` e `misto`. Classificar `vip` junto seria decidir
   mais do que foi decidido; servir o seed como está seria decidir por omissão.
   Existe uma terceira situação — `SituacaoSeedV1.reemissaoExigida` — e a medida
   que ela produz é útil: **nenhum dos seis templates do catálogo serve a V1 sem
   reemissão** (caso `FV1-A11`). Só `eventoEncerramento` já nasce admitido.

2. **"VIP presenteado" virou lista fechada de origens.** `playerEntitlements`
   carrega `origem`, e os produtores desta árvore escrevem `play` e
   `legado_usuarios`. A origem `administrativa` está documentada em
   `entitlement.dart` e **não tem produtor** — é exatamente sob ela que um VIP
   presenteado seria escrito. Ficou de fora por lista fechada: origem
   desconhecida recusa, em vez de cair num `else` que concede. O passe de
   cortesia continua excluído por construção (vive em `playerCourtesyPass` /
   `passesVip`, que a admissão não consulta).

3. **O ciclo é só para frente.** Devolver a revisão para rascunho, reprovar e
   desagendar são operações plausíveis que a OS **não** congelou. Inventá-las
   seria decidir produto. Cada uma recusa por
   `RecusaEditorialV1.transicaoInexistente` — recusa nomeada, não silêncio.

---

## 4. O gate `torneiobase`

Registrado na fonte única com contrato de conteúdo completo:

```
torneiobase
    suite      app/test/torneios/fundacao_torneios_v1_test.dart
    executor   roda torneiobase test/torneios/fundacao_torneios_v1_test.dart
    sha256     f49a7ec46cdcfb4f76ea6b7713147183c06203ee9ecba2b4b3038a24a6e7d17d
    provas     70
    casos      70
    exige      (15 literais: os sete grupos + oito casos)
```

Produtor no workflow: `roda torneiobase  test/torneios/fundacao_torneios_v1_test.dart`.
A bijeção fonte ↔ workflow que `composneg` PN-10 e PN-12 exigem continua
fechada nos dois sentidos.

### O grupo que faz o gate valer mais que a soma das assertivas

`FV1-G` afirma, **contra a árvore**, que a fundação não ligou nada:

* `FV1-G01` — a fundação é camada pura (sem Flutter, sem Firestore, sem `dart:io`);
* `FV1-G02` — nenhuma peça fora do recorte é tocada pelo código;
* `FV1-G02b` — controle do recorte de `FV1-G02`, para que ele não fique verde
  por vazio;
* `FV1-G03` — varre os **222** `.dart` de `lib/` e exige **zero** consumidor de
  produção;
* `FV1-G04` — prende a superfície de deploy do codebase `torneios` em **7**
  exports;
* `FV1-G06` — o próprio registro na fonte única e no workflow.

No dia em que uma sucessora ligar a fundação a uma rota, `FV1-G03` fica
vermelho — e a ligação passa a ser decisão escrita no diff, em vez de efeito
colateral.

**A armadilha que `FV1-G02` teve de contornar:** `kForaDaFundacaoV1` nomeia, em
texto, exatamente as peças que a busca caça (`tournamentJobs`, `check-in`,
`carteira`). Varrer o arquivo sem descontar a declaração de limites faria a
prova reprovar o arquivo **por ele declarar a própria abstinência**. O recorte
desconta a lista e falha alto se ela sumir; `FV1-G02b` garante que o desconto
continua estreito.

---

## 5. Placar

| gate | resultado |
|---|---|
| `torneiobase` | **70/70**, exit 0 |
| `torneios` | **80/80**, exit 0 |
| `mtorneios` | **179/179**, exit 0 |
| `cascaaud` | **19/19**, exit 0 |
| `portaoci` (matriz do agregador) | **38/38**, exit 0 |
| `composneg` | **21/21**, exit 0 |
| `verificar_contrato_suites.sh` fase A | 16 contratos, exit 0 |
| `analyze` | 44 issues (28 info + 16 warning), **0 erros**, **0 nos arquivos novos** |
| `rankingfn` | **461/462** — `PF-01` herdado, idêntico à base |
| `contratosui` (matriz) | **33/34, VERMELHO** — ver 5.1 |

### 5.1 O SEGUNDO vermelho, e ele é HERDADO

`contratosui` reprova o caso **T27** (`CONTROLE — evidencia completa e datada
=> VERDE`), e **reprova igual na base**. Medido, não deduzido: montei uma raiz
de controle a partir de `21ddf47` (scripts de CI, workflow e as suítes
contratadas, todos extraídos do próprio SHA) e rodei a mesma bancada.

| árvore | contratos na fonte | placar | falha |
|---|---|---|---|
| base `21ddf47` | 15 | 33/34 VERMELHO | T27 |
| entrega | 16 | 33/34 VERMELHO | T27 |

**O mecanismo.** A FASE B do verificador exige um log `t_<gate>.log` para
**todo** gate contratado. A bancada monta a evidência sintética em
`resultados()`, que escreve exatamente **quatro** logs — `comunicacao`,
`chatdom`, `portaoci`, `contratosui`. Quando a OS de Perfil/Social acrescentou
onze contratos à fonte única, a fixture da bancada não acompanhou: os onze
passaram a não ter log, T27 passou a esperar exit 0 e a receber 1, e o gate
ficou vermelho. `torneiobase` vira o décimo segundo faltante — a mesma falta,
no mesmo caso, sem mover o placar.

Rodando o verificador em FASE B direto, a diferença é só de contagem:

```
base      11 erros "nao deixou log", exit 1
entrega   12 erros "nao deixou log", exit 1   (o 12º é torneiobase)
```

**Não consertei, e a razão é de escopo.** O conserto mora em
`resultados()`, dentro de `scripts/ci/teste_contrato_suites.sh` — arquivo cujo
digest é fixado pelo contrato do próprio `contratosui` (`sha256 77966085…`).
Mexer nele obriga a recarimbar esse digest, que é **exatamente o ponto de
colisão entre as três folhas da linhagem P**: a raiz e `21ddf47` carregam
`77966085…`, `b99f41a` carrega `dc0db488…` e `929113b` carrega `de8d3a58…`.
Produzir um quarto digest aqui encareceria a arbitragem que ainda falta, e
consertar a bancada de gates não é a missão desta OS, que manda criar *somente*
a fundação contratual mínima.

### 5.2 `flutter analyze` não roda nesta máquina, e não é do código

`flutter analyze` aborta com `analysis server exited with code -1073740791`
(`STATUS_STACK_BUFFER_OVERRUN`) e gera `tool_crash`. **Reproduzido com os dois
arquivos novos afastados da árvore** — mesma assinatura, mesmo exit. É defeito
de ambiente (Flutter 3.41.4 / Dart 3.11.1 no Windows), não da entrega.

A medição foi feita pelo outro driver, `dart analyze lib test`, que roda até o
fim: **44 issues, 28 `info` e 16 `warning`, zero `error`, e zero em
`fundacao_v1.dart` ou `fundacao_torneios_v1_test.dart`**. Com
`--no-fatal-infos --no-fatal-warnings`, que é como o workflow invoca, isso é
exit 0.

---

## 6. Limites absolutos respeitados

Não foi implementado, e a lista está em `kForaDaFundacaoV1`, conferida por
`FV1-G05`:

claim `admin` · produtor de edições · consumidor de `tournamentJobs` ·
inscrição produtiva · carteira ou ledger · check-in · cliente/rota produtiva ·
ligação da Central de Torneios · OS 12 visual/A11Y · backend completo.

Não foi transportado mecanismo M, mock, `mostrarAdmin` nem segunda autoridade
de gates. Nenhum arquivo de `functions-ranking/src` foi tocado.
