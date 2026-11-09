#!/usr/bin/env python3
"""Measure complete CLI process time with repeated independent processes."""
import csv
import os
import pathlib
import statistics
import subprocess
import time

ROOT=pathlib.Path(__file__).resolve().parent
JULIA=os.environ.get("JULIA","julia")
FILES=["examples/pipeline_basico.abt","examples/colecoes_agregacao.abt","examples/funcoes.pseudo"]
with (ROOT/"benchmark_cli.csv").open("w") as f:
    writer=csv.writer(f)
    writer.writerow(["file","median_ms","min_ms","max_ms","samples","exit_codes"])
    for name in FILES:
        samples=[]; codes=[]
        for _ in range(9):
            start=time.perf_counter_ns()
            result=subprocess.run([JULIA,"--startup-file=no",str(ROOT/"pseudo.jl"),str(ROOT/name)],cwd=ROOT,env=os.environ.copy(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60)
            samples.append((time.perf_counter_ns()-start)/1e6)
            codes.append(result.returncode)
        writer.writerow([name,statistics.median(samples),min(samples),max(samples),len(samples),";".join(map(str,codes))])
        print(name,round(statistics.median(samples),2),"ms",set(codes),flush=True)
        if any(codes): raise SystemExit(1)
