#!/usr/bin/env python3
"""Executa casos de bioestatística nos três backends e compara JSON estruturado."""
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
JULIA = os.environ.get("ABT_JULIA", "julia")
ENV = dict(os.environ, ABT_JULIA=JULIA)
CASES = [
    ("resumo", 'mostrar codificar_json(resumo_estatistico([1,2,3,4]), "erro")\n', None),
    ("intervalo", 'mostrar codificar_json(intervalo_confianca_media([1,2,3,4], 0.95), "erro")\n', None),
    ("correlacao", 'mostrar codificar_json(correlacao([1,2,3,4], [2,5,7,9], "spearman"), "erro")\n', None),
    ("teste_t", 'mostrar codificar_json(teste_t([1,2,3,4], [2,4,5,7], "welch", "bilateral", 0), "erro")\n', None),
    ("nao_parametrico", 'mostrar codificar_json(teste_nao_parametrico([1,2,3], [4,5,6], "mann_whitney", "bilateral"), "erro")\n', None),
    ("normalidade", 'mostrar codificar_json(teste_normalidade([1,2,3,4,5]), "erro")\n', None),
    ("proporcoes", 'mostrar codificar_json(teste_proporcoes(8,10,3,10,"bilateral"), "erro")\n', None),
    ("distribuicao", 'mostrar codificar_json(probabilidade_distribuicao("normal", [0,1], 0), "erro")\n', None),
    ("quantil", 'mostrar codificar_json(quantil_distribuicao("student_t", [4], 0.975), "erro")\n', None),
    ("ausente", 'função sem_valor() { }\nmostrar resumo_estatistico([1, sem_valor(), 3])\n', "resumo_estatistico"),
    ("constante", 'mostrar intervalo_confianca_media([2,2,2], 0.95)\n', "variância zero"),
    ("contagens", 'mostrar teste_proporcoes(11,10,2,10,"bilateral")\n', "contagens fora do domínio"),
    ("colinear", 't = ler_csv("applications/biostatistics/regressao.csv", esquema("resposta","real","idade","inteiro","exposicao","inteiro"),"erro")\nmostrar regressao_linear(t,"resposta",["idade","idade"])\n', "preditores distintos"),
]
APPS = ["ensaio_clinico", "correlacao_biomedica", "regressao_clinica"]


def equivalent(a, b):
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(equivalent(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(equivalent(x, y) for x, y in zip(a, b))
    if isinstance(a, float):
        return math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-12)
    return a == b


def check(name, source, error):
    with tempfile.TemporaryDirectory(prefix="abt-bio-") as directory:
        tmp = Path(directory)
        program = tmp / "case.abt"
        program.write_text(source)
        results = []
        results.append(subprocess.run([str(ROOT / "bin/abt"), "run", str(program)], cwd=ROOT, env=ENV, text=True, capture_output=True, timeout=120))
        for optimized in (False, True):
            generated = tmp / ("optimized.jl" if optimized else "plain.jl")
            cmd = [JULIA, "--startup-file=no", f"--project={ROOT}", str(ROOT / "pseudo.jl"), str(program), "--emit-julia", str(generated), "--no-run"]
            if not optimized:
                cmd.append("--no-opt")
            emit = subprocess.run(cmd, cwd=ROOT, env=ENV, text=True, capture_output=True, timeout=120)
            if emit.returncode:
                return {"case": name, "status": "FAIL", "stage": "emit", "stderr": emit.stderr}
            results.append(subprocess.run([JULIA, "--startup-file=no", f"--project={ROOT}", str(generated)], cwd=ROOT, env=ENV, text=True, capture_output=True, timeout=120))
        if error:
            ok = all(r.returncode != 0 and error in r.stderr for r in results)
        else:
            try:
                values = [json.loads(r.stdout) for r in results]
                ok = all(r.returncode == 0 and not r.stderr for r in results) and equivalent(values[0], values[1]) and equivalent(values[0], values[2])
            except (ValueError, KeyError):
                ok = False
        return {"case": name, "status": "PASS" if ok else "FAIL", "codes": [r.returncode for r in results],
                "stdout": [r.stdout for r in results], "stderr": [r.stderr for r in results]}


results = [check(*case) for case in CASES]
for name in APPS:
    source = (ROOT / "applications/biostatistics" / f"{name}.abt").read_text()
    results.append(check(name, source, None))
log = ROOT / "logs/test_logs/biostatistics_backends.json"
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
for result in results:
    print(result["status"], result["case"], flush=True)
print("Resumo:", {k: sum(r["status"] == k for r in results) for k in ("PASS", "FAIL")})
raise SystemExit(any(r["status"] != "PASS" for r in results))
