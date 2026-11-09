# ABT 0.10.3 — 14ª inspeção adversarial (estática)

## Corrigido nesta rodada
- `usar Julia.Statistics` e `usar Julia.LinearAlgebra` deixam de emitir `@eval import` no módulo hospedeiro.
- O gerador resolve os módulos padrão por `Base.require(Base.PkgId(...))`, com UUIDs fixos, e armazena os resultados em vínculos locais à função do programa.
- `Julia.Base` usa diretamente `Base`, sem importação.
- A emissão de referências `Julia.Statistics.mean` usa o vínculo local `__abt_julia_module_Statistics.mean`.
- A ordem das instruções ABT continua preservada; carregar módulos pode, naturalmente, ter efeitos de inicialização globais.

## Nova tentativa de quebra — achado alto
O gerador ainda emite `@eval import PythonCall` quando encontra `usar Python...`. Portanto **a ponte Python continua alterando o namespace do módulo hospedeiro**. Dois programas ABT com PythonCall podem compartilhar esse vínculo, apesar do `let` de isolamento. A correção seguinte deve usar carregamento isolado de PythonCall ou uma dependência explicitamente injetada, sem `@eval import` no hospedeiro.

## Achado adicional — semântica de tipos
O interpretador usa um `Dict` de módulos Julia, enquanto o gerador usa vínculos locais. A interface aceita é limitada às referências `Julia.Módulo.função` e não a valores de módulo, mas ainda falta testar rigorosamente os erros de importação e o comportamento de `Base.require` entre versões de Julia.

## Limites da verificação
Inspeção e testes textuais em Python apenas; **Julia não está instalada neste ambiente**. Não é aprovação dinâmica nem garantia de que a API interna `Base.require(PkgId)` funciona em todas as versões.
