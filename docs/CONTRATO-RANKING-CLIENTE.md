# CONTRATO — o que o backend publica, e como ligá-lo ao cliente

Cumpre a seção 25 da OS: mapeia a autoridade criada em `functions-ranking/` para
os contratos que já existem em `integracao/ranking-ligas-hall` (`428c458`).

**Esta OS não alterou o cliente.** O documento descreve o adaptador que falta, e
ele é a única peça restante entre os dois lados.

---

## 1. Os quatro pontos de ligação

| arquivo do cliente | o que é | o que muda |
|---|---|---|
| `app/lib/services/ranking_service.dart` | interface `RankingService` + `RankingSemFonte` | ganha uma segunda implementação |
| `app/lib/services/hall_service.dart` | interface `HallService` + `HallSemFonte` | idem |
| `app/lib/ranking/ranking_contract.dart` | tipos de dados | **nada** |
| `app/lib/hall/hall_contract.dart` | tipos de dados | **nada** |

`RankingPage(service:)` e `HallPage(service:)` recebem a implementação por
injeção. Ligar a fonte real é trocar o argumento — nenhuma linha de tela muda,
como o `RESULTADO-INTEGRACAO-RANKING-LIGAS-HALL.md` daquela branch já previa.

---

## 2. As funções chamáveis

Todas em `southamerica-east1`, todas com App Check, todas exigindo autenticação.

### `abrirRanking({ escopo, limite? })` → `RankingAbertura`

Cabeçalho e primeira página **numa ida só** — o contrato exige isso para a tela
não ter dois estados de erro concorrentes.

```jsonc
{
  "resumo": {
    "escopo": "temporada",
    "temporadaId": "2026-A",
    "temporadaNome": "Temporada A",
    "faixaTempo": "Temporada acaba em 12d 6h",  // pronto; o cliente não calcula prazo
    "fimEm": "2026-10-31T23:59:59.000Z",
    "divisao": null,                             // ver §5, dependência aberta
    "podio":  [ /* até 3 JogadorPublicado */ ],
    "escadaLigas": [ { "ligaId": "...", "nome": "...", "icone": "...", "atual": true } ],
    "eu": null                                   // JogadorPublicado ou null
  },
  "primeiraPagina": {
    "itens": [ /* JogadorPublicado */ ],
    "cursorProxima": "eyJ2IjoxLC...",            // opaco; null quando acabou
    "fim": false
  }
}
```

### `paginarRanking({ escopo, cursor, limite? })` → `RankingPagina`

Mesma forma de `primeiraPagina`. O cursor é conferido contra o escopo **e** a
temporada: um cursor da aba "temporada" aplicado à consulta "global" é recusado,
em vez de devolver uma página plausível do lugar errado.

### `consultarHall({})` → quadro por categoria

```jsonc
{
  "temporadaId": "2026-A",
  "algumHonrado": false,
  "categorias": [
    { "categoria": "campeaoHoje",     "estado": "criterio_nao_definido", "honrado": null },
    { "categoria": "melhorDupla",     "estado": "criterio_nao_definido", "honrado": null },
    { "categoria": "maiorSequencia",  "estado": "criterio_nao_definido", "honrado": null },
    { "categoria": "reiRainhaSemana", "estado": "criterio_nao_definido", "honrado": null },
    { "categoria": "lendaMes",        "estado": "criterio_nao_definido", "honrado": null }
  ]
}
```

### `consultarJogadorPorIdPublico({ publicPlayerId })`

O outro lado da navegação `posição → id público → perfil` que a OS anterior
preparou. Recebe id público, devolve dado competitivo. O UID não entra e não sai.

### `garantirIdentidadePublica({})` → `{ publicPlayerId }`

Chamada no primeiro acesso à tela. Sem ela, quem ainda não terminou partida
ranqueada não tem id público e não pode ser alvo de "abrir perfil".

---

## 3. `JogadorPublicado` → `RankingJogador`, campo a campo

A projeção foi escrita **com os nomes do contrato do cliente**, para que o
adaptador seja leitura de mapa e não tradução — que é onde um erro passa
despercebido.

| backend | `RankingJogador` | observação |
|---|---|---|
| `id` | `id` | é o `publicPlayerId`, **nunca** o UID do Firebase |
| `apelido` | `apelido` | **vazio hoje** — não há fonte de perfil (§5) |
| `avatar` | `avatar` | idem |
| `liga` | `liga` | vazio quando não há escada registrada |
| `pontos` | `pontos` | |
| `posicao` | `posicao` | `0` quando ainda não apurado — `0` não é posição válida, então não se confunde com "primeiro" |
| `direcao` | `direcao` | `subiu`/`desceu`/`estavel`, mesmos wires do enum |
| `delta` | `delta` | posições andadas desde a apuração anterior |
| `selo` | `selo` | `null` hoje |
| `souEu` | `souEu` | decidido no servidor comparando UIDs — nunca apelido |

`RankingJogador.chave` (dedupe entre páginas) cai no `id`, que é sempre publicado.

---

## 4. O adaptador que falta

Uma classe, sem lógica de classificação. Esboço:

```dart
class RankingFirebase extends RankingService {
  final FirebaseFunctions _fn;
  const RankingFirebase(this._fn);

  @override
  Future<RankingAbertura> abrir(RankingEscopo escopo) async {
    try {
      final r = await _fn.httpsCallable('abrirRanking').call({'escopo': _wire(escopo)});
      return _lerAbertura(r.data, escopo);
    } on FirebaseFunctionsException catch (e) {
      // `failed-precondition` = a fonte respondeu e disse que não há o que
      // publicar. É diferente de erro de rede, e a tela mostra o mesmo estado
      // honesto que `RankingSemFonte` já produz.
      throw RankingIndisponivel(e.message ?? RankingSemFonte.motivo);
    }
  }

  @override
  Future<RankingPagina> proximaPagina(RankingEscopo escopo, String cursor) async { /* ... */ }
}
```

**Regras que o adaptador precisa respeitar** — e que os testes da branch do
cliente já travam:

1. **Não reordenar.** `ranking_apresentacao_test.dart` alimenta a tela com
   posições 42/3/17 fora de ordem e afirma que ela mostra exatamente aquilo. O
   adaptador repassa a lista na ordem em que chegou.
2. **Não renumerar.** `posicao` vem da fonte; índice de lista não é posição.
3. **Não recalcular `souEu`.** Já vem resolvido.
4. **Não deduzir `fim`.** Ele é campo da resposta, não `itens.isEmpty`.
5. **Não formatar `faixaTempo`.** Vem pronto, do relógio do servidor.

**Dependências Flutter:** `cloud_functions`. Hoje o app só usa `firebase_auth` —
`cloud_firestore` **não** é necessário, porque nenhuma leitura de ranking passa
por Firestore direto (ver §6).

---

## 5. O que o adaptador vai receber vazio, e por quê

Nada disso é falha do backend; é ausência de decisão de produto. O cliente já
sabe exibir todos estes casos.

| campo | valor hoje | o que falta |
|---|---|---|
| `pontos` de todo mundo | `0`, e nenhuma linha criada | a **fórmula de pontuação** |
| `liga` | `""` | a lista oficial de ligas e as faixas |
| `escadaLigas` | `[]` | idem |
| `divisao` | `null` | regra de divisão **dentro** de uma liga e de "faltam X pontos" |
| `apelido` / `avatar` | `""` | uma fonte de perfil no backend |
| `selo` | `null` | critérios dos 9 selos que a arte já tem |
| Hall (5 categorias) | `criterio_nao_definido` | critérios de elegibilidade |
| aba **amigos** | `failed-precondition` | grafo social — não existe no projeto |

A aba "amigos" recusa explicitamente em vez de devolver lista vazia: vazio faria a
tela dizer *"você não tem amigos"*, que é falso e diferente de *"esta aba ainda
não existe"*.

---

## 6. Por que tudo passa por Function, e nada por Firestore direto

`rankingStandings` guarda o `uid` ao lado da pontuação. Regra do Firestore libera
ou nega o **documento inteiro** — não há como permitir ler `pontos` e esconder
`uid`. Publicar a coleção entregaria, de graça, o identificador com que se
endereçam `users/{uid}`, `playerModeration/{uid}` e todo o resto.

A projeção campo a campo só é possível em código, e é por isso que a leitura é
chamável. É a mesma decisão que o bloco de moderação tomou para as denúncias,
pelo mesmo motivo.

Efeito colateral bem-vindo: o app não ganha dependência de `cloud_firestore`.

---

## 7. Ordem de ligação sugerida

1. Registrar uma política em `functions-ranking/src/politica.ts` (**exige a
   fórmula decidida**) e abrir uma temporada com ela.
2. Esvaziar o backlog: `processarResultado({ matchId })` para cada partida em
   `rankingBacklog`.
3. Rodar `apurarRanking({})` para atribuir posições.
4. Só então escrever o adaptador — antes disso ele receberia listas vazias e não
   haveria como distinguir "adaptador errado" de "ranking sem dado".

O passo 1 é decisão de produto. Os passos 2 a 4 são operação, e as três funções
já existem.
