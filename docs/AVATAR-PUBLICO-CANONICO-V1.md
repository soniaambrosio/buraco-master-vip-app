# Canonização do avatar público entre Home e Perfil (V1)

Fecha a divergência visual em que a **Home** desenhava o `avatarRef` real do
perfil público e o **Perfil** desenhava uma coroa fixa, ignorando aquele campo.

Data: 2026-08-17.

---

## 1. Topologia

| Papel | Ref | SHA |
|---|---|---|
| Base obrigatória | `origin/integracao/perfil-publicavel-mesa-online-casca-v2-v1` | `d738f458f1f115ab8f47efea7a80bef26675e2ca` |
| Branch entregue | `claude/avatar-publico-home-perfil-v1` | ver §12 |

`HEAD` inicial: `d738f458f1f115ab8f47efea7a80bef26675e2ca` (a branch nasce
exatamente na base — sem merge, sem rebase, sem `main`).

A branch preferencial **estava livre** no remoto (`git ls-remote origin
'refs/heads/claude/avatar*'` devolveu vazio), então nenhum sufixo foi necessário.
A folha documental `homologacao/perfil-publicavel-canonico-v1-b2 @ 874f07c` foi
**lida como evidência e não incorporada**: não há merge dela nesta branch.

### Gate Zero

| # | Verificação | Resultado |
|---|---|---|
| 1 | `git fetch` da ref da base | ok (o `commit-graph` do git reclama nesta máquina; a ref foi atualizada) |
| 2–3 | **Duas** conferências independentes por `ls-remote` (via `origin` e via URL literal) | `d738f458…` nas duas |
| 4 | Árvore limpa antes de criar a branch | ok |
| 5 | Cadeia `HomeDeProducao → PerfilPage → PerfilScreen` | única — `home_de_producao.dart:223` empurra `PerfilPage`; `perfil_page.dart:161` constrói `PerfilScreen` |
| 6–7 | Origem de `avatarRef` | §2 |
| 8 | Renderizador da Home | `inicio_screen.dart:983` (`_AssetOrText`), via `_Avatar` em `:453` |
| 9 | Coroa fixa do Perfil | `perfil_service.dart:118` — `avatar: '👑'` |
| 10 | Fallback da Home | `'👑'`, no `?? ` de `home_de_producao.dart:97` |
| 11 | Assinaturas do perfil público | uma só, em `SessaoDoJogador` (`uids.listen`) |
| 12 | `authStateChanges` | um assinante — `lib/sessao/sessao_firebase.dart` |
| 13 | Baseline do analyzer | §8 |
| 14 | Baseline das suítes | §9 |
| 15 | `main.dart`, Mesa Online, ranking e autenticação | fora do delta (§7) |

---

## 2. A origem de `avatarRef` — provada, não presumida

```
publicProfiles/{publicId}                        ← Firestore
  └─ functions-social/src/repositorio.ts:204      lerPerfilPublico()
        db().collection(C_PERFIS_PUBLICOS).doc(publicId).get()
        C_PERFIS_PUBLICOS = "publicProfiles"      (chaves.ts:35)
  └─ functions-social/src/index.ts:149            obterMinhaIdentidade()
        perfil: entradaPublica(perfil, publicId, null)
  └─ app/lib/sessao/fonte_identidade_firebase.dart   a callable, do lado do app
  └─ app/lib/sessao/identidade_publica_sessao.dart:259
        avatarRef: perfil['avatarRef'] is String ? … : null
  └─ EstadoIdentidadeSessao  →  EscopoSessao  →  Home e Perfil
```

`avatarRef` **é** autoridade real: sai de `publicProfiles`, atravessa a callable
única e chega às telas pelo estado canônico da sessão. Nenhum `BLOCKED` se
aplica — a correção é inteiramente de cliente, sem servidor, sem Rules e sem
mudança de contrato.

### O que a Home fazia antes

```dart
avatar: identidade?.avatarRef ?? '👑',
```

O `??` cobria apenas o `avatarRef` **nulo**. Uma referência vazia desenhava um
círculo em branco; uma com espaços nas bordas desenhava o espaço junto; e uma
que começasse com `http://` ou `https://` fazia o `_AssetOrText` chamar
`Image.network` para o endereço gravado no perfil.

### O que o Perfil fazia antes

`PerfilService._montar` escrevia `avatar: '👑'` **incondicionalmente**, e
`perfil_screen.dart:527` desenhava esse valor (`_icone(vm.avatar, 44)`). O
`PerfilService` já recebia a `IdentidadePublica` e já a usava para o **nome** —
só o avatar era ignorado. Era uma coroa fixa ao lado de um apelido real.

---

## 3. A resolução canônica

Arquivo novo: **`app/lib/sessao/avatar_publico.dart`** — domínio puro, sem
Flutter, sem Firebase, sem cache e sem I/O.

```dart
const String kAvatarPublicoFallback = '👑';
final RegExp kFormatoAvatarPublico = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$');

String avatarPublicoDaIdentidade(IdentidadePublica? id) => avatarPublicoDe(id?.avatarRef);

String avatarPublicoDe(String? avatarRef) {
  final ref = avatarRef?.trim() ?? '';
  if (ref.isEmpty) return kAvatarPublicoFallback;
  if (!kFormatoAvatarPublico.hasMatch(ref)) return kAvatarPublicoFallback;
  return ref;
}
```

Uma regra observável, e uma só, para os nove casos que a OS §4 enumera:

| Entrada | Saída |
|---|---|
| referência reconhecida | a própria referência |
| ausente (`null`) | fallback |
| vazia / só espaços | fallback |
| desconhecida (fora do formato) | fallback |
| com cara de asset (`assets/…`) | fallback — nunca vira `Image.asset` |
| com cara de rede (`http://…`) | fallback — **nunca vira `Image.network`** |
| tipo não suportado | já morre na hidratação (`doWire` devolve `null`) → fallback |
| carregando | sem identidade resolvida → fallback |
| troca de usuário / atualização do perfil | o estado da sessão muda e as duas telas reconsultam a função no `build` |

**Por que função pura e não widget.** Home e Perfil já têm o seu renderizador —
`_AssetOrText` e `_icone` —, e os dois seguem a mesma convenção (valor iniciado
por `assets/` é imagem; qualquer outro é texto). O que divergia não era o
desenho: era o **valor** que chegava até ele. Um widget comum obrigaria a mexer
no visual aprovado das duas telas para resolver um problema que não é de visual.

**Por que a referência válida não vira caminho de asset.** `kCatalogoAvatares`
está vazio nesta árvore e o backend registra a pendência no próprio contrato
(`catalogoDeAvatarDisponivel: false`). Mapear `coruja_dourada` para
`assets/avatares/coruja_dourada.webp` seria inventar um catálogo — proibido pela
OS §5. No dia em que o catálogo existir, é este arquivo que passa a consultá-lo,
e nenhuma das duas telas muda.

### O formato é uma cópia — deliberada, e travada por teste

`kFormatoAvatarPublico` espelha `kFormatoAvatarRef` de
`app/lib/social/apresentacao.dart`, que é a autoridade do servidor. A cópia
existe porque `test/sessao/auditoria_identidade_test.dart` **proíbe** qualquer
arquivo do cliente de importar `lib/social/` — aquele módulo carrega a fórmula
de geração de `publicId`, que o app não pode conhecer. O preço da cópia é pago
por um caso da matriz que compara os dois padrões caractere a caractere: se um
lado mudar o alfabeto, cai um teste, e não o desenho da tela.

---

## 4. O fallback

`'👑'` — e **não é invenção desta OS**: é o valor que a Home já usava no `??`,
promovido a constante. A coroa foi **rebaixada**, não removida: de "o avatar"
para "o que aparece quando não há avatar". Um `avatarRef` reconhecido sempre
ganha dela.

As coroas ornamentais continuam intocadas, e há um caso da matriz que as
protege de uma varredura textual indiscriminada: a marca do jogo na Home e no
login, o selo de VIP do Saguão, o Rei/Rainha da semana no Hall, a chamada do
convite VIP e o emoji do texto compartilhado.

---

## 5. A ligação das duas telas

| Arquivo | Mudança |
|---|---|
| `casca/home_de_producao.dart` | `avatar: avatarPublicoDaIdentidade(identidade)` no lugar do `??` |
| `services/perfil_service.dart` | `_montar` recebe o avatar; `carregar` passa `avatarPublicoDaIdentidade(identidade)`; o `'👑'` literal saiu |
| `pages/perfil_page.dart` | o `build` **reaplica** a resolução canônica sobre o VM |
| `screens/perfil_screen.dart` | `PerfilVM.comAvatarPublico` — troca só o avatar |

### Por que o `build` reaplica

O `PerfilVM` é montado por uma carga assíncrona, e a recarga só dispara quando o
**`publicId`** muda (`didChangeDependencies`). Um `avatarRef` trocado dentro da
mesma identidade não move aquele gatilho: sem a reaplicação, o Perfil ficaria com
o avatar velho até o jogador sair e entrar de novo. Reaplicando a cada `build`,
o avatar exibido passa a ser **função direta do estado vivo** — sem recarga, sem
esqueleto piscando e sem uma segunda consulta.

Não é assinatura nova: `EscopoSessao.identidadeDe` só lê o `InheritedNotifier`
que a raiz já pendurou, e é a **mesma** dependência que o
`didChangeDependencies` já estabelecia. A contagem de chamadas à callable
confirma: abrir e fechar o Perfil cinco vezes mantém `chamadasEmitidas` no mesmo
número.

`comAvatarPublico` não é um `copyWith` genérico de propósito: os outros campos
têm um produtor só, e abrir a porta para remendá-los na tela é exatamente como
nasce a segunda autoridade que esta correção veio fechar.

---

## 6. Reatividade e identidade

| Situação | Comportamento |
|---|---|
| carregamento inicial | fallback; a Home mostra esqueleto, o Perfil também |
| chegada tardia do perfil público | as duas telas passam ao `avatarRef` no mesmo quadro |
| atualização de `avatarRef` | reflete na Home e no Perfil, **sem recarga do Perfil** |
| rebuild (60 quadros seguidos) | valor estável; zero chamadas novas |
| abrir/reconstruir o Perfil | zero chamadas novas |
| logout | fallback imediato, inclusive com a tela **montada** |
| login de outro jogador | fallback na janela entre a troca e a identidade nova |
| mudança de `publicId` | recarga; nome e avatar do jogador novo |
| invalidação de geração | quem invalida é `SessaoDoJogador` (`_geracao`), intocada |
| válida → inválida | volta ao fallback |

A prova de "não vaza entre contas" usa uma fonte **manual**: a resposta da
identidade de B fica pendurada, e é nessa janela — que dura quadros, não
microtasks — que se exige o fallback. Com resposta imediata, a janela existiria
mas o teste passaria sem tê-la visitado.

---

## 7. Preservações

Delta completo (fora este documento):

```
app/lib/casca/home_de_producao.dart  | 10 +++++++++-
app/lib/pages/perfil_page.dart       | 18 +++++++++++++++++-
app/lib/screens/perfil_screen.dart   | 35 +++++++++++++++++++++++++++++++++++
app/lib/services/perfil_service.dart | 23 +++++++++++++++++++----
app/lib/sessao/avatar_publico.dart          (novo)
app/test/casca/avatar_publico_canonico_test.dart (novo)
```

* `main.dart` — **byte a byte** o da base. Provado de dois jeitos: ele não
  aparece no `git diff --numstat`, e um caso da matriz confere o SHA-256 do
  conteúdo normalizado (`8526fc0a…`, com `\r\n` → `\n`, porque o checkout no
  Windows entrega CRLF e o do CI entrega LF — sem normalizar, o digest provaria
  o sistema operacional).
* Servidor, Functions, Rules, índices, Firebase, billing, Android — **zero**
  arquivos tocados. Zero deploy.
* Mesa Online e Mesa de Treino — fora do delta, e um caso estrutural exige que
  nenhum arquivo delas passe a conhecer o resolvedor.
* Nome público, `publicId`, liga, pontos, colocação, temporada, moldura,
  cosméticos, VIP, conquistas e compartilhamento — inalterados, com caso próprio.
* Navegação `HomeDeProducao → PerfilPage → PerfilScreen` — intacta.
* Literal `Bronze` — ausente do fecho alcançável, e a liga continua **ausente**
  no caminho publicável (o teste mede as duas coisas, porque a homologação
  anterior mostrou que `EstadoRanking.disponivel(liga: 'Bronze')` escapa de uma
  proibição só textual).

---

## 8. Analyzer

`flutter analyze --no-fatal-infos --no-fatal-warnings`, **mesmo binário e mesma
árvore** para base e candidata (Flutter 3.41.4 local; o CI pina 3.44.8).
Comparação por lista normalizada — cada ocorrência reduzida a
`severidade - mensagem - arquivo - regra`, sem `:linha:coluna`, ordenada.

O baseline de `101` da composição **é reproduzível**, e a diferença para o `38`
que uma medição ingênua produz não é de versão: é do conjunto de lints. O
overlay do CI nasce de `flutter create`, que gera um `analysis_options.yaml` com
`include: package:flutter_lints/flutter.yaml`; o pacote `app/` versionado não tem
esse arquivo. Com ele presente, a contagem bate exatamente.

| Ambiente | Base | Candidata | Erros | Listas |
|---|---:|---:|---:|---|
| `app/` como está no repositório | 38 | 38 | 0 | **idênticas** |
| `app/` + `analysis_options.yaml` do overlay (= CI) | **101** | **101** | **0** | **idênticas** |

Zero erro, zero warning novo, **nenhum** diagnóstico novo — nem nos arquivos
tocados, nem nos dois arquivos novos.

---

## 9. Suítes

| Execução | Base | Candidata |
|---|---:|---:|
| Suíte nova (`avatar_publico_canonico_test.dart`) | — | **37** ✅ |
| Suíte padrão (glob `**_test.dart`) | 888 | **925** ✅ |
| Sete suítes fora do glob | 549 | **549** ✅ |
| Seleção sensível (9 suítes) | 212 | **212** ✅ |
| **Total único** | **1.437** | **1.474** |

925 = 888 + os 37 casos novos. Nenhum caso anterior foi removido, pulado,
comentado ou afrouxado; nenhuma espera foi aumentada para converter falha em
verde. A seleção sensível é reexecução e não entra no total.

Seeds: as suítes de torneios e coleções exigem `test/torneios/data` e
`test/colecoes/data`, que o CI monta copiando de `app/data`. As cópias foram
feitas para rodar e **removidas antes do commit** — não estão versionadas.

---

## 10. Matriz

37 casos. Os 24 mínimos da OS estão cobertos; M13b e M14b nasceram de uma prova
por defeito injetado (§11).

| # | Caso |
|---|---|
| M01 | `avatarRef` válido aparece na Home |
| M02 | o mesmo `avatarRef` aparece no Perfil |
| M03 | Home e Perfil produzem a mesma representação (8 entradas: válida, nula, vazia, espaços, com espaços nas bordas, URL, caminho de asset, maiúsculas) |
| M04 / M04b | ausência de identidade e de avatar dão o mesmo fallback, nos dois lugares |
| M05 | referência vazia e só-espaços caem no fallback |
| M06 | espaços nas bordas não produzem avatar inconsistente |
| M07 / M07b / M07c | referência desconhecida (11 formas), tipo não suportado e "não derruba a tela" — incluindo a prova de que **nenhuma `NetworkImage`** é criada |
| M08 | asset ausente não derruba a tela (nas duas metades: o resolvedor recusa, e o renderizador segura) |
| M09 / M10 | atualização do avatar reflete na Home e no Perfil |
| M11 | rebuild (60 quadros em cada tela) não volta para a coroa fixa |
| M12 | abrir e fechar o Perfil 5× não cria assinatura nem chamada |
| M13 / M13b | logout remove o avatar anterior — inclusive com o Perfil **montado** |
| M14 / M14b | login de outro jogador não exibe o avatar antigo — inclusive com o Perfil **montado**, na janela de carregamento |
| M15 | mudança de `publicId` invalida o estado anterior (avatar e nome) |
| M16 | Perfil em carregamento não inventa avatar definitivo |
| M17 | nome, ranking, moldura, mascote, vitrine, e-mail, moedas e liga inalterados |
| M18 | `authStateChanges` continua com um assinante só |
| M19 | `main.dart` byte a byte o da base (SHA-256 normalizado) |
| M20 | nenhuma consulta, callable, `StreamBuilder` ou `.listen(` novo no Perfil |
| M21 / M21b | nenhum `Bronze` no fecho alcançável **e** nenhuma liga afirmada pelo produtor |
| M22 | Mesa Online e Treino não conhecem o resolvedor |
| M23 | o convite compartilhado continua funcional e sem o avatar |
| M24 | as seis coroas ornamentais continuam onde estavam |
| — | o formato do cliente espelha o do domínio social, caractere a caractere |
| — | a autoridade do avatar é uma: ninguém lê `avatarRef` fora do resolvedor |
| — | o fallback é literal em um lugar só do fecho alcançável |
| — | o fecho cresceu só pelo componente previsto |
| — | `ranking_screen.dart` continua inalcançável; o caminho online não ganhou o motor local |
| — | o resolvedor não conhece Flutter, Firebase nem armazenamento |

A varredura do "fallback em um lugar só" **desconta os factories `.mock()`**:
`InicioVM.mock()` e `PerfilVM.mock()` continuam escrevendo `avatar: '👑'`, e
devem continuar — são maquete declarada, e `auditoria_casca_test.dart` já prova
que nenhuma rota nascida em `main()` as constrói. Sem esse desconto, provar algo
sobre produção exigiria mexer no protótipo.

---

## 11. Provas por defeito injetado

Cada defeito foi aplicado sozinho, medido, e revertido. As contagens abaixo são
de execuções **isoladas** (uma invocação de `flutter test` por defeito).

| # | Defeito | Casos que caem | n |
|---|---|---|---:|
| D1 | volta a coroa fixa no Perfil (serviço + página) | M02, M03, M10, M11, M12, M13b, M14b, M15, "fallback literal em um lugar só" | 9 |
| D2 | Perfil ignora a atualização de `avatarRef` (sem reaplicar no `build`) | M10, M13b, M14b | 3 |
| D3 | fallback diferente no Perfil (`?? '🙂'`) | M03, M04b, M07c, M10, M13, M13b, M14b, M16, "autoridade do avatar é UMA" | 9 |
| D4 | cache de avatar sem vínculo com a identidade | M13b, M14b | 2 |
| D5 | assinatura direta nova de `publicProfiles` no Perfil | M20 | 1 |
| D6 | referência inválida lança em vez de cair no fallback | M07, M03, M07c, M08, "válida → inválida" | 5 |
| D7 | ranking e moldura alterados por acidente | M17, M21 | 2 |

**D4 foi o defeito que ensinou.** Na primeira medição ele passou pela matriz
inteira: M13 e M14 montavam o Perfil **depois** do evento, e um `State` recém-
criado nasce sem cache por construção. M13b e M14b nasceram daí — a tela
atravessa a troca de sessão sem ser desmontada — e são justamente os dois casos
que D1, D2, D3 e D4 derrubam juntos.

Uma nota de honestidade sobre o método: uma primeira execução encadeou os sete
defeitos num script só, e duas linhas do resultado divergiram da execução
isolada (D1 sem o caso estrutural, D2 com um `Bronze` que não existia na
árvore). Reproduzidos um a um, D1 e D2 deram os números da tabela acima, e a
divergência não se reproduziu. Por isso a tabela é a das execuções isoladas, e
não a do script.

Depois de revertidos: `grep` por resíduo em `lib/` vazio, matriz **37/37 verde**,
`git diff --stat` de volta aos quatro arquivos previstos.

---

## 12. Auditoria estrutural

Fecho transitivo de imports a partir de `lib/main.dart`, recalculado por
ferramenta independente e conferido de novo dentro da suíte:

| | Base | Candidata |
|---|---:|---:|
| Arquivos alcançáveis | **39** | **40** |

A única diferença é `lib/sessao/avatar_publico.dart` — o componente previsto. Ele
não arrasta nada: importa exatamente um arquivo, `identidade_publica_sessao.dart`,
que já estava no fecho.

* `lib/screens/ranking_screen.dart` continua **inalcançável**.
* O caminho online não ganhou importação do motor local.
* Assinaturas de autenticação: **1 → 1**. De perfil público: **1 → 1** (a de
  `SessaoDoJogador`). No Perfil: **0 → 0**.
* `lib/social/` continua **não importado** por nenhum arquivo do cliente.

---

## 13. Riscos residuais

1. **Flutter 3.41.4 local, 3.44.8 no CI.** Todas as comparações são internamente
   consistentes (mesmo binário para base e candidata), mas os números absolutos
   não estão confirmados contra o pin do CI.
2. **`avatarRef` bem formado é desenhado como texto.** Sem catálogo de avatares,
   uma referência reconhecida aparece como a própria string dentro do círculo —
   que é, exatamente, o que a Home já fazia. Não é regressão desta OS; é a
   consequência de o catálogo não existir. Quando ele chegar, o mapeamento entra
   no resolvedor e nenhuma tela muda.
3. **Ninguém grava `avatarRef` hoje.** A callable `atualizarPerfilPublico`
   existe no backend, mas nenhuma tela do cliente a chama (`onTrocarAvatar`
   mostra aviso). Na prática, hoje as duas telas mostram o fallback — o valor
   desta OS é que elas passam a mostrar **a mesma coisa** e a continuar iguais
   quando o campo começar a ser preenchido.
4. **`_carregar()` continua sem guarda de geração.** Duas cargas concorrentes do
   Perfil podem terminar fora de ordem. É anterior a esta OS e não afeta o
   avatar (que é reaplicado no `build`, fora do VM carregado); fica registrado
   porque afeta nome e ranking.
5. **A cópia do formato de avatar** vive travada por teste, não por tipo. Se
   alguém mover `kFormatoAvatarRef` de arquivo, o teste que compara os dois cai
   por não achar o padrão — e a mensagem diz o que fazer.

---

## 14. Veredito

```
PASS — HOME E PERFIL CONSOMEM O MESMO AVATAR PÚBLICO CANÔNICO
```

Zero servidor, zero deploy, `main.dart` intacto.
