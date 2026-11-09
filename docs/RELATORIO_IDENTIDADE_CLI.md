# ABT — identidade, CLI e encapsulamento

## Escopo executado

A baseline antes das alterações registrou 37 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL e 0 TIMEOUT (`logs/historical/identity_baseline.log`). O código fonte principal foi movido de `pseudo.jl` para `src/ABT.jl`, com módulo público `ABT`. A fronteira externa foi movida para `src/Runtime/Bridge.jl`. `pseudo.jl` e `bridge_runtime.jl` são adaptadores legados; testes e scripts antigos continuam a funcionar. O novo lançador `bin/abt` resolve sua própria localização e chama `src/CLI.jl`. Nenhuma regra do lexer, parser, IR, otimizador, interpretador, gerador ou manifesto de pacotes foi alterada.

`abt arquivo.abt`, `abt executar`, `abt verificar`, `abt --versao` e `abt --ajuda` têm contratos e códigos de saída documentados em `docs/MAPA_IDENTIDADE.md`. `--depurar` mostra a exceção técnica completa. A ajuda normal não apresenta invocação Julia; a instalação documenta Julia 1.13.3 como dependência real. O CLI não depende de caminhos absolutos do ambiente de desenvolvimento.

O VS Code recebe associação `.abt`, tarefas para executar e verificar e uma extensão mínima de gramática em `vscode/abt-language`. Os JSON foram validados sintaticamente. A extensão não foi instalada no perfil pessoal do usuário nem testada dentro da interface gráfica do VS Code; o README contém o procedimento de instalação. A distribuição autossuficiente não foi construída; `docs/PLANO_DISTRIBUICAO.md` registra opções, medições e riscos.

## Verificações

- `tests/test_cli_identity.jl`: 20 asserções; cobriu ajuda, versão, três formas de execução/verificação, diretório externo, pacote, erros, debug, caminho com espaço e Unicode, link simbólico e adaptador legado. Resultado: PASS (`logs/historical/cli_identity_test.log`).
- `tools/verify_cli_examples.py`: seis exemplos `.abt` executados pelo novo CLI e pelo adaptador legado com código de saída, stdout e stderr idênticos. Resultado: 6/6 PASS (`logs/historical/cli_examples_identity.json`, `logs/historical/cli_examples_identity.log`).
- Suíte histórica completa **após a última alteração**, incluindo a resposta rápida de `--versao`: 38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT (`logs/historical/identity_final_full.log`, `logs/test_logs/summary.json`). PROBE não equivale a aprovação.
- `tools/run_cli_examples.py`: três exemplos de coleções passaram na comparação com Julia gerado sem otimização e com otimização (`logs/historical/identity_generated_examples.log`, `logs/historical/cli_examples_results.json`).

## Limites

Os diagnósticos sintáticos existentes preservam linha e coluna; nem todo erro de runtime do ABT anterior possui localização de origem, então o CLI acrescenta o caminho do arquivo sem inventar uma posição. A separação interna de compiler/IR/backend em muitos módulos foi adiada: esta etapa separou a interface pública, a CLI e o bridge, preservando o núcleo funcional. Nomes de helpers `pseudo_*` no Julia gerado são internos e foram mantidos por compatibilidade textual com testes legados. Arquivos `.pseudo` históricos continuam disponíveis.

O modo `verificar` não executa o programa e não garante que uma chamada externa tenha sucesso em runtime. Pacotes opcionais continuam governados por `ABT.packages.toml` e pelo ambiente Julia. A interoperabilidade Python mantém os efeitos e permissões de Python; o ABT não é sandbox.

## Distribuição e desempenho observados

O projeto tem cerca de 1,7 MiB e a instalação Julia 1.13.3 local tem cerca de 1,1 GiB. Cinco processos por comando deram medianas de 0,20 s/206 MiB para `--versao`, 5,21 s/364 MiB para `verificar` e 5,41 s/365 MiB para `executar` no exemplo básico (`benchmarks/results/distribution_measurements.json`). Antes da resposta rápida, `--versao` tinha 3,76 s/360 MiB (`benchmarks/results/distribution_measurements_before.json`). Os números incluem o processo Julia e são preliminares para este hardware; não representam uma distribuição autossuficiente.
