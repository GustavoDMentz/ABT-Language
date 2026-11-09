#!/usr/bin/env python3
"""Three-backend figure export with byte-level output parity."""
import hashlib,json,os,pathlib,subprocess,sys,tempfile
root=pathlib.Path(__file__).resolve().parent
julia=os.environ.get('ABT_JULIA','julia')
base=[julia,'--startup-file=no','--compile=min','--compiled-modules=existing',f'--project={root}']
source=root/'applications/science/visualizacao.abt'
results=[]
with tempfile.TemporaryDirectory(prefix='abt-chart-') as d:
 out=pathlib.Path(d)/'figura.png'
 env=dict(os.environ,ABT_FIGURA_PATH=str(out),XDG_CACHE_HOME=str(pathlib.Path(d)/'cache'),JULIA_PKG_PRECOMPILE_AUTO='0')
 for optimized,label in [(None,'interpretador'),(False,'gerado_sem_otimizacao'),(True,'gerado_otimizado')]:
  if optimized is None:
   command=base+[str(root/'src/CLI.jl'),str(source)]
  else:
   generated=pathlib.Path(d)/(label+'.jl')
   emit=base+[str(root/'pseudo.jl'),str(source),'--emit-julia',str(generated),'--no-run']+([] if optimized else ['--no-opt'])
   e=subprocess.run(emit,cwd=root,env=env,capture_output=True,text=True,timeout=120)
   if e.returncode:
    results.append(dict(backend=label,status='FAIL',phase='emit',stderr=e.stderr,stdout=e.stdout,command=emit));continue
   command=base+[str(generated)]
  if out.exists():out.unlink()
  r=subprocess.run(command,cwd=root,env=env,capture_output=True,text=True,timeout=120)
  data=out.read_bytes() if out.exists() else b''
  ok=r.returncode==0 and data.startswith(b'\x89PNG\r\n\x1a\n') and len(data)>1000
  results.append(dict(backend=label,status='PASS' if ok else 'FAIL',code=r.returncode,stdout=r.stdout,stderr=r.stderr,size=len(data),sha256=hashlib.sha256(data).hexdigest(),command=command))
  print(results[-1]['status'],label,len(data),flush=True)
 valid=[x for x in results if x['status']=='PASS']
 parity=len(valid)==3 and len({x['stdout'] for x in valid})==1 and len({x['sha256'] for x in valid})==1
 results.append(dict(check='observable_parity',status='PASS' if parity else 'FAIL'))
 svg=pathlib.Path(d)/'figura.svg'
 svg_env=dict(env,ABT_FIGURA_PATH=str(svg))
 svg_run=subprocess.run(base+[str(root/'src/CLI.jl'),str(source)],cwd=root,env=svg_env,capture_output=True,text=True,timeout=120)
 svg_data=svg.read_bytes() if svg.exists() else b''
 svg_ok=svg_run.returncode==0 and b'<svg' in svg_data[:500]
 results.append(dict(check='svg_export',status='PASS' if svg_ok else 'FAIL',code=svg_run.returncode,stdout=svg_run.stdout,stderr=svg_run.stderr,size=len(svg_data)))
 invalid_env=dict(env,ABT_FIGURA_PATH=str(pathlib.Path(d)/'figura.txt'))
 invalid_run=subprocess.run(base+[str(root/'src/CLI.jl'),str(source)],cwd=root,env=invalid_env,capture_output=True,text=True,timeout=120)
 invalid_ok=invalid_run.returncode!=0 and 'caminho deve terminar' in invalid_run.stderr
 results.append(dict(check='invalid_format',status='PASS' if invalid_ok else 'FAIL',code=invalid_run.returncode,stdout=invalid_run.stdout,stderr=invalid_run.stderr))
(root/'test_logs/batch_chart_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('parity',parity)
sys.exit(any(x['status']!='PASS' for x in results))
