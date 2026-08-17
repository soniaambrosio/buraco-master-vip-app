# Homologação independente — Perfil Publicável Canônico V1

**Veredito: PASS — PERFIL PUBLICÁVEL CANÔNICO HOMOLOGADO SEM ALTERAÇÃO DE CÓDIGO.**

| | |
|---|---|
| Candidata | `origin/integracao/perfil-publicavel-canonico-v1` @ `e87dd18d8bc8c92fa19132df3f98ca42b6ea6e07` |
| Base | `origin/claude/perfil-ranking-estado-canonico-v1-cac971` @ `bc74e30a148a56b00ca7db691a378584efaa5207` |
| Branch desta homologação | `homologacao/perfil-publicavel-canonico-v1-b2` |
| Natureza | Somente leitura. Único arquivo criado: este laudo. Nenhum merge, nenhum deploy. |

> **Sobre o nome da branch.** A OS pede `homologacao/perfil-publicavel-canonico-v1`
> como preferencial. Consultado o remoto, **esse nome já existe**, em
> `4d24dbdb23dbf068d2f857d51907021174b23a46` — é uma homologação anterior da
> **mesma** candidata `e87dd18`, também com veredito PASS. Conforme §2, ela não
> foi sobrescrita: esta execução publica em `…-v1-b2`. As duas convivem, e a
> comparação entre elas está em §8.

---

## 1. Gate Zero

Cada item foi conferido antes de qualquer arquivo ser criado ou editado.

| # | Exigência | Resultado |
|---|---|---|
| 1 | `git ls-remote` **duas vezes**, candidata e base | Feito. Segunda consulta idêntica à primeira |
| 2 | SHAs exatos | `e87dd18d8bc8c92fa19132df3f98ca42b6ea6e07` e `bc74e30a148a56b00ca7db691a378584efaa5207` — conferem |
| 3 | `bc74e30…` é ancestral de `e87dd18…` | `git merge-base --is-ancestor` → verdadeiro |
| 4 | Exatamente três commits exclusivos | `git rev-list --count bc74e30..e87dd18` → **3**, na ordem e com as mensagens declaradas |
| 5 | Sete arquivos; sem servidor, Rules ou Firebase | **7 arquivos**, `+827 −98`. Nenhum caminho `functions*`, `firebase/`, `firebase.json` ou de servidor |
| 6 | Árvore limpa | `git status --porcelain` vazio, antes e depois |
| 7 | Lista completa registrada antes de homologar | Abaixo |

**Commits exclusivos**

```
fa72a3f  perfil: o que não tem fonte deixa de ser desenhado, e o ranking segue canônico
726e2c7  testes: a matriz do Perfil publicável, com o alcançável provado pela Home
e87dd18  docs: o laudo de arbitragem entre as duas folhas da Casca V2
```

**Delta completo**

```
M  app/lib/pages/perfil_page.dart                       18 ±
M  app/lib/screens/perfil_screen.dart                  195 ±
M  app/lib/services/perfil_service.dart                 51 ±
M  app/test/casca/auditoria_casca_test.dart             72 +
M  app/test/casca/casca_producao_test.dart             152 +
M  app/test/ranking/estado_canonico_ranking_test.dart  302 ±
A  docs/ARBITRAGEM-PERFIL-PUBLICAVEL-V1.md             135 +
```

Três arquivos de produção, três de teste, um de documentação. **Gate Zero aprovado.**

Ressalva registrada, não impeditiva: o `git fetch` emitiu
`failed to write commit-graph` — manutenção local concorrente. As refs foram
reconferidas por `rev-parse` contra o `ls-remote`, e batem.

---

## 2. Ambiente de execução

O repositório não é um projeto Flutter montável em si: `app/` guarda `lib`,
`test`, `assets`, `data` e o `pubspec`, e o CI monta um scaffold e sobrepõe. Esta
homologação **reproduziu o overlay do `ci-os-integracao.yml` passo a passo**, no
scratchpad, fora do repositório:

```
flutter create … app_build
cp app/pubspec.yaml app/pubspec.lock app_build/   &&  flutter pub get
cp -R app/lib/. app_build/lib/
find assets -type f ! -name '*.dart'  →  app_build/assets/   (166 arquivos)
cp -R app/test/. app_build/test/
cp app/data/torneios/*.json  → app_build/test/torneios/data/
cp app/data/colecoes/*.json  → app_build/test/colecoes/data/
rm -f app_build/test/widget_test.dart
```

O overlay **não foi versionado**, conforme §6. A árvore do repositório terminou
tão limpa quanto começou.

**Divergência de versão, declarada:** o Flutter desta máquina é **3.41.4**
(Dart 3.11.1); o CI fixa **3.44.8**. Todos os portões abaixo rodaram no 3.41.4.
Uma diferença de comportamento no pin do CI não pode ser descartada por esta
execução — ver §7.

---

## 3. Provas funcionais

### 3.1 Cadeia única do Perfil (§5.1)

A cadeia real, conferida por varredura de construtores em todo o `lib/`:

```
home_de_producao.dart:225   Navigator.push(… builder: (_) => const PerfilPage())
        ↓
perfil_page.dart:161        return PerfilScreen(…)
```

* **Um único construtor** de `PerfilPage` em todo o cliente, e ele nasce na Home
  de produção. `PerfilScreen` é construída num lugar só, pela `PerfilPage`.
* **Não existe segundo Perfil concorrente.** As outras classes com "Perfil" no
  nome são `PerfilResumo` (contrato de Configurações), `PerfilStats`/`PerfilVM`
  (tipos da própria tela), `PerfilPublico` (`lib/social/`, backend) e
  `PerfilElegibilidade` (`lib/torneios/`) — nenhuma é uma segunda tela de perfil,
  e as duas últimas não são alcançáveis a partir de `main()`.
* A rota abre por `MaterialPageRoute` e fecha por `maybePop` (`onVoltar` e
  `NavDestino.inicio`).
* Nenhuma maquete participa: `PerfilVM.mock()` existe, e **nenhum** arquivo
  alcançável a constrói (provado em §3.6 e derrubado na mutação M5).
* Troca e encerramento de sessão não conservam dados do usuário anterior —
  provado por comportamento com a sessão real, e derrubado pela mutação M3.

### 3.2 Dados publicáveis (§5.2)

Cada informação que a tela pode desenhar, com a sua origem no estado publicável:

| Informação | Fonte | No estado publicável |
|---|---|---|
| Nome | `IdentidadePublica.apelido` (sessão canônica); sem apelido, o `publicId`; sem identidade, o rótulo `'Jogador(a)'` | Identidade **real** |
| Nível, XP atual, XP próximo | não há autoridade | `null` → selo do avatar e barra de XP **não desenhados** |
| Título e emoji de título | não há autoridade | `null` → faixa **não desenhada** |
| Liga, colocação mundial | `EstadoRanking` | `indisponivel` → liga vira travessão, colocação **some** |
| Vitórias, partidas, canastras, aproveitamento | não há autoridade | `null` → painel **não desenhado** |
| Última conquista | não há autoridade | `null` → bloco **não desenhado** |
| Presentes (contagem) | não há autoridade | `null` → baú **não desenhado** |
| Conquistas | não há autoridade | `null` → seção inteira **some, título incluído** |
| Avatar, mascote, moldura, dorso, efeito, vitrine | constantes no serviço | **desenhados** — ver Achado 1, §6 |

Confirmado:

* **Ausência de fonte não vira conteúdo fictício.** O ramo publicável do
  `PerfilService` escreve `null` em oito campos, e a tela responde não
  desenhando o elemento.
* **A distinção `null` / `[]` é real e intencional** em `conquistas`: `null` é
  "não perguntei a ninguém" e apaga a seção; `[]` é "perguntei, e a resposta foi
  nenhuma" e autoriza o recado de estado vazio. Provada nos dois sentidos.
* **Apresentação neutra prevista pelo contrato:** o travessão de
  `EstadoRanking.ligaParaExibicao` é o único lugar em que a ausência ocupa
  espaço, e é decisão registrada na arbitragem (REJEITAR #10).
* **`statsDemo` é `const false`**, tem um único consumidor, e — o ponto que
  importa — desligá-la não é mais o que segura o defeito: o outro ramo do
  ternário escreve `null`, não `1`/`0`/`'Novato(a)'`.
* O serviço **não fabrica** conquistas, estatísticas, posição nem liga. Sobre
  cosméticos, ver Achado 1.

### 3.3 Ranking canônico (§5.3)

* `EstadoRanking` é **autoridade única**. Os campos crus são privados; liga e
  colocação só saem pelos getters, que higienizam na saída: fora de
  `FaseRanking.disponivel` devolvem `null`; dentro dela, string vazia ou só de
  espaços não é liga, e `0` ou negativo não é colocação.
* Home, Perfil e compartilhamento leem **a mesma constante**
  `rankingDaCascaPublicavel` (`home_de_producao.dart:108` e
  `perfil_service.dart:148`). Não há segunda interpretação de "sem ranking".
* **Não existe fallback para `'Bronze'`.** O único literal `'Bronze'` do
  `lib/` em posição de código está em `screens/ranking_screen.dart:214`, e esse
  arquivo **não é alcançável** a partir de `main()` (§3.6). Todas as demais
  ocorrências são texto de comentário explicando o defeito que foi removido.
* **Não existe fallback para colocação `1`** — nem para `0`. O tipo não deixa.
* Estado não classificado não é apresentado como classificação real.
* A candidata **não cria cálculo paralelo** de liga, pontos ou posição: não há
  aritmética competitiva nenhuma nos três arquivos de produção do delta.

### 3.4 Compartilhamento (§5.4)

`PerfilPage.textoDeCompartilhamento` é estática e pública de propósito, o que
permite conferir o texto **que sai do aparelho** sem encenar toque nem tocar na
área de transferência. Cada trecho competitivo é condicional:

```dart
if (nivel   != null) partes.add('Nível $nivel');
if (liga    != null) partes.add('Liga $liga');
if (posicao != null) partes.add('#$posicao no mundo');
if (partes.isEmpty)  return '$convite Sou ${vm.nome} 👑';
```

* Não afirma liga inexistente — nem com travessão: num texto solto o travessão
  se leria como ruído, e a decisão foi omitir.
* Não afirma colocação desconhecida.
* Não publica dado privado: o que sai é o apelido público ou o `publicId`, que
  **é** o identificador público. Não há e-mail, `uid` nem `displayName`.
* Não reutiliza informação de sessão anterior (provado em §3.1 e na mutação M3).
* Permanece coerente com o Perfil: os dois leem o mesmo `PerfilVM` e o mesmo
  `EstadoRanking`.

### 3.5 Sessão e autenticação (§5.5)

Auditado por conta própria, sobre o código com comentários removidos:

* **`authStateChanges` é assinado em um lugar só:**
  `lib/sessao/sessao_firebase.dart:59`. As outras sete ocorrências no `lib/` são
  todas texto de comentário — conferido linha a linha.
* **`firebase_auth` e `google_sign_in` são importados por dois arquivos**, ambos
  em `lib/sessao/`: `sessao_firebase.dart` e `autenticacao_firebase.dart`.
* **Nenhuma das 35 unidades alcançáveis fora de `lib/sessao/`** contém
  `currentUser`, `signInWithCredential` ou `signOut(` em posição de código.
* Perfil, Home e compartilhamento consomem a sessão canônica via
  `EscopoSessao.identidadeDe(context)`. O `PerfilService` **recebe** a identidade
  por parâmetro e não a busca — se buscasse, seria um segundo lugar que obtém
  identidade.
* Registro histórico relevante: o `PerfilService` **lia**
  `FirebaseAuth.instance.currentUser?.displayName` e deixou de ler. Era uma
  segunda autoridade de nome, e na troca de conta abriria o perfil novo com o
  nome do anterior.
* **Nenhum segundo proprietário de credencial foi criado.**

### 3.6 Casca alcançável (§5.6)

O fecho transitivo de imports a partir de `lib/main.dart` foi recalculado por
ferramenta independente (réplica do algoritmo da suíte, incluindo a remoção de
comentários antes de varrer, executada fora do repositório):

```
TOTAL = 35 arquivos alcançáveis
```

Bate exatamente com o esperado pela OS. Composição: 9 de `casca/`, 9 de
`sessao/`, 6 de `services/`, 7 de `screens/`, `pages/perfil_page.dart`,
`ranking/estado_ranking.dart`, `mesa.dart` e `main.dart`.

Nenhum alcançável constrói mock, usa Perfil de demonstração, inventa liga,
acessa autenticação diretamente ou reintroduz preview na raiz. **`ranking_screen.dart`
— o único portador do literal `'Bronze'` — está fora do fecho.**

---

## 4. Testes

### 4.1 Suítes obrigatórias

| Alvo | Resultado |
|---|---|
| `test/casca/auditoria_casca_test.dart` | **+17 — All tests passed** |
| `test/casca/casca_producao_test.dart` | **+30 — All tests passed** |
| `test/ranking/estado_canonico_ranking_test.dart` | **+43 — All tests passed** |

### 4.2 Suíte padrão completa

```
flutter test  →  766 testes, All tests passed!
```

**Bate exatamente com a referência da OS (766).**

### 4.3 As sete suítes fora do glob padrão

Rodadas separadamente, como manda §6:

| Suíte | Casos | Resultado |
|---|---|---|
| `test/teste_motor.dart` | 132 | verde |
| `test/teste_motor_resiliencia.dart` | 196 | verde |
| `test/teste_encerramento.dart` | 10 | verde |
| `test/integracao/teste_integracao_motores.dart` | 64 | verde |
| `test/moderacao/teste_moderacao.dart` | 42 | verde |
| `test/motor/teste_visao_espectador.dart` | 15 | verde |
| `test/social/teste_social.dart` | 90 | verde |
| **Total** | **549** | **todas verdes** |

**Cobertura total desta homologação: 766 + 549 = 1315 casos, todos verdes.**

Nenhuma falha foi atribuída a "seed ausente": com o overlay reproduzido, não
houve falha alguma a classificar.

### 4.4 `flutter analyze`

```
98 issues found  —  88 info + 10 warning  —  ZERO erros
```

**A referência da OS (38 ocorrências) não se reproduz nesta máquina**, e a causa
mais provável é o pin: 3.41.4 aqui contra 3.44.8 no CI — sozinha,
`unnecessary_underscores` responde por 55 das 98. Não é diferença de escopo:
`flutter analyze lib` isolado dá 97, ou seja, 97 das 98 vêm do `lib/`.

Como a referência não era reproduzível, o controle correto foi construído: a
**base `bc74e30` foi analisada no mesmo overlay, no mesmo binário**, revertendo
apenas os seis arquivos de `lib`/`test` do delta.

```
base bc74e30 :  98 issues   (88 info + 10 warning, zero erros)
candidata    :  98 issues   (88 info + 10 warning, zero erros)

diff das listas normalizadas:
  −  perfil_screen.dart:1330:25  unnecessary_underscores
  −  perfil_screen.dart:1330:29  unnecessary_underscores
  +  perfil_screen.dart:1393:25  unnecessary_underscores
  +  perfil_screen.dart:1393:29  unnecessary_underscores
```

Duas ocorrências que **desceram 63 linhas** no mesmo arquivo, mesma regra, mesma
mensagem — consequência aritmética das 63 linhas que o delta acrescentou acima
delas. Ignorando número de linha, as listas são **idênticas, ocorrência por
ocorrência**.

**Nenhum erro. Nenhuma ocorrência nova. Nenhuma ocorrência removida.** A
exigência de §6 — comparar a lista, e não a contagem — foi cumprida contra o
controle certo.

---

## 5. Provas negativas (§7)

Cinco defeitos foram **injetados no overlay** (nunca no repositório) e
revertidos. Para cada um, o teste que o derruba:

| # | Mutação | Derrubada por | Casos vermelhos |
|---|---|---|---|
| M1 | Liga cai para `'Bronze'` no ramo publicável | `casca_producao_test.dart` + `estado_canonico_ranking_test.dart` | **8** |
| M2 | Colocação cai para `1` no ramo publicável | `casca_producao_test.dart` + `estado_canonico_ranking_test.dart` | **7** |
| M3 | Perfil anterior retido na troca de sessão | `estado_canonico_ranking_test.dart` | **2** |
| M4 | Tela alcançável lê o provedor de autenticação direto | `auditoria_casca_test.dart` | **2** |
| M5 | Perfil de demonstração alcançável pela raiz | `auditoria_casca_test.dart` + `estado_canonico_ranking_test.dart` | **2** |

Detalhe de cada uma:

**M1 — `: rankingDaCascaPublicavel` → `: const EstadoRanking.disponivel(liga: 'Bronze')`.**
Mortos: `o perfil publicável não recebe liga nem colocação` (`Expected:
indisponivel / Actual: disponivel, liga: Bronze`), `o que a Home põe no cabeçalho
é o que o Perfil recebe`, `sem autoridade de ranking, nada de Bronze nem de #0`,
`o convite copiado do Perfil alcançável não inventa nada` — este último flagrando
o texto real que sairia do aparelho: `… Sou Ana 👑 Liga Bronze.` Placar das duas
suítes: `+28 −2` e `+37 −6`, oito casos vermelhos ao todo.

**M2 — mesma linha, `posicaoMundial: 1`.** Escolhido de propósito: `1` é
colocação legítima e **atravessa** a higienização do tipo, então só um teste de
comportamento pega. Mortos 7 casos, incluindo os três de troca de sessão.

**M3 — `if (_jaCarregou && sessao.publicId == _publicIdCarregado) return;` →
`if (_jaCarregou) return;`.** O Perfil deixa de reagir à troca de identidade.
Mortos: `troca de conta sem logout não reaproveita nada da geração anterior` e
`o compartilhamento após a troca também não afirma nada`.

**M4 — `import 'package:firebase_auth/firebase_auth.dart'` e
`FirebaseAuth.instance.currentUser` dentro de `perfil_page.dart`.** Mortos:
`só a camada de sessão importa firebase_auth ou google_sign_in` e `nenhuma tela
alcançável guarda o usuário do provedor`.

**M5 — `_service.vmPlaceholder()` → `PerfilVM.mock()`.** Mortos: `nenhum arquivo
alcançável CONSTRÓI um .mock()` e `a demonstração do Perfil não é alcançável pela
raiz publicável`.

**Nenhuma mutação sobreviveu.** Após cada reversão, os três arquivos foram
conferidos por `diff` contra o repositório: **zero resíduo**. As três suítes
obrigatórias voltaram a `+17`, `+30` e `+43`.

### Observação de defesa em profundidade

M1 e M2 **não** foram pegas pela auditoria estrutural — só pelas suítes de
comportamento. Não é defeito: a auditoria de `auditoria_casca_test.dart` proíbe
os **literais** exatos que produziram o defeito original (`liga: demo ? 'Diamante'
: 'Bronze'` e cinco irmãos), e as minhas mutações escreveram um Bronze de forma
textual diferente. As duas camadas se complementam — a estrutural impede a volta
do literal histórico, a comportamental pega qualquer forma nova. Registro isso
porque significa que **quem mexer nessas suítes precisa preservar as duas**: a
estrutural sozinha não seguraria uma reintrodução escrita de outro jeito.

---

## 6. Achados registrados, sem correção

Conforme §3 e §10, nada foi corrigido. Nenhum destes é impeditivo.

**Achado 1 — cosméticos sem fonte, e a divergência do avatar entre Home e
Perfil. Pré-existente.**
O `PerfilService` escreve constantes em `avatar: '👑'`, `mascote: '🦊'`,
`moldura`/`dorso`/`efeito` e `vitrine: _vitrinePadrao` (cinco itens), e a tela
desenha os cinco slots sob o cabeçalho **`VITRINE EQUIPADA`** — que, lido ao pé
da letra, afirma que aquilo é o que a pessoa equipou, e ninguém conferiu. Mais
concreto: `IdentidadePublica.avatarRef` **existe, é real e vem de
`publicProfiles`**; a Home o lê (`identidade?.avatarRef ?? '👑'`,
`home_de_producao.dart:97`) e o Perfil **não** — carimba a coroa. Quem tiver
avatar escolhido vê o seu na Home e a coroa no Perfil, nas mesmas duas telas que
esta OS quer coerentes.
Verificado que é **pré-existente e idêntico na base**: nenhuma dessas linhas
aparece no diff `bc74e30..e87dd18`, e `git show bc74e30:…/perfil_service.dart`
traz os mesmos literais nas linhas 123–127 e 160. A candidata não introduziu nem
agravou. Corrigir estaria fora de §3, que proíbe tocar código Dart. Fica como
insumo para a Fase 3 (inventário real), junto do resto da vitrine.

**Achado 2 — corrida no `_carregar` durante troca rápida de sessão.
Pré-existente.**
Duas cargas em voo não são canceladas uma pela outra: vence a última a
*terminar*. Hoje é inofensivo porque o atraso é constante (350 ms simulados) e a
ordem se preserva; com Firestore real na Fase 2 pode inverter. O corpo de
`_carregar` **não foi tocado pelo delta**. Já constava da homologação anterior.

**Achado 3 — árvore duplicada `app/lib/app/lib/`. Pré-existente.**
Confirmada presente (`screens/`, `widgets/`). Não é alcançável a partir de
`main()` e não entra no fecho de 35. Limpeza ampla é vedada por §3.

**Achado 4 — a branch de homologação anterior alterou mais que documentação.**
`4d24dbd` acrescentou, além do laudo,
`app/test/ranking/homologacao_perfil_publicavel_test.dart`. Sob **esta** OS isso
seria violação de §3 ("é proibido alterar testes"; commit "exclusivamente
documental"). Não julgo a OS que a governava, que pode ter sido outra — registro
porque muda o que deve ser composto adiante: se aquela branch entrar numa
composição, entra código de teste junto, e não só um documento. **Esta**
homologação é estritamente documental.

---

## 7. Ressalvas de ambiente

1. **Flutter local 3.41.4; o CI fixa 3.44.8.** Tudo aqui rodou no 3.41.4. É a
   causa mais provável de o `analyze` dar 98 em vez das 38 da referência.
   Analyze e suítes são verdes nesta máquina; uma diferença no pin do CI não pode
   ser descartada por esta execução.
2. **`flutter pub get` avisou que "Building with plugins requires symlink
   support"** (Modo de Desenvolvedor desligado). Não afeta esta OS: a resolução
   de dependências completou, `analyze` e `flutter test` rodam. Nenhum portão
   exigido é de build, e §3 proíbe APK/AAB/deploy.
3. **Os portões de Firebase/emulador do `ci-os-integracao.yml` não foram
   executados.** O delta não toca `functions*`, `firebase/` nem Rules. Registrado
   como **não executado**, e não presumido verde.
4. **`git fetch` emitiu `failed to write commit-graph`.** Manutenção local
   concorrente; refs reconferidas por `rev-parse`.

---

## 8. Relação com a homologação anterior da mesma candidata

`origin/homologacao/perfil-publicavel-canonico-v1` @ `4d24dbd` já homologou
`e87dd18` com veredito PASS. Esta execução foi conduzida **de forma independente**
— fecho recalculado por ferramenta própria, auditoria de autenticação refeita
por varredura própria, controle de `analyze` construído contra a base, e as cinco
mutações injetadas e revertidas por conta própria. Chegou ao **mesmo veredito**,
por caminhos que se cruzam apenas no resultado.

Convergências independentes: **35** arquivos alcançáveis; `'Bronze'` presente só
em `ranking_screen.dart`, fora do fecho; `rankingDaCascaPublicavel` lido por Home
e Perfil; Achado 2 (corrida no `_carregar`) e Achado 3 (árvore duplicada).

Diferenças: esta execução mediu a suíte completa (**766**) e as sete suítes fora
do glob (**549**), construiu o controle de `analyze` contra a base — o que a
anterior não fez — e acrescenta o Achado 1 (cosméticos e a divergência do avatar
entre Home e Perfil) e o Achado 4. Nenhuma delas muda o veredito.

---

## 9. Relação com a composição futura

Esta OS **não** realiza a composição. Registrado, conforme §8 da OS:

* A homologação da Mesa Online/Casca V2 está em
  `origin/homologacao/ligacao-motor-canonico-casca-v2-p0`. O prefixo conhecido
  `cf8fe37` foi **confirmado no remoto nesta execução**, com SHA completo
  `cf8fe37b0c232ad6dd35556ddac7f3e4bb729aa9` — que ainda assim **deve ser
  reconfirmado** na OS de composição, porque a ref pode andar.
* A ordem aprovada é **Mesa Online/Casca V2 primeiro, Perfil Publicável depois**.
* Esta homologação **não tocou código nem testes** — apenas acrescentou este
  documento. Portanto a pré-arbitragem anterior **permanece válida** e não
  precisa ser refeita.

---

## 10. Critérios de aprovação (§9)

| Critério | Situação |
|---|---|
| Gate Zero integralmente aprovado | **Sim** — §1 |
| Todas as fontes visíveis identificadas | **Sim** — §3.2, com o Achado 1 explicitado |
| Nenhum fallback competitivo inventado | **Sim** — §3.3 |
| Sessão canônica continua única | **Sim** — §3.5 |
| Provas negativas eficazes | **Sim** — 5 de 5 mortas, §5 |
| Testes obrigatórios verdes no ambiente correto | **Sim** — 1315 casos, §4 |
| Nenhuma alteração além do documento | **Sim** — único arquivo criado é este |
| Branch publicada, árvore limpa, `local == remoto` | **Sim** — §11 |
| Nenhum merge ou deploy | **Sim** |

---

## 11. Entrega

* **Correção funcional:** nenhuma. Não houve defeito a corrigir.
* **Teste novo:** nenhum. §3 proíbe alterar testes, e esta branch é
  exclusivamente documental.
* **Arquivo criado:** este laudo, e só ele.
* **Branch:** `homologacao/perfil-publicavel-canonico-v1-b2`, publicada sem
  `--force`, sobre `e87dd18`. Sem PR, sem promoção a RC, sem deploy.
* A candidata `origin/integracao/perfil-publicavel-canonico-v1` **permanece
  intocada** em `e87dd18`.

---

**Veredito final: PASS — PERFIL PUBLICÁVEL CANÔNICO HOMOLOGADO SEM ALTERAÇÃO DE
CÓDIGO.**

O Perfil deixou de afirmar o que ninguém verificou. Liga e colocação têm uma
autoridade só, que sabe dizer "não sei" e higieniza o zero antes que qualquer
tela o veja; nível, XP, título, placar, presentes e conquistas chegam ausentes em
vez de zerados, e a tela responde não desenhando; o convite que sai do aparelho
perde a linha competitiva em vez de inventá-la; e a identidade é real, vinda da
sessão canônica, com um único dono de credencial. As cinco mutações que
reintroduziriam o defeito morrem em testes que rodam no CI, o que significa que a
proibição continua valendo depois que esta OS fechar.
