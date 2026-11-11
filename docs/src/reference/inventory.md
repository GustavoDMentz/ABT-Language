# Inventário de recursos da `main` 0.12.0

| Estado | Recursos | Fonte principal |
|---|---|---|
| Implementado | Lexer, parser, AST, IR, validação, interpretador, gerador Julia com otimização conservadora. | `src/ABT.jl`, testes diferenciais. |
| Implementado | Literais, atribuições, listas, operadores, condicionais, laços, funções de nível superior, registros, agregações e pipelines indentados. | `src/ABT.jl`, `tests/test_pipelines_118.jl`, `tests/test_collections_117.jl`. |
| Implementado | 42 operações públicas para texto, CSV tipado, tabelas, estatística, bioestatística, DNA/RNA, álgebra, JSON e visualização. | `src/Stdlib*.jl`, `src/ExtensionRegistry.jl`, [referência](../standard-library/index.md). |
| Implementado | CLI, instalador por usuário, extensão VS Code com realce lexical. | `bin/abt`, `src/CLI.jl`, `tools/install.py`, `vscode/`. |
| Limitado | Imports Julia por manifesto explícito; PythonCall sob demanda; ausência de isolamento de segurança. | `ABT.packages.toml`, `src/Runtime/Bridge.jl`, testes de interoperação. |
| Limitado | CSV iterável, com materialização em algumas operações; inferência estatística clássica com premissas do usuário. | `src/Stdlib.jl`, `src/StdlibBiostatistics.jl`. |
| Experimental | Semântica da linguagem, otimizações e superfície das extensões ainda podem evoluir; ABT 0.12.0 não é API estabilizada de longo prazo. | Versão em `Project.toml`, relatórios históricos. |
| Não implementado | Literal de ausente, tratamento de exceções em ABT, funções aninhadas, módulo ABT definido pelo usuário, LSP, autocomplete semântico, debugger. | Ausência no parser/CLI/VS Code; [gramática](grammar.md). |

Este inventário corresponde ao commit integrado da PR #1 em `main` em 11/11/2026. Propostas em relatórios históricos não são parte da linguagem até aparecerem no código e nos testes da branch principal.
