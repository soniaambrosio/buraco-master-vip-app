# Contrato da conexão autenticada — lado do cliente (V1)

Branch: `claude/cliente-servidor-auth-producao-v1` · base `origin/consolidacao/apk-geral-bmv` @ `0cea0d6`
Estado: **sem merge, sem deploy, produção intocada.**

Fecha o P0 em que o aplicativo publicável não conseguia estabelecer a sessão que
o servidor autenticado exige. Este documento é o contrato; a execução das provas
está em [CLIENTE-SERVIDOR-AUTH-EVIDENCIA-V1.md](CLIENTE-SERVIDOR-AUTH-EVIDENCIA-V1.md).

---

## 1. O que esta OS possui

Configuração de endereço, transporte, handshake, credenciais efêmeras, máquina
de estados da conexão e o adaptador que a mesa real consome.

| Arquivo | O quê |
|---|---|
| [app/lib/services/endpoint_servidor.dart](../app/lib/services/endpoint_servidor.dart) | de onde sai o endereço e o que é recusado, por perfil de build |
| [app/lib/services/redacao_segredos.dart](../app/lib/services/redacao_segredos.dart) | apaga segredo de qualquer texto que possa ser visto |
| [app/lib/services/online_service.dart](../app/lib/services/online_service.dart) | credencial, handshake, geração de sessão, reconexão, projeção |
| [app/lib/main.dart](../app/lib/main.dart) | estados novos no chip de status, vigia de logout, redação no erro de login |
| [app/test/online_auth_test.dart](../app/test/online_auth_test.dart) | 31 provas da credencial (vindas da folha `ws-auth`) |
| [app/test/conexao_producao_test.dart](../app/test/conexao_producao_test.dart) | 43 provas da conexão publicável |
| [.github/workflows/build.yml](../.github/workflows/build.yml) | portão da suíte + validação do endereço antes de gerar o APK |

Fora da fronteira, e **não** tocado: casca principal, tabela de rotas e telas de
menu (OS 1); Crashlytics e workflows de release (OS 3); servidor, regras do
jogo, economia, Billing e Play Console.

---

## 2. Procedência — o que foi incorporado, e de onde

A folha `claude/ws-auth-identidade-1fc213` **não era alcançável** pela base: ela
está dois commits À FRENTE de `0cea0d6`, não atrás. SHA remoto congelado e
conferido:

```
claude/ws-auth-identidade-1fc213 = 13582ddfa0f9b8cccc81b20e51705bf666ca8754
                                   ^^^^^^^ prefixo 13582dd, como a OS exige
```

Os dois commits foram incorporados por cherry-pick identificado (`-x`), então a
proveniência está registrada em cada mensagem:

| Aqui | Origem | O quê |
|---|---|---|
| `eb5bdcf` | `1615979` | o app apresenta credencial em vez de declarar identidade |
| `2562e0c` | `13582dd` | renovação de credencial vencida e versão incompatível |

Depois do cherry-pick, `git diff 13582dd HEAD` era **vazio** — a árvore ficou
idêntica à folha congelada antes de qualquer trabalho novo.

### Contrato do servidor (registrado, não alterado)

```
buraco-servidor · seguranca/ws-auth-identidade
@ 71199e81ff44d41c8fcdb41cd866b38c0cf14fee
```

Conferido como ponta exata daquela branch, **em leitura**. Nada foi editado nem
publicado naquele repositório. O vocabulário observado no `server.js` congelado
bate com o que o app fala, sem divergência:

| Servidor envia | App trata |
|---|---|
| `autenticado` | libera a fila de comandos |
| `authFalhou` | falha terminal `naoAutenticado` |
| `authExpirou` | renova a credencial no mesmo socket |
| `atualizacaoObrigatoria` | falha terminal `atualizacaoObrigatoria` |
| `entrou{codigo,assento}` | guarda mesa e assento |
| `estado{visao}` | projeção do assento (ver §6) |
| `erro{motivo}` | mensagem redigida; durante `auth`, `servidorDesatualizado` |

Constantes do servidor confirmadas na leitura: `PROTOCOLO_MINIMO = 2`,
`PROTOCOLO_ATUAL = 2`, `CARENCIA_RENOVACAO_MS = 30000`, e
`CAMPOS_DE_IDENTIDADE = ["jogadorId","uid","playerId","usuarioId","ownerId"]`
recusados quando divergem da identidade vinculada.

---

## 3. Endereço do servidor

O endereço **não vive mais no código**. Ele entra pela configuração do build:

```
flutter build apk --release --dart-define=BMV_SERVIDOR_URL=wss://SEU-SERVIDOR.exemplo.tld
```

Exemplo copiável, sem segredo e sem endereço de produção:
[docs/exemplo-configuracao-endpoint.env](exemplo-configuracao-endpoint.env).

### Política por perfil

| Endereço | Release | Desenvolvimento | Desenvolvimento + `BMV_PERMITIR_ENDPOINT_INSEGURO=true` |
|---|---|---|---|
| vazio | recusa | recusa | recusa |
| `wss://host.tld` | **aceita** | aceita | aceita |
| `https://host.tld` | **aceita** (vira `wss`) | aceita | aceita |
| `ws://host.tld` | recusa | recusa | aceita |
| `wss://localhost` | recusa | recusa | aceita |
| `wss://127.0.0.0/8` | recusa | recusa | aceita |
| `wss://10.0.2.2` (emulador) | recusa | recusa | aceita |
| `wss://10.0.3.2` (Genymotion) | recusa | recusa | aceita |
| `*.local` (mDNS) | recusa | recusa | aceita |
| com `?query` ou `#fragmento` | recusa | recusa | **recusa** |
| com `usuario:senha@` | recusa | recusa | **recusa** |

Duas decisões que valem a pena estar escritas:

1. **A autorização de endereço inseguro não vale no release.** Se valesse,
   bastaria alguém ligar a chave por engano para publicar um app que fala em
   claro. Ela só tem efeito fora do build publicável.
2. **Credencial em URL é recusada em todo perfil**, inclusive desenvolvimento.
   Um `?token=` acaba em log de proxy, histórico e relatório de erro. O servidor
   também ignora identidade vinda da URL — aqui é a mesma regra, do lado de cá.

O endereço ruim é pego **duas vezes**: pelo portão de CI antes de gerar o APK, e
pelo app em execução (vira `configuracaoInvalida`, falha terminal). O portão de
CI existe porque descobrir isso no celular de quem instalou é tarde demais.

---

## 4. Handshake

```
conectar()
   ↓
validar endereço                    ← inválido → configuracaoInvalida (terminal)
   ↓
obter Firebase ID Token             ← sem token → naoAutenticado (terminal)
   ↓
abrir WebSocket
   ↓
{tipo:"auth", token, protocolo:2}   ← PRIMEIRA mensagem, sempre
   ↓
esperar {tipo:"autenticado"}        ← status = autenticando; nada mais sai
   ↓                                  (desiste em 15s se o servidor não responde)
soltar a fila de comandos           ← status = conectado
```

O app anuncia **protocolo 2** e nunca 1 — há teste para isso. Quando o servidor
responde `atualizacaoObrigatoria` (o que ele faz para protocolo < 2), o app para
e diz para atualizar, em vez de tentar de novo.

A credencial vai na **primeira mensagem**, não no cabeçalho, porque
`WebSocketChannel.connect` não expõe cabeçalhos de forma multiplataforma (na web
quem manda é a API `WebSocket` do navegador, que não permite cabeçalho nenhum).
O servidor aceita os dois caminhos.

**O app não declara identidade.** Nenhum comando que sai daqui carrega
`jogadorId`, `uid`, `playerId`, `usuarioId`, `ownerId`, `sub` ou `email`. Um
teste varre todo o vocabulário que o app sabe falar e falha se algum reaparecer.

---

## 5. Matriz da conexão — estado → evento → ação → estado seguinte

| Estado | Evento | Ação | Estado seguinte |
|---|---|---|---|
| `desconectado` | `conectar()` | valida endereço | `conectando` |
| `conectando` | endereço inválido | fecha tudo, esvazia fila | **`configuracaoInvalida`** |
| `conectando` | sem credencial | fecha tudo, esvazia fila | **`naoAutenticado`** |
| `conectando` | socket falhou | agenda backoff | `erro` |
| `conectando` | geração mudou | abandona (fecha se abriu) | — (sem efeito) |
| `conectando` | socket aberto | envia `auth{protocolo:2}`, arma 15s | `autenticando` |
| `autenticando` | `autenticado` | reentra na mesa se havia; solta a fila | `conectado` |
| `autenticando` | `authFalhou` | fecha, esvazia fila, apaga projeção | **`naoAutenticado`** |
| `autenticando` | `atualizacaoObrigatoria` | fecha, esvazia fila | **`atualizacaoObrigatoria`** |
| `autenticando` | `erro` genérico | fecha, esvazia fila | **`servidorDesatualizado`** |
| `autenticando` | 15s sem resposta | fecha socket, agenda backoff | `erro` |
| `autenticando` | socket caiu | agenda backoff | `conectando` |
| `conectado` | `entrou{codigo,assento}` | guarda mesa e assento | `conectado` |
| `conectado` | `estado` **com** assento | guarda a projeção | `conectado` |
| `conectado` | `estado` **sem** assento | **descarta** | `conectado` |
| `conectado` | `estado` com visão malformada | descarta | `conectado` |
| `conectado` | `authExpirou` | pede token novo (**um por vez**) | `autenticando` |
| `conectado` | `erro{motivo}` | expõe o motivo **redigido** | `conectado` |
| `conectado` | `sair()` | apaga mesa, assento e projeção | `conectado` |
| `conectado` | socket caiu | agenda backoff | `conectando` |
| `erro` | timer do backoff | nova tentativa, credencial **fresca** | `conectando` |
| `erro` | tentativas esgotadas (6) | fecha tudo | **`semConexao`** |
| *qualquer* | `desligar()` / `dispose()` | incrementa geração, fecha, esvazia fila | `desconectado` |
| *qualquer* | `encerrarPorLogout()` | acima + apaga mesa, assento e projeção | `desconectado` |
| *terminal* | `tentarNovamente()` | zera o contador de tentativas | `conectando` |
| *terminal* | socket velho fala | ignorado (geração antiga) | — (sem efeito) |

Estados em **negrito** são terminais: o ciclo automático não sai deles sozinho.
`falhaTerminal` expõe isso para a UI, que mostra o que fazer em vez de girar.

### Backoff

Exponencial com teto e **jitter**: metade do intervalo é fixa, metade sorteada.

| Tentativa | 1 | 2 | 3 | 4 | 5 | 6 | limite |
|---|---|---|---|---|---|---|---|
| Intervalo | 0,25–0,5s | 0,5–1s | 1–2s | 2–4s | 4–8s | 8–16s | → `semConexao` |

O jitter não é enfeite: sem ele, uma queda do servidor faz todos os aparelhos
voltarem no mesmo milissegundo e derrubarem de novo o que acabou de subir.

### Geração de sessão

Cada abertura recebe um número; todo retorno tardio confere antes de agir —
token que demorou, mensagem de socket que já caiu, timer de tentativa antiga.
É o que impede socket órfão depois de rebuild/rotação e mensagem de sessão velha
entrando na sessão nova.

### Renovação coordenada

Uma renovação por vez. A trava só cai quando a renovação **termina**, não quando
o token chega — soltá-la ao receber o token deixava uma janela em que os avisos
seguintes disparavam pedidos novos. Cinco `authExpirou` seguidos produzem **um**
pedido de token, não cinco.

Renovar **não** reenvia `entrarMesa`: o socket nunca caiu e o assento continua
nosso. É a diferença entre renovar credencial e reconectar.

---

## 6. Projeção autorizada

O servidor congelado só envia `estado` para conexão que tenha **assento** e
credencial **válida agora** (`c.assento != null && c.estadoAuth === AUTENTICADO`).

**Não existe papel de espectador nesse contrato.** Uma conexão sem assento não
recebe projeção nenhuma — não é omissão desta OS, é o que o servidor faz. O app
espelha a mesma regra em vez de inventar uma visão:

- sem assento, um `estado` que chegue é **descartado**;
- credencial recusada **apaga** a projeção que havia;
- `sair()` apaga mesa, assento e projeção;
- logout apaga tudo, para a conta seguinte não ver dado que não é dela;
- ao reentrar após queda, a projeção antiga é limpa antes de pedir a nova — a
  visão de antes da queda não é mostrada como se fosse o estado atual.

Retomada de assento continua não existindo no servidor (quem cai vira bot e não
reassume). Pré-existente, fora do escopo desta OS.

---

## 7. O token não vaza

Ele sai uma única vez por autenticação, dentro da mensagem `auth`. Não aparece
em URL, log, exceção, `toString()`, `status`, `erro` nem na projeção — e o mesmo
vale para o token renovado.

Além do caminho normal, todo texto que pode ser visto passa por `redigir()`:
JWT, `Bearer`, campos nomeados (`token`, `purchaseToken`, `senha`, `apiKey`,
`uid`), e-mail e query string de URL viram `[REDIGIDO]`. Isso cobre o caminho
anormal — a exceção que traz o corpo junto, o erro de login que traz o e-mail —
que é onde o segredo entra por acidente.

---

## 8. Compatibilidade (importante)

**Não existe compatibilidade cruzada, e é proposital:**

- este app **não** joga contra o servidor hoje em produção — mostra "servidor em
  atualização", e o resto do app (jogo local, torneios, perfil) segue normal;
- o app hoje publicado **não** joga contra o servidor novo: nunca autentica, e o
  primeiro comando volta com `ATUALIZACAO_OBRIGATORIA`.

A implantação precisa ser **coordenada**: `FIREBASE_PROJECT_ID` no Railway → app
publicado → servidor implantado. A ordem completa está em
`docs/WS-AUTH-IDENTIDADE.md` do repositório do servidor, §5.

Também de lá, decisão fechada e que **não** deve ser reaberta: as contas legadas
`j-<random>` têm **corte limpo, sem migração automática**. Nada neste app envia
identificador legado, e nada deve passar a enviar.
