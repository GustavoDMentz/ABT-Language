using Documenter

const IS_CI = get(ENV, "CI", "false") == "true"

makedocs(
    sitename = "ABT — Manual oficial",
    source = "src",
    build = "build",
    clean = true,
    doctest = false,
    checkdocs = :none,
    warnonly = false,
    format = Documenter.HTML(
        prettyurls = IS_CI,
        edit_link = "main",
        repolink = "https://github.com/GustavoDMentz/ABT-Language",
        lang = "pt-BR",
        description = "Manual oficial da linguagem ABT 0.13.0",
        footer = "Gerado com [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).",
        assets = ["assets/abt.css", "assets/abt.js"],
    ),
    pages = [
        "Início" => "index.md",
        "Primeiros passos" => [
            "Visão geral" => "getting-started/overview.md",
            "Instalação e CLI" => "getting-started/install.md",
            "VS Code e diagnósticos" => "getting-started/tooling.md",
        ],
        "Manual" => [
            "Sintaxe e valores" => "manual/syntax.md",
            "Expressões e operadores" => "manual/expressions.md",
            "Controle de fluxo e funções" => "manual/control-flow.md",
            "Coleções e pipelines" => "manual/collections.md",
            "Módulos e interoperabilidade" => "manual/interop.md",
        ],
        "Biblioteca padrão" => [
            "Índice de operações" => "standard-library/index.md",
            "Núcleo, texto e ambiente" => "standard-library/core.md",
            "Arquivos, CSV e tabelas" => "standard-library/tables.md",
            "Estatística e bioestatística" => "standard-library/statistics.md",
            "Dados, JSON e álgebra" => "standard-library/data.md",
            "Bioinformática e visualização" => "standard-library/science.md",
            "Bibliotecas científicas 0.13.0" => "standard-library/scientific0130.md",
        ],
        "Ciência 0.13.0" => "scientific/overview.md",
        "Tutoriais" => [
            "Primeiros passos" => "tutorials/first-program.md",
            "Dados e CSV" => "tutorials/data.md",
            "Estatística" => "tutorials/statistics.md",
            "Bioestatística" => "tutorials/biostatistics.md",
            "Bioinformática" => "tutorials/bioinformatics.md",
            "Visualização" => "tutorials/visualization.md",
            "Bibliotecas Julia" => "tutorials/julia.md",
            "Extensões" => "tutorials/extensions.md",
        ],
        "Exemplos" => "examples/programs.md",
        "Internos e contribuição" => [
            "Arquitetura" => "internals/architecture.md",
            "Compilação e IR" => "internals/compiler.md",
            "Extensões e testes" => "internals/extensions.md",
            "Contribuir" => "contributing/index.md",
        ],
        "Referência formal" => [
            "Gramática" => "reference/grammar.md",
            "Semântica e limites" => "reference/semantics.md",
            "Inventário de recursos" => "reference/inventory.md",
        ],
    ],
)
