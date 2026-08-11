# Correção P0 integrada — elegibilidade do jogador + ciclo de vida do VIP

Fecha os dois bloqueadores da homologação P0 integrada: **P0-1** (não existia
fonte real para o estado de elegibilidade) e **P0-3** (Billing sem ciclo de vida
de entitlement). Os dois juntos, porque são a mesma fratura vista de dois lados —
ligar o consumidor sem o ciclo de vida trocaria *"VIP que não funciona"* por
*"VIP que não expira"*.

Conclusão desta OS ao final do documento (§26).

---

## A. Base real

| | |
|---|---|
| branch de origem exigida | `homologacao/p0-integrada-a90557` |
| HEAD exigido | `f9814f9` |
| HEAD encontrado | `f9814f9` — **confere** |
| ancestralidade | `f9814f9` é ancestral do commit final; nenhuma branch de origem foi tocada |
| branch da sessão (recebida) | `claude/p0-elegibilidade-vip-lifecycle-5c3943` @ `fb9edb5` |
| o que era `fb9edb5` | `origin/main` — o placeholder de sempre (`main.dart` solto, commit "noop"), sem `app/`, sem `functions*`, sem `firebase/` |
| ação | `reset --hard f9814f9` na branch da sessão, antes de qualquer edição |
| commit final | `f2b06c1` |

### Divergência de nomenclatura, declarada

A OS §2 sugere `correcao/p0-elegibilidade-vip-lifecycle`. O worktree desta sessão
está preso a `claude/p0-elegibilidade-vip-lifecycle-5c3943`, criada pelo harness.
Trabalhei nela — é exclusiva desta OS e não é reaproveitada de sessão anterior —
e criei `correcao/p0-elegibilidade-vip-lifecycle` **apontando para o mesmo
commit**, para que o nome pedido exista. As duas são o mesmo `f2b06c1`.

### Nota de ambiente

O `git` desta máquina recusa o worktree por *dubious ownership* (F: não registra
ownership). Diferente da sessão anterior, precisei acrescentar a exceção ao
`.gitconfig` global — o `-c safe.directory=*` por comando não bastava para o
worktree novo. É a mesma linha que já existia para outros 12 worktrees deste
repositório.

### Arquivos e módulos encontrados

| módulo | o que estava lá |
|---|---|
| `functions/src/index.ts` | `montarPerfil` lendo `players/{uid}` — a leitura órfã |
| `functions-billing/index.js` | `validarCompraPlay`, e só ela. Gravava `vip: true` em `usuarios/{uid}` |
| `functions-moderacao/src/index.ts` | `consolidarSancoes` gravando `playerModeration/{uid}` — íntegro, com produtor real |
| `app/lib/torneios/eligibility.dart` | domínio correto, honrando `perfil.suspenso` e `assinaturaAtiva` |
| `app/lib/moderacao/sancao.dart` | `EstadoModeracao.fromMap` + `suspensoEm(agora)` — já prontos para serem consumidos |
| `firebase/firestore.rules` | sem `match /players`; `usuarios/` declarado LEGADO no cabeçalho |

Confirmação do diagnóstico da homologação: `players` aparecia **uma vez** em toda
a árvore, e era a própria leitura.

---

## B. Contrato escolhido

```
  playerModeration/{uid}         playerEntitlements/{uid}
  dono: functions-moderacao      dono: functions-billing
  suspensão, prazo, permanência  estado do VIP, até quando, produto
            \                             /
             \                           /
              v                         v
              comporPerfil()   (app/lib/elegibilidade/)
                      |
                      v
              PerfilElegibilidade
                      |
                      v
              inscrever() / avaliarElegibilidade()
```

### Ownership

| fonte | dono | quem escreve | quem lê |
|---|---|---|---|
| `playerModeration/{uid}` | moderação | `functions-moderacao` (Admin SDK) | o dono, o admin, e a composição |
| `playerEntitlements/{uid}` | billing | `functions-billing` (Admin SDK) | o dono, o admin, e a composição |
| `playerEntitlements/{uid}/interno/billing` | billing | `functions-billing` | **ninguém** — nem dono, nem admin |
| `billingEvents/{messageId}` | billing | `functions-billing` | admin |

O Billing **não escreve** em `playerModeration`. A moderação **não escreve** em
`playerEntitlements`. Nenhum dos dois escreve num terceiro documento agregado.

### Por que composição e não um documento agregado

Um `players/{uid}` de verdade — com os campos copiados para lá — resolveria o
sintoma e criaria dois problemas novos: uma cópia que diverge da fonte no
primeiro erro de propagação, e um segundo produtor por domínio que alguém precisa
lembrar de manter. Composição na leitura não tem cópia, logo não tem o que
divergir. O preço é uma leitura a mais por inscrição — barato perto de uma sanção
que não pega.

**Não existe snapshot derivado nesta correção.** O §6 da OS previa o caso; ele
não foi necessário.

### Papel de `usuarios/`

Continua sendo o namespace legado que o cabeçalho de `firestore.rules` declara —
e **deixou de participar do VIP**:

- o Billing **parou de gravar** `vip`, `vipExpiraEm`, `vipProdutoId` e
  `vipAtualizadoEm` ali. Aquele `vip` era monotônico: nada no sistema o removia.
  Mantê-lo criaria as duas fontes concorrentes permanentes que a §17 proíbe;
- `fichas` e o resto do legado continuam onde estavam. O bloco de regras de
  `usuarios/` **não foi tocado** e continua barrando os campos de servidor
  (provado em ENT-20);
- a única coisa que ainda lê `vip` lá é a migração única (§C, migração).

Nenhum consumidor lê `usuarios/` — verificado por varredura em `app/lib`: o app
nunca leu essa coleção, `PerfilService` ainda serve números com `statsDemo`.

### Destino de `players/`

Removida do código. **Não foi criada**, não recebeu regra, e o fecho padrão de
`firestore.rules` continua negando-a — provado explicitamente em ENT-21, para que
uma ressurreição acidental quebre um teste.

### Onde mora a pergunta "tem VIP agora?"

Em **um lugar só**: `EntitlementVip.vigenteEm` (`app/lib/elegibilidade/entitlement.dart`).

```
vigente = vipAtivo  &&  estado concede acesso  &&  agora < expiraEm
```

As três condições juntas. `vipAtivo` é o veredito do Billing na última
verificação autoritativa; `estado` diz de que natureza ele era; `expiraEm` é o
limite que a Google devolveu. Um documento incoerente (`revogado` com `vipAtivo:
true`) **não concede** — divergência recusa, não autoriza.

O Billing **não reimplementa esse predicado**. Ele grava fatos, e a varredura de
vencimento dele é uma *consulta* ao Firestore (`vipAtivo == true && expiraEm <=
agora`), não uma segunda cópia da regra. Foi para não ter uma segunda definição
de "o que é ser VIP" — o risco que `visao_espectador.dart` documenta no próprio
cabeçalho.

### Por que a composição é Dart

Quem consome é o domínio de torneios (Dart). Quem produz o estado de moderação é
`consolidar()` (Dart). Escrever a composição em TypeScript criaria uma terceira
leitura das mesmas regras, na única linguagem onde nenhum teste do projeto a
exercitaria. Em Dart, a costura inteira roda num teste puro. A Cloud Function
chama pela ponte que já existia (`js_bridge.dart` → `functions/src/domain.ts`):
ela **lê os dois documentos e obedece**, sem interpretar nenhum dos dois. Foi
interpretar por conta própria, com nome de campo escolhido no TypeScript, que
produziu o defeito.

### O que ficou declaradamente ausente

`nivel`, `posicaoRanking` e `conquistas` entram na composição como **ausentes**:
não existe autoridade nesta árvore que publique ranking, nível ou conquista. Os
critérios correspondentes recusam por `dado_indisponivel` /
`classificacao_insuficiente` — que é exatamente o que o sistema já fazia na
prática (o documento nunca existia), agora declarado em vez de acidental. Os
parâmetros existem para ligar a fonte no dia em que ela existir.

---

## C. Ciclo de vida

Todos os estados abaixo têm teste. `vipAtivo` é o campo gravado; a coluna
"entra em torneio VIP?" é o que o consumidor decide, com o relógio.

| evento | estado anterior | estado novo | vipAtivo | expiraEm | entra? | efeito |
|---|---|---|---|---|---|---|
| compra validada (ACTIVE) | `nunca_teve` | `ativo` | `true` | fim do período | **sim** | direito nasce |
| renovação (RTDN 2 → reconsulta) | `ativo` | `ativo` | `true` | **estendido** | sim | era o defeito: o prazo ficava congelado |
| carência (IN_GRACE_PERIOD) | `ativo` | `em_carencia` | `true` | mantido | sim | pagamento falhou, Google ainda tenta |
| conta em espera (ON_HOLD) | `em_carencia` | `em_espera` | `false` | mantido | não | carência acabou sem pagar |
| recuperação (RTDN 1) | `em_espera` | `ativo` | `true` | novo | sim | reconsulta autoritativa |
| pausa (PAUSED) | `ativo` | `pausado` | `false` | mantido | não | pausa pedida pelo jogador |
| cancelamento (CANCELED) | `ativo` | `cancelado_vigente` | `true` | **mantido** | **sim, até expirar** | renovação desligada; período pago continua |
| vencimento do cancelado | `cancelado_vigente` | `expirado` | `false` | mantido | não | pelo relógio, na leitura e na varredura |
| expiração (EXPIRED / relógio) | qualquer | `expirado` | `false` | mantido | não | prazo é o fato que produziu a conclusão |
| revogação (RTDN 12) | qualquer | `revogado` | `false` | **agora** | não | acesso encerrado na hora, terminal |
| reembolso (`voidedPurchase`) | qualquer | `reembolsado` | `false` | **agora** | não | estorno/chargeback, terminal |
| compra nova após terminal | `revogado`/`reembolsado` | `ativo` | `true` | novo período | sim | terminal prende o *token*, não a pessoa |
| compra pendente (PENDING) | — | `pendente` | `false` | — | não | existe mas não foi paga |
| estado desconhecido | qualquer | `desconhecido` | `false` | — | não | plataforma mudou → recusa investigável |

**O caso que separa esta correção de um `vip: true` renomeado** é a linha
"expiração": o consumidor recusa um direito vencido **mesmo com `vipAtivo: true`
ainda gravado**, porque a vigência é avaliada contra o relógio da operação. A
varredura só serve para o *documento* também contar a verdade — se ela atrasar
cinco minutos ou falhar por uma semana, ninguém entra de graça.

---

## D. RTDN / reconciliação

### Modelo

A notificação é **sinal, não veredito**. Fora dos dois desfechos terminais, nada
é derivado do payload: a mensagem manda *perguntar* à Google qual é o estado
agora (`purchases.subscriptionsv2.get`). Confiar no payload seria confiar num
evento que pode ter sido emitido antes de outro já processado.

As duas exceções são fatos que a consulta de estado não expressa:

- **revogação** (`notificationType: 12`) — a Google não devolve um
  `subscriptionState` que diga "revogado";
- **anulação** (`voidedPurchaseNotification`) — idem para estorno.

Esperar a consulta para descobrir deixaria uma janela em que o reembolsado
continua VIP.

### Origem

`packageName` da mensagem é conferido contra o `applicationId` oficial. O tópico
Pub/Sub só aceita publicação da Google, mas um projeto com mais de um
`applicationId` apontando para o mesmo tópico entregaria evento alheio ali dentro.

### Idempotência

`billingEvents/{messageId}` é escrito na **mesma transação** do efeito: ou os dois
acontecem, ou nenhum. Há um atalho barato de leitura antes da chamada de rede,
mas ele não é a barreira — a barreira está dentro da transação, onde a corrida
existe. Regra do Firestore nega criação por cliente, inclusive admin: um
documento plantado ali faria o sistema descartar como "repetida" a notificação de
estorno quando ela chegasse (ENT-19).

### Ordem

O carimbo comparado **não é o do evento** — é o da *consulta* que produziu a
proposta (`verificadoEm`), capturado **antes** da chamada de rede. Uma resposta
que demorou dez segundos descreve o mundo de dez segundos atrás.

- proposta mais velha que a última verificação gravada → `verificacao_antiga`,
  descartada;
- evento antigo que chega depois → produz consulta *nova*, e consulta nova nunca
  regride;
- o carimbo `ultimoEventoEm` só anda para a frente.

### Titularidade sob evento

A Google conhece o token e nada sobre identidade. O elo é `compras/{hash}`, que
`validarCompraPlay` grava com o uid do **contexto autenticado**. Sem registro
não há titular comprovável e o evento é descartado — atribuir direito por palpite
seria pior que perder o evento.

Evento sobre token que **não é o vigente** → `token_superado`. É o que impede a
expiração da assinatura anterior de derrubar a assinatura nova.

### Desfecho terminal

Revogado e reembolsado do token vigente são **irreversíveis para aquele token**.
Uma leitura atrasada que ainda diga `ACTIVE` vira `terminal_preservado` — não
concessão. O único caminho de volta é uma compra nova, que entra pelo ramo de
titularidade.

### Retries e falha externa

`retry: true` no consumidor é deliberado: falha na Play Developer API volta como
reentrega do Pub/Sub, e essa **é** a reconciliação posterior deste desenho. Como
o registro de "já processei" só é gravado junto com o efeito, a reentrega encontra
trabalho a fazer — e não um evento marcado concluído sem ter concluído nada.

Três caminhos de reconciliação, com propósitos distintos:

| caminho | gatilho | consulta a Google? | para quê |
|---|---|---|---|
| `notificacoesPlay` | RTDN | sim | o normal |
| `reconciliarEntitlements` | agendado, 30 min | **não** | rede de segurança: fecha vencidos mesmo sem RTDN, sem API e sem tópico configurado |
| `reconciliarEntitlementDoJogador` | admin | sim | divergência relatada, notificação perdida |

### Concorrência

Toda escrita de entitlement passa por `aplicarProposta`, que decide com o
documento **relido dentro da transação** — a mesma disciplina que `podeConceder`
já impunha ao crédito. Não existe "ler, decidir fora, escrever depois". Duas
verificações em voo (RTDN + reconciliação manual, por exemplo) resolvem por
`verificadoEm`: vence quem consultou a Google por último, **não** quem gravou por
último (DA-14).

`set` sem `merge` é deliberado: o estado consolidado é completo, e um merge
deixaria campo velho de um estado anterior sobrevivendo ao lado do novo.

### Migração do legado — dito sem maquiagem

`compras/{hash}` guarda o **hash** do token, nunca o token. Para as compras
anteriores a esta OS não existe, em lugar nenhum da árvore, o valor com que se
pergunta à Play. A única informação disponível sobre elas é `vipExpiraEm`, que
veio da Google no dia da compra.

`migrarEntitlementsLegado` (admin, idempotente, com cursor) cria o entitlement a
partir dela, com `origem: 'legado_usuarios'`. O que isso significa:

- **vale até o prazo que já estava gravado, e nem um minuto a mais**;
- se a assinatura renovou, quem repõe o prazo é a próxima notificação ou a
  próxima validação — as duas carregam o token;
- se foi estornada no meio, o sistema só descobre no vencimento. Janela de erro:
  no máximo um período de cobrança;
- `usuarios/{uid}` com `vip: true` e **sem** `vipExpiraEm` é pulado e contado —
  sem prazo não dá para afirmar que o direito vale, e afirmar o que não se sabe é
  o defeito que esta OS veio consertar.

A alternativa seria tirar o VIP de todo assinante pagante no dia da virada.
`decidirAtualizacao` recusa migração sobre entitlement já verificado
(`legado_nao_sobrescreve`, DA-11), então rodar a migração duas vezes, ou depois de
o jogador já ter renovado, não estraga nada.

**Quando o legado deixa de participar:** assim que a migração roda e cada
assinante passa por uma renovação (que reescreve com `origem: 'play'`). A remoção
definitiva dos campos `vip*` de `usuarios/` continua sendo a migração com OS
própria que o cabeçalho de `firestore.rules` já previa — agora sem consumidor
nenhum dependendo deles.

---

## E. Segurança

### Identidade e titularidade

- `validarCompraPlay` continua tirando o uid do `request.auth` — o app não manda
  uid, e uid mandado por cliente é falsificável;
- `conferirTitularidade` continua sendo avaliada **antes** do estado, e de novo
  dentro da transação de concessão. Nada disso foi tocado;
- o elo `uid ↔ produto ↔ purchaseToken ↔ entitlement` é `compras/{hash}`, escrito
  só com identidade autenticada;
- RTDN sem titular comprovável não concede a ninguém;
- `reconciliarEntitlementDoJogador` e `migrarEntitlementsLegado` exigem o claim
  `admin`, que vem de custom claim e nunca de documento.

### Rules

Nenhuma regra existente foi afrouxada. Os blocos acrescentados:

```
match /playerEntitlements/{uid} {
  allow read:  if ehDono(uid) || ehAdmin();
  allow write: if false;                       // inclusive dono e admin

  match /interno/{documento} {
    allow read, write: if false;               // ninguém, nunca
  }
}

match /billingEvents/{messageId} {
  allow read:  if ehAdmin();
  allow write: if false;
}
```

`allow write: if false` fecha a porta do **aplicativo**; as Functions usam Admin
SDK e ignoram estas regras — o princípio já declarado no cabeçalho do arquivo.

Provado no emulador: o jogador não cria entitlement, não se concede VIP, não
estende `expiraEm`, não troca `estado` nem `produtoId`, não apaga o documento, e
nem o admin escreve pelo cliente. Leitura do próprio é permitida (a tela precisa
poder dizer "seu VIP vale até tal dia"); leitura de terceiro é negada, o que
também impede enumerar quem paga.

### Dados sensíveis

O documento que o jogador lê **não contém** `purchaseToken`, hash, `orderId`,
carimbos de verificação nem tipo do último evento. Isso é verificado por um teste
que lista as chaves permitidas (DOC-01) — se alguém acrescentar um campo sensível
ao documento público, o teste quebra.

A separação em dois documentos existe porque regra do Firestore libera o
**documento inteiro**: não há como conceder `vipAtivo` e esconder o token no
mesmo lugar. É a mesma solução que a moderação usou entre `reports` (interno) e
`reportReceipts` (do denunciante).

#### O `purchaseToken` em claro — decisão declarada

O token cru é gravado em `playerEntitlements/{uid}/interno/billing`. A OS §5.2
pede para não persistir token em claro se o código já adota proteção, então a
decisão precisa ser justificada e não escondida:

- `idempotencia.js` não guardava o token porque ali ele servia de
  **identificador**, e para identificar o hash basta (o comentário original diz
  exatamente isso: "não há motivo para guardar o valor bruto como identificador");
- aqui ele é **credencial de consulta**, e hash não consulta nada. Sem o token não
  existe consulta autoritativa fora do instante em que a notificação chega: nem
  reconciliação manual de um entitlement travado, nem reprocessamento depois de a
  Play Developer API ficar indisponível. A migração desta OS é a prova do custo de
  não tê-lo guardado — as compras antigas não podem ser reconsultadas;
- mitigações, todas verificáveis: subcoleção com `allow read, write: if false`
  para cliente **e** para admin (ENT-13, ENT-14, ENT-15); ausente do documento que
  o jogador lê (DOC-01); e nenhum log deste codebase o imprime — todo log usa
  `rotuloToken`, que corta o **hash** em oito caracteres (DOC-06).

Se a Sônia preferir não guardar o token, o caminho é abrir mão de
`reconciliarEntitlementDoJogador` e do reprocessamento pós-falha, ficando só com
RTDN + varredura por relógio. É uma troca real, e por isso está escrita aqui em
vez de decidida em silêncio.

---

## F. Testes

Todos os comandos abaixo rodaram nesta máquina, nesta árvore, com o código em
`f2b06c1` — o commit seguinte só acrescenta este documento e não toca em código.

| suíte | comando | testes | ✓ | ✗ | skip | não executado |
|---|---|---|---|---|---|---|
| Dart — completa, com staging de seeds | `flutter test` em `app/` | **536** | 536 | 0 | 0 | — |
| Dart — sem staging (baseline) | `flutter test` em `app/` | 192 + 4 suítes que falham no *load* | 192 | 4 | 0 | — |
| Regras Firestore — as quatro suítes, um só `firestore.rules` | `firebase emulators:exec --only firestore --project demo-bmv "cd firebase/testes && npm run test:integrado"` | **93** | 93 | 0 | 3 suítes | — |
| Billing (Functions) | `npm test` em `functions-billing/` | **55** | 55 | 0 | 0 | — |
| Moderação (Functions) | `npm test` em `functions-moderacao/` | **13** | 13 | 0 | 0 | — |
| Torneios (Functions) | `npx tsc --noEmit` em `functions/` | typecheck | exit 0 | — | — | — |
| Bundle Dart→JS | `npm run build:domain` em `functions/` | compilação | exit 0 | — | — | — |
| Ponte compilada, do Node | verificação pontual (abaixo) | 7 chamadas | 7 | 0 | — | não é suíte permanente |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | em `app/` | 42 issues | 0 erros | — | — | — |

**Total das suítes automatizadas: 697 testes, 697 aprovados, 0 falhos.**

### Testes novos, por natureza

| arquivo | casos | o que protege |
|---|---|---|
| `app/test/elegibilidade/costura_p0_test.dart` | 29 | **a costura**: produtor real → documento → composição → consumidor |
| `functions-billing/test/entitlement.test.js` | 42 | o ciclo de vida: consolidação, notificação, ordem, terminal, formato gravado |
| `firebase/testes/entitlement.test.js` | 22 | quem escreve e quem lê o direito |

### Fronteira dos testes, declarada

A OS §12 pede para não chamar de integração o que não é:

- **teste unitário** — `functions-billing/test/entitlement.test.js`. As respostas
  da Play Developer API entram como **literais**, copiados do formato documentado
  de `purchases.subscriptionsv2`. Não há rede, não há mock de cliente HTTP, e não
  se afirma nada sobre a API real responder assim hoje;
- **teste de costura entre módulos** — `costura_p0_test.dart`. O estado de
  moderação nasce de `avaliarSancao` + `consolidar()`, o **mesmo código** que a
  Cloud Function executa. Nenhuma flag construída à mão;
- **teste de contrato entre runtimes** — o grupo `CT-*` em
  `entitlement.test.js`. O produtor é JavaScript e o consumidor é Dart, e não há
  runtime que rode os dois. Cada documento do lado Dart é construído pelo produtor
  de verdade no lado JS e comparado campo a campo com o literal do outro lado.
  **É um contrato espelhado com estopim nos dois lados, e não uma prova
  automática única** — mudar um nome de campo, um formato de data ou um valor de
  `estado` quebra um dos dois arquivos;
- **teste de regras** — `firebase/testes/entitlement.test.js`, emulador de
  Firestore;
- **teste que exigiria ambiente externo real** — RTDN de verdade chegando por
  Pub/Sub com tópico configurado na Play Console, e a conferência de que a
  resposta real da Google tem os campos que este código lê. **Não existe e não foi
  simulado.** Exigem projeto implantado e credencial de conta de serviço.

### SKIP e não executado

| item | situação | por quê |
|---|---|---|
| `registrarDenuncia`, `bloqueio pela Function` (moderacao.test.js) | **SKIP** | exigem o emulador de Functions; rodei `--only firestore` |
| `claimPioneerKit` (seguranca.test.js) | **SKIP** | idem |
| 4 suítes Dart sem staging de seeds | **falham no load** | dependência de CWD pré-existente (ver abaixo) |
| CI (`ci-os-integracao.yml`) | **não executado** | o workflow só dispara por `workflow_dispatch` e só a partir da branch padrão; sem merge, nenhum run acontece. É o P1-2 da homologação, e continua valendo |
| RTDN ponta a ponta | **não executado** | ambiente externo |

Nada foi marcado como aprovado por não ter rodado.

### Staging de seeds — feito, desfeito, conferido

Os 536 do Dart exigiram o staging temporário que o CI faz em `app_build/`:

```
app/data/torneios/*.json  -> app/test/torneios/data/
app/data/colecoes/*.json  -> app/test/colecoes/data/
```

Foi **desfeito** e a árvore conferida (`git status` limpo além das alterações da
OS). Nada dele foi commitado. Sem o staging, as mesmas 4 suítes pré-existentes
falham no *load* — não é regressão desta OS, e corrigir a localização dos seeds
não era necessário para a cobertura nova, então **não foi feito** (§16).

Efeito colateral registrado: rodar a suíte completa regenera dois PNGs de
evidência em `app/test/colecoes/evidencias/`. Restaurados com `git checkout`.

### Verificação pontual da ponte compilada

Não é suíte permanente — é a prova de que a nova entrada da ponte atravessa o
`dart compile js` e responde como a Cloud Function vai chamá-la:

```
entradas da ponte: 13   comporElegibilidade? function
vazio        -> {"userId":"ana", ..., "assinaturaAtiva":false, "suspenso":false}
vip ativo    -> true
vip vencido  -> false
revogado     -> false
suspenso     -> true
suspensão vencida -> false
documento ilegível -> {"erro":"FormatException: Invalid date format\nxx"}
```

A última linha importa: entrada corrompida atravessa como erro e derruba a
operação. Não existe "ignorar o que não entendi" — um estado de moderação
corrompido que virasse `suspenso: false` liberaria justamente quem está punido.

---

## G. Casos P0 — resultado explícito

Todos abaixo passam pela costura inteira (documento → `comporPerfil` → `inscrever`),
contra um torneio de acesso `vip`. O seed aprovado tem **quatro** torneios VIP, então
isto não é hipótese.

| caso | estado de origem | resultado | teste |
|---|---|---|---|
| **A — suspenso** | `suspensaoTemporaria` vigente, produzida por `avaliarSancao` + `consolidar()` | **inscrição recusada** (`perfilSuspenso`), mesmo com VIP em dia | A-01 |
| A′ — banido | `suspensaoPermanente` | recusado, sem depender de prazo | A-02 |
| A″ — suspensão vencida | `suspensoAte` no passado | **entra** — o prazo é reavaliado na leitura, sem job para desligar flag | A-03 |
| A‴ — sanção revogada | `status: revogada` | entra | A-04 |
| A⁗ — só silêncio de chat | `chatSilenciadoAte` vigente | **entra** — punição de chat não vira punição de competição | A-05 |
| **B — VIP válido** | `ativo`, prazo no futuro | **inscrição permitida** | B |
| **C — sem VIP** | nenhum entitlement | **recusada** (`requisitoVipNaoAtendido` / `semAssinatura`) | C |
| **D — VIP expirado** | `ativo` com prazo vencido, `vipAtivo` **ainda `true`** | **recusada** — o relógio desmente o documento | D |
| D′ — após a varredura | `expirado`, `vipAtivo: false` | recusada | D-2 |
| **E — VIP revogado** | `revogado` (documento como o Billing grava) | **recusada** | E |
| E′ — revogado com prazo futuro | documento incoerente | recusada — o estado terminal sozinho basta | E-2 |
| **F — VIP reembolsado** | `reembolsado` | **recusada** | F |
| F′ — reembolsado com prazo futuro | documento incoerente | recusada | F-2 |
| **G — cancelado, período vigente** | `cancelado_vigente`, prazo no futuro, `renovacaoAutomatica: false` | **VIP permanece ativo até `expiraEm`** | G |
| G′ — o mesmo, após o prazo | prazo vencido | recusada | G-2 |
| H — carência × conta em espera | `em_carencia` / `em_espera` | uma concede, a outra não | H |
| I — torneio público | sem entitlement | entra: público não exige VIP | I |

Fail-closed, sete casos adicionais: documento incoerente, estado desconhecido,
direito sem prazo, documento vazio, documento ausente, uid do corpo divergente do
caminho, e o instante exato do vencimento (FC-01..FC-07).

---

## H. Regressões

### P0-2 — continua corrigido

`functions-moderacao/test/idempotencia.test.js`: **13/13**, verde. Nenhum arquivo
da moderação foi tocado por esta OS:

- `decidirSobreReserva` — intacto;
- `conferirConformidade` / conferência de titularidade e intenção — intactos;
- os três desfechos `EXECUTAR` / `REPETICAO` / `CONFLITO` — intactos;
- `77eff2d` é ancestral de `f2b06c1`.

A cobertura **aumentou** de lado: A-01..A-06 provam que a sanção agora produz
efeito no consumidor, que era o outro lado do mesmo contrato.

### Suíte anterior

| suíte | antes (`f9814f9`) | agora (`f2b06c1`) | diferença |
|---|---|---|---|
| Dart | 507 ✓ | 536 ✓ | +29 — todos novos, nenhum alterado |
| Regras | 71 ✓ | 93 ✓ | +22 — todos novos; os 71 anteriores intactos |
| Billing | 13 ✓ | 55 ✓ | +42 — os 13 de idempotência intactos |
| Moderação | 13 ✓ | 13 ✓ | inalterada |
| `tsc` torneios | exit 0 | exit 0 | — |
| `flutter analyze` | 42 issues, 0 erros | 42 issues, 0 erros | idêntico; nenhum arquivo desta OS produz issue |

Nenhum teste existente foi editado, renomeado ou removido.

### Regras antigas não afrouxadas

Conferido por teste, e não por leitura: `usuarios/{uid}` continua barrando campos
de servidor (ENT-20), `players/{uid}` continua negada pelo fecho padrão (ENT-21),
`playerModeration/{uid}` continua fechada para escrita inclusive para o dono
(ENT-22). As duas suítes de não-regressão que já existiam (`o fecho padrão ainda
nega caminho não declarado`, `o segundo bloco users/{uid} não afrouxou o
inventário`) continuam verdes.

---

## I. Pendências

Só problemas reais encontrados nesta árvore.

### P1 — estorno de compra avulsa não devolve as fichas

Descoberto ao escrever o consumidor de RTDN. `voidedPurchaseNotification` de um
produto **consumível** é corretamente ignorada pelo entitlement (consumível não
gera VIP), mas ninguém debita as fichas creditadas. Um jogador pode comprar
fichas, gastá-las e pedir estorno.

Não corrigido de propósito: é economia, e a §21 desta OS põe economia fora de
escopo. Exige decisão de produto (saldo pode ficar negativo? e se as fichas já
foram gastas?) e não é elegibilidade nem ciclo de vida do VIP.

### P1 — duas carteiras coexistem

`usuarios/{uid}.fichas` (Billing) e `wallets/{uid}.fichas` (torneios) são
carteiras diferentes do mesmo jogador. Fichas compradas não pagam inscrição de
torneio, e prêmio de torneio não aparece na carteira da loja.

Pré-existente, ortogonal a esta OS, e não tocado. Registrado porque é o mesmo
padrão de fratura que produziu P0-1 — dois donos, dois documentos, nenhum
contrato — e vai reaparecer quando um torneio com `custoEntrada` abrir.

### P1 — os quatro da homologação continuam abertos

Nenhum foi tocado, conforme §20: freios de abuso contornáveis por concorrência;
CI não executando moderação/rastreabilidade/espectador; `NÃO EXECUTADO` não
reprovando o portão; `VisaoEspectador` sem consumidor de produção.

Impacto desta OS sobre eles: o CI **também não executa** as três suítes novas.
`ci-os-integracao.yml` não foi editado — uma edição ali não é verificável nesta
sessão (sem merge na branch padrão, nenhum run acontece), e mexer nele sem poder
provar seria exatamente o "verde que não significa nada" que a §15 proíbe.

### P2 — o tópico RTDN precisa ser criado e configurado

`play-billing-rtdn` está declarado no código e **não existe** em lugar nenhum
ainda. Enquanto a Play Console não apontar as notificações para ele, o ciclo de
vida funciona apenas por: validação (compra e renovação, quando o app chama) e
varredura por relógio (expiração). Revogação e reembolso **não chegam** sem RTDN.

Não é defeito desta entrega — é a etapa de implantação que ela habilita. Está
aqui para não ser esquecida: **sem o tópico configurado, reembolso não retira
VIP.**

### P2 — nível, ranking e conquistas seguem sem autoridade

Já registrado em §B. Os critérios `nivel_minimo`, `classificacao_maxima` e
`conquista` recusam por dado indisponível. Nenhum torneio do seed aprovado os
usa hoje.

---

## J. Git

| | |
|---|---|
| branch de trabalho | `claude/p0-elegibilidade-vip-lifecycle-5c3943` |
| branch com o nome da OS | `correcao/p0-elegibilidade-vip-lifecycle` (mesmo commit) |
| hash base | `f9814f9` (`homologacao/p0-integrada-a90557`) |
| hash do código | `f2b06c1` |
| hash final local | o commit **deste documento**, imediatamente acima de `f2b06c1` |
| commits desta OS | **2** — um de código, um de documentação |
| upstream configurado | **não** (`no upstream configured`) |
| branch remota | **não existe** |
| hash remoto | **não se aplica** |
| push | **NÃO FEITO** — ver abaixo |
| merge em `main` / `consolidacao/apk-geral-bmv` / qualquer branch compartilhada | **NÃO FEITO** |
| rebase, force push, alteração de branch de origem | **NÃO FEITO** |
| deploy / publicação | **NÃO FEITO** |
| árvore de trabalho | **limpa** |

Sobre o push: **não é falta de permissão** — o remoto `origin` existe e está
acessível. Não publiquei porque publicar é ação externa e a OS não a exige;
`git push -u origin claude/p0-elegibilidade-vip-lifecycle-5c3943` publica sem
tocar em nenhuma outra branch, se a Sônia quiser. O commit está íntegro
localmente e nenhuma branch de outra sessão foi tocada.

### Arquivos

```
novos:
  app/lib/elegibilidade/entitlement.dart         a definição de vigência
  app/lib/elegibilidade/composicao.dart          a fronteira única
  app/test/elegibilidade/costura_p0_test.dart    29 casos de costura
  functions-billing/entitlement.js               o ciclo de vida, puro
  functions-billing/test/entitlement.test.js     42 casos
  firebase/testes/entitlement.test.js            22 casos de regras

alterados:
  app/lib/torneios/js_bridge.dart      + comporElegibilidade
  functions/src/domain.ts              + a entrada tipada da ponte
  functions/src/index.ts               montarPerfil lê as fontes reais
  functions-billing/index.js           entitlement, RTDN, reconciliação, migração
  functions-billing/package.json       alvo de teste novo
  firebase/firestore.rules             bloco 2b/3
  firebase/firestore.indexes.json      índice da varredura de vencimento
  firebase/testes/package.json         suíte nova nos dois alvos
```

---

## 26. Conclusão

### Resultado A — APTO PARA REHOMOLOGAÇÃO

A costura que faltava existe, nasce das fontes reais e está testada ponta a
ponta:

```
Google Play  ->  playerEntitlements/{uid}  \
                                            >  elegibilidade  ->  torneios
Moderação    ->  playerModeration/{uid}    /
```

- **banido não entra** — e a prova parte de `avaliarSancao` + `consolidar()`, não
  de uma flag construída à mão;
- **VIP válido entra** — o assinante pagante deixa de ser recusado nos quatro
  torneios VIP do seed aprovado;
- **VIP expirado não entra** — inclusive antes de qualquer job rodar;
- **VIP revogado não entra**;
- **VIP reembolsado não entra**;
- **cancelamento não encerra o período já pago**;
- **o cliente não consegue alterar nenhum desses fatos** — provado no emulador,
  para o dono e para o admin.

P0-2 continua corrigido. Nenhuma regra foi afrouxada. Nenhum teste anterior foi
alterado.

### O que essa aprovação NÃO diz

Três coisas, para que ninguém leia mais do que está escrito:

1. **O tópico RTDN não existe ainda.** Sem ele configurado na Play Console,
   revogação e reembolso não chegam ao sistema. O código está pronto e testado; a
   ligação é etapa de implantação (P2 em §I). **Esse é o item que separa "correto"
   de "funcionando em produção".**
2. **A migração do legado precisa ser executada** (`migrarEntitlementsLegado`)
   antes de qualquer torneio VIP abrir inscrição, senão assinante antigo entra
   como "sem VIP". Ela é admin, idempotente e com cursor.
3. **Nada disto rodou no CI.** O portão continua manual e parcial (P1-2 da
   homologação), e as três suítes novas também não estão nele. Os números de §F
   são desta máquina.

O portão P0 **pode ser reaberto para homologação**. Se ele será aprovado depende
de a rehomologação confirmar estes números num ambiente que não seja o meu — e,
para a parte de Billing, de o tópico RTDN existir.
