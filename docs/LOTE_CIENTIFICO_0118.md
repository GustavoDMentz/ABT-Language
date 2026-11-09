# ABT 0.11.8 — lote científico

## Operadores

A precedência, da mais forte à mais fraca, é: parênteses e chamadas; exponenciação `^` (associativa à direita); sinais prefixos `+` e `-`; `*` e `/`; `+` e `-` binários; comparações; `e`; `ou`. Os sinais prefixos exigem `Int64` ou `Float64`. A exponenciação usa o operador Julia `^` nos valores numéricos ABT; por exemplo, `-2^2` resulta em `-4`, `(-2)^2` em `4` e `2.0^-2` em `0.25`. Um expoente negativo com base inteira conserva a regra Julia (erro de domínio). Operações com tipos comprovadamente inválidos são rejeitadas antes de gerar código.

## Extensões

| Operação | Pacote | Contrato principal |
| --- | --- | --- |
| `agrupar_dados(tabela, grupo, valor, politica)` | DataFrames.jl | Grupo textual, valor `inteiro` ou `real`, ordem da primeira ocorrência, política `erro` ou `ignorar_linha`. |
| `testar_grupos(grupos, a, b, metodo)` | HypothesisTests.jl | Dois grupos existentes com ao menos duas observações cada; teste t bilateral `welch` ou `student`. |
| `categorias(tabela, coluna, niveis, politica)` | CategoricalArrays.jl | Níveis textuais únicos e explícitos; rejeita valores fora deles. |
| `probabilidade_normal(media, desvio, limiar)` | Distributions.jl | Parâmetros finitos, desvio positivo; devolve probabilidade estritamente acima do limiar. |
| `grafico(tabela, x, y, modo)` | ABT | Eixos numéricos sem ausentes, modo `linha` ou `pontos`; devolve especificação estruturada. |
| `salvar_figura(figura, caminho)` | Cairo.jl | Exporta PNG/SVG; retorna caminho e quantidade de pontos. |
| `alinhar_sequencias(fasta, id_a, id_b, modo, acerto, erro, abertura, extensao)` | BioAlignments.jl | FASTA validado, IDs distintos, modo global/local e pontuações inteiras explícitas; devolve métricas. |

CairoMakie.jl foi avaliada, mas sua pré-compilação excedeu a RAM/swap disponíveis neste ambiente; a exportação usa Cairo.jl com desenho determinístico de linhas e pontos. As bibliotecas são carregadas apenas quando a operação correspondente é executada. JSON3.jl foi deixado de fora porque JSON.jl já atende ao contrato de JSON estruturado. HTTP.jl não entra neste lote: nenhuma das três aplicações precisa de rede.

## Aplicações

- `applications/science/estatistica.abt`: CSV tipado, grupos, Welch, categorias e probabilidade normal; resultado JSON estruturado.
- `applications/science/visualizacao.abt`: CSV tipado, filtro, gráfico de linha e PNG.
- `applications/science/alinhamento.abt`: FASTA, descrição das sequências e alinhamento global.

Execute a partir da raiz do projeto:

```bash
JULIA_DEPOT_PATH=/caminho/para/depot julia --project=. --startup-file=no src/CLI.jl applications/science/estatistica.abt
JULIA_DEPOT_PATH=/caminho/para/depot julia --project=. --startup-file=no src/CLI.jl applications/science/visualizacao.abt
JULIA_DEPOT_PATH=/caminho/para/depot julia --project=. --startup-file=no src/CLI.jl applications/science/alinhamento.abt
```

`tests/test_batch_118.py` executa casos consolidados nos três backends. Os resultados estruturados ficam em `logs/test_logs/batch_118_results.json`. A suíte histórica é `tests/run_all_tests.py`.

## Limites

O gráfico materializa os dois eixos antes da exportação. `agrupar_dados` materializa as colunas de agrupamento; tabelas gigantes exigirão abordagem em streaming em trabalho futuro. O teste t supõe observações independentes e aproximadamente normais em cada grupo; `student` também supõe variâncias iguais. ABT não verifica essas hipóteses automaticamente. Pontuações de alinhamento são fornecidas pelo programa, sem escolha científica implícita. A interoperabilidade Julia/Python executa código confiável no processo e não estabelece um sandbox.
