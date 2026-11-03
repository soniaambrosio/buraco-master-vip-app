#!/usr/bin/env python3
"""validar_endpoint_servidor.py — portão do endereço do servidor no pipeline.

O endereço é lido da variável de ambiente BMV_SERVIDOR_URL (nunca de argumento),
e julgado com a política de RELEASE de `app/lib/services/endpoint_servidor.dart`
(`EndpointServidor.validar(..., perfil: PerfilDeBuild.release)`).

REGRA DE ALINHAMENTO (é ela que o modo --vetores confere):

  1. Tudo que o app recusa, este portão recusa. Um AAB que o portão aprova
     nunca nasce com o online morto por endereço.
  2. Este portão recusa A MAIS só formas de host que o app não interpreta de
     modo canônico e que podem ser apelido de máquina local (número IPv4 fora da
     forma a.b.c.d, ponto final, IPv6 mapeando 127/8, `.localhost`) ou sintaxe
     malformada (espaço, não-ASCII, `%` no host, porta fora de 0–65535, `@`
     vazio). Cada recusa a mais está listada nos vetores com app=aceita ou
     app=indeterminado.

Uso:
  BMV_SERVIDOR_URL=... python3 -I tools/ci/validar_endpoint_servidor.py
  python3 -I tools/ci/validar_endpoint_servidor.py --vetores <arquivo.json>

Saída 0 = aceito (imprime a forma normalizada); 1 = recusado ou divergência.
"""

import ipaddress
import json
import os
import re
import sys
from urllib.parse import urlsplit


class Recusa(Exception):
    """Endereço recusado. `extra` marca recusa que o app não faria."""

    def __init__(self, motivo, extra=False):
        super().__init__(motivo)
        self.motivo = motivo
        self.extra = extra


# Espelho de EndpointServidor._hostsLocais.
_HOSTS_LOCAIS = {
    "localhost", "127.0.0.1", "0.0.0.0", "::1", "::", "10.0.2.2", "10.0.3.2",
}

_ROTULO = r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
_NOME_DNS = re.compile(rf"^(?=.{{1,253}}$){_ROTULO}(?:\.{_ROTULO})*$")
_ESQUEMA = re.compile(r"^([A-Za-z][A-Za-z0-9+.-]*):")


def _ipv4_canonico(host):
    """a.b.c.d com 4 octetos decimais 0–255, sem zero à esquerda; senão None."""
    partes = host.split(".")
    if len(partes) != 4:
        return None
    for p in partes:
        if not p.isdigit() or (len(p) > 1 and p[0] == "0") or int(p) > 255:
            return None
    return ipaddress.IPv4Address(host)


def _ipv4_e_local(ip):
    # Espelho do app: 127.0.0.0/8 inteiro, 0.0.0.0 e os atalhos de emulador.
    return ip in ipaddress.IPv4Network("127.0.0.0/8") or str(ip) in _HOSTS_LOCAIS


def validar(bruto):
    """Devolve a URL normalizada (como o app a devolveria) ou lança Recusa."""
    texto = bruto.strip()
    if not texto:
        raise Recusa("o endereço do servidor não foi configurado neste build")

    # Sintaxe que o app talvez interprete de outro jeito: recusa a mais.
    if any(c.isspace() for c in texto):
        raise Recusa("o endereço tem espaço no meio", extra=True)
    if not texto.isascii():
        raise Recusa("o endereço tem caractere não-ASCII", extra=True)

    # Credencial e parâmetros: o app recusa em todo perfil. '?' e '#' em
    # qualquer posição abrem query/fragmento (vazios inclusive).
    if "?" in texto:
        raise Recusa("o endereço do servidor não pode carregar parâmetros")
    if "#" in texto:
        raise Recusa("o endereço do servidor não pode carregar parâmetros")

    m = _ESQUEMA.match(texto)
    if not m:
        raise Recusa("o endereço do servidor precisa começar com wss://")
    esquema = m.group(1).lower()
    resto = texto[m.end():]
    if not resto.startswith("//"):
        raise Recusa("o endereço do servidor precisa começar com wss://")

    try:
        partes = urlsplit(texto)
    except ValueError:
        raise Recusa("o endereço do servidor é inválido")

    autoridade = partes.netloc
    if "@" in autoridade:
        usuario = autoridade.rsplit("@", 1)[0]
        if usuario:
            raise Recusa("o endereço do servidor não pode carregar usuário ou senha")
        raise Recusa("o endereço tem '@' sem usuário", extra=True)

    # Esquema: só os seguros, como no release do app.
    if esquema not in ("wss", "https"):
        if esquema in ("ws", "http"):
            raise Recusa("o endereço do servidor precisa usar wss:// (conexão cifrada)")
        raise Recusa("o endereço do servidor precisa começar com wss://")

    try:
        porta = partes.port
    except ValueError:
        # O app recusa porta não numérica; a faixa > 65535 fica como extra.
        porta_texto = autoridade.rsplit(":", 1)[-1]
        raise Recusa("porta inválida", extra=porta_texto.isdigit())

    if autoridade.startswith("["):
        if not re.match(r"^\[[^\]]*\](?::\d*)?$", autoridade):
            raise Recusa("o endereço do servidor é inválido")
        literal = autoridade[1:autoridade.index("]")]
        if "%" in literal:
            raise Recusa("IPv6 com zona não é endereço público", extra=True)
        try:
            ip6 = ipaddress.IPv6Address(literal)
        except ValueError:
            raise Recusa("o endereço do servidor é inválido")
        if literal.lower() in _HOSTS_LOCAIS:
            # O app compara o TEXTO do host com '::1' e '::'.
            raise Recusa(
                "este build está apontando para um servidor local, que não existe "
                "fora da máquina de desenvolvimento"
            )
        mapeado = ip6.ipv4_mapped
        if mapeado is not None and _ipv4_e_local(mapeado):
            raise Recusa("IPv6 que mapeia endereço local", extra=True)
        if ip6.is_loopback or ip6.is_unspecified:
            raise Recusa("IPv6 local escrito por extenso", extra=True)
        host_saida = "[" + ip6.compressed + "]"
    else:
        host = (partes.hostname or "")
        if not host:
            raise Recusa("o endereço do servidor não tem host")
        if "%" in host:
            raise Recusa("host com escape '%'", extra=True)
        # Espelho direto do app ANTES das recusas extras: assim a mensagem do
        # caso que o app também recusa é a mesma do app.
        if host in _HOSTS_LOCAIS or host.endswith(".local"):
            raise Recusa(
                "este build está apontando para um servidor local, que não existe "
                "fora da máquina de desenvolvimento"
            )
        partes_ip = host.split(".")
        if len(partes_ip) == 4 and partes_ip[0] == "127" and all(
            p.isdigit() and int(p) <= 255 for p in partes_ip
        ):
            raise Recusa(
                "este build está apontando para um servidor local, que não existe "
                "fora da máquina de desenvolvimento"
            )
        if host.endswith("."):
            raise Recusa("host com ponto final (apelido de nome local)", extra=True)
        if not _NOME_DNS.match(host):
            raise Recusa("host fora da forma de nome DNS", extra=True)
        if host.split(".")[-1].isdigit():
            ip4 = _ipv4_canonico(host)
            if ip4 is None:
                raise Recusa("IPv4 fora da forma a.b.c.d", extra=True)
        if host == "localhost" or host.endswith(".localhost"):
            raise Recusa("domínio .localhost resolve para a própria máquina", extra=True)
        host_saida = host

    # Normalização do app: https→wss; porta padrão do https (443) some, porque
    # o Uri do Dart a torna implícita; caminho "/" vira vazio.
    esquema_final = "wss"
    if porta is not None and not (esquema == "https" and porta == 443):
        host_saida += ":" + str(porta)
    caminho = partes.path
    if caminho == "/":
        caminho = ""
    return esquema_final + "://" + host_saida + caminho


def _rodar_vetores(caminho):
    with open(caminho, encoding="utf-8") as f:
        vetores = json.load(f)["vetores"]
    falhas = 0
    for v in vetores:
        url, app, portao = v["url"], v["app"], v["portao"]
        try:
            saida, obtido, extra = validar(url), "aceita", False
        except Recusa as r:
            saida, obtido, extra = r.motivo, "recusa", r.extra
        problemas = []
        if obtido != portao:
            problemas.append(f"portão {obtido}, esperado {portao}")
        # Invariante 1: o portão nunca aceita o que o app recusa ou o que não
        # se sabe se o app aceita.
        if obtido == "aceita" and app != "aceita":
            problemas.append(f"portão ACEITA o que o app registra como {app}")
        # Invariante 2: recusa só do portão tem de ser declarada como extra.
        if obtido == "recusa" and app == "aceita" and not extra:
            problemas.append("recusa a mais sem a marca de extra")
        if obtido == "recusa" and app == "recusa" and extra:
            problemas.append("recusa marcada como extra, mas o app também recusa")
        if obtido == "aceita" and v.get("normalizado") and saida != v["normalizado"]:
            problemas.append(f"normalizado {saida!r}, esperado {v['normalizado']!r}")
        estado = "OK" if not problemas else "DIVERGE"
        falhas += bool(problemas)
        print(f"{estado}\t{json.dumps(url)}\tapp={app}\tportao={obtido}\t{saida}"
              + ("\t" + "; ".join(problemas) if problemas else ""))
    print(f"vetores: {len(vetores)} · divergências: {falhas}")
    return 1 if falhas else 0


def main(argv):
    if len(argv) == 3 and argv[1] == "--vetores":
        return _rodar_vetores(argv[2])
    if len(argv) != 1:
        print("uso: BMV_SERVIDOR_URL=... validar_endpoint_servidor.py "
              "| validar_endpoint_servidor.py --vetores <arquivo.json>", file=sys.stderr)
        return 2
    try:
        normalizado = validar(os.environ.get("BMV_SERVIDOR_URL", ""))
    except Recusa as r:
        print("ERRO: " + r.motivo + (" [recusa do portão, a mais que o app]" if r.extra else ""))
        print("Cadastre ou corrija a variável de repositório BMV_SERVIDOR_URL "
              "(Settings > Secrets and variables > Actions > Variables).")
        return 1
    print("endereço do servidor validado para este build: " + normalizado)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
