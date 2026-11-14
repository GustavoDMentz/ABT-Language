#!/usr/bin/env python3
"""ABT 0.15.0 — perfis de execução da CLI.

1. Lógica do bin/abt (precedência, valores inválidos, compatibilidade) com um Julia falso que
   imprime os argumentos recebidos: verifica exatamente a flag --compile repassada.
2. Com o Julia real: os perfis não alteram saídas, erros nem códigos de saída.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "bin" / "abt"
JULIA = os.environ.get("ABT_JULIA") or shutil.which("julia")

FAKE = """#!/bin/sh
if [ "$1" = "--version" ]; then echo 'julia version 1.13.3'; exit 0; fi
for a in "$@"; do printf '%s\\n' "$a"; done
"""


class ProfileSelection(unittest.TestCase):
    """Sem Julia real: o que o bin/abt repassa ao runtime."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="abt-perfil-")
        self.addCleanup(self.tmp.cleanup)
        self.fake = Path(self.tmp.name) / "julia-falso"
        self.fake.write_text(FAKE)
        self.fake.chmod(0o755)

    def run_abt(self, *args, **env):
        environment = {k: v for k, v in os.environ.items() if k != "ABT_JULIA_COMPILE"}
        environment.update(ABT_JULIA=str(self.fake), **env)
        return subprocess.run([str(BIN), *args], env=environment, capture_output=True, text=True, timeout=30)

    def compile_flag(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        flags = [l for l in result.stdout.splitlines() if l.startswith("--compile=")]
        self.assertEqual(len(flags), 1, result.stdout)
        return flags[0].split("=", 1)[1], result.stdout.splitlines()

    def test_default_is_padrao_compile_yes(self):
        flag, lines = self.compile_flag(self.run_abt("run", "x.abt"))
        self.assertEqual(flag, "yes")
        self.assertEqual(lines[-2:], ["run", "x.abt"])

    def test_cli_profiles(self):
        self.assertEqual(self.compile_flag(self.run_abt("--perfil", "rapido", "run", "x.abt"))[0], "min")
        self.assertEqual(self.compile_flag(self.run_abt("--perfil=padrao", "run", "x.abt"))[0], "yes")
        # posição livre; a opção não chega à CLI Julia
        flag, lines = self.compile_flag(self.run_abt("run", "x.abt", "--perfil", "rapido"))
        self.assertEqual(flag, "min")
        self.assertEqual(lines[-2:], ["run", "x.abt"])
        self.assertNotIn("--perfil", lines)
        flag, lines = self.compile_flag(self.run_abt("--depurar", "--perfil=rapido", "run", "x.abt"))
        self.assertEqual(lines[-3:], ["--depurar", "run", "x.abt"])

    def test_environment_variable_is_still_supported(self):
        for mode in ("min", "yes", "all", "no"):
            self.assertEqual(self.compile_flag(self.run_abt("run", "x.abt", ABT_JULIA_COMPILE=mode))[0], mode)

    def test_cli_has_precedence_over_environment(self):
        self.assertEqual(self.compile_flag(self.run_abt("--perfil", "padrao", "run", "x.abt", ABT_JULIA_COMPILE="min"))[0], "yes")
        self.assertEqual(self.compile_flag(self.run_abt("--perfil", "rapido", "run", "x.abt", ABT_JULIA_COMPILE="all"))[0], "min")

    def test_invalid_values(self):
        for args, env, fragment in [
            (("--perfil", "turbo", "run", "x.abt"), {}, "perfil inválido: turbo"),
            (("--perfil=", "run", "x.abt"), {}, "perfil inválido"),
            (("run", "x.abt", "--perfil"), {}, "--perfil exige um valor"),
            (("run", "x.abt"), {"ABT_JULIA_COMPILE": "rapido"}, "ABT_JULIA_COMPILE deve ser min, yes, all ou no"),
        ]:
            result = self.run_abt(*args, **env)
            self.assertEqual(result.returncode, 2, (args, result.stdout))
            self.assertIn(fragment, result.stderr)
            self.assertEqual(result.stdout, "")
        # um perfil inválido é rejeitado mesmo que o ambiente seja válido
        self.assertEqual(self.run_abt("--perfil", "x", "run", "a.abt", ABT_JULIA_COMPILE="min").returncode, 2)

    def test_doctor_reports_effective_mode(self):
        result = self.run_abt("doctor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Compilação Julia: --compile=yes (origem: padrao)", result.stdout)
        result = self.run_abt("--perfil", "rapido", "doctor")
        self.assertIn("--compile=min (origem: cli)", result.stdout)
        result = self.run_abt("doctor", ABT_JULIA_COMPILE="all")
        self.assertIn("--compile=all (origem: ABT_JULIA_COMPILE)", result.stdout)


@unittest.skipUnless(JULIA, "Julia 1.13.3 necessária")
class ProfilesPreserveResults(unittest.TestCase):
    """Com Julia real: mesmas saídas, erros e códigos de saída em todos os perfis."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="abt-perfil-real-")
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def run_abt(self, *args, **env):
        environment = {k: v for k, v in os.environ.items() if k != "ABT_JULIA_COMPILE"}
        environment.update(ABT_JULIA=str(JULIA), **env)
        return subprocess.run([str(BIN), *args], cwd=ROOT, env=environment, capture_output=True, text=True, timeout=600)

    def same_everywhere(self, *args):
        reference = self.run_abt(*args)
        for variant in (("--perfil", "rapido"), ("--perfil", "padrao")):
            other = self.run_abt(*variant, *args)
            self.assertEqual((other.returncode, other.stdout, other.stderr), (reference.returncode, reference.stdout, reference.stderr), variant)
        legacy = self.run_abt(*args, ABT_JULIA_COMPILE="min")
        self.assertEqual((legacy.returncode, legacy.stdout, legacy.stderr), (reference.returncode, reference.stdout, reference.stderr))
        return reference

    def test_trivial_program(self):
        program = self.dir / "trivial.abt"; program.write_text("mostrar 1\n")
        result = self.same_everywhere("run", str(program))
        self.assertEqual((result.returncode, result.stdout), (0, "1\n"))

    def test_scientific_program(self):
        # Pequeno o bastante para o perfil rapido terminar em tempo razoável.
        program = self.dir / "bio.abt"
        program.write_text(
            'mostrar conteudo_gc("ATGCGTACGTAG")\n'
            'mostrar traduzir_quadro("ATGTGGTTTTAA", 1)\n'
            'mostrar alinhar_par("ACGTTTACGT", "ACGACGT", "global", pontuacao_dna(2, -1, -3, -1)).pontuacao\n'
            'l = ler_fastq("applications/scientific_0130/data/reads.fastq", "DNA", "rejeitar", "phred33")\n'
            'mostrar resumir_fastq(filtrar_fastq(l, 6, 35, 0))\n'
            'mostrar descrever([1, 2, 3, 4])\n')
        result = self.same_everywhere("run", str(program))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[:3], ["50.0", "MWF*", "8"])

    def test_errors_and_exit_codes(self):
        bad = self.dir / "erro.abt"; bad.write_text("mostrar x\n")
        result = self.same_everywhere("run", str(bad))
        self.assertEqual(result.returncode, 1)
        self.assertIn("ABT[E021]", result.stderr)
        missing = self.same_everywhere("run", str(self.dir / "ausente.abt"))
        self.assertEqual(missing.returncode, 2)
        check = self.same_everywhere("check", str(bad))
        self.assertEqual(check.returncode, 1)

    def test_informational_commands(self):
        self.assertEqual(self.same_everywhere("--version").stdout, "ABT 0.15.0\n")
        self.assertIn("--perfil NOME", self.same_everywhere("--help").stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
