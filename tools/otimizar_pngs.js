#!/usr/bin/env node
// otimizar_pngs.js — recompressao PNG SEM PERDA.
//
// O que faz, e so isso:
//   1. inflaciona os IDAT e desfaz a filtragem, chegando ao RGBA cru;
//   2. refiltra cada linha escolhendo, entre os cinco filtros do PNG, o de menor
//      soma de diferencas absolutas (heuristica classica da libpng);
//   3. recomprime com deflate nivel 9 testando tres estrategias e ficando com a
//      menor saida;
//   4. grava um unico IDAT.
//
// O QUE NAO FAZ, por decisao explicita: nao redimensiona, nao muda color type,
// bit depth ou paleta, nao converte formato e nao remove chunk algum alem de
// metadados textuais (tEXt/zTXt/iTXt/tIME). Chunks de cor — gAMA, cHRM, sRGB,
// iCCP, tRNS, PLTE — sao preservados, porque remove-los mudaria a renderizacao.
//
// GARANTIA: o script so grava o arquivo novo depois de decodificar a propria
// saida e conferir, byte a byte, que o RGBA cru e IDENTICO ao da entrada. Se um
// unico pixel divergir, ele aborta sem escrever nada.
//
// Usa apenas a biblioteca padrao do Node (zlib). Nenhuma dependencia externa,
// nenhum binario baixado.
//
// Uso:
//   node tools/otimizar_pngs.js <dir-entrada> [--out <dir-saida>] [--commit]
// Sem --commit, apenas relata o ganho previsto sem tocar em nada.

'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const ASSINATURA = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const METADADOS_DESCARTAVEIS = new Set(['tEXt', 'zTXt', 'iTXt', 'tIME']);

// ---------------------------------------------------------------------------
// Leitura de chunks
// ---------------------------------------------------------------------------

function lerChunks(buf) {
  if (!buf.subarray(0, 8).equals(ASSINATURA)) throw new Error('nao e PNG');
  const chunks = [];
  let off = 8;
  while (off < buf.length) {
    const len = buf.readUInt32BE(off);
    const tipo = buf.toString('ascii', off + 4, off + 8);
    chunks.push({ tipo, dados: buf.subarray(off + 8, off + 8 + len) });
    off += 12 + len;
    if (tipo === 'IEND') break;
  }
  return chunks;
}

function lerIhdr(dados) {
  return {
    largura: dados.readUInt32BE(0),
    altura: dados.readUInt32BE(4),
    bitDepth: dados[8],
    colorType: dados[9],
    compressao: dados[10],
    filtro: dados[11],
    interlace: dados[12],
  };
}

/** Canais por pixel, por color type do PNG. */
function canais(colorType) {
  switch (colorType) {
    case 0: return 1; // cinza
    case 2: return 3; // RGB
    case 3: return 1; // paleta (indice)
    case 4: return 2; // cinza + alpha
    case 6: return 4; // RGBA
    default: throw new Error(`colorType desconhecido: ${colorType}`);
  }
}

// ---------------------------------------------------------------------------
// Filtragem PNG (secao 9 da especificacao)
// ---------------------------------------------------------------------------

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/** Desfaz a filtragem: dados filtrados -> scanlines cruas. */
function desfiltrar(filtrado, largura, altura, bpp) {
  const bytesPorLinha = largura * bpp;
  const cru = Buffer.alloc(altura * bytesPorLinha);
  let entrada = 0;

  for (let y = 0; y < altura; y++) {
    const tipo = filtrado[entrada++];
    const linha = y * bytesPorLinha;
    const anterior = (y - 1) * bytesPorLinha;

    for (let x = 0; x < bytesPorLinha; x++) {
      const bruto = filtrado[entrada + x];
      const a = x >= bpp ? cru[linha + x - bpp] : 0;
      const b = y > 0 ? cru[anterior + x] : 0;
      const c = x >= bpp && y > 0 ? cru[anterior + x - bpp] : 0;

      let valor;
      switch (tipo) {
        case 0: valor = bruto; break;
        case 1: valor = bruto + a; break;
        case 2: valor = bruto + b; break;
        case 3: valor = bruto + ((a + b) >> 1); break;
        case 4: valor = bruto + paeth(a, b, c); break;
        default: throw new Error(`filtro invalido na linha ${y}: ${tipo}`);
      }
      cru[linha + x] = valor & 0xff;
    }
    entrada += bytesPorLinha;
  }
  return cru;
}

/**
 * Refiltra escolhendo, por linha, o filtro de menor soma de diferencas
 * absolutas com sinal. E a heuristica que a libpng usa: nao garante o otimo
 * global, mas custa uma passada e costuma chegar perto.
 */
function refiltrar(cru, largura, altura, bpp) {
  const bytesPorLinha = largura * bpp;
  const saida = Buffer.alloc(altura * (bytesPorLinha + 1));
  const candidato = Buffer.alloc(bytesPorLinha);
  const melhor = Buffer.alloc(bytesPorLinha);

  for (let y = 0; y < altura; y++) {
    const linha = y * bytesPorLinha;
    const anterior = (y - 1) * bytesPorLinha;
    let melhorTipo = 0;
    let melhorCusto = Infinity;

    for (let tipo = 0; tipo <= 4; tipo++) {
      let custo = 0;
      for (let x = 0; x < bytesPorLinha; x++) {
        const atual = cru[linha + x];
        const a = x >= bpp ? cru[linha + x - bpp] : 0;
        const b = y > 0 ? cru[anterior + x] : 0;
        const c = x >= bpp && y > 0 ? cru[anterior + x - bpp] : 0;

        let v;
        switch (tipo) {
          case 0: v = atual; break;
          case 1: v = atual - a; break;
          case 2: v = atual - b; break;
          case 3: v = atual - ((a + b) >> 1); break;
          default: v = atual - paeth(a, b, c); break;
        }
        v &= 0xff;
        candidato[x] = v;
        // Soma com sinal: bytes proximos de 0 ou de 255 sao os que o deflate
        // comprime melhor, entao 200 conta como -56.
        custo += v < 128 ? v : 256 - v;
      }
      if (custo < melhorCusto) {
        melhorCusto = custo;
        melhorTipo = tipo;
        candidato.copy(melhor);
      }
    }

    const destino = y * (bytesPorLinha + 1);
    saida[destino] = melhorTipo;
    melhor.copy(saida, destino + 1);
  }
  return saida;
}

// ---------------------------------------------------------------------------
// Compressao
// ---------------------------------------------------------------------------

const ESTRATEGIAS = [
  ['default', zlib.constants.Z_DEFAULT_STRATEGY],
  ['filtered', zlib.constants.Z_FILTERED],
  ['rle', zlib.constants.Z_RLE],
];

function melhorDeflate(dados) {
  let melhor = null;
  let nome = null;
  for (const [rotulo, estrategia] of ESTRATEGIAS) {
    const saida = zlib.deflateSync(dados, {
      level: 9,
      windowBits: 15,
      memLevel: 9,
      strategy: estrategia,
    });
    if (!melhor || saida.length < melhor.length) {
      melhor = saida;
      nome = rotulo;
    }
  }
  return { dados: melhor, estrategia: nome };
}

function montarPng(chunks, idat) {
  const partes = [ASSINATURA];
  const escrever = (tipo, dados) => {
    const cab = Buffer.alloc(8);
    cab.writeUInt32BE(dados.length, 0);
    cab.write(tipo, 4, 'ascii');
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([cab.subarray(4, 8), dados])) >>> 0, 0);
    partes.push(cab, dados, crc);
  };

  let idatEscrito = false;
  for (const c of chunks) {
    if (c.tipo === 'IDAT') {
      // Um unico IDAT no lugar das dezenas originais: cada chunk custa 12 bytes
      // de cabecalho e CRC.
      if (!idatEscrito) {
        escrever('IDAT', idat);
        idatEscrito = true;
      }
      continue;
    }
    if (METADADOS_DESCARTAVEIS.has(c.tipo)) continue;
    escrever(c.tipo, c.dados);
  }
  return Buffer.concat(partes);
}

let TABELA_CRC = null;
function crc32(buf) {
  if (!TABELA_CRC) {
    TABELA_CRC = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      TABELA_CRC[n] = c;
    }
  }
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = TABELA_CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return c ^ 0xffffffff;
}

// ---------------------------------------------------------------------------
// Pipeline por arquivo
// ---------------------------------------------------------------------------

/** Decodifica ate o RGBA cru. Usado na entrada e, de novo, para conferir a saida. */
function decodificar(buf) {
  const chunks = lerChunks(buf);
  const ihdr = lerIhdr(chunks.find((c) => c.tipo === 'IHDR').dados);

  if (ihdr.interlace !== 0) throw new Error('PNG entrelacado nao suportado');
  if (ihdr.bitDepth !== 8) throw new Error(`bitDepth ${ihdr.bitDepth} nao suportado`);
  if (ihdr.colorType === 3) throw new Error('PNG com paleta nao suportado');

  const bpp = canais(ihdr.colorType);
  const idat = zlib.inflateSync(
    Buffer.concat(chunks.filter((c) => c.tipo === 'IDAT').map((c) => c.dados)),
  );
  const cru = desfiltrar(idat, ihdr.largura, ihdr.altura, bpp);
  return { chunks, ihdr, bpp, cru };
}

function otimizar(buf) {
  const { chunks, ihdr, bpp, cru } = decodificar(buf);

  const refiltrado = refiltrar(cru, ihdr.largura, ihdr.altura, bpp);
  const { dados: comprimido, estrategia } = melhorDeflate(refiltrado);
  const novo = montarPng(chunks, comprimido);

  // Conferencia obrigatoria: decodifica a PROPRIA saida e compara o RGBA cru.
  const volta = decodificar(novo);
  if (!volta.cru.equals(cru)) {
    throw new Error('RGBA divergiu apos a recompressao — arquivo descartado');
  }
  if (volta.ihdr.largura !== ihdr.largura || volta.ihdr.altura !== ihdr.altura) {
    throw new Error('dimensoes divergiram apos a recompressao');
  }
  if (volta.ihdr.colorType !== ihdr.colorType || volta.ihdr.bitDepth !== ihdr.bitDepth) {
    throw new Error('formato de cor divergiu apos a recompressao');
  }

  return { novo, estrategia, cru, ihdr };
}

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function main() {
  const entrada = process.argv[2];
  const iOut = process.argv.indexOf('--out');
  const saidaDir = iOut >= 0 ? process.argv[iOut + 1] : entrada;
  const gravar = process.argv.includes('--commit');

  if (!entrada) {
    console.error('uso: node tools/otimizar_pngs.js <dir> [--out <dir>] [--commit]');
    process.exit(1);
  }

  const arquivos = fs.readdirSync(entrada).filter((f) => f.endsWith('.png')).sort();
  let antes = 0;
  let depois = 0;
  const relatorio = [];

  console.log(`ferramenta: otimizar_pngs.js (Node ${process.version}, zlib ${process.versions.zlib})`);
  console.log(`modo: ${gravar ? 'GRAVANDO' : 'ENSAIO (sem --commit)'}\n`);
  console.log(
    'arquivo'.padEnd(60) + 'antes'.padStart(11) + 'depois'.padStart(11) + 'ganho'.padStart(9) + '  estrategia',
  );

  for (const nome of arquivos) {
    const original = fs.readFileSync(path.join(entrada, nome));
    const { novo, estrategia, cru, ihdr } = otimizar(original);

    // Nunca piorar: se o original ja for menor, ele fica.
    const escolhido = novo.length < original.length ? novo : original;
    const ganho = original.length - escolhido.length;

    antes += original.length;
    depois += escolhido.length;

    relatorio.push({
      file: nome,
      bytesAntes: original.length,
      bytesDepois: escolhido.length,
      ganho,
      sha256Antes: sha256(original),
      sha256Depois: sha256(escolhido),
      sha256Rgba: sha256(cru),
      width: ihdr.largura,
      height: ihdr.altura,
      colorType: ihdr.colorType,
      bitDepth: ihdr.bitDepth,
      estrategia: escolhido === novo ? estrategia : 'original mantido',
    });

    console.log(
      nome.padEnd(60) +
        String(original.length).padStart(11) +
        String(escolhido.length).padStart(11) +
        `${((100 * ganho) / original.length).toFixed(2)}%`.padStart(9) +
        `  ${escolhido === novo ? estrategia : 'original mantido'}`,
    );

    if (gravar) {
      fs.mkdirSync(saidaDir, { recursive: true });
      fs.writeFileSync(path.join(saidaDir, nome), escolhido);
    }
  }

  const pct = ((100 * (antes - depois)) / antes).toFixed(2);
  console.log(
    '\n' + 'TOTAL'.padEnd(60) + String(antes).padStart(11) + String(depois).padStart(11) + `${pct}%`.padStart(9),
  );
  console.log(
    `reducao: ${antes - depois} bytes (${((antes - depois) / 1048576).toFixed(2)} MiB)`,
  );

  const destinoRelatorio = path.join(saidaDir, '..', 'otimizacao_pngs.json');
  if (gravar) {
    fs.writeFileSync(
      destinoRelatorio,
      JSON.stringify(
        {
          ferramenta: 'tools/otimizar_pngs.js',
          node: process.version,
          zlib: process.versions.zlib,
          totalAntes: antes,
          totalDepois: depois,
          reducaoBytes: antes - depois,
          arquivos: relatorio,
        },
        null,
        2,
      ) + '\n',
    );
    console.log(`\nrelatorio: ${destinoRelatorio}`);
  }
}

main();
