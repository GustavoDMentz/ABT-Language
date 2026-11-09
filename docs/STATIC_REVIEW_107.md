# ABT 0.10.7 — 18ª rodada de auditoria estática

## Correção
O loader gerado agora envolve `Core.eval(deps, :(import PythonCall))` em `try/catch`, assim como o loader do interpretador em `bridge_runtime.jl`. Ambos emitem `Interop Python indisponível: verifique PythonCall.jl. Causa: ...` e preservam o texto da causa com `sprint(showerror, err)`. O tipo e o stacktrace da exceção original não são preservados: isto continua sendo uma limitação explícita.

## Nova tentativa adversarial — ALTA
O gerador emite dois comportamentos diferentes para `abt_external_field` dependendo da presença de importação Python. Se não há Python, emite `abt_external_field(obj, field) = obj isa AbstractDict ? obj[field] : getproperty(obj, Symbol(field))`, **sem** a restrição `startswith(field, "_")` que o interpretador aplica sempre. Portanto, para um objeto externo com atributo privado, o interpretador rejeita o acesso, enquanto o código Julia gerado sem Python permite a consulta. Contrato de atributos diverge por uma condição não relacionada ao objeto consultado.

## Outras observações
- O teste incluído é estático/textual e não prova comportamento em execução.
- O carregamento em módulos privados e `Base.require` ainda precisam de Julia real.
- Os diagnósticos padronizam a mensagem, mas não o tipo da exceção.
