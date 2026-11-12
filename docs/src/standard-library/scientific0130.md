# Bibliotecas científicas 0.13.0

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `ler_fastq`

`ler_fastq(caminho, alfabeto, ambiguidade, codificacao)`

Declara leitura FASTQ validada com codificação de qualidade explícita.

- **Parâmetros e padrões:** arquivo, DNA, rejeitar/permitir_N, phred33
- **Retorno:** leitor FASTQ reutilizável
- **Pré-condições, ausentes, erros e limites:** arquivo, alfabeto, política, codificação
- **Efeitos:** Nenhum.
- **Dependência Julia:** FASTX.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `resumir_fastq`

`resumir_fastq(fastq)`

Resume bases e qualidades de um FASTQ sem materializar registros.

- **Parâmetros e padrões:** leitor FASTQ
- **Retorno:** registros, bases, A/C/G/T/N e Phred mínimo/médio/máximo
- **Pré-condições, ausentes, erros e limites:** vazio, truncado, bases, qualidades
- **Efeitos:** Lê arquivo em fluxo.
- **Dependência Julia:** FASTX.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `registros_fastq`

`registros_fastq(fastq)`

Materializa leituras FASTQ com sequência e métricas por registro.

- **Parâmetros e padrões:** leitor FASTQ
- **Retorno:** lista de registros com sequência, contagens e resumo Phred
- **Pré-condições, ausentes, erros e limites:** vazio, truncado, bases, qualidades
- **Efeitos:** Lê arquivo em fluxo.
- **Dependência Julia:** FASTX.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `frequencias_kmers`

`frequencias_kmers(dna, k)`

Conta todas as janelas de comprimento k de uma sequência DNA.

- **Parâmetros e padrões:** DNA ACGT maiúsculo, k inteiro positivo até comprimento
- **Retorno:** k, total e frequências lexicográficas sobrepostas
- **Pré-condições, ausentes, erros e limites:** alfabeto, vazio, k
- **Efeitos:** Nenhum.
- **Dependência Julia:** BioSequences.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `complemento_reverso`

`complemento_reverso(dna)`

Produz a sequência DNA reversa complementar.

- **Parâmetros e padrões:** DNA ACGTN maiúsculo não vazio
- **Retorno:** texto DNA reverso complementar
- **Pré-condições, ausentes, erros e limites:** alfabeto, vazio
- **Efeitos:** Nenhum.
- **Dependência Julia:** BioSequences.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `traduzir_dna`

`traduzir_dna(dna)`

Traduz DNA codificante no quadro inicial pelo código padrão.

- **Parâmetros e padrões:** DNA ACGT maiúsculo, comprimento múltiplo de 3
- **Retorno:** proteína no código padrão, quadro 1; stop como *
- **Pré-condições, ausentes, erros e limites:** alfabeto, vazio, comprimento
- **Efeitos:** Nenhum.
- **Dependência Julia:** BioSequences.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `produto_matricial`

`produto_matricial(a, b)`

Multiplica duas matrizes compatíveis.

- **Parâmetros e padrões:** duas matrizes retangulares Float64 finitas
- **Retorno:** matriz como lista de linhas
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões, não finito
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib)
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `transpor_matriz`

`transpor_matriz(matriz)`

Troca linhas e colunas de uma matriz.

- **Parâmetros e padrões:** matriz retangular Float64 finita
- **Retorno:** matriz transposta como lista de linhas
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `determinante_matriz`

`determinante_matriz(matriz)`

Calcula o determinante de uma matriz quadrada.

- **Parâmetros e padrões:** matriz quadrada Float64 finita
- **Retorno:** determinante Float64; resultado numérico sujeito a arredondamento
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões, não finito
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib)
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `posto_matriz`

`posto_matriz(matriz, tolerancia_absoluta)`

Calcula posto numérico com tolerância absoluta explícita.

- **Parâmetros e padrões:** matriz Float64 e tolerância absoluta Float64 não negativa
- **Retorno:** posto inteiro, rtol=0
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões, tolerância
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib)
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `decompor_matriz`

`decompor_matriz(matriz, metodo)`

Calcula QR, SVD ou autovalores de matriz simétrica.

- **Parâmetros e padrões:** matriz Float64; qr, svd ou autovalores_simetricos
- **Retorno:** registro Q/R, U/singulares/Vt ou valores/vetores
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões, simetria, método
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib)
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `resolver_sistema`

`resolver_sistema(matriz, vetor)`

Resolve um sistema linear quadrado geral via LU.

- **Parâmetros e padrões:** matriz quadrada Float64, vetor Float64 compatível
- **Retorno:** solucao e residuo_norma via LU
- **Pré-condições, ausentes, erros e limites:** tipos, dimensões, singularidade
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib)
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `ajustar_valores_p`

`ajustar_valores_p(valores_p, metodo, alpha)`

Corrige uma família de valores-p pelo método escolhido.

- **Parâmetros e padrões:** Float64 em [0,1], bonferroni/holm/bh/by, alpha Float64 em (0,1)
- **Retorno:** originais, ajustados, rejeitar na ordem original; metodo, controle, alpha
- **Pré-condições, ausentes, erros e limites:** vazio, valores, método, alpha
- **Efeitos:** Nenhum.
- **Dependência Julia:** MultipleTesting.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `minimizar_polinomio`

`minimizar_polinomio(coeficientes, inferior, superior, tolerancia_relativa, tolerancia_absoluta, max_iteracoes)`

Busca mínimo local de polinômio escalar em intervalo.

- **Parâmetros e padrões:** coeficientes Float64 crescente em grau, limites, rtol, atol, máximo de iterações
- **Retorno:** solucao, valor_objetivo, iteracoes, convergiu, status
- **Pré-condições, ausentes, erros e limites:** tipos, intervalo, tolerâncias, limite, objetivo não finito
- **Efeitos:** Nenhum.
- **Dependência Julia:** Optim.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `selecionar_colunas`

`selecionar_colunas(tabela, nomes)`

Projeta colunas de uma tabela tipada na ordem informada.

- **Parâmetros e padrões:** tabela, nomes únicos existentes
- **Retorno:** tabela na ordem de colunas pedida, linhas preservadas
- **Pré-condições, ausentes, erros e limites:** colunas, duplicação, vazio
- **Efeitos:** Nenhum.
- **Dependência Julia:** tabela ABT
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `renomear_colunas`

`renomear_colunas(tabela, originais, novos)`

Renomeia colunas sem modificar os valores da tabela.

- **Parâmetros e padrões:** tabela, nomes atuais e novos em listas pareadas
- **Retorno:** tabela com esquema renomeado
- **Pré-condições, ausentes, erros e limites:** colunas, nomes, colisão
- **Efeitos:** Nenhum.
- **Dependência Julia:** tabela ABT
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `ordenar_tabela`

`ordenar_tabela(tabela, colunas, direcoes, politica_ausentes)`

Ordena linhas estavelmente por chaves e direções explícitas.

- **Parâmetros e padrões:** tabela, colunas, crescente/decrescente por coluna, erro/primeiro/ultimo para ausentes
- **Retorno:** tabela ordenada estavelmente; materializa linhas
- **Pré-condições, ausentes, erros e limites:** colunas, direções, ausentes
- **Efeitos:** Materializa linhas.
- **Dependência Julia:** Base Julia
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv`.

## `remover_duplicatas`

`remover_duplicatas(tabela, colunas)`

Retém a primeira linha de cada combinação de chaves.

- **Parâmetros e padrões:** tabela, colunas de comparação
- **Retorno:** tabela com primeira ocorrência; missing compara igual
- **Pré-condições, ausentes, erros e limites:** colunas
- **Efeitos:** Materializa linhas.
- **Dependência Julia:** Base Julia
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `juntar_tabelas`, `exportar_csv`.

## `juntar_tabelas`

`juntar_tabelas(esquerda, direita, chaves, modo)`

Relaciona duas tabelas tipadas por chaves explícitas.

- **Parâmetros e padrões:** tabelas, chaves de tipos idênticos, interna/esquerda
- **Retorno:** tabela na ordem esquerda; múltiplas correspondências expandidas
- **Pré-condições, ausentes, erros e limites:** tipos, ausentes nas chaves, colisão de colunas
- **Efeitos:** Materializa linhas.
- **Dependência Julia:** DataFrames.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `exportar_csv`.

## `exportar_csv`

`exportar_csv(tabela, caminho, marcador_ausente)`

Grava uma tabela tipada em CSV com marcador explícito de ausente.

- **Parâmetros e padrões:** tabela, caminho, marcador de ausente não vazio
- **Retorno:** registro arquivo, linhas, marcador_ausente; arquivo CSV
- **Pré-condições, ausentes, erros e limites:** tipos, colisão do marcador com texto, IO
- **Efeitos:** Escreve arquivo.
- **Dependência Julia:** CSV.jl
- **Exemplo executável:** [`docs/examples/cientifico.abt`](../examples/programs.md#cientifico).
- **Operações relacionadas nesta seção:** `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna`, `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema`, `ajustar_valores_p`, `minimizar_polinomio`, `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`.
