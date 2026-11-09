# ABT 0.10.2 — 13ª auditoria estática adversarial

## Corrigido por inspeção
- Resolução de namespaces Python: **módulo importado exato > namespace virtual de descendentes > atributo do objeto pai**.
- Aplicada a mesma prioridade em `bridge_runtime.jl` e no helper gerado por `pseudo.jl`.
- Adicionado `tests/test_static_102.jl` com caso de prefixos sobrepostos e namespace virtual.

## Nova fragilidade: efeitos e isolamento das importações Julia
O gerador usa `@eval import Módulo` dentro de `__abt_program_main__`. O macro avalia no módulo hospedeiro, e não no escopo `let` do programa. Isso introduz/compartilha vínculos entre programas ABT independentes e pode criar conflitos com nomes preexistentes no host. A ordem temporal foi corrigida na 0.10.1, mas **o isolamento dos efeitos não foi corrigido**. A implementação do interpretador, por sua vez, usa o mapeamento de módulos carregados no módulo `Pseudo`, não o host do código gerado.

### Contrato proposto
Para a PoC, explicitar que importações Julia são dependências de módulo hospedeiro e exigir host isolado nos testes diferenciais, **ou** substituir o mecanismo por resolução explícita de objetos de módulo sem `@eval import` no host. A segunda opção é mais coerente com isolamento forte, mas exige uma refatoração revisada.

## Limites da auditoria
- Testes Julia não executados neste ambiente.
- A mudança de prioridade pode alterar o comportamento esperado de códigos que dependiam da antiga view virtual; isso é intencional.
- Testes de efeitos de importação, objetos Python reais e múltiplos módulos hospedeiros continuam necessários.
