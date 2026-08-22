# Lobby Público e presença agregada no Flutter — V1

**OS 38.2** — segunda etapa da família *Lobby Público / Onde Jogar*.
Folha do aplicativo. Não altera o servidor e não antecipa o ingresso da 38.3.

| | |
| --- | --- |
| **Base do app** | `integracao/loja-functions-producao-canonica-v1` @ `54f2ea631608187e0b528dc556eb8c34f9697975` |
| **Branch** | `integracao/lobby-publico-presenca-flutter-v1` |
| **Autoridade externa** | `buraco-servidor@integracao/descoberta-mesas-publicas-presenca-v1` @ `d1de8a7b2b91dfeb5b409fec61473f10fc21afe4` |
| **Base canônica do servidor** | `26a08fcbcc7013586d7218d9dbd60b11b7a70ab0` (ancestral de `d1de8a7`) |
| **Contrato consumido** | `contrato/descoberta-mesas-v1.json`, digest `a528c9e465a815f4aebb284b30744a17a02badbc0d48bc7d9b0ba368c0c5c63b` |

---

## 1. Os dois P0

### 1.1 A presença nasce na Home

A iniciativa de conectar **saiu da tela do Lobby e foi para `PonteSessaoOnline`**.

O `escopo_transporte.dart` da base já dizia, por escrito, que essa iniciativa
seria "da Casca de Produção, quando existir". Ela existe, e é esta ponte.

O que mudou de fato:

```
Sessão autenticada → PonteSessaoOnline → OnlineService.conectar()
                   → auth no servidor → presença → descoberta inicial
```

Nada disso passa por `build()`, por rota ou por `BuildContext`. A ponte observa
a sessão e fala com o transporte; ela não conhece tela.

**Por que a decisão anterior deixou de valer.** A justificativa antiga era boa
para o que se sabia então: uma raiz que conectasse sozinha abriria socket para
quem só queria treinar contra robôs. O que passou a existir é uma pergunta que
só o servidor responde e que a Home faz antes de qualquer tela de jogo —
*quantas pessoas estão online*. Com a iniciativa na tela do Lobby, essa
afirmação era impossível de fazer com honestidade: quem estivesse com o
aplicativo aberto na Home não seria contado, e o número estaria errado
exatamente sobre quem estivesse olhando para ele. Pior: o total subiria por
causa de **navegação**, não de gente chegando.

O que **não** mudou: sem sessão autenticada não há conexão (logout não religa),
uma troca de conta produz **uma** transição, e o Treino continua sem falar com
o servidor.

### 1.2 `sbtl` → `STBL`

A chave do fio continua `sbtl`. O texto da jogadora é sempre `STBL`.

A tradução mora em **um lugar só**: `ModalidadeDeMesa.rotulo`. Nenhuma tela,
filtro, semântica ou mensagem monta esse texto por conta própria — quem quer
exibir modalidade lê `rotulo`.

A guarda tem duas metades, e a segunda é a que sobrevive ao tempo:

- casos de tela provam o que **eles** desenham;
- uma **varredura de código-fonte** proíbe o literal `'sbtl'` em `lib/casca` e
  `lib/screens`, com exceção nomeada para os três arquivos que falam a língua
  do servidor. É ela que pega o tooltip que alguém escrever amanhã.

> **A varredura achou dois resíduos pré-existentes.**
> `como_jogar_screen.dart` e `mesa_screen.dart` exibiam `SBTL` — letras
> trocadas. Não é opinião: a suíte da base já afirmava `STBL` em oito lugares e
> um caso já exigia que `SBTL` **não** aparecesse, só que num host diferente
> desses dois. Corrigidos.

---

## 2. Arquitetura do consumo

| camada | arquivo | papel |
| --- | --- | --- |
| vocabulário do fio | `lib/descoberta/contrato_descoberta.dart` | tipos de mensagem, ritmos, listas fechadas, chaves proibidas |
| modelo tipado | `lib/descoberta/modelo_descoberta.dart` | retrato, mesa, assento, presença — e a tradução `STBL` |
| fronteira | `lib/descoberta/adaptador_descoberta.dart` | mapa cru → modelo, **fail-closed** |
| ordem | `lib/descoberta/estado_descoberta.dart` | geração, revisão, fase da superfície |
| ritmo | `lib/descoberta/agente_descoberta.dart` | quando pedir, quando pulsar, quando parar |
| transporte | `lib/services/online_service.dart` | as duas mensagens no **mesmo** WebSocket |
| iniciativa | `lib/services/ponte_sessao_online.dart` | o P0 §3.1 |
| Home | `lib/casca/home_de_producao.dart` | lê a presença, não pede nada |
| Lobby | `lib/casca/lobby_publico_de_producao.dart` + `lib/screens/lobby_publico_screen.dart` | host + camada visual |

### A UI não lê o mapa bruto

Ou o retrato inteiro é construído, ou ele **não existe**. Não há retrato
parcial, campo completado por padrão nem mesa descartada individualmente para
"salvar o resto".

Recusar não apaga o que já valia: o último retrato válido continua na tela, e o
que muda é o **aviso**.

Recusas cobertas: esquema desconhecido, campo ausente, campo **a mais**, tipo
incorreto, chave proibida em qualquer profundidade, número negativo, capacidade
≠ 4, vetor de assentos inválido, índice de assento que não bate com a posição,
assento livre carregando dados, modalidade desconhecida, estado de ingresso
desconhecido, aritmética da mesa que não fecha, presença incoerente.

### Nenhum UID atravessa

O servidor já monta a projeção campo a campo. Esta é a segunda tranca, do lado
de cá: se a projeção regredir e mandar `jogadorId`, o retrato **inteiro** é
recusado. Ignorar o campo deixaria o dado viver na memória do aparelho;
recusar faz o defeito aparecer como estado de erro, que alguém investiga.

---

## 3. Geração e revisão

| situação | decisão |
| --- | --- |
| primeiro retrato de uma geração | aceita |
| mesma geração, revisão maior | aceita |
| mesma geração, revisão igual ou menor | **descarta** (chegou atrasado) |
| geração diferente | **substitui integralmente**, mesmo indo para trás |
| transporte anterior | descarta antes de qualquer leitura |
| logout / troca de conta | apaga o retrato — é o **único** caminho que apaga |

Geração diferente não é comparação: é ordem de jogar fora o que se tinha. Um
cliente que só comparasse números descartaria para sempre tudo o que viesse de
um servidor reiniciado, porque `1 <= 4812`.

---

## 4. Ritmo

O ritmo pertence ao transporte, que é **um** pela vida do aplicativo. A tela não
cria timer nenhum.

- **lista**: 5 s (cinco vezes o piso de 1 s do contrato);
- **pulso**: o `intervaloSugeridoMs` que o servidor devolve, com o piso de 5 s
  como chão;
- **primeira consulta imediata** ao autenticar;
- **botão Atualizar** protegido: dez toques mandam um pedido;
- ligado só depois de `autenticado`; parado em queda, falha terminal e logout;
  `descartar()` no `dispose` impede religar por resposta tardia.

> **Um defeito real desta OS.** O limite de frequência usava `DateTime.now()`,
> que **não anda junto com os temporizadores**. O tique periódico disparava e a
> própria checagem o recusava — a presença de quem ficava parado na Home
> simplesmente parava. Em produção os dois relógios concordam e isso ficaria
> invisível até alguém medir. Os tiques automáticos passaram a se reagendar
> sozinhos, sem consultar relógio: o próprio intervalo é o limite, e um pedido
> manual reagenda o automático, o que garante o piso sem depender de relógio.

---

## 5. As duas projeções não se tocam

Uma resposta `mesas` nunca escreve em `visao`, `codigo` ou `meuAssento`. O
`case` termina com `return`, e não com `break`, para que a descoberta não
compartilhe caminho de saída com a projeção da mesa.

---

## 6. Superfícies

### Home

`N jogadores online agora`, exclusivamente de `presenca.jogadoresOnlineTotal`.

- **desconhecido não vira zero**: a linha inteira sai da tela, como já acontece
  com moedas e liga;
- **zero real** é exibido como zero;
- **não é a soma das modalidades** — quem está na Home, no Perfil ou assistindo
  também está online e não aparece em modalidade nenhuma;
- nenhuma identidade é exibida;
- tocar no acesso leva ao Lobby Público.

### Onde Jogar

"Mesa Pública" saiu de `bloqueado: true` e leva ao Lobby Público. A descrição
diz o que ela entrega **hoje**: ver as mesas, quem está sentado e quantas vagas
faltam — e que entrar chega na próxima atualização. Treino e Mesa por código
seguem intactos. `configurar_mesa_screen.dart` não foi promovida.

### Lobby Público

Cada card: nome, Meta, modalidade, humanos/capacidade, vagas, as quatro
posições com apelido sanitizado, estado de ingresso e tempo de espera. A palavra
"Pública" não é repetida — a tela inteira já é disso.

**A ordem é a do servidor**, percorrida como veio. Não há `sort` no arquivo.

**As contagens dos filtros são as do servidor** (`presenca.porModalidade`), e
não `mesas.where(...).length`. Filtrar oculta cards; nenhum número muda.

Estados honestos: carregando, lista disponível, vazia real, sem ingressáveis,
reconectando, servidor indisponível, retrato inválido, sessão encerrada,
atualização em curso. Nenhum dado de demonstração em estado nenhum.

### Ingresso: não nesta OS

`onEscolherMesa` é `null` em produção. O card não é botão e não finge ser.
Quando a 38.3 chegar, é por aqui que ela entra — sem que a tela precise aprender
a falar com o servidor.

---

## 7. Acessibilidade

Alvos ≥ 48 dp, Voltar nomeado, filtros com papel e `selected`, card numa frase
compreensível, assentos nomeados um a um, ordem de foco igual à da tela, zero nó
tocável anônimo, zero duplicação semântica.

Matriz de responsividade: **320 / 360 / 412 dp × 100 / 130 / 150 / 175 / 200 %**
— 15 casos, sem estouro e com tudo alcançável.

> **Dois defeitos de acessibilidade meus, achados pela suíte.**
>
> 1. **`excludeSemantics` levava o toque junto.** Os filtros saíam com
>    `isButton` e o rótulo certo, e **sem ação de toque**: respondiam ao dedo e
>    eram inertes para o TalkBack. Só apareceu porque o teste usa
>    `performAction`, que é o caminho do leitor de tela. A forma certa é o
>    inverso — a semântica envolve o `InkWell` (herdando a ação dele) e quem
>    tem a semântica descartada é só o `Text` de dentro.
> 2. **Os filtros ficavam fora da viewport.** Numa faixa horizontal, "Fechado" e
>    "STBL" não eram alcançáveis já em 390 dp — e um `ListView` nem constrói o
>    que está fora. Viraram `Wrap`: os cinco existem sempre, e o que muda com
>    fonte grande é o número de linhas.

---

## 8. Gates

Cinco gates novos na **fonte única existente**
(`scripts/ci/gates_os_integracao.txt`), sem família paralela:

| gate | suíte | guarda |
| --- | --- | --- |
| `descadapt` | `contrato_e_adaptador_test.dart` | digest do contrato + fronteira fail-closed + registro dos gates |
| `descestado` | `estado_e_agente_test.dart` | geração, revisão, resposta atrasada, ritmo |
| `deschome` | `presenca_na_home_test.dart` | **o P0**: presença nasce na Home |
| `descstbl` | `apresentacao_stbl_test.dart` | **o P0**: `sbtl` → `STBL`, com varredura de código |
| `desclobby` | `lobby_publico_test.dart` | tela, ordem, contagens, estados, A11Y, responsividade |

Três casos guardam a **própria inscrição**: apagar uma linha da fonte única, ou
renomear um arquivo de suíte sem atualizar o workflow, fica vermelho. Sem isso,
"desregistrar a suíte" seria o buraco que a §15 manda fechar.

`descadapt` lê `../contrato/descoberta-mesas-v1.json` — o caminho funciona nos
dois lugares: local o CWD é `app/`, no CI é `app_build/`, e os dois são irmãos
de `contrato/` na raiz.

---

## 9. Medição

Baseline medida em worktree próprio em `54f2ea6`, com o mesmo script.

| | base | depois |
| --- | --- | --- |
| suítes do portão | 27 | **32** |
| casos | 1611 | **1743** |
| suítes não verdes | 0 | **0** |
| `flutter analyze lib/` | 28 achados, 0 erros | **28 achados, idênticos** |

Nenhuma suíte perdeu casos. `casca` foi de 30 para 31 (um caso novo).

### Ferramenta: três defeitos que precisei fechar antes de qualquer número valer

1. **`$?` depois de um pipe** capturava o `tr`, não o `flutter test` — toda
   suíte reportava `exit=0`.
2. **O parser de contagem casava com `LIX-23`** dentro do nome de um caso, e
   reportou "23 falhas" numa suíte 458/458 verde.
3. **A variável se chamava `TMP`.** No Windows essa É a variável de ambiente do
   diretório temporário, e o `flutter` a lê. `TMP=$(mktemp)` a fez apontar para
   um *arquivo* — 27 suítes verdes reportadas como vermelhas, duas vezes.

E `flutter test` sem argumento **trava** nesta base: ele roda os arquivos em
paralelo no mesmo `build/`, e a colisão em `build/unit_test_assets` pendura a
execução sem mensagem útil. A medição honesta é uma suíte por vez, que é como o
CI mede — `app/tools/medir_suites.sh`.

---

## 10. Afirmações datadas invertidas

Três casos da base afirmavam coisas que esta OS torna falsas **por desenho**.
Nenhum foi apagado; todos viraram afirmações **mais fortes**.

| antes | agora |
| --- | --- |
| `inicialização autenticada não abre socket nenhum` (`aberturas == 0`) | `inicialização autenticada abre UM socket, sem ir ao Lobby` — afirma `== 1`, mais que nenhum Lobby foi aberto, mais que a credencial saiu pela sessão |
| `abrir o lobby conecta UMA vez` | `abrir o lobby NÃO abre um segundo socket`, com um caso irmão novo: `sem sessão NÃO há socket` |
| `Treino não abre socket` | `Treino não fala com o servidor` — lê o **fio** e exige que nada além de `descobrirMesas`/`presenca_ping` tenha saído. Contar sockets era proxy; ler o fio é a coisa |

E `a credencial não aparece na interface` usava `mensagens.single`, que quebrou
porque a descoberta passou a falar. Em vez de trocar por `first` (que
afrouxaria), passou a afirmar que **toda** mensagem que não é a credencial está
no vocabulário conhecido, nenhuma carrega o token, e as duas novas têm
`keys == ['tipo']` — sem campos.

**61 casos da Casca precisaram de `aquietar()`** no fim do corpo. É consequência
direta do P0: tela autenticada tem transporte vivo, transporte vivo tem
temporizador vivo, e o `flutter_test` confere temporizadores pendentes **ao fim
do corpo, antes dos `addTearDown`**. Nenhuma asserção foi afrouxada — é o
equivalente a fechar o aplicativo.

---

## 11. O que a OS 38.3 recebe pronto

- `onEscolherMesa` no `LobbyPublicoScreen`, recebendo o **código opaco**;
- o modelo tipado com `estadoIngresso` e `ingressavel` já decididos pelo
  servidor;
- transporte único, autenticado, com presença viva desde a Home;
- geração e revisão para reconciliar sem inventar estado.

**Não recebe** — e não deve inventar: assinatura/push, paginação, filtro por
modalidade no servidor, escolha local de assento e qualquer contagem calculada
no cliente.
