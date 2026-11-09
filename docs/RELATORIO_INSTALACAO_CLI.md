# ABT 0.11.8 — instalação e CLI

Este relatório registra a entrega anterior da instalação. Para a pré-compilação e a validação atual de desempenho, consulte `RELATORIO_DESEMPENHO_0118.md`.

## Origem e escopo

O arquivo `abt_identidade_cli.zip` citado na missão não estava presente na pasta do projeto desta sessão. Usei a árvore `abt_identity_cli/`, entrega anterior que contém a mesma CLI de identidade, como base de trabalho. A árvore sincronizada `sources/` não foi alterada. As mudanças se limitam à interface de comando, instalação, tarefas VS Code, testes e documentação; `src/ABT.jl` e `src/Runtime/Bridge.jl` permaneceram intactos.

## Estado inicial

Ponto de entrada: `bin/abt` resolve seu próprio caminho e chama Julia para `src/CLI.jl`; este carrega `src/ABT.jl` apenas para verificar ou executar programas. Julia é obrigatória; PythonCall é carregado apenas quando um programa ABT usa a ponte Python.

Comando executado antes das mudanças, dentro desta árvore:

```bash
ABT_REQUIRE_PYTHON=1 JULIA_DEPOT_PATH=/home/gumentz/.codex/.chatgpt-projects/g-p-6aed28c64c608191837b0b5384a649bb/abt_v116/.julia_depot JULIA_PYTHONCALL_EXE=/usr/bin/python3 python3 tests/run_all_tests.py --julia /home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia --timeout 180 > logs/historical/install_baseline.log 2>&1
```

Resultado: 38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT. As duas sondas são exploratórias e não equivalem a aprovação funcional. Os detalhes por suíte estão em `logs/historical/install_baseline.log` e `logs/test_logs/summary.json` (o último é substituído pela execução final).

## Alterações

- `run`/`check`, `--version`/`--help` somados aos comandos e aliases anteriores. `doctor` verifica arquivos essenciais e Julia 1.13.3, inclusive quando Julia está ausente. Comandos reservados sem argumento retornam código 2.
- `tools/install.py` instala por usuário em `~/.local/share/abt`, com link `~/.local/bin/abt`, sem `sudo` ou edição de configuração do shell. A instalação guarda um manifesto de hashes; atualização e desinstalação recusam arquivos alterados, extras, ausentes ou link conflitante. A troca da árvore na atualização usa preparação em diretório temporário e restauração se a troca falhar.
- `tools/uninstall.py` remove apenas uma instalação verificada. A segunda desinstalação é inofensiva.
- As tarefas VS Code executam o ABT instalado e dão mensagem explícita quando falta. O suporte a `.abt` e o realce lexical existentes permanecem.

## Reprodução da validação final

```bash
ABT_TEST_JULIA=/home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia python3 tests/test_install_cli.py > logs/historical/install_cli_tests.log 2>&1
ABT_REQUIRE_PYTHON=1 JULIA_DEPOT_PATH=/home/gumentz/.codex/.chatgpt-projects/g-p-6aed28c64c608191837b0b5384a649bb/abt_v116/.julia_depot JULIA_PYTHONCALL_EXE=/usr/bin/python3 python3 tests/run_all_tests.py --julia /home/gumentz/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia --timeout 180 > logs/historical/install_final_full.log 2>&1
```

O teste de instalação usa `HOME` temporário e não altera a instalação real. Ele cobre instalação, repetição, atualização, desinstalação, conflitos de arquivo e diretório, caminhos Unicode/com espaços, execução de outro diretório, comandos, aliases, códigos de saída, Julia ausente/incompatível, tarefas VS Code e um exemplo ABT anterior. Resultado: 5 testes aprovados em `logs/historical/install_cli_tests.log`. Uma asserção intermediária do novo teste consultava o índice errado do array de argumentos do VS Code; foi corrigida e a suíte foi repetida integralmente.

## Limites

- A versão homologada do runtime é exatamente Julia 1.13.3. Outras versões são recusadas até validação.
- PythonCall permanece opcional. O instalador não instala Julia, PythonCall nem pacotes externos.
- A instalação por usuário pressupõe Python 3 e utilitários Linux usuais para o lançador; o uso diário exige Julia e não exige Python 3 para programas sem interop Python.
- A verificação `check` valida a linguagem sem executar o programa; não garante que imports externos ou efeitos em runtime funcionarão.
- VS Code recebeu tarefas e realce lexical. Sua interface gráfica não foi exercitada automaticamente nesta sessão.
- O bundle autossuficiente com PackageCompiler.jl é apenas hipótese documentada em `PLANO_DISTRIBUICAO.md`; não foi criado nem aprovado.

## Resultado final da suíte histórica

Resultado executado: 38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT. Ver `logs/historical/install_final_full.log` e `logs/test_logs/summary.json` para detalhes por suíte. Nenhuma sonda exploratória é contada como teste funcional aprovado. Não houve testes históricos ignorados nesta execução com `ABT_REQUIRE_PYTHON=1`.
