# ABT 0.10.9 — 21ª rodada, auditoria ampla

## Correções por inspeção
- `generate_ir(Vector{IR})` agora valida IR antes de gerar; o caminho interno `_generate_validated_ir` é reservado para código que já validou. `generate` valida uma vez, otimiza opcionalmente e emite. `explain` utiliza o caminho interno após validação.
- Constant folding numérico agora limita comparações a `Int64` e `Float64` finitos, evitando executar métodos de tipos numéricos externos durante a compilação. Isto é um endurecimento conservador, não uma prova de equivalência para todos os tipos.
- `tests/test_static_109.jl` adiciona regressão da fronteira pública de IR.

## Nova auditoria adversarial ampla — pendências
1. **Alta: bridge duplicado**: `bridge_runtime.jl` e helpers emitidos por strings em `pseudo.jl` continuam implementações independentes, com representações distintas de namespaces. Requer refatoração cuidadosa, não um replace textual.
2. **Alta: `generate_ir` não é fronteira de segurança absoluta**: `_generate_validated_ir` permanece acessível pelo nome qualificado do módulo Julia; é interface interna por convenção, não isolamento de segurança. ABT não é sandbox.
3. **Alta: semântica de importação Julia**: `Base.require(PkgId)` e o binding em função devem ser executados com Julia real; sem teste não há garantia de compatibilidade.
4. **Média: saída e exceções**: interpretador armazena strings e compilado imprime em stdout; não existe harness diferencial para erros, side effects e objetos Python.
5. **Média: aliasing do ambiente externo**: `copy(env)` é cópia rasa; objetos mutáveis inseridos no ambiente ainda podem sofrer mutações por funções externas.
6. **Média: constantes IR arbitrárias**: `julia_ir_expr(:constant)` usa `string` para valores não-string; não existe serialização segura e geral de objetos externos. O parser ABT suporta subconjunto mais restrito.
7. **Média: namespaces Python**: gerador usa token/NamedTuple, interpretador usa `ABTPythonNamespace`, divergências futuras ainda são possíveis.

## Verificação
- Arquivos modificados e testes Julia adicionados.
- Sem Julia instalado neste ambiente: nenhuma afirmação de execução ou aprovação dinâmica.
- Para a próxima rodada: centralizar o bridge, definir contrato de IR serializável e preparar harness diferencial.
