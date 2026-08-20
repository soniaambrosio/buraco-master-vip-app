# OS 12.1 — Torneios — correção do P0 semântico V1

**Base congelada:** `claude/torneios-mock-admin-cleanup-b0e388` @
`c65a61b724fdceb3661bc26e3fb6b1b4e11f525e`, confirmada no remoto antes de
qualquer edição, com refspec completo (`+refs/heads/*:refs/remotes/origin/*`).
**Branch de entrega:** `claude/a11y-torneios-p0-semantico-v1-3b34db`.
**Sem merge, sem PR, sem deploy. Torneios continua fora do fecho de `main()`.**

Fonte obrigatória: o laudo integral da OS 12, *Acessibilidade da folha de
Torneios* — nove superfícies montadas e medidas em runtime, veredito
**REPROVADA como folha candidata**, três achados P0.

---

## 1. O que a OS 12 mediu, e o que desta OS era escopo

A OS 12 registrou **três** achados P0. Dois são semânticos, e são estes que a
OS 12.1 fecha. O terceiro é de layout e pertence à OS 12.2, que continua
bloqueada até a arbitragem desta entrega.

| # | Achado | Arquivo · linha | Natureza | Nesta OS |
|---|---|---|---|---|
| P0-1a | "Ver classificação" — `IconButton` sem `label` e sem `tooltip` | `torneios_screens.dart:1383` | semântico | **corrigido** |
| P0-1b | "Compartilhar conquista" — idem | `torneios_screens.dart:1709` | semântico | **corrigido** |
| P0-2 | `Switch` cru cujo rótulo é nó **irmão** | `torneio_modelo_screen.dart:307` | semântico | **corrigido** |
| P0-3 | Estouro de `RenderFlex` na escala de fábrica | `torneios_screens.dart:1522 · 1647 · 720 · 600` | layout | **intocado — OS 12.2** |

O laudo da OS 12 já previa este recorte: a §20 nomeia uma "OS de nomeação
semântica", independente de tudo, e uma "OS de layout elástico" separada — a
mais cara das duas, porque mexe em `Row`, em alturas fixas e na escala
tipográfica inteira.

---

## 2. Reprodução, antes de editar

As árvores foram colhidas do `SemanticsOwner` sobre a base congelada, com a
view em 360×800 dp e escala de fábrica, ANTES de qualquer alteração.

### P0-1a · Sala de espera

```
d=4 "" [tip=Voltar]  {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus>  48x48
d=4 "Sala de espera"                                                               242x24
d=4 "Quarta da Vulnerabilidade"                                                    244x15
d=4 ""               {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus>  48x48   <- SEM NOME
```

### P0-1b · Resultado

```
d=4 ""               {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus>  48x48   <- SEM NOME
```

### P0-2 · Formulário de modelo — três nós IRMÃOS em `d=6`

```
d=6 "Modelo recorrente"                                                            192x40
d=6 "Todas as decisões finais serão validadas pelo Claude."                        192x60
d=6 ""  {hasEnabledState,isEnabled,hasToggledState,isToggled,isFocusable} <tap>      60x48  <- SEM NOME
```

A barreira de uso, no que a medição mostra: o leitor de tela anuncia "botão" e
para aí. Na Sala de espera, aquele botão é a **única** saída para a
classificação.

---

## 3. As correções, e por que estas e não outras

### P0-1 — `semanticLabel` no ícone, e não `tooltip`

O nome foi para o `semanticLabel` do `Icon`, que produz o campo **primário** do
nó. O `tooltip` cairia em `tooltipText`, que é secundário: o TalkBack só o lê
quando não há descrição de conteúdo, e outros serviços não o leem. O próprio
laudo classifica "nomeado só por tooltip" como **P2** — e P2 está fora desta
OS, razão pela qual os outros seis controles só-ícone da folha **não foram
tocados**.

Acrescentar um `tooltip` também teria sido afordância visual nova (menu de
toque longo), e o §6 da OS proíbe mudança visual.

O nome diz a **ação**, não o desenho do ícone: "Ver classificação", não
"leaderboard".

### P0-2 — `MergeSemantics`, e não `SwitchListTile`

Os outros doze toggles da folha usam `SwitchListTile`, que internamente resolve
o problema com `MergeSemantics`. Trocar este por um `SwitchListTile` **mudaria
o desenho**: aqui a linha é ícone + coluna de dois textos + `Switch` numa `Row`,
e o `SwitchListTile` impõe a sua própria estrutura. Isso violaria o §6.

`MergeSemantics` entrega a mesma semântica **sem tocar em uma única medida**:
não é widget de layout, apenas colapsa a subárvore num nó único, que passa a
carregar nome, estado de alternância e ação de toque juntos. É exatamente a
forma dos doze que já acertavam.

---

## 4. Depois

```
d=4 "Ver classificação"       {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus>  48x48
d=4 "Compartilhar conquista"  {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus>  48x48
d=6 "Modelo recorrente / Todas as decisões finais serão validadas pelo Claude."
                              {hasEnabledState,isEnabled,hasToggledState,isToggled,isFocusable} <tap,focus>
```

**Prova de que o layout ficou intacto:** o `diff` das árvores semânticas
completas das três superfícies — todos os nós, com bandeiras, ações e
retângulos — antes × depois tem **exatamente três alterações**, e são os três
reparos. Nenhum outro nó mudou, nenhum retângulo mudou, e os dois botões
continuam medindo 48×48 dp, que é o que a OS 12 mediu antes da correção.

---

## 5. A fronteira com a OS 12.2 é guardada por teste

Os estouros de `RenderFlex` continuam onde estavam, e o portão os afirma **por
valor**: 102 px (`_ConfrontoCard`, linha 1647) e 177 px (`FaixaTorneioMesa`,
linha 1522), em 360 dp @100%.

A afirmação vale para os dois lados. Se alguém corrigir um estouro por dentro
de uma OS de reparo semântico, o portão fica **vermelho** e a correção volta
para a OS 12.2, onde ela é medida junto com as nove superfícies em três escalas
e duas geometrias.

---

## 6. O que NÃO foi feito

* nenhuma alteração de tamanho, proporção ou responsividade;
* nenhum estouro corrigido;
* nenhum P1 corrigido — anúncio de mudança de fase, confirmação de ação
  irreversível, barras de progresso sem objeto, pares rótulo/valor sem
  associação, ausência de `isHeader` e alvos de toque abaixo de 48 dp
  continuam em aberto, para as OS 12.2 e 12.3;
* nenhum P2 corrigido — os seis controles nomeados só por `tooltip` seguem
  como estão;
* nenhuma rota produtiva: Torneios continua com **zero** arquivos no fecho de
  `main()`, e a preview page continua sem importador;
* nenhum mock reintroduzido, nenhum `mostrarAdmin`, nenhum claim `admin`
  produzido ou investigado;
* Functions, Rules e servidor não foram tocados;
* nenhuma implementação de localização pt-BR aberta;
* nenhum gatilho ou permissão de CI ampliado.

---

## 7. O portão

`app/test/torneios/a11y_p0_semantico_test.dart` — 19 provas, ligado aos **dois**
workflows: um passo próprio em `.github/workflows/build.yml`, espelhando o
portão irmão do saneamento, e o alvo `torneiosa11y` em
`.github/workflows/ci-os-integracao.yml`, **com a chave acrescentada às duas
listas** — a da evidência e a do veredito. Só a do veredito faz o portão ficar
vermelho; sem a da evidência, o alvo roda e não aparece no relatório.

Estar na lista do veredito, porém, ainda não bastava: era possível desligar o
portão apagando o arquivo de teste. Ver a §8.

A prova lê a árvore semântica real e exerce o toque pelo `SemanticsOwner` — o
caminho que a tecnologia assistiva usa —, e não por hit-test de pixel. Nenhuma
afirmação depende de busca textual pelo reparo.

### Observação de bancada, que vale para as próximas OS

A primeira mutação de layout injetada contra este arquivo **não deixou o portão
vermelho: deixou-o pendurado.** Quando um `expect` reprova, o corpo do teste é
interrompido e a desmontagem explícita nunca roda; o `Timer.periodic` da Sala
de espera fica vivo e a suíte trava no teste seguinte. Um portão que trava ao
reprovar não informa nada — e num CI consome o job inteiro até o timeout.

A desmontagem passou a ser registrada em `addTearDown` dentro da própria
bancada de montagem, que roda em qualquer saída. Vale para qualquer tela desta
base que mantenha timer próprio.

---

## 8. O veredito obrigatório — o portão podia ser desligado apagando o teste

Estar no veredito não bastava. A função `roda` do `ci-os-integracao.yml`
escreve `nao_<chave>` quando o **arquivo** não existe, e o laço do veredito
tratava `nao_<chave>` como neutro — "NÃO EXECUTADO", sem somar no `fail`.

Isso é deliberado para a maior parte da lista: alvos de emulador e de Node
dependem de serviço externo, e um passo que nem chegou a rodar não é evidência
de regressão do código. Só que o mesmo tratamento deixava **apagar a suíte**
ser a maneira mais barata de voltar ao verde — a única forma de "consertar" um
portão vermelho sem consertar nada.

`torneiosa11y` passou a ser **obrigatório**: ausência é FALHA nos três
caminhos — arquivo ausente, marcador de execução ausente, e passo que não
chegou a rodar. E a lista do veredito saiu do literal do `for` para uma
variável, porque declarar uma chave obrigatória não vale nada se ela puder ser
apagada da lista: uma conferência final exige que todo obrigatório esteja
realmente sendo percorrido.

O relatório de evidência foi alinhado junto. Sem isso ele marcaria "NÃO
EXECUTADO" — neutro — para o gate que acabou de deixar o portão vermelho, e
quem lesse a evidência procuraria a causa no lugar errado.

### A prova

Os scripts não foram digitados para o teste: `veredito_antes.sh`,
`veredito_depois.sh` e a função `roda` foram **extraídos do YAML** — o de antes
de `c8971e7`, o de depois da árvore de trabalho. A prova exercita o script que
vai rodar no CI. No cenário "apagada", quem produz o marcador é a **função
`roda` real**, e não uma suposição sobre qual marcador ela escreveria: a cadeia
arquivo ausente → `nao_<chave>` → veredito está provada ponta a ponta.

| cenário | `c8971e7` (antes) | agora |
|---|---|---|
| suíte presente e verde | VERDE `exit 0` | VERDE `exit 0` |
| **suíte apagada** | **VERDE `exit 0`** | **VERMELHO `exit 1`** |
| **passo não chegou a rodar** | **VERDE `exit 0`** | **VERMELHO `exit 1`** |
| chave apagada da `LISTA` do laço | — | **VERMELHO `exit 1`** |

O caminho verde continua verde: o endurecimento não reprova quem não deve.

### O que não mudou

`gatilhos`, `permissions`, `jobs` e a **contagem de passos** dos três workflows
são idênticos antes e depois, conferidos por parse de YAML e não por leitura:

```
ci-os-integracao.yml  push:[integracao/os-final-backend-flutter] + workflow_dispatch
                      permissions {contents: write}   jobs=validar   passos=20
build.yml             push:[main, master, codex/inicio-ui] + workflow_dispatch
                      permissions {contents: write}   jobs=build     passos=47
web.yml               workflow_dispatch
                      permissions {contents: read, pages: write, id-token: write}
                      jobs=build,deploy               passos=19
```

Mudaram apenas corpos de `run:` e um nome de passo. `app/lib` não foi tocado.

### Uma folga que fica registrada, e não é desta OS

`torneiosmk` — o portão de saneamento de mock e admin — **continua não
obrigatório**, e continua fora da lista da evidência. Apagar
`saneamento_mock_admin_test.dart` ainda deixa o agregador verde. É o mesmo
defeito, na suíte da OS anterior; fechá-lo é decisão de quem arbitra aquela
entrega, e a mudança é uma palavra na variável `OBRIGATORIOS`.

---

## 9. Provas negativas — 12 mutações, 12 detectadas

Cada mutação foi injetada sozinha, removendo ou distorcendo **um** reparo, com
a suíte rodada em seguida sobre um overlay igual ao do CI.

| # | Mutação | Reparo atacado | Resultado |
|---|---|---|---|
| M1 | `semanticLabel` de "Ver classificação" removido | rótulo | detectada |
| M2 | `semanticLabel` de "Compartilhar conquista" removido | rótulo | detectada |
| M3 | `MergeSemantics` removido — `Switch` volta a ser irmão do rótulo | agrupamento | detectada |
| M4 | correção preguiçosa: nome no `Switch`, texto **duplicado** ao lado | duplicação | detectada |
| M5 | dois nós semânticos para a mesma ação | ação única | detectada |
| M6 | nome do **ícone** ("leaderboard") em vez do nome da ação | rótulo | detectada |
| M7 | callback trocado, nome mantido | callback | detectada |
| M8 | estouro de layout "corrigido" — antecipa a OS 12.2 | fronteira 12.2 | detectada |
| M9 | Torneios ligado à Casca — rota produtiva criada | ausência de rota | detectada |
| M10 | `mostrarAdmin` de volta em `lib/` | ausência de admin | detectada |
| M11 | `onPressed: null` — ação e estado somem, nome fica | estado + ação | detectada |
| M12 | `ExcludeSemantics` no botão — leva a ação junto com a decoração | ação única | detectada |

M3 e M4 foram refeitas depois de uma primeira tentativa que reprovou por **erro
de compilação**, e não por detecção. Uma mutação que não compila não prova
nada: ela reprova qualquer suíte, inclusive uma vazia. As duas foram
reconstruídas a partir do arquivo pristino de `c65a61b` e detectadas de fato.

---

## 10. Medições

### `flutter analyze --no-fatal-infos --no-fatal-warnings lib test`

| árvore | issues | erros | saída |
|---|---|---|---|
| base congelada `c65a61b` | 107 | 0 | 0 |
| esta entrega | 109 | 0 | 0 |

Delta de **exatamente +2**, os dois no arquivo de teste novo e os dois
`deprecated_member_use` — `pipelineOwner` e `hasFlag`, que não têm substituto
capaz de percorrer a árvore INTEIRA, e é a árvore inteira que este arquivo
mede. O acesso obsoleto está centralizado num auxiliar só, para que a dívida
seja uma linha e não cinco. **Os dois arquivos de `lib/` não acrescentaram
nenhum issue.**

O portão do CI trata erro como fatal e tolera infos, por decisão registrada no
próprio passo: a árvore já carrega depreciações pré-existentes.

### Suítes Flutter — a parte do agregador que roda nesta máquina

| chave | alvo | verdes | status |
|---|---|---|---|
| `motor` | `test/teste_motor.dart` | 132 | VERDE |
| `resil` | `test/teste_motor_resiliencia.dart` | 196 | VERDE |
| `encerr` | `test/teste_encerramento.dart` | 10 | VERDE |
| `torneios` | `test/torneios/reward_grants_test.dart` | 80 | VERDE |
| `mtorneios` | `test/torneios/motor_torneios_test.dart` | 179 | VERDE |
| `integr` | `test/integracao/teste_integracao_motores.dart` | 64 | VERDE |
| `colarte` | `test/colecoes/colecao_arte_test.dart` | 14 | VERDE |
| `colfire` | `test/colecoes/colecao_firebase_test.dart` | 18 | VERDE |
| `colkit` | `test/colecoes/kit_pioneiros_test.dart` | 81 | VERDE |
| `social` | `test/social/teste_social.dart` | 90 | VERDE |
| `casca` | `test/casca/casca_producao_test.dart` | 30 | VERDE |
| `cascaaud` | `test/casca/auditoria_casca_test.dart` | 17 | VERDE |
| `torneiosmk` | `test/torneios/saneamento_mock_admin_test.dart` | 26 | VERDE |
| `torneiosa11y` | `test/torneios/a11y_p0_semantico_test.dart` | 19 | VERDE |
| `splash` | `test/splash/splash_constelacao_test.dart` | 48 | VERDE |

**Total: 1004 provas verdes, zero falhas.**

Fora de alcance local, e **intocadas por esta OS**: os alvos de Node e de
emulador do `ci-os-integracao.yml` — `billing`, `torneiosfn`, `socialdom`,
`socialfn`, `socialemu`, `rankingfn`, `rankingint`, `identint`, `auditident`
e `regras`. Nenhum arquivo de Functions, Rules ou servidor foi alterado.

---

## 11. Estado

Árvore limpa, `local == remoto`, sem `--force`. A OS 12.2 permanece bloqueada
até a arbitragem formal desta entrega.
