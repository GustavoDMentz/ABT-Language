# ABT 0.11.1 — 23ª rodada, auditoria estática adversarial

## Alteração aplicada
- Nova verificação estrutural recursiva `abt_check_ir_shape` antes da validação semântica.
- Checagem de opcodes, aridade, tipos de operandos, listas de expressões, parâmetros, ramos e corpos.
- Entrada IR malformada agora recebe erro semântico com caminho do nó, em vez de depender de `BoundsError`/`MethodError` internos.
- `test_static_111.jl`: oito famílias de IR inválido em ambos os caminhos públicos e caso válido de geração.

## Tentativa adicional de quebra — pendências
1. **Alta:** interpretador e código gerado ainda têm bridges Python independentes; não há garantia de equivalência em exceções e identidade de objetos.
2. **Alta:** `optimize_ir` continua exportável como operação sem validação estrutural prévia; entradas IR arbitrárias ainda podem falhar com exceções internas. É API de transformação, não de execução, mas precisa contrato explícito.
3. **Média:** `validate_ir` admite import Julia com nome que não consta em `JULIA_BRIDGE`; a execução pode divergir dependendo do módulo e da versão.
4. **Média:** pré-validação estrutural não prova equivalência de stdout, mutabilidade, ordem de efeitos ou erros entre os dois backends.
5. **Média:** namespaces e carregamento via APIs internas Julia ainda precisam de testes dinâmicos em versões reais.
6. **Média:** `initial_names` é um argumento público cujo formato não é validado pela checagem estrutural.

## Limites da verificação
Inspeção textual e verificação de integridade ZIP; Julia não disponível neste ambiente. `test_static_111.jl` foi escrito mas não executado. A alteração ainda requer execução da suíte completa.
