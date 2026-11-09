#!/usr/bin/env python3
"""Audit exact ABT diagnostic-line parity from test_bio.py results."""
import json
import re
from collections import defaultdict
from pathlib import Path

path = Path('logs/test_logs/bio_results.json')
results = json.loads(path.read_text())
by_case = defaultdict(list)
for result in results:
    by_case[result['case']].append(result)
divergences = []
for case, runs in by_case.items():
    if len(runs) != 3 or any(x['status'] != 'PASS' for x in runs):
        divergences.append({'case': case, 'reason': 'missing or failed backend'})
        continue
    if all(x['returncode'] == 0 for x in runs):
        values = [x['stdout'] for x in runs]
    else:
        values = []
        for x in runs:
            match = re.search(r'ABT (?:FASTA|ler_fasta):[^\n]*', x['stderr'])
            values.append(match.group(0) if match else None)
    if len(set(values)) != 1:
        divergences.append({'case': case, 'values': values})
report = {'cases': len(by_case), 'backend_runs': len(results), 'divergences': divergences}
Path('logs/test_logs/bio_parity_audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(report)
raise SystemExit(bool(divergences))
