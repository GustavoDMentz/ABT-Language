#!/usr/bin/env python3
"""Run the ABT collection examples through the CLI and both generated modes."""
import argparse
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--julia", default="julia")
args = parser.parse_args()
results = []
for path in sorted((ROOT / "examples").glob("colecoes_*.abt")):
    interpreted = subprocess.run(
        [args.julia, "--startup-file=no", str(ROOT / "pseudo.jl"), str(path)],
        cwd=ROOT, text=True, capture_output=True, timeout=120,
    )
    modes = []
    with tempfile.TemporaryDirectory() as temporary:
        for optimize in (False, True):
            generated_path = pathlib.Path(temporary) / ("optimized.jl" if optimize else "plain.jl")
            command = [args.julia, "--startup-file=no", str(ROOT / "pseudo.jl"), str(path),
                       "--emit-julia", str(generated_path), "--no-run"]
            if not optimize:
                command.append("--no-opt")
            emitted = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
            generated = subprocess.run(
                [args.julia, "--startup-file=no", str(generated_path)],
                cwd=ROOT, text=True, capture_output=True, timeout=120,
            ) if emitted.returncode == 0 else None
            modes.append({"optimize": optimize, "emit_exit": emitted.returncode,
                          "exit": None if generated is None else generated.returncode,
                          "stdout": None if generated is None else generated.stdout,
                          "stderr": emitted.stderr + ("" if generated is None else generated.stderr)})
    passed = interpreted.returncode == 0 and all(
        mode["emit_exit"] == 0 and mode["exit"] == 0
        and mode["stdout"] == interpreted.stdout and not mode["stderr"] for mode in modes
    )
    results.append({"file": path.name, "status": "PASS" if passed else "FAIL",
                    "interpreter": {"exit": interpreted.returncode, "stdout": interpreted.stdout,
                                    "stderr": interpreted.stderr}, "generated": modes})
    print(f"{'PASS' if passed else 'FAIL'} {path.name}")
(ROOT / "cli_examples_results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False))
raise SystemExit(0 if all(item["status"] == "PASS" for item in results) else 1)
