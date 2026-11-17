# Política de segurança da execução de programas ABT.
#
# A ABT NÃO é um sandbox: um programa .abt tem os privilégios de quem o executa.
# Estas regras reduzem o risco de rodar programas de origem duvidosa por engano:
#   1. `usar Python.<modulo>` só aceita módulos de uma lista de permitidos
#      (bibliotecas científicas e de texto); os demais exigem `--permitir-python`
#      (ou ABT_PERMITIR_PYTHON=1).
#   2. `--seguro` bloqueia `usar Python`, `ambiente` e qualquer leitura ou escrita
#      de arquivos fora da pasta do programa.

# Módulos Python de nível raiz permitidos por padrão (sem acesso direto ao sistema).
const ABT_PYTHON_PERMITIDOS = Set([
    "numpy", "scipy", "pandas", "math", "cmath", "statistics", "random", "json", "re",
    "datetime", "decimal", "fractions", "itertools", "collections", "string",
    "textwrap", "operator", "functools", "Bio", "sklearn", "matplotlib",
])

const ABT_MODO_SEGURO = Ref(false)
const ABT_PERMITIR_PYTHON = Ref(false)
const ABT_DIR_PROGRAMA = Ref("")

abt_python_liberado() = ABT_PERMITIR_PYTHON[] || get(ENV, "ABT_PERMITIR_PYTHON", "") == "1"

# Ajusta a política para uma execução (a CLI chama isto antes de executar o programa).
function abt_configurar_seguranca!(; seguro::Bool=false, permitir_python::Bool=false, arquivo::AbstractString="")
    ABT_MODO_SEGURO[] = seguro
    ABT_PERMITIR_PYTHON[] = permitir_python
    ABT_DIR_PROGRAMA[] = isempty(arquivo) ? pwd() : dirname(abspath(arquivo))
    return nothing
end

function abt_verificar_modulo_python(path::AbstractString)
    ABT_MODO_SEGURO[] &&
        error("Security error: 'usar Python' não é permitido no modo --seguro")
    raiz = String(first(split(path, '.')))
    raiz in ABT_PYTHON_PERMITIDOS || abt_python_liberado() ||
        error("Security error: o módulo Python '$raiz' não está na lista de permitidos; " *
              "se confia neste programa, execute com --permitir-python")
    return nothing
end

# Resolve links simbólicos do trecho existente do caminho (o destino pode ainda não existir).
function abt_caminho_real(path::AbstractString)
    p = abspath(path)
    resto = String[]
    while !ispath(p) && dirname(p) != p
        pushfirst!(resto, basename(p))
        p = dirname(p)
    end
    real = ispath(p) ? realpath(p) : p
    return isempty(resto) ? real : joinpath(real, resto...)
end

# No modo --seguro, só permite caminhos dentro da pasta do programa.
function abt_verificar_caminho(operacao::AbstractString, path)
    ABT_MODO_SEGURO[] || return path
    path isa AbstractString || return path
    base = abt_caminho_real(isempty(ABT_DIR_PROGRAMA[]) ? pwd() : ABT_DIR_PROGRAMA[])
    alvo = abt_caminho_real(path)
    (alvo == base || startswith(alvo, base * Base.Filesystem.path_separator)) ||
        error("Security error: $operacao: o caminho '$path' está fora da pasta do programa (modo --seguro)")
    return path
end

function abt_verificar_ambiente(operacao::AbstractString)
    ABT_MODO_SEGURO[] &&
        error("Security error: $operacao: variáveis de ambiente não estão disponíveis no modo --seguro")
    return nothing
end

# Funções da biblioteca padrão que tocam o sistema: posição do argumento com o caminho.
const ABT_ARGUMENTO_CAMINHO = Dict(
    "ler_texto" => 1, "ler_csv" => 1, "ler_fasta" => 1, "ler_fastq" => 1,
    "exportar_csv" => 2, "exportar_fastq" => 2, "salvar_figura" => 2,
)

# Envolve a função da biblioteca padrão com a verificação de segurança. Vale só para o
# interpretador: o código Julia gerado embute as funções e é independente desta política.
function abt_proteger_funcao(nome::AbstractString, implementacao)
    if nome == "ambiente"
        return (args...) -> (abt_verificar_ambiente("ambiente"); implementacao(args...))
    elseif haskey(ABT_ARGUMENTO_CAMINHO, nome)
        posicao = ABT_ARGUMENTO_CAMINHO[nome]
        return function (args...)
            length(args) >= posicao && abt_verificar_caminho(nome, args[posicao])
            return implementacao(args...)
        end
    end
    return implementacao
end
