# Perfil VIP — Fase 1 (dados reais) · para commit na branch `soniaambrosio-patch-1`

Parceiro Codex fez a **cara** (a tela). Esta fase liga a tela aos **dados** — sem
mexer em nada do visual. São **3 arquivos**:

| Arquivo | Onde vai | O que é |
|---|---|---|
| `app/lib/services/perfil_service.dart` | **novo** | busca o perfil (nome real do Firebase + números) |
| `app/lib/pages/perfil_page.dart` | **novo** | controlador: carrega, trata estados e liga os 14 botões |
| `app/lib/main.dart` | **substitui** o da branch | agora abre o `PerfilPage` em vez do mock |

## O que mudou no `main.dart` (só 2 pontinhos)
1. Troquei o import `screens/perfil_screen.dart` por `pages/perfil_page.dart`.
2. O `_abrirPerfil()` agora faz `Navigator.push(... PerfilPage())` — 6 linhas no lugar
   das ~38 do mock. **Não toquei em mais nada** do arquivo.

> A tela do Codex (`perfil_screen.dart`) e os assets (`assets/perfil/`) **ficam como
> estão** — não precisa reenviar.

## O que já funciona agora
- **Nome de verdade**: puxa `displayName` do Firebase (quem logou com Google vê o
  próprio nome; sem login, aparece "Jogador(a)").
- **Estados reais**: carregando → normal → erro (com botão "tentar de novo" ligado).
- **Compartilhar**: copia um convite pronto pra área de transferência.
- Os botões de telas que ainda não existem (config, editar, loja, ranking) dão um
  avisinho simpático "chega nas próximas fatias 👍".

## Um detalhe pra você decidir (o "botão" da Fase 2)
Como a mesa **ainda não grava** resultado (isso é a Fase 2, com Firestore), os
**números** do perfil (nível 24, 342 vitórias, etc.) são de **demonstração** — pra
tela continuar cheia e bonita nos prints. Isso fica num interruptor só, no topo do
`perfil_service.dart`:

```dart
static const bool statsDemo = true;   // true = números de exemplo (atual)
                                       // false = jogador novo honesto (nível 1, tudo zerado)
```

O **nome é sempre real**, independente disso. Quando a gente fizer a Fase 2, esse
`carregar()` passa a ler do banco e o interruptor some. É só me avisar qual dos dois
você prefere ver no APK agora. 👑
