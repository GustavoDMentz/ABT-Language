#!/usr/bin/env python3
"""Run bounded ABT parser/semantic probes, each in a separate Julia process."""
import json
import os
import pathlib
import resource
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
JULIA = os.environ.get("JULIA", "julia")
CASES = [
    ("unicode_name", "valid", "ação=3\nmostrar ação+2"),
    ("comments_blank", "valid", "# comentário\n\nx=2 # fim\nmostrar x"),
    ("short_circuit", "valid", "mostrar falso e (1/0 > 0)\nmostrar verdadeiro ou (1/0 > 0)"),
    ("shadow_scope", "valid", "x=2\nfunção f(x) { retornar x+1 }\nmostrar f(4)\nmostrar x"),
    ("zero_division", "valid", "mostrar 1/0"),
    ("heterogeneous", "valid", "mostrar [1,verdadeiro,\"x\"]"),
    ("pipeline_nested", "valid", "função f(x) { retornar x }\nf([1,2,3])\n    filtrar onde valor > 1\n    transformar com valor*2\n    mostrar"),
    ("tabs", "invalid", "[1,2]\n\tmostrar"),
    ("unknown_step", "invalid", "[1,2]\n    inventar valor\n    mostrar"),
    ("after_terminal", "invalid", "[1,2]\n    mostrar\n    limitar a 1"),
    ("incomplete_expression", "invalid", "mostrar (1+"),
    ("invalid_character", "invalid", "mostrar 1 @ 2"),
    ("huge_identifier", "valid", "a" * 100_000 + "=1\nmostrar 2"),
    ("deep_expression", "valid", "mostrar " + "(" * 2500 + "1" + ")" * 2500),
]

def limits():
    resource.setrlimit(resource.RLIMIT_AS, (1024 * 1024 * 1024,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (15, 15))

results = []
with tempfile.TemporaryDirectory() as temp:
    for name, mode, source in CASES:
        file = pathlib.Path(temp) / (name + ".abt")
        file.write_text(source)
        start = time.monotonic()
        try:
            run = subprocess.run([JULIA, "--startup-file=no", str(ROOT / "tests/adversarial_case_118.jl"), mode, str(file)], cwd=ROOT, env=os.environ.copy(), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20, preexec_fn=limits)
            status = "PASS" if run.returncode == 0 else "FINDING"
            output = run.stdout[-2000:]
            code = run.returncode
        except subprocess.TimeoutExpired as exc:
            status, output, code = "TIMEOUT", str(exc), None
        results.append(dict(name=name, mode=mode, status=status, exit_code=code, seconds=round(time.monotonic()-start,3), output=output))
        print(f"{name}: {status}", flush=True)
(ROOT / "logs/test_logs/adversarial_results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False))
raise SystemExit(int(any(r["status"] != "PASS" for r in results)))
