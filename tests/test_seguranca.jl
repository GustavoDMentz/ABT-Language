using Test

# Política de segurança da execução (src/Seguranca.jl): lista de módulos Python
# permitidos, --permitir-python e o modo --seguro.
const ROOT = dirname(@__DIR__)
const BIN = joinpath(ROOT, "bin", "abt")
const JULIA = Base.julia_cmd().exec[1]

function cli(dir, args...)
    out, outio = mktemp(); err, errio = mktemp()
    close(outio); close(errio)
    try
        command = Cmd(Cmd([BIN, String.(args)...]); dir=dir,
                      env=merge(Dict(ENV), Dict("ABT_JULIA" => JULIA)))
        process = run(pipeline(ignorestatus(command); stdout=out, stderr=err))
        return (process.exitcode, read(out, String), read(err, String))
    finally
        rm(out; force=true); rm(err; force=true)
    end
end

mktempdir() do dir
    write(joinpath(dir, "os.abt"), "usar Python.os\nmostrar 1\n")
    write(joinpath(dir, "ambiente.abt"), "mostrar ambiente(\"HOME\", \"padrao\")\n")
    write(joinpath(dir, "dados.txt"), "conteudo\n")
    write(joinpath(dir, "dentro.abt"), "mostrar ler_texto(\"dados.txt\")\n")
    fora = joinpath(mktempdir(), "segredo.txt")
    write(fora, "segredo\n")
    write(joinpath(dir, "fora.abt"), "mostrar ler_texto($(repr(fora)))\n")

    @testset "módulos Python fora da lista exigem --permitir-python" begin
        padrao = cli(dir, "run", "os.abt")
        @test padrao[1] == 1
        @test occursin("Security error", padrao[2] * padrao[3])
        @test occursin("--permitir-python", padrao[2] * padrao[3])
        # Com a permissão explícita, a verificação de segurança deixa passar
        # (o import em si depende do PythonCall, que é opcional).
        liberado = cli(dir, "--permitir-python", "run", "os.abt")
        @test !occursin("Security error", liberado[2] * liberado[3])
    end

    @testset "variável de ambiente permitida por padrão" begin
        r = cli(dir, "run", "ambiente.abt")
        @test r[1] == 0
    end

    @testset "--seguro" begin
        r = cli(dir, "--seguro", "run", "os.abt")
        @test r[1] == 1 && occursin("--seguro", r[2] * r[3])
        r = cli(dir, "--seguro", "--permitir-python", "run", "os.abt")  # --seguro prevalece
        @test r[1] == 1 && occursin("Security error", r[2] * r[3])
        r = cli(dir, "--seguro", "run", "ambiente.abt")
        @test r[1] == 1 && occursin("variáveis de ambiente", r[2] * r[3])
        r = cli(dir, "--seguro", "run", "dentro.abt")
        @test r[1] == 0 && strip(r[2]) == "conteudo"
        r = cli(dir, "run", "fora.abt")
        @test r[1] == 0 && strip(r[2]) == "segredo"      # sem --seguro, lê qualquer arquivo
        r = cli(dir, "--seguro", "run", "fora.abt")
        @test r[1] == 1 && occursin("fora da pasta do programa", r[2] * r[3])
    end

    @testset "--seguro não deixa um link simbólico escapar da pasta" begin
        if !Sys.iswindows()
            symlink(fora, joinpath(dir, "atalho.txt"))
            write(joinpath(dir, "via_link.abt"), "mostrar ler_texto(\"atalho.txt\")\n")
            r = cli(dir, "--seguro", "run", "via_link.abt")
            @test r[1] == 1 && occursin("fora da pasta do programa", r[2] * r[3])
        end
    end

    @testset "ajuda documenta as opções de segurança" begin
        r = cli(dir, "--ajuda")
        @test r[1] == 0
        @test occursin("--seguro", r[2]) && occursin("--permitir-python", r[2])
    end
end
