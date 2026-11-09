#!/usr/bin/env python3
"""End-to-end installer and installed CLI tests in an isolated HOME."""
import os
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
JULIA = os.environ.get("ABT_TEST_JULIA") or shutil.which("julia")
from install import FILES, LEGACY_FILES, digest


@unittest.skipUnless(JULIA, "set ABT_TEST_JULIA to a Julia 1.13.3 executable")
class InstalledCLI(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="abt install é ")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home é espaço"
        self.home.mkdir()
        self.env = {**os.environ, "HOME": str(self.home), "ABT_JULIA": str(JULIA)}
        self.env["PATH"] = str(self.home / ".local/bin") + os.pathsep + self.env.get("PATH", "")
        self.other = Path(self.tmp.name) / "outro diretório"
        self.other.mkdir()

    def call(self, *args, env=None, cwd=None):
        return subprocess.run(args, cwd=cwd or self.other, env=env or self.env,
                              capture_output=True, text=True, timeout=60)

    def install(self):
        result = self.call(sys.executable, str(ROOT / "install.py"))
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_install_reinstall_update_and_uninstall(self):
        self.install()
        link = self.home / ".local/bin/abt"
        self.assertTrue(link.is_symlink())
        self.install()
        self.assertEqual(self.call("abt", "--version").stdout.strip(), "ABT 0.11.8")
        installed = self.home / ".local/share/abt/src/CLI.jl"
        installed.write_text(installed.read_text() + "\n# user modification\n")
        blocked = self.call(sys.executable, str(ROOT / "install.py"))
        self.assertEqual(blocked.returncode, 2)
        self.assertIn("modificado", blocked.stderr)
        installed.write_bytes((ROOT / "src/CLI.jl").read_bytes())
        self.install()
        removed = self.call(sys.executable, str(ROOT / "uninstall.py"))
        self.assertEqual(removed.returncode, 0, removed.stderr)
        self.assertFalse(link.is_symlink())
        self.assertFalse((self.home / ".local/share/abt").exists())
        self.assertEqual(self.call(sys.executable, str(ROOT / "uninstall.py")).returncode, 0)

    def test_conflicts_preserved(self):
        link = self.home / ".local/bin/abt"
        link.parent.mkdir(parents=True)
        link.write_text("other program")
        result = self.call(sys.executable, str(ROOT / "install.py"))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(link.read_text(), "other program")
        link.unlink()
        target = self.home / ".local/share/abt"
        target.mkdir(parents=True)
        foreign = target / "foreign.txt"
        foreign.write_text("keep")
        result = self.call(sys.executable, str(ROOT / "install.py"))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(foreign.read_text(), "keep")

    def test_legacy_marker_can_be_upgraded(self):
        target = self.home / ".local/share/abt"
        hashes = {}
        for relative in LEGACY_FILES:
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)
            hashes[relative] = digest(destination)
        (target / ".abt-install.json").write_text(json.dumps({"application":"ABT", "schema":1, "files":hashes}))
        link = self.home / ".local/bin/abt"
        link.parent.mkdir(parents=True)
        link.symlink_to(target / "bin/abt")
        result = self.call(sys.executable, str(ROOT / "install.py"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((target / "src/ExtensionRegistry.jl").is_file())
        self.assertEqual(self.call("abt", "operacoes").returncode, 0)

    def test_vscode_tasks_use_installed_command(self):
        tasks = json.loads((ROOT / ".vscode/tasks.json").read_text())
        self.assertEqual(len(tasks["tasks"]), 2)
        for task in tasks["tasks"]:
            self.assertIn("$HOME/.local/bin/abt", task["args"][1])
            self.assertIn("ABT não instalado", task["args"][1])
            self.assertEqual(task["args"][-1], "${file}")

    def test_installed_commands_unicode_paths_and_errors(self):
        self.install()
        source = self.other / "olá mundo.abt"
        source.write_text('mostrar "Olá, mundo!"\n')
        for args in ((str(source),), ("run", str(source)), ("executar", str(source))):
            result = self.call("abt", *args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Olá, mundo!", result.stdout)
        for command in ("check", "verificar"):
            result = self.call("abt", command, str(source))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("válido", result.stdout)
        for command in ("--help", "--ajuda"):
            self.assertIn("abt run", self.call("abt", command).stdout)
        self.assertEqual(self.call("abt", "doctor").returncode, 0)
        catalog = self.call("abt", "operacoes")
        self.assertEqual(catalog.returncode, 0, catalog.stderr)
        self.assertIn("contar_categorias", catalog.stdout)
        extension = self.other / "sistema.abt"
        extension.write_text("mostrar resolver_sistema_spd([[2.0]], [4.0])\n")
        solved = self.call("abt", "run", str(extension))
        self.assertEqual(solved.returncode, 0, solved.stderr)
        match = re.search(r"solucao = \[([-+\d.e]+)\]", solved.stdout)
        self.assertIsNotNone(match, solved.stdout)
        self.assertAlmostEqual(float(match.group(1)), 2.0)
        self.assertEqual(self.call("abt", "run", "ausente.abt").returncode, 2)
        self.assertEqual(self.call("abt", "check", str(source), "extra").returncode, 2)
        self.assertEqual(self.call("abt", "run").returncode, 2)
        self.assertEqual(self.call("abt", "check").returncode, 2)
        self.assertEqual(self.call("abt", "--unknown").returncode, 2)
        invalid = self.other / "inválido.abt"
        invalid.write_text("mostrar (\n")
        self.assertEqual(self.call("abt", "run", str(invalid)).returncode, 1)
        self.assertIn("Detalhes técnicos", self.call("abt", "--depurar", "run", str(invalid)).stderr)
        legacy = self.call("abt", "run", str(ROOT / "examples/pipeline_basico.abt"))
        self.assertEqual(legacy.returncode, 0, legacy.stderr)
        self.assertIn("[30, 40]", legacy.stdout)

    def test_missing_and_incompatible_julia(self):
        self.install()
        missing = {**self.env, "ABT_JULIA": "/nonexistent/julia"}
        self.assertEqual(self.call("abt", "doctor", env=missing).returncode, 2)
        self.assertEqual(self.call("abt", "run", "x.abt", env=missing).returncode, 2)
        fake = self.other / "fake-julia"
        fake.write_text("#!/bin/sh\necho 'julia version 1.12.0'\n")
        fake.chmod(0o755)
        incompatible = {**self.env, "ABT_JULIA": str(fake)}
        result = self.call("abt", "doctor", env=incompatible)
        self.assertEqual(result.returncode, 2)
        self.assertIn("não homologada", result.stderr)

    def test_install_rejects_missing_julia_without_artifacts(self):
        absent = {**self.env, "ABT_JULIA": "/nonexistent/julia"}
        result = self.call(sys.executable, str(ROOT / "install.py"), env=absent)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Julia", result.stderr)
        self.assertFalse((self.home / ".local/share/abt").exists())
        self.assertFalse((self.home / ".local/bin/abt").exists())

    def test_install_rolls_back_when_precompile_fails(self):
        fake = self.other / "failing-julia"
        fake.write_text("#!/bin/sh\nif [ \"$1\" = --version ]; then echo 'julia version 1.13.3'; exit 0; fi\nexit 1\n")
        fake.chmod(0o755)
        result = self.call(sys.executable, str(ROOT / "install.py"),
                           env={**self.env, "ABT_JULIA": str(fake)})
        self.assertEqual(result.returncode, 2)
        self.assertIn("pré-compilação", result.stderr)
        self.assertFalse((self.home / ".local/share/abt").exists())
        self.assertFalse((self.home / ".local/bin/abt").is_symlink())

    def test_update_refreshes_package_manifest_cache(self):
        source_copy = self.other / "source copy"
        (source_copy / "src/Runtime").mkdir(parents=True)
        (source_copy / "bin").mkdir()
        for relative in ("install.py", *FILES):
            destination = source_copy / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)
        install = (sys.executable, str(source_copy / "install.py"))
        self.assertEqual(self.call(*install).returncode, 0)
        manifest = source_copy / "ABT.packages.toml"
        manifest.write_text(manifest.read_text().replace("year = 1", "month = 1"))
        self.assertEqual(self.call(*install).returncode, 0)
        project = self.home / ".local/share/abt"
        result = self.call(str(JULIA), "--startup-file=no", "--compile=min", f"--project={project}",
                           "-e", 'using ABT; print(sort(collect(keys(ABT.ABT_PACKAGES["Dates"].functions))))')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("month", result.stdout)
        self.assertNotIn("year", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
