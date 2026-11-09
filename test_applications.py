#!/usr/bin/env python3
"""Testes de ponta a ponta dos três programas ABT; sem alterar seus dados originais."""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APPS = ROOT / "applications"
parser = argparse.ArgumentParser()
parser.add_argument("--julia", default=os.environ.get("ABT_JULIA", "julia"))
parser.add_argument("--case", action="append", help="run only this named case (repeatable)")
parser.add_argument("--output", default=str(APPS / "test_results.json"))
args = parser.parse_args()
env = dict(os.environ, ABT_JULIA=args.julia)
results = []


def run(name, source, expected=None, data=None, variable=None, error=None, generated=False):
    if args.case and name not in args.case:
        return
    with tempfile.TemporaryDirectory(prefix="abt-app-") as temporary:
        tmp = Path(temporary)
        path = source
        if isinstance(source, tuple):
            path = tmp / "case.abt"
            path.write_text(source[0])
        local = env.copy()
        if data is not None:
            fixture = tmp / "input.txt"
            fixture.write_text(data)
            local[variable] = str(fixture)
        commands = [("interpretador", [str(ROOT / "bin" / "abt"), "run", str(path)])]
        if generated:
            for optimized, label in [(False, "julia_sem_otimizacao"), (True, "julia_otimizada")]:
                output = tmp / f"{label}.jl"
                cmd = [args.julia, "--startup-file=no", f"--project={ROOT}", str(ROOT / "pseudo.jl"), str(path),
                       "--emit-julia", str(output), "--no-run"]
                if not optimized: cmd.append("--no-opt")
                emit = subprocess.run(cmd, cwd=ROOT, env=local, capture_output=True, text=True, timeout=120)
                if emit.returncode:
                    results.append(dict(case=name, backend=label, status="FAIL", stdout=emit.stdout, stderr=emit.stderr))
                    continue
                commands.append((label, [args.julia, "--startup-file=no", f"--project={ROOT}", str(output)]))
        for label, command in commands:
            try:
                p = subprocess.run(command, cwd=ROOT, env=local, capture_output=True, text=True, timeout=120)
                ok = (p.returncode == 0 and p.stdout == expected) if error is None else (p.returncode != 0 and error in p.stderr)
                results.append(dict(case=name, backend=label, status="PASS" if ok else "FAIL",
                                    code=p.returncode, stdout=p.stdout, stderr=p.stderr, command=command))
            except subprocess.TimeoutExpired:
                results.append(dict(case=name, backend=label, status="TIMEOUT", command=command))


stats = APPS / "statistics" / "descritiva.abt"
csv = APPS / "data" / "resumo_csv.abt"
bio = APPS / "bio" / "conteudo_gc.abt"
stats_default = "(resumo = (quantidade = 6, soma = 120, media = 20.0, mediana = 19.5, desvio_padrao = 6.48074069840786, minimo = 12, maximo = 30), quantidade_maior_igual_18 = 4)\n"
csv_default = "(registros = 5, selecionados_grupo_A_valor_maior_igual_10 = 2, soma = 32.0, media = 16.0)\n"
bio_default = "(sequencias = 1, bases = 12, A = 4, C = 2, G = 3, T = 3, N = 0, GC_percentual = 41.666666666666664)\n"
run("estatistica_amostra", stats, expected=stats_default, generated=True)
run("csv_amostra", csv, expected=csv_default, generated=True)
run("dna_amostra", bio, expected=bio_default, generated=True)
run("dna_registros_amostra", APPS / "bio" / "por_registro.abt",
    expected='[(identificador = "alfa", descricao = "alfa amostra A", sequencia = "ACGT", comprimento = 4, A = 1, C = 1, G = 1, T = 1, U = 0, N = 0, GC_percentual = 50.0), (identificador = "beta", descricao = "beta amostra B", sequencia = "GGGG", comprimento = 4, A = 0, C = 0, G = 4, T = 0, U = 0, N = 0, GC_percentual = 100.0), (identificador = "gama", descricao = "gama amostra C", sequencia = "AAAA", comprimento = 4, A = 4, C = 0, G = 0, T = 0, U = 0, N = 0, GC_percentual = 0.0)]\n',
    generated=True)

original = stats.read_text()
run("estatistica_constante", (original.replace("[12, 15, 18, 21, 24, 30]", "[5, 5, 5]"),),
    expected="(resumo = (quantidade = 3, soma = 15, media = 5.0, mediana = 5.0, desvio_padrao = 0.0, minimo = 5, maximo = 5), quantidade_maior_igual_18 = 0)\n")
run("estatistica_vazia", (original.replace("[12, 15, 18, 21, 24, 30]", "[]"),), error="at least two values required")
run("estatistica_tipo_invalido", (original.replace("[12, 15, 18, 21, 24, 30]", '[1, "x"]'),), error="expected finite Int64 or Float64")

run("csv_aspas_e_filtro", csv, data='nome,grupo,valor\n"Ana, Maria",A,20\nBruno,B,100\n',
    variable="ABT_CSV_PATH", expected="(registros = 2, selecionados_grupo_A_valor_maior_igual_10 = 1, soma = 20.0, media = 20.0)\n")
run("csv_sem_selecao", csv, data="nome,grupo,valor\nAna,B,1\n", variable="ABT_CSV_PATH", error="empty table")
run("csv_cabecalho_invalido", csv, data="nome,grupo,pontos\nAna,A,20\n", variable="ABT_CSV_PATH", error="header does not match explicit schema")
run("csv_numero_invalido", csv, data="nome,grupo,valor\nAna,A,abc\n", variable="ABT_CSV_PATH", error="invalid real value")
run("csv_linha_incompleta", csv, data="nome,grupo,valor\nAna,A\n", variable="ABT_CSV_PATH", error="short_row")
run("csv_vazio", csv, data="", variable="ABT_CSV_PATH", error="empty file or missing header")

run("dna_multiplas_minusculas", bio, data=">a\nacgt\n>b\nGGCC\n", variable="ABT_FASTA_PATH",
    expected="(sequencias = 2, bases = 8, A = 1, C = 3, G = 3, T = 1, N = 0, GC_percentual = 75.0)\n")
run("dna_gc_zero", bio, data=">a\nAAAA\n", variable="ABT_FASTA_PATH",
    expected="(sequencias = 1, bases = 4, A = 4, C = 0, G = 0, T = 0, N = 0, GC_percentual = 0.0)\n")
run("dna_gc_cem", bio, data=">a\nGGGG\n", variable="ABT_FASTA_PATH",
    expected="(sequencias = 1, bases = 4, A = 0, C = 0, G = 4, T = 0, N = 0, GC_percentual = 100.0)\n")
run("dna_base_invalida", bio, data=">a\nACNT\n", variable="ABT_FASTA_PATH", error="base inválida")
run("dna_sem_cabecalho", bio, data="ACGT\n", variable="ABT_FASTA_PATH", error="FASTA")
run("dna_vazio", bio, data=">a\n", variable="ABT_FASTA_PATH", error="sequência vazia")
run("dna_ultimo_registro_vazio", bio, data=">a\nACGT\n>b\n", variable="ABT_FASTA_PATH", error="sequência vazia")

run("registro_composicao", ('r = registro("nome", "ABT", "metricas", descrever([1, 2, 3]))\nmostrar r.metricas.media\nmostrar r\n',),
    expected='2.0\n(nome = "ABT", metricas = (quantidade = 3, soma = 6, media = 2.0, mediana = 2.0, desvio_padrao = 1.0, minimo = 1, maximo = 3))\n', generated=True)
run("registro_duplicado", ('mostrar registro("x", 1, "x", 2)\n',), error="duplicate field", generated=True)
run("registro_nome_invalido", ('mostrar registro("_interno", 1)\n',), error="invalid field name")
run("registro_aridade_invalida", ('mostrar registro("x", 1, "y")\n',), error="name/value pairs")
run("descrever_um_valor", ('mostrar descrever([1])\n',), error="at least two values required", generated=True)
run("descrever_nao_numerico", ('mostrar descrever([1, "a"])\n',), error="expected finite Int64 or Float64", generated=True)
run("descrever_booleano", ('mostrar descrever([1, verdadeiro])\n',), error="expected finite Int64 or Float64")
run("descrever_ausente", ('função sem_valor() { }\nmostrar descrever([1, sem_valor()])\n',), error="without missing values", generated=True)
run("descrever_infinito", ('mostrar descrever([1, 1 / 0])\n',), error="expected finite Int64 or Float64", generated=True)
run("descrever_nan", ('mostrar descrever([1, 0 / 0])\n',), error="expected finite Int64 or Float64")
run("descrever_overflow", ('mostrar descrever([9223372036854775807, 1])\n',), error="sum overflow", generated=True)
run("descrever_escalar", ('mostrar descrever(2)\n',), error="expects a collection")
run("sombreamento_funcao_existente", ('função descrever(x) { retornar x + 1 }\nmostrar descrever(2)\n',), expected="3\n", generated=True)
run("biblioteca_em_funcao", ('função calcular(xs) { retornar descrever(xs) }\nmostrar calcular([2, 4]).media\n',), expected="3.0\n", generated=True)
run("sem_captura_apos_sombreamento", ('função calcular() { retornar descrever([1, 2]) }\ndescrever = 3\nmostrar calcular()\n',), error="undefined function 'descrever'")

vendas = APPS / "data" / "vendas.abt"
run("vendas_amostra", vendas,
    expected='(regiao = "Sul", resumo = (quantidade = 3, soma = 20, media = 6.666666666666667, minimo = 4, maximo = 10), produtos = ["Caderno", "Lápis", "Borracha"])\n',
    generated=True)
run("csv_cabecalho_duplicado", csv, data="nome,grupo,grupo\nAna,A,20\n", variable="ABT_CSV_PATH",
    error="duplicate header", generated=True)
run("csv_campo_ausente", csv, data="nome,grupo,valor\nAna,A,\n", variable="ABT_CSV_PATH",
    error="missing field", generated=True)
run("csv_campo_vazio_entre_aspas", csv, data='nome,grupo,valor\nAna,A,""\n', variable="ABT_CSV_PATH",
    error="invalid real value", generated=True)
run("csv_citacao_malformada", csv, data='nome,grupo,valor\n"Ana,A,20\n', variable="ABT_CSV_PATH",
    error="CSV", generated=True)
run("csv_quebra_linha_entre_aspas", csv,
    data='nome,grupo,valor\n"Ana\nMaria",A,20\n', variable="ABT_CSV_PATH",
    expected="(registros = 1, selecionados_grupo_A_valor_maior_igual_10 = 1, soma = 20.0, media = 20.0)\n",
    generated=True)
run("csv_arquivo_inexistente", ('mostrar ler_csv("/tmp/abt_arquivo_que_nao_existe.csv", esquema("x", "texto"), "erro")\n',),
    error="ABT ler_csv: file", generated=True)
run("csv_tipo_invalido", ('mostrar esquema("x", "adivinhar")\n',), error="requires texto", generated=True)
run("csv_coluna_inexistente", ('t = ler_csv("applications/data/sample.csv", esquema("nome", "texto", "grupo", "texto", "valor", "real"), "erro")\nmostrar coluna(t, "inexistente")\n',),
    error="unknown column", generated=True)
run("csv_filtro_tipo_incompativel", ('t = ler_csv("applications/data/sample.csv", esquema("nome", "texto", "grupo", "texto", "valor", "real"), "erro")\nmostrar filtrar_tabela(t, "valor", ">", "10")\n',),
    error="incompatible comparison value", generated=True)
run("csv_transformacao_tipo_incompativel", ('t = ler_csv("applications/data/vendas.csv", esquema("produto", "texto", "regiao", "texto", "unidades", "inteiro", "preco", "real"), "erro")\nx = transformar_tabela(t, "unidades", "dobro", "/", 2, "inteiro")\nmostrar coluna(x, "dobro")\n',),
    error="result does not match declared type", generated=True)
run("csv_ausente_permitido", ('t = ler_csv(ambiente("ABT_CSV_PATH", ""), esquema("x", "texto", "y", "inteiro"), "permitir")\nmostrar coluna(t, "x")\n',),
    data='x,y\n,1\n"",2\n', variable="ABT_CSV_PATH", expected='[ausente, ""]\n', generated=True)
run("csv_unicode", ('t = ler_csv(ambiente("ABT_CSV_PATH", ""), esquema("nome", "texto", "valor", "inteiro"), "erro")\nmostrar coluna(t, "nome")\n',),
    data='nome,valor\nJoão,2\nÉrica,3\n', variable="ABT_CSV_PATH", expected='["João", "Érica"]\n', generated=True)
run("csv_delimitador_explicito", ('t = ler_csv(ambiente("ABT_CSV_PATH", ""), esquema("nome", "texto", "valor", "inteiro"), "erro", ";")\nmostrar coluna(t, "valor")\n',),
    data='nome;valor\n"Ana; Maria";2\n', variable="ABT_CSV_PATH", expected='[2]\n', generated=True)
run("csv_delimitador_invalido", ('mostrar ler_csv("applications/data/sample.csv", esquema("nome", "texto", "grupo", "texto", "valor", "real"), "erro", ";;")\n',),
    error="delimiter must be one character", generated=True)
run("csv_booleano_sem_ordem", ('t = ler_csv(ambiente("ABT_CSV_PATH", ""), esquema("ok", "booleano"), "erro")\nmostrar filtrar_tabela(t, "ok", ">", verdadeiro)\n',),
    data='ok\ntrue\n', variable="ABT_CSV_PATH", error="boolean columns support only", generated=True)
run("csv_acesso_registros", APPS / "data" / "listar_nomes.abt",
    expected="Ana\nBruno\nCarla\nDiego\nEva\n", generated=True)

log = Path(args.output)
log.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
for result in results:
    print(result["status"], result["case"], result["backend"], flush=True)
print("Resumo:", {kind: sum(r["status"] == kind for r in results) for kind in ("PASS", "FAIL", "TIMEOUT")})
raise SystemExit(1 if any(r["status"] != "PASS" for r in results) else 0)
