# Adversarial differential runner for ABT 0.5. Does not modify the compiler.
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

cases = [
 ("basic", "show 2 + 3 * 4"),
 ("parentheses", "show (2 + 3) * 4"),
 ("float", "show 1 / 2"),
 ("negative", "show 0 - 5"),
 ("large_integer", "show 9223372036854775807 + 1"),
 ("divide_by_zero", "show 1 / 0"),
 ("zero_div_zero", "show 0 / 0"),
 ("empty_sum", "numbers=[]\nshow sum of numbers"),
 ("empty_average", "numbers=[]\nshow average of numbers"),
 ("false_branch", "if 1 > 2 { show 10 } else { show 20 }"),
 ("nested_branch", "if 1 < 2 { if 3 > 2 { show 7 } }"),
 ("empty_loop", "for each x in [] { show x }"),
 ("loop_scope", "for each x in [1,2] { show x }\nshow x"),
 ("branch_scope", "if 1 < 2 { x = 9 }\nshow x"),
 ("reassignment", "x=1\nx=2\nshow x"),
 ("boolean", "show true"),
 ("logical_short_circuit", "show false and (1 / 0 > 0)"),
 ("unicode", "números=[1,2,3]\nmostrar soma de números"),
 ("string_escape", "show \"a\\nb\""),
 ("precedence", "show 1 + 2 * 3 == 7"),
 ("numeric_comparison", "show 2 < 3"),
 ("filtered_sum", "numbers=[1,2,3,4]\nshow sum of numbers where value > 2"),
 ("filtered_avg", "numbers=[1,2,3,4]\nshow average of numbers where value > 2"),
]

function outcome(f)
 try
  return ("ok", f())
 catch e
  return ("error", string(typeof(e)), sprint(showerror, e))
 end
end

function run_generated(src; optimize=true)
 ast = Pseudo.parse_program(Pseudo.tokenize(src))
 code = Pseudo.generate(ast; optimize)
 mktemp() do path, io
  write(io, code)
  close(io)
  out = IOBuffer(); err = IOBuffer()
  cmd = `$(Base.julia_cmd()) --startup-file=no $path`
  proc = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
  if success(proc)
   return ("ok", chomp(String(take!(out))))
  end
  return ("error", "runtime", first(split(String(take!(err)), '\n'; limit=2)))
 end
end

function main()
 println("ABT 0.6 adversarial differential test")
 disagreements = 0
 expected_errors = 0
 for (name, src) in cases
  interpreted = outcome(() -> join(Pseudo.execute(Pseudo.parse_program(Pseudo.tokenize(src))), "\n"))
  raw = outcome(() -> run_generated(src; optimize=false))
  opt = outcome(() -> run_generated(src; optimize=true))
  raw = raw[1] == "ok" ? raw[2] : raw
  opt = opt[1] == "ok" ? opt[2] : opt
  if interpreted[1] == "ok" && raw[1] == "ok" && opt[1] == "ok" && interpreted[2] == raw[2] == opt[2]
   println("[MATCH] $name")
  elseif interpreted[1] == "error" && raw[1] == "error" && opt[1] == "error" &&
         (occursin("Cannot average an empty selection", string(interpreted)) &&
          occursin("Cannot average an empty selection", string(raw)) &&
          occursin("Cannot average an empty selection", string(opt)) ||
          occursin("undefined variable", string(interpreted)) &&
          occursin("undefined variable", string(raw)) &&
          occursin("undefined variable", string(opt)))
   expected_errors += 1
   println("[EXPECTED_ERROR] $name")
  else
   disagreements += 1
   println("[INVESTIGATE] $name")
   println("  interpreter: ", repr(interpreted))
   println("  generated:   ", repr(raw))
   println("  optimized:   ", repr(opt))
  end
 end
 println("Cases: $(length(cases)); expected errors: $expected_errors; investigate: $disagreements")
 return disagreements
end

if abspath(PROGRAM_FILE) == @__FILE__
 exit(main() == 0 ? 0 : 1)
end
