# Base canônica de identidade, sessão e autenticação — Conflitos V1

Cada conflito material desta composição, com a intenção de cada lado, a
resolução e o teste que falha se alguma intenção se perder.

**Nenhum conflito foi resolvido por `ours`, `theirs` ou substituição integral de
arquivo.**

---

## Sumário

| # | Onde | Tipo | Resolução |
|---|---|---|---|
| 1 | `app/lib/services/online_service.dart` + `app/lib/sessao/` | **Semântico** — dois donos de autenticação | Sessão vira autoridade única de credencial |
| 2 | `.github/workflows/build.yml` | Textual (auto) — hunks vizinhos | Verificado: os quatro portões convivem |
| 3 | `app/lib/main.dart` | Textual (auto) — regiões distintas | Verificado: as duas intenções inteiras |
| 4 | `app/lib/main.dart` — `_OnlineLobbyHostState` | **Semântico** — ponto de montagem | Transporte passa a nascer da sessão |

Os conflitos 1 e 4 **não aparecem no `git status`**. O merge textual foi limpo
nos dois casos, e é justamente por isso que eles importam: são os que uma
composição apressada declararia resolvida sem nunca tê-los visto.

---

## Conflito 1 — dois donos de autenticação

**Arquivos:** `app/lib/services/online_service.dart` (linhas 33, 88–97 do SHA da
Folha B) contra `app/lib/sessao/sessao_do_jogador.dart` inteiro.

### Intenção da base

Nenhuma. `0cea0d6d` não tem sessão nem autenticação de transporte. O
`OnlineService` da base abre socket e manda comando, sem credencial nenhuma.

### Intenção da Folha A

A `SessaoDoJogador` é a autoridade única de identidade do jogador autenticado.
Mantém uma **geração de sessão** que sobe a cada login/logout/troca, e toda
resposta assíncrona carrega a geração em que nasceu — se a geração virou, a
resposta é descartada. É a trava que impede a resposta atrasada do jogador A de
contaminar a sessão do jogador B.

### Intenção da Folha B

O app apresenta credencial em vez de declarar identidade. Para isso, o
`OnlineService` precisa de um ID Token, e o obtém assim:

```dart
static Future<String?> _idTokenDoFirebase() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return null;
  return u.getIdToken();
}
```

### O conflito

As duas intenções são corretas e **incompatíveis quando coexistem**. Juntas,
produzem dois objetos com opinião sobre quem está logado, e o segundo (o
transporte) não sabe que a geração de sessão existe.

O defeito concreto — e ele não é teórico:

```
t0  jogador A logado, socket caindo, backoff dispara _abrir()
t1  _abrir() chama await _obterIdToken()          ← lê FirebaseAuth direto
t2  jogador A faz LOGOUT
    · a sessão sobe a geração e vira `deslogado`
    · o transporte não fica sabendo de nada
t3  o token de A volta do await, válido
t4  o socket abre e manda {tipo:"auth", token: <token de A>}
```

O app acabou de autenticar como um jogador que já saiu. Nenhuma das duas suítes
enxergava isso: a da Folha A não conhece socket, a da Folha B não conhece
sessão.

### Resolução

A credencial passa a sair pela **mesma** autoridade que conhece a geração.

1. **Nova porta** `FonteDeCredencial` em
   `app/lib/sessao/credencial_de_sessao.dart` — irmã de `FonteDeIdentidade`, e
   pelo mesmo motivo: o controller não pode importar `firebase_auth` sem tornar
   os testes de logout dependentes do SDK.

2. **`SessaoDoJogador.obterCredencial()`** aplica à credencial exatamente a
   trava que a Folha A já aplicava à identidade — geração capturada antes do
   `await`, conferida depois, `null` se virou.

3. **`CredencialDoFirebase`** em `sessao_firebase.dart` passa a ser o único
   ponto do app que extrai token do Firebase.

4. **`online_service.dart` perde o import de `firebase_auth`** e o construtor
   passa a **exigir** `obterIdToken`. A obrigatoriedade é o mecanismo: enquanto
   havia padrão, `OnlineService()` solto em qualquer canto já nascia sabendo
   autenticar sozinho, como um segundo dono.

5. **Geração de transporte** em `OnlineService`, que fecha o resto: o caso em
   que a credencial voltou válida logo *antes* do logout e a continuação
   seguiria em frente com ela na mão. `_abrir` e `_renovarCredencial` conferem
   depois de cada `await`; a que abriu o socket é quem o fecha.

### Nenhuma intenção se perdeu

| Intenção | Onde está agora |
|---|---|
| A: geração de sessão trava resposta atrasada | intacta, e agora vale para credencial também |
| A: controller não importa `firebase_auth` | intacta — o adaptador é que importa |
| B: app apresenta credencial, não declara identidade | intacta — mudou só a **fonte** |
| B: reconexão pega token fresco | intacta — pede à sessão a cada tentativa |
| B: token não vaza | intacta, e ampliada para a camada de sessão |

### Testes que falham se alguma se perder

```
test/sessao/uniao_sessao_transporte_test.dart
  §8.3/§8.4  'o transporte não conhece firebase_auth'          ← trava estrutural
  §8.6       'logout enquanto o token está NO AR não abre socket nenhum'
  §8.6       'logout enquanto renova descarta o token atrasado'
  §8.6       'a sessão devolve null para o token que chega depois do logout'
  §8.8       'a conexão de B usa o token de B, e nunca o de A'
```

Executados antes de seguir: **32/32 verdes**.

---

## Conflito 2 — `.github/workflows/build.yml`

**Merge textual: automático, sem marcador.** Os dois lados escreveram em regiões
vizinhas do mesmo arquivo, o que é exatamente o caso em que o git acerta o texto
e pode errar o sentido. Verificado à mão.

### Intenções

* **Folha A** acrescenta o *PORTÃO DE QUALIDADE — resiliência do motor*, logo
  depois do portão do motor.
* **Folha B** acrescenta dois passos: *Deps de TESTE* (`stream_channel` e
  `fake_async` como dev, antes de qualquer portão) e o *PORTÃO DE SEGURANÇA —
  identidade da conexão online*, depois do portão de recompensas.

### Resolução

Nenhuma. O resultado do merge já era o correto, e foi **verificado**, não
presumido:

```
148  Deps de TESTE (só dev — não entram no APK)              ← Folha B
178  PORTÃO DE QUALIDADE — testes do motor                   ← base
198  PORTÃO DE QUALIDADE — resiliência do motor              ← Folha A
227  PORTÃO DE QUALIDADE — domínio de recompensas            ← base
246  PORTÃO DE SEGURANÇA — identidade da conexão online      ← Folha B
```

Os quatro portões convivem, na ordem certa, e o passo de dependências vem antes
de todos eles — que é a única ordenação em que os dois portões novos rodam.

### Ressalva registrada

Este arquivo **não foi executado** nesta entrega. O CI deste repositório só
dispara por `workflow_dispatch` e a partir da branch padrão; declarar verde um
pipeline que não rodou seria maquiar. Ver
[EVIDÊNCIA](BASE-IDENTIDADE-SESSAO-AUTH-EVIDENCIA-V1.md) §5.

---

## Conflito 3 — `app/lib/main.dart`, regiões distintas

**Merge textual: automático, sem marcador.** Verificado.

### Intenções

* **Folha A** reescreve `BuracoApp` de `StatelessWidget` para `StatefulWidget`,
  cria a `SessaoDoJogador` na raiz e a pendura em `EscopoSessao`; e altera
  `_AmigosPreviewHost` e `_RankingPreviewHost` para consumirem identidade.
* **Folha B** acrescenta quatro ramos ao `switch` de status do lobby
  (`autenticando`, `naoAutenticado`, `atualizacaoObrigatoria`,
  `servidorDesatualizado`).

As regiões não se tocam — raiz e telas de preview contra linha ~1190.

### Verificação

```
26,27  import 'sessao/escopo_sessao.dart' …            ← Folha A
92     late final SessaoDoJogador _sessao = …          ← Folha A
102    return EscopoSessao(sessao: _sessao, …          ← Folha A
1190-1199  os oito ramos do switch, completos          ← base + Folha B
```

Nenhum ramo do `switch` se perdeu, e a raiz continua dona da sessão.

---

## Conflito 4 — o ponto de montagem do transporte

**Não aparece no merge.** É a consequência do Conflito 1 no único lugar do app
que constrói um `OnlineService`.

### Estado após o merge textual

```dart
class _OnlineLobbyHostState extends State<_OnlineLobbyHost> {
  final OnlineService _srv = OnlineService();   // ← sem credencial nomeada
  …
  void initState() { _srv.addListener(_atualizar); _srv.conectar(); }
```

Compilava, e estava errado: era o segundo dono de autenticação sendo construído.

### Resolução

O transporte passa a nascer **da sessão da árvore**, e por isso não pode mais
ser inicializado num campo — a sessão vem do `context`, disponível só a partir
de `didChangeDependencies`.

```dart
late final OnlineService _srv;
PonteSessaoOnline? _ponte;
bool _ligado = false;

void didChangeDependencies() {
  super.didChangeDependencies();
  if (_ligado) return;          // o escopo é InheritedNotifier: isto re-roda
  _ligado = true;
  final sessao = EscopoSessao.talvezDe(context);
  if (sessao == null) {
    _srv = OnlineService(obterIdToken: () async => null);
  } else {
    _srv = criarOnlineServiceDaSessao(sessao);
    _ponte = PonteSessaoOnline(sessao: sessao, online: _srv);
  }
  _srv.addListener(_atualizar);
  _srv.conectar();
}
```

### Três decisões dentro desta resolução

1. **A trava `_ligado`.** `EscopoSessao` é um `InheritedNotifier`, então
   `didChangeDependencies` roda de novo a cada notificação da sessão. Sem a
   trava, cada avanço de fase da identidade construiria outro socket.
   *Teste:* §8.11 `'a fase da identidade avançando não mexe no transporte'`.

2. **Sem escopo, transporte sem credencial.** A tela também roda em
   pré-visualização isolada, sem sessão acima. Ali o transporte para em "entre
   na sua conta para jogar online" — que é a verdade daquele ambiente. A
   alternativa (deixar o transporte procurar credencial sozinho) é o defeito
   que esta composição existe para fechar.

3. **A ponte religa depois de uma troca de conta.** Decisão registrada por ter
   um trade-off real: a alternativa — sempre deixar em `desconectado` — tem um
   buraco concreto, porque o lobby chama `conectar()` ao montar e a tentativa em
   voo morreria na troca de geração, sem ninguém para refazê-la. Religar não é
   iniciativa da ponte: é ela preservando um pedido que o jogador já fez. Logout
   **não** religa.
   *Teste:* §8.8 `'a conexão de B usa o token de B, e nunca o de A'` e
   §8.7 `'logout fecha o socket e não reconecta sozinho'`.

---

## Decisões novas de produto: nenhuma

A OS §7 manda parar se surgir decisão nova de produto, nova política de
autenticação, mudança de backend ou incompatibilidade sem contrato aprovado.

Nada disso surgiu. O protocolo 2 já estava aprovado na Folha B; a autoridade da
sessão já estava aprovada na Folha A; o backend não foi tocado. As quatro
resoluções acima são **arquiteturais**, e todas escolhem preservar as duas
intenções em vez de arbitrar entre elas.

O único ponto com trade-off de comportamento visível ao jogador — religar a
conexão após troca de conta — está registrado acima com o motivo, e é revertível
em uma linha.
