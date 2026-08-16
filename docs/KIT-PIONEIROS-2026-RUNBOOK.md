# Kit Pioneiros 2026 — runbook de implantação

**Nada foi implantado.** Este documento é o roteiro; executá-lo depende de nova
autorização da Sônia.

A campanha está e permanece em `status: draft`, `catalogVisibility: hidden` e com
`kitPioneiros2026Enabled: false`. Nenhum passo abaixo, até o 9, torna a coleção
visível ou resgatável para qualquer jogador.

---

## Antes de começar

| | |
| --- | --- |
| **Projeto** | `buraco-master-vip` (o mesmo do `firebase_auth` já em produção — ver `app/lib/main.dart`) |
| **Ambiente** | produção. Não existe projeto de staging hoje; ver "Se não houver staging" abaixo |
| **Região das Functions** | `southamerica-east1` — precisa casar com `kRegiaoFuncoes` em `colecao_firebase.dart` |
| **Quem executa** | quem tiver papel de Editor/Owner no projeto |
| **Janela** | qualquer horário até o passo 8; o passo 9 é a virada de chave |
| **Duração** | ~40 min, dominados pela construção dos índices |

```bash
npm install -g firebase-tools
firebase login
firebase use buraco-master-vip
```

### Se não houver staging

O projeto não tem ambiente separado. Duas saídas, em ordem de preferência:

1. **Criar um projeto de teste** e rodar os passos 1–8 nele primeiro. É o
   caminho seguro e custa uma tarde.
2. **Ir direto em produção**, aceitando que os passos 1–8 são inertes: eles só
   criam documentos novos e regras mais restritivas, sem tocar em nada que o
   aplicativo hoje use. O risco real está concentrado no passo 1, tratado abaixo.

---

## 1. Salvar as regras que estão na Console  ⚠️ passo mais delicado

O repositório **não tem** as regras atuais de produção — `firebase/firestore.rules`
foi escrito do zero nesta entrega. Publicar por cima sem olhar o que existe hoje
pode revogar acesso a coleções em uso.

```bash
mkdir -p firebase/backup
firebase firestore:rules get > firebase/backup/regras-producao-ANTES.rules
```

Se o comando não existir na sua versão, copie manualmente em
**Console → Firestore → Regras**, e guarde o arquivo.

Agora **compare**:

```bash
diff firebase/backup/regras-producao-ANTES.rules firebase/firestore.rules
```

**No Firestore, caminho não declarado é caminho negado.** Se o arquivo antigo
liberar `usuarios/`, `partidas/`, `amigos/` ou qualquer outra coleção, essas
regras precisam ser **copiadas para dentro** de `firebase/firestore.rules` antes
do passo 2. Não pule esta conferência.

> Situação esperada: o aplicativo hoje usa só Firebase Auth e não tem
> `cloud_firestore`, então provavelmente não há regra em uso. "Provavelmente" não
> é o suficiente — confira.

## 2. Publicar regras e índices

Regras primeiro, sempre. Publicar dados antes das regras deixaria uma janela em
que o cliente escreveria no próprio inventário.

```bash
cd firebase
firebase deploy --only firestore:rules --project buraco-master-vip
```

```bash
cd firebase
firebase deploy --only firestore:indexes --project buraco-master-vip
```

## 3. Esperar os índices ficarem prontos

Índice em construção faz consulta falhar com `failed-precondition`. São três.

```bash
firebase firestore:indexes --project buraco-master-vip
```

Repita até nenhum aparecer como `CREATING`. Em base pequena leva poucos minutos;
não siga antes disso.

## 4. Publicar as Functions

```bash
cd firebase/functions && npm install
```

```bash
cd firebase
firebase deploy --only functions --project buraco-master-vip
```

Confira que as três subiram na região certa:

```bash
firebase functions:list --project buraco-master-vip
```

Esperado: `claimPioneerKit`, `grantPioneerEligibility` e `revokePioneerKit`, em
`southamerica-east1`.

## 5. Ensaio do seed

Não grava nada — imprime o que faria.

```bash
node firebase/scripts/seed_pioneiros_2026.js --project buraco-master-vip
```

Deve listar 13 documentos e a linha `integridade OK: 10 itens conferidos contra
manifesto e campanha`. Se a integridade falhar, **pare**: catálogo, campanha e
manifesto estão divergentes.

## 6. Gravar o seed

```bash
node firebase/scripts/seed_pioneiros_2026.js --project buraco-master-vip --commit
```

Idempotente: usa ids determinísticos e `merge: true`. Rodar de novo atualiza, não
duplica.

Confira na Console que `campaigns/pioneiros_2026` está com `status: "draft"` e que
`config/featureFlags` tem `kitPioneiros2026Enabled: false`.

## 7. Rodar a suíte de segurança nos emuladores

Este passo fecha o único item de segurança cuja evidência ainda é por construção
(ver `KIT-PIONEIROS-2026-SEGURANCA.md`).

```bash
cd firebase/testes && npm install
```

```bash
cd firebase && firebase emulators:exec --only firestore,functions,auth "cd testes && npm test"
```

Deve provar, entre outras coisas, que cinco chamadas simultâneas ainda deixam
exatamente dez itens.

## 8. Teste controlado com um UID real

Ainda com a flag desligada e a campanha em `draft`: **ninguém mais vê nada.**

```bash
firebase firestore:documents:set "campaigns/pioneiros_2026/eligible/<SEU_UID>" \
  '{"naAllowlist": true}' --project buraco-master-vip
```

Ative só para você, em duas edições na Console:

1. `config/featureFlags` → `kitPioneiros2026Enabled: true`
2. `campaigns/pioneiros_2026` → `status: "active"`, `eligibilityMode: "allowlist"`

Com `catalogVisibility` ainda em `hidden`, quem não está na allowlist não vê a
campanha. Faça o resgate pelo aplicativo e confirme:

- [ ] chegaram os 10 documentos em `users/<UID>/inventory`;
- [ ] existe 1 comprovante em `users/<UID>/campaign_claims/pioneiros_2026`;
- [ ] resgatar de novo devolve `alreadyClaimed` e **não** cria documento;
- [ ] desinstalar e reinstalar o app mantém os 10;
- [ ] equipar um mascote desequipa o anterior;
- [ ] um UID fora da allowlist recebe `permission-denied`.

Terminado o teste, **volte `status` para `draft`** até a abertura de verdade.

## 9. Abertura — a flag é o último passo

Nesta ordem:

1. definir `eligibilityMode` e popular `campaigns/pioneiros_2026/eligible/{uid}`
   com a lista final aprovada;
2. definir `startAt` / `endAt` / `claimDeadline`, se houver, em ISO-8601 **com
   sufixo `Z`** (`"2026-09-01T00:00:00Z"`). Data sem `Z` é recusada de propósito;
3. definir `catalogVisibility` (`hidden` ou `teaser`);
4. **ativar o App Check** antes da abertura pública, com o app já publicado numa
   versão que o configure:
   ```bash
   firebase functions:secrets:set ENFORCE_APP_CHECK
   ```
   (valor `true`, seguido de novo deploy das functions);
5. `status: "active"`;
6. **por último**, `kitPioneiros2026Enabled: true`.

A flag é o último passo porque é o interruptor mais rápido de desfazer.

---

## Rollback

**Desligar tudo — 1 edição, efeito imediato:**

```
config/featureFlags → kitPioneiros2026Enabled: false
```

A flag vence status, janela e evidência: a campanha some e nenhuma concessão
ocorre. Quem já resgatou **mantém** o inventário — é permanente por desenho.

**Parar de conceder sem esconder de quem já tem:**

```
campaigns/pioneiros_2026 → status: "paused"
```

**Reverter as regras:**

```bash
cd firebase
cp backup/regras-producao-ANTES.rules firestore.rules
firebase deploy --only firestore:rules --project buraco-master-vip
```

**Reverter as Functions:** publique novamente a partir do commit anterior. As
funções são idempotentes e sem estado próprio; não há migração a desfazer.

**Desfazer a concessão de um jogador** (só como correção, com trilha):

```bash
firebase functions:shell --project buraco-master-vip
# claimPioneerKit não tem inverso; use a função administrativa:
# revokePioneerKit({uid: '<UID>', confirmar: true, motivo: '<justificativa>'})
```

**O que NÃO tem rollback simples:** os índices. Apagar índice é lento e não
urgente — índice sobrando não quebra nada, só ocupa espaço. Deixe.

---

## Depois da abertura, observar

- `pioneer_claim_error` na telemetria — se subir, olhe os logs da função;
- `firebase functions:log --only claimPioneerKit`;
- a coleção `audit/`, para conferir que não houve concessão administrativa
  inesperada;
- quantidade de documentos em `campaign_claims` versus tamanho da allowlist: uma
  diferença grande indica gente elegível que não conseguiu resgatar.
