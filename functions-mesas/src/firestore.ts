// firestore.ts — QUEM EXECUTA. Transacao, leitura, escrita.
//
// Este arquivo NAO decide nada. Ele le fatos, entrega os fatos a `decisao.ts`,
// e grava o efeito do veredito. Toda regra — que tipos existem, quem pode
// sentar, quando o passe e consumido — mora nos modulos puros, e e la que ela
// e conferida.
//
// ===========================================================================
// A TRANSACAO E UMA SO, E ISSO E O CORACAO DA SECAO 6.3 DA OS
// ===========================================================================
//
// "O consumo devera ocorrer somente quando houver admissao autoritativa
// bem-sucedida, em operacao associada a reserva real da cadeira."
//
// Aqui isso e literal: o registro da admissao e a marcacao do passe como usado
// acontecem na MESMA transacao do Firestore. Nao existe instante em que o
// passe esteja gasto e a admissao nao exista, nem o contrario.
//
// E a mesma disciplina de `fichasStore.js`, onde a linha do livro-razao e
// criada na MESMA transacao do credito, e de `idempotencia.js`, onde a
// concessao e a marcacao de `concedida` sao inseparaveis. O projeto ja recusou
// reserva-e-confirma tres vezes, e por um motivo: nao existe compensacao neste
// repositorio, e um mecanismo de duas fases sem compensacao e um vazamento com
// agenda.
//
// ===========================================================================
// AS DUAS IDEMPOTENCIAS, QUE NAO SAO A MESMA
// ===========================================================================
//
//   REPETICAO ...... duas chamadas com a MESMA `tentativaEntradaId`. A segunda
//                    le `admissoesDeMesa/{id}` e devolve o resultado da
//                    primeira, sem consumir nada. E o retry de rede.
//
//   CONCORRENCIA ... duas chamadas com tentativas DIFERENTES disputando o
//                    MESMO passe. As duas transacoes tocam
//                    `passesVip/{uid}`; o Firestore serializa, uma vence e a
//                    outra reexecuta, le `usadoEm` preenchido e recusa.
//
// O adaptador do servidor ja deduplica concorrencia do lado dele (voos
// compartilhados por `tentativaEntradaId`). A divisao e essa: la se deduplica
// concorrencia do transporte, aqui se deduplica repeticao E disputa pelo
// direito.

import { getFirestore, Firestore, Transaction } from "firebase-admin/firestore";

import { TipoDeMesa, traduzirDoServidor } from "./tipos";
import { assinaturaVigente } from "./elegibilidade";
import { CONCESSAO, DocumentoPasse, decidirConcessao, decidirConsumo, estadoDoPasse } from "./passe";
import {
  AdmissaoAnterior,
  FONTE,
  Fonte,
  RECUSA,
  Recusa,
  SalaPrivada,
  decidirAdmissao,
} from "./decisao";
import {
  RegistroDeTentativas,
  VinculoDeCodigo,
  avaliarTentativa,
  impressaoDoCodigo,
  normalizarCodigo,
  resolverCodigo,
} from "./salas";

// ===========================================================================
// AS COLECOES
// ===========================================================================

/// Nomeadas uma vez so. `test/inventario.test.js` do codebase `conta` LE
/// `firebase/firestore.rules` e falha se alguma colecao declarada la nao
/// estiver classificada na matriz de retencao — entao acrescentar colecao aqui
/// obriga a decidir o que acontece com ela quando o jogador pede para sair.
export const COL = {
  /// Da autoridade do Billing. ESTE CODEBASE SO LE.
  ENTITLEMENTS: "playerEntitlements",
  /// O passe quinzenal de cortesia.
  PASSES: "passesVip",
  /// Uma admissao por tentativa. Chave de idempotencia e trilha de auditoria.
  ADMISSOES: "admissoesDeMesa",
  /// A ancora de reconexao: quem ja ocupa assento nesta sala.
  ASSENTOS: "assentosAdmitidos",
  /// A Mesa Privada, chaveada pelo codigo da sala no servidor de mesas.
  SALAS: "salasPrivadas",
  /// O convite: `{impressao do codigo}` -> sala. O id do documento E a
  /// impressao, e nao ha campo com o codigo em claro.
  CODIGOS: "codigosDeSala",
  /// O limitador de palpites de codigo.
  TENTATIVAS: "tentativasDeCodigo",
} as const;

// ===========================================================================
// O PEDIDO E A RESPOSTA
// ===========================================================================

/// O contrato `admissao-vip-v1`, exatamente como o servidor o envia.
export type PedidoDeAdmissao = {
  uidAutenticado: string;
  codigoDaSala: string;
  identidadeDaPartida: string | null;
  assento: number;
  categoriaCompetitiva: string;
  tentativaEntradaId: string;
  reconexao: boolean;
  /// A topologia da sala. O contrato v1 nao a carrega — ver o comentario em
  /// `topologiaDe`.
  tipoPartida?: string;
};

export type ResultadoAdmissao =
  | { ok: true; admissaoId: string; fonteElegibilidade: Fonte; tipo: TipoDeMesa; repetida: boolean }
  | { ok: false; codigoRecusa: Recusa | string };

/// O documento `admissoesDeMesa/{tentativaEntradaId}`.
type DocumentoAdmissao = {
  esquema: number;
  ok: boolean;
  admissaoId: string | null;
  uid: string;
  codigoDaSala: string;
  assento: number;
  tipo: string | null;
  fonteElegibilidade: string | null;
  codigoRecusa: string | null;
  decididaEm: string;
  versaoContrato: string;
};

const ESQUEMA_ADMISSAO = 1;
const CONTRATO = "admissao-vip-v1";

// ===========================================================================
// A TOPOLOGIA QUE O CONTRATO v1 NAO CARREGA
// ===========================================================================

/// De onde sai `tipoPartida` para a traducao canonica.
///
/// O contrato `admissao-vip-v1` tem OITO campos, e `tipoPartida` nao e um
/// deles: quando ele foi fechado, so a categoria competitiva importava, porque
/// so a mesa VIP consultava este backend.
///
/// A Mesa Privada mudou isso — ela exige elegibilidade individual e passou a
/// consultar tambem. Ate o contrato ganhar `tipoPartida` (v2), a topologia e
/// DEDUZIDA de um fato que ja esta no banco e que o cliente nao escreve: existe
/// documento em `salasPrivadas/{codigoDaSala}`?
///
/// A deducao e conservadora nos dois sentidos, e vale dizer por que:
///
///   ha sala privada registrada .... `privada`. Um documento so nasce ali por
///                                   `registrarMesaPrivada`, que exige
///                                   assinatura ativa do dono.
///   nao ha ....................... `publica`. E a topologia de toda mesa que
///                                   nao foi registrada como privada, e a
///                                   categoria decide se ela e casual ou
///                                   ranqueada.
///
/// O que NAO acontece: o cliente escolher. Nem `tipoPartida` do payload e
/// lido — ele existe no tipo so para que a migracao para o contrato v2 seja uma
/// linha, e `ADM-CTR-04` prova que hoje ele e ignorado.
function topologiaDe(temSalaPrivada: boolean): string {
  return temSalaPrivada ? "privada" : "publica";
}

// ===========================================================================
// O STORE
// ===========================================================================

export type Store = ReturnType<typeof criarStore>;

export function criarStore({ db, agora }: { db: Firestore; agora: () => string }) {
  const ref = {
    entitlement: (uid: string) => db.collection(COL.ENTITLEMENTS).doc(uid),
    passe: (uid: string) => db.collection(COL.PASSES).doc(uid),
    admissao: (tentativa: string) => db.collection(COL.ADMISSOES).doc(tentativa),
    assento: (codigoDaSala: string, uid: string) =>
      db.collection(COL.ASSENTOS).doc(`${codigoDaSala}__${uid}`),
    sala: (codigoDaSala: string) => db.collection(COL.SALAS).doc(codigoDaSala),
    codigo: (impressao: string) => db.collection(COL.CODIGOS).doc(impressao),
    tentativas: (uid: string) => db.collection(COL.TENTATIVAS).doc(uid),
  };

  /// Materializa a janela do passe, se houver janela nova.
  ///
  /// Chamada DENTRO da transacao de admissao e tambem pela consulta do
  /// cliente. Nos dois casos ela le o entitlement primeiro, porque assinante
  /// ativo nao recebe.
  async function materializarPasse(
    tx: Transaction,
    uid: string,
    instante: string,
  ): Promise<{ passe: DocumentoPasse | null; assinaturaAtiva: boolean; gravar: DocumentoPasse | null }> {
    const [docEnt, docPasse] = await Promise.all([
      tx.get(ref.entitlement(uid)),
      tx.get(ref.passe(uid)),
    ]);

    const assinaturaAtiva = assinaturaVigente(
      docEnt.exists ? (docEnt.data() as Record<string, unknown>) : null,
      instante,
    );
    const atual = docPasse.exists ? (docPasse.data() as DocumentoPasse) : null;

    const decisao = decidirConcessao({ atual, agora: instante, assinaturaAtiva });
    if (decisao.acao === CONCESSAO.CONCEDER) {
      return { passe: decisao.proposta, assinaturaAtiva, gravar: decisao.proposta };
    }
    return { passe: atual, assinaturaAtiva, gravar: null };
  }

  return {
    ref,

    /// A admissao ao assento. UMA transacao, do inicio ao fim.
    async admitir(pedido: PedidoDeAdmissao): Promise<ResultadoAdmissao> {
      const instante = agora();

      return db.runTransaction(async (tx) => {
        // ---- idempotencia por REPETICAO --------------------------------
        const jaDecidida = await tx.get(ref.admissao(pedido.tentativaEntradaId));
        if (jaDecidida.exists) {
          const d = jaDecidida.data() as DocumentoAdmissao;
          // A resposta anterior, inteira. Nao se reavalia nada: o retry de
          // rede tem que ver exatamente o que a primeira chamada viu, ou o
          // jogador entra numa mesa e e expulso da seguinte por um passe que
          // ele acha que ainda tem.
          if (d.ok && d.admissaoId) {
            return {
              ok: true as const,
              admissaoId: d.admissaoId,
              fonteElegibilidade: d.fonteElegibilidade as Fonte,
              tipo: d.tipo as TipoDeMesa,
              repetida: true,
            };
          }
          return { ok: false as const, codigoRecusa: d.codigoRecusa ?? RECUSA.TIPO_DESCONHECIDO };
        }

        // ---- os fatos ---------------------------------------------------
        const docSala = await tx.get(ref.sala(pedido.codigoDaSala));
        const sala = docSala.exists ? (docSala.data() as SalaPrivada) : null;

        const tipo = traduzirDoServidor({
          tipoPartida: topologiaDe(sala !== null),
          categoriaCompetitiva: pedido.categoriaCompetitiva,
        });

        const { passe, assinaturaAtiva, gravar } = await materializarPasse(
          tx,
          pedido.uidAutenticado,
          instante,
        );

        const docAssento = await tx.get(ref.assento(pedido.codigoDaSala, pedido.uidAutenticado));
        // A reconexao so vale se o gate do servidor tambem a classificou
        // assim. Duas fontes concordando: quem ja esta sentado (la) e quem ja
        // foi admitido (aqui). Uma sozinha seria adivinhacao.
        const admissaoAnterior: AdmissaoAnterior | null =
          pedido.reconexao && docAssento.exists
            ? (docAssento.data() as AdmissaoAnterior)
            : null;

        // ---- o veredito -------------------------------------------------
        const veredito = decidirAdmissao({
          tipo,
          uidAutenticado: pedido.uidAutenticado,
          codigoDaSala: pedido.codigoDaSala,
          assento: pedido.assento,
          agora: instante,
          assinaturaAtiva,
          passe,
          sala,
          admissaoAnterior,
        });

        // A janela do passe e materializada mesmo quando a admissao recusa: a
        // concessao e conclusao do calendario, e nao premio por entrar. Nao
        // gravar aqui faria o jogador recusado perder a janela dele.
        if (gravar !== null) tx.set(ref.passe(pedido.uidAutenticado), gravar);

        if (!veredito.ok) {
          const registro: DocumentoAdmissao = {
            esquema: ESQUEMA_ADMISSAO,
            ok: false,
            admissaoId: null,
            uid: pedido.uidAutenticado,
            codigoDaSala: pedido.codigoDaSala,
            assento: pedido.assento,
            tipo,
            fonteElegibilidade: null,
            codigoRecusa: veredito.codigoRecusa,
            decididaEm: instante,
            versaoContrato: CONTRATO,
          };
          tx.set(ref.admissao(pedido.tentativaEntradaId), registro);
          return { ok: false as const, codigoRecusa: veredito.codigoRecusa };
        }

        // ---- o efeito ---------------------------------------------------
        const admissaoId =
          veredito.admissaoReaproveitada ?? `adm_${pedido.tentativaEntradaId}`;

        if (veredito.consumirPasse) {
          // `decidirConsumo` reconfere o passe contra o relogio DENTRO da
          // transacao. Confiar no `passe` lido acima bastaria hoje, e
          // deixaria de bastar no dia em que a leitura e a escrita se
          // separassem — e esse dia chega sem aviso.
          const consumo = decidirConsumo({ atual: passe, agora: instante, admissaoId });
          if (!consumo.ok) {
            const registro: DocumentoAdmissao = {
              esquema: ESQUEMA_ADMISSAO,
              ok: false,
              admissaoId: null,
              uid: pedido.uidAutenticado,
              codigoDaSala: pedido.codigoDaSala,
              assento: pedido.assento,
              tipo,
              fonteElegibilidade: null,
              codigoRecusa: consumo.motivo,
              decididaEm: instante,
              versaoContrato: CONTRATO,
            };
            tx.set(ref.admissao(pedido.tentativaEntradaId), registro);
            return { ok: false as const, codigoRecusa: consumo.motivo };
          }
          tx.set(ref.passe(pedido.uidAutenticado), consumo.documento);
        }

        const registro: DocumentoAdmissao = {
          esquema: ESQUEMA_ADMISSAO,
          ok: true,
          admissaoId,
          uid: pedido.uidAutenticado,
          codigoDaSala: pedido.codigoDaSala,
          assento: pedido.assento,
          tipo,
          fonteElegibilidade: veredito.fonteElegibilidade,
          codigoRecusa: null,
          decididaEm: instante,
          versaoContrato: CONTRATO,
        };
        tx.set(ref.admissao(pedido.tentativaEntradaId), registro);

        // A ancora de reconexao. Escrita so na aprovacao, e so para quem
        // ainda nao a tinha: reescrever numa reconexao trocaria o
        // `admissaoId` original, e ele e a prova de qual direito foi gasto.
        if (veredito.admissaoReaproveitada === null) {
          const ancora: AdmissaoAnterior = {
            admissaoId,
            assento: pedido.assento,
            fonteElegibilidade: veredito.fonteElegibilidade,
          };
          // `uid` viaja no documento embora ele ja esteja no ID. Nao e
          // redundancia: a matriz de retencao alcanca esta colecao por
          // CONSULTA POR CAMPO (`where uid ==`), e o Firestore nao consulta
          // por fragmento de id. Sem o campo, a exclusao de conta deixaria a
          // ancora para tras — e o teste da matriz nao pegaria, porque ele
          // confere a CLASSIFICACAO, nao o alcance.
          tx.set(ref.assento(pedido.codigoDaSala, pedido.uidAutenticado), {
            ...ancora,
            uid: pedido.uidAutenticado,
          });
        }

        return {
          ok: true as const,
          admissaoId,
          fonteElegibilidade: veredito.fonteElegibilidade,
          tipo: tipo as TipoDeMesa,
          repetida: false,
        };
      });
    },

    /// O estado do passe, para a tela. NAO decide admissao.
    ///
    /// Materializa a janela se houver janela nova — e o unico caminho pelo qual
    /// o passe nasce sem alguem tentar entrar numa mesa. A tela pergunta, e a
    /// pergunta e a materializacao.
    async consultarPasse(uid: string) {
      const instante = agora();
      return db.runTransaction(async (tx) => {
        const { passe, assinaturaAtiva, gravar } = await materializarPasse(tx, uid, instante);
        if (gravar !== null) tx.set(ref.passe(uid), gravar);
        if (passe === null) {
          return { temPasse: false as const, assinaturaAtiva, estado: null };
        }
        return {
          temPasse: true as const,
          assinaturaAtiva,
          estado: estadoDoPasse(passe, instante),
        };
      });
    },

    /// Registra uma Mesa Privada e cunha o convite.
    ///
    /// Exige assinatura ATIVA do dono — a criacao e o unico momento em que a
    /// politica pede assinatura e nao aceita cortesia.
    async registrarMesaPrivada(entrada: {
      uid: string;
      codigoDaSala: string;
      codigoConvite: string;
      cadeiras: readonly string[];
      expiraEm: string;
    }): Promise<{ ok: true } | { ok: false; motivo: string }> {
      const instante = agora();
      const impressao = impressaoDoCodigo(entrada.codigoConvite);

      return db.runTransaction(async (tx) => {
        const docEnt = await tx.get(ref.entitlement(entrada.uid));
        const ativa = assinaturaVigente(
          docEnt.exists ? (docEnt.data() as Record<string, unknown>) : null,
          instante,
        );
        if (!ativa) return { ok: false as const, motivo: "SEM_ASSINATURA_ATIVA" };

        const jaExiste = await tx.get(ref.sala(entrada.codigoDaSala));
        if (jaExiste.exists) return { ok: false as const, motivo: "SALA_JA_REGISTRADA" };

        const sala: SalaPrivada = {
          salaId: entrada.codigoDaSala,
          codigoDaSala: entrada.codigoDaSala,
          proprietarioUid: entrada.uid,
          criadaEm: instante,
          encerradaEm: null,
          cadeiras: entrada.cadeiras,
        };
        tx.set(ref.sala(entrada.codigoDaSala), sala);

        const vinculo: VinculoDeCodigo = {
          salaId: entrada.codigoDaSala,
          proprietarioUid: entrada.uid,
          criadoEm: instante,
          expiraEm: entrada.expiraEm,
          revogadoEm: null,
        };
        tx.set(ref.codigo(impressao), vinculo);

        return { ok: true as const };
      });
    },

    /// Resolve um convite para uma sala, com limitador.
    ///
    /// Devolve SEMPRE a mesma recusa. O motivo interno vai para o registro, e
    /// nunca para quem perguntou.
    async resolverConvite(entrada: { uid: string; codigoBruto: unknown }) {
      const instante = agora();
      const canonico = normalizarCodigo(entrada.codigoBruto);

      return db.runTransaction(async (tx) => {
        const docTent = await tx.get(ref.tentativas(entrada.uid));
        const decisao = avaliarTentativa({
          registro: docTent.exists ? (docTent.data() as RegistroDeTentativas) : null,
          agora: instante,
        });
        // O contador e gravado SEMPRE, inclusive quando o palpite e recusado
        // por excesso: nao contar a recusada tornaria o limitador contornavel
        // por insistencia.
        tx.set(ref.tentativas(entrada.uid), decisao.proximo);

        if (!decisao.permitido) return { ok: false as const, motivoInterno: "EXCESSO_DE_TENTATIVAS" };
        // Codigo mal formado nem chega a tocar a colecao de convites.
        if (canonico === null) return { ok: false as const, motivoInterno: "MAL_FORMADO" };

        const docVinculo = await tx.get(ref.codigo(impressaoDoCodigo(canonico)));
        const r = resolverCodigo({
          vinculo: docVinculo.exists ? (docVinculo.data() as VinculoDeCodigo) : null,
          agora: instante,
        });
        if (!r.ok) return { ok: false as const, motivoInterno: r.motivo };
        return { ok: true as const, salaId: r.salaId };
      });
    },
  };
}

/// A instancia usada em producao. Separada da fabrica para que os testes
/// injetem um Firestore de emulador sem tocar neste arquivo.
export function storePadrao() {
  return criarStore({ db: getFirestore(), agora: () => new Date().toISOString() });
}

export { FONTE, RECUSA };
