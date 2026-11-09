#!/usr/bin/env python3
"""Mede uma execução por tamanho e modo após correção do validador."""
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RAW = HERE / "after_fix_raw"
RAW.mkdir(exist_ok=True)
results = []
for n, mode, timeout in [(10000, "min", 300), (10000, "all", 300),
                         (100000, "min", 300), (100000, "all", 300),
                         (1000000, "all", 180), (1000000, "min", 180)]:
    program = HERE / f"incrementos_{n}.abt"
    if not program.exists():
        program.write_text("x = 0\n" + "x = x + 1\n" * n + "mostrar x\n")
    cmd = ["/usr/bin/time", "-v", str(ROOT / "bin" / "abt"), "run", str(program)]
    env = dict(os.environ, ABT_JULIA_COMPILE=mode, JULIA_NUM_THREADS="1", LC_ALL="C")
    t = time.perf_counter()
    try:
        p = subprocess.Popen(cmd, env=env, cwd=ROOT, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            out, err = p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
            out, err = p.communicate()
            raise subprocess.TimeoutExpired(cmd, timeout, output=out, stderr=err)
        code = p.returncode
        status = "pass" if code == 0 and out == f"{n}\n" else "fail"
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode(errors="replace") if isinstance(e.stdout, bytes) else e.stdout or ""
        err = e.stderr.decode(errors="replace") if isinstance(e.stderr, bytes) else e.stderr or ""
        code, status = None, "timeout"
    real = time.perf_counter() - t
    stem = f"n{n}_{mode}"
    (RAW / f"{stem}.stdout").write_text(out)
    (RAW / f"{stem}.time-v.txt").write_text(err)
    row = dict(n=n, mode=mode, status=status, code=code, real_s=real, stdout=out,
               timeout_s=timeout, command=cmd)
    for field, pattern in [("user_s", r"User time \(seconds\):\s*([\d.]+)"),
                           ("system_s", r"System time \(seconds\):\s*([\d.]+)"),
                           ("rss_kb", r"Maximum resident set size \(kbytes\):\s*(\d+)")]:
        m = re.search(pattern, err)
        if m: row[field] = int(m.group(1)) if field == "rss_kb" else float(m.group(1))
    results.append(row)
    (HERE / "after_fix.json").write_text(json.dumps(results, indent=2) + "\n")
    print(n, mode, status, f"{real:.3f}s", row.get("rss_kb", "NA"), flush=True)
