include(joinpath(@__DIR__, "CLIText.jl"))

# Informational commands do not need to load the compiler or optional bridges.
if ARGS == ["--ajuda"] || ARGS == ["--help"] || ARGS == ["-h"]
    print(ABT_HELP)
    exit(0)
elseif ARGS == ["--versao"] || ARGS == ["--version"]
    println("ABT ", ABT_VERSION)
    exit(0)
end

using ABT

exit(ABT.cli_main(copy(ARGS)))
