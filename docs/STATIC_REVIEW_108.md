# ABT 0.10.8 — 20ª rodada: correções + auditoria estática ampla

## Método e limites
Inspeção do código-fonte de `pseudo.jl`, `bridge_runtime.jl`, lexer, parser, IR, validação, otimização, interpretação, geração Julia, testes e documentação. **Não foi executado Julia**. As correções foram conferidas por inspeção textual e regressões Julia foram preparadas, não executadas.

## Correções aplicadas
1. **Atributos privados sem Python:** o helper emitido no ramo `has_python == false` agora rejeita campos começados por `_`, tal como o interpretador e o ramo Python. Harmonizada a mensagem de diagnóstico nos dois ramos gerados.
2. **Ambiente fornecido pelo chamador:** `execute` copia o dicionário antes de passar ao runtime; atribuições, importações e `__abt_output__` deixam de modificar o dicionário do chamador. O vetor `output`, quando fornecido, continua recebendo saídas por contrato.
3. **Colisão com estado interno:** `execute` rejeita chaves iniciais prefixadas por `__abt_`, em vez de sobrescrevê-las silenciosamente.
4. **Documentação:** explicita-se que geração é para programas autocontidos e que o bridge gerado ainda possui implementação própria, não uma incorporação literal do arquivo compartilhado.

## Novos achados adversariais — NÃO CORRIGIDOS
### H1 (alta): `generate_ir` é público e não valida a entrada
`generate_ir(program::Vector{IR})` é chamável diretamente sem `validate_ir`. A interface `generate` valida, mas um chamador pode passar IR inválido diretamente ao gerador, inclusive nomes/fluxos não verificados. Recomendação: marcar `generate_ir` como interno e/ou validar por construção, sem validação recursiva duplicada.

### H2 (alta): código gerado e interpretador ainda duplicam a semântica da ponte
`bridge_runtime.jl` define `abt_external_field` e `abt_import_python!`; `generate_ir` reimplementa em strings, com estruturas de namespace diferentes (`ABTPythonNamespace` versus `NamedTuple` com token). A correção do acesso privado remove uma divergência conhecida, mas não garante paridade futura. Recomendação: gerar runtime compartilhado com uma representação compatível ou manter testes diferenciais obrigatórios para cada operação.

### H3 (média): otimização avalia comparações literais durante compilação
`optimize_ir` calcula operações comparativas numéricas diretamente. Para valores ou métodos numéricos exóticos fornecidos via IR, a operação pode ter semântica ou efeitos de execução distintos. Parser atual produz números simples, reduzindo o risco no caminho normal; não assumir validade para IR arbitrário.

### H4 (média): saída não tem contrato uniforme de representação
Interpretador usa `string(...)` e gerador usa `println(...)`; em Julia, a impressão usa `print`, mas a captura de stdout, erros, objetos externos e saídas múltiplas não têm contrato diferencial formalizado. A saída do interpretador é vetor de strings; a compilada é stdout.

### H5 (média): carga de módulos via API de baixo nível
`Base.require(Base.PkgId(...))` e importação de PythonCall em `Module(gensym(...))` exigem testes reais em versões de Julia suportadas. Não é possível aprovar estaticamente compatibilidade ou isolamento de efeitos globais.

### H6 (média): imports e estado Python não são sandbox
A ponte carrega módulos Python com efeitos colaterais de importação e compartilha `sys.modules`. É contrato explícito, mas importante na avaliação de equivalência temporal e segurança.

### H7 (média): análise de fluxo e funções
Laços de zero iterações, variáveis reatribuídas em ramos e retorno antecipado merecem regressões diferenciais. `check` faz união conservadora de tipos e não implementa análise de alcance/fixpoint; pode rejeitar programas válidos ou deixar diferenças de erro para runtime.

## Contrato da versão
- `execute(nodes; env=...)` aceita ambiente externo e não altera seu dicionário.
- `generate(nodes)` **não** recebe ambiente externo; equivalência só é reivindicada para programas autocontidos.
- `execute_unchecked` é mecanismo interno e pode modificar seu `env` deliberadamente.
- Acesso privado é rejeitado em todos os caminhos.
- Não existe isolamento de estado Python, apenas isolamento dos vínculos Julia gerados.

## Próxima prioridade
Eliminar duplicação do bridge e fechar contrato de entrada/saída; então rodar Julia, testes diferenciais e casos adversariais. Não interpretar inspeção textual como testes executados.
