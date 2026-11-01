---
layout: post
title: "Ensinando um programa em C a mostrar o raciocínio"
locale: pt
slug: teaching-c-to-show-its-work
date: 2026-11-01
tags: [c, webassembly, algorithms]
---

O [projeto de rotas](/pt/projects/car-routes/) começou como um trabalho de 2023
que fiz com dois colegas: ler um mapa, achar a rota mais rápida e replanejar
quando o trânsito muda no meio do caminho. É C puro. Você dá um arquivo e ele
devolve três linhas: o caminho, os quilômetros e o tempo.

Para o professor corrigir, essa resposta basta. Para uma página web, não serve
para nada. Eu queria que o leitor visse o Dijkstra abrindo e fechando nós, o
carro saindo, uma via travando e o carro mudando de ideia. O C sabia tudo isso
enquanto rodava. Só nunca falava.

Vi três jeitos de colocar isso na página. Reescrever o algoritmo em JavaScript,
e o C viraria só um link para o repositório. Rodar o C antes e publicar
animações gravadas, e ninguém poderia criar o próprio engarrafamento. Ou
ensinar o C a narrar. Fiquei com o terceiro.

## Ganchos que não custam nada quando ninguém escuta

O C ganhou uma struct de ponteiros de função, um por evento, todos `NULL` por
padrão:

```c
typedef struct {
  void (*pop)(int node, double time);
  void (*relax)(int from, int to, double new_time);
  void (*plan)(const int *path, int length, double eta);
  void (*move)(int from, int to, double t0, double t1);
  /* ...update, replan, unreachable, done */
} TraceHooks;
```

O `dijkstra` e o laço de replanejamento só chamam cada um se ele estiver
preenchido. O programa de linha de comando original nunca preenche, então para
ele a mudança custa umas poucas comparações com `NULL`.

Antes de mexer em qualquer linha, salvei a saída do programa para alguns mapas
de teste como resultado esperado. Qualquer mudança dali em diante tinha que
reproduzir esses arquivos exatamente. Na primeira execução dessa base, um deles
saiu assim:

```
1;2;4;6
3.000000
00:02:60.000000
```

Dois minutos e sessenta segundos. A rota está certa, são exatamente 180
segundos. Em ponto flutuante a soma dá algo como 179,99999, o código trunca com
`(int)` para tirar os minutos, chega em 2, e imprime o resto, que o `printf`
arredonda de volta para 60. Isso vinha sendo impresso desde 2023. A correção
arredonda para milissegundos antes de quebrar o tempo em partes. Essa linha da
base foi a única que o projeto inteiro teve permissão de mudar.

## Uma linha por evento

Com os ganchos no lugar, uma função nova, `run_trace`, imprime uma linha para
cada coisa que acontece. Esta é a saída real para o mapa da página do projeto,
onde a via 2→4 cai para 5 km/h aos 30 segundos:

```
pop 1 0.000
relax 1 2 60.000
relax 1 3 90.000
pop 2 60.000
relax 2 4 120.000
relax 2 5 210.000
...
plan 1 2 4 6 180.000
move 1 2 0.000 60.000
update 2 4 5.000 60.000
replan 2 60.000
pop 2 0.000
...
plan 2 5 6 180.000
move 2 5 60.000 210.000
move 5 6 210.000 240.000
done 240.000 4.000
```

Repare nos tempos depois de `replan 2 60.000`. O `pop 2` seguinte diz `0.000`,
o plano novo diz que a viagem leva `180.000`, mas o carro chega em 240. Os dois
estão certos. Quando o carro replaneja, o Dijkstra recomeça do nó 2 com o
relógio zerado, então tudo que ele imprime é relativo àquele momento. Já
`move`, `update` e `done` usam o relógio de verdade. Minha própria spec errou
isso: ela tinha o segundo plano em `240.000`, e só corrigi depois que o C de
verdade imprimiu 180. O JavaScript guarda o relógio do último `replan` e soma
em todo evento do Dijkstra que vem depois.

O trace também mostra coisas que o código não diz em lugar nenhum. O nó 5 é
relaxado duas vezes, com 210 e depois com 156, porque o nosso heap não tem
decrease-key: ele só insere o nó de novo e deixa a cópia velha na fila. E o
`pop 4 720.000` aparece depois de o destino já estar fechado, porque o laço não
para antes. Os dois comportamentos sempre estiveram no código. Eu só vi quando
eles apareceram impressos, um por linha.

## Lendo um arquivo que não é arquivo

O programa original lê o mapa com `fscanf` de um `FILE *`. Uma página web não
tem arquivo nenhum para entregar, e eu não queria um segundo parser só para o
navegador. O `fmemopen` resolveu: ele abre uma string como `FILE *`, então o
`run_trace` recebe o mapa como texto e passa para as mesmas três funções de
leitura que o programa de linha de comando usa. O único custo foi compilar com
`-std=gnu99`.

Para o navegador, o Emscripten compila todos os arquivos menos o `main.c`. Sem
`main`, o módulo carrega e fica esperando. A página chama `run_trace` com o
mapa em forma de string, junta tudo que ele imprime pelo callback `print` do
módulo e recebe a execução inteira como texto. São 49.687 bytes de
WebAssembly, carregados uma vez por página, e uma execução nesses mapas leva
poucos milissegundos. Quando você cria um engarrafamento no editor de trânsito,
a página monta uma entrada nova e chama o C de novo.

## Entrada de desconhecidos

O editor de trânsito mudou uma coisa que ninguém tinha previsto. Até ali, a
única entrada que esse programa já tinha lido eram arquivos que nós três
escrevemos. Agora ele lê o que qualquer leitor monta clicando. Três coisas
quebraram na hora:

- o `read_updates` lia cada linha num `char aux[50]`, então uma linha comprida
  escrevia além do fim do buffer;
- uma atualização para uma via que não existe andava a lista de adjacência até
  passar do fim e derrubava o programa;
- um destino inalcançável também derrubava, em vez de avisar.

Teve uma quarta, mais quieta. O `dijkstra` dimensiona os vetores pelo número de
nós da primeira linha do arquivo, então um cabeçalho dizendo que o mapa tem um
bilhão de nós estouraria a pilha. O `run_trace` recusa qualquer coisa acima de
um milhão.

Nenhum desses era bug para o trabalho da faculdade, porque a gente nunca deu
arquivo ruim para ele. Hoje cada um tem um teste, e a saída do programa para
os mapas originais continua batendo byte a byte com a base, fora aquela linha.

## Reproduzindo

No lado do JavaScript, o trace passa por um reducer que transforma cada evento
num retrato completo: quais nós estão abertos ou fechados, o plano atual, onde
está o carro. Todos são calculados de uma vez, então tocar, pausar, avançar um
passo e mudar a velocidade são só uma posição num array. O canvas lê as cores
das variáveis CSS do site a cada quadro, e é por isso que o grafo acompanha a
troca de tema claro/escuro no meio da animação sem código extra.

O programa em C faz exatamente o que fazia em 2023. Só que agora ele fala
enquanto trabalha. E ainda imprime três minutos como `00:03:0.000000`, com os
segundos sem o zero à esquerda. O README documenta isso. Vou deixar assim.
