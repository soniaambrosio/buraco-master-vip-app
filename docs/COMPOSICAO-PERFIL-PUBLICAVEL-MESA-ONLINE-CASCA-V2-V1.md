# Composição — Perfil Publicável + Mesa Online/Casca V2 (V1)

Composição de duas linhagens já homologadas, na ordem obrigatória
**B → A**: primeiro a Mesa Online ligada à Casca V2, depois o Perfil Publicável
Canônico V1.

Veredito: **PASS**.

---

## 1. Entradas e topologia

| | Ref | SHA |
|---|---|---|
| **Entrada B** (primeira) | `homologacao/ligacao-motor-canonico-casca-v2-p0` | `cf8fe37b0c232ad6dd35556ddac7f3e4bb729aa9` |
| **Entrada A** (depois) | `homologacao/perfil-publicavel-canonico-v1` | `4d24dbdb23dbf068d2f857d51907021174b23a46` |
| **Merge-base** | — | `bc74e30a148a56b00ca7db691a378584efaa5207` |

O SHA de A foi resolvido por **duas consultas independentes** de `git ls-remote`
— uma por padrão (`refs/heads/homologacao/*`) e outra por ref nomeada —, com
resultado idêntico.

### Gate Zero — 14/14

| # | Verificação | Resultado |
|---|---|---|
| 1 | Duas consultas `ls-remote` independentes | concordantes |
| 2 | SHA completo de A e SHA exato de B | `4d24dbdb…` / `cf8fe37b…` |
| 3 | Refspec de fetch completo | `+refs/heads/*:refs/remotes/origin/*` |
| 4 | Cada ref buscada explicitamente | feito |
| 5 | `4b3c460…` ancestral de B | ✅ |
| 6 | `e87dd18…` ancestral de A | ✅ |
| 7 | Merge-base único e igual a `bc74e30…` | ✅ (`merge-base --all` devolve uma linha) |
| 8 | A não é ancestral de B, nem B de A | ✅ |
| 9 | `b246c072…` não incorporado | ✅ nas duas |
| 10 | Árvore limpa | ✅ |
| 11 | `git merge-tree` contra os SHAs finais | árvore `10a0329864e7cc8c96a45cb037b4eb3007624087` |
| 12 | Ausência de conflito textual | ✅ exit 0, sem marcação de conflito |
| 13 | Inventário de arquivos comuns e exclusivos | interseção **vazia** |
| 14 | Grafo alcançável recalculado | **39** |

### Deltas de B

| | Arquivos | Linhas |
|---|---|---|
| Funcional (`bc74e30 → 4b3c460`, 5 commits) | 13 | `+5254 / −71` |
| Bruto da entrada homologada (`bc74e30 → cf8fe37`) | 14 | `+5422 / −71` |

A diferença é **exclusivamente documentação**: o laudo de homologação de B e a
correção documental sobre `rodadasVulneravel` e `mortoPego`. A homologação de B
não tocou **nada** sob `app/` — nem código, nem teste.

### Delta de homologação de A

`e87dd18 → 4d24dbd`, dois commits, como a OS previa:

```
c97ffb3  testes: a matriz da OS de homologação conferida por fora
4d24dbd  docs: o laudo da homologação independente do Perfil Publicável V1
```

Toca apenas `app/test/ranking/homologacao_perfil_publicavel_test.dart` (+396) e
`docs/HOMOLOGACAO-PERFIL-PUBLICAVEL-CANONICO-V1.md` (+201). **Nenhuma alteração
em `app/lib/`.**

---

## 2. O merge

Interseção de arquivos entre A e B: **vazia**. `git merge-tree` previu, antes de
qualquer composição, a árvore `10a0329864e7cc8c96a45cb037b4eb3007624087` **sem
conflito** — e a árvore do merge efetivo é exatamente essa. Isso importa por um
motivo prático: toda a bateria de verificação deste laudo rodou contra
`10a0329`, ou seja, contra o conteúdo publicado, e não contra uma reconstrução.

Merge explícito `--no-ff`, sem squash, sem rebase, sem cherry-pick, sem
reconstrução manual de commit e **sem nenhuma resolução manual**. A ordem fica
comprovável nos pais:

```
5b979c0  ← merge
  parent 1: cf8fe37  (Entrada B — Mesa Online/Casca V2)
  parent 2: 4d24dbd  (Entrada A — Perfil Publicável)
```

Delta da composição contra a base: 23 arquivos, `+6846 / −169`. Os nove arquivos
de `app/lib/` alterados são os seis de B (mesa online, lobby e transporte) e os
três de A (`perfil_page`, `perfil_screen`, `perfil_service`). `lib/main.dart`
está **intocado**.

---

## 3. Grafo alcançável a partir de `lib/main.dart`

Recalculado com a mesma técnica de `auditoria_casca_test.dart` — fecho
transitivo dos imports, comentários despojados respeitando aspas:

| Árvore | Alcançáveis |
|---|---|
| Base `bc74e30` | 35 |
| Entrada B | 39 |
| Entrada A | 35 |
| **Composição** | **39** |

O conjunto da composição é **idêntico** ao de B: A não acrescenta nó alcançável,
só altera arquivos que já eram. Os quatro que entram sobre a base são
`lib/casca/mesa_online/{arte_das_cartas,estado_mesa_online,mesa_online_screen,porta_de_comandos_online}.dart`.

---

## 4. Autoridades verificadas

Todas conferidas **sobre a árvore composta**, e restritas ao conjunto alcançável
— um literal em arquivo inalcançável não conta. Foi por isso que
`lib/screens/ranking_screen.dart`, que tem `nome: 'Bronze'`, não constitui
achado: ele **não está entre os 39**.

| Autoridade | Verificação |
|---|---|
| Sessão | entre os 39, só `lib/sessao/autenticacao_firebase.dart` e `lib/sessao/sessao_firebase.dart` importam `firebase_auth`/`google_sign_in`; `FirebaseAuth.instance`/`currentUser` só aparecem nesses dois |
| Ponte | `PonteSessaoOnline` segue como único tradutor sessão → transporte |
| Mesa: retrato cru | `OnlineService.visao` |
| Mesa: leitura | `AdaptadorVisaoOnline.ler()`, porta única |
| Mesa: saída | `PortaDeComandosOnline`, porta única |
| Mesa: sem motor | zero `Jogo(` / `MotorPartida(` em `lib/casca/` |
| Mesa local | alcançável apenas pelo botão Treino, sem rede |
| `EstadoMesaOnline.substitui` | **sem chamador em produção** — permanece assim |
| `rodadasVulneravel`, `mortoPego` | permanecem omissões declaradas, não implementadas |
| Ranking | `EstadoRanking` único; zero `'Bronze'` fora de comentário nos alcançáveis; nenhum fallback de colocação `1` |
| Perfil | cadeia única `HomeDeProducao → PerfilPage → PerfilScreen` |
| Raiz | `main.dart` intocado; nenhuma Preview/maquete alcançável |

---

## 5. Testes

Ambiente: overlay do CI reproduzido passo a passo a partir de
`.github/workflows/ci-os-integracao.yml`. **Flutter 3.41.4** nesta máquina — o CI
pina **3.44.8**; conforme a §11 da OS, os 101 issues foram tratados como
expectativa **a verificar**, e foram verificados.

### Suíte padrão

| Árvore | Casos | Exit |
|---|---|---|
| Base `bc74e30` | 749 | 0 |
| Entrada B | 855 | 0 |
| Entrada A | **782** | 0 |
| **Composição** | **888** | 0 |

A aritmética fecha exatamente:

```
749 + 106 (Mesa Online/Casca) + 17 (Perfil) + 16 (homologação independente) = 888
```

Nenhum teste foi alterado para alcançar a contagem.

### Fora do glob — sete suítes, nominalmente

```
test/teste_motor.dart
test/teste_motor_resiliencia.dart
test/teste_encerramento.dart
test/integracao/teste_integracao_motores.dart
test/moderacao/teste_moderacao.dart
test/motor/teste_visao_espectador.dart
test/social/teste_social.dart
```

Executadas explicitamente sobre a composição: **549 casos, exit 0**. A menção a
"seis suítes" no laudo do Perfil é erro de escrituração, já identificado.

### Suítes sensíveis

As oito da §10.4 mais a suíte independente introduzida por `c97ffb3`
(`test/ranking/homologacao_perfil_publicavel_test.dart`), executadas
explicitamente: **212 casos, exit 0**.

### Total

```
888 padrão + 549 fora do glob = 1.437 casos verdes
```

---

## 6. Analyzer

`flutter analyze --no-fatal-infos --no-fatal-warnings`, mesmo ambiente e mesmo
comando nas quatro árvores:

| Árvore | Issues | Erros |
|---|---|---|
| Base | 98 | 0 |
| Entrada A | 98 | 0 |
| Entrada B | 101 | 0 |
| **Composição** | **101** | **0** |

Comparação **normalizada** por severidade + regra + arquivo:

- composição × Entrada B → **idênticas**; nenhum diagnóstico novo;
- Entrada A × base → **idênticas**; A não introduz diagnóstico;
- composição × base → exatamente os **três** já conhecidos, todos `info` e todos
  em arquivo de teste (`bancada_online.dart` e
  `porta_de_comandos_online_test.dart`);
- nada do baseline desapareceu — **não houve mascaramento**.

Detalhe registrado para quem repetir a medição: na comparação **com** número de
linha, dois `unnecessary_underscores` de `lib/screens/perfil_screen.dart` migram
de `1330` para `1393`. É o mesmo diagnóstico deslocado porque A editou o arquivo,
e não um par novo/perdido. Comparar só a lista com linha produziria dois
"entraram" e dois "sumiram" falsos.

---

## 7. Riscos residuais

1. **Versão do Flutter.** A medição saiu em 3.41.4, não no 3.44.8 pinado pelo CI.
   Os números bateram com as três referências da OS, mas a confirmação no pin é
   do CI.
2. **`substitui` continua sem chamador.** Mecanismo correto para um campo que o
   servidor ainda não emite. Não foi ativado, e não deve ser durante composição.
3. **Omissões declaradas seguem omissões.** `rodadasVulneravel` e `mortoPego`
   não foram implementados — o selo de vulnerável pediria a regra do mínimo por
   nível de vulnerabilidade, que a OS proíbe tocar.
4. **Interseção vazia não é independência.** A e B não compartilham um único
   arquivo, mas A altera `auditoria_casca_test.dart`, que varre o grafo
   alcançável — e o grafo cresceu por causa de B. A composição passou; a lição
   é que o portão que prova independência é o teste, não o `diff`.
5. **Composição produzida por sessão paralela.** O merge `5b979c0` foi criado
   por outra sessão neste mesmo repositório. Seu conteúdo foi conferido por fora
   antes deste laudo: pais na ordem B→A e árvore idêntica à que o `merge-tree`
   previu de forma independente. Nenhum merge, rebase, reset ou cherry-pick foi
   refeito sobre ele.

---

## 8. O que esta composição NÃO fez

Nenhuma correção ou redesenho de código; nenhuma edição manual de arquivo
funcional ou de teste; nenhuma RC; nenhum deploy; nenhum PR; nenhum merge em
branch protegida; nenhuma alteração no servidor. A integração segue para
homologação independente por outro funcionário.
