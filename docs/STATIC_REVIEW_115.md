# ABT 0.11.5 — 27ª rodada de auditoria adversarial

## Defeito corrigido
O verificador estrutural aceitava `AbstractVector` com elementos `IR` (inclusive `Vector{Any}`), mas `optimize_ir` e outras rotinas internas requerem concretamente `Vector{IR}`. Assim, um IR podia passar pela validação e falhar com `MethodError` na otimização. Agora sequências de expressões, argumentos e blocos exigem `Vector{IR}`; parâmetros de funções exigem `Vector{String}`. Isso não muda o código-fonte ABT normal, cujo lowering já constrói esses vetores.

## Nova tentativa de quebra
- IR com lista de argumentos `Any[ir(...)]`.
- IR com lista de elementos `Any[ir(...)]`.
- IR com corpo condicional `Any[ir(...)]`.
- IR com parâmetros de função `Any["x"]`.
- Regressão positiva com vetores tipados.

## Pendências e riscos
1. Ponte Python permanece duplicada entre interpretador e código gerado; requer testes diferenciais reais antes de refatorar.
2. Verificação estrutural usa travessia recursiva e pode repetir trabalho em DAGs com compartilhamento extenso. Limite de profundidade não limita o custo total.
3. Gerador e interpretador ainda não foram comparados dinamicamente quanto a erros, saídas e efeitos colaterais.
4. Compatibilidade de carregamento de módulos com versões Julia suportadas não foi comprovada.
5. A verificação do IR é um contrato de representação interna, não uma garantia de segurança contra código externo malicioso.

## Verificação
Código e ZIP inspecionados; testes Julia preparados mas **não executados**, pois Julia não está disponível neste ambiente.
