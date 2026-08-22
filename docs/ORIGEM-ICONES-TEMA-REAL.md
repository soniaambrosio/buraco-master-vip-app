# Origem dos ícones do Tema Real VIP — Ajustes

Este é o **registro de origem** exigido pela §6 da OS do Tema Real VIP. Ele
nasceu vazio, antes dos arquivos, de propósito: enquanto uma linha não tivesse
origem e aprovação preenchidas, o arquivo correspondente não podia entrar na
árvore.

**As 28 linhas estão preenchidas.** O conjunto foi incorporado, o diretório foi
declarado no `pubspec.yaml` e `kConjuntoRealVipRegistrado` está em `true`.

## Procedência do conjunto

| item | valor |
| --- | --- |
| pacote | `tema-real-vip-assets-v1.zip` |
| SHA-256 do pacote | `8ef236fd64f9a3bf0c4dcddcd9bf5da3f86a29f788ac0d860658a74bcc99c3b6` |
| tamanho do pacote | 4.582.157 bytes |
| manifesto do pacote | `MANIFESTO-ASSETS-TEMA-REAL-V1.md` + `SHA256SUMS.txt` (28 linhas) |
| painel visual | `PAINEL-28-ASSETS-TEMA-REAL-V1.png` |
| prova de redução | `QA-LEGIBILIDADE-18PX.png` |
| **Origem** | arte original produzida sob direção da proprietária, com geração de imagem OpenAI, em 22/08/2026 |
| **Aprovação** | Sônia Ambrósio, 22/08/2026 |
| data de produção | 22/08/2026 |

`titulo_ajustes.webp` foi produzido primeiro e aprovado como **mestre de
linguagem visual**; os outros 27 nasceram a partir dessa referência, sem cópia de
catálogo externo. Fundos artificiais foram removidos por edição, preservando o
desenho e produzindo alfa real.

Os arquivos entraram **byte a byte** como saíram do pacote: nenhum foi renomeado,
recomprimido, reenquadrado, recolorido ou reexportado. Os SHA-256 da tabela
abaixo foram recalculados sobre os arquivos JÁ na árvore e conferem, um a um, com
o `SHA256SUMS.txt` do pacote.

> O manifesto do pacote traz a linha *"Aprovação individual do painel completo:
> pendente de confirmação da proprietária antes da ativação"*. Ela descreve o
> estado em que o pacote foi fechado. A aprovação veio depois, em 22/08/2026, e é
> a que autoriza esta incorporação — o manifesto não foi editado porque ele é
> evidência de origem, e evidência não se corrige retroativamente.

## Características verificadas

Todos os 28, conferidos por leitura de cabeçalho e por decodificação real na
suíte `temavip`:

* **WebP lossless** (`RIFF`/`WEBP`/`VP8L`, assinatura `0x2F`);
* **256 × 256 px**;
* **canal alfa real** — cada arquivo tem pixel totalmente transparente E pixel
  totalmente opaco, que é o que distingue recorte de fundo pintado;
* nenhum inteiramente transparente;
* sem fundo branco ou xadrez incorporado — os quatro cantos são transparentes;
* legíveis reduzidos a 18 px, que é o tamanho de desenho na tela;
* sem texto, letra, número, marca d'água ou URL;
* estáticos: sem animação, cintilação ou partícula;
* carregados **somente** pelo `AssetBundle` do aplicativo.

Paleta: ouro `#EFB94A`, roxo `#B36CFF`, fundo `#080503`.

## Tabela — os 28 arquivos, na ordem das chaves

Origem e aprovação são as da seção *Procedência* e valem para as 28 linhas.

| # | Arquivo (`app/assets/ajustes/real/`) | Chave | Desenho | SHA-256 | bytes |
|---:|---|---|---|---|---:|
| 1 | `editar_perfil.webp` | `editarPerfil` | espelho real e pena | `8a2d81da512bf44c41822df2dd9a79332b3849aa569573e507b358034df086b5` | 55268 |
| 2 | `assinatura_vip.webp` | `assinaturaVip` | diamante coroado | `b93a1445e893c55ce7eb458a405d8d0ce8e0cd7ca9685b3bf3da0142ff5f9c45` | 53386 |
| 3 | `fichas_e_compras.webp` | `fichasECompras` | baú real e fichas | `a4ed40a0645cab6baf6a17a57c80663c443e165c1f6d097e47685c2aace0f60f` | 70624 |
| 4 | `musica.webp` | `musica` | lira dourada | `aab5866f36beb99f84420fe8398dff4c0c85a39e1b1de7c43c0086774d973350` | 60620 |
| 5 | `efeitos_sonoros.webp` | `efeitosSonoros` | trombeta real | `db9a0928db0fb72bd7ef4dcf11082cd5dd0ea7e901305b6448b312b2085fc9f1` | 41634 |
| 6 | `vibracao.webp` | `vibracao` | joia vibrante | `b40b95fb0523be3656b6f5654481dc4f6059828f144e57781ef0015fa7f1cd30` | 35536 |
| 7 | `notificacoes.webp` | `notificacoes` | sino imperial | `cf4f8c3908fa35b9b6404dcb32fc2735de8dea0a3120493da4fa7fd515064dbc` | 39178 |
| 8 | `animacoes.webp` | `animacoes` | estrelas reais | `a820c2aeec9315cbd5e0f4d365817917e850fcc1274a9a114d7b5e4aeae63666` | 49228 |
| 9 | `ordenar_cartas.webp` | `ordenarCartas` | baralho ornamentado | `ebb6d41c90ba636454f0a6a1d48c4dabfe369250c9e91615e83a4e23214d9266` | 48922 |
| 10 | `mao.webp` | `mao` | luva real | `9d4ba7346c4818b34324ca9931643f870677573684754cc599d5caffb134924e` | 46934 |
| 11 | `presenca_online.webp` | `presencaOnline` | esmeralda com presença | `c4c1eb811e2f045e52eea73335eb2f6516162fff973724f260469bc6a3280aaf` | 54966 |
| 12 | `convites.webp` | `convites` | envelope lacrado | `ca7a1d3fe919216ffe2f036e97863e350ec978a6e395991f2e1740f4e98b836c` | 47410 |
| 13 | `jogadores_bloqueados.webp` | `jogadoresBloqueados` | escudo de bloqueio | `2698f28b93e311c96040e4ca37cc500de00d4f8a53110b661de36b6f4a047d98` | 60162 |
| 14 | `como_jogar.webp` | `comoJogar` | livro dourado | `b5fa759df9a5cad73cf8a93e2e5a107a203b24ba3c03193e5f97e7cf556e8de1` | 44024 |
| 15 | `suporte.webp` | `suporte` | balão ornamentado e mão | `efd1ea80bbd991aeef0543d6dfc660f481a8ac36e8d4d1d70236328aabe15411` | 48618 |
| 16 | `avaliar_aplicativo.webp` | `avaliarAplicativo` | estrela coroada | `6cee0fc959dab25140fc7104d4eebd7e76e501d57998936a31dc10638e492810` | 49562 |
| 17 | `secao_conta.webp` | `secaoConta` | brasão de conta | `a01fe79375c8ea505fc97a17ff82b14c76037dad973ac2f7b1cd298f65a24856` | 57452 |
| 18 | `secao_som_e_notificacoes.webp` | `secaoSomENotificacoes` | corneta e sino | `5f88111d7fbefaf0f1b4b592e5ea6fd994b113ccc37b3e800a5f9e130fb7f299` | 55612 |
| 19 | `secao_jogo.webp` | `secaoJogo` | naipes ornamentados | `d06bebfb7ad918e90d0bc5d2021f4fdfba5601144d6addfd52dd8af4a114253b` | 56522 |
| 20 | `secao_privacidade.webp` | `secaoPrivacidade` | selo com fechadura | `89e0c913d90c36ec92933bedbd3d94d177bda1f5b9abe834cb7a5c06f2435b34` | 59890 |
| 21 | `secao_geral.webp` | `secaoGeral` | cetro real | `edca9681f7986d85b537646c55a707d0ce93a9298578ea07d524596cb2d063fa` | 27372 |
| 22 | `titulo_ajustes.webp` | `tituloAjustes` | engrenagem coroada | `b5a804424d2aba06fe9afc6929bfb7c7b8cdda41fcf3e3abe86cee049a9afd2b` | 52608 |
| 23 | `confirmar_descarte.webp` | `confirmarDescarte` | pergaminho conferido | `5253ef584a68396f16b0860f9657170372e7f744f6a2fec8cc1ed304d73a4b8e` | 47930 |
| 24 | `chat_publico.webp` | `chatPublico` | par de balões ornamentados | `f3b1c526595707442a350620d9bb717f7ff80e64bdda83f8149314ae2dcaabcd` | 44168 |
| 25 | `idioma.webp` | `idioma` | globo dourado | `b013eb3c67e503b03b55fefa8b042c280c9b0189900ff38521e6015d9bf82e88` | 66550 |
| 26 | `termos_e_privacidade.webp` | `termosEPrivacidade` | pergaminho selado | `2ebdf9861f700419838582da938ed834272ea472a36a6747c1571df292b23e31` | 53210 |
| 27 | `orientacao_mesa.webp` | `orientacaoMesa` | molduras com rotação | `5d9d7232a27bef442a7cc21651ca4eb8a93430a876b64324d2380f81403498d1` | 39148 |
| 28 | `saldo_de_fichas.webp` | `saldoDeFichas` | fichas reais | `b1e4dba34be2187b12d2d61ed0ef2015e3f0c3a6d2c430191e8f08e21318caaa` | 48708 |

## Fora da tabela, e de propósito

Seis chaves do contrato **não** ganham desenho luxuoso, e a ausência delas aqui é
a prova disso:

| Chave | Por quê |
|---|---|
| `voltar`, `avancar`, `expandir`, `confirmar` | afordância de direção, não símbolo: dourar uma seta não a torna mais seta |
| `sair`, `excluirConta` | §11.4 — ação destrutiva não pode parecer prêmio VIP |

São **34 chaves** no contrato: 28 variáveis (a tabela acima) + 6 invariantes
(esta tabela).

> **Cuidado com a enumeração.** Qualquer lista que diga "28" e mostre 27 está
> errada, e a que costuma escapar é `secao_jogo.webp` — ela fica no meio das
> cinco chaves de seção, entre `secao_som_e_notificacoes` e `secao_privacidade`,
> e é a única cujo nome não aparece em nenhum rótulo da tela. O laudo da folha
> anterior omitiu exatamente essa linha; está corrigido lá.

## Se um dia a arte for trocada

1. substituir os arquivos em `app/assets/ajustes/real/`, mantendo os NOMES;
2. recalcular os SHA-256 e atualizar a tabela acima **no mesmo commit**;
3. atualizar a assinatura da suíte `temavip` na fonte única de gates.

O nome do arquivo acompanha a AÇÃO, não o desenho — "diamante coroado" pode virar
"coroa com diamante" na segunda versão da arte sem que uma linha de código mude.
