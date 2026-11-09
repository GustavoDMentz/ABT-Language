#!/usr/bin/env python3
"""CLI semantics across Julia compilation modes and repeated processes."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import shutil
import signal
import statistics
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
JULIA = os.environ.get("ABT_TEST_JULIA") or shutil.which("julia")


@unittest.skipUnless(JULIA, "set ABT_TEST_JULIA to Julia 1.13.3")
class CompileModeSemantics(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="abt perf α ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {**os.environ, "ABT_JULIA": str(JULIA)}

    def call(self, path, mode="min", *prefix):
        return subprocess.run([str(ROOT / "bin/abt"), *prefix, str(path)],
                              env={**self.env, "ABT_JULIA_COMPILE": mode},
                              capture_output=True, text=True, timeout=60)

    def test_modes_match_success_and_failure(self):
        samples = [ROOT / "benchmarks/scenarios/ola.abt", ROOT / "examples/pipeline_basico.abt",
                   ROOT / "examples/colecoes_agregacao.abt", ROOT / "examples/pacote_dates.abt"]
        invalid = self.root / "inválido.abt"
        invalid.write_text("mostrar (\n")
        samples.append(invalid)
        for source in samples:
            for prefix in (("run",), ("check",)):
                with self.subTest(source=source.name, command=prefix[0]):
                    a = self.call(source, "min", *prefix)
                    b = self.call(source, "all", *prefix)
                    self.assertEqual((a.returncode, a.stdout, a.stderr),
                                     (b.returncode, b.stdout, b.stderr))

    def test_consecutive_edits_effects_and_parallel_runs(self):
        source = self.root / "mutável α.abt"
        source.write_text('mostrar "primeiro"\nmostrar "depois"\n')
        self.assertEqual(self.call(source, "min", "run").stdout, "primeiro\ndepois\n")
        source.write_text('mostrar "alterado"\n')
        self.assertEqual(self.call(source, "min", "run").stdout, "alterado\n")
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: self.call(source, "min", "run"), range(8)))
        self.assertTrue(all(r.returncode == 0 and r.stdout == "alterado\n" for r in results))

    def test_interrupt_and_next_run(self):
        command = [str(ROOT / "bin/abt"), "run", str(ROOT / "benchmarks/scenarios/large_1000.abt")]
        process = subprocess.Popen(command, env=self.env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        time.sleep(0.3)
        self.assertIsNone(process.poll(), "target finished before SIGINT")
        process.send_signal(signal.SIGINT)
        process.communicate(timeout=15)
        self.assertNotEqual(process.returncode, 0)
        next_run = self.call(ROOT / "benchmarks/scenarios/ola.abt", "min", "run")
        self.assertEqual((next_run.returncode, next_run.stdout), (0, "Olá, mundo!\n"))

    def test_package_manifest_invalidates_precompile_cache(self):
        project = self.root / "package copy"
        shutil.copytree(ROOT / "src", project / "src")
        for relative in ("Project.toml", "ABT.packages.toml"):
            shutil.copy2(ROOT / relative, project / relative)

        def functions():
            result = subprocess.run([str(JULIA), "--startup-file=no", "--compile=min",
                                     f"--project={project}", "-e",
                                     'using ABT; print(sort(collect(keys(ABT.ABT_PACKAGES["Dates"].functions))))'],
                                    env=self.env, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

        self.assertIn("year", functions())
        manifest = project / "ABT.packages.toml"
        manifest.write_text(manifest.read_text().replace("year = 1", "month = 1"))
        os.utime(manifest, (time.time() + 2, time.time() + 2))
        self.assertIn("month", functions())
        self.assertNotIn("year", functions())

    def test_local_latency_regression_guard(self):
        # A generous local gate catches accidental return to ~5 s startup.
        self.call(ROOT / "benchmarks/scenarios/ola.abt", "min", "run")
        samples = []
        for _ in range(5):
            start = time.perf_counter()
            result = self.call(ROOT / "benchmarks/scenarios/ola.abt", "min", "run")
            samples.append(time.perf_counter() - start)
            self.assertEqual((result.returncode, result.stdout), (0, "Olá, mundo!\n"))
        self.assertLess(statistics.median(samples), 2.0, samples)


if __name__ == "__main__":
    unittest.main(verbosity=2)
