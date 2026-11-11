# Semântica, erros e limites

## Valores e escopos

Literais numéricos geram `Int64` ou `Float64`, sem inferência de unidade ou coerção geral. Listas preservam ordem e podem conter valores de tipos diferentes. Registros vêm de `registro`; tabelas e FASTA são valores especiais da biblioteca. `ausente` não é literal do parser. Operações tabulares exigem esquema explícito e política de ausentes declarada.

Funções são declarações de nível superior com aridade fixa. Parâmetros e atribuições pertencem à chamada; não capturam variáveis mutáveis globais. Novos nomes de um ramo precisam existir em ambos os ramos para serem garantidos depois; novos nomes definidos apenas em laços não escapam com garantia. `valor` nas operações de lista é temporário. A validação de IR rejeita nomes internos reservados, caminhos de import inválidos e chamadas com aridade conhecida incorreta.

## Ordem e apresentação

Operações, argumentos e efeitos são avaliados em ordem textual. `e`/`ou` fazem curto-circuito. `mostrar` avalia a expressão e apresenta um valor; funções de cálculo retornam valores e não imprimem automaticamente. `salvar_figura` escreve um arquivo explicitamente. O interpretador e os geradores Julia partilham as operações da biblioteca, mas podem formatar pilhas técnicas de exceção de maneira diferente. O diagnóstico ABT preserva a causa.

## Erros

`abt check` valida sem executar imports externos. `abt run` pode falhar posteriormente por arquivo, biblioteca, dados ou valor dinâmico. Códigos CLI: 0 sucesso, 1 erro de programa, 2 uso/ambiente. `ABT[E010]` cobre alguns erros de sintaxe, `E021` nome não definido, `E052` aridade e `E000` outros erros de compilação ou execução. `--depurar` acrescenta exceção técnica. Não trate a categoria `E000` como prova de uma causa única.

## Limites conhecidos

- ABT não tem literal `ausente`, exceções capturáveis no código ABT, funções aninhadas, módulos definidos pelo usuário, LSP ou debugger interativo.
- CSV usa iteradores reexecutáveis, mas `coluna`, `linhas_tabela`, gráficos e regressão materializam os dados necessários. `mostrar tabela` percorre toda a tabela.
- Estatística e OLS pressupõem desenho amostral adequado; ABT não verifica independência, confundimento, heterocedasticidade nem múltiplas comparações. Números `Int64` convertidos a `Float64` obedecem à precisão deste último.
- PythonCall é opcional. A ponte externa aceita apenas imports/caminhos declarados, mas ABT não isola efeitos de bibliotecas de terceiros.
- A CLI homologada exige Julia 1.13.3. A interface pública de geração de código é usada em desenvolvimento via `pseudo.jl`, não como flag da CLI cotidiana.

O [inventário](inventory.md) classifica capacidades. Os relatórios técnicos em `docs/` documentam decisões e medições históricas sem substituir testes atuais.
