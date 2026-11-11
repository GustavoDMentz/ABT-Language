# O que é ABT

ABT expressa programas pequenos e operações de dados de maneira declarativa. Julia executa cálculos e fornece bibliotecas consolidadas. A linguagem mantém um interpretador e um gerador Julia que consomem a mesma representação intermediária validada. O objetivo é escrever intenção de alto nível sem inferir silenciosamente esquemas, métodos estatísticos ou políticas científicas.

ABT ainda é experimental. A CLI homologada exige Julia 1.13.3; o projeto não distribui Julia embutida. Funções científicas têm pré-condições explícitas, e chamadas a bibliotecas externas pressupõem código confiável. ABT não é um sandbox.

```abt
medidas = [12, 15, 19, 20]
mostrar descrever(medidas)
```

O resultado é um registro com quantidade, soma, média, mediana, desvio padrão e extremos. `mostrar` apresenta o valor; `descrever` não imprime por conta própria. Veja [sintaxe](../manual/syntax.md) e [estatística](../standard-library/statistics.md).

## Organização

`src/` contém o compilador, runtime e operações; `bin/abt` é a CLI; `applications/` reúne aplicações por domínio; `examples/` contém exemplos curtos; `tests/` e `logs/` guardam validação e evidências; `docs/` contém este site e relatórios históricos. O [guia interno](../internals/architecture.md) descreve o fluxo real.
