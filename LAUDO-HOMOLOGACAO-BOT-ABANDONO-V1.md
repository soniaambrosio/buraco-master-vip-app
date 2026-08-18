# LAUDO — HOMOLOGAÇÃO ADVERSARIAL DA CADEIA DO BOT E ASSUNÇÃO DE ASSENTO APÓS ABANDONO V1

**VEREDITO: `BLOCKED — ASSUNÇÃO AUTORITATIVA DE ASSENTO PELO BOT AUSENTE`**

A homologação parou no STOP obrigatório do §4. **Não existe, no candidato,
caminho canônico que substitua um jogador que abandona por um bot.** Não há
sequer o conceito de "quem controla este assento": o assento 0 é humano por
construção e os assentos 1, 2 e 3 são robôs por construção.

Conforme a OS determina, a substituição **não foi inventada** dentro desta
homologação. Nenhuma linha de produção foi tocada.

---

## 1. Git

| item | valor |
| ---- | ----- |
| branch de homologação | `homologacao/bot-cadeia-completa-abandono-v1` |
| candidato | `claude/bot-orcamento-busca-stbl-v1` |
| SHA do candidato | `d3effdc119bd68ccf27fdcb628834a43baf5c6d8` |
| candidato é ancestral do HEAD | sim (a branch nasceu dele) |
| árvore | limpa |
| `git diff d3effdc -- app/lib` | **vazio** |
| deploy / PR / merge | **nenhum**; `main` intocada |

### Resolução do candidato por duas vias independentes

```
git ls-remote origin refs/heads/claude/bot-orcamento-busca-stbl-v1
  -> d3effdc119bd68ccf27fdcb628834a43baf5c6d8
git ls-remote --heads origin | grep bot-orcamento-busca-stbl-v1
  -> d3effdc119bd68ccf27fdcb628834a43baf5c6d8
```

### Ancestralidade da cadeia

```
89fca38                                    Bot IA Estratégica V1        -> SIM
f41eea0                                    Encerramento legal de turno  -> SIM
07eb4ff                                    Proveniência de descartes    -> SIM
6b028be8ad19fbbcdf3d5511d0df0fafabb07a6b   Calibração (base da OS 4)    -> SIM
d3effdc119bd68ccf27fdcb628834a43baf5c6d8   Orçamento/fallback STBL      -> candidato
```

---

## 2. Gate Zero — o que passou

| item | esperado | medido |
| ---- | -------- | ------ |
| suíte nominal | 479 verdes | **479 verdes** |
| skips | zero | **zero** |
| analyzer | sem diagnóstico novo | **118, delta 0** |
| árvore limpa | sim | sim |

**A cadeia existente está verde.** O bloqueio não é sobre ela.

---

## 3. Onde o abandono é detectado — e onde não é

Varredura de `app/lib` por `abandon|desconect|disconnect|ausent|inativ|
substitu|takeover|assumir|timeout`:

| lugar | o que existe | serve como detecção de abandono? |
| ----- | ------------ | -------------------------------- |
| `services/online_service.dart` | `enum OnlineStatus { desconectado, conectando, conectado, erro }` e reconexão automática com backoff | **Não.** Descreve a conexão **deste** aparelho com o servidor. Não observa os outros três jogadores, e não informa nada ao motor. |
| `mesa.dart` — relógio de turno | quando o cronômetro zera na vez do assento 0, chama `_autoJogarPorTempo()` | **Não.** É inatividade de UM turno, não abandono. Ver §5. |
| resto de `app/lib` | nada | — |

Não há, no candidato, nenhum ponto que observe "o jogador do assento N sumiu".

---

## 4. Onde a troca deveria ocorrer — e por que hoje não pode ocorrer

### O assento não tem controlador

`Jogo` (`app/lib/mesa.dart`) tem mãos, monte, lixo, mortos, jogos por dupla,
vez, placar, vulnerabilidade, apelidos, avatares e mascotes. **Não tem nenhum
campo que diga quem controla cada assento.** Não existe `tipo`, `assentosBot`,
`controlador` nem equivalente.

Quem é humano e quem é robô está **codificado no número do assento**, em seis
lugares de `mesa.dart`:

```
314   bool get suaVez => vez == 0;
2255  if (_j.vez != 0) { ... }
2299  if (_j.vez == 0 && !_j.rodadaEncerrada && !_botsRodando) _autoJogarPorTempo();
2317  if (_j.vez != 0 || _j.rodadaEncerrada || _botsRodando) return;
2770  while (_j.vez != 0 && ...) { _j.botJoga(_j.vez); }   // laço dos robôs
4601  if (_j.vez != 0 && !_j.rodadaEncerrada) _rodarBots();
```

O laço dos robôs é literalmente "enquanto a vez não for do assento 0". Um bot
assumir o assento 0 não é uma configuração possível: seria preciso **inverter a
condição de parada do laço**, que é código de produção — e o §2 proíbe alterá-lo
nesta OS.

### O bot só é acionado de um lugar

```
grep -rn "ExecutorBot|botJoga|jogadaAutomatica" app/lib --include=*.dart
  (fora de mesa.dart e bot/): nenhuma ocorrência
```

A camada estratégica inteira é acionada só por `Jogo.botJoga(assento)`, e quem
chama `botJoga` é o laço acima. Não há API pública de "faça o bot assumir o
assento N".

### Nenhum teste exercita takeover

Busca por `abandon|takeover|assumir|substitu|desconect` em `app/test/`: as
únicas ocorrências são sobre **curinga substituto** em melds — assunto sem
relação.

---

## 5. `jogadaAutomatica` não é assunção de assento

É o candidato mais próximo, e é importante dizer com precisão por que **não**
serve — para que ninguém a confunda com a substituição em falta:

```dart
bool jogadaAutomatica(int assento) {
  ...
  if (!jaComprou) { comprarMonte(assento); ordenar(assento); }
  if (jaComprou && !rodadaEncerrada) {
    for (final c in List<Carta>.from(maos[assento])) {
      final erro = descartar(assento, c.id);
      if (erro == null) break;   // primeira carta que sair, sai
    }
  }
  ...
}
```

| dimensão | `jogadaAutomatica` | o que a assunção de assento exigiria |
| -------- | ------------------ | ------------------------------------ |
| quem decide | ninguém: compra do monte e descarta a **primeira carta legal** varrendo a mão | `ExecutorBot`, com a camada estratégica homologada |
| duração | **um turno**; no turno seguinte o humano volta a ser esperado | permanente até política de retorno decidir o contrário |
| gatilho | cronômetro zerou (inatividade momentânea) | abandono/desconexão observada |
| assento | fixo em 0 | qualquer assento |
| orçamento | não usa (não há busca) | orçamento por decisão da OS 4 |
| proveniência | não usa | modelo público reconstruído da proveniência canônica |

Homologar `jogadaAutomatica` como se fosse takeover seria homologar outra coisa
com o nome da coisa pedida. Ela sequer chama o bot que esta OS deveria
homologar.

---

## 6. O `substituto` do servidor Node é outro bot, em outro repositório

Para não deixar a impressão de que "existe em algum lugar": o servidor
(`F:/Projetos/buraco-servidor`, `server.js`) tem, sim, um perfil de bot chamado
`substituto`, com o comentário `B4: bot substituto de reconexao (secao 30)`, e
tem `desconectar(id)`.

Isso **não** satisfaz o §4 do candidato, por três razões independentes:

1. **É outro repositório.** O candidato desta OS é o app, no SHA `d3effdc`. A
   OS §29 exige `git diff <candidato> -- app/lib` vazio; o servidor não está
   sob homologação nem sob o SHA congelado.
2. **É outro bot.** O `substituto` do servidor é um perfil ISMCTS em
   JavaScript (`orcamentoMs: 40, maxIter: 50, depth: 2`). A cadeia que esta OS
   manda homologar — Bot IA Estratégica V1, encerramento legal de turno,
   proveniência de descartes, calibração, orçamento determinístico — é a
   implementação **Dart**, em `app/lib/bot/` e `app/lib/rules/`. São dois
   motores de decisão distintos.
3. **Orçamento por tempo, não por trabalho.** O perfil do servidor usa
   `orcamentoMs`, isto é, **relógio** — exatamente o critério que a OS 4 proibiu
   como autoridade de decisão, por tornar a jogada dependente da velocidade da
   máquina. Homologar aquilo sob os critérios desta OS reprovaria no §13.

---

## 7. O que a implementação vai precisar (entregue como pedido pelo §4)

### Onde o abandono é detectado

Hoje: em lugar nenhum do candidato. Precisa nascer. Duas fontes possíveis, e
elas não são equivalentes:

* **partida local** (o que o candidato roda): não há outros humanos — o único
  humano é o assento 0. "Abandono" aqui só pode significar inatividade
  prolongada, e o gatilho natural é o relógio que já existe.
* **partida online**: quem observa a queda é o **servidor**, que já tem
  `desconectar(id)`. O app é cliente e recebe `visao`. Nesse caminho, a decisão
  de substituir é do servidor, e a cadeia Dart homologada **não participa**.

Essa bifurcação precisa ser decidida antes de codificar: **qual bot assume?**
Se for o online, é o JS; se for o local, é o Dart. Hoje o produto tem os dois.

### Onde a troca deveria ocorrer

No `Jogo`, entre turnos — nunca no meio de um. O ponto natural é imediatamente
antes de `botJoga`/`jogadaAutomatica` decidirem, com o controlador consultado em
vez de `vez == 0`.

### Estado necessário

Um campo canônico por assento, por exemplo `controlador: [humano|bot] x 4`, com
três exigências que decorrem do que já existe:

* precisa entrar no `EstadoJogo` **ou** ser declarado explicitamente como
  envelope de runtime — e a lição já registrada no projeto é que campo normativo
  fora do `EstadoJogo` vira regra morta no primeiro round-trip da autoridade;
* precisa sobreviver a `paraCanonico`/`aplicarEmJogo` e à serialização, senão a
  substituição se desfaz sozinha;
* **não pode** alterar mão, monte, lixo, mortos, jogos, vez, placar nem
  vulnerabilidade — o §16 desta OS já diz isso, e é exatamente o que um teste de
  snapshot normalizado antes/depois provaria.

### Autoridade que deve decidir

A mesma que decide todo o resto: `aplicarLegal` continua julgando a jogada, e o
bot continua sendo só intenção. A **troca de controlador** em si não é jogada e
não deve passar por `aplicarLegal`; deve ser um evento de mesa, aplicado entre
turnos, com o invariante de cartas verificado antes e depois.

### Risco de deixar a mesa pendurada

É o risco concreto de produção, e ele existe **hoje**:

* na partida local, se o humano do assento 0 fecha o app no meio do turno, não
  há quem jogue por ele — o laço `_rodarBots` só roda enquanto `vez != 0`, então
  a mesa fica parada na vez de um assento sem ninguém;
* o relógio cobre **um** turno (`jogadaAutomatica`), e só se a tela estiver
  viva; com o app fechado, nem isso;
* na partida online, o servidor tem `desconectar(id)` e um perfil substituto,
  mas o candidato não sabe disso e não tem como saber — não há campo de
  controlador para refletir a mudança.

### Política de retorno (§17)

**Também ausente.** Não há política definida no candidato: sem controlador de
assento, não há o que retomar. Registrado, como a OS manda, sem escolher "o que
parece melhor":

`BLOCKED — POLÍTICA DE RETORNO APÓS ASSUNÇÃO PELO BOT AUSENTE`

---

## 8. O que NÃO foi executado, e por quê

Os itens abaixo pressupõem a substituição existir. Executá-los produziria
números sobre um mecanismo inexistente — pior que não medir, porque pareceria
evidência.

| § | item | situação |
| - | ---- | -------- |
| 6 | provas de privacidade do bot substituto | não executável: não há bot substituto |
| 8 | 12 momentos adversariais de abandono | não executável |
| 9 | não repetir fase após troca | não executável |
| 10 | compromisso de topo do lixo através da troca | não executável |
| 11 | batida e mão de uma carta após troca | não executável |
| 12 | `ModeloParceiro` de dois bots assumindo em sequência | não executável |
| 14 | orçamento após substituição | não executável |
| 18 | 288 partidas com abandono | não executável |
| 21–22 | múltiplos abandonos e abandono simultâneo | não executável |
| 25–26 | 50 testes independentes e 15 mutações | sem objeto a testar |

O §19 (matriz **sem** abandono) e o §30 (semente patológica) foram medidos na
OS 4 sobre este mesmo SHA e continuam válidos: 384/384 partidas, 49,36%
agregado, pior decisão 0,55 s. Repeti-los aqui não acrescentaria evidência sobre
o que está sendo homologado.

---

## 9. Riscos residuais registrados

1. **A mesa pode ficar pendurada hoje.** Não é hipótese: é a consequência
   direta de o laço de robôs parar no assento 0 e não haver controlador.
2. **Existem dois bots no produto** — o Dart (homologado pela cadeia OS 1–4) e o
   JS do servidor. Quem assume um assento abandonado numa partida online seria o
   JS, que **não** passou pela cadeia de homologação, e cujo orçamento é por
   relógio.
3. **A cadeia Dart nunca foi exercitada fora do assento 0..3 fixo.** Todos os
   479 testes assumem essa distribuição. Quando o controlador existir, a
   suposição "assento 0 é humano" precisa ser varrida do código e dos fixtures.

---

## 10. Conformidade desta homologação

| exigência | resultado |
| --------- | --------- |
| candidato intocado | `git diff d3effdc -- app/lib` **vazio** |
| nenhum código de produção alterado | sim |
| substituição inventada | **não** |
| suíte da cadeia | 479 verdes, zero skip |
| analyzer | 118, delta 0 |
| árvore limpa | sim |
| deploy / PR / merge / `main` | nenhum |

**Veredito: `BLOCKED — ASSUNÇÃO AUTORITATIVA DE ASSENTO PELO BOT AUSENTE`**, com
o bloqueio adicional `BLOCKED — POLÍTICA DE RETORNO APÓS ASSUNÇÃO PELO BOT
AUSENTE`. A implementação é de outra OS.
