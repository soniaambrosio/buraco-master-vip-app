// bootstrap_credencial_motor.js — A ÚNICA VEZ QUE UMA CREDENCIAL ADMINISTRATIVA
// TOCA A CREDENCIAL DO MOTOR.
//
// O passo 7 da ativação do provisionador (docs/PROVISIONAMENTO-CLAIM-MOTOR-PARTIDAS-V1.md
// §9) ficou em aberto com a pergunta certa: "como o Railway obtém ID token
// renovado sem chave versionada?". Este script é a metade administrativa da
// resposta. A outra metade é `servidor/credencial_motor.js`, no repositório do
// servidor.
//
// O DESENHO, EM UMA FRASE: o operador troca UMA VEZ uma credencial
// administrativa por um REFRESH TOKEN, e o Railway vive desse refresh token para
// sempre — renovando ID tokens sozinho, sem chave de conta de serviço, sem
// `firebase-admin` e sem login interativo.
//
//   credencial administrativa (aqui, na máquina do operador, uma vez)
//     → createCustomToken(uid)
//     → POST identitytoolkit accounts:signInWithCustomToken
//     → { idToken, refreshToken }
//     → o REFRESH TOKEN vira segredo do Railway
//
//   Railway (para sempre, sem credencial administrativa)
//     → POST securetoken /v1/token  (grant_type=refresh_token)
//     → idToken novo, só em memória
//
// POR QUE O REFRESH TOKEN, E NÃO O CUSTOM TOKEN. Um custom token expira em uma
// hora e só pode ser EMITIDO por quem tem credencial administrativa — guardá-lo
// no Railway obrigaria a rodar este script toda hora, e guardar a credencial que
// o emite obrigaria a pôr uma chave de conta de serviço no Railway. As duas
// saídas são as que a OS proíbe. O refresh token não expira por tempo, é
// revogável de fora (`revokeRefreshTokens`), e trocá-lo por um ID token exige
// só a Web API Key, que não é segredo.
//
// POR QUE ESTE SCRIPT NÃO É UMA CLOUD FUNCTION. Mesmo motivo do provisionador,
// e mais forte aqui: esta ferramenta PRODUZ uma credencial de longa duração.
// Uma Function que a produzisse seria uma superfície de rede cujo
// comprometimento entrega a autoridade da partida sem sequer precisar do claim.
//
// POR QUE AQUI, E NÃO EM `firebase/scripts/`. `firebase-admin` é dependência de
// `functions/`, e o Node resolve módulos a partir do diretório do próprio
// script. Além disso `scripts/` está fora de `tsconfig.include` (`src` apenas),
// `index.ts` não o reexporta, e `firebase.json` já o exclui do pacote — as três
// travas que impedem qualquer coisa daqui de virar Cloud Function.
//
// ENSAIO É O PADRÃO, e aqui ele é mais estrito que no provisionador: sem
// `--commit` o script NÃO EMITE TOKEN NENHUM. Não é só a escrita em disco que
// fica de fora — a própria criação do custom token, que é o ato irreversível de
// materializar uma credencial, só acontece com `--commit`.
//
// Uso:
//   cd functions
//   export FIREBASE_WEB_API_KEY=...        # nunca em argumento (ver §Segredos)
//
//   # ensaio — valida projeto, uid, claim e destino; não emite nada
//   node scripts/bootstrap_credencial_motor.js \
//        --project <id> --uid <uid> --saida <caminho FORA do repositório>
//
//   # gravação — dupla digitação do projeto
//   node scripts/bootstrap_credencial_motor.js \
//        --project <id> --uid <uid> --saida <caminho FORA do repositório> \
//        --commit --confirmar-projeto <id>

'use strict';

const fsReal = require('fs');
const pathReal = require('path');
const httpsReal = require('https');

/// O claim exigido. Mesma constante de `src/autoridade.ts` e do provisionador —
/// o teste prova que as três grafias coincidem.
const CLAIM = 'motorDePartidas';

/// Forma de um id de projeto Firebase. Barra argumento trocado de lugar antes de
/// o SDK sequer carregar.
const FORMA_PROJETO = /^[a-z][a-z0-9-]{3,29}$/;

/// A troca oficial de custom token por par ID token + refresh token.
/// https://firebase.google.com/docs/reference/rest/auth
const HOST_TROCA = 'identitytoolkit.googleapis.com';
const CAMINHO_TROCA = '/v1/accounts:signInWithCustomToken';

/// Teto da resposta lida. Um corpo sem fim numa máquina de operador é menos
/// grave que em produção, mas ler sem limite continua sendo um jeito de o outro
/// lado escolher quanta memória gastamos.
const LIMITE_RESPOSTA_BYTES = 64 * 1024;
const TIMEOUT_TROCA_MS = 15000;

/// `0o600`: só o dono lê e escreve. O arquivo carrega um refresh token, que é
/// credencial de longa duração — deixá-lo legível ao grupo numa máquina
/// compartilhada anula todo o resto.
const MODO_ARQUIVO = 0o600;

// ---------------------------------------------------------------------------
// DECISÃO PURA — sem rede, sem SDK, sem disco. É o que os testes exercitam.
// ---------------------------------------------------------------------------

/// Mostra o suficiente para o operador conferir que é o UID certo, e pouco
/// demais para que um log colado num chamado entregue a identidade técnica.
function mascararUid(uid) {
  if (typeof uid !== 'string' || uid.length === 0) return '(vazio)';
  if (uid.length <= 6) return uid[0] + '…' + uid[uid.length - 1];
  return uid.slice(0, 4) + '…' + uid.slice(-2);
}

/// Descreve um segredo sem o entregar: só o tamanho.
///
/// NÃO imprime prefixo, sufixo nem hash. Um prefixo de refresh token identifica
/// o projeto; um hash estável permite correlacionar dois logs e concluir que é a
/// mesma credencial. O comprimento responde "veio alguma coisa?" e nada mais.
function descreverSegredo(valor) {
  if (typeof valor !== 'string' || valor.length === 0) return '(ausente)';
  return '(' + valor.length + ' caracteres, não impresso)';
}

function analisarArgumentos(argv) {
  const valor = (nome) => {
    const i = argv.indexOf(nome);
    return i >= 0 ? argv[i + 1] : null;
  };
  const projectId = valor('--project');
  const uid = valor('--uid');
  const saida = valor('--saida');
  const commit = argv.includes('--commit');
  const confirmacao = valor('--confirmar-projeto');

  if (!projectId) return { erro: '--project é obrigatório' };
  if (!FORMA_PROJETO.test(projectId)) {
    return { erro: '--project não parece um id de projeto Firebase: ' + projectId };
  }
  if (!uid) return { erro: '--uid é obrigatório' };
  // O destino é exigido SEMPRE, e não só com `--commit`: o ensaio existe para
  // conferir o plano inteiro, e um plano que não diz onde o segredo vai parar
  // não é o plano que vai ser executado.
  if (!saida) return { erro: '--saida é obrigatório (caminho FORA do repositório)' };

  // DUPLA DIGITAÇÃO. O projeto tem de ser escrito duas vezes para que algo seja
  // emitido. Aqui a proteção vale ainda mais que no provisionador: emitir a
  // credencial no projeto de produção achando que era o de teste produz um
  // segredo REAL que já nasce fora do lugar.
  if (commit && confirmacao !== projectId) {
    return {
      erro: '--commit exige --confirmar-projeto idêntico a --project ' +
        '(recebido: ' + (confirmacao === null ? '(ausente)' : confirmacao) + ')',
    };
  }
  return { projectId, uid, saida, commit };
}

/// O destino é aceitável?
///
/// Duas recusas, e as duas são categóricas:
///
///   DENTRO DO REPOSITÓRIO — um refresh token dentro da árvore de trabalho é um
///   `git add .` de distância de virar segredo versionado, e segredo versionado
///   não se apaga: fica no histórico. Nenhum `.gitignore` compensa isso, porque
///   quem escreve o arquivo não controla o `.gitignore` de quem o clona.
///
///   ARQUIVO JÁ EXISTENTE — sobrescrever apagaria uma credencial que talvez
///   esteja em uso no Railway neste instante, e ninguém descobriria antes de o
///   servidor parar de autenticar.
function validarDestino(saida, raizRepo, existe) {
  const alvo = pathReal.resolve(saida);
  const raiz = pathReal.resolve(raizRepo);
  const relativo = pathReal.relative(raiz, alvo);
  const dentro = relativo !== '' && !relativo.startsWith('..') && !pathReal.isAbsolute(relativo);
  if (dentro) {
    return {
      ok: false,
      erro: 'o destino está DENTRO do repositório (' + relativo + '). ' +
        'Um refresh token na árvore de trabalho é um `git add` de distância de ' +
        'virar segredo versionado — e segredo versionado não se apaga do histórico.',
    };
  }
  if (existe) {
    return {
      ok: false,
      erro: 'o destino já existe: ' + alvo + '. Este script nunca sobrescreve — ' +
        'o arquivo de lá pode ser a credencial em uso agora. Mova-o ou escolha outro nome.',
    };
  }
  return { ok: true, alvo };
}

/// O usuário tem autoridade para virar credencial do motor?
///
/// `=== true` é ESTRITO, e é o MESMO contrato de `src/autoridade.ts`. Aceitar
/// `"true"` ou `1` aqui produziria uma credencial que o receptor recusa — o
/// operador sairia com um segredo no Railway e um servidor que não autentica, e
/// o defeito só apareceria na primeira partida encerrada.
///
/// Este script NÃO concede o claim. Conceder é do provisionador, e separar as
/// duas ferramentas é de propósito: quem produz credencial não deve poder também
/// se autorizar.
function avaliarClaim(claims) {
  const atuais = claims && typeof claims === 'object' ? claims : {};
  const bruto = atuais[CLAIM];
  if (bruto === true) return { ok: true };
  if (bruto === undefined) {
    return {
      ok: false,
      erro: 'o usuário não tem o claim `' + CLAIM + '`. Conceda antes, com ' +
        'scripts/provisionar_claim_motor_partidas.js grant.',
    };
  }
  return {
    ok: false,
    erro: 'o claim `' + CLAIM + '` existe com o tipo errado (' + typeof bruto + ': ' +
      JSON.stringify(bruto) + ') e NÃO autoriza — a guarda exige o booleano `true`. ' +
      'Corrija com scripts/provisionar_claim_motor_partidas.js grant.',
  };
}

/// Lê o payload de um JWT compacto SEM verificar assinatura.
///
/// Isto é leitura de conferência, não de autoridade — e a distinção importa: no
/// bootstrap a autoridade final vem do `verifyIdToken` do Admin SDK, chamado
/// logo em seguida. Decodificar aqui serve para dizer ao operador QUAL
/// identidade chegou antes de gravar qualquer coisa.
function decodificarPayload(jwt) {
  if (typeof jwt !== 'string') return null;
  const p = jwt.split('.');
  if (p.length !== 3) return null;
  try {
    const bruto = Buffer.from(p[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
    const payload = JSON.parse(bruto);
    return payload && typeof payload === 'object' ? payload : null;
  } catch (_) {
    return null;
  }
}

/// A identidade que voltou é a que se pediu?
///
/// O endpoint de troca NÃO devolve `localId` nem `projectId` em campo próprio —
/// eles vêm dentro do ID token. Conferir aqui fecha o caso em que a Web API Key
/// pertence a OUTRO projeto: a troca daria certo, o token voltaria válido, e o
/// operador gravaria no Railway uma credencial do projeto errado.
function conferirIdentidade(payload, esperado) {
  if (!payload) return { ok: false, erro: 'o ID token devolvido não é um JWT legível' };
  const issEsperado = 'https://securetoken.google.com/' + esperado.projectId;
  if (payload.sub !== esperado.uid) {
    return {
      ok: false,
      erro: 'o ID token devolvido pertence a OUTRO usuário (esperado ' +
        mascararUid(esperado.uid) + ', veio ' + mascararUid(payload.sub) + ')',
    };
  }
  if (payload.aud !== esperado.projectId) {
    return {
      ok: false,
      erro: 'o ID token devolvido é de OUTRO projeto (aud=' + JSON.stringify(payload.aud) +
        ', esperado ' + esperado.projectId + '). A Web API Key provavelmente é de outro projeto.',
    };
  }
  if (payload.iss !== issEsperado) {
    return {
      ok: false,
      erro: 'o emissor do ID token não é o esperado (iss=' + JSON.stringify(payload.iss) + ')',
    };
  }
  if (payload[CLAIM] !== true) {
    return {
      ok: false,
      erro: 'o ID token devolvido NÃO carrega `' + CLAIM + ': true`. O claim foi ' +
        'concedido depois de o token ser emitido, ou não foi concedido.',
    };
  }
  return { ok: true };
}

/// A resposta da troca tem o que o Railway precisa?
function conferirRespostaDaTroca(corpo) {
  if (!corpo || typeof corpo !== 'object') {
    return { ok: false, erro: 'a resposta da troca não é um objeto JSON' };
  }
  if (typeof corpo.idToken !== 'string' || corpo.idToken.length === 0) {
    return { ok: false, erro: 'a resposta da troca não trouxe idToken' };
  }
  // O refresh token é o ÚNICO item desta operação que sobrevive a ela. Sem ele o
  // bootstrap não produziu nada de útil, e gravar um arquivo sem ele deixaria o
  // operador achando que terminou.
  if (typeof corpo.refreshToken !== 'string' || corpo.refreshToken.length === 0) {
    return { ok: false, erro: 'a resposta da troca não trouxe refreshToken' };
  }
  return { ok: true };
}

/// O conteúdo do arquivo de bootstrap: o que o operador cola no Railway.
///
/// O QUE NÃO ENTRA, e cada ausência é uma decisão:
///   - o ID token, porque ele expira em uma hora e o servidor o obtém sozinho.
///     Gravá-lo ensinaria que existe um token para guardar, e não existe;
///   - o custom token, porque ele já cumpriu o papel dele nesta execução;
///   - a Web API Key, porque ela é CONFIGURAÇÃO do projeto e não segredo — sai
///     no runbook, não num arquivo de modo 0600 que ninguém vai querer abrir.
function materialDeBootstrap({ projectId, uid, refreshToken, carimbo }) {
  return [
    '# Buraco Master VIP — credencial de execução do Motor de Partidas.',
    '#',
    '# GERADO POR functions/scripts/bootstrap_credencial_motor.js.',
    '# NÃO versione este arquivo. NÃO o cole em chamado, log ou mensagem.',
    '#',
    '# FIREBASE_MOTOR_REFRESH_TOKEN é SEGREDO de longa duração: quem o tiver',
    '# obtém ID tokens com `' + CLAIM + '` e escreve encerramento de partida.',
    '# Para cortar o acesso, revogue as sessões do UID abaixo',
    '# (admin.auth().revokeRefreshTokens) — trocar este arquivo não basta.',
    '#',
    '# Gerado em: ' + carimbo,
    '',
    'FIREBASE_PROJECT_ID=' + projectId,
    'FIREBASE_MOTOR_UID=' + uid,
    'FIREBASE_MOTOR_REFRESH_TOKEN=' + refreshToken,
    '',
  ].join('\n');
}

// ---------------------------------------------------------------------------
// TROCA REST — `https` nativo, sem dependência nova
// ---------------------------------------------------------------------------

/// Troca o custom token pelo par ID token + refresh token.
///
/// `https` do Node, e não um cliente HTTP: acrescentar dependência a
/// `functions/` para uma requisição só aumentaria a árvore que sobe no pacote de
/// implantação — e este script nem viaja nele.
function trocarCustomTokenHttps({ apiKey, customToken, https = httpsReal }) {
  return new Promise((ok, falha) => {
    const corpo = JSON.stringify({ token: customToken, returnSecureToken: true });
    const req = https.request(
      {
        host: HOST_TROCA,
        path: CAMINHO_TROCA + '?key=' + encodeURIComponent(apiKey),
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'content-length': Buffer.byteLength(corpo),
        },
      },
      (res) => {
        let bruto = '';
        let excedeu = false;
        res.setEncoding('utf8');
        res.on('data', (d) => {
          if (excedeu) return;
          bruto += d;
          if (bruto.length > LIMITE_RESPOSTA_BYTES) {
            excedeu = true;
            res.destroy();
            falha(new Error('resposta da troca acima do limite'));
          }
        });
        res.on('end', () => {
          if (excedeu) return;
          if (res.statusCode !== 200) {
            // A mensagem de erro do Google pode ecoar o token enviado. Só o
            // status sai daqui.
            return falha(new Error('a troca falhou com HTTP ' + res.statusCode));
          }
          try {
            ok(JSON.parse(bruto));
          } catch (_) {
            falha(new Error('a resposta da troca não é JSON'));
          }
        });
      }
    );
    req.setTimeout(TIMEOUT_TROCA_MS, () => req.destroy(new Error('timeout na troca')));
    req.on('error', (e) => falha(new Error('falha de rede na troca: ' + e.message)));
    req.end(corpo);
  });
}

// ---------------------------------------------------------------------------
// ESCRITA ATÔMICA
// ---------------------------------------------------------------------------

/// Grava o material com modo restrito, sem nunca deixar arquivo parcial.
///
/// Temporário no MESMO diretório e depois `rename`: o destino final ou não
/// existe, ou existe completo. Escrever direto no destino deixaria, numa falha
/// no meio, um arquivo com meio refresh token — que o operador colaria no
/// Railway sem perceber, e o servidor falharia com "credencial inválida" sem
/// ninguém saber por quê.
///
/// `wx` no temporário: criação EXCLUSIVA. Se o nome já existe, falha em vez de
/// sobrescrever.
///
/// LIMITAÇÃO DECLARADA — no Windows o modo POSIX é ignorado pelo `fs`. O
/// `chmod` é chamado assim mesmo (é inócuo, não erra), e o script AVISA quando a
/// plataforma não sustenta a restrição. Fingir que 0o600 valeu ali seria a
/// pior das saídas.
function gravarMaterial({ alvo, conteudo, fs = fsReal, plataforma = process.platform }) {
  const temporario = alvo + '.parcial-' + process.pid;
  let fd = null;
  try {
    fd = fs.openSync(temporario, 'wx', MODO_ARQUIVO);
    fs.writeFileSync(fd, conteudo, { encoding: 'utf8' });
    fs.fsyncSync(fd);
    fs.closeSync(fd);
    fd = null;
    fs.chmodSync(temporario, MODO_ARQUIVO);
    fs.renameSync(temporario, alvo);
  } catch (e) {
    // Abandono seguro: nem o temporário nem o destino ficam para trás.
    try { if (fd !== null) fs.closeSync(fd); } catch (_) { /* já fechado */ }
    try { fs.unlinkSync(temporario); } catch (_) { /* nunca chegou a existir */ }
    throw e;
  }
  return {
    modo: MODO_ARQUIVO,
    restricaoSustentada: plataforma !== 'win32',
  };
}

// ---------------------------------------------------------------------------
// EXECUÇÃO
// ---------------------------------------------------------------------------

const USO = [
  'uso: node scripts/bootstrap_credencial_motor.js \\',
  '       --project <id> --uid <uid> --saida <caminho FORA do repositório> \\',
  '       [--commit --confirmar-projeto <id>]',
  '',
  'A Web API Key vem de FIREBASE_WEB_API_KEY (variável de ambiente).',
  'NÃO a passe em argumento: argumento aparece no histórico do shell e na',
  'lista de processos da máquina.',
  '',
  'Sem --commit o script apenas ENSAIA: nenhum token é emitido e nada é escrito.',
].join('\n');

/// Raiz do repositório, procurando `.git` para cima. É o que `validarDestino`
/// usa para recusar um destino dentro da árvore de trabalho.
function acharRaizRepo(partida) {
  let atual = pathReal.resolve(partida);
  for (let i = 0; i < 12; i++) {
    if (fsReal.existsSync(pathReal.join(atual, '.git'))) return atual;
    const pai = pathReal.dirname(atual);
    if (pai === atual) break;
    atual = pai;
  }
  // Sem `.git` encontrado, assume-se a raiz relativa ao próprio script. Falhar
  // para o lado seguro: melhor recusar um destino legítimo do que aceitar um
  // dentro do repositório.
  return pathReal.resolve(partida, '..', '..');
}

async function main(argv, deps = {}) {
  const log = deps.log || console.log;
  const erro = deps.erro || console.error;
  const env = deps.env || process.env;
  const fs = deps.fs || fsReal;
  const trocar = deps.trocar || trocarCustomTokenHttps;
  const plataforma = deps.plataforma || process.platform;
  const agora = deps.agora || (() => new Date());

  const args = analisarArgumentos(argv);
  if (args.erro) {
    erro('ERRO: ' + args.erro);
    erro('\n' + USO);
    return 1;
  }
  const { projectId, uid, saida, commit } = args;
  const raizRepo = deps.raizRepo || acharRaizRepo(__dirname);

  log('operação        : bootstrap da credencial do motor');
  log('projeto         : ' + projectId);
  log('uid             : ' + mascararUid(uid) + '  (mascarado)');
  log('destino         : ' + pathReal.resolve(saida));
  log('modo            : ' + (commit ? 'GRAVAÇÃO (--commit)' : 'ENSAIO (nenhum token será emitido)'));

  // O destino é validado ANTES de qualquer emissão. Descobrir que o caminho é
  // inválido depois de já ter materializado um refresh token deixaria uma
  // credencial viva no projeto sem ninguém para guardá-la.
  const destino = validarDestino(saida, raizRepo, fs.existsSync(pathReal.resolve(saida)));
  if (!destino.ok) {
    erro('\nERRO: ' + destino.erro);
    return 1;
  }

  const apiKey = env.FIREBASE_WEB_API_KEY;
  if (commit && (typeof apiKey !== 'string' || apiKey.length === 0)) {
    erro('\nERRO: FIREBASE_WEB_API_KEY não está definida no ambiente.');
    erro('Ela é a Web API Key do projeto (Console → Configurações → Geral).');
    erro('Nada foi emitido.');
    return 1;
  }

  const admin = deps.admin || require('firebase-admin');
  if (admin.apps.length === 0) admin.initializeApp({ projectId });

  // Mesma trava do provisionador: o SDK resolve o projeto de várias fontes, e o
  // que ele resolveu tem de ser o que o operador pediu.
  const resolvido = admin.app().options.projectId;
  if (resolvido && resolvido !== projectId) {
    erro('\nERRO: o SDK resolveu o projeto "' + resolvido + '", e não "' + projectId + '".');
    erro('Nada foi emitido. Verifique GOOGLE_APPLICATION_CREDENTIALS e as variáveis de ambiente.');
    return 1;
  }

  const auth = admin.auth();
  let usuario;
  try {
    usuario = await auth.getUser(uid);
  } catch (e) {
    erro('\nERRO: não foi possível ler o usuário (' + (e.code || e.message) + ').');
    erro('Nada foi emitido. Este script NÃO cria identidade.');
    return 1;
  }

  const claim = avaliarClaim(usuario.customClaims);
  log('\nclaim           : ' + CLAIM + '=' + JSON.stringify((usuario.customClaims || {})[CLAIM]));
  if (!claim.ok) {
    erro('\nERRO: ' + claim.erro);
    erro('Nada foi emitido.');
    return 1;
  }
  log('autoridade      : CONFIRMADA');

  log('\nplano           :');
  log('  1. emitir custom token para ' + mascararUid(uid));
  log('  2. trocá-lo em ' + HOST_TROCA + CAMINHO_TROCA);
  log('  3. conferir sub/aud/iss/' + CLAIM + ' do ID token devolvido');
  log('  4. verificar o ID token pelo Admin SDK, com checkRevoked');
  log('  5. gravar SOMENTE o refresh token em ' + destino.alvo + ' (modo 0600)');
  log('  o ID token e o custom token NÃO são gravados, e nenhum é impresso.');

  if (!commit) {
    log('\n--- ENSAIO: nenhum token foi emitido e nada foi escrito. ---');
    log('Repita com --commit --confirmar-projeto ' + projectId);
    return 0;
  }

  let customToken;
  try {
    customToken = await auth.createCustomToken(uid);
  } catch (e) {
    erro('\nERRO: falha ao emitir o custom token (' + (e.code || e.message) + ').');
    erro('Nada foi escrito.');
    return 1;
  }

  let resposta;
  try {
    resposta = await trocar({ apiKey, customToken });
  } catch (e) {
    erro('\nERRO: ' + e.message);
    erro('Nada foi escrito.');
    return 1;
  }

  const forma = conferirRespostaDaTroca(resposta);
  if (!forma.ok) {
    erro('\nERRO: ' + forma.erro);
    erro('Nada foi escrito.');
    return 1;
  }

  const identidade = conferirIdentidade(decodificarPayload(resposta.idToken), { uid, projectId });
  if (!identidade.ok) {
    erro('\nERRO: ' + identidade.erro);
    erro('Nada foi escrito.');
    return 1;
  }

  // Conferência CRIPTOGRÁFICA, e não só a leitura acima. `checkRevoked: true` é
  // o mesmo contrato que o receptor passou a exigir: se a sessão desta
  // identidade já estiver revogada, o bootstrap não deve entregar ao Railway uma
  // credencial que nasce recusada.
  try {
    await auth.verifyIdToken(resposta.idToken, true);
  } catch (e) {
    erro('\nERRO: o ID token devolvido não passou na verificação do Admin SDK (' +
      (e.code || e.message) + ').');
    erro('Nada foi escrito.');
    return 1;
  }
  log('\nverificação     : assinatura e revogação conferidas (checkRevoked)');
  log('id token        : ' + descreverSegredo(resposta.idToken) + ' — descartado, só existe em memória');
  log('refresh token   : ' + descreverSegredo(resposta.refreshToken));

  const conteudo = materialDeBootstrap({
    projectId,
    uid,
    refreshToken: resposta.refreshToken,
    carimbo: agora().toISOString(),
  });

  let gravacao;
  try {
    gravacao = gravarMaterial({ alvo: destino.alvo, conteudo, fs, plataforma });
  } catch (e) {
    erro('\nERRO: falha ao gravar (' + e.message + ').');
    erro('Nenhum arquivo parcial ficou para trás. A credencial FOI emitida no projeto:');
    erro('revogue as sessões de ' + mascararUid(uid) + ' antes de tentar de novo.');
    return 2;
  }

  log('\ngravado         : ' + destino.alvo);
  log('modo            : 0' + gravacao.modo.toString(8) +
    (gravacao.restricaoSustentada ? '' : '  ⚠ ESTA PLATAFORMA (Windows) IGNORA O MODO POSIX'));
  if (!gravacao.restricaoSustentada) {
    log('                  restrinja o acesso pelo Explorer/icacls, ou gere em máquina POSIX.');
  }
  log('\nPRÓXIMO PASSO: copie as três variáveis para os segredos do Railway e');
  log('APAGUE o arquivo. Ele não tem por que sobreviver à cópia.');
  log('O ID token NÃO vai para o Railway: o servidor o obtém sozinho, do refresh token.');
  return 0;
}

module.exports = {
  CLAIM,
  FORMA_PROJETO,
  HOST_TROCA,
  CAMINHO_TROCA,
  LIMITE_RESPOSTA_BYTES,
  MODO_ARQUIVO,
  analisarArgumentos,
  validarDestino,
  avaliarClaim,
  decodificarPayload,
  conferirIdentidade,
  conferirRespostaDaTroca,
  materialDeBootstrap,
  gravarMaterial,
  mascararUid,
  descreverSegredo,
  acharRaizRepo,
  main,
};

if (require.main === module) {
  main(process.argv.slice(2))
    .then((codigo) => process.exit(codigo))
    .catch((e) => {
      // `e.message` e nada mais: uma stack de erro de rede pode carregar o corpo
      // da requisição, e o corpo da requisição carrega o custom token.
      console.error('FALHOU:', e.message);
      process.exit(1);
    });
}
