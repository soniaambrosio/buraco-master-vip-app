# Kit Pioneiros 2026 — relatório técnico

Entrega da parte lógica, Firebase e contratos de integração, conforme a ordem de
serviço de 06/08/2026. A camada visual definitiva **não** foi feita e continua
reservada à etapa Codex.

- **Branch:** `claude/kit-pioneiros-2026-1b56ed` (não mesclada em `main`)
- **Base:** `0cea0d6` (= `origin/consolidacao/apk-geral-bmv`, o merge-base)
- **Toolchain:** Flutter 3.41.4 local · CI pinado em 3.44.8

> **Segunda rodada (ajustes solicitados).** Este relatório já incorpora os seis
> ajustes pedidos após a primeira entrega. Onde algo mudou de conclusão, o texto
> foi corrigido em vez de acumulado. Um resumo do que mudou:
>
> | Ajuste | Onde |
> | --- | --- |
> | 1. `cloud_firestore`/`cloud_functions` no pubspec + adaptador real | §2.1, §5.1 |
> | 2. AAB pelo CI, com merge-base e artefato | §7 |
> | 3. Otimização PNG sem perda + equivalência comprovada | §7.1 |
> | 4. Resolvedor de artes não preso a caminho local | §5.2 |
> | 5. Confirmações de segurança | [documento próprio](KIT-PIONEIROS-2026-SEGURANCA.md) |
> | 6. Runbook de implantação | [documento próprio](KIT-PIONEIROS-2026-RUNBOOK.md) |

---

## 1. Conflitos com a arquitetura atual

A ordem de serviço pede para adaptar ao catálogo, inventário e modelos
existentes, e para declarar explicitamente qualquer conflito **antes** de criar
estrutura paralela. São quatro, e o desenho da entrega saiu deles.

### 1.1 Não existia catálogo nem inventário para reutilizar

Varri `app/lib` inteiro. O que existe hoje:

| Onde | O que é | Serve como catálogo/inventário? |
| --- | --- | --- |
| `lib/torneios/` | Domínio de recompensas de torneio (assets, políticas, concessão) | Não — é fechado em torno de torneio/edição |
| `services/perfil_service.dart` | `_catalogoTravado`, `_vitrinePadrao`, `_presentesDemo` | Não — listas `const` de demonstração, sem persistência |
| `screens/loja_screen.dart`, `loja_categoria_screen.dart` | Telas de loja | Não — não há modelo de item por trás |

Não há modelo de item, repositório, nem posse persistida em lugar nenhum.

**Decisão:** `app/lib/colecoes/` nasce como o **primeiro** catálogo e inventário
genéricos do aplicativo, com `collectionId` na raiz. O Kit Pioneiros 2026 é o
primeiro cliente dele, não um caso especial. É exatamente o oposto do que a ordem
proíbe: não criei uma segunda estrutura de mascotes, selos e efeitos — criei a
primeira, e o kit entra nela.

### 1.2 O domínio de torneios está congelado e é um contrato fechado

Duas razões para não estender `lib/torneios/`:

1. Ele está congelado em `0cea0d6` por decisão da Sônia, até o visual dos
   torneios ser aprovado. **Nenhum arquivo de `lib/torneios/`, `app/data/torneios/`
   ou `app/test/torneios/` foi tocado nesta entrega.**
2. `TorneioAssetIds.todos` é um conjunto fechado, validado por igualdade exata
   contra o seed, e a idempotência é `tournamentId|editionId|userId|assetId`. Um
   item comemorativo permanente não tem torneio nem edição — entraria como dado
   inválido dentro de um contrato desenhado para outra coisa.

O que foi reaproveitado é a **forma**, não o código: mesma separação
arte/regra/ato, mesmos seeds JSON versionados, mesma recusa enumerada e
serializável, mesma exigência de sufixo `Z` em datas, mesmo estilo de portão no CI.

### 1.3 O projeto não tem Firestore, regras nem functions

O aplicativo usa apenas `firebase_core` e `firebase_auth`. Não há
`cloud_firestore` nas dependências (ver `.github/workflows/build.yml`), nem
`firestore.rules`, nem pasta `functions/`. Não havia backend a "atualizar".

**Decisão:** `firebase/` foi criado do zero, versionado e **não implantado**.
Publicar exige credenciais do projeto e é decisão da Sônia. Ver
[firebase/README.md](../firebase/README.md) e o
[runbook](KIT-PIONEIROS-2026-RUNBOOK.md).

**Resolvido na 2ª rodada:** `cloud_firestore` e `cloud_functions` agora são
dependências de verdade, e o adaptador real existe. Ver §2.1.

### 1.4 Divergência de identificadores no pacote aprovado

O manifesto usa `collection_id: pioneiros_2026` e ids de item com o radical
`pioneer_2026_`. A ordem de serviço, na seção 5.2, também menciona
`source = pioneers_2026`.

**Decisão:** preservei os ids do manifesto exatamente como vieram (são o
contrato), padronizei `pioneiros_2026` para coleção e campanha, e usei
`source: "campanha"` — que descreve a origem, e não o nome da campanha, que já
vai em `campaignId`. Não existe regra de prefixo entre `itemId` e `collectionId`,
e isso está dito no seed para ninguém tentar aplicar uma depois.

---

## 2. Arquivos

### 2.1 Dependências e integração real (ajuste 1)

O repositório **não tinha pubspec**: o CI rodava `flutter create` + `flutter pub
add`, resolvendo versões do zero a cada build — dois builds do mesmo commit
podiam usar pacotes diferentes, sem registro de qual.

Agora `app/pubspec.yaml` e `app/pubspec.lock` são a fonte da verdade, com **107
pacotes travados**. Entraram como dependência de verdade, e não como linha de
workflow:

| Pacote | Versão travada | Para quê |
| --- | --- | --- |
| `cloud_firestore` | 6.8.0 | Catálogo, campanha, evidência e inventário |
| `cloud_functions` | 6.3.6 | `claimPioneerKit` é `https.onCall` |
| `firebase_app_check` | 0.4.6 | Pronto e **desligado** (§ segurança) |
| `crypto` (dev) | 3.0.7 | Portão de integridade |
| `fake_cloud_firestore` (dev) | 4.2.0 | Testes do adaptador sem emulador |

**Transporte, respondendo à pergunta diretamente:** `claimPioneerKit` é
`https.onCall`. Não há endpoint HTTP público. O cliente Flutter usa
`cloud_functions`, e a chamada vai **sem payload** — a função pega o UID do
contexto autenticado e lê a elegibilidade das fontes confiáveis.

**Adaptador:** `app/lib/colecoes/colecao_firebase.dart` é o único arquivo do
módulo que conhece Firebase. Atrás de `ColecaoRepositorio` (interface pura), o
domínio inteiro continua testável sem emulador.

**Validação:** 21 casos novos em `colecao_firebase_test.dart`, sobre
`fake_cloud_firestore` — leitura de campanha com conversão de `Timestamp`,
flag que só liga com `true` booleano, evidência que não vaza entre jogadores,
inventário que sobrevive a um documento corrompido, equipagem em lote tocando só
`equipped`, e tradução dos códigos de erro.

**O que essa suíte não cobre, e por quê:** não existe fake oficial de
`cloud_functions`. A tradução da resposta é testada isolada; a **chamada real**
está em `firebase/testes/seguranca.test.js`, que roda contra os emuladores e
**não foi executada nesta entrega** — exige emulador de pé e `npm install`. É o
passo 7 do runbook.

### Criados

| Arquivo | Papel |
| --- | --- |
| `app/assets/colecoes/pioneiros_2026/*.png` | As 10 artes, byte a byte iguais ao pacote |
| `app/data/colecoes/pioneiros_2026.manifest.json` | Manifesto técnico (dimensões, alpha, SHA-256) |
| `app/data/colecoes/catalogo.seed.json` | Catálogo: itens, categorias, slots |
| `app/data/colecoes/campanha_pioneiros_2026.seed.json` | Espelho de `campaigns/pioneiros_2026` |
| `app/lib/colecoes/colecao_catalogo.dart` | Quais itens existem e onde equipam |
| `app/lib/colecoes/colecao_campanha.dart` | Quem tem direito e quando |
| `app/lib/colecoes/colecao_inventario.dart` | O que o jogador possui e o que está ativo |
| `app/lib/colecoes/colecao_resgate.dart` | O ato de resgatar; devolve plano de gravação |
| `app/lib/colecoes/colecao_ui_contract.dart` | Contrato único para a camada visual |
| `app/test/colecoes/kit_pioneiros_test.dart` | 81 casos, organizados pelos critérios de aceite |
| `app/lib/colecoes/colecao_arte.dart` | Origem da arte (bundle/remota), resolvedor, cache |
| `app/lib/colecoes/colecao_repositorio.dart` | Interface de acesso a dados, pura |
| `app/lib/colecoes/colecao_firebase.dart` | Adaptador real de Firestore e Functions |
| `app/pubspec.yaml` + `app/pubspec.lock` | Dependências e assets versionados |
| `app/test/colecoes/colecao_arte_test.dart` | 14 casos de origem da arte |
| `app/test/colecoes/colecao_firebase_test.dart` | 21 casos do adaptador |
| `app/test/colecoes/evidencias_visuais_test.dart` | Gerador dos prints (não é tela do produto) |
| `tools/otimizar_pngs.js` | Recompressão sem perda |
| `tools/verificar_equivalencia.js` | Prova de equivalência de pixels |
| `tools/regenerar_manifesto.js` | Manifesto a partir dos arquivos |
| `tools/ci/montar_app*.sh` | Montagem do projeto compilável |
| `firebase/testes/seguranca.test.js` | Regras e concorrência nos emuladores |
| `.github/workflows/tamanho-aab.yml` | AAB e comparação de tamanho |
| `docs/KIT-PIONEIROS-2026-SEGURANCA.md` | Confirmações de segurança |
| `docs/KIT-PIONEIROS-2026-RUNBOOK.md` | Roteiro de implantação |
| `firebase/firestore.rules` | Regras de acesso |
| `firebase/firestore.indexes.json` | 3 índices |
| `firebase/functions/index.js` | `claimPioneerKit` + 2 funções administrativas |
| `firebase/scripts/seed_pioneiros_2026.js` | Publica catálogo e campanha; idempotente |
| `firebase/firebase.json`, `firebase/README.md` | Configuração e roteiro de deploy |

### Alterados

| Arquivo | Mudança |
| --- | --- |
| `.github/workflows/build.yml` | Cópia com contagem exata, portão de SHA-256, portão de testes, declaração no pubspec, medição do custo no APK |
| `.github/workflows/web.yml` | Cópia com contagem exata e declaração no pubspec |

**Nada mais foi tocado.** Nenhuma tela, nenhum widget, nenhuma regra do jogo,
nenhum arquivo de torneios.

---

## 3. Modelo de dados no Firestore

| Documento | Escrita pelo cliente | Observação |
| --- | --- | --- |
| `config/featureFlags` | ❌ | `kitPioneiros2026Enabled` |
| `campaigns/pioneiros_2026` | ❌ (só admin) | Status, janela, modo, `rewardIds` |
| `campaigns/pioneiros_2026/eligible/{uid}` | ❌ | Subcoleção; o jogador só lê o próprio |
| `collections/pioneiros_2026` (+ `/items/{itemId}`) | ❌ | Catálogo |
| `users/{uid}/inventory/{itemId}` | ❌ | **Id determinístico = itemId** |
| `users/{uid}/campaign_claims/{campaignId}` | ❌ | **Id determinístico**; o comprovante |
| `audit/{auto}` | ❌ | Trilha de ação administrativa |

Campos por item de inventário: `userId`, `itemId`, `collectionId`, `source`,
`campaignId`, `campaignVersion`, `unlockedAt` (server timestamp), `equipped`.

### Por que isso não duplica

Três camadas, nenhuma dependendo de estado guardado no aparelho:

1. o comprovante tem id determinístico — a segunda gravação colide no mesmo
   documento em vez de criar outro;
2. cada item tem id determinístico — reaplicar sobrescreve em vez de somar;
3. a função consulta o comprovante antes de planejar e devolve `alreadyClaimed`.

Reinstalar, trocar de aparelho, sofrer timeout ou chamar dez vezes cai sempre em
(1) ou (3). A chave inclui a **versão** da campanha, para que uma reedição futura
seja concessão nova e não seja lida como duplicidade.

### Duas decisões que valem registro

- **A reconciliação acontece antes da checagem de elegibilidade.** Quem já
  recebeu não pode perder itens porque a campanha encerrou, a flag caiu ou a
  allowlist foi limpa. O inventário é permanente; a campanha é que tem prazo.
- **A reconciliação reusa o `claimedAt` do comprovante.** O item que faltava foi
  conquistado no dia do resgate, não no dia em que a falha foi percebida.

---

## 4. Elegibilidade

Cinco modos, configuráveis no documento da campanha, sem novo build:
`allowlist`, `closedTest`, `matchInWindow`, `hybrid`, `adminGrant`.

A concessão administrativa vale em **qualquer** modo — é a válvula prevista para
atender um jogador caso a caso. Ela ainda exige gravação de admin e gera
auditoria.

A regra existe em dois lugares, de propósito: em Dart (`colecao_campanha.dart`),
para o cliente escolher **qual tela desenhar**, e em JS (`functions/index.js`),
que é quem **autoriza a gravação**. Um aparelho com relógio adiantado ou APK
modificado muda apenas a própria tela. A função nem aceita evidência por
parâmetro — lê das fontes confiáveis dentro da transação.

Custo conhecido dessa duplicação: mudar a regra exige mudar os dois lados. A
alternativa seria confiar num veredito calculado no aparelho do jogador, que é o
que a ordem proíbe.

---

## 5. Contrato para a camada visual

### 5.1 Repositório

`ColecaoRepositorio` (puro) define `carregarCampanha`, `featureFlagLigada`,
`carregarEvidencia`, `carregarInventario`, `resgatar` e `aplicarEquipagem`.
`ColecaoRepositorioFirebase` implementa. Erros chegam como `ErroColecao` com um
`FalhaBackend` tipado — e só `indisponivel` sugere repetir, porque insistir num
não elegível só gera carga.

### 5.2 Origem da arte (ajuste 4)

**Confirmado: o resolvedor não está preso a caminho local.**

O catálogo guardava um `assetPath`. Agora guarda uma `FonteArte`, que é `bundle`
(hoje) ou `remota` (amanhã), com `sha256`, `bytes` e `chaveCache`. A camada
visual depende de `ResolvedorDeArte`, não de string de caminho.

A promessa que isso protege: **o `itemId` não muda quando a origem muda.** Uma
peça que hoje vem do bundle e amanhã vem da rede continua sendo o mesmo item no
inventário de quem já a possui — nenhuma migração, nenhum documento reescrito.

- fonte remota **exige** `sha256` — sem checksum não há como distinguir download
  truncado de arquivo íntegro;
- a chave de cache deriva da **origem**, nunca do `itemId`: dois itens podem
  apontar para o mesmo arquivo e o cache guarda uma cópia só;
- `CacheDeArte` está declarado sem implementação, para a forma já estar acordada:
  guarda por chave e confere o SHA-256 **antes** de dar o arquivo por bom;
- `ResolvedorBundle` **recusa** fonte remota em vez de devolver algo pela metade.

**O Kit Pioneiros continua inteiro no bundle.** Nada foi movido para
armazenamento remoto, e o seed não precisou ser reescrito: `assetPath` solto
continua sendo lido como bundle. Há 14 casos em `colecao_arte_test.dart`,
incluindo um catálogo com item remoto e item de bundle convivendo.

`app/lib/colecoes/colecao_ui_contract.dart` é o único arquivo que a etapa Codex
precisa ler.

- **Estados:** `inactive`, `loading`, `notEligible`, `eligibleUnclaimed`,
  `claiming`, `claimed`, `alreadyClaimed`, `recoverableError`.
- **View model por recompensa:** `id`, `displayName`, `assetPath`, `category`,
  `slot`, `owned`, `equipped`, `canEquip`, `sortOrder`, `accessibilityLabel`.
- **Callbacks:** `onClaim`, `onRetry`, `onEquip`, `onUnequip`, `onOpenInventory`,
  `onClose`.
- **Textos pt-BR** e os **7 eventos** de telemetria, cujo payload não tem onde
  carregar dado pessoal.
- **`RegrasDeExibicao`:** `BoxFit.contain`, margem interna ≥ 8%, transparência
  preservada, fundo escuro neutro, e proibição de precachear as 10 peças na
  abertura.

Nenhum widget consulta Firestore e nenhum widget decide elegibilidade.
`deveAparecer` concentra a regra de visibilidade num lugar só.

### Slots de equipagem

| Slot | Itens | Origem |
| --- | --- | --- |
| `mascote` | Bulldog, Rainha, Dragão | **Existente** (vitrine do perfil) |
| `efeito` | Vórtice | **Existente** (vitrine do perfil) |
| `coroa` | Coroa | **Novo** — não havia slot de coroa |
| `emblema` | Emblema, Medalhão | **Novo** — o jogador escolhe qual insígnia o representa |
| `vitrine` | Trono, Estátua | **Novo** — peça de vitrine/troféu |

O Baú não é equipável: é arte de apresentação, mas consta no catálogo para não
virar arquivo órfão.

Os três mascotes são possuídos ao mesmo tempo e apenas um fica ativo. Com um slot
de uma vaga, equipar troca automaticamente; com mais de uma vaga cheia, a
operação é **recusada** em vez de o sistema escolher quem sai.

---

## 6. Testes

**113 casos, todos verdes**, em três arquivos:

| Arquivo | Casos | Cobre |
| --- | ---: | --- |
| `kit_pioneiros_test.dart` | 78 | Critérios de aceite da seção 9 |
| `colecao_firebase_test.dart` | 21 | Adaptador, sobre `fake_cloud_firestore` |
| `colecao_arte_test.dart` | 14 | Origem da arte e resolvedor |

Rodam sobre os seeds **reais de produção**, copiados para dentro do teste pelo
workflow: o portão valida a configuração que vai para a loja, não uma fixture
paralela.

Amostra do que está coberto:

- flag desligada não concede; campanha em `draft` não concede;
- não elegível não resgata nem por chamada direta;
- elegível recebe exatamente 10 itens numa operação;
- repetir 10 vezes continua dando 10; segunda chamada devolve `alreadyClaimed`;
- falha parcial reconcilia só o que falta e preserva o `unlockedAt` original;
- quem já resgatou não perde o kit quando a campanha encerra;
- 3 mascotes possuídos, 1 ativo; Emblema e Medalhão dividem slot; Baú não equipa;
- comprovante com chave adulterada ou data sem `Z` é recusado;
- nenhum item tem campo de preço; telemetria sem dado pessoal.

`flutter analyze` no `app/lib` inteiro: **0 erros**, 105 issues (92 info, 13
warning) — **todas pré-existentes**. Sobre `lib/colecoes/` e os três arquivos de
teste, isolados: **`No issues found!`**.

Falta executar `firebase/testes/seguranca.test.js` (emuladores) — passo 7 do
runbook. É a única verificação escrita e ainda não rodada.

Dois portões novos no CI:

- **integridade do arquivo** — SHA-256 e tamanho contra o manifesto;
- **integridade dos pixels** — decodifica o PNG e confere `sha256_rgba`. Pega
  recorte, recolorização, resize e achatamento de alpha, e sobrevive a
  recompressões legítimas;
- **qualidade** — as três suítes com os seeds de produção.

E um workflow novo, `tamanho-aab.yml`, que roda os três portões mais o analyze
antes de compilar os dois AABs.

---

## 7. Tamanho do build

**Medido pelo CI**, no workflow `.github/workflows/tamanho-aab.yml`, que compila o
AAB de release duas vezes — no **merge-base** e neste commit — e publica os dois
como artefato `aab-comparacao`.

Por que merge-base e não o HEAD da branch anterior: comparar com o topo de outra
branch mediria também tudo o que entrou nela em paralelo. O merge-base é o último
ponto em comum, então a diferença isola o que **esta** branch acrescentou. Aqui o
merge-base é `0cea0d6`, topo de `origin/consolidacao/apk-geral-bmv`.

O lado "antes" é montado pelo procedimento que valia **naquele** commit
(`tools/ci/montar_app_legado.sh`). Montar os dois lados do jeito novo mediria a
mudança de pipeline junto com a coleção, e o delta deixaria de significar o que
promete.

O run publica no resumo:

- tamanho dos dois AABs, em bytes e MiB;
- **delta exato**, em bytes e MiB;
- peso comprimido das 10 peças dentro do AAB;
- estimativa de download por aparelho, via `bundletool get-size total` (sempre
  menor que o AAB, porque cada aparelho baixa só a sua fatia);
- resultado de analyze, dos testes e dos dois portões de SHA-256.

**Ordem de grandeza esperada:** o payload comprimido da coleção mede
**27.240.409 bytes ≈ 25,98 MiB** — medição direta, feita localmente com a mesma
compressão do empacotador. Os PNGs já estão saturados: o DEFLATE ganha ~0% neles.
O delta do AAB deve ficar próximo disso, com pequena diferença por conta do
código Dart novo e das dependências de Firestore/Functions. **O número oficial é o
que o CI imprimir.**

> O build local segue impossível nesta máquina — o Flutter no Windows exige Modo
> de Desenvolvedor para montar plugins. Conforme orientado, não pedi essa
> alteração: o caminho é o CI.

### 7.0 O run ainda não aconteceu — e o motivo

A branch foi enviada para `origin` em 06/08/2026 22:28Z, com o workflow presente
(`.github/workflows/tamanho-aab.yml`, 9.615 bytes, confirmado na branch remota).
**O GitHub não criou nenhum run.**

Ao investigar pela API pública, o padrão do repositório ficou claro:

| Últimos 10 runs | Evento | Workflow |
| --- | --- | --- |
| todos | `workflow_dispatch` | `.github/workflows/build.yml` |

**Nenhum run deste repositório foi disparado por `push`** — nem nesta branch, nem
nas outras. Todos são acionamentos manuais, e todos usam `build.yml`, que vive na
branch padrão. Sem autenticação não dá para ler as permissões de Actions do
repositório (`/actions/permissions` responde 401), então não afirmo a causa; o
que está medido é o padrão.

**Consequência prática:** `workflow_dispatch` só aparece na interface quando o
workflow está na **branch padrão**. Como `tamanho-aab.yml` está apenas nesta
branch, ele não é dispachável ainda.

**O que destrava, e é decisão sua** — não fiz nenhuma das duas:

1. **Levar só o arquivo do workflow para `main`.** É um arquivo novo, que não
   altera build nem app; depois disso, Actions → *Tamanho do AAB* → *Run
   workflow* → escolher esta branch.
2. **Ou abrir o PR** desta branch e verificar, nas configurações de Actions, por
   que eventos de `push` não disparam.

Enquanto isso não acontecer, **este item continua aberto** — e, como você
determinou, a implementação não deve ser considerada fechada sem o build de
release concluído.

### 7.1 Otimização PNG sem perda (ajuste 3)

Autorizada e aplicada. **O resultado é modesto e vale ser dito de frente: 20.812
bytes, ou 0,08%.**

| | bytes |
| --- | ---: |
| Antes | 27.241.519 |
| Depois | 27.220.707 |
| **Redução** | **20.812 (0,08%)** |

Por arquivo, entre 1.455 B (Vórtice, 0,05%) e 2.681 B (Rainha da Sorte, 0,11%).
Detalhe completo em `app/data/colecoes/otimizacao_pngs.json`.

**Esse é o teto real, não falta de esforço.** Testei a matriz completa — os cinco
filtros fixos do PNG mais o adaptativo, cruzados com as três estratégias de
deflate, 18 combinações — numa das artes. O melhor resultado foi 0,09%, e é
justamente a combinação que a ferramenta já escolhe (adaptativo + `Z_FILTERED`).
As artes chegaram muito bem comprimidas. Ganho relevante exigiria **zopfli**, que
é um binário externo; não instalei nada.

**Ferramenta:** `tools/otimizar_pngs.js`, escrita para esta entrega, usando apenas
a biblioteca padrão do Node — **Node v24.14.0, zlib 1.3.1-e00f703**, registrado no
manifesto. Nenhum binário baixado.

**O que ela faz:** inflaciona os IDAT, desfaz a filtragem, refiltra escolhendo por
linha o filtro de menor soma de diferenças absolutas, recomprime em nível 9
testando três estratégias, e grava um único IDAT no lugar dos ~40 chunks
originais.

**O que ela não faz:** nada de resize, mudança de color type ou bit depth,
conversão de formato, redução de paleta ou remoção de chunk de cor. As artes não
têm chunk auxiliar nenhum; descartáveis seriam só tEXt/zTXt/iTXt/tIME.

### 7.2 Comprovação de equivalência visual

**10/10 artes, zero pixels alterados**, verificado de duas maneiras
independentes:

1. **Dentro do otimizador.** Ele não grava nada antes de decodificar a própria
   saída e comparar o RGBA byte a byte com a entrada. Um pixel divergente aborta
   o arquivo.
2. **Contra o pacote original da Sônia**, depois do fato:
   ```bash
   node tools/verificar_equivalencia.js --contra "<pasta do pacote aprovado>"
   ```
   Saída: `10 artes conferidas, 0 divergencias. EQUIVALENCIA VISUAL CONFIRMADA`.
   Quando diverge, o erro aponta o primeiro pixel e o canal.

**O manifesto ganhou o campo que faltava.** `sha256_rgba` é a impressão digital
dos **pixels decodificados** — não muda numa recompressão sem perda. O hash do
arquivo, sozinho, não serve para provar equivalência: ele muda em qualquer
reescrita, legítima ou não. Com `sha256_rgba`, a equivalência passa a ser
verificável para sempre, e virou portão de CI:

```bash
node tools/verificar_equivalencia.js --contra-manifesto
```

Esse portão pega recorte, recolorização, resize e achatamento de alpha —
exatamente o que a ordem de serviço proíbe — e sobrevive a recompressões futuras.

O manifesto também guarda `origem` (SHA-256 e tamanho do arquivo como veio no
pacote aprovado), para o rastro não se perder. E `width`, `height`, `mode`,
`alpha_min` e `alpha_max` passaram a ser **recalculados dos pixels**, e não
copiados do manifesto anterior: um manifesto que repete o que já estava escrito
não prova nada. Todas as dez seguem 1254×1254, RGBA, alpha 0–255.

## 8. Evidências

Prints em `app/test/colecoes/evidencias/`, gerados por
`flutter test test/colecoes/evidencias_visuais_test.dart`:

| Arquivo | Mostra |
| --- | --- |
| `01_elegivel_nao_resgatado.png` | Convite: 10 peças, nenhuma possuída, resgate ativo |
| `02_resgate_concluido.png` | 10 de 10 numa única operação |
| `03_inventario_ja_resgatado.png` | Segunda chamada: `alreadyClaimed`, sem duplicidade |
| `04_itens_equipados.png` | 5 slots ativos; 3 mascotes possuídos, 1 equipado |

> **Isto não é a tela do produto e não é proposta de layout.** É o andaime mínimo
> para provar que o contrato funciona e que as regras da arte são respeitáveis
> (fundo escuro neutro, `BoxFit.contain`, margem de 8%, transparência real).
> Nenhum widget entrou em `lib/` — o aplicativo não ganhou tela nenhuma.
> O gerador fica **fora** do portão do CI, porque escreve imagem em vez de
> comparar golden.

O print `04` é o que mais carrega informação: mostra os cinco slots ativos com
borda dourada e, ao mesmo tempo, os três mascotes possuídos com **apenas um**
equipado — a exclusividade de slot funcionando.

### Achado de performance para a etapa Codex

Montar os prints expôs um custo que a tela definitiva vai encontrar: dez artes de
1254×1254 decodificadas em tamanho cheio ocupam **~63 MB de memória** (6,3 MB
cada, em RGBA). No harness isso deixou cada captura na casa de minutos.

A correção é `cacheWidth` (ou `ResizeImage`) no tamanho real de exibição —
`Image.asset(path, fit: BoxFit.contain, cacheWidth: 480)`. **Não recorta, não
deforma e não toca no arquivo**: muda só a resolução de decodificação. Vale
combinar com a regra já registrada em `RegrasDeExibicao.precachearTudoNaAbertura
= false` (carregar sob demanda; no carrossel, antecipar apenas o item seguinte).

---

## 9. Critérios de aceite (seção 9 da ordem)

| Critério | Situação |
| --- | --- |
| Flag desligada: campanha não aparece, nada é concedido | ✅ testado |
| Não elegível não resgata nem por chamada direta | ✅ testado + regras |
| Elegível recebe exatamente 10 itens numa operação | ✅ testado |
| Repetir/timeout/reinstalar/trocar aparelho não duplica | ✅ testado (ids determinísticos) |
| Inventário consistente após logout/login e em outro aparelho | ✅ por construção · ⏳ prova em emulador é o passo 7 do runbook |
| Transparência real, sem corte e sem deformação | ✅ prints + portão de pixels |
| 3 mascotes distintos, seguindo a regra de equipagem | ✅ testado |
| Cada peça em categoria/slot documentado | ✅ §5 |
| Nenhum item à venda, nenhum preço criado | ✅ testado (não existe campo de preço) |
| Delta de AAB/APK medido e informado | ✅ workflow `tamanho-aab.yml` |
| `flutter analyze` sem erros novos; testes passam; build de release conclui | ✅ analyze e 113 testes · ⏳ build no CI |
| Prints e log de testes | ✅ §8 |

---

## 10. Pendências

**Antes de considerar fechado:**

1. **Destravar o run do `tamanho-aab.yml`** (ver §7.0): eventos de `push` não
   disparam neste repositório, e `workflow_dispatch` só aparece para workflows da
   branch padrão. Depois, conferir delta e AAB publicado.
2. Rodar `firebase/testes/seguranca.test.js` nos emuladores (passo 7 do runbook)
   — fecha a única verificação escrita e ainda não executada.

**Para ativar (runbook completo em [KIT-PIONEIROS-2026-RUNBOOK.md](KIT-PIONEIROS-2026-RUNBOOK.md)):**

3. Salvar e comparar as regras que estão hoje na Console — **o passo mais
   delicado**: no Firestore, caminho não declarado é caminho negado.
4. Implantar regras, índices e Functions; esperar os índices concluírem.
5. Rodar o seed (ensaio, depois `--commit`).
6. Teste controlado com um UID real, ainda invisível para os demais.
7. Ligar App Check, `status: active` e, por último, a feature flag.

**Camada visual (etapa Codex), consumindo o contrato:**

8. Card de convite, abertura do Baú, carrossel de revelação, fechamento com
   Emblema/Coroa, aba do kit no inventário.
9. Expor os três slots novos (`coroa`, `emblema`, `vitrine`) na vitrine do perfil.
10. Ligar os 7 eventos de telemetria ao provedor de analytics.
11. Usar `cacheWidth`/`ResizeImage` ao renderizar: dez artes decodificadas em
    tamanho cheio custam ~63 MB de memória (§8).

**Quando houver uma segunda coleção:**

12. Implementar o resolvedor remoto e o `CacheDeArte` — os contratos já estão
    definidos (§5.2). O Kit Pioneiros não precisa ser migrado.

---

## 11. Checklist de devolução (seção 11 da ordem)

| Item | |
| --- | --- |
| Branch e commits informados | ✅ |
| Manifesto e assets registrados | ✅ manifesto regenerado, com impressão de pixels |
| Critério de elegibilidade configurável | ✅ 5 modos |
| Resgate seguro/idempotente | ✅ |
| Dez itens no inventário | ✅ |
| Regras Firebase atualizadas | ✅ criadas (não implantadas) |
| Contrato de UI documentado | ✅ |
| Build release concluído | ⏳ workflow pronto e branch enviada; run bloqueado (§7.0) |
| Delta de tamanho informado | ⏳ medido pelo CI; payload local ≈ 25,98 MiB |
| Prints e resumo de testes | ✅ |
| Nenhuma alteração visual não aprovada | ✅ nenhuma tela tocada; 0 pixels alterados |

**Não mesclar em `main` sem validação da Sônia. Nada implantado no Firebase.**
