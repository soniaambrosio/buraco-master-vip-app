# Exclusão de Conta e Dados do Jogador — v1

OS "Exclusão de Conta e Dados do Jogador v1".
Auditoria e implementação sobre a base consolidada em 14–15/08/2026.

Este documento é o fechamento da OS: base, arquitetura, matriz completa de
retenção/exclusão, evidência de teste e o que ficou em aberto.

---

## 1. O que existia antes: nada

A auditoria varreu as seis codebases de Functions (`firebase/functions`,
`functions-billing`, `functions`, `functions-moderacao`, `functions-ranking`,
`functions-social`) e a árvore Flutter inteira. **Não havia exclusão de conta,
nem parcial, nem esboçada.** Zero ocorrências de `deleteUser`,
`recursiveDelete`, `reauthenticate`, `anonimizar` ou equivalentes.

O que havia era **uma menção**, e ela é o ponto de partida desta OS.
`docs/CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md` §15 registrava a lacuna com todas
as letras:

> Exclusão/desativação de conta não existe no projeto. `EstadoPerfilPublico.
> indisponivel` está implementado e testado, mas **nada o escreve**. (…) Quando
> ela existir, basta gravar `estado: "indisponivel"` — a leitura já respeita.

O gancho estava pronto dos dois lados: `app/lib/social/identidade_publica.dart`
já modela `indisponivel` e faz o *parsing* defensivo cair nele; e
`firebase/testes/social.test.js` já prova que "perfil inexistente e perfil
indisponível respondem IGUAL". Esta OS cumpre aquele contrato.

O mais próximo de exclusão, no cliente, era o botão **"Sair da conta"** —
logout, não exclusão.

---

## 2. Base: as duas linhas tiveram de ser consolidadas antes

O repositório tem tudo publicado **sem merge**, e as duas linhas mais recentes
carregam metades diferentes do jogador:

| Linha | HEAD | O que ela tem |
|---|---|---|
| Identidade / Ranking / Social | `claude/identidade-sessao-canonica-flutter` (`3c6eb8d`) | `functions-ranking`, `functions-social`, identidade de sessão no cliente |
| Billing / RTDN | `integracao/play-billing-flutter` (`319bb8f`) | ciclo de vida do VIP, RTDN, cliente Play Billing |

Auditar só uma produziria uma matriz **cega para metade do jogador**: sem a
primeira não se enxerga `publicId`, amizades, temporadas nem ranking; sem a
segunda não se enxerga entitlement, compras nem eventos da Play.

A consolidação foi feita e teve **dois conflitos, ambos de união e nenhum de
semântica**: `firestore.indexes.json` (o índice de vencimento do VIP entrou ao
lado dos de ranking e social) e `firebase/testes/package.json` (`test` e
`test:integrado` passaram a incluir `entitlement.test.js` junto de `social` e
`ranking`).

**Branch:** `claude/player-account-deletion-flow-d04d45`
**Base:** `claude/identidade-sessao-canonica-flutter` + `integracao/play-billing-flutter`

---

## 3. Arquitetura adotada

### 3.1 Codebase próprio: `functions-conta`

Pelo mesmo critério que já separa os cinco existentes — e aqui ele é **mais
forte, não mais fraco**. Este é o único codebase que *escreve* em coleções de
todos os domínios: apaga carteira de torneio, corta titular de compra,
neutraliza linha de ranking, remove bloqueio de moderação.

Hospedá-lo dentro de qualquer um deles inverteria a dependência para o lado
errado: um deploy quebrado da exclusão derrubaria a lista de amigos, ou a
validação de compra. E, na direção que mais importa, **um erro aqui não pode
impedir ninguém de jogar, comprar nem denunciar.**

```
functions-conta/
  src/inventario.ts   ..... A MATRIZ. O que acontece com cada dado, e por quê.
  src/plano.ts ............ A ordem das etapas, e as recusas anteriores a
                            qualquer escrita.
  src/diario.ts ........... A lápide e a decisão de idempotência. Puro.
  src/reautenticacao.ts ... A janela de `auth_time` e a palavra. Puro.
  src/executor.ts ......... Firestore e Authentication. Paginação, lote, retomada.
  src/index.ts ............ As duas callables. Autenticação e tradução de recusa.
```

### 3.2 A matriz é dado, não prosa

`src/inventario.ts` não é documentação que acompanha o código: **é o código.**
`plano.ts` monta a ordem a partir dela, `executor.ts` executa item por item, e
`test/inventario.test.js` **lê `firebase/firestore.rules`** e falha se alguma
coleção declarada lá não estiver classificada aqui.

Essa trava é o motivo principal do desenho. Uma tabela num `.md` envelhece em
silêncio: alguém acrescenta uma coleção, o documento não muda, e a exclusão
passa a deixar rastro sem ninguém perceber. Aqui, acrescentar coleção sem
classificar **quebra a suíte**.

O mesmo teste exige justificativa em todo item (a OS proíbe apagar histórico
"sem justificativa", e um campo obrigatório que aceita string vazia não proíbe
nada), exige `campos` declarados em `ANONIMIZAR` e `DESVINCULAR`, e proíbe que
um item `RETER` declare como ser alcançado — um item retido com consulta
declarada é um acidente esperando alguém acrescentá-lo ao plano.

### 3.3 A doutrina: o corte do vínculo

A OS proíbe apagar cegamente o que quebra integridade competitiva, financeira ou
de moderação. As três quebras são concretas:

* **Competitiva.** Uma partida tem quatro pessoas. O rating que os outros três
  ganharam saiu do resultado contra este jogador.
* **Financeira.** `compras/{hash}` é o único elo entre um `purchaseToken` da
  Google e um titular, e a Play pode estornar meses depois.
* **Moderação.** `firestore.rules` chama `playerModeration/{uid}` de *"o ponto
  exato onde morre a tentativa de apagar a própria punição"*. Uma exclusão que o
  apagasse seria essa tentativa, com outro nome.

Reter registro chaveado por UID só não é reter dado pessoal por causa de uma
propriedade, **produzida ativamente por este fluxo**:

> Depois da exclusão, não existe mais caminho de UID para pessoa.

A conta do Authentication é apagada. O perfil privado, nos **dois** namespaces
(`users/` e `usuarios/`), é apagado. `playerIdentities/{uid}` é apagado.
`publicProfiles/{publicId}` perde apelido e avatar. O que sobra em
`rankingLedger`, `matches` e `sanctions` é uma string opaca que não resolve para
ninguém — pseudônimo sem chave de reversão.

É por isso que a matriz tem tantos `DESVINCULAR`: em vez de apagar o registro
(que quebraria a integridade) ou de mantê-lo intacto (que manteria o vínculo),
corta-se o campo que faz a ponte e preserva-se o fato.

### 3.4 A exceção deliberada: `publicIdIndex` vira lápide

Contra-intuitivo, e é a decisão mais discutível da matriz — por isso está
explícita. O documento **fica**, sem `uid`, marcado como retirado.

Apagar devolveria o `publicId` ao sorteio de `garantirIdentidade` (o `create` só
falha se o id já existir), e um jogador novo poderia receber o código de um que
saiu — herdando, aos olhos de quem lê, as linhas de `rankingStandings`,
`hallEntries` e `rankingLedger` que ainda citam aquele `publicId`. A lápide custa
um documento e impede uma troca de identidade silenciosa.

### 3.5 Execução retomável por diário, e não por transação

A operação toca dezenas de coleções, varre subcoleções de tamanho desconhecido e
chama o Authentication, que **não participa de transação do Firestore**. Uma
tentativa de atomicidade produziria uma transação que estoura limite e falha
sempre nas contas grandes — justamente as que mais têm dado a remover.

A atomicidade é trocada por: **toda etapa é idempotente, e o progresso é
gravado** em `accountDeletions/{uid}`.

A ordem das dez etapas é escolhida para que "se parar aqui, o sistema fica pior?"
tenha sempre a resposta *não*:

| # | Etapa | Por que nesta posição |
|---|---|---|
| 1 | `trancar` | Desabilita a conta e revoga os *refresh tokens*. Sem isso, uma solicitação de amizade aceita no meio recria a projeção que a etapa seguinte apaga. As duas chamadas importam: `disabled` impede autenticação nova, `revokeRefreshTokens` invalida as que já existem. |
| 2 | `social` | Lê `friendships` **antes** de apagar: é de `membros` que saem os UIDs dos amigos, e sem eles os espelhos ficariam inalcançáveis. |
| 3 | `moderacaoDoJogador` | As listas dele e as referências a ele nas listas dos outros. |
| 4 | `rastreabilidadeDoJogador` | Só a projeção pessoal do histórico. |
| 5 | `colecoes` | Inventário, resgates, elegibilidade. |
| 6 | `ranking` | Antes de `identidade`: as linhas competitivas são alcançadas pelo `publicId`. |
| 7 | `billing` | O documento `interno` antes do pai — `delete` no pai não apaga subcoleção. |
| 8 | `identidade` | O corte do vínculo. |
| 9 | `perfil` | Carteira (com o saldo registrado no diário antes de sumir) e documento raiz. |
| 10 | `encerrar` | Apaga o Authentication. **A última escrita, e a única irreversível.** Parada no meio com a conta ainda existindo é retomável; parada com a conta já apagada sobraria dado órfão e ninguém com sessão para pedir de novo. |

### 3.6 Os três portões

| Portão | Pergunta que responde | Como |
|---|---|---|
| Autenticação | "Há alguém logado?" | `req.auth.uid`. **O UID nunca vem do payload** — e um pedido que *traz* `uid`, `userId`, `publicId`, `alvo` ou `alvoUid` é **recusado**, e não ignorado: ignorar produziria o mesmo efeito e esconderia a tentativa. |
| Reautenticação | "Faz pouco tempo que essa pessoa provou que é ela?" | O claim `auth_time`, que é **assinado** e não se falsifica. Janela de 5 minutos, com 60s de folga de relógio. Conferido no servidor porque `reauthenticateWithCredential` do cliente é útil para a experiência e inútil como garantia — um app modificado simplesmente não a chama. |
| Confirmação | "Essa pessoa entendeu o que vai acontecer?" | A palavra `EXCLUIR`, conferida **no servidor**. |

Cada um cobre coisa diferente: um toque acidental passa pelos dois primeiros
(a sessão *é* recente) e para no terceiro; um aparelho desbloqueado e esquecido
para no segundo.

### 3.7 Cliente Flutter

```
app/lib/conta/
  exclusao_de_conta.dart ...... Tipos. Puro: sem Firebase, sem Flutter.
  fonte_exclusao.dart ......... A PORTA. Nenhuma operação recebe uid.
  fonte_exclusao_firebase.dart  O ÚNICO arquivo que conhece cloud_functions.
  controlador_exclusao.dart ... O fluxo inteiro. Não importa firebase_auth.
app/lib/screens/excluir_conta_screen.dart ... Desenha a fase. Sem I/O.
```

**O aviso não é texto escrito no aplicativo.** Ele vem de
`resumirExclusaoDeConta`, derivado da mesma matriz que o executor obedece, e
chega agrupado em quatro listas — o que some, o que fica sem o seu nome, o que
fica sem ligação com você, e **o que é guardado, com a justificativa de cada
linha**. Uma lista escrita à mão no Dart estaria errada no dia em que alguém
acrescentasse uma coleção ao backend.

Duas advertências continuam sendo texto do aplicativo, e estão em
`kAvisosQueNaoVemDaMatriz`, porque não são sobre dados:

1. **A assinatura na Google Play NÃO é cancelada pela exclusão.** Sem esse aviso,
   alguém sai do aplicativo e descobre na fatura seguinte.
2. **Não há desfazer**, e uma conta nova começa do zero.

O controlador recebe `reautenticar` e `encerrarSessao` como funções, e não
importa `firebase_auth`: é o que o mantém testável e o que respeita a auditoria
estrutural de `app/test/sessao/auditoria_identidade_test.dart`, que varre
`lib/screens/` e `lib/pages/` atrás de `cloud_functions`.

A reautenticação é **reativa**: só pedimos a credencial depois de o servidor
dizer que precisa, e repetimos **uma** vez. Um laço viraria pedido de senha
infinito quando a causa for relógio do aparelho fora de hora.

Detalhe do host que parece supérfluo e não é: depois de
`reauthenticateWithCredential`, o ID token em mãos ainda carrega o `auth_time`
**antigo**. Sem `getIdToken(true)`, a chamada seguinte seria recusada de novo e o
jogador veria o pedido de senha duas vezes seguidas.

---

## 4. Matriz completa de retenção/exclusão

Gerada a partir de `functions-conta/src/inventario.ts` — se as duas divergirem, a
fonte é o código, e `test/inventario.test.js` é quem percebe.

| Classe | Itens |
|---|---|
| APAGAR | 33 |
| RETER | 21 |
| DESVINCULAR | 8 |
| ANONIMIZAR | 4 |
| NAO_APLICAVEL | 11 |

Total: 77 caminhos classificados.

> A contagem acima estava **congelada em 61** desde o fechamento da OS v1 e não
> acompanhou as coleções que chegaram depois (Mesas, Economia, Passe de
> Cortesia, a composição canônica e, agora, `chatRitmo`). Foi corrigida aqui.
> A fonte continua sendo `functions-conta/src/inventario.ts`: quando este número
> divergir de novo, é a prosa que está errada.

### Autenticação

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `FirebaseAuth/{uid}` | **APAGAR** | — | E a conta em si: e-mail, telefone, provedor e nome vindo do provedor. E TAMBEM a chave que torna todo o resto reversivel — enquanto ela existe, um UID em `rankingLedger` volta a ser uma pessoa. Apagada por ULTIMO de proposito (ver plano.ts): se fosse primeiro, uma falha no meio deixaria dado orfao e o jogador sem sessao para pedir de novo. |

### Conta / perfil

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `accountDeletions/{uid}` | **RETER** | — | A lapide. Guarda o que foi feito, quando, e o resumo do que existia (saldo de fichas, VIP ativo) para o suporte responder 'sim, esta conta foi excluida a pedido, nesta data'. Nao carrega apelido, e-mail nem avatar. E tambem a barreira de idempotencia: e a leitura dele que faz a segunda chamada convergir em vez de refazer tudo. |
| `users/{uid}` | **APAGAR** | — | O documento raiz. Nenhuma Function deste repositorio o escreve hoje — ele existe como PAI das oito subcolecoes — mas apaga-lo e barato e fecha a porta para um campo gravado por fora. ATENCAO: apagar o pai NAO apaga as subcolecoes no Firestore; e por isso que cada uma delas tem item proprio nesta matriz, e nao uma linha 'users e tudo abaixo'. |

### Identidade pública

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `playerIdentities/{uid}` | **APAGAR** | — | E o mapa uid -> publicId. E metade da ponte que o corte de vinculo precisa derrubar: sem ele, ninguem parte de um UID retido e chega ao perfil. |
| `publicIdIndex/{publicId}` | **DESVINCULAR** | `uid` | CONTRA-INTUITIVO, E DELIBERADO: o documento FICA, sem `uid`, marcado como retirado. Apagar devolveria o publicId ao sorteio de `garantirIdentidade` (o `create` so falha se o id existir), e um jogador novo poderia receber o codigo de um que saiu — herdando, aos olhos de quem le, as linhas de `rankingStandings`, `hallEntries` e `rankingLedger` que ainda citam aquele publicId. A lapide custa um documento e impede uma troca de identidade silenciosa. |
| `publicProfiles/{publicId}` | **ANONIMIZAR** | `apelido`, `apelidoOrdenacao`, `avatarRef`, `estado` | Apelido e avatar sao a PESSOA e saem. O documento fica porque e a fonte de apresentacao que ranking e hall projetam, e porque `estado: indisponivel` e exatamente o gancho que o contrato de identidade publica deixou reservado para esta OS. Apagar faria `verPerfilPublico` responder `not-found` — que ja e a mesma resposta de conta inexistente, entao nao ha ganho de privacidade em apagar, e ha perda de rotulo nas linhas historicas. |

### Grafo social

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `friendships/{pairKey}` | **APAGAR** | — | A relacao canonica. Uma amizade e um vinculo entre duas contas vivas; morta uma, o vinculo nao descreve mais nada. O documento carrega `membros`, `solicitanteUid` e `destinatarioUid` — tres UIDs — entao mante-lo seria manter o UID do excluido dentro do dado de OUTRA pessoa. |
| `users/{uid}/friends/{outroUid}` | **APAGAR** | — | Projecao da lista de amigos do proprio jogador. Deriva de `friendships`, que sai junto. |
| `users/{outroUid}/friends/{uid}` | **APAGAR** | — | O ESPELHO, e ele e o item que uma exclusao ingenua esquece. O UID do excluido e o ID DO DOCUMENTO na lista do amigo: apagar so o lado dele deixaria o amigo com uma linha que aponta para uma conta que nao existe — e com o UID dela na chave. Alcancado sem varredura: os UIDs do outro lado vem de `friendships.membros`, ja carregado na etapa anterior. |
| `users/{uid}/friendRequests/{outroUid}` | **APAGAR** | — | Projecao das solicitacoes do proprio jogador. Mesma derivacao de `friends`. |
| `users/{outroUid}/friendRequests/{uid}` | **APAGAR** | — | O espelho da solicitacao pendente. Sem isto, o outro jogador ficaria com um convite eterno de alguem que nao existe, sem botao que resolva: aceitar chamaria uma Function que nao acha a contraparte. |
| `playerSocial/{uid}` | **APAGAR** | — | Contadores derivados (amigos, solicitacoes enviadas). Sem relacoes, nao contam nada. |

### Moderação

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `users/{uid}/blocks/{alvoUid}` | **APAGAR** | — | A lista de quem ESTE jogador bloqueou. E preferencia de protecao dele, e carrega os UIDs de terceiros; sem conta, nao protege ninguem. |
| `users/{outroUid}/blocks/{uid}` | **APAGAR** | — | Bloqueios que OUTROS fizeram contra o excluido. Ficam orfaos: a conta bloqueada nao pode mais convidar, chamar nem escrever, porque nao existe. Apagar tira o UID do excluido de dentro da conta de terceiros, e limpa o fantasma da tela 'Jogadores bloqueados' do outro. Consulta collection-group pelo campo `bloqueadoUid`, que a Function de bloqueio ja grava redundantemente — o `fieldOverrides` correspondente foi declarado em firebase/firestore.indexes.json por esta OS. |
| `users/{uid}/mutes/{alvoUid}` | **APAGAR** | — | Silenciamentos configurados por ele. Preferencia de exibicao, sem efeito sobre terceiros. |
| `users/{outroUid}/mutes/{uid}` | **APAGAR** | — | Mesmo raciocinio do bloqueio espelhado: e o UID do excluido dentro da conta de outra pessoa, silenciando alguem que nao fala mais. |
| `reports/{denuncianteUid\|reportIntentId}` | **RETER** | — | INTEGRIDADE DE MODERACAO, nos dois sentidos. As denuncias que ELE fez sao processos abertos contra terceiros: apaga-las derrubaria casos que nao sao dele. As que ELE sofreu sao a base das sancoes aplicadas: apaga-las apagaria o fundamento do historico disciplinar. O UID esta na chave e nos campos, e permanece — orfao, depois do corte de vinculo. |
| `users/{uid}/reportReceipts/{reportId}` | **APAGAR** | — | O COMPROVANTE e a copia pessoal do denunciante — protocolo e status, para ele acompanhar. O registro administrativo fica em `reports`, que e retido. Apagar o comprovante nao perde informacao nenhuma: perde a comodidade de quem nao existe mais. |
| `sanctions/{sancaoId}` | **RETER** | — | O historico disciplinar. A propria colecao ja e desenhada para nunca ser apagada — revogar grava `revogada`, nao deleta. Deixar a exclusao de conta apaga-la abriria o caminho de limpeza de ficha que `firestore.rules` recusa explicitamente ao dono. |
| `playerModeration/{uid}` | **RETER** | — | O efeito consolidado (silenciado ate, suspenso ate, permanente). E O PONTO EXATO que firebase/firestore.rules descreve como 'onde morre a tentativa de apagar a propria punicao'. Uma exclusao que o apagasse seria essa tentativa, com outro nome. Fica, e o UID que o chaveia ja nao resolve para pessoa nenhuma. |
| `moderationAudit/{eventoId}` | **RETER** | — | Trilha administrativa. Por desenho, nem o admin apaga — 'para que a trilha nao possa ser limpa por quem a gerou'. |
| `moderationTasks/{chaveTarefa}` | **RETER** | — | Barreira de idempotencia. Apagar reabriria intencoes ja gastas — uma denuncia repetida com o mesmo intent id voltaria a ser aceita. O ganho de privacidade seria zero; o custo, uma porta de reprocessamento. |
| `chatChannels/{canalId}` | **DESVINCULAR** | `participantes` | O CANAL É DA MESA, e a mesa é de mais gente. Sai o UID de `participantes`; o canal continua enquanto tiver finalidade compartilhada. |
| `chatMessages/{messageId}` | **APAGAR** | — | Mensagem comum não é registro compartilhado: é fala de UMA pessoa. As dos outros participantes permanecem, porque a consulta é por `autorUid`. |
| `chatRitmo/{uid}` | **APAGAR** | — | CONTADOR DE RAJADA, e não ficha disciplinar. Guarda `recentes` (instante e id de item — nunca conteúdo), `bloqueadoAteMs` e `recusasSeguidas`; o horizonte de decisão são dois minutos e o freio máximo dura dois minutos. Ver §4.1. |

#### 4.1 `chatRitmo/{uid}` — por que APAGAR, e não RETER (OS 48)

A coleção nasceu com a **Comunicação Controlada V1**, depois desta matriz, e
por um período foi a única coleção declarada em `firebase/firestore.rules` sem
destino aqui — o estado que `test/inventario.test.js` existe para denunciar, e
que ele denunciou.

**O que o documento guarda.** Três campos, e nenhum a mais
(`EstadoDeRitmo.toJson`, em `app/lib/comunicacao/limites.dart`):

| Campo | O que é | Vida útil |
|---|---|---|
| `recentes[]` | `{emMs, itemId?, categoria?}` de cada envio. **Nunca conteúdo** — o domínio recusa gravá-lo aqui, para não criar uma segunda cópia da mensagem fora do documento dela. | aparado ao `horizonte`: 2 minutos |
| `bloqueadoAteMs` | Instante em que o freio automático solta. | `bloqueioPorAbuso` = 2 minutos |
| `recusasSeguidas` | Recusas de ritmo seguidas; zera a cada envio aceito. | até o próximo aceite |

Identidade, só pela **chave**: não há apelido, avatar, `publicId` nem e-mail.

**Quem escreve e quem lê.** Um produtor e um consumidor, os dois em
`functions-moderacao/src/index.ts`: `executarEnvioDeMensagem` grava (nos dois
desfechos — sem isso, uma rajada de pedidos recusados não contaria como abuso)
e `lerRitmo` lê. Para o cliente, `firestore.rules` nega **leitura e escrita**.
`functions-conta` não a tocava.

**A decisão: `APAGAR`.** As três alternativas foram consideradas:

- **RETER** seria a leitura errada mais provável, e ela tem uma razão de
  parecer certa: o documento guarda um *bloqueio*, e a doutrina desta matriz
  retém `playerModeration`, `sanctions`, `reports` e `moderationAudit`
  justamente para que a exclusão de conta não seja o botão de limpar ficha que
  `firestore.rules` recusa ao dono. **Só que o freio não é nenhuma das quatro.**
  As duas fontes dizem isso por escrito, e antes desta OS: o campo
  `bloqueadoAteMs` é documentado como *"ISTO NÃO É SANÇÃO. Sanção é decisão de
  moderação, tem responsável, motivo e trilha. Isto é um freio automático de
  minutos, sem julgamento e sem registro disciplinar"*, e o bloco `chatRitmo`
  das regras separa a coleção de `playerModeration` pelo mesmo motivo. Apagar o
  contador **não apaga punição nenhuma**: os quatro registros disciplinares
  continuam RETIDOS e não dependem dele — a evidência de uma denúncia é
  *copiada* para o registro dela, por desenho (§7.5 da Comunicação Controlada).
  E não há evasão a comprar: excluir a conta destrói o acesso, o que custa
  infinitamente mais do que esperar dois minutos.
- **ANONIMIZAR** não se aplica: não há campo de rosto a substituir. O único
  dado de pessoa é a chave, e trocar a chave é criar outro documento.
- **DESVINCULAR** não corta nada, pela mesma razão: a ponte para a identidade
  **é** a chave, e a classe existe para cortar um campo preservando o fato.

**Por que reter seria pior do que inútil.** Não há TTL sobre esta coleção — o
`expiraEm` da §7.5 da Comunicação Controlada é de `chatMessages`, não daqui. Um
documento retido ficaria para sempre guardando o padrão de envio de dois
minutos de uma conta que não existe mais, sem ninguém que volte a lê-lo: o
único leitor de produto é `lerRitmo`, e ele só é chamado com `req.auth.uid` de
conta viva.

**Recriação de conta.** O UID do Authentication não é reciclado, então uma conta
nova nunca herdaria a chave. Ainda assim o efeito é provado por construção: com
o documento apagado, não existe `bloqueadoAteMs` a herdar, e documento ausente é
exatamente o estado de quem nunca falou (`EstadoDeRitmo.fromJson` devolve estado
vazio para ausência **e** para dado ilegível — dado que não existe não
restringe).

**Onde a decisão vive.** Item `moderacao.ritmoDeChat` (`docPorUid`), etapa
`moderacaoDoJogador`, executado por último entre os itens de chat — as varreduras
de mensagem podem demorar, e o produtor grava nos dois desfechos de uma chamada
em voo, então apagar o contador antes delas alargaria a janela.

**O que esta OS não fez, de propósito:** nada da política funcional do chat
mudou. Nenhum limite, nenhum cooldown, nenhuma rota, nenhuma regra do Firestore,
nenhuma tela. A correção é inteiramente do lado da autoridade de exclusão.

---
### Rastreabilidade de partidas

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `matches/{matchId}` | **RETER** | — | INTEGRIDADE COMPETITIVA. A partida e de quatro pessoas, nao de uma. Apagar (ou tirar um competidor de `userIdsCompetidores`) mudaria o registro dos outros tres e quebraria a reconstrucao de historico que a rastreabilidade existe para permitir. |
| `matches/{matchId}/events/{eventId}` | **RETER** | — | Trilha de eventos da mesa. Mesmo motivo da partida: e o registro compartilhado de quem jogou junto. |
| `users/{uid}/matchHistory/{matchId}` | **APAGAR** | — | E a VISAO DO JOGADOR — projecao pessoal de `matches`, com as contagens dele. O registro tecnico fica; a copia pessoal sai. Nada se perde: a projecao e reconstrutivel a partir do canonico. |
| `rankingLedger/{matchId\|userId\|motivo}` | **RETER** | — | O extrato antes/delta/depois. E a prova de POR QUE cada pontuacao e o que e — inclusive a dos adversarios. Apagar os lancamentos de um jogador deixaria a cadeia dos outros com um degrau sem origem. |
| `fraudSignals/{chaveIdempotencia}` | **RETER** | — | Sinais antifraude citam VARIOS alvos por documento (conluio e coletivo). Apagar por causa de um citado destruiria a suspeita sobre os outros — e transformaria 'excluir a conta' na forma mais barata de sumir com o rastro de um esquema. Sinal nao e veredito e nao pune ninguem; reter e o comportamento conservador correto. |

### Ranking, Ligas e Temporadas

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `rankingStandings/{seasonId\|uid}` | **ANONIMIZAR** | `apelido`, `avatar` | A LINHA FICA, O ROSTO SAI. Apagar reescreveria a classificacao de temporadas encerradas — quem ficou em terceiro passaria a segundo por um motivo que nao aconteceu na mesa. `apelido` e `avatar` sao projecao de `publicProfiles` e viram o rotulo neutro; `uid` e `publicPlayerId` permanecem porque sao a chave da linha (o id do documento e `seasonId\|uid`, e nao ha como cortar o campo sem inutilizar o proprio documento). NAO HA CONSULTA POR UID nesta colecao — as chaves sao remontadas varrendo `rankingSeasons`, que e pequena e finita. |
| `rankingPlayers/{uid}` | **ANONIMIZAR** | `apelido`, `avatar` | O agregado de vida inteira, que sustenta a aba global. Mesmo raciocinio do standing: apagar mexeria na ordem de quem ficou. Chaveado por UID, entao a linha e retida com a apresentacao neutralizada. |
| `rankingContributions/{chaveIdempotencia}` | **RETER** | — | A prova de que uma partida ja foi processada, com os deltas de TODOS os jogadores dela. E o que impede a mesma partida de pontuar duas vezes num reprocessamento. Apagar reabriria a dupla contagem para os adversarios. |
| `rankingBacklog/{matchId}` | **RETER** | — | Fila de partidas a reprocessar quando a formula existir. O documento e da PARTIDA, nao do jogador, e a ordem cronologica dele e o que faz o Elo (nao comutativo) chegar ao mesmo resultado. |
| `rankingAudit/{eventoId}` | **RETER** | — | Trilha. O UID que ela carrega e o do ADMIN que operou, nao o do jogador excluido. |
| `rankingTasks/{chaveTarefa}` | **RETER** | — | Idempotencia administrativa. Mesmo motivo de `moderationTasks`. |
| `rankingSeasons/{seasonId}` | **NAO_APLICAVEL** | — | Configuracao de temporada. Guarda contagem de classificados, nunca quem. E, ao mesmo tempo, a FONTE das chaves de `rankingStandings` — lida, nunca escrita, por esta OS. |
| `rankingLadders/{ladderId}` | **NAO_APLICAVEL** | — | Escada de Ligas — as faixas de rating que definem Bronze a Imortal. Configuracao competitiva pura: descreve o sistema, nunca um jogador. Conferido item a item; nao ha campo de pessoa aqui. |
| `hallEntries/{chave}` | **ANONIMIZAR** | `apelido`, `avatar` | O Hall e memoria: quem venceu uma temporada venceu. Apagar reescreveria o passado; o rotulo neutro preserva o fato sem o rosto. NOTA DE ESTADO: nenhuma Function deste repositorio escreve `hallEntries` hoje (a colecao existe nas regras e nao tem produtor), entao a consulta tende a nao achar nada — e esta linha e o que garante que ela seja tratada no dia em que o produtor aparecer. |

### Torneios

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `tournaments/{t}/editions/{e}/registrations/{uid}` | **RETER** | — | A inscricao e o fato de ter participado de uma edicao, e ela sustenta a classificacao e a premiacao dos outros inscritos. RESSALVA QUE ESTA OS NAO RESOLVE, e registra: se a edicao ainda NAO encerrou, a inscricao de uma conta morta continua ocupando vaga. Cancelar exigiria reproduzir a regra de `cancelarInscricaoTorneio` (devolucao de fichas, convocacao da lista de espera) dentro deste codebase, que e duplicacao de regra competitiva — e a OS proibe alterar regra competitiva. O bloqueio esta na porta: `plano.ts` RECUSA a exclusao enquanto houver inscricao ativa em edicao nao encerrada, e manda o jogador cancelar pelo fluxo proprio. |
| `tournamentHistory/{registroId}` | **RETER** | — | Snapshot congelado de uma edicao concluida, com `participantesUserIds` e `campeoes`. Mexer aqui reescreveria o resultado de um torneio inteiro por causa de um participante. |
| `rewardGrants/{chaveIdempotencia}` | **RETER** | — | Concessao de premio: e registro economico e e idempotencia ao mesmo tempo. Apagar reabriria a possibilidade de a mesma premiacao ser concedida de novo num reprocessamento da edicao. |
| `annualQualifications/{registroId}` | **RETER** | — | O fato da classificacao anual. Sustenta a lista de excedentes e a consolidacao de convites dos OUTROS. |
| `closingInvites/{chaveIdempotencia}` | **RETER** | — | O convite de encerramento e um direito emitido, contado na lotacao da edicao final. Apagar mudaria a contagem administrativa de uma temporada ja consolidada. |
| `tournamentTasks/{chaveTarefa}` | **NAO_APLICAVEL** | — | Idempotencia do agendador. O `alvo` e a fase, nao o jogador — conferido, nao ha UID aqui. |
| `tournamentAudit/{eventoId}` | **NAO_APLICAVEL** | — | Trilha do motor. O ator e 'sistema' — conferido, nao ha UID aqui. |
| `wallets/{uid}` | **APAGAR** | — | A CARTEIRA DE FICHAS. Saldo e intransferivel e morre com a conta — nao ha para quem devolver depois que o titular pede para sair. O saldo do momento do encerramento vai gravado no diario (`accountDeletions`), que e o que permite ao suporte responder a um pedido de estorno posterior sem manter a carteira viva. NOTA: `wallets` nao e declarada em firestore.rules e cai no fecho `if false` — invisivel ao cliente, escrita so pelo Admin SDK. |
| `tournaments/{t}/editions/{e}/{tables\|results\|standings\|conclusion\|phases}` | **RETER** | — | Mesas, resultados, classificacao e desfecho de uma edicao. Carregam `participanteId` (que em dupla e `uidA+uidB`) e `campeoes`. Sao o registro compartilhado da competicao; nenhum deles descreve so o excluido. Nao ha produtor destes documentos nesta arvore — vem do Motor de Partidas. |
| `tournamentJobs/{chaveIdempotencia}` | **NAO_APLICAVEL** | — | Fila interna do agendador, chaveada por fase. Conferido: nao ha UID. |
| `seeds/{documento}` | **NAO_APLICAVEL** | — | Sementes de catalogo (registro de assets, politicas de premio). Sem dado de pessoa. |
| `tournaments/{tournamentId}` | **NAO_APLICAVEL** | — | Configuracao do torneio e das edicoes. Sem dado de pessoa. |

### Billing

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `playerEntitlements/{uid}` | **APAGAR** | — | O DIREITO VIP e da conta e morre com ela. Guardar um entitlement ativo de uma conta inexistente so criaria um estado que a reconciliacao teria de tratar para sempre. O que a compra teve de fato fica em `compras`, que e retido. |
| `playerEntitlements/{uid}/interno/billing` | **APAGAR** | — | O DOCUMENTO MAIS SENSIVEL DO BANCO: carrega o `purchaseToken` EM CLARO. Apagar e obrigatorio, e apagar EXPLICITAMENTE tambem: um `delete` no documento pai NAO apaga subcolecao no Firestore, e confiar nisso deixaria o token vivo depois de a conta ter sumido. |
| `compras/{sha256(purchaseToken)}` | **DESVINCULAR** | `uid` | INTEGRIDADE FINANCEIRA. O registro fica: houve uma transacao real, com valor real, que a Play pode estornar meses depois. O `uid` sai, e o efeito e exatamente o desejado — `titularDoToken` passa a responder `registro_sem_uid` e o RTDN daquela assinatura e DESCARTADO em vez de conceder direito a um fantasma. O comportamento seguro ja existia no billing; esta OS so o aciona. |
| `billingEvents/{messageId}` | **DESVINCULAR** | `uid` | Trilha de notificacoes da Play, e barreira contra reentrega do Pub/Sub. O evento fica (apagar faria uma reentrega ser reprocessada); o `uid` sai. O documento ja guarda so um rotulo curto do hash do token, nunca o token. |
| `usuarios/{uid}` | **APAGAR** | — | O PERFIL PRIVADO no namespace legado do Billing — e um namespace DIFERENTE de `users/`, e os dois estao vivos. Guarda fichas e os campos VIP historicos. Uma exclusao que varresse so `users/` deixaria este documento inteiro para tras, com o perfil do jogador dentro. |
| `configuracao/{documento}` | **NAO_APLICAVEL** | — | Configuracao do billing (pacote do app, chaves de produto). Sem dado de pessoa. |

### Coleções / Kit Pioneiros

| Caminho | Classe | Campos afetados | Justificativa |
|---|---|---|---|
| `users/{uid}/inventory/{itemId}` | **APAGAR** | — | Vitrine e itens cosmeticos do jogador. Sem valor fora da conta, e sem efeito sobre terceiros. |
| `users/{uid}/campaign_claims/{campaignId}` | **APAGAR** | — | Comprovante de resgate do Kit Pioneiros. E a idempotencia do resgate DAQUELE UID — e o UID nao volta a existir, entao nao ha resgate a repetir. O fato administrativo (quem resgatou, quando) fica em `audit`, que e retido. |
| `campaigns/{campaignId}/eligible/{uid}` | **APAGAR** | — | Elegibilidade concedida a este UID. Chaveada por UID dentro da campanha — e mais um lugar onde o UID do excluido sobreviveria fora de `users/`. Apagar nao permite nada a ninguem: uma conta nova tem UID novo e precisa de concessao nova. ALCANCADA POR CHAVE DERIVADA, e nao por consulta: o documento NAO tem campo `uid` (so `concessaoAdministrativa`, `concedidaPor` e `concedidaEm`), entao nao ha por onde filtrar — a chave e remontada varrendo `campaigns`, que e uma colecao de configuracao pequena. |
| `audit/{registroId}` | **RETER** | — | Trilha de acao administrativa (concessao manual, revogacao). Carrega o UID do admin como `autor` e o do jogador como `alvo`. Por desenho, nem o admin apaga. |
| `campaigns/{campaignId}` | **NAO_APLICAVEL** | — | Definicao da campanha. Sem dado de pessoa. |
| `collections/{collectionId}` | **NAO_APLICAVEL** | — | Catalogo de colecoes e itens. Sem dado de pessoa. |
| `config/{documento}` | **NAO_APLICAVEL** | — | Feature flags do aplicativo, legiveis por qualquer autenticado e escritas so por admin. Conferido campo a campo: descrevem o que esta ligado no produto, nunca quem e o jogador. |


---

## 5. Testes

| Suíte | Alvo | Resultado |
|---|---|---|
| `functions-conta` — unidade (`npm test`) | matriz, plano, diário, reautenticação, provas estruturais | **92 passam** |
| `functions-conta` — integração (`npm run test:emulador`) | Firestore + Auth reais, os dez casos da OS + as coleções que chegaram depois | **48 passam** |
| `app` — `flutter test` (com overlay de seeds do CI) | suíte Flutter inteira, incluindo os 31 casos novos de exclusão | **684 passam** |
| `app` — os sete arquivos `teste_*.dart` | motor, encerramento, moderação, social, integração, espectador | **549 passam** |
| `flutter analyze` | `lib/conta`, tela, `configuracoes_screen`, `main.dart`, `test/conta` | **sem erro novo** |

### 5.1 Os dez casos que a OS pede

| Caso | Onde | O que é afirmado |
|---|---|---|
| usuário comum | `integracao.emulador.test.js` | conta fora do Auth, perfil fora dos **dois** namespaces, carteira e histórico pessoal apagados, perfil público anônimo e `indisponivel`, `publicIdIndex` virado lápide sem `uid`. Inclui a conta **sem identidade pública**, que também precisa poder sair. |
| VIP | idem | entitlement e o documento interno com o `purchaseToken` **em claro** apagados; `compras` e `billingEvents` retidos e sem titular; o diário guarda o estado do VIP no encerramento. |
| ranqueado | idem | *standings* das duas temporadas e agregado vitalício retidos com apelido anônimo; `rankingLedger` e `matches` intocados, `userId` incluso. |
| com amizades | idem | canônico e os **dois** espelhos, inclusive a solicitação pendente na conta do amigo. |
| bloqueado | idem | as listas dele e as referências a ele nas listas de terceiros, por consulta *collection-group*. |
| com denúncias | idem | `reports` (as que fez e as que sofreu), `sanctions` e `playerModeration` **ficam**; só o comprovante pessoal sai. E **um jogador suspenso consegue excluir a conta sem que a sanção suma junto.** |
| chamada duplicada | idem | converge com `repeticao`, não reexecuta, não infla o contador de tentativas, não apaga o resumo medido. Inclui duas chamadas **simultâneas**. |
| UID de terceiro | `plano.test.js` + `integracao.emulador.test.js` | a recusa do payload cobre os cinco nomes (inclusive `publicId`, o único identificador que o cliente conhece); e excluir A não arrasta B junto. |
| falha parcial | `integracao.emulador.test.js` | sem conta no Auth a exclusão para na etapa 1, fica `parcial` e **não apaga nada depois disso**. |
| idempotência | idem | a retomada conclui, salta etapa já feita, e um diário concluído não volta a executar nem com dado no banco. |

### 5.2 Provas estruturais

Provas de **ausência**, que teste de comportamento não pegaria — a rota que
passasse a aceitar `req.data.uid` teria nome novo e nenhum teste existente a
chamaria. Mesma técnica de `functions-ranking/test/identidade.test.js`.

* Nenhum arquivo de `functions-conta/src/` lê `req.data.uid`, `.userId` ou
  `.publicId`.
* `executar` recebe o uid **por parâmetro**, e o executor não conhece
  `CallableRequest`.
* `STATUS_INSCRICAO_ATIVA` é conferido contra `app/lib/torneios/registrations.
  dart`: um estado novo lá não pode passar a ser tratado como inativo aqui em
  silêncio.
* Toda etapa declarada em `plano.ts` tem execução em `executor.ts` — conferido no
  **carregamento do módulo**, não no teste: uma etapa sem execução seria saltada
  em silêncio e a exclusão terminaria "concluída" tendo deixado dado para trás.

### 5.3 O freio de rajada (OS 48)

Onze casos novos em `integracao.emulador.test.js`, no bloco
`o freio de rajada do chat`. A suíte passou de **37 para 48**, e os 37
anteriores continuam passando na mesma execução.

| Caso | O que é afirmado |
|---|---|
| documento presente | o contador do excluído sai |
| documento ausente | quem nunca falou é excluído igual, e a etapa conclui — `delete` de documento inexistente é sucesso |
| terceiro intocado | o freio de quem fica continua valendo, com o contador não zerado |
| ficha disciplinar | o freio sai e `playerModeration`, `sanctions` e `reports` **ficam** — a prova de que apagar não é limpar ficha |
| repetição idempotente | a segunda chamada converge com `repeticao`, sem erro |
| falha intermediária | parou antes de `moderacaoDoJogador`; o documento espera a retomada em vez de sumir por acidente |
| retomada | a segunda tentativa alcança o item — uma etapa que só rodasse na primeira passada deixaria o freio vivo em toda exclusão que falhou uma vez |
| resposta atrasada | uma escrita tardia não reabre a conta nem derruba a exclusão; o resíduo é o contador e nada mais (§7.4) |
| troca A→B | a conta nova nasce sem estado de ritmo: não há `bloqueadoAteMs` a herdar |
| subcoleções | `chatRitmo/{uid}` é documento plano — e o caso reprova no dia em que deixar de ser, porque `delete` no pai não apaga subcoleção |
| exclusão integral | o jogador inteiro numa passada: as 11 etapas concluem, o freio sai junto, e a moderação continua retida |

#### Campanha negativa

`ferramentas/exclusao/` — **19 sabotagens, nenhum sobrevivente.**

* **18 mutações de código** (`campanha.sh` → `campanha_chat_ritmo.js`): oito na
  matriz (classe trocada pelas quatro alternativas, chave desviada para
  `publicId`, coleção com plural a mais, alcance `semAcao`, justificativa
  esvaziada), quatro no plano (item fora da etapa, item em duas etapas, ordem
  invertida, resumo que esconde o que apaga) e seis no executor (tratamento
  removido, UID desviado por `publicId` e por sufixo, coleção errada, varredura
  sem filtro levando o freio de todo mundo, e a exclusão apagando também a ficha
  disciplinar).
* **1 sabotagem de portão** (`portao_nao_executado.sh`): as cinco formas de a
  suíte **não ter rodado** — marcador `nao_<gate>`, resultado ausente, `exit`
  vazio, `exit` não numérico e `exit 1` — para `contafn` **e** `contaemu`,
  contra o agregador real `scripts/ci/portao_os_integracao.sh`. É a sabotagem
  que as outras dezoito pressupõem resolvida: `contaemu` é o único lugar onde o
  apagamento acontece de verdade, e depende de emulador, que é justamente o tipo
  de passo que "pula quando o ambiente não está pronto".

O arnês recusa três coisas em vez de contá-las como cobertura, e cada recusa é
consequência de um laudo mentiroso já visto nesta árvore: âncora ausente ou
ambígua **para a campanha inteira** (em vez de virar sobrevivente); falha de
compilação e *timeout* saem como `INVALIDA`, nunca como "pega"; e a árvore
intacta tem de dar verde **antes e depois**, com conferência byte a byte da
restauração.

A primeira volta desta campanha teve **dois escapes**, e os dois eram do arnês e
do guarda, não do código:

1. a mutação da justificativa trocava só a primeira frase — **mutante
   equivalente**: o resto do texto continuava citando `sanctions`,
   `playerModeration` e `limites.dart`, então o argumento seguia escrito e o
   portão tinha razão em não reprovar. Passou a substituir o valor inteiro, e o
   guarda passou a exigir também a palavra `RETIDOS` — citar os registros sem
   dizer que eles **ficam** não defende decisão nenhuma;
2. a mutação que tirava o contador do resumo da etapa escapava porque o guarda
   procurava `/rajada/` e a palavra aparecia numa segunda frase do mesmo resumo.

---

## 6. Índices declarados

Dois `fieldOverrides` novos em `firebase/firestore.indexes.json`, ambos
`COLLECTION_GROUP`:

| Coleção | Campo | Para quê |
|---|---|---|
| `blocks` | `bloqueadoUid` | achar os bloqueios que **outros** fizeram contra quem está saindo |
| `mutes` | `alvoUid` | idem, para silenciamentos |

O arquivo tinha `fieldOverrides: []` "de propósito", e o raciocínio original
continua registrado no comentário. O que mudou: essas duas consultas são
*collection group* sobre subcoleção, e o índice automático de campo único não as
garante nesse escopo.

> **Ressalva que vale repetir:** o emulador do Firestore **não exige** índice — ele
> os cria sozinho. As duas consultas passariam na suíte de integração mesmo sem o
> `fieldOverrides`, e falhariam **em produção**. A conferência é por leitura do
> arquivo, e continua sendo portão de pré-deploy.

---

## 7. O que ficou em aberto

1. **Inscrição ativa em torneio bloqueia a exclusão.** Cancelar exigiria
   reproduzir a regra de `cancelarInscricaoTorneio` (devolução de fichas,
   convocação da lista de espera, recontagem de lotação) dentro de
   `functions-conta` — duplicação de regra competitiva, que a OS proíbe. A porta
   recusa e **nomeia** as inscrições que travaram; o jogador cancela pelo fluxo
   próprio e volta. Resolver isso de verdade é uma OS de torneios, não desta.

2. **`wallets/{uid}` não é declarada em `firestore.rules`.** Cai no fecho
   `if false`, então é invisível ao cliente e o comportamento hoje está correto —
   mas é a coleção que guarda o saldo de fichas e ela merece bloco próprio, como
   o fecho do arquivo pede. Não foi acrescentada aqui porque mexer nas regras de
   torneios está fora do escopo desta OS.

3. **`hallEntries` não tem produtor neste repositório.** A linha está na matriz e
   a varredura existe; hoje ela não acha nada. É o que garante que o Hall seja
   tratado no dia em que alguém passar a escrevê-lo.

4. **Uma escrita atrasada ainda pode deixar resíduo — e não é específico de
   `chatRitmo`.** `trancar` desabilita a conta e revoga os refresh tokens, mas um
   ID token já emitido continua válido até expirar; uma chamada em voo pode
   terminar depois da etapa que apagou o dado dela. A janela vale para **todo**
   item APAGAR da matriz. O que a OS 48 acrescentou foi a medida do limite para
   o caso do freio de rajada: o máximo que sobra é o contador — nem perfil, nem
   carteira, nem identidade, nem conta voltam, e o UID remanescente já não
   resolve para pessoa nenhuma. Fechar isso de verdade exigiria que cada
   autoridade produtora consultasse `accountDeletions/{uid}` antes de gravar,
   o que é mudança nas autoridades, não nesta.

5. **O cruzamento com as regras é cego para a remoção da própria regra.**
   `test/inventario.test.js` acusa coleção *declarada e não classificada*. O
   caminho inverso — apagar o bloco `match /colecao/{id}` de
   `firebase/firestore.rules` — faz a coleção deixar de ser cobrada, e nenhuma
   suíte reprova. Vale para as 77 linhas da matriz igualmente. Fechar isso é
   mudar o critério de cobertura (cruzar também contra os `.collection("…")` do
   código das Functions), e não o destino de uma coleção.

6. **Nada foi implantado.** A OS proíbe deploy, migração e execução em produção,
   e nada disso foi feito. Antes de um deploy futuro: publicar os dois
   `fieldOverrides`, subir o codebase `conta`, e conferir a região
   (`southamerica-east1`) contra o cliente.

---

## 8. Commits

| Hash | O quê |
|---|---|
| `b301cb2` | consolidação das duas linhas (base) |
| `aad09df` | `functions-conta`: matriz, plano, diário, reautenticação, executor, callables |
| `b304f59` | os dez casos da OS contra Firestore e Auth reais |
| `d251c14` | cliente Flutter: porta, adaptador, controlador, tela e entrada em Configurações |

---

## 9. O que veio depois

**OS 48 — destino canônico de `chatRitmo/{uid}`.** A Comunicação Controlada V1
criou uma coleção depois desta matriz e não a classificou; o gate `contafn`
ficou vermelho na base com `actual: [ 'chatRitmo' ]`. A correção decidiu
`APAGAR`, escreveu a justificativa na matriz (§4.1), acrescentou o item à etapa
`moderacaoDoJogador`, e provou o efeito contra o emulador. Ela **não alterou** a
política de comunicação: nem limite, nem cooldown, nem rota, nem regra, nem tela.

A camada de **conformidade de publicação** que sucede esta OS — recurso web
externo de exclusão, Política de Privacidade, preenchimento do Data Safety e o
caminho para gerenciar a assinatura da Google Play — está em
[`GOOGLE-PLAY-EXCLUSAO-CONTA-DATA-SAFETY.md`](GOOGLE-PLAY-EXCLUSAO-CONTA-DATA-SAFETY.md).

Aquela OS **não alterou nada do que está descrito aqui**: a matriz de
`inventario.ts`, o plano, o executor, os portões e as recusas continuam
exatamente como este documento os descreve. O recurso web não reimplementa a
exclusão — ele chama as mesmas duas callables, com o UID vindo do ID token e
nunca do navegador.
