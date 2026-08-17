# Encerramento pendente até a apresentação — V1

O aviso de fim de partida deixa de ser dado por consumido quando CHEGA e passa a
ser dado por consumido quando APARECE.

- Base: `claude/ligacao-encerramento-autoritativo-ui-v1` @ `8bd9661f7274c8f01267e5ba8ffaacf800aa3d14`
- Referência de servidor (somente leitura, repositório `buraco-servidor`):
  `claude/versionamento-visao-autoritativa-v1` @ `7e7572b3471bcec2a6968e6084f56dd407cef601`
- Zero alteração de servidor, zero alteração de protocolo, zero deploy.

---

## 1. O que estava errado

A entrega anterior registrou o risco como residual. Ele é real e não deixa
rastro.

`OrdemDaVisao.talvezEncerramento` respondia a duas perguntas num gesto só:

1. este fim já é conhecido?
2. este fim já foi tratado?

O `Set<String> _terminaisDespachados` respondia às duas com a mesma anotação, e a
anotação acontecia **no recebimento** — antes de existir qualquer apresentação.
Logo em seguida, `online_service.dart` fazia:

```dart
final encerramento = _ordem.talvezEncerramento(decisao, nova);
if (encerramento != null) aoEncerrar?.call(encerramento);
```

O `?.` era a perda. Com o slot vazio, o efeito já estava anotado como despachado
e a chamada não acontecia. O resultado:

1. o servidor declara o fim enquanto a pessoa está fora da rota da mesa — ou na
   janela entre o `dispose` de um vínculo e o `didChangeDependencies` do
   seguinte, que é real na troca de transporte;
2. o efeito fica marcado como resolvido e ninguém o apresenta;
3. a pessoa volta. A mesa mostra "Partida encerrada" — o RETRATO é obrigado a se
   repetir —, mas o AVISO nunca acontece, e não acontece mais: o reenvio
   pós-reconexão bate no livro e é engolido.

Sem erro, sem log, sem teste vermelho. Um diálogo que simplesmente não aparece.

Havia uma segunda janela, menor e do mesmo tipo: mesmo com consumidor montado, a
apresentação esperava um quadro (`addPostFrameCallback`), e a rota podia morrer
nesse intervalo.

---

## 2. A máquina de estados

`LivroDeEfeitosTerminais` (`app/lib/services/livro_de_efeitos_terminais.dart`)
guarda o ciclo de vida de cada aviso da mesa.

```
                registrar()                 reivindicar(dono)
   (chegou) ──────────────────► pendente ─────────────────────► reivindicado
                                   ▲                                 │
                                   │  liberar(dono) /                │ confirmar(dono)
                                   │  liberarTudoDe(dono)            ▼
                                   └───────────────────────────  apresentado
                                                                (fim de linha)
```

| Situação | Significado |
|---|---|
| `pendente` | Chegou do servidor e ninguém apresentou. Espera indefinidamente. Sobrevive a reconexão e a troca de transporte. |
| `reivindicado` | Um proprietário identificável assumiu a apresentação. |
| `apresentado` | O aviso entrou na árvore. Daqui não se volta. |

`reivindicado` existe porque apresentar não é instantâneo: entre "vou apresentar"
e "apresentei" cabe um quadro inteiro, e nele chegam reconstruções, reenvios do
servidor e trocas de transporte. Sem esse estado, cada um abriria seu diálogo.

A transição que importa é a que **não** é de mão única: `reivindicado` volta a
`pendente`. Reivindicar é promessa; promessa não cumprida devolve o efeito. É a
diferença entre um aviso adiado e um aviso perdido.

`confirmar` e `liberar` exigem a **mesma posse** que reivindicou. `PosseDoEfeito`
é objeto opaco, sem conteúdo e sem `==` próprio: identidade por instância é a
característica inteira. A geração do consumidor da tela não serviria — ela é um
número da tela, e o livro vive no transporte, que sobrevive a ela; uma tela nova
começaria a contar do zero e teria a mesma geração de uma morta.

Nada é persistido. O livro vive em memória, com a mesa. Não há Firebase,
Firestore nem servidor nesta camada.

---

## 3. Quem faz o quê, e quando

| Momento | Onde | O que acontece |
|---|---|---|
| Recebimento | `online_service.dart`, `case 'estado'` | `talvezEncerramento` anota **pendente** e devolve o aviso se ele for novo. |
| Cutucada | `aoEncerrar?.call(...)` | Avisa quem estiver montado. Slot vazio **não perde nada**. |
| Assinatura | `_LobbyOnlineState._ligarAoEncerramento` | Drena o livro na hora — é o caminho de quem chegou depois do fim. |
| Reivindicação | `_drenar`, **antes** de esperar o quadro | Exclusiva. Uma segunda cutucada encontra o livro sem pendente. |
| Apresentação | `_apresentar`, no `addPostFrameCallback` | Tudo reconferido: `mounted`, geração e transporte. |
| Confirmação | `_apresentar`, **depois** do apresentador | Só com `ResultadoDaApresentacao.apresentado`. |
| Devolução | `dispose`, troca de transporte, recusa, **estouro**, rota morta | `liberar` / `liberarTudoDe`. O efeito volta a pendente. |

O consumidor instalado no slot **ignora** o encerramento que recebe de parâmetro.
Apresentar o que veio pela cutucada seria voltar a ter duas fontes para o mesmo
efeito — e a que chega pelo slot é justamente a que não sobrevive às janelas.

`ensureVisualUpdate()` continua vindo imediatamente antes do
`addPostFrameCallback`: `addPostFrameCallback` não agenda quadro nenhum, e há um
caminho real em que ninguém suja a árvore pelo efeito (carimbo repetido com visão
terminal é `duplicada`, e o transporte volta antes de notificar).

---

## 4. O apresentador

`ApresentadorDeEncerramento.apresentar` passa a devolver
`ResultadoDaApresentacao`:

| Valor | Quando | Efeito no livro |
|---|---|---|
| `apresentado` | O diálogo entrou na árvore | confirmado |
| `recusado` | Não há navegador onde inserir | devolvido a pendente |
| `cancelado` | O contexto já não estava montado | devolvido a pendente |
| _(estouro)_ | O apresentador lançou exceção | devolvido a pendente, e o erro é relatado |

### O estouro do apresentador

Um apresentador pode quebrar de **duas** formas, e são caminhos diferentes de
código para quem chama: um `throw` antes de o futuro existir acontece na
**chamada**; um futuro que completa com erro acontece no **`await`**. O `try` de
`_apresentar` envolve a chamada inteira justamente para não escolher entre os
dois.

Sem esse `catch`, a exceção sobe por um `addPostFrameCallback` — para um futuro
que ninguém aguarda — e leva junto a reivindicação: o aviso fica travado em
`reivindicado` por um dono vivo que já desistiu dele. Ninguém apresenta e
ninguém libera. É a mesma perda silenciosa desta OS, por outra porta.

A ordem importa: **devolve primeiro, relata depois**. Se o relato falhar (e
`FlutterError.onError` é um gancho que a aplicação instala), o efeito já está de
volta no livro.

O relato usa `FlutterError.reportError`, e não log: por esta camada passam ids de
carta e a auditoria proíbe log aqui com razão. `reportError` é o canal do próprio
framework, vai para onde a aplicação mandar os erros e não escreve nada por conta
própria. Engolir em silêncio esconderia um defeito do apresentador — exatamente a
classe de falha muda que esta entrega existe para acabar.

`DialogoDeEncerramento` confere `context.mounted` e
`Navigator.maybeOf(context, rootNavigator: true)` antes de tentar, e **não espera**
o `showDialog` completar — ele só completa quando a pessoa fecha o aviso, e
segurar a confirmação até lá seria segurá-la exatamente durante a janela em que
um segundo diálogo seria pior.

O desenho, o texto e as ações "Ver a mesa" e "Sair da mesa" não mudaram. Sair
continua saindo pela porta de comandos.

---

## 5. O que continua valendo

- O efeito **não** nasce da visão. `encerrada: true` é retrato, e retrato é
  obrigado a se repetir.
- Escopo: o consumidor mora na rota da mesa (`_LobbyOnlineState`), nunca na raiz,
  no `MaterialApp` ou na Home. Há teste de ausência fixando isso.
- O modo legado (envelope sem carimbo) tem a mesma semântica de pendente e
  apresentado, com a identidade fraca que já existia. Nenhum `eventoId` é
  fabricado no cliente.
- Nenhuma camada de áudio foi criada.

---

## 6. Evidência

| Portão | Antes | Depois |
|---|---|---|
| `flutter analyze` | 38 (28 info, 10 warning, 0 erro) | 38, lista idêntica |
| Suíte da área (`test/casca`) | 218 | 255 |
| Suíte completa | 571 +4 | 608 +4 |

As quatro falhas da suíte completa são as preexistentes de carga por ausência de
`assets_registry.seed.json`, nos mesmos quatro arquivos e com a mesma mensagem.

### Provas por defeito injetado

Cada defeito foi aplicado, medido e revertido; a árvore ficou limpa entre eles.

| Defeito | Casos que caem |
|---|---|
| Consumo marcado no recebimento | 35 |
| Descarte do evento quando não há listener | 6 |
| Confirmação no agendamento, antes de apresentar | 8 |
| Sem liberação quando o apresentador falha | 2 |
| Sem conferência de posse em `confirmar`/`liberar` | 2 |
| Modo legado sem tratamento pendente | 3 |
| Assinatura movida para o `build` | 21 |
| Efeito inferido da visão terminal | 26 |
| `catch` do apresentador neutralizado | 3 |

O último foi injetado trocando `catch (erro, pilha)` por `on OutOfMemoryError
catch (erro, pilha)`: o bloco continua compilando e nunca casa. Os três casos do
estouro caem, e a mensagem é o próprio invariante — esperado `pendente`, obtido
`reivindicado`.

---

## 7. Riscos residuais

1. **Recusa ou estouro com a tela viva não tenta de novo sozinho.** O efeito
   fica pendente até a próxima entrada legítima na mesa (reentrada ou troca de
   transporte) — há caso fixando que essa reentrada apresenta. Um repique
   automático foi descartado: ele giraria contra um apresentador que falhasse
   sempre. Em produção a recusa exige uma rota sem navegador, que a casca não
   produz, e o estouro exige um defeito no apresentador, que passa a ser
   relatado em vez de silencioso.
2. **A dedup do modo legado continua sendo por mesa, não por fim.** É a
   identidade que o servidor antigo permite. Duas partidas seguidas na mesma
   mesa sem carimbo compartilhariam a mesma anotação — o que só se corrige no
   servidor, e o servidor novo já carimba.
3. **O livro morre com o processo.** Um encerramento pendente quando o
   aplicativo é fechado não é reapresentado na abertura seguinte. É deliberado:
   persistir descreveria uma sala que talvez nem exista mais.
4. **`_pediuConexao` é por `State`, não por transporte.** Numa troca de
   transporte com reaproveitamento do `State`, a tela não pede `conectar()` ao
   transporte novo. É comportamento anterior a esta OS, da camada de conexão, e
   não foi tocado — está registrado aqui porque apareceu na montagem de um caso.
