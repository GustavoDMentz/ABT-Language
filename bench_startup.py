#!/usr/bin/env python3
"""External process timings for ABT; records raw samples and stdout/stderr."""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parent


def percentile(values, fraction):
    ordered = sorted(values)
    pos = fraction * (len(ordered) - 1)
    low = int(pos)
    return ordered[low] + (ordered[min(low + 1, len(ordered) - 1)] - ordered[low]) * (pos - low)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--julia", required=True)
    parser.add_argument("--repeats", type=int, default=10)
    parser.add_argument("--output", required=True)
    parser.add_argument("--launcher-root", default=str(ROOT), help="ABT tree to benchmark; workloads stay in this tree")
    args = parser.parse_args()
    if args.repeats < 3:
        parser.error("--repeats must be at least 3")
    env = {**os.environ, "ABT_JULIA": args.julia}
    launcher = str(Path(args.launcher_root).resolve() / "bin/abt")
    cases = {
        "launcher_only": ["/bin/sh", "-c", 'readlink -f -- "$1" >/dev/null; dirname -- "$(dirname -- "$1")" >/dev/null', "sh", launcher],
        "julia_start": [args.julia, "--startup-file=no", "-e", "nothing"],
        "version": [launcher, "--version"],
        "doctor": [launcher, "doctor"],
        "check_hello": [launcher, "check", str(ROOT / "perf_logs/ola.abt")],
        "run_hello": [launcher, "run", str(ROOT / "perf_logs/ola.abt")],
        "pipeline": [launcher, "run", str(ROOT / "examples/pipeline_basico.abt")],
        "math": [launcher, "run", str(ROOT / "examples/colecoes_agregacao.abt")],
        "representative": [launcher, "run", str(ROOT / "examples/portugues.pseudo")],
        "large_1000": [launcher, "run", str(ROOT / "perf_logs/large_1000.abt")],
    }
    results = {"environment": {"julia": args.julia, "launcher_root": str(Path(args.launcher_root).resolve()),
                               "julia_depot_path": env.get("JULIA_DEPOT_PATH"),
                               "compile_mode": env.get("ABT_JULIA_COMPILE", "min"),
                               "repeats": args.repeats, "os_cache_cleared": False}, "cases": {}}
    for name, command in cases.items():
        samples = []
        for _ in range(args.repeats):
            start = time.perf_counter()
            result = subprocess.run(["/usr/bin/time", "-f", "ABT_TIME %e %M", *command],
                                    env=env, capture_output=True, text=True, timeout=180)
            wall = time.perf_counter() - start
            lines = result.stderr.splitlines()
            timings = [line for line in lines if line.startswith("ABT_TIME ")]
            if not timings:
                raise RuntimeError(f"time output missing for {name}: {result.stderr}")
            _, measured, rss = timings[-1].split()
            samples.append({"wall_s": wall, "time_s": float(measured), "rss_kb": int(rss),
                            "returncode": result.returncode, "stdout": result.stdout,
                            "stderr": "\n".join(line for line in lines if not line.startswith("ABT_TIME "))})
        if any(sample["returncode"] for sample in samples):
            raise RuntimeError(f"command failed: {name}")
        walls = [sample["wall_s"] for sample in samples]
        results["cases"][name] = {"samples": samples, "median_s": statistics.median(walls),
                                   "p95_s": percentile(walls, 0.95),
                                   "stdev_s": statistics.stdev(walls),
                                   "max_rss_kb": max(sample["rss_kb"] for sample in samples)}
        print(f"{name}: median {statistics.median(walls):.3f}s, p95 {percentile(walls, 0.95):.3f}s", flush=True)
    Path(args.output).write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
