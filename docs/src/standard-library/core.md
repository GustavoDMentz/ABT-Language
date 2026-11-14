# Núcleo, texto e ambiente

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `registro`

`registro("campo", valor, ...)`

Cria um registro reutilizável com campos nomeados.

- **Parâmetros e padrões:** Um ou mais pares nome textual/valor; nomes válidos, distintos e sem prefixo `_`; sem valores padrão.
- **Retorno:** Registro com campos na ordem informada.
- **Pré-condições, ausentes, erros e limites:** Aridade par, nomes válidos e sem duplicação; valores ausentes podem ser armazenados; erros de nome e aridade.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `descrever`

`descrever(lista)`

Resume números reais finitos.

- **Parâmetros e padrões:** Lista com ao menos dois `Int64` ou `Float64`; sem padrão.
- **Retorno:** Registro `quantidade`, `soma`, `media`, `mediana`, `desvio_padrao`, `minimo`, `maximo`.
- **Pré-condições, ausentes, erros e limites:** Rejeita ausentes, valores não finitos, soma com overflow e lista curta.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Statistics (stdlib).
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `contar`

`contar(lista)`

Conta elementos de uma lista.

- **Parâmetros e padrões:** Uma lista ABT, inclusive vazia; sem padrão.
- **Retorno:** Inteiro com a quantidade de elementos.
- **Pré-condições, ausentes, erros e limites:** Conta valores ausentes como elementos; rejeita texto, registro, tabela e qualquer valor que não seja lista; não percorre tabelas lazy.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `minimo`

`minimo(lista)`

Obtém o menor valor de uma lista numérica.

- **Parâmetros e padrões:** Lista não vazia de `Int64` ou `Float64` finitos; sem padrão.
- **Retorno:** O próprio elemento, com o seu tipo original; em empate vale a primeira ocorrência.
- **Pré-condições, ausentes, erros e limites:** Rejeita lista vazia, texto, valores ausentes, não finitos e qualquer valor que não seja lista.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `maximo`

`maximo(lista)`

Obtém o maior valor de uma lista numérica.

- **Parâmetros e padrões:** Lista não vazia de `Int64` ou `Float64` finitos; sem padrão.
- **Retorno:** O próprio elemento, com o seu tipo original; em empate vale a primeira ocorrência.
- **Pré-condições, ausentes, erros e limites:** Mesmas pré-condições de `minimo`.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `ordenar`

`ordenar(lista[, direcao])`

Ordena uma lista sem alterar a original.

- **Parâmetros e padrões:** Lista só de números finitos ou só de textos; direção `crescente` (padrão) ou `decrescente`.
- **Retorno:** Nova lista; a ordenação é estável e os elementos mantêm seu tipo.
- **Pré-condições, ausentes, erros e limites:** Rejeita listas mistas de texto e número, ausentes, não finitos, direção desconhecida e valores que não sejam lista; lista vazia retorna lista vazia.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `sem_duplicatas`

`sem_duplicatas(lista)`

Remove elementos repetidos preservando a primeira ocorrência.

- **Parâmetros e padrões:** Uma lista ABT; sem padrão.
- **Retorno:** Nova lista na ordem original; dois elementos são iguais segundo `isequal` da Julia (`1` e `1.0` são iguais; `0.0` e `-0.0` não).
- **Pré-condições, ausentes, erros e limites:** Rejeita qualquer valor que não seja lista; lista vazia retorna lista vazia.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `para_inteiro`

`para_inteiro(valor)`

Converte explicitamente para `Int64`, sem arredondar.

- **Parâmetros e padrões:** Inteiro, real com valor inteiro representável ou texto de dígitos com sinal opcional, sem espaços; sem padrão.
- **Retorno:** `Int64`.
- **Pré-condições, ausentes, erros e limites:** Rejeita real com fração, não finito ou fora da faixa, texto vazio, com espaços, decimal ou fora da faixa, e booleano.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `para_real`

`para_real(valor)`

Converte explicitamente para `Float64`, sem perda silenciosa.

- **Parâmetros e padrões:** Real, inteiro exatamente representável ou texto decimal/científico sem espaços; sem padrão.
- **Retorno:** `Float64`.
- **Pré-condições, ausentes, erros e limites:** Rejeita inteiro que perderia precisão, texto inválido ou fora da faixa finita (`1e999`) e booleano.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `para_texto`

`para_texto(valor)`

Converte texto, número ou booleano para texto.

- **Parâmetros e padrões:** Texto, `Int64`, `Float64` ou booleano; sem padrão.
- **Retorno:** Texto na mesma representação usada por `mostrar` para valores escalares.
- **Pré-condições, ausentes, erros e limites:** Rejeita listas, registros, tabelas e demais valores.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `falhar`

`falhar(mensagem)`

Interrompe o programa com erro explícito.

- **Parâmetros e padrões:** `mensagem`: texto; sem padrão.
- **Retorno:** Não retorna normalmente.
- **Pré-condições, ausentes, erros e limites:** Tipo não textual gera erro; a mensagem informada aparece no diagnóstico.
- **Efeitos:** Lança erro e encerra a execução corrente.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/falhar.abt`](../examples/programs.md#falhar).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `ambiente`

`ambiente(nome, fallback)`

Lê uma variável de ambiente.

- **Parâmetros e padrões:** Nome e valor alternativo: textos; sem padrão.
- **Retorno:** Texto do ambiente ou `fallback` quando a variável não existe.
- **Pré-condições, ausentes, erros e limites:** Nome vazio e fallback não textual são erros; não distingue variável vazia de ausente por inferência.
- **Efeitos:** Lê o ambiente do processo.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `ler_texto`

`ler_texto(caminho)`

Lê um arquivo UTF-8 completo.

- **Parâmetros e padrões:** Caminho textual não vazio; sem padrão.
- **Retorno:** Texto integral do arquivo.
- **Pré-condições, ausentes, erros e limites:** Arquivo ausente ou inválido gera erro com caminho e causa; não introduz valor ausente.
- **Efeitos:** Lê arquivo; materializa o conteúdo.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `linhas_texto`

`linhas_texto(texto)`

Separa texto em linhas.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Lista de textos.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; não interpreta CSV.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `aparar`

`aparar(texto)`

Remove espaços nas bordas do texto.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Texto aparado.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `maiusculas`

`maiusculas(texto)`

Converte texto para maiúsculas segundo Julia.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Texto convertido.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; Unicode segue `uppercase` da Julia.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `inicia_com`

`inicia_com(texto, prefixo)`

Verifica prefixo textual.

- **Parâmetros e padrões:** Dois textos; sem padrão.
- **Retorno:** Booleano.
- **Pré-condições, ausentes, erros e limites:** Entradas não textuais são erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `comprimento_texto`, `contar_caractere`.

## `comprimento_texto`

`comprimento_texto(texto)`

Conta caracteres Unicode do texto.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Inteiro.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; não conta bytes.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `contar_caractere`.

## `contar_caractere`

`contar_caractere(texto, caractere)`

Conta ocorrências de um caractere.

- **Parâmetros e padrões:** Dois textos; segundo argumento deve ter comprimento um.
- **Retorno:** Inteiro.
- **Pré-condições, ausentes, erros e limites:** Caractere vazio ou com mais de uma unidade de caractere é erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `minimo`, `maximo`, `ordenar`, `sem_duplicatas`, `para_inteiro`, `para_real`, `para_texto`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`.
