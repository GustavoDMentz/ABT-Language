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
  --seguro          Bloqueia 'usar Python', 'ambiente' e arquivos fora da pasta do programa.
  --permitir-python Libera qualquer módulo Python em 'usar Python' (só para programas de confiança).

Segurança: um programa ABT roda com os seus privilégios; a ABT não é um sandbox.
Não execute programas de origem desconhecida sem --seguro.

Códigos de saída: 0 sucesso, 1 erro no programa, 2 uso incorreto ou arquivo ausente.
"""
