# Firebase — Kit Pioneiros 2026

Camada segura da coleção. **Nada aqui foi implantado.** Os arquivos estão
versionados e prontos; a publicação em produção é uma decisão da Sônia e exige
credenciais do projeto, que esta entrega não usou.

## O que tem nesta pasta

| Arquivo | Papel |
| --- | --- |
| `firestore.rules` | Regras de acesso. O cliente nunca escreve inventário, comprovante ou elegibilidade. |
| `firestore.indexes.json` | Três índices: inventário por coleção, itens equipados e auditoria de resgates. |
| `functions/index.js` | `claimPioneerKit`, `grantPioneerEligibility` e `revokePioneerKit`. |
| `scripts/seed_pioneiros_2026.js` | Publica catálogo e campanha lendo `app/data/colecoes/`. Idempotente. |
| `firebase.json` | Amarra regras, índices, funções e emuladores. |

## Modelo de dados

```
config/featureFlags                      { kitPioneiros2026Enabled: false }
campaigns/pioneiros_2026                 espelho de campanha_pioneiros_2026.seed.json
campaigns/pioneiros_2026/eligible/{uid}  evidências; só admin escreve
collections/pioneiros_2026               metadados da coleção
collections/pioneiros_2026/items/{itemId}
users/{uid}/inventory/{itemId}           id determinístico = itemId
users/{uid}/campaign_claims/{campaignId} comprovante, id determinístico
audit/{auto}                             trilha de ação administrativa
```

Os dois ids determinísticos são o que sustenta a idempotência: uma segunda
gravação colide no mesmo documento em vez de criar outro. Isso vale mesmo se o
aplicativo for reinstalado, o aparelho trocado ou a chamada repetida por timeout.

## Ordem de implantação

O passo 1 é o mais importante: publicar as regras **depois** de já existir dado
gravável deixaria uma janela em que o cliente poderia escrever no próprio
inventário.

```bash
cd firebase
firebase deploy --only firestore:rules --project <id>
```

```bash
cd firebase
firebase deploy --only firestore:indexes --project <id>
```

```bash
cd firebase/functions && npm install
firebase deploy --only functions --project <id>
```

Ensaio do seed (não grava nada):

```bash
node firebase/scripts/seed_pioneiros_2026.js --project <id>
```

Gravação do seed, depois de conferir o ensaio:

```bash
node firebase/scripts/seed_pioneiros_2026.js --project <id> --commit
```

## Ativar a campanha

O seed publica a campanha em `status: draft`, visibilidade `hidden` e com a
feature flag **desligada**. Nenhuma dessas três coisas muda por deploy: a
ativação é feita editando os documentos, sem novo build do aplicativo.

1. `config/featureFlags` → `kitPioneiros2026Enabled: true`
2. `campaigns/pioneiros_2026` → `status: "active"`
3. Definir `eligibilityMode` (`allowlist`, `closedTest`, `matchInWindow`,
   `hybrid` ou `adminGrant`) e, se houver, `startAt` / `endAt` / `claimDeadline`
   em ISO-8601 **com sufixo `Z`**.
4. Popular `campaigns/pioneiros_2026/eligible/{uid}` com a evidência
   correspondente.

Para desligar tudo em uma ação, basta voltar a flag para `false`: ela vence
status, janela e evidência.

## Administração

`grantPioneerEligibility` marca um UID como elegível caso a caso — **não**
concede o kit. O jogador continua resgatando pelo fluxo normal, o que mantém uma
única porta de escrita de inventário. Exige custom claim `admin: true` e grava
auditoria.

`revokePioneerKit` existe apenas como ferramenta de correção. Exige
`confirmar: true` e `motivo`, remove itens e comprovante numa transação e deixa
trilha em `audit/`. Não faz parte do fluxo comum.

O custom claim é atribuído fora do aplicativo:

```bash
firebase auth:import --help
```

## Aviso sobre o escopo das regras

No Firestore, **caminho não declarado é caminho negado**. `firestore.rules` cobre
somente as coleções do Kit Pioneiros. Quando `usuarios/`, `partidas/`, `amigos/`
e as demais entrarem no ar, precisam ser acrescentadas ao mesmo arquivo — senão
o aplicativo perde acesso a elas no dia do deploy.

Hoje isso não é um problema: o aplicativo usa apenas Firebase Auth e ainda não
tem `cloud_firestore` nas dependências (ver `.github/workflows/build.yml`).
Adicionar o pacote é pré-requisito para ligar a campanha e está listado como
pendência no relatório.
