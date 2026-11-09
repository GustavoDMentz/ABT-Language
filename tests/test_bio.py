#!/usr/bin/env python3
"""FASTA contract and interpreter/generated equivalence; records full outputs."""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--julia', default=os.environ.get('ABT_JULIA', 'julia'))
parser.add_argument('--case', action='append', help='run only this named case (repeatable)')
parser.add_argument('--output', default='logs/test_logs/bio_results.json')
args = parser.parse_args()
run_env = dict(os.environ, ABT_JULIA=args.julia)
programs = [
    ('dna', '>a descrição\nacgt\n>b\nGGCC\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', '(sequencias = 2, bases = 8, A = 1, C = 3, G = 3, T = 1, N = 0, GC_percentual = 75.0)\n', None),
    ('rna', '>r\nacgu\n', 'RNA', 'rejeitar', 'normalizar', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 1, C = 1, G = 1, U = 1, N = 0, GC_percentual = 50.0)\n', None),
    ('rna_ambiguo', '>r\nANCGU\n', 'RNA', 'permitir_N', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 5, A = 1, C = 1, G = 1, U = 1, N = 1, GC_percentual = 50.0)\n', None),
    ('ambiguo', '>n\nANCG\n', 'DNA', 'permitir_N', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 1, C = 1, G = 1, T = 0, N = 1, GC_percentual = 66.66666666666667)\n', None),
    ('multilinha', '>a\nAC\nGT\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 1, C = 1, G = 1, T = 1, N = 0, GC_percentual = 50.0)\n', None),
    ('gc_zero', '>a\nAAAA\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 4, C = 0, G = 0, T = 0, N = 0, GC_percentual = 0.0)\n', None),
    ('gc_cem', '>a\nGGGG\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 0, C = 0, G = 4, T = 0, N = 0, GC_percentual = 100.0)\n', None),
    ('duplicado', '>a\nAC\n>a\nGT\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', None, 'identificador duplicado'),
    ('minusculas', '>a\nacgt\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', None, 'minúsculas não permitidas'),
    ('base_invalida', '>a\nACX\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, "base inválida 'X' na posição 3"),
    ('n_rejeitado', '>a\nACN\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, "base inválida 'N' na posição 3"),
    ('somente_n', '>a\nNNN\n', 'DNA', 'permitir_N', 'normalizar', 'descrever_sequencias', None, 'GC indefinido'),
    ('vazio', '>a\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'sequência vazia'),
    ('sem_cabecalho', 'ACGT\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'FASTA'),
    ('id_vazio', '>\nACGT\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'identificador vazio'),
    ('arquivo_vazio', '', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'nenhum registro'),
    ('arquivo_inexistente', '>a\nACGT\n', 'DNA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'não existe'),
    ('alfabeto_invalido', '>a\nACGT\n', 'PROTEINA', 'rejeitar', 'normalizar', 'descrever_sequencias', None, 'alfabeto deve ser'),
    ('objeto_invalido', None, None, None, None, 'descrever_sequencias', None, 'esperado valor produzido por ler_fasta'),
    ('registros', '>a descrição\nacgt\n', 'DNA', 'rejeitar', 'normalizar', 'registros_fasta', None, None),
    ('funcao', '>a\nACGT\n', 'DNA', 'rejeitar', 'exigir_maiusculas', 'descrever_sequencias', '(sequencias = 1, bases = 4, A = 1, C = 1, G = 1, T = 1, N = 0, GC_percentual = 50.0)\n', None),
]
results = []
with tempfile.TemporaryDirectory(prefix='abt-bio-') as temp:
    tmp = Path(temp)
    for name, data, alphabet, ambiguity, case_policy, operation, expected, error in programs:
        if args.case and name not in args.case:
            continue
        fasta = tmp / 'data.fasta'
        if data is not None:
            fasta.write_text(data)
            source = f'f = ler_fasta({json.dumps(str(fasta))}, {json.dumps(alphabet)}, {json.dumps(ambiguity)}, {json.dumps(case_policy)})\nmostrar {operation}(f)\n'
            if name == 'funcao':
                source = 'função analisar(x) { retornar descrever_sequencias(x) }\n' + source.replace('mostrar descrever_sequencias(f)', 'mostrar analisar(f)')
        else:
            source = 'mostrar descrever_sequencias(1)\n'
        program = tmp / f'{name}.abt'
        program.write_text(source)
        if name == 'arquivo_inexistente':
            fasta.unlink()
        commands = [('interpretador', [str(ROOT/'bin/abt'), 'run', str(program)])]
        for no_opt, label in [(True, 'gerado_sem_otimizacao'), (False, 'gerado_otimizado')]:
            output = tmp / f'{name}_{label}.jl'
            emit = [args.julia, '--startup-file=no', f'--project={ROOT}', str(ROOT/'pseudo.jl'), str(program), '--emit-julia', str(output), '--no-run']
            if no_opt: emit.append('--no-opt')
            p = subprocess.run(emit, cwd=ROOT, env=run_env, capture_output=True, text=True, timeout=120)
            if p.returncode:
                results.append(dict(case=name, backend=label, status='FAIL', phase='emit', source=source, data=data, stdout=p.stdout, stderr=p.stderr))
            else:
                commands.append((label, [args.julia, '--startup-file=no', f'--project={ROOT}', str(output)]))
        observed = []
        for label, command in commands:
            p = subprocess.run(command, cwd=ROOT, env=run_env, capture_output=True, text=True, timeout=120)
            observed.append((p.returncode == 0, p.stdout, p.stderr))
            if name == 'registros':
                ok = p.returncode == 0 and 'identificador = "a"' in p.stdout and 'descricao = "a descrição"' in p.stdout and 'sequencia = "acgt"' in p.stdout and 'GC_percentual = 50.0' in p.stdout
            elif error:
                ok = p.returncode != 0 and error in p.stderr
            else:
                ok = p.returncode == 0 and p.stdout == expected
            results.append(dict(case=name, backend=label, status='PASS' if ok else 'FAIL', returncode=p.returncode, source=source, data=data, stdout=p.stdout, stderr=p.stderr, command=command))
            print(('PASS' if ok else 'FAIL'), name, label, flush=True)
        # Exact output/exit parity for successful cases; errors retain backend-specific wrapper but same ABT cause.
        if not error and all(item[0] for item in observed):
            assert len({item[1] for item in observed}) == 1, name
Path('logs/test_logs').mkdir(exist_ok=True)
Path(args.output).write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
print('Resumo:', {s: sum(r['status']==s for r in results) for s in ('PASS','FAIL')})
raise SystemExit(any(r['status'] != 'PASS' for r in results))
