// Codec PNG mínimo em Node puro: esta máquina não tem ImageMagick, ffmpeg nem
// Python real (ver a memória `medir-tela-do-emulador-sem-ffmpeg`), e a geração
// dos recursos de ícone precisa ser DETERMINÍSTICA e auditável byte a byte.
// Cobre o que a arte oficial usa: 8 bits por canal, sem entrelaçamento.
import zlib from 'node:zlib';

const ASSINATURA = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function crc32(buf) {
  let tabela = crc32.tabela;
  if (!tabela) {
    tabela = crc32.tabela = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      tabela[n] = c;
    }
  }
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = tabela[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

const paeth = (a, b, c) => {
  const p = a + b - c;
  const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
};

/** Devolve {largura, altura, pixels} com pixels em RGBA8 (4 bytes por pixel). */
export function decodificar(buffer) {
  if (!buffer.slice(0, 8).equals(ASSINATURA)) throw new Error('não é PNG');
  let pos = 8, cabecalho = null, paleta = null, transparencia = null;
  const partesIdat = [];
  while (pos < buffer.length) {
    const tam = buffer.readUInt32BE(pos);
    const tipo = buffer.toString('latin1', pos + 4, pos + 8);
    const dados = buffer.subarray(pos + 8, pos + 8 + tam);
    if (tipo === 'IHDR') {
      cabecalho = {
        largura: dados.readUInt32BE(0),
        altura: dados.readUInt32BE(4),
        profundidade: dados[8],
        tipoCor: dados[9],
        entrelacado: dados[12],
      };
    } else if (tipo === 'PLTE') paleta = Buffer.from(dados);
    else if (tipo === 'tRNS') transparencia = Buffer.from(dados);
    else if (tipo === 'IDAT') partesIdat.push(Buffer.from(dados));
    else if (tipo === 'IEND') break;
    pos += 12 + tam;
  }
  if (!cabecalho) throw new Error('PNG sem IHDR');
  const { largura, altura, profundidade, tipoCor, entrelacado } = cabecalho;
  if (profundidade !== 8) throw new Error(`profundidade ${profundidade} não suportada`);
  if (entrelacado) throw new Error('PNG entrelaçado não suportado');
  const canais = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[tipoCor];
  if (!canais) throw new Error(`tipo de cor ${tipoCor} não suportado`);

  const bruto = zlib.inflateSync(Buffer.concat(partesIdat));
  const bpp = canais;
  const passo = largura * bpp;
  const linhas = Buffer.alloc(altura * passo);
  let off = 0;
  for (let y = 0; y < altura; y++) {
    const filtro = bruto[off++];
    const linha = bruto.subarray(off, off + passo);
    off += passo;
    const destino = linhas.subarray(y * passo, (y + 1) * passo);
    const anterior = y > 0 ? linhas.subarray((y - 1) * passo, y * passo) : null;
    for (let x = 0; x < passo; x++) {
      const a = x >= bpp ? destino[x - bpp] : 0;
      const b = anterior ? anterior[x] : 0;
      const c = anterior && x >= bpp ? anterior[x - bpp] : 0;
      const v = linha[x];
      destino[x] =
        filtro === 0 ? v :
        filtro === 1 ? (v + a) & 0xff :
        filtro === 2 ? (v + b) & 0xff :
        filtro === 3 ? (v + ((a + b) >> 1)) & 0xff :
        filtro === 4 ? (v + paeth(a, b, c)) & 0xff :
        (() => { throw new Error(`filtro ${filtro} inválido`); })();
    }
  }

  const pixels = Buffer.alloc(largura * altura * 4);
  for (let i = 0, n = largura * altura; i < n; i++) {
    const s = i * bpp, d = i * 4;
    if (tipoCor === 0) { pixels[d] = pixels[d + 1] = pixels[d + 2] = linhas[s]; pixels[d + 3] = 255; }
    else if (tipoCor === 2) { pixels[d] = linhas[s]; pixels[d + 1] = linhas[s + 1]; pixels[d + 2] = linhas[s + 2]; pixels[d + 3] = 255; }
    else if (tipoCor === 3) {
      const idx = linhas[s];
      pixels[d] = paleta[idx * 3]; pixels[d + 1] = paleta[idx * 3 + 1]; pixels[d + 2] = paleta[idx * 3 + 2];
      pixels[d + 3] = transparencia && idx < transparencia.length ? transparencia[idx] : 255;
    }
    else if (tipoCor === 4) { pixels[d] = pixels[d + 1] = pixels[d + 2] = linhas[s]; pixels[d + 3] = linhas[s + 1]; }
    else { pixels[d] = linhas[s]; pixels[d + 1] = linhas[s + 1]; pixels[d + 2] = linhas[s + 2]; pixels[d + 3] = linhas[s + 3]; }
  }
  return { largura, altura, pixels };
}

/**
 * Codifica RGBA8 em PNG. A escolha de filtro por linha é a heurística clássica
 * da soma de valores absolutos — determinística, sem sorteio: gerar duas vezes
 * tem de dar o mesmo SHA-256, senão a guarda de hash no CI vira ruído.
 */
export function codificar({ largura, altura, pixels }, { comAlfa = true } = {}) {
  const canais = comAlfa ? 4 : 3;
  const passo = largura * canais;
  const bruto = Buffer.alloc(altura * (passo + 1));
  const linha = Buffer.alloc(passo);
  let anterior = Buffer.alloc(passo);
  const candidato = Buffer.alloc(passo);
  for (let y = 0; y < altura; y++) {
    for (let x = 0; x < largura; x++) {
      const s = (y * largura + x) * 4, d = x * canais;
      linha[d] = pixels[s]; linha[d + 1] = pixels[s + 1]; linha[d + 2] = pixels[s + 2];
      if (comAlfa) linha[d + 3] = pixels[s + 3];
    }
    let melhorTipo = 0, melhorSoma = Infinity;
    const melhor = Buffer.alloc(passo);
    for (let tipo = 0; tipo <= 4; tipo++) {
      let soma = 0;
      for (let x = 0; x < passo; x++) {
        const a = x >= canais ? linha[x - canais] : 0;
        const b = anterior[x];
        const c = x >= canais ? anterior[x - canais] : 0;
        const v =
          tipo === 0 ? linha[x] :
          tipo === 1 ? linha[x] - a :
          tipo === 2 ? linha[x] - b :
          tipo === 3 ? linha[x] - ((a + b) >> 1) :
          linha[x] - paeth(a, b, c);
        candidato[x] = v & 0xff;
        soma += candidato[x] < 128 ? candidato[x] : 256 - candidato[x];
      }
      if (soma < melhorSoma) { melhorSoma = soma; melhorTipo = tipo; candidato.copy(melhor); }
    }
    const base = y * (passo + 1);
    bruto[base] = melhorTipo;
    melhor.copy(bruto, base + 1);
    linha.copy(anterior);
  }
  const pedaco = (tipo, dados) => {
    const cabeca = Buffer.alloc(8);
    cabeca.writeUInt32BE(dados.length, 0);
    cabeca.write(tipo, 4, 'latin1');
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([cabeca.subarray(4), dados])), 0);
    return Buffer.concat([cabeca, dados, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(largura, 0);
  ihdr.writeUInt32BE(altura, 4);
  ihdr[8] = 8; ihdr[9] = comAlfa ? 6 : 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const idat = zlib.deflateSync(bruto, { level: 9 });
  return Buffer.concat([ASSINATURA, pedaco('IHDR', ihdr), pedaco('IDAT', idat), pedaco('IEND', Buffer.alloc(0))]);
}
