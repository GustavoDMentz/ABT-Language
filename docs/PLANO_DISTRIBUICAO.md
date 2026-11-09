# Investigação de distribuição Linux autossuficiente

As medições abaixo são da CLI anterior à otimização. Veja `RELATORIO_DESEMPENHO_0118.md` para os resultados atuais e a arquitetura escolhida.

Esta entrega é um CLI com Julia instalada separadamente. Não contém um runtime Julia embutido.

## Medição local inicial

No ambiente de desenvolvimento, a instalação Julia 1.13.3 ocupa cerca de **1,1 GiB** em disco (`du -sh` da árvore Julia), e a árvore do projeto ocupa cerca de **1,7 MiB**. Esses números não são o tamanho mínimo de uma distribuição ABT: a instalação Julia inclui componentes que uma imagem reduzida talvez não precise.

Cinco processos independentes por comando, medidos com `/usr/bin/time` no Ubuntu local, deram as seguintes medianas de tempo total e pico de RSS (`benchmarks/results/distribution_measurements.json`):

| Comando | Tempo total | Pico de RSS |
|---|---:|---:|
| `abt --versao` | 0,20 s | 206 MiB |
| `abt verificar` no exemplo básico | 5,21 s | 364 MiB |
| `abt executar` no exemplo básico | 5,41 s | 365 MiB |

A primeira implementação carregava o compilador antes de `--versao`; sua mediana era 3,76 s e 360 MiB (`benchmarks/results/distribution_measurements_before.json`). O comando informativo agora responde antes de carregar o compilador. Execução e verificação continuam incluindo inicialização e JIT do Julia. Estas medições não são uma comparação de desempenho entre plataformas nem uma promessa para um pacote autossuficiente; devem ser repetidas no artefato de distribuição final.

## Opções a avaliar

1. **Julia externa, lançador `abt`**: solução entregue; instalação pequena do ABT, depende de Julia 1.13.3 no PATH ou em `ABT_JULIA`.
2. **Aplicativo compilado com PackageCompiler.jl**: `create_app` pode produzir um bundle com executável e bibliotecas necessárias, mas exige estruturar o ABT como pacote Julia com entrada `julia_main()::Cint`. A relocabilidade de dependências, imports tardios, `ABT.packages.toml` e PythonCall precisa de protótipo e execução em outra máquina antes de prometer compatibilidade. Referência: https://julialang.github.io/PackageCompiler.jl/stable/apps.html .
3. **Árvore Julia redistribuída com o ABT**: implantação simples conceitualmente, mas tamanho inicial próximo ao runtime completo, além de dependências de sistema e obrigações de licença.

Para uma decisão futura, medir tamanho comprimido e instalado, tempo até primeira execução, memória residente, compatibilidade de `ABT.packages.toml`, interoperabilidade Python, licenças, portabilidade entre distribuições Ubuntu e reprodução com checksums/manifestos. Não criar um daemon Julia persistente como padrão. PackageCompiler.jl não estava instalado neste ambiente e nenhum binário autossuficiente foi gerado ou aprovado.
