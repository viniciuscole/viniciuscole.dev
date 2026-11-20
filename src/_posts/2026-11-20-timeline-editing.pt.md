---
layout: post
title: Edição na timeline com desfazer e refazer
locale: pt
slug: timeline-editing
date: 2026-11-20 00:00:20 -03:00
tags: [video, testing]
---

A timeline do [editor](https://viniciuscole.com/lab/editor/) faz o que se
espera: aparar, mover, dividir, apagar, apagar fechando o buraco (o ripple
delete), crossfades, velocidade do clipe, desfazer e refazer. Nada disso é
difícil de descrever. O difícil é manter umas poucas regras verdadeiras depois
de qualquer sequência de edições, então este post é mais sobre como essas
regras são escritas e testadas. A
[visão geral](/pt/2026/11/20/how-it-works/) tem o resto da arquitetura.

## Inteiros numa grade de quadros

O tempo no documento é um número inteiro de microssegundos, e todo ponto de
edição cai num quadro do projeto. O quadro `n` fica em
`round(n · 1e6 · den / num)`, então a 29,97 fps (30000/1001) o quadro 100 é
3.336.667 µs. Inteiro mantém isso exato onde float escorregaria.

Ir e voltar entre as duas unidades ainda perde um microssegundo aqui e ali,
então o código que precisa saber qual quadro da fonte aparece num quadro da
timeline faz a conta em índices de quadro, não em microssegundos. O primeiro
PR da timeline achou erros de arredondamento de 1 µs a 29,97 fazendo do outro
jeito.

## Comandos e patches

Toda mudança passa por um comando com nome, e o store é pequeno o bastante
para mostrar:

```ts
dispatch(command: Command): boolean {
  const [next, patches, inverse] = produceWithPatches(this.current, (draft) => {
    command.apply(draft);
    pruneTransitions(draft);
  });
  if (patches.length === 0) return false;
  ...
}
```

O `produceWithPatches` do Immer devolve o documento novo e os patches nas duas
direções. O desfazer aplica os inversos, o refazer aplica os de ida, e todo
conjunto de patches vai também para o worker de renderização, que mantém a
própria cópia do documento. Um comando que não muda nada não gera patch nem
passo de desfazer.

Um arrasto não é uma enxurrada de comandos. Enquanto você arrasta, funções
puras calculam uma prévia de onde o clipe iria parar, e o documento só muda
quando você solta, como um único `moveClip` ou `trimClip`. Um arrasto, um
passo de desfazer. O Esc cancela sem deixar nada para desfazer.

O ripple delete fecha o buraco em todas as trilhas, para elas continuarem em
sincronia. Se um clipe de outra trilha cruza o trecho que está saindo, o
ripple é recusado e um aviso diz qual clipe e qual trilha. O deslocamento é
feito em quadros, então clipes a 29,97 fps continuam na grade.

## Regras, conferidas ao acaso

A spec lista as regras: clipes nunca se sobrepõem numa trilha, todo ponto de
edição está num quadro, transições nunca usam mais material do que existe, um
clipe só aparece dentro do próprio intervalo, e desfazer tudo devolve o
documento inicial. Elas são conferidas com testes de propriedade do
fast-check, que geram sequências aleatórias de adicionar, aparar, mover,
arrastar, dividir, apagar, ripple, crossfade, velocidade, desfazer e refazer,
e checam todas as regras depois de cada passo. A cópia do documento no worker
também tem que ser igual à da thread principal em todo passo.

A montagem do teste também conta. Um revisor percebeu que o teste só zerava o
documento depois de uma rodada que passava, então uma rodada que falhava
encolhia o contraexemplo em cima de um documento sujo, e não dava para
confiar nele. Hoje cada rodada abre um editor novo.

## Crossfades sem sobreposição

Clipes nunca se sobrepõem, então um crossfade não pode ser dois clipes
deslizando um por cima do outro. Ele fica em cima do corte e pega emprestado
material que os clipes não estão mostrando: de depois do ponto de saída do
clipe que sai e de antes do ponto de entrada do clipe que entra. Esses quadros
de sobra são as handles. Se não tem material suficiente, o crossfade encolhe e
o inspetor avisa "Shortened to X s: not enough footage beyond the cut." O
documento guarda a duração que você pediu, então ela volta quando uma aparada
libera material.

A revisão desse PR achou que o teste de propriedade não protegia de verdade a
regra das handles. A maioria dos cortes vinha de divisões, em que o
comprimento do clipe acaba antes do material. Com o limite do material antes
do ponto de entrada removido, o teste ainda passava com as 25 rodadas do
commit. Com 150 rodadas ele falhou uma vez, na rodada 103, com esta
sequência:

```
add(in 14, len 1), append(in 0, len 1), crossfade(2)
```

Hoje o gerador puxa para clipes com pouquíssimo material de cada lado, e as
duas mutações das handles derrubam o teste 5 vezes em 5.

## Velocidade, e meios quadros

A velocidade do clipe foi o ticket em que a grade de quadros resistiu. Um
clipe mantém o trecho da fonte, e o comprimento dele na timeline vira
`max(1, round(sourceFrames / speed))`. O quadro `i` da timeline mostra o
quadro `floor(in + i · speed)` da fonte: um quadro sim, um não a 2×, cada
quadro duas vezes a 0,5×, e os quadros 0, 1, 3, 4, 6 a 1,5×.

A primeira versão aparava arredondando a mudança na fonte a cada passo. Pegue
um clipe mostrando os quadros 20 a 50 da fonte a 0,5×, ou seja, 60 quadros na
timeline. Aparar um quadro no fim move a fonte em meio quadro, e
`Math.round(-0.5)` em JavaScript é `-0`. O revisor aparou o fim dez vezes: o
clipe ficou 10 quadros mais curto e o ponto de saída na fonte não saiu do
lugar. Aparar o começo dez vezes levou o ponto de entrada de 20 para 30 em vez
de 25, porque `Math.round(0.5)` é 1. Depois disso, o último quadro do clipe
mostrava o quadro 54 da fonte, depois do ponto de saída em 50, e aparar de
volta nunca restaurava o original.

Em quadros inteiros, não tem como acertar isso. Aparar um quadro a 0,5× tem
que mover a fonte em meio quadro. Então os pontos de entrada e saída na fonte
agora ficam numa grade de 1/100 de quadro, e as velocidades são quantizadas
em 0,01, de modo que uma aparada move a fonte exatamente `speed` quadros e
aparadas repetidas nunca escorregam. A spec diz que todo ponto de edição cai
num quadro. Os pontos da timeline continuam caindo, mas os pontos na fonte de
um clipe fora de 1× não, e o PR registra isso como desvio da spec. Voltar um
clipe para 1× arredonda o trecho da fonte para fora, até quadros inteiros.

## O contraexemplo

A rodada de revisão seguinte pegou o teste de propriedade falhando ao acaso.
O fast-check encolheu a falha até isto:

```
[{"inFrame":33,"length":1},0,3,[{"edge":"start","frames":0}],0]
AssertionError: source range, speed and duration disagree:
  expected 0.6666666666666667 to be less than or equal to 0.500001
```

O invariante dizia que o comprimento de um clipe fica a meio quadro do seu
material dividido pela velocidade. Só que um clipe com um quadro de fonte a 3×
tem um quadro na timeline, por causa do piso do `max(1, …)`, e |1/3 − 1| dá
0,67. O código estava certo e o invariante estava errado. Ele só falhava nas
rodadas em que a semente aleatória sorteava um clipe de um quadro a 3×, e o CI
tinha passado por sorte.

Fazendo a conta direito: uma aparada mantém `L − S/s` constante (L quadros na
timeline, S quadros na fonte, velocidade s), e uma mudança de velocidade põe
esse valor entre −0,5 e 0,5, menos no piso de um quadro. Então o intervalo
alcançável é `−0.5 ≤ L − S/s < 1`, e o teste afirma esses dois limites. O de
cima diz que um clipe nunca mostra um quadro depois do seu ponto de saída. O
de baixo diz que ele nunca fica mais de meio quadro curto. O revisor recolocou
o bug de arredondamento original e o novo limite de baixo pegou sozinho.

O bug de arredondamento foi achado por um revisor aparando na mão, não pelo
teste de propriedade. Depois o teste de propriedade falhou por um erro dele
mesmo. A regra que um teste aleatório confere precisa da mesma revisão que o
código que ele confere.
