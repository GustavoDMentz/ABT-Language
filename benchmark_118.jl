using Statistics, Printf
include("pseudo.jl")
using .Pseudo

const NSAMPLES = 9
function workloads()
    cases = Tuple{String,String,Function}[]
    push!(cases, ("arithmetic", "x=12\ny=7\nmostrar (x+y*3)/2", () -> println((12+7*3)/2)))
    push!(cases, ("function_calls", "função f(x) { retornar x*2+1 }\nmostrar f(1)\nmostrar f(2)\nmostrar f(3)\nmostrar f(4)\nmostrar f(5)", () -> begin f(x)=x*2+1; for x in 1:5; println(f(x)); end; end))
    push!(cases, ("branch_loop", "x=0\npara cada v em [1,2,3,4,5,6,7,8] { se v > 4 { x=x+v } }\nmostrar x", () -> begin x=0; for v in [1,2,3,4,5,6,7,8]; if v>4; x+=v; end; end; println(x); end))
    push!(cases, ("aggregation", "mostrar soma de [1,2,3,4,5,6,7,8]", () -> println(sum([1,2,3,4,5,6,7,8]))))
    for n in (0, 5, 1000)
        values = collect(1:n)
        literal = "["*join(values,",")*"]"
        src = "xs=$literal\nmostrar limitar (transformar (filtrar xs onde valor > 2) com valor * 10) a 2"
        native = () -> begin xs=copy(values); println(first(isempty(xs) ? Any[] : map(x->x*10,filter(x->x>2,xs)), min(2,max(0,length(xs)-2)))); end
        push!(cases,("collection_$n",src,native))
    end
    for stages in (2,5,10,20)
        values = collect(1:20)
        lines = ["xs=["*join(values,",")*"]", "xs"]
        for j in 1:stages
            push!(lines,isodd(j) ? "    filtrar onde valor > $(mod(j,4))" : "    transformar com valor + $(mod(j,3))")
        end
        push!(lines,"    mostrar")
        native = () -> begin
            xs=copy(values)
            for j in 1:stages
                xs = isodd(j) ? filter(x->x>mod(j,4),xs) : map(x->x+mod(j,3),xs)
            end
            println(xs)
        end
        push!(cases,("pipeline_$stages",join(lines,"\n"),native))
    end
    cases
end
function sample(f; reps=1)
    f(); f(); GC.gc()
    times=Float64[]; allocs=Int[]
    for _ in 1:NSAMPLES
        t=time_ns(); a=@allocated begin for _ in 1:reps; f(); end end
        push!(times,(time_ns()-t)/1e6/reps); push!(allocs,div(a,reps))
    end
    (median(times),minimum(times),maximum(times),median(allocs))
end
function bench_main()
    open("benchmark_results.csv","w") do io
        println(io,"workload,path,phase,median_ms,min_ms,max_ms,median_alloc_bytes,samples")
        for (name,source,native) in workloads()
            tokens=Pseudo.tokenize(source); ast=Pseudo.parse_program(tokens)
            ir=Pseudo.validate_ir(Pseudo.lower_ir(ast))
            opt=Pseudo.optimize_ir(ir)
            for (phase,fn) in (("tokenize_parse",()->Pseudo.parse_program(Pseudo.tokenize(source))),
                               ("lower_validate",()->Pseudo.validate_ir(Pseudo.lower_ir(ast))),
                               ("optimize",()->Pseudo.optimize_ir(ir)),
                               ("generate_unoptimized",()->Pseudo.generate(ir;optimize=false)),
                               ("generate_optimized",()->Pseudo.generate(ir;optimize=true)))
                m,lo,hi,a=sample(fn)
                println(io,"$name,abt,$phase,$m,$lo,$hi,$a,$NSAMPLES")
            end
            for optimize in (false,true)
                path=optimize ? "generated_optimized" : "generated_unoptimized"
                code=Pseudo.generate(ast;optimize)
                fresh=()->redirect_stdout(devnull) do; Base.include_string(Module(gensym(:ABTBench)),code); end
                m,lo,hi,a=sample(fresh)
                println(io,"$name,$path,include_jit,$m,$lo,$hi,$a,$NSAMPLES")
                compiled=Base.eval(Module(gensym(:ABTWarm)),Meta.parse("() -> begin\n"*code*"\nend"))
                sink=()->redirect_stdout(devnull) do; Base.invokelatest(compiled); end
                m,lo,hi,a=sample(sink;reps=20)
                println(io,"$name,$path,warm_execution,$m,$lo,$hi,$a,$NSAMPLES")
            end
            sinknative=()->redirect_stdout(devnull) do; native(); end
            m,lo,hi,a=sample(sinknative;reps=20)
            println(io,"$name,native,warm_execution,$m,$lo,$hi,$a,$NSAMPLES")
            sinkinterp=()->Pseudo.execute(ast)
            m,lo,hi,a=sample(sinkinterp;reps=20)
            println(io,"$name,interpreter,warm_execution,$m,$lo,$hi,$a,$NSAMPLES")
            flush(io)
            println("completed $name")
        end
    end
end
if abspath(PROGRAM_FILE)==@__FILE__; bench_main(); end
