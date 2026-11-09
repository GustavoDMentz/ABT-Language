using Random, TOML
include("test_differential_1000.jl")

const STRESS_SEED = 0xAB7118E
function number_expr(rng, depth, vars)
    if depth == 0 || rand(rng) < 0.30
        return rand(rng, vars)
    end
    a = number_expr(rng, depth-1, vars)
    b = number_expr(rng, depth-1, vars)
    op = rand(rng, ("+", "-", "*"))
    return "($a $op $b)"
end
function case_at(id::Int)
    1 <= id <= 10000 || error("case id must be 1..10000")
    rng = MersenneTwister(STRESS_SEED + id)
    category = div(id-1, 1000) + 1
    depth = 1 + mod(div(id-1, 200), 4)
    a, b, c = rand(rng, 0:15), rand(rng, 0:15), rand(rng, 0:15)
    xs = "xs=[$a,$b,$c,1,2,3]"
    if category == 1
        e = number_expr(rng, depth, ["x", "y", "1", "2", "3"])
        return "arithmetic", "x=$a\ny=$b\nmostrar $e"
    elseif category == 2
        e1 = number_expr(rng, depth, ["x", "1", "2"])
        e2 = number_expr(rng, depth, ["y", "1", "2"])
        return "function", "função f(x,y) { retornar $e1 + $e2 }\nmostrar f($a,$b)"
    elseif category == 3
        e = number_expr(rng, depth, ["x", "y", "1", "2"])
        return "branch", "x=$a\ny=$b\nse x > y { mostrar $e } senao { mostrar y }"
    elseif category == 4
        return "loop", "$xs\ntotal=0\npara cada x em xs { total=total+x; se x > $b { mostrar total } }\nmostrar total"
    elseif category == 5
        return "collection", "$xs\nmostrar limitar (transformar (filtrar xs onde valor >= $b) com valor + $a) a $(mod(id,7))"
    elseif category == 6
        stages = String[]
        for j in 1:(2 + mod(id,4))
            push!(stages, isodd(j) ? "    filtrar onde valor >= $(mod(a+j,5))" : "    transformar com valor + $(mod(b+j,4))")
        end
        push!(stages, "    mostrar")
        return "pipeline", xs * "\nxs\n" * join(stages,"\n")
    elseif category == 7
        return "aggregate", "$xs\nmostrar soma de (transformar (filtrar xs onde valor > $b) com valor * $(a+1))"
    elseif category == 8
        e = number_expr(rng, depth, ["x", "2", "3"])
        return "nested_scope", "x=$a\nfunção f(x) { se x > $b { retornar $e } senao { retornar x+1 } }\nmostrar f($c)\nmostrar x"
    elseif category == 9
        return "boolean", "x=$a\ny=$b\nse x > y e y >= 0 { mostrar x } senao { mostrar y }\nse x == y ou x < y { mostrar verdadeiro } senao { mostrar falso }"
    else
        return "julia_bridge", "usar Julia.Base\nmostrar Julia.Base.sum([$a,$b,$c])\nmostrar Julia.Base.length([$a,$b])"
    end
end
function minimize(source, reason)
    lines = split(source, '\n')
    length(lines) <= 1 && return source
    changed = true
    while changed
        changed = false
        for i in eachindex(lines)
            candidate = join(lines[setdiff(eachindex(lines), [i])], "\n")
            try
                ast = parse_program(tokenize(candidate))
                ok, why, _ = run_one(0, "minimize", candidate)
                if !ok && !startswith(why, "parser:")
                    lines = split(candidate, '\n'); changed = true; break
                end
            catch
            end
        end
    end
    return join(lines, "\n")
end
function stress_main()
    ids = if length(ARGS)==2 && ARGS[1]=="--case"
        [parse(Int, ARGS[2])]
    elseif length(ARGS)==2 && ARGS[1]=="--limit"
        1:parse(Int, ARGS[2])
    elseif length(ARGS)==3 && ARGS[1]=="--range"
        parse(Int,ARGS[2]):parse(Int,ARGS[3])
    elseif isempty(ARGS)
        1:10000
    else
        error("usage: julia stress_generator_118.jl [--case ID | --limit N | --range FIRST LAST]")
    end
    tag = length(ARGS)==3 ? "_$(first(ids))_$(last(ids))" : ""
    failures = 0; by_category = Dict{String,Int}(); started=time()
    open("logs/test_logs/stress_failures$tag.tsv","w") do io
        println(io,"id\tcategory\treason\tprogram\tminimized")
        flush(io)
        for id in ids
            category, source = case_at(id)
            by_category[category] = get(by_category,category,0)+1
            ok, reason, _ = run_one(id, category, source)
            if !ok
                failures += 1
                minsrc = startswith(reason,"parser:") ? source : minimize(source, reason)
                escape(s) = replace(s, '\n'=>"\\n", '\t'=>"\\t")
                println(io,join((id,category,escape(reason),escape(source),escape(minsrc)),'\t'))
                flush(io)
            end
            if id % 100 == 0
                println("completed=$id failures=$failures elapsed=$(round(time()-started;digits=1))s")
                flush(stdout)
            end
        end
    end
    open("logs/test_logs/stress_summary$tag.toml","w") do io
        TOML.print(io, Dict("seed"=>string(STRESS_SEED),"executed"=>length(ids),"failures"=>failures,"seconds"=>round(time()-started;digits=2),"categories"=>by_category))
    end
    println("STRESS RESULT executed=$(length(ids)) failures=$failures")
    failures==0 || exit(1)
end
if abspath(PROGRAM_FILE)==@__FILE__; stress_main(); end
