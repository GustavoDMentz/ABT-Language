#!/usr/bin/env python3
"""Validate ABT documentation against the public catalog and execute examples."""
from pathlib import Path
from urllib.parse import unquote
import json
import os
import re
import runpy
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs/src"
JULIA = os.environ.get("ABT_JULIA", "julia")
CLI = ROOT / "bin/abt"
RESULTS = []

def redact_local_paths(detail):
    return detail.replace(str(ROOT), "<ABT_REPO>").replace(str(Path.home()), "<USER_HOME>")

def result(kind, name, status, detail=""):
    detail = redact_local_paths(detail)
    RESULTS.append(dict(kind=kind, name=name, status=status, detail=detail))
    print(" ".join(part for part in (status, kind, name, detail[:100].rstrip()) if part), flush=True)

def slug(text):
    text = re.sub(r"<[^>]*>", "", text).strip().lower()
    text = text.replace("`", "")
    return re.sub(r"[^\w\- ]", "", text).replace(" ", "-")

def run(command, *, env=None, expected=0, contains=None):
    try:
        p = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    ok = (p.returncode == expected and (contains is None or contains in p.stdout + p.stderr))
    return ok, f"exit={p.returncode}; stdout={p.stdout[:200]!r}; stderr={p.stderr[:200]!r}"

def catalog():
    code = 'using ABT; println(join(sort!(collect(ABT.ABT_STDLIB_NAMES)), "\\n"))'
    p = subprocess.run([JULIA, "--startup-file=no", f"--project={ROOT}", "-e", code],
                       cwd=ROOT, text=True, capture_output=True, timeout=120)
    if p.returncode:
        result("catalog", "ABT.ABT_STDLIB_NAMES", "FAIL", p.stderr[:300])
        return set()
    return set(p.stdout.splitlines())

def reference():
    pages = list((DOCS / "standard-library").glob("*.md"))
    names = []
    for page in pages:
        if page.name == "index.md":
            continue
        names += re.findall(r"^## `([^`]+)`$", page.read_text(), re.M)
    actual = catalog()
    missing, extra = sorted(actual - set(names)), sorted(set(names) - actual)
    duplicate = sorted(n for n in set(names) if names.count(n) > 1)
    ok = bool(actual) and not (missing or extra or duplicate)
    result("reference", "public operations", "PASS" if ok else "FAIL",
           f"{len(names)} documented; missing={missing}; extra={extra}; duplicate={duplicate}")
    source = runpy.run_path(str(ROOT / "tools/generate_docs_reference.py"))
    uncovered = []
    for _, block in source["SECTIONS"].values():
        for name, *_, example in source["rows"](block):
            program = ROOT / "docs/examples" / example
            if not program.is_file() or not re.search(r"\b" + re.escape(name) + r"\s*\(", program.read_text()):
                uncovered.append(f"{name} -> {example}")
    result("reference", "operation example coverage", "PASS" if not uncovered else "FAIL",
           f"{len(names) - len(uncovered)} covered; missing={uncovered}")

def generated():
    ok, detail = run([sys.executable, str(ROOT / "tools/generate_docs_reference.py"), "--check"])
    result("generation", "reference/examples sync", "PASS" if ok else "FAIL", detail)

def links():
    failures = []
    for page in DOCS.rglob("*.md"):
        content = page.read_text()
        for target in re.findall(r"(?<!!)\[[^]]+\]\(([^)]+)\)", content):
            if target.startswith(("https://", "http://", "mailto:")):
                continue
            path, _, fragment = target.partition("#")
            destination = (page.parent / unquote(path)).resolve() if path else page
            if not destination.is_relative_to(DOCS.resolve()) or not destination.is_file():
                failures.append(f"{page.relative_to(DOCS)} -> {target}: file missing")
                continue
            if fragment:
                headings = re.findall(r"^#{1,6} +(.+)$", destination.read_text(), re.M)
                if fragment not in {slug(h) for h in headings}:
                    failures.append(f"{page.relative_to(DOCS)} -> {target}: anchor missing")
    result("links", "internal markdown links", "PASS" if not failures else "FAIL", "; ".join(failures[:10]))

def files():
    failures = []
    for page in DOCS.rglob("*.md"):
        for path in re.findall(r"`((?:applications|examples|docs/examples)/[^`\s]+\.(?:abt|csv|fasta))`", page.read_text()):
            if not (ROOT / path).is_file():
                failures.append(f"{page.relative_to(DOCS)} -> {path}")
    result("files", "referenced ABT/data files", "PASS" if not failures else "FAIL", "; ".join(failures[:10]))

def cli():
    for command, expected_text in [(["--version"], "ABT 0.13.0"), (["--help"], "Uso:"), (["doctor"], "runtime disponíveis"), (["operacoes"], "resumo_estatistico")]:
        ok, detail = run([str(CLI), *command], env=os.environ, contains=expected_text)
        result("cli", " ".join(command), "PASS" if ok else "FAIL", detail)

def examples():
    env = dict(os.environ, ABT_JULIA=JULIA, ABT_DOC_FIGURE_PATH="/tmp/abt-documentation-figure.png",
               ABT_FIGURA_PATH="/tmp/abt-documentation-tutorial.png",
               XDG_CACHE_HOME="/tmp/abt-documentation-cache",
               JULIA_CONDAPKG_BACKEND="Null",
               JULIA_PYTHONCALL_EXE=os.environ.get("JULIA_PYTHONCALL_EXE", sys.executable))
    for path in sorted((ROOT / "docs/examples").glob("*.abt")):
        ok, detail = run([str(CLI), "check", str(path)], env=env, contains="Programa ABT válido.")
        result("example-check", path.name, "PASS" if ok else "FAIL", detail)
        code, expected = (1, "erro demonstrativo") if path.name == "falhar.abt" else (0, None)
        ok, detail = run([str(CLI), "run", str(path)], env=env, expected=code, contains=expected)
        result("example-run", path.name, "PASS" if ok else "FAIL", detail)
    for page in sorted(DOCS.rglob("*.md")):
        if page == DOCS / "examples/programs.md":
            continue  # The corresponding source files were executed above.
        blocks = re.findall(r"```abt\n(.*?)\n```", page.read_text(), re.S)
        for number, source in enumerate(blocks, 1):
            name = f"{page.relative_to(DOCS)}:{number}"
            if page == DOCS / "getting-started/tooling.md":
                with tempfile.TemporaryDirectory(prefix="abt-doc-") as directory:
                    program = Path(directory) / "example.abt"
                    program.write_text(source + "\n")
                    ok, detail = run([str(CLI), "run", str(program)], env=env, expected=1, contains="E021")
                result("inline-error", name, "PASS" if ok else "FAIL", detail)
                continue
            with tempfile.TemporaryDirectory(prefix="abt-doc-") as directory:
                program = Path(directory) / "example.abt"
                program.write_text(source + "\n")
                ok, detail = run([str(CLI), "run", str(program)], env=env)
            result("inline", name, "PASS" if ok else "FAIL", detail)

def main():
    generated(); reference(); links(); files(); cli(); examples()
    output = ROOT / os.environ.get("ABT_DOC_VALIDATION_OUTPUT", "logs/documentation/validation.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(RESULTS, ensure_ascii=False, indent=2) + "\n")
    counts = {status: sum(row["status"] == status for row in RESULTS) for status in ("PASS", "FAIL", "SKIP")}
    print("Summary:", counts)
    return 1 if counts["FAIL"] else 0

if __name__ == "__main__":
    raise SystemExit(main())
