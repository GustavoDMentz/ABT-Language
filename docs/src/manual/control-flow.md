# Condicionais, laços e funções

```abt
numero = 4
se numero > 2 {
    mostrar "maior"
} senao {
    mostrar "menor ou igual"
}

para cada item em [1, 2, 3] {
    mostrar item
}
```

`se` exige condição booleana. Uma variável criada apenas em um ramo não fica garantida depois dele; defini-la em ambos os ramos torna o nome disponível. `para cada` percorre a coleção na ordem recebida. O corpo pode não executar; por isso novos nomes criados apenas nele não são garantidos após o laço. A variável do laço não pode esconder uma função declarada.

```abt
função dobro(x) {
    retornar x * 2
}
mostrar dobro(5)
```

Funções de nível superior ficam disponíveis antes de sua posição textual, aceitam aridade fixa e podem chamar outras funções ABT, incluindo recursão. Não há funções aninhadas nem captura implícita de variáveis mutáveis do nível superior. Parâmetros e atribuições locais pertencem à invocação. Sem `retornar`, a chamada produz o valor interno `nothing` do runtime, que não possui literal ABT próprio. `retornar` fora de função é erro.

`mostrar` é instrução com efeito de saída. Dentro de uma função, a saída é adicionada ao fluxo do programa na ordem de execução. Um erro ao avaliar argumentos acontece antes da chamada da função.
