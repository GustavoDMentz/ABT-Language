# Dados, JSON e álgebra

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `resumir_grupos`

`resumir_grupos(tabela, grupo, valor, politica)`

Resume valores por grupo.

- **Parâmetros e padrões:** Grupo textual, valor numérico, política `erro`/`ignorar_linha`.
- **Retorno:** Registro com grupos e contagem de linhas.
- **Pré-condições, ausentes, erros e limites:** Coluna/tipo/ausente inválido ou soma inválida são erros; ordem segue primeira ocorrência.
- **Efeitos:** Percorre a fonte.
- **Dependência Julia:** CSV.jl via tabela ABT.
- **Exemplo executável:** [`docs/examples/dados.abt`](../examples/programs.md#dados).
- **Operações relacionadas nesta seção:** `contar_categorias`, `agrupar_dados`, `testar_grupos`, `categorias`, `codificar_json`, `resolver_sistema_spd`.

## `contar_categorias`

`contar_categorias(tabela, coluna, politica)`

Calcula frequências e proporções categóricas.

- **Parâmetros e padrões:** Tabela, coluna textual e política `erro`/`ignorar_linha`.
- **Retorno:** Registro estruturado de categorias.
- **Pré-condições, ausentes, erros e limites:** Rejeita coluna, tipo ou política inválidos; ausentes tratados pela política informada.
- **Efeitos:** Percorre a fonte.
- **Dependência Julia:** StatsBase.jl sob demanda.
- **Exemplo executável:** [`docs/examples/dados.abt`](../examples/programs.md#dados).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `agrupar_dados`, `testar_grupos`, `categorias`, `codificar_json`, `resolver_sistema_spd`.

## `agrupar_dados`

`agrupar_dados(tabela, grupo, valor, politica)`

Agrupa valores numéricos para análises posteriores.

- **Parâmetros e padrões:** Grupo textual, valor numérico, política `erro`/`ignorar_linha`.
- **Retorno:** Registro `grupos`, `linhas_lidas`, `linhas_ignoradas`.
- **Pré-condições, ausentes, erros e limites:** Tipo ou coluna inválida, ausente sob `erro` e valor não finito são erros; grupos preservam ordem de aparição.
- **Efeitos:** Percorre e materializa grupos.
- **Dependência Julia:** DataFrames.jl sob demanda.
- **Exemplo executável:** [`docs/examples/grupos.abt`](../examples/programs.md#grupos).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `contar_categorias`, `testar_grupos`, `categorias`, `codificar_json`, `resolver_sistema_spd`.

## `testar_grupos`

`testar_grupos(grupos, nome_a, nome_b, metodo)`

Compara dois grupos com teste t bilateral.

- **Parâmetros e padrões:** Resultado de `agrupar_dados`; nomes distintos; método `welch`/`student`.
- **Retorno:** Registro com médias, n, estatística e valor-p.
- **Pré-condições, ausentes, erros e limites:** Ambos os grupos devem existir e ter ≥ 2 valores finitos; não escolhe método automaticamente.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/grupos.abt`](../examples/programs.md#grupos).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `categorias`, `codificar_json`, `resolver_sistema_spd`.

## `categorias`

`categorias(tabela, coluna, niveis, politica)`

Conta níveis categóricos explícitos.

- **Parâmetros e padrões:** Coluna textual; lista não vazia de níveis únicos; política `erro`/`ignorar_linha`.
- **Retorno:** Registro com contagens na ordem dos níveis e linhas ignoradas.
- **Pré-condições, ausentes, erros e limites:** Valores fora dos níveis, ausentes sob `erro` e níveis repetidos são erros.
- **Efeitos:** Percorre a fonte.
- **Dependência Julia:** CategoricalArrays.jl sob demanda.
- **Exemplo executável:** [`docs/examples/dados.abt`](../examples/programs.md#dados).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `testar_grupos`, `codificar_json`, `resolver_sistema_spd`.

## `codificar_json`

`codificar_json(valor, politica)`

Serializa valor ABT em JSON textual.

- **Parâmetros e padrões:** Valor estruturado e política `erro`/`nulo` para ausentes.
- **Retorno:** Texto JSON.
- **Pré-condições, ausentes, erros e limites:** Ciclos, tipos não suportados, números não finitos e ausentes sob política de erro são rejeitados.
- **Efeitos:** Nenhum.
- **Dependência Julia:** JSON.jl sob demanda.
- **Exemplo executável:** [`docs/examples/dados.abt`](../examples/programs.md#dados).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `testar_grupos`, `categorias`, `resolver_sistema_spd`.

## `resolver_sistema_spd`

`resolver_sistema_spd(matriz, vetor)`

Resolve sistema linear simétrico definido positivo.

- **Parâmetros e padrões:** Lista de listas `Float64` quadrada e vetor `Float64` compatível.
- **Retorno:** Registro com solução e norma do resíduo.
- **Pré-condições, ausentes, erros e limites:** Forma, tipo, finitude, simetria ou positividade inválidas são erros; sem coerção implícita.
- **Efeitos:** Nenhum.
- **Dependência Julia:** LinearAlgebra (stdlib).
- **Exemplo executável:** [`docs/examples/dados.abt`](../examples/programs.md#dados).
- **Operações relacionadas nesta seção:** `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `testar_grupos`, `categorias`, `codificar_json`.
