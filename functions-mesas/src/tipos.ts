// tipos.ts — A TAXONOMIA CANONICA DOS TIPOS DE MESA.
//
// Este arquivo e a resposta inteira a pergunta "que tipos de mesa existem, e
// como cada camada os chama?". Ele NAO consulta banco, NAO importa
// firebase-admin e NAO decide admissao: ele so nomeia, traduz e recusa.
//
// MODULO PURO DE PROPOSITO, pelo mesmo criterio de functions-conta/src/
// inventario.ts e functions-social/src/chaves.ts: a taxonomia e a fundacao de
// toda decisao de permissao deste codebase, e uma fundacao precisa ser
// conferivel com `node --test`, sem emulador e sem rede.
//
// ===========================================================================
// POR QUE UMA TAXONOMIA, E NAO UM `isVip`
// ===========================================================================
//
// O projeto ja recusou o booleano uma vez, no servidor de mesas
// (`docs/GATE-VIP-RANQUEADA-V1.md`, secao "Duas dimensoes, nao uma"): um
// booleano ao lado de uma enumeracao fechada e uma SEGUNDA AUTORIDADE, e as
// duas divergem no primeiro caminho que esquecer de atualizar uma delas.
//
// Aqui vale igual, e por um motivo a mais: "VIP" nao e uma propriedade da
// mesa. Sao DUAS perguntas diferentes que o booleano cola numa so —
//
//   "esta mesa exige elegibilidade VIP para sentar?"  -> vipRanqueada E privada
//   "esta mesa alimenta o Ranking competitivo?"       -> SO vipRanqueada
//
// — e a Mesa Privada e exatamente o caso em que as duas respostas divergem.
// Um `isVip` teria que responder as duas ao mesmo tempo, e responderia uma
// delas errado.
//
// ===========================================================================
// AS DUAS DIMENSOES DO SERVIDOR, E A TRADUCAO
// ===========================================================================
//
// O servidor de mesas (`buraco-servidor`) NAO fala esta taxonomia. Ele fala
// duas dimensoes independentes, ambas fixadas na CONSTRUCAO do processo e
// nunca escolhidas pelo cliente:
//
//   tipoPartida ........... publica | privada | simulada     (topologia)
//   categoriaCompetitiva .. casual  | vip_ranqueada          (natureza)
//
// Esta OS NAO colapsa as duas em uma, e nao pede ao servidor que passe a
// enviar um literal `vip`. Ela faz o que a secao 4 da OS autoriza
// explicitamente: TRADUCAO EXPLICITA E TESTADA, num ponto so, com as
// combinacoes impossiveis recusadas em vez de adivinhadas.
//
// A combinacao que mais importa recusar e `privada` x `vip_ranqueada`. Ela
// parece inofensiva — "uma mesa privada entre assinantes" — e seria a porta
// para farmar rating em sala fechada, com adversarios escolhidos a dedo. A
// Mesa Privada exige VIP de cada ocupante E fica fora do Ranking; as duas
// coisas juntas nao cabem em `vip_ranqueada`, entao a combinacao nao resolve
// para tipo nenhum.

// ===========================================================================
// OS QUATRO TIPOS
// ===========================================================================

/// Os quatro tipos canonicos, e nada alem deles.
///
/// Os valores sao os que a OS fixou, ao pe da letra. Eles viajam no fio (no
/// contrato de admissao, na telemetria e no registro de auditoria), entao
/// renomear qualquer um deles e mudanca de contrato — e ha teste de
/// serializacao que faz essa mudanca aparecer.
export const TIPO_MESA = {
  /// Casual online. Nao ranqueia, nao exige assinatura, nao tem aposta de
  /// entrada. E a mesa de todo mundo.
  PUBLICA: "publica",

  /// O ambiente competitivo oficial. Unico tipo que alimenta o Ranking.
  /// Exige assinatura VIP ativa OU passe de cortesia valido.
  VIP_RANQUEADA: "vipRanqueada",

  /// Social por convite. Exige elegibilidade VIP de CADA ocupante — o codigo
  /// localiza a sala, nao concede direito. Nao alimenta o Ranking.
  PRIVADA: "privada",

  /// Jogador contra tres robos, local. Nao ranqueia, nao movimenta carteira,
  /// nao consome cortesia.
  TREINO: "treino",
} as const;

export type TipoDeMesa = (typeof TIPO_MESA)[keyof typeof TIPO_MESA];

/// A lista fechada, para varredura e validacao.
export const TIPOS_DE_MESA: readonly TipoDeMesa[] = Object.freeze([
  TIPO_MESA.PUBLICA,
  TIPO_MESA.VIP_RANQUEADA,
  TIPO_MESA.PRIVADA,
  TIPO_MESA.TREINO,
]);

/// Resposta para "isto que chegou e um tipo de mesa?".
///
/// Existe para que nenhum caminho deste codebase precise comparar strings
/// soltas. `politica.ts`, `decisao.ts` e `index.ts` passam por aqui, e um
/// literal novo escrito a mao em qualquer um deles nao compila.
export function tipoDeMesaPorWire(valor: unknown): TipoDeMesa | null {
  if (typeof valor !== "string") return null;
  for (const t of TIPOS_DE_MESA) {
    if (t === valor) return t;
  }
  return null;
}

// ===========================================================================
// AS DUAS DIMENSOES DO SERVIDOR
// ===========================================================================

/// Topologia da sala, como o servidor de mesas a nomeia.
export const TIPO_PARTIDA_SERVIDOR = {
  PUBLICA: "publica",
  PRIVADA: "privada",
  SIMULADA: "simulada",
} as const;

export type TipoPartidaServidor =
  (typeof TIPO_PARTIDA_SERVIDOR)[keyof typeof TIPO_PARTIDA_SERVIDOR];

/// Natureza competitiva, como o servidor de mesas a nomeia.
///
/// `desconhecida` NAO aparece aqui de proposito: ela e o resultado que o
/// servidor produz para configuracao invalida, e ela nunca deve virar um tipo
/// canonico. Ela chega a `traduzirDoServidor` como qualquer outra string
/// estranha, e sai como `null`.
export const CATEGORIA_SERVIDOR = {
  CASUAL: "casual",
  VIP_RANQUEADA: "vip_ranqueada",
} as const;

export type CategoriaServidor =
  (typeof CATEGORIA_SERVIDOR)[keyof typeof CATEGORIA_SERVIDOR];

/// Traduz o par de dimensoes do servidor para UM tipo canonico.
///
/// Fecha em `null` para toda combinacao que a taxonomia nao reconhece. `null`
/// NAO e "casual" e NAO e "trate como publica": e recusa. Quem chama e
/// obrigado a tratar, e o compilador cobra isso.
///
/// A tabela inteira, sem ramo escondido:
///
///   publica  x casual .......... publica
///   publica  x vip_ranqueada ... vipRanqueada
///   privada  x casual .......... privada
///   privada  x vip_ranqueada ... RECUSA  (ver o cabecalho)
///   simulada x qualquer ........ treino
///   qualquer coisa fora disso .. RECUSA
export function traduzirDoServidor(entrada: {
  tipoPartida: unknown;
  categoriaCompetitiva: unknown;
}): TipoDeMesa | null {
  const topologia = entrada.tipoPartida;
  const categoria = entrada.categoriaCompetitiva;

  if (typeof topologia !== "string" || typeof categoria !== "string") return null;

  // `simulada` resolve antes da categoria: uma mesa simulada nao compete nem
  // cobra, e a categoria dela e irrelevante. Deixar a categoria mandar aqui
  // criaria um caminho em que uma mesa simulada mal configurada virasse
  // ambiente competitivo.
  if (topologia === TIPO_PARTIDA_SERVIDOR.SIMULADA) return TIPO_MESA.TREINO;

  if (topologia === TIPO_PARTIDA_SERVIDOR.PUBLICA) {
    if (categoria === CATEGORIA_SERVIDOR.CASUAL) return TIPO_MESA.PUBLICA;
    if (categoria === CATEGORIA_SERVIDOR.VIP_RANQUEADA) return TIPO_MESA.VIP_RANQUEADA;
    return null;
  }

  if (topologia === TIPO_PARTIDA_SERVIDOR.PRIVADA) {
    if (categoria === CATEGORIA_SERVIDOR.CASUAL) return TIPO_MESA.PRIVADA;
    // `privada` x `vip_ranqueada` nao resolve. Ver o cabecalho: seria sala
    // fechada alimentando o Ranking.
    return null;
  }

  return null;
}

// ===========================================================================
// A TRADUCAO PARA A RASTREABILIDADE
// ===========================================================================

/// `TipoDePartida` do dominio Dart (`app/lib/rastreabilidade/
/// identidade_partida.dart`), como ele viaja no fio.
///
/// Este codebase NAO redefine "isto vale ranking": essa resposta ja tem dono, e
/// o dono e `TipoDePartida.alteraRanking`. O que existe aqui e a ponte — o
/// nome que a partida recebe quando o encerramento a registra.
export const TIPO_DE_PARTIDA_WIRE = {
  PUBLICA_CASUAL: "publica_casual",
  PUBLICA_RANQUEADA: "publica_ranqueada",
  PRIVADA: "privada",
  TREINAMENTO: "treinamento",
} as const;

export type TipoDePartidaWire =
  (typeof TIPO_DE_PARTIDA_WIRE)[keyof typeof TIPO_DE_PARTIDA_WIRE];

/// O nome com que esta mesa deve ser registrada na rastreabilidade.
///
/// Total: os quatro tipos tem resposta. Nao ha `null` aqui, e nao ha `default`
/// silencioso — `noFallthroughCasesInSwitch` e `noImplicitReturns` do tsconfig
/// transformam um tipo novo sem tratamento em erro de compilacao.
export function tipoDePartidaDe(tipo: TipoDeMesa): TipoDePartidaWire {
  switch (tipo) {
    case TIPO_MESA.PUBLICA:
      return TIPO_DE_PARTIDA_WIRE.PUBLICA_CASUAL;
    case TIPO_MESA.VIP_RANQUEADA:
      return TIPO_DE_PARTIDA_WIRE.PUBLICA_RANQUEADA;
    case TIPO_MESA.PRIVADA:
      return TIPO_DE_PARTIDA_WIRE.PRIVADA;
    case TIPO_MESA.TREINO:
      return TIPO_DE_PARTIDA_WIRE.TREINAMENTO;
  }
}

// ===========================================================================
// AS TRES PERGUNTAS QUE A TAXONOMIA RESPONDE SOZINHA
// ===========================================================================

/// Esta mesa alimenta o Ranking competitivo?
///
/// UM tipo, e so um. Espelha `TipoDePartida.alteraRanking` do dominio Dart no
/// recorte que este codebase produz: `torneio` tambem alimenta o Ranking, e
/// nao aparece aqui porque mesa de torneio nao passa por esta admissao — quem
/// a abre e o Motor de Torneios.
export function alimentaRanking(tipo: TipoDeMesa): boolean {
  return tipo === TIPO_MESA.VIP_RANQUEADA;
}

/// Sentar nesta mesa exige elegibilidade VIP INDIVIDUAL do ocupante?
///
/// DOIS tipos, e e aqui que a Mesa Privada se separa do Ranking. A regra
/// aprovada e "Mesa Privada e beneficio exclusivo VIP": quem senta precisa de
/// direito PROPRIO, e o codigo da sala nao substitui direito nenhum. Uma
/// assinatura nao libera familiares nem convidados.
export function exigeElegibilidadeVip(tipo: TipoDeMesa): boolean {
  return tipo === TIPO_MESA.VIP_RANQUEADA || tipo === TIPO_MESA.PRIVADA;
}

/// O passe quinzenal de cortesia serve para entrar nesta mesa?
///
/// UM tipo. O produto aprovado e "uma entrada em partida VIP" — e a Mesa
/// Privada, apesar de exigir VIP, NAO esta incluida: a OS diz, com todas as
/// letras, que a cortesia nao concede criacao nem acesso a Mesa Privada.
///
/// Esta funcao existe separada de `exigeElegibilidadeVip` exatamente porque as
/// duas respostas divergem na Privada. Deduzir uma da outra faria a cortesia
/// abrir a sala fechada no dia em que alguem simplificasse o codigo.
export function aceitaPasseDeCortesia(tipo: TipoDeMesa): boolean {
  return tipo === TIPO_MESA.VIP_RANQUEADA;
}
