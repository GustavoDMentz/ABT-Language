# ABT 0.11.8 — benchmark e auditoria adversarial local

## Escopo e método

Referência: `abt_v118_pipelines.zip`, SHA-256 `2a284c99abbd777e72558756b742f02f5550c93b4512f350f3b05bc840b8db9d`. A auditoria foi feita em cópia extraída; `sources/` não foi alterado. A execução final usou Julia 1.13.3 no Ubuntu, Intel Core i5-7400, 7,6 GiB de RAM e PythonCall 0.9.37 com Python `/usr/bin/python3`. O ambiente local tinha pouca memória livre e swap quase cheio; por isso a campanha longa foi dividida em processos de 1.000 casos.

O baseline foi executado antes de adicionar as novas ferramentas: 36 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT. `PROBE` significa sonda exploratória, não aprovação. Os detalhes estão em `baseline_118_run.log`, `baseline_environment.json` e `test_logs/summary.json`.

A suíte histórica final foi executada novamente com o mesmo resultado: 36 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL e 0 TIMEOUT (`final_full_run.log`). As 2 sondas exploratórias não contam como suítes aprovadas.

## Comandos de reprodução

No diretório do projeto extraído, com Julia 1.13.3 instalado:

```bash
export JULIA=/home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia
export JULIA_DEPOT_PATH=/home/gumentz/.codex/.chatgpt-projects/g-p-6aed28c64c608191837b0b5384a649bb/abt_v116/.julia_depot
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
ABT_REQUIRE_PYTHON=1 python3 run_all_tests.py --julia "$JULIA" --timeout 180
"$JULIA" --startup-file=no benchmark_118.jl
"$JULIA" --startup-file=no verify_benchmark_equivalence_118.jl
JULIA="$JULIA" python3 benchmark_cli_118.py
"$JULIA" --startup-file=no metamorphic_118.jl
"$JULIA" --startup-file=no invalid_campaign_118.jl
JULIA="$JULIA" python3 adversarial_isolated_118.py
for start in 1 1001 2001 3001 4001 5001 6001 7001 8001 9001; do
  "$JULIA" --startup-file=no stress_generator_118.jl --range "$start" "$((start+999))"
done
"$JULIA" --startup-file=no stress_generator_118.jl --case 1234
Rscript plot_benchmarks_118.R
```

O depot acima registra o ambiente usado nesta máquina; em outra máquina, instale apenas as dependências declaradas pelo projeto e ajuste o caminho. `PythonCall` é opcional para o ABT e necessário apenas às suítes de interoperabilidade Python.

## Resultados

Os resultados completos e a classificação final estão em `benchmark_results.csv`, `benchmark_cli.csv`, `stress_summary_*.toml`, `stress_failures_*.tsv`, `invalid_summary.toml`, `metamorphic_summary.toml` e `adversarial_results.json`. Os gráficos `benchmark_latency.png`, `benchmark_allocations.png` e `benchmark_throughput.png` usam esses dados. Os testes diferenciais comparam saída padrão, saída de erro e categoria/mensagem de exceção, sem normalizações adicionais além da camada `LoadError` de `include_string` já justificada pela suíte anterior. Os programas gerados imprimem seus valores observáveis.

As 11 cargas do benchmark foram verificadas contra a implementação Julia nativa materializada, com a mesma saída (`benchmark_equivalence.log`). As medições foram feitas com nove amostras, aquecimento explícito e medianas; cada carga contém parsing, validação/IR, otimização, geração, inclusão/avaliação do Julia gerado, execução aquecida e bytes alocados. A medida chamada `include_jit` mistura avaliação do código e compilação com possíveis caches do Julia; não representa um JIT totalmente frio. A execução aquecida gerada usa `Base.invokelatest` para evitar o problema de world age do próprio aferidor, o que adiciona overhead. As diferenças de poucos microssegundos devem ser tratadas como ruído sem intervalos de confiança mais fortes.

A campanha de entradas inválidas executou 1.000 programas e rejeitou os 1.000 (`invalid_summary.toml`). As 601 verificações metamórficas terminaram sem falhas (`metamorphic_summary.toml`). As 14 sondas isoladas terminaram sem achados dentro dos limites indicados (`adversarial_results.json`). A primeira execução das sondas tinha classificado incorretamente como inválidos um identificador longo e uma expressão profundamente parentizada; a gramática os aceita. Corrigimos a sonda, não o ABT, e repetimos os 14 casos.

A campanha diferencial gerativa executou 10.000 programas válidos em 10 lotes independentes, sem divergências (`audit_summary.json`). Cada lote tem seu próprio log, resumo TOML e arquivo TSV de falhas minimizadas. Os dez arquivos TSV contêm apenas o cabeçalho porque nenhuma divergência apareceu. A divisão em lotes evitou crescimento de memória do compilador Julia ao criar módulos para cada caso. Uma primeira tentativa monolítica foi interrompida antes de concluir, e não foi contabilizada como execução aprovada.

### Desempenho observado

Tempos medianos de execução aquecida, em microssegundos, incluindo a captura de saída do aferidor:

| Carga | Julia nativo | Julia gerado sem otimização | Julia gerado otimizado | Interpretador |
|---|---:|---:|---:|---:|
| Aritmética | 4,41 | 5,29 | 4,99 | 12,57 |
| Funções | 4,86 | 5,44 | 5,34 | 54,64 |
| Condicional e laço | 4,32 | 4,38 | 4,34 | 33,67 |
| Coleção 1.000 | 8,18 | 8,14 | 8,09 | 1.615,09 |
| Pipeline 2 etapas | 5,65 | 5,13 | 5,46 | 57,50 |
| Pipeline 5 etapas | 5,37 | 5,28 | 5,47 | 94,60 |
| Pipeline 10 etapas | 6,02 | 7,25 | 7,69 | 180,51 |
| Pipeline 20 etapas | 6,51 | 14,18 | 10,90 | 320,97 |

Na coleção de 1.000 elementos, o Julia gerado otimizado teve mediana de 8,09 µs e 24.952 bytes alocados, praticamente igual ao nativo materializado (8,18 µs e 24.952 bytes). O interpretador levou 1,62 ms e alocou cerca de 1,68 MB. No pipeline de 20 etapas, gerado otimizado/nativo foi 1,67× (10,90/6,51 µs), com 6.272/6.144 bytes; o interpretador levou 321 µs e alocou cerca de 288 KB. Esses são custos reproduzidos na carga, não defeitos semânticos. Não se alterou o núcleo sem uma otimização demonstradamente segura e medida antes/depois.

O tempo total da CLI teve medianas de 5,22 s (pipeline básico), 6,40 s (agregação) e 7,20 s (funções), nove processos por exemplo, todos com código de saída zero. Esse custo inclui inicialização do Julia, carregamento e JIT; não deve ser confundido com execução aquecida. `benchmark_cli.csv` registra mínimo e máximo por exemplo.

### Alterações e achados

Foram adicionados gerador diferencial, campanha inválida, testes metamórficos, sondas isoladas, benchmark, verificação do equivalente nativo, gráficos e consolidação. O aferidor foi corrigido para usar `Base.invokelatest` ao chamar código recém-gerado; sem isso a própria medição sofria world age. Um erro local no teste metamórfico sombreava `repr` com uma string e foi corrigido. Dois casos adversariais inicialmente rotulados inválidos eram válidos e foram reclassificados. Essas três correções são das ferramentas de auditoria. **Nenhum defeito semântico do ABT foi confirmado; nenhum arquivo do núcleo foi modificado.**

## Limites de cobertura

O gerador usa 10 categorias, sementes fixas e profundidades variadas, inclusive árvores recursivas de expressão, funções, laços, coleções, pipelines, agregações, escopo e ponte Julia. Ele não demonstra completude da gramática. A campanha inválida é separada. As propriedades metamórficas verificam também uma saída esperada independente dos três executores.

Não houve medição de vetores com 100.000 ou 1.000.000 de elementos: a linguagem não expõe construção de intervalo/`collect` pela ponte Julia permitida e gerar literais gigantes neste ambiente de memória pressionada confundiria custo de parsing com custo das operações. A chamada `Julia.Base.collect` foi sondada e rejeitada por validação como função externa não suportada; isto é limite do contrato atual, não defeito. Não foi introduzida uma nova função no ABT para completar o benchmark. Consumo máximo de memória por carga e intervalo de confiança estatístico ainda não foram medidos de forma confiável; os CSVs contêm alocação por amostra e mínimo/máximo de latência.

As sondas isoladas usam limite de 1 GiB de espaço de endereçamento, 15 segundos de CPU e 20 segundos de tempo real por caso. Elas cobrem Unicode, comentários, curto-circuito, escopo, divisão por zero, coleção heterogênea, pipeline aninhado, tabulação, etapa desconhecida, continuação após terminal, expressão incompleta, caractere inválido, identificador de 100.000 caracteres e 2.500 níveis de parênteses. A interoperabilidade Python/Julia também é coberta pelas suítes históricas; não se presume isolamento de código externo, pois o ABT não é sandbox.

## Maturidade

O resultado sustenta maturidade **experimental consistente no escopo exercitado**, com boa equivalência entre interpretador e Julia gerado nesses programas. Não sustenta garantia geral de equivalência, robustez contra todas as entradas, desempenho de coleções muito grandes nem isolamento de código externo. Não houve otimização nem alteração semântica no núcleo do ABT nesta auditoria; as mudanças estão nas ferramentas de teste e medição.
