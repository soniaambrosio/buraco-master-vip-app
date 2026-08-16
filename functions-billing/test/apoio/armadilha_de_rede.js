/**
 * armadilha_de_rede.js — a prova de que nenhuma chamada real acontece.
 *
 * POR QUE ISTO EXISTE
 *
 * "Os testes nao usam rede" e uma afirmacao que costuma ser feita lendo o
 * codigo: nao vejo `googleapis`, logo nao ha rede. Isso nao prova nada — um
 * `require` transitivo, um cliente de telemetria, um SDK que resolve credencial
 * no primeiro uso, qualquer um deles fura a leitura sem furar a suite.
 *
 * Aqui a afirmacao vira PROPRIEDADE VERIFICADA. As cinco saidas de rede do Node
 * sao substituidas por versoes que LANCAM. Se qualquer coisa nesta suite tentar
 * abrir socket, resolver nome ou fazer requisicao, o teste morre com um erro que
 * diz exatamente quem tentou — em vez de funcionar em silencio contra um serviço
 * de verdade.
 *
 * A armadilha e armada na CARGA do arquivo de teste, antes do primeiro `test()`,
 * e o contador e conferido no ultimo. As tentativas ficam registradas para que o
 * laudo possa dizer "zero" com um numero atras, e nao com uma opiniao.
 */

'use strict';

const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const dns = require('node:dns');

function armadilhaDeRede() {
  /** Toda tentativa de sair para a rede: {porta, detalhe}. */
  const tentativas = [];

  const barrar = (porta) => (...args) => {
    const detalhe = (() => {
      try {
        return JSON.stringify(args[0]);
      } catch {
        return String(args[0]);
      }
    })();
    tentativas.push({ porta, detalhe });
    throw new Error(
      `[armadilha] a suite tentou usar a rede por ${porta}. `
      + 'A homologacao adversarial e totalmente local: use os falsos de test/apoio.'
    );
  };

  http.request = barrar('http.request');
  http.get = barrar('http.get');
  https.request = barrar('https.request');
  https.get = barrar('https.get');
  net.Socket.prototype.connect = barrar('net.Socket.connect');
  net.connect = barrar('net.connect');
  net.createConnection = barrar('net.createConnection');
  dns.lookup = barrar('dns.lookup');
  if (dns.promises) dns.promises.lookup = barrar('dns.promises.lookup');
  globalThis.fetch = barrar('fetch');

  return {
    tentativas,
    /** Quantas vezes a suite tentou sair. Tem de ser zero. */
    total: () => tentativas.length,
  };
}

module.exports = { armadilhaDeRede };
