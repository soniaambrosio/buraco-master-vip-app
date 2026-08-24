# Ingresso produtivo em mesas públicas e escolha autoritativa de assento V1

**OS 38.3 — cliente Flutter.**
Folha. Sem PR, sem merge em `main`, sem deploy, sem tag.

---

## 1. O que passou a existir

Antes desta folha o Lobby Público mostrava as mesas e **parava ali**:
`onEscolherMesa` era nulo de propósito, e a única porta de ingresso que o
aplicativo tinha — `entrarMesa` só com o código — entraria em *qualquer* lugar.

Agora o caminho é inteiro:

```
Home → Onde Jogar → Entrar em mesa → Lobby Público → escolher mesa
     → escolher assento → solicitar ingresso → aguardar ACK → mesa confirmada
```

E a regra que atravessa cada passo é uma só:

> **O cliente pede. O servidor decide.**
> O único assento que existe para o aplicativo é o que vem dentro do ACK.

Não há caminho, em nenhum arquivo desta folha, que produza um ingresso sem um
`entrou` do servidor. Não há valor padrão, não há "assume o que pediu", e não
há segunda tentativa em outra cadeira.

---

## 2. O servidor consumido

| | |
|---|---|
| repositório | `soniaambrosio/buraco-servidor` |
| branch | `integracao/servidor-assento-descoberta-presenca-v1` |
| SHA | `8a0ee4b76ac915705e2e1a37237666a4aab41c39` |
| estado | PASS · 639/639 · sabotagens 106/106 |

Conferido por `git merge-base --is-ancestor` que esse SHA contém as três
linhagens que a OS exige:

* transporte — `ff3ddbe9d99fa2c9275aee0674ecc8ad323916cb`
* escolha autoritativa de assento (OS 41) — `13ea6f1df29681ec709a32d91391564d4bb3d491`
* descoberta e presença (OS 38.1) — `d1de8a7b2b91dfeb5b409fec61473f10fc21afe4`

**Zero alteração no servidor.** Zero alteração em Functions e em Rules.

---

## 3. O protocolo, como ele é

Lido de `server.js` do SHA acima (`entrarMesa`, `ehAssentoPedido`,
`recusaDeAssento`, `aplicarEntrada`, `erroDeAdmissao`, `concluirPortaDeMesa`) e
congelado em `contrato/ingresso-assento-v1.json`.

### Cliente → servidor

```json
{ "tipo": "entrarMesa", "codigo": "<opaco>", "apelido": "<público>", "assento": 0..3 }
```

`assento` é **opcional**, e a distinção entre ausente e nulo é do contrato:

* **ausente** (a chave não existe) → o servidor aplica a ordem `[2, 1, 3]`;
* **`null` explícito** → pedido malformado → `ASSENTO_INVALIDO`.

O cliente **omite a chave**. Ele não manda `null`, e não manda uma preferência
inventada para imitar o algoritmo do servidor.

### Servidor → cliente

```json
{ "tipo": "entrou", "codigo": "...", "assento": 0..3, "reconexao": false }
{ "tipo": "erro",   "motivo": "...", "codigo": "ASSENTO_OCUPADO" }
{ "tipo": "erro",   "motivo": "mesa cheia" }
```

| recusa | código | quando |
|---|---|---|
| assento ocupado | `ASSENTO_OCUPADO` | a cadeira tem dono — é a recusa da concorrência |
| assento inválido | `ASSENTO_INVALIDO` | fora de 0..3, não inteiro, ou `null` explícito |
| admissão indisponível | `ADMISSAO_VIP_INDISPONIVEL` | backend de direitos não respondeu (mesa VIP) |
| mesa não encontrada | *(sem código)* | a mesa sumiu |
| mesa cheia | *(sem código)* | ingresso automático sem vaga |
| a partida já começou | *(sem código)* | e quem pediu não é titular |

As três últimas chegam **só com `motivo`**, e são lidas por texto — normalizado
sem acento e sem caixa. Classificar errado não concede assento nenhum: no pior
caso vira recusa genérica, e a pessoa continua fora da mesa.

---

## 4. `confirmado == solicitado`, e a única exceção

Quando houve **pedido explícito** e a resposta **não é reconexão**, o assento do
ACK tem de ser exatamente o pedido. Diferente é violação de contrato e **não
concede entrada** — vira `ackForaDoContrato`, e a navegação não acontece.

A exceção é a **reconexão**, e ela vem anunciada pelo próprio servidor
(`reconexao: true`): ali ele ignora a preferência de propósito e devolve o lugar
que já era do titular. Recusá-la impediria alguém de voltar para a própria
cadeira — que é o oposto do que a autoridade do servidor existe para proteger.

---

## 5. A máquina da intenção

`lib/ingresso/estado_ingresso.dart`. Mora no **transporte**, não na tela, pelo
mesmo motivo do retrato da descoberta: a tela pode ser descartada antes da
resposta, e estado que morre com a tela não tem como descartar o que chega
depois.

| situação | o que acontece |
|---|---|
| toque duplo | o segundo pedido não é autorizado; um pedido no fio |
| resposta duplicada | confirma uma vez; `consumirConfirmacao` entrega uma vez |
| resposta fora de ordem | recusa depois do ACK não desfaz |
| ACK de outra mesa | descartado; o pedido continua em voo |
| queda do socket | a intenção morre — a resposta não vem mais por ali |
| troca de conta | intenção **e** confirmação não consumida são apagadas |
| saída da tela | `dispose` cancela a intenção; ACK tardio não navega |

O que o cancelamento **não** faz é desfazer uma entrada que o servidor já
concedeu. Se o ACK estava a caminho, a pessoa está sentada de verdade; mandar
`sair` seria a compensação *"entrei errado, saio e tento de novo"* que a §19
proíbe — e nem resolveria, porque o servidor continuaria sendo a autoridade.

---

## 6. Arquivos

### Novos

```
contrato/ingresso-assento-v1.json
app/lib/ingresso/contrato_ingresso.dart
app/lib/ingresso/modelo_ingresso.dart
app/lib/ingresso/estado_ingresso.dart
app/lib/screens/escolha_assento_screen.dart
app/lib/casca/escolha_assento_de_producao.dart
app/test/ingresso/cena_de_ingresso.dart
app/test/ingresso/contrato_e_estado_test.dart
app/test/ingresso/escolha_assento_test.dart
app/test/ingresso/transporte_ingresso_test.dart
app/test/ingresso/navegacao_ingresso_test.dart
app/tools/mutacoes_ingresso.js
```

### Alterados

```
app/lib/services/online_service.dart          solicitarIngresso + a máquina
app/lib/casca/lobby_publico_de_producao.dart  onEscolherMesa abre o SELETOR
app/lib/screens/lobby_publico_screen.dart     card tocável só se ingressável
app/lib/casca/lobby_online.dart               recebe o ingresso confirmado
app/lib/casca/onde_jogar_de_producao.dart     a descrição andou junto
app/tools/mutacoes_descoberta.js              âncoras M07 e M20
scripts/ci/gates_os_integracao.txt            bloco 14 — quatro gates
.github/workflows/ci-os-integracao.yml        quatro passos `roda`
```

---

## 7. O contrato do cliente NÃO tem gêmeo, e isso é dito em voz alta

`contrato/descoberta-mesas-v1.json` existe **idêntico** nos dois repositórios, e
é isso que faz editar um lado reprovar no outro.

`contrato/ingresso-assento-v1.json` **não tem gêmeo**. A OS 38.3 é do cliente e
proíbe tocar no servidor — não há como publicar a cópia lá sem violar isso.

O que substitui a amarra, e é mais fraco:

* a **proveniência** — o SHA do servidor está dentro do JSON e numa constante
  Dart, e `CT-04` cobra que os dois apontem para o SHA que a OS exige;
* o **digest** — `CT-02` impede a cópia do cliente de derivar sozinha.

**Residual registrado:** publicar o gêmeo em `buraco-servidor` é trabalho de
outra OS.

---

## 8. Acessibilidade

Superfícies novas ou alteradas: o seletor de assento e o card do Lobby.

* nome acessível em todo controle; papel `button` só onde há gesto;
* `enabled` falso na cadeira ocupada, na mesa não ingressável e durante o
  pedido em voo; `selected` na cadeira pedida;
* alvos de 48 × 48 dp — cabeçalho e as quatro cadeiras;
* **uma** região viva, e uma só: a linha de estado. Ela anuncia pedido em voo,
  recusa e ingresso confirmado, e só existe quando há algo transitório a dizer.
  Região viva permanente faria o leitor de tela repetir a tela a cada
  atualização automática da lista, que é a cada poucos segundos, para sempre;
* zero nó semântico duplicado por cadeira;
* zero estouro em 320/360/412 dp por 100/130/150/175/200 % de fonte, com a
  última cadeira e a ação secundária alcançáveis por rolagem.

---

## 9. Privacidade

* zero UID, `jogadorId`, `admissaoId`, `tentativaEntradaId`, token ou
  credencial em qualquer mensagem que sai — o pedido tem exatamente
  `{tipo, codigo, apelido, assento?}`;
* zero identidade interna na interface, e **o código da mesa também não é
  exibido**: ele é opaco e serve para pedir, não para mostrar;
* a lista continua sem mesa privada e sem mesa VIP/Ranqueada — a projeção do
  servidor não as publica, e o adaptador recusa o retrato inteiro se alguma
  chave proibida aparecer;
* espectador não pede assento: `assistirMesa` é outro caminho, e esta folha não
  o toca;
* texto livre não reaparece na Pública — nada de chat entrou aqui.

---

## 10. Fora de escopo, e registrado

* **`configurar_mesa_screen.dart` continua órfã.** A §12 proíbe promovê-la, e
  ela não foi promovida. Criar mesa continua indo para o destino já aprovado
  (`LobbyOnline`).
* **A conversão dos cinco gates `desc*` para contratos P completos** continua
  pendente, como a OS 38.2 registrou. Esta folha somou quatro gates ao mesmo
  mecanismo vigente; não importou mecanismo da família 23.1-P.
* **Mesa VIP/Ranqueada** continua fora: os dois regimes de admissão do servidor
  são disjuntos, e só o casual é descobrível.

---

## 11. Medição

Tudo abaixo foi executado nesta máquina, na árvore desta folha. Nenhum número
aqui é estimado.

### Portões

**36/36 verdes, 1858 casos, zero falhas.** Os 32 herdados mais os quatro desta
OS:

| gate | suíte | casos |
|---|---|---|
| `ingrcontrato` | `test/ingresso/contrato_e_estado_test.dart` | 37 |
| `ingrassento` | `test/ingresso/escolha_assento_test.dart` | 38 |
| `ingrtransp` | `test/ingresso/transporte_ingresso_test.dart` | 23 |
| `ingrnav` | `test/ingresso/navegacao_ingresso_test.dart` | 15 |

`flutter analyze`: 48 diagnósticos, **zero** nos arquivos desta folha. Os seis
`error` são de `tools/print_mesa.dart` e são anteriores a esta OS.

### Sabotagem

| campanha | resultado |
|---|---|
| `tools/mutacoes_ingresso.js` (nova) | **30/30** |
| `tools/mutacoes_descoberta.js` (herdada) | **26/26** |

### As cinco que escaparam na primeira volta

A campanha do ingresso deu **25/30** na primeira execução. Nenhuma das cinco
era mutante equivalente, e uma delas era furo na própria guarda desta OS.

| mutação | por que escapou | o que passou a existir |
|---|---|---|
| **I27** o passo `roda ingrnav` some do workflow | `RG-02` procurava `roda <gate> test/` em qualquer posição da linha, e casava com `# roda ingrnav …`. Comentar o passo tirava a suíte do CI e o portão continuava verde | âncora no começo da linha, e exatamente uma ocorrência |
| **I23** a cadeira ocupada vira escolhível | `EA-03` não passava `onEscolherAssento`, então **nenhuma** cadeira era botão: o caso não distinguia "a ocupada não é botão" de "nada é botão" | o callback passou a ser obrigatório, e o caso afirma primeiro que a **livre** é botão |
| **I14** `pushReplacement` vira `push` | `findsNothing` não separa as duas: a rota debaixo de uma rota opaca também não aparece nos finders | o **Voltar** decide — sair da mesa devolve à lista, nunca ao seletor |
| **I15** o `dispose` deixa de cancelar a intenção | `NV-10` não quebrava: o host desmontado já não navega de qualquer modo | `NV-15` — sair com pedido em voo e voltar a entrar tem de deixar pedir de novo. Sem isso a pessoa não pede cadeira em mesa nenhuma até o socket cair |
| **I09** as duas guardas de geração somem | no caminho de produção elas são redundantes: a intenção morre a cada troca de conexão, e nenhum caso as alcançava | `EI-18` cobra o contrato na **fronteira da classe**, anotando que o transporte nunca faz aquela chamada |

### O que a medição obrigou a mudar em produção

Um defeito real, achado ao escrever `TR-20a`: a **queda do socket não sobe a
geração do transporte** — a reconexão reaproveita a mesma —, então o crachá de
geração sozinho não matava um pedido de assento em voo. O seletor ficaria em
"pedindo" para sempre, com as quatro cadeiras travadas. Fechado em `_aoCair`, e
cobrado pela mutação `I12b`.
