# Descoberta Social, Amigos e Perfil Público V1 — contrato do CLIENTE

Este documento descreve o lado do **cliente**. As autoridades já existiam e não
foram alteradas:

- `docs/CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md` — identidade pública e grafo social.
- `docs/CONTRATO-BUSCA-APELIDO-DESCOBERTA.md` — busca por apelido.
- `docs/AUTORIDADE-DE-IDENTIDADE-PUBLICA.md` — quem emite `publicId`.

---

## 1. Gate Zero — a arbitragem das linhagens

Resolvida **por ancestralidade**, e não por data:

```
f9814f9 ──> fddcecc   (AUTORIDADE: identidade pública + grafo social)
              │
              ├──> 7a25c06 ─> 9ac6d67 ─> e97bac8   (busca por apelido)
              │
              └──(cherry-pick)──> 0b0aa63 ──> … ──> cd0562d   (Perfil Público)
```

- `fddcecc` **é ancestral** de `e97bac8`: a folha de descoberta **descende** da
  autoridade — não compete com ela.
- `0b0aa63` **é ancestral** de `cd0562d`: a linha do Perfil **já contém** a
  autoridade, portada por cherry-pick.
- O cherry-pick foi **fiel**: `functions-social/src/{chaves,domain,index,repositorio}.ts`
  são **byte-idênticos** entre `fddcecc` e `cd0562d`.

Logo não havia arquitetura a decidir. A base é `cd0562d`, e a busca é um delta
**aditivo** de três commits sobre um tronco que já estava lá.

Os três conflitos do porte (todos em arquivo de configuração) foram resolvidos
por **união**, nunca por escolha de lado — `functions-social/package.json`,
`firebase.json` e `firebase/firestore.indexes.json`.

---

## 2. O módulo `app/lib/amigos/`

| arquivo | papel |
|---|---|
| `estado_social.dart` | domínio puro: relação, ações, jogador, páginas, falhas |
| `transporte_social.dart` | a PORTA (interface), sem Flutter e sem Firebase |
| `transporte_social_firebase.dart` | o ÚNICO arquivo que conhece `cloud_functions` |
| `leitor_social.dart` | quem fala com a autoridade, e o único que fala |
| `escopo_social.dart` | como as telas alcançam o leitor |
| `rotulos_sociais.dart` | as palavras, num lugar só |

### Por que não é `lib/social/`

`app/lib/social/` **não é cliente**: é o domínio das Cloud Functions escrito em
Dart e compilado para JS (`dart compile js -o functions-social/lib/domain_bundle.js
app/lib/social/js_bridge.dart`). Uma tela que o importasse levaria para dentro do
aplicativo a autoridade que mora no servidor — inclusive o cunhador de
`publicId` —, e `test/sessao/auditoria_identidade_test.dart` reprova esse import.

Por isso `RelacaoSocial` e `AcaoSocial` são declarados aqui e hidratados pelo
`.name` que vem no fio. A duplicação é deliberada, e é a fronteira.

---

## 3. As três regras que organizam tudo

### 3.1 A interface não inventa permissão

Os botões de um resultado de busca são `ResultadoSocial.acoes`, que vem do
servidor. Deduzi-los da relação seria uma segunda política, e ela ignoraria
bloqueio e sanção social: o servidor pararia de oferecer "adicionar amigo" a
quem tem restrição, e a tela continuaria desenhando o botão.

A relação serve para o **rótulo**; a lista de ações serve para o **botão**.
Rótulo descreve, botão autoriza.

**A única exceção, auditada e documentada:** as listas (`listarAmigos`,
`listarSolicitacoes*`) devolvem `EntradaPublica` e **não** devolvem `acoes` — o
contrato foi escrito assim porque a lista já é o estado. Ali a tela desenha as
ações que a lista implica (as mesmas que `acoesDisponiveis` deriva no servidor).
A alternativa seria uma chamada de `verPerfilPublico` por linha — 25 chamadas
para uma página de 25 amigos —, e o ganho seria cobrir a janela em que alguém
bloqueou você entre a listagem e o toque. **Essa janela não é explorável:** toda
operação social lê o bloqueio dentro da própria transação. O botão desenhado a
mais é recusado pela autoridade; a autorização continua inteira do lado de lá.

### 3.2 O cliente não guarda grafo

O que o leitor guarda são **páginas** que o servidor devolveu. Não há conjunto
de arestas, não há `Map<publicId, éMeuAmigo>`, e nada responde "somos amigos?" a
partir da memória.

Depois de cada ação aceita, nesta ordem:

1. **SUBTRAI** a linha da lista onde ela estava — a autoridade acabou de dizer
   que aquela pendência não existe mais.
2. **RELÊ** `verPerfilPublico` daquele jogador, e é dessa resposta que saem a
   relação e as ações novas.

Nenhuma das duas **adiciona** jogador a lista nenhuma. Quem entra na lista de
amigos é a próxima leitura de `listarAmigos`, e por isso as listas ficam
**vencidas** (`FaseSocial.naoCarregada` preservando a página) em vez de
remendadas. Quem chama `garantir` depois de uma ação é a TELA, para a aba
visível — o leitor não sabe qual é.

### 3.3 `publicId` continua opaco

Nada em `lib/amigos/` conhece alfabeto, comprimento ou prefixo. A checagem para
em `trim().isNotEmpty`. Quem recusa malformado é o servidor
(`invalid-argument`).

---

## 4. Navegação ao Perfil

`lib/casca/navegacao_perfil_publico.dart` continua sendo o **único** ponto que
decide de quem é o Perfil que abre. Ele ganhou `AlvoDePerfil`, com um construtor
por origem:

| construtor | de onde vem `souEu` |
|---|---|
| `AlvoDePerfil.doRanking` | `jogador.souEu`, calculado pelo servidor sobre o UID |
| `AlvoDePerfil.daBusca` | `relacao == euMesmo`, que o servidor devolve |
| `AlvoDePerfil.daListaSocial` | `false`, por **invariante do banco** — ver abaixo |

**Por que `false` nas listas não é suposição:** uma relação de alguém consigo
não pode existir. `avaliarSolicitacao` recusa `solicitanteUid ==
destinatarioUid` antes de tudo, e `chaveDoPar` **lança** para um par de um
jogador com ele mesmo — nem por escrita direta o documento nasce.

---

## 5. O Perfil visitado

**Duas autoridades para duas perguntas**, e não uma só para as duas:

- **quem é essa pessoa** (nome, avatar, números) → projeção do ranking, que foi
  canonizada em `cd0562d` e **não foi tocada**;
- **o que eu sou dela** (relação e ações) → `social:verPerfilPublico`.

Pedir a relação ao ranking seria pedir a ele uma resposta que ele não tem. Pedir
a identidade ao social criaria uma segunda fonte de nome — que é exatamente o
defeito que a canonização fechou.

A faixa entra em `PerfilScreen` como um **widget pronto**, e não como campos
(`relacao`, `acoes`, `onAcaoSocial`). Com campos, o `switch` que decide qual
botão existe acabaria dentro da tela do Codex, e aquele arquivo viraria um
segundo lugar onde se decide permissão.

Uma falha do social **não derruba** o Perfil: perde-se o botão, não a tela.

---

## 6. O que esta OS deliberadamente NÃO fez

- **Aba "Online" / presença.** A maquete tem Online/Todos/Pedidos, e a primeira
  depende de um serviço de presença que não existe em lugar nenhum do projeto.
  Alimentá-la com a lista completa faria a tela afirmar que todo mundo está
  jogando.
- **Portão de VIP.** A maquete anuncia Amigos como benefício de assinatura, e o
  backend social **não** aplica esse gate — as callables atendem qualquer
  autenticado. Um portão só no cliente seria decoração sobre uma porta aberta.
- **Bloquear/desbloquear.** São do codebase de **moderação**; o social apenas
  reage a eles por gatilho. `TransporteSocial.agir` lança `ArgumentError` se
  pedirem, e as telas filtram por `kAcoesDeAmizade`.
- **Código de convite / recompensa por convite.** Não há autoridade que os
  emita.
- **Limite de taxa da busca.** Lacuna registrada no contrato da busca: contá-la
  exigiria o "histórico de pesquisas" que a própria OS proíbe. A solução é quota
  genérica (App Check / Cloud Armor).

---

## 7. Dois defeitos reais que os testes acharam

1. **`whenComplete(() => _vistasEmVoo.remove(alvo))`** — `Map.remove` **devolve**
   o valor removido, que aqui é o próprio `Future`, e `whenComplete` espera pelo
   que a sua função retorna. O voo passava a esperar por si mesmo e **nunca
   completava**: toda visita a um perfil de terceiro travaria para sempre, sem
   erro e sem log. Corrigido com corpo de bloco.

2. **`notifyListeners()` durante a construção da árvore** — `garantir()` nasce em
   `didChangeDependencies`. A defesa ficou **no leitor** (`_notificarEmBreve`),
   e não na tela: no leitor ela vale para todo chamador futuro.

---

## 8. As provas

| suíte | casos | o que prova |
|---|---|---|
| `test/amigos/estado_social_test.dart` | 28 | a fronteira do fio |
| `test/amigos/leitor_social_test.dart` | 29 | dedupe, geração, subtrai/relê/nunca adiciona |
| `test/amigos/descoberta_social_tela_test.dart` | 18 | as duas superfícies |
| `test/amigos/auditoria_descoberta_social_test.dart` | 22 + 1 pulado | as regras varridas no código |

`test/amigos/bancada_social.dart` é o transporte falso, com modo manual para
encenar resposta que demora, que chega fora de ordem e que é recusada com o
código de domínio exato.

**O caso pulado** cruza os nomes das callables do cliente com
`functions-social/src/index.ts`. Ele é pulado **com aviso explícito** quando o
backend está fora de alcance (o overlay do CI não o tem ao lado). Foi executado
de verdade nesta entrega, com o backend espelhado ao lado do overlay: as dez
callables conferem.

### Mutações injetadas

Oito, e **duas passaram despercebidas na primeira tentativa** — as duas
expuseram lacunas reais, e as duas viraram correção:

| mutação | 1ª rodada | correção |
|---|---|---|
| ações deduzidas da relação na busca | detectada | — |
| aceitar ADICIONA aos amigos | detectada | — |
| relação desconhecida vira `nenhuma` | detectada | — |
| `souEu` da busca fixado em `false` | detectada | — |
| vista deduzida do desfecho | detectada | — |
| a maquete volta a ser importada | detectada | — |
| **o Perfil do dono consulta a porta de terceiro** | **passou** | o caso usava `publicIdVisitado` nulo, onde a guarda é redundante; entrou o caso `ehMeuPerfil: true` **com** id escrito |
| **recusa crua vai para a tela** | **passou** | a regra proibia a *interpolação*; o defeito é o valor SAIR. Agora `e.recusa` só pode ser assunto de `switch` |

Uma nona mutação, no cruzamento com o backend (`listarAmigos` →
`listarAmigosRenomeada`), também passou: `contains('export const $nome')` é
verdadeiro para um nome que é **prefixo** do novo. A varredura passou a extrair
os nomes exportados e comparar por igualdade.

---

## 9. Medições

Overlay `C:\bmvsoc` (o `F:` é exFAT — ver `docs` de bancada):

- **1330 testes verdes + 1 pulado**, contra **1232** na base `cd0562d` + porte.
- `flutter analyze`: conjunto **idêntico** ao da base, ocorrência por ocorrência.
- `functions-social`: `tsc --noEmit` limpo; **55/55** testes Node
  (`chaves` 19, `busca` 10, `auditoria` 26).

---

## 10. Auditorias existentes que foram atualizadas

Nenhuma foi enfraquecida.

- `casca_producao_test` — Amigos saiu do grupo "só tem prévia visual" e ganhou
  afirmação própria.
- `homologacao_casca_v2_test` — os "quatro bloqueados" viraram três, **e** entrou
  um caso provando que Amigos navega, consulta a autoridade uma vez e não mostra
  nome de maquete.
- `avatar_publico_canonico_test` — a regra do avatar deixou de ser "ninguém mais
  pode nomear o campo" (que reprovaria um consumidor correto) e passou a ser o
  que sempre quis dizer: **leu, chamou o resolvedor**. Os portadores ganharam
  afirmação própria de que não desenham.
- o fecho alcançável **48 → 55**, com os sete nomes declarados e a afirmação
  explícita de que `lib/screens/amigos_screen.dart` **não** entrou.
