# Mesa VIP — vestido de gala

## Escopo

Refinamento final da camada visual da mesa do Buraco Master VIP, preservando integralmente regras, pontuação, turnos, robôs, Firebase e validações do motor.

## Ajustes aplicados

- Conteúdo da mesa centralizado e limitado a 430 dp para manter proporções estáveis em celulares de diferentes larguras.
- Cabeçalho responsivo com o título **BURACO MASTER VIP** completo e selo **MESA VIP**.
- Faixas das duplas com larguras estáveis, nomes completos e placares centralizados.
- Painéis superior, central e inferior alinhados com dimensões previsíveis.
- Cartas dos jogos baixados ampliadas e padronizadas em 48 × 72 dp.
- Cartas do monte, lixo e mortos padronizadas em 52 × 78 dp.
- Dorsos ampliados, sem versão reduzida nos mortos.
- Mão do jogador ampliada para 66 × 99 dp, com sobreposição fixa de 50% e rolagem horizontal quando necessária.
- Área segura inferior respeitada para impedir corte das cartas pela navegação do Android.
- Faixa permanente de instrução da vez removida.
- Mensagens aparecem somente em situações de erro, confirmação ou orientação realmente necessária.
- Compra no monte ou lixo mantém o som de carta e destaca temporariamente as cartas que entraram na mão.
- A origem da compra também recebe brilho temporário no painel central.
- Carta recém-comprada recebe elevação, escala, borda dourada/ametista e selo de brilho por aproximadamente 1,85 s.

## Limites preservados

Não foram alterados:

- distribuição e embaralhamento;
- regras de compra do monte ou lixo;
- descarte;
- baixar e estender jogos;
- canastras e pontuação;
- morto;
- turnos e inteligência dos robôs;
- autenticação, Perfil VIP ou Firebase.

O único estado adicional é estritamente visual e temporário: identificação das cartas recém-compradas para animação e destaque.

## Arquivo alterado

`app/lib/main.dart`
