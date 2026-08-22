# Laudo — OS 39: incorporação, ativação e homologação dos 28 assets do Tema Real VIP

## Veredito

```text
PASS — TEMA REAL VIP ATIVO PARA O ASSINANTE COMPLETO E VIGENTE
```

A dívida que fechou a folha anterior está paga. Os 28 desenhos aprovados entraram
byte a byte, o diretório foi declarado, a chave foi virada, e o assinante VIP
completo e vigente vê a tela de Ajustes inteira em iconografia luxuosa. Todos os
outros estados — público, cortesia, expirado, revogado, desconhecido — recebem o
Tema Padrão **integral**.

## 1. Branch

`integracao/tema-real-vip-assets-aprovados-v1`

## 2. Base e SHA congelado

| item | valor |
| --- | --- |
| base | `claude/tema-real-vip-iconografia-ajustes-v1` @ `929113bed40ceb16ca90242320c9254e0954278d` |
| ramo criado diretamente nesse SHA | sim |
| `origin/main` | `fb9edb5`, intocada |
| PR / merge / deploy / tag / force | nenhum |

## 3. Prova de ancestralidade

```text
git merge-base --is-ancestor 929113b HEAD   → 0 (é ancestral)
git merge-base --is-ancestor dc3a46b HEAD   → 0 (o código da folha anterior também)
```

Árvore limpa antes de qualquer edição; `git ls-remote` conferido, não
`refs/remotes/`.

## 4. SHA-256 do pacote

| item | valor |
| --- | --- |
| arquivo | `tema-real-vip-assets-v1.zip` |
| SHA-256 esperado | `8ef236fd64f9a3bf0c4dcddcd9bf5da3f86a29f788ac0d860658a74bcc99c3b6` |
| SHA-256 medido | **idêntico** |
| tamanho esperado | 4.582.157 bytes |
| tamanho medido | **4.582.157** |

Conteúdo: 28 `.webp` em `app/assets/ajustes/real/`, `MANIFESTO-ASSETS-TEMA-REAL-V1.md`,
`SHA256SUMS.txt`, `PAINEL-28-ASSETS-TEMA-REAL-V1.png`, `QA-LEGIBILIDADE-18PX.png`.
Nenhum arquivo além dos previstos.

## 5. Hashes dos 28 assets

`sha256sum -c SHA256SUMS.txt` → **28 OK, 0 divergências**, tanto no pacote quanto
depois da cópia para a árvore. `cmp` byte a byte entre pacote e árvore: **28/28
idênticos**. O blob do índice do git bate com `git hash-object` do arquivo — o
git os tratou como binário e não normalizou nada.

A tabela completa (nome, chave, desenho, SHA-256, bytes) está em
`docs/ORIGEM-ICONES-TEMA-REAL.md`.

Características medidas nos 28: WebP **lossless** (`VP8L`, assinatura `0x2F`),
**256 × 256**, alfa declarado no cabeçalho e **alfa real** nos pixels — cada um
tem pixel de alfa 0 e pixel de alfa 255.

## 6. Arquivos alterados

```text
 app/assets/ajustes/real/*.webp                 |  28 arquivos novos (binários)
 .github/workflows/build.yml                    |  27 +
 app/lib/tema/conjunto_real_vip.dart            |  63 ±
 app/pubspec.yaml                               |  12 +
 app/test/casca/tema_real_vip_ajustes_test.dart | 614 ++
 docs/ORIGEM-ICONES-TEMA-REAL.md                | 182 ±
 scripts/ci/gates_os_integracao.txt             |  15 ±
 tools/ci/montar_app.sh                         |  28 ±
 35 arquivos, 827 inserções, 114 remoções
```

**A tela e o host NÃO foram tocados.**
`git diff --name-only 929113b..HEAD -- app/lib/screens app/lib/casca` devolve
vazio. Ligar o Tema Real não custou uma linha de UI — era exatamente o que a
arquitetura da folha anterior prometia, e é a prova de que ela funciona.
Também intocados: `app/lib/billing`, `app/lib/elegibilidade`,
`resolucao_tema_ajustes.dart`, `iconografia_ajustes.dart`, `functions*`,
`firebase/`, `servidor/`.

## 7. `pubspec.yaml`

Uma linha, `- assets/ajustes/real/`, no bloco `flutter: assets:`. É a **fonte
única** da declaração: `conjunto_real_vip.dart` deriva os nomes das CHAVES do
contrato, e nenhum workflow, script ou manifesto auxiliar repete a lista dos 28
nomes — `ART-09` percorre cinco arquivos de CI exigindo que não repitam.

Ela não podia existir antes da arte: o Flutter reprova o build quando um
diretório declarado está ausente. Foi por isso que a folha anterior fechou sem
ela, e é por isso que declaração, chave e registro entraram no **mesmo commit**.

## 8. Origem e aprovação

Em `docs/ORIGEM-ICONES-TEMA-REAL.md`, para as 28 linhas:

* **Origem** — arte original produzida sob direção da proprietária, com geração
  de imagem OpenAI, em 22/08/2026; `titulo_ajustes.webp` foi o mestre de
  linguagem visual e os outros 27 nasceram dele;
* **Aprovação** — Sônia Ambrósio, 22/08/2026;
* referência ao manifesto do pacote e ao SHA-256 do ZIP.

O manifesto do pacote traz a linha *"Aprovação individual do painel completo:
pendente"*. Ela descreve o estado em que o pacote foi fechado; a aprovação veio
depois e é a que autoriza esta incorporação. O manifesto **não** foi editado —
evidência de origem não se corrige retroativamente, e o registro diz isso.

**Correção documental exigida pela OS:** a enumeração do laudo anterior dizia
"28" e listava **27** — `secao_jogo.webp` ficava de fora. Corrigido e numerado,
com a razão registrada: é a única das cinco chaves de seção cujo nome não aparece
em rótulo nenhum da tela.

## 9. Prova da ativação

```dart
const bool kConjuntoRealVipRegistrado = true;   // era false
```

E a prova de que isso não é só um `bool` — `ART-12` resolve o tema pelo **caminho
de produção**, sem `registrado:` forçado:

```dart
final r = await resolverTemaDeAjustes(acesso: <VIP ativo vigente>);
expect(r.tema, TemaIconografia.realVip);
expect(r.motivo, MotivoDoTema.concedido);
expect(r.icones.assetsUsados, chavesDeAssetDoTemaReal.toSet());   // os 28
```

A chave é apenas a **primeira** das duas condições. A segunda é
`conjuntoRealDisponivel`, que abre os 28 arquivos antes de a tela nascer. Virar a
chave sem a arte não acende nada: só troca o motivo do fallback de
`conjuntoNaoRegistrado` para `conjuntoIncompleto`.

## 10. Matriz dos estados

| estado | autoridade | tema | assets na tela |
| --- | --- | --- | --- |
| VIP completo vigente (`ativo`) | `vigenteEm` = true | **Real** | 28/28 |
| VIP em carência com benefício (`em_carencia`, `cancelado_vigente`) | `vigenteEm` = true | **Real** | 28/28 |
| Público / sem documento (`nunca_teve`) | — | Padrão | 0 |
| Expirado / revogado / reembolsado / em espera / pausado / pendente | `vigenteEm` = false | Padrão | 0 |
| Passe quinzenal de cortesia | outra coleção | Padrão | 0 |
| Desconhecido, carregando, falha de leitura | indefinido | Padrão | 0 |
| Um dos 28 ausente ou corrompido | qualquer | Padrão **integral** | 0 |

Nenhum estado produz mistura. `AST-14` e `ART-14` medem o conjunto rendido: no
Tema Real, **zero** glifos de chave variável sobram na árvore.

## 11. Separação da cortesia

Estrutural, e é a única prova honesta: **não existe leitor**. `ELG-05` percorre os
seis arquivos do caminho do tema — os três de `lib/tema/`, `acesso_vip.dart`,
`entitlement_repositorio.dart` e o host — e exige que nenhum deles, **fora de
comentário**, mencione `playerCourtesyPass` ou `courtesyPass`. E confere que
`functions-ranking/src/passe.ts` continua sem tocar `playerEntitlements`.

`ELG-06` fecha as outras portas: a decisão de tema não pode citar código, sala,
mesa, amigo, inventário ou item equipado.

Sabotagem `S08` (injetar leitura do passe na decisão) → **vermelha**.

## 12. As seis invariantes

`voltar`, `avancar`, `expandir`, `confirmar`, `sair`, `excluirConta` continuam
com o **mesmo glifo Material** nos dois temas. Elas não aparecem em
`arquivosDoTemaReal`, e `A11Y-32` afirma isso nos dois sentidos: o glifo é o
mesmo na árvore rendida, e as chaves não têm arquivo.

Sabotagem `S11` (dar arquivo luxuoso a `sair`) → **vermelha**.

## 13. Capturas comparativas

Treze capturas geradas por render real do Flutter, em
`C:\bmvtema\capturas` (fora do repositório — evidência de bancada, não artefato
versionado):

| captura | estado | resultado |
| --- | --- | --- |
| `01-nao-vip-PADRAO` | público | 0 assets, todos os glifos |
| `02-vip-completo-REAL` | VIP vigente | 28 assets, nenhum glifo variável |
| `03-cortesia-PADRAO` | cortesia | 0 assets |
| `04-vip-expirado-PADRAO` | expirado | 0 assets |
| `matriz-{320,360,412}dp-{100,150,200}pct` | VIP, 9 geometrias | layout preservado |

Comparando `01` e `02` lado a lado: mesmas linhas, mesmas alturas, mesmos textos,
mesmos toggles, mesma ordem — só a iconografia muda. A pastilha `VIP` e a de
fichas aparecem só no estado VIP porque vêm de `perfil.vip` e `perfil.fichas`, e
não do tema.

**Limitações declaradas, e não contornadas:**

* **sem aparelho físico**: as capturas são render do Flutter em bancada, não
  fotografia de tela;
* **sem build de APK**: `flutter create` exige Modo de Desenvolvedor do Windows,
  que não está ligado nesta máquina — é bloqueio de ambiente conhecido, anterior
  a esta OS, e atinge o primeiro comando do montador. O que a montagem provaria
  foi provado de outro jeito (seção 16);
* nas capturas, os **glifos Material aparecem como quadrados** e o emoji do
  avatar também: `flutter test` não carrega a fonte de ícones nem a de emoji. É
  limitação do arnês, não da tela — e ajuda a leitura, porque separa visualmente
  o que é arte (desenhada) do que é glifo (quadrado).

## 14. Testes

Suíte `app/test/casca/tema_real_vip_ajustes_test.dart`: **38 → 53 provas**.

Quinze novas, no grupo `ART` — o único lugar do repositório que **abre** os
arquivos de imagem e olha dentro. Presença não é prova de conteúdo: um asset pode
estar no manifesto, no contrato e no bundle e ainda ser um retângulo branco.

| prova | o que mede |
| --- | --- |
| `ART-01` | os 28 exatos no diretório, e nada além |
| `ART-02` | SHA-256 de cada um contra a tabela aprovada |
| `ART-03` | cabeçalho WebP lossless 256×256 com alfa declarado |
| `ART-04` | decodificação real, 256×256 |
| `ART-05` | alfa REAL: pixel transparente E pixel opaco em cada um |
| `ART-06` | nenhum é folha em branco |
| `ART-07` | sem fundo branco ou xadrez: anel de borda transparente |
| `ART-08` | legíveis reduzidos a 18 px |
| `ART-09` | pubspec declara uma vez; a lista de arquivos não se repete no CI |
| `ART-10` | a chave está ligada e o conjunto inteiro abre |
| `ART-11` | corromper UM derruba o conjunto inteiro (28 casos) |
| `ART-12` | **ativação** pelo caminho de produção |
| `ART-13` | público e expirado continuam no Padrão pelo mesmo caminho |
| `ART-14` | 9 geometrias: o Tema Real não acrescenta estouro nem corte |
| `ART-15` | toda pasta declarada é empacotada pelos dois montadores |

Contagens:

| medida | base `929113b` | HEAD |
| --- | --- | --- |
| `flutter test` (app inteiro) | 1715 | **1730** |
| `test/casca` | 219 | 234 |
| `temavip` | 38 | **53** |
| `dart analyze lib test` | 40 issues, 0 erros | **40 issues, 0 erros** |

Três armadilhas que custaram uma rodada cada, registradas no próprio arquivo:

* **decodificar imagem exige o relógio REAL.** Sob `FakeAsync` o `await` nunca
  devolve — o teste morre por timeout de dez minutos, sem uma linha de
  diagnóstico. `runAsync` é a única saída, e dentro dele `pump` é proibido;
* **os limiares de pixel vieram da MEDIDA**, com ordens de grandeza de folga, e
  não de números ajustados até passar: branco opaco máximo medido 2,00% (o vidro
  do espelho de `editar_perfil`) contra limiar de 10%; anel de borda máximo
  0,69% contra 2%, quando um fundo assado daria 100%;
* **`precacheImage` dentro de `runAsync`** é o que faz a arte chegar ao quadro
  numa captura — sem ele os ícones saem em branco e a evidência mente.

## 15. Sabotagens

**15 sabotagens independentes, 15 vermelhas**, controles verdes nas duas pontas.

| # | sabotagem | quem acusa |
| --- | --- | --- |
| S01 | remover um WebP | `ART-01` |
| S02 | renomear um WebP | `ART-01` |
| S03 | acrescentar um 29º arquivo | `ART-01` |
| S04 | corromper um WebP | `ART-02`/`ART-04` |
| S05 | trocar um hash na tabela aprovada | `ART-02` |
| S06 | remover o diretório do `pubspec` | `ART-09` |
| S07 | virar a chave para `false` | `ART-10` |
| S08 | liberar Tema Real por cortesia | `ELG-05` |
| S09 | liberar Tema Real para não VIP | `ELG-01/04/07` |
| S10 | fazer UM asset cair para Padrão | `AST-14`/`ART-14` |
| S11 | tornar uma das seis invariantes luxuosa | `AST-10`/`A11Y-32` |
| S12 | remover o registro do gate `temavip` | verificador + `composneg` |
| S13 | remover o produtor do gate (passo do workflow) | verificador + `composneg` |
| S14 | substituir a suíte por teste trivial | contrato (`sha256`) |
| S15 | reduzir o piso de provas na fonte única | contrato (piso no código) |

## 16. Gate `temavip`

| peça | estado |
| --- | --- |
| fonte única `scripts/ci/gates_os_integracao.txt` | `provas 53`, assinatura nova, **17 blocos** `exige` |
| passo produtor em `ci-os-integracao.yml` | inalterado (já existia) |
| `verificar_contrato_suites.sh` | `temavip` ok: arquivo, executor, marcador, assinatura, provas, blocos |

Nenhum gate novo, nenhum manifesto concorrente, nenhum `suites_obrigatorias.txt`
transportado, nenhuma permissão ou gatilho de workflow ampliado.

**O achado de CI desta OS, e ele quase levou a entrega inteira.** Existem três
procedimentos de montagem no repositório, e cada um resolve assets de um jeito.
`release-aab.yml` copia `app/assets/` inteiro por `find` — escapou.
`tools/ci/montar_app.sh` e o passo de APK do `build.yml` têm listas próprias,
escritas à mão, e **nenhuma conhecia `assets/ajustes/real`**. Pior: o montador
ainda criava a pasta declarada **vazia** para o Flutter não reclamar. O build
passaria, o APK sairia sem os 28 ícones, a pré-checagem responderia `false` no
aparelho, e todo assinante VIP veria a tela pública — sem erro em lugar nenhum, e
sem nem meia tela para denunciar, porque o fallback é por conjunto.

Corrigido nos três pontos: o montador copia a pasta e **reprova** quando uma
pasta declarada chega vazia, nomeando-a; o `build.yml` ganhou passo próprio com
contagem exata de 28; e `ART-15` guarda a invariante. De quebra, a guarda
denunciou uma lacuna antiga: `assets/mesa_vip` era declarada, copiada pelo
montador e **nunca** pelo `build.yml`.

Exercitado com os dois blocos extraídos do script real:

```text
montagem normal   → 240 assets empacotados, 28 do Tema Real, guarda aprova
pasta fora da lista → ERRO: pasta declarada no pubspec e VAZIA: assets/ajustes/real
```

## 17. Contrato P

```text
verificar_contrato_suites.sh   7 conferidos, tudo no lugar
teste_portao_os_integracao.sh  38 casos ok, 0 falhas — VERDE
teste_contrato_suites.sh       35 casos ok, 0 falhas — VERDE
composicao/negativas.test.js   21 pass, 0 fail
composicao/loja_functions.js   35 pass, 0 fail
```

## 18. `flutter analyze`

`dart analyze lib test`: **40 issues, 0 erros** — ocorrência a ocorrência igual à
base. Nenhum aviso novo.

## 19. Build APK

**BLOQUEADO POR AMBIENTE, e não contornado.** `tools/ci/montar_app.sh` para no
primeiro comando:

```text
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

É o `flutter create`, antes de qualquer passo desta OS, e é bloqueio conhecido
desta máquina. Não foi inventada prova física. O que a montagem provaria — que os
28 arquivos chegam ao bundle — foi provado pelos dois blocos extraídos do script
(seção 16) e pela guarda `ART-15`.

Registrado do próprio montador, e relevante para esta arte: o Impeller é
desligado no `AndroidManifest` porque há **bug conhecido que renderiza WebP com
alfa em branco no release**. Os 28 são WebP com alfa; a mitigação já estava lá e
continua.

## 20. Diffstat

Seção 6.

## 21–24. Publicação

| item | valor |
| --- | --- |
| SHA do código | `8f7f0b4` — o último commit que toca código, teste, asset ou gate |
| ponta da branch | o commit deste laudo, necessariamente posterior: um documento não pode conter o próprio SHA |
| `local == remoto` | conferido por `git ls-remote`, não por `refs/remotes/` |
| árvore | limpa |
| PR / merge / deploy / tag | nenhum |
| `origin/main` | `fb9edb5`, intocada |

Os quatro commits desta folha, em ordem:

| SHA | assunto | natureza |
| --- | --- | --- |
| `edd9c10` | os 28 assets aprovados entram na árvore | 28 binários, nada mais |
| `3d1ab2a` | a arte é declarada e o Tema Real é ATIVADO | pubspec + chave + registro |
| `a7549fb` | o grupo ART abre os WebP, gate 38 → 52 | suíte + fonte única |
| `8f7f0b4` | os montadores de APK não empacotavam a arte declarada | montador + build.yml + ART-15 |

## Pendências herdadas, não reabertas

1. **Família OS 30 / A11Y de Ajustes** não foi composta — decisão da OS, e a
   composição continua pertencendo à futura raiz integrada.
2. **Estouro de 22 px em 320 dp a 200%** no cabeçalho, entre o apelido flexível e
   a pastilha `VIP`: dívida **anterior**, medida idêntica nos dois temas. Por
   isso `ART-14` é comparativa — um limiar absoluto obrigaria esta missão a
   consertar layout que ela não veio consertar, ou a afrouxar o número até
   passar.
3. **Nome comercial do plano** e **saldo de fichas** seguem como na folha
   anterior: sem catálogo e sem autoridade de economia alcançáveis nesta tela.
