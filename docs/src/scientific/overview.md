# Bibliotecas científicas 0.13.0

Esta etapa adiciona vinte operações ao catálogo modular do ABT. A [referência de assinaturas](../standard-library/scientific0130.md) descreve cada chamada. Todas recebem argumentos explícitos, retornam valores reutilizáveis e deixam a apresentação a cargo de `mostrar`.

## Bioinformática

`ler_fastq(caminho, "DNA", "rejeitar", "phred33")` cria um leitor reutilizável. `resumir_fastq` percorre os registros em fluxo e devolve contagens de bases e qualidade Phred. `registros_fastq` materializa os registros; use apenas quando couberem em memória. Arquivos truncados, qualidades fora da codificação Phred+33 e bases incompatíveis são erros. `frequencias_kmers` exige DNA A/C/G/T maiúsculo, conta janelas sobrepostas e ordena as frequências pela sequência. `complemento_reverso` aceita A/C/G/T/N. `traduzir_dna` usa o código genético padrão, quadro inicial, comprimento múltiplo de três e representa parada por `*`.

## Tabelas tipadas

As novas operações preservam o esquema declarado por `ler_csv`: seleção, renomeação, ordenação estável, remoção de duplicatas, junção e exportação. A junção exige chaves de mesmo tipo, rejeita chaves ausentes e nomes não chave sobrepostos; os modos são `interna` e `esquerda`. Na junção à esquerda, colunas direitas sem correspondência são `missing`. `ordenar_tabela` requer direção por coluna e política explícita `erro`, `primeiro` ou `ultimo` para ausentes. Exportação exige marcador textual não vazio que não colida com textos existentes. Os filtros e resumos tabulares prévios continuam disponíveis. Agrupamento por várias chaves e transformação genérica de colunas não integram esta etapa.

## Estatística e álgebra linear

`ajustar_valores_p` usa MultipleTesting.jl e preserva a ordem das hipóteses. Bonferroni e Holm controlam FWER; BH e BY controlam FDR sob suas respectivas hipóteses. A operação exige lista não vazia de `Float64` finitos entre zero e um e `alpha` em (0,1). A decisão `rejeitar` é calculada com o valor ajustado e o mesmo `alpha`. Não converte valores-p ausentes ou inválidos.

As operações matriciais usam listas retangulares não vazias de `Float64` finitos. Produto e solução exigem dimensões compatíveis. Determinante, autovalores simétricos e solução geral exigem matriz quadrada. A simetria é verificada exatamente antes de `eigen`; a interpretação de resultados numéricos ainda requer atenção às tolerâncias do problema. QR e SVD retornam fatores estruturados. O posto requer tolerância absoluta explícita; singularidade e resultados não finitos são erros.

## Otimização e visualização

`minimizar_polinomio` usa Optim.jl/Brent para um polinômio univariado descrito por coeficientes `Float64` em ordem crescente, num intervalo e com tolerâncias e limite de iteração explícitos. O resultado contém solução, objetivo, iterações, convergência e status. Brent é uma busca local; não há garantia de mínimo global em funções multimodais. A interface atual não representa um callback ABT com contrato uniforme nos três backends; por isso não aceita funções arbitrárias nem otimização multivariada.

A [aplicação de visualização](../examples/programs.md) reutiliza o gráfico de linhas/pontos e exportação PNG/SVG já existentes. Histograma, boxplot, barras e mapa de calor configuráveis permanecem fora desta etapa. CairoMakie.jl não foi adicionado como segunda dependência gráfica.

## Exemplos

Na raiz do repositório, após `Pkg.instantiate()`:

```sh
bin/abt run applications/scientific_0130/sequenciamento.abt
bin/abt run applications/scientific_0130/expressao.abt
bin/abt run applications/scientific_0130/algebra.abt
bin/abt run applications/scientific_0130/visualizacao.abt
```

Os dados sintéticos estão em `applications/scientific_0130/data/`. A análise de expressão corrige valores-p de exemplo; ela não é uma análise diferencial validada de RNA-seq. A auditoria de escopo em `docs/scientific_0130/AUDITORIA.md` distingue as capacidades disponíveis das propostas futuras.
