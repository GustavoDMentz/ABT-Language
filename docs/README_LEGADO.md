## ABT 0.11.8: pipelines por indentação

### Fundação opcional de pacotes Julia

O arquivo `ABT.packages.toml` declara módulos Julia adicionais por nome exato, UUID, versão e funções com aridade fixa. O ABT só carrega o módulo ao executar `usar Julia.Nome`; a instalação e a resolução de dependências continuam a cargo do ambiente Julia. O exemplo `examples/pacote_dates.abt` usa `Dates`, da biblioteca padrão. Consulte `ARQUITETURA_PACOTES_FUNDACAO.md` para a gramática, os contratos, os testes e os limites desta fatia incremental.

Exemplo: `julia pseudo.jl examples/pipeline_basico.abt` imprime `[30, 40]`. Etapas disponíveis: `filtrar onde`, `transformar com`, `limitar a`; `mostrar` encerra o pipeline. Consulte `ESPECIFICACAO_PIPELINES_118.md`.

# ABT — linguagem experimental sobre Julia

## Coleções declarativas (0.11.7)

ABT agora oferece três expressões composicionais: `filtrar coleção onde predicado`, `transformar coleção com expressão` e `limitar coleção a quantidade`. `valor` (ou `value`) representa o elemento atual nas duas primeiras operações. Use parênteses para compor:

```abt
dados = [1, 2, 3, 4, 5]
mostrar limitar (transformar (filtrar dados onde valor > 2) com valor * 10) a 2
```

Saída: `[30, 40]`. A gramática e os contratos de tipos, ordem, vazios e erros estão em `ESPECIFICACAO_COLECOES_117.md`. Exemplos executáveis estão em `examples/colecoes_*.abt`.

```sh
julia pseudo.jl examples/colecoes_pipeline.abt
python3 run_cli_examples.py --julia julia
julia test_collections_117.jl
```

## Histórico da ponte Python (0.9.2)

A ponte é compartilhada em `bridge_runtime.jl` pelo interpretador e pelo gerador (embutida no Julia emitido). Importações são publicadas somente após `pyimport` bem-sucedido, módulos e submódulos coexistem, chamadas Python passam por diagnóstico contextual, e atributos privados são rejeitados também em runtime.

**Atenção:** executar módulos Python continua sendo execução de código com privilégios do processo, NÃO uma sandbox. A política de `_` é apenas uma restrição de API, não uma barreira de segurança. Tipos e efeitos ainda não são verificados estaticamente.

## Testes

```sh
julia test_bridge_092.jl
julia test_python_bridge.jl
julia test_regression_091.jl
julia test_interop_extended.jl
julia test_interop.jl
julia runtests.jl
julia break_abt.jl
```

Para testes obrigatórios: `ABT_REQUIRE_PYTHON=1 julia test_bridge_092.jl` após instalar PythonCall e NumPy. A suíte antiga ainda pode pular testes opcionais.

## Revisão 0.9.3

Veja `STATIC_REVIEW_093.md`; execute `julia test_static_093.jl` antes das demais suítes.


ABT 0.10.4: ver STATIC_REVIEW_104.md; testes de Julia ainda não executados.

### Contrato da 0.10.8
`execute(...; env=...)` não modifica o dicionário recebido, mas pode acrescentar saídas ao vetor `output` passado. Chaves `__abt_*` no ambiente inicial são reservadas. `generate(...)` só suporta programas autocontidos (sem valores externos injetados). O bridge gerado ainda é uma implementação própria e requer regressões diferenciais; consulte `STATIC_REVIEW_108.md`.


### Revisão 0.11.3
Veja `STATIC_REVIEW_113.md` e execute `julia test_static_113.jl` para verificar o limite `initial_names`.
