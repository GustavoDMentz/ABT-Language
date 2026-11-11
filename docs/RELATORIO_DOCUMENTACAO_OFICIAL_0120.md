# Relatório da documentação oficial ABT 0.12.0

Data: 11/11/2026. Base: commit `05e5fe620d275f72bab159b2b8c1c90387f20c20` da `main`; PR #1 de bioestatística já integrada. A branch de documentação é `docs/official-abt-manual`. Nenhuma semântica ABT foi alterada.

## Inventário e fontes

Foram examinados `src/ABT.jl` (lexer, parser, AST, IR, validador, interpretador e gerador), `src/Stdlib*.jl`, `src/ExtensionRegistry.jl`, `src/Runtime/Bridge.jl`, `src/CLI.jl`, `bin/abt`, `ABT.packages.toml`, `Project.toml`, `Manifest.toml`, exemplos, aplicações, testes e configuração VS Code. O catálogo público `ABT.ABT_STDLIB_NAMES` contém 42 operações; as cinco páginas de referência cobrem exatamente essas 42, sem extras nem duplicações. O [inventário do site](src/reference/inventory.md) separa implementado, limitado, experimental e não implementado.

Documentação anterior em `docs/` foi preservada. A nova documentação usa `docs/src/`, com entrada, introdução, manual, referência da biblioteca, oito tutoriais, exemplos, internos, contribuição e gramática. `README.md` passou a apresentar o projeto e apontar para esses capítulos.

## Infraestrutura

Documenter.jl 1.20.0, em `docs/Project.toml` e `docs/Manifest.toml`, gera HTML estático com navegação hierárquica, busca, índices, tema claro/escuro, layout responsivo e realce ABT local. A dependência não entra em `Project.toml` da linguagem. O workflow `.github/workflows/documentation.yml` valida catálogo, links, CLI e exemplos, compila o site em PRs e publica somente em push à `main`, com permissões de Pages limitadas ao job de publicação. A publicação usa artifact de Pages, sem alterar a configuração do repositório.

O endpoint de leitura `GET /repos/GustavoDMentz/ABT-Language/pages` retornou HTTP 404 nesta auditoria. Isso não comprova a ativação de Pages; o mantenedor deve selecionar **GitHub Actions** como fonte em *Settings → Pages*. O endereço esperado é `https://gustavodmentz.github.io/ABT-Language/` após o primeiro deploy bem-sucedido. O workflow remoto ainda não foi executado nesta branch.

## Validação reproduzível

Ambiente local: Linux x86_64, Julia 1.13.3, Python 3.12.3. Com Julia no `PATH` ou `ABT_JULIA` definido:

```bash
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=docs -e 'import Pkg; Pkg.instantiate()'
python3 tools/generate_docs_reference.py --check
python3 tools/validate_docs.py
julia --project=docs docs/make.jl
```

O validador compara os nomes públicos reais com os títulos da referência, verifica que cada operação aparece em um exemplo ABT, confere links internos e arquivos, executa os comandos informativos da CLI, faz `check` e `run` dos nove programas em `docs/examples/` e executa blocos ABT completos do manual e tutoriais. `falhar.abt` e o exemplo de nome indefinido precisam falhar com os diagnósticos esperados. Os resultados estruturados e logs ficam em `logs/documentation/`.

| Verificação | Resultado |
|---|---:|
| Build Documenter local | PASS; HTML em `docs/build/`, sem avisos de links |
| Operações públicas documentadas e cobertas por exemplos | 42/42 |
| Links internos e arquivos citados | Aprovados na validação local |
| CLI (`--version`, `--help`, `doctor`, `operacoes`) | 4/4 |
| Programas de referência (`check` + `run`) | 18/18 |
| Blocos ABT inline | 19 PASS, inclusive erro intencional; 0 FAIL |
| PythonCall opcional | 1 bloco não executado; dependência opcional |

O validador final registrou **46 PASS, 0 FAIL e 1 SKIP** em `logs/documentation/validation.json`. `docs/build/` foi gerado localmente, contém `index.html` e `search_index.js`, e usa `lang="pt-BR"`; o diretório de build é ignorado pelo Git. O log do build está em `logs/documentation/build.log`.

O primeiro teste inline detectou `2 ^ -3` em um exemplo: Julia rejeita potência inteira de expoente negativo. O exemplo foi corrigido para `2.0 ^ -3` e o limite foi documentado. Não foi feita alteração na linguagem. A referência gerada é conferida por `--check` para detectar divergência entre fonte editorial e páginas publicadas.

## Manutenção e limites

Para editar um contrato de operação, atualize `tools/generate_docs_reference.py`, gere novamente as páginas e execute o validador. Para novas operações, atualize também exemplo, testes diretos e diferenciais. O índice de operações cobre as funções ABT registradas, não todas as funções Julia importáveis. O site inicial documenta a versão atual da `main`; versionamento de páginas por tag não foi configurado, pois ainda não há release oficial a publicar. PythonCall continua opcional e exige ambiente próprio; o bloco de interoperação Python não foi executado nesta rodada. Logs históricos e relatórios anteriores permanecem intactos.
