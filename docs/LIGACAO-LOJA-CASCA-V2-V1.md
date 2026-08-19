# Ligação produtiva da Loja à Casca V2 — V1

**Veredito: PASS.** A Loja é alcançável pelo aplicativo publicável, partindo de
duas superfícies reais da Casca, sem passar por `main.dart` de prévias.

Branch: `integracao/loja-casca-v2-v1`, base `integracao/functions-producao-canonica-v1 @ 6340573`.

---

## 1. Gate Zero — a topologia, medida antes de editar

### 1.1 A pergunta que decidiu tudo

A ordem de serviço pedia a folha mais recente com a **Loja real** e a folha mais
recente da **Casca produtiva**. A medição foi feita sobre os **392 refs** do
repositório (locais + `origin`), por presença de árvore, e não por nome de
branch:

| marcador | o que identifica | refs que o têm |
|---|---|---|
| `app/lib/billing/` | o cliente Play Billing real (entitlement + `formattedPrice`) | 28 |
| `app/lib/casca/` | a Casca V2 produtiva (raiz, Login, Home, roteamento por sessão) | 45 |
| **os dois juntos** | — | **1** |

O único ref do repositório onde as duas linhagens já estão compostas é
`integracao/functions-producao-canonica-v1 @ 6340573`. Ele é a base desta OS.

Isso não é conveniência: **não havia escolha a fazer**. As outras 27 folhas com
Billing carregam o `main.dart` de 84 KB — a bancada de prévias — e nenhuma delas
tem `app/lib/casca/`. As outras 44 folhas com Casca não têm `app/lib/billing/`.
Compor as duas famílias do zero seria refazer o trabalho que `6340573` já fez.

### 1.2 Ancestralidade

`6340573` **contém** a folha da Loja real:

```
CONTIDA  8ce6fa0  claude/loja-play-real-prova-comportamental-v1
CONTIDA  5fa2d96  integracao/play-billing-propriedade-compra-p0-v1
CONTIDA  c0bd150  claude/autoridade-tipos-mesa-permissoes-v1
CONTIDA  3d124b0  claude/chat-transporte-real-v1        (traz a Casca V2 por dentro)
CONTIDA  3752ad8  claude/casca-producao-auth-roteamento-v2-76c136
```

E **não contém** as folhas de Casca mais novas, que seguem paralelas:

```
FORA  bf5a9e7  claude/descoberta-social-amigos-perfil-657134
FORA  45479fb  claude/inspecao-ampliada-cosmeticos-loja-perfil-v2
FORA  c65a61b  claude/torneios-mock-admin-cleanup-b0e388
FORA  2ffe4ff  claude/integracao-splash-rive-constelacao-v1
FORA  ea2d7b7  claude/meta-canonica-lobby-v1
FORA  cd0562d  claude/perfil-publico-visitado-identidade-canonica-v1
FORA  861d4d5  claude/configuracao-mesa-apostas-canonicas-v1
FORA  089cb5e  integracao/avatar-ranking-estatisticas-navegacao-publica-v1
FORA  b246c07  claude/casca-producao-auth-roteamento-v2-9c41ae
FORA  5022848  claude/colecoes-inventario-jogador-v1
```

**Elas continuam fora, de propósito.** Compor oito folhas de Casca é outra OS, e
misturá-la com esta esconderia qual mudança quebrou o quê. O que esta entrega
afirma é sobre a ligação; não sobre a composição da RC.

### 1.3 STOP — duas autoridades comerciais incompatíveis?

**Não.** A condição de parada não se materializou, e a verificação foi feita:

- há **um** cliente de Billing na árvore (`app/lib/billing/`, 12 arquivos);
  `app/lib/services/` não tem nenhum `billing_*.dart` — o cliente antigo de
  `feat/play-billing-aab-interno` não está aqui e não foi trazido;
- há **um** catálogo de produtos (`CatalogoBilling.oficial`);
- há **uma** autoridade de preço, e ela não é nossa: `formattedPrice` da Play.
  Nenhum preço em `lib/` fora da maquete (`LojaVM.mock`), que esta entrega
  tornou inalcançável;
- há **uma** autoridade de direito VIP: `playerEntitlements/{uid}`, escrito só
  pelo backend.

---

## 2. O defeito que a ligação corrige

O Billing do cliente estava **completo e inalcançável**.

O host que liga a tela ao Billing existia num lugar só — `_LojaPreviewHost`,
dentro das 2.172 linhas do `main.dart` antigo. Ele já era o host certo: foi ele
que trocou o `setState(() => _ehVip = true)` por `playerEntitlements/{uid}` e os
preços escritos à mão pelo `formattedPrice` da Play.

A Casca V2 apagou aquele arquivo, e com razão — era uma bancada de prévias. Mas
o host da Loja foi junto. Desde então, nenhuma rota que nasce em `main()`
chegava a uma tela capaz de abrir o fluxo de compra: na Home, `Loja VIP` era um
item **apagado** (`disponivel: false`) e o toque respondia "ainda não está
disponível nesta versão"; nos Ajustes, `Assinatura VIP` fazia o mesmo.

Um aplicativo com Play Billing implementado, homologado, e sem caminho para
comprar.

---

## 3. O que foi entregue

### 3.1 A tela de produção — `lib/casca/loja_de_producao.dart` (novo)

O host de prévia, movido para dentro da casca, com três diferenças:

1. **O uid vem do `EscopoSessao`**, e não de `FirebaseAuth.instance`. Só a
   camada de sessão fala com o provedor — é a invariante que
   `auditoria_casca_test.dart` cobra.
2. **A navegação é a de produção**: `‹` volta com `maybePop`, o Início é a Home
   real e o Perfil é a `PerfilPage` real.
3. **Nada de `LojaVM.mock()`.**

### 3.2 Por que a Loja publicável é menor que a maquete

O host de prévia desenhava `LojaVM.mock().copiarCom(ehVip:…, planos:…)`: o VIP e
os planos vinham do backend e da Play; **todo o resto** — 1.000 moedas, 12
gemas, cinco pacotes com preço, seis categorias de cosmético com contagem
("28 skins"), oito amigos para presentear — vinha da maquete.

Numa bancada de prévias isso é honesto: quem abre sabe que está olhando um
desenho. Num aplicativo publicado, não:

- `🪙 1.000` no alto da tela é uma **afirmação sobre a carteira** de quem
  instalou. É o mesmo defeito que a Casca V2 tirou da Home, na mesma posição da
  tela;
- um pacote de moedas com `R$ 4,90` é uma **oferta** — de um produto que não
  existe na Play Console, que nenhum backend credita e que ninguém aprovou.
  Publicar isso não é maquete: é promessa comercial sem produto por trás.

Sobra o que tem autoridade: o selo VIP e os planos. Enquanto `master_vip` não
existir na Play Console, a lista de planos vem vazia — e a tela **diz isso**,
em vez de mostrar um buraco no lugar da grade.

`LojaScreen` ganhou a capacidade de calar o que não tem fonte: `moedas` e
`gemas` viraram nuláveis (a pastilha da carteira some), e as seções MOEDAS,
COSMÉTICOS e o botão de presentear não são desenhados com a lista vazia. **A
maquete não perdeu nada** — `LojaVM.mock()` continua preenchendo tudo, e as
telas de prévia continuam desenhando a vitrine completa.

O caminho de volta não passa por aqui: no dia em que houver autoridade de
economia e catálogo de cosméticos, quem as ligar preenche os campos
correspondentes e as seções reaparecem sozinhas.

### 3.3 As duas portas de entrada

| superfície | antes | agora |
|---|---|---|
| Home, grade do menu, item `Loja VIP` | apagado, aviso "ainda não" | abre `LojaDeProducao` |
| Home, barra de baixo, `NavDestino.loja` | aviso "ainda não" | abre `LojaDeProducao` |
| Ajustes, `Assinatura VIP` | aviso "ainda não" | abre `LojaDeProducao` |

A Loja é **empurrada sobre** a Home — é o que faz o `‹` voltar para ela em vez
de reconstruí-la, e o que mantém a Home viva embaixo.

### 3.4 O `cloud_functions` que precisou sair de `vinculo.dart`

Ligar a Loja tornou `lib/billing/` alcançável a partir de `main.dart`, e isso
acordou uma invariante do projeto inteiro, cobrada por `composicao` (C11b): **só
um arquivo `*_firebase.dart` conhece `cloud_functions`**. `vinculo.dart`
carregava a porta e o adaptador no mesmo arquivo.

`PreparadorFirebase` saiu para `lib/billing/vinculo_firebase.dart`. É a forma
que o resto do módulo já tinha (`validacao.dart` / `validacao_firebase.dart`), e
devolve `vinculo.dart` à condição de Dart puro — que é a razão de a porta
existir.

Esta foi a **única** regressão que a ligação produziu, e ela apareceu porque o
portão existia. Vale registrar: as duas primeiras execuções da suíte
apontaram exatamente os três lugares que afirmavam o estado velho — os dois
testes que provavam que a Loja *não* navegava, e este.

---

## 4. O portão novo — `test/casca/loja_de_producao_test.dart`

16 casos, registrados como gate `cascaloja` na fonte única
(`scripts/ci/gates_os_integracao.txt`) e no `ci-os-integracao.yml`. Entram
automaticamente no `flutter test test/casca` do `build.yml`.

| grupo | o que prova |
|---|---|
| a Loja é alcançável | grade da Home, item não apagado, Ajustes, e o `‹` que volta |
| a Loja respeita a sessão | Billing montado com o uid canônico; logout com a Loja aberta a descarta; sem sessão, nem Billing é montado |
| não desenha dado sem fonte | sem carteira, sem pacote, sem cosmético, sem amigo; nenhum `R$` na tela; catálogo vazio explicado |
| o VIP vem do backend | entitlement acende o selo; **tocar em assinar não acende** |
| a direção da falha | fora do `EscopoLoja`, a montagem é a de PRODUÇÃO |
| o critério de PASS | `lib/casca/loja_de_producao.dart` está no fecho de imports de `lib/main.dart`, e `main.dart` não tem `Preview` |

### 4.1 Os testes mordem — mutação injetada

Não basta verde. Duas mutações foram aplicadas ao código de produção no overlay:

| mutação | quem pegou |
|---|---|
| a Loja volta a desenhar `LojaVM.mock().copiarCom(…)` | 3 casos comportamentais **+** `auditoria_casca_test.dart` ("nenhum arquivo alcançável CONSTRÓI um `.mock()`") |
| `onAssinar` volta a acender VIP local (`setState(() => _vipLocal = true)`) | `tocar em assinar NÃO acende o VIP` |

Duas camadas independentes pegam a primeira; a segunda é o defeito comercial
original, e ele reprova.

---

## 5. Medições

Overlay do CI reproduzido localmente (`C:\bmvloja`), baseline em `6340573`
medido no mesmo Flutter (3.41.4) e no mesmo scaffold.

| medida | baseline `6340573` | HEAD |
|---|---|---|
| `flutter analyze` | 191 issues, **0 erros** | 191 issues, **0 erros** |
| issues novos | — | **nenhum** |
| `flutter test` (suíte completa) | 1533 verdes | **1549 verdes** (+16) |
| falhas | 4 | **as mesmas 4** |
| `test/casca` + `test/billing` + `test/composicao` | — | 340 verdes, 0 falhas |
| teste do próprio portão do CI | — | 31 casos, VERDE |

As 4 falhas são **pré-existentes e idênticas** nos dois lados, nenhuma tocada
por esta OS: `conta/conformidade_web_test.dart (setUpAll)`,
`conta/gerenciar_assinatura_test.dart (kPacotePlayOficial)` e dois casos de
`mesa_flow_plan_test.dart`.

---

## 6. O que esta OS NÃO fez, e por quê

- **Não reimplementou Billing.** Nenhum arquivo de `lib/billing/` mudou de
  comportamento; o único mexido foi `vinculo.dart`, e só para mover uma classe
  de arquivo.
- **Não implementou inventário nem cosméticos.** Coleções segue onde estava, na
  sua própria folha; `loja_categoria_screen.dart` continua sem ninguém que a
  alcance, e o teste do fecho de imports afirma isso.
- **Não compôs as oito folhas de Casca de 18–19/08.** Ver §1.2.
- **Não montou `EscopoVip` na raiz.** `PortaoVip`/`AcessoVip` existem e não são
  montados em lugar nenhum — o gate VIP de saguão e configuração de mesa
  continua sem dono na árvore. É a ligação seguinte, e é de enforcement, não de
  Loja: a Loja **exibe** o direito, não o **concede**.
- **Não desbloqueou a compra de verdade.** `master_vip` continua não existindo
  na Play Console, então `CatalogoBilling.oficial` continua vazio e a vitrine
  abre dizendo que não há planos. Esse bloqueio é externo e não é executável por
  agente — ver `docs/PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md`.
