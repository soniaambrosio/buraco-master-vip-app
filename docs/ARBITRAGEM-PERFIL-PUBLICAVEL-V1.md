# Arbitragem e composição canônica do Perfil publicável — V1

**Branch efetiva:** `integracao/perfil-publicavel-canonico-v1`
**Base:** `origin/claude/perfil-ranking-estado-canonico-v1-cac971` @ `bc74e30a148a56b00ca7db691a378584efaa5207`
**Candidata (só auditoria):** `origin/claude/casca-producao-auth-roteamento-v2-9c41ae` @ `b246c0723f3e252eadcf313886788c93ffde3534`
**Ancestral comum:** `3752ad8c495d5aa4ff699a0e2bbab557d5e7b048` (Casca de produção) — é também o `merge-base` exato das duas folhas.

---

## 1. O que cada folha tinha feito

As duas descendem da mesma Casca e atacaram o **mesmo defeito** por caminhos
diferentes. O defeito é um só: o Perfil afirmava, sobre uma pessoa que nunca
disputou nada, coisas que ninguém tinha verificado.

**A base** resolveu a parte competitiva com um **tipo**. `EstadoRanking` tem
quatro fases distintas — `indisponivel`, `carregando`, `falha`, `disponivel` —
e getters que higienizam na entrada: liga em branco não é liga, colocação `0` ou
negativa não é colocação. Home, Perfil e compartilhamento passaram a ler a mesma
constante `rankingDaCascaPublicavel`, e nenhuma tela vê o valor cru. É a parte
mais difícil do problema, e é a que fecha a porta para o defeito voltar por uma
entrada nova — inclusive por um backend futuro que mande zero no lugar de
ausente.

**A candidata** não tocou no tipo. Tornou `liga` e `posicaoMundial` nuláveis no
VM e apagou a linha inteira quando não havia nada. Em compensação, viu o que a
base não viu: **liga e colocação não eram os únicos campos inventados**. O ramo
não-demo do `PerfilService` também escrevia

```
nivel: 1 · xp: 0/1000 · titulo: 'Novato(a)' 🃏
stats: 0/0/0/0 · presentesCount: 0 · oito conquistas travadas
```

e tudo isso continuava desenhado na base. É o mesmo defeito sem a palavra
`Bronze`: um zero desenhado é uma **afirmação** — diz que a pessoa jogou e não
ganhou, que foi avaliada e ficou na base. Ninguém a avaliou.

A composição, portanto, é assimétrica de propósito: **o tipo vem da base, a
cobertura vem da candidata.**

---

## 2. Matriz de arbitragem

Cada linha é uma alteração da candidata avaliada por **comportamento
alcançável**, e não por diferença textual.

### ABSORVER — comportamento correto que a base não tinha

| # | Delta | Por que entra |
|---|---|---|
| 1 | `nivel` nulável; selo do avatar condicional | A base entregava `nivel: 1` e o selo desenhava `1`. Não há sistema de progressão ligado |
| 2 | `xpAtual`/`xpProximo` nuláveis; barra de XP condicional | A base entregava `0 / 1.000 XP`. Uma barra vazia diz que a pessoa está no começo de uma jornada que o jogo não conta |
| 3 | `titulo`/`tituloEmoji` nuláveis; faixa condicional | A base entregava `🃏 Novato(a)`. Título é concedido, não presumido — e este o jogo punha na pessoa sem ela ter feito nada |
| 4 | `stats` nulável; painel condicional | A base entregava `0/0/0/0`. Nada grava resultado de partida no cliente: não é o placar de quem não jogou, é um placar sem placar atrás |
| 5 | `presentesCount` nulável; baú condicional | A base entregava `0`. Não há inventário ligado, e um baú que abre vazio é pior do que ele não estar ali |
| 6 | `_catalogoTravado` retirado do serviço | Oito troféus apagados afirmam que a pessoa não desbloqueou nenhum. Quem sabe isso é `RecompensaConcessao`, que o cliente não lê |
| 7 | Seção CONQUISTAS condicional, **título incluído** | Absorvido, com o gatilho trocado — ver REJEITAR #11 |
| 8 | `Nível` condicional no texto de compartilhamento | A base já condicionava liga e colocação, mas seguia interpolando `'Nível ${vm.nivel}'` sem guarda. Com o campo ausente, mandaria a palavra `null` para a conversa de outra pessoa |

### REDUNDANTE — a base já resolve de forma equivalente ou superior

| # | Delta | Por quê |
|---|---|---|
| 12 | `_compartilhar` montando o texto embutido no `State` | A base extraiu `PerfilPage.textoDeCompartilhamento`, **estática e pública**: um teste confere o texto que sai do aparelho sem encenar toque nem mexer na área de transferência. Superior, e é o que fica |
| 13 | Reformatação de `EscopoSessao.identidadeDe(context,)` | Idêntica nas duas folhas |
| 14 | `PerfilVM.mock()` preservada cheia | As duas chegaram à mesma decisão: a maquete é catálogo visual e não é alcançável a partir de `main()` |

### REJEITAR — conflita com o estado canônico ou regride

| # | Delta | Por que não entra |
|---|---|---|
| 9 | `String? liga` + `int? posicaoMundial` no VM | Seria a **terceira** representação do mesmo estado. `EstadoRanking` distingue quatro fases e higieniza `0`, negativo e string vazia; dois campos nuláveis não distinguem "não perguntei" de "perguntei e deu erro", e é exatamente esse colapso que produziu o Bronze |
| 10 | Apagar a linha `💎 Liga` inteira quando não há liga | §4.2 manda usar **o estado neutro já aprovado na linha canônica**, que é o travessão de `EstadoRanking.ligaParaExibicao`. Ele não se parece com nome de liga, ninguém o lê como conquista e mantém o cabeçalho no lugar. A colocação, essa sim, some — não há travessão que faça `#` parecer honesto |
| 11 | `conquistas: const []` no ramo não-demo | Absorvida a intenção, rejeitada a forma. O campo virou `List<Conquista>?`: **nulo é "não perguntei a ninguém", `[]` é "perguntei, e a resposta foi nenhuma"**. Só a segunda autoriza o recado "Ainda sem conquistas" — que com a lista vazia viraria código morto, e que é justamente o que a Fase 2 vai produzir |

### TESTE A PRESERVAR

| # | Prova | Destino |
|---|---|---|
| 15 | Estrutural: o literal do ramo publicável do serviço | Absorvida e **estendida** em `casca/auditoria_casca_test.dart`. O caso que existia conferia só `statsDemo == false`, e desligar a chave nunca tocou no outro ramo do ternário — era por isso que o defeito passava pelo portão. Agora são seis pares proibidos, sete ausências exigidas e a garantia de que `_catalogoTravado` não reaparece |
| 16 | Estrutural: o convite sem fallback | Absorvida em `casca/auditoria_casca_test.dart` |
| 17 | Comportamento: quatro casos abrindo o Perfil **pela grade da Home** | Absorvidos e adaptados como cinco casos em `casca/casca_producao_test.dart`. O adjetivo é o valor da prova: as outras suítes montam a tela na mão; estes exercitam a raiz de produção, a sessão de verdade e a identidade real. As asserções sobre a linha da liga foram invertidas para o travessão, conforme REJEITAR #10 |

### O que só a base tem, e permanece intocado

`app/lib/ranking/estado_ranking.dart`; a Home lendo `rankingDaCascaPublicavel.liga`;
o `Flexible` do recado de estado terminal em `lobby_online.dart`;
`test/ranking/estado_canonico_ranking_test.dart`; `test/casca/homologacao_casca_v2_test.dart`;
e os dois laudos em `docs/`.

---

## 3. Comportamento final, pelos quatro estados

### Ranking disponível, com dado real
Liga e colocação saem como vieram. `EstadoRanking.disponivel(liga: 'Ouro')` sem
colocação mostra só a liga; `posicaoMundial: 0` chegando de um produtor distraído
é higienizado no tipo e não vira `#0` em lugar nenhum. Home, Perfil e
compartilhamento leem o mesmo objeto.

### Jogador ainda não classificado — o estado da casca de hoje
Nenhum `Bronze`, nenhum `#0 no mundo`, nenhum nível, título, XP, estatística,
presente ou conquista. Na tela restam identidade e vitrine. A linha competitiva
mantém o rótulo `💎 Liga` com o travessão — a ausência admitida da linha
canônica. O convite copiado é `Vem jogar Buraco comigo no Buraco Master VIP! Sou
{nome} 👑`, sem ponto solto no fim.

### Carregando
`FaseRanking.carregando`, distinto de `indisponivel`. A tela mostra esqueleto: o
`vmPlaceholder` não tem nome, nível, XP, título, placar, presentes nem
conquistas. Nada do jogador anterior sobrevive — logout e troca A→B são provados
com a sessão real.

### Falha
`FaseRanking.falha`, distinto dos outros dois. A tela pede recarga e **não
desenha o corpo do perfil**, o que impede tanto o vazamento do VM anterior quanto
o dos valores da maquete.

---

## 4. Fronteiras

Nenhuma autoridade nova de sessão, Perfil ou ranking foi criada; nenhuma
implementação de Perfil foi duplicada; nenhum arquivo legado foi reformatado em
massa. `PerfilVM.mock()` segue cheia e segue inalcançável a partir de `main()` —
há prova estrutural disso nas duas suítes.

Fora de escopo e não tocados: `6853c47`, `14cf1ed`, `891c0b3`, Crashlytics e
observabilidade, a conquista "Primeira Batida Real", Splash/Rive, Billing, APK,
AAB, deploy e Play Console. Nenhuma branch protegida foi alterada.

Esta base é a que deve receber, depois, a integração limpa de
Observabilidade/Crashlytics.
