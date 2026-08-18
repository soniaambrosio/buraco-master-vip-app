# Homologação independente — Avatar público canônico entre Home e Perfil V1

**Veredito: PASS.**

A folha `claude/avatar-publico-home-perfil-v1` fica qualificada para composição
futura. Esta homologação **não** a transforma em linhagem canônica.

Nenhum arquivo de `app/lib/` foi alterado. O delta desta homologação são dois
arquivos: a matriz independente e este laudo.

---

## 1. Refs, topologia e ambiente

Base e candidata resolvidas por **duas consultas `ls-remote` independentes** — a
primeira pelo remoto configurado do worktree, a segunda pela URL do repositório
diretamente, de fora da árvore. As duas concordaram.

| Papel | Branch | SHA |
|---|---|---|
| Base | `integracao/perfil-publicavel-mesa-online-casca-v2-v1` | `d738f458f1f115ab8f47efea7a80bef26675e2ca` |
| Candidata | `claude/avatar-publico-home-perfil-v1` | `295f5569239780e292a62249bf0d58af77bcc485` |
| Homologação | `homologacao/avatar-publico-home-perfil-v1` | nasceu **exatamente** de `295f5569` |

`git rev-list base..candidata` devolve **4 commits**, `--merges` devolve **vazio**,
e a base é ancestral da candidata. A cadeia é a declarada, na ordem declarada:

| # | SHA | Pai | Assunto |
|---|---|---|---|
| 1 | `92344edf7b6a512b07220f5ebcbd06f41a333faf` | `d738f45` | resolução canônica do avatar, e a Home ligada a ela |
| 2 | `847499797efde50cae11db04d73e3c34b92ead8d` | `92344ed` | o Perfil consome a mesma autoridade que a Home |
| 3 | `1d788a85b3d9143f405b486d13016e31ebffdc83` | `8474997` | matriz de 37 casos e auditoria estrutural |
| 4 | `295f5569239780e292a62249bf0d58af77bcc485` | `1d788a8` | laudo da entrega |

Linhagens proibidas, verificadas por `merge-base --is-ancestor`:

| Ref | Contida na candidata? |
|---|---|
| `874f07c` (rehomologação b2) | **NÃO** ✅ |
| `6e428e8575e2df4a504148a948305838cf3ff2d4` (composição) | **NÃO** ✅ |
| `e1923f1` (Ranking Real V2) | **NÃO** ✅ |
| `4d24dbd` (homologação do Perfil publicável) | contida — **e é ancestral da BASE**, não introduzida pela folha |

Nada foi incorporado nesta homologação.

**Ambiente:** Flutter 3.41.4 · Dart 3.11.1 · Windows 11 (10.0.26200.9168) ·
worktree exclusivo, árvore limpa na abertura do Gate Zero.

> Nota de ambiente: o CI pina Flutter 3.44.8. As medições abaixo usam o **mesmo
> binário local** para base, candidata e homologação, que é o que a comparação
> exige. O `fetch` emitiu `failed to write commit-graph` — é contenção de outra
> sessão sobre o mesmo repositório, e não afeta as refs, que foram reconferidas
> por `rev-parse` depois.

---

## 2. Inventário

`git diff --name-status base candidata` devolve **exatamente** os sete arquivos
declarados, e nada além:

| Estado | Arquivo | +/− |
|---|---|---:|
| A | `app/lib/sessao/avatar_publico.dart` | +126 |
| A | `app/test/casca/avatar_publico_canonico_test.dart` | +1148 |
| A | `docs/AVATAR-PUBLICO-CANONICO-V1.md` | +414 |
| M | `app/lib/casca/home_de_producao.dart` | +9 −1 |
| M | `app/lib/pages/perfil_page.dart` | +17 −1 |
| M | `app/lib/screens/perfil_screen.dart` | +35 |
| M | `app/lib/services/perfil_service.dart` | +19 −4 |

Zero `main.dart`, zero servidor, zero Functions, zero Rules, zero configuração
Firebase, zero dependências, zero assets, zero Mesa Online, zero Ranking.

---

## 3. Proveniência, recalculada

Recalculada por leitura do código, sem copiar o laudo da entrega.

```
publicProfiles/{publicId}                        (Firestore, lado servidor)
  └─ social:obterMinhaIdentidade                 (callable; UID vem do contexto
     │                                            autenticado — o cliente não
     │                                            pode pedir a identidade de
     │                                            outra pessoa)
     └─ FonteDeIdentidadeFirebase                fonte_identidade_firebase.dart:45
        └─ IdentidadePublica.doWire              identidade_publica_sessao.dart:243
           │                                     avatarRef só sobrevive se for
           │                                     String; qualquer outro tipo → null
           └─ EstadoIdentidadeSessao             fotografia imutável da sessão
              └─ SessaoDoJogador                 dono único; geração + dedup
                 └─ EscopoSessao                 InheritedNotifier na raiz
                    ├─ HomeDeProducao            avatarPublicoDaIdentidade(identidade)
                    └─ PerfilPage                avatarPublicoDaIdentidade(identidade)
```

`lerPerfilPublico` **não existe no cliente** — a leitura de `publicProfiles` é
inteiramente do lado do servidor, dentro de `obterMinhaIdentidade`. O cliente não
tem porta para `publicProfiles`.

Os sete pontos da §5 da OS, conferidos com comentários descontados (contar no
texto cru mente aqui: os arquivos novos **citam** `Image.network`, `FirebaseAuth`
e `publicProfiles` nos comentários porque documentam o defeito que fecharam):

| Exigência | Base | Candidata |
|---|---:|---:|
| `avatarRef` vem da identidade pública canônica | — | ✅ |
| `authStateChanges` em `lib/` | 1 | **1** |
| `.obterMinhaIdentidade()` chamado | 1 | **1** |
| `publicProfiles` no código do cliente | 0 | **0** |
| leitura de perfil público dentro do Perfil | 0 | **0** |
| `FirebaseAuth` / `currentUser` / `displayName` no Perfil | 0 | **0** |
| `Image.network` em `lib/` | 3 | **3** |

O Perfil não cria assinatura própria: `EscopoSessao.identidadeDe` chama
`dependOnInheritedWidgetOfExactType`, que é a **mesma** dependência que o
`didChangeDependencies` já estabelece. Ler no `build` não acrescenta assinante —
acrescenta reatividade.

O resolvedor é puro: seu único `import` é `identidade_publica_sessao.dart`, e ele
não menciona `package:flutter/`, `package:firebase`, `dart:io`, `dart:ui`,
`shared_preferences`, `BuildContext` nem `Widget`.

---

## 4. Regra canônica

`kFormatoAvatarPublico` = `^[a-z0-9][a-z0-9_-]{2,63}$`.

A autoridade correspondente é `kFormatoAvatarRef` em `lib/social/apresentacao.dart:142`,
e o padrão é **idêntico caractere a caractere**. A comparação é feita de duas
maneiras, porque cada uma sozinha é furável: o `pattern` das duas `RegExp`, e o
**comportamento** sobre um corpus de 18 entradas — é a segunda que pega uma
divergência escrita de forma equivalente mas não idêntica (`{2,63}` virando
`{2,}`, âncora trocada, ordem de classe).

A cópia do padrão é deliberada e está justificada no código: `auditoria_identidade_test.dart`
proíbe o cliente de importar `lib/social/`, porque aquele módulo carrega a
fórmula de geração de `publicId` — que é exatamente o que o app não pode
conhecer. O fecho de imports confirma: `lib/social/apresentacao.dart` **não está**
no fecho de produção de Home+Perfil.

Todos os itens da §6 verificados: referência válida prevalece; `null`, vazio e
só-espaços caem no fallback; bordas são aparadas e o miolo não; URL (9 formas),
caminho de asset (9 formas) e valor fora do alfabeto (14 formas) caem; tipo não
textual morre na hidratação; o fallback é `👑` — afirmado por **code point**
`U+1F451`, um único rune, e não por literal copiado do produto; e Home e Perfil
aplicam a mesma função, verificado em 8 estados com as duas telas vivas na mesma
árvore.

---

## 5. Segurança do renderizador

Os dois renderizadores seguem convenções conhecidas:

* `_AssetOrText` (`inicio_screen.dart`) — `assets/` → `Image.asset`,
  `http://`/`https://` → **`Image.network`**, qualquer outro → `Text`;
* `_icone` (`perfil_screen.dart:1416`) — `assets/` → `Image.asset`, outro → `Text`.

Um `avatarRef` adulterado com `https://` faria a Home abrir requisição para o
endereço gravado. A recusa **tem** de acontecer antes do renderizador, e acontece:
`:`, `/`, `.` e espaço estão fora do alfabeto, então os três casos caem sozinhos —
sem lista de coisas ruins para alguém manter.

Provado por widget, e não só por domínio: em cada caso de URL a árvore montada é
varrida por `Image` cujo `ImageProvider` seja `NetworkImage`, e o conjunto é
**vazio**. Para asset, o conjunto de `AssetImage.assetName` pedidos **não contém**
o caminho gravado.

Os sete pontos da §7 verificados. Dois merecem registro:

* **string vazia não produz círculo visualmente vazio** — a Home *tem* um
  `Text("")` legítimo, que é o e-mail da conta, suprimido de propósito por §5 da
  casca. Exigir "nenhum texto vazio na tela" reprovaria essa decisão. O caso
  afirma o que importa: o vazio não é o avatar;
* **o fallback não substitui uma referência reconhecida** — nenhuma referência
  válida pode ser igual ao fallback, porque emoji não passa no alfabeto. O caso
  afirma as duas metades.

A coroa **ornamental** da Home (marca do aplicativo) continua desenhada, como a
§7 da OS exige. Ela é separada do fallback por prova **diferencial**: monta-se com
`avatarRef` e sem, e a diferença de coroas na tela é exatamente **1**. Contar
coroas numa única montagem não distinguiria as duas.

**Risco conhecido, não regressão:** uma referência válida continua desenhada como
**texto** (`Text('tuca_azul')`), porque `kCatalogoAvatares` está vazio nesta
árvore e o backend registra `catalogoDeAvatarDisponivel: false`. A OS §7 dispensa
o catálogo. Ver §9.

---

## 6. Matriz independente

`app/test/casca/homologacao_avatar_publico_test.dart` — **42 casos**, acima dos 20
mínimos. `avatar_publico_canonico_test.dart` **não foi tocado**.

| Grupo | Casos | Cobertura |
|---|---:|---|
| H-A domínio puro | 11 | fallback por code point; 7 formas de ausência; bordas vs miolo; 9 URLs; 9 caminhos; 14 recusas + fronteiras 3 e 64; alfabeto vs autoridade (padrão **e** corpus); 5 tipos não textuais; precedência da referência; pureza em 1000 chamadas nas duas ordens; auditoria de dependências do resolvedor |
| H-B Home | 5 | referência desenhada; URL sem `NetworkImage`; asset não pedido; vazio não vira círculo branco; coroa do avatar isolada da ornamental por prova diferencial |
| H-C Perfil | 6 | mesma referência desenhada; URL sem requisição; não fica preso ao placeholder; sem identidade usa fallback e **não emite chamada**; serviço sem constante; Perfil sem Firebase Auth |
| H-D identidade em movimento | 11 | chegada tardia; `avatarRef` novo com o mesmo `publicId`; 8 estados com as duas telas juntas; logout com tela montada (1 quadro + 20); janela A→B amostrada em 30 quadros; resposta atrasada de A **fora de ordem**; válida↔inválida nos dois sentidos; 60 reconstruções; 6 aberturas do Perfil; falha sem retry por rebuild; troca de avatar sem esqueleto em 40 quadros |
| H-E auditoria estrutural | 9 | `main.dart` por digest; `authStateChanges` = 1; `obterMinhaIdentidade` = 1; sem Firestore/`publicProfiles` no fecho; fecho cresceu só pelo resolvedor; coroa com um dono **na função de avatar**; sem catálogo nem concatenação; sem literal de avatar em produção; sem credencial nem dado pessoal |

**A janela de troca de conta dura quadros controlados pelo teste.** A fonte de
identidade guarda cada chamada num `Completer` e só responde quando o teste manda,
e o índice da chamada é estável — é o que permite encenar a resposta de A
chegando **depois** da de B, ordem que um `Future.value` nunca produz.

---

## 7. Provas por defeito injetado

Doze mutações, aplicadas ao `lib/` de uma **cópia descartável** (o overlay do
scratchpad), com as duas matrizes rodando a cada vez. A reversão é por
**restauração do arquivo inteiro** a partir da candidata — não por um `sed`
inverso, que é como uma reversão silenciosamente incompleta contamina a rodada
seguinte — e a árvore é conferida por `diff` depois de cada uma. **Baseline: 77
casos, zero falhas.** Árvore limpa no fim.

| # | Mutação | Casos caídos | Detectada pela matriz independente |
|---|---|---:|---|
| 01 | coroa fixa de volta no `PerfilService` | 3 | H-E06 |
| 02 | `avatarRef ?? '👑'` de volta na Home | 11 | H-B02, H-B03, H-B04, H-D03, H-D07, H-E06 |
| 03 | aceitar URLs | 10 | H-A04, H-A10, H-B02, H-C02, H-D03, H-D07 |
| 04 | aceitar caminhos de asset | 4 | H-A05, H-B03 |
| 05 | remover o `trim` | 3 | H-A03, H-A10 |
| 06 | manter o avatar antigo quando o `publicId` não muda | 4 | H-D02 |
| 07 | permitir vazamento do avatar da conta anterior | 4 | H-D05 |
| 08 | abrir consulta nova ao reconstruir o Perfil | 2 | **H-D11** |
| 09 | segunda assinatura do perfil público no Perfil | 25 | H-C01…H-C03, H-D01…H-D10 |
| 10 | divergir o padrão aceito do autoritativo | 4 | H-A06, H-A07 |
| 11 | fallback diferente entre Home e Perfil | 3 | **H-E09** |
| 12 | remover a reaplicação do avatar no `build` | 9 | H-C03, H-D02, H-D04, H-D05, H-D07, H-E06 |

**Todas as doze derrubam ao menos um caso identificável**, e todas derrubam ao
menos um caso da matriz independente.

Duas exigiram fortalecer o instrumento, e a razão é a mesma nas duas — vale
registrar porque diz algo sobre o desenho da folha:

* **08** e **11** são mascaradas em tempo de execução pela reaplicação no `build`.
  O `PerfilPage` recalcula o avatar a cada quadro, então um fallback errado
  escrito no `PerfilService` (11) é sobrescrito antes de chegar à tela, e uma
  recarga a mais (08) termina dentro do dreno e deixa a tela recomposta. Isso é
  defesa em profundidade e é bom — mas significa que um segundo dono de fallback
  pode nascer no serviço sem que nenhuma tela reclame, e no dia em que a
  reaplicação sair, o valor errado aparece.
* Na primeira rodada, **08** caía só em `M10` (matriz da entrega) e **11** só nos
  dois casos estruturais dela. Nasceram então **H-D11** (a transição amostrada em
  40 quadros: um único em `carregando` reprova, porque o que denuncia a recarga é
  o caminho e não o destino) e **H-E09** (invariante estrutural: nenhum produtor
  de produção escreve avatar literal). A primeira versão de H-E09 usava
  `avatar:\s*'` e a mutação **passou**, escondendo o literal dentro de um
  ternário; a leitura foi reescrita para contar profundidade de parênteses. As
  duas foram reconferidas contra as mutações e agora caem.

---

## 8. Preservações estruturais (§11)

| Invariante | Base | Candidata | |
|---|---:|---:|---|
| `main.dart` byte a byte (SHA-256, `\n` normalizado) | `8526fc0a…a0ab` | `8526fc0a…a0ab` | ✅ |
| `authStateChanges` | 1 | 1 | ✅ |
| Leitor do perfil público (`.obterMinhaIdentidade()`) | 1 | 1 | ✅ |
| Leitura de perfil público dentro do Perfil | 0 | 0 | ✅ |
| `Image.network` em `lib/` | 3 | 3 | ✅ |
| Fecho de imports Home+Perfil (arquivos `lib/`) | 30 | **31** | ✅ |
| Fecho de imports Home+Perfil (externos) | 10 | 10 | ✅ |

O fecho cresceu de 30 para 31, e o arquivo novo é **exatamente**
`lib/sessao/avatar_publico.dart`. Os 10 externos são idênticos: `dart:async`,
`dart:convert`, `dart:math`, `audioplayers`, `flutter/foundation`,
`flutter/material`, `flutter/services`, `flutter/widgets`, `shared_preferences`,
`web_socket_channel` — **nenhum** `cloud_firestore`, **nenhum** `firebase_auth`.

Nenhuma URL, caminho de asset ou catálogo inventado. Nenhuma alteração em Mesa
Online, Ranking, autenticação ou servidor — o inventário de sete arquivos já o
prova. Nenhuma credencial, segredo ou dado pessoal no delta, verificado por
varredura dos cinco arquivos de produção tocados.

---

## 9. Bateria

Base, candidata e homologação medidas no **mesmo toolchain** e no **mesmo
overlay**, reproduzido de `.github/workflows/ci-os-integracao.yml`: scaffold por
`flutter create`, `pubspec.yaml` + `pubspec.lock` do repositório, `flutter pub
get`, `cp -R app/lib/.`, assets menos os `.dart` soltos, `cp -R app/test/.` mais
as seeds de `app/data`, `rm test/widget_test.dart`. `lib/` e `test/` são zerados
antes de cada sincronização — sem isso, um arquivo que só existe na candidata
sobreviveria à troca para a base, e a medição da base mediria as duas.

### Analyzer

`flutter analyze --no-fatal-infos --no-fatal-warnings`. Comparação por lista
normalizada (`severidade - mensagem - arquivo - regra`, **sem** `:linha:coluna`,
ordenada) — sem normalizar, editar um arquivo desloca o diagnóstico e inventa um
"novo" e um "perdido".

| Ambiente | Base | Candidata | Homologação | Erros | Listas |
|---|---:|---:|---:|---:|---|
| `app/` como está no repositório | 38 | 38 | 38 | 0 | idênticas |
| Overlay equivalente ao CI | 101 | 101 | **101** | 0 | **idênticas** |

Os 101 são 91 `info` + 10 `warning`, **zero** erro. A diferença para os 38 não é
de versão: o overlay nasce de `flutter create`, que gera um `analysis_options.yaml`
com `include: package:flutter_lints/flutter.yaml`, e o pacote `app/` versionado não
tem esse arquivo. As baselines de 38 e 101 da OS **reproduzem exatamente**.

**Zero diagnóstico novo** — a matriz independente não acrescenta nenhum, nos dois
ambientes.

### Suítes

| Execução | Base | Candidata | Homologação |
|---|---:|---:|---:|
| Suíte padrão (glob `**_test.dart`) | 888 ✅ | **925** ✅ | **967** ✅ |
| Sete suítes fora do glob | 549 ✅ | **549** ✅ | **549** ✅ |
| Matriz da entrega (37) | — | 37 ✅ | 37 ✅ |
| Matriz independente (42) | — | — | 42 ✅ |
| Seleção sensível (`test/casca` + `test/sessao` + `test/ranking`, 15 suítes) | — | 344 ✅ | **386** ✅ |

925 − 888 = 37, exatamente a matriz da entrega. 967 − 925 = 42, exatamente a
matriz independente. 386 − 344 = 42, a mesma coisa pela seleção sensível.
**Nenhum teste existente foi removido, alterado, pulado, comentado ou
neutralizado; nenhuma espera foi aumentada para converter falha em verde.**

Referências da OS confirmadas: analyzer 38 e 101 ✅, suíte padrão 925 ✅, fora do
glob 549 ✅, matriz do avatar 37 ✅.

> **Divergência de referência, sem consequência para o veredito.** A OS cita
> "seleção sensível: 212" sem nomear as 9 suítes. `test/casca` sozinho (9 arquivos
> `_test.dart`) dá **202** na candidata, não 212, e nenhuma combinação óbvia
> fecha em 212. Como a OS não define o conjunto, a seleção sensível aqui é
> declarada explicitamente (`test/casca` + `test/sessao` + `test/ranking`, 15
> suítes) e medida nos dois lados. A seleção é reexecução e não entra em nenhum
> total.

> **Nota de ambiente.** Rodar `flutter test` direto em `app/` dá 581 passes e 4
> falhas — `colecoes/evidencias_visuais`, `colecoes/kit_pioneiros`,
> `torneios/motor_torneios` e `torneios/reward_grants`, todas por
> `test/colecoes/data/*.json` e `test/torneios/data/*.json` ausentes. São seeds
> que o CI monta copiando de `app/data`, e as quatro suítes morrem na carga, o
> que também explica a diferença para os 925 do overlay. É ambiente, não
> regressão: acontece igual na base. As cópias **não** foram versionadas.

---

## 10. Riscos residuais

1. **Referência válida é desenhada como texto.** `avatarPublicoDe('tuca_azul')`
   devolve `'tuca_azul'`, e os dois renderizadores desenham `Text('tuca_azul')` —
   o slug em vez de um avatar. É o **risco conhecido** que a §7 da OS dispensa:
   `kCatalogoAvatares` está vazio e o backend declara
   `catalogoDeAvatarDisponivel: false`. Não é regressão, e o lugar de consultar o
   catálogo no dia em que ele existir já está identificado no resolvedor — nenhuma
   das duas telas muda.
2. **Ninguém grava `avatarRef`.** O campo existe no contrato e no domínio social,
   mas não há caminho no cliente que o escreva: `onTrocarAvatar` mostra "chega nas
   próximas fatias". Na prática, hoje **todo** jogador vê o fallback. A correção
   está certa e é verificável; ela ainda não tem efeito visível em produção.
3. **O padrão do alfabeto é uma cópia.** `kFormatoAvatarPublico` duplica
   `kFormatoAvatarRef` de propósito, porque o cliente não pode importar
   `lib/social/`. A divergência é barrada por teste (H-A07 e o caso equivalente da
   entrega), não pelo compilador. Se alguém mudar a autoridade e rodar só as
   suítes do servidor, a divergência entra e só cai aqui.
4. **08 e 11 são invisíveis em tempo de execução.** A reaplicação no `build`
   mascara um fallback divergente no `PerfilService` e uma recarga a mais. As duas
   invariantes ficam sustentadas por casos **estruturais** (H-E09, H-D11) — que são
   varredura de código-fonte, e portanto quebráveis por uma reescrita que preserve
   o defeito e mude a forma. Foi exatamente o que aconteceu na primeira versão de
   H-E09.
5. **Folha isolada.** A candidata não contém Ranking Real V2, a composição
   `6e428e8`, a blindagem do CI nem o encerramento excepcional da UI. A
   composição é OS própria, e o fecho de Home+Perfil toca
   `casca/mesa_online/`, `services/online_service.dart` e `ranking/estado_ranking.dart`
   — há superfície compartilhada com aquelas linhagens, mesmo com zero interseção
   de arquivos no delta.

---

## 11. Veredito, item por item

| §15 exige | |
|---|---|
| refs e topologia exatas | ✅ |
| inventário é o declarado | ✅ |
| proveniência pública comprovada | ✅ |
| Home e Perfil produzem o mesmo avatar em todos os estados | ✅ |
| nenhuma URL ou asset arbitrário | ✅ |
| troca de conta não vaza avatar | ✅ |
| rebuild não abre consulta adicional | ✅ |
| autoridades permanecem únicas | ✅ |
| todas as mutações detectadas | ✅ (12/12) |
| nenhuma regressão ou diagnóstico novo | ✅ |
| nenhum código de produção alterado | ✅ |

**PASS.**
