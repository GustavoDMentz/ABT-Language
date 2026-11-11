# Resultados da expansão modular ABT 0.11.8

Este relatório mede a etapa inicial de agrupamento/JSON. Para o estado atual com StatsBase/LinearAlgebra, consulte [Resultados da arquitetura de extensões](RESULTADOS_ARQUITETURA_EXTENSOES_0118.md).

Ambiente: Linux x86-64, Julia 1.13.3; execução local com `JULIA_DEPOT_PATH=/tmp/abt-tabular-depot:<JULIA_DEPOT>`. PythonCall foi exigido na regressão histórica com Python `/usr/bin/python3`.

## Verificação funcional

| Execução | Resultado | Evidência |
|---|---:|---|
| Contratos novos, interpretador e Julia gerada com/sem otimização | 45 PASS, 0 FAIL | `logs/test_logs/extensions_execution.log`, `logs/test_logs/extensions_results.json` |
| Contratos internos: ciclo, NaN/Inf, ausência explícita | 6 PASS, 0 FAIL | `logs/test_logs/extensions_internal.log` |
| Histórico completo | 39 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT | `logs/test_logs/historical_extensions_final.log`, `logs/test_logs/summary.json` |
| Aplicações existentes | 112 PASS, 0 FAIL, 0 TIMEOUT | `logs/test_logs/applications_extensions_final.log`, `applications/test_results.json` |

As duas sondas históricas são exploratórias; seu estado `PROBE` não equivale a aprovação sem findings. A comparação diferencial nova confere todos os campos do JSON e igualdade literal de stdout entre os três modos nos casos válidos; nos casos inválidos, confere falha e a causa diagnóstica esperada. Os 1.000 casos da suíte diferencial histórica passaram dentro da regressão.

No primeiro ciclo da suíte nova houve 7 falhas de expectativa: seis tratavam a apresentação de um registro por `mostrar` como JSON, e uma ainda procurava a mensagem técnica antiga de overflow. O contrato do ABT não promete JSON implícito. A suíte foi corrigida para chamar `codificar_json` explicitamente e esperar o diagnóstico ABT de overflow; a execução final passou 45/45. Nenhuma asserção semântica foi retirada.

## Dependência e custo de instalação

Na etapa inicial, somente JSON.jl v1.13.4 foi adicionada como dependência direta; StructUtils.jl entrou como dependência transitiva. `Pkg.add` usou pacotes já presentes no cache local, levou aproximadamente 23,1 s de parede e 16,7 s de pré-compilação informada pelo Pkg; houve aviso de indisponibilidade do servidor de pacotes. Esses valores **não** medem tempo de download numa instalação limpa. Fontes locais: JSON.jl aproximadamente 1,4 MiB e StructUtils.jl 364 KiB. Cache compilado local: aproximadamente 18 MiB e 828 KiB, respectivamente. Esses tamanhos são em disco, não RSS nem alocações de Julia.

Não foram medidos tempo de instalação, inicialização ou RSS de DataFrames.jl, CategoricalArrays.jl, StatsBase.jl, HypothesisTests.jl, JSON3.jl, HTTP.jl, BioAlignments.jl, GenomicFeatures.jl ou CairoMakie.jl, pois esses pacotes não foram instalados nesta etapa. A avaliação deles se limita à compatibilidade declarada no registro local e à adequação arquitetural.

## Medição por processo

O script `benchmarks/benchmark_extensions.py` usa `/usr/bin/time -v`, cinco repetições independentes por cenário, `--compile=min` em todos os processos e guarda cada medição bruta em `logs/test_logs/extensions_benchmark.json`. Medianas abaixo; os intervalos entre parênteses são mínimo–máximo. Tempo de usuário e sistema são tempos de CPU do processo inteiro.

| Cenário | Tempo real (s) | CPU usuário (s) | CPU sistema (s) | Pico RSS (KiB) |
|---|---:|---:|---:|---:|
| Julia mínima | 0,15 (0,15–0,16) | 0,08 (0,08–0,08) | 0,07 (0,06–0,07) | 164.844 (164.828–164.992) |
| Julia + `import JSON` | 0,26 (0,26–0,26) | 0,26 (0,25–0,27) | 0,09 (0,07–0,09) | 218.404 (218.372–218.564) |
| Carregamento ABT | 0,52 (0,50–0,54) | 0,52 (0,51–0,53) | 0,09 (0,08–0,09) | 247.912 (247.648–247.964) |
| CLI ABT: CSV + grupos + JSON | 1,15 (1,14–1,17) | 1,08 (1,08–1,09) | 0,15 (0,14–0,16) | 349.496 (349.336–352.660) |

`import JSON` acrescentou aproximadamente 0,11 s e 53.560 KiB de RSS mediano frente à Julia mínima nesta máquina. Carregar o módulo ABT sem executar operação acrescentou 83.068 KiB frente à Julia mínima; esse valor inclui o núcleo ABT e suas dependências já existentes, portanto **não representa custo incremental de JSON.jl**. A aplicação completa atingiu 101.584 KiB acima do carregamento ABT, incluindo CLI, CSV, agrupamento, serialização e seus dados. Essas subtrações são diferenças entre processos, não atribuição precisa de alocações internas. `Base.require` só carrega JSON.jl quando `codificar_json` é chamado.

Reprodução no Ubuntu, na raiz do projeto, após `Pkg.instantiate()`:

```sh
export ABT_JULIA=/caminho/julia-1.13.3/bin/julia
python3 benchmarks/benchmark_extensions.py --julia "$ABT_JULIA" --repetitions 5
python3 tests/test_extensions.py --julia "$ABT_JULIA"
"$ABT_JULIA" --startup-file=no --project=. tests/test_extensions_internal.jl
python3 tests/test_applications.py --julia "$ABT_JULIA"
python3 tests/run_all_tests.py --julia "$ABT_JULIA"
```

## Correções e limites

- O diagnóstico de overflow inteiro foi tornado específico de `resumir_grupos` e aponta registro/coluna; a soma continua verificada com `Base.checked_add`.
- O carregamento tardio de JSON.jl agora traduz indisponibilidade da biblioteca para erro ABT com causa original.
- JSON de tabela materializa registros. O resumo agrupado percorre os registros uma vez, mas materializa um registro por grupo. O número de grupos, portanto, limita o ganho de memória em dados de alta cardinalidade.
- Os pacotes não instalados constam na avaliação de compatibilidade declarada em `EXTENSOES_JULIA_0118.md`; não há alegação de que foram testados em execução.
