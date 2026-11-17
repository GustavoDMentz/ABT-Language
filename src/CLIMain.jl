# Implementação da CLI pública, dentro do pacote para entrar na imagem pré-compilada.
# O script src/CLI.jl apenas trata --help/--version e chama ABT.cli_main.
function cli_main(args::Vector{String})
    debug = !isempty(args) && first(args) == "--depurar"
    debug && (args = args[2:end])
    # Opções de segurança (ver src/Seguranca.jl); aceitas antes do comando, em qualquer ordem.
    seguro = false; permitir_python = false
    while !isempty(args) && first(args) in ("--seguro", "--permitir-python")
        first(args) == "--seguro" ? (seguro = true) : (permitir_python = true)
        args = args[2:end]
    end
    if !debug && length(args) == 1 && args[1] in ("--ajuda", "--help", "-h")
        print(ABT_HELP)
        return 0
    elseif !debug && length(args) == 1 && args[1] in ("--versao", "--version")
        println("ABT ", ABT_VERSION)
        return 0
    elseif !debug && args == ["operacoes"]
        for spec in abt_extension_catalog()
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
    abt_configurar_seguranca!(; seguro, permitir_python, arquivo=path)
    try
        source = read(path, String)
        ast = parse_program(tokenize(source))
        if command in ("check", "verificar")
            validate_ir(lower_ir(ast))
            println("Programa ABT válido.")
        else
            foreach(println, execute(ast))
        end
        return 0
    catch err
        println(stderr, path, ": ", render_diagnostic(err; humor="off", source=path))
        if debug
            println(stderr, "\nDetalhes técnicos:")
            showerror(stderr, err, catch_backtrace())
            println(stderr)
        end
        return 1
    end
end
