# Tutorial 8 — adicionar uma operação ABT

**Objetivo:** estender a biblioteca mantendo interpretador e Julia gerada equivalentes. **Pré-requisito:** familiaridade com Julia e com o [registro modular](../internals/extensions.md). Não é um exemplo de nova sintaxe ABT: exige alteração do código-fonte em uma branch própria.

1. Defina a assinatura, domínios válidos, resultado estruturado, ausentes, erros e dependência.
2. Implemente a função em um arquivo `src/Stdlib*.jl` compartilhável pelos dois modos. Carregue pacotes externos apenas na chamada, se necessário.
3. Adicione uma entrada em `ABT_EXTENSION_SPECS` em `src/ExtensionRegistry.jl`, com `arity`, `static_args`, `implementation`, `generated`, `source` e contratos.
4. Acrescente um programa ABT em `tests/` que invoque a operação; compare interpretador, Julia gerada sem otimização e otimizada.
5. Rode `python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180` e o validador desta documentação.

`resumo_estatistico` em `src/StdlibBiostatistics.jl` e sua entrada no registro fornecem um caso concreto: recebe lista numérica, devolve registro e é chamada pelo mesmo nome nos três modos. Um exemplo executável está em [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica). Veja [fluxo do compilador](../internals/compiler.md) antes de alterar o IR.
