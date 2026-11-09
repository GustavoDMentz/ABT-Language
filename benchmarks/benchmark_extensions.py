#!/usr/bin/env python3
"""Repeatable process-level startup and memory measurements for extensions."""
import argparse
import json
import os
import re
import statistics
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
parser.add_argument('--repetitions', type=int, default=5)
args = parser.parse_args()
if args.repetitions < 1:
    parser.error('--repetitions must be positive')

env = dict(os.environ, ABT_JULIA=args.julia)
julia = [args.julia, '--startup-file=no', '--compile=min', f'--project={root}']
scenarios = {
    'julia_minima': julia + ['-e', 'nothing'],
    'julia_json': julia + ['-e', 'import JSON'],
    'abt_carregamento': julia + ['-e', 'include("src/ABT.jl")'],
    'abt_csv_grupos_json': [str(root/'bin/abt'), 'run', str(root/'applications/data/vendas_por_regiao_json.abt')],
}
results = []
for name, command in scenarios.items():
    for repetition in range(1, args.repetitions+1):
        run = subprocess.run(['/usr/bin/time', '-v', *command], cwd=root, env=env,
                             capture_output=True, text=True, timeout=180)
        def field(pattern):
            match = re.search(pattern, run.stderr)
            if not match:
                raise RuntimeError(f'{name}: missing time field {pattern}')
            return float(match.group(1))
        row = dict(scenario=name, repetition=repetition, command=command,
                   exit_code=run.returncode, stdout=run.stdout,
                   user_seconds=field(r'User time \(seconds\): ([\d.]+)'),
                   system_seconds=field(r'System time \(seconds\): ([\d.]+)'),
                   max_rss_kb=int(field(r'Maximum resident set size \(kbytes\): (\d+)')))
        clock = re.search(r'Elapsed \(wall clock\) time.*?: (?:(\d+):)?(\d+):(\d+\.\d+)', run.stderr)
        if not clock:
            raise RuntimeError(f'{name}: missing elapsed time')
        row['wall_seconds'] = int(clock.group(1) or 0)*3600 + int(clock.group(2))*60 + float(clock.group(3))
        if run.returncode:
            row['stderr'] = run.stderr
        results.append(row)
        print(name, repetition, run.returncode, row['wall_seconds'], row['max_rss_kb'], flush=True)

summary = {}
for name in scenarios:
    rows = [row for row in results if row['scenario'] == name and row['exit_code'] == 0]
    summary[name] = {field: dict(median=statistics.median(row[field] for row in rows),
                                 minimum=min(row[field] for row in rows),
                                 maximum=max(row[field] for row in rows))
                     for field in ('wall_seconds', 'user_seconds', 'system_seconds', 'max_rss_kb')}
output = root/'logs/test_logs/extensions_benchmark.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(dict(repetitions=args.repetitions, results=results, summary=summary),
                             ensure_ascii=False, indent=2)+'\n')
raise SystemExit(any(row['exit_code'] for row in results))
