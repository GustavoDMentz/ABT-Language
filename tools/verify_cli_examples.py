#!/usr/bin/env python3
"""Compare the public CLI with the legacy entry on every executable .abt example."""
import json
import os
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
julia = os.environ.get("ABT_JULIA", "julia")
results = []
for path in sorted((root / "examples").glob("*.abt")):
    public = subprocess.run([str(root / "bin" / "abt"), str(path)], cwd="/tmp", env=os.environ.copy(), text=True, capture_output=True, timeout=120)
    legacy = subprocess.run([julia, "--startup-file=no", str(root / "pseudo.jl"), str(path)], cwd="/tmp", env=os.environ.copy(), text=True, capture_output=True, timeout=120)
    equal = (public.returncode, public.stdout, public.stderr) == (legacy.returncode, legacy.stdout, legacy.stderr)
    results.append({"file":path.name,"status":"PASS" if equal else "FAIL","public":{"exit":public.returncode,"stdout":public.stdout,"stderr":public.stderr},"legacy":{"exit":legacy.returncode,"stdout":legacy.stdout,"stderr":legacy.stderr}})
    print(f"{path.name}: {'PASS' if equal else 'FAIL'}", flush=True)
(root / "cli_examples_identity.json").write_text(json.dumps(results, indent=2, ensure_ascii=False))
raise SystemExit(int(any(x["status"] != "PASS" for x in results)))
