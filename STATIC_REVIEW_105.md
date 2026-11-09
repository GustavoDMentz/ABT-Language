# ABT 0.10.5 — 16ª rodada de auditoria estática

## Correções
1. O interpretador não usa mais `@eval import PythonCall` no módulo `Pseudo`. Carrega o pacote em um módulo privado, como o gerador, e mantém referência em cache.
2. O gerador inicializa `__abt_pythoncall_module__ = nothing` antes de testar a variável. Sem isso, a primeira importação podia causar `UndefVarError` no código Julia gerado.

## Nova tentativa adversarial — achados pendentes
**Alta: isolamento não significa independência de estado do Python.** Mesmo com módulos Julia privados, o PythonCall e o interpretador Python compartilham o estado de importação (`sys.modules`). Importar um módulo Python com efeitos colaterais em programas ABT distintos não fornece isolamento por programa. É preciso definir o contrato explicitamente (estado compartilhado, sem promessa de sandbox) e testar a ordem dos efeitos.

**Média: cache no interpretador vs. cache por programa gerado.** O interpretador reutiliza a referência PythonCall entre execuções, enquanto cada programa gerado cria um módulo privado. A API de `pyimport` é a mesma, mas o ciclo de vida não é idêntico. Não declarar equivalência de efeitos colaterais sem ensaio.

**Média: compatibilidade do carregamento em módulos anônimos.** `Core.eval(Module(gensym(...)), :(import PythonCall))` precisa de teste real nas versões Julia suportadas. Não é garantia de resolução de dependências em todos os ambientes.

## Verificações
- Auditoria estática e inspeção textual do fonte: realizadas.
- Testes Julia: **não executados** (Julia indisponível).
- Sem declaração de aprovação dinâmica.
