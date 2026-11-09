#!/usr/bin/env python3
"""Representative process-level wall time and RSS measurements."""
import json,os,pathlib,re,subprocess,sys,tempfile
root=pathlib.Path(__file__).resolve().parent
julia=os.environ.get('ABT_JULIA','julia')
scenarios=[('minimo','mostrar 1\n','min'),('estatistica',str(root/'applications/science/estatistica.abt'),'min'),('visualizacao',str(root/'applications/science/visualizacao.abt'),'min'),('biologia',str(root/'applications/science/alinhamento.abt'),'min')]
results=[]
with tempfile.TemporaryDirectory(prefix='abt-bench-batch-') as d:
 for name,source,mode in scenarios:
  if len(sys.argv)>1 and name not in sys.argv[1:]: continue
  path=pathlib.Path(source) if source.endswith('.abt') else pathlib.Path(d)/'minimo.abt'
  if not path.is_file(): path.write_text(source)
  for repeat in range(2):
   cmd=['/usr/bin/time','-v',julia,'--startup-file=no',f'--compile={mode}','--compiled-modules=existing',f'--project={root}',str(root/'src/CLI.jl'),str(path)]
   p=subprocess.run(cmd,cwd=root,env=dict(os.environ,JULIA_PKG_PRECOMPILE_AUTO='0',XDG_CACHE_HOME='/tmp/abt-fontcache'),capture_output=True,text=True,timeout=900)
   def field(label):
    m=re.search(r'^\s*'+re.escape(label)+r':\s*(.*)$',p.stderr,re.M)
    return m.group(1) if m else None
   row=dict(scenario=name,repeat=repeat+1,compile=mode,code=p.returncode,wall=field('Elapsed (wall clock) time (h:mm:ss or m:ss)'),user_seconds=field('User time (seconds)'),system_seconds=field('System time (seconds)'),max_rss_kib=field('Maximum resident set size (kbytes)'),stdout=p.stdout,stderr=p.stderr,command=cmd)
   results.append(row); print(name,repeat+1,p.returncode,row['wall'],row['max_rss_kib'],flush=True)
   (root/'test_logs/batch_benchmark.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
