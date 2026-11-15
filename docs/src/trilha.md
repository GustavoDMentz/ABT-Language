# Trilha de aprendizado

Sete etapas, da instalação à análise científica. Siga a ordem: cada etapa usa o que a anterior ensinou, e termina com um **checkpoint** que você consegue conferir sozinho. Marque as lições como concluídas no fim de cada página; o progresso fica salvo apenas neste navegador.

```@raw html
<div id="abt-progress"></div>
<div class="abt-path">
```

## Instalar e rodar o primeiro comando

Prepare o ambiente e veja a ABT executando. Você vai entender o que é a linguagem e instalar tudo com um comando (a Julia 1.13.3 vem junto, no Linux).

- [O que é ABT](getting-started/overview.md)
- [Instalação, atualização e CLI](getting-started/install.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** `abt --version` imprime `ABT 0.15.0` e `abt doctor` confirma o ambiente.

```@raw html
</div>
```

## Escrever o primeiro programa

Variáveis, expressões, condição, laço e função em poucas linhas, com saída que você prevê antes de executar.

- [Tutorial 1 — primeiro programa](tutorials/first-program.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** `bin/abt run primeiro.abt` imprime `4` e `6`, e você sabe explicar por que `se 1 { ... }` é inválido: ABT exige condição booleana.

```@raw html
</div>
```

## Dominar a linguagem

Os valores, os nomes e as regras que o parser aplica. Aqui estão a precedência dos operadores, os blocos `se` / `para cada` e as funções.

- [Sintaxe, valores e nomes](manual/syntax.md)
- [Expressões e operadores](manual/expressions.md)
- [Condicionais, laços e funções](manual/control-flow.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** Sem consultar a página, explique por que `a < b < c` é rejeitado e como testar um intervalo com `e`.

```@raw html
</div>
```

## Trabalhar com listas e pipelines

O coração da ABT: `filtrar`, `transformar` e `limitar`, em atribuições separadas ou em um pipeline indentado terminado por `mostrar`.

- [Listas, agregações e pipelines](manual/collections.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** Reescreva o pipeline `filtrar → transformar → limitar` da página como três atribuições e confirme que o resultado continua `[30, 40]`.

```@raw html
</div>
```

## Analisar dados reais

Leia um CSV com esquema declarado, agrupe e resuma. A ABT não infere tipos em silêncio: você declara colunas e a política para valores ausentes.

- [Tutorial 2 — CSV tipado e JSON](tutorials/data.md)
- [Tutorial 3 — estatística descritiva](tutorials/statistics.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** Execute os dois exemplos e reproduza `media = 20.0` no resumo do tutorial de estatística.

```@raw html
</div>
```

## Aplicar à ciência

Comparação de grupos, regressão, sequências FASTA e gráficos, tudo com as operações já incluídas na biblioteca padrão.

- [Tutorial 4 — comparação e regressão](tutorials/biostatistics.md)
- [Tutorial 5 — sequências FASTA](tutorials/bioinformatics.md)
- [Tutorial 6 — visualização científica](tutorials/visualization.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** Execute `ensaio_clinico.abt`, `conteudo_gc.abt` e `visualizacao.abt` e leia o contrato de cada operação usada na [referência da biblioteca](standard-library/index.md).

```@raw html
</div>
```

## Ir mais fundo

Quando a biblioteca padrão não bastar, use módulos Julia. Para entender a linguagem por dentro, siga para a arquitetura e a gramática.

- [Bibliotecas Julia e Python](manual/interop.md)
- [Referência da biblioteca padrão](standard-library/index.md)
- [Arquitetura](internals/architecture.md)
- [Gramática](reference/grammar.md)

```@raw html
<div class="abt-check">
```

**Checkpoint.** Dada uma tarefa nova, você localiza a operação certa na referência e lê o seu contrato antes de usá-la.

```@raw html
</div>
</div>
```
