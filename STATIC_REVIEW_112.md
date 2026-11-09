# ABT 0.11.2 — 24ª rodada

## Correção
- `optimize_ir` valida estruturalmente a árvore antes de indexar os operandos.
- A verificação é intencionalmente apenas estrutural; IR com nomes ainda não resolvidos pode ser otimizado, mas o gerador continua exigindo validação semântica.
- Testes de regressão adicionados em `test_static_112.jl`.

## Nova tentativa de quebra: pendências
1. **Alta:** interpretador e gerador ainda mantêm implementações de ponte Python separadas; comportamento de identidade, exceções e efeitos pode divergir.
2. **Alta:** a API `initial_names` aceita valores não verificados e pode introduzir tipos semânticos inválidos.
3. **Média:** IR arbitrário com nomes malformados (caracteres de controle, Unicode, nomes reservados) precisa de revisão específica do mapeamento para Julia.
4. **Média:** carregamento de módulos via APIs Julia internas não foi testado em múltiplas versões.
5. **Média:** contratos de saída, mutabilidade e erros entre caminhos não estão demonstrados por testes diferenciais dinâmicos.

## Verificação
Revisão textual e integridade ZIP; nenhum teste Julia executado neste ambiente.
