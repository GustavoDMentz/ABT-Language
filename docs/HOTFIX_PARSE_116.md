# ABT 0.11.6 — hotfix de parsing (2026-11-05)

## Erro reproduzido pelo usuário

`ParseError` em `pseudo.jl:980` antes de iniciar os testes.

## Correção

Escapado o `$` final da expressão regular dentro da string geradora de código Julia. Antes: `...*)*$\", path)`; depois: `...*)*\$\", path)`. O `$` continua presente na expressão regular gerada como âncora de fim, mas deixa de ser interpretado como interpolação no código-fonte do gerador.

## Validação

Revisão textual e teste de integridade do ZIP. Julia não está disponível neste ambiente, portanto nenhuma execução dinâmica foi realizada aqui. Execute `julia tests/test_static_116.jl`, `julia tests/runtests.jl`, `julia tests/break_abt.jl`.
