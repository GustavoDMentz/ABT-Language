# ABT 0.10.4 — 15ª revisão adversarial (estática)

## Correção
- O gerador não usa mais `@eval import PythonCall` no módulo hospedeiro.
- A instrução `usar Python...` cria um módulo privado do programa na primeira execução e realiza `Core.eval(private_module, :(import PythonCall))` ali. O objeto PythonCall é recuperado por `getfield`.
- A importação continua tardia e o caminho Julia puro não carrega PythonCall.

## Nova quebra encontrada — prioridade ALTA
O interpretador ABT continua carregando PythonCall via `@eval import PythonCall` no próprio módulo `Pseudo` (`python_runtime()`), enquanto o código gerado usa um módulo privado. Isso não altera necessariamente o resultado visível de um script simples, mas viola a pretensão de ter a mesma política de isolamento nos dois caminhos. Corrigir usando carregador privado compartilhado, sem ampliar o escopo do POC.

## Outros riscos detectados
- `Base.require(Base.PkgId(...))` é API de baixo nível; a compatibilidade precisa ser verificada em Julia real.
- Testes legados `test_static_099.jl` e `test_static_101.jl` contêm expectativas textuais obsoletas (`@eval import`); precisam ser atualizados para não gerar falsos negativos.
- A criação de um módulo privado não isola efeitos globais de inicialização do próprio pacote PythonCall ou dos módulos Python importados.

## Evidência e limites
Inspeção do código-fonte e teste textual acrescentado em `test_static_104.jl`. Julia não estava disponível, logo não houve execução nem prova de equivalência.
