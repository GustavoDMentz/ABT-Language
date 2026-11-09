#!/usr/bin/env python3
"""Combine independently recorded campaign results without inventing passes."""
import json
import pathlib
import tomllib

root=pathlib.Path(__file__).resolve().parent.parent
chunks=[]
for path in sorted((root / "logs/historical").glob("stress_summary_*_*.toml")):
    data=tomllib.loads(path.read_text())
    chunks.append({"file":path.name,**data})
historical=json.loads((root/"logs/test_logs/summary.json").read_text())
adversarial=json.loads((root/"logs/historical/adversarial_results.json").read_text())
result={
    "historical":{"total":len(historical["results"]),"statuses":{s:sum(x["status"]==s for x in historical["results"]) for s in ("PASS","PROBE","PARTIAL","FAIL","TIMEOUT")}},
    "stress":{"chunks":chunks,"executed":sum(x["executed"] for x in chunks),"failures":sum(x["failures"] for x in chunks)},
    "invalid":tomllib.loads((root/"logs/historical/invalid_summary.toml").read_text()),
    "metamorphic":tomllib.loads((root/"logs/historical/metamorphic_summary.toml").read_text()),
    "adversarial":{"executed":len(adversarial),"statuses":{s:sum(x["status"]==s for x in adversarial) for s in ("PASS","FINDING","TIMEOUT")}},
}
(root/"logs/current_audit_summary.json").write_text(json.dumps(result,indent=2,ensure_ascii=False))
print(json.dumps({"historical":result["historical"],"stress":{"executed":result["stress"]["executed"],"failures":result["stress"]["failures"]},"invalid":{k:result["invalid"][k] for k in ("executed","rejected","accepted")},"metamorphic":{k:result["metamorphic"][k] for k in ("executed","failures")},"adversarial":result["adversarial"]},indent=2))
