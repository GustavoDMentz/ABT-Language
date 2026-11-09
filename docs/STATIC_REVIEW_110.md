# ABT 0.11.0 — 22ª rodada, auditoria adversarial estática

## Correções
1. **Constantes IR**: rejeição de objetos não serializáveis em `validate_ir`; emissão via `abt_literal_source` para `nothing`, `Bool`, `String`, `Int64`, `Float64` (incluindo `NaN`, infinitos e zero negativo). `string(obj)` não é serialização de código Julia.
2. **Bug concreto de geração**: strings de helpers gerados continham `$field` e agora `$path` sem escape. Julia tentaria interpolar variáveis no escopo do gerador, em vez de deixar a interpolação para o código gerado. Escapados como `\$field` e `\$path` no template.
3. **Mensagens de bridge**: alinhadas mensagens de importação inválida, componente privado e namespace ausente entre interpretador e gerador.
4. `tests/test_static_110.jl` testa rejeição de objetos IR, parse de literais e escape das mensagens de helpers.

## Nova tentativa de quebra: achados e limites
- **Alta**: o bridge continua duplicado; mensagens alinhadas não garantem equivalência de semântica.
- **Alta**: `validate_ir` presume a forma dos operandos do IR; IR arbitrariamente malformado pode lançar `BoundsError` ou `MethodError`, em vez de erro semântico uniforme.
- **Alta**: o interpretador tem funções auxiliares e namespaces com tipos diferentes dos helpers gerados; falta teste diferencial executado.
- **Média**: `Float64` NaN/Inf pode ser representado em Julia, mas a equivalência de operações não foi verificada dinamicamente.
- **Média**: `Base.require(Base.PkgId(...))` continua sem teste de compatibilidade Julia real.
- **Média**: aliasing de objetos mutáveis externos permanece uma política a documentar, não algo a corrigir com `deepcopy` indiscriminado.
- **Média**: não há contrato completo para stdout, stderr, erros, efeitos colaterais e resultados Python.

## Verificação
- Inspeção textual das mudanças e integridade do arquivo ZIP.
- `tests/test_static_110.jl` criado, **não executado**: Julia não está instalado neste ambiente.
- Nenhuma afirmação de aprovação dinâmica ou de equivalência comprovada.
