# Inspeção do compilador ABT para a IDE: chama as funções ORIGINAIS da ABT, etapa por etapa, e serializa o
# que cada uma produz em JSON. Não reimplementa nenhuma regra da linguagem e NÃO executa o programa.
#
#   julia --startup-file=no --project=RAIZ_DA_ABT ide/inspecionar.jl ARQUIVO.abt [--instrumentar]
#
# Saída (stdout, UTF-8): um objeto JSON com
#   versao, palavras_reservadas, etapas.{lexica,sintatica,ir,semantica,otimizacao,geracao,geracao_otimizada}
# Cada etapa tem ok, ms (1ª chamada, inclui compilação JIT) e, se falhou, erro/codigo/diagnostico.
# Etapas posteriores a uma falha são marcadas como "nao_executada". Com --instrumentar, cada etapa é repetida
# para medir também o tempo "aquecido" (sem JIT), como mediana de 5 repetições.
# Valores da AST/IR: {"n": tipo, "a": [filhos]} para nós, {"l": [...]} para listas e {"v": valor, "t": tipo} para folhas.
t_processo = time_ns()
using ABT, JSON
const MS_CARGA = (time_ns() - t_processo) / 1e6

ms(t) = round(t / 1e6; digits=3)

ser(x::ABT.Node) = Dict("n" => String(x.kind), "a" => [ser(y) for y in x.args])
ser(x::ABT.IR) = Dict("n" => String(x.op), "a" => [ser(y) for y in x.operands])
ser(x::AbstractVector) = Dict("l" => [ser(y) for y in x])
ser(::Nothing) = Dict("v" => nothing, "t" => "Nothing")
ser(x::Union{Bool,AbstractString}) = Dict("v" => x, "t" => string(typeof(x)))
ser(x::Integer) = Dict("v" => x, "t" => string(typeof(x)))
ser(x::AbstractFloat) = Dict("v" => isfinite(x) ? x : string(x), "t" => string(typeof(x)))
ser(x) = Dict("v" => repr(x), "t" => string(typeof(x)))

texto_arvore(x) = sprint(io -> ABT.treeprint(io, x))

function erro_dict(err)
    msg = sprint(showerror, err)
    codigo = ABT.diagnostic_code(msg)
    diag = try
        ABT.render_diagnostic(err; humor="off")
    catch
        msg
    end
    Dict{String,Any}("erro" => msg, "codigo" => codigo, "diagnostico" => diag)
end

# Executa f(); devolve (resultado, dict_da_etapa). Mede a 1ª chamada; com `instrumentar`, repete para o tempo aquecido.
function etapa(f; instrumentar=false)
    t0 = time_ns()
    try
        valor = f()
        d = Dict{String,Any}("ok" => true, "ms" => ms(time_ns() - t0))
        if instrumentar
            tempos = Float64[]
            for _ in 1:5
                t = time_ns(); f(); push!(tempos, time_ns() - t)
            end
            sort!(tempos)
            d["ms_aquecido"] = ms(tempos[3])
        end
        return valor, d
    catch err
        d = erro_dict(err)
        d["ok"] = false
        d["ms"] = ms(time_ns() - t0)
        return nothing, d
    end
end

function main()
    isempty(ARGS) && error("uso: inspecionar.jl ARQUIVO.abt [--instrumentar]")
    instrumentar = "--instrumentar" in ARGS
    source = read(ARGS[1], String)
    etapas = Dict{String,Any}()
    saida = Dict{String,Any}("versao" => ABT.ABT_VERSION, "julia" => string(VERSION), "ms_carga_pacote" => round(MS_CARGA; digits=3),
                             "instrumentado" => instrumentar, "etapas" => etapas)
    saida["palavras_reservadas"] = [Dict("lexema" => k, "token" => v) for (k, v) in sort!(collect(ABT.KEYWORDS))]
    saida["nomes_embutidos"] = sort!(collect(ABT.ABT_STDLIB_NAMES))
    pular() = Dict{String,Any}("ok" => false, "nao_executada" => true)

    toks, d = etapa(() -> ABT.tokenize(source); instrumentar)
    etapas["lexica"] = d
    if toks !== nothing
        d["tokens"] = [Dict("tipo" => t.kind, "lexema" => t.lexeme, "linha" => t.line, "coluna" => t.col) for t in toks]
    else
        # O lexer real não devolve tokens parciais em erro: aplica-o ao trecho anterior à posição do erro.
        m = match(r"at (\d+):(\d+)", get(d, "erro", ""))
        if m !== nothing
            linha, col = parse(Int, m[1]), parse(Int, m[2])
            linhas = split(source, '\n'; keepempty=true)
            prefixo = join(vcat(linhas[1:linha-1], [first(linhas[linha], max(col - 1, 0))]), "\n")
            parcial, _ = etapa(() -> ABT.tokenize(String(prefixo)))
            if parcial !== nothing
                d["tokens_antes_do_erro"] = [Dict("tipo" => t.kind, "lexema" => t.lexeme, "linha" => t.line, "coluna" => t.col)
                                             for t in parcial if t.kind != "EOF"]
            end
        end
    end

    ast, d = toks === nothing ? (nothing, pular()) : etapa(() -> ABT.parse_program(toks); instrumentar)
    etapas["sintatica"] = d
    if ast !== nothing
        d["ast"] = [ser(n) for n in ast]
        d["ast_texto"] = texto_arvore(ast)
        # Intervalos de tokens de cada instrução de nível superior, obtidos com o PRÓPRIO `statement` da ABT (mesmo laço
        # de parse_program). A AST não guarda posições; isto é o que o parser permite saber. Conferido contra a AST real.
        try
            p = ABT.Parser(toks, 1); nos = ABT.Node[]; faixas = Vector{Vector{Int}}()
            while !ABT.at(p, "EOF")
                if ABT.at(p, ";"); ABT.take(p); continue; end
                i0 = p.pos; push!(nos, ABT.statement(p)); push!(faixas, [i0, p.pos - 1])
            end
            d["instrucoes_topo"] = faixas
            d["instrucoes_topo_conferem"] = texto_arvore(nos) == d["ast_texto"]
        catch
            d["instrucoes_topo_conferem"] = false
        end
    end

    repr_ir, d = ast === nothing ? (nothing, pular()) : etapa(() -> ABT.lower_ir(ast); instrumentar)
    etapas["ir"] = d
    if repr_ir !== nothing
        d["ir"] = [ser(n) for n in repr_ir]
        d["ir_texto"] = texto_arvore(repr_ir)
    end

    validada, d = repr_ir === nothing ? (nothing, pular()) : etapa(() -> ABT.validate_ir(repr_ir); instrumentar)
    etapas["semantica"] = d

    otimizada, d = validada === nothing ? (nothing, pular()) : etapa(() -> ABT.optimize_ir(validada); instrumentar)
    etapas["otimizacao"] = d
    if otimizada !== nothing
        d["ir_otimizada"] = [ser(n) for n in otimizada]
        d["ir_otimizada_texto"] = texto_arvore(otimizada)
    end

    gerado, d = validada === nothing ? (nothing, pular()) : etapa(() -> ABT._generate_validated_ir(validada); instrumentar)
    etapas["geracao"] = d
    gerado !== nothing && (d["codigo"] = gerado)

    gerado_o, d = otimizada === nothing ? (nothing, pular()) : etapa(() -> ABT._generate_validated_ir(otimizada); instrumentar)
    etapas["geracao_otimizada"] = d
    gerado_o !== nothing && (d["codigo"] = gerado_o)

    JSON.print(stdout, saida)
    println()
end

main()
