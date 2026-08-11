# Identidade da conexão online — lado do app

Branch: `claude/ws-auth-identidade` · base `origin/consolidacao/apk-geral-bmv` @ `0cea0d6`
Estado: **sem merge, sem deploy, produção intocada.**

Metade do app da OS de autenticação do handshake WebSocket. A outra metade — o
servidor, que é onde a segurança de verdade mora — está em
`buraco-servidor`, branch `seguranca/ws-auth-identidade`, com o mapa completo da
auditoria e todas as decisões em `docs/WS-AUTH-IDENTIDADE.md` daquele repo.

---

## O que mudou

Antes, [online_service.dart](app/lib/services/online_service.dart) abria o
WebSocket e mandava comandos direto. Não enviava credencial nenhuma — e nem
precisava, porque o servidor não pedia. Quem quisesse, dizia ser quem quisesse.

Agora:

```
conectar()
   ↓
obter Firebase ID Token          ← sem token, nem abre socket
   ↓
abrir WebSocket
   ↓
{tipo:"auth", token}             ← PRIMEIRA mensagem, sempre
   ↓
esperar {tipo:"autenticado"}     ← status = autenticando; nada mais sai
   ↓
soltar a fila de comandos        ← status = conectado
```

### Arquivos

| Arquivo | O quê |
|---|---|
| [app/lib/services/online_service.dart](app/lib/services/online_service.dart) | credencial antes do socket, máquina de estados, fila presa até autenticar, reconexão com token novo |
| [app/lib/main.dart](app/lib/main.dart) | dois estados novos no chip de status (o `switch` é exaustivo, então tinha que ser tratado) |
| [app/test/online_auth_test.dart](app/test/online_auth_test.dart) | 20 testes do portão |
| [.github/workflows/build.yml](.github/workflows/build.yml) | portão de CI para a suíte nova + deps de teste |

---

## Decisões

### O app não declara identidade

Nenhum comando que sai daqui carrega `jogadorId`, `uid`, `playerId`, `usuarioId`
ou `ownerId`. Mandar um seria redundante no melhor caso e **recusado pelo
servidor** (`IDENTIDADE_DIVERGENTE`) no pior. Há um teste que varre todas as
mensagens enviadas e falha se algum desses campos reaparecer — é o que impede
alguém reintroduzir isso sem perceber.

### Credencial na primeira mensagem, não no cabeçalho

O servidor aceita os dois caminhos, e prefere o cabeçalho `Authorization` do
upgrade HTTP. O app usa a **primeira mensagem** porque
`WebSocketChannel.connect` do `web_socket_channel` não expõe cabeçalhos de forma
multiplataforma (na web quem manda é a API `WebSocket` do navegador, que não
permite cabeçalho nenhum). Trocar por `IOWebSocketChannel` resolveria só no
mobile e quebraria a build web.

A credencial **nunca** vai na URL nem em query string — há teste para isso.

### Sem usuário logado: falha controlada, não crash

`OnlineStatus.naoAutenticado` é estado terminal. Sem usuário no Firebase, ou com
credencial recusada pelo servidor, o app:

- fecha o socket;
- **descarta** a fila de comandos;
- **não** agenda reconexão — insistir com credencial ruim só daria laço;
- mostra "entre na sua conta para jogar online".

### Reconexão busca token novo

Toda reabertura passa por `_abrir()`, que pede o token **antes** de abrir o
socket. `getIdToken()` devolve o token em cache e só vai à rede quando ele
expirou ou está perto disso, então isso é barato e garante credencial fresca.

Reconectar **nunca** reaproveita identidade anterior: a volta para a mesa
(`entrarMesa` com o código guardado) só é enviada depois do `autenticado`, e o
código da mesa diz *para onde* voltar, não *quem* está voltando — quem, o
servidor decide pelo token.

### O token não vaza

Ele sai uma única vez, dentro da mensagem `auth`, e não aparece em `erro`,
`status`, `visao`, `toString()` nem em log nenhum. Dois testes cobrem isso.

---

## Defeito pré-existente corrigido (fora do escopo original, mas indispensável)

`_abrir()` começava com uma guarda `if (status == conectando) return;`, e
`_aoCair()` põe o status em `conectando` **antes** de agendar o backoff. O timer
de reconexão chamava `_abrir()`, que voltava na primeira linha — **sempre**. A
reconexão automática nunca funcionou.

Isso teve que ser corrigido aqui: se a reconexão não roda, ela também não
reautentica, e o requisito de reautenticação da OS ficaria vazio. A guarda virou
uma trava explícita de abertura em curso (`_abrindo`), que era a intenção
original e não depende do rótulo de status.

Nenhum outro comportamento foi alterado.

---

## Compatibilidade (importante)

**Não existe compatibilidade cruzada, e é proposital:**

- este app **não** funciona contra o servidor atual em produção (`1828d42`): o
  `{tipo:"auth"}` cai no `default` do `switch` de lá, volta `"tipo desconhecido"`
  e o app trata como falha de autenticação;
- o app atual em produção **não** funciona contra o servidor novo: nunca
  autentica, e todo comando volta `NAO_AUTENTICADO`.

A implantação precisa ser **coordenada**. A ordem recomendada e os riscos estão
em `docs/WS-AUTH-IDENTIDADE.md` do repositório do servidor, incluindo a decisão
pendente sobre as contas hoje chaveadas pelos ids que os navegadores inventaram
em `localStorage`.

---

## Verificação

```
flutter test test/teste_motor.dart test/torneios/reward_grants_test.dart test/online_auth_test.dart
→ 232 testes, 232 verdes (20 deles novos)

flutter analyze lib test
→ 105 issues, exatamente a linha de base anterior (nenhum nos arquivos desta OS)
```

Rodado em scaffold local (`flutter create` + overlay de `app/lib`, como o CI
faz). O `flutter build` local continua bloqueado por symlink nesta máquina — é o
CI que mede APK.
