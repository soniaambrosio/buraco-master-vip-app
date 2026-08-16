# Mesa canônica e fronteira de entrada

Data: 09/08/2026  
Branch: `codex/configuracao-mesas-fluxo`

## Decisão de fonte canônica

A `MesaScreen` de runtime a ser preservada na integração é a definida em:

`app/lib/mesa.dart`

Motivo: `main.dart` importa diretamente `mesa.dart` e o fluxo ativo instancia essa `MesaScreen`. O arquivo `app/lib/screens/mesa_screen.dart` é uma implementação visual paralela/protótipo e **não deve ser ligado ao servidor nem escolhido por engano durante a integração**.

Até uma eventual remoção futura, `app/lib/screens/mesa_screen.dart` deve ser tratado como legado/quarentena, não como segunda fonte de verdade.

## Separação entre ambiente e pele visual

Foram criados:

- `app/lib/screens/mesa_launch_spec.dart`
- `app/lib/screens/mesa_renderer_contract.dart`

`MesaLaunchSpec` preserva o contexto completo que precisa atravessar `Configurar → Preparando → Mesa`.

`MesaRendererContract` separa duas coisas que antes estavam misturadas:

1. **contexto da partida**: Pública, VIP ou Privada;
2. **pele do renderer**: Pública ou Premium.

Regra visual:

- Mesa Pública → contexto `publica` + pele `publica`;
- Mesa VIP → contexto `vip` + pele `premium`;
- Mesa Privada → contexto `privada` + pele `premium`.

A Mesa Privada usa a pele premium porque é um ambiente VIP. Isso **não** transforma a sala em Mesa VIP. Código, cadeiras, espectadores, composição de parceiro/oponentes, Passe Convidado e chat social continuam governados pelo contexto `privada`.

Essa separação substitui semanticamente o padrão perigoso do host legado:

`publica ? MesaVariant.publica : MesaVariant.vip`

Na ligação final, a conversão para o `MesaVariant` existente pode reutilizar `vip` como pele premium, mas o contexto privado deve continuar vivo em paralelo.

## Contrato de entrada na mesa

A cadeia recomendada é:

`ConfigMesaVM`
→ `MesaConfigContract`
→ validação visual (`validarMesaConfig`)
→ `PreparandoPartidaVM` (`prepararPartidaDaConfiguracao`)
→ `MesaLaunchSpec`
→ `MesaRendererContract`
→ adaptador autoritativo do Claude
→ `app/lib/mesa.dart::MesaScreen`

Nenhum desses contratos novos cria sala, movimenta moeda, valida assinatura, consome Passe Convidado ou decide autoridade.

## Escolhas que não podem desaparecer

Na travessia até a mesa devem sobreviver:

- ambiente Pública/VIP/Privada;
- modalidade ABERTO/FECHADO/STBL;
- 2 ou 4 jogadores;
- meta 1.500/3.000;
- tempo 15/30/45s;
- chat;
- aposta e pote;
- espectadores;
- código da Privada;
- cadeiras e composição da turma;
- contexto VIP/Passe Convidado;
- custo de criação.

## Pontos do host legado que devem ser substituídos na integração

O `_ConfigMesaPreviewHost` atual ainda:

- monta `PreparandoPartidaVM.mock(...)` em vez de usar o adaptador configurado;
- converte qualquer tipo não público em `MesaVariant.vip` sem preservar o contexto;
- envia para a `MesaScreen` somente modalidade, meta e tempo;
- contém uma ocorrência visível legada de `SBTL` no modal de regras;
- não transporta modo, chat, aposta, espectadores, código e cadeiras até o runtime.

Esses itens são ligação/hospedagem do fluxo, não redesenho das telas aprovadas.

## STBL

A grafia oficial é **STBL**.

O configurador, contratos e adaptadores novos já usam STBL. A ocorrência `SBTL` ainda presente no modal legado de `main.dart` deve ser alterada para `STBL` quando o host for substituído/ligado, sem qualquer alteração da regra de jogo.

## Modo de 2 jogadores

A animação visual de preparação já trabalha com a lista real de posições recebidas: duas posições geram duas distribuições; quatro posições geram quatro.

O motor de runtime atual, entretanto, ainda possui estrutura histórica de quatro assentos. O suporte autoritativo ao modo 1 × 1 é responsabilidade da ligação motor/servidor. A UI não deve simular quatro jogadores invisíveis para mascarar essa ausência.

## Regra para a integração

Claude pode adaptar dados e callbacks, mas não deve:

- reintroduzir seletor Pública/VIP/Privada dentro do configurador;
- transformar Privada semanticamente em VIP só porque compartilha a pele premium;
- remover o chat Livre ou as ações Silenciar/Bloquear/Denunciar da Privada;
- permitir cadeira privada ocupada sem VIP/Passe válido;
- pular a tela de configuração;
- voltar a usar o lobby privado legado como tela de criação;
- conectar `app/lib/screens/mesa_screen.dart` como runtime concorrente.
