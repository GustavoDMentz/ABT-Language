include("benchmark_118.jl")
include(joinpath(@__DIR__, "..", "tests", "test_differential_1000.jl"))
failures=String[]
for (name,source,native) in workloads()
    ast=Pseudo.parse_program(Pseudo.tokenize(source))
    output=String[]
    Pseudo.execute(ast;output)
    expected=join(output,"\n") * (isempty(output) ? "" : "\n")
    got=capture(native)
    if got.stdout != expected || got.error != ""
        push!(failures,"$name native=$(repr(got.stdout)) ABT=$(repr(expected)) error=$(got.error)")
    end
end
write("logs/benchmark_equivalence_current.log",isempty(failures) ? "$(length(workloads()))/$(length(workloads())) equivalent\n" : join(failures,"\n"))
println(read("logs/benchmark_equivalence_current.log",String))
isempty(failures) || exit(1)
