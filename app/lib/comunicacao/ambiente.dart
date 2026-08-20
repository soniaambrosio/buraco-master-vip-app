// ambiente.dart — ONDE a comunicação acontece, e o que cada lugar admite.
//
// Este arquivo é a MATRIZ CANÔNICA da §2 da OS de Comunicação Controlada,
// escrita uma vez só. A frase que governa tudo o que vem depois é:
//
//     SOMENTE A MESA PRIVADA ADMITE TEXTO DIGITADO LIVREMENTE.
//
// E a segunda, que costuma ser esquecida quando a primeira é implementada:
//
//     VIP NÃO SIGNIFICA CHAT LIVRE.
//
// O benefício VIP amplia o CATÁLOGO (falas premium, emojis, reações). Ele não
// abre o teclado. Um `if (isVip)` que liberasse digitação fora da Mesa Privada
// seria a regressão exata que esta OS existe para impedir — e por isso não há,
// em lugar nenhum deste arquivo, uma pergunta sobre assinatura.
//
// ===========================================================================
// AMBIENTE NÃO É SUPERFÍCIE, E NÃO É TIPO DE MESA
// ===========================================================================
//
// Três vocabulários vizinhos convivem no projeto, e confundi-los foi o que esta
// OS teve de desfazer:
//
//   SUPERFÍCIE (app/lib/chat/superficie.dart) .... QUE CANAL TÉCNICO é este:
//        uma partida com gente sentada, uma plateia, um saguão. Ela responde
//        "existe conversa aqui?" e nasceu na OS do Chat Livre Seguro.
//
//   TIPO DE MESA (functions-mesas/src/tipos.ts) .. QUE MESA é esta: publica,
//        vipRanqueada, privada, treino. É a AUTORIDADE, e este arquivo NÃO a
//        recria — ele a TRADUZ, e há teste de espelho que prova a tradução
//        contra o arquivo original (functions-moderacao/test/espelho.test.js).
//
//   AMBIENTE (aqui) .............................. ONDE O JOGADOR ESTÁ, do
//        ponto de vista de com quem ele pode falar. Ele acrescenta os dois
//        lugares que NÃO são mesa — Saguão Público e Salão VIP — e por isso não
//        podia ser o tipo de mesa; e separa Mesa Pública de Mesa VIP, que a
//        superfície colapsava numa só.
//
// A superfície continua existindo e continua valendo: ela é o canal. O ambiente
// é a POLÍTICA daquele canal. Um canal de mesa pode ser Mesa Pública ou Mesa
// Privada, e a diferença entre os dois é tudo o que esta OS decide.

import '../chat/superficie.dart';

/// Os seis ambientes da matriz canônica, e nada além deles.
///
/// `wire` é o valor que atravessa a fronteira e fica GRAVADO. Nome de enum do
/// Dart não vai para o Firestore: renomear o enum não pode reescrever documento
/// gravado nem invalidar uma denúncia antiga.
enum AmbienteDeComunicacao {
  /// Fora de qualquer partida, aberto a todos.
  saguaoPublico('saguao_publico'),

  /// O saguão dos assinantes. Mesmo formato do público, catálogo ampliado.
  salaoVip('salao_vip'),

  /// Mesa casual online. Não ranqueia, não exige assinatura.
  mesaPublica('mesa_publica'),

  /// A mesa competitiva oficial (`vipRanqueada` na taxonomia dos tipos).
  mesaVip('mesa_vip'),

  /// Social por convite. O ÚNICO lugar onde texto digitado existe.
  mesaPrivada('mesa_privada'),

  /// Jogador contra robôs. Não há com quem conversar.
  treino('treino');

  final String wire;
  const AmbienteDeComunicacao(this.wire);

  static AmbienteDeComunicacao? porWire(Object? wire) {
    if (wire is! String) return null;
    for (final a in AmbienteDeComunicacao.values) {
      if (a.wire == wire) return a;
    }
    return null;
  }

  /// Este ambiente é uma mesa com partida?
  bool get ehMesa =>
      this == AmbienteDeComunicacao.mesaPublica ||
      this == AmbienteDeComunicacao.mesaVip ||
      this == AmbienteDeComunicacao.mesaPrivada ||
      this == AmbienteDeComunicacao.treino;

  /// Este ambiente é um saguão (gente fora de partida)?
  bool get ehSaguao =>
      this == AmbienteDeComunicacao.saguaoPublico ||
      this == AmbienteDeComunicacao.salaoVip;
}

/// A configuração de chat de UMA mesa, como a autoridade dos tipos a nomeia.
///
/// Os três valores são os de `CHATS_CANONICOS` em functions-mesas/src/
/// politica.ts, ao pé da letra. Não são inventados aqui, e o teste de espelho
/// falha se lá mudarem sem mudarem aqui.
///
/// AUSENTE NÃO É `completo`. Quem lê um documento sem o campo recebe
/// [ModoDeComunicacao.desligado] — ver [modoPorWire]. A configuração que não
/// existe não concede nada.
enum ModoDeComunicacao {
  /// Texto digitado + falas prontas. Só a Mesa Privada pode escolher isto.
  completo('completo'),

  /// Falas prontas, reações e emojis. Sem teclado.
  apenasEmotes('apenas_emotes'),

  /// Nenhuma comunicação de usuário.
  desligado('desligado');

  final String wire;
  const ModoDeComunicacao(this.wire);
}

/// Traduz o valor gravado. Desconhecido, ausente ou de outro tipo vira
/// [ModoDeComunicacao.desligado] — a leitura mais restritiva possível.
ModoDeComunicacao modoPorWire(Object? wire) {
  if (wire is! String) return ModoDeComunicacao.desligado;
  for (final m in ModoDeComunicacao.values) {
    if (m.wire == wire) return m;
  }
  return ModoDeComunicacao.desligado;
}

/// O que um AMBIENTE admite, depois de aplicada a configuração da mesa.
class PermissaoDeComunicacao {
  /// Texto digitado livremente pelo jogador.
  final bool textoLivre;

  /// Falas, reações e emojis do catálogo autoritativo.
  final bool catalogado;

  const PermissaoDeComunicacao({
    required this.textoLivre,
    required this.catalogado,
  });

  /// Nada. É o valor de quem não tem decisão a favor.
  static const nenhuma =
      PermissaoDeComunicacao(textoLivre: false, catalogado: false);

  bool get algumaCoisa => textoLivre || catalogado;

  Map<String, Object?> toJson() => {
        'textoLivre': textoLivre,
        'catalogado': catalogado,
      };
}

/// A MATRIZ. Fonte única de "o que é permitido aqui".
///
/// ORDEM DAS PERGUNTAS, e por que ela importa: o ambiente decide PRIMEIRO, e o
/// modo só refina DEPOIS. A inversão seria o defeito — um `modo == completo`
/// que decidisse sozinho daria texto livre a qualquer mesa cujo documento
/// carregasse esse valor, inclusive por engano de escrita ou por legado.
///
/// TEXTO LIVRE TEM UMA ÚNICA PORTA: `ambiente == mesaPrivada` E
/// `modo == completo`. As duas condições, sempre, e não há terceiro caminho
/// nesta função. Um ambiente novo no enum entra por `switch` exaustivo e nasce
/// SEM texto livre, porque o Dart obriga a tratá-lo e o valor a escrever é o
/// conservador.
PermissaoDeComunicacao permissaoDe(
  AmbienteDeComunicacao ambiente,
  ModoDeComunicacao modo,
) {
  switch (ambiente) {
    // Os dois saguões: falas prontas, reações e emojis. O catálogo do Salão VIP
    // é MAIOR (itens premium), e isso é decidido item a item em catalogo.dart —
    // não aqui. Aqui os dois têm a mesma FORMA de comunicação, e é essa a
    // decisão da §2. O modo da mesa não se aplica: não há mesa.
    case AmbienteDeComunicacao.saguaoPublico:
    case AmbienteDeComunicacao.salaoVip:
      return const PermissaoDeComunicacao(textoLivre: false, catalogado: true);

    // As duas mesas controladas. `completo` NÃO vira texto livre aqui, e a
    // razão é a §2: "Mesa Pública / Mesa VIP — falas prontas/balões ou
    // desligado". Um documento que trouxesse `completo` para uma delas é dado
    // inválido, e dado inválido não concede: ele é tratado como emotes.
    //
    // Isso NÃO substitui a recusa: quem declara um canal com `completo` num
    // ambiente que não o admite é RECUSADO em [modoPermitidoNoAmbiente]. Esta
    // função é a segunda tranca — a que continua fechada mesmo que um documento
    // já gravado carregue o valor errado.
    case AmbienteDeComunicacao.mesaPublica:
    case AmbienteDeComunicacao.mesaVip:
      return switch (modo) {
        ModoDeComunicacao.desligado => PermissaoDeComunicacao.nenhuma,
        ModoDeComunicacao.apenasEmotes ||
        ModoDeComunicacao.completo =>
          const PermissaoDeComunicacao(textoLivre: false, catalogado: true),
      };

    // A ÚNICA porta do texto livre em todo o sistema.
    case AmbienteDeComunicacao.mesaPrivada:
      return switch (modo) {
        ModoDeComunicacao.completo =>
          const PermissaoDeComunicacao(textoLivre: true, catalogado: true),
        ModoDeComunicacao.apenasEmotes =>
          const PermissaoDeComunicacao(textoLivre: false, catalogado: true),
        ModoDeComunicacao.desligado => PermissaoDeComunicacao.nenhuma,
      };

    // Três robôs não recebem recado. E a política dos tipos já dizia isto antes
    // desta OS: `treino` não tem sequer o CAMPO `chat` em
    // functions-mesas/src/politica.ts.
    case AmbienteDeComunicacao.treino:
      return PermissaoDeComunicacao.nenhuma;
  }
}

/// Este ambiente PODE ser configurado com este modo?
///
/// Separada de [permissaoDe] de propósito, e a diferença é o momento: esta
/// responde na hora de DECLARAR o canal ("o anfitrião podia escolher isso?"),
/// aquela responde na hora de FALAR ("o que vale agora?"). Juntá-las faria a
/// declaração inválida virar degradação silenciosa, e a §7.3 pede que a escolha
/// seja VALIDADA pela autoridade — validar é poder recusar.
bool modoPermitidoNoAmbiente(
  AmbienteDeComunicacao ambiente,
  ModoDeComunicacao modo,
) {
  if (modo == ModoDeComunicacao.completo) {
    return ambiente == AmbienteDeComunicacao.mesaPrivada;
  }
  if (ambiente == AmbienteDeComunicacao.treino) {
    // Treino não tem configuração de chat nenhuma. Nem `desligado`: o campo não
    // existe para este tipo, e aceitar um valor seria fingir que existe.
    return false;
  }
  return true;
}

// ===========================================================================
// A TRADUÇÃO DA AUTORIDADE DOS TIPOS DE MESA
// ===========================================================================
//
// ESTE BLOCO NÃO É UMA SEGUNDA TAXONOMIA. Ele é uma ponte de MÃO ÚNICA: recebe
// o que a autoridade dos tipos já decidiu e diz qual ambiente corresponde. Não
// há aqui elegibilidade VIP, não há propriedade de sala, não há validade de
// código, não há ocupação de cadeira — as cinco coisas que a §3 proíbe recriar.
//
// O teste de espelho (functions-moderacao/test/espelho.test.js) lê
// functions-mesas/src/tipos.ts e falha se qualquer um dos quatro valores mudar
// de nome lá sem mudar aqui.

/// Os valores de `TIPO_MESA` de functions-mesas/src/tipos.ts, como eles viajam.
///
/// Constantes com nome, e não literais espalhados: um literal escrito à mão em
/// dois lugares diverge no dia em que um deles for corrigido.
const String kTipoMesaPublica = 'publica';
const String kTipoMesaVipRanqueada = 'vipRanqueada';
const String kTipoMesaPrivada = 'privada';
const String kTipoMesaTreino = 'treino';

/// O ambiente correspondente a um tipo de mesa da autoridade.
///
/// `null` para valor que a taxonomia não conhece — e `null` NÃO é "trate como
/// pública". É recusa, e quem chama é obrigado a tratar.
AmbienteDeComunicacao? ambienteDeTipoDeMesa(Object? tipoDeMesa) {
  return switch (tipoDeMesa) {
    kTipoMesaPublica => AmbienteDeComunicacao.mesaPublica,
    kTipoMesaVipRanqueada => AmbienteDeComunicacao.mesaVip,
    kTipoMesaPrivada => AmbienteDeComunicacao.mesaPrivada,
    kTipoMesaTreino => AmbienteDeComunicacao.treino,
    _ => null,
  };
}

// ---------------------------------------------------------------------------
// AS DUAS DIMENSÕES DO SERVIDOR DE MESAS
// ---------------------------------------------------------------------------
//
// O servidor de partidas não fala a taxonomia dos tipos: ele fala TOPOLOGIA
// (`tipoPartida`) e NATUREZA COMPETITIVA (`categoriaCompetitiva`), as duas
// fixadas na construção do processo e nunca escolhidas pelo cliente. A
// tradução das duas para UM tipo canônico já existe, e é de
// `functions-mesas/src/tipos.ts` (`traduzirDoServidor`).
//
// ESTE BLOCO É O ESPELHO DELA, e o espelho existe pelo mesmo motivo que
// `functions-mesas/src/elegibilidade.ts` espelha `ESTADOS_COM_ACESSO` do
// Billing: cada codebase de Functions é uma unidade de implantação com `source`
// próprio, e um `require` para fora do diretório compila na bancada e quebra no
// deploy. O antídoto é o mesmo, e é um teste que LÊ o arquivo original:
// functions-moderacao/test/espelho.test.js falha se a tabela divergir.
//
// A ALTERNATIVA REJEITADA foi o servidor mandar o ambiente pronto. Ela parece
// mais simples e é pior: o ambiente passaria a ser afirmação de quem chama, e a
// Mesa Privada — o único lugar com texto livre — seria concedida por um campo.

/// `TIPO_PARTIDA_SERVIDOR` de functions-mesas/src/tipos.ts.
const String kTopologiaPublica = 'publica';
const String kTopologiaPrivada = 'privada';
const String kTopologiaSimulada = 'simulada';

/// `CATEGORIA_SERVIDOR` de functions-mesas/src/tipos.ts.
const String kCategoriaCasual = 'casual';
const String kCategoriaVipRanqueada = 'vip_ranqueada';

/// Traduz o par de dimensões do servidor para um tipo canônico de mesa.
///
/// A tabela inteira, sem ramo escondido — e idêntica à de `traduzirDoServidor`:
///
///   publica  x casual .......... publica
///   publica  x vip_ranqueada ... vipRanqueada
///   privada  x casual .......... privada
///   privada  x vip_ranqueada ... RECUSA (sala fechada alimentando o Ranking)
///   simulada x qualquer ........ treino
///   qualquer coisa fora disso .. RECUSA
String? tipoDeMesaDoServidor({
  required Object? tipoPartida,
  required Object? categoriaCompetitiva,
}) {
  if (tipoPartida is! String || categoriaCompetitiva is! String) return null;

  if (tipoPartida == kTopologiaSimulada) return kTipoMesaTreino;

  if (tipoPartida == kTopologiaPublica) {
    if (categoriaCompetitiva == kCategoriaCasual) return kTipoMesaPublica;
    if (categoriaCompetitiva == kCategoriaVipRanqueada) {
      return kTipoMesaVipRanqueada;
    }
    return null;
  }

  if (tipoPartida == kTopologiaPrivada) {
    if (categoriaCompetitiva == kCategoriaCasual) return kTipoMesaPrivada;
    return null;
  }

  return null;
}

/// O ambiente correspondente ao par de dimensões do servidor.
///
/// ATENÇÃO AO QUE ISTO **NÃO** DECIDE: que a Mesa Privada existe. Este par diz
/// apenas o que a instância do servidor DECLAROU hospedar. A Mesa Privada só
/// vira ambiente de texto livre quando a autoridade encontra o documento da
/// sala em `salasPrivadas/{codigo}` — ver `definirCanalDeChat` em
/// functions-moderacao/src/index.ts. Uma instância mal configurada pode
/// declarar `privada`; ela não pode INVENTAR uma sala registrada por um
/// assinante.
AmbienteDeComunicacao? ambienteDoServidor({
  required Object? tipoPartida,
  required Object? categoriaCompetitiva,
}) =>
    ambienteDeTipoDeMesa(tipoDeMesaDoServidor(
      tipoPartida: tipoPartida,
      categoriaCompetitiva: categoriaCompetitiva,
    ));

/// A superfície técnica compatível com este ambiente.
///
/// POR QUE CONFERIR OS DOIS: a superfície é o que o domínio do chat já usa para
/// decidir se texto livre existe; o ambiente é o que esta OS usa. Se um canal
/// pudesse declarar `superficie: mesa_de_partida` com `ambiente: saguao_publico`,
/// as duas classificações passariam a discordar sobre o mesmo canal — e a
/// política aplicada seria a de quem perguntasse primeiro.
SuperficieChat superficieDe(AmbienteDeComunicacao ambiente) => ambiente.ehSaguao
    ? SuperficieChat.saguaoPublico
    : SuperficieChat.mesaDePartida;

/// A superfície declarada corresponde ao ambiente?
bool superficieCoerente(AmbienteDeComunicacao ambiente, SuperficieChat s) =>
    superficieDe(ambiente) == s;

/// Versão do CONTRATO de comunicação (§5). Sobe quando o formato do evento
/// gravado muda de forma que um leitor antigo o interpretaria errado.
const int kVersaoContratoComunicacao = 1;
