# Identidade pública no cliente Flutter

> Escopo: **cliente**. A autoridade de `publicId` continua sendo o backend, e
> nada neste documento altera contrato, Rules, índices ou Functions. Ver
> `docs/AUTORIDADE-DE-IDENTIDADE-PUBLICA.md` para o lado do servidor.

## A inversão

Antes, a identidade pública era efeito colateral de **abrir o Ranking**:

```text
abrir Ranking → obter/criar identidade → as outras telas passam a funcionar
```

Isso fazia a identidade do jogador depender de qual botão ele apertou primeiro.
Agora ela pertence à **sessão autenticada**:

```text
Firebase Auth → sessão → obterMinhaIdentidade → estado canônico
                                                      │
                              ┌───────────┬───────────┼───────────┐
                              ▼           ▼           ▼           ▼
                           Perfil      Ranking     Social     Descoberta
```

Ranking, Perfil, Social e Descoberta **apenas leem**. Nenhum deles cria, garante,
inicializa, escolhe ou deriva `publicId`.

## Onde vive

| Arquivo | Responsabilidade |
| --- | --- |
| `app/lib/sessao/identidade_publica_sessao.dart` | Domínio puro: fases, `IdentidadePublica`, falhas. Sem Flutter, sem Firebase. |
| `app/lib/sessao/fonte_identidade.dart` | A porta: um método, `obterMinhaIdentidade`. Não existe verbo de criação. |
| `app/lib/sessao/fonte_identidade_firebase.dart` | Único arquivo que conhece `cloud_functions` para identidade. |
| `app/lib/sessao/sessao_do_jogador.dart` | O dono do estado: dedup, geração, cache, retry. |
| `app/lib/sessao/sessao_firebase.dart` | Liga `authStateChanges()` ao controller. |
| `app/lib/sessao/escopo_sessao.dart` | `InheritedNotifier` — como as telas alcançam o estado. |

A instância única nasce em `BuracoApp` (`app/lib/main.dart`) e é pendurada acima
do `MaterialApp`.

## Quem dispara a chamada

A **transição para sessão autenticada**, e mais nada. `SessaoDoJogador` assina o
fluxo de uids; quando um login chega, ele busca a identidade. Nenhum `initState`
de tela participa — e isso é verificado por teste, não por convenção.

## As quatro travas

1. **Deduplicação** — a requisição em voo é compartilhada. Perfil, Ranking e
   Social pedindo ao mesmo tempo produzem **uma** chamada (a mesma `Future`).
2. **Geração** — toda troca de sessão incrementa um contador. Uma resposta
   carrega a geração em que nasceu e é **descartada** se a sessão já virou. É o
   que impede a resposta atrasada de A de contaminar B.
3. **Cache de sessão, só em memória** — navegar entre telas não reconsulta. Não
   há `SharedPreferences`, SQLite, Hive nem arquivo: uma segunda fonte de verdade
   exigiria uma política de invalidação que ninguém especificou.
4. **Sem retry por rebuild** — `garantirCarregada()` age apenas a partir de
   `naoCarregada`; depois de uma falha ela é inerte. Só `recarregar()`, que nasce
   de um gesto explícito, tenta de novo.

## `publicId` é opaco

O cliente **não** conhece alfabeto, comprimento nem prefixo do id. A única
exigência sobre o valor é ser string não vazia; qualquer outra coisa é resposta
inválida e vira falha explícita.

Não existe, e não pode voltar a existir:

- `publicId ?? uid`
- `publicId.isEmpty ? uid : publicId`
- id temporário enquanto o servidor não responde
- fórmula local equivalente à do servidor

Quando não há identidade, `EstadoIdentidadeSessao.publicId` devolve `null`. Null
é a resposta certa: representa exatamente "não há identidade".

> **Fallback de apresentação ≠ fallback de identidade.** A tela de Amigos mostra
> `—` quando ainda não há código. `—` não é identificador, não é buscável e não é
> persistido. O proibido é fabricar um valor que **passe por** `publicId`.

## `app/lib/social/` não é cliente

`app/lib/social/` é o domínio das Cloud Functions sociais escrito em Dart e
compilado para JS (`functions-social/lib/domain_bundle.js`). É lá que vive
`idPublicoDeBytes`, o gerador — que é a **autoridade**, não uma cópia local dela.

Nenhum arquivo do app importa aquele diretório, e
`app/test/sessao/auditoria_identidade_test.dart` falha se algum passar a
importar.

## Testes

| Arquivo | Cobre |
| --- | --- |
| `app/test/sessao/identidade_sessao_test.dart` | A, E, F, G, H, I, J, K, L, M |
| `app/test/sessao/telas_consomem_identidade_test.dart` | B, C, D, E (telas), O |
| `app/test/sessao/auditoria_identidade_test.dart` | N + auditoria estrutural |

A auditoria estrutural é um **teste**, e não um `grep` de fechamento: um grep
prova o dia em que foi rodado; o teste mantém a proibição valendo no CI depois
que a OS fechar.

### Armadilha registrada

Em `testWidgets`, criar a sessão dentro de `setUp` **não funciona**: o corpo do
teste roda num zone de tempo falso e o `setUp` roda fora dele, então os eventos
do stream de autenticação nunca são entregues pelo relógio do `pump`. A sessão
precisa ser aberta dentro do corpo do teste.
