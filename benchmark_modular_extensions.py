#!/usr/bin/env python3
"""Independent process timing/RSS for registered ABT operations."""
import argparse
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import tempfile

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
parser.add_argument('--repetitions', type=int, default=5)
args = parser.parse_args()
if args.repetitions < 1:
    parser.error('positive repetitions required')
env = dict(os.environ, ABT_JULIA=args.julia)
julia = [args.julia, '--startup-file=no', '--compile=min', f'--project={root}']
sources = {
    'abt_minimo': 'mostrar 1\n',
    'statsbase_isolada': 'dados = ler_csv("applications/data/vendas.csv", esquema("produto", "texto", "regiao", "texto", "unidades", "inteiro", "preco", "real"), "erro")\nmostrar contar_categorias(dados, "regiao", "erro")\n',
    'algebra_isolada': 'mostrar resolver_sistema_spd([[2.0, 0.0 - 1.0], [0.0 - 1.0, 2.0]], [1.0, 1.0])\n',
    'statsbase_algebra': 'dados = ler_csv("applications/data/vendas.csv", esquema("produto", "texto", "regiao", "texto", "unidades", "inteiro", "preco", "real"), "erro")\ncontagens = contar_categorias(dados, "regiao", "erro")\nsolucao = resolver_sistema_spd([[2.0, 0.0 - 1.0], [0.0 - 1.0, 2.0]], [1.0, 1.0])\nmostrar contagens\nmostrar solucao\n',
}
rows = []
with tempfile.TemporaryDirectory(prefix='abt-modular-bench-') as directory:
    temporary = Path(directory)
    scenarios = {'julia_minima': julia+['-e','nothing']}
    for name, source in sources.items():
        file = temporary/f'{name}.abt'
        file.write_text(source)
        scenarios[name] = [str(root/'bin/abt'),'run',str(file)]
    scenarios['app_estatistica_json'] = [str(root/'bin/abt'),'run',str(root/'applications/data/distribuicao_vendas.abt')]
    scenarios['app_algebra_json'] = [str(root/'bin/abt'),'run',str(root/'applications/engineering/rede_condutancias.abt')]
    for name, command in scenarios.items():
        for repetition in range(1,args.repetitions+1):
            result = subprocess.run(['/usr/bin/time','-v',*command],cwd=root,env=env,capture_output=True,text=True,timeout=180)
            def number(pattern):
                match = re.search(pattern,result.stderr)
                if not match:
                    raise RuntimeError(f'{name}: missing time field {pattern}')
                return float(match.group(1))
            clock = re.search(r'Elapsed \(wall clock\) time.*?: (?:(\d+):)?(\d+):(\d+\.\d+)',result.stderr)
            if not clock:
                raise RuntimeError(f'{name}: missing elapsed time')
            wall = int(clock.group(1) or 0)*3600+int(clock.group(2))*60+float(clock.group(3))
            row = dict(scenario=name,repetition=repetition,command=command,exit_code=result.returncode,
                       stdout=result.stdout,wall_seconds=wall,
                       user_seconds=number(r'User time \(seconds\): ([\d.]+)'),
                       system_seconds=number(r'System time \(seconds\): ([\d.]+)'),
                       max_rss_kb=int(number(r'Maximum resident set size \(kbytes\): (\d+)')))
            if result.returncode:
                row['stderr']=result.stderr
            rows.append(row)
            print(name,repetition,result.returncode,wall,row['max_rss_kb'],flush=True)
summary={}
for name in scenarios:
    group=[row for row in rows if row['scenario']==name and row['exit_code']==0]
    if len(group)!=args.repetitions:
        continue
    summary[name]={field:{'median':statistics.median(row[field] for row in group),
                          'minimum':min(row[field] for row in group),
                          'maximum':max(row[field] for row in group)}
                   for field in ('wall_seconds','user_seconds','system_seconds','max_rss_kb')}
output=root/'test_logs/modular_benchmark.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(dict(repetitions=args.repetitions,sources=sources,rows=rows,summary=summary),ensure_ascii=False,indent=2)+'\n')
raise SystemExit(any(row['exit_code'] for row in rows))
