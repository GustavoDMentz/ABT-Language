# Modo de inspeção da ABT IDE

O botão **🔍 Inspecionar** (atalho `Ctrl+I`) mostra o que o compilador da ABT faz com o programa, etapa por etapa: tokens, símbolos, código normalizado, gramática G2 com FIRST/FOLLOW/tabela M, análise sintática passo a passo, AST, IR, análise semântica, otimizações, código Julia gerado e tempos. Serve para estudo e para demonstração de Linguagens Formais, Autômatos e Compiladores.

> **Princípio:** nada do que aparece é simulado. O que o compilador produz vem do próprio compilador (`ide/inspecionar.jl` chama `tokenize`, `parse_program`, `lower_ir`, `validate_ir`, `optimize_ir` e o gerador de Julia). O que é derivação da IDE (tabelas léxica e de símbolos, código normalizado, análise tabular de G2, classificação das otimizações) vem *desses dados* e está rotulado na tela como derivação.

Inspecionar **só compila**: o programa não é executado. A execução é uma ação explícita, por caminho, na aba **Saída**.

## Como usar

1. Escreva (ou carregue) um programa e clique em **Inspecionar**. O botão **Programa de referência** carrega e inspeciona o programa acadêmico da média da turma.
2. A primeira inspeção carrega a Julia e a ABT e leva alguns segundos; as seguintes são mais rápidas.
3. Se a inspeção falhou numa etapa, a IDE abre direto a aba dessa etapa e marca as posteriores como **não executadas**.
4. **← Voltar ao editor** (ou `Esc`) permite alterar o código; **↻ Inspecionar de novo** (ou `Ctrl+I`) repete. Se o editor mudar depois de inspecionar, aparece a faixa **"estes resultados estão DESATUALIZADOS"**.
5. Apresentação: **A− / A+** (fonte), **Tema** (auto/claro/escuro) e **Tela cheia**.

## Painéis

| Aba | O que mostra | Origem dos dados |
|---|---|---|
| Código-fonte | A versão exata inspecionada (SHA-256), tokens clicáveis, posição do erro léxico | compilador (tokens) |
| Análise léxica | Tabela: índice, lexema, token, padrão (regex), linha, coluna, valor, origem; catálogo de palavras reservadas e equivalência português ↔ inglês; erro léxico real com diagnóstico | lexer real (`tokenize`, `ABT.KEYWORDS`) |
| Tabela de símbolos | Símbolos do usuário: categoria, escopo, 1ª ocorrência, definições, usos; funções/importações da AST | derivada dos tokens + AST real |
| Código normalizado | Original × normalizado (identificadores → `id`, números → `num`), lado a lado | derivada dos **tokens** |
| Gramática e tabela M | Produções de G2, anuláveis, FIRST, FOLLOW, tabela M (origem de cada célula, conflitos) | calculados de `ide/g2.txt` |
| Análise sintática | Parser real × análise tabular de G2, passo a passo com controles, pilha, entrada, célula de M em destaque, contadores, primeiro erro, árvore de derivação | parser real + simulação da IDE |
| AST | Árvore hierárquica (expandir/recolher), operadores e operandos, texto, correspondência código ↔ AST ↔ IR | AST real |
| IR | Idem, para a IR devolvida por `lower_ir` | IR real |
| Análise semântica | Resultado de `validate_ir`, diagnóstico e código de erro, etapas bloqueadas, funções (aridade) | compilador |
| Otimizações | IR antes/depois, diferenças, transformações identificadas, contagem de nós | `optimize_ir` + classificação da IDE |
| Código Julia / Julia otimizado | Texto exato dos geradores, copiar, baixar `.jl`, comparar as duas versões | geradores reais |
| Saída | Executar interpretador, Julia gerado e Julia otimizado (um a um ou os três); stdout, stderr, código de retorno, tempo; comparação | execução explícita |
| Diagnósticos e desempenho | Diagnósticos das etapas que falharam e tempos de cada etapa | medições reais na Julia |

## G2 e o parser real da ABT

São duas análises **diferentes**, e a IDE as mostra lado a lado sem confundi-las:

- **Parser real da ABT**: descendente recursivo, escrito à mão em Julia (`parse_program`, `statement`, `expr`…). É o que decide se um programa é válido. Aceita a linguagem inteira (funções, textos, `e`/`ou`, `^`, `usar`, pipelines, chamadas…).
- **Análise preditiva tabular de G2**: gramática acadêmica LL(1) que cobre só um **recorte** da ABT (atribuição, expressões aritméticas e relacionais, `se`/`senao`, `para cada`, listas e `mostrar`). FIRST, FOLLOW e a tabela M são calculados a partir das produções em `ide/g2.txt`; o analisador consome os tokens que o lexer **real** produziu. A ABT não usa essa tabela.

O veredito mostrado combina os dois resultados:

| G2 | Parser real | Mensagem |
|---|---|---|
| aceita | aceita | Aceito por G2 e pelo parser real |
| rejeita | aceita | Programa **válido na ABT**, mas fora do recorte de G2 (lista os símbolos fora do recorte) |
| rejeita | rejeita | Rejeitado pelos dois (e o primeiro erro de cada um) |
| aceita | rejeita | Divergência G2 × implementação (sinalizada para investigação) |
| — | — | Erro léxico: a análise sintática não é feita |

**G2 ser LL(1) não significa que a linguagem ABT completa seja LL(1).** A IDE só afirma o que vale para G2 (sem conflitos em M) e diz isso na tela.

A **árvore de derivação** de G2 (aba Análise sintática) e a **AST** real (aba AST) são estruturas diferentes e aparecem em lugares diferentes.

## Matriz de atendimento aos requisitos acadêmicos

Requisitos do trabalho prático:

| # | Requisito | Onde | Exportação | Estado |
|---|---|---|---|---|
| 1 | Tabela de tokens, lexemas, padrões (regex) e linhas | Análise léxica | `tokens_simbolos.txt`, `tokens.csv` | Atendido |
| 2 | Tabela de símbolos definidos pelo usuário | Tabela de símbolos | `tokens_simbolos.txt`, `simbolos.csv` | Atendido (sem tipos: o compilador não os expõe) |
| 3 | Código reescrito com `id` e `num` | Código normalizado | `codigo_normalizado.txt` | Atendido |
| 4 | Passo a passo da análise sintática consultando a tabela M | Análise sintática | `passos_analise_sintatica.txt/.json` | Atendido (445 passos na referência) |
| 5 | Resultado da validação sintática | Análise sintática | `resultado_sintatico.txt` | Atendido |
| 6 | Primeiro erro sintático | Análise sintática | `resultado_sintatico.txt` | Atendido (G2 e parser real) |
| 7 | Informações em arquivos TXT | Exportar… | os quatro `.txt` acima | Atendido |

Itens da especificação da tarefa:

| Seção | Item | Estado |
|---|---|---|
| 4 | Ação **Inspecionar**, abas independentes, aviso de resultado desatualizado | Atendido (14 abas) |
| 5 | Tabela léxica completa, catálogo PT/EN, localizar token no código, erro léxico real | Atendido |
| 6 | Tabela de símbolos léxica × informações semânticas | **Parcial**: tipos e escopos não são expostos por `validate_ir`; o escopo exibido é derivado dos blocos de função nos tokens |
| 7 | Normalização a partir de tokens, comparação, TXT | Atendido |
| 8 | Terminais, não terminais, produções, FIRST, FOLLOW, M, conflitos, origem das células | Atendido |
| 9 | Passo a passo com controles, destaques, contadores, aceitação/erro, distinção G2 × parser real | Atendido |
| 10 | AST real, expandir/recolher, texto, operadores/operandos | Atendido; **parcial** em "localização no código": a AST não guarda posições (só há intervalos de tokens das instruções de nível superior) |
| 11 | IR real e correspondência fonte ↔ AST ↔ IR | Atendido (nível de instrução de topo) |
| 12 | Semântica: diagnósticos, etapas bloqueadas, não executar rejeitados | Atendido |
| 13 | Antes/depois das otimizações, "nenhuma otimização" explícito | Atendido; a classificação das transformações é feita pela IDE (o otimizador não as registra) |
| 14 | Julia normal e otimizada, copiar, exportar, comparar | Atendido |
| 15 | Execução pelos três caminhos, saída, stderr, código, tempo, comparação; sem execução automática | Atendido; o tempo é o de parede do processo |
| 16 | Tempos por etapa, instrumentação opcional | Atendido; ver limitações |
| 17 | Exportações (TXT acadêmicos, CSV, JSON, `.jl`, HTML autossuficiente, ZIP) | Atendido |
| 18 | Biblioteca padrão, offline, subprocessos seguros, token | Atendido |
| 19 | Testes | Atendido (ver abaixo); integração com a ABT não roda no CI |
| 20 | Apresentação: fonte, temas, tela cheia, referência | Atendido |

## Arquitetura e decisões

- **O compilador não foi alterado.** Só `ide/` mudou.
- **`--explain` investigado.** Ele existe apenas na interface legada (`julia pseudo.jl ARQ --explain --no-run`, função `ABT.explain`) e imprime texto para humanos (tokens, AST, IR, IR otimizada, Julia). A CLI `abt` da 0.15.0 não o expõe (`run`, `check`, `doctor`, `operacoes`). Em vez de interpretar esse texto, `ide/inspecionar.jl` chama as mesmas funções etapa por etapa e serializa em **JSON**, o que permite capturar erros por etapa, tempos e a estrutura da AST/IR.
- **Comunicação estruturada.** Julia → JSON (stdout) → Python. Nenhum texto de console é analisado, exceto a posição `L:C` dentro de mensagens de erro do compilador (que não têm campo próprio).
- **Onde roda a Julia.** A IDE acha a raiz da ABT (`ABT_RAIZ`, ou a pasta pai de `bin/` do comando `abt`) e usa a Julia embutida da instalação, com o depot dela e offline (igual ao lançador `abt`); sem runtime embutido, usa `ABT_JULIA` ou `julia` no `PATH`. Sem shell e sem comandos vindos da interface.
- **Segurança preservada.** Mesmo servidor (127.0.0.1, checagem de `Host`, token por execução, limite de 1 MiB), mesmas pastas temporárias e timeout de 60 s, e encerramento da árvore de processos. O código Julia executado nos caminhos "gerado" e "otimizado" **sai do servidor** (pacote inspecionado), nunca do cliente; o cliente só escolhe o caminho. Arquivos estáticos servidos: apenas `inspecao.js` e `inspecao.css`.
- **Uma só fonte para a gramática.** `ide/g2.txt` → `g2.py` calcula anuláveis, FIRST, FOLLOW e M; a interface e as exportações usam esse cálculo. Conflitos são detectados (há teste com uma gramática ambígua).
- **Tokens da reescrita de pipelines.** O lexer da ABT reescreve pipelines indentados (`expand_pipelines`) criando tokens cuja posição é copiada de outro token. A IDE os marca como `origem: pipeline`, não os desenha no código e os omite do código normalizado e dos símbolos.
- **Cache no servidor.** Os últimos 16 resultados ficam em memória, indexados pelo SHA-256 do código, para exportar e para executar sem reinspecionar.
- **Front-end** em HTML/CSS/JS nativos (`inspecao.js`, `inspecao.css`), sem bibliotecas, sem rede.

## Testes e evidências

```bash
python3 -m unittest discover -s ide -p "test_*.py"
```

| Conjunto | Resultado |
|---|---|
| Sem ABT instalada (como no CI) | 56 testes, 6 pulados (integração): OK |
| Com a ABT 0.15.0 instalada | 56 testes: OK (cerca de 75 s) |

O que cada grupo cobre (todos *executados* no ambiente de desenvolvimento; os de integração **não** rodam no CI):

- **Fixtures com saída real do compilador** (`ide/fixtures/*.json`, geradas por `gerar_fixtures.py`): referência acadêmica, precedência e associatividade, palavras em inglês com listas/condicionais/repetição/comentários, textos e identificadores Unicode, função recursiva, pipeline, fora de G2, e um erro léxico, um sintático e um semântico. Verificam tokens, símbolos, normalização, veredito, AST/IR, correspondência, otimizações e todas as exportações (TXT, CSV, JSON, HTML autossuficiente, ZIP).
- **Servidor**: token obrigatório, arquivos estáticos restritos, `inspecionar` não executa nada, o código Julia executado é o do servidor, caminho desconhecido recusado.
- **Integração** (precisa de Julia + ABT): as fixtures continuam idênticas ao que o compilador produz hoje; as expressões regulares documentadas ainda estão no `src/ABT.jl`; instrumentação mede tempo aquecido; **interpretador, Julia gerado e Julia otimizado produzem a mesma saída** na referência (`6.75 0.5 1 true true true`, igual à saída registrada no projeto acadêmico) e num programa que ativa as otimizações; programa rejeitado não gera código nem executa.
- **Interface**: percorrida manualmente no navegador (as 14 abas sem erro de JavaScript, passo a passo, execução dos três caminhos, aviso de código desatualizado). Não há teste automatizado do front-end.

### Reprodução dos resultados acadêmicos (programa de referência)

| Medida | Documentado | Obtido pela IDE |
|---|---|---|
| Tokens | 111 | 111 |
| Gramática G2 | 17 não terminais, 38 produções | 17 / 38 |
| Células preenchidas em M | 117, 0 conflitos | 117, 0 conflitos |
| Passos da análise | 445 | **445** (1 inicial + 332 produções + 111 casamentos + 1 aceitação) |
| Nós da árvore de derivação | 553 | 553 |

Nenhuma divergência encontrada; nada foi ajustado para reproduzir os números. A contagem de 445 inclui o estado inicial e o passo de aceitação, como no relatório.

### Tempos medidos (referência, uma execução nesta máquina, com instrumentação)

| Etapa | 1ª chamada (ms) | Aquecido (ms) |
|---|---|---|
| `using ABT` (carga do pacote) | 152,8 | — |
| Análise léxica | 1,9 | 0,10 |
| Análise sintática | 0,04 | 0,03 |
| IR | 0,08 | 0,01 |
| Validação semântica | 498 | 0,12 |
| Otimização | 264 | 0,05 |
| Geração Julia | 1553 | 0,91 |
| Geração Julia otimizado | 0,89 | 0,78 |

Os tempos altos da 1ª chamada são compilação JIT da Julia (lexer e parser vêm pré-compilados); o aquecido mostra o custo real da etapa. Valores variam entre execuções e máquinas.

## Limitações e itens parciais

- **Windows e macOS**: o modo de inspeção não foi executado numa máquina Windows ou macOS reais. O CI em Windows roda só os testes sem ABT (fixtures e servidor); a execução real da Julia nesses sistemas não foi verificada. A localização da Julia segue o layout do instalador (`runtime\julia\bin\julia.exe`, `depot`).
- **Tipos e escopos semânticos**: `validate_ir` infere tipos internamente mas não os devolve; a IDE não os exibe. O "escopo" da tabela de símbolos é derivado dos blocos `função … { }` nos tokens.
- **Posições na AST/IR**: não existem no compilador. Só há o intervalo de tokens das instruções de nível superior (obtido com o próprio `statement` do parser e conferido com a AST real).
- **Classificação de otimizações**: é uma inspeção estrutural das duas IRs feita pela IDE (constant folding de comparações de literais e eliminação de ramos com condição literal). O otimizador não registra o que fez; a prova é o diff.
- **Erros léxicos**: o lexer real não devolve tokens parciais; a IDE reaplica o lexer ao trecho anterior ao erro para mostrar os tokens reconhecidos.
- **Posição dos erros**: vem de `L:C` na mensagem do compilador; erros semânticos e alguns sintáticos (`Unclosed block`) não trazem posição.
- **Tempos**: a execução é medida pelo tempo de parede do processo (inclui inicialização da Julia e compilação). Não há medição interna separada de inicialização/compilação/execução do programa.
- **G2** cobre só um recorte da ABT; programas com funções, textos, `e`/`ou`, `^`, `usar` ou pipelines são válidos na ABT e ficam fora de G2.
- Os resultados ficam apenas em memória (16 mais recentes); reiniciar a IDE descarta o que não foi exportado.
