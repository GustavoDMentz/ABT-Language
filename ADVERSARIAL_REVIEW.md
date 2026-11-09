# ABT 0.9.2 — terceira auditoria adversarial

## Defeito confirmado por inspeção de código (não executado em Julia)

- `evalnode(:call)` em `pseudo.jl` só aceita `fn isa Function`, `PythonCall.Py` ou `ABTFunction`. Objetos Julia que implementam `(::MeuTipo)(args...)` são chamáveis, mas o interpretador os rejeita. O código Julia gerado chama `abt_invoke(fn, ...)`, que delega a `fn(args...)`, e portanto aceita esses objetos. Isso quebra a equivalência interpretador/backend com objetos fornecidos por `env`. O teste `test_adversarial_093.jl` demonstra o contrato esperado e deve falhar no interpretador atual.

## Fragilidades adicionais

- `abt_external_field` permite acesso por atributo em módulos já importados, inclusive a submódulos não declarados explicitamente, pois a verificação semântica só exige um prefixo importado. É uma política de imports permissiva, não necessariamente um bug, mas deve ser documentada.
- `abt_invoke` captura toda exceção de `PythonCall.Py` e a reemite como `ErrorException`, perdendo o tipo original e parte do contexto estruturado.
- A equivalência diferencial atual compara texto impresso, não valores tipados, mutações, efeitos ou exceções.
- O código gerado incorpora o bridge inteiro mesmo em programas que não usam Python; isso aumenta o tamanho do código gerado e o trabalho de parsing/compilação, embora não carregue PythonCall automaticamente.
- Testes com PythonCall/NumPy são opcionais, salvo `ABT_REQUIRE_PYTHON=1`.

## Limitação da auditoria

O ambiente não tem executável Julia. Estes testes são entregues para execução no ambiente do usuário; nenhuma aprovação de runtime é alegada.
