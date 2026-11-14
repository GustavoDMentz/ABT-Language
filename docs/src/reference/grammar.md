# Gramática da versão 0.15.0

O resumo abaixo transcreve a estrutura de `tokenize`, `statement`, `expr` e `atom` em `src/ABT.jl`. É uma **EBNF de superfície** com restrições semânticas descritas depois; não substitui o parser para mensagens de erro ou casos de fronteira. `ws` inclui espaços, tabs e quebras de linha, exceto dentro de pipelines. Comentário começa com `#` e termina na quebra de linha.

```ebnf
programa      = { ";" | instrucao } , EOF ;
instrucao     = "mostrar" , expressao
              | nome , "=" , expressao
              | "se" , expressao , bloco , [ ("senao" | "senão") , bloco ]
              | "para" , "cada" , nome , "em" , expressao , bloco
              | ("função" | "funcao") , nome , "(" , [ nomes ] , ")" , bloco
              | "retornar" , expressao
              | "usar" , "Python" , "." , nome , { "." , nome }
              | "usar" , "Julia" , "." , nome ;
bloco         = "{" , { ";" | instrucao } , "}" ;
nomes         = nome , { "," , nome } ;
expressao     = disjuncao ;
disjuncao     = conjuncao , { ("ou" | "or") , conjuncao } ;
conjuncao     = comparacao , { ("e" | "and") , comparacao } ;
comparacao    = adicao , { (">" | "<" | ">=" | "<=" | "==" | "!=" | "é" | "is") , adicao } ;
adicao        = produto , { ("+" | "-") , produto } ;
produto       = unario , { ("*" | "/") , unario } ;
unario        = ("+" | "-") , unario | potencia ;
potencia      = atomo , [ "^" , unario ] ;
atomo         = numero | texto | booleano | lista | "(" , expressao , ")"
              | ( nome | "valor" ) , { "(" , [ argumentos ] , ")" | "." , nome | "de" , atomo }
              | ("soma" | "media" | "média") , "de" , atomo , [ "onde" , expressao ]
              | "filtrar" , atomo , "onde" , expressao
              | "transformar" , atomo , "com" , expressao
              | "limitar" , atomo , "a" , atomo ;
lista         = "[" , [ argumentos ] , "]" ;
argumentos    = expressao , { "," , expressao } ;
```

`numero` é sequência decimal sem sinal, com parte `.<dígitos>` opcional. O sinal é operador unário. `texto` usa aspas duplas e escapes reconhecidos por `Base.unescape_string`. `nome` começa com letra Unicode ou sublinhado (`_`) e continua com caracteres de palavra (letras, dígitos e `_`); o parser reserva prefixo `__abt_`. As palavras-chave portuguesas e aliases ingleses estão no dicionário `KEYWORDS` e **não distinguem maiúsculas de minúsculas**: o lexer compara `lowercase(lexema)`, então `SE`, `Se` e `se` são a mesma palavra; já os nomes de variáveis e funções distinguem (`Total` e `total` são nomes diferentes). `mostrar/show`, `se/if`, `para/for`, `cada/each`, `em/in`, `retornar/return`, `verdadeiro/true`, `falso/false`, `e/and`, `ou/or`, `onde/where`, `soma/sum`, `media/média/average`, `de/of`, `é/is`, `maior/above`, `menor/below`, `que/than`, `senao/senão/else`, `função/funcao/function` compartilham tokens. `valor/value` também são palavras reservadas (token `VALUE`): podem ser lidas como expressão, para o elemento corrente nas operações de lista, mas não podem ser definidas como nome (`valor = 3` é erro de sintaxe). `usar` é reservado. Os nomes `soma`, `sum`, `media`, `média` e `average` são exceção: continuam sendo aceitos como nomes. As palavras `filtrar`, `transformar`, `limitar`, `com` e `a` são contextuais.

`é maior que` e `é menor que` são reconhecidos em comparações como `>` e `<`; `que` é opcional no parser. A forma de propriedade `campo de registro` exige um nome à esquerda. Chamadas de função e acesso a campo associam antes dos operadores da tabela acima. A potência associa à direita; as demais cadeias binárias associam à esquerda.

## Pipelines indentados

Antes do parser, uma linha que sozinha é uma expressão completa pode iniciar pipeline se a próxima linha não vazia tiver coluna maior. A primeira etapa fixa a coluna; todas as etapas seguintes devem começar nessa mesma coluna. Tabs no recuo das linhas envolvidas são erro. Etapas válidas: `filtrar onde expressão`, `transformar com expressão`, `limitar a expressão`; o final obrigatório é `mostrar` sozinho. Após o terminal, o pipeline termina; uma próxima linha volta ao fluxo normal. A expansão preserva as posições de origem para diagnósticos. Consulte [coleções](../manual/collections.md) para exemplo.

`usar Julia.Módulo` aceita exatamente um módulo declarado; `usar Python.caminho` permite componentes adicionais validados. Imports devem estar no nível superior. Funções aninhadas, `retornar` fora de função e condições não booleanas são rejeitadas na validação semântica, mesmo que a EBNF aceite a sequência de tokens.
