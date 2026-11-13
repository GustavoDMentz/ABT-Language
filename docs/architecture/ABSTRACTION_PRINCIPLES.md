# Princípios de abstração da ABT

ABT expressa a intenção do programa; Julia executa a implementação. A API pública da ABT é definida por sua sintaxe, operações e contratos observáveis, não pelos tipos ou módulos usados internamente. Esta referência orienta a revisão de novas operações e exemplos.

## Critérios

1. **Expressividade:** uma operação pública representa uma tarefa compreensível em termos do domínio. Não exige que o usuário descreva etapas internas de Julia quando a tarefa já é suportada pela ABT.
2. **Independência conceitual:** os fluxos oficialmente documentados podem ser aprendidos e executados sem conhecer módulos, tipos ou convenções de Julia.
3. **Consistência:** operações afins seguem convenções previsíveis de nomes, ordem de argumentos, resultados e erros. Uma diferença de contrato precisa de uma razão explícita.
4. **Composição:** resultados podem ser atribuídos, reutilizados e combinados com funções, listas, registros, tabelas e pipelines quando os tipos e contratos permitem. `mostrar` apresenta; operações de cálculo retornam valores.
5. **Interoperabilidade controlada:** `usar Julia.Módulo` e a ponte Python são recursos explícitos para casos avançados. A interoperabilidade não substitui uma operação fundamental oficialmente suportada.
6. **Rigor semântico:** a interface amigável não escolhe implicitamente hipóteses científicas, política de ausentes, esquema, unidades ou parâmetros que mudem a interpretação de um resultado.

## Três superfícies distintas

| Superfície | Responsabilidade | Exemplo |
| --- | --- | --- |
| API pública ABT | Expressar intenção com contrato estável | `contar(dados)` |
| Ponte de interoperabilidade | Acesso externo solicitado explicitamente | `usar Julia.Base` e `Julia.Base.length(dados)` |
| Implementação interna | Executar operações e carregar bibliotecas | `Base.length` dentro de uma função da biblioteca ABT |

Uma função Julia usada internamente não é, por si, vazamento de abstração. O problema surge quando um fluxo público comum exige que o programa ABT conheça essa função, seu módulo ou um tipo de implementação.

## Convenções para operações públicas

- Usar um nome descritivo em português para novas operações comuns. Aliases em inglês existentes continuam válidos; novos aliases só são adicionados quando houver benefício concreto e ausência de colisão.
- Definir aridade, tipos aceitos, casos vazios, valores ausentes, ordem de avaliação, efeitos e erros antes de implementar.
- Retornar valores ABT reutilizáveis. Registros e tabelas têm campos e comportamento documentados; detalhes internos de pacotes não integram o contrato público.
- Preferir composição de operações existentes a uma nova palavra reservada. Uma mudança gramatical requer proposta separada com semântica, impacto no parser, IR, backends e compatibilidade.
- Preservar equivalência observável entre interpretação e Julia gerada, com e sem otimização: valor, tipo, saída, erro, ordem e efeitos.
- Manter a ponte Julia/Python explícita e compatível com programas existentes. PythonCall permanece opcional.

## Revisão obrigatória de uma biblioteca nova

Antes de aceitar a integração, responder:

1. É possível usar a operação sem conhecer Julia?
2. O nome e a assinatura expressam uma intenção clara?
3. Os argumentos necessários e suas políticas são compreensíveis?
4. O resultado tem contrato ABT estável e é reutilizável?
5. A operação compõe com os recursos existentes sem conversão silenciosa?
6. Erros e valores ausentes são definidos?
7. Interpretador e código Julia gerado concordam nos casos válidos e inválidos?
8. A documentação ensina ABT em vez de reproduzir a API de um pacote Julia?

Parâmetros estatísticos e biológicos que alteram o significado do resultado devem continuar explícitos, ainda que tornem a assinatura mais longa. Valores padrão só são admissíveis quando tecnicamente seguros, documentados e compatíveis.

## Evolução da sintaxe

Uma proposta de sintaxe deve incluir um programa anterior e posterior, ganho concreto de clareza, gramática sem ambiguidade, impacto no AST/IR e teste de paridade entre backends. A aparência, isoladamente, não justifica uma palavra-chave. Construções com significado indeterminado devem permanecer propostas até que o contrato seja definido.
