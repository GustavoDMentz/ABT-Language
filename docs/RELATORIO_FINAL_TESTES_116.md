# ABT 0.11.6 — revisão integral dos testes

## Resultado verificado

Julia 1.13.3, PythonCall 0.9.37 e NumPy 2.5.1. A execução final de `tests/run_all_tests.py` iniciou **34 processos Julia**: 31 arquivos `test_*.jl`, `tests/runtests.jl`, `tests/break_abt.jl` e `tests/audit_adversarial.jl`. Resultado: **34 PASS, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. `tests/runtests_legacy.jl` foi executado por inclusão em `tests/runtests.jl`, totalizando 35 arquivos de testes/sondas cobertos. Nenhum teste foi marcado como `Broken`/ignorado na última rodada. As saídas de cada processo e o resumo estruturado estão em `logs/test_logs/`.

`tests/break_abt.jl` e `tests/audit_adversarial.jl` são sondas exploratórias: código de saída zero confirma a execução, não a ausência de problemas. A última registrou dois `FINDING`, detalhados abaixo.

## Ambiente e comandos

O launcher `~/.juliaup/bin/julia` não conseguiu criar seu lockfile neste ambiente. Foi usado diretamente `/home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia`. `Statistics` e `LinearAlgebra` vêm da biblioteca padrão. Somente `PythonCall` foi instalado como pacote Julia adicional, em `.julia_depot/` isolado. PythonCall usou `/usr/bin/python3`, onde NumPy já estava disponível.

Instalação: `JULIA_DEPOT_PATH=$PWD/.julia_depot /home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia --startup-file=no -e 'using Pkg; Pkg.add("PythonCall")'`

Execução final, a partir desta pasta:

```sh
ABT_REQUIRE_PYTHON=1 \
JULIA_DEPOT_PATH="$PWD/.julia_depot" \
JULIA_PYTHONCALL_EXE=/usr/bin/python3 \
python3 tests/run_all_tests.py \
  --julia /home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia \
  --timeout 180
```

A primeira execução, antes das correções, teve **20 PASS e 14 FAIL**; os logs estão em `logs/test_logs_baseline/`. Os testes afetados foram repetidos após as correções, com saídas em `logs/test_logs_correction/`, e então a suíte integral foi executada novamente em `logs/test_logs/`.

## Classificação e correções

| Categoria | Evidência e correção |
|---|---|
| Defeito ABT | `tests/test_bridge_092.jl` e `tests/test_adversarial_093.jl` mostraram que o namespace retornava o módulo pai antes de permitir um submódulo explicitamente importado. O resolver do interpretador e o embutido no gerador agora expõem os dois caminhos. `tests/test_static_102.jl` foi atualizado para exigir os dois comportamentos. |
| Defeito ABT | `test_interop*.jl` revelaram que a validação tentava inferir `Julia.Módulo` como valor ao validar `Julia.Módulo.função(...)`. A chamada completa agora é tratada sem validar prematuramente o caminho parcial. |
| Defeito ABT | O gerador usava UUID incorreto para `Statistics`; corrigido para o UUID da biblioteca padrão. A execução gerada de `mean` é testada de verdade. |
| Defeito ABT | Carregamento tardio de bibliotecas Julia/Python gerava erros de world age em chamadas, importações e impressão de objetos Python. O bridge usa `Base.invokelatest` nas chamadas necessárias; atributos `PythonCall.Py` são lidos por `pygetattr`, preservando o bloqueio de atributos privados. |
| Defeito dos testes | `tests/runtests.jl`, `tests/runtests_legacy.jl`, `test_interop*.jl`, `tests/test_python_bridge.jl`, `tests/test_regression_091.jl`, `tests/test_bridge_092.jl`, `tests/test_adversarial_093.jl` e vários `test_static_*.jl` exigiam nomes e trechos de Julia gerado de versões antigas. Foram atualizados para resultados de execução quando viável e, nos contratos estruturais, para a arquitetura atual. |
| Defeito dos testes | `tests/test_static_095.jl` e `tests/test_static_103.jl` passavam `String` diretamente a `parse_program`, que recebe tokens; corrigidos para chamar `tokenize`. |
| Ambiente | PythonCall ausente na primeira rodada; instalado localmente. A rodada final exigiu PythonCall/NumPy e não teve `Broken`. O launcher juliaup não funcionou sob a restrição de escrita; o binário Julia direto funcionou. |
| Comportamento não especificado como barreira de segurança | `tests/audit_adversarial.jl` relata aceitação de `getattr(..., "__dict__")` e `os.system`. O projeto documenta que importar módulos Python executa código com privilégios do processo e que a regra de `_` restringe a API direta, sem ser sandbox. Esses dois `FINDING` continuam como observações de segurança da sonda, sem alterar a semântica ABT. |

## Auditoria de cobertura

As famílias incluem baseline/legado, aritmética e funções, 24 regressões `test_static_093..116.jl`, interoperabilidade Julia, quatro scripts de ponte/regressão Python, diagnóstico e sondas adversariais. Há sobreposição intencional de expectativas de namespaces e importações entre testes históricos; os arquivos foram preservados para regressão por versão. O runner isola cada script em processo novo, marca execução com `Broken` como `PARTIAL` e documenta a inclusão do legado. Foi adicionado um teste de comportamento de Julia gerado com otimização ligada/desligada para aritmética, desvio, função e agregação.

Lacuna remanescente: os 600 casos aritméticos e 200 casos de otimização da suíte principal não executam individualmente cada programa gerado; a nova amostra diferencial cobre os caminhos principais, e os casos em massa continuam verificando o interpretador e propriedades estruturais. As sondas exploratórias não são gates de segurança. PythonCall permanece opcional para uso normal do ABT, embora tenha sido exigido nesta auditoria.
