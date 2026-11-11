# Arquivos, CSV e tabelas

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `esquema`

`esquema("coluna", "tipo", ...)`

Declara nomes e tipos de colunas explicitamente.

- **Parâmetros e padrões:** Pares nome/tipo; tipos `texto`, `inteiro`, `real`, `booleano`; sem padrão.
- **Retorno:** Registro de esquema.
- **Pré-condições, ausentes, erros e limites:** Rejeita nomes duplicados, pares incompletos e tipo desconhecido; não infere tipos.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `ler_csv`, `coluna`, `linhas_tabela`, `filtrar_tabela`, `transformar_tabela`, `resumir_coluna`.

## `ler_csv`

`ler_csv(caminho, esquema, politica[, delimitador])`

Abre CSV com esquema explícito e linhas iteráveis.

- **Parâmetros e padrões:** Caminho, esquema, política `erro`/`permitir`; delimitador textual de um caractere, padrão `,`.
- **Retorno:** Valor tabela ABT com fonte, colunas, tipos e iterador.
- **Pré-condições, ausentes, erros e limites:** Cabeçalho deve coincidir exatamente; vazio, duplicado, tipo inválido e ausente sob `erro` são erros. Conversão ocorre ao percorrer linhas.
- **Efeitos:** Lê arquivo sob demanda; não materializa todas as linhas inicialmente.
- **Dependência Julia:** CSV.jl e Tables.jl sob demanda.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `coluna`, `linhas_tabela`, `filtrar_tabela`, `transformar_tabela`, `resumir_coluna`.

## `coluna`

`coluna(tabela, nome)`

Materializa uma coluna de tabela.

- **Parâmetros e padrões:** Tabela ABT e nome textual existente; sem padrão.
- **Retorno:** Lista dos valores, inclusive `missing` se permitido.
- **Pré-condições, ausentes, erros e limites:** Coluna inexistente ou CSV inválido gera erro contextual; materializa a coluna.
- **Efeitos:** Lê linhas da fonte.
- **Dependência Julia:** Tabelas ABT/CSV.jl.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `ler_csv`, `linhas_tabela`, `filtrar_tabela`, `transformar_tabela`, `resumir_coluna`.

## `linhas_tabela`

`linhas_tabela(tabela)`

Materializa os registros de tabela.

- **Parâmetros e padrões:** Tabela ABT; sem padrão.
- **Retorno:** Lista de registros.
- **Pré-condições, ausentes, erros e limites:** Falhas de leitura ou conversão da fonte são erros; ausentes seguem o esquema da tabela.
- **Efeitos:** Lê e materializa linhas.
- **Dependência Julia:** Tabelas ABT/CSV.jl.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `ler_csv`, `coluna`, `filtrar_tabela`, `transformar_tabela`, `resumir_coluna`.

## `filtrar_tabela`

`filtrar_tabela(tabela, coluna, operador, valor)`

Produz tabela filtrada sem materialização imediata.

- **Parâmetros e padrões:** Operador textual `==`, `!=`, `>`, `>=`, `<`, `<=`; valor deve ter tipo exato da coluna.
- **Retorno:** Nova tabela ABT iterável.
- **Pré-condições, ausentes, erros e limites:** Coluna desconhecida, tipo incompatível e ausente na coluna filtrada são erros; booleano aceita apenas igualdade/desigualdade.
- **Efeitos:** Lê a fonte quando consumida.
- **Dependência Julia:** Tabelas ABT/CSV.jl.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `ler_csv`, `coluna`, `linhas_tabela`, `transformar_tabela`, `resumir_coluna`.

## `transformar_tabela`

`transformar_tabela(tabela, origem, destino, operador, operando, tipo)`

Cria coluna numérica derivada.

- **Parâmetros e padrões:** Origem numérica, nome novo, operador `+`, `-`, `*`, `/`, operando do tipo da origem, destino `inteiro`/`real`.
- **Retorno:** Nova tabela ABT iterável com coluna adicional.
- **Pré-condições, ausentes, erros e limites:** Ausente, overflow, divisão incompatível ou resultado diferente do tipo declarado são erros; não converte silenciosamente.
- **Efeitos:** Lê a fonte quando consumida.
- **Dependência Julia:** Tabelas ABT/CSV.jl.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `ler_csv`, `coluna`, `linhas_tabela`, `filtrar_tabela`, `resumir_coluna`.

## `resumir_coluna`

`resumir_coluna(tabela, coluna)`

Resume uma coluna numérica.

- **Parâmetros e padrões:** Tabela e coluna `inteiro`/`real`; sem padrão.
- **Retorno:** Registro `quantidade`, `soma`, `media`, `minimo`, `maximo`.
- **Pré-condições, ausentes, erros e limites:** Tabela vazia, ausente, overflow e total não finito são erros.
- **Efeitos:** Percorre a fonte.
- **Dependência Julia:** Tabelas ABT/CSV.jl.
- **Exemplo executável:** [`docs/examples/tabelas.abt`](../examples/programs.md#tabelas).
- **Operações relacionadas nesta seção:** `esquema`, `ler_csv`, `coluna`, `linhas_tabela`, `filtrar_tabela`, `transformar_tabela`.
