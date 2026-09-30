// resolucao_tema_ajustes.dart — quem decide se a tela de Ajustes nasce Padrão
// ou Real, e com base em quê.
//
// ---------------------------------------------------------------------------
// A DECISÃO É UMA SÓ, E ELA NÃO É TOMADA PELA TELA
// ---------------------------------------------------------------------------
//
// A §8 da OS lista o que NÃO pode decidir o tema: selo na tela, plano escrito,
// cache sem validade, item equipado, entrada em Mesa VIP, passe de cortesia,
// código de sala, amizade, variável local editável. Nenhuma dessas coisas
// aparece neste arquivo, e nenhuma delas PODE aparecer: a única entrada é
// [AcessoVip], que é o retrato produzido por `PortaoVip` a partir de
// `playerEntitlements/{uid}` — o documento que só o Billing escreve.
//
// `PortaoVip` reavalia a vigência CONTRA O RELÓGIO a cada leitura
// (`EntitlementVip.vigenteEm`), e é isso que faz a §8 sobre expiração funcionar
// sem nenhum código de expiração aqui: um direito que vence com a tela aberta
// deixa de valer na próxima reconstrução, sem escrita no Firestore, sem job e
// sem relógio próprio deste arquivo.
//
// ---------------------------------------------------------------------------
// DUAS CONDIÇÕES, E AS DUAS TÊM DE VALER
// ---------------------------------------------------------------------------
//
//   elegível  ... a autoridade canônica diz que o benefício VIP COMPLETO está
//                 em vigor agora;
//   completo  ... o conjunto luxuoso INTEIRO está registrado e legível.
//
// Faltando qualquer uma, o resultado é [TemaIconografia.padrao] para a tela
// toda. É a §7: fallback por CONJUNTO, nunca por item.
//
// O PASSE QUINZENAL DE CORTESIA NÃO ENTRA AQUI, e a prova é estrutural: ele mora
// em `playerCourtesyPass/{uid}` (backend `functions-ranking`), coleção que este
// arquivo não lê, que `PortaoVip` não lê e que `EntitlementRepositorio` não
// conhece. Não existe conversão de passe em `vipCompleto` do lado do cliente
// porque não existe leitor.
library;

import '../billing/acesso_vip.dart';
import '../elegibilidade/entitlement.dart';
import 'conjunto_real_vip.dart';
import 'iconografia_ajustes.dart';

/// Os cinco estados da §8, do ponto de vista desta tela.
enum EstadoTemaVip {
  /// Sem sessão, sem documento, ou documento que nunca concedeu nada.
  publico,

  /// Assinatura em dia.
  vipCompletoAtivo,

  /// Carência ou cancelamento com período pago em curso: a autoridade ainda
  /// concede o benefício, então o tema acompanha a autoridade.
  vipCompletoEmCarenciaComBeneficio,

  /// Houve direito e ele acabou — vencido, revogado, reembolsado, em espera,
  /// pausado ou pendente de pagamento.
  vipCompletoExpirado,

  /// Ainda carregando, falha de leitura, ou estado que este cliente não conhece.
  /// Usa Tema Padrão até resolver, por decisão explícita da §8.
  desconhecido,
}

/// Por que o tema resolvido foi o que foi. Vocabulário FECHADO e sanitizado:
/// nada daqui carrega uid, e-mail, caminho de arquivo ou mensagem de exceção.
enum MotivoDoTema {
  /// Tema Real concedido.
  concedido,

  /// A autoridade não concede o benefício completo agora.
  semDireitoVigente,

  /// A autoridade ainda não respondeu, ou respondeu com falha.
  autoridadeIndefinida,

  /// O conjunto luxuoso não está registrado nesta build.
  conjuntoNaoRegistrado,

  /// O conjunto está registrado mas nem todos os arquivos abriram.
  conjuntoIncompleto,
}

/// O veredito: um tema, o estado que o produziu e o motivo.
class ResolucaoDeTema {
  const ResolucaoDeTema({
    required this.tema,
    required this.estado,
    required this.motivo,
  });

  final TemaIconografia tema;
  final EstadoTemaVip estado;
  final MotivoDoTema motivo;

  /// O conjunto correspondente. É por aqui que a tela recebe os ícones — e o
  /// único lugar do aplicativo que escolhe entre os dois conjuntos.
  ConjuntoDeIcones get icones => switch (tema) {
        TemaIconografia.padrao => conjuntoPadraoDeAjustes,
        TemaIconografia.realVip => conjuntoRealVipDeAjustes,
      };

  /// Linha de diagnóstico técnico, sem dado pessoal. A §7 pede registro
  /// sanitizado do fallback; é esta a linha.
  String get diagnostico =>
      'tema=${tema.name} estado=${estado.name} motivo=${motivo.name}';

  @override
  String toString() => 'ResolucaoDeTema($diagnostico)';
}

/// Traduz o retrato da autoridade para os cinco estados da §8.
EstadoTemaVip estadoTemaDe(AcessoVip acesso) {
  switch (acesso.situacao) {
    case SituacaoVip.carregando:
    case SituacaoVip.erro:
      return EstadoTemaVip.desconhecido;
    case SituacaoVip.semSessao:
      return EstadoTemaVip.publico;
    case SituacaoVip.liberado:
      // `liberado` já significa "vigente agora" — o portão recomputou contra o
      // relógio. Resta distinguir a natureza, que é informação de tela.
      return acesso.entitlement?.estado == EstadoEntitlement.ativo
          ? EstadoTemaVip.vipCompletoAtivo
          : EstadoTemaVip.vipCompletoEmCarenciaComBeneficio;
    case SituacaoVip.semDireito:
      final estado = acesso.entitlement?.estado;
      if (estado == null || estado == EstadoEntitlement.nuncaTeve) {
        return EstadoTemaVip.publico;
      }
      if (estado == EstadoEntitlement.desconhecido) {
        // Estado que a plataforma passou a devolver e este cliente não conhece.
        // Vira dúvida, não "não é VIP": a §8 manda a dúvida usar o Padrão, que
        // é o mesmo desfecho visual, mas com o motivo certo no diagnóstico.
        return EstadoTemaVip.desconhecido;
      }
      return EstadoTemaVip.vipCompletoExpirado;
  }
}

/// Este estado, por si, concede o Tema Real?
///
/// Somente os dois em que a autoridade AINDA entrega o benefício completo.
bool concedeTemaReal(EstadoTemaVip estado) =>
    estado == EstadoTemaVip.vipCompletoAtivo ||
    estado == EstadoTemaVip.vipCompletoEmCarenciaComBeneficio;

/// Resolve o tema da tela de Ajustes.
///
/// [verificarConjunto] existe para o teste conseguir encenar bundle completo,
/// incompleto e corrompido sem precisar de arquivo real. Em produção ele é
/// [conjuntoRealDisponivel], que abre os arquivos de verdade.
Future<ResolucaoDeTema> resolverTemaDeAjustes({
  required AcessoVip acesso,
  Future<bool> Function()? verificarConjunto,
  bool registrado = kConjuntoRealVipRegistrado,
}) async {
  final estado = estadoTemaDe(acesso);

  if (!concedeTemaReal(estado)) {
    return ResolucaoDeTema(
      tema: TemaIconografia.padrao,
      estado: estado,
      motivo: estado == EstadoTemaVip.desconhecido
          ? MotivoDoTema.autoridadeIndefinida
          : MotivoDoTema.semDireitoVigente,
    );
  }

  if (!registrado) {
    return ResolucaoDeTema(
      tema: TemaIconografia.padrao,
      estado: estado,
      motivo: MotivoDoTema.conjuntoNaoRegistrado,
    );
  }

  final completo = await (verificarConjunto ?? conjuntoRealDisponivel)();
  if (!completo) {
    return ResolucaoDeTema(
      tema: TemaIconografia.padrao,
      estado: estado,
      motivo: MotivoDoTema.conjuntoIncompleto,
    );
  }

  return ResolucaoDeTema(
    tema: TemaIconografia.realVip,
    estado: estado,
    motivo: MotivoDoTema.concedido,
  );
}
