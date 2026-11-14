# Especificação formal da linguagem ABT 0.15.0

**Objeto:** a linguagem **ABT** exatamente como implementada na versão **0.15.0** (repositório `GustavoDMentz/ABT-Language`, commit `0b1d9b8`, "Merge pull request #11"), executada com Julia 1.13.3.
**Natureza do documento:** engenharia reversa e formalização *descritiva*. Nada aqui altera, estende ou "corrige" a ABT. Onde a implementação e a documentação do projeto divergem, a divergência é registrada (Apêndice A) e vale o comportamento **medido** na implementação.
**Como ler as evidências:** toda afirmação técnica traz sua origem entre colchetes.

| Marca | Significa | Exemplo |
|---|---|---|
| `[C ABT.jl:149]` | código-fonte do repositório (arquivo e linha, no commit `0b1d9b8`) | `[C ABT.jl:149]` |
| `[D grammar.md]` | documentação oficial do projeto (`docs/src/...`) | `[D expressions.md]` |
| `[T keywords]` | teste automatizado existente no repositório (`tests/...`) | `[T test_abstraction_keywords.jl]` |
| `[E L01]` | exemplo deste documento, **executado na ABT real** pelo verificador (§C.1) | `[E O06]` |

Sumário: 1 Introdução · 2 Regras léxicas · 3 Variáveis, identificadores e tipos numéricos · 4 Operadores e expressões · 5 Decisão e repetição · 6 Símbolos especiais · 7 Gramática EBNF · 8 Semântica · 9 Programas completos · 10 Matriz de conformidade · 11 Limitações e conclusões · Apêndices A (divergências), B (índice de evidências), C (reprodução e método).

---

## 1. Introdução e objetivos da ABT

### 1.1 O que é a ABT

ABT é uma linguagem de programação **experimental**, de sintaxe em português (com sinônimos em inglês), voltada a "programas pequenos e operações de dados de maneira declarativa", cujos cálculos são executados por Julia `[D overview.md]`. O projeto declara que a ABT "ainda é experimental" e "não é um sandbox" `[D overview.md]`. Para a atividade de Linguagens Formais, o que interessa é o **núcleo da linguagem**: variáveis, números, operadores, comando condicional e comando de repetição. A biblioteca científica (bioinformática, estatística, tabelas), as pontes com Julia/Python e as funções de coleção estão fora do escopo normativo deste documento; aparecem apenas onde afetam a gramática (§7).

### 1.2 Estrutura de processamento (o que realmente acontece ao rodar um programa)

`abt run programa.abt` executa, nesta ordem `[C CLIMain.jl:34-39]`, `[C ABT.jl:623-631]`:

```
texto ──tokenize──▶ tokens ──expand_pipelines──▶ tokens ──parse_program──▶ AST
      (§2)                  (pré-processamento,                (§7)
                             §7.4)
AST ──lower_ir──▶ IR ──validate_ir──▶ (análise estática, §8.2) ──execute──▶ saída (§8.3)
```

* A **análise estática** (`validate_ir`) roda **antes** de qualquer execução; por isso um erro estático impede que *qualquer* saída seja produzida `[C ABT.jl:629]`, `[E M01]`.
* O **interpretador** é o caminho usado por `abt run`. O projeto também possui geradores de código Julia, que compartilham a mesma representação intermediária validada `[D semantics.md]`; este documento descreve e mede o interpretador (`abt run`) e **não** reavalia os geradores.
* `abt check` executa tokenização, análise sintática e validação, sem executar `[C CLIMain.jl:36-37]`, `[E M08]`.

### 1.3 Objetivos deste documento

1. Registrar as regras léxicas, sintáticas e semânticas **reais** do núcleo da ABT 0.15.0.
2. Demonstrar, por execução, o atendimento a cada requisito da atividade (§10).
3. Tornar a especificação *verificável*: o professor pode executar cada exemplo diretamente com a CLI original (`abt run`), sem instalar nada além da própria ABT (Apêndice C).

### 1.4 Convenções de notação

A gramática usa EBNF no estilo ISO 14977, em texto simples: `=` define, `,` concatena, `|` alterna, `[ ]` é opcional, `{ }` repete zero ou mais vezes, `( )` agrupa, aspas delimitam terminais, `(* … *)` é comentário. Letras maiúsculas (`NUMBER`, `IDENT`) são **tokens** definidos na §2.

---

## 2. Definição formal das regras léxicas

### 2.1 Visão geral

A análise léxica é feita por `tokenize` `[C ABT.jl:132-173]`: um laço que percorre o texto e, em cada posição, aplica **a primeira** regra que casa, nesta ordem de prioridade:

| Prioridade | Regra | Código |
|---|---|---|
| 1 | quebra de linha `LF`: incrementa a linha e zera a coluna | `[C ABT.jl:138-140]` |
| 2 | espaço em branco: espaço, `TAB`, `CR` (descartados) | `[C ABT.jl:141-143]` |
| 3 | comentário: `#` até o fim da linha (descartado) | `[C ABT.jl:144-147]` |
| 4 | **NUMBER**: `^(?:\d+(?:\.\d+)?)` | `[C ABT.jl:149-153]` |
| 5 | **STRING**: `^"(?:\\.\|[^"\\])*"` (sem fechar aspas: erro) | `[C ABT.jl:154-157]` |
| 6 | **IDENT / palavra-chave**: `^[^\W\d]\w*` | `[C ABT.jl:159-161]` |
| 7 | **símbolo**: `^(?:==\|!=\|>=\|<=\|[=+*/^><\-{},;\[\]().])` | `[C ABT.jl:163-166]` |
| — | nenhuma regra casou: erro `Unexpected character` | `[C ABT.jl:164]` |

Ao final é emitido o token `EOF`; cada token guarda **linha e coluna** (base 1) do primeiro caractere `[C ABT.jl:120-125, 168-171]`. Em seguida os tokens passam por `expand_pipelines` (§7.4).

Duas consequências importantes da **ordem** acima:

* NUMBER tem prioridade sobre IDENT: um texto como `2y` vira **dois tokens** (`NUMBER 2`, `IDENT y`). Não existe erro léxico "identificador começando com dígito" (§3.2).
* Dentro de cada regra a expressão regular é gananciosa (casa o lexema mais longo), e na regra de símbolos a alternativa de dois caracteres vem antes das de um (`<=` é um token, não `<` seguido de `=`).

### 2.2 Gramática léxica em EBNF

```ebnf
(* Texto de entrada: caracteres Unicode. Regras na ordem de prioridade da tabela §2.1. *)
espaco        = " " | TAB | CR ;
nova_linha    = LF ;
comentario    = "#" , { qualquer_caractere_exceto_LF } ;

NUMBER        = digito , { digito } , [ "." , digito , { digito } ] ;
digito        = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;   (* ver §2.5 sobre \d *)

STRING        = '"' , { caractere_de_texto | "\" , qualquer_caractere } , '"' ;
caractere_de_texto = qualquer_caractere_exceto_aspas_e_barra_invertida ;

IDENT_LEXEMA  = inicio_de_nome , { continuacao_de_nome } ;                    (* ver §3.1 *)
inicio_de_nome      = letra | "_" ;
continuacao_de_nome = letra | digito | "_" ;
(* letra: letra Unicode (ex.: a, Z, ç, ã, Δ). O lexema vira palavra-chave se, em minúsculas, estiver na tabela §2.3. *)

SIMBOLO       = "==" | "!=" | ">=" | "<=" | "=" | "+" | "*" | "/" | "^" | ">" | "<" | "-"
              | "{" | "}" | "," | ";" | "[" | "]" | "(" | ")" | "." ;
```

Os 21 símbolos produzem tokens cujo "tipo" é o próprio lexema `[C ABT.jl:165]`. Qualquer outro caractere (por exemplo `% ! & | ' : ? $ @ ~ \`) **não pertence ao alfabeto** da linguagem: erro `Unexpected character '…' at L:C`, classificado como `E000` `[C ABT.jl:164]`, `[E S01]`–`[E S08]`.

### 2.3 Palavras reservadas (46 lexemas, 22 tipos de token)

O dicionário `KEYWORDS` `[C ABT.jl:108-118]` associa cada lexema (já em minúsculas) a um tipo de token. A comparação usa `lowercase(lexeme)` `[C ABT.jl:161]`; logo **as palavras-chave não distinguem maiúsculas de minúsculas** (`SE`, `Se` e `se` são a mesma palavra) `[T test_abstraction_keywords.jl]`, `[E L01]`. A documentação do projeto não menciona isso (Apêndice A, DV-01).

| Tipo de token | Lexemas (português / inglês) | Papel |
|---|---|---|
| `SHOW` | `mostrar`, `show` | instrução de saída |
| `IF` | `se`, `if` | condicional |
| `ELSE` | `senao`, `senão`, `else` | alternativa do condicional |
| `FOR`, `EACH`, `IN` | `para`, `for` · `cada`, `each` · `em`, `in` | repetição `para cada … em …` |
| `FUNCTION` | `função`, `funcao`, `function` | declaração de função |
| `RETURN` | `retornar`, `return` | retorno de função |
| `USE` | `usar` | importação (fora do núcleo) |
| `TRUE`, `FALSE` | `verdadeiro`, `true` · `falso`, `false` | literais lógicos |
| `AND`, `OR` | `e`, `and` · `ou`, `or` | conectivos lógicos |
| `IS`, `ABOVE`, `BELOW`, `THAN` | `é`, `is` · `maior`, `above` · `menor`, `below` · `que`, `than` | forma verbal de comparação (§4.3) |
| `SUM`, `AVG`, `OF`, `WHERE` | `soma`, `sum` · `media`, `média`, `average` · `de`, `of` · `onde`, `where` | agregações e acesso `campo de registro` |
| `VALUE` | `valor`, `value` | elemento corrente em operações de lista |

Palavras **contextuais** (continuam sendo `IDENT`; só têm função especial em certas posições): `filtrar`, `transformar`, `limitar`, `com`, `a` `[C ABT.jl:397-407]`. Os tokens `SUM` e `AVG` (`soma`, `sum`, `media`, `média`, `average`) são aceitos também como **nomes** de variável/função `[C ABT.jl:247-254]`, `[T runtests.jl:137-144]`, `[E L13]`.

### 2.4 Números

```
NUMBER = dígito+ [ "." dígito+ ]
```

* **Inteiro:** um ou mais dígitos; convertido com `Int64` `[C ABT.jl:414]`. Zeros à esquerda são aceitos (`007` vale 7) `[E L14]`.
* **Fracionário:** dígitos, ponto, dígitos; convertido para `Float64` `[C ABT.jl:414]`. **Os dois lados do ponto são obrigatórios.**
* **Sem sinal no literal:** `-5` é o operador unário `-` aplicado a `5` `[C ABT.jl:362-367]`, `[E L23]`. Consequência: o menor `Int64` não pode ser escrito como literal (`[E N05]`).
* **Não há** notação científica, hexadecimal ou separador de milhar: `1e3` é o literal `1` seguido do identificador `e3`; `1_000` e `0x1F` dão o mesmo tipo de falha (`[E L18]`, `[E L19]`, `[E L20]`).
* `5.` é `NUMBER 5` seguido do símbolo `.`; `.5` começa pelo símbolo `.`; `1.2.3` é `NUMBER 1.2` seguido de `.` (`[E L15]`, `[E L16]`, `[E L17]`). Em todos os casos o **analisador sintático** (não o léxico) rejeita a sequência (`E010`).
* **Limite:** um literal inteiro acima de 9 223 372 036 854 775 807 faz `Base.parse(Int64, …)` falhar com `OverflowError`, reportado como `E000` `[E L21]`.

### 2.5 Observação sobre a classe `\d` (comportamento medido)

O padrão de NUMBER usa `\d`, que na implementação (expressões regulares com suporte Unicode do Julia) também reconhece dígitos decimais de outros alfabetos. O léxico então produz um `NUMBER`, mas a conversão para `Int64` rejeita o dígito: o programa `mostrar ٣` (dígito arábico-índico) falha com `E000` `[E L22]`. É um comportamento de borda, não documentado pelo projeto.

### 2.6 Textos e comentários

* Texto: `"…"`, com escapes processados por `Base.unescape_string` `[C ABT.jl:415-416]`; aspas não fechadas: `Unterminated string at L:C` (`E000`) `[C ABT.jl:155-156]`, `[E L26]`. No `mostrar`, um texto de nível superior sai sem aspas; dentro de uma lista, com aspas `[C StdlibRender.jl:21-24]`, `[E L25]`.
* Comentário: `#` até o fim da linha `[C ABT.jl:144-147]`, `[E L24]`.

### 2.7 Erros léxicos e seu diagnóstico

A ABT **não possui categoria própria** para erros léxicos: o catálogo tem só quatro códigos (`E000`, `E010`, `E021`, `E052`) e a classificação é feita por trechos da mensagem de erro `[C ABT.jl:1593-1610]`. Erros de caractere inválido, texto sem fechar e literal fora de faixa são `E000`; as mensagens da forma `Expected …`/`Unexpected token …` são `E010` (sintaxe). Por isso `2y` (§3.2) aparece como `E010` e não como erro léxico.

---

## 3. Variáveis, identificadores e tipos numéricos

### 3.1 Identificadores

**Regra (implementada):** um nome é um lexema que casa `^[^\W\d]\w*` `[C ABT.jl:159]` e **não** é palavra reservada (§2.3), exceto as contextuais de §2.3. Em português: o primeiro caractere é **letra Unicode ou sublinhado** (nunca dígito); os seguintes são letras, dígitos ou sublinhados, em qualquer ordem e quantidade; **sem espaços e sem outros caracteres especiais**. Maiúsculas e minúsculas são distintas em nomes (`Total` ≠ `total`) `[E L02]`.

| Texto | Válido? | Por quê (medido) |
|---|---|---|
| `x1`, `a1b2`, `r2d2` | sim | dígitos no meio e no fim `[E L02]` |
| `Total` e `total` | sim, **distintos** | nomes diferenciam caixa `[E L02]` |
| `ação`, `preço`, `café`, `Δ` | sim | letras Unicode `[E L03]`, `[T test_differential_1000.jl: caso unicode_names]` |
| `a_b`, `_a` | sim | `_` é caractere de palavra `[E L03]` |
| `1a`, `2y` | **não** | começa com dígito (§3.2) `[E L04]`, `[E L05]` |
| `a b` | **não** | espaço separa dois tokens `[E L06]` |
| `x$` | **não** | `$` não pertence ao alfabeto (`E000`) `[E L07]` |
| `x-y` | **não** | `-` é operador `[E L08]` |
| `__abt_x` | **não** | prefixo `__abt_` é reservado `[C ABT.jl:251]`, `[E L09]` |
| `valor`, `maior`, `de`, `se`, … | **não** | palavras reservadas `[E L10]`, `[E L11]`, `[E L12]` |
| `soma`, `media`, `com`, `filtrar` | sim | contextuais `[E L13]` |
| `Julia`, `Python` | **não** como variável | namespaces reservados `[C ABT.jl:1117]`, `[E V07]` |

Observação: a documentação diz que o nome "começa com letra Unicode" `[D grammar.md]`, `[D syntax.md]`; a implementação também aceita sublinhado inicial (Apêndice A, DV-03).

```abt ok L02
x1 = 1
a1b2 = 2
r2d2 = 3
mostrar x1 + a1b2 + r2d2
Total = 10
total = 20
mostrar Total
mostrar total
```
```saida
6
10
20
```

```abt ok L03
ação = 4
preço = 5
mostrar ação + preço
a_b = 1
_a = 2
mostrar a_b + _a
```
```saida
9
3
```

### 3.2 Por que um identificador não pode começar com dígito (mecanismo real)

Não há uma regra léxica dedicada. Como NUMBER tem prioridade sobre IDENT (§2.1), o texto `2y` é dividido em `NUMBER 2` e `IDENT y`; é o analisador sintático que falha, e a mensagem é **genérica** (e, no caso de `2y` no fim de uma atribuição, aponta o fim do arquivo):

```abt E010 L04
1a = 5
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "1" at 1:1.
```

```abt E010 L05
x = 2y
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "" at 2:1.
```

```abt E010 L06
a b = 1
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "b" at 1:3.
```

```abt E000 L07
x$ = 1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '$' at 1:2
```

```abt E010 L08
x-y = 1
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "-" at 1:2.
```

```abt E000 L09
__abt_x = 1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Reserved ABT internal identifier: __abt_x
```

Palavras reservadas como nomes:

```abt E010 L10
valor = 3
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "valor" at 1:1.
```

```abt E010 L11
maior = 1
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "maior" at 1:1.
```

```abt E010 L12
de = 1
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "de" at 1:1.
```

```abt ok L13
soma = 3
media = 2
com = 1
filtrar = 4
mostrar soma + media + com + filtrar
```
```saida
10
```

### 3.3 Criação e vida das variáveis

* **Criação:** por atribuição, `nome = expressão`, sem declaração e sem tipo declarado `[C ABT.jl:312-313]`, `[D syntax.md]`. Uma variável nasce com valor.
* **Tipagem dinâmica:** a mesma variável pode receber valores de tipos diferentes ao longo do programa `[C ABT.jl:585]` (o interpretador só faz `env[nome] = valor`); a análise estática acompanha o tipo conhecido a cada atribuição `[C ABT.jl:1118]` `[E V02]`.
* **Ordem:** o lado direito é avaliado antes de o nome existir; por isso `x = x + 1` com `x` não definida é erro `E021` `[E V04]`.
* **Ambiente único:** o interpretador usa um único dicionário de variáveis para o nível superior; `se` e `para cada` **não** criam ambiente novo `[C ABT.jl:608-616]`. O que impede o uso indevido de nomes fora do lugar é a **análise de atribuição definida** da validação (§8.2), não um escopo de bloco.
* **Funções** têm ambiente próprio e **não capturam** variáveis do nível superior `[C ABT.jl:499-501]`, `[C ABT.jl:1121-1141]`, `[T test_static_096.jl]`, `[E V05]`.
* **Nomes da biblioteca** (por exemplo `contar`) podem ser reatribuídos como variáveis comuns `[E V08]`. Nomes de **funções declaradas** não podem ser reatribuídos nem usados como variável de laço `[C ABT.jl:1116, 1155]`, `[E M05]`, `[E C24]`.

```abt ok V01
x = 1
mostrar x
x = x + 1
mostrar x
y = x
x = 5
mostrar y
```
```saida
1
2
2
```

```abt ok V02
x = 1
x = "texto"
mostrar x
x = 1.5
x = 2
mostrar x
```
```saida
texto
2
```

```abt E021 V03
mostrar y
```
```erro
Erro ABT[E021] — variável não definida

A variável 'y' não foi definida.
```

```abt E021 V04
x = x + 1
```
```erro
Erro ABT[E021] — variável não definida

A variável 'x' não foi definida.
```

```abt E021 V05
x = 3
função f() { retornar x }
mostrar f()
```
```erro
Erro ABT[E021] — variável não definida

A variável 'x' não foi definida.
```

```abt ok V06
função f(a, b) { retornar a + b }
mostrar f(2, 3)
```
```saida
5
```

```abt E000 V07
Julia = 1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: reserved namespace 'Julia'
```

```abt ok V08
contar = 3
mostrar contar
```
```saida
3
```

### 3.4 Tipos de valor

Em tempo de execução os valores são tipos do Julia. Para o núcleo importam:

| Tipo em execução | Origem | Tag da análise estática `[C ABT.jl:914-916, 1021-1023]` |
|---|---|---|
| `Int64` | literal inteiro, resultado de `+ - * ^` entre inteiros | `:number` |
| `Float64` | literal fracionário, `/`, operações com algum `Float64` | `:number` |
| `Bool` | `verdadeiro`, `falso`, comparações, `e`, `ou` | `:bool` |
| `String` | literal de texto | `:string` |
| `Vector` | lista `[ … ]` | `:list` |
| outros | resultados de chamadas, campos, bibliotecas | `:unknown` |

A análise estática **não distingue** `Int64` de `Float64`: ambos são `:number`. Valores `:unknown` têm suas verificações adiadas para a execução (§8.2).

### 3.5 Tipos numéricos e seus comportamentos observáveis

Os operadores aritméticos delegam ao Julia `[C ABT.jl:520-524]` (documentado: "Divisão usa `/` do runtime Julia" `[D expressions.md]`). Comportamento medido:

| Operação | Regra observada | Exemplo |
|---|---|---|
| `+ - *` com `Int64` e `Int64` | resultado `Int64`, aritmética **módulo 2⁶⁴ (dá a volta, sem aviso)** | `[E N03]` |
| `+ - *` com algum `Float64` | o `Int64` é convertido; resultado `Float64` (IEEE 754) | `[E N09]` |
| `/` | **sempre** `Float64`, inclusive entre inteiros (`6 / 3` vale `2.0`) | `[E N01]` |
| `/` por zero | **não é erro**: `1 / 0` → `Inf`, `-1 / 0` → `-Inf`, `0 / 0` → `NaN` | `[E N02]` |
| `^` com `Int64` e expoente `Int64` ≥ 0 | resultado `Int64`; estoura silenciosamente (`2 ^ 63`, `2 ^ 64`) | `[E N06]` |
| `^` com `Int64` e expoente `Int64` < 0 | erro de domínio do Julia (`E000`) | `[E N07]` |
| `^` com base `Float64` negativa e expoente fracionário | erro de domínio do Julia (`E000`) | `[E N08]` |
| `-` unário sobre o menor `Int64` | resultado é o próprio menor `Int64` | `[E N04]` |
| comparação `Int64` × `Float64` | **exata** (não arredonda o inteiro) | `[E N11]` |
| conversão `Int64` → `Float64` em operação mista | arredonda ao `Float64` mais próximo (perde precisão acima de 2⁵³) | `[E N11]` |

A documentação confirma `Int64`/`Float64`, a erro de domínio para `^` e a precisão do `Float64` `[D syntax.md]`, `[D expressions.md]`, `[D semantics.md]`; **não documenta** o "dar a volta" do `Int64` nem o `Inf` na divisão por zero (Apêndice A, DV-05 e DV-06). Os testes do projeto exercitam esses casos apenas como *concordância entre interpretador e código gerado* (`large_integer`, `divide_by_zero` em `[T break_abt.jl:10-11]`), não como decisão de projeto.

```abt ok N01
mostrar 7 / 2
mostrar 6 / 3
mostrar 1 + 2.5
mostrar 2 * 3
mostrar 7 - 2.5
mostrar 7 / 2 * 2
```
```saida
3.5
2.0
3.5
6
4.5
7.0
```

```abt ok N02
mostrar 1 / 0
mostrar -1 / 0
mostrar 0 / 0
```
```saida
Inf
-Inf
NaN
```

```abt ok N03
x = 9223372036854775807
mostrar x
mostrar x + 1
mostrar 9223372036854775807 * 2
```
```saida
9223372036854775807
-9223372036854775808
-2
```

```abt ok N04
x = -9223372036854775807 - 1
mostrar x
mostrar -x
mostrar x - 1
```
```saida
-9223372036854775808
-9223372036854775808
9223372036854775807
```

```abt E000 N05
mostrar -9223372036854775808
```
```erro
Erro ABT[E000] — erro de compilação ou execução

OverflowError: overflow parsing "9223372036854775808"
```

```abt ok N06
mostrar 2 ^ 10
mostrar 2.0 ^ -1
mostrar 2 ^ 0.5
mostrar 2 ^ 63
mostrar 2 ^ 64
```
```saida
1024
0.5
1.4142135623730951
-9223372036854775808
0
```

```abt E000 N07
mostrar 2 ^ -1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

DomainError with -1:
Cannot raise an integer x to a negative power -1.
Make x or -1 a float by adding a zero decimal (e.g., 2.0^-1 or 2^-1.0 instead of 2^-1) or write 1/x^1, float(x)^-1, x^float(-1) or (x//1)^-1.
```

```abt E000 N08
mostrar (-8.0) ^ (1 / 3)
```
```erro
Erro ABT[E000] — erro de compilação ou execução

DomainError with -8.0:
Exponentiation yielding a complex result requires a complex argument.
Replace x^y with (x+0im)^y, Complex(x)^y, or similar.
```

```abt ok N09
mostrar 0.1 + 0.2
mostrar 1 + 2.0 * 3
mostrar 3 * 2.0
mostrar 4 / 2
mostrar 2 ^ 3
mostrar 2.0 ^ 3
```
```saida
0.30000000000000004
7.0
6.0
2.0
8
8.0
```

```abt ok N11
mostrar 1 == 1.0
mostrar 9007199254740993 == 9007199254740992.0
mostrar 9007199254740993 > 9007199254740992.0
mostrar 9007199254740993 + 0.0
```
```saida
true
false
true
9.007199254740992e15
```

### 3.6 Como os números são impressos

`mostrar` converte o valor com `string` do Julia `[C StdlibRender.jl:28]`: inteiros em decimal; lógicos como `true`/`false`; reais com os dígitos mais curtos que reproduzem o valor, sempre com parte fracionária (`1.0`), e **notação científica** fora da faixa que o Julia imprime em forma posicional. A regra completa é do Julia; os limites medidos aparecem no exemplo `N10` (`100000.0` posicional; `1000000.0` → `1.0e6`; `0.0001` posicional; `0.00001` → `1.0e-5`). Valores infinitos e indefinidos aparecem como `Inf`, `-Inf` e `NaN`.

```abt ok N10
mostrar 1
mostrar 1.0
mostrar 100000.0
mostrar 1000000.0
mostrar 0.0001
mostrar 0.00001
mostrar 123456789.123
```
```saida
1
1.0
100000.0
1.0e6
0.0001
1.0e-5
1.23456789123e8
```

### 3.7 Operações numéricas sobre tipos inadequados

Quando os tipos são conhecidos na análise estática, operar texto ou lógico com operador aritmético é rejeitado **antes da execução** `[C ABT.jl:1050-1056]`, `[C ABT.jl:1046-1049]`:

```abt E000 N12
mostrar "a" + "b"
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: arithmetic '+' requires numbers
```

```abt E000 N13
mostrar 1 + verdadeiro
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: arithmetic '+' requires numbers
```

```abt E000 N14
mostrar -verdadeiro
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: unary '-' requires a number
```

---

## 4. Operadores e expressões

### 4.1 Precedência e associatividade (da mais forte para a mais fraca)

Derivadas das funções do analisador `[C ABT.jl:316-374]`; confirmadas pela documentação `[D expressions.md]`.

| Nível | Operadores / construções | Associatividade | Código |
|---|---|---|---|
| 1 | chamada `f(…)`, acesso `a.b`, `campo de registro` | à esquerda (encadeáveis) | `[C ABT.jl:430-447]` |
| 2 | potência `^` | **à direita**; o expoente é um `unario` | `[C ABT.jl:368-374]` |
| 3 | sinal unário `+` `-` (prefixo) | à direita; aplica-se **ao resultado** da potência | `[C ABT.jl:362-367]` |
| 4 | `*` `/` | à esquerda | `[C ABT.jl:355-361]` |
| 5 | `+` `-` binários | à esquerda | `[C ABT.jl:348-354]` |
| 6 | `>` `<` `>=` `<=` `==` `!=` e a forma `é …` | à esquerda (mesmo nível) | `[C ABT.jl:331-347]` |
| 7 | `e` (`and`) | à esquerda | `[C ABT.jl:324-330]` |
| 8 | `ou` (`or`) | à esquerda | `[C ABT.jl:317-323]` |

Parênteses agrupam qualquer expressão `[C ABT.jl:426-427]`. **Não existe** negação lógica (`nao`, `!`): ver §4.4.

```abt ok O01
mostrar 2 + 3 * 4
mostrar (2 + 3) * 4
mostrar 10 - 4 - 3
mostrar 100 / 10 / 5
mostrar -3 + 5
mostrar 2 * -3
mostrar - -3
```
```saida
14
20
3
2.0
2
-6
3
```

```abt ok O02
mostrar -2 ^ 2
mostrar (-2) ^ 2
mostrar 2 ^ 3 ^ 2
mostrar (2 ^ 3) ^ 2
```
```saida
-4
4
512
64
```

O exemplo do manual `[D expressions.md]` (cujos comentários indicam `-8.0`, `-8.0`, `0.125`, `-6.0`, `10.0`) produz exatamente esses valores:

```abt ok O03
a = 2.0
b = 3
mostrar -a ^ b
mostrar (-a) ^ b
mostrar a ^ -b
mostrar a * -b
mostrar (a + b) * 2
```
```saida
-8.0
-8.0
0.125
-6.0
10.0
```

### 4.2 Operadores aritméticos existentes

`+` (adição), `-` (subtração), `*` (multiplicação), `/` (divisão), `^` (potência) e os sinais unários `+` e `-` `[C ABT.jl:520-524, 480-484]`. **Não existem** resto (`%`), divisão inteira (`//`) nem `**` `[E S01]`, `[E S09]`, `[E S10]`. O operador `+` não concatena textos `[E N12]`. Operandos precisam ser números (ou `:unknown`, verificado na execução) `[C ABT.jl:1053-1056]`.

### 4.3 Operadores relacionais existentes

**Forma simbólica:** `>` `<` `>=` `<=` `==` `!=`.
**Forma verbal:** `é` (igualdade), `é maior que`, `é menor que`, com `que` **opcional** (`é maior`, `é menor`) `[C ABT.jl:333-343]`. Não existe forma verbal para `>=`, `<=` nem `!=`.

| Operador | Operandos | Resultado | Exemplo |
|---|---|---|---|
| `>` `<` `>=` `<=` | números (verificado estaticamente quando os tipos são conhecidos) | `Bool` | `[E O04]` |
| `==` `!=` | **quaisquer** valores (não exigem número); valores de tipos diferentes são simplesmente diferentes | `Bool` | `[E O05]` |
| `é`, `é maior (que)`, `é menor (que)` | idem à forma simbólica equivalente | `Bool` | `[E O06]`, `[E O07]` |

A regra estática `[C ABT.jl:1061-1067]` exige número nos quatro operadores de ordem; `==` e `!=` aceitam qualquer tipo. O operando direito de `é maior que` é uma expressão aditiva, então `5 é maior que 3 + 1` compara com `4` `[E O07]`.

```abt ok O04
x = 5
mostrar x > 3
mostrar x < 3
mostrar x >= 5
mostrar x <= 4
mostrar x == 5
mostrar x != 5
```
```saida
true
false
true
false
true
false
```

```abt ok O05
mostrar 1 == 1.0
mostrar 1 != 1.0
mostrar 2 > 1.5
mostrar 1 == "1"
mostrar 1 != "1"
mostrar "a" != "b"
mostrar verdadeiro == verdadeiro
mostrar [1, 2] == [1, 2]
```
```saida
true
false
true
false
true
true
true
true
```

```abt ok O06
x = 5
mostrar x é 5
mostrar x é maior que 3
mostrar x é menor que 3
mostrar x é maior 3
mostrar x é menor 9
```
```saida
true
true
false
true
true
```

```abt ok O07
mostrar 3 é maior que 2 e 1 é menor que 2
mostrar 5 é 5.0
mostrar 5 é maior que 3 + 1
```
```saida
true
true
true
```

```abt E000 O14
mostrar "a" < "b"
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: comparison '<' requires numbers
```

### 4.4 Operadores lógicos

`e` / `and` e `ou` / `or`, com **curto-circuito**: o operando direito só é avaliado se necessário `[C ABT.jl:517-518]`, `[D semantics.md]`, `[T break_abt.jl: logical_short_circuit]`. Ambos os operandos precisam ser `Bool` (verificado estaticamente quando conhecido) `[C ABT.jl:1057-1060]`. `e` tem precedência sobre `ou`. **Não existe `nao`** nem `!`: usar `x == falso` ou `x != verdadeiro` `[E O11]`.

```abt ok O08
mostrar verdadeiro e falso
mostrar verdadeiro ou falso
mostrar falso ou falso
mostrar 1 < 2 e 2 < 3 ou falso
mostrar verdadeiro ou falso e falso
mostrar (verdadeiro ou falso) e falso
```
```saida
false
true
false
true
true
false
```

No exemplo seguinte, `1 / 0` vale `Inf` (§3.5), de modo que a terceira linha imprime `true`; as duas primeiras mostram o curto-circuito (o lado direito não é avaliado):

```abt ok O09
mostrar falso e (1 / 0 > 1)
mostrar verdadeiro ou (1 / 0 > 1)
mostrar verdadeiro e (1 / 0 > 1)
```
```saida
false
true
true
```

```abt E000 O10
mostrar 1 e 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: logical '&&' requires booleans
```

```abt E010 O11
mostrar nao verdadeiro
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "verdadeiro" at 1:13.
```

Os sinônimos em inglês são equivalentes:

```abt ok O15
x = 3
if x > 1 and x < 5 { show 1 } else { show 2 }
show true or false
```
```saida
1
true
```

### 4.5 Comparações encadeadas

A gramática aceita `a < b < c` e a trata como `(a < b) < c`, com associatividade à esquerda `[C ABT.jl:333-345]`, `[D expressions.md]`. Como `a < b` é `Bool` e `<` exige números, a validação **rejeita** o encadeamento de operadores de ordem; já com `==` o encadeamento é aceito, pois `==` não exige tipo:

```abt E000 O12
mostrar 1 < 2 < 3
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: comparison '<' requires numbers
```

```abt ok O13
mostrar 1 == 1 == verdadeiro
```
```saida
true
```

### 4.6 Uma armadilha de sintaxe: as quebras de linha não terminam instruções

Como as quebras de linha são apenas espaço (§2.1), uma linha que começa com operador continua a expressão da anterior:

```abt ok S15
x = 5
-1
mostrar x
```
```saida
4
```

Aqui `x = 5 - 1`, logo `x` vale 4 `[D syntax.md: "Quebras de linha normalmente são apenas espaço"]`.

---

## 5. Estruturas de decisão e repetição

### 5.1 Decisão: `se` / `senao`

```
se CONDIÇÃO { instruções } [ senao { instruções } ]
```

* As **chaves são obrigatórias** (`bloco`) `[C ABT.jl:269-277, 294-298]` `[E C03]`. Parênteses em volta da condição são opcionais, pois são apenas agrupamento `[E S18]`.
* O `senao` é opcional; pode estar na linha seguinte `[E C05]`. **Não existe `senao se`**: um novo `se` precisa estar dentro de chaves `[E C04]`.
* A condição deve ser `Bool`. É verificado **estaticamente** quando o tipo é conhecido (`IF condition must be boolean`) `[C ABT.jl:1146-1147]` `[E C02]`; quando o tipo só é conhecido na execução, o Julia falha com `TypeError: non-boolean (Int64) used in boolean context` `[E C20]`. Número não é tratado como verdade `[D expressions.md]`.
* Os blocos aninham livremente. Como o bloco é delimitado por `{ }`, um `senao` pertence sempre ao `se` cujo bloco acabou de fechar `[C ABT.jl:295-298]` (não existe o problema do "else pendente") `[E C01]`.

```abt ok C01
x = 1
se x > 0 { mostrar 1 } senao { mostrar 2 }
se x < 0 { mostrar 3 }
se x > 0 {
    se x > 5 { mostrar 100 } senao { mostrar 10 }
} senao { mostrar 0 }
```
```saida
1
10
```

```abt E000 C02
se 1 { mostrar 1 }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: IF condition must be boolean
```

```abt E010 C03
se verdadeiro mostrar 1
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado {, mas foi encontrado "mostrar" at 1:15.
```

```abt E010 C04
x = 1
se x > 0 { mostrar 1 } senao se x < 0 { mostrar 2 }
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado {, mas foi encontrado "se" at 2:30.
```

```abt ok C05
x = 1
se x > 0 { mostrar 1 }
senao { mostrar 2 }
```
```saida
1
```

```abt ok S18
x = 1
se (x > 0) { mostrar 1 }
```
```saida
1
```

```abt E000 C20
função f() { retornar 3 }
se f() { mostrar 1 }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

TypeError: non-boolean (Int64) used in boolean context
```

### 5.2 Repetição: `para cada`

```
para cada VARIÁVEL em COLEÇÃO { instruções }
```

* A ABT possui **um único comando de repetição**: `para cada … em …` (equivalente a um *for-each*). Percorre a coleção na ordem recebida `[D control-flow.md]`, atribuindo cada elemento à variável do laço `[C ABT.jl:309-311, 611-616]`.
* A coleção precisa ser uma **lista** (ou valor de tipo desconhecido, verificado na execução); número e texto são rejeitados (`FOR requires a collection`) `[C ABT.jl:1157-1158]` `[E C15]`, `[E C16]`.
* O corpo pode executar zero vezes `[E C12]`. Laços aninham `[E C10]`.
* Um laço **contado** precisa de uma lista explícita, porque a linguagem **não tem** função de intervalo: o número de iterações é o tamanho da lista literal `[E C27]`. Entre os nomes da biblioteca básica `[C ABT.jl:11]` e as operações listadas por `abt operacoes` (55 linhas na 0.15.0) não há gerador de intervalo ou sequência.
* **Não existe** `enquanto`/`while` (nem `for` de três cláusulas, `break` ou `continue`): `enquanto` não é palavra reservada e o início da linha é lido como nome de variável, o que gera erro de sintaxe `[E C17]`, `[E C18]`. Recursão de funções é a outra forma de repetir `[E C25]`.
* A forma de `para cada` exige chaves `[E C19]`.

```abt ok C09
para cada i em [10, 20, 30] {
    mostrar i
}
```
```saida
10
20
30
```

```abt ok C10
para cada i em [1, 2] {
    para cada j em [10, 20] {
        mostrar i * j
    }
}
```
```saida
10
20
20
40
```

```abt ok C11
total = 0
para cada i em [1, 2, 3, 4] {
    total = total + i
}
mostrar total
```
```saida
10
```

```abt ok C12
para cada i em [] { mostrar i }
mostrar 0
```
```saida
0
```

```abt ok C27
contador = 0
para cada passo em [1, 2, 3, 4, 5] {
    contador = contador + passo
}
mostrar contador
```
```saida
15
```

```abt E000 C15
para cada i em 5 { mostrar i }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: FOR requires a collection
```

```abt E000 C16
para cada c em "abc" { mostrar c }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: FOR requires a collection
```

```abt E010 C17
enquanto verdadeiro { mostrar 1 }
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "verdadeiro" at 1:10.
```

```abt E010 C18
x = 0
enquanto x < 3 {
    x = x + 1
}
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "x" at 2:10.
```

```abt E010 C19
para cada i em [1, 2] mostrar i
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado {, mas foi encontrado "mostrar" at 1:23.
```

### 5.3 Visibilidade de nomes em `se` e `para cada` (análise de atribuição definida)

Regras implementadas na validação `[C ABT.jl:1145-1166]`, descritas por `[D control-flow.md]`, `[D semantics.md]`, `[D compiler.md]`:

1. **Depois de um `se`**, um nome *novo* só fica garantido se for definido **nos dois ramos** (e, portanto, só se houver `senao`) `[E C06]`. Definido só em um ramo, ou em ramos diferentes: `E021` `[E C07]`, `[E C08]`.
2. **Depois de um `para cada`**, nomes novos criados no corpo **não** escapam, pois o laço pode executar zero vezes; a **variável do laço também não** `[E C13]`, `[E C14]`.
3. Nomes criados **antes** do bloco continuam visíveis dentro dele e atribuições a eles valem depois `[E C22]`.
4. Dentro de um laço, uma variável definida nos dois ramos de um `se` fica disponível no restante do corpo `[E C23]`.
5. A variável do laço não pode ter o nome de uma função declarada `[C ABT.jl:1155]` `[E C24]`; o mesmo nome de variável de laço pode ser reutilizado em laços seguintes `[E C21]`.

Atenção: a ABT **não** tem escopo léxico de bloco no interpretador (§3.3). A regra acima é um *contrato de análise estática*: programas que o violam são rejeitados antes de executar.

```abt ok C06
se verdadeiro { a = 1 } senao { a = 2 }
mostrar a
```
```saida
1
```

```abt E021 C07
se verdadeiro { a = 1 }
mostrar a
```
```erro
Erro ABT[E021] — variável não definida

A variável 'a' não foi definida.
```

```abt E021 C08
se verdadeiro { a = 1 } senao { b = 2 }
mostrar a
```
```erro
Erro ABT[E021] — variável não definida

A variável 'a' não foi definida.
```

```abt E021 C13
para cada i em [1, 2, 3] { x = i * 2 }
mostrar x
```
```erro
Erro ABT[E021] — variável não definida

A variável 'x' não foi definida.
```

```abt E021 C14
para cada n em [1, 2] { mostrar n }
mostrar n
```
```erro
Erro ABT[E021] — variável não definida

A variável 'n' não foi definida.
```

```abt ok C22
x = 3
para cada i em [1, 2] { x = x + i }
mostrar x
```
```saida
6
```

```abt ok C23
para cada i em [1, 2] {
    se i == 2 { y = 7 } senao { y = 8 }
    mostrar y
}
```
```saida
8
7
```

```abt ok C21
para cada i em [1, 2] { mostrar i }
mostrar 99
para cada i em [3] { mostrar i }
```
```saida
1
2
99
3
```

```abt E000 C24
função dobro(x) { retornar x * 2 }
para cada dobro em [1] { mostrar 1 }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: loop variable shadows function 'dobro'
```

### 5.4 Funções (necessárias para recursão)

`função nome(parâmetros) { … }`, `retornar expressão`. Funções de nível superior são conhecidas antes de sua posição textual `[C ABT.jl:575-581]` `[E C26]`, têm aridade fixa e podem ser recursivas `[E C25]`. O terceiro valor impresso abaixo (`fatorial(21)`) mostra o "dar a volta" do `Int64` (§3.5).

```abt ok C25
função fatorial(n) {
    se n <= 1 { retornar 1 } senao { retornar n * fatorial(n - 1) }
}
mostrar fatorial(5)
mostrar fatorial(20)
mostrar fatorial(21)
```
```saida
120
2432902008176640000
-4249290049419214848
```

```abt ok C26
mostrar f(2)
função f(a) { retornar a * 2 }
```
```saida
4
```

---

## 6. Símbolos especiais e delimitadores

### 6.1 Os símbolos aceitos e onde cada um é empregado

São 21 símbolos `[C ABT.jl:163]`, mais `#` e `"` (tratados antes) e o sublinhado (caractere de nome).

| Símbolo | Papel | Onde pode aparecer (derivado da gramática §7) |
|---|---|---|
| `=` | atribuição | só como segundo elemento de `nome = expressão` `[C ABT.jl:313]` |
| `==` `!=` `>` `<` `>=` `<=` | comparação | entre duas expressões aditivas `[C ABT.jl:333]` |
| `+` `-` | adição/subtração; sinal | entre termos; ou antes de um operando (sinal) |
| `*` `/` | multiplicação, divisão | entre fatores |
| `^` | potência | entre um átomo e um operando (com ou sem sinal) |
| `(` `)` | agrupamento; argumentos de chamada; parâmetros de função | em expressões; depois de um nome (chamada); em `função nome( … )` |
| `[` `]` | literal de lista | em expressões `[C ABT.jl:419-425]` |
| `{` `}` | delimitam blocos | depois da condição do `se`, de `senao`, do `para cada` e da lista de parâmetros de `função` |
| `,` | separador | entre elementos de lista, argumentos e parâmetros |
| `;` | separador de instruções (**opcional**) / instrução vazia | entre instruções, em qualquer posição de início de instrução `[C ABT.jl:264, 273]` |
| `.` | acesso a campo (`a.b`) e caminho de importação (`usar Julia.Modulo`) | depois de um nome; **não** faz parte de um literal numérico fora do formato `dígitos.dígitos` |
| `#` | comentário | até o fim da linha |
| `"` | delimitador de texto | em pares |

Notas:

* **`;` não é obrigatório.** Instruções são reconhecidas pela sua palavra inicial; `x = 1 y = 2` na mesma linha é válido; `;` vazios são aceitos `[E S13]`, `[E S14]`, `[E S16]`. Isso difere de C/Java, em que o `;` termina todo comando.
* Os operadores de comparação de **dois caracteres** são tokens únicos; `<>`, `=>`, `**` e `//` **não** existem e são lidos como símbolos separados, gerando erro de sintaxe `[E S09]`–`[E S12]`.
* O acento de `é`/`função`/`média`/`senão` faz parte do lexema (são letras), não símbolo.

### 6.2 Caracteres que **não** pertencem à linguagem

`% ! & | ' : ? $ @ ~`, a barra invertida e o acento grave: erro `Unexpected character` (`E000`) `[C ABT.jl:164]`. (`!` só existe dentro de `!=`.)

```abt E000 S01
mostrar 5 % 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '%' at 1:11
```

```abt E000 S02
mostrar !verdadeiro
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '!' at 1:9
```

```abt E000 S03
mostrar 1 & 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '&' at 1:11
```

```abt E000 S04
mostrar 1 | 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '|' at 1:11
```

```abt E000 S05
mostrar 'a'
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '\'' at 1:9
```

```abt E000 S06
mostrar 1 : 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character ':' at 1:11
```

```abt E000 S07
mostrar 1 ? 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '?' at 1:11
```

```abt E000 S08
x = 1 $ 2
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unexpected character '$' at 1:7
```

```abt E010 S09
mostrar 2 ** 3
```
```erro
Erro ABT[E010] — erro de sintaxe

Unexpected token "*" at 1:12
```

```abt E010 S10
mostrar 5 // 2
```
```erro
Erro ABT[E010] — erro de sintaxe

Unexpected token "/" at 1:12
```

```abt E010 S11
mostrar 1 <> 2
```
```erro
Erro ABT[E010] — erro de sintaxe

Unexpected token ">" at 1:12
```

```abt E010 S12
mostrar 1 => 2
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "=" at 1:11.
```

### 6.3 Exemplos de uso de `;` e de espaço em branco

```abt ok S13
x = 1 y = 2
mostrar x + y
```
```saida
3
```

```abt ok S14
x = 1; y = 2; mostrar x + y;
;;
```
```saida
3
```

```abt ok S16
mostrar 1;; mostrar 2
```
```saida
1
2
```

### 6.4 Exemplos léxicos complementares (palavras-chave, números, texto e comentários)

```abt ok L01
SE verdadeiro { Mostrar 1 }
MOSTRAR VERDADEIRO
```
```saida
1
true
```

```abt ok L14
mostrar 007 + 1
mostrar 3.14
mostrar 0.5
mostrar 10.50
mostrar 007.50
```
```saida
8
3.14
0.5
10.5
7.5
```

```abt E010 L15
mostrar 5.
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "." at 1:10.
```

```abt E010 L16
mostrar .5
```
```erro
Erro ABT[E010] — erro de sintaxe

Unexpected token "." at 1:9
```

```abt E010 L17
mostrar 1.2.3
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "." at 1:12.
```

```abt E010 L18
mostrar 1e3
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "" at 2:1.
```

```abt E010 L19
mostrar 1_000
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "" at 2:1.
```

```abt E010 L20
mostrar 0x1F
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado =, mas foi encontrado "" at 2:1.
```

```abt E000 L21
mostrar 99999999999999999999
```
```erro
Erro ABT[E000] — erro de compilação ou execução

OverflowError: overflow parsing "99999999999999999999"
```

```abt E000 L22
mostrar ٣
```
```erro
Erro ABT[E000] — erro de compilação ou execução

ArgumentError: invalid base 10 digit '٣' in "٣"
```

```abt ok L23
mostrar -5
mostrar +5
mostrar - 5
```
```saida
-5
5
-5
```

```abt ok L24
# comentário de linha
mostrar 1 # comentário no fim da linha
```
```saida
1
```

```abt ok L25
mostrar "texto"
mostrar "a\nb"
mostrar ["x", 1]
```
```saida
texto
a
b
["x", 1]
```

```abt E000 L26
mostrar "aberto
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Unterminated string at 1:9
```

---

## 7. Gramática sintática em EBNF

### 7.1 Natureza do analisador

O analisador `parse_program` `[C ABT.jl:261-268]` é um **descendente recursivo escrito à mão**: uma função por nível de precedência. Fatos verificáveis no código que importam para a gramática:

* Na maioria das produções decide-se olhando um token (`at(p, …)`) `[C ABT.jl:245]`.
* Há **duas exceções**: (i) `collection_form` examina o token seguinte e, se este é `(`, **varre adiante até o parêntese que fecha** para decidir se `filtrar`/`transformar`/`limitar` formam uma expressão de coleção `[C ABT.jl:375-395]`; (ii) `expand_pipelines` testa por tentativa (`try`/`catch`) se uma linha é uma expressão completa `[C ABT.jl:191-199]`.
* Por isso **este documento não afirma que a gramática da ABT seja LL(1)** (nem a classifica em outra classe): a implementação não se restringe a um token de antecipação e nenhuma demonstração foi feita. A EBNF abaixo é uma **descrição** da linguagem aceita, com a verificação empírica do §7.5.

### 7.2 EBNF do núcleo e das formas auxiliares

```ebnf
(* Terminais: tokens da §2 (IDENT, NUMBER, STRING) e palavras reservadas (§2.3).
   "mostrar" significa o token SHOW (mostrar | show), etc.; todas as palavras-chave
   ignoram maiúsculas e minúsculas (§2.3). *)

programa      = { ";" | instrucao } , EOF ;                               (* ABT.jl:261-268 *)
bloco         = "{" , { ";" | instrucao } , "}" ;                         (* ABT.jl:269-277 *)

instrucao     = usar | exibir | condicional | funcao | retorno
              | repeticao | atribuicao ;                                  (* ABT.jl:278-315 *)

exibir        = "mostrar" , expressao ;                                   (* 292-293 *)
atribuicao    = nome , "=" , expressao ;                                  (* 312-313 *)
condicional   = "se" , expressao , bloco , [ "senao" , bloco ] ;          (* 294-298 *)
repeticao     = "para" , "cada" , nome , "em" , expressao , bloco ;       (* 309-311 *)
funcao        = "função" , nome , "(" , [ nome , { "," , nome } ] , ")" , bloco ;  (* 299-306 *)
retorno       = "retornar" , expressao ;                                  (* 307-308 *)
usar          = "usar" , nome , "." , nome , [ { "." , nome } ] ;         (* 279-291; ver nota N-1 *)

nome          = IDENT | SUM | AVG ;                  (* take_name, 248-254; rejeita prefixo "__abt_" *)

expressao     = disjuncao ;                                               (* 316 *)
disjuncao     = conjuncao , { "ou" , conjuncao } ;                        (* 317-323 *)
conjuncao     = comparacao , { "e" , comparacao } ;                       (* 324-330 *)
comparacao    = soma , { operador_rel , soma } ;                          (* 331-347 *)
operador_rel  = ">" | "<" | ">=" | "<=" | "==" | "!="
              | "é" , [ ( "maior" | "menor" ) , [ "que" ] ] ;
soma          = produto , { ( "+" | "-" ) , produto } ;                   (* 348-354 *)
produto       = unario , { ( "*" | "/" ) , unario } ;                     (* 355-361 *)
unario        = ( "+" | "-" ) , unario | potencia ;                       (* 362-367 *)
potencia      = atomo , [ "^" , unario ] ;                                (* 368-374 *)

atomo         = forma_colecao | agregacao | NUMBER | STRING | booleano
              | lista | "(" , expressao , ")" | referencia ;              (* 396-451 *)
booleano      = "verdadeiro" | "falso" ;
lista         = "[" , [ argumentos ] , "]" ;
argumentos    = expressao , { "," , expressao } ;
referencia    = ( IDENT | "valor" | SUM | AVG ) ,
                { "(" , [ argumentos ] , ")"  |  "." , nome  |  "de" , atomo } ;  (* 428-447; nota N-2 *)

forma_colecao = "filtrar"     , atomo , "onde" , expressao
              | "transformar" , atomo , "com"  , expressao
              | "limitar"     , atomo , "a"    , atomo ;                  (* 397-407; nota N-3 *)
agregacao     = ( "soma" | "media" ) , "de" , atomo , [ "onde" , expressao ] ;   (* 408-412 *)
```

**Notas de precisão** (cada uma decorre do código):

* **N-1.** Para `usar Python.x.y`, o analisador consome `.nome` repetidamente `[C ABT.jl:281-287]`; para qualquer outra raiz (a única válida é `Julia`) consome um único `.nome` `[C ABT.jl:288-291]`. A raiz diferente de `Python`/`Julia` é rejeitada na etapa semântica (`only Julia and Python modules are supported`), não na sintática. Logo `usar Julia.Statistics.mean` é erro de sintaxe `[E U01]`.
* **N-2.** `de` só é aceito depois de um **nome simples** (`n.kind == :var`); depois de uma chamada, por exemplo, é `Invalid property access` `[C ABT.jl:442-444]`. `valor` pode ser lido como expressão (variável do elemento corrente) mas **não pode ser definido** como nome `[C ABT.jl:248-254, 428]` `[E L10]`.
* **N-3.** `filtrar`, `transformar`, `limitar`, `com` e `a` são `IDENT`s; só formam a construção se o contexto a confirma `[C ABT.jl:375-395]`. Fora dele são nomes comuns `[E L13]`. `soma`/`media` seguidos de `de` formam agregação; fora disso, são nomes `[C ABT.jl:408]`.
* **N-4.** Os símbolos `==`, `!=`, `>`, `<`, `>=`, `<=` e a forma `é` ficam **no mesmo nível** e associam à esquerda `[C ABT.jl:331-347]`.
* **N-5.** A gramática **não impõe** `;` entre instruções (§6.1) e **não** distingue linhas.
* **N-6.** O que a EBNF aceita não é tudo o que executa: a validação estática (§8.2) ainda rejeita, por exemplo, `retornar` fora de função, condição não booleana e nomes indefinidos.

A documentação oficial traz uma EBNF "de superfície" `[D grammar.md]`; a daqui a **refina** com o que o código faz (Apêndice A, DV-02, DV-03, DV-07).

### 7.3 Terminais que o analisador espera, por construção

| Construção | Terminais obrigatórios | Erro típico |
|---|---|---|
| `atribuicao` | `nome` `=` `expressao` | `Era esperado =, mas foi encontrado …` (`E010`) |
| `condicional` | `se` `expressao` `{` … `}` | `Era esperado {, mas foi encontrado …` (`E010`) `[E C03]` |
| `repeticao` | `para` `cada` `nome` `em` `expressao` `{` … `}` | `Era esperado EACH/IN/{ …` (`E010`) |
| `bloco` sem `}` | — | `Unclosed block` (`E000`, não `E010`) `[C ABT.jl:272]` |
| fim inesperado | — | `Unexpected token "" at L:C` (`E010`) |

### 7.4 Pré-processamento: pipelines indentados (fora do núcleo exigido)

Antes de analisar, `expand_pipelines` `[C ABT.jl:177-239]` reescreve uma linha que é expressão completa, seguida de linhas mais indentadas com etapas `filtrar onde …`, `transformar com …`, `limitar a …` e um `mostrar` final, para as formas de coleção da gramática acima. Tabulações no recuo são erro. Não afeta o núcleo; é registrado por completude `[D grammar.md]`, `[T test_pipelines_118.jl]`:

```abt ok P05
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    limitar a 2
    mostrar
```
```saida
[3, 4]
```

```abt E010 U01
usar Julia.Statistics.mean
```
```erro
Erro ABT[E010] — erro de sintaxe

Era esperado IDENT, mas foi encontrado "." at 1:22.
```

### 7.5 Verificação empírica da EBNF contra o analisador real

Como a EBNF foi derivada **manualmente** do código, ela foi verificada de forma empírica (script `tools/verificar_ebnf.py` + `tools/analisar_sintaxe.jl`, Apêndice C.2). O script **gera programas a partir da EBNF** (não interpreta ABT) e entrega cada um ao `tokenize` + `parse_program` **originais** da ABT. Resultado (semente 15, registrado em `evidencias/verificacao_ebnf.json`):

* **500 programas** gerados pela EBNF (em média 537 caracteres cada; todas as instruções, as formas de coleção, agregações, `é maior/menor [que]`, `^`, chamadas, campos, `de`, `valor`, `usar`, `;` soltos e os sinônimos em inglês aparecem em dezenas ou centenas deles) — **500 aceitos** pelo `tokenize` + `parse_program` reais, **nenhum recusado**.
* **Controle negativo:** de cada programa removeu-se um símbolo estrutural (`{ } = ( ) [ ]`); dos **483** mutantes obtidos, o analisador real **rejeitou os 483**. Isso mostra que o teste discrimina (um analisador que aceitasse tudo seria detectado).

O que isto demonstra: nas amostras geradas, a EBNF **não é mais permissiva** do que o analisador real. O que **não** demonstra: que o analisador real não aceita programas que a EBNF não gera (completude), a equivalência das duas linguagens, ou qualquer propriedade formal como LL(1) (§7.1).

---

## 8. Regras semânticas relevantes

### 8.1 Ordem de avaliação

Operandos e argumentos são avaliados da esquerda para a direita `[C ABT.jl:516-519]`, `[D semantics.md]`; `e`/`ou` curto-circuitam `[C ABT.jl:517-518]`; funções de nível superior são registradas antes da execução `[C ABT.jl:575-581]`.

### 8.2 Semântica estática (`validate_ir`)

A validação percorre o programa uma vez, mantendo um mapa *nome → tag* e a **tag** de cada expressão `[C ABT.jl:886-1179]`. As tags são `:number`, `:bool`, `:string`, `:list`, `:unknown` (e `:external` para pontes). Regras relevantes ao núcleo:

| Regra | Código | Exemplo |
|---|---|---|
| nome lido deve estar definido (`undefined variable`, `E021`) | `[C ABT.jl:917-918]` | `[E V03]` |
| `+ - * / ^` exigem `:number` ou `:unknown` | `[C ABT.jl:1053-1056]` | `[E N12]` |
| sinal unário exige `:number` ou `:unknown` | `[C ABT.jl:1046-1049]` | `[E N14]` |
| `e`/`ou` exigem `:bool` ou `:unknown` | `[C ABT.jl:1057-1060]` | `[E O10]` |
| `> < >= <=` exigem `:number` ou `:unknown`; `==`/`!=` não exigem | `[C ABT.jl:1061-1067]` | `[E O12]`, `[E O14]` |
| condição de `se` deve ser `:bool` ou `:unknown` | `[C ABT.jl:1146-1147]` | `[E C02]` |
| `para cada` exige `:list` ou `:unknown` | `[C ABT.jl:1157-1158]` | `[E C15]` |
| `retornar` só dentro de função | `[C ABT.jl:1142-1143]` | `[E M06]` |
| função duplicada; reatribuir nome de função; variável de laço com nome de função | `[C ABT.jl:898, 1116, 1155]` | `[E M04]`, `[E M05]`, `[E C24]` |
| chamada a função declarada com aridade errada (`E052`) | `[C ABT.jl:957-958]` | `[E M03]` |
| definição após `se` / `para` | `[C ABT.jl:1145-1166]` | §5.3 |
| funções: ambiente isolado (sem capturar variáveis globais) | `[C ABT.jl:1121-1141]` | `[E V05]` |

A tag **`:unknown`** (resultado de chamadas, campos, e de nomes cujo tipo difere entre ramos `[C ABT.jl:1152]`) **adia** a verificação para a execução; nesse caso o erro vem do próprio Julia (por exemplo, `TypeError`).

```abt E052 M03
função f(a) { retornar a }
mostrar f(1, 2)
```
```erro
Erro ABT[E052] — quantidade incorreta de argumentos

A função 'f' espera 1 argumentos, mas recebeu 2.
```

```abt E000 M04
função f() { retornar 1 }
função f() { retornar 2 }
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: duplicate function 'f'
```

```abt E000 M05
função f() { retornar 1 }
f = 3
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: cannot reassign function 'f'
```

```abt E000 M06
retornar 1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

Erro semântico: RETURN outside function
```

```abt ok M07
função f(x) { y = x * 2 }
mostrar f(1)
```
```saida
nothing
```

```abt ok M10
x = 1
x = verdadeiro
se x { mostrar 1 }
```
```saida
1
```

### 8.3 Semântica de execução (`execute_unchecked`)

* **Estado:** um dicionário *nome → valor*, único para o nível superior `[C ABT.jl:572-620]`.
* `nome = e` avalia `e` e grava; `mostrar e` avalia e **acrescenta o texto formatado** a uma lista de saída `[C ABT.jl:584-587]`.
* `se c { A } senao { B }` avalia `c` e executa `A` ou `B` **no mesmo ambiente** `[C ABT.jl:608-610]`.
* `para cada x em L { C }`: para cada elemento `v` de `L`, faz `x = v` e executa `C` `[C ABT.jl:611-616]`; depois do laço, `x` mantém o último valor *no ambiente*, mas a validação já impede a leitura de `x` fora do laço (§5.3).
* **Chamada de função:** cria ambiente novo com os parâmetros e apenas funções declaradas e nomes da biblioteca `[C ABT.jl:494-504]`; sem `retornar`, devolve `nothing`, que `mostrar` imprime como `nothing` `[E M07]`.
* **Saída:** a CLI imprime as linhas **somente depois de o programa terminar com sucesso** `[C CLIMain.jl:39]`. Consequência observável: **se ocorrer um erro de execução depois de um `mostrar`, a saída anterior é descartada** `[E M02]`; e um erro estático impede qualquer saída `[E M01]`.

```abt E021 M01
mostrar 1
mostrar y
```
```erro
Erro ABT[E021] — variável não definida

A variável 'y' não foi definida.
```

```abt E000 M02
mostrar 1
mostrar 2 ^ -1
```
```erro
Erro ABT[E000] — erro de compilação ou execução

DomainError with -1:
Cannot raise an integer x to a negative power -1.
Make x or -1 a float by adding a zero decimal (e.g., 2.0^-1 or 2^-1.0 instead of 2^-1) or write 1/x^1, float(x)^-1, x^float(-1) or (x//1)^-1.
```

### 8.4 Diagnósticos e códigos de saída

`render_diagnostic` classifica o erro pela mensagem `[C ABT.jl:1600-1610]`:

| Código | Título | Critério |
|---|---|---|
| `E010` | erro de sintaxe | mensagem contém `Expected `, `Unexpected token` ou `Pipeline error` |
| `E021` | variável não definida | mensagem contém `undefined variable` |
| `E052` | quantidade incorreta de argumentos | mensagem contém `wrong argument count` ou `expects ` |
| `E000` | erro de compilação ou execução | todos os demais (inclui erro léxico, `TypeError`, `DomainError`, `OverflowError`, erros semânticos de tipo) |

Códigos de saída da CLI: `0` sucesso; `1` erro do programa; `2` uso incorreto ou arquivo ausente `[C CLIText.jl: ABT_HELP]`, `[D semantics.md]`. `abt check` imprime `Programa ABT válido.` `[C CLIMain.jl:37]`.

```abt-check ok M08
x = 1
mostrar x
```
```saida
Programa ABT válido.
```

```abt-check E021 M09
x = 1
mostrar y
```
```erro
Erro ABT[E021] — variável não definida

A variável 'y' não foi definida.
```

---

## 9. Exemplos de programas executáveis

Todos executados na ABT real pelo verificador (§C.1).

**P01 — Média e contagem (variáveis, `para cada`, `se`, aritmética real, relacionais):**

```abt ok P01
notas = [7.5, 4.0, 9.0, 6.0]
soma_notas = 0
aprovados = 0
para cada nota em notas {
    soma_notas = soma_notas + nota
    se nota >= 6 {
        aprovados = aprovados + 1
    }
}
media_turma = soma_notas / 4
mostrar media_turma
mostrar aprovados
se media_turma >= 6 {
    mostrar "turma aprovada"
} senao {
    mostrar "turma reprovada"
}
```
```saida
6.625
3
turma aprovada
```

**P02 — Função e laço (soma de quadrados):**

```abt ok P02
função quadrado(n) {
    retornar n * n
}
total = 0
para cada i em [1, 2, 3, 4] {
    total = total + quadrado(i)
}
mostrar total
```
```saida
30
```

**P03 — Decisões aninhadas e operadores lógicos:**

```abt ok P03
temperatura = 27.5
se temperatura < 15 {
    mostrar "frio"
} senao {
    se temperatura >= 15 e temperatura < 25 {
        mostrar "ameno"
    } senao {
        mostrar "quente"
    }
}
```
```saida
quente
```

**P04 — Acúmulo de reais (arredondamento visível):**

```abt ok P04
saldo = 100.0
taxa = 0.05
para cada mes em [1, 2, 3] {
    saldo = saldo + saldo * taxa
    mostrar saldo
}
```
```saida
105.0
110.25
115.7625
```

---

## 10. Matriz de conformidade com o enunciado da disciplina

Legenda de **Situação**: **Atendido** = a ABT 0.15.0 possui e executa o mecanismo; **Atendido com ressalva** = possui, mas a implementação difere do exemplo do enunciado em algum ponto (descrito); **Não atendido** = a ABT não possui o mecanismo.

O enunciado pede que a linguagem tenha determinadas capacidades e dá *exemplos de regras* (marcados "Por exemplo"). Conforme o objetivo desta entrega, **não** se alterou a ABT para imitar esses exemplos: onde os exemplos restringem mais do que a ABT, a coluna "Ressalva" diz exatamente o que a ABT faz.

| # | Requisito do enunciado | Como a ABT atende | Evidência | Situação | Ressalva (comportamento real) |
|---|---|---|---|---|---|
| 1 | **Criação de variáveis pelo usuário** | `nome = expressão`; criada na primeira atribuição, sem declaração, tipagem dinâmica | §3.3; `[C ABT.jl:312-313]`; `[E V01]`, `[E V02]` | **Atendido** | — |
| 2 | **Números inteiros e/ou fracionários** | `Int64` (`3`) e `Float64` (`3.14`), com promoção e comparação exata | §2.4, §3.4, §3.5; `[E L14]`, `[E N01]`, `[E N09]` | **Atendido** | `Int64` dá a volta em silêncio; `/` por zero dá `Inf` (DV-05, DV-06) |
| 3 | **Ao menos dois operadores aritméticos** | `+ - * /` e também `^`, e sinais unários | §4.2; `[E O01]`, `[E O02]` | **Atendido** | possui mais do que `+ - * /` (inclui `^`) |
| 4 | **Ao menos dois operadores relacionais** | `> < >= <= == !=` e a forma verbal `é [maior\|menor] [que]` | §4.3; `[E O04]`–`[E O07]` | **Atendido** | — |
| 5 | **Um comando condicional** | `se … { } [senao { }]` | §5.1; `[E C01]`–`[E C05]` | **Atendido** | chaves obrigatórias; sem `senao se` |
| 6 | **Um comando de repetição (for/while)** | `para cada x em lista { }` (for-each) | §5.2; `[E C09]`–`[E C12]`, `[E C27]` | **Atendido com ressalva** | **não há `while`**; o laço é sobre lista (sem função de intervalo) |
| 7 | **Símbolos especiais: quando, onde e quais** | 21 símbolos + `#` + `"`, com papel e posição definidos | §6.1, §6.2; `[E S01]`–`[E S16]` | **Atendido** | conjunto bem maior que `;` e `( )` |
| 8 | *Exemplo:* "Atribuições e expressões aritméticas só poderão ser formadas por `+ - * /` e `=`" | atribuição com `=`; aritmética com `+ - * /` (e `^`) | §4.1, §4.2 | **Atendido com ressalva** | além de `+ - * /`, aceita `^`, chamadas, listas, textos |
| 9 | *Exemplo:* "Identificadores não podem iniciar com números" | `2y`, `1a` são rejeitados | §3.1, §3.2; `[E L04]`, `[E L05]` | **Atendido** | rejeição vem do analisador sintático (mensagem genérica), não de regra léxica |
| 10 | *Exemplo:* "após a primeira letra, dígitos ao final e/ou em meio às letras" | `x1`, `a1b2`, `r2d2` válidos | §3.1; `[E L02]` | **Atendido** | — |
| 11 | *Exemplo:* "não poderão ter caracteres especiais" | `x$`, `x-y` inválidos | §3.1; `[E L07]`, `[E L08]` | **Atendido com ressalva** | **o sublinhado `_` é aceito** (`a_b`, `_a`), e letras Unicode (`ação`) |
| 12 | *Exemplo:* "não poderão ter espaços" | espaço separa tokens: `a b = 1` é erro | §3.1; `[E L06]` | **Atendido** | — |
| 13 | *Exemplo:* "Números inteiros e/ou fracionários; fracionários com parte inteira separada por ponto" | `3.14` válido; `5.` e `.5` rejeitados | §2.4; `[E L14]`–`[E L17]` | **Atendido** | exige dígitos dos dois lados do ponto |
| 14 | *Exemplo:* "Os símbolos especiais aceitos serão apenas `;` e `( )`" | — | §6.1 | **Não atendido (literalmente)** | a ABT aceita também `{ } [ ] , . = == != > < >= <= + - * / ^ # "`; `;` é opcional |
| 15 | **(Opcional) etapas léxica e sintática** | regras léxicas (tabela + EBNF léxica) e gramática EBNF derivadas do código; verificação empírica | §2, §7, §C.2 | **Atendido** | sem alegar propriedades formais (p. ex. LL(1)) |
| 16 | Exemplos executáveis e inválidos contra a ABT real | exemplos `L…`, `V…`, `N…`, `O…`, `C…`, `S…`, `M…`, `P…` | §C.1 (todos conferidos) | **Atendido** | — |

Resumo: dos 16 itens, 12 são **atendidos**, 3 **atendidos com ressalva** (6, 8 e 11) e 1 **não atendido literalmente** (o item 14: os símbolos especiais da ABT vão além de `;` e `( )`). Esses números refletem o *comportamento real* da ABT; nenhum foi obtido modificando a linguagem.

---

## 11. Limitações conhecidas e conclusões

### 11.1 Limitações da própria ABT 0.15.0 (relevantes ao núcleo)

1. **Sem `enquanto`/`while`**: a única repetição é `para cada` sobre listas; sem função de intervalo, contar exige lista literal `[E C27]`, `[E C17]`, `[E C18]`.
2. **Sem negação lógica** (`nao`, `!`) `[E O11]` e sem operadores de resto/divisão inteira `[E S01]`, `[E S10]`.
3. **`Int64` dá a volta em silêncio** (`9223372036854775807 + 1`, `2 ^ 64`, `fatorial(21)`) `[E N03]`, `[E N06]`, `[E C25]`.
4. **`1 / 0` vale `Inf`; `0 / 0` vale `NaN`** `[E N02]`.
5. **Mensagens de erro genéricas:** erros léxicos e vários erros de tipo são `E000`; `2y` aparece como erro sintático no fim do arquivo `[E L05]`; `Unclosed block` não é `E010`.
6. **Quebras de linha não terminam instruções**; uma linha iniciada por `-`, `+`, `(` ou `[` pode continuar a anterior `[E S15]`.
7. **Verificação de tipos incompleta:** só quando a tag é conhecida; `:unknown` falha na execução (`TypeError`, `DomainError`) `[E C20]`, `[E N07]`, `[E N08]`.
8. **Saída só ao final:** um erro de execução descarta a saída anterior `[E M02]`.
9. **Sem escopo léxico de bloco**: o "escopo" é um contrato de análise estática (§5.3).

### 11.2 Limitações deste trabalho

* A EBNF e as tabelas foram **derivadas manualmente** do código e da execução; a verificação empírica (§C.2) é uma **amostra**, não prova. Nenhuma propriedade formal (LL(1), não ambiguidade, equivalência de linguagens) é afirmada.
* Descreve-se e mede-se o **interpretador** (`abt run`). Os geradores de código Julia, a biblioteca científica e as pontes com Julia/Python estão fora do escopo.
* Medições em **uma** instalação: ABT 0.15.0 (`0b1d9b8`), Julia 1.13.3, Linux. Os resultados registrados estão em `evidencias/`.
* O comportamento de classes Unicode (`\d`, `\w`) foi verificado só nos exemplos `[E L03]`, `[E L22]`, não exaustivamente.

### 11.3 Conclusões

A ABT 0.15.0 implementa, em português, um núcleo imperativo completo para a atividade: **variáveis** por atribuição, **números** `Int64` e `Float64`, **operadores aritméticos, relacionais e lógicos**, o **condicional** `se/senao` e a **repetição** `para cada`. As regras reais foram extraídas do código (`tokenize`, `parse_program`, `validate_ir`, `execute`), conferidas contra a documentação e os testes do projeto e **executadas** (todos os exemplos deste documento são reproduzíveis com `abt run`). Os pontos em que a ABT se afasta dos exemplos do enunciado (ausência de `while`, conjunto de símbolos maior, `_` em nomes) e os comportamentos numéricos não documentados estão registrados explicitamente, sem inventar regra para conciliá-los.

---

## Apêndice A — Divergências e lacunas (implementação × documentação × testes)

Registradas sem conciliação: vale o comportamento medido.

| ID | Tema | Documentação / testes | Implementação (medida) | Evidência |
|---|---|---|---|---|
| DV-01 | Caixa das palavras-chave | `[D grammar.md]` e `[D syntax.md]` não mencionam | palavras-chave **não** distinguem caixa (`SE`, `Mostrar`) | `[C ABT.jl:161]`, `[T test_abstraction_keywords.jl]`, `[E L01]` |
| DV-02 | `valor` / `value` | `[D grammar.md]` lista as palavras-chave sem `valor`/`value`; `[D syntax.md]` diz que as palavras-chave da gramática não devem ser nomes | `valor`/`value` são palavras reservadas: `valor = 3` é `E010` | `[C ABT.jl:111, 248-254]`, `[E L10]` |
| DV-03 | Início de nome | `[D grammar.md]`: "começa com letra Unicode" | também pode começar com `_` (`_a`) | `[C ABT.jl:159]`, `[E L03]` |
| DV-04 | `E010` | `[D semantics.md]`: "cobre alguns erros de sintaxe" | `Unclosed block` e erros léxicos são `E000` | `[C ABT.jl:1600-1610]`, `[E L26]`, `[E S01]` |
| DV-05 | `Int64` ao estourar | `[D syntax.md]`: apenas "Inteiros são `Int64`" | dá a volta módulo 2⁶⁴ sem erro | `[E N03]`, `[E N06]`, `[T break_abt.jl: large_integer]` (compara backends) |
| DV-06 | Divisão por zero | `[D expressions.md]`: "divisão por zero não recebe um valor de substituição ABT" | resultado é `Inf`/`-Inf`/`NaN` do Julia, sem erro | `[C ABT.jl:524]`, `[E N02]` |
| DV-07 | `usar` | `[D grammar.md]` (EBNF): `usar , ("Julia"\|"Python") , "." , nome , { "." , nome }` | para `Julia` só um `.nome` é aceito; mais é `E010` (o texto do manual já diz "exatamente um módulo") | `[C ABT.jl:281-291]`, `[E U01]` |
| DV-08 | Comparação encadeada | `[D expressions.md]`: "avaliadas como binárias sucessivas" | verdadeiro para `==`; para `<`/`>` a validação rejeita (`Bool` não é número) | `[C ABT.jl:1061-1064]`, `[E O12]`, `[E O13]` |
| DV-09 | Comentário em teste | `[T runtests.jl:34]`: "unary minus (not in current grammar)" | o sinal unário existe no analisador | `[C ABT.jl:362-367]`, `[E L23]` — apenas comentário desatualizado em teste |
| DV-10 | Identificador iniciado por dígito | não há regra documentada | não há erro léxico: `2y` vira `NUMBER` + `IDENT` e a sintaxe falha, com mensagem genérica | `[C ABT.jl:149, 159]`, `[E L05]` |

**Situação das correções.** O [PR #12](https://github.com/GustavoDMentz/ABT-Language/pull/12) foi **integrado à main** (merge commit `86eaa78`, build e deploy do site verdes) e corrige apenas o **texto** da documentação e um comentário de teste: DV-01, DV-02, DV-03, DV-07, DV-08 e DV-09. DV-04 e DV-10 (qualidade das mensagens) e DV-05 e DV-06 (estouro de `Int64` e divisão por zero, que são decisões de semântica) continuam como estão na implementação e apenas registrados aqui. As medições e o código citados neste documento são do commit `0b1d9b8` (anterior ao PR #12); a documentação oficial, a partir de `86eaa78`, passa a coincidir com as linhas DV-01, 02, 03, 07, 08 e 09 da tabela acima.

## Apêndice B — Índice de evidências

**Código (commit `0b1d9b8`)**

| Arquivo | Linhas | Conteúdo |
|---|---|---|
| `src/ABT.jl` | 108–118 | `KEYWORDS` (46 lexemas) |
| `src/ABT.jl` | 132–173 | `tokenize` (regras léxicas) |
| `src/ABT.jl` | 177–239 | `expand_pipelines` |
| `src/ABT.jl` | 241–451 | analisador (`take_name`, `parse_program`, `block`, `statement`, expressões, `collection_form`, `atom`) |
| `src/ABT.jl` | 480–571 | `abt_unary`, `evalnode` |
| `src/ABT.jl` | 572–631 | `execute_unchecked`, `execute` |
| `src/ABT.jl` | 886–1179 | `validate_ir` (`infer`, `check`) |
| `src/ABT.jl` | 1593–1624 | catálogo e classificação de diagnósticos |
| `src/CLIMain.jl` | 20–45 | comandos `run`/`check`, saída e diagnósticos |
| `src/CLIText.jl` | — | ajuda e códigos de saída |
| `src/StdlibRender.jl` | 9–29 | formatação de `mostrar` |

**Documentação (`docs/src/`)**: `reference/grammar.md`, `reference/semantics.md`, `manual/syntax.md`, `manual/expressions.md`, `manual/control-flow.md`, `internals/compiler.md`, `getting-started/overview.md`.

**Testes (`tests/`)**: `test_abstraction_keywords.jl` (palavras-chave em qualquer caixa), `test_static_096.jl` (funções não capturam variáveis), `test_differential_1000.jl` (1000 casos de concordância; inclui `unicode_names`), `break_abt.jl` (concordância interpretador × gerado: `large_integer`, `divide_by_zero`, `loop_scope`, `branch_scope`, `logical_short_circuit`), `runtests.jl` (aritmética, nomes indefinidos, identificadores contextuais), `test_pipelines_118.jl`, `test_diagnostics.jl` (códigos `E010`, `E021`, `E052`).

**Testes do repositório reexecutados** neste ambiente (ABT 0.15.0, Julia 1.13.3), todos com sucesso: `test_abstraction_keywords.jl` (3/3), `test_static_096.jl` (aprovado), `test_diagnostics.jl` (43/43), `break_abt.jl` (23 casos: 20 concordam, 3 erros esperados, 0 a investigar) e `runtests.jl` (todos os conjuntos, entre eles 1200 + 120 + 100 + 400 verificações aritméticas, de nomes e de ramos). `test_differential_1000.jl` e `test_pipelines_118.jl` foram **lidos, não reexecutados**.

Observação sobre o papel dos testes: os testes de **concordância** (`break_abt.jl`, `test_differential_1000.jl`) verificam que o interpretador e o código gerado produzem o mesmo resultado; não afirmam que cada resultado seja uma *decisão de projeto*.

## Apêndice C — Reprodução e método

### C.1 Como o professor executa os exemplos

O documento contém **123 exemplos executáveis** (`57` programas que terminam com sucesso, `66` programas inválidos com o diagnóstico exato). Estado atual do registro: `123/123` conferem (`evidencias/verificacao_exemplos.json`).

Requisitos para **executar os exemplos**: a ABT 0.15.0 instalada (ou o repositório clonado) e Julia 1.13.3 `[D install.md]`. Nada mais. Para rodar também o verificador automático: Python 3 (testado com 3.12.3), só biblioteca padrão.

```bash
# um exemplo qualquer (arquivos em exemplos/ID.abt; saída esperada em exemplos/ID.saida ou ID.erro)
abt run exemplos/O06.abt

# todos os exemplos deste documento, conferidos contra a ABT real
python3 tools/verificar_exemplos.py --abt /caminho/ABT-Language/bin/abt
```

O verificador **não interpreta ABT**: grava cada bloco em um arquivo, chama `abt run` (ou `abt check`) e compara a saída padrão (ou o erro, sem o nome do arquivo) com o bloco que o segue. Resultado completo de cada exemplo: `evidencias/verificacao_exemplos.json`.

### C.2 Verificação empírica da EBNF (§7.5)

```bash
python3 tools/verificar_ebnf.py --abt-repo /caminho/ABT-Language
```

Gera programas a partir da EBNF do §7.2 (gerador, **não** interpretador) e os entrega a `tokenize` + `parse_program` originais via `tools/analisar_sintaxe.jl`. Resultado em `evidencias/verificacao_ebnf.json`.

### C.3 Método da auditoria

1. Leitura do código: `tokenize`, `expand_pipelines`, analisador, `evalnode`, `execute_unchecked`, `validate_ir`, diagnósticos e CLI.
2. Leitura da documentação (`grammar.md`, `syntax.md`, `expressions.md`, `control-flow.md`, `semantics.md`, `compiler.md`) e dos testes citados.
3. Sondagem com ~210 programas de teste na ABT real (itens lexicais, sintáticos, numéricos, de controle e de escopo); os que sustentam afirmações viraram os exemplos deste documento.
4. Redação e verificação automática de todos os exemplos.

Um trabalho anterior, fora deste repositório, descrevia uma linguagem diferente (que **não** é a ABT) e serviu apenas de referência metodológica para o verificador de exemplos; nada dele faz parte desta especificação.
