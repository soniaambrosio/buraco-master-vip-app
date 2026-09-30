// Gera, de forma determinística, TODOS os recursos nativos de marca do Android a
// partir de uma única arte autoritativa: `branding/fonte/icone_oficial_bmv_512.png`.
//
// Por que gerar e COMMITAR em vez de gerar no CI: o `build.yml` monta o projeto
// host na hora com `flutter create`, e a lição registrada em build.yml é que o que
// não é copiado por nome simplesmente não chega ao APK — em silêncio. Arquivo
// commitado + guarda de SHA-256 no passo de cópia torna o defeito ruidoso.
//
// Rodar:  node tools/branding/gerar_icones_android.mjs
// A saída tem de ser byte a byte igual entre execuções (o CI confere o SHA).
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { decodificar, codificar } from './png.mjs';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ = path.resolve(AQUI, '..', '..');
const FONTE = path.join(RAIZ, 'branding', 'fonte', 'icone_oficial_bmv_512.png');
const RES = path.join(RAIZ, 'branding', 'android', 'res');

// ---------------------------------------------------------------------------
// Geometria, medida na arte e não chutada (ver docs/ICONE-NATIVO-ANDROID-V1.md):
//  - a moldura dourada começa a 23 px das bordas, num quadrado de 512;
//  - o arco do canto tem centro em (113,113) e raio 90 px;
//  - o assunto (coroa + cartas) ocupa x 99..410, y 52..461.
// ---------------------------------------------------------------------------
const SILHUETA_INSET = 16; // recorte da margem chapada, 7 px antes da moldura
const SILHUETA_RAIO = 97; // 113 - 16: mesmo centro de arco da moldura
const ASSUNTO = { esq: 99, dir: 410, topo: 52, base: 461 };

// Canvas do ícone adaptativo: 108 dp, janela da máscara 72 dp, safe zone 66 dp.
// 78 dp é o único tamanho de arte que satisfaz as duas pontas ao mesmo tempo:
//   >= 72 dp   -> a arte cobre a janela, a camada de fundo nunca aparece;
//   <= 82.8 dp -> o assunto inteiro cabe na safe zone de 66 dp.
const CANVAS_DP = 108;
const ARTE_DP = 78;
const JANELA_DP = 72;
const SAFE_ZONE_DP = 66;

const DENSIDADES = [
  { nome: 'mdpi', escala: 1 },
  { nome: 'hdpi', escala: 1.5 },
  { nome: 'xhdpi', escala: 2 },
  { nome: 'xxhdpi', escala: 3 },
  { nome: 'xxxhdpi', escala: 4 },
];

// --- primitivas de imagem ---------------------------------------------------

const vazia = (largura, altura) => ({ largura, altura, pixels: Buffer.alloc(largura * altura * 4) });

/** Recorta uma janela da imagem. */
function recortar(img, x0, y0, largura, altura) {
  const fora = vazia(largura, altura);
  for (let y = 0; y < altura; y++) {
    const inicio = ((y0 + y) * img.largura + x0) * 4;
    img.pixels.copy(fora.pixels, y * largura * 4, inicio, inicio + largura * 4);
  }
  return fora;
}

/**
 * Redução por média de área (box filter), com peso fracionário nas bordas.
 * Para downscale — que é todo o uso aqui — equivale a supersampling exato e não
 * introduz o serrilhado do vizinho-mais-próximo. Trabalha em alfa pré-multiplicado
 * para não puxar cor de pixel transparente.
 */
function redimensionar(img, largura, altura) {
  const fora = vazia(largura, altura);
  const rx = img.largura / largura;
  const ry = img.altura / altura;
  for (let y = 0; y < altura; y++) {
    const y0 = y * ry;
    const y1 = (y + 1) * ry;
    for (let x = 0; x < largura; x++) {
      const x0 = x * rx;
      const x1 = (x + 1) * rx;
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      let peso = 0;
      for (let sy = Math.floor(y0); sy < Math.min(Math.ceil(y1), img.altura); sy++) {
        const py = Math.min(y1, sy + 1) - Math.max(y0, sy);
        for (let sx = Math.floor(x0); sx < Math.min(Math.ceil(x1), img.largura); sx++) {
          const p = py * (Math.min(x1, sx + 1) - Math.max(x0, sx));
          const i = (sy * img.largura + sx) * 4;
          const al = img.pixels[i + 3] / 255;
          r += img.pixels[i] * al * p;
          g += img.pixels[i + 1] * al * p;
          b += img.pixels[i + 2] * al * p;
          a += img.pixels[i + 3] * p;
          peso += p;
        }
      }
      const d = (y * largura + x) * 4;
      const alfa = a / peso;
      const desmult = alfa > 0 ? 255 / alfa : 0;
      fora.pixels[d] = Math.round(Math.min(255, (r / peso) * desmult));
      fora.pixels[d + 1] = Math.round(Math.min(255, (g / peso) * desmult));
      fora.pixels[d + 2] = Math.round(Math.min(255, (b / peso) * desmult));
      fora.pixels[d + 3] = Math.round(alfa);
    }
  }
  return fora;
}

/** Cola `fonte` centrada num canvas transparente de `lado` x `lado`. */
function centralizar(fonte, lado) {
  const fora = vazia(lado, lado);
  const x0 = Math.round((lado - fonte.largura) / 2);
  const y0 = Math.round((lado - fonte.altura) / 2);
  for (let y = 0; y < fonte.altura; y++) {
    const destino = ((y0 + y) * lado + x0) * 4;
    fonte.pixels.copy(fora.pixels, destino, y * fonte.largura * 4, (y + 1) * fonte.largura * 4);
  }
  return fora;
}

/**
 * Aplica alfa de retângulo arredondado, com 4x4 de supersampling na borda.
 * Sem o supersampling o contorno sai em degraus, e é justamente o contorno que
 * define a silhueta do ícone na starting window, onde o sistema NÃO mascara.
 */
function arredondar(img, raio) {
  const { largura: L, altura: A } = img;
  const dentro = (x, y) => {
    const cx = Math.min(Math.max(x, raio), L - raio);
    const cy = Math.min(Math.max(y, raio), A - raio);
    const dx = x - cx;
    const dy = y - cy;
    return dx * dx + dy * dy <= raio * raio;
  };
  for (let y = 0; y < A; y++) {
    for (let x = 0; x < L; x++) {
      let acertos = 0;
      for (let sy = 0; sy < 4; sy++) {
        for (let sx = 0; sx < 4; sx++) {
          if (dentro(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) acertos++;
        }
      }
      const i = (y * L + x) * 4;
      img.pixels[i + 3] = Math.round((img.pixels[i + 3] * acertos) / 16);
    }
  }
  return img;
}

/**
 * Silhueta monocromática (Android 13+, ícone temático): o sistema repinta a
 * camada com UMA cor e usa só o alfa. A luminância da arte já separa o que é
 * marca (ouro, cartas claras) do que é fundo (marrom quase preto), então o alfa
 * sai de uma rampa sobre a luminância — nada de recorte por limiar duro, que
 * comeria o degradê da coroa.
 */
function monocromatica(img, piso, teto) {
  const fora = vazia(img.largura, img.altura);
  for (let i = 0; i < img.largura * img.altura; i++) {
    const s = i * 4;
    const lum = 0.2126 * img.pixels[s] + 0.7152 * img.pixels[s + 1] + 0.0722 * img.pixels[s + 2];
    const t = Math.min(1, Math.max(0, (lum - piso) / (teto - piso)));
    fora.pixels[s] = 255;
    fora.pixels[s + 1] = 255;
    fora.pixels[s + 2] = 255;
    fora.pixels[s + 3] = Math.round(255 * t * (img.pixels[s + 3] / 255));
  }
  return fora;
}

// --- geração ----------------------------------------------------------------

function escrever(rel, buffer) {
  const destino = path.join(RES, rel);
  fs.mkdirSync(path.dirname(destino), { recursive: true });
  fs.writeFileSync(destino, buffer);
  console.log(
    String(buffer.length).padStart(7),
    crypto.createHash('sha256').update(buffer).digest('hex').slice(0, 16),
    rel.replace(/\\/g, '/'),
  );
}

const arte = decodificar(fs.readFileSync(FONTE));
if (arte.largura !== 512 || arte.altura !== 512) throw new Error('a arte oficial tem de ser 512x512');

// Provas geométricas ANTES de escrever: se a arte for trocada por outra com
// enquadramento diferente, isto reprova em vez de gerar um recurso torto.
if (ARTE_DP < JANELA_DP) throw new Error('arte menor que a janela da máscara: a camada de fundo apareceria');
const margemSegura = (512 * (1 - SAFE_ZONE_DP / ARTE_DP)) / 2;
const margens = { topo: ASSUNTO.topo, base: 512 - ASSUNTO.base, esq: ASSUNTO.esq, dir: 512 - ASSUNTO.dir };
for (const [lado, valor] of Object.entries(margens)) {
  if (valor < margemSegura) {
    throw new Error(`assunto fora da safe zone (${lado}: ${valor} px < ${margemSegura.toFixed(1)} px exigidos)`);
  }
}

// A silhueta: margem chapada fora, moldura dourada virando o contorno.
const silhueta = arredondar(
  recortar(arte, SILHUETA_INSET, SILHUETA_INSET, 512 - 2 * SILHUETA_INSET, 512 - 2 * SILHUETA_INSET),
  SILHUETA_RAIO,
);

// O assunto sozinho, num quadrado centrado na própria bbox — base da camada
// monocromática, que não deve carregar moldura.
const ladoAssunto = Math.max(ASSUNTO.dir - ASSUNTO.esq, ASSUNTO.base - ASSUNTO.topo);
const assunto = recortar(
  arte,
  Math.round((ASSUNTO.esq + ASSUNTO.dir - ladoAssunto) / 2),
  Math.round((ASSUNTO.topo + ASSUNTO.base - ladoAssunto) / 2),
  ladoAssunto,
  ladoAssunto,
);

for (const { nome, escala } of DENSIDADES) {
  const canvas = Math.round(CANVAS_DP * escala);
  const arteDp = Math.round(ARTE_DP * escala);

  // 1. Ícone herdado (API < 26, e qualquer consumidor que leia o bitmap direto).
  //    Vai a arte cheia: aqui ninguém aplica máscara.
  escrever(
    path.join(`mipmap-${nome}`, 'ic_launcher.png'),
    codificar(redimensionar(arte, Math.round(48 * escala), Math.round(48 * escala)), { comAlfa: false }),
  );

  // 2. Camada de frente do ícone adaptativo (API 26+): quadrado opaco de 78 dp
  //    num canvas de 108 dp. Quem arredonda é a máscara do launcher.
  escrever(
    path.join(`mipmap-${nome}`, 'ic_launcher_foreground.png'),
    codificar(centralizar(redimensionar(arte, arteDp, arteDp), canvas)),
  );

  // 3. Ícone da starting window (Android 12+): mesma geometria, mas com a
  //    silhueta recortada — o sistema desenha o drawable como está.
  escrever(
    path.join(`drawable-${nome}`, 'splash_icon.png'),
    codificar(centralizar(redimensionar(silhueta, arteDp, arteDp), canvas)),
  );

  // 4. Camada monocromática (Android 13+). Só o assunto, sem a moldura: a
  //    moldura vira arcos soltos quando reduzida a uma cor, e a diretriz do
  //    ícone temático é silhueta legível. Conteúdo dentro da safe zone de 66 dp,
  //    porque o ícone temático é mascarado igual ao adaptativo.
  escrever(
    path.join(`drawable-${nome}`, 'ic_launcher_monochrome.png'),
    codificar(
      centralizar(
        monocromatica(
          redimensionar(assunto, Math.round(SAFE_ZONE_DP * escala), Math.round(SAFE_ZONE_DP * escala)),
          45,
          150,
        ),
        canvas,
      ),
    ),
  );
}

// Manifesto de hashes: é ele que o `build.yml` confere com `sha256sum -c` antes
// de copiar. Sem isso, um PNG editado à mão (ou um checkout que reescreveu
// bytes) chega ao APK sem ninguém notar — o modo de falha silencioso que já
// mordeu este projeto com asset novo que não era copiado.
const BRANDING = path.join(RAIZ, 'branding');
const arquivos = ['fonte/icone_oficial_bmv_512.png'];
for (const dir of fs.readdirSync(RES).sort()) {
  for (const arq of fs.readdirSync(path.join(RES, dir)).sort()) arquivos.push(`android/res/${dir}/${arq}`);
}
const manifesto = arquivos
  .map((rel) => `${crypto.createHash('sha256').update(fs.readFileSync(path.join(BRANDING, rel))).digest('hex')}  ${rel}`)
  .join('\n');
fs.writeFileSync(path.join(BRANDING, 'MANIFESTO.sha256'), manifesto + '\n');
console.log(`\nbranding/MANIFESTO.sha256: ${arquivos.length} arquivos`);

console.log(
  `janela da máscara mostra ${((JANELA_DP / ARTE_DP) * 100).toFixed(1)}% da arte; ` +
    `a safe zone exige ${margemSegura.toFixed(1)} px de margem e a menor margem do assunto é ` +
    `${Math.min(...Object.values(margens))} px.`,
);
