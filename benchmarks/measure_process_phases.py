#!/usr/bin/env python3
"""Approximate Julia startup and shutdown via a flushed marker."""
import argparse
import json
import statistics
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--julia", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--repeats", type=int, default=10)
args = parser.parse_args()
samples = []
for _ in range(args.repeats):
    start = time.perf_counter()
    process = subprocess.Popen([args.julia, "--startup-file=no", "-e",
                                'println("READY"); flush(stdout)'],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    marker = process.stdout.readline()
    ready = time.perf_counter()
    stderr = process.stderr.read()
    code = process.wait()
    end = time.perf_counter()
    if marker != "READY\n" or code:
        raise RuntimeError(f"Julia phase probe failed: {code}: {stderr}")
    samples.append({"startup_to_marker_s": ready - start, "shutdown_after_marker_s": end - ready,
                    "total_s": end - start})
result = {"samples": samples, "startup_median_s": statistics.median(s["startup_to_marker_s"] for s in samples),
          "shutdown_median_s": statistics.median(s["shutdown_after_marker_s"] for s in samples)}
Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
print(result["startup_median_s"], result["shutdown_median_s"])
