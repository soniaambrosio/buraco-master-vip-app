/**
 * firestore_adversarial.js — o Firestore falso da homologacao, com FALHA e DIARIO.
 *
 * ELE ESTENDE `firestore_falso.js`, e NAO O SUBSTITUI
 *
 * Aquele arquivo ja e a peca certa: concorrencia otimista de verdade, recusa de
 * leitura-depois-de-escrita, retry limitado. Reescrever isso aqui produziria dois
 * modelos do mesmo contrato se afastando com o tempo, e a suite historica (79
 * testes) continuaria provando o OUTRO. Entao esta classe herda o comportamento
 * inteiro e acrescenta so o que a homologacao adversarial precisa e que a suite
 * historica nao precisava:
 *
 *   DIARIO DE ESCRITAS   toda gravacao efetivada, na ordem, com caminho e valor.
 *                        Sem ele, "nao duplicou" so pode ser afirmado olhando o
 *                        estado FINAL — e um estado final correto e compativel
 *                        com duas escritas, uma delas errada e sobrescrita. O
 *                        diario e o que separa convergencia de ausencia de
 *                        efeito repetido (casos B, C, T).
 *
 *   FALHA NO COMMIT      um erro lancado no exato ponto entre "o corpo da
 *                        transacao terminou" e "as escritas foram efetivadas".
 *                        E onde mora o caso W: se as escritas fossem aplicadas
 *                        conforme acontecem em vez de bufferizadas, a falha ali
 *                        deixaria entitlement, compra e evento em estados que se
 *                        contradizem. O modelo bufferizado do pai reproduz o
 *                        contrato do Firestore real (commit atomico), e este
 *                        gancho e o que permite PROVAR que ele esta sendo usado.
 *
 *   COMMIT TRUNCADO      aplica so as primeiras N escritas e lanca. Isto NAO
 *                        modela o Firestore — modela o que aconteceria se ele
 *                        nao fosse atomico. Existe para a prova de nao-vacuidade
 *                        do caso W: um teste que passa tanto com atomicidade
 *                        quanto sem ela nao esta provando atomicidade.
 *
 *   ORCAMENTO DE RETRY   `maxTentativas` configuravel. O pai fixa 5, que e o
 *                        padrao do Admin SDK; dez execucoes simultaneas sobre o
 *                        mesmo documento estouram esse orcamento no modelo sem
 *                        backoff, e confundir "o fake desistiu" com "o codigo
 *                        duplicou" seria o pior erro possivel num laudo. O caso Q
 *                        roda nas duas configuracoes e o laudo relata as duas.
 *
 * O QUE CONTINUA NAO EXISTINDO AQUI: consulta, indice, regra de seguranca e
 * `FieldValue.increment`. Nada neste arquivo prova `firestore.rules`.
 */

'use strict';

const { FirestoreFalso, CARIMBO } = require('./firestore_falso');

class FirestoreAdversarial extends FirestoreFalso {
  constructor({ maxTentativas = 5 } = {}) {
    super();
    this.maxTentativas = maxTentativas;
    /** Toda gravacao efetivada: {caminho, dados, merge, sequencia}. */
    this.diario = [];
    /**
     * Gancho de falha, chamado com o numero da tentativa DEPOIS do corpo e ANTES
     * do commit. Devolver um Error faz a transacao lancar sem escrever nada;
     * devolver `{truncarEm: n}` aplica so as n primeiras escritas e lanca.
     */
    this.falhaNoCommit = null;
    this._sequencia = 0;
  }

  _gravar(caminho, dados, opcoes) {
    super._gravar(caminho, resolverIncrementos(this._ler(caminho), dados), opcoes);
    this._sequencia += 1;
    this.diario.push({
      caminho,
      merge: Boolean(opcoes && opcoes.merge === true),
      sequencia: this._sequencia,
      dados: this.ver(caminho),
    });
  }

  /**
   * Colecao com CONSULTA. O pai so tem `doc()`, porque a suite historica so
   * alcanca caminhos diretos; `reconciliarEntitlements` e `migrarEntitlementsLegado`
   * varrem por `where`/`orderBy`, e sem isto elas ficariam fora da homologacao.
   */
  collection(nome) {
    return new ColecaoConsultavel(this, nome, super.collection(nome));
  }

  /** Quantas vezes um caminho foi efetivamente gravado. */
  escritasEm(caminho) {
    return this.diario.filter((e) => e.caminho === caminho).length;
  }

  /** Caminhos gravados, na ordem, sem deduplicar. */
  trilha() {
    return this.diario.map((e) => e.caminho);
  }

  zerarDiario() {
    this.diario.length = 0;
    return this;
  }

  /**
   * Copia do laco do pai com dois acrescimos: `maxTentativas` configuravel e o
   * gancho `falhaNoCommit`. A regra de commit — so vale se nada que foi lido
   * mudou — e identica, de proposito.
   */
  async runTransaction(corpo) {
    const Transacao = classeTransacao();
    for (let tentativa = 1; tentativa <= this.maxTentativas; tentativa += 1) {
      const tx = new Transacao(this);
      this.tentativas += 1;
      const resultado = await corpo(tx);

      if (this.pausarAntesDoCommit) {
        await this.pausarAntesDoCommit(tentativa);
      }

      if (this.falhaNoCommit) {
        const decisao = this.falhaNoCommit(tentativa);
        if (decisao instanceof Error) {
          throw decisao;
        }
        if (decisao && typeof decisao.truncarEm === 'number') {
          // NAO e o Firestore: e a ausencia de atomicidade, encenada.
          for (const w of tx._escritas.slice(0, decisao.truncarEm)) {
            this._gravar(w.caminho, w.dados, w.opcoes);
          }
          throw new Error('commit truncado (atomicidade encenada como ausente)');
        }
      }

      let limpo = true;
      for (const [caminho, versao] of tx._lidos) {
        if (this._versao(caminho) !== versao) {
          limpo = false;
          break;
        }
      }

      if (!limpo) {
        this.conflitos += 1;
        continue;
      }

      for (const w of tx._escritas) {
        this._gravar(w.caminho, w.dados, w.opcoes);
      }
      this.commits += 1;
      return resultado;
    }
    throw new Error('transacao excedeu as tentativas por contencao');
  }

}

/**
 * A classe `Transacao` do pai nao e exportada. Em vez de duplica-la — o que
 * criaria uma SEGUNDA semantica de leitura/escrita, divergindo em silencio da
 * que a suite historica exercita —, ela e capturada do proprio pai.
 *
 * Funciona porque o corpo de uma funcao `async` roda sincronamente ate o
 * primeiro `await`: `runTransaction` instancia a transacao e chama `corpo(tx)`
 * antes de ceder. Com um callback SINCRONO, `capturada` ja esta preenchida
 * quando a chamada retorna. A transacao-sonda nao escreve nada e commita vazia.
 */
// ---------------------------------------------------------------------------
// FieldValue / FieldPath
// ---------------------------------------------------------------------------

/** Sentinel de `FieldValue.increment(n)`. Resolvido na GRAVACAO, nao na leitura. */
function incremento(n) {
  return { __incremento: Number(n) };
}

/** `FieldPath.documentId()`. Comparavel por identidade. */
const ID_DOCUMENTO = Object.freeze({ __idDoDocumento: true });

/**
 * As portas que `index.js` importa de `firebase-admin/firestore`.
 * `serverTimestamp` devolve o mesmo CARIMBO que a suite historica ja compara.
 */
const FieldValueFalso = Object.freeze({
  serverTimestamp: () => CARIMBO,
  increment: incremento,
});

const FieldPathFalso = Object.freeze({
  documentId: () => ID_DOCUMENTO,
});

/**
 * Troca sentinels de incremento pelo valor somado ao que ja estava gravado.
 *
 * Um nivel de profundidade, igual ao `mesclar` do pai: e a profundidade que o
 * Firestore mescla e a unica que este codebase usa (`fichas`).
 */
function resolverIncrementos(atual, dados) {
  if (dados == null || typeof dados !== 'object' || Array.isArray(dados)) return dados;
  const saida = {};
  for (const [k, v] of Object.entries(dados)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && '__incremento' in v) {
      const base = atual && typeof atual[k] === 'number' ? atual[k] : 0;
      saida[k] = base + v.__incremento;
    } else {
      saida[k] = v;
    }
  }
  return saida;
}

// ---------------------------------------------------------------------------
// Consulta
// ---------------------------------------------------------------------------

const COMPARADORES = {
  '==': (a, b) => a === b,
  '!=': (a, b) => a !== b,
  '<': (a, b) => a < b,
  '<=': (a, b) => a <= b,
  '>': (a, b) => a > b,
  '>=': (a, b) => a >= b,
};

/**
 * Consulta sobre os documentos DIRETOS de uma colecao.
 *
 * Modela `where`, `orderBy(documentId)`, `limit` e `startAfter` — exatamente o
 * que os dois varredores de `index.js` usam, e nada alem. Em particular NAO
 * modela indice composto: o emulador tambem nao cobra, e afirmar que a consulta
 * de `reconciliarEntitlements` tem indice em producao seria afirmar o que este
 * arquivo nao sabe. Fica declarado como limitacao no laudo.
 */
class ConsultaFalsa {
  constructor(banco, caminho, estado = {}) {
    this._banco = banco;
    this._caminho = caminho;
    this._filtros = estado.filtros || [];
    this._ordenar = estado.ordenar || null;
    this._limite = estado.limite || null;
    this._apos = estado.apos !== undefined ? estado.apos : null;
  }

  _derivar(mudanca) {
    return new ConsultaFalsa(this._banco, this._caminho, {
      filtros: this._filtros,
      ordenar: this._ordenar,
      limite: this._limite,
      apos: this._apos,
      ...mudanca,
    });
  }

  where(campo, operador, valor) {
    if (!COMPARADORES[operador]) {
      throw new Error(`operador nao modelado: ${operador}`);
    }
    return this._derivar({ filtros: [...this._filtros, { campo, operador, valor }] });
  }

  orderBy(campo) {
    return this._derivar({ ordenar: campo });
  }

  limit(n) {
    return this._derivar({ limite: n });
  }

  startAfter(valor) {
    return this._derivar({ apos: valor });
  }

  async get() {
    const prefixo = `${this._caminho}/`;
    let linhas = [...this._banco._docs.entries()]
      .filter(([p]) => p.startsWith(prefixo) && !p.slice(prefixo.length).includes('/'))
      .map(([p, e]) => ({ id: p.slice(prefixo.length), caminho: p, dados: e.dados }));

    for (const f of this._filtros) {
      const cmp = COMPARADORES[f.operador];
      linhas = linhas.filter((l) => l.dados != null && cmp(l.dados[f.campo], f.valor));
    }

    // Sem `orderBy` o Firestore ainda devolve em ordem de id; ordenar sempre
    // torna o teste deterministico sem inventar comportamento.
    const chave = this._ordenar === ID_DOCUMENTO || this._ordenar == null
      ? (l) => l.id
      : (l) => l.dados[this._ordenar];
    linhas.sort((a, b) => (chave(a) < chave(b) ? -1 : chave(a) > chave(b) ? 1 : 0));

    if (this._apos != null) linhas = linhas.filter((l) => chave(l) > this._apos);
    if (this._limite != null) linhas = linhas.slice(0, this._limite);

    const docs = linhas.map((l) => ({
      id: l.id,
      exists: l.dados != null,
      data: () => JSON.parse(JSON.stringify(l.dados)),
      ref: this._banco.doc(l.caminho),
    }));
    return { docs, size: docs.length, empty: docs.length === 0 };
  }
}

/** Colecao do pai (para `doc()`) somada as capacidades de consulta. */
class ColecaoConsultavel extends ConsultaFalsa {
  constructor(banco, caminho, colecaoDoPai) {
    super(banco, caminho);
    this._colecao = colecaoDoPai;
    this.path = caminho;
  }

  doc(id) {
    return this._colecao.doc(id);
  }
}

let _Transacao = null;
function classeTransacao() {
  if (_Transacao) return _Transacao;
  const sonda = new FirestoreFalso();
  sonda
    .runTransaction((tx) => {
      _Transacao = tx.constructor;
      return null;
    })
    .catch(() => {});
  if (!_Transacao) throw new Error('nao consegui capturar a classe Transacao do pai');
  return _Transacao;
}

module.exports = {
  FirestoreAdversarial,
  CARIMBO,
  FieldValueFalso,
  FieldPathFalso,
  ID_DOCUMENTO,
  incremento,
};
