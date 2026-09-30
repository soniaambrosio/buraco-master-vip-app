# Homologação — encerramento pendente até a apresentação confirmada pela UI (V1)

**Veredito: PASS.**

Nenhum arquivo de `app/lib/` foi alterado. Os 12 defeitos injetados foram todos
detectados. Não houve regressão de analyzer nem de suíte. Os riscos residuais
estão na seção 9 e nenhum deles é perda do aviso.

---

## 1. Refs e ancestralidade

| | Branch | SHA |
|---|---|---|
| Base | `claude/ligacao-encerramento-autoritativo-ui-v1` | `8bd9661f7274c8f01267e5ba8ffaacf800aa3d14` |
| Candidata | `claude/encerramento-ui-pendente-ack-v1` | `e7bc236f00fa98b79f19c371999ef7745f94211c` |
| Laudo | `homologacao/encerramento-ui-pendente-ack-v1` | nasce exatamente da candidata |

Resolvidas por **duas consultas `ls-remote` independentes**, com os mesmos
valores nas duas. A segunda foi uma listagem completa filtrada, não uma repetição
da primeira, justamente para não herdar um refspec truncado — o modo conhecido
de o `fetch` mentir sobre ancestralidade.

Gate Zero, item por item:

| Exigência | Resultado |
|---|---|
| `8bd9661` é ancestral de `e7bc236` | **SIM** (`merge-base --is-ancestor`) |
| `390b282` presente no intervalo | **SIM** |
| `e7bc236` é filho **direto** de `390b282` | **SIM** — pai único `390b282…` |
| Merges na candidata | **0** |
| Refs móveis | nenhuma; os SHAs completos exigidos pela OS conferem |
| Árvore suja | não; worktrees exclusivos, criados para esta homologação |

A cadeia é linear, quatro commits:

```
8bd9661  (base)
  440b84a  feat(encerramento): o efeito terminal ganha pendente, reivindicado e apresentado
  a28c65a  test(encerramento): a matriz do efeito pendente, e as oito provas negativas
  12c18f8  docs(encerramento): o laudo do aviso pendente até a apresentação
  390b282  ← o marco intermediário que a OS exige
e7bc236  fix(casca): o apresentador que estoura devolve o aviso em vez de engoli-lo
```

### Ambiente

| | |
|---|---|
| Flutter | 3.41.4 · canal stable · revisão `ff37bef603` |
| Dart | 3.11.1 |
| Engine | `99578ad0355da00edb26301c874a3c250a5716f5` |
| Java | não exercitado — esta homologação não compila Android; nada de `app/lib/` fora de Dart foi tocado |
| SO | Windows 11 Home Single Language 10.0.26200 (win32) |

Três worktrees exclusivos: base (`8bd9661`, detached), candidata
(`e7bc236`, a branch do laudo) e um descartável para as mutações.

---

## 2. Inventário

Confirmado por `git diff --name-status 8bd9661 e7bc236`, sem consultar relatório
anterior. **Oito arquivos, exatamente os oito declarados pela OS** — mas **quatro
caminhos da OS estão errados**. Os basenames casam 8/8; os diretórios, não.

| Estado | Caminho **real** | Caminho na OS | linhas |
|---|---|---|---|
| M | `app/lib/casca/lobby_online.dart` | idem | +169 −21 |
| M | `app/lib/casca/mesa_online/encerramento_da_mesa.dart` | `app/lib/casca/encerramento_da_mesa.dart` | +99 −43 |
| M | `app/lib/services/online_service.dart` | `app/lib/casca/mesa_online/online_service.dart` | +27 −5 |
| M | `app/lib/services/ordem_da_visao.dart` | `app/lib/casca/mesa_online/ordem_da_visao.dart` | +43 −50 |
| M | `app/test/casca/encerramento_na_ui_test.dart` | idem | +25 −4 |
| A | `app/lib/services/livro_de_efeitos_terminais.dart` | `app/lib/casca/mesa_online/livro_de_efeitos_terminais.dart` | +253 |
| A | `app/test/casca/encerramento_pendente_test.dart` | idem | +1443 |
| A | `docs/ENCERRAMENTO-PENDENTE-ATE-APRESENTAR-V1.md` | idem | +226 |

É divergência de transcrição da OS, não arquivo a mais nem a menos. Registrada
porque o par caminho+arquivo das OSs já divergiu antes, e o que vale é o Git.

**Superfície proibida: zero.** Varredura do `--name-only` por `server`,
`functions`, `.rules`, `firebase`, `firestore.`, `pubspec`, `assets/`,
`main.dart`, `protocolo`, `.yml`/`.yaml` e `.json` não devolveu nada.

---

## 3. Máquina de estados

`LivroDeEfeitosTerminais` (`app/lib/services/livro_de_efeitos_terminais.dart`)
guarda três situações e uma transição de volta:

```
   registrar()            reivindicar(dono)          confirmar(dono, aviso)
──────────────► pendente ─────────────────► reivindicado ─────────────────► apresentado
                    ▲                            │                          (fim de linha)
                    └────────────────────────────┘
                     liberar(dono, aviso)
                     liberarTudoDe(dono)
```

Provado independentemente que a confirmação **só** acontece depois de
`ResultadoDaApresentacao.apresentado` — o único ponto de `confirmar` no código de
produção está depois do `await` do apresentador e sob a comparação com esse valor.

As nove formas de falha exigidas pela OS devolvem o efeito a `pendente`:

| Falha | Caso | Como o efeito volta |
|---|---|---|
| ausência de consumidor | H01 | nunca sai de `pendente` — `registrar` não reivindica |
| recusa | H12 | `liberar` no ramo `!= apresentado` |
| cancelamento | H13 | mesmo ramo |
| dispose | H14 | `liberarTudoDe(posse)` no `dispose` |
| troca de transporte | H15 | `liberarTudoDe(posse)` no `didChangeDependencies` |
| rota morta | H12/H13 | o apresentador de produção devolve `recusado` sem `Navigator` |
| exceção síncrona | H16 | `catch` → `liberar` |
| futuro com erro | H17 | mesmo `catch`, no `await` |
| falha do canal global de relato | **H18** | `liberar` **antes** de `reportError` |

**Posse antiga não confirma nem libera posse nova:** `confirmar`, `liberar` e
`liberarTudoDe` exigem `identical(efeito.dono, dono)`. Provado no nível de unidade
(H21, H22) e no de integração (H20).

---

## 4. Fonte autoritativa

| Exigência da OS | Caso | Resultado |
|---|---|---|
| 1. nasce só do envelope autoritativo | H01, H03 | visão em andamento não cria efeito; `conhecidos == 0` |
| 2. não infere pela visão terminal | H04, H05, **H33** | a palavra `encerrada` não aparece em código nenhum de `lobby_online.dart` |
| 3. a "cutucada" não é segunda fonte | **H06, H07** | aviso forjado, entregue direto no slot, não é apresentado; com pendente no livro, apresenta-se o **do livro** |
| 4. o livro é a única drenagem | H33 | um único `efeitosTerminais.reivindicar` no arquivo, dentro de `_drenar` |
| 5. confirma só depois de apresentar | H12–H19 | ver seção 3 |
| 6. reconexão não reapresenta | H04, H05 | queda + volta + reenvio ⇒ 1 anúncio |
| 7. pendente é apresentado após reentrada legítima | H02, H09, H12–H20, H30 | |
| 8. modo legado não fabrica `eventoId` | **H08** | `eventoId` e `versaoEstado` chegam **nulos** ao apresentador |
| 9. eventos distintos não colidem | H11, H24, H25 | legado + carimbado convivem; `conhecidos == 2` |
| 10. escopo do livro | **H28** — ver ressalva | |

**Ressalva no item 10.** A OS pede "o livro é por processo". O contrato
efetivamente declarado e entregue é **por mesa/transporte**: a instância vive em
`OrdemDaVisao`, que vive no `OnlineService`, e `sair()` a zera via
`reiniciarMesa()`. Um livro por processo seria pior — vazaria entre mesas e entre
contas. H28 prova a independência entre transportes e H27 prova que sair da mesa
zera o livro, permitindo que a mesa seguinte reuse o mesmo `eventoId`. Tratado
como imprecisão de redação da OS, não como desvio da entrega.

---

## 5. Ciclo de vida da assinatura

| Exigência | Caso |
|---|---|
| assinatura nasce fora de `build` | H29 (comportamento) + **H31** (varredura: `aoEncerrar`, `_ligarAoEncerramento`, `reivindicar` e `PosseDoEfeito` ausentes do corpo de `build`) |
| rebuild não duplica assinatura | H29 — 12 reconstruções por três caminhos, identidade de `aoEncerrar` inalterada |
| troca de transporte solta posse e vínculo | H15 |
| `dispose` impede efeito tardio | H14, H20 |
| slot anterior só é removido se ainda for do mesmo dono | H20 — na troca por chave o slot já é do vínculo novo e **não** é zerado |
| consumidor novo não é apagado pelo antigo | H20 |
| ausência temporária de tela não descarta o evento | **H30** — três idas e voltas, efeito segue `pendente` |
| reentrada drena o pendente | H02, H09 |

---

## 6. Exceções do apresentador

Suíte independente, sem tocar os testes da candidata.

| Exigência | Caso |
|---|---|
| 1. `throw` síncrono antes de existir `Future` | H16 (`ApresentadorInstavel` **não** é `async`, senão a forma síncrona não existiria) |
| 2. `Future.error` | H17 |
| 3. efeito segue pendente nos dois casos | H16, H17 |
| 4. nenhum anúncio confirmado | H16, H17 — `vistos` vazio |
| 5. erro encaminhado por `FlutterError.reportError` | H16, H17 — `takeException()` devolve o `StateError` |
| 6. reentrada apresenta o mesmo `eventoId` | H16, H17, H18 |
| 7. segunda tentativa confirma uma única vez | H19 |
| 8. nenhuma exceção antiga reaparece | H16, H17, H18 — `takeException()` nulo ao final |
| 9. dois encerramentos distintos seguem independentes | H24, H25, H26 |

### O caso obrigatório: o relato também falha (H18)

Sequência, na ordem exigida:

1. `FlutterError.onError` é substituído por um gancho que **lança** outra exceção;
2. o apresentador estoura (forma síncrona);
3. comprova-se que `estadoDe('fim-K') == pendente` — o efeito **já** havia voltado
   antes de o relato falhar;
4. o manipulador global é restaurado (em `addTearDown` **e** antes do primeiro
   `expect`, para que um `expect` que falhasse não estourasse dentro do estouro);
5. reentra-se com apresentador saudável;
6. o **mesmo** `eventoId` é apresentado e confirmado, uma vez.

**Este caso reprova sob a inversão exigida.** A mutação M10 ("relatar antes de
liberar") derruba **H18 e só H18** — nenhum outro caso da matriz a percebe.

Detalhe de bancada que vale registrar: a exceção do relato escapa por um
`addPostFrameCallback`, isto é, num futuro que ninguém aguarda, e o
`flutter_test` reprova o caso em **qualquer** erro assíncrono não tratado. Duas
tentativas anteriores não serviram — delegar ao manipulador original faz o
framework reprovar na hora, e engolir a segunda chamada dispara o
`assert(_pendingExceptionDetails != null)` do binding. O quadro roda dentro de um
`runZonedGuarded`, e a fuga é **capturada e assertada** (é `StateError`, e é a do
relato, não a do apresentador). Sem isso o caso não é escrevível.

### Sobre log

Não se afirma ausência absoluta de registro: `FlutterError.reportError` entrega
ao gancho que a aplicação instalar, que pode muito bem mandar a ocorrência ao
console ou ao Crashlytics. O que **H32** prova é ausência de escrita **direta**
nesta camada — sem `print`, `debugPrint`, `log(`, `developer.log`, `Crashlytics`,
`Analytics`, `stdout` ou `stderr` nos quatro arquivos de produção da entrega,
medidos com comentários e literais de texto removidos (uma varredura crua acusaria
o comentário que explica a proibição de ser a violação).

---

## 7. Matriz independente

`app/test/casca/homologacao_encerramento_pendente_ack_test.dart` — **33 casos,
33 verdes.** Cenários remontados do zero: bancada própria (`Trilho`),
apresentadores próprios (`ApresentadorDeBancada`, `ApresentadorInstavel`),
helpers próprios. Falsos apenas o socket (`CanalFalso`, da bancada
compartilhada) e o apresentador; `OnlineService`, `OrdemDaVisao`,
`LivroDeEfeitosTerminais` e `LobbyOnline` são os de produção.

| # | Caso |
|---|---|
| H01 | o fim chega **sem** consumidor e fica pendente |
| H02 | o consumidor entra **depois** e drena o pendente |
| H03 | visão em andamento não registra efeito nenhum |
| H04 | o reenvio do retrato terminal não reapresenta |
| H05 | queda e volta não reapresentam o fim já apresentado |
| H06 | a cutucada **não** é fonte: aviso forjado não é apresentado |
| H07 | com pendente no livro, a cutucada forjada apresenta o aviso **do livro** |
| H08 | envelope sem carimbo apresenta uma vez e **não fabrica id** |
| H09 | o legado também espera por consumidor |
| H10 | dois legados na mesma mesa colapsam num efeito |
| H11 | legado e carimbado não colidem |
| H12 | **recusa** devolve o efeito; a reentrada apresenta |
| H13 | **cancelamento** devolve o efeito; a reentrada apresenta |
| H14 | **dispose antes do quadro** devolve o efeito |
| H15 | **troca de transporte** devolve o efeito do transporte anterior |
| H16 | **exceção síncrona** devolve o efeito |
| H17 | **futuro com erro** devolve o efeito |
| H18 | **o próprio relato estoura** e o efeito já voltou a pendente |
| H19 | a segunda tentativa bem-sucedida confirma uma vez só |
| H20 | **posse antiga** não confirma nem perde o efeito com vínculo novo já nascido |
| H21 | `confirmar`/`liberar` exigem a **mesma** posse (unidade) |
| H22 | `liberarTudoDe` solta só o que é do dono (unidade) |
| H23 | **duplicata** antes da confirmação não abre um segundo |
| H24 | dois eventos distintos são apresentados e não colidem |
| H25 | dois eventos no mesmo quadro saem ambos, em ordem |
| H26 | um evento recusado não contamina o outro |
| H27 | sair da mesa zera o livro; a próxima mesa é outra |
| H28 | dois transportes têm livros independentes |
| H29 | reconstruções repetidas não criam assinatura a mais |
| H30 | ausência temporária de tela não descarta o evento |
| H31 | a assinatura não é escrita dentro de `build()` |
| H32 | nenhum `print`, `debugPrint`, `log` ou telemetria direta |
| H33 | o efeito não nasce da visão, e o livro é a drenagem |

Dois casos falharam na primeira execução e **os dois eram defeito da prova, não
da candidata**, corrigidos na prova:

* **H20** supunha que `pumpWidget` não roda quadro. Roda — o efeito já estava
  `apresentado` quando a asserção media `reivindicado`. O cenário foi remontado
  com troca de chave num pump só, que é a única ordem em que a posse morta chega
  depois de existir um dono novo.
* **H33** varria `.visao` no arquivo inteiro. `lobby_online.dart` é a tela do
  online **completa** e lê `srv.visao` para desenhar a mesa — retrato legítimo. A
  varredura foi reduzida aos três métodos do efeito (`_drenar`, `_apresentar`,
  `_ligarAoEncerramento`), que não a tocam.

---

## 8. Provas por defeito injetado

Worktree descartável, na candidata. Cada rodada: restaura, injeta, **confere pelo
`git diff --numstat` que a injeção pegou**, roda a suíte, restaura, confere que
`app/lib` voltou limpo. Toda rodada terminou com a árvore limpa.

| # | Defeito injetado | Casos derrubados |
|---|---|---|
| M01 | consumo no recebimento (`registrar` já marca apresentado) | 27 casos — H01,02,04,05,07–20,21–27,29,30 |
| M02 | descarte quando não há listener | H01, H02, H07, H09, H30 |
| M03 | confirmação no agendamento do quadro | H07, H12–H20, H23, H26 |
| M04 | ausência de liberação na recusa | H07, H12, H13, H19, H26 |
| M05 | `confirmar` sem conferência de posse | **H21** |
| M06 | modo legado fora do livro (sem pendência) | H08, H09, H10, H11 |
| M07 | assinatura dentro de `build` | 23 casos, incl. **H29 e H31** |
| M08 | encerramento inferido da visão | 23 casos, incl. **H33** |
| M09 | `catch` do apresentador neutralizado | H16, H17, H18 |
| M10 | **ordem trocada: relatar antes de liberar** | **H18** — e só H18 |
| M11 | confirmação mesmo após exceção | H16, H17, H18 |
| M12 | remoção da drenagem na reentrada | H02, H09, H12–H20, H30 |

**12 de 12 detectados.** Nenhum sobreviveu.

Duas notas de método, porque o contrário me faria assinar uma cobertura que não
existe. Cinco injeções multilinha não pegaram na primeira passada — os arquivos
são **CRLF** e os padrões usavam `\n`. Outras duas não pegaram na segunda — o
delimitador `s///` colidia com o `//` do comentário-âncora. Nos dois casos o
sintoma era "mutação não detectada", e nos dois casos a causa era o script. Foi
por isso que o roteiro passou a exigir prova de que a injeção pegou (`numstat`
não vazio) antes de creditar qualquer resultado; sem essa conferência, M10 teria
sido reportada como sobrevivente — que é exatamente o falso PASS que esta seção
existe para não produzir.

---

## 9. Baterias e regressão

Mesmo toolchain nos três worktrees. Sem `analysis_options.yaml` em `app/`, o
analyzer roda com o conjunto padrão — os 38 não vêm do `flutter_lints`.

| | `flutter analyze` | `test/casca` | suíte completa |
|---|---|---|---|
| Base `8bd9661` | 38 (28 info + 10 warning), **0 erros** | **218** verdes | **571** verdes + 4 falhas ambientais |
| Candidata `e7bc236` | 38, 0 erros | **255** verdes | **608** verdes + as mesmas 4 |
| Candidata + esta homologação | 38, 0 erros | **288** verdes | **641** verdes + as mesmas 4 |

Os números da OS (38 / 255 / 608) **reproduzem exatamente**, medidos na candidata
sozinha, sem a suíte do laudo. Os acréscimos são os 33 casos independentes:
255 + 33 = 288 e 608 + 33 = 641.

**Analyzer: lista normalizada idêntica.** Diagnósticos sem linha e coluna,
ordenados: `diff` entre base e candidata (com a suíte nova) é **vazio**. Zero
diagnóstico novo — a suíte independente não introduz nenhum. Normalizar importa:
editar um arquivo acima desloca o diagnóstico e inventa um "novo" e um "perdido".

**As 4 falhas são as preexistentes e ambientais**, idênticas nos três worktrees:
`test/colecoes/evidencias_visuais_test.dart`,
`test/colecoes/kit_pioneiros_test.dart`, `test/torneios/motor_torneios_test.dart`
e `test/torneios/reward_grants_test.dart` — todas por `Cannot open file` em
`test/colecoes/data/catalogo.seed.json` e
`test/torneios/data/assets_registry.seed.json`, que só resolvem sob o overlay do
CI. Não têm relação com esta entrega.

**Nenhum teste existente foi removido, alterado, pulado ou neutralizado.** A
única diferença entre a candidata e a branch do laudo em `app/test/` é o arquivo
novo.

---

## 10. Riscos residuais

1. **Reentrada por troca de chave não redrena no mesmo quadro** (observado em
   H20). Se um `State` novo nascer no mesmo lugar da árvore **antes** de o
   anterior ser descartado, o vínculo novo encontra o efeito ainda
   `reivindicado`, não o toma, e depois nada o cutuca — o aviso fica `pendente`
   com consumidor montado até a próxima entrada legítima. **Não é rota de
   produção**: o roteamento do aplicativo não substitui esse `State` no lugar;
   nas idas e voltas reais o `dispose` cai num quadro anterior ao da montagem
   seguinte, e H14/H30 mostram a drenagem funcionando. Fica registrado porque uma
   mudança futura de navegação pode criar a ordem.
2. **A exceção do relato escapa para um futuro não aguardado.** Quando o
   `FlutterError.onError` da aplicação estoura, a exceção sobe por um
   `addPostFrameCallback` cujo retorno é descartado e chega ao zone raiz. O aviso
   **não** se perde (a devolução já aconteceu — é o que H18 prova), mas o
   segundo estouro fica sem dono. É o `onError` da aplicação que teria de não
   estourar; nada em `app/lib/` pode consertá-lo daqui.
3. **Recusa não retenta no lugar.** `recusado`/`cancelado` devolvem o efeito e
   retornam; a recuperação depende de nova reentrada, e um reenvio do mesmo
   `eventoId` não cutuca. Em produção `DialogoDeEncerramento` só recusa quando
   não há `Navigator` raiz — isto é, quando a rota já morreu —, então a reentrada
   é o evento natural seguinte. Sem defeito, e coerente com "adiado, não
   perdido".
4. **Dois encerramentos distintos na mesma janela empilham dois diálogos**
   (H25). O código declara o caso como raro e possível, e a OS pede apenas
   independência — que se verifica. Fica anotado como decisão de produto, não
   como defeito.
5. **Divergência de caminhos na OS** (seção 2): quatro dos oito arquivos estão
   listados sob `app/lib/casca/mesa_online/` e vivem em `app/lib/services/`. Vale
   o Git.
6. **"Livro por processo"** (seção 4): o contrato entregue é por mesa/transporte,
   e é o mais restritivo dos dois. A redação da OS é que está larga.

---

## 11. Publicação

* Branch: `homologacao/encerramento-ui-pendente-ack-v1`, nascida exatamente de
  `e7bc236f00fa98b79f19c371999ef7745f94211c`.
* Dois commits separados: primeiro os testes independentes, depois este laudo.
* Push normal, sem `--force`. Sem PR, merge, deploy ou alteração no servidor.
* Nada de `app/lib/` foi tocado. Nada de servidor, Functions, Rules, protocolo,
  assets, `main.dart` ou dependências foi tocado.

Esta homologação **não** compõe a candidata com Perfil, Ranking, avatar ou CI.
