# Textos públicos da CLI. Incluído pelo script src/CLI.jl (caminho rápido de --help/--version,
# sem carregar a ABT) e pelo módulo ABT (cli_main pré-compilado). Fonte única de verdade.
const ABT_VERSION = "0.15.0"
const ABT_HELP = """ABT — linguagem experimental

Uso:
  abt arquivo.abt
  abt run arquivo.abt
  abt executar arquivo.abt
  abt check arquivo.abt
  abt verificar arquivo.abt
  abt doctor
  abt operacoes
  abt --version
  abt --help
  abt --versao
  abt --ajuda

Opções:
  --depurar         Exibe também a exceção técnica completa; use antes do comando.
  --perfil NOME     Perfil de execução: padrao (recomendado) ou rapido.

Códigos de saída: 0 sucesso, 1 erro no programa, 2 uso incorreto ou arquivo ausente.
"""
