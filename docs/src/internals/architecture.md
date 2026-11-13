# Como a ABT é construída

O mesmo programa ABT pode ser interpretado ou convertido em Julia. As duas rotas passam por uma representação intermediária validada e compartilham as operações da biblioteca. O diagrama resume esse fluxo sem ocultar as dependências do runtime.

## Fluxo de um programa

```@raw html
<figure class="abt-flow" aria-label="Fluxo da fonte ABT até os runtimes">
  <ol>
    <li><span>Fonte</span><strong>Arquivo .abt</strong></li>
    <li><span>Análise</span><strong>Tokens → AST</strong><small>Inclui expansão de pipelines</small></li>
    <li><span>Verificação</span><strong>IR validado</strong><small>Estrutura e contratos semânticos</small></li>
    <li><span>Execução</span><strong>Interpretador ou Julia gerada</strong><small>Otimização conservadora opcional</small></li>
    <li><span>Bibliotecas</span><strong>Stdlib e extensões</strong><small>Julia; PythonCall quando importado</small></li>
  </ol>
  <figcaption>As duas rotas de execução usam a mesma representação validada e as mesmas operações registradas.</figcaption>
</figure>
```

## Onde estão os componentes

O arquivo `src/ABT.jl` contém lexer, parser, AST, IR, validador, interpretador, otimizador e gerador. `src/CLI.jl` é a interface pública chamada por `bin/abt`. `src/Runtime/Bridge.jl` medeia módulos externos. `src/Stdlib*.jl` implementa operações compartilhadas e `src/ExtensionRegistry.jl` registra as modulares. `Project.toml`/`Manifest.toml` definem o ambiente Julia; `ABT.packages.toml` restringe a superfície de chamadas Julia explícitas em programas ABT.

## Execução e apresentação

`src/StdlibRender.jl` apresenta registros, listas, tabelas e FASTA. `mostrar` não altera os dados. O gerador incorpora apenas implementações das operações usadas, evitando carregar pacotes opcionais na inicialização. A ponte PythonCall é carregada apenas quando há import Python.

O repositório separa `applications/`, `examples/`, `tests/`, `benchmarks/`, `docs/`, `logs/`, `tools/`, `bin/` e `vscode/`. `pseudo.jl` e `bridge_runtime.jl` preservam compatibilidade com ferramentas históricas. Os relatórios técnicos antigos permanecem na raiz de `docs/` como evidência, enquanto o site usa `docs/src/`.

## Continue a leitura

Veja [compilador e IR](compiler.md) para validação e geração, [módulos e interoperabilidade](../manual/interop.md) para os limites das pontes e [referência formal](../reference/grammar.md) para a sintaxe aceita.
