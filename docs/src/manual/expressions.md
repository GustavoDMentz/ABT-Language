# Expressões e operadores

Da maior para a menor precedência: chamadas/acesso a campos, potência `^`, sinal unário `+`/`-`, multiplicação e divisão `*`/`/`, adição e subtração `+`/`-`, comparações, `e`, `ou`. A potência associa à direita; operadores binários nos demais níveis associam à esquerda. Comparações encadeadas são agrupadas à esquerda, como binárias sucessivas: `a < b < c` é `(a < b) < c`. Como `a < b` é booleano e `<`, `>`, `<=` e `>=` exigem números, a validação rejeita o encadeamento desses quatro operadores; `==` e `!=` aceitam qualquer tipo e podem ser encadeados (`1 == 1 == verdadeiro` vale `true`). Para testar um intervalo, use `e`: `a < b e b < c`.

```abt
a = 2.0
b = 3
mostrar -a ^ b       # -8.0
mostrar (-a) ^ b     # -8.0
mostrar a ^ -b       # 0.125
mostrar a * -b       # -6.0
mostrar (a + b) * 2  # 10.0
```

O sinal unário aceita `Int64` e `Float64`. Potência com base `Int64` e expoente inteiro negativo produz erro de domínio Julia; o exemplo usa base `Float64` explicitamente. Operações inválidas são diagnosticadas pela validação quando o tipo é conhecido ou pela execução Julia quando depende de valor externo. Divisão usa `/` do runtime Julia e pode retornar `Float64`; divisão por zero não recebe um valor de substituição ABT.

Comparações aceitam `>`, `<`, `>=`, `<=`, `==`, `!=` e a forma `é`. `é maior que` e `é menor que` representam `>` e `<`. `e` e `ou` usam curto-circuito: o operando direito só é avaliado quando necessário. Condições devem ser booleanas; um número não é tratado implicitamente como verdade.

```abt
mostrar verdadeiro ou falso
mostrar 3 é maior que 2
```

O acesso a campos aceita `registro.campo` e a forma `campo de registro`. Em módulos externos, as chamadas passam por validação de import e aridade; veja [interoperação](interop.md).
