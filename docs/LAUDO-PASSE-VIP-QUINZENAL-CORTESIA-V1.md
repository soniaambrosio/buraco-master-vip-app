# LAUDO — PASSE VIP QUINZENAL DE CORTESIA V1

**Natureza:** arbitragem somente leitura. Nenhum passe concedido, nenhum
entitlement alterado, nenhuma escrita em produção, nenhum agendador criado,
nenhuma linha de código de produto modificada.

**Base auditada:** `integracao/release-canonica-predeploy-v1` @ `8ee179d`
("censo(billing): a populacao legada VIP e zero, e medida"), 469 commits,
a composição predeploy mais ampla do repositório — superconjunto das frentes de
Billing, economia, torneios, conta e servidor. Também auditado o repositório
separado do servidor de mesas: `F:/Projetos/buraco-servidor` @ `85d0eee`.

**Branch documental:** `auditoria/passe-vip-quinzenal-cortesia-v1`, criada a
partir de `8ee179d`.

---

## 1. VEREDITO

### `BLOCKED — CONSUMO VIP NÃO TRANSACIONAL`

O rótulo é o mais próximo da lista da OS, mas ele **subestima** o achado, e a
diferença importa para o planejamento: o consumo do passe não é "não
transacional" — **ele não existe em lugar nenhum do sistema.**

O benefício descrito pela OS é *uma entrada de partida VIP*. Para que um passe
seja consumido é preciso que exista um instante em que alguém com autoridade
diga "este jogador está entrando numa partida VIP agora". **Esse instante não
existe:**

1. **O servidor de mesas não conhece VIP.** Em `buraco-servidor@85d0eee`,
   `server.js:3801` declara `TIPOS_DE_PARTIDA = ["publica", "privada",
   "simulada"]`. Não há nível VIP. Um `git grep -i vip` no servidor inteiro só
   encontra o nome do produto em comentários e o id do projeto de teste.
2. **O servidor não lê o Firestore.** Ele valida o ID Token do Firebase por
   assinatura RSA (`server.js:4676`, `criarVerificadorFirebase`) e usa uma
   credencial própria com o claim `motorDePartidas` (`server.js:4824`) para
   chamar `registrarEncerramentoPartida`. Ele **não** tem acesso a
   `playerEntitlements` nem a nenhuma coleção de direitos.
3. **O tipo da partida é configuração do processo, não da mesa.** Em
   `server.js:4085`, `tipoPartida` vem de `opts` do *gerenciador* — e o próprio
   comentário do arquivo explica que ele está ali, e não em `criarMesa({...})`,
   *"porque o despachante monta `criarMesa` a partir de `msg`, e um campo que
   morasse lá seria escolhível pelo cliente"*. Uma instância do servidor tem
   **um** tipo para todas as suas mesas.
4. **Nesta RC o fluxo de mesa VIP nem chega ao servidor.** `OnlineService`
   (`app/lib/services/online_service.dart`) **não é instanciado em nenhum ponto
   do aplicativo** — a única ocorrência de `OnlineService(` no código é a própria
   declaração do construtor, na linha 81 do arquivo que o define. As rotas VIP do
   `main.dart` levam a `MesaFlowPreviewHost` → `MesaScreen`, navegação local.
   Entrar numa "mesa VIP" hoje é uma transição de tela, sem ida e volta a
   autoridade nenhuma.

Consequência direta: **qualquer passe concedido hoje seria decorativo.** Ele
poderia ser gravado, exibido e expirado corretamente, e ainda assim nada o
consumiria, porque não há porta onde ele seja apresentado. Um passe que nunca é
consumido é indistinguível de VIP permanente de graça.

### Condições subordinadas, registradas para não ficarem escondidas

O veredito é um só, como a OS pede. Estas duas condições **também** estão
presentes e precisam ser resolvidas — não são alternativas ao veredito acima, são
gates da sequência de OS da seção 7:

- **`DECISÃO DE PRODUTO NECESSÁRIA`** — as perguntas 3, 4 e 5 da OS não têm
  resposta derivável do repositório. Ver seção 3.
- **`CONFLITO COM BILLING` (condicional, ainda não materializado)** — não existe
  passe hoje, então não há conflito *de fato*. Mas a modelagem mais óbvia
  (gravar o passe em `playerEntitlements/{uid}`) **produziria** o conflito. Ver
  seção 4. A OS manda registrar o conflito em vez de assumir a modelagem: fica
  registrado.

---

## 2. MAPA DAS AUTORIDADES EXISTENTES

Oito codebases de Functions, cada um unidade de implantação independente
(`firebase.json`):

| Codebase | Fonte | Dono de |
|---|---|---|
| `billing` | `functions-billing/` | `playerEntitlements/{uid}`, `compras/{hash}`, `fichasConcessoes/`, `billingEvents/` |
| `economia` | `functions-economia/` | `usuarios/{uid}.fichas` (carteira), `economiaLedger/` |
| `torneios` | `functions/` | `tournaments/`, `rewardGrants/`, inscrição e elegibilidade |
| `colecoes` | `firebase/functions/` | `users/{uid}/inventory/`, `users/{uid}/campaign_claims/` |
| `conta` | `functions-conta/` | exclusão de conta e matriz de retenção |
| `moderacao`, `ranking`, `social` | — | fora do escopo deste laudo |

**Superfície de callables completa** (nenhuma delas autoriza entrada em partida):

- Billing: `validarCompraPlay`, `notificacoesPlay` (RTDN),
  `reconciliarEntitlements` (agendada), `concederFichasMensais` (agendada),
  `reconciliarEntitlementDoJogador`, `diagnosticarPopulacaoVip`,
  `backfillPurchaseTokenHash`, `diagnosticarMetadadosLegados`.
- Economia: `garantirBonusDeBoasVindas`, `aoRegistrarPartida` (gatilho),
  `reprocessarResultadoDaPartida`.
- Torneios: `inscreverEmTorneio`, `cancelarInscricaoTorneio`,
  `receberResultadoPartida`, `tickTorneios` (agendada), `aoConcluirEdicao`,
  `consolidarConvitesDaTemporada`, `responderConviteEncerramento`.
- Coleções: `claimPioneerKit`, `grantPioneerEligibility`, `revokePioneerKit`.
- Conta: `resumirExclusaoDeConta`, `excluirMinhaConta`.

**O único consumidor server-side de VIP fora do próprio Billing** é a
elegibilidade de torneio: `functions/src/index.ts:106` lê
`playerEntitlements/{uid}` e passa para `comporElegibilidade` (ponte para o
domínio Dart). Salão VIP, mesas VIP e mesas privadas **não têm nenhum
enforcement server-side** — o portão é exclusivamente o cliente.

---

## 3. AS QUINZE PERGUNTAS OBRIGATÓRIAS

**1. Qual autoridade pode conceder sem conflitar com assinatura Play?**
Nenhuma existente. Deve nascer uma, e ela **não pode ser o Billing**: o Billing
é o tradutor da Google e todo documento que ele escreve descreve uma compra real.
O candidato natural é o codebase `economia` (já é o dono de benefício não pago e
já tem o padrão de callable idempotente) ou um codebase novo `beneficios`. A
autoridade precisa ser distinta da do Billing para que um deploy de cortesia
nunca derrube a validação de compra — critério que `firebase.json` já aplica aos
oito codebases.

**2. Passe é entitlement, grant econômico ou documento próprio?**
**Documento próprio.** Os três candidatos existentes falham:
- *Entitlement* (`playerEntitlements`): categoria errada. `EntitlementVip`
  responde "tem VIP agora?" — um estado contínuo de 7 dias, não uma entrada
  única. Um passe modelado assim liberaria Salão VIP, mesas VIP, mesas privadas
  e elegibilidade de torneio por 7 dias inteiros. Além disso conflita com
  Billing (seção 4).
- *Grant econômico* (`economiaLedger` / `usuarios.fichas`): a carteira é um
  inteiro sem prazo. `economia.js` não tem nenhum conceito de validade, e
  `aplicarPiso` trata saldo como número puro. Fichas não expiram; o passe expira.
- *`rewardGrants`*: chega perto e não serve — ver pergunta 12.

**3. Onde nasce a primeira concessão: cadastro, ativação da feature ou primeira visita?**
**Decisão de produto, e o repositório força a mão numa direção.**
Não existe ponto autoritativo de criação de usuário nesta base — não há gatilho
de Auth nem `beforeUserCreated`. O precedente instalado é
`garantirBonusDeBoasVindas`: **callable idempotente chamada a cada sessão**, que
resolve contas antigas sem migração. "Cadastro" não é implementável sem criar um
gatilho novo; "primeira visita" é o que a arquitetura já suporta.

**4. Assinante VIP recebe, oculta ou deixa de acumular o passe?**
**Decisão de produto. Sem resposta no repositório.** Recomendação técnica:
não conceder enquanto `EntitlementVip.vigenteEm(agora)` for verdadeiro, e **não**
mover `nextEligibleAt` durante a assinatura — assim o assinante que cancela volta
a receber na primeira janela seguinte sem carência artificial. Conceder a
assinante criaria estoque invisível; ocultar sem parar a concessão criaria
acúmulo silencioso, que a OS proíbe.

**5. Em que momento ele é consumido: entrada, reserva, início ou encerramento?**
**Decisão de produto — e hoje nenhuma das quatro é implementável** (ver seção 1).
Recomendação: **na admissão à mesa, pelo servidor**, em transação, antes de o
assento ser ocupado. Consumir no encerramento é inseguro (a partida já foi
jogada); consumir na entrada do cliente é inseguro (o cliente não é autoridade).

**6. Como devolver a autorização se matchmaking ou criação da mesa falhar?**
**Não há mecanismo, e não há precedente.** Uma varredura por
`reserva|rollback|estorno|compensac` nos quatro codebases relevantes e no
domínio Dart não devolve nenhuma ocorrência de duas fases — só heurística de
bot (`preservaCuringa`). Todo o repositório usa **uma escrita transacional
idempotente**, nunca reserva-e-confirma.

**7. Como impedir consumo duplicado por dois dispositivos?**
Transação do Firestore com chave determinística. O padrão está pronto e provado
três vezes: `idempotencia.js` (`podeConceder`, relido dentro da transação),
`fichasStore.js` (linha do livro-razão criada na MESMA transação do crédito) e
`economiaStore.js`. É a parte fácil.

**8. Como impedir duas concessões simultâneas?**
Mesma disciplina, com a chave da **janela**, não do instante — ver seção 4.
`fichasConcessoes/{purchaseTokenHash}_{indice}` é o precedente exato: o índice
da parcela, e não uma data, é o que torna a chave determinística.

**9. Como lidar com expiração durante uma partida já iniciada?**
Se o consumo for na admissão, a questão desaparece: o direito foi gasto ao
entrar, e a partida não é reavaliada. Este é o argumento mais forte a favor de
consumir na admissão. (Comparar com `EntitlementVip`, que é reavaliado a cada
leitura justamente por ser um estado contínuo — o passe não deve ser.)

**10. Como o servidor Railway confirma o passe sem confiar no Flutter?**
**Não consegue hoje.** Ele não lê Firestore. Existe, porém, o caminho: ele já
possui credencial própria com o claim `motorDePartidas` e já chama uma Cloud
Function (`registrarEncerramentoPartida`). O desenho correto é uma callable nova
de admissão — `admitirEmMesaVip` — chamada **pelo servidor**, com a mesma
credencial, consumindo o passe em transação e devolvendo autorizado/recusado.
O cliente nunca carrega o veredito.

**11. Há suporte atual para reserva/commit/rollback?**
**Não.** Ver pergunta 6.

**12. `reward_grants` suporta bem temporal com expiração?**
**Suporta a expiração; não suporta o resto.** `RecompensaConcessao`
(`app/lib/torneios/reward_grants.dart:286`) tem `grantedAt`, `expiresAt` em UTC,
recusa `expiresAt` não posterior a `grantedAt`, e tem chave de idempotência
determinística. Mas:
- a chave é `tournamentId + editionId + userId + assetId` — usá-la exigiria
  inventar um torneio e uma edição falsos para um benefício que não é de torneio;
- **não há consumo**. Uma recompensa é um ativo de vitrine (coroa, selo); o
  domínio não tem "usar" nem "gastar". A OS exige "usado ou expirado desaparece";
- não há janela recorrente: `ExpirationPolicy` resolve por duração ou pela
  próxima edição, não por ciclo de 15 dias;
- `firebase/firestore.rules:459` já fecha `rewardGrants` para escrita do cliente,
  o que é correto e se mantém em qualquer desenho.

**13. É necessário agendador ou a concessão pode ser materializada sob demanda?**
**Sob demanda, e o precedente é forte.** `fichas.js` resolve exatamente este
problema: `indicesDevidos({inicioEm, agora})` deriva do **calendário** quais
parcelas venceram, e o livro-razão por índice impede pagamento duplo. O
agendador (`concederFichasMensais`) é rede de segurança, não o mecanismo. O
cabeçalho de `fichas.js` é explícito: *"a entrega mensal não pode ser reativa a
evento; ela precisa ser uma conclusão do RELÓGIO"*. Para o passe quinzenal vale
o mesmo — **e melhor**, porque o passe só interessa quando o jogador vai jogar,
então materializar na visita cobre 100% dos casos úteis. Infraestrutura de
agendador existe (`onSchedule` em dois pontos do Billing e em `tickTorneios`),
mas **não é necessária**.

**14. Qual dado o Perfil/Home deve exibir?**
Hoje a Home tem `cadeadoVip` (`inicio_screen.dart:41`) e o Saguão tem
`ehVip`/`vipsOnline`, todos alimentados por `EscopoVip.de(context)`. Para o
passe, a tela precisa de três fatos e **nenhum veredito**: se há passe utilizável,
`expiresAt` (quanto falta para perder) e `nextEligibleAt` (quando vem o próximo).
A disciplina do `PortaoVip` deve ser copiada literalmente: guardar FATOS,
recomputar a vigência contra o relógio a cada leitura, e nunca guardar
`liberado: true`.

**15. Quais índices, Rules e rotinas de exclusão seriam afetados?**
- **Rules** (`firebase/firestore.rules`): coleção nova, no padrão já dominante —
  `allow read: if ehDono(uid)`, `allow write: if false`. **Atenção à armadilha já
  registrada no projeto:** `allow read` com `|| ehAdmin()` torna a coleção
  varrível, porque no `list` o predicado roda documento a documento e `ehAdmin()`
  não depende de documento. Separar `get` de `list`, como `economiaLedger` faz.
- **Índices** (`firebase/firestore.indexes.json`): **nenhum**, se a coleção for
  `passesVip/{uid}` resolvida por id de documento. O Billing hoje não declara
  índice nenhum, e é bom que continue assim. Um índice composto só apareceria se
  alguém quisesse varrer passes por vencimento — o que a materialização sob
  demanda torna desnecessário.
- **Exclusão de conta** (`functions-conta/src/inventario.ts`): **obrigatório**
  acrescentar o item. O arquivo lê `firebase/firestore.rules` e **falha se alguma
  coleção declarada lá não estiver classificada** — acrescentar coleção sem
  classificar quebra a suíte, por construção. Classe correta: `APAGAR`, mesma de
  `billing.playerEntitlements` ("o DIREITO VIP é da conta e morre com ela").

---

## 4. A SEMÂNTICA PROPOSTA PELA OS, AVALIADA

A modelagem da seção 4 da OS (`receivedAt` / `expiresAt = receivedAt + 7d` /
`nextEligibleAt = receivedAt + 15d`) é **coerente e compatível** com o
repositório. Não há autoridade incompatível instalada, porque não há passe
nenhum hoje. Ressalvas:

**`receivedAt` como âncora está certo, e é a decisão que evita o defeito clássico.**
Ancorar em uso ou expiração faria a cadência derivar do comportamento do jogador
— quem usa no dia 7 receberia o próximo em intervalos crescentes. Ancorar no
recebimento mantém a cadência fixa. É a mesma escolha que `fichas.js` faz ao
contar a partir de `inicioEm`.

**A chave de idempotência deve ser o ÍNDICE DA JANELA, não a data.**
Este é o ponto mais importante desta seção. `fichasConcessoes/{hash}_{indice}`
funciona porque o índice é derivado do calendário e é o **mesmo** número
independentemente de quando a rotina rode. Para o passe:

```
indiceJanela = floor((agora - ancoraInicial) / 15 dias)
chave        = `${uid}_${indiceJanela}`
```

Com isso, duas execuções simultâneas na mesma janela colidem na mesma chave e a
segunda perde a transação — que é exatamente a pergunta 8. Uma chave por
timestamp **não** teria essa propriedade.

**"Não acumula" e "no máximo um utilizável" precisam ser invariantes de escrita,
não de leitura.** A concessão da janela N+1 deve, na mesma transação, encerrar o
passe da janela N que ainda esteja aberto. Se ficar a cargo da leitura ("mostre
só o mais recente"), dois passes coexistem no banco e qualquer consumidor novo
volta a poder gastar os dois.

**Relógio sempre do servidor:** compatível e já é a regra do codebase. Todo
domínio recebe `agora` por parâmetro e `EntitlementVip.vigenteEm` **estoura** se
o instante não estiver em UTC. Manter.

**"Nenhuma vantagem competitiva além do direito de entrada":** compatível, e há
um cuidado concreto. `economia.js` paga +15/−10 por modalidade
(`TIPOS_QUE_PAGAM`), sem olhar quem entrou como cortesia. Se a mesa VIP for de
uma modalidade que paga, o passe passa a ter valor econômico indireto. Não é
defeito hoje — é decisão a tomar quando a mesa VIP existir de fato.

### O conflito que a modelagem por `playerEntitlements` produziria

Registrado como a OS manda, para que ninguém o descubra depois:

1. `reconciliarEntitlements` varre `vipAtivo == true && expiraEm <= agora` e
   trataria o passe como assinatura vencida.
2. O RTDN reconsulta a Google por `purchaseToken`. Um passe de cortesia não tem
   token; `titularDoToken` responderia `registro_sem_uid` e o evento seria
   descartado — ou pior, o passe seria reconciliado contra uma compra
   inexistente.
3. `concederFichasMensais` cairia no ramo `semPlano` — o passe não receberia
   fichas, o que por acaso é o desejado, mas por motivo errado.
4. O campo `origem` já admite `administrativa` (`entitlement.dart`), mas **nenhum
   produtor grava esse valor hoje**. Ligá-lo criaria uma segunda natureza dentro
   da coleção que o Billing considera sua — a "fonte concorrente permanente" que
   a OS de ciclo de vida do VIP proibiu explicitamente.
5. E o decisivo: um entitlement VIP concede **tudo** que é VIP por 7 dias,
   inclusive elegibilidade a torneio via `functions/src/index.ts:106`. A OS pede
   **uma entrada de partida**.

---

## 5. OS QUATORZE CENÁRIOS

| # | Cenário | Situação hoje |
|---|---|---|
| 1 | Concessão inicial | **Não implementável.** Sem autoridade e sem ponto de criação de usuário. Padrão disponível: callable idempotente por sessão (`garantirBonusDeBoasVindas`). |
| 2 | Uso no primeiro dia | **Não implementável.** Não há ponto de consumo (seção 1). |
| 3 | Uso no sétimo dia | Idem. A fronteira `agora < expiresAt` é trivial e já é a disciplina de `vigenteEm`. |
| 4 | Expiração sem uso | **Implementável sem escrita**, e é o desenho certo: expiração é conclusão do relógio na leitura, não um job. Precedente: `EntitlementVip.vigenteEm` e o cabeçalho de `acesso_vip.dart` — *"expiração não gera escrita no Firestore no segundo do vencimento"*. |
| 5 | Retorno no décimo quinto dia | **Implementável** por índice de janela derivado do calendário, sem agendador (pergunta 13). |
| 6 | Dois dispositivos | **Resolvível** por transação com chave determinística. Padrão pronto e provado. |
| 7 | Duas tentativas simultâneas | **Resolvível** pela chave de janela. Uma chave por timestamp NÃO resolveria. |
| 8 | Falha antes da mesa nascer | **Sem mecanismo.** Não há reserva. Mitigação: consumir só depois de a mesa existir — o que exige o servidor participar. |
| 9 | Falha depois da reserva | **Não aplicável hoje**, porque reserva não existe. Se for construída, é a primeira coisa do projeto a precisar de compensação, e o repositório não tem nenhum precedente de compensação. |
| 10 | Assinatura iniciada durante a validade | **Decisão de produto** (pergunta 4). Tecnicamente detectável: `EntitlementVip.vigenteEm` responde no mesmo instante. |
| 11 | Assinatura encerrada | Coberto pelo Billing: `canceladoVigente` mantém acesso até `expiraEm`, depois cai. O passe deve voltar a ser concedido na janela seguinte, sem carência. |
| 12 | Relógio do cliente adulterado | **Já resolvido pela disciplina do codebase.** Todo domínio recebe `agora` por parâmetro; nenhum lê `DateTime.now()` para decidir. `colecao_campanha.dart` declara em texto que o veredito do cliente nunca concede. Manter: a concessão e o consumo decidem no servidor. |
| 13 | Exclusão e recriação de conta | **Vetor de farm em aberto, e é decisão de produto.** `playerEntitlements` é APAGADO na exclusão; conta recriada tem `uid` novo, logo primeira janela nova. Não há amarra entre pessoa e conta que sobreviva à exclusão — e criar uma esbarra em privacidade. Registrar como risco aceito ou limitar o valor do benefício. |
| 14 | Partida iniciada antes e encerrada depois da expiração | **Não é problema se o consumo for na admissão** — o direito já foi gasto. É a razão prática para escolher admissão em vez de encerramento. |

---

## 6. ACHADOS ADJACENTES

Encontrados durante a arbitragem, fora do escopo do passe, registrados porque
afetam qualquer OS futura que toque partida VIP:

1. **Vocabulário de tipo de partida divergente entre servidor e domínio.**
   O servidor produz `publica | privada | simulada` (`server.js:3801`); o domínio
   Dart usa `publica_casual | publica_ranqueada | torneio | treinamento |
   contra_robos | privada` (`app/lib/rastreabilidade/identidade_partida.dart:67`),
   e `functions-economia/economia.js` só paga para
   `['publica_casual','publica_ranqueada','torneio']`. Só `privada` existe nos
   dois lados — e é justamente o tipo que **não** paga. Merece verificação
   própria: pode significar que a economia básica não credita nada em produção.
2. **`OnlineService` órfão nesta RC.** O cliente de WebSocket existe, está
   autenticado e testado, e **não é instanciado por nenhuma tela**. A ligação
   mesa online × casca existe em outra linhagem (`4b3c460`), que **não** está
   contida em `8ee179d`. Qualquer OS que dependa do servidor precisa compor essa
   linhagem antes.

---

## 7. SEQUÊNCIA DAS FUTURAS OS

A ordem não é negociável nos dois primeiros itens: sem o gate de produto não há o
que especificar, e sem o servidor o benefício é decorativo.

### Gate 0 — DECISÃO DE PRODUTO (Sônia, sem código)
Responder, por escrito, as perguntas **3, 4 e 5**:
- onde nasce a primeira concessão (recomendado: primeira visita, por callable
  idempotente — é o que a arquitetura suporta sem gatilho novo);
- o que acontece com o assinante (recomendado: não conceder, e não mover a
  âncora);
- em que instante o passe é consumido (recomendado: admissão à mesa).
Decidir também o risco do cenário 13 (exclusão e recriação).
**Nada mais pode ser especificado antes disto.**

### OS-1 — SERVIDOR: NÍVEL VIP DE MESA
*Repositório `buraco-servidor`.* Fazer o servidor saber o que é uma mesa VIP:
`tipoPartida` por **mesa** e não por processo, mantendo a invariante já declarada
no código de que o nível **não pode vir de `msg`** do cliente. Sem isto não há
onde apresentar passe nenhum. Não toca Firestore ainda.

### OS-2 — BACKEND: AUTORIDADE DE CONCESSÃO
*Codebase `economia`, ou um `beneficios` novo — nunca `billing`.* Coleção
própria (`passesVip/{uid}`), materialização sob demanda por **índice de janela**
derivado do calendário, sem agendador. Concessão e encerramento do passe anterior
na mesma transação. Rules `read` do dono / `write: if false`, com `get` separado
de `list`. Item novo na matriz de retenção de `functions-conta` (classe `APAGAR`)
— sem ele a suíte de exclusão quebra, por construção.

### OS-3 — BACKEND: ADMISSÃO TRANSACIONAL
Callable `admitirEmMesaVip`, chamada **pelo servidor** com a credencial do claim
`motorDePartidas` (o mesmo caminho que `registrarEncerramentoPartida` já usa).
Consome o passe em transação e devolve autorizado/recusado. O cliente nunca
carrega o veredito. Se o Gate 0 escolher consumo com reserva em vez de admissão,
esta OS ganha uma segunda fase e um mecanismo de compensação que **não tem
nenhum precedente no repositório** — motivo técnico para preferir admissão.

### OS-4 — CLIENTE: APRESENTAÇÃO
Portão análogo ao `PortaoVip`: guarda fatos, recomputa contra o relógio, **não
tem método que conceda**. Exibe passe disponível, `expiresAt` e `nextEligibleAt`
na Home e no Perfil. Nunca decide admissão — só antecipa a recusa para não
empurrar o jogador a uma porta que vai fechar.

### OS-5 — ATIVAÇÃO OPERACIONAL
Deploy dos codebases tocados, conferência de que nenhum índice composto novo é
exigido, e verificação de que o servidor em produção roda a versão da OS-1.
Observação: a publicação comercial do VIP **continua bloqueada** por itens
alheios a este laudo (catálogo `master_vip` inexistente na Play e tópico RTDN não
criado). O passe de cortesia **não depende** deles — ele não passa pela Google —,
e essa independência é um argumento a favor de entregá-lo antes.

---

## 8. CONFORMIDADE DA ENTREGA

- Somente leitura: nenhum arquivo de código, teste, regra ou configuração foi
  modificado. A auditoria foi feita lendo o object store do git
  (`git show`/`git grep` no ref `8ee179d`) e o repositório do servidor.
- Nenhum passe concedido, nenhum entitlement alterado, nenhuma escrita em
  produção, nenhum agendador criado, nenhum deploy.
- Sem PR e sem merge.
- Único arquivo acrescentado: este laudo.
