include(joinpath(@__DIR__, "src", "ABT.jl"))
using Test

@testset "contratos internos das extensões" begin
    cycle = Any[]
    push!(cycle, cycle)
    @test_throws ErrorException ABT.abt_std_json(cycle, "erro")
    @test occursin("coleção cíclica", sprint(showerror, try ABT.abt_std_json(cycle, "erro") catch e; e end))
    for value in (NaN, Inf, -Inf)
        @test occursin("número não finito", sprint(showerror, try ABT.abt_std_json(value, "erro") catch e; e end))
    end
    @test ABT.abt_std_json((;x=missing), "nulo") == "{\"x\":null}"
end
