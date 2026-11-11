# Extensões, contratos e testes

Uma entrada em `ABT_EXTENSION_SPECS` define `domain`, `arity`, `static_args`, `return_kind`, `implementation`, `generated`, `source`, `input`, `output`, `errors`, `dependencies` e `loading`. `ABT_STDLIB` instala a mesma implementação no interpretador; o gerador inclui o arquivo fonte apenas se a operação for usada. Isso mantém um único contrato e evita duplicar lógica entre backends.

Para acrescentar uma operação:

1. Registre entrada com nome único e aridade exata em `src/ExtensionRegistry.jl`.
2. Implemente função em `src/Stdlib*.jl`, com pré-condições, diagnóstico ABT e retorno estruturado. Se usar biblioteca externa, declare-a em `Project.toml`, fixe-a em `Manifest.toml` e carregue-a na chamada.
3. Crie teste direto comparando com a biblioteca Julia quando houver cálculo científico.
4. Crie teste ABT com execução interpretada, Julia gerada sem otimização e otimizada; compare valor, tipo observável, saída e categoria de erro.
5. Atualize [a referência pública](../standard-library/index.md), o exemplo executável e rode `python3 tools/validate_docs.py`.

Não use `ABT.packages.toml` para registrar operação da biblioteca padrão: esse arquivo serve à ponte de chamadas explícitas `Julia.Módulo.função(...)`. Uma função Python precisa de PythonCall, opcional, e de testes específicos.

## Testes existentes

`tests/run_all_tests.py` percorre `test_*.jl`, a suíte legada e duas sondas exploratórias; classifica `PASS`, `PARTIAL`, `FAIL`, `TIMEOUT` e `PROBE`. `tests/test_biostatistics_backends.py` compara três modos. `tests/test_applications.py`, `tests/test_extensions.py`, `tests/test_modular_extensions.py` e `tests/test_install_cli.py` verificam aplicações, extensões e CLI. Logs históricos em `logs/` são evidência de execuções passadas, não substituem nova execução.

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
python3 tests/test_biostatistics_backends.py
python3 tools/validate_docs.py
```
