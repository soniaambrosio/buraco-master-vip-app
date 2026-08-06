#!/usr/bin/env node
// verificar_equivalencia.js — prova que as artes continuam pixel a pixel iguais.
//
// Dois modos, e os dois decodificam PNG de verdade (nao comparam so o hash do
// arquivo, que muda a cada recompressao mesmo sem perda):
//
//   --contra-manifesto   decodifica cada arte do repositorio e confere o
//                        `sha256_rgba` gravado no manifesto. E o portao do CI:
//                        pega recorte, recolorizacao, resize e achatamento de
//                        alpha, e sobrevive a futuras recompressoes.
//
//   --contra <dir>       decodifica as artes do repositorio E as de <dir>
//                        (tipicamente o pacote original da Sonia) e compara os
//                        pixels diretamente. E a prova de que a otimizacao sem
//                        perda nao mexeu em nada.
//
// Usa apenas a biblioteca padrao do Node.
//
// Uso:
//   node tools/verificar_equivalencia.js --contra-manifesto
//   node tools/verificar_equivalencia.js --contra "<dir-dos-originais>"

'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const RAIZ = path.resolve(__dirname, '..');
const DIR_ARTES = path.join(RAIZ, 'app', 'assets', 'colecoes', 'pioneiros_2026');
const MANIFESTO = path.join(RAIZ, 'app', 'data', 'colecoes', 'pioneiros_2026.manifest.json');

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/** PNG -> RGBA cru. Suporta RGBA/8 nao entrelacado, que e o formato das artes. */
function decodificar(buf, rotulo) {
  let off = 8;
  const chunks = [];
  while (off < buf.length) {
    const len = buf.readUInt32BE(off);
    const tipo = buf.toString('ascii', off + 4, off + 8);
    chunks.push({ tipo, dados: buf.subarray(off + 8, off + 8 + len) });
    off += 12 + len;
    if (tipo === 'IEND') break;
  }

  const ihdr = chunks.find((c) => c.tipo === 'IHDR');
  if (!ihdr) throw new Error(`${rotulo}: sem IHDR`);
  const largura = ihdr.dados.readUInt32BE(0);
  const altura = ihdr.dados.readUInt32BE(4);
  const bitDepth = ihdr.dados[8];
  const colorType = ihdr.dados[9];
  if (bitDepth !== 8 || colorType !== 6 || ihdr.dados[12] !== 0) {
    throw new Error(
      `${rotulo}: esperava RGBA/8 nao entrelacado (depth=${bitDepth} color=${colorType} interlace=${ihdr.dados[12]})`,
    );
  }

  const bpp = 4;
  const bpl = largura * bpp;
  const filtrado = zlib.inflateSync(
    Buffer.concat(chunks.filter((c) => c.tipo === 'IDAT').map((c) => c.dados)),
  );
  const cru = Buffer.alloc(altura * bpl);
  let e = 0;

  for (let y = 0; y < altura; y++) {
    const tipo = filtrado[e++];
    const L = y * bpl;
    const P = (y - 1) * bpl;
    for (let x = 0; x < bpl; x++) {
      const bruto = filtrado[e + x];
      const a = x >= bpp ? cru[L + x - bpp] : 0;
      const b = y > 0 ? cru[P + x] : 0;
      const c = x >= bpp && y > 0 ? cru[P + x - bpp] : 0;
      let v;
      switch (tipo) {
        case 0: v = bruto; break;
        case 1: v = bruto + a; break;
        case 2: v = bruto + b; break;
        case 3: v = bruto + ((a + b) >> 1); break;
        case 4: v = bruto + paeth(a, b, c); break;
        default: throw new Error(`${rotulo}: filtro invalido ${tipo} na linha ${y}`);
      }
      cru[L + x] = v & 0xff;
    }
    e += bpl;
  }

  let alphaMin = 255;
  let alphaMax = 0;
  for (let i = 3; i < cru.length; i += 4) {
    const a = cru[i];
    if (a < alphaMin) alphaMin = a;
    if (a > alphaMax) alphaMax = a;
  }

  return { largura, altura, cru, alphaMin, alphaMax, colorType, bitDepth };
}

const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');

/** Primeiro pixel divergente, para o erro apontar onde olhar. */
function primeiraDiferenca(a, b, largura) {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (a[i] !== b[i]) {
      const pixel = Math.floor(i / 4);
      return { x: pixel % largura, y: Math.floor(pixel / largura), canal: 'RGBA'[i % 4] };
    }
  }
  return null;
}

function main() {
  const manifesto = JSON.parse(fs.readFileSync(MANIFESTO, 'utf8'));
  const contraManifesto = process.argv.includes('--contra-manifesto');
  const iContra = process.argv.indexOf('--contra');
  const dirOriginais = iContra >= 0 ? process.argv[iContra + 1] : null;

  if (!contraManifesto && !dirOriginais) {
    console.error('uso: --contra-manifesto | --contra <dir-dos-originais>');
    process.exit(1);
  }

  const falhas = [];
  let conferidos = 0;

  console.log(
    contraManifesto
      ? 'Conferindo os PIXELS de cada arte contra o sha256_rgba do manifesto.\n'
      : `Comparando os PIXELS do repositorio com os originais em:\n  ${dirOriginais}\n`,
  );

  for (const item of manifesto.items) {
    const caminho = path.join(DIR_ARTES, item.file);
    if (!fs.existsSync(caminho)) {
      falhas.push(`${item.id}: arquivo ausente (${item.file})`);
      continue;
    }
    const atual = decodificar(fs.readFileSync(caminho), item.id);
    const problemas = [];

    if (atual.largura !== item.width || atual.altura !== item.height) {
      problemas.push(`dimensoes ${atual.largura}x${atual.altura} != ${item.width}x${item.height}`);
    }
    if (atual.alphaMin !== item.alpha_min || atual.alphaMax !== item.alpha_max) {
      problemas.push(
        `alpha ${atual.alphaMin}-${atual.alphaMax} != ${item.alpha_min}-${item.alpha_max}`,
      );
    }
    if (atual.colorType !== 6 || atual.bitDepth !== 8) {
      problemas.push(`formato de cor mudou (colorType=${atual.colorType} depth=${atual.bitDepth})`);
    }

    if (contraManifesto) {
      const hash = sha(atual.cru);
      if (!item.sha256_rgba) {
        problemas.push('manifesto sem sha256_rgba — rode tools/regenerar_manifesto.js');
      } else if (hash !== item.sha256_rgba) {
        problemas.push(`sha256_rgba divergente (${hash.slice(0, 16)}… != ${item.sha256_rgba.slice(0, 16)}…)`);
      }
    } else {
      const caminhoOriginal = path.join(dirOriginais, item.file);
      if (!fs.existsSync(caminhoOriginal)) {
        problemas.push(`original ausente em ${dirOriginais}`);
      } else {
        const original = decodificar(fs.readFileSync(caminhoOriginal), `${item.id} (original)`);
        if (!original.cru.equals(atual.cru)) {
          const d = primeiraDiferenca(original.cru, atual.cru, atual.largura);
          problemas.push(
            d ? `pixels divergem a partir de (${d.x},${d.y}) canal ${d.canal}` : 'tamanho do RGBA divergente',
          );
        }
      }
    }

    conferidos++;
    if (problemas.length) {
      falhas.push(`${item.id}: ${problemas.join('; ')}`);
      console.log(`  FALHOU  ${item.id.padEnd(28)} ${problemas.join('; ')}`);
    } else {
      const economia = item.origem ? item.origem.bytes - item.bytes : 0;
      console.log(
        `  OK      ${item.id.padEnd(28)} ${atual.largura}x${atual.altura} RGBA ` +
          `alpha ${atual.alphaMin}-${atual.alphaMax}` +
          (economia > 0 ? `  (-${economia} B)` : ''),
      );
    }
  }

  console.log(`\n${conferidos} artes conferidas, ${falhas.length} divergencias.`);
  if (falhas.length) {
    console.log('\nARTES ALTERADAS:');
    for (const f of falhas) console.log('  -', f);
    process.exit(1);
  }
  console.log('EQUIVALENCIA VISUAL CONFIRMADA: nenhum pixel mudou.');
}

main();
