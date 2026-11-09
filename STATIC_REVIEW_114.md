# ABT 0.11.4 — 26ª auditoria adversarial

## Correções
- Proteção de ciclos no grafo de IR antes de qualquer validação recursiva. A proteção rastreia a identidade dos vetores de operandos e aceita subexpressões compartilhadas sem ciclos.
- Limite defensivo de profundidade (256) para evitar recursão descontrolada em IR fornecido manualmente.
- `optimize_ir` passa a chamar `abt_check_ir_shape` na entrada pública, evitando acesso posicional a IR malformado.
- Regressões em `test_static_114.jl` para ciclos diretos, indiretos, compartilhamento e otimizador.

## Nova tentativa de quebra: pontos pendentes
1. A validação de ciclos considera IR e vetores, mas não pretende validar objetos arbitrários encapsulados em constantes; esses são tratados separadamente pelo contrato de constantes.
2. O bridge Python permanece duplicado entre interpretador e código gerado.
3. Ainda falta executar testes de equivalência em Julia, inclusive importações e exceções.
4. `Base.require` e carregamento de módulos precisam de validação em versões Julia suportadas.
5. O limite de profundidade é uma restrição de segurança de entrada, não uma garantia de ausência de recursão em outras rotinas.

## Verificação
Revisão estática e teste de integridade do arquivo ZIP; **testes Julia não executados**.
