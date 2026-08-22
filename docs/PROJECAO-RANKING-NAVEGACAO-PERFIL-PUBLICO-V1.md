# Projeção canônica do ranking e navegação ao Perfil público — V1

## Base e cabeça

| | |
|---|---|
| Base (branch) | `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1` |
| Base (SHA) | `6e428e8575e2df4a504148a948305838cf3ff2d4` |
| Referência documental | `auditoria/navegacao-perfil-publico-v1 @ a9f08bd9906e0e8c37b35f14df73927f8a57d771` (somente leitura) |
| Branch publicada | `claude/ranking-navegacao-perfil-publico-v1-5ffffa` |

A base foi confirmada por **duas consultas remotas independentes**: `git ls-remote origin`
e a API REST do GitHub (`/repos/.../branches/...`). As duas devolveram o mesmo SHA para
as duas referências.

---

## O defeito

`abrirRanking` sempre devolveu jogadores reais em `resumo.podio[]` e
`primeiraPagina.itens[]` — cada linha com `publicPlayerId`, `souEu`, apelido,
posição, liga e mais treze campos, todos decididos pelo servidor.

O cliente lia a resposta inteira e guardava **um campo**: `resumo.eu`.
`FotografiaRanking.daAbertura` descartava o resto dentro do parser.

A consequência não era "falta uma tela". Era que a única lista de gente de
verdade que o sistema publica **não existia no aplicativo** — e qualquer
superfície que quisesse mostrar ranking teria de inventar os jogadores. É a
mesma família de defeitos desta linhagem: Liga Bronze para quem nunca jogou,
`#0 no mundo`, o Hall com cinco nomes escritos no código, Amigos com `beto` e
`claudia`.

---

## Inventário de arquivos

### Criados

| Arquivo | O que é |
|---|---|
| `app/lib/ranking/estado_tabela_ranking.dart` | A tabela como o cliente pode afirmá-la: fase + pódio + primeira página. |
| `app/lib/casca/navegacao_perfil_publico.dart` | **O ponto único** que decide de quem é o Perfil que abre. |
| `app/lib/casca/ranking_de_producao.dart` | A apresentação mínima do ranking real, com os cinco estados. |
| `app/test/ranking/navegacao_perfil_publico_test.dart` | A matriz da OS: 38 casos. |

### Alterados

| Arquivo | +/− | O que mudou |
|---|---|---|
| `app/lib/ranking/ranking_transporte.dart` | +361/−2 | `JogadorPublicoRanking`, `TabelaRanking`, `AberturaRanking`; `meuRanking()` → `abrirRanking()`. |
| `app/lib/ranking/leitor_ranking.dart` | +98/−23 | `LeituraDeAbertura`; a tabela atravessa as **mesmas três guardas**. |
| `app/lib/ranking/estado_ranking.dart` | +40/−10 | `faseDaFalhaDeRanking` extraída — uma opinião só sobre o que uma falha significa. |
| `app/lib/ranking/ranking_da_sessao.dart` | +36/−6 | Publica `meuEstado` e `tabela` **juntos**, de uma leitura só. |
| `app/lib/ranking/escopo_ranking.dart` | +9/−0 | `EscopoRanking.tabelaDe(context)`. |
| `app/lib/ranking/ranking_transporte_firebase.dart` | +8/−6 | Adaptador lê a abertura inteira; `_chamar` virou genérico. |
| `app/lib/pages/perfil_page.dart` | +40/−2 | `ehMeuPerfil` derivado de `publicIdVisitado`; porta para o ranking. |
| `app/lib/screens/perfil_screen.dart` | +57/−1 | `onAbrirRanking` opcional na linha competitiva. |
| 4 suítes de ranking/composição | +50/−11 | Fakes de transporte adaptados ao contrato novo. |

**Nada fora de `app/`.** Servidor, Functions, Rules e protocolo intocados.

---

## O modelo público criado

`JogadorPublicoRanking` espelha `JogadorPublicado` de
`functions-ranking/src/projecao.ts` **campo a campo** — dezessete campos, nenhum
a mais, nenhum a menos.

O que ele **não** tem, e por quê:

- **Sem `uid`.** `projetarJogador` é uma lista branca que troca o uid pelo
  `publicPlayerId` antes de a linha atravessar a fronteira. O objeto não tem
  campo onde um uid caberia — a garantia é estrutural, não uma expressão
  regular que alguém possa afrouxar.
- **Sem identificador inventado.** Índice na lista, posição e apelido são
  "quase identificadores" à mão, e cada um mente no caso que importa: dois
  jogadores com o mesmo apelido, uma lista reordenada entre o desenho e o toque.

### `souEu` vem de fora, e isso é o contrato

A comparação acontece em **uma linha do sistema inteiro**, e ela é do servidor:

```ts
souEu: uidDoLeitor !== null && linha.uid === uidDoLeitor
```

O cliente não tem os dois lados dessa igualdade e por isso não pode nem
"conferir". A suíte encena o caso que expõe qualquer heurística local: uma linha
cujo `publicPlayerId` é **igual ao da conta logada** e cujo `souEu` é `false`
(caso `N5b`).

### O que a validação de id faz, e onde ela para

Para em "não está vazio". O cliente trata `publicId` como **string opaca** —
`auditoria_identidade_test.dart` (CASO N) varre `lib/` e reprova a presença do
alfabeto, do comprimento e do prefixo do id, porque essas três constantes juntas
**são a fórmula de geração**. Um cliente que a conhece está a uma linha de cunhar
identidade, que é o defeito de duas autoridades de emissão que este projeto já
pagou para fechar.

Conferir a forma aqui seria, além de proibido, uma segunda opinião sobre um
julgamento que já existe: `idPublicoValido` em `functions-ranking/src/identidade.ts`
recusa o malformado com `invalid-argument` antes de tocar o banco.

> Esta decisão foi **descoberta pelo portão**, não planejada: a primeira
> implementação importava `lib/social/identidade_publica.dart` e o CASO N
> reprovou. O teste existente estava certo e a implementação, errada.

---

## Ponto único de navegação

`app/lib/casca/navegacao_perfil_publico.dart` → `abrirPerfilDoJogador()`

```
souEu == true  → const PerfilPage()                       (cadeia do proprietário)
souEu == false → PerfilPage(publicIdVisitado: <o dele>)   (cadeia do visitante)
id vazio       → não navega
```

Três coisas sustentam a unicidade:

1. **`ehMeuPerfil` é derivado.** O padrão era `true` fixo, e
   `PerfilPage(publicIdVisitado: 'PXXX…')` compilava mostrando o perfil do
   **dono** com os controles de edição enquanto carregava um id de terceiro que
   ninguém consultava. Agora quem passa o id já disse tudo — não há
   `ehMeuPerfil: false` a esquecer. `const PerfilPage()` continua constante.
2. **O ramo do dono não olha o id.** Testar a forma ali criaria um caminho em que
   o dono fica sem perfil por causa de um campo que a tela dele nem lê (caso
   `N10c`).
3. **Auditoria estrutural.** `N13b` afirma que `publicIdVisitado` é alimentado
   de **um lugar só**, e por `jogador.publicPlayerId`.

---

## Superfície produtiva

A porta é a **linha competitiva do Perfil** — o bloco que já mostra liga e
colocação. Sem o callback (catálogo visual, testes sem casca) o desenho é byte a
byte o de antes; com ele, a linha ganha área de toque de 48 px, um nó de
acessibilidade de botão e a seta. O item "Ranking" da barra inferior, que dizia
"chega nas próximas fatias", vai ao mesmo destino.

**Abrir o ranking não pergunta nada.** A tela lê `EscopoRanking`, o mesmo estado
que a Home e o cabeçalho do Perfil já consomem: uma abertura, uma resposta, três
superfícies que não podem divergir.

### Cinco estados, e nenhum deles é "lista vazia"

| Estado | Desenho | Botão |
|---|---|---|
| carregando | progresso | — |
| vazio (respondeu, ninguém classificado) | "Ninguém classificado nesta temporada ainda." | — |
| acesso recusado | frase **neutra** (não acusa a sessão) | Tentar de novo |
| falha recuperável | "Não consegui carregar o ranking agora." | Tentar de novo |
| sucesso | pódio + primeira página, como vieram | — |

Mais dois que a tela trata e a OS não listou porque não são erro: `indisponivel`
(sem autoridade, ou sem temporada) e `sessaoInvalida` (sem sessão local — sem
botão, porque insistir só repetiria a recusa).

Quatro deles desenham lista vazia. Uma tela que olhasse `itens.isEmpty` em vez da
fase diria "ainda não há ninguém no ranking" nos quatro, e dois esconderiam o
botão que resolveria o problema da pessoa.

### O que não foi ligado

`ranking_screen.dart`, `hall_screen.dart` e `amigos_screen.dart` continuam órfãos
do fecho que nasce em `main.dart` — provado por `N12`, e por `N13`, que varre o
código alcançável atrás dos slugs `beto`, `claudia`, `fernanda`, `mateus`,
`sofia`, `larissa`, `ricardo`, `voce` e `SONIA-RAINHA`.

---

## Matriz

| # | Caso | Prova |
|---|---|---|
| 1 | pódio e primeira página preservados campo a campo | `N1a`–`N1f` |
| 2 | `publicPlayerId` nunca vira UID | `N2a`–`N2c` |
| 3 | jogador próprio usa o Perfil local | `N3` |
| 4 | jogador próprio produz zero chamada remota de Perfil | `N4` |
| 5 | terceiro usa exatamente seu `publicPlayerId` | `N5`, `N5b` |
| 6 | três toques no mesmo terceiro reutilizam o voo | `N6`, `N6b` |
| 7 | dois terceiros não compartilham cache | `N7` |
| 8 | troca de sessão invalida cache e voos antigos | `N8`, `N8b` |
| 9 | resposta antiga não substitui sessão nova | `N9` |
| 10 | `publicPlayerId` vazio ou inválido não navega | `N10`, `N10b`, `N10c` |
| 11 | acesso recusado não inventa dados | `N11a`–`N11g` |
| 12 | Hall e Amigos continuam sem ligação produtiva | `N12` |
| 13 | nenhum slug de maquete chega a `publicIdVisitado` | `N13`, `N13b`, `N13c`, `N13d` |
| 14 | voltar do Perfil público preserva o ranking | `N14` |
| 15 | acessibilidade e área de toque adequadas | `N15`, `N16b` |

`N1a` compara o **objeto inteiro**, e não três campos escolhidos: é assim que uma
perda de campo aparece em vez de passar.

---

## Mutações injetadas

Cada mutação foi conferida por `diff` **antes** de creditar o resultado — uma
mutação que não pega mente sobre a cobertura.

| # | Defeito injetado | Casos que caíram |
|---|---|---|
| M1 | `souEu` invertido no ponto de navegação | 7 — `N3`, `N4`, `N5`, `N5b`, `N10`, `N10b`, `N10c` |
| M2 | campo `uid` acrescentado à projeção | `N2a` |
| M3 | dono roteado pela callable de terceiro | 4 — `N3`, `N4`, `N10c`, `N13b` |
| M4 | maquete de Amigos ligada na Home | `N12`, `N13` |
| M5 | campo `selo` deixado cair na projeção | `N1a` |
| M6 | guarda do id ausente removida | `N10`, `N10b` |

Todas revertidas; os três arquivos novos foram conferidos byte a byte contra
cópia anterior às mutações, e não há resíduo de `MUTAÇÃO` em `app/lib`.

---

## Números antes/depois

| Portão | Antes (`6e428e8`) | Depois |
|---|---|---|
| `flutter analyze` | 38 issues, 0 erros | **38 issues, 0 erros — conjunto idêntico** |
| Suíte padrão (glob) | 993 passando | **1031 passando** (+38) |
| `test/teste_motor.dart` | 132 | 132 |
| `test/teste_motor_resiliencia.dart` | 196 | 196 |
| `test/teste_encerramento.dart` | 10 | 10 |
| `test/integracao/teste_integracao_motores.dart` | 64 | 64 |
| `test/social/teste_social.dart` | 90 | 90 |
| `test/moderacao/teste_moderacao.dart` | 42 | 42 |
| `test/motor/teste_visao_espectador.dart` | 15 | 15 |

A comparação do analyze é feita **sem linha e coluna**: editar um arquivo acima
desloca o diagnóstico e inventa um "novo" e um "perdido".

As suítes de torneios e coleções exigem os seeds de `app/data` copiados para
`app/test/*/data` — o que o CI faz no overlay. As cópias foram feitas para medir
e **removidas** ao final; não estão no commit.

---

## Uma prova homologada foi reescrita

`regressao_leitor_ranking_test.dart` → `B9` afirmava `identical(a, b)` entre dois
`Future` de `meuRanking`. `meuRanking` passou a ser uma **projeção** de
`abrirRanking` — mesma chave, mesmo voo, mesma resposta, devolvendo só o
cabeçalho —, e projetar cria um `Future` novo por chamada.

A propriedade que importa (**três toques, uma chamada**) continua afirmada pelo
mesmo `expect(t.emitidasDe('proprio'), 2)` de antes, intocado. A identidade do
objeto de voo passou a ser afirmada sobre `abrirRanking`, que é a superfície que
realmente dedupa e a que a produção usa. Nenhuma garantia foi afrouxada; a
afirmação mudou de sujeito junto com o sujeito.

---

## Preservações verificadas

- Servidor, Functions, Rules e protocolo: **zero alterações** (`git status`).
- Nenhum literal de demonstração: `N13` e `N13d`.
- Nenhum logout em falha: `sessaoInvalida` só com prova independente; a tela não
  desloga ninguém.
- Cache, deduplicação, barreira temporal e troca de sessão: as três guardas do
  leitor não foram tocadas — a tabela passou a atravessá-las **junto** com o
  cabeçalho, no mesmo valor, porque vieram da mesma ida.
- App Check **não** foi ativado.
- `app/lib/app/lib/` **não** foi tocado.

---

## Riscos residuais

1. **App Check segue desligado.** Em produção as duas callables recusam com
   `unauthenticated`, e a tela mostra o estado neutro com botão. Pendência de
   ativação, registrada desde a OS do leitor real; não é código.
2. **A tabela não pagina.** Só a primeira página é exibida; `paginarRanking`
   existe no backend e não tem porta no cliente. Deliberado: o cursor não tem
   consumidor, e superfície sem consumidor apodrece.
3. **`apelido` vazio cai no `publicPlayerId`.** É o mesmo fallback de
   apresentação da Home. Enquanto `publicProfiles` não for a fonte da linha de
   classificação, a lista pode exibir ids em vez de nomes — honesto, mas feio.
4. **Flutter local 3.41.4, CI pinado em 3.44.8.** Os 38 diagnósticos vêm do
   `flutter_lints` e não da versão, mas o número não foi conferido no CI.
5. **`ci-os-integracao` não é dispatchável a partir desta branch** — o arquivo
   não está em `main`, e o gatilho por push é de outra branch. Não há evidência
   de CI para esta entrega; os portões foram executados localmente e estão acima.

---

## Árvore

Limpa. `local == remoto` após o push. Nenhum PR, merge ou deploy.
