# Identidade do Perfil público visitado — canonização pelo `publicId`

**Veredito:** `PASS — NOME E AVATAR DO PERFIL PÚBLICO VISITADO CANONIZADOS PELO PUBLICID V1`

Branch: `claude/perfil-publico-visitado-identidade-canonica-v1`
Base: `integracao/avatar-ranking-estatisticas-navegacao-publica-v1` @ `089cb5ee8e050f8903aabd8336509973834c9a7a`

---

## 1. Gate Zero

Branch e SHA confirmados por duas vias remotas independentes (`ls-remote` pelo
remoto configurado e `ls-remote` pela URL explícita). Ancestrais da composição
verificados: `92344ed`, `e1923f19`, `fda063bf`, `6e428e8`, `41a767a`,
`79063e07`, `53105ab` — todos presentes. Árvore limpa. Linha de base
reproduzida: Flutter 1153/1153, `functions-ranking` 407/407, `tsc --noEmit`
exit 0, `flutter analyze` exit 0 (103 infos).

### O mapa que a §2 pediu

| Pergunta | Resposta encontrada |
| --- | --- |
| Quem fornece `publicIdVisitado` | `casca/navegacao_perfil_publico.dart`, único ponto, a partir de `jogador.publicPlayerId` da tabela |
| Quem fornecia o nome | `PerfilService.carregar` a partir de `identidade` — **sempre a da SESSÃO** |
| Quem fornecia o avatar | idem, mais a reaplicação incondicional de `comAvatarPublico` no `build` |
| Fonte da liga | `LeitorDeRanking.rankingPublico` → `consultarJogadorPorIdPublico` (correta) |
| Fonte das estatísticas | nenhuma: `stats` era nulo fora do modo demo |
| Fonte canônica pública | **existe** — ver §2 |

---

## 2. STOP da §3: NÃO disparou

A §3 manda parar se não existir hoje uma fonte canônica capaz de dar nome e
avatar públicos a partir de um `publicId`. Ela existe, e o cliente **já a
consultava**:

```ts
// functions-ranking/src/index.ts — consultarJogadorPorIdPublico
return { id, temporadaId, classificado: true, jogador: projetarJogador(standing, uid) };
```

`projetarJogador` é uma **lista branca**, e `CAMPOS_PUBLICADOS` nomeia
`apelido` e `avatar` entre os campos autorizados — junto com `partidas`,
`vitorias`, `derrotas` e `aproveitamento`. O uid não entra e não sai.

O defeito nunca foi falta de autoridade: era **descarte**. O cliente lia daquele
mapa só `liga`, `ligaId` e `posicao`, jogava o resto fora, e depois completava
nome e avatar com a identidade de quem estava olhando.

Por isso nenhum backend foi tocado. Esta correção é de **consumo**, como a §23
previu.

Existe também `social:verPerfilPublico`, que é a autoridade de identidade
propriamente dita. **Não foi usada**, e a decisão está registrada em §8 como
risco residual.

---

## 3. O que mudou

| Arquivo | Mudança |
| --- | --- |
| `ranking/ranking_transporte.dart` | `FotografiaRanking.publico` guarda a projeção pública inteira, lida pelo **mesmo** `JogadorPublicoRanking.doMapa` da tabela |
| `ranking/leitor_ranking.dart` | `perfilPublico(...)` devolve identidade **e** estado na mesma leitura; `LeituraDeAbertura.visitado`; `rankingPublico` virou projeção dela |
| `pages/perfil_page.dart` | traduz a projeção num ponto só (`_retratoDe`); passa `identidade: widget.ehMeuPerfil ? identidade : null`; reaplicação do avatar da sessão ganhou guarda |
| `services/perfil_service.dart` | com retrato de visitado, sai cedo e **não lê** a identidade |
| `screens/perfil_screen.dart` | `RetratoVisitado`; `canastras` virou `int?`; o quadradinho some quando não há fonte |
| `test/perfil/identidade_visitada_test.dart` | **novo** — 25 casos |
| `test/casca/auditoria_casca_test.dart` | 2 casos de integridade do gate |
| `test/casca/homologacao_avatar_publico_test.dart` | H-E09: forma do repasse alargada; a página entrou na lista de produtoras |
| `test/composicao/composicao_navegacao_publica_test.dart` | o caso da pendência passou a afirmar o comportamento correto |
| `.github/workflows/ci-os-integracao.yml` | gate `perfilvis` |

### Fonte canônica do nome

A projeção pública do `publicIdVisitado` — `apelido`, e a mesma regra de
apresentação do perfil próprio quando ele vem vazio (id público, senão rótulo
genérico). Nunca `SessaoDoJogador`, nunca `displayName`, nunca e-mail.

### Fonte canônica do avatar

A mesma projeção, passando pelo resolvedor canônico `avatarPublicoDe`. **Sem
segundo fallback**: referência ausente ou malformada de um terceiro cai na
mesma coroa que a de qualquer um, e um `https://` continua não virando
requisição de rede.

### Perfil próprio × visitado

| | Próprio | Visitado |
| --- | --- | --- |
| nome / avatar | sessão canônica | projeção pública do `publicIdVisitado` |
| liga | `EscopoRanking` (lido no `build`, acompanha a consulta) | da mesma leitura pública |
| estatísticas | ausentes (nada grava no cliente) | as publicadas, com `canastras` nulo |
| reaplicação do avatar no `build` | sim (reatividade do dono) | **não** |

Três decisões que merecem o porquê:

1. **`publico` fica nulo no caminho do dono**, embora `abrirRanking` também
   traga apelido e avatar em `resumo.eu`. A identidade do dono vem da sessão
   canônica, que é a autoridade certa para ele e não depende de estar
   classificado. Preencher ali criaria uma segunda fonte de nome para o dono.
2. **A página passa `identidade: null`** para um visitado, em vez de confiar que
   o serviço "vai preferir o visitado". Confiar deixaria de pé o caminho pelo
   qual o defeito existia: bastava a projeção faltar para o serviço cair de
   volta na sessão. Com `null`, não há para onde cair.
3. **`canastras` virou `int?`** porque `projetarJogador` não a publica. Zero
   afirmaria que a pessoa nunca fez canastra; esconder os outros três jogaria
   fora o que a autoridade publicou. Nulo é a terceira saída, e é a mesma regra
   que nível, XP e título já seguem.

---

## 4. Matriz "A visita B"

Fixtures deliberadamente sem nada em comum:

| | visitante (A) | visitado (B) |
| --- | --- | --- |
| apelido | `Ana` | `Bartolomeu` |
| avatar | `coruja_dourada` | `lobo_prateado` |
| liga | Diamante, #3 | Prata, #47 |
| números | 999 partidas / 888 vitórias / 88% | 20 / 7 / 35% |

O caso de identidade cruzada afirma os quatro campos de B **ao mesmo tempo** e
varre a tela inteira atrás de qualquer traço de A (`Ana`, `coruja_dourada`,
`Diamante`, `999`). Um por um, cada asserção poderia passar por acidente; os
quatro juntos, com fixtures assim, não.

## 5. Corrida B → C

`V9`: B é aberto com a consulta pendurada, o teste navega para C, C responde e
só **depois** a resposta atrasada de B chega. C sobrevive nos três campos.

A proteção é estrutural e já existia: cada visita empilha uma rota nova, logo um
`State` novo, e a chave do leitor é `(conta, alvo)` — a resposta de B não tem
onde tocar em C. Nenhum estado global paralelo foi inventado.

## 6. Comportamento em falha

| Cenário | Resultado |
| --- | --- |
| Leitura pública falha | sem identidade afirmada; **não** cai para a sessão (`V15`) |
| `classificado: false` | idem — o jogador respondeu e não está na tabela (`V15b`) |
| Avatar ausente | fallback público único (`V16`) |
| Avatar malformado (`https://`) | mesmo fallback, e nenhuma `Image` de rede (`V16b`) |
| `publicId` vazio | não consulta e não afirma identidade (`V11`) |

Em nenhum deles a tela "parece funcionar" mostrando o dono da sessão.

---

## 7. Testes e mutações

```
flutter analyze   exit 0   103 issues (só info) — MESMA linha de base da composição
flutter test      exit 0   1180 verdes  (1153 + 25 da suíte nova + 2 do gate)
functions-ranking: tsc --noEmit  exit 0
functions-ranking: npm test      exit 0   407/407  (intocado)
```

### Provas negativas — 10 exigidas, 12 executadas

| # | Mutação | Morta por |
| --- | --- | --- |
| 1 | nome do visitado = sessão | `V3`, `V7`, `V-cruzado` + guarda estrutural |
| 2 | avatar do visitado = sessão | `V4`, `V-cruzado`, `V9` |
| 3 | fallback coroa no visitado | `V16b` e, depois do ajuste de escopo, `H-E09` |
| 4 | fallback para `displayName` | `V3`, `V4` |
| 5 | apelido vira identificador | `V12` |
| 6 | posição vira identificador | `V13` |
| 7 | B atrasado sobrescreve C | ver abaixo — induzida na chave do leitor, morta por `V9` |
| 8 | erro de leitura cai para a sessão | `V15`, `V15b` |
| 9 | consulta ignora o `publicIdVisitado` | `V9`, `V10` |
| 10 | nome de B com avatar de A | `V4`, `V8` |
| 11 | apagar a suíte | `auditoria_casca` — "a suíte existe na árvore" |
| 12 | tirar `perfilvis` do portão | `auditoria_casca` — "o workflow a executa e a considera" |

**Duas mutações não se comportaram como a OS previa, e isso é resultado:**

* **a nº 1 é inerte quando aplicada em um ponto só.** Fazer o serviço preferir a
  identidade da sessão não muda nada, porque a página já manda `null`. Foi
  preciso reverter as **duas** metades para reproduzir o defeito — que é a
  definição de defesa em profundidade, e está registrado porque um leitor futuro
  poderia concluir que a mutação "não é detectada".
* **a nº 7 não se induz removendo o `if (!mounted)`.** A proteção contra B
  sobrescrever C não é aquele `if`: é que B e C são rotas diferentes, com
  `State`s diferentes, e um `State` morto não escreve no vivo. Para provar que
  `V9` tem dentes, a mutação foi levada ao ponto que **pode** produzir o defeito
  — a chave do leitor deixando de distinguir o alvo, o que faria B e C
  compartilharem voo. `V9` reprova.

### Um achado das provas negativas

A mutação nº 3 foi pega pelo comportamento e **não** por `H-E09`, que existe
justamente para essa forma. O contrapositivo dela varria `home_de_producao`,
`perfil_service` e `perfil_screen` — a página não estava na lista porque, até
esta OS, ela não produzia valor de avatar nenhum. Agora produz. Com a página
dentro, a mesma mutação na forma realista cai em `H-E09`.

---

## 8. Gate

`roda perfilvis test/perfil/identidade_visitada_test.dart`, mais o nome nas
**duas** listas: a da evidência publicada (`GATES`) e a que decide
verde/vermelho. Estar só na primeira faria o gate aparecer no relatório sem
poder reprovar.

* **arquivo alcançado** — o passo de overlay já copia `app/test/.` inteiro;
* **saída participa da evidência** — `t_perfilvis.log` entra no relatório;
* **ausência reprova** — provada pela mutação nº 11;
* **agregador considera** — provado pela nº 12.

A prova de integridade do gate mora em `auditoria_casca_test.dart`, e não na
suíte que ela protege, por um motivo concreto: o workflow trata arquivo ausente
como NÃO EXECUTADO, e NÃO EXECUTADO **não** derruba o portão. Apagar a suíte a
silenciaria em vez de quebrá-la; uma prova escrita dentro dela morreria junto.

Triggers, branches e permissions: intocados.

---

## 9. Risco residual

**A identidade de um visitado sem classificação.** A autoridade usada
(`consultarJogadorPorIdPublico`) responde `classificado: false, jogador: null`
para quem não tem standing na temporada vigente — e aí não há nome nem avatar a
mostrar. Hoje isso é **inalcançável em produção**: o único ponto que abre um
perfil de terceiro é a tabela do Ranking (`ranking_de_producao.dart:280`), onde
o jogador necessariamente tem standing. `V15b` cobre o caso e prova que ele não
vaza a visitante.

Fechá-lo de verdade exige consumir `social:verPerfilPublico`, que é a autoridade
de identidade e não depende de ranking. Isso significaria **um transporte novo no
cliente** para o codebase social — hoje ele só chama `obterMinhaIdentidade` — e
uma resposta que carrega relação de amizade e ações, com superfície de
privacidade maior. Ficou fora por escopo (§23: "corrigir consumo de uma
autoridade pública já existente, não criar uma"), e é a próxima OS natural.

Outros pontos registrados:

* `canastras` não tem fonte pública para ninguém — o quadradinho some no perfil
  visitado e continua ausente no próprio;
* o perfil visitado não mostra conquistas, vitrine nem presentes, porque nada
  disso é publicado; nenhum deles caía para a sessão antes nem cai agora.

---

## 10. Fechamento

* perfil próprio continua correto (`V1`, `V2`, `V18`);
* perfil visitado mostra nome, avatar, liga e números do visitado;
* nenhuma identidade da sessão completa um terceiro;
* falha não vaza a visitante;
* corrida B→C protegida;
* `publicId` continua a chave única;
* nenhuma informação privada aparece (`V17`, `V17b`);
* árvore limpa; local = remoto;
* **zero** deploy, PR, merge em `main` ou alteração de backend não relacionado —
  `functions-ranking` não foi tocado (407/407 idênticos), e nenhum outro codebase
  entrou no diff.
