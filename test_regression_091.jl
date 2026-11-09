using Test
include("pseudo.jl")
using .Pseudo
compile091(s) = generate(parse_program(tokenize(s)))
@testset "ABT 0.9.1 — static bridge contracts" begin
 for src in [
  "usar Python.numpy\nf = Python.numpy.sum\nmostrar f([1,2,3])",
  "usar Python.numpy\na = Python.numpy.array([1,2])\nmostrar a.sum()",
  "usar Python.Bio.Seq\nmostrar Python.Bio.Seq.Seq(\"ACGT\")",
  "usar Python.numpy\nusar Python.numpy.linalg\nmostrar Python.numpy.linalg.norm([3,4])",
 ]
  generated = compile091(src)
  @test occursin("abt_import_python!", generated)
 end
 for src in [
  "usar Python.numpy\nPython = 3",
  "usar Python.numpy\nmostrar Python.numpy.__dict__",
  "mostrar Python.numpy.sum([1])",
  "usar Python.numpy\nfunção Python(x)\nretornar x",
  "usar Python.numpy\nse verdadeiro\n    usar Python.os\nmostrar 1",
 ]
  @test_throws Exception compile091(src)
 end
 code = compile091("usar Python.Bio.Seq\nmostrar Python.Bio.Seq.Seq(\"ACGT\")")
 @test occursin("abt_import_python!(Python, \"Bio.Seq\", abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport)", code)
 @test !occursin("__abt_py_modules", code)
end

@testset "ABT 0.9.1 — differential Python runtime (optional)" begin
 available = try
  @eval import PythonCall
  PythonCall.pyimport("numpy")
  true
 catch
  false
 end
 if available
  for src in [
   "usar Python.numpy\nmostrar Python.numpy.sum([1,2,3])",
   "usar Python.numpy\nf = Python.numpy.sum\nmostrar f([1,2,3])",
   "usar Python.numpy\na = Python.numpy.array([1,2,3])\nmostrar a.sum()",
   "usar Python.numpy\nusar Python.numpy.linalg\nmostrar Python.numpy.linalg.norm([3,4])",
  ]
   ast = parse_program(tokenize(src))
   expected = execute(ast)
   path = tempname() * ".jl"
   write(path, compile091(src))
   actual = read(`$(Base.julia_cmd()) --startup-file=no $path`, String)
   rm(path; force=true)
   @test strip(actual) == join(expected, "\n")
  end
 else
  @info "PythonCall/NumPy indisponível: testes diferenciais ignorados"
  @test_skip false
 end
end
