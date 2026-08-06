#!/usr/bin/env node
// regenerar_manifesto.js — reescreve o manifesto tecnico a partir dos arquivos.
//
// Alem de atualizar `sha256` e `bytes`, grava dois campos que nao existiam:
//
//   sha256_rgba      impressao digital dos PIXELS decodificados (RGBA cru).
//                    Nao muda numa recompressao sem perda — e o que torna a
//                    equivalencia visual verificavel para sempre, e nao apenas
//                    no dia em que a otimizacao foi rodada.
//
//   origem           SHA-256 e tamanho do arquivo COMO VEIO no pacote aprovado,
//                    para o rastro nao se perder quando o arquivo e recomprimido.
//
// `width`, `height`, `mode`, `alpha_min` e `alpha_max` sao RECALCULADOS a partir
// dos pixels, e nao copiados do manifesto anterior: um manifesto que se limita a
// repetir o que ja estava escrito nao prova nada.
//
// Uso: node tools/regenerar_manifesto.js [--commit]

'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const RAIZ = path.resolve(__dirname, '..');
const DIR_ARTES = path.join(RAIZ, 'app', 'assets', 'colecoes', 'pioneiros_2026');
const MANIFESTO = path.join(RAIZ, 'app', 'data', 'colecoes', 'pioneiros_2026.manifest.json');
const RELATORIO = path.join(RAIZ, 'app', 'data', 'colecoes', 'otimizacao_pngs.json');

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/** Decodifica um PNG RGBA/8 nao entrelacado ate os pixels crus. */
function decodificar(buf) {
  let off = 8;
  const chunks = [];
  while (off < buf.length) {
    const len = buf.readUInt32BE(off);
    const tipo = buf.toString('ascii', off + 4, off + 8);
    chunks.push({ tipo, dados: buf.subarray(off + 8, off + 8 + len) });
    off += 12 + len;
    if (tipo === 'IEND') break;
  }

  const ihdr = chunks.find((c) => c.tipo === 'IHDR').dados;
  const largura = ihdr.readUInt32BE(0);
  const altura = ihdr.readUInt32BE(4);
  const bitDepth = ihdr[8];
  const colorType = ihdr[9];
  if (bitDepth !== 8 || colorType !== 6 || ihdr[12] !== 0) {
    throw new Error(`esperava RGBA/8 nao entrelacado (veio depth=${bitDepth} color=${colorType})`);
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
        default: throw new Error(`filtro invalido: ${tipo}`);
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

  return { largura, altura, cru, alphaMin, alphaMax };
}

const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');

function main() {
  const gravar = process.argv.includes('--commit');
  const manifesto = JSON.parse(fs.readFileSync(MANIFESTO, 'utf8'));
  const otimizacao = fs.existsSync(RELATORIO)
    ? JSON.parse(fs.readFileSync(RELATORIO, 'utf8'))
    : null;

  const porArquivo = new Map(
    (otimizacao ? otimizacao.arquivos : []).map((a) => [a.file, a]),
  );

  let total = 0;
  for (const item of manifesto.items) {
    const buf = fs.readFileSync(path.join(DIR_ARTES, item.file));
    const { largura, altura, cru, alphaMin, alphaMax } = decodificar(buf);
    const registro = porArquivo.get(item.file);

    // Rastro do arquivo como veio no pacote aprovado. Preservado na primeira
    // regeneracao e nunca sobrescrito depois.
    if (!item.origem) {
      item.origem = {
        sha256: registro ? registro.sha256Antes : item.sha256,
        bytes: registro ? registro.bytesAntes : item.bytes,
        nota: 'arquivo como entregue no pacote aprovado, antes da recompressao sem perda',
      };
    }

    item.sha256 = sha(buf);
    item.bytes = buf.length;
    item.sha256_rgba = sha(cru);
    item.width = largura;
    item.height = altura;
    item.mode = 'RGBA';
    item.alpha_min = alphaMin;
    item.alpha_max = alphaMax;

    total += buf.length;
  }

  manifesto.technical_summary.total_bytes = total;
  manifesto.technical_summary.integrity_note =
    'sha256 e bytes descrevem o arquivo ATUAL. sha256_rgba descreve os PIXELS e ' +
    'nao muda em recompressao sem perda: e por ele que se prova equivalencia ' +
    'visual. origem guarda o arquivo como veio no pacote aprovado.';

  if (otimizacao) {
    manifesto.otimizacao = {
      ferramenta: otimizacao.ferramenta,
      node: otimizacao.node,
      zlib: otimizacao.zlib,
      tipo: 'recompressao sem perda (refiltragem adaptativa + deflate nivel 9)',
      preservado: 'dimensoes, bit depth, color type, alpha e todos os pixels',
      total_antes: otimizacao.totalAntes,
      total_depois: otimizacao.totalDepois,
      reducao_bytes: otimizacao.reducaoBytes,
    };
  }

  const saida = JSON.stringify(manifesto, null, 2) + '\n';
  if (gravar) {
    fs.writeFileSync(MANIFESTO, saida);
    console.log(`manifesto regravado: ${MANIFESTO}`);
  } else {
    console.log('ENSAIO (sem --commit). Resumo:');
  }

  for (const item of manifesto.items) {
    console.log(
      `  ${item.id.padEnd(28)} ${String(item.bytes).padStart(9)}B ` +
        `alpha ${item.alpha_min}-${item.alpha_max}  rgba=${item.sha256_rgba.slice(0, 12)}…`,
    );
  }
  console.log(`  TOTAL ${total} bytes`);
}

main();
