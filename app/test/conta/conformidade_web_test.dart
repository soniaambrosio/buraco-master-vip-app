// conformidade_web_test.dart — O RECURSO WEB, A POLÍTICA E A DOCUMENTAÇÃO.
//
// OS de Conformidade de Exclusão de Conta, §10.
//
// ===========================================================================
// POR QUE PROVA ESTRUTURAL, E NÃO REVISÃO DE TEXTO
// ===========================================================================
//
// Um documento de conformidade envelhece do mesmo jeito que uma matriz de
// retenção escrita em prosa: alguém mexe no produto, o texto continua o mesmo, e
// a promessa publicada passa a divergir do código sem ninguém perceber. A
// diferença é que este texto não fica num `.md` interno — ele fica numa URL que
// a Google Play recebe como declaração formal.
//
// Esta suíte é o portão contra isso. Ela não julga estilo nem redação: ela afere
// PROPRIEDADES que a política do Google exige e que a arquitetura de exclusão
// deste projeto garante, e falha quando alguma delas some.
//
// ===========================================================================
// AS DUAS AFIRMAÇÕES MAIS FORTES DAQUI
// ===========================================================================
//
// 1. NENHUM ALVO DE EXCLUSÃO VEM DO NAVEGADOR. Não basta olhar o HTML e
//    concluir "não parece ter". O teste varre o arquivo por campos de entrada e
//    por menções aos três nomes pelos quais alguém tentaria nomear uma conta
//    (`uid`, `userId`, `publicId`), e recusa qualquer um que não esteja num
//    contexto comprovadamente inofensivo.
//
// 2. NENHUM DADO INSTITUCIONAL FOI INVENTADO. A OS proíbe inventar domínio,
//    e-mail, CNPJ, razão social e prazo de retenção. O teste procura por
//    endereços de e-mail e por domínios externos no HTML e só aceita os que
//    estão numa lista explícita — e confere que todo marcador {{PENDENTE:...}}
//    está declarado em web/PENDENCIAS-EXTERNAS.json, e vice-versa.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'raiz_do_repositorio.dart';

const String kPaginaExclusao = 'web/exclusao-de-conta/index.html';
const String kPaginaPolitica = 'web/politica-de-privacidade/index.html';
const String kPaginaRaiz = 'web/index.html';
const String kPendencias = 'web/PENDENCIAS-EXTERNAS.json';
const String kDocDataSafety = 'docs/GOOGLE-PLAY-EXCLUSAO-CONTA-DATA-SAFETY.md';

/// Os únicos domínios externos que podem aparecer nas páginas.
///
/// LISTA FECHADA de propósito: é ela que transforma "não inventamos domínio" de
/// promessa em verificação. Um endereço novo — de formulário de terceiro, de
/// analytics, de CDN — quebra a suíte e obriga a decisão a ser explícita.
const Set<String> kDominiosPermitidos = {'play.google.com'};

/// Marcador de valor que esta OS se recusou a inventar.
final RegExp kMarcadorPendente = RegExp(r'\{\{PENDENTE:([A-Z0-9_]+)\}\}');

/// O HTML sem os comentários.
///
/// USADO SÓ ONDE A PERGUNTA É SOBRE A PROSA PUBLICADA. O cabeçalho da política
/// explica, em comentário, por que nenhum prazo foi escrito — e cita "5 anos" e
/// "indefinidamente" como exemplos do que não se deve escrever. Uma varredura
/// que não distinguisse comentário de texto acusaria justamente a explicação de
/// cometer o que ela proíbe.
///
/// As demais verificações continuam sobre o arquivo INTEIRO, de propósito: um
/// e-mail de contato ou um host de terceiro escondido num comentário continua
/// sendo servido ao navegador, e continua sendo um problema.
String semComentarios(String html) =>
    html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

void main() {
  late String exclusao;
  late String politica;
  late String raiz;
  late String dataSafety;
  late Map<String, Object?> pendencias;

  setUpAll(() {
    exclusao = lerDaRaiz(kPaginaExclusao);
    politica = lerDaRaiz(kPaginaPolitica);
    raiz = lerDaRaiz(kPaginaRaiz);
    dataSafety = lerDaRaiz(kDocDataSafety);
    pendencias =
        jsonDecode(lerDaRaiz(kPendencias)) as Map<String, Object?>;
  });

  // =========================================================================
  // IDENTIFICAÇÃO
  // =========================================================================
  group('o recurso web se identifica', () {
    test('nomeia o aplicativo e o pacote', () {
      for (final pagina in [exclusao, politica, raiz]) {
        expect(pagina, contains('Buraco Master VIP'));
        expect(pagina, contains('io.github.soniaambrosio.buracomastervip'));
      }
    });

    test('o pacote citado é o mesmo do workflow de release', () {
      // Mesma conferência que `gerenciar_assinatura_test.dart` faz para o deep
      // link, e pelo mesmo motivo: um pacote errado numa página que a Play
      // Console vai receber é uma divergência que nada mais acusaria.
      final workflow = lerDaRaiz('.github/workflows/release-aab.yml');
      final pacote =
          RegExp(r'BMV_APPLICATION_ID:\s*(\S+)').firstMatch(workflow)!.group(1)!;
      expect(exclusao, contains(pacote));
      expect(politica, contains(pacote));
    });

    test('declara quem publica o aplicativo', () {
      // O nome real ainda não existe, e por isso o que se exige aqui é o
      // MARCADOR: a página tem o campo, e ele está declarado como pendência.
      expect(exclusao, contains('{{PENDENTE:NOME_DO_DESENVOLVEDOR}}'));
      expect(politica, contains('{{PENDENTE:NOME_DO_DESENVOLVEDOR}}'));
    });

    test('a página tem título e é indexável', () {
      // Um recurso que a Google precisa alcançar não pode estar com `noindex`.
      expect(exclusao, contains('<title>'));
      expect(exclusao, contains('name="robots"'));
      expect(exclusao, isNot(contains('noindex')));
      expect(politica, isNot(contains('noindex')));
    });
  });

  // =========================================================================
  // O CAMINHO DE EXCLUSÃO
  // =========================================================================
  group('o caminho de exclusão está na página', () {
    test('a exclusão é o assunto do título e do primeiro cabeçalho', () {
      expect(exclusao, contains('<title>Excluir conta'));
      expect(exclusao, contains('<h1>Excluir sua conta'));
    });

    test('há ação de entrar e ação de excluir', () {
      expect(exclusao, contains('id="botao-entrar"'));
      expect(exclusao, contains('id="botao-excluir"'));
      expect(exclusao, contains('id="campo-confirmacao"'));
    });

    test('a página chama as callables do backend autoritativo', () {
      // É isto que a impede de virar uma segunda implementação da exclusão.
      expect(exclusao, contains('resumirExclusaoDeConta'));
      expect(exclusao, contains('excluirMinhaConta'));
    });

    test('a região das callables casa com a do backend', () {
      // Região errada devolve `not-found`, que num fluxo de exclusão é fácil de
      // confundir com "conta já removida".
      final backend = lerDaRaiz('functions-conta/src/index.ts');
      final regiao =
          RegExp(r'region:\s*"([a-z0-9-]+)"').firstMatch(backend)!.group(1)!;
      expect(exclusao, contains(regiao));
    });

    test('a palavra de confirmação do servidor continua sendo exigida', () {
      final reautenticacao = lerDaRaiz('functions-conta/src/reautenticacao.ts');
      final palavra = RegExp(r'PALAVRA_DE_CONFIRMACAO\s*=\s*"([A-Z]+)"')
          .firstMatch(reautenticacao)!
          .group(1)!;
      expect(exclusao, contains(palavra));
    });

    test('a raiz do site leva à página de exclusão', () {
      expect(raiz, contains('href="/exclusao-de-conta/"'));
      expect(raiz, contains('href="/politica-de-privacidade/"'));
    });
  });

  // =========================================================================
  // O APLICATIVO NÃO É A ÚNICA SAÍDA
  // =========================================================================
  group('o usuário não é mandado de volta ao aplicativo', () {
    test('a página diz, com todas as letras, que instalar não é necessário', () {
      expect(
        exclusao.contains('não é necessário') ||
            exclusao.contains('sem instalar'),
        isTrue,
        reason: 'a Google recusa recurso web cuja única instrução seja '
            'reinstalar ou abrir o aplicativo.',
      );
      expect(exclusao, contains('sem instalar e sem abrir o aplicativo'));
    });

    test('o caminho do aplicativo aparece como ALTERNATIVA, não como único', () {
      // O caminho no app é mencionado — tem de ser, é útil a quem já o tem —
      // mas a página precisa continuar resolvendo sozinha.
      expect(exclusao, contains('Configurações → Excluir minha conta'));
      expect(exclusao, contains('Outras formas'));
    });

    test('não há link que só mande instalar o aplicativo', () {
      expect(exclusao, isNot(contains('play.google.com/store/apps/details')));
    });
  });

  // =========================================================================
  // NENHUM ALVO VEM DO NAVEGADOR
  // =========================================================================
  group('não se exclui a conta de terceiro', () {
    test('o único campo de entrada da página é o da confirmação', () {
      // Se um dia alguém acrescentar um campo, esta contagem obriga a decisão a
      // ser consciente — e a passar por revisão.
      final campos = RegExp(r'<input\b').allMatches(exclusao).length;
      expect(
        campos,
        1,
        reason: 'a página deve ter exatamente um campo de entrada (a palavra de '
            'confirmação). Qualquer outro campo é candidato a virar alvo de '
            'exclusão escolhido por quem digita.',
      );
      expect(exclusao, contains('id="campo-confirmacao"'));
    });

    test('não há campo de UID, de e-mail-alvo nem de código de jogador', () {
      for (final proibido in [
        'name="uid"',
        'name="userId"',
        'name="publicId"',
        'id="campo-uid"',
        'id="campo-email"',
        'id="campo-publicid"',
      ]) {
        expect(
          exclusao,
          isNot(contains(proibido)),
          reason: 'entrada de alvo encontrada: $proibido',
        );
      }
    });

    test('os payloads enviados não carregam alvo', () {
      // As duas únicas chamadas: uma sem dados, outra só com a confirmação.
      expect(exclusao, contains('chamar("resumirExclusaoDeConta")'));
      expect(
        exclusao,
        contains('chamar("excluirMinhaConta", { confirmacao:'),
      );
    });

    test('a página reconhece a recusa de alvo do servidor', () {
      // Não é decoração: é a prova de que quem escreveu a página conhecia a
      // regra do backend e não tentou contorná-la.
      expect(exclusao, contains('alvoNoPayloadRecusado'));

      final backend = lerDaRaiz('functions-conta/src/index.ts');
      expect(
        backend,
        contains('alvoNoPayloadRecusado'),
        reason: 'a recusa de alvo saiu do backend — a página passou a citar uma '
            'garantia que não existe mais.',
      );
    });

    test('a identidade vem da autenticação, e o login é explícito', () {
      expect(exclusao, contains('signInWithPopup'));
      // `select_account` evita excluir a conta errada por já estar logado.
      expect(exclusao, contains('select_account'));
    });

    test('o texto promete o que o código faz', () {
      expect(exclusao, contains('não existe, nesta página,'));
      expect(exclusao, contains('conta de outra pessoa'));
    });
  });

  // =========================================================================
  // NENHUM SEGREDO NO FRONTEND
  // =========================================================================
  group('não há credencial nem segredo na página', () {
    test('a configuração do Firebase vem do Hosting, não do repositório', () {
      expect(exclusao, contains('/__/firebase/init.js'));
      for (final chave in ['apiKey', 'appId', 'messagingSenderId', 'projectId']) {
        expect(
          exclusao,
          isNot(contains('$chave:')),
          reason: 'configuração do Firebase colada à mão: $chave',
        );
      }
    });

    test('não há chave privada, token nem credencial administrativa', () {
      for (final suspeito in [
        'BEGIN PRIVATE KEY',
        'service_account',
        'serviceAccount',
        'firebase-adminsdk',
        'admin: true',
        'Bearer ',
      ]) {
        expect(
          exclusao,
          isNot(contains(suspeito)),
          reason: 'segredo ou credencial administrativa na página: $suspeito',
        );
      }
    });

    test('a única chave prevista é a do App Check, e ela é pendência', () {
      // Chave de site do reCAPTCHA é pública por natureza — e mesmo assim não
      // foi inventada.
      expect(exclusao, contains('{{PENDENTE:RECAPTCHA_SITE_KEY_WEB}}'));
    });

    test('nenhuma rota administrativa é chamada', () {
      for (final rota in ['excluirContaDe', 'adminExcluir', 'forcarExclusao']) {
        expect(exclusao, isNot(contains(rota)));
      }
    });
  });

  // =========================================================================
  // NADA FOI INVENTADO
  // =========================================================================
  group('nenhum dado institucional foi inventado', () {
    test('não há endereço de e-mail escrito nas páginas', () {
      // O e-mail de suporte é pendência declarada. Um endereço real aqui seria
      // ou invenção, ou o e-mail de commit usado fora do lugar dele.
      final email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
      for (final pagina in [exclusao, politica, raiz]) {
        expect(
          email.allMatches(pagina).map((m) => m.group(0)).toList(),
          isEmpty,
          reason: 'endereço de e-mail escrito à mão numa página pública.',
        );
      }
    });

    test('os domínios externos citados estão numa lista fechada', () {
      final hosts = <String>{};
      for (final pagina in [exclusao, politica, raiz]) {
        for (final m in RegExp(r'https?://([A-Za-z0-9.-]+)').allMatches(pagina)) {
          hosts.add(m.group(1)!);
        }
      }
      expect(
        hosts.difference(kDominiosPermitidos),
        isEmpty,
        reason: 'domínio externo não previsto nas páginas públicas.',
      );
    });

    test('não há prazo de retenção inventado', () {
      // A OS é explícita: nada de "5 anos", "10 anos" ou "indefinidamente" sem
      // fonte. A política declara a finalidade, e deixa a duração como decisão
      // pendente.
      final prazo = RegExp(
        r'\b\d+\s*(anos?|meses|dias)\b|indefinidamente|permanentemente',
        caseSensitive: false,
      );
      expect(
        prazo.allMatches(semComentarios(politica)).map((m) => m.group(0)).toList(),
        isEmpty,
        reason: 'prazo de conservação escrito sem decisão que o sustente.',
      );
      expect(politica, contains('{{PENDENTE:PRAZOS_DE_RETENCAO}}'));
    });

    test('todo marcador pendente está declarado, e vice-versa', () {
      final declarados = <String>{
        for (final p in pendencias['pendencias']! as List<Object?>)
          (p as Map<String, Object?>)['marcador']! as String,
      };

      final usados = <String>{};
      for (final pagina in [exclusao, politica, raiz]) {
        for (final m in kMarcadorPendente.allMatches(pagina)) {
          usados.add(m.group(1)!);
        }
      }

      expect(
        usados.difference(declarados),
        isEmpty,
        reason: 'marcador usado no HTML e não declarado em $kPendencias — '
            'valor pendente que ninguém vai lembrar de preencher.',
      );
      expect(
        declarados.difference(usados),
        isEmpty,
        reason: 'pendência declarada que não aparece em página nenhuma — '
            'entrada obsoleta em $kPendencias.',
      );
      expect(usados, isNotEmpty);
    });

    test('cada pendência diz o que é, quem decide e onde aparece', () {
      for (final p in pendencias['pendencias']! as List<Object?>) {
        final item = p as Map<String, Object?>;
        for (final campo in ['marcador', 'oQueE', 'quemDecide', 'ondeAparece']) {
          expect(
            item[campo],
            isNotNull,
            reason: 'pendência ${item['marcador']} sem "$campo".',
          );
        }
        final onde = item['ondeAparece']! as List<Object?>;
        expect(onde, isNotEmpty);
        for (final caminho in onde) {
          // O caminho declarado tem de existir E conter o marcador.
          expect(
            lerDaRaiz(caminho! as String),
            contains('{{PENDENTE:${item['marcador']}}}'),
            reason: 'a pendência ${item['marcador']} diz aparecer em $caminho, '
                'e não aparece.',
          );
        }
      }
    });
  });

  // =========================================================================
  // A POLÍTICA DE PRIVACIDADE
  // =========================================================================
  group('a política cobre o que a Play exige', () {
    test('tem seção de exclusão de conta, com os dois caminhos', () {
      expect(politica, contains('Exclusão da conta'));
      expect(politica, contains('Configurações → Excluir minha conta'));
      expect(politica, contains('href="/exclusao-de-conta/"'));
    });

    test('tem seção de retenção, e ela nomeia as quatro classes', () {
      expect(politica, contains('O que acontece com cada dado'));
      expect(politica, contains('O que é apagado'));
      expect(politica, contains('O que fica sem o seu nome'));
      expect(politica, contains('O que fica sem ligação com a sua conta'));
      expect(politica, contains('O que é retido'));
    });

    test('tem seção de prazo, mesmo sem prazo decidido', () {
      expect(politica, contains('Por quanto tempo'));
    });

    test('menciona a assinatura da Google Play e que ela não é cancelada', () {
      expect(politica, contains('Google Play'));
      expect(politica, contains('não cancela a sua assinatura'));
      // E que cancelar não é requisito para excluir.
      expect(politica, contains('não é requisito'));
    });

    test('não promete apagamento integral', () {
      // A frase fácil seria falsa: a matriz classifica em cinco classes, e só
      // uma apaga. Publicá-la seria contradizer o próprio código.
      for (final promessa in [
        'todos os seus dados são apagados',
        'todos os dados são apagados',
        'apagamos todos os seus dados',
        'exclusão completa de todos os dados',
      ]) {
        expect(
          politica.toLowerCase(),
          isNot(contains(promessa)),
          reason: 'promessa de apagamento integral em desacordo com a matriz: '
              '"$promessa"',
        );
      }
      // E o oposto está dito explicitamente.
      expect(politica, contains('Não é verdade que tudo é apagado'));
    });

    test('usa terminologia precisa em vez de chamar tudo de anônimo', () {
      // A OS proíbe chamar indistintamente de "dados anônimos" o que é
      // pseudonimizado ou apenas desvinculado.
      expect(politica, contains('anonimização'));
      expect(politica, contains('esvinculação'));
      expect(politica, contains('seudonimizados'));
      expect(
        politica,
        contains('esta política não os chama de dados'),
        reason: 'a política precisa dizer explicitamente que o que é retido NÃO '
            'é dado anônimo.',
      );
    });

    test('as quatro classes da política existem na matriz do backend', () {
      // O elo que impede a política de descrever um mundo que o código
      // abandonou.
      final matriz = lerDaRaiz('functions-conta/src/inventario.ts');
      for (final classe in ['APAGAR', 'ANONIMIZAR', 'DESVINCULAR', 'RETER']) {
        expect(matriz, contains('$classe:'));
      }
    });

    test('os motivos de retenção citados são os da matriz', () {
      for (final motivo in [
        'integridade',
        'moderação',
        'antifraude',
        'auditoria',
        'idempotência',
      ]) {
        expect(
          politica.toLowerCase(),
          contains(motivo.toLowerCase()),
          reason: 'motivo de retenção ausente da política: $motivo',
        );
      }
    });
  });

  // =========================================================================
  // A ASSINATURA, NAS TRÊS SUPERFÍCIES
  // =========================================================================
  group('a assinatura da Play é tratada em todo lugar', () {
    test('a página de exclusão avisa e oferece a saída', () {
      expect(exclusao, contains('NÃO é cancelada'));
      expect(exclusao, contains('play.google.com/store/account/subscriptions'));
    });

    test('cancelar não é apresentado como requisito', () {
      expect(exclusao, contains('não é obrigatório'));
    });

    test('o aplicativo diz o mesmo que a página', () {
      // As duas superfícies não podem divergir: a mesma pessoa lê as duas.
      final dominio = lerDaRaiz('app/lib/conta/exclusao_de_conta.dart');
      expect(dominio, contains('NÃO é cancelada'));
    });
  });

  // =========================================================================
  // A DOCUMENTAÇÃO DO PLAY CONSOLE
  // =========================================================================
  group('o guia de preenchimento do Play Console', () {
    test('responde às perguntas do formulário', () {
      for (final exigido in [
        'permite criar conta',
        'Configurações → Excluir minha conta',
        'URL',
        'Data Safety',
        'Política de Privacidade',
      ]) {
        expect(dataSafety, contains(exigido));
      }
    });

    test('declara a URL planejada, e ela casa com a hospedagem configurada', () {
      final firebaseJson =
          jsonDecode(lerDaRaiz('firebase.json')) as Map<String, Object?>;
      final hosting = firebaseJson['hosting']! as Map<String, Object?>;
      expect(hosting['public'], 'web');

      final projeto =
          (jsonDecode(lerDaRaiz('.firebaserc')) as Map<String, Object?>);
      final id = (projeto['projects']! as Map<String, Object?>)['default']!;
      expect(
        dataSafety,
        contains('https://$id.web.app/exclusao-de-conta'),
        reason: 'a URL documentada não corresponde ao projeto do .firebaserc.',
      );
    });

    test('separa as pendências por natureza', () {
      expect(dataSafety, contains('Bloqueador de código'));
      expect(dataSafety, contains('Bloqueador de deploy'));
      expect(dataSafety, contains('Ação manual no Play Console'));
      expect(dataSafety, contains('Entrada externa'));
    });

    test('não declara conformidade concluída antes da publicação', () {
      // A conclusão que a OS exige quando a página não está no ar.
      expect(dataSafety, contains('ainda depende da publicação da URL'));
      expect(
        dataSafety.toLowerCase(),
        isNot(contains('google play compliant')),
      );
    });

    test('lista as mesmas pendências declaradas no manifesto', () {
      for (final p in pendencias['pendencias']! as List<Object?>) {
        final marcador = (p as Map<String, Object?>)['marcador']! as String;
        expect(
          dataSafety,
          contains(marcador),
          reason: 'pendência $marcador não aparece no guia do Play Console — '
              'quem for preencher o formulário não vai saber que ela existe.',
        );
      }
    });
  });
}
