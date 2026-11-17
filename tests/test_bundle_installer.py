#!/usr/bin/env python3
"""Testes do instalador integrado (tools/instalar.sh) e do launcher com Julia embutida.

Usam um pacote falso: a "Julia" é um script de shell que responde a --version, simula a
pré-compilação e executa `mostrar 1`. Isso cobre a lógica do instalador (integridade,
troca atômica, rollback, link, atualização, reparo, desinstalação) sem baixar 1,7 GB.
O teste com a Julia real fica em tools/construir_bundle.sh + o workflow de release.
"""
import hashlib
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parent.parent
INSTALADOR = ROOT / "tools" / "instalar.sh"
LAUNCHER = ROOT / "bin" / "abt"

FALSE_JULIA = """#!/bin/sh
# Julia falsa para testes.
case "$1" in --version) echo 'julia version 1.13.3'; exit 0 ;; esac
[ -n "${FAKE_LOG:-}" ] && printf 'depot=%s offline=%s\\n' "${JULIA_DEPOT_PATH:-}" "${JULIA_PKG_OFFLINE:-}" >>"$FAKE_LOG"
for a in "$@"; do
  if [ "$a" = "-e" ]; then
    [ -z "${FAKE_PRECOMPILE_FAIL:-}" ] || { echo 'falha simulada' >&2; exit 1; }
    mkdir -p "$JULIA_DEPOT_PATH/compiled"; exit 0
  fi
done
while [ "$#" -gt 0 ]; do
  if [ "$1" = run ]; then shift; [ "$(cat "$1")" = 'mostrar 1' ] && echo 1; exit 0; fi
  shift
done
exit 0
"""


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def construir_pacote(destino, versao, *, com_julia=True):
    """Cria abt-<versao>-linux-x86_64.tar.xz (+ .sha256) com a estrutura do pacote real."""
    base = Path(destino) / f"montagem-{versao}"
    pasta = base / "abt"
    for relativo in ("bin", "src", "libexec", "runtime/julia/bin", "depot/packages", "depot/artifacts"):
        (pasta / relativo).mkdir(parents=True, exist_ok=True)
    shutil.copy2(LAUNCHER, pasta / "bin" / "abt")
    shutil.copy2(INSTALADOR, pasta / "libexec" / "instalar.sh")
    for nome in ("CLI.jl", "ABT.jl"):
        (pasta / "src" / nome).write_text("# falso\n")
    for nome in ("Project.toml", "Manifest.toml", "ABT.packages.toml"):
        (pasta / nome).write_text(f'name = "ABT"\nversion = "{versao}"\n' if nome == "Project.toml" else f'# {versao}\n')
    julia = pasta / "runtime/julia/bin/julia"
    julia.write_text(FALSE_JULIA if com_julia else "#!/bin/sh\necho 'julia version 9.9.9'\n")
    julia.chmod(0o755)
    nome = f"abt-{versao}-linux-x86_64.tar.xz"
    pacote = Path(destino) / nome
    subprocess.run(["tar", "-C", str(base), "-cJf", str(pacote), "abt"], check=True)
    (Path(destino) / f"{nome}.sha256").write_text(f"{sha256(pacote)}  {nome}\n")
    return pacote


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="abt instalador é ")
        self.addCleanup(self.tmp.cleanup)
        self.t = Path(self.tmp.name)
        self.home = self.t / "home"
        self.home.mkdir()
        self.prefixo = self.home / "instalação abt"
        self.bin = self.home / "bin"
        self.pacotes = self.t / "pacotes"
        self.pacotes.mkdir()
        self.env = {"HOME": str(self.home), "PATH": "/usr/bin:/bin", "TMPDIR": str(self.t)}
        self.log = self.t / "fake.log"
        self.env["FAKE_LOG"] = str(self.log)

    def instalador(self, *args, env=None, script=None):
        return subprocess.run(["sh", str(script or INSTALADOR), *args], capture_output=True, text=True,
                              env={**self.env, **(env or {})}, timeout=120)

    def instalar(self, pacote, *args, env=None):
        return self.instalador("--arquivo", str(pacote), "--prefixo", str(self.prefixo), "--bin", str(self.bin),
                               *args, env=env)

    def abt(self, *args, env=None):
        return subprocess.run([str(self.bin / "abt"), *args], capture_output=True, text=True,
                              env={**self.env, **(env or {})}, timeout=60)

    def sobras(self):
        return [p.name for p in self.prefixo.parent.iterdir() if ".tmp." in p.name or ".antiga." in p.name]

    def marcador(self):
        return (self.prefixo / ".abt-install.json").read_text()


class Instalacao(Base):
    def test_instala_e_executa_com_julia_embutida(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        r = self.instalar(pacote)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.bin / "abt").is_symlink())
        self.assertEqual(os.readlink(self.bin / "abt"), str(self.prefixo / "bin/abt"))
        self.assertIn('"schema": 2', self.marcador())
        self.assertIn('"versao": "0.15.0"', self.marcador())
        self.assertEqual((self.prefixo / ".abt-prefixo").read_text().strip(), str(self.prefixo))
        self.assertTrue((self.prefixo / "depot/compiled").is_dir())
        self.assertEqual(self.sobras(), [])
        programa = self.t / "p.abt"
        programa.write_text("mostrar 1\n")
        r = self.abt("run", str(programa))
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "1"), r.stderr)
        self.assertIn(f"depot={self.prefixo}/depot offline=true", self.log.read_text())
        r = self.abt("doctor")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("embutida", r.stdout)

    def test_abt_julia_explicita_tem_prioridade(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        self.assertEqual(self.instalar(pacote, "--versao", "0.15.0").returncode, 0)
        externa = self.t / "julia-externa"
        externa.write_text(FALSE_JULIA)
        externa.chmod(0o755)
        r = self.abt("doctor", env={"ABT_JULIA": str(externa)})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("externa", r.stdout)

    def test_soma_errada_nao_instala_nada(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        r = self.instalar(pacote, "--sha256", "0" * 64)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("SHA-256", r.stderr)
        self.assertFalse(self.prefixo.exists())
        self.assertFalse((self.bin / "abt").exists())
        self.assertEqual(self.sobras(), [])

    def test_pacote_sem_soma_exige_confirmacao_explicita(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        solto = self.t / "sem-soma"
        solto.mkdir()
        copia = shutil.copy2(pacote, solto)  # sem o .sha256 ao lado
        r = self.instalar(copia)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("sem soma SHA-256", r.stderr)
        self.assertFalse(self.prefixo.exists())
        r = self.instalar(copia, "--sem-verificacao")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("SEM verificação", r.stderr)

    def test_recusa_prefixo_perigoso(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        for prefixo in ("/", "/usr", "/tmp", "/etc/", "/raso", str(self.home), str(self.home) + "/"):
            r = self.instalar(pacote, "--prefixo", prefixo)
            self.assertNotEqual(r.returncode, 0, prefixo)
            self.assertRegex(r.stderr, "pasta do sistema|pessoal|raso", prefixo)
        r = self.instalar(pacote, "--prefixo", str(self.home) + "/com\nquebra")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("caracteres de controle", r.stderr)

    def test_trava_impede_duas_instalacoes_no_mesmo_prefixo(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        trava = Path(str(self.prefixo) + ".trava")
        trava.mkdir()
        r = self.instalar(pacote)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("outra instalação", r.stderr)
        self.assertTrue(trava.is_dir(), "a trava de outra instalação não pode ser removida")
        self.assertFalse(self.prefixo.exists())
        trava.rmdir()
        self.assertEqual(self.instalar(pacote).returncode, 0)
        self.assertFalse(trava.exists(), "a trava própria é removida ao terminar")

    def test_pacote_com_caminho_fora_da_pasta_e_recusado(self):
        import tarfile
        nome = "abt-0.15.0-linux-x86_64.tar.xz"
        pasta = self.t / "malicioso"
        pasta.mkdir()
        pacote = pasta / nome
        with tarfile.open(pacote, "w:xz") as tar:
            dado = self.t / "x.txt"
            dado.write_text("x")
            tar.add(dado, arcname="abt/../fugiu.txt")
        (pasta / f"{nome}.sha256").write_text(f"{sha256(pacote)}  {nome}\n")
        r = self.instalar(pacote)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("caminho suspeito", r.stderr)
        self.assertFalse(self.prefixo.exists())
        self.assertFalse((self.t / "fugiu.txt").exists())

    def test_recusa_endereco_que_nao_seja_https(self):
        for base in ("http://exemplo.invalid/releases", "ftp://exemplo.invalid/releases", "http://127.0.0.1.exemplo.invalid/x"):
            r = self.instalador("--prefixo", str(self.prefixo), "--bin", str(self.bin), env={"ABT_BASE_URL": base})
            self.assertNotEqual(r.returncode, 0, base)
            self.assertIn("use https://", r.stderr, base)
            self.assertFalse(self.prefixo.exists(), base)

    def test_atestacao_exige_gh_ou_pacote_baixado(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        r = self.instalar(pacote, "--verificar-atestacao")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("só vale para pacotes baixados", r.stderr)
        self.assertFalse(self.prefixo.exists())

    def test_pacote_sem_a_julia_esperada_e_recusado(self):
        pacote = construir_pacote(self.pacotes, "0.15.0", com_julia=False)
        r = self.instalar(pacote)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Julia esperada", r.stderr)
        self.assertFalse(self.prefixo.exists())

    def test_falha_na_precompilacao_desfaz_tudo(self):
        pacote = construir_pacote(self.pacotes, "0.15.0")
        r = self.instalar(pacote, env={"FAKE_PRECOMPILE_FAIL": "1"})
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(self.prefixo.exists())
        self.assertFalse((self.bin / "abt").exists())
        self.assertEqual(self.sobras(), [])

    def test_prefixo_sem_marcador_nao_e_tocado(self):
        self.prefixo.mkdir()
        (self.prefixo / "meu-arquivo").write_text("importante")
        r = self.instalar(construir_pacote(self.pacotes, "0.15.0"))
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual((self.prefixo / "meu-arquivo").read_text(), "importante")
        self.assertFalse((self.bin / "abt").exists())

    def test_instalacao_antiga_do_install_py_e_recusada_com_instrucao(self):
        self.prefixo.mkdir()
        (self.prefixo / ".abt-install.json").write_text('{"application": "ABT", "schema": 1, "files": {}}\n')
        r = self.instalar(construir_pacote(self.pacotes, "0.15.0"))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("uninstall.py", r.stderr)
        self.assertIn('"schema": 1', self.marcador())

    def test_comando_existente_de_outra_origem_nao_e_sobrescrito(self):
        self.bin.mkdir()
        (self.bin / "abt").write_text("outro programa")
        r = self.instalar(construir_pacote(self.pacotes, "0.15.0"))
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual((self.bin / "abt").read_text(), "outro programa")
        self.assertFalse(self.prefixo.exists())

    def test_reinstalar_substitui_e_falha_restaura_a_anterior(self):
        antiga = construir_pacote(self.pacotes, "0.15.0")
        self.assertEqual(self.instalar(antiga, "--versao", "0.15.0").returncode, 0)
        nova = construir_pacote(self.pacotes, "0.16.0")
        r = self.instalar(nova, "--versao", "0.16.0", env={"FAKE_PRECOMPILE_FAIL": "1"})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('"versao": "0.15.0"', self.marcador())
        self.assertTrue((self.bin / "abt").is_symlink())
        self.assertEqual(self.sobras(), [])
        r = self.instalar(nova, "--versao", "0.16.0")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"versao": "0.16.0"', self.marcador())
        self.assertEqual(self.sobras(), [])


class Manutencao(Base):
    def instalado(self, versao="0.15.0"):
        r = self.instalar(construir_pacote(self.pacotes, versao), "--versao", versao)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_desinstalar_remove_so_a_abt(self):
        self.instalado()
        outro = self.home / ".julia"
        outro.mkdir()
        r = self.abt("desinstalar", "--sim")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.prefixo.exists())
        self.assertFalse((self.bin / "abt").exists())
        self.assertTrue(outro.is_dir())
        r = self.instalador("--desinstalar", "--sim", "--prefixo", str(self.prefixo), "--bin", str(self.bin))
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_desinstalar_sem_confirmacao_cancela(self):
        self.instalado()
        r = self.instalador("--desinstalar", "--prefixo", str(self.prefixo), "--bin", str(self.bin))
        self.assertEqual(r.returncode, 0)
        self.assertTrue(self.prefixo.is_dir())

    def test_desinstalar_recusa_pasta_sem_marcador(self):
        self.prefixo.mkdir()
        (self.prefixo / "x").write_text("x")
        r = self.instalador("--desinstalar", "--sim", "--prefixo", str(self.prefixo), "--bin", str(self.bin))
        self.assertNotEqual(r.returncode, 0)
        self.assertTrue((self.prefixo / "x").exists())

    def test_instalacao_movida_avisa_e_reparar_corrige(self):
        self.instalado()
        novo = self.home / "novo lugar"
        shutil.move(self.prefixo, novo)
        programa = self.t / "p.abt"
        programa.write_text("mostrar 1\n")
        r = subprocess.run([str(novo / "bin/abt"), "run", str(programa)], capture_output=True, text=True,
                           env=self.env, timeout=60)
        self.assertIn("abt reparar", r.stderr)
        r = subprocess.run([str(novo / "bin/abt"), "reparar"], capture_output=True, text=True,
                           env=self.env, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((novo / ".abt-prefixo").read_text().strip(), str(novo))
        r = subprocess.run([str(novo / "bin/abt"), "run", str(programa)], capture_output=True, text=True,
                           env=self.env, timeout=60)
        self.assertEqual(r.stderr, "")
        self.assertEqual(r.stdout.strip(), "1")
        # O link antigo ficou órfão ao mover a pasta; reparar o reaponta.
        self.assertEqual(os.readlink(self.bin / "abt"), str(novo / "bin/abt"))
        r = subprocess.run([str(novo / "bin/abt"), "desinstalar", "--sim"], capture_output=True, text=True,
                           env=self.env, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.lexists(self.bin / "abt"))

    def test_comandos_de_manutencao_exigem_instalacao_integrada(self):
        externa = self.t / "julia-externa"
        externa.write_text(FALSE_JULIA)
        externa.chmod(0o755)
        for comando in ("atualizar", "reparar", "desinstalar"):
            r = subprocess.run([str(LAUNCHER), comando], capture_output=True, text=True,
                               env={**self.env, "ABT_JULIA": str(externa)}, timeout=30)
            self.assertEqual(r.returncode, 2, comando)
            self.assertIn("instalação integrada", r.stderr)


class Atualizacao(Base):
    def setUp(self):
        super().setUp()
        self.servidor = self.t / "servidor"
        for versao in ("0.15.0", "0.16.0"):
            pasta = self.servidor / "download" / f"v{versao}"
            pasta.mkdir(parents=True)
            pacote = construir_pacote(self.pacotes, versao)
            shutil.copy2(pacote, pasta)
            shutil.copy2(f"{pacote}.sha256", pasta)
        (self.servidor / "latest" / "download").mkdir(parents=True)
        self.publicar("0.15.0")
        diretorio = str(self.servidor)

        class Handler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *a, **k):
                super().__init__(*a, directory=diretorio, **k)

            def log_message(self, *a):
                pass

        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.addCleanup(self.httpd.server_close)
        self.addCleanup(self.httpd.shutdown)
        self.env["ABT_BASE_URL"] = f"http://127.0.0.1:{self.httpd.server_address[1]}"

    def publicar(self, versao):
        (self.servidor / "latest" / "download" / "VERSION").write_text(versao + "\n")

    def test_manutencao_nao_deixa_copia_temporaria(self):
        self.assertEqual(self.instalador("--prefixo", str(self.prefixo), "--bin", str(self.bin)).returncode, 0)
        self.assertEqual(self.abt("atualizar").returncode, 0)
        self.assertEqual([p.name for p in self.t.iterdir() if p.name.startswith("abt-instalar.")], [])

    def test_instala_da_rede_e_atualiza(self):
        r = self.instalador("--prefixo", str(self.prefixo), "--bin", str(self.bin))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"versao": "0.15.0"', self.marcador())
        r = self.abt("atualizar")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("já é a versão mais recente", r.stdout)
        self.publicar("0.16.0")
        r = self.abt("atualizar")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"versao": "0.16.0"', self.marcador())
        self.assertEqual(self.sobras(), [])
        self.assertEqual(self.abt("doctor").returncode, 0)

    def test_pacote_corrompido_no_servidor_e_recusado(self):
        pacote = self.servidor / "download" / "v0.15.0" / "abt-0.15.0-linux-x86_64.tar.xz"
        pacote.write_bytes(pacote.read_bytes() + b"lixo")
        r = self.instalador("--prefixo", str(self.prefixo), "--bin", str(self.bin))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("SHA-256", r.stderr)
        self.assertFalse(self.prefixo.exists())


if __name__ == "__main__":
    unittest.main()
