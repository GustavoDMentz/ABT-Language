include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# No-Python code must still block private attributes.
no_py = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("mostrar 1")))
@assert occursin("startswith(field", no_py)
@assert occursin("atributo privado não permitido", no_py)

# Python and non-Python generated code enforce the same private-attribute policy.
with_py = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("usar Python.math\nmostrar Python.math.sqrt(9)")))
@assert occursin("atributo privado não permitido", with_py)

# Interpreter must not modify caller-owned environment.
env = Dict{String,Any}("x" => 2)
result = Pseudo.execute(Pseudo.parse_program(Pseudo.tokenize("mostrar x")); env=env)
@assert result == ["2"]
@assert env == Dict{String,Any}("x" => 2)

# Internal runtime keys are not user-provided values.
try
    Pseudo.execute(Pseudo.parse_program(Pseudo.tokenize("mostrar 1")); env=Dict{String,Any}("__abt_output__" => "injected"))
    error("expected reserved key rejection")
catch err
    occursin("reserved internal environment key", sprint(showerror, err)) || rethrow()
end

println("ABT 0.10.8 regression checks OK")
