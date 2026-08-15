/**
 * firestore_falso.js — um Firestore de mentira que erra pelos motivos certos.
 *
 * POR QUE NAO E UM MOCK
 *
 * Um mock devolveria o que o teste mandasse devolver, e entao os testes de
 * concorrencia (RTDN-09, RTDN-10) provariam apenas que o autor do teste sabe o
 * resultado que quer. O que precisa ser provado e outra coisa: que a transacao de
 * `aplicarProposta` CONTINUA CORRETA quando duas execucoes leem o mesmo documento
 * e uma commita antes da outra.
 *
 * Por isso este arquivo implementa a propriedade que torna aquela transacao
 * necessaria — CONCORRENCIA OTIMISTA. Cada documento tem uma versao; a transacao
 * anota a versao de tudo que leu; no commit, se alguma versao lida mudou, o
 * trabalho inteiro e DESCARTADO e a funcao roda de novo contra o estado novo. E o
 * mesmo contrato do Firestore de verdade, e e o unico motivo pelo qual "reler o
 * documento dentro da transacao" significa alguma coisa.
 *
 * TAMBEM RECUSA O QUE O FIRESTORE RECUSA
 *
 *   - leitura depois de escrita na mesma transacao (o Firestore exige todas as
 *     leituras antes de qualquer escrita);
 *   - retry infinito — cinco tentativas e desiste, como o SDK real.
 *
 * O QUE ELE NAO E
 *
 * Nao e o Firestore. Nao tem consulta, indice, regra de seguranca nem
 * `FieldValue.increment`. Nada aqui prova que as REGRAS de `firestore.rules`
 * estao certas — isso e outro tipo de teste, com emulador, e esta declarado como
 * pendente no relatorio desta OS. O que ele prova e a logica de transacao do
 * codebase, que e onde a corrida mora.
 *
 * `pausarAntesDoCommit` e o que torna a corrida DETERMINISTICA: sem um ponto de
 * interleaving controlado, um teste de concorrencia vira sorteio, e teste que
 * passa por sorteio nao prova nada.
 */

'use strict';

/** Sentinel de carimbo do servidor. Comparavel por identidade nos testes. */
const CARIMBO = Object.freeze({ __carimboDoServidor: true });

function ehObjetoSimples(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

/** `set(..., {merge:true})` do Firestore: mescla campo a campo, um nivel. */
function mesclar(atual, novo) {
  const saida = { ...(atual || {}) };
  for (const [k, v] of Object.entries(novo)) {
    saida[k] = ehObjetoSimples(v) && ehObjetoSimples(saida[k])
      ? { ...saida[k], ...v }
      : v;
  }
  return saida;
}

function copiar(v) {
  if (v === CARIMBO) return CARIMBO;
  if (Array.isArray(v)) return v.map(copiar);
  if (ehObjetoSimples(v)) {
    const o = {};
    for (const [k, x] of Object.entries(v)) o[k] = copiar(x);
    return o;
  }
  return v;
}

class Instantaneo {
  constructor(ref, dados) {
    this.ref = ref;
    this.id = ref.id;
    this._dados = dados;
  }
  get exists() {
    return this._dados != null;
  }
  data() {
    return this._dados == null ? undefined : copiar(this._dados);
  }
}

class Referencia {
  constructor(banco, caminho) {
    this._banco = banco;
    this.path = caminho;
    this.id = caminho.slice(caminho.lastIndexOf('/') + 1);
  }
  collection(nome) {
    return new Colecao(this._banco, `${this.path}/${nome}`);
  }
  async get() {
    this._banco.leiturasSoltas += 1;
    return new Instantaneo(this, this._banco._ler(this.path));
  }
  async set(dados, opcoes) {
    this._banco._gravar(this.path, dados, opcoes);
  }
}

/**
 * Sentinel devolvido por `FieldPathFalso.documentId()`. Comparavel por
 * identidade, como o do Admin SDK.
 */
const ID_DO_DOCUMENTO = Object.freeze({ __idDoDocumento: true });

/** O `FieldPath` do Admin SDK, na parte que este codebase usa. */
const FieldPathFalso = { documentId: () => ID_DO_DOCUMENTO };

/**
 * Consulta com `where`/`orderBy`/`limit`/`startAfter`.
 *
 * IMUTAVEL E ENCADEAVEL, como a do Firestore: cada metodo devolve uma consulta
 * NOVA. Se ela mutasse em vez de copiar, uma varredura que reaproveitasse o
 * objeto base acumularia `startAfter` a cada pagina — e o teste de paginacao
 * passaria a provar o contrario do que pretende.
 *
 * SO ORDENA POR ID. E a unica ordenacao que a varredura deste codebase usa, e
 * implementar as outras aqui seria escrever um Firestore de mentira mais
 * completo do que o necessario para provar o que esta em jogo.
 */
class Consulta {
  constructor(banco, caminho, estado = {}) {
    this._banco = banco;
    this.path = caminho;
    this._filtros = estado.filtros || [];
    this._ordenado = estado.ordenado || false;
    this._limite = estado.limite || null;
    this._depoisDe = estado.depoisDe || null;
  }

  _derivar(mudanca) {
    return new Consulta(this._banco, this.path, {
      filtros: this._filtros,
      ordenado: this._ordenado,
      limite: this._limite,
      depoisDe: this._depoisDe,
      ...mudanca,
    });
  }

  where(campo, operador, valor) {
    if (operador !== '==' && operador !== '<=') {
      throw new Error(`operador nao suportado pelo Firestore falso: ${operador}`);
    }
    return this._derivar({
      filtros: [...this._filtros, { campo, operador, valor }],
    });
  }

  orderBy(campo) {
    if (campo !== ID_DO_DOCUMENTO) {
      throw new Error('o Firestore falso so ordena por documentId()');
    }
    return this._derivar({ ordenado: true });
  }

  limit(n) {
    return this._derivar({ limite: n });
  }

  startAfter(cursor) {
    return this._derivar({ depoisDe: cursor });
  }

  async get() {
    const prefixo = `${this.path}/`;
    let ids = [...this._banco._docs.keys()]
      .filter((c) => c.startsWith(prefixo))
      // Filhos DIRETOS apenas: `playerEntitlements/{uid}/interno/billing` nao e
      // documento da colecao `playerEntitlements`.
      .filter((c) => !c.slice(prefixo.length).includes('/'))
      .map((c) => c.slice(prefixo.length));

    ids = ids.filter((id) => {
      const dados = this._banco._ler(`${prefixo}${id}`) || {};
      return this._filtros.every(({ campo, operador, valor }) => {
        const v = dados[campo];
        if (operador === '==') return v === valor;
        return v != null && v <= valor;
      });
    });

    // A ordenacao por id e SEMPRE aplicada quando pedida; sem `orderBy` a ordem
    // e a de insercao, que e o pior caso realista e serve para mostrar que uma
    // paginacao sem criterio estavel nao funciona.
    if (this._ordenado) ids.sort();

    if (this._depoisDe != null) {
      ids = ids.filter((id) => id > this._depoisDe);
    }

    this._banco.paginasLidas += 1;

    const escolhidos =
      this._limite == null ? ids : ids.slice(0, this._limite);

    const docs = escolhidos.map((id) => {
      const ref = new Referencia(this._banco, `${prefixo}${id}`);
      return new Instantaneo(ref, this._banco._ler(ref.path));
    });

    return { docs, size: docs.length, empty: docs.length === 0 };
  }
}

class Colecao extends Consulta {
  doc(id) {
    return new Referencia(this._banco, `${this.path}/${id}`);
  }
}

class Transacao {
  constructor(banco) {
    this._banco = banco;
    this._lidos = new Map(); // caminho -> versao vista
    this._escritas = [];     // {caminho, dados, opcoes}
  }
  async get(ref) {
    if (this._escritas.length > 0) {
      throw new Error(
        'transacao leu depois de escrever: o Firestore exige todas as leituras antes'
      );
    }
    this._lidos.set(ref.path, this._banco._versao(ref.path));
    return new Instantaneo(ref, this._banco._ler(ref.path));
  }
  set(ref, dados, opcoes) {
    this._escritas.push({ caminho: ref.path, dados, opcoes });
  }
}

class FirestoreFalso {
  constructor() {
    this._docs = new Map();   // caminho -> {dados, versao}
    this.tentativas = 0;      // quantas vezes um corpo de transacao rodou
    this.commits = 0;
    this.conflitos = 0;
    this.leiturasSoltas = 0;
    /** Quantas paginas de consulta foram lidas. O contador da paginacao. */
    this.paginasLidas = 0;
    /**
     * Gancho de interleaving. Chamado depois do corpo da transacao e ANTES da
     * checagem de versoes, com o numero da tentativa. Devolver uma Promise
     * segura a transacao ali — que e onde a outra execucao entra.
     */
    this.pausarAntesDoCommit = null;
  }

  collection(nome) {
    return new Colecao(this, nome);
  }

  doc(caminho) {
    return new Referencia(this, caminho);
  }

  _ler(caminho) {
    const e = this._docs.get(caminho);
    return e ? e.dados : null;
  }

  _versao(caminho) {
    const e = this._docs.get(caminho);
    return e ? e.versao : 0;
  }

  _gravar(caminho, dados, opcoes) {
    const anterior = this._docs.get(caminho);
    const mescla = opcoes && opcoes.merge === true;
    const dadosFinais = mescla
      ? mesclar(anterior ? anterior.dados : null, copiar(dados))
      : copiar(dados);
    this._docs.set(caminho, {
      dados: dadosFinais,
      versao: (anterior ? anterior.versao : 0) + 1,
    });
  }

  async runTransaction(corpo) {
    for (let tentativa = 1; tentativa <= 5; tentativa += 1) {
      const tx = new Transacao(this);
      this.tentativas += 1;
      const resultado = await corpo(tx);

      if (this.pausarAntesDoCommit) {
        await this.pausarAntesDoCommit(tentativa);
      }

      // Commit: so vale se nada que foi lido mudou desde a leitura.
      let limpo = true;
      for (const [caminho, versao] of tx._lidos) {
        if (this._versao(caminho) !== versao) {
          limpo = false;
          break;
        }
      }

      if (!limpo) {
        this.conflitos += 1;
        continue; // trabalho descartado; roda de novo contra o estado novo
      }

      for (const w of tx._escritas) {
        this._gravar(w.caminho, w.dados, w.opcoes);
      }
      this.commits += 1;
      return resultado;
    }
    throw new Error('transacao excedeu as tentativas por contencao');
  }

  // ---------------------------------------------------------- apoio de teste

  /** Conteudo cru de um documento, ou `null`. */
  ver(caminho) {
    const d = this._ler(caminho);
    return d == null ? null : copiar(d);
  }

  /** Todos os caminhos existentes, ordenados. */
  caminhos() {
    return [...this._docs.keys()].sort();
  }

  /**
   * Fotografia de caminho + VERSAO de todo o banco.
   *
   * `caminhos()` sozinho nao serve para provar ausencia de escrita: reescrever um
   * documento que ja existe nao cria caminho novo, entao a lista sairia igual. A
   * versao sobe a cada `_gravar`, entao dois retratos identicos significam que
   * nenhuma escrita aconteceu — inclusive as que sobrescrevem em cima.
   */
  retrato() {
    return [...this._docs.entries()]
      .map(([caminho, e]) => `${caminho}@${e.versao}`)
      .sort();
  }

  /** Semeia um documento sem passar por transacao. */
  semear(caminho, dados) {
    this._gravar(caminho, dados);
    return this;
  }
}

module.exports = { FirestoreFalso, CARIMBO, FieldPathFalso, ID_DO_DOCUMENTO };
