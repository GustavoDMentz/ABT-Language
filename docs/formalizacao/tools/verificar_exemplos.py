#!/usr/bin/env python3
"""Executa, na implementação REAL da ABT, todos os exemplos da especificação e confere os resultados.

Este script NÃO interpreta ABT: ele só grava cada exemplo num arquivo e chama `bin/abt` (a CLI original).

Convenção no documento (Markdown):

    ```abt ok L01          programa ABT que deve terminar com sucesso (código de saída 0)
    ...programa...
    ```
    ```saida              saída padrão esperada (exatamente)
    ...
    ```

    ```abt E010 L04        programa que deve falhar com o diagnóstico ABT[E010] (código de saída 1)
    ...
    ```
    ```erro               erro padrão esperado, sem o prefixo "ARQUIVO: " da primeira linha
    ...
    ```

    ```abt-check ok V30    idem, mas executa `abt check` (valida sem executar)

Para um bloco de erro, a saída padrão deve estar vazia (a ABT só imprime depois de o programa terminar).

Uso:
    python3 tools/verificar_exemplos.py --abt /caminho/ABT-Language/bin/abt              # confere
    python3 tools/verificar_exemplos.py --abt ... --preencher                           # grava os resultados reais
    python3 tools/verificar_exemplos.py --abt ... --extrair exemplos/                   # grava exemplos/ID.abt e ID.saida
"""
import argparse, concurrent.futures as cf, json, os, re, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FENCE = re.compile(r"```(abt-check|abt)[ \t]+(\S+)[ \t]+(\S+)[ \t]*\n(.*?)```[ \t]*\n```(resultado|saida|erro)[ \t]*\n(.*?)```", re.S)


def parse(doc):
    blocks = []
    for m in FENCE.finditer(doc):
        kind, status, bid, program, rkind, result = m.groups()
        blocks.append(dict(kind=kind, status=status, id=bid, program=program, rkind=rkind, result=result, span=m.span(), rspan=(m.start(5) - 3, m.end())))
    return blocks


def run_block(abt, b, timeout):
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / f"{b['id']}.abt"
        path.write_text(b["program"], encoding="utf-8", newline="")
        cmd = [abt, "check" if b["kind"] == "abt-check" else "run", str(path)]
        t0 = time.time()
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return dict(rc="TIMEOUT", out="", err="", seg=timeout)
        err = r.stderr.replace(str(path) + ": ", "", 1)
        return dict(rc=r.returncode, out=r.stdout, err=err, seg=round(time.time() - t0, 2))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--abt", default=os.environ.get("ABT_BIN", "abt"))
    p.add_argument("--doc", default=str(ROOT / "ESPECIFICACAO_ABT_0.15.0.md"))
    p.add_argument("--preencher", action="store_true", help="grava no documento os resultados reais (revise o diff!)")
    p.add_argument("--extrair", help="diretório de saída para ID.abt / ID.saida / ID.erro")
    p.add_argument("--json", default=str(ROOT / "evidencias/verificacao_exemplos.json"))
    p.add_argument("--timeout", type=int, default=180)
    p.add_argument("--jobs", type=int, default=4)
    a = p.parse_args()
    doc_path = Path(a.doc)
    doc = doc_path.read_text(encoding="utf-8")
    blocks = parse(doc)
    ids = [b["id"] for b in blocks]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        print("IDs duplicados:", sorted(dup)); return 2
    version = subprocess.run([a.abt, "--version"], capture_output=True, text=True).stdout.strip()
    print(f"{len(blocks)} exemplos; implementação: {version} ({a.abt})", flush=True)
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        results = list(ex.map(lambda b: run_block(a.abt, b, a.timeout), blocks))
    falhas, log = [], []
    for b, r in zip(blocks, results):
        ok_status = (r["rc"] == 0) if b["status"] == "ok" else (r["rc"] == 1 and f"ABT[{b['status']}]" in r["err"] and r["out"] == "")
        actual = r["out"] if b["status"] == "ok" else r["err"]
        want_kind = "saida" if b["status"] == "ok" else "erro"
        if a.preencher:
            b["new"] = (want_kind, actual)
        match = ok_status and b["rkind"] == want_kind and b["result"].rstrip("\n") == actual.rstrip("\n")
        log.append(dict(id=b["id"], comando=b["kind"], esperado=b["status"], codigo_saida=r["rc"], saida=r["out"], erro=r["err"], conferiu=bool(match) or a.preencher and ok_status))
        if not (match or (a.preencher and ok_status)):
            falhas.append((b, r, actual))
    if a.preencher:
        out, last = [], 0
        for b in blocks:
            kind, text = b["new"]
            out.append(doc[last:b["rspan"][0]]); out.append(f"```{kind}\n{text.rstrip(chr(10))}\n```" if text.strip() else f"```{kind}\n```")
            last = b["rspan"][1]
        out.append(doc[last:])
        doc_path.write_text("".join(out), encoding="utf-8")
    if a.extrair:
        d = Path(a.extrair); d.mkdir(parents=True, exist_ok=True)
        for b, r in zip(blocks, results):
            (d / f"{b['id']}.abt").write_text(b["program"], encoding="utf-8", newline="")
            (d / f"{b['id']}.{'saida' if b['status'] == 'ok' else 'erro'}").write_text(r["out"] if b["status"] == "ok" else r["err"], encoding="utf-8")
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps(dict(implementacao=version, exemplos=log), ensure_ascii=False, indent=1), encoding="utf-8")
    for b, r, actual in falhas:
        print(f"--- DIVERGE: {b['id']} (esperado {b['status']}; código {r['rc']})\nprograma:\n{b['program']}esperado:\n{b['result']}\nobtido:\n{actual}")
    print(f"{len(blocks) - len(falhas)}/{len(blocks)} exemplos conferem" + (" (resultados gravados)" if a.preencher else ""))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
