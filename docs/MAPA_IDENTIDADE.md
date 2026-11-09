# Identidade pública e compatibilidade

## Inventário antes da refatoração

O ABT estava implementado principalmente em `pseudo.jl`, no módulo `Pseudo`. `bridge_runtime.jl` continha a fronteira externa. A execução pública documentada usava `julia pseudo.jl ...`. O inventário textual encontrou referências ao nome histórico em 36 arquivos de teste, 17 documentos, 7 scripts e o arquivo central; não havia programas em `examples/` cujo código ABT dependesse do nome `Pseudo`. As referências em revisões antigas são evidência histórica, não instruções atuais.

| Ocorrência | Classe | Decisão |
|---|---|---|
| Comando `julia pseudo.jl` em README antigo | Pública, obsoleta | README novo usa `abt`. A versão anterior ficou em `docs/README_LEGADO.md`. |
| Módulo `Pseudo` e `pseudo.jl` em testes | Compatibilidade legada | `pseudo.jl` inclui `src/ABT.jl` e expõe `Pseudo` como alias do módulo `ABT`; execução legada continua disponível. |
| `bridge_runtime.jl` em teste estático | Compatibilidade legada | Adaptador inclui `src/Runtime/Bridge.jl`. |
| `pseudo_sum`, `pseudo_average` no código gerado | Interna | Nomes de helpers locais mantidos para preservar testes e código gerado; não aparecem no CLI público. |
| Arquivos `.pseudo` antigos | Compatibilidade legada | Exemplos e testes preservados; `.abt` é a extensão pública no VS Code. |
| Documentos `STATIC_REVIEW_*` e changelog | Histórica | Mantidos sem reescrever o registro técnico. |
| `run_cli_examples.py`, benchmarks e scripts de teste | Interna | Podem usar o adaptador para testar geração antiga; não constituem interface de usuário. |

## Novos caminhos

| Responsabilidade | Caminho |
|---|---|
| Comando oficial | `bin/abt` |
| Interface do compilador e runtime ABT | `src/ABT.jl`, módulo `ABT` |
| Roteamento de comandos, diagnósticos e códigos de saída | `src/CLI.jl` |
| Fronteira Julia/Python compartilhada | `src/Runtime/Bridge.jl` |
| Declarações de pacotes opcionais | `ABT.packages.toml` |
| Compatibilidade de entrada antiga | `pseudo.jl`, `bridge_runtime.jl` |

Lexer, parser, AST, IR, otimizador e gerador permanecem juntos em `src/ABT.jl` nesta etapa. Separá-los em vários módulos agora exigiria mudar vínculos internos e arriscaria a equivalência sem ganho semântico demonstrado. A fronteira pública, a CLI e o runtime externo estão separados; uma divisão interna adicional fica condicionada a testes específicos.

## Contrato do CLI

`abt FILE` e `abt executar FILE` executam o programa e emitem sua saída normal. `abt verificar FILE` faz tokenize, parse e validação do IR sem executar o programa. `abt --versao` e `abt --ajuda` são consultas. `--depurar` antes do comando acrescenta exceção e stacktrace técnicos. As mensagens normais são em português; a ajuda normal não expõe a invocação Julia. Os códigos de saída são 0 (sucesso), 1 (erro do programa) e 2 (uso incorreto/arquivo ausente). Caminhos de arquivo são interpretados em relação ao diretório do usuário; os arquivos internos do ABT são resolvidos em relação ao lançador.

Julia permanece dependência de implementação e está identificada na documentação de instalação. O CLI não esconde limites de segurança ou proveniência de pacotes. `ABT_JULIA` permite selecionar uma instalação Julia específica para reprodução; o padrão é `julia` do PATH.
