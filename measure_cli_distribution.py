#!/usr/bin/env python3
"""Preliminary process startup/RSS measurements for the external-Julia CLI."""
import json
import os
import pathlib
import statistics
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent
commands = {
    "version": ["--versao"],
    "verify": ["verificar", str(root / "examples" / "pipeline_basico.abt")],
    "execute": ["executar", str(root / "examples" / "pipeline_basico.abt")],
}
results = {}
for name, args in commands.items():
    samples = []
    for _ in range(5):
        with tempfile.NamedTemporaryFile() as metric:
            run = subprocess.run(["/usr/bin/time", "-f", "%e,%M,%x", "-o", metric.name,
                                  str(root / "bin" / "abt"), *args], cwd="/tmp", env=os.environ.copy(),
                                 text=True, capture_output=True, timeout=60)
            elapsed, rss, exit_code = metric.read().decode().strip().split(",")
        samples.append({"seconds":float(elapsed),"maxrss_kb":int(rss),"exit":int(exit_code),
                        "stdout":run.stdout,"stderr":run.stderr})
    assert all(x["exit"] == 0 for x in samples)
    results[name] = {"samples":samples,"median_seconds":statistics.median(x["seconds"] for x in samples),
                     "median_maxrss_kb":statistics.median(x["maxrss_kb"] for x in samples)}
    print(name, results[name]["median_seconds"], "s", results[name]["median_maxrss_kb"], "KB", flush=True)
(root / "distribution_measurements.json").write_text(json.dumps(results, indent=2, ensure_ascii=False))
