# ABT 0.15.0 — relatório de desempenho da CLI e do caminho científico

Commit-base: `1a36919` (main, ABT 0.14.0). Branch: `perf/abt-015-execution-engine`. Todas as medições abaixo são **reais**, feitas nesta máquina; nada aqui é estimativa, exceto onde está escrito "hipótese".

**Ambiente:** Intel Skylake (x86_64), 4 núcleos, 7,6 GiB de RAM, Linux 7.0 (glibc 2.39), Julia 1.13.3, sem PythonCall. Uma única máquina, sem controle de frequência da CPU e com carga de fundo mínima mas não nula: diferenças abaixo de ~15% devem ser tratadas como ruído.

## 1. Diagnóstico inicial

Até a 0.14.0 a CLI executava o Julia com `--compile=min` por padrão. Esse modo dá partida rápida, mas executa de forma **interpretada** todo código que não esteja nativo numa imagem pré-compilada. A 0.14.0 já tinha registrado o sintoma (alinhamento 1000×1000 levando ~4 min) e recomendado `ABT_JULIA_COMPILE=all`, que custava ~8–9 s fixos até para `mostrar 1`.

As medições desta etapa separaram as fases com `--compile=yes`, o modo padrão do Julia, que não era aceito pela CLI:

| Fase (`mostrar 1`, `--compile=yes`) | Tempo |
|---|---:|
| `using ABT` (carregar a imagem do pacote) | 0,04 s |
| primeira análise (lexer + parser) | 1,49 s |
| primeira execução | 2,92 s |
| script `src/CLI.jl` (`cli_main`) | ~3 s |
| **total do processo** | **~9,3 s** |

**Causa demonstrada:** a imagem pré-compilada do pacote ABT não tinha código nativo para o próprio núcleo da linguagem, porque não havia carga de trabalho de pré-compilação. Com `yes` o Julia recompilava lexer, parser, validação, interpretador e CLI a cada processo. Com `min` esse mesmo código, e também o das bibliotecas científicas, rodava interpretado. Em nenhum modo o usuário tinha ao mesmo tempo partida rápida e código científico compilado.

O custo **não** era do interpretador ABT em si nem do JIT do programa do usuário: era recompilar a ABT a cada execução (`yes`/`all`) ou interpretá-la (`min`).

## 2. Hipóteses investigadas

| Hipótese | Resultado |
|---|---|
| O tempo frio vem do JIT do programa do usuário | **Falsa.** `mostrar 1` custava ~9 s em `yes`. |
| `using ABT` é lento | **Falsa.** 0,04 s. |
| A imagem do pacote não contém código nativo do núcleo | **Verdadeira.** Com uma carga de pré-compilação, o `yes` cai de 9,3 s para 0,28 s em `mostrar 1`. |
| O script `src/CLI.jl` também é recompilado a cada execução | **Verdadeira.** Com `cli_main` dentro do pacote e exercitada na pré-compilação, o `yes` cai de 3,2 s para 0,28 s. |
| Leitura FASTA/FASTQ lenta por instabilidade de tipos | **Verdadeira.** O FASTX é carregado em tempo de execução; com barreira de função, `metricas_leituras` aquecida caiu de 82 para 40 ms. |
| O Julia gerado tem custo anormal | **Falsa.** `mostrar 1` gerado: 0,20 s; FASTQ gerado: 1,07 s. Nenhuma mudança. |

## 3. Decisões de arquitetura

**Perfis explícitos, sem seleção automática.** Com o núcleo pré-compilado, `--compile=yes` atende igualmente bem programas triviais (0,28 s contra 0,24 s em `min`) e programas científicos (de 24 a 200 vezes mais rápido que `min` nesta versão; de 2,6 a 4,4 vezes em aritmética e listas). Uma política automática exigiria analisar o programa e relançar o Julia com outra flag, um processo a mais. Ela erraria em funções indiretas, operações em ramos condicionais e interoperação, e seu único ganho possível seriam ~0,04 s em programas triviais. Foi descartada.

- `padrao` (novo padrão): `--compile=yes`.
- `rapido`: `--compile=min`, para quem quer a menor latência possível em programas muito curtos.
- Precedência: `--perfil` > `ABT_JULIA_COMPILE` (que passou a aceitar também `yes`) > `padrao`. Valores inválidos encerram com código 2, sem executar nada. `abt doctor` informa o modo efetivo e a origem.

**Pré-compilação sem novas dependências.** A carga usa apenas `ccall(:jl_generating_output)` do próprio Julia, e não PrecompileTools nem PackageCompiler. Ela executa programas ABT do núcleo e a CLI de ponta a ponta, com a saída descartada. Ela **não** usa operações que carregam CSV, FASTX, BioAlignments e afins: carregá-las na pré-compilação as tornaria dependências da imagem e tornaria toda partida mais lenta.

## 4. Otimizações implementadas

1. `src/Precompile.jl`: carga de pré-compilação do núcleo e da CLI.
2. `src/CLIMain.jl` e `src/CLIText.jl`: `cli_main` entrou no pacote; os textos de ajuda e versão viraram fonte única, e `--help`/`--version` seguem sem carregar a ABT.
3. `bin/abt`: perfis de execução e `ABT_JULIA_COMPILE=yes`.
4. Leitura FASTA/FASTQ: barreiras de função; checagem de minúsculas sem copiar a sequência (o caminho não ASCII segue igual); validação FASTQ sem montar a mensagem de erro a cada leitura; contagem de bases em tupla, sem alocar por leitura. Resultados e mensagens de erro idênticos, confirmados pelos testes científicos.

## 5. Benchmarks antes e depois

Reproduza com `python3 benchmarks/benchmark_0150.py --julia "$(which julia)" --base <checkout de 1a36919>` e `julia --project=. benchmarks/benchmark_0150_warm.jl`. Os resultados brutos estão em `benchmarks/results/benchmark_0150_cli.json` e `benchmark_0150_warm.json`. Os dados são sintéticos e com semente fixa: FASTQ com 20 000 leituras × 100 pb (~4,5 MB), FASTA com 20 000 sequências de 150–200 pb (~3,6 MB).

### Processo frio (tempo de parede da CLI, mediana de 3 execuções)

Cada medição é um processo novo: partida do Julia, carga da ABT, compilação e execução. ¹ = uma única execução (modos `min` em cenários científicos levam minutos).

| Cenário | 0.14 padrão (`min`) | 0.14 `all` (recomendado na 0.14) | **0.15 `padrao`** | 0.15 `rapido` | Julia direta equivalente | ganho sobre 0.14 padrão | ganho sobre 0.14 `all` | saídas idênticas |
|---|---:|---:|---:|---:|---:|---:|---:|:-:|
| `mostrar 1` | 0.33 s | 8.79 s | **0.28 s** | 0.24 s | — | 1× | 31.4× | sim |
| Aritmética (10 000 chamadas de função) | 104.73 s | 10.86 s | **1.15 s** | 5.07 s | — | 91× | 9.4× | sim |
| Listas (20 000 inteiros) | 13.12 s | 9.64 s | **0.70 s** | 1.85 s | — | 19× | 13.8× | sim |
| FASTA: `resumir_comprimentos` | 47.31 s ¹ | 10.92 s | **1.12 s** | 63.35 s ¹ | 1.97 s | 42× | 9.7× | sim |
| FASTQ: `resumir_fastq` | 68.75 s ¹ | 10.57 s | **1.11 s** | 65.50 s ¹ | 1.72 s | 62× | 9.5× | sim |
| FASTQ: `filtrar_fastq` + `metricas_leituras` | 94.17 s ¹ | 10.64 s | **1.22 s** | 85.84 s ¹ | — | 77× | 8.7× | sim |
| Alinhamento global DNA 1000×1000 | 235.44 s ¹ | 9.95 s | **1.34 s** | 269.24 s ¹ | 1.21 s | 176× | 7.4× | sim |
| Alinhamento global proteína 400×400 (BLOSUM62) | 29.55 s ¹ | 10.62 s | **1.35 s** | 32.53 s ¹ | 1.09 s | 22× | 7.9× | sim |
| Aplicação composta | 176.22 s ¹ | 11.60 s | **3.17 s** | 193.76 s ¹ | — | 56× | 3.7× | sim |

Em todos os cenários as quatro configurações ABT produziram **exatamente a mesma saída**.

**Julia direta** é um script com a mesma validação e o mesmo trabalho (`benchmarks/direct_equivalents_0150.jl`), executado como processo novo; ele paga a compilação do próprio script. A 0.15 aparece mais rápida que a Julia direta em FASTA e FASTQ a frio porque o núcleo da ABT chega pré-compilado e o script não. Isso **não** significa que a ABT seja mais rápida que Julia; a comparação de custo por operação está na tabela aquecida.

### Memória máxima (RSS, MiB)

| Cenário | 0.14 `min` | 0.14 `all` | 0.15 `padrao` | 0.15 `rapido` |
|---|---:|---:|---:|---:|
| `mostrar 1` | 239 | 400 | 240 | 211 |
| FASTQ: `resumir_fastq` | 313 | 438 | 307 | 296 |
| Alinhamento global DNA 1000×1000 | 314 | 416 | 302 | 293 |
| Aplicação composta | 372 | 427 | 323 | 339 |

### Em processo (primeira execução e execuções aquecidas, mediana de 5)

| Cenário | ABT 1ª execução no processo | ABT aquecida (mediana) | ABT alocado (MiB) | Julia equivalente aquecida | Julia alocado (MiB) | razão ABT/Julia |
|---|---:|---:|---:|---:|---:|---:|
| `mostrar 1` | 815 ms | 0.1 ms | 0.0 | — | — | — |
| Aritmética (10 000 chamadas de função) | 663 ms | 475.7 ms | 110.8 | — | — | — |
| Listas (20 000 inteiros) | 542 ms | 135.1 ms | 297.8 | — | — | — |
| FASTA: `resumir_comprimentos` | 630 ms | 53.1 ms | 18.0 | 19.0 ms | 16.3 | 2.8× |
| FASTQ: `resumir_fastq` | 490 ms | 36.1 ms | 32.7 | 26.2 ms | 32.0 | 1.4× |
| FASTQ: `filtrar_fastq` + `metricas_leituras` | 499 ms | 41.6 ms | 34.7 | — | — | — |
| Alinhamento global DNA 1000×1000 | 922 ms | 5.7 ms | 1.4 | 4.6 ms | 1.0 | 1.2× |
| Alinhamento global proteína 400×400 (BLOSUM62) | 676 ms | 1.4 ms | 0.4 | 0.8 ms | 0.2 | 1.8× |

Em processo, o custo da ABT sobre a Julia equivalente fica entre 1,2× e 2,8×, com alocações praticamente iguais. `resumir_comprimentos` faz mais trabalho que o equivalente: valida o alfabeto e conta bases e GC por registro. A coluna "1ª execução" inclui compilação e não é comparável com a Julia equivalente, que reaproveita código já compilado no mesmo processo.

## 6. Compatibilidade

- **Muda:** o padrão de compilação, de `min` para `yes`. É só desempenho: saídas, erros e códigos de saída idênticos, testados em `tests/test_execution_profiles.py` e nas suítes abaixo. Quem fixou `ABT_JULIA_COMPILE=min` mantém o comportamento anterior.
- **Não muda:** sintaxe, APIs públicas, resultados científicos, interoperação, `ABT_JULIA_COMPILE` (agora com `yes` também).
- **Corrigido de passagem:** o instalador da 0.14.0 omitia `src/StdlibBioAdvanced.jl` e a cópia instalada não carregava a ABT; o teste de instalação não pegava porque só verificava `--version`. Agora todos os arquivos de `src/` estão listados, e um teste roda um programa a partir da cópia instalada.
- **Pré-compilação:** a primeira execução depois de instalar ou atualizar leva ~15 s para gerar a imagem, uma única vez por modo de compilação.

## 7. Resultados dos testes

Linux, Julia 1.13.3, sem PythonCall.

| Suíte | Resultado |
|---|---|
| Histórica (`run_all_tests.py`, 52 arquivos) | 45 PASS, 2 PROBE, 4 PARTIAL, **1 FAIL**, 0 TIMEOUT, no commit `feb2567` |
| FAIL acima: `test_cli_identity.jl` | Real: a nova ajuda mencionava "Julia", e o contrato de identidade da CLI proíbe. Corrigido (as variáveis de ambiente ficam no manual); depois da correção, 20/20 PASS. A suíte inteira **não** foi repetida após essa correção de texto. |
| Perfis de execução (`test_execution_profiles.py`, novo) | 10/10 OK (precedência, ambiente, valores inválidos, `doctor`, mesmas saídas, erros e códigos de saída nos perfis) |
| Instalação (`test_install_cli.py`, 1 teste novo) | 12/12 OK. Antes: com o atalho do juliaup e `HOME` temporário, o Julia não respondia a `--version` (falha de ambiente, 8 testes); com o binário real e o depósito de pacotes existente, uma rodada teve 3 erros cuja causa não capturei e a repetição passou 12/12. |
| Aplicações (112 casos, 3 modos) | 112 PASS |
| Aplicações 0.14 (3 modos e erros) | 27 PASS |
| Diferenciais de bioestatística e científico | 19 PASS e 16 PASS |
| Documentação (`validate_docs.py`) | 58 PASS, 1 FAIL (exemplo `Python.math`, sem PythonCall) |
| Referência gerada e privacidade | OK |

Os 4 PARTIAL e o FAIL da documentação vêm de PythonCall/NumPy ausentes (dependência opcional); os 2 PROBE são scripts exploratórios. Os testes científicos (`test_bioinformatics_0140`, `test_scientific_0130`) foram rodados também logo depois das mudanças de leitura FASTA/FASTQ: 0 falhas.

## 8. Limitações

- Uma única máquina; poucas repetições nos cenários `min` (uma execução).
- O perfil `rapido` continua lento para código científico, por desenho.
- A primeira execução de uma operação científica num processo ainda compila código do FASTX/BioAlignments (~0,5–0,9 s); a pré-compilação desses pacotes exigiria carregá-los na partida ou adotar extensões de pacote (proposta abaixo).
- O build do site (Documenter) não foi executado localmente.

## 9. Alternativas descartadas

- **Seleção automática de perfil:** ganho máximo de ~0,04 s, ao custo de um segundo processo e de fragilidade (seção 3).
- **PackageCompiler / sysimage:** gera artefato local, grande e dependente da máquina; o ganho que justificaria esse custo já foi obtido sem ele.
- **Pré-compilar os pacotes científicos dentro da imagem da ABT:** tornaria FASTX, BioAlignments, CSV e afins dependências de carga e deixaria toda partida mais lenta.
- **Gerar Julia que chame a imagem da ABT em vez de embutir a biblioteca:** mudaria a arquitetura do gerador; o custo medido não justifica.

## 10. Próximas oportunidades

1. **Interpretador:** cada chamada de função ABT copia o ambiente filtrando todas as entradas (~48 µs por chamada na aritmética aquecida, 110 MiB alocados para 10 000 chamadas). *Hipótese não medida isoladamente:* essa cópia domina o custo. Corrigir exige mexer no interpretador, fora do escopo desta entrega.
2. **Extensões de pacote** (`[weakdeps]`/`[extensions]`) para pré-compilar o caminho científico sem afetar a partida dos programas simples.
3. `resumir_comprimentos`: evitar `description` e as contagens quando só os comprimentos são pedidos.
