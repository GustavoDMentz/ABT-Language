# ABT 0.11.8 — evolução incremental: fundação de pacotes

## Entrega implementada

Esta entrega cobre a **Fase A** do pedido. O compilador usa a gramática existente `usar Julia.Módulo` e `Julia.Módulo.função(...)` para um módulo declarado no novo `ABT.packages.toml`. O manifesto explicita UUID, versão exata e aridade de cada função. O Julia carrega o módulo apenas ao alcançar o import. A versão é conferida, e tanto o interpretador como o Julia gerado usam a mesma declaração. O exemplo executável `examples/pacote_dates.abt` usa `Dates`, da biblioteca padrão. PythonCall continua opcional.

Não há novos tokens, parser de Python, conversão tabular ou runtime próprio. O formato, as decisões e a matriz de riscos constam de `ARQUITETURA_PACOTES_FUNDACAO.md`.

## Auditoria inicial

O estado inspecionado era ABT 0.11.8. A baseline obrigatória, antes das alterações, executou 36 suítes PASS e 2 sondas PROBE, sem PARTIAL, FAIL ou TIMEOUT (`logs/historical/foundation_baseline.log`). O ambiente foi Julia 1.13.3; Julia Pkg listou PythonCall 0.9.37. NumPy e pandas estavam instalados no Python local; Biopython, Streamlit e PyTorch não. Os pacotes Julia DataFrames, CSV, DataFramesMeta, QuadGK e Symbolics não estavam no ambiente. Nenhuma dessas dependências pesadas foi adicionada ao núcleo.

## Correção de regressão durante o trabalho

A primeira execução integral após a mudança encontrou 1 falha em `tests/test_interop_extended.jl`: o diagnóstico de módulo Julia não suportado havia trocado a palavra `unsupported` por `undeclared`, quebrando uma expectativa histórica válida. O texto anterior foi restaurado; o teste afetado passou com 15/15 asserções, e o teste novo passou com 18/18. O núcleo semântico não foi alterado por essa correção.

## Resultado final

A última execução integral terminou com **37 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL e 0 TIMEOUT** (`logs/historical/foundation_final_full.log` e `logs/test_logs/summary.json`). O teste novo registrou 18/18 asserções aprovadas; o legado afetado registrou 15/15. O exemplo CLI exibiu `2026-11-06` e `2026` com código de saída zero (`logs/historical/package_example_run.log`). Sondas `PROBE` são separadas de aprovação.

O benchmark da auditoria 0.11.8 anterior (`benchmarks/results/benchmark_results.csv`, gráficos e `RELATORIO_BENCHMARK_AUDITORIA_118.md`) permanece no projeto como baseline de desempenho; não foi repetido como medição específica da nova importação. Esta entrega não afirma overhead medido para pacotes opcionais nem para os tamanhos 10.000–10.000.000, porque a fatia adicionou import e chamadas explícitas, não operações vetoriais novas.

## Limitações e próximas fases

O manifesto suporta funções de aridade fixa entre 0 e 32; métodos variádicos, argumentos nomeados, tipos externos complexos e macros não foram cobertos. A verificação de versão ocorre após `Base.require`, então a inicialização de um pacote incompatível ainda pode ter efeitos. O projeto Julia deve ser resolvido e fixado com `Project.toml`/`Manifest.toml` quando forem adicionadas dependências externas reais. O manifesto ABT não substitui Pkg.

As Fases B–E permanecem pendentes. Não foi especificada sem ambiguidade a semântica de `missing`, agrupamento e cópias para tabelas; a gramática e o escopo de blocos Python; as conversões matemáticas/biológicas; nem o ciclo de reruns do Streamlit. Uma auditoria mínima obrigatória entre todos os backends também depende de contrato de eventos, retenção e privacidade. Essas construções não foram implementadas por aproximação. Veja a matriz de riscos em `ARQUITETURA_PACOTES_FUNDACAO.md`.

## Comandos exatos usados localmente

```bash
export JULIA=/home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia
export JULIA_DEPOT_PATH=/home/gumentz/.codex/.chatgpt-projects/g-p-6aed28c64c608191837b0b5384a649bb/abt_v116/.julia_depot
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
ABT_REQUIRE_PYTHON=1 python3 tests/run_all_tests.py --julia "$JULIA" --timeout 180
"$JULIA" --startup-file=no tests/test_packages_foundation.jl
"$JULIA" --startup-file=no pseudo.jl examples/pacote_dates.abt
```
