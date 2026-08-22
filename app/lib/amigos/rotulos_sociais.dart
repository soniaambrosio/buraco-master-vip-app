// rotulos_sociais.dart — as PALAVRAS do social, num lugar só.
//
// Domínio puro: só entram `String` e os tipos de `estado_social.dart`. Não
// importa Flutter, e por isso é testável sem `WidgetTester`.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO PARA TEXTO
// ---------------------------------------------------------------------------
//
// Porque duas superfícies mostram a MESMA relação — a linha da tela de Amigos e
// a faixa do Perfil visitado —, e com os textos escritos dentro de cada uma
// elas divergem na primeira correção feita numa só. Divergir aqui não é feio:
// é a mesma amizade sendo chamada de "Amigos" numa tela e "Vocês são amigos"
// noutra, e o jogador não tem como saber se são a mesma coisa.
//
// Mais grave é a divergência dos RECADOS DE RECUSA. Cada frase aqui é uma
// decisão sobre o que o aplicativo pode dizer, e algumas são decisões de
// privacidade — ver [textoDaFalhaSocial]. Espalhadas, a próxima tela social
// escreveria a sua versão sem saber que havia uma regra.
//
// ---------------------------------------------------------------------------
// A REGRA QUE VALE PARA TODAS AS FRASES
// ---------------------------------------------------------------------------
//
// Nenhuma delas revela o que o contrato esconde. `RelacaoSocial.indisponivel` é
// UM estado para DOIS fatos diferentes — o outro me bloqueou, ou há sanção
// social — e o texto não distingue os dois, porque o backend deliberadamente
// não conta qual é. E nenhum código de recusa cru chega à tela: `recusa` existe
// para o log e para o `switch` daqui, não para ser lido por quem joga.

import 'estado_social.dart';

/// Como CHAMAR a relação na tela.
///
/// DESCREVE, e não autoriza. Quem autoriza é [ResultadoSocial.acoes], e a
/// separação é o coração do módulo — ver o cabeçalho de `estado_social.dart`.
///
/// `null` para [RelacaoSocial.nenhuma] e [RelacaoSocial.desconhecida], e o nulo
/// é a resposta certa nos dois casos por motivos diferentes: "vocês não são
/// nada" não é informação, e "o servidor disse algo que eu não entendi" não
/// pode virar palpite. Quem desenha simplesmente não mostra faixa.
String? rotuloDaRelacao(RelacaoSocial relacao) => switch (relacao) {
  RelacaoSocial.amigos => 'Amigos',
  RelacaoSocial.solicitacaoEnviada => 'Pedido enviado',
  RelacaoSocial.solicitacaoRecebida => 'Quer ser seu amigo',
  RelacaoSocial.bloqueadoPorMim => 'Bloqueado por você',
  RelacaoSocial.indisponivel => 'Indisponível',
  RelacaoSocial.euMesmo => 'Você',
  RelacaoSocial.nenhuma || RelacaoSocial.desconhecida => null,
};

/// O rótulo do BOTÃO de uma ação.
///
/// VERBO, e não estado: "Aceitar", nunca "Pedido recebido". Um botão rotulado
/// com o estado atual não diz o que vai acontecer ao ser tocado.
String verboDaAcao(AcaoSocial acao) => switch (acao) {
  AcaoSocial.adicionarAmigo => 'Adicionar',
  AcaoSocial.aceitarSolicitacao => 'Aceitar',
  AcaoSocial.recusarSolicitacao => 'Recusar',
  AcaoSocial.cancelarSolicitacao => 'Cancelar',
  AcaoSocial.removerAmigo => 'Remover',
  AcaoSocial.bloquear => 'Bloquear',
  AcaoSocial.desbloquear => 'Desbloquear',
  AcaoSocial.editarPerfil => 'Editar',
};

/// O que dizer quando a ação DEU CERTO.
///
/// `repeticao` ganha frase própria em vez de silêncio: a pessoa tocou e algo
/// tem de responder. E não pode ser a frase do sucesso comum — dizer "pedido
/// enviado" para um pedido que já existia é o aplicativo relatando uma ação que
/// não aconteceu agora.
String textoDoDesfecho(AcaoSocial acao, {required bool repeticao}) {
  if (repeticao) return 'Isso já estava resolvido por aqui 👍';
  return switch (acao) {
    AcaoSocial.adicionarAmigo => 'Pedido enviado!',
    AcaoSocial.aceitarSolicitacao => 'Vocês agora são amigos 🎉',
    AcaoSocial.recusarSolicitacao => 'Pedido recusado.',
    AcaoSocial.cancelarSolicitacao => 'Pedido cancelado.',
    AcaoSocial.removerAmigo => 'Amizade desfeita.',
    AcaoSocial.bloquear ||
    AcaoSocial.desbloquear ||
    AcaoSocial.editarPerfil => 'Pronto.',
  };
}

/// O que dizer quando o servidor RECUSOU uma ação.
///
/// -------------------------------------------------------------------------
/// AS DUAS REGRAS DESTE `switch`
/// -------------------------------------------------------------------------
///
/// 1. NÃO REVELA O QUE O CONTRATO ESCONDE. Não existe frase para "essa pessoa
///    bloqueou você", e não é esquecimento: o backend nem manda esse fato, e
///    uma frase que o deduzisse do silêncio seria pior que o próprio vazamento,
///    porque estaria adivinhando.
///
/// 2. SÓ VIRA FRASE ESPECÍFICA O QUE MUDA O QUE A PESSOA PODE FAZER. "Você
///    atingiu o limite de amigos" ajuda: há uma ação possível (remover
///    alguém). Um código interno não ajuda em nada, então cai no recado neutro
///    — e é o `recusa` no log do servidor que serve a quem depura.
String textoDaFalhaSocial(FalhaSocial e) => switch (e.motivo) {
  MotivoFalhaSocial.naoEncontrado => 'Não encontrei esse jogador.',
  MotivoFalhaSocial.naoAutenticado =>
    'Sua sessão expirou. Entre de novo para continuar.',
  MotivoFalhaSocial.regraDeNegocio => switch (e.recusa) {
    'limiteDeAmigos' => 'Você atingiu o limite de amigos.',
    'limiteDeSolicitacoesEnviadas' =>
      'Você tem pedidos demais esperando resposta.',
    _ => 'Não deu para fazer isso agora.',
  },
  MotivoFalhaSocial.pedidoInvalido ||
  MotivoFalhaSocial.recusado ||
  MotivoFalhaSocial.respostaInvalida => 'Não deu para fazer isso agora.',
  MotivoFalhaSocial.indisponivel ||
  MotivoFalhaSocial.desconhecida => 'Falha de conexão. Tenta de novo?',
};

/// O que dizer quando a BUSCA foi recusada.
///
/// Separado de [textoDaFalhaSocial] porque as recusas da busca são sobre o que
/// a pessoa DIGITOU, e a frase certa diz o que mudar no texto. "Não deu para
/// fazer isso agora" num termo curto demais deixaria alguém tentando o mesmo
/// termo para sempre.
String textoDaBuscaRecusada(FalhaSocial e) => switch (e.recusa) {
  'consultaMuitoCurta' => 'Escreva um pouco mais para procurar.',
  'consultaMuitoLonga' => 'Esse texto é longo demais para um apelido.',
  'consultaInvalida' => 'Não consegui entender esse texto.',
  _ => e.transitoria
      ? 'Falha de conexão. Tenta de novo?'
      : 'Não consegui buscar agora.',
};
