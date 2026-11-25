#!/usr/bin/env python3
"""Regenera ide/fixtures/*.json com a saída REAL do compilador (precisa da ABT instalada).

Cada fixtures/NOME.abt é inspecionado por inspecionar.jl e o JSON bruto vai para fixtures/NOME.json. Os testes
test_inspecao.py usam esses arquivos para validar a IDE sem Julia (ex.: no CI); os testes de integração
refazem a inspeção de verdade e conferem que continuam iguais (exceto os tempos).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import inspecao  # noqa: E402

PASTA = Path(__file__).resolve().parent / "fixtures"

if __name__ == "__main__":
    for arq in sorted(PASTA.glob("*.abt")):
        bruto, _ = inspecao.rodar_julia_inspecao(arq.read_text(encoding="utf-8"))
        (PASTA / (arq.stem + ".json")).write_text(json.dumps(bruto, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("gerado", arq.stem)
