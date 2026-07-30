# Varredura geral de botões — Buraco Master VIP (Claude)
_Auditoria de todo o `app/lib`: botões sem ação, stubs e sincronização com a branch._

## 🟥 1. MORTOS SILENCIOSOS (tocou, não acontece NADA — nem aviso) — 3
Esses são os que "não têm ligação" de verdade. Prioridade de conserto:

| Tela | Botão | Onde | Hoje faz |
|---|---|---|---|
| Hall dos Imortais | **Regras do Hall** (i + botão) | `main.dart:853` `onVerRegras` | `() {}` — nada |
| Hall dos Imortais | **Enviar presente** (abrir seletor) | `main.dart:855` `onPresentear` | `(id) {}` — nada |
| Loja | **Busca** no presentear item | `main.dart:824` `onBuscarPresenteado` | `(_) {}` — não filtra |

> Obs.: `onEnviarPresente` do Hall (mandar o presente escolhido) já dá feedback; só o
> **abrir o seletor** (`onPresentear`) está mudo.

## 🟨 2. STUBS "fica com o Claude" / "em breve" (dão aviso, mas a ação real é backlog MEU)
Não são bugs do Codex — são pontos onde o Codex fez a interface e **deixou a lógica pra mim**.
A maioria depende de infra da Fase B (Firestore, Google Play Billing, servidor de amigos/salas).

- **Início:** Histórico, Temporada (topo) · nav **Temporadas**, nav **Loja VIP**.
- **Ranking:** Convidar amigo · Ver jogador (perfil da posição).
- **Saguão:** Convidar por link, Convidar amigo, Assistir mesa, Abrir amigo, Entrar na mesa (código),
  Salão VIP bloqueado, Presentear jogador.
- **Configurações:** Suporte, Avaliar na Play, Bloqueados. _(Mão destro/canhoto e "Quem me convida"
  já MUDAM o estado na prévia — só falta refletir na mesa/servidor.)_
- **Loja:** Comprar moedas, Comprar pacote, Presentear item. _(billing = Fase B)_
- **Hall:** Ver perfil, Enviar presente (mandar), Estatísticas (nav).
- **Recompensas:** Resgatar missão, Resgatar login diário, Abrir Baú Real, Tocar numa fonte de XP.
- **Perfil:** Abrir config, Trocar avatar, Editar apelido, Editar perfil, Ver todas conquistas,
  Ver conquista, Ver última conquista, Trocar itens da vitrine.

> Todos esses **dão um aviso** ("integração fica com o Claude" / "em breve"), então o usuário
> percebe que registrou — não ficam mudos. Viram trabalho de lógica conforme a infra for entrando.

## 🟩 3. FALSOS POSITIVOS (parecem mortos, mas são de PROPÓSITO — não mexer)
- `main.dart:4137` e `3298` `onTap: () {}` / zoom → absorvem o toque pra **não fechar o modal**
  ao clicar no conteúdo (padrão Flutter). Corretos.
- `perfil_page` `onAbrirPresentes` / `onFecharPresentes` → o bottom-sheet de presentes é **interno
  à tela**; o host não precisa fazer nada. Correto.
- **Jogar Treino** (Como Jogar) → o texto do aviso engana, mas ele **ABRE A MESA** de verdade. OK.
- `onAssinar` (Saguão/Loja) → ativa o VIP na prévia (`ehVip=true`) + avisa que o billing é Fase B. OK.

## 🔵 4. SINCRONIZAÇÃO com a branch publicada (o "não está no app")
Comparei **arquivo por arquivo** o meu tronco com a branch `codex/inicio-ui` publicada:
- **TODAS as 17 telas estão IDÊNTICAS** — as mudanças visuais do Codex (loja, hall, splash,
  preparando, configurações, como jogar, onde jogar, etc.) **já estão na branch/publicadas**.
- O **único** arquivo diferente é o `main.dart` (só os meus ajustes de HOJE: robô pega lixo,
  ordenação crescente, cronômetro, vulnerabilidade, Firebase web).
- A última entrega do Codex (02:29, "mesa ordenação") continha **só** a ordenação da mão, que eu
  já refiz como crescente. Não havia outra mudança visual escondida ali.

➡️ **Conclusão:** se as mudanças visuais não aparecem no seu app, é porque o **APK instalado é
antigo**. Rebuild o APK (ou usa o link web quando subir) e elas aparecem — elas já estão na branch.

### Lixo pra limpar na branch (opcional, não quebra nada hoje)
`main_1.dart`, `main_3.dart` (vazios), pasta duplicada `app/lib/app/lib/…`, e telas mortas
`mesa_screen.dart` / `mesa_vip_preview_screen.dart` (não são importadas). Dá pra apagar depois.
