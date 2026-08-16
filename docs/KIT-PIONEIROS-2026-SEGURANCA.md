# Kit Pioneiros 2026 — confirmações de segurança

Cada afirmação abaixo aponta para onde ela é imposta no código e para o caso que
a prova. Nada aqui depende de boa fé do aplicativo.

| # | Afirmação | Situação |
| --- | --- | --- |
| 1 | `claimPioneerKit` exige autenticação | ✅ imposto |
| 2 | O UID vem do contexto autenticado | ✅ imposto |
| 3 | O cliente não concede itens | ✅ imposto |
| 4 | Funções administrativas restritas a admin | ✅ imposto |
| 5 | Chamadas repetidas e concorrentes são idempotentes | ✅ imposto |
| 6 | As regras impedem acesso ao inventário de terceiros | ✅ imposto |
| 7 | App Check previsto para ativação antes da abertura | ✅ pronto, desligado |

> **Uma ressalva honesta sobre a evidência.** Os itens 1–4, 6 e 7 são verificáveis
> por leitura do código, e os pontos exatos estão citados abaixo. O item 5 tem
> prova em memória (113 casos, incluindo repetição e reconciliação), mas a prova
> **contra concorrência real** exige os emuladores. A suíte está escrita em
> `firebase/testes/seguranca.test.js` e **não foi executada nesta entrega** — não
> há emulador de pé nem autorização para instalar dependências. É o único item da
> lista cuja evidência ainda é por construção, e está no runbook como passo 7.

---

## 1. `claimPioneerKit` exige autenticação

`firebase/functions/index.js`:

```js
const uid = request.auth && request.auth.uid;
if (!uid) {
  throw new HttpsError('unauthenticated', 'e preciso estar autenticado para resgatar');
}
```

É a primeira linha da função, antes de qualquer leitura. Uma chamada anônima não
chega a tocar o Firestore.

## 2. O UID vem do contexto autenticado

A função **não tem parâmetro de UID**. `request.auth.uid` é preenchido pelo
próprio runtime a partir do token verificado do Firebase Auth; o cliente não
consegue forjá-lo sem a chave privada do projeto.

O adaptador reforça isso do outro lado — `app/lib/colecoes/colecao_firebase.dart`
chama sem payload nenhum:

```dart
final resposta = await chamada.call<Map<String, dynamic>>();
```

E a elegibilidade **não entra por parâmetro**: `lerEvidencia(uid, tx)` busca
`campaigns/{campaignId}/eligible/{uid}` dentro da própria transação. Mandar
`{uid: 'outra_pessoa'}` no corpo não muda nada — há um caso cobrindo exatamente
isso na suíte do emulador.

## 3. O cliente não concede itens

`firebase/firestore.rules`:

```
match /inventory/{itemId} {
  allow get, list: if ehDono(uid) || ehAdmin();
  allow create, delete: if false;
  allow update: if ehDono(uid)
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['equipped'])
    && request.resource.data.equipped is bool;
}
```

- **Criar e apagar: fechados para todos.** Só a Cloud Function grava, via Admin
  SDK, que ignora as regras por definição.
- **A única escrita permitida é `equipped`**, e o `hasOnly` garante que nenhum
  outro campo muda junto. Sem isso, uma atualização de equipagem poderia carregar
  `source`, `campaignId` ou `unlockedAt` adulterados no mesmo pedido e forjar a
  procedência de um item legítimo.

**Por que equipar é escrita direta e não uma função:** equipar não concede nada e
não tem valor econômico — é escolha de vitrine. Uma Cloud Function por toque de
botão custaria latência e dinheiro sem fechar nenhuma brecha, porque o que
precisava ser fechado (criar item, mudar procedência) já está fechado.

O comprovante segue o mesmo padrão: `create, update, delete: if false`.

## 4. Funções administrativas restritas a administradores

`firebase/functions/index.js`:

```js
function exigirAdmin(request) {
  const token = request.auth && request.auth.token;
  if (!token || token.admin !== true) {
    throw new HttpsError('permission-denied', 'acao restrita a administracao');
  }
  return request.auth.uid;
}
```

`grantPioneerEligibility` e `revokePioneerKit` chamam isso na primeira linha. O
custom claim `admin` é atribuído fora do aplicativo — **não existe caminho pelo
qual o jogador se torne admin**, porque `campaigns/` e `config/` são somente
leitura para ele e claims não vivem no Firestore.

Ambas gravam auditoria em `audit/`, coleção que o aplicativo não lê nem escreve:

```
match /audit/{registroId} {
  allow read: if ehAdmin();
  allow write: if false;
}
```

`write: if false` inclusive para admin: quem gera a trilha não pode limpá-la.

**A revogação é deliberadamente difícil.** Exige `confirmar: true` **e** um
`motivo` textual, e remove itens e comprovante numa única transação — não existe
estado meio-revogado.

**`grantPioneerEligibility` não concede o kit.** Ela apenas marca o UID como
elegível; o jogador continua resgatando pelo fluxo normal. Isso mantém **uma
única porta de escrita de inventário**, em vez de duas que podem divergir.

## 5. Idempotência sob repetição e concorrência

Três camadas, nenhuma dependendo de estado guardado no aparelho:

1. **Comprovante com id determinístico** (`campaign_claims/{campaignId}`) — a
   segunda gravação colide no mesmo documento;
2. **Item com id determinístico** (`inventory/{itemId}`) — reaplicar sobrescreve
   em vez de somar;
3. **Transação** — a função lê comprovante e inventário *dentro* da transação que
   grava. Duas chamadas simultâneas não conseguem ambas ler "não resgatado" e
   ambas gravar: o Firestore aborta e repete a perdedora, que então enxerga o
   comprovante e devolve `alreadyClaimed`.

A gravação de item usa `merge: true`, então mesmo uma corrida que escape converge
em vez de duplicar — e `equipped` não aparece no merge, para não desfazer a
escolha do jogador.

Coberto em memória (113 casos), incluindo: repetir dez vezes continua dando dez;
falha parcial reconcilia só o que falta; comprovante de outra versão não é
arbitrado. **A concorrência real está na suíte do emulador, ainda não executada**
(cinco chamadas simultâneas → dez itens).

## 6. Isolamento do inventário

`ehDono(uid)` compara `request.auth.uid` com o `{uid}` do caminho. Um jogador
autenticado não lê nem escreve em `users/{outro}/inventory`, e `list` está
igualmente fechado — não dá para varrer.

Na subcoleção de elegíveis a separação é mais fina:

```
allow get: if ehDono(uid) || ehAdmin();
allow list: if ehAdmin();
```

`get` do próprio documento é liberado (o app precisa saber se você foi
convidado); `list` é só admin, para que ninguém enumere a lista de convidados
antes do anúncio.

## 7. App Check

Integração pronta e **desligada**:

- `firebase_app_check` está em `app/pubspec.yaml`;
- as funções leem `ENFORCE_APP_CHECK` e passam `enforceAppCheck` nas opções.

**Por que desligado:** ligar a exigência antes de existir uma versão publicada do
aplicativo com App Check configurado derrubaria o resgate de todo mundo,
inclusive do teste fechado. A ordem correta é: publicar o app com App Check →
observar → só então exigir.

Ativação sem alterar código, no passo 9 do runbook:

```bash
firebase functions:secrets:set ENFORCE_APP_CHECK
```

---

## O que continua fora do alcance destas regras

Dito explicitamente para não virar suposição:

- **Um admin comprometido pode tudo.** As regras protegem contra o jogador, não
  contra quem tem o custom claim. A trilha em `audit/` existe para isso: não
  impede, mas registra.
- **A tela pode mentir para o próprio dono.** Um APK modificado consegue exibir
  `eligibleUnclaimed` para quem não tem direito. Não importa: a gravação é
  decidida no servidor, e a tela mentirosa só engana quem a modificou.
- **App Check não é autenticação.** Ele atesta que a chamada veio de um binário
  legítimo, não quem é a pessoa. Os dois se somam; nenhum substitui o outro.
