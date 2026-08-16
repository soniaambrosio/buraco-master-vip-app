# Autoridade e concessão da `primeira_batida_real` — V1

Etapa 1 de 2. Esta entrega produz a **evidência autoritativa** de quem bateu, e
**concede** a conquista uma única vez, pelo backend, com timestamp do servidor e
escrita fechada ao cliente.

O Perfil **não foi tocado**: a seção "Última Conquista", a leitura real e a
remoção do mock são a OS seguinte.

- Branch: `claude/autoridade-conquista-primeira-batida-real-v1`
- Base: `origin/feat/economia-boas-vindas-vitorias` @ `42928c30aa0cf9d38aa7c74a84ca4897b22d14ab`
- Evidência de execução: `docs/CONQUISTA-PRIMEIRA-BATIDA-REAL-EVIDENCIA-V1.md`

---

## 1. A autoridade que já existia, e o que faltava nela

`registrarEncerramentoPartida` (`functions/src/rastreabilidade.ts`) é a **única
porta** de escrita de `matches`: exige o claim `motorDePartidas` ou `admin`, e o
`firestore.rules` nega toda escrita do cliente. Ela já provava quatro dos cinco
fatos que a conquista precisa:

| Fato | Onde já estava |
|---|---|
| partida encerrada autoritativamente | `RegistroDePartida.estado` + `motivoEncerramento`, sob claim |
| dupla vencedora | `ladoVencedor` + `placar[].assentos` |
| identidade autenticada | `ParticipantePartida.userId` + `ClasseDeParticipante.humano` |
| partida válida / não simulada | `IdentidadePartida.origem` + `TipoDePartida` |
| **executor individual da batida** | **faltava** |
| **legalidade da batida** | **faltava explicitamente** |

O quinto fato não estava perdido — estava sendo **descartado**. `Jogo` grava
`assentoQueBateu` na mesma atribuição que `duplaQueBateu`, e `capturarDesfecho`
copiava só a dupla.

## 2. O que foi estendido

Um contrato só, o que já existia. Nenhuma autoridade paralela foi criada.

```
Jogo.assentoQueBateu                             (já existia)
   └─> DesfechoCanonicoPartida
         .assentoQueBateuUltimaRodada            (NOVO, aditivo, nulável)
         └─> RegistroDePartida.assentoQueBateuFinal   (NOVO)
               └─> matches/{matchId}             (mesma transação de sempre)
```

**A legalidade vem junto, e não como um segundo campo.** `Jogo` só preenche o
assento depois de aprovar a batida por `duplaPodeBater` — que exige canastra
(limpa no Aberto/STBL, qualquer uma no Fechado) — e depois de esgotado o morto da
dupla. Rodadas que acabam sem batida legal (baralho esgotado, monte e mortos
vazios) deixam o campo nulo. Logo `assentoQueBateuFinal != null` é, por
construção, "houve batida válida, e foi deste assento". Um booleano `batidaLegal`
separado seria um segundo lugar onde a verdade poderia divergir.

**Coerência validada na construção:** assento em 0..3, dupla obrigatória quando
há assento, e o assento tem de pertencer ao lado declarado. Creditar a batida a
alguém do lado adversário é a incoerência mais cara possível aqui, e não há como
saber qual dos dois campos estaria errado — então recusa.

## 3. A regra, e onde ela mora

`app/lib/conquistas/primeira_batida_real.dart`. **Uma** implementação, em Dart,
alcançada pelas Functions através de `dart compile js` — a mesma disciplina que
`functions/src/domain.ts` já declarava para o Motor de Torneios. Não existe um
`if` de elegibilidade em TypeScript.

Concede quando **todos** valem:

1. `estado == finalizada`;
2. `motivoEncerramento == meta_atingida`;
3. lado vencedor declarado;
4. `identidade.origem != local`;
5. `tipo` ∈ {`publica_casual`, `publica_ranqueada`, `privada`, `torneio`};
6. assento da batida final conhecido;
7. esse assento pertence ao lado vencedor;
8. o assento tem exatamente um ocupante;
9. o ocupante é `humano`;
10. com `userId` não vazio.

`encerrada_por_admin` também produz `finalizada` — por isso o motivo é conferido
à parte. É o caso que passaria batido numa regra que olhasse só o estado.

**Fail-closed em toda ausência.** Campo que não veio é "não sei", e "não sei"
nunca concede. Um envelope de produtor antigo, sem o assento, recusa igual a uma
partida que acabou sem batida. Por isso a leitura do assento não usa o helper
`inteiro(campo, padrao)` do registro: ali ausente e zero virariam a mesma coisa,
e zero é um assento real.

### Decisões de política que ficam registradas

- **`privada` conta.** É gente de verdade jogando de verdade, e não está em
  nenhuma exclusão da OS. Registrado para revisão: ela é combinável (o dono
  escolhe os adversários), e por isso não pontua ranking. Para uma conquista
  concedida uma vez na vida, o custo disso é um marco antecipado, não vantagem
  acumulável.
- **`treinamento` e `contra_robos` não contam.** São, por definição, mesa de
  prática.
- **Tipo novo não entra sozinho.** A lista é fechada e positiva, no espírito de
  `TipoDePartida.alteraRanking`.
- **A unidade é o jogador, nunca a dupla.** A função devolve **um** uid, o do
  assento que bateu. Não existe caminho que devolva dois.

## 4. Persistência

```
playerAchievements/{uid}/items/primeira_batida_real
```

| Campo | Valor |
|---|---|
| `id` | `primeira_batida_real` |
| `obtidaEm` | `FieldValue.serverTimestamp()` |
| `partidaId` | matchId imutável da partida que concedeu |
| `origem` | `encerramento_autoritativo_v1` |
| `versaoContrato` | `1` |
| `assento` | assento do executor — prova para auditoria futura |

Sem título, sem descrição, sem arte: texto visual pertence ao catálogo do
cliente. A persistência guarda identidade, origem e momento.

## 5. Idempotência

**O id do documento é constante por jogador.** Não há chave derivada de partida,
tentativa ou relógio — e isso é o mecanismo, não um detalhe: a conquista é "a
PRIMEIRA vez", e um id que variasse por partida deixaria a segunda vitória
conceder de novo.

Dentro da transação do encerramento:

1. lê o registro da partida;
2. pede o veredito ao domínio;
3. lê o documento da conquista — **última leitura**;
4. todas as escritas, incluindo `create` da conquista.

A ordem não é estética: o Firestore exige toda leitura antes de qualquer escrita,
e misturar as fases falha só em execução.

`create`, e não `set`: duas transações que passem juntas pela leitura fazem a
segunda falhar no commit, o Firestore reexecuta, e a segunda passada vê o
documento e devolve `ja_existente`. Com `set`, a segunda venceria e reescreveria
`obtidaEm` — trocando a data do marco pela data do reprocessamento.

O caminho de **reenvio** também avalia. Converge para o mesmo estado final e
repara concessão perdida, sem nunca duplicar.

**Envelope ilegível não derruba o encerramento.** Vira recusa no log. Perder o
registro da partida por causa de uma conquista seria trocar o dado importante
pelo acessório.

## 6. Segurança

`firebase/firestore.rules`, bloco `playerAchievements`:

- leitura: dono e admin, por `get` e por `list`;
- escrita: **negada a todos** pelo cliente, inclusive dono e admin.

`update` e `delete` negados não é excesso. `obtidaEm` é a data do marco: quem
pudesse editar antedataria a própria conquista, e quem pudesse apagar zeraria o
documento para ganhar de novo — que é exatamente o que o id fixo existe para
impedir.

Sem `list` de terceiro: a coleção de um jogador não é varrível por outro.
`publicProfiles` não foi tocada.

## 7. Fronteira de confiança

O cliente **não escolhe** vencedor, executor, legalidade, tipo de encerramento
nem elegibilidade. Não há sequer um caminho em que ele fale com esta função: ela
exige o claim `motorDePartidas`/`admin`, que um aparelho não tem.

O que o cliente pode fazer é **ler a própria conquista**. Nada mais.

A fronteira, dita de outro jeito: tudo que decide vem de `matches/{matchId}`, que
só a autoridade escreve; e tudo que a autoridade escreve sobre a batida vem de
`Jogo`, que é quem aprova a jogada.

## 8. Observabilidade

Um log próprio, filtrável, com `matchId`, `conquista`, `versaoContrato`,
`resultado` (`concedida` | `ja_existente` | `inelegivel`) e `motivo` — o código
estável da recusa.

Sem uid, apelido, e-mail, token ou carta. O `matchId` já identifica a partida na
linha anterior, e o motivo em código é o que responde "por que fulano não
recebeu?" sem reabrir a partida.

## 9. C10 — por que não entrou

`origin/claude/buraco-c10-parte-2-5eb70e` (`a600b4e`) **não é ancestral** da base
(`git merge-base --is-ancestor` → falso; ancestral comum em `27b3f36`). Foi
examinada, como a OS §3 manda, e **não contém a autoridade necessária** — que é a
condição da §6 para integrar:

- C10 tem **zero** arquivos em `functions/` e **zero** de rastreabilidade;
- a base tem **205 arquivos que C10 não tem**, incluindo toda a cadeia de
  encerramento autoritativo, Rules, economia, moderação e billing;
- o fato que a conquista precisa do motor — `Jogo.assentoQueBateu` — existe
  **nas duas**, e C10 o preserva (`autoridade_canonica.dart`).

C10 é a autoridade do motor **local** (`MotorConfig.producao()` para partida no
aparelho), e partida local é justamente o caminho que **nunca** concede
(`origem == local` → `partida_nao_autoritativa`).

Mesclá-la significaria trazer 66 commits de divergência, com `mesa.dart` em
+1285/−244 sobre um ramo que nunca viu o backend — exigindo escolher, arquivo a
arquivo, entre duas linhagens de motor, sem que nada disso mudasse uma linha do
que esta OS entrega. A §6 proíbe resolver isso em massa; e a §6 também condiciona
a integração a "conter a autoridade necessária", que não é o caso.

**Fica registrado como decisão, não como esquecimento.** Se um dia o motor local
passar a produzir encerramento autoritativo, C10 volta a ser relevante para a
conquista — e aí a integração é uma OS própria.

## 10. O que a próxima OS precisa saber

1. A conquista já existe no banco, e a leitura pelo cliente já está liberada
   (`playerAchievements/{uid}/items/`). Falta o `ConquistasService` no Flutter.
2. `UltimaConquista` e `Conquista` (em `perfil_screen.dart`, na linhagem do
   Perfil) **não têm `obtidaEm`**. Sem esse campo, "a mais recente por timestamp
   do servidor" não é expressável.
3. O Perfil hoje exibe **"Primeira Batida Real" como mock**, para todo mundo, em
   `perfil_service.dart`. Trocar isso é trabalho da OS seguinte, junto com ligar
   a fonte — apagar antes deixaria a seção morta.
4. **Nada retroativo.** Ninguém tem a conquista hoje: ela passa a ser concedida
   nos encerramentos daqui para frente, e em reenvios de encerramentos passados
   cujo envelope traga o assento. Envelopes antigos não trazem, e recusam.
5. **O produtor do envelope precisa passar a enviar o campo.** O plano chega de
   fora deste repositório (o servidor Node/Railway). Enquanto ele não incluir
   `assentoQueBateuFinal`, toda avaliação recusa com `sem_batida_final_conhecida`
   — corretamente, e sem conceder nada errado.
