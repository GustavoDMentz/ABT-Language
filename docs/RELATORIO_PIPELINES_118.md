# ABT 0.11.8 — relatório de pipelines declarativos

## Decisão e implementação

A gramática anterior descartava quebras de linha e usava chaves para blocos. Por isso, o reconhecimento foi limitado a uma expressão completa isolada em uma linha, seguida por linhas recuadas de etapas. A primeira etapa fixa a coluna de todas as demais. `mostrar` sem argumento é obrigatório e terminal. Recuo inconsistente, etapa desconhecida, expressão incompleta e tabulação no recuo geram erro com posição. A especificação detalhada está em `ESPECIFICACAO_PIPELINES_118.md`.

O lexer reconhece esse padrão e o converte em uma única declaração `mostrar` composta por `filtrar`, `transformar` e `limitar` existentes. AST, IR, validação, otimização, interpretador e gerador permanecem os mesmos. Isso preserva contratos de tipo, ordem de efeitos, escopo de `valor` e exceções. A apresentação de erro de pipeline foi associada ao diagnóstico sintático E010. Não foram adicionadas dependências.

## Validação efetivamente executada

Ambiente: Ubuntu, Julia 1.13.3 local, PythonCall opcional disponível via `.julia_depot`, Python `/usr/bin/python3`.

Comando integral, a partir da raiz deste projeto:

```sh
ABT_REQUIRE_PYTHON=1 JULIA_DEPOT_PATH="$PWD/.julia_depot" JULIA_PYTHONCALL_EXE=/usr/bin/python3 python3 tests/run_all_tests.py --julia /home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia --timeout 180
```

Resultado: **36 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. Os 36 incluem os testes históricos, estáticos, legados (`tests/runtests_legacy.jl` via `tests/runtests.jl`), interoperabilidade Python/Julia, 1.000 casos diferenciais anteriores, 335 verificações de coleções 0.11.7 e a nova suíte de pipelines. Esta nova suíte executou 9 casos diferenciais dirigidos, 100 casos determinísticos com semente `0xAB7118` e 7 testes de diagnóstico. O harness diferencial compara interpretador, Julia gerado sem otimização e com otimização, inclusive saídas e erros. Resultados estruturados e logs por arquivo: `logs/test_logs/summary.json` e `logs/test_logs/*.log`.

Exemplos executados pela CLI:

```sh
julia pseudo.jl examples/pipeline_basico.abt
# [30, 40]
julia pseudo.jl examples/pipeline_efeitos.abt
# 1, 2, 3, [2, 4, 6], cada item em uma linha
```

Os resultados observados estão em `logs/historical/pipeline_cli.log`.

## Divergências, correções e limites

Nenhuma divergência entre os três modos foi encontrada nos casos executados. A implementação não alterou a semântica das operações 0.11.7; adicionou apenas o reconhecimento rigoroso da nova forma. Uma primeira versão do teste tentou atribuir a `valor`, palavra reservada já na gramática anterior; o teste foi corrigido para usar `x`, sem mudança no compilador.

As duas sondas exploratórias não são declaração de aprovação: `tests/break_abt.jl` e `tests/audit_adversarial.jl`. A última ainda registra comportamento dinâmico da interoperabilidade Python e uso de `os.system`, coerentes com o limite de confiança declarado anteriormente: ABT não é sandbox. Nenhum teste foi ignorado. O formato indentado não abrange atribuição de resultado, expressões multilinha, tabulações ou chaves na linha terminal; esses casos estão explicitamente fora da gramática 0.11.8. Não se extrapola a equivalência testada para todos os programas possíveis.
