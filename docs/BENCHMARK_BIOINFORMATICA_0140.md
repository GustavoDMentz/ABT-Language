# Benchmarks de bioinformática — ABT 0.14.0

Medições reais, repetíveis e limitadas. **Máquina:** CPU `skylake` (Intel Skylake), 4 núcleos, 7.6 GiB de RAM, Julia 1.13.3, Linux. O JIT do Julia já gera código para o processador local (`-C native` por padrão); não há flag adicional de otimização por CPU a configurar. Uma única máquina, carga de fundo mínima mas não nula: tratar diferenças menores que ~15% como ruído.

## Como reproduzir

```bash
julia --project=. benchmarks/benchmark_bio_0140.jl                       # execuções aquecidas, em processo
python3 benchmarks/benchmark_bio_0140_cli.py --julia "$(which julia)"    # processos frios (CLI), tempo e RSS
```

Os dados são sintéticos, gerados com sementes fixas. Resultados brutos: `benchmarks/results/benchmark_bio_0140_warm.json`, `..._warm_before_optimization.json` e `..._cli.json`.

## 1. Execuções aquecidas (mediana de 3–5 execuções após aquecimento)

A coluna "Julia direta" lê/alinha com FASTX.jl e BioAlignments.jl **sem** a validação que a ABT faz (alfabeto base a base, qualidades Phred, identificadores duplicados, `N`). A diferença, portanto, inclui trabalho de correção e não é apenas custo da camada ABT. O alinhamento tem metodologia equivalente (mesmo algoritmo e modelo); a diferença é a construção do resultado estruturado (colunas, contagens, texto do alinhamento).

| Cenário | ABT antes da otimização | ABT 0.14.0 | Julia direta | Alocado ABT (MiB) | Alocado direta (MiB) |
|---|---:|---:|---:|---:|---:|
| Alinhamento global 1000×1000 (DNA) | 7.0 ms | 6.3 ms | 5.6 ms | 1.3 | 1.0 |
| Alinhamento global 2000×2000 (DNA) | 25.5 ms | 23.6 ms | 22.6 ms | 4.5 | 3.9 |
| `resumir_comprimentos`, 20 000 sequências (~3,5 Mb) | 645.5 ms | 88.3 ms | 7.0 ms | 42.6 | 13.4 |
| `metricas_leituras`, 20 000 leituras × 100 pb | 153.6 ms | 83.1 ms | 17.4 ms | 48.0 | 34.0 |
| `resumir_fastq`, 20 000 leituras × 100 pb | 105.3 ms | 64.3 ms | — | 42.1 | — |
| GC + motivo + tradução, 100 kb | 4.4 ms | 3.6 ms | — | 0.6 | — |

**Otimização feita nesta etapa.** O perfil de alocações mostrou que os laços de leitura FASTA/FASTQ já existentes percorriam a sequência com tipo desconhecido (o módulo FASTX é carregado dinamicamente), alocando uma tupla por base. Foram fixados os tipos, a validação passou a usar uma tabela de bytes e a contagem de bases uma única passada; mensagens de erro e resultados permanecem idênticos (suítes de regressão abaixo). O ganho em `resumir_comprimentos` foi de ~7×; em `metricas_leituras`, ~2×. Ainda restam fatores de 5 a 12 sobre a Julia direta, atribuíveis em parte à validação.

## 2. Processos frios (CLI), mediana de 3 execuções

| Cenário | Tempo de parede | RSS máximo (MiB) |
|---|---:|---:|
| `abt --version` (caminho rápido, sem carregar ABT) | 190.0 ms | 167 |
| `abt run` de `mostrar 1` (carrega ABT) | 370.0 ms | 240 |
| `julia --project -e nothing` | 150.0 ms | 161 |
| FASTQ, métricas de 20 000 leituras: ABT, `--compile=min` (padrão) | 101.1 s | 330 |
| FASTQ, métricas de 20 000 leituras: ABT, `ABT_JULIA_COMPILE=all` | 8760.0 ms | 435 |
| FASTQ, métricas de 20 000 leituras: Julia direta | 470.0 ms | 275 |
| FASTA, comprimentos de 20 000 sequências: ABT, `--compile=min` (padrão) | 48.1 s | 371 |
| FASTA, comprimentos de 20 000 sequências: ABT, `ABT_JULIA_COMPILE=all` | 7960.0 ms | 434 |
| FASTA, comprimentos de 20 000 sequências: Julia direta | 330.0 ms | 264 |
| Alinhamento global 1000×1000: ABT, `--compile=min` (padrão) | 244.2 s | 316 |
| Alinhamento global 1000×1000: ABT, `ABT_JULIA_COMPILE=all` | 8790.0 ms | 420 |
| Alinhamento global 1000×1000: Julia direta | 960.0 ms | 292 |

**Achado importante.** A CLI usa `--compile=min` por padrão, o que dá inicialização rápida (0,37 s), mas executa em modo interpretado todo código Julia ainda não pré-compilado. Em cargas de dados isso é dramático: 1000×1000 de alinhamento leva ~4 min no padrão contra ~9 s com `ABT_JULIA_COMPILE=all` e ~1 s em Julia direta. Já `ABT_JULIA_COMPILE=all` custa ~7,7 s fixos de inicialização, mesmo para `mostrar 1`. Recomendação para usuários: programas pequenos, o padrão; análises de arquivos ou alinhamentos, `ABT_JULIA_COMPILE=all`. **Não alteramos o padrão** do `bin/abt` nesta etapa porque é uma decisão de projeto que afeta todos os programas; a pendência está registrada abaixo.

## Limitações das medições

Uma máquina, 3 repetições (CLI) e 3–5 (aquecido); sem controle de frequência da CPU; memória medida por RSS máximo do processo (inclui o runtime Julia) e por bytes alocados. Não se afirma superioridade de desempenho da ABT sobre Julia direta: a ABT é mais lenta nos cenários medidos, por validar mais e por construir resultados estruturados. Não foram medidos arquivos acima de ~5 MB nem execução multi-thread.

## Pendência proposta

Avaliar um modo de compilação adaptativo na CLI (por exemplo, escolher `all` quando o programa usa leitura de arquivos ou alinhamento), ou pré-compilar via PackageCompiler as operações de bioinformática. Requer decisão sobre latência de partida versus throughput e testes dedicados.
