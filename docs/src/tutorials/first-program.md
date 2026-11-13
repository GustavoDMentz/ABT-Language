# Seu primeiro programa ABT

Este percurso reúne variáveis, funções, condições e laços em um programa pequeno. Ao final, você terá um arquivo `.abt` que pode conferir e executar pela CLI.

## Antes de começar

Instale [Julia 1.13.3 e a CLI do ABT](../getting-started/install.md). O exemplo não usa pacotes ou dados externos.

## Escreva o programa

Salve como `primeiro.abt`:

```abt
função dobro(x) {
    retornar x * 2
}
numeros = [1, 2, 3]
para cada n em numeros {
    se n > 1 {
        mostrar dobro(n)
    }
}
```

## Execute e confira

Rode `bin/abt check primeiro.abt` e depois `bin/abt run primeiro.abt`. A saída esperada são duas linhas:

```text
4
6
```

A função `dobro` é conhecida antes da primeira chamada. O laço visita os elementos de `numeros` em ordem; a condição só permite exibir os valores maiores que 1.

## Entenda o contrato

Condições exigem booleanos. Escrever `se 1 { ... }` é inválido: ABT não converte `1` em verdadeiro. A instrução `mostrar` apresenta os valores calculados sem alterar a função.

Continue por [expressões e operadores](../manual/expressions.md), [controle de fluxo](../manual/control-flow.md) ou [coleções e pipelines](../manual/collections.md).
