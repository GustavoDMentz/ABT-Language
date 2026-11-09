#!/usr/bin/env python3
"""Explore compilation-mode crossover on a larger deterministic ABT file."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--julia", required=True)
parser.add_argument("--program", default=str(ROOT / "benchmarks/scenarios/large_10000.abt"))
parser.add_argument("--repeats", type=int, default=3)
parser.add_argument("--output", required=True)
args = parser.parse_args()
results = {}
for mode in ("min", "all"):
    samples = []
    for _ in range(args.repeats):
        env = {**os.environ, "ABT_JULIA": args.julia, "ABT_JULIA_COMPILE": mode}
        start = time.perf_counter()
        result = subprocess.run([str(ROOT / "bin/abt"), "run", args.program], env=env,
                                capture_output=True, text=True, timeout=180)
        sample = {"wall_s": time.perf_counter() - start, "returncode": result.returncode,
                  "stdout": result.stdout, "stderr": result.stderr}
        if sample["returncode"] or sample["stdout"] != "10000\n":
            raise RuntimeError(f"invalid output under {mode}: {sample}")
        samples.append(sample)
        print(mode, round(sample["wall_s"], 3), flush=True)
    results[mode] = samples
Path(args.output).write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
