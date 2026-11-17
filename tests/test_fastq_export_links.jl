using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# exportar_fastq não pode truncar a própria entrada: nem pelo mesmo caminho, nem por um link
# simbólico ou físico que aponte para ela (antes só o caminho absoluto idêntico era barrado).
const ROOT = dirname(@__DIR__)
const ORIGINAL = joinpath(ROOT, "applications", "scientific_0130", "data", "reads.fastq")

interpreted(source) = join(execute(parse_program(tokenize(source))), "\n")
function generated_error(source; optimize)
    code = generate(parse_program(tokenize(source)); optimize)
    err = IOBuffer()
    run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$ROOT -e $code`); stdout=devnull, stderr=err))
    String(take!(err))
end
program(entrada, saida) = """
leituras = ler_fastq("$entrada", "DNA", "rejeitar", "phred33")
mostrar exportar_fastq(leituras, "$saida")
"""

mktempdir() do dir
    entrada = joinpath(dir, "entrada.fastq")
    cp(ORIGINAL, entrada)
    conteudo = read(entrada, String)
    alvos = Dict("mesmo caminho" => entrada, "caminho com ./" => joinpath(dir, ".", "entrada.fastq"))
    if !Sys.iswindows()
        simbolico = joinpath(dir, "atalho.fastq"); symlink(entrada, simbolico)
        alvos["link simbólico"] = simbolico
        fisico = joinpath(dir, "fisico.fastq")
        try
            Base.Filesystem.hardlink(entrada, fisico)
            alvos["link físico"] = fisico
        catch
        end
    end
    for (nome, saida) in alvos
        @testset "destino = entrada ($nome)" begin
            fonte = program(entrada, saida)
            erro = try interpreted(fonte); "" catch e; sprint(showerror, e) end
            @test occursin("próprio arquivo de entrada", erro)
            @test read(entrada, String) == conteudo
            for optimize in (false, true)
                @test occursin("próprio arquivo de entrada", generated_error(fonte; optimize))
                @test read(entrada, String) == conteudo
            end
        end
    end
    @testset "destino diferente continua funcionando" begin
        saida = joinpath(dir, "saida.fastq")
        @test occursin("leituras_escritas", interpreted(program(entrada, saida)))
        @test isfile(saida) && read(entrada, String) == conteudo
    end
end
