# Composição — Avatar, Ranking Real V2, Estatísticas e Navegação ao Perfil Público

**Veredito:** `PASS`

Branch: `integracao/avatar-ranking-estatisticas-navegacao-publica-v1`
HEAD final: `a437f5b9aafa35e4d554abe8be6b8ae2c7c82beb` (antes deste laudo)

---

## 1. Entradas e ancestralidade

| Papel | Ref | SHA completo (40) |
| --- | --- | --- |
| Base | `integracao/avatar-publico-ranking-real-v2-v1` | `41a767a49353575b9a251119c0753782659ec3e6` |
| Entrada A — contrato | `claude/contrato-estatisticas-oficiais-perfil-v1` | `79063e07c38e1b2601058504b0083d4a41a33223` |
| Entrada B — navegação | `claude/ranking-navegacao-perfil-publico-v1-5ffffa` | `53105ab861e32cbcaa6ea19bb81e29549276bf98` |

As três refs foram confirmadas por **três consultas independentes**: `git
ls-remote` pelo remoto configurado, `git ls-remote` pela URL explícita e a API
REST do GitHub por `curl`. As três concordam.

### Gate Zero

| # | Verificação | Resultado |
| --- | --- | --- |
| 2 | Base contém `92344ed`, `e1923f19`, `fda063bf`, `6e428e8` | PASS (quatro) |
| 3 | `fda063bf` é ancestral de `79063e07` | PASS |
| 4 | Os dois commits entre eles | `581bd91` + `79063e0` (ver §2) |
| 5 | Relação de `53105ab` com `6e428e8` | `6e428e8` é ancestral; `53105ab` é **irmã** da base, um commit adiante |
| 6 | Testes integrais da base | 1093 Flutter verdes, `analyze` exit 0 |
| 7 | Suítes das entradas, separadamente | ver §5 |
| 9 | Árvore limpa | PASS |

`merge-base(41a767a, 53105ab) = 6e428e8`. Isso é o fato estrutural mais
importante desta OS: **a folha da navegação e a base são irmãs**, então o merge
enxerga uma árvore-base que ainda não conhece nem o avatar canônico nem o
contrato novo.

---

## 2. Ordem dos merges

```
41a767a  (base)
   │
   ├── merge 1 ── 79063e07   merge-base fda063bf   →  512257e
   │
   └── merge 2 ── 53105ab    merge-base 6e428e8    →  ae66fd7
```

Commits produzidos:

```
512257e  merge: trazer o contrato atualizado das estatisticas oficiais (79063e07)
ae66fd7  merge: trazer a navegacao produtiva ao Perfil publico (53105ab)
3475f5f  test: adaptar as tres provas que a entrada da navegacao moveu
a437f5b  test(composicao): a suite propria das quatro entregas juntas
```

Os dois merges têm dois pais cada — nenhum commit das entradas foi
reimplementado à mão.

### Inclusão comprovada dos dois commits de `79063e07`

```
581bd91  torneio vira modalidade conhecida e explicitamente inelegivel
79063e0  docs: laudo atualizado para torneio conhecido e inelegivel
```

Ambos ancestrais do HEAD. Os quatro arquivos que A toca ficaram **idênticos** aos
de `79063e07` (`git diff --quiet 79063e07 -- <arquivo>` para os quatro), o que
era esperado: a base não os tocou desde `fda063bf`.

---

## 3. Conflitos e auto-merges auditados

**Merge 1 — nenhum conflito.** Só os quatro arquivos de A, todos idênticos à
folha. Nenhuma adaptação.

**Merge 2 — nenhum conflito, e dois auto-merges que exigiram auditoria.** O git
mesclou `pages/perfil_page.dart` e `screens/perfil_screen.dart` sozinho porque
os hunks caíram em regiões diferentes do mesmo arquivo. Foi sorte estrutural,
não garantia — nesta linhagem um merge sem conflito já reintroduziu um segundo
dono de autenticação por um hunk que ninguém leu. Conferido à mão:

| Arquivo | De `53105ab` | Da base `41a767a` |
| --- | --- | --- |
| `perfil_page.dart` | construtor que **deriva** `ehMeuPerfil` de `publicIdVisitado`; `_abrirRanking`; `onAbrirRanking`; item Ranking da barra | encadeamento `base → comRanking → comAvatarPublico`, com guarda de `ehMeuPerfil` no ranking e sem guarda no avatar |
| `perfil_screen.dart` | `onAbrirRanking` e a linha competitiva tocável | `comRanking` **e** `comAvatarPublico`, os dois métodos |

`home_de_producao.dart` **não entrou no merge**: `53105ab` não o toca, então o
`avatarRef ?? '👑'` que a árvore-base de `6e428e8` ainda tinha não teve por onde
voltar. Conferido mesmo assim — o arquivo mantém `avatarPublicoDaIdentidade(...)`
e `ranking.ehLigaDeVerdade ? ranking.liga : null`.

---

## 4. Adaptações inevitáveis

Três, todas em teste, nenhuma afrouxando o que a prova protege.

### 4.1 O fake do transporte (`composicao_avatar_ranking_test.dart`)

`53105ab` renomeou `TransporteRanking.meuRanking()` para `abrirRanking()` e
alargou o retorno para `AberturaRanking` (cabeçalho **mais** tabela). A quebra é
deliberada — o comentário no contrato explica que um método novo com
implementação padrão deixaria os fakes antigos "funcionando" enquanto jogavam a
tabela fora em silêncio.

A folha adaptou os fakes que conhecia. O desta suíte nasceu na composição
anterior e ela não podia conhecê-lo. Adaptado igual aos vizinhos.

### 4.2 O total do fecho (`avatar_publico_canonico_test.dart`)

`45 → 48`. Medido por **conjunto** antes de tocar no número:

| Conjunto | Resultado |
| --- | --- |
| fecho(composto) − fecho(41a767a) | `estado_tabela_ranking.dart`, `ranking_de_producao.dart`, `navegacao_perfil_publico.dart` |
| fecho(41a767a) − fecho(composto) | vazio |

Os três entram **nominalmente**, e o total virou
`40 + doRankingReal.length + daNavegacaoPublica.length`.

### 4.3 H-E09, de "tem aspa" para "tem literal SOLTO"

Esta é a única com risco real de virar afrouxamento, então vale o detalhe. A
prova reprovava qualquer valor de `avatar:` que **contivesse** aspa. O analisador
de resposta que a navegação trouxe tem esta forma:

```dart
avatar: _texto(j['avatar'], '$onde.avatar')
```

Duas aspas, nenhuma delas um avatar: uma é a **chave** do mapa vindo da rede, a
outra é o caminho da mensagem de diagnóstico. Conferido à mão que **ninguém
renderiza esse campo** — `ranking_de_producao.dart` não lê `jogador.avatar`, a
tabela não desenha avatar —, então não há segunda autoridade nascendo: há um
parser.

A regra passou a ser sobre a **forma**: apagam-se as listas de argumentos e
procura-se literal no que sobra.

| Valor | Veredito |
| --- | --- |
| `'X'` | REPROVA |
| `identidade?.avatarRef ?? 'X'` | REPROVA ← a mutação 3 da OS |
| `cond ? 'X' : 'Y'` | REPROVA ← já escapou uma vez |
| `_texto(j['avatar'], '...')` | passa |
| `avatarPublicoDaIdentidade(x)` | passa |

A alternativa preguiçosa — tirar `ranking_transporte.dart` da lista de arquivos
vigiados — é que seria afrouxar: abriria exceção permanente num arquivo de
produção.

---

## 5. Testes, antes e depois

### Antes (cada entrada por si)

| Árvore | Flutter | functions-ranking |
| --- | --- | --- |
| Base `41a767a` | 1093 verdes | 399 |
| Entrada A `79063e07` | — | 403 (402 + 1 pulado)¹ |
| Entrada B `53105ab` | 1031 verdes; `navegacao_perfil_publico_test.dart` **38 verdes** | — |

¹ O pulo é condicional à presença de `functions-social`, que não existia no
diretório de recorte usado para medir A isolada. Na árvore completa ele roda.

### Depois (composição)

```
flutter analyze --no-fatal-infos --no-fatal-warnings   exit 0   103 issues (só info)
flutter test                                            exit 0   1153 verdes
functions-ranking: tsc --noEmit                         exit 0
functions-ranking: npm test                             exit 0   407/407
```

**Nenhum teste antes verde foi perdido.** 1093 (base) + 38 (suíte de navegação da
folha B) = 1131, e 1131 + 22 (suíte nova de composição) = **1153**.

### Diferenças explicadas nominalmente

`analyze`: **101 → 103**. Os dois novos são `avoid_renaming_method_parameters`
(`bool operator ==(Object outro)`) em `lib/ranking/estado_tabela_ranking.dart` e
`lib/ranking/ranking_transporte.dart`. Os dois arquivos são **idênticos** aos de
`53105ab` — os avisos vieram com a folha, não da composição. Zero diagnóstico
novo atribuível a esta OS, e zero perdido.

`functions-ranking`: **403 → 407**, pelos quatro casos de
`test/composicao.test.js` (§6). Alvo da OS: pelo menos 403/403 — atendido.

---

## 6. A suíte de composição

26 casos, em dois lugares. A divisão não é estilo: o overlay que o CI monta para
o Flutter copia só `app/`, então nenhum teste Dart alcança `functions-ranking/`.
Um caso de contrato escrito do lado Dart leria um arquivo que não existe onde ele
roda — passaria por vacuidade.

| Arquivo | Casos |
| --- | --- |
| `app/test/composicao/composicao_navegacao_publica_test.dart` | 22 |
| `functions-ranking/test/composicao.test.js` | 4 |

A matriz de 20 da OS:

| # | Caso | Prova |
| --- | --- | --- |
| 1 | Avatar e Ranking coexistem no fecho | C1 |
| 2 | Contrato contém `torneio` | C2 (node) |
| 3 | Torneio conhecido e inelegível | C3 (node) |
| 4 | Torneio competitivo incoerente recusado | C4 (node) |
| 5 | Tabela usa jogadores públicos sem UID | C5 |
| 6 | Terceiro navega pelo `publicId` | C6, C6b |
| 7 | Proprietário sem callable de terceiro | C7 |
| 8 | `publicId` vazio não navega | C8 |
| 9 | Apelido não vira identificador | C9 |
| 10 | Posição não vira identificador | C10 |
| 11 | Índice não vira identificador | C11 |
| 12 | Avatar não volta ao emoji fixo | C12, C12b |
| 13 | Ranking ausente não vira Bronze/0 | C13 |
| 14 | Barreira temporal permanece | C14 |
| 15 | Três toques simultâneos, uma abertura | C15 |
| 16 | Nenhuma maquete assume autoridade | C16 |
| 17 | Os cinco do Ranking seguem no fecho | C17 |
| 18 | O avatar só acrescenta sua dependência | C18 |
| 19 | Nenhuma suíte das entradas removida | C19 |
| 20 | Nenhuma contagem rígida envelhecida | C20 |

Os casos estruturais trabalham **por conjunto e por nome**, nunca por número
mágico — C20 existe justamente para travar isso, e proíbe total literal **só** no
fecho (um `hasLength(1)` para o assinante único de `authStateChanges` continua
sendo o certo).

---

## 7. Provas negativas

Doze mutações injetadas, cada uma revertida em seguida. Todas alteraram produção
ou portão de verdade, e todas foram pegas por prova **identificada**:

| # | Mutação | Detectada por |
| --- | --- | --- |
| 1 | Remover `torneio` da enumeração | C2, C3 + `elegibilidade` + `schema` — 9 falhas |
| 2 | Torneio passa a contar estatística | C3, C2b + `elegibilidade` + `schema` — 5 falhas |
| 3 | Restaurar `avatarRef ?? '👑'` na Home | C12 + 12 casos de `homologacao_avatar_publico` |
| 4 | Remover `comRanking` da página | `composicao_avatar_ranking` — 4 falhas |
| 5 | Segundo dono do avatar na página | «a autoridade do avatar continua sendo uma só» |
| 6 | Navegar pelo apelido | C9 |
| 7 | Proprietário pela callable de terceiro | C7 (e C9) |
| 8 | Identificador vazio navega | C8 |
| 9 | Reintroduzir `uid` na projeção | C5 |
| 10 | Religar uma superfície de maquete | C16 |
| 11 | Aceitar estado temporal antigo | C14 + R1a, R1b, R2a da suíte da barreira |
| 12 | Remover a suíte de navegação do portão | C19 |

A mutação 5 foi refeita: a primeira versão não compilava, e erro de compilação
não é prova identificada. Reescrita como um segundo dono de fallback que compila
limpo, foi pega pelo caso nominal.

---

## 8. Fecho produtivo

`45 → 48`, sem perda. Os três que entram:

```
lib/ranking/estado_tabela_ranking.dart
lib/casca/ranking_de_producao.dart
lib/casca/navegacao_perfil_publico.dart
```

`main.dart` e as superfícies produtivas seguem sem maquete: Amigos, Loja, Loja
por categoria, Hall e a prévia de Ranking continuam **inalcançáveis** a partir da
raiz (C16).

---

## 9. Risco residual — a identidade do terceiro

**Pendência funcional declarada, não corrigida nesta OS (§6 da OS).**

O Perfil visitado ainda monta **nome e avatar** a partir da identidade da sessão
de quem está olhando. O `PerfilService` recebe a identidade da sessão e a usa
para os dois campos, e não há nesta árvore de onde tirar a identidade pública de
um terceiro — corrigir exige buscá-la e projetá-la, que é trabalho de outra OS.

O que a composição **garante**, e está sob teste:

* o `publicIdVisitado` correto chega ao Perfil (C6: `idsConsultados == [alvoX]`);
* o Ranking consultado é o **do visitado** (C6, e o caso da pendência);
* a **liga** da sessão nunca mascara a do visitado — este é o campo que a
  composição já acerta, e está travado por caso próprio;
* o avatar canônico da sessão continua correto nas superfícies do proprietário
  (C12, C12b);
* nenhuma identidade fictícia foi criada para tapar a lacuna.

Os dois casos que registram a pendência **não afirmam** nome nem avatar do
visitado, e isso é deliberado: `expect(vm.nome, 'Terceiro')` mentiria sobre o
presente, e `expect(vm.nome, 'Ana')` seria pior — carimbaria o defeito como
comportamento esperado e ficaria vermelho no dia em que alguém o consertasse.

---

## 10. Fechamento

* árvore limpa;
* branch local e remota no mesmo SHA;
* nenhuma branch de entrada alterada (reconferido no remoto ao final);
* nenhum PR, merge em branch preexistente ou deploy;
* zero alteração em backend não relacionado — o diff toca `functions-ranking`
  apenas com os quatro arquivos de A e o teste de composição novo;
* zero segredo no diff.
