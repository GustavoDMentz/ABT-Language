#!/usr/bin/env python3
"""Cold-process scientific benchmark: startup, load, first call, steady calls, RSS."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
parser.add_argument('--repetitions', type=int, default=3)
parser.add_argument('--iterations', type=int, default=20)
parser.add_argument('--output', default='logs/scientific_0130/benchmark.json')
args = parser.parse_args()
if args.repetitions < 1 or args.iterations < 1:
    parser.error('repetitions and iterations must be positive')

workloads = {
    'valores_p': {
        'abt': 'mostrar ajustar_valores_p([0.01,0.04,0.2],"bh",0.05)',
        'direct_import': 'using MultipleTesting',
        'direct_call': 'MultipleTesting.adjust([0.01,0.04,0.2],MultipleTesting.BenjaminiHochberg())',
    },
    'matriz': {
        'abt': 'mostrar resolver_sistema([[4.0,1.0],[1.0,3.0]],[1.0,2.0])',
        'direct_import': 'using LinearAlgebra',
        'direct_call': '([4.0 1.0; 1.0 3.0] \\ [1.0,2.0])',
    },
}

def source(work, backend):
    if backend == 'ABT':
        load = 'using ABT'
        setup = f'''src = {json.dumps(work['abt'])}
ast = ABT.parse_program(ABT.tokenize(src))'''
        call = 'ABT.execute(ast)'
    else:
        load = work['direct_import']
        setup = 'nothing'
        call = work['direct_call']
    return f'''t0=time_ns()
@eval {load}
t1=time_ns()
{setup}
t2=time_ns()
first_result={call}
t3=time_ns()
for _ in 1:{args.iterations}
    {call}
end
t4=time_ns()
println("STAGES ", (t1-t0)/1e9, " ", (t2-t1)/1e9, " ", (t3-t2)/1e9, " ", (t4-t3)/1e9)
'''

results = []
for name, work in workloads.items():
    for backend in ('Julia', 'ABT'):
        for repetition in range(1, args.repetitions + 1):
            with tempfile.TemporaryDirectory(prefix='abt0130-bench-') as td:
                script = Path(td) / 'bench.jl'
                timer = Path(td) / 'time.txt'
                script.write_text(source(work, backend))
                command = ['/usr/bin/time', '-v', '-o', str(timer), args.julia,
                           '--startup-file=no', f'--project={ROOT}', str(script)]
                process = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
                timing = timer.read_text()
                stages = re.search(r'^STAGES (.*)$', process.stdout, re.M)
                rss = re.search(r'Maximum resident set size \(kbytes\):\s*(\d+)', timing)
                elapsed = re.search(r'^\s*Elapsed \(wall clock\) time \(h:mm:ss or m:ss\):\s*(.+)$', timing, re.M)
                results.append({
                    'workload': name, 'backend': backend, 'repetition': repetition,
                    'command': '/usr/bin/time -v julia --startup-file=no --project=. bench.jl',
                    'exit_code': process.returncode,
                    'stages_seconds': dict(zip(('library_load', 'prepare', 'first_call', 'repeated_calls'),
                                               map(float, stages.group(1).split()))) if stages else None,
                    'repeated_iterations': args.iterations,
                    'process_wall': elapsed.group(1) if elapsed else None,
                    'maximum_rss_kib': int(rss.group(1)) if rss else None,
                    'stderr': process.stderr[-3000:].replace(str(ROOT), '<ABT_REPO>').replace(str(Path.home()), '<USER_HOME>'),
                })
                print(name, backend, repetition, 'PASS' if process.returncode == 0 and stages and rss else 'FAIL', flush=True)
out = ROOT / args.output
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({'method': 'independent cold processes; first call includes Julia compilation; repeated calls are warm', 'results': results}, indent=2, ensure_ascii=False) + '\n')
raise SystemExit(any(r['exit_code'] != 0 or r['stages_seconds'] is None or r['maximum_rss_kib'] is None for r in results))
