#!/usr/bin/env python3
"""Independent process RSS and wall/CPU benchmark for the FASTA summary."""
import argparse
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
p.add_argument('--repetitions', type=int, default=3)
a = p.parse_args()
if a.repetitions < 1: p.error('repetitions must be positive')
env = dict(os.environ, ABT_JULIA=a.julia)
results = []
with tempfile.TemporaryDirectory(prefix='abt-bio-bench-') as d:
    tmp = Path(d)
    for name, records, length in [('pequeno', 1, 100), ('medio', 10, 10000), ('grande', 100, 10000)]:
        fasta = tmp / f'{name}.fasta'
        with fasta.open('w') as out:
            for i in range(records):
                out.write(f'>seq{i}\n')
                out.write('ACGT' * (length // 4) + '\n')
        source = tmp / f'{name}.abt'
        source.write_text(f'f = ler_fasta({json.dumps(str(fasta))}, "DNA", "rejeitar", "exigir_maiusculas")\nmostrar descrever_sequencias(f)\n')
        expected = f'(sequencias = {records}, bases = {records*length}, A = {records*length//4}, C = {records*length//4}, G = {records*length//4}, T = {records*length//4}, N = 0, GC_percentual = 50.0)\n'
        generated = tmp / f'{name}.jl'
        emit = subprocess.run([a.julia, '--startup-file=no', f'--project={ROOT}', str(ROOT/'pseudo.jl'), str(source), '--emit-julia', str(generated), '--no-run'], cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
        if emit.returncode: raise RuntimeError(emit.stderr)
        for backend in ('interpretador', 'gerado'):
            for compile_mode in ('min', 'all'):
                for repetition in range(1, a.repetitions + 1):
                    timing = tmp / 'timing.txt'
                    if backend == 'interpretador':
                        command = [str(ROOT/'bin/abt'), 'run', str(source)]
                        local_env = dict(env, ABT_JULIA_COMPILE=compile_mode)
                    else:
                        command = [a.julia, '--startup-file=no', f'--compile={compile_mode}', f'--project={ROOT}', str(generated)]
                        local_env = env
                    proc = subprocess.run(['/usr/bin/time', '-v', '-o', str(timing), *command], cwd=ROOT, env=local_env, capture_output=True, text=True, timeout=600)
                    data = timing.read_text()
                    def number(label):
                        match = re.search(r'^\s*' + re.escape(label) + r':\s*(.*)$', data, re.MULTILINE)
                        return match.group(1) if match else None
                    row = dict(size=name, records=records, bases=records*length, backend=backend, compile=compile_mode, repetition=repetition,
                               seconds_user=float(number('User time (seconds)')), seconds_system=float(number('System time (seconds)')),
                               elapsed=number('Elapsed (wall clock) time (h:mm:ss or m:ss)'), rss_kb=int(number('Maximum resident set size (kbytes)')),
                               input_bytes=fasta.stat().st_size, status='PASS' if proc.returncode == 0 and proc.stdout == expected else 'FAIL',
                               stdout=proc.stdout, stderr=proc.stderr, command=command)
                    results.append(row)
                    Path('test_logs').mkdir(exist_ok=True)
                    Path('test_logs/bio_benchmark.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
                    print(row['status'], name, backend, compile_mode, repetition, row['elapsed'], row['rss_kb'], flush=True)
Path('test_logs').mkdir(exist_ok=True)
Path('test_logs/bio_benchmark.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
print('Resumo:', {s: sum(x['status']==s for x in results) for s in ('PASS','FAIL')})
raise SystemExit(any(x['status'] != 'PASS' for x in results))
