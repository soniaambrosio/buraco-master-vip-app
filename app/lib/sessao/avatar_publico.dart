// avatar_publico.dart — a REGRA ÚNICA de como um `avatarRef` vira desenho.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTE ARQUIVO EXISTE PARA FECHAR
// ---------------------------------------------------------------------------
//
// A Home lia `identidade?.avatarRef ?? '👑'` e o Perfil escrevia `avatar: '👑'`
// direto no produtor do seu view-model. Eram DUAS autoridades visuais sobre o
// mesmo campo: quem tivesse um `avatarRef` gravado em `publicProfiles` o via no
// cabeçalho da Home e não o via no próprio Perfil, que apresentava a coroa fixa
// como se fosse o avatar escolhido.
//
// A coroa em si nunca foi o problema — ela É o fallback oficial, e a Home já a
// usava nesse papel. O problema era o Perfil usá-la INCONDICIONALMENTE, o que a
// transforma de "não há avatar escolhido" em "o avatar escolhido não importa".
//
// Agora as duas telas fazem a mesma pergunta a este arquivo, e ele é o único
// lugar do cliente que sabe responder.
//
// ---------------------------------------------------------------------------
// POR QUE UMA FUNÇÃO PURA, E NÃO UM WIDGET
// ---------------------------------------------------------------------------
//
// Home e Perfil já têm, cada uma, o seu renderizador — `_AssetOrText` em
// `screens/inicio_screen.dart` e `_icone` em `screens/perfil_screen.dart` —, e
// os dois seguem a MESMA convenção: valor que começa com `assets/` é imagem,
// qualquer outro é texto. O que divergia não era o desenho; era o VALOR que
// chegava até ele. Trocar os dois renderizadores por um widget comum seria
// mexer no visual aprovado das duas telas para resolver um problema que não é
// de visual.
//
// Sendo função pura, ela também não abre consulta nenhuma: recebe o estado
// canônico que a sessão já carregou (`IdentidadePublica`) e devolve uma string.
// Não conhece Firebase, não conhece `BuildContext` e não guarda cache — o cache
// de identidade é da sessão, e é lá que a troca de jogador o invalida.
//
// ---------------------------------------------------------------------------
// O QUE NUNCA SAI DAQUI
// ---------------------------------------------------------------------------
//
// Uma referência que este arquivo não reconhece vira FALLBACK, e não vira
// tentativa. Em especial ela nunca é devolvida quando poderia ser lida como:
//
//   * endereço de rede — `_AssetOrText` chama `Image.network` para qualquer
//     valor iniciado por `http://` ou `https://`. Um `avatarRef` adulterado
//     viraria uma requisição para o servidor de quem o gravou;
//   * caminho de asset — `assets/...` faria o widget procurar um arquivo que
//     ninguém empacotou, e um `avatarRef` passaria a poder apontar para arte de
//     outra tela;
//   * caminho relativo — `../` sai do lugar previsto.
//
// A recusa não depende de uma lista de coisas ruins que alguém precisa lembrar
// de manter. Depende de [kFormatoAvatarPublico], que é uma lista curta de
// coisas boas: minúsculas, dígitos, `-` e `_`. `:`, `/`, `.`, `<`, `>` e espaço
// estão fora do alfabeto, e é por isso que os três casos acima caem sozinhos.

import 'identidade_publica_sessao.dart';

/// O fallback OFICIAL do avatar público — em toda tela, sem exceção.
///
/// NÃO É INVENÇÃO DESTA CAMADA: é o valor que a Home de produção já usava
/// quando `avatarRef` não vinha (`identidade?.avatarRef ?? '👑'`), promovido a
/// constante para que o Perfil pare de manter a sua própria cópia do literal.
///
/// Ele é fallback, e só isso. Um `avatarRef` reconhecido SEMPRE ganha dele —
/// é essa precedência que [avatarPublicoDe] garante e que a matriz de testes
/// persegue. As outras coroas do aplicativo (o selo de VIP no Saguão, o emoji
/// do convite, a marca de Rei/Rainha do Hall) são ornamento e nada têm a ver
/// com este valor.
const String kAvatarPublicoFallback = '👑';

/// O formato aceito para uma referência de avatar.
///
/// ESPELHA `kFormatoAvatarRef` de `lib/social/apresentacao.dart`, que é a
/// autoridade do lado do servidor (o domínio social compila para as Cloud
/// Functions e recusa a GRAVAÇÃO de qualquer referência fora deste alfabeto).
///
/// A cópia é deliberada, e não descuido: `test/sessao/auditoria_identidade_test
/// .dart` proíbe qualquer arquivo do cliente de importar `lib/social/` — puxar
/// aquele módulo traria junto a fórmula de geração de `publicId`, que é
/// exatamente o que o app não pode conhecer. Em troca da cópia,
/// `avatar_publico_canonico_test.dart` compara os dois padrões caractere a
/// caractere: se um dia divergirem, cai um teste, e não o desenho da tela.
final RegExp kFormatoAvatarPublico = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$');

/// O que desenhar no lugar do avatar de [identidade].
///
/// Atalho de [avatarPublicoDe] para o caso normal — a identidade pública da
/// sessão, que pode não existir ainda (carregando, falha, logout). Sem
/// identidade não há avatar escolhido, e o fallback é a resposta certa.
String avatarPublicoDaIdentidade(IdentidadePublica? identidade) =>
    avatarPublicoDe(identidade?.avatarRef);

/// O que desenhar, dado o `avatarRef` cru vindo de `publicProfiles`.
///
/// A regra inteira, em ordem:
///
///   1. ausente (`null`), vazio ou só espaços .... fallback;
///   2. fora de [kFormatoAvatarPublico] ........... fallback;
///   3. reconhecido ............................... a própria referência.
///
/// O CASO 3 NÃO FABRICA CAMINHO. Devolve a referência como ela veio (aparadas
/// as bordas), e quem desenha aplica a mesma convenção que já aplicava. Mapear
/// `coruja_dourada` para `assets/avatares/coruja_dourada.webp` seria inventar
/// um catálogo: `kCatalogoAvatares` está vazio nesta árvore, e o backend
/// registra isso no contrato (`catalogoDeAvatarDisponivel: false`). No dia em
/// que o catálogo existir, é este arquivo que passa a consultá-lo — e nenhuma
/// das duas telas muda.
String avatarPublicoDe(String? avatarRef) {
  // `trim` antes de tudo: '   ' é ausência escrita com espaços, e '  coruja  '
  // é a mesma referência com sujeira de borda. Sem esta linha a Home desenharia
  // um círculo vazio no primeiro caso e o Perfil (que compara o valor cru)
  // poderia discordar dela no segundo.
  final ref = avatarRef?.trim() ?? '';
  if (ref.isEmpty) return kAvatarPublicoFallback;
  if (!kFormatoAvatarPublico.hasMatch(ref)) return kAvatarPublicoFallback;
  return ref;
}

/// O valor exibido é o fallback, e não uma escolha do jogador?
///
/// Existe para que teste e tela possam distinguir "não escolheu avatar" de
/// "escolheu um avatar que por acaso é uma coroa" sem espalhar comparações com
/// o literal por aí. Nenhuma referência válida pode ser igual ao fallback: a
/// coroa é um emoji, e emoji não passa por [kFormatoAvatarPublico].
bool avatarPublicoEhFallback(String avatar) => avatar == kAvatarPublicoFallback;
