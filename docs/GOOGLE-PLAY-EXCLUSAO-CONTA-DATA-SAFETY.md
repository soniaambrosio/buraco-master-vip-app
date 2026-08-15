# Google Play — Exclusão de Conta e Data Safety

Guia de preenchimento do Play Console para o **Buraco Master VIP**
(`io.github.soniaambrosio.buracomastervip`).

Este documento **não altera o Play Console**. Ele existe para que o
preenchimento seja uma transcrição de respostas já decididas e conferíveis, e
não uma sequência de decisões tomadas na hora, dentro de um formulário, sem o
código à vista.

Cada resposta aqui aponta para **onde ela é verdadeira no repositório**. Se uma
resposta e o código divergirem, é a resposta que está errada.

---

## 0. Estado desta conformidade, em uma frase

> Implementação de conformidade pronta para publicação; a conformidade externa
> ainda depende da publicação da URL e do preenchimento/validação no Play
> Console.

Enquanto a página não estiver publicada e o campo do Play Console não estiver
preenchido, **não é correto dizer que o aplicativo está em conformidade** com a
exigência de exclusão de conta da Google Play. O que está pronto é o lado que
depende de código.

---

## 1. O aplicativo permite criar conta?

**Sim.** O acesso é feito com Conta do Google (`google_sign_in` +
`GoogleAuthProvider`, em `app/lib/main.dart`), e a sessão é uma conta do Firebase
Authentication. Não há modo anônimo nem login por e-mail e senha.

Consequência: a Google Play exige **dois** caminhos de exclusão — um dentro do
aplicativo e um recurso web externo. Os dois existem, e estão descritos abaixo.

---

## 2. Caminho de exclusão DENTRO do aplicativo

| | |
|---|---|
| Onde fica | **Configurações → Excluir minha conta** |
| Tela | `app/lib/screens/excluir_conta_screen.dart` |
| Fluxo | `app/lib/conta/controlador_exclusao.dart` |
| Backend | `functions-conta` — `resumirExclusaoDeConta`, `excluirMinhaConta` |

Portões, na ordem: autenticação → reautenticação recente (claim `auth_time`) →
confirmação digitando a palavra `EXCLUIR`. Nenhum deles foi afrouxado por esta
OS.

**Como descrever no formulário:** "Settings → Delete my account", a partir da
tela inicial do aplicativo, com o usuário autenticado.

---

## 3. Caminho de exclusão FORA do aplicativo (recurso web)

| | |
|---|---|
| Arquivo | `web/exclusao-de-conta/index.html` |
| URL planejada | `https://buraco-master-vip.web.app/exclusao-de-conta` |
| Hospedagem | Firebase Hosting do projeto `buraco-master-vip` (bloco `hosting` em `firebase.json`) |
| Publicada? | **Não.** A OS que a criou proíbe deploy. |

### Como o usuário inicia o pedido fora do aplicativo

1. Abre a URL — **sem instalar e sem abrir o aplicativo**.
2. Clica em *Entrar com o Google* e escolhe a mesma conta que usa no jogo.
3. Vê o resumo do que acontece com cada dado, vindo do servidor.
4. Digita `EXCLUIR` e confirma.
5. A conta é excluída **na hora**.

### Por que esta página não é uma segunda implementação da exclusão

Ela não decide nada. Chama as **mesmas duas Cloud Functions** que o aplicativo
chama, com o mesmo payload e sem alvo. Matriz de retenção, ordem das etapas,
idempotência, retomada e exclusão do Firebase Authentication continuam morando
em `functions-conta/`, num lugar só.

Consequência prática: uma coleção acrescentada ao backend aparece no aviso da
página sem ninguém editar o HTML.

### Como a identidade é verificada

Pelo **ID token do Firebase Authentication**, cuja assinatura a Cloud Function
verifica antes de qualquer código do projeto rodar. O login por popup é feito
no momento do pedido, então o claim `auth_time` é recente e satisfaz o portão de
reautenticação do servidor.

O provedor é chamado com `prompt: select_account` para evitar o pior engano
possível desta página: entrar em silêncio com outra conta Google já logada no
navegador e excluir o perfil errado.

### Como se impede a exclusão de terceiro

Em três camadas, e a primeira delas é a ausência de uma coisa:

1. **Não existe campo de alvo.** A página não tem entrada de UID, de e-mail-alvo
   nem de código de jogador. Não há o que digitar.
2. **O payload vai sem alvo.** As duas chamadas enviam `{}` ou
   `{ confirmacao }`.
3. **O servidor recusa alvo.** `recusarAlvoExterno`
   (`functions-conta/src/index.ts`) responde `permission-denied` se o payload
   trouxer `uid`, `userId` ou `publicId` — recusa, e não ignora em silêncio,
   para que a tentativa fique registrada com o autor identificado.

### Segredos

Não há. A configuração do Firebase vem de `/__/firebase/init.js`, servido pelo
próprio Hosting — nem `apiKey`, nem `appId`, nem `projectId` estão escritos
neste repositório. A única chave prevista no HTML é a **chave de site do
reCAPTCHA** do App Check, que é pública por natureza e ainda não existe (ver §7).

### Quem não consegue mais entrar na conta Google

A página orienta a escrever para o suporte a partir do endereço da conta, e a
recuperar o acesso para então concluir a exclusão. **Não existe, e não deve
existir, um caminho que apague uma conta a partir de um nome, apelido ou código
informado por quem escreve** — seria entregar a qualquer pessoa o poder de
apagar a conta de outra. Ver a pendência em §8.

---

## 4. Política de Privacidade

| | |
|---|---|
| Arquivo | `web/politica-de-privacidade/index.html` |
| URL planejada | `https://buraco-master-vip.web.app/politica-de-privacidade` |
| Existia antes? | **Não.** Esta é a primeira do projeto. |

A política foi escrita a partir de `functions-conta/src/inventario.ts`, e a
seção 7 espelha as quatro classes da matriz, uma a uma.

**Onde cada exigência do Data Safety está declarada:**

| Exigência | Seção da política |
|---|---|
| Que dados são coletados | 3 |
| Para que são usados | 4 |
| Com quem são compartilhados | 5 |
| Como pedir a exclusão | 6 |
| O que é apagado | 7.1 |
| O que é anonimizado | 7.2 |
| O que é desvinculado | 7.3 |
| O que é retido e por quê | 7.4 |
| Por quanto tempo | 8 |
| Direitos do titular | 9 |

---

## 5. Respostas do formulário de Data Safety

### 5.1 Exclusão de conta

| Campo | Resposta |
|---|---|
| O app permite criar conta? | **Sim** |
| Oferece exclusão de conta no app? | **Sim** — Configurações → Excluir minha conta |
| URL para solicitar exclusão de conta | `https://buraco-master-vip.web.app/exclusao-de-conta` |
| Alguns dados são retidos após a exclusão? | **Sim** |
| Motivo da retenção | Integridade competitiva de partidas com outros jogadores; consistência de transações financeiras estornáveis; moderação e histórico disciplinar; antifraude; trilhas de auditoria; barreiras de idempotência |
| Onde a retenção está declarada | Política de Privacidade, seção 7.4 |
| A exclusão exige reinstalar ou abrir o app? | **Não** |

### 5.2 Categorias de dados — o que acontece na exclusão

Derivado de `functions-conta/src/inventario.ts`. A coluna "destino" usa as
classes da matriz.

| Categoria de dados (vocabulário do Data Safety) | Destino |
|---|---|
| Nome, e-mail, IDs de usuário (conta de autenticação) | **Apagado** |
| Perfil privado e preferências | **Apagado** |
| Fotos/avatar e apelido no perfil público | **Anonimizado** (rótulo neutro; perfil fica indisponível) |
| Contatos no app (amizades e solicitações) | **Apagado**, inclusive a cópia do lado da outra pessoa |
| Listas de bloqueio e silenciamento | **Apagado**, nos dois sentidos |
| Atividade no app — histórico pessoal de partidas | **Apagado** |
| Atividade no app — partidas e eventos de mesa | **Retido** (registro compartilhado de 4 jogadores) |
| Atividade no app — classificação e lançamentos | Apresentação **anonimizada**; lançamentos **retidos** |
| Atividade no app — torneios (inscrição, histórico, premiação) | **Retido** |
| Informações de compra | **Desvinculado** (transação permanece; vínculo com a conta é cortado) |
| Token interno da compra | **Apagado** |
| Itens, coleções, carteira de fichas | **Apagado** |
| Denúncias, sanções, estado de moderação | **Retido** |
| Sinais antifraude | **Retido** |
| Trilhas administrativas | **Retido** |

### 5.3 Pagamentos

O app **não coleta** dados de cartão ou meio de pagamento. A compra acontece
inteiramente dentro da Google Play; o backend recebe do Google a confirmação e
guarda o registro da transação.

### 5.4 Assinatura

A exclusão da conta **não cancela** a assinatura na Google Play, e isso é dito
em três lugares: na tela de exclusão do app, na página web e na política (§6).
O app oferece o caminho para gerenciar a assinatura na loja, e **não exige** o
cancelamento para permitir a exclusão.

---

## 6. Onde a assinatura é gerenciada, no aplicativo

| | |
|---|---|
| Onde aparece | Tela de exclusão de conta, dentro do aviso "Antes de continuar" |
| Quando aparece | Quando há assinatura vigente **ou** ainda registrada na Google Play (em espera, pausada, pendente) |
| Quando **não** aparece | Quem nunca assinou, ou cuja assinatura expirou/foi revogada/estornada |
| Destino | Deep link `.../store/account/subscriptions?sku=<produtoId>&package=<pacote>` quando o produto é confiável; a central geral de assinaturas em qualquer outro caso |
| Módulo | `app/lib/billing/gerenciar_assinatura.dart` |

Regras respeitadas, e provadas na suíte:

- não cancela nada, nem pelo cliente nem pelo backend;
- não bloqueia a exclusão;
- tocar na ação **não executa** a exclusão;
- falha ao abrir a loja não trava o fluxo nem vira erro da exclusão.

---

## 7. O que ainda precisa ser feito à mão

### 7.1 Entradas externas da proprietária do aplicativo

Declaradas em `web/PENDENCIAS-EXTERNAS.json`, com a suíte conferindo que
nenhuma foi esquecida no HTML e que nenhuma foi inventada:

| Marcador | O que é |
|---|---|
| `NOME_DO_DESENVOLVEDOR` | Nome exato da listagem da Play |
| `EMAIL_DE_SUPORTE` | Canal de contato publicado |
| `IDENTIFICACAO_DO_CONTROLADOR` | Quem responde juridicamente pelos dados |
| `DATA_DE_VIGENCIA` | Data em que a política passa a valer |
| `PRAZOS_DE_RETENCAO` | Duração da conservação dos registros retidos |
| `IDADE_MINIMA` | Idade mínima declarada |

### 7.2 Console do Firebase (antes do deploy)

1. Registrar o app **web** no App Check e obter a chave de site do reCAPTCHA v3
   (`RECAPTCHA_SITE_KEY_WEB`). Sem ela, a página publicada recebe recusa do
   servidor: as duas callables rodam com `enforceAppCheck: true`.
2. Autorizar o domínio do Hosting em *Authentication → Settings → Authorized
   domains*, senão `signInWithPopup` recusa a origem.
3. Confirmar que existe cliente OAuth de tipo **Web** para o provedor Google.
4. Confirmar que a versão do SDK nos caminhos `/__/firebase/<versão>/` responde
   200 no site publicado.

### 7.3 Deploy

```bash
firebase deploy --only hosting
```

Proibido pela OS que criou estes arquivos. Só faz sentido depois de 7.1 e 7.2.

### 7.4 Play Console

1. Preencher a URL de exclusão de conta (§5.1).
2. Preencher a URL da Política de Privacidade.
3. Preencher o formulário de Data Safety com as respostas de §5.2.
4. Confirmar que o **nome do desenvolvedor** na listagem é o mesmo escrito nas
   duas páginas.

---

## 8. Pendências, separadas por natureza

### Bloqueador de código

**Não há caminho administrativo de exclusão, e esta OS não o criou.**

- **Comportamento atual:** `excluirMinhaConta` age exclusivamente sobre
  `req.auth.uid`. Não existe rota pela qual o suporte execute a exclusão em nome
  de alguém.
- **Consequência:** quem perdeu o acesso à conta Google **não consegue**
  concluir a exclusão; o suporte só pode ajudar a recuperar o acesso.
- **Por que ficou assim:** criar essa rota é uma decisão de arquitetura que
  acrescenta uma segunda porta à autoridade da exclusão, e a OS que produziu
  este documento proíbe redesenhar a arquitetura de exclusão e proíbe criar
  endpoint administrativo público.
- **Proposta, quando for decidido:** uma callable restrita ao claim
  `admin == true` (o mesmo gate que `functions-moderacao/src/index.ts` já usa)
  que **reutiliza `executar(uid)`** de `functions-conta/src/executor.ts` — mesma
  matriz, mesmo executor, mesmo diário, mesma idempotência. Uma segunda porta
  para a mesma execução, e não uma segunda execução. Exigiria também um
  procedimento documentado de verificação de identidade fora do produto.
- **Impacto na conformidade Play:** nenhum para o caso comum. A Google exige que
  o usuário consiga **solicitar** a exclusão pela web, e ele consegue — e mais do
  que isso: consegue concluí-la sozinho.

### Bloqueador de deploy

- `RECAPTCHA_SITE_KEY_WEB` ausente (§7.2.1).
- Domínio não autorizado no Authentication (§7.2.2).
- Cliente OAuth web não confirmado (§7.2.3).

### Ação manual no Play Console

Tudo em §7.4.

### Entrada externa da proprietária

Tudo em §7.1.

---

## 9. O que esta OS deliberadamente NÃO mexeu

A matriz de retenção de `functions-conta/src/inventario.ts` está **intacta**.
Nenhuma classificação foi alterada, nenhum caminho foi acrescentado ou removido,
e nenhuma justificativa foi reescrita. As mesmas 81 provas unitárias que
guardavam a matriz continuam guardando-a.

Continuam fora de escopo, como a OS determina: a inscrição ativa em torneio
(o bloqueio permanece), `wallets/{uid}` nas Rules, o produtor de `hallEntries` e
os `fieldOverrides` de `blocks.bloqueadoUid` e `mutes.alvoUid`.
