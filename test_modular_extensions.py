#!/usr/bin/env python3
"""Three-backend tests for the StatsBase and LinearAlgebra ABT extensions."""
import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
parser.add_argument('--case', action='append')
args = parser.parse_args()
env = dict(os.environ, ABT_JULIA=args.julia)
julia = [args.julia, '--startup-file=no', f'--project={root}']

def same(actual, expected):
    if isinstance(expected, float):
        return isinstance(actual, (float, int)) and math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12)
    if isinstance(expected, dict):
        return isinstance(actual, dict) and actual.keys() == expected.keys() and all(same(actual[k], v) for k, v in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(same(a, b) for a, b in zip(actual, expected))
    return actual == expected

stats_expected = {'fonte':'vendas','dimensao':'regiao','distribuicao':{'categorias':[
    {'categoria':'Sul','quantidade':3,'proporcao':0.75},
    {'categoria':'Norte','quantidade':1,'proporcao':0.25}],
    'linhas_lidas':4,'linhas_ignoradas':0}}
linear_expected = {'modelo':'rede_condutancias','tensoes':[1.0,1.0],'residuo_norma':0.0}

cases = [
    ('vendas_estatistica_json', root/'applications/data/distribuicao_vendas.abt', stats_expected, None),
    ('rede_algebra_json', root/'applications/engineering/rede_condutancias.abt', linear_expected, None),
    ('categorias_vazias', 'dados = ler_csv("{csv}", esquema("grupo", "texto"), "erro")\nmostrar codificar_json(contar_categorias(dados, "grupo", "erro"), "erro")\n', {'categorias':[], 'linhas_lidas':0,'linhas_ignoradas':0}, None),
    ('ausente_erro', 'dados = ler_csv("{csv}", esquema("grupo", "texto", "medida", "inteiro"), "permitir")\nmostrar contar_categorias(dados, "grupo", "erro")\n', None, 'valor ausente'),
    ('ausente_ignorar', 'dados = ler_csv("{csv}", esquema("grupo", "texto", "medida", "inteiro"), "permitir")\nmostrar codificar_json(contar_categorias(dados, "grupo", "ignorar_linha"), "erro")\n', {'categorias':[{'categoria':'A','quantidade':2,'proporcao':1.0}],'linhas_lidas':3,'linhas_ignoradas':1}, None),
    ('coluna_inexistente', 'dados = ler_csv("{csv}", esquema("grupo", "texto"), "erro")\nmostrar contar_categorias(dados, "x", "erro")\n', None, 'coluna inexistente'),
    ('coluna_numerica', 'dados = ler_csv("{csv}", esquema("grupo", "inteiro"), "erro")\nmostrar contar_categorias(dados, "grupo", "erro")\n', None, 'coluna deve ser texto'),
    ('politica_invalida', 'dados = ler_csv("{csv}", esquema("grupo", "texto"), "erro")\nmostrar contar_categorias(dados, "grupo", "adivinhar")\n', None, 'política de ausentes'),
    ('matriz_nao_quadrada', 'mostrar resolver_sistema_spd([[1.0, 2.0]], [3.0])\n', None, 'linha 1 deve ter 1 valores'),
    ('matriz_inteira', 'mostrar resolver_sistema_spd([[2]], [2.0])\n', None, 'Float64 finito'),
    ('matriz_assimetrica', 'mostrar resolver_sistema_spd([[2.0, 1.0], [0.0, 2.0]], [3.0, 2.0])\n', None, 'não simétrica'),
    ('matriz_nao_positiva', 'mostrar resolver_sistema_spd([[1.0, 0.0], [0.0, 0.0]], [1.0, 1.0])\n', None, 'fatoração/solução'),
    ('vetor_invalido', 'mostrar resolver_sistema_spd([[2.0]], [2])\n', None, 'vetor[1] deve ser Float64 finito'),
    ('numero_nao_finito', 'mostrar resolver_sistema_spd([[0.0 / 0.0]], [1.0])\n', None, 'Float64 finito'),
    ('sombreamento', 'contar_categorias = 7\nmostrar contar_categorias\n', '7\n', None),
    ('funcao_mesmo_nome', 'função contar_categorias(x) { retornar x + 1 }\nmostrar contar_categorias(2)\n', '3\n', None),
    ('tipo_estatico', 'mostrar resolver_sistema_spd(1, [])\n', None, 'argument 1 expects list'),
]
fixtures = {
    'categorias_vazias':'grupo\n',
    'ausente_erro':'grupo,medida\nA,1\n,2\n',
    'ausente_ignorar':'grupo,medida\nA,1\n,2\nA,3\n',
    'coluna_inexistente':'grupo\nA\n',
    'coluna_numerica':'grupo\n1\n',
    'politica_invalida':'grupo\nA\n',
}
results = []
with tempfile.TemporaryDirectory(prefix='abt-modular-') as directory:
    temporary = Path(directory)
    for name, source, expected, error in cases:
        if args.case and name not in args.case:
            continue
        if isinstance(source, Path):
            program = source
            text = source.read_text()
        else:
            fixture = temporary/f'{name}.csv'
            fixture.write_text(fixtures.get(name, ''))
            text = source.replace('{csv}', str(fixture))
            program = temporary/f'{name}.abt'
            program.write_text(text)
        commands = [('interpretador', [str(root/'bin/abt'), 'run', str(program)])]
        for label, extra in [('gerado_sem_otimizacao', ['--no-opt']), ('gerado_otimizado', [])]:
            generated = temporary/f'{name}_{label}.jl'
            emit = subprocess.run(julia+[str(root/'pseudo.jl'),str(program),'--emit-julia',str(generated),'--no-run',*extra],
                                  cwd=root, env=env, capture_output=True, text=True, timeout=120)
            if emit.returncode:
                status = 'PASS' if error and error in emit.stderr else 'FAIL'
                results.append(dict(case=name, backend=label, status=status, phase='emit', source=text,
                                    stdout=emit.stdout, stderr=emit.stderr))
                print(status, name, label, 'emit', flush=True)
            else:
                commands.append((label, julia+[str(generated)]))
        observed = []
        for label, command in commands:
            run = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=120)
            if error:
                passed = run.returncode != 0 and error in run.stderr
            elif isinstance(expected, str):
                passed = run.returncode == 0 and run.stdout == expected
            else:
                try:
                    parsed = json.loads(run.stdout)
                except ValueError:
                    parsed = None
                passed = run.returncode == 0 and same(parsed, expected)
            status = 'PASS' if passed else 'FAIL'
            results.append(dict(case=name, backend=label, status=status, phase='run', source=text,
                                command=command, returncode=run.returncode, stdout=run.stdout, stderr=run.stderr))
            observed.append((label, run.returncode, run.stdout))
            print(status, name, label, flush=True)
        if not error and len(observed) == 3 and len({item[2] for item in observed}) != 1:
            results.append(dict(case=name, status='FAIL', phase='stdout_parity', observed=observed))
            print('FAIL', name, 'stdout_parity', flush=True)

output = root/'test_logs/modular_results.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n')
print('Resumo:', {status:sum(row['status']==status for row in results) for status in ('PASS','FAIL')})
raise SystemExit(any(row['status'] != 'PASS' for row in results))
