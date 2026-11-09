# ABT 0.9.2 — auditoria adversarial e limites

## Corrigido no código
- Módulo e submódulo coexistem num registro por caminho completo; namespaces intermediários são vistas opacas (`ABTPythonNamespace`), com acesso a atributos do módulo importado.
- Importação primeiro executa `pyimport`; somente em sucesso publica o caminho completo, sem prefixos parcialmente criados.
- Interpretador e backend usam **o mesmo arquivo** `bridge_runtime.jl`, embutido no código Julia gerado, evitando duas implementações divergentes.
- `abt_invoke` normaliza a mensagem de erro de chamada Python e mantém o texto da causa; chamada de objeto não chamável continua sendo erro dinâmico.
- Rejeição de atributos `_` também na resolução em runtime; nomes `Python` e `Julia` continuam reservados pela validação semântica.
- Adicionada suíte `tests/test_bridge_092.jl` com importação em ambas as ordens, repetição, falha atômica, namespace, atributos privados, chamadas indiretas e testes diferenciais com NumPy.

## Limitações e casos ainda abertos
- **Não é sandbox.** `usar Python.os` e chamadas públicas como `os.system` executam com os privilégios do processo; não executar código ABT não confiável.
- Não há inferência estática geral de chamabilidade, tipos, efeitos, callbacks, ponteiros, GPU, async, ciclos de vida, ou cópias de arrays.
- Exceções Python recebem prefixo ABT, mas não são normalizadas numa hierarquia estruturada de classes/códigos. Saídas e efeitos não são comparados estruturalmente.
- O namespace é opaco na sintaxe ABT, mas o registro interno Julia é mutável. A política `_` não impede acesso indireto por APIs públicas Python.
- A suíte diferencial ainda compara saída textual e depende de PythonCall + NumPy; configure `ABT_REQUIRE_PYTHON=1` para falhar se estiverem ausentes.
- Não foi possível executar Julia neste ambiente. Não declarar aprovação dos testes até execução externa.
