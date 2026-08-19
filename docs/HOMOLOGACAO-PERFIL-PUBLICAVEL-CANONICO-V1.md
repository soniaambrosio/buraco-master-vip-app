# Homologação independente — Perfil Publicável Canônico V1

**Veredito: PASS.**

**Branch de trabalho:** `homologacao/perfil-publicavel-canonico-v1`
**Candidata homologada:** `origin/integracao/perfil-publicavel-canonico-v1` @ `e87dd18d8bc8c92fa19132df3f98ca42b6ea6e07`
**Ancestral obrigatório:** `origin/claude/perfil-ranking-estado-canonico-v1-cac971` @ `bc74e30a148a56b00ca7db691a378584efaa5207`
**Referência de auditoria (nunca mesclada):** `origin/claude/casca-producao-auth-roteamento-v2-9c41ae` @ `b246c0723f3e252eadcf313886788c93ffde3534`

---

## 1. Gate Zero

| Verificação | Resultado |
|---|---|
| `git ls-remote` — passagem 1 (refs nominais) | candidata `e87dd18d…`, ancestral `bc74e30a…`, referência `b246c072…` |
| `git ls-remote --heads` — passagem 2 (listagem completa) | os três SHAs idênticos à passagem 1 |
| Refspec de fetch | `+refs/heads/*:refs/remotes/origin/*` — completo, sem truncamento |
| Refs locais após `fetch` | batem exatamente com os três SHAs remotos |
| `bc74e30a…` é ancestral de `e87dd18d…` | **SIM** (`merge-base --is-ancestor`) |
| `b246c072…` está contido em `e87dd18d…` | **NÃO** — é folha irmã, como a OS descreve |
| `merge-base(e87dd18d…, b246c072…)` | `3752ad8c495d5aa4ff699a0e2bbab557d5e7b048` (Casca de produção) |
| Árvore de trabalho | limpa antes e depois |

O refspec foi conferido de propósito: um refspec truncado responde "up to date"
sobre refs congeladas e mentiria sobre ancestralidade. Aqui ele é completo.

**Ressalva de ambiente registrada:** o `git fetch` emitiu
`failed to write commit-graph`. É efeito de atividade concorrente do git nesta
máquina sobre o mesmo repositório; as refs foram escritas corretamente e
`rev-parse` confirma os três SHAs. Não afeta o veredito.

## 2. Delta auditado — `bc74e30…e87dd18…`

Três commits, sete arquivos, +827 −98.

```
fa72a3f perfil: o que não tem fonte deixa de ser desenhado, e o ranking segue canônico
726e2c7 testes: a matriz do Perfil publicável, com o alcançável provado pela Home
e87dd18 docs: o laudo de arbitragem entre as duas folhas da Casca V2
```

| Arquivo | Δ |
|---|---|
| `app/lib/pages/perfil_page.dart` | 18 |
| `app/lib/screens/perfil_screen.dart` | 195 |
| `app/lib/services/perfil_service.dart` | 51 |
| `app/test/casca/auditoria_casca_test.dart` | 72 |
| `app/test/casca/casca_producao_test.dart` | 152 |
| `app/test/ranking/estado_canonico_ranking_test.dart` | 302 |
| `docs/ARBITRAGEM-PERFIL-PUBLICAVEL-V1.md` | 135 |

Nenhum arquivo fora do escopo do Perfil/ranking foi tocado. Nenhuma regra
competitiva, motor, Billing ou Firebase entrou no delta.

## 3. Matriz obrigatória, caso a caso

Cada linha foi conferida **por fora**, com suíte própria
(`app/test/ranking/homologacao_perfil_publicavel_test.dart`, 16 casos escritos
do zero), além de reexecutar as provas da candidata.

| # | Exigência | Veredito | Como foi provado |
|---|---|---|---|
| 1 | Ranking real atravessa sem substituição | **PASS** | `disponivel(liga:'Diamante', posicaoMundial:128)` sai íntegro; `posicaoMundial: 1` (limite inferior legítimo) não é confundido com ausência |
| 2 | `posicaoMundial <= 0` / liga inválida não produzem `#0` nem Bronze | **PASS** | `0`, `-1`, `-128` → `null`; `''`, `'   '`, `'\t'`, `'\n'` → `null`. Higienização em `EstadoRanking`, antes de qualquer tela |
| 3 | Sem classificação mantém identidade e vitrine, com `💎 Liga —` | **PASS** | Nome e `VITRINE EQUIPADA` presentes; `💎 Liga` + `—` presentes; nenhuma de `Bronze/Prata/Ouro/Diamante/#0/no mundo` na tela |
| 4 | Sem classificação não desenha nível, XP, título, placar, presentes nem conquistas | **PASS** | Nenhum de `XP/Nível/Vitórias/Partidas/Canastras/Aproveit/presentes que você recebeu/CONQUISTAS`; e nenhum `Text` isolado `'0'`, `'1'` ou `'0%'` — o selo de nível do avatar sai junto |
| 5 | `conquistas == null` significa "não consultado" | **PASS** | Seção inteira ausente, título incluído; sem o recado de estado vazio |
| 6 | `conquistas == []` permite "Ainda sem conquistas" | **PASS** | Título e recado voltam com a lista vazia |
| 7 | Carregamento exibe esqueleto sem nome ou número inventado | **PASS** | `vmPlaceholder()` em `PerfilEstado.carregando`: sem nome, sem `0`, sem `1`, sem liga |
| 8 | Falha apresenta recarga e não reaproveita VM antigo | **PASS** | `_conteudo()` faz `switch` no estado e os ramos `carregando`/`erro` **não tocam em `vm`** — é estrutural, não apenas testado. Provado entregando `PerfilVM.mock()` (o VM mais "cheio" possível) no estado de erro: nada dela é desenhado |
| 9 | Home, Perfil e compartilhamento leem a mesma instância/estado canônico | **PASS** | `identical(perfil.ranking, rankingDaCascaPublicavel)` é **true** — a mesma instância `const`, não apenas igual. A Home lê `rankingDaCascaPublicavel.liga` em `home_de_producao.dart:108` |
| 10 | Convite termina em `Sou {nome} 👑`, sem pontuação órfã | **PASS** | `endsWith('Sou Sônia 👑')`; sem `.` final, sem `👑 .`, sem `👑 ·`, sem espaço duplo. Com dado real, volta a afirmar e fecha em `.` |
| 11 | Nenhum dos oito elementos absorvidos volta a depender de `statsDemo` | **PASS** | O ramo publicável é `null` para os oito, independentemente da chave; `statsDemo` é `const false`, tem **um** consumidor (`perfil_service.dart:103`) e a auditoria estrutural trava os seis pares proibidos e as sete ausências exigidas |
| 12 | `_assentar` só estabiliza o relógio | **PASS** | Ver §4 — provado por experimento, não por leitura |

### Sobre a exigência 12, que era a mais fácil de aceitar sem provar

`_assentar` bombeia 4 × 400 ms e depois `pumpAndSettle()`. A pergunta da OS é se
isso mascara trabalho assíncrono permanente ou exceção pendente. Foi decidido
por experimento: **o corpo do laço foi removido no overlay** e a suíte reexecutada.

Resultado: 3 casos falharam com `Expected: 'Sônia' / Actual: '…'` — ou seja, sem
os pumps o VM ainda é o *placeholder*. As falhas são de **asserção sobre estado
que não chegou**, e não *timeout*. Isso prova que os pumps fazem trabalho real
(deixam o `Future` de identidade e os 350 ms de I/O simulado do serviço
completarem), e não que uma espera maior esteja convertendo vermelho em verde.

Complementarmente: as três suítes tocadas não contêm nenhum `takeException()`,
`FlutterError.onError` nem `catch` que consuma exceção — então uma exceção
pendente reprovaria o caso; o `pumpAndSettle()` final estouraria em trabalho
permanente; e o teardown do `flutter_test` reprova timer pendente. Nenhum ocorreu.
Também não há `skip:`, `solo:` nem `timeout:` afrouxado em `test/ranking` ou
`test/casca`.

## 4. Gates técnicos

Executados na forma canônica do CI (`ci-os-integracao.yml`): scaffold
`flutter create`, `pubspec.yaml` + `pubspec.lock` do repositório, overlay de
`lib/`, overlay de `assets/` **excluindo `*.dart`**, suítes + seeds de
`app/data/{torneios,colecoes}`, remoção do `widget_test.dart` do scaffold.

| Gate | Candidata | Baseline `bc74e30` |
|---|---|---|
| `flutter pub get` | OK | OK |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **exit 0** — 98 issues, **0 erros** | exit 0 — 98 issues |
| `flutter test test/sessao` | **83 ✓** | — |
| `flutter test test/casca` | **59 ✓** | — |
| `flutter test test/ranking` | **59 ✓** (43 da candidata + 16 desta homologação) | — |
| Suíte Flutter completa | **782 ✓ / exit 0** | **749 ✓ / exit 0** |
| Suítes fora do glob (`teste_`) | **549 ✓** | — |
| **Total executado** | **1331 casos, todos verdes** | — |

Suítes fora do glob, uma a uma (o glob padrão do `flutter test` só apanha
`*_test.dart`, e estas seis usam o prefixo `teste_`):

```
test/integracao/teste_integracao_motores.dart    64 ✓
test/moderacao/teste_moderacao.dart              42 ✓
test/motor/teste_visao_espectador.dart           15 ✓
test/social/teste_social.dart                    90 ✓
test/teste_encerramento.dart                     10 ✓
test/teste_motor.dart                           132 ✓
test/teste_motor_resiliencia.dart               196 ✓
```

**Comparação com o baseline:** 749 → 782. O acréscimo é 17 casos da candidata
mais 16 desta homologação. **Zero regressões**, zero casos perdidos, e a
contagem de issues do analyze é idêntica (98) — a candidata não introduziu
nenhum achado novo de análise estática.

Nenhum teste foi reduzido, comentado, pulado ou afrouxado. Nenhuma espera foi
aumentada para converter falha em verde.

## 5. Verificações adversariais adicionais

Feitas por conta própria, além da matriz:

- **Alcance real a partir de `main()`.** O fecho transitivo de imports foi
  recalculado por ferramenta independente: **35 arquivos**. O único `'Bronze'`
  restante em `lib/` (`screens/ranking_screen.dart:214`) **não é alcançável**;
  `screens/perfil_screen.dart` é. A auditoria da candidata usa o mesmo fecho
  transitivo real, e não uma lista branca — conferido lendo `_alcancaveisDaRaiz()`.
- **A interpolação de colocação em `perfil_screen.dart:690`** está guardada por
  `if (vm.ranking.temPosicao)`. Não há caminho para `#null no mundo`.
- **Barra de XP nos seis subconjuntos parciais** de (`nivel`, `xpAtual`,
  `xpProximo`): nenhum deles desenha barra. Meia barra seria tão inventada
  quanto a inteira. Este caso não existia na candidata.
- **Título com emoji ausente** não produz `'null Campeã'` na faixa. Também não
  existia na candidata.
- **`posicaoMundial: 0` vindo de fonte `disponivel`** não vira `#0` no convite
  copiado — a higienização provada na superfície que sai do aparelho.

## 6. Observações — sem correção, e por quê

Nenhum defeito introduzido ou exposto pela candidata foi encontrado, então
**nenhuma correção funcional foi feita**. Registrado o que apareceu e ficou de
fora do escopo da OS §6:

1. **`_carregar()` não tem guarda de geração.** Duas cargas concorrentes
   (troca de conta rápida) resolvem-se por ordem de chegada, não por ordem de
   emissão: a última a *terminar* vence. Hoje é inofensivo porque o atraso é
   constante (350 ms), então a ordem se preserva; com Firestore real na Fase 2
   pode inverter e mostrar o VM da conta anterior. **Pré-existente** — o corpo
   de `_carregar` não foi tocado pelo delta (`bc74e30` tem o mesmo código).
   Corrigir estaria fora de §6.
2. **Árvore duplicada `app/lib/app/lib/`** (`amigos_screen.dart`,
   `convite_vip.dart`). **Pré-existente e idêntica** na base; não alcançável a
   partir de `main()`. Limpeza ampla é vedada por §6.

## 7. Entrega

- **Correção funcional:** nenhuma — não houve defeito a corrigir.
- **Teste de regressão:** `app/test/ranking/homologacao_perfil_publicavel_test.dart`,
  16 casos independentes cobrindo a matriz, com quatro provas que a candidata
  não tinha.
- **Laudo:** este arquivo.

Branch publicada sem `--force`. Sem PR, sem promoção a RC, sem deploy.

## 8. Ressalvas reais de ambiente

1. **Flutter local 3.41.4; o CI fixa 3.44.8.** Todos os gates rodaram no 3.41.4.
   Analyze e suítes são verdes aqui; uma diferença de comportamento no pin do CI
   não pode ser descartada por esta execução.
2. **`flutter build` continua indisponível nesta máquina** (symlink exige Modo de
   Desenvolvedor). Não afeta esta OS: nenhum gate exigido é de build, e a OS
   proíbe APK/AAB/deploy.
3. **`git fetch` emitiu `failed to write commit-graph`** por concorrência local.
   Refs corretas, conferidas por `rev-parse`.
4. Os gates de Firebase/emulador do `ci-os-integracao.yml` **não foram
   executados**: o delta não toca `functions*`, `firebase/` nem regras. Fora do
   escopo desta OS, e registrado como não executado em vez de presumido verde.

---

**Veredito final: PASS.** A candidata faz o que afirma. O estado canônico de
ranking é uma instância única lida por Home, Perfil e compartilhamento; nenhum
dado demonstrativo aparece com a fonte ausente, carregando ou em falha; a
distinção `null` / `[]` em `conquistas` é real e está provada nos dois sentidos;
e o convite que sai do aparelho não afirma nada que ninguém verificou.
