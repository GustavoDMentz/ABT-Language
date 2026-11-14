# Carga de trabalho de pré-compilação do núcleo da ABT.
#
# Sem ela, a imagem pré-compilada do pacote não contém código nativo para o lexer, o parser,
# a validação, o interpretador e a apresentação: com `--compile=yes`, o Julia compilava essas
# funções a cada execução (vários segundos antes de `mostrar 1`). Executar programas pequenos
# durante a pré-compilação faz o Julia guardar essas especializações na imagem do pacote.
#
# Regras:
# - só é executada quando o Julia está gerando a imagem (`jl_generating_output`);
# - não usa operações que carregam pacotes opcionais (CSV, FASTX, BioAlignments, GLM...):
#   carregá-los aqui os tornaria dependências da imagem e deixaria toda partida mais lenta;
# - não escreve em stdout e ignora falhas (a pré-compilação nunca pode quebrar por causa dela).

function abt_precompile_workload()
 programs = (
  "mostrar 1",
  "a = 2.0\nb = 3\nmostrar -a ^ b\nmostrar (a + b) * 2\nmostrar 7 / 2\nmostrar 3 é maior que 2\nmostrar verdadeiro ou falso\nmostrar \"texto\"\nmostrar 1 == 1.0",
  "dados = [1, 2, 3, 4, 5]\ndados\n    filtrar onde valor > 2\n    transformar com valor * 10\n    limitar a 2\n    mostrar\nmostrar soma de dados onde valor > 2\nmostrar media de dados\nmostrar [1, 2.5, \"x\"]\nmostrar []",
  "função fatorial(n) {\n    se n <= 1 {\n        retornar 1\n    } senao {\n        retornar n * fatorial(n - 1)\n    }\n}\ntotal = 0\npara cada i em [1, 2, 3] {\n    total = total + fatorial(i)\n}\nmostrar total",
  "r = registro(\"nome\", \"x\", \"n\", 2, \"lista\", [1, 2])\nmostrar r\nmostrar r.nome\nmostrar n de r\nmostrar descrever([1, 2, 3, 4])\nmostrar aparar(\" a \")\nmostrar maiusculas(\"abc\")\nmostrar linhas_texto(\"a\\nb\")\nmostrar comprimento_texto(\"abc\")\nmostrar inicia_com(\"abc\", \"a\")\nmostrar contar_caractere(\"banana\", \"a\")",
  "xs = [3, 1.5, 2, 2, 9]\nmostrar contar(xs)\nmostrar minimo(xs)\nmostrar maximo(xs)\nmostrar ordenar(xs)\nmostrar ordenar([\"b\", \"a\"], \"decrescente\")\nmostrar sem_duplicatas(xs)\nmostrar para_inteiro(\"42\")\nmostrar para_real(\"2.5\")\nmostrar para_texto(3.5)",
  "usar Julia.Statistics\nmostrar Julia.Statistics.mean([1, 2, 3])\nmostrar ambiente(\"ABT_PRECOMPILE_INEXISTENTE\", \"padrao\")",
 )
 for source in programs
  try
   ast = parse_program(tokenize(source))
   validate_ir(lower_ir(ast))
   execute(ast)
  catch
  end
 end
 # Caminhos de erro: diagnóstico de sintaxe, nome indefinido e aridade.
 for source in ("mostrar (", "mostrar x", "função f(a) { retornar a }\nmostrar f(1, 2)", "mostrar 1 +")
  try
   execute(parse_program(tokenize(source)))
  catch err
   render_diagnostic(err; humor="off", source="programa.abt")
  end
 end
 # A CLI de ponta a ponta (run, check, erro, uso inválido), com a saída descartada.
 precompile(cli_main, (Vector{String},))
 try
  dir = mktempdir()
  ok = joinpath(dir, "ok.abt"); bad = joinpath(dir, "erro.abt")
  write(ok, "dados = [1, 2, 3]\nmostrar soma de dados\nmostrar registro(\"n\", 1)\n")
  write(bad, "mostrar x\n")
  redirect_stdout(devnull) do
   redirect_stderr(devnull) do
    for args in (["run", ok], ["check", ok], [ok], ["run", bad], ["executar", joinpath(dir, "ausente.abt")], ["--opcao-invalida"])
     cli_main(String.(args))
    end
   end
  end
  rm(dir; recursive=true, force=true)
 catch
 end
 return nothing
end

if ccall(:jl_generating_output, Cint, ()) == 1
 abt_precompile_workload()
end
