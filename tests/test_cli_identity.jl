using Test

const ROOT = dirname(@__DIR__)
const BIN = joinpath(ROOT, "bin", "abt")
const JULIA = Base.julia_cmd().exec[1]

function cli(args...; dir=ROOT, binary=BIN)
    out, outio = mktemp(); err, errio = mktemp()
    close(outio); close(errio)
    try
        command = Cmd(Cmd([binary, String.(args)...]); dir=dir,
                      env=merge(Dict(ENV), Dict("ABT_JULIA"=>JULIA)))
        process = run(pipeline(ignorestatus(command); stdout=out, stderr=err))
        return (process.exitcode, read(out, String), read(err, String))
    finally
        rm(out; force=true); rm(err; force=true)
    end
end

@testset "ABT public CLI and legacy adapter" begin
    help = cli("--ajuda"; dir="/tmp")
    @test help[1] == 0
    @test occursin("abt verificar", help[2])
    @test !occursin("Julia", help[2])
    @test cli("--versao"; dir="/tmp") == (0, "ABT 0.13.0\n", "")
    example = joinpath(ROOT, "examples", "pipeline_basico.abt")
    direct = cli(example; dir="/tmp")
    explicit = cli("executar", example; dir="/tmp")
    @test direct == explicit
    @test direct == (0, "[30, 40]\n", "")
    @test cli("verificar", example; dir="/tmp") == (0, "Programa ABT válido.\n", "")
    @test cli("verificar", joinpath(ROOT,"examples","pacote_dates.abt"); dir="/tmp")[1] == 0
    @test cli("executar", joinpath(ROOT,"examples","pacote_dates.abt"); dir="/tmp")[2] == "2026-11-06\n2026\n"
    @test cli("arquivo-inexistente.abt"; dir="/tmp")[1] == 2
    @test cli("--invalido"; dir="/tmp")[1] == 2
    @test cli("executar"; dir="/tmp")[1] == 2
    mktempdir(prefix="ABT espaço α ") do temp
        source = joinpath(temp, "olá mundo.abt")
        write(source, "mostrar \"olá\"\n")
        @test cli(source; dir="/tmp") == (0, "olá\n", "")
        link = joinpath(temp, "abt")
        symlink(BIN, link)
        @test cli(source; dir="/tmp", binary=link) == (0, "olá\n", "")
        write(source, "mostrar (\n")
        broken = cli("verificar", source; dir="/tmp")
        @test broken[1] == 1
        @test occursin(source, broken[3])
        debug = cli("--depurar", "verificar", source; dir="/tmp")
        @test debug[1] == 1
        @test occursin("Detalhes técnicos", debug[3])
        write(source, "usar Julia.Dates\nmostrar Julia.Dates.Date(\"não-é-data\")\n")
        @test cli("executar", source; dir="/tmp")[1] == 1
    end
    legacy = Cmd(Cmd([JULIA,"--startup-file=no",joinpath(ROOT,"pseudo.jl"),example]);dir="/tmp")
    @test read(legacy,String) == direct[2]
end
