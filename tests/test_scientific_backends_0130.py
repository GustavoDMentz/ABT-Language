#!/usr/bin/env python3
"""Compare interpreted ABT and both Julia generation modes on scientific cases."""
from pathlib import Path
import json, math, os, subprocess, tempfile
ROOT=Path(__file__).resolve().parent.parent
JULIA=os.environ.get('ABT_JULIA','julia')
ENV=dict(os.environ,ABT_JULIA=JULIA)
ENV['XDG_CACHE_HOME']=str(Path(tempfile.gettempdir())/'abt0130-font-cache')
Path(ENV['XDG_CACHE_HOME']).mkdir(parents=True,exist_ok=True)
CASES=[
 ('fastq','h=ler_fastq("applications/scientific_0130/data/reads.fastq","DNA","rejeitar","phred33")\nmostrar codificar_json(resumir_fastq(h),"erro")\n',None),
 ('records','h=ler_fastq("applications/scientific_0130/data/reads.fastq","DNA","rejeitar","phred33")\nmostrar codificar_json(registros_fastq(h),"erro")\n',None),
 ('dna','mostrar codificar_json(registro("k",frequencias_kmers("ACGTAC",2),"r",complemento_reverso("ACGTN"),"p",traduzir_dna("ATGGAA")),"erro")\n',None),
 ('linear','a=[[4.0,1.0],[1.0,3.0]]\nmostrar codificar_json(registro("x",resolver_sistema(a,[1.0,2.0]),"svd",decompor_matriz(a,"svd"),"d",determinante_matriz(a),"r",posto_matriz(a,0.0)),"erro")\n',None),
 ('matrices','a=[[1.0,2.0],[3.0,4.0]]\nmostrar codificar_json(registro("m",produto_matricial(a,a),"t",transpor_matriz(a),"qr",decompor_matriz(a,"qr")),"erro")\n',None),
 ('pvalues','mostrar codificar_json(ajustar_valores_p([0.01,0.04,0.2],"by",0.05),"erro")\n',None),
 ('optimization','mostrar codificar_json(minimizar_polinomio([1.0,-2.0,1.0],-2.0,3.0,0.00000001,0.0000000001,100),"erro")\n',None),
 ('tables','t=ler_csv("applications/scientific_0130/data/expressao.csv",esquema("gene","texto","log2fc","real","p_valor","real"),"erro")\ns=selecionar_colunas(t,["gene","p_valor"])\nr=renomear_colunas(s,["p_valor"],["p"])\nmostrar codificar_json(linhas_tabela(ordenar_tabela(remover_duplicatas(r,["gene"]),["p"],["crescente"],"erro")),"erro")\n',None),
 ('join','t=ler_csv("applications/scientific_0130/data/expressao.csv",esquema("gene","texto","log2fc","real","p_valor","real"),"erro")\na=selecionar_colunas(t,["gene","p_valor"])\nb=renomear_colunas(a,["p_valor"],["p"])\nmostrar codificar_json(linhas_tabela(juntar_tabelas(a,b,["gene"],"interna")),"erro")\n',None),
 ('bad_fastq','h=ler_fastq("applications/scientific_0130/data/reads.fastq","DNA","rejeitar","wrong")\nmostrar resumir_fastq(h)\n','ler_fastq'),
 ('bad_pvalue','mostrar ajustar_valores_p([1.2],"holm",0.05)\n','ajustar_valores_p'),
 ('singular','mostrar resolver_sistema([[1.0,2.0],[2.0,4.0]],[1.0,2.0])\n','resolver_sistema'),
]
for name in ('sequenciamento','expressao','algebra','visualizacao'):
 CASES.append((name,(ROOT/'applications/scientific_0130'/f'{name}.abt').read_text(),None))
EXPECTED={
 'sequenciamento':('id = "leitura_1"','id = "leitura_2"','phred_medio = 35.0'),
 'expressao':('genes = ["G1", "G2", "G3"]','ajustados = [0.003, 0.06, 0.2]'),
 'algebra':('solucao = ','singulares = '),
 'visualizacao':('pontos = 4',),
}

def same(a,b):
 if type(a)!=type(b):return False
 if isinstance(a,dict):return a.keys()==b.keys() and all(same(a[k],b[k]) for k in a)
 if isinstance(a,list):return len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
 if isinstance(a,float):return math.isclose(a,b,rel_tol=1e-10,abs_tol=1e-10)
 return a==b

def scrub(s):return s.replace(str(ROOT),'<ABT_REPO>').replace(str(Path.home()),'<USER_HOME>')
def check(name,source,error):
 with tempfile.TemporaryDirectory(prefix='abt0130-') as td:
  tmp=Path(td); sourcepath=tmp/'case.abt'; sourcepath.write_text(source)
  figure=tmp/'figure.png'; run_env=dict(ENV,ABT_0130_FIGURA=str(figure))
  runs=[subprocess.run([str(ROOT/'bin/abt'),'run',str(sourcepath)],cwd=ROOT,env=run_env,text=True,capture_output=True,timeout=180)]
  for opt in (False,True):
   target=tmp/('opt.jl' if opt else 'plain.jl')
   cmd=[JULIA,'--startup-file=no',f'--project={ROOT}',str(ROOT/'pseudo.jl'),str(sourcepath),'--emit-julia',str(target),'--no-run']
   if not opt:cmd.append('--no-opt')
   emit=subprocess.run(cmd,cwd=ROOT,env=run_env,text=True,capture_output=True,timeout=180)
   if emit.returncode:return {'case':name,'status':'FAIL','stage':'emit','detail':scrub(emit.stderr)}
   runs.append(subprocess.run([JULIA,'--startup-file=no',f'--project={ROOT}',str(target)],cwd=ROOT,env=run_env,text=True,capture_output=True,timeout=180))
  if error:
   ok=all(r.returncode!=0 and error in r.stderr for r in runs)
  else:
   try:
    values=[json.loads(r.stdout) if r.stdout.lstrip().startswith(('{','[')) else r.stdout for r in runs]
    ok=all(r.returncode==0 and not r.stderr for r in runs) and same(values[0],values[1]) and same(values[0],values[2])
    ok=ok and all(all(token in r.stdout for token in EXPECTED.get(name,())) for r in runs)
    if name=='visualizacao':ok=ok and figure.is_file() and figure.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
   except ValueError:ok=False
  return {'case':name,'status':'PASS' if ok else 'FAIL','codes':[r.returncode for r in runs], 'stdout':[scrub(r.stdout) for r in runs], 'stderr':[scrub(r.stderr) for r in runs]}
results=[]
for case in CASES:
 result=check(*case)
 results.append(result)
 print(result['status'],result['case'],flush=True)
path=ROOT/'logs/scientific_0130/backends.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Resumo:',{x:sum(r['status']==x for r in results) for x in ('PASS','FAIL')})
raise SystemExit(any(r['status']!='PASS' for r in results))
