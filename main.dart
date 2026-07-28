# Mesa VIP — Fase 1 visual (Codex)

## Escopo

Alterações exclusivamente visuais na `MesaScreen`, preservando integralmente as regras, estados, áudio, callbacks e fluxo da partida.

## Ajustes realizados

- Cabeçalho compacto e premium, com título, meta, rodada, menu e chat em uma única faixa.
- Placar deslocado para dentro das áreas de cada dupla, associado aos respectivos jogadores.
- Jogadores reorganizados em linhas simétricas, com avatares, mascotes, nomes e contagem de cartas.
- Feltro refinado com verde profundo, borda dourada discreta e sombras mais suaves.
- Faixa central de monte, lixo e mortos com acabamento mais limpo e hierarquia melhor.
- Barra de turno transformada em componente próprio, com estado visual para turno, espera e aviso.
- Reserva de espaço na área da dupla NÓS para reduzir colisão da barra de turno com jogos baixados.
- Badges de quantidade redesenhados com acabamento vinho/dourado.
- Textos vazios e instruções visuais simplificados.

## Limites respeitados

Não foram alterados:

- distribuição de cartas;
- compra do monte ou lixo;
- descarte;
- baixar ou estender jogos;
- validação de sequências;
- mortos;
- turnos dos robôs;
- pontuação;
- fim de rodada ou partida;
- áudio;
- Firebase ou autenticação.

## Arquivo alterado

- `app/lib/main.dart`

## Validação necessária

Executar o GitHub Actions na branch da Mesa VIP e testar no aparelho:

- ausência de overflow em 360, 394 e 430 dp;
- legibilidade de nomes e placar;
- toque em monte, lixo, jogos baixados e cartas da mão;
- barra de turno sem esconder informações essenciais;
- rolagem dos jogos baixados;
- animação e seleção da mão.
