// provisionar_claim_motor_partidas.js — EMISSOR DO CLAIM `motorDePartidas`.
//
// O claim tinha três consumidores e nenhum emissor: `registrarEncerramentoPartida`
// e `receberResultadoPartida` o exigem, `firestore.rules` conta com ele, e
// `setCustomUserClaims` não era chamado em lugar nenhum das linhagens auditadas.
// Este script é esse emissor, e é o único.
//
// POR QUE UM SCRIPT, E NÃO UMA CLOUD FUNCTION.
//
// Uma Function que concedesse `motorDePartidas` seria uma superfície de rede
// cujo comprometimento entrega a autoridade da partida inteira — quem a
// obtivesse escreveria o próprio placar. Um script roda sob credencial
// administrativa já controlada, não escuta porta nenhuma, e não pode ser
// chamado por um aparelho. A troca é deliberada: perde-se automação, ganha-se
// uma superfície a menos.
//
// POR QUE AQUI, E NÃO EM `firebase/scripts/`.
//
// `firebase-admin` é dependência de `functions/`, e o Node resolve módulos a
// partir do diretório do PRÓPRIO script — um arquivo em `firebase/scripts/` não
// alcançaria `functions/node_modules`. Além disso este diretório está fora de
// `tsconfig.include` (`src` apenas) e não é reexportado por `index.ts`, então
// nada daqui pode virar Cloud Function por acidente; e `firebase.json` o exclui
// do pacote de implantação.
//
// ENSAIO É O PADRÃO. Sem `--commit`, nada é escrito. É a mesma disciplina de
// `firebase/scripts/seed_pioneiros_2026.js`.
//
// Uso:
//   cd functions
//   node scripts/provisionar_claim_motor_partidas.js inspect --project <id> --uid <uid>
//   node scripts/provisionar_claim_motor_partidas.js grant   --project <id> --uid <uid>
//   node scripts/provisionar_claim_motor_partidas.js grant   --project <id> --uid <uid> \
//        --commit --confirmar-projeto <id>
//   node scripts/provisionar_claim_motor_partidas.js revoke  --project <id> --uid <uid> \
//        --commit --confirmar-projeto <id>

'use strict';

/// O claim emitido. Só este. Ver `functions/src/autoridade.ts`, que é quem o
/// consome — o teste prova que as duas grafias coincidem, porque um erro de
/// digitação aqui produziria um claim que nada lê e uma autoridade que nunca
/// funciona.
const CLAIM = 'motorDePartidas';

const OPERACOES = ['inspect', 'grant', 'revoke'];

/// Forma de um id de projeto Firebase. Não é cosmético: `--project` decide em
/// QUAL projeto o claim é escrito, e um valor com espaço, barra ou maiúscula é
/// quase sempre um argumento trocado de lugar.
const FORMA_PROJETO = /^[a-z][a-z0-9-]{3,29}$/;

// ---------------------------------------------------------------------------
// DECISÃO PURA — sem rede, sem SDK, sem processo. É o que os testes exercitam.
// ---------------------------------------------------------------------------

/// Mostra o suficiente para o operador conferir que é o UID certo, e pouco
/// demais para que um log colado num chamado entregue a identidade técnica.
function mascararUid(uid) {
  if (typeof uid !== 'string' || uid.length === 0) return '(vazio)';
  if (uid.length <= 6) return uid[0] + '…' + uid[uid.length - 1];
  return uid.slice(0, 4) + '…' + uid.slice(-2);
}

function analisarArgumentos(argv) {
  const operacao = argv[0];
  if (!OPERACOES.includes(operacao)) {
    return { erro: 'operação deve ser uma de: ' + OPERACOES.join(', ') };
  }
  const valor = (nome) => {
    const i = argv.indexOf(nome);
    return i >= 0 ? argv[i + 1] : null;
  };
  const projectId = valor('--project');
  const uid = valor('--uid');
  const commit = argv.includes('--commit');
  const confirmacao = valor('--confirmar-projeto');

  if (!projectId) return { erro: '--project é obrigatório' };
  if (!FORMA_PROJETO.test(projectId)) {
    return { erro: '--project não parece um id de projeto Firebase: ' + projectId };
  }
  if (!uid) return { erro: '--uid é obrigatório' };

  // `inspect` não escreve nunca. Aceitar `--commit` aqui seria ensinar o
  // operador que a flag é inofensiva — e ela não é nas outras duas operações.
  if (commit && operacao === 'inspect') {
    return { erro: 'inspect nunca escreve; remova --commit' };
  }
  // DUPLA DIGITAÇÃO. O projeto tem de ser escrito duas vezes para que a escrita
  // aconteça. É a proteção contra o erro mais caro possível aqui: conceder
  // autoridade de partida no projeto de produção achando que era o de teste.
  if (commit && confirmacao !== projectId) {
    return {
      erro: '--commit exige --confirmar-projeto idêntico a --project ' +
        '(recebido: ' + (confirmacao === null ? '(ausente)' : confirmacao) + ')',
    };
  }
  return { operacao, projectId, uid, commit };
}

/// O plano de mutação, a partir dos claims que o usuário JÁ tem.
///
/// Preserva tudo que não é `motorDePartidas`: `admin`, `suporte` e qualquer
/// coisa que outra frente tenha gravado. Substituir o mapa inteiro é o erro
/// clássico desta API — `setCustomUserClaims` SOBRESCREVE, não mescla, e um
/// grant desatento apagaria o `admin` de quem o tivesse.
function planejarMutacao(operacao, claimsAtuais) {
  const atuais = claimsAtuais && typeof claimsAtuais === 'object' ? claimsAtuais : {};
  const preservados = Object.keys(atuais).filter((k) => k !== CLAIM).sort();

  if (operacao === 'inspect') {
    return {
      acao: 'nenhuma',
      resultado: atuais[CLAIM] === true ? 'concedido' : 'ausente',
      claimsFinais: null,
      preservados,
    };
  }

  if (operacao === 'grant') {
    // `=== true` e não "existe": um claim que chegou como `"true"`, `1` ou
    // `false` — o que um provisionamento manual produz — NÃO autoriza nada, e
    // por isso precisa ser corrigido para o booleano, e não deixado como está.
    if (atuais[CLAIM] === true) {
      return { acao: 'nenhuma', resultado: 'ja_concedido', claimsFinais: null, preservados };
    }
    return {
      acao: 'escrever',
      resultado: 'concedido',
      claimsFinais: { ...atuais, [CLAIM]: true },
      preservados,
    };
  }

  // revoke — REMOVE a chave em vez de gravar `false`.
  //
  // As duas são igualmente seguras para a guarda (`=== true` recusa ambas), mas
  // remover não deixa lápide: um mapa que acumula `motorDePartidas: false`,
  // `pioneiro: false`, `beta: false` vira ruído em que ninguém mais enxerga o
  // que está de fato concedido.
  if (!Object.prototype.hasOwnProperty.call(atuais, CLAIM)) {
    return { acao: 'nenhuma', resultado: 'ja_revogado', claimsFinais: null, preservados };
  }
  const finais = { ...atuais };
  delete finais[CLAIM];
  return { acao: 'escrever', resultado: 'revogado', claimsFinais: finais, preservados };
}

/// Confere o que o servidor devolveu DEPOIS da escrita. Não confia no plano:
/// `setCustomUserClaims` pode ter sido aceito e mesmo assim o estado final ser
/// outro, se alguém escreveu no meio.
function verificarResultado(operacao, claimsDepois) {
  const atuais = claimsDepois && typeof claimsDepois === 'object' ? claimsDepois : {};
  const tem = atuais[CLAIM] === true;
  if (operacao === 'grant') {
    return tem ? { ok: true } : { ok: false, erro: 'após conceder, o claim não está presente como booleano true' };
  }
  return tem ? { ok: false, erro: 'após revogar, o claim continua autorizando' } : { ok: true };
}

// ---------------------------------------------------------------------------
// EXECUÇÃO
// ---------------------------------------------------------------------------

const USO = [
  'uso: node scripts/provisionar_claim_motor_partidas.js <inspect|grant|revoke> \\',
  '       --project <id> --uid <uid> [--commit --confirmar-projeto <id>]',
  '',
  'Sem --commit o script apenas ENSAIA: nada é escrito.',
].join('\n');

async function main(argv) {
  const args = analisarArgumentos(argv);
  if (args.erro) {
    console.error('ERRO: ' + args.erro);
    console.error('\n' + USO);
    return 1;
  }
  const { operacao, projectId, uid, commit } = args;

  const noEmulador = !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
  console.log('operação        : ' + operacao);
  console.log('projeto         : ' + projectId);
  console.log('uid             : ' + mascararUid(uid) + '  (mascarado)');
  console.log('ambiente        : ' + (noEmulador ? 'EMULADOR' : 'REAL — credencial administrativa'));
  console.log('modo            : ' + (commit ? 'GRAVAÇÃO (--commit)' : 'ENSAIO (nada será escrito)'));

  const admin = require('firebase-admin');
  if (admin.apps.length === 0) admin.initializeApp({ projectId });

  // O SDK resolve o projeto de várias fontes (env, credencial, metadata). Se o
  // que ele resolveu não é o que o operador pediu, parar: escrever no projeto
  // errado é exatamente o acidente que esta checagem existe para impedir.
  const resolvido = admin.app().options.projectId;
  if (resolvido && resolvido !== projectId) {
    console.error('\nERRO: o SDK resolveu o projeto "' + resolvido + '", e não "' + projectId + '".');
    console.error('Nada foi escrito. Verifique GOOGLE_APPLICATION_CREDENTIALS e as variáveis de ambiente.');
    return 1;
  }

  const auth = admin.auth();
  let usuario;
  try {
    usuario = await auth.getUser(uid);
  } catch (e) {
    console.error('\nERRO: não foi possível ler o usuário (' + (e.code || e.message) + ').');
    console.error('Nada foi escrito.');
    return 1;
  }

  const claimsAtuais = usuario.customClaims || {};
  const plano = planejarMutacao(operacao, claimsAtuais);

  // Só o NOME dos outros claims é impresso. O valor pertence a quem os
  // concedeu, e um log colado num chamado não precisa carregá-lo.
  console.log('\nclaims atuais   : ' + CLAIM + '=' + JSON.stringify(claimsAtuais[CLAIM]) +
    (plano.preservados.length ? ' · preservados: ' + plano.preservados.join(', ') : ' · nenhum outro'));

  if (operacao === 'inspect') {
    console.log('estado          : ' + plano.resultado);
    console.log('autoriza?       : ' + (claimsAtuais[CLAIM] === true ? 'SIM' : 'NÃO'));
    return 0;
  }

  if (plano.acao === 'nenhuma') {
    console.log('plano           : nada a fazer (' + plano.resultado + ')');
    console.log('\nIdempotente: repetir esta operação não muda nada.');
    return 0;
  }

  console.log('plano           : ' + plano.resultado + ' — gravaria ' + CLAIM + '=' +
    JSON.stringify(plano.claimsFinais[CLAIM] === undefined ? null : plano.claimsFinais[CLAIM]));
  console.log('preservaria     : ' + (plano.preservados.length ? plano.preservados.join(', ') : 'nenhum outro claim'));

  if (!commit) {
    console.log('\n--- ENSAIO: nada foi escrito. Repita com --commit --confirmar-projeto ' + projectId + ' ---');
    return 0;
  }

  await auth.setCustomUserClaims(uid, plano.claimsFinais);

  const depois = (await auth.getUser(uid)).customClaims || {};
  const v = verificarResultado(operacao, depois);
  if (!v.ok) {
    console.error('\nFALHA NA VERIFICAÇÃO: ' + v.erro);
    return 2;
  }

  console.log('\ngravado e verificado: ' + CLAIM + '=' + JSON.stringify(depois[CLAIM]));
  console.log('claims preservados  : ' +
    (Object.keys(depois).filter((k) => k !== CLAIM).sort().join(', ') || 'nenhum outro'));
  console.log('\nATENÇÃO: o claim só aparece em um ID TOKEN NOVO. Um token já emitido');
  console.log('não ganha nem perde o claim — quem chama precisa renovar antes de usar.');
  return 0;
}

module.exports = {
  CLAIM,
  OPERACOES,
  analisarArgumentos,
  planejarMutacao,
  verificarResultado,
  mascararUid,
};

if (require.main === module) {
  main(process.argv.slice(2))
    .then((codigo) => process.exit(codigo))
    .catch((e) => {
      console.error('FALHOU:', e.message);
      process.exit(1);
    });
}
