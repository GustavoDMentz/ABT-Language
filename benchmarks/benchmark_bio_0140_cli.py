#!/usr/bin/env python3
"""ABT 0.14.0 — benchmark de processo frio (CLI) e memória máxima (RSS).

Mede, em processos novos, a CLI da ABT (`bin/abt run`) contra scripts Julia diretos equivalentes
(FASTX.jl/BioAlignments.jl). Cada medição é um processo independente (inicialização + carga +
primeira execução + cálculo); por isso inclui compilação JIT. As medições aquecidas em processo
estão em benchmark_bio_0140.jl. A Julia direta não valida o alfabeto como a ABT.

    python3 benchmarks/benchmark_bio_0140_cli.py --julia $(which julia) [--repeat 3] [--output arquivo.json]
"""
import argparse, json, os, platform, random, re, statistics, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--julia", default=os.environ.get("ABT_JULIA", "julia"))
parser.add_argument("--repeat", type=int, default=3)
parser.add_argument("--timeout", type=int, default=300)
parser.add_argument("--output", default=str(ROOT / "benchmarks/results/benchmark_bio_0140_cli.json"))
args = parser.parse_args()
env = dict(os.environ, ABT_JULIA=args.julia)


def timed(command, extra_env=None):
    """Executa sob /usr/bin/time -v; devolve (segundos de parede, RSS máximo em MiB, stdout)."""
    run_env = dict(env, **(extra_env or {}))
    p = subprocess.run(["/usr/bin/time", "-v"] + command, cwd=ROOT, env=run_env, capture_output=True, text=True, timeout=args.timeout)
    if p.returncode:
        raise SystemExit(f"falhou: {command}\n{p.stderr[-600:]}")
    wall = re.search(r"Elapsed \(wall clock\) time.*: (?:(\d+):)?(\d+):([\d.]+)", p.stderr)
    seconds = (int(wall.group(1) or 0) * 3600 + int(wall.group(2)) * 60 + float(wall.group(3)))
    rss = int(re.search(r"Maximum resident set size \(kbytes\): (\d+)", p.stderr).group(1)) / 1024
    return seconds, rss, p.stdout


def repeated(command, extra_env=None):
    runs = [timed(command, extra_env) for _ in range(args.repeat)]
    secs = [r[0] for r in runs]; rss = [r[1] for r in runs]
    return dict(mediana_s=round(statistics.median(secs), 3), minimo_s=round(min(secs), 3), rss_max_mib=round(max(rss), 1)), runs[0][2]


rng = random.Random(140)
with tempfile.TemporaryDirectory(prefix="abt-bench-") as tmp:
    tmp = Path(tmp)
    with open(tmp / "reads.fastq", "w") as f:
        for i in range(1, 20001):
            f.write(f"@r{i}\n{''.join(rng.choices('ACGT', k=100))}\n+\n{''.join(chr(33 + rng.randint(20, 40)) for _ in range(100))}\n")
    with open(tmp / "seqs.fasta", "w") as f:
        for i in range(1, 20001):
            f.write(f">s{i}\n{''.join(rng.choices('ACGT', k=150 + rng.randint(0, 50)))}\n")
    a, b = ("".join(rng.choices("ACGT", k=1000)) for _ in range(2))
    (tmp / "vazio.abt").write_text("mostrar 1\n")
    (tmp / "fastq.abt").write_text(f'l = ler_fastq("{tmp}/reads.fastq", "DNA", "rejeitar", "phred33")\nm = metricas_leituras(l)\nmostrar soma de transformar m com 1\n')
    (tmp / "fasta.abt").write_text(f'g = ler_fasta("{tmp}/seqs.fasta", "DNA", "rejeitar", "exigir_maiusculas")\nmostrar resumir_comprimentos(g).sequencias\n')
    (tmp / "align.abt").write_text(f'mostrar alinhar_par("{a}", "{b}", "global", pontuacao_dna(2, -1, -3, -1)).pontuacao\n')
    (tmp / "fastq.jl").write_text(f'''using FASTX
n = 0
open("{tmp}/reads.fastq") do io
    for rec in FASTQ.Reader(io)
        seq = sequence(String, rec); q = collect(quality_scores(rec, FASTQ.SANGER_QUAL_ENCODING))
        count(c -> c == 'G' || c == 'C', seq); sum(q) / length(q); global n += 1
    end
end
println(n)
''')
    (tmp / "fasta.jl").write_text(f'''using FASTX
n = 0
open("{tmp}/seqs.fasta") do io
    for rec in FASTA.Reader(io); length(sequence(String, rec)); global n += 1; end
end
println(n)
''')
    (tmp / "align.jl").write_text(f'''using BioAlignments, BioSequences
m = AffineGapScoreModel(; match=2, mismatch=-1, gap_open=-3, gap_extend=-1)
println(score(pairalign(GlobalAlignment(), LongDNA{{2}}("{a}"), LongDNA{{2}}("{b}"), m)))
''')
    out = {"maquina": dict(cpu=platform.processor() or "desconhecido", nucleos=os.cpu_count(), sistema=platform.platform(),
                           julia=subprocess.run([args.julia, "--version"], capture_output=True, text=True).stdout.strip(), repeticoes=args.repeat)}
    out["cli_version_caminho_rapido"], _ = repeated([str(ROOT / "bin/abt"), "--version"])
    out["cli_vazio_carrega_abt"], _ = repeated([str(ROOT / "bin/abt"), "run", str(tmp / "vazio.abt")])
    out["julia_vazia_com_projeto"], _ = repeated([args.julia, "--startup-file=no", f"--project={ROOT}", "-e", "nothing"])
    for name in ("fastq", "fasta", "align"):
        out[f"{name}_abt_cli_compile_min"], printed_abt = repeated([str(ROOT / "bin/abt"), "run", str(tmp / f"{name}.abt")])
        out[f"{name}_abt_cli_compile_all"], _ = repeated([str(ROOT / "bin/abt"), "run", str(tmp / f"{name}.abt")], {"ABT_JULIA_COMPILE": "all"})
        out[f"{name}_julia_direta"], printed_julia = repeated([args.julia, "--startup-file=no", f"--project={ROOT}", str(tmp / f"{name}.jl")])
        print(name, "saída ABT:", printed_abt.strip()[:60], "| Julia:", printed_julia.strip()[:60], flush=True)
Path(args.output).parent.mkdir(parents=True, exist_ok=True)
Path(args.output).write_text(json.dumps(out, indent=2, ensure_ascii=False))
print(json.dumps(out, indent=2, ensure_ascii=False))
