# ABT

ABT é uma linguagem experimental de alto nível. Julia executa o runtime principal; PythonCall é opcional para programas que importam Python. A interface cotidiana é o comando `abt`.

## Instalação por usuário no Ubuntu

Instale Julia 1.13.3 e deixe `julia` no `PATH` ou defina `ABT_JULIA` com o caminho do executável. O ABT **exige Julia instalada separadamente**. Python 3 é necessário apenas para instalar/atualizar/desinstalar; PythonCall é opcional para programas que importam Python.

Na pasta extraída do projeto, execute:

```bash
python3 tools/install.py
abt doctor
```

O instalador coloca os arquivos em `~/.local/share/abt`, cria `~/.local/bin/abt` e pré-compila o módulo ABT no cache local de Julia. Essa etapa pode levar alguns segundos, mas evita pagar o custo de compilação na primeira execução. Se `~/.local/bin` não estiver no `PATH`, o instalador informa como resolver; não altera arquivos de configuração do shell. Funciona de qualquer diretório e pode ser executado novamente para atualizar. Recusa instalações conflitantes e modificações locais nos arquivos instalados. Para desinstalar, execute `python3 tools/uninstall.py` a partir de uma cópia do projeto. A instalação não exige `sudo` nem a pasta de extração depois de concluída.

Crie e execute um primeiro programa:

```bash
printf 'mostrar "Olá, mundo!"\n' > ola.abt
abt ola.abt
abt check ola.abt
```

## Comandos

```bash
abt examples/pipeline_basico.abt
abt run examples/pipeline_basico.abt
abt executar examples/pipeline_basico.abt
abt check examples/pipeline_basico.abt
abt verificar examples/pipeline_basico.abt
abt doctor
abt --version
abt --help
abt --versao
abt --ajuda
```

`run`/`executar` rodam o interpretador e imprimem a saída do programa. `check`/`verificar` fazem análise léxica, sintática e validação do IR sem executar o programa nem carregar pacotes declarados. Códigos de saída: 0 sucesso, 1 erro de compilação/execução do programa, 2 argumentos inválidos, arquivo ausente ou ambiente incompatível. `abt --depurar run arquivo.abt` inclui a exceção técnica e o rastreamento de pilha. `doctor` informa o caminho da instalação e verifica arquivos essenciais e Julia 1.13.3.

Para reduzir a latência de programas curtos, a CLI usa o módulo ABT pré-compilado e inicia Julia com `--compile=min`. Para programas grandes ou computacionalmente intensivos, use `ABT_JULIA_COMPILE=all abt run arquivo.abt` para permitir compilação JIT completa; as duas opções usam o mesmo interpretador ABT. Em uma sonda com 10.000 atribuições, `all` foi cerca de quatro vezes mais rápido que o padrão `min`. `no` também é aceito para diagnóstico, mas não é o padrão. Veja `docs/RELATORIO_DESEMPENHO_0118.md` para medições e limites.

O [benchmark de escalabilidade](docs/BENCHMARK_ESCALABILIDADE.md) reúne dez medições por modo para 100, 1.000 e 10.000 incrementos, gráficos, dados brutos e o limite observado em 100.000 incrementos.

A [correção da validação de programas grandes](docs/CORRECAO_VALIDACAO_PROGRAMAS_GRANDES.md) explica por que esse limite rejeitava programas válidos e registra as execuções de 100.000 e 1.000.000 incrementos após a correção.

Nove [aplicações ABT executáveis](applications/README.md) cobrem estatística, CSV, FASTA, vendas tabulares, distribuição de categorias e uma rede de condutâncias. A [avaliação do ecossistema](docs/ECOSSISTEMA_APLICACOES_0118.md) registra capacidades, pacotes e limites.

A [primeira camada de abstração](docs/ABSTRACAO_BIBLIOTECA_0118.md) acrescenta `descrever` e `registro` como funções de biblioteca, com resultados estruturados e sem sintaxe nova.

A [camada de arquivos e tabelas tipadas](docs/ARQUIVOS_TABELAS_0118.md) acrescenta leitura de texto/CSV, esquema explícito, filtros, transformação, resumos e apresentação estruturada. CSV.jl e Tables.jl são dependências Julia do projeto; PythonCall continua opcional.

A [camada de bioinformática](docs/BIOINFORMATICA_0118.md) acrescenta leitura FASTA explícita de DNA/RNA com FASTX.jl e BioSequences.jl, resumo em fluxo e métricas por registro.

As [extensões Julia para agrupamento tabular e JSON](docs/EXTENSOES_JULIA_0118.md) acrescentam operações ABT estruturadas, contratos explícitos, duas aplicações e testes diferenciais. JSON.jl é carregado somente quando `codificar_json` é executado. [Resultados de testes e desempenho](docs/RESULTADOS_EXTENSOES_0118.md).

A [arquitetura modular de operações](docs/ARQUITETURA_EXTENSOES_0118.md) registra domínio, assinatura, contratos e dependências em um lugar. `abt operacoes` mostra o catálogo. As novas integrações usam StatsBase.jl para frequências e LinearAlgebra para resolver sistemas simétricos definidos positivos. [Resultados e reprodução](docs/RESULTADOS_ARQUITETURA_EXTENSOES_0118.md).

Para usar um pacote Julia opcional, declare módulo, UUID, versão e funções em `ABT.packages.toml`, resolva a dependência no ambiente Julia com seus mecanismos nativos e faça import explícito no programa. `examples/pacote_dates.abt` é um exemplo que usa a biblioteca padrão `Dates`. PythonCall continua opcional; o ABT não é sandbox para código externo.

## VS Code

O projeto inclui tarefas em `.vscode/tasks.json` para executar e verificar o arquivo atual usando `~/.local/bin/abt`; elas mostram uma mensagem se o ABT não estiver instalado. A extensão mínima em `vscode/abt-language` reconhece `.abt` e fornece realce simples. Para instalá-la localmente, copie essa pasta para `~/.vscode/extensions/abt-language-0.1.0` e reinicie o VS Code. O realce é lexical e não substitui a validação feita por `abt check`. Não há LSP, autocomplete semântico ou depurador interativo.

## Desenvolvimento e compatibilidade

O módulo público está em `src/ABT.jl`; a CLI está em `src/CLI.jl`; o runtime externo está em `src/Runtime/Bridge.jl`. `pseudo.jl` e `bridge_runtime.jl` são adaptadores temporários para testes e ferramentas antigas. Arquivos `.pseudo` históricos continuam executáveis pelo adaptador. Consulte `docs/MAPA_IDENTIDADE.md` para a classificação dos nomes legados e `docs/PLANO_DISTRIBUICAO.md` para a investigação de distribuição autossuficiente.

Para rodar todos os testes históricos e os novos testes de CLI:

```bash
python3 tests/run_all_tests.py --julia julia --timeout 180
```

Defina `ABT_REQUIRE_PYTHON=1` e configure PythonCall/NumPy se quiser exigir a execução dos testes Python opcionais.

Para testar instalação e CLI em diretórios temporários, execute `ABT_TEST_JULIA=/caminho/para/julia python3 tests/test_install_cli.py`.

### Lote científico ABT 0.11.8

Operadores unários e exponenciação, operações de dados/estatística/visualização/bioinformática e três aplicações completas: [contratos e execução](docs/LOTE_CIENTIFICO_0118.md).

Resultados, limitações e medições do lote: [relatório consolidado](docs/RELATORIO_LOTE_0118.md).

## Organização do repositório

Testes ficam em `tests/`, medições em `benchmarks/`, ferramentas em `tools/` e evidências de execução em `logs/`. O histórico e a validação da mudança estão em [docs/REORGANIZACAO_REPOSITORIO.md](docs/REORGANIZACAO_REPOSITORIO.md).

## Bioestatística 0.12.0

Operações modulares para inferência, correlação, distribuições e regressão linear estão descritas em [docs/BIOESTATISTICA_0120.md](docs/BIOESTATISTICA_0120.md). Os exemplos executáveis com dados sintéticos ficam em `applications/biostatistics/`.

A validação independente da versão 0.12.0 está em [docs/AUDITORIA_FINAL_BIOESTATISTICA_0120.md](docs/AUDITORIA_FINAL_BIOESTATISTICA_0120.md).
