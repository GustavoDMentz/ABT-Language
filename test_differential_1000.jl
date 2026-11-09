using Random
using TOML
include("pseudo.jl")
using .Pseudo

const SEED = 0xAB7116
const JULIA_BIN = VERSION

function cases()
    rng = MersenneTwister(SEED)
    result = Tuple{String,String}[]
    for i in 1:250
        a, b, c = rand(rng, 0:50), rand(rng, 1:20), rand(rng, 1:9)
        push!(result, ("arithmetic", "x=$a\ny=$b\nshow (x + y * $c) / $c\nshow x - y"))
    end
    for i in 1:150
        a, b = rand(rng, 0:30), rand(rng, 0:30)
        push!(result, ("branch_logic", "x=$a\ny=$b\nif x > y and y >= 0 { show x } else { show y }\nif x == y or x < y { show true } else { show false }"))
    end
    for i in 1:150
        n = rand(rng, 0:7)
        push!(result, ("loop_scope", "total=0\nfor each item in [1,2,3,$n] { total=total+item; if item > 2 { show total } }\nshow total"))
    end
    for i in 1:150
        a, b = rand(rng, 0:20), rand(rng, 0:20)
        push!(result, ("functions", "function calc(x,y) { if x > y { return x-y } else { return x+y } }\nshow calc($a,$b)\nshow calc($b,$a)"))
    end
    for i in 1:150
        x, y, threshold = rand(rng, 0:20), rand(rng, 0:20), rand(rng, 0:20)
        push!(result, ("aggregate", "numbers=[$x,$y,3,4]\nshow sum of numbers where value > $threshold\nshow average of numbers"))
    end
    for i in 1:100
        x = rand(rng, 0:50)
        push!(result, ("unicode_names", "café=$x\nΔ=2\nfunction soma(v) { return v+café }\nshow soma(Δ)"))
    end
    for i in 1:50
        x, y = rand(rng, 1:9), rand(rng, 1:9)
        push!(result, ("julia_interop", "usar Julia.Statistics\nusar Julia.LinearAlgebra\nshow Julia.Statistics.mean([$x,$y])\nshow Julia.LinearAlgebra.dot([$x,$y],[2,3])"))
    end
    @assert length(result) == 1000
    return result
end

function capture(f)
    outpath, outio = mktemp()
    errpath, errio = mktemp()
    value = nothing
    error_value = nothing
    try
        redirect_stdout(outio) do
            redirect_stderr(errio) do
                try
                    value = f()
                catch e
                    error_value = e
                end
            end
        end
        flush(outio); flush(errio)
        seekstart(outio); seekstart(errio)
        # include_string adds one host-evaluation LoadError layer. It is not an
        # ABT exception and contains only the generated source location.
        inner = error_value isa LoadError ? error_value.error : error_value
        return (value=value, stdout=read(outio, String), stderr=read(errio, String),
                error=inner === nothing ? "" : string(typeof(inner)),
                message=inner === nothing ? "" : sprint(showerror, inner))
    finally
        close(outio); close(errio)
        rm(outpath; force=true); rm(errpath; force=true)
    end
end

function run_one(id, category, source)
    ast = nothing
    parse_error = nothing
    try
        ast = parse_program(tokenize(source))
    catch e
        parse_error = e
    end
    parse_error === nothing || return (false, "parser: " * sprint(showerror, parse_error), nothing)
    output = String[]
    interpreted = capture(() -> execute(ast; output))
    interpreted = merge(interpreted, (output=join(output, "\n") * (isempty(output) ? "" : "\n"),))
    for optimize in (false, true)
        code = nothing
        compile_error = nothing
        try
            code = generate(ast; optimize)
        catch e
            compile_error = e
        end
        if compile_error !== nothing
            got = (error=string(typeof(compile_error)), message=sprint(showerror, compile_error))
            expected = (error=interpreted.error, message=interpreted.message)
            got == expected || return (false, "compile optimize=$optimize: $got != $expected", code)
            continue
        end
        generated = capture(() -> Base.include_string(Module(gensym(:ABTDifferential)), code))
        if (generated.stdout, generated.stderr, generated.error, generated.message) !=
           (interpreted.output, interpreted.stderr, interpreted.error, interpreted.message)
            reason = "optimize=$optimize generated=$(repr((generated.stdout, generated.stderr, generated.error, generated.message))) interpreter=$(repr((interpreted.output, interpreted.stderr, interpreted.error, interpreted.message)))"
            return (false, reason, code)
        end
    end
    return (true, "", nothing)
end

function main()
    selected = nothing
    if length(ARGS) == 2 && ARGS[1] == "--case"
        selected = parse(Int, ARGS[2])
        1 <= selected <= 1000 || error("case id must be 1..1000")
    elseif !isempty(ARGS)
        error("usage: julia test_differential_1000.jl [--case ID]")
    end
    allcases = cases()
    ids = selected === nothing ? (1:1000) : (selected:selected)
    failures = Dict{String,Any}[]
    counts = Dict{String,Int}()
    for id in ids
        category, source = allcases[id]
        counts[category] = get(counts, category, 0) + 1
        ok, reason, code = run_one(id, category, source)
        if !ok
            push!(failures, Dict("id"=>id, "category"=>category, "source"=>source, "reason"=>reason))
            println("FAIL case $id [$category]: $reason")
        end
        id % 100 == 0 && println("Completed $id / 1000")
    end
    report = Dict{String,Any}("seed"=>Int(SEED), "julia_version"=>string(JULIA_BIN),
        "executed"=>length(ids), "passed"=>length(ids)-length(failures),
        "failed"=>length(failures), "categories"=>counts, "failures"=>failures)
    path = selected === nothing ? "differential_results.toml" : "differential_case_$(selected).toml"
    open(path, "w") do io; TOML.print(io, report); end
    println("Summary: $(report["passed"]) PASS, $(report["failed"]) FAIL; $path")
    isempty(failures) || exit(1)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
