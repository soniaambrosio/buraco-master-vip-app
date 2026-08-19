# Homologação independente — Casca real de produção, autenticação e roteamento V2

**Veredito: PARTIAL — CASCA V2 FUNCIONAL COM RISCO RESIDUAL DOCUMENTADO**

A casca faz o que se propôs a fazer: o aplicativo abre pela casca real, há uma
única autoridade de sessão, o transporte só sobe com credencial da sessão, e a
navegação privada morre junto com a geração da sessão. Foram encontrados um
defeito (corrigido, com regressão) e um risco residual que não é corrigível
dentro do escopo desta OS — uma tela alcançável que desenha liga, nível e
posição mundial sem que exista autoridade para nenhum dos três.

---

## 1. Base e SHA confirmados

| Item | Valor |
| --- | --- |
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Branch de origem | `origin/claude/casca-producao-auth-roteamento-v2-76c136` |
| SHA exigido pela OS | `3752ad8` |
| SHA remoto conferido | `3752ad8c495d5aa4ff699a0e2bbab557d5e7b048` |
| Branch efetiva | `homologacao/casca-producao-auth-roteamento-v2` |
| HEAD inicial do worktree | `fb9edb5` (descartado — a branch nasceu do SHA, não daqui) |
| HEAD ao criar a branch | `3752ad8c495d5aa4ff699a0e2bbab557d5e7b048` |

Conferência executada:

```
git ls-remote origin refs/heads/claude/casca-producao-auth-roteamento-v2-76c136
3752ad8c495d5aa4ff699a0e2bbab557d5e7b048
```

A branch foi criada **diretamente do SHA completo**, sem passar por `main`, por
`consolidacao/apk-geral-bmv` nem por RC local. Não houve merge, rebase ou
cherry-pick. O nome pedido pela OS estava livre — não foi preciso sufixo.

---

## 2. Gate zero

| # | Exigência | Resultado | Evidência |
| --- | --- | --- | --- |
| 1 | `main.dart` só com inicialização mínima | **OK** | 59 linhas: binding, `Firebase.initializeApp` blindado, `runApp`. Nenhuma tela, nenhum host de prévia |
| 2 | `RaizDoAplicativo` monta as dependências acima do `MaterialApp` | **OK** | Os três escopos envolvem o `MaterialApp`; rotas empurradas herdam deles |
| 3 | `CascaDeProducao` decide a superfície pela sessão | **OK** | Decisão declarativa: `resolvida` → `autenticado` → Login ou Home. Não empurra rota para trocar de superfície |
| 4 | Uma única `SessaoDoJogador` canônica | **OK** | `authStateChanges` assinado em um só arquivo do cliente (`sessao/sessao_firebase.dart`), com teste estrutural que reprova o segundo |
| 5 | A geração participa da invalidação da navegação | **OK** | `key: ValueKey<int>(_sessao.geracao)` no `MaterialApp` |
| 6 | `PonteSessaoOnline` e `OnlineService` usam a credencial da sessão | **OK** | `obterIdToken` é obrigatório no construtor; a única montagem é `criarOnlineServiceDaSessao(sessao)` |
| 7 | Endpoint injetado, não duplicado | **OK** | `EndpointServidor.resolver()` a partir da configuração de build; não há URL de produção no código |
| 8 | Ranking, Recompensas, Amigos e Loja bloqueados | **OK** | `disponivel: false` nos quatro itens; o toque avisa e não navega |
| 9 | Sem nome, e-mail, moedas, liga ou identidade fixos no caminho de produção | **PARCIAL** | Nenhum dado pessoal e nenhum `.mock()` alcançável. Mas o Perfil desenha liga e posição sem fonte — ver §9 |

**Gate zero: aprovado.** Nenhuma peça essencial ausente, SHA conferido. A
arquitetura não foi reconstruída em ponto nenhum.

---

## 3. Grafo de inicialização

```
main()
 ├─ WidgetsFlutterBinding.ensureInitialized()
 ├─ Firebase.initializeApp(...)          ← falha engolida de propósito
 └─ runApp(RaizDoAplicativo)
     │
     ├─ initState (uma vez por processo)
     │   ├─ SessaoDoJogador  ← criarSessaoDoJogador(): authStateChanges + currentUser
     │   ├─ ComandosDeAutenticacao ← AutenticacaoFirebase()
     │   ├─ OnlineService    ← criarOnlineServiceDaSessao(sessao)   [DESCONECTADO]
     │   └─ PonteSessaoOnline(sessao, online)
     │
     └─ build
         EscopoSessao ─ EscopoAutenticacao ─ EscopoTransporte
             │                                    (os três SOBREVIVEM à troca de sessão)
             └─ ListenableBuilder(sessao)
                 └─ MaterialApp  key: ValueKey(sessao.geracao)   ← A PILHA MORRE AQUI
                     └─ CascaDeProducao
                         ├─ sessão ausente ......... _AvisoTerminal
                         ├─ !resolvida & espera OK .. SplashOficialScreen
                         ├─ !resolvida & estourou ... _EsperaEstourada  (+ botão)
                         ├─ resolvida & abertura ..... SplashOficialScreen
                         ├─ !autenticado ............ LoginDeProducao
                         └─ autenticado ............. HomeDeProducao
```

O ponto que faz a arquitetura funcionar: os escopos estão **acima** da chave e o
`MaterialApp` **abaixo** dela. A sessão sobrevive à troca; a navegação não.

---

## 4. Tabela de autoridade

| Responsabilidade | Dono único | Quem NÃO pode ter |
| --- | --- | --- |
| Quem está logado (estado) | `SessaoDoJogador` | Qualquer tela; o transporte |
| Fluxo de autenticação (`authStateChanges`) | `sessao/sessao_firebase.dart` | Todo o resto do cliente |
| Entrar / sair (comando) | `ComandosDeAutenticacao` | Telas chamando `signOut()` direto |
| Credencial apresentada ao servidor | `SessaoDoJogador.obterCredencial` | `OnlineService` (não importa `firebase_auth`) |
| Geração da sessão | `SessaoDoJogador` | — |
| Tradução sessão → transporte | `PonteSessaoOnline` | A sessão; a tela do lobby |
| Endereço do servidor | `EndpointServidor` (build) | Constante no código |
| Decisão de tela | `CascaDeProducao` | Login e Ajustes (nenhum navega) |
| Identidade pública | `SessaoDoJogador.estado` | `PerfilService`, Ranking, Social (só leem) |

**Verificação independente.** Varredura no fecho transitivo de `lib/main.dart`:
um só assinante de `authStateChanges`; `firebase_auth`/`google_sign_in`
importados só em `sessao/`; um só ponto que constrói `OnlineService`
(`raiz_do_aplicativo.dart`); nenhum `currentUser`, `signInWithCredential` ou
`signOut(` fora de `sessao/`; nenhum `print`/`debugPrint`/`log` em `sessao/`,
`casca/` ou no transporte.

---

## 5. Matriz de estados da sessão (§4.1)

| Estado | Superfície | Resultado |
| --- | --- | --- |
| Primeira abertura, sem sessão | Splash → Login | **OK** |
| Firebase inicializado | — | **OK** |
| Sessão carregando (fluxo calado) | Splash, e só Splash | **OK** — 30 quadros conferidos, nem Home nem Login aparecem |
| Sessão válida restaurada (`uidInicial`) | Splash → Home | **OK** — `resolvida` já nasce verdadeira |
| Sessão expirada / logout externo | Login | **OK** |
| Credencial ausente | Login, ou lobby em `naoAutenticado` | **OK** — falha terminal, sem laço |
| Protocolo incompatível | `atualizacaoObrigatoria` | **OK** — terminal; 2 min de relógio sem nenhuma tentativa nova |
| Falha recuperável de inicialização | Splash → estado explícito com botão | **OK** |
| Falha terminal sem reconexão infinita | `semConexao` após 6 tentativas | **OK** |
| Sem provedor de autenticação no build | "Este aplicativo está mal configurado", sem botão | **OK** |
| Sem sessão acima na árvore | `_AvisoTerminal` | **OK** — não desenha Home sem dono |

**Nenhuma tela privada pisca antes de a sessão se pronunciar.** A espera é por
`sessao.resolvida`, não por `estado.autenticado` — que é a distinção que impede o
Login de piscar para quem já estava logado, e a Home de piscar para quem não
está. A Splash cobre o intervalo inteiro, inclusive depois de a animação acabar.

---

## 6. Matriz de autenticação (§4.2)

| Caso | Resultado | Observação |
| --- | --- | --- |
| Login concluído | **OK** | A tela não navega: a casca redesenha porque a sessão mudou |
| Cancelamento voluntário | **OK** | `DesfechoDeLogin.cancelado` — sem mensagem vermelha, sem crash |
| Falha do provedor | **OK** | Mensagem já redigida na origem; a tela não constrói texto próprio |
| Autenticado sem credencial online pronta | **OK** | `obterCredencial` devolve `null`; o transporte não abre socket |
| Renovação de credencial | **OK** | `authExpirou` → token novo no mesmo socket, sem reentrar na mesa |
| Reemissão do mesmo uid | **OK** | Não é troca de sessão: não sobe geração, não derruba conexão |
| Logout | **OK** | Um caminho só (Ajustes → comando canônico), sem `popUntil` |
| Logout durante conexão | **OK** | Socket em `autenticando` é fechado; nenhuma abertura nova |
| Logout durante reconexão pendente | **OK** | O timer agendado é cancelado; 3 s de relógio sem socket novo |
| Troca de usuário na mesma instalação | **OK** | Uma transição de transporte; nada de A sobrevive |

Casos difíceis conferidos em separado, porque são os que costumam vazar entre
contas: resposta de identidade que chega **depois** do logout é descartada pela
geração; token que volta **depois** do logout vira `null`; renovação que termina
num socket que já não é o nosso morre calada.

---

## 7. Matriz de navegação e logout (§4.3)

| Passo | Resultado |
| --- | --- |
| Rota privada empilhada (Ajustes) + logout → pilha descartada | **OK** |
| Botão VOLTAR não recupera a tela privada | **OK** — `canPop()` é falso, e o `handlePopRoute` do aparelho não muda nada |
| Autenticar outro usuário → nenhuma rota anterior reaparece | **OK** |
| Nenhum dado do usuário anterior reaparece | **OK** — apelido, publicId, código de mesa, assento e visão somem |
| Invalidação depende da GERAÇÃO, não da troca de `home` | **OK** — provado com A→B, em que a tela de baixo é Home nos dois lados |

O terceiro caso é o que separa esta arquitetura da anterior. Na troca A→B sem
logout, a tela de baixo não muda: era Home, continua Home. Uma casca que
invalidasse pela troca de superfície não faria nada ali, e a rota de Ajustes de A
continuaria empilhada sobre a Home de B. Como a chave é a geração, a árvore
inteira é substituída.

---

## 8. Matriz de transporte e reconexão (§4.4)

| Exigência | Resultado |
| --- | --- |
| Nenhuma conexão antes de haver credencial válida | **OK** — inicialização autenticada abre zero sockets |
| Conexão no momento certo do ciclo de vida | **OK** — só quando o jogador escolhe "Mesa por código" |
| Sem notificação de ancestral durante `build` | **OK** — `takeException()` nulo ao montar o lobby |
| `addPostFrameCallback` não duplica conexão | **OK** — sair e voltar ao lobby mantém 1 socket |
| Reconexão não sobrevive ao logout | **OK** |
| Erro terminal não repete infinitamente | **OK** — cinco estados terminais, todos sem backoff |
| Descarte da raiz encerra listeners | **OK** — troca de sessão depois do descarte não mexe no transporte |
| Credenciais não aparecem em log | **OK** — o token sai uma vez, dentro do `auth`, e não está em texto nenhum da tela nem na URL |

O item do `build` merece nota: `conectar()` muda o status e notifica, e quem
ouve é o `EscopoTransporte`, que fica **acima** da tela do lobby. Chamado de
dentro do `didChangeDependencies`, isso é marcar ancestral como sujo durante a
construção de um descendente — erro de framework. O pedido sai num
`addPostFrameCallback`, com trava para não virar um `conectar()` por notificação.

---

## 9. Inventário `REAL / EM BREVE / ÓRFÃO / MORTO`

Alcançabilidade medida pelo fecho transitivo dos imports a partir de
`lib/main.dart`, ignorando comentários: **34 arquivos alcançáveis de 111 em
`lib/`**.

### REAL — destinos que fazem o que dizem

| Destino | Arquivo | Nota |
| --- | --- | --- |
| Splash | `screens/splash_oficial_screen.dart` | — |
| Login | `casca/login_de_producao.dart` | Só desenha provedor que o build sabe acionar |
| Home | `casca/home_de_producao.dart` | Cabeçalho da identidade da sessão; sem saldo, sem liga |
| Perfil | `pages/perfil_page.dart` | Identidade real; **números sem fonte** — ver risco residual |
| Onde jogar | `casca/onde_jogar_de_producao.dart` | Catálogo honesto, 2 de 4 abertas |
| Treino | `mesa.dart` (`MesaScreen`) | Partida local completa contra robôs |
| Mesa por código | `casca/lobby_online.dart` | Online autenticado de verdade |
| Como jogar | `screens/como_jogar_screen.dart` | — |
| Ajustes | `casca/configuracoes_de_producao.dart` | Preferências reais em disco; único botão de sair |
| Resultado de partida | `screens/resultado_partida_screen.dart` | — |

### BLOQUEADO — EM BREVE

| Item | Onde | Comportamento |
| --- | --- | --- |
| Ranking | Grade da Home + barra inferior | `disponivel: false`, aviso, não navega |
| Recompensas | Grade da Home | idem |
| Amigos | Grade da Home | idem |
| Loja VIP | Grade da Home + barra inferior | idem |
| Mesa Pública | Onde jogar | `bloqueado: true`, aviso |
| Mesa VIP | Onde jogar | `bloqueado: true`, aviso |
| Histórico, Temporadas, Saguão | Callbacks da Home | Avisam; `temporada` e `lobby` são nulos, então nem chegam a ser acionados |
| Editar perfil, VIP, moedas, bloqueados, suporte, termos, avaliar | Ajustes | Avisam |

Conferido tocando nos quatro itens da grade: em todos, a Home continua na tela e
o aviso aparece. **Nenhuma prévia foi reativada.**

### ÓRFÃO — existe, compila, não é alcançável

77 arquivos. Os grupos:

| Grupo | Arquivos | Natureza |
| --- | --- | --- |
| Telas de prévia | `ranking_screen`, `recompensas_screen`, `amigos_screen`, `loja_screen`, `loja_categoria_screen`, `saguao_screen`, `hall_screen`, `configurar_mesa_screen`, `preparando_partida_screen`, `mesa_vip_preview_screen`, `mesa_screen`, `torneios_screens`, `torneio_modelo_screen`, `torneios_models`, `torneios_preview_page` | Catálogo visual e material de teste. **Devem continuar órfãs** |
| Domínio de torneios | `lib/torneios/*` (20) | Motor pronto; sem superfície no cliente |
| Domínio social | `lib/social/*` (6) | Backend — roda como bundle das Functions |
| Moderação | `lib/moderacao/*` (5) | idem |
| Coleções | `lib/colecoes/*` (8) | idem |
| Rastreabilidade | `lib/rastreabilidade/*` (8) | idem |
| Integração | `lib/integracao/*` (3) | idem |
| **Motor canônico** | `lib/motor/*` (10) | **Ver nota abaixo** |
| Widget | `widgets/convite_vip.dart` | — |

**Nota sobre `lib/motor/`.** O motor canônico não é alcançável a partir de
`main.dart`: a mesa jogável (`mesa.dart`) não o importa. Isso não é defeito da
casca e está fora do escopo desta OS (§6 proíbe alterar regras do motor), mas é
um fato que a homologação registra: o que o aplicativo publicável executa numa
partida de treino não é o código que as 131 provas de `teste_motor.dart` e as
195 de `teste_motor_resiliencia.dart` exercitam.

### CÓDIGO MORTO

| Arquivo | Diagnóstico |
| --- | --- |
| `lib/app/lib/screens/amigos_screen.dart` | Cópia duplicada de `lib/screens/amigos_screen.dart` numa árvore `lib/app/lib/` aninhada por acidente |
| `lib/app/lib/widgets/convite_vip.dart` | Cópia duplicada de `lib/widgets/convite_vip.dart` |

Sem relação com a casca. Não removidos — remover é mudança sem defeito
comprovado, que §9 proíbe.

---

## 10. Evidências contra vazamento de mocks

Varredura independente sobre os arquivos alcançáveis, com comentários
descartados (um módulo que documenta o que é proibido acusaria a própria prosa):

| Alvo | Resultado |
| --- | --- |
| `"Sônia Rainha"` | **Ausente** — só citações em comentário histórico |
| E-mail pessoal / qualquer domínio real | **Ausente** |
| Saldo fixo de 1.000 moedas | **Ausente do caminho de produção** — só dentro do `InicioVM.mock()`, que ninguém alcançável chama |
| Liga Diamante fixa | **Ausente** |
| Chamada a `VM.mock()` | **Ausente** — a definição continua permitida, a chamada não |
| Telas de prévia nomeadas | **Ausentes** do fecho de `main.dart` |
| `PerfilService.statsDemo` | `false`, com teste que reprova a volta |
| E-mail exibido na Home e nos Ajustes | Campo preenchido vazio de propósito |

A Home é o exemplo do critério: `moedas: null`, `liga: null`, `temporada: null`,
`lobby: null`. Dado sem fonte **não é desenhado** — não vira zero, não vira
travessão, não vira "carregando" para sempre. O elemento sai da tela.

---

## 11. Testes e contagens

### `flutter analyze`

```
38 issues found.  (0 erros)
```

Todos são `warning` de declaração não usada e `info` de `withOpacity`
descontinuado, e **todos moram em telas de prévia órfãs** (`mesa.dart`,
`screens/*`). Nenhum em `casca/`, `sessao/` ou `services/`. Resultado idêntico ao
da base — a correção desta homologação não acrescentou nem removeu nenhum.

### `flutter test`

```
716 testes — All tests passed!
```

(704 na base + 12 acrescentados por esta homologação.)

| Suíte | Casos |
| --- | --- |
| Sessão (`test/sessao/`, 4 arquivos) | 83 |
| — união sessão/transporte | 32 |
| Conexão de produção (`test/conexao_producao_test.dart`) | 43 |
| Autenticação online (`test/online_auth_test.dart`) | 31 |
| Casca de produção (`test/casca/`) | **52** |
| — comportamento da entrega | 25 |
| — auditoria de ausência | 15 |
| — **matriz desta homologação** | **12** |

### Suítes fora do glob do `flutter test`

Sete arquivos usam o prefixo `teste_` e por isso **não entram** em `flutter test`
sem alvo. Foram executados um a um:

| Suíte | Casos |
| --- | --- |
| Motor (`test/teste_motor.dart`) | 131 |
| Resiliência (`test/teste_motor_resiliencia.dart`) | 195 |
| Encerramento legal (`test/teste_encerramento.dart`) | 9 |
| Integração de motores | 63 |
| Moderação | 41 |
| Visão do espectador | 14 |
| Social | 89 |
| **Subtotal** | **542** |

**Total geral: 1.258 casos, todos verdes.**

### Nota de ambiente: as 4 falhas que não são falhas

`flutter test` sem preparo reprova 4 arquivos **na carga**, não na execução:

```
test/colecoes/evidencias_visuais_test.dart
test/colecoes/kit_pioneiros_test.dart
test/torneios/motor_torneios_test.dart
test/torneios/reward_grants_test.dart
```

Os quatro leem seeds em `test/<dominio>/data/`, e os seeds moram em
`app/data/<dominio>/`. Quem faz a ponte é o CI, copiando os arquivos no passo de
overlay. Reproduzido o mesmo overlay localmente, os quatro carregam e a suíte
fecha em 716 verdes. **Nada a ver com a casca**, e as cópias não foram
commitadas.

---

## 12. Defeitos encontrados

### D1 — o recado de estado terminal do lobby estoura a linha (CORRIGIDO)

**Onde.** `app/lib/casca/lobby_online.dart`, o indicador de status.

**O que é.** O texto do status ficava solto dentro de um `Row`, sem restrição de
largura, ao lado de um ponto colorido de 10 px. A frase mais longa da lista —
`'servidor em atualização — tente mais tarde'`, 41 caracteres em negrito de 13 —
disputa 302 pontos de largura: 430 de máximo (ou a largura do aparelho, se for
menor), menos 20 de padding de cada lado, menos os 18 do ponto e do respiro.

**Por que importa.** Cabe raspando na largura e na fonte de referência, e deixa
de caber em duas situações reais: aparelho mais estreito, e ajuste de fonte
grande do sistema — que é exatamente quem mais precisa ler um recado de erro. O
que se vê então é a faixa de estouro e o recado cortado. Atinge cinco estados
alcançáveis, todos terminais: `naoAutenticado`, `atualizacaoObrigatoria`,
`servidorDesatualizado`, `configuracaoInvalida` e `semConexao` — ou seja,
justamente aqueles em que a frase é a única coisa que explica à pessoa o que
houve.

**Como apareceu.** A suíte da entrega nunca alcançou um estado terminal do
lobby; os estados que ela exercita (`conectado`, `autenticando`) têm frases
curtas. O caso de protocolo incompatível desta homologação foi o primeiro a
chegar lá.

**Correção.** O `Text` passou a ser `Flexible` — quando não cabe, quebra em duas
linhas em vez de estourar. Uma linha de mudança estrutural; nenhum ajuste
cosmético, nenhuma mudança de cor, texto ou disposição.

**Regressão.** `test/casca/homologacao_casca_v2_test.dart`, caso
_"o recado de estado terminal cabe na linha — REGRESSÃO"_: leva o lobby ao
estado de frase mais longa e exige que nenhuma exceção de layout apareça.

---

## 13. Correções realizadas

| Commit | Responsabilidade | Arquivos |
| --- | --- | --- |
| `casca: o recado de estado terminal cabe na linha` | Correção do D1 | `app/lib/casca/lobby_online.dart` |
| `testes: a matriz de homologação da casca v2` | Os 12 casos da matriz, incluindo a regressão do D1 | `app/test/casca/homologacao_casca_v2_test.dart` |
| `docs: laudo da homologação da casca de produção v2` | Este documento | `docs/HOMOLOGACAO-CASCA-PRODUCAO-V2.md` |

Nenhuma regra de motor foi tocada. Nenhuma tela foi redesenhada. Nenhuma prévia
foi ativada. Nenhum arquivo órfão foi removido.

### Os 12 casos acrescentados

| # | Caso | Cobre |
| --- | --- | --- |
| 1 | O botão voltar não recupera a rota privada depois do logout | §4.3 |
| 2 | A troca de conta não herda a navegação da conta anterior | §4.3 |
| 3 | É a geração que derruba a pilha, e não a troca de tela | §4.3 |
| 4 | A Home não pisca em quadro nenhum antes da sessão responder | §4.1 |
| 5 | Abrir o lobby não notifica ancestral durante o build | §4.4 |
| 6 | Sair e voltar ao lobby não abre um segundo socket | §4.4 |
| 7 | O logout cancela uma reconexão já agendada | §4.2, §4.4 |
| 8 | O logout no meio da autenticação fecha o socket em aberto | §4.2 |
| 9 | Protocolo incompatível é terminal — não vira laço | §4.1 |
| 10 | O recado de estado terminal cabe na linha — REGRESSÃO | D1 |
| 11 | Descartar a raiz solta o ouvinte da ponte | §4.4 |
| 12 | Os quatro bloqueados avisam, e nenhum deles navega | §4.5 |

---

## 14. Riscos residuais

### R1 — o Perfil afirma liga, nível e posição mundial sem autoridade

**Gravidade: média.** É o único achado que contraria diretamente um objetivo
declarado da OS ("não expõe dados mockados"), e é o motivo do veredito PARTIAL.

`PerfilService.statsDemo` está desligado, e isso resolveu o pior: ninguém mais
abre o próprio perfil e vê nível 24, "Rainha da Canastra", Liga Diamante e 342
vitórias. Mas o estado que ficou no lugar não é ausência — é outro conjunto de
afirmações sem fonte. Com `demo: false`, o Perfil alcançável desenha:

- `liga: 'Bronze'` — renderizado literalmente na tela;
- `posicaoMundial: 0` — renderizado como `· #0 no mundo`;
- `nivel: 1`, `xpProximo: 1000`, `titulo: 'Novato(a)'`;
- `stats` zerados e oito conquistas travadas.

Nenhuma autoridade de ranking é alcançável pelo cliente. É por isso que a
`HomeDeProducao` recusa desenhar `liga` e passa `null` — e o Perfil fica a **um
toque** dessa mesma Home, dizendo "Bronze · #0 no mundo". As duas telas aplicam
critérios opostos ao mesmo dado inexistente.

Há ainda um efeito para fora do aplicativo: `PerfilPage._compartilhar` copia para
a área de transferência `"Nível 1 · Liga Bronze"` — a afirmação sai do aparelho.

Os `stats` zerados são defensáveis: sem persistência, um jogador realmente não
tem partida registrada. `Bronze` e `#0` não são: são um nome de liga e uma
colocação, não a ausência deles.

**Por que não foi corrigido.** Corrigir significa mudar o que a tela do Perfil
mostra, e §6 é explícita: "não redesenhar telas", "não ampliar escopo". A
correção certa — `liga` e `posicaoMundial` nulos, com a tela omitindo a linha
como a Home já faz — é uma alteração de contrato visual do `PerfilVM`, e cabe a
uma OS que possa decidir o que aparece no lugar.

**Recomendação.** Antes de publicar, aplicar ao Perfil a mesma regra da Home:
dado sem fonte não é desenhado. E tirar a liga do texto de compartilhamento.

### R2 — o motor canônico não está no caminho de produção

`lib/motor/*` não é alcançável a partir de `main.dart`. As 326 provas de motor e
resiliência exercitam um código que a partida de treino do aplicativo publicável
não executa. Fora do escopo desta OS; registrado para quem for decidir a
promoção.

### R3 — "Tentar de novo" da espera estourada não muda a causa

Na tela de espera estourada, o botão apenas rearma o mesmo relógio de 8 s. Se o
fluxo de autenticação nunca se pronunciar, a pessoa vê splash → erro → splash →
erro. Não é laço automático (cada volta exige um toque) e não inventa sessão, mas
também não age sobre a causa. Aceitável: o Firebase pode se pronunciar atrasado,
e é isso que o botão dá chance de acontecer.

### R4 — sete suítes ficam fora do `flutter test` e do CI padrão

Os arquivos com prefixo `teste_` (542 casos, entre eles motor, resiliência e
encerramento) não entram no glob. O CI os invoca por alvo explícito; quem rodar
`flutter test` local mede menos da metade do que existe. Pré-existente, sem
relação com a casca.

### R5 — quatro suítes dependem de um overlay de seeds que só o CI faz

Descrito em §11. Pré-existente.

---

## 15. Veredito

```
PARTIAL — CASCA V2 FUNCIONAL COM RISCO RESIDUAL DOCUMENTADO
```

A casca de produção está homologada no que a OS chamou de essencial: o
aplicativo inicia pela casca real, tem uma autoridade de sessão e só uma,
autentica e encerra corretamente, conecta o transporte apenas com credencial da
sessão, elimina a navegação privada na troca de geração — inclusive na troca de
conta sem logout, que é o caso que o roteamento imperativo nunca cobre —, trata
os estados terminais sem laço e não apresenta prévia como recurso disponível. As
suítes canônicas de motor e sessão foram preservadas.

O que impede o PASS é R1: uma tela alcançável do fluxo de produção afirma liga,
nível e posição mundial que nenhuma autoridade emitiu, contradizendo a regra que
a própria casca aplica na Home. Não é bloqueador — nada quebra, nenhum dado
pessoal vaza, nenhuma maquete foi reativada — mas é exatamente o tipo de
afirmação sem fonte que esta OS existe para eliminar, e corrigi-la exige mexer no
contrato visual do Perfil, o que esta OS proíbe.
