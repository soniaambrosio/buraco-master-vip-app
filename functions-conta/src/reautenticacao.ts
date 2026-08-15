// reautenticacao.ts — "faz quanto tempo esta pessoa provou que e ela?"
//
// MODULO PURO DE PROPOSITO: nao importa firebase-admin, nao le relogio e nao
// toca no banco. Recebe o instante da autenticacao e o instante de agora como
// DADOS, e por isso `test/reautenticacao.test.js` prova a janela inteira com
// `node --test`, sem emulador — mesma disciplina de functions-social/src/
// chaves.ts e functions-moderacao/src/idempotency.ts.
//
// ---------------------------------------------------------------------------
// POR QUE A REAUTENTICACAO E CONFERIDA NO SERVIDOR, E NAO NA TELA
// ---------------------------------------------------------------------------
//
// O Firebase tem, do lado do cliente, `reauthenticateWithCredential`. E util
// para a EXPERIENCIA (pedir a senha de novo antes de um passo grave), e e
// inutil como GARANTIA: um aplicativo modificado simplesmente nao a chama.
//
// O que nao se falsifica e `auth_time`, um campo ASSINADO do ID token, posto
// pelo proprio Firebase Authentication no momento em que a credencial foi
// apresentada. O `onCall` verifica a assinatura do token antes de o nosso codigo
// rodar, entao quando `req.auth.token.auth_time` chega aqui ele ja e um fato
// atestado — nao um valor de payload.
//
// Consequencia pratica, e e ela que fecha o caso "cliente jamais escolhe":
// exigir `auth_time` recente e exigir que a PESSOA tenha apresentado credencial
// ha pouco NESTE dispositivo. Uma sessao antiga restaurada do disco tem
// `auth_time` velho mesmo com token de acesso novinho, porque a renovacao de
// token nao e reautenticacao — e essa e exatamente a distincao que interessa
// para um botao que apaga a conta.
//
// ---------------------------------------------------------------------------
// A JANELA, E POR QUE CINCO MINUTOS
// ---------------------------------------------------------------------------
//
// Curta o bastante para que um aparelho desbloqueado e esquecido em cima da
// mesa nao sirva para apagar a conta de alguem; longa o bastante para caber o
// fluxo inteiro (aviso -> confirmacao -> digitar a palavra -> execucao) sem que
// a pessoa que leu com calma seja mandada de volta ao login.

/// Quanto tempo uma credencial recem-apresentada continua valendo para
/// autorizar a exclusao.
export const JANELA_REAUTENTICACAO_SEGUNDOS = 5 * 60;

/// Tolerancia para desencontro de relogio entre o emissor do token e nos.
///
/// `auth_time` e carimbado pelo servidor do Firebase Authentication, e o nosso
/// `Date.now()` roda noutra maquina. Sem folga, um adiantamento de um segundo
/// produziria `auth_time` no futuro e a conferencia recusaria uma credencial
/// legitima — falha que apareceria de forma intermitente e sem explicacao.
export const FOLGA_RELOGIO_SEGUNDOS = 60;

export const MOTIVO_REAUTENTICACAO = {
  /// O token nao trouxe `auth_time`. Nao ha o que conferir, e a ausencia NAO e
  /// tratada como aprovacao.
  AUSENTE: "reautenticacaoAusente",
  /// Trouxe, mas a credencial foi apresentada ha tempo demais.
  VENCIDA: "reautenticacaoVencida",
  /// Trouxe um valor que nao e um instante utilizavel.
  INVALIDA: "reautenticacaoInvalida",
} as const;

export type MotivoReautenticacao =
  (typeof MOTIVO_REAUTENTICACAO)[keyof typeof MOTIVO_REAUTENTICACAO];

export interface VereditoReautenticacao {
  recente: boolean;
  motivo: MotivoReautenticacao | null;
  /// Ha quantos segundos a credencial foi apresentada. `null` quando nao deu
  /// para saber. Vai na resposta de recusa para que a tela possa dizer "sua
  /// sessao e de 40 minutos atras" em vez de um "tente de novo" sem conteudo.
  idadeSegundos: number | null;
}

/// A credencial foi apresentada dentro da janela?
///
/// [authTime] e o claim `auth_time` do ID token, em SEGUNDOS desde a epoca — a
/// unidade em que o Firebase o emite. [agoraSegundos] tambem em segundos, e
/// entra como parametro justamente para o teste poder encenar "40 minutos
/// depois" sem esperar 40 minutos.
export function conferirReautenticacao(
  authTime: unknown,
  agoraSegundos: number,
  janelaSegundos: number = JANELA_REAUTENTICACAO_SEGUNDOS
): VereditoReautenticacao {
  if (authTime === undefined || authTime === null) {
    return {
      recente: false,
      motivo: MOTIVO_REAUTENTICACAO.AUSENTE,
      idadeSegundos: null,
    };
  }

  // So numero. Uma string "1700000000" seria convertivel, e aceita-la abriria a
  // porta para um claim customizado de tipo inesperado ser lido como instante.
  if (typeof authTime !== "number" || !Number.isFinite(authTime) || authTime <= 0) {
    return {
      recente: false,
      motivo: MOTIVO_REAUTENTICACAO.INVALIDA,
      idadeSegundos: null,
    };
  }

  const idade = agoraSegundos - authTime;

  // Credencial "do futuro" alem da folga: relogio absurdo ou token forjado por
  // um emissor que nao e o Firebase. Recusa, e nao aceita — aceitar faria de um
  // `auth_time` inflado um passe permanente.
  if (idade < -FOLGA_RELOGIO_SEGUNDOS) {
    return {
      recente: false,
      motivo: MOTIVO_REAUTENTICACAO.INVALIDA,
      idadeSegundos: Math.round(idade),
    };
  }

  const dentro = idade <= janelaSegundos + FOLGA_RELOGIO_SEGUNDOS;
  return {
    recente: dentro,
    motivo: dentro ? null : MOTIVO_REAUTENTICACAO.VENCIDA,
    idadeSegundos: Math.max(0, Math.round(idade)),
  };
}

// ---------------------------------------------------------------------------
// A PALAVRA DE CONFIRMACAO
// ---------------------------------------------------------------------------
//
// O segundo portao, e ele resolve um problema DIFERENTE do da reautenticacao.
// Reautenticacao responde "e voce mesmo?"; a palavra responde "voce entendeu o
// que vai acontecer?". Um toque acidental no botao errado passa pelo primeiro
// portao sem esforco — a sessao E recente — e nao passa pelo segundo.
//
// Conferida no SERVIDOR, e nao so na tela, pelo mesmo motivo de sempre: o que a
// tela confere, um aplicativo modificado nao confere.

/// A palavra que o jogador digita para confirmar. Em portugues porque o app e
/// pt-BR e a pessoa precisa entender o que esta escrevendo.
export const PALAVRA_DE_CONFIRMACAO = "EXCLUIR";

/// Normaliza para comparar: espaco em volta nao e erro de intencao, e teclado de
/// celular com maiuscula automatica tambem nao.
export function confirmacaoConfere(digitado: unknown): boolean {
  if (typeof digitado !== "string") return false;
  return digitado.trim().toUpperCase() === PALAVRA_DE_CONFIRMACAO;
}
