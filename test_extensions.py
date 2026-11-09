#!/usr/bin/env python3
"""Differential contracts for grouped tables and explicit JSON encoding."""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
p.add_argument('--case', action='append')
p.add_argument('--output', default='test_logs/extensions_results.json')
a = p.parse_args()
env = dict(os.environ, ABT_JULIA=a.julia)
JULIA = [a.julia, '--startup-file=no', f'--project={ROOT}']
apps = [
    ('vendas_app', ROOT/'applications/data/vendas_por_regiao_json.abt', {'fonte':'vendas','unidade':'itens','resumo':{'grupos':[{'grupo':'Sul','quantidade':3,'soma':10,'media':10/3,'minimo':2,'maximo':5},{'grupo':'Norte','quantidade':1,'soma':8,'media':8.0,'minimo':8,'maximo':8}],'linhas_lidas':4,'linhas_ignoradas':0}}),
    ('lotes_app', ROOT/'applications/data/qualidade_lotes_json.abt', {'fonte':'qualidade_lotes','politica_ausentes':'ignorar_linha','resumo':{'grupos':[{'grupo':'A','quantidade':3,'soma':30.0,'media':10.0,'minimo':8.0,'maximo':12.0},{'grupo':'B','quantidade':1,'soma':7.5,'media':7.5,'minimo':7.5,'maximo':7.5}],'linhas_lidas':5,'linhas_ignoradas':1}}),
]
cases = [
    ('ausente_erro', 'grupo,valor\nA,1\nB,\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "erro")', None, 'valor ausente'),
    ('ausente_ignorar', 'grupo,valor\nA,1\nB,\nA,3\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "ignorar_linha")', {'grupos':[{'grupo':'A','quantidade':2,'soma':4,'media':2.0,'minimo':1,'maximo':3}],'linhas_lidas':3,'linhas_ignoradas':1}, None),
    ('vazia', 'grupo,valor\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "erro")', {'grupos':[],'linhas_lidas':0,'linhas_ignoradas':0}, None),
    ('coluna_inexistente', 'grupo,valor\nA,1\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "x", "erro")', None, 'coluna de valor inexistente'),
    ('grupo_numerico', 'grupo,valor\n1,2\n', 'grupo:inteiro,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "erro")', None, 'coluna de grupo deve ser texto'),
    ('valor_texto', 'grupo,valor\nA,x\n', 'grupo:texto,valor:texto', 'resumir_grupos(dados, "grupo", "valor", "erro")', None, 'coluna de valor deve ser numérica'),
    ('politica_invalida', 'grupo,valor\nA,1\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "adivinhar")', None, 'política de ausentes'),
    ('overflow', 'grupo,valor\nA,9223372036854775807\nA,1\n', 'grupo:texto,valor:inteiro', 'resumir_grupos(dados, "grupo", "valor", "erro")', None, 'soma excede Int64'),
    ('json_tabela', 'grupo,valor\nA,1\n', 'grupo:texto,valor:inteiro', 'codificar_json(dados, "erro")', {'colunas':['grupo','valor'],'registros':[{'grupo':'A','valor':1}]}, None),
    ('json_ausente_erro', 'grupo,valor\nA,\n', 'grupo:texto,valor:inteiro', 'codificar_json(dados, "erro")', None, 'valor ausente'),
    ('json_ausente_nulo', 'grupo,valor\nA,\n', 'grupo:texto,valor:inteiro', 'codificar_json(dados, "nulo")', {'colunas':['grupo','valor'],'registros':[{'grupo':'A','valor':None}]}, None),
    ('json_politica_invalida', 'grupo,valor\nA,1\n', 'grupo:texto,valor:inteiro', 'codificar_json(dados, "ignorar")', None, 'política de ausentes'),
    ('json_nan', 'grupo,valor\nA,1\n', 'grupo:texto,valor:inteiro', 'codificar_json(registro("x", 0 / 0), "erro")', None, 'número não finito'),
]
results=[]
with tempfile.TemporaryDirectory(prefix='abt-extensions-') as d:
    tmp=Path(d)
    jobs=[]
    for name,path,expected in apps:
        jobs.append((name,path,None,expected,None))
    for name,data,schema,expression,expected,error in cases:
        fixture=tmp/f'{name}.csv'
        fixture.write_text(data)
        pairs=[]
        for field in schema.split(','):
            field_name,kind=field.split(':')
            pairs.extend([field_name,kind])
        schema_args=', '.join(json.dumps(v) for v in pairs)
        shown = f'codificar_json({expression}, "erro")' if expected is not None and name in ('ausente_ignorar', 'vazia') else expression
        source=f'dados = ler_csv({json.dumps(str(fixture))}, esquema({schema_args}), "permitir")\nmostrar {shown}\n'
        program=tmp/f'{name}.abt'
        program.write_text(source)
        jobs.append((name,program,source,expected,error))
    for name,program,source,expected,error in jobs:
        if a.case and name not in a.case:
            continue
        commands=[('interpretador',[str(ROOT/'bin/abt'),'run',str(program)])]
        for no_opt,label in [(True,'gerado_sem_otimizacao'),(False,'gerado_otimizado')]:
            generated=tmp/f'{name}_{label}.jl'
            emit=JULIA+[str(ROOT/'pseudo.jl'),str(program),'--emit-julia',str(generated),'--no-run']
            if no_opt: emit.append('--no-opt')
            done=subprocess.run(emit,cwd=ROOT,env=env,capture_output=True,text=True,timeout=120)
            if done.returncode:
                results.append({'case':name,'backend':label,'status':'FAIL','phase':'emit','source':source,'stdout':done.stdout,'stderr':done.stderr})
                continue
            commands.append((label,JULIA+[str(generated)]))
        observed=[]
        for label,command in commands:
            done=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=120)
            if error:
                ok=done.returncode!=0 and error in done.stderr
            else:
                try: value=json.loads(done.stdout)
                except (ValueError,TypeError): value=None
                ok=done.returncode==0 and value==expected
            observed.append((done.returncode,done.stdout,done.stderr))
            results.append({'case':name,'backend':label,'status':'PASS' if ok else 'FAIL','source':source,'expected':expected,'error':error,'returncode':done.returncode,'stdout':done.stdout,'stderr':done.stderr,'command':command})
            print('PASS' if ok else 'FAIL',name,label,flush=True)
        if not error and len(observed)==3 and all(x[0]==0 for x in observed):
            if len({x[1] for x in observed})!=1:
                results.append({'case':name,'status':'FAIL','phase':'stdout_parity','observed':observed})
Path('test_logs').mkdir(exist_ok=True)
Path(a.output).write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Resumo:',{s:sum(x['status']==s for x in results) for s in ('PASS','FAIL')})
raise SystemExit(any(x['status']!='PASS' for x in results))
