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

class Colecao {
  constructor(banco, caminho) {
    this._banco = banco;
    this.path = caminho;
  }
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

  /** Semeia um documento sem passar por transacao. */
  semear(caminho, dados) {
    this._gravar(caminho, dados);
    return this;
  }
}

module.exports = { FirestoreFalso, CARIMBO };
