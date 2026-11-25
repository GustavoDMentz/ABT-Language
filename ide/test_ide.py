"""Testes da IDE (sem precisar da ABT instalada): usam um `abt` de mentira."""
import json
import os
import re
import stat
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import abt_ide  # noqa: E402


def abt_falso(pasta, texto):
    """Cria um executável que imprime `texto`, num caminho com espaço (como C:\\Users\\Maria Silva)."""
    base = Path(pasta) / "pasta com espaco"
    base.mkdir()
    if os.name == "nt":
        caminho = base / "abt.cmd"
        caminho.write_bytes(f"@echo off\r\necho {texto}\r\n".encode())
    else:
        caminho = base / "abt"
        caminho.write_text(f"#!/bin/sh\necho {texto}\n")
        caminho.chmod(caminho.stat().st_mode | stat.S_IXUSR)
    return str(caminho)


class ComAbtFalso(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.antigo = os.environ.get("ABT_BIN")
        os.environ["ABT_BIN"] = abt_falso(self.tmp.name, "resultado-falso")
        self.addCleanup(self.restaurar)

    def restaurar(self):
        if self.antigo is None:
            os.environ.pop("ABT_BIN", None)
        else:
            os.environ["ABT_BIN"] = self.antigo


class Execucao(ComAbtFalso):
    def test_executa_e_devolve_saida(self):
        r = abt_ide.executar("mostrar 1\n", "run")
        self.assertEqual(r["codigo_saida"], 0, r)
        self.assertIn("resultado-falso", r["saida"])

    def test_verificar_tambem_funciona(self):
        self.assertEqual(abt_ide.executar("x = 1\n", "check")["codigo_saida"], 0)

    def test_abt_inexistente_nao_quebra(self):
        os.environ["ABT_BIN"] = str(Path(self.tmp.name) / "nao_existe")
        path_antigo = os.environ.get("PATH", "")
        self.addCleanup(os.environ.__setitem__, "PATH", path_antigo)
        os.environ["PATH"] = ""
        if abt_ide.achar_abt() is None:  # pode existir um abt na pasta padrão da instalação
            self.assertEqual(abt_ide.executar("x", "run")["codigo_saida"], 127)


class Exemplos(unittest.TestCase):
    def test_exemplos_numerados_com_titulo(self):
        ex = abt_ide.exemplos()
        self.assertGreaterEqual(len(ex), 13)
        for i, titulo in enumerate(ex, start=1):
            self.assertRegex(titulo, rf"^{i}\. \S")
        self.assertTrue(any("txt" in t for t in ex))

    def test_dados_citados_existem(self):
        for codigo in abt_ide.exemplos().values():
            for caminho in re.findall(r'"(dados/[^"]+)"', codigo):
                self.assertTrue((abt_ide.PASTA_EXEMPLOS / caminho).is_file(), caminho)


class Servidor(ComAbtFalso):
    def setUp(self):
        super().setUp()
        self.srv = ThreadingHTTPServer(("127.0.0.1", 0), abt_ide.Manipulador)
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        self.addCleanup(self.srv.server_close)
        self.addCleanup(self.srv.shutdown)
        self.base = f"http://127.0.0.1:{self.srv.server_port}"

    def pedir(self, caminho, corpo=None, cabecalhos=None):
        req = urllib.request.Request(self.base + caminho, data=corpo, headers=cabecalhos or {})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            return e.code, ""

    def test_pagina_e_execucao_com_token(self):
        status, html = self.pedir("/")
        self.assertEqual(status, 200)
        cfg = json.loads(re.search(r"const CFG = (.*?);\nconst KW", html, re.S).group(1).replace("<\\/", "</"))
        corpo = json.dumps({"codigo": "mostrar 1", "modo": "run"}).encode()
        status, texto = self.pedir("/api/executar", corpo, {"X-IDE-Token": cfg["token"]})
        self.assertEqual(status, 200)
        self.assertIn("resultado-falso", json.loads(texto)["saida"])

    def test_sem_token_e_recusado(self):
        status, _ = self.pedir("/api/executar", b'{"codigo": "mostrar 1"}')
        self.assertEqual(status, 403)

    def test_host_estranho_e_recusado(self):
        status, _ = self.pedir("/", None, {"Host": "evil.example"})
        self.assertEqual(status, 403)


if __name__ == "__main__":
    unittest.main()
