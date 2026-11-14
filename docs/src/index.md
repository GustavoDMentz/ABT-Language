# ABT — manual oficial

ABT 0.14.0 é uma linguagem experimental de alto nível executada sobre Julia. Ela oferece sintaxe curta para controle de fluxo, coleções e operações científicas, com contratos explícitos para dados e pacotes. PythonCall é uma ponte opcional. Esta branch documenta a versão candidata 0.13.0; a publicação depende de revisão e integração da PR.

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

Saída: `[30, 40]`. Salve o exemplo em `primeiro.abt` e execute `bin/abt run primeiro.abt` a partir da raiz do repositório.

## Percursos

- [Instalar e executar](getting-started/install.md): Julia 1.13.3, CLI e primeiro programa.
- [Aprender a linguagem](manual/syntax.md): sintaxe, valores, funções, coleções e imports.
- [Consultar operações](standard-library/index.md): índice das operações públicas e seus contratos.
- [Seguir tutoriais](tutorials/first-program.md): programas completos com dados sintéticos.
- [Entender a implementação](internals/architecture.md): lexer, AST, IR, interpretador e geração Julia.
- [Ler a referência formal](reference/grammar.md): gramática baseada no parser e limites da versão.

Os exemplos do site são verificados por `python3 tools/validate_docs.py`; o [inventário](reference/inventory.md) distingue o que funciona do que ainda é limitado.
