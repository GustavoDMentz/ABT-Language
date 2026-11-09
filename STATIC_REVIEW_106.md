# ABT 0.10.6 — 17ª rodada: auditoria estática

## Correções
- Ambos os caminhos usam `abt_load_pythoncall!(cache)` e inicializam o cache somente na primeira importação Python.
- O interpretador usa `Ref` no módulo Pseudo; o gerador usa `Ref` por programa. Os caches têm vidas distintas, mas ambos apontam para o pacote PythonCall carregado pelo Julia.
- O contrato agora explicita que `sys.modules` e demais estados Python são compartilhados por processo; não há sandbox nem independência entre programas.
- O carregador gerado é emitido apenas quando o programa contém importação Python; não há dependência Python no caminho Julia puro.

## 17ª tentativa adversarial — problema ainda aberto (ALTA)
**Diferença de tratamento de erros de importação:** o interpretador transforma a falha de carregamento de PythonCall em uma mensagem de interoperabilidade; o gerador agora deixa a exceção original de `Core.eval` escapar. Isso viola um contrato de diagnósticos uniformes, embora não necessariamente o de resultado numérico. A próxima correção deve centralizar também a política de erro, sem esconder a causa original.

## Limitações
- `Module(gensym(...))` com `Core.eval(..., :(import PythonCall))` depende do ambiente de pacotes e deve ser executado em Julia real.
- As duas implementações do loader são equivalentes por inspeção textual, não provadas por execução.
- Não foi executada suíte Julia neste ambiente.

Testes de regressão textuais 0.10.4 e 0.10.5 atualizados para o novo carregador.
