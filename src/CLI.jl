const ABT_VERSION = "0.14.0"
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
  --depurar  Exibe também a exceção técnica completa; use antes do comando.

Códigos de saída: 0 sucesso, 1 erro no programa, 2 uso incorreto ou arquivo ausente.
"""

# Informational commands do not need to load the compiler or optional bridges.
if ARGS == ["--ajuda"] || ARGS == ["--help"] || ARGS == ["-h"]
    print(ABT_HELP)
    exit(0)
elseif ARGS == ["--versao"] || ARGS == ["--version"]
    println("ABT ", ABT_VERSION)
    exit(0)
end

using ABT

function cli_main(args::Vector{String})
    debug = !isempty(args) && first(args) == "--depurar"
    debug && (args = args[2:end])
    if !debug && length(args) == 1 && args[1] in ("--ajuda", "--help", "-h")
        print(ABT_HELP)
        return 0
    elseif !debug && length(args) == 1 && args[1] in ("--versao", "--version")
        println("ABT ", ABT_VERSION)
        return 0
    elseif !debug && args == ["operacoes"]
        for spec in ABT.abt_extension_catalog()
            println(spec.name, " [", spec.domain, "] — ", spec.input,
                    " → ", spec.output, " | pacote: ", spec.dependencies,
                    " | carga: ", spec.loading)
        end
        return 0
    end
    command, path = if length(args) == 1 && !startswith(args[1], "-") && !(args[1] in ("run", "check", "executar", "verificar", "doctor"))
        ("executar", args[1])
    elseif length(args) == 2 && args[1] in ("run", "executar", "check", "verificar") && !startswith(args[2], "-")
        (args[1], args[2])
    else
        print(stderr, ABT_HELP)
        return 2
    end
    if !isfile(path)
        println(stderr, "ABT: arquivo não encontrado: ", path)
        return 2
    end
    try
        source = read(path, String)
        ast = ABT.parse_program(ABT.tokenize(source))
        if command in ("check", "verificar")
            ABT.validate_ir(ABT.lower_ir(ast))
            println("Programa ABT válido.")
        else
            foreach(println, ABT.execute(ast))
        end
        return 0
    catch err
        println(stderr, path, ": ", ABT.render_diagnostic(err; humor="off", source=path))
        if debug
            println(stderr, "\nDetalhes técnicos:")
            showerror(stderr, err, catch_backtrace())
            println(stderr)
        end
        return 1
    end
end

exit(cli_main(copy(ARGS)))
