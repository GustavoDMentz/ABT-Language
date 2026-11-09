# ABT 0.11.6 — revisão integral do acervo de testes

## Escopo e método
Foram inspecionados **35 arquivos** de testes/sondas (`tests/runtests.jl`, `tests/runtests_legacy.jl`, `tests/break_abt.jl`, `tests/audit_adversarial.jl` e os 31 arquivos `test_*.jl`) do pacote `abt_v116_active_test_fixes.zip`. Análise de código estática e confronto com `pseudo.jl`/`bridge_runtime.jl`; **Julia não disponível neste ambiente**, portanto não se afirma que os arquivos foram executados aqui. Os logs enviados pelo usuário comprovam execução parcial no Julia 1.13.3. `tests/runtests_legacy.jl` é incluído por `tests/runtests.jl`, não deve ser executado sozinho.

## Problemas prioritários, com evidências

1. **Suíte incompleta**: `tests/runtests.jl` inclui apenas `tests/runtests_legacy.jl` e seus próprios `@testset`; não inclui `test_static_093..116.jl`, `test_interop*.jl`, `tests/test_bridge_092.jl`, etc. Não há garantia de execução integral. Novo `tests/run_all_tests.py` executa cada script em processo Julia isolado e salva logs.
2. **Falha confirmada em execução**: `tests/runtests.jl:125` exige `function soma(`, mas o compilador produz `function __abt_user_736f6d61(`. Teste acoplado à forma antiga dos identificadores. Substituir por teste de comportamento e, se útil, assertiva sobre prefixo de nome mangled.
3. **Expectativas historicamente obsoletas**: `tests/test_static_099.jl` exige `@eval import PythonCall`; `tests/test_static_101.jl` exige `@eval import Statistics`; `tests/test_python_bridge.jl` exige `PythonCall.pyimport`; `tests/test_static_093.jl` exige `struct ABTPythonNamespace` e `import PythonCall` no código gerado. O gerador atual usa `abt_load_pythoncall!` e `Base.require(Base.PkgId...)`; revisar cada expectativa conforme contrato atual.
4. **Interop Julia desatualizada**: `tests/test_interop.jl` e `tests/test_interop_extended.jl` exigem `import Statistics`, `import LinearAlgebra`, `Statistics.mean(dados)` e `Base.sort(numeros)` literalmente; a geração atual usa identificadores codificados e carregamento via `Base.require`. O resultado funcional, e não o texto, deve ser o oráculo principal.
5. **Teste adversarial não é oráculo de aprovação**: `tests/audit_adversarial.jl` imprime `FINDING` mas pode encerrar com código zero. Deve permanecer marcado como *probe*, não contado como PASS sem analisar findings. `tests/break_abt.jl` também imprime resumos; verificar seu código de saída e sua cobertura antes de tratá-lo como gate de CI.
6. **Baixa sensibilidade semântica**: em `tests/runtests.jl`, 600 casos aritméticos verificam o interpretador e apenas `occursin("println(", code)` no compilador; 200 casos de otimização verificam texto gerado, não o executam. Uma regressão no código gerado pode passar.
7. **Erros amplos**: diversos `@test_throws Exception` aceitam erros internos (`MethodError`, `BoundsError`) quando se espera erro semântico controlado. Testar categoria e fragmento da mensagem nos pontos críticos.
8. **Testes de texto de implementação**: vários `test_static_*.jl` validam substrings específicas (`cache[]`, `@eval`, `struct`, `let`, nomes de helpers) em vez de propriedades observáveis. Manter apenas quando o detalhe for contrato de segurança explícito, e atualizar junto com a arquitetura.
9. **Dependências opcionais**: `tests/test_python_bridge.jl` usa `@test_skip` se PythonCall/NumPy não estiverem disponíveis; a suíte deve reportar explicitamente o que foi ignorado, sem tratar ausência de Python como aprovação de interoperabilidade.
10. **Risco de ambiente compartilhado**: scripts incluem `pseudo.jl` e definem funções/constantes globais. Rodar todos com `include` no mesmo processo pode criar conflitos de definições e efeitos de estado. O runner proposto isola processos.
11. **Testes estruturais específicos**: `test_static_109..116.jl` têm regressões relevantes de IR malformado, ciclos, limites e validação; manter e acrescentar casos que garantam que entradas normais ainda funcionam, sem somente rejeições.
12. **Teste de parsing do gerador**: `tests/test_static_110.jl` usa `Meta.parse(generated)`; isso detecta sintaxe inválida, mas não executa o código e não cobre todos os caminhos. Acrescentar um smoke test que avalie código gerado sem Python, em módulo isolado.

## Inventário por família (todos os arquivos)

| Arquivos | Papel | Parecer |
|---|---|---|
| `tests/runtests.jl`, `tests/runtests_legacy.jl` | Baseline, aritmética, linguagem, funções, diagnósticos | Atualizar oráculos textuais; executar código gerado; falha conhecida na linha 125 |
| `tests/break_abt.jl`, `tests/audit_adversarial.jl` | Comparação adversarial e sondas | Preservar; não confundir impressões com assertions de CI |
| `tests/test_interop.jl`, `tests/test_interop_extended.jl` | Julia Statistics, LinearAlgebra, Base | Strings de importação/nomes obsoletas |
| `tests/test_python_bridge.jl`, `tests/test_bridge_092.jl` | Python opcional e resolução de namespaces | Reavaliar gerador e dependências; manter resolução do bridge |
| `tests/test_regression_091.jl`, `tests/test_adversarial_093.jl`, `tests/test_diagnostics.jl` | Regressões antigas, chamadas, mensagens | Preservar; checar oráculos e erros |
| `tests/test_static_093.jl`, `tests/test_static_094.jl`, `tests/test_static_095.jl` | Callables, nomes, função main | 093 tem expectativas obsoletas; 094/095 checar estabilidade |
| `tests/test_static_096.jl`, `tests/test_static_097.jl`, `tests/test_static_098.jl` | Escopo, captura, namespace | Manter como contratos semânticos |
| `tests/test_static_099.jl`, `tests/test_static_100.jl`, `tests/test_static_101.jl` | Isolamento, namespace, importação | 099/101 obsoletos; 100 acoplado à representação |
| `tests/test_static_102.jl`, `tests/test_static_103.jl`, `tests/test_static_104.jl` | Precedência de namespace, importação Julia/Python | Revalidar strings internas, preservar comportamento |
| `tests/test_static_105.jl`, `tests/test_static_106.jl`, `tests/test_static_107.jl` | Loader lazy Python e erros | Testes de implementação; verificar API atual |
| `tests/test_static_108.jl`, `tests/test_static_109.jl`, `tests/test_static_110.jl` | Privacidade, IR validado, literais/parse | Importantes; acrescentar testes executáveis |
| `tests/test_static_111.jl`, `tests/test_static_112.jl`, `tests/test_static_113.jl` | IR malformado, otimizador, initial_names | Importantes; checar classes de erro |
| `tests/test_static_114.jl`, `tests/test_static_115.jl`, `tests/test_static_116.jl` | Ciclos, tipos de vetores, orçamento | Manter; ampliar limites e casos válidos |

## Próximo plano de correção

1. Rodar `python3 tests/run_all_tests.py` no Ubuntu do usuário, dentro da pasta extraída, e receber `logs/test_logs/summary.json` + logs das falhas.
2. Corrigir primeiro testes obsoletos **sem enfraquecer as garantias**; evitar trocar assertions úteis por `@test true`.
3. Criar helpers comuns para comparar `execute(ast)` com `include_string` do código Julia gerado, capturando `stdout` e exceções, em ambiente isolado.
4. Separar os gates em `core`, `interop-julia`, `interop-python-optional`, `adversarial` e `static-internals`.
5. Tornar obrigatórios testes de parsing e execução do código gerado após mudanças nos templates Julia (evitaria o erro de `$` que bloqueou a 0.11.6).

**Status:** inventário e auditoria estática realizados; **não** é certificação de 35 testes aprovados nem correção automática de todos eles.
