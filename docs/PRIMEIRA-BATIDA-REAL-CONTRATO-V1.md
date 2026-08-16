# CONTRATO — Conquista canônica "Primeira Batida Real" V1

- Branch: `claude/conquista-primeira-batida-real-v1-81af8a`
- Base: `integracao/ranking-ligas-hall` @ `428c4587f9ab771bc785d27a1174b069fc15f20b`
- Estado desta OS: **BLOCKED — EVENTO AUTORITATIVO INSUFICIENTE**
- Evidência e medições: `docs/PRIMEIRA-BATIDA-REAL-EVIDENCIA-V1.md`

Este documento registra o contrato **especificado** da conquista. Ele não descreve
código entregue: nenhuma linha de `app/lib/` foi alterada, porque o gate zero da OS
(§3) parou a execução. O contrato fica escrito para que, quando a autoridade
existir, a implementação seja mecânica e não precise redecidir nada.

---

## 1. Por que o contrato não virou código

A OS §3 exige, antes de editar, localizar "a autoridade real de encerramento de
partida e o evento de batida válida", e manda parar se ela não existir:

> Se não existir evento autoritativo capaz de provar jogador vencedor + batida
> válida + fim de partida, parar com `BLOCKED — EVENTO AUTORITATIVO INSUFICIENTE`.
> Não inferir pela tela, placar local ou animação.

Na base obrigatória essa autoridade **não existe**. O detalhamento probatório está
na evidência (§2 e §3 de lá). Em resumo:

1. a base não tem persistência alguma — `cloud_firestore` não está nas dependências
   do CI e nenhum arquivo de `app/lib/` o importa;
2. a base não tem backend — não há `functions*/`, `firebase/firestore.rules` nem
   `firestore.indexes.json` em nenhum lugar da árvore;
3. o servidor Node alcançado por `OnlineService` fala um protocolo pré-autenticação
   (`criarMesa` / `entrarMesa` / `iniciarPartida` / `jogada` / `sair`, resposta
   `entrou` / `estado` / `erro`), identifica jogador por **apelido** e não publica
   evento de fim de partida nem atribuição de batida;
4. a única coisa que calcula batida e encerramento na base é o **motor local**
   (`app/lib/mesa.dart`), que roda no cliente contra robôs — exatamente a fonte que
   a OS proíbe usar.

Um quinto achado, independente da base, aparece na linhagem mais avançada do
repositório e afeta o próprio §4.2 desta OS: o desfecho canônico
(`app/lib/motor/desfecho_partida.dart`, em `origin/claude/politica-competitiva-v1-3e139e`)
carrega `duplaQueBateuUltimaRodada` — atribuição **por dupla**, não por jogador — e
o comentário do campo declara que ele é descritivo, "nunca para decidir competição".
Isso é a divergência que a OS §4.2 manda registrar e interromper, e não decidir em
silêncio.

---

## 2. Identificador canônico

```
primeira_batida_real
```

Nenhum identificador equivalente existe hoje. O catálogo da base
(`app/lib/services/perfil_service.dart:36-56`) tem oito ids — `primeiro_lugar`,
`sequencia_10`, `cem_canastras`, `diamante`, `campeao`, `imortal`, `lenda`,
`perfeito` — e nenhum deles é esta conquista. A varredura das 105 branches remotas
não achou domínio de conquistas em lugar nenhum: os únicos arquivos que casam com
`conquista|achievement` são as **nove artes** de `app/assets/perfil/`, idênticas em
todas as branches.

O texto "Primeira Batida Real" já aparece na base, mas **como demonstração**, sem id,
sem data e sem origem — é literal de mock (§7). O identificador acima é novo por
necessidade, não por duplicação.

## 3. Condição de concessão

Concede-se uma única vez, ao **jogador**, quando **todos** forem verdadeiros:

1. o desfecho é **final** e vem da autoridade (não é fim de rodada intermediária);
2. o motivo do encerramento é conclusão normal — não `abandono`, `wo`,
   `cancelada`, `anulada` nem empate;
3. a partida é elegível: humana, oficial, fora de fixture/teste;
4. o jogador pertence ao lado vencedor declarado pela autoridade;
5. **a batida válida é atribuída a esse jogador** pela regra canônica;
6. o jogador ainda não possui `primeira_batida_real`.

Vencer sem que a batida seja sua não concede. Ser parceiro de quem bateu não
concede — salvo se a regra canônica declarar que a unidade é a dupla, e essa
declaração precisa ser aprovada explicitamente, não inferida (§4.2 da OS).

**Ambiguidade que precisa de decisão de regra, não de código.** Uma partida tem
várias rodadas, e cada rodada pode ter uma batida. "Venceu a partida com uma batida
válida" admite duas leituras: (a) a batida da **última** rodada é do jogador; ou (b)
o jogador bateu em **alguma** rodada da partida que sua dupla venceu. O motor local
sequer preserva o histórico: `assentoQueBateu` é zerado a cada rodada nova
(`app/lib/mesa.dart:177`), então ao fim da partida ele só conhece a última. As duas
leituras produzem populações diferentes de contemplados.

## 4. Autoridade e idempotência

- A concessão é **exclusiva do backend**. O cliente lê e apresenta; nunca decide.
- Chave idempotente derivada do evento e da conquista, não do relógio:
  `{uid}:{partidaId}:primeira_batida_real`.
- Escrita sob transação, condicionada à inexistência do registro: retry,
  reconexão, redelivery e chamadas concorrentes convergem para **um** registro, uma
  recompensa e uma notificação.
- `obtidaEm` é timestamp **do servidor**. O cliente não carimba data.
- O registro é permanente; não há revogação neste contrato.
- As Rules devem **negar** escrita direta do app na coleção de conquistas — leitura
  do próprio dono, escrita só por Admin SDK.

## 5. Recompensa

**Somente a conquista permanente e seu registro visual.** Não há catálogo canônico
que atribua fichas, XP, item ou vantagem a este identificador — a varredura não
achou catálogo de conquistas nenhum. Inventar recompensa é proibido pela OS §4.4.

## 6. Contrato visual

No Perfil, entre as estatísticas e o restante do conteúdo:

- título da seção: `Última Conquista`;
- conteúdo principal: `Primeira Batida Real`;
- descritivo aprovado: `Você venceu sua primeira partida com uma batida válida.`;
- identidade preta/dourada/roxa, selo legível, nome + data + categoria;
- estados **carregando**, **vazio** e **erro** honestos — sem número inventado;
- estado vazio real para quem não tem conquista; nunca preencher "Primeira Batida
  Real" como demonstração;
- responsivo em 320×640 e 390×844, com fonte ampliada;
- acessibilidade sem depender só de cor ou animação.

A superfície visual já existe e **não precisa ser redesenhada**:
`PerfilScreen._ultimaConquista` (`app/lib/screens/perfil_screen.dart:776`) desenha o
card dourado com imagem, título, subtítulo e chevron.

Duas lacunas de modelo, porém, impedem cumprir o §6 da OS com os tipos atuais:

| Exigência da OS | Campo no modelo da base | Situação |
|---|---|---|
| "Última Conquista" escolhida por `obtidaEm` do servidor | `UltimaConquista` (`perfil_screen.dart:21`) | **não tem** `obtidaEm` nem `id` |
| conquista também aparece no histórico, sem duplicar | `Conquista` (`perfil_screen.dart:35`) | **não tem** `obtidaEm` |
| toque abre detalhe "se esse padrão já existir" | `onVerConquista` (`perfil_page.dart:128`) | padrão **não existe** — hoje só exibe "em breve" |

Ou seja: os dois modelos precisam ganhar `obtidaEm` (aditivo) para que "a mais
recente" seja determinável por timestamp do servidor com desempate determinístico
(sugestão: `obtidaEm` desc, depois `id` asc). Sem detalhe de conquista existente, a
OS §5 manda **não** criar navegação paralela — o toque permanece como está.

## 7. Dado fictício no caminho, registrado (OS §3.9)

| Local | O que é |
|---|---|
| `perfil_service.dart:32` | `PerfilService.statsDemo = true` — liga o perfil inteiro em demonstração |
| `perfil_service.dart:130-137` | `ultimaConquista` **hardcoded como "Primeira Batida Real"**, subtítulo "desbloqueada hoje", sem id e sem data |
| `perfil_service.dart:47-56` | `_catalogoDemo` com quatro conquistas marcadas `desbloqueada: true` |
| `perfil_screen.dart:126-151` | `PerfilVM.mock()` com nome **"Sônia Rainha"** — dado pessoal da proprietária, vedado pela OS §7 |

O item mais grave para esta OS é o segundo: a tela **já exibe** "Primeira Batida
Real" para todo mundo, como enfeite. É exatamente o que a OS §5 proíbe. Trocá-lo
por estado vazio honesto é parte da entrega — mas só junto com a fonte real, porque
apagar o mock sem fonte deixaria a seção morta e não cumpre o objetivo da OS.
Não foi feito aqui: a OS §3 manda parar, não entregar meia conquista.

## 8. Diagrama — do evento autoritativo até o Perfil

O caminho **especificado**. Os trechos marcados `[AUSENTE]` não existem na base.

```
   MESA / MOTOR AUTORITATIVO                    [AUSENTE na base]
   partida chega ao fim
            |
            v
   DesfechoCanonicoPartida                      [existe só em politica-competitiva-v1]
   { partidaId, estado: encerrada, motivo,
     ladoVencedor, lados[assentos], encerradaEm,
     duplaQueBateuUltimaRodada }                <-- por DUPLA, não por jogador
            |                                       (bloqueio de regra, §1)
            v
   RESULTADO OFICIAL (Firestore)                [AUSENTE na base]
   partidas/{partidaId}
            |
            | gatilho onDocumentWritten
            v
   AVALIADOR DE CONQUISTAS (Functions)          [AUSENTE em todo o repositório]
   - filtra: final? motivo normal? elegível?
   - resolve assento -> uid
   - checa atribuição de batida ao jogador
   - transação condicionada à inexistência
            |
            v
   conquistas/{uid}/itens/primeira_batida_real  [AUSENTE]
   { id, obtidaEm: serverTimestamp,
     partidaId, categoria, raridade }
            |
            | Rules: leitura do dono; escrita NEGADA ao cliente
            v
   ConquistasService (Flutter)                  [AUSENTE — não há cloud_firestore]
            |
            v
   PerfilService.carregar()                     [existe, mas devolve mock]
            |
            v
   PerfilVM.ultimaConquista                     [existe, sem obtidaEm nem id]
            |
            v
   PerfilScreen._ultimaConquista                [existe e está pronto]
   card "Última Conquista" -> "Primeira Batida Real"
```

Dos oito elos, **cinco não existem** e um existe com o contrato errado. O único
trecho pronto é o último — o card.

## 9. O que precisa existir para desbloquear esta OS

Em ordem de dependência:

1. **Autoridade de encerramento publicando resultado oficial** com identidade de
   jogador (uid), não apelido, e com motivo de encerramento distinguível
   (normal / abandono / WO / cancelada / anulada / empate).
2. **Atribuição de batida por jogador** no desfecho canônico — decisão de regra
   sobre dupla × jogador, e sobre última rodada × qualquer rodada (§3).
3. **Elegibilidade de partida**: marcar partida humana/oficial e separá-la de
   partida contra robô e de fixture. Hoje, na base, **toda** partida é local e
   contra robôs, e `OnlineService` nem sequer abre a Mesa.
4. **Domínio de conquistas no backend**: coleção, avaliador, idempotência e Rules.
5. **`cloud_firestore` no cliente** e um `ConquistasService` real.
6. **`obtidaEm` nos modelos** `UltimaConquista` e `Conquista`.

Itens 1, 4 e 5 são trabalho de outra linhagem. Itens 2 e 3 são decisão da
proprietária antes de qualquer código.
