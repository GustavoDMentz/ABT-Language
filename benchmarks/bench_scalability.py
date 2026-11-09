#!/usr/bin/env python3
"""Benchmark reproduzível de incrementos sequenciais no interpretador ABT."""
import argparse
import json
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "benchmarks" / "scalability"
SIZES = (100, 1000, 10000, 100000)
MODES = ("min", "all")
FIELDS = {
    "user_s": r"User time \(seconds\):\s*([\d.]+)",
    "system_s": r"System time \(seconds\):\s*([\d.]+)",
    "rss_kb": r"Maximum resident set size \(kbytes\):\s*(\d+)",
    "elapsed_time_s": r"Elapsed \(wall clock\) time \(h:mm:ss or m:ss\):\s*(\S+)",
}


def measure(n, mode, repetition, env, timeout):
    stem = f"n{n}_{mode}_r{repetition:02d}"
    program = OUT / f"incrementos_{n}.abt"
    command = ["/usr/bin/time", "-v", str(ROOT / "bin" / "abt"), "run", str(program)]
    run_env = dict(env, ABT_JULIA_COMPILE=mode)
    start = time.perf_counter()
    try:
        p = subprocess.run(command, cwd=ROOT, env=run_env, capture_output=True, text=True, timeout=timeout)
        status = "pass" if p.returncode == 0 and p.stdout == f"{n}\n" else "fail"
        stdout, stderr, returncode = p.stdout, p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        status = "timeout"
        stdout = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        stderr = (e.stderr or b"").decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
        returncode = None
    elapsed = time.perf_counter() - start
    (OUT / "raw" / f"{stem}.stdout").write_text(stdout)
    (OUT / "raw" / f"{stem}.time-v.txt").write_text(stderr)
    result = {"n": n, "mode": mode, "repetition": repetition, "status": status,
              "returncode": returncode, "real_s": elapsed, "stdout": stdout,
              "command": command, "timeout_s": timeout}
    for key, pattern in FIELDS.items():
        m = re.search(pattern, stderr)
        if m:
            result[key] = int(m.group(1)) if key == "rss_kb" else m.group(1) if key == "elapsed_time_s" else float(m.group(1))
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repetitions", type=int, default=10)
    ap.add_argument("--timeout-100k", type=int, default=120)
    ap.add_argument("--sizes", type=int, nargs="+", choices=SIZES, default=SIZES)
    ap.add_argument("--modes", nargs="+", choices=MODES, default=MODES)
    args = ap.parse_args()
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    for n in SIZES:
        (OUT / f"incrementos_{n}.abt").write_text("x = 0\n" + "x = x + 1\n" * n + "mostrar x\n")
    env = os.environ.copy()
    env.update(LC_ALL="C", JULIA_NUM_THREADS="1")
    results_file = OUT / "results.json"
    results = json.loads(results_file.read_text()) if results_file.exists() else []
    for n in args.sizes:
        for mode in args.modes:
            existing = [r for r in results if r["n"] == n and r["mode"] == mode]
            if any(r["status"] != "pass" for r in existing):
                continue
            for rep in range(1, args.repetitions + 1):
                if any(r["repetition"] == rep for r in existing):
                    continue
                timeout = args.timeout_100k if n == 100000 else 300
                r = measure(n, mode, rep, env, timeout)
                results.append(r)
                results_file.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
                print(f"{n:6d} {mode:3s} {rep:2d} {r['status']:7s} {r['real_s']:.3f}s RSS={r.get('rss_kb', 'NA')}", flush=True)
                if r["status"] != "pass":
                    break


if __name__ == "__main__":
    main()
