# ABT 0.10.2: exact imported module must win over descendants.
include(joinpath(@__DIR__, "..", "bridge_runtime.jl"))
using Test
@testset "overlapping Python namespace resolution" begin
    ns = ABTPythonNamespace()
    parent = Dict("marker" => "parent")
    child = Dict("marker" => "child")
    ns.modules["pkg"] = parent
    ns.modules["pkg.sub"] = child
    @test abt_external_field(abt_external_field(ns, "pkg"), "marker") == "parent"
    @test abt_external_field(ABTPythonNamespace(ns.modules, "pkg"), "sub") === child
    onlychild = ABTPythonNamespace(Dict{String,Any}("pkg.sub" => child), "")
    @test abt_external_field(onlychild, "pkg") isa ABTPythonNamespace
end
# The generated resolver must preserve the same behavior for overlapping imports.
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo
generated = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("usar Python.pkg\nusar Python.pkg.sub\nmostrar Python.pkg.sub.marker")))
@test occursin("return abt_namespace(obj.modules, path)", generated)
