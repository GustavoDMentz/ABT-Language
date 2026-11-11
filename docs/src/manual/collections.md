# Listas, agregações e pipelines

Listas são valores ordenados. As formas contextuais `filtrar`, `transformar` e `limitar` operam sobre listas. `valor` é o elemento corrente apenas dentro da expressão de filtro ou transformação. `filtrar` exige predicado booleano; `limitar` exige `Int64` não negativo.

```abt
dados = [1, 2, 3, 4]
pares = filtrar dados onde valor > 2
dobrados = transformar pares com valor * 2
mostrar limitar dobrados a 1
mostrar soma de dados onde valor > 2
mostrar media de dados
```

Saídas: `[6]`, `7`, `2.5`. A seleção vazia em `media de ...` é erro; `soma de ...` retorna zero. Expressões de agregação avaliam elementos em ordem, sem reordenar efeitos.

Um pipeline por indentação começa quando uma linha que, sozinha, é expressão completa é seguida de uma linha mais recuada. Todas as etapas usam a mesma coluna; tabs de indentação são rejeitados. Etapas válidas são `filtrar onde expressão`, `transformar com expressão` e `limitar a expressão`. O pipeline precisa terminar com `mostrar` isolado nessa mesma coluna. A expansão lexical produz as mesmas operações de coleção; não existe um segundo executor.

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

Saída: `[30, 40]`. Uma etapa desconhecida, indentação inconsistente ou término sem `mostrar` gera diagnóstico de pipeline com linha e coluna. `mostrar` é terminal: não recebe argumento nessa forma. A expressão de origem é avaliada uma vez e as etapas mantêm a ordem textual. Veja a [gramática](../reference/grammar.md).
