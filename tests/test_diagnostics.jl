using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

@testset "ABT — diagnósticos em português" begin
 samples = Dict(
  "E021" => ("Semantic error: undefined variable 'x'", "A variável 'x' não foi definida."),
  "E010" => ("Expected IDENT, got NUMBER at 2:8", "Era esperado IDENT"),
  "E052" => ("Semantic error: function 'somar' expects 2 arguments, got 1", "A função 'somar' espera 2 argumentos, mas recebeu 1."),
 )
 for (code, (msg, detail)) in samples
  outputs = Dict(mode => render_diagnostic(ErrorException(msg); humor=mode) for mode in ("off", "dry", "roast"))
  for mode in ("off", "dry", "roast")
   @test occursin("ABT[$code]", outputs[mode])
   @test occursin(detail, outputs[mode])
   @test outputs[mode] == render_diagnostic(ErrorException(msg); humor=mode)
  end
  @test !occursin("ABT: ", outputs["off"])
  @test occursin("ABT: ", outputs["dry"])
  @test occursin("ABT: ", outputs["roast"])
 end
 for mode in ("off", "dry", "roast")
  out = render_diagnostic(OutOfMemoryError(); humor=mode)
  @test occursin("ABT[FATAL]", out)
  @test !occursin("ABT: ", out)
 end
 @test_throws ArgumentError render_diagnostic(ErrorException("x"); humor="random")
end
