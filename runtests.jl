using Test
include("pseudo.jl")
using .Pseudo

function compile_source(src; optimize=true)
    return generate(parse_program(tokenize(src)); optimize)
end
function interpret_source(src)
    return execute(parse_program(tokenize(src)))
end
generate_ir_for_test(ir) = generate(ir; optimize=false)

@testset "ABT 0.7 — baseline" begin
    include("runtests_legacy.jl")
end

@testset "ABT — generated Julia behavior" begin
    for source in (
        "show 2 + 3 * 4",
        "if 2 > 1 { show 7 } else { show 8 }",
        "function add(a,b) { return a+b }\nshow add(3,4)",
        "numbers=[1,2,3]\nshow sum of numbers",
    )
        expected = join(interpret_source(source), "\n")
        for optimize in (true, false)
            code = compile_source(source; optimize)
            @test strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String)) == expected
        end
    end
end

@testset "ABT 0.7 — 600 deterministic arithmetic cases" begin
    for a in -12:12, b in 1:24
        # Avoid unary minus (not in current grammar): represent negatives as 0 - N.
        aa = a < 0 ? "(0 - $(-a))" : string(a)
        src = "show $aa + $b * 2"
        @test interpret_source(src) == [string(a + b * 2)]
        code = compile_source(src)
        @test occursin("Base.invokelatest(println,", code)
    end
end

@testset "ABT 0.7 — 120 language equivalence cases" begin
    for threshold in 0:59
        pt = "numeros=[1,2,3,4,5]\\nmostrar soma de numeros onde valor é maior que $threshold"
        en = "numbers=[1,2,3,4,5]\\nshow sum of numbers where value is above $threshold"
        # Source newline is a real separator, not the two characters backslash+n.
        pt = replace(pt, "\\n" => "\n")
        en = replace(en, "\\n" => "\n")
        expected = string(sum(x for x in 1:5 if x > threshold))
        @test interpret_source(pt) == [expected]
        @test interpret_source(en) == [expected]
    end
end

@testset "ABT 0.7 — 100 invalid-name diagnostics" begin
    for i in 1:100
        name = "missing_$(i)"
        err = try
            compile_source("show $name")
            nothing
        catch e
            e
        end
        @test err isa ErrorException && occursin("undefined variable '$name'", sprint(showerror, err))
    end
end

@testset "ABT 0.7 — 200 branch optimizer equivalence cases" begin
    for a in 0:99
        for op in (">", "<")
            src = "if $a $op 50 { show 1 } else { show 2 }"
            ast = parse_program(tokenize(src))
            before = lower_ir(ast)
            validate_ir(before)
            after = optimize_ir(before)
            @test length(after) == 1 && after[1].op == :print
            @test occursin("abt_std_render($(interpret_source(src)[1]))", generate_ir_for_test(after))
        end
    end
end


@testset "ABT 0.7 — optimization guards" begin
    @test occursin("if", compile_source("x=1\nif x > 0 { show 1 }"))
    @test !occursin("if (10 > 5)", compile_source("if 10 > 5 { show 1 }"))
    @test occursin("if (10 > 5)", compile_source("if 10 > 5 { show 1 }"; optimize=false))
    @test interpret_source("if 10 > 5 { show 1 }") == ["1"]
    @test interpret_source("if 10 < 5 { show 1 } else { show 2 }") == ["2"]
end

@testset "ABT 0.6 — regressions" begin
    @test interpret_source("numbers=[]\nshow sum of numbers") == ["0"]
    @test occursin("pseudo_sum(", compile_source("numbers=[]\nshow sum of numbers"))
    @test interpret_source("numbers=[]\nshow sum of numbers where value > 0") == ["0"]
    @test interpret_source("if true { x=1 } else { x=2 }\nshow x") == ["1"]
    for src in ("if true { x=9 }\nshow x", "for each x in [1,2] { show x }\nshow x")
        for f in (interpret_source, compile_source)
            err = try f(src); nothing catch e; e end
            @test err isa ErrorException && occursin("undefined variable 'x'", sprint(showerror, err))
        end
    end
    err = try interpret_source("numbers=[]\nshow average of numbers"); nothing catch e; e end
    @test err isa ErrorException && occursin("Cannot average an empty selection", sprint(showerror, err))
end

@testset "ABT 0.7 — functions" begin
    examples = [
        ("função quadrado(x) { retornar x * x }\nmostrar quadrado(5)", ["25"]),
        ("function add(a,b) { return a+b }\nshow add(3,4)", ["7"]),
        ("função dobro(x) { retornar x*2 }\nfunção soma(a,b) { retornar a+b }\nmostrar soma(dobro(3),dobro(4))", ["14"]),
        ("função escolha(x) { se x > 0 { retornar 9 } retornar 3 }\nmostrar escolha(2)\nmostrar escolha(0)", ["9", "3"]),
        ("função soma_lista(xs) { retornar soma de xs }\nmostrar soma_lista([1,2,3])", ["6"]),
        ("função f(x) { y=x+1; retornar y }\nmostrar f(4)", ["5"]),
        ("função f(x) { mostrar x; retornar x+1 }\nmostrar f(4)", ["4", "5"]),
    ]
    for (source, expected) in examples
        @test interpret_source(source) == expected
        @test occursin("function ", compile_source(source))
        @test occursin("function ", compile_source(source; optimize=false))
    end
    invalid = [
        "retornar 2",
        "função f(x) { retornar x }\nmostrar f()",
        "função f(x) { retornar x }\nmostrar f(1,2)",
        "mostrar inexistente(2)",
        "função f(x,x) { retornar x }",
        "função f(x) { retornar x }\nfunção f(y) { retornar y }",
        "função f(x) { retornar desconhecido }",
    ]
    for source in invalid
        @test_throws Exception interpret_source(source)
        @test_throws Exception compile_source(source)
    end
end

@testset "ABT 0.7.1 — contextual aggregate identifiers" begin
    src = "função soma(a,b) { retornar a+b }\nmostrar soma(3,4)\nmostrar soma de [1,2,3]"
    @test interpret_source(src) == ["7", "6"]
    @test strip(read(`$(Base.julia_cmd()) --startup-file=no -e $(compile_source(src))`, String)) == "7\n6"
    @test occursin("pseudo_sum", compile_source(src))
    @test interpret_source("soma=4\nmostrar soma") == ["4"]
end

@testset "ABT 0.7.1 — diagnostics" begin
    err = ErrorException("Semantic error: undefined variable 'nota'")
    @test occursin("E021", Pseudo.render_diagnostic(err))
    @test !occursin("ABT:", Pseudo.render_diagnostic(err; humor="off"))
    @test occursin("ABT:", Pseudo.render_diagnostic(err; humor="dry"))
    @test occursin("bola de cristal", Pseudo.render_diagnostic(err; humor="roast"))
    @test !occursin("ABT:", Pseudo.render_diagnostic(OutOfMemoryError(); humor="roast"))
end

@testset "ABT 0.7.1 — CLI humor argument regression" begin
    # split produces SubString; the CLI must normalize it before passing
    # it to render_diagnostic(::Any; humor::String).
    mode = String(split("--humor=roast", "="; limit=2)[2])
    @test mode isa String
    @test occursin("E052", Pseudo.render_diagnostic(
        ErrorException("Semantic error: function 'somar' expects 2 arguments, got 1"); humor=mode))
end
