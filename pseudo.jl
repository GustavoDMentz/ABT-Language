# Legacy adapter. Public programs should use bin/abt and src/ABT.jl.
include(joinpath(@__DIR__, "src", "ABT.jl"))
const Pseudo = ABT

if abspath(PROGRAM_FILE) == @__FILE__
 mode = "dry"
 for arg in ARGS
  if startswith(arg, "--humor=")
   global mode = String(split(arg, "="; limit=2)[2])
  elseif startswith(arg, "--lang=") || arg == "--lang"
   println(stderr, "ABT: --lang foi removido; os diagnósticos são em português.")
   exit(2)
  end
 end
 if !(mode in ("off", "dry", "roast"))
  println(stderr, "ABT: modo de humor inválido; use off, dry ou roast.")
  exit(2)
 end
 try
  ABT.main()
 catch err
  diagnostic = try
   ABT.render_diagnostic(err; humor=mode)
  catch
   "ABT[FATAL] — falha ao formatar diagnóstico. Execução interrompida."
  end
  println(stderr, diagnostic)
  exit(1)
 end
end
