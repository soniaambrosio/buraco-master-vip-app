# Mesa VIP — Layout definitivo (Codex)

Ajustes estritamente visuais aplicados conforme a orientação aprovada:

- três containers verticais em proporção exata 41% / 18% / 41%;
- containers superior, central e inferior com a mesma largura útil fixa dentro da mesa responsiva;
- superior e inferior com exatamente o mesmo flex e a mesma altura;
- quatro células centrais iguais para monte, lixo, morto 1 e morto 2;
- usuário preservado no canto inferior direito;
- cartas baixadas padronizadas em 54 × 81 dp;
- sobreposição fixa de 50% nas cartas de cada jogo, sem compressão dinâmica por quantidade de cartas ou jogos;
- monte, lixo e mortos padronizados em 54 × 81 dp;
- mão em 68 × 102 dp, com sobreposição fixa de 50%;
- fora da vez, a mão mantém a escala e fica 50% oculta na base;
- na vez, a mão sobe verticalmente em 300 ms e fica totalmente visível;
- retirada da legenda permanente da mão;
- feedback sonoro e destaque da compra preservados.

Não foram alteradas regras, validações, pontuação, robôs, Firebase ou contratos de dados.
- As quatro células do container central usam `Expanded` iguais, eliminando variações de largura e risco de overflow.
- As quatro células do container central usam larguras exatamente iguais, sem variação pelo conteúdo.
