# ABT 0.10.0 — 11ª inspeção estática adversarial

## Corrigido
- Namespace Python gerado usava `NamedTuple` identificado apenas por nomes de campos. Agora cada programa possui `abt_namespace_token`, um `Ref` de identidade exclusiva; as views carregam o token e o dispatcher compara por `===`. Objetos externos com campos `modules` e `prefix` não são mais confundidos com namespaces ABT.
- Mantida a inicialização da ponte somente para programas com import Python.

## Nova tentativa de quebra (não corrigida)
**Alta — funções ABT e Python importado:** funções ABT são emitidas antes do corpo principal, mas o validador não admite namespace Python dentro de funções; limitação explícita, não bug de execução.
**Alta — imports Julia antecipados:** `generate_ir` emite `import Statistics` no escopo do módulo antes do `let`, mesmo quando o comando ABT aparece depois de instruções com efeitos. A importação pode carregar código e alterar estado antes do momento em que o interpretador a executa. Contrato temporal ainda divergente.
**Rechecagem — operadores booleanos:** o lexer normaliza operadores para `&&` e `||`; portanto a suspeita inicial de emissão literal de `e`/`ou` não se confirmou. Não contabilizada como defeito.
**Média — dependência do ambiente:** `execute(nodes; env=...)` aceita nomes externos; `generate` não recebe ambiente correspondente. A equivalência diferencial só é válida para programas fechados ou com um contrato de injeção.

## Estado
Revisão de texto e código; testes Julia não executados. Não afirmar equivalência completa.
