using Test
include("pseudo.jl")
using .Pseudo

compile(src) = generate(validate_ir(lower_ir(parse_program(tokenize(src)))))
@testset "ABT 0.9 — contrato estático Python" begin
 for src in [
  "usar Python.numpy\nmostrar Python.numpy.sum([1,2,3])",
  "usar Python.Bio.Seq\nmostrar Python.Bio.Seq.Seq(\"ACGT\")",
  "usar Python.pandas\ndf = Python.pandas.DataFrame([1,2])\nmostrar df.shape",
 ]
  @test occursin("abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport", compile(src))
 end
 for (src, fragment) in [
  ("mostrar Python.numpy.sum([1])", "before import"),
  ("usar Python.numpy\nmostrar Python.numpy.__dict__", "private"),
  ("usar Python.numpy\nmostrar Python.numpy.__dict__([1])", "private"),
  ("usar Python._private", "private"),
 ]
  err = try compile(src); nothing catch e; e end
  @test err isa Exception
  @test occursin(fragment, lowercase(sprint(showerror, err)))
 end
end

@testset "ABT 0.9 — integração Python (opcional)" begin
 available = try
  @eval import PythonCall
  PythonCall.pyimport("numpy")
  true
 catch
  false
 end
 if available
  np = PythonCall.pyimport("numpy")
  src = "usar Python.numpy\na = Python.numpy.array([1,2,3,4])\nmostrar Python.numpy.sum(a)"
  ast = parse_program(tokenize(src))
  output = execute(ast)
  @test length(output) == 1
  @test occursin("10", output[1])
  generated = compile(src)
  @test occursin("abt_import_python!(Python, \"numpy\", abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport)", generated)
  @test occursin("getproperty", generated)
  @test np !== nothing
 else
  @info "Teste de runtime Python ignorado: PythonCall.jl ou NumPy indisponível"
  @test_skip false
 end
end
