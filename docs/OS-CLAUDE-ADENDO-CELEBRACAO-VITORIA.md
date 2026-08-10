# ADENDO À OS CLAUDE — Celebração de Vitória

Data: 10/08/2026

Este adendo é obrigatório e complementa `docs/OS-CLAUDE-INTEGRACAO-FLUXO-MESAS.md`.

## 1. Decisão de produto

Ao término **confirmado** de uma partida, a dupla vencedora deve receber uma celebração curta e elegante:

- confetes sobre a interface, destacando a dupla vencedora;
- banner curto `VITÓRIA!` com os nomes dos vencedores;
- som de vitória para os dispositivos dos integrantes da dupla vencedora;
- duração visual aproximada de 2 a 3 segundos;
- a tela normal de resultado continua disponível por baixo/na sequência.

A celebração padrão é gratuita e faz parte da experiência básica de vitória.

## 2. Áudio já existente

O repositório já contém:

`app/assets/sons/vitoria.mp3`

Usar `AssetSource('sons/vitoria.mp3')` como som padrão, respeitando a preferência de efeitos sonoros do usuário.

Falha ao tocar áudio nunca pode bloquear a tela de resultado.

## 3. Autoridade do resultado

A UI não decide o vencedor comparando placares localmente.

O servidor/motor autoritativo deve informar:

- identificador único do resultado/evento;
- assentos da dupla vencedora;
- confirmação de fim de partida.

Somente depois dessa confirmação a celebração pode disparar.

Fechamento de rodada intermediária não dispara a comemoração final.

Empate/resultado indefinido não dispara celebração de vitória.

## 4. Regra local de som e visual

- todos os jogadores podem ver os confetes e o destaque da dupla vencedora;
- o som de vitória toca localmente apenas para quem pertence à dupla vencedora;
- respeitar `efeitosSonoros == false`;
- não tocar o som repetidamente por rebuild, reconexão ou retry.

## 5. Idempotência

A celebração deve ser idempotente por `eventoId`/resultado confirmado.

O mesmo resultado não pode gerar novamente:

- som;
- confete;
- recompensa;
- prêmio;
- evento de estatística.

Reconexão pode reconstruir a tela, mas não deve transformar a vitória em máquina de confete infinita.

## 6. Componentes Flutter preparados

Foram adicionados:

- `app/lib/screens/vitoria_celebracao.dart`
- `app/lib/screens/resultado_vitoria_adapter.dart`
- `app/lib/screens/resultado_partida_celebrado.dart`
- `app/test/vitoria_celebracao_contract_test.dart`

### `CelebracaoVitoriaVM`

Carrega:

- `eventoId`;
- estado ativo;
- indicação se o jogador local venceu;
- nomes dos vencedores;
- preferência de som;
- `efeitoId`;
- duração.

### `CelebracaoVitoriaLayer`

- usa o áudio já existente;
- desenha confete via Flutter/CustomPainter, sem dependência externa;
- não intercepta toques;
- não altera estado da partida;
- executa uma vez por `eventoId` na instância.

### `celebracaoVitoriaDoResultado(...)`

Recebe os assentos vencedores **já autoritativos** e monta o VM. Não conhece regra esportiva nem infere parceria.

### `ResultadoPartidaCelebrado`

Wrapper neutro para acoplar celebração à `ResultadoPartidaScreen` sem duplicar/recriar o layout aprovado.

## 7. Efeitos premium

A celebração padrão não deve ser removida para quem não comprou cosmético.

Estratégia de monetização:

- padrão gratuito: confete + som `vitoria.mp3`;
- efeito premium equipado pode substituir ou enriquecer o visual padrão;
- exemplos futuros: chuva dourada, cartas, coroa, neon, fogo, glitter etc.;
- a troca do efeito é cosmética e não altera resultado, recompensa ou regra da partida.

`efeitoId = 'confete_padrao'` representa o fallback gratuito.

Se um efeito premium falhar ao carregar, voltar ao confete padrão.

## 8. Integração com ResultadoPartida

A tela existente `app/lib/screens/resultado_partida_screen.dart` continua sendo a tela aprovada de resultado.

Não redesenhar a tela.

Na abertura do resultado final:

1. receber resultado autoritativo;
2. montar `CelebracaoVitoriaVM`;
3. envolver `ResultadoPartidaScreen` com `ResultadoPartidaCelebrado`/`CelebracaoVitoriaLayer`;
4. disparar visual e som uma única vez;
5. manter botões de revanche, amizade, lobby e anúncio funcionando normalmente.

## 9. Orientação da Mesa

A celebração deve funcionar em Vertical e Horizontal.

A rotação durante/na chegada do resultado não pode repetir o `eventoId` nem o som.

O confete deve usar o tamanho disponível da tela e respeitar safe area quando necessário.

## 10. Critérios de aceite

A entrega só está concluída quando:

1. vitória confirmada dispara confete;
2. nomes da dupla vencedora aparecem no destaque;
3. integrantes vencedores ouvem `vitoria.mp3` uma vez;
4. perdedores não recebem som de vitória local;
5. `efeitosSonoros == false` silencia o som sem remover o visual;
6. rodada intermediária não comemora como fim de partida;
7. ausência de vencedor autoritativo não dispara festa;
8. rebuild/reconexão não duplica o evento;
9. Vertical e Horizontal funcionam;
10. os botões da tela de resultado continuam clicáveis;
11. efeito premium pode ser acoplado sem alterar a regra esportiva;
12. falha cosmética/áudio nunca bloqueia a partida ou o resultado.

## 11. Testes obrigatórios

Executar:

- `app/test/vitoria_celebracao_contract_test.dart`;
- widget test do overlay;
- teste com jogador local vencedor;
- teste com jogador local perdedor;
- teste com efeitos sonoros desligados;
- teste de idempotência/rebuild;
- teste em Vertical e Horizontal;
- testes existentes da tela de resultado e motor afetados.

Não declarar concluído apenas porque o componente existe: o runtime real deve fornecer os assentos vencedores e o `eventoId` confirmado.
