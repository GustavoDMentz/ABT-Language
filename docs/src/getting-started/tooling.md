# VS Code, validação e diagnósticos

A extensão mínima em `vscode/abt-language` associa `.abt` à linguagem e oferece realce lexical. Para instalação local, copie a pasta para `~/.vscode/extensions/abt-language-0.1.0` e reinicie o VS Code. As tarefas em `.vscode/tasks.json` executam e verificam o arquivo atual por `~/.local/bin/abt`.

O realce não é análise semântica. Use `abt check arquivo.abt` antes de executar. Não há servidor LSP, autocomplete semântico ou depurador interativo nesta versão.

```abt
mostrar resultado
```

Sem uma atribuição anterior, a CLI devolve um diagnóstico `ABT[E021]` de variável não definida e código de saída 1. Erros de sintaxe recebem, quando reconhecidos pelo catálogo, `E010`; aridade incorreta pode receber `E052`; outros erros usam `E000`. O código e a causa textual são mais úteis que a redação exata, que pode mudar. `--depurar` mostra a exceção Julia original. Consulte [semântica e erros](../reference/semantics.md).

Para gerar Julia a partir de um programa ABT, a interface legada `pseudo.jl` aceita `--emit-julia arquivo.jl --no-run` e `--no-opt`. Essa interface é voltada a desenvolvimento; a CLI cotidiana é `bin/abt`.
