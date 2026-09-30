# Fundação canônica da base P para Torneios VIP V1

    Branch : integracao/base-p-torneios-vip-fundacao-v1
    Base   : 21ddf47b6320c1e5ddf1c64659d928b68c1f0889  (integracao/perfil-social-funcional-raiz-p-v1)
    Raiz P : 5aa8263469d5abbf19f40e4fd0b35e20560c3944  (integracao/os32-fonte-unica-gates-p-v1)
    Gate   : torneiobase
    Sem PR, sem merge, sem deploy, sem promoção automática a raiz.

Esta OS **não** implementa orquestração, produtor de edições, consumidor de
`tournamentJobs`, cliente produtivo, Central de Torneios, premiação, Hall,
inscrição produtiva, check-in nem administração. Ela produz a base sobre a qual
essas OS poderão ser escritas, e fecha as portas que não podem ficar abertas
enquanto elas não existirem.

---

## 1. Gate Zero

`fetch` limpo, árvore limpa, execução fora de `main`.

| item | valor |
|---|---|
| ponta P autorizada | `21ddf47b6320c1e5ddf1c64659d928b68c1f0889` |
| local == remoto na base | sim |
| descende da raiz P | sim (`5aa8263`) |
| `99ef93a` é ancestral? | **não** — está contido em uma única ref, ela mesma |
| `21ddf47` usado como | referência de leitura no Gate Zero, e base do branch |
| branch criada | depois do Gate Zero, como o §4.4 exige |

O Gate Zero anterior — que parou por três pontas P concorrentes — foi encerrado
pela autorização que nomeou `21ddf47`. `b99f41a` e `929113b` não entram aqui.

### Seeds, classificados (§5.11 e §5.12)

| template | acesso original | V1 |
|---|---|---|
| `quarta_vulnerabilidade` | `publico` | **SUPERSEDED** → legado |
| `sexta_master_vip` | `vip` | ativo |
| `copa_buraco_master` | `vip` | ativo |
| `domingo_pintando_7` | `vip` | ativo |
| `campeonato_mensal` | `misto` | **SUPERSEDED** → legado |
| `campeonato_anual` | `vip` | ativo (cadastrado e desligado, decisão #6) |
| `encerramento_campeoes_ano` | `somente_convidados` | ativo — convite **cumulativo** ao VIP |

---

## 2. O que foi feito, e por quê

### 2.1 Saneamento dos seeds — preservar, não converter

Os dois modelos incompatíveis saíram da relação ativa e foram para
`app/data/torneios/legado/tournamentTemplates.superseded.json`, **preservados
exatamente como estavam**.

Convertê-los para `acesso: "vip"` teria sido mais curto e é o que a leitura
apressada do §2.1 sugere. Não foi feito, e a razão é que isso apagaria a
**Decisão #10** — "público joga e ganha fichas, selos e coroas, mas não pontua
no ranking" —, que é decisão de produto registrada no próprio seed. Transformar
a Quarta da Vulnerabilidade num torneio pago e exclusivo é uma decisão que
ninguém tomou; movê-la para o legado mantém as duas saídas abertas, e o §7.2
prevê exatamente esse mecanismo.

O legado está fora do carregamento produtivo por construção, e não por
convenção: o glob `app/data/torneios/*.json` — que o CI usa e que qualquer
carregador usaria — não alcança subpasta. `SEED-13` afirma isso.

`TorneioIds.superseded` continua nomeando os dois. Apagar os identificadores
faria a volta de um deles cair na mensagem genérica de "templateId não
declarado", que descreve erro de digitação. O que aconteceria não é digitação —
é uma decisão sendo desfeita —, e `SEED-14` prova que a mensagem diz isso.

### 2.2 O contrato normativo — `app/lib/torneios/contrato_v1.dart`

Um contrato, e um só. Antes havia dois vocabulários vivos: o seed falava
`vagas:{max,min}` / `entrada` / `acesso`; a Cloud Function lia
`limiteParticipantes` / `custoEntrada` / `usaCheckin`, campos que o seed nunca
teve. `validarTemplateV1` é o que o futuro produtor de edições consome; se ele
escrever a própria validação, terá criado o segundo vocabulário de novo.

Tudo falha fechado: campo ausente, tipo errado, valor desconhecido e mapa vazio
produzem violação. A função é **total** — devolve todas as violações, não para
na primeira —, pelo mesmo motivo de `avaliarElegibilidade`.

**A lacuna declarada.** Os quatro templates ativos violam o contrato em
`criadorAusente`, e `campeonato_anual` também em `capacidadeInvalida`. As duas
estão fixadas por valor em `CTR-02`. Não são defeito desta entrega: não existe
produtor seguro do claim `admin` nesta árvore, então não há identidade
administrativa para registrar como criador; e o Anual está cadastrado e
desligado, sem vagas — a mesma configuração incompleta que faz o domínio recusar
inscrição por `configuracaoPendente` (`SEED-06b`). Preenchê-las com valores
inventados seria fabricar dado, que o §8 proíbe.

### 2.3 `em_revisao` no ciclo canônico

O enum canônico tinha 12 estados e nenhum de revisão; `rascunho → agendado` era
aresta direta. Agora:

    rascunho → em_revisao → agendado

A aresta direta **foi removida do grafo**. A separação de funções mora dentro de
`avaliarTransicao`, e não numa função própria de aprovação: uma segunda porta
seria uma segunda autoridade de transição, e quem esquecesse de chamá-la
publicaria sem revisor. Aqui não há caminho para `agendado` que não passe pelo
`if`.

Três recusas novas: `criadorAusente`, `aprovadorAusente`,
`aprovadorIgualAoCriador`. O ator `jogador` continua barrado antes de tudo, e o
ator `sistema` é barrado porque nenhuma das duas arestas está em
`transicoesAutomaticas` — a automação não submete nem aprova.

A correspondência 1:1 com `ui.TorneioStatus` estava fixada por teste e fez o seu
trabalho: acrescentar o estado de um lado quebrou o portão até o outro lado
acompanhar.

### 2.4 As Rules — a porta que estava aberta

`registrations` permitia ao cliente criar a própria inscrição, e o comentário
justificava: *"a elegibilidade, a lotação e a janela são revalidadas pela
Function que reage a este documento"*.

**Essa Function nunca existiu.** Os únicos gatilhos de documento do repositório
são `aoRegistrarPartida`, `aoRegistrarResultadoOficial`, `aoBloquearJogador` e
`aoConcluirEdicao`. O efeito era completo: inscrição em torneio VIP, lotado,
fora da janela, com perfil suspenso e sem pagar ficha — e a linha contava na
lotação lida pelo `tickTorneios`.

A porta fechou (`allow write: if false`), e não "quando o revalidador existir":
uma regra que confia num consumidor ausente é uma regra que não vale. A porta
autoritativa é OS própria e não precisa deste `allow` — Cloud Function escreve
pelo Admin SDK, que não passa por Rules. A **leitura continua**: fechar a leitura
junto confundiria "não escreve" com "não existe".

---

## 3. Medições

### Flutter

| alvo | resultado |
|---|---|
| `test/torneios/fundacao_base_p_test.dart` | **56/56** (novo) |
| `test/torneios/motor_torneios_test.dart` | **179/179** — mesma contagem da base |
| `test/torneios/reward_grants_test.dart` | 80/80 |
| `test/elegibilidade/costura_p0_test.dart` | 29/29 |
| `test/integracao/teste_integracao_motores.dart` | 64/64 |
| `flutter analyze` | 50 issues, conjunto idêntico ao da base |

Os 6 `error` do analyze são pré-existentes e vivem em `tools/print_mesa.dart`,
fora de `lib/`.

### Rules, contra o emulador

| suíte | resultado |
|---|---|
| `firebase/testes/torneios.test.js` | **23/23** (novo) |
| `firebase/testes/seguranca.test.js` | 14/14 |
| `firebase/testes/entitlement.test.js` | 29/29 |
| `firebase/testes/passe.test.js` | 14/14 |

**A medição vale em NTFS, e não em exFAT.** Em `F:` o `npm install` de
`firebase/testes` produz árvore incompleta e a suíte morre em `MODULE_NOT_FOUND`
dentro de `@firebase/firestore`. A bancada foi montada em `C:`.

### Portões do próprio portão

| gate | resultado |
|---|---|
| `verificar_contrato_suites.sh` | 16 conferidos, `torneiobase` com 14 blocos |
| `portaoci` | 38/38 — VERDE |
| `contratosui` | 33 ok, 1 falha — **VERMELHO, e já era na base** |

---

## 4. `contratosui` estava vermelho antes desta entrega

Medido nos dois lados, com a mesma árvore e o mesmo comando:

| | casos ok | falhas | caso que falha |
|---|---|---|---|
| base `21ddf47` intocada | 33 | 1 | `T27 CONTROLE` |
| esta candidata | 33 | 1 | `T27 CONTROLE` |

`T27` monta um diretório de evidência completo e espera VERDE. Ele reprova
porque onze gates contratados da própria composição de `21ddf47` não recebem log
na bancada sintética:

    a11yamigos  audsocial  avatarcanon  avatarhml  compavrank  compnavpub
    perfilvis   rknavpub   socialestado  socialleitor  socialtela

`torneiobase` é o **décimo segundo nome numa lista que já existia**. O veredito
não mudou — vermelho antes, vermelho depois, mesmo caso, mesma causa —, e o
reparo é da bancada do `contratosui`, que pertence à família OS 32 e não a esta.

Registrado como **limitação remanescente**, e não como falha desta entrega.

---

## 5. Matriz das próximas autoridades (§7.6)

Todas **BLOCKED** nesta base. Nenhuma foi implementada.

| # | autoridade | entrada esperada | saída esperada |
|---|---|---|---|
| 1 | provisionamento do claim `admin` | identidade administrativa + credencial controlada | claim gravado pelo Admin SDK, com preservação de claims alheios |
| 2 | produtor de edições | template válido por `validarTemplateV1` + criador ≠ aprovador | documento em `editions`, nascido em `rascunho` |
| 3 | consumidor de `tournamentJobs` | job enfileirado pelo `tickTorneios` | `tables`, `phases`, `standings`, `conclusion` |
| 4 | porta autoritativa de inscrição | callable com App Check + perfil composto | documento em `registrations`, escrito pelo Admin SDK |
| 5 | carteira única e ledger | arbitragem entre `wallets` e `usuarios.fichas` | uma carteira, com linha de razão por débito e crédito |
| 6 | identidade e check-in por `publicId` | `publicId` + janela de check-in | `checkin_realizado`, com VIP reconferido |
| 7 | orquestração produtiva | 1 a 6 | ciclo completo da edição |
| 8 | cliente produtivo | 7 | Central de Torneios ligada à Casca |
| 9 | composição visual/A11Y sobre P | 8 | família OS 12 recomposta |
| 10 | Hall dos Imortais | produtor + consumidor + idempotência + política | `hallEntries` com produtor real |

O que continua indisponível, e é afirmado por teste: criar edição, aprovar
edição, agendar, inscrever, cancelar inscrição, cobrar, premiar, consumir jobs,
fazer check-in, formar dupla, produzir candidatura ao Hall, abrir cliente
produtivo.

---

## 6. Limitações remanescentes

1. **`contratosui` vermelho**, pelo `T27`, já na base. Seção 4.
2. **`test:integrado` não fecha nesta bancada** — e também não fecha sem a suíte
   nova: o controle sem `torneios.test.js` morre igual, em `chat.test.js`, com
   `fetch failed / ECONNRESET`. `node --test` roda os arquivos em paralelo
   contra um emulador só. As quatro suítes que importam foram medidas
   individualmente e estão verdes.
3. **`criadoPor` ausente nos quatro templates ativos**, por não haver produtor do
   claim `admin`. Declarado por valor em `CTR-02`.
4. **`campeonato_anual` sem vagas**, cadastrado e desligado. Mesma origem da
   recusa por `configuracaoPendente`.
5. **`mostrarAdmin: true` e o seletor de cenários** continuam em
   `torneios_preview_page.dart`. Estão fora do fecho de `main()` e o `CLI-02`
   prova que a bancada segue sem importador; o saneamento é da recomposição da
   família OS 12 (autoridade 9), que esta OS não faz.
6. **A porta autoritativa de inscrição não existe.** Fechar as Rules deixa a
   inscrição indisponível para todos até a autoridade 4 chegar — o que é o
   comportamento pedido, e não um efeito colateral.
