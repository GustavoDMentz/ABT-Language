include(joinpath(@__DIR__, "..", "src", "ABT.jl"))
source = read(joinpath(@__DIR__, "ola.abt"), String)
for pass in 1:2
    t0 = time_ns()
    tokens = ABT.tokenize(source)
    t1 = time_ns()
    ast = ABT.parse_program(tokens)
    t2 = time_ns()
    ir = ABT.lower_ir(ast)
    t3 = time_ns()
    ABT.validate_ir(ir)
    t4 = time_ns()
    output = ABT.execute(ast)
    t5 = time_ns()
    println(stderr, "pass=", pass, " tokenize=", (t1-t0)/1e9,
            " parse=", (t2-t1)/1e9, " lower=", (t3-t2)/1e9,
            " validate=", (t4-t3)/1e9, " execute=", (t5-t4)/1e9,
            " output=", repr(output))
end
