// auditoria_descoberta_social_test.dart — as REGRAS da OS, varridas no código.
//
// ---------------------------------------------------------------------------
// POR QUE UMA AUDITORIA ESTRUTURAL AO LADO DAS DE COMPORTAMENTO
// ---------------------------------------------------------------------------
//
// As suítes irmãs provam que o aplicativo se comporta certo HOJE. Estas provam
// que o defeito não pode voltar por um caminho novo. A diferença já custou caro
// neste repositório: a auditoria que proibia os literais de liga inventada
// ficou VERDE quando alguém reintroduziu a mesma semântica por outra escrita, e
// quem pegou foram as suítes de comportamento — e vice-versa, uma função que
// renasce com nome novo passa por todo teste de comportamento existente.
//
// As duas camadas se complementam, e nenhuma delas substitui a outra.
//
// Cada grupo abaixo é uma REGRA da ordem de serviço, escrita como varredura.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Os arquivos do módulo social do CLIENTE.
const _doModulo = [
  'lib/amigos/estado_social.dart',
  'lib/amigos/transporte_social.dart',
  'lib/amigos/transporte_social_firebase.dart',
  'lib/amigos/leitor_social.dart',
  'lib/amigos/escopo_social.dart',
  'lib/amigos/rotulos_sociais.dart',
];

/// As superfícies que consomem o módulo.
const _asTelas = [
  'lib/casca/amigos_de_producao.dart',
  'lib/pages/perfil_page.dart',
  'lib/casca/navegacao_perfil_publico.dart',
];

/// O arquivo SEM comentários, respeitando aspas.
///
/// Indispensável nesta suíte: os próprios arquivos auditados explicam em prosa
/// o que é proibido, e uma varredura ingênua acusaria a explicação como
/// violação — que é o modo mais rápido de uma auditoria ser desativada por
/// quem se cansou dos falsos positivos.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
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
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

final RegExp _reImport = RegExp(r'''import\s+['"]([^'"]+)['"]''');

void main() {
  setUpAll(() {
    // A auditoria precisa ter o que ler. Sem isto, um caminho errado deixaria
    // todos os casos abaixo verdes por não encontrarem nada.
    for (final caminho in [..._doModulo, ..._asTelas]) {
      expect(
        File(caminho).existsSync(),
        isTrue,
        reason: '$caminho sumiu — a auditoria ficaria verde sem ler nada',
      );
    }
  });

  // =========================================================================
  // §  apelido nunca vira identidade
  // =========================================================================
  group('apelido não é identificador', () {
    test('nenhuma chamada de ação ou de perfil viaja com apelido', () {
      // O vocabulário do fio é `publicId`. Um `apelido:` como argumento de
      // `agir` ou de `verPerfilPublico` seria o apelido virando chave — e
      // apelido NÃO É ÚNICO, então dois jogadores homônimos colidiriam.
      final proibidos = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        final fonte = _codigo(File(caminho));
        for (final padrao in [
          RegExp(r'agir\([^)]*apelido'),
          RegExp(r'verPerfilPublico\([^)]*apelido'),
          RegExp(r'publicIdVisitado\s*:\s*[\w.]*apelido'),
        ]) {
          if (padrao.hasMatch(fonte)) proibidos.add('$caminho: ${padrao.pattern}');
        }
      }
      expect(proibidos, isEmpty);
    });

    test('a decisão de qual Perfil abrir não vê apelido', () {
      // A regra já valia para o ranking; agora ela vale para as três origens.
      final fonte = _codigo(File('lib/casca/navegacao_perfil_publico.dart'));
      expect(fonte, isNot(contains('apelido')));
    });
  });

  // =========================================================================
  // §  posição/índice nunca vira publicId
  // =========================================================================
  group('posição e índice não identificam ninguém', () {
    test('a navegação não conhece posição nem índice de lista', () {
      final fonte = _codigo(File('lib/casca/navegacao_perfil_publico.dart'));
      for (final proibido in const [
        'posicao',
        'indexOf',
        'elementAt',
        'index]',
        '[i]',
      ]) {
        expect(fonte, isNot(contains(proibido)), reason: proibido);
      }
    });

    test('as telas sociais passam o publicId, e nunca um índice', () {
      // O que se procura é a forma do defeito: `agir(acao, i)` ou
      // `AlvoDePerfil...(indice)`. Cada chamada tem de nomear o identificador.
      final tela = _codigo(File('lib/casca/amigos_de_producao.dart'));
      final chamadas = RegExp(r'onAgir\s*:\s*\(a\)\s*=>\s*_agir\(a,\s*([^)]+)\)')
          .allMatches(tela)
          .map((m) => m.group(1)!.trim())
          .toList();
      expect(chamadas, isNotEmpty, reason: 'a varredura não achou as chamadas');
      for (final argumento in chamadas) {
        expect(
          argumento,
          endsWith('.publicId'),
          reason: 'a ação foi endereçada por outra coisa: $argumento',
        );
      }
    });
  });

  // =========================================================================
  // §  a busca não retorna UID
  // =========================================================================
  group('UID não atravessa a fronteira', () {
    test('nenhum arquivo do módulo social do cliente menciona uid', () {
      // O backend nunca publica UID (a trava `exigirRespostaSegura` transforma
      // o vazamento em erro), e este lado não tem por onde recebê-lo. Uma
      // menção aqui só poderia significar que alguém começou a esperá-lo.
      final infratores = <String>[];
      final uid = RegExp(r'\buid\b|\bUid\b|\buserId\b', caseSensitive: true);
      for (final caminho in _doModulo) {
        if (uid.hasMatch(_codigo(File(caminho)))) infratores.add(caminho);
      }
      expect(infratores, isEmpty);
    });

    test('`JogadorPublico` não tem campo de identidade interna', () {
      final fonte = _codigo(File('lib/amigos/estado_social.dart'));
      final campos = RegExp(r'final\s+\S+\s+(\w+);')
          .allMatches(fonte)
          .map((m) => m.group(1)!)
          .toSet();
      for (final proibido in const [
        'uid',
        'userId',
        'ownerUid',
        'membros',
        'pairKey',
        'email',
      ]) {
        expect(campos, isNot(contains(proibido)), reason: proibido);
      }
    });
  });

  // =========================================================================
  // §  sem duplicar grafo social no cliente
  // =========================================================================
  group('o cliente não guarda grafo', () {
    test('o leitor não guarda relação em memória — nem índice, nem cache', () {
      // O que o leitor guarda são PÁGINAS e VOOS. Um mapa de relação por
      // jogador seria o grafo local, e com ele a tela passaria a responder
      // "somos amigos?" de memória — inclusive depois de a resposta ter
      // mudado noutro aparelho.
      //
      // O padrão é PREGUIÇOSO de propósito: um `[^>]*` não atravessa
      // `Future<void>>`, e com ele metade dos campos escaparia da varredura
      // sem ninguém notar.
      final campos = RegExp(r'Map<[\s\S]*?>\s+(_?\w+)\s*=')
          .allMatches(_codigo(File('lib/amigos/leitor_social.dart')))
          .toList();
      expect(campos, isNotEmpty, reason: 'a varredura não achou campo nenhum');
      for (final m in campos) {
        expect(
          m.group(0),
          isNot(contains('RelacaoSocial')),
          reason: 'nasceu um índice de relação em memória',
        );
        expect(
          m.group(0),
          isNot(contains('ResultadoSocial>')),
          reason: 'nasceu um cache de relação — e relação guardada é um botão '
              'que afirma uma permissão que pode já não valer',
        );
      }
      // E os campos que existem são os quatro previstos. Um quinto tem de
      // passar por aqui, e por isso tem de ser explicado por quem o criar.
      expect(campos.map((m) => m.group(1)).toSet(), {
        '_ultimoPedido',
        '_emVoo',
        '_listas',
        '_vistasEmVoo',
      });
    });

    test('nada no cliente ADICIONA jogador a uma lista social', () {
      // Subtrair é permitido (a autoridade acabou de dizer que a pendência
      // acabou); adicionar não é. Quem entra numa lista é a próxima leitura.
      final fonte = _codigo(File('lib/amigos/leitor_social.dart'));
      expect(
        RegExp(r'\.itens\s*\.\.\s*add|itens\.add\(|itens\.insert\(').hasMatch(fonte),
        isFalse,
        reason: 'o leitor passou a inserir jogador numa lista por conta própria',
      );
      // `PaginaSocial` oferece SUBTRAÇÃO e concatenação de página do servidor —
      // e nenhuma outra mutação.
      final estado = _codigo(File('lib/amigos/estado_social.dart'));
      expect(estado, contains('PaginaSocial sem(String publicId)'));
    });

  });

  // =========================================================================
  // §  a interface não inventa permissão
  // =========================================================================
  group('as ações vêm do servidor', () {
    test('nenhuma tela deriva ação a partir da relação', () {
      // A forma do defeito é comparar a relação e concluir qual botão desenhar.
      // A exceção auditada e documentada são as ações das LISTAS
      // (`_acoesDaAba`), que o contrato não devolve — ver o comentário longo
      // naquela função.
      final infratores = <String>[];
      final deducao = RegExp(
        r'relacao\s*==\s*RelacaoSocial\.\w+\s*\?[^;]*Acao|'
        r'switch\s*\(\s*relacao\s*\)[^}]*Acao',
      );
      for (final caminho in _asTelas) {
        if (deducao.hasMatch(_codigo(File(caminho)))) infratores.add(caminho);
      }
      expect(infratores, isEmpty);
    });

    test('os botões saem de `acoes`, e são filtrados pelo que há porta', () {
      for (final caminho in const [
        'lib/casca/amigos_de_producao.dart',
        'lib/pages/perfil_page.dart',
      ]) {
        final fonte = _codigo(File(caminho));
        expect(
          fonte,
          contains('kAcoesDeAmizade.contains'),
          reason: '$caminho parou de filtrar as ações que sabe executar',
        );
      }
    });

    test('`bloquear` e `desbloquear` não têm caminho neste módulo', () {
      // São do codebase de MODERAÇÃO. O social só REAGE a eles por gatilho, e
      // uma chamada daqui seria o cliente pedindo ao codebase errado.
      final transporte = _codigo(
        File('lib/amigos/transporte_social_firebase.dart'),
      );
      for (final proibida in const ['bloquearJogador', 'desbloquearJogador']) {
        expect(transporte, isNot(contains(proibida)), reason: proibida);
      }
    });
  });

  // =========================================================================
  // §  publicId continua opaco, e o cliente não importa o domínio de servidor
  // =========================================================================
  group('a fronteira com `lib/social/`', () {
    test('nenhum arquivo do módulo importa o domínio das Functions', () {
      // `lib/social/` é código de SERVIDOR (compilado para JS). Importá-lo
      // traria para dentro do aplicativo o cunhador de `publicId`.
      final infratores = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        for (final m in _reImport.allMatches(_codigo(File(caminho)))) {
          if (RegExp(r'(^|/)social/').hasMatch(m.group(1)!)) {
            infratores.add('$caminho -> ${m.group(1)}');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('nada calcula, valida ou repara a FORMA de um publicId', () {
      final infratores = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        final fonte = _codigo(File(caminho));
        for (final proibido in const [
          'kAlfabetoIdPublico',
          'kComprimentoIdPublico',
          'kPrefixoIdPublico',
          'idPublicoDeBytes',
          'idPublicoValido',
          '0123456789ABCDEFGHJKMNPQRSTVWXYZ',
        ]) {
          if (fonte.contains(proibido)) infratores.add('$caminho: $proibido');
        }
      }
      expect(infratores, isEmpty);
    });

    test('a checagem de id utilizável para em "não vazio"', () {
      final fonte = _codigo(File('lib/amigos/estado_social.dart'));
      expect(fonte, contains('publicId.trim().isNotEmpty'));
      // E não existe comparação de comprimento nem de prefixo.
      expect(fonte, isNot(RegExp(r'publicId\.(length|startsWith)')));
    });
  });

  // =========================================================================
  // §  bloqueio/moderação prevalece sobre descoberta
  // =========================================================================
  group('o bloqueio não é decidido nem revelado pelo cliente', () {
    test('o cliente não tem vocabulário para saber quem o bloqueou', () {
      // `alvoMeBloqueou` existe no domínio do SERVIDOR e é deliberadamente
      // colapsado em `indisponivel` na resposta. Se ele aparecesse aqui,
      // alguém teria começado a esperá-lo — e o passo seguinte é a tela
      // escrever "Fulano bloqueou você".
      final infratores = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        final fonte = _codigo(File(caminho));
        for (final proibido in const ['alvoMeBloqueou', 'euBloqueeiOAlvo']) {
          if (fonte.contains(proibido)) infratores.add('$caminho: $proibido');
        }
      }
      expect(infratores, isEmpty);
    });

    test('nenhuma frase da tela distingue bloqueio de sanção', () {
      // `indisponivel` é UM estado para DOIS fatos, e os textos precisam
      // respeitar isso — é a razão de o estado existir.
      final rotulos = _codigo(File('lib/amigos/rotulos_sociais.dart'));
      for (final proibida in const [
        'bloqueou você',
        'bloqueou voce',
        'te bloqueou',
        'silenciado',
        'suspenso',
        'banido',
      ]) {
        expect(rotulos, isNot(contains(proibida)), reason: proibida);
      }
    });

    test('o código de recusa só é LIDO para escolher a frase, nunca exibido', () {
      // ---------------------------------------------------------------------
      // A REGRA FICOU MAIS FORTE PORQUE A ANTERIOR DEIXOU PASSAR UMA MUTAÇÃO
      // ---------------------------------------------------------------------
      //
      // Antes esta varredura proibia a INTERPOLAÇÃO (`${e.recusa}`). Injetando
      // um braço de `switch` que devolve `e.recusa` CRU — sem interpolação
      // nenhuma —, o código interno chegava inteiro à tela e a auditoria ficava
      // verde. O defeito não é a interpolação: é o valor sair.
      //
      // A regra agora é posicional e não tem essa brecha: `e.recusa` só pode
      // aparecer como ASSUNTO de um `switch`. Em qualquer outra posição ele
      // está a caminho de virar texto.
      final rotulos = _codigo(File('lib/amigos/rotulos_sociais.dart'));
      final usos = RegExp(r'e\.recusa').allMatches(rotulos).toList();
      expect(usos, isNotEmpty, reason: 'a varredura não achou nenhum uso');
      for (final m in usos) {
        final antes = rotulos.substring(
          (m.start - 10).clamp(0, rotulos.length),
          m.start,
        );
        expect(
          antes,
          endsWith('switch ('),
          reason: 'o código de recusa saiu do `switch` e está indo para a tela',
        );
      }
    });
  });

  // =========================================================================
  // §  a maquete continua órfã
  // =========================================================================
  group('a maquete de Amigos não voltou', () {
    test('a tela de produção não importa nem constrói a maquete', () {
      final fonte = _codigo(File('lib/casca/amigos_de_producao.dart'));
      expect(fonte, isNot(contains('amigos_screen')));
      expect(fonte, isNot(contains('AmigosScreen')));
      expect(fonte, isNot(contains('AmigosVM')));
      expect(fonte, isNot(contains('.mock(')));
    });

    test('nenhum identificador da maquete existe no módulo ou nas telas', () {
      // Os slugs da maquete COMPILAM contra `publicIdVisitado` — são `String`.
      // Chegando lá, a callable responderia `invalid-argument`, depois de o
      // aplicativo já ter afirmado que aquela pessoa existe.
      const slugs = [
        "'beto'",
        "'claudia'",
        "'fernanda'",
        "'mateus'",
        "'sofia'",
        "'larissa'",
        "'ricardo'",
        "'joao'",
        "'voce'",
        'SONIA-RAINHA',
      ];
      final achados = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        final fonte = _codigo(File(caminho));
        for (final slug in slugs) {
          if (fonte.contains(slug)) achados.add('$caminho: $slug');
        }
      }
      expect(achados, isEmpty);
    });

    test('a maquete continua existindo — ninguém a apagou para calar a regra', () {
      // Apagar o arquivo faria as auditorias N12/C16 ficarem verdes por vacuidade.
      expect(File('lib/screens/amigos_screen.dart').existsSync(), isTrue);
    });
  });

  // =========================================================================
  // §  a fronteira do adaptador
  // =========================================================================
  group('só um arquivo conhece Firebase', () {
    test('`cloud_functions` entra por um ponto só do módulo', () {
      final comFirebase = <String>[];
      for (final caminho in [..._doModulo, ..._asTelas]) {
        final fonte = _codigo(File(caminho));
        if (fonte.contains('cloud_functions') ||
            fonte.contains('FirebaseFunctions')) {
          comFirebase.add(caminho);
        }
      }
      expect(comFirebase, ['lib/amigos/transporte_social_firebase.dart']);
    });

    test('a região é IMPORTADA da identidade, e não recopiada', () {
      // Duas cópias divergem, e chamar a região errada devolve `not-found` —
      // que é o mesmo código de "esse jogador não existe".
      final fonte = _codigo(
        File('lib/amigos/transporte_social_firebase.dart'),
      );
      expect(fonte, contains('kRegiaoFuncoesSociais'));
      expect(
        fonte,
        isNot(contains("'southamerica-east1'")),
        reason: 'a região virou um literal duplicado',
      );
    });

    test('os nomes das callables são os que o backend exporta', () {
      // Varre o `index.ts` de verdade. Um rename no backend sem rename aqui é
      // um `not-found` em produção que nenhum teste de cliente pegaria.
      // ESTE CASO SÓ RODA NO REPOSITÓRIO, e diz em voz alta quando não roda.
      //
      // O overlay que o CI monta (`flutter create app_build` mais a cópia de
      // `lib/` e `test/`) não tem `functions-social` ao lado, e a bancada
      // local em C: também não. Marcar como PULADO é a única saída honesta:
      // um `skip` silencioso é como uma auditoria morre sem ninguém perceber,
      // e um `expect(existe, isTrue)` derrubaria o CI por um arquivo que ele
      // nunca teve.
      final backend = File('../functions-social/src/index.ts');
      if (!backend.existsSync()) {
        markTestSkipped(
          'functions-social/src/index.ts fora de alcance — o cruzamento '
          'cliente x backend NÃO foi verificado nesta execução',
        );
        return;
      }
      final ts = backend.readAsStringSync();
      final adaptador = _codigo(
        File('lib/amigos/transporte_social_firebase.dart'),
      );
      // OS NOMES SAEM DAS DECLARAÇÕES, e não de "toda string do arquivo".
      //
      // A primeira versão desta varredura pegava qualquer literal e reprovou
      // `'publicId'` — que é chave de PAYLOAD, não nome de callable. Uma
      // auditoria que acusa o inocente é desligada por quem se cansa dela, e aí
      // deixa de acusar o culpado também. As duas expressões abaixo leem
      // exatamente os dois lugares onde um nome de callable pode nascer: as
      // constantes `kCallable*` e os valores do mapa de ações.
      final nomes = <String>{
        for (final m in RegExp(
          r"kCallable\w+\s*=\s*'(\w+)'",
        ).allMatches(adaptador))
          m.group(1)!,
        for (final m in RegExp(
          r"AcaoSocial\.\w+:\s*'(\w+)'",
        ).allMatches(adaptador))
          m.group(1)!,
      };
      expect(
        nomes,
        hasLength(10),
        reason: 'o adaptador tem cinco leituras e cinco ações; a conta mudou',
      );
      // COM FRONTEIRA DE PALAVRA, e o motivo é uma mutação que passou.
      //
      // Escrito como `contains('export const $nome')`, renomear
      // `listarAmigos` para `listarAmigosRenomeada` no backend deixava esta
      // auditoria VERDE — o nome antigo continua sendo prefixo do novo, e o
      // cliente seguiria chamando uma função que não existe mais. Prefixo não
      // é identidade.
      final exportadas = RegExp(r'export const (\w+)\s*=')
          .allMatches(ts)
          .map((m) => m.group(1)!)
          .toSet();
      for (final nome in nomes) {
        expect(
          exportadas,
          contains(nome),
          reason: '`$nome` não é uma callable exportada por functions-social',
        );
      }
    });
  });
}
