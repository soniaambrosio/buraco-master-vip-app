# Configuração visual das apostas 1500 / 2000 / 3000 — V1

**Veredito: `BLOCKED — APOSTA NÃO É CONFIGURÁVEL POR MESA NO CONTRATO ATUAL`**

Nenhuma linha de código foi alterada. Este documento é a medição que sustenta a
parada, e ele existe para que a próxima pessoa não refaça a varredura.

Base: `089cb5e` (`integracao/avatar-ranking-estatisticas-navegacao-publica-v1`),
o topo produtivo mais recente do aplicativo. Servidor conferido em `3016f64`
(`homologacao/alvo-operacional-credencial-v1`, o alvo operacional canonizado) e
em `274c50d` (`integracao/mesa-privada-vip-individual-v1`, a linhagem de mesa
mais recente). Os dois concordam campo por campo no que interessa aqui.

---

## 1. Gate Zero: a configuração de mesa produtiva mais recente **não existe**

A OS manda resolver a configuração de mesa produtiva e não tocar em
maquete/prévia que não seja rota real. A varredura devolveu que **não há
nenhuma**: a tela de configuração existe no repositório e **nenhuma rota chega
nela**.

O caminho produtivo inteiro, de `main()` até a mesa, é este:

| Passo | Arquivo |
| --- | --- |
| entrada do processo | `app/lib/main.dart` (58 linhas — só binding e Firebase) |
| raiz / sessão / transporte | `app/lib/casca/raiz_do_aplicativo.dart` |
| Login ou Home | `app/lib/casca/casca_de_producao.dart` |
| Home | `app/lib/casca/home_de_producao.dart:250` |
| Onde Jogar | `app/lib/casca/onde_jogar_de_producao.dart:87` e `:90` |
| Treino (local) | `MesaScreen` |
| **Online por código** | `app/lib/casca/lobby_online.dart` |
| mesa online | `app/lib/casca/mesa_online/mesa_online_screen.dart` |

A tela de criação online é o lobby, e a superfície de criação dele é, inteira:

```dart
// app/lib/casca/lobby_online.dart:345
onPressed: pronto ? () => srv.criarMesa(apelido: _apelidoEscolhido) : null,
```

Um campo de apelido, um botão "Criar mesa", um campo de código. **Não há
seletor de aposta, nem de meta de pontos, nem de modalidade** — não há tela de
configuração de mesa na rota produtiva.

`app/lib/screens/configurar_mesa_screen.dart` (1.189 linhas, com o seletor de
`ENTRADA (aposta em moedas)` e o cartão de pote) continua no repositório e
continua compilando, mas é **órfã**: a única referência a `ConfigurarMesaScreen`
em `app/lib` é o próprio arquivo, e não há um único teste em `app/test` que a
monte. Ela é catálogo visual — exatamente o que o cabeçalho de `main.dart`
descreve quando conta o que saiu da bancada de prévias.

Mexer nela seria mexer em maquete, que é o que o Gate Zero proíbe. **Por isso
ela não foi tocada**, e por isso os `[0, 500, 1000, 5000]` da linha 182
continuam lá.

## 2. O servidor tirou a aposta do cliente de propósito

Mesmo que a tela fosse rota, o valor não teria para onde ir. O contrato atual
**não aceita aposta por mesa**:

```js
// server.js:4555 (3016f64 e 274c50d)
const apostaDeEntrada = Number.isFinite(opts.apostaDeEntrada)
  ? Math.max(0, Math.round(opts.apostaDeEntrada))
  : 0;
```

`apostaDeEntrada` é **opção de construção do gerenciador** — configuração do
processo, com padrão zero. A sala nasce com `aposta: apostaDeEntrada`
(`server.js:4626`), e o despachante de `criarMesa` (`server.js:6619`) repassa
apenas `apelido`, `jogadorId`, `uidAutenticado`, `modalidade` e `metaPontos`.

A suíte do servidor guarda isso com cinco provas em `test/mesa_privada.test.js`:

| Caso | O que prova |
| --- | --- |
| `APO-01` | `msg.aposta` não é mais lido pelo despachante |
| `APO-02` | `criarMesa` não recebe mais aposta como parâmetro |
| `APO-03` | a aposta é configuração do **processo** |
| `APO-04` | configuração inválida vira zero, e não `NaN` |
| `APO-05` | a mesa pública padrão não cobra entrada |

O motivo está escrito no próprio servidor: `sala.aposta` alimenta
`registrarPartida`, que move o cofre de fichas. Enquanto o cliente escolhia o
valor, **o cliente decidia quanto o cofre movimentava**. Reabrir `msg.aposta`
para fazer um botão funcionar desfaz uma correção de economia deliberada — e é
literalmente o que a OS proíbe ("nada de inventar protocolo").

O cliente produtivo já respeita isso: `OnlineService.criarMesa`
(`app/lib/services/online_service.dart:423`) envia `apelido`, `metaPontos` e
`modalidade`, e **nada de aposta**.

## 3. O que destravaria

Só uma decisão de produto, e ela é da Sônia, não da UI:

1. **A aposta volta a ser por mesa** — exige contrato novo no servidor
   (`msg.aposta` validado contra uma tabela canônica, recusa explícita fora
   dela, e a decisão de quem pode abrir mesa cobrando), depois o campo no
   comando, e só então o botão. É OS de backend antes de ser OS de tela.
2. **A aposta continua do processo** — então não existe superfície visual para
   canonizar, e o seletor de aposta deve sumir da tela órfã em vez de ganhar
   valores novos.

Enquanto nenhuma das duas for escolhida, qualquer botão de 1500/2000/3000
seria decoração: o servidor cobraria `apostaDeEntrada` de qualquer jeito.

## 4. Uma pergunta que precisa de resposta antes da próxima tentativa

**1500 / 2000 / 3000 não é a família de valores da aposta nesta base — é a
família da META DE PONTOS.**

O que está registrado na especificação visual aprovada —
`CONFIGURACAO-MESAS-UI-APROVADA.md`, que **não existe nesta árvore**: ela ficou
na linhagem pré-casca, e se lê com
`git show e384863:docs/CONFIGURACAO-MESAS-UI-APROVADA.md`:

- linha 46 — `Pontos: 1.500 / 3.000`
- linha 47 — `Aposta em moedas: Grátis / 500 / 1.000 / 5.000`

Os números da OS batem com a primeira lista (1.500 e 3.000, faltando o 2.000) e
não têm interseção nenhuma com a segunda. E "2000 realmente selecionável" na
lista de testes descreve com precisão um valor **que falta** numa dupla, não uma
família inteira trocada.

Se a intenção for a **meta de pontos**, a situação é outra e vale registrar,
porque muda o veredito de uma OS futura:

- `metaPontos` **já viaja por mesa** — `criarMesa` o envia
  (`online_service.dart:423`, padrão 3000) e o servidor o honra
  (`server.js:4606` → `criarJogo`), então não haveria bloqueio de contrato;
- mas **o servidor não valida o valor recebido**: `metaPontos: msg.metaPontos`
  entra sem lista branca e sem normalização. Um cliente adulterado abre mesa com
  meta 7 ou 999.999. A regra da OS "não confiar em valor adulterado" exigiria
  correção **no servidor**, não na tela;
- e o lobby produtivo não tem seletor nenhum, então não seria "corrigir a
  superfície": seria **criar** a superfície de configuração que hoje não existe
  na rota real — decisão de escopo que a OS não autoriza.

Nenhuma dessas três coisas foi feita, porque nenhuma delas é o que esta OS pede
com as palavras que ela usa (aposta, autoridade econômica, `apostaDeEntrada`).

---

## Anexo — como reproduzir a medição

```bash
grep -rn "ConfigurarMesaScreen" app/lib                    # só o próprio arquivo
grep -rn "criarMesa" app/lib/casca/lobby_online.dart      # só apelido
git -C F:/Projetos/buraco-servidor grep -n "apostaDeEntrada" 3016f64 -- server.js
git -C F:/Projetos/buraco-servidor grep -n "APO-0" 3016f64 -- test
```
