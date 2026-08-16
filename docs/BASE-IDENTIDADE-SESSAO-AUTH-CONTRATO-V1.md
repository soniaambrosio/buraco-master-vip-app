# Base canônica de identidade, sessão e autenticação — Contrato V1

Quem é dono do quê, qual é o ciclo de vida de cada coisa, e por onde a Casca de
Produção vai encostar nisto sem quebrar nada.

---

## 1. As autoridades

Há **três** objetos com responsabilidade nesta base, e nenhum deles se sobrepõe
a outro.

| Objeto | Arquivo | É dono de |
|---|---|---|
| `SessaoDoJogador` | `app/lib/sessao/sessao_do_jogador.dart` | Quem está logado, a identidade pública, a geração de sessão e **a credencial** |
| `OnlineService` | `app/lib/services/online_service.dart` | O socket, o protocolo, a fila de comandos e o estado da conexão |
| `PonteSessaoOnline` | `app/lib/services/ponte_sessao_online.dart` | Traduzir troca de sessão em transição de transporte. Nada mais. |

### A regra que sustenta tudo

> **Só a sessão emite credencial.** O transporte não conhece `firebase_auth`, e
> há teste estrutural que falha se voltar a conhecer.

Antes desta composição existiam **dois** donos de autenticação: a sessão sabia
quem estava logado, e o transporte perguntava ao Firebase por conta própria.
Funcionava nos dois testes isolados e estava errado — ver
[CONFLITOS](BASE-IDENTIDADE-SESSAO-AUTH-CONFLITOS-V1.md) §1.

### Direção das dependências

```
   main.dart (UI)
        │  monta os dois e entrega um ao outro
        ▼
   services/  ──────────────►  sessao/
   (transporte + ponte)         (identidade + credencial)
```

`services/` conhece `sessao/`. `sessao/` **não** conhece `services/`. Nenhum dos
dois conhece a UI. Não há ciclo.

---

## 2. Ciclo de vida da sessão

### 2.1 Nascimento

A sessão nasce em `_BuracoAppState` — a raiz do app —, e não numa tela. O
controller assina o fluxo de autenticação sozinho; quando um login acontece, a
identidade pública é resolvida sem que ninguém tenha aberto Ranking, Perfil ou
Social.

### 2.2 Geração

Todo **troca de sessão** incrementa `geracao`:

| Evento | Sobe a geração? |
|---|---|
| Login | sim |
| Logout | sim |
| Troca de conta A → B | sim |
| Mesmo uid reemitido (renovação de token) | **não** |
| Fase da identidade avança (`carregando` → `disponivel`) | **não** |

Essa distinção não é cosmética: é o que impede que o Ranking terminando de
carregar derrube a mesa de alguém.

### 2.3 A trava da resposta atrasada

Toda operação assíncrona da sessão captura a geração **antes** do `await` e a
confere **depois**. Vale para os dois lados:

* `_executar` (identidade) — descarta a resposta se a geração virou;
* `obterCredencial` (credencial) — devolve `null` se a geração virou.

É por isso que o token do jogador que acabou de sair nunca vira um `auth` no
fio.

### 2.4 Logout

Logout invalida a geração, substitui o estado por `deslogado` e solta a
requisição em voo. Nenhum resquício do jogador anterior sobrevive: nem
identidade, nem `publicId`, nem a promessa em andamento — e, via ponte, nem
código de mesa, assento ou visão.

### 2.5 Cache

Em memória apenas. Não há `SharedPreferences`, SQLite, Hive nem arquivo — uma
segunda fonte de verdade precisaria de uma política de invalidação que nenhuma
OS especificou, e a memória do processo morre junto com a sessão, que é
exatamente a validade desejada. Há teste estrutural que falha se alguém
introduzir persistência em `lib/sessao/`.

---

## 3. Ciclo de vida do transporte

### 3.1 A sequência

```
conectar()
   → pedir credencial À SESSÃO           (nunca ao Firebase)
   → sem credencial: naoAutenticado, e para aqui
   → abrir socket
   → {tipo:"auth", token, protocolo:2}   PRIMEIRA mensagem
   → esperar "autenticado"               fila segurada
   → SÓ ENTÃO soltar os comandos
```

### 3.2 Estados

| Estado | Significado | Terminal? |
|---|---|---|
| `desconectado` | ninguém pediu, ou foi desligado | não — `conectar()` funciona |
| `conectando` | buscando credencial / abrindo socket | não |
| `autenticando` | socket aberto, credencial ainda não aceita | não |
| `conectado` | credencial aceita; comandos fluem | — |
| `erro` | falha **transitória** de rede; o backoff tenta de novo | não |
| `naoAutenticado` | sem credencial, ou credencial recusada | **sim** |
| `atualizacaoObrigatoria` | servidor exige protocolo mais novo | **sim** |
| `servidorDesatualizado` | servidor não fala protocolo 2 | **sim** |

Os três terminais não reconectam: insistir não resolveria nenhum deles. E não
existe fallback para protocolo 1 — jogar contra um servidor antigo exigiria
voltar a declarar identidade pelo cliente, que é o buraco que foi fechado.

### 3.3 Geração do transporte

Espelha, do lado do socket, o que a geração de sessão faz do lado da
identidade. Sobe em `desligar()`, `encerrarSessao()` e em toda falha terminal.
`_abrir` e `_renovarCredencial` capturam antes do `await` e conferem depois —
um logout no meio de qualquer um dos dois mata a continuação, incluindo o caso
em que o socket já tinha aberto (ele é fechado pela própria continuação, que é
quem o tem em mãos).

### 3.4 Renovação de credencial

`authExpirou` com a conexão de pé → busca token novo **na sessão** e reapresenta
no **mesmo** socket. Não reentra na mesa: o assento nunca foi perdido, e
reentrar pegaria outro.

---

## 4. A união — como os dois ciclos se falam

### 4.1 Uma troca de sessão, uma transição

A ponte reage a **geração**, não a notificação. Quando a geração muda, ela faz
uma coisa só:

```
queria = online.querConectado        // lê o pedido do jogador ANTES
online.encerrarSessao()              // derruba socket, reconexão, refresh
                                     // pendente, fila, e apaga mesa/assento/visão
if (queria && sessão autenticada)    // e só então
    online.conectar()                // religa sob a identidade NOVA
```

**Por que religa.** A tela do lobby chama `conectar()` ao montar. Se o login
chegar logo depois, a tentativa em voo morre na troca de geração — e sem esta
linha ninguém a refaria, deixando o jogador olhando "desconectado" sem nada para
apertar. Isto não é a ponte tomando iniciativa: é ela não fazendo o jogador
perder um pedido que ele já tinha feito.

**Por que logout não religa.** Sem sessão autenticada não há credencial, e
insistir só produziria "entre na sua conta" em loop.

### 4.2 Falha de transporte não derruba sessão

Credencial recusada pelo servidor põe o transporte em `naoAutenticado`. A
`SessaoDoJogador` **continua válida** — uid e `publicId` intactos. O caminho
inverso é que vale: quando a sessão cai, o transporte cai junto.

### 4.3 Sem segundo cache

O transporte não guarda credencial. Toda conexão e toda renovação pedem à
sessão de novo. Não há corrida entre "o token que o socket tem" e "o token que a
sessão tem", porque o socket não tem nenhum.

---

## 5. O seam para a Casca de Produção

A Casca vai precisar de duas coisas, e as duas já estão expostas:

### 5.1 Ler a sessão

```dart
EscopoSessao.talvezDe(context)        // a SessaoDoJogador, ou null fora do escopo
EscopoSessao.identidadeDe(context)    // o EstadoIdentidadeSessao (nunca null)
```

`EscopoSessao` é um `InheritedNotifier`: a tela reconstrói sozinha quando a fase
muda. Fora do escopo, `identidadeDe` devolve `deslogado` — "não há identidade",
que é a leitura correta e a única segura.

### 5.2 Ler o estado da conexão

`OnlineService` é um `ChangeNotifier`. `status`, `erro`, `conectado`,
`querConectado`, `codigo`, `meuAssento` e `visao` são leitura direta.

### 5.3 Montar o par

```dart
final srv = criarOnlineServiceDaSessao(sessao);
final ponte = PonteSessaoOnline(sessao: sessao, online: srv);
```

O construtor de `OnlineService` **exige** `obterIdToken`. Isso é proposital: sem
padrão, todo ponto de construção precisa dizer de onde vem a credencial, e a
única resposta certa é a sessão.

### 5.4 O que a Casca ainda vai ter de decidir

Nada disso foi decidido aqui, e nenhuma dessas decisões está escondida no
código:

* **Quando conectar.** Hoje quem pede é a tela do lobby, ao montar. Se a Casca
  quiser conexão viva desde o login, o lugar de decidir isso é a Casca.
* **Para onde mandar quem não está autenticado.** Não há roteamento nesta base.
* **O que mostrar em cada estado terminal.** Há texto no lobby; uma Casca de
  produção vai querer telas.

---

## 6. Invariantes que não podem cair

Se alguma destas deixar de valer, a base deixou de ser canônica:

1. Existe **uma** `SessaoDoJogador` por app, acima do `MaterialApp`.
2. `online_service.dart` **não** importa `firebase_auth`.
3. Nenhuma mensagem do cliente carrega `jogadorId`, `uid`, `publicId` ou
   equivalente — nem a chave, nem o valor disfarçado.
4. Nada sai pelo socket antes de `autenticado`.
5. Logout fecha socket, cancela reconexão e refresh, e apaga o estado privado.
6. Resposta assíncrona de geração antiga nunca toca o estado.
7. Protocolo 1 não tem caminho de volta.
8. O token não aparece em URL, log, erro, `toString()`, fixture ou snapshot.

Todas as oito têm teste. Ver
[EVIDÊNCIA](BASE-IDENTIDADE-SESSAO-AUTH-EVIDENCIA-V1.md).
