# Resultados da arquitetura modular ABT 0.11.8

## Execução e classificação

Ambiente: Ubuntu/Linux x86-64, Julia 1.13.3, projeto ABT local. PythonCall foi exigido na regressão histórica com `JULIA_CONDAPKG_BACKEND=Null`, `JULIA_PYTHONCALL_EXE=/usr/bin/python3` e `ABT_REQUIRE_PYTHON=1`.

| Suíte | Resultado efetivo | Evidência |
|---|---:|---|
| Extensões modulares: dois aplicativos, válidos, inválidos, sombreamento, tipo estático, três backends | 51 PASS, 0 FAIL | `logs/test_logs/modular_results.json`, `logs/test_logs/modular_execution.log` |
| Registro: catálogo, integridade dos metadados, carregamento tardio e inclusão seletiva no gerador | 9 PASS, 0 FAIL | `logs/test_logs/modular_registry.log` |
| Regressão histórica completa | 41 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT | `logs/test_logs/summary.json`, `logs/test_logs/modular_historical.log` |
| Suíte anterior de agrupamento e JSON | 45 PASS, 0 FAIL | `logs/test_logs/extensions_results.json`, `logs/test_logs/modular_prior_extensions.log` |
| Aplicações existentes | 112 PASS, 0 FAIL, 0 TIMEOUT | `applications/test_results.json`, `logs/test_logs/modular_applications.log` |
| Instalador e CLI instalada, incluindo atualização de marcador antigo | 9 PASS, 0 FAIL | `logs/test_logs/modular_install_cli.log` |

As duas sondas históricas mantêm status `PROBE`: são exploratórias, não aprovação da ausência de problemas. Na suíte modular, a mesma aplicação foi executada pelo interpretador e por Julia gerada com e sem otimização. JSON válido foi comparado por todos os campos e a saída literal foi comparada entre os três modos. Erros foram conferidos pela categoria/causa diagnóstica esperada. `tests/test_extension_registry.jl` verificou que análise semântica e geração de um programa não carregam StatsBase.jl, e que um programa simples não inclui a implementação da extensão no código gerado.

O primeiro teste de ausência da coluna de grupo usou um arquivo CSV com linha inteiramente em branco, que CSV.jl ignora. O fixture foi corrigido para ter duas colunas e uma célula de grupo vazia; os três modos passaram. Foi uma correção do teste, não uma alteração semântica do ABT.

## Disponibilidade e instalação

StatsBase.jl 0.34.13 foi selecionada a partir do registro General local e de sua [documentação oficial](https://juliastats.org/StatsBase.jl/latest/). A primeira tentativa de instalação no sandbox falhou por resolução DNS de `pkg.julialang.org`/GitHub; o log está em `logs/test_logs/modular_install_first_attempt.log`. A instalação autorizada com acesso externo concluiu: StatsBase.jl 0.34.13 e suas dependências necessárias foram instaladas e 13 dependências pré-compiladas em 9 s, com 7 já pré-compiladas. A segunda integração, LinearAlgebra, já fazia parte da biblioteca padrão e do projeto; nenhuma instalação adicional foi necessária. Fontes e caches dos pacotes novos de StatsBase ocupam aproximadamente 14 MiB neste depot local. É espaço em disco, não RSS. Tempo de download numa instalação limpa não foi medido.

## Benchmark

`benchmarks/benchmark_modular_extensions.py` executa cada cenário em processo independente, cinco vezes, com `/usr/bin/time -v` e `--compile=min`. Os cenários são Julia mínima, ABT mínimo, extensão StatsBase com CSV, extensão LinearAlgebra isolada, ambas combinadas e as duas aplicações finais com JSON. O arquivo `logs/test_logs/modular_benchmark.json` preserva comandos, fontes de benchmark, tempos de parede/CPU e pico de RSS por repetição. Os cenários de StatsBase incluem a leitura CSV porque sua entrada pública é uma tabela ABT; sua diferença de RSS não pode ser atribuída exclusivamente ao pacote.

| Cenário | Parede, mediana s (mín–máx) | CPU usuário s | CPU sistema s | Pico RSS, mediana KiB (mín–máx) |
|---|---:|---:|---:|---:|
| Julia mínima | 0,15 (0,15–0,15) | 0,08 | 0,07 | 164.988 (164.916–165.108) |
| ABT mínimo | 0,31 (0,31–0,32) | 0,31 | 0,08 | 241.292 (241.224–241.612) |
| StatsBase via tabela CSV | 1,43 (1,40–1,46) | 1,35 | 0,17 | 368.084 (368.056–372.932) |
| LinearAlgebra, solução SPD | 0,92 (0,91–0,93) | 0,88 | 0,12 | 309.020 (308.956–310.108) |
| StatsBase + LinearAlgebra | 1,56 (1,56–1,57) | 1,47 | 0,18 | 369.212 (368.840–374.760) |
| Aplicação CSV + StatsBase + JSON | 1,48 (1,48–1,49) | 1,39 | 0,18 | 369.260 (368.068–369.440) |
| Aplicação LinearAlgebra + JSON | 1,04 (1,03–1,05) | 1,00 | 0,13 | 324.428 (323.184–324.720) |

O ABT mínimo ficou 0,16 s e 76.304 KiB de RSS acima da Julia mínima neste ambiente. O cenário StatsBase/CSV ficou 126.792 KiB acima do ABT mínimo; **inclui** CSV, leitura e dados, portanto não é uma medição isolada de alocação do StatsBase. A operação algébrica ficou 67.728 KiB acima do ABT mínimo; inclui fatoração e compilação de métodos. A combinação não somou os picos dos cenários isolados. O teste de registro confirma diretamente que StatsBase não é carregada por um programa ABT mínimo. RSS é memória do processo inteiro; as diferenças são estimativas entre processos, não alocações internas atribuídas a um pacote.

## Reproduzir

```sh
export ABT_JULIA=/caminho/julia-1.13.3/bin/julia
"$ABT_JULIA" --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt operacoes
bin/abt run applications/data/distribuicao_vendas.abt
bin/abt run applications/engineering/rede_condutancias.abt
python3 tests/test_modular_extensions.py --julia "$ABT_JULIA"
"$ABT_JULIA" --startup-file=no --project=. tests/test_extension_registry.jl
python3 benchmarks/benchmark_modular_extensions.py --julia "$ABT_JULIA" --repetitions 5
python3 tests/test_extensions.py --julia "$ABT_JULIA"
python3 tests/test_applications.py --julia "$ABT_JULIA"
python3 tests/run_all_tests.py --julia "$ABT_JULIA"
```

Um caso diferencial pode ser repetido com `python3 tests/test_modular_extensions.py --julia "$ABT_JULIA" --case matriz_nao_positiva`. O script reconstrói os arquivos temporários; o resultado estruturado registra o fonte ABT e os comandos de cada backend.

O contrato de `resolver_sistema_spd` exige Float64 e matriz definida positiva. A representação dos números negativos na aplicação usa `0.0 - 1.0`, pois o parser ABT atual não aceita um sinal unário negativo nesse contexto; a sintaxe da linguagem não foi alterada nesta missão.
