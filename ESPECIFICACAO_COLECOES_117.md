# ABT 0.11.7 — primeira camada declarativa de coleções

Esta especificação antecede a implementação. Ela acrescenta três expressões, sem alterar a sintaxe válida anterior.

## Gramática

```text
expressão_primária ::= ...
                    | "filtrar" expressão_primária "onde" expressão
                    | "transformar" expressão_primária "com" expressão
                    | "limitar" expressão_primária "a" expressão_primária
```

`filtrar`, `transformar`, `limitar` e `com` são reconhecidas apenas no padrão completo da operação; continuam disponíveis como nomes em programas ABT anteriores. `onde` já era reservada. O operando de coleção e o limite seguem a regra de expressão primária; use parênteses para operandos compostos. Assim, a composição não depende de precedência implícita:

```abt
resultado = limitar (transformar (filtrar dados onde valor > 2) com valor * 10) a 3
```

Não há comandos de linha soltos: as operações retornam coleções e podem ser atribuídas, passadas a funções ou mostradas. Frases parcialmente reconhecidas são erro de sintaxe.

## Contrato comum

- A entrada deve ser `Vector` Julia (o tipo de lista produzido pelo ABT). Cada operação cria um novo vetor; a entrada não é alterada.
- A coleção é avaliada primeiro, exatamente uma vez. `filtrar` e `transformar` avaliam sua expressão uma vez por elemento, da esquerda para a direita. `limitar` avalia o limite depois da coleção, uma vez.
- Em `filtrar` e `transformar`, `valor` e `value` designam o elemento atual apenas dentro da expressão da operação. São palavras contextuais já existentes e não escapam para o escopo externo. Operações aninhadas têm bindings próprios.
- `nothing` e `missing` não são removidos nem substituídos automaticamente. Se uma expressão não puder operar sobre eles, a exceção original é propagada. Não há valores ausentes implícitos na sintaxe ABT atual.
- As operações não introduzem paralelismo, I/O ou efeitos próprios. Efeitos das expressões do usuário ocorrem na ordem de avaliação acima; a primeira exceção interrompe a operação e impede avaliações posteriores.
- O interpretador e o Julia gerado devem produzir os mesmos valores observáveis, saída e erros, com otimização ligada ou desligada. O otimizador não reordena nem funde estas operações nesta versão.

## `filtrar coleção onde predicado`

Entrada: `Vector`. O predicado deve produzir `Bool` para cada elemento; qualquer outro resultado é erro explícito. Saída: novo `Vector` com os elementos originais cujo predicado é `true`, na mesma ordem e sem alterar seus valores. Entrada vazia produz vetor vazio e não avalia o predicado. A coleção deve ser válida antes de qualquer chamada do predicado.

## `transformar coleção com expressão`

Entrada: `Vector`. A expressão pode produzir qualquer valor ABT/Julia representável em um vetor. Saída: novo `Vector` com um resultado por elemento, na ordem original. Entrada vazia produz `Any[]` e não avalia a expressão; isso fixa a representação observável em `mostrar` sem inferir um tipo a partir de uma expressão que não foi executada. A expressão é avaliada mesmo quando retorna `nothing`; esse valor permanece no resultado.

## `limitar coleção a quantidade`

Entrada: `Vector`; quantidade: `Int64` não negativo (Bool, Float64 e outros tipos são rejeitados). Saída: novo `Vector` com os primeiros `min(quantidade, comprimento)` elementos, preservando ordem e valores. Zero e coleção vazia produzem vetor vazio. Quantidade maior que o comprimento retorna cópia completa. A quantidade é avaliada mesmo quando a coleção está vazia. Quantidade inválida produz erro explícito.

## Decisões e exclusões

O IR recebe três nós de expressão separados, mantendo a sequência explícita e evitando um executor paralelo de pipelines. `map` e `filter` do Julia realizam a iteração; não há gerenciador de memória ou runtime tabular novo. Agregação já existe como `soma de` e `média de` e pode consumir a saída das operações. Agrupamento, ordenação declarativa e carregamento de arquivos ficam fora desta etapa porque exigem escolhas adicionais de chave, ordenação, esquema e I/O. Nenhuma estratégia estatística é escolhida automaticamente.
