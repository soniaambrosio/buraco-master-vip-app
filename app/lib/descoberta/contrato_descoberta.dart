// contrato_descoberta.dart — o vocabulário do fio da descoberta, num lugar só.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO NÃO É UM PUNHADO DE STRINGS SOLTAS
// ---------------------------------------------------------------------------
//
// O contrato de verdade é `contrato/descoberta-mesas-v1.json`, que existe
// IDÊNTICO neste repositório e em `buraco-servidor` — o mesmo desenho do
// contrato de chat. Editar uma cópia e não a outra reprova nas duas suítes.
//
// Este arquivo é a projeção Dart dele. Ele existe para que nenhuma outra parte
// do aplicativo redigite `'descobrirMesas'` ou o número 1000: teste que redigita
// uma string não detecta renomeação, só a repete. E porque a suíte compara
// ESTES valores com o JSON — se o servidor mudar o vocabulário e o JSON vier
// junto, é aqui que a divergência aparece, e não numa tela em produção.
//
// ---------------------------------------------------------------------------
// A CHAVE DO SERVIDOR NÃO É O TEXTO DO JOGADOR
// ---------------------------------------------------------------------------
//
// O motor chama a modalidade-mãe de `sbtl`. A jogadora conhece o jogo como
// STBL. As duas coisas são verdadeiras e nenhuma das duas deve ser mudada para
// caber na outra: mexer na chave quebraria o servidor, e mostrar a chave crua
// mostraria jargão de código para quem só quer jogar.
//
// A tradução mora em `ModalidadeDeMesa`, e SÓ lá. Ver `modelo_descoberta.dart`.

/// Vocabulário e limites do fio da descoberta (OS 38.1 §7/§8).
///
/// Tudo `static const`: é contrato, não configuração.
class ContratoDaDescoberta {
  const ContratoDaDescoberta._();

  /// Nome do arquivo de contrato, idêntico nos dois repositórios.
  static const arquivo = 'contrato/descoberta-mesas-v1.json';

  /// Esquema declarado no retrato. Retrato com outro esquema é recusado
  /// inteiro — ver `AdaptadorDaDescoberta`.
  static const esquema = 'descoberta-mesas-v1';

  /// Versão do contrato. Existe para o dia em que houver uma v2 e as duas
  /// precisarem conviver durante uma migração.
  static const versao = 1;

  // --- mensagens ------------------------------------------------------------

  /// Cliente → servidor. SEM CAMPOS: a resposta é função do estado do servidor
  /// e de mais nada. Acrescentar campo aqui seria devolver ao cliente uma
  /// opinião sobre o que ele pode ver.
  static const pedidoDeMesas = 'descobrirMesas';

  /// Servidor → cliente: o retrato inteiro.
  static const respostaDeMesas = 'mesas';

  /// Cliente → servidor. SEM CAMPOS: renova o lease do uid da PRÓPRIA conexão.
  /// Não existe campo de total, de contagem, de outro jogador ou de tempo.
  static const pulsoDePresenca = 'presenca_ping';

  /// Servidor → cliente: `ttlMs` e `intervaloSugeridoMs`.
  static const reciboDePulso = 'presenca_ok';

  // --- recusas --------------------------------------------------------------

  static const recusaDeRitmoDeMesas = 'DESCOBERTA_RITMO';
  static const recusaDeRitmoDePulso = 'PRESENCA_RITMO';

  // --- ritmo ----------------------------------------------------------------

  /// O servidor recusa consulta mais frequente que isto, por conexão. O cliente
  /// respeita o mesmo limite ANTES de enviar — pedir para levar recusa é gastar
  /// o socket para não receber nada.
  static const ritmoMinimoDeMesas = Duration(milliseconds: 1000);

  /// Idem para o pulso.
  static const ritmoMinimoDePulso = Duration(milliseconds: 5000);

  // --- forma ----------------------------------------------------------------

  /// Quatro assentos, sempre. Retrato que declare outra coisa é recusado.
  static const capacidadeDaMesa = 4;

  /// Campos de primeiro nível do retrato, além de `tipo`. Lista FECHADA.
  static const camposDoRetrato = <String>{
    'esquema',
    'geracao',
    'revisao',
    'geradoEm',
    'mesas',
    'presenca',
  };

  /// Campos de uma mesa. Lista FECHADA.
  static const camposDaMesa = <String>{
    'codigo',
    'nome',
    'modalidade',
    'metaPontos',
    'capacidade',
    'jogadores',
    'bots',
    'ocupados',
    'vagas',
    'assentos',
    'estadoIngresso',
    'ingressavel',
    'aguardandoHaMs',
    'revisao',
  };

  /// Campos de um assento. Lista FECHADA.
  static const camposDoAssento = <String>{
    'assento',
    'ocupado',
    'tipo',
    'apelido',
    'avatarGaleria',
  };

  /// Campos do bloco de presença. Lista FECHADA.
  static const camposDaPresenca = <String>{
    'jogadoresOnlineTotal',
    'espectadoresOnline',
    'jogadoresEmMesasPublicas',
    'jogadoresEmMesasPublicasAguardando',
    'jogadoresEmMesasPublicasEmAndamento',
    'mesasPublicas',
    'mesasPublicasComVagas',
    'porModalidade',
  };

  /// Campos de uma entrada de `porModalidade`. Lista FECHADA.
  static const camposDaModalidade = <String>{
    'mesas',
    'mesasComVagas',
    'jogadores',
    'jogadoresAguardando',
    'jogadoresEmAndamento',
  };

  /// CHAVES QUE NÃO PODEM EXISTIR EM LUGAR NENHUM DO RETRATO.
  ///
  /// O servidor não as envia — a projeção dele é uma lista branca montada campo
  /// a campo, e a suíte de lá varre o payload. Esta lista é a segunda tranca, e
  /// ela olha para o outro lado: se um dia o servidor regredir, o aplicativo
  /// recusa o retrato inteiro em vez de desenhar um uid na tela.
  ///
  /// Recusar é mais forte que ignorar. Ignorar o campo deixaria o dado
  /// atravessar o fio e viver na memória do aparelho; recusar faz o retrato
  /// inteiro não existir, e o defeito aparece como estado de erro — que alguém
  /// investiga — em vez de como nada.
  static const chavesProibidas = <String>{
    'uid',
    'uidAutenticado',
    'jogadorId',
    'admissaoId',
    'tentativaEntradaId',
    'token',
    'credencial',
    'jogo',
    'mao',
    'maos',
    'lixo',
    'monte',
    'cartas',
  };
}
