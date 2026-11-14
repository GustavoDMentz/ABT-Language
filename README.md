# ABT

ABT 0.13.0 é uma linguagem experimental de alto nível construída sobre Julia. Ela combina sintaxe curta para programas e pipelines com operações explícitas para tabelas, estatística, bioinformática e visualização. PythonCall é opcional; Julia 1.13.3 é o runtime homologado.

```abt
dados = [1, 2, 3, 4, 5]
dados
    filtrar onde valor > 2
    transformar com valor * 10
    limitar a 2
    mostrar
```

Saída: `[30, 40]`.

## Comece aqui

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tools/install.py
~/.local/bin/abt doctor
printf 'mostrar "Olá, mundo!"\n' > ola.abt
~/.local/bin/abt run ola.abt
~/.local/bin/abt check ola.abt
```

O instalador por usuário coloca ABT em `~/.local/share/abt` e cria `~/.local/bin/abt`, sem `sudo`. Sem instalar, use `bin/abt` na raiz do clone. Execute `python3 tools/install.py` novamente para atualizar ou `python3 tools/uninstall.py` para remover. Python 3 é necessário para esses scripts; PythonCall só é necessário para programas que importam Python.

`abt run arquivo.abt` executa; `abt check arquivo.abt` valida sem executar; `abt operacoes` lista as extensões modulares. `abt --help`, `abt --version` e `abt doctor` mostram ajuda, versão e ambiente. A CLI usa `--compile=min` por padrão; `ABT_JULIA_COMPILE=all` permite compilação Julia completa. Erros retornam código 1 e problemas de uso ou ambiente retornam 2.

## Documentação

O [manual desta branch](docs/src/index.md) cobre instalação, sintaxe, operações, tutoriais, arquitetura e [gramática](docs/src/reference/grammar.md). A [referência da biblioteca](docs/src/standard-library/index.md) documenta as 70 operações públicas, e os [programas de referência](docs/src/examples/programs.md) têm fontes executáveis em `docs/examples/`. O site da versão publicada está em `https://gustavodmentz.github.io/ABT-Language/`.

Aplicações completas ficam em [`applications/`](applications/README.md). A [expansão científica 0.13.0](docs/src/scientific/overview.md) reúne as novas operações e seus limites. Para detalhes técnicos históricos, consulte [relatórios e especificações em `docs/`](docs/), incluindo [bioestatística 0.12.0](docs/BIOESTATISTICA_0120.md), [auditoria independente](docs/AUDITORIA_FINAL_BIOESTATISTICA_0120.md), [arquitetura de extensões](docs/ARQUITETURA_EXTENSOES_0118.md), [arquivos e tabelas](docs/ARQUIVOS_TABELAS_0118.md), [bioinformática](docs/BIOINFORMATICA_0118.md), [identidade e CLI](docs/MAPA_IDENTIDADE.md) e [benchmarks](docs/BENCHMARK_ESCALABILIDADE.md).

Os [princípios de abstração](docs/architecture/ABSTRACTION_PRINCIPLES.md) definem a fronteira entre a API ABT e o runtime Julia; a [auditoria de abstração](docs/architecture/ABSTRACTION_AUDIT.md) registra as melhorias implementadas e propostas.

## Desenvolvimento

```bash
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
python3 tools/validate_docs.py
julia --project=docs docs/make.jl
```

Os testes diferenciais e de aplicações ficam em `tests/`; evidências históricas em `logs/`. A extensão mínima de VS Code em `vscode/abt-language` oferece realce lexical, sem LSP. Veja o [guia de contribuição](docs/src/contributing/index.md) para adicionar operações mantendo equivalência entre o interpretador e Julia gerada.
