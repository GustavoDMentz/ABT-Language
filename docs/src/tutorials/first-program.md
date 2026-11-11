# Tutorial 1 — primeiro programa

**Objetivo:** usar variáveis, expressões, condição, laço e função. **Pré-requisito:** [Julia 1.13.3 e CLI](../getting-started/install.md). Não há dados externos.

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

Execute `bin/abt check primeiro.abt` e `bin/abt run primeiro.abt`. Saída esperada do segundo comando: duas linhas, `4` e `6`. A função é conhecida antes da primeira chamada; `n` percorre a lista em ordem. Uma condição como `se 1 { ... }` é inválida, pois ABT exige booleano. Continue com [expressões](../manual/expressions.md) e [controle de fluxo](../manual/control-flow.md).
