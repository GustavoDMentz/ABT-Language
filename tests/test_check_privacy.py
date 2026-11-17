#!/usr/bin/env python3
"""Testes do verificador de privacidade (tools/check_privacy.py).

Os valores de teste são montados em tempo de execução: escritos por extenso, o próprio
verificador acusaria este arquivo.
"""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SCRIPT = RAIZ / "tools" / "check_privacy.py"
sys.path.insert(0, str(RAIZ / "tools"))
import check_privacy  # noqa: E402

CHAVE_AWS = "AK" + "IA" + "ABCDEFGHIJKLMNOP"
TOKEN_GH = "gh" + "p_" + "a1B2c3D4e5F6g7H8i9J0k1L2m3N4"
HOME_LINUX = "/ho" + "me/alguem/projeto"
CHAVE_PRIVADA = "-----BEGIN " + "RSA PRIVATE KEY-----"


class Padroes(unittest.TestCase):
    def rotulos(self, texto):
        return {r for r, _ in check_privacy.achados(texto)}

    def test_detecta_cada_tipo(self):
        self.assertIn("AWS access key", self.rotulos(f"chave = {CHAVE_AWS}"))
        self.assertIn("GitHub token", self.rotulos(f"token {TOKEN_GH}"))
        self.assertIn("Linux home", self.rotulos(f"em {HOME_LINUX}"))
        self.assertIn("Private key", self.rotulos(CHAVE_PRIVADA))

    def test_numero_da_linha(self):
        self.assertEqual(check_privacy.achados(f"a\nb\n{CHAVE_AWS}\n"), [("AWS access key", 3)])

    def test_texto_comum_e_exemplos_publicos_passam(self):
        self.assertEqual(check_privacy.achados("mostrar 1\nplano sk-curto\n/ho" + "me/runner/work"), [])


class Execucao(unittest.TestCase):
    def executar(self, pasta, *args):
        return subprocess.run([sys.executable, "-I", str(pasta / "tools" / "check_privacy.py"), *args],
                              capture_output=True, text=True, cwd=pasta)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.pasta = Path(self.tmp.name)
        (self.pasta / "tools").mkdir()
        shutil.copy2(SCRIPT, self.pasta / "tools" / "check_privacy.py")

    def test_fora_do_git_confere_a_arvore_e_nao_ignora_arquivo_nao_utf8(self):
        (self.pasta / "limpo.txt").write_text("nada aqui\n")
        r = self.executar(self.pasta)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        # Latin-1 (não UTF-8) com um segredo em ASCII: antes o arquivo era pulado em silêncio.
        (self.pasta / "dados.csv").write_bytes("caf\xe9;".encode("latin-1") + CHAVE_AWS.encode() + b"\n")
        r = self.executar(self.pasta)
        self.assertEqual(r.returncode, 1)
        self.assertIn("dados.csv:1: AWS access key", r.stdout)

    def test_historico_e_informativo_e_so_falha_com_estrito(self):
        def git(*a):
            subprocess.run(["git", *a], cwd=self.pasta, check=True, capture_output=True,
                           env={"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                                "GIT_COMMITTER_EMAIL": "t@t", "PATH": "/usr/bin:/bin", "HOME": str(self.pasta)})
        git("init", "-q")
        segredo = self.pasta / "x.txt"
        segredo.write_text(CHAVE_AWS + "\n")
        git("add", "x.txt")
        git("commit", "-q", "-m", "um")
        segredo.write_text("removido\n")
        git("add", "x.txt")
        git("commit", "-q", "-m", "dois")
        r = self.executar(self.pasta, "--historico")
        self.assertEqual(r.returncode, 0, r.stdout)  # a árvore atual está limpa
        self.assertIn("x.txt: AWS access key", r.stdout)
        self.assertIn("filter-repo", r.stdout)
        self.assertEqual(self.executar(self.pasta, "--historico", "--estrito").returncode, 1)

    def test_o_repositorio_passa_na_propria_verificacao(self):
        r = subprocess.run([sys.executable, "-I", str(SCRIPT)], capture_output=True, text=True, cwd=RAIZ)
        self.assertEqual(r.returncode, 0, r.stdout)


if __name__ == "__main__":
    unittest.main()
