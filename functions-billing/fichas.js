/**
 * fichas.js — O BENEFICIO ECONOMICO DA ASSINATURA. Logica pura, sem Firestore.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * Ate aqui, assinatura concedia VIP e NADA de economico. O ramo `ehAssinatura`
 * de `validarCompraPlay` gravava `vip`, prazo e plano-base; o credito de fichas
 * existia num lugar so, e era o ramo de produto avulso. Um jogador que pagasse
 * R$ 19,90 recebia acesso e zero fichas — nem as 1.500 da ativacao. A politica
 * comercial aprovada prometia outra coisa.
 *
 * O QUE TORNA ISTO MAIS DIFICIL DO QUE UM `increment`
 *
 * A politica nao e "credite X na compra". Ela tem uma parcela na ativacao e
 * parcelas MENSAIS, e a Play nao emite evento mensal para os planos trimestral e
 * anual: a RTDN de renovacao chega a cada ciclo de COBRANCA — de 3 em 3 meses,
 * de 12 em 12. Nao existe notificacao para "mes 2 do plano anual". Entao a
 * entrega mensal nao pode ser reativa a evento; ela precisa ser uma conclusao do
 * RELOGIO sobre um prazo que a Google ja informou — a mesma natureza da varredura
 * de vencimento em `reconciliarEntitlements`.
 *
 * E conclusao de relogio roda de novo. Todo dia. Sobre o mesmo jogador. Por isso
 * o desenho inteiro gira em torno de uma unica pergunta: **esta parcela ja foi
 * paga?** A resposta nao pode vir de um contador (que perde corrida) nem de uma
 * data de "ultimo credito" (que perde parcela quando o job falha um dia). Ela vem
 * de um LIVRO-RAZAO com uma linha por parcela, cuja chave e deterministica:
 *
 *     fichasConcessoes/{purchaseTokenHash}_{indice}
 *
 * Criar essa linha e creditar o saldo sao a MESMA transacao — a disciplina que
 * `idempotencia.js` ja impunha a concessao da compra. Quem perder a corrida
 * encontra a linha escrita e nao credita de novo.
 *
 * O INDICE DO MES E A UNIDADE DE TUDO
 *
 * Indice 0 e a ativacao. Indice N e o N-esimo mes decorrido desde o inicio da
 * assinatura, contado em meses de CALENDARIO (a Play cobra por calendario, nao
 * por blocos de 30 dias). Uma assinatura que comecou em 31 de janeiro completa o
 * mes 1 em 28 de fevereiro, e nao em 3 de marco.
 *
 * Com o indice como unidade, a ativacao deixa de ser um caso especial: ela e o
 * indice 0, passa pelo mesmo livro-razao, e por isso a varredura agendada e
 * capaz de REPARAR um credito de ativacao que tenha falhado durante a validacao.
 * A validacao credita o indice 0 na hora para o jogador nao esperar; se ela
 * falhar, o agendador entrega. Nenhum dos dois consegue creditar duas vezes.
 *
 * A POLITICA E DADO, NAO CODIGO
 *
 * Nenhum valor de ficha aparece aqui. Os numeros vivem em `configuracao/billing`,
 * por plano-base, pela mesma razao que `definicao.fichas` ja vivia la: o servidor
 * e a autoridade sobre o que um produto vale, e mudar preco de beneficio nao pode
 * exigir deploy.
 */

'use strict';

/** Colecao do livro-razao. Uma linha por parcela concedida, para sempre. */
const COL_FICHAS = 'fichasConcessoes';

/**
 * Teto de parcelas liquidadas por jogador em UM tick do agendador.
 *
 * Existe para o caso patologico: um documento com `inicioEm` corrompido para
 * 1970 pediria centenas de transacoes e seguraria a varredura inteira. Vinte e
 * quatro cobre com folga qualquer atraso real (o plano mais longo tem 12
 * parcelas) e o que passar disso e entregue no tick seguinte — nunca perdido.
 * Quando o teto morde, quem chama REGISTRA: um corte silencioso se leria como
 * "estava tudo em dia".
 */
const TETO_PARCELAS_POR_TICK = 24;

/**
 * Soma meses de calendario a uma data, grudando no ultimo dia quando o mes de
 * destino e mais curto.
 *
 * `Date.UTC(ano, mes, 31)` para fevereiro NAO estoura erro: ele transborda para
 * marco. Sem o grude, uma assinatura iniciada dia 31 teria o mes 1 reconhecido
 * so em 3 de marco — o jogador esperaria tres dias a mais pela parcela dele.
 */
function somarMeses(base, n) {
  const ano = base.getUTCFullYear();
  const mes = base.getUTCMonth() + n;
  // Dia 0 do mes seguinte e o ultimo dia do mes alvo.
  const ultimoDia = new Date(Date.UTC(ano, mes + 1, 0)).getUTCDate();
  return new Date(
    Date.UTC(
      ano,
      mes,
      Math.min(base.getUTCDate(), ultimoDia),
      base.getUTCHours(),
      base.getUTCMinutes(),
      base.getUTCSeconds(),
      base.getUTCMilliseconds()
    )
  );
}

/**
 * Quantos meses de calendario COMPLETOS se passaram entre `inicioEm` e `agora`.
 *
 * @returns {number} 0 no dia da compra, 1 no primeiro mesversario, e assim por
 *   diante. `-1` quando nao da para afirmar nada: data ausente, data invalida ou
 *   `agora` anterior ao inicio. Um `-1` nao concede parcela nenhuma — a duvida
 *   recusa, que e a regra do codebase inteiro.
 */
function mesesDecorridos(inicioEm, agora) {
  if (!inicioEm || !agora) return -1;
  const inicio = new Date(inicioEm);
  const fim = new Date(agora);
  if (Number.isNaN(inicio.getTime()) || Number.isNaN(fim.getTime())) return -1;
  if (fim.getTime() < inicio.getTime()) return -1;

  let meses =
    (fim.getUTCFullYear() - inicio.getUTCFullYear()) * 12 +
    (fim.getUTCMonth() - inicio.getUTCMonth());
  // O calculo acima conta viradas de mes, nao mesversarios. Dia 1o de marco com
  // inicio em 20 de janeiro daria 2, e o mes 2 ainda nao venceu.
  if (fim.getTime() < somarMeses(inicio, meses).getTime()) meses -= 1;
  return meses < 0 ? -1 : meses;
}

/**
 * A configuracao do plano-base dentro da definicao do produto.
 *
 * Devolve `null` — e nao um objeto vazio — quando nao existe, para que quem
 * chama tenha que decidir o que fazer com a ausencia em vez de creditar zero
 * achando que creditou.
 */
function planoDoCatalogo(definicao, basePlanId) {
  if (!definicao || typeof definicao !== 'object') return null;
  if (typeof basePlanId !== 'string' || !basePlanId) return null;
  const planos = definicao.planos;
  if (!planos || typeof planos !== 'object') return null;
  const plano = planos[basePlanId];
  return plano && typeof plano === 'object' ? plano : null;
}

/**
 * Quantas fichas a parcela de indice `indice` vale neste plano.
 *
 * O indice 0 e a ativacao. Os demais valem `mensal`.
 *
 * `ativacaoPorCiclo` existe porque a definicao comercial e ambigua na RENOVACAO,
 * e a ambiguidade vale dinheiro: "2.700 na ativacao, 1.200 no 2o mes, 1.200 no
 * 3o" descreve UM ciclo trimestral e nao diz o que acontece no mes 4. Duas
 * leituras cabem — a renovacao repete o bonus de ativacao, ou o bonus e de
 * assinatura nova e so acontece uma vez.
 *
 * O padrao e `false` (bonus uma vez so) porque e a unica leitura COERENTE com o
 * plano mensal, que na mesma definicao recebe 1.500 na ativacao e 1.000 nos
 * meses seguintes: se renovacao fosse ativacao, o mensal receberia 1.500 todo
 * mes e a frase "1.000 nos meses seguintes" nao teria a quem se aplicar.
 *
 * Fica como campo de configuracao, e nao como constante, para que a outra
 * leitura seja uma decisao registrada em `configuracao/billing` — nao um deploy.
 */
function fichasDoIndice(plano, indice) {
  if (!plano || !Number.isInteger(indice) || indice < 0) return 0;

  const ativacao = Number(plano.ativacao);
  const mensal = Number(plano.mensal);
  const valor = (n) => (Number.isFinite(n) && n > 0 ? Math.floor(n) : 0);

  if (indice === 0) return valor(ativacao);

  if (plano.ativacaoPorCiclo === true) {
    const ciclo = Number(plano.mesesDoCiclo);
    if (Number.isInteger(ciclo) && ciclo > 0 && indice % ciclo === 0) {
      return valor(ativacao);
    }
  }
  return valor(mensal);
}

/**
 * Os indices de parcela que ja venceram, do mais antigo para o mais novo.
 *
 * Nao consulta livro-razao nenhum: devolve o que o CALENDARIO deve, e cabe a
 * quem chama descobrir, parcela a parcela, o que ja foi pago. Separar as duas
 * coisas e o que permite testar a conta do calendario sem banco.
 */
function indicesDevidos({ inicioEm, agora, teto = TETO_PARCELAS_POR_TICK }) {
  const decorridos = mesesDecorridos(inicioEm, agora);
  if (decorridos < 0) return { indices: [], truncado: false, decorridos };

  const total = decorridos + 1; // inclui o indice 0
  const limite = Math.min(total, teto);
  const indices = [];
  for (let i = 0; i < limite; i += 1) indices.push(i);
  return { indices, truncado: total > limite, decorridos };
}

/**
 * Chave deterministica da parcela no livro-razao.
 *
 * O hash do token identifica a ASSINATURA (a Play mantem o mesmo `purchaseToken`
 * atraves das renovacoes automaticas; uma reassinatura depois de expirar traz
 * token novo, e portanto um livro-razao novo — que e o comportamento certo: quem
 * reassina volta a ter direito ao bonus de ativacao).
 *
 * O `uid` NAO entra na chave, e isso e deliberado: o titular de um token e unico
 * e ja e conferido por `conferirTitularidade`. Se o uid entrasse, dois usuarios
 * disputando o mesmo token produziriam duas linhas e o credito sairia dobrado —
 * exatamente o que o livro-razao existe para impedir. Ele e GRAVADO no corpo,
 * para auditoria.
 */
function chaveConcessao(purchaseTokenHash, indice) {
  return `${purchaseTokenHash}_${indice}`;
}

module.exports = {
  COL_FICHAS,
  TETO_PARCELAS_POR_TICK,
  somarMeses,
  mesesDecorridos,
  planoDoCatalogo,
  fichasDoIndice,
  indicesDevidos,
  chaveConcessao,
};
