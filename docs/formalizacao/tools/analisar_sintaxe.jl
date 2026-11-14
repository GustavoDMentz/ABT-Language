# Entrega cada arquivo de um diretório ao tokenize + parse_program ORIGINAIS da ABT e informa se a análise
# sintática aceita ou rejeita. Não executa os programas e não os valida semanticamente.
#   julia --startup-file=no --project=/caminho/ABT-Language tools/analisar_sintaxe.jl DIRETORIO
# Saída (stdout), uma linha por arquivo, separada por TAB:  NOME  ok  |  NOME  erro  PRIMEIRA_LINHA_DA_MENSAGEM
using ABT

function main(dir)
    for name in sort(readdir(dir))
        endswith(name, ".abt") || continue
        source = read(joinpath(dir, name), String)
        try
            parse_program(tokenize(source))
            println(name, "\tok")
        catch err
            message = first(split(sprint(showerror, err), '\n'))
            println(name, "\terro\t", replace(message, '\t' => ' '))
        end
    end
end
main(ARGS[1])
