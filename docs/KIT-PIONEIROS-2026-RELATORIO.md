# Kit Pioneiros 2026 — relatório técnico

Entrega da parte lógica, Firebase e contratos de integração, conforme a ordem de
serviço de 06/08/2026. A camada visual definitiva **não** foi feita e continua
reservada à etapa Codex.

- **Branch:** `claude/kit-pioneiros-2026-1b56ed` (não mesclada em `main`)
- **Base:** `0cea0d6`
- **Toolchain:** Flutter 3.41.4 local · CI pinado em 3.44.8

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
[firebase/README.md](../firebase/README.md) para a ordem de deploy.

**Pendência que bloqueia a ativação:** adicionar `cloud_firestore` às dependências
do CI. Enquanto isso não acontecer, a campanha não tem como ser lida pelo app.

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
| `app/test/colecoes/evidencias_visuais_test.dart` | Gerador dos prints (não é tela do produto) |
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

`flutter test test/colecoes/kit_pioneiros_test.dart` → **81 casos, todos verdes.**

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
warning) — **todas pré-existentes**. Nenhuma vem de `lib/colecoes/`.

Dois portões novos no CI:

- **integridade** — SHA-256 e tamanho de cada peça contra o manifesto. Recorte,
  recolorização ou achatamento de alpha viram falha de build, não revisão no olho;
- **qualidade** — a suíte com os seeds de produção.

---

## 7. Tamanho do build

**Medição:** o payload da coleção comprimido exatamente como entra no APK
(DEFLATE nível Optimal, que é o do empacotador).

| | |
| --- | --- |
| Pasta, descomprimida | 27.241.519 B = **25,98 MiB** |
| Dentro do APK | 27.249.849 B = **25,99 MiB** |
| **Delta no APK** | **≈ 26,0 MiB** (+ ~760 B de cabeçalhos) |

Os PNGs já estão saturados: o DEFLATE do APK ganha **0%** neles — o arquivo
chega a ficar alguns bytes maior. Ou seja, o custo no artefato é praticamente o
tamanho bruto da pasta, sem desconto.

> **Limitação, dita com todas as letras:** o APK de release **não** foi compilado
> localmente. O Flutter no Windows exige o Modo de Desenvolvedor ativado para
> montar plugins (symlinks), e essa é uma configuração de sistema que não altero
> por conta própria. O número acima é medição direta do payload, não estimativa —
> mas o delta ponta a ponta do artefato só sai de um build completo.
>
> Duas formas de fechar isso: ativar o Modo de Desenvolvedor no Windows e eu rodo
> o build local, ou deixar o CI medir. O passo **"Kit Pioneiros no APK + custo
> real da coleção"** já foi adicionado ao `build.yml` e imprime, no próximo build
> de `main`, o tamanho comprimido real, o APK completo e a porcentagem.

**Recomendação:** 26 MiB é bastante para uma coleção. A seção 6.1 da ordem
permite otimização PNG **sem perda**. Vale avaliar `oxipng`/`zopflipng`, que
costumam tirar 5–15% de PNGs assim sem tocar um pixel.

Não fiz isso por conta própria por dois motivos: alteraria os bytes das artes
aprovadas, e invalidaria os SHA-256 do manifesto — o portão de integridade
passaria a falhar. Se você aprovar, o caminho é reotimizar, **regerar o
manifesto** e confirmar que os pixels e o alpha saíram idênticos.

---

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
| Inventário consistente após logout/login e em outro aparelho | ✅ por construção (id determinístico, sem estado local) — ⏳ falta validar no emulador |
| Transparência real, sem corte e sem deformação | ✅ prints + `RegrasDeExibicao` |
| 3 mascotes distintos, seguindo a regra de equipagem | ✅ testado |
| Cada peça em categoria/slot documentado | ✅ seção 5 |
| Nenhum item à venda, nenhum preço criado | ✅ testado (não existe campo de preço) |
| Delta de AAB/APK medido e informado | ⚠️ payload medido; build completo pendente (seção 7) |
| `flutter analyze` sem erros novos; testes passam; build de release conclui | ✅ analyze e testes · ⚠️ build de release pendente |
| Prints e log de testes | ✅ seção 8 |

---

## 10. Pendências

**Bloqueia a ativação:**

1. Adicionar `cloud_firestore` às dependências do CI — sem isso o app não lê a
   campanha.
2. Implantar regras, índices e funções (ver `firebase/README.md`). Regras
   primeiro.
3. Rodar o seed e definir modo de elegibilidade, janela e allowlist.
4. Ligar `kitPioneiros2026Enabled` e mudar `status` para `active`.

**Camada visual (etapa Codex), consumindo o contrato:**

5. Card de convite, abertura do Baú, carrossel de revelação, fechamento com
   Emblema/Coroa, aba do kit no inventário.
6. Expor os três slots novos (`coroa`, `emblema`, `vitrine`) na vitrine do perfil.
7. Ligar os 7 eventos de telemetria ao provedor de analytics.

**Recomendado:**

8. Decidir sobre a otimização PNG sem perda (seção 7).
9. Rodar a suíte de regras no emulador do Firestore, para fechar o critério de
   sincronização entre aparelhos com evidência e não só por construção.

---

## 11. Checklist de devolução (seção 11 da ordem)

| Item | |
| --- | --- |
| Branch e commits informados | ✅ |
| Manifesto e assets registrados | ✅ |
| Critério de elegibilidade configurável | ✅ 5 modos |
| Resgate seguro/idempotente | ✅ |
| Dez itens no inventário | ✅ |
| Regras Firebase atualizadas | ✅ criadas (não implantadas) |
| Contrato de UI documentado | ✅ |
| Build release concluído | ⚠️ ver seção 7 |
| Delta de tamanho informado | ✅ ≈ 26,0 MiB |
| Prints e resumo de testes | ✅ |
| Nenhuma alteração visual não aprovada | ✅ nenhuma tela tocada |

**Não mesclar em `main` sem validação da Sônia.**
