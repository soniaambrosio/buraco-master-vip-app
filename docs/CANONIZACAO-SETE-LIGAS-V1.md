# Canonização funcional e visual das sete Ligas — V1

> Fecha a dependência declarada em `docs/POLITICA-COMPETITIVA-V1.md` §19.3 e a
> linha `icone` da tabela de lacunas de `docs/CONTRATO-RANKING-CLIENTE.md`.
> **Sem PR, sem merge em `main`, sem deploy.**

---

## 1. A escada oficial, e ela é única

| # | `ligaId` | Nome | Pontuação | Arte |
|---|---|---|---|---|
| 1 | `bronze` | Bronze | abaixo de 950 | `assets/ranking/liga_bronze.webp` |
| 2 | `prata` | Prata | 950 – 1.099 | `assets/ranking/liga_prata.webp` |
| 3 | `ouro` | Ouro | 1.100 – 1.249 | `assets/ranking/liga_ouro.webp` |
| 4 | `platina` | Platina | 1.250 – 1.399 | `assets/ranking/liga_platina.webp` |
| 5 | `diamante` | Diamante | 1.400 – 1.549 | `assets/ranking/liga_diamante.webp` |
| 6 | `mestre` | **Mestre** | 1.550 – 1.699 | `assets/ranking/liga_mestre.webp` |
| 7 | `lenda` | Lenda | 1.700 ou mais | `assets/ranking/liga_lenda.webp` |

Bronze tem piso **aberto**; Lenda tem teto **aberto**. Não existe oitava liga,
subdivisão, estrela, ponto de promoção nem patente intermediária.

**Imperial não é liga.** É denominação visual legada. Não é `ligaId`, não é nome
oficial, não é degrau e não é *fallback*. O arquivo `liga_imperial.webp`
permanece no repositório como legado **não referenciado**, até uma limpeza
independente e comprovadamente segura.

Durante colocação a tela mostra **Em colocação**; durante revalidação, **Em
revalidação**. Nunca Bronze, nunca a liga anterior.

---

## 2. Onde cada coisa mora

A escada existe em quatro lugares, e um só deles decide.

| lugar | papel |
|---|---|
| `functions-ranking/src/competicao.ts` → `DEGRAUS_V1` | **A AUTORIDADE.** Ids, nomes, faixas e caminhos de arte. |
| `app/assets/ranking/liga_*.webp` | a arte que os caminhos apontam. |
| `app/lib/screens/ranking_screen.dart` | maquete do catálogo visual — **espelho**, não autoridade. |
| Ranking, Perfil e Home produtivos | exibem o rótulo que a autoridade mandou. Não têm tabela de nomes nem de faixas. |

O que amarra os quatro é `app/test/ranking/escada_sete_ligas_test.dart`: ele
**lê** `DEGRAUS_V1` e confere todo o resto contra ela. Não redigita a escada — a
única lista escrita à mão nele é a dos sete `ligaId`, que é a afirmação de
produto desta OS (é o que reprova quem acrescentar uma oitava liga na própria
autoridade).

### `icone` é tabela literal, nunca derivação

`DegrauDeLiga.icone` proíbe deduzir `assets/ranking/liga_${nome.toLowerCase()}`
desde o primeiro dia, e a sexta liga é a prova viva do porquê: por seis meses a
arte se chamou `liga_imperial.webp` enquanto a regra sempre chamou a liga
**Mestre**. Uma regra de derivação teria apontado para arquivo inexistente — ou,
pior, teria convidado alguém a renomear a **liga** para caber no nome do
**arquivo**.

---

## 3. A arte da Mestre

| arquivo | onde | SHA-256 |
|---|---|---|
| `liga_mestre.webp` (256×256, WebP sRGBA) | `app/assets/ranking/` — **entra no pacote** | `b94295653828418d2509afc08f3c376bcbd15769988c35f78c5e43d590d3dd65` |
| `liga_mestre_512.webp` (512×512, WebP sRGBA) | `docs/artes/` — **fora do pacote** | `cb6df61726b2f3e1bc5d8f7d9accf8075a545e4885a05214667d7fcfb46fe8d8` |
| `liga_mestre_buraco_master_vip.png` (1024×1024, PNG sRGBA) | `docs/artes/` — **fora do pacote**, fonte | `ca014d9c556280415e6dd0e349049c694c8daf6efcb447d7bd9a1873c36b75ef` |

**Por que a de 256 no runtime, e não a de 512 nem a fonte.** As outras seis Ligas
são **88×88** e a escada as desenha em **30 lógicos**. 256 cobre 3× de densidade
com folga; 1024 gastaria um megabyte de memória para pintar trinta pixels. O
repositório **não tem** convenção de diretório de artes-fonte, então a fonte e a
versão ampliável foram preservadas em `docs/artes/`, que está fora de
`app/assets/` e portanto fora do bundle.

**Alfa medido, não presumido** (`L2j`/`L2k` da suíte, decodificando o arquivo):
256×256, os quatro cantos com alfa `0`, **37.256 de 65.536** pixels
completamente transparentes e 28.280 sólidos. Não há xadrez incorporado — uma
arte achatada sobre xadrez não deixaria vazio nenhum. Catorze pixels da moldura
são opacos, e legitimamente: há um elemento vertical que encosta no topo e na
base. Por isso o gate mede **proporção** (< 5% da moldura) e não "moldura limpa",
que reprovaria a arte por ser bem enquadrada.

---

## 4. Referências legadas encontradas, e o destino de cada uma

| onde | o que era | destino |
|---|---|---|
| `functions-ranking/src/competicao.ts` | `icone: ""` nos sete + comentário declarando a dependência | tabela literal com os sete caminhos |
| `functions-ranking/src/ligas.ts` | cabeçalho listando `liga_imperial.webp` como a 6ª arte | reescrito: registra o que a v1 fechou |
| `app/lib/screens/ranking_screen.dart` | `nome: 'Imperial'`, `icone: 'assets/ranking/liga_imperial.webp'`, `DivisaoAtual('Diamante III' → 'Diamante II')`, escada de **seis** degraus sem Lenda | sete degraus oficiais; `DivisaoAtual` → `ProgressoDeLiga` (liga atual → próxima liga) |
| `app/test/ranking/a11y_ranking_cabecalho_escala_test.dart` | `liga: 'Imperial'` como rótulo longo em 5 asserções | `Diamante` — mesmo comprimento, liga que existe |
| `app/test/ranking/leitor_ranking_real_test.dart` | lista de **proibição** de nomes de liga no cliente | mantida, e ampliada com `Mestre`; `Imperial` **continua proibida** de propósito |
| `firebase/testes/ranking.test.js` | `ligaId: 'imperial'` como escada forjada pelo cliente | `ligaId: 'a-minha'` — o teste nunca foi sobre o nome |
| `docs/CONTRATO-RANKING-CLIENTE.md`, `docs/POLITICA-COMPETITIVA-V1.md`, `docs/RESULTADO-BACKEND-RANKING.md` | dependência declarada em aberto | marcada como resolvida, apontando para este documento |
| `app/assets/ranking/liga_imperial.webp` | arte da 6ª liga | **permanece no disco**, fora do catálogo e sem referência em `lib/` |
| `app/assets/ranking/divisao_diamante.webp` | arte da subdivisão | **permanece no disco**, sem referência em `lib/` |

### Documentos produtivos com `ligaId: imperial`: **zero**

E não é estimativa. O codebase `ranking` **nunca foi implantado**: o censo de
produção de 2026-08-15, remedido em 2026-08-20, encontrou 5 funções `ACTIVE`
(todas de `billing`) e **7 documentos no Firestore inteiro**, nenhum deles de
`rankingStandings`. Não há população legada a migrar, e por isso **nada foi
migrado**. Se um dia houver, a política é a mesma que a §5.4 da OS fixa: a
autoridade **recalcula pela pontuação**, e ninguém reescreve `imperial` → `mestre`
à mão.

---

## 5. Segurança: não se equipa Liga pelo cliente

A prova é estrutural, e não uma lista de proibições:

- **o cliente não tem as faixas.** `L5a` varre o fecho transitivo de imports a
  partir de `lib/main.dart` e reprova se qualquer um dos doze limites (949, 950,
  1099, 1100, 1249, 1250, 1399, 1400, 1549, 1550, 1699, 1700) aparecer em código.
  Sem as faixas, "sou Mestre" não é uma conta que caiba no aparelho;
- **o cliente não tem os nomes.** `leitor_ranking_real_test.dart` reprova
  qualquer nome de liga escrito em `lib/ranking/`. O rótulo chega pronto do
  servidor;
- **um `EstadoRanking` montado à mão não vale como Liga.** `ehLigaDeVerdade`
  exige `ligaId`, e o único construtor que o preenche a partir de dado externo é
  `EstadoRanking.daFotografia`, que só recebe o que o transporte trouxe (`L5d`);
- **nada alcançável equipa Mestre ou Lenda** (`L5b`), e a preferência local não
  guarda liga (`L5c`);
- **a chave de demonstração do Perfil está desligada** (`L5e`);
- **Bronze não volta como fallback** (`L5f`). Ele é o único dos sete nomes
  proibido **por si** no fecho produtivo, e a assimetria é deliberada: os
  outros seis aparecem em fixture declarada de prévia e nenhum deles jamais
  foi valor-padrão de coisa nenhuma;
- **o cliente não pode escrever a escada.** `firebase/testes/ranking.test.js`
  prova, contra o emulador, que nem o dono nem o admin criam `rankingLadders`,
  trocam a política da temporada ou rebaixam a faixa de uma liga existente.

`souEu` continua sendo decidido no servidor, e a Liga também: ela é derivada da
pontuação por `ligaDe`, em `functions-ranking/src/ligas.ts`.

---

## 6. O portão

Gate `ligas7`, suíte `app/test/ranking/escada_sete_ligas_test.dart`, **48
casos**. Registrado em três lugares, e cada um fecha uma porta diferente:

1. `.github/workflows/ci-os-integracao.yml` — passo `roda ligas7`, mais as duas
   listas de gate (a da evidência publicada e a que decide verde/vermelho);
2. `app/test/suites_obrigatorias.txt` — entrada com `sha256`, piso de `provas` e
   26 blocos `exige`. Apagar a suíte, renomeá-la ou **esvaziá-la** reprova antes
   de qualquer teste rodar;
3. `scripts/ci/verificar_suites_obrigatorias.sh` — `PISOS` ganhou `ligas7:40`,
   para que baixar o piso no manifesto também apareça no diff.

**O que reprova o gate:** remover um degrau da autoridade, renomear uma liga,
mudar uma faixa, esvaziar um `icone`, apagar uma arte, apontar um `icone` para
`liga_imperial`, tirar `assets/ranking/` do pubspec, deixar a maquete divergir da
autoridade em id/nome/ordem/arte, reintroduzir subdivisão, tornar a maquete
alcançável pela raiz de produção, escrever um limite da escada no cliente, e
apagar a própria suíte.

---

## 7. Grupos da suíte

| grupo | o que prova |
|---|---|
| **L1** (11) | a autoridade: sete degraus, ordem, nomes, pontas abertas, faixas encaixadas, os doze limites da §7.1, pontuação negativa em Bronze, ausência de subdivisão, ausência de Imperial, Mestre em 6º e Lenda em 7º |
| **L2** (11) | a arte: `icone` não vazio, caminhos distintos, existência no disco, declaração no pubspec, Mestre com a arte da Mestre, nenhuma arte legada no catálogo, o legado fora do catálogo e sem referência em `lib/`, as sete carregam pelo pacote **e decodificam**, alfa real, ausência de xadrez incorporado |
| **L3** (9) | a maquete espelha a autoridade em id, nome, arte e ordem; um único `atual`; Lenda no topo; nenhuma subdivisão; "Imperial" fora do código de `lib/`; o catálogo visual continua **fora** do fecho produtivo |
| **L4** (8) | Ranking, Perfil e Home dizem a mesma liga para o mesmo payload; **Em colocação** e **Em revalidação** não viram Bronze nem liga anterior; liga desconhecida vira estado neutro; sem resposta não há liga; quem não pontuou não recebe liga |
| **L5** (6) | ninguém concede Liga pelo cliente, e Bronze não volta como fallback (ver §5) |
| **L6** (3) | o gate está registrado onde reprova |

### As três armadilhas que a suíte evita de propósito

1. **comentário não é código** — este repositório cita "Imperial" e "Diamante
   III" em prosa para explicar a remoção; toda varredura passa por
   `semComentarios`, senão a explicação seria acusada de ser a violação;
2. **árvore vazia passa** — todo grupo que varre ancora numa **contagem** antes
   de varrer;
3. **ausência do arquivo não é permissão** — a autoridade é **exigida**. Um gate
   que devolve verde por não ter achado o que conferir é pior que gate nenhum.

E uma armadilha do `flutter_test`, registrada porque custou dez minutos de
execução muda: decodificar imagem dentro de `testWidgets` **exige**
`tester.runAsync` (o `Future` vem da engine real, fora do relógio falso), e o
`expect` tem de ficar **fora** dele — uma asserção que falha dentro de
`runAsync` é atribuída ao caso errado, depois de pendurar a execução.

---

## 7.1 Campanha de mutação — 20 mutações, 20 detectadas

Um gate que nunca ficou vermelho não é um gate. Cada mutação abaixo foi
aplicada **só na bancada** (nunca no repositório), a suíte foi executada, e o
resultado exigido era vermelho:

| # | mutação | casos vermelhos |
|---|---|---|
| M01 | tirar o degrau da Mestre da autoridade | 9 |
| M02 | renomear Mestre para Imperial na autoridade | 3 |
| M03 | esvaziar o `icone` da Mestre | 5 |
| M04 | apagar a arte da Mestre do disco | 1 |
| M05 | apontar a Mestre para a arte legada | 5 |
| M06 | mudar a faixa da Mestre (1550 → 1500) | 2 |
| M07 | fechar o piso do Bronze | 3 |
| M08 | acrescentar uma oitava liga | 6 |
| M09 | trocar a ordem de dois degraus na autoridade | 6 |
| M10 | tirar a Lenda da maquete | 5 |
| M11 | devolver Imperial à maquete | 2 |
| M12 | devolver a subdivisão à maquete | 1 |
| M13 | trocar a arte de um degrau da maquete pela do vizinho | 1 |
| M14 | marcar dois degraus como atuais na maquete | 1 |
| M15 | tirar `assets/ranking/` do pubspec | 3 |
| M16 | escrever um limite da escada no código alcançável | 1 |
| M17 | tornar a maquete alcançável pela raiz | 4 |
| M18 | devolver o fallback Bronze à Home | 1 |
| M19 | fazer rótulo vazio virar Bronze em `EstadoRanking` | 3 |
| M20 | deixar estado de qualificação passar por Liga de verdade | 4 |

### O que a campanha achou, e não foi só confirmação

**A primeira rodada mentiu, e a mentira foi encontrada.** Ela declarou "16 de
16 detectadas" **sem ter executado um único teste**: o Node 24 recusa spawnar
`flutter.bat` sem shell (`EINVAL`, desde a correção da CVE-2024-27980), toda
execução caía no `catch`, e o arnês lia exit-code diferente de zero como
"mutação detectada". A correção é dupla, e vale para qualquer campanha futura
neste repositório: `execSync` com shell, e **veredito pela CONTAGEM do
reporter**, nunca pelo exit code — um tropeço de ambiente também sai
diferente de zero.

**E ela achou um buraco real.** Devolver o fallback `Bronze` à Home (M18)
passava pela suíte. A guarda existia em `estado_canonico_ranking_test.dart` —
que não é obrigatória no manifesto —, e não na suíte que a OS tornou
obrigatória. O caso `L5f` nasceu daí.

---

## 8. O que esta OS NÃO fez

- **não criou superfície nova.** A escada "Suas ligas" e o card de progresso
  existem **apenas** na maquete; nas superfícies produtivas não há escada a
  corrigir. Criá-las é decisão de produto, e não estava na OS;
- **não acrescentou campo à projeção pública.** `JogadorPublicado` continua com
  os mesmos 17 campos; a referência visual chega ao cliente por `escadaLigas`,
  que já carrega `ligaId` + `icone` dos sete;
- **não mexeu nas faixas de pontos**, não criou subdivisão, não transformou
  Imperial em apelido de Mestre e não concedeu liga por assinatura, compra ou
  cortesia;
- **não apagou** `liga_imperial.webp` nem `divisao_diamante.webp`;
- **não fez PR, merge em `main` nem deploy.**

---

## 9. Evidência de execução

Bancada local que espelha o overlay do `ci-os-integracao.yml`: `flutter create`
+ o `pubspec` do repositório + `app/lib`, `app/assets`, `app/test` e os seeds de
`app/data`, com `functions-ranking/` e `.github/` alcançáveis um nível acima —
a mesma geometria que o CI monta ao criar `app_build/` na raiz. Flutter local
**3.41.4**; o CI fixa 3.44.8, e por isso o número absoluto do `analyze` não é
comparável entre os dois — o que se compara aqui é base contra candidata na
**mesma** máquina.

| medida | base `291dfad` | candidata | delta |
|---|---|---|---|
| `flutter test` (glob `**_test.dart`) | 1409 verdes, 1 pulado | **1457** verdes, 1 pulado | +48 |
| `teste_motor` + `teste_motor_resiliencia` + `teste_encerramento` | 338 | 338 | — |
| `functions-ranking`: `npm test` | 407 | **416** | +9 |
| `functions-ranking`: `tsc --noEmit` | exit 0 | exit 0 | — |
| `flutter analyze` | 106 issues, 0 erros | 106 issues, 0 erros | conjunto **idêntico** |
| `verificar_suites_obrigatorias.sh` | 2 suítes | **3** suítes, exit 0 | +1 |
| campanha de mutação | — | 20 mutações, **20 detectadas** | — |

O `analyze` foi comparado **sem linha e sem coluna**: a maquete cresceu ~90
linhas, e uma comparação crua acusaria dez avisos pré-existentes como novos só
porque desceram de posição. O conjunto de (severidade, mensagem, arquivo, regra)
é idêntico entre base e candidata.

**Sem evidência de CI**, e não é falha da entrega: `ci-os-integracao.yml` só
dispara em `push` para `integracao/os-final-backend-flutter` ou por
`workflow_dispatch`, e nenhuma das duas coisas foi feita.

---

## 10. Base e arbitragem

A base **não** foi uma folha publicada isolada, e o porquê está registrado aqui
porque é a parte da entrega que mais custou a decidir.

Das **194** refs remotas, **74** são folhas maximais (calculadas por um dump
único do DAG — `git branch --contains` custa ~21 s por ref neste repositório).
Das 74, apenas as da família A descendem de `089cb5e`, que é a única linhagem
que carrega **as cinco autoridades** que o Gate Zero exige ao mesmo tempo:
Política Competitiva v1 (`cad4515`), backend de Ranking/Temporadas (`af57fe8`),
leitor real de Ranking (`e1923f1`), sessão/identidade públicas e navegação
produtiva de Ranking e Perfil (`53105ab`).

A segunda família publicada (loja/chat/functions canônica, pontas `7459d44` e
`5aa8263`) é **mais recente** e mesmo assim foi descartada como base: ela não
contém `53105ab` nem `089cb5e`. Não houve arbitragem a fazer entre as duas —
uma delas simplesmente não atende ao Gate Zero.

Dentro da família A há **15** folhas maximais irmãs, e a arbitragem foi
medida, não estimada: varrendo o diff de cada uma contra o ancestral comum
`bf5a9e7`, **uma só** toca arquivo de Ranking/Liga — `246481e`
(`a11y-ranking-cabecalho-escala`, que reescreve `ranking_de_producao.dart`). As
outras catorze mexem em Ajustes, Mesa, Splash, Torneios, Loja e pipeline.

A base é, portanto, a composição **mínima** de duas folhas:

```
8bb9117  correcao/os30-c2-integridade-suite-a11y-ajustes-v1   (a mais recente da família, traz o portão de suítes obrigatórias)
246481e  claude/a11y-ranking-cabecalho-escala-v1-316f02        (a única que toca a superfície de Ranking)
   ↓
291dfad  merge de arbitragem
```

Os conjuntos de arquivos das duas são **disjuntos**, exceto
`.github/workflows/ci-os-integracao.yml`, resolvido à mão pela **união** dos
dois passos de portão — nenhum dos dois lados perdeu nada, e isso foi auditado
arquivo a arquivo em vez de confiado ao merge limpo.

**Nenhuma ref publicada já havia trocado Imperial por Mestre.** Medido, não
suposto: o blob de `functions-ranking/src/competicao.ts` é **idêntico**
(`46926d89`) em todas as 74 folhas maximais, e a árvore de
`app/assets/ranking/` também (`0e828dca`).
