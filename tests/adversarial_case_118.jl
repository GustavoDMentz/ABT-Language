include("test_differential_1000.jl")
source = read(ARGS[2], String)
if ARGS[1] == "valid"
    ok, reason, _ = run_one(0, "adversarial", source)
    println(ok ? "EQUIVALENT" : "DIVERGENCE: " * reason)
    exit(ok ? 0 : 2)
elseif ARGS[1] == "invalid"
    try
        execute(parse_program(tokenize(source)))
        println("ACCEPTED")
        exit(3)
    catch e
        println("REJECTED: ", typeof(e), ": ", sprint(showerror, e))
    end
end
