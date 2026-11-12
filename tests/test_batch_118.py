#!/usr/bin/env python3
"""Consolidated three-backend ABT 0.11.8 batch regression. Run from repository root."""
import json, math, os, pathlib, subprocess, sys, tempfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
JULIA=os.environ.get('ABT_JULIA','julia')
BASE=[JULIA,'--startup-file=no','--compile=min','--compiled-modules=existing',f'--project={ROOT}']
ENV=dict(os.environ, JULIA_PKG_PRECOMPILE_AUTO='0')
CASES=[
 ('unario_precedencia','a = 2\nb = 3\nmostrar -2^2\nmostrar (-2)^2\nmostrar 2^3^2\nmostrar 2.0^-2\nmostrar -3.14\nmostrar -(a+b)\nmostrar a * -b\nmostrar +3.14\n','-4\n4\n512\n0.25\n-3.14\n-5\n-6\n3.14\n',None),
 ('logica_precedencia','mostrar verdadeiro ou falso e falso\nmostrar falso e verdadeiro ou verdadeiro\n','true\ntrue\n',None),
 ('unario_invalido','mostrar -"texto"\n',None,'requires a number'),
 ('potencia_invalida','mostrar 2 ^ "texto"\n',None,'requires numbers'),
 ('normal_invalida','mostrar probabilidade_normal(0.0, 0.0, 1.0)\n',None,'desvio deve ser positivo'),
 ('grafico_spec','dados = ler_csv(\"applications/science/experimento.csv\", esquema(\"tratamento\", \"texto\", \"resposta\", \"real\", \"tempo\", \"inteiro\"), \"erro\")\nmostrar codificar_json(grafico(dados, \"tempo\", \"resposta\", \"pontos\"), \"erro\")\n',None,None),
 ('categoria_invalida','dados = ler_csv(\"applications/science/experimento.csv\", esquema(\"tratamento\", \"texto\", \"resposta\", \"real\", \"tempo\", \"inteiro\"), \"erro\")\nmostrar categorias(dados, \"tratamento\", [\"controle\"], \"erro\")\n',None,'fora dos níveis'),
 ('grupo_invalido','dados = ler_csv(\"applications/science/experimento.csv\", esquema(\"tratamento\", \"texto\", \"resposta\", \"real\", \"tempo\", \"inteiro\"), \"erro\")\ngrupos = agrupar_dados(dados, \"tratamento\", \"resposta\", \"erro\")\nmostrar testar_grupos(grupos, \"controle\", \"inexistente\", \"welch\")\n',None,'os dois grupos devem existir'),
 ('estatistica',str(ROOT/'applications/science/estatistica.abt'),None,None),
 ('bio_id_invalido','f = ler_fasta(\"applications/science/amostras.fasta\", \"DNA\", \"rejeitar\", \"exigir_maiusculas\")\nmostrar alinhar_sequencias(f, \"amostra_a\", \"x\", \"global\", 2, -1, -3, -1)\n',None,'identificador inexistente'),
 ('bio',str(ROOT/'applications/science/alinhamento.abt'),None,None),
]
def run(command,timeout=240):
 try:
  p=subprocess.run(command,cwd=ROOT,env=ENV,capture_output=True,text=True,timeout=timeout)
  return dict(code=p.returncode,stdout=p.stdout,stderr=p.stderr,command=command)
 except subprocess.TimeoutExpired as e:
  return dict(code=None,stdout=(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else (e.stdout or ''),stderr='TIMEOUT',command=command)
def semantic_check(name, output):
 try: value=json.loads(output)
 except (ValueError,TypeError): return False
 if name=='estatistica':
  t=value['teste']; c=value['categorias']['categorias']; p=value['referencia_normal']['probabilidade_acima']
  return t['n_a']==t['n_b']==4 and t['media_a']==10.125 and t['media_b']==14.125 and math.isclose(t['p_valor'],0.0005701755793736388,rel_tol=1e-10) and [r['quantidade'] for r in c]==[4,4] and math.isclose(p,0.024997895148220435,rel_tol=1e-10)
 if name=='bio':
  a=value['alinhamento']; r=value['resumo']
  return a['pontuacao']==18 and a['correspondencias']==10 and a['diferencas']==2 and r['sequencias']==2 and r['GC_percentual']==50.0
 if name=='grafico_spec':
  return value['tipo']=='grafico_abt' and len(value['x'])==len(value['y'])==8 and value['modo']=='pontos'
 return True
results=[]
with tempfile.TemporaryDirectory(prefix='abt-batch-') as d:
 tmp=pathlib.Path(d)
 for name,source,expected,error in CASES:
  program=pathlib.Path(source) if source.endswith('.abt') and pathlib.Path(source).is_file() else tmp/(name+'.abt')
  if not program.is_file(): program.write_text(source)
  commands=[('interpretador',BASE+[str(ROOT/'src/CLI.jl'),str(program)])]
  for opt,label in [(False,'gerado_sem_otimizacao'),(True,'gerado_otimizado')]:
   target=tmp/(name+'_'+label+'.jl')
   emit=run(BASE+[str(ROOT/'pseudo.jl'),str(program),'--emit-julia',str(target),'--no-run']+([] if opt else ['--no-opt']))
   if emit['code']!=0:
    ok=error is not None and error in (emit['stdout']+emit['stderr'])
    results.append(dict(case=name,backend=label,status='PASS' if ok else 'FAIL',phase='emit',**emit)); continue
   commands.append((label,BASE+[str(target)]))
  observed=[]
  for label,command in commands:
   result=run(command)
   if error: ok=result['code']!=0 and error in result['stderr']
   elif expected is not None: ok=result['code']==0 and result['stdout']==expected
   else: ok=result['code']==0 and semantic_check(name,result['stdout'])
   result.update(case=name,backend=label,status='PASS' if ok else 'FAIL')
   results.append(result); observed.append(result)
   print(result['status'],name,label,flush=True)
  if expected is None and error is None and len(observed)==3 and all(r['code']==0 for r in observed):
   if len(set(r['stdout'] for r in observed))!=1:
    results.append(dict(case=name,status='FAIL',phase='stdout_parity',observed=[r['stdout'] for r in observed]))
path=ROOT/os.environ.get('ABT_TEST_LOG_DIR','logs/test_logs')/'batch_118_results.json';path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Resumo', {s:sum(r['status']==s for r in results) for s in ('PASS','FAIL')})
sys.exit(any(r['status']!='PASS' for r in results))
