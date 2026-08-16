// visao_espectador.dart — O QUE QUEM ASSISTE PODE VER (OS de Moderação §12/§13).
//
// `VisaoAssento` responde "o que o assento N vê?", e a resposta inclui a mão
// dele. Espectador não é assento: não tem mão, não tem parceiro e não tem vez.
// Se ele fosse atendido por `VisaoAssento.de(jogo, algumAssento)` receberia a mão
// daquele assento — e escondê-la na interface não resolve nada, porque o payload
// já teria chegado ao aparelho. O §12 da OS é explícito: dado secreto não deve
// ser ENVIADO ao dispositivo do espectador.
//
// A regra desta camada é uma só, e é mais estreita que a do assento:
//
//   O espectador vê SOMENTE o que está na mesa — lixo, jogos baixados, placar,
//   de quem é a vez — e a CONTAGEM do que está oculto. Nenhuma carta de mão, de
//   monte ou de morto sai daqui, sob nenhum campo, em nenhuma profundidade.
//
// A contagem não é vazamento pelo mesmo motivo que vale para o assento: quantas
// cartas cada um tem é o que qualquer pessoa em volta da mesa real conta com os
// olhos.
//
// POR QUE UM ARQUIVO PRÓPRIO, e não um parâmetro `espectador: true` dentro de
// `VisaoAssento`: o mapa abaixo é uma LISTA DE PERMISSÃO escrita à mão. Um campo
// secreto novo acrescentado ao assento não vaza para cá por descuido — ele
// simplesmente não existe neste arquivo. Num builder compartilhado com um `if`,
// o padrão se inverteria: o campo novo nasceria visível para o espectador e
// alguém teria que lembrar de escondê-lo. Aqui, esquecer é omitir; lá, esquecer
// seria expor.
//
// O preço dessa escolha é a possibilidade de o espectador ficar para trás quando
// um campo PÚBLICO novo entrar no assento. Isso é um defeito de menu, não de
// segurança, e o teste ESP-DRIFT compara os dois recortes campo a campo para que
// a diferença apareça em vez de passar batida.
//
// A prova não é a leitura deste arquivo: é `VisaoAssento.vazamentos`, que varre
// a estrutura inteira contra os ids secretos, sob qualquer chave e em qualquer
// profundidade. O conjunto do que é secreto PARA O ESPECTADOR está em [segredos].

import '../mesa.dart';
import 'presenca.dart';
import 'relogio_turno.dart';
import 'snapshot_partida.dart';
import 'visao_assento.dart';

/// Recorte público do estado, para quem assiste sem jogar.
class VisaoEspectador {
  const VisaoEspectador._();

  static Map<String, Object?> _carta(Carta c) => {
        'id': c.id,
        'naipe': c.naipe,
        'valor': c.valor,
        'coringa': c.ehCoringa,
      };

  static List<Object?> _cartas(List<Carta> cs) => [for (final c in cs) _carta(c)];

  /// TUDO o que é secreto para quem assiste: as QUATRO mãos, o monte e os
  /// mortos.
  ///
  /// É a diferença exata em relação ao assento, onde a própria mão é legítima.
  /// Existe aqui, e não só no teste, porque é a definição que o servidor precisa
  /// consultar antes de despachar qualquer payload para um espectador — uma
  /// segunda cópia dessa lista no backend divergiria na primeira mudança de
  /// regra.
  static Set<String> segredos(Jogo j) => {
        for (final mao in j.maos)
          for (final c in mao) c.id,
        for (final c in j.monte) c.id,
        for (final m in j.mortos)
          for (final c in m) c.id,
      };

  /// Monta a visão de quem assiste.
  ///
  /// Não recebe assento: espectador não ocupa nenhum. [relogio], [presenca] e
  /// [versaoEstado] vêm de fora pelo mesmo motivo que no assento — são estado da
  /// SESSÃO, e quem manda neles é o servidor.
  static Map<String, Object?> de(
    Jogo j, {
    int versaoEstado = 0,
    String partidaId = '',
    RelogioTurno? relogio,
    MapaPresenca? presenca,
    ParametrosPresenca parametrosPresenca = ParametrosPresenca.padrao,
  }) {
    return {
      'partidaId': partidaId,
      'versaoEstado': versaoEstado,
      'formatoSnapshot': kVersaoFormatoSnapshot,

      // Marca o recorte. O cliente e o servidor podem afirmar QUAL visão
      // receberam sem inferir pela ausência de campos.
      'espectador': true,

      // ---- quem está na mesa (público: apelido, avatar, mascote, contagem) ----
      'jogadores': [
        for (var a = 0; a < 4; a++)
          {
            'assento': a,
            'apelido': a < j.apelidos.length ? j.apelidos[a] : '',
            'avatar': a < j.avatares.length ? j.avatares[a] : '',
            'mascote': a < j.mascotes.length ? j.mascotes[a] : '',
            'dupla': a % 2 == 0 ? 'nos' : 'eles',
            'cartasNaMao': j.maos[a].length,
          },
      ],

      // ---- mesa ----
      'modalidade': j.modalidade,
      'metaPontos': j.metaPontos,
      'rodada': j.rodada,

      // ---- turno ----
      // De quem é a vez é público. `minhaVez` não existe aqui: não há "mim".
      'vez': j.vez,
      'jaComprou': j.jaComprou,
      'rodadaEncerrada': j.rodadaEncerrada,
      'partidaEncerrada': j.encerrada,

      // ---- o que está na mesa, à vista de todos ----
      // O lixo é uma pilha aberta: quem está em volta da mesa real leu todas as
      // cartas que passaram por ela. Os jogos baixados idem.
      'lixo': _cartas(j.lixo),
      'jogosNos': [for (final g in j.jogosDupla['nos']!) _cartas(g)],
      'jogosEles': [for (final g in j.jogosDupla['eles']!) _cartas(g)],

      // ---- o que está oculto: SÓ A CONTAGEM ----
      'cartasNaMao': [for (var a = 0; a < 4; a++) j.maos[a].length],
      'monteRestante': j.monte.length,
      'mortosRestantes': j.mortos.length,
      'mortosTamanhos': [for (final m in j.mortos) m.length],
      'mortoPegoNos': j.mortoPego['nos'] ?? false,
      'mortoPegoEles': j.mortoPego['eles'] ?? false,

      // ---- pendência do topo: o FATO, nunca o id ----
      // Que alguém pegou o lixo e está devendo o topo é público — todo mundo
      // viu. QUAL é a carta, não: ela está na mão de quem pegou. O assento dono
      // recebe `idTopoObrigatorio`; aqui esse campo não existe.
      'obrigacaoTopoPendente': j.lixoTopoObrigatorio != null,

      // ---- placar e vulnerabilidade, pelas duas duplas ----
      // No assento estes campos são relativos ("minha dupla"). Sem assento, a
      // forma correta é nomear as duas.
      'placarNos': j.placar['nos'] ?? 0,
      'placarEles': j.placar['eles'] ?? 0,
      'minimoParaDescerNos': j.minimoParaDescer('nos'),
      'minimoParaDescerEles': j.minimoParaDescer('eles'),
      'vulneravelNos': j.minimoParaDescer('nos') > 0,
      'vulneravelEles': j.minimoParaDescer('eles') > 0,
      'podeBaterNos': j.duplaPodeBater('nos'),
      'podeBaterEles': j.duplaPodeBater('eles'),

      // ---- desfecho ----
      // `pontosRodada` só existe depois da rodada apurada e carrega agregados
      // (total, canastras, bônus, desconto de mão como NÚMERO) — nenhum id de
      // carta. O teste ESP-04 é quem garante isso, e não este comentário.
      'duplaQueBateu': j.duplaQueBateu,
      'assentoQueBateu': j.assentoQueBateu,
      'pontosRodada': j.pontosRodada,

      // ---- bloqueio crítico ----
      // Mesmo motivo do assento: o espectador só precisa saber QUE a mesa
      // travou. O código auditável cita cartas e fica no log do servidor.
      'mesaBloqueada': j.integridadeErro != null,

      // ---- sessão (não pertence ao Jogo) ----
      'relogio': relogio?.toJson(),
      'presenca': presenca?.toJson() ??
          {'parametros': parametrosPresenca.toJson(), 'assentos': const []},
    };
  }

  /// Ids secretos que escaparam para [visao]. Vazio = sem vazamento.
  ///
  /// Atalho de [VisaoAssento.vazamentos] com o conjunto de [segredos] já
  /// aplicado, para que o servidor não precise montar a lista por conta própria
  /// antes de despachar.
  static Set<String> vazamentos(Map<String, Object?> visao, Jogo j) =>
      VisaoAssento.vazamentos(visao, segredos(j));
}
