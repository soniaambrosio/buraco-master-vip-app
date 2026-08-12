// teste_social.dart — o domínio de identidade pública e grafo social (OS §36).
//
// Só decisão pura: nada aqui sobe emulador nem toca Firestore. Os casos de
// AUTORIZAÇÃO (quem lê, quem escreve, o cliente consegue forjar amizade?) ficam
// em firebase/testes/social.test.js, porque quem os prova é a regra, não o Dart.
//
// A separação é a mesma que a OS de Moderação já estabeleceu, e a razão continua
// valendo: "o apelido tem 3 caracteres" e "o vizinho consegue ler este documento"
// são perguntas de naturezas diferentes, e a segunda não se responde sem
// emulador.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/social/amizade.dart';
import 'package:buraco_master_vip/social/apresentacao.dart';
import 'package:buraco_master_vip/social/erros_sociais.dart';
import 'package:buraco_master_vip/social/identidade_publica.dart';
import 'package:buraco_master_vip/social/listagem_social.dart';

const uidA = 'uidJogadorA';
const uidB = 'uidJogadorB';
const uidC = 'uidJogadorC';

/// Bytes determinísticos para a geração de id. Cada um cai num símbolo conhecido
/// do alfabeto, o que deixa o teste afirmar o ID INTEIRO em vez de só o formato.
List<int> bytes(int inicio) =>
    List<int>.generate(kComprimentoIdPublico, (i) => inicio + i);

EntradaSocial entrada(String publicId, String apelido) => EntradaSocial(
      publicId: publicId,
      apelido: apelido,
      avatarRef: null,
      desde: '2026-01-01T00:00:00.000Z',
    );

void main() {
  // ======================================================== IDENTIDADE (§36)
  group('IDN — identidade pública', () {
    test('IDN-01 geração produz o formato acordado com functions-ranking', () {
      final id = idPublicoDeBytes(bytes(0));
      expect(id.startsWith(kPrefixoIdPublico), isTrue);
      expect(id.length, kTamanhoTotalIdPublico);
      expect(idPublicoValido(id), isTrue);
      // Bytes 0..11 caem nos doze primeiros símbolos do alfabeto.
      expect(id, 'P0123456789AB');
    });

    test('IDN-02 bytes diferentes geram ids diferentes', () {
      expect(idPublicoDeBytes(bytes(0)), isNot(idPublicoDeBytes(bytes(5))));
      // E o oposto do mesmo fato, que é a razão de `% 32` não enviesar: bytes
      // separados por um múltiplo de 32 caem no MESMO símbolo. Isso é o
      // desenho, não defeito — cada símbolo do alfabeto recebe exatamente 8 dos
      // 256 valores de um byte, e é essa uniformidade que dá os 60 bits.
      expect(idPublicoDeBytes(bytes(0)), idPublicoDeBytes(bytes(32)));
    });

    test('IDN-03 os mesmos bytes geram o MESMO id (função pura)', () {
      expect(idPublicoDeBytes(bytes(7)), idPublicoDeBytes(bytes(7)));
    });

    test('IDN-04 bytes insuficientes são recusados, não completados', () {
      // Completar com zero produziria ids com cauda previsível — entropia menor
      // do que a anunciada, e sem ninguém perceber.
      expect(() => idPublicoDeBytes([1, 2, 3]), throwsArgumentError);
    });

    test('IDN-05 o id NÃO deriva do UID', () {
      // Dois jogadores diferentes com os MESMOS bytes recebem o mesmo id — o que
      // prova que o uid não entra na conta. E nenhum id contém o uid.
      final id = idPublicoDeBytes(bytes(3));
      expect(pareceDerivadoDoUid(id, uidA), isFalse);
      expect(pareceDerivadoDoUid(id, uidB), isFalse);
      expect(pareceDerivadoDoUid('P${uidA.toUpperCase()}', uidA), isTrue,
          reason: 'o detector precisa pegar o derivado óbvio, senão não prova nada');
    });

    test('IDN-06 o alfabeto não tem I, L, O nem U', () {
      for (final proibido in ['I', 'L', 'O', 'U']) {
        expect(kAlfabetoIdPublico.contains(proibido), isFalse,
            reason: '$proibido é ambíguo na leitura ou indesejado');
      }
    });

    test('IDN-07 normalização aceita minúscula, hífen e espaço', () {
      final id = idPublicoDeBytes(bytes(0)); // P0123456789AB
      expect(normalizarIdPublico(id.toLowerCase()), id);
      expect(normalizarIdPublico('p0123-456789-ab'), id);
      expect(normalizarIdPublico('  p0123 456789 ab  '), id);
    });

    test('IDN-08 normalização repara I/L/O digitados no lugar de 1/0', () {
      // "P0123456789AB" digitado com O no lugar do zero.
      expect(normalizarIdPublico('PO123456789AB'), 'P0123456789AB');
      expect(normalizarIdPublico('PI123456789AB'), 'P1123456789AB');
      expect(normalizarIdPublico('PL123456789AB'), 'P1123456789AB');
    });

    test('IDN-09 normalização recusa o que não é id, sem chutar', () {
      expect(normalizarIdPublico(null), isNull);
      expect(normalizarIdPublico(''), isNull);
      expect(normalizarIdPublico('P0123456789A'), isNull, reason: 'curto');
      expect(normalizarIdPublico('P0123456789ABC'), isNull, reason: 'longo');
      expect(normalizarIdPublico('X0123456789AB'), isNull, reason: 'prefixo');
      expect(normalizarIdPublico('P0123456789AU'), isNull,
          reason: 'U não pertence ao alfabeto e não tem reparo');
      expect(normalizarIdPublico(42), isNull);
    });

    test('IDN-10 consulta pública: inválido, inexistente e indisponível', () {
      final id = idPublicoDeBytes(bytes(0));
      expect(
        recusaDeConsultaPublica(
            idBruto: 'lixo', existe: true, estado: EstadoPerfilPublico.ativo),
        ErroSocial.perfilPublicoInvalido,
      );
      expect(
        recusaDeConsultaPublica(
            idBruto: id, existe: false, estado: EstadoPerfilPublico.ativo),
        ErroSocial.perfilPublicoNaoDisponivel,
      );
      expect(
        recusaDeConsultaPublica(
            idBruto: id,
            existe: true,
            estado: EstadoPerfilPublico.indisponivel),
        ErroSocial.perfilPublicoNaoDisponivel,
        reason: 'conta removida responde igual a conta inexistente (§31-G)',
      );
      expect(
        recusaDeConsultaPublica(
            idBruto: id, existe: true, estado: EstadoPerfilPublico.ativo),
        isNull,
      );
    });

    test('IDN-11 estado desconhecido no documento é tratado como indisponível',
        () {
      // Um estado que este código não entende pode ser "banido". Expor por
      // desconhecimento é o pior desfecho possível.
      expect(EstadoPerfilPublico.porNome('bloqueadoPorSancaoFutura'),
          EstadoPerfilPublico.indisponivel);
      expect(EstadoPerfilPublico.porNome(null),
          EstadoPerfilPublico.indisponivel);
    });
  });

  // ============================================================ APELIDO (§7)
  group('APE — apelido', () {
    test('APE-01 trim nas bordas', () {
      expect(normalizarApelido('   Dona Maria   '), 'Dona Maria');
    });

    test('APE-02 espaços consecutivos colapsam', () {
      expect(normalizarApelido('Dona     Maria'), 'Dona Maria');
      expect(normalizarApelido('Dona\t\tMaria'), 'Dona Maria');
    });

    test('APE-03 mínimo de 3 caracteres visíveis', () {
      expect(recusaDeApelido(normalizarApelido('ab')),
          ErroSocial.apelidoInvalido);
      expect(recusaDeApelido(normalizarApelido('  a  ')),
          ErroSocial.apelidoInvalido);
      expect(recusaDeApelido(normalizarApelido('abc')), isNull);
    });

    test('APE-04 máximo de 24 caracteres visíveis', () {
      expect(recusaDeApelido('a' * kApelidoMaximo), isNull);
      expect(recusaDeApelido('a' * (kApelidoMaximo + 1)),
          ErroSocial.apelidoInvalido);
    });

    test('APE-05 acento e Unicode normal são aceitos', () {
      for (final nome in ['Ávila', 'João', 'Söhne', 'Иван', '山田太郎', 'Ana 🌸']) {
        expect(recusaDeApelido(normalizarApelido(nome)), isNull,
            reason: '$nome é apelido legítimo');
      }
    });

    test('APE-05b o piso de 3 pega nomes CJK curtos — limitação registrada', () {
      // 花子 ("Hanako") tem DUAS runas e é um nome próprio completo em japonês.
      // O piso de 3 de §7 o recusa. Fica assim porque a faixa é a que a OS
      // especifica, e afrouxar por conta própria mexeria numa política de nomes;
      // o teste existe para que a limitação seja um FATO CONHECIDO e não uma
      // descoberta de suporte. Ver a seção de lacunas do contrato.
      expect(recusaDeApelido('花子'), ErroSocial.apelidoInvalido);
      expect(comprimentoVisivel('花子'), 2);
    });

    test('APE-06 emoji conta como UM caractere visível', () {
      // Se o limite fosse por `String.length`, este apelido teria 26 unidades
      // UTF-16 e seria recusado por um limite que o jogador não vê.
      final comEmoji = '${'a' * 22}🌸';
      expect(comprimentoVisivel(comEmoji), 23);
      expect(recusaDeApelido(comEmoji), isNull);
    });

    test('APE-07 string vazia é recusada', () {
      expect(recusaDeApelido(''), ErroSocial.apelidoInvalido);
      expect(recusaDeApelido(normalizarApelido('     ')),
          ErroSocial.apelidoInvalido);
    });

    test('APE-08 caracteres de controle e invisiveis sao recusados', () {
      // As strings sao MONTADAS a partir do ponto de codigo, e nao coladas no
      // arquivo. Um invisivel literal no fonte e indistinguivel de um erro de
      // edicao: qualquer ferramenta que "limpe" a linha apagaria justamente o
      // que o teste existe para provar, e ele continuaria passando.
      //
      // Cada faixa tem um abuso concreto atras dela — ver _caractereProibido em
      // apresentacao.dart.
      const proibidos = <int, String>{
        0x00: 'NUL',
        0x07: 'BEL',
        0x0A: 'quebra de linha, que destroi qualquer lista',
        0x1F: 'controle C0',
        0x7F: 'DEL',
        0x85: 'controle C1',
        0x200B: 'zero-width space — impersonacao',
        0x200D: 'zero-width joiner',
        0x200E: 'marca direcional',
        0x202E: 'override bidirecional, desenha o texto ao contrario',
        0x2060: 'word joiner',
        0x2066: 'isolamento direcional',
        0xFEFF: 'BOM no meio do texto',
      };
      proibidos.forEach((codigo, porque) {
        final apelido = 'Ana${String.fromCharCode(codigo)}Bia';
        expect(recusaDeApelido(normalizarApelido(apelido)),
            ErroSocial.apelidoInvalido,
            reason: 'U+${codigo.toRadixString(16).toUpperCase()}: $porque');
      });
    });

    test('APE-09 o espaco comum continua permitido', () {
      // A contrapartida de APE-08: proibir invisivel nao pode virar proibir
      // espaco. "Dona Maria" e apelido legitimo, e o que se faz com o espaco
      // duplicado e colapsar, nao recusar.
      expect(recusaDeApelido(normalizarApelido('Dona Maria')), isNull);
      expect(recusaDeApelido(normalizarApelido('Dona   Maria')), isNull);
      expect(normalizarApelido('Dona   Maria'), 'Dona Maria');
    });

    test('APE-10 apelido NÃO precisa ser único (§7)', () {
      // Duas pessoas com o mesmo apelido são aceitas; quem desempata é o
      // publicId. Nada no domínio consulta unicidade.
      expect(recusaDeApelido('Maria'), isNull);
      expect(recusaDeApelido('Maria'), isNull);
    });

    test('APE-11 chave de ordenação dobra acento e caixa', () {
      expect(chaveDeOrdenacao('Ávila'), 'avila');
      expect(chaveDeOrdenacao('ÁVILA'), 'avila');
      expect(chaveDeOrdenacao('João'), 'joao');
      // A prova de que serve: sem a dobra, "Ávila" cairia depois de "Zeca".
      final ordenado = ['Zeca', 'Ávila', 'Bia']
        ..sort((a, b) => chaveDeOrdenacao(a).compareTo(chaveDeOrdenacao(b)));
      expect(ordenado, ['Ávila', 'Bia', 'Zeca']);
    });

    test('APE-12 alterar apelido NÃO altera o publicId', () {
      final id = idPublicoDeBytes(bytes(0));
      final antes = PerfilPublico(
        publicId: id,
        apelido: 'Maria',
        avatarRef: null,
        estado: EstadoPerfilPublico.ativo,
        criadoEm: '2026-01-01T00:00:00.000Z',
        atualizadoEm: '2026-01-01T00:00:00.000Z',
      );
      final v = avaliarAtualizacaoDeApresentacao(
        apelidoBruto: 'Maria das Dores',
        agoraIso: '2026-02-01T00:00:00.000Z',
      );
      expect(v.aceita, isTrue);
      // A chave decisiva: o mapa de alteração NÃO PODE conter publicId.
      expect(v.campos!.containsKey('publicId'), isFalse);
      expect(v.campos!['apelido'], 'Maria das Dores');
      expect(antes.publicId, id);
    });
  });

  // ============================================================= AVATAR (§8)
  group('AVA — avatar', () {
    test('AVA-01 referência válida é aceita', () {
      expect(recusaDeAvatar('coruja_dourada'), isNull);
      expect(recusaDeAvatar('av-01'), isNull);
    });

    test('AVA-02 ausência é tratada, não é erro', () {
      expect(recusaDeAvatar(null), isNull);
    });

    test('AVA-03 payload arbitrário é recusado', () {
      for (final lixo in [
        'https://exemplo.com/eu.png',
        '<img src=x onerror=alert(1)>',
        '../../etc/passwd',
        'assets/perfil/vitrine_avatar.webp',
        'data:image/png;base64,AAAA',
        'a', // curto demais
        'A_MAIUSCULA',
        'com espaco',
        '',
      ]) {
        expect(recusaDeAvatar(lixo), ErroSocial.avatarInvalido,
            reason: '"$lixo" não pode virar referência de avatar');
      }
      expect(recusaDeAvatar(42), ErroSocial.avatarInvalido);
      expect(recusaDeAvatar(<String, String>{}), ErroSocial.avatarInvalido);
    });

    test('AVA-04 quando houver catálogo, ele passa a mandar', () {
      // Hoje kCatalogoAvatares é vazio e a validação é só de formato — §8 manda
      // documentar essa ausência. Este teste prova que o dia do catálogo já está
      // ligado: preencher a constante basta.
      const catalogo = {'coruja_dourada', 'jacare_verde'};
      expect(recusaDeAvatar('coruja_dourada', catalogo: catalogo), isNull);
      expect(recusaDeAvatar('inventado', catalogo: catalogo),
          ErroSocial.avatarInvalido);
      expect(recusaDeAvatar('inventado'), isNull,
          reason: 'sem catálogo, só o formato manda');
    });

    test('AVA-05 remover avatar exige pedido explícito', () {
      // `avatarRef: null` é indistinguível de "não mexi nisso" e apagaria o
      // avatar de quem só quis trocar de nome.
      final soNome = avaliarAtualizacaoDeApresentacao(
          apelidoBruto: 'Bia', agoraIso: 'agora');
      expect(soNome.campos!.containsKey('avatarRef'), isFalse);

      final remove = avaliarAtualizacaoDeApresentacao(
          removerAvatar: true, agoraIso: 'agora');
      expect(remove.aceita, isTrue);
      expect(remove.campos!['avatarRef'], isNull);
      expect(remove.campos!.containsKey('avatarRef'), isTrue);
    });

    test('AVA-06 pedido vazio é recusado, não é sucesso silencioso', () {
      expect(avaliarAtualizacaoDeApresentacao(agoraIso: 'agora').aceita, isFalse);
    });
  });

  // =============================================== DOCUMENTO PÚBLICO (§5, §31-F)
  group('PUB — o documento público só tem informação pública', () {
    final perfil = PerfilPublico(
      publicId: idPublicoDeBytes(bytes(0)),
      apelido: 'Maria',
      avatarRef: 'coruja_dourada',
      estado: EstadoPerfilPublico.ativo,
      criadoEm: '2026-01-01T00:00:00.000Z',
      atualizadoEm: '2026-01-01T00:00:00.000Z',
    );

    test('PUB-01 a serialização tem exatamente os campos permitidos', () {
      expect(perfil.toJson().keys.toSet(), camposPublicos);
    });

    test('PUB-02 não há UID nem e-mail no documento público', () {
      final json = perfil.toJson();
      for (final proibido in camposProibidosNoPublico) {
        expect(json.containsKey(proibido), isFalse,
            reason: '$proibido não pode existir num documento legível por todos');
      }
    });

    test('PUB-03 a trava recusa campo privado que encoste no documento', () {
      final contaminado = {...perfil.toJson(), 'email': 'a@b.c', 'uid': uidA};
      final ofensivas = conferirDocumentoPublico(contaminado);
      expect(ofensivas, containsAll(['email', 'uid']));
      expect(ofensivas.every(camposProibidosNoPublico.contains), isTrue);
    });

    test('PUB-04 a trava recusa até campo inocente não declarado', () {
      // A regra principal é a lista de PERMITIDOS. Um campo novo tem que ser
      // decidido, não deduzido.
      expect(conferirDocumentoPublico({...perfil.toJson(), 'humor': 'feliz'}),
          ['humor']);
      expect(conferirDocumentoPublico(perfil.toJson()), isEmpty);
    });

    test('PUB-05 releitura preserva a identidade e recusa id corrompido', () {
      final relido = PerfilPublico.deJson(perfil.toJson());
      expect(relido.publicId, perfil.publicId);
      expect(relido.apelido, 'Maria');
      expect(relido.estado, EstadoPerfilPublico.ativo);
      expect(() => PerfilPublico.deJson({'publicId': 'quebrado'}),
          throwsFormatException);
    });

    test('PUB-06 o UID não é usado como fallback de apelido (§31-F)', () {
      // Perfil sem apelido: a apresentação fica VAZIA, e a tela mostra o
      // publicId. Cair no uid aqui publicaria a identidade interna.
      final semNome = PerfilPublico.deJson({'publicId': perfil.publicId});
      expect(semNome.apelido, '');
      expect(semNome.toJson().values.contains(uidA), isFalse);
    });
  });

  // ======================================================== SOLICITAÇÃO (§13)
  group('SOL — solicitação de amizade', () {
    VereditoAmizade pedir({
      String de = uidA,
      String para = uidB,
      EstadoAmizade estado = EstadoAmizade.nenhuma,
      String? pendenteDe,
      bool contato = true,
      int amigosDoSolicitante = 0,
      int amigosDoDestinatario = 0,
      int pendentes = 0,
    }) =>
        avaliarSolicitacao(
          solicitanteUid: de,
          destinatarioUid: para,
          estadoAtual: estado,
          solicitantePendenteUid: pendenteDe,
          contatoPermitido: contato,
          amigosDoSolicitante: amigosDoSolicitante,
          amigosDoDestinatario: amigosDoDestinatario,
          pendentesEnviadasDoSolicitante: pendentes,
        );

    test('SOL-01 A→B funciona', () {
      final v = pedir();
      expect(v.aceita, isTrue);
      expect(v.acao, AcaoAmizade.criarSolicitacao);
    });

    test('SOL-02 A→A falha', () {
      expect(pedir(para: uidA).recusa, ErroSocial.autoAmizadeInvalida);
    });

    test('SOL-03 duplicidade no mesmo sentido NÃO duplica e responde sucesso',
        () {
      final v = pedir(estado: EstadoAmizade.pendente, pendenteDe: uidA);
      expect(v.aceita, isFalse);
      expect(v.repeticao, isTrue, reason: 'quem chama responde sucesso');
      expect(v.recusa, ErroSocial.solicitacaoJaExiste);
      expect(v.acao, AcaoAmizade.nenhuma, reason: 'nada é escrito');
    });

    test('SOL-04 já amigos é recusado', () {
      expect(pedir(estado: EstadoAmizade.amigos).recusa, ErroSocial.jaSaoAmigos);
    });

    test('SOL-05 bloqueio em qualquer sentido impede', () {
      // O domínio recebe UM booleano porque `avaliarContato` (moderação) já
      // dobrou os dois sentidos — e responde o MESMO código nos dois casos, para
      // não contar quem bloqueou quem.
      final v = pedir(contato: false);
      expect(v.recusa, ErroSocial.relacaoBloqueada);
    });

    test('SOL-06 bloqueio vence até quando já existe amizade', () {
      expect(pedir(estado: EstadoAmizade.amigos, contato: false).recusa,
          ErroSocial.relacaoBloqueada,
          reason: 'a resposta não pode nem confirmar que existe relação');
    });

    test('SOL-07 limite de amigos do solicitante trava', () {
      expect(pedir(amigosDoSolicitante: kLimiteAmigos).recusa,
          ErroSocial.limiteAmigos);
      expect(pedir(amigosDoSolicitante: kLimiteAmigos - 1).aceita, isTrue);
    });

    test('SOL-08 limite de pendentes enviadas trava', () {
      expect(pedir(pendentes: kLimiteSolicitacoesEnviadas).recusa,
          ErroSocial.limiteSolicitacoes);
      expect(pedir(pendentes: kLimiteSolicitacoesEnviadas - 1).aceita, isTrue);
    });

    test('SOL-09 a lotação do DESTINATÁRIO não trava o pedido comum', () {
      // Recusar aqui contaria ao solicitante quantos amigos o alvo tem. A
      // lotação do alvo é conferida no ACEITE, por quem é dono dela.
      expect(pedir(amigosDoDestinatario: kLimiteAmigos).aceita, isTrue);
    });

    test('SOL-10 §27: pedido cruzado vira aceite determinístico', () {
      // A pede a B enquanto B já pediu a A. Sem esta regra, os dois veriam
      // "solicitação enviada" e nenhum veria o botão de aceitar.
      final v = pedir(estado: EstadoAmizade.pendente, pendenteDe: uidB);
      expect(v.aceita, isTrue);
      expect(v.acao, AcaoAmizade.aceitarInversa);
    });

    test('SOL-11 §27: o aceite cruzado respeita a lotação dos DOIS', () {
      expect(
        pedir(
          estado: EstadoAmizade.pendente,
          pendenteDe: uidB,
          amigosDoDestinatario: kLimiteAmigos,
        ).recusa,
        ErroSocial.limiteAmigos,
      );
    });

    test('SOL-12 identificador inválido é recusado', () {
      expect(pedir(de: '').recusa, ErroSocial.identificadorInvalido);
      expect(pedir(para: 'com|barra').recusa, ErroSocial.identificadorInvalido);
    });
  });

  // ============================================================= ACEITE (§14)
  group('ACE — aceite', () {
    VereditoAmizade aceitar({
      String quem = uidB,
      EstadoAmizade estado = EstadoAmizade.pendente,
      String? destinatario = uidB,
      bool contato = true,
      int amigosDeQuemAceita = 0,
      int amigosDoOutro = 0,
    }) =>
        avaliarAceite(
          uidQueAceita: quem,
          estadoAtual: estado,
          destinatarioPendenteUid: destinatario,
          contatoPermitido: contato,
          amigosDeQuemAceita: amigosDeQuemAceita,
          amigosDoOutro: amigosDoOutro,
        );

    test('ACE-01 somente o destinatário aceita', () {
      expect(aceitar().aceita, isTrue);
      expect(aceitar(quem: uidA).recusa, ErroSocial.naoEDestinatario,
          reason: 'o remetente fechando a própria amizade é adicionar sem permissão');
      expect(aceitar(quem: uidC).recusa, ErroSocial.naoEDestinatario);
    });

    test('ACE-02 aceitar duas vezes é idempotente e responde sucesso', () {
      final v = aceitar(estado: EstadoAmizade.amigos);
      expect(v.repeticao, isTrue);
      expect(v.acao, AcaoAmizade.nenhuma);
      expect(v.recusa, ErroSocial.jaSaoAmigos);
    });

    test('ACE-03 aceitar o que não existe é recusado', () {
      expect(aceitar(estado: EstadoAmizade.nenhuma).recusa,
          ErroSocial.solicitacaoNaoEncontrada);
    });

    test('ACE-04 §27: bloqueio prevalece sobre o aceite', () {
      // "A aceita enquanto B bloqueia A — não pode terminar em amizade ativa
      // contra um bloqueio confirmado."
      expect(aceitar(contato: false).recusa, ErroSocial.relacaoBloqueada);
      expect(aceitar(contato: false, estado: EstadoAmizade.amigos).recusa,
          ErroSocial.relacaoBloqueada);
    });

    test('ACE-05 limite de amigos vale para os dois lados', () {
      expect(aceitar(amigosDeQuemAceita: kLimiteAmigos).recusa,
          ErroSocial.limiteAmigos);
      expect(aceitar(amigosDoOutro: kLimiteAmigos).recusa,
          ErroSocial.limiteAmigos);
    });
  });

  // ============================================ RECUSA E CANCELAMENTO (§15, §16)
  group('REC — recusa e cancelamento', () {
    test('REC-01 somente o destinatário recusa', () {
      expect(
        avaliarRecusa(
          uidQueRecusa: uidB,
          estadoAtual: EstadoAmizade.pendente,
          destinatarioPendenteUid: uidB,
        ).acao,
        AcaoAmizade.apagar,
      );
      expect(
        avaliarRecusa(
          uidQueRecusa: uidA,
          estadoAtual: EstadoAmizade.pendente,
          destinatarioPendenteUid: uidB,
        ).recusa,
        ErroSocial.naoEDestinatario,
      );
    });

    test('REC-02 recusar duas vezes é seguro', () {
      final v = avaliarRecusa(
        uidQueRecusa: uidB,
        estadoAtual: EstadoAmizade.nenhuma,
      );
      expect(v.repeticao, isTrue);
      expect(v.acao, AcaoAmizade.nenhuma);
    });

    test('REC-03 recusar NÃO desfaz amizade existente', () {
      // Sem esta linha, "recusar" viraria um atalho para remover amigo.
      final v = avaliarRecusa(
        uidQueRecusa: uidB,
        estadoAtual: EstadoAmizade.amigos,
        destinatarioPendenteUid: uidB,
      );
      expect(v.aceita, isFalse);
      expect(v.repeticao, isFalse);
      expect(v.acao, AcaoAmizade.nenhuma);
    });

    test('REC-04 recusar não cria amizade e não bloqueia ninguém', () {
      final v = avaliarRecusa(
        uidQueRecusa: uidB,
        estadoAtual: EstadoAmizade.pendente,
        destinatarioPendenteUid: uidB,
      );
      // A única ação é apagar. Não existe caminho no domínio que transforme
      // recusa em bloqueio — §15.
      expect(v.acao, AcaoAmizade.apagar);
      expect(AcaoAmizade.values.contains(AcaoAmizade.apagar), isTrue);
    });

    test('REC-05 somente o remetente cancela', () {
      expect(
        avaliarCancelamento(
          uidQueCancela: uidA,
          estadoAtual: EstadoAmizade.pendente,
          solicitantePendenteUid: uidA,
        ).acao,
        AcaoAmizade.apagar,
      );
      expect(
        avaliarCancelamento(
          uidQueCancela: uidB,
          estadoAtual: EstadoAmizade.pendente,
          solicitantePendenteUid: uidA,
        ).recusa,
        ErroSocial.naoERemetente,
        reason: 'o destinatário recusa; cancelar em nome do remetente é outra coisa',
      );
    });

    test('REC-06 cancelar duas vezes é seguro', () {
      expect(
        avaliarCancelamento(
          uidQueCancela: uidA,
          estadoAtual: EstadoAmizade.nenhuma,
        ).repeticao,
        isTrue,
      );
    });
  });

  // =========================================================== REMOÇÃO (§17)
  group('REM — remoção de amizade', () {
    test('REM-01 qualquer um dos dois remove', () {
      for (final quem in [uidA, uidB]) {
        final v = avaliarRemocao(
          uidQueRemove: quem,
          estadoAtual: EstadoAmizade.amigos,
          ehMembro: true,
        );
        expect(v.acao, AcaoAmizade.apagar, reason: '$quem deve poder remover');
      }
    });

    test('REM-02 remover duas vezes é seguro', () {
      final v = avaliarRemocao(
        uidQueRemove: uidA,
        estadoAtual: EstadoAmizade.nenhuma,
        ehMembro: true,
      );
      expect(v.repeticao, isTrue);
      expect(v.acao, AcaoAmizade.nenhuma);
    });

    test('REM-03 remover NÃO apaga solicitação pendente por engano', () {
      final v = avaliarRemocao(
        uidQueRemove: uidA,
        estadoAtual: EstadoAmizade.pendente,
        ehMembro: true,
      );
      expect(v.acao, AcaoAmizade.nenhuma,
          reason: 'a pós-condição "não são amigos" já vale; nada é escrito');
    });

    test('REM-04 ninguém desfaz amizade alheia', () {
      expect(
        avaliarRemocao(
          uidQueRemove: uidC,
          estadoAtual: EstadoAmizade.amigos,
          ehMembro: false,
        ).recusa,
        ErroSocial.naoEDestinatario,
      );
    });
  });

  // ============================================================== PAR (§20)
  group('PAR — a chave canônica do par', () {
    test('PAR-01 A-B e B-A produzem a MESMA chave', () {
      expect(chaveDoPar(uidA, uidB), chaveDoPar(uidB, uidA));
    });

    test('PAR-02 pares diferentes produzem chaves diferentes', () {
      expect(chaveDoPar(uidA, uidB), isNot(chaveDoPar(uidA, uidC)));
    });

    test('PAR-03 não existe par de um jogador consigo', () {
      expect(() => chaveDoPar(uidA, uidA), throwsArgumentError);
    });

    test('PAR-04 identificador que quebraria a chave é recusado', () {
      // `|` dentro de um componente partiria a chave em dois e deixaria dois
      // pares diferentes colidirem.
      expect(() => chaveDoPar('a|b', uidB), throwsArgumentError);
      expect(() => chaveDoPar('', uidB), throwsArgumentError);
    });

    test('PAR-05 membros saem ordenados e a relação sabe quem é o outro', () {
      final r = RelacaoAmizade.nenhuma(uidB, uidA);
      expect(r.membros, [uidA, uidB]);
      expect(r.outroMembro(uidA), uidB);
      expect(r.outroMembro(uidB), uidA);
      expect(r.contem(uidC), isFalse);
      expect(r.estado, EstadoAmizade.nenhuma);
    });

    test('PAR-06 releitura do documento canônico preserva o estado', () {
      final r = RelacaoAmizade(
        pairKey: chaveDoPar(uidA, uidB),
        membros: membrosOrdenados(uidA, uidB),
        estado: EstadoAmizade.amigos,
        solicitanteUid: uidA,
        destinatarioUid: uidB,
        solicitadaEm: '2026-01-01T00:00:00.000Z',
        amigosDesde: '2026-01-02T00:00:00.000Z',
        publicIds: {uidA: 'P0123456789AB', uidB: 'PCDEFGHJKMNPQ'},
      );
      final relido = RelacaoAmizade.deJson(r.toJson());
      expect(relido.estado, EstadoAmizade.amigos);
      expect(relido.pairKey, r.pairKey);
      expect(relido.publicIds[uidB], 'PCDEFGHJKMNPQ');
      expect(relido.amigosDesde, '2026-01-02T00:00:00.000Z');
    });

    test('PAR-07 estado desconhecido num documento vira "nenhuma"', () {
      expect(EstadoAmizade.porNome('bloqueada'), EstadoAmizade.nenhuma,
          reason: 'não existe estado bloqueada: o bloqueio é do outro domínio');
    });
  });

  // ======================================================= VER PERFIL (§31-A/B)
  group('VER — ver perfil de outro jogador', () {
    RelacaoVista vista({
      String observador = uidA,
      String alvo = uidB,
      EstadoAmizade estado = EstadoAmizade.nenhuma,
      String? solicitante,
      bool euBloqueei = false,
      bool contato = true,
    }) =>
        vistaDaRelacao(
          uidObservador: observador,
          uidAlvo: alvo,
          estado: estado,
          solicitanteUid: solicitante,
          euBloqueeiOAlvo: euBloqueei,
          contatoPermitido: contato,
        );

    test('VER-01 sem relação: pode adicionar', () {
      final v = vista();
      expect(v, RelacaoVista.nenhuma);
      expect(acoesDisponiveis(v), {AcaoSocial.adicionarAmigo, AcaoSocial.bloquear});
    });

    test('VER-02 solicitação enviada: pode cancelar, não aceitar', () {
      final v = vista(estado: EstadoAmizade.pendente, solicitante: uidA);
      expect(v, RelacaoVista.solicitacaoEnviada);
      expect(acoesDisponiveis(v), contains(AcaoSocial.cancelarSolicitacao));
      expect(acoesDisponiveis(v), isNot(contains(AcaoSocial.aceitarSolicitacao)));
    });

    test('VER-03 solicitação recebida: pode aceitar e recusar', () {
      final v = vista(estado: EstadoAmizade.pendente, solicitante: uidB);
      expect(v, RelacaoVista.solicitacaoRecebida);
      expect(acoesDisponiveis(v), containsAll([
        AcaoSocial.aceitarSolicitacao,
        AcaoSocial.recusarSolicitacao,
      ]));
      expect(acoesDisponiveis(v), isNot(contains(AcaoSocial.cancelarSolicitacao)));
    });

    test('VER-04 amigos: pode remover', () {
      final v = vista(estado: EstadoAmizade.amigos);
      expect(v, RelacaoVista.amigos);
      expect(acoesDisponiveis(v), contains(AcaoSocial.removerAmigo));
      expect(acoesDisponiveis(v), isNot(contains(AcaoSocial.adicionarAmigo)));
    });

    test('VER-05 bloqueado por mim: só desbloquear', () {
      final v = vista(euBloqueei: true, contato: false);
      expect(v, RelacaoVista.bloqueadoPorMim);
      expect(acoesDisponiveis(v), {AcaoSocial.desbloquear});
    });

    test('VER-06 bloqueio do OUTRO lado não se distingue de indisponível', () {
      // §31-B: nada de "Fulano bloqueou você". O cliente sabe que não pode
      // interagir; não sabe por quê.
      final bloqueadoPeloOutro = vista(contato: false);
      expect(bloqueadoPeloOutro, RelacaoVista.indisponivel);
      expect(acoesDisponiveis(bloqueadoPeloOutro), isEmpty,
          reason: 'até o botão de bloquear seria informação');
    });

    test('VER-07 bloqueio prevalece sobre amizade ainda não desfeita', () {
      // A janela entre "bloqueei agora" e "o gatilho de faxina já rodou".
      expect(vista(estado: EstadoAmizade.amigos, euBloqueei: true, contato: false),
          RelacaoVista.bloqueadoPorMim);
      expect(vista(estado: EstadoAmizade.amigos, contato: false),
          RelacaoVista.indisponivel);
    });

    test('VER-08 perfil próprio é reconhecido e não oferece ação social', () {
      final v = vista(observador: uidA, alvo: uidA);
      expect(v, RelacaoVista.euMesmo);
      expect(acoesDisponiveis(v), {AcaoSocial.editarPerfil});
    });

    test('VER-09 mute NÃO aparece na vista (§19)', () {
      // Não há parâmetro de mute em `vistaDaRelacao`, e é isso que garante que
      // silenciar alguém não mude o grafo. Este teste existe para que
      // acrescentar um parâmetro desses quebre alguma coisa.
      final amigoSilenciado = vista(estado: EstadoAmizade.amigos);
      expect(amigoSilenciado, RelacaoVista.amigos);
      expect(acoesDisponiveis(amigoSilenciado), contains(AcaoSocial.removerAmigo));
    });
  });

  // ============================================================= LISTA (§22)
  group('LST — listagem e paginação', () {
    final todos = [
      entrada('P0000000000AB', 'Zeca'),
      entrada('P0000000000CD', 'Ávila'),
      entrada('P0000000000EF', 'bia'),
      entrada('P0000000000GH', 'Bia'),
      entrada('P0000000000JK', 'Carlos'),
    ];

    test('LST-01 ordena por apelido normalizado, publicId desempata', () {
      final p = paginarAmigos(todos, limite: 10);
      expect(p.itens.map((e) => e.apelido).toList(),
          ['Ávila', 'bia', 'Bia', 'Carlos', 'Zeca']);
      // "bia" e "Bia" empatam no apelido; o publicId decide, e a ordem é estável.
      expect(p.itens[1].publicId, 'P0000000000EF');
      expect(p.itens[2].publicId, 'P0000000000GH');
    });

    test('LST-02 paginação percorre a lista inteira sem repetir nem pular', () {
      final vistos = <String>[];
      String? cursor;
      var voltas = 0;
      do {
        final p = paginarAmigos(todos, cursor: cursor, limite: 2);
        vistos.addAll(p.itens.map((e) => e.publicId));
        cursor = p.proximoCursor;
        voltas++;
      } while (cursor != null && voltas < 10);

      expect(vistos.length, todos.length);
      expect(vistos.toSet().length, todos.length, reason: 'sem repetição');
      expect(voltas, 3, reason: '5 itens em páginas de 2');
    });

    test('LST-03 a última página não devolve cursor', () {
      final p = paginarAmigos(todos, limite: 10);
      expect(p.proximoCursor, isNull);
      expect(p.total, 5);
    });

    test('LST-04 lista vazia é página vazia, não erro', () {
      final p = paginarAmigos(const [], limite: 10);
      expect(p.itens, isEmpty);
      expect(p.proximoCursor, isNull);
      expect(p.total, 0);
    });

    test('LST-05 nenhuma entrada carrega UID ou e-mail', () {
      final json = paginarAmigos(todos, limite: 10).toJson();
      final itens = json['itens']! as List;
      for (final item in itens) {
        final m = item as Map<String, Object?>;
        expect(m.keys.toSet(), {'publicId', 'apelido', 'avatarRef', 'desde'});
        for (final proibido in ['uid', 'userId', 'email']) {
          expect(m.containsKey(proibido), isFalse);
        }
      }
    });

    test('LST-06 o tamanho de página tem teto', () {
      expect(tamanhoDePagina(null), kPaginaPadrao);
      expect(tamanhoDePagina(0), kPaginaPadrao);
      expect(tamanhoDePagina(-5), kPaginaPadrao);
      expect(tamanhoDePagina(10), 10);
      expect(tamanhoDePagina(100000), kPaginaMaxima,
          reason: '"paginado" não pode virar "uma página só"');
    });

    test('LST-07 o teto de amigos cabe numa lista carregada de uma vez', () {
      // A premissa que sustenta a ordenação em memória (ver o cabeçalho de
      // listagem_social.dart). Se alguém subir kLimiteAmigos, este teste avisa.
      expect(kLimiteAmigos, lessThanOrEqualTo(1000));
      final muitos = List.generate(
          kLimiteAmigos, (i) => entrada('P${i.toString().padLeft(12, '0')}', 'Jogador $i'));
      final p = paginarAmigos(muitos, limite: kPaginaMaxima);
      expect(p.total, kLimiteAmigos);
      expect(p.itens.length, kPaginaMaxima);
    });

    test('LST-08 não há teto de solicitações recebidas (§25, anti-DoS)', () {
      expect(kLimiteSolicitacoesRecebidas, isNull,
          reason: 'um teto aqui trancaria a vítima fora do sistema para sempre');
    });
  });

  // ========================================================== CÓDIGOS (§35)
  group('ERR — códigos de domínio estáveis', () {
    test('ERR-01 todo código exigido pela OS existe', () {
      final nomes = ErroSocial.values.map((e) => e.name).toSet();
      expect(
        nomes,
        containsAll([
          'identidadeNaoEncontrada',
          'autoAmizadeInvalida',
          'jaSaoAmigos',
          'solicitacaoJaExiste',
          'solicitacaoNaoEncontrada',
          'naoEDestinatario',
          'relacaoBloqueada',
          'limiteAmigos',
          'limiteSolicitacoes',
          'perfilPublicoInvalido',
        ]),
      );
    });

    test('ERR-02 o esquema dos documentos sociais está declarado', () {
      expect(kEsquemaSocial, 1);
    });
  });
}
