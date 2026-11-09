using Test
include("test_differential_1000.jl")
const P = Pseudo

@testset "ABT package manifest and explicit Julia calls" begin
    @test P.PYTHONCALL_CACHE[] === nothing
    @test haskey(P.ABT_PACKAGES, "Dates")
    @test P.ABT_PACKAGES["Dates"].version == "1.11.0"
    for source in (
        "usar Julia.Dates\nd=Julia.Dates.Date(\"2026-11-06\")\nmostrar d\nmostrar Julia.Dates.year(d)",
        "usar Julia.Dates\nmostrar Julia.Dates.year(Julia.Dates.Date(\"2000-01-01\"))",
        "usar Julia.Dates\nusar Julia.Dates\nmostrar Julia.Dates.year(Julia.Dates.Date(\"2024-02-29\"))",
    )
        ok, why, _ = run_one(1, "packages", source)
        @test ok
        @test isempty(why)
    end
    for source in (
        "mostrar Julia.Dates.Date(\"2026-11-06\")",
        "usar Julia.Dates\nmostrar Julia.Dates.month(Julia.Dates.Date(\"2026-11-06\"))",
        "usar Julia.Dates\nmostrar Julia.Dates.year()",
        "usar Julia.NotDeclared\nmostrar 1",
    )
        @test_throws Exception P.generate(P.parse_program(P.tokenize(source)))
    end
    @test_throws Exception P.abt_load_julia_package("Dates", P.ABT_PACKAGES["Dates"].uuid, "0.0.0")
    @test_throws Exception P.abt_load_julia_package("AbsentABTPackage", "00000000-0000-0000-0000-000000000001", "1.0.0")
    for data in (
        "[julia.Dates]\nuuid=\"ade2ca70-3891-5945-98fb-dc099432e06a\"\nversion=\"1.11.0\"\nfunctions={}",
        "[julia.Base]\nuuid=\"ade2ca70-3891-5945-98fb-dc099432e06a\"\nversion=\"1.11.0\"\nfunctions={sum=1}",
        "[julia.Dates]\nuuid=\"bad\"\nversion=\"1.11.0\"\nfunctions={Date=1}",
    )
        path, io = mktemp()
        try
            write(io, data); flush(io)
            @test_throws Exception P.abt_package_specs(path)
        finally
            close(io); rm(path;force=true)
        end
    end
end
