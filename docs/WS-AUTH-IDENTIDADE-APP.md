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
obter Firebase ID Token             ← sem token, nem abre socket
   ↓
abrir WebSocket
   ↓
{tipo:"auth", token, protocolo:2}   ← PRIMEIRA mensagem, sempre
   ↓
esperar {tipo:"autenticado"}        ← status = autenticando; nada mais sai
   ↓                                  (desiste em 15s se o servidor não responder)
soltar a fila de comandos           ← status = conectado
   ↓
{tipo:"authExpirou"} do servidor    ← a credencial venceu com a conexão de pé
   ↓
pegar token novo e reapresentar     ← no MESMO socket; a fila volta a segurar
```

### Arquivos

| Arquivo | O quê |
|---|---|
| [app/lib/services/online_service.dart](app/lib/services/online_service.dart) | credencial antes do socket, máquina de estados, fila presa até autenticar, reconexão com token novo |
| [app/lib/main.dart](app/lib/main.dart) | quatro estados novos no chip de status (o `switch` é exaustivo, então tinham que ser tratados) |
| [app/test/online_auth_test.dart](app/test/online_auth_test.dart) | 31 testes do portão |
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

### Renovação de credencial sem perder o assento

O servidor avisa (`authExpirou`) quando o token da conexão vence, e dá uma
carência curta. O app pega um token novo e reapresenta **no mesmo socket**.
Enquanto isso o status volta a `autenticando` e a fila de comandos segura de
novo — igual à primeira autenticação.

Renovar **não** reenvia `entrarMesa`: o socket nunca caiu e o assento continua
nosso. Reentrar pegaria outro lugar na mesa. É a diferença entre renovar
credencial e reconectar — o app distingue as duas.

Sem credencial na hora da renovação (a sessão do Firebase caiu no meio-tempo),
vira falha terminal, como qualquer outra ausência de credencial.

### Estados terminais

Três situações em que insistir não resolveria, e o app para de tentar:

| Estado | Quando | O que a pessoa vê |
|---|---|---|
| `naoAutenticado` | sem usuário no Firebase, ou credencial recusada | "entre na sua conta para jogar online" |
| `atualizacaoObrigatoria` | o servidor exige protocolo mais novo | "atualize o aplicativo para jogar online" |
| `servidorDesatualizado` | o servidor ainda não fala o protocolo autenticado | "servidor em atualização — tente mais tarde" |

`servidorDesatualizado` é detectado pelo erro que o servidor antigo devolve ao
`{tipo:"auth"}` (`"tipo desconhecido: auth"`). **Não existe caminho de jogo a
partir daí, de propósito:** jogar contra o servidor antigo exigiria o app voltar
a declarar `jogadorId`, que é exatamente o buraco fechado. O que o app garante é
falhar de forma explícita em vez de travar — e voltar sozinho assim que o
servidor subir.

Um servidor que simplesmente **não responde** ao `auth` também não pendura o
app: 15 segundos e ele desiste desta tentativa, caindo no backoff normal.

### O token não vaza

Ele sai uma única vez por autenticação, dentro da mensagem `auth`, e não aparece
em `erro`, `status`, `visao`, `toString()` nem em log nenhum. Vale igual para o
token renovado. Três testes cobrem isso.

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

- este app **não** joga contra o servidor atual em produção (`1828d42`) — mostra
  "servidor em atualização" no online, e o resto do app (jogo local, torneios,
  perfil) segue funcionando normalmente;
- o app atual em produção **não** joga contra o servidor novo: nunca autentica, e
  o primeiro comando volta com `ATUALIZACAO_OBRIGATORIA` e a mensagem "atualize o
  aplicativo para continuar jogando online".

A implantação precisa ser **coordenada**: `FIREBASE_PROJECT_ID` no Railway → app
publicado nas lojas → servidor implantado. A ordem completa, a janela de
indisponibilidade e o porquê de não existir ponte funcional estão em
`docs/WS-AUTH-IDENTIDADE.md` do repositório do servidor, §5.

Lá também está a decisão fechada sobre as contas legadas `j-<random>`: **corte
limpo, sem migração automática**. Nada neste app envia identificador legado, e
nada deve passar a enviar.

---

## Verificação

```
flutter test test/teste_motor.dart test/torneios/reward_grants_test.dart test/online_auth_test.dart
→ 243 testes, 243 verdes (31 deles novos)

flutter analyze lib test
→ 105 issues, exatamente a linha de base anterior (nenhum nos arquivos desta OS)
```

Rodado em scaffold local (`flutter create` + overlay de `app/lib`, como o CI
faz). O `flutter build` local continua bloqueado por symlink nesta máquina — é o
CI que mede APK.
