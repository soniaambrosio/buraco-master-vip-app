/**
 * relogio_falso.js — tempo injetavel, sem `Date.now()` em lugar nenhum.
 *
 * POR QUE UM RELOGIO E PECA DE PROVA, E NAO CONVENIENCIA
 *
 * A regra de ordem do Billing (`decidirAtualizacao`) compara o instante da
 * CONSULTA autoritativa, nao o da gravacao. Provar "evento antigo nao regride o
 * estado" exige, portanto, decidir com precisao qual carimbo cada consulta
 * recebe — inclusive fazer uma consulta que COMECOU antes terminar DEPOIS. Com o
 * relogio do sistema isso vira sorteio, e sorteio nao e prova.
 *
 * `fila()` e o que da esse controle: os proximos N instantes sao ditados, na
 * ordem, e depois o relogio volta a andar sozinho a partir do ultimo valor.
 */

'use strict';

class RelogioFalso {
  /** @param {string} inicio instante inicial em ISO-8601 UTC */
  constructor(inicio) {
    const t = new Date(inicio).getTime();
    if (Number.isNaN(t)) throw new Error(`instante inicial invalido: ${inicio}`);
    this._ms = t;
    this._fila = [];
    /** Todos os instantes ja entregues, na ordem. Serve de evidencia no teste. */
    this.entregues = [];
  }

  /** O instante atual, em ISO-8601. Consome a fila, se houver. */
  agora() {
    const valor = this._fila.length > 0
      ? this._fila.shift()
      : new Date(this._ms).toISOString();
    this._ms = new Date(valor).getTime();
    this.entregues.push(valor);
    return valor;
  }

  /** Funcao pronta para injetar como porta `agora`. */
  porta() {
    return () => this.agora();
  }

  /** Dita os proximos instantes, na ordem dada. */
  fila(...instantes) {
    for (const i of instantes) {
      const t = new Date(i).getTime();
      if (Number.isNaN(t)) throw new Error(`instante invalido na fila: ${i}`);
      this._fila.push(new Date(t).toISOString());
    }
    return this;
  }

  avancar(ms) {
    this._ms += ms;
    return this;
  }

  /** O instante atual sem consumir a fila e sem registrar entrega. */
  espiar() {
    return new Date(this._ms).toISOString();
  }
}

module.exports = { RelogioFalso };
