# ABT 0.11.3 — 25ª rodada (revisão estática)

## Correção implementada
`validate_ir` agora normaliza e verifica `initial_names` antes de inferir tipos:
- exige dicionário com chaves String não vazias e sem caracteres de controle;
- aceita somente tipos semânticos públicos `:unknown`, `:external`, `:number`, `:bool`, `:string`, `:list`;
- bloqueia `Python`, `Julia` e prefixo interno `__julia_` para impedir falsificação de namespaces/importações;
- copia as entradas para `Dict{String,Symbol}`, evitando dependência de mutação do dicionário do chamador.

`tests/test_static_113.jl` cobre entradas inválidas e tipos públicos válidos. Testes não executados: Julia não disponível neste ambiente.

## Nova tentativa adversarial — achados e limites
1. **Alta:** o interpretador e o código gerado continuam com caminhos próprios de ponte Python; falta teste diferencial com efeitos, erros e identidade.
2. **Alta:** `abt_check_ir_shape` valida formato, mas não detecta ciclos em IR arbitrário; uma estrutura autorreferente pode causar recursão sem fim ou estouro de pilha.
3. **Média:** `abt_check_ir_shape` aceita nomes IR com caracteres de controle, enquanto `initial_names` agora os rejeita; política de identificadores deve ser unificada.
4. **Média:** a carga de módulos Julia usa APIs internas e carece de testes em diferentes versões Julia.
5. **Média:** chamadas externas podem modificar objetos mutáveis passados pelo chamador; a política de aliasing deve ser documentada, não corrigida por cópias profundas automáticas.

## Verificações realizadas
Inspeção do diff e integridade ZIP; **não** foi executada a suíte Julia nem comprovada equivalência entre interpretador e gerador.
