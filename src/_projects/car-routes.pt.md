---
title: Rotas com trânsito em C
locale: pt
slug: car-routes
year: 2023
featured: true
order: 4
summary: Caminho mais rápido num mapa cujo trânsito muda enquanto o carro anda — Dijkstra com fila de prioridade, replanejado a cada atualização, rodando aqui compilado para WebAssembly.
tech: [C, Dijkstra, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/car-routes-optimazing
demo:
  type: routes
---

Um mapa é um grafo: cruzamentos são nós, vias são arestas com sentido, e
cada via tem um comprimento em metros. O que este trabalho acrescenta é o
tempo: as vias têm velocidade, e a velocidade **muda enquanto o carro anda**
— um engarrafamento às 8h07, uma pista liberada às 8h20. O programa recebe o
mapa, a origem, o destino e a lista de mudanças, e responde por onde ir e
quanto tempo leva.

A simulação acima roda o C original do trabalho, compilado para WebAssembly.
Aperte **Rodar** para ver o algoritmo escolher o caminho, o carro seguir por
ele e, quando a via 2→4 trava, o desvio. Clique em qualquer via para
inventar seu próprio engarrafamento.

## Peso é tempo, não distância

O caminho mais curto não é o mais rápido: 3 km a 60 km/h levam 3 minutos;
4 km a 90 km/h, 2 minutos e 40. Por isso o peso de cada aresta é o tempo
que ela custa, calculado uma vez na leitura do arquivo:

```c
double calculate_weight(double distance, double velocity)
{
    velocity = velocity / 3.6;
    return distance / velocity;
}
```

Metros por (km/h ÷ 3,6) dá segundos. Quando uma via muda de velocidade,
só esse número muda; o grafo continua o mesmo.

## Dijkstra, passo a passo

<div class="rotas" data-rotas="dijkstra"></div>

O Dijkstra mantém, para cada nó, o menor tempo conhecido até ele, e uma
fila dos nós ainda por fechar, ordenada por esse tempo. A cada passo tira
da fila o nó de menor tempo, **fecha** — daqui em diante o tempo dele não
muda mais — e olha os vizinhos: se chegar neles por este nó for mais rápido
do que o que se conhecia, o tempo do vizinho é atualizado e ele volta para
a fila. É o *relaxamento*, e no código é isto:

```c
if (time[w_id] > time[v_id] + value(adj))
{
    time[w_id] = time[v_id] + value(adj);
    dist[w_id] = dist[v_id] + dist(adj);
    path[w_id] = v_id;
    PQ_insert(pq, init_adj(w_id, dist[w_id], time[w_id]));
}
```

`path[w] = v` guarda de onde se chegou em `w`; no fim, andar de trás para
frente a partir do destino reconstrói o caminho. A invariante que faz tudo
funcionar: quando um nó sai da fila, nenhum caminho ainda não explorado
pode ser mais rápido até ele — porque todos os outros nós na fila já custam
mais, e as vias só somam tempo. Isso exige pesos positivos, e tempo sempre
é.

Na simulação, os nós com contorno em destaque estão na fila; os
preenchidos, fechados. Repare que o algoritmo não para ao fechar o destino:
esvazia a fila. É uma otimização que ficou de fora.

## A fila de prioridade

A fila é um heap binário de mínimo (`PQ.c`): inserir e remover custam
O(log n). Sem ele, achar o menor tempo seria uma busca linear a cada passo,
e o algoritmo inteiro sairia em O(V²). Com o heap, O((V + E) log V) — para
um mapa de cidade, a diferença entre segundos e milissegundos.

Um detalhe do trabalho: o heap não tem "diminuir chave" em uso. Quando o
tempo de um nó melhora, ele é inserido de novo, e a cópia antiga fica na
fila com o tempo velho. Ao sair, ela é ignorada porque o nó já foi fechado.
É mais simples e custa pouco: a fila cresce até E entradas em vez de V.

## Quando o trânsito muda

<div class="rotas" data-rotas="engarrafamento"></div>

Aqui está o que o trabalho pede de verdade. O carro sai por `1 2 4 6`, o
plano mais rápido: 3 km, 3 minutos. Aos 30 segundos a via 2→4 cai para
5 km/h. O carro só fica sabendo ao chegar em 2, aos 60 segundos — e aí o
programa aplica a mudança e **roda o Dijkstra de novo, a partir de 2**. A
via 2→4 passou a custar 12 minutos; `2 5 6` custa 3. O carro desvia e chega
em 4 minutos, com 4 km rodados.

O loop que faz isso está em `calculate_path`: anda pelo plano nó a nó
somando tempo; quando o relógio passa do instante da próxima atualização,
aplica todas as vencidas e replaneja de onde está.

<div class="rotas" data-rotas="tarde-demais"></div>

Nem sempre dá tempo. Neste cenário a mesma via trava aos 90 segundos — e o
carro entrou nela aos 60. O modelo não interrompe uma via no meio: a
atualização só é aplicada quando o carro chega ao próximo nó, em 4, aos 120
segundos. Aí já não importa: `4 6` é o mais rápido do que resta. O trânsito
mudou e o carro pagou por ele sem chance de reagir. É a limitação mais
honesta do modelo, e a mais real.

<div class="rotas" data-rotas="via-libera"></div>

O contrário também acontece. Tudo a 30 km/h, o plano é `1 2 4 6`, 6
minutos. Aos 60 segundos a via 2→5 abre a 120 km/h. O carro chega em 2 aos
2 minutos, replaneja, e `2 5 6` agora custa 2 min 15 contra 4 minutos por 4.
Desvia e ganha quase dois minutos.

## O que faria diferente

- **Recalcular do zero** a cada atualização é simples e, para grafos deste
  tamanho, instantâneo. Num mapa real, algoritmos incrementais como D\* Lite
  ou LPA\* reaproveitam a busca anterior e só corrigem o que a mudança
  afetou.
- **O programa lê o futuro**: as atualizações vêm todas no arquivo, com
  instante marcado. Um carro de verdade só sabe do engarrafamento quando ele
  acontece — mas o Dijkstra que ele roda a cada notícia é exatamente este.
- **Uma velocidade inicial só** para todas as vias. Bastaria uma coluna a
  mais no arquivo para cada via ter a sua.
- **O carro não volta**. Se a melhor saída fosse dar meia-volta na via em
  que está, o modelo não sabe.

## Créditos

Trabalho de Técnicas de Busca e Ordenação (UFES, 2023), feito com
[João](https://github.com/vortex2jm) e
[Gabriel Gatti](https://github.com/gabrielgatti7). O código está no
[repositório](https://github.com/viniciuscole/car-routes-optimazing); o
modo *trace* que alimenta estas simulações foi adicionado para esta página.
