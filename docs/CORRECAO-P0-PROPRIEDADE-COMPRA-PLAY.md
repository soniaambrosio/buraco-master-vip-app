# Correção P0 — a propriedade da compra Play

**Veredito: `PASS`** — nenhum portador de token escolhe a conta beneficiada; a
propriedade vem da vinculação registrada antes do fluxo Play e devolvida pela
Google; nenhuma associação token → UID existe antes dessa verificação; RTDN e
validação direta convergem para a mesma conta; os três achados médios estão
corrigidos; matriz adversarial e provas de não-vacuidade integralmente verdes.

**Com uma parte da OS BLOQUEADA e não entregue:** a seção 5 (fluxo de compra no
aplicativo) não tem onde ser aplicada — **não existe cliente de Billing nesta
base**. Detalhado na seção 4 deste laudo. Todo o resto foi entregue.

---

## 1. Identificação

| | |
| --- | --- |
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Base | `homologacao/rtdn-vip-adversarial-p0` — `c5c9a7d4765db334143678df0036db9b27cf2658` |
| Produção homologada na linhagem | `a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9` |
| Branch | `correcao/rtdn-vip-propriedade-compra-p0` |

### A divergência `b2c3d91` × `a2622d5`

`b2c3d91` **não identifica** a ref homologada. Duas leituras de `git ls-remote`
em `integracao/rtdn-vip-producao` devolveram `a2622d59c09…`, na homologação e de
novo aqui. A correção incide sobre o código auditado em `a2622d5`, preservado
byte a byte dentro da base `c5c9a7d` — conferido no Gate Zero:

```
git diff --stat a2622d5 c5c9a7d -- functions-billing/*.js firebase/ app/ functions/
(vazio)
```

`c5c9a7d` descende de `a2622d5` e acrescenta **somente** testes, fakes e o laudo
da homologação. Ela é evidência e base de testes; não representa aprovação do
RTDN/VIP e não deve ser promovida isoladamente.

### Gate Zero

Antes de qualquer edição: dois SHAs confirmados remotamente; ancestralidade
provada; produção idêntica entre os dois pontos; baseline `79/79`; suíte
adversarial `65/65`; dez provas de não-vacuidade, todas **NÃO VÁCUAS**.

O inventário (`git grep` sobre o código versionado) devolveu, para
`linkedPurchaseToken`, `obfuscated` e `externalAccountIdentifiers`: **zero
ocorrências**. Nenhuma segunda autoridade apareceu. Nenhum cliente de compra
existe em `app/`.

---

## 2. A ordem de validação: antes e depois

O achado A-1 não era "gravar cedo demais". Era **não existir autoridade nenhuma**
sobre a pergunta *de quem é esta compra?*.

| | ANTES (`a2622d5`) | DEPOIS |
| --- | --- | --- |
| 1 | autenticar | autenticar |
| 2 | validar forma | validar forma |
| 3 | conferir catálogo | conferir catálogo |
| 4 | **gravar `compras/{hash}` com o uid de quem chamou** | **perguntar à Google** |
| 5 | perguntar à Google | **validar a forma da resposta** |
| 6 | veredito econômico | **extrair `obfuscatedExternalAccountId`** |
| 7 | consolidar entitlement | **resolver o dono no índice de vinculação** |
| 8 | transação de concessão | **exigir igualdade com o uid autenticado** |
| 9 | — | veredito econômico |
| 10 | — | consolidar entitlement |
| 11 | — | transação de concessão |

O passo 4 antigo é o defeito inteiro. Ele dava a compra a quem apresentasse o
token primeiro **e** envenenava o documento contra o dono legítimo, que dali em
diante recebia `permission-denied` para sempre — o mesmo guarda que protege o
caso R trabalhando a favor do invasor.

Hoje uma tentativa de tomar compra alheia termina **sem deixar rastro**: `R6`
verifica `c.db.diario.length === 0`.

---

## 3. A autoridade da vinculação

```
prepararCompraPlay (autenticada)          ← export NOVO
    │  gera 24 bytes aleatórios → 48 caracteres hexadecimais
    ▼
playerBillingIdentity/{uid}         → { contaOfuscada }   ┐ mesma
billingAccountIndex/{contaOfuscada} → { uid }             ┘ transação
    │
    ▼  o aplicativo entrega como obfuscatedAccountId
Google Play
    │  devolve em externalAccountIdentifiers.obfuscatedExternalAccountId
    │  (assinatura) ou obfuscatedExternalAccountId na raiz (produto avulso)
    ▼
resolverPropriedade → decidirPropriedade({identificador, uidResolvido, uidEsperado})
```

**Por que uma porta nova.** Nenhuma existente comporta a preparação:
`validarCompraPlay` roda **depois** da compra e por definição não pode
prepará-la; as outras duas são administrativas e exigem `admin`; e os demais
codebases (colecoes, torneios, moderação) são unidades de implantação
independentes. Somar a preparação a qualquer uma misturaria *quem sou eu para
comprar* com *o que eu ganhei*.

**Por que duas coleções.** As perguntas são feitas em momentos e por caminhos
opostos: a preparação tem o uid e quer o identificador; o RTDN só tem o
identificador e **não tem sessão** para varrer nada. Escritas sempre juntas.

**Por que aleatório, e não derivado do uid.** Uma derivação precisaria ser
invertida para o RTDN resolver o dono, e hash não se inverte — o índice reverso
seria necessário de qualquer forma. Existindo o índice, um valor aleatório não
carrega correlação alguma com a conta, nem para quem conheça a fórmula.

**As propriedades exigidas pela seção 4 da OS, e onde cada uma é provada:**

| Exigência | Prova |
| --- | --- |
| gerado pelo backend autenticado | `Y4` |
| ≤ 64 caracteres | `Y1` |
| sem uid, e-mail ou `publicId` em claro | `Y5` |
| estável para a conta | `Y1` |
| único | `Y2` |
| não concede VIP por existir | `Y7` — o direito só vem da resposta da Google |
| não é segredo de autenticação | a sessão Firebase continua exigida (`R5`) |
| não escolhido pelo cliente | `Y4` |
| um UID, uma vinculação | `Y1` |
| criação concorrente → um resultado | `Y3`, dez chamadas simultâneas |
| leitura e escrita diretas proibidas | `firestore.rules`, `ENT-23`…`ENT-26` |

---

## 4. `BLOQUEIO` — a seção 5 não tem onde ser aplicada

**Não existe cliente de Play Billing nesta base.** Verificado no Gate Zero e
reproduzível:

```bash
git grep -ln "in_app_purchase\|InAppPurchase\|BillingClient\|validarCompraPlay" -- 'app/**'
```

Não há dependência de billing em `app/pubspec.yaml`, não há código Dart que chame
`validarCompraPlay`, e a única menção a `purchaseToken` em Dart está em
comentários do consumidor do direito.

A seção 5 manda "alterar somente o encanamento necessário do Billing" e "parar e
registrar o bloqueio antes de criar canal nativo ou atualizar dependências por
iniciativa própria". Não há encanamento a alterar: entregar a seção 5 exigiria
acrescentar `in_app_purchase` ao `pubspec` e construir um fluxo de compra do
zero — exatamente as duas coisas que a OS proíbe fazer por iniciativa própria.

**A consequência tem de ser dita sem maquiagem: com esta correção, nenhuma compra
é aprovada até o cliente passar `obfuscatedAccountId`.** É falha fechada, é o que
a seção 17 exige, e é seguro hoje porque o produto não existe na Play Console e
não há compra real em circulação. Mas é uma porta fechada, não uma porta que
passou a funcionar melhor.

O que a correção **já** entrega para o dia em que o cliente existir: a porta
`prepararCompraPlay`, o contrato do campo e a conferência do outro lado. O que
falta é uma linha no fluxo de compra do aplicativo.

---

## 5. RTDN antes da validação do aplicativo

É o motivo pelo qual a vinculação nasce na **preparação** e não na validação.

A notificação da Google pode chegar antes de o aplicativo voltar a falar com o
backend. Se a propriedade dependesse de `validarCompraPlay` ter rodado, esse
evento não teria dono — e a versão antiga resolvia isso escolhendo o primeiro
solicitante.

`Y7` encena exatamente isso: preparação feita, **nenhuma** validação, notificação
entregue. O direito vai para a conta certa, e `compras/{hash}` continua não
existindo — o RTDN não inventa registro.

O caminho **terminal** (revogação, anulação) também mudou. O `ESTADO` continua
saindo do evento, porque a Google não devolve um `subscriptionState` que diga
"estornado" e esperar por um deixaria uma janela em que o reembolsado continua
VIP. O que passou a sair da consulta é o **dono**. `RTDN-05` foi renomeado de
"terminal TIRADA DO EVENTO — sem consultar a Play" para "o ESTADO vem do evento,
o DONO vem da Google": metade do nome antigo era garantia, metade era o defeito.

Custo: uma consulta por evento terminal, que antes não existia.

---

## 6. Compras antigas sem vinculação

Resposta da Google **sem** identificador → `vinculo_ausente`:

* não concede entitlement (`Y10`, `V`);
* não transfere propriedade;
* não cria associação definitiva — nada é gravado (`Y10`: `diario.length === 0`);
* registra apenas o código fechado na trilha, para que a operação consiga separar
  *assinante antigo* de *tentativa de tomar compra alheia*.

**Há legado real?** Dentro do repositório, apenas fixtures. Esta OS não autoriza
leitura de produção, e nenhuma foi feita; a afirmação se limita ao que é
verificável aqui. Um censo anterior desta linhagem registrou população legada VIP
igual a zero, mas isso **não foi reconferido** nesta OS e não é evidência que este
laudo produza.

Se houver legado real, ele é **bloqueio operacional específico**: aqueles direitos
não são atribuíveis com segurança e precisam de estratégia de recuperação
separada. A regra das compras novas não se enfraquece por causa deles.

---

## 7. Os três achados médios

**M-1 — `lineItems` malformado.** Duas defesas agora.
`validarRespostaAssinatura` (propriedade.js) recusa a resposta **inteira** antes
da consolidação, com código fechado; e `consolidarAssinatura` filtra a coleção
antes de percorrê-la. Elemento nulo deixou de virar `TypeError` não tratado —
deixou de virar pílula envenenada reentregue até a retenção do tópico expirar.
`O2b` foi invertido: era o registro do defeito, hoje prova a recusa controlada.

**M-2 — `e.message` de terceiro.** Nenhum sobrou. `MOTIVO` (propriedade.js) é o
conjunto **fechado** do que pode ser persistido, devolvido ou registrado. `Z1`
injeta uma agulha na mensagem da Play e verifica que ela não aparece em documento
nenhum, nem na mensagem, nem nos detalhes que voltam ao cliente — nos dois
caminhos (falha da consulta e falha do fechamento).

*Nota de nomenclatura:* a OS listou os códigos em MAIÚSCULA como exemplo e, na
mesma seção, mandou seguir o padrão existente. O padrão deste codebase para causa
persistida é `minúsculas_com_sublinhado` (`token_superado`, `verificacao_antiga`,
`em_validacao`). Seguiu-se o padrão; os conceitos são os que a OS listou.

**M-3 — `packageName`.** A condição era `corpo.packageName && …`: pacote alheio
recusado, pacote **ausente** aceito — a única conferência de origem desligada
justamente para a mensagem que não declara de onde veio, e é o caminho terminal
que tira o veredito do próprio payload. Hoje ausência é recusa, e
`criarProcessadorRtdn` **não nasce** sem applicationId configurado: configuração
faltando não pode virar uma conferência a menos. Pacote oficial fixado em
`io.github.soniaambrosio.buracomastervip`.

---

## 8. Antes e depois

| Portão | Antes | Depois |
| --- | ---: | ---: |
| Baseline histórica | 79/79 | **79/79** |
| Suíte adversarial | 65/65 | **82/82** |
| Total | 144 | **161**, 0 skip |
| Provas de não-vacuidade | 10/10 | **22/22** |
| Regras (`firebase/testes/entitlement.test.js`) | 22 | **26** |
| Exports do codebase | 5 | **6** (`prepararCompraPlay`) |
| Tentativas de rede nos testes | 0 | **0** (`X4`) |

**Testes que mudaram de asserção porque a autoridade mudou:** cinco na baseline
(`RTDN-05`, `RTDN-06`, `RTDN-16`, `RTDN-19`, `RTDN-21`), mais `RT-04` no arquivo
puro, e nove na adversarial. Cada um explica no corpo o que mudou e por que
continua valendo. Três ficaram **mais fortes**: onde se exigia "o registro não
está recusado", hoje se exige "não há registro nenhum".

**Testes invertidos** (documentavam o defeito): `R6` e `O2b`, mais a observação de
`X3`.

**Testes novos:** `R6b` (invasor e dono simultâneos), `Y1`–`Y15` (a autoridade da
vinculação) e `Z1` (sanitização).

---

## 9. As mutações

22 provas negativas, cada uma desligando uma proteção de **produção** em cópia
temporária não commitada e exigindo vermelho. Todas **NÃO VÁCUAS**. Árvore limpa
antes, entre cada caso e depois.

```bash
npm run prova:nao-vacuidade
```

As doze da seção 14 da OS: gravar antes da consulta (`N1`), ignorar o
identificador (`N2`), confiar no uid de quem chamou (`N3`), vinculação escolhida
pelo cliente (`N4`), aceitar ausência de vinculação (`N5`), `packageName`
opcional (`N6`), aceitar pacote divergente (`N7`), ignorar item malformado
(`N8`), persistir `e.message` (`N9`), expor token em log (`N10`), sucessão por
token ligado sem conferência (`N11`), RTDN dependendo de validação anterior
(`N12`).

### Duas nasceram vácuas, e foi o mais útil que aconteceu

**`N3`** passava com a proteção desligada porque o teste que a cobria (`R4`) roda
no RTDN, onde **não há sessão** — logo não há de quem deduzir. Faltava o caso do
meio: sessão válida, identificador bem formado, e ninguém dono dele. `Y14` foi
escrito para ele, e é justamente o cenário em que a tentação é maior, porque há um
usuário autenticado na frente.

**`N11`** revelou outra coisa: a mutação **não é representável** em
`entitlementStore.js`. Os documentos são escolhidos por `proposta.uid` **antes**
da transação, então nenhuma lógica de dentro dela redireciona a escrita para outra
conta — a propriedade já está decidida quando a transação começa. A mutação foi
movida para onde o risco existe de verdade: a sucessão por `linkedPurchaseToken`
virar larga, com qualquer token substituindo qualquer entitlement do mesmo dono.
`Y15` prova que ela é estreita.

**A prova `R` também foi repontada.** Com `^R ` ficou vácua: a conferência de
propriedade recusa o invasor antes de a transação ser alcançada, então o guarda de
`idempotencia.js` deixou de ser defesa primária e virou defesa em profundidade. O
único cenário que ainda depende dele é um `compras/{hash}` residual do regime
antigo — que `Y13` encena.

---

## 10. Portões executados

| Portão | Resultado |
| --- | --- |
| Baseline original | 79/79, 0 skip, 197 ms |
| Suíte adversarial | 82/82, 0 skip, 683 ms |
| Suíte completa (`npm test`) | 161/161, 0 skip, 551 ms |
| Provas de não-vacuidade | 22/22 não vácuas, árvore limpa |
| Varredura de exports | `X2` — seis funções, `us-central1`, `gcfv2`, tópico e `retry: true` fixados; `prepararCompraPlay` sem segredo |
| Varredura de rede | `X4` — 0 tentativas em 82 testes |
| Varredura de segredos | nenhum padrão de credencial no diff; apenas `token_sintetico_A/B/C` |
| Skips, `catch` vazio, retry infinito | nenhum |
| Regras do Firestore | quatro testes novos escritos (`ENT-23`…`ENT-26`); execução — ver limitações |
| TypeScript (`functions/`) | o diff **não toca** `functions/` — verificável por `git diff --name-only` |
| Flutter analyze | o diff **não toca** `app/` — zero arquivo Dart alterado |
| Testes Flutter do Billing | **não existem**: não há cliente de Billing nesta base |
| Compra real, Play Console, deploy, PR, merge | **nenhum** |

---

## 11. Limitações e riscos residuais

1. **A seção 5 não foi entregue.** Sem cliente de Billing, o campo
   `obfuscatedAccountId` não é preenchido por ninguém — e portanto **nenhuma
   compra é aprovada hoje**. É falha fechada e é o comportamento que a seção 17
   exige, mas é uma porta fechada.

2. **As regras não foram executadas nesta sessão.** Os quatro testes novos estão
   escritos e versionados; rodá-los exige `npm install` em `firebase/testes` mais o
   emulador do Firestore com Java 21. O ambiente desta máquina apresentou lentidão
   patológica de I/O durante a OS — a mesma carga de módulo variou entre 24 s e
   3 min 8 s, e um `require('firebase-functions')` chegou a não completar em cinco
   minutos —, o que torna a execução não confiável como evidência. **A afirmação de
   que as duas coleções estão fechadas vem da leitura do arquivo de regras, não de
   execução.**

3. **`tsc` e `flutter analyze` não foram executados como comparação.** Os dois
   diretórios estão provadamente intocados pelo diff, então o diff de diagnósticos
   é vazio por construção. `flutter analyze` chegou a rodar e devolveu 18 453
   issues — número que **não é comparável** sem o overlay do CI, e que por isso não
   é usado aqui como evidência de nada.

4. **A resposta real da Google nunca foi vista.** Os corpos entram como literais no
   formato documentado. Em particular, que a Play devolva
   `externalAccountIdentifiers.obfuscatedExternalAccountId` para assinatura e
   `obfuscatedExternalAccountId` na raiz para produto avulso é leitura do contrato,
   não observação. Se a forma real divergir, nenhuma compra passa — falha fechada,
   e detectável na primeira compra de teste licenciada.

5. **Legado real, se existir, fica sem caminho.** Ver a seção 6.

6. **A concorrência de dez execuções roda com orçamento de retry elevado.** O
   Firestore falso não tem backoff; `Y3` e `Q3` usam 60 e 80 tentativas. A corrida
   de dois, determinística, roda no orçamento padrão.

7. **`prepararCompraPlay` é uma superfície nova exposta a qualquer conta
   autenticada.** Ela não fala com a Google, não pede segredo, e o pior que um
   abuso produz é um documento por conta. Ainda assim é uma porta a mais, e uma
   porta a mais é uma decisão que vale registro.

---

## 12. Fronteira

Nenhuma alteração fora de `functions-billing/`, `firebase/firestore.rules`,
`firebase/testes/` e `docs/`. `app/`, `functions/` e `functions-moderacao/`
intocados. Nenhum PR, merge em `main`, deploy, compra real ou alteração no Play
Console.
