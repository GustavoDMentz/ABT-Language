using Test
include("test_differential_1000.jl")

const ADVERSARIAL_CASES = [
    ("unicode_distinct", "café=4\ncafe=5\nshow café\nshow cafe"),
    ("helper_name_collision", "abt_invoke=7\nshow abt_invoke"),
    ("function_forward_reference", "show double(4)\nfunction double(x) { return x*2 }"),
    ("recursion", "function fact(n) { if n <= 1 { return 1 } return n*fact(n-1) }\nshow fact(5)"),
    ("nested_scope_update", "x=1\nif true { if true { x=x+2 } }\nshow x"),
    ("short_circuit_and", "show false and (average of [] > 0)"),
    ("short_circuit_or", "show true or (average of [] > 0)"),
    ("argument_error_order", "function first(a,b) { return a }\nshow 8\nshow first(1, average of [])"),
    ("division_zero", "show 1/0\nshow 0/0"),
    ("empty_sum", "show sum of []"),
    ("empty_average", "show average of []"),
    ("loop_empty", "x=2\nfor each y in [] { x=5 }\nshow x"),
    ("loop_shadow", "x=9\nfor each x in [1,2] { show x }\nshow x"),
    ("repeated_julia_import", "usar Julia.Statistics\nusar Julia.Statistics\nshow Julia.Statistics.mean([2,4])"),
    ("julia_import_order", "show 1\nusar Julia.Statistics\nshow Julia.Statistics.mean([2,4])"),
]

@testset "ABT adversarial semantic differential" begin
    for (id, (category, source)) in enumerate(ADVERSARIAL_CASES)
        ok, reason, _ = run_one(id, category, source)
        @test ok || error("$category: $reason")
    end
end

@testset "ABT invalid input boundaries" begin
    for source in (
        "show missing_name",
        "usar Julia.Statistics\nshow Julia.Statistics",
        "usar Julia.Foo",
        "usar Python._private",
        "usar Python.numpy\nshow Python.numpy.__dict__",
        "__abt_user_6162=3",
        "function f(x,x) { return x }",
        "return 1",
    )
        error_interpreter = try execute(parse_program(tokenize(source))); nothing catch e; e end
        error_generator = try generate(parse_program(tokenize(source))); nothing catch e; e end
        @test error_interpreter !== nothing
        @test typeof(error_interpreter) == typeof(error_generator)
        @test sprint(showerror, error_interpreter) == sprint(showerror, error_generator)
    end
end

@testset "ABT Python imports and attributes" begin
    if Base.find_package("PythonCall") === nothing
        @test_skip false
    else
        for (id, (category, source)) in enumerate((
            ("python_parent_child", "usar Python.numpy\nusar Python.numpy.linalg\nshow Python.numpy.linalg.norm([3,4])"),
            ("python_child_parent", "usar Python.numpy.linalg\nusar Python.numpy\nshow Python.numpy.sum([2,3])"),
            ("python_repeat", "usar Python.numpy\nusar Python.numpy\nshow Python.numpy.sum([2,3])"),
            ("python_object", "usar Python.numpy\na=Python.numpy.array([1,2,3])\nshow a.sum()"),
        ))
            ok, reason, _ = run_one(id, category, source)
            @test ok || error("$category: $reason")
        end
    end
end
