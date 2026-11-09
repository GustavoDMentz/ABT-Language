# ABT 0.11.8: pipelines por indentação

## Gramática e reconhecimento

Um pipeline começa quando uma linha contém somente uma expressão ABT completa e a próxima linha não vazia inicia em coluna maior. Comentários e linhas vazias não são etapas. A expressão inicial é avaliada uma vez. A primeira etapa determina a coluna `c`; todas as etapas devem começar exatamente em `c`. Recuo adicional é erro. O pipeline termina exclusivamente com uma linha `mostrar` em `c`, sem argumento. Ausência dessa etapa é erro. O primeiro token após `mostrar` pertence ao programa externo. Não há continuação de pipeline em linhas seguintes.

Etapas permitidas: `filtrar onde expressão`, `transformar com expressão`, `limitar a expressão`, e `mostrar`. Cada expressão de etapa deve caber em uma linha e ser completa. Uma linha de etapa desconhecida ou incompleta é erro com linha, coluna e causa. Tabulações no recuo da origem ou das etapas são erro; use espaços. A declaração de função e os blocos `se`/`para` continuam delimitados por chaves; pipelines podem ocorrer em seu corpo quando a origem e cada etapa ocupam linhas próprias. Chaves devem aparecer fora da linha terminal. O formato não aceita uma expressão inicial distribuída por várias linhas.

A linha isolada sem uma próxima linha recuada continua sujeita à gramática normal de declarações do ABT. Assim, o reconhecimento de pipeline não reinterpreta programas válidos antigos. O recuo das demais construções não adquire semântica nova.

## Semântica

`filtrar`, `transformar` e `limitar` são exatamente as operações de coleção 0.11.7, na ordem textual. O valor de cada etapa alimenta a seguinte. `valor` e `value` pertencem exclusivamente à avaliação por elemento da etapa correspondente. Não são criadas variáveis para resultados intermediários. `mostrar` emite a representação do resultado final uma vez, como a declaração `mostrar` existente. Não retorna um valor de pipeline nem habilita etapas seguintes no mesmo pipeline.

O parser converte a forma indentada em uma única declaração `mostrar` composta pelas expressões existentes antes de construir AST e IR. Interpretador e dois modos de geração passam pelo mesmo IR e contratos. Erros de tipo, coleção vazia, limite inválido, ordem de efeitos e exceções seguem a especificação de coleções 0.11.7. Não há fusão, paralelismo ou reordenação.

## Construções excluídas por ambiguidade

Atribuição direta do resultado do pipeline, `mostrar` com argumento, várias etapas na mesma linha, etapas após `mostrar` com o mesmo recuo, recuos tabulados e expressões de etapa multilinha não têm significado nesta versão. Use as expressões compostas de 0.11.7 para atribuição ou expressões multilinha quando necessário.
