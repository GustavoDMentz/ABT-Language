#!/usr/bin/env python3
"""ABT 0.15.0 — benchmark de processo frio da CLI (tempo de parede e memória máxima).

Cada medição é um processo novo: inicialização do Julia + carga da ABT + compilação + execução.
Configurações comparadas (mesmos programas e dados):
  0.14-min   : commit-base da main 0.14.0 com o padrão de então (--compile=min)
  0.14-all   : commit-base com ABT_JULIA_COMPILE=all (configuração recomendada no relatório 0.14.0)
  0.15-padrao: esta versão, perfil padrão (--compile=yes)
  0.15-rapido: esta versão, perfil rapido (--compile=min)
  julia      : script Julia direto metodologicamente equivalente (benchmarks/direct_equivalents_0150.jl)

Uso:
  python3 benchmarks/benchmark_0150.py --julia $(which julia) --base /caminho/checkout-0.14 [--repeat 3]
Os modos sem compilação sob demanda (min) levam minutos nos cenários científicos; neles a
medição é feita uma única vez (--repeat-min, padrão 1). Os dados são sintéticos, com semente fixa.
"""
import argparse, json, os, platform, random, re, statistics, subprocess, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
p = argparse.ArgumentParser()
p.add_argument("--julia", default=os.environ.get("ABT_JULIA", "julia"))
p.add_argument("--base", required=True, help="checkout do commit-base 0.14.0")
p.add_argument("--repeat", type=int, default=3)
p.add_argument("--repeat-min", type=int, default=1)
p.add_argument("--timeout", type=int, default=900)
p.add_argument("--output", default=str(ROOT / "benchmarks/results/benchmark_0150_cli.json"))
p.add_argument("--only", default="", help="lista de cenários separada por vírgulas")
args = p.parse_args()

HEAVY = {"fasta", "fastq", "metricas", "alinhamento_dna", "alinhamento_proteina", "composta"}


def timed(cmd, env):
    try:
        r = subprocess.run(["/usr/bin/time", "-v"] + cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        return None, None, "TIMEOUT"
    if r.returncode:
        raise RuntimeError(f"falhou: {cmd}\n{r.stderr[-800:]}")
    m = re.search(r"Elapsed \(wall clock\) time.*: (?:(\d+):)?(\d+):([\d.]+)", r.stderr)
    wall = int(m.group(1) or 0) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    rss = int(re.search(r"Maximum resident set size \(kbytes\): (\d+)", r.stderr).group(1)) / 1024
    return wall, rss, r.stdout


def build_data(d):
    rng = random.Random(150)
    with open(d / "reads.fastq", "w") as f:
        for i in range(1, 20001):
            f.write(f"@r{i}\n{''.join(rng.choices('ACGT', k=100))}\n+\n{''.join(chr(33 + rng.randint(15, 40)) for _ in range(100))}\n")
    with open(d / "seqs.fasta", "w") as f:
        for i in range(1, 20001):
            f.write(f">s{i}\n{''.join(rng.choices('ACGT', k=150 + rng.randint(0, 50)))}\n")
    dna_a, dna_b = ("".join(rng.choices("ACGT", k=1000)) for _ in range(2))
    aa = "ACDEFGHIKLMNPQRSTVWY"
    prot_a, prot_b = ("".join(rng.choices(aa, k=400)) for _ in range(2))
    numeros = ", ".join(str(rng.randint(1, 1000)) for _ in range(20000))
    pequenos = ", ".join(str(i) for i in range(1, 101))
    programs = {
        "trivial": "mostrar 1\n",
        "aritmetica": f"""função passo(a, b) {{
    retornar (a * 3 + b * 7) - (a + b) / 2
}}
xs = [{pequenos}]
total = 0
para cada a em xs {{
    para cada b em xs {{
        total = total + passo(a, b)
    }}
}}
mostrar total
""",
        "listas": f"""dados = [{numeros}]
pares = filtrar dados onde valor > 500
dobrados = transformar pares com valor * 2
mostrar soma de dobrados
mostrar media de dados
mostrar contar(sem_duplicatas(dados))
mostrar limitar ordenar(dados) a 3
""",
        "fasta": f'g = ler_fasta("{d}/seqs.fasta", "DNA", "rejeitar", "exigir_maiusculas")\nmostrar resumir_comprimentos(g)\n',
        "fastq": f'l = ler_fastq("{d}/reads.fastq", "DNA", "rejeitar", "phred33")\nmostrar resumir_fastq(l)\n',
        "metricas": f'l = ler_fastq("{d}/reads.fastq", "DNA", "rejeitar", "phred33")\nm = metricas_leituras(filtrar_fastq(l, 50, 25, 0))\nmostrar contar(m)\n',
        "alinhamento_dna": f'mostrar alinhar_par("{dna_a}", "{dna_b}", "global", pontuacao_dna(2, -1, -3, -1)).pontuacao\n',
        "alinhamento_proteina": f'mostrar alinhar_par("{prot_a}", "{prot_b}", "global", pontuacao_proteina("BLOSUM62", -10, -1)).pontuacao\n',
        "composta": f"""genes = ler_fasta("{d}/seqs.fasta", "DNA", "rejeitar", "exigir_maiusculas")
mostrar resumir_comprimentos(genes)
leituras = ler_fastq("{d}/reads.fastq", "DNA", "rejeitar", "phred33")
aprovadas = filtrar_fastq(leituras, 50, 30, 0)
mostrar resumir_fastq(aprovadas)
r = exportar_fastq(aprovadas, "{d}/aprovadas.fastq")
mostrar r.leituras_escritas
mostrar conteudo_gc("{dna_a}")
mostrar alinhar_par(subsequencia("{dna_a}", 1, 300), subsequencia("{dna_b}", 1, 300), "local", pontuacao_dna(2, -1, -3, -1)).pontuacao
""",
    }
    for name, src in programs.items():
        (d / f"{name}.abt").write_text(src)
    direct = {
        "fasta": f'direct_length_summary("{d}/seqs.fasta")',
        "fastq": f'direct_fastq_summary("{d}/reads.fastq")',
        "alinhamento_dna": f'direct_align("{dna_a}", "{dna_b}", AffineGapScoreModel(; match=2, mismatch=-1, gap_open=-3, gap_extend=-1))',
        "alinhamento_proteina": f'direct_protein_align("{prot_a}", "{prot_b}", AffineGapScoreModel(BLOSUM62; gap_open=-10, gap_extend=-1))',
    }
    for name, expr in direct.items():
        (d / f"{name}.jl").write_text(f'include("{ROOT}/benchmarks/direct_equivalents_0150.jl")\nprintln({expr})\n')
    sizes = {"fastq": "20 000 leituras × 100 pb (~4,5 MB)", "fasta": "20 000 sequências de 150–200 pb (~3,6 MB)",
             "alinhamento_dna": "1000 × 1000 pb", "alinhamento_proteina": "400 × 400 aminoácidos",
             "aritmetica": "10 000 chamadas de função ABT (100 × 100)", "listas": "lista literal de 20 000 inteiros"}
    return list(programs), sizes


def main():
    base_env = {k: v for k, v in os.environ.items() if k != "ABT_JULIA_COMPILE"}
    base_env["ABT_JULIA"] = args.julia
    configs = {
        "0.14-min": ([str(Path(args.base) / "bin/abt"), "run"], {}),
        "0.14-all": ([str(Path(args.base) / "bin/abt"), "run"], {"ABT_JULIA_COMPILE": "all"}),
        "0.15-padrao": ([str(ROOT / "bin/abt"), "run"], {}),
        "0.15-rapido": ([str(ROOT / "bin/abt"), "--perfil", "rapido", "run"], {}),
    }
    results = {"maquina": dict(cpu=platform.processor() or platform.machine(), nucleos=os.cpu_count(), sistema=platform.platform(),
                                julia=subprocess.run([args.julia, "--version"], capture_output=True, text=True).stdout.strip(),
                                repeticoes=args.repeat, repeticoes_min_cientifico=args.repeat_min,
                                data=time.strftime("%Y-%m-%d")), "cenarios": {}}
    with tempfile.TemporaryDirectory(prefix="abt-bench-0150-") as tmp:
        d = Path(tmp)
        names, sizes = build_data(d)
        results["tamanhos"] = sizes
        only = set(filter(None, args.only.split(",")))
        # aquecimento das imagens pré-compiladas (não medido)
        for cmd, extra in configs.values():
            timed(cmd + [str(d / "trivial.abt")], {**base_env, **extra})
        for name in names:
            if only and name not in only:
                continue
            row, outputs = {}, {}
            for label, (cmd, extra) in configs.items():
                is_min = label.endswith("min") or label.endswith("rapido")
                reps = args.repeat_min if (is_min and name in HEAVY) else args.repeat
                runs = [timed(cmd + [str(d / f"{name}.abt")], {**base_env, **extra}) for _ in range(reps)]
                if any(r[0] is None for r in runs):
                    row[label] = dict(resultado=f"TIMEOUT (> {args.timeout} s)", repeticoes=reps)
                    print(name, label, row[label], flush=True)
                    continue
                row[label] = dict(mediana_s=round(statistics.median(r[0] for r in runs), 2), minimo_s=round(min(r[0] for r in runs), 2),
                                  rss_max_mib=round(max(r[1] for r in runs)), repeticoes=reps)
                outputs[label] = runs[0][2]
                print(name, label, row[label], flush=True)
            if (d / f"{name}.jl").exists():
                runs = [timed([args.julia, "--startup-file=no", f"--project={ROOT}", str(d / f"{name}.jl")], base_env) for _ in range(args.repeat)]
                row["julia"] = dict(mediana_s=round(statistics.median(r[0] for r in runs), 2), minimo_s=round(min(r[0] for r in runs), 2),
                                    rss_max_mib=round(max(r[1] for r in runs)), repeticoes=args.repeat)
                print(name, "julia", row["julia"], flush=True)
            # as quatro configurações ABT devem produzir exatamente a mesma saída
            row["saidas_identicas"] = len(set(outputs.values())) == 1 if outputs else None
            results["cenarios"][name] = row
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(results, indent=2, ensure_ascii=False))
    print(json.dumps({k: {c: v[c].get("mediana_s", v[c].get("resultado")) for c in v if isinstance(v[c], dict)} for k, v in results["cenarios"].items()}, indent=1, ensure_ascii=False))


main()
