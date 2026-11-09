# Decisões arquiteturais — coleções ABT 0.11.7

## Extensão escolhida

O lexer mantém os identificadores antigos; o parser reconhece `filtrar`, `transformar` e `limitar` apenas em posição e formato de expressão. Cada operação gera um nó AST e um nó IR próprios. Isso preserva programas anteriores que usam essas palavras como nomes e reutiliza o validador, otimizador e gerador existentes.

O IR representa a ordem de composição por aninhamento. Não há motor de pipelines separado, fusão de etapas, reordenação, paralelismo ou plano de execução novo. O otimizador apenas percorre as novas expressões, preservando a sequência e os efeitos.

## Execução

O interpretador usa `Base.filter`, `Base.map` e fatiamento de `Vector`. O Julia gerado usa as mesmas operações por helpers locais ao programa gerado. As closures recebem `valor`/`value` em escopo local; o vetor de entrada nunca é alterado. `limitar` só avalia a quantidade após a expressão da coleção. O predicado de filtragem deve retornar `Bool` em cada elemento.

O gerador continua autocontido e sem dependências externas para estas operações. PythonCall continua opcional. Bibliotecas científicas existentes continuam responsáveis por estatística; `média de` já era parte do ABT e pode receber uma coleção transformada.

## Equivalência e custo

Nenhuma nova otimização altera a ordem das operações. Os testes comparam interpretador e Julia gerado com otimização ligada e desligada, incluindo efeitos de funções chamadas por elemento, falhas e coleções vazias. O caso vazio revelou `Any[]` versus `Int64[]` em `transformar`; a representação foi fixada explicitamente como `Any[]` em ambos os caminhos.

O custo é o de criar novos vetores por operação, coerente com a semântica imutável da entrada. Não há execução paralela automática. Fusão de operações exigiria prova de preservação de erros e efeitos e ficou fora da etapa.

## Não implementado

Agrupamento por chave, ordenação declarativa, limitação de arquivos tabulares e carregamento CSV não foram adicionados. Eles exigem contratos adicionais sobre chave, comparador, esquema, codificação e I/O. A etapa encerra nas três operações especificadas.
