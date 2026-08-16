# Moderação, denúncia, bloqueio e proteção social

Camada de segurança social do Buraco Master VIP: denúncia de jogadores, mensagens
e partidas; bloqueio; silêncio pessoal; sanções administrativas; e o recorte que
impede um espectador de receber carta que não pode ver.

Este documento descreve **o que existe**. O que ficou decidido pelo produto, e
não por esta entrega, está na seção 6.

---

## 1. Onde cada coisa mora

| Camada | Caminho | O que faz |
|---|---|---|
| Decisão (domínio) | `app/lib/moderacao/` | O que é denúncia válida, auto-bloqueio, quando uma sanção expira. Dart puro, sem Firebase. |
| Ponte | `app/lib/moderacao/js_bridge.dart` | Compila o domínio para JS (`dart compile js`) para o Node executar a MESMA regra. |
| Execução | `functions-moderacao/src/` | Autenticação, transação, leitura e escrita. TypeScript `strict`. |
| Autorização | `firebase/firestore.rules` (Bloco 4/4) | Quem lê e quem escreve cada coleção. |
| Privacidade da partida | `app/lib/motor/visao_espectador.dart` | Recorte público do estado, para quem assiste. |

A repartição é a mesma do motor de torneios: **quem decide é o Dart, quem executa
é o TypeScript**. Um `if` de política de moderação em `.ts` está no lugar errado.

Por que o domínio não foi reescrito em TypeScript: seriam duas implementações das
mesmas regras, e elas divergiriam no primeiro dia em que alguém apertasse um
limite só de um lado — com o agravante de que, aqui, a versão frouxa é a porta de
abuso.

---

## 2. Modelo de dados

### 2.1 Denúncia — dois documentos, de propósito

As regras do Firestore liberam ou negam o **documento inteiro**: não existe
"pode ler estes quatro campos". Projetar campo a campo só é possível gravando
dois documentos, e é o que a Function faz numa transação.

**`reports/{reportId}`** — registro administrativo. Leitura: **só admin**.

```
reportId, denuncianteUid, denunciadoUid, tipo, categoria, comentario,
matchId, roomId, messageId, evidencia{}, status, origem, createdAt, esquema
```

`reportId` = `${denuncianteUid}|${reportIntentId}` — determinista, calculado pelo
domínio, e é o **id do documento**.

**`users/{uid}/reportReceipts/{reportId}`** — comprovante. Leitura: **só o dono**.

```
protocolo, tipo, categoria, status (genérico), criadoEm, esquema
```

Não tem `denunciadoUid`, comentário, evidência nem status interno — porque a
Function não os grava aqui.

**Tipos e categorias** (`denuncia.dart`): `perfil`, `mensagem`, `partida`. As
categorias são enumeradas e **validadas por tipo** — `insulto` numa denúncia de
partida é recusado. Categoria livre não se agrega, não se prioriza e não se
compara entre denúncias, e a triagem depende exatamente disso.

**Status**: interno (`recebida`, `emAnalise`, `procedente`, `improcedente`,
`arquivada`) × público (`emAnalise`, `concluida`). O denunciante vê só o público:
dizer "improcedente" a quem denunciou expõe o resultado da investigação e convida
a testar de novo com outra redação.

### 2.2 Bloqueio e silêncio pessoal

| Coleção | Escrita | Leitura |
|---|---|---|
| `users/{uid}/blocks/{alvoUid}` | só Cloud Function | dono, admin |
| `users/{uid}/mutes/{alvoUid}` | **o próprio cliente**, sob regra estrita | dono, admin |

A assimetria é deliberada:

- **Bloqueio** afeta o que OUTRA pessoa consegue fazer, e tem teto
  (`kLimiteBloqueios = 500`). Regra do Firestore não conta documentos de uma
  coleção — sem a Function, o teto simplesmente não existiria.
- **Mute** é preferência de exibição: não afeta ninguém além de quem configurou,
  não tem teto a contar. Gastar uma Cloud Function em cada toque seria custo sem
  ganho de segurança. A regra ainda garante dono, forma fixa (`apenasCampos`),
  `alvoUid` batendo com o id do documento, e recusa de auto-mute comparando os
  dois parâmetros do caminho.

**O bloqueio é unilateral no registro.** `A bloqueia B` não cria `B bloqueia A`;
são dois documentos independentes. O que *não* é unilateral é o efeito — ver 3.3.

### 2.3 Sanção — infraestrutura, não política

| Coleção | Conteúdo | Leitura |
|---|---|---|
| `sanctions/{sancaoId}` | histórico completo: tipo, motivo, responsável, prazo, denúncia de origem | só admin |
| `playerModeration/{uid}` | efeito consolidado vigente | **o próprio** e admin |

Tipos: `advertencia`, `muteTemporario`, `restricaoSocial`, `suspensaoTemporaria`,
`suspensaoPermanente`.

`playerModeration/{uid}` é legível pelo próprio para que a tela possa dizer "você
está silenciado até tal hora" em vez de falhar sem explicação — e é **ilegível
por terceiros**, o que fecha a enumeração de quem está suspenso.

Escrita fechada para todos, inclusive o dono: é o ponto exato onde morre a
tentativa de apagar a própria punicão.

Revogar **não apaga**: marca `status: revogada`. Apagar deixaria a trilha
contando uma história que não aconteceu.

### 2.4 Trilha e idempotência

`moderationAudit/{eventoId}` e `moderationTasks/{chave}` — leitura só admin,
escrita de ninguém pelo cliente. Nem o admin apaga a trilha que ele mesmo gerou.

A auditoria **nunca** guarda o conteúdo denunciado nem o comentário: só quem fez
o quê, sobre quem, e quando.

---

## 3. Fluxos

### 3.1 Criação de denúncia

```
cliente → registrarDenuncia(denunciadoUid, tipo, categoria, reportIntentId, …)
  1. exigirAutenticacao        → uid vem de req.auth, NUNCA do payload
  2. count() das denúncias do mesmo uid na última hora
  3. dominio.avaliarDenuncia() → veredito + chave determinista
  4. executarUmaVez(chave)     → transação:
       create reports/{chave}
       create users/{uid}/reportReceipts/{chave}
       create moderationAudit/{auto}
  5. devolve { registrada, protocolo, jaRegistrada }
```

**Retry não é erro.** A segunda chamada devolve sucesso com `jaRegistrada: true`.
Devolver erro faria o cliente tentar de novo, e a próxima também "falharia" — um
laço que só termina quando o jogador desiste.

### 3.2 Bloqueio e desbloqueio

`bloquearJogador` usa `set(..., {merge: true})` com o UID bloqueado como id do
documento: bloquear duas vezes converge no mesmo estado em vez de falhar.

`desbloquearJogador` apaga sem consultar antes — de propósito. Responder
diferente para "existia" e "não existia" contaria ao chamador se aquele UID já
fora bloqueado.

### 3.3 Consulta server-side de contato

`consultarContato(alvoUid)` é a **porta única** das rotas sociais. Faz três
leituras diretas por id (sem varredura, sem índice):

```
users/{origem}/blocks/{alvo}     → origem bloqueou destino?
users/{alvo}/blocks/{origem}     → destino bloqueou origem?
playerModeration/{origem}        → sanção vigente sobre quem fala?
```

e devolve `{permitido, motivo}`. Existe **antes** das rotas sociais para que elas
nasçam perguntando, em vez de serem corrigidas depois.

O efeito é simétrico ainda que o registro seja unilateral: se qualquer um dos
dois bloqueou, o contato é recusado nos dois sentidos. Recusar também a direção
"quem bloqueou fala com o bloqueado" é decisão deste projeto, não exigência da
OS — sem ela, bloquear alguém viraria uma forma de falar sem poder ouvir a
resposta.

### 3.4 Proteção do espectador

`VisaoEspectador.de(jogo)` devolve **o que está na mesa** (lixo, jogos baixados,
placar, de quem é a vez) e **apenas a contagem** do que está oculto (mãos, monte,
mortos).

Não é um parâmetro de `VisaoAssento`, e sim um arquivo próprio, porque o mapa é
uma **lista de permissão escrita à mão**: um campo secreto novo acrescentado ao
assento não vaza para cá por descuido — ele simplesmente não existe lá. Num
builder compartilhado com um `if espectador`, o padrão se inverteria: o campo
novo nasceria visível e alguém teria que lembrar de escondê-lo.

A prova não é a leitura do arquivo: é `VisaoAssento.vazamentos`, que parte dos
**ids secretos** e varre todo valor de texto da estrutura, sob qualquer chave e
em qualquer profundidade. Sem allowlist de campos, que envelheceria em silêncio.

---

## 4. Segurança

### 4.1 Quem lê o quê

| Coleção | Dono | Terceiro | Admin |
|---|---|---|---|
| `reports` | ✗ | ✗ | ✓ |
| `users/{uid}/reportReceipts` | ✓ | ✗ | ✓ |
| `users/{uid}/blocks` | ✓ | ✗ | ✓ |
| `users/{uid}/mutes` | ✓ | ✗ | ✓ |
| `playerModeration/{uid}` | ✓ | ✗ | ✓ |
| `sanctions` | ✗ | ✗ | ✓ |
| `moderationAudit`, `moderationTasks` | ✗ | ✗ | ✓ |

Nenhuma coleção de moderação tem `allow read: if autenticado()`. Nos outros três
blocos do arquivo de regras, negar escrita basta — ninguém se prejudica por ler o
catálogo de torneios. **Aqui, ler a denúncia errada revela quem denunciou quem, e
isso é o dano.**

### 4.2 Campos que só o servidor escreve

`createdAt`, `denuncianteUid`, `status`, `reportId`, todo o documento de
`sanctions` e de `playerModeration`, e a lista de `blocks`.

O UID do denunciante **nunca** é lido do payload. Provado em
`firebase/testes/moderacao.test.js`: uma chamada que envia `denuncianteUid` de
terceiro grava sob o UID autenticado, e nada aparece sob o UID do payload.

### 4.3 Como a identidade do denunciante é protegida

Quatro camadas, e a primeira já bastaria:

1. `reports` é `allow read: if ehAdmin()` — o denunciado não tem caminho até o
   documento que contém `denuncianteUid`.
2. O comprovante que o denunciante lê é **outro documento**, e não carrega o
   denunciado.
3. O status devolvido ao denunciante é o genérico.
4. A auditoria, que liga ator a alvo, também é só de admin.

### 4.4 Anti-enumeração

- `consultarContato` com UID inexistente responde `permitido: true`, igual a um
  UID válido sem bloqueio.
- `desbloquearJogador` não distingue "existia" de "não existia".
- `playerModeration` de terceiro é negado — não dá para varrer quem está suspenso.
- Recusas do domínio usam códigos sobre **o pedido**, nunca sobre o alvo.

### 4.5 Abuso e concorrência

- **Idempotência**: id de documento determinista + `create` dentro de transação.
  Cinco chamadas simultâneas deixam um registro (teste no emulador).
- **Freio**: 20 denúncias por hora por denunciante, por consulta `count()`
  indexada. Pedido malformado é recusado **antes** do freio, para que não dê para
  queimar a cota de alguém mandando lixo em nome dele.
- **Instante congelado**: a Function captura `agora` uma vez e passa adiante. O
  domínio recusa data sem fuso. Sem isso, uma sanção poderia estar vigente na
  primeira checagem e expirada na segunda, dentro da mesma operação.

### 4.6 Riscos conhecidos

1. **Evidência de mensagem é atestada pelo cliente.** Não existe chat
   servidor-lado neste projeto — o backend de partida é um servidor Node externo
   (Railway), fora deste repositório. Enquanto o conteúdo da mensagem só existir
   no aparelho, o registro grava `evidencia.origem = "cliente_atestada"`. Quando
   o chat passar a ser servidor-lado, a Function preenche a mesma estrutura com
   `origem: "servidor"` e o campo atestado deixa de ser aceito.

2. **O recorte de espectador não está ligado a nenhum servidor.**
   `VisaoEspectador` é a definição correta do payload, e está provada; mas quem
   serve estado de partida é o servidor externo. **Enquanto ele não consumir este
   recorte, não existe espectador em produção — e é assim que deve ficar até
   existir.** Ver seção 5.

3. **App Check é dispensado sob o emulador** (`FUNCTIONS_EMULATOR !== "true"`).
   A variável é posta pelo próprio emulador e nunca vale `true` numa instância
   implantada; nada no pedido do cliente a influencia.

4. **`admin` é custom claim, e nada neste repositório o atribui.** Continua
   valendo o que o mapa do Firebase já registrava: o claim é emitido fora daqui.

---

## 5. Dependência: o servidor de partidas

A seção 13 da OS pede provas de que o espectador não obtém estado privado
"chamando diretamente endpoint/function". **Essas três provas não podem ser
fechadas neste repositório**, porque o endpoint de estado de partida não está
aqui: é `servidor/servidor.js`, hospedado no Railway.

O que foi entregue é a metade que cabe a este repositório:

- o recorte correto (`VisaoEspectador`), com a definição de segredo
  (`VisaoEspectador.segredos`) que o servidor precisa consultar;
- a prova de que esse recorte não vaza, por varredura estrutural.

O que falta, e **onde falta**: o servidor externo precisa passar a montar o
payload de espectador por esta definição, em vez de reaproveitar a visão de
assento. Menor decisão necessária para prosseguir: abrir a OS do servidor de
partidas com este arquivo como contrato.

---

## 6. Decisões de produto propositalmente não implementadas

A OS proíbe inventar política disciplinar sem especificação. Ficaram de fora, e
a infraestrutura está pronta para receber cada uma:

1. **Progressão disciplinar.** Quantas denúncias procedentes levam a qual sanção,
   e por quanto tempo. Hoje toda sanção é aplicada por decisão administrativa
   explícita.
2. **Bloqueado e bloqueador na mesma mesa pública.** A OS diz explicitamente que
   é decisão de matchmaking e está fora de escopo. Esta camada bloqueia
   **contato social**, e registra a relação para quem for decidir. Duas pessoas
   que se bloquearam **podem** cair na mesma partida pública.
3. **Triagem.** Quem move `status` de `recebida` para `procedente`, com que
   ferramenta, e em que fila. A coleção e os índices existem; a ferramenta
   administrativa não.
4. **Retenção.** Por quanto tempo denúncia e evidência ficam guardadas.
5. **Recurso.** Não há fluxo de contestação de sanção.

---

## 7. Como rodar as provas

Domínio e espectador (sem emulador):

```bash
cd app && flutter test test/moderacao/teste_moderacao.dart test/motor/teste_visao_espectador.dart
```

Só as **regras** (Emulator Suite; exige Java 11+). Os dois blocos de Function
saem como `# SKIP` aqui, de propósito — este alvo não sobe Functions:

```bash
cd firebase/testes && npm install && npm run emulador
```

Regras **e** as chamadas reais às Cloud Functions — compila o domínio Dart e o
TypeScript, sobe `firestore,auth,functions:moderacao` e roda os 45 casos:

```bash
cd firebase/testes && npm run emulador:moderacao
```

Numa máquina sem Java no PATH mas com Android Studio, o `java` precisa estar no
PATH (o Firebase CLI não lê `JAVA_HOME` para escolher o binário):

```bash
PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH" npm run emulador:moderacao
```

### Por que `emulador:moderacao` existe

`emulators:exec` exporta `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`
e `GCLOUD_PROJECT` — e **nada** para Functions. Como os dois blocos de callable
são guardados por `skip: !process.env.FUNCTIONS_EMULATOR_HOST`, subir o emulador
pela via normal os pulava em silêncio: o resumo dizia `fail 0` e nenhuma chamada
tinha sido feita. Foi assim desde a entrega da OS de Moderação.

Quem fecha o buraco é `firebase/testes/com-functions.js`: ele confere que a porta
5001 atende, **falha** se não atender — em vez de pular — e só então exporta a
variável. O mesmo runner serve a suíte social, via `--codebase=<nome>`.

### No CI, Moderação é gate bloqueante

O portão `.github/workflows/ci-os-integracao.yml` protege **três** suítes Firebase
com Emulator Suite, cada uma em passo próprio, sequenciais e bloqueantes:

| Passo | Suíte | Gate | Comando | Piso |
|---|---|---|---|---|
| 3d | **Social** | `socialemu` | `emulators:exec … npm run test:social:functions` | 67 |
| 3e | **Moderação** | `moderacaoemu` | `cd firebase/testes && npm run emulador:moderacao` | 45 |
| 3f | **Coleções** | `colecoesemu` | `emulators:exec … npm test` | — |

Até a OS *Gate de Moderação no CI*, o passo de Moderação não existia. A suíte
`moderacao.test.js` já rodava dentro do gate de Coleções (então chamado `regras`,
hoje `colecoesemu`), mas
**sem** o emulador de Functions: lá os dois `describe` de callable saem `# SKIP`
de propósito, porque aquele alvo prova regras. Na prática, `registrarDenuncia` e
`bloquearJogador` nunca tinham sido *chamados* no CI, e a única rede contra uma
regressão era alguém lembrar de rodar a suíte na própria máquina.

O passo 3e chama o **wrapper** `emulador:moderacao`, e não o alvo interno como faz
o passo social, porque o wrapper é autocontido — instala, compila `build:domain` e
`build`, confere os artefatos, o Java, as portas e o dreno — e classifica o
desfecho em exit codes distintos (`0` OK, `1` falha funcional, `3`/`4`
infraestrutura, `5` suíte incompleta, `6` cleanup incompleto). Qualquer valor
diferente de zero reprova o job; o que a classe muda é para onde quem lê o log vai
olhar. Repetir o build no YAML criaria uma segunda receita do mesmo bundle.

Sequenciais, e não paralelos: as três disputam as mesmas portas e o mesmo
`projectId demo-bmv`.

Os três gates não usam `continue-on-error`. E, desde a OS *CI fail-closed dos
gates de emulador*, eles são **fail-closed**: o portão só fica verde se cada um
dos três tiver deixado recibo válido de sucesso.

| Situação do gate obrigatório | Portão |
|---|---|
| recibo com `0` | verde |
| recibo com `1`, `3`, `4`, `5` ou `6` | vermelho — `FALHOU (exit N)` |
| recibo vazio, ou com algo que não é exit code | vermelho — `RESULTADO INVÁLIDO` |
| passo pulado por condição, ou que nem começou | vermelho — `NÃO EXECUTADO` |
| passo que começou e morreu antes de registrar | vermelho — `NÃO EXECUTADO`, com a distinção impressa |
| job **cancelado** | o portão é pulado (`if: !cancelled()`); o job sai CANCELADO, não vermelho |

A distinção entre "nem começou" e "começou e morreu" vem da marca `inicio_<gate>`,
que cada passo obrigatório escreve antes de qualquer coisa que possa falhar. As
duas reprovam; o que muda é o diagnóstico.

A política antiga — `NÃO EXECUTADO` reporta e não reprova — continua valendo para
os demais gates (analyze, suítes Flutter, typechecks), de propósito.

Duas coisas que a primeira execução de verdade revelou, já corrigidas:

1. **`CONCORRENCIA` não provava nada.** A asserção filtrava `reports` por id de
   documento e conferia que sobrava um — o que é verdade por construção, já que
   id é único. Agora conta a trilha em `moderationAudit`, que tem id automático e
   é o único artefato que denunciaria o corpo da transação executado duas vezes.
2. **A direção que a §8 exige não era testada.** O caso chamado "o contato do
   bloqueado com o bloqueador" media a direção oposta (`bloqueouODestino`, que é
   decisão deste projeto, não exigência da OS). O caso de `bloqueadoPeloDestino`
   foi acrescentado.

Rodar dois `emulador:*` em sequência exige esperar o anterior liberar as portas
5001/8080/9099; encavalar faz o segundo run morrer com `port taken` ou responder
`functions/not-found` em toda chamada.
