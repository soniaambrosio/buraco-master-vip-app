# Origem dos ícones do Tema Real VIP — Ajustes

Este é o **registro de origem** exigido pela §6 da OS do Tema Real VIP. Ele
existe antes dos arquivos de propósito: enquanto uma linha da tabela não tiver
origem e aprovação preenchidas, o arquivo correspondente **não pode entrar na
árvore**, e o Tema Real continua desligado.

## Estado atual

**NENHUM dos 28 arquivos existe.** A varredura de `app/assets/` nas 203 refs
remotas do repositório devolve doze diretórios — `baralho`, `loja`, `perfil`,
`ranking`, `torneios`, `colecoes`, `inicio`, `configurar_mesa`, `hall`,
`mesa_vip`, `splash`, `sons` — e nenhum ícone de Ajustes em nenhum deles.

Por isso `kConjuntoRealVipRegistrado` está em `false` em
`app/lib/tema/conjunto_real_vip.dart`, e **todo mundo — inclusive o assinante VIP
em dia — recebe o Tema Padrão**. Isso é o fallback integral da §7 funcionando,
não uma degradação.

## Requisitos de cada arquivo (§6)

* linguagem dourada, preta e roxa, coerente com a paleta da tela
  (`#EFB94A` ouro, `#B36CFF` roxo, fundo `#080503`);
* fundo transparente REAL (canal alfa, não branco);
* proporção quadrada e margem interna equivalente entre os 28;
* legível a **18 px** sobre fundo escuro — é esse o tamanho de desenho na tela;
* sem texto embutido (a tela é traduzível, o ícone não);
* sem depender de brilho excessivo para se distinguir;
* `.webp` com resolução adequada, ou vetor convertido;
* nome de arquivo **estável** e igual ao da tabela;
* nunca carregado por URL externa — o `pubspec.yaml` é o único caminho.

Nesta V1 os ícones são **estáticos**: sem animação contínua, cintilação ou
partículas automáticas.

## Tabela

Preencher `Origem` e `Aprovação` no mesmo commit em que o arquivo entrar.

| # | Arquivo (`app/assets/ajustes/real/`) | Chave | Desenho previsto (§5) | Origem | Aprovação |
|---|---|---|---|---|---|
| 1 | `editar_perfil.webp` | `editarPerfil` | pena ou espelho real | — | — |
| 2 | `assinatura_vip.webp` | `assinaturaVip` | diamante coroado | — | — |
| 3 | `fichas_e_compras.webp` | `fichasECompras` | moeda ou baú real | — | — |
| 4 | `musica.webp` | `musica` | lira dourada | — | — |
| 5 | `efeitos_sonoros.webp` | `efeitosSonoros` | trombeta real | — | — |
| 6 | `vibracao.webp` | `vibracao` | joia vibrante | — | — |
| 7 | `notificacoes.webp` | `notificacoes` | sino imperial | — | — |
| 8 | `animacoes.webp` | `animacoes` | estrelas reais | — | — |
| 9 | `ordenar_cartas.webp` | `ordenarCartas` | baralho ornamentado | — | — |
| 10 | `mao.webp` | `mao` | luva real | — | — |
| 11 | `presenca_online.webp` | `presencaOnline` | esmeralda | — | — |
| 12 | `convites.webp` | `convites` | envelope lacrado | — | — |
| 13 | `jogadores_bloqueados.webp` | `jogadoresBloqueados` | escudo real | — | — |
| 14 | `como_jogar.webp` | `comoJogar` | livro dourado | — | — |
| 15 | `suporte.webp` | `suporte` | balão ornamentado | — | — |
| 16 | `avaliar_aplicativo.webp` | `avaliarAplicativo` | estrela coroada | — | — |
| 17 | `secao_conta.webp` | `secaoConta` | brasão de conta | — | — |
| 18 | `secao_som_e_notificacoes.webp` | `secaoSomENotificacoes` | corneta real | — | — |
| 19 | `secao_jogo.webp` | `secaoJogo` | naipes ornamentados | — | — |
| 20 | `secao_privacidade.webp` | `secaoPrivacidade` | selo lacrado | — | — |
| 21 | `secao_geral.webp` | `secaoGeral` | cetro | — | — |
| 22 | `titulo_ajustes.webp` | `tituloAjustes` | engrenagem coroada | — | — |
| 23 | `confirmar_descarte.webp` | `confirmarDescarte` | pergaminho conferido | — | — |
| 24 | `chat_publico.webp` | `chatPublico` | balão ornamentado (par) | — | — |
| 25 | `idioma.webp` | `idioma` | globo dourado | — | — |
| 26 | `termos_e_privacidade.webp` | `termosEPrivacidade` | pergaminho selado | — | — |
| 27 | `orientacao_mesa.webp` | `orientacaoMesa` | moldura girando | — | — |
| 28 | `saldo_de_fichas.webp` | `saldoDeFichas` | ficha real | — | — |

## Fora da tabela, e de propósito

Seis chaves do contrato **não** ganham desenho luxuoso, e a ausência delas aqui
é a prova disso:

| Chave | Por quê |
|---|---|
| `voltar`, `avancar`, `expandir`, `confirmar` | afordância de direção, não símbolo: dourar uma seta não a torna mais seta |
| `sair`, `excluirConta` | §11.4 — ação destrutiva não pode parecer prêmio VIP |

## Como ativar

1. colocar os 28 arquivos em `app/assets/ajustes/real/`;
2. declarar `assets/ajustes/real/` em `app/pubspec.yaml` (**não** está declarado
   hoje: o Flutter reprova o build quando um diretório declarado não existe);
3. preencher `Origem` e `Aprovação` de cada linha desta tabela;
4. virar `kConjuntoRealVipRegistrado` para `true`, no **mesmo commit**.

O gate `temavip` reprova quem virar a chave sem os arquivos e quem acrescentar
arquivo sem chave. Não há como ativar pela metade.
