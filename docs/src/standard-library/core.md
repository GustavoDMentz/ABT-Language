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
- **Operações relacionadas nesta seção:** `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `descrever`

`descrever(lista)`

Resume números reais finitos.

- **Parâmetros e padrões:** Lista com ao menos dois `Int64` ou `Float64`; sem padrão.
- **Retorno:** Registro `quantidade`, `soma`, `media`, `mediana`, `desvio_padrao`, `minimo`, `maximo`.
- **Pré-condições, ausentes, erros e limites:** Rejeita ausentes, valores não finitos, soma com overflow e lista curta.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Statistics (stdlib).
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `contar`

`contar(lista)`

Conta elementos de uma lista.

- **Parâmetros e padrões:** Uma lista ABT, inclusive vazia; sem padrão.
- **Retorno:** Inteiro com a quantidade de elementos.
- **Pré-condições, ausentes, erros e limites:** Conta valores ausentes como elementos; rejeita texto, registro, tabela e qualquer valor que não seja lista; não percorre tabelas lazy.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `falhar`

`falhar(mensagem)`

Interrompe o programa com erro explícito.

- **Parâmetros e padrões:** `mensagem`: texto; sem padrão.
- **Retorno:** Não retorna normalmente.
- **Pré-condições, ausentes, erros e limites:** Tipo não textual gera erro; a mensagem informada aparece no diagnóstico.
- **Efeitos:** Lança erro e encerra a execução corrente.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/falhar.abt`](../examples/programs.md#falhar).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `ambiente`

`ambiente(nome, fallback)`

Lê uma variável de ambiente.

- **Parâmetros e padrões:** Nome e valor alternativo: textos; sem padrão.
- **Retorno:** Texto do ambiente ou `fallback` quando a variável não existe.
- **Pré-condições, ausentes, erros e limites:** Nome vazio e fallback não textual são erros; não distingue variável vazia de ausente por inferência.
- **Efeitos:** Lê o ambiente do processo.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `ler_texto`

`ler_texto(caminho)`

Lê um arquivo UTF-8 completo.

- **Parâmetros e padrões:** Caminho textual não vazio; sem padrão.
- **Retorno:** Texto integral do arquivo.
- **Pré-condições, ausentes, erros e limites:** Arquivo ausente ou inválido gera erro com caminho e causa; não introduz valor ausente.
- **Efeitos:** Lê arquivo; materializa o conteúdo.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `linhas_texto`

`linhas_texto(texto)`

Separa texto em linhas.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Lista de textos.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; não interpreta CSV.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `aparar`

`aparar(texto)`

Remove espaços nas bordas do texto.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Texto aparado.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `maiusculas`

`maiusculas(texto)`

Converte texto para maiúsculas segundo Julia.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Texto convertido.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; Unicode segue `uppercase` da Julia.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `inicia_com`, `comprimento_texto`, `contar_caractere`.

## `inicia_com`

`inicia_com(texto, prefixo)`

Verifica prefixo textual.

- **Parâmetros e padrões:** Dois textos; sem padrão.
- **Retorno:** Booleano.
- **Pré-condições, ausentes, erros e limites:** Entradas não textuais são erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `comprimento_texto`, `contar_caractere`.

## `comprimento_texto`

`comprimento_texto(texto)`

Conta caracteres Unicode do texto.

- **Parâmetros e padrões:** Um texto; sem padrão.
- **Retorno:** Inteiro.
- **Pré-condições, ausentes, erros e limites:** Entrada não textual é erro; não conta bytes.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `contar_caractere`.

## `contar_caractere`

`contar_caractere(texto, caractere)`

Conta ocorrências de um caractere.

- **Parâmetros e padrões:** Dois textos; segundo argumento deve ter comprimento um.
- **Retorno:** Inteiro.
- **Pré-condições, ausentes, erros e limites:** Caractere vazio ou com mais de uma unidade de caractere é erro.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Base Julia.
- **Exemplo executável:** [`docs/examples/nucleo.abt`](../examples/programs.md#nucleo).
- **Operações relacionadas nesta seção:** `registro`, `descrever`, `contar`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`.
