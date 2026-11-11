# ABT 0.11.8 — inicialização e execução

## Arquitetura escolhida

O ABT continua sendo interpretado pelo mesmo módulo Julia. A CLI agora carrega `ABT` como pacote Julia pré-compilável (`Project.toml` e `using ABT`) e inicia o processo com `--compile=min`. O instalador pré-compila esse módulo no cache Julia do usuário. `ABT_JULIA_COMPILE=all` permite JIT completo para cargas longas; `no` é aceito apenas para diagnóstico. Não há daemon, cache de resultados de programas ou segundo interpretador.

`Base.include_dependency(ABT_PACKAGE_FILE)` invalida o cache do módulo se `ABT.packages.toml` mudar. Um teste copia o pacote, altera a lista de funções de Dates e confirma que o processo seguinte enxerga o conteúdo novo.

## Metodologia

- Ambiente: Ubuntu local, Julia 1.13.3 em `<JULIA_BIN>`.
- `benchmarks/bench_startup.py` executa processos independentes por cenário, mede latência externa com `time.perf_counter()` e pico de RSS com `/usr/bin/time -f '%e %M'`. Guarda cada amostra, stdout, stderr e código de retorno em JSON.
- Cenários: lançador isolado, Julia vazio, versão, doctor, check/run de Olá Mundo, pipeline, agregação matemática, programa representativo e arquivo de 1.000 atribuições.
- Mediana, p95 interpolado, desvio padrão e pico de RSS são calculados das amostras. A primeira amostra fica registrada separadamente nos JSONs; não foi descartada.
- O cache de páginas do sistema operacional não foi limpo, portanto “frio” significa cache Julia novo, **não** inicialização fria do sistema operacional. `isolated_install_timing.json` mede instalação num HOME e depot temporários e as duas primeiras execuções instaladas.
- `profile_internal.json` instrumenta include, leitura, tokenização, parsing, lowering, validação, execução e impressão. Essas durações de primeiro uso incluem compilação JIT, alocações e sobrecarga da própria instrumentação; `profile_repeated.log` mostra o segundo uso no mesmo processo para separar o trabalho aquecido.
- `benchmarks/measure_process_phases.py` mede o instante em que um Julia vazio emite uma marca com flush e o instante de encerramento do processo. A mediana em dez amostras foi 0,145 s até a marca e 0,031 s da marca ao fim. O primeiro trecho contém criação do processo, inicialização Julia e a impressão mínima; o segundo aproxima o custo de encerramento.

## Gargalo identificado

No processo antigo, Julia vazio inicia em cerca de 0,16 s e o lançador em cerca de 0,006 s, enquanto Olá Mundo leva cerca de 5,1 s. A instrumentação de primeiro uso encontrou medianas de cerca de 0,98 s no carregamento do módulo, 1,11 s na primeira tokenização, 0,23 s no primeiro parsing, 0,25 s no lowering, 1,36 s na validação e 0,65 s na execução. A segunda passagem no mesmo processo leva dezenas de microssegundos para cada etapa medida. O custo dominante é carregar e compilar métodos Julia para um processo de vida curta; a avaliação efetiva do Olá Mundo é pequena.

## Resultados

Os dados brutos da comparação definitiva ficam em `logs/perf_logs/before_quiet.json` e `logs/perf_logs/after_quiet.json`. Há dez execuções independentes por cenário em cada versão, sem outros testes iniciados durante cada rodada, no mesmo host, Julia e `JULIA_DEPOT_PATH`. Os dados exploratórios anteriores ficam em `baseline_external.json`, `after_external.json`, `before_matched.json` e `compile_modes.json`; `before_matched.json` sofreu concorrência da suíte histórica e não entrou na tabela. `isolated_install_timing.json` mede a instalação nova. O p95 de dez repetições ainda é sensível à carga do host.

| Cenário | Antes mediana/p95 | Depois mediana/p95 | Pico RSS antes/depois |
|---|---:|---:|---:|
| `abt --version` | 0,260/0,269 s | 0,180/0,185 s | 203/168 MiB |
| `abt doctor` | 0,016/0,016 s | 0,017/0,018 s | 29/29 MiB |
| `abt check ola.abt` | 4,971/5,898 s | 0,336/0,365 s | 368/234 MiB |
| `abt run ola.abt` | 4,923/5,105 s | 0,344/0,363 s | 368/234 MiB |
| Pipeline | 5,403/5,802 s | 0,736/0,774 s | 368/290 MiB |
| Agregação matemática | 5,335/5,560 s | 0,745/0,776 s | 369/290 MiB |
| Programa representativo | 5,274/5,529 s | 0,710/0,836 s | 371/291 MiB |
| 1.000 atribuições | 5,183/5,271 s | 1,992/2,085 s | 369/264 MiB |

O desvio padrão de `abt run ola.abt` caiu de 0,124 s para 0,014 s; os demais desvios e amostras individuais estão nos JSONs. Não houve limpeza do cache do sistema operacional.

Em instalação isolada com depot novo, instalar e aquecer o cache levou 7,773 s; primeira e segunda execuções instaladas do Olá Mundo levaram 0,327 s e 0,322 s. Em uma árvore ainda não pré-compilada, a primeira chamada observada levou 0,94 s. Portanto, a meta de 500 ms é atingida para Olá Mundo **após a pré-compilação realizada pelo instalador**, no host medido. A meta de 100 ms não é atingida: o processo Julia vazio por si só leva mais de 160 ms.

## Estratégias avaliadas

- Apenas transformar ABT em pacote pré-compilável, mantendo JIT normal, reduziu Olá Mundo de cerca de 5,1 s para cerca de 4,0 s no protótipo. O ganho isolado não atendia à meta.
- `--compile=min` sem pacote reduziu Olá Mundo a aproximadamente 0,56 s; `--compile=no` a aproximadamente 0,53 s em três amostras, mas `no` elimina compilação de mais métodos e não foi escolhido como padrão.
- Pacote pré-compilável mais `--compile=min` atingiu cerca de 0,3 s. Não requer dependência adicional nem um processo persistente.
- Uma sonda explícita com 10.000 atribuições (`benchmarks/bench_long_modes.py`, três processos por modo) mediu 16,091/16,696/16,379 s em `min` e 4,323/4,342/4,307 s em `all`, com a mesma saída `10000`. Esta é uma regressão real para um programa grande quando se usa o padrão voltado a baixa latência. O modo `all` permanece disponível e documentado. Não foi introduzida uma heurística de troca automática baseada em tamanho de arquivo, pois ela não representa de forma confiável o custo computacional do programa.
- Um daemon poderia evitar a inicialização de Julia, mas exigiria IPC local, isolamento de estado, sinais, segurança entre usuários e preservação de stdout/stderr. Não foi implementado porque a meta principal foi alcançada sem essa complexidade.
- [PackageCompiler.jl `create_app`](https://julialang.github.io/PackageCompiler.jl/stable/apps.html) poderia produzir um bundle executável, mas exige empacotamento e verificação de relocabilidade, bibliotecas externas e PythonCall. Não foi instalado ou usado nesta entrega; não há runtime independente.
- `PrecompileTools.jl` não foi introduzido: o pacote Julia comum mais o modo de compilação já atingiu a meta e evitou uma dependência de distribuição.

## Validação e limites

`tests/test_perf_semantics.py` compara resultados observáveis dos modos `min` e `all`, executa arquivos modificados entre chamadas, execuções simultâneas, interrupção por SIGINT seguida de nova chamada, invalidação do cache de pacotes e uma guarda local de latência: **5/5 testes aprovados** em `logs/perf_logs/perf_semantics_tests.log`. `tests/test_install_cli.py` cobre instalação, atualização, remoção, conflito, rollback de pré-compilação, atualização do manifesto e diagnósticos: **8/8 testes aprovados** em `logs/perf_logs/install_cli_tests.log`. Uma falha intermediária na preparação da cópia de teste foi corrigida antes da execução final.

A suíte histórica completa terminou com **38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT** em `logs/perf_logs/final_full.log`; as sondas não são contadas como aprovação funcional. Ela inclui diferencial de 1.000 casos, interoperabilidade, testes estáticos e legados. A execução adicional de `tests/test_differential_1000.jl` com `--compile=min` registrou **1000 PASS, 0 FAIL** em `logs/perf_logs/differential_compile_min.log`. Os exemplos de import Julia e Python pela CLI rápida também foram executados; a carga Python produziu `10` e `2.5` sem erro.

Após o último ajuste de diagnóstico do lançador, `tests/test_cli_identity.jl` foi repetido separadamente e registrou **20/20 asserções aprovadas** em `logs/perf_logs/final_cli_identity.log`. Nenhum arquivo do parser ou executor ABT foi alterado depois da suíte histórica completa.

O modo `min` favorece programas curtos e **perde desempenho no arquivo de 10.000 atribuições medido**. Use `ABT_JULIA_COMPILE=all` para cargas longas ou compare os dois modos no seu programa. O limite de 500 ms não é promessa para todos os programas ou computadores; pipeline e agregação já ultrapassam esse valor neste host. PythonCall continua opcional e sua primeira importação pode custar mais. Alterações de código ou manifesto podem invalidar o cache Julia e acrescentar custo à próxima chamada. O ABT não é sandbox para bibliotecas Julia ou Python.

## Reproduzir no Ubuntu

```bash
python3 tools/install.py
abt doctor
abt run benchmarks/scenarios/ola.abt
ABT_JULIA_COMPILE=all abt run benchmarks/scenarios/ola.abt
ABT_TEST_JULIA=/caminho/julia-1.13.3 python3 tests/test_install_cli.py
ABT_TEST_JULIA=/caminho/julia-1.13.3 python3 tests/test_perf_semantics.py
python3 benchmarks/bench_startup.py --julia /caminho/julia-1.13.3 --repeats 10 --output logs/perf_logs/minha_medicao.json
ABT_REQUIRE_PYTHON=1 python3 tests/run_all_tests.py --julia /caminho/julia-1.13.3 --timeout 180
```

PythonCall exige configuração Julia/Python apropriada para os testes opcionais. No ambiente medido foi usado `JULIA_PYTHONCALL_EXE=/usr/bin/python3` e o depot local documentado nos logs.

Comandos exatos usados neste host para repetir as medições da árvore atual:

```bash
cd <ABT_PERF_WORKTREE>
export ABT_JULIA=<JULIA_BIN>
export JULIA_DEPOT_PATH=/tmp/abt-perf-final-depot:<JULIA_DEPOT>
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
python3 benchmarks/bench_startup.py --julia "$ABT_JULIA" --repeats 10 --output logs/perf_logs/repeticao.json
python3 benchmarks/measure_process_phases.py --julia "$ABT_JULIA" --output logs/perf_logs/fases_repeticao.json
python3 benchmarks/bench_long_modes.py --julia "$ABT_JULIA" --output logs/perf_logs/modos_repeticao.json
ABT_TEST_JULIA="$ABT_JULIA" python3 tests/test_install_cli.py
ABT_TEST_JULIA="$ABT_JULIA" python3 tests/test_perf_semantics.py
ABT_REQUIRE_PYTHON=1 python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
ABT_REQUIRE_PYTHON=1 "$ABT_JULIA" --startup-file=no --compile=min tests/test_differential_1000.jl
```

Para repetir o “antes” no mesmo host, use a árvore anterior `abt_install_cli` da entrega `abt_instalacao_cli_0118.zip` como `--launcher-root ../abt_install_cli`; os dados brutos já estão no ZIP atual.
