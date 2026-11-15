```@raw html
<div class="abt-hero">
<p class="abt-eyebrow">Linguagem experimental · versão 0.15.0 · executa sobre Julia 1.13.3</p>
```

# Escreva a intenção. O Julia executa.

ABT é uma linguagem de alto nível, em português, para dados, estatística e bioinformática: sintaxe curta para controle de fluxo, coleções e operações científicas, com contratos explícitos para dados e pacotes.

```@raw html
<div class="abt-cta">
```

[Começar a trilha →](trilha.md)
[Instalar a ABT](getting-started/install.md)
[Ver a sintaxe](manual/syntax.md)

```@raw html
</div>
<div class="abt-demo">
```

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

```text
[30, 40]
```

```@raw html
</div>
<ul class="abt-stats">
  <li><strong>84</strong>operações públicas</li>
  <li><strong>PT-BR</strong>palavras-chave em português</li>
  <li><strong>2</strong>caminhos de execução equivalentes</li>
  <li><strong>Julia</strong>por baixo, sem importar nada</li>
</ul>
</div>
```

Salve o exemplo em `primeiro.abt` e execute `bin/abt run primeiro.abt` a partir da raiz do repositório.

## Por que ABT

```@raw html
<div class="abt-cards">
```

- [Fala português](manual/syntax.md)

  Palavras-chave como `mostrar`, `se`, `para cada`, `função` e `filtrar … onde`, com aliases em inglês quando existem.

- [Pipelines legíveis](manual/collections.md)

  Encadeie `filtrar`, `transformar` e `limitar` por indentação, terminando em `mostrar`.

- [Ciência incluída](standard-library/index.md)

  CSV tipado, estatística, bioestatística, FASTA/FASTQ, alinhamento, álgebra linear e gráficos, sem importar nada.

- [Rigor explícito](reference/semantics.md)

  Esquemas e políticas de valores ausentes são declarados; nada é convertido em silêncio.

- [Julia por baixo](internals/architecture.md)

  Interpretador e gerador de código Julia consomem a mesma representação intermediária e dão resultados equivalentes.

- [Exemplos verificados](examples/programs.md)

  Os programas do manual são executados por `tools/validate_docs.py`, para que a documentação não se afaste da implementação.

```@raw html
</div>
```

## Como você vai aprender

A [trilha de aprendizado](trilha.md) leva da instalação até a análise de dados em sete etapas curtas. Cada lição tem um ponto de verificação e o seu progresso fica salvo neste navegador.

```@raw html
<div class="abt-cards abt-cards-compact abt-numbered">
```

- [Instale e rode](getting-started/install.md)

  Julia 1.13.3, a CLI e o comando `abt`.

- [Escreva o primeiro programa](tutorials/first-program.md)

  Variáveis, condição, laço e função.

- [Domine a sintaxe](manual/syntax.md)

  Valores, nomes, operadores e blocos.

- [Trabalhe com dados](tutorials/data.md)

  CSV tipado, esquema e relatório em JSON.

```@raw html
</div>
```

## Um programa de verdade

Uma função, um laço e duas agregações. As agregações `media de` e `soma de … onde` leem a lista inteira; `valor` é o elemento corrente dentro do filtro.

```abt
função situacao(nota) {
    se nota >= 7 {
        retornar "aprovado"
    } senao {
        retornar "recuperação"
    }
}

notas = [9.5, 6.0, 7.5, 4.0, 8.0]
para cada n em notas {
    mostrar situacao(n)
}
mostrar media de notas
mostrar soma de notas onde valor >= 7
```

```text
aprovado
recuperação
aprovado
recuperação
aprovado
7.0
25.0
```

## Escolha seu caminho

```@raw html
<div class="abt-cards abt-cards-compact">
```

- [Instalar e executar](getting-started/install.md)

  Julia 1.13.3, CLI e primeiro programa.

- [Aprender a linguagem](manual/syntax.md)

  Sintaxe, valores, funções, coleções e imports.

- [Consultar operações](standard-library/index.md)

  Índice das 84 operações públicas e seus contratos.

- [Seguir tutoriais](tutorials/first-program.md)

  Programas completos com dados sintéticos.

- [Entender a implementação](internals/architecture.md)

  Lexer, AST, IR, interpretador e geração Julia.

- [Ler a referência formal](reference/grammar.md)

  Gramática baseada no parser e limites da versão.

```@raw html
</div>
```

!!! note "Estado do projeto"
    ABT é experimental. A CLI homologada exige Julia 1.13.3, e PythonCall é uma ponte opcional. Os exemplos deste site são verificados por `python3 tools/validate_docs.py`; o [inventário](reference/inventory.md) distingue o que funciona do que ainda é limitado.
