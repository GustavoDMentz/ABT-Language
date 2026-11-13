```@raw html
<div class="abt-home-eyebrow">A linguagem ABT · documentação 0.13.0</div>
```

# Programas claros. Semântica precisa.

ABT é uma linguagem experimental de alto nível construída sobre Julia. Escreva programas, componha operações sobre dados e use bibliotecas científicas com contratos explícitos. PythonCall oferece interoperabilidade opcional.

```@raw html
<div class="abt-home-actions"><a class="abt-button abt-button-primary" href="getting-started/overview.html">Explorar a documentação <span aria-hidden="true">→</span></a><a class="abt-button abt-button-secondary" href="getting-started/install.html">Instalar ABT <span aria-hidden="true">↗</span></a></div>
<span class="abt-home-rule" aria-hidden="true"></span><span class="abt-home-section-label">A linguagem em ação</span>
```

## Uma ideia, poucas etapas.

Um pipeline filtra, transforma e limita uma coleção. A etapa `mostrar` apresenta o resultado. A ordem das etapas é preservada.

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

```@raw html
<div class="abt-example-output"><span>Saída</span><code>[30, 40]</code></div>
```

Salve como `primeiro.abt` e execute `bin/abt run primeiro.abt` na raiz do projeto. Consulte a [semântica dos pipelines](manual/collections.md) para conhecer suas regras de indentação e escopo.

```@raw html
<span class="abt-home-rule" aria-hidden="true"></span><span class="abt-home-section-label">Encontre seu caminho</span>
```

## Do primeiro programa à referência.

```@raw html
<div class="abt-link-grid">
<a class="abt-link-row" href="tutorials/first-program.html"><span><strong>Primeiro programa</strong><small>Variáveis, funções, condições e laços.</small></span><span aria-hidden="true">↗</span></a>
<a class="abt-link-row" href="manual/syntax.html"><span><strong>Manual da linguagem</strong><small>Sintaxe, valores, expressões e coleções.</small></span><span aria-hidden="true">↗</span></a>
<a class="abt-link-row" href="standard-library/index.html"><span><strong>Biblioteca padrão</strong><small>Operações públicas e contratos de uso.</small></span><span aria-hidden="true">↗</span></a>
<a class="abt-link-row" href="examples/programs.html"><span><strong>Programas completos</strong><small>Exemplos ABT executáveis do projeto.</small></span><span aria-hidden="true">↗</span></a>
<a class="abt-link-row" href="scientific/overview.html"><span><strong>Aplicações científicas</strong><small>Dados, estatística e bioinformática.</small></span><span aria-hidden="true">↗</span></a>
<a class="abt-link-row" href="reference/grammar.html"><span><strong>Referência formal</strong><small>Gramática, semântica e limites.</small></span><span aria-hidden="true">↗</span></a>
</div>
```

```@raw html
<p class="abt-home-note">ABT ainda é experimental. A <a href="reference/inventory.html">referência de recursos</a> distingue o que está implementado do que permanece em estudo. Os exemplos deste portal são verificados por <code>tools/validate_docs.py</code>.</p>
```
