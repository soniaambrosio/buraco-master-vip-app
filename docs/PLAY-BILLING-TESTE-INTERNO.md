# Google Play Billing — AAB para Teste interno

Guia operacional para destravar a área de produtos da Play Console.

**O problema:** a Play Console só deixa criar assinaturas e produtos únicos depois
de processar uma versão publicada que contenha a Google Play Billing Library.
Nenhuma versão enviada até hoje tinha essa biblioteca.

**A solução:** este trabalho adiciona a biblioteca, garante a permissão
`com.android.vending.BILLING` no manifesto final e gera um AAB de release
assinado para a faixa de **Teste interno** — sem cadastrar nenhum ID nem preço
de produto, porque os IDs oficiais só existem depois desse envio.

---

## Antes de tudo: a chave de upload está bloqueada

A chave de upload registrada hoje na Play Console é:

| | |
|---|---|
| SHA-1 | `32:6B:CA:26:34:29:45:41:D5:DA:21:17:DB:87:80:91:32:D2:D9:9C` |
| SHA-256 | `AB:7A:51:93:E6:CA:FD:16:04:56:4B:3E:4B:8C:61:60:19:2C:22:28:D1:9B:32:D0:0C:5A:A5:9E:CB:FA:83:E8` |

A chave privada correspondente não foi localizada, e a keystore de teste que está
no repositório (`keystore/buraco-master-vip-test.jks.b64`) **não** é essa chave —
já foi conferido. Sem a chave privada, a Play Console recusa qualquer AAB novo.

O caminho oficial é pedir a **redefinição da chave de upload**, enviando o
certificado público de uma chave nova. Isso **não** mexe na chave de assinatura
do app administrada pelo Google (Play App Signing) — essa continua intacta, e é
ela que assina o que chega no celular dos jogadores. A chave de upload só prova,
no momento do envio, que o AAB veio de você.

> Guarde a chave nova com cuidado. A Play Console impõe restrições de frequência
> para pedidos de redefinição de chave de upload, e elas mudam — confirme a
> política vigente na própria Console no momento do pedido, em vez de assumir
> um intervalo fixo.

### 1. Gerar a chave nova

```bash
powershell -ExecutionPolicy Bypass -File keystore/gerar-chave-upload.ps1 -Alias SEU_ALIAS
```

Escolha o alias (ele vai para o secret `BMV_UPLOAD_KEY_ALIAS`) e, quando o
`keytool` pedir, **uma senha forte**. Guarde os dois no gerenciador de senhas.
Nem o alias nem a senha são escritos em lugar nenhum do repositório — e sem eles
a chave nova também se perde.

O script gera três arquivos em `keystore/` (nenhum vai para o git):

| arquivo | o que é |
|---|---|
| `buraco-master-vip-upload.jks` | a **chave privada**. Nunca compartilhe. Faça backup. |
| `upload_certificate.pem` | o certificado **público** — é este que vai para a Play Console. |
| `buraco-master-vip-upload.jks.b64` | conteúdo do secret `BMV_UPLOAD_KEYSTORE_B64`. |

### 2. Pedir a redefinição na Play Console

1. Play Console → o app → **Testes e versões** → **Assinatura de apps**
2. **Solicitar redefinição da chave de upload**
3. Motivo: *perdi minha chave de upload*
4. Anexar `keystore/upload_certificate.pem`
5. Aguardar a confirmação da Play Console

Não trabalhe com um prazo estimado. A Play Console informa, na própria tela de
**Assinatura de apps** e por e-mail, a confirmação do pedido e a **data a partir
da qual a chave nova passa a valer** para uploads. É essa data de vigência que
manda — antes dela, o envio continua sendo recusado mesmo que o pedido já
apareça como aceito.

Registre a data informada e só envie o AAB a partir dela. O build em si pode ser
rodado antes; só o upload depende dessa vigência.

---

## Secrets do GitHub

Em **Settings → Secrets and variables → Actions**, cadastre os quatro:

| secret | valor |
|---|---|
| `BMV_UPLOAD_KEYSTORE_B64` | conteúdo de `buraco-master-vip-upload.jks.b64` |
| `BMV_UPLOAD_KEY_ALIAS` | o alias que você passou em `-Alias` |
| `BMV_UPLOAD_STORE_PASSWORD` | a senha que você escolheu |
| `BMV_UPLOAD_KEY_PASSWORD` | a mesma senha (o script usa uma só) |
| `BMV_GOOGLE_SERVICES_JSON_B64` | base64 do `google-services.json` do app Android oficial |

Para o último: Firebase Console → app Android `io.github.soniaambrosio.buracomastervip`
→ baixar `google-services.json` → converter para base64:

```bash
base64 -w0 google-services.json
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('google-services.json'))
```

Ele vai por secret, e não pelo repositório, porque carrega chave de API e IDs de
cliente OAuth — mesmo critério aplicado ao resto do material sensível.

O workflow falha logo no começo, com o nome do que faltou, se algum não existir.
Nenhuma senha aparece em arquivo versionado — diferente do `build.yml` de APK de
teste, que tem as senhas em texto puro (aceitável lá, porque aquela chave não
assina nada que vá para a Play Console).

---

## Gerar o AAB

**Actions → Release AAB (Teste interno) → Run workflow**

| campo | valor |
|---|---|
| `version_code` | `3` |
| `version_name` | `1.0.1` |

O último AAB aceito pela Play Console foi o **versionCode 2** (o `1.0.0.1` que
aparece na Console é o *nome* da versão, não o código). O workflow recusa
qualquer valor ≤ 2 antes de começar a compilar.

Ao final, baixe o artefato **`bmv-aab-teste-interno`** — ele contém
`app-release.aab` e o `manifesto-final.xml` extraído de dentro do bundle.

### O que o workflow verifica sozinho

Nada é assumido; tudo é lido de dentro do `.aab` gerado:

- `applicationId` = `io.github.soniaambrosio.buracomastervip`
- permissão `com.android.vending.BILLING` presente no manifesto **final**
- `versionCode` e `versionName` conforme os campos preenchidos
- classes `com/android/billingclient/**` empacotadas — prova de que a biblioteca
  foi compilada, e não só declarada no `pubspec`
- impressões digitais da chave que assinou, para você comparar com a Play Console
  **antes** de enviar

Se qualquer uma falhar, o build quebra e não gera artefato.

### Enviar

Play Console → **Testes** → **Teste interno** → **Criar nova versão** → subir o
`app-release.aab`.

**Não enviar para produção.** O objetivo aqui é só fazer a Play Console
processar uma versão com a biblioteca de billing.

---

## Depois que a Play Console processar

A área de produtos libera. Cadastre:

- assinatura **`master_vip`**, com os planos-base **mensal**, **trimestral** e **anual**
- os pacotes consumíveis de fichas

> No Google Play, mensal/trimestral/anual são **planos-base dentro** da
> assinatura `master_vip` — não são três produtos separados. O código já assume
> isso: `BillingCatalogo.assinaturas` recebe um ID só, e os planos-base chegam
> como ofertas dentro do `ProductDetails` correspondente.

Com os IDs oficiais em mãos, dois lugares precisam ser preenchidos:

**1. No app** — `app/lib/services/billing_catalogo.dart`:

```dart
static const Set<String> assinaturas = <String>{ 'master_vip' };
static const Set<String> consumiveis = <String>{ /* IDs dos pacotes de fichas */ };
```

**2. No servidor** — documento `configuracao/billing` do Firestore, que é quem
decide **o que cada produto concede**:

```json
{
  "produtos": {
    "master_vip":            { "assinatura": true },
    "<id_do_pacote_fichas>": { "assinatura": false, "fichas": 1000 }
  }
}
```

A quantidade de fichas vive **só** no servidor, de propósito: se viesse do app,
bastaria adulterar o aparelho para pedir um crédito maior.

O portão `billing_catalogo_test.dart` roda no CI e recusa IDs mal formados ou com
cara de provisório (`teste`, `exemplo`, `dummy`…). IDs de produto do Google Play
são imutáveis — não podem ser apagados depois de criados, só desativados.

---

## Backend de validação

O aplicativo **nunca** concede VIP ou fichas. Ele manda o `purchaseToken` para a
Cloud Function `validarCompraPlay`, que pergunta à Google Play Developer API se a
compra é real e só então grava a concessão no Firestore.

O motivo: o retorno de compra chega dentro do aparelho do jogador, e aparelho de
jogador não é ambiente confiável — um dispositivo com root consegue forjar um
retorno de sucesso. O que não dá para forjar é a resposta da API da Google, que
exige a credencial de uma conta de serviço que vive só no backend.

### Publicar

1. **Conta de serviço com acesso à Play Developer API**
   Google Cloud Console → criar conta de serviço → na Play Console, em
   **Usuários e permissões**, conceder a ela acesso ao app com a permissão
   *Ver dados financeiros* e *Gerenciar pedidos e assinaturas*.

2. **Guardar a credencial no Secret Manager** (nunca no repositório):
   ```bash
   firebase functions:secrets:set PLAY_SERVICE_ACCOUNT_JSON
   ```
   Cole o JSON da conta de serviço quando for pedido.

3. **Publicar a função e as regras:**
   ```bash
   cd functions && npm install && cd .. && firebase deploy --only functions,firestore:rules
   ```

As regras em `firestore.rules` são a outra metade da proteção: elas impedem que o
aplicativo escreva `vip`, `vipExpiraEm`, `fichas` e afins. Sem elas, validar no
servidor não adiantaria nada — bastaria o jogador escrever `vip: true` no próprio
documento.

### Quem consome o token

O **backend** consome, via `purchases.products.consume` da Play Developer API, e
só **depois** de creditar as fichas. O app nunca consome.

Consumir é o que libera o token para ser comprado de novo. Consumir antes de
creditar — ou consumir no cliente, que pode ser morto a qualquer instante — é a
receita para o jogador pagar e não receber. Na ordem correta, se o consumo
falhar o jogador já recebeu, a Play reentrega o token, e a reentrega cai na
idempotência sem creditar duas vezes.

Assinatura não se consome: é reconhecida com `subscriptions.acknowledge`. Sem
reconhecer, a Play Store estorna automaticamente em 3 dias.

### Idempotência e concorrência

A Play Store reentrega compras (troca de aparelho, app fechado no meio da
validação, reinstalação), e duas entregas podem chegar **ao mesmo tempo**.

Duas garantias, ambas em `functions/idempotencia.js`:

**Titularidade.** O mesmo `purchaseToken` sempre descreve a mesma compra. Se
chegar amarrado a outro `uid`, outro `produtoId` ou outro tipo, é conflito e a
função recusa. A conferência acontece **antes** de olhar o estado — senão um
token de outro jogador que estivesse `concedida` devolveria a concessão alheia.

**Crédito único.** A concessão e a marcação de `concedida` acontecem na **mesma
transação**, com o documento relido dentro dela. Não existe janela entre
"creditei" e "anotei que creditei". Duas execuções simultâneas disputam a
transação; o Firestore serializa e faz a perdedora repetir a leitura, e aí ela vê
`concedida` e devolve o que já foi concedido em vez de creditar de novo.

No app, o cuidado equivalente: uma falha temporária de validação (rede fora,
função ainda não publicada) **não** finaliza a compra — ela fica pendente de
propósito para a Play Store reentregar e revalidar. Só uma recusa definitiva do
backend encerra a compra sem conceder nada.

Ambos os lados têm portão no CI: `functions/test/idempotencia.test.js`
(concorrência e reentrega, `node --test`) e `app/test/billing/billing_fluxo_test.dart`
(decisão de finalizar ou não).

---

## Firebase do pacote oficial

Configurado e confirmado. O app Android oficial no Firebase:

| | |
|---|---|
| pacote | `io.github.soniaambrosio.buracomastervip` |
| App ID | `1:203886484007:android:b1cd95baa0b9e6e629cc02` |
| SHA-1 da chave de assinatura Play | `83:73:8C:7A:9A:C9:F5:00:AB:27:49:1A:04:EA:8B:EA:74:AB:CF:6A` |
| projeto | `buraco-master-vip` (o mesmo de sempre) |

> O SHA-1 acima é o da **chave de assinatura do app administrada pelo Google**
> (Play Console → Assinatura de apps), e não o da chave de upload. Em produção
> quem assina o que roda no celular é o Google — cadastrar o SHA-1 da chave de
> upload aqui faria o login falhar em todo aparelho que instalasse pela Play.

### Como os dois pacotes convivem

O fonte `app/lib/main.dart` continua apontando para o app do Firebase do **PoC**,
porque ele é compartilhado com o `build.yml` (APK de teste, pacote `.poc`). Quem
troca o `appId` é o `release-aab.yml`, na cópia dentro de `app_build/` — o
repositório não é alterado.

Consequência prática: **o APK de teste segue funcionando exatamente como antes**.
Nenhuma mudança desta entrega toca nele.

O `serverClientId` do Google Sign-In é o **mesmo** nos dois pacotes
(`203886484007-a5e1ob…apps.googleusercontent.com`): ele identifica o projeto, não
o app Android. O workflow falha se ele sumir do `main.dart`.

### google-services.json

Entra no build a partir do secret `BMV_GOOGLE_SERVICES_JSON_B64`, e o plugin
`com.google.gms.google-services` é aplicado no `settings.gradle.kts` e no
`app/build.gradle.kts` do scaffold. Sem o plugin, o arquivo ficaria no diretório
sem efeito nenhum.

Antes de compilar, o workflow confere que o JSON é mesmo do app certo: `project_id`,
presença do pacote oficial e presença do App ID oficial. O plugin também rejeita
um pacote divergente, mas com mensagem obscura — a conferência antecipada dá um
erro legível e ainda pega o caso pior, que é um JSON válido do app **errado**.
