# Aprenda ABT. Consulte com confiança.

ABT 0.13.0 é uma linguagem experimental de alto nível sobre Julia. Ela reúne programas claros, dados com contratos explícitos e bibliotecas científicas em uma mesma experiência de aprendizado. PythonCall oferece interoperabilidade opcional.

```@raw html
<div class="abt-home-search" role="search" aria-label="Buscar na documentação"><span class="abt-home-search-icon" aria-hidden="true">⌕</span><button type="button" class="abt-search-trigger" aria-label="Buscar conceitos, funções e exemplos">Buscar conceitos, operações e exemplos <span class="abt-shortcut">Ctrl /</span></button></div>
```

```@raw html
<div class="abt-home-actions"><a class="abt-button abt-button-primary" href="getting-started/install.html">Instalar ABT</a><a class="abt-button abt-button-secondary" href="tutorials/first-program.html">Escrever o primeiro programa</a></div>
```

## Comece a aprender

Escolha um percurso e avance dos primeiros comandos até aplicações completas. Cada tutorial aponta para a referência técnica correspondente.

```@raw html
<div class="abt-card-grid abt-card-grid-three"><a class="abt-card" href="getting-started/overview.html"><span class="abt-card-kicker">01 · Introdução</span><strong>Entenda a linguagem</strong><span>O que ABT faz, como usa Julia e onde estão seus limites.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a><a class="abt-card" href="tutorials/first-program.html"><span class="abt-card-kicker">02 · Prática</span><strong>Seu primeiro programa</strong><span>Variáveis, funções, condições e laços em um exemplo executável.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a><a class="abt-card" href="manual/collections.html"><span class="abt-card-kicker">03 · Composição</span><strong>Coleções e pipelines</strong><span>Transforme dados com etapas declarativas e ordem explícita.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a></div>
```

## ABT em poucas linhas

Um pipeline filtra, transforma e limita uma coleção. A etapa `mostrar` apresenta o resultado.

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

```@raw html
<div class="abt-example-output"><span>Saída esperada</span><code>[30, 40]</code></div>
```

Salve como `primeiro.abt` e execute `bin/abt run primeiro.abt` na raiz do projeto. Veja a [semântica dos pipelines](manual/collections.md) antes de compor etapas maiores.

## Explore por assunto

```@raw html
<div class="abt-topic-grid"><a href="manual/syntax.html"><strong>Sintaxe</strong><span>Valores, nomes e estrutura</span></a><a href="manual/control-flow.html"><strong>Funções e controle</strong><span>Condições, laços e escopo</span></a><a href="standard-library/tables.html"><strong>Dados e tabelas</strong><span>CSV, esquemas e operações</span></a><a href="standard-library/statistics.html"><strong>Estatística</strong><span>Resumos e testes</span></a><a href="standard-library/science.html"><strong>Bioinformática</strong><span>Sequências e análise</span></a><a href="standard-library/data.html"><strong>Álgebra e JSON</strong><span>Cálculo e intercâmbio</span></a></div>
```

## Bibliotecas e aplicações

```@raw html
<div class="abt-card-grid abt-card-grid-two"><a class="abt-card" href="standard-library/index.html"><span class="abt-card-kicker">Referência</span><strong>Biblioteca padrão</strong><span>Índice das operações públicas, assinaturas, contratos e limites.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a><a class="abt-card" href="standard-library/scientific0130.html"><span class="abt-card-kicker">ABT 0.13.0</span><strong>Operações científicas</strong><span>FASTQ, tabelas, estatística, álgebra linear e otimização.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a><a class="abt-card" href="tutorials/data.html"><span class="abt-card-kicker">Aplicação · Dados</span><strong>Analise um CSV</strong><span>Leia com esquema explícito, filtre e produza resultados reutilizáveis.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a><a class="abt-card" href="tutorials/bioinformatics.html"><span class="abt-card-kicker">Aplicação · Ciência</span><strong>Explore sequências</strong><span>Do arquivo FASTA a estatísticas biológicas verificáveis.</span><span class="abt-card-arrow" aria-hidden="true">→</span></a></div>
```

## Em destaque

- [Programas completos](examples/programs.md): fontes ABT que acompanham o projeto e são validadas automaticamente.
- [Ciência no ABT 0.13.0](scientific/overview.md): novas capacidades e aplicações de referência.
- [Gramática e semântica](reference/grammar.md): regras formais, diagnósticos e limitações.
- [Arquitetura](internals/architecture.md): como lexer, IR, interpretador e Julia gerada se relacionam.

ABT ainda é experimental. A [referência de limites](reference/inventory.md) distingue recursos implementados de propostas. Os exemplos deste portal são verificados por `python3 tools/validate_docs.py`.
