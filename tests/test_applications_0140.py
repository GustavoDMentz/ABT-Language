#!/usr/bin/env python3
"""ABT 0.14.0: as três aplicações de bioinformática nos três modos de execução.

Compara interpretador, Julia sem otimização e Julia otimizada entre si e com as saídas
esperadas versionadas; confere valores-chave com Python puro (oráculo independente);
verifica que entradas inválidas falham com a mesma mensagem nos três modos.
"""
import argparse, json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APPS = ROOT / "applications" / "bioinformatics_0140"
parser = argparse.ArgumentParser()
parser.add_argument("--julia", default=os.environ.get("ABT_JULIA", "julia"))
parser.add_argument("--timeout", type=int, default=240)
args = parser.parse_args()
results = []


def run_modes(source, env_extra, tmp):
    """Devolve {modo: (código, stdout, stderr)}."""
    env = dict(os.environ, ABT_JULIA=args.julia, **env_extra)
    out = {}
    cmd = [str(ROOT / "bin" / "abt"), "run", str(source)]
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=args.timeout)
    out["interpretador"] = (p.returncode, p.stdout, p.stderr)
    for optimized, label in ((False, "julia_sem_otimizacao"), (True, "julia_otimizada")):
        jl = Path(tmp) / f"{source.stem}_{label}.jl"
        emit = [args.julia, "--startup-file=no", f"--project={ROOT}", str(ROOT / "pseudo.jl"), str(source),
                "--emit-julia", str(jl), "--no-run"] + ([] if optimized else ["--no-opt"])
        e = subprocess.run(emit, cwd=ROOT, env=env, capture_output=True, text=True, timeout=args.timeout)
        if e.returncode:
            out[label] = (e.returncode, e.stdout, e.stderr)
            continue
        p = subprocess.run([args.julia, "--startup-file=no", f"--project={ROOT}", str(jl)],
                           cwd=ROOT, env=env, capture_output=True, text=True, timeout=args.timeout)
        out[label] = (p.returncode, p.stdout, p.stderr)
    return out


def record(name, ok, detail=""):
    results.append(dict(case=name, status="PASS" if ok else "FAIL", detail=detail[:400]))
    print("PASS" if ok else "FAIL", name, detail[:200] if not ok else "", flush=True)


def check_app(name, extra_env_factory=None, extra_checks=None):
    with tempfile.TemporaryDirectory(prefix="abt-014-") as tmp:
        outputs = {}
        for mode_index in range(1):
            env = extra_env_factory(tmp) if extra_env_factory else {}
            modes = run_modes(APPS / f"{name}.abt", env, tmp)
        expected = (APPS / "expected" / f"{name}.out").read_text()
        for mode, (code, stdout, stderr) in modes.items():
            record(f"{name}:{mode}:saida_esperada", code == 0 and stdout == expected,
                   f"código={code}; stderr={stderr[:200]!r}")
        if extra_checks:
            extra_checks(modes["interpretador"][1], tmp)


# --- oráculo independente em Python puro ---
def fasta_records(path):
    data, name = {}, None
    for line in Path(path).read_text().splitlines():
        if line.startswith(">"):
            name = line[1:].split()[0]; data[name] = ""
        elif line:
            data[name] += line
    return data


def fastq_reads(path):
    lines = Path(path).read_text().splitlines()
    for i in range(0, len(lines), 4):
        yield lines[i][1:], lines[i + 1], [ord(c) - 33 for c in lines[i + 3]]


def checks_a(stdout, tmp):
    genes = fasta_records(APPS / "data" / "genes.fasta")
    total = sum(map(len, genes.values()))
    acgt = sum(s.count(b) for s in genes.values() for b in "ACGT")
    gc = sum(s.count("G") + s.count("C") for s in genes.values())
    record("A:independente:bases_e_gc", f"bases = {total}," in stdout and repr(100.0 * gc / acgt) in stdout)
    lengths = sorted(map(len, genes.values()))
    record("A:independente:comprimentos",
           f"minimo = {lengths[0]}, maximo = {lengths[-1]}, media = {total / len(lengths)}" in stdout)
    ricos = [k for k, s in genes.items() if 100 * (s.count("G") + s.count("C")) / sum(s.count(b) for b in "ACGT") >= 50]
    record("A:independente:filtro_gc", json.dumps(ricos) == stdout.splitlines()[2])


def checks_c(stdout, tmp):
    reads = list(fastq_reads(APPS / "data" / "leituras.fastq"))
    approved = [r for r in reads if len(r[1]) >= 24 and sum(r[2]) / len(r[2]) >= 30 and r[1].count("N") <= 1]
    record("C:independente:aprovadas", [r[0] for r in approved] == ["leitura_01", "leitura_02", "leitura_03", "leitura_06"])
    mean = sum(sum(r[2]) for r in reads) / sum(len(r[2]) for r in reads)
    record("C:independente:phred_medio", f"phred_medio = {mean}" in stdout)
    q30 = sum(1 for r in reads if 100 * sum(x >= 30 for x in r[2]) / len(r[2]) >= 90)
    record("C:independente:q30", stdout.rstrip().splitlines()[-1] == str(q30))


check_app("analise_sequencias", extra_checks=checks_a)
check_app("alinhamento")
check_app("qualidade_sequenciamento",
          extra_env_factory=lambda tmp: {"ABT_FASTQ_SAIDA": str(Path(tmp) / "aprovadas.fastq")},
          extra_checks=checks_c)

# --- entradas inválidas: mesma falha nos três modos ---
with tempfile.TemporaryDirectory(prefix="abt-014-bad-") as tmp:
    cases = {
        "fasta_base_invalida": ("analise_sequencias", "ABT_FASTA_PATH", ">x\nACGZ\n", "base inválida"),
        "fasta_vazio": ("analise_sequencias", "ABT_FASTA_PATH", "", "nenhum registro"),
        "fastq_truncado": ("qualidade_sequenciamento", "ABT_FASTQ_PATH", "@r1\nACGT\n+\nII\n", "ABT FASTQ"),
        "fastq_vazio": ("qualidade_sequenciamento", "ABT_FASTQ_PATH", "", "arquivo sem registros"),
    }
    for label, (app, variable, content, fragment) in cases.items():
        path = Path(tmp) / f"{label}.txt"; path.write_text(content)
        modes = run_modes(APPS / f"{app}.abt", {variable: str(path), "ABT_FASTQ_SAIDA": str(Path(tmp) / "s.fastq")}, tmp)
        for mode, (code, stdout, stderr) in modes.items():
            record(f"erro:{label}:{mode}", code != 0 and fragment in stderr, f"código={code}; stderr={stderr[:200]!r}")

summary = {s: sum(1 for r in results if r["status"] == s) for s in ("PASS", "FAIL")}
print("Resumo:", summary)
sys.exit(1 if summary["FAIL"] else 0)
