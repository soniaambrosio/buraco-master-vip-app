// ancora_provas_visuais_test.dart — a ÂNCORA EXTERNA das provas visuais da
// carta obrigatória do lixo.
//
// POR QUE ESTE ARQUIVO EXISTE.
//
// A OS 29-C4 pôs a guarda do desenho da carta obrigatória FORA do arquivo que
// ela guarda, e a OS 29-C5 deu à metade recíproca a mesma força que ela cobra.
// O par ficou simétrico e forte, e mesmo assim a própria C5 registrou o que
// sobra — o residual C10:
//
//   esvaziar as DUAS metades no mesmo commit e realinhar o digest que sobra
//   sai VERDE, com o placar da árvore íntegra (`cascaaud +28`, `mesac1 +31`).
//
// E não é defeito de nenhuma das duas: uma guarda MÚTUA de dois nós não tem
// âncora fora de si. Tudo o que um cobra do outro está escrito num dos dois, e
// um gesto que toca os dois ao mesmo tempo é, para o par, indistinguível de uma
// mudança legítima.
//
// Este arquivo é o terceiro nó. Ele NÃO pergunta nada aos dois arquivos sobre
// si mesmos: as listas de casos, as declarações exigidas, as agulhas, os pisos
// e os digests do CÓDIGO das duas metades estão declarados AQUI, em cópia
// própria. Realinhar os dois digests um no outro não o alcança, porque ele
// carrega um terceiro par de digests que o gesto coordenado não sabe que
// existe — e, se souber, já é um gesto de TRÊS arquivos, declarado em três
// lugares de naturezas diferentes.
//
// E ele não se contenta com a árvore. Cinco dos casos abaixo leem a EVIDÊNCIA
// do executor verdadeiro: o carimbo que o alvo oficial escreve antes de rodar,
// os marcadores de saída e os logs `--reporter expanded` das duas suítes. Um
// marcador fabricado sem log, um log anterior ao carimbo, um placar abaixo do
// piso ou um caso protegido que não aparece na chamada nominal reprovam aqui.
//
// FAIL-CLOSED, E DE PROPÓSITO. Os grupos irmãos deste diretório escrevem
// `if (!workflow.existsSync()) return;` — e está certo para eles, que nasceram
// para sobreviver a recortes antigos da árvore. Esta âncora não: ela existe
// para ser a coisa que não se pode desligar em silêncio. Se o alvo oficial não
// estiver alcançável a partir de onde ela roda, ela REPROVA, porque "não
// consegui olhar" e "olhei e está certo" não podem sair iguais.
//
// ONDE ELA É EXECUTADA. Nos dois portões, e de propósito:
//
//   * `.github/workflows/ci-os-integracao.yml`, pela chave `ancoravis`, que
//     entra por `exige` e está nas TRÊS listas do veredito — de modo que o
//     passo que não roda também reprova;
//   * `.github/workflows/build.yml`, que roda `flutter test test/casca
//     test/cartas` no diretório inteiro. Esse comando é afirmado, letra por
//     letra, por `auditoria_casca_test.dart`, que é um dos dois arquivos
//     protegidos e não pode ser tocado sem derrubar o par.
//
// É essa segunda porta que fecha o buraco de apagar a ENTRADA: quem tirar
// `ancoravis` das listas do alvo oficial continua rodando esta âncora pelo
// portão do APK, e ela reprova nominalmente por causa da entrada que sumiu.

@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// OS ENDEREÇOS
// ===========================================================================

/// A guarda externa do desenho da obrigação (o gate `cascaaud`).
const String kCaminhoDaGuarda = 'test/casca/auditoria_casca_test.dart';

/// A suíte protegida, que prova o desenho na mesa montada (o gate `mesac1`).
const String kCaminhoDaSuiteProtegida =
    'test/casca/mesa_treino_alvos_reais_test.dart';

/// Esta âncora, como os dois workflows a nomeiam.
const String kCaminhoDestaAncora = 'test/casca/ancora_provas_visuais_test.dart';

/// A chave do gate desta âncora no alvo oficial.
const String kChaveDoGate = 'ancoravis';

/// As chaves dos dois gates cujas provas esta âncora torna obrigatórias.
const String kChaveDaGuarda = 'cascaaud';
const String kChaveDaSuiteProtegida = 'mesac1';

/// O alvo oficial e o portão que produz o APK, a partir de `app/`.
const String kAlvoOficial = '../.github/workflows/ci-os-integracao.yml';
const String kPortaoDoApk = '../.github/workflows/build.yml';

/// O comando que o portão do APK roda, e que `auditoria_casca_test.dart`
/// afirma letra por letra. É a porta que sobrevive ao apagamento da entrada.
const String kComandoDoPortaoDoApk = 'flutter test test/casca test/cartas';

/// O contrato desta autoridade, a partir da raiz — o SEGUNDO dono do digest
/// desta âncora, e onde a campanha que cobra o residual C10 está registrada.
const String kCaminhoDoContrato =
    'docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md';

// ===========================================================================
// A EVIDÊNCIA DO EXECUTOR VERDADEIRO
// ===========================================================================
//
// O alvo oficial roda as suítes a partir de `app_build/`, e escreve carimbo,
// marcadores e logs na raiz do workspace — um nível acima. Esta bancada tem a
// mesma forma: `app/` embaixo, a raiz em cima.

/// O carimbo que o alvo oficial escreve ANTES de rodar as suítes.
const String kCarimbo = '../carimbo_ancoravis';

/// O marcador de saída e o log de cada uma das duas suítes protegidas.
const String kMarcadorDaGuarda = '../exit_cascaaud';
const String kLogDaGuarda = '../t_cascaaud.log';
const String kMarcadorDaSuiteProtegida = '../exit_mesac1';
const String kLogDaSuiteProtegida = '../t_mesac1.log';

/// A linha com que o `--reporter expanded` fecha uma execução inteira.
const String kFechoDoPlacar = 'All tests passed!';

/// As duas aspas triplas, escritas de um jeito que NÃO as escreve: aspas
/// adjacentes se juntam em tempo de compilação, e este arquivo continua sem
/// conter a agulha que ele procura no outro.
const String kAspaTriplaSimples = "'" "'" "'";
const String kAspaTriplaDupla = '"' '"' '"';

// ===========================================================================
// A PORTA POR QUE ESTA EXECUÇÃO VEIO (OS 29-C7)
// ===========================================================================
//
// A OS 29-R5 mediu o que a AUSÊNCIA de carimbo fazia aqui: os dois casos de
// evidência começavam com `if (!carimbo.existsSync()) return;`, e mover o
// produtor UMA linha adiante desligava a metade de evidência inteira sem nada
// ficar vermelho. Um ramo degradado que dispensa evidência é uma porta aberta
// com nome de conveniência.
//
// Não há mais ramo degradado. Cada uma das duas portas DECLARA que é ela quem
// está executando, e passa o carimbo desta corrida por AMBIENTE. Sem porta
// declarada esta âncora reprova; com porta declarada ela cobra a evidência que
// aquela porta produz — e o carimbo de arquivo tem de ser o mesmo que o shell
// acabou de gerar, o que um arquivo guardado de outra corrida não é.

/// O nome da variável de ambiente por onde a porta se declara.
const String kEnvPorta = 'BMV_PORTA_ANCORAVIS';

/// O nome da variável de ambiente que carrega o carimbo desta corrida.
const String kEnvCarimbo = 'BMV_CARIMBO_ANCORAVIS';

/// As duas portas, e só elas.
const String kPortaDoAlvoOficial = 'alvo-oficial';
const String kPortaDoApk = 'portao-apk';

/// O arquivo onde a porta que está executando escreve o próprio nome.
const String kArquivoDaPorta = '../porta_ancoravis';

/// As linhas vivas com que cada porta limpa a evidência anterior, declara-se e
/// gera o carimbo desta corrida. A ORDEM entre elas é contrato, e não estilo:
/// a OS 29-R5 mediu que mover o produtor do carimbo para depois das suítes
/// desliga a metade de evidência inteira sem nada ficar vermelho.
const String kLimpezaDoAlvoOficial =
    'rm -f carimbo_ancoravis porta_ancoravis t_cascaaud.log t_mesac1.log '
    't_ancoravis.log t_autancora.log exit_cascaaud exit_mesac1 '
    'exit_ancoravis exit_autancora nao_cascaaud nao_mesac1 nao_ancoravis '
    'nao_autancora';
const String kLimpezaDoPortaoDoApk =
    'rm -f t_apk_casca.log carimbo_ancoravis porta_ancoravis';
const String kDeclaraPortaDoAlvoOficial = 'BMV_PORTA_ANCORAVIS=alvo-oficial';
const String kDeclaraPortaDoApk = 'BMV_PORTA_ANCORAVIS=portao-apk';
const String kGeraCarimbo =
    r'BMV_CARIMBO_ANCORAVIS="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)-$$-${RANDOM}"';
const String kExportaCarimbo =
    'export BMV_PORTA_ANCORAVIS BMV_CARIMBO_ANCORAVIS';
const String kEscrevePorta =
    "printf '%s' " r'"$BMV_PORTA_ANCORAVIS" > porta_ancoravis';
const String kEscreveCarimbo =
    "printf '%s' " r'"$BMV_CARIMBO_ANCORAVIS" > carimbo_ancoravis';

/// Toda invocação de suíte no passo das suítes do alvo oficial.
final RegExp kInvocacaoDeSuite = RegExp(r'^(roda|exige) +[a-z0-9]+ +\S+$');

// ===========================================================================
// A AUTORIDADE EXTERNA DESTA ÂNCORA (OS 29-C7)
// ===========================================================================
//
// O RESIDUAL QUE ELA FECHA. Até a OS 29-C6, tudo o que decidia o que esta
// âncora É morava em três arquivos que um mesmo gesto já estava tocando: o
// digest e o piso no alvo oficial, o digest no contrato dela, e o conteúdo
// aqui. Esvaziar a âncora, recarimbar os dois donos e baixar `ANCORA_PISO`
// para 1 saía VERDE — foi o escape E3 da OS 29-R5.
//
// `autancora` é o QUARTO nó. Ele carrega cópia própria do caminho canônico
// desta âncora, do piso de casos, da relação NOMINAL dos casos e do digest do
// CÓDIGO dela, e nenhum desses valores é calculado a partir do alvo que ele
// verifica. E esta âncora o guarda de volta, com o mesmo rigor: as constantes
// abaixo são o que impede que remover, esvaziar ou recarimbar a autoridade
// externa passe em silêncio.
//
// O gesto que neutraliza os dois de uma vez precisa, agora, de CINCO arquivos
// de três naturezas: as duas suítes, o alvo oficial, e os dois contratos em
// prosa. O residual está declarado com esse tamanho, e não como proteção
// absoluta.

/// A autoridade externa, como os dois workflows a nomeiam.
const String kCaminhoDaAutoridade =
    'test/casca/autoridade_ancora_visual_test.dart';

/// A chave do gate da autoridade externa no alvo oficial.
const String kChaveDaAutoridade = 'autancora';

/// O contrato da autoridade externa, a partir da raiz.
const String kCaminhoDoContratoDaAutoridade =
    'docs/AUTORIDADE-EXTERNA-ANCORA-VISUAL-V1.md';

/// Quantos casos a autoridade externa tem.
const int kCasosDaAutoridade = 20;

/// Os casos da autoridade externa, na ordem em que ela os declara.
const List<String> kCasosDaAutoridadeExterna = <String>[
  'a âncora existe no caminho canônico, e não encolheu',
  'os casos da âncora são exatamente estes, na ordem contratada',
  'o código da âncora bate com o digest desta autoridade',
  'a âncora não usa aspa tripla, que cega qualquer varredor',
  'a âncora continua afirmando acima do piso, e não virou casca',
  'a âncora carrega as declarações sem as quais ela não confere nada',
  'o alvo oficial exige a âncora, viva, no passo que a executa',
  'a âncora está nas quatro listas do veredito do alvo oficial',
  'o portão do APK nomeia a âncora no laço vivo de obrigatórios',
  'o portão do APK executa as duas pastas numa linha viva',
  'o portão do APK consome o exit real e confere o placar contra o piso',
  'o alvo oficial exige esta autoridade e a torna obrigatória',
  'o portão do APK nomeia esta autoridade no laço vivo',
  'cada variável de decisão tem exatamente uma atribuição viva',
  'o vínculo de conteúdo da âncora tem dois donos, e eles concordam',
  'o carimbo nasce depois da limpeza e antes de toda suíte protegida',
  'a âncora roda depois das duas metades que ela lê',
  'a âncora guarda esta autoridade de volta, e pelo conteúdo',
  'os dois contratos estão na árvore e declaram as duas campanhas',
  'esta execução veio por uma das duas portas, com carimbo desta corrida',
];

/// O piso de afirmações NÃO TRIVIAIS da autoridade externa.
const int kPisoDeAfirmacoesDaAutoridade = 86;

/// O digest do CÓDIGO da autoridade externa — sem comentário, sem as linhas
/// marcadas `[digest-movel]`, sem espaço à direita e sem linha vazia.
///
/// A linha abaixo é móvel de propósito: ela não entra no digest deste arquivo,
/// e por isso os dois nós podem carregar o digest um do outro sem entrar em
/// recursão.
const String kDigestDoCodigoDaAutoridade =
    '9f338f225a555d11bbd73743beabdda1a2139cc603449b930b2f440efafcd027'; // [digest-movel]

// ===========================================================================
// OS PASSOS QUE DECIDEM, E O PISO DA SEGUNDA PORTA
// ===========================================================================
//
// Workflow não se lê como textão. Cada `run:` é um shell próprio: o mesmo
// comando escrito noutro passo não executa nada aqui, e uma linha dentro de um
// heredoc não executa em lugar nenhum. Daqui para baixo tudo é lido POR PASSO,
// e só o que sobra depois de tirar comentário e corpo de heredoc conta como
// comando vivo.

/// O passo do alvo oficial que roda as suítes protegidas e esta âncora.
const String kPassoDasSuites =
    '1+2 — analyze + suítes Flutter (captura exit codes sem abortar)';

/// O passo do alvo oficial que publica a evidência.
const String kPassoDaEvidencia = 'Publicar evidência na branch ci-evidencias';

/// O passo do alvo oficial que dá o veredito.
const String kPassoDoVeredito =
    'Portão verde/vermelho (gate que falhou, e gate OBRIGATÓRIO que não rodou)';

/// O passo do portão do APK que executa `test/casca` e `test/cartas`.
const String kPassoDoPortaoDoApk =
    'PORTÃO DE PRODUÇÃO — casca real (roteamento, mocks, dados pessoais)';

/// A linha VIVA que executa as duas pastas no portão do APK, letra por letra.
const String kComandoVivoDoPortaoDoApk =
    'flutter test test/casca test/cartas --reporter expanded 2>&1 | tee '
    '../t_apk_casca.log';

/// O piso de casos do portão do APK.
///
/// 343 é o placar da árvore da OS 29-C6. O acréscimo é EXCLUSIVAMENTE dos
/// casos novos desta OS: seis nesta âncora e vinte na autoridade externa.
const int kPisoDoPortaoDoApk = 369;

/// Os arquivos que o portão do APK nomeia um a um, e que apagar derruba o
/// laço de obrigatórios antes de derrubar a contagem do diretório.
const List<String> kObrigatoriosDoPortaoDoApk = <String>[
  'app/test/casca/mesa_treino_caracterizacao_test.dart',
  'app/test/casca/mesa_treino_acessivel_test.dart',
  'app/test/casca/mesa_treino_alvos_reais_test.dart',
  'app/test/casca/ancora_provas_visuais_test.dart',
  'app/test/casca/autoridade_ancora_visual_test.dart',
  'app/test/cartas/disposicao_da_mao_test.dart',
];

// ===========================================================================
// AS CAMPANHAS REGISTRADAS
// ===========================================================================
//
// A OS 29-R5 mediu o escape E5: a seção 7 do contrato caía de 2562 letras para
// `C6-01 a C6-20.` e saía VERDE, porque o caso que a vigiava pedia
// `contains('C6-01')` e `contains('C6-20')`. Duas cadeias de seis letras.
//
// Agora a campanha é lida como TABELA: os identificadores um a um, únicos, na
// ordem contratada, cada um com descrição material do vetor, com o resultado
// esperado e com quem acusa. Reduzir a seção aos dois rótulos extremos reprova
// por contagem; duplicar um ID para completar a contagem reprova por unicidade;
// trocar a ordem reprova pela ordem; esvaziar a descrição reprova pelo tamanho;
// transformar todos em controle reprova pela conta de vermelhos.

/// Quantos vetores a campanha da OS 29-C6 tem, e quantos são controle.
const int kVetoresDaC6 = 20;
const int kControlesDaC6 = 1;

/// Quantos vetores a campanha da OS 29-C7 tem, e quantos são controle.
const int kVetoresDaC7 = 32;
const int kControlesDaC7 = 1;

/// O tamanho mínimo da descrição de um vetor, em letras. Grosseiro de
/// propósito: não julga qualidade, só impede a descrição esvaziada.
const int kPisoDaDescricaoDoVetor = 20;

// ===========================================================================
// O QUE AS DUAS METADES SÃO — EM CÓPIA PRÓPRIA
// ===========================================================================

/// Os marcadores da metade que mora na guarda externa.
const String kInicioDaGuarda =
    '// >>> GUARDA EXTERNA DA SUITE DO DESENHO - INICIO';
const String kFimDaGuarda = '// <<< GUARDA EXTERNA DA SUITE DO DESENHO - FIM';

/// Os marcadores da metade recíproca, que mora na suíte protegida.
const String kInicioDaReciprocidade = '// >>> RECIPROCIDADE DA GUARDA - INICIO';
const String kFimDaReciprocidade = '// <<< RECIPROCIDADE DA GUARDA - FIM';

/// Os casos da metade que guarda, na ordem em que ela os declara.
const List<String> kCasosDaGuarda = <String>[
  'a suíte protegida está no caminho declarado e bate com o digest',
  'os casos da suíte protegida são exatamente estes',
  'cada trecho protegido continua AFIRMANDO o que promete',
  'a suíte exercita 320, 360 e 412 e protege o piso de 48',
  'a suíte protegida guarda esta auditoria de volta',
];

/// Os casos da suíte protegida, na ordem em que ela os declara.
///
/// Esta é a cópia da ÂNCORA. A guarda externa tem a dela, e a coincidência
/// entre as duas é o que um gesto de dois arquivos não consegue produzir.
const List<String> kCasosDaSuiteProtegida = <String>[
  'numa tela larga as onze cartas cabem numa fileira',
  'em 360 pontos a mão usa duas fileiras',
  'a mesa não estoura em nenhuma largura nomeada, nem no quadrado',
  'com a fonte do sistema em 200% o piso continua de pé',
  'o piso vale nas três larguras nomeadas: 320, 360 e 412',
  'vale em 400 pontos',
  'o toque em cada carta acerta a carta, e não a vizinha',
  'o piso exigido é 48, e o número é conferido e não só usado',
  'a leitura é 1…11, com as duas fileiras',
  'a leitura é a mesma em uma e em duas fileiras',
  'selecionar na fileira de cima não mexe na de baixo',
  'a reorganização da compra não quebra ordem nem piso',
  'é anunciada, e só numa carta',
  'acompanha a INSTÂNCIA, e não o valor e o naipe',
  'sobrevive à seleção, à desmarcação e ao rebuild',
  'sobrevive à mudança de fileira',
  'a compra comum do monte NÃO vira obrigação',
  'o destaque vermelho dura o que a obrigação durar',
  'sem obrigação viva, carta nenhuma fica com o destaque',
  'enquanto a pendência vive, nenhum descarte é aceito',
  'a baixada com o topo encerra a pendência antes de a vez virar',
  'cada um tem 48 × 48 de região acionável',
  'os discos continuam onde a mesa original os desenhou',
  'os cinco pontos de cada alvo respondem, e só ao dono',
  'os três alvos não se sobrepõem nem pegam o vizinho',
  'a mão desabilitada não oferece ação',
  'nó tocável nenhum fica sem nome',
  'o jogo baixado diz de quem é, quantas cartas e o que faz',
  'cada jogador é UM nó, e o avatar não vira o segundo',
  'os três atributos continuam escritos à mão',
  'a guarda externa desta suíte existe, e é ela que a protege',
];

/// Os casos das duas metades, que a chamada nominal do log tem de conter.
const List<String> kCasosDoDesenhoDaObrigacao = <String>[
  'é anunciada, e só numa carta',
  'acompanha a INSTÂNCIA, e não o valor e o naipe',
  'sobrevive à seleção, à desmarcação e ao rebuild',
  'sobrevive à mudança de fileira',
  'a compra comum do monte NÃO vira obrigação',
  'o destaque vermelho dura o que a obrigação durar',
  'sem obrigação viva, carta nenhuma fica com o destaque',
];

/// Sem estas declarações, a metade que guarda não confere coisa nenhuma —
/// ainda que conserve os cinco nomes de caso e os marcadores.
const List<String> kDeclaracoesDaGuarda = <String>[
  'const casosEsperados = <String>[',
  'const afirmacoes = <String, Map<String, int>>{',
  'const chamadas = <String, Map<String, int>>{',
  'const pisoDeAfirmacoes = <String, int>{',
  'const afirmacoesDaReciprocidade = <String, int>{',
  'const pisoDaReciprocidade = ',
  "const kTrechoDaReciprocidade = 'RECIPROCIDADE DA GUARDA';",
  'List<String> afirmacoesDe(String corpo)',
  'bool afirmacaoTrivial(String afirmacao)',
  'List<String> posicionais(String argumentos)',
  'List<String> argumentosDeExpect(String corpo)',
  'String semComentarios(String fonte)',
  'String semTextoDeString(String fonte)',
  'String trecho(String texto, String nome)',
  'String digestDe(String t)',
  'List<String> casosDe(String texto)',
  'orderedEquals(casosEsperados)',
];

/// O mesmo, do lado recíproco.
const List<String> kDeclaracoesDaReciprocidade = <String>[
  'final externa = File(kCaminhoDaGuardaExterna);',
  'blocoDaGuardaExterna(externa.readAsStringSync())',
  'orderedEquals(kCasosDaGuardaExterna)',
  'for (final d in kDeclaracoesDaGuardaExterna)',
  'naoTriviaisDaGuardaExterna(bloco)',
  'kAfirmacoesDaGuardaExterna.entries',
  'kPisoDaGuardaExterna',
  'kDigestDaGuardaExterna',
  'contains(kCaminhoDestaSuite)',
];

/// As declarações de topo da suíte protegida que sustentam a metade recíproca.
///
/// Elas moram FORA do bloco delimitado, e por isso precisam de conferência
/// própria: apagá-las não muda o digest do bloco.
const List<String> kDeclaracoesDeTopoDaSuiteProtegida = <String>[
  "const String kCaminhoDaGuardaExterna = 'test/casca/auditoria_casca_test.dart';",
  'const String kCaminhoDestaSuite =',
  'const String kDigestDaGuardaExterna = ',
  'const List<String> kCasosDaGuardaExterna = <String>[',
  'const List<String> kDeclaracoesDaGuardaExterna = <String>[',
  'const Map<String, int> kAfirmacoesDaGuardaExterna = <String, int>{',
  'const int kPisoDaGuardaExterna = ',
  'String blocoDaGuardaExterna(String texto) {',
  'String digestNormalizado(String trecho) =>',
];

/// O que a metade que guarda tem de continuar AFIRMANDO, dentro do PRIMEIRO
/// argumento posicional de um `expect`, e quantas vezes.
const Map<String, int> kAfirmacoesDaGuarda = <String, int>{
  'digestDe(texto)': 1,
  'linhas': 1,
  'casos': 2,
  'naoTriviais.length': 2,
  'quantas': 3,
  'guardaDoPiso': 1,
  'larguras': 1,
  'pisoDeAfirmacoes.containsKey(': 1,
  'afirmacoes.containsKey(': 1,
};

/// O mesmo, do lado recíproco.
const Map<String, int> kAfirmacoesDaReciprocidade = <String, int>{
  'externa.existsSync()': 1,
  'digestNormalizado(bloco)': 1,
  'casos': 2,
  'bloco': 3,
  'naoTriviais.length': 1,
  'quantas': 1,
};

/// Os pisos de afirmações NÃO TRIVIAIS de cada metade.
///
/// Grosseiros de propósito: não julgam qualidade, só impedem que a metade vire
/// casca depois que alguém realinhar os dois digests um no outro.
const int kPisoDaGuarda = 16;
const int kPisoDaReciprocidade = 8;

/// O digest do CÓDIGO de cada metade — sem comentário, sem a linha marcada
/// `[digest-movel]`, e sem espaço à direita.
///
/// É AQUI que o residual C10 morre. Os dois arquivos carregam o digest um do
/// outro, e um commit que esvazia os dois realinha os dois. Estes dois números
/// moram num terceiro arquivo, que o gesto coordenado não toca.
const String kDigestDoCodigoDaGuarda =
    '02135122f2f25894900c0347b37e2472752fb4f46afbc951a00e3d7c4b0d0aee';
const String kDigestDoCodigoDaReciprocidade =
    '3ddec94a74fed5cc9b29b220d52c9b619949dde6db217a16d37073370b11607b';

/// O placar mínimo de cada suíte protegida no log do executor verdadeiro.
const int kPisoDoPlacarDaGuarda = 28;
const int kPisoDoPlacarDaSuiteProtegida = 31;

/// Quantos casos esta âncora tem.
///
/// O alvo oficial declara o mesmo número em `ANCORA_PISO` e confere o placar
/// REAL desta suíte contra ele. Baixar o piso lá reprova aqui; esvaziar esta
/// âncora derruba o placar lá. Nenhum dos dois gestos se basta.
const int kCasosDestaAncora = 22;

// ===========================================================================
// OS VARREDORES
// ===========================================================================
//
// São os mesmos das duas metades, e estão duplicados de propósito. Importar os
// de lá faria a conferência depender do conferido: quem trivializasse as duas
// metades trivializaria junto o instrumento que as mede. A independência é o
// que faz o terceiro nó ser um terceiro nó.

/// Verdadeiro se a aspa em [k] abre uma string CRUA (`r'...'`).
///
/// `r'\'` é uma string crua de UM caractere. Um varredor que trate a barra como
/// escape consome a aspa de fechamento, perde o sincronismo e passa a ler o
/// resto do arquivo como texto — e daí em diante não enxerga `expect` nenhum.
bool aspaCrua(String fonte, int k) =>
    k > 0 &&
    fonte[k - 1] == 'r' &&
    (k == 1 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(fonte[k - 2]));

/// O texto sem comentário, respeitando aspas.
String semComentarios(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  var crua = false;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\' && !crua) {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(fonte, i);
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// O mesmo texto com o CONTEÚDO das strings esvaziado, aspas preservadas.
///
/// Escrever `temBordaDaObrigacao(` dentro de uma string é citar o nome, não
/// afirmar com ele.
String semTextoDeString(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  var crua = false;
  while (i < fonte.length) {
    final c = fonte[i];
    if (aspa != null) {
      if (c == r'\' && !crua) {
        i += 2;
        continue;
      }
      if (c == aspa) {
        aspa = null;
        saida.write(c);
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(fonte, i);
      saida.write(c);
      i++;
      continue;
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// Os argumentos de cada `expect(...)`, com parênteses balanceados e aspas
/// respeitadas.
List<String> argumentosDeExpect(String corpo) {
  const chamada = 'expect(';
  final colado = RegExp(r'[A-Za-z0-9_$.]');
  final saida = <String>[];
  var i = 0;
  while (true) {
    final k = corpo.indexOf(chamada, i);
    if (k < 0) break;
    if (k > 0 && colado.hasMatch(corpo[k - 1])) {
      i = k + chamada.length;
      continue;
    }
    var p = k + chamada.length;
    var nivel = 1;
    String? aspa;
    var crua = false;
    while (p < corpo.length && nivel > 0) {
      final c = corpo[p];
      if (aspa != null) {
        if (c == r'\' && !crua) {
          p += 2;
          continue;
        }
        if (c == aspa) aspa = null;
      } else if (c == "'" || c == '"') {
        aspa = c;
        crua = aspaCrua(corpo, p);
      } else if (c == '(') {
        nivel++;
      } else if (c == ')') {
        nivel--;
      }
      p++;
    }
    saida.add(corpo.substring(k + chamada.length, p - 1));
    i = p;
  }
  return saida;
}

/// Os argumentos POSICIONAIS de um `expect`, separados na vírgula de nível
/// zero. Tudo a partir do primeiro nomeado fica de fora — `reason:` é prosa de
/// reprovação, e citar a agulha nela não é afirmar com ela.
List<String> posicionais(String argumentos) {
  final saida = <String>[];
  var inicio = 0;
  var nivel = 0;
  String? aspa;
  var crua = false;
  for (var p = 0; p < argumentos.length; p++) {
    final c = argumentos[p];
    if (aspa != null) {
      if (c == r'\' && !crua) {
        p++;
        continue;
      }
      if (c == aspa) aspa = null;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      crua = aspaCrua(argumentos, p);
      continue;
    }
    if (c == '(' || c == '[' || c == '{') nivel++;
    if (c == ')' || c == ']' || c == '}') nivel--;
    if (c == ',' && nivel == 0) {
      saida.add(argumentos.substring(inicio, p));
      inicio = p + 1;
    }
  }
  saida.add(argumentos.substring(inicio));
  final nomeado = RegExp(r'^\s*[A-Za-z_][A-Za-z0-9_]*\s*:');
  final fim = saida.indexWhere(nomeado.hasMatch);
  return fim < 0 ? saida : saida.sublist(0, fim);
}

/// Verdadeiro se a afirmação não olha para programa nenhum: literal, string,
/// vazio, ou uma tautologia que passa em qualquer árvore.
bool afirmacaoTrivial(String afirmacao) {
  final a = afirmacao.trim();
  if (a.isEmpty) return true;
  if (RegExp(r"^'[^']*'$").hasMatch(a)) return true;
  if (RegExp(r'^"[^"]*"$').hasMatch(a)) return true;
  if (RegExp(r'^-?[0-9]+(\.[0-9]+)?$').hasMatch(a)) return true;
  if (a == 'true' || a == 'false' || a == 'null') return true;
  if (RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*!\1$').hasMatch(a)) {
    return true;
  }
  if (RegExp(r'^!([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*\1$').hasMatch(a)) {
    return true;
  }
  return false;
}

/// O PRIMEIRO argumento posicional de cada `expect` do trecho, já sem
/// comentário e com o conteúdo das strings esvaziado.
List<String> afirmacoesDe(String corpo) => argumentosDeExpect(
      semTextoDeString(semComentarios(corpo)),
    ).map((a) => posicionais(a).isEmpty ? '' : posicionais(a).first).toList();

/// As afirmações do trecho que olham para o programa.
List<String> naoTriviaisDe(String corpo) =>
    afirmacoesDe(corpo).where((x) => !afirmacaoTrivial(x)).toList();

/// Os nomes dos casos declarados no texto, na ordem.
List<String> casosDe(String texto) => RegExp(
      "^\\s*(?:testWidgets|test)\\(\\s*'((?:[^'\\\\]|\\\\.)*)'",
      multiLine: true,
    )
        .allMatches(semLinhaDeComentario(texto))
        .map((m) => m.group(1)!)
        .toList();

/// O texto sem as linhas que COMEÇAM com `//`.
String semLinhaDeComentario(String texto) => <String>[
      for (final l in normalizado(texto).split('\n'))
        if (!l.trimLeft().startsWith('//')) l,
    ].join('\n');

/// O mesmo texto com fim de linha de máquina normalizado.
///
/// Esta árvore é versionada com `autocrlf`: o MESMO arquivo tem CRLF na máquina
/// e LF no CI. Um digest cru diria que ele mudou toda vez que viaja.
String normalizado(String t) =>
    t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// O digest de um trecho, normalizado.
String digestDe(String t) =>
    sha256.convert(utf8.encode(normalizado(t))).toString();

// ===========================================================================
// LER OS ARQUIVOS
// ===========================================================================

/// O conteúdo de [caminho], ou uma reprovação nominal se ele não estiver lá.
String leitura(String caminho, String porque) {
  final f = File(caminho);
  expect(
    f.existsSync(),
    isTrue,
    reason: 'ausente: $caminho — $porque. Esta âncora é fail-closed: não '
        'conseguir olhar e olhar e estar certo não podem sair iguais',
  );
  return normalizado(f.readAsStringSync());
}

/// O CÓDIGO de um bloco delimitado: as linhas entre os marcadores, sem
/// comentário, sem a linha móvel do digest, sem espaço à direita.
String codigoDoBloco(String texto, String inicio, String fim, String onde) {
  final linhas = normalizado(texto).split('\n');
  final a = linhas.indexWhere((l) => l.trim() == inicio);
  final b = linhas.indexWhere((l) => l.trim() == fim);
  expect(
    a,
    greaterThanOrEqualTo(0),
    reason: 'o marcador de início de "$onde" sumiu — sem ele o bloco não tem '
        'fronteira, e o que se mede deixa de ser o que se declara',
  );
  expect(
    b,
    greaterThan(a),
    reason: 'o marcador de fim de "$onde" sumiu ou trocou de lugar com o de '
        'início',
  );
  return <String>[
    for (final l in linhas.sublist(a + 1, b))
      if (!l.trimLeft().startsWith('//') && !l.contains('[digest-movel]'))
        l.trimRight(),
  ].join('\n');
}

/// Toda declaração de shell `NOME="a b c"` do workflow, quebrada em chaves.
List<List<String>> declaracoesDe(String texto, String nome) =>
    RegExp('^ *' + nome + '="([^"]*)"', multiLine: true)
        .allMatches(texto)
        .map((m) => m
            .group(1)!
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList())
        .toList();

/// O valor de uma atribuição de shell SEM aspas, `NOME=valor`, VIVA — a linha
/// não pode começar por `#`.
String? atribuicaoViva(String texto, String nome) {
  final m = RegExp('^ *' + nome + r'=([^\s#]+)[ \t]*$', multiLine: true)
      .firstMatch(texto);
  return m?.group(1);
}

/// Verdadeiro se o workflow tem a linha [linha] VIVA — sem `#` na frente.
bool linhaViva(String texto, String linha) => RegExp(
      '^ *' + RegExp.escape(linha) + r'[ \t]*$',
      multiLine: true,
    ).hasMatch(texto);

/// O placar com que o `--reporter expanded` fechou o log: o `+N` da linha de
/// fecho. Devolve `-1` se o log não fechou verde.
int placarDo(String log) {
  final m = RegExp(r'\+([0-9]+):[^\n]*' + RegExp.escape(kFechoDoPlacar))
      .allMatches(log)
      .toList();
  if (m.isEmpty) return -1;
  return int.parse(m.last.group(1)!);
}

// ===========================================================================
// LER O WORKFLOW COMO PASSOS, E NÃO COMO TEXTÃO (OS 29-C7)
// ===========================================================================
//
// `^ *comando$` no arquivo inteiro confunde três coisas diferentes: comando
// que roda, linha dentro de um heredoc (que não roda em lugar nenhum) e
// comando idêntico escrito noutro passo (que roda em OUTRO shell, e portanto
// não substitui este). E `contains` não distingue comando de comentário, que
// foi exatamente o escape E2 da OS 29-R5: um `#` na frente do
// `flutter test test/casca test/cartas` deixava o portão do APK executar ZERO
// teste e sair verde, com o literal de pé para quem procurasse por substring.

/// Um passo do workflow: o nome declarado, o corpo cru e os comandos VIVOS.
class Passo {
  const Passo(this.nome, this.cru, this.comandos);

  /// O que o `- name:` declara, sem as aspas.
  final String nome;

  /// As linhas do passo inteiro, como estão no arquivo.
  final List<String> cru;

  /// O `run:` reduzido ao que o shell executa: sem linha em branco, sem
  /// comentário, sem corpo de heredoc, com as continuações de `\` juntadas.
  final List<String> comandos;
}

/// O corpo do bloco `run: |` de um passo, ainda com o recuo do arquivo.
List<String> corpoDoRun(List<String> cru) {
  final chave = RegExp(r'^(\s*)run:\s*\|-?\s*$');
  for (var k = 0; k < cru.length; k++) {
    final m = chave.firstMatch(cru[k]);
    if (m == null) continue;
    final recuo = m.group(1)!.length;
    final saida = <String>[];
    for (var j = k + 1; j < cru.length; j++) {
      final l = cru[j];
      if (l.trim().isEmpty) {
        saida.add('');
        continue;
      }
      if (l.length - l.trimLeft().length <= recuo) break;
      saida.add(l);
    }
    return saida;
  }
  return const <String>[];
}

/// O que o shell de um passo realmente executa.
List<String> comandosVivos(List<String> linhas) {
  final saida = <String>[];
  final abreHeredoc = RegExp('<<-?[ ]*[\'"]?([A-Za-z_][A-Za-z0-9_]*)[\'"]?');
  String? heredoc;
  var acumulado = '';
  for (final bruta in linhas) {
    final t = bruta.trim();
    if (heredoc != null) {
      if (t == heredoc) heredoc = null;
      continue;
    }
    if (t.isEmpty) continue;
    if (acumulado.isEmpty && t.startsWith('#')) continue;
    if (t.endsWith(r'\')) {
      final pedaco = t.substring(0, t.length - 1).trim();
      acumulado = acumulado.isEmpty ? pedaco : '$acumulado $pedaco';
      continue;
    }
    final comando = acumulado.isEmpty ? t : '$acumulado $t';
    acumulado = '';
    saida.add(comando);
    final h = abreHeredoc.firstMatch(comando);
    if (h != null) heredoc = h.group(1);
  }
  if (acumulado.isNotEmpty) saida.add(acumulado);
  return saida;
}

/// Todos os passos de um workflow.
List<Passo> passosDe(String yaml) {
  final linhas = normalizado(yaml).split('\n');
  final abre = RegExp(r'^(\s*)-\s+name:\s*(.*?)\s*$');
  final passos = <Passo>[];
  var i = 0;
  while (i < linhas.length) {
    final m = abre.firstMatch(linhas[i]);
    if (m == null) {
      i++;
      continue;
    }
    final recuo = m.group(1)!.length;
    var nome = m.group(2)!;
    if (nome.length >= 2 &&
        ((nome.startsWith('"') && nome.endsWith('"')) ||
            (nome.startsWith("'") && nome.endsWith("'")))) {
      nome = nome.substring(1, nome.length - 1);
    }
    final cru = <String>[linhas[i]];
    var j = i + 1;
    while (j < linhas.length) {
      final l = linhas[j];
      if (l.trim().isNotEmpty && l.length - l.trimLeft().length <= recuo) break;
      cru.add(l);
      j++;
    }
    passos.add(Passo(nome, cru, comandosVivos(corpoDoRun(cru))));
    i = j;
  }
  return passos;
}

/// O passo de [nome], ou uma reprovação nominal se ele sumiu ou foi renomeado.
Passo passo(String yaml, String nome, String onde) {
  final achados = passosDe(yaml).where((p) => p.nome == nome).toList();
  expect(
    achados,
    hasLength(1),
    reason: 'o passo "$nome" de $onde aparece ${achados.length} vezes. Um '
        'passo removido, renomeado ou duplicado muda o que executa sem mudar '
        'uma letra do que está escrito',
  );
  return achados.single;
}

/// O índice do primeiro comando vivo do passo que casa com [padrao], ou -1.
int indiceDe(Passo p, RegExp padrao) =>
    p.comandos.indexWhere(padrao.hasMatch);

/// Quantos comandos vivos do passo casam com [padrao].
int vezesNoPasso(Passo p, RegExp padrao) =>
    p.comandos.where(padrao.hasMatch).length;

/// O padrão de uma linha inteira, literal.
RegExp literal(String linha) => RegExp('^' + RegExp.escape(linha) + r'$');

/// Os valores de toda atribuição VIVA de [nome] no passo — incluindo as
/// escritas com `export`, que também governam o shell.
///
/// A OS 29-R5 mediu o escape E4 nesta exata dobra: o leitor pegava a PRIMEIRA
/// atribuição e o shell obedecia à ÚLTIMA, então bastava inserir
/// `ANCORA_PISO=1` depois da legítima para a âncora ler 16 e o portão usar 1.
/// Por isso aqui não se pega uma: contam-se todas, e exige-se exatamente uma.
List<String> atribuicoesVivas(Passo p, String nome) {
  final padrao = RegExp('^(?:export +)?' + RegExp.escape(nome) + r'=(.*)$');
  return <String>[
    for (final c in p.comandos)
      if (padrao.hasMatch(c)) padrao.firstMatch(c)!.group(1)!,
  ];
}

/// O valor da ÚNICA atribuição viva de [nome] no passo — que é o valor que o
/// shell obedece, porque não há outra.
String atribuicaoUnica(Passo p, String nome, String onde) {
  final vivas = atribuicoesVivas(p, nome);
  expect(
    vivas,
    hasLength(1),
    reason: 'o passo "${p.nome}" de $onde tem ${vivas.length} atribuições '
        'vivas de $nome (${vivas.join(" | ")}). O shell obedece à ÚLTIMA: uma '
        'segunda atribuição, antes ou depois da legítima, faz a guarda e a '
        'execução falarem de valores diferentes',
  );
  return vivas.single;
}

/// Verdadeiro se [valor] é um literal fechado: nada de expansão, de
/// substituição de comando, de aspa ou de espaço.
bool valorLiteral(String valor) =>
    RegExp(r'^[A-Za-z0-9._/:+-]+$').hasMatch(valor);

/// O CÓDIGO de um arquivo inteiro: sem as linhas móveis, sem comentário, sem
/// linha vazia e sem espaço à direita.
///
/// As linhas marcadas `[digest-movel]` saem ANTES de o comentário ser tirado —
/// senão a marca, que mora no comentário, sumiria junto e a linha voltaria a
/// contar.
String codigoDe(String texto) {
  final semMovel = <String>[
    for (final l in normalizado(texto).split('\n'))
      if (!l.trimRight().endsWith('// [digest-movel]')) l,
  ].join('\n');
  return <String>[
    for (final l in semComentarios(semMovel).split('\n'))
      if (l.trim().isNotEmpty) l.trimRight(),
  ].join('\n');
}

// ===========================================================================
// A PORTA DESTA EXECUÇÃO
// ===========================================================================

/// A porta por que esta execução veio, conferida contra o carimbo desta
/// corrida.
///
/// NÃO existe ramo "sem porta". Sem porta declarada esta função reprova, e é
/// isso que separa "não consegui olhar" de "olhei e está certo". O carimbo
/// viaja por ambiente e por arquivo, e os dois têm de dizer o mesmo: um
/// `carimbo_ancoravis` guardado de outra corrida e reapresentado não casa com
/// o valor que o shell da porta acabou de gerar.
String portaDestaExecucao() {
  final porta = Platform.environment[kEnvPorta] ?? '';
  expect(
    <String>[kPortaDoAlvoOficial, kPortaDoApk],
    contains(porta),
    reason: 'esta suíte foi executada sem porta declarada em $kEnvPorta '
        '(veio "$porta"). Ela é fail-closed de propósito: as duas portas '
        'oficiais — o passo "$kPassoDasSuites" do alvo oficial e o passo '
        '"$kPassoDoPortaoDoApk" do portão do APK — declaram a porta e o '
        'carimbo antes de executar, e uma execução que não veio por nenhuma '
        'delas não tem evidência para apresentar',
  );
  final naEnv = Platform.environment[kEnvCarimbo] ?? '';
  expect(
    naEnv.isNotEmpty,
    isTrue,
    reason: 'a porta $porta não passou o carimbo desta corrida em '
        '$kEnvCarimbo. Sem ele, um arquivo de carimbo guardado de outra '
        'execução passa por evidência desta',
  );
  final noDisco = File(kCarimbo);
  expect(
    noDisco.existsSync(),
    isTrue,
    reason: 'a porta $porta declarou o carimbo $naEnv e não escreveu '
        '$kCarimbo',
  );
  expect(
    noDisco.readAsStringSync().trim(),
    naEnv,
    reason: 'o carimbo em disco é "${noDisco.readAsStringSync().trim()}" e o '
        'desta corrida é "$naEnv": a evidência apresentada é de outra '
        'execução',
  );
  final arquivoDaPorta = File(kArquivoDaPorta);
  expect(
    arquivoDaPorta.existsSync(),
    isTrue,
    reason: 'a porta $porta não escreveu $kArquivoDaPorta',
  );
  expect(
    arquivoDaPorta.readAsStringSync().trim(),
    porta,
    reason: 'o ambiente diz que a porta é $porta e o disco diz '
        '"${arquivoDaPorta.readAsStringSync().trim()}"',
  );
  return porta;
}

// ===========================================================================
// LER A CAMPANHA REGISTRADA COMO TABELA
// ===========================================================================

/// Uma linha da tabela de campanha de um contrato.
class Vetor {
  const Vetor(this.id, this.gesto, this.acusador, this.resultado);
  final String id;
  final String gesto;
  final String acusador;
  final String resultado;
}

/// Os vetores declarados na tabela de [markdown] cujo identificador começa por
/// [prefixo]. Só linha de TABELA conta: um identificador escrito na prosa, num
/// comentário ou num texto-isca não é um vetor declarado.
List<Vetor> campanhaDe(String markdown, String prefixo) {
  final saida = <Vetor>[];
  for (final l in normalizado(markdown).split('\n')) {
    final t = l.trim();
    if (!t.startsWith('| $prefixo')) continue;
    final col = t.split('|').map((c) => c.trim()).toList();
    if (col.length < 6) continue;
    saida.add(Vetor(col[1], col[2], col[3], col[4]));
  }
  return saida;
}

/// Confere uma campanha inteira: identidade, unicidade, ordem, descrição
/// material, acusador, resultado esperado e a conta de vermelhos e controles.
void conferirCampanha(
  String markdown,
  String prefixo,
  int quantos,
  int controles,
  String onde,
) {
  final vetores = campanhaDe(markdown, prefixo);
  final esperados = <String>[
    for (var i = 1; i <= quantos; i++)
      '$prefixo-${i.toString().padLeft(2, '0')}',
  ];
  expect(
    vetores.map((v) => v.id).toList(),
    orderedEquals(esperados),
    reason: 'a campanha $prefixo de $onde declara '
        '${vetores.map((v) => v.id).join(", ")}, e o contrato são os '
        '$quantos identificadores de $prefixo-01 a ${esperados.last}, na '
        'ordem, cada um uma vez. Reduzir a seção aos rótulos extremos, '
        'duplicar um ID para completar a conta, retirar um intermediário ou '
        'trocar a ordem reprovam todos aqui',
  );
  for (final v in vetores) {
    expect(
      v.gesto.length,
      greaterThanOrEqualTo(kPisoDaDescricaoDoVetor),
      reason: 'o vetor ${v.id} de $onde ficou com a descrição "${v.gesto}": '
          'uma campanha sem descrição material do gesto não é reproduzível, e '
          'é a descrição que diz o que foi medido',
    );
    expect(
      v.acusador.length,
      greaterThanOrEqualTo(5),
      reason: 'o vetor ${v.id} de $onde não diz quem o acusa',
    );
    expect(
      <String>['VERMELHO', 'VERDE'],
      contains(v.resultado),
      reason: 'o vetor ${v.id} de $onde declara o resultado esperado '
          '"${v.resultado}", e só VERMELHO e VERDE são resultados',
    );
  }
  final verdes = vetores.where((v) => v.resultado == 'VERDE').length;
  expect(
    verdes,
    controles,
    reason: 'a campanha $prefixo de $onde tem $verdes controles verdes, e o '
        'contrato são $controles. Converter sabotagem em controle é esvaziar '
        'a campanha sem tirar uma linha dela',
  );
  expect(
    vetores.length - verdes,
    quantos - controles,
    reason: 'a campanha $prefixo de $onde tem ${vetores.length - verdes} '
        'sabotagens vermelhas, e o contrato são ${quantos - controles}',
  );
  expect(
    vetores.last.resultado,
    'VERDE',
    reason: 'o último vetor da campanha $prefixo de $onde é o CONTROLE, e ele '
        'tem de ser explicitamente verde: uma campanha sem controle não prova '
        'que o instrumento distingue árvore íntegra de árvore sabotada',
  );
}

void main() {
  // =========================================================================
  // 1 — OS DOIS ARQUIVOS PROTEGIDOS
  // =========================================================================

  test('os dois arquivos protegidos estão no caminho declarado', () {
    for (final c in <String>[kCaminhoDaGuarda, kCaminhoDaSuiteProtegida]) {
      expect(
        File(c).existsSync(),
        isTrue,
        reason: 'o arquivo protegido $c sumiu da árvore — e some em silêncio '
            'no alvo oficial, porque ausência de arquivo vira NÃO EXECUTADO',
      );
    }
    // Um digest bate com um arquivo vazio tão bem quanto com o certo. O tamanho
    // é a segunda pergunta, e ela não depende de digest nenhum.
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda o desenho');
    final protegida =
        leitura(kCaminhoDaSuiteProtegida, 'é a suíte do desenho na mesa');
    expect(
      guarda.split('\n').length,
      greaterThan(1000),
      reason: 'a guarda externa encolheu para ${guarda.split('\n').length} '
          'linhas',
    );
    expect(
      protegida.split('\n').length,
      greaterThan(2000),
      reason: 'a suíte protegida encolheu para '
          '${protegida.split('\n').length} linhas',
    );
  });

  // =========================================================================
  // 2 — O ALVO OFICIAL EXECUTA AS DUAS
  // =========================================================================

  test('o alvo oficial executa as duas suítes protegidas, pelo caminho certo',
      () {
    final texto = leitura(
      kAlvoOficial,
      'é a autoridade canônica de gates, e sem ela nada aqui é obrigatório',
    );
    expect(
      linhaViva(texto, 'roda $kChaveDaGuarda   $kCaminhoDaGuarda'),
      isTrue,
      reason: 'o gate $kChaveDaGuarda deixou de executar $kCaminhoDaGuarda — '
          'foi apontado para outro caminho, comentado, ou saiu do alvo',
    );
    expect(
      RegExp(
        '^ *exige +' +
            kChaveDaSuiteProtegida +
            ' +' +
            RegExp.escape(kCaminhoDaSuiteProtegida) +
            r'[ \t]*$',
        multiLine: true,
      ).hasMatch(texto),
      isTrue,
      reason: 'o gate $kChaveDaSuiteProtegida não exige '
          '$kCaminhoDaSuiteProtegida — foi rebaixado para roda, desviado para '
          'uma isca, ou saiu do alvo',
    );
    // Executar sem estar nas listas é rodar sem poder reprovar.
    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(
      RegExp(r'for +k +in +\$LISTA *; *do').hasMatch(texto),
      isTrue,
      reason: 'o veredito deixou de percorrer a variável LISTA',
    );
    for (final k in <String>[kChaveDaGuarda, kChaveDaSuiteProtegida]) {
      expect(gates.single, contains(k),
          reason: '$k saiu da evidência publicada');
      expect(lista.single, contains(k),
          reason: '$k saiu da lista que o veredito percorre');
    }
  });

  test('o portão do APK roda o diretório inteiro e nomeia os três caminhos',
      () {
    final texto = leitura(
      kPortaoDoApk,
      'é a segunda porta desta âncora, e a única que sobrevive ao apagamento '
          'da entrada no alvo oficial',
    );
    final p = passo(texto, kPassoDoPortaoDoApk, 'o portão do APK');

    // A LINHA TEM DE ESTAR VIVA, E NÃO APENAS ESCRITA.
    //
    // A OS 29-C6 cobrava este comando por `contains`, e a OS 29-R5 mediu o que
    // isso vale: um `#` na frente da linha derrubava o portão inteiro — os 343
    // casos de `test/casca` e `test/cartas` — com o literal de pé e o passo
    // saindo VERDE, com uma linha de saída e zero teste executado.
    expect(
      vezesNoPasso(p, literal(kComandoVivoDoPortaoDoApk)),
      1,
      reason: 'o passo "$kPassoDoPortaoDoApk" não executa exatamente uma vez '
          'a linha viva `$kComandoVivoDoPortaoDoApk`. Comentada, trocada por '
          'um `echo`, envolvida em `if false`, seguida de `|| true`, '
          'estreitada para um diretório só ou escrita dentro de um heredoc, '
          'ela continua CONTIDA no arquivo e não executa nada',
    );
    for (final proibido in <String>['|| true', 'if false', 'continue-on-error']) {
      expect(
        p.comandos.where((c) => c.contains(proibido)).toList(),
        isEmpty,
        reason: 'o passo "$kPassoDoPortaoDoApk" ganhou `$proibido`, que é como '
            'se escreve "reprove à vontade, eu saio verde"',
      );
    }
    expect(
      p.cru.where((l) => l.contains('continue-on-error')).toList(),
      isEmpty,
      reason: 'o passo "$kPassoDoPortaoDoApk" ganhou continue-on-error',
    );

    // OS ARQUIVOS NOMEADOS UM A UM, DENTRO DO LAÇO VIVO.
    final laco =
        p.comandos.where((c) => c.startsWith('for obrigatoria in ')).toList();
    expect(
      laco,
      hasLength(1),
      reason: 'o portão do APK tem ${laco.length} laços de arquivos '
          'obrigatórios. É por esse laço que apagar um arquivo dói antes de a '
          'contagem do diretório cair',
    );
    for (final c in kObrigatoriosDoPortaoDoApk) {
      expect(
        laco.single,
        contains(c),
        reason: 'o portão do APK não nomeia $c no laço VIVO de obrigatórios — '
            'apagá-lo derrubaria a contagem do diretório e, sem o piso, '
            'deixaria o portão verde',
      );
    }
    // A METADE QUE GUARDA NÃO ENTRA NO LAÇO, E É DE PROPÓSITO.
    //
    // `auditoria_casca_test.dart` tem guarda PRÓPRIA e anterior, escrita à
    // mão logo acima do laço, e é ela que o portão do APK usa desde antes
    // desta OS. Cobrar a mesma coisa nos dois lugares esconderia a perda de
    // um dos dois; aqui cada um é cobrado onde de fato mora.
    expect(
      vezesNoPasso(
        p,
        literal('if [ ! -f app/' + kCaminhoDaGuarda + ' ]; then'),
      ),
      1,
      reason: 'o portão do APK perdeu a guarda própria de '
          'app/$kCaminhoDaGuarda, que é a que prova a AUSÊNCIA',
    );
    for (final c in <String>[
      kCaminhoDaSuiteProtegida,
      kCaminhoDestaAncora,
      kCaminhoDaAutoridade,
    ]) {
      expect(
        laco.single,
        contains('app/$c'),
        reason: 'o portão do APK não nomeia app/$c no laço vivo',
      );
    }
  });

  // =========================================================================
  // 3 — IDENTIDADE NOMINAL DOS CASOS
  // =========================================================================

  test('os casos das duas metades são exatamente estes', () {
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda');
    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');

    final daGuarda = casosDe(
      codigoDoBloco(guarda, kInicioDaGuarda, kFimDaGuarda, 'a metade que '
          'guarda'),
    );
    expect(
      daGuarda,
      orderedEquals(kCasosDaGuarda),
      reason: 'os casos da metade que guarda deixaram de ser os declarados '
          'nesta âncora: $daGuarda. Um caso retirado sai do placar em '
          'silêncio, e um renomeado troca a prova sem mexer na conta',
    );

    final daSuite = casosDe(protegida);
    expect(
      daSuite,
      orderedEquals(kCasosDaSuiteProtegida),
      reason: 'os casos da suíte protegida deixaram de ser os declarados '
          'nesta âncora: $daSuite',
    );
    expect(
      daSuite.toSet(),
      hasLength(daSuite.length),
      reason: 'dois casos da suíte protegida têm o mesmo nome',
    );
    // Os casos do DESENHO da obrigação são o objeto desta OS, e por isso são
    // cobrados um a um, e não só pela lista inteira.
    for (final c in kCasosDoDesenhoDaObrigacao) {
      expect(
        daSuite,
        contains(c),
        reason: 'o caso "$c" — que é uma das provas visuais da carta '
            'obrigatória — saiu da suíte protegida',
      );
    }
  });

  // =========================================================================
  // 4 — CONTEÚDO ESTRUTURAL INDISPENSÁVEL
  // =========================================================================

  test('cada metade tem as declarações sem as quais ela não confere nada', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    for (final d in kDeclaracoesDaGuarda) {
      expect(
        guarda,
        contains(d),
        reason: 'a metade que guarda perdeu a declaração "$d": ela pode '
            'conservar os cinco nomes de caso e ter perdido o mapa que diz o '
            'que conferir',
      );
    }

    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');
    final reciproca = codigoDoBloco(
      protegida,
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    for (final d in kDeclaracoesDaReciprocidade) {
      expect(
        reciproca,
        contains(d),
        reason: 'a metade recíproca perdeu a declaração "$d"',
      );
    }
    // As declarações de topo moram FORA do bloco: apagá-las não muda o digest
    // dele, e sem elas a metade recíproca não tem com que comparar.
    final codigoDeTopo = semLinhaDeComentario(protegida);
    for (final d in kDeclaracoesDeTopoDaSuiteProtegida) {
      expect(
        codigoDeTopo,
        contains(d),
        reason: 'a suíte protegida perdeu a declaração de topo "$d", que é o '
            'que a metade recíproca usa para conferir a guarda',
      );
    }
  });

  test('cada metade continua AFIRMANDO o que promete', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    final naoTriviaisDaGuarda = naoTriviaisDe(guarda);
    for (final e in kAfirmacoesDaGuarda.entries) {
      final quantas =
          naoTriviaisDaGuarda.where((a) => a.contains(e.key)).length;
      expect(
        quantas,
        greaterThanOrEqualTo(e.value),
        reason: 'a metade que guarda afirma ${e.key} $quantas vez(es), e esta '
            'âncora pede ${e.value}: a agulha continuar escrita no arquivo não '
            'é a mesma coisa que ela estar dentro do primeiro argumento de um '
            'expect',
      );
    }

    final reciproca = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    final naoTriviaisDaReciproca = naoTriviaisDe(reciproca);
    for (final e in kAfirmacoesDaReciprocidade.entries) {
      final quantas =
          naoTriviaisDaReciproca.where((a) => a.contains(e.key)).length;
      expect(
        quantas,
        greaterThanOrEqualTo(e.value),
        reason: 'a metade recíproca afirma ${e.key} $quantas vez(es), e esta '
            'âncora pede ${e.value}',
      );
    }
  });

  // =========================================================================
  // 5 — PISOS DE AFIRMAÇÕES NÃO TRIVIAIS
  // =========================================================================

  test('as duas metades continuam acima do piso de afirmações', () {
    final guarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    final daGuarda = naoTriviaisDe(guarda);
    expect(
      daGuarda.length,
      greaterThanOrEqualTo(kPisoDaGuarda),
      reason: 'a metade que guarda ficou com ${daGuarda.length} afirmações que '
          'olham para a suíte protegida, de ${afirmacoesDe(guarda).length} '
          'expect: o resto é literal, tautologia ou string',
    );

    final reciproca = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    final daReciproca = naoTriviaisDe(reciproca);
    expect(
      daReciproca.length,
      greaterThanOrEqualTo(kPisoDaReciprocidade),
      reason: 'a metade recíproca ficou com ${daReciproca.length} afirmações '
          'que olham para a guarda, de ${afirmacoesDe(reciproca).length} '
          'expect',
    );
  });

  // =========================================================================
  // 6 — RECIPROCIDADE VIVA
  // =========================================================================

  test('as duas metades se guardam de volta, e os digests que elas declaram batem com o que está lá',
      () {
    final guarda = leitura(kCaminhoDaGuarda, 'é a metade que guarda');
    final protegida = leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida');

    // Apontamento mútuo.
    final blocoDaGuarda =
        codigoDoBloco(guarda, kInicioDaGuarda, kFimDaGuarda, 'a metade que '
            'guarda');
    expect(
      blocoDaGuarda,
      contains(kCaminhoDaSuiteProtegida),
      reason: 'a metade que guarda deixou de apontar para a suíte protegida',
    );
    expect(
      semLinhaDeComentario(protegida),
      contains(kCaminhoDaGuarda),
      reason: 'a suíte protegida deixou de apontar para a guarda externa',
    );

    // O digest que a guarda declara sobre a suíte protegida tem de ser o
    // digest DELA. Presente e errado é uma frase gentil.
    final declaradoLa = RegExp(r"const digestDaSuite = '([0-9a-f]{64})'")
        .firstMatch(guarda)
        ?.group(1);
    expect(
      declaradoLa,
      digestDe(protegida),
      reason: 'o digest que a guarda externa declara sobre a suíte protegida '
          'não é o da suíte protegida: a guarda ficou apontando para um '
          'arquivo que não existe mais',
    );

    // E o digest que a suíte protegida declara sobre o CÓDIGO da guarda tem de
    // ser o daquele bloco.
    final declaradoAqui =
        RegExp(r"const String kDigestDaGuardaExterna = '([0-9a-f]{64})'")
            .firstMatch(protegida)
            ?.group(1);
    expect(
      declaradoAqui,
      digestDe(blocoDaGuarda),
      reason: 'o digest que a suíte protegida declara sobre a guarda externa '
          'não é o do código da guarda externa',
    );
  });

  // =========================================================================
  // 7 — O VÍNCULO DE CONTEÚDO QUE O REALINHAMENTO COORDENADO NÃO ALCANÇA
  // =========================================================================

  test('o código das duas metades bate com o digest desta âncora', () {
    final blocoDaGuarda = codigoDoBloco(
      leitura(kCaminhoDaGuarda, 'é a metade que guarda'),
      kInicioDaGuarda,
      kFimDaGuarda,
      'a metade que guarda',
    );
    expect(
      digestDe(blocoDaGuarda),
      kDigestDoCodigoDaGuarda,
      reason: 'o CÓDIGO da metade que guarda mudou. Este é o residual C10: os '
          'dois arquivos carregam o digest um do outro, e um commit que '
          'esvazia os dois realinha os dois. Este número mora num TERCEIRO '
          'arquivo. Se a mudança é legítima, ele entra aqui no mesmo commit',
    );

    final blocoReciproco = codigoDoBloco(
      leitura(kCaminhoDaSuiteProtegida, 'é a suíte protegida'),
      kInicioDaReciprocidade,
      kFimDaReciprocidade,
      'a metade recíproca',
    );
    expect(
      digestDe(blocoReciproco),
      kDigestDoCodigoDaReciprocidade,
      reason: 'o CÓDIGO da metade recíproca mudou, e o digest dela nesta '
          'âncora não foi realinhado junto',
    );
  });

  // =========================================================================
  // 8 — O REGISTRO, O PRODUTOR, O MARCADOR, O LOG E O CONSUMIDOR
  // =========================================================================

  test('a entrada desta âncora está viva nas três listas do veredito', () {
    final texto = leitura(kAlvoOficial, 'é onde a entrada desta âncora mora');

    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    final obrigatorios = declaracoesDe(texto, 'OBRIGATORIOS');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(
      obrigatorios,
      hasLength(2),
      reason: 'o alvo declara ${obrigatorios.length} listas de gates '
          'obrigatórios, e são duas: a da evidência e a do veredito',
    );
    expect(
      obrigatorios.first,
      orderedEquals(obrigatorios.last),
      reason: 'as duas declarações de OBRIGATORIOS divergiram: o relatório '
          'diria uma coisa e o portão faria outra',
    );

    expect(gates.single, contains(kChaveDoGate),
        reason: '$kChaveDoGate saiu da evidência publicada');
    expect(lista.single, contains(kChaveDoGate),
        reason: '$kChaveDoGate saiu da lista que o veredito percorre — '
            'passaria a rodar sem poder reprovar');
    expect(obrigatorios.first, contains(kChaveDoGate),
        reason: '$kChaveDoGate deixou de ser obrigatório: um passo que não '
            'chegue a rodar voltaria a sair VERDE');
  });

  test('o comando que executa esta âncora está vivo, e não comentado', () {
    final texto = leitura(kAlvoOficial, 'é quem executa esta âncora');
    expect(
      RegExp(
        '^ *exige +' +
            kChaveDoGate +
            ' +' +
            RegExp.escape(kCaminhoDestaAncora) +
            r'[ \t]*$',
        multiLine: true,
      ).hasMatch(texto),
      isTrue,
      reason: 'o alvo oficial não exige $kCaminhoDestaAncora: o literal '
          'continuar escrito num comentário não executa nada, e `roda` no '
          'lugar de `exige` deixa a ausência do arquivo sair como NÃO '
          'EXECUTADO',
    );
  });

  test('o vínculo de conteúdo desta âncora está declarado no alvo oficial',
      () {
    final texto = leitura(kAlvoOficial, 'é onde o vínculo desta âncora mora');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');

    final arquivo = atribuicaoUnica(p, 'ANCORA_ARQUIVO', 'o alvo oficial');
    expect(
      arquivo,
      'app/$kCaminhoDestaAncora',
      reason: 'o alvo oficial deixou de declarar ANCORA_ARQUIVO apontando '
          'para esta âncora — sem isso o digest confere outro arquivo',
    );

    final digest = atribuicaoUnica(p, 'ANCORA_DIGEST', 'o alvo oficial');
    expect(
      digest,
      digestDe(leitura(kCaminhoDestaAncora, 'é esta âncora')),
      reason: 'o digest desta âncora declarado no alvo oficial não é o desta '
          'âncora: o passo que a mede está medindo outra coisa',
    );

    final piso = atribuicaoUnica(p, 'ANCORA_PISO', 'o alvo oficial');
    expect(
      piso,
      '$kCasosDestaAncora',
      reason: 'o piso desta âncora no alvo oficial é $piso, e esta âncora tem '
          '$kCasosDestaAncora casos. Baixar o piso lá é como esvaziar a '
          'âncora aqui: os dois são o mesmo gesto, e nenhum se basta',
    );

    // O SEGUNDO DONO DO DIGEST.
    //
    // Um digest com um dono só é um digest que se realinha — é o residual C10
    // um degrau abaixo. O contrato desta autoridade é o segundo dono, e o alvo
    // oficial reprova se os dois números divergirem.
    final contrato = atribuicaoUnica(p, 'ANCORA_CONTRATO', 'o alvo oficial');
    expect(
      contrato,
      kCaminhoDoContrato,
      reason: 'o alvo oficial deixou de declarar ANCORA_CONTRATO apontando '
          'para $kCaminhoDoContrato: o digest desta âncora voltaria a ter um '
          'dono só',
    );
    final noContrato = RegExp('^ancora-digest: ([0-9a-f]{64})' + r'$',
            multiLine: true)
        .firstMatch(leitura('../$kCaminhoDoContrato', 'é o contrato'))
        ?.group(1);
    expect(
      noContrato,
      digest,
      reason: 'o contrato declara o digest $noContrato e o alvo oficial '
          'declara $digest: um dos dois foi realinhado sozinho',
    );

    // O passo que confere o digest e o piso tem de estar VIVO. Comentá-lo
    // deixaria as declarações acima de pé, sem ninguém as ler.
    for (final l in <String>[
      r'd=$(tr -d "\r" < "$ANCORA_ARQUIVO" | sha256sum | cut -d" " -f1)',
      r'if [ "$d" != "$ANCORA_DIGEST" ]; then',
      r'c=$(grep -oE "^ancora-digest: [0-9a-f]{64}$" "$ANCORA_CONTRATO" | tail -1 | sed "s/.*: //")',
      r'if [ "$c" != "$ANCORA_DIGEST" ]; then',
      r'if [ -z "$n" ] || [ "$n" -lt "$ANCORA_PISO" ]; then',
      r'echo 1 > exit_ancoravis',
    ]) {
      expect(
        vezesNoPasso(p, literal(l)),
        greaterThanOrEqualTo(1),
        reason: 'o verificador externo do alvo oficial perdeu a linha viva '
            '`$l`: as declarações continuariam escritas e ninguém as leria',
      );
    }
  });

  test('o produtor do carimbo está vivo no alvo oficial', () {
    final texto = leitura(kAlvoOficial, 'é quem carimba antes de executar');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');

    // A POSIÇÃO FAZ PARTE DO CONTRATO.
    //
    // A OS 29-C6 conferia que a linha do produtor EXISTIA, nunca ONDE ela
    // estava. A OS 29-R5 mediu o preço: mover a linha para depois do
    // `exige ancoravis` deixava-a viva, escrita letra por letra, e desligava
    // a metade de evidência inteira — marcador, log, data contra o carimbo,
    // piso do placar e chamada nominal deixavam de ser cobrados de uma vez.
    for (final l in <String>[
      kLimpezaDoAlvoOficial,
      kDeclaraPortaDoAlvoOficial,
      kGeraCarimbo,
      kExportaCarimbo,
      kEscrevePorta,
      kEscreveCarimbo,
    ]) {
      expect(
        vezesNoPasso(p, literal(l)),
        1,
        reason: 'o passo "$kPassoDasSuites" do alvo oficial não executa '
            'exatamente uma vez a linha viva `$l`. Um produtor comentado, '
            'ausente, duplicado ou dentro de um bloco morto deixa a evidência '
            'desta corrida sem origem',
      );
    }

    final iLimpeza = indiceDe(p, literal(kLimpezaDoAlvoOficial));
    final iPorta = indiceDe(p, literal(kEscrevePorta));
    final iCarimbo = indiceDe(p, literal(kEscreveCarimbo));
    expect(
      iLimpeza,
      lessThan(iCarimbo),
      reason: 'a limpeza da evidência anterior vem DEPOIS do carimbo novo: o '
          'que sobrou da corrida passada seria apagado com o carimbo desta já '
          'no disco',
    );
    expect(
      iPorta,
      lessThan(iCarimbo),
      reason: 'a porta é declarada depois do carimbo',
    );

    // NENHUMA suíte protegida pode ser invocada antes do carimbo.
    final invocacoes = <int>[
      for (var i = 0; i < p.comandos.length; i++)
        if (kInvocacaoDeSuite.hasMatch(p.comandos[i])) i,
    ];
    expect(
      invocacoes,
      isNotEmpty,
      reason: 'o passo "$kPassoDasSuites" não invoca suíte nenhuma',
    );
    expect(
      invocacoes.first,
      greaterThan(iCarimbo),
      reason: 'a primeira invocação de suíte do passo está na posição '
          '${invocacoes.first} e o carimbo na $iCarimbo: um log escrito ANTES '
          'do carimbo é, para a comparação de datas, evidência de outra '
          'corrida — e mover o carimbo uma linha adiante inverte o sinal de '
          'toda a metade de evidência',
    );

    // E a ordem das quatro chaves do eixo é ela mesma um contrato.
    final iGuarda = indiceDe(
        p, RegExp('^roda +$kChaveDaGuarda +' + RegExp.escape(kCaminhoDaGuarda) + r'$'));
    final iProtegida = indiceDe(
        p,
        RegExp('^exige +$kChaveDaSuiteProtegida +' +
            RegExp.escape(kCaminhoDaSuiteProtegida) +
            r'$'));
    final iAncora = indiceDe(
        p,
        RegExp('^exige +$kChaveDoGate +' +
            RegExp.escape(kCaminhoDestaAncora) +
            r'$'));
    final iAutoridade = indiceDe(
        p,
        RegExp('^exige +$kChaveDaAutoridade +' +
            RegExp.escape(kCaminhoDaAutoridade) +
            r'$'));
    for (final par in <List<Object>>[
      <Object>[kChaveDaGuarda, iGuarda],
      <Object>[kChaveDaSuiteProtegida, iProtegida],
      <Object>[kChaveDoGate, iAncora],
      <Object>[kChaveDaAutoridade, iAutoridade],
    ]) {
      expect(
        par[1],
        greaterThan(iCarimbo),
        reason: 'o gate ${par[0]} é invocado na posição ${par[1]}, e o carimbo '
            'na $iCarimbo',
      );
    }
    expect(
      iAncora,
      greaterThan(iProtegida),
      reason: 'esta âncora lê os logs de $kChaveDaSuiteProtegida: invocada '
          'antes, ela leria evidência que ainda não existe',
    );
    expect(
      iAncora,
      greaterThan(iGuarda),
      reason: 'esta âncora lê os logs de $kChaveDaGuarda: invocada antes, ela '
          'leria evidência que ainda não existe',
    );
    expect(
      iAutoridade,
      greaterThan(iAncora),
      reason: 'a autoridade externa é invocada antes da âncora que ela '
          'verifica',
    );
  });

  // =========================================================================
  // 9 — A EVIDÊNCIA DO EXECUTOR VERDADEIRO
  // =========================================================================
  //
  // O carimbo só existe onde o alvo oficial rodou. Onde ele não existe — no
  // portão do APK, e na bancada de quem está escrevendo — o que se pode
  // afirmar é que o PRODUTOR continua declarado, e isso já foi afirmado acima.
  // Onde ele existe, a evidência é cobrada inteira.

  test('as duas suítes protegidas executaram de verdade, e depois do carimbo',
      () {
    final porta = portaDestaExecucao();
    if (porta == kPortaDoApk) {
      // Nesta porta a âncora roda DENTRO da mesma invocação de `flutter test`
      // que as duas suítes protegidas: não há marcador nem log delas para ler,
      // porque elas estão rodando agora, ao lado. O que se cobra aqui é o que
      // ESTA porta produz — e se cobra nominalmente, não se pula.
      expect(
        File(kCaminhoDaGuarda).existsSync(),
        isTrue,
        reason: 'a metade que guarda sumiu da árvore, e é o portão do APK que '
            'está executando',
      );
      expect(
        File(kCaminhoDaSuiteProtegida).existsSync(),
        isTrue,
        reason: 'a suíte protegida sumiu da árvore, e é o portão do APK que '
            'está executando',
      );
      final p = passo(
        leitura(kPortaoDoApk, 'é a porta por que esta execução veio'),
        kPassoDoPortaoDoApk,
        'o portão do APK',
      );
      expect(
        vezesNoPasso(p, literal(kComandoVivoDoPortaoDoApk)),
        1,
        reason: 'esta execução se declarou como $kPortaDoApk e o passo que a '
            'produz não tem a linha viva que roda as duas pastas',
      );
      return;
    }

    final quandoCarimbou = File(kCarimbo).statSync().modified;
    for (final par in <List<String>>[
      <String>[kChaveDaGuarda, kMarcadorDaGuarda, kLogDaGuarda],
      <String>[
        kChaveDaSuiteProtegida,
        kMarcadorDaSuiteProtegida,
        kLogDaSuiteProtegida,
      ],
    ]) {
      final chave = par[0];
      final marcador = File(par[1]);
      final log = File(par[2]);

      expect(
        marcador.existsSync(),
        isTrue,
        reason: 'há carimbo desta execução e o gate $chave não deixou '
            'marcador de saída: o passo não rodou',
      );
      expect(
        marcador.readAsStringSync().trim(),
        '0',
        reason: 'o gate $chave saiu com '
            '${marcador.readAsStringSync().trim()}',
      );
      expect(
        log.existsSync(),
        isTrue,
        reason: 'o gate $chave tem marcador de saída e não tem log: um '
            'marcador fabricado sem execução é exatamente isto',
      );
      expect(
        log.statSync().modified.isAfter(quandoCarimbou),
        isTrue,
        reason: 'o log do gate $chave é ANTERIOR ao carimbo desta execução '
            '(${log.statSync().modified} < $quandoCarimbou): é evidência de '
            'outra corrida, guardada e reapresentada',
      );
    }
  });

  test('o log de cada suíte protegida chama os casos pelo nome e fecha o placar',
      () {
    final porta = portaDestaExecucao();
    if (porta == kPortaDoApk) {
      // Aqui não há log das duas metades para ler — elas rodam ao lado, nesta
      // mesma invocação. O que esta porta pode afirmar, e afirma, é que o piso
      // do placar dela está declarado e é o desta árvore: uma execução que
      // fechar abaixo dele reprova no shell que a produziu.
      final p = passo(
        leitura(kPortaoDoApk, 'é a porta por que esta execução veio'),
        kPassoDoPortaoDoApk,
        'o portão do APK',
      );
      expect(
        atribuicaoUnica(p, 'APK_PISO', 'o portão do APK'),
        '$kPisoDoPortaoDoApk',
        reason: 'o piso do portão do APK deixou de ser $kPisoDoPortaoDoApk: '
            'sem ele, uma execução com zero teste e exit 0 volta a sair verde',
      );
      return;
    }

    final logDaGuarda = leitura(kLogDaGuarda, 'é o log do gate cascaaud');
    final logDaSuite = leitura(kLogDaSuiteProtegida, 'é o log do gate mesac1');

    expect(
      placarDo(logDaGuarda),
      greaterThanOrEqualTo(kPisoDoPlacarDaGuarda),
      reason: 'o gate $kChaveDaGuarda fechou em ${placarDo(logDaGuarda)} '
          'casos, e o piso é $kPisoDoPlacarDaGuarda',
    );
    expect(
      placarDo(logDaSuite),
      greaterThanOrEqualTo(kPisoDoPlacarDaSuiteProtegida),
      reason: 'o gate $kChaveDaSuiteProtegida fechou em '
          '${placarDo(logDaSuite)} casos, e o piso é '
          '$kPisoDoPlacarDaSuiteProtegida',
    );

    // A chamada NOMINAL. O placar sozinho é uma conta: cinco casos novos e
    // vazios pagam cinco casos protegidos que sumiram.
    for (final c in kCasosDaGuarda) {
      expect(
        logDaGuarda,
        contains(c),
        reason: 'o caso "$c" da metade que guarda não foi chamado pelo nome '
            'no log do executor: ele não rodou nesta execução',
      );
    }
    for (final c in kCasosDoDesenhoDaObrigacao) {
      expect(
        logDaSuite,
        contains(c),
        reason: 'a prova visual "$c" não foi chamada pelo nome no log do '
            'executor: ela não rodou nesta execução',
      );
    }
    expect(
      logDaSuite,
      contains(kCasosDaSuiteProtegida.last),
      reason: 'o caso recíproco "${kCasosDaSuiteProtegida.last}" não foi '
          'chamado pelo nome no log do executor',
    );
  });

  // =========================================================================
  // 10 — A CAMPANHA QUE COBRA O RESIDUAL C10
  // =========================================================================

  test('o contrato desta âncora continua na árvore e nomeia o residual', () {
    final contrato = leitura(
      '../$kCaminhoDoContrato',
      'é o contrato desta autoridade, e é onde a campanha negativa está '
          'registrada',
    );
    for (final t in <String>[
      kCaminhoDaGuarda,
      kCaminhoDaSuiteProtegida,
      kCaminhoDestaAncora,
      kCaminhoDaAutoridade,
      kChaveDoGate,
      kChaveDaAutoridade,
    ]) {
      expect(
        contrato,
        contains(t),
        reason: 'o contrato desta âncora deixou de registrar "$t": a campanha '
            'que cobra o residual C10 saiu do repositório',
      );
    }
    // A CAMPANHA INTEIRA, E NÃO OS DOIS RÓTULOS EXTREMOS.
    //
    // A OS 29-C6 pedia `contains('C6-01')` e `contains('C6-20')`, e a OS 29-R5
    // mediu o preço: a seção caía de 2562 letras para `C6-01 a C6-20.` e o
    // portão continuava verde. Doze letras pagavam dezenove sabotagens.
    conferirCampanha(
      contrato,
      'C6',
      kVetoresDaC6,
      kControlesDaC6,
      'o contrato desta âncora',
    );
  });

  // =========================================================================
  // 11 — A EXECUÇÃO VIVA DA SEGUNDA PORTA (OS 29-C7)
  // =========================================================================

  test('o portão do APK consome o exit real e confere o placar contra o piso',
      () {
    final texto = leitura(kPortaoDoApk, 'é a segunda porta desta âncora');
    final p = passo(texto, kPassoDoPortaoDoApk, 'o portão do APK');

    const linhas = <String>[
      'set +e',
      r'APK_EXIT=${PIPESTATUS[0]}',
      'set -e',
      r'if [ "$APK_EXIT" != "0" ]; then',
      r'APK_PLACAR=$(grep -oE "\+[0-9]+: All tests passed!" ../t_apk_casca.log | grep -oE "[0-9]+" | tail -1)',
      r'if [ -z "$APK_PLACAR" ]; then',
      r'if [ "$APK_PLACAR" -lt "$APK_PISO" ]; then',
    ];
    for (final l in linhas) {
      expect(
        vezesNoPasso(p, literal(l)),
        1,
        reason: 'o portão do APK perdeu a linha viva `$l`. Sem ela o passo '
            'volta a declarar PORTÃO VERDE sem consumir o exit real da '
            'execução e sem comprovar placar: zero teste com exit 0 sairia '
            'verde, que foi o escape E2 da OS 29-R5',
      );
    }
    expect(
      atribuicaoUnica(p, 'APK_PISO', 'o portão do APK'),
      '$kPisoDoPortaoDoApk',
      reason: 'o piso do portão do APK não é $kPisoDoPortaoDoApk. Ele é o '
          'placar da árvore da OS 29-C6 (343) mais os casos novos desta OS, e '
          'baixá-lo é como apagar suíte: nenhum dos casos anteriores pode '
          'desaparecer sem alguém reprovar',
    );

    final iFlutter = indiceDe(p, literal(kComandoVivoDoPortaoDoApk));
    expect(
      iFlutter,
      greaterThanOrEqualTo(0),
      reason: 'o portão do APK não tem a linha viva que executa as duas '
          'pastas: não existe execução cujo exit e cujo placar consumir',
    );
    final iExit = indiceDe(p, literal(r'APK_EXIT=${PIPESTATUS[0]}'));
    final iSeExit = indiceDe(p, literal(r'if [ "$APK_EXIT" != "0" ]; then'));
    final iSeVazio = indiceDe(p, literal(r'if [ -z "$APK_PLACAR" ]; then'));
    final iSePiso =
        indiceDe(p, literal(r'if [ "$APK_PLACAR" -lt "$APK_PISO" ]; then'));
    final iVerde = indiceDe(p, RegExp('^echo "PORTÃO VERDE'));
    expect(
      iVerde,
      greaterThanOrEqualTo(0),
      reason: 'o portão do APK não anuncia mais o próprio veredito',
    );
    for (final par in <List<Object>>[
      <Object>['a captura do exit', iExit],
      <Object>['a conferência do exit', iSeExit],
      <Object>['a conferência de placar vazio', iSeVazio],
      <Object>['a conferência do piso', iSePiso],
      <Object>['o anúncio de PORTÃO VERDE', iVerde],
    ]) {
      expect(
        par[1],
        greaterThan(iFlutter),
        reason: '${par[0]} está ANTES da execução das suítes: o portão '
            'anunciaria o resultado de uma execução que ainda não aconteceu',
      );
    }
    expect(iVerde, greaterThan(iSePiso),
        reason: 'o PORTÃO VERDE é anunciado antes de o piso ser conferido');
    expect(
      p.comandos.sublist(0, iFlutter).where((c) => c == 'exit 0').toList(),
      isEmpty,
      reason: 'o passo sai com sucesso ANTES de executar as suítes',
    );
    expect(
      p.comandos.where((c) => c == 'exit 1').length,
      greaterThanOrEqualTo(3),
      reason: 'as três conferências do portão do APK não reprovam: capturar o '
          'erro e sair verde é o mesmo que não capturar',
    );
    expect(
      p.comandos
          .where((c) => c.startsWith('echo') && c.contains('flutter test'))
          .toList(),
      isEmpty,
      reason: 'o comando de teste do portão do APK virou texto impresso',
    );
  });

  // =========================================================================
  // 12 — A AUTORIDADE EXTERNA DESTA ÂNCORA (OS 29-C7)
  // =========================================================================

  test('a autoridade externa desta âncora está na árvore, íntegra e viva', () {
    final autoridade = leitura(
      kCaminhoDaAutoridade,
      'é a autoridade externa desta âncora, e sem ela o piso, o caminho, a '
          'identidade e o conteúdo desta âncora voltam a morar só nos '
          'arquivos que um gesto de três já está tocando',
    );
    expect(
      autoridade.split('\n').length,
      greaterThan(400),
      reason: 'a autoridade externa encolheu para '
          '${autoridade.split('\n').length} linhas',
    );
    for (final aspa in <String>[kAspaTriplaSimples, kAspaTriplaDupla]) {
      expect(
        autoridade.contains(aspa),
        isFalse,
        reason: 'a autoridade externa passou a usar aspa tripla ($aspa), que '
            'cega qualquer varredor que respeite aspas: o scanner lê a '
            'segunda aspa como fechamento, perde o sincronismo e passa a '
            'medir o mesmo número num arquivo íntegro e num arquivo vazio',
      );
    }
    expect(
      casosDe(autoridade),
      orderedEquals(kCasosDaAutoridadeExterna),
      reason: 'os casos da autoridade externa deixaram de ser os declarados '
          'aqui. Esta lista é a cópia PRÓPRIA desta âncora, e a coincidência '
          'entre as duas é o que um gesto de um arquivo não consegue produzir',
    );
    expect(
      casosDe(autoridade),
      hasLength(kCasosDaAutoridade),
      reason: 'a autoridade externa tem ${casosDe(autoridade).length} casos, e '
          'o contrato são $kCasosDaAutoridade',
    );
    expect(
      digestDe(codigoDe(autoridade)),
      kDigestDoCodigoDaAutoridade,
      reason: 'o CÓDIGO da autoridade externa não bate com o digest declarado '
          'aqui. Esvaziá-la, trocá-la por uma isca de mesmo nome ou '
          'trivializá-la reprova neste ponto mesmo depois de recarimbar '
          'AUTORIDADE_DIGEST no alvo oficial e no contrato dela — que é '
          'exatamente o gesto que a OS 29-R5 mediu contra esta âncora',
    );
    expect(
      naoTriviaisDe(autoridade).length,
      greaterThanOrEqualTo(kPisoDeAfirmacoesDaAutoridade),
      reason: 'a autoridade externa ficou com '
          '${naoTriviaisDe(autoridade).length} afirmações que olham para o '
          'programa, e o piso é $kPisoDeAfirmacoesDaAutoridade: ela virou '
          'casca com os nomes de pé',
    );
    // A RECIPROCIDADE. Uma autoridade que não é guardada de volta é o mesmo
    // residual C10 deslocado um arquivo adiante.
    expect(
      autoridade,
      contains(kCaminhoDestaAncora),
      reason: 'a autoridade externa deixou de nomear esta âncora: ela passou a '
          'guardar outra coisa',
    );
    expect(
      autoridade,
      contains(kCaminhoDaAutoridade),
      reason: 'a autoridade externa deixou de nomear o próprio caminho '
          'canônico',
    );

    // O DIGEST CRU, E OS SEUS DOIS DONOS.
    final texto = leitura(kAlvoOficial, 'é o primeiro dono do digest dela');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    final digest = atribuicaoUnica(p, 'AUTORIDADE_DIGEST', 'o alvo oficial');
    expect(
      digest,
      digestDe(autoridade),
      reason: 'o digest da autoridade externa declarado no alvo oficial não é '
          'o dela',
    );
    final noContrato = RegExp('^autoridade-digest: ([0-9a-f]{64})' + r'$',
            multiLine: true)
        .firstMatch(leitura('../$kCaminhoDoContratoDaAutoridade',
            'é o segundo dono do digest da autoridade externa'))
        ?.group(1);
    expect(
      noContrato,
      digest,
      reason: 'o contrato da autoridade externa declara $noContrato e o alvo '
          'oficial declara $digest: um dos dois foi realinhado sozinho',
    );
    expect(
      atribuicaoUnica(p, 'AUTORIDADE_ARQUIVO', 'o alvo oficial'),
      'app/$kCaminhoDaAutoridade',
      reason: 'AUTORIDADE_ARQUIVO deixou de apontar para a autoridade externa',
    );
    expect(
      atribuicaoUnica(p, 'AUTORIDADE_CONTRATO', 'o alvo oficial'),
      kCaminhoDoContratoDaAutoridade,
      reason: 'AUTORIDADE_CONTRATO deixou de apontar para o contrato dela',
    );
    expect(
      atribuicaoUnica(p, 'AUTORIDADE_PISO', 'o alvo oficial'),
      '$kCasosDaAutoridade',
      reason: 'o piso da autoridade externa no alvo oficial deixou de ser '
          '$kCasosDaAutoridade',
    );
    for (final l in <String>[
      r'da=$(tr -d "\r" < "$AUTORIDADE_ARQUIVO" | sha256sum | cut -d" " -f1)',
      r'if [ "$da" != "$AUTORIDADE_DIGEST" ]; then',
      r'ca=$(grep -oE "^autoridade-digest: [0-9a-f]{64}$" "$AUTORIDADE_CONTRATO" | tail -1 | sed "s/.*: //")',
      r'if [ "$ca" != "$AUTORIDADE_DIGEST" ]; then',
      r'if [ -z "$na" ] || [ "$na" -lt "$AUTORIDADE_PISO" ]; then',
      r'echo 1 > exit_autancora',
    ]) {
      expect(
        vezesNoPasso(p, literal(l)),
        greaterThanOrEqualTo(1),
        reason: 'o verificador externo da autoridade perdeu a linha viva '
            '`$l`',
      );
    }
  });

  test('a entrada da autoridade externa está viva nas duas portas', () {
    final texto = leitura(kAlvoOficial, 'é onde a entrada dela mora');
    final p = passo(texto, kPassoDasSuites, 'o alvo oficial');
    expect(
      vezesNoPasso(
        p,
        RegExp('^exige +$kChaveDaAutoridade +' +
            RegExp.escape(kCaminhoDaAutoridade) +
            r'$'),
      ),
      1,
      reason: 'o alvo oficial não exige $kCaminhoDaAutoridade exatamente uma '
          'vez: o literal continuar escrito num comentário não executa nada, '
          'e `roda` no lugar de `exige` deixa a ausência do arquivo sair como '
          'NÃO EXECUTADO',
    );
    final gates = declaracoesDe(texto, 'GATES');
    final lista = declaracoesDe(texto, 'LISTA');
    final obrigatorios = declaracoesDe(texto, 'OBRIGATORIOS');
    expect(gates, hasLength(1), reason: 'o alvo tem ${gates.length} GATES');
    expect(lista, hasLength(1), reason: 'o alvo tem ${lista.length} LISTA');
    expect(obrigatorios, hasLength(2),
        reason: 'o alvo declara ${obrigatorios.length} listas de obrigatórios');
    expect(obrigatorios.first, orderedEquals(obrigatorios.last),
        reason: 'as duas declarações de OBRIGATORIOS divergiram');
    for (final chave in <String>[kChaveDoGate, kChaveDaAutoridade]) {
      expect(gates.single, contains(chave),
          reason: '$chave saiu da evidência publicada');
      expect(lista.single, contains(chave),
          reason: '$chave saiu da lista que o veredito percorre');
      expect(obrigatorios.first, contains(chave),
          reason: '$chave deixou de ser obrigatório');
      expect(obrigatorios.last, contains(chave),
          reason: '$chave saiu da lista de obrigatórios do veredito');
    }
    // A SEGUNDA PORTA. É ela que reprova o gesto de tirar a entrada do alvo
    // oficial — e o gesto coordenado de tirar das DUAS só passa se as duas
    // suítes também sumirem, e aí o laço abaixo é quem acusa.
    final apk = passo(
      leitura(kPortaoDoApk, 'é a segunda porta'),
      kPassoDoPortaoDoApk,
      'o portão do APK',
    );
    final laco =
        apk.comandos.where((c) => c.startsWith('for obrigatoria in ')).toList();
    expect(laco, hasLength(1), reason: 'o portão do APK perdeu o laço');
    for (final c in <String>[kCaminhoDestaAncora, kCaminhoDaAutoridade]) {
      expect(
        laco.single,
        contains('app/$c'),
        reason: 'o portão do APK não nomeia app/$c no laço vivo: a retirada '
            'coordenada da âncora das DUAS portas sairia verde',
      );
    }
  });

  // =========================================================================
  // 13 — A SEMÂNTICA DAS ATRIBUIÇÕES (OS 29-C7)
  // =========================================================================

  test('as variáveis que decidem execução têm uma atribuição viva só', () {
    const doAlvo = <String>[
      'ANCORA_ARQUIVO',
      'ANCORA_CONTRATO',
      'ANCORA_DIGEST',
      'ANCORA_PISO',
      'AUTORIDADE_ARQUIVO',
      'AUTORIDADE_CONTRATO',
      'AUTORIDADE_DIGEST',
      'AUTORIDADE_PISO',
      'BMV_PORTA_ANCORAVIS',
    ];
    const doApk = <String>['APK_PISO', 'BMV_PORTA_ANCORAVIS'];

    for (final par in <List<Object>>[
      <Object>[kAlvoOficial, kPassoDasSuites, doAlvo, 'o alvo oficial'],
      <Object>[kPortaoDoApk, kPassoDoPortaoDoApk, doApk, 'o portão do APK'],
    ]) {
      final texto = leitura(par[0] as String, 'é ${par[3]}');
      final autorizado = passo(texto, par[1] as String, par[3] as String);
      for (final nome in par[2] as List<String>) {
        final valor = atribuicaoUnica(autorizado, nome, par[3] as String);
        expect(
          valorLiteral(valor),
          isTrue,
          reason: 'o valor de $nome em ${par[3]} é "$valor": um valor composto '
              'em tempo de execução, com expansão indireta ou com fallback '
              'permissivo faz a guarda e o shell falarem de coisas diferentes',
        );
        for (final outro in passosDe(texto)) {
          if (outro.nome == autorizado.nome) continue;
          expect(
            atribuicoesVivas(outro, nome),
            isEmpty,
            reason: '$nome também é atribuído vivo no passo "${outro.nome}" de '
                '${par[3]}. Cada `run:` é um shell próprio: uma atribuição '
                'fora do bloco autorizado ou é inútil, ou é uma segunda '
                'autoridade sobre o mesmo valor',
          );
        }
      }
    }
  });

  // =========================================================================
  // 14 — A CAMPANHA DA AUTORIDADE EXTERNA (OS 29-C7)
  // =========================================================================

  test('a campanha desta OS está inteira, única, ordenada e com resultado',
      () {
    final contrato = leitura(
      '../$kCaminhoDoContratoDaAutoridade',
      'é o contrato da autoridade externa, e é onde a campanha da OS 29-C7 '
          'está registrada',
    );
    for (final t in <String>[
      kCaminhoDestaAncora,
      kCaminhoDaAutoridade,
      kChaveDoGate,
      kChaveDaAutoridade,
      kComandoVivoDoPortaoDoApk,
      '$kPisoDoPortaoDoApk',
    ]) {
      expect(
        contrato,
        contains(t),
        reason: 'o contrato da autoridade externa deixou de registrar "$t"',
      );
    }
    conferirCampanha(
      contrato,
      'C7',
      kVetoresDaC7,
      kControlesDaC7,
      'o contrato da autoridade externa',
    );
  });

  // =========================================================================
  // 15 — A PORTA DESTA EXECUÇÃO (OS 29-C7)
  // =========================================================================

  test('esta execução veio por uma das duas portas, com carimbo desta corrida',
      () {
    final porta = portaDestaExecucao();
    expect(
      <String>[kPortaDoAlvoOficial, kPortaDoApk],
      contains(porta),
      reason: 'porta desconhecida: $porta',
    );
    // E as duas portas têm de declarar nomes DIFERENTES: uma porta que se
    // declara como a outra escaparia da evidência que só a outra produz.
    final alvo = passo(
      leitura(kAlvoOficial, 'é a primeira porta'),
      kPassoDasSuites,
      'o alvo oficial',
    );
    final apk = passo(
      leitura(kPortaoDoApk, 'é a segunda porta'),
      kPassoDoPortaoDoApk,
      'o portão do APK',
    );
    expect(
      atribuicaoUnica(alvo, kEnvPorta, 'o alvo oficial'),
      kPortaDoAlvoOficial,
      reason: 'o alvo oficial deixou de se declarar como $kPortaDoAlvoOficial',
    );
    expect(
      atribuicaoUnica(apk, kEnvPorta, 'o portão do APK'),
      kPortaDoApk,
      reason: 'o portão do APK deixou de se declarar como $kPortaDoApk. Se ele '
          'se declarasse como o alvo oficial, cobraria de si mesmo uma '
          'evidência que ele não produz; se o alvo oficial se declarasse como '
          'ele, deixaria de cobrar a que produz',
    );
    for (final par in <List<Object>>[
      <Object>[alvo, kLimpezaDoAlvoOficial, 'o alvo oficial'],
      <Object>[apk, kLimpezaDoPortaoDoApk, 'o portão do APK'],
    ]) {
      final p = par[0] as Passo;
      for (final l in <String>[
        par[1] as String,
        kGeraCarimbo,
        kExportaCarimbo,
        kEscrevePorta,
        kEscreveCarimbo,
      ]) {
        expect(
          vezesNoPasso(p, literal(l)),
          1,
          reason: '${par[2]} não executa exatamente uma vez `$l`',
        );
      }
      expect(
        indiceDe(p, literal(par[1] as String)),
        lessThan(indiceDe(p, literal(kEscreveCarimbo))),
        reason: 'em ${par[2]} a limpeza vem depois do carimbo novo',
      );
    }
  });
}
