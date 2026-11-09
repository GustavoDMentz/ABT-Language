# ABT 0.9.1 — correções da auditoria

- Corrigido: namespace aninhado via `abt_import_python!` tanto no interpretador como no gerador.
- Corrigido: referência a função Python armazenada em variável e chamada posterior.
- Corrigido: método em objeto Python armazenado em variável, com propagação de tipo externo.
- Corrigido: reatribuição de `Python` e `Julia`, incluindo parâmetros, funções e variáveis de loop.
- Corrigido: importações dentro de estruturas aninhadas rejeitadas para evitar escopo divergente.
- Acrescentado: testes estáticos e diferenciais opcionais em `test_regression_091.jl`.
- **Não corrigido**: isolamento de execução arbitrária de bibliotecas Python, inspeção de efeitos de imports, validação dinâmica de assinaturas/tipos, diagnóstico unificado de exceções externas. Não alegar segurança de sandbox.
- **Não executado**: Julia indisponível no ambiente de autoria; requer execução da suíte no host.
