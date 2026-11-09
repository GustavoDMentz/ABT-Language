# ABT 0.9.3 — revisão estática antes dos testes

## Correções efetuadas

1. **Functors Julia:** `evalnode(:call)` avalia argumentos uma vez e encaminha chamadas não-ABT a `abt_invoke`; evita rejeitar objetos Julia chamáveis.
2. **Semântica dinâmica:** `validate_ir` aceita chamada de variável com tipo `:unknown`/`:external` já definida, preservando rejeição de nomes ausentes, aridades conhecidas e valores obviamente não chamáveis.
3. **Sem ponte desnecessária:** código Julia gerado sem `import_python` inclui apenas dois helpers mínimos, não o código de namespace Python.
4. **Exceções:** `abt_invoke` não transforma indiscriminadamente exceções Python em `ErrorException`, preservando o tipo original.
5. **Testes estáticos existentes:** expectativas de geração ajustadas para distinguir programa com/sem Python.

## Riscos remanescentes / não alegar correção universal

- `PythonCall` não é sandbox; a checagem de atributos privados não garante isolamento.
- A geração Julia não reproduz automaticamente valores injetados pelo `env` do interpretador; não é uma comparação diferencial válida para funções externas injetadas.
- Semântica de chamadas dinâmicas só pode ser validada em runtime; não é possível provar estaticamente que todo objeto desconhecido é chamável.
- Exceções externas preservam o tipo, mas diagnósticos ainda não estão uniformizados.
- Tipos, cópias, mutações e efeitos laterais entre Julia e Python ainda carecem de testes diferenciais estruturados.
- Nenhum teste Julia foi executado neste ambiente; a revisão estática não substitui execução.

## Execução sugerida

```sh
julia test_adversarial_093.jl
ABT_REQUIRE_PYTHON=1 julia test_bridge_092.jl
julia test_regression_091.jl
julia test_python_bridge.jl
julia test_interop_extended.jl
julia test_interop.jl
julia runtests.jl
julia break_abt.jl
```
