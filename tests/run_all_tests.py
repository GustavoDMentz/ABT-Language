#!/usr/bin/env python3
"""Execute each ABT test file in a fresh Julia process and summarize failures.
Usage: python3 run_all_tests.py [--timeout 120] [--julia julia]
"""
import argparse, pathlib, subprocess, json, time, sys
p=argparse.ArgumentParser(); p.add_argument('--timeout',type=int,default=120); p.add_argument('--julia',default='julia'); p.add_argument('--log-dir',default='logs/test_logs'); args=p.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent
log_dir=root/args.log_dir
files=sorted((root/'tests').glob('test_*.jl')) + [root/'tests'/'runtests.jl',root/'tests'/'break_abt.jl',root/'tests'/'audit_adversarial.jl']
probes={'break_abt.jl','audit_adversarial.jl'}
results=[]
for f in files:
    started=time.monotonic()
    try:
        run=subprocess.run([args.julia,'--startup-file=no',f'--project={root}',str(f)],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=args.timeout)
        output=run.stdout
        status='FAIL' if run.returncode else ('PARTIAL' if 'Broken  Total' in output else ('PROBE' if f.name in probes else 'PASS'))
    except subprocess.TimeoutExpired as exc:
        status='TIMEOUT'; output=(exc.stdout or b'').decode(errors='replace') if isinstance(exc.stdout,bytes) else (exc.stdout or '')
    except FileNotFoundError:
        print('Julia não encontrado. Instale Julia ou passe --julia CAMINHO',file=sys.stderr); sys.exit(2)
    duration=round(time.monotonic()-started,2)
    log_dir.mkdir(parents=True,exist_ok=True)
    (log_dir/f'{f.stem}.log').write_text(output)
    results.append({'file':f.name,'status':status,'seconds':duration,'log':str((log_dir/f'{f.stem}.log').relative_to(root))})
    print(f'{status:7s} {duration:7.2f}s  {f.name}',flush=True)
(log_dir/'summary.json').write_text(json.dumps({'results':results,'included_tests':['runtests_legacy.jl (via runtests.jl)'],'probe_only':sorted(probes)},indent=2,ensure_ascii=False))
print('Resumo:', {s:sum(r['status']==s for r in results) for s in ['PASS','PROBE','PARTIAL','FAIL','TIMEOUT']})
print('OBS: audit_adversarial.jl é exploratório; PASS não significa ausência de findings.')
sys.exit(1 if any(r['status'] not in ('PASS','PROBE') for r in results) else 0)
