# EVIDÊNCIA — Conquista canônica "Primeira Batida Real" V1

Veredito: **BLOCKED — EVENTO AUTORITATIVO INSUFICIENTE**

- Branch: `claude/conquista-primeira-batida-real-v1-81af8a`
- Base: `origin/integracao/ranking-ligas-hall` @ `428c4587f9ab771bc785d27a1174b069fc15f20b`
- HEAD inicial da worktree: `fb9edb5c6963964161f1e8834b57f50fe77074a1` (placeholder de `main`)
- Contrato especificado: `docs/PRIMEIRA-BATIDA-REAL-CONTRATO-V1.md`

Nenhum arquivo de `app/lib/`, `app/test/`, regras, funções ou assets foi alterado.
As duas únicas adições são estes dois documentos.

---

## 1. Gate zero (OS §3) — comandos e resultado

```
$ git fetch --all --prune                                          exit 0
$ git rev-parse origin/integracao/ranking-ligas-hall
428c4587f9ab771bc785d27a1174b069fc15f20b
$ git ls-remote origin refs/heads/integracao/ranking-ligas-hall
428c4587f9ab771bc785d27a1174b069fc15f20b  refs/heads/integracao/ranking-ligas-hall
$ git ls-remote origin 'refs/heads/claude/conquista-primeira-batida-real*'
(vazio — branch de saída não existia)
$ git reset --hard origin/integracao/ranking-ligas-hall
$ git status --porcelain
(vazio — árvore limpa)
```

O refspec de fetch é o completo (`+refs/heads/*:refs/remotes/origin/*`), então a
medição de ancestralidade e a varredura das branches abaixo são confiáveis.

| # | Item do gate zero | Resultado |
|---|---|---|
| 1 | base remota no SHA exato | **OK** |
| 2 | árvore limpa, branch de saída inexistente | **OK** |
| 3 | autoridade de encerramento + evento de batida válida | **NÃO EXISTE** (§2) |
| 4 | modelo/repositório canônico de conquistas | **NÃO EXISTE** (§3) |
| 5 | `Perfil`, `Última Conquista`, lista de conquistas | existem, e só a UI está pronta (§4) |
| 6 | identificador equivalente já existente | **não há** (§3) |
| 7 | base distingue os oito casos exigidos | **não distingue** (§5) |
| 8 | Rules/Functions/índices/testes afetados | **não há Rules nem Functions na base** (§2) |
| 9 | `VM.mock()` e valor fixo relacionados | registrados (§6) |

O item 3 é o que dispara a parada prevista na própria OS §3.

## 2. Prova de que não há autoridade

**A base inteira tem 236 arquivos versionados.** `git ls-files` não devolve
`functions/`, `functions-ranking/`, `functions-billing/`, `firebase/firestore.rules`
nem `firestore.indexes.json`. Não há o que alterar em Rules — o teste 9 da OS §8
("Rules recusam gravação direta pelo cliente") não tem alvo nesta base.

```
$ grep -rn "cloud_firestore\|FirebaseFirestore\|httpsCallable" .
docs/MAPA-INTEGRACAO-RANKING-LIGAS-HALL.md:180:  ... **`cloud_firestore` não está lá**
docs/RESULTADO-INTEGRACAO-RANKING-LIGAS-HALL.md:26: ... `cloud_firestore` não está nas dependências
app/lib/services/ranking_service.dart:6:  (comentário registrando a mesma ausência)
app/lib/screens/amigos_screen.dart:7:      (comentário de fase futura)
```

Todas as ocorrências são **comentário ou documentação**. Nenhuma linha de código
importa Firestore. Não há persistência: o `perfil_service.dart:8` já dizia que "sem
Cloud Firestore, a mesa não grava resultados".

**Servidor.** `app/lib/services/online_service.dart` fala o protocolo pré-auth:
envia `criarMesa`/`entrarMesa`/`iniciarPartida`/`jogada`/`sair`, recebe
`entrou`/`estado`/`erro`. Identidade é **apelido** (`online_service.dart:98`), não
uid. Não existe mensagem de fim de partida nem campo de batida. Além disso, o único
consumidor é `_OnlineLobbyHost` (`app/lib/main.dart:986`), uma tela de status de
conexão — **ela não abre a Mesa**. Nenhuma partida da base passa pelo servidor.

**Motor local.** Quem calcula batida e encerramento é `app/lib/mesa.dart`, no
cliente, contra robôs:

```
mesa.dart:100   bool encerrada = false;   // partida acabou (bateu a meta)
mesa.dart:517   rodadaEncerrada = true; duplaQueBateu = dupla; assentoQueBateu = assento;
mesa.dart:3702  /// Assentos da dupla vencedora, derivados do placar do motor local
mesa.dart:3704  final nosVenceu = (_j.placar['nos'] ?? 0) >= (_j.placar['eles'] ?? 0);
```

O próprio código já se declara provisório em `mesa.dart:3683-3684`:

> "A fonte de verdade do runtime offline atual é o motor local (`_j`). Quando existir
> motor/servidor autoritativo, trocar SOMENTE a origem de eventoId + assentos
> vencedores."

Usar isso para conceder conquista é precisamente o que a OS §3 proíbe ("Não inferir
pela tela, placar local ou animação") e o que a §10 classifica como FAIL
("concessão calculada pelo cliente").

**Fora da base, o problema muda de forma mas não some.** Na linhagem mais avançada
(`origin/claude/politica-competitiva-v1-3e139e`), `app/lib/motor/desfecho_partida.dart`
tem `DesfechoCanonicoPartida` com `estado`, `motivo`, `ladoVencedor`, `lados[assentos]`
e `encerradaEm` — mas a batida aparece como `duplaQueBateuUltimaRodada`, **por dupla**,
com comentário dizendo que serve para descrever, "nunca para decidir competição".
Mesmo com aquela branch por base, a condição da OS §4.2 ("batida válida atribuída ao
jogador") não seria demonstrável sem uma decisão de regra.

## 3. Prova de que não há domínio de conquistas

Varredura nas **105 branches remotas**, arquivo a arquivo:

```
$ for b in $(git branch -r ...); do git ls-tree -r --name-only $b | grep -icE "conquista|achievement"; done
```

Todas as branches devolvem exatamente **9**, e as nove são artes:

```
app/assets/perfil/conquista_100_canastras.webp   app/assets/perfil/conquista_imortal.webp
app/assets/perfil/conquista_1_lugar.webp         app/assets/perfil/conquista_lenda.webp
app/assets/perfil/conquista_campeao.webp         app/assets/perfil/conquista_perfeito.webp
app/assets/perfil/conquista_diamante.webp        app/assets/perfil/conquista_sequencia_10.webp
app/assets/perfil/ultima_conquista.webp
```

Não existe coleção, modelo de persistência, avaliador, catálogo com recompensa nem
serviço de conquistas em **nenhum lugar do repositório**. O catálogo da base é uma
lista `const` de oito rótulos com `desbloqueada` fixo
(`perfil_service.dart:36-56`), sem id `primeira_batida_real` e sem data.

## 4. O que existe do lado do Perfil

| Peça | Arquivo | Estado |
|---|---|---|
| card "Última Conquista" | `perfil_screen.dart:776-828` | **pronto** — gradiente dourado, imagem 52px, título, subtítulo, chevron |
| grade de conquistas | `perfil_screen.dart:879` | pronta |
| host / carregamento | `perfil_page.dart:36` | usa `PerfilService`, com estados de carregando/erro |
| modelo `UltimaConquista` | `perfil_screen.dart:21-33` | **sem `id`, sem `obtidaEm`** |
| modelo `Conquista` | `perfil_screen.dart:35-47` | **sem `obtidaEm`** |
| detalhe de conquista | `perfil_page.dart:127-129` | **não existe** — `onVerConquista` só mostra "em breve" |

A UI aprovada não precisa ser redesenhada. O que falta é fonte e dois campos.

## 5. Os oito casos da OS §3.7

| Caso | A base distingue? |
|---|---|
| vitória por batida válida | só no motor local, e por **dupla**; `assentoQueBateu` é zerado a cada rodada (`mesa.dart:177`) |
| vitória sem batida do próprio jogador | não — o cliente só sabe qual dupla venceu (`mesa.dart:3704`) |
| fim de rodada × fim de partida | **sim**, no motor local (`rodadaEncerrada` × `encerrada`) |
| abandono | **não representado** |
| WO | **não representado** |
| empate | o motor nunca encerra empatado (`mesa.dart:307`: `n != e`); não há desfecho de empate |
| partida de bot / teste | **não distinguível** — na base *toda* partida é local contra robôs |
| evento repetido | há idempotência **de celebração** por `eventoId` (`resultado_vitoria_adapter.dart`), que é visual e local; não há idempotência de concessão |

Sete dos oito casos não são decidíveis com o que a base oferece.

## 6. Dado fictício registrado (OS §3.9) — **não alterado**

| Local | Conteúdo |
|---|---|
| `perfil_service.dart:32` | `static const bool statsDemo = true` |
| `perfil_service.dart:130-137` | `ultimaConquista` fixo em **"Primeira Batida Real"**, subtítulo "Marco de Jornada · Comum Especial · desbloqueada hoje" |
| `perfil_service.dart:47-56` | `_catalogoDemo`, quatro conquistas `desbloqueada: true` |
| `perfil_screen.dart:127` | `PerfilVM.mock()` com nome **"Sônia Rainha"** |

O segundo item é o achado mais relevante: **a tela já exibe "Primeira Batida Real"
para qualquer jogador, como demonstração**, sem id, data ou origem — a situação que
a OS §5 proíbe explicitamente. Não foi removido nesta OS: apagar o mock sem ligar a
fonte deixaria a seção vazia sem entregar a conquista, e a OS §3 manda parar, não
entregar meia funcionalidade.

## 7. Medições — a base está verde e intocada

Overlay do CI reproduzido localmente (`app/tools/overlay_local.ps1` sobre um
scaffold `flutter create`), Flutter 3.41.4 / Dart 3.11.1. O CI fixa 3.44.8; a
diferença mexe em contagem de `info`, não em comportamento.

| Comando | Resultado | Exit code |
|---|---|---|
| `flutter analyze` | **0 erros · 13 warnings · 160 infos** (173 issues) | 1 (só por `info`) |
| `flutter test` | **215 passaram**, 0 falhas, 0 pulados | **0** |
| `flutter test test/teste_motor.dart` | **132 passaram** | **0** |
| `flutter test test/torneios/reward_grants_test.dart` | **80 passaram** (subconjunto dos 215) | **0** |

Total distinto: **347 testes verdes**. `teste_motor.dart` fica **fora** do glob
padrão do `flutter test` por causa do prefixo `teste_` — por isso o CI o invoca com
alvo explícito, e por isso ele foi rodado à parte aqui.

Os números batem exatamente com a baseline declarada pela OS anterior em
`docs/RESULTADO-INTEGRACAO-RANKING-LIGAS-HALL.md` §7 (0/13/160 e 215 verdes), o que
confirma que a árvore não foi tocada.

### Defeito do arnês local, encontrado de passagem (registrado, **não corrigido**)

Na primeira execução, `flutter test` acusou **32 falhas** numa base intocada. Não
eram falhas reais: `app/tools/overlay_local.ps1` copia os assets para
`app_build/assets/` mas **nunca os declara no `pubspec.yaml`**, passo que o CI faz
separadamente ("Declare assets in pubspec (robusto)", `.github/workflows/build.yml:361`).
Sem a declaração, todo `Image.asset` estoura `Unable to load asset` e derruba os
testes de Hall, Mesa, orientação e regressão visual.

Declarando os treze diretórios de assets no `pubspec.yaml` do scaffold (fora do
versionamento — `/app_build/` está no `.gitignore`), a suíte foi de 183+/32− para
**215+/0−**. O script do repositório **não foi alterado**: corrigi-lo é ferramenta,
fora das fronteiras da OS §7. Fica registrado para quem for medir a próxima
baseline — sem esse passo, a comparação sai falsa e parece regressão.

## 8. Fronteiras respeitadas

- sem merge em nenhuma ref existente;
- sem rebase, sem force-push;
- `main`, `consolidacao/apk-geral-bmv` e RC intactas;
- sem deploy, sem AAB/APK, sem Firebase Console, sem Play Console;
- motor, regras do Buraco, servidor, ranking, ligas, economia, Billing e moderação
  não foram tocados;
- `app/lib/`, `app/test/` e assets sem uma linha alterada.

## 9. Bloqueadores remanescentes

1. **Não há autoridade de encerramento de partida** publicando resultado oficial com
   uid, motivo e elegibilidade. *(bloqueia tudo)*
2. **Não há atribuição de batida por jogador.** Onde a batida existe no desfecho
   canônico, ela é por dupla e declarada não-competitiva. Exige decisão de regra:
   dupla × jogador, e última rodada × qualquer rodada. *(decisão da proprietária)*
3. **Não há como separar partida humana oficial de partida contra robô ou fixture.**
   Na base, toda partida é local contra robôs.
4. **Não há domínio de conquistas** — nem coleção, nem avaliador, nem Rules, nem
   catálogo — em nenhuma branch do repositório.
5. **Não há `cloud_firestore` no cliente**, logo não há como ler conquista real.
6. **Os modelos `UltimaConquista` e `Conquista` não têm `obtidaEm`**, então "a mais
   recente por timestamp do servidor" (OS §6) não é expressável.

Nenhum deles é contornável dentro das fronteiras da OS §7.

## 10. Veredito

```
BLOCKED — EVENTO AUTORITATIVO INSUFICIENTE
```
