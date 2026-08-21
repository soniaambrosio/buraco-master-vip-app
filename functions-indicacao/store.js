/** Escrita transacional da indicação e da recompensa. */

'use strict';

const {
  VALOR_POR_JOGADOR,
  avaliarVinculo,
  chaveDia,
  chaveLedger,
  deveReterParaRevisao,
} = require('./politica');

function dados(doc) {
  return doc && doc.exists ? doc.data() : null;
}

function saldoLegivel(valor) {
  if (valor == null) return 0;
  return Number.isInteger(valor) && valor >= 0 ? valor : null;
}

function instanteMs(valor) {
  if (valor && typeof valor.toMillis === 'function') return valor.toMillis();
  const n = Date.parse(valor);
  return Number.isFinite(n) ? n : null;
}

function criarStore({ db, carimbo, agora }) {
  async function vincular({ inviteeUid, referrerUid, referrerPublicId }) {
    const ref = db.collection('referrals').doc(inviteeUid);
    const progresso = db.collection('referralProgress').doc(inviteeUid);
    return db.runTransaction(async (tx) => {
      const [atual, prog] = await Promise.all([tx.get(ref), tx.get(progresso)]);
      const veredito = avaliarVinculo({
        inviteeUid,
        referrerUid,
        jaVinculada: atual.exists,
        jaJogou: prog.exists,
      });
      if (!veredito.aceita) return { vinculada: false, recusa: veredito.recusa };
      tx.create(ref, {
        inviteeUid,
        referrerUid,
        referrerPublicId,
        status: 'pendente',
        vinculadaEm: carimbo(),
        esquema: 1,
      });
      return { vinculada: true, recusa: null };
    });
  }

  async function registrarPrimeiraPartida({ matchId, inviteeUid, encerradaEm }) {
    const referralRef = db.collection('referrals').doc(inviteeUid);
    const progressRef = db.collection('referralProgress').doc(inviteeUid);
    return db.runTransaction(async (tx) => {
      const [referralDoc, progressDoc] = await Promise.all([
        tx.get(referralRef),
        tx.get(progressRef),
      ]);

      if (progressDoc.exists) return { efeito: 'repetido' };

      const marcarPrimeira = () => tx.create(progressRef, {
        inviteeUid,
        firstValidMatchId: matchId,
        registradaEm: carimbo(),
      });

      // O marcador nasce até quando não houve indicação. Assim, cadastrar um
      // código depois da primeira partida nunca abre uma janela retroativa.
      if (!referralDoc.exists) {
        marcarPrimeira();
        return { efeito: 'sem_indicacao' };
      }
      const referral = dados(referralDoc);
      if (!referral || referral.status !== 'pendente') {
        marcarPrimeira();
        return { efeito: 'repetido' };
      }

      const referrerUid = referral.referrerUid;
      if (typeof referrerUid !== 'string' || referrerUid === inviteeUid) {
        marcarPrimeira();
        tx.update(referralRef, { status: 'recusada', recusa: 'vinculo_invalido' });
        return { efeito: 'recusado' };
      }

      const vinculadaMs = instanteMs(referral.vinculadaEm);
      const encerradaMs = instanteMs(encerradaEm);
      if (vinculadaMs == null || encerradaMs == null || vinculadaMs > encerradaMs) {
        marcarPrimeira();
        tx.update(referralRef, {
          status: 'recusada',
          recusa: 'vinculo_posterior_a_partida',
          firstValidMatchId: matchId,
        });
        return { efeito: 'recusado' };
      }

      const dia = chaveDia(agora());
      const statsRef = db.collection('referralStats').doc(referrerUid);
      const sinalRef = db.collection('referralFraudSignals').doc(`volume|${inviteeUid}`);
      const carteiraConvidadoRef = db.collection('usuarios').doc(inviteeUid);
      const carteiraIndicadorRef = db.collection('usuarios').doc(referrerUid);
      const ledgerConvidadoRef = db.collection('indicacaoLedger').doc(chaveLedger(inviteeUid, inviteeUid));
      const ledgerIndicadorRef = db.collection('indicacaoLedger').doc(chaveLedger(inviteeUid, referrerUid));

      const [statsDoc, carteiraConvidado, carteiraIndicador, reciboA, reciboB] = await Promise.all([
        tx.get(statsRef),
        tx.get(carteiraConvidadoRef),
        tx.get(carteiraIndicadorRef),
        tx.get(ledgerConvidadoRef),
        tx.get(ledgerIndicadorRef),
      ]);
      if (reciboA.exists || reciboB.exists) {
        marcarPrimeira();
        return { efeito: 'repetido' };
      }

      // Todas as leituras da transação terminaram. A partir daqui só há
      // escritas — exigência do Firestore e proteção contra corrida.
      marcarPrimeira();

      const stats = dados(statsDoc) || {};
      const hoje = stats.dia === dia && Number.isInteger(stats.concedidasHoje)
        ? stats.concedidasHoje : 0;
      const total = Number.isInteger(stats.concedidasTotal) ? stats.concedidasTotal : 0;
      if (deveReterParaRevisao({ concedidasHoje: hoje, concedidasTotal: total })) {
        tx.update(referralRef, {
          status: 'retida_revisao',
          firstValidMatchId: matchId,
          retidaEm: carimbo(),
        });
        tx.create(sinalRef, {
          tipo: 'volume_indicacoes',
          referrerUid,
          inviteeUid,
          matchId,
          geraPunicao: false,
          registradoEm: carimbo(),
        });
        return { efeito: 'retido' };
      }

      const saldoConvidado = saldoLegivel(dados(carteiraConvidado)?.fichas);
      const saldoIndicador = saldoLegivel(dados(carteiraIndicador)?.fichas);
      if (saldoConvidado == null || saldoIndicador == null) {
        tx.update(referralRef, {
          status: 'retida_revisao',
          recusa: 'carteira_ilegivel',
          firstValidMatchId: matchId,
          retidaEm: carimbo(),
        });
        tx.set(sinalRef, {
          tipo: 'carteira_ilegivel',
          referrerUid,
          inviteeUid,
          matchId,
          geraPunicao: false,
          registradoEm: carimbo(),
        }, { merge: true });
        return { efeito: 'retido' };
      }

      const lancar = (ledgerRef, uid, antes) => {
        tx.create(ledgerRef, {
          inviteeUid,
          beneficiarioUid: uid,
          matchId,
          motivo: 'indicacao_primeira_partida',
          delta: VALOR_POR_JOGADOR,
          saldoAntes: antes,
          saldoDepois: antes + VALOR_POR_JOGADOR,
          registradoEm: carimbo(),
        });
      };
      lancar(ledgerConvidadoRef, inviteeUid, saldoConvidado);
      lancar(ledgerIndicadorRef, referrerUid, saldoIndicador);
      tx.set(carteiraConvidadoRef, {
        fichas: saldoConvidado + VALOR_POR_JOGADOR,
        fichasAtualizadoEm: carimbo(),
      }, { merge: true });
      tx.set(carteiraIndicadorRef, {
        fichas: saldoIndicador + VALOR_POR_JOGADOR,
        fichasAtualizadoEm: carimbo(),
      }, { merge: true });
      tx.set(statsRef, {
        dia,
        concedidasHoje: hoje + 1,
        concedidasTotal: total + 1,
        atualizadoEm: carimbo(),
      }, { merge: true });
      tx.update(referralRef, {
        status: 'concedida',
        firstValidMatchId: matchId,
        valorPorJogador: VALOR_POR_JOGADOR,
        concedidaEm: carimbo(),
      });
      return { efeito: 'concedido', valorPorJogador: VALOR_POR_JOGADOR };
    });
  }

  return { vincular, registrarPrimeiraPartida };
}

module.exports = { criarStore, saldoLegivel, instanteMs };
