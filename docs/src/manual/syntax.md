# Sintaxe, valores e nomes

Um arquivo ABT contém instruções em sequência. Quebras de linha normalmente são apenas espaço; `;` separa instruções quando necessário. Blocos de `se`, `para cada` e `função` usam `{ ... }`. A exceção são [pipelines indentados](collections.md), cujas linhas têm significado próprio. Comentários começam em `#` e seguem até o fim da linha.

```abt
# Valores literais
quantidade = 3
taxa = 2.5
rotulo = "ensaio"
ativo = verdadeiro
itens = [1, 2, 3]
mostrar registro("nome", rotulo, "n", quantidade)
```

Inteiros são `Int64`; números com ponto são `Float64`; literais booleanos são `verdadeiro`/`falso` (também `true`/`false`); texto usa aspas duplas; listas usam `[...]`. Não há literal `ausente` no parser. Valores ausentes podem surgir de CSV com política explícita ou de bibliotecas externas. `registro` cria um valor estruturado; `esquema` declara tipos de colunas, não um tipo geral de variável.

Identificadores aceitam letras Unicode e dígitos após o primeiro caractere. Nomes que começam com `__abt_` são reservados. As palavras-chave listadas na [gramática](../reference/grammar.md) não devem ser usadas como nomes comuns, salvo os nomes contextuais de agregação aceitos pelo parser. Atribuição usa `nome = expressão`; não há declaração de tipo nem coerção implícita geral.

```abt
valor_inicial = 10
valor_inicial = valor_inicial + 1
mostrar valor_inicial
```

Saída: `11`. Um nome ainda não definido é erro; a validação do IR detecta leituras definitivamente inválidas. Conversões explícitas podem ser feitas por funções Julia permitidas, como `Julia.Base.Float64`, após `usar Julia.Base`; veja [interoperação](interop.md).
