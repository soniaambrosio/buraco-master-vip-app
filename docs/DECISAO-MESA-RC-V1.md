# Decisão sobre a Mesa — RC V1

**Classificação: E — nenhuma das duas candidatas está apta como folha de Mesa da RC.**
**Bloqueio formal: a consolidação da Mesa exige OS própria.** Nenhum código foi combinado
nesta OS.

---

## 1. O achado que decide a questão

As duas candidatas **são a mesma entrega**. As árvores são bit a bit idênticas:

```text
integracao/fluxo-mesas-pronto-claude  @ daa6bad959c652638c9bd19752c21470d3f8b0c7
integracao/orientacao-mesa-atualizada @ 74d20a64f64e4bb66a287484ba3c4ca98dd877eb

tree daa6bad = 447c19b2a9865ae4496c022b01715de906040f3a
tree 74d20a6 = 447c19b2a9865ae4496c022b01715de906040f3a   ← idêntica
git diff daa6bad 74d20a6  → vazio
```

A diferença é só de genealogia: `daa6bad` chega ao resultado em **1 commit**;
`74d20a6` chega ao mesmo resultado em **3**, sendo dois deles andaimes
(`chore: aplicar patch de orientação sobre head atualizado`,
`chore: corrigir aplicador temporário do patch`). Não há, portanto, disputa de conteúdo
entre elas — a escolha entre A e B seria trivial (`daa6bad`, histórico limpo).

O bloqueio é outro, e é com a entrega **aprovada**.

## 2. Nenhuma das duas descende da entrega aprovada

```text
merge-base(daa6bad, 74d20a6) = a1a1927680ba4cff431650d09519675bdf10aad4   (codex/configuracao-mesas-fluxo)

integracao/fluxo-mesas @ 7a75bab49ca18a2876f43f69996de4903b9d6ccc  é ancestral de daa6bad?  NÃO
                                                                    é ancestral de 74d20a6?  NÃO
```

As duas nasceram de `codex/configuracao-mesas-fluxo @ a1a1927`, um head paralelo, e seguiram
sem incorporar a integração do fluxo de mesas que já havia sido homologada e publicada.

## 3. O que a linhagem das candidatas não tem

Comparando `7a75bab` (aprovada) com `daa6bad` (candidata): **21 arquivos divergentes,
525 inserções contra 2.110 linhas ausentes**. Entre o que existe na aprovada e não existe na
candidata:

| Ausente na candidata | Linhas |
| --- | --- |
| `app/test/mesa_orientacao_runtime_test.dart` | 284 |
| `app/test/mesa_flow_integracao_test.dart` | 187 |
| `app/test/mesa_flow_idempotencia_test.dart` | 129 |
| `app/test/vitoria_celebracao_runtime_test.dart` | 121 |
| `app/tools/print_mesa.dart` | 103 |
| `app/test/superficie_de_teste.dart` | 90 |
| `app/test/vitoria_celebracao_contract_test.dart` (parcial) | 15 |
| `docs/MAPA-INTEGRACAO-FLUXO-MESAS.md`, `docs/PLANO-EXECUCAO-…`, `docs/RESULTADO-…` | 592 |

Suítes de Mesa por árvore:

| Aprovada `7a75bab` (13 suítes) | Candidata `daa6bad` (9 suítes) |
| --- | --- |
| `configurar_mesa_ui_contract_test.dart` | `configurar_mesa_ui_contract_test.dart` |
| `mesa_config_contract_test.dart` | `mesa_config_contract_test.dart` |
| `mesa_config_validator_test.dart` | `mesa_config_validator_test.dart` |
| `mesa_flow_idempotencia_test.dart` | — |
| `mesa_flow_integracao_test.dart` | — |
| `mesa_flow_plan_test.dart` | `mesa_flow_plan_test.dart` |
| `mesa_flow_preview_host_test.dart` | `mesa_flow_preview_host_test.dart` |
| `mesa_launch_spec_test.dart` | `mesa_launch_spec_test.dart` |
| `mesa_orientacao_runtime_test.dart` | — |
| `mesa_orientation_contract_test.dart` | `mesa_orientation_contract_test.dart` |
| — | `mesa_orientation_integracao_test.dart` |
| `superficie_de_teste.dart` | — |
| `vitoria_celebracao_contract_test.dart` | `vitoria_celebracao_contract_test.dart` |
| `vitoria_celebracao_runtime_test.dart` | — |

Note o ponto sensível: a entrega aprovada **já tem orientação** — `mesa_orientacao_runtime_test.dart`
e `mesa_orientation_contract_test.dart`. As candidatas substituem a suíte de runtime por
`mesa_orientation_integracao_test.dart`. Não é um delta que falta na aprovada; são duas
implementações do mesmo assunto, feitas em paralelo.

## 4. A colisão é real, não hipotética

Simulação sem escrita (`git merge-tree --write-tree`, nenhuma árvore alterada):

```text
Auto-merging app/lib/main.dart
CONFLICT (content): Merge conflict in app/lib/mesa.dart
CONFLICT (content): Merge conflict in app/lib/screens/configuracoes_screen.dart
```

`app/lib/mesa.dart` diverge em 637 linhas entre as duas linhagens. É exatamente a colisão de
`MesaScreen` que o Censo de Telas apontou e que a OS de composição mandou **não** resolver.

## 5. Consequência para a RC

A folha 4 da RC, `integracao/ranking-ligas-hall @ 428c4587`, **contém** a entrega aprovada
`7a75bab`. Portanto:

* a RC já herda a Mesa aprovada — menu no cabeçalho, coluna de ações intocada, 13 suítes;
* mesclar `daa6bad` ou `74d20a6` por cima **não** apagaria os arquivos ausentes (elas nunca
  os deletaram; apenas nunca os tiveram), mas exigiria resolver à mão a divergência de
  `mesa.dart` e `configuracoes_screen.dart` — decisão de produto, fora do escopo autorizado;
* deixar as duas de fora mantém a RC coerente e apenas adia a orientação automática.

## 6. Recomendação

1. **Não integrar** `daa6bad9` nem `74d20a64` na RC V1.
2. Abrir **OS exclusiva de consolidação da Mesa**, com escopo: reaplicar a orientação
   automática sobre o head aprovado `7a75bab`, preservando as quatro suítes que a linhagem
   `codex/` não tem, e decidir qual das duas implementações de orientação sobrevive
   (`mesa_orientacao_runtime` da aprovada × `mesa_orientation_integracao` da candidata).
3. Se, mesmo assim, for preciso escolher uma das duas branches como ponto de partida do
   trabalho, usar **`integracao/fluxo-mesas-pronto-claude @ daa6bad9`** — mesmo conteúdo, um
   commit só, sem os dois `chore` de aplicador temporário.
